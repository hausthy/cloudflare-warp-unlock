# syntax=docker/dockerfile:1.7
# ==============================================================================
# warp-unlock v2.0 — 官方 Cloudflare WARP 客户端 (MASQUE) 架构
#
# 与 v1.x (WGCF + wireguard-go) 的根本区别：
#   * 不创建 TUN 虚拟网卡，不修改任何路由表 —— 无需 /dev/net/tun、无需 NET_ADMIN，
#     容器除 Docker 默认能力外零特权，可运行在任何能跑 Docker 的环境；
#   * 使用 Cloudflare 官方 warp-svc 守护进程，走 MASQUE 协议（官方 proxy 模式唯一支持协议）；
#   * GOST 作为前端：同端口 auto 协议（SOCKS5 / SOCKS4 / HTTP CONNECT）+ 可选认证。
#
# 分层构建（Multi-stage）：
#   Stage 1 builder —— 递归解析 cloudflare-warp 的全部 DEB 依赖包，逐个下载并用
#          dpkg -x 解包到 /out（覆盖 ldd 静态解析不到的 dlopen 库，如 libtss2-*）；
#          GOST 一并在此下载。gnupg/socat 等安装工具一概不需要。
#   Stage 2 runtime —— 仅安装 ca-certificates / curl / tzdata 三个运行时必需包，
#          COPY /out 增量即得最终镜像。apt 缓存、文档、安装工具不进入最终层。
# ==============================================================================

ARG DEBIAN_RELEASE=bookworm

# ------------------------------------------------------------------------------
# Stage 1: builder —— 收集官方客户端全部 DEB 依赖并组装运行时增量
# ------------------------------------------------------------------------------
FROM docker.io/debian:${DEBIAN_RELEASE}-slim AS builder

ARG DEBIAN_RELEASE
ARG GOST_VERSION=2.11.5
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    # 接入 Cloudflare 官方 APT 源（bookworm 的 apt 支持直接引用 armored 密钥，无需 gnupg）
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
      -o /etc/apt/keyrings/cloudflare-warp.asc; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/cloudflare-warp.asc] https://pkg.cloudflareclient.com/ ${DEBIAN_RELEASE} main" \
      > /etc/apt/sources.list.d/cloudflare-client.list; \
    apt-get update; \
    # ---------- 递归收集 cloudflare-warp 的全部依赖包并下载 ----------
    # 注意：必须用递归依赖解包而非 ldd 拷贝——warp-svc 会 dlopen libtss2-esys 等
    # TPM2 库，ldd 静态解析不到，运行时会报 cannot open shared object file。
    DEPS="$(apt-cache depends --recurse --no-recommends --no-suggests \
             --no-conflicts --no-breaks --no-replaces --no-enhances \
             cloudflare-warp \
           | grep -E '^[a-zA-Z0-9]' | sort -u | tr '\n' ' ')"; \
    echo ">>> 依赖包列表: ${DEPS}"; \
    mkdir -p /debs; \
    cd /debs; \
    apt-get download ${DEPS}; \
    # ---------- 逐包解包到 /out ----------
    mkdir -p /out; \
    for deb in /debs/*.deb; do dpkg -x "$deb" /out; done; \
    # ---------- merged-usr 归一化 ----------
    # bookworm 的 /bin、/sbin、/lib、/lib64 是指向 /usr 的符号链接；若部分 deb 解包出
    # 同名真实目录，COPY 到 runtime 会与符号链接冲突（cannot copy to non-directory）。
    # 统一并入 /usr 对应目录，保证 /out 只包含 usr/、etc/ 等真实目录。
    for d in bin sbin lib lib64; do \
      if [ -d "/out/$d" ]; then \
        mkdir -p "/out/usr/$d"; \
        cp -a "/out/$d/." "/out/usr/$d/"; \
        rm -rf "/out/$d"; \
      fi; \
    done; \
    # 剪裁运行时用不到的内容，进一步瘦身
    rm -rf /out/lib/systemd /out/usr/lib/systemd /out/etc/systemd \
           /out/usr/share/doc /out/usr/share/man /out/usr/share/info \
           /out/usr/share/lintian /out/usr/share/bug; \
    # ---------- 下载 GOST（静态单文件，用于前端 auto 协议与可选认证） ----------
    case "${TARGETARCH}" in \
      amd64) GOST_ARCH=amd64 ;; \
      arm64) GOST_ARCH=armv8 ;; \
      *) echo "不支持的构建架构: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL --retry 3 \
      "https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz" \
      -o /tmp/gost.gz; \
    mkdir -p /out/usr/local/bin; \
    gzip -dc /tmp/gost.gz > /out/usr/local/bin/gost; \
    chmod 0755 /out/usr/local/bin/gost; \
    rm -f /tmp/gost.gz; \
    # ---------- 定位 warp 二进制并设置 PATH 兜底符号链接 ----------
    WARP_SVC="$(find /out -name warp-svc -type f | head -n1 | sed "s|^/out||")"; \
    WARP_CLI="$(find /out -name warp-cli -type f | head -n1 | sed "s|^/out||")"; \
    echo ">>> warp-svc 解包路径: ${WARP_SVC}"; \
    echo ">>> warp-cli 解包路径: ${WARP_CLI}"; \
    test -n "$WARP_SVC" && test -n "$WARP_CLI"; \
    ln -sf "$WARP_SVC" /out/usr/local/bin/warp-svc; \
    ln -sf "$WARP_CLI" /out/usr/local/bin/warp-cli; \
    # 构建期断言：二进制必须就位且可执行，否则立即失败暴露问题
    test -x /out/usr/local/bin/warp-svc; \
    test -x /out/usr/local/bin/warp-cli; \
    # ---------- 清理构建期产物（不进入任何镜像层记录也无妨，双保险） ----------
    rm -rf /debs /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ------------------------------------------------------------------------------
# Stage 2: runtime —— 极简运行时
# ------------------------------------------------------------------------------
FROM docker.io/debian:${DEBIAN_RELEASE}-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

# 仅安装运行时必需包，并即时清理 apt 缓存与文档，杜绝缓存进入镜像层
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl tzdata; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/* \
           /usr/share/doc/* /usr/share/man/* /usr/share/info/* /usr/share/locale/*

# 从 builder 层拷贝运行时增量：warp 二进制 + 全部依赖库 + GOST
COPY --from=builder /out/ /

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/check-status.sh /app/check-status.sh
COPY scripts/unlock-check.sh /app/unlock-check.sh

RUN chmod 0755 /entrypoint.sh /app/check-status.sh /app/unlock-check.sh \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && mkdir -p /logs /var/lib/cloudflare-warp \
    # 运行时断言：warp 二进制与 GOST 必须存在且可执行
    && test -x /usr/local/bin/warp-svc \
    && test -x /usr/local/bin/warp-cli \
    && test -x /usr/local/bin/gost

# 注册状态持久化目录（warp-svc 数据目录；挂载宿主机 ./config 可跨容器重启保留账户）
VOLUME ["/var/lib/cloudflare-warp"]

EXPOSE 40000/tcp

ENTRYPOINT ["/entrypoint.sh"]

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
#   Stage 1 builder —— 接入 Cloudflare APT 源并完整安装 cloudflare-warp，随后用 ldd
#          解析 warp-svc / warp-cli 的全部动态库依赖，连同二进制与数据文件组装成
#          /out 根文件系统增量；GOST 一并在此下载。gnupg/curl 等安装工具全部留在本层。
#   Stage 2 runtime —— 仅安装 ca-certificates / curl / tzdata 三个运行时必需包，
#          COPY /out 增量即得最终镜像。apt 缓存、文档、gnupg、socat 一概不进入最终层。
# ==============================================================================

ARG DEBIAN_RELEASE=bookworm

# ------------------------------------------------------------------------------
# Stage 1: builder —— 安装官方客户端并组装运行时增量
# ------------------------------------------------------------------------------
FROM docker.io/debian:${DEBIAN_RELEASE}-slim AS builder

ARG DEBIAN_RELEASE
ARG GOST_VERSION=2.11.5
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends gnupg ca-certificates curl; \
    # 接入 Cloudflare 官方 APT 源
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
      | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${DEBIAN_RELEASE} main" \
      > /etc/apt/sources.list.d/cloudflare-client.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends cloudflare-warp; \
    # 下载 GOST（静态单文件，用于前端 auto 协议与可选认证）
    case "${TARGETARCH}" in \
      amd64) GOST_ARCH=amd64 ;; \
      arm64) GOST_ARCH=armv8 ;; \
      *) echo "不支持的构建架构: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL --retry 3 \
      "https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz" \
      -o /tmp/gost.gz; \
    gzip -dc /tmp/gost.gz > /out-gost; \
    rm -f /tmp/gost.gz; \
    # ---------- 组装 /out 运行时增量 ----------
    mkdir -p /out/usr/local/bin; \
    mv /out-gost /out/usr/local/bin/gost; \
    chmod 0755 /out/usr/local/bin/gost; \
    # 用 dpkg 精确定位 warp 二进制的真实安装路径（不假设 /usr/bin，兼容 sbin 等布局）
    WARP_SVC="$(dpkg -L cloudflare-warp | grep -E '/warp-svc$' | head -n1)"; \
    WARP_CLI="$(dpkg -L cloudflare-warp | grep -E '/warp-cli$' | head -n1)"; \
    echo ">>> warp-svc 安装路径: ${WARP_SVC}"; \
    echo ">>> warp-cli 安装路径: ${WARP_CLI}"; \
    test -n "$WARP_SVC" && test -n "$WARP_CLI"; \
    # 拷贝二进制及全部动态库依赖（ldd 解析，天然兼容静态二进制的空输出）
    for src in "$WARP_SVC" "$WARP_CLI"; do \
      cp --parents "$src" /out/; \
      ldd "$src" 2>/dev/null \
        | awk '{if ($3 ~ /^\//) print $3; else if ($1 ~ /^\//) print $1}' \
        | sort -u \
        | while read -r lib; do cp --parents "$lib" /out/; done; \
    done; \
    # PATH 兜底：在 /usr/local/bin 放符号链接，无论真实安装路径在哪都能被 exec 找到
    ln -sf "$WARP_SVC" /out/usr/local/bin/warp-svc; \
    ln -sf "$WARP_CLI" /out/usr/local/bin/warp-cli; \
    # 构建期断言：二进制必须就位，否则立即失败暴露问题（而不是等容器运行时才炸）
    test -x "/out${WARP_SVC}"; \
    test -x "/out${WARP_CLI}"; \
    # 附带客户端的数据/配置目录（存在才拷贝，不影响运行时自动创建）
    for d in /etc/cloudflare-warp /usr/share/cloudflare-warp; do \
      [ -d "$d" ] && cp -a --parents "$d" /out/ || true; \
    done

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

# 从 builder 层拷贝运行时增量：warp 二进制 + 动态库 + 数据目录 + GOST
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

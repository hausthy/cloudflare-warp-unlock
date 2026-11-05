# syntax=docker/dockerfile:1.7
# ==============================================================================
# warp-unlock v2.0 — 官方 Cloudflare WARP 客户端 (MASQUE) 架构
#
# 与 v1.x (WGCF + wireguard-go) 的根本区别：
#   * 不创建 TUN 虚拟网卡 —— 无需 /dev/net/tun；仅需 NET_ADMIN capability
#     （新版 warp-svc 连接建立后会安装 fwmark 策略路由规则，官方客户端硬性要求）；
#   * 使用 Cloudflare 官方 warp-svc 守护进程，走 MASQUE 协议（官方 proxy 模式唯一支持协议）；
#   * GOST 作为前端：同端口 auto 协议（SOCKS5 / SOCKS4 / HTTP CONNECT）+ 可选认证。
#
# 分层构建（Multi-stage）：
#   Stage 1 builder —— 真实安装 cloudflare-warp 后，按 ldd 精确拷贝 warp-svc /
#          warp-cli 的全部传递依赖，并显式补上 dlopen 加载的 libtss2-*（TPM2）
#          与 /usr/lib/warp 数据目录；GUI 依赖栈（GTK/gstreamer 等，约 400MB）
#          完全不进 /out。GOST 一并在此下载。
#   Stage 2 runtime —— 仅安装 ca-certificates / tzdata / dbus 三个运行时
#          必需包，curl 使用 builder 提供的静态二进制（SHA256 强校验），
#          COPY /out 增量即得最终镜像。
# ==============================================================================

ARG DEBIAN_RELEASE=bookworm

# ------------------------------------------------------------------------------
# Stage 1: builder —— 安装官方客户端并抽取最小运行时集
# ------------------------------------------------------------------------------
FROM docker.io/debian:${DEBIAN_RELEASE}-slim AS builder

ARG DEBIAN_RELEASE
ARG GOST_VERSION=2.11.5
# 静态 curl（stunnel/static-curl 项目，替代 apt curl 及其 ~20MB 动态依赖闭包）；
# SHA256 取自 release 页官方 checksums，构建期强校验
ARG CURL_STATIC_VERSION=8.23.0-1
ARG CURL_STATIC_SHA256_AMD64=b19756efa22538f0af3bb293626841c9dbf0d168489a1924f0e3edec2f560ba6
ARG CURL_STATIC_SHA256_ARM64=71780652d4e4de42bc0f2138cb764c90a7f8d4b64969450dd1dde5518cc5ff09
ARG UPX_VERSION=4.2.4
# UPX 同时压缩 warp-svc（默认 0 关闭）。压后镜像可再省 ~60MB，但 warp-svc 是
# 常驻守护进程，压缩属于非常规操作；如连接异常请用 --build-arg UPX_WARP_SVC=0 回退
ARG UPX_WARP_SVC=0
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    # 注意：bookworm 源里没有 upx-ucl 包，改用 UPX 官方 GitHub 静态二进制；
    # 其发行包为 .tar.xz，builder 需要临时安装 xz-utils 解压（不进最终镜像）
    apt-get install -y --no-install-recommends ca-certificates curl binutils xz-utils; \
    # 接入 Cloudflare 官方 APT 源（bookworm 的 apt 支持直接引用 armored 密钥，无需 gnupg）
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
      -o /etc/apt/keyrings/cloudflare-warp.asc; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/cloudflare-warp.asc] https://pkg.cloudflareclient.com/ ${DEBIAN_RELEASE} main" \
      > /etc/apt/sources.list.d/cloudflare-client.list; \
    apt-get update; \
    # ---------- 真实安装（builder 内 ldd 才能解析完整传递依赖） ----------
    # 注意：cloudflare-warp 的 deb 硬依赖整套 GUI 栈（GTK3/gstreamer/fonts，
    # 约 400MB），但 warp-svc/warp-cli 完全用不到；因此不解包整个 deb 闭包，
    # 而是只按动态链接关系抽取最小运行时集。
    apt-get install -y --no-install-recommends cloudflare-warp; \
    # ---------- 拷贝 warp 二进制及其全部传递动态库依赖 ----------
    mkdir -p /out; \
    for bin in /usr/bin/warp-svc /usr/bin/warp-cli; do \
      cp --parents "$bin" /out/; \
      ldd "$bin" 2>/dev/null \
        | awk '{if ($3 ~ /^\//) print $3; else if ($1 ~ /^\//) print $1}' \
        | sort -u > /tmp/libs.txt; \
      while read -r lib; do cp --parents "$lib" /out/; done < /tmp/libs.txt; \
    done; \
    # warp-svc 运行时 dlopen 的 TPM2 库——ldd 静态解析不到，必须显式带上
    for lib in /usr/lib/*/libtss2*; do \
      [ -e "$lib" ] && cp --parents "$lib" /out/ || true; \
    done; \
    # 客户端自带运行时数据目录（守护进程加载的辅助资源）
    [ -d /usr/lib/warp ] && cp -a --parents /usr/lib/warp /out/ || true; \
    [ -d /etc/cloudflare-warp ] && cp -a --parents /etc/cloudflare-warp /out/ || true; \
    # ---------- merged-usr 归一化 ----------
    # bookworm 的 /bin、/sbin、/lib、/lib64 是指向 /usr 的符号链接；ldd 解析出的
    # 库按绝对路径复制会产生 /out/lib 等真实目录，COPY 到 runtime 会与符号链接
    # 冲突（cannot copy to non-directory）。统一并入 /usr 对应目录。
    for d in bin sbin lib lib64; do \
      if [ -d "/out/$d" ]; then \
        mkdir -p "/out/usr/$d"; \
        cp -a "/out/$d/." "/out/usr/$d/"; \
        rm -rf "/out/$d"; \
      fi; \
    done; \
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
    # ---------- 剥离符号表与调试信息（对运行时零影响，体积收益巨大） ----------
    # warp-svc / warp-cli / gost 均为 Go/Rust 二进制，自带数十 MB 的 DWARF 调试
    # 段；动态库同样带符号表。--strip-unneeded 只移除重定位与调试所需符号，
    # 运行行为完全不变。
    if command -v strip >/dev/null 2>&1; then \
      echo ">>> strip 前体积: $(du -sh /out | cut -f1)"; \
      find /out -type f \( -perm /111 -o -name '*.so*' \) \
        -exec strip --strip-unneeded {} + 2>/dev/null || true; \
      echo ">>> strip 后体积: $(du -sh /out | cut -f1)"; \
    fi; \
    # ---------- PATH 兜底符号链接（必须用相对路径：绝对目标会在 builder 内
    # 解析到 builder 自身文件系统导致断言失败） ----------
    WARP_SVC="$(find /out -name warp-svc -type f | head -n1 | sed "s|^/out||")"; \
    WARP_CLI="$(find /out -name warp-cli -type f | head -n1 | sed "s|^/out||")"; \
    echo ">>> warp-svc 路径: ${WARP_SVC}"; \
    echo ">>> warp-cli 路径: ${WARP_CLI}"; \
    test -n "$WARP_SVC" && test -n "$WARP_CLI"; \
    chmod 0755 "/out${WARP_SVC}" "/out${WARP_CLI}"; \
    # ---------- UPX 压缩（风险与收益权衡后的保守方案） ----------
    # 实测官方二进制已自带 strip，符号层面无油水；UPX 对 Go/常规 ELF 可压
    # 约 60%。gost 与 warp-cli 压缩风险低（普通前台/IPC 客户端进程）；
    # warp-svc 是常驻守护进程且需 fork/exec，为稳定性起见默认不压。
    # 如需极限瘦身可自行在下方追加 upx 处理 warp-svc（需自测）。
    # ---------- UPX 下载（GitHub 静态二进制，按构建架构选择） ----------
    case "${TARGETARCH}" in \
      amd64) UPX_ARCH=amd64 ;; \
      arm64) UPX_ARCH=arm64 ;; \
      *) echo "不支持的构建架构: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL --retry 3 \
      "https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-${UPX_ARCH}_linux.tar.xz" \
      -o /tmp/upx.tar.xz; \
    mkdir -p /tmp/upx; \
    tar -xJf /tmp/upx.tar.xz -C /tmp/upx --strip-components=1; \
    test -x /tmp/upx/upx; \
    echo ">>> UPX 前:"; ls -lh /out/usr/local/bin/gost "/out${WARP_CLI}" | awk '{print $5, $9}'; \
    /tmp/upx/upx -q -9 /out/usr/local/bin/gost || true; \
    /tmp/upx/upx -q -9 "/out${WARP_CLI}" || true; \
    # 可选：压缩 warp-svc（见文件头 ARG UPX_WARP_SVC 说明）
    if [ "${UPX_WARP_SVC}" = "1" ]; then \
      /tmp/upx/upx -q -9 "/out${WARP_SVC}" || true; \
    fi; \
    echo ">>> UPX 后:"; ls -lh /out/usr/local/bin/gost "/out${WARP_CLI}" "/out${WARP_SVC}" | awk '{print $5, $9}'; \
    # ---------- 静态 curl（下载到 /out，runtime 直接 COPY，免去动态依赖全家桶） ----------
    # 发行包为 curl-linux-<arch>-glibc-<version>.tar.xz，内含静态 curl 二进制
    case "${TARGETARCH}" in \
      amd64) CURL_ARCH=x86_64; CURL_SHA256="${CURL_STATIC_SHA256_AMD64}" ;; \
      arm64) CURL_ARCH=aarch64; CURL_SHA256="${CURL_STATIC_SHA256_ARM64}" ;; \
      *) echo "不支持的构建架构: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL --retry 3 \
      "https://github.com/stunnel/static-curl/releases/download/${CURL_STATIC_VERSION}/curl-linux-${CURL_ARCH}-glibc-${CURL_STATIC_VERSION}.tar.xz" \
      -o /tmp/static-curl.tar.xz; \
    mkdir -p /tmp/static-curl; \
    tar -xJf /tmp/static-curl.tar.xz -C /tmp/static-curl; \
    find /tmp/static-curl -type f -name curl -exec cp {} /out/usr/local/bin/curl \;; \
    rm -rf /tmp/static-curl /tmp/static-curl.tar.xz; \
    test -x /out/usr/local/bin/curl; \
    # SHA256 针对二进制本体（取自 release 页 checksums），供应链强校验
    echo "${CURL_SHA256}  /out/usr/local/bin/curl" | sha256sum -c -; \
    # 校验通过后再压缩（UPX 会改写文件，必须放在校验之后）
    /tmp/upx/upx -q -9 /out/usr/local/bin/curl || true; \
    chmod 0755 /out/usr/local/bin/curl; \
    rm -rf /tmp/upx /tmp/upx.tar.xz; \
    SVC_REL="$(realpath --relative-to="/out/usr/local/bin" "/out${WARP_SVC}")"; \
    CLI_REL="$(realpath --relative-to="/out/usr/local/bin" "/out${WARP_CLI}")"; \
    ln -sf "$SVC_REL" /out/usr/local/bin/warp-svc; \
    ln -sf "$CLI_REL" /out/usr/local/bin/warp-cli; \
    # 构建期断言：二进制必须就位且可执行，否则立即失败暴露问题
    test -x /out/usr/local/bin/warp-svc; \
    test -x /out/usr/local/bin/warp-cli; \
    # 打印 /out 体积分布，便于排查镜像膨胀
    echo ">>> /out 总体积: $(du -sh /out | cut -f1)"; \
    du -xh -d2 /out/usr | sort -rh | head -12; \
    # ---------- 清理构建期产物 ----------
    rm -rf /var/cache/apt/archives/*.deb /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ------------------------------------------------------------------------------
# Stage 2: runtime —— 极简运行时
# ------------------------------------------------------------------------------
FROM docker.io/debian:${DEBIAN_RELEASE}-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

# 仅安装运行时必需包（curl 由 builder 提供静态二进制，不再装 apt 版及其
# libcurl/openssl/krb5/ldap/sasl 等动态依赖），并即时清理 apt 缓存与文档，
# 杜绝缓存进入镜像层
# （dbus：warp-svc 启动时会尝试连接 system bus 读取电源状态，缺失时每 3 秒
#   重试并打印 WARN；提供轻量 dbus-daemon 即可彻底消除该日志噪音）
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates tzdata dbus; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/* \
           /usr/share/doc/* /usr/share/man/* /usr/share/info/* /usr/share/locale/* \
           /var/lib/dpkg/info/* /var/cache/* \
    # 运行期不再安装任何软件包，apt/dpkg 工具链与元数据整体移除（~15MB）。
    # 副作用：基于此镜像的衍生构建无法再 apt install，属预期行为
    && rm -rf /usr/bin/apt* /usr/bin/dpkg* /usr/lib/apt /usr/lib/dpkg \
              /var/lib/dpkg /var/lib/apt /etc/apt \
    # 基础镜像残留的无用组件（~19MB）：
    #   gconv —— glibc 字符集转换模块，运行期仅用 UTF-8/ASCII
    #   perl —— base 镜像的 Essential 残留，脚本与 dbus 均不依赖
    #   openssl CLI —— 静态 curl 自带 TLS 实现，仅需 libssl 库本体
    && rm -rf /usr/lib/x86_64-linux-gnu/gconv \
              /usr/lib/x86_64-linux-gnu/perl-base \
              /usr/bin/perl /usr/bin/perl5.* \
              /usr/bin/openssl /usr/lib/ssl/misc

# 从 builder 层拷贝运行时增量：warp 二进制 + 全部依赖库 + GOST
COPY --from=builder /out/ /

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/check-status.sh /app/check-status.sh
COPY scripts/unlock-check.sh /app/unlock-check.sh

RUN chmod 0755 /entrypoint.sh /app/check-status.sh /app/unlock-check.sh \
    # /etc/localtime 在 slim 镜像里是指向 zoneinfo/Etc/UTC 的符号链接，必须先移除，
    # 否则 cp 会沿链接写穿、留下悬空链接
    && rm -f /etc/localtime \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    # tzdata 完整 zoneinfo 约 12MB；默认时区固定为 Asia/Shanghai，仅保留该条目
    # （如需其他时区，在 entrypoint 中通过 TZ 环境变量引用 /etc/localtime 即可，
    #  或挂载宿主机 /usr/share/zoneinfo 覆盖）
    && find /usr/share/zoneinfo -mindepth 1 -delete \
    && mkdir -p /usr/share/zoneinfo/Asia \
    && cp /etc/localtime /usr/share/zoneinfo/Asia/Shanghai \
    && mkdir -p /logs /var/lib/cloudflare-warp \
    # 运行时断言：warp 二进制与 GOST 必须存在且可执行
    && test -x /usr/local/bin/warp-svc \
    && test -x /usr/local/bin/warp-cli \
    && test -x /usr/local/bin/gost \
    && test -x /usr/local/bin/curl

# 注册状态持久化目录（warp-svc 数据目录；挂载宿主机 ./config 可跨容器重启保留账户）
VOLUME ["/var/lib/cloudflare-warp"]

EXPOSE 40000/tcp

ENTRYPOINT ["/entrypoint.sh"]

# ------------------------------------------------------------------------------
# Stage 3: flatten —— 重组文件系统到空镜像，物理压平全部历史层
#
#   Stage 2 里对基础镜像文件的删除（apt/perl/gconv/openssl 等）只是 whiteout
#   标记：docker images 的体积仍按基础层原始文件计费，rm 不减重。本阶段把
#   最终文件系统整体 COPY 进 scratch，被删除的文件真正从镜像中消失，同时
#   合并全部历史层。预期额外收益 ~30MB。
#
#   注意：scratch 无 shell，后续无法 docker exec 进容器调试——需要排障时用
#   `docker build --target runtime` 构建带 shell 的中间层镜像即可。
# ------------------------------------------------------------------------------
FROM scratch

ENV TZ=Asia/Shanghai

# 最终文件系统整体迁移（含 entrypoint 脚本、warp 二进制与全部依赖库）
COPY --from=runtime / /

VOLUME ["/var/lib/cloudflare-warp"]

EXPOSE 40000/tcp

ENTRYPOINT ["/entrypoint.sh"]

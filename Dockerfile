# syntax=docker/dockerfile:1.7
# ==============================================================================
# warp-unlock v2.0 — 官方 Cloudflare WARP 客户端 (MASQUE) 极简架构
#
# 与 v1.x (WGCF + wireguard-go) 的根本区别：
#   * 不创建 TUN 虚拟网卡 —— 无需 /dev/net/tun；仅需 NET_ADMIN capability
#     （新版 warp-svc 连接建立后会安装 fwmark 策略路由规则，官方客户端硬性要求）；
#   * 使用 Cloudflare 官方 warp-svc 守护进程，走 MASQUE 协议（官方 proxy 模式唯一支持协议）；
#   * GOST 作为前端：同端口 auto 协议（SOCKS5 / SOCKS4 / HTTP CONNECT）+ 可选认证。
#
# 分层构建（Multi-stage）：
#   Stage 1 builder —— 接入官方源仅下载 cloudflare-warp deb 并解压核心二进制，
#          按 ldd 精确提取 warp-svc / warp-cli 的无 GUI 依赖闭包与 libtss2-*；
#          彻底剔除 /usr/lib/warp（Flutter 桌面 GUI 资产，~42MB）；
#          GOST 与 静态 curl 一并在 builder 内下载、校验与 UPX 压缩。
#   Stage 2 runtime —— 极简 Debian 运行时，安装 ca-certificates / tzdata / dbus，
#          深度剔除 apt/dpkg/perl/systemd/gconv 等系统冗余（适配多架构通配符）。
#   Stage 3 flatten —— 重组根文件系统到 scratch 空镜像，物理消除历史层与已删除文件。
#          （保留完整 /bin/bash 与 coreutils，完全支持 docker exec 调试）。
# ==============================================================================

ARG DEBIAN_RELEASE=bookworm

# ------------------------------------------------------------------------------
# Stage 1: builder —— 提取最小依赖闭包
# ------------------------------------------------------------------------------
FROM docker.io/debian:${DEBIAN_RELEASE}-slim AS builder

ARG DEBIAN_RELEASE
ARG GOST_VERSION=3.3.3
# 静态 curl（stunnel/static-curl 项目，替代 apt curl 及其 ~20MB 动态依赖闭包）；
# SHA256 取自 release 页官方 checksums，构建期强校验
ARG CURL_STATIC_VERSION=8.23.0-1
ARG CURL_STATIC_SHA256_AMD64=b19756efa22538f0af3bb293626841c9dbf0d168489a1924f0e3edec2f560ba6
ARG CURL_STATIC_SHA256_ARM64=71780652d4e4de42bc0f2138cb764c90a7f8d4b64969450dd1dde5518cc5ff09
ARG UPX_VERSION=4.2.4
# UPX 同时压缩 warp-svc（默认 1 开启，镜像 ~100MB vs ~145MB）。warp-svc 为
# 常驻守护进程，如运行异常可用 --build-arg UPX_WARP_SVC=0 回退不压缩版本
ARG UPX_WARP_SVC=1
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    # 仅安装 warp-svc 真正的动态链接依赖，绝不装 WebKitGTK / GTK3 等桌面全家桶
    # 实测（deb 2026.8.2115.0）warp-svc 的 DT_NEEDED 全集仅：
    #   libtss2-esys.so.0 / libtss2-tctildr.so.0 / libtss2-mu.so.0 /
    #   libdbus-1.so.3 / libnss3.so / libsmime3.so / libgcc_s / libm / libc
    # 下列包即可全部覆盖（libtss2-mu0、libsmime3 由 Depends 自动带入）；
    # warp-cli 只依赖 libc/libm/libgcc_s。无 libpcap / nftables / setcap 动态依赖
    # （deb 声明的 iproute2 / nftables / gnupg2 / libcap2-bin / libwebkit2gtk
    #   全是桌面端或 postinst 用，warp-svc 运行时不加载，故一律不装）
    apt-get install -y --no-install-recommends \
        ca-certificates curl binutils xz-utils \
        libdbus-1-3 libtss2-esys-3.0.2-0 libtss2-tctildr0 libnss3; \
    # 接入 Cloudflare 官方 APT 源（bookworm 的 apt 支持直接引用 armored 密钥，无需 gnupg）
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
      -o /etc/apt/keyrings/cloudflare-warp.asc; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/cloudflare-warp.asc] https://pkg.cloudflareclient.com/ ${DEBIAN_RELEASE} main" \
      > /etc/apt/sources.list.d/cloudflare-client.list; \
    apt-get update; \
    # ---------- 仅下载 deb 并解包核心二进制（避免拉取 ~400MB GUI 依赖） ----------
    mkdir -p /tmp/cf-deb /tmp/cf; \
    (cd /tmp/cf-deb && apt-get download cloudflare-warp); \
    dpkg -x /tmp/cf-deb/cloudflare-warp_*.deb /tmp/cf; \
    find /tmp/cf -type f -name warp-svc -exec cp {} /usr/bin/warp-svc \;; \
    find /tmp/cf -type f -name warp-cli -exec cp {} /usr/bin/warp-cli \;; \
    rm -rf /tmp/cf-deb /tmp/cf; \
    # ---------- 拷贝 warp 二进制及其全部传递动态库依赖 ----------
    mkdir -p /out; \
    for bin in /usr/bin/warp-svc /usr/bin/warp-cli; do \
      cp --parents "$bin" /out/; \
      # 断言：新流程不再 apt install 整个包，缺库时 ldd 只输出 "not found"，
      # 会被下面的 awk 静默跳过 —— 构建成功但运行时报
      # "error while loading shared libraries"。必须在构建期硬失败。
      if ldd "$bin" 2>/dev/null | grep -q 'not found'; then \
        echo "错误：${bin} 存在未满足的动态依赖（官方新版 deb 可能新增了库，请补齐上方 apt 清单）："; \
        ldd "$bin" | grep 'not found'; \
        exit 1; \
      fi; \
      ldd "$bin" 2>/dev/null \
        | awk '{if ($3 ~ /^\//) print $3; else if ($1 ~ /^\//) print $1}' \
        | sort -u > /tmp/libs.txt; \
      while read -r lib; do cp --parents "$lib" /out/; done < /tmp/libs.txt; \
    done; \
    # warp-svc 运行时 dlopen 的 TPM2 驱动库（ldd 静态解析不到，必须显式带上）
    for lib in /usr/lib/*/libtss2*; do \
      [ -e "$lib" ] && cp --parents "$lib" /out/ || true; \
    done; \
    # 不再拷贝 /usr/lib/warp（582 个文件的 Flutter 桌面托盘资源，48.9MB）：
    # 实测 warp-svc / warp-cli 二进制内 "/usr/lib/warp" 出现 0 次，纯 GUI 资产。
    # 官方 deb 也不含 /etc/cloudflare-warp，二进制同样不引用，无需拷贝。
    # ---------- merged-usr 归一化 ----------
    for d in bin sbin lib lib64; do \
      if [ -d "/out/$d" ]; then \
        mkdir -p "/out/usr/$d"; \
        cp -a "/out/$d/." "/out/usr/$d/"; \
        rm -rf "/out/$d"; \
      fi; \
    done; \
    # ---------- 下载 GOST（静态单文件，用于前端 auto 协议与可选认证） ----------
    GOST_MAJOR="${GOST_VERSION%%.*}"; \
    case "${TARGETARCH}:${GOST_MAJOR}" in \
      amd64:3) GOST_URL="https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_amd64.tar.gz"; GOST_PKG=tar.gz ;; \
      arm64:3) GOST_URL="https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_arm64.tar.gz"; GOST_PKG=tar.gz ;; \
      amd64:2) GOST_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-amd64-${GOST_VERSION}.gz"; GOST_PKG=gz ;; \
      arm64:2) GOST_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-armv8-${GOST_VERSION}.gz"; GOST_PKG=gz ;; \
      *) echo "不支持的组合: arch=${TARGETARCH} gost=${GOST_VERSION}"; exit 1 ;; \
    esac; \
    echo ">>> GOST ${GOST_VERSION} (${GOST_PKG}) <- ${GOST_URL}"; \
    curl -fsSL --retry 3 "${GOST_URL}" -o "/tmp/gost.${GOST_PKG}"; \
    mkdir -p /out/usr/local/bin; \
    if [ "${GOST_PKG}" = "tar.gz" ]; then \
      mkdir -p /tmp/gostx; \
      tar -xzf "/tmp/gost.${GOST_PKG}" -C /tmp/gostx; \
      GOST_BIN="$(find /tmp/gostx -type f -name gost | head -n1)"; \
      test -n "${GOST_BIN}"; \
      install -m 0755 "${GOST_BIN}" /out/usr/local/bin/gost; \
      rm -rf /tmp/gostx; \
    else \
      gzip -dc "/tmp/gost.${GOST_PKG}" > /out/usr/local/bin/gost; \
      chmod 0755 /out/usr/local/bin/gost; \
    fi; \
    rm -f "/tmp/gost.${GOST_PKG}"; \
    # ---------- 剥离符号表与调试信息 ----------
    if command -v strip >/dev/null 2>&1; then \
      echo ">>> strip 前体积: $(du -sh /out | cut -f1)"; \
      find /out -type f \( -perm /111 -o -name '*.so*' \) \
        -exec strip --strip-unneeded {} + 2>/dev/null || true; \
      echo ">>> strip 后体积: $(du -sh /out | cut -f1)"; \
    fi; \
    WARP_SVC="$(find /out -name warp-svc -type f | head -n1 | sed "s|^/out||")"; \
    WARP_CLI="$(find /out -name warp-cli -type f | head -n1 | sed "s|^/out||")"; \
    echo ">>> warp-svc 路径: ${WARP_SVC}"; \
    echo ">>> warp-cli 路径: ${WARP_CLI}"; \
    test -n "$WARP_SVC" && test -n "$WARP_CLI"; \
    chmod 0755 "/out${WARP_SVC}" "/out${WARP_CLI}"; \
    # ---------- UPX 压缩（--best --lzma 极致压缩率） ----------
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
    /tmp/upx/upx -q --best --lzma /out/usr/local/bin/gost || true; \
    /tmp/upx/upx -q --best --lzma "/out${WARP_CLI}" || true; \
    if [ "${UPX_WARP_SVC}" = "1" ]; then \
      /tmp/upx/upx -q --best --lzma "/out${WARP_SVC}" || true; \
    fi; \
    echo ">>> UPX 后:"; ls -lh /out/usr/local/bin/gost "/out${WARP_CLI}" "/out${WARP_SVC}" | awk '{print $5, $9}'; \
    # ---------- 静态 curl ----------
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
    echo "${CURL_SHA256}  /out/usr/local/bin/curl" | sha256sum -c -; \
    /tmp/upx/upx -q --best --lzma /out/usr/local/bin/curl || true; \
    chmod 0755 /out/usr/local/bin/curl; \
    rm -rf /tmp/upx /tmp/upx.tar.xz; \
    SVC_REL="$(realpath --relative-to="/out/usr/local/bin" "/out${WARP_SVC}")"; \
    CLI_REL="$(realpath --relative-to="/out/usr/local/bin" "/out${WARP_CLI}")"; \
    ln -sf "$SVC_REL" /out/usr/local/bin/warp-svc; \
    ln -sf "$CLI_REL" /out/usr/local/bin/warp-cli; \
    test -x /out/usr/local/bin/warp-svc; \
    test -x /out/usr/local/bin/warp-cli; \
    echo ">>> /out 总体积: $(du -sh /out | cut -f1)"; \
    du -xh -d2 /out/usr | sort -rh | head -12; \
    rm -rf /var/cache/apt/archives/*.deb /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ------------------------------------------------------------------------------
# Stage 2: runtime —— 极简运行时与系统冗余裁剪
# ------------------------------------------------------------------------------
FROM docker.io/debian:${DEBIAN_RELEASE}-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates tzdata dbus; \
    # 精简时区文件（仅保留 Asia/Shanghai，节约 ~12MB）
    rm -f /etc/localtime; \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    echo "Asia/Shanghai" > /etc/timezone; \
    find /usr/share/zoneinfo -mindepth 1 -delete; \
    mkdir -p /usr/share/zoneinfo/Asia; \
    cp /etc/localtime /usr/share/zoneinfo/Asia/Shanghai; \
    # 清理包管理器及文档缓存（节约 ~15MB）
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/* \
           /usr/share/doc/* /usr/share/man/* /usr/share/info/* /usr/share/locale/* \
           /var/lib/dpkg/info/* /var/cache/* \
           /usr/bin/apt* /usr/bin/dpkg* /usr/lib/apt /usr/lib/dpkg \
           /var/lib/dpkg /var/lib/apt /etc/apt \
    # 彻底移除基础镜像残留无用组件与非必需重型运维工具（适配多架构通配符，节约 ~35-45MB）
    && rm -rf /usr/lib/*-linux-gnu/gconv \
              /usr/lib/*-linux-gnu/perl-base \
              /usr/share/perl* /usr/lib/perl* \
              /usr/bin/perl* \
              /usr/bin/openssl /usr/lib/ssl/misc \
              /usr/lib/systemd /lib/systemd \
              /usr/lib/udev /usr/share/lintian /usr/share/bug /etc/init.d /etc/cron* \
              /usr/bin/tar /usr/bin/diff* /usr/bin/cmp /usr/bin/xz* /usr/bin/lzma* \
              /usr/bin/gzip /usr/bin/gunzip /usr/bin/zcat /usr/bin/bzip2* \
              /usr/sbin/fdisk* /usr/sbin/cfdisk* /usr/sbin/sfdisk* /usr/sbin/mkfs* \
              /usr/sbin/tune2fs /usr/sbin/mke2fs /usr/sbin/e2fsck /usr/sbin/badblocks \
              /usr/bin/lsblk /usr/bin/lscpu /usr/bin/dmesg /usr/bin/chcpu \
              /usr/bin/renice /usr/bin/ionice /usr/bin/flock /usr/bin/losetup \
              /usr/bin/wall /usr/bin/mesg /usr/bin/script* /usr/bin/more /usr/bin/less \
              /usr/sbin/chroot /usr/sbin/group* /usr/sbin/user* /usr/sbin/vipw /usr/sbin/vigr

# 从 builder 层拷贝运行时增量：warp 二进制 + 全部依赖库 + GOST + 静态 curl
COPY --from=builder /out/ /

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/check-status.sh /app/check-status.sh
COPY scripts/unlock-check.sh /app/unlock-check.sh

RUN chmod 0755 /entrypoint.sh /app/check-status.sh /app/unlock-check.sh \
    && mkdir -p /logs /var/lib/cloudflare-warp \
    # 运行时断言：核心二进制与工具必须就绪且可执行
    && test -x /usr/local/bin/warp-svc \
    && test -x /usr/local/bin/warp-cli \
    && test -x /usr/local/bin/gost \
    && test -x /usr/local/bin/curl

# ------------------------------------------------------------------------------
# Stage 3: flatten —— 重组文件系统到空镜像，物理压平全部历史层并剥离已删除文件
#
#   提示：容器完整保留了 /bin/bash 与 coreutils，完全支持
#   `docker compose exec cloudflare-warp-unlock bash` 直接进入容器排障调试。
# ------------------------------------------------------------------------------
FROM scratch

ENV TZ=Asia/Shanghai

# 最终文件系统整体迁移（含 entrypoint 脚本、warp 二进制与全部依赖库）
COPY --from=runtime / /

VOLUME ["/var/lib/cloudflare-warp"]

EXPOSE 40000/tcp

ENTRYPOINT ["/entrypoint.sh"]

# syntax=docker/dockerfile:1.7
# ==============================================================================
# warp-unlock v2.0 — 官方 Cloudflare WARP 客户端 (MASQUE) 架构
#
# 与 v1.x (WGCF + wireguard-go) 的根本区别：
#   * 不创建 TUN 虚拟网卡，不修改任何路由表 —— 无需 /dev/net/tun、无需 NET_ADMIN，
#     容器除 Docker 默认能力外零特权，可运行在任何能跑 Docker 的环境；
#   * 使用 Cloudflare 官方 warp-svc 守护进程，走 MASQUE 协议（官方 proxy 模式唯一支持协议）；
#   * GOST 作为前端：同端口 auto 协议（SOCKS5 / SOCKS4 / HTTP CONNECT）+ 可选认证。
# ==============================================================================

ARG DEBIAN_RELEASE=bookworm
FROM docker.io/debian:${DEBIAN_RELEASE}-slim

ARG DEBIAN_RELEASE
ARG GOST_VERSION=2.11.5
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      gnupg ca-certificates curl socat tzdata; \
    # 接入 Cloudflare 官方 APT 源，安装 warp-svc / warp-cli
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
      | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${DEBIAN_RELEASE} main" \
      > /etc/apt/sources.list.d/cloudflare-client.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends cloudflare-warp; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/*

# 下载 GOST（静态单文件，用于前端 auto 协议与可选认证）
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) GOST_ARCH=amd64 ;; \
      arm64) GOST_ARCH=armv8 ;; \
      *) echo "不支持的构建架构: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL --retry 3 \
      "https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz" \
      -o /tmp/gost.gz; \
    gzip -dc /tmp/gost.gz > /usr/local/bin/gost; \
    chmod 0755 /usr/local/bin/gost; \
    rm -f /tmp/gost.gz

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/check-status.sh /app/check-status.sh

RUN chmod 0755 /entrypoint.sh /app/check-status.sh \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 注册状态持久化目录（warp-svc 数据目录；挂载宿主机 ./config 可跨容器重启保留账户）
VOLUME ["/var/lib/cloudflare-warp"]

EXPOSE 40000/tcp

ENTRYPOINT ["/entrypoint.sh"]

# syntax=docker/dockerfile:1.7

# ==============================================================================
# 第一阶段：编译与外部核心组件下载（多阶段构建，不污染最终镜像）
# 借助 --platform=$BUILDPLATFORM 启用 Go 原生极速交叉编译，规避 QEMU 模拟器性能开销
# ==============================================================================
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG WGCF_VERSION=2.2.32
ARG GOST_VERSION=2.11.5

# 安装构建与下载必需工具
RUN apk add --no-cache curl gzip

# 1. 编译纯静态、已剥离调试信息的 wireguard-go
RUN set -eux; \
    GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} CGO_ENABLED=0 \
    go install -v -ldflags="-s -w" golang.zx2c4.com/wireguard@latest; \
    mkdir -p /output/bin; \
    find /go/bin -type f -exec cp {} /output/bin/wireguard-go \;

# 2. 按架构下载 WGCF 与 GOST 并保存
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) WGCF_ARCH=amd64; GOST_ARCH=amd64 ;; \
      arm64) WGCF_ARCH=arm64; GOST_ARCH=armv8 ;; \
      *) echo "不支持的构建架构: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fL --retry 3 \
      "https://github.com/ViRb3/wgcf/releases/download/v${WGCF_VERSION}/wgcf_${WGCF_VERSION}_linux_${WGCF_ARCH}" \
      -o /output/bin/wgcf; \
    chmod 0755 /output/bin/wgcf; \
    curl -fL --retry 3 \
      "https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz" \
      -o /tmp/gost.gz; \
    gzip -dc /tmp/gost.gz > /output/bin/gost; \
    chmod 0755 /output/bin/gost; \
    rm -f /tmp/gost.gz

# ==============================================================================
# 第二阶段：极致精简瘦身的 Alpine 运行时镜像
# ==============================================================================
FROM alpine:3.21

ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LC_ALL=C.UTF-8 \
    WG_I_PREFER_BUGGY_USERSPACE_TO_POLISHED_KMOD=1

# 仅保留严格必需的核心运行时组件：
# - bash: 启动与管理脚本执行环境
# - ca-certificates & curl: WARP 与在线拉取/流媒体检测连接
# - iproute2: ip 与 ss 工具
# - wireguard-tools: wg 命令行工具
# - iptables: 隧道策略与 NAT 标记
# - tzdata: 完整时区数据库（确保 Alpine musl libc 正确解析 Asia/Shanghai 时区）
RUN set -eux; \
    apk add --no-cache \
      bash \
      ca-certificates \
      curl \
      iproute2 \
      wireguard-tools \
      iptables \
      tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && rm -rf /var/cache/apk/* /tmp/* \
    && mkdir -p /etc/wireguard /data /data/cron /data/logs /app \
                 /var/spool/cron/crontabs /root /var/run/wireguard

# 从构建阶段一键复制准备好的纯静态二进制文件 (wireguard-go, wgcf, gost)
COPY --from=builder /output/bin/* /usr/local/bin/

# 备份原始 wg-quick（若存在）
RUN if [ -f /usr/bin/wg-quick ]; then mv /usr/bin/wg-quick /usr/bin/wg-quick.orig; fi

# 将当前脚本打包进镜像作为离线降级保底（仅 60KB，零外部网络依赖）
COPY scripts/warp-unlock.sh /app/warp-unlock.fallback.sh

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/wireguard-manager.sh /app/wireguard-manager.sh
COPY scripts/wg-quick /usr/local/bin/wg-quick
COPY scripts/setup-unlock.sh /app/setup-unlock.sh
COPY scripts/check-status.sh /app/check-status.sh

RUN chmod 0755 /entrypoint.sh \
               /app/wireguard-manager.sh \
               /usr/local/bin/wg-quick \
               /app/setup-unlock.sh \
               /app/check-status.sh \
               /app/warp-unlock.fallback.sh

WORKDIR /etc/wireguard
ENTRYPOINT ["/entrypoint.sh"]

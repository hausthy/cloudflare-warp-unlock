#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

mkdir -p /etc/wireguard /data/cron /data/logs /var/spool/cron/crontabs /logs /var/run/wireguard
chmod 700 /etc/wireguard

# 确保 /dev/net/tun 设备可用（wireguard-go 必须依赖此设备）
if [[ ! -c /dev/net/tun ]]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200 2>/dev/null || true
  chmod 600 /dev/net/tun 2>/dev/null || true
fi

# 将上游 unlock.sh 固定写入的路径映射到持久化目录。
# 使用符号链接，不修改上游脚本逻辑。
ln -sfn /data/warp_unlock.sh /usr/bin/warp_unlock.sh
ln -sfn /data/status.log /usr/bin/status.log
ln -sfn /data/result.log /root/result.log

cd /etc/wireguard

# ==============================================================================
# WARP+ License 绑定：通过 WARP_LICENSE 环境变量将账户升级为 WARP+
# ==============================================================================
# 已应用的 License 记录保存在持久化目录（./config/wgcf-license），
# 环境变量与记录不一致时自动重新绑定，一致时跳过，避免每次重启都请求 API。
LICENSE_FILE="/etc/wireguard/wgcf-license"

apply_warp_license() {
  local license="${WARP_LICENSE:-}"

  # 未配置 License：跳过绑定（不会自动降级，已绑定的 plus 保持不变）
  if [[ -z "$license" ]]; then
    [[ -s "$LICENSE_FILE" ]] && log "账户已绑定 WARP+ License（环境变量为空，保持现状）"
    return 0
  fi

  # 校验格式：26 位字符，8-8-8 三段
  if [[ ! "$license" =~ ^[A-Za-z0-9]{8}-[A-Za-z0-9]{8}-[A-Za-z0-9]{8}$ ]]; then
    log "错误：WARP_LICENSE 格式不合法（应为 26 位字符，形如 xxxxxxxx-xxxxxxxx-xxxxxxxx），跳过绑定"
    return 0
  fi

  # License 未变更且账户文件存在：无需重复绑定
  if [[ -s "$LICENSE_FILE" && -s /etc/wireguard/wgcf-account.toml ]] &&
     [[ "$(cat "$LICENSE_FILE" 2>/dev/null || true)" == "$license" ]]; then
    log "WARP+ License 未变更，跳过绑定"
    return 0
  fi

  log "正在将 WARP+ License 绑定到当前 WARP 账户"
  if wgcf update --license-key "$license"; then
    printf '%s' "$license" > "$LICENSE_FILE"
    chmod 600 "$LICENSE_FILE"
    log "WARP+ License 绑定成功，账户已升级为 WARP+"
  else
    log "错误：WARP+ License 绑定失败（License 无效、绑定设备数已满或网络异常），本次以免费账户继续运行"
    log "提示：请检查 WARP_LICENSE 后重启容器重试；如需彻底重置账户，可清空 ./config 后重新启动"
    rm -f "$LICENSE_FILE"
  fi
}

# 首次启动注册免费 WARP 账户；账号文件保存在宿主机 ./config
if [[ ! -s /etc/wireguard/wgcf-account.toml ]]; then
  log "首次启动：注册 WARP 账户"
  wgcf register --accept-tos
fi

# 绑定 WARP+ License（如配置了 WARP_LICENSE；须在生成配置前执行，确保首次即生成 plus 账户配置）
apply_warp_license

# 生成 WireGuard 配置。wgcf 默认生成 wgcf-profile.conf。
if [[ ! -s /etc/wireguard/wgcf.conf ]]; then
  log "生成 WGCF WireGuard 配置"
  wgcf generate
  test -s /etc/wireguard/wgcf-profile.conf
  install -m 600 /etc/wireguard/wgcf-profile.conf /etc/wireguard/wgcf.conf
fi

chmod 600 /etc/wireguard/wgcf-account.toml /etc/wireguard/wgcf.conf

# ==============================================================================
# 配置适配：针对 wireguard-go 与容器化环境优化
# ==============================================================================
# 1. 注释掉配置中的 DNS 行，由自主脚本统一管理，防止触发 resolvconf 报错
sed -i -E 's/^[[:space:]]*DNS[[:space:]]*=/# &/' /etc/wireguard/wgcf.conf

# 2. 确保配置包含标准 MTU 1280
if ! grep -q -E '^[[:space:]]*MTU' /etc/wireguard/wgcf.conf; then
  sed -i '/\[Interface\]/a MTU = 1280' /etc/wireguard/wgcf.conf
fi

# 3. 检查 IPv6 环境兼容性：若当前容器未启用 IPv6，则降级为 IPv4 单栈，防止路由报错
if ! ip -6 route show >/dev/null 2>&1; then
  log "检测到容器未开启 IPv6 栈，自动对 wgcf.conf 屏蔽 IPv6 配置以兼容"
  sed -i -E 's/^[[:space:]]*Address[[:space:]]*=.*:.*$/# &/' /etc/wireguard/wgcf.conf
  sed -i -E 's/^[[:space:]]*AllowedIPs[[:space:]]*=.*::.*$/# &/' /etc/wireguard/wgcf.conf
fi

# 4. 必须包含基础默认出站路由
if ! grep -q '0.0.0.0/0' /etc/wireguard/wgcf.conf; then
  log "错误：wgcf.conf 未包含 0.0.0.0/0 AllowedIPs，停止启动"
  exit 1
fi

# 启动用户态 WireGuard 接口
if ! ip link show wgcf >/dev/null 2>&1; then
  log "启动容器网络命名空间内的 WGCF 用户态接口 (wireguard-go)"
  /app/wireguard-manager.sh up wgcf
fi

# 启动 GOST SOCKS5 服务
log "启动 GOST SOCKS5 :40000"
gost -L :40000 >> /logs/gost.log 2>&1 &
GOST_PID=$!

# 仅在 WARP 隧道已经能访问 Cloudflare trace 时，自动初始化解锁任务。
# 若初次网络暂不可用，不阻断 SOCKS5 服务；可稍后手动执行 setup-unlock.sh。
if [[ "${WARP_AUTO_SETUP:-1}" == "1" && ! -s /data/warp_unlock.sh ]]; then
  if curl -4 -ksm8 --interface wgcf https://www.cloudflare.com/cdn-cgi/trace |
       grep -Eq '^warp=(on|plus)$' ||
     curl -6 -ksm8 --interface wgcf https://www.cloudflare.com/cdn-cgi/trace |
       grep -Eq '^warp=(on|plus)$'; then
    log "检测到 WARP 已连通，初始化 unlock.sh 定时任务"
    /app/setup-unlock.sh || log "警告：unlock.sh 自动初始化失败，可稍后手动重试"
  else
    log "WARP trace 尚未连通，暂不初始化解锁任务；SOCKS5 仍会启动"
  fi
fi

# BusyBox crond 在容器内以前台方式运行；不依赖 OpenRC/systemd。
log "启动 crond 守护进程"
trap 'kill "${GOST_PID}" 2>/dev/null || true; /app/wireguard-manager.sh down wgcf || true' TERM INT
crond -f -l 2

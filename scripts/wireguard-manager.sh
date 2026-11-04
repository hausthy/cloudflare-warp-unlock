#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[%s] [wireguard-manager] %s\n' "$(date '+%F %T')" "$*"
}

IFACE="${2:-wgcf}"
CONF_FILE="/etc/wireguard/${IFACE}.conf"
STATE_DIR="/var/run/wireguard"
mkdir -p "$STATE_DIR" /etc/wireguard

resolve_ip() {
  local target="$1"
  # 如果已经是 IPv4 地址直接返回
  if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$target"
    return 0
  fi
  # 使用 getent 或 nslookup 解析域名
  local ip
  ip="$(getent ahosts "$target" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
  if [[ -z "$ip" ]]; then
    ip="$(nslookup "$target" 2>/dev/null | awk '/^Address: / {print $2}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
  fi
  if [[ -n "$ip" ]]; then
    echo "$ip"
  else
    # Cloudflare 常用 Anycast IP 保底
    echo "162.159.192.1"
  fi
}

cmd_up() {
  log "正在启动用户态 WireGuard 接口: ${IFACE}"

  if [[ ! -f "$CONF_FILE" ]]; then
    log "错误: 配置文件 ${CONF_FILE} 不存在"
    exit 1
  fi

  # 1. 确保 /dev/net/tun 可用
  if [[ ! -c /dev/net/tun ]]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200 2>/dev/null || true
    chmod 600 /dev/net/tun 2>/dev/null || true
  fi

  # 2. 如果接口已存在，先优雅停止
  if ip link show dev "$IFACE" >/dev/null 2>&1; then
    log "接口 ${IFACE} 已存在，先执行清理关闭"
    cmd_down || true
  fi

  # 3. 解析配置参数
  local mtu endpoint_raw endpoint_host endpoint_port endpoint_ip
  mtu="$(grep -E '^[[:space:]]*MTU' "$CONF_FILE" | awk -F '=' '{print $2}' | tr -d ' ' || true)"
  [[ -n "$mtu" ]] || mtu=1280

  endpoint_raw="$(grep -E '^[[:space:]]*Endpoint' "$CONF_FILE" | head -n 1 | awk -F '=' '{print $2}' | tr -d ' ' || true)"
  if [[ -n "$endpoint_raw" ]]; then
    endpoint_host="${endpoint_raw%:*}"
    endpoint_port="${endpoint_raw##*:}"
    endpoint_ip="$(resolve_ip "$endpoint_host")"
    log "WARP 对端 Endpoint: ${endpoint_host}:${endpoint_port} -> 解析为 IP: ${endpoint_ip}"
    echo "$endpoint_ip" > "${STATE_DIR}/${IFACE}.endpoint_ip"
  else
    endpoint_ip=""
  fi

  # 4. 生成 wireguard-go 专用的纯净配置（过滤掉 Address, DNS, MTU 等非底层参数）
  local stripped_conf="${STATE_DIR}/${IFACE}.stripped.conf"
  grep -v -E '^[[:space:]]*(Address|DNS|MTU|Table|PreUp|PostUp|PreDown|PostDown)[[:space:]]*=' "$CONF_FILE" > "$stripped_conf"
  if [[ -n "$endpoint_ip" && -n "$endpoint_port" ]]; then
    # 将域名替换为确切 IP，避免 wireguard-go 内部解析失败
    sed -i -E "s|^[[:space:]]*Endpoint[[:space:]]*=.*|Endpoint = ${endpoint_ip}:${endpoint_port}|" "$stripped_conf"
  fi
  chmod 600 "$stripped_conf"

  # 5. 启动 wireguard-go
  log "启动 wireguard-go 用户态进程"
  wireguard-go "$IFACE"

  # 等待虚拟 TUN 设备在内核中生成
  local ready=0
  for _ in $(seq 1 30); do
    if ip link show dev "$IFACE" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 0.1
  done

  if [[ "$ready" -ne 1 ]]; then
    log "错误: wireguard-go 创建接口 ${IFACE} 超时"
    exit 1
  fi

  # 6. 配置密钥与对端参数
  wg setconf "$IFACE" "$stripped_conf"

  # 7. 设置 MTU 并启动网络接口
  ip link set dev "$IFACE" mtu "$mtu" up

  # 8. 分配 IP 地址
  mapfile -t ipv4_addrs < <(grep -E '^[[:space:]]*Address[[:space:]]*=' "$CONF_FILE" | awk -F '=' '{print $2}' | tr -d ' ' | tr ',' '\n' | grep -F '.' || true)
  mapfile -t ipv6_addrs < <(grep -E '^[[:space:]]*Address[[:space:]]*=' "$CONF_FILE" | awk -F '=' '{print $2}' | tr -d ' ' | tr ',' '\n' | grep -F ':' || true)

  for addr in "${ipv4_addrs[@]}"; do
    [[ -n "$addr" ]] || continue
    log "添加 IPv4 地址: ${addr} 到 ${IFACE}"
    ip -4 addr add "$addr" dev "$IFACE"
  done

  for addr in "${ipv6_addrs[@]}"; do
    [[ -n "$addr" ]] || continue
    log "添加 IPv6 地址: ${addr} 到 ${IFACE}"
    ip -6 addr add "$addr" dev "$IFACE" 2>/dev/null || log "警告: 添加 IPv6 地址 ${addr} 失败（容器可能未开启 IPv6 支持）"
  done

  # 9. 智能路由管理（防回环与 GOST 隔离）
  local eth0_gw eth0_dev eth0_ip
  eth0_dev="$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -n 1 || true)"
  [[ -n "$eth0_dev" ]] || eth0_dev="eth0"
  eth0_gw="$(ip -4 route show default dev "$eth0_dev" 2>/dev/null | awk '{print $3}' | head -n 1 || true)"
  eth0_ip="$(ip -4 -o addr show dev "$eth0_dev" scope global 2>/dev/null | awk 'NR==1 {split($4,a,"/"); print a[1]}' || true)"

  # (1) 对端 Endpoint 直连路由：防止 WireGuard 自身的 UDP 报文打进隧道形成死循环
  if [[ -n "$endpoint_ip" && -n "$eth0_gw" ]]; then
    log "添加 Endpoint 静态出口路由: ${endpoint_ip}/32 via ${eth0_gw} dev ${eth0_dev}"
    ip -4 route add "${endpoint_ip}/32" via "$eth0_gw" dev "$eth0_dev" 2>/dev/null || true
  fi

  # (2) SOCKS5 回程策略路由：确保从 eth0 进来的客户端连接，响应报文原路返回 Docker 网桥，不进 WARP
  if [[ -n "$eth0_ip" ]]; then
    if ! ip -4 rule show | grep -Fq "from ${eth0_ip} lookup main"; then
      log "添加 SOCKS5 入站回程策略路由: from ${eth0_ip}/32 lookup main"
      ip -4 rule add priority 100 from "${eth0_ip}/32" lookup main
    fi
  fi

  # (3) 默认流量进 WARP：采用 0.0.0.0/1 + 128.0.0.0/1 双段路由
  # 优点：不冲垮或删除原有的 main 表默认路由，容错性最高，退出时易清理
  log "添加全局出站分段默认路由 (0.0.0.0/1, 128.0.0.0/1) -> ${IFACE}"
  ip -4 route add 0.0.0.0/1 dev "$IFACE"
  ip -4 route add 128.0.0.0/1 dev "$IFACE"

  if grep -q '::/0' "$CONF_FILE" 2>/dev/null; then
    ip -6 route add ::/1 dev "$IFACE" 2>/dev/null || true
    ip -6 route add 8000::/1 dev "$IFACE" 2>/dev/null || true
  fi

  # 10. DNS 自行管理：直接写入可靠的公共 DNS，不依赖宿主机或 openresolv
  if [[ ! -f /etc/resolv.conf.docker_orig ]]; then
    cp /etc/resolv.conf /etc/resolv.conf.docker_orig 2>/dev/null || true
  fi
  cat << 'EOF' > /etc/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
EOF
  log "已更新 /etc/resolv.conf 为 Cloudflare & Google DNS"

  log "WireGuard 用户态网络接口 ${IFACE} 启动完毕！"
}

cmd_down() {
  log "正在关闭用户态 WireGuard 接口: ${IFACE}"

  # 1. 清理路由
  ip -4 route del 0.0.0.0/1 dev "$IFACE" 2>/dev/null || true
  ip -4 route del 128.0.0.0/1 dev "$IFACE" 2>/dev/null || true
  ip -6 route del ::/1 dev "$IFACE" 2>/dev/null || true
  ip -6 route del 8000::/1 dev "$IFACE" 2>/dev/null || true

  if [[ -f "${STATE_DIR}/${IFACE}.endpoint_ip" ]]; then
    local endpoint_ip
    endpoint_ip="$(cat "${STATE_DIR}/${IFACE}.endpoint_ip" 2>/dev/null || true)"
    if [[ -n "$endpoint_ip" ]]; then
      ip -4 route del "${endpoint_ip}/32" 2>/dev/null || true
    fi
    rm -f "${STATE_DIR}/${IFACE}.endpoint_ip"
  fi

  # 2. 停用并删除接口
  ip link set dev "$IFACE" down 2>/dev/null || true
  pkill -f "wireguard-go.*${IFACE}" 2>/dev/null || true
  ip link del dev "$IFACE" 2>/dev/null || true

  # 3. 恢复原始 DNS
  if [[ -f /etc/resolv.conf.docker_orig ]]; then
    cp -f /etc/resolv.conf.docker_orig /etc/resolv.conf 2>/dev/null || true
  fi

  rm -f "${STATE_DIR}/${IFACE}.stripped.conf"
  log "WireGuard 用户态网络接口 ${IFACE} 已关闭"
}

cmd_status() {
  if ip link show dev "$IFACE" >/dev/null 2>&1; then
    echo "===== Interface ${IFACE} ====="
    ip addr show dev "$IFACE"
    echo
    echo "===== WireGuard Status ====="
    wg show "$IFACE"
  else
    echo "接口 ${IFACE} 未运行"
  fi
}

case "${1:-up}" in
  up)
    cmd_up
    ;;
  down)
    cmd_down
    ;;
  status)
    cmd_status
    ;;
  *)
    echo "用法: $0 [up|down|status] [interface_name]" >&2
    exit 1
    ;;
esac

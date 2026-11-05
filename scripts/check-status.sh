#!/usr/bin/env bash
set -u

echo "===== WGCF interface ====="
ip -brief addr show wgcf 2>/dev/null || true

echo
echo "===== WARP account ====="
if [[ -s /etc/wireguard/wgcf-account.toml ]]; then
  # 设备 ID 全量显示，License 仅显示首尾各 4 位避免完整泄露
  local_dev_id="$(grep -E '^device_id' /etc/wireguard/wgcf-account.toml 2>/dev/null | cut -d'"' -f2 || true)"
  [[ -n "$local_dev_id" ]] && echo "Device ID: $local_dev_id"
  if [[ -s /etc/wireguard/wgcf-license ]]; then
    lic="$(cat /etc/wireguard/wgcf-license)"
    echo "WARP+ License: 已绑定 (${lic:0:4}****${lic: -4})"
  else
    echo "WARP+ License: 未绑定（免费账户）"
  fi
else
  echo "未找到 wgcf-account.toml"
fi

echo
echo "===== wireguard-go process ====="
pgrep -fla "wireguard-go" || echo "未找到 wireguard-go 运行进程"

echo
echo "===== WireGuard status ====="
wg show wgcf 2>/dev/null || true

echo
echo "===== Policy rules ====="
ip -4 rule show
ip -6 rule show 2>/dev/null || true

echo
echo "===== Active Routes ====="
ip -4 route show
ip -6 route show 2>/dev/null || true

echo
echo "===== DNS (resolv.conf) ====="
cat /etc/resolv.conf 2>/dev/null || true

echo
echo "===== WARP trace IPv4 ====="
curl -4 -ksm10 --interface wgcf https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null |
  grep -E '^(ip|warp|loc)=' || echo "WARP IPv4 连接失败或未连通"

echo
echo "===== WARP trace IPv6 ====="
curl -6 -ksm10 --interface wgcf https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null |
  grep -E '^(ip|warp|loc)=' || echo "WARP IPv6 未启用或未连通"

echo
echo "===== SOCKS5 listener ====="
ss -lntp | grep ':40000' || true

echo
echo "===== Unlock cron ====="
cat /var/spool/cron/crontabs/root 2>/dev/null || true

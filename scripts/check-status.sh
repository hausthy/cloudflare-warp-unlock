#!/usr/bin/env bash
# warp-unlock v2.0 一键状态诊断（官方客户端 MASQUE 架构）
set -u

echo "===== WARP daemon ====="
warp-cli --accept-tos status 2>&1 || true

echo
echo "===== WARP settings ====="
warp-cli --accept-tos settings 2>&1 | head -n 20 || true

echo
echo "===== WARP account ====="
if warp-cli --accept-tos registration show 2>&1; then
  :
else
  echo "未获取到注册信息（可能未完成注册）"
fi

echo
echo "===== Tunnel trace (via :40000) ====="
trace="$(curl -ksm8 -x socks5h://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null || true)"
if [[ -n "$trace" ]]; then
  printf '%s\n' "$trace" | grep -E '^(warp|ip|loc|colo|MASQUE)=' || printf '%s\n' "$trace"
  if printf '%s\n' "$trace" | grep -q '^warp=plus$'; then
    echo ">>> 账户状态：WARP+ 已生效"
  elif printf '%s\n' "$trace" | grep -q '^warp=on$'; then
    echo ">>> 账户状态：WARP（免费）"
  fi
else
  echo "无法通过 :40000 获取 trace（代理或隧道可能未就绪）"
fi

echo
echo "===== Processes ====="
pgrep -fla "warp-svc" || echo "未找到 warp-svc 运行进程"
pgrep -fla "gost" || echo "未找到 gost 运行进程"

echo
echo "===== Listening ports ====="
ss -Hln "sport = :40000" 2>/dev/null || netstat -Hln 2>/dev/null | grep 40000 || true

echo
echo "===== Unlock checks (live) ====="
if [[ -x /app/unlock-check.sh ]]; then
  if UNLOCK_LOG=/dev/null /app/unlock-check.sh; then
    echo ">>> 全部检测通过"
  else
    echo ">>> 存在未通过项（巡检循环会自动轮换出口 IP）"
  fi
fi

echo
echo "===== Recent unlock log (last 5) ====="
tail -n 5 /logs/unlock.log 2>/dev/null || echo "暂无解锁检测记录"

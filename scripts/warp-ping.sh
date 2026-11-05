#!/usr/bin/env bash
set -e

# ==============================================================================
# WARP 链路延时与真实握手协议（IPv4/IPv6）探测工具
# 用法: warp-ping [目标URL或域名]
# 示例: warp-ping chatgpt.com
#       warp-ping https://netflix.com
# ==============================================================================

TARGET="${1:-https://chatgpt.com}"
if [[ ! "$TARGET" =~ ^https?:// ]]; then
  TARGET="https://${TARGET}"
fi

# 智能探测 SOCKS5 代理端口（优先环境变量，其次自动探测 19588 或 40000）
if [[ -z "${PROXY:-}" ]]; then
  if (ss -Hln "sport = :19588" 2>/dev/null | grep -q .) || (nc -z 127.0.0.1 19588 2>/dev/null); then
    PROXY="socks5://127.0.0.1:19588"
  elif (ss -Hln "sport = :40000" 2>/dev/null | grep -q .) || (nc -z 127.0.0.1 40000 2>/dev/null); then
    PROXY="socks5://127.0.0.1:40000"
  else
    PROXY="socks5://127.0.0.1:40000"
  fi
fi

# 核心：必须使用 socks5://（不带 h），由 curl 显式解析并向代理发起确切的 IPv4 / IPv6 建立请求
RAW_LOG=$(curl -s -Iv -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
  --proxy "${PROXY}" \
  "${TARGET}" \
  -w "\n__METRICS__|%{http_code}|%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}" 2>&1 || true)

CONNECT_LINE=$(echo "$RAW_LOG" | grep -i 'SOCKS5 connect to' | head -n 1 || true)
METRICS_LINE=$(echo "$RAW_LOG" | grep '^__METRICS__|' | tail -n 1 || true)

if [[ -n "$METRICS_LINE" ]]; then
  IFS='|' read -r _ HTTP_CODE T_DNS T_CONNECT T_APP T_TTFB T_TOTAL <<< "$METRICS_LINE"
else
  HTTP_CODE="000"
  T_DNS="0.000000"
  T_CONNECT="0.000000"
  T_APP="0.000000"
  T_TTFB="0.000000"
  T_TOTAL="0.000000"
fi

if echo "$CONNECT_LINE" | grep -qi 'IPv6'; then
  IP_TARGET=$(echo "$CONNECT_LINE" | sed -n 's/.*SOCKS5 connect to IPv6 \([^ ]*\).*/\1/p')
  ROUTE_STATUS="🟢 100% 实锤走【IPv6 纯净通道】 (${IP_TARGET})"
elif echo "$CONNECT_LINE" | grep -qi 'IPv4'; then
  IP_TARGET=$(echo "$CONNECT_LINE" | sed -n 's/.*SOCKS5 connect to IPv4 \([^ ]*\).*/\1/p')
  ROUTE_STATUS="🔵 100% 实锤走【IPv4 兼容通道】 (${IP_TARGET})"
else
  ROUTE_STATUS="⚪ 连接未建立或失败"
fi

echo "=================================================================="
echo " 🎯 测试目标: ${TARGET}"
echo " 🛡️ 代理通道: ${PROXY}"
echo " 🚀 底层实锤: ${ROUTE_STATUS}"
echo "=================================================================="
echo "HTTP 状态码:       ${HTTP_CODE}"
echo "------------------------------------------------------------------"
echo "1. DNS 解析耗时:     ${T_DNS} 秒"
echo "2. 代理建立连接:     ${T_CONNECT} 秒"
echo "3. TLS/SSL 握手:     ${T_APP} 秒"
echo "4. 首字节返回(TTFB): ${T_TTFB} 秒"
echo "------------------------------------------------------------------"
echo "总耗时 (Total):      ${T_TOTAL} 秒"
echo "=================================================================="

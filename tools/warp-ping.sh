#!/usr/bin/env bash
# ==============================================================================
# warp-ping.sh — WARP 链路延时与真实握手协议（IPv4/IPv6）探测工具
#
# 宿主机侧运维工具，不打包进镜像（Dockerfile 仅 COPY scripts/ 下三个脚本）。
#
# 用法:
#   ./tools/warp-ping.sh [选项] [目标URL或域名]
#
# 选项:
#   -p, --proxy <url>   代理地址（默认 socks5://127.0.0.1:40000）
#   -h, --help          显示帮助
#
# 环境变量:
#   PROXY               代理地址，等价于 -p，命令行参数优先级更高
#
# 示例:
#   ./tools/warp-ping.sh chatgpt.com
#   ./tools/warp-ping.sh https://netflix.com
#   ./tools/warp-ping.sh -p socks5://127.0.0.1:40000 chatgpt.com
#   PROXY=socks5://10.0.0.5:40000 ./tools/warp-ping.sh netflix.com
#
# 注意: 代理必须用 socks5://（不带 h）——由 curl 本地解析域名后向代理发起
#       精确的 A/AAAA 请求，才能从 SOCKS5 握手行判断实际走的是 v4 还是 v6；
#       用 socks5h:// 时解析发生在代理侧，无法得知协议族。
# ==============================================================================
set -u

DEFAULT_PROXY="socks5://127.0.0.1:40000"

usage() {
  sed -n '7,25p' "$0" | sed 's/^# \{0,1\}//'
}

TARGET=""
PROXY_OPT="${PROXY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--proxy)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "错误：$1 需要一个代理地址参数" >&2
        exit 2
      fi
      PROXY_OPT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    --)
      shift; break ;;
    -*)
      echo "错误：未知选项 $1（用 -h 查看用法）" >&2
      exit 2 ;;
    *)
      TARGET="$1"; shift ;;
  esac
done

command -v curl >/dev/null 2>&1 || { echo "错误：未找到 curl" >&2; exit 1; }

TARGET="${TARGET:-https://chatgpt.com}"
[[ "$TARGET" =~ ^https?:// ]] || TARGET="https://${TARGET}"

PROXY="${PROXY_OPT:-$DEFAULT_PROXY}"

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

# 按实际建立的握手行归类协议族
if echo "$CONNECT_LINE" | grep -qi 'IPv6'; then
  IP_TARGET=$(echo "$CONNECT_LINE" | sed -n 's/.*SOCKS5 connect to IPv6 \([^ ]*\).*/\1/p')
  ROUTE_STATUS="🟢 100% 实锤走【IPv6 纯净通道】 (${IP_TARGET})"
elif echo "$CONNECT_LINE" | grep -qi 'IPv4'; then
  IP_TARGET=$(echo "$CONNECT_LINE" | sed -n 's/.*SOCKS5 connect to IPv4 \([^ ]*\).*/\1/p')
  ROUTE_STATUS="🔵 100% 实锤走【IPv4 兼容通道】 (${IP_TARGET})"
else
  ROUTE_STATUS="⚪ 连接未建立或失败（检查代理是否在运行：${PROXY}）"
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

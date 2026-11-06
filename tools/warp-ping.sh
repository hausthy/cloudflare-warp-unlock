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
#                       可省略协议前缀：127.0.0.1:40000 等价 socks5://127.0.0.1:40000
#   -u, --user <u:p>    代理认证（也可用 PROXY_USER/PROXY_PASS 环境变量）
#   -4, --ipv4          只请求 A 记录（目标走 IPv4），用于排查 v6 目标不通
#   -6, --ipv6          只请求 AAAA 记录（目标走 IPv6）
#   -h, --help          显示帮助
#
# 环境变量:
#   PROXY               代理地址，等价于 -p，命令行参数优先级更高
#   PROXY_USER /
#   PROXY_PASS          代理认证，两者同时设置才生效（与容器内同名变量一致）
#
# 示例:
#   ./tools/warp-ping.sh chatgpt.com
#   ./tools/warp-ping.sh https://netflix.com
#   ./tools/warp-ping.sh -p socks5://127.0.0.1:40000 chatgpt.com
#   ./tools/warp-ping.sh -p 10.0.0.5:40000 netflix.com
#   PROXY=socks5://10.0.0.5:40000 ./tools/warp-ping.sh netflix.com
#   ./tools/warp-ping.sh -p 127.0.0.1:40000 -4 netflix.com    # 强制目标走 v4
#   ./tools/warp-ping.sh -p 127.0.0.1:40000 -6 netflix.com    # 强制目标走 v6
#   PROXY_USER=u PROXY_PASS=p ./tools/warp-ping.sh -p 203.0.113.9:40000 netflix.com
#
# 注意: 代理应使用 socks5://（不带 h）——由 curl 本地解析域名后向代理发起
#       精确的 A/AAAA 请求，才能从 SOCKS5 握手行判断实际走的是 v4 还是 v6；
#       用 socks5h:// 时解析发生在代理侧，无法得知协议族。
# ==============================================================================
set -u

DEFAULT_PROXY="socks5://127.0.0.1:40000"

usage() {
  awk '/^# 用法:/{f=1} f{if(/^# =====/) exit; print}' "$0" | sed 's/^# \{0,1\}//'
}

TARGET=""
PROXY_OPT="${PROXY:-}"
PROXY_AUTH_OPT=""
CURL_FAMILY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--proxy)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "错误：$1 需要一个代理地址参数" >&2
        exit 2
      fi
      PROXY_OPT="$2"; shift 2 ;;
    -u|--user)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "错误：$1 需要 user:pass 参数" >&2
        exit 2
      fi
      PROXY_AUTH_OPT="$2"; shift 2 ;;
    -4|--ipv4)
      CURL_FAMILY="-4"; shift ;;
    -6|--ipv6)
      CURL_FAMILY="-6"; shift ;;
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
# 允许省略协议前缀：127.0.0.1:40000 / host:port → socks5://host:port
if [[ "$PROXY" != *://* ]]; then
  PROXY="socks5://${PROXY}"
fi

# 代理认证：-u > PROXY_USER/PROXY_PASS 环境变量（两者同时设置才生效）；URL 内已带凭据则忽略
PROXY_AUTH="$PROXY_AUTH_OPT"
if [[ -z "$PROXY_AUTH" && -n "${PROXY_USER:-}" && -n "${PROXY_PASS:-}" ]]; then
  PROXY_AUTH="${PROXY_USER}:${PROXY_PASS}"
fi
[[ "$PROXY" == *@* ]] && PROXY_AUTH=""

# 协议族只有在 SOCKS5 握手行里才看得见，非 socks5 代理只能测延时
[[ "$PROXY" == socks5://* ]] || \
  echo "提示：${PROXY} 不是 socks5:// 代理，无法从握手行判断 IPv4/IPv6（延时数据仍有效）" >&2

CURL_AUTH=()
[[ -n "$PROXY_AUTH" ]] && CURL_AUTH=(--proxy-user "$PROXY_AUTH")

RAW_LOG=$(curl -sS -Iv ${CURL_FAMILY:+"$CURL_FAMILY"} -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
  --proxy "${PROXY}" ${CURL_AUTH[@]+"${CURL_AUTH[@]}"} \
  "${TARGET}" \
  -w "\n__METRICS__|%{http_code}|%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}" 2>&1)
CURL_RC=$?

CONNECT_LINE=$(echo "$RAW_LOG" | grep -i 'SOCKS5 connect to' | head -n 1 || true)
METRICS_LINE=$(echo "$RAW_LOG" | grep '^__METRICS__|' | tail -n 1 || true)
ERR_LINE=$(echo "$RAW_LOG" | grep -E '^curl: \([0-9]+\)' | tail -n 1 || true)
ERR_CODE=$(echo "$ERR_LINE" | sed -n 's/^curl: (\([0-9][0-9]*\)).*/\1/p')

err_hint() {
  case "$1" in
    5)  echo "代理域名解析失败" ;;
    6)  echo "无法解析代理主机名" ;;
    7)  echo "连接失败：代理未监听，或代理无法连到目标" ;;
    28) echo "超时：链路长时间无响应" ;;
    52) echo "服务端无响应（连接被空关闭）" ;;
    56) echo "连接被重置（隧道中断 / 被上游断开）" ;;
    97) echo "SOCKS5 握手失败：代理拒绝或无法到达目标地址" ;;
    "") echo "" ;;
    *)  echo "curl 退出码 $1" ;;
  esac
}
HINT="$(err_hint "$ERR_CODE")"

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

# 失败判定：HTTP 000 或 curl 非 0 退出码都算没连通（000 的耗时没有参考意义）
FAILED=0
{ [[ "$HTTP_CODE" == "000" ]] || (( CURL_RC != 0 )); } && FAILED=1

# 按握手行归类协议族（注意：握手行只说明 curl 请求了哪个族，不代表隧道通）
if echo "$CONNECT_LINE" | grep -qi 'IPv6'; then
  FAMILY="IPv6"
  IP_TARGET=$(echo "$CONNECT_LINE" | sed -n 's/.*SOCKS5 connect to IPv6 \([^ ]*\).*/\1/p')
elif echo "$CONNECT_LINE" | grep -qi 'IPv4'; then
  FAMILY="IPv4"
  IP_TARGET=$(echo "$CONNECT_LINE" | sed -n 's/.*SOCKS5 connect to IPv4 \([^ ]*\).*/\1/p')
else
  FAMILY=""
  IP_TARGET=""
fi

if (( FAILED )); then
  if [[ -n "$FAMILY" ]]; then
    ROUTE_STATUS="⚠️ 请求目标是【${FAMILY}】${IP_TARGET}，但隧道未建立（该行只代表 curl 发起了该族请求）"
  else
    ROUTE_STATUS="⚪ 连接未建立（检查代理是否在运行：${PROXY}）"
  fi
elif [[ "$FAMILY" == "IPv6" ]]; then
  ROUTE_STATUS="🟢 100% 实锤走【IPv6 纯净通道】 (${IP_TARGET})"
elif [[ "$FAMILY" == "IPv4" ]]; then
  ROUTE_STATUS="🔵 100% 实锤走【IPv4 兼容通道】 (${IP_TARGET})"
else
  ROUTE_STATUS="⚪ 未捕获 SOCKS5 握手行（非 socks5:// 代理无法判断协议族）"
fi

echo "=================================================================="
echo " 🎯 测试目标: ${TARGET}"
echo " 🛡️ 代理通道: ${PROXY}"
if [[ "$CURL_FAMILY" == "-4" ]]; then
  echo " 🎚️ 目标族限定: IPv4（-4，只请求 A 记录）"
elif [[ "$CURL_FAMILY" == "-6" ]]; then
  echo " 🎚️ 目标族限定: IPv6（-6，只请求 AAAA 记录）"
fi
echo " 🚀 底层实锤: ${ROUTE_STATUS}"
echo "=================================================================="

if (( FAILED )); then
  echo "连接结论:          ❌ 未连通（curl 退出码 ${CURL_RC}${HINT:+，${HINT}}）"
  [[ -n "$ERR_LINE" ]] && echo "curl 错误:         ${ERR_LINE}"
  echo "HTTP 状态码:       ${HTTP_CODE}"
  echo "------------------------------------------------------------------"
  echo "耗时（仅用于定位失败阶段，不能当成成功延时）:"
  echo "1. DNS 解析耗时:     ${T_DNS} 秒"
  echo "2. 代理建立连接:     ${T_CONNECT} 秒"
  echo "3. TLS/SSL 握手:     ${T_APP} 秒"
  echo "4. 首字节返回(TTFB): ${T_TTFB} 秒"
  echo "------------------------------------------------------------------"
  echo "总耗时 (Total):      ${T_TOTAL} 秒  ← 失败耗时，越短只说明失败越快"
  echo "💡 排障：curl -Iv --proxy ${PROXY} ${TARGET} 看完整过程；"
  echo "   容器内 /app/check-status.sh 看隧道状态与双栈出口"
  if [[ "$PROXY" == socks5://* ]] && { [[ "$ERR_CODE" == "97" ]] || [[ "$ERR_CODE" == "56" ]]; }; then
    echo "   注：socks5:// 由本机解析，目标以 IP 字面量交给代理。旧镜像（gost 2.x）链式"
    echo "   转发时会一律按“域名”上送，IPv6 字面量因此被拒（rep=4）；镜像默认已是"
    echo "   gost 3.3.3（已修复）。临时绕过：改 socks5h:// 或 http:// 代理。"
  fi
  echo "=================================================================="
  exit 1
fi

echo "连接结论:          ✅ 已连通"
CODE_NOTE=""
[[ "$HTTP_CODE" == "405" ]] && CODE_NOTE=" （405 = 站点拒绝 HEAD 请求，属正常）"
echo "HTTP 状态码:       ${HTTP_CODE}${CODE_NOTE}"
echo "------------------------------------------------------------------"
echo "1. DNS 解析耗时:     ${T_DNS} 秒"
echo "2. 代理建立连接:     ${T_CONNECT} 秒"
echo "3. TLS/SSL 握手:     ${T_APP} 秒"
echo "4. 首字节返回(TTFB): ${T_TTFB} 秒"
echo "------------------------------------------------------------------"
echo "总耗时 (Total):      ${T_TOTAL} 秒"
echo "=================================================================="

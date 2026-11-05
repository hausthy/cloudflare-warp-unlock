#!/usr/bin/env bash
# ==============================================================================
# unlock-check.sh — 流媒体解锁检测 + 出口地区验证（官方客户端 MASQUE 版）
#
# 替代 v1.x 的 fscarmen unlock.sh 检测部分：
#   * 通过本机代理 :40000 逐一探测 UNLOCK_STREAMS 指定的目标；
#   * 若设置 WARP_REGION，验证 trace 的出口地区（loc=）是否匹配；
#   * 全部通过返回 0，任一失败返回 1，检测摘要追加写入 /logs/unlock.log。
#
# 供 entrypoint.sh 的解锁巡检循环调用：失败 -> warp-cli 重连换 IP -> 复检。
# ==============================================================================
set -u

log() { printf '[%s] [unlock] %s\n' "$(date '+%F %T')" "$*"; }

PROXY_ARG="socks5h://127.0.0.1:40000"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
UNLOCK_LOG="${UNLOCK_LOG:-/logs/unlock.log}"
TARGETS="${UNLOCK_STREAMS:-ndc}"

# ---- 各目标检测函数（返回 0 = 解锁通过） -------------------------------------

current_loc() {
  curl -ksm8 -x "$PROXY_ARG" https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null |
    grep -E '^loc=' | cut -d= -f2 || true
}

# Netflix：解锁 IP 可访问非自制剧详情页返回 200；被识别为代理返回 403/404
check_netflix() {
  local code
  code="$(curl -ksm12 -x "$PROXY_ARG" -A "$UA" \
    -o /dev/null -w '%{http_code}' https://www.netflix.com/title/81280792 2>/dev/null || true)"
  [[ "$code" == "200" ]]
}

# ChatGPT：ios 端点返回含 "VPN" 表示数据中心 IP 被风控，"Ok" 表示可用
check_chatgpt() {
  local body
  body="$(curl -ksm12 -x "$PROXY_ARG" -A "$UA" https://ios.chat.openai.com/ 2>/dev/null || true)"
  [[ -n "$body" ]] && ! printf '%s' "$body" | grep -qi 'vpn'
}

# Disney+：select-profile 页面对封锁地区返回 403/404
check_disney() {
  local code
  code="$(curl -ksm12 -x "$PROXY_ARG" -A "$UA" \
    -o /dev/null -w '%{http_code}' https://www.disneyplus.com/select-profile 2>/dev/null || true)"
  [[ -n "$code" && "$code" != "403" && "$code" != "404" ]]
}

# ---- 主流程 -------------------------------------------------------------------

declare -A CHECK_FN=(
  [n]=check_netflix
  [d]=check_disney
  [c]=check_chatgpt
)
declare -A CHECK_NAME=(
  [n]=Netflix
  [d]=Disney+
  [c]=ChatGPT
)

summary=""
failed=0

# 出口地区验证：WARP_REGION 非空时校验 loc= 是否匹配
if [[ -n "${WARP_REGION:-}" ]]; then
  loc="$(current_loc)"
  loc_lc="$(printf '%s' "${loc:-}" | tr '[:upper:]' '[:lower:]')"
  region_lc="$(printf '%s' "${WARP_REGION}" | tr '[:upper:]' '[:lower:]')"
  if [[ "$loc_lc" == "$region_lc" ]]; then
    summary="${summary}Region(${loc}):OK "
  else
    summary="${summary}Region(${loc:-unknown}!=${WARP_REGION}):NG "
    failed=1
  fi
fi

# 逐项检测流媒体目标
for t in $(printf '%s' "$TARGETS" | grep -o . | sort -u); do
  name="${CHECK_NAME[$t]:-}"
  fn="${CHECK_FN[$t]:-}"
  [[ -n "$fn" ]] || continue
  if "$fn"; then
    summary="${summary}${name}:OK "
  else
    summary="${summary}${name}:NG "
    failed=1
  fi
done

[[ -z "$summary" ]] && { log "未指定任何检测目标 (UNLOCK_STREAMS 为空)"; exit 0; }

if [[ "$failed" -eq 0 ]]; then
  log "解锁检测通过: ${summary}"
else
  log "解锁检测未通过: ${summary}"
fi

mkdir -p "$(dirname "$UNLOCK_LOG")"
printf '[%s] %s\n' "$(date '+%F %T')" "$summary" >> "$UNLOCK_LOG"
exit "$failed"

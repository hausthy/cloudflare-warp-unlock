#!/usr/bin/env bash
# ==============================================================================
# warp-unlock v2.0 entrypoint — 官方 Cloudflare WARP 客户端 (MASQUE) 架构
#
# 流程：拉起 warp-svc 守护进程 → 注册账户 →（可选）绑定 WARP+ License →
#       切换 proxy 模式（本机 40001）→ 连接 → GOST 前端 (:40000) → 看门狗守护
#
# 权限模型：无 TUN、无 privileged，仅需 NET_ADMIN（warp-svc 安装 fwmark 策略路由所需）。
# ==============================================================================
set -u

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

WARP_PROXY_PORT=40001          # warp-svc 本机代理端口（gost 转发目标）
PUBLIC_PORT=40000              # 对外暴露端口

# ------------------------------------------------------------------------------
# 日志配置：
#   WARP_LOG_LEVEL —— warp-svc 为 Rust/tracing 程序（但实测不完全遵循 RUST_LOG）；
#                     默认 error：warn 层全是容器环境噪音（IPC 断管/UDP 端口回退/
#                     网络事件转储等，多为多行事件，线级过滤抓不全），白名单也只是止血；
#                     连接状态变化由本脚本的 log() 输出，不依赖 warp-svc 的低级别日志
#   WARP_LOG_FILE  —— 日志落盘文件（/logs 挂载到宿主机 ./logs）；留空 = 仅 stdout
# ------------------------------------------------------------------------------
export RUST_LOG="${WARP_LOG_LEVEL:-error}"
export NO_COLOR=1   # warp-svc 若识别则关闭 ANSI 颜色码；不识别时由 filter_by_level 剥离
WARP_LOG_FILE="${WARP_LOG_FILE:-/logs/warp.log}"

mkdir -p /logs /var/lib/cloudflare-warp

# ------------------------------------------------------------------------------
# D-Bus（可选）：warp-svc 的 power_notifier 会尝试连接 system bus 读取电源状态
# （桌面场景才用），容器内无 D-Bus 时每 3 秒重试并打印 WARN 日志。
# 镜像内带了轻量 dbus-daemon，这里拉起它即可彻底消除该日志噪音；失败也无碍。
# ------------------------------------------------------------------------------
if command -v dbus-daemon >/dev/null 2>&1; then
  mkdir -p /run/dbus
  dbus-uuidgen --ensure >/dev/null 2>&1 || true
  dbus-daemon --system --fork >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# GOST 前端参数：auto 协议（SOCKS5 / SOCKS4 / HTTP CONNECT 自动识别）+ 可选认证
# ------------------------------------------------------------------------------
GOST_USER_PASS=""
if [[ -n "${PROXY_USER:-}" && -n "${PROXY_PASS:-}" ]]; then
  GOST_USER_PASS="${PROXY_USER}:${PROXY_PASS}@"
  log "已启用代理认证（用户: ${PROXY_USER}）"
elif [[ -n "${PROXY_USER:-}" || -n "${PROXY_PASS:-}" ]]; then
  log "警告：PROXY_USER 与 PROXY_PASS 必须同时配置，本次启动不启用认证"
fi

# ------------------------------------------------------------------------------
# 后台子任务：注册 → License → 模式 → 连接 → GOST → 看门狗
# （warp-svc 将以 exec 方式接管前台，故所有初始化放在后台子 shell 中执行）
# ------------------------------------------------------------------------------
(
  # 1. 等待 warp-svc 就绪并完成注册
  #    新版客户端会随 daemon 启动自动注册，此处 "registration new" 可能报
  #    "Old registration is still around"，视为已注册成功，避免死循环。
  while true; do
    if out="$(warp-cli --accept-tos registration new 2>&1)"; then
      log "WARP 账户注册成功"
      break
    fi
    if printf '%s' "$out" | grep -qi "Old registration is still around"; then
      log "检测到既有 WARP 注册状态，直接复用"
      break
    fi
    sleep 1
  done

  # 2. 绑定 WARP+ License（可选）。docker compose 可能保留引号，先剥离一对。
  #    注意：设备槽位 = 注册（存于 /var/lib/cloudflare-warp），保留 config 重建
  #    容器不会占用新设备；清空 config 重注册才会。
  LICENSE="${WARP_LICENSE:-}"
  LICENSE="${LICENSE#[\"\']}"
  LICENSE="${LICENSE%[\"\']}"
  if [[ -n "$LICENSE" ]]; then
    if warp-cli --accept-tos registration license "$LICENSE" ||
       warp-cli --accept-tos license "$LICENSE" 2>/dev/null; then
      log "WARP+ License 绑定成功，账户已升级为 WARP+"
    else
      log "错误：WARP+ License 绑定失败（License 无效、设备数已满或网络异常），以免费账户继续运行"
    fi
  fi

  # 3. 自定义入口 Endpoint（高级）：钉住特定 Cloudflare 入口 IP 可影响落地 colo，
  #    配合 WARP_REGION 验证实现"地区定向"。warp-cli 新旧版本命令不同，依次尝试。
  if [[ -n "${WARP_ENDPOINT:-}" ]]; then
    if warp-cli --accept-tos tunnel endpoint set "$WARP_ENDPOINT" 2>/dev/null ||
       warp-cli --accept-tos set-custom-endpoint "$WARP_ENDPOINT" 2>/dev/null; then
      log "已设置自定义入口 Endpoint: ${WARP_ENDPOINT}"
    else
      log "错误：设置自定义 Endpoint 失败（当前 warp-cli 不支持或格式有误，格式应为 IP:PORT），使用默认入口"
    fi
  fi

  # 3.5 隧道协议（可选）：MASQUE（默认，HTTP3/QUIC，内存 ~170MB）或 WireGuard
  #     （老协议栈，无 QUIC/quiche，实测内存显著更低，适合小内存 VPS；
  #      但 Cloudflare 重心在 MASQUE，两协议解锁表现可能有差异）
  #     注意须在 connect 之前设置；注册状态跨协议保留
  WARP_PROTOCOL="${WARP_PROTOCOL:-MASQUE}"
  if [[ "$WARP_PROTOCOL" != "MASQUE" ]]; then
    if warp-cli --accept-tos tunnel protocol set "$WARP_PROTOCOL" 2>/dev/null; then
      log "隧道协议已切换为 ${WARP_PROTOCOL}"
    else
      log "警告：warp-cli 不支持切换协议（tunnel protocol set），保持默认 MASQUE"
      WARP_PROTOCOL="MASQUE"
    fi
  fi

  # 4. 切换 proxy 模式并设置本机端口，然后建立连接（兼容新旧 warp-cli 语法）
  warp-cli --accept-tos mode proxy || warp-cli --accept-tos set-mode proxy ||
    { log "错误：切换 proxy 模式失败"; exit 1; }
  warp-cli --accept-tos proxy port "$WARP_PROXY_PORT" ||
    warp-cli --accept-tos set-proxy-port "$WARP_PROXY_PORT" || true
  warp-cli --accept-tos connect

  # 5. 等待隧道连通（最多 60 秒），不阻塞代理启动
  for _ in $(seq 1 60); do
    if curl -ksm5 -x "socks5h://127.0.0.1:${WARP_PROXY_PORT}" \
         https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -Eq '^warp=(on|plus)$'; then
      log "WARP (${WARP_PROTOCOL}) 隧道已连通"
      break
    fi
    sleep 1
  done

  # 6. GOST 前端：对外 40000，链式转发到 warp-svc 本机代理 40001
  log "启动 GOST 前端 :${PUBLIC_PORT} (SOCKS5 + HTTP CONNECT 双协议)"
  gost -L "auto://${GOST_USER_PASS}:${PUBLIC_PORT}" \
       -F "socks5://127.0.0.1:${WARP_PROXY_PORT}" >> /logs/gost.log 2>&1 &

  # 7. 看门狗：定期验证隧道连通性，失联自动重连
  #    （日志滚动由 log_writer 按日期处理，这里不再做 10MB 原地截断）
  while true; do
    sleep "${WARP_WATCHDOG_INTERVAL:-60}"
    if ! curl -ksm8 -x "socks5h://127.0.0.1:${WARP_PROXY_PORT}" \
         https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -Eq '^warp=(on|plus)$'; then
      log "看门狗：隧道失联，正在自动重连"
      warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
      warp-cli --accept-tos connect >/dev/null 2>&1 || true
    fi
  done
) &

# ------------------------------------------------------------------------------
# 解锁巡检循环：定期检测流媒体解锁与出口地区，未通过自动重连换 IP（刷 IP）
# 环境变量：
#   WARP_AUTO_UNLOCK  —— 总开关，1 开启 / 0 关闭（默认 1）
#   UNLOCK_STREAMS    —— 检测项组合，n=Netflix d=Disney+ c=ChatGPT（默认 ndc，留空=不检测）
#   WARP_UNLOCK_ROTATE—— 未通过时是否轮换出口 IP，1 轮换（默认）/ 0 仅记录不动 IP
#   UNLOCK_INTERVAL   —— 巡检间隔秒数（默认 300）
#   WARP_REGION       —— 期望出口地区，非空则校验 loc=
# ------------------------------------------------------------------------------
if [[ "${WARP_AUTO_UNLOCK:-1}" == "1" ]]; then
  (
    interval="${UNLOCK_INTERVAL:-300}"
    sleep "${UNLOCK_INITIAL_DELAY:-60}"   # 等隧道与代理稳定后先做首轮检测
    while true; do
      if ! /app/unlock-check.sh; then
        if [[ "${WARP_UNLOCK_ROTATE:-1}" != "1" ]]; then
          log "解锁巡检：检测未通过（WARP_UNLOCK_ROTATE=0，仅记录不轮换 IP）"
        else
          log "解锁巡检：检测未通过，开始轮换出口 IP（最多 3 次）"
          for _ in 1 2 3; do
            warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
            warp-cli --accept-tos connect >/dev/null 2>&1 || true
            sleep 10
            /app/unlock-check.sh && { log "解锁巡检：重连后检测通过"; break; }
            log "解锁巡检：第 ${_} 次重连后仍未通过"
          done
        fi
      fi
      sleep "$interval"
    done
  ) &
fi

# ------------------------------------------------------------------------------
# warp-svc 前台运行，作为容器主进程（保持 PID1 以便正确接收 docker stop 信号）
#   - 实测 warp-svc 不完全遵循 RUST_LOG，按 WARP_LOG_LEVEL 对输出行做兜底过滤：
#     info 隐 DEBUG，warn/error 再隐 INFO（debug/trace 不过滤）
#   - WARP_LOG_FILE 非空时经 tee 同步落盘（stdout 仍进 docker logs）
# ------------------------------------------------------------------------------
filter_by_level() {
  # 内置噪音关键字（容器环境已验证无害的正则，| 分隔）
  local builtin_noise=' (DEBUG|INFO) |quiche: .* idle timeout expired|Failed to load SMBiosData|Discarding structured log emitted without ZT registration|Reinstalling missing WARP fwmark|IPC writer failed|Failed to bind to preferred UDP socket|actor_emergency_disconnect|NewNeighbour|^(h|ip|ts|uag|colo|sliver|http|loc|tls|sni|warp|gateway|rbi|kex|visit_scheme|fl)=|^[[:space:]]*(changes|new_info|power_state|fallback_disconnect_reason|failed_disconnect_reason)[[:space:]]*='
  # 用户自定义追加关键字（LOG_NOISE_KEYWORDS，ERE 正则，| 分隔），叠加在内置之上
  local extra="${LOG_NOISE_KEYWORDS:-}"
  # warp-svc 输出带 ANSI 颜色码（如 "<ESC>[34mDEBUG<ESC>[0m"），裸 ' DEBUG ' 匹配不上，
  # 必须先剥离转义序列再按级别过滤；顺带让落盘日志为纯文本、便于 grep
  # （NO_COLOR 尝试从源头关闭颜色，warp-svc 不识别时由 sed 兜底）
  sed -E $'s/\x1b\\[[0-9;]*[mK]//g' | {
    case "${WARP_LOG_LEVEL:-error}" in
      debug|trace) cat ;;
      warn|error)
        # --line-buffered：管道场景下逐行输出，避免 4KB 缓冲导致日志延迟可见
        if [[ -n "$extra" ]]; then
          grep --line-buffered -Ev "${builtin_noise}|${extra}"
        else
          grep --line-buffered -Ev "$builtin_noise"
        fi ;;
      *)
        if [[ -n "$extra" ]]; then
          grep --line-buffered -Ev " DEBUG |${extra}"
        else
          grep --line-buffered -v ' DEBUG '
        fi ;;
    esac
  }
}
# ------------------------------------------------------------------------------
# 日志写入器：按日期滚动（warp-YYYY-MM-DD.log）+ 保留最近 N 天
#   - 不能用 tee：tee 持有固定文件 fd，跨天无法切换目标文件，只能原地截断
#   - 这里自管 fd：每 30 秒（按行触发）检查一次系统日期，跨天则关闭旧 fd、
#     打开新一天的文件、重建 warp.log 软链、清理超期文件
#   - warp.log 始终指向当天文件，便于 tail -F logs/warp.log 跟踪
# ------------------------------------------------------------------------------
WARP_LOG_DIR="$(dirname "$WARP_LOG_FILE")"
WARP_LOG_KEEP_DAYS="${WARP_LOG_KEEP_DAYS:-3}"

prune_old_logs() {
  [[ "$WARP_LOG_KEEP_DAYS" =~ ^[0-9]+$ ]] || return 0
  (( WARP_LOG_KEEP_DAYS > 0 )) || return 0
  local cutoff f d
  # 保留天数含当天：保留 3 天 = 今天 + 前 2 天
  cutoff="$(date -d "-$((WARP_LOG_KEEP_DAYS - 1)) days" +%F 2>/dev/null)" || return 0
  for f in "$WARP_LOG_DIR"/warp-????-??-??.log; do
    [[ -e "$f" ]] || continue
    d="${f##*/warp-}"; d="${d%.log}"
    [[ "$d" < "$cutoff" ]] && rm -f "$f"
  done
  return 0
}

log_writer() {
  local line fd="" day="" next_check=0 echo_stdout=1
  [[ "${WARP_LOG_STDOUT:-1}" == "0" ]] && echo_stdout=0
  mkdir -p "$WARP_LOG_DIR"   # 防御：目录被外部删除时自愈

  # 兼容旧版本：此前 warp.log 是普通文件，新建软链会 -f 覆盖它。
  # 先按该文件的修改日期归档为 warp-YYYY-MM-DD.log，保留历史内容。
  if [[ -f "${WARP_LOG_DIR}/warp.log" && ! -L "${WARP_LOG_DIR}/warp.log" ]]; then
    mv -f "${WARP_LOG_DIR}/warp.log" \
          "${WARP_LOG_DIR}/warp-$(date -r "${WARP_LOG_DIR}/warp.log" +%F 2>/dev/null || date +%F).log" \
      2>/dev/null || rm -f "${WARP_LOG_DIR}/warp.log"
  fi

  # 启动即建当天文件（即使默认 error 级别长时间无输出，文件与软链也存在）
  day="$(date +%F)"
  exec {fd}>>"${WARP_LOG_DIR}/warp-${day}.log"
  ln -sfn "warp-${day}.log" "${WARP_LOG_DIR}/warp.log"
  prune_old_logs
  next_check=$((SECONDS + 30))

  while IFS= read -r line; do
    if (( SECONDS >= next_check )); then
      next_check=$((SECONDS + 30))
      local d; d="$(date +%F)"
      if [[ "$d" != "$day" ]]; then
        day="$d"
        exec {fd}>&-
        exec {fd}>>"${WARP_LOG_DIR}/warp-${day}.log"
        ln -sfn "warp-${day}.log" "${WARP_LOG_DIR}/warp.log"
        prune_old_logs
      fi
    fi
    printf '%s\n' "$line" >&"$fd"
    (( echo_stdout )) && printf '%s\n' "$line"
  done

  exec {fd}>&-
}

if [[ -n "$WARP_LOG_FILE" ]]; then
  mkdir -p "$WARP_LOG_DIR"
  if [[ "${WARP_LOG_STDOUT:-1}" != "0" ]]; then
    # 默认双路：过滤后日志按日滚动落盘 + 同步输出到容器日志（compose logging 1MB×3 兜底）
    log "warp-svc 日志：级别 ${WARP_LOG_LEVEL:-error}，按日滚动 ${WARP_LOG_DIR}/warp-YYYY-MM-DD.log（保留 ${WARP_LOG_KEEP_DAYS} 天），同步输出到容器日志"
    exec warp-svc > >(filter_by_level | log_writer) 2>&1
  fi
  # WARP_LOG_STDOUT=0 时仅落盘，docker logs 只保留本脚本的生命周期日志
  log "warp-svc 日志：级别 ${WARP_LOG_LEVEL:-error}，按日滚动 ${WARP_LOG_DIR}/warp-YYYY-MM-DD.log（保留 ${WARP_LOG_KEEP_DAYS} 天），容器日志不输出"
  exec warp-svc > >(filter_by_level | log_writer) 2>&1
fi
exec warp-svc > >(filter_by_level) 2>&1

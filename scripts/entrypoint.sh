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
  LICENSE="${WARP_LICENSE:-}"
  LICENSE="${LICENSE#[\"\']}"
  LICENSE="${LICENSE%[\"\']}"
  if [[ -n "$LICENSE" ]]; then
    if warp-cli --accept-tos registration license "$LICENSE" ||
       warp-cli --accept-tos license "$LICENSE"; then
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
      log "WARP (MASQUE) 隧道已连通"
      break
    fi
    sleep 1
  done

  # 6. GOST 前端：对外 40000，链式转发到 warp-svc 本机代理 40001
  log "启动 GOST 前端 :${PUBLIC_PORT} (SOCKS5 + HTTP CONNECT 双协议)"
  gost -L "auto://${GOST_USER_PASS}:${PUBLIC_PORT}" \
       -F "socks5://127.0.0.1:${WARP_PROXY_PORT}" >> /logs/gost.log 2>&1 &

  # 7. 看门狗：定期验证隧道连通性，失联自动重连
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
# 环境变量：UNLOCK_STREAMS (ndc) / WARP_REGION (期望地区) / UNLOCK_INTERVAL (秒)
# ------------------------------------------------------------------------------
if [[ "${WARP_AUTO_UNLOCK:-1}" == "1" ]]; then
  (
    interval="${UNLOCK_INTERVAL:-300}"
    sleep "${UNLOCK_INITIAL_DELAY:-60}"   # 等隧道与代理稳定后先做首轮检测
    while true; do
      if ! /app/unlock-check.sh; then
        log "解锁巡检：检测未通过，开始轮换出口 IP（最多 3 次）"
        for _ in 1 2 3; do
          warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
          warp-cli --accept-tos connect >/dev/null 2>&1 || true
          sleep 10
          /app/unlock-check.sh && { log "解锁巡检：重连后检测通过"; break; }
          log "解锁巡检：第 ${_} 次重连后仍未通过"
        done
      fi
      sleep "$interval"
    done
  ) &
fi

# warp-svc 前台运行，作为容器主进程
exec warp-svc

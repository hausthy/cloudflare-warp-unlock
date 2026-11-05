#!/usr/bin/env bash
# ==============================================================================
# warp-unlock v2.0 entrypoint — 官方 Cloudflare WARP 客户端 (MASQUE) 架构
#
# 流程：拉起 warp-svc 守护进程 → 注册账户 →（可选）绑定 WARP+ License →
#       切换 proxy 模式（本机 40001）→ 连接 → GOST 前端 (:40000) → 看门狗守护
#
# 权限模型：无 TUN、无 NET_ADMIN、无特权。warp-svc 的 proxy 模式为纯用户态 MASQUE。
# ==============================================================================
set -u

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

WARP_PROXY_PORT=40001          # warp-svc 本机代理端口（gost 转发目标）
PUBLIC_PORT=40000              # 对外暴露端口

mkdir -p /logs /var/lib/cloudflare-warp

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
    if warp-cli --accept-tos registration license "$LICENSE"; then
      log "WARP+ License 绑定成功，账户已升级为 WARP+"
    else
      log "错误：WARP+ License 绑定失败（License 无效、设备数已满或网络异常），以免费账户继续运行"
    fi
  fi

  # 3. 切换 proxy 模式并设置本机端口，然后建立连接
  warp-cli --accept-tos mode proxy || { log "错误：切换 proxy 模式失败"; exit 1; }
  warp-cli --accept-tos proxy port "$WARP_PROXY_PORT"
  warp-cli --accept-tos connect

  # 4. 等待隧道连通（最多 60 秒），不阻塞代理启动
  for _ in $(seq 1 60); do
    if curl -ksm5 -x "socks5h://127.0.0.1:${WARP_PROXY_PORT}" \
         https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -Eq '^warp=(on|plus)$'; then
      log "WARP (MASQUE) 隧道已连通"
      break
    fi
    sleep 1
  done

  # 5. GOST 前端：对外 40000，链式转发到 warp-svc 本机代理 40001
  log "启动 GOST 前端 :${PUBLIC_PORT} (SOCKS5 + HTTP CONNECT 双协议)"
  gost -L "auto://${GOST_USER_PASS}:${PUBLIC_PORT}" \
       -F "socks5://127.0.0.1:${WARP_PROXY_PORT}" >> /logs/gost.log 2>&1 &

  # 6. 看门狗：定期验证隧道连通性，失联自动重连（替代 v1.x 的 unlock.sh 定时巡检）
  #    说明：MASQUE 模式无法手动指定出口地区，故不再提供解锁地区定向与刷 IP；
  #    看门狗仅保证隧道始终在线。刷新出口 IP = 重启容器，或执行
  #    `warp-cli disconnect && warp-cli connect`。
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

# warp-svc 前台运行，作为容器主进程
exec warp-svc

#!/usr/bin/env bash
set -Eeuo pipefail

REGION="${WARP_REGION:-us}"
STREAMS="${UNLOCK_STREAMS:-ndc}"
FAMILY="${WARP_FAMILY:-4}"

[[ "$REGION" =~ ^[A-Za-z]{2}$ ]] || {
  echo "WARP_REGION 必须是两位地区代码，例如 us、sg、jp" >&2
  exit 2
}
[[ "$STREAMS" =~ ^[ndcNDC]+$ ]] || {
  echo "UNLOCK_STREAMS 只允许 n、d、c，例如 ndc" >&2
  exit 2
}
[[ "$FAMILY" == "4" || "$FAMILY" == "6" ]] || {
  echo "WARP_FAMILY 只能是 4 或 6" >&2
  exit 2
}

if ! ip link show wgcf >/dev/null 2>&1; then
  echo "wgcf 接口尚未启动，请先检查容器日志和 /etc/wireguard/wgcf.conf" >&2
  exit 1
fi

# 先验证用户指定的检测地址族，避免上游脚本在 WARP 未连通时进入安装菜单。
if ! curl "-${FAMILY}" -ksm10 --interface wgcf \
     https://www.cloudflare.com/cdn-cgi/trace | grep -Eq '^warp=(on|plus)$'; then
  echo "WARP IPv${FAMILY} 尚未连通，暂不配置解锁任务。请先检查 WGCF/网络后重试。" >&2
  exit 1
fi

# 避免重复安装时上游脚本因 MODE 已存在而拒绝操作。
if [[ "${1:-}" == "--force" ]]; then
  rm -f /data/warp_unlock.sh
  if [[ -f /var/spool/cron/crontabs/root ]]; then
    sed -i '/warp_unlock\.sh/d' /var/spool/cron/crontabs/root
  fi
fi

if [[ -s /data/warp_unlock.sh ]]; then
  echo "unlock.sh 定时任务已经存在。需要重新配置时执行："
  echo "  docker compose exec warp-unlock /app/setup-unlock.sh --force"
  exit 0
fi

# ==============================================================================
# 三级容错降级加载策略：
# ① 优先级 1：优先使用宿主机挂载的本地脚本（实时生效，无需重新构建）
# ② 优先级 2：未挂载时，尝试在线从官方链接拉取最新版本
# ③ 优先级 3：在线下载失败时，自动回退到构建时打包进镜像的稳定保底脚本
# ==============================================================================
UNLOCK_BIN="/usr/local/bin/unlock.sh"
FALLBACK_SCRIPT="/app/warp-unlock.fallback.sh"
LOCAL_SCRIPT=""

# 1. 第一优先级：检测是否挂载了本地脚本
for candidate in \
  "/scripts/warp-unlock.sh" \
  "/scripts/unlock.sh" \
  "/app/warp-unlock.sh"; do
  if [[ -f "$candidate" && -s "$candidate" ]]; then
    LOCAL_SCRIPT="$candidate"
    break
  fi
done

if [[ -n "$LOCAL_SCRIPT" ]]; then
  echo ">>> [脚本加载] ① 优先使用已挂载的本地脚本: ${LOCAL_SCRIPT}"
  cp -f "$LOCAL_SCRIPT" "$UNLOCK_BIN"
  chmod 0755 "$UNLOCK_BIN"
else
  # 2. 第二优先级：未挂载本地脚本，在线拉取最新版
  echo ">>> [脚本加载] 未挂载本地脚本，② 尝试通过官方链接在线拉取最新版本..."
  DOWNLOAD_OK=0
  if curl -sSLf --retry 2 --connect-timeout 6 "https://gitlab.com/fscarmen/warp_unlock/-/raw/main/unlock.sh" -o "$UNLOCK_BIN"; then
    echo ">>> [脚本加载] 从官方 GitLab 下载成功"
    DOWNLOAD_OK=1
  elif curl -sSLf --retry 2 --connect-timeout 6 "https://raw.githubusercontent.com/fscarmen/warp_unlock/main/unlock.sh" -o "$UNLOCK_BIN"; then
    echo ">>> [脚本加载] 从 GitHub 备用源下载成功"
    DOWNLOAD_OK=1
  fi

  # 3. 第三优先级：在线下载失败，回退到镜像内置保底脚本
  if [[ "$DOWNLOAD_OK" -ne 1 || ! -s "$UNLOCK_BIN" ]]; then
    echo ">>> [警告] 在线下载失败，③ 触发降级机制：回退使用镜像内置的稳定保底脚本" >&2
    if [[ -s "$FALLBACK_SCRIPT" ]]; then
      cp -f "$FALLBACK_SCRIPT" "$UNLOCK_BIN"
      echo ">>> [降级成功] 已成功载入内置保底脚本"
    else
      echo "错误: 内置保底脚本丢失，无法继续安装解锁任务！" >&2
      exit 1
    fi
  fi
  chmod 0755 "$UNLOCK_BIN"
fi

# 上游 1.22 的 -M 1 即 Alpine/BusyBox crond 每 5 分钟检测。
# -T @@docker 设置非空机器名但不配置 Telegram，避免脚本进入交互式询问。
# 若双栈检测都成功，上游会询问检测使用 IPv4 还是 IPv6；
# 这里通过管道提供预设选项，隧道本身仍保留双栈。
if [[ "$FAMILY" == "4" ]]; then
  FAMILY_CHOICE=1
else
  FAMILY_CHOICE=2
fi

echo "配置 fscarmen unlock.sh 1.22：地区=${REGION}，项目=${STREAMS}，检测地址族 IPv${FAMILY}"
printf '%s\n' "$FAMILY_CHOICE" |
  bash "$UNLOCK_BIN" \
    -C \
    -A "$REGION" \
    -N "$STREAMS" \
    -M 1 \
    -T "@@docker"

if [[ ! -s /data/warp_unlock.sh ]]; then
  echo "未生成 /data/warp_unlock.sh，请检查上游脚本输出和容器日志" >&2
  exit 1
fi

chmod 700 /data/warp_unlock.sh
echo "unlock.sh 定时任务已配置：每 5 分钟检测一次。"

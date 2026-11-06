# WARP Unlock Docker v2.0（官方客户端 MASQUE 版）

[![Debian](https://img.shields.io/badge/Base-Debian_bookworm-blue.svg?logo=debian)](https://www.debian.org/)
[![Client](https://img.shields.io/badge/Client-Cloudflare_WARP_official-orange.svg)](https://pkg.cloudflareclient.com/)
[![Protocol](https://img.shields.io/badge/Protocol-MASQUE-red.svg)](#)
[![Architecture](https://img.shields.io/badge/Arch-AMD64%20%7C%20ARM64-success.svg)](#)
[![Privilege](https://img.shields.io/badge/Privilege-NET_ADMIN_only-yellow.svg)](#)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](#)

专为 VPS / 云服务器打造的容器化 Cloudflare WARP 代理网关。

基于 **Debian + Cloudflare 官方 warp-svc 客户端（MASQUE 协议）+ GOST** 构建：不创建 TUN 设备、不改路由表，仅需 `NET_ADMIN` capability（无需 `privileged`），通过官方 proxy 模式对外提供 **SOCKS5 / HTTP CONNECT 双协议**代理，内置看门狗自动重连与 WARP+ License 绑定。

---

## 🌟 核心特性

* 🏛️ **Cloudflare 官方客户端（warp-svc + MASQUE）**：
  使用官方 APT 源安装的 `cloudflare-warp`，协议演进由 Cloudflare 官方跟进（proxy 模式仅支持 MASQUE），无需自行维护 WireGuard 配置生成逻辑。
* 🛡️ **最小特权**：
  无需 `/dev/net/tun` 设备、无需 `privileged`，仅需 `NET_ADMIN` capability（新版 warp-svc 连接建立后会安装 fwmark 策略路由规则，此为官方客户端硬性要求），不创建虚拟网卡——常规 Docker 环境开箱即跑。
* 🔀 **同端口双协议**：
  GOST 前端 `auto` 协议自动识别，`40000` 端口同时接受 `socks5h://`、`socks5://` 与 `http://` 客户端。
* 🔒 **可选代理认证**：
  配置 `PROXY_USER` / `PROXY_PASS` 即启用 HTTP Basic + SOCKS5 user/pass 认证，公网暴露也无需担心被扫描白嫖；默认仅绑定 `127.0.0.1`。
* ➕ **WARP+ License 一键升级**：
  `WARP_LICENSE` 环境变量自动执行 `warp-cli registration license`，绑定结果实时反映在启动日志与诊断报告中。
* 🐕 **隧道看门狗**：
  定期（默认 60 秒，可调）探测 `warp=on/plus`，隧道失联自动 disconnect/connect 重连，长期无人值守稳定在线。
* 📺 **流媒体解锁巡检 + 自动刷 IP**：
  内置 `unlock-check.sh` 定期检测 Netflix / Disney+ / ChatGPT（`UNLOCK_STREAMS`），未通过自动重连轮换出口 IP（单轮最多 3 次），检测历史写入 `./logs/unlock.log`。
* 🌍 **出口地区验证 + 自定义入口**：
  `WARP_REGION` 设定期望出口地区（校验 trace `loc=`，不匹配触发轮换）；高级用户可用 `WARP_ENDPOINT` 钉住特定 Cloudflare 入口 IP 影响落地 colo。
* 🐳 **预构建镜像 + 每日自动重建**：
  GitHub Actions 自动构建 AMD64/ARM64 双架构镜像并推送 Docker Hub 与 GHCR；每日定时重建，持续跟进基础镜像与官方客户端的安全更新。

---

## 🏗️ 架构拓扑图

```mermaid
flowchart TD
    subgraph Host["宿主机 (Host)"]
        Client["远程服务器 / 本地应用"]
        SocksPort["127.0.0.1:40000<br>(SOCKS5 / HTTP CONNECT 入口)"]
        Client -->|仅本机回环访问| SocksPort
    end

    subgraph Container["warp-unlock 容器内部（最小特权沙箱）"]
        Gost["GOST 前端 (:40000)<br>auto 协议识别 + 可选认证"]
        WarpSvc["warp-svc 官方守护进程<br>proxy 模式 (:40001)"]
        Watchdog["看门狗循环<br>(trace 探测 / 失联自动重连)"]
        SocksPort -.->|端口映射| Gost
        Gost -->|SOCKS5 链式转发| WarpSvc
        Watchdog -.->|warp-cli disconnect/connect| WarpSvc
    end

    subgraph Cloudflare["Cloudflare 骨干网"]
        Endpoint["MASQUE 隧道 (QUIC/HTTP3)"]
        CFIP["Cloudflare 出口 IP 资源池"]
        WarpSvc ==>|MASQUE 加密| Endpoint
        Endpoint --> CFIP
    end

    subgraph Targets["目标服务"]
        Netflix["流媒体 / AI 平台"]
        Any["任意 HTTPS 服务"]
        CFIP --> Netflix
        CFIP --> Any
    end
```

---

## ⚠️ v1.x → v2.0 架构变更说明

本版本从 **WGCF + wireguard-go（WireGuard 协议）** 全面切换为 **官方客户端（MASQUE 协议）**：

| 项目 | v1.x (WGCF) | v2.0 (官方客户端 MASQUE) |
| :--- | :--- | :--- |
| 所需权限 | `/dev/net/tun` + `NET_ADMIN` | 仅 `NET_ADMIN`（无需 TUN 设备） |
| 协议 | WireGuard UDP | MASQUE（QUIC/HTTP3） |
| 代理协议 | SOCKS5（GOST） | SOCKS5 + **HTTP CONNECT**（同端口） |
| WARP+ License | `wgcf update --license-key` | `warp-cli registration license` |
| 出口地区定向 | ✅ WGCF 配置直接指定 | ⚠️ `WARP_REGION` 验证 + `WARP_ENDPOINT` 钉入口（高级） |
| 解锁检测/自动刷 IP | ✅ 每 5 分钟 | ✅ `UNLOCK_STREAMS` 巡检 + 失败轮换（可配间隔） |
| 出口 IP 轮换 | 重连隧道即换 IP | 重启容器 / `warp-cli disconnect && connect` |
| 适用环境 | 需 TUN 的常规 VPS | 常规 Docker 环境（无需 TUN，需 NET_ADMIN） |

> 如果依赖「WGCF 精确地区切换」能力，请继续使用 v1.x（`master` 分支）；
> 如果更看重官方维护与协议兼容性，v2.0 是更优解（解锁检测与刷 IP 已回归；权限上免去 TUN 设备，仅需 NET_ADMIN）。

---

## 📁 目录结构

```text
warp-unlock-docker/
├── Dockerfile                   # Debian + 官方 cloudflare-warp + GOST 构建（含瘦身清理）
├── docker-compose.yml           # 服务编排（cap_add: NET_ADMIN）
├── .env.example                 # 环境变量模板（推荐生产基线：WireGuard + 3MB 分卷 + warn + 关自动解锁）
├── .github/workflows/
│   └── docker-image.yml         # 预构建镜像 CI（多架构 + 每日重建）
├── config/                      # 挂载卷：warp-svc 注册状态持久化
├── logs/                        # 挂载卷：GOST 日志 + 解锁检测历史
│   ├── gost.log
│   └── unlock.log
├── scripts/
│   ├── entrypoint.sh            # 注册 → License → Endpoint → proxy 模式 → GOST → 巡检循环
│   ├── unlock-check.sh          # 流媒体解锁检测 + 出口地区验证
│   └── check-status.sh          # 容器一键状态诊断脚本
└── tools/
    └── warp-ping.sh             # 宿主机链路耗时与 IPv4/IPv6 握手分析工具（不打包进镜像）
```

---

## 🚀 快速开始

### 方案 A：预构建镜像（推荐，开箱即用）

```bash
# Docker Hub
docker run -d --name warp-unlock \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  -p 127.0.0.1:40000:40000 \
  -v $(pwd)/config:/var/lib/cloudflare-warp \
  hausthy/cloudflare-warp-unlock:latest

# 或 GitHub Container Registry
docker run -d --name warp-unlock \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  -p 127.0.0.1:40000:40000 \
  -v $(pwd)/config:/var/lib/cloudflare-warp \
  ghcr.io/hausthy/cloudflare-warp-unlock:latest
```

> 镜像由 CI 每日自动重建（跟进官方客户端与基础镜像安全更新）；
> 如需暴露公网，请先配置认证并将端口改为 `-p 0.0.0.0:40000:40000`（强烈建议配合 `PROXY_USER/PROXY_PASS`）。

### 方案 B：本地构建 + docker compose

```bash
cp .env.example .env      # 模板即推荐生产配置（低内存/精简日志/关自动解锁），按需改 WARP_LICENSE、认证
docker compose up -d --build
docker compose logs -f warp-unlock
```

> 想恢复官方默认行为（MASQUE、`error` 日志、开启自动解锁）：删掉 `.env` 或把相关行注释掉即可回落到 compose 内置默认值。

首次启动时容器会自动：
1. 拉起 `warp-svc` 并注册免费 WARP 账户（状态持久化在 `./config`，重启不重复注册）；
2. 如配置了 `WARP_LICENSE` 则绑定升级 WARP+；
3. 切换 proxy 模式并建立 MASQUE 隧道；
4. 启动 GOST 前端（`:40000`）与看门狗。

### 方案 C：从源码构建测试（服务器）

```bash
# 1. 克隆分支（HTTPS 免登录；国内服务器慢可加镜像前缀 https://ghfast.top/）
git clone -b v2 https://github.com/hausthy/warp_unlock.git warp-unlock-v2
cd warp-unlock-v2

# 2. 准备环境变量（按需填写 WARP_LICENSE / WARP_REGION / UNLOCK_STREAMS 等）
cp .env.example .env

# 3. 分层构建并启动（首次构建约 2-4 分钟，需可访问 pkg.cloudflareclient.com 与 GitHub）
docker compose up -d --build

# 4. 跟踪启动日志，看到 "WARP (MASQUE) 隧道已连通" 即成功
docker compose logs -f warp-unlock

# 5. 验证代理（SOCKS5 与 HTTP CONNECT 同端口）
curl -x socks5h://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace | grep warp
curl -x http://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace | grep warp

# 6. 一键诊断（含解锁检测实时结果与巡检历史）
docker compose exec warp-unlock /app/check-status.sh

# 7. 跟踪解锁巡检记录
tail -f logs/unlock.log

# 8. 查看镜像体积（验证分层瘦身效果）
docker images | grep warp-unlock
```

> 测试完成后清理：`docker compose down`；彻底重来（清账户）：`docker compose down && rm -rf config/*`

### 镜像体积与构建参数

最终镜像 **~139MB**（默认开启 UPX）/ **~190MB**（`UPX_WARP_SVC=0` 回退不压缩），从初版 330MB 优化而来。
瘦身手段：UPX 压缩三件套（gost/warp-cli/warp-svc）、静态 curl（SHA256 强校验）、
清除 apt/perl/gconv 冗余组件、scratch 压平镜像层。

| 构建参数 | 默认 | 说明 |
| :--- | :--- | :--- |
| `UPX_WARP_SVC` | `1` | UPX 压缩 warp-svc 守护进程（省 ~50MB）。若守护进程出现异常，改回 `0` 重建即回退 |
| `GOST_VERSION` | `2.11.5` | GOST 版本 |
| `CURL_STATIC_VERSION` | `8.23.0-1` | 静态 curl 版本（stunnel/static-curl，构建期 SHA256 强校验） |
| `UPX_VERSION` | `4.2.4` | UPX 版本 |
| `DEBIAN_RELEASE` | `bookworm` | 基础镜像发行版 |

```bash
# compose 方式：默认即开启 UPX，直接重建即可
docker compose up -d --build

# 或 docker build 直接指定（不加 --build-arg 亦默认开启）
docker build -t warp-unlock:test .

# 回退不压缩版本（守护进程异常时）
docker build --build-arg UPX_WARP_SVC=0 -t warp-unlock:test .

# 排障专用：构建带完整 shell 的未压平中间层镜像（scratch 终版无 apt/dpkg）
docker build --target runtime -t warp-unlock:debug .
```

> 说明：官方客户端 MASQUE 架构的体积硬成本 = debian-slim 基座（glibc）约 65MB +
> warp-svc 自带私有库 `/usr/lib/warp` 约 42MB，这两块无法再压缩；
> seiry/docker-warp-proxy 的 50MB 是 wgcf 静态单文件架构，不含上述组件。

---

## ⚙️ 环境变量详解 (`.env`)

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `WARP_LICENSE` | 空 | 26 位 WARP+ License（`xxxxxxxx-xxxxxxxx-xxxxxxxx`），留空为免费账户 |
| `PROXY_USER` / `PROXY_PASS` | 空 | 代理认证（两者同时填写才生效），HTTP Basic + SOCKS5 user/pass |
| `UNLOCK_STREAMS` | `ndc` | 解锁检测项：`n` (Netflix)、`d` (Disney+)、`c` (ChatGPT)，留空则不检测 |
| `UNLOCK_INTERVAL` | `300` | 解锁巡检间隔（秒） |
| `WARP_AUTO_UNLOCK` | `1` | 流媒体解锁巡检总开关（`0` 关闭，仅保留隧道看门狗） |
| `WARP_UNLOCK_ROTATE` | `1` | 检测未通过时是否轮换出口 IP：`1` = 断开重连刷 IP（最多 3 次）；`0` = 仅记录日志不动 IP |
| `WARP_REGION` | 空 | 期望出口地区（两位代码），非空时巡检校验 `loc=` 是否匹配 |
| `WARP_ENDPOINT` | 空 | （高级）自定义入口 `IP:PORT`，钉住入口影响落地 colo |
| `WARP_PROTOCOL` | `MASQUE` | 隧道协议：`MASQUE` / `WireGuard`；WireGuard 内存占用显著更低（小内存 VPS），见「内存优化」节 |
| `WARP_WATCHDOG_INTERVAL` | `60` | 看门狗巡检间隔（秒），失联自动重连 |
| `WARP_LOG_LEVEL` | `error` | warp-svc 日志级别：`error/warn/info/debug/trace`。默认 `error` 基本静默——`warn` 层全是容器环境噪音，`info` 每小时上万行；排障时临时改 `debug`/`trace`（全量不过滤），用完改回 |
| `WARP_LOG_FILE` | `/logs/warp.log` | 日志落盘路径（实际按日滚动为 `warp-YYYY-MM-DD.log`，`warp.log` 为当天软链）；留空 = 不落盘，仅容器日志 |
| `WARP_LOG_KEEP_DAYS` | `3` | 按日期滚动保留天数（今天 + 前 N-1 天），跨天自动清理更早文件（含卷文件） |
| `WARP_LOG_MAX_SIZE_MB` | `10` | 单文件大小上限（MB），超过则同日分卷 `warp-DATE-NN.log`，最新始终为 `warp-DATE.log`；`0` = 不限制 |
| `WARP_LOG_STDOUT` | `1` | `1` = 落盘 + 容器日志双路；`0` = 仅落盘 |
| `LOG_NOISE_KEYWORDS` | 空 | 追加日志噪音拦截关键字（ERE 正则，`\|` 分隔），叠加在内置白名单之上，所有级别（除 debug/trace）生效。例：`my_noisy_span\|DeviceWithNoLimits` |
| `GOST_VERSION` | `2.11.5` | GOST 构建版本 |

### 日志系统说明

| 文件（宿主机 `./logs/`） | 内容 |
| :--- | :--- |
| `warp-YYYY-MM-DD.log` | warp-svc 主日志，**按日期滚动**，且始终是当天最新文件（默认 `error` 级别，静默即健康） |
| `warp-YYYY-MM-DD-01.log` / `-02.log` … | 同日超大小上限后的历史卷，编号越大越早（`-01` 是上一卷） |
| `warp.log` | 指向当天最新日志文件的软链，跟踪用 `tail -F logs/warp.log`（`-F` 才能跨天/跨卷自动切换） |
| `gost.log` | GOST 前端日志（gost 仅输出启动/异常，增长极慢） |
| `unlock.log` | 解锁巡检与刷 IP 记录（每次检测一行） |

- **两级滚动**：①按自然日切分 `warp-YYYY-MM-DD.log`；②单文件达到 `WARP_LOG_MAX_SIZE_MB`（默认 `10`，`0`=不限）时同日分卷——`warp-DATE.log → warp-DATE-01.log`，已有卷号整体 +1，最新文件始终是 `warp-DATE.log`。分卷失败（只读挂载等）时退化为原地截断，仅保留最后 2000 行
- **保留策略**：`WARP_LOG_KEEP_DAYS`（默认 `3`）= 今天 + 前 2 天，跨天时按日期前缀清理更早的日期文件（卷文件一并删除）。日志量大时（如 `WARP_LOG_LEVEL=debug`）也不会无限膨胀
- **为什么不用 logrotate**：镜像为 scratch 压平版，不含 cron/logrotate；滚动由 entrypoint 内的写入器自管文件描述符实现（`tee` 持有固定 fd，无法切换文件）
- **连接状态看哪里**：注册/License 绑定/隧道连通/看门狗重连/解锁巡检均由 entrypoint 直接输出到 `docker logs`，不依赖 warp-svc 低级别日志，因此 `error` 默认档不丢关键信息
- **ANSI 剥离**：warp-svc 输出自带颜色转义码（且不完全遵循 `RUST_LOG`），entrypoint 先剥离 ANSI 再按级别行过滤，落盘为纯文本
- **内置噪音白名单**：容器环境已验证无害的告警（fwmark 重装提示、IPC broken pipe、UDP 端口回退、SMBios 读取失败、无 ZT 注册的遥测丢弃、网络事件转储等）已默认拦截；如仍有刺眼输出，用 `LOG_NOISE_KEYWORDS` 追加即可，无需改代码
- **默认双路输出**：`WARP_LOG_STDOUT=1`（默认）时过滤后日志同时落盘（按日文件）和容器日志（docker logs，1MB×3 轮转）；设 `WARP_LOG_STDOUT=0` 则仅落盘，docker logs 只保留 entrypoint 生命周期日志
- **排障姿势**：`.env` 改 `WARP_LOG_LEVEL=debug` 重建看全量；检查原始字节用 `cat -v logs/warp-$(date +%F).log`（终端渲染会吞掉转义符，别被显示骗到）

### 资源占用与限制

compose 已内置资源限制（服务器实测校准）：

| 限制项 | 值 | 依据 |
| :--- | :--- | :--- |
| `mem_limit` | `512m` | 实测稳态 ~170MB（warp-svc ~150MB + gost ~30MB），2-3 倍余量；超限被 OOM Kill 后由 `restart: unless-stopped` 自动拉起 |
| `cpus` | `1.0` | 空闲近 0%，转发时 QUIC 加解密 + 中转单核足够，防止异常失控吃满宿主机 |
| `pids_limit` | `256` | warp-svc 以线程为主 + gost + 定时 CLI 调用，实测 ~44，防泄漏 |

```bash
# 实时核对占用与限额余量
docker stats --no-stream warp-unlock
```

### 内存优化：切换 WireGuard 协议（可选）

MASQUE 模式下 warp-svc 稳态 ~150MB，大头是 QUIC/HTTP3 协议栈（quiche 缓冲 + tokio 多线程运行时），属官方闭源黑盒、无参数可调。**唯一有效的省内存开关是切回老协议 WireGuard**（`WARP_PROTOCOL=WireGuard`），无 QUIC 栈后内存显著下降，适合小内存 VPS：

```env
WARP_PROTOCOL=WireGuard
```

取舍：WireGuard 是 Cloudflare 逐步淡出的老协议，且两协议的出口特征/解锁表现可能有差异，追求解锁稳定性就保持默认 MASQUE。切换后需 `docker compose up -d` 重建（注册状态跨协议保留，不占新设备槽位）。启动日志会打印 `隧道协议已切换为 WireGuard`；若报 `不支持切换协议` 说明客户端版本过旧，会自动回退 MASQUE。

对照参考：v1.x（wgcf + wireproxy，用户态 WireGuard）稳态仅 ~20MB——如果 170MB 无法接受且不需要官方客户端特性，master 分支方案仍是内存最优解。

### 出口协议族说明（默认双栈）

默认配置下 WARP 出口是**双栈漂移**的：WARP 隧道本身同时持有 v4（出口池 `104.28.x.x`）和 v6（出口池 `2a09:bac::/48`），warp-svc 出站解析域名时若宿主机有 IPv6 则优先走 v6。trace 里 `ip=` 显示哪个族，取决于该次连接实际走的协议族（`curl -4` 测不出差异——它只约束 curl→gost 本地段，出口协议族由 warp-svc 出站决定）。

**可选：强制 IPv4 出口**。多数流媒体风控（Netflix、Disney+ 等）主要看 IPv4 信誉库，若出口协议族漂移导致解锁不稳定，可在 `docker-compose.yml` 的服务下加：

```yaml
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=1
      - net.ipv6.conf.default.disable_ipv6=1
```

改后需**重建容器**（`docker compose up -d`，`restart` 不生效）。

双栈出口验证（用 ip.sb 专用子域名，A/AAAA 记录各只剩一个，强制 warp-svc 走对应协议族出站）：

```bash
# IPv4 出口：应返回 104.28.x.x
curl -sm8 -x socks5h://127.0.0.1:40000 https://api-ipv4.ip.sb/ip

# IPv6 出口：未禁 v6 时返回 2a09:bac::/48 地址；已禁则超时/失败
curl -sm8 -x socks5h://127.0.0.1:40000 https://api-ipv6.ip.sb/ip

# 默认出口：未禁 v6 时随解析漂移；已禁则固定返回 104.28.x.x
curl -sm8 -x socks5h://127.0.0.1:40000 https://api.ip.sb/ip
```

---

## 🧪 验证与测试

```bash
# SOCKS5 模式（远程 DNS 解析）
curl -x socks5h://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace | grep warp
# 输出 warp=on（或 plus）即代理生效

# HTTP CONNECT 模式（同一端口）
curl -x http://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace | grep warp

# 查询出口 IP
curl -x socks5h://127.0.0.1:40000 https://api.ip.sb/ip

# 确认端口仅监听本机回环
ss -lntp | grep 40000

# 一键完整诊断
docker compose exec warp-unlock /app/check-status.sh

# 宿主机链路分析
./tools/warp-ping.sh chatgpt.com
```

### 宿主机工具：`tools/warp-ping.sh`

在宿主机直接运行（**不打包进镜像**，无需进容器），输出各阶段耗时并判定实际走 IPv4 还是 IPv6：

```bash
./tools/warp-ping.sh chatgpt.com                  # 默认代理 socks5://127.0.0.1:40000
./tools/warp-ping.sh https://netflix.com
./tools/warp-ping.sh -p socks5://127.0.0.1:40000 netflix.com   # 指定代理
PROXY=socks5://10.0.0.5:40000 ./tools/warp-ping.sh netflix.com # 环境变量方式
./tools/warp-ping.sh -h                           # 帮助
```

**代理优先级**：`-p/--proxy` > 环境变量 `PROXY` > 默认 `socks5://127.0.0.1:40000`（容器映射端口）。

协议族判定原理：必须使用 `socks5://`（不带 `h`），由 curl 本地解析域名后向代理发起精确的 A/AAAA 请求，再从 SOCKS5 握手行（`SOCKS5 connect to IPv4/IPv6 x.x.x.x`）判断实际走的协议族；若用 `socks5h://`，解析在代理侧完成，无法得知协议族。可用于排查出口协议族漂移问题（见「出口协议族说明」节）。

---

## 📺 联动 Sing-box / Xray 分流

与 v1.x 用法完全一致，将流媒体/AI 流量指向 `127.0.0.1:40000` 的 `socks` 出站即可（示例见 v1.x 文档或仓库历史）；HTTP 类客户端也可直接使用 `http://127.0.0.1:40000`。

---

## 🔍 FAQ

### Q1: 如何更换/轮换出口 IP？
```bash
# 容器内重连
docker compose exec warp-unlock warp-cli --accept-tos disconnect && \
docker compose exec warp-unlock warp-cli --accept-tos connect
# 或直接重启容器
docker compose restart warp-unlock
```

### Q2: 解锁地区定向和刷 IP 是怎么实现的？和 v1.x 有什么不同？
v2.0 通过**巡检 + 轮换**实现：
- `unlock-check.sh` 每 `UNLOCK_INTERVAL` 秒检测 Netflix/Disney+/ChatGPT 与出口地区（`WARP_REGION`）；
- 未通过则 `warp-cli disconnect && connect` 轮换出口 IP（单轮最多 3 次），通过即保持。

三个环境变量即可完全控制行为：

| 目的 | 配置 |
| :--- | :--- |
| 完全关闭解锁巡检 | `WARP_AUTO_UNLOCK=0` |
| 只检测不换 IP（固定优质 IP 时用） | `WARP_AUTO_UNLOCK=1` + `WARP_UNLOCK_ROTATE=0` |
| 只检测某几项 | `UNLOCK_STREAMS=n` / `dc` / `ndc`（留空 = 不检测，仅保活） |
| 默认（检测全部 + 未通过轮换） | `WARP_AUTO_UNLOCK=1` + `UNLOCK_STREAMS=ndc` + `WARP_UNLOCK_ROTATE=1` |

与 v1.x 的差异：MASQUE 模式下官方客户端不提供地区强制切换，`WARP_REGION` 是**验证目标**——轮换通常只能改变同区域内的出口 IP 与解锁状态，若你的 VPS 所在 colo 始终无法满足期望地区，可尝试 `WARP_ENDPOINT` 钉住其他地区的 Cloudflare 入口 IP（高级玩法，需自行寻找可用入口），或回退 v1.x（WGCF 可直接改配置选地区）。

### Q3: 如何使用 WARP+ License？
编辑 `.env` 填入 `WARP_LICENSE` 后 `docker compose up -d`，日志出现 `WARP+ License 绑定成功` 即升级完成；失败常见原因：License 无效、设备数已满（5 台）、网络不可达。

### Q4: 如何彻底重置账户？
```bash
docker compose down && rm -rf config/*
```

### Q5: 公网暴露安全吗？
默认端口仅绑定 `127.0.0.1`，外网不可达。如需公网使用：务必配置 `PROXY_USER/PROXY_PASS` 认证后再将端口映射改为 `0.0.0.0`。

### Q6: 日志报 `fwmark policy rule ... Operation not permitted` 后无限重连？
新版 warp-svc 在连接建立后会向容器网络命名空间安装 fwmark 策略路由规则（`ip rule`），缺少 `NET_ADMIN` capability 时会失败并触发断开重连循环。确认 `docker-compose.yml` 中包含：

```yaml
cap_add:
  - NET_ADMIN
```

修改后需要**重新创建容器**（`docker compose up -d --force-recreate`，仅 `restart` 不会重算能力集）。

### Q7: 服务器磁盘/内存被 Docker 吃掉了怎么办？

长期迭代构建的机器常见两类膨胀，处理方式：

```bash
# 磁盘：BuildKit 构建缓存（docker system df -v 查看，迭代十几轮可积 10G+）
docker builder prune -af     # 零风险，仅影响下次构建速度
docker image prune -f        # 清 dangling 中间镜像

# 内存：dockerd 常驻 RSS 膨胀（正常 50-80MB，可涨到 200-300MB）
ps aux --sort=-%mem | head   # 若 dockerd RSS 明显偏高
systemctl restart docker     # 秒级中断，容器按 unless-stopped 自动拉起
```

日常重建时顺手清理：`docker builder prune -af && docker image prune -f && docker compose up -d --build`。

---

## 📜 鸣谢与致敬

* [seiry/docker-warp-proxy](https://github.com/seiry/docker-warp-proxy)：官方客户端 proxy 模式容器化思路与 warp-cli 版本兼容处理的灵感来源
* [ginuerzh/gost](https://github.com/ginuerzh/gost)：功能强大的安全代理工具（前端双协议与认证）
* [Cloudflare WARP Client for Linux](https://pkg.cloudflareclient.com/)：官方客户端

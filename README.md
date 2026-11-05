# WARP Unlock Docker v2.0（官方客户端 MASQUE 版）

[![Debian](https://img.shields.io/badge/Base-Debian_bookworm-blue.svg?logo=debian)](https://www.debian.org/)
[![Client](https://img.shields.io/badge/Client-Cloudflare_WARP_official-orange.svg)](https://pkg.cloudflareclient.com/)
[![Protocol](https://img.shields.io/badge/Protocol-MASQUE-red.svg)](#)
[![Architecture](https://img.shields.io/badge/Arch-AMD64%20%7C%20ARM64-success.svg)](#)
[![Privilege](https://img.shields.io/badge/Privilege-Zero-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](#)

专为 VPS / 云服务器打造的容器化 Cloudflare WARP 代理网关。

基于 **Debian + Cloudflare 官方 warp-svc 客户端（MASQUE 协议）+ GOST** 构建：不创建 TUN 设备、不改路由表、**零特权**，通过官方 proxy 模式对外提供 **SOCKS5 / HTTP CONNECT 双协议**代理，内置看门狗自动重连与 WARP+ License 绑定。

---

## 🌟 核心特性

* 🏛️ **Cloudflare 官方客户端（warp-svc + MASQUE）**：
  使用官方 APT 源安装的 `cloudflare-warp`，协议演进由 Cloudflare 官方跟进（proxy 模式仅支持 MASQUE），无需自行维护 WireGuard 配置生成逻辑。
* 🛡️ **真正零特权**：
  无需 `/dev/net/tun` 设备、无需 `NET_ADMIN`/`SYS_ADMIN` capability、无需 `privileged`，不创建虚拟网卡不修改路由——任何能跑 Docker 的环境（含受限 LXC、容器托管平台）皆可运行。
* 🔀 **同端口双协议**：
  GOST 前端 `auto` 协议自动识别，`40000` 端口同时接受 `socks5h://`、`socks5://` 与 `http://` 客户端。
* 🔒 **可选代理认证**：
  配置 `PROXY_USER` / `PROXY_PASS` 即启用 HTTP Basic + SOCKS5 user/pass 认证，公网暴露也无需担心被扫描白嫖；默认仅绑定 `127.0.0.1`。
* ➕ **WARP+ License 一键升级**：
  `WARP_LICENSE` 环境变量自动执行 `warp-cli registration license`，绑定结果实时反映在启动日志与诊断报告中。
* 🐕 **隧道看门狗**：
  定期（默认 60 秒，可调）探测 `warp=on/plus`，隧道失联自动 disconnect/connect 重连，长期无人值守稳定在线。
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

    subgraph Container["warp-unlock 容器内部（零特权沙箱）"]
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
| 所需权限 | `/dev/net/tun` + `NET_ADMIN` | **无**（零特权） |
| 协议 | WireGuard UDP | MASQUE（QUIC/HTTP3） |
| 代理协议 | SOCKS5（GOST） | SOCKS5 + **HTTP CONNECT**（同端口） |
| WARP+ License | `wgcf update --license-key` | `warp-cli registration license` |
| 出口地区定向 (`WARP_REGION`) | ✅ | ❌ 不支持（官方客户端不提供） |
| 解锁检测/自动刷 IP (`unlock.sh`) | ✅ 每 5 分钟 | ❌ 不支持，改为看门狗保活 |
| 出口 IP 轮换 | 重连隧道即换 IP | 重启容器 / `warp-cli disconnect && connect` |
| 适用环境 | 需 TUN 的常规 VPS | 任何 Docker 环境（含受限容器平台） |

> 如果依赖「地区定向 + 流媒体自动刷 IP」能力，请继续使用 v1.x（`master` 分支）；
> 如果更看重零特权部署、官方维护与协议兼容性，v2.0 是更优解。

---

## 📁 目录结构

```text
warp-unlock-docker/
├── Dockerfile                   # Debian + 官方 cloudflare-warp + GOST 构建
├── docker-compose.yml           # 零特权服务编排
├── .env.example                 # 环境变量配置模板
├── .github/workflows/
│   └── docker-image.yml         # 预构建镜像 CI（多架构 + 每日重建）
├── config/                      # 挂载卷：warp-svc 注册状态持久化
├── logs/                        # 挂载卷：GOST 运行日志
│   └── gost.log
├── scripts/
│   ├── entrypoint.sh            # 注册 → License → proxy 模式 → GOST → 看门狗
│   └── check-status.sh          # 容器一键状态诊断脚本
└── tools/
    └── warp-ping.sh             # 宿主机链路耗时与 IPv4/IPv6 握手分析工具
```

---

## 🚀 快速开始

### 方案 A：预构建镜像（推荐，开箱即用）

```bash
# Docker Hub
docker run -d --name warp-unlock \
  --restart unless-stopped \
  -p 127.0.0.1:40000:40000 \
  -v $(pwd)/config:/var/lib/cloudflare-warp \
  hausthy/warp-unlock:latest

# 或 GitHub Container Registry
docker run -d --name warp-unlock \
  --restart unless-stopped \
  -p 127.0.0.1:40000:40000 \
  -v $(pwd)/config:/var/lib/cloudflare-warp \
  ghcr.io/hausthy/warp-unlock:latest
```

> 镜像由 CI 每日自动重建（跟进官方客户端与基础镜像安全更新）；
> 如需暴露公网，请先配置认证并将端口改为 `-p 0.0.0.0:40000:40000`（强烈建议配合 `PROXY_USER/PROXY_PASS`）。

### 方案 B：本地构建 + docker compose

```bash
cp .env.example .env      # 按需修改（WARP_LICENSE、认证等）
docker compose up -d --build
docker compose logs -f warp-unlock
```

首次启动时容器会自动：
1. 拉起 `warp-svc` 并注册免费 WARP 账户（状态持久化在 `./config`，重启不重复注册）；
2. 如配置了 `WARP_LICENSE` 则绑定升级 WARP+；
3. 切换 proxy 模式并建立 MASQUE 隧道；
4. 启动 GOST 前端（`:40000`）与看门狗。

---

## ⚙️ 环境变量详解 (`.env`)

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `WARP_LICENSE` | 空 | 26 位 WARP+ License（`xxxxxxxx-xxxxxxxx-xxxxxxxx`），留空为免费账户 |
| `PROXY_USER` / `PROXY_PASS` | 空 | 代理认证（两者同时填写才生效），HTTP Basic + SOCKS5 user/pass |
| `WARP_WATCHDOG_INTERVAL` | `60` | 看门狗巡检间隔（秒），失联自动重连 |
| `GOST_VERSION` | `2.11.5` | GOST 构建版本 |

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

### Q2: 为什么没有解锁地区定向和自动刷 IP 了？
官方客户端 proxy 模式（MASQUE）不提供出口地区选择能力，`unlock.sh` 的 WireGuard 隧道重连刷 IP 逻辑不适用。这是官方架构的取舍：换来的是零特权部署与官方长期维护。如需该能力请使用 v1.x。

### Q3: 如何使用 WARP+ License？
编辑 `.env` 填入 `WARP_LICENSE` 后 `docker compose up -d`，日志出现 `WARP+ License 绑定成功` 即升级完成；失败常见原因：License 无效、设备数已满（5 台）、网络不可达。

### Q4: 如何彻底重置账户？
```bash
docker compose down && rm -rf config/*
```

### Q5: 公网暴露安全吗？
默认端口仅绑定 `127.0.0.1`，外网不可达。如需公网使用：务必配置 `PROXY_USER/PROXY_PASS` 认证后再将端口映射改为 `0.0.0.0`。

---

## 📜 鸣谢与致敬

* [seiry/docker-warp-proxy](https://github.com/seiry/docker-warp-proxy)：官方客户端 proxy 模式容器化思路与 warp-cli 版本兼容处理的灵感来源
* [ginuerzh/gost](https://github.com/ginuerzh/gost)：功能强大的安全代理工具（前端双协议与认证）
* [Cloudflare WARP Client for Linux](https://pkg.cloudflareclient.com/)：官方客户端

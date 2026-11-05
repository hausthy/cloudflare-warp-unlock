# Cloudflare WARP Unlock Gateway v2.0 (Official Client · MASQUE)

[![Debian](https://img.shields.io/badge/Base-Debian_bookworm-blue.svg)](https://www.debian.org/) [![Client](https://img.shields.io/badge/Client-Cloudflare_WARP_official-orange.svg)](https://pkg.cloudflareclient.com/) [![Protocol](https://img.shields.io/badge/Protocol-MASQUE-red.svg)](#) [![Architecture](https://img.shields.io/badge/Arch-AMD64_--_ARM64-success.svg)](#) [![Privilege](https://img.shields.io/badge/Privilege-NET_ADMIN_only-yellow.svg)](#)

专为云服务器打造的 **最小特权、开箱即用** Cloudflare WARP 代理网关。

基于 **Debian + Cloudflare 官方 warp-svc 客户端（MASQUE 协议）+ GOST** 构建：无需 TUN 设备、无需 privileged，仅需 `NET_ADMIN` capability（新版官方客户端安装 fwmark 策略路由所需），同端口提供 **SOCKS5 / HTTP CONNECT 双协议**代理，支持 WARP+ License、可选认证与看门狗自动重连。

---

## 🌟 核心特性

* 🏛️ **官方客户端**：Cloudflare 官方 APT 源安装 `cloudflare-warp`，协议演进官方跟进。
* 🛡️ **最小特权**：无 TUN、无 privileged，仅需 `NET_ADMIN` capability，不建网卡不改路由。
* 🔀 **双协议同端口**：`:40000` 同时接受 `socks5h://` / `socks5://` / `http://`。
* 🔒 **可选认证**：`PROXY_USER/PROXY_PASS` 启用 HTTP Basic + SOCKS5 user/pass。
* ➕ **WARP+ 一键升级**：`WARP_LICENSE` 环境变量自动绑定。
* 📺 **解锁巡检 + 刷 IP**：定期检测 Netflix/Disney+/ChatGPT，未通过自动轮换出口 IP。
* 🌍 **地区验证**：`WARP_REGION` 校验出口地区，`WARP_ENDPOINT` 高级自定义入口。
* 🐕 **看门狗保活**：隧道失联自动重连（间隔可调，默认 60 秒）。
* 🪶 **极致瘦身**：镜像仅 **~139MB**（UPX 三件套 + 静态 curl + scratch 压平）。
* 🐳 **每日重建**：CI 自动构建 AMD64/ARM64 双架构镜像。

---

## 🏗️ 架构

```text
[宿主机] 应用 ──► 127.0.0.1:40000
                     │
[warp-unlock 容器（最小特权）]
  GOST 前端 (:40000, auto 协议 + 可选认证)
    └──► warp-svc proxy 模式 (:40001)
           └──► MASQUE (QUIC/HTTP3) ──► Cloudflare 骨干网
[看门狗] trace 探测，失联自动 warp-cli disconnect && connect
```

---

## 🪶 镜像体积与构建参数

| 配置 | 体积 |
| :--- | :--- |
| `UPX_WARP_SVC=1`（推荐） | ~139MB |
| 默认（不压缩 warp-svc） | ~190MB |

> 若开启 UPX 压缩 warp-svc 后守护进程异常，改回 `UPX_WARP_SVC=0` 重建即可回退。
> 排障可构建带完整 shell 的中间层镜像：`docker build --target runtime ...`

---

## 🚀 快速启动

### 方案 A：docker run 一键启动

```bash
docker run -d \
  --name warp-unlock \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  -p 127.0.0.1:40000:40000 \
  -v $(pwd)/config:/var/lib/cloudflare-warp \
  hausthy/warp-unlock:latest
```

### 方案 B：docker compose

```yaml
services:
  warp-unlock:
    container_name: warp-unlock
    image: hausthy/warp-unlock:latest
    restart: unless-stopped
    init: true
    ports:
      - "127.0.0.1:40000:40000/tcp"
    environment:
      TZ: Asia/Shanghai
      WARP_LICENSE: ""           # 可选：26 位 WARP+ License
      PROXY_USER: ""             # 可选：代理认证（与 PROXY_PASS 同时配置生效）
      PROXY_PASS: ""
      WARP_WATCHDOG_INTERVAL: "60"
    volumes:
      - ./config:/var/lib/cloudflare-warp
      - ./logs:/logs
    logging:
      driver: json-file
      options:
        max-size: "1m"
        max-file: "3"
```

```bash
docker compose up -d
```

---

## ⚙️ 环境变量

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `TZ` | `Asia/Shanghai` | 容器时区 |
| `WARP_LICENSE` | 空 | 26 位 WARP+ License（`xxxxxxxx-xxxxxxxx-xxxxxxxx`），留空为免费账户 |
| `PROXY_USER` / `PROXY_PASS` | 空 | 代理认证，两者同时填写才生效 |
| `UNLOCK_STREAMS` | `ndc` | 解锁检测项：n(Netflix) / d(Disney+) / c(ChatGPT)，留空不检测 |
| `UNLOCK_INTERVAL` | `300` | 解锁巡检间隔（秒），未通过自动轮换出口 IP |
| `WARP_REGION` | 空 | 期望出口地区（两位代码），非空时校验 trace loc= |
| `WARP_ENDPOINT` | 空 | （高级）自定义入口 IP:PORT |
| `WARP_WATCHDOG_INTERVAL` | `60` | 看门狗巡检间隔（秒） |

---

## 🧪 验证与测试

```bash
# SOCKS5 模式
curl -x socks5h://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace | grep warp

# HTTP CONNECT 模式（同一端口）
curl -x http://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace | grep warp

# 容器一键诊断
docker compose exec warp-unlock /app/check-status.sh
```

---

## 📜 项目地址与协议

* **GitHub Repository**：[https://github.com/hausthy/warp_unlock](https://github.com/hausthy/warp_unlock)
* **License**：MIT

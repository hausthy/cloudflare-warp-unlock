# Cloudflare WARP Unlock Gateway (Userspace wireguard-go)

[![Alpine Linux](https://img.shields.io/badge/Base-Alpine_3.21-blue.svg)](https://alpinelinux.org/) [![Architecture](https://img.shields.io/badge/Arch-AMD64_--_ARM64-success.svg)](#) [![Driver](https://img.shields.io/badge/Driver-wireguard--go-red.svg)](https://git.zx2c4.com/wireguard-go) [![Size](https://img.shields.io/badge/Size-50MB-brightgreen.svg)](#) [![GitHub](https://img.shields.io/badge/GitHub-warp__unlock-blue.svg)](https://github.com/hausthy/warp_unlock)

专为云服务器打造的 **轻量级、无污染、无特权** Cloudflare WARP 流媒体解锁网关。

基于 **Alpine 3.21 + WGCF + wireguard-go + GOST + unlock.sh** 构建，采用 **全用户态 WireGuard 网络栈**，彻底解耦宿主机 Linux 内核与模块，在完全 **非特权（`privileged: false`）** 环境下实现 Netflix、Disney+、ChatGPT 等服务的原生高质量 IP 解锁与本地安全 SOCKS5 代理。

---

## 🌟 核心特性

* 🛡️ **纯用户态网络栈 (`wireguard-go`)**：完全不依赖宿主机 `wireguard.ko` 内核模块，无需挂载 `/lib/modules`，无论在 KVM、LXC、OpenVZ 或各大云厂商精简内核 VPS 上皆可 100% 稳定运行。
* ⚡ **极速精简瘦身（仅 ~50 MB）**：剥离全部冗余依赖，静态编译裁剪，传输体积仅 15 MB 左右。
* 🔄 **智能三级降级容错机制**：
  * ① 优先加载宿主机挂载的 `./scripts/warp-unlock.sh`（本地修改即时热生效，无需重构镜像）；
  * ② 未挂载时自动在线拉取 GitLab/GitHub 官方最新版本；
  * ③ 在线拉取失败时自动平滑回退至镜像内置的稳定保底脚本，离线断网环境下仍可 100% 成功启动。
* 🌐 **路由防环与 Docker 网络隔离**：强制 Cloudflare Anycast 节点静态直连宿主机网关，彻底避免 UDP 隧道报文死循环；设立专用策略路由，确保 SOCKS5 入站流量原路返回。
* 🔒 **高安全性本地回环绑定**：默认严格绑定宿主机 `127.0.0.1:40000`，外网无法扫描或探测，杜绝被黑客白嫖或充当跳板。

---

## 🏗️ 架构拓扑图

```text
[宿主机 (Host)]
  Xray / Sing-box / 本地应用 ──► 127.0.0.1:40000 (SOCKS5 入口)
        │
        ▼ (本地回环端口映射)
[warp-unlock 容器内部 (用户态非特权沙箱)]
  ├── GOST SOCKS5 服务 (:40000)
  ├── wireguard-go (TUN 用户态网卡)
  └── unlock.sh (crond 每5分钟自动巡检刷IP)
        │
        ▼ (WireGuard 隧道加密)
[Cloudflare WARP Anycast 骨干网]
  ├── Netflix 满血解锁 (Region: SG/US/JP...)
  ├── Disney+ 绿色通过
  └── ChatGPT 正常访问
```

---

## 🔄 解锁脚本加载与三级降级机制 (Waterfall Fallback)

```text
[容器启动 (执行 setup-unlock.sh)]
  │
  ▼
[第一级: 宿主机挂载优先]
  是否挂载了 /scripts/warp-unlock.sh ?
  ├── [是] ──► 优先载入宿主机脚本 (修改即时生效，免重构镜像)
  └── [否] ──► 进入第二级在线拉取
               │
               ▼
[第二级: 在线动态获取]
  尝试向 GitLab / GitHub 官方源发起拉取
  ├── [成功] ──► 载入最新官方版本
  └── [失败] ──► 网络受限或离线，触发第三级保底降级
               │
               ▼
[第三级: 镜像保底降级]
  自动回退至镜像内置的离线保底脚本 (/app/warp-unlock.fallback.sh)
  └── 保证纯离线/断网环境下 100% 成功启动
               │
               ▼
[系统初始化与守护]
  生成 /data/warp_unlock.sh 并启动 BusyBox crond 每5分钟定时刷 IP
  └── 网关就绪：自动守护流媒体解锁与 SOCKS5 代理
```

---

## 🚀 快速启动

### 方案 A：使用 Docker Compose（推荐）

创建 `docker-compose.yml`：

```yaml
services:
  warp-unlock:
    container_name: warp-unlock
    image: hausthy/warp-unlock:latest
    restart: unless-stopped
    init: true

    # 用户态 wireguard-go 依赖 /dev/net/tun 虚拟网卡设备
    devices:
      - /dev/net/tun:/dev/net/tun

    # 仅允许网络命名空间管理，完全无特权
    cap_add:
      - NET_ADMIN
    security_opt:
      - no-new-privileges:true

    # 仅绑定宿主机本地回环，保障网络安全
    ports:
      - "127.0.0.1:40000:40000/tcp"

    environment:
      TZ: Asia/Shanghai
      WARP_REGION: "sg"          # 与机器物理归属地一致，例如 sg, us, jp, hk
      UNLOCK_STREAMS: "ndc"      # 检测项：n(Netflix)、d(Disney+)、c(ChatGPT)
      WARP_FAMILY: "4"           # 优选检测 IPv4
      WARP_AUTO_SETUP: "1"       # 首次连通后自动开启每 5 分钟定时刷 IP

    sysctls:
      net.ipv6.conf.all.disable_ipv6: "0"
      net.ipv6.conf.default.disable_ipv6: "0"

    volumes:
      - ./config:/etc/wireguard
      - ./data:/data
      - ./data/cron:/var/spool/cron/crontabs
      - ./logs:/logs
      - ./scripts:/scripts:ro    # 可选：挂载宿主机本地自定义脚本

    networks:
      - docker-default

networks:
  docker-default:
    name: docker-default
    external: true               # 若未提前创建外部网络，可将 external 改为 driver: bridge
```

启动容器：
```bash
docker compose up -d
```

---

### 方案 B：使用 `docker run` 一键启动

```bash
docker run -d \
  --name warp-unlock \
  --restart unless-stopped \
  --device /dev/net/tun:/dev/net/tun \
  --cap-add NET_ADMIN \
  --security-opt no-new-privileges:true \
  -p 127.0.0.1:40000:40000 \
  -e TZ=Asia/Shanghai \
  -e WARP_REGION=sg \
  -e UNLOCK_STREAMS=ndc \
  -v $(pwd)/config:/etc/wireguard \
  -v $(pwd)/data:/data \
  hausthy/warp-unlock:latest
```

---

## ⚙️ 环境变量说明

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `TZ` | `Asia/Shanghai` | 容器时区 |
| `WARP_REGION` | `sg` | 目标检测地区（建议与云服务器物理机房所在国家一致，如 `sg`, `jp`, `us`） |
| `UNLOCK_STREAMS` | `ndc` | 检测项目：`n` (Netflix)、`d` (Disney+)、`c` (ChatGPT) |
| `WARP_FAMILY` | `4` | 探测与测试地址族（`4` 为 IPv4，`6` 为 IPv6） |
| `WARP_AUTO_SETUP` | `1` | 是否自动开启 5 分钟定时检测刷 IP 守护任务 |

---

## 🧪 验证与测试

在宿主机终端测试 SOCKS5 代理连通性：

```bash
# 查询经过 WARP 后的出口 IPv4
curl --proxy socks5h://127.0.0.1:40000 -4 https://api-ipv4.ip.sb/ip

# 查询经过 WARP 后的出口 IPv6
curl --proxy socks5h://127.0.0.1:40000 https://api-ipv6.ip.sb/ip

# 实时查看流媒体解锁日志
tail -f data/result.log

# 容器一键状态全面诊断
docker compose exec warp-unlock /app/check-status.sh
```

---

## 📺 联动 Xray / Sing-box 分流配置示例

在远程服务器端分流规则中，将流媒体流量路由至本容器的 `127.0.0.1:40000`：

### Sing-box (`config.json`)
```json
{
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "socks",
      "tag": "warp-unlock",
      "server": "127.0.0.1",
      "server_port": 40000
    }
  ],
  "route": {
    "rules": [
      {
        "geosite": ["netflix", "disney", "openai"],
        "outbound": "warp-unlock"
      }
    ]
  }
}
```

---

## 📜 开源协议与项目地址

* **GitHub Repository**：[https://github.com/hausthy/warp_unlock](https://github.com/hausthy/warp_unlock)
* **License**：MIT

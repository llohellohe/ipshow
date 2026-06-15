# IPShow

一款用于检测 macOS 当前公网出口 IP 与归属地的轻量原生 App，按"出口通道"分别检测，便于判断代理是否对不同流量生效。

## 解决的问题

在 macOS 上使用 ClashX / Surge / Stash 等代理工具时，常见的情况是：
- 浏览器流量走代理生效（可在 whatismyip 类站点看到 IP 变化）；
- 但 terminal 命令行（`curl`、`git`、`pip` 等）、或部分原生 GUI App 并没有走代理；
- 用户难以确认每条链路真实的对外 IP 与地理位置。

IPShow 同时探测三条独立的"出口通道"，让差异一目了然。

## 出口通道说明

| 通道 | 实现 | 反映的真实场景 |
| --- | --- | --- |
| App 通道 | `URLSession.shared`，默认遵循 *System Settings → Network → Proxies* 中的 HTTP/HTTPS Proxy | 大部分 GUI 原生 App 走的链路 |
| Shell 通道 | `Process` 调起 `/bin/zsh -l -c "curl ..."`，加载 login shell 环境变量（`http_proxy`、`https_proxy`、`all_proxy`） | terminal、命令行工具走的链路 |
| 直连通道 | `URLSession` 显式设置 `connectionProxyDictionary = [:]`，强制忽略系统代理 | 物理出口真实 IP（基线参照） |

归属地查询统一通过"直连通道"访问 `ip-api.com`，避免被代理污染结果。

## 主要功能

- 一键刷新（`⌘R`）并行检测三个通道的公网 IP；
- 展示国家 / 地区 / 城市 / ISP / ASN，并标注是否 Proxy / Hosting；
- 通道间 IP 不一致时给出醒目提示；
- 历史记录持久化（SwiftData），按时间倒序展示，自动保留最近 500 条；
- 可折叠面板查看本地网卡（`getifaddrs`，IPv4 / IPv6）；
- 可选每分钟自动刷新；
- 右键复制 IP。

## 运行要求

- macOS 14 Sonoma 或更新（SwiftData / `@Observable`）；
- Xcode 15 或更新；
- 联网，能访问 `api.ipify.org`、`ifconfig.co`、`ip-api.com`。

## 构建与运行

```bash
open IPShow.xcodeproj
```

在 Xcode 中：
1. 选择 `IPShow` scheme；
2. `⌘R` 运行。

如果构建时提示需要选择团队签名，在 *Target → Signing & Capabilities* 中选自己的 Apple ID 即可（本地运行不需要付费开发者账号）。

## 关于沙盒

为了让 Shell 通道能调起 `/bin/zsh` 与 `curl`，本工程默认 **关闭** App Sandbox（见 `IPShow/IPShow.entitlements`）。如需上架 Mac App Store，需要重新设计 Shell 通道（例如改为内置 SOCKS 客户端或读取代理设置后用 URLSession 模拟）。

## 项目结构

```
IPShow/
├── IPShowApp.swift              入口，注入 ModelContainer
├── ContentView.swift            主窗口布局
├── Models/
│   ├── Channel.swift            App / Shell / Direct 三通道枚举
│   ├── IPSnapshot.swift         瞬态检测结果
│   └── IPRecord.swift           SwiftData 持久化模型
├── Services/
│   ├── IPDetectionService.swift 三通道并行探测
│   ├── GeoLookupService.swift   ip-api.com 归属地查询
│   └── LocalInterfaceService.swift getifaddrs 本地网卡
├── ViewModels/
│   └── DashboardViewModel.swift 刷新编排与历史持久化
├── Views/
│   ├── ChannelCardView.swift
│   ├── LocalInterfacesView.swift
│   └── HistoryListView.swift
├── Assets.xcassets
└── IPShow.entitlements          关闭沙盒 + 允许 client 网络
```

## 自测建议

1. 打开代理（如 ClashX）→ 在系统设置中"为 HTTP/HTTPS 代理"勾选 127.0.0.1:7890 → 刷新，应看到 App 通道与直连通道 IP 不同；
2. 在 terminal 中 `export http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890`，重启 IPShow（让新的 shell 环境变量生效）→ Shell 通道 IP 应与 App 通道一致；
3. 关闭系统 HTTP 代理但保留 `http_proxy` 环境变量 → 应看到 App 通道与直连一致、Shell 通道走代理，IP 不同。

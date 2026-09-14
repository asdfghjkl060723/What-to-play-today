---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 71387854f6f121d0438faa3d1cae15f1_90ed65f9af2811f18f50525400aeaaa3
    ReservedCode1: a+MTFU2UrbI2ow3WuBdKG5Sr++T5TTHkBCfB21b/8zmEMIXf3elD4CJpxGysafCMJShXVL+37nhwtj3vQLAMwoyPIOPpu05rHm0eTzdHibEh04ilT0Hf2LxnRs5jxgb0T+CrvYefWfNZDxrqG2yQXz5cU+3rVrM29qe3WCGa98xwXLOQfOeSXl3LDZI=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 71387854f6f121d0438faa3d1cae15f1_90ed65f9af2811f18f50525400aeaaa3
    ReservedCode2: a+MTFU2UrbI2ow3WuBdKG5Sr++T5TTHkBCfB21b/8zmEMIXf3elD4CJpxGysafCMJShXVL+37nhwtj3vQLAMwoyPIOPpu05rHm0eTzdHibEh04ilT0Hf2LxnRs5jxgb0T+CrvYefWfNZDxrqG2yQXz5cU+3rVrM29qe3WCGa98xwXLOQfOeSXl3LDZI=
---

# 今天玩什么 (What to Play Today)

一款 **Millennium Steam 客户端插件**。

在 Steam 标题栏工具栏增加一个骰子按钮，点击后弹出「今天玩什么」窗口，
点击「开始抽取」，即可从 **你拥有的 Steam 游戏**（默认仅已安装）中随机抽取一款，并支持 **一键启动**。

---

## 一、目录结构

```
what-to-play-today/
├── plugin.json                     # Millennium 识别插件的入口元数据
├── README.md
├── games_cache.json                # 游戏列表缓存（自动生成，24 小时过期）
├── blacklist.json                  # 黑名单持久化（自动生成，可选）
├── .millennium/
│   └── Dist/
│       └── index.js                # 客户端脚本：注册插件 → 注入按钮 → 弹窗 UI → 随机抽取 → 启动游戏
└── backend/
    ├── main.lua                    # Lua 后端入口（RPC 方法 + on_load / on_frontend_loaded / on_unload）
    └── library.lua                 # 已安装游戏清单扫描（libraryfolders.vdf + appmanifest_*.acf）
```

| 文件 | 说明 |
| --- | --- |
| `plugin.json` | 插件元信息，`name` 必须与文件夹名一致，声明 `backendType: "lua"` |
| `.millennium/Dist/index.js` | 前端注入模块（工具栏按钮 + 弹窗 UI），Millennium 加载插件时在 Steam CEF 主窗口中执行 |
| `backend/main.lua` | Lua 后端入口，暴露 `GetInstalledGames()` / `GetBlacklist()` / `SaveBlacklist()` / `Ping()` / `LogDiag()` / `GetGamesCache()` / `SaveGamesCache()` / `OpenInBrowser()` 全局方法并返回生命周期回调 |
| `backend/library.lua` | 后端子模块，被 `require("library")` 引用，解析 `appmanifest_*.acf` 得到已安装游戏 |
| `games_cache.json` | 前端通过 Steam Web API 拉取的游戏列表缓存，避免每次打开弹窗都请求接口 |
| `blacklist.json` | 用户加入黑名单的 AppID 列表，持久化到插件目录 |

---

## 二、安装方法

1. 将整个 `what-to-play-today` 文件夹复制到 Millennium 插件目录：

   `<Steam 安装目录>\millennium\plugins\what-to-play-today`

2. 完全退出 Steam（托盘图标 → 退出），再重新启动。
3. 启动后，在 **库（Library）** 页面的标题栏第二行（导航行）右侧会出现骰子按钮。

> 若 Millennium 未识别插件：确认文件夹名与 `plugin.json` 中的 `name` 完全一致（均为 `what-to-play-today`）。

---

## 三、使用说明

### 首次使用：配置 API Key

插件通过 **Steam Web API** 读取你的游戏库，首次使用需在弹窗内点击「设置」配置：

1. **Steam Web API Key**：前往 [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey) 申请（域名可任意填写），复制粘贴到输入框；
2. **Steam ID（17 位数字）**：插件会自动检测当前登录账号，留空即可；若检测不到，可从个人资料页 URL 中复制数字 ID。

> 配置保存在浏览器 `localStorage` 中，不会上传到任何第三方。

### 抽取游戏

1. 点击标题栏的骰子按钮 → 弹出「今天玩什么」窗口；
2. 窗口顶部显示状态：`共 N 款游戏 · 当前候选 M 款`（若配置了黑名单还会显示黑名单数量）；
3. 点击「开始抽取」→ 卡片区域快速滚动游戏名称后随机落定一款，显示 **游戏图标 / 名称 / AppID / 游玩时长 / 占用空间**（未安装会标注「未安装」，已全成就会标注「全成就」）；
4. 点击「启动游戏」→ 调用 `SteamClient.Apps.RunGame(gameId, "", -1, 0)` 启动该游戏；失败时回退到 `steam://rungameid/<appid>`；
5. 点击「不玩这个」→ 本轮排除该游戏并立即重新抽取，可反复换到满意为止；
6. 勾选「添加还未安装的游戏」→ 抽取范围扩大到你拥有但尚未安装的游戏；
7. 底部「本次排除 N 款 / 重置排除」→ 查看并清空本轮排除列表（仅本次弹窗会话内有效，关闭后重置）。

### 黑名单（持久化）

1. 点击弹窗右上角「黑名单(N)」打开黑名单管理窗口；
2. 通过搜索框按 **游戏名称** 或 **AppID** 筛选；
3. 点击列表项可将该游戏加入 / 移出黑名单；
4. 黑名单持久化保存在插件目录的 `blacklist.json` 中，重启 Steam 后依然生效；被加入黑名单的游戏永远不参与抽取。

---

## 四、特性

### 1. 工具栏按钮

- **仅在库页面显示**：导航到商店、社区等非库页面时自动隐藏，切回库页面时重新定位显示；
- **固定贴视口右侧边缘**：使用 CSS `right: 12px` 定位，窗口拉伸 / 全屏时按钮天然跟随右边，不会飞走；
- **垂直居中于导航行**：与「商店 / 库 / 社区」所在行的按钮垂直居中；
- **独立图层**：`position: fixed; z-index: 1000000`，不加入 Steam 工具栏按钮组，不挤压推移原生按钮；
- **不随 Steam 重渲染乱跑**：只在首次挂载、窗口尺寸变化、库↔非库页面切换时重新计算坐标，Steam 内部 DOM 变化（如悬停通知铃铛）不触发重定位；
- **可见性兜底**：挂载后 5 秒内若未能定位到目标行，自动落到右上角可见区，绝不出现「按钮存在但看不见」的状态；
- **自动适配主题**：检测 Millennium 主题的背景色、文字色、强调色、圆角、字体，自动适配深色 / 浅色主题。

### 2. 弹窗 UI

- 首选 `MILLENNIUM_API.showModal(element, undefined, { strTitle, popupWidth, popupHeight, bForcePopOut: true, bHideActionIcons: true })` 由 Millennium 创建独立弹窗窗口；
- 兜底：若 `showModal` 不可用，使用 ReactDOM 在主窗口内渲染自有遮罩浮层（带标题栏与「关闭」按钮）；
- 弹窗样式自动适配当前 Millennium 主题。

### 3. 游戏清单获取（双源）

| 优先级 | 来源 | 说明 |
| --- | --- | --- |
| 1 | **Steam Web API** `IPlayerService/GetOwnedGames/v0001/` | 前端直接 fetch，返回你拥有的所有游戏（含名称 / 游玩时长 / 最后游玩时间 / 图标 hash），结果缓存到 `games_cache.json`（24 小时） |
| 2 | `SteamClient.InstallFolder.GetInstallFolders()` | Steam 自身的已安装清单，用于判断 Web API 返回的游戏是否已安装（过滤未安装项） |
| 3 | Lua 后端 `GetInstalledGames()` | 回退方案：解析 `steamapps/libraryfolders.vdf` 找齐所有库目录，再逐个解析 `appmanifest_<appid>.acf`（过滤 `StateFlags` 未完全安装的条目） |

- 默认 **仅抽取已安装** 的游戏（用 `InstallFolder` / 后端清单过滤 Web API 结果）；
- 勾选「添加还未安装的游戏」后，抽取范围扩大到所有拥有的游戏；
- 按 `app_type` 过滤掉工具 / DLC / 音乐等非游戏条目（拿不到 `app_type` 时按名称兜底过滤 Steamworks redistributables、Proton、Steam Linux Runtime、SDK、Server 等）；
- 游戏图标优先用 `iconHash` 拼成 Steam Community CDN 地址，失败时回退到 capsule 图。

### 4. 启动游戏

```
SteamClient.Apps.RunGame(gameId, "", -1, 0)   // gameId 优先取 appStore overview 的 GetGameID()
        ↓ 失败时
SteamClient.URL.ExecuteSteamURL("steam://rungameid/" + gameId)
```

### 5. 缓存机制

- Steam Web API 结果缓存到后端 `games_cache.json`，24 小时内直接复用，无需重复请求；
- 点击「强制刷新」可绕过缓存重新拉取；
- 缓存写入失败不影响抽取流程。

---

## 五、排障

在 Steam 客户端使用 Millennium 打开日志，过滤关键字 `WhatToPlay`：

- `插件已加载 v1.0.0` —— 插件脚本已执行；
- `[diag] mount {...}` —— 按钮已挂载（含锚点候选数量、fixed 基准宿主）；
- `[diag] dock {...}` —— 已定位（`mode` = `nav-right`，含最终坐标）；
- `[diag] hide {reason: "not-library"}` —— 切到非库页面，按钮已隐藏；
- `[diag] fallback {...}` —— 锚点定位超时，已走可见性兜底；
- `API 返回 N 款游戏` —— Steam Web API 读取结果；
- `已安装 N 款` —— 已安装过滤后的数量；
- `缺少 API Key 或 Steam ID` —— 未配置，请点击「设置」；
- `后端清单读取失败` —— `SteamClient.InstallFolder` 与 Lua 后端均不可用（请附上完整报错）。

### 定位诊断日志

按钮定位的每一步都会以 `[diag]` 前缀记录，内容包括：**锚点候选数量**、**命中模式**（`nav-right`）、**最终坐标**以及 **fixed 基准宿主**。三个查看入口：

1. Steam 控制台（`F12`）过滤 `[diag]`；
2. 控制台执行 `window.__TWTP_DIAG__` 查看最近 15 条；
3. 插件日志文件 `<Steam>\millennium\logs\`（由后端 `LogDiag` 写入，节流 1.2 秒）。

后端日志位于 `<Steam>\millennium\logs\`（同时输出到 Millennium 控制台），标签为 `[WhatToPlay]`。

---

## 六、后端 RPC 接口

前端通过 `Millennium.callServerMethod("what-to-play-today", "<方法名>", <参数>)` 调用以下 Lua 方法：

| 方法 | 参数 | 返回 | 说明 |
| --- | --- | --- | --- |
| `Ping` | 无 | `{ ok, plugin, version }` | 连通性检查 |
| `GetInstalledGames` | 无 | `{ ok, games: [...] }` | 扫描 `libraryfolders.vdf` + `appmanifest_*.acf`，返回已安装游戏（`appid` / `name` / `install_dir` / `sizeOnDisk` / `library`） |
| `GetBlacklist` | 无 | `{ ok, blacklist: [appid,...] }` | 读取持久化黑名单 |
| `SaveBlacklist` | `[appid,...]` (JSON 字符串) | `{ ok }` | 保存黑名单到 `blacklist.json` |
| `GetGamesCache` | 无 | `{ ok, data }` 或 `{ ok: false }` | 读取游戏列表缓存 |
| `SaveGamesCache` | `{ games, game_count }` (JSON 字符串) | `{ ok }` | 保存游戏列表缓存到 `games_cache.json` |
| `LogDiag` | `text` | `{ ok }` | 前端定位诊断日志写入后端日志文件 |
| `OpenInBrowser` | `url` | `{ ok }` | 用系统默认浏览器打开 URL（仅允许 http/https，Windows 用 `rundll32` 不弹 cmd 窗口） |

---

## 七、兼容性说明

Steam 客户端内部 API（`findModule` 类名、`InstallFolder`、`RunGame`、`appStore` 字段名）随客户端版本迭代可能变化，
本插件已针对每一处关键调用做了「多重定位 + 兜底 + 失败日志」处理：

- 工具栏按钮定位不依赖写死的 CSS Module 类名，改用文本锚点（商店 / 库 / 社区）+ 几何分簇 + 通知铃铛兜底；
- `appStore` 字段名（`appid` / `nAppID` / `m_nAppID` 等）、`app_type` 取值、图标 hash 字段均做多字段兼容；
- 启动游戏提供 `RunGame` → `ExecuteSteamURL` 两级兜底；
- 已安装清单提供 `InstallFolder` → Lua 后端两级兜底。

出现异常时请查看控制台日志定位具体环节。

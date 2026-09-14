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
窗口内点击「开始抽取」，即可从 **Steam 库中已安装的游戏** 里随机抽取一款，并支持 **一键启动**。

---

## 一、目录结构

```
what-to-play-today/
├── plugin.json                     # Millennium 识别插件的入口元数据
├── README.md
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
| `backend/main.lua` | Lua 后端入口，暴露 `GetInstalledGames()` / `Ping()` / `LogDiag()` 全局方法并返回生命周期回调 |
| `backend/library.lua` | 后端子模块，被 `require("library")` 引用，解析 `appmanifest_*.acf` 得到已安装游戏 |

---

## 二、安装方法

1. 将整个 `what-to-play-today` 文件夹复制到 Millennium 插件目录：

   <Steam 安装目录>\millennium\plugins\what-to-play-today

2. 完全退出 Steam（托盘图标 → 退出），再重新启动。
3. 启动后，Steam 主窗口标题栏第二行（导航行）右上角会出现骰子按钮。

> 若 Millennium 未识别插件：确认文件夹名与 `plugin.json` 中的 `name` 完全一致（均为 `what-to-play-today`）。

---

## 三、使用说明

1. 点击标题栏的骰子按钮 → 弹出「今天玩什么」窗口；
2. 窗口顶部显示状态：`库中已安装 N 款游戏 · 当前候选 M 款`；
3. 点击「开始抽取」→ 卡片区域快速滚动后随机落定一款游戏，显示游戏名 / AppID / 游玩时长 / 占用空间；
4. 点击「启动游戏」→ 调用 `SteamClient.Apps.RunGame(gameId, "", -1, 0)` 启动该游戏；
5. 点击「不玩这个」→ 本轮排除该游戏并立即重新抽取，可反复换到满意为止；
6. 勾选「只抽还没玩过的游戏」→ 仅从游玩时长为 0 的游戏中抽取；
7. 底部「已排除 N 款 / 重置排除」→ 查看并清空本轮排除列表。

> **提示**：排除列表仅在本次弹窗会话内有效，关闭弹窗后重置。

---

## 四、特性

### 1. 工具栏按钮

- **仅在库页面显示**：导航到商店、社区等非库页面时自动隐藏，避免干扰这些页面的工具栏；
- **固定贴视口右侧边缘**：使用 CSS `right: 12px` 定位，窗口拉伸/全屏时按钮天然跟随右边，不会飞走；
- **垂直居中于导航行**：与「商店 / 库 / 社区」所在行的按钮垂直居中；
- **独立图层**：`position: fixed; z-index: 1000000`，不加入 Steam 工具栏按钮组，不挤压推移原生按钮；
- **不随 Steam 重渲染乱跑**：只在首次挂载、窗口尺寸变化、库↔非库页面切换时重新计算坐标，Steam 内部 DOM 变化不触发重定位；
- **自动适配主题**：检测 Millennium 主题的背景色、文字色、强调色、圆角、字体，自动适配深色/浅色主题。

### 2. 弹窗 UI

- 首选 `MILLENNIUM_API.showModal(element, undefined, { strTitle, popupWidth, popupHeight, bForcePopOut: true })` 由 Millennium 创建独立弹窗窗口；
- 兜底：若 `showModal` 不可用，使用 ReactDOM 在主窗口内渲染自有遮罩浮层（带标题栏与「关闭」按钮）；
- 弹窗样式自动适配当前 Millennium 主题。

### 3. 已安装游戏清单（双通道）

| 优先级 | 来源 | 说明 |
| --- | --- | --- |
| 1 | `SteamClient.InstallFolder.GetInstallFolders()` | Steam 自身的已安装清单，返回各库目录的 `vecApps`（含 `nAppID` / `strAppName` / `nUsedSize`） |
| 2 | Lua 后端 `GetInstalledGames()` | 回退方案：解析 `steamapps/libraryfolders.vdf` 找齐所有库目录，再逐个解析 `appmanifest_<appid>.acf`（过滤 `StateFlags` 未完全安装的条目） |

名称、游玩时长、类型等信息通过 `appStore.GetAppOverviewByAppID(appid)` 补全；
按 `app_type` 过滤掉工具 / DLC / 音乐等非游戏条目（拿不到 `app_type` 时按名称兜底过滤 Steamworks redistributables、Proton、Steam Linux Runtime 等）。

### 4. 启动游戏

```
SteamClient.Apps.RunGame(gameId, "", -1, 0)   // gameId 优先取 appStore overview 的 GetGameID()
        ↓ 失败时
SteamClient.URL.ExecuteSteamURL("steam://rungameid/" + gameId)
```

---

## 五、排障

在 Steam 客户端使用 Millennium打开日志，过滤关键字 `WhatToPlay`：

- `插件已加载 v1.0.0` —— 插件脚本已执行；
- `[diag] mount {...}` —— 按钮已挂载（含锚点候选数量、fixed 基准宿主）；
- `[diag] dock {...}` —— 已定位（`mode` = `nav-right`，含最终坐标）；
- `[diag] hide {reason: "not-library"}` —— 切到非库页面，按钮已隐藏；
- `已安装游戏 N 款 [...]` —— 游戏清单读取结果；
- `后端清单读取失败` —— `SteamClient.InstallFolder` 与 Lua 后端均不可用（请附上完整报错）。

### 定位诊断日志

按钮定位的每一步都会以 `[diag]` 前缀记录，内容包括：**锚点候选数量**、**命中模式**（`nav-right`）、**最终坐标**以及 **fixed 基准宿主**。三个查看入口：

1. Steam 控制台（`F12`）过滤 `[diag]`；
2. 控制台执行 `window.__TWTP_DIAG__` 查看最近 15 条；
3. 插件日志文件 `<Steam>\millennium\logs\`（由后端 `LogDiag` 写入，节流 1.2 秒）。

后端日志位于 `<Steam>\millennium\logs\`（同时输出到 Millennium 控制台），标签为 `[WhatToPlay]`。

---

## 六、兼容性说明

Steam 客户端内部 API（`findModule` 类名、`InstallFolder`、`RunGame`）随客户端版本迭代可能变化，
本插件已针对每一处关键调用做了"多重定位 + 兜底 + 失败日志"处理，出现异常时请查看控制台日志定位具体环节。

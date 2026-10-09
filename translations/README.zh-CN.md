<p align="center">
  <img src="../assets/icon-256.png" alt="DockTouchBar" width="128" height="128">
</p>

<h1 align="center">DockTouchBar</h1>

<p align="center">
  <strong>把 Dock 放到 Touch Bar 上。</strong>
  <br>
  <strong>简洁 · 优雅 · 高效</strong>
  <br>
  单击切换 · 双击最小化 · 长按退出
  <br>
  <a href="https://hooosberg.com/apps/docktouchbar">产品页</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar/diary">开发日记</a>
</p>

<p align="center">
  <strong>两个 App，两个下载：</strong>
  <br>
  <a href="https://github.com/hooosberg/DockTouchBar/releases/latest"><strong>⬇ DockTouchBar</strong></a>（纯净版：把 Dock 放到 Touch Bar 上）
  &nbsp;·&nbsp;
  <a href="https://github.com/hooosberg/DockTouchBar/releases/tag/vibe-v1.23"><strong>⬇ DockTouchBar Vibe</strong></a>（另外在图标上显示 AI 智能体的实时状态）
  <br>
  <sub>拿不准就先用纯净版。<a href="#两个版本">两者有什么区别、在哪里下载？</a></sub>
</p>

<p align="center">
  <a href="../README.md">English</a> ·
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.pt.md">Português</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.it.md">Italiano</a> ·
  <a href="README.tr.md">Türkçe</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-444.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20芯片-已实测-2e7d32.svg" alt="Apple 芯片：已实测">
  <img src="https://img.shields.io/badge/Intel-未实测-f9a825.svg" alt="Intel：未实测">
  <img src="https://img.shields.io/badge/Swift-AppKit-F05138.svg" alt="Swift + AppKit">
  <img src="https://img.shields.io/badge/许可证-PolyForm%20Noncommercial-1e88e5.svg" alt="PolyForm Noncommercial">
</p>

## 两个版本

| | **DockTouchBar**（纯净版） | **DockTouchBar Vibe**（Vibecoding 版） |
|---|---|---|
| 适合 | 所有有 Touch Bar 的 Mac 用户 | 用 AI 编程智能体的人（Claude Code、Codex、Qoder、WorkBuddy、Antigravity……） |
| 是什么 | 把 Dock 放到 Touch Bar 上：单击、双击、长按 | 包含纯净版的全部功能，另外在智能体所在 App 的图标上显示实时状态：工作时是像素风屏幕加字符雨，做完显示 **OK** |
| 下载 | [**下载纯净版**](https://github.com/hooosberg/DockTouchBar/releases/latest) | [**下载 Vibe 1.23**](https://github.com/hooosberg/DockTouchBar/releases/tag/vibe-v1.23) |

**在哪里下载**

- **纯净版** → 仓库的 [**Releases** 页面](https://github.com/hooosberg/DockTouchBar/releases/latest)（标着 **Latest** 的那个发布，也就是本页右侧栏显示的那个）。下载 `DockTouchBar-<版本>.dmg`。
- **Vibe 版** → 它自己的发布 [**Vibe 1.23**](https://github.com/hooosberg/DockTouchBar/releases/tag/vibe-v1.23)，在 **Assets** 里下载 `DockTouchBarVibe-<版本>.dmg`。GitHub 的侧栏只能显示一个 “Latest”，所以侧栏里看不到 Vibe：请用这个链接，或者到完整的 [Releases 列表](https://github.com/hooosberg/DockTouchBar/releases)里找名字带 “Vibe” 的那个。

**拿不准就先用纯净版。** 如果你在这台 Mac 上用 AI 编程智能体，想直接在 Touch Bar 上看到哪个正在忙、哪个刚做完，就选 **Vibe**。Vibe 是一个独立的 App（有自己的名字、设置和更新），已经包含完整的 Dock，所以两个只需要装一个。它们都会占用 Touch Bar，一次只运行一个（如果纯净版正在运行，Vibe 会提示你）。两个版本都在这个仓库里：纯净版是 `main` 分支，Vibe 是 `vibecoding` 分支。

![Touch Bar 上的 DockTouchBar](../assets/touchbar-idle.gif)
*平时工作状态：图标底部贴边、右上角激活状态标点（当前前台应用红色小圆点），最右侧像素咖啡杯白烟动态飘动*

![长按退出：四季主题关闭效果](../assets/touchbar-seasons.gif)
*长按退出演示：像素画四季长按倒计时动画（春·奔跑小狗 / 夏·帆船冲浪 / 秋·林间小狐 / 冬·雪橇滑雪），中途松手即取消，松手后还有收尾消散风暴*

### ⚡ 能耗与性能（早期版本实机测量）

DockTouchBar 的应用和窗口更新以事件驱动为主。下表是早期版本的测量记录；截图活动期间会临时进行短间隔进程检查，不能把历史空闲数据当成当前所有状态的性能保证。

| 指标维度 | 实测数据 | 说明 |
|---|---|---|
| **CPU 占用** | **0.0% ~ 0.8%** | 日常空闲 0.0%；仅在切换应用或窗口变动时有瞬间微小起伏 |
| **物理内存 (Footprint)** | **29 MB** | macOS 官方 `footprint` 工具实测，远低于传统跨平台工具 |
| **能耗影响 (Energy Impact)** | **0.0** | 活动监视器最低档能耗，对电池续航几无影响 |
| **常驻线程** | **4 线程（全部休眠等待事件）** | 零忙等待，无高频心跳唤醒 |
| **网络访问** | **GitHub 更新检查与下载** | Dock 交互在本地执行；无统计、无账号 |
| **渲染性能** | **单帧约 2.3 ms** | 原生 CoreAnimation / AppKit 渲染，触控灵敏跟手 |

**如果 DockTouchBar 对你有用，去 GitHub 点个 ⭐ Star，就是最好的支持。**

## DockTouchBar Vibe：看见你的 AI 智能体在工作

![Touch Bar 上的 AI 编程智能体：空闲、工作中、做完](../assets/vibe-agents.gif)
*Vibe：智能体所在 App 的图标，在它工作时变成一块像素风小屏幕、字符雨往下掉，做完后显示 **OK**，点一下图标就消失。图里五个图标依次是 Claude Code、Codex、Qoder、WorkBuddy、Antigravity。*

- **不用等我们逐个适配。** 复制一段提示词，粘贴给你的智能体，它自己接进来。
- 动画由 App 自己画，用的是智能体所在 App 的真实图标，所以没见过的工具也能用，没有为某个智能体预先做好的素材。
- **像素画风格：** 图标被重画成锐利的 8-bit 像素画，每个图标有自己的小调色板，外面套一个老式 CRT 屏幕边框。边框、字符雨和 **OK** 用的是同一个像素格。

**三步配对一个智能体**

1. 打开 **设置 → 配对智能体**，点 **复制提示词**。
2. 把它粘贴给你的智能体（任何能在你的 Mac 上执行命令的智能体）。它会先自检，再用最合适的方式接进来：用它自己的 hook，没有 hook 就写一条规则进它的长期指令；Vibe 能自己看到的 App 则什么都不用改。改配置前先备份，告诉你每一步。
3. 连接和宿主识别是否通过由 Vibe 自己判定（智能体不能给自己打“通过”），通过后才可登记到列表。验证会播放动画演示，但不代表 hook 已获信任或自动执行。完成所需的 hook 信任后，交给智能体一个任务，确认图标随工作状态变化。列表分别说明连接验证和收到的事件；手动发送的事件也不能证明自动上报已启用。**试一下** 只播放动画，**复制取消配对提示词** 让智能体撤销改动。

![配对智能体页面](../assets/vibe-pairing-zh.png)

需要知道的：

- **App 从不修改其他工具的配置。** 是你把提示词粘贴给智能体之后，由它在你的 Mac 上改；提示词要求它先备份、不碰你已有的 hook、并告诉你做了什么。这个功能不会把任何数据发出 Mac。
- **需要智能体能在你的 Mac 上执行命令，并且跑在一个桌面 App 里**（终端或编辑器也行）。纯网页聊天工具不行。如果智能体连不上 App，提示词要求它如实说明，不能说成功。
- **有些智能体会请你信任一次新的 hook。** 比如 Codex：ChatGPT 设置 → Hooks → 全部信任，智能体会告诉你去哪里点。
- 即使 Vibe 正在运行，沙箱仍可能拒绝访问本地 socket。配对命令会在 `NOT_REACHABLE` 后保留原因、`nc` 退出码和能够取得的原始错误。有些 macOS 版本的 `nc` 即使开启详细输出也不报告原因，此时 `reason=connection_failed` 明确表示原因未知，不能据此认定 Vibe 未运行。遇到 `reason=permission_denied` 应停下并通过智能体的正式权限流程申请批准，再原样重跑命令，不要关闭沙箱或绕过 hook 信任。`reason=no_response` 表示连接没有收到回复，不算自检成功。

### 支持的智能体

**任何能在你的 Mac 上执行命令的智能体都可以配对。下面只是目前试过的，不是上限。**

| 智能体 | 怎么接入 | 备注 |
|---|---|---|
| Claude Code | 它自己的 hook | |
| Codex（ChatGPT 应用 / 命令行） | 它自己的 hook | 要信任一次 hook：ChatGPT 设置 → Hooks → 全部信任 |
| Qoder | 它自己的 hook | |
| WorkBuddy | 它自己的 hook | |
| Antigravity | 写进它长期指令里的一条规则（`GEMINI.md`） | 没有 hook，靠智能体每次照做 |
| 千问办公（Qwen Work） | 写进它长期指令里的一条规则 | 同上 |
| 豆包（Doubao Work） | Vibe 只读地看它自己的会话文件 | 不改豆包任何东西 |
| **其他任何智能体** | 粘贴提示词 | 它自己选 hook 或指令规则，并汇报结果；如果连不上 Vibe，提示词要求它如实说明，不能说成功 |

以上都只在作者的 Mac 上试过。配对的安全约束：提示词要求智能体先备份、只增加不删除设置、结果和预期不一致就停下并把原始输出给你看、不许伪造验证。

## 为什么做

Pock、PockV2 等都能把 Dock 放到 Touch Bar 上，但它们做的事情更多，日常用起来 Touch Bar 容易消失或点了没反应。DockTouchBar 只做一件事，并且把这件事做好。

**简洁**

- 只做一件事：Touch Bar 上的 Dock。没有小组件，没有插件。
- 菜单栏里只有几个开关，没有别的要配置。
- 原生 Swift 和 AppKit，没有第三方依赖；像素场景数据随源码提供。

**优雅**

- 使用 macOS 图标和系统自己的 Touch Bar 滚动控件。未固定的运行中应用放在左侧，新启动的排在最前面；固定应用保持系统 Dock 顺序。关闭应用后保留当前可视区域。
- 手势不打扰你：单击立刻生效，不会为了等你是不是要双击而延迟；长按时图标下方出现一条安静的进度条，Touch Bar 右边缘还会显示“正在关闭…”和倒计时（手指不会挡住），背景是一幅像素画的季节小场景，春夏秋冬可以在菜单里切换，中途松手就取消。
- 连点也很跟手：永远以最后一下为准，也不会和你争。切桌面被系统丢掉、或者焦点被别的 App 抢走，它会悄悄纠正回来；你一动键盘、鼠标或触控板，它立刻停手。
- 跟随你的语言（12 种语言，从简体中文、English 到 日本語），只需要一个可选的权限。

**高效**

- 应用与窗口更新由事件驱动。早期版本在 M1 MacBook Pro 上开着 Dock 空闲时实测：**CPU 0.0%**、**空闲唤醒 0 次**、内存约 **32 MB**。\*
- 适应你的电脑，而不是用固定的等待时间：切桌面时等系统自己发出的“切完了”信号并核对结果，动画慢、关掉动画、机器很忙时都不会出错。
- App 启动或退出时只更新变化的部分，滚动位置不会被打断；图标只栅格化一次并缓存。
- 能自己恢复：睡眠唤醒、屏幕解锁、控制条进程重启之后自动重新挂上，不用手动重开。
- 失败时安全：私有接口在运行时解析，系统删掉某个接口时，对应功能自动关闭，而不是崩溃。
- 隐私：没有统计和账号。Dock 交互在本地执行；自动检查更新和用户请求的下载会连接 GitHub，偏好设置保存在本机。

<sub>\* Release 版本。CPU 是 `top` 连续 5 次采样（间隔 2 秒）都是 0.0%；唤醒次数是读内核的进程计数器、隔 20 秒读两次做差，1.10 上测了三次（每次空闲唤醒和中断唤醒都是 0 次；此前在 1.8 上有一次中断唤醒 0～7 次，来自系统事件）；内存是 `footprint` 的物理占用（32 MB）。咖啡杯上方的蒸汽是系统的渲染进程画的，不是 App 本身在动。</sub>

## 功能

| 操作 | 效果 |
|---|---|
| **单击**图标 | 切换到这个 App，没打开的就启动。App 的窗口在别的桌面时，自动切到那个桌面 |
| **双击** | 最小化当前窗口，等同左上角黄色按钮。需要辅助功能权限；再点图标可恢复 |
| **长按** | 关闭这个 App，并且每次都告诉你结果。按住时图标下方出现进度条，右边缘出现“正在关闭…”倒计时，背景是像素画的季节场景（菜单里选）；中途松手算单击。一律退出整个 App（等同 ⌘Q），不管它有几个窗口、是否最小化或隐藏；访达退不了，所以把它的所有窗口都关掉（含最小化的；窗口在别的桌面就先切过去再关）。如果 App 关不掉，是因为在等你回答（“要保存吗”之类的确认框）或者压根没关，Touch Bar 会切到它那边（包括切桌面）并提示你 |
| **垃圾桶** | 单击在访达中打开废纸篓窗口；双击最小化它；长按关闭它。窗口关闭时图标变暗（“只显示正在运行的 App”模式下直接消失） |
| **左右滑动** | 图标放不下时滚动；关闭应用后保留当前可视区域 |
| **咖啡杯**（右端，杯口有蒸汽动画） | 歇一会儿：暂时隐藏 Dock、把 Touch Bar 还给系统（亮度、音量），10–60 秒后自动回来 |
| **窗口居中 / 最大化按钮**（最右边） | 把最前面 App 的窗口居中；再点一下最大化（铺满可用区域，不是原生全屏），再点回到居中。你自己拖过或换了 App，就先居中，图标会跟着窗口现在的样子变。需要辅助功能权限 |

菜单栏菜单里只保留常用开关：在 Touch Bar 上显示 Dock、只显示正在运行的 App（默认不勾选：固定在 Dock 里的 App 也会显示；勾选后变灰的图标——包括没有窗口的访达、已关闭的垃圾桶——都不显示，访达排在最左）、图标居中显示（图标放得下时居中，超出宽度就从左边开始滑动）、显示“窗口居中 / 最大化”按钮、登录时自动启动。点 **设置…** 打开设置窗口，有三页：

- **设置**：图标间距；点咖啡杯后临时隐藏的时长（10 / 20 / 30 / 60 秒）；居中后窗口的大小（高度为屏幕高度的 60–100%；宽度与高度相同，或为屏幕宽度的 50–100%）；双击最小化；长按关闭（不启用 / 1 / 2 / 3 / 5 秒）及提示风格（春夏秋冬，选中后 Touch Bar 上会演示一遍）；系统 Touch Bar 避让（截图 / 录屏与 Fn 两个独立开关，默认开启）；语言（跟随系统，或 12 种语言之一，位于设置页最上面；Touch Bar 上长按关闭的提示也会跟着翻译）；辅助功能权限状态和去系统设置的入口（除此之外不需要任何权限）；“为什么看不到 Dock？”诊断
- **使用说明**：手势和按钮
- **关于**：版本、检查更新、产品页和开发日记链接、Star 按钮

装好后程序坞里也有它的图标，可以从那里启动。

App 已经在运行时，再从「应用程序」打开它，会直接弹出这个菜单。

## 使用环境和实测情况

| | |
|---|---|
| 硬件 | 带 Touch Bar 的 Mac（MacBook Pro 2016–2022） |
| **实测环境** | **MacBook Pro 13 英寸（M1，`MacBookPro17,1`），macOS 27.0，单显示器，3 个桌面，Touch Bar 设为“展开的控制条”，开着台前调度** |
| Apple 芯片（M1） | ✅ 这就是开发和日常使用的机器 |
| Intel | ⚠️ **未知。** 安装包是通用二进制，在 M1 上用 Rosetta 能启动 Intel 部分，但从没在真正的 Intel Touch Bar 机器上跑过。欢迎反馈 |
| macOS 版本 | 最低按 macOS 13 编译，但只在 macOS 27.0 上测过，更早的版本没测 |

需要知道的几件事：

- 后台 App 要让 Touch Bar 一直显示，只能用 **Apple 的私有 API**。所以它不能上架 Mac App Store，以后 macOS 更新也可能让它失效。私有接口都是在运行时解析的，缺了哪个，对应功能会自己关闭而不是崩溃；运行 `swift tools/probe-private-api.swift` 可以看到你的 macOS 里还有哪些。
- Dock 会占满**整条** Touch Bar，开着的时候系统控制条（亮度、音量）看不到。要用时，点 Touch Bar 右侧的咖啡杯，Dock 暂时隐藏、Touch Bar 还给系统（10–60 秒后自动回来，默认 20 秒；如果屏幕被调到全黑，则等亮度调回来就自动恢复）。也可以在菜单里取消勾选“在 Touch Bar 上显示 Dock”。
- 图标从左到右：未固定的运行中应用（最近启动的在最前）→ 分隔线 → 访达 → 按系统 Dock 顺序固定的 App → 分隔线 → 垃圾桶。新启动的临时应用会自动出现在左侧可视区域；切换已经打开的应用不会重新排序。点击垃圾桶可在访达中打开。
- 开着台前调度时，macOS 会给窗口切换加动画，窗口在屏幕上出现要约半秒。被点的 App 变成前台只要约 40 毫秒，剩下的时间是系统的动画。

## 安装

1. 到 [Releases](https://github.com/hooosberg/DockTouchBar/releases/latest) 下载 `DockTouchBar-<版本>.dmg`。（要用 **Vibe**，到它的[发布页](https://github.com/hooosberg/DockTouchBar/releases/tag/vibe-v1.23)下载 `DockTouchBarVibe-<版本>.dmg`，把 **DockTouchBar Vibe** 拖进「应用程序」；区别见[两个版本](#两个版本)。）
2. 打开后把 **DockTouchBar** 拖到 **Applications**，再启动它。菜单栏和 Touch Bar 上会出现图标。

> DMG 用 Developer ID 证书签名，并且**已通过 Apple 公证**，所以和普通 App 一样可以直接打开，第一次启动时系统只会让你确认一下。想自己编译的话，见[从源码编译](#从源码编译)。

### 辅助功能权限（可选）

跨桌面切换、双击最小化、居中 / 最大化、关闭访达的窗口、识别确认框和 Fn 避让需要辅助功能权限。未授权时仍可启动和激活应用，上述功能会受限。

1. 菜单栏图标 → **设置…** → **权限** → **去开启…**（授权后会显示“辅助功能：已开启”）
2. 在 系统设置 → 隐私与安全性 → 辅助功能 里打开 DockTouchBar。

如果打开后仍然提示授权，说明旧记录已失效（App 的签名变了就会这样）：在列表里选中 DockTouchBar，点 **−** 删掉，再重新添加。或者运行 `tccutil reset Accessibility com.maohuhu.docktouchbar` 后重做第 1 步。

### 点了没有切到桌面时

出问题之后马上在仓库目录里运行下面这条。它是只读的，会打印程序当时怎么判断这个 App 的窗口：有哪些窗口、各在哪个桌面、哪些是真实窗口、最后会提前哪一个：

```bash
tools/diagnose-switch.sh com.google.Chrome
```

## 看不到 Dock？

最常见的原因：系统设置 → 键盘 → 「触控栏显示」被设为「显示 F1、F2 等键」，整条 Touch Bar 被功能键占满。1.16 起 App 会自动检测，并在首次启动时询问是否改为「展开的控制条」；之后可随时点菜单栏图标里的「诊断：为什么看不到 Dock？」逐项排查，还能一键复制诊断信息用于反馈。改完后按住 Fn 仍可看到 F1–F12。

## 从源码编译

需要 Xcode 命令行工具。

```bash
git clone https://github.com/hooosberg/DockTouchBar.git
cd DockTouchBar
scripts/install.sh      # 编译 → 装到 /Applications → 启动
scripts/make-dmg.sh     # 生成 build/DockTouchBar-<版本>.dmg
```

没有签名证书时会退回 ad-hoc 签名。能用，但 macOS 会把每次重新编译的 ad-hoc 版本当成新 App，辅助功能权限每次都要重新授权。设置 `SIGN_IDENTITY="Apple Development: …"`（或 Developer ID 证书）可以固定签名身份。

## 目录结构

```
Sources/DockTouchBar/   App 源码
Resources/              Info.plist、App 图标
scripts/                build.sh、install.sh、make-dmg.sh、make-icon.sh
tools/                  诊断工具：私有接口检查、桌面与窗口查看、切换诊断、连点压力测试、离屏预览、render-seasons.sh（README 里的截图）
assets/                 README 里的图片
```

macOS 大版本更新后，运行 `swift tools/probe-private-api.swift` 可以看到哪些私有接口还在。

## 许可证

[PolyForm Noncommercial License 1.0.0](../LICENSE)：**个人使用及其他非商业用途**可以免费使用、复制、修改和分享。**商业使用不在授权范围内**，需要向作者另行取得授权，请通过 [hooosberg.com](https://hooosberg.com/) 联系。

这是“源码可见”许可证，不是 OSI 认可的开源许可证。版权声明：Copyright © 2026 hooosberg。

## 作者

**hooosberg** — [hooosberg.com](https://hooosberg.com/) · [GitHub](https://github.com/hooosberg)。如果它帮你省了几次点击，欢迎 ⭐ Star 支持。

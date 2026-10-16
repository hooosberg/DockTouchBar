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
  <a href="https://github.com/hooosberg/DockTouchBar/releases/latest"><strong>⬇ 下载 DockTouchBar</strong></a>
  <br>
  <sub>一个 App，一个下载。个人使用免费。</sub>
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
  <img src="https://img.shields.io/badge/Apple%20silicon-tested-2e7d32.svg" alt="Apple 芯片：已实测">
  <img src="https://img.shields.io/badge/Intel-untested-f9a825.svg" alt="Intel：未实测">
  <img src="https://img.shields.io/badge/Swift-AppKit-F05138.svg" alt="Swift + AppKit">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-1e88e5.svg" alt="PolyForm Noncommercial">
</p>

## 这是什么

DockTouchBar 把 Dock 放到 Touch Bar 上：单击、双击、长按。如果你用 AI 编程智能体（Claude Code、Codex、Qoder、WorkBuddy、Antigravity……），它还会在智能体所在 App 的图标上显示实时状态：工作时是像素风屏幕加字符雨，做完显示 **OK**。这部分可以在设置里关闭。

**下载：** [Releases 页面](https://github.com/hooosberg/DockTouchBar/releases/latest)，文件 `DockTouchBar-<版本>.dmg`。

*之前用过 DockTouchBar Vibe？* 它已经并入本 App（1.24 及以后版本），所以现在只有一个 App、一份代码、一条发布线。下载 DockTouchBar，然后退出并删除 Vibe。已经配对的智能体继续有效；设置不会自动带过来。

![Touch Bar 上的 DockTouchBar](../assets/touchbar-idle.gif)
*空闲状态：应用图标贴底对齐，右上角有状态小圆点（前台应用为红色）；像素风咖啡杯，杯口有动态蒸汽。*

![长按退出：四季动画](../assets/touchbar-seasons.gif)
*长按退出：像素风倒计时，有四个季节场景。提前松手即取消。*

## 手势

| 手势 | 效果 |
|---|---|
| **单击**图标 | 切换到这个 App，没打开的就启动。App 的窗口在别的桌面（Space）时，自动切换到那个桌面 |
| **双击** | 最小化当前窗口。需要辅助功能权限。再点图标可恢复 |
| **长按** | 退出这个 App（等同 ⌘Q），并显示进度条和倒计时。提前松手即取消。访达无法退出，因此改为关闭它的窗口。如果 App 在等你处理（例如“未保存的更改”对话框），Touch Bar 会切换到它并提示你 |
| **⌥ + 长按** | **强制退出**无响应的 App（访达除外） |
| **垃圾桶** | 单击在访达中打开；双击最小化；长按关闭 |
| **左右滑动** | 图标放不下时滚动 |
| **咖啡杯**（右端） | 歇一会儿：暂时隐藏 Dock，把 Touch Bar 还给系统（亮度、音量）。10–60 秒后自动恢复 |
| **居中 / 最大化按钮**（最右边） | 把最前面的 App 窗口居中；再点一下最大化，再点一下回到居中。需要辅助功能权限 |

菜单栏菜单：在 Touch Bar 上显示 Dock、只显示正在运行的 App、图标居中、显示居中 / 最大化按钮、在程序坞中隐藏图标、登录时启动、设置…。**设置**里有：图标位置（靠左 / 居中 / 靠右）、图标间距、咖啡杯时长、居中窗口大小、双击、长按时间与季节、让位给系统 Touch Bar 控制（截图 / 录屏和 Fn，带一个自动核对定时器：万一没收到“让位结束”，Dock 会自己回来）、语言（12 种）、辅助功能状态，以及“为什么看不到 Dock？”诊断。其他页面：**配对智能体**、**使用说明**、**关于**（含致谢）。

**在程序坞中隐藏图标：** 设置 → 通用 → *在程序坞中隐藏图标*，App 会继续在后台运行，只保留菜单栏图标。

## 看见你的 AI 智能体在工作

![Touch Bar 上的 AI 编程智能体：空闲、工作中、完成](../assets/vibe-agents.gif)
*智能体工作时，它所在 App 的图标会变成一块像素风小屏幕，字符雨往下掉；做完后显示 **OK**。单击图标即可让它消失。图中依次为：Claude Code、Codex、Qoder、WorkBuddy、Antigravity。*

没有针对某个智能体的插件：复制一段提示词，粘贴给你的智能体，它自己接进来。动画由智能体所在 App 的真实图标绘制而成，所以对我们从未见过的工具也适用。

**三步配对一个智能体**

1. 打开 **设置 → 配对智能体**，点击 **复制提示词**。
2. 把它粘贴给你的智能体（任何能在你的 Mac 上执行命令的智能体）。它会先自检，再用最合适的方式接入：用它自己的 hook，或在它的长期指令里加一条规则；对于 DockTouchBar 能自行观察的 App，则什么都不用改。它会先备份配置，并告诉你每一步。
3. 验证是否通过由 DockTouchBar 自己判定（智能体不能给自己标记“已验证”）；通过后，该智能体才会在列表中显示为 **已验证**，之后它工作时图标就会有动画。**试一下** 无需等待任务，直接播放动画；**复制取消配对提示词** 会给智能体一段提示词，让它自己撤销改动。

![配对智能体页面](../assets/vibe-pairing-en.png)

- **App 从不修改其他工具的配置。** 是智能体在你粘贴提示词之后，在你的 Mac 上自行修改。这个功能不会把任何数据发出你的 Mac。
- 需要智能体能在你的 Mac 上执行命令，并且运行在桌面 App 中（终端或编辑器也可以）。如果它连不上 App，提示词会要求它如实说明，而不是声称成功。
- **终端机 / 命令行 AI 助手（Claude Code 等）：** 在终端（如 macOS 终端 Terminal.app、iTerm2、Ghostty 或 VS Code 集成终端）中运行 AI 编程 CLI 时，DockTouchBar 会自动沿进程树向上精准穿透（包括跨越 root 属主的 `login` 进程），找到外层的终端 App 图标。在终端里提问、AI 运行命令或工具时，Touch Bar 上的终端图标立即播放字符雨，任务结束等候输入时变为绿色 **OK**。
- 有些智能体会请你信任一次新的 hook（例如 Codex：ChatGPT 设置 → Hooks → 全部信任）。

| 智能体 | 接入方式 |
|---|---|
| Claude Code（终端 / 命令行 CLI）、Codex（ChatGPT 应用 / CLI）、Qoder、WorkBuddy | 它自己的 hook |
| Antigravity、Qwen Work（千问办公） | 写进它长期指令里的一条规则（Antigravity 用 `GEMINI.md`）；没有 hook，因此依赖智能体遵守该规则 |
| Doubao Work（豆包） | DockTouchBar 只读取它的会话文件 |
| **其他任何智能体** | 粘贴提示词；它自己选择 hook 或指令规则，并汇报结果 |

此列表只是目前试过的（在作者的 Mac 上），并非上限。

## 为什么做这个

Pock 等同类工具也能把 Dock 放到 Touch Bar 上，但它们做的事情更多，日常使用中 Touch Bar 容易消失或停止响应。DockTouchBar 只专注一件事，并把它做好：原生 Swift 和 AppKit，没有第三方依赖；事件驱动（空闲时 CPU 0.0%，约 30 MB 内存）；睡眠唤醒、屏幕解锁和控制条进程重启后能自动恢复；私有接口在运行时解析，缺失时只关闭对应功能，而不会崩溃。没有统计和账号；网络用途仅限检查更新和下载。界面支持 12 种语言。

如果 DockTouchBar 对你有用，在 GitHub 上点个 ⭐ Star 就是最好的感谢。

## 使用环境和实测情况

| | |
|---|---|
| 硬件 | 带 Touch Bar 的 Mac（MacBook Pro 2016–2022） |
| 实测环境 | MacBook Pro 13 英寸（M1），macOS 27.0，Touch Bar 设为“展开的控制条” |
| Apple 芯片 | ✅ 在 M1 上开发并日常使用 |
| Intel | ⚠️ 未实测。安装包是通用二进制，但从未在真实的 Intel Touch Bar Mac 上运行过。欢迎反馈 |
| macOS 版本 | 以 macOS 13+ 为目标编译，但只在 27.0 上测试过 |

- 它使用 **Apple 私有 API** 才能让后台 App 的 Touch Bar 一直显示，因此无法上架 Mac App Store，未来的 macOS 更新也可能使其失效。运行 `swift tools/probe-private-api.swift` 可以查看你的 macOS 仍保留哪些私有接口。
- Dock 会占满**整条** Touch Bar，开启期间系统控制条会被隐藏。可点咖啡杯暂时把它还给系统。

## 安装

1. 到 [Releases](https://github.com/hooosberg/DockTouchBar/releases/latest) 下载 `DockTouchBar-<版本>.dmg`。
2. 将 **DockTouchBar** 拖到 **Applications** 中，然后启动它。

DMG 使用 Developer ID 证书签名，并经过 Apple 公证。想自己编译，请参见 [从源码编译](#从源码编译)。

**辅助功能权限（可选）。** 开启后可使用跨桌面切换、双击最小化、居中 / 最大化、关闭访达窗口、识别确认对话框以及 Fn 让位功能。在 设置 → 权限 → *去开启…* 中打开，然后到 系统设置 → 隐私与安全性 → 辅助功能 中启用。如果之后仍提示授权，请用 **−** 删除旧条目后重新添加，或运行 `tccutil reset Accessibility com.maohuhu.docktouchbar`。

**看不到 Dock？** 最常见的原因是 系统设置 → 键盘 → “触控栏显示”被设为“F1、F2 等键”。1.16 起，App 会提议将其改为“展开的控制条”。你也可以使用菜单中的“诊断：为什么看不到 Dock？”。

**单击后没有切换桌面？** 出现问题后，立即在仓库的克隆目录中运行 `tools/diagnose-switch.sh com.google.Chrome`。它是只读的。

## 从源码编译

需要 Xcode 命令行工具。

```bash
git clone https://github.com/hooosberg/DockTouchBar.git
cd DockTouchBar
scripts/install.sh      # 编译 → 复制到 /Applications → 启动
scripts/make-dmg.sh     # 生成 build/DockTouchBar-<版本>.dmg
```

没有签名证书时，编译结果会使用 ad-hoc 签名，因此 macOS 会把每次重新编译的版本都当作新 App，你必须重新授予辅助功能权限。设置 `SIGN_IDENTITY="Apple Development: …"` 即可保持同一个签名身份。

```
Sources/DockTouchBar/   App 源码
Resources/              Info.plist、App 图标
scripts/                build.sh, install.sh, make-dmg.sh, make-icon.swift
tools/                  诊断工具、智能体配对检查、README 渲染脚本
assets/                 README 图片
```

贡献代码请通过 Pull Request 提交到 `main` 分支。

## 致谢

DockTouchBar 因为以下这些人而变得更好：

| 贡献者 | 贡献 |
|---|---|
| [@thierry-laval](https://github.com/thierry-laval) | 在程序坞中隐藏图标（PR #5）· 长按时按住 ⌥ 强制退出（PR #6）· 通用二进制构建回退到原生构建系统（PR #7） |
| [@1dea193073](https://github.com/1dea193073) | 改进智能体配对诊断，区分演示与真实活动（PR #3） |
| [@Aserti2](https://github.com/Aserti2) | 提出希望能隐藏 Dock 图标的需求（#4） |
| [@fatHROSE](https://github.com/fatHROSE) | 反馈 fn 键让位问题，促使其改为可选；建议图标靠右和自动恢复，二者均在 1.25 实现（#2） |
| [@hlenyafinland](https://github.com/hlenyafinland) | 早期反馈与建议（#1） |

App 内也有同样的名单：**设置 → 关于 → 致谢**。

## 许可证

[PolyForm Noncommercial License 1.0.0](../LICENSE)：可免费用于**个人及其他非商业用途**，包括使用、复制、修改和分享。**商业使用需要另行向作者取得授权**，请通过 [hooosberg.com](https://hooosberg.com/) 联系。这是“源码可见”（source-available）许可证，不是 OSI 认可的开源许可证。Copyright © 2026 hooosberg。

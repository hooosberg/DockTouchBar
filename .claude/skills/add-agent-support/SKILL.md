---
name: add-agent-support
description: 给 DockTouchBar 增加对一个新的 AI 编程助手（Claude Code、Codex 之外，比如 Gemini CLI、Cursor 等）的支持，或调整图标上的状态动画（字符雨、OK、CRT 屏幕外框）。只在 vibecoding 分支做。
---

# 给 DockTouchBar 接入一个新助手 / 调整状态动画

从 `main` 拉功能分支，改完走 PR 合回 `main`。

## 现在只有一条路：提示词配对

App 不再替任何助手改配置（早期的 Claude Code / Codex 内置连接已经去掉；它们早期装的 hook 还在各自配置里继续工作，启动时自动补一份登记）。接入一个新智能体 = 用户在设置 →「配对智能体」页复制提示词（`AgentPairingPrompt.swift`）交给它，由它自己查 hook、改配置、验证、登记到 `agents/<id>.json`。新增智能体**不用改代码**；要改的只有：

1. **提示词措辞**：它在真实智能体上跑得不好时调（`AgentPairingPrompt.swift`，中英两份都要改）。
2. **状态机**（`AgentStatus.swift`）：出现新的卡住/误判时修，并先在 `tools/verify-agent-hooks/main.swift` 里补用例。

## 它是怎么工作的（别重新发明）

1. 智能体的 hook（或它按指令手动）执行 `~/Library/Application Support/DockTouchBar/agent-hook.sh <事件> [id] [会话id] < /dev/null`。
2. 脚本把 `事件[|id] \t 父进程号 \t JSON` 一行写进 Unix socket。手动调用时 JSON 是 `{"session_id":…,"manual":true}`。
3. `AgentMonitor` 从父进程号一路往上找到第一个有 Dock 图标的 App，按 App 汇总 `idle / working / done`。
4. `DockModel` 把状态写进 `DockTile.agentState`，`DockTileView` 交给 `AgentOverlayLayer`（`AgentOverlay.swift`）画动画。动画和状态机跟具体智能体无关。

### 状态机的约定（出过的坑，别改回去）

- **Unix socket 路径不能超过 104 字节**：测试的支持目录要用 `/tmp/dtbv-…` 这种短路径，系统临时目录太长会让 `start()` 静默失败。
- **`activity.json` 要先读后写**：内存里的记录必须启动时从文件载入（`lazy var activity`），否则第一条事件会把别的智能体的记录覆盖掉。
- 自检（`Check` 事件）的回复在读到换行后就发，不要等对方关连接；脚本 `--check` 里用 `{ printf …; sleep 1; } | nc` 让 nc 等到回复（BSD nc 在 stdin 结束后会立刻退出）。

- **严格 vs 宽松**：会话 id 来自 hook 的 JSON（Claude Code、Codex）是严格的，只处理自己的会话，允许同时多个会话；手动调脚本的（`manual:true` 或没有会话 id）是宽松的：Stop/Interrupt 把它名下所有工作中的会话一起收尾，3 分钟没事件就当中断。没带会话 id 时用 `agent-<id>` 当会话，不用进程号（每次调用进程号都不同，永远对不上开始和结束）。
- **心跳不能新建会话**：用户点掉“做完了”之后迟到的 PostToolUse 会造出永远等不到 Stop 的“工作中”。
- **Esc 打断**：Claude Code 不发任何 hook，但会往聊天记录（hook JSON 里的 `transcript_path`）追加 `[Request interrupted by user`；`scanTranscriptsForInterrupts` 每 2 秒从会话开始时的文件位置往后找，找到就回到空闲。Codex 有 `Interrupt` 事件。
- **“已验证”看 `activity.json`**（App 自己写，按 agent id 存最近一次事件），不要看 `events.log`（它只是诊断日志，会被截断、被挪走）。不带 id 的旧 hook，用 `transcript_path` 里的 `/.claude/`、`/.codex/` 认出是谁。
- Codex 的 hook 要用户先在 ChatGPT 设置 → Hooks → 全部信任（命令行 `/hooks`），按 hook 内容的哈希记录，改命令字符串就要重新信任；排查用 `python3 tools/check-codex-hooks.py`。不要替用户伪造信任。

## 案例：豆包（DoubaoWork）——给能力弱的智能体设计流程

事故经过：豆包的命令跑在 `AgentInfraService.xpc` 里，父进程是 launchd，进程链上找不到 App，`--check` 回 `host_app=NOT_FOUND`。它没有停，而是编译了一个冒充 `com.work.pc.doubao` 的包装 App 去发测试事件，设置页因此显示“已验证”，真实任务却没有动画。教训，也是现在流程的设计依据：

1. **判定权在 App，不在智能体。** 以前让智能体自己发测试事件、等两秒、读日志、判断 `app=` 对不对、手写登记 JSON，每一步都能糊弄。现在是 `--verify <id>`（App 自己判断，回 PASS/FAIL，PASS 时在那个图标上放一遍动画）和 `--register …`（App 写登记文件，只收刚通过 `--verify` 的 id，一小时内有效）。别再让智能体手写登记 JSON、别再让它读日志做判断。
2. **App 要容忍恶劣环境，别指望智能体绕。** 宿主识别除了父进程链，还按链上进程的可执行文件路径落在哪个 `.app` 里匹配正在运行的 App（`owningApp(of:)` / `bundleID(containing:among:)`）。沙箱、XPC、容器里的智能体都应该直接 PASS。
3. **红线放最前面，卡住的出口要写死。** 弱智能体碰到意外会“想办法解决”。提示词开头三条红线（不伪造、卡住就停并贴原始输出、只加不删），每一步写明“期望”，不一致就停；FAIL 的回复本身也写“停下来告诉用户，不要伪装”。
4. **少参数、不要占位符。** 提示词里的命令直接是真实路径，不写要智能体自己替换的 `S`；不要它管会话 id（不带会话 id 时 App 用 `agent-<id>`，Stop 宽松收尾）；方案 B 的规则是三句可原样粘贴的话。
5. **固定汇报模板。** 结果、方案、改过的文件、`--verify` 原始输出、需要用户做的事，便于用户一眼看出它有没有糊弄。

6. **没有 hook 的弱智能体，不能只靠它自觉上报（方案 B 的先天缺陷）。** 豆包配对时一切正常（`--verify` PASS、登记成功），但真实任务里它一次都没调用脚本：规则写在它不读的 `~/AGENTS.md`，“长期记忆”里只有一句指针，纯搜索任务根本不用 Bash。所以对豆包加了**被动文件监视**（`AgentFileWatcher.swift` 的 `DoubaoSessionWatcher`，只读、每秒轮询、只在已配对豆包——登记 id 以 `doubao` 开头——时启用）：`.sessions/<会话>/agents/*/system/assignment.md` 追加 = 开始，`trajectory.jsonl` 追加 = 心跳，最后一行是不带工具调用的 assistant 回复 = 做完；回复行有时迟迟不写，所以静默 60 秒也按做完。事件走 `handle(…, bundleID:)`，直接落在 `com.work.pc.doubao` 上。豆包升级后文件结构变了就会失效，现象是 `events.log` 里没有 `src=files` 的行。再遇到类似的智能体：先用文件变化记录器（轮询它数据目录的 mtime）看它工作时哪些文件会稳定变化，能被动感知就别指望它自觉。

7. **向下兼容的三档，由 App 决定，不让智能体猜。** `--check` 的回复里有 `watch=builtin` 或 `watch=none`（`AgentMonitor.builtinWatchedApps`）：① 有自己 hook 的走 hook，最可靠；② `watch=builtin`（App 内置监视，目前只有豆包）：智能体**什么都不用配置**，只做 `--verify` + `--register … passive`（App 要求 passive 只能用在有内置监视的软件上，登记里记下 `host`，监视器按 `host` 启用，不要求 id 叫什么，取消配对 = 直接删登记）；③ `watch=none` 才走方案 B（长期指令，靠自觉，最不可靠）。**给一个新软件加内置监视**：先用文件变化记录器确认它工作时有稳定变化的文件，再写一个像 `DoubaoSessionWatcher` 的只读监视器，把它的 bundleID 加进 `builtinWatchedApps`，并在 `tools/verify-agent-hooks/main.swift` 补用例。

新增或调整流程后，用真实的弱智能体重新跑一遍配对提示词（豆包、千问、WorkBuddy），对照 `events.log` 和设置页确认。

## 排查“没反应 / 卡住”

0. **先自检 / 验证**：`--verify <id>` 由 App 判定 PASS/FAIL（找不到宿主 App 就 FAIL，什么也不记）。自检：`"~/Library/Application Support/DockTouchBar/agent-hook.sh" --check <id> < /dev/null`，输出 `OK` + `host_app=…` 说明链路通且找到了所在 App；`NOT_RUNNING` = App 没开；`host_app=NOT_FOUND` = 进程链找不到有 Dock 图标的 App。配对提示词第 0 步也让智能体先跑它。脚本的 socket 路径可用环境变量 `DTB_SOCKET` 覆盖（测试用）。
1. `~/Library/Application Support/DockTouchBar/events.log`：没有新行 = hook 没执行；有行但 `app=-` = 进程链没找到 App。
2. 设置页配对列表底部的“清除动画状态”；每行的“试一下”在它的所在 App 图标上放 4 秒动画（不用等智能体跑任务）。
3. Claude 桌面版里多个会话共用一个图标，任何一个会话卡在“工作中”整个图标都会动。

## 调整图标上的动画 / 外观

所有绘制在 `AgentOverlay.swift`。**整个图标共用一个像素格：1 格 = 1pt = 2×2 设备像素，整个图标 28×28 格**——8-bit 原图标、CRT 边框、字符雨、OK 全都按这个格子画，对齐才统一；新加任何绘制都要遵守，不要再引入别的像素大小。

- 8-bit 原图标：`pixelated(_:)`。要的是游戏里那种锐利的像素画：**没有渐变、没有抖动、没有中间色**。做法：56×56 原图上先加强饱和度和对比度 → 每个图标 median cut 出 8 色小调色板 → 每个像素直接归到最近的调色板颜色（不平均）→ 缩成 28×28 格时每格取出现最多的颜色（平局取更暗的，保住细线）→ 去孤立噪点格。试过先平均再抖动（Bayer），效果软，用户说“不够锐利”，别改回去。
- CRT 屏幕外框：`crtFrame(of:)`，按格、按“离图标边缘几格”分层（机身边、玻璃边、两层内阴影、左上角反光），所以自动贴合任何圆角，圆角是按格的阶梯。
- 字符雨：`glyphBitmaps`（3×5 格点阵，镜像）、`stripVariants/drawStrip`（字符带的图片一个像素 = 一格，`contentsScale = 1`；只有雨头带淡光晕——每个字符都带的话会连成一片绿盖住图标）。
- OK：`okImage()`（5×7 格，每格 1pt）。

**出图流程（每次改完都跑）**：

```bash
swift build 2>&1 | grep -E "error|Build"
bash tools/preview-agent.sh build/agent-preview.png   # 实时窗口截图，已放大，用 Read 打开看
# 对比多个真实 App 的图标（颜色、辨识度），PREVIEW_CROP 调宽裁剪：
PREVIEW_CROP=640 PREVIEW_AGENT_APPS="/Applications/A.app,/Applications/B.app" bash tools/preview-agent.sh build/compare.png
bash tools/render-settings.sh build/pairing-page.png  # 离屏渲染“配对智能体”页（Stage Manager 会把设置窗口收起来，别截真窗口）
```

看图要点：原图标认不认得出（用白色、黑白、彩色几种图标都试）、字符雨有没有连成一片盖住图标、`OK` 的对比度、边框是否贴合圆角、各部分的像素大小是否一致。静态截图看不出动画流畅度和光标闪烁，要说清楚“没看到动画”，让用户在真 Touch Bar 上确认。

App 图标：改 `scripts/make-icon.swift` 后 `bash scripts/make-icon.sh`，再 Read `Resources/AppIcon-1024.png` 检查。

## 提交前

- `swift build` 通过、`bash tools/verify-agent-hooks.sh` 全 PASS。
- `bash scripts/install.sh` 装到 `/Applications/DockTouchBar.app`，确认进程在跑。

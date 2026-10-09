// 验证 AI 助手接入：事件状态机、配对智能体的宽松收尾、打断检测、登记和最近活动、旧 hook 迁移、提示词和脚本。
// 全程在临时目录里做，不碰真实的 ~/.claude、~/.codex 和应用支持目录。由 tools/verify-agent-hooks.sh 编译运行。
import AppKit
import Darwin

var failures = 0
func check(_ ok: Bool, _ message: String) {
    print(ok ? "PASS \(message)" : "FAIL \(message)")
    if !ok { failures += 1 }
}

let fm = FileManager.default
let temp = fm.temporaryDirectory.appendingPathComponent("verify-agent-hooks-\(UUID().uuidString)", isDirectory: true)
try fm.createDirectory(at: temp, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: temp) }
// Unix socket 的路径不能超过 104 字节，系统临时目录太长，支持目录要用短路径。
let support = URL(fileURLWithPath: "/tmp/dtbv-\(UUID().uuidString.prefix(8))", isDirectory: true)
defer { try? fm.removeItem(at: support) }
AgentMonitor.supportDirectory = support
AgentRegistry.homeDirectory = temp
try fm.createDirectory(at: AgentMonitor.supportDirectory, withIntermediateDirectories: true)

func makeMonitor(_ owner: @escaping (pid_t) -> String? = { _ in "app.one" }) -> AgentMonitor {
    let monitor = AgentMonitor()
    monitor.ownerResolver = owner
    return monitor
}

// 1. 状态机（内置 hook 风格：会话 id 来自 hook，严格）。
do {
    let monitor = makeMonitor { $0 == 100 ? "app.one" : ($0 == 200 ? "app.two" : nil) }
    var changes = 0
    monitor.onChange = { changes += 1 }
    func send(_ event: String, _ session: String, _ pid: pid_t, agent: String? = nil) {
        monitor.handle(event: event, sessionID: session, from: pid, agent: agent)
    }
    check(monitor.state(for: "app.one") == .idle, "状态: 初始空闲")
    send("UserPromptSubmit", "a", 100)
    check(monitor.state(for: "app.one") == .working && monitor.state(for: "app.two") == .idle, "状态: 提问后只有这个 App 在工作")
    send("PostToolUse", "a", 100)
    check(monitor.state(for: "app.one") == .working, "状态: 心跳不改变状态")
    send("Stop", "a", 100)
    check(monitor.state(for: "app.one") == .done, "状态: Stop 后是做完")
    send("PostToolUse", "a", 100)
    check(monitor.state(for: "app.one") == .done, "状态: 做完后迟到的心跳不会翻回工作中")
    monitor.acknowledge(bundleID: "app.one")
    check(monitor.state(for: "app.one") == .idle, "状态: 点图标后回到空闲")
    send("PostToolUse", "a", 100)
    check(monitor.state(for: "app.one") == .idle, "状态: 点掉之后迟到的心跳不会造出永远不结束的“工作中”")
    send("UserPromptSubmit", "a", 100); send("UserPromptSubmit", "b", 100); send("Stop", "a", 100)
    check(monitor.state(for: "app.one") == .working, "状态: 同一个 App 里还有会话在工作，就还是工作中")
    send("Stop", "b", 100)
    check(monitor.state(for: "app.one") == .done, "状态: 都做完才算做完")
    monitor.acknowledge(bundleID: "app.one")
    send("UserPromptSubmit", "c", 200); send("Interrupt", "c", 200)
    check(monitor.state(for: "app.two") == .idle, "状态: Interrupt 直接回到空闲，不显示做完")
    send("UserPromptSubmit", "d", 200); send("SessionEnd", "d", 200)
    check(monitor.state(for: "app.two") == .idle, "状态: SessionEnd 回到空闲")
    send("UserPromptSubmit", "e", 999)
    check(monitor.state(for: "app.one") == .idle && monitor.state(for: "app.two") == .idle, "状态: 找不到所在 App 的事件被忽略")
    // 用 hook 的助手有多个会话同时在跑：一个 Stop 不能带走另一个。
    send("UserPromptSubmit", "s1", 100, agent: "claude-code"); send("UserPromptSubmit", "s2", 100, agent: "claude-code")
    send("Stop", "s1", 100, agent: "claude-code")
    check(monitor.state(for: "app.one") == .working, "严格: 用 hook 的助手，一个会话 Stop 不影响另一个会话")
    monitor.resetAll()
    check(monitor.state(for: "app.one") == .idle, "重置: 一键清掉所有动画状态")
    monitor.isEnabled = false
    send("UserPromptSubmit", "f", 100)
    check(monitor.state(for: "app.one") == .idle, "状态: 总开关关掉后一律显示空闲")
    check(changes > 0, "状态: 变化会通知刷新")
}

// 2. 手动调脚本的智能体：会话 id 对不上、漏发 Stop 都不会卡住。
do {
    let monitor = makeMonitor()
    monitor.handle(event: "UserPromptSubmit", sessionID: "a", from: 1, agent: "bot", lenient: true)
    monitor.handle(event: "UserPromptSubmit", sessionID: "b", from: 2, agent: "bot", lenient: true)
    monitor.handle(event: "Stop", sessionID: "zzz", from: 3, agent: "bot", lenient: true)
    check(monitor.state(for: "app.one") == .done, "宽松: Stop 带了对不上的会话 id，它名下工作中的会话一起算做完")
    monitor.acknowledge(bundleID: "app.one")
    monitor.handle(event: "UserPromptSubmit", sessionID: "c", from: 1, agent: "bot", lenient: true)
    monitor.handle(event: "Interrupt", sessionID: "other", from: 1, agent: "bot", lenient: true)
    check(monitor.state(for: "app.one") == .idle, "宽松: Interrupt 清掉它所有工作中的会话")
    monitor.handle(event: "UserPromptSubmit", sessionID: "d", from: 1, agent: "bot", lenient: true)
    monitor.dropStaleSessions(now: Date().addingTimeInterval(AgentMonitor.pairedStaleAfter - 5))
    check(monitor.state(for: "app.one") == .working, "宽松: 3 分钟以内还算工作中")
    monitor.dropStaleSessions(now: Date().addingTimeInterval(AgentMonitor.pairedStaleAfter + 5))
    check(monitor.state(for: "app.one") == .idle, "宽松: 3 分钟没有事件就当中断")
    monitor.handle(event: "UserPromptSubmit", sessionID: "x", from: 1, agent: "claude-code")
    monitor.dropStaleSessions(now: Date().addingTimeInterval(AgentMonitor.pairedStaleAfter + 5))
    check(monitor.state(for: "app.one") == .working, "严格: 用 hook 的助手 3 分钟不会被清掉")
    monitor.dropStaleSessions(now: Date().addingTimeInterval(AgentMonitor.staleAfter + 5))
    check(monitor.state(for: "app.one") == .idle, "严格: 10 分钟没有事件才清掉")
}

// 3. 打断检测：Claude Code 按 Esc 不发事件，但会往聊天记录追加一句。
do {
    let monitor = makeMonitor()
    let transcript = temp.appendingPathComponent("transcript.jsonl")
    try "{\"type\":\"user\",\"text\":\"[Request interrupted by user]\"}\n".write(to: transcript, atomically: true, encoding: .utf8)  // 旧的一句，不能算
    monitor.handle(event: "UserPromptSubmit", sessionID: "t1", from: 1, agent: "claude-code", transcriptPath: transcript.path)
    monitor.scanTranscriptsForInterrupts()
    check(monitor.state(for: "app.one") == .working, "打断: 开始之前记录里的旧打断标记不算")
    let handle = try FileHandle(forWritingTo: transcript)
    handle.seekToEndOfFile()
    handle.write(Data("{\"type\":\"assistant\",\"text\":\"working\"}\n".utf8))
    monitor.scanTranscriptsForInterrupts()
    check(monitor.state(for: "app.one") == .working, "打断: 记录有新内容但没有打断标记，还在工作中")
    handle.write(Data("{\"type\":\"user\",\"text\":\"[Request interrupted by user for tool use]\"}\n".utf8))
    try handle.close()
    monitor.scanTranscriptsForInterrupts()
    check(monitor.state(for: "app.one") == .idle, "打断: 开始之后出现打断标记，直接回到空闲（不显示做完）")
}

// 4. 认出是谁、最近活动落盘。
check(AgentMonitor.inferAgent(["transcript_path": "/Users/x/.claude/projects/p/a.jsonl"]) == "claude-code", "识别: .claude 下的记录是 Claude Code")
check(AgentMonitor.inferAgent(["transcript_path": "/Users/x/.codex/sessions/a.jsonl"]) == "codex", "识别: .codex 下的记录是 Codex")
check(AgentMonitor.inferAgent(["turn_id": "t"]) == "codex" && AgentMonitor.inferAgent(["session_id": "s"]) == nil, "识别: 带 turn_id 的是 Codex，什么都没有就不猜")
do {
    let monitor = makeMonitor()
    monitor.handle(event: "UserPromptSubmit", sessionID: "s1", from: 1, agent: "workbuddy", lenient: true)
    monitor.handle(event: "Stop", sessionID: "s1", from: 1, agent: "workbuddy", lenient: true)
    monitor.handle(event: "Stop", sessionID: "s9", from: 1)
    let activity = AgentRegistry.lastActivity()
    check(activity["workbuddy"]?.event == "Stop" && activity["workbuddy"]?.bundleID == "app.one", "活动: 每个智能体最近一次事件和所在 App 存进 activity.json")
    check(activity["-"] == nil && activity[""] == nil, "活动: 没带 agent id 的事件不进配对列表")
    try? fm.removeItem(at: AgentRegistry.logURL)
    check(AgentRegistry.lastActivity()["workbuddy"] != nil, "活动: 日志没了（比如被挪走）验证状态也不丢")
    let lost = makeMonitor { _ in nil }
    lost.handle(event: "Stop", sessionID: "s2", from: 1, agent: "lost", lenient: true)
    check(AgentRegistry.lastActivity()["lost"]?.bundleID == nil, "活动: 找不到所在 App 时 bundleID 为空，列表会提示")
}

// 4a. 进程链断了（XPC 服务的父进程是 launchd）时，按可执行文件所在的 .app 包认出宿主 App。
do {
    let running = [(id: "com.work.pc.doubao", path: "/Applications/DoubaoWork.app"), (id: "app.other", path: "/Applications/Other.app")]
    let xpc = "/Applications/DoubaoWork.app/Contents/Helpers/DoubaoWork Browser.app/Contents/XPCServices/AgentInfraService.xpc/Contents/MacOS/AgentInfraService"
    check(AgentMonitor.bundleID(containing: xpc, among: running) == "com.work.pc.doubao", "宿主: 嵌在主 App 里的 XPC 服务按路径认出主 App")
    check(AgentMonitor.bundleID(containing: "/Applications/Other.app/Contents/MacOS/Other", among: running) == "app.other", "宿主: 主程序按路径认出自己")
    check(AgentMonitor.bundleID(containing: "/bin/bash", among: running) == nil, "宿主: 不在任何 .app 里的进程认不出")
    check(AgentMonitor.bundleID(containing: "/Applications/NotRunning.app/Contents/MacOS/x", among: running) == nil, "宿主: App 没在运行就认不出（不凭路径瞎猜）")
    check(AgentMonitor.bundleID(containing: "/Applications/DoubaoWork.app.bak/Contents/MacOS/x", among: running) == nil, "宿主: 路径只是前缀相同不算")
}

// 4c. 豆包：不靠它上报，看它自己写的会话文件（assignment.md 开始、trajectory.jsonl 心跳和最终回复）。
do {
    let root = temp.appendingPathComponent("doubao-sessions", isDirectory: true)
    let system = root.appendingPathComponent("s1/agents/m_x/system", isDirectory: true)
    try fm.createDirectory(at: system, withIntermediateDirectories: true)
    let assignment = system.appendingPathComponent("assignment.md")
    let trajectory = system.appendingPathComponent("trajectory.jsonl")
    var clock = Date(timeIntervalSince1970: 1_800_000_000)
    func touch(_ url: URL, _ text: String? = nil, append: Bool = false) {
        if let text {
            if append, let handle = try? FileHandle(forWritingTo: url) { handle.seekToEndOfFile(); handle.write(Data(text.utf8)); try? handle.close() }
            else { try? text.write(to: url, atomically: true, encoding: .utf8) }
        }
        try? fm.setAttributes([.modificationDate: clock], ofItemAtPath: url.path)
    }
    let user = #"{"role":"user","content":"hi"}"# + "\n"
    let call = #"{"role":"assistant","content":"searching","tool_calls":[{"id":"1"}]}"# + "\n"
    let result = #"{"role":"tool","content":"result","tool_call_id":"1"}"# + "\n"
    let final = #"{"role":"assistant","content":"done"}"# + "\n"
    touch(assignment, "old"); touch(trajectory, user)       // 启动前就有的会话
    var events: [String] = []
    let watcher = DoubaoSessionWatcher()
    watcher.root = root
    watcher.agentID = { "doubao" }
    watcher.emit = { event, session, agent in events.append("\(event):\(session):\(agent)") }
    func tick(_ seconds: TimeInterval = 1) { clock = clock.addingTimeInterval(seconds); watcher.poll(now: clock) }
    tick()
    check(events.isEmpty, "豆包: 启动前就有的会话只记现状，不当成新事件")
    clock = clock.addingTimeInterval(1); touch(assignment, "new turn", append: true); tick(0)
    check(events == ["UserPromptSubmit:doubao-s1:doubao"], "豆包: assignment.md 追加一条需求 = 开始工作")
    events = []; clock = clock.addingTimeInterval(1); touch(trajectory, call, append: true); tick(0)
    check(events == ["PostToolUse:doubao-s1:doubao"], "豆包: 记录里有新的一步（工具调用）= 心跳")
    events = []; tick(5)
    check(events.isEmpty, "豆包: 没有新内容时不重复发心跳")
    clock = clock.addingTimeInterval(1); touch(trajectory, result, append: true); tick(0)
    events = []; clock = clock.addingTimeInterval(1); touch(trajectory, final, append: true); tick(0)
    check(events == ["Stop:doubao-s1:doubao"], "豆包: 最后一行是不带工具调用的 assistant 回复 = 做完")
    events = []; tick(120)
    check(events.isEmpty, "豆包: 做完之后不会再发 Stop")
    // 回复那一行迟迟不写：最后一行是工具结果，静默超过 60 秒就算做完。
    clock = clock.addingTimeInterval(1); touch(assignment, "turn 2", append: true); tick(0)
    clock = clock.addingTimeInterval(1); touch(trajectory, user + call + result, append: true); tick(0)
    events = []; tick(DoubaoSessionWatcher.quietDoneAfter - 5)
    check(events.isEmpty, "豆包: 60 秒内没有新内容还算在工作（模型可能在生成回复）")
    tick(10)
    check(events == ["Stop:doubao-s1:doubao"], "豆包: 回复行一直没写，静默超过 60 秒按做完处理")
    // 错过了 assignment.md：有新步骤也当作开始。
    events = []; clock = clock.addingTimeInterval(1); touch(trajectory, call, append: true); tick(0)
    check(events == ["UserPromptSubmit:doubao-s1:doubao"], "豆包: 没看到回合开头，有新步骤也当作开始工作")
    // 启动之后新出现的会话从头算。
    let system2 = root.appendingPathComponent("s2/agents/m_y/system", isDirectory: true)
    try fm.createDirectory(at: system2, withIntermediateDirectories: true)
    events = []; clock = clock.addingTimeInterval(1)
    touch(system2.appendingPathComponent("assignment.md"), "first"); touch(system2.appendingPathComponent("trajectory.jsonl"), user + final); tick(0)
    check(events == ["UserPromptSubmit:doubao-s2:doubao", "Stop:doubao-s2:doubao"], "豆包: 新会话一回合内开始又做完，开始和结束都有")
    // 没配对的不看。
    let unpaired = DoubaoSessionWatcher()
    unpaired.root = root
    unpaired.agentID = { nil }
    var unpairedEvents = 0
    unpaired.emit = { _, _, _ in unpairedEvents += 1 }
    unpaired.poll(now: clock); touch(trajectory, call, append: true); unpaired.poll(now: clock.addingTimeInterval(1))
    check(unpairedEvents == 0, "豆包: 没有配对（登记里没有 doubao）就不看它的文件")
    check(DoubaoSessionWatcher.lastRowIsFinalReply(trajectory) == false, "豆包: 最后一行是工具调用时不是最终回复")
    // 状态机接上：事件直接带所在 App，不用查进程。
    let monitor = makeMonitor { _ in nil }
    monitor.handle(event: "UserPromptSubmit", sessionID: "doubao-s1", from: 0, agent: "doubao", lenient: true, bundleID: DoubaoSessionWatcher.bundleID)
    check(monitor.state(for: DoubaoSessionWatcher.bundleID) == .working, "豆包: 文件监视器的事件直接落在豆包的图标上")
    monitor.handle(event: "Stop", sessionID: "doubao-s1", from: 0, agent: "doubao", lenient: true, bundleID: DoubaoSessionWatcher.bundleID)
    check(monitor.state(for: DoubaoSessionWatcher.bundleID) == .done, "豆包: 做完显示 OK")
}

// 4d. 向下兼容：App 内置监视的软件（豆包），智能体什么都不用配，只要验证和登记（passive）。
do {
    let agentsDir = AgentRegistry.directory
    let doubao = makeMonitor { _ in DoubaoSessionWatcher.bundleID }
    let plain = makeMonitor { _ in "com.apple.finder" }
    check(doubao.checkReply(agent: "dumb", pid: 1).contains("watch=builtin"), "兼容: 内置监视的软件，自检直接告诉智能体 watch=builtin（不用配置）")
    check(plain.checkReply(agent: "smart", pid: 1).contains("watch=none"), "兼容: 没有内置监视的软件，自检说 watch=none（要自己接入）")
    check(!makeMonitor { _ in nil }.checkReply(agent: "x", pid: 1).contains("watch="), "兼容: 找不到所在 App 时不报 watch")
    check(plain.registerReply(agent: "smart", fields: ["Smart", "passive", ""]).hasPrefix("FAIL"), "兼容: 没验证就登记 passive 被拒绝")
    _ = plain.verifyReply(agent: "smart", pid: 1)
    let refused = plain.registerReply(agent: "smart", fields: ["Smart", "passive", ""])
    check(refused.hasPrefix("FAIL") && refused.contains("passive") && !fm.fileExists(atPath: agentsDir.appendingPathComponent("smart.json").path), "兼容: 没有内置监视的软件不能用 passive 糊弄过去")
    check(doubao.verifyReply(agent: "dumb", pid: 1).hasPrefix("PASS"), "兼容: 内置监视的软件 --verify 照样通过")
    let accepted = doubao.registerReply(agent: "dumb", fields: ["豆包", "passive", "App 直接监视，没改任何配置"])
    check(accepted.hasPrefix("OK"), "兼容: 内置监视的软件登记 passive 成功，不用列文件")
    let entry = AgentRegistry.load().first { $0.id == "dumb" }
    check(entry?.method == "passive" && entry?.files == [] && entry?.host == DoubaoSessionWatcher.bundleID, "兼容: 登记里记下 passive 和所在 App")
    check(DoubaoSessionWatcher().agentID() == "dumb", "兼容: 豆包的文件监视按登记里的所在 App 启用，不要求 id 叫什么")
    try? fm.removeItem(at: agentsDir.appendingPathComponent("dumb.json"))
    check(DoubaoSessionWatcher().agentID() == nil, "兼容: 取消配对（删登记）后监视就停了")
}

// 4b. 升级时从日志回填，已配对的不退回“待验证”。
do {
    try? fm.removeItem(at: AgentRegistry.activityURL)
    let log1 = ["2026-10-03T19:23:08Z UserPromptSubmit agent=antigravity session=t pid=1 app=com.google.antigravity",
                "2026-10-03T19:27:23Z Stop agent=antigravity session=t pid=1 app=com.google.antigravity",
                "2026-10-03T19:30:00Z Stop agent=- session=x pid=1 app=com.apple.finder"].joined(separator: "\n")
    try log1.write(to: AgentRegistry.logURL, atomically: true, encoding: .utf8)
    AgentRegistry.backfillActivityFromLog()
    let activity = AgentRegistry.lastActivity()
    check(activity["antigravity"]?.event == "Stop" && activity["antigravity"]?.bundleID == "com.google.antigravity" && activity.count == 1,
          "回填: 从日志取每个智能体最近一次事件，没带 id 的不算")
    try "2026-10-03T20:00:00Z Stop agent=other session=x pid=1 app=-".write(to: AgentRegistry.logURL, atomically: true, encoding: .utf8)
    AgentRegistry.backfillActivityFromLog()
    check(AgentRegistry.lastActivity()["other"] == nil, "回填: 已经有 activity.json 的不再覆盖")
}

// 4c. 重启后第一条事件不能把别的智能体的记录覆盖掉。
do {
    try? fm.removeItem(at: AgentRegistry.activityURL)
    let first = makeMonitor()
    first.handle(event: "Stop", sessionID: "s", from: 1, agent: "alpha", lenient: true)
    let restarted = makeMonitor { _ in "app.two" }
    restarted.handle(event: "Stop", sessionID: "s", from: 1, agent: "beta", lenient: true)
    let activity = AgentRegistry.lastActivity()
    check(activity["alpha"] != nil && activity["beta"]?.bundleID == "app.two", "活动: 重启后第一条事件不会覆盖别的智能体的记录")
}

// 5. 登记文件。
let agentsDir = AgentRegistry.directory
try fm.createDirectory(at: agentsDir, withIntermediateDirectories: true)
try #"{"id":"workbuddy","name":"WorkBuddy","method":"hook","files":["/tmp/a.json"],"notes":"ok"}"#
    .write(to: agentsDir.appendingPathComponent("workbuddy.json"), atomically: true, encoding: .utf8)
try #"{"id":"other","name":"Mismatch"}"#.write(to: agentsDir.appendingPathComponent("wrongname.json"), atomically: true, encoding: .utf8)
try #"{"id":"../evil","name":"Evil"}"#.write(to: agentsDir.appendingPathComponent("evil.json"), atomically: true, encoding: .utf8)
try "{ broken".write(to: agentsDir.appendingPathComponent("broken.json"), atomically: true, encoding: .utf8)
try #"{"id":"nameless"}"#.write(to: agentsDir.appendingPathComponent("nameless.json"), atomically: true, encoding: .utf8)
let registered = AgentRegistry.load()
check(registered.map(\.id).sorted() == ["nameless", "workbuddy"], "登记: 只读到合法的两份（坏文件、id 和文件名不一致、路径穿越都被跳过）")
check(registered.first { $0.id == "workbuddy" }?.files == ["/tmp/a.json"], "登记: files 读出来了")
check(registered.first { $0.id == "nameless" }?.name == "nameless", "登记: 没有 name 时用 id")
check(AgentRegistry.isValidID("work-buddy2") && !AgentRegistry.isValidID("Work") && !AgentRegistry.isValidID("a/b") && !AgentRegistry.isValidID(""), "登记: id 的合法性判断")

// 6. 早期自动连接的 Claude Code / Codex：补登记，不动它们的配置。
let script = AgentHookInstaller.scriptURL.path
let claudeConfig = temp.appendingPathComponent(".claude/settings.json")
try fm.createDirectory(at: claudeConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
let claudeText = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"\"\#(script)\" Stop"}]}]}}"#
try claudeText.write(to: claudeConfig, atomically: true, encoding: .utf8)
let codexConfig = temp.appendingPathComponent(".codex/hooks.json")
try fm.createDirectory(at: codexConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
try #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo someone-else"}]}]}}"#.write(to: codexConfig, atomically: true, encoding: .utf8)
let created = AgentRegistry.migrateLegacyHooks()
check(created == ["claude-code"], "迁移: 只给配置里真有我们 hook 的 Claude Code 补登记，Codex（没有我们的 hook）不补")
check(AgentRegistry.load().contains { $0.id == "claude-code" && $0.name == "Claude Code" }, "迁移: 补的登记在配对列表里读得到")
check((try String(contentsOf: claudeConfig, encoding: .utf8)) == claudeText, "迁移: 只读配置，一个字不改")
check(AgentRegistry.migrateLegacyHooks().isEmpty, "迁移: 已有登记的不重复建")

// 7. 提示词和脚本。
try AgentHookInstaller.refreshScript()
let prompt = AgentPairingPrompt.text()
check(prompt.contains(script), "提示词: 含脚本的真实路径")
check(!prompt.contains("\"S\""), "提示词: 命令里直接是真实路径，不留要智能体自己替换的占位符")
check(prompt.contains("/dev/null") && prompt.contains("UserPromptSubmit") && prompt.contains("Interrupt") && prompt.contains("Stop"), "提示词: 含用法和事件")
check(prompt.contains("--check") && prompt.contains("--verify") && prompt.contains("--register") && prompt.contains("NOT_FOUND"), "提示词: 自检、验证、登记三个命令和 NOT_FOUND 都有")
check(!prompt.contains("会话id") && !prompt.contains(agentsDir.path), "提示词: 不要智能体管会话 id，也不让它手写登记文件")
check(prompt.contains("伪装") && prompt.contains("卡住就停") && prompt.contains("汇报"), "提示词: 红线（不伪造、卡住就停）和汇报模板")
check(prompt.contains("watch=builtin") && prompt.contains("watch=none") && prompt.contains("passive"), "提示词: 按 watch= 分流，内置监视的软件跳过接入、用 passive 登记")
check(prompt.contains("reason=permission_denied") && prompt.contains("正式权限审批"), "提示词: socket 权限拒绝必须停下并通过正式审批，不关闭沙箱")
check(prompt.contains("不代表 hook 已获信任或自动执行"), "提示词: 不把演示说成自动 hook 已启用")
let scriptText = try String(contentsOfFile: script, encoding: .utf8)
check(scriptText.contains("[ -t 0 ]") && scriptText.contains("$EVENT") && scriptText.contains("manual"), "脚本: 终端上不卡 stdin、支持 agent id、手动调用带 manual 标记")
let mode = (try? fm.attributesOfItem(atPath: script))?[.posixPermissions] as? Int
check(fm.fileExists(atPath: script) && mode == 0o755, "脚本: 已写入且可执行")

// 7b. 自检：真的启动监听、真的跑脚本 --check。
do {
    let monitor = makeMonitor { _ in "com.apple.finder" }
    monitor.start()
    defer { monitor.stop() }
    func runCheck(_ args: [String], denyNetwork: Bool = false) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: denyNetwork ? "/usr/bin/sandbox-exec" : "/bin/bash")
        process.arguments = (denyNetwork ? ["-p", "(version 1) (allow default) (deny network*)", "/bin/bash"] : []) + [script] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardInput = FileHandle.nullDevice
        process.environment = ProcessInfo.processInfo.environment.merging(["DTB_SOCKET": AgentMonitor.socketURL.path]) { $1 }
        try? process.run()
        process.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
    Thread.sleep(forTimeInterval: 0.3)
    let output = runCheck(["--check", "bot"])
    check(output.hasPrefix("OK") && output.contains("host_app=com.apple.finder") && output.contains("agent=bot registered=no"), "自检: App 在运行时回复 OK、所在 App、是否登记")
    // Run the real generated script against a real listener with network access denied.
    for mode in ["--check", "--verify", "--register"] {
        let denied = runCheck([mode, "sandbox-bot"], denyNetwork: true)
        // Apple's nc may fail silently even with -v. Never infer errno from exit 1.
        check(denied.hasPrefix("NOT_REACHABLE") && denied.contains("nc_exit=1") && denied.contains("socket=\(AgentMonitor.socketURL.path)") && denied.contains("normal permission approval"), "诊断: \(mode) 保留沙箱连接失败的退出码、socket 和正式审批提示")
        check(denied.contains("reason=permission_denied") || (denied.contains("reason=connection_failed") && denied.contains("cause cannot be determined")), "诊断: \(mode) 没有底层错误信息时不猜测原因")
    }
    check(runCheck(["Stop", "sandbox-bot"], denyNetwork: true).isEmpty, "诊断: 沙箱拒绝时普通事件仍然静默")
    try #"{"id":"bot","name":"Bot"}"#.write(to: agentsDir.appendingPathComponent("bot.json"), atomically: true, encoding: .utf8)
    check(runCheck(["--check", "bot"]).contains("registered=yes"), "自检: 登记后显示 registered=yes")
    check(!runCheck(["--check"]).contains("agent="), "自检: 不带 id 也能用")
    let lost = makeMonitor { _ in nil }
    check(lost.checkReply(agent: "x", pid: 1).contains("host_app=NOT_FOUND"), "自检: 找不到所在 App 时明确说 NOT_FOUND")
    // 验证和登记：由 App 判定、由 App 写文件。
    let early = runCheck(["--register", "newbie", "New Bie", "instructions", "note"])
    check(early.hasPrefix("FAIL") && early.contains("--verify") && !fm.fileExists(atPath: agentsDir.appendingPathComponent("newbie.json").path), "登记: 没通过验证就登记会被拒绝，也不写文件")
    check(runCheck(["--verify"]).hasPrefix("FAIL"), "验证: 不带 id 直接 FAIL")
    let verify = runCheck(["--verify", "newbie"])
    check(verify.hasPrefix("PASS") && verify.contains("host_app=com.apple.finder"), "验证: 找到所在 App 时 PASS，并报出所在 App")
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    check(AgentRegistry.lastActivity()["newbie"] == nil, "验证: 动画演示不会伪造 Stop 或任务活动")
    monitor.handle(event: "UserPromptSubmit", sessionID: "real-task", from: 1, agent: "newbie")
    let taskActivity = AgentRegistry.lastActivity()["newbie"]
    _ = runCheck(["--verify", "newbie"])
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    check(AgentRegistry.lastActivity()["newbie"] == taskActivity, "验证: 重复演示不会覆盖已有真实事件")
    check(runCheck(["--register", "newbie", "New Bie", "hook-ish", "note"]).hasPrefix("FAIL"), "登记: 方法不是 hook 或 instructions 会被拒绝")
    check(runCheck(["--register", "other", "Other", "hook", "note"]).hasPrefix("FAIL"), "登记: 登记的 id 必须是刚通过验证的那个")
    let registered = runCheck(["--register", "newbie", "New Bie", "Instructions", "加了一条规则", "/Users/x/AGENTS.md", "relative/path", "/Users/x/rules.md"])
    check(registered.hasPrefix("OK"), "登记: 验证通过后登记成功")
    let entry = AgentRegistry.load().first { $0.id == "newbie" }
    check(entry?.name == "New Bie" && entry?.method == "instructions" && entry?.notes == "加了一条规则", "登记: App 写出的文件字段正确（方法统一小写）")
    check(entry?.files == ["/Users/x/AGENTS.md", "/Users/x/rules.md"], "登记: 只收绝对路径")
    check(entry?.host == "com.apple.finder", "登记: 没有任务事件时仍保存验证过的宿主，供试一下使用")
    check(AgentRegistry.load().contains { $0.id == "newbie" } && runCheck(["--check", "newbie"]).contains("registered=yes"), "登记: 自检能看到已登记")
    // 过期的验证不能用来登记。
    check(monitor.registerReply(agent: "newbie", fields: ["N", "hook", ""], now: Date().addingTimeInterval(AgentMonitor.verifiedValidFor + 1)).hasPrefix("FAIL"), "登记: 验证超过一小时就要重新验证")
    monitor.stop()
    // 找不到所在 App：验证 FAIL、什么也不记，之后也登记不了。
    let blind = makeMonitor { _ in nil }
    blind.start()
    Thread.sleep(forTimeInterval: 0.3)
    let blindVerify = runCheck(["--verify", "ghost"])
    check(blindVerify.hasPrefix("FAIL") && blindVerify.contains("NOT_FOUND") && blindVerify.contains("伪装") == (L10n.isChinese), "验证: 找不到所在 App 时 FAIL，并明确说不要伪装")
    check(runCheck(["--register", "ghost", "Ghost", "hook", "n"]).hasPrefix("FAIL") && !fm.fileExists(atPath: agentsDir.appendingPathComponent("ghost.json").path), "登记: 找不到所在 App 的智能体登记不了")
    blind.stop()
    Thread.sleep(forTimeInterval: 0.2)
    check(runCheck(["--check", "bot"]).hasPrefix("NOT_RUNNING"), "自检: App 没运行时说 NOT_RUNNING")
    check(runCheck(["Stop", "bot", "s1"]).isEmpty, "脚本: 发事件永远静默、不输出")

    // A stale socket and a peer which accepts but never replies are different failures.
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    withUnsafeMutablePointer(to: &address.sun_path) { tuple in
        tuple.withMemoryRebound(to: CChar.self, capacity: capacity) { _ = strlcpy($0, AgentMonitor.socketURL.path, capacity) }
    }
    let bound = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    check(fd >= 0 && bound == 0, "诊断: 创建隔离的测试 socket")
    if fd >= 0 && bound == 0 {
        let refused = runCheck(["--check", "bot"])
        check(refused.hasPrefix("NOT_REACHABLE") && refused.contains("nc_exit=1") && !refused.contains("reason=permission_denied"), "诊断: socket 存在但未监听时报告失败，不误诊为权限拒绝")
        if listen(fd, 1) == 0 {
            DispatchQueue.global().async {
                let client = accept(fd, nil, nil)
                if client >= 0 {
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    _ = read(client, &buffer, buffer.count)
                    close(client)
                }
            }
            let empty = runCheck(["--check", "bot"])
            check(empty.hasPrefix("NOT_REACHABLE reason=no_response nc_exit=0"), "诊断: 连接成功但没有回复不能被当成自检成功")
        } else {
            check(false, "诊断: 测试 socket 监听成功")
        }
    }
    if fd >= 0 { close(fd) }
    unlink(AgentMonitor.socketURL.path)
}
let trial = makeMonitor()
trial.simulate(bundleID: "app.trial")
check(trial.state(for: "app.trial") == .working, "试一下: 立刻显示工作中")

// 顶层的 defer 在 exit 时不会执行，临时目录要在这里显式清掉。
try? fm.removeItem(at: support)
try? fm.removeItem(at: temp)
print(failures == 0 ? "RESULT failures=0" : "RESULT failures=\(failures)")
exit(failures == 0 ? 0 : 1)

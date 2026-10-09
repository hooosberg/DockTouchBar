import AppKit
import Darwin

/// AI 编程助手（Claude Code 等）在某个 App 里的工作状态，显示在对应 App 的图标上。
enum AgentState: Equatable {
    case idle
    case working
    /// 刚做完、用户还没点过。点一下对应图标就回到 idle。
    case done
}

/// 接收各个助手的 hook 事件（本地 Unix socket），按“所在的 App”汇总成状态。
///
/// 事件来自转发脚本 `agent-hook.sh`（各智能体按“配对智能体”提示词，用自己的 hook 或指令调用它）：每个事件一行
/// `事件名[|智能体id] \t 脚本的父进程号 \t 智能体传来的 JSON（可为空）`。父进程号一路往上找，找到第一个有 Dock 图标的 App，
/// 就是这次会话所在的 App（终端、VS Code、Claude 桌面版……）。
final class AgentMonitor {
    static let shared = AgentMonitor()

    /// 支持目录（socket、hook 脚本）。可以替换，测试时用。
    static var supportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/\(AppInfo.fileName)", isDirectory: true)
    static var socketURL: URL { supportDirectory.appendingPathComponent("agent.sock") }

    /// 从 hook 进程号找到会话所在的 App。可以替换，测试时用。
    var ownerResolver: (pid_t) -> String? = AgentMonitor.owningApp(of:)
    /// 状态变了（主线程回调）。
    var onChange: (() -> Void)?
    /// 设置里的总开关；关掉后所有图标都按 idle 显示，事件仍然记录。
    var isEnabled = true {
        didSet { if isEnabled != oldValue { onChange?() } }
    }

    private struct Session {
        var state: AgentState
        var lastEvent: Date
        var agent: String?
        /// 靠自觉手动调脚本的智能体（会话 id 是它自己给的）：不一定每次都发对 Stop，所以 Stop/Interrupt 对它宽松收尾、超时也更短。
        /// 用自己 hook 的（会话 id 来自 hook 的 JSON）是严格的：只处理自己的会话，允许多个会话同时在跑。
        var lenient = false
        /// 会话的聊天记录文件和开始时的大小。用户按 Esc 打断时 Claude Code 不发任何事件，但会往记录里追加
        /// “[Request interrupted by user]”，从开始时的位置往后找这一句，找到就当被打断。
        var transcript: (path: String, offset: UInt64)?
    }

    /// App 的 bundleID → 会话 ID → 会话。只在主线程读写。
    private var sessions: [String: [String: Session]] = [:]
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSource?
    private var staleTimer: Timer?
    private var interruptTimer: Timer?
    private var fileTimer: Timer?
    /// 看豆包自己写的会话文件（它不一定肯照提示词上报）。
    lazy var doubaoWatcher: DoubaoSessionWatcher = {
        let watcher = DoubaoSessionWatcher()
        watcher.emit = { [weak self] event, session, agent in
            self?.handle(event: event, sessionID: session, from: 0, agent: agent, lenient: true,
                         detail: "src=files", bundleID: DoubaoSessionWatcher.bundleID)
        }
        return watcher
    }()
    /// Stop 不会在用户按 Esc 打断时触发；工作中的会话超过这么久没有任何事件，就当没发生过，免得动画一直转。
    /// 用 hook 的有心跳，给 10 分钟；手动调脚本的常常漏发，只给 3 分钟（提示词要求它每步发一次 PostToolUse 续期）。
    static let staleAfter: TimeInterval = 600
    static let pairedStaleAfter: TimeInterval = 180

    func state(for bundleID: String) -> AgentState {
        guard isEnabled, let group = sessions[bundleID], !group.isEmpty else { return .idle }
        if group.values.contains(where: { $0.state == .working }) { return .working }
        return .done
    }

    /// 清掉所有图标上的动画状态（动画卡住时用，设置里有按钮）。
    func resetAll() {
        guard !sessions.isEmpty else { return }
        sessions.removeAll()
        onChange?()
    }

    /// 用户点了图标：把这个 App 里“做完了”的会话清掉。
    func acknowledge(bundleID: String) {
        guard var group = sessions[bundleID] else { return }
        let before = group.count
        group = group.filter { $0.value.state != .done }
        sessions[bundleID] = group.isEmpty ? nil : group
        if group.count != before { onChange?() }
    }

    // MARK: - 服务

    func start() {
        guard listenFD < 0 else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])
        let path = Self.socketURL.path
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else { close(fd); return }
        withUnsafeMutablePointer(to: &address.sun_path) { tuple in
            tuple.withMemoryRebound(to: CChar.self, capacity: capacity) { _ = strlcpy($0, path, capacity) }
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, listen(fd, 16) == 0 else { close(fd); return }
        chmod(path, 0o600)
        listenFD = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in self?.acceptConnection(on: fd) }
        source.setCancelHandler { close(fd) }
        source.resume()
        acceptSource = source as? DispatchSource

        staleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.dropStaleSessions() }
        interruptTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.scanTranscriptsForInterrupts() }
        fileTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.doubaoWatcher.poll() }
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        listenFD = -1
        staleTimer?.invalidate()
        staleTimer = nil
        interruptTimer?.invalidate()
        interruptTimer = nil
        fileTimer?.invalidate()
        fileTimer = nil
        unlink(Self.socketURL.path)
    }

    private func acceptConnection(on fd: Int32) {
        let client = accept(fd, nil, nil)
        guard client >= 0 else { return }
        // hook 的 nc 发完就关；读到结束为止，最多等 1 秒，防止异常连接一直占着。
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < 1 << 20 {
            let count = read(client, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
            // 一条消息就是一行，读到换行就够了，不用等对方关连接（自检要在这之后回话）。
            if data.last == UInt8(ascii: "\n") { break }
        }
        guard let text = String(data: data, encoding: .utf8) else { close(client); return }
        var reply = ""
        defer {
            if !reply.isEmpty { _ = reply.withCString { write(client, $0, strlen($0)) } }
            close(client)
        }
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count >= 2, let ppid = pid_t(parts[1]) else { continue }
            // 事件字段是 “事件名” 或 “事件名|智能体 id”（配对智能体的脚本会带上自己的 id，只用于日志和配对列表）。
            let eventParts = parts[0].split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            let event = String(eventParts[0])
            let agent = eventParts.count == 2 ? String(eventParts[1]) : nil
            // 自检：`agent-hook.sh --check <id>` 发来 Check，当场回一段说明（App 在运行、能不能找到所在 App、登记了没有），不进状态机。
            if event == "Check" {
                reply += checkReply(agent: agent, pid: ppid)
                continue
            }
            // 验证、登记：由 App 来判定通过与否、由 App 来写登记文件，不让智能体自己判断、自己手写。
            if event == "Verify" {
                reply += verifyReply(agent: agent, pid: ppid)
                continue
            }
            if event == "Register" {
                let fields = parts.count == 3 ? parts[2].split(separator: "\t", omittingEmptySubsequences: false).map(String.init) : []
                reply += registerReply(agent: agent, fields: fields)
                continue
            }
            var json: [String: Any]?
            if parts.count == 3 { json = (try? JSONSerialization.jsonObject(with: Data(parts[2].utf8))) as? [String: Any] }
            let sessionID = json?["session_id"] as? String
            let transcript = json?["transcript_path"] as? String
            // 诊断用：完整会话 id、轮次 id、工具名（Codex 的会话 id 是按时间生成的，前 8 位相同不代表同一个会话）。
            let detail = ["turn": json?["turn_id"] as? String, "tool": json?["tool_name"] as? String,
                          "sid": sessionID, "src": (transcript as NSString?)?.lastPathComponent]
                .compactMap { key, value in value.map { "\(key)=\($0.prefix(40))" } }.sorted().joined(separator: " ")
            // 手动调脚本时会话 id 是智能体自己给的（脚本在 JSON 里加了 manual 标记），或者干脆没有会话 id。
            let lenient = (json?["manual"] as? Bool) == true || (sessionID == nil && agent != nil)
            // 旧的、不带 id 的 hook（早期自动连接的 Claude Code、Codex）：从记录文件的位置认出是谁，配对列表才对得上。
            let who = agent ?? Self.inferAgent(json)
            DispatchQueue.main.async { [weak self] in
                // 没带会话 id 时：手动调用的智能体用自己的 id 当会话（它每次调脚本的进程号都不同，用进程号永远对不上开始和结束）；其余用进程号。
                let session = sessionID ?? agent.map { "agent-\($0)" } ?? "pid-\(ppid)"
                self?.handle(event: event, sessionID: session, from: ppid, agent: who, lenient: lenient, transcriptPath: transcript, detail: detail)
            }
        }
    }

    /// 自检的回复：给智能体看的几行字，告诉它链路通不通、有没有找到它所在的 App。可以在任何线程调用。
    func checkReply(agent: String?, pid: pid_t) -> String {
        let owner = ownerResolver(pid)
        var lines = [L10n.isChinese ? "OK \(AppInfo.name) 正在运行，转发脚本能连上它。" : "OK \(AppInfo.name) is running and the script can reach it."]
        if let owner {
            let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: owner)
                .map { FileManager.default.displayName(atPath: $0.path) } ?? owner
            lines.append("host_app=\(owner) (\(name))")
        } else {
            lines.append(L10n.isChinese
                ? "host_app=NOT_FOUND 从这条命令的进程往上找不到有 Dock 图标的 App，所以这样发的事件不会让任何图标出现动画。请停下来告诉用户，不要发测试事件、不要登记，也不要伪装 App 绕过去。"
                : "host_app=NOT_FOUND no app with a Dock icon was found above this command's process, so events sent this way won't animate any icon. Stop and tell the user; don't send test events, don't register, and don't fake an app to get around it.")
        }
        if let owner {
            // 向下兼容：这个软件 App 自己就能看出它在不在工作，智能体什么都不用配。
            if Self.builtinWatchedApps[owner] != nil {
                lines.append(L10n.isChinese
                    ? "watch=builtin 这个软件的工作状态由 \(AppInfo.name) 直接监视，不需要你修改任何配置、不需要写规则。跳过接入步骤，直接 --verify，通过后 --register（方法写 passive，不用列文件）。"
                    : "watch=builtin this app's working state is watched directly by \(AppInfo.name); you don't need to change any config or write any rule. Skip the connect step: run --verify, then --register after PASS (method passive, no files to list).")
            } else {
                lines.append(L10n.isChinese
                    ? "watch=none 需要你自己接入：按提示词选方案 A（hook）或方案 B（长期指令）。"
                    : "watch=none you have to connect yourself: pick Option A (hooks) or Option B (long-term instructions) as the prompt says.")
            }
        }
        if let agent {
            let registered = AgentRegistry.load().contains { $0.id == agent }
            lines.append("agent=\(agent) registered=\(registered ? "yes" : "no")")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// App 自己能看出工作状态的软件（bundleID → 名字）：不需要智能体配合，配对时只要验证和登记。目前是豆包，见 `DoubaoSessionWatcher`。
    static let builtinWatchedApps = [DoubaoSessionWatcher.bundleID: "Doubao"]

    /// 通过 `--verify` 的智能体 id → 所在 App 和时间。登记（`--register`）只认这里有、且一小时以内的。可以在任何线程访问。
    private var verified: [String: (bundleID: String, date: Date)] = [:]
    private let verifiedLock = NSLock()
    static let verifiedValidFor: TimeInterval = 3600

    /// 验证：App 自己判断找没找到智能体所在的 App。找到了就在那个图标上放一遍“工作中 → OK”，并回 PASS；没找到回 FAIL，什么都不记。
    /// 智能体只需要把这一行原样回报，不用自己发测试事件、读日志、判断 app= 对不对。
    func verifyReply(agent: String?, pid: pid_t) -> String {
        guard let agent, AgentRegistry.isValidID(agent) else {
            return L10n.isChinese
                ? "FAIL 没带合法的 id（只能用小写字母、数字、短横线）。用法：--verify <你的id>。停下来告诉用户。\n"
                : "FAIL missing or invalid id (lowercase letters, digits, dashes only). Usage: --verify <your-id>. Stop and tell the user.\n"
        }
        guard let owner = ownerResolver(pid) else {
            return L10n.isChinese
                ? "FAIL host_app=NOT_FOUND 找不到你所在的 App，验证没通过，也没有记下任何东西。立刻停下来，把这行原样告诉用户，不要发测试事件、不要登记、不要伪装 App 或冒充 bundle id 绕过去。\n"
                : "FAIL host_app=NOT_FOUND your app wasn't found, so verification failed and nothing was recorded. Stop right now and give the user this line as is; don't send test events, don't register, and don't fake an app or bundle id to get around it.\n"
        }
        verifiedLock.lock()
        verified[agent] = (owner, Date())
        verifiedLock.unlock()
        DispatchQueue.main.async { [weak self] in
            // Verification is a connection check and a demo, not a lifecycle event.
            // In particular, it cannot prove that the agent's hooks are trusted or running.
            self?.simulate(bundleID: owner)
        }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: owner)
            .map { FileManager.default.displayName(atPath: $0.path) } ?? owner
        return L10n.isChinese
            ? "PASS host_app=\(owner) (\(name))。用户的 Touch Bar 上，这个 App 的图标现在应该在显示字符雨，几秒后显示 OK。仅验证连接和演示，不代表 hook 已获信任或自动运行。下一步：用 --register 登记。\n"
            : "PASS host_app=\(owner) (\(name)). On the user's Touch Bar the icon of this app should now show the falling digits, then OK. This verifies the connection and demo only, not hook trust or automatic delivery. Next step: register with --register.\n"
    }

    /// 登记：只有这个 id 刚通过 `--verify` 才收。字段：显示名、方法（hook 或 instructions）、一句话说明、改过的文件（绝对路径，可以没有）。
    func registerReply(agent: String?, fields: [String], now: Date = Date()) -> String {
        func fail(_ zh: String, _ en: String) -> String { "FAIL " + (L10n.isChinese ? zh : en) + "\n" }
        guard let agent, AgentRegistry.isValidID(agent) else {
            return fail("没带合法的 id。用法：--register <id> \"<显示名>\" <hook|instructions> \"<一句话说明>\" <文件绝对路径…>。停下来告诉用户。",
                        "missing or invalid id. Usage: --register <id> \"<display name>\" <hook|instructions> \"<one-line note>\" <absolute file paths…>. Stop and tell the user.")
        }
        verifiedLock.lock()
        let passed = verified[agent]
        verifiedLock.unlock()
        guard let passed, now.timeIntervalSince(passed.date) < Self.verifiedValidFor else {
            return fail("这个 id 还没有通过 --verify（或已超过一小时）。先运行 --verify \(agent)，看到 PASS 再来登记；如果得到的是 FAIL，就停下来告诉用户。",
                        "this id hasn't passed --verify (or it was over an hour ago). Run --verify \(agent) first and register only after PASS; if you got FAIL, stop and tell the user.")
        }
        let name = fields.first.map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : String($0.prefix(60)) } ?? agent
        let method = fields.count > 1 ? fields[1].trimmingCharacters(in: .whitespaces).lowercased() : ""
        guard ["hook", "instructions", "passive"].contains(method) else {
            return fail("方法只能是 hook（用了软件自己的 hook）、instructions（写进了长期指令），或 passive（--check 说 watch=builtin，没改任何配置）。",
                        "method must be hook (you used the app's own hooks), instructions (you wrote it into long-term instructions), or passive (--check said watch=builtin and you changed no config).")
        }
        guard method != "passive" || Self.builtinWatchedApps[passed.bundleID] != nil else {
            return fail("这个软件没有内置监视，不能用 passive。请按提示词选方案 A 或 B 接入，再用 hook 或 instructions 登记。",
                        "this app has no built-in watcher, so passive isn't allowed. Connect with Option A or B as the prompt says and register as hook or instructions.")
        }
        let notes = fields.count > 2 ? String(fields[2].trimmingCharacters(in: .whitespaces).prefix(300)) : ""
        let files = fields.dropFirst(3).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("/") }.prefix(20).map { String($0.prefix(300)) }
        let json: [String: Any] = ["id": agent, "name": name, "method": method, "files": Array(files), "notes": notes, "host": passed.bundleID]
        do {
            try FileManager.default.createDirectory(at: AgentRegistry.directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: json)
            try data.write(to: AgentRegistry.directory.appendingPathComponent("\(agent).json"), options: .atomic)
        } catch {
            return fail("写登记文件失败：\(error.localizedDescription)。停下来告诉用户。", "couldn't write the registration file: \(error.localizedDescription). Stop and tell the user.")
        }
        return L10n.isChinese
            ? "OK 已登记「\(name)」（\(method)，改过的文件 \(files.count) 个）。现在可以按汇报模板告诉用户结果了。\n"
            : "OK registered \"\(name)\" (\(method), \(files.count) changed file(s)). You can now report to the user with the report template.\n"
    }

    /// 配对列表里的“试一下”：在这个 App 的图标上放 4 秒“工作中”，再显示“做完”，3 秒后自己收掉。不用等智能体跑任务就能看到动画。
    func simulate(bundleID: String) {
        let id = "demo-\(UUID().uuidString.prefix(6))"
        var group = sessions[bundleID] ?? [:]
        group[id] = Session(state: .working, lastEvent: Date(), agent: "demo", lenient: true)
        sessions[bundleID] = group
        onChange?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, var group = self.sessions[bundleID], group[id] != nil else { return }
            group[id] = Session(state: .done, lastEvent: Date(), agent: "demo", lenient: true)
            self.sessions[bundleID] = group
            self.onChange?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, var group = self.sessions[bundleID], group[id] != nil else { return }
                group[id] = nil
                self.sessions[bundleID] = group.isEmpty ? nil : group
                self.onChange?()
            }
        }
    }

    /// 从 hook 传来的聊天记录路径认出是哪个助手（Claude Code 在 ~/.claude/，Codex 在 ~/.codex/）。
    static func inferAgent(_ json: [String: Any]?) -> String? {
        if let path = json?["transcript_path"] as? String {
            if path.contains("/.claude/") { return "claude-code" }
            if path.contains("/.codex/") { return "codex" }
        }
        return json?["turn_id"] != nil ? "codex" : nil
    }

    // MARK: - 状态机

    func handle(event: String, sessionID: String, from pid: pid_t, agent: String? = nil,
                lenient: Bool = false, transcriptPath: String? = nil, detail: String = "", bundleID knownApp: String? = nil) {
        // 文件监视器（豆包）没有进程可查，直接告诉它所在的 App。
        let owner = knownApp ?? ownerResolver(pid)
        record("\(event) agent=\(agent ?? "-") session=\(sessionID.prefix(8)) pid=\(pid) app=\(owner ?? "-")" + (detail.isEmpty ? "" : " " + detail))
        if let agent { recordActivity(agent: agent, event: event, bundleID: owner) }
        guard let bundleID = owner else { return }
        let before = state(for: bundleID)
        var group = sessions[bundleID] ?? [:]
        let now = Date()
        func newSession(_ state: AgentState) -> Session {
            var session = Session(state: state, lastEvent: now, agent: agent, lenient: lenient)
            if let transcriptPath {
                let size = (try? FileManager.default.attributesOfItem(atPath: transcriptPath))?[.size] as? UInt64
                session.transcript = (transcriptPath, size ?? 0)
            }
            return session
        }
        switch event {
        case "UserPromptSubmit":
            group[sessionID] = newSession(.working)
        case "PostToolUse", "Notification":
            // 心跳，只给已经存在的会话续期。不能凭心跳新建会话：用户点掉“做完了”之后，
            // 迟到的心跳（后台任务、子任务收尾）会造出一个永远等不到 Stop 的“工作中”，动画就卡住了。开始一定有 UserPromptSubmit。
            if var session = group[sessionID] {
                session.lastEvent = now
                group[sessionID] = session
            }
        case "Stop":
            var done = newSession(.done)
            done.transcript = nil
            group[sessionID] = done
            // 手动调脚本的智能体，Stop 没带对会话 id 也没关系：它这个 id 下还在“工作中”的，一起算做完。
            if lenient, let agent {
                for (id, session) in group where session.agent == agent && session.state == .working {
                    group[id] = Session(state: .done, lastEvent: now, agent: agent, lenient: true)
                }
            }
        case "SessionEnd", "Interrupt":
            // 会话结束，或用户按 Esc 打断：直接回到空闲，不显示“做完”。
            group[sessionID] = nil
            if lenient, let agent {
                for (id, session) in group where session.agent == agent && session.state == .working { group[id] = nil }
            }
        default:
            return
        }
        sessions[bundleID] = group.isEmpty ? nil : group
        if state(for: bundleID) != before { onChange?() }
    }

    // MARK: - 打断检测

    /// 工作中的会话有聊天记录文件时，每 2 秒从上次读到的位置往后找 “[Request interrupted by user”：
    /// Claude Code 在用户按 Esc 打断时不触发任何 hook，但会把这句追加进记录。找到就当被打断（不显示“做完”）。
    func scanTranscriptsForInterrupts() {
        var changed = false
        for (bundleID, group) in sessions {
            var kept = group
            for (id, session) in group where session.state == .working {
                guard let transcript = session.transcript, let handle = FileHandle(forReadingAtPath: transcript.path) else { continue }
                defer { try? handle.close() }
                guard let end = try? handle.seekToEnd(), end > transcript.offset else { continue }
                // 记录里的新内容最多读 256KB；留 64 字节重叠，免得标记被读成两截。
                let from = max(transcript.offset, end > 262_144 ? end - 262_144 : 0)
                try? handle.seek(toOffset: from)
                let text = String(decoding: (try? handle.readToEnd()) ?? Data(), as: UTF8.self)
                if text.contains("[Request interrupted by user") {
                    kept[id] = nil
                    changed = true
                } else {
                    var updated = session
                    updated.transcript = (transcript.path, end > 64 ? max(transcript.offset, end - 64) : transcript.offset)
                    kept[id] = updated
                }
            }
            sessions[bundleID] = kept.isEmpty ? nil : kept
        }
        if changed { onChange?() }
    }

    // MARK: - 最近活动（配对列表用）

    /// 启动时先读上次存下的，免得第一条事件把别的智能体的记录覆盖掉。
    private lazy var activity: [String: [String: Any]] = {
        guard let data = try? Data(contentsOf: AgentRegistry.activityURL),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: [String: Any]] else { return [:] }
        return json
    }()
    private var lastActivityWrite = Date.distantPast

    /// 记下每个智能体最近一次事件，存进 `activity.json`（重启 App、换日志都不丢）。心跳频繁，最多 2 秒写一次。
    private func recordActivity(agent: String, event: String, bundleID: String?) {
        activity[agent] = ["date": Date().timeIntervalSince1970, "event": event, "app": bundleID ?? ""]
        guard event != "PostToolUse" || Date().timeIntervalSince(lastActivityWrite) > 2 else { return }
        lastActivityWrite = Date()
        if let data = try? JSONSerialization.data(withJSONObject: activity) {
            try? data.write(to: AgentRegistry.activityURL, options: .atomic)
        }
    }

    /// 诊断日志：最近收到的事件，排查“助手没反应”时看。超过 64KB 就从头来。
    private func record(_ line: String) {
        let url = Self.supportDirectory.appendingPathComponent("events.log")
        let text = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        if let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int, size > 65536 {
            try? FileManager.default.removeItem(at: url)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(text.utf8))
            try? handle.close()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func dropStaleSessions(now: Date = Date()) {
        var changed = false
        for (bundleID, group) in sessions {
            let kept = group.filter { _, session in
                if session.state == .done { return true }
                let limit = session.lenient ? Self.pairedStaleAfter : Self.staleAfter
                return now.timeIntervalSince(session.lastEvent) < limit
            }
            if kept.count != group.count {
                sessions[bundleID] = kept.isEmpty ? nil : kept
                changed = true
            }
        }
        if changed { onChange?() }
    }

    // MARK: - 进程

    /// 从 `pid` 一路往父进程找，第一个有 Dock 图标的 App 就是会话所在的 App。
    /// 找不到时（比如豆包的命令跑在 XPC 服务里，父进程直接是 launchd，和主 App 没有父子关系）再看链上进程的可执行文件
    /// 位于哪个 .app 包里：`DoubaoWork.app/…/AgentInfraService.xpc/…` 就属于正在运行的 DoubaoWork。
    static func owningApp(of pid: pid_t) -> String? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var current = pid
        var paths: [String] = []
        for _ in 0..<32 where current > 1 {
            if current != ownPID, let app = NSRunningApplication(processIdentifier: current),
               app.activationPolicy == .regular, let id = app.bundleIdentifier {
                return id
            }
            if let path = executablePath(of: current) { paths.append(path) }
            guard let parent = parentPID(of: current), parent != current else { break }
            current = parent
        }
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            .compactMap { app in app.bundleIdentifier.flatMap { id in app.bundleURL.map { (id: id, path: $0.path) } } }
        for path in paths {
            if let id = bundleID(containing: path, among: running) { return id }
        }
        return nil
    }

    /// 可执行文件路径在哪个正在运行的 App 包里。从最外层的 .app 开始匹配（Helper、XPC 服务都嵌在主 App 里面）。
    static func bundleID(containing executablePath: String, among running: [(id: String, path: String)]) -> String? {
        let parts = executablePath.split(separator: "/", omittingEmptySubsequences: false)
        for index in parts.indices where parts[index].hasSuffix(".app") {
            let bundlePath = parts[...index].joined(separator: "/")
            if let match = running.first(where: { $0.path == bundlePath }) { return match.id }
        }
        return nil
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }
}

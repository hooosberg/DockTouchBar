import Foundation

/// 通过“配对智能体”提示词自己接进来的智能体：它们验证通过之后，会把一份登记 JSON 写进 `agents/<id>.json`。
/// 登记只是给设置页的“配对列表”看的；真正让动画出现的是它们调用转发脚本发来的事件。
struct PairedAgent: Identifiable, Equatable {
    let id: String
    let name: String
    /// 怎么接的：hook（用它自己的 hook 机制）、instructions（写进它的长期指令里）或 passive（App 内置监视，没改任何配置）。
    let method: String
    /// 它改过的文件（绝对路径），取消配对时要还原。
    let files: [String]
    let notes: String
    /// 验证时找到的所在 App 的 bundleID（`--register` 写入；老的登记没有）。
    var host: String? = nil
}

/// 某个智能体最近一次发来的事件。
struct AgentActivity: Equatable {
    let date: Date
    let event: String
    /// 事件解析到的所在 App 的 bundleID；nil＝没找到。
    let bundleID: String?
}

enum AgentRegistry {
    static var directory: URL { AgentMonitor.supportDirectory.appendingPathComponent("agents", isDirectory: true) }
    static var logURL: URL { AgentMonitor.supportDirectory.appendingPathComponent("events.log") }
    /// 每个智能体最近一次事件（App 自己写，重启和换日志都不丢）。连接验证和动画演示不写入这里。
    static var activityURL: URL { AgentMonitor.supportDirectory.appendingPathComponent("activity.json") }

    /// id 只能是小写字母、数字、短横线（也是登记文件名，不能带路径）。
    static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 40 && id.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") }
    }

    /// 读所有登记。坏文件、id 不合法或和文件名不一致的直接跳过，不报错。
    static func load() -> [PairedAgent] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }.compactMap { url -> PairedAgent? in
            guard let data = try? Data(contentsOf: url),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let id = json["id"] as? String, isValidID(id), url.deletingPathExtension().lastPathComponent == id else { return nil }
            let name = (json["name"] as? String).flatMap { $0.isEmpty ? nil : String($0.prefix(60)) } ?? id
            return PairedAgent(id: id, name: name,
                               method: String(((json["method"] as? String) ?? "").prefix(40)),
                               files: ((json["files"] as? [Any]) ?? []).compactMap { $0 as? String }.prefix(20).map { String($0.prefix(300)) },
                               notes: String(((json["notes"] as? String) ?? "").prefix(300)),
                               host: (json["host"] as? String).flatMap { $0.isEmpty ? nil : String($0.prefix(120)) })
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 只删登记，不动它改过的配置——那要让它自己还原（列表里有“复制取消配对提示词”）。
    static func remove(id: String) {
        guard isValidID(id) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).json"))
    }

    /// 每个智能体最近一次事件。
    static func lastActivity() -> [String: AgentActivity] {
        guard let data = try? Data(contentsOf: activityURL),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: [String: Any]] else { return [:] }
        return json.compactMapValues { item in
            guard let seconds = item["date"] as? Double, let event = item["event"] as? String else { return nil }
            let app = (item["app"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return AgentActivity(date: Date(timeIntervalSince1970: seconds), event: event, bundleID: app)
        }
    }

    /// 第一次有 `activity.json`（升级自按日志判断“已验证”的旧版本）时，从诊断日志回填每个智能体最近一次事件，已配对的不会退回“待验证”。
    /// 日志一行：`时间 事件 agent=… session=… pid=… app=…`。已有 activity.json 的不动。
    static func backfillActivityFromLog() {
        guard !FileManager.default.fileExists(atPath: activityURL.path),
              let text = try? String(contentsOf: logURL, encoding: .utf8) else { return }
        let formatter = ISO8601DateFormatter()
        var result: [String: [String: Any]] = [:]
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: " ")
            guard fields.count >= 3, let date = formatter.date(from: String(fields[0])) else { continue }
            func value(_ key: String) -> String? {
                fields.first { $0.hasPrefix(key + "=") }.map { String($0.dropFirst(key.count + 1)) }
            }
            guard let agent = value("agent"), agent != "-" else { continue }
            let app = value("app").flatMap { $0 == "-" ? nil : $0 } ?? ""
            result[agent] = ["date": date.timeIntervalSince1970, "event": String(fields[1]), "app": app]
        }
        guard !result.isEmpty, let data = try? JSONSerialization.data(withJSONObject: result) else { return }
        try? data.write(to: activityURL, options: .atomic)
    }

    /// 早期版本自动连接过的 Claude Code、Codex：它们的 hook 还在各自配置里工作，只是没有登记。
    /// 启动时给它们补一份登记，配对列表里才看得到（只读配置，不改任何东西；已有登记的不动）。
    static var homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    @discardableResult static func migrateLegacyHooks() -> [String] {
        let legacy: [(id: String, name: String, path: String)] = [
            ("claude-code", "Claude Code", ".claude/settings.json"),
            ("codex", "Codex", ".codex/hooks.json"),
        ]
        var created: [String] = []
        for item in legacy {
            let registration = directory.appendingPathComponent("\(item.id).json")
            let config = homeDirectory.appendingPathComponent(item.path)
            guard !FileManager.default.fileExists(atPath: registration.path),
                  let text = try? String(contentsOf: config, encoding: .utf8),
                  text.contains(AgentMonitor.supportDirectory.path), text.contains("-hook.sh") else { continue }
            let json: [String: Any] = ["id": item.id, "name": item.name, "method": "hook", "files": [config.path],
                                       "notes": "早期版本自动连接的 hook，启动时补上的登记"]
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let data = try? JSONSerialization.data(withJSONObject: json) {
                try? data.write(to: registration, options: .atomic)
                created.append(item.id)
            }
        }
        return created
    }
}

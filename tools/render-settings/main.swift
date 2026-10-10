// 离屏渲染设置窗口里的“配对智能体”页成 PNG，检查界面、做 README 截图用（不打开真的窗口，不受 Stage Manager 影响）。
// 由 tools/render-settings.sh 编译运行。环境变量：
//   RENDER_LANG=en|zh   界面语言（默认跟随系统）
//   RENDER_FAKE=1       用一份中性的假数据（五个常见的智能体、都“刚收到事件”，路径是 /Users/Shared/…），不读你自己的登记，
//                       截图里不会出现你的用户名；做 README 截图时用
//   RENDER_HEIGHT=900   窗口高度（默认 700）
import AppKit
import SwiftUI

let env = ProcessInfo.processInfo.environment
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "settings.png"
if let lang = env["RENDER_LANG"] { UserDefaults.standard.set(lang, forKey: SettingsKey.language) }

var cleanup: URL?
if env["RENDER_FAKE"] == "1" {
    let fm = FileManager.default
    let support = URL(fileURLWithPath: "/Users/Shared/DockTouchBar", isDirectory: true)
    cleanup = support
    AgentMonitor.supportDirectory = support
    try? fm.removeItem(at: support)
    try? fm.createDirectory(at: AgentRegistry.directory, withIntermediateDirectories: true)
    let fake: [(id: String, name: String, method: String, app: String)] = [
        ("claude-code", "Claude Code", "hook", "com.anthropic.claudefordesktop"),
        ("codex", "Codex", "hook", "com.openai.codex"),
        ("qoder", "Qoder", "hook", "com.qoder.app"),
        ("workbuddy", "WorkBuddy", "hook", "com.tencent.workbuddy.mac"),
        ("antigravity", "Antigravity", "instructions", "com.google.antigravity"),
        ("qwenwork", "Qwen Work", "instructions", "cn.qwenwork.desktop.mac"),
        ("doubao", "Doubao Work", "passive", "com.work.pc.doubao"),
    ]
    var activity: [String: [String: Any]] = [:]
    for (index, agent) in fake.enumerated() {
        let json: [String: Any] = ["id": agent.id, "name": agent.name, "method": agent.method, "files": [], "notes": ""]
        try? JSONSerialization.data(withJSONObject: json).write(to: AgentRegistry.directory.appendingPathComponent("\(agent.id).json"))
        activity[agent.id] = ["date": Date().timeIntervalSince1970 - Double(index * 70 + 8), "event": "Stop", "app": agent.app]
    }
    try? JSONSerialization.data(withJSONObject: activity).write(to: AgentRegistry.activityURL)
    try? AgentHookInstaller.refreshScript()
}

let height = CGFloat(Double(env["RENDER_HEIGHT"] ?? "") ?? 700)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let host = NSHostingView(rootView: PairingPage().frame(width: 500, height: height).environment(\.colorScheme, .dark))
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: height), styleMask: [.titled], backing: .buffered, defer: false)
window.appearance = NSAppearance(named: .darkAqua)
window.contentView = host
window.setFrameOrigin(NSPoint(x: -2000, y: 0))
window.orderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { exit(1) }
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: output))
    if let cleanup { try? FileManager.default.removeItem(at: cleanup) }
    print("Wrote \(output)")
    exit(0)
}
app.run()

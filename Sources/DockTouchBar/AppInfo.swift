import Foundation

/// 作者和项目的链接、版本号。改链接只改这里。
enum AppInfo {
    static let name = "DockTouchBar"
    /// 打包文件名（.app、.dmg、进程名）和 Application Support 目录名。
    static let fileName = "DockTouchBar"
    static let author = "hooosberg"
    static let productPageURL = URL(string: "https://hooosberg.com/apps/docktouchbar")!
    static let diaryURL = URL(string: "https://hooosberg.com/apps/docktouchbar/diary")!
    static let githubProfileURL = URL(string: "https://github.com/hooosberg")!
    static let repositoryURL = URL(string: "https://github.com/hooosberg/DockTouchBar")!

    /// 致谢名单：给项目提过 PR 或建议的人。新增贡献者在这里加一行，README 的 Thanks 表同步改。
    struct Contributor: Identifiable {
        let handle: String
        let zh: String
        let en: String
        var id: String { handle }
        var url: URL { URL(string: "https://github.com/\(handle)")! }
    }

    static let contributors: [Contributor] = [
        Contributor(handle: "thierry-laval",
                    zh: "可在程序坞隐藏图标（PR #5）· 按住 ⌥ 长按强制退出（PR #6）· 通用二进制构建回退（PR #7）· 设置页权限状态自动刷新（PR #11）· 法语翻译补全（PR #12）",
                    en: "Hide the Dock icon (PR #5) · Hold ⌥ while long-pressing to force quit (PR #6) · Universal build fallback (PR #7) · Settings permission status refresh (PR #11) · Complete French translations (PR #12)"),
        Contributor(handle: "1dea193073",
                    zh: "改进智能体配对诊断，区分演示与真实活动（PR #3）",
                    en: "Better agent-pairing diagnostics, demo vs. real activity (PR #3)"),
        Contributor(handle: "Aserti2",
                    zh: "提出隐藏程序坞图标的需求（#4）",
                    en: "Asked for a way to hide the Dock icon (#4)"),
        Contributor(handle: "fatHROSE",
                    zh: "反馈 fn 避让问题，促成“避让”可关闭，并建议图标靠右、避让后自动恢复，均已在 1.25 实现（#2）",
                    en: "Reported the fn-key yielding, which led to making it optional; suggested right-aligned icons and auto-return, both added in 1.25 (#2)"),
        Contributor(handle: "hlenyafinland",
                    zh: "早期使用建议（#1）",
                    en: "Early feedback and suggestions (#1)"),
    ]

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}

import AppKit
import SwiftUI
import ServiceManagement

/// 设置窗口，三页：设置（所有选项）、使用说明、关于（介绍、更新、作者链接）。
/// 每次打开都重新创建内容，这样切换语言后再打开就是新语言。
final class SettingsWindowController {
    private var window: NSWindow?
    private var defaultsObserver: NSObjectProtocol?
    /// 诊断按钮要做的事，由 AppDelegate 提供。
    var onDiagnose: () -> Void = {}

    func show(page: SettingsPage = .settings, checkUpdates: Bool = false) {
        let window = self.window ?? makeWindow()
        self.window = window
        updateTitle()
        if defaultsObserver == nil {
            // 窗口开着时切换了语言，标题也要跟着换。
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.updateTitle()
            }
        }
        window.contentViewController = NSHostingController(rootView: SettingsView(initialPage: page, onDiagnose: onDiagnose))
        window.center()
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
        if checkUpdates {
            UpdateManager.shared.checkForUpdates(silent: false)
        }
    }

    private func updateTitle() {
        window?.title = L10n.tr("\(AppInfo.name) 设置", "\(AppInfo.name) Settings")
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window
    }
}

enum SettingsPage { case settings, pairing, usage, about }

private struct SettingsView: View {
    typealias Page = SettingsPage
    let initialPage: SettingsPage
    let onDiagnose: () -> Void

    /// 使用说明里的一项：左边是图标（系统符号或者像素画），右边是标题和说明。
    private struct Usage: Identifiable {
        enum Icon {
            case symbol(String)
            case pixels([CGImage?], scale: CGFloat)
        }
        let id = UUID()
        let icon: Icon
        let title: String
        let detail: String
    }

    @State private var page = Page.settings
    /// 读取语言键，改了语言后整个窗口立刻重绘。
    @AppStorage(SettingsKey.language) private var language = AppLanguage.system.rawValue
    @ObservedObject private var updater = UpdateManager.shared

    private var gestures: [Usage] {
        [
            Usage(icon: .symbol("hand.tap"), title: L10n.tr("单击", "Tap"),
                  detail: L10n.tr("切换到这个 App，没打开的会启动。窗口在别的桌面时自动切过去（需要辅助功能权限）。",
                                  "Switch to the app, or launch it if it isn't running. If its windows are on another desktop, jump there (needs Accessibility permission).")),
            Usage(icon: .symbol("minus.rectangle"), title: L10n.tr("双击", "Double-tap"),
                  detail: L10n.tr("最小化当前窗口，等同左上角黄色按钮。需要辅助功能权限；再点图标可恢复。",
                                  "Minimize the current window, like its yellow button. Needs Accessibility permission; tap the icon again to restore it.")),
            Usage(icon: .symbol("power"), title: L10n.tr("长按", "Long-press"),
                  detail: L10n.tr("退出这个 App（等同 ⌘Q）。按住时右边缘出现像素画的倒计时，小角色沿进度条跑到头就退出；中途松手算单击。时长和提示的季节风格（春夏秋冬）可在设置里调整。",
                                  "Quit the app (same as ⌘Q). A pixel-art countdown appears at the edge and a tiny character runs along the progress bar; when it gets to the end, the app quits. Release early to treat it as a tap. The duration and the season (spring, summer, autumn, winter) are set in Settings.")),
            Usage(icon: .symbol("arrow.left.and.right"), title: L10n.tr("左右滑动", "Swipe"),
                  detail: L10n.tr("图标放不下时滚动。", "Scroll when the icons don't all fit.")),
        ]
    }

    private var buttons: [Usage] {
        [
            Usage(icon: .pixels([PixelIcon.coffee.first], scale: 1.5), title: L10n.tr("咖啡杯", "Coffee cup"),
                  detail: L10n.tr("歇一会儿：Dock 暂时隐藏、系统控制条（亮度、音量）回来，稍后自动恢复，时长在设置里调整。也可以在菜单栏菜单里取消勾选“在 Touch Bar 上显示 Dock”。",
                                  "Take a break: the Dock hides for a moment and the system controls (brightness, volume) come back, then it returns on its own (set the time in Settings). Or untick “Show Dock on Touch Bar” in the menu bar menu.")),
            Usage(icon: .pixels([PixelIcon.center, PixelIcon.maximize], scale: 1), title: L10n.tr("窗口居中 / 最大化", "Center / maximize"),
                  detail: L10n.tr("把最前面 App 的窗口居中；已经居中时再点一下最大化（铺满可用区域，不是原生全屏），再点回到居中。你自己拖过或换了 App，就先居中。需要辅助功能权限。",
                                  "Center the frontmost app's window. When it is already centered, the next tap maximizes it (fills the usable area, not native full screen), and the next one centers it again. If you moved the window or switched apps, it centers first. Needs Accessibility permission.")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $page) {
                Text(L10n.tr("设置", "Settings")).tag(Page.settings)
                Text(L10n.tr("配对智能体", "Pair agents")).tag(Page.pairing)
                Text(L10n.tr("使用说明", "How to use")).tag(Page.usage)
                Text(L10n.tr("关于", "About")).tag(Page.about)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .id(language)
            .frame(width: 420)
            .padding(.vertical, 14)

            switch page {
            case .settings: SettingsForm(onDiagnose: onDiagnose)
            case .pairing: PairingPage()
            case .usage: usagePage
            case .about: aboutPage
            }
        }
        .frame(width: 500, height: 700)
        .onAppear { page = initialPage }
    }

    // MARK: - 关于

    private var aboutPage: some View {
        VStack(spacing: 5) {
            Spacer(minLength: 16)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
            Text(AppInfo.name).font(.title.weight(.bold)).padding(.top, 4)
            Text(L10n.tr("版本 \(AppInfo.version)（\(AppInfo.build)）", "Version \(AppInfo.version) (\(AppInfo.build))"))
                .font(.callout).foregroundStyle(.secondary)

            // 自动检测与安装更新
            updateCard

            Text(L10n.tr("简洁 · 优雅 · 高效", "Simple · Elegant · Efficient"))
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 6)
            Text(L10n.tr("把 Dock 放到 Touch Bar 上", "Your Dock on the Touch Bar"))
                .font(.callout).foregroundStyle(.secondary)

            Spacer(minLength: 16)
            Divider().padding(.horizontal, 40)
            Spacer(minLength: 14)

            Text(L10n.tr("作者：\(AppInfo.author)", "By \(AppInfo.author)")).font(.headline)
            HStack(spacing: 18) {
                Link(destination: AppInfo.productPageURL) {
                    Label(L10n.tr("产品页", "Product page"), systemImage: "globe")
                }
                Link(destination: AppInfo.diaryURL) {
                    Label(L10n.tr("开发日记", "Build diary"), systemImage: "book")
                }
                Link(destination: AppInfo.githubProfileURL) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .padding(.top, 3)
            Text(L10n.tr("如果它对你有帮助，欢迎在 GitHub 上点一个 Star 支持一下。",
                         "If it helps you, a Star on GitHub would mean a lot."))
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Link(destination: AppInfo.repositoryURL) {
                Label(L10n.tr("在 GitHub 上点 Star", "Star on GitHub"), systemImage: "star.fill")
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            .padding(.top, 3)

            Spacer(minLength: 14)
            Text(L10n.tr("© 2026 \(AppInfo.author) · 个人使用免费，商业使用需另行授权",
                         "© 2026 \(AppInfo.author) · Free for personal use, commercial use requires a separate license"))
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updater.checkForUpdates(silent: true)
        }
    }

    @ViewBuilder
    private var updateCard: some View {
        switch updater.state {
        case .idle:
            Button {
                updater.checkForUpdates(silent: false)
            } label: {
                Label(L10n.tr("检查更新", "Check for Updates"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 2)

        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(L10n.tr("正在检查新版本…", "Checking for updates…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 3)

        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text(L10n.tr("已是最新版本", "Up to date"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    updater.checkForUpdates(silent: false)
                } label: {
                    Text(L10n.tr("重新检查", "Check Again"))
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 3)

        case .available(let info):
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.orange)
                    Text(L10n.tr("发现新版本 v\(info.version)", "New version v\(info.version) available!"))
                        .font(.callout.weight(.semibold))
                }

                if !info.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(info.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                HStack(spacing: 12) {
                    Button {
                        updater.startInstall()
                    } label: {
                        Label(L10n.tr("自动安装更新并重启", "Update & Restart"), systemImage: "arrow.down.circle.fill")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Link(destination: info.releaseURL) {
                        Text(L10n.tr("发行说明", "Release Notes"))
                            .font(.caption)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
            .padding(.top, 4)

        case .downloading(let progress):
            VStack(spacing: 5) {
                HStack {
                    Text(L10n.tr("正在下载新版本…", "Downloading update…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Button(L10n.tr("取消", "Cancel")) {
                    updater.cancel()
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(width: 240)
            .padding(.top, 4)

        case .verifying:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(L10n.tr("正在校验苹果安全代码签名…", "Verifying Apple code signature…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(L10n.tr("正在安装更新并重新启动…", "Installing and restarting…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

        case .failed(let message):
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 8) {
                    Button(L10n.tr("重试", "Retry")) {
                        updater.checkForUpdates(silent: false)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Link(destination: AppInfo.repositoryURL) {
                        Text(L10n.tr("前往 GitHub 下载", "Download from GitHub"))
                            .font(.caption2)
                    }
                }
            }
            .padding(.top, 3)
        }
    }

    // MARK: - 使用说明

    private var usagePage: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            section(L10n.tr("在图标上", "On the icons"), gestures)
            section(L10n.tr("右侧的按钮", "The buttons on the right"), buttons)
            Text(L10n.tr("需要的权限只有“辅助功能”，在“设置”页的“权限”里能看到状态、点一下去开启。开关开着但设置里仍显示“未开启”：在 系统设置 → 隐私与安全性 → 辅助功能 里删掉 DockTouchBar，再重新添加并打开。",
                         "The only permission needed is Accessibility; its status is shown under “Permissions” on the Settings page, and one click takes you to turn it on. If it's switched on but Settings still says it's off: remove DockTouchBar in System Settings → Privacy & Security → Accessibility, then add it again and turn it on."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func section(_ title: String, _ items: [Usage]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ForEach(items) { usage in
                HStack(alignment: .top, spacing: 10) {
                    icon(usage.icon)
                        .frame(width: 34, alignment: .center)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(usage.title).font(.callout.weight(.semibold))
                        Text(usage.detail)
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func icon(_ icon: Usage.Icon) -> some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
        case .pixels(let images, let scale):
            // 像素画是白色的，按“模板”画：颜色跟着文字走，浅色、深色外观下都看得清。每格 4 个像素。
            VStack(spacing: 4) {
                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                    if let image {
                        Image(decorative: image, scale: 1)
                            .renderingMode(.template)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: CGFloat(image.width) / 4 * scale, height: CGFloat(image.height) / 4 * scale)
                    }
                }
            }
        }
    }
}

// MARK: - 设置页

private struct SettingsForm: View {
    let onDiagnose: () -> Void

    @AppStorage(SettingsKey.enabled) private var enabled = true
    @AppStorage(SettingsKey.showPinned) private var showPinned = true
    @AppStorage(SettingsKey.centerIcons) private var centerIcons = true
    @AppStorage(SettingsKey.iconSpacing) private var spacing = 4
    @AppStorage(SettingsKey.showCenterButton) private var showCenterButton = true
    @AppStorage(SettingsKey.centerHeight) private var centerHeight = 80
    @AppStorage(SettingsKey.centerWidth) private var centerWidth = 0
    @AppStorage(SettingsKey.hideSeconds) private var hideSeconds = 20
    @AppStorage(SettingsKey.doubleTapMinimize) private var doubleTap = true
    @AppStorage(SettingsKey.longPressSeconds) private var longPress = 3
    @AppStorage(QuitHintTheme.defaultsKey) private var theme = QuitHintTheme.spring.rawValue
    @AppStorage(SettingsKey.yieldCapture) private var yieldCapture = true
    @AppStorage(SettingsKey.yieldFunctionRow) private var yieldFn = true
    @AppStorage(SettingsKey.language) private var language = AppLanguage.system.rawValue
    @AppStorage(SettingsKey.agentStatus) private var agentStatus = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasAccess = AppSwitcher.hasAccessibilityAccess

    var body: some View {
        Form {
            Section(L10n.tr("语言", "Language")) {
                Picker(L10n.tr("界面语言", "Interface language"), selection: $language) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { Text($0.nativeName).tag($0.rawValue) }
                }
            }

            Section(L10n.tr("显示", "Display")) {
                Toggle(L10n.tr("在 Touch Bar 上显示 Dock", "Show Dock on Touch Bar"), isOn: $enabled)
                    .disabled(!TouchBarBridge.isAvailable)
                Toggle(L10n.tr("只显示正在运行的 App", "Only show running apps"),
                       isOn: Binding(get: { !showPinned }, set: { showPinned = !$0 }))
                Toggle(L10n.tr("图标居中显示", "Center the icons"), isOn: $centerIcons)
                Picker(L10n.tr("图标间距", "Icon spacing"), selection: $spacing) {
                    ForEach(SettingsOptions.spacing, id: \.self) { Text("\($0)pt").tag($0) }
                }
                Picker(L10n.tr("点咖啡杯后临时隐藏", "Hide after tapping the coffee cup"), selection: $hideSeconds) {
                    ForEach(SettingsOptions.hide, id: \.self) { Text(L10n.tr("\($0) 秒", "\($0) s")).tag($0) }
                }
            }

            Section(L10n.tr("窗口居中 / 最大化", "Center / maximize")) {
                Toggle(L10n.tr("显示“窗口居中 / 最大化”按钮", "Show the center / maximize button"), isOn: $showCenterButton)
                Picker(L10n.tr("居中窗口的高度", "Centered window height"), selection: $centerHeight) {
                    ForEach(SettingsOptions.height, id: \.self) {
                        Text(L10n.tr("屏幕高度的 \($0)%", "\($0)% of screen height")).tag($0)
                    }
                }
                Picker(L10n.tr("居中窗口的宽度", "Centered window width"), selection: $centerWidth) {
                    ForEach(SettingsOptions.width, id: \.self) {
                        Text($0 == 0 ? L10n.tr("与高度相同（正方形）", "Same as height (square)")
                                     : L10n.tr("屏幕宽度的 \($0)%", "\($0)% of screen width")).tag($0)
                    }
                }
            }

            Section(L10n.tr("AI 编程助手", "AI coding agents")) {
                Toggle(L10n.tr("在图标上显示工作状态", "Show working status on icons"), isOn: $agentStatus)
                Text(L10n.tr("智能体怎么接进来、接了哪些，在“配对智能体”页。助手工作时，所在 App 的图标变成像素屏幕加字符雨，做完显示 OK，点一下图标消失。",
                             "How agents connect, and which ones are, is on the “Pair agents” page. While an agent works, the icon of the app it runs in turns into a pixel screen with falling digits, then shows OK when it's done; a tap on the icon dismisses it."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L10n.tr("手势", "Gestures")) {
                Toggle(L10n.tr("双击图标：最小化当前窗口", "Double-tap an icon: minimize the window"), isOn: $doubleTap)
                Picker(L10n.tr("长按图标：退出 App", "Long-press an icon: quit the app"), selection: $longPress) {
                    ForEach(SettingsOptions.longPress, id: \.self) {
                        Text($0 == 0 ? L10n.tr("不启用", "Off") : L10n.tr("按住 \($0) 秒", "Hold \($0) s")).tag($0)
                    }
                }
                Picker(L10n.tr("长按提示风格", "Long-press style"), selection: $theme) {
                    ForEach(QuitHintTheme.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            }

            Section(L10n.tr("系统 Touch Bar 避让", "Yield to system Touch Bar controls")) {
                Toggle(L10n.tr("截图 / 录屏时自动避让", "Yield during screenshots / recording"), isOn: $yieldCapture)
                Toggle(L10n.tr("按住 Fn 时自动避让", "Yield while Fn is held"), isOn: $yieldFn)
                Text(L10n.tr("开启时 Dock 临时隐藏，结束后自动恢复", "When on, the Dock hides temporarily and returns afterward"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L10n.tr("通用", "General")) {
                Toggle(L10n.tr("登录时自动启动", "Launch at login"), isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }))
            }

            Section(L10n.tr("权限", "Permissions")) {
                HStack {
                    Image(systemName: hasAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(hasAccess ? Color.green : Color.orange)
                    Text(hasAccess ? L10n.tr("辅助功能：已开启", "Accessibility: on")
                                   : L10n.tr("辅助功能：未开启", "Accessibility: off"))
                    Spacer()
                    Button(hasAccess ? L10n.tr("打开系统设置", "Open System Settings")
                                     : L10n.tr("去开启…", "Turn on…")) {
                        AppSwitcher.requestAccessibilityAccess()
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Text(L10n.tr("用来：跨桌面切换窗口、窗口居中和最大化、长按关闭访达窗口、双击最小化、监听 Fn 避让。没有它其他功能照常，只是这几项不可用。除此之外不需要其他任何权限。",
                             "Used to: switch to windows on other desktops, center and maximize windows, close Finder's windows on long-press, minimize on double-tap, and detect Fn for yielding. Without it everything else works. No other permission is needed."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L10n.tr("问题排查", "Troubleshooting")) {
                Button(L10n.tr("诊断：为什么看不到 Dock？…", "Diagnose: why can't I see the Dock?…"), action: onDiagnose)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            hasAccess = AppSwitcher.hasAccessibilityAccess
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on { try service.register() } else { try service.unregister() }
        } catch {
            let alert = NSAlert()
            alert.messageText = L10n.tr("无法修改登录项", "Couldn't change the login item")
            alert.informativeText = "\(error.localizedDescription)\n\n"
                + L10n.tr("先把 App 放进「应用程序」文件夹再试。", "Move the app to the Applications folder and try again.")
            alert.runModal()
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        launchAtLogin = service.status == .enabled
    }
}


// MARK: - 配对智能体页

/// 三块：说明、给智能体的提示词（复制）、配对列表（只有已经配对的智能体；取消配对也是复制提示词交给它）。
struct PairingPage: View {
    @State private var copied = false
    @State private var copiedUnpair: String?
    /// 取消配对（passive）后要让列表重新读一遍登记。
    @State private var listRevision = 0

    var body: some View {
        Form {
            Section(L10n.tr("说明", "How it works")) {
                Text(L10n.tr("""
                    让任何有自主能力的智能体（Claude Code、Codex、WorkBuddy、Antigravity、豆包、千问……）自己接进来：
                    1. 复制下面的提示词，粘贴给它。
                    2. 它会自己查它的软件怎么挂 hook（没有 hook 就写进它的长期指令），改配置前先备份，并告诉你每一步做了什么。
                    3. 连接验证通过后会出现在下面的列表里；审核信任 hook 后，交给它一个任务，确认图标随工作状态变化。验证演示不代表自动上报已启用。
                    如果它的软件要你审核或信任新增的 hook，按它说的点一下就行。不想用了，在列表里复制“取消配对提示词”交给它。
                    """,
                    """
                    Let any capable agent (Claude Code, Codex, WorkBuddy, Antigravity, Doubao, Qwen…) connect itself:
                    1. Copy the prompt below and paste it to the agent.
                    2. It looks up how its app does hooks (or, without hooks, writes to its long-term instructions), backs up its config first, and tells you every step.
                    3. After connection verification it appears in the list below. Review and trust its hooks, then give it a task to check that the icon follows its work. The demo does not prove automatic delivery is enabled.
                    If its app asks you to review or trust a new hook, just click as it says. To stop, copy the unpair prompt from the list and hand it to the agent.
                    """))
                    .font(.callout).foregroundStyle(.secondary)
            }

            Section(L10n.tr("提示词", "Prompt")) {
                ScrollView {
                    Text(AgentPairingPrompt.text())
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 150)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                HStack {
                    Spacer()
                    Button(copied ? L10n.tr("已复制 ✓", "Copied ✓") : L10n.tr("复制提示词", "Copy prompt")) {
                        copy(AgentPairingPrompt.text())
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }

            Section(L10n.tr("配对列表", "Paired agents")) {
                // 每 3 秒重读一次登记和最近事件，智能体登记、发来事件或撤销后这里自己更新。
                TimelineView(.periodic(from: .now, by: 3)) { _ in
                    list
                }
                HStack {
                    Spacer()
                    Button(L10n.tr("清除动画状态", "Clear animation states")) { AgentMonitor.shared.resetAll() }
                        .buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var list: some View {
        let _ = listRevision
        let activity = AgentRegistry.lastActivity()
        let paired = AgentRegistry.load()
        ForEach(paired) { agent in
            let seen = activity[agent.id]
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Label(agent.name, systemImage: seen?.bundleID != nil ? "checkmark.circle.fill" : "clock")
                        .foregroundStyle(seen?.bundleID != nil ? Color.green : Color.orange)
                    if !agent.method.isEmpty { Text(agent.method).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if let host = seen?.bundleID ?? agent.host {
                        Button(L10n.tr("试一下", "Try it")) { AgentMonitor.shared.simulate(bundleID: host) }
                    }
                    if agent.method == "passive" {
                        // 没改过任何配置，没什么要让它还原的：直接删登记，App 也不再看它。
                        Button(L10n.tr("取消配对", "Unpair")) {
                            AgentRegistry.remove(id: agent.id)
                            listRevision += 1
                        }
                    } else {
                        Button(copiedUnpair == agent.id ? L10n.tr("已复制 ✓", "Copied ✓") : L10n.tr("复制取消配对提示词", "Copy unpair prompt")) {
                            copy(AgentPairingPrompt.unpairText(agent))
                            copiedUnpair = agent.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedUnpair = nil }
                        }
                    }
                }
                Text(status(seen, agent: agent)).font(.caption).foregroundStyle(.secondary)
            }
        }
        if paired.isEmpty {
            Text(L10n.tr("还没有配对的智能体", "No paired agents yet")).foregroundStyle(.secondary)
        }
    }

    private func status(_ seen: AgentActivity?, agent: PairedAgent) -> String {
        guard let seen else {
            if agent.host != nil {
                return L10n.tr("连接已验证；等待事件。请完成所需的 hook 信任，再交给它一个任务。", "Connection verified; waiting for events. Complete any required hook trust, then give the agent a task.")
            }
            return L10n.tr("待验证：还没收到它发来的事件", "Pending: no events received yet")
        }
        // “几分钟前”按 App 里选的语言显示，不跟系统语言（英文界面不能冒出“分钟前”）。
        let formatter = RelativeDateTimeFormatter()
        if L10n.language != .system { formatter.locale = Locale(identifier: L10n.language.rawValue) }
        let ago = formatter.localizedString(for: seen.date, relativeTo: Date())
        var app = ""
        if let id = seen.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            app = " · " + FileManager.default.displayName(atPath: url.path)
        } else if seen.bundleID == nil {
            app = " · " + L10n.tr("没找到所在 App，图标不会有动画", "host app not found — no icon animation")
        }
        // An event may also be sent manually; don't claim automatic hook delivery or trust.
        return L10n.tr("事件记录：\(ago) 收到事件\(app)", "Activity: event received \(ago)\(app)")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

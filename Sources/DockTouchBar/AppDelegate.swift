import AppKit
import ServiceManagement

/// 菜单栏菜单：几个常用开关 + “设置…”按钮（打开设置窗口）+ 退出。其余选项都在设置窗口里。
/// 菜单文字全部在 `menuNeedsUpdate` 里按当前语言重新设置，所以切换语言后不用重启。
/// 设置窗口和菜单都只改 UserDefaults，`applySettings` 监听变化后统一同步给 Dock。
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private typealias Key = SettingsKey

    private let dock = DockBarController()
    private let settingsWindow = SettingsWindowController()
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem?
    private var launched = false
    private var appliedEnabled: Bool?

    private lazy var setupWarningItem = makeItem(#selector(fixTouchBarSetup))
    /// 显示后自检没通过：Dock 应该在显示却没有出现。
    private var dockFailedToShow = false
    private lazy var enabledItem = makeItem(#selector(toggleEnabled))
    private lazy var pinnedItem = makeItem(#selector(togglePinned))
    private lazy var centerIconsItem = makeItem(#selector(toggleCenterIcons))
    private lazy var centerButtonItem = makeItem(#selector(toggleCenterButton))
    private lazy var hideDockIconItem = makeItem(#selector(toggleHideDockIcon))
    private lazy var loginItem = makeItem(#selector(toggleLaunchAtLogin))
    private lazy var settingsItem = makeItem(#selector(showSettings), keyEquivalent: ",")
    private lazy var quitItem = makeItem(#selector(NSApplication.terminate(_:)), target: NSApp, keyEquivalent: "q")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 两个实例会互相抢 Touch Bar，只留先启动的那个。
        if isAnotherInstanceRunning() {
            NSApp.terminate(nil)
            return
        }
        defaults.register(defaults: SettingsKey.defaults)
        settingsWindow.onDiagnose = { [weak self] in self?.showDiagnostics() }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        setupWarningItem.isHidden = true
        menu.addItem(setupWarningItem)
        menu.addItem(enabledItem)
        menu.addItem(pinnedItem)
        menu.addItem(centerIconsItem)
        menu.addItem(centerButtonItem)
        menu.addItem(hideDockIconItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)

        NSApp.mainMenu = makeMainMenu()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Touch Bar Dock")
        item.menu = menu
        statusItem = item

        applySettings()
        launched = true
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applySettings()
        }
        scheduleDisplayCheck()
    }

    /// 把保存的设置同步给 Dock。只在值真的变了才赋值，避免无谓的重绘。
    private func applySettings() {
        let showPinned = defaults.bool(forKey: Key.showPinned)
        if dock.showsPinnedApps != showPinned { dock.showsPinnedApps = showPinned }
        dock.doubleTapMinimizes = defaults.bool(forKey: Key.doubleTapMinimize)
        dock.yieldsToSystemCapture = defaults.bool(forKey: Key.yieldCapture)
        dock.yieldsToFunctionRow = defaults.bool(forKey: Key.yieldFunctionRow)
        dock.longPressDuration = TimeInterval(defaults.integer(forKey: Key.longPressSeconds))
        let theme = QuitHintTheme.saved
        if dock.quitHintTheme != theme {
            dock.quitHintTheme = theme
            // 换风格后立刻在 Touch Bar 上演示一遍，不用真的去长按一个 App。
            if launched { dock.previewQuitHint() }
        }
        let showCenter = defaults.bool(forKey: Key.showCenterButton)
        if dock.showsCenterButton != showCenter {
            dock.showsCenterButton = showCenter
            if launched, showCenter, !AppSwitcher.hasAccessibilityAccess { AppSwitcher.requestAccessibilityAccess() }
        }
        dock.centerHeightPercent = defaults.integer(forKey: Key.centerHeight)
        dock.centerWidthPercent = defaults.integer(forKey: Key.centerWidth)
        dock.pauseDuration = TimeInterval(defaults.integer(forKey: Key.hideSeconds))
        dock.iconSpacing = CGFloat(defaults.integer(forKey: Key.iconSpacing))
        dock.centersIcons = defaults.bool(forKey: Key.centerIcons)
        let hideDock = defaults.bool(forKey: Key.hideDockIcon)
        let targetPolicy: NSApplication.ActivationPolicy = hideDock ? .accessory : .regular
        if NSApp.activationPolicy() != targetPolicy {
            NSApp.setActivationPolicy(targetPolicy)
        }
        let enabled = defaults.bool(forKey: Key.enabled)
        if appliedEnabled != enabled {
            appliedEnabled = enabled
            applyEnabled()
        }
    }

    /// App 已经在运行时，再从「应用程序」或启动台打开它：弹出菜单栏菜单，方便开关和设置。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let button = statusItem?.button {
            button.performClick(nil)
        } else {
            showSettings()
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        dock.stop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshSetupWarning()
        let available = TouchBarBridge.isAvailable
        enabledItem.isEnabled = available
        enabledItem.title = available
            ? L10n.tr("在 Touch Bar 上显示 Dock", "Show Dock on Touch Bar")
            : L10n.tr("当前系统不支持（找不到 Touch Bar 接口）", "Not supported on this system (Touch Bar API not found)")
        enabledItem.state = available && defaults.bool(forKey: Key.enabled) ? .on : .off

        // 界面上是“只显示正在运行的 App”，存的仍是原来的 showPinned（取反），已有用户的设置不受影响。
        pinnedItem.title = L10n.tr("只显示正在运行的 App", "Only show running apps")
        pinnedItem.state = defaults.bool(forKey: Key.showPinned) ? .off : .on

        centerIconsItem.title = L10n.tr("图标居中显示", "Center the icons")
        centerIconsItem.state = defaults.bool(forKey: Key.centerIcons) ? .on : .off
        centerIconsItem.toolTip = L10n.tr("图标不多时居中；图标超出 Touch Bar 宽度时仍从左边开始滑动",
                                          "Centers the icons when they fit; once they overflow the Touch Bar they start from the left and scroll")

        centerButtonItem.title = L10n.tr("显示“窗口居中 / 最大化”按钮", "Show the center / maximize button")
        centerButtonItem.state = defaults.bool(forKey: Key.showCenterButton) ? .on : .off

        hideDockIconItem.title = L10n.tr("在程序坞中隐藏图标", "Hide icon in Dock")
        hideDockIconItem.state = defaults.bool(forKey: Key.hideDockIcon) ? .on : .off

        loginItem.title = L10n.tr("登录时自动启动", "Launch at login")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        settingsItem.title = L10n.tr("设置…", "Settings…")
        quitItem.title = L10n.tr("退出", "Quit \(AppInfo.name)")
        refreshMainMenuTitles()
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        defaults.set(!defaults.bool(forKey: Key.enabled), forKey: Key.enabled)
    }

    @objc private func togglePinned() {
        defaults.set(!defaults.bool(forKey: Key.showPinned), forKey: Key.showPinned)
    }

    @objc private func toggleCenterIcons() {
        defaults.set(!defaults.bool(forKey: Key.centerIcons), forKey: Key.centerIcons)
    }

    @objc private func toggleCenterButton() {
        defaults.set(!defaults.bool(forKey: Key.showCenterButton), forKey: Key.showCenterButton)
    }

    @objc private func toggleHideDockIcon() {
        defaults.set(!defaults.bool(forKey: Key.hideDockIcon), forKey: Key.hideDockIcon)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showAlert(L10n.tr("无法修改登录项", "Couldn't change the login item"),
                      "\(error.localizedDescription)\n\n"
                      + L10n.tr("先把 App 放进「应用程序」文件夹再试。", "Move the app to the Applications folder and try again."))
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }

    @objc private func showAbout() {
        settingsWindow.show(page: .about)
    }

    // MARK: - Touch Bar 显示自检与修复

    /// 启动后（以及系统设置被改动后）检查：显示模式是否会盖住 Dock，Dock 是否真的出现了。
    private func scheduleDisplayCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            self.runDisplayCheck()
            if TouchBarSetup.modeHidesDock, !self.defaults.bool(forKey: "setupPromptShown") {
                self.defaults.set(true, forKey: "setupPromptShown")
                self.fixTouchBarSetup()
            }
        }
    }

    private func runDisplayCheck() {
        let wanted = defaults.bool(forKey: Key.enabled) && TouchBarBridge.isAvailable
        dockFailedToShow = wanted && dock.isExpectedToShow && !dock.isDisplayed
        refreshSetupWarning()
    }

    private func refreshSetupWarning() {
        let modeProblem = TouchBarSetup.modeHidesDock && defaults.bool(forKey: Key.enabled)
        setupWarningItem.isHidden = !modeProblem
        setupWarningItem.title = L10n.tr("⚠︎ Touch Bar 正显示 F1–F12，Dock 无法出现 — 点此修复…",
                                         "⚠︎ Touch Bar is showing F1–F12, so the Dock can't appear — click to fix…")
        let warn = modeProblem || dockFailedToShow
        let name = warn ? "exclamationmark.triangle" : "dock.rectangle"
        statusItem?.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Touch Bar Dock")
    }

    @objc private func fixTouchBarSetup() {
        guard TouchBarSetup.modeHidesDock else { showDiagnostics(); return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n.tr("Touch Bar 被系统设为「显示 F1、F2 等键」",
                                    "Your Touch Bar is set to show F1, F2, etc. keys")
        alert.informativeText = L10n.tr(
            "这个设置会让整条 Touch Bar 被功能键占满，Dock 无法显示。\n\n可以改成「展开的控制条」（等同于 系统设置 → 键盘 → 触控栏显示）。改完后 F1–F12 不再默认显示，按住 Fn 键即可看到。之后想还原，在同一处改回即可（Dock 会随之失效）。",
            "That setting fills the whole Touch Bar with function keys, so the Dock can't appear.\n\nYou can switch it to “Expanded Control Strip” (same as System Settings → Keyboard → Touch Bar Shows). F1–F12 will no longer be shown by default; hold Fn to see them. To undo, change it back in the same place (the Dock will stop showing again).")
        alert.addButton(withTitle: L10n.tr("改为展开的控制条（推荐）", "Switch to Expanded Control Strip (recommended)"))
        alert.addButton(withTitle: L10n.tr("保持现状", "Keep as is"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if TouchBarSetup.applyWorkingMode() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                self.dock.stop()
                self.applyEnabled()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.runDisplayCheck() }
            }
        } else {
            showAlert(L10n.tr("修改失败", "Couldn't change the setting"),
                      L10n.tr("请手动打开 系统设置 → 键盘，把「触控栏显示」改为「展开的控制条」。",
                              "Open System Settings → Keyboard and set “Touch Bar Shows” to “Expanded Control Strip”."))
        }
    }

    private func diagnosticReport() -> (text: String, problems: Int) {
        var lines: [String] = []
        var problems = 0
        func row(_ ok: Bool, _ okText: String, _ badText: String) {
            lines.append((ok ? "✓ " : "✗ ") + (ok ? okText : badText))
            if !ok { problems += 1 }
        }
        // 机型名单可能不全：Dock 已经显示出来说明一定有 Touch Bar；名单里没有的机型只提示，不算问题。
        if TouchBarSetup.hasTouchBarHardware || dock.isDisplayed {
            lines.append("✓ " + L10n.tr("这台 Mac 带 Touch Bar（\(TouchBarSetup.hardwareModel)）", "This Mac has a Touch Bar (\(TouchBarSetup.hardwareModel))"))
        } else {
            lines.append("· " + L10n.tr("机型 \(TouchBarSetup.hardwareModel) 不在已知带 Touch Bar 的名单里（名单可能不全，若你的 Mac 有 Touch Bar 可忽略）",
                                       "Model \(TouchBarSetup.hardwareModel) isn't in the known Touch Bar list (the list may be incomplete; ignore if your Mac has one)"))
        }
        row(TouchBarBridge.isAvailable,
            L10n.tr("系统 Touch Bar 接口可用", "System Touch Bar API available"),
            L10n.tr("找不到系统 Touch Bar 接口（当前系统版本可能不支持）", "System Touch Bar API not found (this macOS version may be unsupported)"))
        row(!TouchBarSetup.modeHidesDock,
            L10n.tr("触控栏显示模式：\(TouchBarSetup.modeDescription)", "Touch Bar Shows: \(TouchBarSetup.modeDescription)"),
            L10n.tr("触控栏显示模式是「\(TouchBarSetup.modeDescription)」，会盖住 Dock → 菜单里点「修复」", "Touch Bar Shows is “\(TouchBarSetup.modeDescription)”, which covers the Dock → use Fix in the menu"))
        row(defaults.bool(forKey: Key.enabled),
            L10n.tr("「在 Touch Bar 上显示 Dock」已开启", "“Show Dock on Touch Bar” is on"),
            L10n.tr("「在 Touch Bar 上显示 Dock」被关闭了 → 在菜单里勾选", "“Show Dock on Touch Bar” is off → turn it on in the menu"))
        row(AppSwitcher.hasAccessibilityAccess,
            L10n.tr("辅助功能权限已开启", "Accessibility permission is on"),
            L10n.tr("辅助功能权限未开启（不影响显示，只影响窗口切换、居中、双击最小化等）", "Accessibility permission is off (doesn't affect display; affects window switching, centering, double-tap minimize)"))
        if dock.isExpectedToShow {
            row(dock.isDisplayed,
                L10n.tr("Dock 正显示在 Touch Bar 上", "The Dock is showing on the Touch Bar"),
                L10n.tr("Dock 应该显示却没有出现 → 先试「关闭再开启显示」，仍不行请把下面的信息反馈给开发者", "The Dock should be showing but isn't → toggle “Show Dock” off and on; if it persists, send this report to the developer"))
        } else {
            lines.append(L10n.tr("· Dock 当前处于临时让位状态（截图 / Fn / 咖啡杯）或已关闭", "· The Dock is currently yielding (screenshot / Fn / coffee cup) or turned off"))
        }
        lines.append("")
        lines.append("DockTouchBar \(AppInfo.version) (\(AppInfo.build)) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · \(TouchBarSetup.hardwareModel)")
        return (lines.joined(separator: "\n"), problems)
    }

    @objc private func showDiagnostics() {
        runDisplayCheck()
        let report = diagnosticReport()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = report.problems == 0
            ? L10n.tr("一切正常", "Everything looks fine")
            : L10n.tr("发现 \(report.problems) 个问题", "Found \(report.problems) issue(s)")
        alert.informativeText = report.text
        if TouchBarSetup.modeHidesDock { alert.addButton(withTitle: L10n.tr("修复显示模式…", "Fix display mode…")) }
        alert.addButton(withTitle: L10n.tr("复制诊断信息", "Copy report"))
        alert.addButton(withTitle: L10n.tr("关闭", "Close"))
        let response = alert.runModal()
        let offset = TouchBarSetup.modeHidesDock ? 1 : 0
        if offset == 1, response == .alertFirstButtonReturn {
            fixTouchBarSetup()
        } else if response == NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + offset) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report.text, forType: .string)
        }
    }

    // MARK: - 程序坞图标与主菜单

    private let mainAboutItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let mainQuitItem = NSMenuItem(title: "", action: nil, keyEquivalent: "q")

    /// 软件在程序坞里有图标之后，点它切到前台时顶部会出现系统菜单栏；放一个最小的应用菜单（关于、退出），
    /// 否则 ⌘Q 不起作用。
    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        mainAboutItem.action = #selector(showAbout)
        mainAboutItem.target = self
        mainQuitItem.action = #selector(NSApplication.terminate(_:))
        mainQuitItem.target = NSApp
        appMenu.addItem(mainAboutItem)
        appMenu.addItem(.separator())
        appMenu.addItem(mainQuitItem)
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        refreshMainMenuTitles()
        return mainMenu
    }

    private func refreshMainMenuTitles() {
        mainAboutItem.title = L10n.tr("关于 \(AppInfo.name)", "About \(AppInfo.name)")
        mainQuitItem.title = L10n.tr("退出 \(AppInfo.name)", "Quit \(AppInfo.name)")
    }

    // MARK: - Helpers

    private func applyEnabled() {
        let on = defaults.bool(forKey: Key.enabled) && TouchBarBridge.isAvailable
        if on { dock.start() } else { dock.stop() }
        statusItem?.button?.appearsDisabled = !on
    }

    /// 菜单项的标题在 `menuNeedsUpdate` 里按语言设置，这里只创建。
    private func makeItem(_ action: Selector, target: AnyObject? = nil, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: "", action: action, keyEquivalent: keyEquivalent)
        item.target = target ?? self
        return item
    }

    private func isAnotherInstanceRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0.processIdentifier != ownPID }
    }

    private func showAlert(_ title: String, _ message: String) {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

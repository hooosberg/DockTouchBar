import AppKit

/// 点 Touch Bar 图标后切到对应的 App。
///
/// 系统只在“用户点 Dock / 按 ⌘Tab”时自动切到 App 所在的桌面；后台 App 发起的激活只会让它变成前台，
/// 桌面不动（macOS 27 实测，`openApplication` 和 `NSRunningApplication.activate` 都一样）。
/// 所以当目标 App 在当前桌面没有窗口、但在别的桌面有窗口时，这里自己找到那个窗口：
/// 先用 SkyLight 把它设为前台窗口，再用辅助功能 Raise，系统随之切到那个桌面（和 AltTab 的做法相同）。
/// 找窗口有两个坑，都是实测出来的：
/// 1. 很多 App（比如 Chrome）在窗口列表里会排着一些看不见的辅助窗口（辅助功能里类型是 AXUnknown），
///    提前它们不会切桌面，所以要优先选类型正确的真实窗口；
/// 2. 按窗口号反查到的辅助功能元素，可能是窗口里面的子元素（比如访达返回的是里面的滚动区域），
///    对它 Raise 会失败，所以要先取到它所在的窗口。
/// 3. 系统切桌面有动画（这台机器上约半秒，机器卡或关掉动画时会变）。这期间读到的“当前桌面”和“屏幕上看得见的窗口”
///    还是旧的，连续快速点击时拿它们判断，第二下会误以为“已经在那个桌面了”而退回普通激活，不切桌面
///    （实测点击间隔 250ms 时 0/4 全错）。所以程序记住“刚刚请求系统去的桌面”，动画结束前以它为准。
/// 4. 动画进行中发出的第二次“切桌面”请求，系统会直接丢掉，接口却照样返回成功。不靠固定的等待时间，而是看结果：
///    发出请求后先看请求有没有被接受（目标 App 应该很快变成前台，实测 40–80ms，没有就是被丢了，马上重发），
///    再等系统“切完了”的官方信号（NSWorkspace.activeSpaceDidChangeNotification，动画结束时发出），并且自己
///    核对系统报告的桌面；下一次要切桌面的点击，如果上一次还没收到完成信号，也是等信号。
///    实测“切完了”的信号只比系统真正能接受新请求早一点点：信号后 8ms 发出的请求被丢过，所以不能只靠信号，
///    必须核对请求是否被接受。等的时候如果有更新的点击取代了它，就跳过。
/// 5. 系统偶尔会进入“不听话”的状态：请求被丢了、切到一半又被切回去、焦点被别的 App 抢走。所以点击处理完之后，
///    还要在一小段时间里持续核对最终结果（前台是不是目标 App、当前桌面上有没有它的窗口），不一致就重新纠正。
///    这只在用户没有动键盘鼠标、也没有更新的点击时才做，绝不去和用户争焦点。
/// 需要辅助功能权限；没有权限或任何一步失败，都退回普通的打开/激活。
enum AppSwitcher {
    /// 最多试几个候选窗口，以及总共最多花多久；候选没有真实窗口时，宁可退回普通激活，也不要拖住点击。
    private static let maxCandidates = 4
    private static let searchTimeLimit: TimeInterval = 1.5
    private static let queue = DispatchQueue(label: "com.maohuhu.docktouchbar.switcher", qos: .userInitiated)
    private static var didPromptForAccess = false

    /// 已经请求系统切过去、但还没确认“切完了”的桌面。只在 `queue` 上读写。
    private static var pendingSpace: (id: UInt64, since: Date)?
    /// 等系统“切完了”的最长时间。正常动画只要半秒左右，这只是兜底：机器很卡也够，请求被丢了也不会一直等。
    private static let spaceSwitchTimeout: TimeInterval = 1.6
    /// 请求发出后，等目标 App 变成前台的最长时间：被接受的请求实测 40–80ms 就会，超过这个就当作被系统丢了。
    private static let acceptTimeout: TimeInterval = 0.4
    /// 最多发几次请求（第一次 + 被丢了之后的重发），重发之间隔一小会儿，免得又落在系统还没准备好的那一刻。
    private static let maxRaiseAttempts = 3

    /// 点击之后盯着最终结果多久（从点击算起，包含约半秒的切桌面动画），多久核对一次，最多纠正几次。
    /// 异常（被抢焦点、被切回去）往往发生在动作完成之后一会儿，所以达成了也不提前结束，一直盯到窗口结束。
    private static let convergeWindow: TimeInterval = 2.4
    private static let convergeInterval: TimeInterval = 0.12
    private static let maxConvergeRetries = 3
    private static let retryBackoff: TimeInterval = 0.05
    /// 单次“提到最前面”的辅助功能调用最多等多久。系统正忙（比如刚好在切桌面动画的尾巴上）时它会一直不返回，
    /// 与其卡一秒多，不如快点失败、稍后重发（实测卡过 1.5 秒后失败）。
    private static let raiseCallTimeout: TimeInterval = 0.35

    /// 已经找到的窗口对应的辅助功能元素。按元素编号枚举很慢（动画期间实测 240ms），窗口不变元素就一直有效，缓存起来。
    /// 只在 `queue` 上读写；用的时候如果失败了就丢掉重新找。
    private static var elementCache: [CGWindowID: (pid: pid_t, element: AXUIElement)] = [:]

    /// 最近一次点击（主线程写，`queue` 上读），用来丢掉已经被后面另一个 App 的点击取代的旧点击。
    private static let clickLock = NSLock()
    private static var latestClick = (serial: 0, pid: pid_t(0))

    static func switchTo(_ tile: DockTile) {
        guard let url = tile.url else { return }
        let clickTime = Date()
        SpaceWatcher.start()
        let app = DockModel.runningApp(bundleID: tile.bundleID, url: url)
        let pid = app?.processIdentifier ?? 0
        clickLock.lock()
        latestClick = (latestClick.serial + 1, pid)
        let serial = latestClick.serial
        clickLock.unlock()
        guard let app, !app.isHidden else {
            launchOrActivate(url)
            return
        }
        // 辅助功能调用会跨进程等待目标 App 回应，放到后台，别卡住 Touch Bar。
        queue.async {
            // 连点时，前一个还没轮到的点击如果已经被另一个 App 的点击取代，就不用做了，直接去最后点的那个。
            if isSuperseded(serial: serial, pid: pid) { return }

            var switched = false
            if AXIsProcessTrusted() {
                let candidates = windowsToRaise(of: pid)
                if !candidates.isEmpty {
                    switched = raiseFirstRealWindow(pid: pid, candidates: candidates) { isSuperseded(serial: serial, pid: pid) }
                }
                if !switched { pendingSpace = nil }
            } else if !windowsOnOtherSpaces(of: pid).isEmpty {
                // 需要跨桌面才能看到窗口，但没有辅助功能权限：提示一次。
                DispatchQueue.main.async { promptForAccessOnce() }
            }
            if switched {
                converge(pid: pid, url: url, serial: serial, clickTime: clickTime)
            } else {
                DispatchQueue.main.async { launchOrActivate(url) }
            }
        }
    }

    /// 点击处理完之后盯着结果：最终状态和目标不一致（请求被丢了、被切回去、焦点被抢走）就重新纠正。
    /// 用户自己在动键盘鼠标、或者有更新的点击时立刻放弃，绝不和用户争。
    private static func converge(pid: pid_t, url: URL, serial: Int, clickTime: Date) {
        let deadline = clickTime.addingTimeInterval(convergeWindow)
        var retries = 0
        // 盯梢期间任何更新的点击（包括再点同一个 App）都立刻结束盯梢，让队列空出来：那次点击会自己处理自己的结果。
        let superseded = { isNewerClick(after: serial) }
        while Date() < deadline {
            if superseded() || userInput(since: clickTime) { return }
            if !isAchieved(pid: pid) {
                // 系统还在切桌面时不重发，等它切完再看。
                if pendingSpace == nil, retries < maxConvergeRetries {
                    retries += 1
                    let candidates = windowsToRaise(of: pid)
                    let redone = !candidates.isEmpty && raiseFirstRealWindow(pid: pid, candidates: candidates, superseded: superseded)
                    if !redone { DispatchQueue.main.async { launchOrActivate(url) } }
                }
            }
            // 睡一小会儿再核对；被更新的点击取代就立刻醒来。
            _ = SpaceWatcher.waitUntil(timeout: convergeInterval, poll: 0.02, superseded: superseded, { false })
        }
    }

    /// 现在的状态就是想要的吗：目标 App 在前台，并且它在当前桌面上有窗口（App 没有任何窗口时，在前台就够了）。
    private static func isAchieved(pid: pid_t) -> Bool {
        guard frontmostPID() == pid else { return false }
        guard let active = SkyLight.activeSpace() else { return true }
        let owned = normalWindows(of: pid, options: [.optionAll, .excludeDesktopElements])
            .map { SkyLight.spaces(of: $0) }
            .filter { !$0.isEmpty }
        return owned.isEmpty || owned.contains { $0.contains(active) }
    }

    /// 点击之后用户有没有动过键盘、鼠标、滚轮。程序自己激活 App、提前窗口不会算。
    private static func userInput(since time: Date) -> Bool {
        let types: [CGEventType] = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown,
                                    .mouseMoved, .leftMouseDragged, .scrollWheel]
        let idle = types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }.min() ?? .infinity
        return idle < Date().timeIntervalSince(time) - 0.05
    }

    /// 在这次点击之后有没有更新的点击（不管点的是哪个 App）。
    private static func isNewerClick(after serial: Int) -> Bool {
        clickLock.lock()
        defer { clickLock.unlock() }
        return latestClick.serial != serial
    }

    /// 这次点击是否已经被后面另一个 App 的点击取代（任何线程都可以调用）。
    private static func isSuperseded(serial: Int, pid: pid_t) -> Bool {
        clickLock.lock()
        defer { clickLock.unlock() }
        return latestClick.serial != serial && latestClick.pid != pid
    }

    /// 双击按目标窗口的黄色最小化按钮；台前调度下允许窗口被收进侧栏而 AXMinimized 仍为 false。
    /// 先取消第一下的切换纠正，否则它会把刚收起的窗口重新提回来。失败时说明原因，不隐藏整个 App。
    static func minimize(_ tile: DockTile, completion: @escaping (String?) -> Void) {
        // 垃圾桶：对象是访达里那个废纸篓窗口。
        let isTrash = tile.kind == .trash
        guard let url = tile.url,
              let app = isTrash ? TrashWindow.finderApp : DockModel.runningApp(bundleID: tile.bundleID, url: url) else { return }
        clickLock.lock()
        latestClick = (latestClick.serial + 1, -1)
        let serial = latestClick.serial
        clickLock.unlock()
        guard AXIsProcessTrusted() else {
            promptForAccessOnce()
            completion(L10n.tr("最小化窗口需要开启辅助功能权限", "Enable Accessibility to minimize windows"))
            return
        }
        queue.async {
            let superseded = { isNewerClick(after: serial) }
            func finish(_ message: String?) {
                DispatchQueue.main.async {
                    guard !superseded() else { return }
                    completion(message)
                }
            }
            // 第一下可能刚发出跨桌面或启动激活请求；等它到前台，随后才操作该 App 的窗口。
            guard case .reached = SpaceWatcher.waitUntil(timeout: 1.6, poll: 0.02, superseded: superseded, {
                frontmostPID() == app.processIdentifier
            }), !superseded() else {
                finish(L10n.tr("窗口还未切换完成，请再双击一次", "The window is still switching; double-tap again"))
                return
            }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, Float(raiseCallTimeout))
            func axElement(_ owner: AXUIElement, _ name: String) -> AXUIElement? {
                var value: CFTypeRef?
                guard AXUIElementCopyAttributeValue(owner, name as CFString, &value) == .success,
                      let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
                return (value as! AXUIElement)
            }
            var candidates: [AXUIElement] = []
            if isTrash {
                candidates = TrashWindow.windows() ?? []
            }
            for name in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] where !isTrash {
                if let candidate = axElement(element, name), let window = containingWindow(of: candidate) {
                    candidates.append(window)
                }
            }
            var windows: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
            if !isTrash { candidates += (windows as? [AXUIElement] ?? []) }
            guard let window = candidates.first(where: { isRealWindow($0, strict: true) }),
                  let button = axElement(window, kAXMinimizeButtonAttribute) else {
                finish(L10n.tr("这个 App 没有可最小化的窗口", "This app has no window to minimize"))
                return
            }
            AXUIElementSetMessagingTimeout(window, Float(raiseCallTimeout))
            AXUIElementSetMessagingTimeout(button, Float(raiseCallTimeout))
            var enabled: CFTypeRef?
            AXUIElementCopyAttributeValue(button, kAXEnabledAttribute as CFString, &enabled)
            guard enabled as? Bool != false else {
                finish(L10n.tr("这个窗口的最小化按钮不可用", "This window's minimize button is unavailable"))
                return
            }
            let windowID = AXPrivate.windowID(of: window)
            let wasOnScreen = windowID.map { isOnScreen($0, pid: app.processIdentifier) } ?? false
            func displayedFrame() -> CGRect? {
                guard let windowID,
                      let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
                      let info = list.first(where: { $0[kCGWindowNumber as String] as? CGWindowID == windowID }),
                      let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
                return CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0,
                              width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            }
            let originalFrame = displayedFrame()
            guard !superseded() else { return }
            guard AXUIElementPerformAction(button, kAXPressAction as CFString) == .success else {
                finish(L10n.tr("无法点击这个窗口的最小化按钮", "Couldn't press this window's minimize button"))
                return
            }
            let minimized = SpaceWatcher.waitUntil(timeout: 1.6, poll: 0.04, superseded: superseded, {
                var value: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value)
                if value as? Bool == true { return true }
                if wasOnScreen && windowID.map({ !isOnScreen($0, pid: app.processIdentifier) }) == true { return true }
                // 台前调度的侧栏缩略图仍属于“在屏”窗口，AXMinimized 也可能保持 false。
                // 用 WindowServer 实际显示的尺寸确认窗口已缩为缩略图，不能把“属性没变”误判为失败。
                if let originalFrame, let frame = displayedFrame() {
                    return frame.width < originalFrame.width * 0.6 && frame.height < originalFrame.height * 0.6
                }
                return false
            })
            finish(minimized == .reached ? nil : L10n.tr("窗口没有最小化", "The window didn't minimize"))
        }
    }

    static var hasAccessibilityAccess: Bool {
        AXIsProcessTrusted()
    }

    /// 这个 App 有没有打开的窗口：不管在哪个桌面、是否最小化、App 是否被隐藏。
    /// 给 `DockModel` 判断访达用：访达进程杀不掉、永远“在运行”，只有看它有没有窗口才知道是不是真的在用。
    ///
    /// 窗口全关以后，访达（备忘录等也一样）会留一个屏幕外的占位窗口（实测 64×64，固定在 (0,400)，
    /// 不属于任何桌面），`.optionAll` 会把它也列出来，所以只数个数不行。真实窗口都属于某个桌面；
    /// 最小化的窗口也不属于桌面，要靠辅助功能确认（没有权限时数不到，最小化的访达窗口不算在内）。
    static func hasOpenWindows(pid: pid_t) -> Bool {
        let windows = normalWindows(of: pid, options: [.optionAll, .excludeDesktopElements])
        guard !windows.isEmpty else { return false }
        guard SkyLight.isAvailable else { return true }
        if windows.contains(where: { !SkyLight.spaces(of: $0).isEmpty }) { return true }
        return hasMinimizedWindow(pid: pid)
    }

    /// 这个 App 有没有窗口显示在屏幕上（别的桌面上的、最小化的、被隐藏的都不算）。
    /// 用来区分“访达在前台，但窗口在别的桌面”（空桌面上访达会接管前台）和“窗口就摆在眼前”。
    static func hasVisibleWindows(pid: pid_t) -> Bool {
        !normalWindows(of: pid, options: [.optionOnScreenOnly, .excludeDesktopElements]).isEmpty
    }

    private static func hasMinimizedWindow(pid: pid_t) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let list = value as? [AXUIElement] else { return false }
        return list.contains {
            var minimized: CFTypeRef?
            return AXUIElementCopyAttributeValue($0, kAXMinimizedAttribute as CFString, &minimized) == .success
                && (minimized as? Bool) == true
        }
    }

    /// 弹出系统的“允许辅助功能”提示，并把本 App 加进 系统设置 → 隐私与安全性 → 辅助功能 的列表。
    /// 已经有权限就不弹，免得重复授权时一遍遍跳窗。
    static func requestAccessibilityAccess() {
        guard !AXIsProcessTrusted() else { return }
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// 第一次真正需要跨桌面切换时才提示，每次启动最多一次。
    private static func promptForAccessOnce() {
        guard !didPromptForAccess else { return }
        didPromptForAccess = true
        requestAccessibilityAccess()
    }

    /// 和点 Dock 一样走 LaunchServices：没开就启动，开着就切到前台（隐藏的会显示、最小化的会还原）。
    private static func launchOrActivate(_ url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                NSLog("DockTouchBar: 打开 %@ 失败：%@", url.path, error.localizedDescription)
            }
        }
    }

    // MARK: - 找窗口

    /// 以哪个桌面为“当前桌面”：刚请求过切桌面、还没确认切完时用请求的那个，否则用系统报告的。
    private static func effectiveSpace() -> UInt64? {
        let reported = SkyLight.activeSpace()
        if let pending = pendingSpace {
            if reported == pending.id || Date().timeIntervalSince(pending.since) > spaceSwitchTimeout * 2 {
                pendingSpace = nil   // 已经切完了，或者等太久了不再相信
            } else {
                return pending.id
            }
        }
        return reported
    }

    /// 这个 App 要提到最前面的候选窗口，按顺序：先是在“当前桌面”上的，再是在别的桌面上的（最小化的没有桌面，不算）。
    /// 只按窗口所属的桌面编号判断，不看“屏幕上看不看得见”，因为后者在切桌面动画期间是过期的。
    private static func windowsToRaise(of pid: pid_t) -> [CGWindowID] {
        guard SkyLight.isAvailable, let space = effectiveSpace() else { return [] }
        let owned = normalWindows(of: pid, options: [.optionAll, .excludeDesktopElements])
            .map { (window: $0, spaces: SkyLight.spaces(of: $0)) }
            .filter { !$0.spaces.isEmpty }
        return owned.filter { $0.spaces.contains(space) }.map(\.window) + owned.filter { !$0.spaces.contains(space) }.map(\.window)
    }

    /// 当前桌面上没有这个 App 的真实窗口时，按前后顺序返回它在各桌面上的候选窗口；已经有真实窗口就返回空。
    /// 候选里可能混着看不见的辅助窗口，要不要用由 `raiseFirstRealWindow` 逐个核实。
    private static func windowsOnOtherSpaces(of pid: pid_t) -> [CGWindowID] {
        guard SkyLight.isAvailable else { return [] }
        let visible = normalWindows(of: pid, options: [.optionOnScreenOnly, .excludeDesktopElements])
        // 当前桌面上看得见的“窗口”也可能是辅助窗口，不能因为它就认为已经有窗口了。
        // 没有辅助功能权限时没法核实，保持原来的判断。
        if !visible.isEmpty, !AXIsProcessTrusted() || hasRealWindow(among: visible, pid: pid) {
            return []
        }
        // 列表按前后顺序排列。最小化的窗口不属于任何桌面，跳过（交给 launchOrActivate 还原）。
        return normalWindows(of: pid, options: [.optionAll, .excludeDesktopElements])
            .filter { !SkyLight.spaces(of: $0).isEmpty }
    }

    /// `visible` 里有没有真实窗口。辅助功能查不到（超时、App 卡住）时按“有”处理，保持原来的行为。
    private static func hasRealWindow(among visible: [CGWindowID], pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 1)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success else { return true }
        let real = Set((value as? [AXUIElement] ?? []).filter { isRealWindow($0) }.compactMap { AXPrivate.windowID(of: $0) })
        return visible.contains { real.contains($0) }
    }

    /// 真实窗口：辅助功能里的类型是 AXWindow，并且没有最小化。
    /// `strict` 时还要求窗口类型是标准窗口、对话框这类；看不见的辅助窗口类型是 AXUnknown，只在宽松判断里算数。
    private static func isRealWindow(_ element: AXUIElement, strict: Bool = false) -> Bool {
        guard attribute(element, kAXRoleAttribute) == kAXWindowRole as String else { return false }
        if strict {
            let realSubroles: Set<String> = [kAXStandardWindowSubrole as String, kAXDialogSubrole as String,
                                             kAXSystemDialogSubrole as String, kAXFloatingWindowSubrole as String]
            guard let subrole = attribute(element, kAXSubroleAttribute), realSubroles.contains(subrole) else { return false }
        }
        var minimized: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &minimized)
        return minimized as? Bool != true
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value as? String
    }

    /// 元素本身是窗口就用它；否则取它所在的窗口（比如访达里查到的是窗口里的滚动区域）。
    private static func containingWindow(of element: AXUIElement) -> AXUIElement? {
        if attribute(element, kAXRoleAttribute) == kAXWindowRole as String { return element }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    /// 普通窗口：第 0 层、不透明、不是 App 用来占位的小窗口。
    private static func normalWindows(of pid: pid_t, options: CGWindowListOption) -> [CGWindowID] {
        let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard info[kCGWindowOwnerPID as String] as? pid_t == pid,
                  info[kCGWindowLayer as String] as? Int == 0,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  (bounds["Width"] ?? 0) > 50, (bounds["Height"] ?? 0) > 50 else { return nil }
            return info[kCGWindowNumber as String] as? CGWindowID
        }
    }

    // MARK: - 切过去

    /// 从候选里按顺序找到真实窗口并提到最前面；这个窗口提不上来，就试下一个。
    /// 先只认标准窗口、对话框这类；一个都没有时才放宽，免得类型特殊的 App 反而切不了。
    /// 返回 true 表示已经处理完（提到了最前面，或者等结果时被更新的点击取代而跳过），不需要再退回普通激活。
    private static func raiseFirstRealWindow(pid: pid_t, candidates: [CGWindowID], superseded: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(searchTimeLimit)
        let shortlist = Array(candidates.prefix(maxCandidates))
        for strict in [true, false] {
            for window in shortlist {
                guard Date() < deadline else { return false }
                guard let element = windowElement(pid: pid, window: window), isRealWindow(element, strict: strict) else { continue }
                if raise(window: window, pid: pid, superseded: superseded) { return true }
            }
        }
        return false
    }

    /// 取窗口对应的辅助功能元素：先看缓存，没有再去找。
    private static func windowElement(pid: pid_t, window: CGWindowID) -> AXUIElement? {
        if let cached = elementCache[window], cached.pid == pid { return cached.element }
        guard let element = axWindow(pid: pid, window: window) else { return nil }
        if elementCache.count > 64 { elementCache.removeAll() }
        elementCache[window] = (pid, element)
        return element
    }

    /// 把一个窗口提到最前面。窗口在别的桌面、需要真的切过去时，按“看结果”的办法确认切成功了再返回。
    private static func raise(window: CGWindowID, pid: pid_t, superseded: () -> Bool) -> Bool {
        let target = SkyLight.spaces(of: window).first
        // 没有正在进行的切换、窗口又已经在屏幕上（比如在另一块屏幕的当前桌面），就不需要切桌面。
        let needsSwitch = target != nil && target != effectiveSpace()
            && !(pendingSpace == nil && isOnScreen(window, pid: pid))
        guard needsSwitch, let target else {
            guard let element = windowElement(pid: pid, window: window) else { return false }
            if focus(pid: pid, window: window, element: element) { return true }
            elementCache[window] = nil   // 元素可能已经失效，下次重新找
            return false
        }
        // 上一次切桌面还没收到“切完了”的信号：先等信号，不是等固定时间。
        if let pending = pendingSpace {
            switch SpaceWatcher.waitUntil(timeout: spaceSwitchTimeout, poll: 0.05, superseded: superseded,
                                          { SkyLight.activeSpace() == pending.id }) {
            case .superseded: return true          // 留着 pendingSpace，更新的那次点击会自己去等
            case .reached, .timedOut: pendingSpace = nil
            }
        }
        let wasFront = frontmostPID() == pid
        for attempt in 0..<maxRaiseAttempts {
            if attempt > 0 { Thread.sleep(forTimeInterval: retryBackoff) }
            // 元素在缓存里失效了就重新找；请求发不出去多半是系统正忙，不是彻底失败，稍后重发。
            guard let element = windowElement(pid: pid, window: window),
                  focus(pid: pid, window: window, element: element) else {
                elementCache[window] = nil
                continue
            }
            pendingSpace = (target, Date())
            // 1) 请求被接受了吗：目标 App 很快会变成前台。没变，多半是系统在动画中把请求丢了，马上重发。
            //    （目标 App 本来就在前台时，这个检查说明不了什么，直接看第 2 步。）
            if !wasFront {
                switch SpaceWatcher.waitUntil(timeout: acceptTimeout, poll: 0.01, superseded: superseded,
                                              { frontmostPID() == pid || SkyLight.activeSpace() == target }) {
                case .superseded: return true
                case .timedOut: continue
                case .reached: break
                }
            }
            // 2) 等系统“切完了”。
            switch SpaceWatcher.waitUntil(timeout: spaceSwitchTimeout, poll: 0.05, superseded: superseded,
                                          { SkyLight.activeSpace() == target }) {
            case .reached: pendingSpace = nil; return true
            case .superseded: return true          // 更新的点击取代了它，让它接着处理，它会先等这次切完
            case .timedOut: continue
            }
        }
        pendingSpace = nil
        return false
    }

    /// 目前的前台 App（在主线程上读，`NSWorkspace` 的状态不保证能在后台线程读）。
    private static func frontmostPID() -> pid_t? {
        DispatchQueue.main.sync { NSWorkspace.shared.frontmostApplication?.processIdentifier }
    }

    private static func isOnScreen(_ window: CGWindowID, pid: pid_t) -> Bool {
        normalWindows(of: pid, options: [.optionOnScreenOnly, .excludeDesktopElements]).contains(window)
    }

    private static func focus(pid: pid_t, window: CGWindowID, element: AXUIElement) -> Bool {
        guard SkyLight.makeFront(pid: pid, window: window) else { return false }
        AXUIElementSetMessagingTimeout(element, Float(raiseCallTimeout))
        return AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
    }

    private static func axWindow(pid: pid_t, window: CGWindowID) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 1)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        // App 没有响应，就别再逐个试了。
        if result == .cannotComplete { return nil }
        for element in (value as? [AXUIElement]) ?? [] where AXPrivate.windowID(of: element) == window {
            return containingWindow(of: element) ?? element
        }
        // 标准接口只返回当前桌面的窗口；其他桌面的窗口要按元素编号逐个试（AltTab 同款做法，实测约 60–80ms）。
        for elementID in UInt64(0)..<1000 {
            guard let element = AXPrivate.element(pid: pid, elementID: elementID) else { continue }
            // 反查到的可能是窗口里的子元素，要取到窗口本身；取不到就继续找别的元素。
            if AXPrivate.windowID(of: element) == window, let windowElement = containingWindow(of: element) {
                return windowElement
            }
        }
        return nil
    }
}

// MARK: - “切完桌面了”的信号

/// 系统切完桌面的官方信号：`NSWorkspace.activeSpaceDidChangeNotification`（公开 API，动画结束时发出）。
/// 通知在主线程发，等待的一方在后台队列上：用信号量被通知唤醒，同时每 50ms 自己再核对一次系统报告的桌面，
/// 防止漏掉通知。
private enum SpaceWatcher {
    enum Outcome { case reached, timedOut, superseded }

    private static let signal = DispatchSemaphore(value: 0)
    private static var observer: NSObjectProtocol?

    /// 在主线程调用，重复调用无副作用。
    static func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in signal.signal() }
    }

    /// 等 `condition` 变成 true。等到了返回 `.reached`；超时返回 `.timedOut`；
    /// `superseded()` 变成 true（有更新的点击）立刻返回 `.superseded`。
    /// 被“切完桌面了”的通知唤醒最快；最多睡 `poll` 秒就自己再核对一次，所以不依赖通知一定送到。
    static func waitUntil(timeout: TimeInterval, poll: TimeInterval, superseded: () -> Bool,
                          _ condition: () -> Bool) -> Outcome {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() { return .reached }
            if superseded() { return .superseded }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { return .timedOut }
            _ = signal.wait(timeout: .now() + min(remaining, poll))
        }
    }
}

// MARK: - 私有接口（全部运行时解析，缺了就退回普通激活）

private enum SkyLight {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias CopySpacesFn = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias SetFrontFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> Int32
    private typealias PostEventFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> Int32
    private typealias GetPSNFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias ActiveSpaceFn = @convention(c) (Int32) -> UInt64

    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
    private static func symbol<T>(_ name: String, in lib: UnsafeMutableRawPointer?, as type: T.Type) -> T? {
        dlsym(lib, name).map { unsafeBitCast($0, to: type) }
    }

    private static let mainConnection = symbol("SLSMainConnectionID", in: handle, as: MainConnectionFn.self)
    private static let copySpaces = symbol("SLSCopySpacesForWindows", in: handle, as: CopySpacesFn.self)
    private static let activeSpaceFn = symbol("SLSGetActiveSpace", in: handle, as: ActiveSpaceFn.self)
    private static let setFront = symbol("_SLPSSetFrontProcessWithOptions", in: handle, as: SetFrontFn.self)
    private static let postEvent = symbol("SLPSPostEventRecordTo", in: handle, as: PostEventFn.self)
    private static let getPSN = symbol("GetProcessForPID", in: UnsafeMutableRawPointer(bitPattern: -2), as: GetPSNFn.self)

    static let isAvailable = mainConnection != nil && copySpaces != nil && setFront != nil && activeSpaceFn != nil
        && postEvent != nil && getPSN != nil && AXPrivate.isAvailable

    /// 窗口所在的桌面编号；最小化的窗口返回空。
    /// 系统报告的当前桌面（切桌面动画期间还是旧的，见 `AppSwitcher.effectiveSpace`）。
    static func activeSpace() -> UInt64? {
        guard let mainConnection, let activeSpaceFn else { return nil }
        return activeSpaceFn(mainConnection())
    }

    static func spaces(of window: CGWindowID) -> [UInt64] {
        guard let mainConnection, let copySpaces else { return [] }
        let allSpaces: Int32 = 0x7
        return copySpaces(mainConnection(), allSpaces, [window] as CFArray)?.takeRetainedValue() as? [UInt64] ?? []
    }

    static func makeFront(pid: pid_t, window: CGWindowID) -> Bool {
        guard let setFront, let postEvent, let getPSN else { return false }
        var psn = ProcessSerialNumber()
        let userGenerated: UInt32 = 0x200
        guard getPSN(pid, &psn) == noErr, setFront(&psn, window, userGenerated) == 0 else { return false }
        // 再发两条“设为关键窗口”的事件记录，键盘焦点才会落在这个窗口上。
        // 字节布局来自 Hammerspoon issue #370，AltTab 也在用。
        for type: UInt8 in [0x01, 0x02] {
            var record = [UInt8](repeating: 0, count: 0xf8)
            record[0x04] = 0xf8
            record[0x08] = type
            record[0x3a] = 0x10
            record.withUnsafeMutableBytes { raw in
                raw.storeBytes(of: window, toByteOffset: 0x3c, as: UInt32.self)
                for offset in 0x20..<0x30 { raw[offset] = 0xff }
            }
            _ = record.withUnsafeMutableBufferPointer { postEvent(&psn, $0.baseAddress!) }
        }
        return true
    }
}

private enum AXPrivate {
    private typealias GetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias CreateWithTokenFn = @convention(c) (CFData) -> Unmanaged<AXUIElement>?

    private static let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)  // RTLD_DEFAULT
    private static let getWindow = dlsym(defaultHandle, "_AXUIElementGetWindow")
        .map { unsafeBitCast($0, to: GetWindowFn.self) }
    private static let createWithToken = dlsym(defaultHandle, "_AXUIElementCreateWithRemoteToken")
        .map { unsafeBitCast($0, to: CreateWithTokenFn.self) }

    static let isAvailable = getWindow != nil && createWithToken != nil

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        guard let getWindow, getWindow(element, &id) == .success else { return nil }
        return id
    }

    /// 按编号直接构造某个 App 里的辅助功能元素（token = pid + 0 + "coco" + 元素编号）。
    static func element(pid: pid_t, elementID: UInt64) -> AXUIElement? {
        guard let createWithToken else { return nil }
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: pid) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f636f)) { Data($0) })
        token.replaceSubrange(12..<20, with: withUnsafeBytes(of: elementID) { Data($0) })
        return createWithToken(token as CFData)?.takeRetainedValue()
    }
}

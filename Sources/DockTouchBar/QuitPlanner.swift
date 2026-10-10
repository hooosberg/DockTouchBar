import AppKit
import ApplicationServices

/// 长按图标时做什么：先看这个 App 现在的样子，再决定，并且保证每次长按都有反馈，做不到的要说清楚。
///
/// 背景（苹果的机制）：`NSRunningApplication.terminate()` 只是“发出退出请求”，返回 true 不代表退出了，App 可以拒绝或者推迟：
/// 有未保存的文稿会弹出“要保存吗”，终端里有进程在跑会弹确认，这时 App 在后台等你回答，而你在 Touch Bar 上什么都看不到。
/// `forceTerminate()` 是直接杀进程，会丢数据，这里不用。访达不能被正常退出（默认没有“退出”菜单项）。
enum QuitPlan {
    /// 退出整个 App（等同 ⌘Q）。
    case quitApp
    /// 强制退出整个 App（等同 强制退出 / kill -9）。
    case forceQuitApp
    /// 关掉这个 App 的所有窗口（只用于访达：它退不了）。
    case closeWindow
    /// 访达的窗口都在别的桌面（辅助功能够不着）：先切到窗口那边，再把它们全关掉。
    case locateAndClose
    /// 隐藏整个 App（访达不在前面时，它退不了也没有窗口可关，只能藏起来）。
    case hideApp
    /// 关掉访达里的废纸篓窗口（垃圾桶图标的长按）。
    case closeTrash
    /// 什么也做不了，只说明情况。
    case notice(String)
}

/// 执行之后的结果。
enum QuitOutcome {
    /// 成功了（退出了 / 窗口关了 / 藏起来了）。
    case done
    /// App 在等你回答（弹出了“要保存吗”之类的确认框）。
    case needsAnswer
    /// 请求发出去了，App 还在，也没有看到确认框（可能在别的桌面，可能没有响应，可能拒绝退出）。
    case stillOpen
}

enum QuitPlanner {
    private static let finderID = "com.apple.finder"
    private static let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
    /// 发出请求后，等多久还没变化就当作“没成功”。退出整个 App 和只关窗口都用这个：
    /// App 退出前的收尾（写偏好设置、关子进程……）、关窗口的动画，都可能比这更慢，尤其是机器卡的时候；
    /// 等太短会把“其实办成了，只是慢”误判成“没办成”——退出场景下这只是提示文字说错话，
    /// 关窗口场景下还会因为接下来切回那个没了窗口的 App 而看着像“又开了一个”。
    private static let patience: TimeInterval = 2.6

    // MARK: - 决定做什么

    /// - 访达：退不了，目标是让它“看起来关了”——把所有窗口（包括最小化的）都关掉；当前桌面上有就直接关，
    ///   窗口都在别的桌面（辅助功能够不着）就先切过去再关；确实一个窗口都没有时说明情况。
    /// - 其他 App：一律退出整个 App，不管它有几个窗口、是在前台、被隐藏还是最小化了。
    static func plan(for app: NSRunningApplication) -> QuitPlan {
        guard app.bundleIdentifier != finderID else {
            if let count = closableWindows(of: app.processIdentifier)?.count, count > 0 { return .closeWindow }
            if AppSwitcher.hasOpenWindows(pid: app.processIdentifier) {
                return AXIsProcessTrusted() ? .locateAndClose : .hideApp
            }
            return .notice(L10n.tr("访达没有窗口，也不能退出", "Finder has no window and can't be quit"))
        }
        return .quitApp
    }

    // MARK: - 执行，并核对结果

    /// 执行 `plan`，最多等 `patience` 秒看结果，然后在主线程回调一次。
    static func perform(_ plan: QuitPlan, on app: NSRunningApplication, completion: @escaping (QuitOutcome) -> Void) {
        let pid = app.processIdentifier
        switch plan {
        case .notice:
            completion(.done)
        case .hideApp:
            _ = app.hide()
            completion(.done)
        case .quitApp:
            guard app.terminate() else { completion(.stillOpen); return }
            wait(until: { isGoneFromSight(app, pid: pid) }) { finished in
                completion(finished ? .done : (hasPendingDialog(pid) ? .needsAnswer : .stillOpen))
            }
        case .forceQuitApp:
            _ = app.forceTerminate()
            kill(pid, SIGKILL)
            wait(until: { isGoneFromSight(app, pid: pid) }) { finished in
                completion(finished ? .done : .stillOpen)
            }
        case .closeWindow:
            closeAllWindows(of: app, completion: completion)
        case .closeTrash:
            closeAllWindows(of: app, windows: TrashWindow.windows(), completion: completion)
        case .locateAndClose:
            // 和点图标一样把访达切到前台（会切到它窗口所在的桌面），等辅助功能看得到窗口了再关。
            AppSwitcher.switchTo(DockTile(kind: .app, url: finderURL, bundleID: finderID))
            wait(until: { (closableWindows(of: pid)?.count ?? 0) > 0 }) { found in
                if found { closeAllWindows(of: app, completion: completion) } else { completion(.stillOpen) }
            }
        }
    }

    /// 关掉所有窗口（含最小化的），和逐个点红色关闭按钮一样，有未保存内容会弹确认。
    private static func closeAllWindows(of app: NSRunningApplication, windows: [AXUIElement]? = nil,
                                        completion: @escaping (QuitOutcome) -> Void) {
        let pid = app.processIdentifier
        let closed = (windows ?? closableWindows(of: pid))?.compactMap(closeWindow) ?? []
        guard !closed.isEmpty else { completion(.stillOpen); return }
        wait(until: { app.isTerminated || closed.allSatisfy { !elementStillExists($0) } }) { finished in
            completion(finished ? .done : (hasPendingDialog(pid) ? .needsAnswer : .stillOpen))
        }
    }

    /// 每 0.2 秒看一次 `condition`，成了就立刻回调 true；等满 `patience` 秒还没成就回调 false。
    private static func wait(patience: TimeInterval = patience, until condition: @escaping () -> Bool, then done: @escaping (Bool) -> Void) {
        let deadline = Date().addingTimeInterval(patience)
        func check() {
            if condition() { done(true); return }
            if Date() >= deadline { done(false); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: check)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: check)
    }

    /// 退出这个 App 是不是已经在用户眼前发生了：真退出了；或者它把自己藏起来了（类似访达的隐藏兜底）；
    /// 或者当前桌面上已经没有它的标准窗口。不强求进程真的已经退出——有些 App（实测：企业 IM 一类）收到
    /// 退出请求后窗口立刻就没了，但后台还要花几十秒断开长连接、写本地缓存才真正退出进程，早就超出任何
    /// 合理的等待时间；对用户来说，窗口没了就是关掉了，不该因为它在后台收尾而被判定成“没关闭”。
    private static func isGoneFromSight(_ app: NSRunningApplication, pid: pid_t) -> Bool {
        app.isTerminated || app.isHidden || (closableWindows(of: pid)?.count ?? 0) == 0
    }

    // MARK: - 辅助功能

    /// 辅助功能能看到的窗口，最小化的、App 被隐藏时的也算（当前桌面之外的看不到）。没有权限或读不到时是 nil。
    /// 按角色（AXWindow）而不是子角色筛：访达点图标新开的窗口实测子角色是 AXDialog 而不是标准窗口，
    /// 只认标准窗口就会误判成“没有窗口可关”；访达的桌面元素角色是 AXScrollArea，不会混进来。
    private static func closableWindows(of pid: pid_t) -> [AXUIElement]? {
        allWindows(of: pid)?.filter { string($0, kAXRoleAttribute) == kAXWindowRole }
    }

    private static func allWindows(of pid: pid_t) -> [AXUIElement]? {
        guard AXIsProcessTrusted() else { return nil }
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }

    /// 有没有确认框：窗口上挂着“表单”（sheet，比如“要保存吗”），或者有独立的对话框窗口。
    private static func hasPendingDialog(_ pid: pid_t) -> Bool {
        for window in allWindows(of: pid) ?? [] {
            let subrole = string(window, kAXSubroleAttribute)
            if subrole == kAXDialogSubrole || subrole == kAXSystemDialogSubrole { return true }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &children) == .success,
               let list = children as? [AXUIElement],
               list.contains(where: { string($0, kAXRoleAttribute) == kAXSheetRole }) { return true }
        }
        return false
    }

    /// 按下这个窗口的红色关闭按钮。成功时原样返回窗口元素，用来之后核对它是不是真的没了（`elementStillExists`）。
    private static func closeWindow(_ window: AXUIElement) -> AXUIElement? {
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &button) == .success,
              let b = button, CFGetTypeID(b) == AXUIElementGetTypeID() else { return nil }
        guard AXUIElementPerformAction(b as! AXUIElement, kAXPressAction as CFString) == .success else { return nil }
        return window
    }

    /// 这个窗口元素是不是还在：关掉的窗口再去读它的属性，系统会报“元素无效”。
    /// 读不出结果（App 卡住、超时）时按“还在”处理，交给窗口数量那条线索兜底。
    private static func elementStillExists(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &value) != .invalidUIElement
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value as? String : nil
    }

    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value as? Bool : nil
    }
}

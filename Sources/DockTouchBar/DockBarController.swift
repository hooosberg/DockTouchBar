import AppKit

/// Touch Bar 上的那条 Dock：显示、刷新、点击/双击/长按，以及被系统收回后自动挂回去。
final class DockBarController: NSObject {
    private enum Metrics {
        /// 40pt 比原来的 36pt 宽一些，手指按下去不容易碰到旁边的图标；间距另外由 `iconSpacing` 控制。
        static let tileWidth: CGFloat = 40
        static let dividerWidth: CGFloat = 13
        /// 图标贴底、右上角留出空间给状态点，在保证状态点顶上边缘的前提下视觉最大化（约 28pt）。
        static let iconSize: CGFloat = {
            if let env = ProcessInfo.processInfo.environment["PREVIEW_ICON_SIZE"], let val = Double(env) {
                return CGFloat(val)
            }
            return 28
        }()
        /// Touch Bar 占满整条时可用宽度约 1004pt。
        static let maxDockWidth: CGFloat = 1000
        /// 最右侧固定的按钮（“咖啡杯”和“窗口居中”）的宽度，Dock 图标区不会画到它们下面。
        static let buttonWidth: CGFloat = 44
        /// 点咖啡杯时屏幕亮度低于这个值算“被调黑了”，回到 `brightnessRecovered` 以上才自动恢复。
        static let brightnessDark: Float = 0.08
        static let brightnessRecovered: Float = 0.15
        static let doubleTapInterval: TimeInterval = 0.35
        /// 按住多久开始显示“长按退出”的进度条；比这更短的按压都当作点击。
        static let pressArmDelay: TimeInterval = 0.35
        /// 按住后手指移动超过这个距离，当作在滑动，取消长按。
        static let pressMovementTolerance: CGFloat = 10
    }

    private static let controlStripBundleID = "com.apple.controlstrip"

    private let trayID = NSTouchBarItem.Identifier("com.maohuhu.docktouchbar.tray")
    private let dockID = NSTouchBarItem.Identifier("com.maohuhu.docktouchbar.dock")
    private let tileViewID = NSUserInterfaceItemIdentifier("tile")

    private let scrubber: NSScrubber
    private let scrubberWidth: NSLayoutConstraint
    private let scrubberLeading: NSLayoutConstraint
    private let flowLayout = NSScrubberFlowLayout()
    private let pressRecognizer = NSPressGestureRecognizer()
    /// 装着 Dock 和右侧“正在关闭”提示的容器；宽度固定为整条 Touch Bar，Dock 靠左，提示靠右边缘。
    private let container = NSView()
    private let quitHint = QuitHintView()
    /// 右侧的两个像素画按钮：咖啡杯（歇一会儿，把 Touch Bar 还给系统）在左，窗口居中在最右边。
    private let coffeeButton = PixelButton(frames: PixelIcon.coffee, cells: (13, 11), frameDuration: 0.4)
    private let centerButton = PixelButton(frames: PixelIcon.center.map { [$0] } ?? [], cells: (13, 11))
    private let quitHintLeading: NSLayoutConstraint
    /// 咖啡杯贴着居中按钮，或者（居中按钮隐藏时）贴着最右边。
    private let coffeeToCenter: NSLayoutConstraint
    private let coffeeToEdge: NSLayoutConstraint
    /// 图标区内容的宽度（不含右侧按钮），按钮显示/隐藏时据此重算图标区可用宽度。
    private var contentWidth: CGFloat = 0
    /// 暂停的原因可以叠加：截图/录屏结束时，不能打断用户自己点咖啡杯设置的暂停时间。
    private enum PauseReason: Hashable {
        case coffee
        case systemCapture
        case functionRow
    }
    private var pauseReasons = Set<PauseReason>()
    private var isPaused: Bool { !pauseReasons.isEmpty }
    /// 点“咖啡杯”后暂时隐藏多久（秒）；如果屏幕已经被调黑，则不看时间，等亮度回来。
    var pauseDuration: TimeInterval = 20
    private var pauseTimer: Timer?

    private lazy var touchBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [dockID]
        return bar
    }()

    /// 系统控制条里的入口按钮（Touch Bar 设为“App 控制”时可见，点一下重新显示 Dock）。
    private lazy var trayItem: NSCustomTouchBarItem = {
        let item = NSCustomTouchBarItem(identifier: trayID)
        let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: nil) ?? NSImage()
        item.view = NSButton(image: image, target: self, action: #selector(trayTapped))
        return item
    }()

    private var tiles: [DockTile] = []
    private var isActive = false
    private var reloadScheduled = false
    private var recoverScheduled = false
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var runningAppsObservation: NSKeyValueObservation?
    private var controlStripPID: pid_t?
    private let finderWindowMonitor = FinderWindowMonitor()
    private lazy var systemTouchBarActivity = SystemTouchBarActivityMonitor { [weak self] isActive in
        guard let self, self.yieldsToSystemCapture, self.isActive else { return }
        if isActive {
            self.beginPause(for: .systemCapture)
        } else {
            self.endPause(for: .systemCapture, present: true)
        }
    }
    private lazy var functionRowActivity = FunctionRowActivityMonitor { [weak self] isDown in
        guard let self, self.yieldsToFunctionRow, self.isActive else { return }
        if isDown {
            self.beginPause(for: .functionRow)
        } else {
            self.endPause(for: .functionRow, present: true)
        }
    }

    /// 正在进行的一次按压（从按住 `pressArmDelay` 秒开始，到松手结束）。
    private struct Press {
        let id = UUID()
        let index: Int
        let tile: DockTile
        let start: NSPoint
        var quitWork: DispatchWorkItem?
        var moved = false
        var completed = false
        var sawSelection = false
        /// 长按走满后要做的事，长按开始时就定好了。
        var plan = QuitPlan.quitApp
    }
    private var press: Press?
    private var suppressSelectionUntil = Date.distantPast
    /// 长按已经退出了 App、手指还没抬起。退出的如果是没固定的 App，它的图标会消失、列表重排，
    /// 按压记录随之作废；这个标记保证松手时不会误点到挪过来的相邻图标。
    private var swallowTapsUntilRelease = false
    private var lastTap: (tile: DockTile, time: Date)?

    var showsPinnedApps = true {
        didSet { if isActive { reload() } }
    }

    /// 图标之间的间距（pt）：越大，手指按在两个图标交界处时越不容易碰到旁边那个。默认 4pt。
    var iconSpacing: CGFloat = 4 {
        didSet {
            guard oldValue != iconSpacing else { return }
            flowLayout.itemSpacing = iconSpacing
            recomputeContentWidth()
            updateDockWidth()
            scrubber.reloadData()
        }
    }

    /// 图标不多、没占满图标区时是否居中显示；占满（要滑动）时本来就靠左，这个选项不起作用。
    var centersIcons = true {
        didSet { if oldValue != centersIcons { updateDockWidth() } }
    }

    /// 长按多少秒退出 App；0 表示不启用。
    var longPressDuration: TimeInterval = 3 {
        didSet { pressRecognizer.isEnabled = longPressDuration > 0 }
    }

    var doubleTapMinimizes = true
    var yieldsToSystemCapture = true {
        didSet { if oldValue != yieldsToSystemCapture { updateSystemCaptureAvoidance() } }
    }
    var yieldsToFunctionRow = true {
        didSet { if oldValue != yieldsToFunctionRow { updateFunctionRowAvoidance() } }
    }

    /// 长按退出提示的风格。
    var quitHintTheme = QuitHintTheme.spring {
        didSet { quitHint.theme = quitHintTheme }
    }
    private var quitHintPreview: DispatchWorkItem?

    /// “窗口居中 / 最大化”按钮：显示与否，以及居中后窗口的大小（0 = 宽度和高度一样，即正方形）。
    var showsCenterButton = true {
        didSet {
            centerButton.isHidden = !showsCenterButton
            updateWindowWatching()
            // 居中按钮不显示时，咖啡杯挪到最右边。
            if showsCenterButton {
                coffeeToEdge.isActive = false
                coffeeToCenter.isActive = true
            } else {
                coffeeToCenter.isActive = false
                coffeeToEdge.isActive = true
            }
            updateDockWidth()
        }
    }
    var centerHeightPercent = 80 {
        didSet { if oldValue != centerHeightPercent { refreshCenterIcon() } }
    }
    var centerWidthPercent = 0 {
        didSet { if oldValue != centerWidthPercent { refreshCenterIcon() } }
    }
    /// 按钮现在的图标，也就是再点一下会做什么：居中，或者（窗口已经是居中的样子时）最大化。
    private var windowAction = WindowPlacer.Action.center
    private let windowWatcher = WindowWatcher()

    override init() {
        let scrubber = NSScrubber()
        self.scrubber = scrubber
        self.scrubberWidth = scrubber.widthAnchor.constraint(equalToConstant: 0)
        self.scrubberLeading = scrubber.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        self.quitHintLeading = quitHint.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        // 和图标格间距一个道理：留个小缝，手指按在两个按钮交界处不会跟旁边那个撞在一起。
        self.coffeeToCenter = coffeeButton.trailingAnchor.constraint(equalTo: centerButton.leadingAnchor, constant: -2)
        self.coffeeToEdge = coffeeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        super.init()

        scrubber.dataSource = self
        scrubber.delegate = self
        scrubber.register(DockTileView.self, forItemIdentifier: tileViewID)
        scrubber.mode = .free
        // 选中态每次都立刻清掉（连续点同一个图标才能再次触发），点击反馈由 DockTileView.flash() 自己画。
        scrubber.selectionBackgroundStyle = nil
        scrubber.showsAdditionalContentIndicators = true
        flowLayout.itemSpacing = iconSpacing
        scrubber.scrubberLayout = flowLayout
        scrubberWidth.isActive = true

        container.translatesAutoresizingMaskIntoConstraints = false
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        quitHint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrubber)
        container.addSubview(coffeeButton)
        container.addSubview(centerButton)
        // 提示要盖在右侧两个按钮上面：只是个临时提示，让它顶到最边上。
        container.addSubview(quitHint)
        for button in [coffeeButton, centerButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.target = self
        }
        coffeeButton.action = #selector(coffeeTapped)
        coffeeButton.setAccessibilityLabel(L10n.tr("暂时隐藏 Dock", "Hide the Dock for a moment"))
        centerButton.action = #selector(centerTapped)
        centerButton.setAccessibilityLabel(L10n.tr("窗口居中", "Center the window"))
        windowWatcher.onChange = { [weak self] in self?.refreshCenterIcon() }
        finderWindowMonitor.onChange = { [weak self] in self?.scheduleReload() }
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: Metrics.maxDockWidth),
            container.heightAnchor.constraint(equalToConstant: 30),
            scrubberLeading,
            scrubber.topAnchor.constraint(equalTo: container.topAnchor),
            scrubber.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            centerButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            coffeeToCenter,
            coffeeButton.topAnchor.constraint(equalTo: container.topAnchor),
            coffeeButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            coffeeButton.widthAnchor.constraint(equalToConstant: Metrics.buttonWidth),
            centerButton.topAnchor.constraint(equalTo: container.topAnchor),
            centerButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            centerButton.widthAnchor.constraint(equalToConstant: Metrics.buttonWidth),
            quitHintLeading,
            quitHint.topAnchor.constraint(equalTo: container.topAnchor),
            quitHint.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            quitHint.widthAnchor.constraint(equalToConstant: QuitHintView.width),
        ])

        pressRecognizer.target = self
        pressRecognizer.action = #selector(handlePress(_:))
        pressRecognizer.allowedTouchTypes = .direct
        pressRecognizer.minimumPressDuration = Metrics.pressArmDelay
        pressRecognizer.allowableMovement = Metrics.pressMovementTolerance
        pressRecognizer.delegate = self
        scrubber.addGestureRecognizer(pressRecognizer)
    }

    // MARK: - 开启 / 关闭

    /// 自检用：Dock 此刻是否真的显示在 Touch Bar 上。
    var isDisplayed: Bool { touchBar.isVisible }
    /// 自检用：Dock 是否在运行且没有被临时让位（截图、Fn、咖啡杯）。
    var isExpectedToShow: Bool { isActive && !isPaused }

    func start() {
        guard !isActive, TouchBarBridge.isAvailable else { return }
        isActive = true
        swallowTapsUntilRelease = false
        TouchBarBridge.hideCloseBox()
        TouchBarBridge.addTrayItem(trayItem)
        controlStripPID = Self.currentControlStripPID()
        startObserving()
        updateSystemCaptureAvoidance()
        updateFunctionRowAvoidance()
        updateWindowWatching()
        finderWindowMonitor.watch(pid: DockModel.finderPID())
        reload()
        present()
        // 刚登录时系统的 Touch Bar 进程可能还没就绪，稍后再确认一次。
        presentAgainIfHidden(after: 2)
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        quitHintPreview?.cancel()
        cancelPress()
        stopObserving()
        systemTouchBarActivity.stop()
        functionRowActivity.stop()
        windowWatcher.stop()
        finderWindowMonitor.stop()
        clearPauses()
        TouchBarBridge.dismiss(touchBar)
        TouchBarBridge.removeTrayItem(trayItem)
    }

    // MARK: - 显示与恢复

    private func updateSystemCaptureAvoidance() {
        guard isActive else { return }
        if yieldsToSystemCapture {
            systemTouchBarActivity.start()
        } else {
            systemTouchBarActivity.stop()
            endPause(for: .systemCapture, present: true)
        }
    }

    private func updateFunctionRowAvoidance() {
        guard isActive else { return }
        if yieldsToFunctionRow {
            functionRowActivity.start()
        } else {
            functionRowActivity.stop()
            endPause(for: .functionRow, present: true)
        }
    }

    private func present() {
        guard isActive, !isPaused else { return }
        TouchBarBridge.present(touchBar, trayIdentifier: trayID)
    }

    /// 系统控制条里的入口按钮：暂停中就恢复，否则重新显示。
    @objc private func trayTapped() {
        systemTouchBarActivity.refreshCurrentState()
        functionRowActivity.refreshCurrentState()
        endPause(for: .coffee, present: false)
        present()
        presentAgainIfHidden(after: 1)
    }

    // MARK: - 临时暂停（兜底：屏幕被调黑时能用系统的亮度条）

    /// 点右侧的咖啡杯按钮：先把 Touch Bar 还给系统（亮度、音量都回来了），之后自动恢复：
    /// 暂停时屏幕已经是黑的，就等亮度回来；否则过一会儿自动恢复。中途亮度又被调黑，就一直等到亮起来。
    /// 第一下居中，再点一下最大化，再点又回到居中；窗口不是这两种样子（用户拖过、换了 App）就先居中。
    @objc private func centerTapped() {
        WindowPlacer.toggleFrontmost(heightPercent: centerHeightPercent, widthPercent: centerWidthPercent) { [weak self] in
            self?.setWindowAction($0)
        }
    }

    // MARK: - 让按钮的图标跟着窗口变

    /// 盯着最前面的 App 的窗口（移动、改大小、换窗口都会通知），图标随时对得上。切到自己（比如开着菜单）时保持原样。
    private func updateWindowWatching() {
        guard isActive, showsCenterButton else {
            windowWatcher.stop()
            return
        }
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            windowWatcher.watch(pid: app.processIdentifier)
        }
        refreshCenterIcon()
    }

    private func refreshCenterIcon() {
        guard isActive, showsCenterButton else { return }
        WindowPlacer.nextAction(heightPercent: centerHeightPercent, widthPercent: centerWidthPercent) { [weak self] in
            self?.setWindowAction($0)
        }
    }

    private func setWindowAction(_ action: WindowPlacer.Action) {
        guard action != windowAction else { return }
        windowAction = action
        let image = action == .maximize ? PixelIcon.maximize : PixelIcon.center
        centerButton.setFrames(image.map { [$0] } ?? [])
        centerButton.setAccessibilityLabel(action == .maximize ? L10n.tr("窗口最大化", "Maximize the window")
                                                                : L10n.tr("窗口居中", "Center the window"))
    }

    @objc private func coffeeTapped() {
        beginPause(for: .coffee)
    }

    private func beginPause(for reason: PauseReason) {
        guard isActive, !pauseReasons.contains(reason) else { return }
        let shouldDismiss = !isPaused
        pauseReasons.insert(reason)
        cancelPress()
        if shouldDismiss { TouchBarBridge.dismiss(touchBar) }
        guard reason == .coffee else { return }

        let wasDark = ScreenBrightness.current.map { $0 < Metrics.brightnessDark } ?? false
        let start = Date()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let brightness = ScreenBrightness.current
            let bright = brightness.map { $0 >= Metrics.brightnessRecovered } ?? true
            let waited = Date().timeIntervalSince(start) >= pauseDuration
            if bright && (wasDark || waited) { self.endPause(for: .coffee, present: true) }
        }
        RunLoop.main.add(timer, forMode: .common)
        pauseTimer = timer
    }

    private func endPause(for reason: PauseReason, present shouldPresent: Bool) {
        if reason == .coffee {
            pauseTimer?.invalidate()
            pauseTimer = nil
        }
        guard pauseReasons.remove(reason) != nil else { return }
        if shouldPresent, !isPaused {
            present()
            presentAgainIfHidden(after: 1)
        }
    }

    private func clearPauses() {
        pauseTimer?.invalidate()
        pauseTimer = nil
        pauseReasons.removeAll()
    }

    private func presentAgainIfHidden(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isActive, !self.touchBar.isVisible else { return }
            self.present()
        }
    }

    /// 睡眠唤醒、解锁、ControlStrip 重启之后系统会收回我们的 Touch Bar，这里重新挂上。
    /// 这几个事件经常一起到，合并成一次。
    private func recover(readdTray: Bool) {
        guard isActive, !recoverScheduled else { return }
        recoverScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.recoverScheduled = false
            guard self.isActive else { return }
            TouchBarBridge.hideCloseBox()
            if readdTray { TouchBarBridge.addTrayItem(self.trayItem) }
            self.present()
            self.presentAgainIfHidden(after: 2)
        }
    }

    // MARK: - 点击 / 双击

    /// 第一下立即切换；同一个图标在 `doubleTapInterval` 内再点一次就最小化当前窗口。
    private func handleTap(at index: Int) {
        guard tiles.indices.contains(index) else { return }
        let tile = tiles[index]
        guard tile.kind != .divider else { return }
        (scrubber.itemViewForItem(at: index) as? DockTileView)?.flash()
        let now = Date()
        if doubleTapMinimizes, let last = lastTap, last.tile.isSameSlot(as: tile),
           now.timeIntervalSince(last.time) < Metrics.doubleTapInterval {
            lastTap = nil
            AppSwitcher.minimize(tile) { [weak self] message in
                guard let self, let message else { return }
                self.quitHintLeading.constant = Metrics.maxDockWidth - QuitHintView.width
                self.quitHint.showResultNotice(message)
            }
        } else {
            lastTap = (tile, now)
            if tile.kind == .trash {
                // 垃圾桶：打开访达里的废纸篓窗口；窗口已经开着就提到前面。
                if let url = tile.url { NSWorkspace.shared.open(url) }
            } else {
                AppSwitcher.switchTo(tile)
            }
        }
    }

    // MARK: - 长按退出

    @objc private func handlePress(_ recognizer: NSPressGestureRecognizer) {
        let point = recognizer.location(in: scrubber)
        switch recognizer.state {
        case .began:
            beginPress(at: point)
        case .changed:
            guard var current = press, !current.moved, !current.completed else { return }
            if hypot(point.x - current.start.x, point.y - current.start.y) > Metrics.pressMovementTolerance {
                // 手指滑开了，是在滚动列表。
                current.moved = true
                press = current
                stopPressProgress()
            }
        case .ended:
            endPress()
            finishSwallowingTaps()
        case .cancelled, .failed:
            cancelPress()
            finishSwallowingTaps()
        default:
            break
        }
    }

    /// 手指抬起后，再忽略 0.3 秒内的选中回调（它可能比手势结束晚一点到）。
    private func finishSwallowingTaps() {
        guard swallowTapsUntilRelease else { return }
        swallowTapsUntilRelease = false
        suppressSelectionUntil = Date().addingTimeInterval(0.3)
    }

    private func beginPress(at point: NSPoint) {
        quitHintPreview?.cancel()
        cancelPress()
        guard let index = tileIndex(at: point) else { return }
        let tile = tiles[index]
        var newPress = Press(index: index, tile: tile, start: point)
        lastTap = nil
        // 没在运行的没什么可退出的，松手后照常当作点击（启动它）。
        // 不看缓存的 tile.isRunning——访达窗口开关不会触发刷新，缓存值随时可能是旧的；这里现查一次真实状态。
        if longPressDuration > 0, tile.kind == .app, let url = tile.url,
           let app = DockModel.runningApp(bundleID: tile.bundleID, url: url), DockModel.isActuallyRunning(app) {
            let name = app.localizedName ?? url.deletingPathExtension().lastPathComponent
            let isOptionDown = NSEvent.modifierFlags.contains(.option)
            let plan: QuitPlan
            if isOptionDown, app.bundleIdentifier != "com.apple.finder" {
                plan = .forceQuitApp
            } else {
                plan = QuitPlanner.plan(for: app)
            }
            newPress.plan = plan
            if case .notice(let message) = plan {
                // 做不了：直接说明情况，这次长按不再当作点击。
                newPress.completed = true
                swallowTapsUntilRelease = true
                showQuitNotice(forItemAt: index, message: message, appName: name)
            } else {
                let remaining = max(longPressDuration - Metrics.pressArmDelay, 0.1)
                let work = DispatchWorkItem { [weak self] in self?.completePress() }
                newPress.quitWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
                (scrubber.itemViewForItem(at: index) as? DockTileView)?.showPressed()
                switch plan {
                case .forceQuitApp: quitHint.action = .forceQuit
                case .closeWindow, .locateAndClose: quitHint.action = .closeWindow
                case .hideApp: quitHint.action = .hide
                default: quitHint.action = .quit
                }
                showQuitHint(forItemAt: index, appName: name, duration: remaining)
            }
        }
        // 垃圾桶：废纸篓窗口开着时，长按关掉它（只关这一个窗口，不动访达的其他窗口）。
        if longPressDuration > 0, tile.kind == .trash, TrashWindow.isOpen {
            newPress.plan = .closeTrash
            let remaining = max(longPressDuration - Metrics.pressArmDelay, 0.1)
            let work = DispatchWorkItem { [weak self] in self?.completePress() }
            newPress.quitWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
            (scrubber.itemViewForItem(at: index) as? DockTileView)?.showPressed()
            quitHint.action = .closeWindow
            showQuitHint(forItemAt: index, appName: L10n.tr("垃圾桶", "Trash"), duration: remaining)
        }
        press = newPress
    }

    /// 只显示一句话的提示（做不了的事）。位置规则和倒计时提示一样。
    private func showQuitNotice(forItemAt index: Int, message: String, appName: String) {
        let tileMid = scrubber.itemViewForItem(at: index).map { container.convert($0.bounds, from: $0).midX } ?? 0
        let onLeft = tileMid > Metrics.maxDockWidth / 2
        quitHintLeading.constant = onLeft ? 0 : Metrics.maxDockWidth - QuitHintView.width
        quitHint.showNotice(message, appName: appName, onLeft: onLeft)
    }

    /// 在菜单里换了风格后，在 Touch Bar 上演示一遍长按提示（走一个 2.5 秒的倒计时）。
    func previewQuitHint() {
        guard isActive, !isPaused, press == nil else { return }
        quitHintPreview?.cancel()
        let duration: TimeInterval = 2.5
        quitHintLeading.constant = Metrics.maxDockWidth - QuitHintView.width
        quitHint.show(appName: AppInfo.name, duration: duration, onLeft: false)
        let work = DispatchWorkItem { [weak self] in self?.quitHint.hide(completed: true) }
        quitHintPreview = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// 提示默认贴 Touch Bar 最右边（盖住右侧的按钮）；手指按在右半边的图标上时放到最左边，免得挡住正在按的图标。
    func showQuitHint(forItemAt index: Int, appName: String, duration: TimeInterval, progress: CGFloat? = nil) {
        let tileMid = scrubber.itemViewForItem(at: index).map { container.convert($0.bounds, from: $0).midX } ?? 0
        let onLeft = tileMid > Metrics.maxDockWidth / 2
        quitHintLeading.constant = onLeft ? 0 : Metrics.maxDockWidth - QuitHintView.width
        if let progress {
            container.layoutSubtreeIfNeeded()
            quitHint.freeze(progress: progress, appName: appName, onLeft: onLeft)
        } else {
            quitHint.show(appName: appName, duration: duration, onLeft: onLeft)
        }
    }

    private func completePress() {
        guard var current = press, !current.moved, !current.completed else { return }
        current.completed = true
        current.quitWork = nil
        press = current
        swallowTapsUntilRelease = true
        (scrubber.itemViewForItem(at: current.index) as? DockTileView)?.hidePressed()
        let isTrash = current.tile.kind == .trash
        guard let url = current.tile.url,
              let app = isTrash ? TrashWindow.finderApp : DockModel.runningApp(bundleID: current.tile.bundleID, url: url) else {
            quitHint.hide(completed: true)
            return
        }
        let name = isTrash ? L10n.tr("垃圾桶", "Trash") : app.localizedName ?? url.deletingPathExtension().lastPathComponent
        let tile = current.tile
        // 动作发出去以后，看结果再决定怎么收尾：成功了放结尾动画；App 在等你确认时切到它那边，让你亲眼看到、能去回答；
        // 单纯没等到变化（可能已经关了，只是比耐心等的时间慢，也可能是真的没响应）就只说明情况，不切过去——
        // 切过去等于激活它，窗口都关完了的 App 一激活常常会自己弹一个新窗口，看起来就像“没关又开了一个”，
        // 其实是我们等得不够久，误会了它。
        var planToExecute = current.plan
        if NSEvent.modifierFlags.contains(.option), current.tile.kind == .app, app.bundleIdentifier != "com.apple.finder" {
            planToExecute = .forceQuitApp
            quitHint.action = .forceQuit
        }

        quitHint.holdForResult()
        QuitPlanner.perform(planToExecute, on: app) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .done:
                self.quitHint.hide(completed: true)
            case .needsAnswer:
                if !isTrash { AppSwitcher.switchTo(tile) }
                self.quitHint.showResultNotice(L10n.tr("\(name) 在等你确认，已切换过去", "\(name) needs your answer — switched to it"))
            case .stillOpen:
                self.quitHint.showResultNotice(L10n.tr("\(name) 还没有关闭", "\(name) hasn't closed"))
            }
        }
    }

    /// 松手：长按已完成就吞掉这次点击；没到时间又没滑动，就当作一次普通点击。
    private func endPress() {
        guard let current = press else { return }
        stopPressProgress()
        if current.completed {
            press = nil
            return
        }
        // 松手时 NSScrubber 可能照常回调 didSelect，也可能因为手势已识别而不回调；
        // 稍等一下，没收到回调就自己补一次点击。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let active = self.press, active.id == current.id else { return }
            self.press = nil
            if !active.moved && !active.sawSelection {
                self.handleTap(at: active.index)
            }
        }
    }

    private func cancelPress() {
        stopPressProgress()
        press = nil
    }

    private func stopPressProgress() {
        quitHint.hide()
        guard let current = press else { return }
        current.quitWork?.cancel()
        press?.quitWork = nil
        (scrubber.itemViewForItem(at: current.index) as? DockTileView)?.hidePressed()
    }

    private func tileIndex(at point: NSPoint) -> Int? {
        tiles.indices.first { index in
            guard let view = scrubber.itemViewForItem(at: index) else { return false }
            return view.bounds.contains(view.convert(point, from: scrubber))
        }
    }

    // MARK: - 监听系统事件

    private func startObserving() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didActivateApplicationNotification) {
            $0.scheduleReload()
            $0.updateWindowWatching()
        }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.finderWindowMonitor.spaceDidChange() }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.recover(readdTray: false) }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.recover(readdTray: false) }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.recover(readdTray: false) }
        observe(DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsUnlocked")) {
            $0.recover(readdTray: false)
        }
        // App 启动/退出都会改这个列表，ControlStrip 进程重启也会反映在这里。
        runningAppsObservation = NSWorkspace.shared.observe(\.runningApplications) { [weak self] _, _ in
            DispatchQueue.main.async { self?.runningApplicationsChanged() }
        }
    }

    private func stopObserving() {
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        runningAppsObservation = nil
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ handler: @escaping (DockBarController) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            if let self { handler(self) }
        }
        observers.append((center, token))
    }

    private func runningApplicationsChanged() {
        guard isActive else { return }
        let pid = Self.currentControlStripPID()
        if let pid, pid != controlStripPID {
            // ControlStrip 崩溃或被重启过，入口按钮和 Dock 都要重新挂上。
            recover(readdTray: true)
        }
        controlStripPID = pid
        // 访达一般不会重启；万一崩溃重启了，PID 会变，得重新盯着新的进程（PID 没变时这一句什么也不做）。
        finderWindowMonitor.watch(pid: DockModel.finderPID())
        scheduleReload()
    }

    private static func currentControlStripPID() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: controlStripBundleID).first?.processIdentifier
    }

    // MARK: - 刷新图标

    private func scheduleReload() {
        guard !reloadScheduled else { return }
        reloadScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.reloadScheduled = false
            self?.reload()
        }
    }

    /// 不是 private：tools/render-preview 用它填充列表做离屏预览，而不必把 Dock 挂到 Touch Bar 上。
    func reload() {
        let newTiles = DockModel.tiles(includePinned: showsPinnedApps)
        guard newTiles != tiles else { return }
        let oldTiles = tiles
        let sameSlots = newTiles.count == tiles.count
            && zip(newTiles, tiles).allSatisfy { $0.isSameSlot(as: $1) }
        if sameSlots {
            tiles = newTiles
            // 位置没变、只是运行/前台状态变了：原地刷新每个图标的状态点和亮暗，不重排列表、不打断滚动位置。
            for (index, tile) in tiles.enumerated() {
                (scrubber.itemViewForItem(at: index) as? DockTileView)?.configure(with: tile, iconSize: Metrics.iconSize)
            }
        } else {
            let revealNewApp = !oldTiles.isEmpty && newTiles.contains { tile in
                tile.isTemporary && !oldTiles.contains { $0.isSameSlot(as: tile) }
            }
            let visibleRect = flowLayout.visibleRect
            // 记住左侧可见的、刷新后仍存在的图标；它被关掉时改用旁边的图标。
            let visibleIndexes = oldTiles.indices.filter { index in
                flowLayout.layoutAttributesForItem(at: index)?.frame.intersects(visibleRect) == true
            }
            let anchor = visibleIndexes.compactMap { index -> DockTile? in
                let tile = oldTiles[index]
                return newTiles.contains { $0.isSameSlot(as: tile) } ? tile : nil
            }.first
            // 图标位置变了，按压记录的序号已经不对，直接作废。
            cancelPress()
            lastTap = nil
            // NSScrubber 的批量操作按数组顺序执行；只增删/移动变化的项，避免 reloadData 归零滚动位置。
            scrubber.performSequentialBatchUpdates {
                for index in tiles.indices.reversed() where !newTiles.contains(where: { tiles[index].isSameSlot(as: $0) }) {
                    tiles.remove(at: index)
                    scrubber.removeItems(at: IndexSet(integer: index))
                }
                for (index, tile) in newTiles.enumerated() {
                    if index < tiles.count, tiles[index].isSameSlot(as: tile) { continue }
                    if let previous = tiles.indices.dropFirst(index).first(where: { tiles[$0].isSameSlot(as: tile) }) {
                        let moved = tiles.remove(at: previous)
                        tiles.insert(moved, at: index)
                        scrubber.moveItem(at: previous, to: index)
                    } else {
                        tiles.insert(tile, at: index)
                        scrubber.insertItems(at: IndexSet(integer: index))
                    }
                }
                // 防御重复分隔项或未来新增的重复槽位。
                while tiles.count > newTiles.count {
                    let index = tiles.count - 1
                    tiles.remove(at: index)
                    scrubber.removeItems(at: IndexSet(integer: index))
                }
                tiles = newTiles
                scrubber.selectedIndex = -1
            }
            recomputeContentWidth()
            updateDockWidth()
            container.layoutSubtreeIfNeeded()
            if !tiles.isEmpty && (revealNewApp || visibleRect.minX <= 0) {
                scrubber.scrollItem(at: 0, to: .leading)
            } else if let anchor, let index = tiles.firstIndex(where: { $0.isSameSlot(as: anchor) }) {
                scrubber.scrollItem(at: index, to: .leading)
            }
            for (index, tile) in tiles.enumerated() {
                (scrubber.itemViewForItem(at: index) as? DockTileView)?.configure(with: tile, iconSize: Metrics.iconSize)
            }
            removeStrayItemViews()
        }
    }

    /// NSScrubber 批量增删/移动之后，位置没变的图标（分隔线、垃圾桶）有时会把旧位置上的视图留在原地，
    /// 画面上就是“重影”，要等下一次整体刷新才消失。不属于任何当前位置的图标视图，一律清掉。
    private func removeStrayItemViews() {
        // 归属没错、位置还停在旧列表里的视图（批量移动后偶发）：让布局重算一遍。
        func misplaced() -> Bool {
            tiles.indices.contains { index in
                guard let view = scrubber.itemViewForItem(at: index),
                      let frame = scrubber.scrubberLayout.layoutAttributesForItem(at: index)?.frame else { return false }
                return abs(view.frame.minX - frame.minX) > 1
            }
        }
        if misplaced() {
            scrubber.scrubberLayout.invalidateLayout()
            scrubber.layoutSubtreeIfNeeded()
            if misplaced() { scrubber.reloadData() }
        }
        let owned = tiles.indices.compactMap { scrubber.itemViewForItem(at: $0) }
        func sweep(_ view: NSView) {
            for sub in view.subviews {
                if sub is DockTileView {
                    if !sub.isHidden, !owned.contains(where: { $0 === sub }) { sub.removeFromSuperview() }
                } else {
                    sweep(sub)
                }
            }
        }
        sweep(scrubber)
    }

    private func recomputeContentWidth() {
        let spacing = tiles.isEmpty ? 0 : CGFloat(tiles.count - 1) * iconSpacing
        contentWidth = tiles.reduce(0) { $0 + Self.width(of: $1) } + spacing
    }

    /// 右侧按钮占的宽度。
    private var buttonsWidth: CGFloat {
        Metrics.buttonWidth * (showsCenterButton ? 2 : 1)
    }

    private func updateDockWidth() {
        let available = Metrics.maxDockWidth - buttonsWidth
        scrubberWidth.constant = min(contentWidth, available)
        // 只有放得下才居中；放不下就是满宽、从最左开始滑动。
        scrubberLeading.constant = centersIcons && contentWidth < available ? ((available - contentWidth) / 2).rounded() : 0
    }

    private static func width(of tile: DockTile) -> CGFloat {
        tile.kind == .divider ? Metrics.dividerWidth : Metrics.tileWidth
    }
}

// MARK: - NSTouchBarDelegate

extension DockBarController: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == dockID else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = container
        return item
    }
}

// MARK: - NSGestureRecognizerDelegate

extension DockBarController: NSGestureRecognizerDelegate {
    /// 和 NSScrubber 自己的滑动、点击识别同时进行，不抢它的触摸。
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        true
    }
}

// MARK: - NSScrubber

extension DockBarController: NSScrubberDataSource, NSScrubberFlowLayoutDelegate {
    func numberOfItems(for scrubber: NSScrubber) -> Int {
        tiles.count
    }

    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let view = scrubber.makeItem(withIdentifier: tileViewID, owner: nil) as? DockTileView ?? DockTileView()
        view.configure(with: tiles[index], iconSize: Metrics.iconSize)
        return view
    }

    func scrubber(_ scrubber: NSScrubber, layout: NSScrubberFlowLayout, sizeForItemAt itemIndex: Int) -> NSSize {
        NSSize(width: Self.width(of: tiles[itemIndex]), height: 30)
    }

    func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
        // 立刻清掉选中态，否则连续点同一个图标（包括双击），第二下不会触发。
        DispatchQueue.main.async { scrubber.selectedIndex = -1 }
        if swallowTapsUntilRelease { return }
        if let current = press {
            press?.sawSelection = true
            // 长按已经退出了 App，松手这一下不再算点击。
            if current.completed { return }
        } else if Date() < suppressSelectionUntil {
            return
        }
        handleTap(at: selectedIndex)
    }
}

// MARK: - 单个图标

final class DockTileView: NSScrubberItemView {
    private let highlightLayer = CALayer()
    private let iconLayer = CALayer()
    /// 右上角状态点：红色＝当前激活（前台）App，未激活/未运行不显示。参考系统图标右上角的提示徽标位置。
    private let badgeLayer = CALayer()
    private let dividerLayer = CALayer()
    private var iconSize: CGFloat = 24
    /// 图形（裁掉留白之后）在 `iconLayer` 本地坐标系里的实际范围；状态点靠它定位，图标和点因此
    /// 天然是“一组”——图形换了大小或者比例，点跟着一起变，不用再单独调一遍像素。
    private var iconContentRect: CGRect?
    /// 长按变暗以后要恢复到的透明度：运行中的图标是 1，没运行（只是固定在栏里）的图标本来就暗一些。
    private var baseOpacity: Float = 1
    private static let badgeSize: CGFloat = {
        if let env = ProcessInfo.processInfo.environment["PREVIEW_BADGE_SIZE"], let val = Double(env) {
            return CGFloat(val)
        }
        return 7
    }()
    /// 状态点圆心压在图形右上角圆角轮廓线上（macOS Squircle 圆角在 45° 方向离顶角的内缩约为边长的 7.7%）。
    /// 图标和圆点作为整体排版：图标贴底（y=0），圆点顶到 Touch Bar 上边缘（y=30）。
    private static let badgeCornerPull: CGFloat = {
        if let env = ProcessInfo.processInfo.environment["PREVIEW_BADGE_PULL"], let val = Double(env) {
            return CGFloat(val)
        }
        return 0.08
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for sublayer in [highlightLayer, iconLayer, badgeLayer, dividerLayer] {
            sublayer.contentsScale = 2
            layer?.addSublayer(sublayer)
        }
        highlightLayer.backgroundColor = NSColor(white: 1, alpha: 0.25).cgColor
        highlightLayer.cornerRadius = 6
        highlightLayer.opacity = 0
        iconLayer.contentsGravity = .resizeAspect
        badgeLayer.cornerRadius = Self.badgeSize / 2
        badgeLayer.borderWidth = 1
        dividerLayer.backgroundColor = NSColor(white: 1, alpha: 0.3).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with tile: DockTile, iconSize: CGFloat) {
        self.iconSize = iconSize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        iconLayer.contents = tile.url.flatMap { IconCache.image(for: $0, pointSize: iconSize) }
        iconContentRect = tile.url.flatMap { IconCache.contentRect(for: $0, pointSize: iconSize) }
        iconLayer.isHidden = tile.kind == .divider
        // 没运行的 App（固定在栏里但还没启动）、没开着窗口的垃圾桶，图标暗一些，一眼能和运行中的分开，但不用暗到看不清图标本身。
        baseOpacity = tile.isRunning ? 1 : 0.6
        iconLayer.opacity = baseOpacity
        // 仅当前激活（前台）的应用显示右上角小红点；未运行应用已通过透明度区分，后台运行应用不需要灰色圆圈。
        badgeLayer.isHidden = tile.kind != .app || !tile.isFrontmost
        badgeLayer.backgroundColor = NSColor.systemRed.cgColor
        badgeLayer.borderColor = NSColor.white.cgColor
        dividerLayer.isHidden = tile.kind != .divider
        setAccessibilityLabel(tile.kind == .trash ? L10n.tr("垃圾桶", "Trash")
                              : tile.url?.deletingPathExtension().lastPathComponent)
        CATransaction.commit()
        needsLayout = true
    }

    /// 点击反馈：短暂高亮一下。
    func flash() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.duration = 0.25
        highlightLayer.add(animation, forKey: "flash")
    }

    /// 长按退出时把图标变暗一点，做个按下的反馈；倒计时本身已经在右侧的提示条上画出来了，这里不用再重复画一遍。
    func showPressed() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        iconLayer.opacity = 0.5
        badgeLayer.opacity = 0
        CATransaction.commit()
    }

    func hidePressed() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        iconLayer.opacity = baseOpacity
        badgeLayer.opacity = 1
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let b = bounds
        let iconX = (b.width - iconSize) / 2
        highlightLayer.frame = b.insetBy(dx: 2, dy: 0)
        // 图标底部贴边（y=0），与右侧按钮共用底边基线；顶部留出几个像素空间给右上角圆点。
        iconLayer.frame = CGRect(x: iconX, y: 0, width: iconSize, height: iconSize)
        // 状态点圆心压在图形自己的右上角圆角轮廓线上：
        // 图标贴底后，图形最高点即 glyph.maxY；圆点圆心在边线上，最高点顶到 Touch Bar 上边缘。
        let badgeSize = Self.badgeSize
        let glyph = iconContentRect ?? CGRect(x: 0, y: 0, width: iconSize, height: iconSize)
        let pull = min(glyph.width, glyph.height) * Self.badgeCornerPull
        let badgeCenterX = iconX + glyph.maxX - pull
        let badgeCenterY = glyph.maxY - pull
        badgeLayer.frame = CGRect(x: badgeCenterX - badgeSize / 2, y: badgeCenterY - badgeSize / 2,
                                  width: badgeSize, height: badgeSize)
        dividerLayer.frame = CGRect(x: (b.width - 1) / 2, y: (b.height - 18) / 2, width: 1, height: 18)
        CATransaction.commit()
    }
}

import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
var failures = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() { print("PASS \(message)") }
    else { print("FAIL \(message)"); failures += 1 }
}
func settle(_ seconds: Double = 0.6) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

let finderID = "com.apple.finder"
func finder(open: Bool) -> DockTile {
    DockTile(kind: .app, url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"), bundleID: finderID, isRunning: open)
}
func tile(_ n: Int, pinned: Bool = false) -> DockTile {
    DockTile(kind: .app, url: URL(fileURLWithPath: "/tmp/Layout-\(n).app"), bundleID: "test.\(n)", isRunning: true, isTemporary: !pinned)
}

// MARK: 1. 排列规则（纯函数）
let running = [tile(1), tile(2), tile(3)]
let onlyRunning = DockModel.arrange(base: [finder(open: true)], others: running, includePinned: false, trashOpen: true)
check(onlyRunning.first?.bundleID == finderID, "Running-only: Finder is the leftmost icon")
check(onlyRunning.dropFirst().prefix(3).map(\.bundleID) == running.map(\.bundleID), "Running-only: apps follow Finder in order")
check(!onlyRunning.contains { $0.bundleID == "temporary-apps" }, "Running-only: no temporary divider")
check(onlyRunning.suffix(2).map(\.kind) == [.divider, .trash], "Running-only: divider + trash at the end while the Trash window is open")
let closedTrash = DockModel.arrange(base: [finder(open: true)], others: running, includePinned: false, trashOpen: false)
check(!closedTrash.contains { $0.kind == .trash || $0.kind == .divider }, "Running-only: dimmed Trash (no window) and its divider disappear")
check(closedTrash.allSatisfy { $0.isRunning }, "Running-only: every remaining icon is a running (bright) one")
check(DockModel.arrange(base: [], others: [], includePinned: true, trashOpen: false).last?.kind == .trash, "Pinned mode: Trash always shown (dimmed when closed)")

let noFinder = DockModel.arrange(base: [], others: running, includePinned: false)
check(!noFinder.contains { $0.bundleID == finderID }, "Running-only: Finder hidden when it has no window")
check(noFinder.first?.bundleID == "test.1", "Running-only: first app is leftmost when Finder is hidden")
check(DockModel.arrange(base: [], others: [], includePinned: false).isEmpty, "Running-only: nothing running leaves an empty list")

let pinnedMode = DockModel.arrange(base: [finder(open: false), tile(9, pinned: true)], others: running, includePinned: true)
check(pinnedMode.first?.bundleID == "test.1" && pinnedMode.contains { $0.bundleID == "temporary-apps" },
      "Pinned mode unchanged: temporary apps on the left, divider, then Finder + pinned")
check(pinnedMode.contains { $0.bundleID == finderID && !$0.isRunning }, "Pinned mode: Finder stays even without windows")
check(DockModel.arrange(base: [], others: [], includePinned: true, trashOpen: true).last?.isRunning == true, "Trash tile carries open state")

// MARK: 2. 真实 NSScrubber：居中位置，切换模式后没有残留的旧图标
DockModel.previewTiles = []
let controller = DockBarController()
controller.reload()
let item = controller.touchBar(NSTouchBar(), makeItemForIdentifier: .init("com.maohuhu.docktouchbar.dock")) as! NSCustomTouchBarItem
let container = item.view
let scrubber = container.subviews.compactMap { $0 as? NSScrubber }.first!
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 30), styleMask: .borderless, backing: .buffered, defer: false)
let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 30))
window.contentView = root
root.addSubview(container)
NSLayoutConstraint.activate([container.leadingAnchor.constraint(equalTo: root.leadingAnchor),
                             container.topAnchor.constraint(equalTo: root.topAnchor)])
window.orderFrontRegardless()
root.layoutSubtreeIfNeeded()
settle()

func itemViews() -> [NSView] {
    func collect(_ v: NSView) -> [NSView] { v.subviews.flatMap { ($0 is DockTileView) ? [$0] : collect($0) } }
    return collect(scrubber)
}
/// 屏幕上每个图标视图都必须对应当前列表里的一个位置，且位置和布局一致；不能多出没人管的旧视图。
func assertClean(_ label: String) {
    container.layoutSubtreeIfNeeded()
    let expected = scrubber.numberOfItems
    let owned = (0..<expected).compactMap { scrubber.itemViewForItem(at: $0) }
    // 重影 = 画在屏幕上、却不属于任何当前位置的图标视图（复用池里藏起来的不算）。
    let ghosts = itemViews().filter { view in
        !owned.contains { $0 === view } && !view.isHidden && view.alphaValue > 0.01
            && view.frame.intersects(scrubber.bounds)
    }
    for g in ghosts { print("   ghost frame=\(g.frame) layer.opacity=\((g.layer?.opacity) ?? -1) label=\(g.accessibilityLabel() ?? "-") scrubberWidth=\(scrubber.frame.width)") }
    check(ghosts.isEmpty, "\(label): no ghost icons on screen (ghosts=\(ghosts.count))")
    let layout = scrubber.scrubberLayout
    let aligned = (0..<expected).allSatisfy { i in
        guard let v = scrubber.itemViewForItem(at: i), let attr = layout.layoutAttributesForItem(at: i) else { return true }
        return abs(v.frame.minX - attr.frame.minX) < 1
    }
    if !aligned { for i in 0..<expected { if let v = scrubber.itemViewForItem(at: i), let a = layout.layoutAttributesForItem(at: i) { print("   idx \(i) view=\(v.frame.minX) layout=\(a.frame.minX) visible=\(layout.visibleRect)") } } }
    check(aligned, "\(label): every icon sits where the layout says")
}
func show(_ tiles: [DockTile]) {
    DockModel.previewTiles = tiles
    controller.reload()
    settle()
}
func scrubberLeft() -> CGFloat { container.convert(scrubber.bounds, from: scrubber).minX }
func scrubberWidth() -> CGFloat { scrubber.frame.width }

// 少量图标：居中
controller.iconAlignment = .center
show([tile(1), tile(2), .divider, .trash])
let contentW = CGFloat(2) * 40 + 13 + 40 + 3 * controller.iconSpacing
let available: CGFloat = 1000 - 88
check(abs(scrubberWidth() - contentW) < 2, "Few icons: scrubber is exactly as wide as the icons")
check(abs(scrubberLeft() - (available - contentW) / 2) < 2, "Few icons: centered in the icon area (left=\(scrubberLeft()))")
assertClean("few icons centered")
controller.iconAlignment = .left
settle()
check(abs(scrubberLeft()) < 1, "Align left: starts from the left")
controller.iconAlignment = .right
settle()
check(abs(scrubberLeft() - (available - contentW)) < 2, "Align right: icons end at the right edge of the icon area (left=\(scrubberLeft()))")
assertClean("few icons right-aligned")
controller.iconAlignment = .center
settle()

// 图标超出宽度：靠左、满宽
show((0..<30).map { tile($0) } + [.divider, .trash])
check(abs(scrubberLeft()) < 1 && abs(scrubberWidth() - available) < 1, "Overflowing icons: left aligned, full width")
assertClean("overflowing")

// 反复切换“只显示运行中 / 显示固定”（少 ↔ 多），每次都不能有残留
for round in 1...4 {
    show([finder(open: true), tile(1), tile(2), .divider, .trash])
    assertClean("round \(round) running-only (5 icons)")
    show([tile(1), tile(2), .temporaryDivider, finder(open: false)] + (10..<24).map { tile($0, pinned: true) } + [.divider, .trash])
    assertClean("round \(round) pinned (22 icons)")
}
// 通过生产开关切换（走 showsPinnedApps 的 didSet）
DockModel.previewTiles = nil
print("RESULT failures=\(failures)")
exit(failures == 0 ? 0 : 1)

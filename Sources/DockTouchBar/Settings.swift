import Foundation

/// 设置项的存储键和可选挡位，菜单栏菜单和设置窗口共用。
enum SettingsKey {
    static let enabled = "enabled"
    static let showPinned = "showPinned"
    // 保留原来的存储键，继承已有用户是否启用双击的选择。
    static let doubleTapMinimize = "doubleTapHide"
    static let yieldCapture = "yieldSystemCapture"
    static let yieldFunctionRow = "yieldFunctionRow"
    static let longPressSeconds = "longPressSeconds"
    static let hideSeconds = "hideSeconds"
    static let showCenterButton = "showCenterButton"
    static let centerHeight = "centerHeightPercent"
    static let centerWidth = "centerWidthPercent"
    static let iconSpacing = "iconSpacing"
    static let centerIcons = "centerIcons"
    static let language = "language"
    static let agentStatus = "agentStatus"
    static let hideDockIcon = "hideDockIcon"
    static let iconAlignment = "iconAlignment"
    static let yieldRecheck = "yieldRecheckSeconds"

    static let defaults: [String: Any] = [
        enabled: true, showPinned: true, doubleTapMinimize: true, longPressSeconds: 3,
        yieldCapture: true, yieldFunctionRow: true, hideSeconds: 20, showCenterButton: true,
        centerHeight: 80, centerWidth: 0, iconSpacing: 4, centerIcons: true, agentStatus: true,
        hideDockIcon: false, yieldRecheck: 5,
    ]
}

/// 图标在 Touch Bar 上的位置（图标放得下时才生效，放不下就从最左开始滑动）。
/// 旧版本只有“居中”开关（centerIcons）：没存过 iconAlignment 时按它推出，已有用户的设置不变。
enum IconAlignment: String, CaseIterable {
    case left, center, right

    static func current(_ defaults: UserDefaults = .standard) -> IconAlignment {
        if let raw = defaults.string(forKey: SettingsKey.iconAlignment), let value = IconAlignment(rawValue: raw) { return value }
        return defaults.bool(forKey: SettingsKey.centerIcons) ? .center : .left
    }

    /// 同时写 centerIcons，保持旧开关和菜单栏的“图标居中显示”一致。
    static func set(_ value: IconAlignment, in defaults: UserDefaults = .standard) {
        defaults.set(value.rawValue, forKey: SettingsKey.iconAlignment)
        defaults.set(value == .center, forKey: SettingsKey.centerIcons)
    }
}

enum SettingsOptions {
    /// 避让系统工具（Fn、截图/录屏）后，每隔多少秒重新核对一次，系统工具已经结束就自动恢复（秒），0 = 不核对。
    static let recheck = [0, 3, 5, 10, 30]
    /// 长按退出 App 的可选时长（秒），0 = 不启用。
    static let longPress = [0, 1, 2, 3, 5]
    /// 点“咖啡杯”后临时隐藏 Dock 的可选时长（秒）。
    static let hide = [10, 20, 30, 60]
    /// 居中后窗口的高度（占屏幕可用高度的百分比）。
    static let height = [60, 70, 80, 90, 100]
    /// 居中后窗口的宽度：0 = 和高度一样（正方形），其余是占屏幕可用宽度的百分比。
    static let width = [0, 50, 60, 70, 80, 90, 100]
    /// 图标之间的间距（pt）。
    static let spacing = [0, 2, 4, 6, 8]
}

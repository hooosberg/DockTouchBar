import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 根据用户设置决定是否在程序坞显示图标：隐藏后仍常驻后台运行并保留菜单栏图标。
let hideDockIcon = UserDefaults.standard.bool(forKey: SettingsKey.hideDockIcon)
app.setActivationPolicy(hideDockIcon ? .accessory : .regular)
app.run()

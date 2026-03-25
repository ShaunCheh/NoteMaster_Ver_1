20260324_221407_app_entry_force_light_mode

# 应用入口统一锁浅色修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- 未修改 `NoteMaster-Ver-1-Info.plist`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### iOS 应用入口没有统一锁定浅色外观

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名：application(_:didFinishLaunchingWithOptions:)
// 功能说明：修改前 iOS 入口只负责创建主窗口并挂载根控制器；
// 没有在应用入口统一锁定界面外观，因此项目里使用 `.systemBackground`、`.label` 等语义色的界面会跟随系统进入深色分支。
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    MusicFontRegistry.bootstrapIfNeeded()

    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = iOSViewController()
    window.backgroundColor = .white
    window.makeKeyAndVisible()
    self.window = window
    return true
}
```

### macOS 应用入口没有统一锁定 Aqua 浅色外观

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名：applicationDidFinishLaunching(_:)
// 功能说明：修改前 macOS 入口直接创建窗口并激活应用；
// 没有在应用级别指定 `.aqua` 外观，因此项目里依赖 `NSColor.windowBackgroundColor`、`NSColor.controlBackgroundColor` 的界面会跟随系统深浅模式变化。
func applicationDidFinishLaunching(_ notification: Notification) {
    MusicFontRegistry.bootstrapIfNeeded()

    let viewController = macOSViewController()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.contentMinSize = NSSize(width: 640, height: 420)
    window.title = "NoteMaster_Ver_1"
    window.center()
    window.contentViewController = viewController
    window.makeKeyAndOrderFront(nil)

    NSApp.activate(ignoringOtherApps: true)
    self.window = window
}
```

## 修改后

### iOS 在主窗口创建阶段统一锁定浅色

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名：application(_:didFinishLaunchingWithOptions:)
// 功能说明：修改后在 iOS 应用入口直接对主窗口锁定 `.light`；
// 这样所有 UIKit 语义色都会稳定解析到浅色分支，从应用入口根因关闭夜间模式。
// `window.backgroundColor` 同步改为 `.systemBackground`，保证窗口底色与浅色语义色体系保持一致。
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    MusicFontRegistry.bootstrapIfNeeded()

    let window = UIWindow(frame: UIScreen.main.bounds)
    // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
    window.overrideUserInterfaceStyle = .light
    window.rootViewController = iOSViewController()
    window.backgroundColor = .systemBackground
    window.makeKeyAndVisible()
    self.window = window
    return true
}
```

### macOS 在应用启动阶段统一锁定 Aqua 浅色外观

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名：applicationDidFinishLaunching(_:)
// 功能说明：修改后在 macOS 应用入口统一指定 `.aqua` 外观；
// 这样 AppKit 语义色会固定落在浅色 Aqua 分支，不再跟随系统深色模式变化。
// 窗口创建逻辑本身保持不变，只把外观决策前移到应用启动入口统一收口。
func applicationDidFinishLaunching(_ notification: Notification) {
    MusicFontRegistry.bootstrapIfNeeded()
    // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
    NSApp.appearance = NSAppearance(named: .aqua)

    let viewController = macOSViewController()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.contentMinSize = NSSize(width: 640, height: 420)
    window.title = "NoteMaster_Ver_1"
    window.center()
    window.contentViewController = viewController
    window.makeKeyAndOrderFront(nil)

    NSApp.activate(ignoringOtherApps: true)
    self.window = window
}
```

## 结果说明

- 本次修复从应用入口统一收口，没有去零散修改按钮、面板、控制器里的单个语义色。
- `iOS` 现有 `.systemBackground`、`.secondarySystemBackground`、`.label`、`.secondaryLabel` 等语义色现在会稳定解析为浅色分支。
- `macOS` 现有 `NSColor.windowBackgroundColor`、`NSColor.controlBackgroundColor`、`.labelColor`、`.secondaryLabelColor` 等语义色现在会稳定解析为 Aqua 浅色分支。
- 谱表与指板的自绘颜色本来就是固定浅色/深墨色，这次不需要再为夜间模式新增任何渲染分支。

## 验证情况

- 已用 `ReadLints` 检查 `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`，无新增诊断。
- 已用 `ReadLints` 检查 `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`，无新增诊断。
- 本次尚未执行真机、模拟器或 macOS 运行时的外观切换实测。

20260324_125716_phase3_staff_font_bootstrap_and_glyphs

# Staff 阶段 3 字体 bootstrap 与符号标识修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Staff/MusicFontRegistry.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`

## 修改前

### 修改前还没有共享字体注册器，`Staff` 域无法统一定位、注册和解析 Bravura 字体

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicFontRegistry.swift
// 函数名：无
// 功能说明：修改前该文件不存在；项目里虽然已有 Bravura.otf / BravuraText.otf 资源，但共享层没有统一的运行时注册和 CTFont 获取入口。
// 文件不存在
```

### 修改前还没有集中化的 glyph 标识层，`treble clef` 还没有映射到 Bravura/SMuFL 符号

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift
// 函数名：无
// 功能说明：修改前该文件不存在；StaffGlyphSymbolID 与具体字体、Unicode scalar、后续 renderer 输入之间还没有共享映射层。
// 文件不存在
```

### 修改前 iOS 启动入口没有做音乐字体 bootstrap

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名：application(_:didFinishLaunchingWithOptions:)
// 功能说明：修改前 iOS 启动时直接创建 window 和 rootViewController，没有确保 Bravura 在首次绘制前完成注册。
#if os(iOS)
import UIKit

@main
final class iOSAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = iOSViewController()
        window.backgroundColor = .white
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
#endif
```

### 修改前 macOS 启动入口也没有做音乐字体 bootstrap

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名：applicationDidFinishLaunching(_:)
// 功能说明：修改前 macOS 启动时直接创建窗口和控制器，没有为后续 Staff 渲染预先注册 Bravura 字体。
#if os(macOS)
import Foundation
import AppKit

@main
final class macOSAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private static let sharedDelegate = macOSAppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = sharedDelegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewController = macOSViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
#endif
```

## 修改后

### 1. 新增 `MusicFontRegistry`，统一负责字体定位、注册和 `CTFont` 提供

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicFontRegistry.swift
// 函数名：bootstrapIfNeeded(bundle:), font(for:size:bundle:), registeredPostScriptName(for:bundle:), locateFontURL(for:bundle:)
// 功能说明：新增共享字体注册器，在运行时查找 Bravura / BravuraText，完成一次性注册，并向阶段 4 的 renderer 暴露 CTFont 获取入口。
import Foundation
import CoreGraphics
import CoreText

enum MusicFontRegistry {
    private enum BootstrapState: Equatable {
        case idle
        case ready
        case failed(String)
    }

    private static let lock = NSLock()
    private static var bootstrapState: BootstrapState = .idle
    private static var registeredPostScriptNames: [MusicFontFace: String] = [:]

    static func bootstrapIfNeeded(bundle: Bundle = .main) {
        lock.lock()
        defer { lock.unlock() }

        guard bootstrapState == .idle else {
            return
        }

        do {
            try MusicFontFace.allCases.forEach { fontFace in
                try register(fontFace: fontFace, bundle: bundle)
            }
            bootstrapState = .ready
        } catch {
            let message = String(describing: error)
            bootstrapState = .failed(message)
            #if DEBUG
            print(message)
            #endif
        }
    }

    static func font(
        for fontFace: MusicFontFace,
        size: CGFloat,
        bundle: Bundle = .main
    ) -> CTFont? {
        bootstrapIfNeeded(bundle: bundle)

        guard case .ready = bootstrapState,
              let postScriptName = registeredPostScriptNames[fontFace] else {
            return nil
        }

        return CTFontCreateWithName(
            postScriptName as CFString,
            max(size, 1),
            nil
        )
    }

    private static func locateFontURL(
        for fontFace: MusicFontFace,
        bundle: Bundle
    ) throws -> URL {
        let searchSubdirectories: [String?] = [
            "Shared/Fonts",
            "Fonts",
            nil
        ]

        // 兼容同步根目录和子目录两种 bundle 结构。
        for subdirectory in searchSubdirectories {
            if let url = bundle.url(
                forResource: fontFace.resourceName,
                withExtension: fontFace.fileExtension,
                subdirectory: subdirectory
            ) {
                return url
            }
        }

        throw RegistryError.resourceNotFound(fontFace.fileName)
    }
}
```

### 2. 新增 `MusicGlyph`，把 `StaffGlyphSymbolID` 集中映射到 Bravura glyph

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift
// 函数名：MusicFontFace.resourceName, MusicGlyph.string, StaffGlyphSymbolID.musicGlyph
// 功能说明：新增共享 glyph 标识层，把 treble clef 映射到 Bravura 的 SMuFL gClef，为阶段 4 CoreText renderer 提供稳定输入。
enum MusicFontFace: String, CaseIterable, Hashable, Sendable {
    case bravura
    case bravuraText

    var resourceName: String {
        switch self {
        case .bravura:
            return "Bravura"
        case .bravuraText:
            return "BravuraText"
        }
    }

    var fileExtension: String {
        "otf"
    }

    // 未来 renderer 优先使用注册后的 PostScript name；这里保留文件级默认名作为回退。
    var fallbackPostScriptName: String {
        resourceName
    }
}

struct MusicGlyph: Equatable, Sendable {
    var fontFace: MusicFontFace
    var scalarValue: UInt32

    // Stage 4 的 CoreText renderer 将直接使用该字符构建 attributed string。
    var string: String {
        guard let scalar = UnicodeScalar(scalarValue) else {
            return "\u{FFFD}"
        }

        return String(scalar)
    }

    // SMuFL gClef，对应 Bravura 中的 treble clef。
    static let trebleClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE050
    )
}

extension StaffGlyphSymbolID {
    var musicGlyph: MusicGlyph {
        switch self {
        case .trebleClef:
            return .trebleClef
        }
    }
}
```

### 3. iOS 启动入口接入 `MusicFontRegistry.bootstrapIfNeeded()`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名：application(_:didFinishLaunchingWithOptions:)
// 功能说明：修改后 iOS 在创建主窗口前先执行音乐字体 bootstrap，保证 Staff 组件第一次取字时已完成注册。
#if os(iOS)
import UIKit

@main
final class iOSAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

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
}
#endif
```

### 4. macOS 启动入口接入 `MusicFontRegistry.bootstrapIfNeeded()`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名：applicationDidFinishLaunching(_:)
// 功能说明：修改后 macOS 在创建窗口前先执行音乐字体 bootstrap，保证 Bravura 在首次渲染 staff glyph 前可用。
#if os(macOS)
import Foundation
import AppKit

@main
final class macOSAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private static let sharedDelegate = macOSAppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = sharedDelegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MusicFontRegistry.bootstrapIfNeeded()

        let viewController = macOSViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
#endif
```

## 结果与边界变化

- `Staff` 域现在具备了“资源文件 -> 注册字体 -> 获取 CTFont -> glyph 标识映射”的共享准备层。
- `StaffGlyphSymbolID.trebleClef` 已经不再只是语义名字，而是通过 `MusicGlyph` 明确映射到 Bravura `U+E050`。
- 双平台应用启动时都会先执行 `MusicFontRegistry.bootstrapIfNeeded()`，后续 renderer 不需要再把“先注册字体”写进绘制链路。
- 本次仍然没有实现 `CoreTextMusicGlyphRenderer`、`MusicGlyphRendererFactory`、`StaffRootLayer`、`StaffGlyphLayer`、`iOSStaffView`、`macOSStaffView`，阶段边界保持在 3。

## 验证情况

- `ReadLints` 检查阶段 3 相关文件后，没有新增诊断。
- 使用 `swiftc -typecheck` 对以下共享层文件进行了静态类型检查，并已通过：
  - `NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicFontRegistry.swift`
  - `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 本次没有执行工程级 `xcodebuild` 验证；当前确认范围是共享层静态类型检查和编辑器诊断通过。

20260324_145700_phase6_staff_platform_views_and_demo

# Staff 阶段 6 平台包装视图与演示接入修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift`
- 新增 `NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`

## 修改前

### 修改前还没有 iOS 平台的 `Staff` 包装视图

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift
// 函数名：无
// 功能说明：修改前该文件不存在；iOS 侧还没有把 StaffRootLayer 包装成 UIView 的平台宿主。
// 文件不存在
```

### 修改前还没有 macOS 平台的 `Staff` 包装视图

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift
// 函数名：无
// 功能说明：修改前该文件不存在；macOS 侧还没有把 StaffRootLayer 包装成 NSView 的平台宿主。
// 文件不存在
```

### 修改前 iOS 控制器页面只有按钮面板和指板组件，没有 staff 演示区域

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：configureLayout(), applyDisplayState()
// 功能说明：修改前控制器只接入了 buttonPanelView 和 fretboardView，布局链路中没有 StaffDisplayState 和 iOSStaffView。
final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }

    private lazy var buttonPanelView: iOSButtonPanelView = {
        let buttonPanelView = iOSButtonPanelView(
            model: ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        )
        buttonPanelView.onAction = { [weak self] actionID in
            self?.handleButtonAction(actionID)
        }
        return buttonPanelView
    }()

    private lazy var fretboardView: iOSFretboardView = {
        let fretboardView = iOSFretboardView(configuration: displayState.configuration)
        return fretboardView
    }()

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(fretboardView)

        NSLayoutConstraint.activate([
            buttonPanelView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: Layout.topInset),
            fretboardView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
    }
}
```

### 修改前 macOS 控制器页面同样只有按钮面板和指板组件，没有 staff 演示区域

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：configureLayout(), applyDisplayState()
// 功能说明：修改前 macOS 控制器只维护指板演示，不包含 macOSStaffView 和固定为 CoreText 的 StaffDisplayState。
final class macOSViewController: NSViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }

    private lazy var buttonPanelView: macOSButtonPanelView = {
        let buttonPanelView = macOSButtonPanelView(
            model: ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        )
        return buttonPanelView
    }()

    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: displayState.configuration)
        return fretboardView
    }()

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(fretboardView)

        NSLayoutConstraint.activate([
            buttonPanelView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: Layout.topInset),
            fretboardView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
    }
}
```

## 修改后

### 1. 新增 `iOSStaffView`，把 `StaffRootLayer` 包装成 iOS 薄宿主视图

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift
// 函数名：layerClass, intrinsicContentSize, applyState(), updateContentsScale()
// 功能说明：新增 iOS 包装视图，负责把 StaffRootLayer 挂到 UIView 上，并显式注入 StaffCanvasOrientation.standard 与 iOS 的 `.none` 归一化模式。
#if os(iOS)
import UIKit

final class iOSStaffView: UIView {
    var configuration: StaffConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyState()
        }
    }

    var sceneProvider: StaffSceneProvider {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            applyState()
        }
    }

    override class var layerClass: AnyClass {
        StaffRootLayer.self
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: configuration.preferredHeight
        )
    }

    private func applyState() {
        var resolvedConfiguration = configuration
        resolvedConfiguration.canvasOrientation = .standard

        staffRootLayer.configuration = resolvedConfiguration
        staffRootLayer.sceneProvider = sceneProvider
        staffRootLayer.contextNormalizationMode = .none
        staffRootLayer.resourceBundle = .main
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        staffRootLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
    }
}
#endif
```

### 2. 新增 `macOSStaffView`，把 `StaffRootLayer` 包装成 macOS 薄宿主视图

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift
// 函数名：makeBackingLayer(), intrinsicContentSize, applyState(), updateContentsScale()
// 功能说明：新增 macOS 包装视图，负责把 StaffRootLayer 挂到 NSView 上，并显式注入 StaffCanvasOrientation.standard 与 macOS 的 `.flipYToTopLeft` 归一化模式。
#if os(macOS)
import AppKit

final class macOSStaffView: NSView {
    var configuration: StaffConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyState()
        }
    }

    var sceneProvider: StaffSceneProvider {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            applyState()
        }
    }

    override func makeBackingLayer() -> CALayer {
        StaffRootLayer()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: configuration.preferredHeight
        )
    }

    private func applyState() {
        var resolvedConfiguration = configuration
        resolvedConfiguration.canvasOrientation = .standard

        staffRootLayer.configuration = resolvedConfiguration
        staffRootLayer.sceneProvider = sceneProvider
        staffRootLayer.contextNormalizationMode = .flipYToTopLeft
        staffRootLayer.resourceBundle = .main
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }

    private func updateContentsScale() {
        staffRootLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}
#endif
```

### 3. iOS 控制器新增 `StaffDisplayState` 和 `iOSStaffView`，形成 `buttonPanel -> staffView -> fretboardView` 演示布局

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：configureLayout(), applyDisplayState()
// 功能说明：修改后 iOS 控制器会创建固定为 CoreText 的 StaffDisplayState，并把 iOSStaffView 插入到按钮面板和指板之间用于展示验证。
final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default

    private let staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(renderMode: .coreText)
    )

    private lazy var staffView: iOSStaffView = {
        iOSStaffView(
            configuration: staffDisplayState.configuration,
            sceneProvider: staffDisplayState.sceneProvider
        )
    }()

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(staffView)
        view.addSubview(fretboardView)

        NSLayoutConstraint.activate([
            buttonPanelView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: Layout.topInset),
            staffView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
    }
}
```

### 4. macOS 控制器新增 `StaffDisplayState` 和 `macOSStaffView`，形成同构演示布局

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：configureLayout(), applyDisplayState()
// 功能说明：修改后 macOS 控制器也以 CoreText 固定配置接入 macOSStaffView，并与 iOS 保持相同的展示顺序和布局结构。
final class macOSViewController: NSViewController {
    private var displayState = FretboardDisplayState.default

    private let staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(renderMode: .coreText)
    )

    private lazy var staffView: macOSStaffView = {
        macOSStaffView(
            configuration: staffDisplayState.configuration,
            sceneProvider: staffDisplayState.sceneProvider
        )
    }()

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(staffView)
        view.addSubview(fretboardView)

        NSLayoutConstraint.activate([
            buttonPanelView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: Layout.topInset),
            staffView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
    }
}
```

## 结果与边界变化

- `Staff` 组件现在已经有完整的平台宿主层：`iOSStaffView` 和 `macOSStaffView`。
- 平台差异被明确压在包装层：
  - iOS 注入 `.none`
  - macOS 注入 `.flipYToTopLeft`
  - 两边都显式注入 `StaffCanvasOrientation.standard`
- iOS/macOS 控制器都已经把 Staff 组件接到当前页面中，形成统一的演示结构：
  - `buttonPanelView`
  - `staffView`
  - `fretboardView`
- 本次仍然没有扩展任何 Staff 交互、按钮面板开关、glyph 后端切换 UI，也没有实现运行时验证工具链，阶段边界保持在 6。

## 验证情况

- `ReadLints` 检查阶段 6 相关文件后，没有新增诊断。
- 使用 `swiftc -typecheck` 对以下文件进行了静态类型检查，并已通过：
  - `NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicFontRegistry.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicGlyphRenderer.swift`
  - `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicGlyphRendererFactory.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`
  - `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift`
- 本次没有执行工程级 `xcodebuild` 验证；当前确认范围是共享层、包装视图的静态类型检查和编辑器诊断通过。

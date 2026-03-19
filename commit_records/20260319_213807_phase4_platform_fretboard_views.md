20260319_213807_phase4_platform_fretboard_views

# 阶段 4 修改记录

## 本次变更范围

- 新增 iOS 包装视图 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 新增 macOS 包装视图 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `FretboardLayer.swift`
- 未接入 `iOSViewController.swift`、`macOSViewController.swift`

## 修改前

### iOS 包装视图文件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：无（文件不存在）
// 功能说明：修改前 iOS 平台没有专门的指板包装视图，无法把共享 FretboardLayer 作为 UIView 的 backing layer 封装起来。
// 该文件在修改前不存在。
```

### macOS 包装视图文件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：无（文件不存在）
// 功能说明：修改前 macOS 平台没有专门的指板包装视图，无法把共享 FretboardLayer 作为 NSView 的 backing layer 封装起来。
// 该文件在修改前不存在。
```

### 平台层职责现状

```swift
// 文件路径：NoteMaster_Ver_1/Platform
// 函数名：无
// 功能说明：修改前平台层只有 AppDelegate 和 ViewController，还没有“薄包装视图”这一层来承接共享渲染层。
Platform/iOS/iOSAppDelegate.swift
Platform/iOS/iOSViewController.swift
Platform/macOS/macOSAppDelegate.swift
Platform/macOS/macOSViewController.swift
```

## 修改后

### 新增 iOS 包装视图

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：configuration, layerClass, intrinsicContentSize, init(frame:), init(configuration:), didMoveToWindow(), traitCollectionDidChange(_:), applyConfiguration(), updateContentsScale()
// 功能说明：新增 UIView 包装层，直接把 backing layer 指向共享 FretboardLayer，并通过 configuration 暴露统一配置入口。
#if os(iOS)
import UIKit

final class iOSFretboardView: UIView {
    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    override class var layerClass: AnyClass {
        FretboardLayer.self
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: configuration.preferredHeight
        )
    }

    override init(frame: CGRect) {
        configuration = .init()
        super.init(frame: frame)
        configureView()
    }
}
#endif
```

### iOS 平台对共享 layer 的托管方式

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：fretboardLayer, configureView(), applyConfiguration(), updateContentsScale()
// 功能说明：iOS 侧只负责获取 backing layer、同步 configuration、更新 contentsScale，并通过 intrinsicContentSize 暴露高度语义。
private var fretboardLayer: FretboardLayer {
    guard let fretboardLayer = layer as? FretboardLayer else {
        fatalError("Expected FretboardLayer backing layer.")
    }

    return fretboardLayer
}

private func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    applyConfiguration()
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    updateContentsScale()
    invalidateIntrinsicContentSize()
}

private func updateContentsScale() {
    fretboardLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
}
```

### 新增 macOS 包装视图

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：configuration, intrinsicContentSize, init(frame:), init(configuration:), makeBackingLayer(), viewDidMoveToWindow(), applyConfiguration(), updateContentsScale()
// 功能说明：新增 NSView 包装层，通过 makeBackingLayer() 返回共享 FretboardLayer，并对外暴露与 iOS 对齐的 configuration 接口。
#if os(macOS)
import AppKit

final class macOSFretboardView: NSView {
    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: configuration.preferredHeight
        )
    }

    override init(frame frameRect: NSRect) {
        configuration = .init()
        super.init(frame: frameRect)
        configureView()
    }
}
#endif
```

### macOS 平台对共享 layer 的托管方式

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：makeBackingLayer(), fretboardLayer, configureView(), applyConfiguration(), updateContentsScale()
// 功能说明：macOS 侧只负责创建 backing layer、同步 configuration 和 backingScaleFactor，不承担任何绘制几何逻辑。
override func makeBackingLayer() -> CALayer {
    FretboardLayer()
}

private var fretboardLayer: FretboardLayer {
    guard let fretboardLayer = layer as? FretboardLayer else {
        fatalError("Expected FretboardLayer backing layer.")
    }

    return fretboardLayer
}

private func configureView() {
    wantsLayer = true
    layerContentsRedrawPolicy = .onSetNeedsDisplay
    applyConfiguration()
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    updateContentsScale()
    invalidateIntrinsicContentSize()
}

private func updateContentsScale() {
    fretboardLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
}
```

## 结果说明

- 阶段 4 的核心结果是补齐了 iOS `UIView` 和 macOS `NSView` 两层薄包装视图。
- 两个平台包装视图都只承担托管共享 `FretboardLayer`、传递 `configuration`、同步显示缩放和暴露高度语义，不承担绘制逻辑。
- 这样阶段 5 接入控制器时，只需要创建包装视图并添加约束，不需要在控制器里接触 `CALayer` 细节。
- 本次没有修改任何 `ViewController`，也没有改动已有的共享几何和共享渲染逻辑。

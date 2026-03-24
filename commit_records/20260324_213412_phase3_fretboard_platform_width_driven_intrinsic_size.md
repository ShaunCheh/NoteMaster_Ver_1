20260324_213412_phase3_fretboard_platform_width_driven_intrinsic_size

# Phase 3 Fretboard Platform Width-Driven Intrinsic Size 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### iOS 指板视图仍把固定 `preferredHeight` 作为 intrinsic 高度出口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：intrinsicContentSize / applyConfiguration()
// 功能说明：修改前 iOS 平台视图仍直接暴露 `configuration.preferredHeight`；
// 也就是说高度与当前实际宽度无关，配置变化时只会失效 intrinsic，但宽度变化本身不会触发新的高度推导。
override var intrinsicContentSize: CGSize {
    CGSize(
        width: UIView.noIntrinsicMetric,
        height: configuration.preferredHeight
    )
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    invalidateIntrinsicContentSize()
}
```

### macOS 指板视图同样仍以固定 `preferredHeight` 作为 intrinsic 高度出口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：intrinsicContentSize / applyConfiguration()
// 功能说明：修改前 macOS 平台视图和 iOS 一样，
// 高度只读固定 `preferredHeight`，窗口或容器宽度变化不会主动让 intrinsic 高度随之重算。
override var intrinsicContentSize: NSSize {
    NSSize(
        width: NSView.noIntrinsicMetric,
        height: configuration.preferredHeight
    )
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    invalidateIntrinsicContentSize()
}
```

## 修改后

### iOS 视图改为按当前宽度推导 intrinsic 高度，并在布局宽度变化时主动失效

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：intrinsicContentSize / layoutSubviews() / resolvedIntrinsicHeight / invalidateIntrinsicSizeForCurrentWidthIfNeeded()
// 功能说明：修改后 iOS 指板视图把 intrinsic 高度改为按当前 `bounds.width` 调用
// `configuration.resolvedHeight(forAvailableWidth:)` 动态计算；
// 同时通过 `layoutSubviews()` 监听布局宽度变化，确保容器拉宽或缩窄时能够重新触发 Auto Layout 消费新的高度。
private var lastMeasuredLayoutWidth: CGFloat?

override var intrinsicContentSize: CGSize {
    CGSize(
        width: UIView.noIntrinsicMetric,
        height: resolvedIntrinsicHeight
    )
}

override func layoutSubviews() {
    super.layoutSubviews()
    invalidateIntrinsicSizeForCurrentWidthIfNeeded()
}

private var resolvedIntrinsicHeight: CGFloat {
    guard bounds.width > 0 else {
        return configuration.preferredHeight
    }

    return configuration.resolvedHeight(forAvailableWidth: bounds.width)
}

private func invalidateIntrinsicSizeForCurrentWidthIfNeeded() {
    let currentWidth = bounds.width
    guard lastMeasuredLayoutWidth != currentWidth else {
        return
    }

    lastMeasuredLayoutWidth = currentWidth
    invalidateIntrinsicContentSize()
}
```

### macOS 视图改为按当前宽度推导 intrinsic 高度，并在 frame 宽度变化时主动失效

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：intrinsicContentSize / setFrameSize(_:) / resolvedIntrinsicHeight
// 功能说明：修改后 macOS 指板视图同样把 intrinsic 高度改为按当前 `bounds.width` 计算；
// 通过重写 `setFrameSize(_:)` 侦测宽度变化，在 live resize 或窗口尺寸变化时及时失效 intrinsic 高度。
override var intrinsicContentSize: NSSize {
    NSSize(
        width: NSView.noIntrinsicMetric,
        height: resolvedIntrinsicHeight
    )
}

override func setFrameSize(_ newSize: NSSize) {
    let previousWidth = frame.size.width
    super.setFrameSize(newSize)

    guard previousWidth != newSize.width else {
        return
    }

    invalidateIntrinsicContentSize()
}

private var resolvedIntrinsicHeight: CGFloat {
    guard bounds.width > 0 else {
        return configuration.preferredHeight
    }

    return configuration.resolvedHeight(forAvailableWidth: bounds.width)
}
```

## 结果说明

- 双平台指板视图的高度出口已经从“固定 `preferredHeight`”切换为“按当前宽度推导的动态 intrinsic 高度”。
- iOS 通过 `layoutSubviews()` 响应宽度变化，macOS 通过 `setFrameSize(_:)` 响应宽度变化，后续整页滚动和窗口拉伸时都能继续沿用这条出口。
- 当 `bounds.width` 尚未建立时，双平台仍会临时回退到 `configuration.preferredHeight`，避免初始化阶段出现 0 高度或布局抖动。
- 本阶段没有改控制器布局结构；也就是说，阶段 3 只完成了“平台消费宽度优先尺寸真相”的出口迁移，还没有进入整页滚动容器改造。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift` 与 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`，无新增诊断。
- 已执行 Swift 源码级类型检查，结果通过。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对项目 Swift 源码执行静态类型检查，确认阶段 3 的双平台视图改动没有引入编译期错误。
swiftc -typecheck NoteMaster_Ver_1/**/*.swift
```

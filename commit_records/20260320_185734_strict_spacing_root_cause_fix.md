20260320_185734_strict_spacing_root_cause_fix

# 严格等距根因修复修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`

## 修改前

### 配置层仍保留旧的 `stringEdgeInsetRatio` 垂直语义

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：LayoutMetrics.stringEdgeInsetRatio, drawingHeight(forStringCount:)
// 功能说明：修改前 drawingHeight 会按 stringEdgeInsetRatio 继续放大弦列总高，因此最外弦到边界不是严格半个 lane。
struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        var stringEdgeInsetRatio: CGFloat
        // 每根弦占据的垂直车道高度，弦位应落在车道中心。
        var stringLaneHeight: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            stringEdgeInsetRatio: 0.09,
            stringLaneHeight: 17,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )

        func drawingHeight(forStringCount stringCount: Int) -> CGFloat {
            let stringBandHeight = stringBandHeight(forStringCount: stringCount)
            let stringBandFactor = max(
                1 - (stringEdgeInsetRatio * 2),
                Self.minimumLayoutFactor
            )
            return stringBandHeight / stringBandFactor
        }
    }
}
```

### 几何层还会对 `drawingRect` 做二次纵向内缩

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringLaneHeight, stringColumnRect, makeStringBandRect()
// 功能说明：修改前几何层先生成 stringBandRect，再在其中排弦；这层 band 内缩会把最外弦进一步推离指板上下边界。
var stringLaneHeight: CGFloat {
    let stringBandRect = makeStringBandRect()
    guard !stringBandRect.isNull else {
        return 0
    }

    return resolvedStringLaneHeight(in: stringBandRect)
}

var stringColumnRect: CGRect {
    let stringBandRect = makeStringBandRect()
    let laneHeight = resolvedStringLaneHeight(in: stringBandRect)
    guard
        !stringBandRect.isNull,
        configuration.stringCount > 0,
        laneHeight > 0
    else {
        return .null
    }

    let occupiedHeight = laneHeight * CGFloat(configuration.stringCount)
    return CGRect(
        x: stringBandRect.minX,
        y: stringBandRect.midY - (occupiedHeight / 2),
        width: stringBandRect.width,
        height: occupiedHeight
    )
}

private func makeStringBandRect() -> CGRect {
    guard !drawingRect.isNull else {
        return .null
    }

    let maxInset = drawingRect.height / 2
    let proposedInset = drawingRect.height * configuration.layoutMetrics.stringEdgeInsetRatio
    let edgeInset = min(max(proposedInset, 0), maxInset)

    let stringBandRect = drawingRect.insetBy(dx: 0, dy: edgeInset)
    if stringBandRect.isNull || stringBandRect.isEmpty {
        return drawingRect
    }

    return stringBandRect
}
```

### 控制器里还保留了临时布局诊断日志入口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：applyDisplayState(logsLayoutDiagnostics:), printLayoutDiagnostics()
// 功能说明：修改前为了定位问题，iOS 控制器会在初始加载和 configuration 变化时打印布局诊断日志。
private var displayState = FretboardDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyDisplayState(
            logsLayoutDiagnostics: oldValue.configuration != displayState.configuration
        )
    }
}

override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    configureLayout()
    applyDisplayState(logsLayoutDiagnostics: true)
}

private func applyDisplayState(logsLayoutDiagnostics: Bool = false) {
    buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    view.setNeedsLayout()
    view.layoutIfNeeded()

    if logsLayoutDiagnostics {
        printLayoutDiagnostics()
    }
}

private func printLayoutDiagnostics() {
    let geometry = FretboardGeometry(
        configuration: displayState.configuration,
        bounds: fretboardView.bounds
    )
    print(geometry.layoutDebugSummary(platform: "iOS"))
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：applyDisplayState(logsLayoutDiagnostics:), printLayoutDiagnostics()
// 功能说明：修改前 macOS 控制器也挂着同一套临时布局诊断日志，用来输出 topEdgeToCenter / spacing 等定位信息。
private var displayState = FretboardDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyDisplayState(
            logsLayoutDiagnostics: oldValue.configuration != displayState.configuration
        )
    }
}

override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    configureLayout()
    applyDisplayState(logsLayoutDiagnostics: true)
}

private func applyDisplayState(logsLayoutDiagnostics: Bool = false) {
    buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()

    if logsLayoutDiagnostics {
        printLayoutDiagnostics()
    }
}

private func printLayoutDiagnostics() {
    let geometry = FretboardGeometry(
        configuration: displayState.configuration,
        bounds: fretboardView.bounds
    )
    print(geometry.layoutDebugSummary(platform: "macOS"))
}
```

## 修改后

### 配置层删除 `stringEdgeInsetRatio`，弦列总高直接等于 `stringCount * stringLaneHeight`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：LayoutMetrics, drawingHeight(forStringCount:)
// 功能说明：修改后配置层不再保留旧的 edgeInset 垂直真相，drawingHeight 直接使用弦列总高，严格等距语义从配置层开始成立。
struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        // 每根弦占据的垂直车道高度，弦位应落在车道中心。
        var stringLaneHeight: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            stringLaneHeight: 17,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )

        func drawingHeight(forStringCount stringCount: Int) -> CGFloat {
            stringBandHeight(forStringCount: stringCount)
        }
    }
}
```

### 几何层直接以 `drawingRect` 作为弦列垂直区域

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringLaneHeight, stringColumnRect, resolvedStringLaneHeight(in:)
// 功能说明：修改后几何层不再生成 stringBandRect，也不再做纵向二次内缩；最外弦到上下边界自动收口为半个 lane。
var stringLaneHeight: CGFloat {
    guard !drawingRect.isNull else {
        return 0
    }

    return resolvedStringLaneHeight(in: drawingRect.height)
}

var stringColumnRect: CGRect {
    let laneHeight = stringLaneHeight
    guard
        !drawingRect.isNull,
        configuration.stringCount > 0,
        laneHeight > 0
    else {
        return .null
    }

    let occupiedHeight = laneHeight * CGFloat(configuration.stringCount)
    return CGRect(
        x: drawingRect.minX,
        y: drawingRect.midY - (occupiedHeight / 2),
        width: drawingRect.width,
        height: occupiedHeight
    )
}

private func resolvedStringLaneHeight(
    in availableHeight: CGFloat
) -> CGFloat {
    guard
        availableHeight > 0,
        configuration.stringCount > 0
    else {
        return 0
    }

    let preferredLaneHeight = max(configuration.layoutMetrics.stringLaneHeight, 1)
    let availableLaneHeight = availableHeight / CGFloat(configuration.stringCount)
    return min(preferredLaneHeight, max(availableLaneHeight, 0))
}
```

### 控制器移除临时布局诊断日志，恢复正常状态传播链

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：applyDisplayState()
// 功能说明：修改后 iOS 控制器不再保留临时布局诊断参数和打印方法，只继续承担 displayState -> view 的正常状态传播。
private var displayState = FretboardDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyDisplayState()
    }
}

override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    configureLayout()
    applyDisplayState()
}

private func applyDisplayState() {
    buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    view.setNeedsLayout()
    view.layoutIfNeeded()
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：applyDisplayState()
// 功能说明：修改后 macOS 控制器也同步移除临时布局诊断日志，继续只负责 displayState 到平台视图的状态刷新。
private var displayState = FretboardDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyDisplayState()
    }
}

override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    configureLayout()
    applyDisplayState()
}

private func applyDisplayState() {
    buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()
}
```

## 验证结果

```text
# 文件路径：无（共享层数值验证输出）
# 函数名：无
# 功能说明：严格等距修复后，4/5/6 弦下最外弦到上下边界都回到 halfLane=8.50，topInset/bottomInset 清零，badge 尺寸保持稳定，命中校验通过。
instrument=guitar6 height=150.00 lane=17.00 spacing=17.00 halfLane=8.50 topGap=8.50 bottomGap=8.50 topInset=0.00 bottomInset=0.00 badge=13.26
instrument=bass4 height=100.00 lane=17.00 spacing=17.00 halfLane=8.50 topGap=8.50 bottomGap=8.50 topInset=-0.00 bottomInset=0.00 badge=13.26
instrument=bass5 height=125.00 lane=17.00 spacing=17.00 halfLane=8.50 topGap=8.50 bottomGap=8.50 topInset=-0.00 bottomInset=0.00 badge=13.26
validation=ok
```

```text
# 文件路径：无（平台高度验证输出）
# 函数名：无
# 功能说明：macOS 平台视图继续只通过 intrinsicContentSize.height 消费派生高度，切换乐器后总高会自动更新。
macOSView heights guitar=150.00 bass4=100.00 bass5=125.00
validation=ok
```

```text
# 文件路径：无（静态检查结果）
# 函数名：无
# 功能说明：严格等距修复涉及的共享层、双平台视图和双平台控制器都通过了 IDE lints 与 swiftc 类型检查。
swiftc -typecheck: exit_code=0
No linter errors found.
```

## 结果说明

- 这次修改从根因上移除了旧的 `stringEdgeInsetRatio` 垂直语义，不再是“调参数”修问题。
- 现在最外弦到上下边界的距离已经严格收口为 `0.5 * stringLaneHeight`，不会再大于弦间距。
- 总高度也随之同步收缩为：`guitar6 = 150`、`bass4 = 100`、`bass5 = 125`。
- `badge` 尺寸、`marker` 几何参考、`raw hitTest` 与平台 `intrinsicContentSize` 都已经回归验证通过。
- 为定位问题临时加的布局诊断日志已经清理掉，没有残留在 iOS/macOS 控制器中。

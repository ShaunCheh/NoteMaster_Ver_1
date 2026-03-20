20260320_131435_phase4_macos_raw_mouse

# Raw 事件阶段 4 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### macOS 包装视图还只是展示壳，没有 raw mouse 回调出口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：configuration, contentProvider, makeBackingLayer()
// 功能说明：修改前 macOSFretboardView 只负责承载 FretboardLayer、透传 configuration 和 contentProvider，还没有任何原始鼠标事件相关的对外回调。
final class macOSFretboardView: NSView {
    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            fretboardLayer.contentProvider = contentProvider
        }
    }

    override func makeBackingLayer() -> CALayer {
        FretboardLayer()
    }
}
```

### macOS 侧没有直接消费原始鼠标事件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：viewDidMoveToWindow(), configureView(), applyConfiguration()
// 功能说明：修改前包装视图只有窗口缩放和 layer 配置逻辑，没有 mouseDown / mouseDragged / mouseUp。
override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    updateContentsScale()
}

private func configureView() {
    wantsLayer = true
    layerContentsRedrawPolicy = .onSetNeedsDisplay
    applyConfiguration()
}
```

## 修改后

### macOS 包装视图新增 raw 事件回调出口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：onRawEvent
// 功能说明：修改后 macOSFretboardView 新增 onRawEvent，把共享 FretboardHitResult 作为平台层向外抛出的统一 raw 事件结果。
final class macOSFretboardView: NSView {
    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            fretboardLayer.contentProvider = contentProvider
        }
    }

    // 阶段 4 只负责把 raw mouse 事件转换成共享命中结果并向外抛出。
    var onRawEvent: ((FretboardHitResult) -> Void)?
}
```

### macOS 包装视图直接接入原始鼠标事件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：mouseDown(with:), mouseDragged(with:), mouseUp(with:)
// 功能说明：修改后 macOS 端不使用手势识别器，而是直接走 NSResponder 的原始鼠标事件入口，并统一交给 handleRawMouseEvent 处理。
override func mouseDown(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .began)
}

override func mouseDragged(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .moved)
}

override func mouseUp(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .ended)
}
```

### macOS 包装视图把窗口事件坐标转换成共享命中结果

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：handleRawMouseEvent(_:phase:)
// 功能说明：修改后包装视图只做三件事：把 window 坐标转成本地坐标、调用共享 FretboardGeometry.hitTest、再把结果通过 onRawEvent 抛出。
private func handleRawMouseEvent(
    _ event: NSEvent,
    phase: FretboardEventPhase
) {
    let location = convert(event.locationInWindow, from: nil)
    let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
    let hitResult = geometry.hitTest(location, phase: phase)
    onRawEvent?(hitResult)
}
```

### 平台层职责边界的变化

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：onRawEvent, handleRawMouseEvent(_:phase:)
// 功能说明：阶段 4 后，macOS 包装视图开始承担“原始鼠标事件入口”和“窗口坐标到本地坐标桥接”的职责，但仍然不自己计算弦品命中，而是委托给共享几何层。
var onRawEvent: ((FretboardHitResult) -> Void)?

private func handleRawMouseEvent(
    _ event: NSEvent,
    phase: FretboardEventPhase
) {
    let location = convert(event.locationInWindow, from: nil)
    let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
    let hitResult = geometry.hitTest(location, phase: phase)
    onRawEvent?(hitResult)
}
```

## 结果说明

- 阶段 4 的核心结果是：macOS 包装视图现在已经能直接接收 raw mouse 事件。
- 这一步和 iOS 保持同一架构边界：平台层只负责把事件转成 view 本地坐标并调用共享 `hitTest`，不自己实现弦/品计算逻辑。
- 当前还没有把结果打印到控制台；`onRawEvent` 只是先把对外回调出口补齐，供后续控制器阶段装配。
- 已对 `macOSFretboardView.swift` 做静态检查，`ReadLints` 无报错；补全 `FretboardLayer.swift` 依赖后，`xcrun swiftc -typecheck` 通过。

20260320_130458_phase3_ios_raw_touch

# Raw 事件阶段 3 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### iOS 包装视图还只是展示壳，没有 raw touch 回调出口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：configuration, contentProvider, layerClass
// 功能说明：修改前 iOSFretboardView 只负责承载 FretboardLayer、透传 configuration 和 contentProvider，还没有任何原始触摸事件相关的对外回调。
final class iOSFretboardView: UIView {
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

    override class var layerClass: AnyClass {
        FretboardLayer.self
    }
}
```

### iOS 侧没有直接消费 raw responder touch 事件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：didMoveToWindow(), traitCollectionDidChange(_:), configureView(), applyConfiguration()
// 功能说明：修改前包装视图只有窗口/屏幕缩放和 layer 配置逻辑，没有 touchesBegan / touchesMoved / touchesEnded / touchesCancelled。
override func didMoveToWindow() {
    super.didMoveToWindow()
    updateContentsScale()
}

override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateContentsScale()
}

private func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    applyConfiguration()
}
```

## 修改后

### iOS 包装视图新增 raw 事件回调出口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：onRawEvent
// 功能说明：修改后 iOSFretboardView 新增 onRawEvent，把共享 FretboardHitResult 作为平台层向外抛出的统一 raw 事件结果。
final class iOSFretboardView: UIView {
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

    // 阶段 3 只负责把 raw touch 事件转换成共享命中结果并向外抛出。
    var onRawEvent: ((FretboardHitResult) -> Void)?
}
```

### iOS 包装视图直接接入原始触摸事件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：touchesBegan(_:with:), touchesMoved(_:with:), touchesEnded(_:with:), touchesCancelled(_:with:)
// 功能说明：修改后 iOS 端不使用手势识别器，而是直接走 UIResponder 的原始 touch 事件入口，并统一交给 handleRawTouchEvent 处理。
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    handleRawTouchEvent(from: touches, phase: .began)
    super.touchesBegan(touches, with: event)
}

override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    handleRawTouchEvent(from: touches, phase: .moved)
    super.touchesMoved(touches, with: event)
}

override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    handleRawTouchEvent(from: touches, phase: .ended)
    super.touchesEnded(touches, with: event)
}

override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    handleRawTouchEvent(from: touches, phase: .cancelled)
    super.touchesCancelled(touches, with: event)
}
```

### iOS 包装视图把本地触点转换成共享命中结果

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：handleRawTouchEvent(from:phase:)
// 功能说明：修改后包装视图只做三件事：读取 touches.first、转换到本地坐标、调用共享 FretboardGeometry.hitTest，再把结果通过 onRawEvent 抛出。
private func handleRawTouchEvent(
    from touches: Set<UITouch>,
    phase: FretboardEventPhase
) {
    guard let touch = touches.first else {
        return
    }

    let location = touch.location(in: self)
    let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
    let hitResult = geometry.hitTest(location, phase: phase)
    onRawEvent?(hitResult)
}
```

### 平台层职责边界的变化

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：onRawEvent, handleRawTouchEvent(from:phase:)
// 功能说明：阶段 3 后，iOS 包装视图开始承担“原始事件入口”和“坐标系桥接”的职责，但仍然不自己计算弦品命中，而是委托给共享几何层。
var onRawEvent: ((FretboardHitResult) -> Void)?

private func handleRawTouchEvent(
    from touches: Set<UITouch>,
    phase: FretboardEventPhase
) {
    let location = touch.location(in: self)
    let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
    let hitResult = geometry.hitTest(location, phase: phase)
    onRawEvent?(hitResult)
}
```

## 结果说明

- 阶段 3 的核心结果是：iOS 包装视图现在已经能直接接收 raw touch 事件。
- 这一步仍然保持了原有架构边界：平台层只负责拿到本地坐标并调用共享 `hitTest`，不自己实现弦/品计算逻辑。
- 当前还没有把结果打印到控制台；`onRawEvent` 只是先把对外回调出口预留好，供后续控制器阶段装配。
- 已对 `iOSFretboardView.swift` 做静态检查，`ReadLints` 无报错，`xcrun swiftc -typecheck` 通过。

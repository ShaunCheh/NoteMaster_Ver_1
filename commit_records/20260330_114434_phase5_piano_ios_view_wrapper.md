# 20260330_114434_phase5_piano_ios_view_wrapper

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260330_114434`
- 记录范围：实施“钢琴键盘组件”计划的阶段 5，只落 `iOS` 薄壳 `UIView`，把 raw touch、Shared 几何、Shared reducer 和 `PianoKeyboardLayer` 接通
- 本次目标：在不接入控制器 demo、不做 `macOS` 壳层的前提下，先完成 `iOSPianoKeyboardView`
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/*`
- `NoteMaster_Ver_1/Platform/macOS/*`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1.xcodeproj/project.pbxproj`

## 本次结论

- 修改前，钢琴组件已经具备 Shared 层的 `state + geometry + reducer + layer`
- 但 `iOS` 端还没有一个真正的 `UIView` 去：
- 承接原始 touch
- 调用 `PianoGeometry`
- 推进 `PianoInteractionReducer`
- 把结果回写到 `PianoKeyboardLayer`
- 修改后，阶段 5 已落成一个半受控的 `iOSPianoKeyboardView`
- 外部可设置 `rows` / `configuration`
- 组件内部也可以在触摸过程中即时推进 `componentState`
- 每次 Shared reducer 产出 `rowsChanged / previewStarted / previewChanged / previewEnded` 时，view 会把这些语义事件继续透出给宿主

## 修改前总体现状

- 修改前，`Shared/Piano` 已能描述“命中了哪一行、哪一区、哪个音，以及下一帧状态应该是什么”
- 但 `iOS` 侧还没有把这些 Shared 能力装进 `UIView`
- 因此当时仍然缺少：
- backing layer 指向 `PianoKeyboardLayer`
- raw touch 到 `PianoRawEvent` 的桥接
- `PianoGeometry + PianoInteractionReducer` 的平台级调用
- reducer 输出到 `UIView` 回调和 layer 重绘的收口

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前 iOS 侧还没有钢琴专用 UIView，Shared/Piano 的交互和绘制无法被 UIKit 直接消费。
(无代码)
```

## 修改 1：新增 `iOSPianoKeyboardView` 基础壳层

### 修改前

- 修改前没有 `iOSPianoKeyboardView`
- 因而也没有：
- `override class var layerClass` 返回 `PianoKeyboardLayer`
- 统一维护 `configuration` / `rows`
- 用 `intrinsicContentSize` 把多行总高度暴露给 Auto Layout

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: layerClass, intrinsicContentSize, configureView()
// 功能说明: 修改前不存在 iOS 薄壳，因此也不存在钢琴 UIKit 侧的 layerClass 和基础布局配置。
(无代码)
```

### 修改后

- 新增 `iOSPianoKeyboardView`
- `layerClass` 直接返回 `PianoKeyboardLayer`
- 视图内部持有 `componentState`
- 对外暴露半受控 `rows`
- `intrinsicContentSize.height` 直接基于 `rowCount` 和 `PianoLayoutMath.totalContentHeight(...)`
- `configureView()` 负责统一设置透明背景、单指触摸和纵向 Hugging/Resistance

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: iOSPianoKeyboardView, layerClass, intrinsicContentSize, configureView()
// 功能说明: 建立 UIKit 薄壳，直接把 UIView 的 backing layer 切到 PianoKeyboardLayer，并暴露半受控 rows/configuration 接口。
final class iOSPianoKeyboardView: UIView {
    private var componentState: PianoComponentState
    private var activeTouch: UITouch?
    private var lastTrackedLocationInView: CGPoint?

    var configuration: PianoConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var rows: [PianoRowState] {
        get {
            componentState.rows
        }
        set {
            replaceRows(newValue)
        }
    }

    override class var layerClass: AnyClass {
        PianoKeyboardLayer.self
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: resolvedIntrinsicHeight
        )
    }
}

func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    isMultipleTouchEnabled = false
    setContentHuggingPriority(.defaultLow, for: .horizontal)
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    applyBackingState()
    applyConfiguration()
}
```

## 修改 2：接通 raw touch -> geometry -> reducer -> layer 回写

### 修改前

- 修改前虽然 Shared 已有 `PianoGeometry` 和 `PianoInteractionReducer`
- 但 UIKit 侧还没有任何代码去：
- 把 `touchesBegan/Moved/Ended/Cancelled` 转成 `PianoRawEvent`
- 调用 `geometry.hitTest(...)`
- 读取 `PianoReduction`
- 把 `nextState` 回写到 backing layer

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: touchesBegan(_:with:), handleRawTouchEvent(from:phase:), handleRawEvent(_:)
// 功能说明: 修改前不存在 raw touch 到 Shared reducer 的桥接入口。
(无代码)
```

### 修改后

- `touchesBegan/Moved/Ended/Cancelled` 全部直接走 `handleRawTouchEvent(...)`
- `handleRawEvent(_:)` 内部按当前 `configuration + componentState + bounds` 构建 `PianoGeometry`
- 然后调用 `PianoInteractionReducer.reduce(...)`
- `applyReduction(_:)` 会把 `nextState` 回写到 `componentState` 和 `PianoKeyboardLayer`
- 同时按 reducer 原顺序转发语义回调

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: touchesBegan(_:with:), touchesMoved(_:with:), touchesEnded(_:with:), touchesCancelled(_:with:)
// 功能说明: UIKit 原始触摸事件不经过手势识别器，直接桥接到钢琴 Shared 交互内核。
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

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: handleRawEvent(_:) , applyReduction(_:) , emitSemanticEvents(_:)
// 功能说明: 把 UIKit 点位投影为 Shared hitResult，再将 reducer 产出的 nextState 和语义事件回写给 layer 与宿主。
func handleRawEvent(_ rawEvent: PianoRawEvent) {
    guard !bounds.isEmpty else {
        return
    }

    let geometry = PianoGeometry(
        configuration: configuration,
        state: componentState,
        bounds: bounds
    )
    let hitResult = geometry.hitTest(
        rawEvent.locationInView,
        phase: rawEvent.phase
    )
    let reduction = PianoInteractionReducer.reduce(
        state: componentState,
        rawEvent: rawEvent,
        hitResult: hitResult,
        configuration: configuration
    )
    applyReduction(reduction)
}

func applyReduction(_ reduction: PianoReduction) {
    guard reduction.nextState != componentState || !reduction.semanticEvents.isEmpty else {
        return
    }

    componentState = reduction.nextState
    applyBackingState()
    emitSemanticEvents(reduction.semanticEvents)
}

func emitSemanticEvents(_ semanticEvents: [PianoSemanticEvent]) {
    for semanticEvent in semanticEvents {
        switch semanticEvent {
        case let .rowsChanged(rows):
            onRowsChanged?(rows)
        case let .previewStarted(preview):
            onPreviewStarted?(preview)
        case let .previewChanged(preview):
            onPreviewChanged?(preview)
        case let .previewEnded(preview):
            onPreviewEnded?(preview)
        }
    }
}
```

## 修改 3：补半受控状态收口与单指追踪

### 修改前

- 修改前没有平台壳层，所以也没有：
- 外部替换 `rows` 时的状态清洗
- 多触点进入时的单指锁定
- `ended/cancelled` 偶发拿不到当前 `UITouch` 时的兜底收尾

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: replaceRows(_:), sanitizedState(byReplacingRowsWith:from:), resolvedTrackedTouch(from:phase:)
// 功能说明: 修改前不存在平台侧状态收口逻辑，外部 rows 回写和单指追踪都还没有实现。
(无代码)
```

### 修改后

- `replaceRows(_:)` 支持宿主外部直接回写 `rows`
- `sanitizedState(...)` 会同步清洗：
- 越界 `preview`
- 越界 `buttonPressed`
- 越界或不一致的 `scaleDrag`
- 越界 `keyGlissando`
- `resolvedTrackedTouch(...)` 把一次输入序列锁在同一根 `UITouch`
- 新增 `lastTrackedLocationInView`
- 当 `ended/cancelled` 阶段没拿到当前触点时，view 仍会用上次位置补发一个结束事件，避免高亮或 preview 卡死

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: replaceRows(_:) , sanitizedState(byReplacingRowsWith:from:) , sanitizedInteraction(_:rowCount:)
// 功能说明: 支持半受控 rows 外部回写，并在行数变化时主动清洗 preview/interaction，避免 Shared 状态残留在失效行上。
func replaceRows(_ newRows: [PianoRowState]) {
    guard componentState.rows != newRows else {
        return
    }

    let hadActiveInteraction = componentState.activeInteraction != nil
    componentState = sanitizedState(
        byReplacingRowsWith: newRows,
        from: componentState
    )

    if hadActiveInteraction, componentState.activeInteraction == nil {
        activeTouch = nil
        lastTrackedLocationInView = nil
    }

    applyBackingState()
}

func sanitizedState(
    byReplacingRowsWith rows: [PianoRowState],
    from currentState: PianoComponentState
) -> PianoComponentState {
    var nextState = currentState
    nextState.rows = rows
    nextState.preview = sanitizedPreview(
        currentState.preview,
        rowCount: rows.count
    )
    nextState.activeInteraction = sanitizedInteraction(
        currentState.activeInteraction,
        rowCount: rows.count
    )
    return nextState
}

func sanitizedInteraction(
    _ interaction: PianoInteractionState?,
    rowCount: Int
) -> PianoInteractionState? {
    guard let interaction else {
        return nil
    }

    switch interaction {
    case let .buttonPressed(interaction):
        guard (0..<rowCount).contains(interaction.rowIndex) else {
            return nil
        }
        return .buttonPressed(interaction)
    case let .scaleDrag(interaction):
        guard (0..<rowCount).contains(interaction.rowIndex),
              interaction.hasConsistentAffectedRows,
              interaction.affectedRowIndices.allSatisfy({ rowIndex in
                  (0..<rowCount).contains(rowIndex)
              }) else {
            return nil
        }
        return .scaleDrag(interaction)
    case let .keyGlissando(interaction):
        guard (0..<rowCount).contains(interaction.rowIndex),
              interaction.currentPreview.rowIndex == interaction.rowIndex else {
            return nil
        }
        return .keyGlissando(interaction)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: handleRawTouchEvent(from:phase:) , resolvedTrackedTouch(from:phase:)
// 功能说明: 通过 activeTouch 锁定单指输入序列，并在 ended/cancelled 丢失当前 UITouch 时用上一次点位补发结束事件。
func handleRawTouchEvent(
    from touches: Set<UITouch>,
    phase: PianoEventPhase
) {
    guard let touch = resolvedTrackedTouch(
        from: touches,
        phase: phase
    ) else {
        if phase == .ended || phase == .cancelled {
            if let lastTrackedLocationInView {
                handleRawEvent(
                    PianoRawEvent(
                        phase: phase,
                        locationInView: lastTrackedLocationInView
                    )
                )
            }
            activeTouch = nil
            lastTrackedLocationInView = nil
        }
        return
    }

    let locationInView = touch.location(in: self)
    lastTrackedLocationInView = locationInView
    let rawEvent = PianoRawEvent(
        phase: phase,
        locationInView: locationInView
    )
    handleRawEvent(rawEvent)

    if phase == .ended || phase == .cancelled {
        activeTouch = nil
        lastTrackedLocationInView = nil
    }
}

func resolvedTrackedTouch(
    from touches: Set<UITouch>,
    phase: PianoEventPhase
) -> UITouch? {
    switch phase {
    case .began:
        guard activeTouch == nil, let touch = touches.first else {
            return nil
        }
        activeTouch = touch
        return touch
    case .moved, .ended, .cancelled:
        guard let activeTouch else {
            return nil
        }
        return touches.first(where: { $0 === activeTouch })
    }
}
```

## 修改 4：说明工程接入方式

### 修改前

- 这轮新增了 `Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- 但没有手动改 `xcodeproj`
- 这里需要如实说明原因，避免后续回看记录时误以为漏改工程文件

### 修改后

- 当前工程使用文件系统同步 group
- 因此新增的 `iOSPianoKeyboardView.swift` 会被工程自动感知，不需要手工修改 `project.pbxproj`

```text
// 文件路径: NoteMaster_Ver_1.xcodeproj/project.pbxproj
// 函数名/符号: PBXFileSystemSynchronizedRootGroup, fileSystemSynchronizedGroups
// 功能说明: 工程采用文件系统同步 group，因此阶段 5 新增的 iOS 文件无需手工加入 xcodeproj。
/* Begin PBXFileSystemSynchronizedRootGroup section */
    isa = PBXFileSystemSynchronizedRootGroup;
/* End PBXFileSystemSynchronizedRootGroup section */

fileSystemSynchronizedGroups = (
    // ... 工程启用文件系统同步 ...
)
```

## 验证结果

- 本轮已执行 `ReadLints` 检查：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- 结果：无 linter 报错
- 本轮尝试探测 iOS 命令行 SDK：
- `xcrun --show-sdk-path --sdk iphonesimulator`
- 结果：当前机器没有 `iphonesimulator` SDK，无法在这轮做 UIKit 侧命令行 typecheck
- 本轮未做控制器接入或真机/模拟器运行时验证；这些仍留待后续阶段联调

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: 阶段 5 验证结论
// 功能说明: 当前阶段以平台壳层代码落地和静态检查为主，未进入控制器或设备运行时联调。
- ReadLints: 无报错
- iOS SDK 探测: `iphonesimulator` 不可用
- UIKit 命令行 typecheck: 本轮未执行
- 控制器/运行时联调: 本轮未执行
```

## 阶段 5 收口说明

- 这一轮严格停留在 `iOS UIView` 薄壳，没有提前做控制器级 demo
- 当前钢琴组件已经具备：
- Shared：`state + geometry + reducer + layer`
- iOS：`UIView + raw touch + reducer bridge + semantic callbacks`
- 下一阶段可以直接按相同语义补 `macOS` 的 `NSView` 薄壳

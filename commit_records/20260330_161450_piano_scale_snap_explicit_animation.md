# 20260330_161450_piano_scale_snap_explicit_animation

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_161450`
- 记录范围：为钢琴 `B` 区拖动结束新增“先保留连续位置，再做显式短动画吸附到最近锚点”的实现
- 本次目标：在不改变现有 `rows -> scene -> rowLayer.scene` 渲染链、不把时间轴塞进 reducer 的前提下，让 `snapEnabled` 从“结束瞬间跳到锚点”改成“结束时先停在连续位置，再由 shared layer 做短动画收口”
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift`（新增）
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `.cursor/plans/钢琴吸附动画_b82263f8.plan.md`（计划文件不计入本次功能记录）

## 本次结论

- 修改前，`snapEnabled` 开启时，`B` 区拖动一结束就会直接把 `rows` 归一化成最近锚点
- 这会让视觉表现变成“立刻跳到 snapped 位置”
- 修改后，`snapEnabled` 开启时的结束流程变成两段：
- 第 1 段：reducer 先保留拖动结束时的连续 `finalRows`
- 第 2 段：reducer 额外输出一个 `animateScaleSnap` 命令，由 shared `PianoKeyboardLayer` 在 `0.12s` 内做显式短动画收口
- 动画完成后，平台 view wrapper 才真正把最终的 snapped rows 提交回组件状态并发出最终 `rowsChanged`
- 这样视觉上不再是抬手瞬间跳变，而是先停住，再快速吸附到最近半音锚点

## 修改前的问题

- 修改前，`finalizeScaleDrag(...)` 在 `snapEnabled == true` 时会直接调用 `normalizeRowsAfterScaleDrag(...)`
- 然后把 `nextState.rows` 立即写成 snapped rows
- 也就是说：
- reducer 既决定“吸到哪里”
- 又立即把逻辑状态切到“已经吸附完成”
- 结果是：
- 用户抬手后看见的是瞬时跳变
- 平台 wrapper 没有机会在“连续位置”和“snapped 位置”之间插入显式动画
- 如果后续想加动画，只能把逻辑状态和画面状态临时分叉，容易出现 hit test 与显示不一致

## 修改 1：扩展 shared 吸附动画输出契约

### 修改前

- 修改前，`PianoReduction` 只有：
- `nextState`
- `semanticEvents`
- `needsDisplay`
- reducer 没有地方表达“这里需要做一段显示动画”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: PianoReduction
// 功能说明: 修改前 reducer 只能返回下一个逻辑状态和语义事件，不能表达显式显示命令。
struct PianoReduction: Equatable, Sendable {
    var nextState: PianoComponentState
    var semanticEvents: [PianoSemanticEvent]
    var needsDisplay: Bool

    init(
        previousState: PianoComponentState,
        nextState: PianoComponentState,
        semanticEvents: [PianoSemanticEvent]
    ) {
        self.nextState = nextState
        self.semanticEvents = semanticEvents
        self.needsDisplay = nextState != previousState || !semanticEvents.isEmpty
    }
}
```

### 修改后

- 修改后，新增：
- `PianoScaleSnapAnimationPlan`
- `PianoPresentationCommand`
- `PianoReduction.presentationCommand`
- 其中 `PianoScaleSnapAnimationPlan` 持有：
- `fromRows`
- `toRows`
- `affectedRowIndices`
- `duration`
- 这样 reducer 就可以只描述“需要从哪一组 rows 动到哪一组 rows”，而不负责真正推进时间轴

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift
// 函数名/符号: PianoScaleSnapAnimationPlan, PianoPresentationCommand
// 功能说明: 修改后 shared 层新增显式吸附动画计划与显示命令，供 reducer 与 layer / wrapper 之间传递。
struct PianoScaleSnapAnimationPlan: Equatable, Sendable {
    static let defaultDuration: TimeInterval = 0.12

    var fromRows: [PianoRowState]
    var toRows: [PianoRowState]
    var affectedRowIndices: [Int]
    var duration: TimeInterval

    var isNoOp: Bool {
        !hasConsistentRowCount || fromRows == toRows || affectedRowIndices.isEmpty
    }
}

enum PianoPresentationCommand: Equatable, Sendable {
    case animateScaleSnap(PianoScaleSnapAnimationPlan)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: PianoReduction
// 功能说明: 修改后 reducer 除了逻辑状态和语义事件外，还可以返回一个显示层要消费的 presentationCommand。
struct PianoReduction: Equatable, Sendable {
    var nextState: PianoComponentState
    var semanticEvents: [PianoSemanticEvent]
    var presentationCommand: PianoPresentationCommand?
    var needsDisplay: Bool

    init(
        previousState: PianoComponentState,
        nextState: PianoComponentState,
        semanticEvents: [PianoSemanticEvent],
        presentationCommand: PianoPresentationCommand? = nil
    ) {
        self.nextState = nextState
        self.semanticEvents = semanticEvents
        self.presentationCommand = presentationCommand
        self.needsDisplay = nextState != previousState
            || !semanticEvents.isEmpty
            || presentationCommand != nil
    }
}
```

## 修改 2：把 scale drag 结束语义改成“保留连续位置 + 输出动画计划”

### 修改前

- 修改前，`finalizeScaleDrag(...)` 会在 `snapEnabled` 开启时直接归一化 rows
- 所以结束时逻辑 state 已经是 snapped 后的状态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: finalizeScaleDrag(_:state:configuration:finalRows:)
// 功能说明: 修改前只要 snapEnabled 开启，结束时就直接把 rows 写成归一化后的 snapped rows。
static func finalizeScaleDrag(
    _ interaction: PianoScaleDragInteraction,
    state: PianoComponentState,
    configuration: PianoConfiguration,
    finalRows: [PianoRowState]
) -> PianoReduction {
    let resolvedRows: [PianoRowState]
    if configuration.snapEnabled {
        resolvedRows = normalizeRowsAfterScaleDrag(
            finalRows,
            interaction: interaction,
            configuration: configuration
        )
    } else {
        resolvedRows = finalRows
    }

    var nextState = state
    nextState.rows = resolvedRows
    nextState.activeInteraction = nil

    var semanticEvents: [PianoSemanticEvent] = []
    if resolvedRows != state.rows {
        semanticEvents.append(.rowsChanged(resolvedRows))
    }

    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: semanticEvents
    )
}
```

### 修改后

- 修改后，`snapEnabled == true` 时：
- 先计算 `snappedRows`
- 但 `nextState.rows` 仍保留为 `finalRows`
- 如果 `snappedRows != finalRows`，则输出 `.animateScaleSnap(plan)`
- 也就是说 reducer 现在只负责：
- 算出拖动结束时的连续位置
- 算出最终应该吸到的目标位置
- 把这两组数据打包给后续显示层

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: finalizeScaleDrag(_:state:configuration:finalRows:)
// 功能说明: 修改后在吸附开关开启时，结束拖动先保留连续位置，再输出 animateScaleSnap 计划，不立即提交 snapped rows。
static func finalizeScaleDrag(
    _ interaction: PianoScaleDragInteraction,
    state: PianoComponentState,
    configuration: PianoConfiguration,
    finalRows: [PianoRowState]
) -> PianoReduction {
    let resolvedRows: [PianoRowState]
    let presentationCommand: PianoPresentationCommand?
    if configuration.snapEnabled {
        let snappedRows = normalizeRowsAfterScaleDrag(
            finalRows,
            interaction: interaction,
            configuration: configuration
        )
        resolvedRows = finalRows
        if snappedRows != finalRows {
            presentationCommand = .animateScaleSnap(
                PianoScaleSnapAnimationPlan(
                    fromRows: finalRows,
                    toRows: snappedRows,
                    affectedRowIndices: interaction.affectedRowIndices
                )
            )
        } else {
            presentationCommand = nil
        }
    } else {
        resolvedRows = finalRows
        presentationCommand = nil
    }

    var nextState = state
    nextState.rows = resolvedRows
    nextState.activeInteraction = nil

    var semanticEvents: [PianoSemanticEvent] = []
    if resolvedRows != state.rows {
        semanticEvents.append(.rowsChanged(resolvedRows))
    }

    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: semanticEvents,
        presentationCommand: presentationCommand
    )
}
```

## 修改 3：新增 shared 插值 helper，按锚点像素位置生成中间帧 rows

### 修改前

- 修改前，没有任何 shared helper 用来描述“从一组连续 rows 平滑走到另一组 snapped rows”
- 如果强行加动画，只能在 layer 里逐个 key rect 手工插值，或者直接对 `startNote` 做离散跳变

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift
// 函数名/符号: (修改前不存在)
// 功能说明: 修改前 shared 层没有专门的吸附动画计划与中间帧 rows 计算 helper。
(修改前无此文件)
```

### 修改后

- 修改后，`PianoPresentationMath.rows(...)` 会：
- 基于 `fromRows` / `toRows`
- 先把每一行转成锚点的像素位置
- 再按 `easeOutCubic` 做插值
- 最后生成一组仅用于渲染的 synthetic `PianoRowState`
- 这里刻意不插值 `startNote`，而是保留 `fromRow.startNote` 作为渲染参考锚点，避免把离散音高当连续值去 lerp

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift
// 函数名: rows(for:progress:configuration:), interpolatedRow(from:to:progress:configuration:)
// 功能说明: 修改后按锚点像素位置插值，生成动画中间帧 rows，继续复用现有 rows -> scene 渲染链。
enum PianoPresentationMath {
    static func rows(
        for plan: PianoScaleSnapAnimationPlan,
        progress: CGFloat,
        configuration: PianoConfiguration
    ) -> [PianoRowState] {
        let clampedProgress = clamp(progress)
        guard clampedProgress > 0 else {
            return plan.fromRows
        }
        guard clampedProgress < 1 else {
            return plan.toRows
        }

        let easedProgress = easeOutCubic(clampedProgress)
        let affectedRowIndices = Set(plan.affectedRowIndices)
        return zip(plan.fromRows, plan.toRows).enumerated().map { index, rows in
            let (fromRow, toRow) = rows
            guard affectedRowIndices.contains(index) else {
                return toRow
            }

            return interpolatedRow(
                from: fromRow,
                to: toRow,
                progress: easedProgress,
                configuration: configuration
            )
        }
    }

    static func interpolatedRow(
        from: PianoRowState,
        to: PianoRowState,
        progress: CGFloat,
        configuration: PianoConfiguration
    ) -> PianoRowState {
        let fromAnchorX = PianoLayoutMath.noteLeadingX(
            from.startNote,
            configuration: configuration
        ) + from.offsetX
        let toAnchorX = PianoLayoutMath.noteLeadingX(
            to.startNote,
            configuration: configuration
        ) + to.offsetX
        let currentAnchorX = fromAnchorX + ((toAnchorX - fromAnchorX) * progress)
        let fromReferenceLeadingX = PianoLayoutMath.noteLeadingX(
            from.startNote,
            configuration: configuration
        )

        return PianoRowState(
            startNote: from.startNote,
            offsetX: currentAnchorX - fromReferenceLeadingX,
            movementScope: to.movementScope
        )
    }
}
```

## 修改 4：在 shared keyboard layer 中加入显式吸附动画上下文

### 修改前

- 修改前，`PianoKeyboardLayer` 只有：
- `configuration`
- `state`
- `rowLayers`
- 每次刷新时，直接拿 `state` 去构 scene
- layer 没有：
- presentation rows override
- 动画上下文
- 动画取消 / 物化逻辑

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: PianoKeyboardLayer, synchronizeSublayerState()
// 功能说明: 修改前 keyboard layer 只会基于当前 state 直接重建 scene，没有显式动画上下文。
final class PianoKeyboardLayer: CALayer {
    var configuration: PianoConfiguration = .init()
    var state: PianoComponentState = .empty
    private var rowLayers: [PianoRowLayer] = []
}

func synchronizeSublayerState() {
    let scene = PianoSceneBuilder(
        configuration: configuration,
        state: state
    ).makeScene(bounds: bounds)

    performWithoutImplicitAnimations {
        ensureRowLayerCount(scene.rows.count)
        // ... 把 rowScene 分发给 rowLayers
    }
}
```

### 修改后

- 修改后，`PianoKeyboardLayer` 增加了：
- `presentationRowsOverride`
- `activeScaleSnapAnimation`
- `scaleSnapTimer`
- `startScaleSnapAnimation(...)`
- `cancelScaleSnapAnimation(materializeCurrentFrame:)`
- `clearScaleSnapPresentationOverride()`
- 刷新 scene 时也改成优先用 `presentationRowsOverride ?? state.rows`
- 这样吸附动画的中间帧就不需要改 `PianoRowLayer` 的逐键绘制，只要把“当前帧 rows”喂给 scene builder 即可

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: PianoKeyboardLayer, startScaleSnapAnimation(_:completion:), cancelScaleSnapAnimation(materializeCurrentFrame:)
// 功能说明: 修改后 keyboard layer 持有动画计划、presentation rows 覆盖和定时驱动逻辑。
final class PianoKeyboardLayer: CALayer {
    var configuration: PianoConfiguration = .init()
    var state: PianoComponentState = .empty
    private var rowLayers: [PianoRowLayer] = []
    private var presentationRowsOverride: [PianoRowState]?
    private var activeScaleSnapAnimation: PianoActiveScaleSnapAnimation?
    private var scaleSnapTimer: Timer?

    func startScaleSnapAnimation(
        _ plan: PianoScaleSnapAnimationPlan,
        completion: @escaping ([PianoRowState]) -> Void
    ) {
        guard !plan.isNoOp else {
            clearScaleSnapPresentationOverride()
            completion(plan.toRows)
            return
        }

        _ = cancelScaleSnapAnimation(materializeCurrentFrame: false)
        activeScaleSnapAnimation = PianoActiveScaleSnapAnimation(
            plan: plan,
            startedAt: CACurrentMediaTime(),
            completion: completion
        )
        presentationRowsOverride = plan.fromRows
        invalidateSublayersForCurrentState()
        scheduleScaleSnapTimer()
    }

    @discardableResult
    func cancelScaleSnapAnimation(
        materializeCurrentFrame: Bool
    ) -> [PianoRowState]? {
        let materializedRows = materializeCurrentFrame
            ? materializedScaleSnapRows()
            : nil
        invalidateScaleSnapTimer()
        activeScaleSnapAnimation = nil
        // ... 根据是否需要物化当前帧来返回 rows
        return materializedRows
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名: synchronizeSublayerState(), resolvedRenderState(), updateScaleSnapAnimationFrame()
// 功能说明: 修改后 scene 构建优先使用 presentationRowsOverride；动画帧推进时只更新当前帧 rows，再重走既有 scene 分发逻辑。
func synchronizeSublayerState() {
    let displayState = resolvedRenderState()
    let scene = PianoSceneBuilder(
        configuration: configuration,
        state: displayState
    ).makeScene(bounds: bounds)

    performWithoutImplicitAnimations {
        ensureRowLayerCount(scene.rows.count)
        // ... 把 rowScene 分发给 rowLayers
    }
}

func resolvedRenderState() -> PianoComponentState {
    guard let presentationRowsOverride else {
        return state
    }

    return PianoComponentState(
        rows: presentationRowsOverride,
        preview: state.preview,
        activeInteraction: state.activeInteraction
    )
}

func updateScaleSnapAnimationFrame() {
    guard let activeScaleSnapAnimation else {
        invalidateScaleSnapTimer()
        return
    }

    let duration = max(activeScaleSnapAnimation.plan.duration, 0.001)
    let progress = CGFloat(
        (CACurrentMediaTime() - activeScaleSnapAnimation.startedAt) / duration
    )
    presentationRowsOverride = PianoPresentationMath.rows(
        for: activeScaleSnapAnimation.plan,
        progress: progress,
        configuration: configuration
    )
    invalidateSublayersForCurrentState()

    guard progress >= 1 else {
        return
    }

    let completion = activeScaleSnapAnimation.completion
    let finalRows = activeScaleSnapAnimation.plan.toRows
    self.activeScaleSnapAnimation = nil
    invalidateScaleSnapTimer()
    presentationRowsOverride = finalRows
    invalidateSublayersForCurrentState()
    completion(finalRows)
}
```

## 修改 5：在 iOS / macOS wrapper 中消费动画命令，并处理动画中断

### 修改前

- 修改前，两个平台 wrapper 的 `applyReduction(_:)` 都是：
- 只要有新 state 或 semantic event
- 就立即 `componentState = reduction.nextState`
- `applyBackingState()`
- `emitSemanticEvents(...)`
- 它们既不会消费显示命令，也不会在新交互开始前处理正在进行中的吸附动画

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: applyReduction(_:)
// 功能说明: 修改前 wrapper 不认识 presentationCommand，reducer 一旦给出 nextState 就会立即落到 backing layer。
func applyReduction(_ reduction: PianoReduction) {
    guard reduction.nextState != componentState || !reduction.semanticEvents.isEmpty else {
        return
    }

    componentState = reduction.nextState
    applyBackingState()
    emitSemanticEvents(reduction.semanticEvents)
}
```

### 修改后

- 修改后，两个平台 wrapper 做了三类接线：
- `applyReduction(_:)` 现在也会消费 `presentationCommand`
- 外部 `configuration` / `rows` 替换时会取消当前吸附动画
- 新一轮 `began` 到来前，如果有进行中的吸附动画，会先把当前动画帧物化成真实 rows，再继续新的 hit test / reducer
- 动画完成后，wrapper 才真正把 `plan.toRows` 提交成 `componentState.rows` 并补发最终 `rowsChanged`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: applyReduction(_:), applyPresentationCommand(_:), finalizeScaleSnapAnimation(with:)
// 功能说明: 修改后 iOS wrapper 会消费 animateScaleSnap，并在动画完成后才提交最终 snapped rows。
func applyReduction(_ reduction: PianoReduction) {
    guard reduction.nextState != componentState
        || !reduction.semanticEvents.isEmpty
        || reduction.presentationCommand != nil else {
        return
    }

    componentState = reduction.nextState
    applyBackingState()
    applyPresentationCommand(reduction.presentationCommand)
    emitSemanticEvents(reduction.semanticEvents)
}

func applyPresentationCommand(_ presentationCommand: PianoPresentationCommand?) {
    guard let presentationCommand else {
        return
    }

    switch presentationCommand {
    case let .animateScaleSnap(plan):
        pianoKeyboardLayer.startScaleSnapAnimation(plan) { [weak self] finalRows in
            self?.finalizeScaleSnapAnimation(with: finalRows)
        }
    }
}

func finalizeScaleSnapAnimation(with finalRows: [PianoRowState]) {
    guard componentState.rows != finalRows else {
        pianoKeyboardLayer.clearScaleSnapPresentationOverride()
        return
    }

    componentState.rows = finalRows
    applyBackingState()
    pianoKeyboardLayer.clearScaleSnapPresentationOverride()
    emitSemanticEvents([.rowsChanged(finalRows)])
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: handleRawEvent(_:), cancelScaleSnapAnimationForExternalStateChange(), materializeScaleSnapAnimationForNewInteractionIfNeeded()
// 功能说明: 修改后新交互开始前会先把动画当前帧物化成真实 rows；外部替换配置或 rows 时会取消吸附动画，避免画面与逻辑位置分叉。
func handleRawEvent(_ rawEvent: PianoRawEvent) {
    guard !bounds.isEmpty else {
        return
    }

    if rawEvent.phase == .began {
        materializeScaleSnapAnimationForNewInteractionIfNeeded()
    }

    let geometry = PianoGeometry(
        configuration: configuration,
        state: componentState,
        bounds: bounds
    )
    // ... 继续 hitTest 和 reducer
}

func cancelScaleSnapAnimationForExternalStateChange() {
    _ = pianoKeyboardLayer.cancelScaleSnapAnimation(
        materializeCurrentFrame: false
    )
}

func materializeScaleSnapAnimationForNewInteractionIfNeeded() {
    guard let materializedRows = pianoKeyboardLayer.cancelScaleSnapAnimation(
        materializeCurrentFrame: true
    ) else {
        return
    }

    componentState.rows = materializedRows
    applyBackingState()
    pianoKeyboardLayer.clearScaleSnapPresentationOverride()
    emitSemanticEvents([.rowsChanged(materializedRows)])
}
```

- macOS wrapper 做了同样的接线，只是保留了现有的坐标归一化与 resize 刷新路径

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: applyReduction(_:), applyPresentationCommand(_:), materializeScaleSnapAnimationForNewInteractionIfNeeded()
// 功能说明: 修改后 macOS wrapper 与 iOS 保持同样的显式吸附动画消费和中断物化策略。
func applyReduction(_ reduction: PianoReduction) {
    guard reduction.nextState != componentState
        || !reduction.semanticEvents.isEmpty
        || reduction.presentationCommand != nil else {
        return
    }

    componentState = reduction.nextState
    applyBackingState()
    applyPresentationCommand(reduction.presentationCommand)
    emitSemanticEvents(reduction.semanticEvents)
}

func materializeScaleSnapAnimationForNewInteractionIfNeeded() {
    guard let materializedRows = pianoKeyboardLayer.cancelScaleSnapAnimation(
        materializeCurrentFrame: true
    ) else {
        return
    }

    componentState.rows = materializedRows
    applyBackingState()
    pianoKeyboardLayer.clearScaleSnapPresentationOverride()
    emitSemanticEvents([.rowsChanged(materializedRows)])
}
```

## 修改 6：更新 validation，校验新语义和插值 helper

### 修改前

- 修改前，`validateScaleDragLifecycle()` 的断言还是：
- 结束时 `rows` 已经被 snapped
- 没有任何 fixture 专门检查：
- `presentationCommand`
- 吸附动画计划的 `fromRows / toRows`
- 中间帧插值是否按锚点像素位置推进

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateScaleDragLifecycle()
// 功能说明: 修改前验证仍然假定 snapEnabled 开启时，scale 结束后 rows 会立刻变成 snapped 状态。
if endedReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .b, octave: 3)
    || endedReduction.nextState.rows[0].offsetX != 0 {
    issues.append(issue(fixtureName, "snapEnabled 开启时，第一行右拖结束后应归一化到 B3 且 offsetX 为 0。"))
}
if endedReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .b, octave: 2)
    || endedReduction.nextState.rows[1].offsetX != 0 {
    issues.append(issue(fixtureName, "cascade 结束时第二行也应同步归一化到 B2。"))
}
```

### 修改后

- 修改后，`validateScaleDragLifecycle()` 改成断言：
- 结束时先保留 `finalRows`
- `presentationCommand` 必须是 `.animateScaleSnap`
- plan 的终点必须是 snapped rows
- 受影响行和时长也必须正确
- 同时新增 `validateScaleSnapPresentationInterpolation()`，单独校验：
- `progress = 0`
- `progress = 0.5`
- `progress = 1`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改后新增专门的吸附动画夹具，并把手工回归清单改成“先停留连续位置，再短动画收口”的语义。
PianoValidationFixture(
    name: "scale_drag_updates_rows_and_emits_snap_animation_on_finish",
    validate: validateScaleDragLifecycle
),
PianoValidationFixture(
    name: "scale_snap_presentation_interpolates_anchor_positions",
    validate: validateScaleSnapPresentationInterpolation
)

"确认 B 区连续拖动离开区域后会立即停止；开启吸附时应先保留连续位置，再以短动画收口到最近锚点。"
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateScaleDragLifecycle()
// 功能说明: 修改后验证 scale 结束时先保留连续位置，并输出 animateScaleSnap 计划，而不是立刻 snapped。
let expectedFinalRows = movedReduction.nextState.rows
if endedReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .c, octave: 4)
    || endedReduction.nextState.rows[0].offsetX != -40 {
    issues.append(issue(fixtureName, "吸附动画开始前，第一行应先保留连续拖动后的 C4 / offsetX=-40 位置。"))
}
guard case let .animateScaleSnap(plan)? = endedReduction.presentationCommand else {
    issues.append(issue(fixtureName, "snapEnabled 开启时，scale 结束后应输出 animateScaleSnap 命令。"))
    return issues
}
if plan.fromRows != expectedFinalRows {
    issues.append(issue(fixtureName, "snap plan 的 fromRows 应等于拖动结束时的连续 rows。"))
}
if plan.toRows[0].startNote != NotePitch(pitchClass: .b, octave: 3)
    || plan.toRows[0].offsetX != 0 {
    issues.append(issue(fixtureName, "snap plan 第一行终点应归一化到 B3 且 offsetX 为 0。"))
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateScaleSnapPresentationInterpolation()
// 功能说明: 修改后单独校验插值 helper 在 0 / 0.5 / 1 三个关键进度点的行为。
let startRows = PianoPresentationMath.rows(
    for: plan,
    progress: 0,
    configuration: configuration
)
let middleRows = PianoPresentationMath.rows(
    for: plan,
    progress: 0.5,
    configuration: configuration
)
let endRows = PianoPresentationMath.rows(
    for: plan,
    progress: 1,
    configuration: configuration
)

if startRows != plan.fromRows {
    issues.append(issue(fixtureName, "progress=0 时应返回原始连续位置。"))
}
if endRows != plan.toRows {
    issues.append(issue(fixtureName, "progress=1 时应返回最终 snap 目标。"))
}
if abs(actualMiddleAnchorX - expectedMiddleAnchorX) > 0.001 {
    issues.append(issue(fixtureName, "progress=0.5 时应按 easeOutCubic 在 from / to anchorX 之间插值。"))
}
```

## 本次没有改动的部分

- `PianoSceneBuilder.swift` 没改
- 因为这次仍然沿用“给 scene builder 一组 rows，就能重建整行几何”的能力
- `PianoRowLayer.swift` 没改
- 因为这次不做逐键 rect 插值，只让 layer 吃中间帧 rows
- `PianoGeometry.swift` 没改
- 因为已有 `noteLeadingX(...)` 已足够支撑锚点像素位置插值
- controller 层也没改
- 因为这次动画命令和最终 rows 提交都在 view wrapper 内完成，不需要上浮到 demo controller

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift
// 函数名/符号: makeScene(bounds:), makeRowScene(rowIndex:rowState:bounds:)
// 功能说明: 本次未修改；显式吸附动画仍然通过“中间帧 rows -> scene”这条既有链路生效。
(未修改，本次记录不重复展开代码)
```

## 验证情况

- `ReadLints`：本次修改相关文件无新增诊断
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`：通过
- 本次全量 typecheck 仍有 2 条仓库原有 warning：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次未做双平台手工 UI 回归；当前验证以静态编译、validation fixture 更新和 reducer / layer / wrapper 语义对齐为主

## 对后续调整的影响

- 现在 `snapEnabled` 的体验已经从“结束即跳变”改成“结束后短动画收口”
- 后续如果还要继续调手感，主要可以沿这三条线微调：
- `PianoScaleSnapAnimationPlan.defaultDuration`
- `PianoPresentationMath.easeOutCubic(_:)`
- `PianoKeyboardLayer` 的中断策略（例如是否在某些外部更新时物化当前帧而不是直接取消）

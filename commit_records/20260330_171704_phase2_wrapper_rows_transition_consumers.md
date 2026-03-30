# 20260330_171704_phase2_wrapper_rows_transition_consumers

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_171704`
- 记录范围：按钮步进动画方案的阶段 2，只统一 iOS / macOS wrapper 对过渡动画的消费命名与调用入口
- 本次目标：让平台层 wrapper 从“`scale snap` 专用消费接口”切换到“通用 `rows transition` 消费接口”，为下一阶段把按钮步进接入同一套动画机制做准备
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `.cursor/plans/按钮步进动画_211eb374.plan.md`（计划文件不计入本次功能记录）

## 本次结论

- 修改前，shared 层虽然已经抽象出通用 `rows transition` 命名，但 iOS / macOS wrapper 仍在使用旧的 `scale snap` 专用方法名
- 修改后，两个 wrapper 已统一改为：
- 从 `presentationCommand?.rowsTransitionPlan` 读取过渡计划
- 调用 `startRowsTransitionAnimation(...)` 启动动画
- 调用 `cancelRowsTransitionAnimation(...)` 处理中断
- 调用 `clearRowsTransitionPresentationOverride()` 清理展示态覆盖
- 这一步没有改动 reducer 语义，也没有改动当前 `B` 区吸附动画的行为时序

## 修改前的问题

- 阶段 1 只完成了 shared 层抽象，平台层 wrapper 还停留在旧命名
- 这会导致当前代码存在“shared 已通用、wrapper 仍专用”的半过渡状态
- 如果下一阶段直接让 `A` 区按钮步进复用动画，就会继续把平台层入口绑在 `scale snap` 语义上，不利于后续维护

## 修改 1：统一外部状态变化和新交互开始时的中断入口命名

### 修改前

- 修改前，wrapper 在配置更新、外部 `rows` 替换、新的 `began` 到来时，调用的仍是 `scale snap` 语义方法
- 功能上没有问题，但平台层表达的仍然是“只服务 B 区吸附动画”

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: applyConfiguration(), replaceRows(_:), handleRawEvent(_:)
// 功能说明: 修改前 iOS wrapper 在配置变化、外部 rows 替换和新交互开始时，仍通过 scale snap 命名的中断/物化入口处理动画。
func applyConfiguration() {
    cancelScaleSnapAnimationForExternalStateChange()
    pianoKeyboardLayer.configuration = configuration
    updateContentsScale()
    invalidateIntrinsicContentSize()
}

func replaceRows(_ newRows: [PianoRowState]) {
    guard componentState.rows != newRows else {
        return
    }

    cancelScaleSnapAnimationForExternalStateChange()
    // ...
}

func handleRawEvent(_ rawEvent: PianoRawEvent) {
    guard !bounds.isEmpty else {
        return
    }

    if rawEvent.phase == .began {
        materializeScaleSnapAnimationForNewInteractionIfNeeded()
    }

    // ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: applyConfiguration(), replaceRows(_:), handleRawEvent(_:)
// 功能说明: 修改前 macOS wrapper 与 iOS 一样，仍使用 scale snap 命名的中断/物化入口。
func applyConfiguration() {
    cancelScaleSnapAnimationForExternalStateChange()
    pianoKeyboardLayer.configuration = configuration
    pianoKeyboardLayer.contextNormalizationMode = resolvedContextNormalizationMode
    updateContentsScale()
    refreshPresentationForResize(displayImmediately: false)
    invalidateIntrinsicContentSize()
}

func replaceRows(_ newRows: [PianoRowState]) {
    guard componentState.rows != newRows else {
        return
    }

    cancelScaleSnapAnimationForExternalStateChange()
    // ...
}

func handleRawEvent(_ rawEvent: PianoRawEvent) {
    guard !bounds.isEmpty else {
        return
    }

    if rawEvent.phase == .began {
        materializeScaleSnapAnimationForNewInteractionIfNeeded()
    }

    // ...
}
```

### 修改后

- 修改后，平台层把这三处入口都切到通用 `rows transition` 命名
- 行为不变，仍然是：
- 配置变化时取消动画但不物化当前帧
- 外部 `rows` 替换时取消动画但不物化当前帧
- 新交互开始时物化当前展示帧，再进入新的 reducer 流程

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: applyConfiguration(), replaceRows(_:), handleRawEvent(_:)
// 功能说明: 修改后 iOS wrapper 的中断/物化入口统一改为 rows transition 命名，但保留原有时机和行为。
func applyConfiguration() {
    cancelRowsTransitionAnimationForExternalStateChange()
    pianoKeyboardLayer.configuration = configuration
    updateContentsScale()
    invalidateIntrinsicContentSize()
}

func replaceRows(_ newRows: [PianoRowState]) {
    guard componentState.rows != newRows else {
        return
    }

    cancelRowsTransitionAnimationForExternalStateChange()
    // ...
}

func handleRawEvent(_ rawEvent: PianoRawEvent) {
    guard !bounds.isEmpty else {
        return
    }

    if rawEvent.phase == .began {
        materializeRowsTransitionAnimationForNewInteractionIfNeeded()
    }

    // ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: applyConfiguration(), replaceRows(_:), handleRawEvent(_:)
// 功能说明: 修改后 macOS wrapper 同步切到 rows transition 命名，保持与 iOS 完全一致的中断策略。
func applyConfiguration() {
    cancelRowsTransitionAnimationForExternalStateChange()
    pianoKeyboardLayer.configuration = configuration
    pianoKeyboardLayer.contextNormalizationMode = resolvedContextNormalizationMode
    updateContentsScale()
    refreshPresentationForResize(displayImmediately: false)
    invalidateIntrinsicContentSize()
}

func replaceRows(_ newRows: [PianoRowState]) {
    guard componentState.rows != newRows else {
        return
    }

    cancelRowsTransitionAnimationForExternalStateChange()
    // ...
}

func handleRawEvent(_ rawEvent: PianoRawEvent) {
    guard !bounds.isEmpty else {
        return
    }

    if rawEvent.phase == .began {
        materializeRowsTransitionAnimationForNewInteractionIfNeeded()
    }

    // ...
}
```

## 修改 2：统一 presentation command 的消费入口

### 修改前

- 修改前，`applyPresentationCommand(_:)` 仍然直接匹配 `.animateScaleSnap(plan)`
- 然后调用 `startScaleSnapAnimation(...)`
- 这意味着 wrapper 仍然依赖旧的专用命令语义，而没有直接消费 shared 层已经提供的通用 `rowsTransitionPlan`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: applyPresentationCommand(_:)
// 功能说明: 修改前 iOS wrapper 仍直接匹配 animateScaleSnap，并调用旧的 scale snap 启动接口。
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: applyPresentationCommand(_:)
// 功能说明: 修改前 macOS wrapper 的命令消费方式与 iOS 一致，也仍绑定在 animateScaleSnap。
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
```

### 修改后

- 修改后，两个 wrapper 都不再直接匹配旧 case 名
- 而是统一读取 `presentationCommand?.rowsTransitionPlan`
- 然后走 `startRowsTransitionAnimation(...)`
- 这样平台层的消费入口就已经是“通用行过渡”，后续按钮步进只要产出同类 plan，就能直接复用这条链路

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: applyPresentationCommand(_:)
// 功能说明: 修改后 iOS wrapper 统一从 rowsTransitionPlan 取过渡计划，并走通用 rows transition 启动入口。
func applyPresentationCommand(_ presentationCommand: PianoPresentationCommand?) {
    guard let rowsTransitionPlan = presentationCommand?.rowsTransitionPlan else {
        return
    }

    pianoKeyboardLayer.startRowsTransitionAnimation(rowsTransitionPlan) { [weak self] finalRows in
        self?.finalizeRowsTransitionAnimation(with: finalRows)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: applyPresentationCommand(_:)
// 功能说明: 修改后 macOS wrapper 同步改为消费 rowsTransitionPlan，统一平台层对过渡命令的入口。
func applyPresentationCommand(_ presentationCommand: PianoPresentationCommand?) {
    guard let rowsTransitionPlan = presentationCommand?.rowsTransitionPlan else {
        return
    }

    pianoKeyboardLayer.startRowsTransitionAnimation(rowsTransitionPlan) { [weak self] finalRows in
        self?.finalizeRowsTransitionAnimation(with: finalRows)
    }
}
```

## 修改 3：统一动画完成回写与展示态清理命名

### 修改前

- 修改前，动画完成时的回写方法和展示态清理方法名都仍然写成 `scale snap`
- 它们实际做的是更通用的事：
- 把最终 `rows` 回写进组件状态
- 清理 layer 的 presentation override
- 对外发出 `.rowsChanged(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: finalizeScaleSnapAnimation(with:), cancelScaleSnapAnimationForExternalStateChange(), materializeScaleSnapAnimationForNewInteractionIfNeeded()
// 功能说明: 修改前 iOS wrapper 的完成回写、中断取消和新交互物化方法名都带有 scale snap 语义。
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

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: finalizeScaleSnapAnimation(with:), cancelScaleSnapAnimationForExternalStateChange(), materializeScaleSnapAnimationForNewInteractionIfNeeded()
// 功能说明: 修改前 macOS wrapper 的动画完成回写和中断处理同样仍停留在 scale snap 命名。
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

### 修改后

- 修改后，平台层这一组回写/中断/清理接口全部切到 `rows transition` 命名
- 实际时序保持不变：
- 动画结束时提交 `finalRows`
- 配置变化或外部 `rows` 替换时取消但不物化
- 新交互开始时取消并物化当前展示帧

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: finalizeRowsTransitionAnimation(with:), cancelRowsTransitionAnimationForExternalStateChange(), materializeRowsTransitionAnimationForNewInteractionIfNeeded()
// 功能说明: 修改后 iOS wrapper 的动画回写、中断处理和展示态清理统一切到 rows transition 命名，行为不变。
func finalizeRowsTransitionAnimation(with finalRows: [PianoRowState]) {
    guard componentState.rows != finalRows else {
        pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
        return
    }

    componentState.rows = finalRows
    applyBackingState()
    pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
    emitSemanticEvents([.rowsChanged(finalRows)])
}

func cancelRowsTransitionAnimationForExternalStateChange() {
    _ = pianoKeyboardLayer.cancelRowsTransitionAnimation(
        materializeCurrentFrame: false
    )
}

func materializeRowsTransitionAnimationForNewInteractionIfNeeded() {
    guard let materializedRows = pianoKeyboardLayer.cancelRowsTransitionAnimation(
        materializeCurrentFrame: true
    ) else {
        return
    }

    componentState.rows = materializedRows
    applyBackingState()
    pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
    emitSemanticEvents([.rowsChanged(materializedRows)])
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: finalizeRowsTransitionAnimation(with:), cancelRowsTransitionAnimationForExternalStateChange(), materializeRowsTransitionAnimationForNewInteractionIfNeeded()
// 功能说明: 修改后 macOS wrapper 与 iOS 一样，统一复用 rows transition 命名，便于后续按钮步进接线。
func finalizeRowsTransitionAnimation(with finalRows: [PianoRowState]) {
    guard componentState.rows != finalRows else {
        pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
        return
    }

    componentState.rows = finalRows
    applyBackingState()
    pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
    emitSemanticEvents([.rowsChanged(finalRows)])
}

func cancelRowsTransitionAnimationForExternalStateChange() {
    _ = pianoKeyboardLayer.cancelRowsTransitionAnimation(
        materializeCurrentFrame: false
    )
}

func materializeRowsTransitionAnimationForNewInteractionIfNeeded() {
    guard let materializedRows = pianoKeyboardLayer.cancelRowsTransitionAnimation(
        materializeCurrentFrame: true
    ) else {
        return
    }

    componentState.rows = materializedRows
    applyBackingState()
    pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
    emitSemanticEvents([.rowsChanged(materializedRows)])
}
```

## 验证情况

- 已检查 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift` 与 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`，无新增 linter 问题
- 已运行：`xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`
- 结果：通过
- 备注：仍有 2 条与本次无关的既有 `Fretboard` warning，本次未处理

## 对下一阶段的影响

- 到本阶段结束，平台层已经不再依赖 `scale snap` 专用入口
- 下一阶段可以直接把 `reduceButtonPress(...).ended` 产出的按钮步进结果包装成通用 `rows transition plan`
- 这样按钮步进接入时不需要再改 iOS / macOS wrapper，只需要改 shared reducer 和相关验证

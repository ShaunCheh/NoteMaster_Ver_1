# 20260330_173725_phase4_button_transition_external_replace_interrupt

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_173725`
- 记录范围：按钮步进动画方案的阶段 4，补齐按钮过渡动画在“外部 rows 覆盖”场景下的中断缺口
- 本次目标：复用前面已经铺好的通用 `rows transition` 中断策略，确保外部重新设置 `rows` 时，无论 `newRows` 是否与当前 logical rows 相等，都能先停掉正在播放的过渡动画
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

- 修改前，平台层对“新一轮 `began`”和“`configuration` 变化”已经有通用 `rows transition` 中断处理
- 但 `replaceRows(_:)` 里仍有一个顺序缺口：
- 先判断 `componentState.rows != newRows`
- 再取消动画
- 这会导致按钮动画播放期间，如果外部把“当前 logical rows”原样重新设置回来，方法会直接早退，旧的 presentation 动画不会被取消
- 修改后，iOS / macOS 两个 wrapper 都把：
- `cancelRowsTransitionAnimationForExternalStateChange()`
- 提前到相等判断之前
- 这样外部 rows 即便与当前 logical rows 相等，也会先停掉进行中的过渡动画，避免视觉层继续沿旧计划播放

## 修改前的问题

- 阶段 3 之后，按钮 `ended` 已经不再立即提交最终 rows，而是只发 `rows transition plan`
- 这意味着动画播放期间：
- `componentState.rows` 仍然保持旧的 logical rows
- 真正移动中的画面来自 `presentationRowsOverride`
- 如果此时外部 host 又调用 `rows = componentState.rows`
- 从 logical state 来看，`newRows` 与当前 `componentState.rows` 相等
- 但从视觉上看，组件仍然处在一个正在播放的过渡中间帧
- 修改前 `replaceRows(_:)` 的顺序会直接命中早退，导致：
- 外部 rows 已经重新接管逻辑状态
- 旧的按钮动画却还会继续播放
- 逻辑层与视觉层出现短暂分叉

## 修改 1：把外部 rows 覆盖的动画取消提前到相等判断之前

### 修改前

- 修改前，两个 wrapper 的 `replaceRows(_:)` 都先做“rows 是否相等”的 guard
- 只有在“不相等”时才取消当前过渡动画
- 这使得“外部原样回灌相同 rows”的覆盖路径漏掉了中断处理

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: replaceRows(_:)
// 功能说明: 修改前 iOS wrapper 先判断 rows 是否相等，再取消动画；当外部回灌相同 logical rows 时，会直接早退并遗漏动画取消。
func replaceRows(_ newRows: [PianoRowState]) {
    guard componentState.rows != newRows else {
        return
    }

    cancelRowsTransitionAnimationForExternalStateChange()
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: replaceRows(_:)
// 功能说明: 修改前 macOS wrapper 与 iOS 一样，只有在 newRows 与当前 logical rows 不同时才会取消动画。
func replaceRows(_ newRows: [PianoRowState]) {
    guard componentState.rows != newRows else {
        return
    }

    cancelRowsTransitionAnimationForExternalStateChange()
    let hadActiveInteraction = componentState.activeInteraction != nil
    componentState = sanitizedState(
        byReplacingRowsWith: newRows,
        from: componentState
    )

    if hadActiveInteraction, componentState.activeInteraction == nil {
        isMouseSequenceActive = false
    }

    applyBackingState()
}
```

### 修改后

- 修改后，两个 wrapper 都先取消当前 `rows transition`
- 然后再判断是否需要替换 logical rows
- 这样“外部 rows 相同”和“外部 rows 不同”两条路径都会先停掉当前动画
- 本次还在函数顶部补了一行注释，明确：
- 外部 rows 是权威输入
- 重新应用它时必须先清掉任何 in-flight presentation 动画

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: replaceRows(_:)
// 功能说明: 修改后 iOS wrapper 会先取消当前过渡动画，再决定是否替换 logical rows，避免外部原样回灌 rows 时遗漏中断。
func replaceRows(_ newRows: [PianoRowState]) {
    // External rows are authoritative, so reapplying them must also stop any in-flight presentation animation.
    cancelRowsTransitionAnimationForExternalStateChange()

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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: replaceRows(_:)
// 功能说明: 修改后 macOS wrapper 同步采用“先取消过渡、再判断是否需要替换 rows”的顺序，避免视觉层延续旧动画。
func replaceRows(_ newRows: [PianoRowState]) {
    // External rows are authoritative, so reapplying them must also stop any in-flight presentation animation.
    cancelRowsTransitionAnimationForExternalStateChange()

    guard componentState.rows != newRows else {
        return
    }
    let hadActiveInteraction = componentState.activeInteraction != nil
    componentState = sanitizedState(
        byReplacingRowsWith: newRows,
        from: componentState
    )

    if hadActiveInteraction, componentState.activeInteraction == nil {
        isMouseSequenceActive = false
    }

    applyBackingState()
}
```

## 修改 2：如实界定本阶段的实际落点

### 修改前

- 阶段 4 计划里提到三类中断来源：
- 新一轮 `began`
- 外部 `rows` 覆盖
- `configuration` 变化
- 但在本次修改前，其中两条链路其实已经具备：
- `handleRawEvent(_:)` 在 `rawEvent.phase == .began` 时会先物化当前过渡帧
- `applyConfiguration()` 在配置变化时已经会先取消当前过渡动画
- 真正还没补齐的是 `replaceRows(_:)` 的“相同 rows 提前 return”这一处顺序问题

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: applyConfiguration(), handleRawEvent(_:)
// 功能说明: 这些链路在本阶段之前就已经存在，本次没有额外修改；真正补的是 replaceRows 的早退顺序。
func applyConfiguration() {
    cancelRowsTransitionAnimationForExternalStateChange()
    pianoKeyboardLayer.configuration = configuration
    updateContentsScale()
    invalidateIntrinsicContentSize()
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

### 修改后

- 所以本阶段完成后的真实状态是：
- 新 `began` 之前会物化当前展示帧
- `configuration` 变化时会取消当前过渡
- 外部 `rows` 覆盖时，即使 `newRows == componentState.rows`，也会先取消当前过渡
- 也就是说，按钮动画期间的三条主要外部打断入口，平台层现在都能落到同一套通用 `rows transition` 中断语义上

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: replaceRows(_:)
// 功能说明: 阶段 4 收口后，外部 rows 覆盖路径会无条件先取消当前过渡，从而与 began / configuration 两条链路保持同一中断语义。
func replaceRows(_ newRows: [PianoRowState]) {
    // External rows are authoritative, so reapplying them must also stop any in-flight presentation animation.
    cancelRowsTransitionAnimationForExternalStateChange()

    guard componentState.rows != newRows else {
        return
    }

    // ...
}
```

## 验证情况

- 已检查 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift` 与 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`，无新增 linter 问题
- 已运行：`xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`
- 结果：通过
- 备注：仍有 2 条与本次无关的既有 `Fretboard` warning，本次未处理

## 对下一阶段的影响

- 到本阶段结束，按钮动画期间的平台层中断入口已经基本收口：
- 新交互开始前可物化当前帧
- 配置变化时可取消当前过渡
- 外部 rows 覆盖时不再遗漏“相同 rows 早退”的取消逻辑
- 下一阶段可以专注补按钮 transition 的 validation 和手工回归清单，而不需要继续改平台 wrapper 的中断入口命名或主流程

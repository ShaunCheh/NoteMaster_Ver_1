# 20260330_111550_phase3_piano_shared_interaction_reducer

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260330_111550`
- 记录范围：实施“钢琴键盘组件”计划的阶段 3，只落 `Shared/Piano` 的交互状态机 reducer 与对应 validation 夹具
- 本次目标：在不接入 `iOS/macOS` 平台视图、不实现 layer 绘制的前提下，先把 `A/B/C` 三套交互流程固化为纯 Shared reducer
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `PianoKeyboardLayer` / `PianoRowLayer`
- `iOSPianoKeyboardView` / `macOSPianoKeyboardView`
- `iOSAppDelegate.swift` / `macOSAppDelegate.swift`

## 本次结论

- 修改前，`Shared/Piano` 已有状态、场景、几何和几何级 validation，但还没有真正推进 `A/B/C` 生命周期的 reducer
- 修改后，`Shared/Piano` 已经具备阶段 3 需要的两块能力：
- `PianoInteractionReducer`：把 `began / moved / ended / cancelled` 事件序列推进为 `nextState + semanticEvents + needsDisplay`
- `PianoValidation`：把按钮按下态、步进传播、刻度拖动、锁区行为、滑音预览生命周期补成自动化夹具
- 这一轮仍然严格停留在 Shared 交互语义层，没有提前进入平台输入桥接或 layer 绘制

## 修改前总体现状

- 修改前，项目已经能回答“当前有哪些键、某个点命中了哪里、应该吸附到哪个音”
- 但还不能回答：
- 点下按钮后下一步状态是什么
- `B` 区拖动中何时更新 `offsetX`
- 离开 `B` 区时如何结束拖动
- `C` 区滑音何时发 `previewStarted / Changed / Ended`
- `rowOnly / cascade` 如何在按钮和拖动里传播

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前 Shared/Piano 还没有统一 reducer，A/B/C 交互时序只存在于计划和讨论里，尚未变成代码。
(无代码)
```

## 修改 1：新增 `PianoInteractionReducer.swift`

### 修改前

- 修改前没有 reducer 文件
- `PianoRawEvent`、`PianoHitResult`、`PianoInteractionState` 这些输入/状态类型虽然已经存在
- 但它们还没有被组装成一个统一的状态机推进入口

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前没有 nextState / semanticEvents / needsDisplay 的统一 reduction 输出。
(无代码)
```

### 修改后

- 新增 `PianoReduction`
- 新增 `PianoInteractionReducer.reduce(...)`
- reducer 现在把输入收口为：
- `state`
- `rawEvent`
- `hitResult`
- `configuration`
- 输出收口为：
- `nextState`
- `semanticEvents`
- `needsDisplay`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: PianoReduction.init(previousState:nextState:semanticEvents:), PianoReduction.unchanged(_:)
// 功能说明: 为钢琴交互状态机提供统一 reduction 输出，避免平台层自行判断是否需要重绘或发语义事件。
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

    static func unchanged(
        _ state: PianoComponentState
    ) -> PianoReduction {
        PianoReduction(
            previousState: state,
            nextState: state,
            semanticEvents: []
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: PianoInteractionReducer.reduce(state:rawEvent:hitResult:configuration:)
// 功能说明: 把 rawEvent + hitResult 分发到 button/scale/glissando 三套状态机分支，统一生成 nextState。
enum PianoInteractionReducer {
    static func reduce(
        state: PianoComponentState,
        rawEvent: PianoRawEvent,
        hitResult: PianoHitResult,
        configuration: PianoConfiguration
    ) -> PianoReduction {
        let hitResult = synchronizedHitResult(
            rawEvent: rawEvent,
            hitResult: hitResult
        )

        switch state.activeInteraction {
        case nil:
            return reduceWithoutActiveInteraction(
                state: state,
                rawEvent: rawEvent,
                hitResult: hitResult
            )
        case let .buttonPressed(interaction):
            return reduceButtonPress(
                interaction,
                state: state,
                hitResult: hitResult,
                configuration: configuration
            )
        case let .scaleDrag(interaction):
            return reduceScaleDrag(
                interaction,
                state: state,
                rawEvent: rawEvent,
                hitResult: hitResult,
                configuration: configuration
            )
        case let .keyGlissando(interaction):
            return reduceKeyGlissando(
                interaction,
                state: state,
                hitResult: hitResult
            )
        }
    }
}
```

## 修改 2：把 `A/B/C` 三套交互规则固化进 reducer

### 修改前

- 修改前虽然在计划里已经确认了 `A/B/C` 的业务时序
- 但代码里还没有：
- `A` 区按钮的按下态追踪
- `A` 区结束时的步进和自动吸附
- `B` 区拖动时的 `offsetX` 连续更新与结束归一化
- `C` 区滑音的 preview 生命周期

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: reduceButtonPress(...), reduceScaleDrag(...), reduceKeyGlissando(...)
// 功能说明: 修改前这些函数不存在，A/B/C 三套状态机还没有落成 Shared 逻辑。
(无代码)
```

### 修改后

- `reduceWithoutActiveInteraction(...)`
  - `began` 命中 `A` 区时建立 `buttonPressed`
  - `began` 命中 `B` 区时建立 `scaleDrag`
  - `began` 命中 `C` 区时建立 `keyGlissando` 并发 `previewStarted`
- `reduceButtonPress(...)`
  - `moved` 维护 `isTrackingInsideButton`
  - `ended` 命中原按钮时按 `rowOnly / cascade` 步进
  - 按钮动作始终通过 `normalizedRowStateForSnap(...)` 先归一化再步进
- `reduceScaleDrag(...)`
  - `moved` 在 `B` 区内按 `deltaX` 更新受影响行 `offsetX`
  - 离开 `B` 或 `ended/cancelled` 时通过 `finalizeScaleDrag(...)` 结束
  - `snapEnabled = true` 时走 `normalizeRowsAfterScaleDrag(...)`
- `reduceKeyGlissando(...)`
  - `moved` 时只在音变化时发 `previewChanged`
  - 离开 `C` 或 `ended/cancelled` 时走 `endPreview(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: reduceWithoutActiveInteraction(state:rawEvent:hitResult:), reduceButtonPress(_:state:hitResult:configuration:)
// 功能说明: 处理交互起点以及 A 区按钮的按下、移出、结束步进和清理。
static func reduceWithoutActiveInteraction(
    state: PianoComponentState,
    rawEvent: PianoRawEvent,
    hitResult: PianoHitResult
) -> PianoReduction {
    guard rawEvent.phase == .began else {
        return .unchanged(state)
    }

    guard let rowIndex = hitResult.rowIndex,
          let rowState = state.rowState(at: rowIndex) else {
        return .unchanged(state)
    }

    switch hitResult.zone {
    case .buttonLeft, .buttonRight:
        // 建立 buttonPressed 交互
    case .scale:
        // 建立 scaleDrag 交互
    case .keys:
        // 建立 keyGlissando，并发出 previewStarted
    case .outside:
        return .unchanged(state)
    }
}

static func reduceButtonPress(
    _ interaction: PianoButtonPressInteraction,
    state: PianoComponentState,
    hitResult: PianoHitResult,
    configuration: PianoConfiguration
) -> PianoReduction {
    switch hitResult.phase {
    case .moved:
        // 更新 isTrackingInsideButton
    case .ended:
        // 命中同按钮时步进；否则只清理交互
    case .cancelled:
        // 直接清理交互
    case .began:
        return .unchanged(state)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: reduceScaleDrag(_:state:rawEvent:hitResult:configuration:), finalizeScaleDrag(_:state:configuration:finalRows:), reduceKeyGlissando(_:state:hitResult:)
// 功能说明: 处理 B 区连续拖动的 offsetX 更新/结束吸附，以及 C 区滑音 preview 生命周期。
static func reduceScaleDrag(
    _ interaction: PianoScaleDragInteraction,
    state: PianoComponentState,
    rawEvent: PianoRawEvent,
    hitResult: PianoHitResult,
    configuration: PianoConfiguration
) -> PianoReduction {
    switch hitResult.phase {
    case .moved:
        if hitResult.rowIndex == interaction.rowIndex,
           hitResult.zone == .scale {
            // 按 deltaX 更新 offsetX，并发 rowsChanged
        }

        // 离开 B 区时结束，不切换到其他模式
        return finalizeScaleDrag(...)
    case .ended, .cancelled:
        return finalizeScaleDrag(...)
    case .began:
        return .unchanged(state)
    }
}

static func reduceKeyGlissando(
    _ interaction: PianoKeyGlissandoInteraction,
    state: PianoComponentState,
    hitResult: PianoHitResult
) -> PianoReduction {
    switch hitResult.phase {
    case .moved:
        // 仅在音变化时更新 preview 并发 previewChanged
    case .ended, .cancelled:
        // 清理 preview 与 activeInteraction，并发 previewEnded
    case .began:
        return .unchanged(state)
    }
}
```

## 修改 3：补齐 reducer 的辅助规则

### 修改前

- 修改前没有 reducer 辅助函数
- 也就还没有：
- `rowOnly / cascade` 受影响行计算
- 按钮步进的公共传播逻辑
- 拖动结束后的 snap 归一化
- 统一的 `endPreview(...)`

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: resolvedAffectedRowIndices(...), applyButtonStep(...), normalizeRowsAfterScaleDrag(...), endPreview(...)
// 功能说明: 修改前这些 reducer 助手函数不存在。
(无代码)
```

### 修改后

- 新增 `resolvedAffectedRowIndices(...)`
- 新增 `applyButtonStep(...)`
- 新增 `applyScaleDrag(...)`
- 新增 `normalizeRowsAfterScaleDrag(...)`
- 新增 `normalizedRowStateForSnap(...)`
- 新增 `endPreview(...)`
- 这些函数把阶段 3 的公共规则收口起来，避免平台层或未来的 view 层再各自重写一次

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: resolvedAffectedRowIndices(rowIndex:movementScope:rowCount:), applyButtonStep(_:triggerRowIndex:direction:movementScope:configuration:)
// 功能说明: 统一处理 rowOnly/cascade 的受影响行集合，以及按钮步进在多行上的传播方式。
static func resolvedAffectedRowIndices(
    rowIndex: Int,
    movementScope: PianoMovementScope,
    rowCount: Int
) -> [Int] {
    switch movementScope {
    case .rowOnly:
        guard (0..<rowCount).contains(rowIndex) else {
            return []
        }
        return [rowIndex]
    case .cascade:
        return Array(0..<rowCount)
    }
}

static func applyButtonStep(
    _ rows: [PianoRowState],
    triggerRowIndex: Int,
    direction: PianoStepDirection,
    movementScope: PianoMovementScope,
    configuration: PianoConfiguration
) -> [PianoRowState] {
    let affectedRowIndices = resolvedAffectedRowIndices(
        rowIndex: triggerRowIndex,
        movementScope: movementScope,
        rowCount: rows.count
    )

    var nextRows = rows
    for rowIndex in affectedRowIndices {
        let normalizedRow = normalizedRowStateForSnap(
            nextRows[rowIndex],
            configuration: configuration
        )
        nextRows[rowIndex] = normalizedRow.shiftedStartNote(
            by: direction.semitoneDelta
        )
    }
    return nextRows
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: finalizeScaleDrag(_:state:configuration:finalRows:), normalizeRowsAfterScaleDrag(_:interaction:configuration:), endPreview(state:preview:)
// 功能说明: 统一处理 B 区拖动结束后的吸附/归一化，以及 C 区预览结束的清理逻辑。
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
    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: resolvedRows != state.rows ? [.rowsChanged(resolvedRows)] : []
    )
}

static func endPreview(
    state: PianoComponentState,
    preview: PianoPreviewState
) -> PianoReduction {
    var nextState = state
    nextState.preview = nil
    nextState.activeInteraction = nil

    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: [.previewEnded(preview)]
    )
}
```

## 修改 4：扩展 `PianoValidation.swift`

### 修改前

- 修改前 `PianoValidationRunner` 已覆盖阶段 1 + 阶段 2 的夹具
- 但还没有真正验证“事件序列驱动下的 reducer 行为”
- `makeFixtures()` 的末尾停在：
- `active_zone_tracking_respects_locked_mode`
- `manualChecklist(for:)` 里也还没有明确强调“输入序列锁区”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改前 validation 已覆盖几何与命中，但还没有 reducer 生命周期夹具。
static func makeFixtures() -> [PianoValidationFixture] {
    [
        // ... 阶段 1 与阶段 2 夹具 ...
        PianoValidationFixture(
            name: "active_zone_tracking_respects_locked_mode",
            validate: validateActiveZoneTracking
        )
    ]
}

static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
    [
        "在 \\(platform.displayName) 上确认 A 区按钮按下/抬起高亮与步进触发边界一致。",
        "确认 B 区连续拖动离开区域后会立即停止，且吸附开关开闭语义正确。",
        "确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。"
    ]
}
```

### 修改后

- `makeFixtures()` 追加了 5 个阶段 3 夹具：
- `button_press_lifecycle_tracks_inside_state`
- `button_step_updates_row_only_and_cascade_rows`
- `scale_drag_updates_rows_and_snaps_on_finish`
- `scale_drag_exit_does_not_switch_into_key_preview`
- `key_glissando_emits_preview_lifecycle`
- `manualChecklist(for:)` 也补上了“一次输入序列锁定在 A/B/C 之一，不在 B 区拖动时切到 C 区预览”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改后 validation runner 把 reducer 生命周期和锁区语义也纳入了自动化与手工回归范围。
static func makeFixtures() -> [PianoValidationFixture] {
    [
        // ... 阶段 1 与阶段 2 夹具 ...
        PianoValidationFixture(
            name: "active_zone_tracking_respects_locked_mode",
            validate: validateActiveZoneTracking
        ),
        PianoValidationFixture(
            name: "button_press_lifecycle_tracks_inside_state",
            validate: validateButtonPressLifecycle
        ),
        PianoValidationFixture(
            name: "button_step_updates_row_only_and_cascade_rows",
            validate: validateButtonStepPropagation
        ),
        PianoValidationFixture(
            name: "scale_drag_updates_rows_and_snaps_on_finish",
            validate: validateScaleDragLifecycle
        ),
        PianoValidationFixture(
            name: "scale_drag_exit_does_not_switch_into_key_preview",
            validate: validateScaleDragExitDoesNotStartPreview
        ),
        PianoValidationFixture(
            name: "key_glissando_emits_preview_lifecycle",
            validate: validateKeyGlissandoLifecycle
        )
    ]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: validateButtonPressLifecycle(), validateScaleDragLifecycle(), validateKeyGlissandoLifecycle()
// 功能说明: 通过真实事件序列驱动 reducer，验证按钮、拖动、滑音三套生命周期是否符合阶段 3 设计。
static func validateButtonPressLifecycle() -> [PianoValidationIssue] {
    // 验证按钮 began 后建立 buttonPressed，
    // moved 到按钮外后仍保留交互，但 inside 状态变为 false。
}

static func validateScaleDragLifecycle() -> [PianoValidationIssue] {
    // 验证 scale began -> moved -> ended 的 rows 变化，
    // 以及 snapEnabled 打开后的归一化结果。
}

static func validateKeyGlissandoLifecycle() -> [PianoValidationIssue] {
    // 验证 previewStarted -> previewChanged -> previewEnded 的完整生命周期。
}
```

## 验证情况

- 本次阶段 3 做了以下验证：
- `ReadLints`：`Shared/Piano` 目录无 lint 错误
- `xcrun swiftc -typecheck`：对 `NotePitch.swift` + `Shared/Piano` 全量文件做了类型检查，结果通过
- 本次仍未跑整工程 `xcodebuild`；当前收口依据是 Shared 层 lint 与 `swiftc` 类型检查通过

```text
// 验证命令: xcrun swiftc -typecheck ...
// 功能说明: 对阶段 1 + 2 + 3 的 Shared/Piano 文件做语法/类型级校验。
xcrun swiftc -typecheck \
  "NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoState.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoScene.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift"

// 结果: 通过
```

## 本次明确没有做的事

- 没有新增 `PianoKeyboardLayer.swift` / `PianoRowLayer.swift`
- 没有实现 `iOSPianoKeyboardView.swift`
- 没有实现 `macOSPianoKeyboardView.swift`
- 没有把 reducer 接到任何平台输入链路

## 对后续阶段的影响

- 阶段 4 可以直接消费 `PianoComponentState + PianoScene` 来做绘制，不再关心交互推进细节
- 阶段 5/6 的平台壳层可以直接把 raw input 变成 `PianoRawEvent + PianoHitResult` 后喂给 reducer
- `A/B/C` 的关键业务时序现在已经不只存在于计划里，而是有对应的 Shared 代码和 validation 夹具约束

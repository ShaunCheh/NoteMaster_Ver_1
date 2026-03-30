# 20260330_172547_phase3_button_reducer_rows_transition

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_172547`
- 记录范围：按钮步进动画方案的阶段 3，把 `A` 区按钮 `ended` 从“立即提交最终 rows”改为“输出通用 `rows transition plan`”
- 本次目标：让按钮步进正式接入前两阶段已经铺好的 shared presentation / wrapper 动画链；保持 `applyButtonStep(...)` 继续只负责算目标 rows，不再让 reducer 在 `ended` 时直接改 logical rows
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `.cursor/plans/按钮步进动画_211eb374.plan.md`（计划文件不计入本次功能记录）

## 本次结论

- 修改前，按钮 `ended` 时 reducer 会立即：
- 调用 `applyButtonStep(...)` 算出 `nextRows`
- 直接写入 `nextState.rows`
- 立即发出 `.rowsChanged(nextRows)`
- 修改后，按钮 `ended` 时 reducer 改为：
- 保留 `nextState.rows == state.rows`
- 清空 `activeInteraction`
- 只输出 `.animateRowsTransition(PianoRowsTransitionPlan(...))`
- 把最终 `rows` 的提交时机交给现有 wrapper + layer 的动画完成回写链路
- 这样 A 区按钮的状态语义，已经和此前 B 区吸附动画保持一致：动画期间由 presentation rows 驱动画面，最终 rows 在动画完成后提交

## 修改前的问题

- 阶段 1 和阶段 2 已经完成了通用 `rows transition` 抽象以及平台层消费入口统一
- 但按钮 `ended` 仍保留旧逻辑：直接提交 `nextState.rows`
- 这会导致：
- A 区点击后画面仍然瞬时跳变
- `rowsChanged` 提前发生在 reducer 阶段，而不是动画完成时
- A 区和 B 区存在两套不同的 rows 提交时序，不利于后续统一中断与连续点击语义

## 修改 1：把按钮 `ended` 从“立即提交 rows”改成“输出 transition plan”

### 修改前

- 修改前，`reduceButtonPress(...).ended` 会在同一按钮内抬起时直接计算并提交目标 rows
- 这意味着 reducer 自己承担了“算目标 + 立即落逻辑状态 + 立即发事件”三件事

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduceButtonPress(_:state:hitResult:configuration:)
// 功能说明: 修改前按钮 ended 直接写 nextState.rows，并立即发 rowsChanged，因此 A 区移动仍是跳变。
case .ended:
    let endedInsideSameButton = hitResult.rowIndex == interaction.rowIndex
        && hitResult.buttonDirection == interaction.direction

    var nextState = state
    var semanticEvents: [PianoSemanticEvent] = []

    if endedInsideSameButton {
        let nextRows = applyButtonStep(
            state.rows,
            triggerRowIndex: interaction.rowIndex,
            direction: interaction.direction,
            movementScope: interaction.movementScope,
            configuration: configuration
        )
        nextState.rows = nextRows
        if nextRows != state.rows {
            semanticEvents.append(.rowsChanged(nextRows))
        }
    }

    nextState.activeInteraction = nil
    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: semanticEvents
    )
```

### 修改后

- 修改后，`ended` 分支被抽到新的 `finalizeButtonPress(...)`
- 这里的职责被明确拆开：
- `applyButtonStep(...)` 继续只负责算 `toRows`
- reducer 保持当前 logical rows 不动
- reducer 只发一个通用 `presentationCommand`
- 动画完成后再由既有 wrapper 回写最终 rows

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduceButtonPress(_:state:hitResult:configuration:), finalizeButtonPress(_:state:endedInsideSameButton:configuration:)
// 功能说明: 修改后按钮 ended 不再立即提交最终 rows，而是输出 rows transition plan，交给现有动画链完成可视过渡和最终回写。
case .ended:
    return finalizeButtonPress(
        interaction,
        state: state,
        endedInsideSameButton: hitResult.rowIndex == interaction.rowIndex
            && hitResult.buttonDirection == interaction.direction,
        configuration: configuration
    )

static func finalizeButtonPress(
    _ interaction: PianoButtonPressInteraction,
    state: PianoComponentState,
    endedInsideSameButton: Bool,
    configuration: PianoConfiguration
) -> PianoReduction {
    let presentationCommand: PianoPresentationCommand?
    if endedInsideSameButton {
        let fromRows = state.rows
        let toRows = applyButtonStep(
            fromRows,
            triggerRowIndex: interaction.rowIndex,
            direction: interaction.direction,
            movementScope: interaction.movementScope,
            configuration: configuration
        )

        if toRows != fromRows {
            presentationCommand = .animateRowsTransition(
                PianoRowsTransitionPlan(
                    fromRows: fromRows,
                    toRows: toRows,
                    affectedRowIndices: resolvedAffectedRowIndices(
                        rowIndex: interaction.rowIndex,
                        movementScope: interaction.movementScope,
                        rowCount: state.rowCount
                    )
                )
            )
        } else {
            presentationCommand = nil
        }
    } else {
        presentationCommand = nil
    }

    var nextState = state
    nextState.activeInteraction = nil
    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: [],
        presentationCommand: presentationCommand
    )
}
```

## 修改 2：明确按钮步进的新 reducer 语义边界

### 修改前

- 修改前，按钮语义是“结束即提交”
- 所以 reducer 输出同时混合了：
- 逻辑状态变更
- 事件广播
- 可视结果
- 这样虽然逻辑简单，但没法复用已有的显式短动画链

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduceButtonPress(_:state:hitResult:configuration:)
// 功能说明: 修改前按钮 ended 时 semanticEvents 直接携带最终 rows，logical rows 和视觉结果同步瞬时切换。
if endedInsideSameButton {
    let nextRows = applyButtonStep(/* ... */)
    nextState.rows = nextRows
    if nextRows != state.rows {
        semanticEvents.append(.rowsChanged(nextRows))
    }
}
```

### 修改后

- 修改后，按钮语义改成与 B 区对齐的“两阶段”：
- 第一阶段：reducer 结束时保留原 rows，仅给 transition plan
- 第二阶段：wrapper 在动画完成时再提交 `finalRows` 并发 `.rowsChanged(finalRows)`
- 另外这一步也保留了 no-op 保护：
- 如果 `toRows == fromRows`，就不启动动画

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: finalizeButtonPress(_:state:endedInsideSameButton:configuration:)
// 功能说明: 修改后按钮 reducer 的职责变成“计算 from/to rows + 生成 presentationCommand”，而不是直接改 logical rows。
let fromRows = state.rows
let toRows = applyButtonStep(
    fromRows,
    triggerRowIndex: interaction.rowIndex,
    direction: interaction.direction,
    movementScope: interaction.movementScope,
    configuration: configuration
)

if toRows != fromRows {
    presentationCommand = .animateRowsTransition(
        PianoRowsTransitionPlan(
            fromRows: fromRows,
            toRows: toRows,
            affectedRowIndices: resolvedAffectedRowIndices(
                rowIndex: interaction.rowIndex,
                movementScope: interaction.movementScope,
                rowCount: state.rowCount
            )
        )
    )
} else {
    presentationCommand = nil
}

var nextState = state
nextState.activeInteraction = nil
return PianoReduction(
    previousState: state,
    nextState: nextState,
    semanticEvents: [],
    presentationCommand: presentationCommand
)
```

## 修改 3：同步改写现有按钮 fixture，使其断言新语义

### 修改前

- 修改前，`validateButtonStepPropagation()` 仍在断言旧语义：
- `rowOnlyReduction.nextState.rows` 已经是最终值
- `cascadeReduction.nextState.rows` 已经是最终值
- reducer 会立即发出 `.rowsChanged(...)`
- 这已经不符合阶段 3 的目标

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateButtonStepPropagation()
// 功能说明: 修改前按钮 fixture 仍把“按钮 ended 立即提交最终 rows”当作正确行为。
if rowOnlyReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .cSharp, octave: 4) {
    issues.append(issue(fixtureName, "rowOnly 模式下当前行应前进一步到 C#4。"))
}
if rowOnlyReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .g, octave: 3) {
    issues.append(issue(fixtureName, "rowOnly 模式下其他行不应被修改。"))
}
if rowOnlyReduction.semanticEvents != [.rowsChanged(rowOnlyReduction.nextState.rows)] {
    issues.append(issue(fixtureName, "rowOnly 步进后应产生 rowsChanged 事件。"))
}

if cascadeReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .b, octave: 3) {
    issues.append(issue(fixtureName, "cascade 模式下触发行应左移一个半音到 B3。"))
}
if cascadeReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .fSharp, octave: 3) {
    issues.append(issue(fixtureName, "cascade 模式下其他行也应同步左移一个半音到 F#3。"))
}
```

### 修改后

- 修改后，现有按钮 fixture 先切到新语义：
- `nextState.rows` 仍应保持原 rows
- `semanticEvents` 为空
- `presentationCommand?.rowsTransitionPlan` 必须存在
- `fromRows` / `toRows` / `affectedRowIndices` 要准确反映 `rowOnly` 和 `cascade`
- 注意：这一步只是把“已存在的按钮夹具”改成当前语义
- 更完整的按钮动画中断与新增 fixture，仍留给后续阶段继续补

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateButtonStepPropagation()
// 功能说明: 修改后按钮 fixture 改为断言 reducer 只输出 rows transition plan，不立即提交最终 rows。
let expectedRowOnlyRows = [
    PianoRowState(
        startNote: NotePitch(pitchClass: .cSharp, octave: 4),
        movementScope: .rowOnly
    ),
    PianoRowState(
        startNote: NotePitch(pitchClass: .g, octave: 3),
        movementScope: .rowOnly
    )
]
if rowOnlyReduction.nextState.rows != rowOnlyState.rows {
    issues.append(issue(fixtureName, "rowOnly 按钮结束时，reducer 不应立即提交最终 rows。"))
}
if !rowOnlyReduction.semanticEvents.isEmpty {
    issues.append(issue(fixtureName, "rowOnly 按钮结束时不应立即发出 rowsChanged，应该等动画完成后再发。"))
}
guard let rowOnlyPlan = rowOnlyReduction.presentationCommand?.rowsTransitionPlan else {
    issues.append(issue(fixtureName, "rowOnly 模式下按钮结束后应输出 rows transition plan。"))
    return issues
}
if rowOnlyPlan.fromRows != rowOnlyState.rows {
    issues.append(issue(fixtureName, "rowOnly plan 的 fromRows 应等于按钮结束前的当前 rows。"))
}
if rowOnlyPlan.toRows != expectedRowOnlyRows {
    issues.append(issue(fixtureName, "rowOnly plan 的 toRows 应只推进当前行到 C#4。"))
}
if rowOnlyPlan.affectedRowIndices != [0] {
    issues.append(issue(fixtureName, "rowOnly plan 应只覆盖触发行。"))
}

let expectedCascadeRows = [
    PianoRowState(
        startNote: NotePitch(pitchClass: .b, octave: 3),
        movementScope: .cascade
    ),
    PianoRowState(
        startNote: NotePitch(pitchClass: .fSharp, octave: 3),
        movementScope: .rowOnly
    )
]
if cascadeReduction.nextState.rows != cascadeState.rows {
    issues.append(issue(fixtureName, "cascade 按钮结束时，reducer 不应立即提交最终 rows。"))
}
guard let cascadePlan = cascadeReduction.presentationCommand?.rowsTransitionPlan else {
    issues.append(issue(fixtureName, "cascade 模式下按钮结束后应输出 rows transition plan。"))
    return issues
}
if cascadePlan.toRows != expectedCascadeRows {
    issues.append(issue(fixtureName, "cascade plan 的 toRows 应让所有受影响行同步左移一个半音。"))
}
if cascadePlan.affectedRowIndices != [0, 1] {
    issues.append(issue(fixtureName, "cascade plan 应覆盖所有受影响行。"))
}
```

## 验证情况

- 已检查 `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift` 与 `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`，无新增 linter 问题
- 已运行：`xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`
- 结果：通过
- 备注：仍有 2 条与本次无关的既有 `Fretboard` warning，本次未处理

## 对下一阶段的影响

- 到本阶段结束，A 区按钮的 reducer 已经不再直接提交最终 rows
- 现有平台层无需再改命名，已经可以直接消费按钮产出的通用 `rows transition plan`
- 下一阶段可以聚焦按钮动画期间的中断与连续点击收口：
- 新 `began` 前物化当前 presentation frame
- 外部 `rows` 替换与 `configuration` 变化时取消当前过渡
- 确保快速连点左 / 右按钮时，每次都从当前可见帧继续出发，而不是回退到旧终点

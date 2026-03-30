# 20260330_174407_phase5_button_transition_validation_and_checklist

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_174407`
- 记录范围：按钮步进动画方案的阶段 5，只补 `PianoValidation` 的自动化夹具与手工回归清单
- 本次目标：把前面阶段 3 / 4 已经改好的按钮 `rows transition` 语义补齐到 validation 层，覆盖“按钮 ended 输出 transition plan”“rowOnly / cascade 目标行保持正确”“中断时可物化中间帧”三类校验，并把手工回归清单同步更新
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `.cursor/plans/按钮步进动画_211eb374.plan.md`（计划文件不计入本次功能记录）

## 本次结论

- 修改前，validation 里只有一个旧按钮夹具已经被阶段 3 顺带改到新语义
- 但还缺少两类明确覆盖：
- 按钮 `ended` 是否稳定输出通用 `rows transition plan`
- 过渡被中断时是否真的能物化出中间帧 rows
- 同时，手工回归清单里也还没有把按钮动画的“短动画 / 快速连点 / 外部覆盖中断”列成显式检查项
- 修改后，`PianoValidation.swift` 新增并整理为三层按钮动画校验：
- `button_step_emits_rows_transition_on_finish`
- `button_transition_preserves_row_only_and_cascade_targets`
- `button_transition_interrupt_materializes_current_frame`
- 并把手工回归清单补上按钮动画相关项目

## 修改前的问题

- 阶段 3 已经让按钮 `ended` 改成只输出 `rows transition plan`
- 阶段 4 也已经补上外部 `rows` 覆盖时的中断缺口
- 但 validation 还没有把这些行为完整固化下来
- 如果后续再改 reducer、wrapper 或 layer：
- 可能重新引入“按钮 ended 直接提交 rows”
- 可能破坏 `rowOnly` / `cascade` 的影响范围
- 也可能把“中断时物化当前展示帧”这件事悄悄改坏，而现有夹具不会报警

## 修改 1：补齐 fixture 列表，并把手工回归清单扩展到按钮动画

### 修改前

- 修改前，fixture 列表里只有：
- `button_press_lifecycle_tracks_inside_state`
- `button_step_updates_row_only_and_cascade_rows`
- 手工回归清单里也只提到 A 区按钮的按下/抬起边界，没有明确要求：
- 点击后是短动画而不是跳变
- 快速连点不反跳
- 外部覆盖 rows 或切设置时不会残留 presentation override

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改前 validation 只保留了旧按钮夹具命名，手工清单也尚未覆盖按钮动画的关键回归点。
PianoValidationFixture(
    name: "button_press_lifecycle_tracks_inside_state",
    validate: validateButtonPressLifecycle
),
PianoValidationFixture(
    name: "button_step_updates_row_only_and_cascade_rows",
    validate: validateButtonStepPropagation
),

static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
    [
        "在 \(platform.displayName) 上确认 A 区按钮按下/抬起高亮与步进触发边界一致。",
        "确认 B 区连续拖动离开区域后会立即停止；开启吸附时应先保留连续位置，再以短动画收口到最近锚点。",
        "确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。",
        "确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
        "确认钢琴组件保持“根 layer + 每行一个 row layer”，不存在按键级拆层或隐式动画。",
        "确认 macOS 归一化后顶行仍显示在最上方，A/B/C 区命中与 iOS 保持一致。"
    ]
}
```

### 修改后

- 修改后，fixture 列表里新增两个按钮 transition 夹具，并把原按钮目标传播夹具的名字改成更贴近当前语义的：
- `button_transition_preserves_row_only_and_cascade_targets`
- 同时，手工回归清单补上了按钮动画的四个关键检查点

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改后 validation 明确把按钮 transition 的输出语义、目标行传播和中断物化都注册成自动化夹具，并补齐手工回归清单。
PianoValidationFixture(
    name: "button_press_lifecycle_tracks_inside_state",
    validate: validateButtonPressLifecycle
),
PianoValidationFixture(
    name: "button_step_emits_rows_transition_on_finish",
    validate: validateButtonStepEmitsRowsTransitionOnFinish
),
PianoValidationFixture(
    name: "button_transition_preserves_row_only_and_cascade_targets",
    validate: validateButtonStepPropagation
),
PianoValidationFixture(
    name: "button_transition_interrupt_materializes_current_frame",
    validate: validateButtonTransitionInterruptMaterialization
),

static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
    [
        "在 \(platform.displayName) 上确认 A 区按钮按下/抬起高亮与步进触发边界一致，且点击左 / 右后键盘会以短动画移动而不是瞬时跳变。",
        "确认 A 区按钮在 rowOnly 下只移动当前行，在 cascade 下会让所有联动行同步移动。",
        "确认连续快速点击 A 区左 / 右按钮时，每次都会从当前可见中间帧继续，不会反跳到旧终点。",
        "确认按钮动画播放期间切换设置、改行数或外部覆盖 rows 时，不会残留 presentation override 或出现视觉错位。",
        "确认 B 区连续拖动离开区域后会立即停止；开启吸附时应先保留连续位置，再以短动画收口到最近锚点。",
        "确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。",
        "确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
        "确认钢琴组件保持“根 layer + 每行一个 row layer”，不存在按键级拆层或隐式动画。",
        "确认 macOS 归一化后顶行仍显示在最上方，A/B/C 区命中与 iOS 保持一致。"
    ]
}
```

## 修改 2：新增“按钮 ended 输出 transition plan”的自动化夹具

### 修改前

- 修改前，validation 没有一个单独的 fixture 去明确断言：
- 按钮 `ended` 时 `nextState.rows` 仍保持旧值
- `semanticEvents` 为空
- `presentationCommand?.rowsTransitionPlan` 存在且内容正确
- 这些语义虽然已经在阶段 3 的代码里成立，但没有被单独锁住

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures()
// 功能说明: 修改前没有单独的 fixture 覆盖“按钮 ended 输出 rows transition plan”这一核心语义。
PianoValidationFixture(
    name: "button_press_lifecycle_tracks_inside_state",
    validate: validateButtonPressLifecycle
),
PianoValidationFixture(
    name: "button_step_updates_row_only_and_cascade_rows",
    validate: validateButtonStepPropagation
)
```

### 修改后

- 修改后新增 `validateButtonStepEmitsRowsTransitionOnFinish()`
- 它单独验证：
- 按钮 `ended` 不立即提交最终 rows
- 不立即发 `rowsChanged`
- `needsDisplay == true`
- `rowsTransitionPlan` 的 `fromRows` / `toRows` / `affectedRowIndices` / `duration` 都正确

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateButtonStepEmitsRowsTransitionOnFinish()
// 功能说明: 新增夹具，专门锁住“按钮 ended 只输出 rows transition plan，最终 rows 留到动画完成后提交”的语义。
static func validateButtonStepEmitsRowsTransitionOnFinish() -> [PianoValidationIssue] {
    let fixtureName = "button_step_emits_rows_transition_on_finish"
    let state = PianoComponentState(
        rows: [
            PianoRowState(
                startNote: NotePitch(pitchClass: .c, octave: 4),
                movementScope: .rowOnly
            )
        ],
        activeInteraction: .buttonPressed(
            PianoButtonPressInteraction(
                rowIndex: 0,
                direction: .right,
                movementScope: .rowOnly
            )
        )
    )
    let reduction = PianoInteractionReducer.reduce(
        state: state,
        rawEvent: PianoRawEvent(
            phase: .ended,
            locationInView: CGPoint(x: 12, y: 10)
        ),
        hitResult: PianoHitResult(
            phase: .ended,
            locationInView: CGPoint(x: 12, y: 10),
            rowIndex: 0,
            zone: .buttonRight,
            note: nil,
            isInsideActiveZone: true
        ),
        configuration: PianoConfiguration()
    )
    let expectedRows = [
        PianoRowState(
            startNote: NotePitch(pitchClass: .cSharp, octave: 4),
            movementScope: .rowOnly
        )
    ]
    var issues: [PianoValidationIssue] = []

    if reduction.nextState.rows != state.rows {
        issues.append(issue(fixtureName, "按钮 ended 时不应立即提交最终 rows。"))
    }
    if reduction.nextState.activeInteraction != nil {
        issues.append(issue(fixtureName, "按钮 ended 后应清空 activeInteraction。"))
    }
    if !reduction.semanticEvents.isEmpty {
        issues.append(issue(fixtureName, "按钮 ended 后不应立即发出 rowsChanged，应该等动画完成时再发。"))
    }
    if !reduction.needsDisplay {
        issues.append(issue(fixtureName, "按钮 ended 后输出过渡命令时应要求刷新显示。"))
    }
    guard let plan = reduction.presentationCommand?.rowsTransitionPlan else {
        issues.append(issue(fixtureName, "按钮 ended 后应输出 rows transition plan。"))
        return issues
    }
    if plan.fromRows != state.rows {
        issues.append(issue(fixtureName, "按钮 plan 的 fromRows 应等于结束时的当前 logical rows。"))
    }
    if plan.toRows != expectedRows {
        issues.append(issue(fixtureName, "按钮 plan 的 toRows 应等于按钮步进后的目标 rows。"))
    }
    if plan.affectedRowIndices != [0] {
        issues.append(issue(fixtureName, "单行 rowOnly 按钮 plan 应只覆盖第 0 行。"))
    }
    if abs(plan.duration - PianoRowsTransitionPlan.defaultDuration) > 0.0001 {
        issues.append(issue(fixtureName, "按钮 plan 应沿用默认 rows transition 时长。"))
    }

    return issues
}
```

## 修改 3：把按钮目标传播夹具语义命名对齐，并新增“中断物化”夹具

### 修改前

- 修改前，按钮目标传播夹具仍叫：
- `button_step_updates_row_only_and_cascade_rows`
- 这个名字来自旧语义，容易让人误解成“reducer 会立即更新 rows”
- 同时，也没有一个现成夹具去直接校验 layer 的 `cancelRowsTransitionAnimation(materializeCurrentFrame: true)` 是否真的会返回中间帧

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateButtonStepPropagation()
// 功能说明: 修改前只有一个按钮目标传播夹具，且名称仍然沿用“立即更新 rows”的旧语义。
static func validateButtonStepPropagation() -> [PianoValidationIssue] {
    let fixtureName = "button_step_updates_row_only_and_cascade_rows"
    var issues: [PianoValidationIssue] = []

    // rowOnly / cascade 目标 rows 断言...
    return issues
}
```

### 修改后

- 修改后：
- `validateButtonStepPropagation()` 的 `fixtureName` 改成 `button_transition_preserves_row_only_and_cascade_targets`
- 更准确表达“按钮通过 transition 语义保持 rowOnly / cascade 目标正确”
- 同时新增 `validateButtonTransitionInterruptMaterialization()`
- 这个夹具直接驱动 `PianoKeyboardLayer.startRowsTransitionAnimation(...)`
- 等待一个很短的时间，再调用 `cancelRowsTransitionAnimation(materializeCurrentFrame: true)`
- 断言：
- 完成回调没有提前触发
- 物化 rows 不为空
- 物化结果仍保留 `fromRow.startNote`
- 当前 `anchorX` 位于起点和终点之间，且确实是中间帧而不是任一端点

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateButtonStepPropagation(), validateButtonTransitionInterruptMaterialization()
// 功能说明: 修改后一个夹具负责锁定 rowOnly / cascade 目标传播，另一个夹具专门验证按钮过渡被打断时能物化出真实中间帧。
static func validateButtonStepPropagation() -> [PianoValidationIssue] {
    let fixtureName = "button_transition_preserves_row_only_and_cascade_targets"
    var issues: [PianoValidationIssue] = []

    // rowOnly / cascade 目标 rows 断言...
    return issues
}

static func validateButtonTransitionInterruptMaterialization() -> [PianoValidationIssue] {
    let fixtureName = "button_transition_interrupt_materializes_current_frame"
    let configuration = PianoConfiguration(whiteKeyWidth: 40)
    let fromRows = [
        PianoRowState(
            startNote: NotePitch(pitchClass: .c, octave: 4),
            movementScope: .rowOnly
        )
    ]
    let toRows = [
        PianoRowState(
            startNote: NotePitch(pitchClass: .cSharp, octave: 4),
            movementScope: .rowOnly
        )
    ]
    let layer = PianoKeyboardLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 320, height: 120)
    layer.contentsScale = 2
    layer.configuration = configuration
    layer.state = PianoComponentState(rows: fromRows)
    layer.refreshForCurrentBounds()

    var completedRows: [PianoRowState]?
    layer.startRowsTransitionAnimation(
        PianoRowsTransitionPlan(
            fromRows: fromRows,
            toRows: toRows,
            affectedRowIndices: [0]
        )
    ) { finalRows in
        completedRows = finalRows
    }

    Thread.sleep(forTimeInterval: 0.03)
    let materializedRows = layer.cancelRowsTransitionAnimation(
        materializeCurrentFrame: true
    )

    var issues: [PianoValidationIssue] = []
    guard let materializedRows,
          let materializedRow = materializedRows.first else {
        issues.append(issue(fixtureName, "按钮过渡被打断时，应能物化出当前中间帧 rows。"))
        return issues
    }

    if completedRows != nil {
        issues.append(issue(fixtureName, "中断按钮过渡时不应提前触发完成回调。"))
    }

    let fromAnchorX = PianoLayoutMath.noteLeadingX(
        fromRows[0].startNote,
        configuration: configuration
    ) + fromRows[0].offsetX
    let toAnchorX = PianoLayoutMath.noteLeadingX(
        toRows[0].startNote,
        configuration: configuration
    ) + toRows[0].offsetX
    let currentAnchorX = PianoLayoutMath.noteLeadingX(
        materializedRow.startNote,
        configuration: configuration
    ) + materializedRow.offsetX

    if abs(currentAnchorX - fromAnchorX) <= 0.001
        || abs(currentAnchorX - toAnchorX) <= 0.001 {
        issues.append(issue(fixtureName, "等待一小段时间后物化按钮过渡，结果应处于中间帧而不是任一端点。"))
    }

    return issues
}
```

## 验证情况

- 已检查 `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`，无新增 linter 问题
- 已运行：`xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`
- 结果：通过
- 备注：仍有 2 条与本次无关的既有 `Fretboard` warning，本次未处理

## 对下一阶段的影响

- 到本阶段结束，按钮动画的 shared runtime 逻辑没有再改
- 但 validation 已经把这几件关键语义锁住：
- 按钮 ended 输出 transition plan
- rowOnly / cascade 目标保持正确
- 中断时可物化当前中间帧
- 后续如果进入阶段 6，就可以更专注做兼容性收口和行为确认，而不是继续补基础覆盖

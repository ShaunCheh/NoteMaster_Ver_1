# 20260330_175102_phase6_button_transition_shared_interpolation_compat_check

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_175102`
- 记录范围：按钮步进动画方案的阶段 6，只做兼容性收口与校验补强
- 本次目标：确认 `B` 区现有吸附动画语义没有被按钮动画接入改坏，确认按钮步进继续复用 `PianoPresentationMath.rows(...)` 这套共享 anchor 插值，不需要第二套按钮动画数学，并确认 controller 层无需改动
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `.cursor/plans/按钮步进动画_211eb374.plan.md`（计划文件不计入本次功能记录）

## 本次结论

- 修改前，阶段 1 到阶段 5 已经把按钮步进接到通用 `rows transition` 链路上，也补齐了 reducer / wrapper / 中断 / validation 的大部分覆盖
- 但阶段 6 还缺一个更直接的“收口型”证明：
- 按钮步进是不是仍然在复用 `PianoPresentationMath.rows(...)` 这套共享插值
- 会不会后续有人在按钮路径里偷偷引入一套独立的按钮动画数学
- 修改后，我没有改 `PianoPresentation.swift` 和 controller 层，而是在 `PianoValidation.swift` 新增：
- `button_transition_reuses_shared_anchor_interpolation`
- 它直接用按钮步进的 `PianoRowsTransitionPlan` 走 `PianoPresentationMath.rows(...)`
- 从而把“按钮和 B 区共用一套 anchor 插值 helper”这件事锁成自动化校验

## 修改前的问题

- 现有代码阅读上已经能看出：
- `PianoRowsTransitionPlan`
- `PianoPresentationMath.rows(...)`
- `startRowsTransitionAnimation(...)`
- 这些 shared 能力已同时服务 B 区吸附和 A 区按钮步进
- 但 validation 里之前只有：
- B 区 `scale snap` 的插值夹具
- A 区按钮的 reducer 输出夹具
- A 区按钮的中断物化夹具
- 还没有一个夹具直接回答：
- “按钮过渡本身，是否就是在复用共享 anchor 插值？”

## 修改 1：在 fixture 列表中注册按钮共享插值兼容性夹具

### 修改前

- 修改前，fixture 列表里已经有 `scale_snap_presentation_interpolates_anchor_positions`
- 但没有按钮版本的共享插值夹具
- 这意味着 B 区吸附有显式插值回归保护，而 A 区按钮在这件事上仍然主要依赖代码阅读

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures()
// 功能说明: 修改前 fixture 列表只显式覆盖了 scale snap 的插值校验，还没有按钮步进复用共享插值的专门夹具。
PianoValidationFixture(
    name: "scale_snap_presentation_interpolates_anchor_positions",
    validate: validateScaleSnapPresentationInterpolation
),
PianoValidationFixture(
    name: "scale_drag_exit_does_not_switch_into_key_preview",
    validate: validateScaleDragExitDoesNotStartPreview
)
```

### 修改后

- 修改后，在 `scale snap` 插值夹具后面新增：
- `button_transition_reuses_shared_anchor_interpolation`
- 这样 A 区按钮和 B 区吸附都各有一条显式的共享插值回归保护

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures()
// 功能说明: 修改后 fixture 列表新增按钮共享插值兼容性夹具，用来锁定按钮步进继续复用现有 shared anchor 插值逻辑。
PianoValidationFixture(
    name: "scale_snap_presentation_interpolates_anchor_positions",
    validate: validateScaleSnapPresentationInterpolation
),
PianoValidationFixture(
    name: "button_transition_reuses_shared_anchor_interpolation",
    validate: validateButtonTransitionPresentationInterpolation
),
PianoValidationFixture(
    name: "scale_drag_exit_does_not_switch_into_key_preview",
    validate: validateScaleDragExitDoesNotStartPreview
)
```

## 修改 2：新增按钮共享插值夹具，直接验证复用 `PianoPresentationMath.rows(...)`

### 修改前

- 修改前，validation 没有一段代码会把“按钮步进生成的 `PianoRowsTransitionPlan`”直接喂给 `PianoPresentationMath.rows(...)`
- 所以虽然从 shared 代码结构能判断它们共用同一套 helper，但没有自动化断言锁住这层关系

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateScaleSnapPresentationInterpolation()
// 功能说明: 修改前只有 B 区 scale snap 的插值夹具，按钮路径缺少等价的共享插值验证。
static func validateScaleSnapPresentationInterpolation() -> [PianoValidationIssue] {
    let fixtureName = "scale_snap_presentation_interpolates_anchor_positions"
    let configuration = PianoConfiguration(whiteKeyWidth: 40)
    let plan = PianoScaleSnapAnimationPlan(
        fromRows: [
            PianoRowState(
                startNote: NotePitch(pitchClass: .c, octave: 4),
                offsetX: -40,
                movementScope: .cascade
            )
        ],
        toRows: [
            PianoRowState(
                startNote: NotePitch(pitchClass: .b, octave: 3),
                offsetX: 0,
                movementScope: .cascade
            )
        ],
        affectedRowIndices: [0]
    )

    // ...
    return issues
}
```

### 修改后

- 修改后新增 `validateButtonTransitionPresentationInterpolation()`
- 它用一个按钮 `rowOnly` 过渡 plan 去直接调用：
- `PianoPresentationMath.rows(for:progress:configuration:)`
- 并断言：
- `progress=0` 返回按钮触发前的 rows
- `progress=1` 返回按钮步进后的目标 rows
- 未受影响行直接保持 `toRows`
- 受影响行在 `progress=0.5` 时按 `easeOutCubic` 做共享 anchor 插值
- 受影响行的 `startNote` 仍保留 `fromRow.startNote`
- 这就把“按钮动画没有额外引入第二套按钮数学”变成了可回归的事实

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateButtonTransitionPresentationInterpolation()
// 功能说明: 新增夹具，直接验证按钮步进也复用 PianoPresentationMath.rows(...) 的共享 anchor 插值逻辑。
static func validateButtonTransitionPresentationInterpolation() -> [PianoValidationIssue] {
    let fixtureName = "button_transition_reuses_shared_anchor_interpolation"
    let configuration = PianoConfiguration(whiteKeyWidth: 40)
    let plan = PianoRowsTransitionPlan(
        fromRows: [
            PianoRowState(
                startNote: NotePitch(pitchClass: .c, octave: 4),
                movementScope: .rowOnly
            ),
            PianoRowState(
                startNote: NotePitch(pitchClass: .g, octave: 3),
                movementScope: .rowOnly
            )
        ],
        toRows: [
            PianoRowState(
                startNote: NotePitch(pitchClass: .cSharp, octave: 4),
                movementScope: .rowOnly
            ),
            PianoRowState(
                startNote: NotePitch(pitchClass: .g, octave: 3),
                movementScope: .rowOnly
            )
        ],
        affectedRowIndices: [0]
    )
    var issues: [PianoValidationIssue] = []

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
        issues.append(issue(fixtureName, "按钮过渡 progress=0 时应返回按钮触发前的原始 rows。"))
    }
    if endRows != plan.toRows {
        issues.append(issue(fixtureName, "按钮过渡 progress=1 时应返回按钮步进后的目标 rows。"))
    }
    if middleRows[1] != plan.toRows[1] {
        issues.append(issue(fixtureName, "rowOnly 按钮过渡中，未受影响行应直接保持 toRows。"))
    }

    let expectedMiddleProgress = PianoPresentationMath.easeOutCubic(0.5)
    let fromAnchorX = PianoLayoutMath.noteLeadingX(
        plan.fromRows[0].startNote,
        configuration: configuration
    ) + plan.fromRows[0].offsetX
    let toAnchorX = PianoLayoutMath.noteLeadingX(
        plan.toRows[0].startNote,
        configuration: configuration
    ) + plan.toRows[0].offsetX
    let expectedMiddleAnchorX = fromAnchorX
        + ((toAnchorX - fromAnchorX) * expectedMiddleProgress)
    let actualMiddleAnchorX = PianoLayoutMath.noteLeadingX(
        middleRows[0].startNote,
        configuration: configuration
    ) + middleRows[0].offsetX

    if middleRows[0].startNote != plan.fromRows[0].startNote {
        issues.append(issue(fixtureName, "按钮过渡插值过程中也应保留 fromRow.startNote 作为渲染参考锚点。"))
    }
    if abs(actualMiddleAnchorX - expectedMiddleAnchorX) > 0.001 {
        issues.append(issue(fixtureName, "按钮过渡 progress=0.5 时应复用共享 anchor 插值，而不是单独使用另一套按钮数学。"))
    }
    if middleRows[0].movementScope != .rowOnly {
        issues.append(issue(fixtureName, "按钮过渡插值后的目标行应保留 movementScope。"))
    }

    return issues
}
```

## 修改 3：如实确认本阶段未改动的共享插值实现与 controller 层

### 修改前

- 阶段 6 的计划里明确要求：
- 不单独写第二套按钮动画数学
- controller 层无需改动
- 这意味着本阶段的“兼容性检查”不仅要说明新增了什么，还要说明哪些核心文件仍然没动

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift
// 函数名: PianoPresentationMath.rows(...), PianoPresentationMath.interpolatedRow(...)
// 功能说明: 这一套 shared anchor 插值逻辑在本阶段前已存在，本次没有改动实现，只新增按钮侧的兼容性夹具来验证它继续被复用。
enum PianoPresentationMath {
    static func rows(
        for plan: PianoRowsTransitionPlan,
        progress: CGFloat,
        configuration: PianoConfiguration
    ) -> [PianoRowState] {
        // ...
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
        let currentAnchorX = fromAnchorX + ((toAnchorX - fromAnchorX) * clampedProgress)
        // ...
    }
}
```

### 修改后

- 本阶段结束后，`git diff` 对以下文件仍为空：
- `NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 这说明：
- 共享插值 helper 本身没有被按钮动画另外 fork 一份
- controller 层也没有被迫接任何新动画 API
- 按钮动画继续由 shared reducer + layer + wrapper 在组件内部闭环完成

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController（整文件兼容性核查）
// 功能说明: 本阶段未改动 controller 层；按钮动画不需要 controller 额外接线，仍由组件内部闭环完成。
final class iOSViewController: UIViewController {
    private static let initialPianoDemoConfiguration = PianoConfiguration(
        whiteKeyWidth: 30,
        rowHeight: 216,
        rowSpacing: 10,
        scaleAreaHeight: 28,
        buttonAreaWidth: 30,
        blackKeyWidthRatio: 0.62,
        blackKeyHeightRatio: 0.6,
        whiteKeyStyle: .borderlessSeparatedByGaps,
        snapEnabled: true
    )

    // ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController（整文件兼容性核查）
// 功能说明: 本阶段同样未改动 macOS controller；按钮动画继续停留在组件内部处理，不需要 controller 参与。
final class macOSViewController: NSViewController {
    private static let initialPianoDemoConfiguration = PianoConfiguration(
        whiteKeyWidth: 30,
        rowHeight: 216,
        rowSpacing: 10,
        scaleAreaHeight: 28,
        buttonAreaWidth: 30,
        blackKeyWidthRatio: 0.62,
        blackKeyHeightRatio: 0.6,
        whiteKeyStyle: .borderlessSeparatedByGaps,
        snapEnabled: true
    )

    // ...
}
```

## 验证情况

- 已检查 `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`，无新增 linter 问题
- 已运行：`xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`
- 结果：通过
- 备注：仍有 2 条与本次无关的既有 `Fretboard` warning，本次未处理
- 已执行：`git diff -- "NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift" "NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift" "NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift" "NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift"`
- 结果：只有 `PianoValidation.swift` 有本次改动，其余三个文件 diff 为空

## 收口结果

- 到本阶段结束，按钮步进动画方案的 1-6 阶段已全部完成
- 共享链路保持为：
- reducer 输出通用 `rows transition plan`
- wrapper 消费 `rowsTransitionPlan`
- layer 通过 `PianoPresentationMath.rows(...)` 驱动中间帧
- 动画完成后再提交最终 rows
- 其中 B 区吸附和 A 区按钮共享同一套过渡数学，controller 层不需要额外参与

# 20260402_111852_phase5_freeze_viewport_pinning_and_regression

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260402_111852`
- 记录范围：实施 `右侧音名条布局` 计划的阶段 `5`，把 viewport pinning 语义和新旧布局回归边界锁进 shared validation 与手工回归清单
- 实际落点说明：
  - 本阶段实际代码改动只发生在 `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift` 与 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift` 本轮没有继续修改，因为双平台 controller 在前序阶段已经统一读取 `exercisePresentationState.scene.requiresViewportPinnedHeight`
  - 当前阶段真正缺少的是 shared fixture 与 manual checklist 对“右侧 rail 场景”和“旧 stacked 场景”的同时覆盖
- 修改目标：
  - 新增阶段 `5` 专用 fixture，显式冻结 `verticalRail` 场景的 viewport pinning 语义
  - 同时验证旧的 `stacked fretboard -> natural note strip` 场景没有退化
  - 验证非 rail 的 `targetPrompt -> fretboard + sideBySide` 继续保持双 `weighted`，且不误触发 viewport pinning
  - 把“左指板、右竖排音名条、左右同高、首屏完整可见、strip 仍能答题”的手工回归要求写进 validation 报告
- 修改统计：`1 file changed, 281 insertions(+)`
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. `makeFixtures()`：把阶段 `5` 的 viewport pinning 夹具纳入自动化入口

- 修改前：`ExerciseCompositionValidationRunner.makeFixtures()` 已经覆盖了阶段 `0` 到阶段 `4` 的 shared contract、scene validator、answer router 等夹具，但还没有一条独立 fixture 专门冻结“右侧 rail 必须 pin viewport height、旧 stacked 不退化、普通 sideBySide 不误触发”的阶段 `5` 约束。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures()
// 功能说明: 修改前自动化夹具列表还没有阶段 5 的 viewport pinning 专项校验；rail 与 stacked 的新旧边界只分散在旧 fixture 里，没有单独冻结。
ExerciseCompositionValidationFixture(
    name: "scene_validator_rejects_duplicate_logical_surface_ids",
    validate: validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs
),
ExerciseCompositionValidationFixture(
    name: "scene_validator_restricts_vertical_rail_to_horizontal_split",
    validate: validateSceneValidatorRestrictsVerticalRailToHorizontalSplit
),
ExerciseCompositionValidationFixture(
    name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
    validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
),
ExerciseCompositionValidationFixture(
    name: "answer_router_routes_stacked_side_and_single_surface_answers",
    validate: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers
)
```

- 修改后：在 scene validator 夹具之后新增 `viewport_pinning_contracts_preserve_rail_and_stacked_layouts`，把阶段 `5` 的核心要求集中收口到一个专用 fixture。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures()
// 功能说明: 修改后自动化入口新增阶段 5 fixture，专门冻结 viewport pinning 与 rail / stacked 回归边界。
ExerciseCompositionValidationFixture(
    name: "scene_validator_rejects_duplicate_logical_surface_ids",
    validate: validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs
),
ExerciseCompositionValidationFixture(
    name: "scene_validator_restricts_vertical_rail_to_horizontal_split",
    validate: validateSceneValidatorRestrictsVerticalRailToHorizontalSplit
),
ExerciseCompositionValidationFixture(
    name: "viewport_pinning_contracts_preserve_rail_and_stacked_layouts",
    validate: validateViewportPinningContractsPreserveRailAndStackedLayouts
),
ExerciseCompositionValidationFixture(
    name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
    validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
),
ExerciseCompositionValidationFixture(
    name: "answer_router_routes_stacked_side_and_single_surface_answers",
    validate: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers
)
```

## 2. `manualChecklist(for:)`：把 rail 场景的手工回归要求正式写进报告

- 修改前：手工回归清单虽然已经覆盖 stacked / side 的基础切换、旧的底部 `natural note strip` 首屏可见性，以及平台通用的 settings / piano 回归，但还没有把阶段 `5` 计划中要求的这些点明确写进去：
  - `positionPrompt + Side` 下的右侧竖排 rail
  - 左右同高
  - 首屏完整可见
  - 切回 stacked 后 strip 不应残留为竖排
  - rail 场景下 strip 继续可答题

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.manualChecklist(for:)
// 功能说明: 修改前清单覆盖了 side/stacked 基础切换和旧底部 strip 首屏可见性，但还没有显式要求检查右侧 rail 的首屏完整可见、左右同高与持续可答题。
var checklist = [
    "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
    "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
    "确认把 `Layout Preset` 切到 `Side` 后，主视觉立即切成左右双栏，而不是被自动打回 `Stacked`。",
    "确认在 `positionPrompt` 里切到 `Composition Preset = Self` 后，页面收敛为单 `fretboard`，并且 settings 重新打开后该选择仍然保留。",
    "确认 stacked/side 的 `positionPrompt` 里，只有当前 answer surface 会响应答题；prompt-only 的 `fretboard` 点击不会误触发答题。",
    "确认单 `fretboard` 自答时，点击同音位置会走统一 answer router，并在正确反馈结束后推进到下一题。",
    "确认打开 settings 只改变 card 可见性，不会重置当前 trainer mode、page layout 或 `pianoAccessoryVisible`。",
    "确认关闭 settings 后页面恢复到关闭前的 prompt/answer 组合，不会闪回 `PageDisplayState.default`。",
    "确认 `positionPrompt` 下方的 `natural note strip` 不再被拉伸到超出首屏；无需向下滚动就能看见按钮文字。",
    "确认 `Piano Accessory Visible` 默认关闭；打开后会按当前 `Accessory Presentation` 进入 docked / floating / collapsible scene，关闭后主 prompt/answer 组合不发生漂移。",
    "确认在 `single/sequence` 下打开 `Natural Strip Visible` 时，strip 会作为 accessory surface 参与布局，但不会抢走 answer surface 角色。",
    "确认 `Collapsible` accessory 收起时，隐藏的 accessory 不可见也不可交互；重新展开后恢复到原来的 surface。",
    "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
]

switch platform {
case .iOS:
    checklist.append("在 iOS 上确认打开/关闭 settings、显示/隐藏钢琴后，scroll view 位置与触摸命中不会跳变。")
case .macOS:
    checklist.append("在 macOS 上确认 live resize、打开/关闭 settings、显示/隐藏钢琴后，主布局不会闪回到错误组合。")
case .commandLine:
    checklist.append("命令行只能覆盖 shared 夹具；settings 开关与钢琴显隐的实际视觉同步需在 App 运行时手工回归。")
}
```

- 修改后：把计划里要求的 rail 回归项直接写进 shared manual checklist；同时为 iOS / macOS 各自补上与 viewport pinning、首屏完整可见相关的平台专项检查。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.manualChecklist(for:)
// 功能说明: 修改后手工回归清单显式覆盖右侧 rail 的竖排 strip、左右同高、首屏完整可见、切回 stacked 不退化，以及双平台的 viewport pinning 观察点。
var checklist = [
    "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
    "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
    "确认把 `Layout Preset` 切到 `Side` 后，主视觉立即切成左右双栏，而不是被自动打回 `Stacked`。",
    "确认 `positionPrompt + Side` 在 `fretboardToNaturalNoteStrip` 组合下呈现为左 `fretboard`、右竖排 `natural note strip`，并且左右两块保持同高。",
    "确认在 `positionPrompt` 里切到 `Composition Preset = Self` 后，页面收敛为单 `fretboard`，并且 settings 重新打开后该选择仍然保留。",
    "确认 stacked/side 的 `positionPrompt` 里，只有当前 answer surface 会响应答题；prompt-only 的 `fretboard` 点击不会误触发答题。",
    "确认单 `fretboard` 自答时，点击同音位置会走统一 answer router，并在正确反馈结束后推进到下一题。",
    "确认打开 settings 只改变 card 可见性，不会重置当前 trainer mode、page layout 或 `pianoAccessoryVisible`。",
    "确认关闭 settings 后页面恢复到关闭前的 prompt/answer 组合，不会闪回 `PageDisplayState.default`。",
    "确认 `positionPrompt` 下方的 `natural note strip` 不再被拉伸到超出首屏；无需向下滚动就能看见按钮文字。",
    "确认右侧 rail 场景下，首屏无需额外滚动就能同时看到完整 `fretboard` 高度与竖排 `natural note strip` 按钮列。",
    "确认切回 stacked 后，`natural note strip` 仍保持底部横条形态，不会被错误保留成竖排 rail。",
    "确认右侧 rail 场景中的 `natural note strip` 继续可以答题，答对/答错反馈和题目推进逻辑不变。",
    "确认 `Piano Accessory Visible` 默认关闭；打开后会按当前 `Accessory Presentation` 进入 docked / floating / collapsible scene，关闭后主 prompt/answer 组合不发生漂移。",
    "确认在 `single/sequence` 下打开 `Natural Strip Visible` 时，strip 会作为 accessory surface 参与布局，但不会抢走 answer surface 角色。",
    "确认 `Collapsible` accessory 收起时，隐藏的 accessory 不可见也不可交互；重新展开后恢复到原来的 surface。",
    "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
]

switch platform {
case .iOS:
    checklist.append("在 iOS 上确认打开/关闭 settings、显示/隐藏钢琴后，scroll view 位置与触摸命中不会跳变。")
    checklist.append("在 iOS 上确认右侧 rail 场景开启 viewport pin 后，不会因为内容高度漂移而把竖排音名条或左侧指板推出首屏。")
case .macOS:
    checklist.append("在 macOS 上确认 live resize、打开/关闭 settings、显示/隐藏钢琴后，主布局不会闪回到错误组合。")
    checklist.append("在 macOS 上确认 live resize 过程中，右侧 rail 仍保持左右同高且首屏完整可见，不会把 `natural note strip` 或 `fretboard` 撑出 viewport。")
case .commandLine:
    checklist.append("命令行只能覆盖 shared 夹具；settings 开关与钢琴显隐的实际视觉同步需在 App 运行时手工回归。")
}
```

## 3. 新增 `validateViewportPinningContractsPreserveRailAndStackedLayouts()`：显式冻结 rail / stacked / 普通 sideBySide 三类 viewport 语义

- 修改前：在 `validateSceneValidatorRestrictsVerticalRailToHorizontalSplit()` 之后，代码会直接进入下一组 answer contract fixture；也就是说，shared validation 里还没有一个阶段 `5` 专用入口来集中验证：
  - 右侧 `verticalRail` scene 必须要求 viewport pin
  - 旧的 stacked `fretboard -> natural note strip` 仍保持 vertical mixed split
  - 普通 `targetPrompt -> fretboard + sideBySide` 继续不触发 viewport pin

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateSceneValidatorRestrictsVerticalRailToHorizontalSplit(), validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass()
// 功能说明: 修改前这里还没有阶段 5 专用的 viewport pinning fixture；rail、stacked 与普通 sideBySide 的 viewport 语义没有被集中冻结。
static func validateSceneValidatorRestrictsVerticalRailToHorizontalSplit()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "scene_validator_restricts_vertical_rail_to_horizontal_split"
    var issues: [ExerciseCompositionValidationIssue] = []

    // ... 省略 validator 相关校验 ...

    return issues
}

static func validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "shared_answer_contracts_default_position_prompt_to_same_pitch_class"
    var issues: [ExerciseCompositionValidationIssue] = []
    // ... 后续是 answer contract 校验 ...
}
```

- 修改后：新增 `validateViewportPinningContractsPreserveRailAndStackedLayouts()`，用三段场景把阶段 `5` 的语义锁死：
  - `fretboardToNaturalNoteStrip + sideBySide`：必须是左 `weighted(1)`、右 `fitContent + verticalRail`，并要求 `requiresViewportPinnedHeight == true`
  - `fretboardToNaturalNoteStrip + stacked`：必须继续是上 `weighted(1)`、下 `fitContent + horizontalStrip`，并保持 vertical mixed split 与 viewport pin
  - `targetPromptToFretboard + sideBySide`：必须继续保持双 `weighted`，且 `requiresViewportPinnedHeight == false`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateViewportPinningContractsPreserveRailAndStackedLayouts()
// 功能说明: 修改后新增阶段 5 专用 fixture，统一冻结 rail scene、旧 stacked scene 与普通 sideBySide scene 的 viewport pinning 和 mainAxisSizing 语义。
static func validateViewportPinningContractsPreserveRailAndStackedLayouts()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "viewport_pinning_contracts_preserve_rail_and_stacked_layouts"
    var issues: [ExerciseCompositionValidationIssue] = []

    let positionPromptTrainerDisplayState = TrainerDisplayState(
        exerciseMode: .positionPrompt
    )
    let railPresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .sideBySide
            )
        )
    )
    if !ExerciseSceneValidator.validate(railPresentation.scene).isEmpty {
        issues.append(
            issue(
                fixtureName,
                "右侧 rail 的 positionPrompt scene 在阶段 5 应继续通过 scene validator。"
            )
        )
    }
    switch railPresentation.scene.root {
    case let .split(axis, children):
        if axis != .horizontal {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 positionPrompt scene 在阶段 5 应保持 horizontal split。"
                )
            )
        }
        if children.count != 2
            || children[0].mainAxisSizing != .weighted(1)
            || children[1].mainAxisSizing != .fitContent {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 positionPrompt scene 在阶段 5 应保持左 weighted(1)、右 fitContent 的主轴尺寸语义。"
                )
            )
        }
        guard
            children.count == 2,
            case let .surface(promptSurface) = children[0].node,
            case let .surface(answerSurface) = children[1].node
        else {
            break
        }
        if promptSurface.id != .fretboard
            || promptSurface.presentationStyle != .standard
            || answerSurface.id != .naturalNoteStrip
            || answerSurface.presentationStyle != .verticalRail {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 positionPrompt scene 在阶段 5 应继续保持左 fretboard standard、右 natural note strip verticalRail。"
                )
            )
        }
    default:
        issues.append(
            issue(
                fixtureName,
                "右侧 rail 的 positionPrompt scene 在阶段 5 应继续落成 split scene。"
            )
        )
    }
    if !railPresentation.scene.hasMixedMainAxisSizing(along: .horizontal) {
        issues.append(
            issue(
                fixtureName,
                "右侧 rail 的 positionPrompt scene 在阶段 5 应继续触发 horizontal mixed main-axis sizing。"
            )
        )
    }
    if railPresentation.scene.hasMixedMainAxisSizing(along: .vertical) {
        issues.append(
            issue(
                fixtureName,
                "右侧 rail 的 positionPrompt scene 在阶段 5 不应误报为 vertical mixed main-axis sizing。"
            )
        )
    }
    if !railPresentation.scene.requiresViewportPinnedHeight {
        issues.append(
            issue(
                fixtureName,
                "右侧 rail 的 positionPrompt scene 在阶段 5 应继续要求 viewport pin 高度。"
            )
        )
    }

    let stackedPresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked
            )
        )
    )
    if !ExerciseSceneValidator.validate(stackedPresentation.scene).isEmpty {
        issues.append(
            issue(
                fixtureName,
                "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续通过 scene validator。"
            )
        )
    }
    switch stackedPresentation.scene.root {
    case let .split(axis, children):
        if axis != .vertical {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 应保持 vertical split。"
                )
            )
        }
        if children.count != 2
            || children[0].mainAxisSizing != .weighted(1)
            || children[1].mainAxisSizing != .fitContent {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续保持上 weighted(1)、下 fitContent 的主轴尺寸语义。"
                )
            )
        }
        guard
            children.count == 2,
            case let .surface(promptSurface) = children[0].node,
            case let .surface(answerSurface) = children[1].node
        else {
            break
        }
        if promptSurface.id != .fretboard
            || promptSurface.presentationStyle != .standard
            || answerSurface.id != .naturalNoteStrip
            || answerSurface.presentationStyle != .horizontalStrip {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续保持上方 standard fretboard、下方 horizontalStrip strip。"
                )
            )
        }
    default:
        issues.append(
            issue(
                fixtureName,
                "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续落成 split scene。"
            )
        )
    }
    if !stackedPresentation.scene.hasMixedMainAxisSizing(along: .vertical) {
        issues.append(
            issue(
                fixtureName,
                "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续触发 vertical mixed main-axis sizing。"
            )
        )
    }
    if stackedPresentation.scene.hasMixedMainAxisSizing(along: .horizontal) {
        issues.append(
            issue(
                fixtureName,
                "stacked 的 fretboard -> natural note strip scene 在阶段 5 不应误报为 horizontal mixed main-axis sizing。"
            )
        )
    }
    if !stackedPresentation.scene.requiresViewportPinnedHeight {
        issues.append(
            issue(
                fixtureName,
                "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续要求 viewport pin 高度。"
            )
        )
    }

    let targetPromptSideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
            fretboardTrainerState: .init(),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .targetPromptToFretboard,
                layoutPreset: .sideBySide
            )
        )
    )
    if !ExerciseSceneValidator.validate(
        targetPromptSideBySidePresentation.scene
    ).isEmpty {
        issues.append(
            issue(
                fixtureName,
                "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 应继续通过 scene validator。"
            )
        )
    }
    switch targetPromptSideBySidePresentation.scene.root {
    case let .split(axis, children):
        if axis != .horizontal {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 应保持 horizontal split。"
                )
            )
        }
        if children.count != 2
            || children[0].mainAxisSizing != .weighted(1)
            || children[1].mainAxisSizing != .weighted(1) {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 仍应保持双 weighted 主轴尺寸语义。"
                )
            )
        }
        guard
            children.count == 2,
            case let .surface(promptSurface) = children[0].node,
            case let .surface(answerSurface) = children[1].node
        else {
            break
        }
        if promptSurface.presentationStyle != .standard
            || answerSurface.presentationStyle != .standard {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 不应被 verticalRail 或 horizontalStrip answer 语义污染。"
                )
            )
        }
    default:
        issues.append(
            issue(
                fixtureName,
                "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 应继续落成 split scene。"
            )
        )
    }
    if targetPromptSideBySidePresentation.scene.requiresViewportPinnedHeight {
        issues.append(
            issue(
                fixtureName,
                "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 不应误触发 viewport pin 高度。"
            )
        )
    }

    return issues
}
```

## 4. 验证结果

- `ReadLints`：`NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift` 无新增 linter 问题
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'platform=macOS' build`：通过
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'generic/platform=iOS Simulator' build`：通过

## 5. 阶段边界

- 本次记录只覆盖阶段 `5` 实际发生的代码变更：shared validation fixture 与 manual checklist 扩展
- 双平台 controller 本轮没有新增 diff；它们继续沿用已有的 `exercisePresentationState.scene.requiresViewportPinnedHeight` 作为 `sceneViewportHeightConstraint` 的启用条件
- 手工视觉回归没有在本轮自动执行，只把所需检查项写进了 validation report 的 `manualChecklist`

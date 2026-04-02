# 20260402_094017_phase0_freeze_side_by_side_invariants

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260402_094017`
- 记录范围：实施 `右侧音名条布局` 计划的阶段 `0`，只补 shared validation 基线，不进入 shared scene contract、composition policy、renderer、view 或 controller 的实现改造
- 修改目标：
  - 在后续升级 `sideBySide` 布局语义之前，先冻结当前三类 `sideBySide` 组合的不变量
  - 明确当前只有 `fretboardToNaturalNoteStrip + sideBySide` 会在后续阶段进入“右侧 rail”语义升级，其它 `sideBySide` 组合此时不能被污染
  - 补强 `stacked positionPrompt` 下 `naturalNoteStrip` 仍可作为 answer surface 的 answer router 基线
- 修改统计：`1 file changed, 232 insertions(+)`
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. `makeFixtures()`：注册阶段 0 专用夹具

- 修改前：`makeFixtures()` 里已经有 `vertical_fit_content_split_sizing_tracks_surface_kinds`、`shared_surface_state_defaults_follow_surface_roles` 等通用夹具，但没有专门冻结阶段 `0` 的 `sideBySide` 组合不变量。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures()
// 功能说明: 修改前 fixtures 列表里还没有阶段 0 的 sideBySide 不变量夹具。
ExerciseCompositionValidationFixture(
    name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
    validate: validateSharedSceneContractsCoverBasicLayouts
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
),
ExerciseCompositionValidationFixture(
    name: "shared_surface_state_defaults_follow_surface_roles",
    validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
),
```

- 修改后：在现有夹具列表里注册 `phase_zero_side_by_side_invariants_preserve_composition_specific_surface_pairs`，让启动时的 validation runner 显式执行这组阶段 `0` 基线检查。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures()
// 功能说明: 修改后新增阶段 0 夹具注册，冻结 sideBySide 组合在后续 rail 改造前的 shared 不变量。
ExerciseCompositionValidationFixture(
    name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
    validate: validateSharedSceneContractsCoverBasicLayouts
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
),
ExerciseCompositionValidationFixture(
    name: "phase_zero_side_by_side_invariants_preserve_composition_specific_surface_pairs",
    validate: validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs
),
ExerciseCompositionValidationFixture(
    name: "shared_surface_state_defaults_follow_surface_roles",
    validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
),
```

## 2. `validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()`：新增阶段 0 基线函数

- 修改前：`validateVerticalFitContentSplitSizingTracksSurfaceKinds()` 结束后，代码直接进入 `validateSharedSurfaceStateDefaultsFollowSurfaceRoles()`；也就是说，仓库里还没有一个专门冻结“不同 `compositionPreset` 在 `sideBySide` 下必须保持各自 surface pair”的 validation 夹具。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateVerticalFitContentSplitSizingTracksSurfaceKinds(), validateSharedSurfaceStateDefaultsFollowSurfaceRoles()
// 功能说明: 修改前 vertical fit-content 夹具结束后，直接进入默认 surface state 夹具；阶段 0 还没有 sideBySide 专用基线函数。
static func validateVerticalFitContentSplitSizingTracksSurfaceKinds()
    -> [ExerciseCompositionValidationIssue] {
    // ... 省略未改动的 vertical split sizing 断言
    return issues
}

static func validateSharedSurfaceStateDefaultsFollowSurfaceRoles()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "shared_surface_state_defaults_follow_surface_roles"
    var issues: [ExerciseCompositionValidationIssue] = []
    // ... 省略未改动代码
}
```

- 修改后：新增 `validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()`，把阶段 `0` 需要保留的 `sideBySide` 不变量显式冻结下来。
- 新函数做了 4 类事情：
  - 用 `validateHorizontalPair(...)` 统一校验 `horizontal split`、surface 顺序和默认 `fill sizing`
  - 冻结 `fretboardToNaturalNoteStrip + sideBySide` 当前仍是左 `fretboard`、右 `naturalNoteStrip`
  - 冻结 `targetPromptToFretboard + sideBySide`、`staffToFretboard + sideBySide` 不能被混入 `naturalNoteStrip`
  - 冻结 `positionPrompt` 下 `fretboard` 仍是 `prompt-only`，`naturalNoteStrip` 仍是 `answer-only`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()
// 功能说明: 修改后新增阶段 0 夹具，冻结不同 compositionPreset 在 sideBySide 下的 scene 结构、surface 顺序、surface state 和 legacy 投影边界。
static func validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "phase_zero_side_by_side_invariants_preserve_composition_specific_surface_pairs"
    var issues: [ExerciseCompositionValidationIssue] = []

    func validateHorizontalPair(
        _ presentation: ExercisePresentationState,
        expectedSurfaceIDs: [ExerciseSurfaceID],
        sceneDescription: String,
        expectedOrderDescription: String
    ) {
        if !ExerciseSceneValidator.validate(presentation.scene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "\(sceneDescription) 在阶段 0 应继续生成合法 scene。"
                )
            )
        }

        switch presentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "\(sceneDescription) 在阶段 0 应继续投影到 horizontal split。"
                    )
                )
            }

            let childSurfaceIDs = children.compactMap {
                $0.node.surfaceNodes.first?.id
            }
            if childSurfaceIDs != expectedSurfaceIDs {
                issues.append(
                    issue(
                        fixtureName,
                        "\(sceneDescription) 在阶段 0 应继续保持 \(expectedOrderDescription)。"
                    )
                )
            }

            if children.contains(where: { $0.sizing != .fill }) {
                issues.append(
                    issue(
                        fixtureName,
                        "\(sceneDescription) 在阶段 0 仍应保持 sideBySide child 的默认 fill sizing。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "\(sceneDescription) 在阶段 0 应继续生成 split scene。"
                )
            )
        }

        if presentation.scene.hasVerticalFitContentSplit {
            issues.append(
                issue(
                    fixtureName,
                    "\(sceneDescription) 在阶段 0 不应误触发 vertical fitContent split 语义。"
                )
            )
        }
    }

    let sideBySidePositionPromptPresentation = ExerciseCompositionPolicy
        .makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt),
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
    validateHorizontalPair(
        sideBySidePositionPromptPresentation,
        expectedSurfaceIDs: [.fretboard, .naturalNoteStrip],
        sceneDescription: "positionPrompt 的 fretboard -> natural note strip sideBySide 组合",
        expectedOrderDescription: "左 fretboard、右 natural note strip"
    )

    // ... 省略未改动的 ExerciseCompositionPolicyInput 组装细节
    // 下面两组断言继续冻结其它 sideBySide 组合，防止后续 rail 语义污染 targetPrompt/staff 路径。
    validateHorizontalPair(
        sideBySideTargetPromptPresentation,
        expectedSurfaceIDs: [.targetPrompt, .fretboard],
        sceneDescription: "single 的 targetPrompt -> fretboard sideBySide 组合",
        expectedOrderDescription: "左 targetPrompt、右 fretboard"
    )
    if sideBySideTargetPromptPresentation.surfaceState(for: .naturalNoteStrip) != nil {
        issues.append(
            issue(
                fixtureName,
                "targetPrompt -> fretboard 的 sideBySide 组合在阶段 0 不应混入 natural note strip surface。"
            )
        )
    }

    validateHorizontalPair(
        sideBySideStaffPresentation,
        expectedSurfaceIDs: [.staff, .fretboard],
        sceneDescription: "sequence 的 staff -> fretboard sideBySide 组合",
        expectedOrderDescription: "左 staff、右 fretboard"
    )
    if sideBySideStaffPresentation.surfaceState(for: .naturalNoteStrip) != nil {
        issues.append(
            issue(
                fixtureName,
                "staff -> fretboard 的 sideBySide 组合在阶段 0 不应混入 natural note strip surface。"
            )
        )
    }

    return issues
}
```

## 3. `validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()`：补强 stacked positionPrompt 的 strip 路由基线

- 修改前：现有 answer router 夹具已经覆盖了 `sideBySide positionPrompt` 中 `naturalNoteStrip` 可以继续答题，也覆盖了 `stacked positionPrompt` 中 `fretboardCell` 必须被忽略；但还没有显式断言“`stacked positionPrompt` 下，`naturalNoteStrip` 仍然应该能路由成有效 answer”。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
// 功能说明: 修改前 stacked positionPrompt 只冻结了 fretboard 不应误答题，还没有冻结 strip 仍能答题的基线。
let stackedPositionPromptPresentation = ExerciseCompositionPolicy
    .makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: .legacyPositionPrompt
        )
    )
if ExerciseAnswerRouter.route(
    fretboardCellEvent,
    presentationState: stackedPositionPromptPresentation,
    trainerDisplayState: positionPromptTrainerDisplayState,
    fretboardConfiguration: fretboardConfiguration
) != .ignored(.answerDisabled(.fretboard)) {
    issues.append(
        issue(
            fixtureName,
            "stacked 的 positionPrompt 里，prompt-only fretboard 不应再被当成唯一答题入口。"
        )
    )
}
```

- 修改后：在原有“`fretboard` 不得误答题”断言之前，先补一条 “`naturalNoteStrip` 仍能被正确路由成 `positionPrompt` answer” 的显式校验，避免后续阶段在改 scene contract 或 answer surface 语义时把 stacked 路径悄悄破坏掉。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
// 功能说明: 修改后 stacked positionPrompt 同时冻结两条基线：strip 继续可答题，fretboard 继续不可误答题。
let stackedPositionPromptPresentation = ExerciseCompositionPolicy
    .makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: .legacyPositionPrompt
        )
    )
if ExerciseAnswerRouter.route(
    naturalNoteStripEvent,
    presentationState: stackedPositionPromptPresentation,
    trainerDisplayState: positionPromptTrainerDisplayState,
    fretboardConfiguration: fretboardConfiguration
) != .routed(
    .positionPrompt(
        ExercisePositionPromptRoutedAnswer(
            event: naturalNoteStripEvent,
            pitchClass: .e
        )
    )
) {
    issues.append(
        issue(
            fixtureName,
            "上下布局中的 positionPrompt 应继续允许 natural note strip 作为 answer surface。"
        )
    )
}
if ExerciseAnswerRouter.route(
    fretboardCellEvent,
    presentationState: stackedPositionPromptPresentation,
    trainerDisplayState: positionPromptTrainerDisplayState,
    fretboardConfiguration: fretboardConfiguration
) != .ignored(.answerDisabled(.fretboard)) {
    issues.append(
        issue(
            fixtureName,
            "stacked 的 positionPrompt 里，prompt-only fretboard 不应再被当成唯一答题入口。"
        )
    )
}
```

## 验证结果

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`：无新增 lint
- 构建验证：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'platform=macOS' build`：通过
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'generic/platform=iOS Simulator' build`：通过

## 阶段 0 完成状态

- 已完成：shared validation 基线冻结
- 未开始：`ExerciseScene` shared contract 升级、`ExerciseCompositionPolicy` rail 语义投影、renderer 主轴尺寸分配、双平台 `NaturalNoteStripView` 竖排实现

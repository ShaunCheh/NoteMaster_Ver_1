# 20260415_165707_stage6_validation_sr2_seam_runtime_smoke

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_165707`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat`、按文件分组的 `git diff --unified=16`、当前文件内容，以及本轮 lint / build / runtime smoke 结果整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 6”真实落地的代码改动；目标是补齐 `SR-1` / `SR-2` 的 validation 合同，并把 `SR-2 seam` 与双端 `runtime smoke` 真正封口
- 重要说明：本轮验证过程中先暴露出一个真实 shared 回归点：`ExerciseCompositionPolicy.makeLegacyCompatiblePresentation(...)` 在 `SR` 模式下会被 fixed layout 与 `pianoPanelState.isVisible` 重新拉回非 legacy 结果；因此下文除了新增 validation / smoke 外，也如实记录了这次根因修复
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`12 files changed, 1171 insertions(+), 15 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 12 个 `Swift` 文件，因此本次统计口径直接等同于阶段 6 本轮改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `12 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 验证结果：
- `ReadLints`：对本轮 12 个改动文件读取诊断，无错误
- 首次把 `DerivedDataStage6-*` 放在工作区根目录执行 `xcodebuild` 时，macOS 与 iOS 都在 `CodeSign ... resource fork, Finder information, or similar detritus not allowed` 失败；失败原因为 iCloud 工作区下构建产物签名污染，不是 Swift 编译错误
- 改为 `xcodebuild -scheme "NoteMaster_Ver_1" -configuration Debug -derivedDataPath "/tmp/NoteMasterStage6-mac-build" build`：构建通过
- 改为 `xcodebuild -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath "/tmp/NoteMasterStage6-ios-build" build`：构建通过
- `ExerciseCompositionValidationRunner` 启动验证：macOS / iOS 均为 `automated=PASS fixtures=30`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：macOS 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：iOS Simulator 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr1判题分阶段_3443803b.plan.md`
- 没有创建额外文档，除本记录文件外不新增其它 markdown
- 没有提交代码

## 本次结论

- 阶段 6 的 exercise validation 总入口已经补上 `SR-1` / `SR-2` 专项夹具，并补了对应手工回归清单
- `staffToPiano` 的 shared scene 合同被正式锁死：`staff` 必须 prompt-only，`piano` 必须 answer-only，且 `legacyPageDisplayState == nil` 在 SR 主场景下是允许且预期的
- `makeLegacyCompatiblePresentation(...)` 的显式 legacy fallback 已从根因上修正，不会再被 `SR` fixed layout 与 accessory piano 重新拉回非 legacy 结果
- settings/navigation validation 已锁住 `SR-1` 的 root tree 收敛、隐藏项、选中态和失效 route fallback
- `FretboardValidation` 已把 `TrainerDisplayState(.sr1/.sr2)` 到 `resolvedSequenceConfiguration` 的 seam 正式纳入 shared comparator 验证，后续开放 `SR-2` UI 时不需要再回改 trainer 内核
- iOS / macOS 已接入统一的 `sr1-piano-answer` runtime smoke，覆盖切模式、钢琴答错/答对、五线谱红绿反馈，以及切回非 `SR` 模式后的状态清理

## 修改 1：把阶段6的 validation fixture 和手工清单接入总入口

### 修改前

- `ExerciseCompositionValidation.swift` 只覆盖到 `staff_to_piano_skips_legacy_back_projection`
- `SettingsNavigationValidation.swift` 还没有 `SR-1` 专项 root-tree / settings-state 夹具，也没有相应手工回归项

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.makeFixtures() / manualChecklist(for:)
// 功能说明: 修改前 exercise composition 总 runner 还没有阶段6的 SR mode fixture；
// 手工清单也还没纳入 SR-1 的 smoke 回归项。
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_skips_legacy_back_projection",
    validate: validateStaffToPianoSkipsLegacyBackProjection
),
ExerciseCompositionValidationFixture(
    name: "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model",
    validate: validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel
)

var checklist = [
    // ... 省略前文未变项 ...
    "确认 `single/sequence + Side` 未投影 `natural note strip` 时，scene membership 仍为 absent，而 renderer/controller/router 只把它当作有效 `.hidden`，不会误判为混入布局。",
    "确认 `stacked + vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 或 `side` 后该滑块消失，切回 `stacked + vertical` 后沿用上次值。"
]
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: SettingsNavigationValidationRunner.makeFixtures() / manualChecklist(for:)
// 功能说明: 修改前 settings navigation 总 runner 只覆盖通用 route/section 合同；
// 还没有 SR-1 专项 root tree 与 fixed presentation state 夹具。
SettingsNavigationValidationFixture(
    name: "root_mode_switch_preserves_exercise_tree_and_state",
    validate: validateRootModeSwitchPreservesExerciseTreeAndState
),
SettingsNavigationValidationFixture(
    name: "position_prompt_section_visibility_tracks_exercise_mode",
    validate: validatePositionPromptSectionVisibilityTracksExerciseMode
),
SettingsNavigationValidationFixture(
    name: "exercise_layout_route_remains_stable_across_choice_updates",
    validate: validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates
)

[
    // ... 省略前文未变项 ...
    "确认 `Accessory Presentation` 里的 `Docked / Floating / Collapsible` 都可进入且可选；只有切到 `Collapsible` 后才启用 `Accessory Expanded`。",
    "确认 `Debug` 分区包含 `Component Bounds` 与 `Side Container Borders` 两个开关；切换 `Side Container Borders` 时 side 布局的红/蓝容器边框会立即显示或隐藏。"
]
```

### 修改后

- `ExerciseCompositionValidationRunner` 新接入 `sr_modes_freeze_staff_to_piano_policy_contracts`
- `SettingsNavigationValidationRunner` 新接入 `sr1_root_tree_drops_invalid_exercise_and_accessory_routes` 与 `sr1_settings_state_freezes_fixed_presentation_options`
- 两个 runner 的手工清单都补上了阶段 6 的 `SR-1` 回归项

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后 exercise composition 总 runner 会自动覆盖 SR-1 / SR-2 的 fixed policy 合同；
// 手工清单也补上了 SR-1 的主视觉、答题反馈和清理回归项。
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_skips_legacy_back_projection",
    validate: validateStaffToPianoSkipsLegacyBackProjection
),
ExerciseCompositionValidationFixture(
    name: "sr_modes_freeze_staff_to_piano_policy_contracts",
    validate: validateSRModesFreezeStaffToPianoPolicyContracts
),
ExerciseCompositionValidationFixture(
    name: "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model",
    validate: validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel
)

var checklist = [
    // ... 省略前文未变项 ...
    "确认 `stacked + vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 或 `side` 后该滑块消失，切回 `stacked + vertical` 后沿用上次值。",
    "确认切到 `SR-1` 后主视觉稳定收敛到 `treble staff + 单行 piano`，不会再把 `piano accessory` 或 legacy page 投影混回主场景。",
    "确认 `SR-1` 下钢琴答错会给五线谱错误反馈、答对会推进到下一题；随后切回非 SR 模式时不会残留 sequence 高亮或钢琴答题缓存。"
]
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: SettingsNavigationValidationRunner.makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后 settings navigation 总 runner 正式纳入 SR-1 专项 root-tree 与 fixed-state 夹具；
// 手工清单同步增加了 SR-1 下的隐藏页与保留页回归项。
SettingsNavigationValidationFixture(
    name: "root_mode_switch_preserves_exercise_tree_and_state",
    validate: validateRootModeSwitchPreservesExerciseTreeAndState
),
SettingsNavigationValidationFixture(
    name: "sr1_root_tree_drops_invalid_exercise_and_accessory_routes",
    validate: validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes
),
// ... 省略中间未变夹具 ...
SettingsNavigationValidationFixture(
    name: "exercise_layout_route_remains_stable_across_choice_updates",
    validate: validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates
),
SettingsNavigationValidationFixture(
    name: "sr1_settings_state_freezes_fixed_presentation_options",
    validate: validateSR1SettingsStateFreezesFixedPresentationOptions
)

[
    // ... 省略前文未变项 ...
    "确认 `Accessory Presentation` 里的 `Docked / Floating / Collapsible` 都可进入且可选；只有切到 `Collapsible` 后才启用 `Accessory Expanded`。",
    "确认切到 `SR-1` 后，settings root 会移除 `Accessories` 分区，`Exercise` 也只保留有效的 `Mode` 入口，不再暴露会被 fixed normalization 强拉回的子页。",
    "确认 `SR-1` 下 `Staff > Clef`、`Piano > Rows and movement` 中被固定的选项会消失，但 `Piano > Appearance` 与 `Snap Drag` 仍可继续访问。"
]
```

## 修改 2：在 shared policy 层修复显式 legacy fallback 被 SR 固定约束反拉回的问题

### 修改前

- `makeLegacyCompatiblePresentation(...)` 只替换 `layoutPreferences`
- 在 `SR-1` / `SR-2` 下，它仍然沿用原始 `trainerDisplayState.exerciseMode` 和 `pianoPanelState.isVisible`
- 结果是显式 legacy fallback 仍可能被 fixed `staffToPiano` normalization 与 accessory piano 重新拉回非 legacy scene

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.makeLegacyCompatiblePresentation(from:)
// 功能说明: 修改前显式 legacy fallback 只覆写 layoutPreferences；
// 在 SR 模式下仍会沿用原始 exerciseMode 与 pianoPanelState.isVisible。
static func makeLegacyCompatiblePresentation(
    from input: ExerciseCompositionPolicyInput
) -> ExercisePresentationState {
    var legacyCompatibleInput = input
    legacyCompatibleInput.layoutPreferences = legacyCompatiblePreferences(
        from: input
    )
    return makePresentation(from: legacyCompatibleInput)
}
```

### 修改后

- 显式 legacy fallback 现在会把 `sr1/sr2` 暂时映射到 layout-compatible 的 `.sequence` host mode
- 同时强制压平 `legacyCompatibleInput.pianoPanelState.isVisible = false`
- 这样 `makeLegacyCompatiblePresentation(...)` 真正能产出 legacy-compatible 的 `staffToFretboard + stacked` 结果，而不是再次漂回 `staffToPiano`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.makeLegacyCompatiblePresentation(from:) / legacyCompatibleTrainerDisplayState(_:)
// 功能说明: 修改后显式 legacy fallback 不再只改 layoutPreferences；
// 它会同时切换到 legacy-compatible host mode，并清掉 accessory piano，可从根因上避免 SR fixed layout 反向覆盖 fallback 结果。
static func makeLegacyCompatiblePresentation(
    from input: ExerciseCompositionPolicyInput
) -> ExercisePresentationState {
    var legacyCompatibleInput = input
    legacyCompatibleInput.layoutPreferences = legacyCompatiblePreferences(
        from: input
    )
    legacyCompatibleInput.trainerDisplayState = legacyCompatibleTrainerDisplayState(
        input.trainerDisplayState
    )
    legacyCompatibleInput.pianoPanelState.isVisible = false
    return makePresentation(from: legacyCompatibleInput)
}

private static func legacyCompatibleTrainerDisplayState(
    _ trainerDisplayState: TrainerDisplayState
) -> TrainerDisplayState {
    var legacyCompatibleState = trainerDisplayState
    switch legacyCompatibleState.exerciseMode {
    case .sr1, .sr2:
        // Explicit legacy fallback should render through a layout-compatible
        // host mode instead of being re-normalized back to staffToPiano.
        legacyCompatibleState.exerciseMode = .sequence
    case .single, .sequence, .positionPrompt:
        break
    }
    return legacyCompatibleState
}
```

## 修改 3：补上 `SR-1` / `SR-2` 的 exercise policy fixture，并把 `staffToPiano` scene 合同继续锁紧

### 修改前

- `ExerciseCompositionValidationExercisePolicy.swift` 还没有专门验证 `sr1 -> pitchClass`、`sr2 -> exactNote`
- `ExerciseCompositionValidationSceneCore.swift` 只校验 `staffToPiano` 的 surface 角色，没有显式锁住“只允许一个逻辑 `.piano` surface”与 `legacyPageDisplayState == nil`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateStaffToPianoSkipsLegacyBackProjection() / validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
// 功能说明: 修改前 exercise policy validation 只有 staffToPiano 的 legacy/back-projection 夹具；
// 还没有一层明确的 SR mode/preset/policy 三者绑定合同。
static func validateStaffToPianoSkipsLegacyBackProjection()
    -> [ExerciseCompositionValidationIssue] {
    // ... 省略函数体 ...
}

static func validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
    -> [ExerciseCompositionValidationIssue] {
    // ... 省略函数体 ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validateStaffToPianoScenePromotesMainPianoAnswerSurface()
// 功能说明: 修改前只验证 staff/piano 的 surface 角色；
// 还没有显式验证 duplicate piano 防线与 non-legacy 语义。
let rawScene = ExerciseCompositionPolicy.makeScene(
    preferences: ExerciseLayoutPreferences(
        compositionPreset: .staffToPiano,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: true,
        isAccessoryExpanded: true
    )
)
let rawSurfaceIDs = rawScene.surfaceNodes.map(\.id)
if rawSurfaceIDs.count != 2
    || Set(rawSurfaceIDs) != Set([.staff, .piano]) {
    issues.append(/* ... 省略未变 issue ... */)
}
```

### 修改后

- 新增 `validateSRModesFreezeStaffToPianoPolicyContracts()`，直接验证 mode、preset、answerPolicy、legacy bridge normalization 是否一起收敛
- `validateStaffToPianoScenePromotesMainPianoAnswerSurface()` 补上 `rawPianoSurfaceCount` / `presentationPianoSurfaceCount` 与 `ExerciseSceneValidator.legacyPageDisplayState(for:) == nil` 的约束

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 修改后 policy validation 会直接验证 sr1/sr2 的 fixed sequence policy、fixed layout 与 preset 支持矩阵；
// 后续开放 SR-2 UI 时，只要 expose 入口即可，不需要再回改 shared comparator 或 scene 结构。
static func validateSRModesFreezeStaffToPianoPolicyContracts()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "sr_modes_freeze_staff_to_piano_policy_contracts"
    var issues: [ExerciseCompositionValidationIssue] = []

    func validateMode(
        _ exerciseMode: TrainerExerciseMode,
        requestedAnswerPolicy: TrainerSequenceAnswerPolicy,
        expectedAnswerPolicy: TrainerSequenceAnswerPolicy
    ) {
        let trainerDisplayState = TrainerDisplayState(
            exerciseMode: exerciseMode,
            sequenceConfiguration: TrainerSequenceConfiguration(
                clef: .bass,
                noteCount: 5,
                includesAccidentals: true,
                answerPolicy: requestedAnswerPolicy
            )
        )
        let requestedPreferences = ExerciseLayoutPreferences(
            compositionPreset: .targetPromptToFretboard,
            layoutPreset: .sideBySide,
            accessoryPresentation: .floating,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: false
        )
        let resolvedSequenceConfiguration = trainerDisplayState
            .resolvedSequenceConfiguration
        let normalizedPreferences = ExerciseCompositionPolicy.normalizedPreferences(
            requestedPreferences,
            trainerDisplayState: trainerDisplayState
        )
        let normalizedLegacyPreferences = LegacyPageLayoutAdapter.normalizedPreferences(
            requestedPreferences,
            trainerDisplayState: trainerDisplayState
        )

        // ... 省略中间 issue 拼装 ...
        _ = resolvedSequenceConfiguration
        _ = normalizedPreferences
        _ = normalizedLegacyPreferences
    }

    validateMode(.sr1, requestedAnswerPolicy: .exactNote, expectedAnswerPolicy: .pitchClass)
    validateMode(.sr2, requestedAnswerPolicy: .pitchClass, expectedAnswerPolicy: .exactNote)
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validateStaffToPianoScenePromotesMainPianoAnswerSurface()
// 功能说明: 修改后 scene-core validation 不只看 surface 角色；
// 还会锁住 duplicate `.piano` 防线，并明确 `legacyPageDisplayState == nil` 在 SR 主场景下是合法结果。
let rawScene = ExerciseCompositionPolicy.makeScene(
    preferences: ExerciseLayoutPreferences(
        compositionPreset: .staffToPiano,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: true,
        isAccessoryExpanded: true
    )
)
let rawSurfaceIDs = rawScene.surfaceNodes.map(\.id)
let rawPianoSurfaceCount = rawScene.surfaceNodes.filter {
    $0.id == .piano
}.count

if rawPianoSurfaceCount != 1 {
    issues.append(
        issue(
            fixtureName,
            "`staffToPiano` 的 raw scene 里只允许存在一个逻辑 `.piano` surface，避免 main piano 与 accessory piano 同场共存。"
        )
    )
}
if ExerciseSceneValidator.legacyPageDisplayState(for: rawScene) != nil {
    issues.append(
        issue(
            fixtureName,
            "`staffToPiano` 的 raw scene 应被视为合法但不可投影到 legacy page 的新场景，而不是伪装成旧 page 结构。"
        )
    )
}

let presentationPianoSurfaceCount = presentation.scene.surfaceNodes.filter {
    $0.id == .piano
}.count
if ExerciseSceneValidator.legacyPageDisplayState(for: presentation.scene) != nil {
    issues.append(
        issue(
            fixtureName,
            "`staffToPiano` 的 presentation.scene 应继续被 scene validator 视为 non-legacy；`legacyPageDisplayState == nil` 在 SR-1 下是预期结果。"
        )
    )
}
if presentationPianoSurfaceCount != 1 {
    issues.append(
        issue(
            fixtureName,
            "`staffToPiano` 的最终 presentation.scene 只允许保留一个主 `.piano` surface。"
        )
    )
}
```

## 修改 4：补 `SR-1` settings root tree、隐藏项与 route fallback 合同

### 修改前

- `SettingsNavigationValidationRootTree.swift` 文件入口直接是通用的 `validateRootRouteItemsMatchPanelSections()`
- `SettingsNavigationValidationStateAndNavigation.swift` 只覆盖普通 layout route 稳定性，还没有 `SR-1` fixed presentation state 夹具

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名/符号: validateRootRouteItemsMatchPanelSections()
// 功能说明: 修改前 root-tree validation 只有通用 section/page 顺序检查；
// 还没有一条专门验证 SR-1 root tree 收敛与失效 route 回退的夹具。
@MainActor
extension SettingsNavigationValidationRunner {
    static func validateRootRouteItemsMatchPanelSections()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "root_route_items_match_panel_sections"
        let stateContext = SettingsPanelStateContext.default
        // ... 省略后文未变逻辑 ...
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates()
// 功能说明: 修改前状态类 validation 只校验普通 Exercise > Layout 深层页稳定性；
// 还没有 SR-1 下 row hidden / page hidden / selected state / retain-state 的专项合同。
static func validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "exercise_layout_route_remains_stable_across_choice_updates"
    var issues: [SettingsNavigationValidationIssue] = []
    // ... 省略函数体 ...
    return issues
}
```

### 修改后

- `validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes()` 锁住 `Accessories` 分区裁剪、`Exercise` 深层子页消失、失效 route fallback
- `validateSR1SettingsStateFreezesFixedPresentationOptions()` 锁住 `Exercise Mode` 选中态、`composition/layout/accessory` 行隐藏、`clef/piano rows/movement` 行隐藏，以及 `Piano > Behavior` 只保留 `Snap Drag`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名/符号: validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes()
// 功能说明: 修改后 root-tree validation 会先构造一个“故意脏”的 SR-1 stateContext；
// 然后验证 builder 是否把无效的 Exercise/Accessories 路径全部收敛掉。
@MainActor
extension SettingsNavigationValidationRunner {
    static func validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "sr1_root_tree_drops_invalid_exercise_and_accessory_routes"
        let stateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardSelfAnswer,
                layoutPreset: .singleSurface,
                accessoryPresentation: .collapsible,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: true,
                isAccessoryExpanded: false
            ),
            trainerDisplayState: TrainerDisplayState(
                exerciseMode: .sr1,
                sequenceConfiguration: TrainerSequenceConfiguration(
                    clef: .bass,
                    noteCount: 5,
                    includesAccidentals: true,
                    answerPolicy: .exactNote
                )
            ),
            pianoPanelState: PianoPanelState(
                isVisible: true,
                rowCount: 6,
                movementScope: .cascade
            )
        )
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )

        // ... 省略中间 issue 拼装 ...
        _ = panelModel
        _ = navigationModel
        return []
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: validateSR1SettingsStateFreezesFixedPresentationOptions()
// 功能说明: 修改后状态类 validation 会先从 single + 脏 layout 切到 SR-1；
// 然后锁定 writeback 后的 fixed layout、fixed sequence policy、隐藏行和保留页是否全部符合预期。
static func validateSR1SettingsStateFreezesFixedPresentationOptions()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "sr1_settings_state_freezes_fixed_presentation_options"
    var issues: [SettingsNavigationValidationIssue] = []
    var stateContext = SettingsPanelStateContext(
        exerciseLayoutPreferences: ExerciseLayoutPreferences(
            compositionPreset: .fretboardSelfAnswer,
            layoutPreset: .singleSurface,
            accessoryPresentation: .collapsible,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: false
        ),
        trainerDisplayState: TrainerDisplayState(
            exerciseMode: .single,
            sequenceConfiguration: TrainerSequenceConfiguration(
                clef: .bass,
                noteCount: 5,
                includesAccidentals: true,
                answerPolicy: .exactNote
            )
        ),
        pianoPanelState: PianoPanelState(
            isVisible: true,
            rowCount: 6,
            movementScope: .cascade
        )
    )
    SettingsPanelEvent.triggerAction(.setExerciseModeSr1).apply(
        to: &stateContext
    )

    let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
    let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: stateContext
    )
    let resolvedSequenceConfiguration = stateContext.trainerDisplayState
        .resolvedSequenceConfiguration

    // ... 省略中间 issue 拼装 ...
    _ = panelModel
    _ = navigationModel
    _ = resolvedSequenceConfiguration
    return issues
}
```

## 修改 5：把 `TrainerDisplayState(.sr1/.sr2)` 到 comparator 的 seam 正式接入 shared fretboard validation

### 修改前

- `FretboardValidation.validateQuarterNoteSequenceTrainer(...)` 直接用硬编码的 `QuarterNoteSequenceSpec`
- 这能覆盖 `exactNote` 比较器本身，但还没有覆盖 “mode 固定约束 -> resolvedSequenceConfiguration -> trainer spec” 这一层 seam

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改前 validation 直接构造 naturalSpec / exactSpec；
// answerPolicy seam 只测到了 comparator，没有测到 TrainerDisplayState.sr1 / sr2 的 mode 固定约束。
logStage("naturalPrompt")
let naturalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
    clef: .treble,
    noteCount: 7,
    includesAccidentals: false,
    answerPolicy: .pitchClass
)

// ... 省略中间未变逻辑 ...

logStage("exactNoteFlow")
let exactSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
    clef: .treble,
    noteCount: 1,
    includesAccidentals: false,
    answerPolicy: .exactNote
)
```

### 修改后

- 先显式构造 `TrainerDisplayState(exerciseMode: .sr1)` 与 `TrainerDisplayState(exerciseMode: .sr2)`
- 再从 `resolvedSequenceConfiguration` 投影出 `quarterNoteSequenceSpec`
- 这样一旦未来 `SR-2` UI 只做入口曝光，shared comparator seam 也已经被锁住

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后 validation 会先检查 sr1/sr2 的 mode fixed constraint，再把结果喂给 trainer；
// 这样 exactNote seam 不只锁住比较器，还锁住 mode -> resolvedSequenceConfiguration 的 shared 投影链路。
logStage("modePolicySeam")
let sr1DisplayState = TrainerDisplayState(
    exerciseMode: .sr1,
    sequenceConfiguration: TrainerSequenceConfiguration(
        clef: .bass,
        noteCount: 7,
        includesAccidentals: false,
        answerPolicy: .exactNote
    )
)
let sr1ResolvedSequenceConfiguration = sr1DisplayState
    .resolvedSequenceConfiguration
if sr1ResolvedSequenceConfiguration.clef != .treble {
    record("SR-1 的 resolvedSequenceConfiguration 应强制锁定 treble clef。")
}
if sr1ResolvedSequenceConfiguration.answerPolicy != .pitchClass {
    record("SR-1 的 resolvedSequenceConfiguration.answerPolicy 应固定为 .pitchClass。")
}

logStage("naturalPrompt")
let naturalSpec = sr1ResolvedSequenceConfiguration.quarterNoteSequenceSpec

// ... 省略中间未变逻辑 ...

let sr2DisplayState = TrainerDisplayState(
    exerciseMode: .sr2,
    sequenceConfiguration: TrainerSequenceConfiguration(
        clef: .bass,
        noteCount: 1,
        includesAccidentals: false,
        answerPolicy: .pitchClass
    )
)
let sr2ResolvedSequenceConfiguration = sr2DisplayState
    .resolvedSequenceConfiguration
if sr2ResolvedSequenceConfiguration.answerPolicy != .exactNote {
    record("SR-2 的 resolvedSequenceConfiguration.answerPolicy 应固定为 .exactNote。")
}

logStage("exactNoteFlow")
let exactSpec = sr2ResolvedSequenceConfiguration.quarterNoteSequenceSpec
```

## 修改 6：新增双端 `SR-1 piano answer` runtime smoke，并接到 App 启动场景

### 修改前

- iOS / macOS 都只保留 `layout-preset-regression` 与 `startup-validation`
- controller 的 `#if DEBUG` extension 里只有 `runLayoutPresetRegressionSmokeTest(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名/符号: RuntimeSmokeScenario / didFinishLaunchingWithOptions
// 功能说明: 修改前 iOS 入口只支持 layout-preset-regression 与 startup-validation；
// 还没有 SR-1 piano answer 的 smoke 分支。
#if DEBUG
if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ... 省略 layout smoke 调度 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: runLayoutPresetRegressionSmokeTest(in:completion:)
// 功能说明: 修改前 iOS controller 的 DEBUG smoke 只覆盖 layout preset 回归；
// 还没有切到 SR-1、钢琴答题、五线谱反馈和状态清理这一整条链路。
#if DEBUG
extension iOSViewController {
    func runLayoutPresetRegressionSmokeTest(
        in window: UIWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        // ... 省略函数体 ...
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名/符号: RuntimeSmokeScenario / applicationDidFinishLaunching(_:)
// 功能说明: 修改前 macOS 入口与 iOS 一样，只调度 layout-preset-regression；
// 还没有 SR-1 专项 smoke scenario。
#if DEBUG
if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ... 省略 layout smoke 调度 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: runLayoutPresetRegressionSmokeTest(in:completion:)
// 功能说明: 修改前 macOS controller 也只有 layout preset smoke；
// 还没有 SR-1 piano answer 的跨模式/跨反馈 smoke。
#if DEBUG
extension macOSViewController {
    func runLayoutPresetRegressionSmokeTest(
        in window: NSWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        // ... 省略函数体 ...
    }
}
#endif
```

### 修改后

- iOS / macOS 都新增 `sr1-piano-answer` 场景值
- 双端 controller 都新增 `runSR1PianoAnswerSmokeTest(...)`
- smoke 步骤统一覆盖：
- 切到 `SR-1`
- 发送错误 `previewStarted`
- 发送正确 `previewStarted`
- 切回 `single`
- 校验固定 layout、五线谱 wrong/correct feedback、`quarterNoteSequenceSession` 清理、`lastPianoAnswerNotesByPreviewID` 清理，以及 `.piano` surface 下线

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名/符号: RuntimeSmokeScenario / didFinishLaunchingWithOptions
// 功能说明: 修改后 iOS 入口新增 sr1-piano-answer 场景；
// 启动时会把环境变量转成具体 smoke 调度，并在成功后直接退出。
#if DEBUG
if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    print("[RuntimeSmoke][iOS] scheduled scenario=sr1_piano_answer")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        // ... 省略取 activeExerciseViewController 的未变守卫 ...
        viewController.runSR1PianoAnswerSmokeTest(
            in: window
        ) { passed, summary in
            print(summary)
            if passed {
                exit(0)
            } else {
                fatalError(summary)
            }
        }
    }
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ... 保持旧逻辑 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"

    static var shouldRunSR1PianoAnswerSmoke: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == sr1PianoAnswerValue
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: runSR1PianoAnswerSmokeTest(in:completion:) / runSR1PianoAnswerSmokeSteps(_:index:settleLayout:completion:)
// 功能说明: 修改后 iOS smoke 会直接走真实 controller 管线；
// 通过 `handleSettingsPanelEvent(...)` 与 `handlePianoSemanticEvent(...)` 验证 SR-1 模式、判题反馈和状态清理是否一致。
#if DEBUG
extension iOSViewController {
    func runSR1PianoAnswerSmokeTest(
        in window: UIWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            action: () -> Void,
            validate: () -> String?
        )
        var wrongPreview: PianoPreviewState?
        var correctPreview: PianoPreviewState?

        func currentExpectedNotePitch() -> NotePitch? {
            if let currentItem = quarterNoteSequenceSession?.currentItem {
                return currentItem.expectedNotePitch
            }
            return currentGeneratedQuarterNoteSequence?.items.first?.expectedNotePitch
        }

        let steps: [SmokeStep] = [
            (
                name: "switch_to_sr1",
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setExerciseModeSr1)
                    )
                },
                validate: {
                    guard self.exerciseLayoutPreferences == .srPianoAnswer else {
                        return "reason=layout_not_fixed"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .staff) == .promptOnly,
                          self.exercisePresentationState.projectedSurfaceState(for: .piano) == .answerOnly else {
                        return "reason=surface_roles_invalid"
                    }
                    return nil
                }
            ),
            (
                name: "wrong_piano_preview",
                action: {
                    // ... 省略预期音高推导 ...
                    self.handlePianoSemanticEvent(.previewStarted(preview))
                },
                validate: {
                    guard self.staffDisplayState.sequencePresentation?.state == .wrong else {
                        return "reason=staff_missing_wrong_feedback"
                    }
                    return nil
                }
            ),
            (
                name: "correct_piano_preview",
                action: {
                    // ... 省略 previewEnded + 正确 note 发送 ...
                },
                validate: {
                    guard self.staffDisplayState.sequencePresentation?.state == .correct else {
                        return "reason=staff_missing_correct_feedback"
                    }
                    return nil
                }
            ),
            (
                name: "switch_back_to_single",
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setExerciseModeSingle)
                    )
                },
                validate: {
                    guard self.quarterNoteSequenceSession == nil,
                          self.quarterNoteSequenceLastEvaluation == nil,
                          self.staffDisplayState.sequencePresentation == nil,
                          self.lastPianoAnswerNotesByPreviewID.isEmpty else {
                        return "reason=state_not_cleared"
                    }
                    return nil
                }
            )
        ]

        runSR1PianoAnswerSmokeSteps(
            steps,
            index: 0,
            settleLayout: { /* ... 省略 layout settle ... */ },
            completion: completion
        )
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名/符号: RuntimeSmokeScenario / applicationDidFinishLaunching(_:)
// 功能说明: 修改后 macOS 入口镜像接入 sr1-piano-answer 场景；
// 与 iOS 一样，在拿到 activeExerciseViewController 后执行同名 smoke 并以退出码反馈结果。
#if DEBUG
if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    print("[RuntimeSmoke][macOS] scheduled scenario=sr1_piano_answer")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        // ... 省略取 activeExerciseViewController 的未变守卫 ...
        viewController.runSR1PianoAnswerSmokeTest(
            in: window
        ) { passed, summary in
            print(summary)
            if passed {
                NSApp.terminate(nil)
            } else {
                fatalError(summary)
            }
        }
    }
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ... 保持旧逻辑 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: runSR1PianoAnswerSmokeTest(in:completion:) / runSR1PianoAnswerSmokeSteps(_:index:settleLayout:completion:)
// 功能说明: 修改后 macOS smoke 与 iOS 保持同一套步骤和断言；
// 只是把 layout settle 换成 `layoutSubtreeIfNeeded()`，以适配 AppKit 容器。
#if DEBUG
extension macOSViewController {
    func runSR1PianoAnswerSmokeTest(
        in window: NSWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            action: () -> Void,
            validate: () -> String?
        )

        func settleLayout() {
            window.contentView?.layoutSubtreeIfNeeded()
            view.layoutSubtreeIfNeeded()
        }

        let steps: [SmokeStep] = [
            // ... 与 iOS 对齐的 switch_to_sr1 / wrong_piano_preview /
            // correct_piano_preview / switch_back_to_single 四步 ...
        ]

        runSR1PianoAnswerSmokeSteps(
            steps,
            index: 0,
            settleLayout: settleLayout,
            completion: completion
        )
    }
}
#endif
```

## 本次文件清单

- 已修改代码文件：`NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- 已修改代码文件：`NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 新增记录文件：`commit_records/20260415_165707_stage6_validation_sr2_seam_runtime_smoke.md`

# 20260415_210852_stage5_sr0_settings_navigation_legacy_bridge

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_210852`
- 记录依据：基于当前工作区本轮阶段 5 改动相关文件的 `git status --short -- ...`、`git diff --stat -- ...`、按文件 `git diff`、`git show HEAD:...` 旧片段、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` 验证结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr0_双行strip_计划_632caead.plan.md` 实施阶段 5 的真实落地代码改动；目标是把 `SR-0` 接入 settings、navigation 与 legacy bridge，并补齐对应 shared validation
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`9 files changed, 308 insertions(+), 63 deletions(-)`
- 统计口径说明：
- `git status --short -- "NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift" "NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift" "NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift" "NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift" "NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift" "NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift" "NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift" "NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift" "NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift"` 只包含下面 9 个 `Swift` 文件
- 本记录文件本身是新增 markdown 记录，不计入上面的 `9 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本次确认但未修改的关键文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`：其 `hasFixedExercisePresentationMode(...)`、`fixedSequenceClef == nil`、`fixedPianoRowCount == nil`、`fixedPianoMovementScope == nil` 这组 generic gate 在阶段 3 引入 `sr0.fixedExerciseLayoutPreferences` 后已经天然覆盖 `SR-0`，所以阶段 5 不需要再为 `SR-0` 单独加特判
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`：阶段 5 的 settings writeback 继续通过既有 `LegacyPageLayoutAdapter.reconcile(&stateContext)` 收口，本轮不需要改 state container
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 上面两个 controller 的 settings 事件分发与 stage 5 无新增分支；`SR-0` 入口属于 shared settings/navigation/legacy 层改动
- 验证结果：
- `ReadLints`：对本轮 9 个目标路径读取 IDE 诊断，返回的实际报错都落在 `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`，共 17 条 `Cannot find ... in scope`；但本轮 macOS / iOS `xcodebuild` 都通过，这组报错应视为当前 IDE / SourceKit 的旧索引诊断，而不是实际编译错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMasterSR0Stage5-mac-build" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" -derivedDataPath "/tmp/NoteMasterSR0Stage5-ios-build" build`：`BUILD SUCCEEDED`
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr0_双行strip_计划_632caead.plan.md`
- 没有新增 runtime smoke
- 没有修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- 没有提交代码

## 本次结论

- `SR-0` 现在正式出现在 `Exercise Mode` 入口里，顺序变为 `Single / Sequence / SR-0 / SR-1 / Position`
- settings navigation 的 Exercise 模式页文案、root tree 断言、fixed-presentation settings state 断言都已把 `SR-0` 纳入 shared contract，而不是继续只为 `SR-1` 写死
- `staffToNaturalNoteStrip` 现在和 `staffToPiano` 一样，在 legacy page 投影路径上会直接回落到默认 legacy page；显式 `legacy-compatible presentation` 也会先通过 legacy host mode 做归一化，避免 `SR-0` 被固定 SR 合同重新拉回 `staff + strip`
- composition validation 新增了 `staff_to_natural_note_strip_skips_legacy_back_projection`，把 `SR-0` 的 settings bridge / legacy fallback 合同锁进 automated validation

## 修改 1：在 `SettingsPanelModel` 中新增 `SR-0` 模式入口，并补齐 shared settings 写回

### 修改前

- `Exercise Mode` 只有 `Single / Sequence / SR-1 / Position`
- `SettingsActionID` 没有 `setExerciseModeSr0`
- `title`、`accessibilityLabel`、`isSelected`、`apply(to: TrainerDisplayState)` 都没有 `SR-0`
- 其它 grouped switch 也没有把 `setExerciseModeSr0` 纳入 no-op / always-enabled 分支

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / SettingsActionID / SettingsActionID.title / SettingsActionID.accessibilityLabel / SettingsActionID.isSelected
// 功能说明: 修改前 settings 层只有 `SR-1` 的入口；
// `SR-0` 既没有 action id，也没有选中态与文案。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr1,
        .setExerciseModePositionPrompt
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setRootModeExercise
    case setRootModePlay
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModeSr1
    case setExerciseModePositionPrompt
    // ... 省略未变 case ...
}

case .setExerciseModeSequence:
    return "Sequence"
case .setExerciseModeSr1:
    return "SR-1"
case .setExerciseModePositionPrompt:
    return "Position"

case .setExerciseModeSequence:
    return "Train a generated note sequence"
case .setExerciseModeSr1:
    return "Train treble staff reading with a single-row piano answer surface"
case .setExerciseModePositionPrompt:
    return "Train note names from a highlighted fretboard position"

case .setExerciseModeSequence:
    return stateContext.trainerDisplayState.exerciseMode == .sequence
case .setExerciseModeSr1:
    return stateContext.trainerDisplayState.exerciseMode == .sr1
case .setExerciseModePositionPrompt:
    return stateContext.trainerDisplayState.exerciseMode == .positionPrompt
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsActionID.apply(to: TrainerDisplayState) / SettingsActionID.isEnabled / SettingsActionID.apply(to: FretboardDisplayState|StaffDisplayState|PianoPanelState|ExerciseLayoutPreferences)
// 功能说明: 修改前 shared settings writeback 也没有 `setExerciseModeSr0`；
// 新增 enum case 以后如果不补这些 grouped switch，会直接破坏 switch 完整性。
case .setExerciseModeSingle:
    displayState.setExerciseMode(.single)
case .setExerciseModeSequence:
    displayState.setExerciseMode(.sequence)
case .setExerciseModeSr1:
    displayState.setExerciseMode(.sr1)
case .setExerciseModePositionPrompt:
    displayState.setExerciseMode(.positionPrompt)

case .setExerciseModeSingle,
     .setExerciseModeSequence,
     .setExerciseModeSr1,
     .setExerciseModePositionPrompt,
     .setPositionPromptFilterModeNoteName,
     .setPositionPromptFilterModeFret,
     .setInstrumentGuitar6,
     .setInstrumentBass4,
     .setInstrumentBass5,
     .setDisplayModeHorizontal,
     .setDisplayModeVertical,
     .setStringThicknessUniform,
     .setStringThicknessGraduated,
     .setVisibilityAll,
     .setVisibilityNaturalOnly,
     .setVisibilityBCEFOnly,
     .setVisibilityAccidentalOnly,
     .setVisibilityNone,
     .setSpellingSharp,
     .setSpellingFlat,
     .toggleShowsOctave,
     .setClefTreble,
     .setClefBass,
     .setPianoMovementScopeCascade,
     .setPianoMovementScopeRowOnly,
     .setPianoWhiteKeyStyleOutlined,
     .setPianoWhiteKeyStyleGapOnly,
     .setPianoWhiteKeyStyleSkeuomorphicHighlight:
    return true
```

### 修改后

- `Exercise Mode` 正式变成 `Single / Sequence / SR-0 / SR-1 / Position`
- `SettingsActionID` 新增 `setExerciseModeSr0`
- `SR-0` 的标题、无障碍文案、选中态、写回分支全部补齐
- 其它 grouped switch 也同步把 `setExerciseModeSr0` 纳入既有共享分组，保持 switch 完整性

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / SettingsActionID / SettingsActionID.title / SettingsActionID.accessibilityLabel / SettingsActionID.isSelected
// 功能说明: 修改后 `Exercise Mode` 正式暴露 `SR-0`；
// 其标题、文案和选中态也与现有 shared settings contract 对齐。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModePositionPrompt
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setRootModeExercise
    case setRootModePlay
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModeSr0
    case setExerciseModeSr1
    case setExerciseModePositionPrompt
    // ... 省略未变 case ...
}

case .setExerciseModeSequence:
    return "Sequence"
case .setExerciseModeSr0:
    return "SR-0"
case .setExerciseModeSr1:
    return "SR-1"
case .setExerciseModePositionPrompt:
    return "Position"

case .setExerciseModeSequence:
    return "Train a generated note sequence"
case .setExerciseModeSr0:
    return "Train treble staff reading with a two-row natural note strip answer surface"
case .setExerciseModeSr1:
    return "Train treble staff reading with a single-row piano answer surface"
case .setExerciseModePositionPrompt:
    return "Train note names from a highlighted fretboard position"

case .setExerciseModeSequence:
    return stateContext.trainerDisplayState.exerciseMode == .sequence
case .setExerciseModeSr0:
    return stateContext.trainerDisplayState.exerciseMode == .sr0
case .setExerciseModeSr1:
    return stateContext.trainerDisplayState.exerciseMode == .sr1
case .setExerciseModePositionPrompt:
    return stateContext.trainerDisplayState.exerciseMode == .positionPrompt
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsActionID.apply(to: TrainerDisplayState) / SettingsActionID.isEnabled / SettingsActionID.apply(to: PianoPanelState|ExerciseLayoutPreferences)
// 功能说明: 修改后 `SR-0` 的 settings action 不仅能改 exerciseMode；
// 它还被纳入其它 grouped switch，避免新增 case 破坏 shared settings writeback 的现有分层。
case .setExerciseModeSingle:
    displayState.setExerciseMode(.single)
case .setExerciseModeSequence:
    displayState.setExerciseMode(.sequence)
case .setExerciseModeSr0:
    displayState.setExerciseMode(.sr0)
case .setExerciseModeSr1:
    displayState.setExerciseMode(.sr1)
case .setExerciseModePositionPrompt:
    displayState.setExerciseMode(.positionPrompt)

case .setExerciseModeSingle,
     .setExerciseModeSequence,
     .setExerciseModeSr0,
     .setExerciseModeSr1,
     .setExerciseModePositionPrompt,
     .setPositionPromptFilterModeNoteName,
     .setPositionPromptFilterModeFret,
     .setInstrumentGuitar6,
     .setInstrumentBass4,
     .setInstrumentBass5,
     .setDisplayModeHorizontal,
     .setDisplayModeVertical,
     .setStringThicknessUniform,
     .setStringThicknessGraduated,
     .setVisibilityAll,
     .setVisibilityNaturalOnly,
     .setVisibilityBCEFOnly,
     .setVisibilityAccidentalOnly,
     .setVisibilityNone,
     .setSpellingSharp,
     .setSpellingFlat,
     .toggleShowsOctave,
     .setClefTreble,
     .setClefBass,
     .setPianoMovementScopeCascade,
     .setPianoMovementScopeRowOnly,
     .setPianoWhiteKeyStyleOutlined,
     .setPianoWhiteKeyStyleGapOnly,
     .setPianoWhiteKeyStyleSkeuomorphicHighlight:
    return true
```

## 修改 2：让 settings navigation 文案与 fixed-mode validation 一起纳入 `SR-0`

### 修改前

- `Exercise > Mode` 子页文案还写死成 `Single, sequence, SR-1, or position`
- root tree 只有 `validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes()`
- fixed settings state 只有 `validateSR1SettingsStateFreezesFixedPresentationOptions()`
- `SettingsNavigationValidation.makeFixtures()` 和 `manualChecklist` 也只显式提 `SR-1`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: SettingsNavigationSnapshotBuilder.childPageSpecs
// 功能说明: 修改前 Exercise > Mode 的 subtitle 仍然把固定 SR 模式只写成 `SR-1`。
ChildPageSpec(
    route: .exerciseMode,
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, SR-1, or position",
    rowIDs: [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses)
    ]
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名/符号: SettingsNavigationValidationRunner.validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes
// 功能说明: 修改前 root tree validation 只有 `SR-1` 单点夹具；
// `SR-0` 还没有被纳入相同的 root tree / route fallback 合同。
static func validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "sr1_root_tree_drops_invalid_exercise_and_accessory_routes"
    let stateContext = SettingsPanelStateContext(
        // ... 省略未变初始化 ...
        trainerDisplayState: TrainerDisplayState(
            exerciseMode: .sr1,
            sequenceConfiguration: TrainerSequenceConfiguration(
                clef: .bass,
                noteCount: 5,
                includesAccidentals: true,
                answerPolicy: .exactNote
            )
        )
    )
    // ... 省略未变断言 ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: SettingsNavigationValidationRunner.validateSR1SettingsStateFreezesFixedPresentationOptions
// 功能说明: 修改前 fixed settings state validation 只覆盖 `SR-1`；
// Exercise Mode 顺序也还没有 `SR-0`。
static func validateSR1SettingsStateFreezesFixedPresentationOptions()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "sr1_settings_state_freezes_fixed_presentation_options"
    var issues: [SettingsNavigationValidationIssue] = []
    var stateContext = SettingsPanelStateContext(
        // ... 省略未变初始化 ...
    )
    SettingsPanelEvent.triggerAction(.setExerciseModeSr1).apply(
        to: &stateContext
    )

    // ... 省略未变断言 ...

    if exerciseModeRow.choices.map(\.id) != [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr1,
        .setExerciseModePositionPrompt
    ] {
        issues.append(
            issue(
                fixtureName,
                "Exercise Mode row 的选项顺序应继续保持 Single / Sequence / SR-1 / Position。"
            )
        )
    }

    // ... 省略未变断言 ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: SettingsNavigationValidationRunner.makeFixtures / manualChecklist
// 功能说明: 修改前 settings navigation validation 的 fixture 注册与手工清单都只写了 `SR-1`。
SettingsNavigationValidationFixture(
    name: "sr1_root_tree_drops_invalid_exercise_and_accessory_routes",
    validate: validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes
),
SettingsNavigationValidationFixture(
    name: "sr1_settings_state_freezes_fixed_presentation_options",
    validate: validateSR1SettingsStateFreezesFixedPresentationOptions
),

"确认切到 `SR-1` 后，settings root 会移除 `Accessories` 分区，`Exercise` 也只保留有效的 `Mode` 入口，不再暴露会被 fixed normalization 强拉回的子页。",
"确认 `SR-1` 下 `Staff > Clef`、`Piano > Rows and movement` 中被固定的选项会消失，但 `Piano > Appearance` 与 `Snap Drag` 仍可继续访问。",
```

### 修改后

- `Exercise > Mode` 文案现在更新为 `Single, sequence, SR-0, SR-1, or position`
- root tree validation 抽成 `validateSRFixedRootTreeDropsInvalidExerciseAndAccessoryRoutes(...)`，并新增 `SR-0` 入口
- fixed settings state validation 抽成 `validateSRFixedSettingsState(...)`，同时覆盖 `SR-0` 与 `SR-1`
- `SettingsNavigationValidation.makeFixtures()` 新增 `sr0_*` 夹具，手工清单也同步扩到 `SR-0 / SR-1`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: SettingsNavigationSnapshotBuilder.childPageSpecs
// 功能说明: 修改后 Exercise > Mode 的 subtitle 正式纳入 `SR-0`。
ChildPageSpec(
    route: .exerciseMode,
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, SR-0, SR-1, or position",
    rowIDs: [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses)
    ]
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名/符号: validateSR0RootTreeDropsInvalidExerciseAndAccessoryRoutes / validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes / validateSRFixedRootTreeDropsInvalidExerciseAndAccessoryRoutes
// 功能说明: 修改后 root tree validation 被提炼成 shared helper；
// `SR-0` 和 `SR-1` 都走同一套 root tree / route fallback 合同。
static func validateSR0RootTreeDropsInvalidExerciseAndAccessoryRoutes()
    -> [SettingsNavigationValidationIssue] {
    validateSRFixedRootTreeDropsInvalidExerciseAndAccessoryRoutes(
        exerciseMode: .sr0,
        modeTitle: "SR-0",
        fixtureName: "sr0_root_tree_drops_invalid_exercise_and_accessory_routes"
    )
}

static func validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes()
    -> [SettingsNavigationValidationIssue] {
    validateSRFixedRootTreeDropsInvalidExerciseAndAccessoryRoutes(
        exerciseMode: .sr1,
        modeTitle: "SR-1",
        fixtureName: "sr1_root_tree_drops_invalid_exercise_and_accessory_routes"
    )
}

private static func validateSRFixedRootTreeDropsInvalidExerciseAndAccessoryRoutes(
    exerciseMode: TrainerExerciseMode,
    modeTitle: String,
    fixtureName: String
) -> [SettingsNavigationValidationIssue] {
    let stateContext = SettingsPanelStateContext(
        // ... 省略未变初始化 ...
        trainerDisplayState: TrainerDisplayState(
            exerciseMode: exerciseMode,
            sequenceConfiguration: TrainerSequenceConfiguration(
                clef: .bass,
                noteCount: 5,
                includesAccidentals: true,
                answerPolicy: .exactNote
            )
        )
    )
    // ... 省略未变断言：root page / section / route fallback ...
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: validateSR0SettingsStateFreezesFixedPresentationOptions / validateSR1SettingsStateFreezesFixedPresentationOptions / validateSRFixedSettingsState
// 功能说明: 修改后 fixed settings state 断言也被收口成 shared helper；
// 它会根据 `hidesPianoRowsAndMovement` 区分 `SR-0` 与 `SR-1` 的钢琴设置页可见性合同。
static func validateSR0SettingsStateFreezesFixedPresentationOptions()
    -> [SettingsNavigationValidationIssue] {
    validateSRFixedSettingsState(
        triggerAction: .setExerciseModeSr0,
        expectedExerciseMode: .sr0,
        modeTitle: "SR-0",
        fixtureName: "sr0_settings_state_freezes_fixed_presentation_options",
        expectedLayoutPreferences: .srNoteStripAnswer,
        hidesPianoRowsAndMovement: false
    )
}

static func validateSR1SettingsStateFreezesFixedPresentationOptions()
    -> [SettingsNavigationValidationIssue] {
    validateSRFixedSettingsState(
        triggerAction: .setExerciseModeSr1,
        expectedExerciseMode: .sr1,
        modeTitle: "SR-1",
        fixtureName: "sr1_settings_state_freezes_fixed_presentation_options",
        expectedLayoutPreferences: .srPianoAnswer,
        hidesPianoRowsAndMovement: true
    )
}

private static func validateSRFixedSettingsState(
    triggerAction: SettingsActionID,
    expectedExerciseMode: TrainerExerciseMode,
    modeTitle: String,
    fixtureName: String,
    expectedLayoutPreferences: ExerciseLayoutPreferences,
    hidesPianoRowsAndMovement: Bool
) -> [SettingsNavigationValidationIssue] {
    // ... 省略未变初始化 ...
    let expectedExerciseModeChoices: [SettingsActionID] = [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModePositionPrompt
    ]
    let expectedPianoSectionRowIDs: [SettingsRowID] = hidesPianoRowsAndMovement
        ? [
            .choice(.pianoWhiteKeyStyle),
            .toggle(.pianoSnapEnabled)
        ]
        : [
            .slider(.pianoRowCount),
            .choice(.pianoMovementScope),
            .choice(.pianoWhiteKeyStyle),
            .toggle(.pianoSnapEnabled)
        ]
    // ... 省略其余断言 ...
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: SettingsNavigationValidationRunner.makeFixtures / manualChecklist
// 功能说明: 修改后 settings navigation validation 的 automated fixture 与手工清单都纳入了 `SR-0`。
SettingsNavigationValidationFixture(
    name: "sr0_root_tree_drops_invalid_exercise_and_accessory_routes",
    validate: validateSR0RootTreeDropsInvalidExerciseAndAccessoryRoutes
),
SettingsNavigationValidationFixture(
    name: "sr1_root_tree_drops_invalid_exercise_and_accessory_routes",
    validate: validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes
),
SettingsNavigationValidationFixture(
    name: "sr0_settings_state_freezes_fixed_presentation_options",
    validate: validateSR0SettingsStateFreezesFixedPresentationOptions
),
SettingsNavigationValidationFixture(
    name: "sr1_settings_state_freezes_fixed_presentation_options",
    validate: validateSR1SettingsStateFreezesFixedPresentationOptions
),

"确认切到 `SR-0` 或 `SR-1` 后，settings root 会移除 `Accessories` 分区，`Exercise` 也只保留有效的 `Mode` 入口，不再暴露会被 fixed normalization 强拉回的子页。",
"确认 `SR-0` / `SR-1` 下 `Staff > Clef` 入口都会消失；`SR-1` 还应继续隐藏 `Piano > Rows and movement`，而 `SR-0` 仍保留后台钢琴配置入口。",
```

## 修改 3：收紧 `SR-0` 的 legacy bridge fallback，避免把 `staff + strip` 重新拉回 non-legacy 场景

### 修改前

- `ExerciseCompositionPolicy.legacyCompatiblePreferences(from:)` 在二次 `normalizedPreferences(...)` 时仍使用 `input.trainerDisplayState`
- 对 `SR-0` 来说，这意味着显式 `legacy-compatible presentation` 途中还有机会被 fixed SR 合同重新拉回 `staffToNaturalNoteStrip`
- `LegacyPageLayoutAdapter.projectedPageDisplayState(...)` 只对 `staffToPiano` 做了直接 fallback，`staffToNaturalNoteStrip` 还没走同一条 legacy page 回退语义

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.legacyCompatiblePreferences
// 功能说明: 修改前 legacy-compatible preference 的二次 normalize 仍然带着原始 `SR-0` trainer mode；
// 对固定 SR 模式来说，这一步可能再次被 fixed normalization 拉回新场景。
static func legacyCompatiblePreferences(
    from input: ExerciseCompositionPolicyInput
) -> ExerciseLayoutPreferences {
    let resolvedPreferences = ExerciseCompositionPolicy.normalizedPreferences(
        input.layoutPreferences,
        trainerDisplayState: input.trainerDisplayState
    )
    var legacyCompatiblePreferences = resolvedPreferences

    legacyCompatiblePreferences.layoutPreset = .stacked
    legacyCompatiblePreferences.accessoryPresentation = .docked
    legacyCompatiblePreferences.isNaturalNoteStripVisible = false
    legacyCompatiblePreferences.isPianoAccessoryVisible = false
    legacyCompatiblePreferences.isAccessoryExpanded = true

    switch input.trainerDisplayState.exerciseMode {
    case .single, .sequence, .sr0, .sr1, .sr2:
        if legacyCompatiblePreferences.compositionPreset
            != .targetPromptToFretboard,
           legacyCompatiblePreferences.compositionPreset
            != .staffToFretboard {
            legacyCompatiblePreferences.compositionPreset = .staffToFretboard
        }
    case .positionPrompt:
        if legacyCompatiblePreferences.compositionPreset
            != .fretboardToNaturalNoteStrip {
            legacyCompatiblePreferences.compositionPreset = .fretboardToNaturalNoteStrip
        }
    }

    legacyCompatiblePreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            legacyCompatiblePreferences,
            trainerDisplayState: input.trainerDisplayState
        )
    // ... 省略未变逻辑 ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: LegacyPageLayoutAdapter.projectedPageDisplayState
// 功能说明: 修改前 direct fallback 只覆盖 `staffToPiano`；
// `staffToNaturalNoteStrip` 还没有被显式纳入同一条 legacy page fallback 语义。
static func projectedPageDisplayState(
    from preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> PageDisplayState {
    let resolvedPreferences = normalizedPreferences(
        preferences,
        trainerDisplayState: trainerDisplayState
    )
    if resolvedPreferences.compositionPreset == .staffToPiano {
        return fallbackPageDisplayState(
            for: trainerDisplayState.exerciseMode
        )
    }

    let presentationState = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: policyInput(
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: .init(),
                layoutPreferences: resolvedPreferences
            )
        )
    // ... 省略未变逻辑 ...
}
```

### 修改后

- `ExerciseCompositionPolicy.legacyCompatiblePreferences(from:)` 先取 `legacyCompatibleTrainerDisplayState(...)`，再用 legacy host mode 做二次 normalize
- 这样显式 legacy-compatible 路径不会再被 `SR-0` 的 fixed scene 合同拉回 `staffToNaturalNoteStrip`
- `LegacyPageLayoutAdapter.projectedPageDisplayState(...)` 也把 `staffToNaturalNoteStrip` 纳入与 `staffToPiano` 相同的 direct fallback

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.legacyCompatiblePreferences
// 功能说明: 修改后显式 legacy-compatible preference 会先切到 legacy host mode 再二次 normalize；
// 这样 `SR-0` 不会在 fallback 中再次被 fixed SR 合同拉回 `staff + strip`。
static func legacyCompatiblePreferences(
    from input: ExerciseCompositionPolicyInput
) -> ExerciseLayoutPreferences {
    let normalizedLegacyTrainerDisplayState = legacyCompatibleTrainerDisplayState(
        input.trainerDisplayState
    )
    let resolvedPreferences = ExerciseCompositionPolicy.normalizedPreferences(
        input.layoutPreferences,
        trainerDisplayState: input.trainerDisplayState
    )
    var legacyCompatiblePreferences = resolvedPreferences

    legacyCompatiblePreferences.layoutPreset = .stacked
    legacyCompatiblePreferences.accessoryPresentation = .docked
    legacyCompatiblePreferences.isNaturalNoteStripVisible = false
    legacyCompatiblePreferences.isPianoAccessoryVisible = false
    legacyCompatiblePreferences.isAccessoryExpanded = true

    switch input.trainerDisplayState.exerciseMode {
    case .single, .sequence, .sr0, .sr1, .sr2:
        if legacyCompatiblePreferences.compositionPreset
            != .targetPromptToFretboard,
           legacyCompatiblePreferences.compositionPreset
            != .staffToFretboard {
            legacyCompatiblePreferences.compositionPreset = .staffToFretboard
        }
    case .positionPrompt:
        if legacyCompatiblePreferences.compositionPreset
            != .fretboardToNaturalNoteStrip {
            legacyCompatiblePreferences.compositionPreset = .fretboardToNaturalNoteStrip
        }
    }

    legacyCompatiblePreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            legacyCompatiblePreferences,
            trainerDisplayState: normalizedLegacyTrainerDisplayState
        )
    // ... 省略未变逻辑 ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: LegacyPageLayoutAdapter.projectedPageDisplayState
// 功能说明: 修改后 `staffToNaturalNoteStrip` 也会像 `staffToPiano` 一样直接回落到默认 legacy page；
// 不再尝试把非 legacy 的新场景硬塞进旧 page model。
static func projectedPageDisplayState(
    from preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> PageDisplayState {
    let resolvedPreferences = normalizedPreferences(
        preferences,
        trainerDisplayState: trainerDisplayState
    )
    if resolvedPreferences.compositionPreset == .staffToPiano
        || resolvedPreferences.compositionPreset == .staffToNaturalNoteStrip {
        return fallbackPageDisplayState(
            for: trainerDisplayState.exerciseMode
        )
    }

    let presentationState = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: policyInput(
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: .init(),
                layoutPreferences: resolvedPreferences
            )
        )
    // ... 省略未变逻辑 ...
}
```

## 修改 4：新增 `staffToNaturalNoteStrip` 的 legacy back projection validation，并注册到 composition validation runner

### 修改前

- `ExerciseCompositionValidationExercisePolicy.swift` 只有 `validateStaffToPianoSkipsLegacyBackProjection()`
- `ExerciseCompositionValidation.swift` 的 fixture registry 也只注册了 `staff_to_piano_skips_legacy_back_projection`
- `staffToNaturalNoteStrip` 还没有单独的 settings bridge / legacy-compatible fallback 回归夹具

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateStaffToPianoSkipsLegacyBackProjection / validateSRModesFreezeStaffToPianoPolicyContracts
// 功能说明: 修改前 validation policy 里只有 `staffToPiano` 的 legacy back projection 夹具；
// `staffToNaturalNoteStrip` 还没有并列的 SR-0 legacy seam 断言。
static func validateStaffToPianoSkipsLegacyBackProjection()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "staff_to_piano_skips_legacy_back_projection"
    var issues: [ExerciseCompositionValidationIssue] = []
    // ... 省略现有 `staffToPiano` legacy bridge 断言 ...
    return issues
}

static func validateSRModesFreezeStaffToPianoPolicyContracts()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "sr_modes_freeze_staff_to_piano_policy_contracts"
    var issues: [ExerciseCompositionValidationIssue] = []
    // ... 省略未变逻辑 ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.makeFixtures
// 功能说明: 修改前 composition validation registry 还没有 `staff_to_natural_note_strip_skips_legacy_back_projection`。
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_skips_legacy_back_projection",
    validate: validateStaffToPianoSkipsLegacyBackProjection
),
ExerciseCompositionValidationFixture(
    name: "sr_modes_freeze_staff_to_piano_policy_contracts",
    validate: validateSRModesFreezeStaffToPianoPolicyContracts
),
ExerciseCompositionValidationFixture(
    name: "sr0_mode_freezes_staff_to_natural_note_strip_policy_contracts",
    validate:
        validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts
),
```

### 修改后

- `ExerciseCompositionValidationExercisePolicy.swift` 新增 `validateStaffToNaturalNoteStripSkipsLegacyBackProjection()`
- 这条新夹具同时断言：
- legacy adapter normalize 不提前改写 `staffToNaturalNoteStrip`
- `projectedPageDisplayState(...)` 直接回落到 `.default`
- settings bridge 仍保留 `srNoteStripAnswer`
- 显式 `makeLegacyCompatiblePresentation(...)` 会回退到 `staffToFretboard + stacked`
- `ExerciseCompositionValidation.swift` 也把这个 fixture 正式注册进 runner

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateStaffToNaturalNoteStripSkipsLegacyBackProjection
// 功能说明: 修改后新增 `staffToNaturalNoteStrip` 的 legacy back projection 夹具；
// 它把 `SR-0` 的 legacy adapter、settings bridge 与 explicit legacy-compatible fallback 合同一并锁住。
static func validateStaffToNaturalNoteStripSkipsLegacyBackProjection()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "staff_to_natural_note_strip_skips_legacy_back_projection"
    var issues: [ExerciseCompositionValidationIssue] = []

    let trainerDisplayState = TrainerDisplayState(exerciseMode: .sr0)
    let requestedPreferences = ExerciseLayoutPreferences(
        compositionPreset: .staffToNaturalNoteStrip,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: true,
        isPianoAccessoryVisible: true,
        isAccessoryExpanded: true
    )
    let normalizedPreferences = LegacyPageLayoutAdapter.normalizedPreferences(
        requestedPreferences,
        trainerDisplayState: trainerDisplayState
    )
    // ... 省略未变断言：normalize 阶段保留主 strip、压平 piano accessory ...

    let projectedPageDisplayState = LegacyPageLayoutAdapter
        .projectedPageDisplayState(
            from: requestedPreferences,
            trainerDisplayState: trainerDisplayState
        )
    // ... 省略未变断言：回落到 .default ...

    var stateContext = SettingsPanelStateContext(
        pageDisplayState: .default,
        exerciseLayoutPreferences: requestedPreferences,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: PianoPanelState(isVisible: true)
    )
    LegacyPageLayoutAdapter.reconcile(&stateContext)
    // ... 省略未变断言：settings bridge 对齐到 `srNoteStripAnswer` ...

    let legacyCompatiblePresentation = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: trainerDisplayState,
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: PianoPanelState(isVisible: true),
                layoutPreferences: requestedPreferences
            )
        )
    // ... 省略未变断言：fallback 到 `staffToFretboard + stacked` ...

    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.makeFixtures
// 功能说明: 修改后新夹具被正式纳入 composition validation runner。
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_skips_legacy_back_projection",
    validate: validateStaffToPianoSkipsLegacyBackProjection
),
ExerciseCompositionValidationFixture(
    name: "staff_to_natural_note_strip_skips_legacy_back_projection",
    validate: validateStaffToNaturalNoteStripSkipsLegacyBackProjection
),
ExerciseCompositionValidationFixture(
    name: "sr_modes_freeze_staff_to_piano_policy_contracts",
    validate: validateSRModesFreezeStaffToPianoPolicyContracts
),
ExerciseCompositionValidationFixture(
    name: "sr0_mode_freezes_staff_to_natural_note_strip_policy_contracts",
    validate:
        validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts
),
```

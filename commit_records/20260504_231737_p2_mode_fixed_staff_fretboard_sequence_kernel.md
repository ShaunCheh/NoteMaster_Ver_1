# P-2 模式接入记录

- 记录时间戳：`20260504_231737`
- 记录依据：基于当前工作区的 `git status --short`、`git diff --stat`、以及本轮 12 个已修改代码文件的 `git diff` 整理；本文不直接粘贴原始 `git diff`。
- 差异概览：本轮代码层变更为 `12 files changed, 375 insertions(+), 20 deletions(-)`。
- 当前工作区里仍有未跟踪文件：`.DS_Store`、`NoteMaster_Ver_1.xcodeproj/project.xcworkspace/xcuserdata/`、`NoteMaster_Ver_1/.DS_Store`、`NoteMaster_Ver_1/Shared/.DS_Store`。这些不是本次 `P-2` 代码接入的一部分，本文不把它们计入功能修改。

## 触达范围

本轮实际修改的代码文件如下：

- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`

这批修改都集中在 shared 层，没有新增平台专属 view，也没有改动 `.md` 之外的文档文件。

## 修改 1：新增 `P-2` mode，并把它收敛为固定的 `staff -> fretboard` 上下布局

修改前，系统只有 `single / sequence / positionPrompt / SR-0 / SR-1 / SR-2`；其中只有 `sequence + SR 家族` 会复用 quarter-note sequence kernel，但没有一个 mode 被固定成“上方五线谱、下方指板”的专用两组件场景。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode / fixedExerciseLayoutPreferences / usesQuarterNoteSequenceKernel
// 功能说明: 修改前没有 P-2；fixed presentation 只覆盖 SR 家族；sequence kernel 只被 sequence 与 SR 家族复用。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
    case sr0
    case sr1
    case sr2
}

var fixedExerciseLayoutPreferences: ExerciseLayoutPreferences? {
    switch self {
    case .sr1, .sr2:
        return srPianoReadingContract?.fixedExerciseLayoutPreferences
    case .sr0:
        return .srNoteStripAnswer
    case .single, .sequence, .positionPrompt:
        return nil
    }
}

var usesQuarterNoteSequenceKernel: Bool {
    switch self {
    case .sequence, .sr0, .sr1, .sr2:
        return true
    case .single, .positionPrompt:
        return false
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: ExerciseLayoutPreferences
// 功能说明: 修改前 shared 里没有 P-2 的固定 layout contract 常量。
static let singleFretboardSelfAnswer = ExerciseLayoutPreferences(
    compositionPreset: .fretboardSelfAnswer,
    layoutPreset: .singleSurface,
    accessoryPresentation: .docked,
    isNaturalNoteStripVisible: false,
    isPianoAccessoryVisible: false,
    isAccessoryExpanded: true
)

static let srPianoAnswer = ExerciseLayoutPreferences(
    compositionPreset: .staffToPiano,
    layoutPreset: .stacked,
    accessoryPresentation: .docked,
    isNaturalNoteStripVisible: false,
    isPianoAccessoryVisible: false,
    isAccessoryExpanded: true
)
```

修改后，新增了 `.p2`，并通过 `ExerciseLayoutPreferences.p2StaffFretboardAnswer` 把它固定为 `staffToFretboard + stacked + no accessories`。同时，`.p2` 也被纳入 `usesQuarterNoteSequenceKernel`，确保它复用 sequence 的出题和判题内核，而不是走 single / positionPrompt 的老链路。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode / fixedExerciseLayoutPreferences / usesQuarterNoteSequenceKernel
// 功能说明: 修改后新增 P-2；它复用 quarter-note sequence kernel，但 presentation 被固定收敛到 staff->fretboard。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case p2
    case positionPrompt
    case sr0
    case sr1
    case sr2
}

var fixedExerciseLayoutPreferences: ExerciseLayoutPreferences? {
    switch self {
    case .sr1, .sr2:
        return srPianoReadingContract?.fixedExerciseLayoutPreferences
    case .p2:
        return .p2StaffFretboardAnswer
    case .sr0:
        return .srNoteStripAnswer
    case .single, .sequence, .positionPrompt:
        return nil
    }
}

var usesQuarterNoteSequenceKernel: Bool {
    switch self {
    case .sequence, .p2, .sr0, .sr1, .sr2:
        return true
    case .single, .positionPrompt:
        return false
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: ExerciseLayoutPreferences.p2StaffFretboardAnswer
// 功能说明: 修改后为 P-2 引入集中 layout contract，锁死 staff prompt + fretboard answer + stacked。
static let p2StaffFretboardAnswer = ExerciseLayoutPreferences(
    compositionPreset: .staffToFretboard,
    layoutPreset: .stacked,
    accessoryPresentation: .docked,
    isNaturalNoteStripVisible: false,
    isPianoAccessoryVisible: false,
    isAccessoryExpanded: true
)
```

## 修改 2：把 `P-2` 正式暴露到 settings / navigation，而不是只停留在内部枚举

修改前，`Exercise Mode` row 只有 `Single / Sequence / SR-0 / SR-1 / SR-2 / Position` 六个选项；导航子页文案也只写死了这六个模式。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / SettingsActionID.title / SettingsActionID.accessibilityLabel
// 功能说明: 修改前 Exercise Mode 没有 P-2，settings 无法显式切入这个模式。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModeSr2,
        .setExerciseModePositionPrompt
    ]

case .setExerciseModeSequence:
    return "Sequence"
case .setExerciseModeSr0:
    return "SR-0"
case .setExerciseModePositionPrompt:
    return "Position"
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: childPageSpecs(for:)
// 功能说明: 修改前 Exercise > Mode 子页 subtitle 只覆盖已有 6 个 mode。
ChildPageSpec(
    route: .exerciseMode,
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, SR-0, SR-1, SR-2, or position",
    rowIDs: [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses)
    ]
)
```

修改后，`P-2` 已经作为正式 mode 进入 `SettingsActionID`、选中态判断、标题与 accessibility label；`Exercise > Mode` 的 subtitle 也同步扩展，避免 UI 和内部状态定义脱节。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / SettingsActionID.title / SettingsActionID.accessibilityLabel / SettingsActionID.apply(to:)
// 功能说明: 修改后 P-2 成为正式的 Exercise Mode 选项，并能从 settings 直接写回到 trainerDisplayState。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeP2,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModeSr2,
        .setExerciseModePositionPrompt
    ]

case .setExerciseModeP2:
    return "P-2"

case .setExerciseModeP2:
    return "Train a generated note sequence with a fixed staff-over-fretboard stacked layout"

case .setExerciseModeP2:
    displayState.setExerciseMode(.p2)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: childPageSpecs(for:)
// 功能说明: 修改后 Exercise > Mode 子页 subtitle 会明确把 P-2 写进模式列表，避免导航文案落后于真实 mode 集合。
ChildPageSpec(
    route: .exerciseMode,
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, P-2, SR-0, SR-1, SR-2, or position",
    rowIDs: [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses)
    ]
)
```

## 修改 3：让 `P-2` 复用 sequence answer flow，但把 legacy / normalization 收口到默认 `staff -> fretboard`

修改前，answer router 里只有 `sequence / SR` 会进入 `ResolvedSequenceAnswer` 路由；legacy adapter 也不知道 `P-2` 的存在。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: ExerciseAnswerRouter.route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能说明: 修改前 sequence answer flow 不认识 P-2；如果只新增 mode 枚举，不补 router，这条链路会断。
switch trainerDisplayState.exerciseMode {
case .single:
    // ...
case .sequence, .sr0, .sr1, .sr2:
    guard let answer = FretboardNaturalNoteTrainerState
        .resolvedSequenceAnswer(
            from: event,
            configuration: fretboardConfiguration
        ) else {
        // ...
    }
    return .routed(.quarterNoteSequence(event: event, answer: answer))
case .positionPrompt:
    // ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: inferredPreferences(pageDisplayState:trainerDisplayState:pianoPanelState:) / fallbackPageDisplayState(for:)
// 功能说明: 修改前 legacy adapter 只把 single / sequence / SR 家族映射回默认 staff->fretboard 页，不包含 P-2。
switch trainerDisplayState.exerciseMode {
case .positionPrompt:
    inferredCompositionPreset = .fretboardToNaturalNoteStrip
case .single, .sequence, .sr0, .sr1, .sr2:
    switch pageDisplayState.topContentMode {
    case .targetPrompt:
        inferredCompositionPreset = .targetPromptToFretboard
    case .staff, .fretboard:
        inferredCompositionPreset = .staffToFretboard
    }
}
```

修改后，`P-2` 会直接走 sequence 的 answer carrier 路由；同时 normalization / legacy fallback 也把它统一当作默认 `staff -> fretboard` 页来处理，再由 fixed layout contract 把主场景收紧到 `stacked`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: ExerciseAnswerRouter.route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能说明: 修改后 P-2 与 sequence/SR 一样走 quarter-note sequence answer flow，确保上方 staff 出题、下方 fretboard 作答复用同一套 sequence 判题链。
switch trainerDisplayState.exerciseMode {
case .single:
    // ...
case .sequence, .p2, .sr0, .sr1, .sr2:
    guard let answer = FretboardNaturalNoteTrainerState
        .resolvedSequenceAnswer(
            from: event,
            configuration: fretboardConfiguration
        ) else {
        // ...
    }
    return .routed(.quarterNoteSequence(event: event, answer: answer))
case .positionPrompt:
    // ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: isCompositionPresetSupported(_:for:) / normalizedCompositionPreset(_:for:)
// 功能说明: 修改后 P-2 被归入固定 presentation mode；一旦请求了无效 preset，会被强制拉回 fixedCompositionPreset。
switch exerciseMode {
case .single, .sequence:
    // ...
case .p2, .sr0, .sr1, .sr2:
    return false
case .positionPrompt:
    // ...
}

guard isCompositionPresetSupported(preset, for: exerciseMode) else {
    switch exerciseMode {
    case .single, .sequence:
        return .staffToFretboard
    case .p2, .sr0, .sr1, .sr2:
        return exerciseMode.fixedCompositionPreset ?? preset
    case .positionPrompt:
        return .fretboardToNaturalNoteStrip
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: inferredPreferences(pageDisplayState:trainerDisplayState:pianoPanelState:) / fallbackPageDisplayState(for:)
// 功能说明: 修改后 P-2 与 single/sequence/SR 一样保持默认 legacy page 兼容值，再由 shared composition policy 输出固定的主场景。
switch trainerDisplayState.exerciseMode {
case .positionPrompt:
    inferredCompositionPreset = .fretboardToNaturalNoteStrip
case .single, .sequence, .p2, .sr0, .sr1, .sr2:
    switch pageDisplayState.topContentMode {
    case .targetPrompt:
        inferredCompositionPreset = .targetPromptToFretboard
    case .staff, .fretboard:
        inferredCompositionPreset = .staffToFretboard
    }
}

switch exerciseMode {
case .single, .sequence, .p2, .sr0, .sr1, .sr2:
    return .default
case .positionPrompt:
    return .positionPrompt
}
```

## 修改 4：补齐 `P-2` 的 shared validation，锁住 fixed presentation contract

修改前，validation 只覆盖 `single / sequence / positionPrompt` 的 legacy baseline，以及 `SR` 家族的 fixed settings / root-tree 收敛；没有 `P-2` 的自动化断言。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: makeFixtures()
// 功能说明: 修改前 exercise composition validation 没有 P-2 baseline fixture。
ExerciseCompositionValidationFixture(
    name: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
    validate: validateLegacySingleBaseline
),
ExerciseCompositionValidationFixture(
    name: "legacy_sequence_baseline_matches_stacked_staff_over_fretboard",
    validate: validateLegacySequenceBaseline
),
ExerciseCompositionValidationFixture(
    name: "legacy_position_prompt_baseline_matches_fretboard_over_natural_strip",
    validate: validateLegacyPositionPromptBaseline
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: makeFixtures()
// 功能说明: 修改前 settings/navigation validation 只有 SR-0 / SR-1 / SR-2 的 fixed presentation fixture，没有 P-2。
SettingsNavigationValidationFixture(
    name: "sr0_settings_state_freezes_fixed_presentation_options",
    validate: validateSR0SettingsStateFreezesFixedPresentationOptions
),
SettingsNavigationValidationFixture(
    name: "sr1_settings_state_freezes_fixed_presentation_options",
    validate: validateSR1SettingsStateFreezesFixedPresentationOptions
),
SettingsNavigationValidationFixture(
    name: "sr2_settings_state_freezes_fixed_presentation_options",
    validate: validateSR2SettingsStateFreezesFixedPresentationOptions
)
```

修改后，新增了 `P-2` 的 legacy baseline、settings state freeze、root tree 收敛 fixture，并把手工 checklist 也扩展到了 `P-2`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateLegacyP2Baseline() / validateLegacyBaseline(...)
// 功能说明: 修改后新增 P-2 baseline 自动化断言，确保它继续落成 staff->fretboard，并隐藏会被 fixed presentation 强制回滚的入口。
static func validateLegacyP2Baseline()
    -> [ExerciseCompositionValidationIssue] {
    validateLegacyBaseline(
        fixtureName: "legacy_p2_baseline_matches_stacked_staff_over_fretboard",
        exerciseMode: .p2,
        expectedPageDisplayState: .default
    )
}

case .p2:
    if exerciseSection.rows.map(\.id) != [
        .choice(.exerciseMode)
    ] {
        issues.append(
            issue(
                fixtureName,
                "P-2 的 legacy baseline 应把 Exercise section 收敛为只保留 Exercise Mode。"
            )
        )
    }
    if stateContext.exerciseLayoutPreferences != .p2StaffFretboardAnswer {
        issues.append(
            issue(
                fixtureName,
                "P-2 的 legacy baseline 应继续收敛到固定的 `staffToFretboard + stacked` layout contract。"
            )
        )
    }
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: validateP2SettingsStateFreezesFixedPresentationOptions()
// 功能说明: 修改后新增 P-2 settings 固定项断言，锁住 mode 顺序、选中态、layout 收敛和 Accessories 隐藏行为。
static func validateP2SettingsStateFreezesFixedPresentationOptions()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "p2_settings_state_freezes_fixed_presentation_options"
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
        )
    )
    SettingsPanelEvent.triggerAction(.setExerciseModeP2).apply(to: &stateContext)
    // ... 后续断言 Exercise Mode row 顺序、layout 收敛、Accessories 隐藏、Staff/Piano section 保留
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名/符号: validateP2RootTreeDropsInvalidExerciseAndAccessoryRoutes()
// 功能说明: 修改后 P-2 与 SR 固定模式一样，会校验 root tree 是否裁掉无效的 Exercise 深层页和 Accessories 分区。
static func validateP2RootTreeDropsInvalidExerciseAndAccessoryRoutes()
    -> [SettingsNavigationValidationIssue] {
    validateFixedPresentationRootTreeDropsInvalidExerciseAndAccessoryRoutes(
        exerciseMode: .p2,
        modeTitle: "P-2",
        fixtureName: "p2_root_tree_drops_invalid_exercise_and_accessory_routes"
    )
}
```

## 验证情况

- `ReadLints`：针对本轮修改文件读取后，没有新增 linter error。
- 编译验证：已执行  
  `xcodebuild build -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug`
- 结果：构建通过，没有新增编译错误。
- 说明：构建输出里仍存在项目既有 warning，例如 `macOSPianoKeyboardView` 的 deprecated API 警告、若干 validation 的 main-actor warning；这些 warning 在本轮修改前就存在，本次 `P-2` 接入没有继续扩大它们，也没有在本次范围内一并处理。

## 结论

本轮不是只给 `sequence` 改个别名，而是按当前 shared 架构把 `P-2` 做成了一个**独立的固定模式 contract**：

- 训练内核复用 `quarterNoteSequence`
- 主场景固定为 `staff prompt + fretboard answer + stacked`
- settings 正式暴露 `P-2`
- fixed presentation 会自动裁掉无效 `Composition / Layout / Accessories` 入口
- shared validation 已补上 `P-2` 的 baseline / root tree / settings freeze 断言

也就是说，`P-2` 现在已经是架构内的正式 mode，而不是临时拼出来的一组 UI 状态组合。

# 20260416_134240_stage3_sr2_settings_navigation_entry_freeze

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260416_134240`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat -- ...`、按文件 `git diff -- ...`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` / `startup-validation` 结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md` 实施阶段 3 的真实落地代码改动；目标是让用户能在 settings / navigation 中正式切到 `SR-2`，并继续隐藏会被 fixed mode 立即拉回的无效控制项
- 重要说明：
- 本轮不是阶段 4；没有新增 `SR-2` runtime smoke 场景
- 本轮不是阶段 5；没有扩充手工 checklist 文案，也没有修改 `ExerciseCompositionValidation` / `FretboardValidation`
- 当前 `git status --short` 只包含下面 5 个 `Swift` 文件，因此本次记录口径与阶段 3 的真实改动集完全一致
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`5 files changed, 123 insertions(+), 8 deletions(-)`
- 本记录文件本身是新增 markdown 记录，不计入上面的 diff 统计
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- 本次确认但未修改的关键文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/.cursor/plans/sr2两行钢琴_4531b6e9.plan.md`
- 验证结果：
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage3_mac" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage3_ios" build`：`BUILD SUCCEEDED`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：macOS 运行结果为 `PASS scenario=startup_validation`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：iOS Simulator 运行结果为 `PASS scenario=startup_validation`
- `SettingsNavigationValidation` 在 iOS / macOS 启动验证链里均为 `automated=PASS fixtures=19`
- 新增的 `sr2_root_tree_drops_invalid_exercise_and_accessory_routes` 与 `sr2_settings_state_freezes_fixed_presentation_options` 在双端均为 `issues=0`
- 本轮调试过程中的非代码问题：
- `ReadLints` 对本轮 5 个文件读取后，`SettingsNavigationValidation.swift` 仍显示 19 条 `Cannot find ... in scope` 的 `SourceKit` 诊断；但相同代码已通过双平台 `xcodebuild` 与双端 `startup-validation`，因此这里按 IDE 诊断滞后如实记录，不视为实际编译失败
- 本次没做的事情：
- 没有修改 `SettingsPanelSnapshotBuilder.swift`；因为阶段 1/2 已经通过 `fixedSequenceClef / fixedPianoMovementScope / fixedPianoRowCount` 把无效项隐藏逻辑接好
- 没有修改任何旧的 `.md` 记录文件
- 没有修改计划文件
- 没有新增 `SR-2` runtime smoke
- 没有提交代码

## 本次结论

- `SR-2` 现在已经从“只存在于 shared contract 的内部模式”变成 settings 中可正式切换的 exercise mode
- 阶段 3 没有去补 controller if/else，也没有去改 scene / renderer，而是直接在 settings / navigation 共享层把入口、文案、选中态、写回和 validation 链路补齐
- `SR-2` 下固定的 `treble + exactNote + 2 rows + rowOnly` 能力边界现在不仅存在于 `TrainerDisplayState`，也被 settings snapshot / root tree / startup validation 显式锁死
- `SettingsPanelSnapshotBuilder.swift` 本轮未改不是遗漏，而是因为它早已通过 fixed-mode gate 隐藏 `clef`、`pianoMovementScope`、`pianoRowCount` 等会被 normalization 拉回的无效项；阶段 3 只需要把 `SR-2` 正式暴露到这些共享 builder 的输入链路里

## 修改 1：在 `SettingsPanelModel` 把 `SR-2` 从内部 mode 变成正式 settings action

### 修改前

- 阶段 2 结束时，`TrainerDisplayState` 与 shared validation 已认识 `SR-2`
- 但 settings 的 `Exercise Mode` row 仍只暴露 `Single / Sequence / SR-0 / SR-1 / Position`
- `SettingsActionID` 也没有 `setExerciseModeSr2`
- 因此用户无法通过 settings 真实切到 `SR-2`，选中态、辅助说明和写回逻辑也无从建立

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / SettingsActionID / SettingsActionID.title / accessibilityLabel / isSelected(in:) / apply(to:)
// 功能说明: 修改前 settings 只把 `SR-0 / SR-1` 视为正式 exercise mode；
// `SR-2` 虽然已经存在于 shared contract，但这里既没有 action，也没有标题、选中态和写回入口。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModePositionPrompt
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModeSr0
    case setExerciseModeSr1
    case setExerciseModePositionPrompt
}

case .setExerciseModeSr1:
    return "SR-1"

case .setExerciseModeSr1:
    return "Train treble staff reading with a single-row piano answer surface"

case .setExerciseModeSr1:
    return stateContext.trainerDisplayState.exerciseMode == .sr1

case .setExerciseModeSr1:
    displayState.setExerciseMode(.sr1)
```

### 修改后

- 在 `exerciseMode` action 列表中加入 `setExerciseModeSr2`
- 新增 `SettingsActionID.setExerciseModeSr2`
- 补齐 `SR-2` 的标题、accessibility label、选中态
- 补齐写回到 `TrainerDisplayState.exerciseMode = .sr2` 的入口
- 同时把 `setExerciseModeSr2` 带入同一文件里所有 exercise-mode 相关的 `switch` 穷举列表，保持 row ownership、编译穷尽和状态写回一致

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / SettingsActionID / SettingsActionID.title / accessibilityLabel / isSelected(in:) / apply(to:)
// 功能说明: 修改后 `SR-2` 被正式接进 settings 的 exercise mode 主链路；
// 用户可以从 UI 切到 `SR-2`，而共享 snapshot / navigation / validation 也能围绕同一个 action 继续收敛状态。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModeSr2,
        .setExerciseModePositionPrompt
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModeSr0
    case setExerciseModeSr1
    case setExerciseModeSr2
    case setExerciseModePositionPrompt
}

case .setExerciseModeSr2:
    return "SR-2"

case .setExerciseModeSr2:
    return "Train treble staff reading with a two-row piano answer surface and exact-note matching"

case .setExerciseModeSr2:
    return stateContext.trainerDisplayState.exerciseMode == .sr2

case .setExerciseModeSr2:
    displayState.setExerciseMode(.sr2)
```

## 修改 2：更新 `Exercise > Mode` 的导航说明，并补 `SR-2` root tree fixture

### 修改前

- `SettingsNavigationSnapshotBuilder` 的 `Exercise > Mode` subtitle 仍写着 `Single, sequence, SR-0, SR-1, or position`
- `SettingsNavigationValidationRootTree.swift` 也只有 `SR-0` / `SR-1` 的 root-tree fixture
- 这会导致 `SR-2` 即使在 settings row 中出现，导航索引文案和 root tree 自动验证仍然落后于真实能力

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: SettingsNavigationSnapshotBuilder.childPageSpecs(for:)
// 功能说明: 修改前 Exercise > Mode 的 subtitle 仍只列出 `SR-0 / SR-1`；
// 导航说明与真实 mode 列表不一致。
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
// 函数名/符号: SettingsNavigationValidationRunner.validateSR0RootTreeDropsInvalidExerciseAndAccessoryRoutes() / validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes()
// 功能说明: 修改前 root tree validation 只为 `SR-0 / SR-1` 建了固定模式夹具；
// `SR-2` 还没有被纳入“Exercise / Accessories route 会被裁剪”的共享验证。
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
```

### 修改后

- `Exercise > Mode` subtitle 扩成包含 `SR-2`
- 在 root-tree validation 里新增 `validateSR2RootTreeDropsInvalidExerciseAndAccessoryRoutes()`
- 同时更新默认 exercise index page 的期望 subtitle，保证 builder 与 validation 使用同一份文案

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: SettingsNavigationSnapshotBuilder.childPageSpecs(for:)
// 功能说明: 修改后导航层的 Exercise > Mode 文案显式纳入 `SR-2`；
// root index 里展示的 mode 能力说明不再落后于 settings 的实际可切换列表。
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

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名/符号: SettingsNavigationValidationRunner.validateSR2RootTreeDropsInvalidExerciseAndAccessoryRoutes() / validateSplitSectionsProduceExpectedPageTree()
// 功能说明: 修改后 root tree validation 会把 `SR-2` 当成正式 fixed mode；
// 同时默认 exercise index page 的期望 subtitle 也升级为包含 `SR-2` 的版本。
static func validateSR2RootTreeDropsInvalidExerciseAndAccessoryRoutes()
    -> [SettingsNavigationValidationIssue] {
    validateSRFixedRootTreeDropsInvalidExerciseAndAccessoryRoutes(
        exerciseMode: .sr2,
        modeTitle: "SR-2",
        fixtureName: "sr2_root_tree_drops_invalid_exercise_and_accessory_routes"
    )
}

SettingsRouteItem(
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, SR-0, SR-1, SR-2, or position",
    route: .exerciseMode
)
```

## 修改 3：把 `SR` 固定模式的 settings validation 从“只管 `SR-0 / SR-1`”扩成共享的 `SR-0 / SR-1 / SR-2` 矩阵

### 修改前

- `SettingsNavigationValidationStateAndNavigation.swift` 已有共享 helper `validateSRFixedSettingsState(...)`
- 但它仍把 `resolvedSequenceConfiguration.answerPolicy` 写死成 `pitchClass`
- `Exercise Mode` 列表顺序仍只检查到 `SR-1`
- 也没有把 `resolvedPianoSettingsSlice.rowCount / movementScope` 当成 settings 层的显式合同
- 因此阶段 3 之前，这条 validation 还无法真正表达 `SR-2 = exactNote + 2 rows + rowOnly`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: SettingsNavigationValidationRunner.validateSR1SettingsStateFreezesFixedPresentationOptions() / validateSRFixedSettingsState(...)
// 功能说明: 修改前共享 helper 仍以 `pitchClass` 和 `SR-0 / SR-1` 列表为中心；
// 它还不能直接验证 `SR-2` 的 exact-note 与两行钢琴合同。
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
    let expectedExerciseModeChoices: [SettingsActionID] = [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModePositionPrompt
    ]

    if resolvedSequenceConfiguration.clef != .treble
        || resolvedSequenceConfiguration.answerPolicy != .pitchClass {
        issues.append(
            issue(
                fixtureName,
                "\(modeTitle) 的 resolvedSequenceConfiguration 应强制固定为 treble + pitchClass。"
            )
        )
    }
}
```

### 修改后

- `validateSRFixedSettingsState(...)` 新增：
- `expectedSequenceAnswerPolicy`
- `expectedResolvedPianoRowCount`
- `expectedResolvedPianoMovementScope`
- 新增 `validateSR2SettingsStateFreezesFixedPresentationOptions()`
- 共享 helper 现在会显式验证：
- `SR-0 = pitchClass + 6 rows + cascade`（即不冻结 piano rows / movement）
- `SR-1 = pitchClass + 1 row + rowOnly`
- `SR-2 = exactNote + 2 rows + rowOnly`
- 同时把 `Exercise Mode` row 的 id 顺序、标题顺序、`SR-2` 选项是否存在、标题是否正确、accessibility label 是否明确表达 `two-row piano + exact-note matching` 一并锁住

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: SettingsNavigationValidationRunner.validateSR0SettingsStateFreezesFixedPresentationOptions() / validateSR1SettingsStateFreezesFixedPresentationOptions() / validateSR2SettingsStateFreezesFixedPresentationOptions()
// 功能说明: 修改后三个 SR 模式都通过同一个共享 helper 描述自己的固定矩阵；
// 阶段3的 settings state validation 不再只覆盖 `SR-0 / SR-1`，而是显式纳入 `SR-2` 的 exact-note 与两行钢琴合同。
static func validateSR0SettingsStateFreezesFixedPresentationOptions()
    -> [SettingsNavigationValidationIssue] {
    validateSRFixedSettingsState(
        triggerAction: .setExerciseModeSr0,
        expectedExerciseMode: .sr0,
        modeTitle: "SR-0",
        fixtureName: "sr0_settings_state_freezes_fixed_presentation_options",
        expectedLayoutPreferences: .srNoteStripAnswer,
        hidesPianoRowsAndMovement: false,
        expectedSequenceAnswerPolicy: .pitchClass,
        expectedResolvedPianoRowCount: 6,
        expectedResolvedPianoMovementScope: .cascade
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
        hidesPianoRowsAndMovement: true,
        expectedSequenceAnswerPolicy: .pitchClass,
        expectedResolvedPianoRowCount: 1,
        expectedResolvedPianoMovementScope: .rowOnly
    )
}

static func validateSR2SettingsStateFreezesFixedPresentationOptions()
    -> [SettingsNavigationValidationIssue] {
    validateSRFixedSettingsState(
        triggerAction: .setExerciseModeSr2,
        expectedExerciseMode: .sr2,
        modeTitle: "SR-2",
        fixtureName: "sr2_settings_state_freezes_fixed_presentation_options",
        expectedLayoutPreferences: .srPianoAnswer,
        hidesPianoRowsAndMovement: true,
        expectedSequenceAnswerPolicy: .exactNote,
        expectedResolvedPianoRowCount: 2,
        expectedResolvedPianoMovementScope: .rowOnly
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: SettingsNavigationValidationRunner.validateSRFixedSettingsState(...)
// 功能说明: 修改后共享 helper 既会检查 sequence policy，也会检查 resolved piano settings；
// 并把 `Exercise Mode` row 的 id / title 顺序与 `SR-2` 选项文案一起锁住。
private static func validateSRFixedSettingsState(
    triggerAction: SettingsActionID,
    expectedExerciseMode: TrainerExerciseMode,
    modeTitle: String,
    fixtureName: String,
    expectedLayoutPreferences: ExerciseLayoutPreferences,
    hidesPianoRowsAndMovement: Bool,
    expectedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy,
    expectedResolvedPianoRowCount: Int,
    expectedResolvedPianoMovementScope: PianoMovementScope
) -> [SettingsNavigationValidationIssue] {
    let resolvedPianoSettingsSlice = stateContext.trainerDisplayState
        .resolvedPianoSettingsSlice(from: stateContext.pianoPanelState.settingsSlice)
    let expectedExerciseModeChoices: [SettingsActionID] = [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModeSr2,
        .setExerciseModePositionPrompt
    ]
    let expectedExerciseModeTitles = [
        "Single",
        "Sequence",
        "SR-0",
        "SR-1",
        "SR-2",
        "Position"
    ]

    if resolvedSequenceConfiguration.clef != .treble
        || resolvedSequenceConfiguration.answerPolicy
        != expectedSequenceAnswerPolicy {
        issues.append(
            issue(
                fixtureName,
                "\(modeTitle) 的 resolvedSequenceConfiguration 应强制固定为 treble + \(expectedSequenceAnswerPolicy)。"
            )
        )
    }
    if resolvedPianoSettingsSlice.rowCount != expectedResolvedPianoRowCount
        || resolvedPianoSettingsSlice.movementScope
        != expectedResolvedPianoMovementScope {
        issues.append(
            issue(
                fixtureName,
                "\(modeTitle) 的 settings state 应通过 shared helper 收敛到 rowCount=\(expectedResolvedPianoRowCount) / movementScope=\(expectedResolvedPianoMovementScope)。"
            )
        )
    }
    if exerciseModeRow.choices.map(\.id) != expectedExerciseModeChoices {
        issues.append(
            issue(
                fixtureName,
                "Exercise Mode row 的选项顺序应继续保持 Single / Sequence / SR-0 / SR-1 / SR-2 / Position。"
            )
        )
    }
    if exerciseModeRow.choices.map(\.title) != expectedExerciseModeTitles {
        issues.append(
            issue(
                fixtureName,
                "Exercise Mode row 的标题顺序应继续保持 Single / Sequence / SR-0 / SR-1 / SR-2 / Position。"
            )
        )
    }

    guard let sr2Choice = exerciseModeRow.choices.first(where: { choice in
        choice.id == .setExerciseModeSr2
    }) else {
        issues.append(
            issue(
                fixtureName,
                "Exercise Mode row 应正式暴露 `SR-2` 选项，而不是只存在于内部 contract。"
            )
        )
        return issues
    }
    if sr2Choice.title != "SR-2" {
        issues.append(
            issue(
                fixtureName,
                "Exercise Mode row 中 `SR-2` 选项的标题应保持为 `SR-2`。"
            )
        )
    }
    if sr2Choice.accessibilityLabel
        != "Train treble staff reading with a two-row piano answer surface and exact-note matching" {
        issues.append(
            issue(
                fixtureName,
                "Exercise Mode row 中 `SR-2` 选项的 accessibility label 应明确表达 two-row piano + exact-note matching。"
            )
        )
    }
}
```

## 修改 4：把 `SR-2` fixture 正式接入 `SettingsNavigationValidation` 聚合器

### 修改前

- 阶段 3 前半段虽然已经写了 `SR-2` 的 helper
- 但如果不把它们接进 `SettingsNavigationValidation.makeFixtures()`，启动时的自动 validation 根本不会实际执行
- 这会让阶段 3 停留在“代码看起来写完了，但自动链路里没跑到”的半完成状态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: SettingsNavigationValidationRunner.makeFixtures()
// 功能说明: 修改前聚合器里只有 `SR-0 / SR-1` 的 fixed-mode fixtures；
// `SR-2` 虽然已有 helper，但还没有被接进启动验证链。
SettingsNavigationValidationFixture(
    name: "sr1_root_tree_drops_invalid_exercise_and_accessory_routes",
    validate: validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes
),
SettingsNavigationValidationFixture(
    name: "sr1_settings_state_freezes_fixed_presentation_options",
    validate: validateSR1SettingsStateFreezesFixedPresentationOptions
),
```

### 修改后

- 在 root tree fixtures 里注册 `sr2_root_tree_drops_invalid_exercise_and_accessory_routes`
- 在 fixed settings fixtures 里注册 `sr2_settings_state_freezes_fixed_presentation_options`
- 这样双端 `startup-validation` 实际执行时会真的跑到新增的 `SR-2` 验证，而不是只靠单元级 helper 存在

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: SettingsNavigationValidationRunner.makeFixtures()
// 功能说明: 修改后 `SR-2` 的 root-tree 与 fixed-settings fixtures 被正式接入聚合器；
// 双端启动验证会实际执行这两个新夹具，而不是停留在“helper 已写但没人调用”的状态。
SettingsNavigationValidationFixture(
    name: "sr1_root_tree_drops_invalid_exercise_and_accessory_routes",
    validate: validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes
),
SettingsNavigationValidationFixture(
    name: "sr2_root_tree_drops_invalid_exercise_and_accessory_routes",
    validate: validateSR2RootTreeDropsInvalidExerciseAndAccessoryRoutes
),
SettingsNavigationValidationFixture(
    name: "sr1_settings_state_freezes_fixed_presentation_options",
    validate: validateSR1SettingsStateFreezesFixedPresentationOptions
),
SettingsNavigationValidationFixture(
    name: "sr2_settings_state_freezes_fixed_presentation_options",
    validate: validateSR2SettingsStateFreezesFixedPresentationOptions
),
```

## 阶段边界确认：为什么 `SettingsPanelSnapshotBuilder.swift` 本轮没有改

- 阶段 3 计划把 `SettingsPanelSnapshotBuilder.swift` 列为关键文件
- 但这不是说一定要修改它，而是要确认“`SR-2` 下无效项是否会被正确隐藏”
- 实际检查后发现，阶段 1/2 已经通过 fixed-mode helper 把这条 gate 铺好了：
- `clef` 只有在 `fixedSequenceClef == nil` 时才显示
- `pianoMovementScope` 只有在 `fixedPianoMovementScope == nil` 时才显示
- `pianoRowCount` 只有在 `fixedPianoRowCount == nil` 时才显示
- 对 `SR-2` 来说，阶段 2 已经固定了 `treble + 2 rows + rowOnly`，所以这里天然会把这些无效控件隐藏掉
- 因此本轮不改这个文件，反而更符合“从根因上解决问题，而不是平行补一层 if/else”的阶段边界

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: SettingsPanelSnapshotBuilder.shouldInclude(choiceRowID:stateContext:) / shouldInclude(sliderID:stateContext:)
// 功能说明: 这些 gate 在本轮之前就已经能按 fixed-mode contract 自动隐藏无效控件；
// 因此阶段3只需要把 `SR-2` 接进 settings 输入链路，而不需要回头修改 builder 本身。
case .clef:
    return stateContext.trainerDisplayState.exerciseMode
        .fixedSequenceClef == nil
case .pianoMovementScope:
    return stateContext.trainerDisplayState.exerciseMode
        .fixedPianoMovementScope == nil

case .pianoRowCount:
    return stateContext.trainerDisplayState.exerciseMode
        .fixedPianoRowCount == nil
```

## 本轮调试与验证说明

### IDE 诊断滞后

- `ReadLints` 在本轮末尾仍报告 `SettingsNavigationValidation.swift` 有 19 条 `Cannot find ... in scope`
- 这些错误全部来自 `SourceKit` 对同一文件里私有扩展方法的旧状态缓存，不是实际编译错误
- 同一代码随后已通过双平台 `xcodebuild` 和双端 `startup-validation`

```bash
# 文件路径: IDE 诊断输出摘录
# 函数名: ReadLints
# 功能说明: IDE 在本轮仍缓存了 `SettingsNavigationValidation.swift` 的旧索引状态；
# 这里如实记录诊断现象，但不把它记为实际代码失败。
[ERROR] L158:27 - Cannot find 'validateSR2RootTreeDropsInvalidExerciseAndAccessoryRoutes' in scope
[ERROR] L198:27 - Cannot find 'validateSR2SettingsStateFreezesFixedPresentationOptions' in scope
```

### 启动验证已实际跑到新增夹具

```bash
# 文件路径: macOS startup-validation 日志摘录
# 函数名: SettingsNavigationValidation / RuntimeSmoke
# 功能说明: macOS 启动验证实际执行了阶段3新增的两个 `SR-2` fixtures，并最终 PASS。
[SettingsNavigationValidation][macOS] fixture begin name=sr2_root_tree_drops_invalid_exercise_and_accessory_routes
[SettingsNavigationValidation][macOS] fixture end name=sr2_root_tree_drops_invalid_exercise_and_accessory_routes issues=0
[SettingsNavigationValidation][macOS] fixture begin name=sr2_settings_state_freezes_fixed_presentation_options
[SettingsNavigationValidation][macOS] fixture end name=sr2_settings_state_freezes_fixed_presentation_options issues=0
[SettingsNavigationValidation][macOS] automated=PASS fixtures=19
[RuntimeSmoke][macOS] PASS scenario=startup_validation
```

```bash
# 文件路径: iOS startup-validation 日志摘录
# 函数名: SettingsNavigationValidation / RuntimeSmoke
# 功能说明: iOS Simulator 启动验证同样执行了新增的 `SR-2` fixtures，并最终 PASS。
[SettingsNavigationValidation][iOS] fixture begin name=sr2_root_tree_drops_invalid_exercise_and_accessory_routes
[SettingsNavigationValidation][iOS] fixture end name=sr2_root_tree_drops_invalid_exercise_and_accessory_routes issues=0
[SettingsNavigationValidation][iOS] fixture begin name=sr2_settings_state_freezes_fixed_presentation_options
[SettingsNavigationValidation][iOS] fixture end name=sr2_settings_state_freezes_fixed_presentation_options issues=0
[SettingsNavigationValidation][iOS] automated=PASS fixtures=19
[RuntimeSmoke][iOS] PASS scenario=startup_validation
```

## 本轮实际命令

```bash
# 文件路径: 工程级验证命令
# 函数名: date / xcodebuild / startup-validation
# 功能说明: 本次阶段3记录使用的时间戳命令与实际跑过的构建、启动验证命令。
date +"%Y%m%d_%H%M%S"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage3_mac" build
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage3_ios" build
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation "/tmp/NoteMaster_Ver_1_stage3_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl boot "iPhone 17" >/dev/null 2>&1 || true
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl bootstatus "iPhone 17" -b
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl install booted "/tmp/NoteMaster_Ver_1_stage3_ios/Build/Products/Debug-iphonesimulator/NoteMaster_Ver_1.app"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
```

## 对后续阶段的直接意义

- 阶段 4 现在可以直接在双端 runtime smoke 里切到 `SR-2`，不需要再为“如何从 settings 进入 `SR-2`”补一层临时 debug 入口
- `SR-2` 的 settings / navigation 合同已经在 shared validation 里正式注册，因此阶段 4 之后若 smoke 失败，可以快速区分“入口未接上”还是“运行时行为回归”
- 如果后续产品要继续调整 `SR-2` 的固定矩阵，也只能改集中 contract 与对应 validation / smoke；阶段 3 已经避免了把模式入口逻辑散落到更多 controller 或 view 层

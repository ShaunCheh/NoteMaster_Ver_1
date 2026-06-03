# 20260603_182350_fr0_mode_fixed_side_coverage_persistent_feedback

## 记录范围

本记录只覆盖刚刚这一轮 `FR-0` 模式接入的实际修改，整理依据来自当前工作区的：

- `date +%Y%m%d_%H%M%S`，得到本次记录时间戳：`20260603_182350`
- `git status --short`
- `git diff --stat`
- 本轮 20 个 Swift 文件的 `git diff`

本文**不直接粘贴原始 `git diff`**，而是按真实改动把“修改前 / 修改后”的关键代码重新整理成可读片段。

## 当前 changes 说明

当前工作区除了本轮功能代码外，还存在一个 IDE 生成的额外变更：

- `NoteMaster_Ver_1.xcodeproj/project.xcworkspace/xcuserdata/shaun.xcuserdatad/UserInterfaceState.xcuserstate`

这个文件来自 IDE 状态写回，不属于本轮 `FR-0` 功能接入本身，下面的功能说明和统计都**不把它计入代码修改范围**。

排除上面的 IDE 生成文件后，本轮功能差异为：

- `20 files changed`
- `816 insertions(+)`
- `75 deletions(-)`

## 触达文件

本轮实际修改的代码文件如下：

- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

---

## 1. 新增 `FR-0` mode，并把它收敛成固定 `targetPrompt -> fretboard + sideBySide`

修改前，`TrainerExerciseMode` 里没有 `FR-0`；fixed layout contract 只覆盖 `P-2` 和 `SR` 家族，`single`/`positionPrompt` 也没有“共用 Position Question Notes 题池”的语义。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode / fixedExerciseLayoutPreferences / usesQuarterNoteSequenceKernel
// 功能注释: 修改前没有 FR-0，也没有 FR-0 专用 fixed layout contract。
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
// 函数名/符号: ExerciseLayoutPreferences
// 功能注释: 修改前 shared layout constants 里没有 FR-0 的固定布局常量。
static let p2StaffFretboardAnswer = ExerciseLayoutPreferences(
    compositionPreset: .staffToFretboard,
    layoutPreset: .stacked,
    accessoryPresentation: .docked,
    isNaturalNoteStripVisible: false,
    isPianoAccessoryVisible: false,
    isAccessoryExpanded: true,
    verticalFretboardWidthScale: 2,
    verticalFretboardOverflowScrollAxis: .vertical
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

修改后，`FR-0` 成为正式 mode，并通过 `fixedExerciseLayoutPreferences` 直接固定到 `targetPromptToFretboard + sideBySide`。同时新增了 `isFR0Mode` 和 `usesPositionQuestionPitchClassPool`，后续 settings、trainer、controller 都据此走统一分支。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode / fixedExerciseLayoutPreferences / isFR0Mode / usesPositionQuestionPitchClassPool
// 功能注释: 修改后 FR-0 作为独立 exercise mode 进入 shared state，并显式占有固定 side layout contract。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case p2
    case positionPrompt
    case fr0
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
    case .fr0:
        return .fr0TargetPromptFretboardAnswer
    case .sr0:
        return .srNoteStripAnswer
    case .single, .sequence, .positionPrompt:
        return nil
    }
}

var isFR0Mode: Bool {
    exerciseMode == .fr0
}

var usesPositionQuestionPitchClassPool: Bool {
    isPositionPromptMode || isFR0Mode
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: ExerciseLayoutPreferences.fr0TargetPromptFretboardAnswer
// 功能注释: 修改后 FR-0 的 layout contract 被集中定义为左 prompt、右 fretboard、无 accessory 的固定 side layout。
static let fr0TargetPromptFretboardAnswer = ExerciseLayoutPreferences(
    compositionPreset: .targetPromptToFretboard,
    layoutPreset: .sideBySide,
    accessoryPresentation: .docked,
    isNaturalNoteStripVisible: false,
    isPianoAccessoryVisible: false,
    isAccessoryExpanded: true
)
```

---

## 2. 把 `FR-0` 正式暴露到 Settings / Navigation，并让它复用 `Position Question Notes`

修改前，`Exercise Mode` row 里没有 `FR-0`；`positionQuestionPitchClasses` 这一行只在 `positionPrompt` 模式下显示，导致 `FR-0` 就算内部支持，也没有 settings 入口可配。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / SettingsActionID
// 功能注释: 修改前 Exercise Mode row 没有 FR-0，也没有对应 action / title / accessibility label。
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

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setRootModeExercise
    case setRootModePlay
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModeP2
    case setExerciseModeSr0
    case setExerciseModeSr1
    case setExerciseModeSr2
    case setExerciseModePositionPrompt
    // ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: shouldInclude(positionFilterRowID:stateContext:)
// 功能注释: 修改前 Position Question Note Names 只服务 positionPrompt，FR-0 无法共用这组过滤条件。
switch positionFilterRowID {
case .positionQuestionPitchClasses:
    return stateContext.trainerDisplayState.isPositionPromptMode
case .positionPromptFilterOptions:
    return false
}
```

修改后，`FR-0` 已经被完整挂进 `SettingsActionID`、标题、选中态、写回逻辑和导航 subtitle；同时 `Position Question Notes` 行改成由 `usesPositionQuestionPitchClassPool` 驱动，这样 `positionPrompt` 和 `FR-0` 共享同一套音名池。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / SettingsActionID.title / SettingsActionID.accessibilityLabel / SettingsActionID.apply(to:)
// 功能注释: 修改后 FR-0 成为正式的 settings mode 选项，并能从 UI 直接写回 trainerDisplayState。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeP2,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModeSr2,
        .setExerciseModeFr0,
        .setExerciseModePositionPrompt
    ]

case .setExerciseModeFr0:
    return "FR-0"

case .setExerciseModeFr0:
    return "Train full fretboard note-name coverage with a fixed left-prompt right-fretboard side layout"

case .setExerciseModeFr0:
    displayState.setExerciseMode(.fr0)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: shouldInclude(positionFilterRowID:stateContext:)
// 功能注释: 修改后 Position Question Note Names 行会在 FR-0 和 positionPrompt 下共同出现，FR-0 直接复用现有音名过滤池。
switch positionFilterRowID {
case .positionQuestionPitchClasses:
    return stateContext.trainerDisplayState.usesPositionQuestionPitchClassPool
case .positionPromptFilterOptions:
    return false
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: childPageSpecs(for:)
// 功能注释: 修改后导航文案同步把 FR-0 写入 Exercise > Mode subtitle，避免 UI 文案和真实 mode 集合脱节。
ChildPageSpec(
    route: .exerciseMode,
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, P-2, SR-0, SR-1, SR-2, FR-0, or position",
    rowIDs: [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses)
    ]
)
```

---

## 3. 把单音覆盖内核升级成“可配置题池 + 持久 wrong cells”

修改前，`singleCoverage` 只会从自然音全集里随机出题，feedback 也只支持单个 `wrongCell`，因此没法满足 `FR-0` 的两个核心要求：

1. 出题必须受 `Position Question Notes` 过滤
2. 一题里多个错点都要一直保留到切题

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: FretboardNaturalNoteTrainerState.init / advanceToNextTarget / randomNaturalPitchClass
// 功能注释: 修改前 single coverage 只有一个固定的“自然音全集”出题池，不能按 settings 传入受限 target pool。
private(set) var mode: ExerciseMode
private(set) var targetPitchClass: PitchClass
private(set) var generatedQuarterNoteSequence: GeneratedNoteSequence?

init(targetPitchClass: PitchClass) {
    precondition(
        targetPitchClass.isNatural,
        "Target pitch class must be a natural note."
    )
    self.mode = .singleNaturalTarget
    self.targetPitchClass = targetPitchClass
    generatedQuarterNoteSequence = nil
}

mutating func advanceToNextTarget<R: RandomNumberGenerator>(
    using generator: inout R
) -> PitchClass {
    requireSingleNaturalTargetMode()
    let nextTargetPitchClass = Self.randomNaturalPitchClass(
        excluding: targetPitchClass,
        using: &generator
    )
    targetPitchClass = nextTargetPitchClass
    return nextTargetPitchClass
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift
// 函数名/符号: FretboardFeedbackOverlayState.singleCoverage
// 功能注释: 修改前覆盖反馈只允许一个 wrongCell，无法持久保留多次错误点击。
case singleCoverage(
    correctCells: Set<FretboardCell>,
    wrongCell: FretboardCell?
)

var isEmpty: Bool {
    switch self {
    case .empty:
        return true
    case let .singleCoverage(correctCells, wrongCell):
        return correctCells.isEmpty && wrongCell == nil
    case .positionPrompt:
        return false
    }
}
```

修改后，`FretboardNaturalNoteTrainerState` 新增了 `singleCoverageTargetPool`，并且所有 single-coverage 初始化和切题都遵守这组池子；同时 `FretboardFeedbackOverlayState` 和 `FretboardFeedbackLayer` 升级为 `wrongCells: Set<FretboardCell>`，支持多红圈持久保留。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: FretboardNaturalNoteTrainerState.init / init(singleCoverageTargetPool:) / advanceToNextTarget / randomSingleCoverageTargetPitchClass
// 功能注释: 修改后 FR-0 可以把 Position Question Notes 过滤结果注入 single coverage trainer，切题时也只会在这个池子里选下一题。
private(set) var mode: ExerciseMode
private(set) var targetPitchClass: PitchClass
private(set) var singleCoverageTargetPool: Set<PitchClass>
private(set) var generatedQuarterNoteSequence: GeneratedNoteSequence?

init(
    targetPitchClass: PitchClass,
    singleCoverageTargetPool: Set<PitchClass>
) {
    let resolvedTargetPool = Self.normalizedSingleCoverageTargetPool(
        singleCoverageTargetPool
    )
    precondition(targetPitchClass.isNatural)
    precondition(resolvedTargetPool.contains(targetPitchClass))
    self.mode = .singleNaturalTarget
    self.targetPitchClass = targetPitchClass
    self.singleCoverageTargetPool = resolvedTargetPool
    generatedQuarterNoteSequence = nil
}

init(singleCoverageTargetPool: Set<PitchClass>) {
    var generator = SystemRandomNumberGenerator()
    self.init(
        randomUsing: &generator,
        singleCoverageTargetPool: singleCoverageTargetPool
    )
}

mutating func advanceToNextTarget<R: RandomNumberGenerator>(
    using generator: inout R
) -> PitchClass {
    requireSingleNaturalTargetMode()
    let nextTargetPitchClass = Self.randomSingleCoverageTargetPitchClass(
        from: singleCoverageTargetPool,
        excluding: targetPitchClass,
        using: &generator
    )
    targetPitchClass = nextTargetPitchClass
    return nextTargetPitchClass
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift
// 函数名/符号: FretboardFeedbackOverlayState.singleCoverage
// 功能注释: 修改后 singleCoverage feedback 把错误集合化，允许 FR-0 在切题前同时保留多个红圈。
case singleCoverage(
    correctCells: Set<FretboardCell>,
    wrongCells: Set<FretboardCell>
)

var isEmpty: Bool {
    switch self {
    case .empty:
        return true
    case let .singleCoverage(correctCells, wrongCells):
        return correctCells.isEmpty && wrongCells.isEmpty
    case .positionPrompt:
        return false
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift
// 函数名/符号: drawSingleCoverageFeedback(correctCells:wrongCells:in:)
// 功能注释: 修改后渲染层会对 wrongCells 排序并逐个画出红圈，不再只渲染最后一个错误位置。
private func drawSingleCoverageFeedback(
    correctCells: Set<FretboardCell>,
    wrongCells: Set<FretboardCell>,
    in context: CGContext
) {
    let orderedCorrectCells = correctCells.sorted {
        if $0.stringIndex == $1.stringIndex {
            return $0.fret < $1.fret
        }
        return $0.stringIndex < $1.stringIndex
    }
    for cell in orderedCorrectCells {
        drawFeedback(
            for: cell,
            fillColor: FretboardPalette.feedbackCorrectFill,
            strokeColor: FretboardPalette.feedbackCorrectStroke,
            in: context
        )
    }

    let orderedWrongCells = wrongCells.sorted {
        if $0.stringIndex == $1.stringIndex {
            return $0.fret < $1.fret
        }
        return $0.stringIndex < $1.stringIndex
    }
    for wrongCell in orderedWrongCells {
        drawFeedback(
            for: wrongCell,
            fillColor: FretboardPalette.feedbackWrongFill,
            strokeColor: FretboardPalette.feedbackWrongStroke,
            in: context
        )
    }
}
```

另外，answer router 也同步把 `FR-0` 并入 single-coverage 路由，确保右侧 fretboard 点击直接进入这条内核，而不是误落到 sequence / positionPrompt。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: ExerciseAnswerRouter.route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能注释: 修改后 FR-0 与 single 共用 singleCoverage answer route，右侧指板点击直接走覆盖式答题链。
switch trainerDisplayState.exerciseMode {
case .single, .fr0:
    guard let cell = event.payload.fretboardCell else {
        return .ignored(
            .unsupportedPayload(
                event.payload,
                trainerDisplayState.exerciseMode
            )
        )
    }
    return .routed(.singleCoverage(event: event, cell: cell))
case .sequence, .p2, .sr0, .sr1, .sr2:
    // ...
case .positionPrompt:
    // ...
}
```

---

## 4. 给 `FR-0` 单独的 side scene 语义，并修正 legacy bridge fallback

修改前，`targetPrompt -> fretboard` 的 side-by-side 一律走左右 `weighted(1)`；这会让 `FR-0` 变成“普通左右平分”，而不是“左 prompt 收内容、右主指板保持主答题区”的语义。另外，legacy fallback 也不认识 `FR-0`，会把它直接当成 `.default`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: makeSideBySideSceneNode(from:preferences:trainerDisplayState:)
// 功能注释: 修改前 targetPrompt->fretboard 的 side layout 没有 FR-0 特判，默认左右两侧都是 weighted(1)。
private static func makeSideBySideSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState?
) -> ExerciseSceneNode {
    switch preferences.compositionPreset {
    case .fretboardToNaturalNoteStrip, .staffToNaturalNoteStrip:
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.prompt),
                    mainAxisSizing: .weighted(1)
                ),
                ExerciseSceneSplitChild(
                    node: .surface(
                        sceneSurfaces.answer.withPresentationStyle(.verticalRail)
                    ),
                    mainAxisSizing: .fitContent
                )
            ]
        )
    case .staffToFretboard, .staffToPiano, .targetPromptToFretboard:
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.prompt),
                    mainAxisSizing: .weighted(1)
                ),
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.answer),
                    mainAxisSizing: .weighted(1)
                )
            ]
        )
    case .fretboardSelfAnswer:
        return .surface(sceneSurfaces.prompt)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: legacyCompatibleTrainerDisplayState(_:)
// 功能注释: 修改前只有 sequence kernel 家族会在 legacy fallback 时被改写成 .sequence，FR-0 没有专门处理。
private static func legacyCompatibleTrainerDisplayState(
    _ trainerDisplayState: TrainerDisplayState
) -> TrainerDisplayState {
    var legacyCompatibleState = trainerDisplayState
    if legacyCompatibleState.exerciseMode.usesQuarterNoteSequenceKernel,
       legacyCompatibleState.exerciseMode != .sequence {
        legacyCompatibleState.exerciseMode = .sequence
    }
    return legacyCompatibleState
}
```

修改后，`FR-0` 在 `targetPromptToFretboard + sideBySide` 下会强制变成左 `fitContent`、右 `weighted(1)`；同时 legacy fallback 会先把 `FR-0` 退回 `.single` host mode，再去做 page bridge，避免 fixed side scene 重新把 fallback 语义拉坏。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: makeSideBySideSceneNode(from:preferences:trainerDisplayState:)
// 功能注释: 修改后 FR-0 拥有独立的 side scene 语义，左 prompt 收内容，右 fretboard 保持主答题区宽度。
private static func makeSideBySideSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState?
) -> ExerciseSceneNode {
    if trainerDisplayState?.isFR0Mode == true,
       preferences.compositionPreset == .targetPromptToFretboard {
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.prompt),
                    mainAxisSizing: .fitContent
                ),
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.answer),
                    mainAxisSizing: .weighted(1)
                )
            ]
        )
    }

    switch preferences.compositionPreset {
    case .fretboardToNaturalNoteStrip, .staffToNaturalNoteStrip:
        // ...
    case .staffToFretboard, .staffToPiano, .targetPromptToFretboard:
        // ...
    case .fretboardSelfAnswer:
        return .surface(sceneSurfaces.prompt)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: legacyCompatibleTrainerDisplayState(_:)
// 功能注释: 修改后 FR-0 在 legacy fallback 中会先退回 single host mode，避免 fixed side scene 在 page bridge 阶段再次被强制拉回。
private static func legacyCompatibleTrainerDisplayState(
    _ trainerDisplayState: TrainerDisplayState
) -> TrainerDisplayState {
    var legacyCompatibleState = trainerDisplayState
    if legacyCompatibleState.exerciseMode == .fr0 {
        // Explicit legacy fallback should render through a layout-compatible
        // single-target host mode instead of being re-normalized back to the
        // fixed FR-0 side scene.
        legacyCompatibleState.exerciseMode = .single
    } else if legacyCompatibleState.exerciseMode.usesQuarterNoteSequenceKernel,
              legacyCompatibleState.exerciseMode != .sequence {
        legacyCompatibleState.exerciseMode = .sequence
    }
    return legacyCompatibleState
}
```

另外，`ExerciseCompositionPolicy+Normalization.swift`、`LegacyPageLayoutAdapter.swift` 和 `SettingsPanelStateContext.swift` 也一起补上了 `FR-0` 的 normalized path / page fallback / layout contract 透传，避免 fixed mode 只改到一半。

---

## 5. iOS / macOS 控制器接入 `FR-0` 的 prompt、题池会话和持久红圈

修改前，平台控制器只有 `single / sequence / positionPrompt` 三条同步路径；single-coverage prompt 默认会显示 coverage 进度内容，也没有单独的 `FR-0` prompt 和 `singleCoverageWrongCells`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: currentSingleCoverageTargetPromptContent / currentFretboardFeedbackOverlayState / synchronizeTrainerPresentationState
// 功能注释: 修改前 iOS 控制器没有 FR-0 分支，single coverage 也只保留最后一个 wrong cell。
private var currentSingleCoverageTargetPromptContent: TargetPromptContent {
    guard let singleCoverageSession,
          singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) else {
        return .single(
            text: fretboardTrainerState.targetPitchClass.displayText(
                using: displayState.spelling
            )
        )
    }

    return singleCoverageSession.targetPromptContent(
        spelling: displayState.spelling
    )
}

private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        let wrongCell: FretboardCell?
        if let singleCoverageLastEvaluation,
           singleCoverageLastEvaluation.hitKind == .wrong {
            wrongCell = singleCoverageLastEvaluation.selectedCell
        } else {
            wrongCell = nil
        }

        return .singleCoverage(
            correctCells: singleCoverageSession.visitedCells,
            wrongCell: wrongCell
        )
    case .positionPrompt:
        // ...
    case .quarterNoteSequence:
        return .empty
    }
}

private func synchronizeTrainerPresentationState(reason: String) {
    if trainerDisplayState.usesQuarterNoteSequenceKernel {
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    } else if trainerDisplayState.isPositionPromptMode {
        synchronizePositionPromptPresentation(reason: reason)
    } else {
        synchronizeSingleTrainerPresentation(reason: reason)
    }
}
```

修改后，平台层新增了：

1. `currentFR0TargetPromptContent`，左侧只显示音名，不显示 `2/5`
2. `currentFR0TargetPitchClassPool` / `expectedSingleCoverageTargetPool`
3. `singleCoverageWrongCells`
4. `synchronizeFR0Presentation` / `applyFR0Projection`
5. 在答题回调中仅当 `FR-0` 错答时累计红圈，并在切题时统一清空

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: currentFR0TargetPromptContent / currentFretboardFeedbackOverlayState / clearSingleCoverageFeedbackState / singleCoverageSessionMatchesCurrentTrainer
// 功能注释: 修改后 iOS 控制器把 FR-0 的“只显示音名 + 多红圈持久保留 + 题池一致性”全部落到平台投影层。
private var currentFR0TargetPromptContent: TargetPromptContent {
    .single(
        text: fretboardTrainerState.targetPitchClass.displayText(
            using: displayState.spelling
        )
    )
}

private var currentFR0TargetPitchClassPool: Set<PitchClass> {
    Set(trainerDisplayState.positionQuestionConfiguration.sortedSelectedPitchClasses)
}

private var expectedSingleCoverageTargetPool: Set<PitchClass> {
    trainerDisplayState.isFR0Mode
        ? currentFR0TargetPitchClassPool
        : Set(PitchClass.naturalCasesInOrder)
}

private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        let wrongCells: Set<FretboardCell>
        if trainerDisplayState.isFR0Mode {
            wrongCells = singleCoverageWrongCells
        } else if let singleCoverageLastEvaluation,
                  singleCoverageLastEvaluation.hitKind == .wrong {
            wrongCells = [singleCoverageLastEvaluation.selectedCell]
        } else {
            wrongCells = []
        }

        return .singleCoverage(
            correctCells: singleCoverageSession.visitedCells,
            wrongCells: wrongCells
        )
    case .positionPrompt:
        // ...
    case .quarterNoteSequence:
        return .empty
    }
}

private func clearSingleCoverageFeedbackState() {
    singleCoverageLastEvaluation = nil
    singleCoverageWrongCells.removeAll()
}

private func singleCoverageSessionMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.SingleCoverageSession
) -> Bool {
    fretboardTrainerState.singleCoverageTargetPool
        == expectedSingleCoverageTargetPool
        && session.targetPitchClass == fretboardTrainerState.targetPitchClass
        && session.requiredCells == currentSingleCoverageRequiredCells
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: synchronizeTrainerPresentationState(reason:) / synchronizeFR0Presentation(reason:) / applyFR0Projection(reason:showsLog:)
// 功能注释: 修改后 FR-0 有自己独立的平台投影分支，不再借用 single 或 positionPrompt 的 presentation 同步逻辑。
private func synchronizeTrainerPresentationState(reason: String) {
    logLifecycle("synchronizeTrainerPresentationState reason=\(reason)")
    if trainerDisplayState.usesQuarterNoteSequenceKernel {
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    } else if trainerDisplayState.isFR0Mode {
        synchronizeFR0Presentation(reason: reason)
    } else if trainerDisplayState.isPositionPromptMode {
        synchronizePositionPromptPresentation(reason: reason)
    } else {
        synchronizeSingleTrainerPresentation(reason: reason)
    }
}

private func synchronizeFR0Presentation(reason: String) {
    resetPositionPromptInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    if reason == "positionQuestionCandidatesChanged" {
        resetSingleCoverageInteractionState()
    }

    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        if fretboardTrainerState.singleCoverageTargetPool
            != expectedSingleCoverageTargetPool {
            resetSingleCoverageInteractionState()
            fretboardTrainerState = FretboardNaturalNoteTrainerState(
                singleCoverageTargetPool: currentFR0TargetPitchClassPool
            )
        }
    case .positionPrompt, .quarterNoteSequence:
        resetSingleCoverageInteractionState()
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            singleCoverageTargetPool: currentFR0TargetPitchClassPool
        )
    }

    synchronizeExerciseCompositionState(reason: reason)
    applyFR0Projection(reason: reason, showsLog: true)
}

private func applyFR0Projection(
    reason: String,
    showsLog: Bool = true
) {
    ensureSingleCoverageSession()
    targetNotePromptView.apply(content: currentFR0TargetPromptContent)
    applyCurrentFretboardFeedbackOverlayState()
    updateAnswerSurfaceInteractionState()

    guard showsLog else {
        return
    }

    print(
        "[FR-0][iOS] target=\(currentFretboardTrainerPrompt.displayText) state=\(reason)"
    )
}
```

`macOSViewController.swift` 也做了同构接线，结构与 iOS 对称：新增 `singleCoverageWrongCells`、`currentFR0TargetPromptContent`、`synchronizeFR0Presentation`、`applyFR0Projection`，并且在 `handleSingleCoverageAnswer(_:)` 里只对 `FR-0` 累计错误圈状态。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: synchronizeFR0Presentation(reason:) / applyFR0Projection(reason:showsLog:)
// 功能注释: macOS 控制器和 iOS 一样，给 FR-0 单独开了一条平台投影分支，避免复用 single 的默认 prompt/progress 逻辑。
private func synchronizeFR0Presentation(reason: String) {
    resetPositionPromptInteractionState()
    resetQuarterNoteSequenceInteractionState()
    // ... staff reset / target pool change reset ...
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        if fretboardTrainerState.singleCoverageTargetPool
            != expectedSingleCoverageTargetPool {
            resetSingleCoverageInteractionState()
            fretboardTrainerState = FretboardNaturalNoteTrainerState(
                singleCoverageTargetPool: currentFR0TargetPitchClassPool
            )
        }
    case .positionPrompt, .quarterNoteSequence:
        resetSingleCoverageInteractionState()
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            singleCoverageTargetPool: currentFR0TargetPitchClassPool
        )
    }
    synchronizeExerciseCompositionState(reason: reason)
    applyFR0Projection(reason: reason, showsLog: true)
}

private func applyFR0Projection(
    reason: String,
    showsLog: Bool = true
) {
    ensureSingleCoverageSession()
    targetNotePromptView.apply(content: currentFR0TargetPromptContent)
    applyCurrentFretboardFeedbackOverlayState()
    updateAnswerSurfaceInteractionState()
    // ... FR-0 console projection log ...
}
```

---

## 6. 补齐 `FR-0` 的 settings / composition validation

修改前，validation 只覆盖 `P-2`、`SR` 家族和已有 legacy baseline，没有 `FR-0` 的 settings freeze / legacy baseline / side scene contract 断言。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: makeFixtures()
// 功能注释: 修改前 settings validation fixture 列表里没有 FR-0。
SettingsNavigationValidationFixture(
    name: "p2_settings_state_freezes_fixed_presentation_options",
    validate: validateP2SettingsStateFreezesFixedPresentationOptions
),
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

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: makeFixtures()
// 功能注释: 修改前 exercise composition validation fixture 列表里没有 FR-0 baseline。
ExerciseCompositionValidationFixture(
    name: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
    validate: validateLegacySingleBaseline
),
ExerciseCompositionValidationFixture(
    name: "legacy_sequence_baseline_matches_stacked_staff_over_fretboard",
    validate: validateLegacySequenceBaseline
),
ExerciseCompositionValidationFixture(
    name: "legacy_p2_baseline_matches_stacked_staff_over_fretboard",
    validate: validateLegacyP2Baseline
),
ExerciseCompositionValidationFixture(
    name: "legacy_position_prompt_baseline_matches_fretboard_over_natural_strip",
    validate: validateLegacyPositionPromptBaseline
)
```

修改后，validation 明确把 `FR-0` 纳入自动化夹具，校验内容覆盖：

1. settings 写回是否固定到 `targetPromptToFretboard + sideBySide`
2. `Exercise Mode` 顺序/标题/选中态是否包含 `FR-0`
3. 是否只保留 `Exercise Mode + Position Question Note Names`
4. legacy baseline 是否保持 `targetPrompt -> fretboard`
5. side scene 是否保持左 `fitContent`、右 `weighted(1)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名/符号: validateFR0SettingsStateFreezesFixedPresentationOptions()
// 功能注释: 修改后新增 FR-0 settings freeze 夹具，锁住 mode 列表、fixed layout、legacy page bridge、Exercise section 收敛和 Accessories 隐藏。
static func validateFR0SettingsStateFreezesFixedPresentationOptions()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "fr0_settings_state_freezes_fixed_presentation_options"
    var issues: [SettingsNavigationValidationIssue] = []
    var stateContext = SettingsPanelStateContext(
        exerciseLayoutPreferences: ExerciseLayoutPreferences(
            compositionPreset: .staffToFretboard,
            layoutPreset: .stacked,
            accessoryPresentation: .collapsible,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: false
        ),
        trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
        pianoPanelState: PianoPanelState(
            isVisible: true,
            rowCount: 6,
            movementScope: .cascade
        )
    )
    SettingsPanelEvent.triggerAction(.setExerciseModeFr0).apply(to: &stateContext)

    if stateContext.exerciseLayoutPreferences != .fr0TargetPromptFretboardAnswer {
        // ... fixed side layout 断言 ...
    }
    if stateContext.pageDisplayState
        != PageDisplayState(
            topContentMode: .targetPrompt,
            mainContentMode: .fretboard
        ) {
        // ... legacy page bridge 断言 ...
    }
    if exerciseSection.rows.map(\.id) != [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses)
    ] {
        // ... Exercise section 收敛断言 ...
    }
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateLegacyFR0Baseline() / validateLegacyBaseline(...) / validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()
// 功能注释: 修改后新增 FR-0 的 legacy baseline 与 side scene contract 自动化断言。
static func validateLegacyFR0Baseline()
    -> [ExerciseCompositionValidationIssue] {
    validateLegacyBaseline(
        fixtureName: "legacy_fr0_baseline_matches_target_prompt_over_fretboard",
        exerciseMode: .fr0,
        expectedPageDisplayState: PageDisplayState(
            topContentMode: .targetPrompt,
            mainContentMode: .fretboard
        )
    )
}

let fr0SideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
    from: ExerciseCompositionPolicyInput(
        trainerDisplayState: TrainerDisplayState(exerciseMode: .fr0),
        fretboardTrainerState: .init(
            singleCoverageTargetPool: Set([.a, .c, .e])
        ),
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pianoPanelState: .init(),
        layoutPreferences: ExerciseLayoutPreferences(
            compositionPreset: .staffToFretboard,
            layoutPreset: .stacked,
            accessoryPresentation: .collapsible,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: false
        )
    )
)

if fr0SideBySidePresentation.resolvedLayoutPreferences
    != .fr0TargetPromptFretboardAnswer {
    // ... fixed normalization 断言 ...
}
if children[0].mainAxisSizing != .fitContent
    || children[1].mainAxisSizing != .weighted(1) {
    // ... side main-axis sizing 断言 ...
}
```

---

## 验证结果

本轮实际执行了以下验证：

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation "/Users/shaun/Library/Developer/Xcode/DerivedData/NoteMaster_Ver_1-dmwiqnlpdpssbzbbzjlcvckqawwe/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"`

验证结果：

- Debug 构建通过
- `startup-validation` 通过
- `SettingsNavigationValidation` 中新增的 `fr0_settings_state_freezes_fixed_presentation_options` 夹具通过
- `ExerciseCompositionValidation` 中新增的 `legacy_fr0_baseline_matches_target_prompt_over_fretboard` 夹具通过
- `ReadLints` 针对本轮修改文件读取后，没有新增 linter error

## 结论

这次 `FR-0` 不是给现有 `Position` 模式加一个分支，而是沿着当前 shared 架构做成了一条完整的独立模式链路：

- shared mode 层正式新增 `FR-0`
- settings / navigation 正式暴露 `FR-0`
- 出题池直接复用 `Position Question Notes`
- trainer 升级成“可配置题池 + 多 wrong cells 持久保留”
- side scene 不是普通 1:1 分栏，而是左 `fitContent`、右主指板 `weighted(1)`
- iOS / macOS 控制器都接入了独立的 `FR-0` projection
- settings / composition validation 也已经补齐

也就是说，`FR-0` 现在已经是架构里的一个**固定 side layout + 覆盖式答题 + 持久反馈**的正式 mode，而不是在现有模式上临时拼出来的一组 UI 状态。

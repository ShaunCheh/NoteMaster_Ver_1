# 20260401_213500_phase6_cutover_from_legacy_page_display_state

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_213500`
- 记录范围：`场景树迁移` 计划的阶段 6；正式切走旧 `PageDisplayState` 业务主链
- 修改性质：让 settings / controllers 以 `exerciseLayoutPreferences`、`exercisePresentationState` 为第一真相；`PageDisplayState` 只保留为 legacy bridge
- 修改统计：`9 files changed, 90 insertions(+), 317 deletions(-)`
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. `SettingsPanelStateContext` 改成 “layout preferences first”，`PageDisplayState` 退成兼容投影

- 修改前：`SettingsPanelStateContext` 仍把 `pageDisplayState` 当成主输入；默认值直接写死为 `.positionPrompt`，再从它推导 `exerciseLayoutPreferences`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: SettingsPanelStateContext.default, SettingsPanelStateContext.init(...)
// 功能说明: 修改前 settings context 仍以 legacy pageDisplayState 为起点，再从它推导 ExerciseLayoutPreferences。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState

    static let `default` = SettingsPanelStateContext(
        pageDisplayState: .positionPrompt,
        trainerDisplayState: .default,
        pianoPanelState: .init()
    )

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState = .default,
        exerciseLayoutPreferences: ExerciseLayoutPreferences? = nil,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init()
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.pageDisplayState = pageDisplayState
        self.trainerDisplayState = trainerDisplayState
        self.pianoPanelState = pianoPanelState
        self.exerciseLayoutPreferences = exerciseLayoutPreferences
            ?? LegacyPageLayoutAdapter.inferredPreferences(
                pageDisplayState: pageDisplayState,
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: pianoPanelState
            )
    }
}
```

- 修改后：默认态和初始化流程都先确定 `exerciseLayoutPreferences`，再把 `pageDisplayState` 当作 bridge 投影出来；如果调用方仍传 legacy `pageDisplayState`，只把它当作兼容入口。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: SettingsPanelStateContext.default, SettingsPanelStateContext.init(...), SettingsPanelStateContext.resolvedLayoutPreferences(...)
// 功能说明: 修改后 settings context 先解析 ExerciseLayoutPreferences，再把 PageDisplayState 作为 legacy 投影补回去。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState

    static let `default` = SettingsPanelStateContext(
        exerciseLayoutPreferences: .legacyPositionPrompt,
        trainerDisplayState: .default,
        pianoPanelState: .init()
    )

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState? = nil,
        exerciseLayoutPreferences: ExerciseLayoutPreferences? = nil,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init()
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.trainerDisplayState = trainerDisplayState
        self.pianoPanelState = pianoPanelState
        self.exerciseLayoutPreferences = Self.resolvedLayoutPreferences(
            pageDisplayState: pageDisplayState,
            exerciseLayoutPreferences: exerciseLayoutPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: pianoPanelState
        )
        self.pageDisplayState = pageDisplayState
            ?? LegacyPageLayoutAdapter.projectedPageDisplayState(
                from: self.exerciseLayoutPreferences,
                trainerDisplayState: trainerDisplayState
            )
        LegacyPageLayoutAdapter.reconcile(&self)
    }

    private static func resolvedLayoutPreferences(
        pageDisplayState: PageDisplayState?,
        exerciseLayoutPreferences: ExerciseLayoutPreferences?,
        trainerDisplayState: TrainerDisplayState,
        pianoPanelState: PianoPanelState
    ) -> ExerciseLayoutPreferences {
        if let exerciseLayoutPreferences {
            return LegacyPageLayoutAdapter.normalizedPreferences(
                exerciseLayoutPreferences,
                trainerDisplayState: trainerDisplayState
            )
        }

        if let pageDisplayState {
            return LegacyPageLayoutAdapter.inferredPreferences(
                pageDisplayState: pageDisplayState,
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: pianoPanelState
            )
        }

        var fallbackPreferences = trainerDisplayState.isPositionPromptMode
            ? ExerciseLayoutPreferences.legacyPositionPrompt
            : .default
        fallbackPreferences.isPianoAccessoryVisible = pianoPanelState.isVisible
        return LegacyPageLayoutAdapter.normalizedPreferences(
            fallbackPreferences,
            trainerDisplayState: trainerDisplayState
        )
    }
}
```

- 同时，`PageDisplayState` 不再保留旧的可变写入口，只作为 bridge 结构和归一化初始化存在。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数名: PageDisplayState.setTopContentMode(...), PageDisplayState.setMainContentMode(...), PageDisplayState.normalizeFretboardPlacement(...)
// 功能说明: 修改前 PageDisplayState 仍然可以被业务层直接改写，并在内部做 top/main 归一化。
struct PageDisplayState: Equatable, Sendable {
    // ... 其余属性省略

    mutating func setTopContentMode(_ mode: PageTopContentMode) {
        topContentMode = mode
        normalizeFretboardPlacement(prioritizingTopContent: true)
    }

    mutating func setMainContentMode(_ mode: PageMainContentMode) {
        mainContentMode = mode
        normalizeFretboardPlacement(prioritizingTopContent: false)
    }

    private mutating func normalizeFretboardPlacement(
        prioritizingTopContent: Bool
    ) {
        self = ExerciseSceneValidator.normalizedLegacyPageDisplayState(
            from: self,
            prioritizingTopContent: prioritizingTopContent
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数名: PageDisplayState.init(...)
// 功能说明: 修改后 PageDisplayState 只保留初始化归一化和 bridge 属性，不再提供业务层直接写 top/main 的入口。
struct PageDisplayState: Equatable, Sendable {
    var topContentMode: PageTopContentMode
    var mainContentMode: PageMainContentMode

    static let `default` = PageDisplayState(
        topContentMode: .staff,
        mainContentMode: .fretboard
    )
    static let positionPrompt = PageDisplayState(
        topContentMode: .fretboard,
        mainContentMode: .naturalNoteStrip
    )

    init(
        topContentMode: PageTopContentMode = .staff,
        mainContentMode: PageMainContentMode = .fretboard
    ) {
        self.topContentMode = topContentMode
        self.mainContentMode = mainContentMode
        self = ExerciseSceneValidator.normalizedLegacyPageDisplayState(
            from: self,
            prioritizingTopContent: true
        )
    }

    var showsFretboardInTopContent: Bool {
        topContentMode == .fretboard
    }

    var showsFretboardInMainContent: Bool {
        mainContentMode == .fretboard
    }

    var hasValidFretboardPlacement: Bool {
        !(showsFretboardInTopContent && showsFretboardInMainContent)
    }
}
```

## 2. `SettingsPanelModel` 删除旧 `Page` section、旧 `top/main` action 和旧回写路径

- 修改前：settings model 里还保留了一整套 `Page section -> top/main rows -> setTopContent* / setMainContent* -> pageDisplayState -> inferPreferences` 的旧链路。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.rowIDs, SettingsChoiceRowID.sectionID, SettingsChoiceRowID.actionIDs
// 功能说明: 修改前 settings 面板仍暴露 Page section，并允许用户直接改 top/main 布局槽位。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case exercise
    case positionPrompt
    case accessories
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
        case .page:
            return [
                .choice(.topContent),
                .choice(.mainContent)
            ]
        // ... 其余 section 省略
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case exerciseMode
    case compositionPreset
    case layoutPreset
    // ... 其余 row 省略

    var sectionID: SettingsSectionID {
        switch self {
        case .topContent, .mainContent:
            return .page
        case .exerciseMode, .compositionPreset, .layoutPreset:
            return .exercise
        // ... 其余分支省略
        }
    }

    var actionIDs: [SettingsActionID] {
        switch self {
        case .topContent:
            return [
                .setTopContentStaff,
                .setTopContentTargetPrompt,
                .setTopContentFretboard
            ]
        case .mainContent:
            return [
                .setMainContentFretboard,
                .setMainContentNaturalNotes
            ]
        // ... 其余分支省略
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsActionID.isSelected(...), SettingsActionID.apply(to: PageDisplayState), SettingsActionID.apply(to stateContext:)
// 功能说明: 修改前 top/main action 会直接读取和写入 pageDisplayState，然后再反推新的 ExerciseLayoutPreferences。
enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setTopContentFretboard
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setExerciseModeSingle
    // ... 其余 action 省略

    func isSelected(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .setTopContentStaff:
            return stateContext.pageDisplayState.topContentMode == .staff
        case .setTopContentTargetPrompt:
            return stateContext.pageDisplayState.topContentMode == .targetPrompt
        case .setTopContentFretboard:
            return stateContext.pageDisplayState.topContentMode == .fretboard
        case .setMainContentFretboard:
            return stateContext.pageDisplayState.mainContentMode == .fretboard
        case .setMainContentNaturalNotes:
            return stateContext.pageDisplayState.mainContentMode == .naturalNoteStrip
        // ... 其余分支省略
        }
    }

    func apply(to displayState: inout PageDisplayState) {
        switch self {
        case .setTopContentStaff:
            displayState.setTopContentMode(.staff)
        case .setTopContentTargetPrompt:
            displayState.setTopContentMode(.targetPrompt)
        case .setTopContentFretboard:
            displayState.setTopContentMode(.fretboard)
        case .setMainContentFretboard:
            displayState.setMainContentMode(.fretboard)
        case .setMainContentNaturalNotes:
            displayState.setMainContentMode(.naturalNoteStrip)
        // ... 其余分支省略
        }
    }

    func apply(to stateContext: inout SettingsPanelStateContext) {
        apply(to: &stateContext.fretboardDisplayState)
        apply(to: &stateContext.staffDisplayState)
        apply(to: &stateContext.pageDisplayState)
        apply(to: &stateContext.exerciseLayoutPreferences)
        apply(to: &stateContext.trainerDisplayState)
        apply(to: &stateContext.pianoPanelState)
        if usesLegacyPagePlacementAction {
            stateContext.exerciseLayoutPreferences = LegacyPageLayoutAdapter
                .inferredPreferences(
                    pageDisplayState: stateContext.pageDisplayState,
                    trainerDisplayState: stateContext.trainerDisplayState,
                    pianoPanelState: stateContext.pianoPanelState
                )
        }
        LegacyPageLayoutAdapter.reconcile(&stateContext)
    }
}
```

- 修改后：`SettingsPanelModel` 里已经没有 `Page section`、`topContent/mainContent` row 和对应 action；状态应用只改 `fretboard/staff/layout/trainer/piano`，最后统一 `reconcile`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.rowIDs, SettingsChoiceRowID.sectionID, SettingsChoiceRowID.actionIDs
// 功能说明: 修改后 settings 面板不再暴露 Page section，Exercise section 只保留 mode / composition / layout 三个语义入口。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case exercise
    case positionPrompt
    case accessories
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    static var allCases: [SettingsSectionID] {
        [
            .exercise,
            .positionPrompt,
            .accessories,
            .fretboard,
            .staff,
            .piano,
            .debug
        ]
    }

    var rowIDs: [SettingsRowID] {
        switch self {
        case .exercise:
            return [
                .choice(.exerciseMode),
                .choice(.compositionPreset),
                .choice(.layoutPreset)
            ]
        // ... 其余 section 省略
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case exerciseMode
    case compositionPreset
    case layoutPreset
    case positionPromptFilterMode
    case accessoryPresentation
    case instrument
    case displayMode
    case stringThickness
    case labels
    case spelling
    case octave
    case clef
    case pianoMovementScope
    case pianoWhiteKeyStyle

    var sectionID: SettingsSectionID {
        switch self {
        case .exerciseMode, .compositionPreset, .layoutPreset:
            return .exercise
        case .positionPromptFilterMode:
            return .positionPrompt
        // ... 其余分支省略
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsActionID.isSelected(...), SettingsActionID.apply(to stateContext:)
// 功能说明: 修改后 SettingsActionID 只基于语义 layout preferences / trainer state 选中，并且不再写 pageDisplayState。
enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModePositionPrompt
    case setCompositionPresetStaffToFretboard
    case setCompositionPresetTargetPromptToFretboard
    case setCompositionPresetFretboardToNaturalNoteStrip
    case setCompositionPresetFretboardSelfAnswer
    case setLayoutPresetStacked
    case setLayoutPresetSideBySide
    case setLayoutPresetSingleSurface
    // ... 其余 action 省略

    func isSelected(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .setExerciseModeSingle:
            return stateContext.trainerDisplayState.exerciseMode == .single
        case .setCompositionPresetFretboardToNaturalNoteStrip:
            return stateContext.exerciseLayoutPreferences.compositionPreset
                == .fretboardToNaturalNoteStrip
        case .setLayoutPresetSideBySide:
            return stateContext.exerciseLayoutPreferences.layoutPreset
                == .sideBySide
        // ... 其余分支省略
        }
    }

    func apply(to stateContext: inout SettingsPanelStateContext) {
        apply(to: &stateContext.fretboardDisplayState)
        apply(to: &stateContext.staffDisplayState)
        apply(to: &stateContext.exerciseLayoutPreferences)
        apply(to: &stateContext.trainerDisplayState)
        apply(to: &stateContext.pianoPanelState)
        LegacyPageLayoutAdapter.reconcile(&stateContext)
    }
}
```

## 3. 导航快照与设置校验同步切到新主链

- 修改前：`SettingsNavigationSnapshotBuilder` 还在兼容 `SettingsSectionID.page`；`SettingsNavigationValidation` 里也继续从 “Page section 不该出现” 与显式 `pageDisplayState` 输入出发做校验。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: SettingsNavigationSnapshotBuilder.childPageSpecs(for:)
// 功能说明: 修改前 navigation snapshot builder 还保留了 `.page` 这个旧 section 分支。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    // ... 其余分支省略
    case .page, .layout, .debug:
        return nil
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: validateSplitSectionsProduceExpectedPageTree(), validatePositionPromptSectionVisibilityTracksExerciseMode(), validatePhase2ExerciseAndAccessoryRowsRemainStable()
// 功能说明: 修改前 validation 仍围绕 Page section 与 pageDisplayState 显式输入做断言。
if resolveSection(.page, in: panelModel) != nil {
    issues.append(issue(fixtureName, "default state 不应再保留 Page section。"))
}

let positionPromptStateContext = SettingsPanelStateContext(
    pageDisplayState: .positionPrompt,
    trainerDisplayState: .default
)

if resolveSection(.page, in: defaultPanelModel) != nil {
    issues.append(issue(fixtureName, "default state 不应再暴露 Page section。"))
}
```

- 修改后：snapshot builder 不再处理 `.page`；validation 改成直接校验新的 section 顺序和 `exerciseLayoutPreferences` 驱动下的 `positionPrompt` 显隐。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: SettingsNavigationSnapshotBuilder.childPageSpecs(for:)
// 功能说明: 修改后 navigation snapshot builder 已经不再认识 `.page` section。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    // ... 其余分支省略
    case .layout, .debug:
        return nil
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: validateSplitSectionsProduceExpectedPageTree(), validatePositionPromptSectionVisibilityTracksExerciseMode()
// 功能说明: 修改后 validation 直接断言新的 section 顺序，并以 ExerciseLayoutPreferences 作为 positionPrompt 默认态输入。
if panelModel.sections.map(\.id) != [
    .exercise,
    .positionPrompt,
    .accessories,
    .fretboard,
    .staff,
    .piano,
    .debug
] {
    issues.append(
        issue(
            fixtureName,
            "default state 的 section 顺序应保持 Exercise -> Position Prompt -> Accessories -> Fretboard -> Staff -> Piano -> Debug。"
        )
    )
}

let positionPromptStateContext = SettingsPanelStateContext(
    exerciseLayoutPreferences: .legacyPositionPrompt,
    trainerDisplayState: .default
)
```

## 4. iOS / macOS 控制器不再维护独立 `pageDisplayState`

- 修改前：控制器启动时先从 `LegacyPageLayoutAdapter.inferredPreferences(pageDisplayState: .default, ...)` 拿布局偏好，再用 `makeLegacyCompatiblePresentation(...)` 启动；控制器内部额外维护一个 `pageDisplayState`，并在 `synchronizeExerciseCompositionState(...)` 里把新的 scene 结果二次投影回 legacy page。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: initialExerciseLayoutPreferences, initialExercisePresentationState, pageDisplayState, debugStateSnapshot(), settingsPanelStateContext, synchronizeExerciseCompositionState(reason:)
// 功能说明: 修改前 iOS 控制器仍然维护独立 pageDisplayState，并在 scene 更新后回写 legacy page 投影。
private static let initialExerciseLayoutPreferences = LegacyPageLayoutAdapter
    .inferredPreferences(
        pageDisplayState: .default,
        trainerDisplayState: .default,
        pianoPanelState: initialPianoPanelState
    )
private static let initialExercisePresentationState = ExerciseCompositionPolicy
    .makeLegacyCompatiblePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: .default,
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: initialStaffDisplayState,
            pianoPanelState: initialPianoPanelState,
            layoutPreferences: initialExerciseLayoutPreferences
        )
    )

private var pageDisplayState = iOSViewController.initialExercisePresentationState
    .legacyPageDisplayState ?? .default

private func debugStateSnapshot() -> String {
    "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
    "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
    "pageTop=\(String(describing: pageDisplayState.topContentMode)) " +
    "pageMain=\(String(describing: pageDisplayState.mainContentMode)) " +
    "displayMode=\(String(describing: displayState.displayMode)) " +
    "showsFretboard=\(isShowingFretboard) " +
    "settingsPresented=\(isSettingsPresented)"
}

private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState,
        exerciseLayoutPreferences: exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: pianoPanelState
    )
}

private func synchronizeExerciseCompositionState(reason: String) {
    let semanticPresentationState = ExerciseCompositionPolicy.makePresentation(
        from: exerciseCompositionPolicyInput
    )
    exercisePresentationState = semanticPresentationState

    if exerciseLayoutPreferences
        != semanticPresentationState.resolvedLayoutPreferences {
        exerciseLayoutPreferences = semanticPresentationState
            .resolvedLayoutPreferences
    }

    var legacyCompatibleInput = exerciseCompositionPolicyInput
    legacyCompatibleInput.layoutPreferences = semanticPresentationState
        .resolvedLayoutPreferences
    let legacyCompatiblePresentationState = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(from: legacyCompatibleInput)

    if let legacyPageDisplayState = legacyCompatiblePresentationState
        .legacyPageDisplayState,
       pageDisplayState != legacyPageDisplayState {
        pageDisplayState = legacyPageDisplayState
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: initialExerciseLayoutPreferences, initialExercisePresentationState, debugStateSnapshot(), settingsPanelStateContext, synchronizeExerciseCompositionState(reason:)
// 功能说明: 修改后 iOS 控制器直接以 ExerciseLayoutPreferences / ExercisePresentationState 为主链，不再维护 pageDisplayState。
private static let initialExerciseLayoutPreferences = ExerciseSceneValidator
    .normalizedPreferences(
        .legacyPositionPrompt,
        trainerDisplayState: .default
    )
private static let initialExercisePresentationState = ExerciseCompositionPolicy
    .makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: .default,
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: initialStaffDisplayState,
            pianoPanelState: initialPianoPanelState,
            layoutPreferences: initialExerciseLayoutPreferences
        )
    )

private func debugStateSnapshot() -> String {
    "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
    "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
    "composition=\(String(describing: exerciseLayoutPreferences.compositionPreset)) " +
    "layout=\(String(describing: exerciseLayoutPreferences.layoutPreset)) " +
    "displayMode=\(String(describing: displayState.displayMode)) " +
    "showsFretboard=\(isShowingFretboard) " +
    "settingsPresented=\(isSettingsPresented)"
}

private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        exerciseLayoutPreferences: exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: pianoPanelState
    )
}

private func synchronizeExerciseCompositionState(reason: String) {
    let semanticPresentationState = ExerciseCompositionPolicy.makePresentation(
        from: exerciseCompositionPolicyInput
    )
    exercisePresentationState = semanticPresentationState

    if exerciseLayoutPreferences
        != semanticPresentationState.resolvedLayoutPreferences {
        exerciseLayoutPreferences = semanticPresentationState
            .resolvedLayoutPreferences
    }
}
```

- `macOSViewController` 做了同构 cutover：同样移除控制器级 `pageDisplayState`，把启动与同步都改成直接走 `ExerciseCompositionPolicy.makePresentation(...)`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: initialExerciseLayoutPreferences, initialExercisePresentationState, pageDisplayState, debugStateSnapshot(), settingsPanelStateContext, synchronizeExerciseCompositionState(reason:)
// 功能说明: 修改前 macOS 控制器与 iOS 一样，仍通过 pageDisplayState 驱动 legacy 兼容投影。
private static let initialExerciseLayoutPreferences = LegacyPageLayoutAdapter
    .inferredPreferences(
        pageDisplayState: .default,
        trainerDisplayState: .default,
        pianoPanelState: initialPianoPanelState
    )
private static let initialExercisePresentationState = ExerciseCompositionPolicy
    .makeLegacyCompatiblePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: .default,
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: initialStaffDisplayState,
            pianoPanelState: initialPianoPanelState,
            layoutPreferences: initialExerciseLayoutPreferences
        )
    )

private var pageDisplayState = macOSViewController.initialExercisePresentationState
    .legacyPageDisplayState ?? .default

private func debugStateSnapshot() -> String {
    "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
    "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
    "pageTop=\(String(describing: pageDisplayState.topContentMode)) " +
    "pageMain=\(String(describing: pageDisplayState.mainContentMode)) " +
    "displayMode=\(String(describing: displayState.displayMode)) " +
    "showsFretboard=\(isShowingFretboard) " +
    "settingsPresented=\(isSettingsPresented)"
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: initialExerciseLayoutPreferences, initialExercisePresentationState, debugStateSnapshot(), settingsPanelStateContext, synchronizeExerciseCompositionState(reason:)
// 功能说明: 修改后 macOS 控制器与 iOS 对齐，以 scene/presentation 为主链，不再回写 page bridge。
private static let initialExerciseLayoutPreferences = ExerciseSceneValidator
    .normalizedPreferences(
        .legacyPositionPrompt,
        trainerDisplayState: .default
    )
private static let initialExercisePresentationState = ExerciseCompositionPolicy
    .makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: .default,
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: initialStaffDisplayState,
            pianoPanelState: initialPianoPanelState,
            layoutPreferences: initialExerciseLayoutPreferences
        )
    )

private func debugStateSnapshot() -> String {
    "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
    "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
    "composition=\(String(describing: exerciseLayoutPreferences.compositionPreset)) " +
    "layout=\(String(describing: exerciseLayoutPreferences.layoutPreset)) " +
    "displayMode=\(String(describing: displayState.displayMode)) " +
    "showsFretboard=\(isShowingFretboard) " +
    "settingsPresented=\(isSettingsPresented)"
}
```

## 5. `ButtonPanelModel` 不再注入伪造的 legacy `pageDisplayState`

- 修改前：按钮面板为了复用 `SettingsActionID`，还会手动构造一个带 `pageDisplayState: .default` 的 `SettingsPanelStateContext`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名: ButtonPanelActionID.isSelected(in:), ButtonPanelActionID.isEnabled(in:)
// 功能说明: 修改前 ButtonPanelModel 还会手动注入一个默认的 legacy pageDisplayState。
func isSelected(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isSelected(
        in: SettingsPanelStateContext(
            fretboardDisplayState: displayState,
            staffDisplayState: .default,
            pageDisplayState: .default
        )
    )
}

func isEnabled(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isEnabled(
        in: SettingsPanelStateContext(
            fretboardDisplayState: displayState,
            staffDisplayState: .default,
            pageDisplayState: .default
        )
    )
}
```

- 修改后：按钮面板只传 `fretboardDisplayState` 与默认 `staffDisplayState`，其余布局语义由 `SettingsPanelStateContext` 自己补齐。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名: ButtonPanelActionID.isSelected(in:), ButtonPanelActionID.isEnabled(in:)
// 功能说明: 修改后 ButtonPanelModel 不再手工注入 legacy page bridge。
func isSelected(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isSelected(
        in: SettingsPanelStateContext(
            fretboardDisplayState: displayState,
            staffDisplayState: .default
        )
    )
}

func isEnabled(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isEnabled(
        in: SettingsPanelStateContext(
            fretboardDisplayState: displayState,
            staffDisplayState: .default
        )
    )
}
```

## 6. `ExerciseCompositionValidation` 改成验证 bridge 投影，而不是旧的 mutable page 写法

- 修改前：validation 还在校验 `PageDisplayState.setTopContentMode(...)` / `setMainContentMode(...)` 这种旧入口，同时构造 `SettingsPanelStateContext` 时仍显式传入 `pageDisplayState`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validatePageStateNormalizationPreservesSingleFretboardSlot(), validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible(), validateSharedLayoutPreferencesCoexistWithLegacyPageState()
// 功能说明: 修改前 validation 仍围绕 PageDisplayState 的旧 mutating API 和显式 page 输入做断言。
var delegatedTopPrioritizedState = PageDisplayState.default
delegatedTopPrioritizedState.setTopContentMode(.fretboard)
if delegatedTopPrioritizedState != topPrioritizedState {
    issues.append(
        issue(
            fixtureName,
            "PageDisplayState.setTopContentMode 应委托 shared validator 的 top 优先归一化规则。"
        )
    )
}

var delegatedMainPrioritizedState = PageDisplayState.positionPrompt
delegatedMainPrioritizedState.setMainContentMode(.fretboard)
if delegatedMainPrioritizedState != mainPrioritizedState {
    issues.append(
        issue(
            fixtureName,
            "PageDisplayState.setMainContentMode 应委托 shared validator 的 main 优先归一化规则。"
        )
    )
}

let horizontalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
    from: SettingsPanelStateContext(
        fretboardDisplayState: horizontalFretboardDisplayState,
        staffDisplayState: defaultStateContext.staffDisplayState,
        pageDisplayState: defaultStateContext.pageDisplayState,
        trainerDisplayState: defaultStateContext.trainerDisplayState,
        pianoPanelState: defaultStateContext.pianoPanelState
    )
)

let stateContext = SettingsPanelStateContext(
    pageDisplayState: .positionPrompt,
    exerciseLayoutPreferences: customPreferences,
    trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt)
)
```

- 修改后：validation 改成校验 `PageDisplayState` 初始化归一化，以及从 `ExerciseLayoutPreferences` 投影 legacy page bridge 的行为。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validatePageStateNormalizationPreservesSingleFretboardSlot(), validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible(), validateSharedLayoutPreferencesCoexistWithLegacyPageState()
// 功能说明: 修改后 validation 断言的是 PageDisplayState 的初始化归一化和 ExerciseLayoutPreferences -> legacy page bridge 投影。
let initNormalizedState = PageDisplayState(
    topContentMode: .fretboard,
    mainContentMode: .fretboard
)
if initNormalizedState != topPrioritizedState {
    issues.append(
        issue(
            fixtureName,
            "PageDisplayState 初始化仍应保持 top 优先的 legacy 归一化结果。"
        )
    )
}

let horizontalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
    from: SettingsPanelStateContext(
        fretboardDisplayState: horizontalFretboardDisplayState,
        staffDisplayState: defaultStateContext.staffDisplayState,
        exerciseLayoutPreferences: defaultStateContext
            .exerciseLayoutPreferences,
        trainerDisplayState: defaultStateContext.trainerDisplayState,
        pianoPanelState: defaultStateContext.pianoPanelState
    )
)

let stateContext = SettingsPanelStateContext(
    exerciseLayoutPreferences: customPreferences,
    trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt)
)
if stateContext.pageDisplayState != .positionPrompt {
    issues.append(
        issue(
            fixtureName,
            "设置 context 应继续从 ExerciseLayoutPreferences 投影 legacy page bridge。"
        )
    )
}
```

## 验证结果

- `ReadLints`
- 检查范围：`PageDisplayState.swift`、`SettingsPanelStateContext.swift`、`SettingsPanelModel.swift`、`ButtonPanelModel.swift`、`SettingsNavigationSnapshotBuilder.swift`、`SettingsNavigationValidation.swift`、`ExerciseCompositionValidation.swift`、`iOSViewController.swift`、`macOSViewController.swift`
- 结果：`No linter errors found.`

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=macOS' build`
- 结果：`BUILD SUCCEEDED`

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=iOS Simulator,OS=26.1,name=iPhone 17' build`
- 结果：`BUILD SUCCEEDED`

- 构建备注：
- 两个平台构建都通过。
- 本次记录只新增了这份 `commit_records` markdown，没有提交。

## 过程中修正

- 在阶段 6 的实现过程中，`SettingsPanelStateContext.resolvedLayoutPreferences(...)` 的默认回退分支最初会丢掉 `pianoPanelState.isVisible`。
- 最终版已在回退逻辑里补上 `fallbackPreferences.isPianoAccessoryVisible = pianoPanelState.isVisible`，保证当调用方只传 `pianoPanelState` 时，legacy bridge 和 settings snapshot 仍能正确回显钢琴显隐状态。

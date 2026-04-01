# 20260401_200432_phase3_shared_composition_policy_and_validator

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_200432`
- 记录范围：`场景树迁移` 计划的阶段 3；把布局语义、legacy page 归一化和 scene 合法性校验从平台控制器收口到 shared policy / validator
- 修改性质：新增 `ExerciseCompositionPolicy` 与 `ExerciseSceneValidator`；扩展 `ExercisePresentationState`；让 `LegacyPageLayoutAdapter` / `PageDisplayState` / iOS / macOS 控制器统一消费 shared 语义真相；补齐阶段 3 的 validation 夹具
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 修改前

### 1. shared 层还没有统一的 composition policy / scene validator

- 修改前，shared 层只有 `ExerciseScene` / `ExercisePresentationState` 这些基础契约，但没有单一入口来统一输出 `scene + surfaceStates + legacy page projection`。
- 同时也没有 shared validator 来集中校验 `scene` 合法性、layout preset 归一化和旧 `PageDisplayState` 的唯一 `fretboard` 约束。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: N/A（修改前文件不存在）
// 功能说明: 修改前 shared 层没有 composition policy 来统一决定 trainer mode、layout preset 与 legacy page 的投影关系。
// （文件不存在）
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: N/A（修改前文件不存在）
// 功能说明: 修改前 shared 层没有 validator 来校验 scene 合法性，也没有统一的 legacy page 归一化入口。
// （文件不存在）
```

### 2. `ExercisePresentationState` 只承载基础 surface role 投影

- 修改前 `ExerciseSurfaceState` 只有 `visible / prompt / answer` 三个维度。
- `ExercisePresentationState` 也只保存 `scene` 和 `surfaceStates`，没有记录归一化后的 layout 偏好，也没有保留 legacy page 的投影结果。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseSurfaceState.init(...), ExercisePresentationState.init(...)
// 功能说明: 修改前 presentation state 只承载 scene 和基础 surface state，没有 interaction 语义，也没有 resolved layout / legacy projection。
struct ExerciseSurfaceState: Equatable, Sendable {
    var isVisible: Bool
    var isPromptActive: Bool
    var isAnswerEnabled: Bool

    static let promptOnly = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: true,
        isAnswerEnabled: false
    )
    static let answerOnly = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: false,
        isAnswerEnabled: true
    )
    static let promptAndAnswer = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: true,
        isAnswerEnabled: true
    )

    init(
        isVisible: Bool = true,
        isPromptActive: Bool = false,
        isAnswerEnabled: Bool = false
    ) {
        self.isVisible = isVisible
        self.isPromptActive = isPromptActive
        self.isAnswerEnabled = isAnswerEnabled
    }
}

struct ExercisePresentationState: Equatable, Sendable {
    var scene: ExerciseScene
    private(set) var surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState]

    init(
        scene: ExerciseScene,
        surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState] = [:]
    ) {
        self.scene = scene
        self.surfaceStates = surfaceStates
    }
}
```

### 3. `LegacyPageLayoutAdapter` 与 `PageDisplayState` 各自维护归一化规则

- 修改前 `LegacyPageLayoutAdapter` 自己维护一套 `normalizedPreferences()` / `projectedPageDisplayState()` / `is*Supported()` 逻辑。
- `PageDisplayState` 也内建了自己的 `normalizeFretboardPlacement()`，导致“layout 合法性”在多个位置重复维护。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名: normalizedPreferences(...), projectedPageDisplayState(...), isCompositionPresetSupported(...), isLayoutPresetSupported(...)
// 功能说明: 修改前 legacy adapter 自己维护 preset 归一化和 legacy page 投影规则，还没有委托 shared policy。
static func normalizedPreferences(
    _ preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> ExerciseLayoutPreferences {
    var normalized = preferences

    switch trainerDisplayState.exerciseMode {
    case .single, .sequence:
        if !isCompositionPresetSupported(
            normalized.compositionPreset,
            for: trainerDisplayState.exerciseMode
        ) {
            normalized.compositionPreset = .staffToFretboard
        }
        normalized.isNaturalNoteStripVisible = false
    case .positionPrompt:
        normalized.compositionPreset = .fretboardToNaturalNoteStrip
        normalized.isNaturalNoteStripVisible = true
    }

    if !isLayoutPresetSupported(normalized.layoutPreset) {
        normalized.layoutPreset = .stacked
    }
    if !isAccessoryPresentationSupported(
        normalized.accessoryPresentation
    ) {
        normalized.accessoryPresentation = .docked
    }

    return normalized
}

static func projectedPageDisplayState(
    from preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> PageDisplayState {
    let normalizedPreferences = normalizedPreferences(
        preferences,
        trainerDisplayState: trainerDisplayState
    )

    switch trainerDisplayState.exerciseMode {
    case .positionPrompt:
        return .positionPrompt
    case .single, .sequence:
        switch normalizedPreferences.compositionPreset {
        case .targetPromptToFretboard:
            return PageDisplayState(
                topContentMode: .targetPrompt,
                mainContentMode: .fretboard
            )
        case .staffToFretboard,
             .fretboardToNaturalNoteStrip,
             .fretboardSelfAnswer:
            return .default
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数名: init(...), normalizeFretboardPlacement(prioritizingTopContent:)
// 功能说明: 修改前 PageDisplayState 自己维护唯一 fretboard placement 规则，没有委托 shared validator。
struct PageDisplayState: Equatable, Sendable {
    // ... 其他未改动代码省略

    init(
        topContentMode: PageTopContentMode = .staff,
        mainContentMode: PageMainContentMode = .fretboard
    ) {
        self.topContentMode = topContentMode
        self.mainContentMode = mainContentMode
        normalizeFretboardPlacement(prioritizingTopContent: true)
    }

    private mutating func normalizeFretboardPlacement(
        prioritizingTopContent: Bool
    ) {
        guard !hasValidFretboardPlacement else {
            return
        }

        if prioritizingTopContent {
            mainContentMode = .naturalNoteStrip
        } else {
            topContentMode = .staff
        }
    }
}
```

### 4. iOS 控制器仍直接决定页面语义和 settings 归一化

- 修改前 `iOSViewController` 里的 `synchronizeSingleTrainerPresentation()` / `synchronizePositionPromptPresentation()` / `synchronizeQuarterNoteSequencePresentation()` 直接改 `pageDisplayState`。
- `handleSettingsPanelEvent()` 也先调用 `normalizeSettingsPanelStateContextForTrainerMode()`，由控制器自己改写下一版 `stateContext`。
- `naturalNoteStripView` 的交互态只看 `trainerDisplayState` 和 overlay phase，还不会读取 shared surface state。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: synchronizeSingleTrainerPresentation(reason:), synchronizePositionPromptPresentation(reason:), synchronizeQuarterNoteSequencePresentation(reason:), updateNaturalNoteStripInteractionState()
// 功能说明: 修改前 trainer mode -> page 语义的映射仍硬编码在 iOS 控制器内部。
private func synchronizeSingleTrainerPresentation(reason: String) {
    // ... 其他未改动代码省略

    if pageDisplayState == .positionPrompt {
        pageDisplayState.setMainContentMode(.fretboard)
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    // ... 其他未改动代码省略

    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetPositionPromptInteractionState()
    if pageDisplayState.mainContentMode != .fretboard {
        pageDisplayState.setMainContentMode(.fretboard)
    }

    // ... 其他未改动代码省略

    applyQuarterNoteSequenceProjection(generatedSequence, reason: reason)
}

private func updateNaturalNoteStripInteractionState() {
    guard isViewLoaded else {
        return
    }

    if trainerDisplayState.isPositionPromptMode {
        naturalNoteStripView.isUserInteractionEnabled = currentPositionPromptOverlayPhase == .neutralWhite
    } else {
        naturalNoteStripView.isUserInteractionEnabled = true
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: settingsPanelStateContext, normalizeSettingsPanelStateContextForTrainerMode(_:), handleSettingsPanelEvent(_:)
// 功能说明: 修改前 settings 事件写回后仍由控制器自己归一化 trainer mode 与 legacy page state。
private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: pianoPanelState
    )
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    switch stateContext.trainerDisplayState.exerciseMode {
    case .single:
        if stateContext.pageDisplayState == .positionPrompt {
            stateContext.pageDisplayState.setMainContentMode(.fretboard)
        }
    case .sequence:
        stateContext.pageDisplayState.setMainContentMode(.fretboard)

        if let currentGeneratedQuarterNoteSequence {
            stateContext.staffDisplayState.apply(
                generatedSequence: currentGeneratedQuarterNoteSequence,
                sequencePresentation: currentQuarterNoteSequenceStaffPresentation(
                    for: currentGeneratedQuarterNoteSequence
                )
            )
        }
    case .positionPrompt:
        stateContext.pageDisplayState = .positionPrompt
    }
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    let nextRequestedStaffDisplayState = nextStateContext.staffDisplayState
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextPageDisplayState = nextStateContext.pageDisplayState
    let nextTrainerDisplayState = nextStateContext.trainerDisplayState
    let nextPianoPanelState = nextStateContext.pianoPanelState

    // ... 其他未改动代码省略
}
```

### 5. macOS 控制器也仍使用相同的硬编码页面语义

- 修改前 `macOSViewController` 和 iOS 基本同构：平台控制器自己维护 `pageDisplayState` 的切换，以及 settings 写回后的 trainer-mode 归一化。
- `naturalNoteStripView.areButtonsEnabled` 也只依赖 mode/phase，不会读取 shared `ExercisePresentationState`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizeSingleTrainerPresentation(reason:), synchronizePositionPromptPresentation(reason:), synchronizeQuarterNoteSequencePresentation(reason:), updateNaturalNoteStripInteractionState()
// 功能说明: 修改前 macOS 控制器与 iOS 一样，直接在平台层决定 page 语义与 natural strip 交互态。
private func synchronizeSingleTrainerPresentation(reason: String) {
    // ... 其他未改动代码省略

    if pageDisplayState == .positionPrompt {
        pageDisplayState.setMainContentMode(.fretboard)
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    // ... 其他未改动代码省略

    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}

private func updateNaturalNoteStripInteractionState() {
    guard isViewLoaded else {
        return
    }

    if trainerDisplayState.isPositionPromptMode {
        naturalNoteStripView.areButtonsEnabled = currentPositionPromptOverlayPhase == .neutralWhite
    } else {
        naturalNoteStripView.areButtonsEnabled = true
    }
}
```

### 6. validation 还没有阶段 3 的 policy / validator 夹具

- 修改前 `ExerciseCompositionValidation` 只覆盖阶段 0~2 的共享契约，不会验证 `ExerciseCompositionPolicy` 的 `sideBySide` / `singleSurface` 投影，也不会验证 legacy fallback 和 duplicate logical surface。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:), validatePageStateNormalizationPreservesSingleFretboardSlot()
// 功能说明: 修改前 validation 还没有阶段 3 的 policy / validator 夹具，手工清单里也仍沿用旧的 `Piano Visible` 文案。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "shared_layout_preferences_coexist_with_legacy_page_state",
            validate: validateSharedLayoutPreferencesCoexistWithLegacyPageState
        ),
        ExerciseCompositionValidationFixture(
            name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
            validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
        )
    ]
}

static func manualChecklist(
    for platform: ExerciseCompositionValidationPlatform
) -> [String] {
    var checklist = [
        "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
        "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
        "确认 `Piano Visible` 默认关闭；打开后只追加钢琴区域，关闭后主 prompt/answer 组合不发生漂移。"
    ]

    // ... 其他未改动代码省略
    return checklist
}

static func validatePageStateNormalizationPreservesSingleFretboardSlot()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "page_state_normalization_preserves_single_fretboard_slot"
    var issues: [ExerciseCompositionValidationIssue] = []

    var topPrioritizedState = PageDisplayState.default
    topPrioritizedState.setTopContentMode(.fretboard)

    var mainPrioritizedState = PageDisplayState.positionPrompt
    mainPrioritizedState.setMainContentMode(.fretboard)

    // ... 其他未改动代码省略

    return issues
}
```

## 修改后

### 1. 新增 `ExerciseCompositionPolicy`，统一输出 scene、surface state 与 legacy page 投影

- 新增 `ExerciseCompositionPolicyInput`
- 新增 `makePresentation()`，把 trainer mode、layout preset、piano accessory 等输入统一投影为 `ExercisePresentationState`
- 新增 `makeLegacyCompatiblePresentation()` / `legacyCompatiblePreferences()`，让阶段 3 能表达更丰富语义，同时继续兼容阶段 4 之前的旧 renderer

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: makePresentation(from:), makeLegacyCompatiblePresentation(from:), legacyCompatiblePreferences(from:)
// 功能说明: 新增 shared composition policy，统一决定 scene、surface state、resolved layout 和 legacy page 投影。
struct ExerciseCompositionPolicyInput: Equatable, Sendable {
    var trainerDisplayState: TrainerDisplayState
    var fretboardTrainerState: FretboardNaturalNoteTrainerState
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pianoPanelState: PianoPanelState
    var layoutPreferences: ExerciseLayoutPreferences
}

enum ExerciseCompositionPolicy {
    static func makePresentation(
        from input: ExerciseCompositionPolicyInput
    ) -> ExercisePresentationState {
        let resolvedLayoutPreferences = ExerciseSceneValidator
            .normalizedPreferences(
                input.layoutPreferences,
                trainerDisplayState: input.trainerDisplayState
            )
        let scene = makeScene(
            preferences: resolvedLayoutPreferences
        )

        return ExercisePresentationState(
            scene: scene,
            surfaceStates: makeSurfaceStates(
                scene: scene,
                input: input,
                resolvedLayoutPreferences: resolvedLayoutPreferences
            ),
            resolvedLayoutPreferences: resolvedLayoutPreferences,
            legacyPageDisplayState: ExerciseSceneValidator
                .legacyPageDisplayState(for: scene)
        )
    }

    static func makeLegacyCompatiblePresentation(
        from input: ExerciseCompositionPolicyInput
    ) -> ExercisePresentationState {
        var legacyCompatibleInput = input
        legacyCompatibleInput.layoutPreferences = legacyCompatiblePreferences(
            from: input
        )
        return makePresentation(from: legacyCompatibleInput)
    }

    static func legacyCompatiblePreferences(
        from input: ExerciseCompositionPolicyInput
    ) -> ExerciseLayoutPreferences {
        let resolvedPreferences = ExerciseSceneValidator.normalizedPreferences(
            input.layoutPreferences,
            trainerDisplayState: input.trainerDisplayState
        )
        var legacyCompatiblePreferences = resolvedPreferences

        legacyCompatiblePreferences.layoutPreset = .stacked
        legacyCompatiblePreferences.accessoryPresentation = .docked
        legacyCompatiblePreferences.isAccessoryExpanded = true

        switch input.trainerDisplayState.exerciseMode {
        case .single, .sequence:
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

        // ... 其他未改动代码省略
        return legacyCompatiblePreferences
    }
}
```

### 2. 新增 `ExerciseSceneValidator`，把 scene 合法性、layout 归一化和 legacy page 投影收口到 shared

- 新增 `validate(_:)`，检查 duplicate logical surface / 缺少 prompt / 缺少 answer
- 新增 `normalizedPreferences(...)`，统一 trainer mode 与 layout preset 的语义约束
- 新增 `normalizedLegacyPageDisplayState(...)` 和 `legacyPageDisplayState(for:)`，把旧 page 规则从零散 helper 迁回 shared

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: validate(_:), normalizedPreferences(_:trainerDisplayState:), normalizedLegacyPageDisplayState(from:prioritizingTopContent:), legacyPageDisplayState(for:)
// 功能说明: 新增 shared validator，统一 scene 合法性、preset 归一化和 legacy page 投影。
enum ExerciseSceneValidationIssue: Equatable, Sendable {
    case duplicateSurfaceID(ExerciseSurfaceID)
    case missingPromptSurface
    case missingAnswerSurface
}

enum ExerciseSceneValidator {
    static func validate(
        _ scene: ExerciseScene
    ) -> [ExerciseSceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [ExerciseSceneValidationIssue] = []

        for surfaceID in ExerciseSurfaceID.allCases {
            let duplicateCount = surfaceNodes.filter { $0.id == surfaceID }.count
            if duplicateCount > 1 {
                issues.append(.duplicateSurfaceID(surfaceID))
            }
        }

        if !surfaceNodes.contains(where: \.isPromptSurface) {
            issues.append(.missingPromptSurface)
        }
        if !surfaceNodes.contains(where: \.isAnswerSurface) {
            issues.append(.missingAnswerSurface)
        }

        return issues
    }

    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        var normalized = preferences

        switch trainerDisplayState.exerciseMode {
        case .single, .sequence:
            if !isCompositionPresetSemanticallySupported(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            ) {
                normalized.compositionPreset = .staffToFretboard
            }
        case .positionPrompt:
            if !isCompositionPresetSemanticallySupported(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            ) {
                normalized.compositionPreset = .fretboardToNaturalNoteStrip
            }
        }

        switch normalized.compositionPreset {
        case .staffToFretboard,
             .targetPromptToFretboard,
             .fretboardToNaturalNoteStrip:
            if !isMultiSurfaceLayoutSemanticallySupported(
                normalized.layoutPreset
            ) {
                normalized.layoutPreset = .stacked
            }
        case .fretboardSelfAnswer:
            normalized.layoutPreset = .singleSurface
        }

        normalized.isNaturalNoteStripVisible = normalized.compositionPreset
            == .fretboardToNaturalNoteStrip
        return normalized
    }

    static func normalizedLegacyPageDisplayState(
        from pageDisplayState: PageDisplayState,
        prioritizingTopContent: Bool
    ) -> PageDisplayState {
        var normalized = pageDisplayState

        let showsFretboardInTopContent = normalized.topContentMode == .fretboard
        let showsFretboardInMainContent = normalized.mainContentMode == .fretboard
        guard showsFretboardInTopContent && showsFretboardInMainContent else {
            return normalized
        }

        if prioritizingTopContent {
            normalized.mainContentMode = .naturalNoteStrip
        } else {
            normalized.topContentMode = .staff
        }

        return normalized
    }

    // ... 其他未改动代码省略
}
```

### 3. `ExercisePresentationState` 补齐 interaction、resolved layout 与 legacy projection

- `ExerciseSurfaceState` 新增 `isInteractionEnabled`
- 新增 `hidden` / `auxiliaryOnly`
- `ExercisePresentationState` 新增 `resolvedLayoutPreferences` 与 `legacyPageDisplayState`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseSurfaceState.init(...), ExercisePresentationState.init(...)
// 功能说明: 修改后 presentation state 能同时承载 scene、interaction state、resolved layout 和 legacy page projection。
struct ExerciseSurfaceState: Equatable, Sendable {
    var isVisible: Bool
    var isPromptActive: Bool
    var isAnswerEnabled: Bool
    var isInteractionEnabled: Bool

    static let hidden = ExerciseSurfaceState(
        isVisible: false,
        isPromptActive: false,
        isAnswerEnabled: false,
        isInteractionEnabled: false
    )
    static let promptOnly = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: true,
        isAnswerEnabled: false,
        isInteractionEnabled: false
    )
    static let answerOnly = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: false,
        isAnswerEnabled: true,
        isInteractionEnabled: true
    )
    static let promptAndAnswer = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: true,
        isAnswerEnabled: true,
        isInteractionEnabled: true
    )
    static let auxiliaryOnly = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: false,
        isAnswerEnabled: false,
        isInteractionEnabled: true
    )

    init(
        surface: ExerciseSurfaceNode,
        isVisible: Bool = true
    ) {
        self.init(
            isVisible: isVisible,
            isPromptActive: surface.isPromptSurface,
            isAnswerEnabled: surface.isAnswerSurface,
            isInteractionEnabled: surface.isAnswerSurface
                || surface.isAuxiliarySurface
        )
    }
}

struct ExercisePresentationState: Equatable, Sendable {
    var scene: ExerciseScene
    var resolvedLayoutPreferences: ExerciseLayoutPreferences
    var legacyPageDisplayState: PageDisplayState?
    private(set) var surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState]

    init(
        scene: ExerciseScene,
        surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState] = [:],
        resolvedLayoutPreferences: ExerciseLayoutPreferences = .default,
        legacyPageDisplayState: PageDisplayState? = nil
    ) {
        self.scene = scene
        self.resolvedLayoutPreferences = resolvedLayoutPreferences
        self.legacyPageDisplayState = legacyPageDisplayState
        self.surfaceStates = surfaceStates
    }
}
```

### 4. `LegacyPageLayoutAdapter` 与 `PageDisplayState` 改为委托 shared policy / validator

- `LegacyPageLayoutAdapter.normalizedPreferences()` 现在直接走 `ExerciseCompositionPolicy.legacyCompatiblePreferences(...)`
- `projectedPageDisplayState()` 改为先从 policy 生成 `ExercisePresentationState`，再读 `legacyPageDisplayState`
- `PageDisplayState` 的唯一 `fretboard` 约束改为委托 `ExerciseSceneValidator.normalizedLegacyPageDisplayState(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名: normalizedPreferences(...), projectedPageDisplayState(...), isCompositionPresetSupported(...), isLayoutPresetSupported(...), policyInput(...)
// 功能说明: 修改后 legacy adapter 不再自维护语义判断，而是转调 shared policy / validator。
static func normalizedPreferences(
    _ preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> ExerciseLayoutPreferences {
    ExerciseCompositionPolicy.legacyCompatiblePreferences(
        from: policyInput(
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: .init(),
            layoutPreferences: preferences
        )
    )
}

static func projectedPageDisplayState(
    from preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> PageDisplayState {
    let presentationState = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: policyInput(
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: .init(),
                layoutPreferences: preferences
            )
        )

    if let legacyPageDisplayState = presentationState.legacyPageDisplayState {
        return legacyPageDisplayState
    }

    switch trainerDisplayState.exerciseMode {
    case .single, .sequence:
        return .default
    case .positionPrompt:
        return .positionPrompt
    }
}

private static func policyInput(
    trainerDisplayState: TrainerDisplayState,
    pianoPanelState: PianoPanelState,
    layoutPreferences: ExerciseLayoutPreferences
) -> ExerciseCompositionPolicyInput {
    ExerciseCompositionPolicyInput(
        trainerDisplayState: trainerDisplayState,
        fretboardTrainerState: .init(),
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pianoPanelState: pianoPanelState,
        layoutPreferences: layoutPreferences
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数名: init(...), normalizeFretboardPlacement(prioritizingTopContent:)
// 功能说明: 修改后 legacy page 自身只保留数据结构，唯一 fretboard placement 规则委托 shared validator。
struct PageDisplayState: Equatable, Sendable {
    // ... 其他未改动代码省略

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

### 5. iOS 控制器改为消费 shared composition policy 输出

- 新增 `exerciseLayoutPreferences` / `exercisePresentationState`
- 新增 `exerciseCompositionPolicyInput` 与 `synchronizeExerciseCompositionState(reason:)`
- `synchronize*Presentation()` 先维护 trainer/session，再调用 shared policy 同步页面语义
- `updateNaturalNoteStripInteractionState()` 开始读取 `exercisePresentationState.surfaceState(for: .naturalNoteStrip)`
- `handleSettingsPanelEvent()` 不再先改 `pageDisplayState`，而是把 layout/trainer/display state 写回后交给 policy 统一 recompose

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: exerciseLayoutPreferences, exercisePresentationState, settingsPanelStateContext, exerciseCompositionPolicyInput, synchronizeExerciseCompositionState(reason:)
// 功能说明: 修改后 iOS 控制器开始显式持有 exercise presentation 真相，并通过 shared policy 回投影 legacy page。
private var pageDisplayState = iOSViewController.initialExercisePresentationState
    .legacyPageDisplayState ?? .default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
        handleQuarterNoteSequencePageDisplayStateTransition(
            from: oldValue,
            to: pageDisplayState
        )
    }
}
private var exerciseLayoutPreferences = iOSViewController
    .initialExerciseLayoutPreferences {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}
private var exercisePresentationState = iOSViewController
    .initialExercisePresentationState

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

private var exerciseCompositionPolicyInput: ExerciseCompositionPolicyInput {
    ExerciseCompositionPolicyInput(
        trainerDisplayState: trainerDisplayState,
        fretboardTrainerState: fretboardTrainerState,
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pianoPanelState: pianoPanelState,
        layoutPreferences: exerciseLayoutPreferences
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
// 函数名: synchronizeSingleTrainerPresentation(reason:), synchronizePositionPromptPresentation(reason:), synchronizeQuarterNoteSequencePresentation(reason:), updateNaturalNoteStripInteractionState(), handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS 控制器不再直接拍板 page 语义，而是在 trainer/session 更新后统一走 shared policy。
private func synchronizeSingleTrainerPresentation(reason: String) {
    // ... 其他未改动代码省略

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    synchronizeExerciseCompositionState(reason: reason)
    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    // ... 其他未改动代码省略

    synchronizeExerciseCompositionState(reason: reason)
    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetPositionPromptInteractionState()

    // ... 其他未改动代码省略

    synchronizeExerciseCompositionState(reason: reason)
    applyQuarterNoteSequenceProjection(generatedSequence, reason: reason)
}

private func updateNaturalNoteStripInteractionState() {
    guard isViewLoaded else {
        return
    }

    let isInteractionEnabled = exercisePresentationState.surfaceState(
        for: .naturalNoteStrip
    )?.isInteractionEnabled ?? false

    if trainerDisplayState.isPositionPromptMode {
        naturalNoteStripView.isUserInteractionEnabled = isInteractionEnabled
            && currentPositionPromptOverlayPhase == .neutralWhite
    } else {
        naturalNoteStripView.isUserInteractionEnabled = isInteractionEnabled
    }
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    let nextRequestedStaffDisplayState = nextStateContext.staffDisplayState

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextExerciseLayoutPreferences = nextStateContext
        .exerciseLayoutPreferences
    let nextTrainerDisplayState = nextStateContext.trainerDisplayState
    let nextPianoPanelState = nextStateContext.pianoPanelState

    // ... 其他未改动代码省略

    if didChangeTrainer {
        synchronizeTrainerPresentationState(reason: trainerSyncReason)
    } else if didChangeExerciseLayoutPreferences
        || didChangePianoPanel
        || didChangeFretboard
        || didChangeStaff {
        synchronizeExerciseCompositionState(
            reason: "settingsStateChanged"
        )
    }
}
```

### 6. macOS 控制器同步切到 shared composition policy

- `macOSViewController` 与 iOS 保持对称改造
- 同样新增 `exerciseLayoutPreferences` / `exercisePresentationState` / `synchronizeExerciseCompositionState(reason:)`
- 同样把 `naturalNoteStripView.areButtonsEnabled` 改为读取 `ExercisePresentationState`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: exerciseLayoutPreferences, exercisePresentationState, settingsPanelStateContext, exerciseCompositionPolicyInput, synchronizeExerciseCompositionState(reason:)
// 功能说明: 修改后 macOS 控制器也从平台层拍板 page 语义，切换为 shared policy -> legacy projection。
private var pageDisplayState = macOSViewController.initialExercisePresentationState
    .legacyPageDisplayState ?? .default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
        handleQuarterNoteSequencePageDisplayStateTransition(
            from: oldValue,
            to: pageDisplayState
        )
    }
}
private var exerciseLayoutPreferences = macOSViewController
    .initialExerciseLayoutPreferences {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}
private var exercisePresentationState = macOSViewController
    .initialExercisePresentationState

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
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizeSingleTrainerPresentation(reason:), synchronizePositionPromptPresentation(reason:), synchronizeQuarterNoteSequencePresentation(reason:), updateNaturalNoteStripInteractionState(), handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS 控制器与 iOS 一样，先维护 trainer/session，再统一走 shared policy 重组页面语义。
private func synchronizeSingleTrainerPresentation(reason: String) {
    // ... 其他未改动代码省略

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    synchronizeExerciseCompositionState(reason: reason)
    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    // ... 其他未改动代码省略

    synchronizeExerciseCompositionState(reason: reason)
    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}

private func updateNaturalNoteStripInteractionState() {
    guard isViewLoaded else {
        return
    }

    let isInteractionEnabled = exercisePresentationState.surfaceState(
        for: .naturalNoteStrip
    )?.isInteractionEnabled ?? false

    if trainerDisplayState.isPositionPromptMode {
        naturalNoteStripView.areButtonsEnabled = isInteractionEnabled
            && currentPositionPromptOverlayPhase == .neutralWhite
    } else {
        naturalNoteStripView.areButtonsEnabled = isInteractionEnabled
    }
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    let nextRequestedStaffDisplayState = nextStateContext.staffDisplayState

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextExerciseLayoutPreferences = nextStateContext
        .exerciseLayoutPreferences
    let nextTrainerDisplayState = nextStateContext.trainerDisplayState
    let nextPianoPanelState = nextStateContext.pianoPanelState

    // ... 其他未改动代码省略

    if didChangeTrainer {
        synchronizeTrainerPresentationState(reason: trainerSyncReason)
    } else if didChangeExerciseLayoutPreferences
        || didChangePianoPanel
        || didChangeFretboard
        || didChangeStaff {
        synchronizeExerciseCompositionState(
            reason: "settingsStateChanged"
        )
    }
}
```

### 7. `ExerciseCompositionValidation` 补齐阶段 3 夹具和断言

- 新增 3 个阶段 3 夹具：
- `composition_policy_projects_supported_presets_to_expected_scenes`
- `legacy_compatible_policy_falls_back_when_scene_exceeds_page_model`
- `scene_validator_rejects_duplicate_logical_surface_ids`
- 同步把手工清单中的 `Piano Visible` 文案改为 `Piano Accessory Visible`
- `validatePageStateNormalizationPreservesSingleFretboardSlot()` 改为同时校验 shared validator 本体和 `PageDisplayState` 的委托关系

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:), validatePageStateNormalizationPreservesSingleFretboardSlot()
// 功能说明: 修改后 validation 会覆盖 phase 3 的 policy / validator 行为，并验证 legacy page 规则已委托 shared validator。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "shared_layout_preferences_coexist_with_legacy_page_state",
            validate: validateSharedLayoutPreferencesCoexistWithLegacyPageState
        ),
        ExerciseCompositionValidationFixture(
            name: "composition_policy_projects_supported_presets_to_expected_scenes",
            validate: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes
        ),
        ExerciseCompositionValidationFixture(
            name: "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model",
            validate: validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel
        ),
        ExerciseCompositionValidationFixture(
            name: "scene_validator_rejects_duplicate_logical_surface_ids",
            validate: validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs
        ),
        ExerciseCompositionValidationFixture(
            name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
            validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
        )
    ]
}

static func manualChecklist(
    for platform: ExerciseCompositionValidationPlatform
) -> [String] {
    var checklist = [
        "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
        "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
        "确认打开 settings 只改变 card 可见性，不会重置当前 trainer mode、page layout 或 `pianoAccessoryVisible`。",
        "确认关闭 settings 后页面恢复到关闭前的 prompt/answer 组合，不会闪回 `PageDisplayState.default`。",
        "确认 `Piano Accessory Visible` 默认关闭；打开后只追加钢琴区域，关闭后主 prompt/answer 组合不发生漂移。"
    ]

    // ... 其他未改动代码省略
    return checklist
}

static func validatePageStateNormalizationPreservesSingleFretboardSlot()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "page_state_normalization_preserves_single_fretboard_slot"
    var issues: [ExerciseCompositionValidationIssue] = []

    let topPrioritizedState = ExerciseSceneValidator
        .normalizedLegacyPageDisplayState(
            from: PageDisplayState(
                topContentMode: .fretboard,
                mainContentMode: .fretboard
            ),
            prioritizingTopContent: true
        )

    let mainPrioritizedState = ExerciseSceneValidator
        .normalizedLegacyPageDisplayState(
            from: PageDisplayState(
                topContentMode: .fretboard,
                mainContentMode: .fretboard
            ),
            prioritizingTopContent: false
        )

    var delegatedTopPrioritizedState = PageDisplayState.default
    delegatedTopPrioritizedState.setTopContentMode(.fretboard)

    var delegatedMainPrioritizedState = PageDisplayState.positionPrompt
    delegatedMainPrioritizedState.setMainContentMode(.fretboard)

    // ... 其他未改动代码省略
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes(), validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel(), validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs()
// 功能说明: 新增 phase 3 自动化夹具，锁定 policy 的 scene 投影、legacy fallback 和 duplicate logical surface 拒绝行为。
static func validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "composition_policy_projects_supported_presets_to_expected_scenes"
    var issues: [ExerciseCompositionValidationIssue] = []

    let sideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
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

    let selfAnswerPresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt),
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: .singleFretboardSelfAnswer
        )
    )

    // ... 其他未改动代码省略
    return issues
}

static func validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model"
    var issues: [ExerciseCompositionValidationIssue] = []

    let sideBySideLegacyPresentation = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
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

    let selfAnswerLegacyPresentation = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt),
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .singleFretboardSelfAnswer
            )
        )

    // ... 其他未改动代码省略
    return issues
}

static func validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "scene_validator_rejects_duplicate_logical_surface_ids"
    var issues: [ExerciseCompositionValidationIssue] = []

    let duplicateFretboardScene = ExerciseScene(
        root: .makeSplit(
            axis: .vertical,
            children: [
                ExerciseSceneSplitChild(node: .surface(.fretboardPrompt)),
                ExerciseSceneSplitChild(node: .surface(.fretboardAnswer))
            ]
        )
    )
    let duplicateIssues = ExerciseSceneValidator.validate(
        duplicateFretboardScene
    )

    let validSelfAnswerScene = ExerciseScene.singleSurface(
        .fretboardPromptAndAnswer
    )

    // ... 其他未改动代码省略
    return issues
}
```

## 验证结果

- `ReadLints`：通过
- `macOS` Debug build：通过
- `iOS Simulator` Debug build：通过

```sh
# 文件路径: N/A（命令行验证）
# 函数名: N/A
# 功能说明: 本次阶段 3 记录对应的时间戳与关键验证命令。
date +"%Y%m%d_%H%M%S"
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build
```

```sh
# 文件路径: N/A（验证结果摘要）
# 函数名: N/A
# 功能说明: 本次阶段 3 修改对应的关键检查结果摘要。
# 时间戳: 20260401_200432
# ReadLints: No linter errors found.
# macOS build: succeeded
# iOS Simulator build: succeeded
```

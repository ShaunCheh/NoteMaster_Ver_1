# 20260401_185855_phase1_exercise_scene_shared_contracts

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_185855`
- 记录范围：`场景树迁移` 计划的阶段 1，只建立 shared 场景树契约，并让新模型与旧 `PageDisplayState` 并存；本阶段不切换 iOS/macOS renderer，不改用户可见 settings 入口
- 修改性质：新增 `ExerciseLayoutPreferences / ExerciseScene / ExercisePresentationState / ExerciseAnswerEvent` 四个 shared 文件；扩展 `SettingsPanelStateContext` 与 `TrainerDisplayState`；补强 `ExerciseCompositionValidation` 的阶段 1 断言；完成 lint 与双平台编译验证
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerEvent.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 修改前

- Shared 层还没有“组合预设 / 布局预设 / 辅助区策略”的统一偏好模型。
- Shared 层还没有可以声明 `上下`、`左右`、`单 surface`，以及“同一个 surface 同时承担 `prompt + answer`”的场景树契约。
- Shared 层还没有 `ExercisePresentationState` 来承接场景树和 surface 级交互状态，也没有统一的 `ExerciseAnswerEvent` 来描述答题输入来源。
- `SettingsPanelStateContext` 只持有 `pageDisplayState`，还没有并存新的 `exerciseLayoutPreferences`。
- `TrainerPositionPromptConfiguration` 只有 filter 相关配置，没有 shared answer rule；`TrainerDisplayState` 也没有把答题规则向外暴露。
- `ExerciseCompositionValidation` 只冻结了阶段 0 的 legacy baseline，还没有自动验证阶段 1 的 shared 契约本身。

```text
# 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前 Shared 层没有“组合预设 + 布局预设 + 辅助区策略”的统一偏好模型。
（文件不存在）
```

```text
# 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前 Shared 层没有 ExerciseScene / ExerciseSceneNode / ExerciseSurfaceNode 这一套场景树契约。
（文件不存在）
```

```text
# 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前 Shared 层没有 surface state 投影容器，无法把 scene 与交互状态打包成独立 presentation state。
（文件不存在）
```

```text
# 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerEvent.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前 Shared 层没有统一的答题事件协议，控制器后续也就没有可复用的 answer router 输入模型。
（文件不存在）
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: init(...)
// 功能说明: 修改前 settings shared context 只持有 legacy pageDisplayState，还没有并存新的 exerciseLayoutPreferences。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState

    static let `default` = SettingsPanelStateContext()

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState = .default,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init()
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.pageDisplayState = pageDisplayState
        self.trainerDisplayState = trainerDisplayState
        self.pianoPanelState = pianoPanelState
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名: TrainerPositionPromptConfiguration.init(...), normalized(), TrainerDisplayState.init(...)
// 功能说明: 修改前 position prompt 只有 filter 配置，没有 shared answer rule，也没有对外暴露的答题规则入口。
enum PositionPromptCandidateFilter: Equatable, Sendable {
    case noteNames(Set<PitchClass>)
    case frets(Set<Int>)
}

struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let supportedPitchClasses: [PitchClass] = PitchClass.naturalCasesInOrder
    static let defaultFilterMode: TrainerPositionPromptFilterMode = .noteName

    var filterMode: TrainerPositionPromptFilterMode
    private(set) var selectedPitchClasses: Set<PitchClass>
    private(set) var selectedFrets: Set<Int>

    init(
        filterMode: TrainerPositionPromptFilterMode = Self.defaultFilterMode,
        selectedPitchClasses: Set<PitchClass> = Self.defaultSelectedPitchClasses,
        selectedFrets: Set<Int> = Self.defaultSelectedFrets
    ) {
        self.filterMode = filterMode
        self.selectedPitchClasses = Self.normalizedSelectedPitchClasses(
            selectedPitchClasses
        )
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    func normalized() -> TrainerPositionPromptConfiguration {
        TrainerPositionPromptConfiguration(
            filterMode: filterMode,
            selectedPitchClasses: selectedPitchClasses,
            selectedFrets: selectedFrets
        )
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration
    var positionPromptConfiguration: TrainerPositionPromptConfiguration
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures()
// 功能说明: 修改前 validation 只覆盖阶段 0 的 legacy baseline，还没有阶段 1 shared 契约夹具。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
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
        ),
        ExerciseCompositionValidationFixture(
            name: "page_state_normalization_preserves_single_fretboard_slot",
            validate: validatePageStateNormalizationPreservesSingleFretboardSlot
        ),
        ExerciseCompositionValidationFixture(
            name: "layout_defaults_keep_piano_hidden_and_vertical_viewport_visible",
            validate: validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible
        )
    ]
}
```

## 修改后

### 1. 新增布局偏好模型

- 新增 `ExerciseCompositionPreset`、`ExerciseLayoutPreset`、`ExerciseAccessoryPresentation`
- 先把“外部设置层”收口成预设，而不是直接暴露树节点编辑
- 预留了 `legacyPositionPrompt` 与 `singleFretboardSelfAnswer` 两个代表性偏好值

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名: ExerciseLayoutPreferences.init(...)
// 功能说明: 新增 shared 布局偏好模型，用组合预设、布局预设和辅助区策略描述场景树外层偏好。
enum ExerciseCompositionPreset: String, CaseIterable, Equatable, Hashable, Sendable {
    case staffToFretboard
    case targetPromptToFretboard
    case fretboardToNaturalNoteStrip
    case fretboardSelfAnswer
}

enum ExerciseLayoutPreset: String, CaseIterable, Equatable, Hashable, Sendable {
    case stacked
    case sideBySide
    case singleSurface
    case threePane
    case overlay
    case collapsibleAccessory
}

enum ExerciseAccessoryPresentation: String, CaseIterable, Equatable, Hashable, Sendable {
    case docked
    case floating
    case collapsible
}

struct ExerciseLayoutPreferences: Equatable, Sendable {
    var compositionPreset: ExerciseCompositionPreset
    var layoutPreset: ExerciseLayoutPreset
    var accessoryPresentation: ExerciseAccessoryPresentation
    var isNaturalNoteStripVisible: Bool
    var isPianoAccessoryVisible: Bool
    var isAccessoryExpanded: Bool

    static let `default` = ExerciseLayoutPreferences()
    static let legacyPositionPrompt = ExerciseLayoutPreferences(
        compositionPreset: .fretboardToNaturalNoteStrip,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: true,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
    static let singleFretboardSelfAnswer = ExerciseLayoutPreferences(
        compositionPreset: .fretboardSelfAnswer,
        layoutPreset: .singleSurface,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
}
```

### 2. 新增场景树契约

- 新增 `ExerciseRole`、`ExerciseSurfaceID`、`ExerciseSurfaceKind`
- 新增 `ExerciseSceneNode`，支持 `surface / split / overlay / collapsible`
- 新增 `ExerciseScene.stacked / sideBySide / singleSurface`
- 明确允许同一个 `fretboard` 同时承担 `.prompt + .answer`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseScene.stacked(...), sideBySide(...), singleSurface(...)
// 功能说明: 新增 shared 场景树契约，支持上下、左右、单 surface，以及一个 surface 同时持有 prompt 与 answer 角色。
enum ExerciseRole: String, CaseIterable, Equatable, Hashable, Sendable {
    case prompt
    case answer
    case auxiliary
}

enum ExerciseSurfaceID: String, CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case targetPrompt
    case naturalNoteStrip
    case piano
}

struct ExerciseSurfaceNode: Equatable, Sendable {
    var id: ExerciseSurfaceID
    var kind: ExerciseSurfaceKind
    private(set) var roles: Set<ExerciseRole>

    var isPromptSurface: Bool {
        roles.contains(.prompt)
    }

    var isAnswerSurface: Bool {
        roles.contains(.answer)
    }
}

indirect enum ExerciseSceneNode: Equatable, Sendable {
    case surface(ExerciseSurfaceNode)
    case split(axis: ExerciseSceneAxis, children: [ExerciseSceneSplitChild])
    case overlay(base: ExerciseSceneNode, floating: [ExerciseSceneNode])
    case collapsible(
        main: ExerciseSceneNode,
        accessory: ExerciseSceneNode,
        isExpanded: Bool
    )

    static func makeSplit(
        axis: ExerciseSceneAxis,
        children: [ExerciseSceneSplitChild]
    ) -> ExerciseSceneNode {
        precondition(children.count >= 2)
        return .split(axis: axis, children: children)
    }
}

struct ExerciseScene: Equatable, Sendable {
    var root: ExerciseSceneNode

    static func stacked(
        top: ExerciseSurfaceNode,
        bottom: ExerciseSurfaceNode
    ) -> ExerciseScene {
        ExerciseScene(
            root: .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(node: .surface(top)),
                    ExerciseSceneSplitChild(node: .surface(bottom))
                ]
            )
        )
    }

    static func sideBySide(
        leading: ExerciseSurfaceNode,
        trailing: ExerciseSurfaceNode
    ) -> ExerciseScene {
        ExerciseScene(
            root: .makeSplit(
                axis: .horizontal,
                children: [
                    ExerciseSceneSplitChild(node: .surface(leading)),
                    ExerciseSceneSplitChild(node: .surface(trailing))
                ]
            )
        )
    }

    static func singleSurface(_ surface: ExerciseSurfaceNode) -> ExerciseScene {
        ExerciseScene(root: .surface(surface))
    }
}

extension ExerciseSurfaceNode {
    static let fretboardPromptAndAnswer = ExerciseSurfaceNode(
        id: .fretboard,
        kind: .fretboard,
        roles: [.prompt, .answer]
    )
}
```

### 3. 新增 presentation state 与 answer event 契约

- `ExercisePresentationState` 把 scene 和 per-surface state 收口到一个 shared 结构里
- `ExerciseAnswerEvent` 把答题输入来源与 payload 统一成 shared 事件
- 首版 payload 先覆盖 `PitchClass` 和 `FretboardCell`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseSurfaceState.init(surface:isVisible:), ExercisePresentationState.surfaceState(for:), setSurfaceState(_:for:)
// 功能说明: 新增 shared presentation state，让 surface 默认状态可由角色自动推导，也允许后续 policy 显式覆盖。
struct ExerciseSurfaceState: Equatable, Sendable {
    var isVisible: Bool
    var isPromptActive: Bool
    var isAnswerEnabled: Bool

    init(
        surface: ExerciseSurfaceNode,
        isVisible: Bool = true
    ) {
        self.init(
            isVisible: isVisible,
            isPromptActive: surface.isPromptSurface,
            isAnswerEnabled: surface.isAnswerSurface
        )
    }
}

struct ExercisePresentationState: Equatable, Sendable {
    var scene: ExerciseScene
    private(set) var surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState]

    func surfaceState(
        for surfaceID: ExerciseSurfaceID
    ) -> ExerciseSurfaceState? {
        if let state = surfaceStates[surfaceID] {
            return state
        }
        guard let surface = scene.surfaceNode(for: surfaceID) else {
            return nil
        }
        return ExerciseSurfaceState(surface: surface)
    }

    mutating func setSurfaceState(
        _ state: ExerciseSurfaceState,
        for surfaceID: ExerciseSurfaceID
    ) {
        surfaceStates[surfaceID] = state
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerEvent.swift
// 函数名: ExerciseAnswerEvent.pitchClass(_:from:), fretboardCell(_:from:)
// 功能说明: 新增 shared 答题事件模型，把来源 surface 与 payload 一起收口，为后续 answer router 做输入契约。
enum ExerciseAnswerPayload: Equatable, Sendable {
    case pitchClass(PitchClass)
    case fretboardCell(FretboardCell)
}

struct ExerciseAnswerEvent: Equatable, Sendable {
    var surfaceID: ExerciseSurfaceID
    var payload: ExerciseAnswerPayload

    static func pitchClass(
        _ pitchClass: PitchClass,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .pitchClass(pitchClass)
        )
    }

    static func fretboardCell(
        _ cell: FretboardCell,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .fretboardCell(cell)
        )
    }
}
```

### 4. 让新旧布局模型并存

- `SettingsPanelStateContext` 新增 `exerciseLayoutPreferences`
- 但 `pageDisplayState` 仍保留，确保阶段 2 之前 legacy settings / page snapshot 不被破坏

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: init(...)
// 功能说明: 修改后 settings shared context 同时持有 legacy pageDisplayState 与新的 exerciseLayoutPreferences，为阶段 2 的 settings 迁移做并存准备。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState

    static let `default` = SettingsPanelStateContext()

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState = .default,
        exerciseLayoutPreferences: ExerciseLayoutPreferences = .default,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init()
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.pageDisplayState = pageDisplayState
        self.exerciseLayoutPreferences = exerciseLayoutPreferences
        self.trainerDisplayState = trainerDisplayState
        self.pianoPanelState = pianoPanelState
    }
}
```

### 5. 在 trainer shared state 中加入 answer rule

- 新增 `PositionPromptAnswerRule`
- 首版只落 `samePitchClass`
- `TrainerPositionPromptConfiguration` 和 `TrainerDisplayState` 都增加了默认值、访问入口与写回入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名: TrainerPositionPromptConfiguration.init(...), normalized(), setAnswerRule(_:)；TrainerDisplayState.positionPromptAnswerRule, setPositionPromptAnswerRule(_:)
// 功能说明: 修改后 position prompt 在 shared 层拥有 answer rule，并先固定首版 samePitchClass 语义。
enum PositionPromptAnswerRule: Equatable, Hashable, Sendable {
    case samePitchClass
}

struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let defaultAnswerRule: PositionPromptAnswerRule = .samePitchClass

    var filterMode: TrainerPositionPromptFilterMode
    var answerRule: PositionPromptAnswerRule
    private(set) var selectedPitchClasses: Set<PitchClass>
    private(set) var selectedFrets: Set<Int>

    init(
        filterMode: TrainerPositionPromptFilterMode = Self.defaultFilterMode,
        answerRule: PositionPromptAnswerRule = Self.defaultAnswerRule,
        selectedPitchClasses: Set<PitchClass> = Self.defaultSelectedPitchClasses,
        selectedFrets: Set<Int> = Self.defaultSelectedFrets
    ) {
        self.filterMode = filterMode
        self.answerRule = answerRule
        self.selectedPitchClasses = Self.normalizedSelectedPitchClasses(
            selectedPitchClasses
        )
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    func normalized() -> TrainerPositionPromptConfiguration {
        TrainerPositionPromptConfiguration(
            filterMode: filterMode,
            answerRule: answerRule,
            selectedPitchClasses: selectedPitchClasses,
            selectedFrets: selectedFrets
        )
    }

    mutating func setAnswerRule(_ answerRule: PositionPromptAnswerRule) {
        self.answerRule = answerRule
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration
    var positionPromptConfiguration: TrainerPositionPromptConfiguration

    var positionPromptAnswerRule: PositionPromptAnswerRule {
        positionPromptConfiguration.answerRule
    }

    mutating func setPositionPromptAnswerRule(
        _ answerRule: PositionPromptAnswerRule
    ) {
        positionPromptConfiguration.setAnswerRule(answerRule)
    }
}
```

### 6. 用 validation 冻结阶段 1 shared 契约

- `ExerciseCompositionValidation` 新增 4 个阶段 1 fixture
- 自动验证三类基础场景：
  - `stacked`
  - `sideBySide`
  - `singleSurface`
- 自动验证：
  - 默认 surface state 是否跟随角色投影
  - 新的 `exerciseLayoutPreferences` 是否能与 legacy `pageDisplayState` 并存
  - `samePitchClass` 是否作为首版默认 answer rule
  - `ExerciseAnswerEvent` 是否保留 payload 与来源 surface

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures()
// 功能说明: 修改后阶段 1 shared 契约也被纳入自动化 fixture，不再只有阶段 0 legacy baseline。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
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
        ),
        ExerciseCompositionValidationFixture(
            name: "page_state_normalization_preserves_single_fretboard_slot",
            validate: validatePageStateNormalizationPreservesSingleFretboardSlot
        ),
        ExerciseCompositionValidationFixture(
            name: "layout_defaults_keep_piano_hidden_and_vertical_viewport_visible",
            validate: validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible
        ),
        ExerciseCompositionValidationFixture(
            name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
            validate: validateSharedSceneContractsCoverBasicLayouts
        ),
        ExerciseCompositionValidationFixture(
            name: "shared_surface_state_defaults_follow_surface_roles",
            validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
        ),
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateSharedSceneContractsCoverBasicLayouts(), validateSharedLayoutPreferencesCoexistWithLegacyPageState(), validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass()
// 功能说明: 修改后新增 shared 契约断言，分别校验基础场景树、并存状态容器和 answer event / answer rule 契约。
let stackedScene = ExerciseScene.stacked(
    top: .staffPrompt,
    bottom: .fretboardAnswer
)

let sideBySideScene = ExerciseScene.sideBySide(
    leading: .targetPrompt,
    trailing: .fretboardAnswer
)

let singleSurfaceScene = ExerciseScene.singleSurface(
    .fretboardPromptAndAnswer
)

let stateContext = SettingsPanelStateContext(
    pageDisplayState: .positionPrompt,
    exerciseLayoutPreferences: .singleFretboardSelfAnswer,
    trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt)
)
let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)

let defaultConfiguration = TrainerPositionPromptConfiguration.default
var trainerDisplayState = TrainerDisplayState(exerciseMode: .positionPrompt)
trainerDisplayState.setPositionPromptAnswerRule(.samePitchClass)

let fretboardCellEvent = ExerciseAnswerEvent.fretboardCell(
    FretboardCell(stringIndex: 2, fret: 3),
    from: .fretboard
)
let pitchClassEvent = ExerciseAnswerEvent.pitchClass(
    .c,
    from: .naturalNoteStrip
)
```

## 验证结果

- `ReadLints` 检查上述 7 个改动文件，未发现 diagnostics
- `macOS` Debug build 通过
- `iOS Simulator` Debug build 通过
- 实现过程中首次 `macOS` build 暴露 `ExerciseSceneNode` 静态工厂方法与 enum case 同名导致的 redeclaration；最终代码已改为 `makeSplit / makeOverlay / makeCollapsible`，最终双平台 build 全部通过

```sh
# 文件路径: N/A（命令行验证）
# 函数名: N/A
# 功能说明: 阶段 1 完成后执行的静态检查与双平台编译验证命令。
date +"%Y%m%d_%H%M%S"
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build
```

```text
# 文件路径: N/A（命令行验证结果）
# 函数名: N/A
# 功能说明: 本次记录对应的关键验证结果摘要。
时间戳: 20260401_185855
ReadLints: No linter errors found.
macOS build: succeeded
iOS Simulator build: succeeded
```

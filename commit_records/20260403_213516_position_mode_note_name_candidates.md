# 20260403_213516_position_mode_note_name_candidates

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_213516`
- 记录范围：只记录本轮“把 Position 模式的出题候选音名做成独立配置，并把入口放到 `Exercise > Mode`”的代码修改
- 本记录中的“修改前”：
- 对 `TrainerDisplayState.swift` / `SettingsPanelModel.swift` / `SettingsPanelSnapshotBuilder.swift` / `SettingsNavigationSnapshotBuilder.swift`，指本轮修改前 shared settings 与 trainer 状态仍把 Position 模式候选集合语义绑定在旧的 `positionPromptConfiguration` 上
- 对 `iOSViewController.swift` / `macOSViewController.swift` / `FretboardNaturalNoteTrainer.swift`，指 Position 模式实际出题仍直接读取 `positionPromptConfiguration.activeFilter`
- 本记录不放原始 `git diff`，只按真实代码状态说明“修改前 / 修改后”
- 本轮代码改动文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本轮相关代码文件状态（生成本记录前的 `git status --short`）：
- `M NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `M NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `M NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
- `M NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- `M NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `M NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `M NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `M NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `M NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `M NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `M NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `M NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `M NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本轮 `git diff --stat`（仅上述代码文件）：`13 files changed, 323 insertions(+), 202 deletions(-)`

## 1. 本轮目标

- 用户需求只和“Position 模式的出题候选项”有关，不和旧的 `Position Prompt` 设置语义绑定。
- 目标不是把旧的 `Position Prompt` 配置搬过来继续共用，而是：
- 新增一份只服务于 Position 出题候选项的独立状态
- 在 `Exercise > Mode` 页面增加 `Note Names` 多选入口
- Position 模式实际出题只从这组被选中的音名里选
- 默认仍保持 `C / E / F / B`
- 继续复用现有音名多选按钮样式，但不再让“样式复用”变成“语义耦合”

## 2. 修改一：新增独立的 Position 出题候选配置

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/符号: struct TrainerDisplayState
// 修改前说明:
// 1. TrainerDisplayState 没有独立的 Position 出题候选配置。
// 2. Position 模式相关的候选集合只能借用 positionPromptConfiguration。
struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration
    var positionPromptConfiguration: TrainerPositionPromptConfiguration

    var positionPromptAnswerRule: PositionPromptAnswerRule {
        positionPromptConfiguration.answerRule
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/符号: struct TrainerPositionQuestionConfiguration / struct TrainerDisplayState
// 修改后说明:
// 1. 新增独立的 TrainerPositionQuestionConfiguration，专门承载 Position 模式出题候选音名。
// 2. 默认选中集合固定为 C / E / F / B。
// 3. TrainerDisplayState 通过 positionQuestionCandidateFilter 对外暴露 Position 出题候选集合。
struct TrainerPositionQuestionConfiguration: Equatable, Sendable {
    static let supportedPitchClasses: [PitchClass] = PitchClass.naturalCasesInOrder
    static let defaultSelectedPitchClasses: Set<PitchClass> = [
        .c, .e, .f, .b
    ]

    private(set) var selectedPitchClasses: Set<PitchClass>

    var activeFilter: PositionPromptCandidateFilter {
        .noteNames(selectedPitchClasses)
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration
    var positionQuestionConfiguration: TrainerPositionQuestionConfiguration
    var positionPromptConfiguration: TrainerPositionPromptConfiguration

    var positionQuestionCandidateFilter: PositionPromptCandidateFilter {
        positionQuestionConfiguration.activeFilter
    }
}
```

## 3. 修改二：把入口挂到 `Exercise > Mode`，而不是继续暴露 root 级 `Position Prompt` 分区

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号: SettingsSectionID.allCases / SettingsSectionID.rowIDs
// 修改前说明:
// 1. settings root 仍然暴露 Position Prompt section。
// 2. Exercise section 只有 Exercise Mode / Composition Preset / Layout Preset 三行。
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

case .exercise:
    return [
        .choice(.exerciseMode),
        .choice(.compositionPreset),
        .choice(.layoutPreset)
    ]
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号: SettingsSectionID.allCases / SettingsSectionID.rowIDs / SettingsPositionFilterRowID
// 修改后说明:
// 1. root settings 不再把 Position Prompt 当成独立 section 暴露。
// 2. Exercise section 新增 positionQuestionPitchClasses 行，作为 Position 模式的音名候选入口。
// 3. 这个 rowID 是独立的，不复用旧的 positionPromptFilterOptions。
static var allCases: [SettingsSectionID] {
    [
        .exercise,
        .accessories,
        .fretboard,
        .staff,
        .piano,
        .debug
    ]
}

case .exercise:
    return [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses),
        .choice(.compositionPreset),
        .choice(.layoutPreset)
    ]

enum SettingsPositionFilterRowID: CaseIterable, Equatable, Hashable, Sendable {
    case positionQuestionPitchClasses
    case positionPromptFilterOptions
}
```

### 3.3 `Exercise > Mode` 页面实际携带这行

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数/符号: childPageSpecs(for:)
// 修改后说明:
// 1. Exercise > Mode 子页除了 Exercise Mode 之外，还会携带 positionQuestionPitchClasses。
// 2. 这样用户在 Mode 页面就能直接控制 Position 模式出题候选音名。
case .exercise:
    return [
        ChildPageSpec(
            route: .exerciseMode,
            title: SettingsRouteID.exerciseMode.fallbackTitle,
            subtitle: "Single, sequence, or position",
            rowIDs: [
                .choice(.exerciseMode),
                .positionFilter(.positionQuestionPitchClasses)
            ]
        ),
        // ... 其余子页保持不变 ...
    ]
```

## 4. 修改三：继续复用按钮样式，但把事件语义从 `Position Prompt` 解耦

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号: enum SettingsPanelEvent
// 修改前说明:
// 1. 音名多选按钮事件名字直接叫 togglePositionPromptFilterOption。
// 2. 这意味着样式复用和 Position Prompt 语义被硬绑在一起。
enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case togglePositionPromptFilterOption(SettingsPositionFilterOptionID)
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/符号: PositionFilterRowView.handleOptionButtonTap(_:)
// 修改前说明:
// PositionFilterRowView 只能发出“Position Prompt 过滤项被切换”的事件。
@objc
private func handleOptionButtonTap(_ sender: PositionFilterButton) {
    guard let optionID = sender.optionID, sender.isEnabled else {
        return
    }

    onEvent?(.togglePositionPromptFilterOption(optionID))
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号: enum SettingsPanelEvent.apply(to:)
// 修改后说明:
// 1. 事件改成 togglePositionFilterOption(rowID, optionID)。
// 2. 同一个按钮样式现在可以根据 rowID 写回不同状态源。
// 3. positionQuestionPitchClasses 专门写回 Position 出题候选配置。
enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case togglePositionFilterOption(
        SettingsPositionFilterRowID,
        SettingsPositionFilterOptionID
    )
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)

    func apply(
        to stateContext: inout SettingsPanelStateContext
    ) {
        switch self {
        case let .togglePositionFilterOption(rowID, optionID):
            switch rowID {
            case .positionQuestionPitchClasses:
                guard case let .pitchClass(pitchClass) = optionID else {
                    return
                }
                stateContext.trainerDisplayState.togglePositionQuestionPitchClass(
                    pitchClass
                )
            case .positionPromptFilterOptions:
                // 旧的 Position Prompt 过滤语义仍保留在这里。
                break
            }
        default:
            break
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/符号: PositionFilterRowView.apply(item:) / PositionFilterRowView.handleOptionButtonTap(_:)
// 修改后说明:
// 1. 平台 view 继续复用同一套按钮外观。
// 2. 但现在会先记住当前 rowID，再把 rowID 和 optionID 一起回传。
private final class PositionFilterRowView: UIView {
    private var rowID: SettingsPositionFilterRowID?

    func apply(item: SettingsPositionFilterRow) {
        rowID = item.id
        // ... 其余渲染逻辑保持不变 ...
    }

    @objc
    private func handleOptionButtonTap(_ sender: PositionFilterButton) {
        guard
            let rowID,
            let optionID = sender.optionID,
            sender.isEnabled
        else {
            return
        }

        onEvent?(.togglePositionFilterOption(rowID, optionID))
    }
}
```

## 5. 修改四：Position 模式实际出题改读新配置

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/符号: currentPositionPromptFilter / handleSettingsPanelEvent(_:)
// 修改前说明:
// 1. Position 模式实际出题直接读取 positionPromptConfiguration.activeFilter。
// 2. 设置变化监听的也是 didChangePositionPromptActiveFilter。
private var currentPositionPromptFilter: PositionPromptCandidateFilter {
    trainerDisplayState.positionPromptConfiguration.activeFilter
}

let didChangePositionPromptActiveFilter =
    nextTrainerDisplayState.positionPromptConfiguration.activeFilter
    != trainerDisplayState.positionPromptConfiguration.activeFilter
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/符号: makePositionPromptSession(configuration:filter:)
// 修改前说明:
// trainer 的默认 filter 也仍然落在 TrainerPositionPromptConfiguration.default.activeFilter。
func makePositionPromptSession(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter
) -> PositionPromptSession
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/符号: currentPositionQuestionCandidateFilter / handleSettingsPanelEvent(_:)
// 修改后说明:
// 1. Position 模式候选集改成从 positionQuestionCandidateFilter 读取。
// 2. 当候选音名集合变化时，controller 会识别 didChangePositionQuestionCandidates 并重建 session。
private var currentPositionQuestionCandidateFilter: PositionPromptCandidateFilter {
    trainerDisplayState.positionQuestionCandidateFilter
}

private var currentPositionPromptCandidatePoolSignature: FretboardNaturalNoteTrainerState.PositionPromptSession.SchedulingState.CandidatePoolSignature {
    FretboardNaturalNoteTrainerState.positionPromptCandidatePoolSignature(
        in: displayState.configuration,
        filter: currentPositionQuestionCandidateFilter
    )
}

let didChangePositionQuestionCandidates =
    nextTrainerDisplayState.positionQuestionCandidateFilter
    != trainerDisplayState.positionQuestionCandidateFilter
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/符号: makePositionPromptSession(configuration:filter:)
// 修改后说明:
// trainer 的默认候选 filter 也已经对齐到新的 Position 出题配置，防止默认值继续从旧语义漏进来。
func makePositionPromptSession(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionQuestionConfiguration.default.activeFilter
) -> PositionPromptSession
```

## 6. 修改五：`Exercise > Mode` 的音名按钮实际按新状态回显

### 6.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/符号: makePositionFilterRow(id:stateContext:)
// 修改前说明:
// 旧的音名按钮只会从 trainerDisplayState.positionPromptConfiguration 取值并回显。
private static func makePositionFilterRow(
    id: SettingsPositionFilterRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsPositionFilterRow {
    let configuration = stateContext.trainerDisplayState.positionPromptConfiguration
    // ... 继续生成 Note Names / Frets ...
}
```

### 6.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/符号: makePositionFilterRow(id:stateContext:)
// 修改后说明:
// 1. positionQuestionPitchClasses 现在单独从 positionQuestionConfiguration 生成 UI 回显。
// 2. 旧的 positionPromptFilterOptions 分支仍保留，但已经不再作为本轮 Position 出题入口。
private static func makePositionFilterRow(
    id: SettingsPositionFilterRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsPositionFilterRow {
    switch id {
    case .positionQuestionPitchClasses:
        let configuration = stateContext.trainerDisplayState
            .positionQuestionConfiguration
        return SettingsPositionFilterRow(
            id: id,
            title: "Note Names",
            accessibilityLabel: "Select the note names used when generating position questions",
            options: id.supportedPitchClasses.map { pitchClass in
                let title = pitchClass.displayText()
                let isSelected = configuration.contains(pitchClass)
                return SettingsPositionFilterItem(
                    id: .pitchClass(pitchClass),
                    title: title,
                    accessibilityLabel: "Toggle note name \(title) for position questions",
                    isSelected: isSelected,
                    isEnabled: !isSelected || configuration.canDeselect(pitchClass)
                )
            }
        )
    case .positionPromptFilterOptions:
        // ... 旧的 Position Prompt 分支保留，仍然继续读取 positionPromptConfiguration ...
    }
}
```

## 7. 验证结果

- `ReadLints` 检查本轮修改文件：无 linter 错误
- 实际构建验证：
- 命令：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- 结果：`BUILD SUCCEEDED`

## 8. 本轮结果归纳

- Position 模式现在有独立的“出题候选音名”状态源，不再借用旧的 `positionPromptConfiguration`
- `Exercise > Mode` 页面新增 `Note Names` 多选按钮，默认回显 `C / E / F / B`
- Position 模式的实际出题候选池已改为读取这组新状态
- root settings 不再继续暴露会造成语义误导的 `Position Prompt` 独立分区
- 现有多选按钮样式仍然复用，但事件和状态写回已经按 rowID 做了解耦

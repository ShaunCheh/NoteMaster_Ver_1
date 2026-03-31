# 20260331_104725_phase2_position_filter_settings_abstraction

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_104725`
- 记录范围：实施“Position 过滤模式重构”计划的阶段 2，只完成 settings 共享模型、snapshot builder、事件抽象与双端 settings 行兼容改造；不包含 shared trainer 候选池改造，不包含 controller 的 session 重建逻辑
- 本次目标：把设置层从“专用 fret filter”抽成“通用 position filter”体系，为后续接入 `noteName` / `fret` 两种过滤模式做准备
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`

## 本次结论

- settings 层已经完成“从 `fretFilter` 专用结构升级为 `positionFilter` 通用结构”的抽象
- `SettingsPanelModel` 现在已经可以表达：
- 通用 row：`.positionFilter(...)`
- 通用 option：`pitchClass(PitchClass)` / `fret(Int)`
- 通用事件：`togglePositionPromptFilterOption(...)`
- 过滤模式切换动作也已经补到 `SettingsActionID` 里：
- `setPositionPromptFilterModeNoteName`
- `setPositionPromptFilterModeFret`
- 但当前 snapshot builder 仍然只投影 `Frets` 这一行，没有把 `Note Names` UI 真正放出来；这是刻意保持与现阶段 trainer 行为一致，避免设置层先于出题链路暴露新功能

## 修改 1：把 settings row 从专用 `fretFilter` 提升为通用 `positionFilter`

### 修改前

- `Trainer` 分区只知道一条 `.fretFilter(.positionPromptFrets)`
- settings row 类型直接绑定“品位筛选”语义
- 后续如果要接入按音名过滤，只能继续叠加另一条平行特例

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsRowID, SettingsSectionID.rowIDs, SettingsFretFilterRowID
// 功能说明: 修改前 settings 层只有专用的 fretFilter row；
// Trainer 分区能表达“Position 的品位筛选”，但不能表达通用的 position filter 概念。
enum SettingsRowID: Equatable, Hashable, Sendable {
    case choice(SettingsChoiceRowID)
    case fretFilter(SettingsFretFilterRowID)
    case slider(SettingsSliderID)
    case toggle(SettingsToggleID)
}

enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
        case .trainer:
            return [
                .choice(.exerciseMode),
                .fretFilter(.positionPromptFrets)
            ]
        default:
            return []
        }
    }
}

enum SettingsFretFilterRowID: CaseIterable, Equatable, Hashable, Sendable {
    case positionPromptFrets
}
```

### 修改后

- row 类型改成 `.positionFilter(SettingsPositionFilterRowID)`
- `Trainer` 分区现在挂的是 `.positionFilter(.positionPromptFilterOptions)`
- 新增通用 option id：`pitchClass(...)` / `fret(...)`
- 这一步把“过滤类型抽象”放到了 settings 共享层，而不是继续用命名层面的 `fretFilter`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsRowID, SettingsSectionID.rowIDs, SettingsPositionFilterRowID, SettingsPositionFilterOptionID
// 功能说明: 修改后 settings 层正式引入通用 position filter row；
// 过滤项可以统一承载音名或品位，为后续切换两种过滤模式做结构准备。
enum SettingsRowID: Equatable, Hashable, Sendable {
    case choice(SettingsChoiceRowID)
    case positionFilter(SettingsPositionFilterRowID)
    case slider(SettingsSliderID)
    case toggle(SettingsToggleID)
}

enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
        case .trainer:
            return [
                .choice(.exerciseMode),
                .positionFilter(.positionPromptFilterOptions)
            ]
        default:
            return []
        }
    }
}

enum SettingsPositionFilterRowID: CaseIterable, Equatable, Hashable, Sendable {
    case positionPromptFilterOptions

    var supportedFrets: ClosedRange<Int> {
        TrainerPositionPromptConfiguration.supportedFretRange
    }

    var supportedPitchClasses: [PitchClass] {
        TrainerPositionPromptConfiguration.supportedPitchClasses
    }
}

enum SettingsPositionFilterOptionID: Equatable, Hashable, Sendable {
    case pitchClass(PitchClass)
    case fret(Int)
}
```

## 修改 2：把过滤模式切换动作与通用 option 事件接入 settings shared state

### 修改前

- `SettingsChoiceRowID` 没有 `positionPromptFilterMode`
- `SettingsActionID` 没有切换过滤模式的动作
- `SettingsPanelEvent` 只能表达 `togglePositionPromptFret(Int)`
- 也就是说，settings 层只能发出“切某个 fret”，不能表达“切过滤模式”或“切某个通用过滤项”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID, SettingsActionID, SettingsPanelEvent
// 功能说明: 修改前 settings 共享层没有过滤模式 row，也没有通用过滤 option 事件；
// 事件模型只支持 togglePositionPromptFret(Int)。
enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case exerciseMode
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef
    case pianoMovementScope
    case pianoWhiteKeyStyle
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setTopContentFretboard
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModePositionPrompt
    // ... 省略其他 action
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case togglePositionPromptFret(Int)
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)
}
```

### 修改后

- 新增 `SettingsChoiceRowID.positionPromptFilterMode`
- 新增两条动作：
- `setPositionPromptFilterModeNoteName`
- `setPositionPromptFilterModeFret`
- `SettingsPanelEvent` 改为通用的 `togglePositionPromptFilterOption(...)`
- 事件落地时会根据 option 类型分发到：
- `togglePositionPromptPitchClass(_:)`
- `togglePositionPromptFret(_:)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.positionPromptFilterMode, SettingsActionID, SettingsPanelEvent.apply(to:)
// 功能说明: 修改后 settings 层既能切过滤模式，也能通过统一 option 事件切换音名或品位；
// 共享状态的落点仍然收口在 TrainerDisplayState。
enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case exerciseMode
    case positionPromptFilterMode
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef
    case pianoMovementScope
    case pianoWhiteKeyStyle
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setTopContentFretboard
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModePositionPrompt
    case setPositionPromptFilterModeNoteName
    case setPositionPromptFilterModeFret
    // ... 省略其他 action
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case togglePositionPromptFilterOption(SettingsPositionFilterOptionID)
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)

    func apply(
        to stateContext: inout SettingsPanelStateContext
    ) {
        switch self {
        case let .triggerAction(actionID):
            actionID.apply(to: &stateContext)
        case let .togglePositionPromptFilterOption(optionID):
            switch optionID {
            case let .pitchClass(pitchClass):
                stateContext.trainerDisplayState.togglePositionPromptPitchClass(
                    pitchClass
                )
            case let .fret(fret):
                stateContext.trainerDisplayState.togglePositionPromptFret(fret)
            }
        case let .setSliderValue(sliderID, value):
            sliderID.apply(value: value, to: &stateContext)
        case let .setToggleValue(toggleID, value):
            toggleID.apply(value: value, to: &stateContext)
        }
    }
}
```

## 修改 3：把 snapshot builder 切到通用 `positionFilter`，但仍然只回显 `Frets`

### 修改前

- builder 只会构建 `.fretFilter`
- row payload 直接是 `SettingsFretFilterRow`
- 这意味着 builder 的输出类型和旧的 row 语义完全耦合

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: makeRow(id:stateContext:), makeFretFilterRow(...)
// 功能说明: 修改前 snapshot builder 只会构建专用 fretFilter row；
// 输出 payload 只能表达 1...12 的品位选项。
private static func makeRow(
    id: SettingsRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsRow? {
    switch id {
    case let .fretFilter(fretFilterRowID):
        guard shouldInclude(
            fretFilterRowID: fretFilterRowID,
            stateContext: stateContext
        ) else {
            return nil
        }

        return .fretFilter(
            makeFretFilterRow(
                id: fretFilterRowID,
                stateContext: stateContext
            )
        )
    default:
        return nil
    }
}

private static func makeFretFilterRow(
    id: SettingsFretFilterRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsFretFilterRow {
    let configuration = stateContext.trainerDisplayState.positionPromptConfiguration

    return SettingsFretFilterRow(
        id: id,
        title: id.title,
        accessibilityLabel: id.accessibilityLabel,
        frets: id.supportedFrets.map { fret in
            let isSelected = configuration.contains(fret)
            return SettingsFretFilterItem(
                fret: fret,
                title: "\(fret)",
                accessibilityLabel: "Toggle fret \(fret) for position prompt questions",
                isSelected: isSelected,
                isEnabled: !isSelected || configuration.canDeselect(fret)
            )
        }
    )
}
```

### 修改后

- builder 改成输出 `.positionFilter(...)`
- payload 改成 `SettingsPositionFilterRow`
- 但为了不提前暴露还没接好的 note-name 过滤，当前仍然只构造 `.fret(...)` option
- 也就是说，这一步完成的是“结构升级”，不是“功能完全放开”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: makeRow(id:stateContext:), makePositionFilterRow(...)
// 功能说明: 修改后 builder 已经切换到通用 positionFilter row；
// 但当前为了保持和现阶段 trainer 行为一致，仍然只回显 Frets，不提前放出 Note Names UI。
private static func makeRow(
    id: SettingsRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsRow? {
    switch id {
    case let .positionFilter(positionFilterRowID):
        guard shouldInclude(
            positionFilterRowID: positionFilterRowID,
            stateContext: stateContext
        ) else {
            return nil
        }

        return .positionFilter(
            makePositionFilterRow(
                id: positionFilterRowID,
                stateContext: stateContext
            )
        )
    default:
        return nil
    }
}

private static func makePositionFilterRow(
    id: SettingsPositionFilterRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsPositionFilterRow {
    let configuration = stateContext.trainerDisplayState.positionPromptConfiguration

    return SettingsPositionFilterRow(
        id: id,
        title: "Frets",
        accessibilityLabel: "Select the frets used when generating position prompt questions",
        options: id.supportedFrets.map { fret in
            let isSelected = configuration.contains(fret)
            return SettingsPositionFilterItem(
                id: .fret(fret),
                title: "\(fret)",
                accessibilityLabel: "Toggle fret \(fret) for position prompt questions",
                isSelected: isSelected,
                isEnabled: !isSelected || configuration.canDeselect(fret)
            )
        }
    )
}
```

## 修改 4：把 iOS / macOS 的 settings 行视图从“按 fret 编码”切到“按通用 option id 编码”

### 修改前

- 双端 `FretFilterRowView` 都用 `buttonsByFret: [Int: ...]`
- 点击事件统一发 `togglePositionPromptFret(fret)`
- 控件缓存 key 和 accessibility identifier 都是按 fret number 硬编码

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterRowView, handleFretButtonTap(_:)
// 功能说明: 修改前 iOS settings 行视图只认专用的 SettingsFretFilterRow / SettingsFretFilterItem；
// 控件缓存和点击事件都按 fret number 编码。
case let .fretFilter(item):
    let rowID = row.id
    if let existingRow = controlViewsByID[rowID] as? FretFilterRowView {
        existingRow.apply(item: item)
        return existingRow
    }

private final class FretFilterRowView: UIView {
    private var buttonsByFret: [Int: FretFilterButton] = [:]

    func apply(item: SettingsFretFilterRow) {
        removeObsoleteButtons(notIn: Set(item.frets.map(\.fret)))
    }

    @objc
    private func handleFretButtonTap(_ sender: FretFilterButton) {
        guard
            let fret = sender.fret,
            sender.isEnabled
        else {
            return
        }

        onEvent?(.togglePositionPromptFret(fret))
    }
}
```

### 修改后

- 双端 settings 行现在都吃 `SettingsPositionFilterRow`
- 按钮缓存 key 改成 `SettingsPositionFilterOptionID`
- 点击统一发 `togglePositionPromptFilterOption(optionID)`
- accessibility identifier 也切成通用 `position-filter-*`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterRowView, FretFilterButton
// 功能说明: 修改后 iOS settings 行视图已经切换到通用 position filter row；
// 这样后续只要 snapshot builder 开始投影音名 option，这一层无需再做结构性重写。
case let .positionFilter(item):
    let rowID = row.id
    if let existingRow = controlViewsByID[rowID] as? FretFilterRowView {
        existingRow.apply(item: item)
        return existingRow
    }

private final class FretFilterRowView: UIView {
    private var buttonsByOptionID: [SettingsPositionFilterOptionID: FretFilterButton] = [:]

    func apply(item: SettingsPositionFilterRow) {
        accessibilityIdentifier = "settings-panel-position-filter-row-\(String(describing: item.id))"
        removeObsoleteButtons(notIn: Set(item.options.map(\.id)))
    }

    @objc
    private func handleFretButtonTap(_ sender: FretFilterButton) {
        guard
            let optionID = sender.optionID,
            sender.isEnabled
        else {
            return
        }

        onEvent?(.togglePositionPromptFilterOption(optionID))
    }
}

private final class FretFilterButton: UIButton {
    var optionID: SettingsPositionFilterOptionID?

    func apply(item: SettingsPositionFilterItem) {
        optionID = item.id
        accessibilityIdentifier = "settings-panel-position-filter-\(item.id.accessibilityIdentifierComponent)"
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterRowView, FretFilterButton
// 功能说明: 修改后 macOS settings 行也同步切换到通用 option id 体系；
// 双端按钮缓存、点击透传和 identifier 命名保持同一抽象层级。
case let .positionFilter(item):
    let rowID = row.id
    if let existingRow = controlViewsByID[rowID] as? FretFilterRowView {
        existingRow.apply(item: item)
        return existingRow
    }

private final class FretFilterRowView: NSView {
    private var buttonsByOptionID: [SettingsPositionFilterOptionID: FretFilterButton] = [:]

    func apply(item: SettingsPositionFilterRow) {
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-position-filter-row-\(String(describing: item.id))"
        )
        removeObsoleteButtons(notIn: Set(item.options.map(\.id)))
    }

    @objc
    private func handleFretButtonTap(_ sender: FretFilterButton) {
        guard
            let optionID = sender.optionID,
            sender.isEnabled
        else {
            return
        }

        onEvent?(.togglePositionPromptFilterOption(optionID))
    }
}

private final class FretFilterButton: NSButton {
    var optionID: SettingsPositionFilterOptionID?

    func apply(item: SettingsPositionFilterItem) {
        optionID = item.id
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-position-filter-\(item.id.accessibilityIdentifierComponent)"
        )
    }
}
```

## 验证

- `ReadLints` 检查以下文件：无 linter 错误
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`

## 后续阶段衔接

- 阶段 2 到这里，settings 共享结构已经准备好，但还没有真正对外暴露 note-name filter
- 下一步应该把：
- `SettingsPanelSnapshotBuilder` 的真实投影
- `FretboardNaturalNoteTrainer` 的 `activeFilter` 出题链路
- controller 的 filter diff / session 重建
- 一起接起来，避免 UI 和出题逻辑出现前后不一致

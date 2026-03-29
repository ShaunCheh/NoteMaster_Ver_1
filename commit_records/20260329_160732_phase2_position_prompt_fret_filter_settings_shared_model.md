# 20260329_160732_phase2_position_prompt_fret_filter_settings_shared_model

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_160732`
- 记录范围：实施“Position 品位筛选”计划的阶段 2，只完成 unified settings panel 的 shared model、snapshot builder、event 接线与双端最小占位分支；不包含真正的 12 格交互 UI、不包含 shared trainer 出题过滤、不包含控制器 session 重建
- 本次目标：让设置面板共享层正式表达“仅在 `positionPrompt` 模式下显示一行 1...12 品位筛选”的结构，并把“切换某个品位”收敛成统一事件
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- `.cursor/plans/position品位筛选_cb2e8023.plan.md`

## 本次结论

- 阶段 2 完成后，设置面板共享模型已经能表达 `positionPrompt` 专属 fret-filter row，并且 row payload 已经包含 `1...12`、选中态以及“最后一个已选品不可取消”的禁用语义
- `SettingsPanelEvent` 现在可以直接表达 `togglePositionPromptFret(Int)`，后续阶段 3 的双端控件只需要发这个事件，不需要再自定义一套额外状态通道
- 本阶段仍未交付真实可点击的 12 格 UI，因此 iOS / macOS 端只补了隐藏占位分支，保证 shared model 扩容后 switch 穷举完整、界面不留下空白占位

## 修改 1：扩展 unified settings panel 的 row 类型，让 Trainer 分区能够描述 fret-filter 行

### 修改前

- `SettingsRowID` 只有 `choice / slider / toggle`
- `Trainer` 分区只有 `Exercise Mode` 这一行
- 这意味着 shared settings model 无法表达“Exercise Mode 下方再跟一行 positionPrompt 专属品位筛选”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsRowID, SettingsSectionID.rowIDs
// 功能说明: 修改前 unified settings panel 只支持 choice / slider / toggle 三类 row；
// Trainer 分区只能放 exerciseMode，shared 层还没有 fret-filter row 的建模入口。
enum SettingsRowID: Equatable, Hashable, Sendable {
    case choice(SettingsChoiceRowID)
    case slider(SettingsSliderID)
    case toggle(SettingsToggleID)
}

enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
        case .page:
            return [
                .choice(.topContent),
                .choice(.mainContent)
            ]
        case .trainer:
            return [
                .choice(.exerciseMode)
            ]
        case .fretboard:
            return [
                .choice(.instrument),
                .choice(.displayMode),
                .choice(.labels),
                .choice(.spelling),
                .choice(.octave)
            ]
        case .staff:
            return [
                .choice(.clef),
                .slider(.clefScale),
                .slider(.clefVerticalTrim),
                .slider(.clefAnchorYOffset)
            ]
        case .layout:
            return [
                .slider(.verticalHostHeightRatio)
            ]
        case .debug:
            return [
                .toggle(.showsComponentBounds)
            ]
        }
    }
}
```

### 修改后

- 新增 `SettingsFretFilterRowID.positionPromptFrets`
- `SettingsRowID` 扩展出 `.fretFilter(SettingsFretFilterRowID)`
- `Trainer` 分区的 row 顺序改成先 `Exercise Mode`，再 `positionPromptFrets`
- 这样 snapshot builder 后续就能在 shared 层生成一条真正的 fret-filter row，而不是把 12 个品位硬塞进 `SettingsActionID`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsRowID, SettingsSectionID.rowIDs, SettingsFretFilterRowID
// 功能说明: 修改后 unified settings panel 可以原生描述“positionPrompt 专用 fret-filter row”；
// Trainer 分区的 shared 结构也变成“先选模式，再配品位”。
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
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
        case .page:
            return [
                .choice(.topContent),
                .choice(.mainContent)
            ]
        case .trainer:
            return [
                .choice(.exerciseMode),
                .fretFilter(.positionPromptFrets)
            ]
        case .fretboard:
            return [
                .choice(.instrument),
                .choice(.displayMode),
                .choice(.labels),
                .choice(.spelling),
                .choice(.octave)
            ]
        case .staff:
            return [
                .choice(.clef),
                .slider(.clefScale),
                .slider(.clefVerticalTrim),
                .slider(.clefAnchorYOffset)
            ]
        case .layout:
            return [
                .slider(.verticalHostHeightRatio)
            ]
        case .debug:
            return [
                .toggle(.showsComponentBounds)
            ]
        }
    }
}

enum SettingsFretFilterRowID: CaseIterable, Equatable, Hashable, Sendable {
    case positionPromptFrets

    var sectionID: SettingsSectionID {
        switch self {
        case .positionPromptFrets:
            return .trainer
        }
    }

    var title: String {
        switch self {
        case .positionPromptFrets:
            return "Frets"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .positionPromptFrets:
            return "Select the frets used when generating position prompt questions"
        }
    }

    var supportedFrets: ClosedRange<Int> {
        switch self {
        case .positionPromptFrets:
            return TrainerPositionPromptConfiguration.supportedFretRange
        }
    }
}
```

## 修改 2：新增 fret-filter row payload 与事件，让 settings shared state 能直接表达“切换某个品位”

### 修改前

- `SettingsPanelModel` 只能按 `choice / slider / toggle` 取 row
- 没有 `SettingsFretFilterItem` / `SettingsFretFilterRow`
- `SettingsPanelEvent` 也没有与“切换某个 fret”直接对应的事件
- 结果是即使阶段 1 已经有 `TrainerPositionPromptConfiguration`，设置面板层仍然没有办法把它结构化地暴露出来

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsPanelModel, SettingsRow, SettingsPanelEvent
// 功能说明: 修改前 SettingsPanelModel 只能查询 choice / slider / toggle；
// SettingsPanelEvent 也不能表达“切换 positionPrompt 的某个 fret”。
enum SettingsRow: Equatable, Sendable {
    case choice(SettingsChoiceRow)
    case slider(SettingsSliderRow)
    case toggle(SettingsToggleRow)

    var id: SettingsRowID {
        switch self {
        case let .choice(row):
            return .choice(row.id)
        case let .slider(row):
            return .slider(row.id)
        case let .toggle(row):
            return .toggle(row.id)
        }
    }
}

struct SettingsPanelModel: Equatable, Sendable {
    var sections: [SettingsSection]

    static let empty = SettingsPanelModel(sections: [])

    var rows: [SettingsRow] {
        sections.flatMap(\.rows)
    }

    func choiceRow(for id: SettingsChoiceRowID) -> SettingsChoiceRow? { /* ... */ }
    func sliderRow(for id: SettingsSliderID) -> SettingsSliderRow? { /* ... */ }
    func toggleRow(for id: SettingsToggleID) -> SettingsToggleRow? { /* ... */ }
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)
}
```

### 修改后

- 新增 `SettingsFretFilterItem` 与 `SettingsFretFilterRow`
- `SettingsRow` 增加 `.fretFilter`
- `SettingsPanelModel` 新增 `fretFilterRow(for:)`
- `SettingsPanelEvent` 新增 `togglePositionPromptFret(Int)`，并在 `apply(to:)` 中直接落到 `trainerDisplayState.togglePositionPromptFret(_:)`
- 这样阶段 3 的双端控件只负责发 `togglePositionPromptFret(fret)`，共享状态更新逻辑继续收口在 shared 层

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsFretFilterItem, SettingsFretFilterRow,
// SettingsRow.fretFilter, SettingsPanelModel.fretFilterRow(for:),
// SettingsPanelEvent.togglePositionPromptFret(_:), SettingsPanelEvent.apply(to:)
// 功能说明: 修改后 settings shared model 已经拥有 fret-filter row payload；
// UI 层可以读到 1...12 的显示数据，也可以把点击动作收口成统一的 toggle 事件。
struct SettingsFretFilterItem: Equatable, Hashable, Sendable {
    var fret: Int
    var title: String
    var accessibilityLabel: String
    var isSelected: Bool
    var isEnabled: Bool
}

struct SettingsFretFilterRow: Equatable, Sendable {
    var id: SettingsFretFilterRowID
    var title: String
    var accessibilityLabel: String
    var frets: [SettingsFretFilterItem]
}

enum SettingsRow: Equatable, Sendable {
    case choice(SettingsChoiceRow)
    case fretFilter(SettingsFretFilterRow)
    case slider(SettingsSliderRow)
    case toggle(SettingsToggleRow)

    var id: SettingsRowID {
        switch self {
        case let .choice(row):
            return .choice(row.id)
        case let .fretFilter(row):
            return .fretFilter(row.id)
        case let .slider(row):
            return .slider(row.id)
        case let .toggle(row):
            return .toggle(row.id)
        }
    }
}

struct SettingsPanelModel: Equatable, Sendable {
    var sections: [SettingsSection]

    static let empty = SettingsPanelModel(sections: [])

    var rows: [SettingsRow] {
        sections.flatMap(\.rows)
    }

    func fretFilterRow(for id: SettingsFretFilterRowID) -> SettingsFretFilterRow? {
        rows.compactMap { row in
            guard case let .fretFilter(fretFilterRow) = row else {
                return nil
            }

            return fretFilterRow
        }.first { $0.id == id }
    }
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case togglePositionPromptFret(Int)
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)

    func apply(
        to stateContext: inout SettingsPanelStateContext
    ) {
        switch self {
        case let .triggerAction(actionID):
            actionID.apply(to: &stateContext)
        case let .togglePositionPromptFret(fret):
            stateContext.trainerDisplayState.togglePositionPromptFret(fret)
        case let .setSliderValue(sliderID, value):
            sliderID.apply(value: value, to: &stateContext)
        case let .setToggleValue(toggleID, value):
            toggleID.apply(value: value, to: &stateContext)
        }
    }
}
```

## 修改 3：在 snapshot builder 里把 positionPrompt 专属 row 真正构建出来

### 修改前

- `SettingsPanelSnapshotBuilder.makeRow(...)` 只认识 `choice / slider / toggle`
- builder 没有地方判断 `isPositionPromptMode`
- 也没有地方把阶段 1 的 `positionPromptConfiguration` 转换成“12 个格子”的快照数据

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: makeRow(id:stateContext:), shouldInclude(sliderID:stateContext:)
// 功能说明: 修改前 snapshot builder 没有 fret-filter row 分支；
// 因此即使 TrainerDisplayState 已有 selectedFrets，共享快照里仍然生成不出对应设置行。
private static func makeRow(
    id: SettingsRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsRow? {
    switch id {
    case let .choice(choiceRowID):
        return .choice(
            makeChoiceRow(
                id: choiceRowID,
                stateContext: stateContext
            )
        )
    case let .slider(sliderID):
        guard shouldInclude(
            sliderID: sliderID,
            stateContext: stateContext
        ) else {
            return nil
        }

        return .slider(
            makeSliderRow(
                id: sliderID,
                stateContext: stateContext
            )
        )
    case let .toggle(toggleID):
        return .toggle(
            makeToggleRow(
                id: toggleID,
                stateContext: stateContext
            )
        )
    }
}
```

### 修改后

- `makeRow(...)` 增加 `.fretFilter` 分支
- 新增 `makeFretFilterRow(...)`
- 新增 `shouldInclude(fretFilterRowID:stateContext:)`
- 只有 `stateContext.trainerDisplayState.isPositionPromptMode == true` 时才返回这行
- row payload 中每个 fret 的 `isEnabled` 都按 `!isSelected || configuration.canDeselect(fret)` 计算
- 这一步把“最后一个已选品位不可取消”的 shared 约束，正式投影成设置面板快照语义

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: makeRow(id:stateContext:), makeFretFilterRow(id:stateContext:),
// shouldInclude(fretFilterRowID:stateContext:)
// 功能说明: 修改后 snapshot builder 会在 positionPrompt 模式下生成 fret-filter row；
// row payload 同时带出每个 fret 的选中态与禁用态，供双端 UI 做统一回显。
private static func makeRow(
    id: SettingsRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsRow? {
    switch id {
    case let .choice(choiceRowID):
        return .choice(
            makeChoiceRow(
                id: choiceRowID,
                stateContext: stateContext
            )
        )
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
    case let .slider(sliderID):
        guard shouldInclude(
            sliderID: sliderID,
            stateContext: stateContext
        ) else {
            return nil
        }

        return .slider(
            makeSliderRow(
                id: sliderID,
                stateContext: stateContext
            )
        )
    case let .toggle(toggleID):
        return .toggle(
            makeToggleRow(
                id: toggleID,
                stateContext: stateContext
            )
        )
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

private static func shouldInclude(
    fretFilterRowID: SettingsFretFilterRowID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch fretFilterRowID {
    case .positionPromptFrets:
        return stateContext.trainerDisplayState.isPositionPromptMode
    }
}
```

## 修改 4：给双端 settings panel 先补隐藏占位分支，保证 shared 模型扩容后平台层仍然稳定

### 修改前

- iOS / macOS 的 `controlView(for:)` 都只处理 `choice / slider / toggle`
- 一旦 shared 的 `SettingsRow` 新增 `.fretFilter`，平台层如果不跟着扩充 switch 分支，就会缺少穷举处理
- 但阶段 2 还不打算实现真实 12 格 UI，因此需要一个“先编译稳定、界面不出空白”的最小占位方案

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: controlView(for:)
// 功能说明: 修改前 iOS settings panel 只处理 choice / slider / toggle；
// shared 层新增 fretFilter 后，平台层还没有对应的 row view。
private func controlView(for row: SettingsRow) -> UIView {
    switch row {
    case let .choice(item):
        // ...
    case let .slider(item):
        // ...
    case let .toggle(item):
        // ...
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: controlView(for:)
// 功能说明: 修改前 macOS settings panel 也只处理 choice / slider / toggle；
// 还没有对应 fret-filter row 的平台分支。
private func controlView(for row: SettingsRow) -> NSView {
    switch row {
    case let .choice(item):
        // ...
    case let .slider(item):
        // ...
    case let .toggle(item):
        // ...
    }
}
```

### 修改后

- iOS / macOS 都增加了 `.fretFilter` 分支
- 本阶段先挂 `FretFilterPlaceholderRowView`
- 占位 view 会带上稳定的 accessibility identifier，但自身隐藏，不参与交互
- macOS 额外把 `rowsStackView.detachesHiddenViews = true` 打开，确保隐藏占位不会留下可见空白间距
- 这让阶段 2 可以先完成 shared model 接线，真实 12 格控件留到阶段 3 实现

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterPlaceholderRowView.apply(item:)
// 功能说明: 修改后 iOS 端先用隐藏占位 view 承接 fret-filter row；
// 这样 shared 模型扩容后平台层仍可稳定编译，且界面不会提前出现错误占位。
private func controlView(for row: SettingsRow) -> UIView {
    switch row {
    case let .choice(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ChoiceRowView {
            existingRow.apply(item: item)
            return existingRow
        }
        // ...
    case let .fretFilter(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? FretFilterPlaceholderRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = FretFilterPlaceholderRowView()
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    case let .slider(item):
        // ...
    case let .toggle(item):
        // ...
    }
}

private final class FretFilterPlaceholderRowView: UIView {
    override var intrinsicContentSize: CGSize {
        .zero
    }

    func apply(item: SettingsFretFilterRow) {
        accessibilityIdentifier = "settings-panel-fret-filter-row-\(String(describing: item.id))"
        isUserInteractionEnabled = false
        isHidden = true
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterPlaceholderRowView.apply(item:), SectionView.configureView()
// 功能说明: 修改后 macOS 端同样先接入隐藏占位 row；
// 并通过 detachesHiddenViews 避免隐藏行在 stack view 中留下布局空隙。
private func controlView(for row: SettingsRow) -> NSView {
    switch row {
    case let .choice(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ChoiceRowView {
            existingRow.apply(item: item)
            return existingRow
        }
        // ...
    case let .fretFilter(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? FretFilterPlaceholderRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = FretFilterPlaceholderRowView(frame: .zero)
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    case let .slider(item):
        // ...
    case let .toggle(item):
        // ...
    }
}

private final class FretFilterPlaceholderRowView: NSView {
    override var intrinsicContentSize: NSSize {
        .zero
    }

    func apply(item: SettingsFretFilterRow) {
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-fret-filter-row-\(String(describing: item.id))"
        )
        isHidden = true
    }
}

private func configureView() {
    rowsStackView.orientation = .vertical
    rowsStackView.alignment = .leading
    rowsStackView.distribution = .fill
    rowsStackView.detachesHiddenViews = true
    rowsStackView.spacing = Style.rowSpacing
}
```

## 修改 5：同步计划状态，标记阶段 2 完成

### 修改前

- `phase2-settings-model` 还处于未完成状态
- 计划文件尚未体现 shared settings model 已经接线完毕

```md
<!-- 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md -->
<!-- 函数名/符号: todo item phase2-settings-model -->
<!-- 功能说明: 修改前计划文件还没有把阶段 2 标记为完成。 -->
- id: phase2-settings-model
  content: 扩展 SettingsPanelModel / SnapshotBuilder / Event，新增只在 positionPrompt 下显示的 fret-filter row 与 toggle fret 事件
  status: pending
```

### 修改后

- `phase2-settings-model` 已标记为 `completed`
- 计划文件与当前代码状态保持一致，后续可以直接推进阶段 3

```md
<!-- 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md -->
<!-- 函数名/符号: todo item phase2-settings-model -->
<!-- 功能说明: 修改后计划文件已确认阶段 2 完成，下一步可进入双端 12 格 UI 实现。 -->
- id: phase2-settings-model
  content: 扩展 SettingsPanelModel / SnapshotBuilder / Event，新增只在 positionPrompt 下显示的 fret-filter row 与 toggle fret 事件
  status: completed
```

## 验证情况

- 已对本次改动的 4 个 Swift 文件执行静态诊断，`ReadLints` 未发现新增问题
- 本阶段没有运行 `xcodebuild`；原因不是本次任务失败，而是这一轮记录工作只需要同步阶段 2 的代码与计划状态
- 当前行为符合阶段边界：
- shared 层已经能构建 fret-filter row
- 平台层已补穷举分支且不会留下可见空行
- 真正的 12 格交互控件仍留在阶段 3

# 20260330_130618_piano_settings_panel_integration

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_130618`
- 记录范围：将钢琴 demo 的控制项接入现有 `SettingsPanel`，支持键盘是否显示、控制键盘行数、是否级联、拖动是否吸附
- 本次目标：复用现有 `SettingsPanel` shared schema 与双平台 settings view，不新增独立 `PianoControlPanelView`；通过 shared piano panel state + projection，把面板状态统一投影到 `PianoConfiguration` 和 `rows`
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`

## 本次结论

- 修改前，钢琴 demo 仍然是控制器里一段“固定配置 + 固定 rows”的独立演示区
- 现有 `SettingsPanel` 没有任何 piano 相关 section，也没有状态入口去驱动 piano demo
- 修改后，钢琴控制项直接并入现有 `SettingsPanel`，新增一个 `Piano` section，支持：
- `Visible`
- `Rows`
- `Row Linking`
- `Snap Drag`
- 同时没有把控制面板逻辑塞进 `PianoKeyboardView`
- 而是新增了 shared 的 `PianoPanelState + PianoPanelProjection`：
- `SettingsPanel` 只负责改 panel state
- 控制器再把 panel state 投影成最终传给 piano view 的 `configuration` 和 `rows`
- 这样 iOS/macOS 两个平台复用同一套规则，避免控制器各自复制“增减行数 / 统一 movementScope / 吸附开关”逻辑

## 修改前总体现状

- 修改前，钢琴 demo 已经接到了两个控制器底部
- 但控制方式仍然是控制器内部固定写死：
- `pianoDemoConfiguration`
- `pianoDemoRows`
- `applyPianoDemoState()` 直接把这两份数据塞给 `PianoKeyboardView`
- 现有 `SettingsPanelStateContext` 也没有任何 piano 状态，因此 settings panel 无法参与钢琴 demo 的控制

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名/符号: SettingsPanelStateContext
// 功能说明: 修改前 settings panel context 只覆盖 fretboard / staff / page / trainer，没有 piano 状态入口。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var trainerDisplayState: TrainerDisplayState

    static let `default` = SettingsPanelStateContext()

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState = .default,
        trainerDisplayState: TrainerDisplayState = .default
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.pageDisplayState = pageDisplayState
        self.trainerDisplayState = trainerDisplayState
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: pianoDemoConfiguration, pianoDemoRows, applyPianoDemoState()
// 功能说明: 修改前 iOS 控制器直接维护一份固定配置和固定 rows，settings panel 无法控制钢琴 demo。
private let pianoDemoConfiguration = iOSViewController.initialPianoDemoConfiguration
private var pianoDemoRows = iOSViewController.initialPianoDemoRows

private func applyPianoDemoState() {
    pianoKeyboardView.configuration = pianoDemoConfiguration
    pianoKeyboardView.rows = pianoDemoRows
    pianoKeyboardView.showsComponentBoundsOverlay = false
    updatePianoDemoStatusLabel()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsSectionID, SettingsChoiceRowID, SettingsToggleID, SettingsSliderID
// 功能说明: 修改前 settings panel schema 里没有 Piano section，也没有显示/行数/级联/吸附相关控件定义。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case debug
}

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
}

enum SettingsToggleID: CaseIterable, Equatable, Hashable, Sendable {
    case showsComponentBounds
}

enum SettingsSliderID: CaseIterable, Equatable, Hashable, Sendable {
    case clefScale
    case clefVerticalTrim
    case clefAnchorYOffset
    case verticalHostHeightRatio
}
```

## 修改 1：新增 shared 的 `PianoPanelState` 与投影 helper

### 修改前

- 修改前，没有一个独立的 piano 控制面板状态模型
- “是否显示 / 行数 / 级联 / 吸附”如果直接做，会被迫散落在两个控制器里
- 也没有一个共享的行数投影策略来决定：
- 少行时怎么截断
- 多行时怎么补行
- movementScope 怎么统一覆盖

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelState, PianoPanelProjection
// 功能说明: 修改前该文件不存在，Shared/Piano 里没有专门承载控制面板状态和投影规则的纯函数层。
(无代码)
```

### 修改后

- 新增 `PianoPanelState.swift`
- `PianoPanelState` 明确承载：
- `isVisible`
- `rowCount`
- `movementScope`
- `snapEnabled`
- `PianoPanelProjection` 统一把 panel state 投影成：
- `resolvedConfiguration(...)`
- `resolvedRows(...)`
- 规则也收口到 shared：
- 行数钳制为 `1...8`
- 缩行用 `prefix`
- 扩行按最后一行每次 `-12` 半音追加
- 统一覆盖所有行的 `movementScope`
- 吸附开关只改 `configuration.snapEnabled`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelState, PianoPanelProjection.resolvedConfiguration(...), PianoPanelProjection.resolvedRows(...)
// 功能说明: 新增一个 shared piano 控制面板状态与投影层，把 UI 面板状态稳定映射到 configuration 和 rows。
struct PianoPanelState: Equatable, Sendable {
    static let supportedRowCountRange: ClosedRange<Int> = 1...8

    var isVisible: Bool
    var rowCount: Int
    var movementScope: PianoMovementScope
    var snapEnabled: Bool

    var resolvedRowCount: Int {
        min(
            max(rowCount, Self.supportedRowCountRange.lowerBound),
            Self.supportedRowCountRange.upperBound
        )
    }

    static func inferred(
        configuration: PianoConfiguration,
        rows: [PianoRowState]
    ) -> PianoPanelState {
        PianoPanelState(
            isVisible: true,
            rowCount: min(
                max(rows.count, Self.supportedRowCountRange.lowerBound),
                Self.supportedRowCountRange.upperBound
            ),
            movementScope: rows.first?.movementScope ?? .cascade,
            snapEnabled: configuration.snapEnabled
        )
    }
}

enum PianoPanelProjection {
    static func resolvedConfiguration(
        from baseConfiguration: PianoConfiguration,
        panelState: PianoPanelState
    ) -> PianoConfiguration {
        var configuration = baseConfiguration
        configuration.snapEnabled = panelState.snapEnabled
        return configuration
    }

    static func resolvedRows(
        from baseRows: [PianoRowState],
        panelState: PianoPanelState
    ) -> [PianoRowState] {
        let targetRowCount = panelState.resolvedRowCount
        let scopedRows = rowsApplyingMovementScope(
            to: baseRows,
            movementScope: panelState.movementScope
        )

        if scopedRows.count > targetRowCount {
            return Array(scopedRows.prefix(targetRowCount))
        }

        var expandedRows = scopedRows
        while expandedRows.count < targetRowCount {
            expandedRows.append(
                appendedRow(
                    after: expandedRows.last,
                    movementScope: panelState.movementScope
                )
            )
        }
        return expandedRows
    }
}
```

## 修改 2：把 piano panel state 接进现有 SettingsPanel shared context

### 修改前

- 修改前，`SettingsPanelStateContext` 没有 piano 状态字段
- 因此 `SettingsPanelSnapshotBuilder` 和 `SettingsPanelEvent.apply(to:)` 都无法构建或修改 piano 相关行

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名/符号: SettingsPanelStateContext.init(...)
// 功能说明: 修改前 context 不知道 piano panel state 的存在。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var trainerDisplayState: TrainerDisplayState
}
```

### 修改后

- `SettingsPanelStateContext` 新增 `pianoPanelState`
- 默认值是 `.init()`
- 这样 settings panel 的整个 shared builder / event apply 链都能访问 piano 控制态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名/符号: SettingsPanelStateContext.init(...)
// 功能说明: 修改后把 pianoPanelState 纳入 settings panel 的统一状态上下文，作为 snapshot 和 event apply 的输入。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState

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

## 修改 3：扩展 `SettingsPanel` schema，新增 `Piano` section 与 4 个控件

### 修改前

- 修改前，settings panel 只有：
- `Page`
- `Trainer`
- `Fretboard`
- `Staff`
- `Layout`
- `Debug`
- 没有 piano section，也没有：
- 行数 slider
- 级联 segmented row
- 显示 toggle
- 吸附 toggle

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsSectionID, SettingsSectionID.rowIDs
// 功能说明: 修改前 settings panel 没有 Piano 分组，因此 UI 根本不会生成钢琴控制项。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case debug
}

var rowIDs: [SettingsRowID] {
    switch self {
    case .layout:
        return [
            .slider(.verticalHostHeightRatio)
        ]
    case .debug:
        return [
            .toggle(.showsComponentBounds)
        ]
    // ... 其余 section 省略
    }
}
```

### 修改后

- `SettingsSectionID` 新增 `.piano`
- `SettingsChoiceRowID` 新增 `.pianoMovementScope`
- `SettingsActionID` 新增：
- `.setPianoMovementScopeCascade`
- `.setPianoMovementScopeRowOnly`
- `SettingsToggleID` 新增：
- `.pianoVisible`
- `.pianoSnapEnabled`
- `SettingsSliderID` 新增：
- `.pianoRowCount`
- 这些项全部复用现有 `.choice / .slider / .toggle` 行类型，所以平台 settings view 不需要新增 row view 类

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsSectionID, SettingsSectionID.rowIDs, SettingsChoiceRowID, SettingsActionID, SettingsToggleID, SettingsSliderID
// 功能说明: 修改后把钢琴控制项并入现有 SettingsPanel shared schema，完全复用通用 row 类型。
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
        // ... 其余 section 保持原样
        case .piano:
            return [
                .toggle(.pianoVisible),
                .slider(.pianoRowCount),
                .choice(.pianoMovementScope),
                .toggle(.pianoSnapEnabled)
            ]
        case .debug:
            return [
                .toggle(.showsComponentBounds)
            ]
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    // ... 原有 case 保持不变
    case pianoMovementScope
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    // ... 原有 case 保持不变
    case setPianoMovementScopeCascade
    case setPianoMovementScopeRowOnly
}

enum SettingsToggleID: CaseIterable, Equatable, Hashable, Sendable {
    case showsComponentBounds
    case pianoVisible
    case pianoSnapEnabled
}

enum SettingsSliderID: CaseIterable, Equatable, Hashable, Sendable {
    // ... 原有 slider 保持不变
    case pianoRowCount
}
```

## 修改 4：让 SettingsPanel 事件真正更新 piano panel state

### 修改前

- 修改前，`SettingsPanelEvent.apply(to:)` 最终只会把 action / slider / toggle 落到：
- `fretboardDisplayState`
- `staffDisplayState`
- `pageDisplayState`
- `trainerDisplayState`
- 不可能修改 piano demo 的控制态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsActionID.apply(to stateContext:), SettingsPanelEvent.apply(to:)
// 功能说明: 修改前 settings panel event 只会落到 fretboard/staff/page/trainer 四类状态。
func apply(to stateContext: inout SettingsPanelStateContext) {
    apply(to: &stateContext.fretboardDisplayState)
    apply(to: &stateContext.staffDisplayState)
    apply(to: &stateContext.pageDisplayState)
    apply(to: &stateContext.trainerDisplayState)
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case togglePositionPromptFret(Int)
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)
}
```

### 修改后

- 新增了 `apply(to pianoPanelState:)`
- `SettingsActionID` 可以更新 `movementScope`
- `SettingsToggleID` 可以更新 `isVisible` 和 `snapEnabled`
- `SettingsSliderID` 可以更新 `rowCount`
- 最终 `SettingsPanelEvent.apply(to:)` 通过 `stateContext.pianoPanelState` 接入钢琴控制态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsActionID.apply(to pianoPanelState:), SettingsToggleID.apply(value:to:), SettingsSliderID.apply(value:to:), SettingsActionID.apply(to stateContext:)
// 功能说明: 修改后 settings panel event 已经可以直接修改 pianoPanelState，由控制器后续投影到 piano view。
func apply(to pianoPanelState: inout PianoPanelState) {
    switch self {
    case .setPianoMovementScopeCascade:
        pianoPanelState.movementScope = .cascade
    case .setPianoMovementScopeRowOnly:
        pianoPanelState.movementScope = .rowOnly
    default:
        return
    }
}

func apply(
    value: Bool,
    to stateContext: inout SettingsPanelStateContext
) {
    switch self {
    case .pianoVisible:
        stateContext.pianoPanelState.isVisible = value
    case .pianoSnapEnabled:
        stateContext.pianoPanelState.snapEnabled = value
    case .showsComponentBounds:
        apply(value: value, to: &stateContext.fretboardDisplayState)
        apply(value: value, to: &stateContext.staffDisplayState)
    }
}

func apply(
    value: CGFloat,
    to stateContext: inout SettingsPanelStateContext
) {
    switch self {
    case .pianoRowCount:
        stateContext.pianoPanelState.rowCount = Int(clampedValue(value).rounded())
    default:
        apply(value: value, to: &stateContext.fretboardDisplayState)
        apply(value: value, to: &stateContext.staffDisplayState)
    }
}

func apply(to stateContext: inout SettingsPanelStateContext) {
    apply(to: &stateContext.fretboardDisplayState)
    apply(to: &stateContext.staffDisplayState)
    apply(to: &stateContext.pageDisplayState)
    apply(to: &stateContext.trainerDisplayState)
    apply(to: &stateContext.pianoPanelState)
}
```

## 修改 5：`SettingsPanelSnapshotBuilder` 接受新的 piano slider

### 修改前

- 修改前，`SettingsPanelSnapshotBuilder.shouldInclude(sliderID:...)` 只认识：
- `verticalHostHeightRatio`
- `clefScale`
- `clefVerticalTrim`
- `clefAnchorYOffset`
- 因此就算 schema 里新增 `pianoRowCount`，snapshot builder 也会把它漏掉

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: shouldInclude(sliderID:stateContext:)
// 功能说明: 修改前 slider inclusion 逻辑不认识 pianoRowCount。
private static func shouldInclude(
    sliderID: SettingsSliderID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch sliderID {
    case .verticalHostHeightRatio:
        return stateContext.fretboardDisplayState.displayMode == .vertical
    case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
        return true
    }
}
```

### 修改后

- `pianoRowCount` 现在会稳定出现在 snapshot 里
- 平台 settings panel view 因为已经支持通用 slider row，所以无需新增 platform view 类型

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: shouldInclude(sliderID:stateContext:)
// 功能说明: 修改后 pianoRowCount 会参与 snapshot 构建，从而自动出现在双平台 settings panel 中。
private static func shouldInclude(
    sliderID: SettingsSliderID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch sliderID {
    case .verticalHostHeightRatio:
        return stateContext.fretboardDisplayState.displayMode == .vertical
    case .pianoRowCount:
        return true
    case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
        return true
    }
}
```

## 修改 6：双平台控制器改为“base + panel state + projection”

### 修改前

- 修改前，iOS / macOS 控制器都是：
- 维护一份固定 `pianoDemoConfiguration`
- 维护一份固定 `pianoDemoRows`
- `settingsPanelStateContext` 不包含 piano 状态
- `applyPianoDemoState()` 也没有投影层
- 因此 settings panel 改不了 piano demo

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: pianoDemoConfiguration, pianoDemoRows, settingsPanelStateContext, applyPianoDemoState()
// 功能说明: 修改前 macOS 控制器与 iOS 一样，钢琴 demo 仍是“固定配置 + 固定 rows”的独立演示块。
private let pianoDemoConfiguration = macOSViewController.initialPianoDemoConfiguration
private var pianoDemoRows = macOSViewController.initialPianoDemoRows

private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState,
        trainerDisplayState: trainerDisplayState
    )
}

private func applyPianoDemoState() {
    pianoKeyboardView.configuration = pianoDemoConfiguration
    pianoKeyboardView.rows = pianoDemoRows
    pianoKeyboardView.showsComponentBoundsOverlay = false
    updatePianoDemoStatusLabel()
}
```

### 修改后

- iOS / macOS 两个平台都新增：
- `pianoBaseConfiguration`
- `pianoBaseRows`
- `pianoPanelState`
- `resolvedPianoDemoConfiguration`
- `resolvedPianoDemoRows`
- `settingsPanelStateContext` 也把 `pianoPanelState` 暴露出去
- `applyPianoDemoState()` 改成“先投影，再更新 view”
- `handlePianoDemoRowsChanged(_:)` 不再直接回写 `pianoDemoRows`，而是回写 `pianoBaseRows`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: pianoBaseConfiguration, pianoBaseRows, pianoPanelState, settingsPanelStateContext, resolvedPianoDemoConfiguration, resolvedPianoDemoRows
// 功能说明: 修改后 iOS 控制器把钢琴 demo 改成“base state + panel state + projection”的结构，settings panel 可以通过 shared context 驱动 piano。
private let pianoBaseConfiguration = iOSViewController.initialPianoDemoConfiguration
private var pianoBaseRows = iOSViewController.initialPianoDemoRows
private var pianoPanelState = PianoPanelState.inferred(
    configuration: iOSViewController.initialPianoDemoConfiguration,
    rows: iOSViewController.initialPianoDemoRows
)

private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: pianoPanelState
    )
}

private var resolvedPianoDemoConfiguration: PianoConfiguration {
    PianoPanelProjection.resolvedConfiguration(
        from: pianoBaseConfiguration,
        panelState: pianoPanelState
    )
}

private var resolvedPianoDemoRows: [PianoRowState] {
    PianoPanelProjection.resolvedRows(
        from: pianoBaseRows,
        panelState: pianoPanelState
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: applyPianoDemoState(), handlePianoDemoRowsChanged(_:)
// 功能说明: 修改后 macOS 控制器与 iOS 共享同一套 panel projection 语义，不再各自手写 rows/configuration 变换规则。
private func applyPianoDemoState() {
    pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
    pianoKeyboardView.rows = resolvedPianoDemoRows
    pianoKeyboardView.showsComponentBoundsOverlay = false
    pianoDemoContainerView.isHidden = !pianoPanelState.isVisible
    pianoDemoBottomToContentConstraint?.isActive = pianoPanelState.isVisible
    mainContentBottomToContentConstraint?.isActive = !pianoPanelState.isVisible
    updatePianoDemoStatusLabel()
}

private func handlePianoDemoRowsChanged(_ rows: [PianoRowState]) {
    pianoBaseRows = rows
    pianoDemoLastEventText = "rowsChanged"
    print("[PianoDemo][macOS] rowsChanged \(pianoDemoRowsSummaryText(rows))")
    applyPianoDemoState()
}
```

## 修改 7：双平台布局从“固定由 piano demo 收口”改成“显示/隐藏双收口”

### 修改前

- 修改前，scroll content 的底部始终由 `pianoDemoContainerView` 收口
- 这意味着单纯设置 `isHidden = true` 不能完整表达“键盘不显示”
- 因为隐藏后仍然会有底部布局残留

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: configureLayout()
// 功能说明: 修改前 contentView.bottom 固定由 pianoDemoContainerView 收口，没有为“隐藏钢琴 demo”预留替代收口约束。
pianoDemoContainerView.topAnchor.constraint(
    equalTo: mainContentHostView.bottomAnchor,
    constant: Layout.verticalSpacing
),
pianoDemoContainerView.leadingAnchor.constraint(
    equalTo: contentView.leadingAnchor,
    constant: Layout.horizontalInset
),
pianoDemoContainerView.trailingAnchor.constraint(
    equalTo: contentView.trailingAnchor,
    constant: -Layout.horizontalInset
),
pianoDemoContainerView.bottomAnchor.constraint(
    equalTo: contentView.bottomAnchor,
    constant: -Layout.bottomInset
),
```

### 修改后

- 双平台都新增了两组底部约束：
- `pianoDemoBottomToContentConstraint`
- `mainContentBottomToContentConstraint`
- 显示钢琴时由 piano demo 收口
- 隐藏钢琴时改由 `mainContentHostView` 收口
- 这比单纯 `isHidden` 更符合当前滚动页面的约束结构

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: configureLayout(), applyPianoDemoState()
// 功能说明: 修改后 iOS 底部约束可以在“显示钢琴 demo”和“隐藏钢琴 demo”两种布局之间切换。
private var pianoDemoBottomToContentConstraint: NSLayoutConstraint?
private var mainContentBottomToContentConstraint: NSLayoutConstraint?

pianoDemoBottomToContentConstraint = pianoDemoContainerView.bottomAnchor.constraint(
    equalTo: contentView.bottomAnchor,
    constant: -Layout.bottomInset
)
mainContentBottomToContentConstraint = mainContentHostView.bottomAnchor.constraint(
    equalTo: contentView.bottomAnchor,
    constant: -Layout.bottomInset
)

private func applyPianoDemoState() {
    pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
    pianoKeyboardView.rows = resolvedPianoDemoRows
    pianoKeyboardView.showsComponentBoundsOverlay = false
    pianoDemoContainerView.isHidden = !pianoPanelState.isVisible
    pianoDemoBottomToContentConstraint?.isActive = pianoPanelState.isVisible
    mainContentBottomToContentConstraint?.isActive = !pianoPanelState.isVisible
    updatePianoDemoStatusLabel()
}
```

## 修改 8：状态文本与 validation 同步支持 piano panel

### 修改前

- 修改前，piano demo 状态文本只显示：
- `event`
- `preview`
- `rows`
- 没有 `panel` 维度的信息
- 同时 `PianoValidationRunner` 也没有覆盖任何 piano panel projection 规则

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: pianoDemoStatusText()
// 功能说明: 修改前状态文本无法直接看出 visible / rowCount / movementScope / snapEnabled 的控制面板结果。
return [
    "event: \(pianoDemoLastEventText)",
    "preview: \(previewText)",
    "rows: \(pianoDemoRowsSummaryText(pianoDemoRows))"
].joined(separator: "\n")
```

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: validatePianoPanelStateInferenceAndClamp(), validatePianoPanelProjectionResolution()
// 功能说明: 修改前不存在这两组 panel projection 夹具。
(无代码)
```

### 修改后

- 状态文本增加 `panel: ...`
- `PianoValidationRunner` 新增两组 focused fixtures：
- `piano_panel_state_infers_and_clamps_supported_values`
- `piano_panel_projection_resolves_rows_and_configuration`
- 这些夹具覆盖了：
- `rowCount` 推断与钳制
- `movementScope` 继承
- `snapEnabled` 投影
- 扩行 `-12 semitones`
- fallback rows

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: pianoDemoStatusText()
// 功能说明: 修改后状态文本直接展示当前 panel 投影结果，便于页面级调试钢琴控制面板。
return [
    "event: \(pianoDemoLastEventText)",
    "preview: \(previewText)",
    "panel: visible=\(pianoPanelState.isVisible) rows=\(resolvedPianoDemoRows.count) scope=\(pianoPanelState.movementScope.debugName) snap=\(resolvedPianoDemoConfiguration.snapEnabled)",
    "rows: \(pianoDemoRowsSummaryText(resolvedPianoDemoRows))"
].joined(separator: "\n")
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures(), validatePianoPanelStateInferenceAndClamp(), validatePianoPanelProjectionResolution()
// 功能说明: 修改后 validation runner 增加 piano panel 相关的 shared 夹具，覆盖行数/级联/吸附投影规则。
static func makeFixtures() -> [PianoValidationFixture] {
    [
        PianoValidationFixture(
            name: "configuration_resolves_safe_metrics",
            validate: validateConfigurationResolvesSafeMetrics
        ),
        PianoValidationFixture(
            name: "piano_panel_state_infers_and_clamps_supported_values",
            validate: validatePianoPanelStateInferenceAndClamp
        ),
        PianoValidationFixture(
            name: "piano_panel_projection_resolves_rows_and_configuration",
            validate: validatePianoPanelProjectionResolution
        ),
        // ... 其余已有 piano fixtures 保持不变
    ]
}

static func validatePianoPanelStateInferenceAndClamp() -> [PianoValidationIssue] {
    let inferred = PianoPanelState.inferred(
        configuration: PianoConfiguration(snapEnabled: false),
        rows: [
            PianoRowState(
                startNote: NotePitch(pitchClass: .c, octave: 5),
                movementScope: .rowOnly
            ),
            PianoRowState(
                startNote: NotePitch(pitchClass: .c, octave: 4),
                movementScope: .cascade
            )
        ]
    )
    // ... 校验 inferred rowCount / movementScope / snapEnabled 和上界钳制
}
```

## 本次没有改动的部分

- `iOSSettingsPanelView` / `macOSSettingsPanelView` 没有改
- 原因是本次新增控件完全复用已有 `.choice / .slider / .toggle` 行类型
- `iOSPianoKeyboardView` / `macOSPianoKeyboardView` 也没有改
- 原因是它们已经支持外部替换 `rows` 并做 sanitation，这次只需要控制器做 projection

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名: controlView(for:)
// 功能说明: 本次未改；现有 settings panel 平台 view 已经支持通用 choice / slider / toggle row 渲染。
(未修改，本次记录不重复展开代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: replaceRows(_:), sanitizedState(byReplacingRowsWith:from:)
// 功能说明: 本次未改；行数变化后的 preview / interaction 清理由现有半受控组件逻辑继续承接。
(未修改，本次记录不重复展开代码)
```

## 验证情况

- `ReadLints`：本次修改相关文件无新增诊断
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`：通过
- 本次全量 typecheck 仍有 2 条仓库原有 warning：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 这次未做双平台 settings panel 的手工 UI 点按回归；当前验证以 shared validation、lint 和全量静态编译为主

## 对后续阶段的影响

- 现有 `SettingsPanel` 已经具备 piano 控制项扩展点，后续如果要继续加：
- 白键宽
- 行高
- 行间距
- 黑键比例
- 都可以沿着同一套 `SettingsPanelModel + SnapshotBuilder + PianoPanelProjection` 继续扩展
- 这次也为后续“从 demo 升级成正式 piano 页面状态”打了基础：控制器已经不是直接持有固定配置，而是拥有一个可由 panel 驱动的 piano state 投影链

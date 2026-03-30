# 20260330_143903_piano_white_key_style_settings_panel

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_143903`
- 记录范围：把钢琴白键样式接入现有 `SettingsPanel`，做成可切换的控制面板选项
- 本次目标：复用现有 `Piano` 分区和通用 `choice row` 机制，让面板可以在 `Outlined` 与 `Gap Only` 两种白键样式之间切换；不新增专门的 platform view，不改白键绘制算法本身
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`

## 本次结论

- 修改前，钢琴控制面板已经支持：
- `Visible`
- `Rows`
- `Row Linking`
- `Snap Drag`
- 但白键样式虽然已经有 `PianoWhiteKeyStyle`，还只能在代码里写死，不能从控制面板切换
- 修改后，`Piano` 分区新增一个 `White Keys` 单选项
- 当前支持两个值：
- `Outlined`
- `Gap Only`
- 这次没有额外新增某种平台专用控件
- 而是继续复用：
- `PianoPanelState`
- `PianoPanelProjection`
- `SettingsChoiceRowID`
- `SettingsActionID`
- `SettingsPanelEvent.apply(...)`
- 因此 iOS / macOS 两边都自动获得了这个选项

## 修改前总体现状

- 修改前，白键样式的“实现”已经有了，但“面板状态”里没有这个字段
- `SettingsPanelModel` 里也没有与白键样式对应的 `choice row`
- 所以控制器虽然会把 `pianoPanelState` 投影给 `resolvedPianoDemoConfiguration`
- 但 `pianoPanelState` 本身并不能表达白键样式

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelState, PianoPanelProjection.resolvedConfiguration(...)
// 功能说明: 修改前 piano panel state 只管理 visible / rowCount / movementScope / snapEnabled，还不包含 whiteKeyStyle。
struct PianoPanelState: Equatable, Sendable {
    static let supportedRowCountRange: ClosedRange<Int> = 1...8

    var isVisible: Bool
    var rowCount: Int
    var movementScope: PianoMovementScope
    var snapEnabled: Bool

    init(
        isVisible: Bool = true,
        rowCount: Int = 3,
        movementScope: PianoMovementScope = .cascade,
        snapEnabled: Bool = true
    ) {
        self.isVisible = isVisible
        self.rowCount = rowCount
        self.movementScope = movementScope
        self.snapEnabled = snapEnabled
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
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsSectionID.rowIDs, SettingsChoiceRowID
// 功能说明: 修改前 Piano section 只有 Row Linking 这一个 choice row，没有 White Keys 选项。
case .piano:
    return [
        .toggle(.pianoVisible),
        .slider(.pianoRowCount),
        .choice(.pianoMovementScope),
        .toggle(.pianoSnapEnabled)
    ]

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
}
```

## 修改 1：把白键样式纳入 `PianoPanelState` 与配置投影

### 修改前

- 修改前，`PianoPanelState` 无法表达白键样式
- `PianoPanelProjection.resolvedConfiguration(...)` 也不会改动 `configuration.whiteKeyStyle`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelState.init(...), PianoPanelState.inferred(...), PianoPanelProjection.resolvedConfiguration(...)
// 功能说明: 修改前 panel state 不持有 whiteKeyStyle，因此控制面板无法影响最终配置的白键样式。
var isVisible: Bool
var rowCount: Int
var movementScope: PianoMovementScope
var snapEnabled: Bool

init(
    isVisible: Bool = true,
    rowCount: Int = 3,
    movementScope: PianoMovementScope = .cascade,
    snapEnabled: Bool = true
) {
    self.isVisible = isVisible
    self.rowCount = rowCount
    self.movementScope = movementScope
    self.snapEnabled = snapEnabled
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

static func resolvedConfiguration(
    from baseConfiguration: PianoConfiguration,
    panelState: PianoPanelState
) -> PianoConfiguration {
    var configuration = baseConfiguration
    configuration.snapEnabled = panelState.snapEnabled
    return configuration
}
```

### 修改后

- 修改后，`PianoPanelState` 新增 `whiteKeyStyle`
- `inferred(...)` 会从 `configuration.whiteKeyStyle` 反推面板初始值
- `resolvedConfiguration(...)` 会把面板值重新投影回最终 `PianoConfiguration`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelState.init(...), PianoPanelState.inferred(...), PianoPanelProjection.resolvedConfiguration(...)
// 功能说明: 修改后 whiteKeyStyle 进入 shared piano panel state，并参与 configuration 投影。
struct PianoPanelState: Equatable, Sendable {
    static let supportedRowCountRange: ClosedRange<Int> = 1...8

    var isVisible: Bool
    var rowCount: Int
    var movementScope: PianoMovementScope
    var whiteKeyStyle: PianoWhiteKeyStyle
    var snapEnabled: Bool

    init(
        isVisible: Bool = true,
        rowCount: Int = 3,
        movementScope: PianoMovementScope = .cascade,
        whiteKeyStyle: PianoWhiteKeyStyle = .outlined,
        snapEnabled: Bool = true
    ) {
        self.isVisible = isVisible
        self.rowCount = rowCount
        self.movementScope = movementScope
        self.whiteKeyStyle = whiteKeyStyle
        self.snapEnabled = snapEnabled
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
            whiteKeyStyle: configuration.whiteKeyStyle,
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
        configuration.whiteKeyStyle = panelState.whiteKeyStyle
        return configuration
    }
}
```

## 修改 2：给 `SettingsPanel` 新增 `White Keys` 选项行

### 修改前

- 修改前，`Piano` section 只有一个和样式无关的 choice row：
- `pianoMovementScope`
- 没有新的 `SettingsChoiceRowID`
- 自然也没有对应标题、accessibility 文案和 action 列表

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsSectionID.rowIDs, SettingsChoiceRowID.title, SettingsChoiceRowID.actionIDs
// 功能说明: 修改前 Piano section 还没有 white key style 对应的 choice row。
case .piano:
    return [
        .toggle(.pianoVisible),
        .slider(.pianoRowCount),
        .choice(.pianoMovementScope),
        .toggle(.pianoSnapEnabled)
    ]

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
}

case .pianoMovementScope:
    return "Row Linking"

case .pianoMovementScope:
    return [
        .setPianoMovementScopeCascade,
        .setPianoMovementScopeRowOnly
    ]
```

### 修改后

- 修改后，`Piano` section 新增 `.choice(.pianoWhiteKeyStyle)`
- `SettingsChoiceRowID` 增加 `.pianoWhiteKeyStyle`
- 标题是 `White Keys`
- 表现形式继续复用 `segmented`
- action 列表是：
- `.setPianoWhiteKeyStyleOutlined`
- `.setPianoWhiteKeyStyleGapOnly`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsSectionID.rowIDs, SettingsChoiceRowID.sectionID/title/accessibilityLabel/presentationStyle/actionIDs
// 功能说明: 修改后 White Keys 作为一个新的 Piano choice row 并入现有 settings panel schema。
case .piano:
    return [
        .toggle(.pianoVisible),
        .slider(.pianoRowCount),
        .choice(.pianoMovementScope),
        .choice(.pianoWhiteKeyStyle),
        .toggle(.pianoSnapEnabled)
    ]

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

case .pianoWhiteKeyStyle:
    return .piano

case .pianoWhiteKeyStyle:
    return "White Keys"

case .pianoWhiteKeyStyle:
    return "Select whether white keys use outlined borders or gap-only separation"

case .topContent,
     .mainContent,
     .exerciseMode,
     .clef,
     .pianoMovementScope,
     .pianoWhiteKeyStyle:
    return .segmented

case .pianoWhiteKeyStyle:
    return [
        .setPianoWhiteKeyStyleOutlined,
        .setPianoWhiteKeyStyleGapOnly
    ]
```

## 修改 3：给 `SettingsActionID` 新增白键样式动作并接到 `pianoPanelState`

### 修改前

- 修改前，`SettingsActionID` 里只有 `setPianoMovementScope...`
- 没有任何和白键样式有关的 action
- `apply(to pianoPanelState:)` 也只会改 `movementScope`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsActionID, SettingsActionID.rowID, SettingsActionID.apply(to pianoPanelState:)
// 功能说明: 修改前 settings action 还不能驱动 pianoPanelState.whiteKeyStyle。
enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    // ... 其余 action 省略
    case setPianoMovementScopeCascade
    case setPianoMovementScopeRowOnly
}

case .setPianoMovementScopeCascade,
     .setPianoMovementScopeRowOnly:
    return .pianoMovementScope

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
```

### 修改后

- 修改后，新增：
- `.setPianoWhiteKeyStyleOutlined`
- `.setPianoWhiteKeyStyleGapOnly`
- 这两个 action 会：
- 参与 `rowID/title/accessibilityLabel/isSelected` 映射
- 参与 `isEnabled` 的通用判断
- 最终在 `apply(to pianoPanelState:)` 中真正更新 `whiteKeyStyle`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsActionID, SettingsActionID.rowID/title/accessibilityLabel/isSelected/apply(to pianoPanelState:)
// 功能说明: 修改后 settings action 已经可以驱动 pianoPanelState.whiteKeyStyle，并通过 choice row 做单选切换。
enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    // ... 原有 action 保持不变
    case setPianoMovementScopeCascade
    case setPianoMovementScopeRowOnly
    case setPianoWhiteKeyStyleOutlined
    case setPianoWhiteKeyStyleGapOnly
}

case .setPianoWhiteKeyStyleOutlined,
     .setPianoWhiteKeyStyleGapOnly:
    return .pianoWhiteKeyStyle

case .setPianoWhiteKeyStyleOutlined:
    return "Outlined"
case .setPianoWhiteKeyStyleGapOnly:
    return "Gap Only"

case .setPianoWhiteKeyStyleOutlined:
    return "Render white keys with individual outlines"
case .setPianoWhiteKeyStyleGapOnly:
    return "Render white keys without outlines, using gaps between keys instead"

case .setPianoWhiteKeyStyleOutlined:
    return stateContext.pianoPanelState.whiteKeyStyle == .outlined
case .setPianoWhiteKeyStyleGapOnly:
    return stateContext.pianoPanelState.whiteKeyStyle == .borderlessSeparatedByGaps

func apply(to pianoPanelState: inout PianoPanelState) {
    switch self {
    case .setPianoMovementScopeCascade:
        pianoPanelState.movementScope = .cascade
    case .setPianoMovementScopeRowOnly:
        pianoPanelState.movementScope = .rowOnly
    case .setPianoWhiteKeyStyleOutlined:
        pianoPanelState.whiteKeyStyle = .outlined
    case .setPianoWhiteKeyStyleGapOnly:
        pianoPanelState.whiteKeyStyle = .borderlessSeparatedByGaps
    default:
        return
    }
}
```

## 修改 4：补充 panel inference / projection 校验

### 修改前

- 修改前，`PianoValidation` 对 `PianoPanelState` 的校验只覆盖：
- `rowCount`
- `movementScope`
- `snapEnabled`
- 没有覆盖 `whiteKeyStyle`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validatePianoPanelStateInferenceAndClamp(), validatePianoPanelProjectionResolution()
// 功能说明: 修改前 panel validation 还不校验 whiteKeyStyle 的推断与投影。
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

if inferred.movementScope != .rowOnly {
    issues.append(issue(fixtureName, "inferred movementScope 应沿用首行 movementScope。"))
}
if inferred.snapEnabled {
    issues.append(issue(fixtureName, "inferred snapEnabled 应沿用 configuration.snapEnabled。"))
}

let panelState = PianoPanelState(
    isVisible: false,
    rowCount: 4,
    movementScope: .cascade,
    snapEnabled: false
)
```

### 修改后

- 修改后，fixture 明确把白键样式放进：
- `inferred(...)` 输入配置
- `panelState`
- 并分别校验：
- `inferred.whiteKeyStyle`
- `resolvedConfiguration.whiteKeyStyle`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validatePianoPanelStateInferenceAndClamp(), validatePianoPanelProjectionResolution()
// 功能说明: 修改后 panel validation 会覆盖 whiteKeyStyle 的推断与 configuration 投影。
let inferred = PianoPanelState.inferred(
    configuration: PianoConfiguration(
        whiteKeyStyle: .borderlessSeparatedByGaps,
        snapEnabled: false
    ),
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

if inferred.whiteKeyStyle != .borderlessSeparatedByGaps {
    issues.append(issue(fixtureName, "inferred whiteKeyStyle 应沿用 configuration.whiteKeyStyle。"))
}

let panelState = PianoPanelState(
    isVisible: false,
    rowCount: 4,
    movementScope: .cascade,
    whiteKeyStyle: .borderlessSeparatedByGaps,
    snapEnabled: false
)

if resolvedConfiguration.whiteKeyStyle != .borderlessSeparatedByGaps {
    issues.append(issue(fixtureName, "panel projection 应允许单独切换 whiteKeyStyle。"))
}
```

## 修改 5：状态文本补充 `style=` 便于观察面板切换结果

### 修改前

- 修改前，controller 里的调试状态文本只显示：
- `visible`
- `rows`
- `scope`
- `snap`
- 不能直接从状态文本里看出当前白键样式

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: pianoDemoStatusText()
// 功能说明: 修改前状态文本不显示 whiteKeyStyle，面板切换样式后只能靠视觉判断。
return [
    "event: \(pianoDemoLastEventText)",
    "preview: \(previewText)",
    "panel: visible=\(pianoPanelState.isVisible) rows=\(resolvedPianoDemoRows.count) scope=\(pianoPanelState.movementScope.debugName) snap=\(resolvedPianoDemoConfiguration.snapEnabled)",
    "rows: \(pianoDemoRowsSummaryText(resolvedPianoDemoRows))"
].joined(separator: "\n")
```

### 修改后

- 修改后，iOS / macOS 两边状态文本都增加：
- `style=\(resolvedPianoDemoConfiguration.whiteKeyStyle.debugName)`
- 同时为了让这里更稳定，`PianoWhiteKeyStyle` 补了一个 `debugName`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: PianoWhiteKeyStyle.debugName
// 功能说明: 修改后为白键样式提供统一的调试文本，便于控制器状态标签复用。
enum PianoWhiteKeyStyle: Equatable, Sendable {
    case outlined
    case borderlessSeparatedByGaps

    var debugName: String {
        switch self {
        case .outlined:
            return "outlined"
        case .borderlessSeparatedByGaps:
            return "gapOnly"
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: pianoDemoStatusText()
// 功能说明: 修改后状态文本会直接显示当前白键样式，便于确认控制面板切换是否生效。
return [
    "event: \(pianoDemoLastEventText)",
    "preview: \(previewText)",
    "panel: visible=\(pianoPanelState.isVisible) rows=\(resolvedPianoDemoRows.count) scope=\(pianoPanelState.movementScope.debugName) style=\(resolvedPianoDemoConfiguration.whiteKeyStyle.debugName) snap=\(resolvedPianoDemoConfiguration.snapEnabled)",
    "rows: \(pianoDemoRowsSummaryText(resolvedPianoDemoRows))"
].joined(separator: "\n")
```

## 本次没有改动的部分

- `SettingsPanelSnapshotBuilder.swift` 没改
- 原因是它已经按 `SettingsSectionID.rowIDs` 和 `SettingsChoiceRowID.actionIDs` 通用构建 choice row
- 这次只要把 schema 扩展好，snapshot builder 就会自动带出新行
- `iOSSettingsPanelView` / `macOSSettingsPanelView` 也没改
- 原因是平台层已经支持通用 segmented choice row
- `PianoRowLayer.swift` 没改
- 因为这次只是把已有样式接到控制面板，不是重写样式绘制本身

```text
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: makeChoiceRow(...), makeChoiceItem(...)
// 功能说明: 本次未修改；现有 snapshot builder 已能自动把新的 pianoWhiteKeyStyle choice row 构建出来。
(未修改，本次记录不重复展开代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: segmented/chips/toggle 通用行渲染逻辑
// 功能说明: 本次未修改；平台 settings view 直接复用现有 choice row UI。
(未修改，本次记录不重复展开代码)
```

## 验证情况

- `ReadLints`：本次修改相关文件无新增诊断
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`：通过
- 本次全量 typecheck 仍有 2 条仓库原有 warning：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次未单独做双平台手工 UI 回归；当前验证以 shared validation 更新、lint 和全量静态编译为主

## 对后续调整的影响

- 现在白键样式已经正式进入 `PianoPanelState`
- 后续如果还要继续加：
- 黑键样式
- 键间缝宽度
- 白键圆角
- 都可以沿着同一套：
- `PianoPanelState`
- `PianoPanelProjection`
- `SettingsChoiceRowID / SettingsActionID`
- 继续扩展
- 这次也进一步验证了：现有 `SettingsPanel` 的 shared schema 足够承接 piano 的视觉控制项，不需要再单独做一套钢琴专用面板视图

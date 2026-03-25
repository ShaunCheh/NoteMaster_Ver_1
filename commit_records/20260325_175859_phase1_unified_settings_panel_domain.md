# 20260325_175859_phase1_unified_settings_panel_domain

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_175859`
- 记录范围：方案 D 的实施阶段 1，统一共享设置域模型
- 本次目标：在不改平台 UI 和控制器布局的前提下，先把当前 `ButtonPanel`、`StaffControlPanel`、`FretboardControlPanel` 三套并行共享语义，收口到新的 `SettingsPanel` 共享域中，为后续统一快照构建器、统一平台视图和设置容器打基础

## 本次完成的修改

1. 新增 `SettingsPanelModel.swift`，建立统一的 settings section / row / action / slider / event 共享模型。
2. 将 `ButtonPanelActionID` 的标题、无障碍文案、选中态、可用态、状态迁移动作代理到新的 `SettingsActionID`。
3. 将 `StaffControlEvent` 与 `StaffOptionControlItem.ID` / `StaffSliderControlItem.ID` 代理到新的 `SettingsActionID` / `SettingsSliderID`。
4. 将 `FretboardControlEvent` 与 `FretboardSliderControlItem.ID` 代理到新的 `SettingsSliderID`。
5. 执行共享层 lint 与类型校验，确认阶段 1 可以作为后续阶段的稳定基线。

## 修改 1：新增 `SettingsPanelModel.swift`，建立统一的 settings 共享域

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前项目中没有统一的 settings 域模型；离散按钮、五线谱设置、指板高度设置分别由 3 套独立 panel model 表达。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSectionID, SettingsChoiceRowID, SettingsActionID, SettingsSliderID, SettingsPanelEvent
// 功能说明: 修改后统一的 settings 域会负责描述 section、choice row、slider row、离散动作、连续值调整以及统一事件入口，成为后续 SettingsPanelSnapshotBuilder / SettingsPanelView 的共享真相。
import CoreGraphics

enum SettingsSelectionStyle: Equatable, Sendable {
    case singleSelection
    case independent
}

enum SettingsPresentationStyle: Equatable, Sendable {
    case chips
    case segmented
}

enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case layout

    var title: String {
        switch self {
        case .fretboard:
            return "Fretboard"
        case .staff:
            return "Staff"
        case .layout:
            return "Layout"
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
    case setClefTreble
    case setClefBass

    func apply(to displayState: inout FretboardDisplayState) {
        switch self {
        case .setInstrumentGuitar6:
            displayState.configuration.tuning = .standard(for: .guitar6)
        case .setInstrumentBass4:
            displayState.configuration.tuning = .standard(for: .bass4)
        case .setInstrumentBass5:
            displayState.configuration.tuning = .standard(for: .bass5)
        case .setDisplayModeHorizontal:
            displayState.setDisplayMode(.horizontal)
        case .setDisplayModeVertical:
            displayState.setDisplayMode(.vertical)
        case .setVisibilityAll:
            displayState.visibility = .all
        case .setVisibilityNaturalOnly:
            displayState.visibility = .naturalOnly
        case .setVisibilityAccidentalOnly:
            displayState.visibility = .accidentalOnly
        case .setVisibilityNone:
            displayState.visibility = .none
        case .setSpellingSharp:
            displayState.spelling = .sharp
        case .setSpellingFlat:
            displayState.spelling = .flat
        case .toggleShowsOctave:
            displayState.showsOctave.toggle()
        case .setClefTreble, .setClefBass:
            return
        }
    }

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case .setClefTreble:
            displayState.configuration.clef = .treble
        case .setClefBass:
            displayState.configuration.clef = .bass
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave:
            return
        }
    }
}

enum SettingsSliderID: CaseIterable, Equatable, Hashable, Sendable {
    case clefScale
    case clefVerticalTrim
    case clefAnchorYOffset
    case verticalHostHeightRatio

    var range: ClosedRange<CGFloat> {
        switch self {
        case .clefScale:
            return 1.0...5
        case .clefVerticalTrim:
            return 0...0.4
        case .clefAnchorYOffset:
            return (-0.25)...0.25
        case .verticalHostHeightRatio:
            return FretboardDisplayState.verticalHostHeightRatioRange
        }
    }
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case setSliderValue(SettingsSliderID, CGFloat)

    func apply(
        to fretboardDisplayState: inout FretboardDisplayState,
        and staffDisplayState: inout StaffDisplayState
    ) {
        switch self {
        case let .triggerAction(actionID):
            actionID.apply(to: &fretboardDisplayState)
            actionID.apply(to: &staffDisplayState)
        case let .setSliderValue(sliderID, value):
            sliderID.apply(value: value, to: &fretboardDisplayState)
            sliderID.apply(value: value, to: &staffDisplayState)
        }
    }
}
```

## 修改 2：`ButtonPanelActionID` 的语义开始代理到 `SettingsActionID`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelActionID.title, accessibilityLabel, isSelected(in:), isEnabled(in:), apply(to:)
// 功能说明: 修改前 ButtonPanelActionID 自己直接维护整套标题、无障碍文案、选中态、可用态和状态迁移逻辑，与未来统一 settings 域完全平行。
var title: String {
    switch self {
    case .setInstrumentGuitar6:
        return "Guitar 6"
    case .setInstrumentBass4:
        return "Bass 4"
    case .setInstrumentBass5:
        return "Bass 5"
    case .setDisplayModeHorizontal:
        return "Horizontal"
    case .setDisplayModeVertical:
        return "Vertical"
    case .setVisibilityAll:
        return "All"
    case .setVisibilityNaturalOnly:
        return "Natural"
    case .setVisibilityAccidentalOnly:
        return "Accidental"
    case .setVisibilityNone:
        return "None"
    case .setSpellingSharp:
        return "Sharp"
    case .setSpellingFlat:
        return "Flat"
    case .toggleShowsOctave:
        return "Octave"
    }
}

func apply(to displayState: inout FretboardDisplayState) {
    switch self {
    case .setInstrumentGuitar6:
        displayState.configuration.tuning = .standard(for: .guitar6)
    case .setInstrumentBass4:
        displayState.configuration.tuning = .standard(for: .bass4)
    case .setInstrumentBass5:
        displayState.configuration.tuning = .standard(for: .bass5)
    case .setDisplayModeHorizontal:
        displayState.setDisplayMode(.horizontal)
    case .setDisplayModeVertical:
        displayState.setDisplayMode(.vertical)
    case .setVisibilityAll:
        displayState.visibility = .all
    case .setVisibilityNaturalOnly:
        displayState.visibility = .naturalOnly
    case .setVisibilityAccidentalOnly:
        displayState.visibility = .accidentalOnly
    case .setVisibilityNone:
        displayState.visibility = .none
    case .setSpellingSharp:
        displayState.spelling = .sharp
    case .setSpellingFlat:
        displayState.spelling = .flat
    case .toggleShowsOctave:
        displayState.showsOctave.toggle()
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelActionID.title, accessibilityLabel, isSelected(in:), isEnabled(in:), apply(to:), settingsActionID
// 功能说明: 修改后 ButtonPanelActionID 仍保持旧接口不变，但它的核心语义已经开始代理到 SettingsActionID，为后续删除旧 ButtonPanel 体系做过渡。
var title: String {
    settingsActionID.title
}

var accessibilityLabel: String {
    settingsActionID.accessibilityLabel
}

func isSelected(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isSelected(
        fretboardDisplayState: displayState,
        staffDisplayState: .default
    )
}

func isEnabled(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isEnabled(
        fretboardDisplayState: displayState,
        staffDisplayState: .default
    )
}

func apply(to displayState: inout FretboardDisplayState) {
    settingsActionID.apply(to: &displayState)
}

private extension ButtonPanelActionID {
    var settingsActionID: SettingsActionID {
        switch self {
        case .setInstrumentGuitar6:
            return .setInstrumentGuitar6
        case .setInstrumentBass4:
            return .setInstrumentBass4
        case .setInstrumentBass5:
            return .setInstrumentBass5
        case .setDisplayModeHorizontal:
            return .setDisplayModeHorizontal
        case .setDisplayModeVertical:
            return .setDisplayModeVertical
        case .setVisibilityAll:
            return .setVisibilityAll
        case .setVisibilityNaturalOnly:
            return .setVisibilityNaturalOnly
        case .setVisibilityAccidentalOnly:
            return .setVisibilityAccidentalOnly
        case .setVisibilityNone:
            return .setVisibilityNone
        case .setSpellingSharp:
            return .setSpellingSharp
        case .setSpellingFlat:
            return .setSpellingFlat
        case .toggleShowsOctave:
            return .toggleShowsOctave
        }
    }
}
```

## 修改 3：`StaffControlPanelModel` 的 clef / slider 语义开始代理到统一 settings 域

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift
// 函数/成员: StaffControlEvent.apply(to:), StaffOptionControlItem.ID.title/accessibilityLabel, StaffSliderControlItem.ID.title/accessibilityLabel/range
// 功能说明: 修改前五线谱控制面板自己维护 clef 事件、slider 范围、标题与无障碍文案；这些语义尚未和统一 settings 域对齐。
static let clefScaleRange: ClosedRange<CGFloat> = 1.0...5
static let clefVerticalTrimRatioRange: ClosedRange<CGFloat> = 0...0.4
static let clefAnchorLogicalDownwardShiftRatioRange: ClosedRange<CGFloat> = (-0.25)...0.25

func apply(to displayState: inout StaffDisplayState) {
    switch self {
    case let .setClef(clef):
        displayState.configuration.clef = clef
    case let .setClefScale(value):
        displayState.configuration.layoutMetrics.clefScale = value.clamped(
            to: Self.clefScaleRange
        )
    case let .setClefVerticalTrimRatio(value):
        displayState.configuration.setClefVerticalTrimRatio(
            value.clamped(
                to: Self.clefVerticalTrimRatioRange
            ),
            for: displayState.configuration.clef
        )
    case let .setClefAnchorLogicalDownwardShiftRatio(value):
        displayState.configuration.setClefAnchorLogicalDownwardShiftRatio(
            value.clamped(
                to: Self.clefAnchorLogicalDownwardShiftRatioRange
            ),
            for: displayState.configuration.clef
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift
// 函数/成员: StaffControlEvent.apply(to:), StaffOptionControlItem.ID.settingsChoiceRowID, StaffSliderControlItem.ID.settingsSliderID
// 功能说明: 修改后 clef 离散动作和 3 个 slider 的范围/标题/无障碍文案/状态迁移开始复用 SettingsActionID 与 SettingsSliderID，旧 StaffControlPanelModel 变成过渡层。
static let clefScaleRange = SettingsSliderID.clefScale.range
static let clefVerticalTrimRatioRange = SettingsSliderID.clefVerticalTrim.range
static let clefAnchorLogicalDownwardShiftRatioRange = SettingsSliderID.clefAnchorYOffset.range

func apply(to displayState: inout StaffDisplayState) {
    switch self {
    case let .setClef(clef):
        clef.settingsActionID.apply(to: &displayState)
    case let .setClefScale(value):
        SettingsSliderID.clefScale.apply(
            value: value,
            to: &displayState
        )
    case let .setClefVerticalTrimRatio(value):
        SettingsSliderID.clefVerticalTrim.apply(
            value: value,
            to: &displayState
        )
    case let .setClefAnchorLogicalDownwardShiftRatio(value):
        SettingsSliderID.clefAnchorYOffset.apply(
            value: value,
            to: &displayState
        )
    }
}

private extension StaffOptionControlItem.ID {
    var settingsChoiceRowID: SettingsChoiceRowID {
        switch self {
        case .clef:
            return .clef
        }
    }
}

private extension StaffSliderControlItem.ID {
    var settingsSliderID: SettingsSliderID {
        switch self {
        case .clefScale:
            return .clefScale
        case .clefVerticalTrim:
            return .clefVerticalTrim
        case .clefAnchorYOffset:
            return .clefAnchorYOffset
        }
    }
}
```

## 修改 4：`FretboardControlPanelModel` 的高度 slider 语义开始代理到统一 settings 域

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelModel.swift
// 函数/成员: FretboardControlEvent.apply(to:), FretboardSliderControlItem.ID.title/accessibilityLabel/range
// 功能说明: 修改前竖向指板高度 slider 仍然由 FretboardControlPanelModel 自己维护 title / accessibility / range / 状态迁移。
func apply(to displayState: inout FretboardDisplayState) {
    switch self {
    case let .setVerticalHostHeightRatio(value):
        displayState.setVerticalHostHeightRatio(value)
    }
}

var title: String {
    switch self {
    case .verticalHostHeightRatio:
        return "Height"
    }
}

var accessibilityLabel: String {
    switch self {
    case .verticalHostHeightRatio:
        return "Adjust vertical fretboard height"
    }
}

var range: ClosedRange<CGFloat> {
    switch self {
    case .verticalHostHeightRatio:
        return FretboardDisplayState.verticalHostHeightRatioRange
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelModel.swift
// 函数/成员: FretboardControlEvent.apply(to:), FretboardSliderControlItem.ID.settingsSliderID
// 功能说明: 修改后竖向指板高度 slider 的状态迁移、标题、无障碍文案与取值范围，都开始通过 SettingsSliderID.verticalHostHeightRatio 统一收口。
func apply(to displayState: inout FretboardDisplayState) {
    switch self {
    case let .setVerticalHostHeightRatio(value):
        SettingsSliderID.verticalHostHeightRatio.apply(
            value: value,
            to: &displayState
        )
    }
}

var title: String {
    settingsSliderID.title
}

var accessibilityLabel: String {
    settingsSliderID.accessibilityLabel
}

var range: ClosedRange<CGFloat> {
    settingsSliderID.range
}

private extension FretboardSliderControlItem.ID {
    var settingsSliderID: SettingsSliderID {
        switch self {
        case .verticalHostHeightRatio:
            return .verticalHostHeightRatio
        }
    }
}
```

## 验证情况

1. 已检查阶段 1 涉及文件的 lint，结果无新增问题。
2. 已执行 `swiftc -typecheck` 覆盖当前工程全部 Swift 源文件，结果通过。
3. 当前仍未改动平台 UI、快照构建器或控制器布局；阶段 1 的结果仅限于共享设置域落地与旧语义代理。

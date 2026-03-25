# 20260325_143247_phase6_display_mode_button_panel_integration

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260325_143247`
- 记录范围：指板竖向 Scene 重构的阶段 6
- 本阶段目标：把 `displayMode` 正式接入共享显示状态与按钮面板切换入口，让 iOS / macOS 都通过现有共享状态链路切换 horizontal / vertical

## 本阶段完成的修改

1. 在 `ButtonPanelModel` 中新增 `displayMode` section，以及 `Horizontal` / `Vertical` 两个 action。
2. 在 `ButtonPanelModel` 的共享状态迁移逻辑中，把 display mode 切换动作接到 `FretboardDisplayState`。
3. 在 `ButtonPanelSnapshotBuilder` 中显式固定 section 顺序，把 `displayMode` 插到 `instrument` 后面。
4. 在 `FretboardDisplayState` 中增加 `setDisplayMode(_:)`，把模式切换入口收口到共享状态层。

## 修改 1：`ButtonPanelModel` 新增 `displayMode` section 与切换 action

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelSectionID, ButtonPanelActionID.sectionID, ButtonPanelActionID.title, ButtonPanelActionID.accessibilityLabel
// 功能说明: 修改前按钮面板只有 instrument / labels / spelling / octave 四个 section，完全没有 display mode 的共享动作定义。
enum ButtonPanelSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case instrument
    case labels
    case spelling
    case octave

    var title: String {
        switch self {
        case .instrument:
            return "Instrument"
        case .labels:
            return "Labels"
        case .spelling:
            return "Spelling"
        case .octave:
            return "Octave"
        }
    }

    var selectionStyle: ButtonPanelSelectionStyle {
        switch self {
        case .instrument, .labels, .spelling:
            return .singleSelection
        case .octave:
            return .independent
        }
    }
}

enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave

    var sectionID: ButtonPanelSectionID {
        switch self {
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5:
            return .instrument
        case .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone:
            return .labels
        case .setSpellingSharp,
             .setSpellingFlat:
            return .spelling
        case .toggleShowsOctave:
            return .octave
        }
    }

    var title: String {
        switch self {
        case .setInstrumentGuitar6:
            return "Guitar 6"
        case .setInstrumentBass4:
            return "Bass 4"
        case .setInstrumentBass5:
            return "Bass 5"
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

    var accessibilityLabel: String {
        switch self {
        case .setInstrumentGuitar6:
            return "Use 6-string guitar standard tuning"
        case .setInstrumentBass4:
            return "Use 4-string bass standard tuning"
        case .setInstrumentBass5:
            return "Use 5-string bass standard tuning"
        case .setVisibilityAll:
            return "Show all note labels"
        case .setVisibilityNaturalOnly:
            return "Show natural note labels only"
        case .setVisibilityAccidentalOnly:
            return "Show accidental note labels only"
        case .setVisibilityNone:
            return "Hide all note labels"
        case .setSpellingSharp:
            return "Use sharp note spelling"
        case .setSpellingFlat:
            return "Use flat note spelling"
        case .toggleShowsOctave:
            return "Toggle octave display"
        }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelSectionID, ButtonPanelActionID.sectionID, ButtonPanelActionID.title, ButtonPanelActionID.accessibilityLabel
// 功能说明: 修改后按钮面板共享模型正式拥有 displayMode 维度；horizontal / vertical 切换按钮与现有 instrument / labels / spelling 一样，统一由共享 action 描述。
enum ButtonPanelSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case instrument
    case displayMode
    case labels
    case spelling
    case octave

    var title: String {
        switch self {
        case .instrument:
            return "Instrument"
        case .displayMode:
            return "Display"
        case .labels:
            return "Labels"
        case .spelling:
            return "Spelling"
        case .octave:
            return "Octave"
        }
    }

    var selectionStyle: ButtonPanelSelectionStyle {
        switch self {
        case .instrument, .displayMode, .labels, .spelling:
            return .singleSelection
        case .octave:
            return .independent
        }
    }
}

enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
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

    var sectionID: ButtonPanelSectionID {
        switch self {
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5:
            return .instrument
        case .setDisplayModeHorizontal,
             .setDisplayModeVertical:
            return .displayMode
        case .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone:
            return .labels
        case .setSpellingSharp,
             .setSpellingFlat:
            return .spelling
        case .toggleShowsOctave:
            return .octave
        }
    }

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

    var accessibilityLabel: String {
        switch self {
        case .setInstrumentGuitar6:
            return "Use 6-string guitar standard tuning"
        case .setInstrumentBass4:
            return "Use 4-string bass standard tuning"
        case .setInstrumentBass5:
            return "Use 5-string bass standard tuning"
        case .setDisplayModeHorizontal:
            return "Show fretboard in horizontal mode"
        case .setDisplayModeVertical:
            return "Show fretboard in vertical mode"
        case .setVisibilityAll:
            return "Show all note labels"
        case .setVisibilityNaturalOnly:
            return "Show natural note labels only"
        case .setVisibilityAccidentalOnly:
            return "Show accidental note labels only"
        case .setVisibilityNone:
            return "Hide all note labels"
        case .setSpellingSharp:
            return "Use sharp note spelling"
        case .setSpellingFlat:
            return "Use flat note spelling"
        case .toggleShowsOctave:
            return "Toggle octave display"
        }
    }
}
```

## 修改 2：`ButtonPanelModel` 把 display mode 选中态与状态迁移接入共享状态

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelActionID.isSelected(in:), isEnabled(in:), apply(to:)
// 功能说明: 修改前共享层只会处理 instrument / labels / spelling / octave，displayMode 既没有选中态，也没有迁移逻辑。
enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
    func isSelected(in displayState: FretboardDisplayState) -> Bool {
        switch self {
        case .setInstrumentGuitar6:
            return displayState.configuration.instrument == .guitar6
        case .setInstrumentBass4:
            return displayState.configuration.instrument == .bass4
        case .setInstrumentBass5:
            return displayState.configuration.instrument == .bass5
        case .setVisibilityAll:
            return displayState.visibility == .all
        case .setVisibilityNaturalOnly:
            return displayState.visibility == .naturalOnly
        case .setVisibilityAccidentalOnly:
            return displayState.visibility == .accidentalOnly
        case .setVisibilityNone:
            return displayState.visibility == .none
        case .setSpellingSharp:
            return displayState.spelling == .sharp
        case .setSpellingFlat:
            return displayState.spelling == .flat
        case .toggleShowsOctave:
            return displayState.showsOctave
        }
    }

    func isEnabled(in _: FretboardDisplayState) -> Bool {
        switch self {
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave:
            return true
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
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelActionID.isSelected(in:), isEnabled(in:), apply(to:)
// 功能说明: 修改后 displayMode 与其它按钮一样，选中态和动作迁移都由共享层定义；平台控制器只需继续把 action 交给 displayState.apply(...)。
enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
    func isSelected(in displayState: FretboardDisplayState) -> Bool {
        switch self {
        case .setInstrumentGuitar6:
            return displayState.configuration.instrument == .guitar6
        case .setInstrumentBass4:
            return displayState.configuration.instrument == .bass4
        case .setInstrumentBass5:
            return displayState.configuration.instrument == .bass5
        case .setDisplayModeHorizontal:
            return displayState.displayMode == .horizontal
        case .setDisplayModeVertical:
            return displayState.displayMode == .vertical
        case .setVisibilityAll:
            return displayState.visibility == .all
        case .setVisibilityNaturalOnly:
            return displayState.visibility == .naturalOnly
        case .setVisibilityAccidentalOnly:
            return displayState.visibility == .accidentalOnly
        case .setVisibilityNone:
            return displayState.visibility == .none
        case .setSpellingSharp:
            return displayState.spelling == .sharp
        case .setSpellingFlat:
            return displayState.spelling == .flat
        case .toggleShowsOctave:
            return displayState.showsOctave
        }
    }

    func isEnabled(in _: FretboardDisplayState) -> Bool {
        switch self {
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
            return true
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
}
```

## 修改 3：`ButtonPanelSnapshotBuilder` 显式固定 section 顺序

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift
// 函数/成员: ButtonPanelSnapshotBuilder.makeModel(from:)
// 功能说明: 修改前 section 顺序完全依赖 ButtonPanelSectionID.allCases；当新增 displayMode 后，虽然通常也会按声明顺序出现，但顺序真相没有显式收口。
enum ButtonPanelSnapshotBuilder {
    static func makeModel(from displayState: FretboardDisplayState) -> ButtonPanelModel {
        ButtonPanelModel(
            sections: ButtonPanelSectionID.allCases.map {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift
// 函数/成员: ButtonPanelSnapshotBuilder.orderedSectionIDs, makeModel(from:)
// 功能说明: 修改后 section 顺序由共享快照构建器显式定义，把 displayMode 固定插在 instrument 后面，避免后续依赖 allCases 的隐式顺序。
enum ButtonPanelSnapshotBuilder {
    private static let orderedSectionIDs: [ButtonPanelSectionID] = [
        .instrument,
        .displayMode,
        .labels,
        .spelling,
        .octave
    ]

    static func makeModel(from displayState: FretboardDisplayState) -> ButtonPanelModel {
        ButtonPanelModel(
            sections: orderedSectionIDs.map {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }
}
```

## 修改 4：`FretboardDisplayState` 新增显式 `setDisplayMode(_:)` 入口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数/成员: FretboardDisplayState.displayMode
// 功能说明: 修改前虽然已经能通过 displayMode 代理访问 configuration.displayMode，但没有显式的共享状态切换入口，按钮动作只能直接写底层配置。
struct FretboardDisplayState: Equatable, Sendable {
    // displayMode 仍以 configuration 为真相来源；这里提供共享状态级别的语义代理。
    var displayMode: FretboardDisplayMode {
        get { configuration.displayMode }
        set { configuration.displayMode = newValue }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数/成员: FretboardDisplayState.displayMode, setDisplayMode(_:)
// 功能说明: 修改后 shared display state 提供显式模式切换方法，display mode 的业务入口被收口到状态层，便于按钮面板和未来其它控制面共用。
struct FretboardDisplayState: Equatable, Sendable {
    // displayMode 仍以 configuration 为真相来源；这里提供共享状态级别的语义代理。
    var displayMode: FretboardDisplayMode {
        get { configuration.displayMode }
        set { configuration.displayMode = newValue }
    }

    // 模式切换入口收口到共享状态，避免平台层自行解释 horizontal / vertical 业务语义。
    mutating func setDisplayMode(_ displayMode: FretboardDisplayMode) {
        self.displayMode = displayMode
    }
}
```

## 补充说明

1. `iOSButtonPanelView` 与 `macOSButtonPanelView` 本阶段无需改动，因为它们已经是按 `ButtonPanelModel.sections` 动态渲染；共享模型新增 section 后，平台层会被动吃到新的 `Horizontal / Vertical` 按钮组。
2. `iOSViewController` 与 `macOSViewController` 也无需新增 display mode 特判，因为它们本来就是把 `ButtonPanelActionID` 交给 `displayState.apply(_:)`，状态变化后会沿现有配置刷新链路自动更新布局。

## 验证情况

1. 已检查本阶段涉及文件的 IDE diagnostics：无新增报错。
2. 已执行 `swiftc -typecheck` 覆盖当前 `NoteMaster_Ver_1` 下全部 Swift 源文件：通过。
3. 未执行 `xcodebuild`：当前环境仍然是 Command Line Tools 目录，不是完整 Xcode toolchain。


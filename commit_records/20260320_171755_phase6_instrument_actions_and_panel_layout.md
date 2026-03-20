20260320_171755_phase6_instrument_actions_and_panel_layout

# 原生按钮组件阶段 6 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 共享按钮模型还不能表达乐器切换动作

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名：ButtonPanelSectionID.title, ButtonPanelSectionID.selectionStyle, ButtonPanelActionID.sectionID, ButtonPanelActionID.apply(to:)
// 功能说明：修改前按钮语义层只有 labels、spelling、octave 三组动作，
// 还不能通过共享 action 切换 guitar6 / bass4 / bass5，也没有 instrument section 承载第二批控制项。
enum ButtonPanelSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case labels
    case spelling
    case octave
}

enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave

    func apply(to displayState: inout FretboardDisplayState) {
        switch self {
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

### iOS 按钮面板的 section 容器仍然是单行横排

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift
// 函数名：configureView()
// 功能说明：修改前 iOS 面板最外层的 sectionsStackView 仍然横向排列，
// 在只展示 labels、spelling、octave 时还能工作，但新增 instrument section 后会把整条工具栏继续横向挤宽。
private func configureView() {
    directionalLayoutMargins = Style.contentInsets
    backgroundColor = .secondarySystemBackground
    layer.cornerRadius = Style.panelCornerRadius
    layer.cornerCurve = .continuous

    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

    sectionsStackView.axis = .horizontal
    sectionsStackView.alignment = .fill
    sectionsStackView.distribution = .fill
    sectionsStackView.spacing = Style.sectionSpacing
}
```

### macOS 按钮面板同样还是单行横排 section

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift
// 函数名：configureView()
// 功能说明：修改前 macOS 面板的 section 容器也是横向排列并且按 centerY 对齐，
// 当 section 数量增长时，布局会继续往横向扩展，不适合作为第二批 instrument 控制项的承载方式。
private func configureView() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    layer?.cornerRadius = Style.panelCornerRadius

    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

    sectionsStackView.orientation = .horizontal
    sectionsStackView.alignment = .centerY
    sectionsStackView.distribution = .fill
    sectionsStackView.spacing = Style.sectionSpacing
}
```

## 修改后

### 共享按钮模型新增 instrument section 和乐器切换动作

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名：ButtonPanelSectionID.title, ButtonPanelSectionID.selectionStyle, ButtonPanelActionID.sectionID, ButtonPanelActionID.title, ButtonPanelActionID.isSelected(in:), ButtonPanelActionID.apply(to:)
// 功能说明：修改后共享按钮模型正式接入 instrument 控制项，
// 新增 guitar6 / bass4 / bass5 三个 action，并把按钮选中态与标准调弦切换规则统一收口到 Shared 层。
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

    func isSelected(in displayState: FretboardDisplayState) -> Bool {
        switch self {
        case .setInstrumentGuitar6:
            return displayState.configuration.instrument == .guitar6
        case .setInstrumentBass4:
            return displayState.configuration.instrument == .bass4
        case .setInstrumentBass5:
            return displayState.configuration.instrument == .bass5
        // ... 其余显示策略按钮保持原逻辑 ...
        default:
            return false
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
        // ... 其余显示策略按钮保持原逻辑 ...
        default:
            break
        }
    }
}
```

### iOS 面板改成按 section 多行布局

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift
// 函数名：configureView()
// 功能说明：修改后 iOS 面板把最外层 sectionsStackView 改成纵向排列，
// 每个 section 内部仍然保持横向按钮行，这样新增 instrument section 后不会把整个面板横向挤爆。
private func configureView() {
    directionalLayoutMargins = Style.contentInsets
    backgroundColor = .secondarySystemBackground
    layer.cornerRadius = Style.panelCornerRadius
    layer.cornerCurve = .continuous

    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

    sectionsStackView.axis = .vertical
    sectionsStackView.alignment = .fill
    sectionsStackView.distribution = .fill
    sectionsStackView.spacing = Style.sectionSpacing
}
```

### macOS 面板同步改成按 section 多行布局

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift
// 函数名：configureView()
// 功能说明：修改后 macOS 面板同样把最外层 sectionsStackView 改成纵向排列，
// 并使用 leading 对齐，保证 section 数量增长后布局仍然稳定，不需要把第二批控制项压缩到一行里。
private func configureView() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    layer?.cornerRadius = Style.panelCornerRadius

    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

    sectionsStackView.orientation = .vertical
    sectionsStackView.alignment = .leading
    sectionsStackView.distribution = .fill
    sectionsStackView.spacing = Style.sectionSpacing
}
```

## 结果说明

- 阶段 6 的核心结果是把第二批 `instrument/tuning` 控制项正式接进共享按钮语义模型。
- 当前这一步提供的是标准调弦切换：`guitar6`、`bass4`、`bass5`，还没有扩展到自定义调弦编辑。
- `ButtonPanelSnapshotBuilder.swift` 本次没有修改，但因为它本来就是基于 `ButtonPanelSectionID.allCases` 和 `ButtonPanelActionID.allCases` 生成快照，所以新增的 instrument section 会自动进入按钮面板。
- iOS 和 macOS 面板都升级成了“按 section 多行布局”，从根因上解决按钮项增长后的横向拥挤问题。
- 已执行构建验证：`DEVELOPER_DIR=\"/Applications/Xcode.app/Contents/Developer\" xcodebuild -project \"NoteMaster_Ver_1.xcodeproj\" -scheme \"NoteMaster_Ver_1\" -destination \"generic/platform=macOS\" build` 与 `generic/platform=iOS Simulator` 均通过。
- 已使用系统 `date` 生成时间戳 `20260320_171755` 作为本记录文件前缀。

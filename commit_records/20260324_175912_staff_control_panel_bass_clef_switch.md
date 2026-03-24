20260324_175912_staff_control_panel_bass_clef_switch

# StaffControlPanel 增加 Bass Clef 切换记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 共享控制模型只有滑动条，且锚点偏移是 treble 专用字段

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift
// 函数名：apply(to:), slider(for:)
// 功能说明：修改前共享事件模型只支持 scale 与 treble clef 的 anchor 偏移；
// 面板结构也只有 slider，没有离散选项行，因此无法表达 “Treble / Bass” 切换。
enum StaffControlEvent: Equatable, Sendable {
    case setClefScale(CGFloat)
    case setTrebleClefAnchorLogicalDownwardShiftRatio(CGFloat)

    static let clefScaleRange: ClosedRange<CGFloat> = 1.0...5
    static let trebleClefAnchorLogicalDownwardShiftRatioRange: ClosedRange<CGFloat> = (-0.25)...0.25

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case let .setClefScale(value):
            displayState.configuration.layoutMetrics.clefScale = value.clamped(
                to: Self.clefScaleRange
            )
        case let .setTrebleClefAnchorLogicalDownwardShiftRatio(value):
            displayState.configuration.trebleClefAnchorLogicalDownwardShiftRatio = value.clamped(
                to: Self.trebleClefAnchorLogicalDownwardShiftRatioRange
            )
        }
    }
}

struct StaffSliderControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case clefScale
        case trebleClefAnchorYOffset
    }
}

struct StaffControlSection: Equatable, Sendable {
    var id: StaffControlSectionID
    var title: String
    var sliders: [StaffSliderControlItem]
}

struct StaffControlPanelModel: Equatable, Sendable {
    var sections: [StaffControlSection]

    var sliders: [StaffSliderControlItem] {
        sections.flatMap(\.sliders)
    }
}
```

### 快照构建器只会生成 slider 区块，无法为面板提供 clef 选项

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift
// 函数名：makeSection(id:displayState:), resolvedValue(for:displayState:)
// 功能说明：修改前 SnapshotBuilder 只遍历 slider ID；
// Anchor Y Offset 读取的也是 treble 专用配置值，切换 clef 后没有独立状态可读。
private static func makeSection(
    id: StaffControlSectionID,
    displayState: StaffDisplayState
) -> StaffControlSection? {
    let sliders = StaffSliderControlItem.ID.allCases
        .filter { $0.sectionID == id }
        .map {
            makeSlider(
                for: $0,
                displayState: displayState
            )
        }

    guard !sliders.isEmpty else {
        return nil
    }

    return StaffControlSection(
        id: id,
        title: id.title,
        sliders: sliders
    )
}

private static func resolvedValue(
    for sliderID: StaffSliderControlItem.ID,
    displayState: StaffDisplayState
) -> CGFloat {
    switch sliderID {
    case .clefScale:
        return displayState.configuration.layoutMetrics.clefScale
    case .trebleClefAnchorYOffset:
        return displayState.configuration.trebleClefAnchorLogicalDownwardShiftRatio
    }
}
```

### iOS / macOS 面板实现只认识 `SliderRowView`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift
// 函数名：applyModel(), syncSliderRows(in:for:), makeEvent(value:)
// 功能说明：修改前 iOS 面板内部缓存的是 slider 行；
// Section 里只会渲染 `section.sliders`，也没有 `OptionRowView` 去承载 clef 切换控件。
private var sliderRowsByID: [StaffSliderControlItem.ID: SliderRowView] = [:]

private func applyModel() {
    removeObsoleteSliderRows(notIn: Set(model.sliders.map(\.id)))
    removeObsoleteSectionViews(notIn: Set(model.sections.map(\.id)))
}

private func syncSliderRows(
    in sectionView: SectionView,
    for section: StaffControlSection
) {
    let orderedRows = section.sliders.map { slider -> SliderRowView in
        let rowView = sliderRow(for: slider)
        rowView.apply(item: slider)
        return rowView
    }

    sectionView.rows = orderedRows
}

private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .clefScale:
            return .setClefScale(value)
        case .trebleClefAnchorYOffset:
            return .setTrebleClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift
// 函数名：applyModel(), syncSliderRows(in:for:), makeEvent(value:)
// 功能说明：修改前 macOS 面板与 iOS 对称，同样只有 slider 这一种行类型；
// 因此两个平台都只能调连续值，不能切换 clef 类型。
private var sliderRowsByID: [StaffSliderControlItem.ID: SliderRowView] = [:]

private func applyModel() {
    removeObsoleteSliderRows(notIn: Set(model.sliders.map(\.id)))
    removeObsoleteSectionViews(notIn: Set(model.sections.map(\.id)))
}

private func syncSliderRows(
    in sectionView: SectionView,
    for section: StaffControlSection
) {
    let orderedRows = section.sliders.map { slider -> SliderRowView in
        let rowView = sliderRow(for: slider)
        rowView.apply(item: slider)
        return rowView
    }

    sectionView.rows = orderedRows
}

private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .clefScale:
            return .setClefScale(value)
        case .trebleClefAnchorYOffset:
            return .setTrebleClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

### Staff 共享渲染链只支持 treble clef

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：无（类型定义片段）
// 功能说明：修改前 `StaffClef` 只有 `.treble`，配置里也只有 treble 的 anchor 偏移；
// 这意味着共享状态无法表示 bass clef，也无法为 bass 保存独立偏移值。
enum StaffClef: Equatable, Sendable {
    case treble
}

struct StaffConfiguration: Equatable, Sendable {
    var clef: StaffClef
    var layoutMetrics: LayoutMetrics
    var trebleClefAnchorLogicalDownwardShiftRatio: CGFloat
    var debugOptions: DebugOptions
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数名：无（类型定义片段）
// 功能说明：修改前 scene 语义层只有 treble 对应的锚点语义和 glyph symbol；
// SceneProvider / Renderer 没有 bass clef 的语义入口。
struct ClefAnchor: Equatable, Sendable {
    enum Semantic: Equatable, Sendable {
        case trebleGLine
    }
}

enum StaffGlyphSymbolID: Equatable, Sendable {
    case trebleClef
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数名：clefAnchor(for:)
// 功能说明：修改前几何层只知道 treble 的逻辑锚点位置。
func clefAnchor(for clef: StaffClef) -> ClefAnchor {
    switch clef {
    case .treble:
        return ClefAnchor(
            point: CGPoint(
                x: clefAreaRect.midX,
                y: lineY(at: 3) ?? staffRect.midY
            ),
            semantic: .trebleGLine,
            targetHeight: max(staffRect.height * configuration.layoutMetrics.clefScale, 1)
        )
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数名：symbolID(for:)
// 功能说明：修改前 SceneProvider 只能把 `StaffClef.treble` 映射成 `StaffGlyphSymbolID.trebleClef`。
private func symbolID(for clef: StaffClef) -> StaffGlyphSymbolID {
    switch clef {
    case .treble:
        return .trebleClef
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift
// 函数名：musicGlyph（计算属性）
// 功能说明：修改前 glyph 映射表只有 treble clef 的 SMuFL 标量值。
struct MusicGlyph: Equatable, Sendable {
    static let trebleClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE050
    )
}

extension StaffGlyphSymbolID {
    var musicGlyph: MusicGlyph {
        switch self {
        case .trebleClef:
            return .trebleClef
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：anchorMetrics(for:geometry:)
// 功能说明：修改前 CoreText renderer 只处理 treble 的 optical bounds 对齐；
// 读取的也是 treble 专用 anchor 偏移配置。
private func anchorMetrics(
    for semantic: ClefAnchor.Semantic,
    geometry: StaffGeometry
) -> AnchorMetrics {
    switch semantic {
    case .trebleGLine:
        return AnchorMetrics(
            xRatio: 0.5,
            yRatio: 0.56 - geometry.configuration.trebleClefAnchorLogicalDownwardShiftRatio
        )
    }
}
```

## 修改后

### 共享控制模型升级为 “离散选项 + slider” 混合行，并把 offset 抽成当前 clef 通用事件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift
// 函数名：apply(to:), slider(for:), option(for:)
// 功能说明：修改后共享事件层新增 `setClef`；
// 面板模型也从纯 slider 升级为 `StaffControlRow`，可以同时承载 clef 选项和连续滑块。
enum StaffControlEvent: Equatable, Sendable {
    case setClef(StaffClef)
    case setClefScale(CGFloat)
    case setClefAnchorLogicalDownwardShiftRatio(CGFloat)

    static let clefScaleRange: ClosedRange<CGFloat> = 1.0...5
    static let clefAnchorLogicalDownwardShiftRatioRange: ClosedRange<CGFloat> = (-0.25)...0.25

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case let .setClef(clef):
            displayState.configuration.clef = clef
        case let .setClefScale(value):
            displayState.configuration.layoutMetrics.clefScale = value.clamped(
                to: Self.clefScaleRange
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
}

struct StaffOptionChoice: Equatable, Hashable, Sendable {
    var clef: StaffClef
    var title: String
    var isSelected: Bool
}

struct StaffOptionControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case clef
    }
}

enum StaffControlRow: Equatable, Sendable {
    case option(StaffOptionControlItem)
    case slider(StaffSliderControlItem)
}

struct StaffControlSection: Equatable, Sendable {
    var id: StaffControlSectionID
    var title: String
    var rows: [StaffControlRow]
}

struct StaffControlPanelModel: Equatable, Sendable {
    var sections: [StaffControlSection]

    var rows: [StaffControlRow] {
        sections.flatMap(\.rows)
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift
// 函数名：makeSection(id:displayState:), makeRows(for:displayState:), makeOption(for:displayState:), resolvedValue(for:displayState:)
// 功能说明：修改后 SnapshotBuilder 会先生成 clef 选项行，再生成 slider 行；
// `Anchor Y Offset` 读取的是“当前 clef”的独立偏移值，而不是写死 treble。
private static func makeSection(
    id: StaffControlSectionID,
    displayState: StaffDisplayState
) -> StaffControlSection? {
    let rows = makeRows(
        for: id,
        displayState: displayState
    )

    guard !rows.isEmpty else {
        return nil
    }

    return StaffControlSection(
        id: id,
        title: id.title,
        rows: rows
    )
}

private static func makeRows(
    for sectionID: StaffControlSectionID,
    displayState: StaffDisplayState
) -> [StaffControlRow] {
    let optionRows = StaffOptionControlItem.ID.allCases
        .filter { $0.sectionID == sectionID }
        .map {
            StaffControlRow.option(
                makeOption(
                    for: $0,
                    displayState: displayState
                )
            )
        }

    let sliderRows = StaffSliderControlItem.ID.allCases
        .filter { $0.sectionID == sectionID }
        .map {
            StaffControlRow.slider(
                makeSlider(
                    for: $0,
                    displayState: displayState
                )
            )
        }

    return optionRows + sliderRows
}

private static func makeOption(
    for optionID: StaffOptionControlItem.ID,
    displayState: StaffDisplayState
) -> StaffOptionControlItem {
    switch optionID {
    case .clef:
        return StaffOptionControlItem(
            id: optionID,
            title: optionID.title,
            accessibilityLabel: optionID.accessibilityLabel,
            choices: StaffClef.allCases.map {
                StaffOptionChoice(
                    clef: $0,
                    title: $0.title,
                    isSelected: $0 == displayState.configuration.clef
                )
            },
            isEnabled: true
        )
    }
}

private static func resolvedValue(
    for sliderID: StaffSliderControlItem.ID,
    displayState: StaffDisplayState
) -> CGFloat {
    switch sliderID {
    case .clefScale:
        return displayState.configuration.layoutMetrics.clefScale
    case .clefAnchorYOffset:
        return displayState.configuration.clefAnchorLogicalDownwardShiftRatio(
            for: displayState.configuration.clef
        )
    }
}
```

### iOS / macOS 面板新增 clef 选项控件，并复用原有事件上送链路

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift
// 函数名：applyModel(), syncControlRows(in:for:), controlView(for:), OptionRowView.handleSelectionChanged(_:), makeEvent(value:)
// 功能说明：修改后 iOS 面板按 `StaffControlRow` 分发控件；
// 新增 `OptionRowView` 承载 `UISegmentedControl`，并把选中的 clef 通过 `StaffControlEvent.setClef` 回传。
private var controlViewsByID: [StaffControlRowID: UIView] = [:]

private func applyModel() {
    removeObsoleteControlViews(notIn: Set(model.rows.map(\.id)))
    removeObsoleteSectionViews(notIn: Set(model.sections.map(\.id)))
}

private func syncControlRows(
    in sectionView: SectionView,
    for section: StaffControlSection
) {
    let orderedRows = section.rows.map { row -> UIView in
        controlView(for: row)
    }

    sectionView.rows = orderedRows
}

private func controlView(for row: StaffControlRow) -> UIView {
    switch row {
    case let .option(item):
        let rowView = OptionRowView()
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        return rowView
    case let .slider(item):
        let rowView = SliderRowView()
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        return rowView
    }
}

private final class OptionRowView: UIView {
    func apply(item: StaffOptionControlItem) {
        titleLabel.text = item.title
        choices = item.choices
        segmentedControl.removeAllSegments()

        var selectedSegmentIndex = UISegmentedControl.noSegment
        for (index, choice) in item.choices.enumerated() {
            segmentedControl.insertSegment(
                withTitle: choice.title,
                at: index,
                animated: false
            )

            if choice.isSelected {
                selectedSegmentIndex = index
            }
        }

        segmentedControl.selectedSegmentIndex = selectedSegmentIndex
    }

    @objc
    private func handleSelectionChanged(_ sender: UISegmentedControl) {
        onEvent?(.setClef(choices[sender.selectedSegmentIndex].clef))
    }
}

private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .clefScale:
            return .setClefScale(value)
        case .clefAnchorYOffset:
            return .setClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift
// 函数名：applyModel(), syncControlRows(in:for:), controlView(for:), OptionRowView.handleSelectionChanged(_:), makeEvent(value:)
// 功能说明：修改后 macOS 面板与 iOS 对称；
// 使用 `NSSegmentedControl` 承载 clef 选项，并继续复用原有 `onEvent` 回调链路。
private var controlViewsByID: [StaffControlRowID: NSView] = [:]

private func applyModel() {
    removeObsoleteControlViews(notIn: Set(model.rows.map(\.id)))
    removeObsoleteSectionViews(notIn: Set(model.sections.map(\.id)))
}

private func syncControlRows(
    in sectionView: SectionView,
    for section: StaffControlSection
) {
    let orderedRows = section.rows.map { row -> NSView in
        controlView(for: row)
    }

    sectionView.rows = orderedRows
}

private func controlView(for row: StaffControlRow) -> NSView {
    switch row {
    case let .option(item):
        let rowView = OptionRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        return rowView
    case let .slider(item):
        let rowView = SliderRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        return rowView
    }
}

private final class OptionRowView: NSView {
    func apply(item: StaffOptionControlItem) {
        titleLabel.stringValue = item.title
        choices = item.choices
        segmentedControl.segmentCount = item.choices.count

        var selectedSegment = -1
        for (index, choice) in item.choices.enumerated() {
            segmentedControl.setLabel(choice.title, forSegment: index)

            if choice.isSelected {
                selectedSegment = index
            }
        }

        segmentedControl.selectedSegment = selectedSegment
    }

    @objc
    private func handleSelectionChanged(_ sender: NSSegmentedControl) {
        onEvent?(.setClef(choices[sender.selectedSegment].clef))
    }
}

private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .clefScale:
            return .setClefScale(value)
        case .clefAnchorYOffset:
            return .setClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

### 共享 Staff 渲染链补齐 bass clef 语义、glyph 和 CoreText 对齐

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：clefAnchorLogicalDownwardShiftRatio(for:), setClefAnchorLogicalDownwardShiftRatio(_:for:)
// 功能说明：修改后配置层真正支持 `treble` / `bass` 两种 clef，
// 并为两个 clef 分别保存独立的 anchor Y 偏移值。
enum StaffClef: CaseIterable, Equatable, Hashable, Sendable {
    case treble
    case bass

    var title: String {
        switch self {
        case .treble:
            return "Treble"
        case .bass:
            return "Bass"
        }
    }
}

struct StaffConfiguration: Equatable, Sendable {
    var clef: StaffClef
    var layoutMetrics: LayoutMetrics
    var trebleClefAnchorLogicalDownwardShiftRatio: CGFloat
    var bassClefAnchorLogicalDownwardShiftRatio: CGFloat
    var debugOptions: DebugOptions

    func clefAnchorLogicalDownwardShiftRatio(for clef: StaffClef) -> CGFloat {
        switch clef {
        case .treble:
            return trebleClefAnchorLogicalDownwardShiftRatio
        case .bass:
            return bassClefAnchorLogicalDownwardShiftRatio
        }
    }

    mutating func setClefAnchorLogicalDownwardShiftRatio(
        _ value: CGFloat,
        for clef: StaffClef
    ) {
        switch clef {
        case .treble:
            trebleClefAnchorLogicalDownwardShiftRatio = value
        case .bass:
            bassClefAnchorLogicalDownwardShiftRatio = value
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数名：无（类型定义片段）, clef（计算属性）
// 功能说明：修改后 scene 语义层新增 bass 的锚点语义和 glyph symbol，
// 并能从 `ClefAnchor.Semantic` 反查所属 clef，供 renderer 读取对应配置值。
struct ClefAnchor: Equatable, Sendable {
    enum Semantic: Equatable, Sendable {
        case trebleGLine
        case bassFLine
    }
}

enum StaffGlyphSymbolID: Equatable, Sendable {
    case trebleClef
    case bassClef
}

extension ClefAnchor.Semantic {
    var clef: StaffClef {
        switch self {
        case .trebleGLine:
            return .treble
        case .bassFLine:
            return .bass
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数名：clefAnchor(for:)
// 功能说明：修改后几何层为 bass clef 生成独立的逻辑锚点；
// 这里把 bass 的语义锚点对到 F line，对应五线谱第 2 条线。
func clefAnchor(for clef: StaffClef) -> ClefAnchor {
    switch clef {
    case .treble:
        return ClefAnchor(
            point: CGPoint(
                x: clefAreaRect.midX,
                y: lineY(at: 3) ?? staffRect.midY
            ),
            semantic: .trebleGLine,
            targetHeight: max(staffRect.height * configuration.layoutMetrics.clefScale, 1)
        )
    case .bass:
        return ClefAnchor(
            point: CGPoint(
                x: clefAreaRect.midX,
                y: lineY(at: 1) ?? staffRect.midY
            ),
            semantic: .bassFLine,
            targetHeight: max(staffRect.height * configuration.layoutMetrics.clefScale, 1)
        )
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数名：symbolID(for:)
// 功能说明：修改后 SceneProvider 能把 `StaffClef.bass` 投影成 `StaffGlyphSymbolID.bassClef`。
private func symbolID(for clef: StaffClef) -> StaffGlyphSymbolID {
    switch clef {
    case .treble:
        return .trebleClef
    case .bass:
        return .bassClef
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift
// 函数名：musicGlyph（计算属性）
// 功能说明：修改后 glyph 表新增 bass clef 的 SMuFL `fClef` 标量值 `0xE062`，
// CoreText renderer 可以直接通过现有字体注册链路取到 bass glyph。
struct MusicGlyph: Equatable, Sendable {
    static let trebleClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE050
    )

    static let bassClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE062
    )
}

extension StaffGlyphSymbolID {
    var musicGlyph: MusicGlyph {
        switch self {
        case .trebleClef:
            return .trebleClef
        case .bassClef:
            return .bassClef
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：anchorMetrics(for:geometry:)
// 功能说明：修改后 renderer 会先按语义 clef 读取当前 clef 的配置偏移，
// 再分别套用 treble / bass 的 optical bounds 对齐经验值。
private func anchorMetrics(
    for semantic: ClefAnchor.Semantic,
    geometry: StaffGeometry
) -> AnchorMetrics {
    let downwardShiftRatio = geometry.configuration.clefAnchorLogicalDownwardShiftRatio(
        for: semantic.clef
    )

    switch semantic {
    case .trebleGLine:
        return AnchorMetrics(
            xRatio: 0.5,
            yRatio: 0.56 - downwardShiftRatio
        )
    case .bassFLine:
        return AnchorMetrics(
            xRatio: 0.74,
            yRatio: 0.5 - downwardShiftRatio
        )
    }
}
```

## 结果说明

- iOS / macOS 两个 `StaffControlPanel` 面板里都新增了 clef 类型切换项
- 切换项现在可以在 `Treble` 和 `Bass` 之间切换
- `Scale` 滑块继续是共用参数
- `Anchor Y Offset` 滑块改为编辑“当前 clef”的独立 offset
- 共享 `Staff` 渲染链已经补齐 `bass clef` 的 scene、glyph、anchor 和 CoreText 对齐逻辑
- 控制器层没有额外改动，继续复用既有 `onEvent -> StaffDisplayState.apply(_:)` 状态流

## 验证情况

- `ReadLints` 检查上述修改文件，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

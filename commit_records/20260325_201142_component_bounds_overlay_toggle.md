# 20260325_201142_component_bounds_overlay_toggle

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_201142`
- 记录范围：为指板组件与五线谱组件增加绿色边界描线，并在统一设置面板中增加控制开关
- 本次目标：让主界面的 `fretboardView`、`staffView` 可以显式描出组件边界，同时保持现有“统一 settings 域模型 -> snapshot builder -> 平台设置面板 -> 控制器事件回写”的链路不分叉
- 根因结论：现有统一设置面板只有 `choice` / `slider` 两种行模型，没有真正的 `toggle` 原语；如果只在某个平台临时硬编码一个开关，会把这次需求绕过共享域模型，后续 iOS/macOS 会再次分叉。因此这次不是局部打补丁，而是把“组件边界描线”提升为共享显示状态，并把统一 settings 模型扩成支持 `toggle row`
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 为 `FretboardDisplayState` 与 `StaffDisplayState` 新增 `showsComponentBoundsOverlay`，把组件边界描线状态收口到共享显示状态层。
2. 为 `SettingsPanelModel` 新增 `debug` section、`toggle` row、`SettingsToggleID` 与 `SettingsPanelEvent.setToggleValue`，补齐统一设置域缺失的开关语义。
3. 为 `SettingsPanelSnapshotBuilder` 增加 `toggle row` 生成逻辑，使 settings 面板快照能从共享状态直接派生出“Component Bounds”开关。
4. 在 `iOSSettingsPanelView` / `macOSSettingsPanelView` 中增加真正的开关行控件，而不是复用 chip 或 segmented 做伪开关。
5. 在 `iOSFretboardView` / `iOSStaffView` / `macOSFretboardView` / `macOSStaffView` 中按状态绘制绿色边框，并按 `contentsScale` 推导线宽，避免 Retina / 非 Retina 下线宽失真。
6. 在 `iOSViewController` / `macOSViewController` 中把共享状态继续转发到平台视图，维持现有统一事件流。
7. 完成相关文件的 lint 检查和 `swiftc -typecheck` 静态校验。

## 修改 1：共享显示状态补充“组件边界描线”语义

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数/成员: FretboardDisplayState
// 功能说明: 修改前共享指板显示状态只管理指板配置、标签显示和 vertical host 高度比例，没有组件边界描线状态。
struct FretboardDisplayState: Equatable, Sendable {
    static let verticalHostHeightRatioRange: ClosedRange<CGFloat> = 0.35...0.9
    static let defaultVerticalHostHeightRatio: CGFloat = 0.72

    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool
    private(set) var verticalHostHeightRatio: CGFloat

    init(
        configuration: FretboardConfiguration,
        visibility: NoteLabelVisibility = .all,
        spelling: PitchSpelling = .sharp,
        showsOctave: Bool = true,
        verticalHostHeightRatio: CGFloat = defaultVerticalHostHeightRatio
    ) {
        self.configuration = configuration
        self.visibility = visibility
        self.spelling = spelling
        self.showsOctave = showsOctave
        self.verticalHostHeightRatio = Self.clampedVerticalHostHeightRatio(
            verticalHostHeightRatio
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState.init(configuration:)
// 功能说明: 修改前共享五线谱显示状态只保存 StaffConfiguration，平台层没有统一的组件边界描线开关可读。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration

    static let `default` = StaffDisplayState(
        configuration: StaffConfiguration()
    )

    init(configuration: StaffConfiguration) {
        self.configuration = configuration
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数/成员: FretboardDisplayState.init(...)
// 功能说明: 修改后把组件边界描线显式提升为共享页面展示状态，避免平台控制器各自维护一份临时布尔值。
struct FretboardDisplayState: Equatable, Sendable {
    static let verticalHostHeightRatioRange: ClosedRange<CGFloat> = 0.35...0.9
    static let defaultVerticalHostHeightRatio: CGFloat = 0.72

    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool
    // 组件边界描线属于页面级展示状态，不进入指板几何配置本身。
    var showsComponentBoundsOverlay: Bool
    private(set) var verticalHostHeightRatio: CGFloat

    init(
        configuration: FretboardConfiguration,
        visibility: NoteLabelVisibility = .all,
        spelling: PitchSpelling = .sharp,
        showsOctave: Bool = true,
        showsComponentBoundsOverlay: Bool = false,
        verticalHostHeightRatio: CGFloat = defaultVerticalHostHeightRatio
    ) {
        self.configuration = configuration
        self.visibility = visibility
        self.spelling = spelling
        self.showsOctave = showsOctave
        self.showsComponentBoundsOverlay = showsComponentBoundsOverlay
        self.verticalHostHeightRatio = Self.clampedVerticalHostHeightRatio(
            verticalHostHeightRatio
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState.init(configuration:showsComponentBoundsOverlay:)
// 功能说明: 修改后五线谱也持有同一语义的组件边界描线状态，让 settings 事件可以同时驱动两类组件。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration
    // 组件边界描线属于平台展示状态，不进入五线谱 scene/config 语义。
    var showsComponentBoundsOverlay: Bool

    static let `default` = StaffDisplayState(
        configuration: StaffConfiguration()
    )

    init(
        configuration: StaffConfiguration,
        showsComponentBoundsOverlay: Bool = false
    ) {
        self.configuration = configuration
        self.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    }
}
```

## 修改 2：统一 settings 域从“只有 choice / slider”升级为“支持 toggle row”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsRowID / SettingsSectionID / SettingsPanelEvent
// 功能说明: 修改前统一 settings 域只有 choice 与 slider 两类行；layout 是最后一个 section，事件层也没有 toggle 事件。
enum SettingsRowID: Equatable, Hashable, Sendable {
    case choice(SettingsChoiceRowID)
    case slider(SettingsSliderID)
}

enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case layout

    var rowIDs: [SettingsRowID] {
        switch self {
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
        }
    }
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case setSliderValue(SettingsSliderID, CGFloat)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsRowID / SettingsSectionID / SettingsToggleID / SettingsPanelEvent
// 功能说明: 修改后统一 settings 域新增 debug section、toggle row 和 setToggleValue 事件，开关语义不再绕过共享模型。
enum SettingsRowID: Equatable, Hashable, Sendable {
    case choice(SettingsChoiceRowID)
    case slider(SettingsSliderID)
    case toggle(SettingsToggleID)
}

enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case layout
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
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

enum SettingsToggleID: CaseIterable, Equatable, Hashable, Sendable {
    case showsComponentBounds

    var title: String {
        switch self {
        case .showsComponentBounds:
            return "Component Bounds"
        }
    }

    func resolvedValue(
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> Bool {
        switch self {
        case .showsComponentBounds:
            return fretboardDisplayState.showsComponentBoundsOverlay
                || staffDisplayState.showsComponentBoundsOverlay
        }
    }

    func apply(value: Bool, to displayState: inout FretboardDisplayState) {
        switch self {
        case .showsComponentBounds:
            displayState.showsComponentBoundsOverlay = value
        }
    }

    func apply(value: Bool, to displayState: inout StaffDisplayState) {
        switch self {
        case .showsComponentBounds:
            displayState.showsComponentBoundsOverlay = value
        }
    }
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)
}
```

## 修改 3：SnapshotBuilder 把 toggle row 纳入统一快照生成

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeRow(id:fretboardDisplayState:staffDisplayState:)
// 功能说明: 修改前 snapshot builder 只能把 choice / slider 两类共享行模型转换成 settings panel rows。
private static func makeRow(
    id: SettingsRowID,
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState
) -> SettingsRow? {
    switch id {
    case let .choice(choiceRowID):
        return .choice(
            makeChoiceRow(
                id: choiceRowID,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        )
    case let .slider(sliderID):
        guard shouldInclude(
            sliderID: sliderID,
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        ) else {
            return nil
        }

        return .slider(
            makeSliderRow(
                id: sliderID,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeRow(...) / makeToggleRow(...)
// 功能说明: 修改后 snapshot builder 可以从共享状态派生 toggle row，让“Component Bounds”开关随状态自动刷新。
private static func makeRow(
    id: SettingsRowID,
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState
) -> SettingsRow? {
    switch id {
    case let .choice(choiceRowID):
        return .choice(
            makeChoiceRow(
                id: choiceRowID,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        )
    case let .slider(sliderID):
        guard shouldInclude(
            sliderID: sliderID,
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        ) else {
            return nil
        }

        return .slider(
            makeSliderRow(
                id: sliderID,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        )
    case let .toggle(toggleID):
        return .toggle(
            makeToggleRow(
                id: toggleID,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        )
    }
}

private static func makeToggleRow(
    id: SettingsToggleID,
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState
) -> SettingsToggleRow {
    SettingsToggleRow(
        id: id,
        title: id.title,
        accessibilityLabel: id.accessibilityLabel,
        isOn: id.resolvedValue(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        ),
        isEnabled: id.isEnabled(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        )
    )
}
```

## 修改 4：iOS / macOS 统一设置面板增加真正的开关行控件

### 修改前（iOS）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/成员: iOSSettingsPanelView.controlView(for:)
// 功能说明: 修改前 iOS 设置面板只认识 choice row 与 slider row，没有 toggle row 分支。
private func controlView(for row: SettingsRow) -> UIView {
    switch row {
    case let .choice(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ChoiceRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = ChoiceRowView()
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    case let .slider(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? SliderRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = SliderRowView()
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    }
}
```

### 修改后（iOS）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/成员: iOSSettingsPanelView.controlView(for:) / ToggleRowView
// 功能说明: 修改后 iOS 设置面板新增 ToggleRowView，并把 UISwitch 的 valueChanged 统一上抛为 SettingsPanelEvent.setToggleValue。
private func controlView(for row: SettingsRow) -> UIView {
    switch row {
    case let .choice(item):
        // 其他未改分支省略
        let rowView = ChoiceRowView()
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[row.id] = rowView
        return rowView
    case let .slider(item):
        // 其他未改分支省略
        let rowView = SliderRowView()
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[row.id] = rowView
        return rowView
    case let .toggle(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ToggleRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = ToggleRowView()
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    }
}

private final class ToggleRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var toggleID: SettingsToggleID?
    private var isApplyingItem = false
    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let spacerView = UIView()
    private let toggleSwitch = UISwitch()

    func apply(item: SettingsToggleRow) {
        toggleID = item.id
        titleLabel.text = item.title
        toggleSwitch.accessibilityLabel = item.accessibilityLabel
        toggleSwitch.isEnabled = item.isEnabled

        isApplyingItem = true
        toggleSwitch.setOn(item.isOn, animated: false)
        isApplyingItem = false
    }

    @objc
    private func handleToggleValueChanged(_ sender: UISwitch) {
        guard
            !isApplyingItem,
            let toggleID
        else {
            return
        }

        onEvent?(.setToggleValue(toggleID, sender.isOn))
    }
}
```

### 修改前（macOS）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数/成员: macOSSettingsPanelView.controlView(for:)
// 功能说明: 修改前 macOS 设置面板同样没有 toggle row，统一域新增开关后无法在平台层落地。
private func controlView(for row: SettingsRow) -> NSView {
    switch row {
    case let .choice(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ChoiceRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = ChoiceRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    case let .slider(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? SliderRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = SliderRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    }
}
```

### 修改后（macOS）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数/成员: macOSSettingsPanelView.controlView(for:) / ToggleRowView
// 功能说明: 修改后 macOS 设置面板同步新增 NSSwitch 版 ToggleRowView，保证双平台 settings 行能力保持一致。
private func controlView(for row: SettingsRow) -> NSView {
    switch row {
    case let .choice(item):
        // 其他未改分支省略
        let rowView = ChoiceRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[row.id] = rowView
        return rowView
    case let .slider(item):
        // 其他未改分支省略
        let rowView = SliderRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[row.id] = rowView
        return rowView
    case let .toggle(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ToggleRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = ToggleRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    }
}

private final class ToggleRowView: NSView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var toggleID: SettingsToggleID?
    private var isApplyingItem = false
    private let contentStackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let spacerView = NSView()
    private let toggleSwitch = NSSwitch()

    func apply(item: SettingsToggleRow) {
        toggleID = item.id
        titleLabel.stringValue = item.title
        toggleSwitch.toolTip = item.accessibilityLabel
        toggleSwitch.isEnabled = item.isEnabled

        isApplyingItem = true
        toggleSwitch.state = item.isOn ? .on : .off
        isApplyingItem = false
    }

    @objc
    private func handleToggleValueChanged(_ sender: NSSwitch) {
        guard
            !isApplyingItem,
            let toggleID
        else {
            return
        }

        onEvent?(.setToggleValue(toggleID, sender.state == .on))
    }
}
```

## 修改 5：平台视图按共享状态绘制绿色组件边界

### 修改前（iOS 指板 / 五线谱）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数/成员: iOSFretboardView
// 功能说明: 修改前 iOS 指板视图没有任何组件边界描线状态，也没有边框更新逻辑。
final class iOSFretboardView: UIView {
    private var lastMeasuredPrimaryDimension: CGFloat?

    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            fretboardLayer.contentProvider = contentProvider
        }
    }

    private func updateContentsScale() {
        fretboardLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift
// 函数/成员: iOSStaffView.updateContentsScale()
// 功能说明: 修改前 iOS 五线谱视图只同步 contentsScale，不会根据共享状态绘制组件边界。
private func updateContentsScale() {
    staffRootLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
}
```

### 修改后（iOS 指板 / 五线谱）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数/成员: iOSFretboardView.showsComponentBoundsOverlay / updateComponentBoundsOverlay()
// 功能说明: 修改后 iOS 指板视图根据共享状态切换 CALayer 边框，并按 contentsScale 推导线宽，避免高分屏下边框过粗。
final class iOSFretboardView: UIView {
    private var lastMeasuredPrimaryDimension: CGFloat?

    var configuration: FretboardConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            fretboardLayer.contentProvider = contentProvider
        }
    }

    var showsComponentBoundsOverlay = false {
        didSet {
            guard oldValue != showsComponentBoundsOverlay else {
                return
            }

            updateComponentBoundsOverlay()
        }
    }

    private func updateContentsScale() {
        fretboardLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
        updateComponentBoundsOverlay()
    }

    private func updateComponentBoundsOverlay() {
        fretboardLayer.borderColor = UIColor.systemGreen.cgColor
        fretboardLayer.borderWidth = showsComponentBoundsOverlay
            ? resolvedComponentBoundsOverlayLineWidth
            : 0
    }

    private var resolvedComponentBoundsOverlayLineWidth: CGFloat {
        max(1 / max(fretboardLayer.contentsScale, 1), 0.5)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift
// 函数/成员: iOSStaffView.showsComponentBoundsOverlay / updateComponentBoundsOverlay()
// 功能说明: 修改后 iOS 五线谱视图也按同样语义绘制绿色边框，确保主页面两个组件的边界可同时可视化。
final class iOSStaffView: UIView {
    var showsComponentBoundsOverlay = false {
        didSet {
            guard oldValue != showsComponentBoundsOverlay else {
                return
            }

            updateComponentBoundsOverlay()
        }
    }

    private func updateContentsScale() {
        staffRootLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
        updateComponentBoundsOverlay()
    }

    private func updateComponentBoundsOverlay() {
        staffRootLayer.borderColor = UIColor.systemGreen.cgColor
        staffRootLayer.borderWidth = showsComponentBoundsOverlay
            ? resolvedComponentBoundsOverlayLineWidth
            : 0
    }

    private var resolvedComponentBoundsOverlayLineWidth: CGFloat {
        max(1 / max(staffRootLayer.contentsScale, 1), 0.5)
    }
}
```

### 修改前（macOS 指板 / 五线谱）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数/成员: macOSFretboardView.updateContentsScale()
// 功能说明: 修改前 macOS 指板视图同样只有 contentsScale 更新，没有组件边界描线逻辑。
private func updateContentsScale() {
    fretboardLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift
// 函数/成员: macOSStaffView.updateContentsScale()
// 功能说明: 修改前 macOS 五线谱视图不会根据共享状态绘制绿色边框。
private func updateContentsScale() {
    staffRootLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
}
```

### 修改后（macOS 指板 / 五线谱）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数/成员: macOSFretboardView.showsComponentBoundsOverlay / updateComponentBoundsOverlay()
// 功能说明: 修改后 macOS 指板视图按共享状态绘制 NSColor.systemGreen 边框，并统一按 backing scale 计算线宽。
var showsComponentBoundsOverlay = false {
    didSet {
        guard oldValue != showsComponentBoundsOverlay else {
            return
        }

        updateComponentBoundsOverlay()
    }
}

private func updateContentsScale() {
    fretboardLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    updateComponentBoundsOverlay()
}

private func updateComponentBoundsOverlay() {
    fretboardLayer.borderColor = NSColor.systemGreen.cgColor
    fretboardLayer.borderWidth = showsComponentBoundsOverlay
        ? resolvedComponentBoundsOverlayLineWidth
        : 0
}

private var resolvedComponentBoundsOverlayLineWidth: CGFloat {
    max(1 / max(fretboardLayer.contentsScale, 1), 0.5)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift
// 函数/成员: macOSStaffView.showsComponentBoundsOverlay / updateComponentBoundsOverlay()
// 功能说明: 修改后 macOS 五线谱视图与指板视图保持相同边界描线语义，避免平台侧出现行为不一致。
var showsComponentBoundsOverlay = false {
    didSet {
        guard oldValue != showsComponentBoundsOverlay else {
            return
        }

        updateComponentBoundsOverlay()
    }
}

private func updateContentsScale() {
    staffRootLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    updateComponentBoundsOverlay()
}

private func updateComponentBoundsOverlay() {
    staffRootLayer.borderColor = NSColor.systemGreen.cgColor
    staffRootLayer.borderWidth = showsComponentBoundsOverlay
        ? resolvedComponentBoundsOverlayLineWidth
        : 0
}

private var resolvedComponentBoundsOverlayLineWidth: CGFloat {
    max(1 / max(staffRootLayer.contentsScale, 1), 0.5)
}
```

## 修改 6：控制器继续沿用统一状态分发，把开关结果转发给平台视图

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSViewController.applyFretboardDisplayState() / applyStaffDisplayState()
// 功能说明: 修改前控制器只把 configuration 和 provider / sceneProvider 下发给平台视图，没有组件边界描线状态转发。
private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}

private func applyStaffDisplayState() {
    staffView.configuration = staffDisplayState.configuration
    staffView.sceneProvider = staffDisplayState.sceneProvider
    applySettingsPanelState()
    updateLayoutIfNeeded()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: macOSViewController.applyFretboardDisplayState() / applyStaffDisplayState()
// 功能说明: 修改前 macOS 控制器与 iOS 一样，没有把共享开关状态传递给平台视图。
private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}

private func applyStaffDisplayState() {
    staffView.configuration = staffDisplayState.configuration
    staffView.sceneProvider = staffDisplayState.sceneProvider
    applySettingsPanelState()
    updateLayoutIfNeeded()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSViewController.applyFretboardDisplayState() / applyStaffDisplayState()
// 功能说明: 修改后 iOS 控制器继续沿用共享状态分发，只新增组件边界描线状态的转发，不引入新的平台级临时状态。
private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}

private func applyStaffDisplayState() {
    staffView.configuration = staffDisplayState.configuration
    staffView.sceneProvider = staffDisplayState.sceneProvider
    staffView.showsComponentBoundsOverlay = staffDisplayState.showsComponentBoundsOverlay
    applySettingsPanelState()
    updateLayoutIfNeeded()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: macOSViewController.applyFretboardDisplayState() / applyStaffDisplayState()
// 功能说明: 修改后 macOS 控制器与 iOS 保持同一条共享事件回写链，不额外分叉控制逻辑。
private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}

private func applyStaffDisplayState() {
    staffView.configuration = staffDisplayState.configuration
    staffView.sceneProvider = staffDisplayState.sceneProvider
    staffView.showsComponentBoundsOverlay = staffDisplayState.showsComponentBoundsOverlay
    applySettingsPanelState()
    updateLayoutIfNeeded()
}
```

## 验证结果

1. `ReadLints` 检查本次修改文件，无新增 lint 问题。
2. 执行 `swiftc -typecheck` 覆盖项目内 Swift 源文件，结果通过。
3. 从结构上确认：
   - settings 面板新增 `Debug` section 与 `Component Bounds` 开关；
   - 开关事件通过 `SettingsPanelEvent.setToggleValue` 同时写回 `FretboardDisplayState` 与 `StaffDisplayState`；
   - `iOS/macOS` 两端的 `fretboardView` 与 `staffView` 都会依据共享状态显示或隐藏绿色边界。

## 结果说明

- 这次不是把边框硬编码在某个平台 view 上，而是先补齐统一 settings 域缺失的 `toggle` 语义，再把“组件边界描线”作为共享显示状态贯穿到 `snapshot builder`、平台设置面板和控制器分发链路。
- 因此，这个开关已经成为统一设置系统的一部分，后续如果还要继续添加别的 debug 开关，可以沿用同一套 `SettingsToggleID -> SettingsToggleRow -> SettingsPanelEvent.setToggleValue` 的路径继续扩展，而不需要再回到平台层做临时拼接。

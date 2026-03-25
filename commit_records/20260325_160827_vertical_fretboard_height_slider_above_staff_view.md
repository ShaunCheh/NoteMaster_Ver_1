# 20260325_160827_vertical_fretboard_height_slider_above_staff_view

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_160827`
- 记录范围：竖向指板模式新增高度滑块，并将滑块放到 `staffView` 上方
- 本次目标：让竖向指板的外层 host 高度由共享状态驱动，并通过独立的控制面板在 iOS / macOS 上同步生效，同时不把页面布局状态混入 `FretboardConfiguration`

## 本次完成的修改

1. 在 `FretboardDisplayState` 中新增 `verticalHostHeightRatio`、默认值和 clamp 逻辑，让竖向 host 高度比例成为共享页面状态。
2. 新增 `FretboardControlPanelModel.swift` 与 `FretboardControlPanelSnapshotBuilder.swift`，为竖向高度滑块建立共享事件流与快照构建层。
3. 新增 `iOSFretboardControlPanelView.swift` 与 `macOSFretboardControlPanelView.swift`，复用现有 staff slider 的薄视图模式承接滑块 UI。
4. 在 `iOSViewController.swift` 与 `macOSViewController.swift` 中把新面板插到 `staffView` 上方，并将竖向 host 高度约束改为按共享状态重建。
5. 更新 `FretboardValidation.manualChecklist(...)`，补充滑块和模式切换的手工回归项。

## 修改 1：`FretboardDisplayState` 新增竖向 host 高度比例

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数/成员: FretboardDisplayState.init(...), FretboardDisplayState.setDisplayMode(_:)
// 功能说明: 修改前共享状态只管理指板内容与显示模式，不包含竖向 host 高度比例；页面高度占比仍散落在平台控制器常量里。
struct FretboardDisplayState: Equatable, Sendable {
    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool

    static let `default` = FretboardDisplayState(
        configuration: FretboardConfiguration(
            displayMode: .horizontal,
            tuning: .standard(for: .guitar6),
            maxFret: 12
        )
    )

    init(
        configuration: FretboardConfiguration,
        visibility: NoteLabelVisibility = .all,
        spelling: PitchSpelling = .sharp,
        showsOctave: Bool = true
    ) {
        self.configuration = configuration
        self.visibility = visibility
        self.spelling = spelling
        self.showsOctave = showsOctave
    }

    mutating func setDisplayMode(_ displayMode: FretboardDisplayMode) {
        self.displayMode = displayMode
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数/成员: FretboardDisplayState.init(...), FretboardDisplayState.setVerticalHostHeightRatio(_:), clampedVerticalHostHeightRatio(_:)
// 功能说明: 修改后 vertical host 高度比例成为共享页面状态，默认值与取值范围统一收口在共享层，平台侧只消费状态，不再各自解释 clamp 规则。
struct FretboardDisplayState: Equatable, Sendable {
    static let verticalHostHeightRatioRange: ClosedRange<CGFloat> = 0.35...0.9
    static let defaultVerticalHostHeightRatio: CGFloat = 0.72

    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool
    private(set) var verticalHostHeightRatio: CGFloat

    static let `default` = FretboardDisplayState(
        configuration: FretboardConfiguration(
            displayMode: .horizontal,
            tuning: .standard(for: .guitar6),
            maxFret: 12
        ),
        verticalHostHeightRatio: defaultVerticalHostHeightRatio
    )

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

    mutating func setVerticalHostHeightRatio(_ ratio: CGFloat) {
        verticalHostHeightRatio = Self.clampedVerticalHostHeightRatio(ratio)
    }

    private static func clampedVerticalHostHeightRatio(_ ratio: CGFloat) -> CGFloat {
        min(
            max(ratio, verticalHostHeightRatioRange.lowerBound),
            verticalHostHeightRatioRange.upperBound
        )
    }
}
```

## 修改 2：为指板高度滑块建立共享控制模型与快照构建层

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: Layout.verticalFretboardHostHeightRatio
// 功能说明: 修改前竖向高度比例是平台私有常量；项目中不存在 FretboardControlPanelModel / SnapshotBuilder，无法通过共享事件流驱动滑块。
private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let verticalFretboardHostHeightRatio: CGFloat = 0.72
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelModel.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前没有独立的指板连续控制模型，也没有把滑块事件映射回 FretboardDisplayState 的共享入口。
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前没有针对竖向指板高度滑块的快照构建器，平台层无法直接消费统一的 panel model。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelModel.swift
// 函数/成员: FretboardControlEvent.apply(to:), FretboardDisplayState.apply(_:)
// 功能说明: 修改后共享层定义了指板控制面板的 section / row / slider / event，滑块值可以直接作用到 FretboardDisplayState。
enum FretboardControlEvent: Equatable, Sendable {
    case setVerticalHostHeightRatio(CGFloat)

    func apply(to displayState: inout FretboardDisplayState) {
        switch self {
        case let .setVerticalHostHeightRatio(value):
            displayState.setVerticalHostHeightRatio(value)
        }
    }
}

struct FretboardSliderControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case verticalHostHeightRatio

        var range: ClosedRange<CGFloat> {
            switch self {
            case .verticalHostHeightRatio:
                return FretboardDisplayState.verticalHostHeightRatioRange
            }
        }
    }
}

extension FretboardDisplayState {
    mutating func apply(_ event: FretboardControlEvent) {
        event.apply(to: &self)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift
// 函数/成员: FretboardControlPanelSnapshotBuilder.makeModel(from:), makeSlider(for:displayState:)
// 功能说明: 修改后只有 vertical 模式才生成滑块面板；滑块的值、显示文本、是否可用都从共享状态统一派生。
enum FretboardControlPanelSnapshotBuilder {
    static func makeModel(from displayState: FretboardDisplayState) -> FretboardControlPanelModel {
        guard displayState.displayMode == .vertical else {
            return .empty
        }

        return FretboardControlPanelModel(
            sections: FretboardControlSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }

    private static func makeSlider(
        for sliderID: FretboardSliderControlItem.ID,
        displayState: FretboardDisplayState
    ) -> FretboardSliderControlItem {
        let range = sliderID.range
        let value = displayState.verticalHostHeightRatio
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)

        return FretboardSliderControlItem(
            id: sliderID,
            title: sliderID.title,
            accessibilityLabel: sliderID.accessibilityLabel,
            value: clampedValue,
            range: range,
            displayValue: String(format: "%.0f%%", Double(clampedValue * 100)),
            isEnabled: displayState.displayMode == .vertical
        )
    }
}
```

## 修改 3：新增 iOS / macOS 指板控制面板薄视图

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSFretboardControlPanelView.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 iOS 没有独立的指板滑块面板，竖向高度无法复用 staff control panel 的 row/view 事件模式。
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSFretboardControlPanelView.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 macOS 同样没有独立的指板滑块面板，缺少从 NSSlider 回传共享事件的桥接层。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSFretboardControlPanelView.swift
// 函数/成员: SliderRowView.apply(item:), SliderRowView.handleSliderValueChanged(_:), FretboardSliderControlItem.ID.makeEvent(value:)
// 功能说明: 修改后 iOS 薄视图负责把共享 slider item 渲染成 UISlider，并把 valueChanged 事件映射回 FretboardControlEvent。
private final class SliderRowView: UIView {
    var onEvent: ((FretboardControlEvent) -> Void)?

    private var sliderID: FretboardSliderControlItem.ID?
    private var isApplyingItem = false
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()

    func apply(item: FretboardSliderControlItem) {
        sliderID = item.id
        titleLabel.text = item.title
        valueLabel.text = item.displayValue
        slider.accessibilityLabel = item.accessibilityLabel
        slider.accessibilityIdentifier = "fretboard-control-slider-\(String(describing: item.id))"
        slider.isEnabled = item.isEnabled
        isUserInteractionEnabled = item.isEnabled

        isApplyingItem = true
        slider.minimumValue = Float(item.range.lowerBound)
        slider.maximumValue = Float(item.range.upperBound)
        slider.setValue(Float(item.value), animated: false)
        isApplyingItem = false
    }

    @objc
    private func handleSliderValueChanged(_ sender: UISlider) {
        guard
            !isApplyingItem,
            let sliderID
        else {
            return
        }

        let event = sliderID.makeEvent(value: CGFloat(sender.value))
        onEvent?(event)
    }
}

private extension FretboardSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> FretboardControlEvent {
        switch self {
        case .verticalHostHeightRatio:
            return .setVerticalHostHeightRatio(value)
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSFretboardControlPanelView.swift
// 函数/成员: SliderRowView.apply(item:), SliderRowView.handleSliderValueChanged(_:), FretboardSliderControlItem.ID.makeEvent(value:)
// 功能说明: 修改后 macOS 薄视图对称复用同一套共享模型，把 NSSlider 的实时变化映射成 FretboardControlEvent。
private final class SliderRowView: NSView {
    var onEvent: ((FretboardControlEvent) -> Void)?

    private var sliderID: FretboardSliderControlItem.ID?
    private var isApplyingItem = false
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)

    func apply(item: FretboardSliderControlItem) {
        sliderID = item.id
        titleLabel.stringValue = item.title
        valueLabel.stringValue = item.displayValue
        slider.toolTip = item.accessibilityLabel
        slider.identifier = NSUserInterfaceItemIdentifier(
            "fretboard-control-slider-\(String(describing: item.id))"
        )
        slider.isEnabled = item.isEnabled

        isApplyingItem = true
        slider.minValue = Double(item.range.lowerBound)
        slider.maxValue = Double(item.range.upperBound)
        slider.doubleValue = Double(item.value)
        isApplyingItem = false
    }

    @objc
    private func handleSliderValueChanged(_ sender: NSSlider) {
        guard
            !isApplyingItem,
            let sliderID
        else {
            return
        }

        let event = sliderID.makeEvent(value: CGFloat(sender.doubleValue))
        onEvent?(event)
    }
}

private extension FretboardSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> FretboardControlEvent {
        switch self {
        case .verticalHostHeightRatio:
            return .setVerticalHostHeightRatio(value)
        }
    }
}
```

## 修改 4：控制器把新面板放到 `staffView` 上方，并让竖向高度约束随共享状态重建

### iOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: configureLayout(), applyFretboardDisplayState(), Layout.verticalFretboardHostHeightRatio
// 功能说明: 修改前布局顺序是 buttonPanel -> staffControlPanel -> staffView -> fretboardHostView；竖向 host 高度约束直接绑定私有常量，且没有独立的指板控制面板。
private func configureLayout() {
    contentView.addSubview(buttonPanelView)
    contentView.addSubview(staffControlPanelView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardHostView)
    fretboardHostView.addSubview(fretboardView)

    let safeArea = view.safeAreaLayoutGuide
    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: safeArea.heightAnchor,
        multiplier: Layout.verticalFretboardHostHeightRatio
    )

    NSLayoutConstraint.activate([
        staffControlPanelView.topAnchor.constraint(
            equalTo: buttonPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        staffView.topAnchor.constraint(
            equalTo: staffControlPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardHostView.topAnchor.constraint(
            equalTo: staffView.bottomAnchor,
            constant: Layout.verticalSpacing
        )
    ])
}

private func applyFretboardDisplayState() {
    buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}
```

### iOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: configureLayout(), updateFretboardControlPanelVisibility(), rebuildVerticalFretboardHostHeightConstraint(), applyFretboardDisplayState(), handleFretboardControlEvent(_:)
// 功能说明: 修改后新增 fretboardControlPanelView，并把它放到 staffView 上方；vertical host 高度约束按共享状态重建，horizontal / vertical 切换时同步显示或折叠该面板。
private lazy var fretboardControlPanelView: iOSFretboardControlPanelView = {
    let fretboardControlPanelView = iOSFretboardControlPanelView(
        model: FretboardControlPanelSnapshotBuilder.makeModel(from: displayState)
    )
    fretboardControlPanelView.onEvent = { [weak self] event in
        self?.handleFretboardControlEvent(event)
    }
    return fretboardControlPanelView
}()

private func configureLayout() {
    contentView.addSubview(buttonPanelView)
    contentView.addSubview(staffControlPanelView)
    contentView.addSubview(fretboardControlPanelView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardHostView)

    rebuildVerticalFretboardHostHeightConstraint()
    collapsedFretboardControlPanelHeightConstraint = fretboardControlPanelView.heightAnchor.constraint(
        equalToConstant: 0
    )
    staffViewTopToStaffControlPanelConstraint = staffView.topAnchor.constraint(
        equalTo: staffControlPanelView.bottomAnchor,
        constant: Layout.verticalSpacing
    )
    staffViewTopToFretboardControlPanelConstraint = staffView.topAnchor.constraint(
        equalTo: fretboardControlPanelView.bottomAnchor,
        constant: Layout.verticalSpacing
    )

    NSLayoutConstraint.activate([
        fretboardControlPanelView.topAnchor.constraint(
            equalTo: staffControlPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardControlPanelView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        fretboardControlPanelView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -Layout.horizontalInset
        )
    ])

    updateFretboardControlPanelVisibility()
    updateFretboardLayoutModeConstraints()
}

private func updateFretboardControlPanelVisibility() {
    let showsFretboardControlPanel = displayState.displayMode == .vertical
    fretboardControlPanelView.isHidden = !showsFretboardControlPanel
    collapsedFretboardControlPanelHeightConstraint?.isActive = !showsFretboardControlPanel
    staffViewTopToStaffControlPanelConstraint?.isActive = !showsFretboardControlPanel
    staffViewTopToFretboardControlPanelConstraint?.isActive = showsFretboardControlPanel
}

private func rebuildVerticalFretboardHostHeightConstraint() {
    verticalFretboardHostHeightConstraint?.isActive = false
    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.heightAnchor,
        multiplier: displayState.verticalHostHeightRatio
    )
}

private func applyFretboardDisplayState() {
    buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardControlPanelView.model = FretboardControlPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardControlPanelVisibility()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}

private func handleFretboardControlEvent(_ event: FretboardControlEvent) {
    var nextDisplayState = displayState
    nextDisplayState.apply(event)

    guard nextDisplayState != displayState else {
        return
    }

    displayState = nextDisplayState
}
```

### macOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: configureLayout(), applyFretboardDisplayState(), Layout.verticalFretboardHostHeightRatio
// 功能说明: 修改前 macOS 布局顺序与 iOS 对称，仍然是固定常量驱动的 host 高度，没有插入指板控制面板。
private func configureLayout() {
    contentView.addSubview(buttonPanelView)
    contentView.addSubview(staffControlPanelView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardHostView)
    fretboardHostView.addSubview(fretboardView)

    let safeArea = view.safeAreaLayoutGuide
    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: safeArea.heightAnchor,
        multiplier: Layout.verticalFretboardHostHeightRatio
    )
}
```

### macOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: configureLayout(), updateFretboardControlPanelVisibility(), rebuildVerticalFretboardHostHeightConstraint(), applyFretboardDisplayState(), handleFretboardControlEvent(_:)
// 功能说明: 修改后 macOS 与 iOS 保持对称：新增 fretboardControlPanelView，位置在 staffView 上方，竖向 host 高度约束由共享状态驱动并在每次 state 应用时重建。
private lazy var fretboardControlPanelView: macOSFretboardControlPanelView = {
    let fretboardControlPanelView = macOSFretboardControlPanelView(
        model: FretboardControlPanelSnapshotBuilder.makeModel(from: displayState)
    )
    fretboardControlPanelView.onEvent = { [weak self] event in
        self?.handleFretboardControlEvent(event)
    }
    return fretboardControlPanelView
}()

private func rebuildVerticalFretboardHostHeightConstraint() {
    verticalFretboardHostHeightConstraint?.isActive = false
    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.heightAnchor,
        multiplier: displayState.verticalHostHeightRatio
    )
}

private func updateFretboardControlPanelVisibility() {
    let showsFretboardControlPanel = displayState.displayMode == .vertical
    fretboardControlPanelView.isHidden = !showsFretboardControlPanel
    collapsedFretboardControlPanelHeightConstraint?.isActive = !showsFretboardControlPanel
    staffViewTopToStaffControlPanelConstraint?.isActive = !showsFretboardControlPanel
    staffViewTopToFretboardControlPanelConstraint?.isActive = showsFretboardControlPanel
}

private func applyFretboardDisplayState() {
    buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardControlPanelView.model = FretboardControlPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardControlPanelVisibility()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}
```

## 修改 5：手工回归清单补充滑块场景

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.manualChecklist(for:)
// 功能说明: 修改前手工回归只覆盖横竖模式切换、命中测试和窗口高度变化，没有覆盖高度滑块与模式往返保值行为。
static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
    var checklist = [
        "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
        "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
        "在 vertical 模式下改变窗口或设备高度，确认指板宽度会自适应变化并保持水平居中。"
    ]

    return checklist
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.manualChecklist(for:)
// 功能说明: 修改后手工回归新增高度滑块、窗口变化和 horizontal / vertical 往返切换后的保值校验，覆盖这次新增的页面布局状态。
static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
    var checklist = [
        "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
        "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
        "在 vertical 模式下拖动高度滑块，确认指板 host 高度立即跟随变化，滑块数值与页面可见占比一致。",
        "在 vertical 模式下改变窗口或设备高度，并在 Horizontal / Vertical 之间往返切换；确认指板宽度会自适应变化并保持水平居中，且切回 vertical 后沿用上次滑块值。"
    ]

    return checklist
}
```

## 验证情况

1. 已执行 `swiftc -typecheck` 覆盖当前工程全部 Swift 源文件，结果通过。
2. 已检查本次修改涉及文件的 lints，结果无新增问题。
3. 尚未执行 iOS / macOS 运行时手工 UI 回归；滑块交互、模式切换与 resize 仍需在应用内按上面的 checklist 再走一遍。

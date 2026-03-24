20260324_171406_phase4_macos_staff_control_panel_view

# StaffControlPanel 阶段 4 macOS 面板视图记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift`
- 未修改 iOS 平台视图和控制器接线

## 修改前

### 项目里还没有 macOS 侧的 `StaffControlPanel` 视图

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift
// 函数名：无（新文件）
// 功能说明：修改前项目中不存在 macOS 版的 StaffControlPanel 视图；
// `StaffControlPanelModel` 还没有对应的 AppKit 容器来展示 section、slider 行和事件回调。
```

## 修改后

### 新增 macOS 平台面板视图，提供 `model + onEvent` 接口并渲染 section / slider 行

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift
// 函数名：configureView(), applyModel(), syncSliderRows(in:for:), sliderRow(for:)
// 功能说明：修改后新增 macOSStaffControlPanelView，复用现有 macOSButtonPanelView 的容器层次，
// 对外暴露 `model` 和 `onEvent`，内部负责 section 视图复用、slider row 复用和整体高度计算。
#if os(macOS)
import Foundation
import AppKit

final class macOSStaffControlPanelView: NSView {
    var model: StaffControlPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModel()
        }
    }

    var onEvent: ((StaffControlEvent) -> Void)?

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        let stackSize = sectionsStackView.fittingSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
        )
    }

    private let sectionsStackView = NSStackView()
    private var sectionViews: [StaffControlSectionID: SectionView] = [:]
    private var sliderRowsByID: [StaffSliderControlItem.ID: SliderRowView] = [:]

    override init(frame frameRect: NSRect) {
        model = .empty
        super.init(frame: frameRect)
        configureView()
        applyModel()
    }

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
        sectionsStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(sectionsStackView)

        NSLayoutConstraint.activate([
            sectionsStackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.contentInsets.left
            ),
            sectionsStackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.contentInsets.right
            ),
            sectionsStackView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.contentInsets.top
            ),
            sectionsStackView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.contentInsets.bottom
            )
        ])
    }

    private func applyModel() {
        removeObsoleteSliderRows(notIn: Set(model.sliders.map(\.id)))
        removeObsoleteSectionViews(notIn: Set(model.sections.map(\.id)))

        let orderedSectionViews = model.sections.map { section -> SectionView in
            let sectionView = self.sectionView(for: section.id)
            sectionView.titleText = section.title
            syncSliderRows(
                in: sectionView,
                for: section
            )
            return sectionView
        }

        replaceArrangedSubviews(
            in: sectionsStackView,
            with: orderedSectionViews
        )

        invalidateIntrinsicContentSize()
        needsLayout = true
    }
}
#endif
```

### 新增 slider 行视图，把 AppKit slider 事件映射为共享 `StaffControlEvent`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift
// 函数名：SliderRowView.apply(item:), handleSliderValueChanged(_:), StaffSliderControlItem.ID.makeEvent(value:)
// 功能说明：修改后每个 slider row 会接收共享 item，显示标题和值文本，并在用户拖动时把 AppKit `NSSlider`
// 的连续值转成共享 `StaffControlEvent`，平台层不直接修改 StaffConfiguration。
private final class SliderRowView: NSView {
    var onEvent: ((StaffControlEvent) -> Void)?

    private var sliderID: StaffSliderControlItem.ID?
    private var isApplyingItem = false

    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)

    func apply(item: StaffSliderControlItem) {
        sliderID = item.id
        titleLabel.stringValue = item.title
        valueLabel.stringValue = item.displayValue
        slider.toolTip = item.accessibilityLabel
        slider.identifier = NSUserInterfaceItemIdentifier("staff-control-slider-\(String(describing: item.id))")
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

private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .trebleClefAnchorYOffset:
            return .setTrebleClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

## 结果说明

- macOS 侧已经有了独立的 `StaffControlPanel` 容器视图
- 平台视图现在可以直接消费 `StaffControlPanelModel`
- `NSSlider` 拖动事件已经能被映射成共享 `StaffControlEvent`
- 当前阶段仍未接入控制器，符合阶段 4 范围

## 验证情况

- `ReadLints` 检查 `macOSStaffControlPanelView.swift`，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

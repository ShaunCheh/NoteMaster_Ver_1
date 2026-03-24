20260324_170851_phase3_ios_staff_control_panel_view

# StaffControlPanel 阶段 3 iOS 面板视图记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift`
- 未修改 macOS 平台视图和控制器接线

## 修改前

### 项目里还没有 iOS 侧的 `StaffControlPanel` 视图

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift
// 函数名：无（新文件）
// 功能说明：修改前项目中不存在 iOS 版的 StaffControlPanel 视图；
// `StaffControlPanelModel` 还没有对应的 UIKit 容器来展示 section、slider 行和事件回调。
```

## 修改后

### 新增 iOS 平台面板视图，提供 `model + onEvent` 接口并渲染 section / slider 行

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift
// 函数名：configureView(), applyModel(), syncSliderRows(in:for:), sliderRow(for:)
// 功能说明：修改后新增 iOSStaffControlPanelView，复用现有按钮面板的容器风格，
// 对外暴露 `model` 和 `onEvent`，内部负责 section 视图复用、slider row 复用和整体高度计算。
#if os(iOS)
import Foundation
import UIKit

final class iOSStaffControlPanelView: UIView {
    var model: StaffControlPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModel()
        }
    }

    var onEvent: ((StaffControlEvent) -> Void)?

    override var intrinsicContentSize: CGSize {
        let stackSize = sectionsStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: directionalLayoutMargins.top + stackSize.height + directionalLayoutMargins.bottom
        )
    }

    private let sectionsStackView = UIStackView()
    private var sectionViews: [StaffControlSectionID: SectionView] = [:]
    private var sliderRowsByID: [StaffSliderControlItem.ID: SliderRowView] = [:]

    override init(frame: CGRect) {
        model = .empty
        super.init(frame: frame)
        configureView()
        applyModel()
    }

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
        sectionsStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(sectionsStackView)

        NSLayoutConstraint.activate([
            sectionsStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            sectionsStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            sectionsStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            sectionsStackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
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
        setNeedsLayout()
    }
}
#endif
```

### 新增 slider 行视图，把 UIKit slider 事件映射为共享 `StaffControlEvent`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift
// 函数名：SliderRowView.apply(item:), handleSliderValueChanged(_:), StaffSliderControlItem.ID.makeEvent(value:)
// 功能说明：修改后每个 slider row 会接收共享 item，显示标题和值文本，并在用户拖动时把 UIKit `UISlider`
// 的连续值转成共享 `StaffControlEvent`，平台层不直接修改 StaffConfiguration。
private final class SliderRowView: UIView {
    var onEvent: ((StaffControlEvent) -> Void)?

    private var sliderID: StaffSliderControlItem.ID?
    private var isApplyingItem = false

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()

    func apply(item: StaffSliderControlItem) {
        sliderID = item.id
        titleLabel.text = item.title
        valueLabel.text = item.displayValue
        slider.accessibilityLabel = item.accessibilityLabel
        slider.accessibilityIdentifier = "staff-control-slider-\(String(describing: item.id))"
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

- iOS 侧已经有了独立的 `StaffControlPanel` 容器视图
- 平台视图现在可以直接消费 `StaffControlPanelModel`
- slider 拖动事件已经能被映射成共享 `StaffControlEvent`
- 当前阶段仍未接入控制器，符合阶段 3 范围

## 验证情况

- `ReadLints` 检查 `iOSStaffControlPanelView.swift`，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

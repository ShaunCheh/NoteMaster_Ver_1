# 20260325_183705_phase3_unified_settings_panel_platform_views

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_183705`
- 记录范围：方案 D 的实施阶段 3，统一平台视图
- 本次目标：新增 iOS / macOS 两个平台的统一 `SettingsPanelView`，以 `SettingsPanelModel` 为唯一输入，支持 `chips`、`segmented`、`slider` 三类 row，并统一回传 `SettingsPanelEvent`
- 本次实际改动：新增 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift` 与 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- 本阶段边界：未修改控制器接线，未引入设置容器，未删除旧的 `ButtonPanelView` / `StaffControlPanelView` / `FretboardControlPanelView`

## 本次完成的修改

1. 新增 `iOSSettingsPanelView.swift`，统一 iOS 端的 settings 面板入口。
2. 新增 `macOSSettingsPanelView.swift`，统一 macOS 端的 settings 面板入口。
3. 将原来分散在旧平台视图中的 chips 与 segmented 交互收口到统一的 `ChoiceRowView`。
4. 将原来分散在旧平台视图中的连续值 slider 交互收口到统一的 `SliderRowView`。
5. 统一新的无障碍标识前缀为 `settings-panel-*`，避免旧 panel 命名继续泄漏到新结构。
6. 完成新增平台文件的 lint 检查，以及共享层加新 macOS 视图的 `swiftc -typecheck` 静态校验。

## 修改 1：新增 `iOSSettingsPanelView.swift`，建立 iOS 统一 settings 视图入口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 iOS 平台没有统一的 settings 面板视图；离散按钮、五线谱设置、指板高度设置分别由 3 套独立视图承载。
```

### 旧结构参考

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift；NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift；NoteMaster_Ver_1/Platform/iOS/Controls/iOSFretboardControlPanelView.swift
// 函数/成员: iOSButtonPanelView.model/onAction；iOSStaffControlPanelView.model/onEvent；iOSFretboardControlPanelView.model/onEvent
// 功能说明: 修改前 iOS 平台的输入和事件类型是分裂的；chips 由 ButtonPanelModel/ButtonPanelActionID 驱动，segmented/slider 由 StaffControlPanelModel/StaffControlEvent 与 FretboardControlPanelModel/FretboardControlEvent 驱动。
final class iOSButtonPanelView: UIView {
    var model: ButtonPanelModel {
        didSet { applyModel() }
    }

    var onAction: ((ButtonPanelActionID) -> Void)?
}

final class iOSStaffControlPanelView: UIView {
    var model: StaffControlPanelModel {
        didSet { applyModel() }
    }

    var onEvent: ((StaffControlEvent) -> Void)?
}

final class iOSFretboardControlPanelView: UIView {
    var model: FretboardControlPanelModel {
        didSet { applyModel() }
    }

    var onEvent: ((FretboardControlEvent) -> Void)?
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/成员: iOSSettingsPanelView.model；iOSSettingsPanelView.onEvent；iOSSettingsPanelView.controlView(for:)
// 功能说明: 修改后 iOS 平台只需要消费统一的 SettingsPanelModel，并统一回传 SettingsPanelEvent；choice row 与 slider row 在一个视图里动态分发。
#if os(iOS)
import Foundation
import UIKit

final class iOSSettingsPanelView: UIView {
    var model: SettingsPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModel()
        }
    }

    var onEvent: ((SettingsPanelEvent) -> Void)?

    private let sectionsStackView = UIStackView()
    private var sectionViews: [SettingsSectionID: SectionView] = [:]
    private var controlViewsByID: [SettingsRowID: UIView] = [:]

    private func controlView(for row: SettingsRow) -> UIView {
        switch row {
        case let .choice(item):
            let rowView = ChoiceRowView()
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
}
#endif
```

## 修改 2：iOS 平台把 chips 与 segmented 收口为统一的 `ChoiceRowView`

### 修改前：chips 只存在于 `iOSButtonPanelView`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift
// 函数/成员: iOSButtonPanelView.syncButtons(in:for:)；PanelActionButton.apply(item:)
// 功能说明: 修改前离散按钮只存在于 button panel；这一套 UI 只认识 ButtonPanelItem / ButtonPanelActionID。
private func syncButtons(
    in sectionStack: UIStackView,
    for section: ButtonPanelSection
) {
    let orderedButtons = section.items.map { item -> UIButton in
        let button = actionButton(
            for: item,
            sectionID: section.id
        )
        return button
    }

    replaceArrangedSubviews(
        in: sectionStack,
        with: orderedButtons
    )
}

private final class PanelActionButton: UIButton {
    var actionID: ButtonPanelActionID?

    func apply(item: ButtonPanelItem) {
        actionID = item.id
        isSelected = item.isSelected
        isEnabled = item.isEnabled
        accessibilityIdentifier = "button-panel-\(item.id)"
        setTitle(item.title, for: .normal)
    }
}
```

### 修改前：segmented 只存在于 `iOSStaffControlPanelView`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift
// 函数/成员: OptionRowView.apply(item:)；OptionRowView.handleSelectionChanged(_:)
// 功能说明: 修改前 segmented 选择控件只存在于 staff control panel；这一套 UI 只认识 StaffOptionControlItem / StaffControlEvent。
private final class OptionRowView: UIView {
    var onEvent: ((StaffControlEvent) -> Void)?
    private var choices: [StaffOptionChoice] = []

    func apply(item: StaffOptionControlItem) {
        titleLabel.text = item.title
        segmentedControl.accessibilityIdentifier = "staff-control-option-\(String(describing: item.id))"
        choices = item.choices
    }

    @objc
    private func handleSelectionChanged(_ sender: UISegmentedControl) {
        guard choices.indices.contains(sender.selectedSegmentIndex) else {
            return
        }

        onEvent?(.setClef(choices[sender.selectedSegmentIndex].clef))
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/成员: ChoiceRowView.apply(item:)；ChoiceRowView.applyChipButtons(item:)；ChoiceRowView.applySegmentedControl(item:)；ChoiceRowView.handleChipButtonTap(_:)；ChoiceRowView.handleSelectionChanged(_:)
// 功能说明: 修改后 chips 与 segmented 由同一个 ChoiceRowView 根据 SettingsChoiceRow.presentationStyle 动态切换，并统一回传 SettingsPanelEvent.triggerAction。
private final class ChoiceRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var item: SettingsChoiceRow?
    private var buttonsByActionID: [SettingsActionID: ChoiceChipButton] = [:]

    func apply(item: SettingsChoiceRow) {
        self.item = item
        titleLabel.text = item.title

        switch item.presentationStyle {
        case .chips:
            applyChipButtons(item: item)
            chipsStackView.isHidden = false
            segmentedControl.isHidden = true
        case .segmented:
            applySegmentedControl(item: item)
            chipsStackView.isHidden = true
            segmentedControl.isHidden = false
        }
    }

    private func applyChipButtons(item: SettingsChoiceRow) {
        let orderedButtons = item.choices.map { choice -> UIButton in
            chipButton(for: choice)
        }

        replaceArrangedSubviews(
            in: chipsStackView,
            with: orderedButtons
        )

        accessibilityIdentifier = "settings-panel-choice-row-\(String(describing: item.id))"
    }

    private func applySegmentedControl(item: SettingsChoiceRow) {
        segmentedControl.accessibilityIdentifier = "settings-panel-choice-row-\(String(describing: item.id))"
        segmentedControl.removeAllSegments()

        for (index, choice) in item.choices.enumerated() {
            segmentedControl.insertSegment(withTitle: choice.title, at: index, animated: false)
            segmentedControl.setEnabled(choice.isEnabled, forSegmentAt: index)
        }
    }

    @objc
    private func handleChipButtonTap(_ sender: ChoiceChipButton) {
        guard let actionID = sender.actionID else {
            return
        }

        onEvent?(.triggerAction(actionID))
    }

    @objc
    private func handleSelectionChanged(_ sender: UISegmentedControl) {
        guard
            let item,
            item.choices.indices.contains(sender.selectedSegmentIndex)
        else {
            return
        }

        onEvent?(.triggerAction(item.choices[sender.selectedSegmentIndex].id))
    }
}
```

## 修改 3：iOS 平台把 staff / fretboard 的 slider 收口为统一的 `SliderRowView`

### 修改前：staff slider 与 fretboard slider 分散在两套旧视图里

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift；NoteMaster_Ver_1/Platform/iOS/Controls/iOSFretboardControlPanelView.swift
// 函数/成员: iOSStaffControlPanelView.SliderRowView.apply(item:)；iOSStaffControlPanelView.SliderRowView.handleSliderValueChanged(_:)；iOSFretboardControlPanelView.SliderRowView.apply(item:)；iOSFretboardControlPanelView.SliderRowView.handleSliderValueChanged(_:)
// 功能说明: 修改前 staff 的连续值调节与 fretboard 的连续值调节分别维护，identifier 和事件类型都不统一。
private final class SliderRowView: UIView {
    var onEvent: ((StaffControlEvent) -> Void)?
    private var sliderID: StaffSliderControlItem.ID?

    func apply(item: StaffSliderControlItem) {
        sliderID = item.id
        slider.accessibilityIdentifier = "staff-control-slider-\(String(describing: item.id))"
        slider.minimumValue = Float(item.range.lowerBound)
        slider.maximumValue = Float(item.range.upperBound)
        slider.setValue(Float(item.value), animated: false)
    }
}

private final class SliderRowView: UIView {
    var onEvent: ((FretboardControlEvent) -> Void)?
    private var sliderID: FretboardSliderControlItem.ID?

    func apply(item: FretboardSliderControlItem) {
        sliderID = item.id
        slider.accessibilityIdentifier = "fretboard-control-slider-\(String(describing: item.id))"
        slider.minimumValue = Float(item.range.lowerBound)
        slider.maximumValue = Float(item.range.upperBound)
        slider.setValue(Float(item.value), animated: false)
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/成员: SliderRowView.apply(item:)；SliderRowView.handleSliderValueChanged(_:)
// 功能说明: 修改后所有连续值调节都由统一的 SettingsSliderRow / SettingsSliderID 驱动，并统一回传 SettingsPanelEvent.setSliderValue。
private final class SliderRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var sliderID: SettingsSliderID?
    private var isApplyingItem = false

    func apply(item: SettingsSliderRow) {
        sliderID = item.id
        accessibilityIdentifier = "settings-panel-slider-row-\(String(describing: item.id))"
        titleLabel.text = item.title
        valueLabel.text = item.displayValue
        slider.accessibilityIdentifier = "settings-panel-slider-\(String(describing: item.id))"
        slider.isEnabled = item.isEnabled

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

        onEvent?(.setSliderValue(sliderID, CGFloat(sender.value)))
    }
}
```

## 修改 4：新增 `macOSSettingsPanelView.swift`，建立 macOS 统一 settings 视图入口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 macOS 平台没有统一的 settings 面板视图；离散按钮、五线谱设置、指板高度设置分别由 3 套独立视图承载。
```

### 旧结构参考

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift；NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift；NoteMaster_Ver_1/Platform/macOS/Controls/macOSFretboardControlPanelView.swift
// 函数/成员: macOSButtonPanelView.model/onAction；macOSStaffControlPanelView.model/onEvent；macOSFretboardControlPanelView.model/onEvent
// 功能说明: 修改前 macOS 平台和 iOS 一样，模型与事件入口是分裂的，尚未形成统一 settings 面板。
final class macOSButtonPanelView: NSView {
    var model: ButtonPanelModel {
        didSet { applyModel() }
    }

    var onAction: ((ButtonPanelActionID) -> Void)?
}

final class macOSStaffControlPanelView: NSView {
    var model: StaffControlPanelModel {
        didSet { applyModel() }
    }

    var onEvent: ((StaffControlEvent) -> Void)?
}

final class macOSFretboardControlPanelView: NSView {
    var model: FretboardControlPanelModel {
        didSet { applyModel() }
    }

    var onEvent: ((FretboardControlEvent) -> Void)?
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数/成员: macOSSettingsPanelView.model；macOSSettingsPanelView.onEvent；macOSSettingsPanelView.controlView(for:)
// 功能说明: 修改后 macOS 平台和 iOS 一样，以 SettingsPanelModel 为统一输入，并把 choice / slider 两类 row 都收口到一个视图层里。
#if os(macOS)
import Foundation
import AppKit

final class macOSSettingsPanelView: NSView {
    var model: SettingsPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModel()
        }
    }

    var onEvent: ((SettingsPanelEvent) -> Void)?

    private let sectionsStackView = NSStackView()
    private var sectionViews: [SettingsSectionID: SectionView] = [:]
    private var controlViewsByID: [SettingsRowID: NSView] = [:]

    private func controlView(for row: SettingsRow) -> NSView {
        switch row {
        case let .choice(item):
            let rowView = ChoiceRowView(frame: .zero)
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
}
#endif
```

## 修改 5：macOS 平台把 choice / slider 的事件与标识统一到新的 settings 语义

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift；NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift；NoteMaster_Ver_1/Platform/macOS/Controls/macOSFretboardControlPanelView.swift
// 函数/成员: PanelActionButton.apply(item:)；OptionRowView.handleSelectionChanged(_:)；SliderRowView.handleSliderValueChanged(_:)
// 功能说明: 修改前 macOS 的 choice / slider 交互分别发出 ButtonPanelActionID、StaffControlEvent、FretboardControlEvent，并使用 button-panel / staff-control / fretboard-control 前缀标识。
private final class PanelActionButton: NSButton {
    func apply(item: ButtonPanelItem) {
        identifier = NSUserInterfaceItemIdentifier("button-panel-\(String(describing: item.id))")
    }
}

private final class OptionRowView: NSView {
    @objc
    private func handleSelectionChanged(_ sender: NSSegmentedControl) {
        onEvent?(.setClef(choices[sender.selectedSegment].clef))
    }
}

private final class SliderRowView: NSView {
    @objc
    private func handleSliderValueChanged(_ sender: NSSlider) {
        let event = sliderID.makeEvent(value: CGFloat(sender.doubleValue))
        onEvent?(event)
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数/成员: ChoiceRowView.applySegmentedControl(item:)；ChoiceRowView.handleSelectionChanged(_:)；ChoiceChipButton.apply(item:)；SliderRowView.apply(item:)；SliderRowView.handleSliderValueChanged(_:)
// 功能说明: 修改后 macOS 端统一使用 settings-panel-* 标识；单选与独立选择都由 SettingsChoiceRow.selectionStyle 驱动，连续值变化统一回传 SettingsPanelEvent。
private final class ChoiceRowView: NSView {
    var onEvent: ((SettingsPanelEvent) -> Void)?
    private var item: SettingsChoiceRow?

    private func applySegmentedControl(item: SettingsChoiceRow) {
        segmentedControl.identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-choice-row-\(String(describing: item.id))"
        )
        segmentedControl.trackingMode = item.selectionStyle == .singleSelection ? .selectOne : .selectAny
    }

    @objc
    private func handleSelectionChanged(_ sender: NSSegmentedControl) {
        guard let item else {
            return
        }

        switch item.selectionStyle {
        case .singleSelection:
            onEvent?(.triggerAction(item.choices[sender.selectedSegment].id))
        case .independent:
            guard let toggledIndex = item.choices.indices.first(where: {
                sender.isSelected(forSegment: $0) != item.choices[$0].isSelected
            }) else {
                return
            }

            onEvent?(.triggerAction(item.choices[toggledIndex].id))
        }
    }
}

private final class ChoiceChipButton: NSButton {
    var actionID: SettingsActionID?

    func apply(item: SettingsChoiceItem) {
        actionID = item.id
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-choice-\(String(describing: item.id))"
        )
    }
}

private final class SliderRowView: NSView {
    var onEvent: ((SettingsPanelEvent) -> Void)?
    private var sliderID: SettingsSliderID?

    func apply(item: SettingsSliderRow) {
        sliderID = item.id
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-slider-row-\(String(describing: item.id))"
        )
        slider.identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-slider-\(String(describing: item.id))"
        )
    }

    @objc
    private func handleSliderValueChanged(_ sender: NSSlider) {
        guard let sliderID else {
            return
        }

        onEvent?(.setSliderValue(sliderID, CGFloat(sender.doubleValue)))
    }
}
```

## 验证结果

```bash
# 文件路径: 命令行校验（无项目内文件路径）
# 函数/成员: ReadLints；swiftc -typecheck
# 功能说明: 新增两个平台视图文件已做 lint 检查；共享层加新的 macOS settings 视图已通过静态类型检查。
ReadLints paths:
- NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
- NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
Result:
- No linter errors found.

swiftc -typecheck:
setopt extendedglob && files=(NoteMaster_Ver_1/Shared/**/*.swift NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift) && swiftc -typecheck $files
Result:
- exit code 0
```

## 结果说明

- 阶段 3 完成后，统一的 settings 平台视图已经在 iOS / macOS 两端落地，后续控制器只需要喂 `SettingsPanelModel` 并处理 `SettingsPanelEvent`。
- 本阶段仍然没有切换控制器引用，因此当前界面上不会出现可见变化；可见变化要到后续设置容器与控制器迁移阶段。
- 本阶段也没有删除旧平台视图文件；旧视图仍作为后续迁移前的兼容基线存在。

//
//  macOSSettingsPanelView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

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

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        let stackSize = sectionsStackView.fittingSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
        )
    }

    private let sectionsStackView = NSStackView()
    private var sectionViews: [SettingsSectionID: SectionView] = [:]
    private var controlViewsByID: [SettingsRowID: NSView] = [:]

    override init(frame frameRect: NSRect) {
        model = .empty
        super.init(frame: frameRect)
        configureView()
        applyModel()
    }

    convenience init(model: SettingsPanelModel) {
        self.init(frame: .zero)
        self.model = model
        applyModel()
    }

    required init?(coder: NSCoder) {
        model = .empty
        super.init(coder: coder)
        configureView()
        applyModel()
    }

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("settings-panel")
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
        removeObsoleteControlViews(notIn: Set(model.rows.map(\.id)))
        removeObsoleteSectionViews(notIn: Set(model.sections.map(\.id)))

        let orderedSectionViews = model.sections.map { section -> SectionView in
            let sectionView = self.sectionView(for: section.id)
            sectionView.titleText = section.title
            sectionView.identifier = NSUserInterfaceItemIdentifier(
                "settings-panel-section-\(String(describing: section.id))"
            )
            syncControlRows(
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

    private func syncControlRows(
        in sectionView: SectionView,
        for section: SettingsSection
    ) {
        let orderedRows = section.rows.map { row -> NSView in
            controlView(for: row)
        }

        sectionView.rows = orderedRows
    }

    private func sectionView(for id: SettingsSectionID) -> SectionView {
        if let existingView = sectionViews[id] {
            return existingView
        }

        let sectionView = SectionView()
        sectionViews[id] = sectionView
        return sectionView
    }

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
        case let .positionFilter(item):
            let rowID = row.id
            if let existingRow = controlViewsByID[rowID] as? FretFilterRowView {
                existingRow.apply(item: item)
                return existingRow
            }

            detachControlViewIfNeeded(for: rowID)

            let rowView = FretFilterRowView(frame: .zero)
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

    private func removeObsoleteControlViews(notIn validIDs: Set<SettingsRowID>) {
        let obsoleteIDs = controlViewsByID.keys.filter { !validIDs.contains($0) }

        for id in obsoleteIDs {
            guard let rowView = controlViewsByID.removeValue(forKey: id) else {
                continue
            }

            if let stackView = rowView.superview as? NSStackView {
                stackView.removeArrangedSubview(rowView)
            }
            rowView.removeFromSuperview()
        }
    }

    private func detachControlViewIfNeeded(for id: SettingsRowID) {
        guard let rowView = controlViewsByID[id] else {
            return
        }

        if let stackView = rowView.superview as? NSStackView {
            stackView.removeArrangedSubview(rowView)
        }
        rowView.removeFromSuperview()
        controlViewsByID.removeValue(forKey: id)
    }

    private func removeObsoleteSectionViews(notIn validIDs: Set<SettingsSectionID>) {
        let obsoleteIDs = sectionViews.keys.filter { !validIDs.contains($0) }

        for id in obsoleteIDs {
            guard let sectionView = sectionViews.removeValue(forKey: id) else {
                continue
            }

            sectionsStackView.removeArrangedSubview(sectionView)
            sectionView.removeFromSuperview()
        }
    }

    private func replaceArrangedSubviews(
        in stackView: NSStackView,
        with views: [NSView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? NSStackView {
                parentStackView.removeArrangedSubview(view)
            }
            view.removeFromSuperview()
            stackView.addArrangedSubview(view)
        }
    }
}

private final class ChoiceRowView: NSView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var item: SettingsChoiceRow?
    private var isApplyingItem = false
    private var buttonsByActionID: [SettingsActionID: ChoiceChipButton] = [:]

    private let contentStackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let chipsStackView = NSStackView()
    private let segmentedControl = NSSegmentedControl()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(item: SettingsChoiceRow) {
        self.item = item
        titleLabel.stringValue = item.title

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

    private func configureView() {
        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.distribution = .fill
        contentStackView.detachesHiddenViews = true
        contentStackView.spacing = Style.choiceContentSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: Style.bodyFontSize, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        chipsStackView.orientation = .horizontal
        chipsStackView.alignment = .centerY
        chipsStackView.distribution = .fill
        chipsStackView.spacing = Style.chipSpacing

        segmentedControl.segmentStyle = .rounded
        segmentedControl.target = self
        segmentedControl.action = #selector(handleSelectionChanged(_:))
        segmentedControl.isHidden = true

        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(chipsStackView)
        contentStackView.addArrangedSubview(segmentedControl)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func applyChipButtons(item: SettingsChoiceRow) {
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-choice-row-\(String(describing: item.id))"
        )
        removeObsoleteButtons(notIn: Set(item.choices.map(\.id)))

        let orderedButtons = item.choices.map { choice -> NSView in
            chipButton(for: choice)
        }

        replaceArrangedSubviews(
            in: chipsStackView,
            with: orderedButtons
        )
    }

    private func applySegmentedControl(item: SettingsChoiceRow) {
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-choice-row-\(String(describing: item.id))"
        )
        segmentedControl.toolTip = item.accessibilityLabel
        segmentedControl.identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-choice-row-\(String(describing: item.id))"
        )
        segmentedControl.trackingMode = item.selectionStyle == .singleSelection ? .selectOne : .selectAny

        isApplyingItem = true
        segmentedControl.segmentCount = item.choices.count

        for (index, choice) in item.choices.enumerated() {
            segmentedControl.setLabel(choice.title, forSegment: index)
            segmentedControl.setEnabled(choice.isEnabled, forSegment: index)
            segmentedControl.setSelected(choice.isSelected, forSegment: index)
        }

        segmentedControl.isEnabled = item.choices.contains(where: { $0.isEnabled })
        isApplyingItem = false
    }

    private func chipButton(for item: SettingsChoiceItem) -> ChoiceChipButton {
        if let existingButton = buttonsByActionID[item.id] {
            existingButton.apply(item: item)
            return existingButton
        }

        let button = ChoiceChipButton(frame: .zero)
        button.target = self
        button.action = #selector(handleChipButtonTap(_:))
        button.apply(item: item)
        buttonsByActionID[item.id] = button
        return button
    }

    private func removeObsoleteButtons(notIn validActionIDs: Set<SettingsActionID>) {
        let obsoleteActionIDs = buttonsByActionID.keys.filter { !validActionIDs.contains($0) }

        for actionID in obsoleteActionIDs {
            guard let button = buttonsByActionID.removeValue(forKey: actionID) else {
                continue
            }

            if let stackView = button.superview as? NSStackView {
                stackView.removeArrangedSubview(button)
            }
            button.removeFromSuperview()
        }
    }

    private func replaceArrangedSubviews(
        in stackView: NSStackView,
        with views: [NSView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? NSStackView {
                parentStackView.removeArrangedSubview(view)
            }
            view.removeFromSuperview()
            stackView.addArrangedSubview(view)
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
    private func handleSelectionChanged(_ sender: NSSegmentedControl) {
        guard
            !isApplyingItem,
            let item
        else {
            return
        }

        switch item.selectionStyle {
        case .singleSelection:
            guard item.choices.indices.contains(sender.selectedSegment) else {
                return
            }

            let choice = item.choices[sender.selectedSegment]
            guard choice.isEnabled else {
                return
            }

            onEvent?(.triggerAction(choice.id))
        case .independent:
            guard let toggledIndex = item.choices.indices.first(where: {
                sender.isSelected(forSegment: $0) != item.choices[$0].isSelected
            }) else {
                return
            }

            let choice = item.choices[toggledIndex]
            guard choice.isEnabled else {
                return
            }

            onEvent?(.triggerAction(choice.id))
        }
    }
}

private final class ChoiceChipButton: NSButton {
    var actionID: SettingsActionID?

    private var isPressed = false

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(
            width: size.width + Style.buttonContentInsets.left + Style.buttonContentInsets.right,
            height: max(
                size.height + Style.buttonContentInsets.top + Style.buttonContentInsets.bottom,
                Style.minimumButtonHeight
            )
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
    }

    func apply(item: SettingsChoiceItem) {
        actionID = item.id
        state = item.isSelected ? .on : .off
        isEnabled = item.isEnabled
        title = item.title
        toolTip = item.accessibilityLabel
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-choice-\(String(describing: item.id))"
        )
        applyCurrentAppearance()
        invalidateIntrinsicContentSize()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        applyCurrentAppearance()
        super.mouseDown(with: event)
        isPressed = false
        applyCurrentAppearance()
    }

    private func configureButton() {
        setButtonType(.momentaryPushIn)
        bezelStyle = .regularSquare
        isBordered = false
        focusRingType = .default
        wantsLayer = true
        layer?.cornerRadius = Style.buttonCornerRadius
        layer?.masksToBounds = true

        if let buttonCell = cell as? NSButtonCell {
            buttonCell.lineBreakMode = .byTruncatingTail
            buttonCell.usesSingleLineMode = true
        }

        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func applyCurrentAppearance() {
        layer?.backgroundColor = resolvedBackgroundColor().cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: Style.bodyFontSize, weight: .medium),
                .foregroundColor: resolvedForegroundColor()
            ]
        )
    }

    private func resolvedBackgroundColor() -> NSColor {
        if !isEnabled {
            return .quaternaryLabelColor.withAlphaComponent(0.12)
        }

        if state == .on {
            return isPressed
                ? NSColor.controlAccentColor.withAlphaComponent(0.78)
                : NSColor.controlAccentColor
        }

        return isPressed
            ? NSColor.quaternaryLabelColor.withAlphaComponent(0.18)
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.1)
    }

    private func resolvedForegroundColor() -> NSColor {
        if !isEnabled {
            return .disabledControlTextColor
        }

        return state == .on ? .white : .labelColor
    }
}

private final class SliderRowView: NSView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var sliderID: SettingsSliderID?
    private var isApplyingItem = false

    private let contentStackView = NSStackView()
    private let headerStackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(item: SettingsSliderRow) {
        sliderID = item.id
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-slider-row-\(String(describing: item.id))"
        )
        titleLabel.stringValue = item.title
        valueLabel.stringValue = item.displayValue
        slider.toolTip = item.accessibilityLabel
        slider.identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-slider-\(String(describing: item.id))"
        )
        slider.isEnabled = item.isEnabled

        isApplyingItem = true
        slider.minValue = Double(item.range.lowerBound)
        slider.maxValue = Double(item.range.upperBound)
        slider.doubleValue = Double(item.value)
        isApplyingItem = false
    }

    private func configureView() {
        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.distribution = .fill
        contentStackView.spacing = Style.sliderContentSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        headerStackView.orientation = .horizontal
        headerStackView.alignment = .centerY
        headerStackView.distribution = .fill
        headerStackView.spacing = Style.headerSpacing

        titleLabel.font = .systemFont(ofSize: Style.bodyFontSize, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: Style.valueFontSize, weight: .medium)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        slider.target = self
        slider.action = #selector(handleSliderValueChanged(_:))
        slider.isContinuous = true
        slider.controlSize = .regular

        addSubview(contentStackView)
        headerStackView.addArrangedSubview(titleLabel)
        headerStackView.addArrangedSubview(valueLabel)
        contentStackView.addArrangedSubview(headerStackView)
        contentStackView.addArrangedSubview(slider)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            slider.widthAnchor.constraint(greaterThanOrEqualToConstant: Style.minimumSliderWidth)
        ])
    }

    @objc
    private func handleSliderValueChanged(_ sender: NSSlider) {
        guard
            !isApplyingItem,
            let sliderID
        else {
            return
        }

        onEvent?(.setSliderValue(sliderID, CGFloat(sender.doubleValue)))
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(item: SettingsToggleRow) {
        toggleID = item.id
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-toggle-row-\(String(describing: item.id))"
        )
        titleLabel.stringValue = item.title
        toggleSwitch.toolTip = item.accessibilityLabel
        toggleSwitch.identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-toggle-\(String(describing: item.id))"
        )
        toggleSwitch.isEnabled = item.isEnabled

        isApplyingItem = true
        toggleSwitch.state = item.isOn ? .on : .off
        isApplyingItem = false
    }

    private func configureView() {
        contentStackView.orientation = .horizontal
        contentStackView.alignment = .centerY
        contentStackView.distribution = .fill
        contentStackView.spacing = Style.toggleSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: Style.bodyFontSize, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 0
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        toggleSwitch.target = self
        toggleSwitch.action = #selector(handleToggleValueChanged(_:))
        toggleSwitch.controlSize = .regular

        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(spacerView)
        contentStackView.addArrangedSubview(toggleSwitch)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
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

private final class FretFilterRowView: NSView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var buttonsByOptionID: [SettingsPositionFilterOptionID: FretFilterButton] = [:]

    private let contentStackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let fretsStackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(item: SettingsPositionFilterRow) {
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-position-filter-row-\(String(describing: item.id))"
        )
        toolTip = item.accessibilityLabel
        titleLabel.stringValue = item.title
        removeObsoleteButtons(notIn: Set(item.options.map(\.id)))

        let orderedButtons = item.options.map { fret -> NSView in
            fretButton(for: fret)
        }

        replaceArrangedSubviews(
            in: fretsStackView,
            with: orderedButtons
        )
    }

    private func configureView() {
        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.distribution = .fill
        contentStackView.spacing = Style.fretFilterContentSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: Style.bodyFontSize, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        fretsStackView.orientation = .horizontal
        fretsStackView.alignment = .centerY
        fretsStackView.distribution = .fillEqually
        fretsStackView.spacing = Style.fretFilterSpacing

        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(fretsStackView)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func fretButton(for item: SettingsPositionFilterItem) -> FretFilterButton {
        if let existingButton = buttonsByOptionID[item.id] {
            existingButton.apply(item: item)
            return existingButton
        }

        let button = FretFilterButton(frame: .zero)
        button.target = self
        button.action = #selector(handleFretButtonTap(_:))
        button.apply(item: item)
        buttonsByOptionID[item.id] = button
        return button
    }

    private func removeObsoleteButtons(
        notIn validOptionIDs: Set<SettingsPositionFilterOptionID>
    ) {
        let obsoleteOptionIDs = buttonsByOptionID.keys.filter {
            !validOptionIDs.contains($0)
        }

        for optionID in obsoleteOptionIDs {
            guard let button = buttonsByOptionID.removeValue(forKey: optionID) else {
                continue
            }

            if let stackView = button.superview as? NSStackView {
                stackView.removeArrangedSubview(button)
            }
            button.removeFromSuperview()
        }
    }

    private func replaceArrangedSubviews(
        in stackView: NSStackView,
        with views: [NSView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? NSStackView {
                parentStackView.removeArrangedSubview(view)
            }
            view.removeFromSuperview()
            stackView.addArrangedSubview(view)
        }
    }

    @objc
    private func handleFretButtonTap(_ sender: FretFilterButton) {
        guard
            let optionID = sender.optionID,
            sender.isEnabled
        else {
            return
        }

        onEvent?(.togglePositionPromptFilterOption(optionID))
    }
}

private final class FretFilterButton: NSButton {
    var optionID: SettingsPositionFilterOptionID?

    private var isPressed = false

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(
            width: max(
                Style.minimumFretFilterButtonWidth,
                size.width + Style.fretFilterButtonContentInsets.left + Style.fretFilterButtonContentInsets.right
            ),
            height: max(
                Style.minimumFretFilterButtonHeight,
                size.height + Style.fretFilterButtonContentInsets.top + Style.fretFilterButtonContentInsets.bottom
            )
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
    }

    func apply(item: SettingsPositionFilterItem) {
        optionID = item.id
        state = item.isSelected ? .on : .off
        isEnabled = item.isEnabled
        title = item.title
        toolTip = item.accessibilityLabel
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-position-filter-\(item.id.accessibilityIdentifierComponent)"
        )
        applyCurrentAppearance()
        invalidateIntrinsicContentSize()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        applyCurrentAppearance()
        super.mouseDown(with: event)
        isPressed = false
        applyCurrentAppearance()
    }

    private func configureButton() {
        setButtonType(.momentaryPushIn)
        bezelStyle = .regularSquare
        isBordered = false
        focusRingType = .default
        wantsLayer = true
        layer?.cornerRadius = Style.fretFilterButtonCornerRadius
        layer?.masksToBounds = true

        if let buttonCell = cell as? NSButtonCell {
            buttonCell.lineBreakMode = .byClipping
            buttonCell.usesSingleLineMode = true
        }

        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func applyCurrentAppearance() {
        layer?.backgroundColor = resolvedBackgroundColor().cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: Style.fretFilterButtonFontSize,
                    weight: .semibold
                ),
                .foregroundColor: resolvedForegroundColor()
            ]
        )
    }

    private func resolvedBackgroundColor() -> NSColor {
        if state == .on {
            if !isEnabled {
                return NSColor.controlAccentColor.withAlphaComponent(0.38)
            }

            return isPressed
                ? NSColor.controlAccentColor.withAlphaComponent(0.78)
                : NSColor.controlAccentColor
        }

        if !isEnabled {
            return .quaternaryLabelColor.withAlphaComponent(0.12)
        }

        return isPressed
            ? NSColor.quaternaryLabelColor.withAlphaComponent(0.18)
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.1)
    }

    private func resolvedForegroundColor() -> NSColor {
        if state == .on {
            return .white.withAlphaComponent(isEnabled ? 1 : 0.84)
        }

        if !isEnabled {
            return .disabledControlTextColor
        }

        return .labelColor
    }
}

private final class SectionView: NSView {
    var titleText: String = "" {
        didSet {
            titleLabel.stringValue = titleText
            titleLabel.isHidden = titleText.isEmpty
        }
    }

    var rows: [NSView] = [] {
        didSet {
            replaceArrangedSubviews(
                in: rowsStackView,
                with: rows
            )
        }
    }

    private let contentStackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let rowsStackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.distribution = .fill
        contentStackView.spacing = Style.sectionContentSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: Style.captionFontSize)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isHidden = true

        rowsStackView.orientation = .vertical
        rowsStackView.alignment = .leading
        rowsStackView.distribution = .fill
        rowsStackView.detachesHiddenViews = true
        rowsStackView.spacing = Style.rowSpacing

        addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(rowsStackView)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func replaceArrangedSubviews(
        in stackView: NSStackView,
        with views: [NSView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? NSStackView {
                parentStackView.removeArrangedSubview(view)
            }
            view.removeFromSuperview()
            stackView.addArrangedSubview(view)
        }
    }
}

private enum Style {
    static let contentInsets = NSEdgeInsets(
        top: 10,
        left: 12,
        bottom: 10,
        right: 12
    )
    static let panelCornerRadius: CGFloat = 14
    static let buttonCornerRadius: CGFloat = 11
    static let minimumButtonHeight: CGFloat = 30
    static let minimumFretFilterButtonWidth: CGFloat = 24
    static let minimumFretFilterButtonHeight: CGFloat = 28
    static let sectionSpacing: CGFloat = 12
    static let sectionContentSpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 12
    static let choiceContentSpacing: CGFloat = 8
    static let fretFilterContentSpacing: CGFloat = 8
    static let fretFilterSpacing: CGFloat = 4
    static let sliderContentSpacing: CGFloat = 8
    static let headerSpacing: CGFloat = 8
    static let toggleSpacing: CGFloat = 12
    static let chipSpacing: CGFloat = 8
    static let minimumSliderWidth: CGFloat = 220
    static let captionFontSize: CGFloat = 12
    static let bodyFontSize: CGFloat = 13
    static let valueFontSize: CGFloat = 13
    static let fretFilterButtonCornerRadius: CGFloat = 8
    static let fretFilterButtonFontSize: CGFloat = 12
    static let buttonContentInsets = NSEdgeInsets(
        top: 7,
        left: 12,
        bottom: 7,
        right: 12
    )
    static let fretFilterButtonContentInsets = NSEdgeInsets(
        top: 5,
        left: 0,
        bottom: 5,
        right: 0
    )
}
#endif

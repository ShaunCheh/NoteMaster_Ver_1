//
//  iOSSettingsPanelView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

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

    override var intrinsicContentSize: CGSize {
        let stackSize = sectionsStackView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: directionalLayoutMargins.top + stackSize.height + directionalLayoutMargins.bottom
        )
    }

    private let sectionsStackView = UIStackView()
    private var sectionViews: [SettingsSectionID: SectionView] = [:]
    private var controlViewsByID: [SettingsRowID: UIView] = [:]

    override init(frame: CGRect) {
        model = .empty
        super.init(frame: frame)
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
        accessibilityIdentifier = "settings-panel"
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
        removeObsoleteControlViews(notIn: Set(model.rows.map(\.id)))
        removeObsoleteSectionViews(notIn: Set(model.sections.map(\.id)))

        let orderedSectionViews = model.sections.map { section -> SectionView in
            let sectionView = self.sectionView(for: section.id)
            sectionView.titleText = section.title
            sectionView.accessibilityIdentifier = "settings-panel-section-\(String(describing: section.id))"
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
        setNeedsLayout()
    }

    private func syncControlRows(
        in sectionView: SectionView,
        for section: SettingsSection
    ) {
        let orderedRows = section.rows.map { row -> UIView in
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
        case let .fretFilter(item):
            let rowID = row.id
            if let existingRow = controlViewsByID[rowID] as? FretFilterPlaceholderRowView {
                existingRow.apply(item: item)
                return existingRow
            }

            detachControlViewIfNeeded(for: rowID)

            let rowView = FretFilterPlaceholderRowView()
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

    private func removeObsoleteControlViews(notIn validIDs: Set<SettingsRowID>) {
        let obsoleteIDs = controlViewsByID.keys.filter { !validIDs.contains($0) }

        for id in obsoleteIDs {
            guard let rowView = controlViewsByID.removeValue(forKey: id) else {
                continue
            }

            if let stackView = rowView.superview as? UIStackView {
                stackView.removeArrangedSubview(rowView)
            }
            rowView.removeFromSuperview()
        }
    }

    private func detachControlViewIfNeeded(for id: SettingsRowID) {
        guard let rowView = controlViewsByID[id] else {
            return
        }

        if let stackView = rowView.superview as? UIStackView {
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
        in stackView: UIStackView,
        with views: [UIView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? UIStackView {
                parentStackView.removeArrangedSubview(view)
            }
            view.removeFromSuperview()
            stackView.addArrangedSubview(view)
        }
    }
}

private final class ChoiceRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var item: SettingsChoiceRow?
    private var isApplyingItem = false
    private var buttonsByActionID: [SettingsActionID: ChoiceChipButton] = [:]

    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let chipsStackView = UIStackView()
    private let segmentedControl = UISegmentedControl(items: [])

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

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

    private func configureView() {
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.spacing = Style.choiceContentSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true

        chipsStackView.axis = .horizontal
        chipsStackView.alignment = .fill
        chipsStackView.distribution = .fill
        chipsStackView.spacing = Style.chipSpacing

        segmentedControl.apportionsSegmentWidthsByContent = true
        segmentedControl.isHidden = true
        segmentedControl.addTarget(
            self,
            action: #selector(handleSelectionChanged(_:)),
            for: .valueChanged
        )

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
        removeObsoleteButtons(notIn: Set(item.choices.map(\.id)))

        let orderedButtons = item.choices.map { choice -> UIButton in
            chipButton(for: choice)
        }

        replaceArrangedSubviews(
            in: chipsStackView,
            with: orderedButtons
        )

        accessibilityIdentifier = "settings-panel-choice-row-\(String(describing: item.id))"
        isUserInteractionEnabled = item.choices.contains(where: { $0.isEnabled })
    }

    private func applySegmentedControl(item: SettingsChoiceRow) {
        accessibilityIdentifier = "settings-panel-choice-row-\(String(describing: item.id))"
        segmentedControl.accessibilityLabel = item.accessibilityLabel
        segmentedControl.accessibilityIdentifier = "settings-panel-choice-row-\(String(describing: item.id))"

        isApplyingItem = true
        segmentedControl.removeAllSegments()

        var selectedSegmentIndex = UISegmentedControl.noSegment
        for (index, choice) in item.choices.enumerated() {
            segmentedControl.insertSegment(
                withTitle: choice.title,
                at: index,
                animated: false
            )
            segmentedControl.setEnabled(choice.isEnabled, forSegmentAt: index)

            if choice.isSelected {
                selectedSegmentIndex = index
            }
        }

        segmentedControl.selectedSegmentIndex = selectedSegmentIndex
        segmentedControl.isEnabled = item.choices.contains(where: { $0.isEnabled })
        isUserInteractionEnabled = item.choices.contains(where: { $0.isEnabled })
        isApplyingItem = false
    }

    private func chipButton(for item: SettingsChoiceItem) -> ChoiceChipButton {
        if let existingButton = buttonsByActionID[item.id] {
            existingButton.apply(item: item)
            return existingButton
        }

        let button = ChoiceChipButton(frame: .zero)
        button.addTarget(
            self,
            action: #selector(handleChipButtonTap(_:)),
            for: .touchUpInside
        )
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

            if let stackView = button.superview as? UIStackView {
                stackView.removeArrangedSubview(button)
            }
            button.removeFromSuperview()
        }
    }

    private func replaceArrangedSubviews(
        in stackView: UIStackView,
        with views: [UIView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? UIStackView {
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
    private func handleSelectionChanged(_ sender: UISegmentedControl) {
        guard
            !isApplyingItem,
            sender.selectedSegmentIndex != UISegmentedControl.noSegment,
            let item,
            item.choices.indices.contains(sender.selectedSegmentIndex)
        else {
            return
        }

        let choice = item.choices[sender.selectedSegmentIndex]
        guard choice.isEnabled else {
            return
        }

        onEvent?(.triggerAction(choice.id))
    }
}

private final class ChoiceChipButton: UIButton {
    var actionID: SettingsActionID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
    }

    func apply(item: SettingsChoiceItem) {
        actionID = item.id
        isSelected = item.isSelected
        isEnabled = item.isEnabled
        accessibilityLabel = item.accessibilityLabel
        accessibilityIdentifier = "settings-panel-choice-\(String(describing: item.id))"
        setTitle(item.title, for: .normal)
        setNeedsUpdateConfiguration()
    }

    override func updateConfiguration() {
        super.updateConfiguration()

        guard actionID != nil else {
            return
        }

        var nextConfiguration = configuration ?? UIButton.Configuration.filled()
        nextConfiguration.title = title(for: .normal)
        nextConfiguration.buttonSize = .medium
        nextConfiguration.cornerStyle = .capsule
        nextConfiguration.contentInsets = Style.buttonContentInsets
        nextConfiguration.baseBackgroundColor = resolvedBackgroundColor()
        nextConfiguration.baseForegroundColor = resolvedForegroundColor()
        configuration = nextConfiguration

        accessibilityTraits = isSelected
            ? [.button, .selected]
            : [.button]
    }

    private func configureButton() {
        configuration = .filled()
        configuration?.buttonSize = .medium
        configuration?.cornerStyle = .capsule
        configuration?.contentInsets = Style.buttonContentInsets

        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.78
        titleLabel?.lineBreakMode = .byTruncatingTail

        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func resolvedBackgroundColor() -> UIColor {
        if !isEnabled {
            return .quaternarySystemFill
        }

        if isSelected {
            return isHighlighted ? .systemBlue.withAlphaComponent(0.78) : .systemBlue
        }

        return isHighlighted ? .tertiarySystemFill : .secondarySystemFill
    }

    private func resolvedForegroundColor() -> UIColor {
        if !isEnabled {
            return .tertiaryLabel
        }

        return isSelected ? .white : .label
    }
}

private final class SliderRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var sliderID: SettingsSliderID?
    private var isApplyingItem = false

    private let contentStackView = UIStackView()
    private let headerStackView = UIStackView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(item: SettingsSliderRow) {
        sliderID = item.id
        accessibilityIdentifier = "settings-panel-slider-row-\(String(describing: item.id))"
        titleLabel.text = item.title
        valueLabel.text = item.displayValue
        slider.accessibilityLabel = item.accessibilityLabel
        slider.accessibilityIdentifier = "settings-panel-slider-\(String(describing: item.id))"
        slider.isEnabled = item.isEnabled
        isUserInteractionEnabled = item.isEnabled

        isApplyingItem = true
        slider.minimumValue = Float(item.range.lowerBound)
        slider.maximumValue = Float(item.range.upperBound)
        slider.setValue(Float(item.value), animated: false)
        isApplyingItem = false
    }

    private func configureView() {
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.spacing = Style.sliderContentSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        headerStackView.axis = .horizontal
        headerStackView.alignment = .firstBaseline
        headerStackView.distribution = .fill
        headerStackView.spacing = Style.headerSpacing

        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        slider.minimumTrackTintColor = .systemBlue
        slider.maximumTrackTintColor = .tertiarySystemFill
        slider.addTarget(
            self,
            action: #selector(handleSliderValueChanged(_:)),
            for: .valueChanged
        )

        addSubview(contentStackView)
        headerStackView.addArrangedSubview(titleLabel)
        headerStackView.addArrangedSubview(valueLabel)
        contentStackView.addArrangedSubview(headerStackView)
        contentStackView.addArrangedSubview(slider)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
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

private final class ToggleRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var toggleID: SettingsToggleID?
    private var isApplyingItem = false

    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let spacerView = UIView()
    private let toggleSwitch = UISwitch()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(item: SettingsToggleRow) {
        toggleID = item.id
        accessibilityIdentifier = "settings-panel-toggle-row-\(String(describing: item.id))"
        titleLabel.text = item.title
        toggleSwitch.accessibilityLabel = item.accessibilityLabel
        toggleSwitch.accessibilityIdentifier = "settings-panel-toggle-\(String(describing: item.id))"
        toggleSwitch.isEnabled = item.isEnabled
        isUserInteractionEnabled = item.isEnabled

        isApplyingItem = true
        toggleSwitch.setOn(item.isOn, animated: false)
        isApplyingItem = false
    }

    private func configureView() {
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.distribution = .fill
        contentStackView.spacing = Style.toggleSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        toggleSwitch.onTintColor = .systemGreen
        toggleSwitch.addTarget(
            self,
            action: #selector(handleToggleValueChanged(_:)),
            for: .valueChanged
        )

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

private final class FretFilterPlaceholderRowView: UIView {
    override var intrinsicContentSize: CGSize {
        .zero
    }

    func apply(item: SettingsFretFilterRow) {
        accessibilityIdentifier = "settings-panel-fret-filter-row-\(String(describing: item.id))"
        isUserInteractionEnabled = false
        isHidden = true
    }
}

private final class SectionView: UIView {
    var titleText: String = "" {
        didSet {
            titleLabel.text = titleText
            titleLabel.isHidden = titleText.isEmpty
        }
    }

    var rows: [UIView] = [] {
        didSet {
            replaceArrangedSubviews(
                in: rowsStackView,
                with: rows
            )
        }
    }

    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let rowsStackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.spacing = Style.sectionContentSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isHidden = true

        rowsStackView.axis = .vertical
        rowsStackView.alignment = .fill
        rowsStackView.distribution = .fill
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
        in stackView: UIStackView,
        with views: [UIView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? UIStackView {
                parentStackView.removeArrangedSubview(view)
            }
            view.removeFromSuperview()
            stackView.addArrangedSubview(view)
        }
    }
}

private enum Style {
    static let contentInsets = NSDirectionalEdgeInsets(
        top: 10,
        leading: 12,
        bottom: 10,
        trailing: 12
    )
    static let panelCornerRadius: CGFloat = 14
    static let sectionSpacing: CGFloat = 12
    static let sectionContentSpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 12
    static let choiceContentSpacing: CGFloat = 8
    static let sliderContentSpacing: CGFloat = 8
    static let headerSpacing: CGFloat = 8
    static let toggleSpacing: CGFloat = 12
    static let chipSpacing: CGFloat = 8
    static let buttonContentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 12,
        bottom: 8,
        trailing: 12
    )
}
#endif

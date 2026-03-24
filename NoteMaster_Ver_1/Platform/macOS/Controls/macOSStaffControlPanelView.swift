//
//  macOSStaffControlPanelView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

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

    convenience init(model: StaffControlPanelModel) {
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

    private func sectionView(for id: StaffControlSectionID) -> SectionView {
        if let existingView = sectionViews[id] {
            return existingView
        }

        let sectionView = SectionView()
        sectionViews[id] = sectionView
        return sectionView
    }

    private func sliderRow(for item: StaffSliderControlItem) -> SliderRowView {
        if let existingRow = sliderRowsByID[item.id] {
            return existingRow
        }

        let rowView = SliderRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        sliderRowsByID[item.id] = rowView
        return rowView
    }

    private func removeObsoleteSliderRows(notIn validIDs: Set<StaffSliderControlItem.ID>) {
        let obsoleteIDs = sliderRowsByID.keys.filter { !validIDs.contains($0) }

        for id in obsoleteIDs {
            guard let rowView = sliderRowsByID.removeValue(forKey: id) else {
                continue
            }

            if let stackView = rowView.superview as? NSStackView {
                stackView.removeArrangedSubview(rowView)
            }
            rowView.removeFromSuperview()
        }
    }

    private func removeObsoleteSectionViews(notIn validIDs: Set<StaffControlSectionID>) {
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

private final class SliderRowView: NSView {
    var onEvent: ((StaffControlEvent) -> Void)?

    private var sliderID: StaffSliderControlItem.ID?
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

private enum Style {
    static let contentInsets = NSEdgeInsets(
        top: 10,
        left: 12,
        bottom: 10,
        right: 12
    )
    static let panelCornerRadius: CGFloat = 14
    static let sectionSpacing: CGFloat = 12
    static let sectionContentSpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 12
    static let sliderContentSpacing: CGFloat = 8
    static let headerSpacing: CGFloat = 8
    static let minimumSliderWidth: CGFloat = 220
    static let captionFontSize: CGFloat = 12
    static let bodyFontSize: CGFloat = 13
    static let valueFontSize: CGFloat = 13
}
#endif

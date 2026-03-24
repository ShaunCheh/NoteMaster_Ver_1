//
//  iOSStaffControlPanelView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

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

        let rowView = SliderRowView()
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

            if let stackView = rowView.superview as? UIStackView {
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

private final class SliderRowView: UIView {
    var onEvent: ((StaffControlEvent) -> Void)?

    private var sliderID: StaffSliderControlItem.ID?
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
    static let sliderContentSpacing: CGFloat = 8
    static let headerSpacing: CGFloat = 8
}
#endif

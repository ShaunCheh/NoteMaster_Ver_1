//
//  iOSButtonPanelView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

#if os(iOS)
import UIKit

final class iOSButtonPanelView: UIView {
    var model: ButtonPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModel()
        }
    }

    var onAction: ((ButtonPanelActionID) -> Void)?

    override var intrinsicContentSize: CGSize {
        let stackSize = sectionsStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: directionalLayoutMargins.top + stackSize.height + directionalLayoutMargins.bottom
        )
    }

    private let sectionsStackView = UIStackView()
    private var sectionStacks: [ButtonPanelSectionID: UIStackView] = [:]
    private var buttonsByActionID: [ButtonPanelActionID: PanelActionButton] = [:]

    override init(frame: CGRect) {
        model = ButtonPanelModel(sections: [])
        super.init(frame: frame)
        configureView()
        applyModel()
    }

    convenience init(model: ButtonPanelModel) {
        self.init(frame: .zero)
        self.model = model
        applyModel()
    }

    required init?(coder: NSCoder) {
        model = ButtonPanelModel(sections: [])
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

        sectionsStackView.axis = .horizontal
        sectionsStackView.alignment = .fill
        sectionsStackView.distribution = .fill
        sectionsStackView.spacing = Style.sectionSpacing
        sectionsStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(sectionsStackView)

        NSLayoutConstraint.activate([
            sectionsStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            sectionsStackView.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor),
            sectionsStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            sectionsStackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }

    private func applyModel() {
        removeObsoleteButtons(notIn: Set(model.items.map(\.id)))
        removeObsoleteSectionStacks(notIn: Set(model.sections.map(\.id)))

        let orderedSectionStacks = model.sections.map { section -> UIStackView in
            let sectionStack = self.sectionStack(for: section.id)
            syncButtons(in: sectionStack, for: section)
            return sectionStack
        }

        replaceArrangedSubviews(
            in: sectionsStackView,
            with: orderedSectionStacks
        )

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

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

    private func sectionStack(for id: ButtonPanelSectionID) -> UIStackView {
        if let existingStack = sectionStacks[id] {
            return existingStack
        }

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = Style.itemSpacing
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = Style.sectionInsets
        sectionStacks[id] = stackView
        return stackView
    }

    private func actionButton(
        for item: ButtonPanelItem,
        sectionID: ButtonPanelSectionID
    ) -> PanelActionButton {
        if let existingButton = buttonsByActionID[item.id] {
            existingButton.sectionID = sectionID
            existingButton.apply(item: item)
            return existingButton
        }

        let button = PanelActionButton(frame: .zero)
        button.sectionID = sectionID
        button.addTarget(
            self,
            action: #selector(handleButtonTap(_:)),
            for: .touchUpInside
        )
        button.apply(item: item)
        buttonsByActionID[item.id] = button
        return button
    }

    private func removeObsoleteButtons(notIn validActionIDs: Set<ButtonPanelActionID>) {
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

    private func removeObsoleteSectionStacks(notIn validSectionIDs: Set<ButtonPanelSectionID>) {
        let obsoleteSectionIDs = sectionStacks.keys.filter { !validSectionIDs.contains($0) }

        for sectionID in obsoleteSectionIDs {
            guard let stackView = sectionStacks.removeValue(forKey: sectionID) else {
                continue
            }

            sectionsStackView.removeArrangedSubview(stackView)
            stackView.removeFromSuperview()
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
    private func handleButtonTap(_ sender: PanelActionButton) {
        guard let actionID = sender.actionID else {
            return
        }

        onAction?(actionID)
    }
}

private final class PanelActionButton: UIButton {
    var actionID: ButtonPanelActionID?
    var sectionID: ButtonPanelSectionID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
    }

    func apply(item: ButtonPanelItem) {
        actionID = item.id
        isSelected = item.isSelected
        isEnabled = item.isEnabled
        accessibilityLabel = item.accessibilityLabel
        accessibilityIdentifier = "button-panel-\(item.id)"
        setTitle(item.title, for: .normal)
        setNeedsUpdateConfiguration()
    }

    override func updateConfiguration() {
        super.updateConfiguration()

        guard let actionID else {
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

private enum Style {
    static let contentInsets = NSDirectionalEdgeInsets(
        top: 10,
        leading: 12,
        bottom: 10,
        trailing: 12
    )
    static let sectionInsets = NSDirectionalEdgeInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )
    static let sectionSpacing: CGFloat = 12
    static let itemSpacing: CGFloat = 8
    static let panelCornerRadius: CGFloat = 14
    static let buttonContentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 12,
        bottom: 8,
        trailing: 12
    )
}
#endif

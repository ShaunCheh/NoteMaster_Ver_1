//
//  macOSButtonPanelView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

#if os(macOS)
import AppKit

final class macOSButtonPanelView: NSView {
    var model: ButtonPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModel()
        }
    }

    var onAction: ((ButtonPanelActionID) -> Void)?

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        let stackSize = sectionsStackView.fittingSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
        )
    }

    private let sectionsStackView = NSStackView()
    private var sectionStacks: [ButtonPanelSectionID: NSStackView] = [:]
    private var buttonsByActionID: [ButtonPanelActionID: PanelActionButton] = [:]

    override init(frame frameRect: NSRect) {
        model = ButtonPanelModel(sections: [])
        super.init(frame: frameRect)
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
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = Style.panelCornerRadius

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        sectionsStackView.orientation = .horizontal
        sectionsStackView.alignment = .centerY
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
                lessThanOrEqualTo: trailingAnchor,
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
        removeObsoleteButtons(notIn: Set(model.items.map(\.id)))
        removeObsoleteSectionStacks(notIn: Set(model.sections.map(\.id)))

        let orderedSectionStacks = model.sections.map { section -> NSStackView in
            let sectionStack = self.sectionStack(for: section.id)
            syncButtons(in: sectionStack, for: section)
            return sectionStack
        }

        replaceArrangedSubviews(
            in: sectionsStackView,
            with: orderedSectionStacks
        )

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    private func syncButtons(
        in sectionStack: NSStackView,
        for section: ButtonPanelSection
    ) {
        let orderedButtons = section.items.map { item -> NSView in
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

    private func sectionStack(for id: ButtonPanelSectionID) -> NSStackView {
        if let existingStack = sectionStacks[id] {
            return existingStack
        }

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fill
        stackView.spacing = Style.itemSpacing
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
        button.target = self
        button.action = #selector(handleButtonTap(_:))
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

            if let stackView = button.superview as? NSStackView {
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
    private func handleButtonTap(_ sender: PanelActionButton) {
        guard let actionID = sender.actionID else {
            return
        }

        onAction?(actionID)
    }
}

private final class PanelActionButton: NSButton {
    var actionID: ButtonPanelActionID?
    var sectionID: ButtonPanelSectionID?

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

    func apply(item: ButtonPanelItem) {
        actionID = item.id
        state = item.isSelected ? .on : .off
        isEnabled = item.isEnabled
        title = item.title
        toolTip = item.accessibilityLabel
        identifier = NSUserInterfaceItemIdentifier("button-panel-\(String(describing: item.id))")
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
                .font: NSFont.systemFont(ofSize: Style.fontSize, weight: .medium),
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

private enum Style {
    static let contentInsets = NSEdgeInsets(
        top: 10,
        left: 12,
        bottom: 10,
        right: 12
    )
    static let sectionSpacing: CGFloat = 12
    static let itemSpacing: CGFloat = 8
    static let panelCornerRadius: CGFloat = 14
    static let buttonCornerRadius: CGFloat = 11
    static let minimumButtonHeight: CGFloat = 30
    static let fontSize: CGFloat = 13
    static let buttonContentInsets = NSEdgeInsets(
        top: 7,
        left: 12,
        bottom: 7,
        right: 12
    )
}
#endif

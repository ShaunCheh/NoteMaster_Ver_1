#if os(macOS)
import AppKit

final class macOSNaturalNoteStripView: NSView {
    var onPitchClassTap: ((PitchClass) -> Void)?
    var areButtonsEnabled = true {
        didSet {
            updateButtonEnabledState()
        }
    }

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        let stackSize = stackView.fittingSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
        )
    }

    private let stackView = NSStackView()
    private lazy var buttons: [NaturalNoteButton] = {
        PitchClass.naturalCasesInOrder.map { pitchClass in
            makeButton(for: pitchClass)
        }
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("natural-note-strip-view")
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = Style.cornerRadius
        layer?.borderWidth = Style.borderWidth
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillEqually
        stackView.spacing = Style.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }
        updateButtonEnabledState()

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.contentInsets.left
            ),
            stackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.contentInsets.right
            ),
            stackView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.contentInsets.top
            ),
            stackView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.contentInsets.bottom
            )
        ])
    }

    private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
        let button = NaturalNoteButton(frame: .zero)
        button.apply(pitchClass: pitchClass)
        button.target = self
        button.action = #selector(handleButtonTap(_:))
        return button
    }

    @objc
    private func handleButtonTap(_ sender: NaturalNoteButton) {
        guard let pitchClass = sender.pitchClass else {
            return
        }

        onPitchClassTap?(pitchClass)
    }

    private func updateButtonEnabledState() {
        buttons.forEach { $0.isEnabled = areButtonsEnabled }
    }
}

private final class NaturalNoteButton: NSButton {
    var pitchClass: PitchClass?

    private var isPressed = false

    override var isEnabled: Bool {
        didSet {
            applyCurrentAppearance()
        }
    }

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

    func apply(pitchClass: PitchClass) {
        self.pitchClass = pitchClass
        let title = pitchClass.displayText()
        self.title = title
        toolTip = "Choose natural note \(title)"
        identifier = NSUserInterfaceItemIdentifier(
            "natural-note-strip-button-\(title.lowercased())"
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
            buttonCell.lineBreakMode = .byClipping
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

        return isPressed
            ? NSColor.quaternaryLabelColor.withAlphaComponent(0.18)
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.1)
    }

    private func resolvedForegroundColor() -> NSColor {
        if !isEnabled {
            return .disabledControlTextColor
        }

        return .labelColor
    }
}

private enum Style {
    static let contentInsets = NSEdgeInsets(
        top: 10,
        left: 12,
        bottom: 10,
        right: 12
    )
    static let itemSpacing: CGFloat = 8
    static let cornerRadius: CGFloat = 22
    static let borderWidth: CGFloat = 1
    static let borderOpacity: CGFloat = 0.35
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

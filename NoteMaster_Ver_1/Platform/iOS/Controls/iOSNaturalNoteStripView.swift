#if os(iOS)
import UIKit

final class iOSNaturalNoteStripView: UIView {
    var onPitchClassTap: ((PitchClass) -> Void)?

    override var intrinsicContentSize: CGSize {
        let stackSize = stackView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: directionalLayoutMargins.top + stackSize.height + directionalLayoutMargins.bottom
        )
    }

    private let stackView = UIStackView()
    private lazy var buttons: [NaturalNoteButton] = {
        PitchClass.naturalCasesInOrder.map { pitchClass in
            makeButton(for: pitchClass)
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        accessibilityIdentifier = "natural-note-strip-view"
        directionalLayoutMargins = Style.contentInsets
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = Style.cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = Style.borderWidth
        layer.borderColor = UIColor.separator.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = Style.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }

    private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
        let button = NaturalNoteButton(frame: .zero)
        button.apply(pitchClass: pitchClass)
        button.addTarget(
            self,
            action: #selector(handleButtonTap(_:)),
            for: .touchUpInside
        )
        return button
    }

    @objc
    private func handleButtonTap(_ sender: NaturalNoteButton) {
        guard let pitchClass = sender.pitchClass else {
            return
        }

        onPitchClassTap?(pitchClass)
    }
}

private final class NaturalNoteButton: UIButton {
    var pitchClass: PitchClass?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
    }

    func apply(pitchClass: PitchClass) {
        self.pitchClass = pitchClass
        let title = pitchClass.displayText()
        accessibilityIdentifier = "natural-note-strip-button-\(title.lowercased())"
        accessibilityLabel = "Choose natural note \(title)"
        setTitle(title, for: .normal)
        setNeedsUpdateConfiguration()
    }

    override func updateConfiguration() {
        super.updateConfiguration()

        guard pitchClass != nil else {
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
    }

    private func configureButton() {
        configuration = .filled()
        configuration?.buttonSize = .medium
        configuration?.cornerStyle = .capsule
        configuration?.contentInsets = Style.buttonContentInsets

        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.7
        titleLabel?.lineBreakMode = .byClipping

        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func resolvedBackgroundColor() -> UIColor {
        if !isEnabled {
            return .quaternarySystemFill
        }

        return isHighlighted ? .tertiarySystemFill : .secondarySystemFill
    }

    private func resolvedForegroundColor() -> UIColor {
        if !isEnabled {
            return .tertiaryLabel
        }

        return .label
    }
}

private enum Style {
    static let contentInsets = NSDirectionalEdgeInsets(
        top: 10,
        leading: 12,
        bottom: 10,
        trailing: 12
    )
    static let itemSpacing: CGFloat = 8
    static let cornerRadius: CGFloat = 22
    static let borderWidth: CGFloat = 1
    static let borderOpacity: CGFloat = 0.35
    static let buttonContentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 12,
        bottom: 8,
        trailing: 12
    )
}
#endif

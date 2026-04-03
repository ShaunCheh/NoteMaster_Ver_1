#if os(iOS)
import UIKit

final class iOSNaturalNoteStripView: UIView {
    enum LayoutMode: Equatable {
        case horizontalStrip
        case verticalRail
    }

    var onPitchClassTap: ((PitchClass) -> Void)?
    var layoutMode: LayoutMode = .horizontalStrip {
        didSet {
            guard oldValue != layoutMode else {
                return
            }
            applyLayoutMode()
        }
    }

    private var railContract: ExerciseNaturalNoteStripRailContract = .defaultSideBySideAnswerRail {
        didSet {
            guard oldValue != railContract else {
                return
            }
            applyLayoutMode()
        }
    }

    override var intrinsicContentSize: CGSize {
        switch layoutMode {
        case .horizontalStrip:
            return CGSize(
                width: UIView.noIntrinsicMetric,
                height: directionalLayoutMargins.top
                    + tallestButtonIntrinsicHeight
                    + directionalLayoutMargins.bottom
            )
        case .verticalRail:
            return CGSize(
                width: verticalRailIntrinsicWidth,
                height: verticalRailIntrinsicHeight
            )
        }
    }

    private let stackView = UIStackView()
    private lazy var buttons: [NaturalNoteButton] = {
        PitchClass.allCases.map { pitchClass in
            makeButton(for: pitchClass)
        }
    }()
    private var tallestButtonIntrinsicHeight: CGFloat {
        buttons.reduce(0) { partialResult, button in
            max(partialResult, button.intrinsicContentSize.height)
        }
    }
    private var activeRailContract: ExerciseNaturalNoteStripRailContract {
        railContract
    }
    private var activeRailButtonExtent: CGFloat {
        CGFloat(activeRailContract.buttonExtent)
    }
    private var activeRailCrossAxisWidthScale: CGFloat {
        CGFloat(activeRailContract.resolvedCrossAxisWidthScale)
    }
    private var verticalRailContentWidth: CGFloat {
        directionalLayoutMargins.leading
            + activeRailButtonExtent
            + directionalLayoutMargins.trailing
    }
    private var verticalRailIntrinsicWidth: CGFloat {
        switch activeRailContract.crossAxisPolicy {
        case .fitContent:
            return verticalRailContentWidth * activeRailCrossAxisWidthScale
        }
    }
    private var verticalRailIntrinsicHeight: CGFloat {
        switch activeRailContract.mainAxisPolicy {
        case .contentSized:
            let slotCount = CGFloat(activeRailContract.slotModel.slotCount)
            let totalSpacing = max(0, slotCount - 1) * Style.itemSpacing
            return directionalLayoutMargins.top
                + (slotCount * activeRailButtonExtent)
                + totalSpacing
                + directionalLayoutMargins.bottom
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func applyPresentationStyle(
        _ presentationStyle: ExerciseSurfacePresentationStyle
    ) {
        switch presentationStyle {
        case .verticalRail:
            layoutMode = .verticalRail
        case .standard, .horizontalStrip:
            layoutMode = .horizontalStrip
        }
    }

    func applyRailContract(_ railContract: ExerciseNaturalNoteStripRailContract?) {
        self.railContract = railContract ?? .defaultSideBySideAnswerRail
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

        applyLayoutMode()
    }

    private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
        let button = NaturalNoteButton(frame: .zero)
        button.apply(pitchClass: pitchClass)
        button.applyLayoutMode(layoutMode, railContract: activeRailContract)
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

    private func applyLayoutMode() {
        switch layoutMode {
        case .horizontalStrip:
            stackView.axis = .horizontal
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        case .verticalRail:
            stackView.axis = .vertical
            stackView.alignment = .center
            stackView.distribution = .fill
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        }

        buttons.forEach {
            $0.applyLayoutMode(layoutMode, railContract: activeRailContract)
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}

private final class NaturalNoteButton: UIButton {
    var pitchClass: PitchClass?
    private var layoutMode: iOSNaturalNoteStripView.LayoutMode = .horizontalStrip
    private var railContract: ExerciseNaturalNoteStripRailContract = .defaultSideBySideAnswerRail

    override var intrinsicContentSize: CGSize {
        switch layoutMode {
        case .horizontalStrip:
            return super.intrinsicContentSize
        case .verticalRail:
            let buttonExtent = CGFloat(railContract.buttonExtent)
            return CGSize(width: buttonExtent, height: buttonExtent)
        }
    }

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
        accessibilityIdentifier = "natural-note-strip-button-\(pitchClass.stripIdentifierToken)"
        accessibilityLabel = "Choose note \(pitchClass.stripAccessibilityLabel)"
        setTitle(pitchClass.stripVisibleTitle, for: .normal)
        invalidateIntrinsicContentSize()
        setNeedsUpdateConfiguration()
    }

    override func updateConfiguration() {
        super.updateConfiguration()

        guard pitchClass != nil else {
            return
        }

        var nextConfiguration = configuration ?? UIButton.Configuration.filled()
        nextConfiguration.title = title(for: .normal)
        nextConfiguration.buttonSize = layoutMode == .verticalRail ? .mini : .medium
        nextConfiguration.cornerStyle = .capsule
        nextConfiguration.contentInsets = resolvedContentInsets()
        nextConfiguration.baseBackgroundColor = resolvedBackgroundColor()
        nextConfiguration.baseForegroundColor = resolvedForegroundColor()
        let resolvedFont = resolvedTitleFont()
        nextConfiguration.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = resolvedFont
                return outgoing
            }
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
    }

    func applyLayoutMode(
        _ layoutMode: iOSNaturalNoteStripView.LayoutMode,
        railContract: ExerciseNaturalNoteStripRailContract
    ) {
        self.layoutMode = layoutMode
        self.railContract = railContract
        switch layoutMode {
        case .horizontalStrip:
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .vertical)
            setContentHuggingPriority(.required, for: .vertical)
        case .verticalRail:
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .vertical)
            setContentHuggingPriority(.required, for: .vertical)
        }

        invalidateIntrinsicContentSize()
        setNeedsUpdateConfiguration()
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

    private func resolvedContentInsets() -> NSDirectionalEdgeInsets {
        switch layoutMode {
        case .horizontalStrip:
            return Style.buttonContentInsets
        case .verticalRail:
            return .zero
        }
    }

    private func resolvedTitleFont() -> UIFont {
        switch layoutMode {
        case .horizontalStrip:
            return UIFont.systemFont(ofSize: Style.fontSize, weight: .medium)
        case .verticalRail:
            let railFontSize = min(
                Style.fontSize,
                max(9, CGFloat(railContract.buttonExtent) * 0.55)
            )
            return UIFont.systemFont(ofSize: railFontSize, weight: .medium)
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
    static let itemSpacing: CGFloat = 6
    static let cornerRadius: CGFloat = 22
    static let borderWidth: CGFloat = 1
    static let borderOpacity: CGFloat = 0.35
    static let fontSize: CGFloat = 13
    static let buttonContentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 8,
        bottom: 8,
        trailing: 8
    )
}

private extension PitchClass {
    var stripVisibleTitle: String {
        isNatural ? displayText() : ""
    }

    var stripAccessibilityLabel: String {
        switch self {
        case .c:
            return "C"
        case .cSharp:
            return "C sharp / D flat"
        case .d:
            return "D"
        case .dSharp:
            return "D sharp / E flat"
        case .e:
            return "E"
        case .f:
            return "F"
        case .fSharp:
            return "F sharp / G flat"
        case .g:
            return "G"
        case .gSharp:
            return "G sharp / A flat"
        case .a:
            return "A"
        case .aSharp:
            return "A sharp / B flat"
        case .b:
            return "B"
        }
    }

    var stripIdentifierToken: String {
        switch self {
        case .c:
            return "c"
        case .cSharp:
            return "c-sharp-d-flat"
        case .d:
            return "d"
        case .dSharp:
            return "d-sharp-e-flat"
        case .e:
            return "e"
        case .f:
            return "f"
        case .fSharp:
            return "f-sharp-g-flat"
        case .g:
            return "g"
        case .gSharp:
            return "g-sharp-a-flat"
        case .a:
            return "a"
        case .aSharp:
            return "a-sharp-b-flat"
        case .b:
            return "b"
        }
    }
}
#endif

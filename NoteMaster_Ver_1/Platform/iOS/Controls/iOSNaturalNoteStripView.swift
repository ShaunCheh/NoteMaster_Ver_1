#if os(iOS)
import UIKit

private let defaultNaturalNoteStripRailLayout =
    ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
        .defaultLayoutContext
        .resolvedLayout

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

    private var railLayout: ExerciseNaturalNoteStripRailLayout =
        defaultNaturalNoteStripRailLayout {
        didSet {
            guard oldValue != railLayout else {
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
    private let railCanvasView = UIView()
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
    private var activeRailLayout: ExerciseNaturalNoteStripRailLayout {
        railLayout
    }
    private var verticalRailIntrinsicWidth: CGFloat {
        CGFloat(activeRailLayout.contentSize.width)
    }
    private var verticalRailIntrinsicHeight: CGFloat {
        CGFloat(activeRailLayout.contentSize.height)
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

    func applyRailLayout(_ railLayout: ExerciseNaturalNoteStripRailLayout?) {
        self.railLayout = railLayout ?? defaultNaturalNoteStripRailLayout
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutRailCanvasIfNeeded()
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
        railCanvasView.isHidden = true
        railCanvasView.clipsToBounds = true

        addSubview(stackView)
        addSubview(railCanvasView)

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
        button.applyLayoutMode(layoutMode, railLayout: activeRailLayout)
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

        syncButtonContainer()
        buttons.forEach {
            $0.applyLayoutMode(layoutMode, railLayout: activeRailLayout)
            $0.applyVisibleTitle(
                resolvedVisibleTitle(for: $0.pitchClass)
            )
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func syncButtonContainer() {
        switch layoutMode {
        case .horizontalStrip:
            stackView.isHidden = false
            railCanvasView.isHidden = true
            buttons.forEach { button in
                detachButtonFromCurrentContainer(button)
                stackView.addArrangedSubview(button)
            }
        case .verticalRail:
            stackView.isHidden = true
            railCanvasView.isHidden = false
            buttons.forEach { button in
                detachButtonFromCurrentContainer(button)
                railCanvasView.addSubview(button)
            }
        }
    }

    private func detachButtonFromCurrentContainer(_ button: NaturalNoteButton) {
        if stackView.arrangedSubviews.contains(button) {
            stackView.removeArrangedSubview(button)
        }
        button.removeFromSuperview()
    }

    private func resolvedVisibleTitle(for pitchClass: PitchClass?) -> String {
        guard let pitchClass else {
            return ""
        }

        switch layoutMode {
        case .horizontalStrip:
            return pitchClass.stripVisibleTitle
        case .verticalRail:
            return pitchClass.stripVisibleTitle(
                showsTitle: railPlacement(for: pitchClass)?.showsTitle ?? false
            )
        }
    }

    private func railPlacement(
        for pitchClass: PitchClass
    ) -> ExerciseNaturalNoteStripRailPlacement? {
        activeRailLayout.placements.first { $0.pitchClass == pitchClass }
    }

    private func layoutRailCanvasIfNeeded() {
        guard layoutMode == .verticalRail else {
            railCanvasView.frame = .zero
            return
        }

        let contentSize = CGSize(
            width: verticalRailIntrinsicWidth,
            height: verticalRailIntrinsicHeight
        )
        let contentFrame = CGRect(
            x: max(0, (bounds.width - contentSize.width) / 2),
            y: max(0, (bounds.height - contentSize.height) / 2),
            width: min(bounds.width, contentSize.width),
            height: min(bounds.height, contentSize.height)
        )
        railCanvasView.frame = contentFrame

        buttons.forEach { button in
            guard
                let pitchClass = button.pitchClass,
                let placement = railPlacement(for: pitchClass)
            else {
                button.isHidden = true
                return
            }

            button.isHidden = false
            button.frame = placement.frame
        }
    }
}

private final class NaturalNoteButton: UIButton {
    var pitchClass: PitchClass?
    private var layoutMode: iOSNaturalNoteStripView.LayoutMode = .horizontalStrip
    private var railLayout: ExerciseNaturalNoteStripRailLayout =
        defaultNaturalNoteStripRailLayout

    private var activeRailButtonExtent: CGFloat {
        CGFloat(railLayout.buttonExtent)
    }

    override var intrinsicContentSize: CGSize {
        switch layoutMode {
        case .horizontalStrip:
            return super.intrinsicContentSize
        case .verticalRail:
            return CGSize(
                width: activeRailButtonExtent,
                height: activeRailButtonExtent
            )
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
        applyVisibleTitle(pitchClass.stripVisibleTitle)
    }

    func applyVisibleTitle(_ title: String) {
        setTitle(title, for: .normal)
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
        railLayout: ExerciseNaturalNoteStripRailLayout
    ) {
        self.layoutMode = layoutMode
        self.railLayout = railLayout
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
                max(9, activeRailButtonExtent * 0.55)
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

    func stripVisibleTitle(showsTitle: Bool) -> String {
        showsTitle ? displayText() : ""
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

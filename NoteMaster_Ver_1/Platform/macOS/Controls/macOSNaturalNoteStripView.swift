#if os(macOS)
import AppKit

private let defaultNaturalNoteStripRailLayout =
    ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
        .defaultLayoutContext
        .resolvedLayout

final class macOSNaturalNoteStripView: NSView {
    enum LayoutMode: Equatable {
        case horizontalStrip
        case verticalRail
    }

    var onPitchClassTap: ((PitchClass) -> Void)?
    var areButtonsEnabled = true {
        didSet {
            updateButtonEnabledState()
        }
    }
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

    override var intrinsicContentSize: NSSize {
        switch layoutMode {
        case .horizontalStrip:
            return NSSize(
                width: NSView.noIntrinsicMetric,
                height: Style.contentInsets.top
                    + tallestButtonIntrinsicHeight
                    + Style.contentInsets.bottom
            )
        case .verticalRail:
            return NSSize(
                width: verticalRailIntrinsicWidth,
                height: verticalRailIntrinsicHeight
            )
        }
    }

    private let stackView = NSStackView()
    private let railCanvasView = RailCanvasView()
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

    override func layout() {
        super.layout()
        layoutRailCanvasIfNeeded()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("natural-note-strip-view")
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = Style.cornerRadius
        layer?.borderWidth = Style.borderWidth
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        stackView.spacing = Style.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        railCanvasView.isHidden = true

        addSubview(stackView)
        addSubview(railCanvasView)
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

        applyLayoutMode()
    }

    private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
        let button = NaturalNoteButton(frame: .zero)
        button.apply(pitchClass: pitchClass)
        button.applyLayoutMode(layoutMode, railLayout: activeRailLayout)
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

    private func applyLayoutMode() {
        switch layoutMode {
        case .horizontalStrip:
            stackView.orientation = .horizontal
            stackView.alignment = .centerY
            stackView.distribution = .fillEqually
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        case .verticalRail:
            stackView.orientation = .vertical
            stackView.alignment = .centerX
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
        needsLayout = true
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

private final class RailCanvasView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private final class NaturalNoteButton: NSButton {
    var pitchClass: PitchClass?

    private var isPressed = false
    private var layoutMode: macOSNaturalNoteStripView.LayoutMode = .horizontalStrip
    private var railLayout: ExerciseNaturalNoteStripRailLayout =
        defaultNaturalNoteStripRailLayout

    override var isEnabled: Bool {
        didSet {
            applyCurrentAppearance()
        }
    }

    private var activeRailButtonExtent: CGFloat {
        CGFloat(railLayout.buttonExtent)
    }

    override var intrinsicContentSize: NSSize {
        switch layoutMode {
        case .horizontalStrip:
            let size = super.intrinsicContentSize
            return NSSize(
                width: size.width
                    + Style.buttonContentInsets.left
                    + Style.buttonContentInsets.right,
                height: max(
                    size.height
                        + Style.buttonContentInsets.top
                        + Style.buttonContentInsets.bottom,
                    Style.minimumButtonHeight
                )
            )
        case .verticalRail:
            return NSSize(
                width: activeRailButtonExtent,
                height: activeRailButtonExtent
            )
        }
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
        toolTip = "Choose note \(pitchClass.stripAccessibilityLabel)"
        identifier = NSUserInterfaceItemIdentifier(
            "natural-note-strip-button-\(pitchClass.stripIdentifierToken)"
        )
        applyVisibleTitle(pitchClass.stripVisibleTitle)
    }

    func applyVisibleTitle(_ title: String) {
        self.title = title
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
    }

    private func applyCurrentAppearance() {
        layer?.cornerRadius = resolvedCornerRadius()
        layer?.backgroundColor = resolvedBackgroundColor().cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: resolvedFont(),
                .foregroundColor: resolvedForegroundColor()
            ]
        )
    }

    func applyLayoutMode(
        _ layoutMode: macOSNaturalNoteStripView.LayoutMode,
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

        applyCurrentAppearance()
        invalidateIntrinsicContentSize()
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

    private func resolvedFont() -> NSFont {
        switch layoutMode {
        case .horizontalStrip:
            return NSFont.systemFont(ofSize: Style.fontSize, weight: .medium)
        case .verticalRail:
            let railFontSize = min(
                Style.fontSize,
                max(9, activeRailButtonExtent * 0.55)
            )
            return NSFont.systemFont(ofSize: railFontSize, weight: .medium)
        }
    }

    private func resolvedCornerRadius() -> CGFloat {
        switch layoutMode {
        case .horizontalStrip:
            return Style.buttonCornerRadius
        case .verticalRail:
            return activeRailButtonExtent / 2
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
    static let itemSpacing: CGFloat = 6
    static let cornerRadius: CGFloat = 22
    static let borderWidth: CGFloat = 1
    static let borderOpacity: CGFloat = 0.35
    static let buttonCornerRadius: CGFloat = 11
    static let minimumButtonHeight: CGFloat = 30
    static let fontSize: CGFloat = 13
    static let buttonContentInsets = NSEdgeInsets(
        top: 7,
        left: 8,
        bottom: 7,
        right: 8
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

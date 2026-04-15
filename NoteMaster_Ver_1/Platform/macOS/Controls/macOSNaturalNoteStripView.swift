#if os(macOS)
import AppKit

private let defaultNaturalNoteStripHorizontalLayout =
    ExerciseNaturalNoteStripHorizontalLayoutContext(
        appliesToSurface: .naturalNoteStrip,
        titleDisplayPolicy:
            ExerciseNaturalNoteStripHorizontalLayoutContext
            .defaultTitleDisplayPolicy,
        geometry: .defaultTwoRowHorizontalStrip(),
        accidentalPitchClasses: PitchClass.accidentalCasesInOrder,
        naturalPitchClasses: PitchClass.naturalCasesInOrder
    ).resolvedLayout

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
    private var layoutMode: LayoutMode = .horizontalStrip
    private var horizontalLayout: ExerciseNaturalNoteStripHorizontalLayout =
        defaultNaturalNoteStripHorizontalLayout
    private var railLayout: ExerciseNaturalNoteStripRailLayout =
        defaultNaturalNoteStripRailLayout

    override var intrinsicContentSize: NSSize {
        switch layoutMode {
        case .horizontalStrip:
            return NSSize(
                width: NSView.noIntrinsicMetric,
                height: horizontalStripIntrinsicHeight
            )
        case .verticalRail:
            return NSSize(
                width: verticalRailIntrinsicWidth,
                height: verticalRailIntrinsicHeight
            )
        }
    }

    private let stackView = NSStackView()
    private let accidentalRowStackView = NSStackView()
    private let naturalRowStackView = NSStackView()
    private let railCanvasView = RailCanvasView()
    private lazy var buttons: [NaturalNoteButton] = {
        PitchClass.allCases.map { pitchClass in
            makeButton(for: pitchClass)
        }
    }()
    private var stackViewLeadingConstraint: NSLayoutConstraint?
    private var stackViewTrailingConstraint: NSLayoutConstraint?
    private var stackViewTopConstraint: NSLayoutConstraint?
    private var stackViewBottomConstraint: NSLayoutConstraint?
    private var activeHorizontalLayout: ExerciseNaturalNoteStripHorizontalLayout {
        horizontalLayout
    }
    private var horizontalStripIntrinsicHeight: CGFloat {
        CGFloat(activeHorizontalLayout.contentSize.height)
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

    func applyConfiguration(
        presentationStyle: ExerciseSurfacePresentationStyle,
        horizontalLayout: ExerciseNaturalNoteStripHorizontalLayout?,
        railLayout: ExerciseNaturalNoteStripRailLayout?
    ) {
        let nextLayoutMode = resolvedLayoutMode(for: presentationStyle)
        let nextHorizontalLayout =
            horizontalLayout ?? defaultNaturalNoteStripHorizontalLayout
        let nextRailLayout = railLayout ?? defaultNaturalNoteStripRailLayout
        guard
            layoutMode != nextLayoutMode
                || self.horizontalLayout != nextHorizontalLayout
                || self.railLayout != nextRailLayout
        else {
            return
        }

        layoutMode = nextLayoutMode
        self.horizontalLayout = nextHorizontalLayout
        self.railLayout = nextRailLayout
        applyLayoutMode()
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
        stackView.translatesAutoresizingMaskIntoConstraints = false
        railCanvasView.isHidden = true
        configureHorizontalStripContainer()

        addSubview(stackView)
        addSubview(railCanvasView)
        updateButtonEnabledState()

        stackViewLeadingConstraint = stackView.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: Style.contentInsets.left
        )
        stackViewTrailingConstraint = stackView.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -Style.contentInsets.right
        )
        stackViewTopConstraint = stackView.topAnchor.constraint(
            equalTo: topAnchor,
            constant: Style.contentInsets.top
        )
        stackViewBottomConstraint = stackView.bottomAnchor.constraint(
            equalTo: bottomAnchor,
            constant: -Style.contentInsets.bottom
        )

        NSLayoutConstraint.activate(
            [
                stackViewLeadingConstraint,
                stackViewTrailingConstraint,
                stackViewTopConstraint,
                stackViewBottomConstraint
            ].compactMap { $0 }
        )

        applyLayoutMode()
    }

    private func configureHorizontalStripContainer() {
        stackView.orientation = .vertical
        stackView.alignment = .width
        stackView.distribution = .fillEqually
        stackView.spacing = Style.itemSpacing

        accidentalRowStackView.orientation = .horizontal
        accidentalRowStackView.alignment = .height
        accidentalRowStackView.distribution = .fillEqually

        naturalRowStackView.orientation = .horizontal
        naturalRowStackView.alignment = .height
        naturalRowStackView.distribution = .fillEqually

        stackView.addArrangedSubview(accidentalRowStackView)
        stackView.addArrangedSubview(naturalRowStackView)
    }

    private func updateHorizontalStripInsets() {
        let contentInsets = resolvedHorizontalLayoutInsets()
        stackViewLeadingConstraint?.constant = contentInsets.left
        stackViewTrailingConstraint?.constant = -contentInsets.right
        stackViewTopConstraint?.constant = contentInsets.top
        stackViewBottomConstraint?.constant = -contentInsets.bottom
    }

    private func resolvedHorizontalLayoutInsets() -> NSEdgeInsets {
        let contentInsets = activeHorizontalLayout.context.geometry.contentInsets
        return NSEdgeInsets(
            top: CGFloat(contentInsets.top),
            left: CGFloat(contentInsets.leading),
            bottom: CGFloat(contentInsets.bottom),
            right: CGFloat(contentInsets.trailing)
        )
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
            updateHorizontalStripInsets()
            stackView.orientation = .vertical
            stackView.alignment = .width
            stackView.distribution = .fillEqually
            stackView.spacing = resolvedHorizontalRowSpacing
            accidentalRowStackView.spacing = resolvedHorizontalColumnSpacing
            naturalRowStackView.spacing = resolvedHorizontalColumnSpacing
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        case .verticalRail:
            stackViewLeadingConstraint?.constant = Style.contentInsets.left
            stackViewTrailingConstraint?.constant = -Style.contentInsets.right
            stackViewTopConstraint?.constant = Style.contentInsets.top
            stackViewBottomConstraint?.constant = -Style.contentInsets.bottom
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
            syncHorizontalStripRows()
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
        for rowStackView in [accidentalRowStackView, naturalRowStackView] {
            if rowStackView.arrangedSubviews.contains(button) {
                rowStackView.removeArrangedSubview(button)
            }
        }
        button.removeFromSuperview()
    }

    private func syncHorizontalStripRows() {
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            button.isHidden = true
        }

        resolvedHorizontalButtons(for: .accidentalsTop).forEach { button in
            button.isHidden = false
            accidentalRowStackView.addArrangedSubview(button)
        }
        resolvedHorizontalButtons(for: .naturalsBottom).forEach { button in
            button.isHidden = false
            naturalRowStackView.addArrangedSubview(button)
        }
    }

    private func resolvedVisibleTitle(for pitchClass: PitchClass?) -> String {
        guard let pitchClass else {
            return ""
        }

        switch layoutMode {
        case .horizontalStrip:
            return pitchClass.stripVisibleTitle(
                showsTitle: horizontalPlacement(for: pitchClass)?.showsTitle
                    ?? false
            )
        case .verticalRail:
            return pitchClass.stripVisibleTitle(
                showsTitle: railPlacement(for: pitchClass)?.showsTitle ?? false
            )
        }
    }

    private func horizontalPlacement(
        for pitchClass: PitchClass
    ) -> ExerciseNaturalNoteStripHorizontalPlacement? {
        activeHorizontalLayout.placementsInDisplayOrder.first {
            $0.pitchClass == pitchClass
        }
    }

    private func railPlacement(
        for pitchClass: PitchClass
    ) -> ExerciseNaturalNoteStripRailPlacement? {
        activeRailLayout.placements.first { $0.pitchClass == pitchClass }
    }

    private func resolvedHorizontalButtons(
        for row: ExerciseNaturalNoteStripHorizontalRow
    ) -> [NaturalNoteButton] {
        buttons
            .compactMap { button -> (Int, NaturalNoteButton)? in
                guard
                    let pitchClass = button.pitchClass,
                    let placement = horizontalPlacement(for: pitchClass),
                    placement.row == row
                else {
                    return nil
                }

                return (placement.columnIndex, button)
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
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

    private func resolvedLayoutMode(
        for presentationStyle: ExerciseSurfacePresentationStyle
    ) -> LayoutMode {
        switch presentationStyle {
        case .verticalRail:
            return .verticalRail
        case .standard, .horizontalStrip:
            return .horizontalStrip
        }
    }

    private var resolvedHorizontalRowSpacing: CGFloat {
        CGFloat(activeHorizontalLayout.context.geometry.resolvedRowSpacing)
    }

    private var resolvedHorizontalColumnSpacing: CGFloat {
        CGFloat(activeHorizontalLayout.context.geometry.resolvedColumnSpacing)
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

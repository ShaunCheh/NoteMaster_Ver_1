#if os(macOS)
import AppKit

final class macOSTargetNotePromptView: NSView {
    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.preferredHeight
        )
    }

    private var currentContent: TargetPromptContent?
    private let noteLabel = NSTextField(labelWithString: Style.placeholderText)
    private let sequenceScrollView = NSScrollView()
    private let sequenceDocumentView = NSView()
    private let sequenceStackView = NSStackView()
    private var sequenceItemViews: [SequenceTokenView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    convenience init(content: TargetPromptContent) {
        self.init(frame: .zero)
        apply(content: content)
    }

    convenience init(prompt: FretboardNaturalNoteTrainerState.Prompt) {
        self.init(frame: .zero)
        apply(prompt: prompt)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func layout() {
        super.layout()
        layoutSequenceDocumentView()
    }

    // 组件只负责显示共享 prompt 内容，不持有 trainer 状态机。
    func apply(content: TargetPromptContent) {
        guard currentContent != content else {
            return
        }

        currentContent = content
        applyContent()
    }

    // 兼容当前单目标调用方；后续 controller 完成统一投影后可直接走 apply(content:)。
    func apply(prompt: FretboardNaturalNoteTrainerState.Prompt) {
        apply(content: prompt.targetPromptContent)
    }

    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = Style.cornerRadius
        layer?.borderWidth = Style.borderWidth
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        identifier = NSUserInterfaceItemIdentifier("target-note-prompt-view")
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.font = .systemFont(
            ofSize: Style.noteFontSize,
            weight: .bold
        )
        noteLabel.textColor = .labelColor
        noteLabel.alignment = .center
        noteLabel.lineBreakMode = .byClipping

        sequenceScrollView.translatesAutoresizingMaskIntoConstraints = false
        sequenceScrollView.drawsBackground = false
        sequenceScrollView.borderType = .noBorder
        sequenceScrollView.hasVerticalScroller = false
        sequenceScrollView.hasHorizontalScroller = true
        sequenceScrollView.autohidesScrollers = true
        sequenceScrollView.scrollerStyle = .overlay
        sequenceScrollView.horizontalScrollElasticity = .allowed
        sequenceScrollView.verticalScrollElasticity = .none
        sequenceScrollView.documentView = sequenceDocumentView

        sequenceStackView.orientation = .horizontal
        sequenceStackView.alignment = .centerY
        sequenceStackView.distribution = .fill
        sequenceStackView.spacing = Style.sequenceItemSpacing
        sequenceDocumentView.addSubview(sequenceStackView)

        addSubview(noteLabel)
        addSubview(sequenceScrollView)

        NSLayoutConstraint.activate([
            noteLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.contentInsets.left
            ),
            noteLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.contentInsets.right
            ),
            noteLabel.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.contentInsets.top
            ),
            noteLabel.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.contentInsets.bottom
            ),
            sequenceScrollView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.contentInsets.left
            ),
            sequenceScrollView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.contentInsets.right
            ),
            sequenceScrollView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.contentInsets.top
            ),
            sequenceScrollView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.contentInsets.bottom
            )
        ])

        applyContent()
    }

    private func applyContent() {
        guard let currentContent else {
            applyPlaceholder()
            return
        }

        toolTip = currentContent.accessibilityLabel

        switch currentContent {
        case let .single(text):
            noteLabel.stringValue = text
            noteLabel.isHidden = false
            sequenceScrollView.isHidden = true
        case let .sequence(_, currentIndex):
            noteLabel.isHidden = true
            sequenceScrollView.isHidden = false
            rebuildSequenceItems(
                from: currentContent.sequenceDisplayItems
            )
            needsLayout = true
            layoutSubtreeIfNeeded()
            scrollSequenceItemIntoView(currentIndex: currentIndex)
        }
    }

    private func applyPlaceholder() {
        noteLabel.stringValue = Style.placeholderText
        noteLabel.isHidden = false
        noteLabel.toolTip = "Current target note unavailable"
        toolTip = noteLabel.toolTip
        sequenceScrollView.isHidden = true
        rebuildSequenceItems(from: [])
    }

    private func rebuildSequenceItems(
        from items: [TargetPromptSequenceDisplayItem]
    ) {
        sequenceItemViews.forEach {
            sequenceStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        sequenceItemViews = items.map { item in
            let itemView = SequenceTokenView(frame: .zero)
            itemView.apply(item: item)
            sequenceStackView.addArrangedSubview(itemView)
            return itemView
        }
    }

    private func layoutSequenceDocumentView() {
        guard !sequenceScrollView.isHidden else {
            return
        }

        sequenceStackView.layoutSubtreeIfNeeded()
        let viewportSize = sequenceScrollView.contentView.bounds.size
        let stackSize = sequenceStackView.fittingSize
        let documentWidth = max(viewportSize.width, stackSize.width)
        let documentHeight = max(viewportSize.height, stackSize.height)
        sequenceDocumentView.frame = NSRect(
            x: 0,
            y: 0,
            width: documentWidth,
            height: documentHeight
        )
        sequenceStackView.frame = NSRect(
            x: 0,
            y: floor((documentHeight - stackSize.height) / 2),
            width: stackSize.width,
            height: stackSize.height
        )
    }

    private func scrollSequenceItemIntoView(currentIndex: Int) {
        guard !sequenceItemViews.isEmpty else {
            return
        }

        let targetIndex = min(
            max(currentIndex, 0),
            sequenceItemViews.count - 1
        )

        layoutSequenceDocumentView()

        let targetView = sequenceItemViews[targetIndex]
        let visibleRect = targetView.convert(
            targetView.bounds,
            to: sequenceDocumentView
        ).insetBy(dx: -Style.sequenceScrollPadding, dy: 0)
        sequenceDocumentView.scrollToVisible(visibleRect)
        sequenceScrollView.reflectScrolledClipView(
            sequenceScrollView.contentView
        )
    }
}

private final class SequenceTokenView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")

    override var intrinsicContentSize: NSSize {
        let labelSize = titleLabel.fittingSize
        return NSSize(
            width: labelSize.width
                + Style.sequenceTokenInsets.left
                + Style.sequenceTokenInsets.right,
            height: max(
                labelSize.height
                    + Style.sequenceTokenInsets.top
                    + Style.sequenceTokenInsets.bottom,
                Style.minimumSequenceTokenHeight
            )
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(item: TargetPromptSequenceDisplayItem) {
        titleLabel.stringValue = item.text
        titleLabel.font = resolvedFont(for: item.state)
        titleLabel.textColor = resolvedForegroundColor(for: item.state)
        layer?.backgroundColor = resolvedBackgroundColor(for: item.state).cgColor
        layer?.borderWidth = item.state == .current
            ? Style.sequenceTokenBorderWidth
            : 0
        layer?.borderColor = resolvedBorderColor(for: item.state)?.cgColor
        invalidateIntrinsicContentSize()
    }

    private func configureView() {
        wantsLayer = true
        layer?.cornerRadius = Style.sequenceTokenCornerRadius
        layer?.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byClipping

        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.sequenceTokenInsets.left
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.sequenceTokenInsets.right
            ),
            titleLabel.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.sequenceTokenInsets.top
            ),
            titleLabel.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.sequenceTokenInsets.bottom
            )
        ])

        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
    }

    private func resolvedFont(
        for state: TargetPromptSequenceDisplayItem.State
    ) -> NSFont {
        switch state {
        case .answered, .pending:
            return .systemFont(
                ofSize: Style.sequenceNoteFontSize,
                weight: .semibold
            )
        case .current:
            return .systemFont(
                ofSize: Style.sequenceNoteFontSize,
                weight: .bold
            )
        }
    }

    private func resolvedBackgroundColor(
        for state: TargetPromptSequenceDisplayItem.State
    ) -> NSColor {
        switch state {
        case .answered:
            return .quaternaryLabelColor.withAlphaComponent(0.12)
        case .current:
            return .controlAccentColor.withAlphaComponent(0.18)
        case .pending:
            return .quaternaryLabelColor.withAlphaComponent(0.08)
        }
    }

    private func resolvedForegroundColor(
        for state: TargetPromptSequenceDisplayItem.State
    ) -> NSColor {
        switch state {
        case .answered:
            return .secondaryLabelColor
        case .current:
            return .controlAccentColor
        case .pending:
            return .labelColor
        }
    }

    private func resolvedBorderColor(
        for state: TargetPromptSequenceDisplayItem.State
    ) -> NSColor? {
        switch state {
        case .current:
            return .controlAccentColor.withAlphaComponent(0.45)
        case .answered, .pending:
            return nil
        }
    }
}

private enum Style {
    static let preferredHeight: CGFloat = StaffConfiguration().preferredHeight
    static let contentInsets = NSEdgeInsets(
        top: 20,
        left: 16,
        bottom: 20,
        right: 16
    )
    static let noteFontSize: CGFloat = 52
    static let sequenceNoteFontSize: CGFloat = 24
    static let cornerRadius: CGFloat = 22
    static let borderWidth: CGFloat = 1
    static let borderOpacity: CGFloat = 0.35
    static let sequenceItemSpacing: CGFloat = 10
    static let sequenceScrollPadding: CGFloat = 20
    static let sequenceTokenCornerRadius: CGFloat = 16
    static let sequenceTokenBorderWidth: CGFloat = 1
    static let minimumSequenceTokenHeight: CGFloat = 42
    static let sequenceTokenInsets = NSEdgeInsets(
        top: 8,
        left: 14,
        bottom: 8,
        right: 14
    )
    static let placeholderText = "--"
}
#endif

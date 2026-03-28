#if os(iOS)
import UIKit

final class iOSTargetNotePromptView: UIView {
    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: Style.preferredHeight
        )
    }

    private var currentContent: TargetPromptContent?
    private let singleContentStackView = UIStackView()
    private let noteLabel = UILabel()
    private let progressLabel = UILabel()
    private let sequenceScrollView = UIScrollView()
    private let sequenceContentView = UIView()
    private let sequenceStackView = UIStackView()
    private var sequenceItemViews: [SequenceTokenView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = Style.cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = Style.borderWidth
        layer.borderColor = UIColor.separator.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        accessibilityIdentifier = "target-note-prompt-view"
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        directionalLayoutMargins = Style.contentInsets
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.font = .systemFont(
            ofSize: Style.noteFontSize,
            weight: .bold
        )
        noteLabel.textColor = .label
        noteLabel.textAlignment = .center
        noteLabel.adjustsFontForContentSizeCategory = true
        noteLabel.adjustsFontSizeToFitWidth = true
        noteLabel.minimumScaleFactor = 0.4
        noteLabel.lineBreakMode = .byClipping
        noteLabel.isAccessibilityElement = false

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = .systemFont(
            ofSize: Style.coverageProgressFontSize,
            weight: .semibold
        )
        progressLabel.textColor = .secondaryLabel
        progressLabel.textAlignment = .center
        progressLabel.adjustsFontForContentSizeCategory = true
        progressLabel.lineBreakMode = .byClipping
        progressLabel.isAccessibilityElement = false

        singleContentStackView.axis = .vertical
        singleContentStackView.alignment = .fill
        singleContentStackView.distribution = .fill
        singleContentStackView.spacing = Style.singleContentSpacing
        singleContentStackView.translatesAutoresizingMaskIntoConstraints = false
        singleContentStackView.addArrangedSubview(noteLabel)
        singleContentStackView.addArrangedSubview(progressLabel)

        sequenceScrollView.translatesAutoresizingMaskIntoConstraints = false
        sequenceScrollView.alwaysBounceVertical = false
        sequenceScrollView.showsHorizontalScrollIndicator = false
        sequenceScrollView.showsVerticalScrollIndicator = false
        sequenceScrollView.isDirectionalLockEnabled = true
        sequenceScrollView.isAccessibilityElement = false

        sequenceContentView.translatesAutoresizingMaskIntoConstraints = false

        sequenceStackView.axis = .horizontal
        sequenceStackView.alignment = .center
        sequenceStackView.distribution = .fill
        sequenceStackView.spacing = Style.sequenceItemSpacing
        sequenceStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(singleContentStackView)
        addSubview(sequenceScrollView)
        sequenceScrollView.addSubview(sequenceContentView)
        sequenceContentView.addSubview(sequenceStackView)

        NSLayoutConstraint.activate([
            singleContentStackView.leadingAnchor.constraint(
                equalTo: layoutMarginsGuide.leadingAnchor
            ),
            singleContentStackView.trailingAnchor.constraint(
                equalTo: layoutMarginsGuide.trailingAnchor
            ),
            singleContentStackView.topAnchor.constraint(
                equalTo: layoutMarginsGuide.topAnchor
            ),
            singleContentStackView.bottomAnchor.constraint(
                equalTo: layoutMarginsGuide.bottomAnchor
            ),
            sequenceScrollView.leadingAnchor.constraint(
                equalTo: layoutMarginsGuide.leadingAnchor
            ),
            sequenceScrollView.trailingAnchor.constraint(
                equalTo: layoutMarginsGuide.trailingAnchor
            ),
            sequenceScrollView.topAnchor.constraint(
                equalTo: layoutMarginsGuide.topAnchor
            ),
            sequenceScrollView.bottomAnchor.constraint(
                equalTo: layoutMarginsGuide.bottomAnchor
            ),
            sequenceContentView.leadingAnchor.constraint(
                equalTo: sequenceScrollView.contentLayoutGuide.leadingAnchor
            ),
            sequenceContentView.trailingAnchor.constraint(
                equalTo: sequenceScrollView.contentLayoutGuide.trailingAnchor
            ),
            sequenceContentView.topAnchor.constraint(
                equalTo: sequenceScrollView.contentLayoutGuide.topAnchor
            ),
            sequenceContentView.bottomAnchor.constraint(
                equalTo: sequenceScrollView.contentLayoutGuide.bottomAnchor
            ),
            sequenceContentView.heightAnchor.constraint(
                equalTo: sequenceScrollView.frameLayoutGuide.heightAnchor
            ),
            sequenceStackView.leadingAnchor.constraint(
                equalTo: sequenceContentView.leadingAnchor
            ),
            sequenceStackView.trailingAnchor.constraint(
                equalTo: sequenceContentView.trailingAnchor
            ),
            sequenceStackView.topAnchor.constraint(
                equalTo: sequenceContentView.topAnchor
            ),
            sequenceStackView.bottomAnchor.constraint(
                equalTo: sequenceContentView.bottomAnchor
            )
        ])

        applyContent()
    }

    private func applyContent() {
        guard let currentContent else {
            applyPlaceholder()
            return
        }

        accessibilityLabel = currentContent.accessibilityLabel

        switch currentContent {
        case let .single(text):
            applySingleContent(
                noteText: text,
                progressText: nil
            )
        case let .singleCoverage(text, _, _):
            applySingleContent(
                noteText: text,
                progressText: currentContent.singleCoverageProgressText
            )
        case let .sequence(_, currentIndex):
            singleContentStackView.isHidden = true
            sequenceScrollView.isHidden = false
            rebuildSequenceItems(
                from: currentContent.sequenceDisplayItems
            )
            scrollSequenceItemIntoView(currentIndex: currentIndex)
        }
    }

    private func applyPlaceholder() {
        applySingleContent(
            noteText: Style.placeholderText,
            progressText: nil
        )
        sequenceScrollView.isHidden = true
        accessibilityLabel = "Current target note unavailable"
        rebuildSequenceItems(from: [])
    }

    private func applySingleContent(
        noteText: String,
        progressText: String?
    ) {
        noteLabel.text = noteText
        progressLabel.text = progressText
        progressLabel.isHidden = progressText == nil
        singleContentStackView.isHidden = false
        sequenceScrollView.isHidden = true
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

    private func scrollSequenceItemIntoView(currentIndex: Int) {
        guard !sequenceItemViews.isEmpty else {
            return
        }

        let targetIndex = min(
            max(currentIndex, 0),
            sequenceItemViews.count - 1
        )

        setNeedsLayout()
        layoutIfNeeded()

        let targetView = sequenceItemViews[targetIndex]
        let targetRect = targetView.convert(
            targetView.bounds,
            to: sequenceScrollView
        ).insetBy(dx: -Style.sequenceScrollPadding, dy: 0)
        sequenceScrollView.scrollRectToVisible(
            targetRect,
            animated: false
        )
    }
}

private final class SequenceTokenView: UIView {
    private let titleLabel = UILabel()

    override var intrinsicContentSize: CGSize {
        let labelSize = titleLabel.intrinsicContentSize
        return CGSize(
            width: labelSize.width
                + Style.sequenceTokenInsets.leading
                + Style.sequenceTokenInsets.trailing,
            height: max(
                labelSize.height
                    + Style.sequenceTokenInsets.top
                    + Style.sequenceTokenInsets.bottom,
                Style.minimumSequenceTokenHeight
            )
        )
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func apply(item: TargetPromptSequenceDisplayItem) {
        titleLabel.text = item.text
        titleLabel.font = resolvedFont(for: item.state)
        titleLabel.textColor = resolvedForegroundColor(for: item.state)
        backgroundColor = resolvedBackgroundColor(for: item.state)
        layer.borderWidth = item.state == .current
            ? Style.sequenceTokenBorderWidth
            : 0
        layer.borderColor = resolvedBorderColor(for: item.state)?.cgColor
        invalidateIntrinsicContentSize()
    }

    private func configureView() {
        directionalLayoutMargins = Style.sequenceTokenInsets
        layer.cornerRadius = Style.sequenceTokenCornerRadius
        layer.cornerCurve = .continuous

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.lineBreakMode = .byClipping
        titleLabel.isAccessibilityElement = false

        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: layoutMarginsGuide.leadingAnchor
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: layoutMarginsGuide.trailingAnchor
            ),
            titleLabel.topAnchor.constraint(
                equalTo: layoutMarginsGuide.topAnchor
            ),
            titleLabel.bottomAnchor.constraint(
                equalTo: layoutMarginsGuide.bottomAnchor
            )
        ])

        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
    }

    private func resolvedFont(
        for state: TargetPromptSequenceDisplayItem.State
    ) -> UIFont {
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
    ) -> UIColor {
        switch state {
        case .answered:
            return .tertiarySystemFill
        case .current:
            return tintColor.withAlphaComponent(0.18)
        case .pending:
            return .secondarySystemFill
        }
    }

    private func resolvedForegroundColor(
        for state: TargetPromptSequenceDisplayItem.State
    ) -> UIColor {
        switch state {
        case .answered:
            return .secondaryLabel
        case .current:
            return tintColor
        case .pending:
            return .label
        }
    }

    private func resolvedBorderColor(
        for state: TargetPromptSequenceDisplayItem.State
    ) -> UIColor? {
        switch state {
        case .current:
            return tintColor.withAlphaComponent(0.45)
        case .answered, .pending:
            return nil
        }
    }
}

private enum Style {
    static let preferredHeight: CGFloat = StaffConfiguration().preferredHeight
    static let contentInsets = NSDirectionalEdgeInsets(
        top: 20,
        leading: 16,
        bottom: 20,
        trailing: 16
    )
    static let noteFontSize: CGFloat = 52
    static let coverageProgressFontSize: CGFloat = 18
    static let singleContentSpacing: CGFloat = 6
    static let sequenceNoteFontSize: CGFloat = 26
    static let cornerRadius: CGFloat = 22
    static let borderWidth: CGFloat = 1
    static let borderOpacity: CGFloat = 0.35
    static let sequenceItemSpacing: CGFloat = 10
    static let sequenceScrollPadding: CGFloat = 20
    static let sequenceTokenCornerRadius: CGFloat = 16
    static let sequenceTokenBorderWidth: CGFloat = 1
    static let minimumSequenceTokenHeight: CGFloat = 48
    static let sequenceTokenInsets = NSDirectionalEdgeInsets(
        top: 10,
        leading: 14,
        bottom: 10,
        trailing: 14
    )
    static let placeholderText = "--"
}
#endif

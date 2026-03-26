#if os(iOS)
import UIKit

final class iOSTargetNotePromptView: UIView {
    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: Style.preferredHeight
        )
    }

    private var currentPrompt: FretboardNaturalNoteTrainerState.Prompt?
    private let noteLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    convenience init(prompt: FretboardNaturalNoteTrainerState.Prompt) {
        self.init(frame: .zero)
        apply(prompt: prompt)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    // 组件只负责显示当前 prompt，不持有 trainer 状态机。
    func apply(prompt: FretboardNaturalNoteTrainerState.Prompt) {
        guard currentPrompt != prompt else {
            return
        }

        currentPrompt = prompt
        applyPrompt()
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

        addSubview(noteLabel)

        NSLayoutConstraint.activate([
            noteLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.horizontalInset
            ),
            noteLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.horizontalInset
            ),
            noteLabel.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.verticalInset
            ),
            noteLabel.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.verticalInset
            )
        ])

        applyPrompt()
    }

    private func applyPrompt() {
        let text = currentPrompt?.displayText ?? Style.placeholderText
        noteLabel.text = text
        accessibilityLabel = currentPrompt.map {
            "Current target note \($0.displayText)"
        } ?? "Current target note unavailable"
    }
}

private enum Style {
    static let preferredHeight: CGFloat = StaffConfiguration().preferredHeight
    static let horizontalInset: CGFloat = 16
    static let verticalInset: CGFloat = 20
    static let noteFontSize: CGFloat = 52
    static let cornerRadius: CGFloat = 22
    static let borderWidth: CGFloat = 1
    static let borderOpacity: CGFloat = 0.35
    static let placeholderText = "--"
}
#endif

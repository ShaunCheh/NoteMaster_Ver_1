#if os(macOS)
import AppKit

final class macOSTargetNotePromptView: NSView {
    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.preferredHeight
        )
    }

    private var currentPrompt: FretboardNaturalNoteTrainerState.Prompt?
    private let noteLabel = NSTextField(labelWithString: Style.placeholderText)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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
        noteLabel.stringValue = text
        noteLabel.toolTip = currentPrompt.map {
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

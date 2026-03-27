# 20260327_123801_phase2_target_prompt_content_and_sequence_views

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_123801`
- 记录范围：统一序列真相源阶段 2，新增 shared prompt 内容模型并升级双平台目标音组件的序列显示能力
- 本次目标：把 prompt 的展示语义从“单个 `Prompt.displayText`”提升为 shared `TargetPromptContent`，并让 iOS / macOS 目标音组件都能支持序列 token 显示与 `currentIndex` 高亮
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift`

## 根因结论

- 当前双平台 `TargetNotePromptView` 都只接受 `FretboardNaturalNoteTrainerState.Prompt`，内部就是一个单独的大字号 label。它们只能表达“当前单个目标音”，不能表达“一个序列 + 当前答题位置”。
- 如果直接在 controller 里临时把序列拼成字符串，再塞给平台 view，就会让 prompt 序列的业务语义重新散落到 controller 或平台层，不符合这轮“统一序列真相源”的目标。
- 阶段 2 的根因修复方向因此不是先改 controller，而是先在 shared 层定义 `TargetPromptContent`，再让平台 view 只消费这个共享内容模型。这样阶段 4 接 controller 时，平台层不需要再猜业务状态。

## 修改 1：新增 shared `TargetPromptContent`，把 single / sequence 展示语义收口到共享层

### 修改前

- 项目内没有独立的 prompt 内容模型文件。
- 单目标 prompt、序列 token、高亮下标、无障碍文案都没有 shared 承载位。
- `GeneratedNoteSequence`、`QuarterNoteSequencePrompt`、`QuarterNoteSequenceSession` 虽然已经有了 shared 数据，但还没有一个统一的“给 prompt view 吃”的投影模型。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift
// 函数/成员: N/A（修改前无此文件）
// 功能说明: 修改前没有独立的 shared prompt 内容模型；
// prompt 组件只能直接依赖 trainer 的单目标 Prompt，无法表达 sequence tokens 和 currentIndex。
// 修改前无此文件。
```

### 修改后

- 新增 `TargetPromptContent.single(text:)` 和 `TargetPromptContent.sequence(tokens:currentIndex:)`
- 新增 `TargetPromptSequenceDisplayItem`，把序列中的每个 token 标成：
  - `answered`
  - `current`
  - `pending`
- 在 shared 层补齐投影入口：
  - `GeneratedNoteSequence.targetPromptContent(...)`
  - `FretboardNaturalNoteTrainerState.Prompt.targetPromptContent`
  - `FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt.targetPromptContent(...)`
  - `FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession.targetPromptContent(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift
// 函数/成员: TargetPromptContent.accessibilityLabel, sequenceDisplayItems,
// GeneratedNoteSequence.targetPromptContent(currentIndex:spelling:),
// FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession.targetPromptContent(spelling:)
// 功能说明: 新增 shared prompt 内容模型，把 single / sequence 的展示语义、
// sequence item 状态划分，以及 generatedSequence / prompt / session 到 prompt 内容的投影统一收口。
struct TargetPromptSequenceDisplayItem: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case answered
        case current
        case pending
    }

    var text: String
    var state: State
}

enum TargetPromptContent: Equatable, Sendable {
    case single(text: String)
    case sequence(tokens: [String], currentIndex: Int)

    var accessibilityLabel: String {
        switch self {
        case let .single(text):
            return "Current target note \(text)"
        case let .sequence(tokens, currentIndex):
            Self.validateSequence(tokens: tokens, currentIndex: currentIndex)
            if currentIndex < tokens.count {
                return "Target note sequence, current step \(currentIndex + 1) of \(tokens.count), target \(tokens[currentIndex])"
            } else {
                return "Target note sequence completed, \(tokens.count) notes total"
            }
        }
    }

    var sequenceDisplayItems: [TargetPromptSequenceDisplayItem] {
        switch self {
        case .single:
            return []
        case let .sequence(tokens, currentIndex):
            Self.validateSequence(tokens: tokens, currentIndex: currentIndex)
            return tokens.enumerated().map { index, token in
                let state: TargetPromptSequenceDisplayItem.State
                if index < currentIndex {
                    state = .answered
                } else if index == currentIndex && currentIndex < tokens.count {
                    state = .current
                } else {
                    state = .pending
                }
                return TargetPromptSequenceDisplayItem(
                    text: token,
                    state: state
                )
            }
        }
    }
}

extension GeneratedNoteSequence {
    func targetPromptContent(
        currentIndex: Int = 0,
        spelling: PitchSpelling = .sharp
    ) -> TargetPromptContent {
        .sequence(
            tokens: displayTexts(using: spelling),
            currentIndex: currentIndex
        )
    }
}

extension FretboardNaturalNoteTrainerState.Prompt {
    var targetPromptContent: TargetPromptContent {
        .single(text: displayText)
    }
}

extension FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession {
    func targetPromptContent(
        spelling: PitchSpelling = .sharp
    ) -> TargetPromptContent {
        prompt.targetPromptContent(
            currentIndex: currentIndex,
            spelling: spelling
        )
    }
}
```

## 修改 2：iOS 目标音组件从“单 label”升级为“single / sequence 双模式”

### 修改前

- `iOSTargetNotePromptView` 只有 `currentPrompt` 和一个 `UILabel`
- `apply(prompt:)` 只接收 `FretboardNaturalNoteTrainerState.Prompt`
- `applyPrompt()` 只会把 `displayText` 填进单个大字号 label
- 组件内部没有任何序列 token、高亮状态、滚动定位能力

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift
// 函数/成员: apply(prompt:), configureView(), applyPrompt()
// 功能说明: 修改前 iOS prompt view 只能显示单个目标音文本；
// 组件内部只有一个 label，没有共享 content 模型，也没有序列展示或当前项高亮能力。
final class iOSTargetNotePromptView: UIView {
    private var currentPrompt: FretboardNaturalNoteTrainerState.Prompt?
    private let noteLabel = UILabel()

    // 组件只负责显示当前 prompt，不持有 trainer 状态机。
    func apply(prompt: FretboardNaturalNoteTrainerState.Prompt) {
        guard currentPrompt != prompt else {
            return
        }

        currentPrompt = prompt
        applyPrompt()
    }

    private func configureView() {
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.font = .systemFont(
            ofSize: Style.noteFontSize,
            weight: .bold
        )
        noteLabel.textAlignment = .center

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
```

### 修改后

- 新增 `currentContent: TargetPromptContent?`
- 新增 `apply(content:)`
- 保留 `apply(prompt:)` 作为兼容适配层，把旧单目标 prompt 投影到 `.single(text:)`
- 新增 `UIScrollView + UIStackView + SequenceTokenView`
- `applyContent()` 根据内容类型自动切换：
  - `single`：继续显示原来的大字号 label
  - `sequence`：显示横向 token 列表，并滚动到当前高亮项

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift
// 函数/成员: apply(content:), apply(prompt:), applyContent(),
// rebuildSequenceItems(from:), scrollSequenceItemIntoView(currentIndex:)
// 功能说明: 修改后 iOS prompt view 只消费 shared TargetPromptContent；
// 单音仍走原有大字模式，序列则走横向 token 列表，并根据 currentIndex 高亮当前题。
final class iOSTargetNotePromptView: UIView {
    private var currentContent: TargetPromptContent?
    private let noteLabel = UILabel()
    private let sequenceScrollView = UIScrollView()
    private let sequenceContentView = UIView()
    private let sequenceStackView = UIStackView()
    private var sequenceItemViews: [SequenceTokenView] = []

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

    private func applyContent() {
        guard let currentContent else {
            applyPlaceholder()
            return
        }

        accessibilityLabel = currentContent.accessibilityLabel

        switch currentContent {
        case let .single(text):
            noteLabel.text = text
            noteLabel.isHidden = false
            sequenceScrollView.isHidden = true
        case let .sequence(_, currentIndex):
            noteLabel.isHidden = true
            sequenceScrollView.isHidden = false
            rebuildSequenceItems(
                from: currentContent.sequenceDisplayItems
            )
            scrollSequenceItemIntoView(currentIndex: currentIndex)
        }
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift
// 函数/成员: SequenceTokenView.apply(item:), resolvedBackgroundColor(for:), resolvedForegroundColor(for:)
// 功能说明: 序列 token 被拆成独立 view，根据 answered / current / pending 三种状态分别应用字体、前景色、背景色与边框。
private final class SequenceTokenView: UIView {
    private let titleLabel = UILabel()

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
}
```

## 修改 3：macOS 目标音组件同步升级为共享 content + 序列 token 显示

### 修改前

- `macOSTargetNotePromptView` 与 iOS 同构，只有 `currentPrompt` 和单个 `NSTextField`
- 只能吃 `FretboardNaturalNoteTrainerState.Prompt`
- 只能显示单个目标音文本，没有序列滚动和高亮语义

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数/成员: apply(prompt:), configureView(), applyPrompt()
// 功能说明: 修改前 macOS prompt view 仅能显示单目标音；
// 平台 view 内没有 sequence token 容器，也没有 currentIndex 对应的高亮与滚动能力。
final class macOSTargetNotePromptView: NSView {
    private var currentPrompt: FretboardNaturalNoteTrainerState.Prompt?
    private let noteLabel = NSTextField(labelWithString: Style.placeholderText)

    // 组件只负责显示当前 prompt，不持有 trainer 状态机。
    func apply(prompt: FretboardNaturalNoteTrainerState.Prompt) {
        guard currentPrompt != prompt else {
            return
        }

        currentPrompt = prompt
        applyPrompt()
    }

    private func configureView() {
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.font = .systemFont(
            ofSize: Style.noteFontSize,
            weight: .bold
        )
        noteLabel.alignment = .center

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
```

### 修改后

- 新增 `currentContent: TargetPromptContent?`
- 新增 `apply(content:)`，旧 `apply(prompt:)` 退化为兼容适配层
- 新增 `NSScrollView + NSStackView + SequenceTokenView`
- `layoutSequenceDocumentView()` 负责手动同步 documentView 与 stackView 尺寸
- `scrollSequenceItemIntoView(currentIndex:)` 负责把当前高亮 token 滚动到可见区域

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数/成员: apply(content:), apply(prompt:), applyContent(),
// layoutSequenceDocumentView(), scrollSequenceItemIntoView(currentIndex:)
// 功能说明: 修改后 macOS prompt view 与 iOS 保持同构，
// 统一消费 shared TargetPromptContent，并在 sequence 模式下切到横向可滚动 token 列表。
final class macOSTargetNotePromptView: NSView {
    private var currentContent: TargetPromptContent?
    private let noteLabel = NSTextField(labelWithString: Style.placeholderText)
    private let sequenceScrollView = NSScrollView()
    private let sequenceDocumentView = NSView()
    private let sequenceStackView = NSStackView()
    private var sequenceItemViews: [SequenceTokenView] = []

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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数/成员: SequenceTokenView.apply(item:), resolvedBackgroundColor(for:), resolvedForegroundColor(for:)
// 功能说明: macOS 版序列 token 也按 answered / current / pending 三种状态套用不同的视觉样式，
// 保持与 iOS 版的展示语义一致。
private final class SequenceTokenView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")

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
}
```

## 阶段 2 完成后的状态

1. shared 层已经有了统一的 prompt 内容模型：`TargetPromptContent`
2. 双平台 `TargetNotePromptView` 都已经具备 sequence 模式的显示能力
3. 旧的 `apply(prompt:)` 还在，因此当前单目标链路没有被打断
4. 阶段 4 接 controller 统一投影时，可以直接把 shared `TargetPromptContent` 喂给平台组件，不需要再在平台 view 或 controller 临时拼字符串

## 边界说明

- 这一阶段没有修改 controller 的 prompt/staff 投影切换逻辑
- 也没有把 quarter-note sequence 实际接到顶部 prompt 组件上
- 当前改动只完成了：
  - shared prompt 内容模型
  - 双平台目标音组件的 sequence 展示能力

## 验证情况

- 已对以下文件执行诊断检查，结果为 `No linter errors found`
- `NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift`
- 已检查阶段 2 的新接口落点，当前可见调用仍保持兼容：
  - `apply(prompt:)` 仍存在
  - `apply(content:)` 已新增，供后续 controller 阶段接入
- 未执行 `xcodebuild`：当前环境仍受 Xcode command line tools 配置限制，和前几轮一致。

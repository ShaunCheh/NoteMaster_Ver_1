# 20260326_213644_phase3_target_note_prompt_views

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_213644`
- 记录范围：顶部内容切换方案的阶段 3，双平台目标音组件
- 本次目标：新增 iOS `UIView` 与 macOS `NSView` 目标音组件，直接消费现有 `FretboardNaturalNoteTrainerState.Prompt`
- 根因结论：修改前项目里只有 trainer 的控制台输出，还没有一个真正可插拔的顶部内容组件来显示当前目标音。后续即使把顶部区域切换到 `targetPrompt` 模式，也没有可复用的 UI 壳层可以直接挂入页面结构
- 本次实际改动：
- 新增 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift`
- 新增 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift`

## 本次完成的修改

1. 新增 iOS `iOSTargetNotePromptView`，内部使用居中的 `UILabel` 显示 trainer prompt。
2. 新增 macOS `macOSTargetNotePromptView`，内部使用居中的 `NSTextField` 显示 trainer prompt。
3. 双平台组件都提供统一的 `apply(prompt:)` 入口，只负责显示，不持有 trainer 状态机。
4. 双平台组件都提供稳定的 `intrinsicContentSize` 高度，并沿用 `StaffConfiguration().preferredHeight`，为后续顶部 host 接入提前对齐高度语义。

## 修改 1：新增 iOS 目标音组件

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift
// 函数/成员: 整个文件
// 功能说明: 修改前该文件不存在；
// iOS 端还没有一个专门显示当前目标音名的 UIView 组件。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift
// 函数/成员: iOSTargetNotePromptView, apply(prompt:), configureView(), applyPrompt()
// 功能说明: 修改后新增一个薄 UIView 组件；
// 它直接消费 trainer prompt，只负责把目标音名显示出来，为后续顶部 host 切换提供可插拔内容视图。
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
```

## 修改 2：新增 macOS 目标音组件

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数/成员: 整个文件
// 功能说明: 修改前该文件不存在；
// macOS 端也没有对称的 NSView 组件来承接当前目标音显示。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数/成员: macOSTargetNotePromptView, apply(prompt:), configureView(), applyPrompt()
// 功能说明: 修改后新增一个对称 NSView 组件；
// 它与 iOS 端保持同样的输入边界，后续控制器只需要按平台挂入 host 即可。
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
```

## 这次修改解决了什么

- 解决了“trainer 已经有 prompt，但页面没有可复用目标音组件”的结构空洞。
- 把目标音显示从控制台字符串推进为真正的双平台 UI 组件，为后续顶部内容切换提供可挂载实体。
- 明确了组件职责边界：`Prompt` 仍由 trainer 提供，view 只做显示壳层，不引入新的业务状态。
- 提前对齐了顶部内容区域的高度语义，降低后续 `topContentHostView` 重构时的布局成本。

## 本次明确未修改的边界

- 未修改 `iOSViewController.swift`
- 未修改 `macOSViewController.swift`
- 未引入 `topContentHostView`
- 未把新组件接入顶部布局
- 未修改 `applyFretboardTrainerPrompt(reason:)`
- 未实现 settings 切换后的真实页面视觉切换；当前仍然只是在代码库里新增可复用组件

## 验证结果

### 静态检查

- `ReadLints` 检查以下 2 个文件，结果为无错误：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 使用 macOS SDK 对项目内 Swift 文件做 typecheck，确认新增双平台目标音组件后编译链保持通过。
xcrun swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk NoteMaster_Ver_1/**/*.swift
```

- 结果：通过
- 结论：阶段 3 已完成双平台目标音组件落地，并保持当前工程静态检查与类型检查通过

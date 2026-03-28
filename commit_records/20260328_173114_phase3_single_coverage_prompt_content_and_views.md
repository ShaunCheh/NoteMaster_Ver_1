# 20260328_173114_phase3_single_coverage_prompt_content_and_views

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_173114`
- 记录范围：实施 `single覆盖反馈` 计划的阶段 3，只扩展 prompt 内容模型与双端目标提示视图，不涉及控制器接线、红绿 overlay、指板反馈绘制
- 本次目标：让 shared 层能够表达 single coverage 进度，并让 iOS/macOS 的 target prompt 组件可以把该进度渲染出来
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift`

## 根因结论

- 阶段 2 已经引入了 `SingleCoverageSession`，但 shared prompt 内容模型仍然只有 `.single(text)` 和 `.sequence(tokens,currentIndex)` 两种表达。
- 这意味着即使 shared 已经知道 single 的覆盖进度，双端 prompt 组件也没有正式的数据结构来显示 `3/7` 这类信息。
- 如果继续把进度硬拼进 `single(text)`，后续 accessibility、平台 view 分支和内容语义都会变得模糊。
- 因此阶段 3 的根因级修复是在 shared 层为 single coverage 建立正式的 prompt 内容 case，并让 iOS/macOS 视图都改为“主音名 + 可选进度副标题”的结构。

## 修改 1：在 `TargetPromptContent.swift` 中为 single coverage 新增结构化内容模型

### 修改前

- `TargetPromptContent` 只有 `.single(text)` 和 `.sequence(tokens,currentIndex)`
- `accessibilityLabel` 只能表达普通单音目标或序列目标
- shared 层还没有 `SingleCoverageSession -> TargetPromptContent` 的映射入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift
// 函数名: TargetPromptContent, TargetPromptContent.accessibilityLabel, FretboardNaturalNoteTrainerState.Prompt.targetPromptContent
// 功能说明: 修改前 prompt 内容模型只有普通 single 和 sequence；
// single coverage 的 visited/total 进度既没有独立 case，也没有 shared 映射出口。
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
}

extension FretboardNaturalNoteTrainerState.Prompt {
    var targetPromptContent: TargetPromptContent {
        .single(text: displayText)
    }
}
```

### 修改后

- 新增 `.singleCoverage(text:visitedCount:totalCount:)`
- 新增 `singleCoverageProgressText`
- 新增 `validateSingleCoverage(...)`
- 新增 `FretboardNaturalNoteTrainerState.SingleCoverageSession.targetPromptContent(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift
// 函数名: TargetPromptContent.singleCoverage, TargetPromptContent.accessibilityLabel, TargetPromptContent.singleCoverageProgressText, SingleCoverageSession.targetPromptContent(...)
// 功能说明: 修改后 shared prompt 内容模型可以正式表达 single coverage 进度，
// 并同时提供 accessibility 文案、进度文本和 SingleCoverageSession 到内容模型的统一映射。
enum TargetPromptContent: Equatable, Sendable {
    case single(text: String)
    case singleCoverage(text: String, visitedCount: Int, totalCount: Int)
    case sequence(tokens: [String], currentIndex: Int)

    var accessibilityLabel: String {
        switch self {
        case let .single(text):
            return "Current target note \(text)"
        case let .singleCoverage(text, visitedCount, totalCount):
            Self.validateSingleCoverage(
                visitedCount: visitedCount,
                totalCount: totalCount
            )
            guard totalCount > 0 else {
                return "Current target note \(text), no target positions available in current range"
            }
            if visitedCount < totalCount {
                return "Current target note \(text), \(visitedCount) of \(totalCount) positions completed"
            } else {
                return "Current target note \(text), coverage completed, \(totalCount) positions total"
            }
        case let .sequence(tokens, currentIndex):
            // ... 保持原 sequence 语义不变 ...
            return "..."
        }
    }

    var singleCoverageProgressText: String? {
        guard case let .singleCoverage(_, visitedCount, totalCount) = self else {
            return nil
        }
        Self.validateSingleCoverage(
            visitedCount: visitedCount,
            totalCount: totalCount
        )
        return "\(visitedCount)/\(totalCount)"
    }
}

extension FretboardNaturalNoteTrainerState.SingleCoverageSession {
    func targetPromptContent(
        spelling: PitchSpelling = .sharp
    ) -> TargetPromptContent {
        .singleCoverage(
            text: targetPitchClass.displayText(using: spelling),
            visitedCount: visitedCount,
            totalCount: totalCount
        )
    }
}
```

## 修改 2：在 `iOSTargetNotePromptView.swift` 中把 single 展示升级为“主音名 + 进度副标题”

### 修改前

- iOS prompt 视图只有一个 `noteLabel`
- single 分支只会把 `noteLabel.text = text`
- 组件还没有用于显示 `3/7` 的独立 UI 元素

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift
// 函数名: iOSTargetNotePromptView.applyContent()
// 功能说明: 修改前 iOS prompt 组件在 single 分支只显示一个大字标签；
// 没有 coverage 进度副标题，也没有 singleCoverage 分支。
private var currentContent: TargetPromptContent?
private let noteLabel = UILabel()
private let sequenceScrollView = UIScrollView()

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
```

### 修改后

- 新增 `singleContentStackView`
- 新增 `progressLabel`
- 新增 `applySingleContent(noteText:progressText:)`
- `singleCoverage` 分支通过 `currentContent.singleCoverageProgressText` 显示进度

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSTargetNotePromptView.swift
// 函数名: configureView(), applyContent(), applySingleContent(noteText:progressText:)
// 功能说明: 修改后 iOS prompt 组件把 single UI 改成纵向 stack；
// 上方显示目标音名，下方按需显示 coverage 进度，sequence 分支保持原有 token UI。
private var currentContent: TargetPromptContent?
private let singleContentStackView = UIStackView()
private let noteLabel = UILabel()
private let progressLabel = UILabel()
private let sequenceScrollView = UIScrollView()

private func configureView() {
    progressLabel.font = .systemFont(
        ofSize: Style.coverageProgressFontSize,
        weight: .semibold
    )
    progressLabel.textColor = .secondaryLabel
    progressLabel.textAlignment = .center

    singleContentStackView.axis = .vertical
    singleContentStackView.alignment = .fill
    singleContentStackView.distribution = .fill
    singleContentStackView.spacing = Style.singleContentSpacing
    singleContentStackView.addArrangedSubview(noteLabel)
    singleContentStackView.addArrangedSubview(progressLabel)
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
```

## 修改 3：在 `macOSTargetNotePromptView.swift` 中同步 single coverage 进度显示

### 修改前

- macOS prompt 视图同样只有一个 `noteLabel`
- single 分支只能显示普通单音文本
- `toolTip` 只绑定到现有内容，没有 single coverage 的结构化分支

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数名: macOSTargetNotePromptView.applyContent()
// 功能说明: 修改前 macOS prompt 组件与 iOS 对称；
// single 分支只渲染 noteLabel，尚未支持 coverage 进度。
private var currentContent: TargetPromptContent?
private let noteLabel = NSTextField(labelWithString: Style.placeholderText)
private let sequenceScrollView = NSScrollView()

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
        scrollSequenceItemIntoView(currentIndex: currentIndex)
    }
}
```

### 修改后

- 新增 `singleContentStackView`
- 新增 `progressLabel`
- 新增 `applySingleContent(noteText:progressText:)`
- `singleCoverage` 分支与 iOS 对齐，显示可选副标题进度

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数名: configureView(), applyContent(), applySingleContent(noteText:progressText:)
// 功能说明: 修改后 macOS prompt 组件与 iOS 保持对称；
// single coverage 会显示目标音名和进度副标题，sequence 仍沿用原有滚动 token 视图。
private var currentContent: TargetPromptContent?
private let singleContentStackView = NSStackView()
private let noteLabel = NSTextField(labelWithString: Style.placeholderText)
private let progressLabel = NSTextField(labelWithString: "")
private let sequenceScrollView = NSScrollView()

private func configureView() {
    progressLabel.font = .systemFont(
        ofSize: Style.coverageProgressFontSize,
        weight: .semibold
    )
    progressLabel.textColor = .secondaryLabelColor
    progressLabel.alignment = .center

    singleContentStackView.orientation = .vertical
    singleContentStackView.alignment = .centerX
    singleContentStackView.distribution = .fill
    singleContentStackView.spacing = Style.singleContentSpacing
    singleContentStackView.addArrangedSubview(noteLabel)
    singleContentStackView.addArrangedSubview(progressLabel)
}

private func applyContent() {
    guard let currentContent else {
        applyPlaceholder()
        return
    }

    toolTip = currentContent.accessibilityLabel

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

private func applySingleContent(
    noteText: String,
    progressText: String?
) {
    noteLabel.stringValue = noteText
    noteLabel.toolTip = nil
    progressLabel.stringValue = progressText ?? ""
    progressLabel.isHidden = progressText == nil
    singleContentStackView.isHidden = false
    sequenceScrollView.isHidden = true
}
```

## 影响范围与未改内容

- 本次只扩展了 prompt 内容模型和 prompt 视图本身，没有接控制器。
- `iOSViewController.swift` / `macOSViewController.swift` 还没有开始把 `SingleCoverageSession.targetPromptContent()` 接到实际 single mode 链路里。
- `FretboardLayer` 和红/绿 feedback overlay 仍未开始实施。
- sequence prompt 的 token UI 保持原有行为，没有改变已有序列练习展示。

## 验证情况

- 已执行 `ReadLints` 检查，`TargetPromptContent.swift`、`iOSTargetNotePromptView.swift`、`macOSTargetNotePromptView.swift` 没有新增 linter 问题。
- 已通过 `git diff` 核对本次实际改动，只涉及上述三个文件。
- 本次没有执行工程级编译或运行时验证；当前验证以 shared/view 代码回读与 lints 为主。

## 阶段结论

- 阶段 3 已完成：shared 已经能够表达 single coverage prompt，双端目标提示视图也已经具备显示进度副标题的能力。
- 后续阶段 5 接上控制器后，single mode 才会真正把 `3/7` 这类进度显示到界面上。

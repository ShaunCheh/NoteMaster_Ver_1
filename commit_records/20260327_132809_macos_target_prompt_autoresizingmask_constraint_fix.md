# 20260327_132809_macos_target_prompt_autoresizingmask_constraint_fix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_132809`
- 记录范围：修复 `macOSTargetNotePromptView` 的 sequence token 约束冲突
- 本次目标：消除 `layoutSubtreeIfNeeded()` 时 `NSStackView.height == 0` 与 token 内部上下约束的冲突
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift`

## 根因结论

- `macOSTargetNotePromptView` 中的 `sequenceStackView` 采用的是手动 `frame` 布局：实际位置和尺寸由 `layoutSequenceDocumentView()` 计算并赋值。
- 但修改前没有关闭 `sequenceStackView` 的 autoresizing mask 转 Auto Layout，导致 AppKit 在初始布局帧里为它自动生成了 `NSAutoresizingMaskLayoutConstraint`，其中包含 `height == 0`。
- 与此同时，`SequenceTokenView` 内部的 `titleLabel` 被上下边距约束固定住，要求 token view 具有非零高度；因此在 `layoutSubtreeIfNeeded()` 时，隐式的 `height == 0` 与内部上下约束发生冲突。
- 这次修复不去削弱 token 内部约束，而是直接去掉错误约束来源，保证手动 frame 布局和 Auto Layout 不再混用。

## 修改 1：关闭 `sequenceStackView` 的 autoresizing mask 转 Auto Layout

### 修改前

- `sequenceStackView` 只配置了方向、对齐、分布和间距
- 但没有显式关闭 `translatesAutoresizingMaskIntoConstraints`
- 在当前手动 frame 布局模式下，这会让 `NSStackView` 生成不该参与求解的隐式约束

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数/成员: configureView()
// 功能说明: 修改前 sequenceStackView 走手动 frame 布局，
// 但仍保留 autoresizing mask 转 Auto Layout，可能生成隐式 0 高度约束。
private func configureView() {
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
}
```

### 修改后

- 显式设置 `sequenceStackView.translatesAutoresizingMaskIntoConstraints = false`
- 保证 `sequenceStackView` 不再把 autoresizing mask 转成约束参与求解
- 这样 `layoutSequenceDocumentView()` 的手动 frame 布局就不会再与 Auto Layout 隐式约束打架

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift
// 函数/成员: configureView()
// 功能说明: 修改后显式关闭 sequenceStackView 的 autoresizing mask 转约束，
// 让它完全受 layoutSequenceDocumentView() 的手动 frame 布局控制。
private func configureView() {
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
    // sequenceStackView 走手动 frame 布局，不能再保留 autoresizing mask
    // 转 Auto Layout；否则初始 0 高度会生成冲突约束。
    sequenceStackView.translatesAutoresizingMaskIntoConstraints = false
    sequenceDocumentView.addSubview(sequenceStackView)
}
```

## 验证结果

- `ReadLints` 检查结果：
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSTargetNotePromptView.swift`
- 以上文件为 `No linter errors found`
- 本次记录文件已放入：`commit_records/20260327_132809_macos_target_prompt_autoresizingmask_constraint_fix.md`
- 本次没有执行 `xcodebuild`；这里只记录本次实际做过的静态诊断结果

## 本次修复结果

- 已移除导致 `NSStackView.height == 0` 参与求解的隐式约束来源
- `SequenceTokenView` 的内部上下边距约束保持不变，不需要为了规避冲突去降低正确约束的优先级
- `macOSTargetNotePromptView` 的 sequence 区域现在统一由手动 frame 布局驱动，不再混入 autoresizing mask 转出的伪约束

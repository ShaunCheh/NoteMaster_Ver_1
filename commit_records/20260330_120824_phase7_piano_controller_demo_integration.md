# 20260330_120824_phase7_piano_controller_demo_integration

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260330_120824`
- 记录范围：实施“钢琴键盘组件”计划的阶段 7，只做双平台控制器级最小 demo 接入，用来验证 `rowsChanged` 与 `preview` 生命周期的真实页面闭环
- 本次目标：不侵入现有 `trainer/pageDisplayState` 逻辑，只在 `iOSViewController` 与 `macOSViewController` 中追加一个独立的 piano demo 区块
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/*`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1.xcodeproj/project.pbxproj`

## 本次结论

- 修改前，双平台已经具备完整的钢琴 Shared 内核和平台壳层
- 但还没有真正放进控制器页面里观察：
- 默认 `rows` 的视觉结果
- `rowsChanged` 的真实回调链路
- `previewStarted / Changed / Ended` 的真实回调链路
- 修改后，`iOSViewController` 和 `macOSViewController` 都在滚动内容底部新增了一个独立的 piano demo 卡片
- 这个卡片包含：
- 固定的默认配置与示例行数据
- 标题
- 当前事件 / preview / rows 摘要文本
- 真正可操作的钢琴视图
- 事件发生时既会更新状态文本，也会向控制台打印日志，便于双平台并排核对语义

## 修改前总体现状

- 修改前，控制器已经有：
- 顶部内容区
- 主内容区
- 指板、谱表、目标提示、设置面板
- 但并没有为 piano 组件预留任何接入点
- 所以阶段 7 之前仍然缺少：
- 控制器级默认 `PianoConfiguration`
- 控制器级默认 `PianoRowState` 阵列
- 放在页面里的真实 piano view
- 控制器层对 `rowsChanged / preview*` 的可视化观察

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration, initialPianoDemoRows, pianoKeyboardView
// 功能说明: 修改前不存在这些钢琴 demo 专用符号，iOS 控制器还没有最小 piano 接入区块。
(无代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration, initialPianoDemoRows, pianoKeyboardView
// 功能说明: 修改前不存在这些钢琴 demo 专用符号，macOS 控制器也还没有任何 piano 页面入口。
(无代码)
```

## 修改 1：在双平台控制器里加入独立的 piano demo 状态

### 修改前

- 修改前，两个控制器的状态几乎都围绕 fretboard / staff / trainer 展开
- 并没有一组只服务于 piano demo 的独立状态
- 因此没有地方去承载：
- 默认 `PianoConfiguration`
- 默认多行 `rows`
- 当前 preview
- 最近一次 piano 事件文本

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration, initialPianoDemoRows, pianoDemoRows, pianoDemoPreview, pianoDemoLastEventText
// 功能说明: 修改前不存在；控制器层还没有钢琴 demo 的独立状态容器。
(无代码)
```

### 修改后

- `iOSViewController` 与 `macOSViewController` 都新增了一套 demo 专用状态
- 默认行数据同时覆盖了两种关键场景：
- 两行 `cascade`
- 一行 `rowOnly`
- 其中第三行起始音故意使用黑键 `F#3`，方便后续阶段继续观察黑键起始的绘制与交互

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration, initialPianoDemoRows
// 功能说明: 给控制器级 demo 准备固定配置与示例 rows，避免阶段 7 就把钢琴组件绑进现有 trainer 状态机。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 96,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    snapEnabled: true
)

private static let initialPianoDemoRows: [PianoRowState] = [
    PianoRowState(
        startNote: NotePitch(pitchClass: .c, octave: 5),
        movementScope: .cascade
    ),
    PianoRowState(
        startNote: NotePitch(pitchClass: .c, octave: 4),
        movementScope: .cascade
    ),
    PianoRowState(
        startNote: NotePitch(pitchClass: .fSharp, octave: 3),
        movementScope: .rowOnly
    )
]
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: pianoDemoRows, pianoDemoPreview, pianoDemoLastEventText
// 功能说明: 控制器独立维护当前 demo 的 rows、preview 和最近事件文本，不污染现有 fretboard trainer 状态。
private let pianoDemoConfiguration = macOSViewController.initialPianoDemoConfiguration
private var pianoDemoRows = macOSViewController.initialPianoDemoRows
private var pianoDemoPreview: PianoPreviewState?
private var pianoDemoLastEventText = "ready"
```

## 修改 2：在双平台滚动页面底部追加 piano demo 卡片

### 修改前

- 修改前，滚动页面只有：
- `topContentHostView`
- `mainContentHostView`
- `contentView.bottom`
- 直接由现有主内容区闭合
- 也就是说，控制器级布局还没有额外的 demo 区块

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: configureLayout()
// 功能说明: 修改前 contentView 的底部直接由 mainContentHostView 收口，没有额外的 piano demo 容器。
(无代码)
```

### 修改后

- 两个平台都没有改动原有顶部/主内容切换逻辑
- 而是在 `contentView` 底部新加了一个独立卡片：
- `pianoDemoContainerView`
- `pianoDemoTitleLabel`
- `pianoDemoStatusLabel`
- `pianoKeyboardView`
- 这样做的好处是：
- demo 和现有主流程物理并列
- 可以真实验证控制器级闭环
- 不会把 piano 实现硬塞进现有 `pageDisplayState` 体系

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: pianoDemoContainerView, pianoDemoTitleLabel, pianoDemoStatusLabel, pianoKeyboardView
// 功能说明: 在 iOS 控制器中新增一个独立的 piano demo 卡片，不侵入现有 top/main content 模式切换。
private let pianoDemoContainerView = UIView()

private lazy var pianoDemoTitleLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .headline)
    label.textColor = .label
    label.text = "Piano Keyboard Demo"
    return label
}()

private lazy var pianoDemoStatusLabel: UILabel = {
    let label = UILabel()
    label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    label.textColor = .secondaryLabel
    label.numberOfLines = 0
    label.text = ""
    return label
}()

private lazy var pianoKeyboardView: iOSPianoKeyboardView = {
    let pianoKeyboardView = iOSPianoKeyboardView(
        configuration: pianoDemoConfiguration,
        rows: pianoDemoRows
    )
    pianoKeyboardView.onRowsChanged = { [weak self] rows in
        self?.handlePianoDemoRowsChanged(rows)
    }
    pianoKeyboardView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoDemoPreviewStarted(preview)
    }
    pianoKeyboardView.onPreviewChanged = { [weak self] preview in
        self?.handlePianoDemoPreviewChanged(preview)
    }
    pianoKeyboardView.onPreviewEnded = { [weak self] preview in
        self?.handlePianoDemoPreviewEnded(preview)
    }
    return pianoKeyboardView
}()
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: configureLayout()
// 功能说明: 把 piano demo 卡片接到 scroll content 的最底部，使其与原有 mainContentHostView 并列而非嵌入 trainer 区。
contentView.addSubview(mainContentHostView)
contentView.addSubview(pianoDemoContainerView)
mainContentHostView.addSubview(fretboardHostView)
mainContentHostView.addSubview(naturalNoteStripView)
pianoDemoContainerView.addSubview(pianoDemoTitleLabel)
pianoDemoContainerView.addSubview(pianoDemoStatusLabel)
pianoDemoContainerView.addSubview(pianoKeyboardView)

NSLayoutConstraint.activate([
    mainContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    mainContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    mainContentHostView.topAnchor.constraint(
        equalTo: topContentHostView.bottomAnchor,
        constant: Layout.verticalSpacing
    ),
    pianoDemoContainerView.topAnchor.constraint(
        equalTo: mainContentHostView.bottomAnchor,
        constant: Layout.verticalSpacing
    ),
    pianoDemoContainerView.leadingAnchor.constraint(
        equalTo: contentView.leadingAnchor,
        constant: Layout.horizontalInset
    ),
    pianoDemoContainerView.trailingAnchor.constraint(
        equalTo: contentView.trailingAnchor,
        constant: -Layout.horizontalInset
    ),
    pianoDemoContainerView.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor,
        constant: -Layout.bottomInset
    )
])
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: pianoDemoContainerView, pianoDemoTitleLabel, pianoDemoStatusLabel, pianoKeyboardView, configureLayout()
// 功能说明: macOS 控制器沿用同一布局策略，在 document content 的最底部追加独立 piano demo 卡片，保持双平台结构一致。
private let pianoDemoContainerView = NSView()

private lazy var pianoDemoTitleLabel: NSTextField = {
    let label = NSTextField(labelWithString: "Piano Keyboard Demo")
    label.font = .systemFont(ofSize: 15, weight: .semibold)
    label.textColor = .labelColor
    return label
}()

private lazy var pianoDemoStatusLabel: NSTextField = {
    let label = NSTextField(wrappingLabelWithString: "")
    label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    label.textColor = .secondaryLabelColor
    label.lineBreakMode = .byWordWrapping
    return label
}()

private lazy var pianoKeyboardView: macOSPianoKeyboardView = {
    let pianoKeyboardView = macOSPianoKeyboardView(
        configuration: pianoDemoConfiguration,
        rows: pianoDemoRows
    )
    pianoKeyboardView.onRowsChanged = { [weak self] rows in
        self?.handlePianoDemoRowsChanged(rows)
    }
    pianoKeyboardView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoDemoPreviewStarted(preview)
    }
    pianoKeyboardView.onPreviewChanged = { [weak self] preview in
        self?.handlePianoDemoPreviewChanged(preview)
    }
    pianoKeyboardView.onPreviewEnded = { [weak self] preview in
        self?.handlePianoDemoPreviewEnded(preview)
    }
    return pianoKeyboardView
}()
```

## 修改 3：把控制器层回调结果同步到状态文本和控制台

### 修改前

- 修改前，控制器并没有一套只服务于 piano demo 的状态更新方法
- 所以即便阶段 5/6 的平台 view 已经能对外发出 `rowsChanged` 和 `preview*`
- 控制器也没有任何地方接住这些事件、汇总成可见的调试信息

```text
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: applyPianoDemoState(), updatePianoDemoStatusLabel(), handlePianoDemoRowsChanged(_:)
// 功能说明: 修改前不存在这些函数，控制器层还没有钢琴 demo 的状态文本与日志收口。
(无代码)
```

### 修改后

- 两个平台都新增了：
- `applyPianoDemoState()`
- `updatePianoDemoStatusLabel()`
- `pianoDemoStatusText()`
- `pianoDemoRowsSummaryText(_:)`
- `handlePianoDemoRowsChanged(_:)`
- `handlePianoDemoPreviewStarted(_:)`
- `handlePianoDemoPreviewChanged(_:)`
- `handlePianoDemoPreviewEnded(_:)`
- 这些函数做两件事：
- 把状态同步回 demo 卡片文本
- 向控制台打印跨平台可比对的事件日志

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: applyPianoDemoState(), updatePianoDemoStatusLabel(), pianoDemoStatusText()
// 功能说明: 把平台 view 的 rows / preview 状态重新投影到控制器级 demo 文本，便于直接观察闭环结果。
private func applyPianoDemoState() {
    pianoKeyboardView.configuration = pianoDemoConfiguration
    pianoKeyboardView.rows = pianoDemoRows
    pianoKeyboardView.showsComponentBoundsOverlay = false
    updatePianoDemoStatusLabel()
}

private func updatePianoDemoStatusLabel() {
    pianoDemoStatusLabel.text = pianoDemoStatusText()
}

private func pianoDemoStatusText() -> String {
    let previewText: String
    if let pianoDemoPreview {
        previewText = "row\(pianoDemoPreview.rowIndex) \(pianoDemoPreview.note.displayText())"
    } else {
        previewText = "nil"
    }

    return [
        "event: \(pianoDemoLastEventText)",
        "preview: \(previewText)",
        "rows: \(pianoDemoRowsSummaryText(pianoDemoRows))"
    ].joined(separator: "\n")
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handlePianoDemoRowsChanged(_:) , handlePianoDemoPreviewStarted(_:) , handlePianoDemoPreviewChanged(_:) , handlePianoDemoPreviewEnded(_:)
// 功能说明: 每次钢琴 demo 事件发生时，控制器同步更新状态文本并打印平台侧日志，方便双平台回调时序对照。
private func handlePianoDemoRowsChanged(_ rows: [PianoRowState]) {
    pianoDemoRows = rows
    pianoDemoLastEventText = "rowsChanged"
    print("[PianoDemo][macOS] rowsChanged \(pianoDemoRowsSummaryText(rows))")
    applyPianoDemoState()
}

private func handlePianoDemoPreviewStarted(_ preview: PianoPreviewState) {
    pianoDemoPreview = preview
    pianoDemoLastEventText = "previewStarted"
    print("[PianoDemo][macOS] previewStarted row=\(preview.rowIndex) note=\(preview.note.displayText())")
    updatePianoDemoStatusLabel()
}

private func handlePianoDemoPreviewChanged(_ preview: PianoPreviewState) {
    pianoDemoPreview = preview
    pianoDemoLastEventText = "previewChanged"
    print("[PianoDemo][macOS] previewChanged row=\(preview.rowIndex) note=\(preview.note.displayText())")
    updatePianoDemoStatusLabel()
}

private func handlePianoDemoPreviewEnded(_ preview: PianoPreviewState) {
    pianoDemoPreview = nil
    pianoDemoLastEventText = "previewEnded row=\(preview.rowIndex) note=\(preview.note.displayText())"
    print("[PianoDemo][macOS] previewEnded row=\(preview.rowIndex) note=\(preview.note.displayText())")
    updatePianoDemoStatusLabel()
}
```

## 修改 4：补充阶段 7 的布局常量

### 修改前

- 修改前控制器底部布局常量只覆盖现有内容区
- 没有给 piano demo 卡片预留独立的内边距、圆角和标题/状态/键盘间距

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: Layout.pianoDemoInnerInset, Layout.pianoDemoStatusTopSpacing, Layout.pianoDemoKeyboardTopSpacing, Layout.pianoDemoCornerRadius
// 功能说明: 修改前不存在这些布局常量，控制器级 piano demo 卡片没有独立样式约束。
(无代码)
```

### 修改后

- 双平台都在各自的 `Layout` 中新增了 piano demo 卡片专用常量
- 这样阶段 7 的 demo 卡片样式仍然服从控制器级集中布局参数管理

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: Layout.pianoDemoInnerInset, Layout.pianoDemoStatusTopSpacing, Layout.pianoDemoKeyboardTopSpacing, Layout.pianoDemoCornerRadius
// 功能说明: 统一收口 piano demo 卡片的内边距、文本间距和圆角，避免把演示样式散落在约束代码里。
private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let contentTopInset: CGFloat = 68
    static let topContentFloatingButtonInset: CGFloat = 12
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let pianoDemoInnerInset: CGFloat = 16
    static let pianoDemoStatusTopSpacing: CGFloat = 8
    static let pianoDemoKeyboardTopSpacing: CGFloat = 12
    static let pianoDemoCornerRadius: CGFloat = 16
    static let settingsButtonSize: CGFloat = 40
    static let sequenceRegenerateButtonSize: CGFloat = 36
    static let contentSizeTolerance: CGFloat = 0.5
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: Layout.pianoDemoInnerInset, Layout.pianoDemoStatusTopSpacing, Layout.pianoDemoKeyboardTopSpacing, Layout.pianoDemoCornerRadius
// 功能说明: macOS 控制器沿用同名布局常量，保持双平台 demo 卡片的结构和间距语义一致。
private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let contentTopInset: CGFloat = 68
    static let topContentFloatingButtonInset: CGFloat = 12
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let pianoDemoInnerInset: CGFloat = 16
    static let pianoDemoStatusTopSpacing: CGFloat = 8
    static let pianoDemoKeyboardTopSpacing: CGFloat = 12
    static let pianoDemoCornerRadius: CGFloat = 16
    static let settingsButtonSize: CGFloat = 40
    static let sequenceRegenerateButtonSize: CGFloat = 36
    static let contentSizeTolerance: CGFloat = 0.5
}
```

## 验证结果

- 本轮已执行 `ReadLints` 检查：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 结果：无 linter 报错
- 本轮已执行全量类型检查：
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`
- 结果：通过
- 本轮全量 typecheck 中出现 2 个既有 warning，但均与阶段 7 的 piano demo 接入无关：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本轮尚未进行真机 / 模拟器 / 桌面窗口的手工联调，因此 piano demo 卡片的运行时外观与交互仍需在下一阶段收口时补验

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: 阶段 7 验证结论
// 功能说明: 当前阶段以控制器接线和静态检查为主，双平台都已把 piano demo 插入页面闭环，但尚未做手工运行时回归。
- ReadLints: 无报错
- swiftc -typecheck NoteMaster_Ver_1/**/*.swift: 通过
- 既有 warning:
  - Shared/Fretboard/FretboardNaturalNoteTrainer.swift
  - Shared/Fretboard/FretboardValidation.swift
- 运行时手工联调: 本轮未执行
```

## 阶段 7 收口说明

- 这一轮没有把 piano 组件接入现有 trainer 状态机，也没有修改 `pageDisplayState` 的切换规则
- 阶段 7 的目标只是让双平台控制器拥有一个真实可交互的 piano 闭环入口
- 当前项目已经具备：
- Shared：`state + geometry + reducer + layer + validation`
- iOS：`UIView` 薄壳 + 控制器 demo
- macOS：`NSView` 薄壳 + 控制器 demo
- 下一阶段可以围绕真实运行时行为做阶段 8 的验证与收口，包括黑键起始、吸附、级联、滑音语义、macOS 坐标归一化和 resize 行为

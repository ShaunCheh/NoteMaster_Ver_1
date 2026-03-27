# 20260327_151944_top_content_sequence_regenerate_button

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_151944`
- 记录范围：为 `TopContent` 增加 `Sequence` 模式下的右上角悬浮“重新生成随机音序列”按钮
- 本次目标：当 `Exercise Mode = Sequence` 时，在 `TopContent` 右上角显示一个悬浮按钮；点击后生成新的随机序列，并继续复用当前统一的 sequence 同步管线
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 当前 sequence 模式虽然已经具备统一的 `GeneratedNoteSequence -> prompt / staff / session` 同步能力，但缺少一个用户可见的“重新出题”入口。
- 如果单独再写一条“按钮点击 -> 自己生成 prompt / 自己改 staff / 自己改 target prompt”的平行逻辑，会再次把 sequence 状态流分叉，违背前面阶段刚刚收口好的统一真相源设计。
- 本次根因级修复策略因此是：把按钮只作为 `TopContent` 的一个浮层入口；点击后仍然回到现有 `regenerate -> synchronizeTrainerPresentationState(...)` 管线，让新序列继续由同一个 controller 投影函数驱动 `prompt / staff / session`。

## 修改 1：iOS 在 `TopContent` 右上角增加 sequence 悬浮按钮

### 修改前

- `topContentHostView` 里只有 `staffView` 和 `targetNotePromptView`
- 没有 sequence 模式专属的浮动按钮
- `trainerDisplayState.didSet` 只负责刷新 settings panel，不负责控制额外入口显隐

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: trainerDisplayState.didSet, settingsContainerView, configureLayout()
// 功能说明: 修改前 TopContent 区域只有 staffView / targetNotePromptView 两个内容视图；
// controller 还没有 sequence 专属的顶部浮动入口。
private var trainerDisplayState = TrainerDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}

private lazy var settingsContainerView: iOSSettingsContainerView = {
    let settingsContainerView = iOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            from: settingsPanelStateContext
        )
    )
    settingsContainerView.onEvent = { [weak self] event in
        self?.handleSettingsPanelEvent(event)
    }
    settingsContainerView.onDismissRequest = { [weak self] in
        self?.setSettingsPresented(false)
    }
    return settingsContainerView
}()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    topContentHostView.translatesAutoresizingMaskIntoConstraints = false
    mainContentHostView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
}
```

### 修改后

- 新增 `sequenceRegenerateButton`
- 放到 `topContentHostView` 里，固定在右上角
- `trainerDisplayState.didSet` 和初始 `applyDisplayState()` 都会同步调用 `applySequenceRegenerateButtonState()`，让按钮显隐直接跟随 `isSequenceMode`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: trainerDisplayState.didSet, sequenceRegenerateButton, configureLayout()
// 功能说明: 修改后 iOS 在 TopContent 上新增 sequence 悬浮按钮；
// 其显隐与 trainerDisplayState.isSequenceMode 绑定，不额外引入新的页面状态字段。
private var trainerDisplayState = TrainerDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
        applySequenceRegenerateButtonState()
    }
}

private lazy var sequenceRegenerateButton: UIButton = {
    let button = UIButton(type: .system)
    var configuration = UIButton.Configuration.filled()
    configuration.buttonSize = .small
    configuration.cornerStyle = .capsule
    configuration.image = UIImage(systemName: "arrow.clockwise")
    configuration.baseBackgroundColor = .systemBlue
    configuration.baseForegroundColor = .white
    configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 8,
        bottom: 8,
        trailing: 8
    )
    button.configuration = configuration
    button.accessibilityIdentifier = "top-content-sequence-regenerate-button"
    button.accessibilityLabel = "Generate new random sequence"
    button.isHidden = true
    button.addTarget(
        self,
        action: #selector(handleSequenceRegenerateButtonTap),
        for: .touchUpInside
    )
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.12
    button.layer.shadowRadius = 10
    button.layer.shadowOffset = CGSize(width: 0, height: 4)
    return button
}()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    topContentHostView.translatesAutoresizingMaskIntoConstraints = false
    mainContentHostView.translatesAutoresizingMaskIntoConstraints = false
    sequenceRegenerateButton.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    topContentHostView.addSubview(sequenceRegenerateButton)

    NSLayoutConstraint.activate([
        sequenceRegenerateButton.topAnchor.constraint(
            equalTo: topContentHostView.topAnchor,
            constant: Layout.topContentFloatingButtonInset
        ),
        sequenceRegenerateButton.trailingAnchor.constraint(
            equalTo: topContentHostView.trailingAnchor,
            constant: -Layout.topContentFloatingButtonInset
        ),
        sequenceRegenerateButton.widthAnchor.constraint(
            equalToConstant: Layout.sequenceRegenerateButtonSize
        ),
        sequenceRegenerateButton.heightAnchor.constraint(
            equalToConstant: Layout.sequenceRegenerateButtonSize
        )
    ])
}
```

## 修改 2：iOS 按钮点击后复用现有 sequence 同步管线，而不是另开分支

### 修改前

- sequence 模式没有“手动重新生成”入口
- `applyDisplayState()` 只会走初始同步
- controller 里也没有专门的 regenerate helper

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyDisplayState(), handleSettingsButtonTap()
// 功能说明: 修改前 iOS 没有 sequence regenerate 入口；
// 当前 sequence 同步只发生在初始化、settings 切换、答题推进等既有路径。
private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyPageDisplayState()
    synchronizeTrainerPresentationState(reason: "initial")
}

@objc
private func handleSettingsButtonTap() {
    setSettingsPresented(!isSettingsPresented)
}
```

### 修改后

- 新增 `applySequenceRegenerateButtonState()`
- 新增 `regenerateQuarterNoteSequence(reason:)`
- 点击按钮时不直接改 `staffView` 或 `targetNotePromptView`，而是重建 `fretboardTrainerState`、清空 `quarterNoteSequenceSession`，再回到 `synchronizeTrainerPresentationState(reason:)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyDisplayState(), applySequenceRegenerateButtonState(),
// regenerateQuarterNoteSequence(reason:), handleSequenceRegenerateButtonTap()
// 功能说明: 修改后 iOS 的重新生成入口仍然复用统一 sequence 同步管线；
// 新序列的 prompt / staff / session 投影继续由既有 controller 逻辑统一处理。
private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyPageDisplayState()
    applySequenceRegenerateButtonState()
    synchronizeTrainerPresentationState(reason: "initial")
}

private func applySequenceRegenerateButtonState() {
    sequenceRegenerateButton.isHidden = !trainerDisplayState.isSequenceMode
}

private func regenerateQuarterNoteSequence(reason: String) {
    guard trainerDisplayState.isSequenceMode else {
        return
    }

    fretboardTrainerState = FretboardNaturalNoteTrainerState(
        quarterNoteSequenceSpec: configuredQuarterNoteSequenceSpec
    )
    quarterNoteSequenceSession = nil
    synchronizeTrainerPresentationState(reason: reason)
}

@objc
private func handleSequenceRegenerateButtonTap() {
    regenerateQuarterNoteSequence(reason: "manualRegenerated")
}
```

## 修改 3：macOS 做同构迁移，保持顶部按钮和 sequence 生成语义一致

### 修改前

- macOS 与 iOS 一样，`topContentHostView` 没有 sequence 模式专属悬浮按钮
- 也没有“重新生成序列”的控制器入口

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: trainerDisplayState.didSet, settingsContainerView, configureLayout(),
// applyDisplayState(), handleSettingsButtonTap()
// 功能说明: 修改前 macOS 没有 TopContent 的 sequence 重新生成按钮，
// sequence 模式也没有用户手动触发的新序列入口。
private var trainerDisplayState = TrainerDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    topContentHostView.translatesAutoresizingMaskIntoConstraints = false
    mainContentHostView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
}

private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyPageDisplayState()
    synchronizeTrainerPresentationState(reason: "initial")
}

@objc
private func handleSettingsButtonTap() {
    setSettingsPresented(!isSettingsPresented)
}
```

### 修改后

- macOS 新增 `sequenceRegenerateButton`
- 同样挂到 `topContentHostView` 右上角
- 同样用 `applySequenceRegenerateButtonState()` 控制显隐
- 同样用 `regenerateQuarterNoteSequence(reason:)` 复用统一 sequence 同步逻辑

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: trainerDisplayState.didSet, sequenceRegenerateButton, configureLayout(),
// applyDisplayState(), applySequenceRegenerateButtonState(),
// regenerateQuarterNoteSequence(reason:), handleSequenceRegenerateButtonTap()
// 功能说明: 修改后 macOS 与 iOS 保持同构；
// 顶部按钮只是 sequence 模式的触发入口，真正的新序列投影仍然回到统一 controller 管线。
private var trainerDisplayState = TrainerDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
        applySequenceRegenerateButtonState()
    }
}

private lazy var sequenceRegenerateButton: NSButton = {
    let button = NSButton()
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.imagePosition = .imageOnly
    button.image = NSImage(
        systemSymbolName: "arrow.clockwise",
        accessibilityDescription: "Generate new random sequence"
    )
    button.imageScaling = .scaleProportionallyDown
    button.contentTintColor = .white
    button.identifier = NSUserInterfaceItemIdentifier(
        "top-content-sequence-regenerate-button"
    )
    button.target = self
    button.action = #selector(handleSequenceRegenerateButtonTap)
    button.toolTip = "Generate new random sequence"
    button.isHidden = true
    button.wantsLayer = true
    button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
    button.layer?.cornerRadius = Layout.sequenceRegenerateButtonSize / 2
    button.layer?.shadowColor = NSColor.black.cgColor
    button.layer?.shadowOpacity = 0.12
    button.layer?.shadowRadius = 10
    button.layer?.shadowOffset = CGSize(width: 0, height: -4)
    return button
}()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    topContentHostView.translatesAutoresizingMaskIntoConstraints = false
    mainContentHostView.translatesAutoresizingMaskIntoConstraints = false
    sequenceRegenerateButton.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    topContentHostView.addSubview(sequenceRegenerateButton)

    NSLayoutConstraint.activate([
        sequenceRegenerateButton.topAnchor.constraint(
            equalTo: topContentHostView.topAnchor,
            constant: Layout.topContentFloatingButtonInset
        ),
        sequenceRegenerateButton.trailingAnchor.constraint(
            equalTo: topContentHostView.trailingAnchor,
            constant: -Layout.topContentFloatingButtonInset
        ),
        sequenceRegenerateButton.widthAnchor.constraint(
            equalToConstant: Layout.sequenceRegenerateButtonSize
        ),
        sequenceRegenerateButton.heightAnchor.constraint(
            equalToConstant: Layout.sequenceRegenerateButtonSize
        )
    ])
}

private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyPageDisplayState()
    applySequenceRegenerateButtonState()
    synchronizeTrainerPresentationState(reason: "initial")
}

private func applySequenceRegenerateButtonState() {
    sequenceRegenerateButton.isHidden = !trainerDisplayState.isSequenceMode
}

private func regenerateQuarterNoteSequence(reason: String) {
    guard trainerDisplayState.isSequenceMode else {
        return
    }

    fretboardTrainerState = FretboardNaturalNoteTrainerState(
        quarterNoteSequenceSpec: configuredQuarterNoteSequenceSpec
    )
    quarterNoteSequenceSession = nil
    synchronizeTrainerPresentationState(reason: reason)
}

@objc
private func handleSequenceRegenerateButtonTap() {
    regenerateQuarterNoteSequence(reason: "manualRegenerated")
}
```

## 修改 4：补布局常量，明确按钮的 TopContent 浮层位置和尺寸

### 修改前

- 两端 `Layout` 中没有 TopContent 浮动 sequence 按钮相关常量

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: Layout
// 功能说明: 修改前 Layout 只定义 settings 按钮、边距和内容间距，没有 sequence 浮动按钮尺寸。
private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let contentTopInset: CGFloat = 68
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let settingsButtonSize: CGFloat = 40
    static let contentSizeTolerance: CGFloat = 0.5
}
```

### 修改后

- iOS/macOS 两端都新增：
- `topContentFloatingButtonInset`
- `sequenceRegenerateButtonSize`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: Layout
// 功能说明: 修改后为 TopContent 右上角 sequence 浮动按钮补充独立布局常量，
// 避免与页面左上角 settingsButton 的布局语义混淆。
private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let contentTopInset: CGFloat = 68
    static let topContentFloatingButtonInset: CGFloat = 12
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let settingsButtonSize: CGFloat = 40
    static let sequenceRegenerateButtonSize: CGFloat = 36
    static let contentSizeTolerance: CGFloat = 0.5
}
```

## 验证结果

- `ReadLints` 检查结果：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 以上文件均为 `No linter errors found`
- 本次记录文件已放入：`commit_records/20260327_151944_top_content_sequence_regenerate_button.md`
- 本次没有执行 `xcodebuild`；这里只记录本次实际做过的静态诊断结果

## 本次落地结果

- 当 `Exercise Mode = Sequence` 时，`TopContent` 右上角会显示悬浮刷新按钮
- 该按钮不会引入新的 sequence 平行状态流，而是复用现有的 `synchronizeTrainerPresentationState(...)`
- 点击后会：
- 用当前 `configuredQuarterNoteSequenceSpec` 重建 `fretboardTrainerState`
- 清空旧 `quarterNoteSequenceSession`
- 重新生成一份新的 `GeneratedNoteSequence`
- 继续把这份新序列统一投影到 `prompt / staff / session`

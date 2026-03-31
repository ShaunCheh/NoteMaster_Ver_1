# 20260331_164928_fretboard_label_visibility_floating_toggle

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_164928`
- 记录范围：在 iOS / macOS 页面右上角新增一个悬浮“显示”按钮，使用可见/不可见图标快速切换 fretboard label 的 `BCEF` 显示与隐藏
- 修改性质：不走设置卡片内二级操作，而是在控制器根视图增加独立悬浮入口；并把按钮显示条件、图标状态、无障碍文案与 `displayState.visibility` 的真相统一收口到控制器层
- 涉及文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

- 左上角只有悬浮 `settingsButton`，右上角没有对应的快捷可见性入口。
- 要切换 fretboard labels 的显示，只能进入 settings card，再到 `fretboard -> labels` 中手动选模式。
- 控制器层没有“快速切到 `BCEF` / 快速切到隐藏”的独立状态同步逻辑。
- `applySettingsPresentationState()` 只负责 settings 按钮与 settings container 的联动，没有处理右上角可见性按钮。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: settingsButton / configureLayout()
// 功能说明: 修改前 iOS 根视图只挂了左上角 settingsButton；
// safe area 右上角没有与 fretboard label visibility 相关的悬浮按钮。
private lazy var settingsButton: UIButton = {
    let button = UIButton(type: .system)
    var configuration = UIButton.Configuration.filled()
    configuration.buttonSize = .medium
    configuration.cornerStyle = .capsule
    configuration.image = UIImage(systemName: "gearshape.fill")
    configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 10,
        leading: 10,
        bottom: 10,
        trailing: 10
    )
    button.configuration = configuration
    button.accessibilityIdentifier = "floating-settings-button"
    button.addTarget(
        self,
        action: #selector(handleSettingsButtonTap),
        for: .touchUpInside
    )
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.12
    button.layer.shadowRadius = 12
    button.layer.shadowOffset = CGSize(width: 0, height: 4)
    return button
}()

// ... 中间布局代码省略

view.addSubview(settingsButton)
view.addSubview(settingsContainerView)

settingsButton.leadingAnchor.constraint(
    equalTo: safeArea.leadingAnchor,
    constant: Layout.horizontalInset
),
settingsButton.topAnchor.constraint(
    equalTo: safeArea.topAnchor,
    constant: Layout.topInset
),
settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: applyDisplayState() / applyFretboardDisplayState() / applyPageDisplayState()
// 功能说明: 修改前控制器只会同步 settings 按钮和 sequence 刷新按钮，
// 不存在右上角 BCEF 快捷按钮的显隐或图标刷新。
private func applyDisplayState() {
    logLifecycle("applyDisplayState begin")
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyPageDisplayState()
    applySequenceRegenerateButtonState()
    synchronizeTrainerPresentationState(reason: "initial")
    logLifecycle("applyDisplayState end")
}

private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
}

private func applyPageDisplayState() {
    applyFretboardHostPlacement()
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: applySettingsPresentationState() / handleSettingsButtonTap()
// 功能说明: 修改前 settings 展示状态只会影响左上角齿轮与 settings card，
// 没有任何 label visibility 快捷入口参与联动。
private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    settingsButton.isHidden = isSettingsPresented
    updateSettingsButtonAppearance()
}

@objc
private func handleSettingsButtonTap() {
    setSettingsPresented(!isSettingsPresented)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: settingsButton / configureLayout() / applySettingsPresentationState()
// 功能说明: 修改前 macOS 与 iOS 对称，
// 同样只有左上角 settingsButton，没有右上角 BCEF 显隐快捷按钮。
private lazy var settingsButton: NSButton = {
    let button = NSButton()
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.imagePosition = .imageOnly
    button.image = NSImage(
        systemSymbolName: "gearshape.fill",
        accessibilityDescription: "Settings"
    )
    button.identifier = NSUserInterfaceItemIdentifier("floating-settings-button")
    button.target = self
    button.action = #selector(handleSettingsButtonTap)
    button.wantsLayer = true
    button.layer?.cornerRadius = Layout.settingsButtonSize / 2
    return button
}()

// ... 中间布局代码省略

view.addSubview(settingsButton)
view.addSubview(settingsContainerView)

private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    settingsButton.isHidden = isSettingsPresented
    updateSettingsButtonAppearance()
}
```

## 修改后

- iOS / macOS 控制器根视图右上角都新增了一个悬浮 `labelVisibilityButton`。
- 按钮默认使用 `eye.slash.fill`，表示当前快捷模式不是 `BCEF` 可见态；切到 `BCEF` 后改成 `eye.fill`。
- 按钮点击时直接在 `.bcefOnly` 与 `.none` 之间切换，语义对应“显示 BCEF / 隐藏 labels”。
- 当页面当前不显示 fretboard，或者 settings card 已经展开时，该按钮会自动隐藏，避免与卡片层入口冲突。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: labelVisibilityButton / configureLayout()
// 功能说明: 修改后 iOS 在根视图右上角新增悬浮按钮，
// 与左上角 settingsButton 对称，固定到 safe area.trailing/top。
private lazy var labelVisibilityButton: UIButton = {
    let button = UIButton(type: .system)
    var configuration = UIButton.Configuration.filled()
    configuration.buttonSize = .medium
    configuration.cornerStyle = .capsule
    configuration.image = UIImage(systemName: "eye.slash.fill")
    configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 10,
        leading: 10,
        bottom: 10,
        trailing: 10
    )
    button.configuration = configuration
    button.accessibilityIdentifier = "floating-fretboard-label-visibility-button"
    button.addTarget(
        self,
        action: #selector(handleLabelVisibilityButtonTap),
        for: .touchUpInside
    )
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.12
    button.layer.shadowRadius = 12
    button.layer.shadowOffset = CGSize(width: 0, height: 4)
    return button
}()

// ... 中间布局代码省略

view.addSubview(settingsButton)
view.addSubview(labelVisibilityButton)
view.addSubview(settingsContainerView)

labelVisibilityButton.trailingAnchor.constraint(
    equalTo: safeArea.trailingAnchor,
    constant: -Layout.horizontalInset
),
labelVisibilityButton.topAnchor.constraint(
    equalTo: safeArea.topAnchor,
    constant: Layout.topInset
),
labelVisibilityButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
labelVisibilityButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: applyDisplayState() / applyFretboardDisplayState() / applyPageDisplayState()
// 功能说明: 修改后 iOS 把按钮显隐与外观刷新接入 display/page/fretboard 三条主同步链，
// 保证页面布局变化、fretboard 出现消失、labels 模式切换时都能立刻刷新右上角状态。
private func applyDisplayState() {
    logLifecycle("applyDisplayState begin")
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyPageDisplayState()
    applySequenceRegenerateButtonState()
    applyLabelVisibilityButtonState()
    synchronizeTrainerPresentationState(reason: "initial")
    logLifecycle("applyDisplayState end")
}

private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    updateFretboardLayoutModeConstraints()
}

private func applyPageDisplayState() {
    applyFretboardHostPlacement()
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    updateLayoutIfNeeded()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: applyLabelVisibilityButtonState() / updateLabelVisibilityButtonAppearance() / handleLabelVisibilityButtonTap()
// 功能说明: 修改后 iOS 明确把按钮语义收口为：
// 显示 fretboard 时可见；点击后在 BCEF 与隐藏之间切换；图标和无障碍文案跟随当前状态同步。
private func applyLabelVisibilityButtonState() {
    labelVisibilityButton.isHidden = !isShowingFretboard || isSettingsPresented
    updateLabelVisibilityButtonAppearance()
}

private func updateLabelVisibilityButtonAppearance() {
    let showsBCEFLabels = displayState.visibility == .bcefOnly
    var configuration = labelVisibilityButton.configuration ?? UIButton.Configuration.filled()
    configuration.image = UIImage(
        systemName: showsBCEFLabels ? "eye.fill" : "eye.slash.fill"
    )
    configuration.baseBackgroundColor = showsBCEFLabels
        ? .systemBlue
        : .secondarySystemBackground
    configuration.baseForegroundColor = showsBCEFLabels
        ? .white
        : .label
    labelVisibilityButton.configuration = configuration
    labelVisibilityButton.accessibilityLabel = showsBCEFLabels
        ? "Hide BCEF fretboard labels"
        : "Show BCEF fretboard labels"
}

@objc
private func handleLabelVisibilityButtonTap() {
    displayState.visibility = displayState.visibility == .bcefOnly
        ? .none
        : .bcefOnly
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: applySettingsPresentationState()
// 功能说明: 修改后 iOS 在 settings card 展示状态变化时，
// 也会同步刷新右上角 label visibility 按钮，避免与 settings card 同屏冲突。
private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    settingsButton.isHidden = isSettingsPresented
    updateSettingsButtonAppearance()
    applyLabelVisibilityButtonState()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: labelVisibilityButton / configureLayout()
// 功能说明: 修改后 macOS 与 iOS 对称新增右上角悬浮按钮，
// 图标和阴影风格沿用现有 settingsButton 的平台实现。
private lazy var labelVisibilityButton: NSButton = {
    let button = NSButton()
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.imagePosition = .imageOnly
    button.image = NSImage(
        systemSymbolName: "eye.slash.fill",
        accessibilityDescription: "Show BCEF fretboard labels"
    )
    button.imageScaling = .scaleProportionallyDown
    button.contentTintColor = .labelColor
    button.identifier = NSUserInterfaceItemIdentifier(
        "floating-fretboard-label-visibility-button"
    )
    button.target = self
    button.action = #selector(handleLabelVisibilityButtonTap)
    button.wantsLayer = true
    button.layer?.cornerRadius = Layout.settingsButtonSize / 2
    button.layer?.shadowColor = NSColor.black.cgColor
    button.layer?.shadowOpacity = 0.12
    button.layer?.shadowRadius = 12
    button.layer?.shadowOffset = CGSize(width: 0, height: -4)
    return button
}()

// ... 中间布局代码省略

view.addSubview(settingsButton)
view.addSubview(labelVisibilityButton)
view.addSubview(settingsContainerView)

labelVisibilityButton.trailingAnchor.constraint(
    equalTo: safeArea.trailingAnchor,
    constant: -Layout.horizontalInset
),
labelVisibilityButton.topAnchor.constraint(
    equalTo: safeArea.topAnchor,
    constant: Layout.topInset
),
labelVisibilityButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
labelVisibilityButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: applyLabelVisibilityButtonState() / updateLabelVisibilityButtonAppearance() / handleLabelVisibilityButtonTap()
// 功能说明: 修改后 macOS 对称收口 BCEF 快捷按钮的显隐、图标、tooltip 与点击行为，
// 保证跨平台都直接在 .bcefOnly 与 .none 之间切换。
private func applyLabelVisibilityButtonState() {
    labelVisibilityButton.isHidden = !isShowingFretboard || isSettingsPresented
    updateLabelVisibilityButtonAppearance()
}

private func updateLabelVisibilityButtonAppearance() {
    let showsBCEFLabels = displayState.visibility == .bcefOnly
    let accessibilityLabel = showsBCEFLabels
        ? "Hide BCEF fretboard labels"
        : "Show BCEF fretboard labels"
    labelVisibilityButton.image = NSImage(
        systemSymbolName: showsBCEFLabels ? "eye.fill" : "eye.slash.fill",
        accessibilityDescription: accessibilityLabel
    )
    labelVisibilityButton.contentTintColor = showsBCEFLabels ? .white : .labelColor
    labelVisibilityButton.layer?.backgroundColor = (
        showsBCEFLabels
            ? NSColor.controlAccentColor
            : NSColor.controlBackgroundColor
    ).cgColor
    labelVisibilityButton.toolTip = accessibilityLabel
    labelVisibilityButton.setAccessibilityLabel(accessibilityLabel)
}

@objc
private func handleLabelVisibilityButtonTap() {
    displayState.visibility = displayState.visibility == .bcefOnly
        ? .none
        : .bcefOnly
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: applyDisplayState() / applyFretboardDisplayState() / applyPageDisplayState() / applySettingsPresentationState()
// 功能说明: 修改后 macOS 同步把按钮状态刷新接进四条主链路，
// 避免页面切换、指板显隐、settings 展开后出现悬浮按钮状态滞后。
private func applyDisplayState() {
    logLifecycle("applyDisplayState begin")
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyPageDisplayState()
    applySequenceRegenerateButtonState()
    applyLabelVisibilityButtonState()
    synchronizeTrainerPresentationState(reason: "initial")
    logLifecycle("applyDisplayState end")
}

private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    updateFretboardLayoutModeConstraints()
}

private func applyPageDisplayState() {
    applyFretboardHostPlacement()
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    updateLayoutIfNeeded()
}

private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    settingsButton.isHidden = isSettingsPresented
    updateSettingsButtonAppearance()
    applyLabelVisibilityButtonState()
}
```

## 验证

- `ReadLints` 检查以下文件，无新增 linter 错误：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 已执行 iOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build`
- 已执行 macOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx CODE_SIGNING_ALLOWED=NO build`

## 结果

- 新增记录文件：`commit_records/20260331_164928_fretboard_label_visibility_floating_toggle.md`
- 当前这次改动未提交 git，仅完成代码修改与记录落盘

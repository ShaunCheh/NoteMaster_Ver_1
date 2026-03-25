# 20260325_185745_phase4_settings_container_and_floating_gear_entry

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_185745`
- 记录范围：方案 D 的实施阶段 4，设置容器与悬浮齿轮入口
- 本次目标：把统一 settings panel 放进独立设置容器；主页面只保留五线谱与指板；在页面左上角增加悬浮齿轮按钮，点击后弹出设置浮层
- 本次实际改动：
  - 新增 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
  - 新增 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
  - 改造 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - 改造 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 实际落地说明：为了让阶段 4 新增的浮层不是空壳，本轮控制器已接上 `SettingsPanelSnapshotBuilder` 和 `SettingsPanelEvent`，因此“统一设置事件流”的最小可用接线也一并进入了本次修改

## 本次完成的修改

1. 新增 iOS 设置容器，包含遮罩背景、浮层卡片、滚动承载和内嵌 `iOSSettingsPanelView`。
2. 新增 macOS 设置容器，结构与 iOS 对称，支持点击遮罩关闭。
3. iOS 控制器从滚动内容中移除旧的三个控制面板，主内容只保留 `staffView` 和 `fretboardHostView`。
4. macOS 控制器完成同样的页面层级改造。
5. 双平台控制器都新增了左上角悬浮齿轮按钮和浮层显示状态。
6. 双平台控制器都已改为刷新统一 `SettingsPanelSnapshotBuilder.makeModel(...)`，并通过 `handleSettingsPanelEvent(_:)` 回写共享 display state。
7. 完成阶段 4 相关文件的 lint 检查，以及共享层加 macOS 平台层的 `swiftc -typecheck` 静态校验。

## 修改 1：新增 iOS 设置容器，承载统一 settings 浮层

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 iOS 端没有独立的设置容器；统一 settings panel 没有浮层承载，也没有遮罩和点击外部关闭能力。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: iOSSettingsContainerView.configureView() / setPresented(_:) / handleBackdropTap()
// 功能说明: 修改后 iOS 容器负责遮罩、卡片、滚动承载、内嵌 iOSSettingsPanelView，并通过 backdrop 点击请求关闭。
#if os(iOS)
import Foundation
import UIKit

final class iOSSettingsContainerView: UIView {
    var model: SettingsPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            settingsPanelView.model = model
        }
    }

    var onEvent: ((SettingsPanelEvent) -> Void)? {
        didSet {
            settingsPanelView.onEvent = onEvent
        }
    }

    var onDismissRequest: (() -> Void)?

    private let backdropView = UIControl()
    private let cardView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let settingsPanelView: iOSSettingsPanelView

    func setPresented(_ presented: Bool) {
        isHidden = !presented
        alpha = presented ? 1 : 0
        isUserInteractionEnabled = presented
        accessibilityElementsHidden = !presented
    }

    private func configureView() {
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(Style.backdropOpacity)
        backdropView.addTarget(
            self,
            action: #selector(handleBackdropTap),
            for: .touchUpInside
        )

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = Style.cardCornerRadius

        cardView.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(settingsPanelView)
    }

    @objc
    private func handleBackdropTap() {
        onDismissRequest?()
    }
}
#endif
```

## 修改 2：新增 macOS 设置容器，结构与 iOS 对称

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 macOS 端同样没有独立设置容器；统一 settings panel 没有浮层承载和外部点击关闭入口。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: macOSSettingsContainerView.configureView() / setPresented(_:) / DismissBackgroundView.mouseDown(with:)
// 功能说明: 修改后 macOS 容器负责遮罩、卡片、滚动承载、内嵌 macOSSettingsPanelView，并把点击背景关闭的能力收口在 DismissBackgroundView。
#if os(macOS)
import Foundation
import AppKit

final class macOSSettingsContainerView: NSView {
    var model: SettingsPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            settingsPanelView.model = model
        }
    }

    var onEvent: ((SettingsPanelEvent) -> Void)? {
        didSet {
            settingsPanelView.onEvent = onEvent
        }
    }

    var onDismissRequest: (() -> Void)?

    private let backdropView = DismissBackgroundView()
    private let cardView = NSView()
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let settingsPanelView: macOSSettingsPanelView

    func setPresented(_ presented: Bool) {
        isHidden = !presented
        alphaValue = presented ? 1 : 0
    }

    private func configureView() {
        backdropView.onClick = { [weak self] in
            self?.onDismissRequest?()
        }

        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = Style.cardCornerRadius

        scrollView.documentView = contentView
        cardView.addSubview(scrollView)
        contentView.addSubview(settingsPanelView)
    }
}

private final class DismissBackgroundView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
#endif
```

## 修改 3：iOS 控制器把主页面从“内容区 + 三块 panel”改成“内容区 + 悬浮齿轮 + 设置浮层”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: buttonPanelView / staffControlPanelView / fretboardControlPanelView / configureLayout()
// 功能说明: 修改前 3 套控制面板直接放在 scrollView 的 contentView 里，主页面本身承担了所有设置 UI。
private lazy var buttonPanelView: iOSButtonPanelView = {
    let buttonPanelView = iOSButtonPanelView(
        model: ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    )
    buttonPanelView.onAction = { [weak self] actionID in
        self?.handleButtonAction(actionID)
    }
    return buttonPanelView
}()

private lazy var staffControlPanelView: iOSStaffControlPanelView = {
    let staffControlPanelView = iOSStaffControlPanelView(
        model: StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
    )
    staffControlPanelView.onEvent = { [weak self] event in
        self?.handleStaffControlEvent(event)
    }
    return staffControlPanelView
}()

private lazy var fretboardControlPanelView: iOSFretboardControlPanelView = {
    let fretboardControlPanelView = iOSFretboardControlPanelView(
        model: FretboardControlPanelSnapshotBuilder.makeModel(from: displayState)
    )
    fretboardControlPanelView.onEvent = { [weak self] event in
        self?.handleFretboardControlEvent(event)
    }
    return fretboardControlPanelView
}()

view.addSubview(scrollView)
scrollView.addSubview(contentView)
contentView.addSubview(buttonPanelView)
contentView.addSubview(staffControlPanelView)
contentView.addSubview(fretboardControlPanelView)
contentView.addSubview(staffView)
contentView.addSubview(fretboardHostView)
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: settingsButton / settingsContainerView / configureLayout()
// 功能说明: 修改后主页面只保留 staffView 与 fretboardHostView；齿轮按钮和设置浮层挂在控制器根视图层级，不进入滚动内容。
private var isSettingsPresented = false

private lazy var settingsButton: UIButton = {
    let button = UIButton(type: .system)
    var configuration = UIButton.Configuration.filled()
    configuration.cornerStyle = .capsule
    configuration.image = UIImage(systemName: "gearshape.fill")
    button.configuration = configuration
    button.accessibilityIdentifier = "floating-settings-button"
    button.addTarget(
        self,
        action: #selector(handleSettingsButtonTap),
        for: .touchUpInside
    )
    return button
}()

private lazy var settingsContainerView: iOSSettingsContainerView = {
    let settingsContainerView = iOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState
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

view.addSubview(scrollView)
scrollView.addSubview(contentView)
contentView.addSubview(staffView)
contentView.addSubview(fretboardHostView)
view.addSubview(settingsButton)
view.addSubview(settingsContainerView)
```

## 修改 4：iOS 控制器移除了旧 panel 约束链，改为内容区直连布局

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: configureLayout() / updateFretboardControlPanelVisibility()
// 功能说明: 修改前 staffView 的顶部位置依赖 staffControlPanelView 或 fretboardControlPanelView；竖向模式还要额外维护 fretboard control panel 的显示/折叠逻辑。
collapsedFretboardControlPanelHeightConstraint = fretboardControlPanelView.heightAnchor.constraint(
    equalToConstant: 0
)
staffViewTopToStaffControlPanelConstraint = staffView.topAnchor.constraint(
    equalTo: staffControlPanelView.bottomAnchor,
    constant: Layout.verticalSpacing
)
staffViewTopToFretboardControlPanelConstraint = staffView.topAnchor.constraint(
    equalTo: fretboardControlPanelView.bottomAnchor,
    constant: Layout.verticalSpacing
)

private func updateFretboardControlPanelVisibility() {
    let showsFretboardControlPanel = displayState.displayMode == .vertical
    fretboardControlPanelView.isHidden = !showsFretboardControlPanel
    collapsedFretboardControlPanelHeightConstraint?.isActive = !showsFretboardControlPanel
    staffViewTopToStaffControlPanelConstraint?.isActive = !showsFretboardControlPanel
    staffViewTopToFretboardControlPanelConstraint?.isActive = showsFretboardControlPanel
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: configureLayout() / Layout.contentTopInset
// 功能说明: 修改后主内容的顶部链路直接从 contentView 连接到 staffView；旧 panel 专属的显示/折叠约束完全退出主页面布局。
NSLayoutConstraint.activate([
    scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
    scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
    scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
    scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
    contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
    contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
    contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
    contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
    contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
    staffView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: Layout.contentTopInset
    ),
    staffView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    staffView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    fretboardHostView.topAnchor.constraint(
        equalTo: staffView.bottomAnchor,
        constant: Layout.verticalSpacing
    ),
    fretboardHostView.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor,
        constant: -Layout.bottomInset
    )
])

private enum Layout {
    static let contentTopInset: CGFloat = 68
}
```

## 修改 5：iOS 控制器把设置交互切到统一 settings 流

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyFretboardDisplayState() / applyStaffDisplayState() / handleButtonAction(_) / handleStaffControlEvent(_) / handleFretboardControlEvent(_)
// 功能说明: 修改前控制器需要分别刷新 3 个旧 panel model，并分别处理 3 套事件入口。
private func applyFretboardDisplayState() {
    buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardControlPanelView.model = FretboardControlPanelSnapshotBuilder.makeModel(from: displayState)
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardControlPanelVisibility()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}

private func applyStaffDisplayState() {
    staffControlPanelView.model = StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
    staffView.configuration = staffDisplayState.configuration
    staffView.sceneProvider = staffDisplayState.sceneProvider
    updateLayoutIfNeeded()
}

private func handleButtonAction(_ actionID: ButtonPanelActionID) { /* ... */ }
private func handleStaffControlEvent(_ event: StaffControlEvent) { /* ... */ }
private func handleFretboardControlEvent(_ event: FretboardControlEvent) { /* ... */ }
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applySettingsPanelState() / setSettingsPresented(_) / updateSettingsButtonAppearance() / handleSettingsButtonTap() / handleSettingsPanelEvent(_:)
// 功能说明: 修改后控制器统一刷新 SettingsPanelSnapshotBuilder.makeModel(...)，统一处理 SettingsPanelEvent，并维护设置浮层的显示状态与齿轮按钮外观。
private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}

private func applyStaffDisplayState() {
    staffView.configuration = staffDisplayState.configuration
    staffView.sceneProvider = staffDisplayState.sceneProvider
    applySettingsPanelState()
    updateLayoutIfNeeded()
}

private func applySettingsPanelState() {
    settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState
    )
}

private func setSettingsPresented(_ presented: Bool) {
    guard isSettingsPresented != presented else {
        return
    }

    isSettingsPresented = presented
    settingsContainerView.setPresented(presented)
    updateSettingsButtonAppearance()
}

@objc
private func handleSettingsButtonTap() {
    setSettingsPresented(!isSettingsPresented)
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState
    )

    if nextDisplayState != displayState {
        displayState = nextDisplayState
    }

    if nextStaffDisplayState != staffDisplayState {
        staffDisplayState = nextStaffDisplayState
    }
}
```

## 修改 6：macOS 控制器做同样的页面层级与统一设置流改造

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: buttonPanelView / staffControlPanelView / fretboardControlPanelView / configureLayout() / applyFretboardDisplayState() / applyStaffDisplayState()
// 功能说明: 修改前 macOS 控制器与 iOS 一样，把 3 套旧 panel 放在 scrollView.documentView 里，并分别刷新、分别处理事件。
private lazy var buttonPanelView: macOSButtonPanelView = {
    let buttonPanelView = macOSButtonPanelView(
        model: ButtonPanelSnapshotBuilder.makeModel(from: displayState)
    )
    buttonPanelView.onAction = { [weak self] actionID in
        self?.handleButtonAction(actionID)
    }
    return buttonPanelView
}()

private lazy var staffControlPanelView: macOSStaffControlPanelView = {
    let staffControlPanelView = macOSStaffControlPanelView(
        model: StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
    )
    staffControlPanelView.onEvent = { [weak self] event in
        self?.handleStaffControlEvent(event)
    }
    return staffControlPanelView
}()

private lazy var fretboardControlPanelView: macOSFretboardControlPanelView = {
    let fretboardControlPanelView = macOSFretboardControlPanelView(
        model: FretboardControlPanelSnapshotBuilder.makeModel(from: displayState)
    )
    fretboardControlPanelView.onEvent = { [weak self] event in
        self?.handleFretboardControlEvent(event)
    }
    return fretboardControlPanelView
}()

view.addSubview(scrollView)
contentView.addSubview(buttonPanelView)
contentView.addSubview(staffControlPanelView)
contentView.addSubview(fretboardControlPanelView)
contentView.addSubview(staffView)
contentView.addSubview(fretboardHostView)
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: settingsButton / settingsContainerView / configureLayout() / handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS 控制器与 iOS 对称，页面只保留内容区，齿轮按钮和设置容器挂在根视图层级，并统一消费 SettingsPanelEvent。
private var isSettingsPresented = false

private lazy var settingsButton: NSButton = {
    let button = NSButton()
    button.image = NSImage(
        systemSymbolName: "gearshape.fill",
        accessibilityDescription: "Settings"
    )
    button.identifier = NSUserInterfaceItemIdentifier("floating-settings-button")
    button.target = self
    button.action = #selector(handleSettingsButtonTap)
    return button
}()

private lazy var settingsContainerView: macOSSettingsContainerView = {
    let settingsContainerView = macOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState
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

view.addSubview(scrollView)
contentView.addSubview(staffView)
contentView.addSubview(fretboardHostView)
view.addSubview(settingsButton)
view.addSubview(settingsContainerView)

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState
    )

    if nextDisplayState != displayState {
        displayState = nextDisplayState
    }

    if nextStaffDisplayState != staffDisplayState {
        staffDisplayState = nextStaffDisplayState
    }
}
```

## 验证结果

```bash
# 文件路径: 命令行校验（无项目内文件路径）
# 函数/成员: ReadLints；swiftc -typecheck
# 功能说明: 阶段 4 新增容器文件和双平台控制器改动已完成 lint 检查；共享层加 macOS 平台层已通过静态类型检查。
ReadLints paths:
- NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
- NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
- NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
- NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
Result:
- No linter errors found.

swiftc -typecheck:
setopt extendedglob && files=(NoteMaster_Ver_1/Shared/**/*.swift NoteMaster_Ver_1/Platform/macOS/**/*.swift) && swiftc -typecheck $files
Result:
- exit code 0
```

## 结果说明

- 阶段 4 完成后，主页面的视觉层级已经切换为“内容区 + 左上角悬浮齿轮按钮 + 设置浮层容器”。
- 旧的 `buttonPanelView`、`staffControlPanelView`、`fretboardControlPanelView` 已经从两个控制器的页面层级中移除，不再参与主页面布局。
- 本轮记录如实反映了实际代码状态：为了让浮层里的统一 settings 面板可交互，控制器已经提前接入统一 settings 快照与事件回写链路，而不是仅仅新增一个空容器。

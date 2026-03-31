# 20260331_143419_settings_navigation_phase3_container_shell_refactor

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_143419`
- 记录范围：实施“卡片内设置导航改造”的阶段 3，双平台 container 壳层改造
- 修改性质：保留 card 外观，统一 header 能力，并把内容承载从直接表单切换到 `navigatorHostView`
- 涉及文件：
  - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`

## 修改前

- `iOS/macOS` 两端的 container 只有 `closeButton`，没有 `backButton` 与 `titleLabel`。
- 内容区是 `scrollView -> contentView -> settingsPanelView`，也就是说 card 壳层直接承载单页表单，没有为后续 navigator 预留宿主层。
- 因此阶段 4 如果直接接 navigator，会同时改 header 和内容宿主，耦合过大。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数名: configureView()
// 功能说明: 修改前 iOS container 的 header 里只有 closeButton，
// scroll 内容区也直接挂 settingsPanelView，没有 navigator host。
cardView.addSubview(headerView)
headerView.addSubview(closeButton)
cardView.addSubview(scrollView)
scrollView.addSubview(contentView)
contentView.addSubview(settingsPanelView)

let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
    equalTo: settingsPanelView.heightAnchor
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数名: configureView()
// 功能说明: 修改前 macOS container 结构与 iOS 对称，
// 同样没有 back/title，也没有 navigatorHostView。
cardView.addSubview(headerView)
headerView.addSubview(closeButton)
cardView.addSubview(scrollView)
contentView.addSubview(settingsPanelView)

let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
    equalTo: settingsPanelView.heightAnchor
)
```

## 修改后

- 双平台 container 都新增了：
  - `navigationTitle`
  - `showsBackButton`
  - `onBackRequest`
  - `backButton`
  - `titleLabel`
  - `navigatorHostView`
  - `setNavigationContentView(...)`
- header 现在统一承载 `back/title/close` 三者，但 `backButton` 默认隐藏，因此当前实际视觉仍接近原状。
- 内容区已经从“直接挂 `settingsPanelView`”变成“挂 `navigatorHostView`”，并继续把现有 `settingsPanelView` 作为默认内容塞进去。
- 这样阶段 4 只需要替换 `navigatorHostView` 内的内容视图，就能接入真正的 navigator，而不用再改 card 壳层。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数名: 属性区 + configureView()
// 功能说明: iOS container 新增统一 header 状态与 navigator 宿主层，
// 为后续卡片内导航做准备，同时继续复用现有 settingsPanelView 作为默认内容。
var navigationTitle: String = SettingsRouteID.root.fallbackTitle {
    didSet {
        updateNavigationHeaderState()
    }
}

var showsBackButton = false {
    didSet {
        updateNavigationHeaderState()
    }
}

var onBackRequest: (() -> Void)?

private let navigatorHostView = UIView()
private weak var currentNavigationContentView: UIView?
private var hostedContentConstraints: [NSLayoutConstraint] = []

private lazy var backButton: UIButton = {
    let button = UIButton(type: .system)
    var configuration = UIButton.Configuration.plain()
    configuration.buttonSize = .medium
    configuration.image = UIImage(systemName: "chevron.left")
    configuration.baseForegroundColor = .label
    button.configuration = configuration
    button.accessibilityIdentifier = "settings-container-back-button"
    button.isHidden = true
    button.addTarget(
        self,
        action: #selector(handleBackButtonTap),
        for: .touchUpInside
    )
    return button
}()

private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .headline)
    label.textAlignment = .center
    label.accessibilityIdentifier = "settings-container-title"
    return label
}()
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数名: configureView()
// 功能说明: iOS container 的 scroll 内容高度约束改为锚定 navigatorHostView，
// header 则固定承载 back/title/close，避免后续出现双层导航条。
headerView.addSubview(backButton)
headerView.addSubview(titleLabel)
headerView.addSubview(closeButton)
cardView.addSubview(scrollView)
scrollView.addSubview(contentView)
contentView.addSubview(navigatorHostView)

let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
    equalTo: navigatorHostView.heightAnchor
)

setNavigationContentView(settingsPanelView)
updateNavigationHeaderState()
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数名: setNavigationContentView(_:) / updateNavigationHeaderState()
// 功能说明: 新增内容宿主切换能力；
// 当前先继续挂原来的 settingsPanelView，后续阶段 4 可替换成真正的 navigator/root page/detail page。
func setNavigationContentView(_ view: UIView) {
    guard currentNavigationContentView !== view else {
        return
    }

    NSLayoutConstraint.deactivate(hostedContentConstraints)
    hostedContentConstraints = []
    currentNavigationContentView?.removeFromSuperview()

    if view.superview != nil {
        view.removeFromSuperview()
    }

    view.translatesAutoresizingMaskIntoConstraints = false
    navigatorHostView.addSubview(view)
    hostedContentConstraints = [
        view.leadingAnchor.constraint(equalTo: navigatorHostView.leadingAnchor),
        view.trailingAnchor.constraint(equalTo: navigatorHostView.trailingAnchor),
        view.topAnchor.constraint(equalTo: navigatorHostView.topAnchor),
        view.bottomAnchor.constraint(equalTo: navigatorHostView.bottomAnchor)
    ]
    NSLayoutConstraint.activate(hostedContentConstraints)
    currentNavigationContentView = view
}

private func updateNavigationHeaderState() {
    titleLabel.text = navigationTitle
    titleLabel.isHidden = navigationTitle.isEmpty
    backButton.isHidden = !showsBackButton
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数名: 属性区 + configureView()
// 功能说明: macOS container 做了与 iOS 对称的壳层重构，
// 保证双平台的 card header 和 navigator host 结构保持一致。
var navigationTitle: String = SettingsRouteID.root.fallbackTitle {
    didSet {
        updateNavigationHeaderState()
    }
}

var showsBackButton = false {
    didSet {
        updateNavigationHeaderState()
    }
}

var onBackRequest: (() -> Void)?

private let navigatorHostView = NSView()
private weak var currentNavigationContentView: NSView?
private var hostedContentConstraints: [NSLayoutConstraint] = []

private lazy var backButton: NSButton = {
    let button = NSButton()
    button.isBordered = false
    button.image = NSImage(
        systemSymbolName: "chevron.left",
        accessibilityDescription: "Back"
    )
    button.identifier = NSUserInterfaceItemIdentifier("settings-container-back-button")
    button.toolTip = "Back"
    button.action = #selector(handleBackButtonTap)
    button.isHidden = true
    return button
}()

private lazy var titleLabel: NSTextField = {
    let label = NSTextField(labelWithString: SettingsRouteID.root.fallbackTitle)
    label.font = NSFont.preferredFont(forTextStyle: .headline)
    label.alignment = .center
    label.identifier = NSUserInterfaceItemIdentifier("settings-container-title")
    return label
}()
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数名: setNavigationContentView(_:) / updateNavigationHeaderState()
// 功能说明: macOS container 同样新增统一内容宿主切换能力，
// 阶段 3 先继续把 macOSSettingsPanelView 挂进去，行为上不提前引入 navigator。
func setNavigationContentView(_ view: NSView) {
    guard currentNavigationContentView !== view else {
        return
    }

    NSLayoutConstraint.deactivate(hostedContentConstraints)
    hostedContentConstraints = []
    currentNavigationContentView?.removeFromSuperview()

    if view.superview != nil {
        view.removeFromSuperview()
    }

    view.translatesAutoresizingMaskIntoConstraints = false
    navigatorHostView.addSubview(view)
    hostedContentConstraints = [
        view.leadingAnchor.constraint(equalTo: navigatorHostView.leadingAnchor),
        view.trailingAnchor.constraint(equalTo: navigatorHostView.trailingAnchor),
        view.topAnchor.constraint(equalTo: navigatorHostView.topAnchor),
        view.bottomAnchor.constraint(equalTo: navigatorHostView.bottomAnchor)
    ]
    NSLayoutConstraint.activate(hostedContentConstraints)
    currentNavigationContentView = view
}

private func updateNavigationHeaderState() {
    titleLabel.stringValue = navigationTitle
    titleLabel.isHidden = navigationTitle.isEmpty
    backButton.isHidden = !showsBackButton
}
```

## 本次明确没有改动的部分

- 没有修改 `SettingsNavigationModel`
- 没有修改 `SettingsNavigationSnapshotBuilder`
- 没有修改 `SettingsNavigationValidationRunner`
- 没有实现 `iOSSettingsNavigatorView` / `macOSSettingsNavigatorView`
- 没有修改 `iOSViewController` / `macOSViewController`
- 没有真正启用 root->section 导航逻辑

## 验证

```bash
// 文件路径: NoteMaster_Ver_1.xcodeproj
// 函数名/场景: 阶段3 macOS 工程级验证
// 功能说明: 构建 macOS 目标，确认 container 壳层改造后的 NSView 约束和 API 使用都能通过编译。
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" \
-scheme "NoteMaster_Ver_1" \
-configuration Debug \
-destination "generic/platform=macOS" \
CODE_SIGNING_ALLOWED=NO build

// 结果: Exit code 0
```

```bash
// 文件路径: NoteMaster_Ver_1.xcodeproj
// 函数名/场景: 阶段3 iOS 工程级验证
// 功能说明: 构建 iOS 目标，确认 container 壳层改造后的 UIView 约束和 API 使用都能通过编译。
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" \
-scheme "NoteMaster_Ver_1" \
-configuration Debug \
-destination "generic/platform=iOS" \
CODE_SIGNING_ALLOWED=NO build

// 结果: Exit code 0
```

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数名/场景: IDE 诊断检查
// 功能说明: 检查阶段3双平台 container 修改后的静态诊断状态。
ReadLints 结果：No linter errors found.
```

## 结论

- 阶段 3 完成后，双平台 settings card 的“壳层能力”已经就绪：header 统一、内容宿主独立、关闭行为保持原样。
- 这一步没有提前引入 navigator 行为，而是把后续阶段 4 真正需要替换的接缝先整理干净。
- 现在 `iOS/macOS` 都已经具备了“在不改 card 外观的前提下，把内容区切换成 navigator”的结构前置条件。

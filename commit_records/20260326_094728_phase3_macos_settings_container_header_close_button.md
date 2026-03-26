# 20260326_094728_phase3_macos_settings_container_header_close_button

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_094728`
- 记录范围：`设置关闭按钮` 方案3 的阶段3实施
- 本次目标：在 macOS 端对称完成 settings card 的 `headerView + scrollView` 两段式改造，并在 card 右上角加入圆形关闭按钮
- 根因结论：当前 `macOSSettingsContainerView` 与阶段2之前的 iOS 一样，`cardView` 内只有 `scrollView`，而 `scrollView.top` 直接贴 `cardView.top + inset`。如果在这种结构上直接叠加关闭按钮，按钮会与卡片顶部设置内容争夺同一块布局区域，无法从容器结构上保证首组 row 不被遮挡。
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`

## 本次完成的修改

1. 在 `macOSSettingsContainerView` 中新增 `headerView` 与圆形 `closeButton`。
2. 将 `cardView` 的内部结构从“只有 `scrollView`”改为“`headerView` 在上，`scrollView` 在下”。
3. 将 `scrollView.topAnchor` 从 `cardView.topAnchor + Style.cardContentInset` 改为 `headerView.bottomAnchor + Style.headerBottomSpacing`。
4. 新增 `handleCloseButtonTap()`，并让它复用阶段1已经收口好的 `requestDismiss()`。
5. 补充 `headerHeight`、`headerBottomSpacing`、`closeButtonSize` 三个 macOS 容器样式常量。

## 修改 1：macOS settings container 新增 header 和右上角关闭按钮

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: 属性定义
// 功能说明: 修改前 macOS settings container 的 card 里只有 scrollView，没有独立 header 或右上角关闭按钮；
// 因此卡片顶部空间完全被设置内容占用。
private let backdropView = DismissBackgroundView()
private let cardView = NSView()
private let scrollView = NSScrollView()
private let contentView = NSView()
private let settingsPanelView: macOSSettingsPanelView
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: 属性定义
// 功能说明: 修改后 macOS settings container 为 card 增加了专用 headerView 和圆形 closeButton，
// 关闭按钮作为 card 壳层控件存在，不进入 shared settings 内容模型。
private let backdropView = DismissBackgroundView()
private let cardView = NSView()
private let headerView = NSView()
private let scrollView = NSScrollView()
private let contentView = NSView()
private let settingsPanelView: macOSSettingsPanelView
private lazy var closeButton: NSButton = {
    let button = NSButton()
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.imagePosition = .imageOnly
    button.image = NSImage(
        systemSymbolName: "xmark",
        accessibilityDescription: "Close settings"
    )
    button.imageScaling = .scaleProportionallyDown
    button.contentTintColor = .white
    button.identifier = NSUserInterfaceItemIdentifier("settings-container-close-button")
    button.toolTip = "Close settings"
    button.target = self
    button.action = #selector(handleCloseButtonTap)
    button.wantsLayer = true
    button.layer?.cornerRadius = Style.closeButtonSize / 2
    button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
    button.layer?.shadowColor = NSColor.black.cgColor
    button.layer?.shadowOpacity = 0.12
    button.layer?.shadowRadius = 12
    button.layer?.shadowOffset = CGSize(width: 0, height: -4)
    return button
}()
```

## 修改 2：card 内部布局从“scroll 贴顶”改为“header 在上、scroll 在下”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: configureView()
// 功能说明: 修改前 cardView 内只有 scrollView；
// scrollView.top 直接贴 card 顶部 inset，因此顶部没有为关闭按钮预留独立布局层。
addSubview(backdropView)
addSubview(cardView)
cardView.addSubview(scrollView)
contentView.addSubview(settingsPanelView)

NSLayoutConstraint.activate([
    // ... cardView constraints ...
    scrollView.leadingAnchor.constraint(
        equalTo: cardView.leadingAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.trailingAnchor.constraint(
        equalTo: cardView.trailingAnchor,
        constant: -Style.cardContentInset
    ),
    scrollView.topAnchor.constraint(
        equalTo: cardView.topAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.bottomAnchor.constraint(
        equalTo: cardView.bottomAnchor,
        constant: -Style.cardContentInset
    )
    // ... remaining constraints ...
])
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: configureView()
// 功能说明: 修改后 cardView 先放 headerView，再把 closeButton 放进 header；
// scrollView.top 改成贴 headerView.bottom，这样关闭按钮不会压住顶部设置内容。
headerView.translatesAutoresizingMaskIntoConstraints = false
headerView.identifier = NSUserInterfaceItemIdentifier("settings-container-header")
closeButton.translatesAutoresizingMaskIntoConstraints = false

addSubview(backdropView)
addSubview(cardView)
cardView.addSubview(headerView)
headerView.addSubview(closeButton)
cardView.addSubview(scrollView)
contentView.addSubview(settingsPanelView)

NSLayoutConstraint.activate([
    // ... cardView constraints ...
    headerView.leadingAnchor.constraint(
        equalTo: cardView.leadingAnchor,
        constant: Style.cardContentInset
    ),
    headerView.trailingAnchor.constraint(
        equalTo: cardView.trailingAnchor,
        constant: -Style.cardContentInset
    ),
    headerView.topAnchor.constraint(
        equalTo: cardView.topAnchor,
        constant: Style.cardContentInset
    ),
    headerView.heightAnchor.constraint(equalToConstant: Style.headerHeight),

    closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
    closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
    closeButton.widthAnchor.constraint(equalToConstant: Style.closeButtonSize),
    closeButton.heightAnchor.constraint(equalToConstant: Style.closeButtonSize),

    scrollView.leadingAnchor.constraint(
        equalTo: cardView.leadingAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.trailingAnchor.constraint(
        equalTo: cardView.trailingAnchor,
        constant: -Style.cardContentInset
    ),
    scrollView.topAnchor.constraint(
        equalTo: headerView.bottomAnchor,
        constant: Style.headerBottomSpacing
    ),
    scrollView.bottomAnchor.constraint(
        equalTo: cardView.bottomAnchor,
        constant: -Style.cardContentInset
    )
    // ... remaining constraints ...
])
```

## 修改 3：关闭按钮复用阶段1的统一 dismiss 链路

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: configureView() 中的 backdropView.onClick
// 功能说明: 修改前只有 backdrop 点击会走 requestDismiss()；
// card 自身还没有独立的关闭按钮入口。
private func configureView() {
    // ... other setup ...
    backdropView.onClick = { [weak self] in
        self?.requestDismiss()
    }
    // ... constraints ...
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: configureView() 中的 backdropView.onClick / handleCloseButtonTap()
// 功能说明: 修改后关闭按钮和 backdrop 点击都统一复用 requestDismiss()，
// 避免在 macOS 容器里分叉出第二条关闭链路。
private func configureView() {
    // ... other setup ...
    backdropView.onClick = { [weak self] in
        self?.requestDismiss()
    }
    // ... constraints ...
}

@objc
private func handleCloseButtonTap() {
    requestDismiss()
}
```

## 修改 4：补充 header / close button 的样式常量

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: Style
// 功能说明: 修改前 Style 里只有 card 与 backdrop 相关常量，还没有 header 和 close button 的尺寸定义。
private enum Style {
    static let screenInset: CGFloat = 16
    static let preferredCardWidth: CGFloat = 360
    static let maximumScrollHeight: CGFloat = 520
    static let cardContentInset: CGFloat = 16
    static let cardCornerRadius: CGFloat = 22
    static let backdropOpacity: CGFloat = 0.28
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: Style
// 功能说明: 修改后补充 headerHeight、headerBottomSpacing 和 closeButtonSize，
// 让 header 区与右上角关闭按钮的几何语义不再散落在 configureView() 的魔法数字里。
private enum Style {
    static let screenInset: CGFloat = 16
    static let preferredCardWidth: CGFloat = 360
    static let maximumScrollHeight: CGFloat = 520
    static let cardContentInset: CGFloat = 16
    static let headerHeight: CGFloat = 40
    static let headerBottomSpacing: CGFloat = 8
    static let closeButtonSize: CGFloat = 40
    static let cardCornerRadius: CGFloat = 22
    static let backdropOpacity: CGFloat = 0.28
}
```

## 修改结果说明

- 阶段3只覆盖 macOS 平台容器层：
  - card 右上角已经具备独立关闭按钮；
  - settings 内容顶部已经从布局上让位给 header 区；
  - 关闭按钮与 backdrop 点击共用同一条 dismiss 链路。
- 这一步仍然没有修改：
  - 页面左上角齿轮按钮的隐藏/恢复；
  - iOS / macOS controller 的页面入口按钮显隐同步；
  - shared settings model / snapshot / panel content 结构。
- 因此当前阶段的预期状态是：
  - macOS 打开 settings 后，card 内右上角已有 close button；
  - 页面左上角齿轮按钮还没有“真隐藏”，只是继续被 settings overlay 盖住。

## 验证结果

1. `ReadLints` 检查 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`，无新增问题。
2. 执行以下静态校验通过：
   - `swiftc -typecheck NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift NoteMaster_Ver_1/Shared/Controls/*.swift NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift`
3. 本轮还未做运行态手工联调；真正需要在 App 内继续验证的点包括：
   - close button 点击是否与 backdrop 点击一样稳定关闭；
   - header 区在窗口较窄或较矮时是否压缩异常；
   - 顶部第一组 settings row 是否完全不被 close button 遮挡。

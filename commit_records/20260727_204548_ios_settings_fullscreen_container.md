# 20260727_204548_ios_settings_fullscreen_container

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260727_204548`
- 记录范围：iOS setting UIView 从居中小卡片调整为安全区内近乎铺满的浮层卡片
- 本次目标：让 setting 的 `UIView` 高度和宽度几乎铺满可用空间，同时与屏幕边框保留固定间隙
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift`
- 未修改范围：没有修改 macOS 的 `NSView` setting 面板，没有提交 commit

## 本次完成的修改

1. 移除 iOS setting 卡片原来的 `360pt` 偏好宽度和 `520pt` 最大滚动高度限制。
2. 将 `cardView` 从“居中且不超过安全区”改为“贴住 safe area 四边，并保留 `16pt` 间隙”。
3. 让滚动内容高度至少等于 scroll viewport 高度，使导航页/表单页可以跟随大卡片撑开。
4. 放开 navigator、panel、index page 的垂直 content hugging，避免外层拉高时产生自适应高度冲突。
5. 将表单/索引内部 stack 的底部约束改为 `lessThanOrEqualTo`，保证背景可以铺满，但按钮和表单行保持自然高度，不被强行纵向拉伸。

## 修改 1：设置容器从小卡片改为安全区内近乎铺满

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: iOSSettingsContainerView.configureView()
// 功能说明: 修改前 cardView 使用居中布局、360pt 偏好宽度和 520pt 最大滚动高度，因此 setting 面板表现为屏幕中央的小卡片。
let safeArea = safeAreaLayoutGuide
let preferredWidthConstraint = cardView.widthAnchor.constraint(
    equalToConstant: Style.preferredCardWidth
)
preferredWidthConstraint.priority = .defaultHigh
let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
    equalTo: navigatorHostView.heightAnchor
)
scrollHeightMatchesContentConstraint.priority = .defaultHigh

NSLayoutConstraint.activate([
    cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
    cardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
    cardView.leadingAnchor.constraint(
        greaterThanOrEqualTo: safeArea.leadingAnchor,
        constant: Style.screenInset
    ),
    cardView.trailingAnchor.constraint(
        lessThanOrEqualTo: safeArea.trailingAnchor,
        constant: -Style.screenInset
    ),
    cardView.topAnchor.constraint(
        greaterThanOrEqualTo: safeArea.topAnchor,
        constant: Style.screenInset
    ),
    cardView.bottomAnchor.constraint(
        lessThanOrEqualTo: safeArea.bottomAnchor,
        constant: -Style.screenInset
    ),
    preferredWidthConstraint,
    scrollHeightMatchesContentConstraint,
    scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Style.maximumScrollHeight)
])
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: iOSSettingsContainerView.configureView()
// 功能说明: 修改后 cardView 直接约束到 safe area 四边，保留 Style.screenInset 间隙；scroll 内容至少等于 viewport 高度，支持大尺寸 setting 卡片。
let safeArea = safeAreaLayoutGuide

NSLayoutConstraint.activate([
    cardView.leadingAnchor.constraint(
        equalTo: safeArea.leadingAnchor,
        constant: Style.screenInset
    ),
    cardView.trailingAnchor.constraint(
        equalTo: safeArea.trailingAnchor,
        constant: -Style.screenInset
    ),
    cardView.topAnchor.constraint(
        equalTo: safeArea.topAnchor,
        constant: Style.screenInset
    ),
    cardView.bottomAnchor.constraint(
        equalTo: safeArea.bottomAnchor,
        constant: -Style.screenInset
    ),

    contentView.heightAnchor.constraint(
        greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor
    )
])
```

## 修改 2：移除小卡片尺寸常量

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: Style
// 功能说明: 修改前 preferredCardWidth 和 maximumScrollHeight 将 setting 限制为固定宽度的小卡片和最多 520pt 高的滚动区域。
private enum Style {
    static let screenInset: CGFloat = 16
    static let preferredCardWidth: CGFloat = 360
    static let maximumScrollHeight: CGFloat = 520
    static let cardContentInset: CGFloat = 16
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: Style
// 功能说明: 修改后只保留屏幕边距和卡片内部边距；卡片尺寸由 safe area 四边约束自然决定。
private enum Style {
    static let screenInset: CGFloat = 16
    static let cardContentInset: CGFloat = 16
}
```

## 修改 3：外层导航宿主允许被大卡片拉高

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: iOSSettingsContainerView.configureView()
// 功能说明: 修改前 navigatorHostView 垂直 hugging 为 required，更倾向于按内部内容高度收缩，不适合被全高卡片拉伸。
navigatorHostView.setContentHuggingPriority(.required, for: .vertical)
navigatorHostView.setContentCompressionResistancePriority(.required, for: .vertical)
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: iOSSettingsContainerView.configureView()
// 功能说明: 修改后 navigatorHostView 可以跟随卡片可用高度扩展，同时仍保留 required compression resistance 防止被压扁。
navigatorHostView.setContentHuggingPriority(.defaultLow, for: .vertical)
navigatorHostView.setContentCompressionResistancePriority(.required, for: .vertical)
```

## 修改 4：导航视图允许承载全高页面

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift
// 函数/成员: iOSSettingsNavigatorView.configureView()
// 功能说明: 修改前 navigator 自身也 required 垂直 hugging，会继续按照当前 page 的 intrinsicContentSize 收缩。
private func configureView() {
    accessibilityIdentifier = SettingsNavigationAccessibility.navigatorIdentifier
    clipsToBounds = true
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift
// 函数/成员: iOSSettingsNavigatorView.configureView()
// 功能说明: 修改后 navigator 可被外层拉高，pageHostView 继续负责装载 root/form 页面并保持 push/pop 过渡。
private func configureView() {
    accessibilityIdentifier = SettingsNavigationAccessibility.navigatorIdentifier
    clipsToBounds = true
    setContentHuggingPriority(.defaultLow, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
}
```

## 修改 5：表单页背景铺满，但表单行不被拉伸

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/成员: iOSSettingsPanelView.configureView()
// 功能说明: 修改前 panel required 垂直 hugging，并且 sectionsStackView 底部等于 layoutMarginsGuide.bottom；当外层变高时，内部 stack 会被迫参与纵向拉伸。
setContentHuggingPriority(.required, for: .vertical)
setContentCompressionResistancePriority(.required, for: .vertical)

NSLayoutConstraint.activate([
    sectionsStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
    sectionsStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
    sectionsStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
    sectionsStackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
])
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数/成员: iOSSettingsPanelView.configureView()
// 功能说明: 修改后 panel 背景可填满外层高度，sectionsStackView 只要求不超过底部，表单内容保持自然高度从顶部排列。
setContentHuggingPriority(.defaultLow, for: .vertical)
setContentCompressionResistancePriority(.required, for: .vertical)

NSLayoutConstraint.activate([
    sectionsStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
    sectionsStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
    sectionsStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
    sectionsStackView.bottomAnchor.constraint(
        lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor
    )
])
```

## 修改 6：索引页背景铺满，但分组按钮不被拉伸

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift
// 函数/成员: iOSSettingsIndexPageView.configureView()
// 功能说明: 修改前 index page required 垂直 hugging，并且 routesStackView 底部等于 layoutMarginsGuide.bottom；大卡片场景下按钮可能被迫纵向分配额外空间。
setContentHuggingPriority(.required, for: .vertical)
setContentCompressionResistancePriority(.required, for: .vertical)

NSLayoutConstraint.activate([
    routesStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
    routesStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
    routesStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
    routesStackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
])
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift
// 函数/成员: iOSSettingsIndexPageView.configureView()
// 功能说明: 修改后 index page 背景可以填满外层高度，routesStackView 保持自然按钮高度并只限制不超过底部。
setContentHuggingPriority(.defaultLow, for: .vertical)
setContentCompressionResistancePriority(.required, for: .vertical)

NSLayoutConstraint.activate([
    routesStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
    routesStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
    routesStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
    routesStackView.bottomAnchor.constraint(
        lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor
    )
])
```

## 验证

1. `ReadLints` 检查以下文件，无 linter errors：
   - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
   - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift`
   - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
   - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift`
2. 执行 iOS Simulator 构建通过：

```shell
# 文件路径: 命令行
# 函数/成员: xcodebuild
# 功能说明: 验证本次 iOS setting UIView 布局调整没有引入编译错误。
xcodebuild -scheme "NoteMaster_Ver_1" -project "NoteMaster_Ver_1.xcodeproj" -destination "generic/platform=iOS Simulator" build
```

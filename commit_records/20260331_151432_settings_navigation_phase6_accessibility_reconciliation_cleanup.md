# 20260331_151432_settings_navigation_phase6_accessibility_reconciliation_cleanup

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_151432`
- 记录范围：实施“卡片内设置导航改造”的阶段 6，完成可访问性、route reconciliation 收口与结构清理
- 修改性质：统一导航相关 accessibility 命名，补足状态驱动的回退转场语义，并把 validation/manual checklist 收敛到可长期维护的结构
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationAccessibility.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`

## 修改前

- 导航相关无障碍标识仍然散落在各个平台视图里，命名混用 `settings-container-*`、`settings-index-route-*`、`settings-navigator`，没有统一入口。
- `NavigatorView.applyModelUpdate()` 在共享 model 发生变化时只会静态替换当前页，虽然 `reconciledPath` 已经能算出回退路径，但 UI 不会根据“路径变浅”体现出 pop 语义。
- 当前页宿主层没有 route 级 page identifier，手工回归和 UI 自动化都不容易直接定位“当前落在哪个页面”。
- validation 还没有约束 `settings-navigation-*` 这一批命名，也没有把 close/back/deep route/动态失效回退这些真正的回归动作收进 checklist。
- `*SettingsPanelView` 虽然实际已经只被 navigator 当作表单页渲染器使用，但文件本身还没有把这个边界说清楚。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数名: backButton / titleLabel / updateNavigationHeaderState()
// 功能说明: 修改前 iOS container 的返回与标题标识仍沿用 container 级命名；
// title 也不会同步 accessibilityLabel。
button.accessibilityIdentifier = "settings-container-back-button"
button.accessibilityLabel = "Back"

label.accessibilityIdentifier = "settings-container-title"
label.accessibilityTraits = [.header]

private func updateNavigationHeaderState() {
    titleLabel.text = navigationTitle
    titleLabel.isHidden = navigationTitle.isEmpty
    backButton.isHidden = !showsBackButton
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift
// 函数名: RouteButton.apply(routeItem:)
// 功能说明: 修改前 iOS route item 直接拼接 settings-index-route-*，
// 这套命名没有与 navigator/title/back 形成统一前缀。
func apply(routeItem: SettingsRouteItem) {
    route = routeItem.route
    accessibilityIdentifier = "settings-index-route-\(routeItem.route.accessibilityIdentifierComponent)"
    accessibilityLabel = routeItem.subtitle.map {
        "\(routeItem.title), \($0)"
    } ?? routeItem.title
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift
// 函数名: configureView() / applyModelUpdate() / installCurrentPageView(_:)
// 功能说明: 修改前 navigator 虽然会按 reconciledPath 更新 routeStack，
// 但总是 none + animated false，也不会给当前页宿主层打 route 级 page identifier。
private func configureView() {
    accessibilityIdentifier = "settings-navigator"
}

private func applyModelUpdate() {
    routeStack = model.reconciledPath(routeStack)
    replaceCurrentPage(
        with: makePageView(for: routeStack.last ?? model.rootRoute),
        transitionDirection: .none,
        animated: false
    )
}

private func installCurrentPageView(_ pageView: UIView) {
    currentPageView = pageView
    invalidateIntrinsicContentSize()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改前 validation 还没有收录导航无障碍命名稳定性，
// 手工回归清单也主要围绕 root 顺序、section 内容和 layout route 消失恢复。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "root_route_items_match_panel_sections",
            validate: validateRootRouteItemsMatchPanelSections
        ),
        SettingsNavigationValidationFixture(
            name: "reserved_route_titles_remain_stable",
            validate: validateReservedRouteTitlesRemainStable
        )
    ]
}

static func manualChecklist(
    for platform: SettingsNavigationValidationPlatform
) -> [String] {
    [
        "在 \(platform.displayName) 上确认 settings root 页展示顺序与共享层 section 顺序一致，不会因平台实现自行重排。",
        "确认从 root 进入任一 section detail page 后，标题与内容都与该 section 对齐，没有串页或丢行。",
        "确认切换到 horizontal 指板布局时，Layout route 会消失；切回 vertical 后 Layout route 会恢复。",
        "确认当当前深层 route 因状态变化失效时，卡片内导航会回到最近仍有效的父级，无法保留时兜底 root。"
    ]
}
```

## 修改后

- 新增 `SettingsNavigationAccessibility.swift`，统一声明 navigator、title、back button、route item、page host 的命名规则。
- iOS/macOS 两端的 header 返回按钮、标题 label 都切到了共享导航命名，并补齐更准确的 accessibility label。
- iOS/macOS 的 route item 标识统一改为 `settings-navigation-route-*`，当前页宿主层统一改为 `settings-navigation-page-*`。
- `NavigatorView.applyModelUpdate()` 开始比较更新前后的路径深度；当状态变化导致当前路径从深层页回退到父页时，会自动走一次 pop 语义的页面切换，而不是静态硬切。
- validation 新增导航无障碍标识稳定性夹具，并把手工回归清单扩充到 close / back / 深层页 / 动态失效回退 / 双端动画布局一致性。
- `iOSSettingsPanelView` / `macOSSettingsPanelView` 增加角色注释，明确它们现在只承担“表单页渲染器”职责。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationAccessibility.swift
// 函数名: SettingsNavigationAccessibility.routeItemIdentifier(for:) / pageIdentifier(for:)
// 功能说明: 新增共享导航无障碍命名入口；
// 所有平台视图统一从这里取 navigator/title/back/route/page 标识。
enum SettingsNavigationAccessibility {
    static let navigatorIdentifier = "settings-navigation"
    static let titleIdentifier = "settings-navigation-title"
    static let backButtonIdentifier = "settings-navigation-back-button"

    static func routeItemIdentifier(
        for route: SettingsRouteID
    ) -> String {
        "settings-navigation-route-\(route.accessibilityIdentifierComponent)"
    }

    static func pageIdentifier(
        for route: SettingsRouteID
    ) -> String {
        "settings-navigation-page-\(route.accessibilityIdentifierComponent)"
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数名: backButton / titleLabel / updateNavigationHeaderState()
// 功能说明: iOS header 现在切到共享导航标识；
// 同时把标题文本同步到 accessibilityLabel，避免页面切换后标题朗读滞后。
private lazy var backButton: UIButton = {
    let button = UIButton(type: .system)
    button.accessibilityIdentifier = SettingsNavigationAccessibility.backButtonIdentifier
    button.accessibilityLabel = "Back to previous settings page"
    return button
}()

private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.isAccessibilityElement = true
    label.accessibilityIdentifier = SettingsNavigationAccessibility.titleIdentifier
    label.accessibilityTraits = [.header]
    return label
}()

private func updateNavigationHeaderState() {
    titleLabel.text = navigationTitle
    titleLabel.accessibilityLabel = navigationTitle
    titleLabel.isHidden = navigationTitle.isEmpty
    backButton.isHidden = !showsBackButton
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数名: backButton / titleLabel / updateNavigationHeaderState()
// 功能说明: macOS header 与 iOS 对称切到共享导航标识；
// tooltip 与 accessibilityLabel 也统一收口。
private lazy var backButton: NSButton = {
    let button = NSButton()
    button.identifier = NSUserInterfaceItemIdentifier(
        SettingsNavigationAccessibility.backButtonIdentifier
    )
    button.setAccessibilityLabel("Back to previous settings page")
    button.toolTip = "Back to previous settings page"
    return button
}()

private lazy var titleLabel: NSTextField = {
    let label = NSTextField(labelWithString: SettingsRouteID.root.fallbackTitle)
    label.identifier = NSUserInterfaceItemIdentifier(
        SettingsNavigationAccessibility.titleIdentifier
    )
    label.setAccessibilityLabel(SettingsRouteID.root.fallbackTitle)
    return label
}()

private func updateNavigationHeaderState() {
    titleLabel.stringValue = navigationTitle
    titleLabel.setAccessibilityLabel(navigationTitle)
    titleLabel.isHidden = navigationTitle.isEmpty
    backButton.isHidden = !showsBackButton
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift
// 函数名: RouteButton.apply(routeItem:)
// 功能说明: iOS route item 改为使用共享 route identifier 规则，
// 后续 UI 测试只需要认 settings-navigation-route-* 这一套前缀。
func apply(routeItem: SettingsRouteItem) {
    route = routeItem.route
    accessibilityIdentifier = SettingsNavigationAccessibility.routeItemIdentifier(
        for: routeItem.route
    )
    accessibilityLabel = routeItem.subtitle.map {
        "\(routeItem.title), \($0)"
    } ?? routeItem.title
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift
// 函数名: RouteButton.apply(routeItem:)
// 功能说明: macOS route item 同样切到共享 route identifier，
// 并补充了 route title 的 accessibilityLabel。
func apply(routeItem: SettingsRouteItem) {
    route = routeItem.route
    identifier = NSUserInterfaceItemIdentifier(
        SettingsNavigationAccessibility.routeItemIdentifier(
            for: routeItem.route
        )
    )
    setAccessibilityLabel(routeItem.title)
    toolTip = routeItem.subtitle.map {
        "\(routeItem.title) - \($0)"
    } ?? routeItem.title
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift
// 函数名: configureView() / applyModelUpdate() / installCurrentPageView(_:) / transitionDirection(from:to:)
// 功能说明: iOS navigator 现在会根据路径深度变化决定 push/pop/none，
// 并给当前页宿主层打上 page identifier，方便回归和自动化定位。
private func configureView() {
    accessibilityIdentifier = SettingsNavigationAccessibility.navigatorIdentifier
}

private func applyModelUpdate() {
    let previousPath = routeStack
    let reconciledPath = model.reconciledPath(routeStack)
    let transitionDirection = transitionDirection(
        from: previousPath,
        to: reconciledPath
    )
    let didCurrentRouteChange = previousPath.last != reconciledPath.last

    routeStack = reconciledPath
    replaceCurrentPage(
        with: makePageView(for: routeStack.last ?? model.rootRoute),
        transitionDirection: transitionDirection,
        animated: didCurrentRouteChange && transitionDirection != .none
    )
}

private func installCurrentPageView(_ pageView: UIView) {
    currentPageView = pageView
    pageHostView.accessibilityIdentifier = SettingsNavigationAccessibility.pageIdentifier(
        for: routeStack.last ?? model.rootRoute
    )
}

private func transitionDirection(
    from previousPath: [SettingsRouteID],
    to nextPath: [SettingsRouteID]
) -> TransitionDirection {
    if nextPath.count < previousPath.count {
        return .pop
    }
    if nextPath.count > previousPath.count {
        return .push
    }
    return .none
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift
// 函数名: configureView() / applyModelUpdate() / installCurrentPageView(_:) / transitionDirection(from:to:)
// 功能说明: macOS navigator 同步补齐 shared identifier 与路径深度驱动的回退转场；
// 这样深层页失效时不会无动画硬切。
private func configureView() {
    identifier = NSUserInterfaceItemIdentifier(
        SettingsNavigationAccessibility.navigatorIdentifier
    )
}

private func applyModelUpdate() {
    let previousPath = routeStack
    let reconciledPath = model.reconciledPath(routeStack)
    let transitionDirection = transitionDirection(
        from: previousPath,
        to: reconciledPath
    )
    let didCurrentRouteChange = previousPath.last != reconciledPath.last

    routeStack = reconciledPath
    replaceCurrentPage(
        with: makePageView(for: routeStack.last ?? model.rootRoute),
        transitionDirection: transitionDirection,
        animated: didCurrentRouteChange && transitionDirection != .none
    )
}

private func installCurrentPageView(_ pageView: NSView) {
    currentPageView = pageView
    pageHostView.identifier = NSUserInterfaceItemIdentifier(
        SettingsNavigationAccessibility.pageIdentifier(
            for: routeStack.last ?? model.rootRoute
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名: 文件头部职责注释
// 功能说明: 明确 iOS SettingsPanelView 在新架构中的边界，
// 避免后续又把它扩成“容器 + 导航 + 表单”三种职责混合体。
#if os(iOS)
import Foundation
import UIKit

// 在 card 内导航落地后，这个 view 只承担“单页表单渲染器”职责；
// navigator 负责路由、标题、返回与页面切换。
final class iOSSettingsPanelView: UIView {
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures() / manualChecklist(for:) / validateReservedAccessibilityIdentifiersRemainStable()
// 功能说明: validation 新增导航 accessibility 命名稳定性检查，
// 并把手工回归清单扩到 close/back/deep route/动态失效回退/双端动画布局一致性。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "reserved_route_titles_remain_stable",
            validate: validateReservedRouteTitlesRemainStable
        ),
        SettingsNavigationValidationFixture(
            name: "reserved_accessibility_identifiers_remain_stable",
            validate: validateReservedAccessibilityIdentifiersRemainStable
        )
    ]
}

static func manualChecklist(
    for platform: SettingsNavigationValidationPlatform
) -> [String] {
    [
        "在 \(platform.displayName) 上确认 close 永远关闭整个 settings card，而不是只关闭当前子页。",
        "确认在 root 页隐藏返回按钮；进入 section 或更深页面后显示返回按钮，点击后只回退卡片内一层。",
        "确认 root -> Trainer / Staff / Piano 的 section page 可以继续进入深层子页，标题与内容和共享 builder 生成的 route 一致。",
        "确认当停留在 Trainer Position Filter 深层页时切换 exercise mode，卡片会自动退回最近仍有效的 Trainer 父页，而不会停留在失效子页。",
        "确认切换到 horizontal 指板布局时 Layout route 会消失；切回 vertical 后 Layout route 会恢复。",
        "确认 iOS / macOS 上的标题、返回、关闭按钮布局与转场方向一致，没有双层导航条或页面闪跳。"
    ]
}

static func validateReservedAccessibilityIdentifiersRemainStable()
    -> [SettingsNavigationValidationIssue] {
    if SettingsNavigationAccessibility.navigatorIdentifier != "settings-navigation" {
        issues.append(issue(fixtureName, "navigatorIdentifier 应为 settings-navigation。"))
    }
    if SettingsNavigationAccessibility.titleIdentifier != "settings-navigation-title" {
        issues.append(issue(fixtureName, "titleIdentifier 应为 settings-navigation-title。"))
    }
    if SettingsNavigationAccessibility.backButtonIdentifier != "settings-navigation-back-button" {
        issues.append(issue(fixtureName, "backButtonIdentifier 应为 settings-navigation-back-button。"))
    }
}
```

## 结果归纳

- 阶段 6 完成后，导航相关 accessibility 命名已经从平台分散字符串收敛为共享常量，iOS/macOS 的 back/title/route/page 标识规则保持一致。
- 共享 `reconciledPath` 现在不只是“算对路径”，平台 navigator 也会基于路径深度变化表现出相应的回退转场语义。
- validation 已经把自动化契约和手工回归清单一起补齐，后续继续改导航时，可以更早发现命名漂移、深层页失效回退错误或双端交互不一致。
- `*SettingsPanelView` 的职责边界已经写明，后续即使继续演进 settings 导航，也不会再把表单渲染器与导航容器混成一个对象。

## 验证结果

- `ReadLints`：本次涉及文件无新增 linter 报错
- iOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS" build`
- macOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`
- 当前记录覆盖的是阶段 6 的代码收口与验证收口；手工点击回归清单已经写入 validation report，但尚未逐项执行

# 20260331_145035_settings_navigation_phase4_platform_navigator_shells_and_controller_integration

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_145035`
- 记录范围：实施“卡片内设置导航改造”的阶段 4，完成 `platform-navigator-shells` 与 `controller-integration`
- 修改性质：在不改动 `SettingsPanelEvent` 回写链的前提下，把 settings card 从“单页表单壳”推进为“卡片内 root -> section navigator”
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

- 共享层已经有 `SettingsNavigationModel`，但它只描述 route/page 数据，没有提供 header 展示态，也没有 route 对应的统一 accessibility 标识片段。
- 双平台 container 虽然在阶段 3 已经有了 `navigatorHostView`，但内部仍然挂的是原来的 `SettingsPanelView`，并没有真正的 `NavigatorView` 或 `IndexPageView`。
- 双平台 controller 仍然通过 `SettingsPanelSnapshotBuilder.makeModel(...)` 构造单页表单模型，settings card 的输入还没有切到 `SettingsNavigationSnapshotBuilder`。
- 因此阶段 3 结束时，视觉壳层已准备好，但 card 内仍然不是一个真正的页面导航结构。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: SettingsRouteID / SettingsPageModel / SettingsNavigationModel
// 功能说明: 修改前共享导航模型只负责 route/page 投影；
// 还没有 header 展示态，也没有给平台按钮复用的 route accessibility 片段。
enum SettingsRouteID: Equatable, Hashable, Sendable {
    case root
    case section(SettingsSectionID)
    case trainerPositionFilter
    case pianoAdvanced

    var fallbackTitle: String {
        switch self {
        case .root:
            return "Settings"
        case let .section(sectionID):
            return sectionID.title
        case .trainerPositionFilter:
            return "Position Filter"
        case .pianoAdvanced:
            return "Advanced"
        }
    }
}

struct SettingsPageModel: Equatable, Sendable {
    var id: SettingsRouteID
    var title: String
    var content: SettingsPageContent
}

struct SettingsNavigationModel: Equatable, Sendable {
    var rootRoute: SettingsRouteID
    var pages: [SettingsRouteID: SettingsPageModel]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: 属性区 / configureView() / settingsContainerView / applySettingsPanelState()
// 功能说明: 修改前 iOS 侧虽然已经有 navigatorHostView，
// 但真正挂进去的仍是 settingsPanelView，controller 也仍然喂给它 SettingsPanelModel。
var model: SettingsPanelModel {
    didSet {
        guard oldValue != model else {
            return
        }

        settingsPanelView.model = model
    }
}

private let settingsPanelView: iOSSettingsPanelView

setNavigationContentView(settingsPanelView)

private lazy var settingsContainerView: iOSSettingsContainerView = {
    let settingsContainerView = iOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            from: settingsPanelStateContext
        )
    )
    return settingsContainerView
}()

private func applySettingsPanelState() {
    settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
        from: settingsPanelStateContext
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: 属性区 / configureView() / settingsContainerView / applySettingsPanelState()
// 功能说明: 修改前 macOS 侧与 iOS 对称，
// 仍然是单页 SettingsPanelView 承载内容，controller 也没有切换到 navigationModel。
var model: SettingsPanelModel {
    didSet {
        guard oldValue != model else {
            return
        }

        settingsPanelView.model = model
    }
}

private let settingsPanelView: macOSSettingsPanelView

setNavigationContentView(settingsPanelView)

private lazy var settingsContainerView: macOSSettingsContainerView = {
    let settingsContainerView = macOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            from: settingsPanelStateContext
        )
    )
    return settingsContainerView
}()

private func applySettingsPanelState() {
    settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
        from: settingsPanelStateContext
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift
// 函数名: N/A（新文件）
// 功能说明: 修改前这些文件不存在；
// 双平台都还没有“root 索引页 + routeStack + push/pop 转场”的平台导航壳。
```

## 修改后

- 共享层新增了 `SettingsNavigationPresentationState`，并为 `SettingsRouteID` 补充 `accessibilityIdentifierComponent`，让平台导航壳可以统一同步 header 状态和 route 按钮标识。
- iOS/macOS 各自新增 `IndexPageView`，把 root page 的 `routeItems` 渲染成独立入口列表，不再让 root 页面直接等于单页表单。
- iOS/macOS 各自新增 `NavigatorView`，内部维护 `routeStack`，支持 `root -> section` push/pop，并在 detail page 继续复用现有 `SettingsPanelView`。
- 双平台 container 的内容源正式从 `settingsPanelView` 切换到 `navigatorView`，`backButton` 也开始真正连到 `navigatorView.pop()`。
- 双平台 controller 的 settings 输入切换为 `SettingsNavigationSnapshotBuilder.makeModel(...)`，而 `handleSettingsPanelEvent(_:)` 这条旧回写链保持不变。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: SettingsRouteID / SettingsNavigationPresentationState
// 功能说明: 修改后共享导航模型补齐平台导航壳需要的展示态与 accessibility 片段，
// 让 header 同步和 route button 标识不必在平台层各自硬编码。
enum SettingsRouteID: Equatable, Hashable, Sendable {
    case root
    case section(SettingsSectionID)
    case trainerPositionFilter
    case pianoAdvanced

    var fallbackTitle: String {
        switch self {
        case .root:
            return "Settings"
        case let .section(sectionID):
            return sectionID.title
        case .trainerPositionFilter:
            return "Position Filter"
        case .pianoAdvanced:
            return "Advanced"
        }
    }

    var accessibilityIdentifierComponent: String {
        switch self {
        case .root:
            return "root"
        case let .section(sectionID):
            return "section-\(String(describing: sectionID))"
        case .trainerPositionFilter:
            return "trainer-position-filter"
        case .pianoAdvanced:
            return "piano-advanced"
        }
    }
}

struct SettingsNavigationPresentationState: Equatable, Sendable {
    var title: String
    var showsBackButton: Bool
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsIndexPageView.swift
// 函数名: applyRouteItems() / RouteButton.apply(routeItem:)
// 功能说明: 新增 iOS root index page；
// 把共享 routeItems 渲染成可点击入口，并复用统一的 accessibilityIdentifier 片段。
private func applyRouteItems() {
    removeObsoleteButtons(notIn: Set(routeItems.map(\.route)))

    let orderedButtons = routeItems.map { routeItem -> UIButton in
        button(for: routeItem)
    }

    replaceArrangedSubviews(
        in: routesStackView,
        with: orderedButtons
    )
}

private final class RouteButton: UIButton {
    var route: SettingsRouteID?

    func apply(routeItem: SettingsRouteItem) {
        route = routeItem.route
        accessibilityIdentifier = "settings-index-route-\(routeItem.route.accessibilityIdentifierComponent)"
        accessibilityLabel = routeItem.subtitle.map {
            "\(routeItem.title), \($0)"
        } ?? routeItem.title

        var configuration = configuration ?? UIButton.Configuration.filled()
        configuration.title = routeItem.title
        configuration.subtitle = routeItem.subtitle
        configuration.image = UIImage(systemName: "chevron.right")
        configuration.imagePlacement = .trailing
        configuration.titleAlignment = .leading
        self.configuration = configuration
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift
// 函数名: applyRouteItems() / RouteButton.apply(routeItem:)
// 功能说明: 新增 macOS root index page；
// 与 iOS 保持同一份 routeItems 输入语义，但用 AppKit button / stack 进行对称实现。
private func applyRouteItems() {
    removeObsoleteButtons(notIn: Set(routeItems.map(\.route)))

    let orderedButtons = routeItems.map { routeItem -> NSView in
        button(for: routeItem)
    }

    replaceArrangedSubviews(
        in: routesStackView,
        with: orderedButtons
    )
}

private final class RouteButton: NSButton {
    var route: SettingsRouteID?

    func apply(routeItem: SettingsRouteItem) {
        route = routeItem.route
        identifier = NSUserInterfaceItemIdentifier(
            "settings-index-route-\(routeItem.route.accessibilityIdentifierComponent)"
        )
        toolTip = routeItem.subtitle.map {
            "\(routeItem.title) - \($0)"
        } ?? routeItem.title
        title = routeItem.title
        image = NSImage(
            systemSymbolName: "chevron.right",
            accessibilityDescription: routeItem.title
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsNavigatorView.swift
// 函数名: push(_:) / makePageView(for:) / replaceCurrentPage(...) / notifyPresentationStateChange()
// 功能说明: 新增 iOS navigator；
// 负责维护 routeStack、把 root page 渲染为 index page、把 detail page 渲染为表单页，并执行卡片内 push/pop 滑动转场。
private func push(_ route: SettingsRouteID, animated: Bool = true) {
    let reconciledPath = model.reconciledPath(routeStack + [route])
    guard reconciledPath != routeStack else {
        return
    }

    routeStack = reconciledPath
    replaceCurrentPage(
        with: makePageView(for: routeStack.last ?? model.rootRoute),
        transitionDirection: .push,
        animated: animated
    )
}

private func makePageView(for route: SettingsRouteID) -> UIView {
    guard let page = model.page(for: route) else {
        return UIView()
    }

    switch page.content {
    case let .index(routeItems):
        let indexPageView = iOSSettingsIndexPageView(routeItems: routeItems)
        indexPageView.onRouteSelected = { [weak self] selectedRoute in
            self?.push(selectedRoute)
        }
        return indexPageView
    case let .form(sections):
        let panelView = iOSSettingsPanelView(
            model: SettingsPanelModel(sections: sections)
        )
        panelView.onEvent = onEvent
        return panelView
    }
}

private func notifyPresentationStateChange() {
    guard let currentRoute = routeStack.last,
          let page = model.page(for: currentRoute) else {
        onPresentationStateChange?(
            SettingsNavigationPresentationState(
                title: SettingsRouteID.root.fallbackTitle,
                showsBackButton: false
            )
        )
        return
    }

    onPresentationStateChange?(
        SettingsNavigationPresentationState(
            title: page.title,
            showsBackButton: routeStack.count > 1
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift
// 函数名: push(_:) / makePageView(for:) / replaceCurrentPage(...) / snapshotView(for:)
// 功能说明: 新增 macOS navigator；
// 与 iOS 保持同一份 routeStack 语义，但转场实现切换为 AppKit 快照滑动。
private func push(_ route: SettingsRouteID, animated: Bool = true) {
    let reconciledPath = model.reconciledPath(routeStack + [route])
    guard reconciledPath != routeStack else {
        return
    }

    routeStack = reconciledPath
    replaceCurrentPage(
        with: makePageView(for: routeStack.last ?? model.rootRoute),
        transitionDirection: .push,
        animated: animated
    )
}

private func replaceCurrentPage(
    with newPageView: NSView,
    transitionDirection: TransitionDirection,
    animated: Bool
) {
    let oldPageView = currentPageView
    let oldSnapshotView = animated ? snapshotView(for: oldPageView) : nil

    installCurrentPageView(newPageView)
    layoutSubtreeIfNeeded()

    let newSnapshotView = animated ? snapshotView(for: newPageView) : nil
    let pageHostWidth = max(pageHostView.bounds.width, bounds.width, 1)

    let animations = {
        oldSnapshotView?.animator().setFrameOrigin(
            CGPoint(
                x: transitionDirection.exitingOffset(for: pageHostWidth),
                y: 0
            )
        )
        oldSnapshotView?.animator().alphaValue = 0
        newSnapshotView?.animator().setFrameOrigin(.zero)
        newSnapshotView?.animator().alphaValue = 1
    }

    NSAnimationContext.runAnimationGroup { context in
        context.duration = Style.transitionDuration
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animations()
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数名: 属性区 + configureView()
// 功能说明: iOS container 现在正式切换为承载 navigatorView；
// header 的 back/title 状态也开始由 navigator 回推，而不是继续挂死在静态壳层里。
var navigationModel: SettingsNavigationModel {
    didSet {
        guard oldValue != navigationModel else {
            return
        }

        navigatorView.model = navigationModel
    }
}

private lazy var navigatorView: iOSSettingsNavigatorView = {
    let navigatorView = iOSSettingsNavigatorView(model: navigationModel)
    navigatorView.onEvent = onEvent
    navigatorView.onPresentationStateChange = { [weak self] state in
        self?.navigationTitle = state.title
        self?.showsBackButton = state.showsBackButton
    }
    return navigatorView
}()

onBackRequest = { [weak self] in
    self?.navigatorView.pop()
}
setNavigationContentView(navigatorView)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数名: 属性区 + configureView()
// 功能说明: macOS container 也同步切换为 navigatorView 驱动，
// 保证 card header、内容宿主、返回动作在双平台上继续对称。
var navigationModel: SettingsNavigationModel {
    didSet {
        guard oldValue != navigationModel else {
            return
        }

        navigatorView.model = navigationModel
    }
}

private lazy var navigatorView: macOSSettingsNavigatorView = {
    let navigatorView = macOSSettingsNavigatorView(model: navigationModel)
    navigatorView.onEvent = onEvent
    navigatorView.onPresentationStateChange = { [weak self] state in
        self?.navigationTitle = state.title
        self?.showsBackButton = state.showsBackButton
    }
    return navigatorView
}()

onBackRequest = { [weak self] in
    self?.navigatorView.pop()
}
setNavigationContentView(navigatorView)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: settingsContainerView / applySettingsPanelState()
// 功能说明: 双平台 controller 的 settings 输入统一切到 SettingsNavigationSnapshotBuilder；
// 这样 container 接收到的是页面树，而不是旧的单页表单快照。
private lazy var settingsContainerView: iOSSettingsContainerView = {
    let settingsContainerView = iOSSettingsContainerView(
        model: SettingsNavigationSnapshotBuilder.makeModel(
            from: settingsPanelStateContext
        )
    )
    return settingsContainerView
}()

private func applySettingsPanelState() {
    settingsContainerView.navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: settingsPanelStateContext
    )
}

private lazy var settingsContainerView: macOSSettingsContainerView = {
    let settingsContainerView = macOSSettingsContainerView(
        model: SettingsNavigationSnapshotBuilder.makeModel(
            from: settingsPanelStateContext
        )
    )
    return settingsContainerView
}()

private func applySettingsPanelState() {
    settingsContainerView.navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: settingsPanelStateContext
    )
}
```

## 结果归纳

- 阶段 4 完成后，settings card 的真实内容结构已经从“单页表单壳”切换为“共享页面树 + 平台导航壳”。
- 当前已经可以稳定支持 `root -> section` 这一级卡片内导航，且返回按钮、标题、内容切换都由 navigator 驱动。
- detail page 继续复用旧的 `SettingsPanelView`，因此没有打断现有 `SettingsPanelEvent`、`SettingsPanelStateContext`、`SettingsPanelSnapshotBuilder` 相关业务逻辑。
- 这也为下一阶段继续把 `Trainer / Piano / Staff` 等重区拆成更深 route 做好了平台基础设施。

## 验证结果

- `ReadLints`：本次涉及文件无新增 linter 报错
- iOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS" build`
- macOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`
- 当前尚未补充阶段 5 的深层 route 手工回归记录；本记录仅覆盖阶段 4 的代码落地与编译验证

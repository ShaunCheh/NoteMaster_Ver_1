# 20260325_211149_phase3_ios_vertical_fretboard_local_horizontal_scroll

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_211149`
- 记录范围：竖向指板局部横滚方案的阶段3实施
- 本次目标：在 iOS 端先落地“只让指板区域横向滚动，页面整体仍然只纵向滚动”的控制器结构，把阶段1/2已经准备好的 shared / platform 内容宽度真相真正接入页面布局
- 根因结论：原有 iOS 布局把 `fretboardView` 直接塞进 `fretboardHostView`，竖向模式下只允许 `width <= host width`，于是即使 shared 层已经能算出“整把竖向指板的内容宽度”，控制器也没有容器去承载这个更宽的内容，最终只能继续把指板压回 host 宽度，导致后续仍然会出现 letterbox 式留白
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`

## 本次完成的修改

1. 在 `iOSViewController` 中新增 `fretboardViewportScrollView` 与 `fretboardScrollContentView`，把指板从“直接挂在 host 上”改成“挂在指板专用横向滚动容器里”。
2. 将原先竖向模式的 `width <= fretboardHostView.width` 约束改成“内容宽度由 `fretboardView.verticalContentSize.width` 驱动”。
3. 保留外层页面 `scrollView` 的纵向滚动职责，不让 `staffView` 跟着横向扩展。
4. 新增 `viewDidLayoutSubviews()`、`syncVerticalFretboardContentWidthConstraint()`、`updateFretboardViewportPresentation()`，用于在布局阶段同步内容宽度、决定是否需要横向滚动，以及在内容未超宽时保持居中显示。
5. 横向模式维持原先“内容宽度等于 viewport 宽度”的语义，不影响现有水平指板布局。
6. 完成本轮 `ReadLints` 与 `swiftc -typecheck` 静态校验。

## 修改 1：指板从“直接挂在 host”改为“局部横向滚动容器 + 内容容器”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: 属性定义 + configureLayout()
// 功能说明: 修改前控制器只有 fretboardHostView，没有指板专用横向滚动容器；
// fretboardView 直接作为 host 子视图参与布局，因此竖向模式无法承载大于 host 宽度的内容。
private let scrollView = UIScrollView()
private let contentView = UIView()
private let fretboardHostView = UIView()
private var horizontalFretboardConstraints: [NSLayoutConstraint] = []
private var verticalFretboardConstraints: [NSLayoutConstraint] = []
private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    scrollView.alwaysBounceHorizontal = false
    scrollView.showsHorizontalScrollIndicator = false

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardHostView)
    fretboardHostView.addSubview(fretboardView)
    view.addSubview(settingsButton)
    view.addSubview(settingsContainerView)

    let safeArea = view.safeAreaLayoutGuide
    rebuildVerticalFretboardHostHeightConstraint()
    horizontalFretboardConstraints = [
        fretboardView.leadingAnchor.constraint(equalTo: fretboardHostView.leadingAnchor),
        fretboardView.trailingAnchor.constraint(equalTo: fretboardHostView.trailingAnchor)
    ]
    verticalFretboardConstraints = [
        fretboardView.centerXAnchor.constraint(equalTo: fretboardHostView.centerXAnchor),
        fretboardView.widthAnchor.constraint(lessThanOrEqualTo: fretboardHostView.widthAnchor)
    ]

    NSLayoutConstraint.activate([
        // ... page constraints ...
        fretboardView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
        fretboardView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor)
        // ... other constraints ...
    ])
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: 属性定义 + configureLayout()
// 功能说明: 修改后在 fretboardHostView 内引入专用 viewport scrollView 和 contentView，
// 指板内容宽度从此可以独立于 host 宽度扩展，而页面主 scrollView 仍然只负责纵向滚动。
private let scrollView = UIScrollView()
private let contentView = UIView()
private let fretboardHostView = UIView()
private let fretboardViewportScrollView = UIScrollView()
private let fretboardScrollContentView = UIView()
private var horizontalFretboardContentWidthConstraint: NSLayoutConstraint?
private var verticalFretboardContentWidthConstraint: NSLayoutConstraint?
private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
    fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
    fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    scrollView.alwaysBounceHorizontal = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.isDirectionalLockEnabled = true
    fretboardViewportScrollView.alwaysBounceVertical = false
    fretboardViewportScrollView.alwaysBounceHorizontal = false
    fretboardViewportScrollView.showsVerticalScrollIndicator = false
    fretboardViewportScrollView.showsHorizontalScrollIndicator = false
    fretboardViewportScrollView.isDirectionalLockEnabled = true
    fretboardViewportScrollView.delaysContentTouches = false
    fretboardViewportScrollView.canCancelContentTouches = true
    fretboardViewportScrollView.panGestureRecognizer.cancelsTouchesInView = true
    fretboardViewportScrollView.contentInsetAdjustmentBehavior = .never

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardHostView)
    fretboardHostView.addSubview(fretboardViewportScrollView)
    fretboardViewportScrollView.addSubview(fretboardScrollContentView)
    fretboardScrollContentView.addSubview(fretboardView)
    view.addSubview(settingsButton)
    view.addSubview(settingsContainerView)

    let safeArea = view.safeAreaLayoutGuide
    rebuildVerticalFretboardHostHeightConstraint()
    horizontalFretboardContentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
        equalTo: fretboardViewportScrollView.frameLayoutGuide.widthAnchor
    )
    verticalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
        equalToConstant: displayState.configuration.verticalContentWidth(
            forViewportHeight: displayState.configuration.preferredHeight
        )
    )

    NSLayoutConstraint.activate([
        // ... page constraints ...
        fretboardViewportScrollView.leadingAnchor.constraint(equalTo: fretboardHostView.leadingAnchor),
        fretboardViewportScrollView.trailingAnchor.constraint(equalTo: fretboardHostView.trailingAnchor),
        fretboardViewportScrollView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
        fretboardViewportScrollView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor),
        fretboardScrollContentView.leadingAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentLayoutGuide.leadingAnchor
        ),
        fretboardScrollContentView.trailingAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentLayoutGuide.trailingAnchor
        ),
        fretboardScrollContentView.topAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentLayoutGuide.topAnchor
        ),
        fretboardScrollContentView.bottomAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentLayoutGuide.bottomAnchor
        ),
        fretboardScrollContentView.heightAnchor.constraint(
            equalTo: fretboardViewportScrollView.frameLayoutGuide.heightAnchor
        ),
        fretboardView.leadingAnchor.constraint(equalTo: fretboardScrollContentView.leadingAnchor),
        fretboardView.trailingAnchor.constraint(equalTo: fretboardScrollContentView.trailingAnchor),
        fretboardView.topAnchor.constraint(equalTo: fretboardScrollContentView.topAnchor),
        fretboardView.bottomAnchor.constraint(equalTo: fretboardScrollContentView.bottomAnchor)
        // ... other constraints ...
    ])
}
```

## 修改 2：竖向模式从“宽度不超过 host”切换为“内容宽度由 shared 真相驱动”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: updateFretboardLayoutModeConstraints()
// 功能说明: 修改前横向/竖向模式通过两组旧约束数组切换；
// 竖向模式的关键约束是 width <= fretboardHostView.width，这会直接阻断局部横向滚动所需的内容宽度。
private func updateFretboardLayoutModeConstraints() {
    let isVertical = displayState.displayMode == .vertical
    verticalFretboardHostHeightConstraint?.isActive = isVertical
    horizontalFretboardConstraints.forEach { $0.isActive = !isVertical }
    verticalFretboardConstraints.forEach { $0.isActive = isVertical }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: updateFretboardLayoutModeConstraints()
// 功能说明: 修改后横向模式继续让 content width 贴合 viewport；竖向模式则切到“内容宽度常量约束”，
// 真正允许 fretboardView 在内层 scroll 内容里变得比 host 更宽。
private func updateFretboardLayoutModeConstraints() {
    let isVertical = displayState.displayMode == .vertical
    verticalFretboardHostHeightConstraint?.isActive = isVertical
    horizontalFretboardContentWidthConstraint?.isActive = !isVertical
    verticalFretboardContentWidthConstraint?.isActive = isVertical

    if !isVertical {
        fretboardViewportScrollView.contentInset = .zero
        fretboardViewportScrollView.scrollIndicatorInsets = .zero
        fretboardViewportScrollView.setContentOffset(.zero, animated: false)
    }
}
```

## 修改 3：新增布局期内容宽度同步与 viewport 展示策略

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyFretboardDisplayState()
// 功能说明: 修改前指板状态刷新只做配置下发、重建 host 高度约束和整体 layout，不存在内容宽度同步、
// 横向滚动开关或“内容未超宽时居中”的 viewport 表现逻辑。
private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: viewDidLayoutSubviews() / applyFretboardDisplayState() /
// syncVerticalFretboardContentWidthConstraint() / updateFretboardViewportPresentation()
// 功能说明: 修改后控制器会在布局阶段同步竖向内容宽度，并根据内容是否超出 viewport
// 决定是否启用横向滚动；如果内容没有超宽，则通过 contentInset 保持视觉居中。
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    syncVerticalFretboardContentWidthConstraint()
    updateFretboardViewportPresentation()
}

private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
    updateLayoutIfNeeded()
    syncVerticalFretboardContentWidthConstraint()
    updateLayoutIfNeeded()
    updateFretboardViewportPresentation()
}

private func syncVerticalFretboardContentWidthConstraint() {
    guard
        displayState.displayMode == .vertical,
        let verticalFretboardContentWidthConstraint
    else {
        return
    }

    let targetWidth = fretboardView.verticalContentSize.width
    guard targetWidth > 0 else {
        return
    }

    if abs(verticalFretboardContentWidthConstraint.constant - targetWidth) > Layout.contentSizeTolerance {
        verticalFretboardContentWidthConstraint.constant = targetWidth
    }
}

private func updateFretboardViewportPresentation() {
    let isVertical = displayState.displayMode == .vertical
    guard isVertical else {
        fretboardViewportScrollView.isScrollEnabled = false
        fretboardViewportScrollView.alwaysBounceHorizontal = false
        fretboardViewportScrollView.showsHorizontalScrollIndicator = false
        return
    }

    let viewportWidth = fretboardViewportScrollView.bounds.width
    let contentWidth = verticalFretboardContentWidthConstraint?.constant ?? fretboardView.verticalContentSize.width
    guard viewportWidth > 0, contentWidth > 0 else {
        return
    }

    let needsHorizontalScroll = contentWidth > viewportWidth + Layout.contentSizeTolerance
    let horizontalInset = needsHorizontalScroll
        ? 0
        : max((viewportWidth - contentWidth) / 2, 0)
    let inset = UIEdgeInsets(
        top: 0,
        left: horizontalInset,
        bottom: 0,
        right: horizontalInset
    )

    fretboardViewportScrollView.contentInset = inset
    fretboardViewportScrollView.scrollIndicatorInsets = inset
    fretboardViewportScrollView.isScrollEnabled = needsHorizontalScroll
    fretboardViewportScrollView.alwaysBounceHorizontal = needsHorizontalScroll
    fretboardViewportScrollView.showsHorizontalScrollIndicator = needsHorizontalScroll
}
```

## 阶段3结果说明

- 这一步只改了 iOS 控制器层，macOS 还没镜像，因此当前“局部横向滚动”只在 iOS 方案上建立了结构基础。
- 页面主 `scrollView` 仍然保持 `contentView.width == frameLayoutGuide.width`，所以 `staffView` 依然占满页面宽度，不参与横向扩展。
- 指板区域现在有了独立的 viewport scrollView，后续竖向模式下的真实内容宽度会优先由 `fretboardView.verticalContentSize.width` 决定，而不是再被 `host` 的宽度上限硬压回去。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
2. 执行以下静态校验，结果通过：
   - `swiftc -typecheck NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift NoteMaster_Ver_1/Shared/Controls/*.swift NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift`
3. 结构上确认：
   - iOS 端已经有独立的指板局部横向滚动容器；
   - 竖向模式内容宽度已经开始接入阶段1/2建立的 shared / platform 真相链路；
   - 横向模式仍然保持“内容宽度等于 viewport 宽度”的旧语义。

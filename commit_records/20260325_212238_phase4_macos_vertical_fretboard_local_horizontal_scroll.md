# 20260325_212238_phase4_macos_vertical_fretboard_local_horizontal_scroll

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_212238`
- 记录范围：竖向指板局部横滚方案的阶段4实施
- 本次目标：在 macOS 端镜像 iOS 已落地的“指板局部横向滚动”结构，让 `staffView` 继续占满页面 viewport 宽度，同时允许竖向指板内容在 `NSScrollView` 内按真实内容宽度展开
- 根因结论：原有 `macOSViewController` 与改造前的 iOS 一样，仍把 `macOSFretboardView` 直接挂在 `fretboardHostView` 上，并在竖向模式下用 `width <= fretboardHostView.width` 限死内容宽度。这样即使 shared / platform 已经能算出竖向内容宽度，控制器层仍没有承载“内容比宿主更宽”的结构，macOS 端会持续保留同类 letterbox 根因
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 在 `macOSViewController` 中新增 `fretboardViewportScrollView` 与 `fretboardScrollContentView`，把指板从“直接挂在 host 上”改成“挂在 macOS 专用局部横向滚动容器里”。
2. 将原先竖向模式的 `width <= fretboardHostView.width` 约束替换为“document width + content width 都由 `macOSFretboardView.verticalContentSize.width` 驱动”的双层宽度真相。
3. 保留外层页面 `scrollView` 继续只做纵向滚动，使 `staffView` 仍然固定在页面 viewport 宽度内。
4. 新增 `viewDidLayout()`、`syncVerticalFretboardContentSizeConstraints()`、`updateFretboardViewportPresentation()` 与 `scrollFretboardViewport(toX:)`，用于在布局阶段同步 document/content 宽度、判定是否需要横向滚动，并在内容不足 viewport 宽时保持起点稳定。
5. 横向模式继续使用“document width == viewport width、content width == document width”的旧语义，不影响现有横向指板布局。
6. 完成本轮 `ReadLints` 与 `swiftc -typecheck` 静态校验；第一次 typecheck 因命令缺少 `macOSSettingsContainerView.swift` / `macOSSettingsPanelView.swift` 依赖失败，补齐依赖后通过。

## 修改 1：macOS 指板从“直接挂在 host”改为“局部横向滚动容器 + documentView”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: 属性定义 + configureLayout()
// 功能说明: 修改前 macOS 控制器只有 fretboardHostView，没有指板专用横向 NSScrollView；
// macOSFretboardView 直接作为 host 子视图参与布局，因此竖向模式无法承载比 host 更宽的内容。
private let scrollView = NSScrollView()
private let contentView = NSView()
private let fretboardHostView = NSView()
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
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.documentView = contentView

    view.addSubview(scrollView)
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
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: 属性定义 + configureLayout()
// 功能说明: 修改后 macOS 控制器在 fretboardHostView 内引入专用 NSScrollView + documentView，
// 让指板内容宽度可以独立于 host 宽度扩展，同时保持页面主 scrollView 继续只负责纵向滚动。
private let scrollView = NSScrollView()
private let contentView = NSView()
private let fretboardHostView = NSView()
private let fretboardViewportScrollView = NSScrollView()
private let fretboardScrollContentView = NSView()
private var horizontalFretboardDocumentWidthConstraint: NSLayoutConstraint?
private var horizontalFretboardContentWidthConstraint: NSLayoutConstraint?
private var verticalFretboardDocumentWidthConstraint: NSLayoutConstraint?
private var verticalFretboardContentWidthConstraint: NSLayoutConstraint?
private var fretboardContentCenterXConstraint: NSLayoutConstraint?
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
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.documentView = contentView
    fretboardViewportScrollView.drawsBackground = false
    fretboardViewportScrollView.borderType = .noBorder
    fretboardViewportScrollView.hasVerticalScroller = false
    fretboardViewportScrollView.hasHorizontalScroller = false
    fretboardViewportScrollView.autohidesScrollers = true
    fretboardViewportScrollView.documentView = fretboardScrollContentView

    view.addSubview(scrollView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardHostView)
    fretboardHostView.addSubview(fretboardViewportScrollView)
    fretboardScrollContentView.addSubview(fretboardView)
    view.addSubview(settingsButton)
    view.addSubview(settingsContainerView)

    let safeArea = view.safeAreaLayoutGuide
    rebuildVerticalFretboardHostHeightConstraint()
    horizontalFretboardDocumentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
        equalTo: fretboardViewportScrollView.contentView.widthAnchor
    )
    horizontalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
        equalTo: fretboardScrollContentView.widthAnchor
    )
    verticalFretboardDocumentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
        equalToConstant: displayState.configuration.verticalContentWidth(
            forViewportHeight: displayState.configuration.preferredHeight
        )
    )
    verticalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
        equalToConstant: displayState.configuration.verticalContentWidth(
            forViewportHeight: displayState.configuration.preferredHeight
        )
    )
    fretboardContentCenterXConstraint = fretboardView.centerXAnchor.constraint(
        equalTo: fretboardScrollContentView.centerXAnchor
    )

    NSLayoutConstraint.activate([
        // ... page constraints ...
        fretboardViewportScrollView.leadingAnchor.constraint(equalTo: fretboardHostView.leadingAnchor),
        fretboardViewportScrollView.trailingAnchor.constraint(equalTo: fretboardHostView.trailingAnchor),
        fretboardViewportScrollView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
        fretboardViewportScrollView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor),
        fretboardScrollContentView.leadingAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentView.leadingAnchor
        ),
        fretboardScrollContentView.topAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentView.topAnchor
        ),
        fretboardScrollContentView.heightAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentView.heightAnchor
        ),
        fretboardView.topAnchor.constraint(equalTo: fretboardScrollContentView.topAnchor),
        fretboardView.bottomAnchor.constraint(equalTo: fretboardScrollContentView.bottomAnchor),
        fretboardContentCenterXConstraint!
        // ... other constraints ...
    ])
}
```

## 修改 2：竖向模式从“宽度不超过 host”改为“document / content 双层宽度由内容真相驱动”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: updateFretboardLayoutModeConstraints()
// 功能说明: 修改前横向/竖向模式仍通过两组旧约束数组切换；
// 竖向模式的关键约束是 width <= fretboardHostView.width，因此没有任何空间让 documentView 横向展开。
private func updateFretboardLayoutModeConstraints() {
    let isVertical = displayState.displayMode == .vertical
    verticalFretboardHostHeightConstraint?.isActive = isVertical
    horizontalFretboardConstraints.forEach { $0.isActive = !isVertical }
    verticalFretboardConstraints.forEach { $0.isActive = isVertical }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: updateFretboardLayoutModeConstraints()
// 功能说明: 修改后横向模式继续把 document / content 都锁到 viewport 宽度；
// 竖向模式则切到“document 宽度常量 + content 宽度常量”两条约束，允许指板内容在 NSScrollView 内超出 host 宽度。
private func updateFretboardLayoutModeConstraints() {
    let isVertical = displayState.displayMode == .vertical
    verticalFretboardHostHeightConstraint?.isActive = isVertical
    horizontalFretboardDocumentWidthConstraint?.isActive = !isVertical
    horizontalFretboardContentWidthConstraint?.isActive = !isVertical
    verticalFretboardDocumentWidthConstraint?.isActive = isVertical
    verticalFretboardContentWidthConstraint?.isActive = isVertical

    if !isVertical {
        fretboardViewportScrollView.hasHorizontalScroller = false
        scrollFretboardViewport(toX: 0)
    }
}
```

## 修改 3：新增布局期内容宽度同步、滚动开关与滚动位置修正逻辑

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: applyFretboardDisplayState()
// 功能说明: 修改前控制器只负责配置下发、重建 host 高度约束和整体 layout，
// 并没有 document/content 宽度同步或横向滚动状态控制逻辑。
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
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: viewDidLayout() / applyFretboardDisplayState() /
// syncVerticalFretboardContentSizeConstraints() / updateFretboardViewportPresentation() /
// scrollFretboardViewport(toX:)
// 功能说明: 修改后控制器会在布局阶段同步竖向 document/content 宽度，
// 并根据内容是否超出 viewport 决定是否显示横向 scroller；同时会把滚动位置钳回合法区间。
override func viewDidLayout() {
    super.viewDidLayout()
    syncVerticalFretboardContentSizeConstraints()
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
    syncVerticalFretboardContentSizeConstraints()
    updateLayoutIfNeeded()
    updateFretboardViewportPresentation()
}

private func syncVerticalFretboardContentSizeConstraints() {
    guard
        displayState.displayMode == .vertical,
        let verticalFretboardDocumentWidthConstraint,
        let verticalFretboardContentWidthConstraint
    else {
        return
    }

    let contentWidth = fretboardView.verticalContentSize.width
    let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
    guard contentWidth > 0 else {
        return
    }

    let documentWidth = max(viewportWidth, contentWidth)
    if abs(verticalFretboardDocumentWidthConstraint.constant - documentWidth) > Layout.contentSizeTolerance {
        verticalFretboardDocumentWidthConstraint.constant = documentWidth
    }

    if abs(verticalFretboardContentWidthConstraint.constant - contentWidth) > Layout.contentSizeTolerance {
        verticalFretboardContentWidthConstraint.constant = contentWidth
    }
}

private func updateFretboardViewportPresentation() {
    let isVertical = displayState.displayMode == .vertical
    guard isVertical else {
        fretboardViewportScrollView.hasHorizontalScroller = false
        return
    }

    let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
    let contentWidth = verticalFretboardContentWidthConstraint?.constant ?? fretboardView.verticalContentSize.width
    guard viewportWidth > 0, contentWidth > 0 else {
        return
    }

    let needsHorizontalScroll = contentWidth > viewportWidth + Layout.contentSizeTolerance
    fretboardViewportScrollView.hasHorizontalScroller = needsHorizontalScroll

    let maxOffsetX = max(contentWidth - viewportWidth, 0)
    let currentOffsetX = fretboardViewportScrollView.contentView.bounds.origin.x
    let clampedOffsetX = needsHorizontalScroll
        ? min(max(currentOffsetX, 0), maxOffsetX)
        : 0

    if abs(currentOffsetX - clampedOffsetX) > Layout.contentSizeTolerance {
        scrollFretboardViewport(toX: clampedOffsetX)
    }
}

private func scrollFretboardViewport(toX x: CGFloat) {
    fretboardViewportScrollView.contentView.scroll(to: CGPoint(x: x, y: 0))
    fretboardViewportScrollView.reflectScrolledClipView(
        fretboardViewportScrollView.contentView
    )
}
```

## 阶段4结果说明

- 这一步把阶段3在 iOS 落下来的“局部横向滚动”结构完整镜像到了 macOS 端，因此双平台现在都具备了“页面主滚动保持纵向、指板区域局部横滚”的容器基础。
- `staffView` 依然跟随页面 viewport 宽度，不会随着竖向指板内容变宽而一起横向扩展。
- 这一步还没有动 shared 几何装箱逻辑，所以如果你继续，下一步真正要做的是阶段5，把 `VerticalFretboardGeometryStrategy.makeDrawingRect(...)` 的“整图塞进 bounds”策略收口成“高度优先吃满”的最终根因修复。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
2. 第一次执行 `swiftc -typecheck` 时，因命令未包含 `macOSSettingsContainerView.swift` / `macOSSettingsPanelView.swift` 依赖，报出 `cannot find type 'macOSSettingsContainerView' in scope`。
3. 补齐依赖后，执行以下静态校验通过：
   - `swiftc -typecheck NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift NoteMaster_Ver_1/Shared/Controls/*.swift NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift`
4. 结构上确认：
   - macOS 端已经有独立的指板局部横向滚动容器；
   - 竖向模式 document/content 宽度已经接入阶段1/2建立的 shared / platform 真相链路；
   - 横向模式仍保持“document width == viewport width、content width == document width”的旧语义。

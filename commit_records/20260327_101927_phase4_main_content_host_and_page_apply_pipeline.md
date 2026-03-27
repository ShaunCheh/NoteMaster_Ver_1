# 20260327_101927_phase4_main_content_host_and_page_apply_pipeline

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_101927`
- 记录范围：`PageDisplayState` 阶段 4，双平台主内容 host 重构与页面 apply 管线闭环
- 本次目标：在 iOS / macOS controller 中引入 `mainContentHostView`，把 `PageDisplayState.mainContentMode` 真正接入页面布局链，让主内容区可以在 `fretboard` 和 `naturalNoteStrip` 之间切换，同时避免隐藏态指板继续参与滚动与约束同步
- 根因结论：修改前页面根布局仍然是 `topContentHostView -> fretboardHostView`，`PageDisplayState.mainContentMode` 虽然已经存在，但控制器没有一个独立的主内容宿主去承接第二种主内容，导致 `naturalNoteStripView` 只能停留在“组件已存在、状态已存在、页面未接线”的半完成状态。与此同时，指板的高度约束、竖向内容宽度同步和横向滚动展示逻辑都默认主内容永远是指板；如果只是简单 `isHidden`，隐藏态指板仍会继续吃布局和滚动副作用
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 双平台 controller 都新增了 `mainContentHostView`，把页面根布局升级为 `topContentHostView -> mainContentHostView`。
2. `fretboardHostView` 不再直接占据页面主内容位置，而是变成 `mainContentHostView` 的一个子视图。
3. `naturalNoteStripView` 作为第二种主内容视图并列挂入 `mainContentHostView`，由 `PageDisplayState.mainContentMode` 控制显隐与约束切换。
4. `applyPageDisplayState()` 被拆成页面总入口 + `applyTopContentMode()` + `applyMainContentMode()`，页面编排职责与 `applyFretboardDisplayState()` / `applyStaffDisplayState()` 分离。
5. 当主内容不是指板时，iOS / macOS 两端都会显式短路指板高度约束、内容宽度同步和横向滚动展示逻辑，避免隐藏态副作用。

## 修改 1：iOS 控制器把页面主内容从 `fretboardHostView` 提升为 `mainContentHostView`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: topContentHostView, fretboardHostView, configureLayout()
// 功能说明: 修改前页面根布局直接把 fretboardHostView 放在 topContentHostView 下方；
// 主内容区没有独立宿主，也没有位置容纳第二种主内容视图。
private let topContentHostView = UIView()
private let fretboardHostView = UIView()

private func configureLayout() {
    // ... 其他初始化省略

    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    contentView.addSubview(fretboardHostView)
    fretboardHostView.addSubview(fretboardViewportScrollView)

    NSLayoutConstraint.activate([
        topContentHostView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.topAnchor.constraint(
            equalTo: topContentHostView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardHostView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: mainContentHostView, mainContentFretboardConstraints, mainContentNaturalNoteStripConstraints, configureLayout()
// 功能说明: 修改后页面根布局先落到 mainContentHostView；
// fretboardHostView 和 naturalNoteStripView 都降为主内容宿主内部的可切换子视图。
private let topContentHostView = UIView()
private let mainContentHostView = UIView()
private let fretboardHostView = UIView()
private var mainContentFretboardConstraints: [NSLayoutConstraint] = []
private var mainContentNaturalNoteStripConstraints: [NSLayoutConstraint] = []

private lazy var naturalNoteStripView: iOSNaturalNoteStripView = {
    let naturalNoteStripView = iOSNaturalNoteStripView()
    naturalNoteStripView.isHidden = true
    return naturalNoteStripView
}()

private func configureLayout() {
    // ... 其他初始化省略

    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    contentView.addSubview(mainContentHostView)
    mainContentHostView.addSubview(fretboardHostView)
    mainContentHostView.addSubview(naturalNoteStripView)
    fretboardHostView.addSubview(fretboardViewportScrollView)

    mainContentFretboardConstraints = [
        fretboardHostView.leadingAnchor.constraint(equalTo: mainContentHostView.leadingAnchor),
        fretboardHostView.trailingAnchor.constraint(equalTo: mainContentHostView.trailingAnchor),
        fretboardHostView.topAnchor.constraint(equalTo: mainContentHostView.topAnchor),
        fretboardHostView.bottomAnchor.constraint(equalTo: mainContentHostView.bottomAnchor)
    ]
    mainContentNaturalNoteStripConstraints = [
        naturalNoteStripView.leadingAnchor.constraint(equalTo: mainContentHostView.leadingAnchor),
        naturalNoteStripView.trailingAnchor.constraint(equalTo: mainContentHostView.trailingAnchor),
        naturalNoteStripView.topAnchor.constraint(equalTo: mainContentHostView.topAnchor),
        naturalNoteStripView.bottomAnchor.constraint(equalTo: mainContentHostView.bottomAnchor)
    ]

    NSLayoutConstraint.activate([
        topContentHostView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        mainContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        mainContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        mainContentHostView.topAnchor.constraint(
            equalTo: topContentHostView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        mainContentHostView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

## 修改 2：iOS 页面 apply 管线接入主内容模式，并短路隐藏态指板逻辑

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyPageDisplayState(), updateFretboardLayoutModeConstraints(), syncVerticalFretboardContentWidthConstraint(), updateFretboardViewportPresentation()
// 功能说明: 修改前 applyPageDisplayState 只负责顶部区域切换；
// 指板布局与滚动逻辑默认主内容永远是 fretboard，没有 main content 模式短路。
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

private func applyPageDisplayState() {
    let showsStaff = pageDisplayState.topContentMode == .staff
    let activeConstraints = showsStaff
        ? topContentStaffConstraints
        : topContentTargetPromptConstraints
    let inactiveConstraints = showsStaff
        ? topContentTargetPromptConstraints
        : topContentStaffConstraints

    targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    staffView.isHidden = !showsStaff
    targetNotePromptView.isHidden = showsStaff
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
    applySettingsPanelState()
    updateLayoutIfNeeded()
}

private func syncVerticalFretboardContentWidthConstraint() {
    guard
        displayState.displayMode == .vertical,
        let verticalFretboardContentWidthConstraint
    else {
        return
    }

    // ... 原有竖向内容宽度同步逻辑
}

private func updateFretboardViewportPresentation() {
    let isVertical = displayState.displayMode == .vertical
    guard isVertical else {
        fretboardViewportScrollView.isScrollEnabled = false
        fretboardViewportScrollView.alwaysBounceHorizontal = false
        fretboardViewportScrollView.showsHorizontalScrollIndicator = false
        return
    }

    // ... 原有横向滚动展示逻辑
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: isShowingFretboardMainContent, applyPageDisplayState(), applyTopContentMode(), applyMainContentMode(), updateFretboardLayoutModeConstraints()
// 功能说明: 修改后 page apply 管线同时驱动顶部和主内容区域；
// 当 main content 不是 fretboard 时，指板高度约束与滚动逻辑都会被显式短路。
private var isShowingFretboardMainContent: Bool {
    pageDisplayState.mainContentMode == .fretboard
}

private func applyPageDisplayState() {
    targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()

    if isShowingFretboardMainContent {
        syncVerticalFretboardContentWidthConstraint()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
}

private func applyTopContentMode() {
    let showsStaff = pageDisplayState.topContentMode == .staff
    let activeConstraints = showsStaff
        ? topContentStaffConstraints
        : topContentTargetPromptConstraints
    let inactiveConstraints = showsStaff
        ? topContentTargetPromptConstraints
        : topContentStaffConstraints

    staffView.isHidden = !showsStaff
    targetNotePromptView.isHidden = showsStaff
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
}

private func applyMainContentMode() {
    let showsFretboard = isShowingFretboardMainContent
    let activeConstraints = showsFretboard
        ? mainContentFretboardConstraints
        : mainContentNaturalNoteStripConstraints
    let inactiveConstraints = showsFretboard
        ? mainContentNaturalNoteStripConstraints
        : mainContentFretboardConstraints

    fretboardHostView.isHidden = !showsFretboard
    naturalNoteStripView.isHidden = showsFretboard
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}

private func updateFretboardLayoutModeConstraints() {
    guard isShowingFretboardMainContent else {
        verticalFretboardHostHeightConstraint?.isActive = false
        horizontalFretboardContentWidthConstraint?.isActive = false
        verticalFretboardContentWidthConstraint?.isActive = false
        fretboardViewportScrollView.contentInset = .zero
        fretboardViewportScrollView.scrollIndicatorInsets = .zero
        fretboardViewportScrollView.isScrollEnabled = false
        fretboardViewportScrollView.alwaysBounceHorizontal = false
        fretboardViewportScrollView.showsHorizontalScrollIndicator = false
        fretboardViewportScrollView.setContentOffset(.zero, animated: false)
        return
    }

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

## 修改 3：macOS 控制器对称引入 `mainContentHostView`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: topContentHostView, fretboardHostView, configureLayout()
// 功能说明: 修改前 macOS 页面根布局和 iOS 一样，仍是 topContentHostView 直接接 fretboardHostView；
// 页面主内容没有独立宿主，AppKit 侧也无法接入第二种主内容视图。
private let topContentHostView = NSView()
private let fretboardHostView = NSView()

private func configureLayout() {
    // ... 其他初始化省略

    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    contentView.addSubview(fretboardHostView)
    fretboardHostView.addSubview(fretboardViewportScrollView)

    NSLayoutConstraint.activate([
        topContentHostView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.topAnchor.constraint(
            equalTo: topContentHostView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardHostView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: mainContentHostView, mainContentFretboardConstraints, mainContentNaturalNoteStripConstraints, configureLayout()
// 功能说明: 修改后 macOS 也对称引入 mainContentHostView；
// fretboardHostView 和 naturalNoteStripView 都变成主内容宿主内部的切换子视图。
private let topContentHostView = NSView()
private let mainContentHostView = NSView()
private let fretboardHostView = NSView()
private var mainContentFretboardConstraints: [NSLayoutConstraint] = []
private var mainContentNaturalNoteStripConstraints: [NSLayoutConstraint] = []

private lazy var naturalNoteStripView: macOSNaturalNoteStripView = {
    let naturalNoteStripView = macOSNaturalNoteStripView()
    naturalNoteStripView.isHidden = true
    return naturalNoteStripView
}()

private func configureLayout() {
    // ... 其他初始化省略

    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    contentView.addSubview(mainContentHostView)
    mainContentHostView.addSubview(fretboardHostView)
    mainContentHostView.addSubview(naturalNoteStripView)
    fretboardHostView.addSubview(fretboardViewportScrollView)

    mainContentFretboardConstraints = [
        fretboardHostView.leadingAnchor.constraint(equalTo: mainContentHostView.leadingAnchor),
        fretboardHostView.trailingAnchor.constraint(equalTo: mainContentHostView.trailingAnchor),
        fretboardHostView.topAnchor.constraint(equalTo: mainContentHostView.topAnchor),
        fretboardHostView.bottomAnchor.constraint(equalTo: mainContentHostView.bottomAnchor)
    ]
    mainContentNaturalNoteStripConstraints = [
        naturalNoteStripView.leadingAnchor.constraint(equalTo: mainContentHostView.leadingAnchor),
        naturalNoteStripView.trailingAnchor.constraint(equalTo: mainContentHostView.trailingAnchor),
        naturalNoteStripView.topAnchor.constraint(equalTo: mainContentHostView.topAnchor),
        naturalNoteStripView.bottomAnchor.constraint(equalTo: mainContentHostView.bottomAnchor)
    ]

    NSLayoutConstraint.activate([
        topContentHostView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        mainContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        mainContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        mainContentHostView.topAnchor.constraint(
            equalTo: topContentHostView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        mainContentHostView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

## 修改 4：macOS 页面 apply 管线接入主内容模式，并短路隐藏态指板逻辑

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: applyPageDisplayState(), updateFretboardLayoutModeConstraints(), syncVerticalFretboardContentSizeConstraints(), updateFretboardViewportPresentation()
// 功能说明: 修改前 macOS 和 iOS 一样，page apply 只切顶部区域；
// document 宽度同步和 viewport 横滚逻辑默认主内容始终是 fretboard。
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

private func applyPageDisplayState() {
    let showsStaff = pageDisplayState.topContentMode == .staff
    let activeConstraints = showsStaff
        ? topContentStaffConstraints
        : topContentTargetPromptConstraints
    let inactiveConstraints = showsStaff
        ? topContentTargetPromptConstraints
        : topContentStaffConstraints

    targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    staffView.isHidden = !showsStaff
    targetNotePromptView.isHidden = showsStaff
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
    applySettingsPanelState()
    updateLayoutIfNeeded()
}

private func syncVerticalFretboardContentSizeConstraints() {
    guard
        displayState.displayMode == .vertical,
        let verticalFretboardDocumentWidthConstraint,
        let verticalFretboardContentWidthConstraint
    else {
        return
    }

    // ... 原有 document / content 宽度同步逻辑
}

private func updateFretboardViewportPresentation() {
    let isVertical = displayState.displayMode == .vertical
    guard isVertical else {
        fretboardViewportScrollView.hasHorizontalScroller = false
        return
    }

    // ... 原有横向滚动展示逻辑
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: isShowingFretboardMainContent, applyPageDisplayState(), applyTopContentMode(), applyMainContentMode(), updateFretboardLayoutModeConstraints()
// 功能说明: 修改后 macOS 页面 apply 管线与 iOS 对称；
// 当 main content 切到 naturalNoteStrip 时，document 宽度同步和 viewport 横滚逻辑都会停掉。
private var isShowingFretboardMainContent: Bool {
    pageDisplayState.mainContentMode == .fretboard
}

private func applyPageDisplayState() {
    targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()

    if isShowingFretboardMainContent {
        syncVerticalFretboardContentSizeConstraints()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
}

private func applyTopContentMode() {
    let showsStaff = pageDisplayState.topContentMode == .staff
    let activeConstraints = showsStaff
        ? topContentStaffConstraints
        : topContentTargetPromptConstraints
    let inactiveConstraints = showsStaff
        ? topContentTargetPromptConstraints
        : topContentStaffConstraints

    staffView.isHidden = !showsStaff
    targetNotePromptView.isHidden = showsStaff
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
}

private func applyMainContentMode() {
    let showsFretboard = isShowingFretboardMainContent
    let activeConstraints = showsFretboard
        ? mainContentFretboardConstraints
        : mainContentNaturalNoteStripConstraints
    let inactiveConstraints = showsFretboard
        ? mainContentNaturalNoteStripConstraints
        : mainContentFretboardConstraints

    fretboardHostView.isHidden = !showsFretboard
    naturalNoteStripView.isHidden = showsFretboard
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}

private func updateFretboardLayoutModeConstraints() {
    guard isShowingFretboardMainContent else {
        verticalFretboardHostHeightConstraint?.isActive = false
        horizontalFretboardDocumentWidthConstraint?.isActive = false
        horizontalFretboardContentWidthConstraint?.isActive = false
        verticalFretboardDocumentWidthConstraint?.isActive = false
        verticalFretboardContentWidthConstraint?.isActive = false
        fretboardViewportScrollView.hasHorizontalScroller = false
        scrollFretboardViewport(toX: 0)
        return
    }

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

## 当前边界

1. 阶段 4 已经完成页面主内容的切换接线，但 `naturalNoteStripView.onPitchClassTap` 还没有接入 controller 或 trainer 判题逻辑。
2. 本轮没有改 `SettingsPanelModel`、`SettingsPanelSnapshotBuilder` 或双平台 settings container；页面切换继续复用阶段 1 和阶段 2 已经完成的 shared settings 链路。

## 验证情况

1. 已检查 IDE 诊断，当前无新增 linter 问题：`NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`、`NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
2. 未执行完整 `xcodebuild` 编译验证；当前环境的 `xcode-select` 指向 Command Line Tools，无法直接完成完整 Xcode 工程构建。

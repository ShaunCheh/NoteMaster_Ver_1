# 20260402_133502_macos_side_layout_crash_system_fix

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260402_133502`
- 记录范围：实施 macOS 上 `Layout Preset = Side` 切换时 `EXC_BAD_ACCESS` 的系统性修复，重点收敛 `settings` 页面复用、`scene renderer` 职责边界、`controller` 布局提交时序，以及共享导航回归夹具
- 修改前基线：以本次修复实施前的工作区状态为准；本记录不放原始 `git diff`，只按真实功能变化记录“修改前 / 修改后”
- 修改目标：
  - 停留在 `Exercise > Layout` 子页时切换 `Stacked / Side / Single`，不再同步拆掉当前 page / row / chip
  - `settings` 同页更新时，只有内容变更，视图树不再发生整页、整行、整按钮 detach / reattach
  - 把 `scene rebuild`、`display refresh`、`layout flush` 三个阶段拆开，避免在同一条 action 调用栈里连续强制 layout
  - 增加共享导航验证，冻结“切 layout 不改 route、不回退当前子页”的契约
- 涉及文件：
  - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`

## 1. `macOSSettingsNavigatorView.swift`：同 route 更新不再整页 replace

- 修改前：`applyModelUpdate()` 只要 `navigationModel` 变化，就会执行一次 `replaceCurrentPage(...)`。即使 `didCurrentRouteChange == false`，当前 `Exercise > Layout` page 也会被拆掉并重建。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift
// 函数名: applyModelUpdate(), makePageView(for:)
// 功能说明: 修改前 route 未变化时仍然整页 replace，当前 settings page 会在 action 尚未返回时被 removeFromSuperview。
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

private func makePageView(for route: SettingsRouteID) -> NSView {
    guard let page = model.page(for: route) else {
        return NSView()
    }

    switch page.content {
    case let .index(routeItems):
        let indexPageView = macOSSettingsIndexPageView(routeItems: routeItems)
        indexPageView.onRouteSelected = { [weak self] selectedRoute in
            self?.push(selectedRoute)
        }
        return indexPageView
    case let .form(sections):
        let panelView = macOSSettingsPanelView(
            model: SettingsPanelModel(sections: sections)
        )
        panelView.onEvent = onEvent
        return panelView
    }
}
```

- 修改后：先判断当前 route 是否真的变了。若 route 没变，就复用现有 `macOSSettingsPanelView` / `macOSSettingsIndexPageView`，只原地更新 model；只有 route 真的切换时才 `replaceCurrentPage(...)`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift
// 函数名: applyModelUpdate(), makePageView(for:route:), updateCurrentPageIfPossible(with:route:)
// 功能说明: 修改后把“同 route 内容更新”和“真正的页面切换”拆开；route 不变时直接复用当前 page，避免当前事件源所在页面被同步拆树。
private func applyModelUpdate() {
    let previousPath = routeStack
    let reconciledPath = model.reconciledPath(routeStack)
    let transitionDirection = transitionDirection(
        from: previousPath,
        to: reconciledPath
    )
    let didCurrentRouteChange = previousPath.last != reconciledPath.last

    routeStack = reconciledPath
    let currentRoute = routeStack.last ?? model.rootRoute
    let currentPageModel = model.page(for: currentRoute)

    if !didCurrentRouteChange,
       let currentPageModel,
       updateCurrentPageIfPossible(
            with: currentPageModel,
            route: currentRoute
       ) {
        return
    }

    replaceCurrentPage(
        with: makePageView(for: currentPageModel, route: currentRoute),
        transitionDirection: transitionDirection,
        animated: didCurrentRouteChange && transitionDirection != .none
    )
}

private func makePageView(
    for page: SettingsPageModel?,
    route: SettingsRouteID
) -> NSView {
    guard let page else {
        let placeholderView = NSView()
        placeholderView.identifier = NSUserInterfaceItemIdentifier(
            SettingsNavigationAccessibility.pageIdentifier(for: route)
        )
        return placeholderView
    }

    switch page.content {
    case let .index(routeItems):
        let indexPageView = macOSSettingsIndexPageView(routeItems: routeItems)
        indexPageView.onRouteSelected = { [weak self] selectedRoute in
            self?.push(selectedRoute)
        }
        return indexPageView
    case let .form(sections):
        let panelView = macOSSettingsPanelView(
            model: SettingsPanelModel(sections: sections)
        )
        panelView.onEvent = onEvent
        return panelView
    }
}

private func updateCurrentPageIfPossible(
    with page: SettingsPageModel,
    route: SettingsRouteID
) -> Bool {
    switch (page.content, currentPageView) {
    case let (.index(routeItems), indexPageView as macOSSettingsIndexPageView):
        indexPageView.onRouteSelected = { [weak self] selectedRoute in
            self?.push(selectedRoute)
        }
        indexPageView.routeItems = routeItems
    case let (.form(sections), panelView as macOSSettingsPanelView):
        panelView.onEvent = onEvent
        panelView.model = SettingsPanelModel(sections: sections)
    default:
        return false
    }

    pageHostView.identifier = NSUserInterfaceItemIdentifier(
        SettingsNavigationAccessibility.pageIdentifier(for: route)
    )
    invalidateIntrinsicContentSize()
    needsLayout = true
    notifyPresentationStateChange()
    return true
}
```

## 2. `macOSSettingsPanelView.swift` / `macOSSettingsIndexPageView.swift`：同 identity / 同顺序时不再拆 row 与 button

- 修改前：即使 `section / row / chip / route button` 的实例身份和排列顺序都没变，`replaceArrangedSubviews(...)` 仍然会先把整组 `arrangedSubviews` 全部移除，再重新 add 回去。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名: replaceArrangedSubviews(in:with:), ChoiceRowView.replaceArrangedSubviews(in:with:)
// 功能说明: 修改前 panel 和 row 层的 stack 更新没有 identity 短路；只要 applyModel() 走到这里，就会整组 detach / reattach 当前 row 和 chip。
private func replaceArrangedSubviews(
    in stackView: NSStackView,
    with views: [NSView]
) {
    for arrangedSubview in stackView.arrangedSubviews {
        stackView.removeArrangedSubview(arrangedSubview)
        arrangedSubview.removeFromSuperview()
    }

    for view in views {
        if let parentStackView = view.superview as? NSStackView {
            parentStackView.removeArrangedSubview(view)
        }
        view.removeFromSuperview()
        stackView.addArrangedSubview(view)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift
// 函数名: replaceArrangedSubviews(in:with:)
// 功能说明: 修改前 index page 的 route button 复用层也没有短路，root / section 页面更新时同样会整组拆按钮。
private func replaceArrangedSubviews(
    in stackView: NSStackView,
    with views: [NSView]
) {
    for arrangedSubview in stackView.arrangedSubviews {
        stackView.removeArrangedSubview(arrangedSubview)
        arrangedSubview.removeFromSuperview()
    }

    for view in views {
        if let parentStackView = view.superview as? NSStackView {
            parentStackView.removeArrangedSubview(view)
        }
        view.removeFromSuperview()
        stackView.addArrangedSubview(view)
    }
}
```

- 修改后：新增 `arrangedSubviewsMatch(...)`。只要当前 `arrangedSubviews` 和下一轮 `views` 的实例身份顺序完全一致，就直接返回，不再拆掉当前 row / chip / route button。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名: replaceArrangedSubviews(in:with:), arrangedSubviewsMatch(_:_:)
// 功能说明: 修改后 panel / section / choiceRow / positionFilterRow 在“还是同一批 view”时直接跳过 stack 重建，避免当前 action 对应的 row 和 chip 被 detach。
private func replaceArrangedSubviews(
    in stackView: NSStackView,
    with views: [NSView]
) {
    guard !arrangedSubviewsMatch(stackView.arrangedSubviews, views) else {
        return
    }

    for arrangedSubview in stackView.arrangedSubviews {
        stackView.removeArrangedSubview(arrangedSubview)
        arrangedSubview.removeFromSuperview()
    }

    for view in views {
        if let parentStackView = view.superview as? NSStackView {
            parentStackView.removeArrangedSubview(view)
        }
        view.removeFromSuperview()
        stackView.addArrangedSubview(view)
    }
}

private func arrangedSubviewsMatch(
    _ currentViews: [NSView],
    _ nextViews: [NSView]
) -> Bool {
    currentViews.map(ObjectIdentifier.init) == nextViews.map(ObjectIdentifier.init)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift
// 函数名: replaceArrangedSubviews(in:with:), arrangedSubviewsMatch(_:_:)
// 功能说明: 修改后 index page 也沿用相同的 identity 短路策略，root / section 层 route button 不再因为同页内容刷新而整组重建。
private func replaceArrangedSubviews(
    in stackView: NSStackView,
    with views: [NSView]
) {
    guard !arrangedSubviewsMatch(stackView.arrangedSubviews, views) else {
        return
    }

    for arrangedSubview in stackView.arrangedSubviews {
        stackView.removeArrangedSubview(arrangedSubview)
        arrangedSubview.removeFromSuperview()
    }

    for view in views {
        if let parentStackView = view.superview as? NSStackView {
            parentStackView.removeArrangedSubview(view)
        }
        view.removeFromSuperview()
        stackView.addArrangedSubview(view)
    }
}

private func arrangedSubviewsMatch(
    _ currentViews: [NSView],
    _ nextViews: [NSView]
) -> Bool {
    currentViews.map(ObjectIdentifier.init) == nextViews.map(ObjectIdentifier.init)
}
```

## 3. `macOSExerciseSceneRenderer.swift`：把 scene render 和 display refresh 拆开

- 修改前：`render(...)` 每次都同时执行 `scene rebuild + 约束模式更新`；`handleLayoutPass()` 只负责做副作用，没有返回值，controller 只能同步连着多次强制 layout。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: render(presentationState:fretboardDisplayState:), handleLayoutPass()
// 功能说明: 修改前 renderer 把 scene 重建和 display mode 布局刷新绑在一起，controller 很难区分“需要重建树”和“只需要刷新指板布局”。
func render(
    presentationState: ExercisePresentationState,
    fretboardDisplayState: FretboardDisplayState
) {
    currentPresentationState = presentationState
    currentFretboardDisplayState = fretboardDisplayState

    rebuildSceneHierarchy(for: presentationState.scene.root)
    updateSurfaceVisibility()
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}

func handleLayoutPass() {
    syncVerticalFretboardContentSizeConstraints()
    updateFretboardViewportPresentation()
}
```

- 修改后：新增 `applyFretboardDisplayState(_:)`，把“scene tree 重建”和“只刷新指板布局模式”拆成两条链；同时让 `handleLayoutPass()` 返回布尔值，告诉 controller 本轮布局是否真的产生了额外约束/viewport 变化。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: render(presentationState:fretboardDisplayState:), applyFretboardDisplayState(_:), handleLayoutPass(), applyCurrentFretboardLayoutState()
// 功能说明: 修改后 scene 重建只跟 presentationState 走；displayState 变化可以单独刷新 renderer 的布局模式，避免无谓重建整棵 scene。
func render(
    presentationState: ExercisePresentationState,
    fretboardDisplayState: FretboardDisplayState
) {
    currentPresentationState = presentationState
    currentFretboardDisplayState = fretboardDisplayState

    rebuildSceneHierarchy(for: presentationState.scene.root)
    updateSurfaceVisibility()
    applyCurrentFretboardLayoutState()
}

func applyFretboardDisplayState(_ fretboardDisplayState: FretboardDisplayState) {
    currentFretboardDisplayState = fretboardDisplayState
    applyCurrentFretboardLayoutState()
}

func handleLayoutPass() -> Bool {
    let didUpdateContentSizeConstraints = syncVerticalFretboardContentSizeConstraints()
    let didUpdateViewportPresentation = updateFretboardViewportPresentation()
    return didUpdateContentSizeConstraints || didUpdateViewportPresentation
}

private func applyCurrentFretboardLayoutState() {
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: syncVerticalFretboardContentSizeConstraints(), updateFretboardViewportPresentation()
// 功能说明: 修改后 layout pass 会显式返回“本轮是否真的改了约束或 scroller 呈现”，供 controller 决定是否安排下一轮 deferred layout。
private func syncVerticalFretboardContentSizeConstraints() -> Bool {
    guard
        isShowingFretboard,
        currentFretboardDisplayState.displayMode == .vertical,
        let verticalFretboardDocumentWidthConstraint,
        let verticalFretboardContentWidthConstraint
    else {
        return false
    }

    var didUpdateConstraints = false
    let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
    let contentWidth = fretboardView.verticalContentSize.width
    let documentWidth = max(viewportWidth, contentWidth)

    if abs(verticalFretboardDocumentWidthConstraint.constant - documentWidth)
        > metrics.contentSizeTolerance {
        verticalFretboardDocumentWidthConstraint.constant = documentWidth
        didUpdateConstraints = true
    }

    if abs(verticalFretboardContentWidthConstraint.constant - contentWidth)
        > metrics.contentSizeTolerance {
        verticalFretboardContentWidthConstraint.constant = contentWidth
        didUpdateConstraints = true
    }

    return didUpdateConstraints
}

private func updateFretboardViewportPresentation() -> Bool {
    let needsHorizontalScroll = contentWidth > viewportWidth + metrics.contentSizeTolerance
    let didToggleScroller = fretboardViewportScrollView.hasHorizontalScroller
        != needsHorizontalScroll
    fretboardViewportScrollView.hasHorizontalScroller = needsHorizontalScroll
    // 这里只展示关键片段，省略 offset clamp 细节。
    return didToggleScroller
}
```

## 4. `macOSViewController.swift`：移除同步重入式 render / layout 链

- 修改前：`synchronizeExerciseCompositionState(...)` 每次都无条件写 `exercisePresentationState`；`renderExercisePresentationState()` 会再次 `applySettingsPanelState()` 并同步做两轮 `updateLayoutIfNeeded()` + `handleLayoutPass()`；`applyFretboardDisplayState()` 也会直接 `renderExercisePresentationState()`；`updateLayoutIfNeeded()` 则在当前事件栈里立刻 `view.layoutSubtreeIfNeeded()`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizeExerciseCompositionState(reason:), renderExercisePresentationState(), applyFretboardDisplayState(), updateLayoutIfNeeded()
// 功能说明: 修改前 controller 把 settings 刷新、scene 重建、layout pass 和根视图强制布局同步串在一条 action 调用栈里。
private func synchronizeExerciseCompositionState(reason: String) {
    let semanticPresentationState = ExerciseCompositionPolicy.makePresentation(
        from: exerciseCompositionPolicyInput
    )
    exercisePresentationState = semanticPresentationState

    if exerciseLayoutPreferences
        != semanticPresentationState.resolvedLayoutPreferences {
        exerciseLayoutPreferences = semanticPresentationState
            .resolvedLayoutPreferences
    }
}

private func renderExercisePresentationState() {
    updateSceneViewportHeightConstraint()
    exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
    applySettingsPanelState()
    updateLayoutIfNeeded()
    exerciseSceneRenderer.handleLayoutPass()
    updateLayoutIfNeeded()
}

private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    renderExercisePresentationState()
    updateLayoutIfNeeded()
    exerciseSceneRenderer.handleLayoutPass()
    updateLayoutIfNeeded()
}

private func updateLayoutIfNeeded() {
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()
}
```

- 修改后：`exercisePresentationState` 写入增加等值短路；`renderExercisePresentationState()` 不再反向刷新 settings，也不再在当前栈里同步做二次 layout；`applyFretboardDisplayState()` 改成只更新 `fretboardView` 和 `renderer.applyFretboardDisplayState(displayState)`；`updateLayoutIfNeeded()` 改成 deferred flush，等当前 action 返回后再合并执行一次 `layoutSubtreeIfNeeded()`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizeExerciseCompositionState(reason:), renderExercisePresentationState(), applyFretboardDisplayState(), viewDidLayout()
// 功能说明: 修改后 controller 只在必要时提交新的 presentationState；scene render、display refresh、layout pass 被拆到更清晰的阶段边界上。
private func synchronizeExerciseCompositionState(reason: String) {
    let semanticPresentationState = ExerciseCompositionPolicy.makePresentation(
        from: exerciseCompositionPolicyInput
    )
    if exercisePresentationState != semanticPresentationState {
        exercisePresentationState = semanticPresentationState
    }

    if exerciseLayoutPreferences
        != semanticPresentationState.resolvedLayoutPreferences {
        exerciseLayoutPreferences = semanticPresentationState
            .resolvedLayoutPreferences
    }
}

override func viewDidLayout() {
    super.viewDidLayout()
    if exerciseSceneRenderer.handleLayoutPass() {
        updateLayoutIfNeeded()
    }
}

private func renderExercisePresentationState() {
    updateSceneViewportHeightConstraint()
    exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
    updateLayoutIfNeeded()
}

private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    exerciseSceneRenderer.applyFretboardDisplayState(displayState)
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    updateLayoutIfNeeded()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: updateLayoutIfNeeded(), flushDeferredLayoutPassIfNeeded()
// 功能说明: 修改后根视图 layout 改成“先标记 needsLayout，再安排下一轮主线程 flush”；不再在当前 settings action 栈里直接强制 layoutSubtreeIfNeeded。
private func updateLayoutIfNeeded() {
    guard isViewLoaded else {
        return
    }

    view.needsLayout = true
    guard !isDeferredLayoutPassScheduled else {
        return
    }

    isDeferredLayoutPassScheduled = true
    DispatchQueue.main.async { [weak self] in
        self?.flushDeferredLayoutPassIfNeeded()
    }
}

private func flushDeferredLayoutPassIfNeeded() {
    guard isViewLoaded, isDeferredLayoutPassScheduled else {
        return
    }

    isDeferredLayoutPassScheduled = false
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()
}
```

## 5. `SettingsNavigationValidation.swift`：冻结 `Exercise > Layout` 子页的 route 稳定契约

- 修改前：共享导航验证只覆盖“路径回退到最近父级”“各 route 标题稳定”等场景，还没有明确冻结“停留在 `Exercise > Layout` 子页时切换 layout 选项，当前 path 不应回退或改写”的契约。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改前 validation 没有专门覆盖“Exercise > Layout 子页内切换 layout 仍然保持同一路由”的共享边界。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "reconciled_path_falls_back_to_existing_parent",
            validate: validateReconciledPathFallsBackToExistingParent
        ),
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
        "确认 `Accessory Presentation` 里的 `Docked / Floating / Collapsible` 都可进入且可选；只有切到 `Collapsible` 后才启用 `Accessory Expanded`。",
        "确认 iOS / macOS 上的标题、返回、关闭按钮布局与转场方向一致，没有双层导航条或页面闪跳。"
    ]
}
```

- 修改后：新增 `exercise_layout_route_remains_stable_across_choice_updates` 夹具，并把相同场景追加到手工回归清单里，冻结“切 layout 不回退当前子页”的共享导航语义。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:), validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates()
// 功能说明: 修改后共享 validation 显式校验 Exercise > Layout 深层 route 在 layout 选项切换前后保持稳定，并检查切到 Side 后页面仍暴露正确的 Layout Preset 选中态。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "reconciled_path_falls_back_to_existing_parent",
            validate: validateReconciledPathFallsBackToExistingParent
        ),
        SettingsNavigationValidationFixture(
            name: "exercise_layout_route_remains_stable_across_choice_updates",
            validate: validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates
        ),
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
        "确认 `Accessory Presentation` 里的 `Docked / Floating / Collapsible` 都可进入且可选；只有切到 `Collapsible` 后才启用 `Accessory Expanded`。",
        "停留在 `Exercise > Layout` 子页时直接切换 `Stacked / Side / Single`，确认当前页不会闪跳、不会被重建回上一层，且选中态立即更新。",
        "确认 iOS / macOS 上的标题、返回、关闭按钮布局与转场方向一致，没有双层导航条或页面闪跳。"
    ]
}

static func validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "exercise_layout_route_remains_stable_across_choice_updates"
    var issues: [SettingsNavigationValidationIssue] = []

    let initialStateContext = SettingsPanelStateContext.default
    let initialNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: initialStateContext
    )
    let initialLayoutPath = initialNavigationModel.reconciledPath([
        .root,
        .section(.exercise),
        .exerciseLayout
    ])

    var sideBySideStateContext = initialStateContext
    SettingsPanelEvent.triggerAction(.setLayoutPresetSideBySide).apply(
        to: &sideBySideStateContext
    )
    let sideBySideNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: sideBySideStateContext
    )
    let sideBySideLayoutPath = sideBySideNavigationModel.reconciledPath(
        initialLayoutPath
    )

    if sideBySideLayoutPath != initialLayoutPath {
        issues.append(
            issue(
                fixtureName,
                "在 Exercise > Layout 子页切换 layout 选项时，reconciledPath 不应把当前路径回退或改写到其它 route。"
            )
        )
    }
    // 这里只展示关键片段，省略 layoutPage / layoutRow 选中态断言细节。
    return issues
}
```

## 6. 验证结果

- `ReadLints`：本次修改涉及的文件无新增 lint 问题
- 构建验证：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build`：通过
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build`：通过
- 手工回归建议：
  - 打开 macOS App，进入 `Exercise > Layout`
  - 依次点击 `Stacked -> Side -> Stacked`
  - 观察当前子页是否保持不跳页、不闪回上一层
  - 观察日志是否出现 `navigator applyModelUpdate reuse currentPage ...`，且不再出现旧的 `installCurrentPageView remove oldPage ... containsActiveSender=true`

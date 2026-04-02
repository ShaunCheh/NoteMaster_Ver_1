# 20260402_161956_macos_side_layout_root_cause_and_final_fix

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260402_161956`
- 记录范围：macOS 上 `Layout Preset` 从 `stacked` 切到 `sideBySide` 时的 `EXC_BAD_ACCESS`，以及本轮根因收敛、日志证据、最终修复方案
- 最终结果：手工回归已确认 `stacked -> sideBySide` 不再崩溃
- 本记录不放原始 `git diff`，只按真实功能变化记录“修改前 / 修改后”
- 本轮实际落地文件：
  - `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`

## 1. 问题现象与最终判断

- 现象：macOS 上 `positionPrompt + fretboardToNaturalNoteStrip + stacked -> sideBySide` 时，控制器日志已经打印到 `renderExercisePresentationState end`，但应用仍在随后崩溃。
- 关键判断：这说明崩溃点已经不在 `settings` action 分发，也不在 `renderer.render(...)` 本身，而是在 render 结束之后的 AppKit 布局阶段。
- 最终根因不是单点 bug，而是 3 层问题叠加：
  1. `renderer` 在 layout 切换时整树重建，并重挂真实 surface view，制造危险中间态。
  2. `controller` 在 render 后继续同步强刷 layout，放大了危险中间态。
  3. `natural note strip` 在 `verticalRail + fitContent` 场景下，`intrinsicContentSize` 内部调用 `layoutSubtreeIfNeeded()`，导致 AppKit 在查询 intrinsic size 时发生可重入布局；而 `sideBySide` 正好是唯一稳定触发这条路径的布局。

## 2. 日志如何证明问题已经收敛到布局阶段

```text
# 日志来源: macOS 手工回归控制台 | 阶段: 最终定位的关键证据
[SettingsTrace][macOS] event=1 end state=... layout=sideBySide ...
[SettingsTrace][macOS] choiceRow dispatch after action=setLayoutPresetSideBySide ...
[Startup][macOSVC] renderExercisePresentationState begin trainerDisplay=positionPrompt ... layout=sideBySide ...
[Startup][macOSVC] renderExercisePresentationState end trainerDisplay=positionPrompt ... layout=sideBySide ...
# 结论:
# 1. settings action 已经完整返回
# 2. renderer.render(...) 已经完整结束
# 3. 崩溃发生在其后的 AppKit 自然布局阶段，而不是 action dispatch 或 render 函数体内部
```

- 这段日志把故障窗口缩小到了 `render end` 之后。
- 因为之前显式崩点已经多次落在 `layoutSubtreeIfNeeded()` 一类强制布局调用上，所以这次继续向“谁在自然布局阶段做了可重入布局”追，才最终收敛到 `macOSNaturalNoteStripView.intrinsicContentSize`。

## 3. 为什么“加了一个 side 模式”就会炸

`sideBySide` 并不是简单把上下改成左右。对 `positionPrompt + fretboardToNaturalNoteStrip` 来说，`side` 会把右侧的 `natural note strip` 投影成 `verticalRail + fitContent`，这和 `stacked` 的横条模式完全不是同一条布局路径。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数: makeSideBySideSceneNode(from:preferences:)
// 功能说明: `positionPrompt + sideBySide` 会把右侧 answer surface 投影成 `verticalRail + fitContent`；
// 这正是 side 独有的布局语义，也是后续 intrinsic size 查询的触发点。
private static func makeSideBySideSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    switch preferences.compositionPreset {
    case .fretboardToNaturalNoteStrip:
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.prompt),
                    mainAxisSizing: .weighted(1)
                ),
                ExerciseSceneSplitChild(
                    node: .surface(
                        sceneSurfaces.answer.withPresentationStyle(.verticalRail)
                    ),
                    mainAxisSizing: .fitContent
                )
            ]
        )
    // ... 其他 composition 省略 ...
    }
}
```

- `stacked` 下，`natural note strip` 是底部横条，主要走纵向高度语义。
- `sideBySide` 下，`natural note strip` 变成右侧 rail，需要 AppKit 查询它的 intrinsic width。
- 也就是说，“为什么一加 side 就炸”的答案是：`side` 不是多一个 preset 这么简单，它会把 `natural note strip` 推进到 `verticalRail + fitContent` 这条此前没有稳定跑过的约束路径。

## 4. 修改一：把 renderer 从“整树重建 + 重挂真实 NSView”改成“稳定 slot / host identity”

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数: render(...), rebuildSceneHierarchy(...), renderSurface(...), embed(...)
// 修改前说明: 每次 scene 变化都整树重建，并把真实 surface view 从旧父视图卸下后重新挂到新 host。
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

private func rebuildSceneHierarchy(
    for rootNode: ExerciseSceneNode
) {
    NSLayoutConstraint.deactivate(activeSceneConstraints)
    activeSceneConstraints = []
    sceneContentView.subviews.forEach { $0.removeFromSuperview() }

    let rootHostView = NSView()
    rootHostView.translatesAutoresizingMaskIntoConstraints = false
    sceneContentView.addSubview(rootHostView)
    activeSceneConstraints.append(contentsOf: [
        rootHostView.leadingAnchor.constraint(equalTo: sceneContentView.leadingAnchor),
        rootHostView.trailingAnchor.constraint(equalTo: sceneContentView.trailingAnchor),
        rootHostView.topAnchor.constraint(equalTo: sceneContentView.topAnchor),
        rootHostView.bottomAnchor.constraint(equalTo: sceneContentView.bottomAnchor)
    ])
    render(node: rootNode, in: rootHostView)
    NSLayoutConstraint.activate(activeSceneConstraints)
}

private func renderSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: NSView
) {
    guard let surfaceView = view(for: surface.id) else {
        return
    }
    embed(
        surfaceView,
        in: hostView,
        contentInsets: contentInsets(for: surface)
    )
}

private func embed(
    _ childView: NSView,
    in hostView: NSView,
    contentInsets: NSEdgeInsets = .zero
) {
    childView.removeFromSuperview()
    childView.translatesAutoresizingMaskIntoConstraints = false
    hostView.addSubview(childView)
    // ... 约束省略 ...
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数: render(...), syncSceneHierarchy(...), sync(...), syncSurface(...), ensureSceneHost(...)
// 修改后说明: 引入稳定的 host path 与 surface slot；真实 surface 只进入 slot 一次，
// layout 切换时只同步空 host 树与约束，不再在 stacked/side 切换时反复重挂真实视图。
private final class SurfaceSlotView: NSView {
    let surfaceID: ExerciseSurfaceID
    private var hostedViewConstraints: [NSLayoutConstraint] = []

    func install(_ childView: NSView) {
        guard childView.superview !== self else {
            return
        }

        NSLayoutConstraint.deactivate(hostedViewConstraints)
        hostedViewConstraints = []
        childView.removeFromSuperview()
        childView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(childView)
        hostedViewConstraints = [
            childView.leadingAnchor.constraint(equalTo: leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: trailingAnchor),
            childView.topAnchor.constraint(equalTo: topAnchor),
            childView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        NSLayoutConstraint.activate(hostedViewConstraints)
    }
}

@discardableResult
func render(
    presentationState: ExercisePresentationState,
    fretboardDisplayState: FretboardDisplayState
) -> Bool {
    currentPresentationState = presentationState
    currentFretboardDisplayState = fretboardDisplayState

    let didChangeStructure = syncSceneHierarchy(for: presentationState.scene.root)
    updateSurfaceVisibility()
    applyCurrentFretboardLayoutState()
    return didChangeStructure
}

@discardableResult
private func syncSceneHierarchy(
    for rootNode: ExerciseSceneNode
) -> Bool {
    NSLayoutConstraint.deactivate(activeSceneConstraints)
    activeSceneConstraints = []

    var state = SceneSyncState()
    sync(node: rootNode, in: rootHostView, path: .root, state: &state)
    if pruneUnusedSceneHosts(requiredPaths: state.requiredHostPaths) {
        state.didChangeStructure = true
    }
    syncSurfaceSlots(activeSurfaceOrder: state.activeSurfaceOrder)
    NSLayoutConstraint.activate(activeSceneConstraints)
    return state.didChangeStructure
}

private func syncSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: SceneHostView,
    state: inout SceneSyncState
) {
    guard let slotView = surfaceSlotViews[surface.id] else {
        return
    }

    if !state.activeSurfaceOrder.contains(surface.id) {
        state.activeSurfaceOrder.append(surface.id)
    }
    slotView.isHidden = false
    placeSurfaceSlot(
        slotView,
        in: hostView,
        contentInsets: contentInsets(for: surface)
    )
}
```

### 4.3 这一刀解决了什么

- 解决的不是“side 的某个约束值”，而是 renderer 的更新方式。
- `staffView`、`targetNotePromptView`、`fretboardHostView`、`naturalNoteStripView`、`pianoAccessoryView` 不再在 `stacked <-> sideBySide` 间换父视图。
- AppKit 不再需要在同一次 preset 切换里同时处理“旧树拆掉、真实 view 脱离、再挂到新树”的危险中间态。

## 5. 修改二：controller 不再在 render 之后同步强刷 subtree layout

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: requestSceneLayoutSettlement(), layoutExerciseSubtreeIfNeeded(), settleSceneLayoutIfNeeded(maxPassCount:)
// 修改前说明: render 之后仍会同步执行 `layoutSubtreeIfNeeded()`，并在同一轮 settlement 里重复强刷多次。
private func requestSceneLayoutSettlement() {
    isSceneLayoutSettlementDirty = true
    guard isViewLoaded, hasRenderedExerciseSceneOnce else {
        return
    }

    if canSettleSceneLayoutNow {
        settleSceneLayoutIfNeeded()
    } else {
        scheduleSceneLayoutSettlementIfNeeded()
    }
}

private func layoutExerciseSubtreeIfNeeded() {
    exerciseSceneRenderer.sceneContainerView.needsLayout = true
    exerciseSceneRenderer.sceneContainerView.layoutSubtreeIfNeeded()
}

private func settleSceneLayoutIfNeeded(maxPassCount: Int = 3) {
    guard isSceneLayoutSettlementDirty, canSettleSceneLayoutNow else {
        return
    }

    var didUpdateDynamicLayout = false
    for _ in 0..<maxPassCount {
        layoutExerciseSubtreeIfNeeded()
        didUpdateDynamicLayout = exerciseSceneRenderer.handleLayoutPass()
        if !didUpdateDynamicLayout {
            break
        }
    }

    if didUpdateDynamicLayout {
        layoutExerciseSubtreeIfNeeded()
    }
}
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: renderExercisePresentationState(), requestSceneLayoutSettlement(), awaitSceneLayoutPass(), settleSceneLayoutIfNeeded()
// 修改后说明: renderer 会返回“是否发生结构性变化”；controller 不再同步 flush subtree，
// 而是等待 AppKit 下一次自然 layout pass 后再做动态约束收敛。
@discardableResult
private func renderExercisePresentationState() -> Bool {
    updateSceneViewportHeightConstraint()
    let didChangeSceneStructure = exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
    hasRenderedExerciseSceneOnce = true
    return didChangeSceneStructure
}

private func requestSceneLayoutSettlement() {
    isSceneLayoutSettlementDirty = true
    guard isViewLoaded, hasRenderedExerciseSceneOnce else {
        return
    }

    awaitSceneLayoutPass()
}

private func requestDeferredSceneLayoutSettlement() {
    isSceneLayoutSettlementDirty = true
    guard isViewLoaded, hasRenderedExerciseSceneOnce else {
        return
    }

    awaitSceneLayoutPass()
}

private func awaitSceneLayoutPass() {
    isAwaitingSceneLayoutPass = true
    view.needsLayout = true
    exerciseSceneRenderer.sceneContainerView.needsLayout = true
}

private func settleSceneLayoutIfNeeded() {
    guard isSceneLayoutSettlementDirty, canSettleSceneLayoutNow else {
        return
    }
    guard !isAwaitingSceneLayoutPass else {
        return
    }

    let didUpdateDynamicLayout = exerciseSceneRenderer.handleLayoutPass()
    if didUpdateDynamicLayout {
        isSceneLayoutSettlementDirty = true
        awaitSceneLayoutPass()
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: commitPendingPresentationTransactionIfNeeded()
// 修改后说明: 只有 renderer 真发生结构性变化时，scene settlement 才按 deferred 策略处理；
// 纯约束刷新不再一刀切延后。
if transaction.scenePresentation {
    let didChangeSceneStructure = renderExercisePresentationState()
    shouldRequestSceneLayoutSettlement = true
    requiresDeferredSceneLayoutSettlement =
        requiresDeferredSceneLayoutSettlement || didChangeSceneStructure
}
```

### 5.3 这一刀解决了什么

- 旧版 controller 会在 render 之后立即把 `sceneContainerView` 强刷一遍，进一步放大 renderer 中间态。
- 新版 controller 只做两件事：
  1. 标记“需要下一次自然 layout pass”
  2. 在 AppKit 自己布局完之后，再做一次 `handleLayoutPass()` 收敛
- 这样显式崩点 `layoutSubtreeIfNeeded()` 被彻底拔掉，危险窗口明显缩小。

## 6. 修改三：修掉 side 独有的最终触发点 `intrinsicContentSize -> layoutSubtreeIfNeeded()`

### 6.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数: intrinsicContentSize
// 修改前说明: intrinsic size 查询内部主动执行 `layoutSubtreeIfNeeded()`；
// 当 side 模式把 strip 投影为 `verticalRail + fitContent` 时，AppKit 查询 rail 宽度就会触发可重入布局。
override var intrinsicContentSize: NSSize {
    layoutSubtreeIfNeeded()
    let stackSize = stackView.fittingSize
    switch layoutMode {
    case .horizontalStrip:
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
        )
    case .verticalRail:
        return NSSize(
            width: Style.contentInsets.left + stackSize.width + Style.contentInsets.right,
            height: NSView.noIntrinsicMetric
        )
    }
}
```

### 6.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数: intrinsicContentSize, tallestButtonIntrinsicHeight, widestButtonIntrinsicWidth
// 修改后说明: intrinsic size 改成纯计算，不再在 getter 中触发布局；
// `verticalRail + fitContent` 只读取按钮自身的 intrinsic size，避免 AppKit 可重入。
override var intrinsicContentSize: NSSize {
    switch layoutMode {
    case .horizontalStrip:
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top
                + tallestButtonIntrinsicHeight
                + Style.contentInsets.bottom
        )
    case .verticalRail:
        return NSSize(
            width: Style.contentInsets.left
                + widestButtonIntrinsicWidth
                + Style.contentInsets.right,
            height: NSView.noIntrinsicMetric
        )
    }
}

private var tallestButtonIntrinsicHeight: CGFloat {
    buttons.reduce(0) { partialResult, button in
        max(partialResult, button.intrinsicContentSize.height)
    }
}

private var widestButtonIntrinsicWidth: CGFloat {
    buttons.reduce(0) { partialResult, button in
        max(partialResult, button.intrinsicContentSize.width)
    }
}
```

### 6.3 这一刀为什么是最终解

- 经过前两刀后，日志已经证明：
  - settings action 返回是安全的
  - renderer.render(...) 返回也是安全的
- 剩下唯一稳定触发 side 特有差异的，就是 `verticalRail + fitContent`。
- `natural note strip` 恰好在这条路径里需要提供 intrinsic width，而旧代码在 intrinsic getter 中主动 layout，自身形成可重入。
- 把这里改成纯尺寸计算后，`stacked -> sideBySide` 终于稳定通过，这和日志推导完全一致。

## 7. 最终根因结论

本次问题的根因链可以压缩成一句话：

> `sideBySide` 让 `natural note strip` 进入 `verticalRail + fitContent` 场景；旧 renderer 又会在切换时整树重建并重挂真实 surface，旧 controller 还会继续同步强刷 subtree，而旧 `macOSNaturalNoteStripView` 又在 `intrinsicContentSize` 里主动 layout，最终在 AppKit 自然布局阶段形成可重入与危险中间态叠加，触发 `EXC_BAD_ACCESS`。

换句话说，这不是“side 模式本身不稳定”，而是：

1. side 激活了此前没有被稳定约束过的 rail 场景。
2. rail 场景要求 fit-content。
3. fit-content 会查询 intrinsic size。
4. 旧 intrinsic size 实现带 layout 副作用。
5. 旧 renderer/controller 又让这次查询发生在最危险的视图树更新窗口里。

## 8. 最终方案总结

- `renderer`：
  - 引入稳定的 `SceneHostPath` / `SceneHostView` / `SurfaceSlotView`
  - 真实 surface view 不再在 `stacked <-> sideBySide` 时换父视图
  - scene 切换只同步空 host 树与约束
- `controller`：
  - `renderExercisePresentationState()` 返回结构性变更结果
  - 去掉同步 `layoutSubtreeIfNeeded()` 强刷
  - 改成等待 AppKit 自然 layout pass，再收敛动态约束
- `natural note strip`：
  - 去掉 `intrinsicContentSize` 内部的 `layoutSubtreeIfNeeded()`
  - 改成纯 intrinsic 计算

## 9. 验证结果

- 构建验证：
  - 已执行 `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=macOS' build -quiet`
  - 结果：构建通过
- 运行验证：
  - 手工回归确认 `stacked -> sideBySide` 不再崩溃
- 当前已知非本次问题项：
  - 仓库仍存在 2 个既有 Swift 6 warning：
    - `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
    - `NoteMaster_Ver_1/Shared/Staff/StaffAccidentalContext.swift`
  - 这两项与本次 side 崩溃修复无直接关系，本轮未处理

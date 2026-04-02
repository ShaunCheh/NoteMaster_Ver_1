---
name: macOS renderer identity
overview: 把 macOS exercise renderer 从“整树重建 + 重挂真实 NSView”改成“稳定 slot host + 增量约束同步”，从根上消除 `stacked <-> sideBySide` 切换时的 AppKit 危险中间态。controller 保留 transaction/settlement 框架，但只在 renderer 发生结构性变化时再走 deferred settlement。
todos:
  - id: slot-host-identity-model
    content: 在 `macOSExerciseSceneRenderer` 设计稳定 surface slot / host identity 模型，禁止真实 surface view 在 layout 切换时换父视图
    status: pending
  - id: replace-full-rebuild
    content: 把 `rebuildSceneHierarchy` 改成按 nodePath 增量同步 host 树，并处理 split/overlay/collapsible 的约束复用
    status: pending
  - id: make-embed-idempotent
    content: 重写 `embed` 与 slot 内约束管理，让同父场景下只更新 inset/约束而不再 `removeFromSuperview()`
    status: pending
  - id: tighten-controller-contract
    content: 让 controller 依据 renderer 的结构性变更结果决定 deferred 或 immediate settlement，保留现有 transaction 主框架
    status: pending
  - id: verify-side-toggle-regressions
    content: 重点验证 `stacked <-> sideBySide`、verticalRail、fitContent、live resize 和 settings 子页停留切换的回归边界
    status: pending
isProject: false
---

# macOS Renderer Identity Fix

## 目标

- 把 [NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift) 从全量 `rebuildSceneHierarchy` 改成稳定 host/surface 身份的增量同步。
- 保留 [NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift) 现有的 presentation transaction 主框架，但不再把所有 `scenePresentation` 都当成必须 deferred 的危险操作。

## 根因边界

- 现在的 crash 已经从“settings action 栈内同步 render”收缩到 render 之后的 layout flush，说明 controller 侧旧的时序问题基本被隔离了，剩下的是 renderer 策略本身。
- [NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift) 里 `render()` 总是调用 `rebuildSceneHierarchy(...)`，而 `embed(...)` 总是 `removeFromSuperview()` 再 `addSubview()`；`fretboardHostView`、`naturalNoteStripView`、`staffView`、`targetNotePromptView`、`pianoAccessoryView` 这些真实 surface view 会在 layout 切换时被重挂。
- `sideBySide` 不是简单换方向，它会把 `positionPrompt + fretboardToNaturalNoteStrip` 升级成 `horizontal split + weighted(1) + fitContent + verticalRail`；也就是会第一次把最敏感的混合几何语义压到“重挂真实 view”的路径上。

```swift
// NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
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
```

## 实施步骤

### 1. 建立稳定 surface slot 层

- 在 [NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift) 内为每个 `ExerciseSurfaceID` 建立长期存在的 leaf slot host。
- 真实 surface view 只在首次装配时挂入各自 slot，之后不再更换父视图。
- 明确保留现有 `sceneContainerView`、`sceneContentView`、`fretboardHostView` 以及其 `NSScrollView` 静态层级，尤其不能再搬动 `fretboardHostView` 所在滚动子树。

### 2. 把全量重建改成结构同步

- 用 `syncSceneHierarchy(with:)` 取代 `rebuildSceneHierarchy(for:)` 的“清空 `sceneContentView.subviews` + 新建 root host”模式。
- `renderSplit`、`renderOverlay`、`renderCollapsible` 改成复用 host node；只有 scene 结构真的变化时才增删中间 host，日常只更新约束、排序和 visibility。
- 设计稳定 key：按 `nodePath` / split index / overlay role 缓存 host，避免 side 和 stacked 来回切换时反复新建中间 `NSView`。

### 3. 让 `embed` 幂等化

- 如果 `childView.superview === slotHost`，只更新 inset 约束，不再 `removeFromSuperview()`。
- 把 slot 内部约束与 `activeSceneConstraints` 分开管理，避免为了更新 scene 结构把真实 view 的挂载约束一起拆掉。
- 明确 `fretboardHostView`、`naturalNoteStripView` 的“装配一次、只改约束”契约。

### 4. 收敛 mixed sizing / rail 语义

- 重点复核 `sideBySide + fretboardToNaturalNoteStrip` 的 `weighted(1) + fitContent + verticalRail`，确保 host 复用后会正确重置 hugging/compression/multiplier 约束，不残留 stacked 态优先级。
- 明确 `hidden` 与 `absent` 的边界：slot 可以长期存在，但布局参与仍必须由 scene membership 决定，不能因为 slot 常驻就把本应 absent 的 surface 变成 hidden 占位。
- 保证 overlay / collapsible / accessory 场景下，中间 host 的增量更新不会留下重复激活的旧约束。

### 5. 收紧 controller 和 renderer 的契约

- 让 renderer 在一次 `render` 之后返回或记录“是否发生结构性重排”。
- 在 [NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift) 的 transaction 提交路径里，不再把所有 `scenePresentation` 都一刀切成 `requestDeferredSceneLayoutSettlement()`；只在 renderer 报告结构性变化时 defer，普通增量更新可以直接 `requestSceneLayoutSettlement()`。
- 保留现有 `performPresentationTransaction`、`settingsMutationDepth`、`settleSceneLayoutIfNeeded()` 主框架，不继续在 controller 侧叠加补丁式护栏。

## 验证范围

- 首先锁定 `positionPrompt + sideBySide` 的 `stacked -> side -> stacked -> side` 往返切换，确认不再崩溃。
- 再覆盖 `verticalRail` 首屏可见性、`fitContent` 宽度、live resize、settings 停留在 `Exercise > Layout` 子页时切换 layout、`naturalNoteStrip` 答题行为。
- 若需要补自动化，只考虑在 [NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift) 周边补对 renderer 契约真正有价值的 focused 验证，不改 shared scene semantics 本身。

## 预期影响文件

- 主改：[NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift)
- 配套：[NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift)
- 验证边界：[NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift)
- 不计划主动改动 settings 面板和 shared composition policy，除非在实施过程中发现它们与 renderer 身份模型存在硬耦合。


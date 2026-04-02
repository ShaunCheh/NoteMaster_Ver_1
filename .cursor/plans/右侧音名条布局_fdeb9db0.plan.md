---
name: 右侧音名条布局
overview: 基于已选定的方案 2 + 方案 3，把 `fretboardToNaturalNoteStrip + sideBySide` 收敛为“左侧指板、右侧竖排 NoteStrip rail、二者同高且占满可视高度”的 shared-first 架构改造。计划按 shared 契约、composition policy、renderer 主轴尺寸分配、双平台 NoteStrip 竖排视图、viewport 收口与回归验证分阶段推进。
todos:
  - id: freeze-invariants
    content: 补 shared validation，冻结当前 stacked/sideBySide 相关不变量，为主轴尺寸契约升级建立回归基线
    status: pending
  - id: upgrade-scene-contract
    content: 升级 ExerciseScene shared 契约，引入 surface presentation style 与主轴尺寸语义，替代现有 weight+sizing 的轴向割裂模型
    status: pending
  - id: emit-rail-scene
    content: 让 ExerciseCompositionPolicy 为 fretboardToNaturalNoteStrip 的 sideBySide 场景显式发出 vertical rail 语义，并保持其它布局路径不变
    status: pending
  - id: refactor-renderers
    content: 重构 iOS/macOS scene renderer 的 split 分配逻辑，让 horizontal split 支持 fitContent/fixed rail，weighted 子项吃剩余宽度
    status: pending
  - id: vertical-strip-views
    content: 让 iOS/macOS NaturalNoteStripView 支持 horizontalStrip 与 verticalRail 两种内部排布，并正确提供 intrinsic size
    status: pending
  - id: viewport-and-regression
    content: 用 shared helper 收口双平台 viewport height 约束，并完成 validation、双平台构建与手工回归
    status: pending
isProject: false
---

# 方案 2 + 方案 3 分阶段计划

## 目标

- 把 `[NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift)` 里已有的 `compositionPreset == .fretboardToNaturalNoteStrip` + `layoutPreset == .sideBySide`，真正落地成“左侧 `fretboard`、右侧竖排 `naturalNoteStrip` rail、两者同高且占满 viewport 高度”。
- 让“`naturalNoteStrip` 是底部横条还是右侧竖条”成为 shared scene 语义，而不是 UIKit/AppKit 层的硬编码分支。
- 让 horizontal split 也拥有和 vertical split 对称的主轴尺寸语义，避免右侧 rail 继续被 `weight` 拉成半屏。

## 默认决策

- 采用 `ExerciseSurfacePresentationStyle` 表达 surface 的展示形态，首批只引入 `standard`、`horizontalStrip`、`verticalRail`。
- 采用 axis-agnostic 的主轴尺寸语义替代当前 `weight + sizing` 组合；首版 contract 直接支持 `weighted(Double)`、`fitContent`、`fixed(Double)`。
- 当前需求的默认落地值是：左侧 `fretboard = .weighted(1)`，右侧 `naturalNoteStrip = .fitContent`。
- 不新增新的 `ExerciseSurfaceKind`，不新增新的 `ExerciseLayoutPreset`，不把“右侧 rail”做成新的 surface 变体。
- 不主动扩展 legacy `PageDisplayState` 对横向 rail 的投影；只有在实现阶段发现仍有主路径强依赖时，才单独补 bridge。

## 阶段关系

```mermaid
flowchart LR
    phase0["阶段 0<br/>冻结当前不变量"] --> phase1["阶段 1<br/>升级 shared scene 契约"]
    phase1 --> phase2["阶段 2<br/>composition policy 发出 rail 语义"]
    phase2 --> phase3["阶段 3<br/>renderer 支持主轴尺寸分配"]
    phase3 --> phase4["阶段 4<br/>双平台 NoteStrip 竖排视图"]
    phase4 --> phase5["阶段 5<br/>viewport 收口与回归验证"]
```

## 阶段 0：冻结当前不变量

- 目标：在改 shared contract 之前，先把现在已经成立的 `stacked`、`sideBySide`、`positionPrompt` 路由行为冻结下来，避免后续把回归误认为新语义。
- 主要文件：[NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift)
- 关键动作：补一组只针对当前问题域的 validation fixture，明确以下行为必须保留。
- `fretboardToNaturalNoteStrip + stacked` 仍然是 vertical split，且下方 strip 仍走现有 vertical fit-content 逻辑。
- `fretboardToNaturalNoteStrip + sideBySide` 目前已经是合法 scene，且 `ExerciseAnswerRouter` 仍允许从 `naturalNoteStrip` 路由 answer。
- `targetPromptToFretboard + sideBySide`、`staffToFretboard + sideBySide` 不应被新的 rail 语义污染。
- 完成标准：shared validation 能区分“本次要改变的是 `fretboardToNaturalNoteStrip + sideBySide` 的展示语义和宽度语义”，而不是把所有 `sideBySide` 都改成 rail 模式。

## 阶段 1：升级 shared scene 契约

- 目标：把“surface 展示样式”和“split 主轴尺寸语义”正式提升为 shared contract，避免平台层继续猜布局语义。
- 主要文件：[NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift)
- 关键动作：为 `ExerciseSurfaceNode` 增加 `presentationStyle`，并引入 `ExerciseSurfacePresentationStyle`。
- `standard`：普通 surface。
- `horizontalStrip`：底部横向 `naturalNoteStrip`。
- `verticalRail`：右侧纵向 `naturalNoteStrip`。
- 关键动作：把 `ExerciseSceneSplitChild` 从当前的 `weight` + `sizing` 升级为统一的主轴尺寸语义，例如 `mainAxisSizing`。
- `weighted(Double)`：参与当前主轴上的剩余空间比例分配。
- `fitContent`：沿当前主轴按内容收口。
- `fixed(Double)`：沿当前主轴使用固定尺寸；首批 policy 不主动发出，但 renderer 和 validator 一次到位支持。
- 关键动作：补 shared helper，替代当前只针对 vertical 的 `hasVerticalFitContentSplit`，增加更通用的查询能力，例如 `requiresViewportPinnedHeight`、`hasMixedMainAxisSizing(along:)` 一类 helper。
- 关键动作：避免 `ExerciseSurfaceNode` 的静态预制实例膨胀成多份 style 变体；优先通过 factory 或 `withPresentationStyle(...)` 之类的复制接口扩展，而不是新增一组 `naturalNoteStripVerticalRailAnswer` 常量。
- 完成标准：shared scene 可以直接表达“同一个 `naturalNoteStrip` surface，在 stacked 时是 `horizontalStrip`，在 sideBySide 时是 `verticalRail`；同一个 split child，在 vertical/horizontal 都能表达 `weighted/fitContent/fixed`”。

## 阶段 2：让 composition policy 发出明确的 rail 语义

- 目标：把“什么场景应该出现右侧 vertical rail”固化到 shared `ExerciseCompositionPolicy`，不把这层判断留给 iOS/macOS。
- 主要文件：[NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift)、[NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift)
- 关键动作：改造 `makeMainSceneNode(...)` 的 `sideBySide` 分支。
- 当 `compositionPreset == .fretboardToNaturalNoteStrip` 时，发出左 `fretboard` + 右 `naturalNoteStrip` 的 horizontal split。
- 左 child：`.weighted(1)`。
- 右 child：`.fitContent`。
- 右侧 `naturalNoteStrip`：`presentationStyle = .verticalRail`。
- 关键动作：保留其它 `sideBySide` 组合的既有语义。
- `targetPromptToFretboard`、`staffToFretboard` 仍保持双 `weighted`，不自动变成 rail 布局。
- 关键动作：保留 stacked 和 accessory 路径的现有 vertical fit-content 能力。
- `fretboardToNaturalNoteStrip + stacked` 继续让 strip 使用 `horizontalStrip` + vertical `fitContent`。
- `naturalNoteStripAccessory` 若仍出现在 vertical accessory subtree 中，继续沿用 vertical fit-content，不强行改成 rail。
- 关键动作：在 `ExerciseSceneValidator` 层补约束，明确“`verticalRail` 只能出现在 horizontal split 语境下”，“stacked strip 不应被投影为 `verticalRail`”。
- 完成标准：shared policy 能在不依赖平台层分支的前提下，稳定输出“左指板 + 右 rail”的 scene tree，同时旧的 `stacked`/`accessory` 路径不回归。

## 阶段 3：重构双平台 renderer 的主轴尺寸分配引擎

- 目标：让 `[NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift)` 和 `[NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift)` 以同一套主轴规则解释 split，而不是“vertical 看 `sizing`、horizontal 只看 `weight`”。
- 关键动作：重写 `renderSplit(...)` 的 child 分组逻辑。
- 沿当前 axis 把 child 拆成 `weighted`、`fitContent`、`fixed` 三类。
- 只有 `weighted` child 参与比例约束。
- `fitContent` / `fixed` child 不参与比例约束，只负责先占用自身需要的主轴空间。
- 关键动作：保留 horizontal split 的等高机制。
- 当前 `top/bottom == hostView` 的约束语义保留，用来保证左 `fretboard` 与右 rail 同高。
- 真正要改的是 width 分配：右 rail 不再进入 `width ratio`，左侧 weighted 区域吃剩余宽度。
- 关键动作：把当前 vertical 的 mixed split 行为迁移到新 contract 下，而不是再维护一套专门分支。
- vertical split 中，`fitContent` 先占内容高度，`weighted` 吃剩余；现有 stacked strip 行为应保持不变。
- `fixed(Double)` 在 vertical/horizontal 都要通，但首批业务不主动依赖。
- 关键动作：审视 `fretboardHostView` 的定高/定宽约束与新主轴分配的关系。
- vertical 模式下，原来的 `verticalHostHeightRatio` 不能继续作为全局 safe area 第二套高度真相压回 split。
- horizontal rail 场景下，重点是保持 `fretboard` 的高度填满 host、宽度滚动逻辑继续由现有 fretboard viewport 机制处理。
- 完成标准：renderer 可以在两端一致地解释 shared tree；`fitContent` rail 不再被拉成半屏，vertical mixed split 的既有行为也不退化。

## 阶段 4：让双平台 `NaturalNoteStripView` 支持竖排 rail 模式

- 目标：让 `[NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift](NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift)` 和 `[NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift)` 真正具备“横条”和“竖条”两种内部排布，而不是只会画底部横条。
- 关键动作：为 view 增加平台层展示模式，并由 renderer 在 render surface 时按 `ExerciseSurfaceNode.presentationStyle` 驱动。
- `horizontalStrip`：保持当前横向 stack + intrinsic height。
- `verticalRail`：切换成纵向 stack + intrinsic width。
- 关键动作：按模式重写 intrinsic size。
- 横条模式：继续给高度，不给宽度。
- 竖条模式：给宽度，不给高度。
- 关键动作：模式切换时统一 `invalidateIntrinsicContentSize()`，并检查 button 的 hugging/compression priority 是否要沿横向做额外调整，避免 rail 宽度被 label 或空白按钮异常拉宽。
- 关键动作：不改点击事件、surface ID、accessibility identifier 和 answer 路由；只改布局，不改交互协议。
- 完成标准：`naturalNoteStrip` 在右侧 rail 场景中能按从上到下排列按钮，自身宽度收口到内容，且不影响原有底部横条场景。

## 阶段 5：收口 viewport 高度，并完成回归验证

- 目标：让两端控制器把 scene 的总高度收口到当前 viewport，同时把新的 rail 语义和旧的 stacked 语义一起锁进 validation 与回归清单。
- 主要文件：[NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift](NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift)、[NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift)、[NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift)
- 关键动作：用 shared helper 替代当前 `hasVerticalFitContentSplit` 的启用条件。
- `sceneViewportHeightConstraint` 不能只在 vertical fit-content 场景启用。
- 对当前目标场景，`fretboardToNaturalNoteStrip + sideBySide + verticalRail` 也应启用 viewport pinning，保证左右两块高度等于可视区高度，而不是继续由 scroll content 自己变高。
- 关键动作：补 validation fixture 和手工回归清单。
- shared fixture：验证 `sideBySide` rail scene 的 node style 和 `mainAxisSizing`。
- shared fixture：验证 `targetPromptToFretboard + sideBySide` 仍是双 weighted。
- shared fixture：验证 `stacked fretboardToNaturalNoteStrip` 仍保留 vertical fit-content strip。
- platform 回归：iOS/macOS 上验证“左指板、右竖排音名条、二者同高、首屏完整可见、natural note strip 仍能答题”。
- 构建回归：iOS/macOS 双端构建，重点观察 renderer 约束冲突、scroll 行为和 `verticalHostHeightRatio` 相关路径。
- 完成标准：shared validation、双平台构建和手工回归都能同时覆盖“新 rail 场景”和“旧 stacked 场景”，确保这是架构升级而不是针对某一个 화면的临时分支。

## 非目标

- 本轮不新增新的 `ExerciseLayoutPreset`。
- 本轮不把 `naturalNoteStrip` 拆成新的 `surface kind` 或新 view 类型。
- 本轮不改 `ExerciseAnswerRouter` 的业务语义，只验证它在新 scene 下继续工作。
- 本轮不主动扩展 `legacyPageDisplayState` 来表达 horizontal rail；若实施中发现仍有主路径依赖，再单独开一个 bridge 子阶段处理。
---
name: rail placement phases c
overview: 为 side 模式下 natural note strip 的方案 C 制定分阶段实施计划：把错位双列布局上移到 shared placement builder，平台只消费 placement，保持 12 个 PitchClass 语义不变。计划覆盖 shared contract/placement、validation、双端视图改造、renderer 对齐与回归策略。
todos:
  - id: freeze-c-boundary
    content: 冻结方案 C 的共享边界与迁移不变量，明确 12 个 PitchClass 语义槽位与双列错位视觉 placement 的关系
    status: completed
  - id: add-shared-placement-types
    content: 在 Shared/Exercise 层新增 rail placement 数据模型与几何 token，补足 shared 直接产出布局所需的信息
    status: completed
  - id: build-placement-builder
    content: 实现 deterministic 的 shared placement builder，并把输出暴露到 ExerciseScene / ExercisePresentationState
    status: completed
  - id: extend-validations
    content: 补齐 composition validation，冻结自然音/升号双列错位的 shared placement 不变量
    status: pending
  - id: refactor-platform-strip-views
    content: 让 iOS/macOS NaturalNoteStripView 的 verticalRail 改为渲染 shared placement，horizontalStrip 继续保留现有路径
    status: pending
  - id: align-renderer-and-regressions
    content: 清理 renderer 与 host 对齐耦合，执行双端 build、validation 与 runtime smoke 回归
    status: pending
isProject: false
---

# 方案C分阶段计划

## 范围前提

- 目标场景先收敛到 `sideBySide + fretboardToNaturalNoteStrip + verticalRail`，不同时改 `stacked` 或 `horizontalStrip` 的视觉结构。
- 保留当前 12 个 `PitchClass` 语义槽位与答题事件，不把 right rail 的交互语义缩成 7 个自然音按钮。
- 目标视觉固定为：自然音右列 `C D E F G A B`，升号左列 `C# D# F# G# A#`；自然音上下直接相邻，升号按钮中心位于相邻自然音中心连线的中点。
- `Settings` 不新增配置项；现有 `fretboardLayoutContract`、默认 layout、side/stacked 切换语义都要保持稳定。
- 当前 worktree 里的红蓝容器描边与 `crossAxisWidthScale = 2` 视为过渡观察手段；方案 C 最终要把 rail 尺寸真相收口到 shared placement 的 `contentSize`，而不是继续靠平台栈布局或宽度倍率推导。

## 当前切入点

- shared 侧已经有 rail contract，但只表达粗粒度语义，还没有 per-`PitchClass` placement： [ExercisePresentationState.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift)
- 平台侧当前仍是把 `PitchClass.allCases` 直接塞进单一竖向 `stackView`： [macOSNaturalNoteStripView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift), [iOSNaturalNoteStripView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift)
- 现有 validation 主要冻结 contract，不冻结具体布局坐标： [ExerciseCompositionValidation.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift)

```268:292:NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 50
    static let defaultCrossAxisWidthScale: Double = 2
    // ...
    var buttonExtent: Double
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var crossAxisWidthScale: Double
}
```

```179:192:NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
case .verticalRail:
    stackView.orientation = .vertical
    stackView.alignment = .centerX
    stackView.distribution = .fill
```

## 阶段 0：冻结方案 C 的语义边界

- 目标：先把“12 个语义槽位”和“错位双列视觉 placement”拆成两个层次，避免实现过程中再次退回平台 patch。
- 关键决策：shared 负责输出 `PitchClass -> placement`，平台不再自己推导 `C#` 在 `C/D` 中点。
- 关键不变量：
- `PitchClass.allCases` 继续是唯一语义顺序来源： [NotePitch.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift)
- `naturalCasesInOrder` 与 `isAccidental` 继续作为 shared 分类基础，而不是在双端重新硬编码。
- 自然音列在右、升号列在左；`E-F`、`B-C` 之间没有 accidental placement。
- 本阶段产出：一组冻结到计划与 validation 的 shared 不变量，用来约束后续类型设计。

## 阶段 1：补齐 shared rail placement 所需的数据模型

- 目标：把当前只够单列栈布局使用的 rail contract，升级成“能直接产出 placement”的 shared 几何输入。
- 建议新增一个 shared 文件，例如 [ExerciseNaturalNoteStripRailPlacement.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift)。
- 在 shared 层新增这些类型：
- `ExerciseNaturalNoteStripRailPlacementModel`：例如 `.singleColumnChromatic12`、`.staggeredNaturalAccidentalTwoColumn`。
- `ExerciseNaturalNoteStripRailPlacement`：至少包含 `pitchClass`、`frame` 或 `center/size`、列归属、是否显示标题。
- `ExerciseNaturalNoteStripRailLayout`：包含 `contentSize`、placements、必要的 host 对齐语义。
- `ExerciseNaturalNoteStripRailGeometry` 或等价字段：把当前仍留在平台 `Style` 中、但 placement 计算必须知道的 token 上移到 shared，例如 `contentInsets`、`columnGap`、`naturalRowSpacing`、按钮可视尺寸来源。
- 对 [ExercisePresentationState.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift) 的建议：
- 保留 `ExerciseNaturalNoteStripRailContract` 作为高层语义入口。
- 新增 derived placement 输出，而不是把所有几何字段都继续堆在 contract 上。
- `crossAxisWidthScale` 在这一阶段先保留，用作过渡兼容；后续以 placement 的 `contentSize.width` 为主真相来源，再决定是否降级为兼容字段或删除。
- 阶段验收：shared 已经具备“只靠 contract + pitch 语义就能描述错位双列布局”的类型基础。

## 阶段 2：实现 shared placement builder，并接到 presentation 链路

- 目标：把错位双列的具体几何推导做成 deterministic 的 pure builder。
- 建议在新 shared 文件中实现一个纯函数 builder，例如：
- 输入：`ExerciseNaturalNoteStripRailContract`、`PitchClass` 集合顺序、几何 token。
- 输出：`ExerciseNaturalNoteStripRailLayout`。
- 几何规则在 shared 中一次性写死：
- 自然音 placement 按 `C D E F G A B` 形成 7 个主行。
- 升号音 placement 落在相邻自然音中心线中点。
- rail `contentHeight` 来自 7 个自然音主行与对应间隙，而不再来自 `slotCount == 12` 的单列公式。
- rail `contentWidth` 来自两列按钮宽度、列间距与内容内边距，而不再来自单列 `fitContent * widthScale`。
- 建议由 [ExerciseScene.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift) 或 [ExercisePresentationState.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift) 暴露 `naturalNoteStripRailLayout`，让 renderer / platform view 都从同一入口读取。
- [ExerciseCompositionPolicy.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift) 在本阶段原则上不改 scene 树，只保持 side rail 的 surface scope 与 presentationStyle 判定。
- 阶段验收：shared 已经能单独算出 `C/C#/D/.../B` 的两列错位 placement 与完整 `contentSize`。

## 阶段 3：扩展 validation，把 placement 冻结成 shared 不变量

- 目标：让方案 C 的核心价值真正落在 automated validation 上，而不是只靠 UI 观察。
- 重点文件： [ExerciseCompositionValidation.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift)
- 扩展现有 fixture：
- `natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults`：从“只测 contract”扩展到“contract + placement 摘要”。
- `side_rail_contract_remains_orthogonal_to_fretboard_height_contract`：证明 placement builder 不依赖 `fretboardLayoutContract`，仍与指板高度策略正交。
- 建议新增 fixture：
- `natural_note_strip_staggered_two_column_layout_matches_pitchclass_topology`：冻结自然音/升号列归属与相对中心位置。
- `natural_note_strip_shared_layout_content_size_matches_intrinsic_semantics`：冻结 shared `contentSize` 与按钮尺寸、行间关系的一致性。
- 如果在 [SettingsNavigationValidation.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift) 已存在 rail 相关 gate，只做“不回退”验证，不新增 settings 行为。
- 阶段验收：shared placement 的关键几何语义在 CI 中可重复、可断言、可回归。

## 阶段 4：让双端 NaturalNoteStripView 改为渲染 placement

- 目标：平台 view 不再自己推导单列布局，而是只消费 shared placement。
- 重点文件： [macOSNaturalNoteStripView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift), [iOSNaturalNoteStripView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift)
- 改造策略：
- `horizontalStrip` 路径先保持现有 `stackView`，避免一次性推翻整个 view。
- `verticalRail` 路径从单一 `stackView` 切换成 placement-backed 内容容器，例如 `railCanvasView` 或等价子容器。
- 按钮集合仍可复用当前 `PitchClass -> NaturalNoteButton` 映射，但 `frame/constraint` 来自 shared placement，而不是 `PitchClass.allCases` 的栈顺序。
- `intrinsicContentSize` 直接取 shared placement 的 `contentSize`。
- 标题、无障碍、按压态、平台字体/圆角仍留在平台层；这部分是 shared placement 覆盖不到的。
- 建议在这个阶段顺手把“verticalRail 宽度 x2”改成 placement `contentSize.width` 驱动，避免 shared contract 与平台外观出现双源真相。
- 阶段验收：在不动 renderer 的前提下，双端 rail 自身已经能按 shared placement 画出两列错位布局。

## 阶段 5：最小化 renderer 耦合，统一 host 对齐来源

- 目标：确认 renderer 只负责 surface 宿主布局，不再平行推导 strip 内部几何。
- 重点文件： [macOSExerciseSceneRenderer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift), [iOSExerciseSceneRenderer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift)
- 当前 renderer 的 `hostedViewLayout` / `embeddedViewLayout` 仍用 contract 的 `mainAxisPolicy` 与 `verticalAlignment` 决定是否纵向居中；方案 C 需要确认这是否继续保留为 scene 层语义，还是改为读 shared layout 的 host alignment。
- 这里的推荐做法是：
- 如果 host 对齐仍是 surface 级语义，就保留 renderer 当前职责，只把判断源统一到 shared layout/contract 的单一出口。
- 不把 renderer 变成第二个 placement 计算器，不在 renderer 里再算一遍列间距、按钮中心或 rail 高度。
- 本阶段同时决定是否移除当前调试边框，或把它彻底隔离成 debug-only 路径，避免污染最终 layout 逻辑。
- 阶段验收：renderer 与 platform view 之间不存在“contract 一份、placement 一份、renderer 又判断一份”的三源漂移。

## 阶段 6：执行回归与风险清理

- 目标：确认方案 C 不只是视觉正确，还不会把之前 side/stacked 相关的稳定性问题重新带回来。
- 必跑项：
- [ExerciseCompositionValidation.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift) 的 rail 相关 fixture。
- [SettingsNavigationValidation.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift) 的默认 side、route gate、settings tree 不回退检查。
- 双端 build：macOS / iOS Simulator。
- 双端 runtime smoke：side 与 stacked 往返切换、窗口尺寸变化 / 设备旋转。
- 手工观察项：
- 自然音列是否上下紧贴。
- `C# D# F# G# A#` 是否落在相邻自然音中点。
- 蓝色容器宽度是否由 placement `contentSize` 主导，红色容器是否相应缩窄。
- 命中、无障碍、按钮标题与当前答题行为是否仍然一一对应。
- 阶段验收：方案 C 的 shared placement、双端渲染与历史稳定性约束同时成立。

## 关键文件清单

- [ExercisePresentationState.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift)：rail contract 与 placement 暴露入口。
- [ExerciseScene.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift)：rail 场景作用域与 sideBySide 判定。
- [ExerciseCompositionPolicy.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift)：scene 树保持不变，继续提供 scope 入口。
- [ExerciseCompositionValidation.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift)：冻结 shared placement 不变量。
- [NotePitch.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift)：自然音/升号分类与 `PitchClass` 顺序真相来源。
- [macOSNaturalNoteStripView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift)：verticalRail 从单列 stack 迁移到 placement 渲染。
- [iOSNaturalNoteStripView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift)：与 macOS 对齐的 placement 渲染路径。
- [macOSExerciseSceneRenderer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift), [iOSExerciseSceneRenderer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift)：host 对齐与 debug 描边清理。

## 关键风险与应对

- 风险：shared contract、shared placement、renderer host 判断并存，出现三份真相。
- 应对：从阶段 2 开始就指定 placement 为内部几何唯一来源，renderer 只保留 surface 级宿主语义。
- 风险：双端继续沿用 `stackView` 试图硬凑错位双列，最后仍然在平台层重复几何推导。
- 应对：verticalRail 明确切到 placement-backed 内容容器，不继续扩大单列 stack 的职责。
- 风险：过渡期 `crossAxisWidthScale = 2` 与 placement `contentSize.width` 同时生效，导致 rail 宽度被重复放大。
- 应对：阶段 4 明确把 rail intrinsic width 的真相来源切到 placement `contentSize`，并在 validation 里冻结新规则。
- 风险：修成视觉正确但打破历史 side/stacked 稳定性。
- 应对：最后阶段必须同时跑 build、validation、runtime smoke，不接受只看截图通过。


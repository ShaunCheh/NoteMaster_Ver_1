# 20260415_183907_stage0_sr0_horizontal_strip_semantic_boundary_freeze

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_183907`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat`、按文件分组的 `git diff --unified=12`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` 验证结果整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 0”真实落地的代码改动；目标是冻结方案一下 `horizontalStrip` 与 `verticalRail` 的 shared 语义边界，不提前实现双行视图，不提前引入 `SR-0`
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`3 files changed, 204 insertions(+), 3 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 3 个 `Swift` 文件，因此本次统计口径直接等同于阶段 0 本轮改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `3 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Scene/SceneCore.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`：阶段 0 不提前把 `horizontalStrip` 改成双行平台视图
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`：同上，保留到阶段 2
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`：双行 strip 的共享布局模型留到阶段 1 统一抽取
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`：本轮不提前接入 `staffToNaturalNoteStrip` 或 `SR-0` preset
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`：本轮不新增 `sr0` mode，避免越过阶段边界
- 验证结果：
- `ReadLints`：对本轮 3 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath /tmp/NoteMasterStage0-mac-build build`：构建通过
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr0_双行strip_计划_632caead.plan.md`
- 没有触碰 iOS / macOS `NaturalNoteStripView` 的 `horizontalStrip` 具体布局实现
- 没有新增 `SR-0` mode、`staffToNaturalNoteStrip` preset 或 shared horizontal layout model
- 没有提交代码

## 本次结论

- `AppSurfacePresentationStyle` 现在在 shared 层明确区分了两种 strip 语义：`horizontalStrip = 底部双行`，`verticalRail = 右侧双列`
- 新增独立 fixture `scheme_one_horizontal_strip_semantic_boundary_stays_distinct_from_vertical_rail`，把阶段 0 需要冻结的语义边界从“隐含约定”提升为“可验证合同”
- `manualChecklist` 也同步改成显式回归要求，后续阶段改平台视图或引入 `SR-0` 时都有统一锚点

## 修改 1：在 `SceneCore` 冻结 presentation style 的产品语义

### 修改前

- `AppSurfacePresentationStyle` 只有枚举 case，没有写明 `horizontalStrip` / `verticalRail` 各自对应的产品语义
- 后续平台实现只能依赖隐含约定来解释 strip 的方向和内部组织

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCore.swift
// 函数名/符号: enum AppSurfacePresentationStyle
// 功能说明: 修改前只保留 presentation style 枚举值；
// `horizontalStrip` 与 `verticalRail` 的产品语义没有在 shared 层显式冻结。
enum AppSurfacePresentationStyle: String, CaseIterable, Equatable, Hashable,
    Sendable {
    case standard
    case horizontalStrip
    case verticalRail
}
```

### 修改后

- 给 `horizontalStrip` 增加“底部双行：上半音、下自然音”的共享注释
- 给 `verticalRail` 增加“右侧双列错位：左半音、右自然音”的共享注释

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCore.swift
// 函数名/符号: enum AppSurfacePresentationStyle
// 功能说明: 修改后先在 shared 枚举上冻结方案一语义边界；
// 平台层后续实现必须服从这里的定义，而不是自行解释 strip 方向。
enum AppSurfacePresentationStyle: String, CaseIterable, Equatable, Hashable,
    Sendable {
    case standard
    // Reserved for bottom strip scenes. Scheme 1 freezes this style as a
    // horizontal two-row strip: accidentals on top, naturals on bottom.
    case horizontalStrip
    // Reserved for side rail scenes and keeps the existing staggered
    // two-column semantics: accidentals on the left, naturals on the right.
    case verticalRail
}
```

## 修改 2：新增阶段 0 shared fixture，显式冻结方案一边界

### 修改前

- 既有 `validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing()` 只验证了 strip surface 的默认 `presentationStyle` 与 mixed sizing
- 阶段 0 还没有单独 fixture 去冻结“stacked = horizontalStrip / side = verticalRail”以及“顶行 accidental / 底行 natural”的方案一边界

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing()
// 功能说明: 修改前这里只覆盖 presentationStyle 与 scene sizing 的基础合同；
// `horizontalStrip` 的双行来源和 `verticalRail` 的保留边界仍是隐含约定。
static func validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing"
    var issues: [ExerciseCompositionValidationIssue] = []

    if ExerciseSurfaceNode.naturalNoteStripAnswer.presentationStyle
        != .horizontalStrip
        || ExerciseSurfaceNode.naturalNoteStripAccessory.presentationStyle
        != .horizontalStrip {
        issues.append(
            issue(
                fixtureName,
                "natural note strip 的静态 surface 节点在阶段 1 应默认保持 horizontalStrip presentation style。"
            )
        )
    }

    let verticalRailStrip = ExerciseSurfaceNode.naturalNoteStripAnswer
        .withPresentationStyle(.verticalRail)

    let stackedMixedScene = ExerciseScene.stacked(
        top: .fretboardPrompt,
        bottom: .naturalNoteStripAnswer
    )
    let railScene = ExerciseScene(
        root: .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(.fretboardPrompt),
                    mainAxisSizing: .weighted(1)
                ),
                ExerciseSceneSplitChild(
                    node: .surface(verticalRailStrip),
                    mainAxisSizing: .fitContent
                )
            ]
        )
    )

    // ... 省略未变断言 ...
    return issues
}
```

### 修改后

- 新增 `validateSchemeOneHorizontalStripSemanticBoundaryStaysDistinctFromVerticalRail()`
- 同时冻结 3 组语义：
- `PitchClass.accidentalCasesInOrder` 继续代表顶部半音行来源
- `PitchClass.naturalCasesInOrder` 继续代表底部自然音行来源
- `positionPrompt + stacked` / `positionPrompt + sideBySide` 继续分别投影到 `horizontalStrip` / `verticalRail`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validateSchemeOneHorizontalStripSemanticBoundaryStaysDistinctFromVerticalRail()
// 功能说明: 修改后新增阶段 0 专用 fixture；
// 显式冻结方案一的 strip 语义边界，避免后续只改平台 view 而 shared 合同缺席。
static func validateSchemeOneHorizontalStripSemanticBoundaryStaysDistinctFromVerticalRail()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "scheme_one_horizontal_strip_semantic_boundary_stays_distinct_from_vertical_rail"
    var issues: [ExerciseCompositionValidationIssue] = []

    let expectedAccidentals: [PitchClass] = [
        .cSharp,
        .dSharp,
        .fSharp,
        .gSharp,
        .aSharp
    ]
    if PitchClass.accidentalCasesInOrder != expectedAccidentals {
        issues.append(
            issue(
                fixtureName,
                "阶段 0 应把 horizontalStrip 的顶行来源冻结为 C#-D#-F#-G#-A#，对应上方半音按钮。"
            )
        )
    }

    let expectedNaturals: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
    if PitchClass.naturalCasesInOrder != expectedNaturals {
        issues.append(
            issue(
                fixtureName,
                "阶段 0 应把 horizontalStrip 的底行来源冻结为 C-D-E-F-G-A-B，对应下方自然音按钮。"
            )
        )
    }

    let stackedPositionPromptPresentation = ExerciseCompositionPolicy
        .makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: .positionPrompt
                ),
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .fretboardToNaturalNoteStrip,
                    layoutPreset: .stacked
                )
            )
        )

    let sidePositionPromptPresentation = ExerciseCompositionPolicy
        .makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: .positionPrompt
                ),
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .fretboardToNaturalNoteStrip,
                    layoutPreset: .sideBySide
                )
            )
        )

    // ... 省略未变断言：
    // 1. 上下两行合并后恰好覆盖全部 12 个 PitchClass，且 accidental / natural 不交叉
    // 2. stacked scene 继续是 vertical split + bottom horizontalStrip
    // 3. side scene 继续是 horizontal split + trailing verticalRail

    return issues
}
```

## 修改 3：把阶段 0 fixture 注册进 runner，并同步更新手工清单

### 修改前

- 新 fixture 没有入口
- checklist 对 bottom strip / side rail 的区分还是口头语义，没有写成显式回归项

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改前 runner 不会执行新的阶段 0 语义边界 fixture；
// checklist 也还没有明确写出 horizontalStrip 与 verticalRail 的分工。
ExerciseCompositionValidationFixture(
    name: "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing",
    validate: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
    validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
)

var checklist = [
    "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
    "确认 `positionPrompt + Side` 在 `fretboardToNaturalNoteStrip` 组合下呈现为左 `fretboard`、右竖排 `natural note strip`，并且左右两块保持同高。",
    "确认切回 stacked 后，`natural note strip` 仍保持底部横条形态，不会被错误保留成竖排 rail。",
]
```

### 修改后

- `makeFixtures()` 把新 fixture 正式纳入验证矩阵
- `manualChecklist` 里的三条关键回归项改成显式合同文案

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后 runner 会执行新的阶段 0 边界 fixture；
// 同时把人工回归项改成明确的 horizontalStrip / verticalRail 合同描述。
ExerciseCompositionValidationFixture(
    name: "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing",
    validate: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing
),
ExerciseCompositionValidationFixture(
    name: "scheme_one_horizontal_strip_semantic_boundary_stays_distinct_from_vertical_rail",
    validate:
        validateSchemeOneHorizontalStripSemanticBoundaryStaysDistinctFromVerticalRail
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
    validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
)

var checklist = [
    "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合；其中底部 `horizontalStrip` 合同在方案一中固定对应“上半音、下自然音”的双行语义。",
    "确认 `positionPrompt + Side` 在 `fretboardToNaturalNoteStrip` 组合下呈现为左 `fretboard`、右竖排 `natural note strip`；右侧 strip 继续走 `verticalRail` 语义，不会被底部 `horizontalStrip` 合同覆盖。",
    "确认切回 stacked 后，`natural note strip` 仍保持底部 `horizontalStrip` 合同，不会被错误保留成右侧 `verticalRail`。",
]
```

## 对阶段计划的对应关系

- 对应 `sr0_双行strip_计划_632caead.plan.md` 的“阶段 0：冻结方案一的共享语义边界”
- 已完成：
- 把 `horizontalStrip` 的产品语义写进 shared 枚举注释
- 把 stacked / side 两种 strip 场景边界写进 shared validation fixture
- 把手工清单同步改为显式回归项
- 尚未开始：
- 阶段 1 的 shared 双行布局模型
- 阶段 2 的 iOS / macOS 双行 strip view
- 阶段 3 之后的 `SR-0` mode / preset / answer flow

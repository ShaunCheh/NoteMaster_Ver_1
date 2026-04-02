# 20260402_232212_stage0_natural_note_strip_rail_boundary_freeze

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260402_232212`
- 记录范围：只记录方案 B 的阶段 0 落地，即先冻结 `sideBySide + naturalNoteStrip + verticalRail` 的 shared 语义边界，不改平台渲染
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本轮实际改动文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. 本轮目标

- 先把“哪些 scene 才允许进入右侧 rail 语义”写死，避免后续又把方案 B 做成平台层 patch。
- 保留当前 12 个 `PitchClass` 槽位，不把 `naturalNoteStrip` 改成 7 个自然音按钮。
- 明确阶段 0 只是冻结 shared 边界，不在这一轮里改 `renderer`、`NaturalNoteStripView`、`settings` 展示。

## 2. 修改一：在 `ExerciseScene.swift` 冻结 right rail 作用域

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数/符号: ExerciseSurfaceNode, ExerciseSceneNode, ExerciseScene
// 修改前说明: shared 层只有泛化的 surface / split 语义，
// 但没有一个 helper 能明确表达“这是不是 naturalNoteStrip 的 side answer rail 作用域”。
struct ExerciseSurfaceNode: Equatable, Sendable {
    var isAuxiliarySurface: Bool {
        roles.contains(.auxiliary)
    }
}

extension ExerciseSceneNode {
    var containsMainFretboardInSideBySideLayout: Bool {
        switch self {
        case .surface:
            return false
        case let .split(axis, children):
            let isCurrentSideBySideFretboard = axis == .horizontal
                && children.count >= 2
                && children.contains { $0.node.containsSurface(.fretboard) }
            return isCurrentSideBySideFretboard
                || children.contains {
                    $0.node.containsMainFretboardInSideBySideLayout
                }
        case let .overlay(base, _):
            return base.containsMainFretboardInSideBySideLayout
        case let .collapsible(main, _, _):
            return main.containsMainFretboardInSideBySideLayout
        }
    }
}

extension ExerciseScene {
    var containsMainFretboardInSideBySideLayout: Bool {
        root.containsMainFretboardInSideBySideLayout
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数/符号: ExerciseSurfaceNode.isNaturalNoteStripAnswerRail
// 修改后说明: 先把“natural note strip + answer + verticalRail”收敛成一个显式 surface helper，
// 后续 renderer / validation 都只认这一个入口，不再各自猜测。
struct ExerciseSurfaceNode: Equatable, Sendable {
    var isAuxiliarySurface: Bool {
        roles.contains(.auxiliary)
    }

    var isNaturalNoteStripAnswerRail: Bool {
        id == .naturalNoteStrip
            && kind == .naturalNoteStrip
            && isAnswerSurface
            && presentationStyle == .verticalRail
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数/符号: ExerciseSceneNode.containsNaturalNoteStripAnswerRailInSideBySideLayout,
//           ExerciseScene.containsNaturalNoteStripAnswerRailInSideBySideLayout
// 修改后说明: scene 层新增“right rail 作用域”识别，只在 horizontal split 且左侧包含 fretboard、
// 右侧包含 naturalNoteStrip answer rail 时返回 true。
extension ExerciseSceneNode {
    var containsNaturalNoteStripAnswerRailInSideBySideLayout: Bool {
        switch self {
        case .surface:
            return false
        case let .split(axis, children):
            let isCurrentNaturalNoteStripAnswerRailLayout = axis == .horizontal
                && children.count >= 2
                && children.contains { $0.node.containsSurface(.fretboard) }
                && children.contains {
                    $0.node.surfaceNodes.contains(where: {
                        $0.isNaturalNoteStripAnswerRail
                    })
                }
            return isCurrentNaturalNoteStripAnswerRailLayout
                || children.contains {
                    $0.node.containsNaturalNoteStripAnswerRailInSideBySideLayout
                }
        case let .overlay(base, _):
            return base.containsNaturalNoteStripAnswerRailInSideBySideLayout
        case let .collapsible(main, _, _):
            return main.containsNaturalNoteStripAnswerRailInSideBySideLayout
        }
    }
}

extension ExerciseScene {
    var containsNaturalNoteStripAnswerRailInSideBySideLayout: Bool {
        root.containsNaturalNoteStripAnswerRailInSideBySideLayout
    }
}
```

### 2.3 这一改动解决了什么

- 以前 shared 层只知道“有 `verticalRail`”或“有 side fretboard”，但不知道“这是不是方案 B 要处理的那条 right rail”。
- 现在 shared 层先把作用域命名出来，后面阶段 1/2/3 都可以只围绕这个 helper 演进，避免把所有 `.verticalRail` 一刀切。

## 3. 修改二：在 `ExercisePresentationState.swift` 冻结阶段 0 的 rail boundary

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseFretboardLayoutContract, ExercisePresentationState.fretboardLayoutContract
// 修改前说明: shared 层只有 fretboard 的高度 contract，
// 还没有 natural note strip rail 的边界对象。
enum ExerciseFretboardHeightPolicy: Equatable, Sendable {
    case followViewportRatio
    case fillAvailableHeight
}

struct ExerciseFretboardLayoutContract: Equatable, Sendable {
    var pinsSceneToViewportHeight: Bool
    var heightPolicy: ExerciseFretboardHeightPolicy
}

extension ExercisePresentationState {
    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        scene.fretboardLayoutContract
    }
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailSlotModel,
//           ExerciseNaturalNoteStripRailLayoutIntent,
//           ExerciseNaturalNoteStripRailBoundary
// 修改后说明: 阶段 0 先新增一个“边界对象”，只冻结作用域与不变量，
// 暂时不把按钮边长、布局约束等平台细节提前塞进 shared。
enum ExerciseNaturalNoteStripRailSlotModel: Equatable, Sendable {
    case chromatic12Preserved

    var slotCount: Int {
        PitchClass.allCases.count
    }
}

enum ExerciseNaturalNoteStripRailLayoutIntent: Equatable, Sendable {
    case contentSizedAndVerticallyCentered
}

enum ExerciseNaturalNoteStripRailBoundary: Equatable, Sendable {
    case inactive
    case sideBySideAnswerRail(
        slotModel: ExerciseNaturalNoteStripRailSlotModel,
        layoutIntent: ExerciseNaturalNoteStripRailLayoutIntent
    )

    var isEnabled: Bool {
        if case .inactive = self {
            return false
        }
        return true
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExercisePresentationState.naturalNoteStripRailBoundary,
//           ExerciseScene.naturalNoteStripRailBoundary
// 修改后说明: ExerciseScene 负责根据 scene 结构推导 rail boundary；
// ExercisePresentationState 只把它往上透出，供后续 validation / renderer 消费。
extension ExercisePresentationState {
    var naturalNoteStripRailBoundary: ExerciseNaturalNoteStripRailBoundary {
        scene.naturalNoteStripRailBoundary
    }
}

extension ExerciseScene {
    var naturalNoteStripRailBoundary: ExerciseNaturalNoteStripRailBoundary {
        guard containsNaturalNoteStripAnswerRailInSideBySideLayout else {
            return .inactive
        }

        return .sideBySideAnswerRail(
            slotModel: .chromatic12Preserved,
            layoutIntent: .contentSizedAndVerticallyCentered
        )
    }
}
```

### 3.3 这一改动解决了什么

- 把“保留 12 槽位”和“目标语义是内容高度 + 垂直居中”先固化成 shared 枚举，而不是写死在平台 view 里。
- 同时保持 `fretboardLayoutContract` 原有职责不变，避免 right rail 的阶段 0 边界反向污染已修好的 `fretboard` 高度 contract。

## 4. 修改三：在 `ExerciseCompositionValidation.swift` 冻结阶段 0 不变量

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: makeFixtures()
// 修改前说明: validation 已经覆盖了 verticalRail、viewport pin、fretboardLayoutContract，
// 但还没有一条专门断言“rail boundary 只在方案 B 的目标作用域内激活”。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing",
            validate: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing
        ),
        ExerciseCompositionValidationFixture(
            name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
            validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
        ),
        ExerciseCompositionValidationFixture(
            name: "phase_zero_side_by_side_invariants_preserve_composition_specific_surface_pairs",
            validate: validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs
        )
    ]
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: makeFixtures(),
//           validateNaturalNoteStripRailBoundaryFreezesScopeBeforeLayoutContract()
// 修改后说明: 新增一个专门的 fixture，锁死阶段 0 的 right rail 范围与不变量，
// 避免后续阶段把语义漂移到 stacked 或其它 sideBySide 组合上。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing",
            validate: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing
        ),
        ExerciseCompositionValidationFixture(
            name: "natural_note_strip_rail_boundary_freezes_scope_before_layout_contract",
            validate: validateNaturalNoteStripRailBoundaryFreezesScopeBeforeLayoutContract
        ),
        ExerciseCompositionValidationFixture(
            name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
            validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
        )
    ]
}

static func validateNaturalNoteStripRailBoundaryFreezesScopeBeforeLayoutContract()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "natural_note_strip_rail_boundary_freezes_scope_before_layout_contract"
    var issues: [ExerciseCompositionValidationIssue] = []

    // 1. 只有 fretboardToNaturalNoteStrip + sideBySide 才激活 right rail boundary
    // 2. 激活后必须继续保留 12 个 PitchClass 槽位
    // 3. 目标语义先冻结为内容高度 + 垂直居中
    // 4. 不能反向破坏 side fretboard 的 fillAvailableHeight
    // 5. stacked / targetPrompt->fretboard / staff->fretboard 都不得误激活

    return issues
}
```

### 4.3 这一改动解决了什么

- 方案 B 的阶段 0 不再只是“口头约定”，而是变成了自动化 fixture。
- 后续如果有人把 `stacked`、`targetPrompt -> fretboard` 或 `staff -> fretboard` 误拉进 right rail 语义，validation 会直接报错。

## 5. 最终状态总结

- `ExerciseScene.swift` 现在已经能识别 right rail 的精确作用域。
- `ExercisePresentationState.swift` 现在已经能把阶段 0 的 rail boundary 暴露成 shared contract。
- `ExerciseCompositionValidation.swift` 现在已经把这组边界写成自动化断言。
- 本轮没有修改任何平台 `renderer` / `NaturalNoteStripView`，因此视觉行为暂时不变；这一点是刻意的，目的是先把 shared 边界钉死。

## 6. 验证结果

- `ReadLints` 检查上述 3 个文件：无 linter 错误
- 构建验证命令：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- 构建结果：`BUILD SUCCEEDED`

## 7. 对后续阶段的直接意义

- 阶段 1 可以在这个 boundary 之上继续补真正的 `rail contract` 字段，而不用再重复讨论“哪些 scene 才算 right rail”。
- 阶段 2/3 改平台 view 和 renderer 时，可以只消费 `naturalNoteStripRailBoundary`，不会误伤其它 `.verticalRail` 语义。

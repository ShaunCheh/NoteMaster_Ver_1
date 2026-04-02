# 20260402_100137_phase1_upgrade_shared_scene_contract

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260402_100137`
- 记录范围：实施 `右侧音名条布局` 计划的阶段 `1`，把 `surface presentation style` 与 `split main-axis sizing` 提升为 shared scene contract，并把现有 policy、presentation、validation、renderer / controller 调用点迁移到新契约
- 修改前基线：以阶段 `0` 完成后的工作区状态为准；由于阶段 `0` 仍未提交，`git diff --stat` 的累计数字会叠加前一阶段未提交改动，因此本记录不写聚合行数，只按文件和功能说明本阶段真实修改
- 修改目标：
  - 为 `ExerciseSurfaceNode` 增加展示语义，显式区分 `standard`、`horizontalStrip`、`verticalRail`
  - 把 `ExerciseSceneSplitChild` 从旧的 `weight + sizing` 升级为统一的 `mainAxisSizing`
  - 提供 shared helper，替代只面向 vertical fit-content 的旧判断
  - 在不提前实现阶段 `2/3` 的前提下，先把 shared 层和现有调用方迁移到新契约
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
  - `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 1. `ExerciseScene.swift`：shared contract 从“旧 split 语义”升级为“展示语义 + 主轴尺寸语义”

- 修改前：`ExerciseSurfaceNode` 只有逻辑身份和角色，没有展示语义；`ExerciseSceneSplitChild` 仍然沿用 `weight + sizing` 组合，`preferredVerticalSplitSizing` 和 `hasVerticalFitContentSplit` 只覆盖 vertical 场景。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSurfaceNode.init(...), ExerciseSceneSplitChild.init(...), ExerciseSurfaceNode.preferredVerticalSplitSizing, ExerciseSceneNode.hasVerticalFitContentSplit
// 功能说明: 修改前 shared contract 只能表达 vertical fit-content / fill，无法表达 surface 的展示样式，也无法统一描述 horizontal / vertical 的主轴尺寸语义。
enum ExerciseSceneSplitChildSizing: String, Equatable, Hashable, Sendable {
    case fill
    case fitContent
}

struct ExerciseSurfaceNode: Equatable, Sendable {
    var id: ExerciseSurfaceID
    var kind: ExerciseSurfaceKind
    private(set) var roles: Set<ExerciseRole>
}

struct ExerciseSceneSplitChild: Equatable, Sendable {
    var node: ExerciseSceneNode
    var weight: Double
    var sizing: ExerciseSceneSplitChildSizing

    init(
        node: ExerciseSceneNode,
        weight: Double = 1,
        sizing: ExerciseSceneSplitChildSizing = .fill
    ) {
        precondition(
            weight > 0,
            "Exercise scene split child weight must be greater than zero."
        )
        self.node = node
        self.weight = weight
        self.sizing = sizing
    }
}

extension ExerciseSurfaceNode {
    var preferredVerticalSplitSizing: ExerciseSceneSplitChildSizing {
        switch kind {
        case .staff, .targetPrompt, .naturalNoteStrip:
            return .fitContent
        case .fretboard, .piano:
            return .fill
        }
    }
}

extension ExerciseSceneNode {
    var hasVerticalFitContentSplit: Bool {
        switch self {
        case .surface:
            return false
        case let .split(axis, children):
            let hasCurrentFitContentSplit = axis == .vertical
                && children.contains(where: { $0.sizing == .fitContent })
                && children.contains(where: { $0.sizing == .fill })
            return hasCurrentFitContentSplit
                || children.contains { $0.node.hasVerticalFitContentSplit }
        case let .overlay(base, floating):
            return base.hasVerticalFitContentSplit
                || floating.contains { $0.hasVerticalFitContentSplit }
        case let .collapsible(main, accessory, _):
            return main.hasVerticalFitContentSplit
                || accessory.hasVerticalFitContentSplit
        }
    }
}
```

- 修改后：新增 `ExerciseSurfacePresentationStyle` 和 `ExerciseSceneSplitChildMainAxisSizing`，`ExerciseSurfaceNode` 可以带展示样式，`ExerciseSceneSplitChild` 统一使用 `mainAxisSizing`，并提供 `withPresentationStyle(...)`、`hasMixedMainAxisSizing(...)`、`requiresViewportPinnedHeight` 等 shared helper。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSurfaceNode.init(...), ExerciseSurfaceNode.withPresentationStyle(...), ExerciseSceneSplitChild.init(...), ExerciseSurfaceNode.preferredVerticalMainAxisSizing(...), ExerciseSceneNode.hasMixedMainAxisSizing(...), ExerciseScene.requiresViewportPinnedHeight
// 功能说明: 修改后 shared contract 可以同时表达 surface 的展示样式和 split 的主轴尺寸语义，为阶段 2/3 的 rail 场景提供表达能力。
enum ExerciseSurfacePresentationStyle: String, CaseIterable, Equatable, Hashable, Sendable {
    case standard
    case horizontalStrip
    case verticalRail
}

enum ExerciseSceneSplitChildMainAxisSizing: Equatable, Hashable, Sendable {
    case weighted(Double)
    case fitContent
    case fixed(Double)

    var weightedValue: Double? {
        guard case let .weighted(weight) = self else {
            return nil
        }

        return weight
    }

    var isWeighted: Bool {
        weightedValue != nil
    }
}

struct ExerciseSurfaceNode: Equatable, Sendable {
    var id: ExerciseSurfaceID
    var kind: ExerciseSurfaceKind
    private(set) var roles: Set<ExerciseRole>
    var presentationStyle: ExerciseSurfacePresentationStyle

    init(
        id: ExerciseSurfaceID,
        kind: ExerciseSurfaceKind,
        roles: Set<ExerciseRole>,
        presentationStyle: ExerciseSurfacePresentationStyle = .standard
    ) {
        precondition(
            !roles.isEmpty,
            "Exercise surface must expose at least one role."
        )
        self.id = id
        self.kind = kind
        self.roles = roles
        self.presentationStyle = presentationStyle
    }

    func withPresentationStyle(
        _ presentationStyle: ExerciseSurfacePresentationStyle
    ) -> ExerciseSurfaceNode {
        var copy = self
        copy.presentationStyle = presentationStyle
        return copy
    }
}

struct ExerciseSceneSplitChild: Equatable, Sendable {
    var node: ExerciseSceneNode
    var mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing

    init(
        node: ExerciseSceneNode,
        mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing = .weighted(1)
    ) {
        switch mainAxisSizing {
        case let .weighted(weight):
            precondition(
                weight > 0,
                "Exercise scene split child weight must be greater than zero."
            )
        case let .fixed(size):
            precondition(
                size > 0,
                "Exercise scene split child fixed size must be greater than zero."
            )
        case .fitContent:
            break
        }
        self.node = node
        self.mainAxisSizing = mainAxisSizing
    }
}

extension ExerciseSurfaceNode {
    func preferredVerticalMainAxisSizing(
        weight: Double = 1
    ) -> ExerciseSceneSplitChildMainAxisSizing {
        switch kind {
        case .staff, .targetPrompt, .naturalNoteStrip:
            return .fitContent
        case .fretboard, .piano:
            return .weighted(weight)
        }
    }

    static let naturalNoteStripAnswer = ExerciseSurfaceNode(
        id: .naturalNoteStrip,
        kind: .naturalNoteStrip,
        roles: [.answer],
        presentationStyle: .horizontalStrip
    )
}

extension ExerciseSceneNode {
    func hasMixedMainAxisSizing(
        along axis: ExerciseSceneAxis
    ) -> Bool {
        switch self {
        case .surface:
            return false
        case let .split(splitAxis, children):
            let hasCurrentMixedMainAxisSizing = splitAxis == axis
                && children.contains(where: { $0.mainAxisSizing.isWeighted })
                && children.contains(where: { !$0.mainAxisSizing.isWeighted })
            return hasCurrentMixedMainAxisSizing
                || children.contains { $0.node.hasMixedMainAxisSizing(along: axis) }
        case let .overlay(base, floating):
            return base.hasMixedMainAxisSizing(along: axis)
                || floating.contains { $0.hasMixedMainAxisSizing(along: axis) }
        case let .collapsible(main, accessory, _):
            return main.hasMixedMainAxisSizing(along: axis)
                || accessory.hasMixedMainAxisSizing(along: axis)
        }
    }

    var requiresViewportPinnedHeight: Bool {
        hasMixedMainAxisSizing(along: .vertical)
            || surfaceNodes.contains(where: {
                $0.presentationStyle == .verticalRail
            })
    }
}
```

## 2. `ExerciseCompositionPolicy.swift` 与 `ExercisePresentationState.swift`：把旧 contract 透传改成新 contract

- 修改前：`ExerciseCompositionPolicy` 仍返回 `sizing`，vertical child 仍通过 `weight + sizing` 组装；`ExerciseRenderedSceneLayout` 暴露的也是 `primaryWeight / secondaryWeight`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: makeScene(...), makeAccessorySceneNode(...), wrapMainSceneNode(...), makeVerticalSceneChild(...)
// 功能说明: 修改前 composition policy 仍基于 weight + sizing 组装 split child。
return ExerciseScene(
    root: wrapMainSceneNode(
        mainSceneNode,
        accessorySceneNode: accessoryScene.node,
        accessorySizing: accessoryScene.sizing,
        preferences: preferences
    )
)

private static func makeAccessorySceneNode(
    preferences: ExerciseLayoutPreferences
) -> (node: ExerciseSceneNode, sizing: ExerciseSceneSplitChildSizing)? {
    // ...
    return (
        node: accessoryChildren[0].node,
        sizing: accessoryChildren[0].sizing
    )
}

private static func makeVerticalSceneChild(
    for surface: ExerciseSurfaceNode,
    weight: Double = 1
) -> ExerciseSceneSplitChild {
    ExerciseSceneSplitChild(
        node: .surface(surface),
        weight: weight,
        sizing: surface.preferredVerticalSplitSizing
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseRenderedSceneLayout, ExercisePresentationState.renderedSceneLayout(for:)
// 功能说明: 修改前 renderedSceneLayout 暴露的是旧字段 primaryWeight / secondaryWeight。
struct ExerciseRenderedSceneLayout: Equatable, Sendable {
    var arrangement: ExerciseRenderedSceneArrangement
    var primarySurface: ExerciseSurfaceNode
    var primaryWeight: Double
    var secondarySurface: ExerciseSurfaceNode?
    var secondaryWeight: Double?
}

return ExerciseRenderedSceneLayout(
    arrangement: axis == .vertical ? .stacked : .sideBySide,
    primarySurface: primarySurface,
    primaryWeight: children[0].weight,
    secondarySurface: secondarySurface,
    secondaryWeight: children[1].weight
)
```

- 修改后：policy 改成传递 `mainAxisSizing`，并把 `ExerciseRenderedSceneLayout` 升级为暴露 `primaryMainAxisSizing / secondaryMainAxisSizing`，为后续 renderer 和上层判断提供一致语义。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: makeScene(...), makeAccessorySceneNode(...), wrapMainSceneNode(...), makeVerticalSceneChild(...)
// 功能说明: 修改后 composition policy 已经全面切到 mainAxisSizing，但当前阶段仍保持既有布局语义不变。
return ExerciseScene(
    root: wrapMainSceneNode(
        mainSceneNode,
        accessorySceneNode: accessoryScene.node,
        accessoryMainAxisSizing: accessoryScene.mainAxisSizing,
        preferences: preferences
    )
)

private static func makeAccessorySceneNode(
    preferences: ExerciseLayoutPreferences
) -> (node: ExerciseSceneNode, mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing)? {
    // ...
    return (
        node: accessoryChildren[0].node,
        mainAxisSizing: accessoryChildren[0].mainAxisSizing
    )
}

private static func wrapMainSceneNode(
    _ mainSceneNode: ExerciseSceneNode,
    accessorySceneNode: ExerciseSceneNode,
    accessoryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing,
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    .makeSplit(
        axis: .vertical,
        children: [
            ExerciseSceneSplitChild(
                node: mainSceneNode,
                mainAxisSizing: .weighted(3)
            ),
            ExerciseSceneSplitChild(
                node: accessorySceneNode,
                mainAxisSizing: accessoryMainAxisSizing
            )
        ]
    )
}

private static func makeVerticalSceneChild(
    for surface: ExerciseSurfaceNode,
    weight: Double = 1
) -> ExerciseSceneSplitChild {
    ExerciseSceneSplitChild(
        node: .surface(surface),
        mainAxisSizing: surface.preferredVerticalMainAxisSizing(
            weight: weight
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseRenderedSceneLayout, ExercisePresentationState.renderedSceneLayout(for:)
// 功能说明: 修改后 renderedSceneLayout 不再暴露旧权重字段，而是直接保留新的主轴尺寸语义。
struct ExerciseRenderedSceneLayout: Equatable, Sendable {
    var arrangement: ExerciseRenderedSceneArrangement
    var primarySurface: ExerciseSurfaceNode
    var primaryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing
    var secondarySurface: ExerciseSurfaceNode?
    var secondaryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing?
}

return ExerciseRenderedSceneLayout(
    arrangement: axis == .vertical ? .stacked : .sideBySide,
    primarySurface: primarySurface,
    primaryMainAxisSizing: children[0].mainAxisSizing,
    secondarySurface: secondarySurface,
    secondaryMainAxisSizing: children[1].mainAxisSizing
)
```

## 3. `ExerciseCompositionValidation.swift`：把 validation 从旧 contract 迁到新 contract，并新增阶段 1 夹具

- 修改前：validation 仍围绕 `children[i].sizing`、`hasVerticalFitContentSplit` 和旧 `weight` 语义断言；同时还没有一组专门验证 `presentationStyle`、`withPresentationStyle(...)`、`hasMixedMainAxisSizing(...)` 与 `requiresViewportPinnedHeight` 的阶段 `1` 夹具。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures(), validateVerticalFitContentSplitSizingTracksSurfaceKinds(), validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()
// 功能说明: 修改前 validation 仍基于旧 contract 名称断言 vertical fit-content 语义，且没有阶段 1 的 shared contract 专用夹具。
ExerciseCompositionValidationFixture(
    name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
    validate: validateSharedSceneContractsCoverBasicLayouts
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
),

if axis != .vertical
    || children.count != 2
    || children[0].sizing != .fitContent
    || children[1].sizing != .fill {
    issues.append(
        issue(
            fixtureName,
            "staff -> fretboard 的 vertical split 应保持上方 prompt fitContent、下方 fretboard fill。"
        )
    )
}

if !positionPromptScene.hasVerticalFitContentSplit {
    issues.append(
        issue(
            fixtureName,
            "包含 natural note strip answer 的 vertical split 应触发 fitContent scene 语义。"
        )
    )
}

if children.contains(where: { $0.sizing != .fill }) {
    issues.append(
        issue(
            fixtureName,
            "\(sceneDescription) 在阶段 0 仍应保持 sideBySide child 的默认 fill sizing。"
        )
    )
}
```

- 修改后：validation 完整迁移到新 contract，并新增 `validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing()`，专门冻结阶段 `1` 的 shared contract 行为。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures(), validateSharedSceneContractsCoverBasicLayouts(), validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing(), validateVerticalFitContentSplitSizingTracksSurfaceKinds(), validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()
// 功能说明: 修改后 validation 既覆盖旧场景不变量，也显式冻结了新的 presentationStyle / mainAxisSizing / helper 语义。
ExerciseCompositionValidationFixture(
    name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
    validate: validateSharedSceneContractsCoverBasicLayouts
),
ExerciseCompositionValidationFixture(
    name: "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing",
    validate: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
),

if children.count != 2
    || children[0].mainAxisSizing != .fitContent
    || children[1].mainAxisSizing != .weighted(1) {
    issues.append(
        issue(
            fixtureName,
            "stacked scene 应继续保持上方 staff fitContent、下方 fretboard weighted(1) 的主轴尺寸语义。"
        )
    )
}

let verticalRailStrip = ExerciseSurfaceNode.naturalNoteStripAnswer
    .withPresentationStyle(.verticalRail)
if verticalRailStrip.id != .naturalNoteStrip
    || verticalRailStrip.kind != .naturalNoteStrip
    || verticalRailStrip.roles != Set([.answer])
    || verticalRailStrip.presentationStyle != .verticalRail {
    issues.append(
        issue(
            fixtureName,
            "withPresentationStyle(.verticalRail) 应只修改 strip 的 presentation style，不改变 logical surface 身份。"
        )
    )
}

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
if !railScene.hasMixedMainAxisSizing(along: .horizontal) {
    issues.append(
        issue(
            fixtureName,
            "右侧 rail 的 horizontal split 在阶段 1 应能被 shared contract 表达为 mixed main-axis sizing。"
        )
    )
}
if !railScene.requiresViewportPinnedHeight {
    issues.append(
        issue(
            fixtureName,
            "包含 verticalRail surface 的 scene 在阶段 1 应能通过 shared helper 要求 viewport pin 高度。"
        )
    )
}

if !positionPromptScene.hasMixedMainAxisSizing(along: .vertical) {
    issues.append(
        issue(
            fixtureName,
            "包含 natural note strip answer 的 vertical split 应触发 vertical mixed main-axis sizing 语义。"
        )
    )
}

if children.contains(where: { !$0.mainAxisSizing.isWeighted }) {
    issues.append(
        issue(
            fixtureName,
            "\(sceneDescription) 在阶段 0 仍应保持 sideBySide child 的默认 weighted 主轴尺寸语义。"
        )
    )
}
```

## 4. iOS / macOS renderer 与 controller：旧 helper / 字段名同步迁移到新 contract

- 修改前：platform renderer 仍通过 `hasVerticalFitContentSplit`、`children[index].sizing`、`children[index].weight` 来理解 shared tree；controller 也只用 `hasVerticalFitContentSplit` 决定是否 pin viewport 高度。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: prefersFlexibleVerticalFretboardHeight, renderSplit(axis:children:in:)
// 功能说明: 修改前 renderer 仍消费旧 contract 的 sizing / weight / hasVerticalFitContentSplit。
private var prefersFlexibleVerticalFretboardHeight: Bool {
    currentPresentationState?.scene.hasVerticalFitContentSplit(
        containing: .fretboard
    ) ?? false
}

if axis == .vertical {
    for (index, childHostView) in childHostViews.enumerated() {
        guard children[index].sizing == .fitContent else {
            continue
        }
        childHostView.setContentHuggingPriority(.required, for: .vertical)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    }
}

let fillIndices = children.indices.filter {
    children[$0].sizing == .fill
}

let referenceWeight = max(children[referenceIndex].weight, 0.0001)
let childWeight = max(children[index].weight, 0.0001)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: updateSceneViewportHeightConstraint()
// 功能说明: 修改前 controller 只会在 vertical fit-content 场景启用 viewport 高度约束。
private func updateSceneViewportHeightConstraint() {
    sceneViewportHeightConstraint?.isActive = exercisePresentationState.scene
        .hasVerticalFitContentSplit
}
```

- 修改后：平台层只做 contract 名称与 helper 的机械迁移，行为语义保持原状；macOS 对应文件同步做了同构修改。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: prefersFlexibleVerticalFretboardHeight, renderSplit(axis:children:in:)
// 功能说明: 修改后 renderer 已切到新 shared contract，但本阶段还没有开始实现 right rail 的实际分宽逻辑。
private var prefersFlexibleVerticalFretboardHeight: Bool {
    currentPresentationState?.scene.hasMixedMainAxisSizing(
        along: .vertical,
        containing: .fretboard
    ) ?? false
}

if axis == .vertical {
    for (index, childHostView) in childHostViews.enumerated() {
        guard !children[index].mainAxisSizing.isWeighted else {
            continue
        }
        childHostView.setContentHuggingPriority(.required, for: .vertical)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    }
}

let weightedIndices = children.indices.filter {
    children[$0].mainAxisSizing.isWeighted
}

let referenceWeight = max(
    children[referenceIndex].mainAxisSizing.weightedValue ?? 1,
    0.0001
)
let childWeight = max(
    children[index].mainAxisSizing.weightedValue ?? 1,
    0.0001
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: updateSceneViewportHeightConstraint()
// 功能说明: 修改后 controller 不再依赖旧的 hasVerticalFitContentSplit，而是统一改读新的 requiresViewportPinnedHeight helper。
private func updateSceneViewportHeightConstraint() {
    sceneViewportHeightConstraint?.isActive = exercisePresentationState.scene
        .requiresViewportPinnedHeight
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: prefersFlexibleVerticalFretboardHeight, renderSplit(axis:children:in:)
// 功能说明: macOS renderer 同步迁移到新的 mainAxisSizing / hasMixedMainAxisSizing shared contract。
private var prefersFlexibleVerticalFretboardHeight: Bool {
    currentPresentationState?.scene.hasMixedMainAxisSizing(
        along: .vertical,
        containing: .fretboard
    ) ?? false
}

let weightedIndices = children.indices.filter {
    children[$0].mainAxisSizing.isWeighted
}
let referenceWeight = max(
    children[referenceIndex].mainAxisSizing.weightedValue ?? 1,
    0.0001
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: updateSceneViewportHeightConstraint()
// 功能说明: macOS controller 同步切到新的 requiresViewportPinnedHeight helper。
private func updateSceneViewportHeightConstraint() {
    sceneViewportHeightConstraint?.isActive = exercisePresentationState.scene
        .requiresViewportPinnedHeight
}
```

## 验证结果

- `ReadLints` 检查以下文件：无新增 lint
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
  - `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 构建验证：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'platform=macOS' build`：通过
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'generic/platform=iOS Simulator' build`：通过

## 阶段 1 完成状态

- 已完成：
  - shared scene contract 升级为 `presentationStyle + mainAxisSizing`
  - policy / presentation / validation 迁移到新 contract
  - renderer / controller 同步迁移到新 helper
- 尚未开始：
  - `ExerciseCompositionPolicy` 正式发出 `verticalRail`
  - horizontal split 真正支持 rail 的 `fitContent / fixed` 分宽
  - 双平台 `NaturalNoteStripView` 的竖排实现

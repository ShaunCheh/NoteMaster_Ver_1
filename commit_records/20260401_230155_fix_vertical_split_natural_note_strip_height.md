# 20260401_230155_fix_vertical_split_natural_note_strip_height

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_230155`
- 记录范围：`positionPrompt` / vertical split 场景里，下方 `naturalNoteStrip` 被按整块 pane 拉伸、按钮文字需要向下滚动才能看到的根因修复
- 根因概括：
  - shared scene contract 只有 `weight`，没有“按内容高度布局”的语义
  - composition policy 会把 `fretboard -> naturalNoteStrip` 和 `staff -> fretboard` 一律投影成纯比例 vertical split
  - renderer 的 `renderSplit(...)` 会把所有 vertical child 都按权重拉伸，`embed(...)` 再把 surface 四边钉死到 host，导致下方 strip 被整块拉高
  - renderer 还会额外用 `safeAreaHeightAnchor * verticalHostHeightRatio` 硬性给 `fretboardHostView` 定高，和 split 分高同时生效
  - controller 没有在需要时把 `sceneContainerView` 收口到 viewport，高度冲突最终通过 scroll view 向下泄漏成“页面变长”
- 修改目标：
  - 保留 `verticalHostHeightRatio` 的既有语义
  - 让 `naturalNoteStrip`、`staff`、`targetPrompt` 这类有自然内容高度的 surface 参与 vertical split 时按内容高度收缩
  - 让 `fretboard` / `piano` 继续承担剩余空间
  - 在存在 `fitContent` vertical split 的场景里，把 `sceneContainerView` 收口到 viewport 高度
- 修改统计：`7 files changed, 387 insertions(+), 30 deletions(-)`
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. `ExerciseScene.swift`：shared split contract 从“只有权重”升级为“权重 + 尺寸语义”

- 修改前：`ExerciseSceneSplitChild` 只有 `weight`，`ExerciseScene.stacked(...)` 也只会构造两个默认 child。shared 层无法表达“这个 child 应该按内容高度收缩”。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSceneSplitChild.init(...), ExerciseScene.stacked(...)
// 功能说明: 修改前 split child 只有 weight，vertical split 无法表达 fit-content 语义。
struct ExerciseSceneSplitChild: Equatable, Sendable {
    var node: ExerciseSceneNode
    var weight: Double

    init(
        node: ExerciseSceneNode,
        weight: Double = 1
    ) {
        precondition(
            weight > 0,
            "Exercise scene split child weight must be greater than zero."
        )
        self.node = node
        self.weight = weight
    }
}

struct ExerciseScene: Equatable, Sendable {
    static func stacked(
        top: ExerciseSurfaceNode,
        bottom: ExerciseSurfaceNode
    ) -> ExerciseScene {
        ExerciseScene(
            root: .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(node: .surface(top)),
                    ExerciseSceneSplitChild(node: .surface(bottom))
                ]
            )
        )
    }
}
```

- 修改后：新增 `ExerciseSceneSplitChildSizing`，让 child 显式表达 `fill / fitContent`；同时把 `staff`、`targetPrompt`、`naturalNoteStrip` 的默认 vertical split 语义收口为 `fitContent`，再补上 `hasVerticalFitContentSplit`，供 renderer / controller 判断是否要切入新高度模型。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSceneSplitChild.init(...), ExerciseScene.stacked(...), ExerciseSurfaceNode.preferredVerticalSplitSizing, ExerciseScene.hasVerticalFitContentSplit
// 功能说明: 修改后 shared scene contract 可以表达 vertical split 里的内容驱动高度 child，并向平台层暴露可检测的 fit-content split 语义。
enum ExerciseSceneSplitChildSizing: String, Equatable, Hashable, Sendable {
    case fill
    case fitContent
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

struct ExerciseScene: Equatable, Sendable {
    static func stacked(
        top: ExerciseSurfaceNode,
        bottom: ExerciseSurfaceNode
    ) -> ExerciseScene {
        ExerciseScene(
            root: .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(
                        node: .surface(top),
                        sizing: top.preferredVerticalSplitSizing
                    ),
                    ExerciseSceneSplitChild(
                        node: .surface(bottom),
                        sizing: bottom.preferredVerticalSplitSizing
                    )
                ]
            )
        )
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

extension ExerciseScene {
    var hasVerticalFitContentSplit: Bool {
        root.hasVerticalFitContentSplit
    }
}
```

## 2. `ExerciseCompositionPolicy.swift`：让 vertical scene child 按 surface kind 自动带上 sizing

- 修改前：`makeMainSceneNode(...)` 和 `makeAccessorySceneNode(...)` 都只会构造默认 `ExerciseSceneSplitChild`。即使下方是 `naturalNoteStrip`，policy 也没有机会把它声明成“内容驱动高度 child”。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: ExerciseCompositionPolicy.makeScene(...), ExerciseCompositionPolicy.makeMainSceneNode(...), ExerciseCompositionPolicy.makeAccessorySceneNode(...), ExerciseCompositionPolicy.wrapMainSceneNode(...)
// 功能说明: 修改前 policy 只投影 weight，不投影 vertical split child 的尺寸语义。
static func makeScene(
    preferences: ExerciseLayoutPreferences
) -> ExerciseScene {
    let sceneSurfaces = resolvedSceneSurfaces(
        for: preferences
    )
    let mainSceneNode = makeMainSceneNode(
        from: sceneSurfaces,
        preferences: preferences
    )
    let accessorySceneNode = makeAccessorySceneNode(
        preferences: preferences
    )

    guard let accessorySceneNode else {
        return ExerciseScene(root: mainSceneNode)
    }

    return ExerciseScene(
        root: wrapMainSceneNode(
            mainSceneNode,
            accessorySceneNode: accessorySceneNode,
            preferences: preferences
        )
    )
}

private static func makeMainSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    switch resolvedMainLayoutPreset(for: preferences) {
    case .stacked:
        return .makeSplit(
            axis: .vertical,
            children: [
                ExerciseSceneSplitChild(node: .surface(sceneSurfaces.prompt)),
                ExerciseSceneSplitChild(node: .surface(sceneSurfaces.answer))
            ]
        )
    // ... 其余分支省略
    default:
        return .surface(sceneSurfaces.prompt)
    }
}

private static func makeAccessorySceneNode(
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode? {
    var accessoryChildren: [ExerciseSceneSplitChild] = []

    if preferences.isNaturalNoteStripVisible,
       preferences.compositionPreset != .fretboardToNaturalNoteStrip {
        accessoryChildren.append(
            ExerciseSceneSplitChild(
                node: .surface(.naturalNoteStripAccessory),
                weight: 0.7
            )
        )
    }

    if preferences.isPianoAccessoryVisible {
        accessoryChildren.append(
            ExerciseSceneSplitChild(
                node: .surface(.pianoAccessory),
                weight: 1.3
            )
        )
    }

    switch accessoryChildren.count {
    case 0:
        return nil
    case 1:
        return accessoryChildren[0].node
    default:
        return .makeSplit(
            axis: .vertical,
            children: accessoryChildren
        )
    }
}
```

- 修改后：新增 `makeVerticalSceneChild(...)`，让所有 vertical split child 都从 shared contract 的 `preferredVerticalSplitSizing` 派生 sizing；同时 accessory subtree 也把 `sizing` 一并带出，供外层 docked split 使用。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: ExerciseCompositionPolicy.makeScene(...), ExerciseCompositionPolicy.makeMainSceneNode(...), ExerciseCompositionPolicy.makeAccessorySceneNode(...), ExerciseCompositionPolicy.wrapMainSceneNode(...), ExerciseCompositionPolicy.makeVerticalSceneChild(...)
// 功能说明: 修改后 policy 会把 prompt/answer/accessory surface 的 vertical sizing 语义一起投影到 scene tree。
static func makeScene(
    preferences: ExerciseLayoutPreferences
) -> ExerciseScene {
    let sceneSurfaces = resolvedSceneSurfaces(
        for: preferences
    )
    let mainSceneNode = makeMainSceneNode(
        from: sceneSurfaces,
        preferences: preferences
    )
    let accessoryScene = makeAccessorySceneNode(
        preferences: preferences
    )

    guard let accessoryScene else {
        return ExerciseScene(root: mainSceneNode)
    }

    return ExerciseScene(
        root: wrapMainSceneNode(
            mainSceneNode,
            accessorySceneNode: accessoryScene.node,
            accessorySizing: accessoryScene.sizing,
            preferences: preferences
        )
    )
}

private static func makeMainSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    switch resolvedMainLayoutPreset(for: preferences) {
    case .stacked:
        return .makeSplit(
            axis: .vertical,
            children: [
                makeVerticalSceneChild(for: sceneSurfaces.prompt),
                makeVerticalSceneChild(for: sceneSurfaces.answer)
            ]
        )
    // ... 其余分支省略
    default:
        return .surface(sceneSurfaces.prompt)
    }
}

private static func makeAccessorySceneNode(
    preferences: ExerciseLayoutPreferences
) -> (node: ExerciseSceneNode, sizing: ExerciseSceneSplitChildSizing)? {
    var accessoryChildren: [ExerciseSceneSplitChild] = []

    if preferences.isNaturalNoteStripVisible,
       preferences.compositionPreset != .fretboardToNaturalNoteStrip {
        accessoryChildren.append(
            makeVerticalSceneChild(
                for: .naturalNoteStripAccessory,
                weight: 0.7
            )
        )
    }

    if preferences.isPianoAccessoryVisible {
        accessoryChildren.append(
            makeVerticalSceneChild(
                for: .pianoAccessory,
                weight: 1.3
            )
        )
    }

    switch accessoryChildren.count {
    case 0:
        return nil
    case 1:
        return (
            node: accessoryChildren[0].node,
            sizing: accessoryChildren[0].sizing
        )
    default:
        return (
            node: .makeSplit(
                axis: .vertical,
                children: accessoryChildren
            ),
            sizing: .fill
        )
    }
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

## 3. `iOSExerciseSceneRenderer.swift`：vertical split 只让 `fill` child 参与比例分配

- 修改前：`renderSplit(...)` 会对所有 vertical child 一律按 `weight` 建立高度比例；`rebuildVerticalFretboardHostHeightConstraint()` 还会额外给 `fretboardHostView` 施加基于 `safeAreaHeightAnchor` 的硬高度。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.renderSplit(...), iOSExerciseSceneRenderer.rebuildVerticalFretboardHostHeightConstraint(...)
// 功能说明: 修改前 vertical split 的所有 child 都被按 weight 拉伸，fretboard 还会额外吃一条 safe-area 高度硬约束。
private func renderSplit(
    axis: ExerciseSceneAxis,
    children: [ExerciseSceneSplitChild],
    in hostView: UIView
) {
    let childHostViews = children.map { _ in
        let childHostView = UIView()
        childHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(childHostView)
        return childHostView
    }

    for (index, child) in children.enumerated() {
        render(node: child.node, in: childHostViews[index])
    }

    for index in 1..<childHostViews.count {
        let previousHostView = childHostViews[index - 1]
        let childHostView = childHostViews[index]

        activeSceneConstraints.append(
            childHostView.topAnchor.constraint(
                equalTo: previousHostView.bottomAnchor,
                constant: metrics.surfaceSpacing
            )
        )

        let firstWeight = max(children[0].weight, 0.0001)
        let childWeight = max(children[index].weight, 0.0001)
        activeSceneConstraints.append(
            childHostViews[0].heightAnchor.constraint(
                equalTo: childHostView.heightAnchor,
                multiplier: firstWeight / childWeight
            )
        )
    }
}

private func rebuildVerticalFretboardHostHeightConstraint() {
    verticalFretboardHostHeightConstraint?.isActive = false
    verticalFretboardHostHeightConstraint = nil

    guard isShowingFretboard else {
        return
    }

    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: safeAreaHeightAnchor,
        multiplier: currentFretboardDisplayState.verticalHostHeightRatio
    )
}
```

- 修改后：`fitContent` child 会先获得 required hugging / compression resistance，并且不再进入比例分配；只有 `fill` child 之间才继续按 `weight` 建比例。`fretboard` 在包含 `fitContent` vertical split 的场景里不再用 required 级别强压 pane，而是降成高优先级目标高度。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.prefersFlexibleVerticalFretboardHeight, iOSExerciseSceneRenderer.renderSplit(...), iOSExerciseSceneRenderer.rebuildVerticalFretboardHostHeightConstraint(...)
// 功能说明: 修改后 renderer 会把 fit-content child 的高度留给内容决定，把 fill child 的剩余空间分配保持在 split 层收口。
private var prefersFlexibleVerticalFretboardHeight: Bool {
    currentPresentationState?.scene.hasVerticalFitContentSplit(
        containing: .fretboard
    ) ?? false
}

private func renderSplit(
    axis: ExerciseSceneAxis,
    children: [ExerciseSceneSplitChild],
    in hostView: UIView
) {
    let childHostViews = children.map { _ in
        let childHostView = UIView()
        childHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(childHostView)
        return childHostView
    }

    for (index, child) in children.enumerated() {
        render(node: child.node, in: childHostViews[index])
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

    let proportionalIndices: [Int]
    switch axis {
    case .vertical:
        let fillIndices = children.indices.filter {
            children[$0].sizing == .fill
        }
        proportionalIndices = fillIndices.isEmpty
            ? Array(children.indices)
            : fillIndices
    case .horizontal:
        proportionalIndices = Array(children.indices)
    }

    guard let referenceIndex = proportionalIndices.first else {
        return
    }

    for index in 1..<childHostViews.count {
        let previousHostView = childHostViews[index - 1]
        let childHostView = childHostViews[index]

        activeSceneConstraints.append(
            childHostView.topAnchor.constraint(
                equalTo: previousHostView.bottomAnchor,
                constant: metrics.surfaceSpacing
            )
        )

        guard proportionalIndices.contains(index), index != referenceIndex else {
            continue
        }

        let referenceWeight = max(children[referenceIndex].weight, 0.0001)
        let childWeight = max(children[index].weight, 0.0001)
        activeSceneConstraints.append(
            childHostViews[referenceIndex].heightAnchor.constraint(
                equalTo: childHostView.heightAnchor,
                multiplier: referenceWeight / childWeight
            )
        )
    }
}

private func rebuildVerticalFretboardHostHeightConstraint() {
    verticalFretboardHostHeightConstraint?.isActive = false
    verticalFretboardHostHeightConstraint = nil

    guard isShowingFretboard else {
        return
    }

    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: safeAreaHeightAnchor,
        multiplier: currentFretboardDisplayState.verticalHostHeightRatio
    )
    verticalFretboardHostHeightConstraint?.priority = prefersFlexibleVerticalFretboardHeight
        ? .defaultHigh
        : .required
}
```

## 4. `macOSExerciseSceneRenderer.swift`：macOS 同步切换到 `fitContent + fill` 的 vertical split 模型

- 修改前：macOS renderer 的 vertical split 逻辑和 iOS 一样，所有 child 按 `weight` 比例拉伸，`fretboardHostView` 同样会吃一条 `safeAreaHeightAnchor * verticalHostHeightRatio` 的 required 高度。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: macOSExerciseSceneRenderer.renderSplit(...), macOSExerciseSceneRenderer.rebuildVerticalFretboardHostHeightConstraint(...)
// 功能说明: 修改前 macOS renderer 仍然把 strip/staff/targetPrompt 当成 fill pane，而不是内容驱动高度 child。
private func renderSplit(
    axis: ExerciseSceneAxis,
    children: [ExerciseSceneSplitChild],
    in hostView: NSView
) {
    let childHostViews = children.map { _ in
        let childHostView = NSView()
        childHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(childHostView)
        return childHostView
    }

    for (index, child) in children.enumerated() {
        render(node: child.node, in: childHostViews[index])
    }

    for index in 1..<childHostViews.count {
        let previousHostView = childHostViews[index - 1]
        let childHostView = childHostViews[index]

        activeSceneConstraints.append(
            childHostView.topAnchor.constraint(
                equalTo: previousHostView.bottomAnchor,
                constant: metrics.surfaceSpacing
            )
        )

        let firstWeight = max(children[0].weight, 0.0001)
        let childWeight = max(children[index].weight, 0.0001)
        activeSceneConstraints.append(
            childHostViews[0].heightAnchor.constraint(
                equalTo: childHostView.heightAnchor,
                multiplier: firstWeight / childWeight
            )
        )
    }
}

private func rebuildVerticalFretboardHostHeightConstraint() {
    verticalFretboardHostHeightConstraint?.isActive = false
    verticalFretboardHostHeightConstraint = nil

    guard isShowingFretboard else {
        return
    }

    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: safeAreaHeightAnchor,
        multiplier: currentFretboardDisplayState.verticalHostHeightRatio
    )
}
```

- 修改后：macOS 路径和 iOS 对齐，shared contract 里的 `sizing` 会直接参与 vertical split 布局，`fretboard` 的目标高度也在包含 `fitContent` split 的场景里降成可让步约束。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: macOSExerciseSceneRenderer.prefersFlexibleVerticalFretboardHeight, macOSExerciseSceneRenderer.renderSplit(...), macOSExerciseSceneRenderer.rebuildVerticalFretboardHostHeightConstraint(...)
// 功能说明: 修改后 macOS renderer 与 iOS 一致，把高度分配的真相收口到 split sizing，而不是让所有 child 一律被 pane 拉伸。
private var prefersFlexibleVerticalFretboardHeight: Bool {
    currentPresentationState?.scene.hasVerticalFitContentSplit(
        containing: .fretboard
    ) ?? false
}

private func renderSplit(
    axis: ExerciseSceneAxis,
    children: [ExerciseSceneSplitChild],
    in hostView: NSView
) {
    let childHostViews = children.map { _ in
        let childHostView = NSView()
        childHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(childHostView)
        return childHostView
    }

    for (index, child) in children.enumerated() {
        render(node: child.node, in: childHostViews[index])
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

    let proportionalIndices: [Int]
    switch axis {
    case .vertical:
        let fillIndices = children.indices.filter {
            children[$0].sizing == .fill
        }
        proportionalIndices = fillIndices.isEmpty
            ? Array(children.indices)
            : fillIndices
    case .horizontal:
        proportionalIndices = Array(children.indices)
    }

    guard let referenceIndex = proportionalIndices.first else {
        return
    }

    for index in 1..<childHostViews.count {
        let previousHostView = childHostViews[index - 1]
        let childHostView = childHostViews[index]

        activeSceneConstraints.append(
            childHostView.topAnchor.constraint(
                equalTo: previousHostView.bottomAnchor,
                constant: metrics.surfaceSpacing
            )
        )

        guard proportionalIndices.contains(index), index != referenceIndex else {
            continue
        }

        let referenceWeight = max(children[referenceIndex].weight, 0.0001)
        let childWeight = max(children[index].weight, 0.0001)
        activeSceneConstraints.append(
            childHostViews[referenceIndex].heightAnchor.constraint(
                equalTo: childHostView.heightAnchor,
                multiplier: referenceWeight / childWeight
            )
        )
    }
}

private func rebuildVerticalFretboardHostHeightConstraint() {
    verticalFretboardHostHeightConstraint?.isActive = false
    verticalFretboardHostHeightConstraint = nil

    guard isShowingFretboard else {
        return
    }

    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: safeAreaHeightAnchor,
        multiplier: currentFretboardDisplayState.verticalHostHeightRatio
    )
    verticalFretboardHostHeightConstraint?.priority = prefersFlexibleVerticalFretboardHeight
        ? .defaultHigh
        : .required
}
```

## 5. `iOSViewController.swift`：只在 vertical fit-content split 场景里把 sceneContainerView 收口到 viewport

- 修改前：controller 只把 `sceneContainerView` 贴到 `contentView` 的上下边，没有任何 viewport 高度收口逻辑。scene 内部一旦出现过高 pane，scroll view 就会直接变长。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.configureLayout(), iOSViewController.renderExercisePresentationState()
// 功能说明: 修改前 iOS 控制器没有针对 fit-content 场景的 viewport 高度约束，scene 高度完全由内容链反推。
private let scrollView = UIScrollView()
private let contentView = UIView()
private let pianoDemoContainerView = UIView()

private func configureLayout() {
    let safeArea = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
        contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        exerciseSceneRenderer.sceneContainerView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        exerciseSceneRenderer.sceneContainerView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor
        ),
        exerciseSceneRenderer.sceneContainerView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor
        ),
        exerciseSceneRenderer.sceneContainerView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}

private func renderExercisePresentationState() {
    exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
}
```

- 修改后：新增 `sceneViewportHeightConstraint`，并在 `renderExercisePresentationState()` 前按 `exercisePresentationState.scene.hasVerticalFitContentSplit` 动态启用。也就是说，只有真的进入这次新高度模型的 vertical split 场景时，scene 才会被收口到当前 viewport。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.configureLayout(), iOSViewController.renderExercisePresentationState(), iOSViewController.updateSceneViewportHeightConstraint()
// 功能说明: 修改后 iOS 控制器会在 fit-content vertical split 场景里把 sceneContainerView 收口到 viewport，阻止 scroll view 因内部 pane 冲突继续增高。
private let scrollView = UIScrollView()
private let contentView = UIView()
private let pianoDemoContainerView = UIView()
private var sceneViewportHeightConstraint: NSLayoutConstraint?

private func configureLayout() {
    let safeArea = view.safeAreaLayoutGuide
    sceneViewportHeightConstraint = exerciseSceneRenderer.sceneContainerView
        .heightAnchor.constraint(
            equalTo: safeArea.heightAnchor,
            constant: -(Layout.contentTopInset + Layout.bottomInset)
        )

    NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
        contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        exerciseSceneRenderer.sceneContainerView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        exerciseSceneRenderer.sceneContainerView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor
        ),
        exerciseSceneRenderer.sceneContainerView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor
        ),
        exerciseSceneRenderer.sceneContainerView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])

    updateSceneViewportHeightConstraint()
}

private func renderExercisePresentationState() {
    updateSceneViewportHeightConstraint()
    exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
}

private func updateSceneViewportHeightConstraint() {
    sceneViewportHeightConstraint?.isActive = exercisePresentationState.scene
        .hasVerticalFitContentSplit
}
```

## 6. `macOSViewController.swift`：macOS 同步只在需要时启用 viewport 收口约束

- 修改前：macOS 控制器同样只是把 `sceneContainerView` 贴在 `contentView` 上，没有针对 vertical fit-content scene 的高度收口。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.configureLayout(), macOSViewController.renderExercisePresentationState()
// 功能说明: 修改前 macOS 控制器没有收口 sceneContainerView 高度，布局冲突会直接膨胀 document view。
private let scrollView = NSScrollView()
private let contentView = NSView()
private let pianoDemoContainerView = NSView()

private func configureLayout() {
    let safeArea = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
        contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
        contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        exerciseSceneRenderer.sceneContainerView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        exerciseSceneRenderer.sceneContainerView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor
        ),
        exerciseSceneRenderer.sceneContainerView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor
        ),
        exerciseSceneRenderer.sceneContainerView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}

private func renderExercisePresentationState() {
    exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
}
```

- 修改后：新增 `sceneViewportHeightConstraint` 和 `updateSceneViewportHeightConstraint()`，与 iOS 保持同一套启用条件。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.configureLayout(), macOSViewController.renderExercisePresentationState(), macOSViewController.updateSceneViewportHeightConstraint()
// 功能说明: 修改后 macOS 控制器也只在 vertical fit-content split 场景下锁住 sceneContainerView 的 viewport 高度。
private let scrollView = NSScrollView()
private let contentView = NSView()
private let pianoDemoContainerView = NSView()
private var sceneViewportHeightConstraint: NSLayoutConstraint?

private func configureLayout() {
    let safeArea = view.safeAreaLayoutGuide
    sceneViewportHeightConstraint = exerciseSceneRenderer.sceneContainerView
        .heightAnchor.constraint(
            equalTo: safeArea.heightAnchor,
            constant: -(Layout.contentTopInset + Layout.bottomInset)
        )

    NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
        contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
        contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        exerciseSceneRenderer.sceneContainerView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        exerciseSceneRenderer.sceneContainerView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor
        ),
        exerciseSceneRenderer.sceneContainerView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor
        ),
        exerciseSceneRenderer.sceneContainerView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])

    updateSceneViewportHeightConstraint()
}

private func renderExercisePresentationState() {
    updateSceneViewportHeightConstraint()
    exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
}

private func updateSceneViewportHeightConstraint() {
    sceneViewportHeightConstraint?.isActive = exercisePresentationState.scene
        .hasVerticalFitContentSplit
}
```

## 7. `ExerciseCompositionValidation.swift`：新增 vertical fit-content 语义夹具与回归清单

- 修改前：validation 只能覆盖 stacked / side / single 的基础 scene contract，以及 accessory scene 的结构；没有专门验证 `fitContent` vertical split 的 child sizing。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures(), ExerciseCompositionValidationRunner.manualChecklist(for:)
// 功能说明: 修改前 validation 不会检查 vertical split 中的 fit-content sizing，也没有针对“首屏内可见 strip 文本”的手工回归项。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
            validate: validateSharedSceneContractsCoverBasicLayouts
        ),
        ExerciseCompositionValidationFixture(
            name: "shared_surface_state_defaults_follow_surface_roles",
            validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
        ),
        ExerciseCompositionValidationFixture(
            name: "accessory_scene_nodes_follow_presentation_strategy",
            validate: validateAccessorySceneNodesFollowPresentationStrategy
        )
    ]
}

static func manualChecklist(
    for platform: ExerciseCompositionValidationPlatform
) -> [String] {
    [
        "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
        "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
    ]
}
```

- 修改后：新增 `vertical_fit_content_split_sizing_tracks_surface_kinds` 夹具，自动验证 `staff -> fretboard`、`fretboard -> naturalNoteStrip`、`threePane accessory split`、`sideBySide` 的 sizing 语义；同时把“下方 strip 首屏内可见”加入手工回归清单。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures(), ExerciseCompositionValidationRunner.manualChecklist(for:), ExerciseCompositionValidationRunner.validateVerticalFitContentSplitSizingTracksSurfaceKinds()
// 功能说明: 修改后 validation 会自动锁住 vertical fit-content split 的 shared 语义，并要求手工确认 positionPrompt 下方 strip 不再被首屏外拉伸。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
            validate: validateSharedSceneContractsCoverBasicLayouts
        ),
        ExerciseCompositionValidationFixture(
            name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
            validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
        ),
        ExerciseCompositionValidationFixture(
            name: "shared_surface_state_defaults_follow_surface_roles",
            validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
        )
    ]
}

static func manualChecklist(
    for platform: ExerciseCompositionValidationPlatform
) -> [String] {
    [
        "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
        "确认 `positionPrompt` 下方的 `natural note strip` 不再被拉伸到超出首屏；无需向下滚动就能看见按钮文字。",
        "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
    ]
}

static func validateVerticalFitContentSplitSizingTracksSurfaceKinds()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "vertical_fit_content_split_sizing_tracks_surface_kinds"
    var issues: [ExerciseCompositionValidationIssue] = []

    let staffStackedScene = ExerciseScene.stacked(
        top: .staffPrompt,
        bottom: .fretboardAnswer
    )
    switch staffStackedScene.root {
    case let .split(axis, children):
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
    default:
        issues.append(
            issue(
                fixtureName,
                "staff -> fretboard stacked scene 应继续落成 vertical split。"
            )
        )
    }

    let positionPromptScene = ExerciseCompositionPolicy.makeScene(
        preferences: ExerciseLayoutPreferences(
            compositionPreset: .fretboardToNaturalNoteStrip,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: false,
            isAccessoryExpanded: true
        )
    )
    switch positionPromptScene.root {
    case let .split(axis, children):
        if axis != .vertical
            || children.count != 2
            || children[0].sizing != .fill
            || children[1].sizing != .fitContent {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 vertical split 应保持上方 fretboard fill、下方 strip fitContent。"
                )
            )
        }
    default:
        issues.append(
            issue(
                fixtureName,
                "positionPrompt 的主视觉 scene 应继续落成 vertical split。"
            )
        )
    }

    return issues
}
```

## 8. 验证结果

- `ReadLints`
  结果：`No linter errors found.`
- macOS Debug 构建
  命令：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build`
  结果：`BUILD SUCCEEDED`
- iOS Simulator Debug 构建
  命令：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build`
  结果：`BUILD SUCCEEDED`

## 9. 构建备注

- 本次修复不是通过缩小按钮样式参数规避问题，而是把 vertical split 的 shared contract、policy 投影、renderer 高度分配、controller viewport 收口一起改到同一套模型上。
- 双平台构建都成功，但构建日志里仍保留项目内既有 warning 链，例如 `ExerciseCompositionValidation.swift` 的 main actor isolation warning 与 `FretboardNaturalNoteTrainer.swift` 的 unused result warning；本次没有顺带处理这类既有警告。

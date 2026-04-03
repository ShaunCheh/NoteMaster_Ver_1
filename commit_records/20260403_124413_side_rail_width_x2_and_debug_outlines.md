# 20260403_124413_side_rail_width_x2_and_debug_outlines

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260403_124413`
- 记录范围：根据当前 `git status` / `git diff`，记录这次未提交的 6 个代码文件改动
- 本记录不放原始 `git diff`，只按真实改动说明“修改前 / 修改后”
- 本轮 `git diff --stat` 结果：`6 files changed, 98 insertions(+), 7 deletions(-)`
- 本轮实际改动文件：
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. 本轮目标

- 先把 `side` 布局下左右两个根级容器边界画出来，直接观察红色 `fretboard` 容器和蓝色 `naturalNoteStrip` 容器的真实范围。
- 然后把 `side` 模式下右侧 `naturalNoteStrip` 的宽度改成当前的 `2` 倍，但不改按钮边长，不改 `fretboard` 的高度链路。
- 宽度放大不能靠平台层写死像素值，而要沿着现有 shared `rail contract -> 双端 intrinsic size -> sideBySide fitContent` 这条链路根因收口。

## 2. 修改一：给 side 根级左右容器加可视化边框

### 2.1 macOS renderer 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数/符号: SceneHostView, syncSplit(axis:children:in:path:state:)
// 修改前说明: SceneHostView 只承担 host 容器职责，不绘制边框。
// side 根级 horizontal split 的 child host 创建后，直接进入 sizing / 约束链，没有单独的容器可视化入口。
private final class SceneHostView: NSView {
    let path: SceneHostPath

    init(path: SceneHostPath) {
        self.path = path
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        identifier = NSUserInterfaceItemIdentifier(
            "exercise-scene-host-\(path.identifierToken)"
        )
    }
}

private func syncSplit(
    axis: ExerciseSceneAxis,
    children: [ExerciseSceneSplitChild],
    in hostView: SceneHostView,
    path: SceneHostPath,
    state: inout SceneSyncState
) {
    let childHostViews = children.enumerated().map { index, child in
        let childHostPath = path.appending(.splitChild(index))
        let childHostView = ensureSceneHost(
            at: childHostPath,
            in: hostView,
            state: &state
        )
        sync(
            node: child.node,
            in: childHostView,
            path: childHostPath,
            state: &state
        )
        return childHostView
    }

    for (index, childHostView) in childHostViews.enumerated() {
        configureMainAxisSizing(
            children[index].mainAxisSizing,
            for: childHostView,
            axis: axis
        )
    }
}
```

### 2.2 macOS renderer 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数/符号: SceneHostView.applyContainerOutline(_:),
//           syncSplit(axis:children:in:path:state:),
//           applySideBySideContainerOutlines(to:axis:path:)
// 修改后说明: 在根级 sideBySide horizontal split 上，给左右两个 child host 分别描边。
// 左侧容器用红色，右侧容器用蓝色，只用于可视化当前两个根级容器的真实边界。
private final class SceneHostView: NSView {
    let path: SceneHostPath

    init(path: SceneHostPath) {
        self.path = path
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        identifier = NSUserInterfaceItemIdentifier(
            "exercise-scene-host-\(path.identifierToken)"
        )
    }

    func applyContainerOutline(color: NSColor?) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = color == nil ? 0 : 14
        layer?.borderWidth = color == nil ? 0 : 2
        layer?.borderColor = color?.withAlphaComponent(0.9).cgColor
    }
}

private func syncSplit(
    axis: ExerciseSceneAxis,
    children: [ExerciseSceneSplitChild],
    in hostView: SceneHostView,
    path: SceneHostPath,
    state: inout SceneSyncState
) {
    let childHostViews = children.enumerated().map { index, child in
        let childHostPath = path.appending(.splitChild(index))
        let childHostView = ensureSceneHost(
            at: childHostPath,
            in: hostView,
            state: &state
        )
        sync(
            node: child.node,
            in: childHostView,
            path: childHostPath,
            state: &state
        )
        return childHostView
    }

    applySideBySideContainerOutlines(
        to: childHostViews,
        axis: axis,
        path: path
    )

    for (index, childHostView) in childHostViews.enumerated() {
        configureMainAxisSizing(
            children[index].mainAxisSizing,
            for: childHostView,
            axis: axis
        )
    }
}

private func applySideBySideContainerOutlines(
    to childHostViews: [SceneHostView],
    axis: ExerciseSceneAxis,
    path: SceneHostPath
) {
    let shouldOutlineContainers = axis == .horizontal
        && path == .root
        && childHostViews.count == 2
        && currentPresentationState?.renderedSceneLayout?.arrangement == .sideBySide

    for (index, childHostView) in childHostViews.enumerated() {
        childHostView.applyContainerOutline(
            color: shouldOutlineContainers
                ? sideBySideContainerOutlineColor(for: index)
                : nil
        )
    }
}
```

### 2.3 iOS renderer 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数: renderSplit(axis:children:in:)
// 修改前说明: iOS 侧同样只有 child host 的创建和布局，没有针对 side 根级容器的描边入口。
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

    for (index, childHostView) in childHostViews.enumerated() {
        configureMainAxisSizing(
            children[index].mainAxisSizing,
            for: childHostView,
            axis: axis
        )
    }
}
```

### 2.4 iOS renderer 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数/符号: renderSplit(axis:children:in:),
//           applySideBySideContainerOutlines(to:axis:hostView:)
// 修改后说明: iOS 侧与 macOS 对齐，在根级 sideBySide horizontal split 上给左右 child host 加调试边框。
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

    applySideBySideContainerOutlines(
        to: childHostViews,
        axis: axis,
        hostView: hostView
    )

    for (index, child) in children.enumerated() {
        render(node: child.node, in: childHostViews[index])
    }
}

private func applySideBySideContainerOutlines(
    to childHostViews: [UIView],
    axis: ExerciseSceneAxis,
    hostView: UIView
) {
    let shouldOutlineContainers = axis == .horizontal
        && childHostViews.count == 2
        && hostView.superview === sceneContentView
        && currentPresentationState?.renderedSceneLayout?.arrangement == .sideBySide

    for (index, childHostView) in childHostViews.enumerated() {
        let outlineColor = shouldOutlineContainers
            ? sideBySideContainerOutlineColor(for: index)
            : nil
        childHostView.layer.cornerRadius = outlineColor == nil ? 0 : 14
        childHostView.layer.cornerCurve = .continuous
        childHostView.layer.borderWidth = outlineColor == nil ? 0 : 2
        childHostView.layer.borderColor = outlineColor?
            .withAlphaComponent(0.9)
            .cgColor
    }
}
```

### 2.5 这一组修改解决了什么

- 把“红色容器”和“蓝色容器”的真实边界从抽象约束链变成了可见结果。
- 后续关于 `fretboard` 白边、`notestrip` 是否贴边、哪一层在居中，都可以直接对着容器边界判断，不需要先猜。

## 3. 修改二：把 side rail 的共享横向宽度语义从 1 倍升级到 2 倍

### 3.1 shared rail contract 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
// 修改前说明: rail contract 只描述按钮边长、主轴内容高度和横向 fitContent。
// 横向宽度没有额外倍率，right rail 的总宽度就是“左右内边距 + 1 个按钮宽度”。
struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 50
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        verticalAlignment: .centered
    )

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
}
```

### 3.2 shared rail contract 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail,
//           ExerciseNaturalNoteStripRailContract.resolvedCrossAxisWidthScale
// 修改后说明: shared rail contract 新增横向宽度倍率字段，并把默认值设为 2。
// 这样 side 右侧 rail 的总宽度会继续保持 fitContent 语义，但“内容宽度”本身变成当前的 2 倍。
struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 50
    static let defaultCrossAxisWidthScale: Double = 2
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        crossAxisWidthScale: defaultCrossAxisWidthScale,
        verticalAlignment: .centered
    )

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var crossAxisWidthScale: Double
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment

    var resolvedCrossAxisWidthScale: Double {
        max(crossAxisWidthScale, 1)
    }
}
```

### 3.3 这一改动解决了什么

- 宽度翻倍不再依赖平台层硬编码像素，也不需要改 `ExerciseCompositionPolicy` 的 split 常量。
- 只要 scene 命中 `defaultSideBySideAnswerRail`，横向宽度倍率就会继续沿 shared contract 向双端传播。
- 这保持了当前方案 B 的分层：shared contract 决定语义，平台 view 只消费 contract。

## 4. 修改三：让双端 natural note strip 直接消费新的宽度倍率

### 4.1 macOS `NaturalNoteStripView` 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号: verticalRailIntrinsicWidth
// 修改前说明: rail 的 intrinsic width 只等于“左右内边距 + 1 个按钮宽度”。
private var activeRailButtonExtent: CGFloat {
    CGFloat(activeRailContract.buttonExtent)
}

private var verticalRailIntrinsicWidth: CGFloat {
    switch activeRailContract.crossAxisPolicy {
    case .fitContent:
        return Style.contentInsets.left
            + activeRailButtonExtent
            + Style.contentInsets.right
    }
}
```

### 4.2 macOS `NaturalNoteStripView` 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号: activeRailCrossAxisWidthScale, verticalRailContentWidth, verticalRailIntrinsicWidth
// 修改后说明: 先计算 rail 的基础内容宽度，再乘上 shared contract 给出的横向倍率。
// 当前默认倍率是 2，所以 side rail 的卡片宽度会变成当前基础宽度的 2 倍。
private var activeRailButtonExtent: CGFloat {
    CGFloat(activeRailContract.buttonExtent)
}

private var activeRailCrossAxisWidthScale: CGFloat {
    CGFloat(activeRailContract.resolvedCrossAxisWidthScale)
}

private var verticalRailContentWidth: CGFloat {
    Style.contentInsets.left
        + activeRailButtonExtent
        + Style.contentInsets.right
}

private var verticalRailIntrinsicWidth: CGFloat {
    switch activeRailContract.crossAxisPolicy {
    case .fitContent:
        return verticalRailContentWidth * activeRailCrossAxisWidthScale
    }
}
```

### 4.3 iOS `NaturalNoteStripView` 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号: verticalRailIntrinsicWidth
// 修改前说明: iOS 侧 rail 宽度计算与 macOS 对齐，同样只有基础内容宽度，没有倍率层。
private var activeRailButtonExtent: CGFloat {
    CGFloat(activeRailContract.buttonExtent)
}

private var verticalRailIntrinsicWidth: CGFloat {
    switch activeRailContract.crossAxisPolicy {
    case .fitContent:
        return directionalLayoutMargins.leading
            + activeRailButtonExtent
            + directionalLayoutMargins.trailing
    }
}
```

### 4.4 iOS `NaturalNoteStripView` 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号: activeRailCrossAxisWidthScale, verticalRailContentWidth, verticalRailIntrinsicWidth
// 修改后说明: iOS 侧也直接消费 shared 宽度倍率，保证双端视觉结果一致。
private var activeRailButtonExtent: CGFloat {
    CGFloat(activeRailContract.buttonExtent)
}

private var activeRailCrossAxisWidthScale: CGFloat {
    CGFloat(activeRailContract.resolvedCrossAxisWidthScale)
}

private var verticalRailContentWidth: CGFloat {
    directionalLayoutMargins.leading
        + activeRailButtonExtent
        + directionalLayoutMargins.trailing
}

private var verticalRailIntrinsicWidth: CGFloat {
    switch activeRailContract.crossAxisPolicy {
    case .fitContent:
        return verticalRailContentWidth * activeRailCrossAxisWidthScale
    }
}
```

### 4.5 这一组修改解决了什么

- side 右侧 `naturalNoteStrip` 现在不是“按钮变大”，而是“卡片宽度变成原来的 2 倍”。
- 由于左右 split 仍然保持 `fitContent`，蓝色容器会自动跟着 `notestrip` 的 intrinsic width 变宽，红色容器自动缩窄。
- 高度链路没有动，`fretboard` 仍然保持当前 `fillAvailableHeight` 语义。

## 5. 修改四：同步 validation，让 shared 断言显式冻结新宽度倍率

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// 修改前说明: validation 只冻结了 contentSized / fitContent / centered，
// 还没有把 rail 的横向宽度倍率纳入 shared 默认语义。
if railContract.mainAxisPolicy != .contentSized
    || railContract.crossAxisPolicy != .fitContent
    || railContract.verticalAlignment != .centered {
    issues.append(
        issue(
            fixtureName,
            "阶段 1 的 rail contract 应继续给出 contentSized / fitContent / centered 的 shared 布局语义。"
        )
    )
}
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// 修改后说明: validation 现在同时冻结 crossAxisWidthScale，
// 明确要求 side rail 的 shared 默认横向宽度语义是 fitContent(x2)。
if railContract.mainAxisPolicy != .contentSized
    || railContract.crossAxisPolicy != .fitContent
    || railContract.crossAxisWidthScale
    != ExerciseNaturalNoteStripRailContract.defaultCrossAxisWidthScale
    || railContract.verticalAlignment != .centered {
    issues.append(
        issue(
            fixtureName,
            "阶段 1 的 rail contract 应继续给出 contentSized / fitContent(x2) / centered 的 shared 布局语义。"
        )
    )
}
```

### 5.3 这一改动解决了什么

- 这次“宽度翻倍”不只是运行时碰巧生效，而是被 shared validation 显式冻结下来了。
- 以后如果有人误把 rail 宽度倍率改回 `1` 或删掉倍率字段，validation 会直接暴露回归。

## 6. 本轮没有改什么

- 没有修改 `ExerciseCompositionPolicy.makeSideBySideSceneNode()` 的左右 split sizing 常量。
- 没有修改 `ExerciseFretboardLayoutContract`，所以 `fretboard` 的高度策略仍然是 side 下 `fillAvailableHeight`。
- 没有修改 `naturalNoteStrip` 的按钮边长；按钮仍然是 `50 x 50`。
- 没有新增 settings 入口，也没有把 rail 宽度倍率暴露成用户设置项。

## 7. 验证结果

- `ReadLints` 检查了本轮改动文件：无 linter 错误。
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=macOS,name=My Mac' build`：`BUILD SUCCEEDED`。
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build`：`BUILD SUCCEEDED`。
- macOS 运行时 smoke：`NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression .../NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1` 最终输出 `PASS scenario=layout_preset_regression finalLayout=sideBySide`。
- iOS 运行时 smoke：`SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression xcrun simctl launch ... shaunyu.NoteMaster-Ver-1` 最终输出 `PASS scenario=layout_preset_regression finalLayout=sideBySide`。

## 8. 最终状态总结

- side 布局下，现在可以直接看到左右两个根级容器边界：左侧红框、右侧蓝框。
- side 布局下，右侧 `naturalNoteStrip` 的共享横向宽度已经从“基础内容宽度”升级成“基础内容宽度 x 2”。
- 因为 split 仍然是 `fitContent`，蓝色容器会跟着 `notestrip` 一起变宽，红色容器会对应缩窄。
- 这一轮仍然保持当前架构约束：
- 宽度语义放在 shared `ExerciseNaturalNoteStripRailContract`
- 双端 `NaturalNoteStripView` 只负责消费 shared contract
- renderer 不负责决定 rail 宽度，只负责把容器边界可视化出来

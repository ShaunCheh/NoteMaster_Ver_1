# 20260402_105854_phase3_refactor_renderer_main_axis_sizing

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260402_105854`
- 记录范围：实施 `右侧音名条布局` 计划的阶段 `3`，只重构双平台 renderer 的主轴尺寸分配引擎，不进入阶段 `4` 的 `NaturalNoteStripView` 竖排布局实现
- 修改目标：
  - 让 `renderSplit(...)` 在 `horizontal` / `vertical` 两个方向统一按 `mainAxisSizing` 解释 child
  - 让 `fitContent` / `fixed(Double)` child 不再参与比例约束，只占用自身需要的主轴空间
  - 保留 horizontal split 的等高约束，让左 `fretboard` 与右 rail 继续同高
  - 为 shared contract 已经提供的 `.fixed(Double)` 语义补齐 renderer 承接
- 修改统计：`2 files changed, 110 insertions(+), 54 deletions(-)`
- 涉及文件：
  - `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`

## 1. `iOSExerciseSceneRenderer.swift`：统一 `renderSplit(...)` 的主轴分配语义

- 修改前：`renderSplit(...)` 只有在 `axis == .vertical` 时，才会给非 `weighted` child 增加 hugging / compression 保护；而 `horizontal` 路径会把所有 child 都塞进 `proportionalIndices`，因此右侧 `fitContent` rail 仍会被拉进 width ratio。与此同时，renderer 也还没有承接 `.fixed(Double)` 的主轴常量约束。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: renderSplit(axis:children:in:)
// 功能说明: 修改前 vertical 才会特殊照顾非 weighted child；horizontal 仍默认所有 child 都参与比例分配，无法正确承接 fitContent rail / fixed 宽度。
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

    // ... 省略未改动的 cross-axis 约束、首 child 贴边约束 ...

    let proportionalIndices: [Int]
    switch axis {
    case .vertical:
        let weightedIndices = children.indices.filter {
            children[$0].mainAxisSizing.isWeighted
        }
        proportionalIndices = weightedIndices.isEmpty
            ? Array(children.indices)
            : weightedIndices
    case .horizontal:
        proportionalIndices = Array(children.indices)
    }

    guard let referenceIndex = proportionalIndices.first else {
        return
    }

    for index in 1..<childHostViews.count {
        let previousHostView = childHostViews[index - 1]
        let childHostView = childHostViews[index]

        // ... 省略未改动的相邻 child 间距约束 ...

        guard proportionalIndices.contains(index), index != referenceIndex else {
            continue
        }

        let referenceWeight = max(
            children[referenceIndex].mainAxisSizing.weightedValue ?? 1,
            0.0001
        )
        let childWeight = max(
            children[index].mainAxisSizing.weightedValue ?? 1,
            0.0001
        )
        switch axis {
        case .vertical:
            activeSceneConstraints.append(
                childHostViews[referenceIndex].heightAnchor.constraint(
                    equalTo: childHostView.heightAnchor,
                    multiplier: referenceWeight / childWeight
                )
            )
        case .horizontal:
            activeSceneConstraints.append(
                childHostViews[referenceIndex].widthAnchor.constraint(
                    equalTo: childHostView.widthAnchor,
                    multiplier: referenceWeight / childWeight
                )
            )
        }
    }

    // ... 省略未改动的末 child 贴边约束 ...
}
```

- 修改后：`renderSplit(...)` 先统一调用 `configureMainAxisSizing(...)`，让每个 child 都按当前 axis 解释 `mainAxisSizing`；随后只筛选 `weighted` child 进入比例约束。这样 `fitContent` rail 不再进入 width ratio，`fixed(Double)` 也会在当前主轴落成常量约束，而 horizontal split 原有的 `top/bottom == hostView` 等高机制保持不变。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: renderSplit(axis:children:in:), configureMainAxisSizing(_:for:axis:)
// 功能说明: 修改后 renderer 在 iOS 端统一按 mainAxisSizing 解释 horizontal / vertical split；只有 weighted child 参与比例约束，fitContent / fixed 则按主轴内容尺寸或常量尺寸落约束。
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

    // ... 省略未改动的 cross-axis 约束、首 child 贴边约束 ...

    let proportionalIndices = children.indices.filter {
        children[$0].mainAxisSizing.isWeighted
    }
    let referenceIndex = proportionalIndices.first

    for index in 1..<childHostViews.count {
        let previousHostView = childHostViews[index - 1]
        let childHostView = childHostViews[index]

        // ... 省略未改动的相邻 child 间距约束 ...

        guard
            let referenceIndex,
            proportionalIndices.contains(index),
            index != referenceIndex
        else {
            continue
        }

        let referenceWeight = max(
            children[referenceIndex].mainAxisSizing.weightedValue ?? 1,
            0.0001
        )
        let childWeight = max(
            children[index].mainAxisSizing.weightedValue ?? 1,
            0.0001
        )
        switch axis {
        case .vertical:
            activeSceneConstraints.append(
                childHostViews[referenceIndex].heightAnchor.constraint(
                    equalTo: childHostView.heightAnchor,
                    multiplier: referenceWeight / childWeight
                )
            )
        case .horizontal:
            activeSceneConstraints.append(
                childHostViews[referenceIndex].widthAnchor.constraint(
                    equalTo: childHostView.widthAnchor,
                    multiplier: referenceWeight / childWeight
                )
            )
        }
    }

    // ... 省略未改动的末 child 贴边约束 ...
}

private func configureMainAxisSizing(
    _ mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing,
    for childHostView: UIView,
    axis: ExerciseSceneAxis
) {
    switch (axis, mainAxisSizing) {
    case (_, .weighted):
        return
    case (.vertical, .fitContent):
        childHostView.setContentHuggingPriority(.required, for: .vertical)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    case (.horizontal, .fitContent):
        childHostView.setContentHuggingPriority(.required, for: .horizontal)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
    case let (.vertical, .fixed(size)):
        childHostView.setContentHuggingPriority(.required, for: .vertical)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
        activeSceneConstraints.append(
            childHostView.heightAnchor.constraint(equalToConstant: size)
        )
    case let (.horizontal, .fixed(size)):
        childHostView.setContentHuggingPriority(.required, for: .horizontal)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        activeSceneConstraints.append(
            childHostView.widthAnchor.constraint(equalToConstant: size)
        )
    }
}
```

## 2. `macOSExerciseSceneRenderer.swift`：同步迁移到同一套主轴分配引擎

- 修改前：macOS 端与 iOS 端保持同样的旧逻辑，问题也一致：
  - 只有 `vertical` split 会保护非 `weighted` child 的内容尺寸
  - `horizontal` split 仍把所有 child 一起做比例分宽
  - 没有为 `.fixed(Double)` 提供主轴常量约束

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: renderSplit(axis:children:in:)
// 功能说明: 修改前 macOS renderer 仍沿用 vertical 特判 + horizontal 全员比例分配；shared scene 发出的 fitContent / fixed 无法在 horizontal split 上被正确解释。
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

    // ... 省略未改动的 cross-axis 约束、首 child 贴边约束 ...

    let proportionalIndices: [Int]
    switch axis {
    case .vertical:
        let weightedIndices = children.indices.filter {
            children[$0].mainAxisSizing.isWeighted
        }
        proportionalIndices = weightedIndices.isEmpty
            ? Array(children.indices)
            : weightedIndices
    case .horizontal:
        proportionalIndices = Array(children.indices)
    }

    guard let referenceIndex = proportionalIndices.first else {
        return
    }

    for index in 1..<childHostViews.count {
        let previousHostView = childHostViews[index - 1]
        let childHostView = childHostViews[index]

        // ... 省略未改动的相邻 child 间距约束 ...

        guard proportionalIndices.contains(index), index != referenceIndex else {
            continue
        }

        let referenceWeight = max(
            children[referenceIndex].mainAxisSizing.weightedValue ?? 1,
            0.0001
        )
        let childWeight = max(
            children[index].mainAxisSizing.weightedValue ?? 1,
            0.0001
        )
        switch axis {
        case .vertical:
            activeSceneConstraints.append(
                childHostViews[referenceIndex].heightAnchor.constraint(
                    equalTo: childHostView.heightAnchor,
                    multiplier: referenceWeight / childWeight
                )
            )
        case .horizontal:
            activeSceneConstraints.append(
                childHostViews[referenceIndex].widthAnchor.constraint(
                    equalTo: childHostView.widthAnchor,
                    multiplier: referenceWeight / childWeight
                )
            )
        }
    }

    // ... 省略未改动的末 child 贴边约束 ...
}
```

- 修改后：macOS 端新增同名的 `configureMainAxisSizing(...)`，并把 `renderSplit(...)` 的比例参与者改为“仅 weighted child”。这样双平台 renderer 终于对 shared scene 的 `weighted / fitContent / fixed` 使用同一套解释规则，不再出现“shared 已经发出 rail 语义，但 horizontal renderer 仍按旧 weight 逻辑硬拉半屏”的分叉。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: renderSplit(axis:children:in:), configureMainAxisSizing(_:for:axis:)
// 功能说明: 修改后 macOS renderer 与 iOS 端对齐，统一按 mainAxisSizing 解释 split；fitContent / fixed child 不再参与比例分配，weighted child 吃剩余主轴空间。
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

    for (index, childHostView) in childHostViews.enumerated() {
        configureMainAxisSizing(
            children[index].mainAxisSizing,
            for: childHostView,
            axis: axis
        )
    }

    // ... 省略未改动的 cross-axis 约束、首 child 贴边约束 ...

    let proportionalIndices = children.indices.filter {
        children[$0].mainAxisSizing.isWeighted
    }
    let referenceIndex = proportionalIndices.first

    for index in 1..<childHostViews.count {
        let previousHostView = childHostViews[index - 1]
        let childHostView = childHostViews[index]

        // ... 省略未改动的相邻 child 间距约束 ...

        guard
            let referenceIndex,
            proportionalIndices.contains(index),
            index != referenceIndex
        else {
            continue
        }

        let referenceWeight = max(
            children[referenceIndex].mainAxisSizing.weightedValue ?? 1,
            0.0001
        )
        let childWeight = max(
            children[index].mainAxisSizing.weightedValue ?? 1,
            0.0001
        )
        switch axis {
        case .vertical:
            activeSceneConstraints.append(
                childHostViews[referenceIndex].heightAnchor.constraint(
                    equalTo: childHostView.heightAnchor,
                    multiplier: referenceWeight / childWeight
                )
            )
        case .horizontal:
            activeSceneConstraints.append(
                childHostViews[referenceIndex].widthAnchor.constraint(
                    equalTo: childHostView.widthAnchor,
                    multiplier: referenceWeight / childWeight
                )
            )
        }
    }

    // ... 省略未改动的末 child 贴边约束 ...
}

private func configureMainAxisSizing(
    _ mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing,
    for childHostView: NSView,
    axis: ExerciseSceneAxis
) {
    switch (axis, mainAxisSizing) {
    case (_, .weighted):
        return
    case (.vertical, .fitContent):
        childHostView.setContentHuggingPriority(.required, for: .vertical)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    case (.horizontal, .fitContent):
        childHostView.setContentHuggingPriority(.required, for: .horizontal)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
    case let (.vertical, .fixed(size)):
        childHostView.setContentHuggingPriority(.required, for: .vertical)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
        activeSceneConstraints.append(
            childHostView.heightAnchor.constraint(equalToConstant: size)
        )
    case let (.horizontal, .fixed(size)):
        childHostView.setContentHuggingPriority(.required, for: .horizontal)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        activeSceneConstraints.append(
            childHostView.widthAnchor.constraint(equalToConstant: size)
        )
    }
}
```

## 3. 验证结果

- `ReadLints`：`NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`、`NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift` 无新增 linter 问题
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'platform=macOS' build`：通过
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'generic/platform=iOS Simulator' build`：通过

## 4. 阶段边界

- 本次记录只覆盖阶段 `3` 的 renderer 主轴尺寸分配改造
- `NaturalNoteStripView` 还没有切到 `verticalRail` 的纵向内部排布；那部分仍属于阶段 `4`

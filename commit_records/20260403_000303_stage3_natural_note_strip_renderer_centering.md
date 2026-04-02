# 20260403_000303_stage3_natural_note_strip_renderer_centering

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_000303`
- 记录范围：只记录方案 B 的阶段 3 落地，即让双端 renderer 按 shared rail contract 把 `naturalNoteStrip` 作为内容尺寸视图嵌入，并在 side 模式列内垂直居中
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本记录中的“修改前”，指 `20260402_234946_stage2_natural_note_strip_content_sizing.md` 记录完成后的代码状态
- 本轮实际改动文件：
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`

## 1. 本轮目标

- 阶段 2 已经让双端 `NaturalNoteStripView` 自己能算出正方形按钮和总内容高度，但 renderer 仍把它按普通 surface 四边贴满 host。
- 真正把 strip 拉长的最后一层，不在 view 内部，而在 renderer 的嵌入约束。
- 阶段 3 的目标，是把 shared contract 里的 `verticalRail + contentSized + centered` 从 shared / presentation 层一路接到 renderer。

## 2. 修改一：macOS slot 支持在稳定 identity 下切换嵌入约束

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数/符号: SurfaceSlotView.install(_:)
// 修改前说明: slot 只支持 fill；如果 childView 已经在当前 slot 中，就直接返回。
// 这意味着同一个 surface 无法只切换约束策略，最终只能一直吃“铺满整列”的 top / bottom 约束。
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
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数/符号: HostedViewLayout, SurfaceSlotView.install(_:layout:), SurfaceSlotView.constraints(for:layout:)
// 修改后说明: 保留稳定 slot / view identity，同时允许同一个 childView 在 fill 和 verticallyCentered 之间切换约束。
private enum HostedViewLayout: Equatable {
    case fill
    case verticallyCentered
}

private final class SurfaceSlotView: NSView {
    let surfaceID: ExerciseSurfaceID

    private var hostedViewConstraints: [NSLayoutConstraint] = []
    private weak var hostedView: NSView?
    private var hostedViewLayout: HostedViewLayout = .fill

    func install(
        _ childView: NSView,
        layout: HostedViewLayout = .fill
    ) {
        let needsSuperviewMove = childView.superview !== self
        let needsConstraintRefresh = hostedView !== childView
            || hostedViewLayout != layout
        guard needsSuperviewMove || needsConstraintRefresh else {
            return
        }

        NSLayoutConstraint.deactivate(hostedViewConstraints)
        hostedViewConstraints = []
        if needsSuperviewMove {
            childView.removeFromSuperview()
        }
        childView.translatesAutoresizingMaskIntoConstraints = false
        if needsSuperviewMove {
            addSubview(childView)
        }

        hostedView = childView
        hostedViewLayout = layout
        hostedViewConstraints = constraints(for: childView, layout: layout)
        NSLayoutConstraint.activate(hostedViewConstraints)
    }

    private func constraints(
        for childView: NSView,
        layout: HostedViewLayout
    ) -> [NSLayoutConstraint] {
        switch layout {
        case .fill:
            return [
                childView.leadingAnchor.constraint(equalTo: leadingAnchor),
                childView.trailingAnchor.constraint(equalTo: trailingAnchor),
                childView.topAnchor.constraint(equalTo: topAnchor),
                childView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ]
        case .verticallyCentered:
            let topConstraint = childView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor)
            topConstraint.priority = .defaultHigh

            let bottomConstraint = childView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
            bottomConstraint.priority = .defaultHigh

            return [
                childView.leadingAnchor.constraint(equalTo: leadingAnchor),
                childView.trailingAnchor.constraint(equalTo: trailingAnchor),
                childView.centerYAnchor.constraint(equalTo: centerYAnchor),
                topConstraint,
                bottomConstraint
            ]
        }
    }
}
```

### 2.3 这一改动解决了什么

- macOS renderer 可以继续复用方案 1 的稳定 host / slot identity。
- slot 内部不再被永久锁死为 top / bottom 铺满。
- `naturalNoteStrip` 后续就有条件走“内容高度 + centerY”的专用嵌入路径。

## 3. 修改二：macOS scene sync 改为按 rail contract 决定 strip 的嵌入方式

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数/符号: configureSurfaceSlots(), syncSurface(_:in:state:), configurePresentationStyle(for:)
// 修改前说明: slot 初次创建时就按默认 fill 安装；后续 sync 只负责摆放 slot，
// 不会根据 natural note rail contract 重新选择 hosted view 的约束策略。
private func configureSurfaceSlots() {
    for surfaceID in ExerciseSurfaceID.allCases {
        let slotView = SurfaceSlotView(surfaceID: surfaceID)
        rootHostView.addSubview(slotView)
        slotView.isHidden = true
        if let surfaceView = view(for: surfaceID) {
            slotView.install(surfaceView)
        }
        surfaceSlotViews[surfaceID] = slotView
    }
}

private func syncSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: SceneHostView,
    state: inout SceneSyncState
) {
    configurePresentationStyle(for: surface)
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

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数/符号: syncSurface(_:in:state:), hostedViewLayout(for:), configurePresentationStyle(for:)
// 修改后说明: scene sync 每次都会按当前 presentation state 决定 strip 是否应走 verticallyCentered。
// 只有 naturalNoteStrip + verticalRail + contentSized + centered 才会切到专用路径，其余 surface 仍保持 fill。
private func syncSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: SceneHostView,
    state: inout SceneSyncState
) {
    configurePresentationStyle(for: surface)
    guard
        let slotView = surfaceSlotViews[surface.id],
        let surfaceView = view(for: surface.id)
    else {
        return
    }

    if !state.activeSurfaceOrder.contains(surface.id) {
        state.activeSurfaceOrder.append(surface.id)
    }
    slotView.install(surfaceView, layout: hostedViewLayout(for: surface))
    slotView.isHidden = false
    placeSurfaceSlot(
        slotView,
        in: hostView,
        contentInsets: contentInsets(for: surface)
    )
}

private func hostedViewLayout(
    for surface: ExerciseSurfaceNode
) -> HostedViewLayout {
    guard
        surface.id == .naturalNoteStrip,
        surface.presentationStyle == .verticalRail,
        let railContract = currentPresentationState?.naturalNoteStripRailContract,
        railContract.appliesToSurface == .naturalNoteStrip,
        railContract.mainAxisPolicy == .contentSized,
        railContract.verticalAlignment == .centered
    else {
        return .fill
    }

    return .verticallyCentered
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
    naturalNoteStripView.applyRailContract(
        currentPresentationState?.naturalNoteStripRailContract
    )
}
```

### 3.3 这一改动解决了什么

- `NaturalNoteStripView` 内部的内容高度和 renderer 外部的嵌入方式，开始使用同一份 contract。
- side 模式下，右侧 rail 不再出现“自己是内容高度，但被父层继续拉满”的错位。
- `mainAxisPolicy == .contentSized` 的限制被显式加到判断里，避免把“垂直居中嵌入”误用到别的 vertical rail 场景。

## 4. 修改三：iOS renderer 同步接入 shared rail contract 和垂直居中嵌入

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数/符号: renderSurface(_:in:), configurePresentationStyle(for:), embed(_:in:contentInsets:)
// 修改前说明: iOS 和 macOS 一样，renderSurface 最终总是走四边贴满。
// strip view 即使已经能返回内容高度，这一层仍会用 top / bottom 约束把它拉成整列高度。
private func renderSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: UIView
) {
    configurePresentationStyle(for: surface)
    guard let surfaceView = view(for: surface.id) else {
        return
    }
    embed(
        surfaceView,
        in: hostView,
        contentInsets: contentInsets(for: surface)
    )
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
}

private func embed(
    _ childView: UIView,
    in hostView: UIView,
    contentInsets: UIEdgeInsets = .zero
) {
    childView.removeFromSuperview()
    childView.translatesAutoresizingMaskIntoConstraints = false
    hostView.addSubview(childView)
    activeSceneConstraints.append(contentsOf: [
        childView.leadingAnchor.constraint(
            equalTo: hostView.leadingAnchor,
            constant: contentInsets.left
        ),
        childView.trailingAnchor.constraint(
            equalTo: hostView.trailingAnchor,
            constant: -contentInsets.right
        ),
        childView.topAnchor.constraint(
            equalTo: hostView.topAnchor,
            constant: contentInsets.top
        ),
        childView.bottomAnchor.constraint(
            equalTo: hostView.bottomAnchor,
            constant: -contentInsets.bottom
        )
    ])
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数/符号: EmbeddedViewLayout, renderSurface(_:in:), embeddedViewLayout(for:), configurePresentationStyle(for:), embed(_:in:contentInsets:layout:)
// 修改后说明: iOS renderer 与 macOS 对齐；只有命中 shared rail contract 的 strip 才改走 verticallyCentered。
private enum EmbeddedViewLayout {
    case fill
    case verticallyCentered
}

private func renderSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: UIView
) {
    configurePresentationStyle(for: surface)
    guard let surfaceView = view(for: surface.id) else {
        return
    }
    embed(
        surfaceView,
        in: hostView,
        contentInsets: contentInsets(for: surface),
        layout: embeddedViewLayout(for: surface)
    )
}

private func embeddedViewLayout(
    for surface: ExerciseSurfaceNode
) -> EmbeddedViewLayout {
    guard
        surface.id == .naturalNoteStrip,
        surface.presentationStyle == .verticalRail,
        let railContract = currentPresentationState?.naturalNoteStripRailContract,
        railContract.appliesToSurface == .naturalNoteStrip,
        railContract.mainAxisPolicy == .contentSized,
        railContract.verticalAlignment == .centered
    else {
        return .fill
    }

    return .verticallyCentered
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
    naturalNoteStripView.applyRailContract(
        currentPresentationState?.naturalNoteStripRailContract
    )
}

private func embed(
    _ childView: UIView,
    in hostView: UIView,
    contentInsets: UIEdgeInsets = .zero,
    layout: EmbeddedViewLayout = .fill
) {
    childView.removeFromSuperview()
    childView.translatesAutoresizingMaskIntoConstraints = false
    hostView.addSubview(childView)

    switch layout {
    case .fill:
        activeSceneConstraints.append(contentsOf: [
            childView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor, constant: contentInsets.left),
            childView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -contentInsets.right),
            childView.topAnchor.constraint(equalTo: hostView.topAnchor, constant: contentInsets.top),
            childView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor, constant: -contentInsets.bottom)
        ])
    case .verticallyCentered:
        let topConstraint = childView.topAnchor.constraint(
            greaterThanOrEqualTo: hostView.topAnchor,
            constant: contentInsets.top
        )
        topConstraint.priority = .defaultHigh

        let bottomConstraint = childView.bottomAnchor.constraint(
            lessThanOrEqualTo: hostView.bottomAnchor,
            constant: -contentInsets.bottom
        )
        bottomConstraint.priority = .defaultHigh

        activeSceneConstraints.append(contentsOf: [
            childView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor, constant: contentInsets.left),
            childView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -contentInsets.right),
            childView.centerYAnchor.constraint(equalTo: hostView.centerYAnchor),
            topConstraint,
            bottomConstraint
        ])
    }
}
```

### 4.3 这一改动解决了什么

- iOS 与 macOS 的布局语义重新对齐，不会出现一端内容尺寸、另一端仍然整列拉伸的分叉。
- `naturalNoteStrip` 的最终高度继续来自 view 自身的 intrinsic size，renderer 只负责横向占满和纵向居中。
- top / bottom 改为不等式高优先级约束后，strip 在列高不足时仍有收缩空间，不会引入新的刚性冲突。

## 5. 本轮没有改什么

- 没有再改 `ExerciseNaturalNoteStripRailContract` 的字段定义和默认值。
- 没有再改双端 `NaturalNoteStripView` 的按钮尺寸算法、12 个 `PitchClass` 槽位语义或内容高度计算公式。
- 没有在这一轮补 shared validation 或 settings / navigation 断言；这一部分仍属于后续阶段。

## 6. 最终状态总结

- 到阶段 3 为止，natural note strip 的 shared contract 已经完整贯通。
- `ExercisePresentationState` 负责产出 rail contract。
- renderer 负责读取 contract，决定当前是 `fill` 还是 `verticallyCentered` 嵌入。
- `NaturalNoteStripView` 负责根据同一份 contract 计算按钮边长和整体 intrinsic height。
- side 模式下，右侧 rail 的高度现在应该由“12 个保留槽位的内容高度”决定，而不是再被父层 top / bottom 直接拉满整列。

## 7. 验证结果

- `ReadLints` 检查相关文件：无 linter 错误
- 构建验证命令（macOS）：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- 构建验证命令（iOS Simulator）：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`
- 构建结果（macOS）：`BUILD SUCCEEDED`
- 构建结果（iOS Simulator）：`BUILD SUCCEEDED`
- 本记录只覆盖实现与构建验证；`side / stacked` 切换、启动、窗口尺寸变化的交互回归，仍应继续按后续阶段执行。

## 8. 对后续阶段的直接意义

- 阶段 4 不需要再重新设计 renderer 语义，重点已经收敛为 shared validation 和回归验证补齐。
- 如果未来 strip 再次出现“被拉长”，优先排查的层级不再是按钮尺寸算法，而是 renderer 是否又退回到了 `fill` 嵌入路径。

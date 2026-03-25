# 20260325_132837_phase4_vertical_fretboard_geometry_strategy

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260325_132837`
- 记录范围：指板竖向 Scene 重构的阶段 4
- 本阶段目标：落地真正的 `VerticalFretboardGeometryStrategy`，并让 `FretboardSceneBuilder` 在 `displayMode == .vertical` 时切到竖向 scene 与命中规则

## 本阶段完成的修改

1. 新增 `VerticalFretboardGeometryStrategy`，正式承接竖向指板的 scene 生成与命中测试。
2. 更新 `FretboardSceneBuilder.makeScene(bounds:)`，让 `vertical` 分支不再回落到 horizontal。
3. 更新 `FretboardSceneBuilder.hitTest(_:phase:scene:)`，让竖向模式命中测试走独立的竖向规则。
4. 将你之前确认的竖向语义真正写入代码：
   - 品位沿 `y` 轴从上到下递增
   - 弦沿 `x` 轴从左到右低音到高音
   - 双点 marker 沿 `x` 轴左右展开
   - `nut` 为顶部横条
   - label anchor 保持正立，不做文字旋转补丁

## 修改 1：`FretboardSceneBuilder` 的 vertical 分支不再回落到 horizontal

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardSceneBuilder.swift
// 函数/成员: FretboardSceneBuilder.makeScene(bounds:), hitTest(_:phase:scene:)
// 功能说明: 修改前虽然已经有 displayMode，但 vertical 分支仍只是显式回落到 HorizontalFretboardGeometryStrategy，竖向模式还没有真实几何与命中实现。
struct FretboardSceneBuilder: Equatable, Sendable {
    var configuration: FretboardConfiguration

    func makeScene(bounds: CGRect) -> FretboardScene {
        let normalizedBounds = bounds.standardized

        switch configuration.displayMode {
        case .horizontal:
            return HorizontalFretboardGeometryStrategy().makeScene(
                configuration: configuration,
                bounds: normalizedBounds
            )
        case .vertical:
            // 阶段 2 先完成横向 scene 真相迁移；竖向 strategy 在后续阶段单独落地。
            return HorizontalFretboardGeometryStrategy().makeScene(
                configuration: configuration,
                bounds: normalizedBounds
            )
        }
    }

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase,
        scene: FretboardScene
    ) -> FretboardHitResult {
        switch configuration.displayMode {
        case .horizontal:
            return HorizontalFretboardGeometryStrategy().hitTest(
                point,
                phase: phase,
                configuration: configuration,
                scene: scene
            )
        case .vertical:
            // 阶段 2 先完成横向 scene 真相迁移；竖向 strategy 在后续阶段单独落地。
            return HorizontalFretboardGeometryStrategy().hitTest(
                point,
                phase: phase,
                configuration: configuration,
                scene: scene
            )
        }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardSceneBuilder.swift
// 函数/成员: FretboardSceneBuilder.makeScene(bounds:), hitTest(_:phase:scene:)
// 功能说明: vertical 分支现在正式切到 VerticalFretboardGeometryStrategy，scene 与 hitTest 都会使用竖向几何真相。
struct FretboardSceneBuilder: Equatable, Sendable {
    var configuration: FretboardConfiguration

    func makeScene(bounds: CGRect) -> FretboardScene {
        let normalizedBounds = bounds.standardized

        switch configuration.displayMode {
        case .horizontal:
            return HorizontalFretboardGeometryStrategy().makeScene(
                configuration: configuration,
                bounds: normalizedBounds
            )
        case .vertical:
            return VerticalFretboardGeometryStrategy().makeScene(
                configuration: configuration,
                bounds: normalizedBounds
            )
        }
    }

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase,
        scene: FretboardScene
    ) -> FretboardHitResult {
        switch configuration.displayMode {
        case .horizontal:
            return HorizontalFretboardGeometryStrategy().hitTest(
                point,
                phase: phase,
                configuration: configuration,
                scene: scene
            )
        case .vertical:
            return VerticalFretboardGeometryStrategy().hitTest(
                point,
                phase: phase,
                configuration: configuration,
                scene: scene
            )
        }
    }
}
```

## 修改 2：新增 `VerticalFretboardGeometryStrategy`，生成真正的竖向 scene

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: 无（文件不存在）
// 功能说明: 修改前工程里没有独立的竖向几何策略类型，vertical 只存在于配置语义层，不存在实际几何实现。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: VerticalFretboardGeometryStrategy.makeScene(configuration:bounds:)
// 功能说明: 正式建立竖向 scene 生成规则；这里把 stringIndex 映射到 x 轴，把 fret 映射到 y 轴，并生成竖向模式下的 cell / 弦 / 品位 / marker / labelAnchor。
struct VerticalFretboardGeometryStrategy: FretboardGeometryStrategy {
    func makeScene(
        configuration: FretboardConfiguration,
        bounds: CGRect
    ) -> FretboardScene {
        let drawingRect = Self.makeDrawingRect(
            bounds: bounds,
            configuration: configuration
        )
        guard !drawingRect.isNull else {
            return .empty
        }

        let displayPositionCount = max(configuration.displayPositionCount, 1)
        let stringCount = max(configuration.stringCount, 1)
        let displaySlotHeight = drawingRect.height / CGFloat(displayPositionCount)
        let stringLaneWidth = drawingRect.width / CGFloat(stringCount)

        let cellFrames = configuration.fretRange.flatMap { fret in
            (0..<configuration.stringCount).map { stringIndex in
                FretboardScene.CellFrame(
                    stringIndex: stringIndex,
                    fret: fret,
                    frame: CGRect(
                        x: drawingRect.minX + (CGFloat(stringIndex) * stringLaneWidth),
                        y: drawingRect.minY + (CGFloat(fret) * displaySlotHeight),
                        width: stringLaneWidth,
                        height: displaySlotHeight
                    )
                )
            }
        }

        let stringSegments = (0..<configuration.stringCount).map { stringIndex in
            let x = drawingRect.minX + (stringLaneWidth * (CGFloat(stringIndex) + 0.5))
            return FretboardScene.StringSegment(
                stringIndex: stringIndex,
                start: CGPoint(x: x, y: drawingRect.minY),
                end: CGPoint(x: x, y: drawingRect.maxY)
            )
        }

        let fretSegments = makeFretSegments(
            configuration: configuration,
            drawingRect: drawingRect,
            displaySlotHeight: displaySlotHeight
        )
        let markerPlacements = makeMarkerPlacements(
            configuration: configuration,
            drawingRect: drawingRect,
            displaySlotHeight: displaySlotHeight
        )
        let labelAnchors = cellFrames.map {
            FretboardScene.LabelAnchor(
                stringIndex: $0.stringIndex,
                fret: $0.fret,
                center: CGPoint(x: $0.frame.midX, y: $0.frame.midY),
                cellFrame: $0.frame
            )
        }

        return FretboardScene(
            drawingRect: drawingRect,
            openStringRect: openStringRect,
            nutRect: nutRect,
            fretboardRect: fretboardRect,
            stringSegments: stringSegments,
            fretSegments: fretSegments,
            cellFrames: cellFrames,
            markerPlacements: markerPlacements,
            labelAnchors: labelAnchors
        )
    }
}
```

## 修改 3：新增竖向命中测试，改为 `x -> string`、`y -> fret`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardSceneBuilder.swift
// 函数/成员: FretboardSceneBuilder.hitTest(_:phase:scene:)
// 功能说明: 修改前 vertical 命中测试仍然沿用 horizontal 逻辑，也就是 point.x 解释为 fret、point.y 解释为 string，和目标竖向语义不一致。
case .vertical:
    return HorizontalFretboardGeometryStrategy().hitTest(
        point,
        phase: phase,
        configuration: configuration,
        scene: scene
    )
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: VerticalFretboardGeometryStrategy.hitTest(_:phase:configuration:scene:)
// 功能说明: 竖向模式下命中规则改为“x 轴找最近弦、y 轴计算品位”，从而与屏幕上的竖向 scene 保持一致。
func hitTest(
    _ point: CGPoint,
    phase: FretboardEventPhase,
    configuration: FretboardConfiguration,
    scene: FretboardScene
) -> FretboardHitResult {
    let isInsideDrawingRect = contains(
        point,
        inInclusiveBoundsOf: scene.drawingRect
    )
    let nearestString = nearestStringMatch(
        forX: point.x,
        scene: scene
    )

    guard
        isInsideDrawingRect,
        let fret = displayPosition(
            forY: point.y,
            configuration: configuration,
            drawingRect: scene.drawingRect
        ),
        let nearestString
    else {
        return FretboardHitResult(
            phase: phase,
            locationInView: point,
            cell: nil,
            isInsideDrawingRect: isInsideDrawingRect,
            distanceToNearestString: nearestString?.distance
        )
    }

    return FretboardHitResult(
        phase: phase,
        locationInView: point,
        cell: FretboardCell(
            stringIndex: nearestString.stringIndex,
            fret: fret
        ),
        isInsideDrawingRect: true,
        distanceToNearestString: nearestString.distance
    )
}
```

## 修改 4：竖向模式的板面语义被正式写死

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: 无（文件不存在）
// 功能说明: 修改前没有地方真正把“品位向下、弦向右、双点 marker 左右展开、nut 为横条”这些竖向规则落成代码。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: makeFretSegments(...), makeNutRect(...), makeMarkerPlacements(...)
// 功能说明: 这几处把竖向板面的视觉语义真正固定下来：品位横线、琴枕横条、双点 marker 沿 x 轴左右展开。
private func makeFretSegments(
    configuration: FretboardConfiguration,
    drawingRect: CGRect,
    displaySlotHeight: CGFloat
) -> [FretboardScene.FretSegment] {
    return (1...configuration.maxFret).map { fret in
        let slotRect = slotRect(
            for: fret,
            drawingRect: drawingRect,
            displaySlotHeight: displaySlotHeight
        )
        return FretboardScene.FretSegment(
            fret: fret,
            start: CGPoint(x: drawingRect.minX, y: slotRect.maxY),
            end: CGPoint(x: drawingRect.maxX, y: slotRect.maxY)
        )
    }
}

private func makeNutRect(
    configuration: FretboardConfiguration,
    drawingRect: CGRect,
    openStringRect: CGRect
) -> CGRect {
    let height = min(
        max(
            configuration.layoutMetrics.nutWidthRatio * drawingRect.height,
            configuration.layoutMetrics.fretLineWidth
        ),
        drawingRect.height
    )

    return CGRect(
        x: drawingRect.minX,
        y: openStringRect.maxY - (height / 2),
        width: drawingRect.width,
        height: height
    )
}

private func makeMarkerPlacements(
    configuration: FretboardConfiguration,
    drawingRect: CGRect,
    displaySlotHeight: CGFloat
) -> [FretboardScene.MarkerPlacement] {
    let markerDoubleDotOffset = drawingRect.width
        * configuration.layoutMetrics.doubleMarkerOffsetRatio

    // 双点 marker 改为沿 x 轴左右展开，而不是 horizontal 模式下的上下展开。
    return configuration.markerLayout.allMarkerFrets(upTo: configuration.maxFret)
        .compactMap { fret in
            let centerX = drawingRect.midX
            let centerY = slotRect(...).midY
            return FretboardScene.MarkerPlacement(
                fret: fret,
                style: .doubleDot,
                centers: [
                    CGPoint(x: centerX - markerDoubleDotOffset, y: centerY),
                    CGPoint(x: centerX + markerDoubleDotOffset, y: centerY)
                ],
                diameter: markerDiameter
            )
        }
}
```

## 修改 5：竖向 scene 的 `drawingRect` 开始采用“高度优先、居中适配”的几何出口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardSceneBuilder.swift
// 函数/成员: vertical 分支
// 功能说明: 修改前 vertical 完全回落到 HorizontalFretboardGeometryStrategy，因此仍然沿用横向的 width-first drawingRect 计算，不具备任何竖向几何语义。
case .vertical:
    return HorizontalFretboardGeometryStrategy().makeScene(
        configuration: configuration,
        bounds: normalizedBounds
    )
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: VerticalFretboardGeometryStrategy.makeDrawingRect(bounds:configuration:)
// 功能说明: 这里开始把竖向几何的 drawingRect 改为“优先用高度反推宽度，再在 bounds 内居中容纳”；这为阶段 5 的 host-height 驱动布局做准备。
private static func makeDrawingRect(
    bounds: CGRect,
    configuration: FretboardConfiguration
) -> CGRect {
    let widthToHeightMultiplier = verticalWidthToHeightMultiplier(
        configuration: configuration
    )
    let widthUsingFullHeight = bounds.height * widthToHeightMultiplier

    let totalWidth: CGFloat
    let totalHeight: CGFloat
    if widthUsingFullHeight <= bounds.width {
        totalWidth = widthUsingFullHeight
        totalHeight = bounds.height
    } else {
        totalWidth = bounds.width
        totalHeight = bounds.width / widthToHeightMultiplier
    }

    let totalRect = CGRect(
        x: bounds.midX - (totalWidth / 2),
        y: bounds.midY - (totalHeight / 2),
        width: totalWidth,
        height: totalHeight
    )

    return CGRect(
        x: totalRect.minX + horizontalInset,
        y: totalRect.minY + verticalInset,
        width: drawingWidth,
        height: drawingHeight
    )
}
```

## 本阶段刻意保持不变的部分

1. `iOSFretboardView` / `macOSFretboardView` 的 intrinsic size 与布局出口还没有改，平台层仍是旧的 width-first 策略。
2. `iOSViewController` / `macOSViewController` 还没有引入 host 容器，也还没有做到“占满高度、宽度自适应、水平居中”。
3. 按钮面板还没有接出 `displayMode` 切换入口，默认界面不会自动切到 vertical。

## 验证情况

1. 已读取 `VerticalFretboardGeometryStrategy.swift` 与 `FretboardSceneBuilder.swift` 的 IDE diagnostics，无 linter 错误。
2. 已使用 `swiftc -typecheck` 对共享层 scene / render / geometry 全链路做静态类型检查，结果通过。
3. 本阶段未额外运行 `xcodebuild`，因此没有做整工程构建级验证。

## 结果小结

- 阶段 4 完成后，`displayMode = .vertical` 已经不再只是配置语义，而是拥有了真正的竖向 scene 和命中测试实现。
- 竖向模式下的几何规则已经和你确认的产品语义对齐：品位向下、弦向右、文字正立、marker 左右展开。
- 但这一步仍然只完成了共享层几何与命中；真正把竖向指板在页面里显示成“占满高度、宽度自适应、居中”的效果，要到阶段 5 才会完整闭环。

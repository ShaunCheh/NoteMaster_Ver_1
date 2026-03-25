# 20260325_130237_phase2_fretboard_scene_strategy_horizontal_migration

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260325_130237`
- 记录范围：指板竖向 Scene 重构的阶段 2
- 本阶段目标：引入 `scene + strategy + builder` 骨架，并把现有横向几何与命中逻辑迁移到 strategy；本阶段不实现真正的 vertical 几何，不改平台布局，不改 root-layer 拆分

## 本阶段完成的修改

1. 新增 `FretboardScene`，把绘制和命中共用的几何结果提炼成独立值对象。
2. 新增 `FretboardGeometryStrategy` 和 `FretboardSceneBuilder`，建立按 `displayMode` 选择几何实现的共享接缝。
3. 新增 `HorizontalFretboardGeometryStrategy`，把当前横向指板的 `drawingRect`、cell、品丝、弦、marker、命中测试迁移出去。
4. 将 `FretboardGeometry` 改造成兼容 facade：保留旧 API，内部改为消费 `scene`。

## 修改 1：新增 `FretboardScene`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数/成员: struct FretboardGeometry
// 功能说明: 修改前几何结果、绘制输入和命中依赖的数据都直接挂在 FretboardGeometry 上，没有独立的 scene 中间层。
struct FretboardGeometry: Equatable {
    struct DisplaySlot: Equatable {
        enum Kind: Equatable {
            case openString
            case fretted(Int)
        }

        var position: Int
        var kind: Kind
        var rect: CGRect
    }

    struct StringLine: Equatable {
        var stringIndex: Int
        var y: CGFloat
    }

    struct FretLine: Equatable {
        var fret: Int
        var x: CGFloat
    }

    struct MarkerPlacement: Equatable {
        enum Style: Equatable {
            case singleDot
            case doubleDot
        }

        var fret: Int
        var style: Style
        var centers: [CGPoint]
        var diameter: CGFloat
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardScene.swift
// 函数/成员: struct FretboardScene
// 功能说明: 将渲染和命中共用的输出收口为 scene，后续 vertical、root-layer、label anchor 都可以基于这份真相继续演进。
struct FretboardScene: Equatable, Sendable {
    struct CellFrame: Equatable, Sendable {
        var stringIndex: Int
        var fret: Int
        var frame: CGRect
    }

    struct StringSegment: Equatable, Sendable {
        var stringIndex: Int
        var start: CGPoint
        var end: CGPoint
    }

    struct FretSegment: Equatable, Sendable {
        var fret: Int
        var start: CGPoint
        var end: CGPoint
    }

    struct MarkerPlacement: Equatable, Sendable {
        enum Style: Equatable, Sendable {
            case singleDot
            case doubleDot
        }

        var fret: Int
        var style: Style
        var centers: [CGPoint]
        var diameter: CGFloat
    }

    struct LabelAnchor: Equatable, Sendable {
        var stringIndex: Int
        var fret: Int
        var center: CGPoint
        var cellFrame: CGRect
    }

    var drawingRect: CGRect
    var openStringRect: CGRect
    var nutRect: CGRect
    var fretboardRect: CGRect
    var stringSegments: [StringSegment]
    var fretSegments: [FretSegment]
    var cellFrames: [CellFrame]
    var markerPlacements: [MarkerPlacement]
    var labelAnchors: [LabelAnchor]
}
```

## 修改 2：建立 `FretboardGeometryStrategy` 与 `FretboardSceneBuilder`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数/成员: init(configuration:bounds:), hitTest(_:phase:)
// 功能说明: 修改前 FretboardGeometry 自己负责“根据 bounds 造几何”和“执行命中测试”，没有基于 displayMode 的分发接缝。
init(configuration: FretboardConfiguration, bounds: CGRect) {
    self.configuration = configuration
    self.bounds = bounds.standardized
}

func hitTest(
    _ point: CGPoint,
    phase: FretboardEventPhase
) -> FretboardHitResult {
    let isInsideDrawingRect = contains(point, inInclusiveBoundsOf: drawingRect)
    let nearestString = nearestStringMatch(forY: point.y)

    guard
        isInsideDrawingRect,
        let fret = displayPosition(forX: point.x),
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

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometryStrategy.swift
// 函数/成员: protocol FretboardGeometryStrategy
// 功能说明: 用统一协议约束“生成 scene”和“执行命中测试”，后续 horizontal / vertical 都走同一个抽象入口。
protocol FretboardGeometryStrategy: Sendable {
    func makeScene(
        configuration: FretboardConfiguration,
        bounds: CGRect
    ) -> FretboardScene

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase,
        configuration: FretboardConfiguration,
        scene: FretboardScene
    ) -> FretboardHitResult
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardSceneBuilder.swift
// 函数/成员: FretboardSceneBuilder.makeScene(bounds:), hitTest(_:phase:scene:)
// 功能说明: 根据 configuration.displayMode 分发到具体 strategy；本阶段 vertical 先显式回落到 horizontal，避免提前引入半成品竖向几何。
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
}
```

## 修改 3：把横向几何与命中迁移到 `HorizontalFretboardGeometryStrategy`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数/成员: displaySlotRect(at:), markerCenters(for:), hitTest(_:phase:)
// 功能说明: 修改前横向指板的 cell、marker 和命中规则都直接写在 FretboardGeometry 内部，无法被 displayMode / strategy 复用。
func displaySlotRect(at position: Int) -> CGRect {
    guard configuration.fretRange.contains(position), !drawingRect.isNull else {
        return .null
    }

    return CGRect(
        x: drawingRect.minX + (CGFloat(position) * displaySlotWidth),
        y: drawingRect.minY,
        width: displaySlotWidth,
        height: drawingRect.height
    )
}

func markerCenters(for fret: Int) -> [CGPoint] {
    let segmentRect = fretSegmentRect(at: fret)
    guard !segmentRect.isNull else {
        return []
    }

    let centerX = segmentRect.midX
    let centerY = drawingRect.midY
    // 这里省略了单双点判断，重点是 marker 位置完全在 FretboardGeometry 内直接计算。
    return [CGPoint(x: centerX, y: centerY)]
}

func hitTest(
    _ point: CGPoint,
    phase: FretboardEventPhase
) -> FretboardHitResult {
    let isInsideDrawingRect = contains(point, inInclusiveBoundsOf: drawingRect)
    let nearestString = nearestStringMatch(forY: point.y)
    // 这里直接将 x 解释为 fret，将 y 解释为 string。
    // 后续如果出现 vertical / mirror / left-handed，就会继续把分支堆在这个类型里。
    ...
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/HorizontalFretboardGeometryStrategy.swift
// 函数/成员: makeScene(configuration:bounds:), hitTest(_:phase:configuration:scene:)
// 功能说明: 将现有横向模式的绘制输入和命中逻辑整体迁入 strategy；scene 成为新的几何真相，facade 只做兼容代理。
struct HorizontalFretboardGeometryStrategy: FretboardGeometryStrategy {
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
        let displaySlotWidth = drawingRect.width / CGFloat(displayPositionCount)
        let stringLaneHeight = drawingRect.height / CGFloat(stringCount)

        // 这里把原先散落在 FretboardGeometry 里的 cell 计算收口成 scene.cellFrames。
        let cellFrames = configuration.fretRange.flatMap { fret in
            (0..<configuration.stringCount).map { stringIndex in
                FretboardScene.CellFrame(
                    stringIndex: stringIndex,
                    fret: fret,
                    frame: CGRect(
                        x: drawingRect.minX + (CGFloat(fret) * displaySlotWidth),
                        y: drawingRect.minY + (CGFloat(stringIndex) * stringLaneHeight),
                        width: displaySlotWidth,
                        height: stringLaneHeight
                    )
                )
            }
        }

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

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase,
        configuration: FretboardConfiguration,
        scene: FretboardScene
    ) -> FretboardHitResult {
        let isInsideDrawingRect = contains(point, inInclusiveBoundsOf: scene.drawingRect)
        let nearestString = nearestStringMatch(forY: point.y, scene: scene)

        guard
            isInsideDrawingRect,
            let fret = displayPosition(forX: point.x, configuration: configuration, drawingRect: scene.drawingRect),
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
            cell: FretboardCell(stringIndex: nearestString.stringIndex, fret: fret),
            isInsideDrawingRect: true,
            distanceToNearestString: nearestString.distance
        )
    }
}
```

## 修改 4：`FretboardGeometry` 退化为兼容 facade

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数/成员: init(configuration:bounds:), drawingRect, nutRect, fretboardRect
// 功能说明: 修改前 FretboardGeometry 既是外部 API，又是内部横向几何真相本体；渲染和命中都直接依赖它自己的实现细节。
struct FretboardGeometry: Equatable {
    let configuration: FretboardConfiguration
    let bounds: CGRect

    init(configuration: FretboardConfiguration, bounds: CGRect) {
        self.configuration = configuration
        self.bounds = bounds.standardized
    }

    var drawingRect: CGRect {
        Self.makeDrawingRect(
            bounds: bounds,
            configuration: configuration
        )
    }

    var nutRect: CGRect {
        // 这里直接根据 drawingRect 和 nutWidthRatio 计算琴枕矩形。
        ...
    }

    var fretboardRect: CGRect {
        // 这里直接根据 nutRect 和 drawingRect 计算指板主体矩形。
        ...
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数/成员: init(configuration:bounds:), drawingRect, displaySlotRect(at:), hitTest(_:phase:)
// 功能说明: 保留旧 API 供 FretboardLayer / NoteNameContentProvider / 平台视图继续使用，但内部已不再自持横向几何真相，而是代理到 scene。
struct FretboardGeometry: Equatable {
    let configuration: FretboardConfiguration
    let bounds: CGRect
    let scene: FretboardScene

    init(configuration: FretboardConfiguration, bounds: CGRect) {
        let normalizedBounds = bounds.standardized
        self.configuration = configuration
        self.bounds = normalizedBounds
        self.scene = FretboardSceneBuilder(
            configuration: configuration
        ).makeScene(bounds: normalizedBounds)
    }

    var drawingRect: CGRect {
        scene.drawingRect
    }

    func displaySlotRect(at position: Int) -> CGRect {
        guard configuration.fretRange.contains(position) else {
            return .null
        }

        return scene.fretSpanRect(at: position) ?? .null
    }

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase
    ) -> FretboardHitResult {
        FretboardSceneBuilder(configuration: configuration).hitTest(
            point,
            phase: phase,
            scene: scene
        )
    }
}
```

## 本阶段刻意保持不变的部分

1. `FretboardLayer` 还没有拆成 `root-layer / board-layer / labels-layer`，仍然通过旧的 `FretboardGeometry` API 取数据。
2. `NoteNameContentProvider` 还没有改为直接消费 `scene.labelAnchors`，这一步留到后续阶段处理。
3. `vertical` 还没有真正实现；当前 `FretboardSceneBuilder` 中的 `case .vertical` 只是显式回落到 `HorizontalFretboardGeometryStrategy`。

## 验证情况

1. 已读取并确认本阶段新增 / 修改文件的 IDE diagnostics，无 linter 错误。
2. 已通过 `swiftc -typecheck` 对共享层相关文件做静态类型检查，结果通过。
3. 尝试运行 `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO build` 时失败，原因不是本次代码错误，而是当前机器的 active developer directory 指向 `CommandLineTools`，无法直接使用 `xcodebuild`。

## 结果小结

- 阶段 2 完成后，横向模式的几何与命中真相已经从“直接堆在 `FretboardGeometry` 里”迁移为“`HorizontalFretboardGeometryStrategy` 生成 `FretboardScene`”。
- 对外兼容层目前仍是 `FretboardGeometry`，因此渲染层和平台层没有被本阶段强制一起改动。
- 这为后续阶段继续做 `root-layer` 拆分、`NoteNameContentProvider` 的 anchor 化、以及真正的 `VerticalFretboardGeometryStrategy` 落地提供了稳定接缝。

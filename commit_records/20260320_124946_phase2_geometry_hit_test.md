20260320_124946_phase2_geometry_hit_test

# Raw 事件阶段 2 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 几何层只有正向布局能力，还没有点位反查 API

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：yPositionForString(_:), markerCenters(for:)
// 功能说明：修改前几何层可以根据 stringIndex 和 fret 生成绘制坐标，但还不能把一个 CGPoint 反查成“第几弦、第几品”的命中结果。
func yPositionForString(_ stringIndex: Int) -> CGFloat? {
    guard stringIndex >= 0, stringIndex < stringYPositions.count else {
        return nil
    }

    return stringYPositions[stringIndex]
}

func markerCenters(for fret: Int) -> [CGPoint] {
    let segmentRect = fretSegmentRect(at: fret)
    guard !segmentRect.isNull else {
        return []
    }

    let centerX = segmentRect.midX
    let singleDotFrets = Set(configuration.markerLayout.normalizedSingleDotFrets(upTo: configuration.maxFret))
    let doubleDotFrets = Set(configuration.markerLayout.normalizedDoubleDotFrets(upTo: configuration.maxFret))
    // ... 后续继续处理 marker 中心 ...
}
```

### 共享交互模型已经存在，但还没有几何层消费它

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift
// 函数名：FretboardEventPhase, FretboardCell, FretboardHitResult
// 功能说明：阶段 1 虽然已经定义了 raw 事件的共享语义模型，但修改前 FretboardGeometry 还没有返回 FretboardHitResult 的命中方法。
enum FretboardEventPhase: Equatable, Sendable {
    case began
    case moved
    case ended
    case cancelled
}

struct FretboardCell: Equatable, Hashable, Sendable {
    var stringIndex: Int
    var fret: Int
}

struct FretboardHitResult: Equatable, Sendable {
    var phase: FretboardEventPhase
    var locationInView: CGPoint
    var cell: FretboardCell?
    var isInsideDrawingRect: Bool
    var distanceToNearestString: CGFloat?
}
```

## 修改后

### 几何层新增品位反查、最近弦反查和统一 hitTest

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：displayPosition(forX:), nearestStringIndex(forY:), hitTest(_:phase:)
// 功能说明：修改后几何层补齐 x 方向的品位反查、y 方向的最近弦反查，以及最终输出 FretboardHitResult 的统一命中入口。
func displayPosition(forX x: CGFloat) -> Int? {
    guard
        !drawingRect.isNull,
        displaySlotWidth > 0,
        isValue(x, withinInclusiveRangeOf: drawingRect.minX, and: drawingRect.maxX)
    else {
        return nil
    }

    let relativeX = min(max(x - drawingRect.minX, 0), drawingRect.width)
    let rawPosition = Int(relativeX / displaySlotWidth)
    return min(rawPosition, configuration.maxFret)
}

func nearestStringIndex(forY y: CGFloat) -> Int? {
    nearestStringMatch(forY: y)?.stringIndex
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

### 几何层内部新增最近弦距离和边界判定辅助能力

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：nearestStringMatch(forY:), contains(_:inInclusiveBoundsOf:), isValue(_:withinInclusiveRangeOf:and:)
// 功能说明：修改后几何层把“最近弦匹配”和“drawingRect 边界包含判断”都内聚到私有辅助方法中，避免平台层各自重复实现命中细节。
private func nearestStringMatch(
    forY y: CGFloat
) -> (stringIndex: Int, distance: CGFloat)? {
    guard !stringYPositions.isEmpty else {
        return nil
    }

    return stringYPositions.enumerated()
        .map { index, stringY in
            (
                stringIndex: index,
                distance: abs(stringY - y)
            )
        }
        .min { lhs, rhs in
            if lhs.distance == rhs.distance {
                return lhs.stringIndex < rhs.stringIndex
            }
            return lhs.distance < rhs.distance
        }
}

private func contains(
    _ point: CGPoint,
    inInclusiveBoundsOf rect: CGRect
) -> Bool {
    guard !rect.isNull else {
        return false
    }

    return isValue(point.x, withinInclusiveRangeOf: rect.minX, and: rect.maxX)
        && isValue(point.y, withinInclusiveRangeOf: rect.minY, and: rect.maxY)
}

private func isValue(
    _ value: CGFloat,
    withinInclusiveRangeOf minValue: CGFloat,
    and maxValue: CGFloat
) -> Bool {
    value >= minValue && value <= maxValue
}
```

### 共享几何层的职责边界发生了扩展

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：displaySlotRect(at:), stringYPositions, hitTest(_:phase:)
// 功能说明：阶段 2 后，FretboardGeometry 不再只是“给绘制层提供坐标”，也开始承担“基于同一套坐标规则做交互反查”的职责，但仍然保持为纯共享几何，不直接依赖 UIKit 或 AppKit。
var stringYPositions: [CGFloat] {
    // ... 根据 stringBandRect 计算各弦 Y 坐标 ...
}

func displaySlotRect(at position: Int) -> CGRect {
    // ... 根据 drawingRect 和 displaySlotWidth 计算每个品位区域 ...
}

func hitTest(_ point: CGPoint, phase: FretboardEventPhase) -> FretboardHitResult {
    // ... 统一输出命中结果 ...
}
```

## 结果说明

- 阶段 2 的核心结果是把共享几何层从“正向布局坐标”扩展成“可反向命中”的坐标真相源。
- 这样后续 iOS 的 `touchesBegan / touchesMoved` 和 macOS 的 `mouseDown / mouseDragged` 都可以直接复用同一套命中规则，而不需要在平台层各写一份 `fret/string` 计算逻辑。
- 当前命中规则已经统一包含三件事：`drawingRect` 内外判断、`x` 方向品位反查、`y` 方向最近弦匹配。
- 已对共享几何相关文件执行 `xcrun swiftc -typecheck`，并用轻量脚本验证了空弦区、普通品格区、指板外点位三类场景。

20260320_175011_phase3_marker_and_badge_alignment

# 固定弦高阶段 3 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 几何层还没有把弦列占用区域抽成独立真相

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringYPositions, stringSpacing, markerDiameter
// 功能说明：修改前几何层虽然已经按固定 lane 排弦，但 marker 仍然通过首尾弦中心距推导垂直参考，缺少“整列弦占用区域”的显式模型。
var stringYPositions: [CGFloat] {
    guard !drawingRect.isNull else {
        return []
    }

    let stringBandRect = makeStringBandRect()
    guard
        !stringBandRect.isNull,
        configuration.stringCount > 0
    else {
        return []
    }

    let laneHeight = resolvedStringLaneHeight(in: stringBandRect)
    let occupiedHeight = laneHeight * CGFloat(configuration.stringCount)
    let firstLaneMinY = stringBandRect.midY - (occupiedHeight / 2)

    return (0..<configuration.stringCount).map { stringIndex in
        firstLaneMinY + (laneHeight * (CGFloat(stringIndex) + 0.5))
    }
}

var stringSpacing: CGFloat {
    guard configuration.stringCount > 1 else {
        return 0
    }

    let stringBandRect = makeStringBandRect()
    guard !stringBandRect.isNull else {
        return 0
    }

    return resolvedStringLaneHeight(in: stringBandRect)
}

var markerDiameter: CGFloat {
    guard !drawingRect.isNull else {
        return 0
    }

    let verticalReference: CGFloat
    if let firstStringY = stringYPositions.first,
       let lastStringY = stringYPositions.last {
        verticalReference = max(lastStringY - firstStringY, 0)
    } else {
        verticalReference = drawingRect.height
    }

    return min(displaySlotWidth, verticalReference) * configuration.layoutMetrics.markerDiameterRatio
}
```

### 品记中心和双圆点偏移仍直接绑在 `drawingRect.midY`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：markerCenters(for:), markerDoubleDotOffset
// 功能说明：修改前品记垂直中心直接使用 drawingRect 的中线，双圆点偏移也继续依赖首尾弦中心距，因此弦列视觉中心和品记视觉中心仍可能分离。
func markerCenters(for fret: Int) -> [CGPoint] {
    let segmentRect = fretSegmentRect(at: fret)
    guard !segmentRect.isNull else {
        return []
    }

    let centerX = segmentRect.midX
    let singleDotFrets = Set(configuration.markerLayout.normalizedSingleDotFrets(upTo: configuration.maxFret))
    let doubleDotFrets = Set(configuration.markerLayout.normalizedDoubleDotFrets(upTo: configuration.maxFret))

    if doubleDotFrets.contains(fret) {
        let offset = markerDoubleDotOffset
        return [
            CGPoint(x: centerX, y: drawingRect.midY - offset),
            CGPoint(x: centerX, y: drawingRect.midY + offset)
        ]
    }

    if singleDotFrets.contains(fret) {
        return [CGPoint(x: centerX, y: drawingRect.midY)]
    }

    return []
}

private var markerDoubleDotOffset: CGFloat {
    guard !drawingRect.isNull else {
        return 0
    }

    let verticalReference: CGFloat
    if let firstStringY = stringYPositions.first,
       let lastStringY = stringYPositions.last {
        verticalReference = max(lastStringY - firstStringY, 0)
    } else {
        verticalReference = drawingRect.height
    }

    return verticalReference * configuration.layoutMetrics.doubleMarkerOffsetRatio
}
```

### 音名 badge 仍通过 `stringSpacing` 间接推断高度

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数名：resolvedBadgeDiameter(slotRect:geometry:)
// 功能说明：修改前 badge 直径仍通过 stringSpacing 间接拿到高度语义，虽然结果大体正确，但表达上仍然是“借道弦距猜 lane 高度”。
private func resolvedBadgeDiameter(
    slotRect: CGRect,
    geometry: FretboardGeometry
) -> CGFloat {
    let referenceHeight = geometry.stringSpacing > 0
        ? geometry.stringSpacing
        : slotRect.height * 0.24
    let heightDrivenDiameter = referenceHeight * layoutMetrics.badgeDiameterRatio
    let widthDrivenDiameter = slotRect.width * layoutMetrics.maxBadgeWidthRatio

    return max(min(heightDrivenDiameter, widthDrivenDiameter), 0)
}
```

## 修改后

### 几何层新增弦列占用区域，并让 marker 吃同一套垂直真相

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringLaneHeight, stringColumnRect, stringYPositions, stringSpacing, markerDiameter
// 功能说明：修改后几何层显式暴露 lane 高度和整列弦占用区域，stringYPositions、stringSpacing、markerDiameter 全部围绕同一套弦列几何语义计算。
var stringLaneHeight: CGFloat {
    let stringBandRect = makeStringBandRect()
    guard !stringBandRect.isNull else {
        return 0
    }

    return resolvedStringLaneHeight(in: stringBandRect)
}

var stringColumnRect: CGRect {
    let stringBandRect = makeStringBandRect()
    let laneHeight = resolvedStringLaneHeight(in: stringBandRect)
    guard
        !stringBandRect.isNull,
        configuration.stringCount > 0,
        laneHeight > 0
    else {
        return .null
    }

    let occupiedHeight = laneHeight * CGFloat(configuration.stringCount)
    return CGRect(
        x: stringBandRect.minX,
        y: stringBandRect.midY - (occupiedHeight / 2),
        width: stringBandRect.width,
        height: occupiedHeight
    )
}

var stringYPositions: [CGFloat] {
    let columnRect = stringColumnRect
    let laneHeight = stringLaneHeight
    guard
        !columnRect.isNull,
        laneHeight > 0
    else {
        return []
    }

    return (0..<configuration.stringCount).map { stringIndex in
        columnRect.minY + (laneHeight * (CGFloat(stringIndex) + 0.5))
    }
}

var stringSpacing: CGFloat {
    guard configuration.stringCount > 1 else {
        return 0
    }

    return stringLaneHeight
}

var markerDiameter: CGFloat {
    guard !drawingRect.isNull else {
        return 0
    }

    let columnRect = stringColumnRect
    let verticalReference = !columnRect.isNull
        ? columnRect.height
        : drawingRect.height

    return min(displaySlotWidth, verticalReference) * configuration.layoutMetrics.markerDiameterRatio
}
```

### 品记中心改为弦列几何中心，双圆点偏移也统一基于弦列占用高度

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：markerCenters(for:), markerDoubleDotOffset
// 功能说明：修改后品记垂直中心优先使用 stringColumnRect.midY，双圆点偏移也统一基于整列弦的实际占用高度计算，避免 drawingRect 中心和弦列中心脱节。
func markerCenters(for fret: Int) -> [CGPoint] {
    let segmentRect = fretSegmentRect(at: fret)
    guard !segmentRect.isNull else {
        return []
    }

    let centerX = segmentRect.midX
    let columnRect = stringColumnRect
    let centerY = !columnRect.isNull
        ? columnRect.midY
        : drawingRect.midY
    let singleDotFrets = Set(configuration.markerLayout.normalizedSingleDotFrets(upTo: configuration.maxFret))
    let doubleDotFrets = Set(configuration.markerLayout.normalizedDoubleDotFrets(upTo: configuration.maxFret))

    if doubleDotFrets.contains(fret) {
        let offset = markerDoubleDotOffset
        return [
            CGPoint(x: centerX, y: centerY - offset),
            CGPoint(x: centerX, y: centerY + offset)
        ]
    }

    if singleDotFrets.contains(fret) {
        return [CGPoint(x: centerX, y: centerY)]
    }

    return []
}

private var markerDoubleDotOffset: CGFloat {
    guard !drawingRect.isNull else {
        return 0
    }

    let columnRect = stringColumnRect
    let verticalReference = !columnRect.isNull
        ? columnRect.height
        : drawingRect.height

    return verticalReference * configuration.layoutMetrics.doubleMarkerOffsetRatio
}
```

### 音名 badge 直接消费真实的 lane 高度

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数名：resolvedBadgeDiameter(slotRect:geometry:)
// 功能说明：修改后 badge 直径直接使用 geometry.stringLaneHeight 作为垂直参考，不再通过 stringSpacing 间接转义，语义与固定弦高模型保持一致。
private func resolvedBadgeDiameter(
    slotRect: CGRect,
    geometry: FretboardGeometry
) -> CGFloat {
    let referenceHeight = geometry.stringLaneHeight > 0
        ? geometry.stringLaneHeight
        : slotRect.height * 0.24
    let heightDrivenDiameter = referenceHeight * layoutMetrics.badgeDiameterRatio
    let widthDrivenDiameter = slotRect.width * layoutMetrics.maxBadgeWidthRatio

    return max(min(heightDrivenDiameter, widthDrivenDiameter), 0)
}
```

## 结果说明

- 阶段 3 的核心结果，是把 `marker` 和 `badge` 的垂直参考统一收口到“固定 lane 高度 + 弦列占用区域”这一套共享几何真相。
- `FretboardGeometry` 现在显式提供 `stringLaneHeight` 和 `stringColumnRect`，后续需要基于弦列占用区域做渲染或命中扩展时，不必再重复拼公式。
- `NoteNameContentProvider` 不再借 `stringSpacing` 猜测高度，badge 尺寸直接跟随固定弦高语义。
- 已执行 `ReadLints` 检查且无报错；`xcrun swiftc -typecheck` 通过。
- 额外做了数值校验：`4/5/6` 弦下 `laneHeight` 都保持 `17.00`，`badge` 直径都保持 `13.26`，说明阶段 3 的渲染依赖已经完成收敛。

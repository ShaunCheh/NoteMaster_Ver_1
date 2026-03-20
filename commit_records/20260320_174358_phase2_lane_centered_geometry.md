20260320_174358_phase2_lane_centered_geometry

# 固定弦高阶段 2 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 几何层仍然按 band 上下边界均分弦位

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringYPositions, stringSpacing
// 功能说明：修改前几何层把弦位直接在 stringBandRect 的上下边界之间均分，stringSpacing 只是从前两根弦的位置反推结果，语义仍然不是固定 lane 高度。
var stringYPositions: [CGFloat] {
    guard !drawingRect.isNull else {
        return []
    }

    let stringBandRect = makeStringBandRect()
    guard !stringBandRect.isNull else {
        return []
    }

    return Self.makeDistributedPositions(
        count: configuration.stringCount,
        minValue: stringBandRect.minY,
        maxValue: stringBandRect.maxY
    )
}

var stringSpacing: CGFloat {
    guard stringYPositions.count > 1 else {
        return 0
    }

    return stringYPositions[1] - stringYPositions[0]
}
```

### 几何层还保留旧的均分辅助函数

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：nearestStringMatch(forY:), makeDistributedPositions(count:minValue:maxValue:)
// 功能说明：修改前文件内部没有 lane 高度解析逻辑，仍然依赖 makeDistributedPositions 生成弦位序列。
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

private static func makeDistributedPositions(
    count: Int,
    minValue: CGFloat,
    maxValue: CGFloat
) -> [CGFloat] {
    guard count > 0 else {
        return []
    }

    guard count > 1 else {
        return [(minValue + maxValue) / 2]
    }

    let step = (maxValue - minValue) / CGFloat(count - 1)
    return (0..<count).map { index in
        minValue + (CGFloat(index) * step)
    }
}
```

## 修改后

### 几何层改为按固定 lane 中心计算弦位

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringYPositions, stringSpacing
// 功能说明：修改后几何层先解析当前可用 laneHeight，再以 stringBandRect 中心为基准计算每根弦所在 lane 的中心点；stringSpacing 直接表达 lane 高度语义。
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
```

### 新增 lane 高度解析，并移除旧的均分工具

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：nearestStringMatch(forY:), resolvedStringLaneHeight(in:)
// 功能说明：修改后新增 resolvedStringLaneHeight 统一解析当前可用 lane 高度；当某一帧可用高度不足时，会临时压缩 lane 并保持整体居中，旧的 makeDistributedPositions 已删除。
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

private func resolvedStringLaneHeight(
    in stringBandRect: CGRect
) -> CGFloat {
    guard
        !stringBandRect.isNull,
        configuration.stringCount > 0
    else {
        return 0
    }

    let preferredLaneHeight = max(configuration.layoutMetrics.stringLaneHeight, 1)
    let availableLaneHeight = stringBandRect.height / CGFloat(configuration.stringCount)
    return min(preferredLaneHeight, max(availableLaneHeight, 0))
}
```

## 结果说明

- 阶段 2 的核心结果，是把 `FretboardGeometry` 的弦位排布真正确认成“固定 lane 居中”模型，而不是“在 band 内均分”。
- `stringSpacing` 现在和 `stringLaneHeight` 的语义一致，后续 `marker`、`badge`、`raw hitTest` 都可以基于同一套垂直真相继续收敛。
- 这次改动只动了共享几何层，没有改平台包装视图、控制器和内容提供层。
- 已执行 `ReadLints` 检查且无报错；`xcrun swiftc -typecheck` 通过。
- 额外做了 4/5/6 弦数值校验，结果分别为：`6弦 spacing=17.0`、`5弦 spacing=17.0`、`4弦 spacing=17.0`，说明固定弦高已经在几何层落地。

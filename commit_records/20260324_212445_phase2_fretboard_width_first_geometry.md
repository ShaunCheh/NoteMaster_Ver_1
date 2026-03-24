20260324_212445_phase2_fretboard_width_first_geometry

# Phase 2 Fretboard Width-First Geometry 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`

## 修改前

### 几何层仍以“当前 bounds 高度 + 固定 lane 高度压缩”作为垂直真相

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：drawingRect / displayPositionCount / stringLaneHeight / stringColumnRect
// 功能说明：修改前几何层仍直接用 `bounds.insetBy(dx:dy:)` 生成 drawingRect，
// 垂直方向继续依赖 `resolvedStringLaneHeight(in:)` 从可用高度和固定弦高里取最小值；
// `stringColumnRect` 也是在 drawingRect 内重新居中计算 occupiedHeight，尚未切到宽度优先链路。
var drawingRect: CGRect {
    Self.makeDrawingRect(bounds: bounds, metrics: configuration.layoutMetrics)
}

var displayPositionCount: Int {
    configuration.maxFret + 1
}

var stringLaneHeight: CGFloat {
    guard !drawingRect.isNull else {
        return 0
    }

    return resolvedStringLaneHeight(in: drawingRect.height)
}

var stringColumnRect: CGRect {
    let laneHeight = stringLaneHeight
    guard
        !drawingRect.isNull,
        configuration.stringCount > 0,
        laneHeight > 0
    else {
        return .null
    }

    let occupiedHeight = laneHeight * CGFloat(configuration.stringCount)
    return CGRect(
        x: drawingRect.minX,
        y: drawingRect.midY - (occupiedHeight / 2),
        width: drawingRect.width,
        height: occupiedHeight
    )
}
```

### 文件内部还保留旧的 `resolvedStringLaneHeight` 压缩辅助函数

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：resolvedStringLaneHeight(in:)
// 功能说明：修改前几何层会先读取固定 `stringLaneHeight`，
// 再与当前可用高度按弦数平均后的结果取 `min`，本质仍是“固定弦高优先，空间不足时临时压缩”。
private func resolvedStringLaneHeight(
    in availableHeight: CGFloat
) -> CGFloat {
    guard
        availableHeight > 0,
        configuration.stringCount > 0
    else {
        return 0
    }

    let preferredLaneHeight = max(configuration.layoutMetrics.stringLaneHeight, 1)
    let availableLaneHeight = availableHeight / CGFloat(configuration.stringCount)
    return min(preferredLaneHeight, max(availableLaneHeight, 0))
}
```

## 修改后

### 几何层改为优先消费配置层的宽度优先尺寸语义

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：drawingRect / displayPositionCount
// 功能说明：修改后几何层不再直接吃 `layoutMetrics` 旧签名，而是把完整 `configuration` 传给 `makeDrawingRect`；
// 列数语义也统一收口到 `configuration.displayPositionCount`，避免后续平台与共享层各自重复解释 `maxFret + 1`。
var drawingRect: CGRect {
    Self.makeDrawingRect(
        bounds: bounds,
        configuration: configuration
    )
}

var displayPositionCount: Int {
    configuration.displayPositionCount
}
```

### 弦高和弦列区域改为直接由宽度推导出的 drawingRect 决定

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringLaneHeight / stringColumnRect / stringYPositions / stringSpacing
// 功能说明：修改后几何层不再从固定弦高链路读取 laneHeight，
// 而是直接把 `drawingRect.height / stringCount` 作为当前帧的 cell/lane 高度；
// `stringColumnRect` 直接收口为 `drawingRect`，弦位中心、间距和后续 hitTest / marker / badge 都统一消费这套几何结果。
var stringLaneHeight: CGFloat {
    guard
        !drawingRect.isNull,
        configuration.stringCount > 0
    else {
        return 0
    }

    return drawingRect.height / CGFloat(configuration.stringCount)
}

var stringColumnRect: CGRect {
    guard
        !drawingRect.isNull,
        configuration.stringCount > 0
    else {
        return .null
    }

    return drawingRect
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
```

### `makeDrawingRect` 改为按宽度推导理想高度，并在旧平台出口下做过渡裁剪

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：makeDrawingRect(bounds:configuration:)
// 功能说明：修改后 drawingRect 先按宽度和列数推导理想 drawingHeight，再在当前 bounds 内居中放置；
// 在平台层尚未完成宽度驱动高度约束前，这里会把理想高度裁剪到 `bounds.height`，保证阶段 2 不会让几何超出当前包装视图边界。
private static func makeDrawingRect(
    bounds: CGRect,
    configuration: FretboardConfiguration
) -> CGRect {
    guard bounds.width > 0, bounds.height > 0 else {
        return .null
    }

    let metrics = configuration.layoutMetrics
    let horizontalInset = min(
        max(bounds.width * metrics.horizontalInsetRatio, 0),
        bounds.width / 2
    )
    let drawingWidth = bounds.width - (horizontalInset * 2)
    guard drawingWidth > 0 else {
        return .null
    }

    // 在平台层尚未完成宽度驱动高度出口前，当前 bounds.height 可能仍来自旧链路；
    // 这里优先按宽度推导理想 drawingHeight，并在必要时裁剪到可用高度，避免几何越界。
    let idealDrawingHeight = configuration.layoutMetrics.drawingHeight(
        forAvailableWidth: bounds.width,
        displayPositionCount: configuration.displayPositionCount,
        stringCount: configuration.stringCount
    )
    let drawingHeight = min(max(idealDrawingHeight, 0), bounds.height)
    let rect = CGRect(
        x: bounds.minX + horizontalInset,
        y: bounds.midY - (drawingHeight / 2),
        width: drawingWidth,
        height: drawingHeight
    )

    return rect.isNull || rect.isEmpty ? .null : rect
}
```

## 结果说明

- 共享几何层已经从“固定 lane 高度优先”切到“宽度优先的 drawingHeight/cellHeight 真相优先”。
- `stringLaneHeight`、`stringSpacing`、`stringYPositions` 现在都直接建立在宽度推导出的 `drawingRect.height` 上，后续 marker、badge、raw hitTest 会继续沿用同一套输出。
- `displayPositionCount` 已与配置层统一，继续保持“空弦区不单独建模，仍按 `maxFret + 1` 等宽列处理”的语义。
- 为了和后续平台阶段平滑衔接，`makeDrawingRect(bounds:configuration:)` 当前保留了“理想高度裁剪到 `bounds.height`”的过渡逻辑；等平台层改为宽度驱动高度约束后，这个过渡分支可以再收紧。
- 本阶段没有修改 `NoteNameContentProvider`、`FretboardLayer` 和双平台包装视图。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`，无新增诊断。
- 已执行 Swift 源码级类型检查，结果通过。
- 已确认 `FretboardGeometry.swift` 内不再残留 `resolvedStringLaneHeight` 和直接读取 `configuration.layoutMetrics.stringLaneHeight` 的旧路径。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对项目 Swift 源码执行静态类型检查，确认阶段 1 + 阶段 2 的共享层改动没有引入编译期错误。
swiftc -typecheck NoteMaster_Ver_1/**/*.swift
```

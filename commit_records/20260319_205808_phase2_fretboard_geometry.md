20260319_205808_phase2_fretboard_geometry

# 阶段 2 修改记录

## 本次变更范围

- 新增共享几何文件 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `InstrumentType.swift`
- 未修改 `FretboardConfiguration.swift`
- 未接入 `iOSViewController.swift`、`macOSViewController.swift`

## 修改前

### 共享几何层文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：无（文件不存在）
// 功能说明：修改前项目中没有共享几何层，空弦区、品位区间、品丝位置、弦线分布和 marker 圆点中心都没有统一的计算入口。
// 该文件在修改前不存在。
```

### 几何职责现状

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard
// 函数名：无
// 功能说明：修改前共享层只有乐器枚举和基础配置，尚未承载任何与 bounds 相关的几何计算结果。
InstrumentType.swift
FretboardConfiguration.swift
```

## 修改后

### 新增共享几何文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：init(configuration:bounds:)
// 功能说明：新增共享几何层，统一把配置和视图 bounds 转成可直接供后续 CALayer 使用的几何结果。
import CoreGraphics

struct FretboardGeometry: Equatable {
    let configuration: FretboardConfiguration
    let bounds: CGRect

    init(configuration: FretboardConfiguration, bounds: CGRect) {
        self.configuration = configuration
        self.bounds = bounds.standardized
    }
}
```

### 明确 `0...maxFret` 的显示槽位

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：displaySlots, displaySlotRect(at:), fretSegmentRect(at:)
// 功能说明：把 0 位置明确建模为空弦显示区，把 1...maxFret 建模为实际按弦区间，避免后续绘制层重复判断。
struct DisplaySlot: Equatable {
    enum Kind: Equatable {
        case openString
        case fretted(Int)
    }

    var position: Int
    var kind: Kind
    var rect: CGRect
}

var displaySlots: [DisplaySlot] {
    configuration.fretRange.map { position in
        let kind: DisplaySlot.Kind = position == 0 ? .openString : .fretted(position)
        return DisplaySlot(position: position, kind: kind, rect: displaySlotRect(at: position))
    }
}

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

func fretSegmentRect(at fret: Int) -> CGRect {
    guard fret > 0 else {
        return .null
    }

    return displaySlotRect(at: fret)
}
```

### 抽出上弦枕、品丝和弦线坐标

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：nutRect, fretLineX(for:), stringYPositions, yPositionForString(_:)
// 功能说明：统一生成上弦枕位置、普通品丝 x 坐标和弦线 y 坐标，为后续绘制层提供稳定输入。
var nutRect: CGRect {
    guard !drawingRect.isNull else {
        return .null
    }

    let width = min(
        max(
            configuration.layoutMetrics.nutWidthRatio * drawingRect.width,
            configuration.layoutMetrics.fretLineWidth
        ),
        drawingRect.width
    )

    return CGRect(
        x: nutX - (width / 2),
        y: drawingRect.minY,
        width: width,
        height: drawingRect.height
    )
}

func fretLineX(for fret: Int) -> CGFloat? {
    guard !drawingRect.isNull else {
        return nil
    }

    if fret == 0 {
        return nutX
    }

    guard fret > 0, fret <= configuration.maxFret else {
        return nil
    }

    return displaySlotRect(at: fret).maxX
}

var stringYPositions: [CGFloat] {
    guard !drawingRect.isNull else {
        return []
    }

    return Self.makeDistributedPositions(
        count: configuration.stringCount,
        minValue: drawingRect.minY,
        maxValue: drawingRect.maxY
    )
}

func yPositionForString(_ stringIndex: Int) -> CGFloat? {
    guard stringIndex >= 0, stringIndex < stringYPositions.count else {
        return nil
    }

    return stringYPositions[stringIndex]
}
```

### 抽出 marker 规则对应的圆点中心

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：markerPlacements, markerCenters(for:)
// 功能说明：把 3、5、7、9 品的单圆点和 12 品双圆点坐标统一算好，后续渲染层直接消费，不再自行推导。
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

var markerPlacements: [MarkerPlacement] {
    let doubleDotFrets = Set(configuration.markerLayout.normalizedDoubleDotFrets(upTo: configuration.maxFret))

    return configuration.markerLayout.allMarkerFrets(upTo: configuration.maxFret).compactMap { fret in
        let centers = markerCenters(for: fret)
        guard !centers.isEmpty else {
            return nil
        }

        let style: MarkerPlacement.Style = doubleDotFrets.contains(fret) ? .doubleDot : .singleDot
        return MarkerPlacement(
            fret: fret,
            style: style,
            centers: centers,
            diameter: markerDiameter
        )
    }
}

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
```

### 抽出绘制区域和均匀分布算法

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：makeDrawingRect(bounds:metrics:), makeDistributedPositions(count:minValue:maxValue:)
// 功能说明：先统一收敛绘制边距，再把弦线沿纵向均匀分布，保证几何计算和渲染职责分离。
private static func makeDrawingRect(
    bounds: CGRect,
    metrics: FretboardConfiguration.LayoutMetrics
) -> CGRect {
    guard bounds.width > 0, bounds.height > 0 else {
        return .null
    }

    let horizontalInset = min(
        max(bounds.width * metrics.horizontalInsetRatio, 0),
        bounds.width / 2
    )
    let verticalInset = min(
        max(bounds.height * metrics.verticalInsetRatio, 0),
        bounds.height / 2
    )
    let rect = bounds.insetBy(dx: horizontalInset, dy: verticalInset)

    return rect.isNull || rect.isEmpty ? .null : rect
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

## 结果说明

- 阶段 2 的核心结果是把几何规则从未来的渲染层里提前剥离出来，形成独立的共享计算层。
- 现在已经有统一的空弦区、按弦区、上弦枕、品丝、弦线、marker 圆点中心计算结果。
- 后续阶段 3 的 `FretboardLayer` 只需要消费 `FretboardGeometry`，不用再自己判断 `0` 品、`12` 品双圆点或弦距分布。
- 本次没有修改任何平台控制器，也没有开始 `UIView` / `NSView` 包装接入。

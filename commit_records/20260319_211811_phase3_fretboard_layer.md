20260319_211811_phase3_fretboard_layer

# 阶段 3 修改记录

## 本次变更范围

- 新增共享渲染层文件 `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- 未修改 `InstrumentType.swift`
- 未修改 `FretboardConfiguration.swift`
- 未修改 `FretboardGeometry.swift`
- 未接入 `iOSViewController.swift`、`macOSViewController.swift`

## 修改前

### 共享渲染层文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名：无（文件不存在）
// 功能说明：修改前项目中没有共享 CALayer 渲染层，几何数据虽然已经存在，但还没有统一入口把背景、指板主体、品丝、弦线和 marker 真正绘制出来。
// 该文件在修改前不存在。
```

### 共享层职责现状

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard
// 函数名：无
// 功能说明：修改前共享层只完成了乐器模型、配置模型和几何计算，还没有承接实际绘制职责。
InstrumentType.swift
FretboardConfiguration.swift
FretboardGeometry.swift
```

## 修改后

### 新增共享渲染层

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名：configuration, init(), init(layer:), init(coder:)
// 功能说明：新增共享 CALayer 子类，作为后续 iOS UIView / macOS NSView 的统一底层渲染核心，并在配置变化时触发重绘。
import CoreGraphics
import QuartzCore

final class FretboardLayer: CALayer {
    var configuration: FretboardConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            setNeedsDisplay()
        }
    }

    override init() {
        super.init()
        configureLayer()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? FretboardLayer {
            configuration = otherLayer.configuration
        }

        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }
}
```

### 统一消费共享几何并完成主绘制流程

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名：draw(in:)
// 功能说明：绘制入口统一消费 FretboardGeometry，把静态指板的绘制顺序固定为背景、指板主体、marker、品丝、上弦枕、弦线和外边框。
override func draw(in context: CGContext) {
    context.clear(bounds)

    let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
    guard !geometry.drawingRect.isNull else {
        return
    }

    drawDisplayBackground(in: context, geometry: geometry)
    drawFretboardBody(in: context, geometry: geometry)
    drawMarkers(in: context, geometry: geometry)
    drawFrets(in: context, geometry: geometry)
    drawNut(in: context, geometry: geometry)
    drawStrings(in: context, geometry: geometry)
    drawDisplayBorder(in: context, geometry: geometry)
}
```

### 初始化 layer 的通用渲染行为

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名：configureLayer()
// 功能说明：统一设置 contentsScale、bounds 变化重绘和透明绘制行为，避免平台包装视图重复配置。
private func configureLayer() {
    contentsScale = max(contentsScale, 2)
    needsDisplayOnBoundsChange = true
    isOpaque = false
    drawsAsynchronously = false
}
```

### 分离各个绘制职责

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名：drawDisplayBackground(in:geometry:), drawFretboardBody(in:geometry:), drawMarkers(in:geometry:), drawFrets(in:geometry:), drawNut(in:geometry:), drawStrings(in:geometry:), drawDisplayBorder(in:geometry:)
// 功能说明：把静态指板分解成多个私有绘制函数，确保背景、木板区域、圆点标记、金属品丝、上弦枕和弦线职责独立。
private func drawDisplayBackground(in context: CGContext, geometry: FretboardGeometry) {
    let path = displayPath(for: geometry)

    context.saveGState()
    context.addPath(path)
    context.setFillColor(Palette.openStringArea)
    context.fillPath()
    context.restoreGState()
}

private func drawFretboardBody(in context: CGContext, geometry: FretboardGeometry) {
    guard !geometry.fretboardRect.isNull else {
        return
    }

    context.saveGState()
    context.addPath(displayPath(for: geometry))
    context.clip()
    context.setFillColor(Palette.fretboardWood)
    context.fill(geometry.fretboardRect)
    context.restoreGState()
}

private func drawMarkers(in context: CGContext, geometry: FretboardGeometry) {
    guard !geometry.markerPlacements.isEmpty else {
        return
    }

    context.saveGState()
    context.setFillColor(Palette.markerFill)

    for marker in geometry.markerPlacements {
        for center in marker.centers {
            let diameter = marker.diameter
            let markerRect = CGRect(
                x: center.x - (diameter / 2),
                y: center.y - (diameter / 2),
                width: diameter,
                height: diameter
            )
            context.fillEllipse(in: markerRect)
        }
    }

    context.restoreGState()
}

private func drawFrets(in context: CGContext, geometry: FretboardGeometry) {
    guard !geometry.fretLines.isEmpty else {
        return
    }

    context.saveGState()
    context.setStrokeColor(Palette.fretMetal)
    context.setLineWidth(max(configuration.layoutMetrics.fretLineWidth, 1))
    context.setLineCap(.butt)

    for fretLine in geometry.fretLines where fretLine.x < geometry.drawingRect.maxX {
        context.move(to: CGPoint(x: fretLine.x, y: geometry.drawingRect.minY))
        context.addLine(to: CGPoint(x: fretLine.x, y: geometry.drawingRect.maxY))
    }

    context.strokePath()
    context.restoreGState()
}
```

### 抽出显示外形和配色

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名：displayPath(for:), makeColor(_:_:_:_:)
// 功能说明：统一生成指板外轮廓，并把绘制颜色集中到 Palette，避免颜色值散落在各个绘制函数里。
private func displayPath(for geometry: FretboardGeometry) -> CGPath {
    let cornerRadius = min(geometry.drawingRect.height, geometry.displaySlotWidth) * 0.12
    return CGPath(
        roundedRect: geometry.drawingRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
}

private enum Palette {
    static let openStringArea = makeColor(0.93, 0.91, 0.87)
    static let fretboardWood = makeColor(0.42, 0.29, 0.19)
    static let fretMetal = makeColor(0.86, 0.86, 0.88)
    static let nut = makeColor(0.15, 0.15, 0.16)
    static let string = makeColor(0.96, 0.96, 0.97, 0.94)
    static let markerFill = makeColor(0.97, 0.95, 0.90)
    static let displayBorder = makeColor(0.22, 0.18, 0.14, 0.28)

    private static func makeColor(
        _ red: CGFloat,
        _ green: CGFloat,
        _ blue: CGFloat,
        _ alpha: CGFloat = 1
    ) -> CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
```

## 结果说明

- 阶段 3 的核心结果是把静态指板的实际绘制职责从平台层抽离，集中到共享 `CALayer` 中。
- `FretboardLayer` 已经直接消费 `FretboardGeometry`，因此后续平台包装视图只需要托管这个 layer，不需要再重复实现绘制逻辑。
- 当前已能在共享层表达并绘制空弦区背景、指板主体、金属品丝、上弦枕、弦线和 `3/5/7/9/12` 标记圆点。
- 本次没有修改任何平台控制器，也没有开始 `UIView` / `NSView` 包装和布局接入。

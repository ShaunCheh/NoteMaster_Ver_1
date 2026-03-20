20260320_122715_note_label_on_string_with_badge

# 音名落弦与圆形底修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`

## 修改前

### 配置层没有弦线边缘内缩参数

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：LayoutMetrics.default
// 功能说明：修改前布局参数只控制 drawingRect 的整体内边距，没有单独约束弦线距离上下边缘的安全距离。
struct LayoutMetrics: Equatable, Sendable {
    var horizontalInsetRatio: CGFloat
    var verticalInsetRatio: CGFloat
    var nutWidthRatio: CGFloat
    var fretLineWidth: CGFloat
    var stringLineWidth: CGFloat
    var markerDiameterRatio: CGFloat
    var doubleMarkerOffsetRatio: CGFloat

    static let `default` = LayoutMetrics(
        horizontalInsetRatio: 0.04,
        verticalInsetRatio: 0.16,
        nutWidthRatio: 0.014,
        fretLineWidth: 1,
        stringLineWidth: 1.5,
        markerDiameterRatio: 0.15,
        doubleMarkerOffsetRatio: 0.18
    )
}
```

### 几何层直接把弦线铺满整个绘制高度

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringYPositions
// 功能说明：修改前弦线直接分布在 drawingRect 的最上和最下边缘，后续如果把音名圆点压到弦线上，顶部和底部会缺少缓冲空间。
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
```

### 内容模型里没有圆形底的尺寸信息

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift
// 函数名：FretboardLabelContent
// 功能说明：修改前 label 只提供文本中心和最大文本尺寸，没有 badge 直径字段，渲染层无法直接根据 provider 输出绘制圆形底。
struct FretboardLabelContent: Equatable, Sendable {
    var stringIndex: Int
    var fret: Int
    var text: String
    var center: CGPoint
    var maxSize: CGSize
    var fontSize: CGFloat
}
```

### 音名 provider 用纵向偏移把文本放到弦间区域

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数名：LayoutMetrics.default, makeLabelContent, resolvedMaxLabelHeight, verticalOffsetReference
// 功能说明：修改前 provider 以 verticalOffsetRatio 为核心，把文本中心从弦线位置向上提，因此音名落点在两根弦之间，而不是压在弦线上。
struct LayoutMetrics: Equatable, Sendable {
    var verticalOffsetRatio: CGFloat
    var maxLabelWidthRatio: CGFloat
    var maxLabelHeightRatio: CGFloat
    var fontScale: CGFloat

    static let `default` = LayoutMetrics(
        verticalOffsetRatio: 0.28,
        maxLabelWidthRatio: 0.88,
        maxLabelHeightRatio: 0.9,
        fontScale: 0.46
    )
}

private func makeLabelContent(
    pitch: NotePitch,
    stringIndex: Int,
    fret: Int,
    stringY: CGFloat,
    slotRect: CGRect,
    geometry: FretboardGeometry
) -> FretboardLabelContent {
    let maxLabelHeight = resolvedMaxLabelHeight(slotRect: slotRect, geometry: geometry)
    let proposedCenterY = stringY - (verticalOffsetReference(slotRect: slotRect, geometry: geometry) * layoutMetrics.verticalOffsetRatio)
    let minCenterY = slotRect.minY + (maxLabelHeight / 2)
    let maxCenterY = slotRect.maxY - (maxLabelHeight / 2)
    let clampedCenterY = min(max(proposedCenterY, minCenterY), maxCenterY)
    let maxLabelWidth = max(slotRect.width * layoutMetrics.maxLabelWidthRatio, 0)

    return FretboardLabelContent(
        stringIndex: stringIndex,
        fret: fret,
        text: pitch.displayText(using: spelling, showsOctave: showsOctave),
        center: CGPoint(x: slotRect.midX, y: clampedCenterY),
        maxSize: CGSize(width: maxLabelWidth, height: maxLabelHeight),
        fontSize: fontSize
    )
}
```

### 渲染层只画文本，不画圆形音名底

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名：drawLabels, resolvedTextLine, Palette
// 功能说明：修改前共享渲染层只会把文本直接绘制到指板上，并根据空弦区与指板区切换文字颜色，没有独立的圆形 badge 绘制步骤。
for label in labels {
    guard let resolvedText = resolvedTextLine(for: label) else {
        continue
    }

    drawTextLine(
        resolvedText.line,
        bounds: resolvedText.bounds,
        centeredAt: label.center,
        in: context
    )
}

private func resolvedTextLine(
    for label: FretboardLabelContent
) -> (line: CTLine, bounds: CGRect)? {
    let baseFontSize = max(label.fontSize, 1)
    let textColor = label.fret == 0
        ? Palette.noteLabelTextOnOpenString
        : Palette.noteLabelTextOnFretboard

    var line = makeTextLine(
        text: label.text,
        fontSize: baseFontSize,
        textColor: textColor
    )
    // ... 省略缩放逻辑 ...
}

private enum Palette {
    static let noteLabelTextOnFretboard = makeColor(0.98, 0.97, 0.95)
    static let noteLabelTextOnOpenString = makeColor(0.20, 0.16, 0.12)
}
```

## 修改后

### 配置层新增弦线边缘内缩参数

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：LayoutMetrics.default
// 功能说明：新增 stringEdgeInsetRatio，让几何层可以为最上和最下两根弦预留安全带，为“音名圆点压在弦线上”提供空间基础。
struct LayoutMetrics: Equatable, Sendable {
    var horizontalInsetRatio: CGFloat
    var verticalInsetRatio: CGFloat
    var stringEdgeInsetRatio: CGFloat
    var nutWidthRatio: CGFloat
    var fretLineWidth: CGFloat
    var stringLineWidth: CGFloat
    var markerDiameterRatio: CGFloat
    var doubleMarkerOffsetRatio: CGFloat

    static let `default` = LayoutMetrics(
        horizontalInsetRatio: 0.04,
        verticalInsetRatio: 0.16,
        stringEdgeInsetRatio: 0.09,
        nutWidthRatio: 0.014,
        fretLineWidth: 1,
        stringLineWidth: 1.5,
        markerDiameterRatio: 0.15,
        doubleMarkerOffsetRatio: 0.18
    )
}
```

### 几何层把弦线限制在带内缩的 string band 中

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：stringYPositions, makeStringBandRect()
// 功能说明：修改后几何层先构造 string band，再把所有弦均匀分布在这个 band 内，避免圆形音名底与指板上下边缘直接冲突。
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

private func makeStringBandRect() -> CGRect {
    guard !drawingRect.isNull else {
        return .null
    }

    let maxInset = drawingRect.height / 2
    let proposedInset = drawingRect.height * configuration.layoutMetrics.stringEdgeInsetRatio
    let edgeInset = min(max(proposedInset, 0), maxInset)

    let stringBandRect = drawingRect.insetBy(dx: 0, dy: edgeInset)
    if stringBandRect.isNull || stringBandRect.isEmpty {
        return drawingRect
    }

    return stringBandRect
}
```

### 内容模型显式携带圆形底直径

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift
// 函数名：FretboardLabelContent
// 功能说明：修改后 provider 会把 badgeDiameter 一并下发，渲染层不需要自己猜测圆点尺寸，只按模型结果绘制即可。
struct FretboardLabelContent: Equatable, Sendable {
    var stringIndex: Int
    var fret: Int
    var text: String
    var center: CGPoint
    var badgeDiameter: CGFloat
    var maxSize: CGSize
    var fontSize: CGFloat
}
```

### 音名 provider 改为生成落在弦线上的圆形 badge 布局

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数名：LayoutMetrics.default, makeLabelContent, resolvedBadgeDiameter
// 功能说明：修改后 provider 不再通过 verticalOffsetRatio 把文本抬离弦线，而是直接使用 stringY 作为圆点中心参考，并同时计算 badge 直径和圆内文本可用尺寸。
struct LayoutMetrics: Equatable, Sendable {
    var badgeDiameterRatio: CGFloat
    var maxBadgeWidthRatio: CGFloat
    var textInsetRatio: CGFloat
    var fontScale: CGFloat

    static let `default` = LayoutMetrics(
        badgeDiameterRatio: 0.78,
        maxBadgeWidthRatio: 0.74,
        textInsetRatio: 0.18,
        fontScale: 0.88
    )
}

private func makeLabelContent(
    pitch: NotePitch,
    stringIndex: Int,
    fret: Int,
    stringY: CGFloat,
    slotRect: CGRect,
    geometry: FretboardGeometry
) -> FretboardLabelContent {
    let badgeDiameter = resolvedBadgeDiameter(slotRect: slotRect, geometry: geometry)
    let minCenterY = slotRect.minY + (badgeDiameter / 2)
    let maxCenterY = slotRect.maxY - (badgeDiameter / 2)
    let clampedCenterY = min(max(stringY, minCenterY), maxCenterY)
    let textInset = badgeDiameter * layoutMetrics.textInsetRatio
    let maxTextDiameter = max(badgeDiameter - (textInset * 2), 0)
    let fontSize = min(
        maxTextDiameter * layoutMetrics.fontScale,
        maxTextDiameter
    )

    return FretboardLabelContent(
        stringIndex: stringIndex,
        fret: fret,
        text: pitch.displayText(using: spelling, showsOctave: showsOctave),
        center: CGPoint(x: slotRect.midX, y: clampedCenterY),
        badgeDiameter: badgeDiameter,
        maxSize: CGSize(width: maxTextDiameter, height: maxTextDiameter),
        fontSize: fontSize
    )
}

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

### 渲染层先画圆，再在圆内绘制音名

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名：drawLabels, drawLabelBadge, resolvedTextLine, Palette
// 功能说明：修改后共享渲染层新增 drawLabelBadge，先绘制圆形底和描边，再用统一的 badge 文本颜色在圆心位置绘制音名。
for label in labels {
    guard let resolvedText = resolvedTextLine(for: label) else {
        continue
    }

    drawLabelBadge(
        for: label,
        in: context
    )
    drawTextLine(
        resolvedText.line,
        bounds: resolvedText.bounds,
        centeredAt: label.center,
        in: context
    )
}

private func drawLabelBadge(
    for label: FretboardLabelContent,
    in context: CGContext
) {
    let badgeRect = CGRect(
        x: label.center.x - (label.badgeDiameter / 2),
        y: label.center.y - (label.badgeDiameter / 2),
        width: label.badgeDiameter,
        height: label.badgeDiameter
    )

    context.saveGState()
    context.setFillColor(Palette.noteBadgeFill)
    context.fillEllipse(in: badgeRect)
    context.setStrokeColor(Palette.noteBadgeStroke)
    context.setLineWidth(1)
    context.strokeEllipse(in: badgeRect)
    context.restoreGState()
}

private func resolvedTextLine(
    for label: FretboardLabelContent
) -> (line: CTLine, bounds: CGRect)? {
    let baseFontSize = max(label.fontSize, 1)

    var line = makeTextLine(
        text: label.text,
        fontSize: baseFontSize,
        textColor: Palette.noteBadgeText
    )
    // ... 省略缩放逻辑 ...
}

private enum Palette {
    static let noteBadgeFill = makeColor(0.98, 0.97, 0.94, 0.98)
    static let noteBadgeStroke = makeColor(0.23, 0.18, 0.14, 0.36)
    static let noteBadgeText = makeColor(0.16, 0.12, 0.09)
}
```

## 结果说明

- 音名的中心点现在以弦线 `stringY` 为基准，不再默认悬浮在两根弦之间。
- 每个音名现在都有独立的圆形底和描边，文本会被缩放到圆内可用区域。
- 通过新增 `stringEdgeInsetRatio`，最上和最下两根弦也能在不贴边的前提下承载圆形音名底。
- provider 和 layer 的职责边界仍然保持清晰：provider 负责产出位置与尺寸，layer 负责最终绘制。

## 验证说明

- 已执行 `xcrun swiftc -typecheck`，本次涉及的共享指板相关 Swift 文件通过静态类型检查。

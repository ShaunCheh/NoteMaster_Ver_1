# 20260325_131911_phase3_fretboard_root_layer_scene_rendering

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260325_131911`
- 记录范围：指板竖向 Scene 重构的阶段 3
- 本阶段目标：把当前单层 `FretboardLayer` 重构为组合式 root-layer，并让渲染与 label 内容都直接消费 `scene`

## 本阶段完成的修改

1. 新增共享调色板 `FretboardPalette`，把板面层和文字层共用的颜色抽出。
2. 新增 `FretboardBoardLayer`，专门负责背景、指板主体、marker、品丝、琴枕、弦、边框。
3. 新增 `FretboardLabelsLayer`，专门负责 badge 和文字绘制。
4. 将 `FretboardLayer` 从“单层直接绘制全部内容”重构为“root-layer 统一同步 scene 到两个子层”。
5. 将 `FretboardContentProviding` 和 `NoteNameContentProvider` 从依赖 `FretboardGeometry` 改为直接依赖 `FretboardScene` 与 `labelAnchor`。

## 修改 1：新增共享调色板 `FretboardPalette`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数/成员: private enum Palette
// 功能说明: 修改前颜色常量被定义在 FretboardLayer 文件尾部，单层绘制直接引用，后续拆成 board/labels 两层后无法自然复用。
private enum Palette {
    static let openStringArea = makeColor(0.93, 0.91, 0.87)
    static let fretboardWood = makeColor(0.42, 0.29, 0.19)
    static let fretMetal = makeColor(0.86, 0.86, 0.88)
    static let nut = makeColor(0.15, 0.15, 0.16)
    static let string = makeColor(0.96, 0.96, 0.97, 0.94)
    static let markerFill = makeColor(0.97, 0.95, 0.90)
    static let displayBorder = makeColor(0.22, 0.18, 0.14, 0.28)
    static let noteBadgeFill = makeColor(0.98, 0.97, 0.94, 0.98)
    static let noteBadgeStroke = makeColor(0.23, 0.18, 0.14, 0.36)
    static let noteBadgeText = makeColor(0.16, 0.12, 0.09)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardPalette.swift
// 函数/成员: enum FretboardPalette
// 功能说明: 把原来单层渲染内嵌的颜色表提取为共享调色板，供 board-layer 和 labels-layer 共同消费。
enum FretboardPalette {
    static let openStringArea = makeColor(0.93, 0.91, 0.87)
    static let fretboardWood = makeColor(0.42, 0.29, 0.19)
    static let fretMetal = makeColor(0.86, 0.86, 0.88)
    static let nut = makeColor(0.15, 0.15, 0.16)
    static let string = makeColor(0.96, 0.96, 0.97, 0.94)
    static let markerFill = makeColor(0.97, 0.95, 0.90)
    static let displayBorder = makeColor(0.22, 0.18, 0.14, 0.28)
    static let noteBadgeFill = makeColor(0.98, 0.97, 0.94, 0.98)
    static let noteBadgeStroke = makeColor(0.23, 0.18, 0.14, 0.36)
    static let noteBadgeText = makeColor(0.16, 0.12, 0.09)
}
```

## 修改 2：新增 `FretboardBoardLayer`，承接板面绘制

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数/成员: draw(in:), drawDisplayBackground(in:geometry:), drawFretboardBody(in:geometry:), drawFrets(in:geometry:), drawStrings(in:geometry:)
// 功能说明: 修改前 FretboardLayer 在单个 CALayer 里一次性绘制背景、木纹主体、marker、品丝、琴枕、弦和边框，scene 虽已引入，但渲染仍是单层过程式调用。
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
    drawLabels(in: context, geometry: geometry)
    drawDisplayBorder(in: context, geometry: geometry)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardBoardLayer.swift
// 函数/成员: draw(in:), drawFrets(in:), drawStrings(in:)
// 功能说明: 新增独立 board-layer，只负责板面 chrome，并直接消费 scene.fretSegments / scene.stringSegments / scene.nutRect 等几何结果。
final class FretboardBoardLayer: CALayer {
    var configuration: FretboardConfiguration = .init()
    var scene: FretboardScene = .empty

    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard !scene.drawingRect.isNull else {
            return
        }

        drawDisplayBackground(in: context)
        drawFretboardBody(in: context)
        drawMarkers(in: context)
        drawFrets(in: context)
        drawNut(in: context)
        drawStrings(in: context)
        drawDisplayBorder(in: context)
    }

    private func drawFrets(in context: CGContext) {
        guard !scene.fretSegments.isEmpty else {
            return
        }

        context.saveGState()
        context.setStrokeColor(FretboardPalette.fretMetal)
        context.setLineWidth(max(configuration.layoutMetrics.fretLineWidth, 1))

        for fretSegment in scene.fretSegments {
            context.move(to: fretSegment.start)
            context.addLine(to: fretSegment.end)
        }

        context.strokePath()
        context.restoreGState()
    }

    private func drawStrings(in context: CGContext) {
        guard !scene.stringSegments.isEmpty else {
            return
        }

        context.saveGState()
        context.setStrokeColor(FretboardPalette.string)
        context.setLineWidth(max(configuration.layoutMetrics.stringLineWidth, 1))

        for stringSegment in scene.stringSegments {
            context.move(to: stringSegment.start)
            context.addLine(to: stringSegment.end)
        }

        context.strokePath()
        context.restoreGState()
    }
}
```

## 修改 3：新增 `FretboardLabelsLayer`，承接 badge 与文字绘制

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数/成员: drawLabels(in:geometry:), drawLabelBadge(for:in:), resolvedTextLine(for:)
// 功能说明: 修改前音名 badge 和文字绘制与板面绘制混在同一个 layer 里，无法独立失效，也无法以 scene 为唯一几何真相进行同步。
private func drawLabels(in context: CGContext, geometry: FretboardGeometry) {
    guard let contentProvider else {
        return
    }

    let labels = contentProvider.makeLabels(
        configuration: configuration,
        geometry: geometry
    )
    guard !labels.isEmpty else {
        return
    }

    for label in labels {
        guard let resolvedText = resolvedTextLine(for: label) else {
            continue
        }

        drawLabelBadge(for: label, in: context)
        drawTextLine(
            resolvedText.line,
            bounds: resolvedText.bounds,
            centeredAt: label.center,
            in: context
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLabelsLayer.swift
// 函数/成员: draw(in:), drawLabelBadge(for:in:), resolvedTextLine(for:)
// 功能说明: 新增 labels-layer，独立接收 contentProvider + scene，专门负责 badge 和文本排版绘制。
final class FretboardLabelsLayer: CALayer {
    var configuration: FretboardConfiguration = .init()
    var scene: FretboardScene = .empty
    var contentProvider: (any FretboardContentProviding)?

    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard
            !scene.drawingRect.isNull,
            let contentProvider
        else {
            return
        }

        let labels = contentProvider.makeLabels(
            configuration: configuration,
            scene: scene
        )
        guard !labels.isEmpty else {
            return
        }

        for label in labels {
            guard let resolvedText = resolvedTextLine(for: label) else {
                continue
            }

            drawLabelBadge(for: label, in: context)
            drawTextLine(
                resolvedText.line,
                bounds: resolvedText.bounds,
                centeredAt: label.center,
                in: context
            )
        }
    }
}
```

## 修改 4：`FretboardContentProviding` 从依赖 `geometry` 改为依赖 `scene`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift
// 函数/成员: FretboardContentProviding.makeLabels(configuration:geometry:)
// 功能说明: 修改前 provider 协议只能拿到 FretboardGeometry，label 内容层必须依赖 geometry 的具体实现细节。
protocol FretboardContentProviding: Sendable {
    func makeLabels(
        configuration: FretboardConfiguration,
        geometry: FretboardGeometry
    ) -> [FretboardLabelContent]
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift
// 函数/成员: FretboardContentProviding.makeLabels(configuration:scene:)
// 功能说明: provider 改为直接消费 scene，让文字内容层正式与 FretboardGeometry facade 解耦。
protocol FretboardContentProviding: Sendable {
    func makeLabels(
        configuration: FretboardConfiguration,
        scene: FretboardScene
    ) -> [FretboardLabelContent]
}
```

## 修改 5：`NoteNameContentProvider` 改为基于 `scene.labelAnchor`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数/成员: makeLabels(configuration:geometry:), makeLabelContent(...), resolvedBadgeDiameter(slotRect:geometry:)
// 功能说明: 修改前 NoteNameContentProvider 通过 geometry.yPositionForString 和 geometry.displaySlotRect(at:) 自己拼接 label 中心点，仍然依赖旧的 geometry 细节。
func makeLabels(
    configuration: FretboardConfiguration,
    geometry: FretboardGeometry
) -> [FretboardLabelContent] {
    var labels: [FretboardLabelContent] = []

    for stringIndex in 0..<configuration.stringCount {
        guard
            let openPitch = configuration.tuning.openStringPitch(for: stringIndex),
            let stringY = geometry.yPositionForString(stringIndex)
        else {
            continue
        }

        for fret in configuration.fretRange {
            let slotRect = geometry.displaySlotRect(at: fret)
            labels.append(
                makeLabelContent(
                    pitch: pitch,
                    stringIndex: stringIndex,
                    fret: fret,
                    stringY: stringY,
                    slotRect: slotRect,
                    geometry: geometry
                )
            )
        }
    }

    return labels
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数/成员: makeLabels(configuration:scene:), makeLabelContent(...), resolvedBadgeDiameter(cellFrame:)
// 功能说明: 直接基于 scene.labelAnchor 和 cellFrame 生成 badge / 文字布局，后续 vertical 只要 scene 给对锚点，provider 就不必再管坐标轴方向。
func makeLabels(
    configuration: FretboardConfiguration,
    scene: FretboardScene
) -> [FretboardLabelContent] {
    var labels: [FretboardLabelContent] = []

    for stringIndex in 0..<configuration.stringCount {
        guard
            let openPitch = configuration.tuning.openStringPitch(for: stringIndex)
        else {
            continue
        }

        for fret in configuration.fretRange {
            guard
                let anchor = scene.labelAnchor(
                    stringIndex: stringIndex,
                    fret: fret
                )
            else {
                continue
            }

            labels.append(
                makeLabelContent(
                    pitch: pitch,
                    stringIndex: stringIndex,
                    fret: fret,
                    anchor: anchor
                )
            )
        }
    }

    return labels
}

private func resolvedBadgeDiameter(
    cellFrame: CGRect
) -> CGFloat {
    let heightDrivenDiameter = cellFrame.height * layoutMetrics.badgeDiameterRatio
    let widthDrivenDiameter = cellFrame.width * layoutMetrics.maxBadgeWidthRatio

    return max(min(heightDrivenDiameter, widthDrivenDiameter), 0)
}
```

## 修改 6：`FretboardLayer` 重构为组合式 root-layer

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数/成员: draw(in:), configuration.didSet, contentProvider.didSet
// 功能说明: 修改前 FretboardLayer 既是外部平台视图的 backing layer，又是具体的单层绘制实现；configuration/contentProvider 变化时只会触发本层 setNeedsDisplay。
final class FretboardLayer: CALayer {
    var configuration: FretboardConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            setNeedsDisplay()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(in context: CGContext) {
        context.clear(bounds)
        let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
        // 后续省略，单层直接完成全部渲染。
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数/成员: synchronizeSublayerState(), invalidateSublayersForCurrentState(displayImmediately:), refreshForCurrentBounds(displayImmediately:)
// 功能说明: FretboardLayer 现在作为 root-layer 只负责 scene 构建和子层同步；board-layer 与 labels-layer 共用同一份 scene。
final class FretboardLayer: CALayer {
    var configuration: FretboardConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            invalidateSublayersForCurrentState()
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            guard oldValue != contentsScale else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    private let boardLayer = FretboardBoardLayer()
    private let labelsLayer = FretboardLabelsLayer()

    override func layoutSublayers() {
        super.layoutSublayers()
        refreshForCurrentBounds()
    }

    private func synchronizeSublayerState() {
        let scene = FretboardSceneBuilder(
            configuration: configuration
        ).makeScene(bounds: bounds)

        performWithoutImplicitAnimations {
            boardLayer.frame = bounds
            labelsLayer.frame = bounds
            boardLayer.configuration = configuration
            labelsLayer.configuration = configuration
            boardLayer.scene = scene
            labelsLayer.scene = scene
            boardLayer.contentsScale = contentsScale
            labelsLayer.contentsScale = contentsScale
            labelsLayer.contentProvider = contentProvider
        }
    }
}
```

## 本阶段刻意保持不变的部分

1. `iOSFretboardView` 和 `macOSFretboardView` 继续使用 `FretboardLayer` 作为 backing layer / backing CALayer，平台层接口没有改名。
2. `FretboardGeometry` 作为兼容 facade 仍然保留，阶段 3 没有把平台事件链改成直接读 `scene`。
3. 竖向 `VerticalFretboardGeometryStrategy` 还没有落地；本阶段只把 scene 真相贯通到渲染与内容层。

## 验证情况

1. 已读取本阶段新增 / 修改文件的 IDE diagnostics，无 linter 错误。
2. 已使用 `swiftc -typecheck` 对共享渲染链做静态类型检查，结果通过。
3. 本阶段未额外运行 `xcodebuild`，因此没有做整工程构建级验证。

## 结果小结

- 阶段 3 完成后，`FretboardScene` 已经从“几何和命中的中间真相”进一步升级为“渲染层和内容层共同消费的中间真相”。
- `FretboardLayer` 现在只负责 scene 同步和子层组合，不再承载具体的板面绘制与文字绘制细节。
- 后续进入阶段 4 时，真正需要改的核心将集中在 `VerticalFretboardGeometryStrategy` 和 `FretboardSceneBuilder` 的 vertical 分发，而不需要回头再拆渲染层。

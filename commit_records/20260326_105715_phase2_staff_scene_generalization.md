# 20260326_105715_phase2_staff_scene_generalization

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_105715`
- 记录范围：`五线谱音符渲染` 的阶段 2 实施
- 本次目标：把 `Shared/Staff` 从“只适合 clef 的 scene / renderer 模型”扩成“可承载 note 图元”的通用基础层
- 根因结论：阶段 1 已经建立了 `StaffScore` 输入层，但当前 `Shared/Staff` 仍然存在 4 个结构性问题：
  - `StaffGlyphSymbolID` 只有 `trebleClef / bassClef`
  - `StaffScene` 只有 `lineSegments + glyphs`，没有 stem / ledger line 这类附加线段语义
  - `StaffGlyphLayer` 实际只消费 `scene.glyphs`
  - `CoreTextMusicGlyphRenderer` 的 `verticalTrimRatio(...)` 仍然通过 `glyphItem.symbolID.clef` 反推 clef 规则，普通 note glyph 一接进来就会误走 clef 逻辑
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`

## 本次完成的修改

1. 扩展 `StaffGlyphSymbolID`，补上 `noteheadWhole / noteheadHalf / noteheadBlack` 以及 `accidentalFlat / accidentalNatural / accidentalSharp`。
2. 扩展 `StaffScene`，新增 `StaffStrokeItem`、`StaffStrokeStyle`、`StaffStrokeSemantic`，正式承接 stem / ledger line 语义。
3. 扩展 `StaffGlyphRenderHint`，新增显式 `verticalTrimMode`，让 clef 专用 trim 与普通 glyph 彻底分流。
4. 在 `StaffGlyphLayer` 中接通 `scene.strokeItems` 的绘制通路，不再只绘制 `glyphs`。
5. 在 `CoreTextMusicGlyphRenderer` 中拆开“clef 专用定位/裁切”和“普通 frame glyph 对齐”。

## 修改 1：把 `StaffScene` 从 clef-only 模型扩成通用场景模型

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数/成员: StaffGlyphSymbolID / StaffGlyphRenderHint / StaffScene
// 功能说明: 修改前 StaffScene 只能表达 treble / bass clef 两类 glyph，
// 同时 scene 本身也只有 lineSegments + glyphs，没有承接 stem / ledger line 的语义位置。
enum StaffGlyphSymbolID: Equatable, Sendable {
    case trebleClef
    case bassClef
}

struct StaffGlyphRenderHint: Equatable, Sendable {
    var preservesAspectRatio: Bool
    var prefersOpticalBoundsAlignment: Bool
    var boundsOverlayStyle: StaffGlyphBoundsOverlayStyle?
    var anchorOverlayStyle: StaffGlyphAnchorOverlayStyle?
}

struct StaffScene: Equatable, Sendable {
    var lineSegments: [StaffGeometry.StaffLineSegment]
    var glyphs: [StaffGlyphItem]

    static let empty = StaffScene(
        lineSegments: [],
        glyphs: []
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数/成员: StaffGlyphSymbolID / StaffGlyphRenderHint / StaffStrokeItem / StaffScene
// 功能说明: 修改后 scene 可以同时承接 clef、notehead、accidental 以及附加线段；
// 其中 verticalTrimMode 明确表达“是否使用 clef 专用裁切”，不再依赖 symbol 反推。
enum StaffGlyphSymbolID: Equatable, Sendable {
    case trebleClef
    case bassClef
    case noteheadWhole
    case noteheadHalf
    case noteheadBlack
    case accidentalFlat
    case accidentalNatural
    case accidentalSharp
}

struct StaffGlyphRenderHint: Equatable, Sendable {
    enum VerticalTrimMode: Equatable, Sendable {
        case none
        case clefSpecific
    }

    var preservesAspectRatio: Bool
    var prefersOpticalBoundsAlignment: Bool
    var verticalTrimMode: VerticalTrimMode
    var boundsOverlayStyle: StaffGlyphBoundsOverlayStyle?
    var anchorOverlayStyle: StaffGlyphAnchorOverlayStyle?
}

struct StaffStrokeItem: Equatable, Sendable {
    var semantic: StaffStrokeSemantic
    var start: CGPoint
    var end: CGPoint
    var style: StaffStrokeStyle
}

struct StaffScene: Equatable, Sendable {
    // 五线谱本体由独立 lines layer 绘制；scene 仍保留这份语义结果，供验证和后续 builder 使用。
    var lineSegments: [StaffGeometry.StaffLineSegment]
    // note stem / ledger line 等附加线段走 scene item，而不是伪装成 staff line。
    var strokeItems: [StaffStrokeItem]
    var glyphs: [StaffGlyphItem]

    static let empty = StaffScene(
        lineSegments: [],
        strokeItems: [],
        glyphs: []
    )
}
```

## 修改 2：扩展 `MusicGlyph` 符号目录，为 notehead / accidental 建立 SMuFL 映射

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift
// 函数/成员: MusicGlyph / StaffGlyphSymbolID.musicGlyph
// 功能说明: 修改前符号目录只有 treble clef 和 bass clef；
// 即使 scene 侧想承接音符，也没有可供 renderer 消费的 notehead / accidental glyph 映射。
struct MusicGlyph: Equatable, Sendable {
    // SMuFL gClef，对应 Bravura 中的 treble clef。
    static let trebleClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE050
    )

    // SMuFL fClef，对应 Bravura 中的 bass clef。
    static let bassClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE062
    )
}

extension StaffGlyphSymbolID {
    var musicGlyph: MusicGlyph {
        switch self {
        case .trebleClef:
            return .trebleClef
        case .bassClef:
            return .bassClef
        }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift
// 函数/成员: MusicGlyph / StaffGlyphSymbolID.musicGlyph
// 功能说明: 修改后符号目录补齐 notehead 与常用升降记号；
// 后续 scene builder 只需要产出 StaffGlyphSymbolID，即可直接走现有 CoreText glyph 渲染通路。
struct MusicGlyph: Equatable, Sendable {
    static let trebleClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE050
    )

    static let bassClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE062
    )

    static let noteheadWhole = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE0A2
    )

    static let noteheadHalf = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE0A3
    )

    static let noteheadBlack = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE0A4
    )

    static let accidentalFlat = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE260
    )

    static let accidentalNatural = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE261
    )

    static let accidentalSharp = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE262
    )
}
```

## 修改 3：把 `scene.strokeItems` 正式接入 `StaffGlyphLayer`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift
// 函数/成员: draw(in:)
// 功能说明: 修改前 StaffGlyphLayer 实际只消费 scene.glyphs；
// 即使后续 scene 里新增 stem / ledger line，渲染链路也不会真正把它们画出来。
override func draw(in context: CGContext) {
    let geometry = StaffGeometry(
        configuration: configuration,
        bounds: bounds,
        orientation: configuration.canvasOrientation
    )
    let glyphs = sceneProvider.makeScene(geometry: geometry).glyphs
    guard !glyphs.isEmpty else {
        return
    }

    let renderer = MusicGlyphRendererFactory.makeRenderer(
        renderMode: configuration.renderMode,
        bundle: resourceBundle
    )

    context.saveGState()
    applyContextNormalizationIfNeeded(in: context)

    for glyph in glyphs {
        renderer.draw(
            glyphItem: glyph,
            in: context,
            geometry: geometry,
            canvasOrientation: geometry.orientation
        )
    }

    context.restoreGState()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift
// 函数/成员: draw(in:) / drawStrokeItems(_:in:)
// 功能说明: 修改后 StaffGlyphLayer 先画 scene.strokeItems，再画 glyphs；
// 这样 scene builder 后续产出的 stem / ledger line 已经能直接落到屏幕上，不需要再改 layer 通路。
override func draw(in context: CGContext) {
    let geometry = StaffGeometry(
        configuration: configuration,
        bounds: bounds,
        orientation: configuration.canvasOrientation
    )
    let scene = sceneProvider.makeScene(geometry: geometry)
    guard !scene.glyphs.isEmpty || !scene.strokeItems.isEmpty else {
        return
    }

    let renderer = MusicGlyphRendererFactory.makeRenderer(
        renderMode: configuration.renderMode,
        bundle: resourceBundle
    )

    context.saveGState()
    applyContextNormalizationIfNeeded(in: context)

    drawStrokeItems(scene.strokeItems, in: context)

    for glyph in scene.glyphs {
        renderer.draw(
            glyphItem: glyph,
            in: context,
            geometry: geometry,
            canvasOrientation: geometry.orientation
        )
    }

    context.restoreGState()
}

private func drawStrokeItems(
    _ strokeItems: [StaffStrokeItem],
    in context: CGContext
) {
    for strokeItem in strokeItems {
        context.saveGState()
        context.setStrokeColor(strokeItem.style.strokeColor.cgColor)
        context.setLineWidth(strokeItem.style.lineWidth)
        context.setLineCap(strokeItem.style.lineCap.cgLineCap)
        context.move(to: strokeItem.start)
        context.addLine(to: strokeItem.end)
        context.strokePath()
        context.restoreGState()
    }
}
```

## 修改 4：让 `StaffSceneProvider` 适配新 scene 契约

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: makeScene(geometry:)
// 功能说明: 修改前 provider 返回的 StaffScene 只包含 lineSegments 和 glyphs；
// 一旦 StaffScene 结构扩展，就需要先把过渡层补齐，避免旧 provider 直接编译失败。
func makeScene(geometry: StaffGeometry) -> StaffScene {
    // ...
    return StaffScene(
        lineSegments: geometry.staffLineSegments,
        glyphs: glyphs
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: makeScene(geometry:)
// 功能说明: 修改后 provider 先按新 scene 契约返回空的 strokeItems；
// 这样阶段 2 先把契约和渲染通路打通，阶段 3 再把真正的 note stem / ledger line 交给 scene builder 产出。
func makeScene(geometry: StaffGeometry) -> StaffScene {
    // ...
    return StaffScene(
        lineSegments: geometry.staffLineSegments,
        strokeItems: [],
        glyphs: glyphs
    )
}
```

## 修改 5：把 renderer 的 clef 专用裁切逻辑与普通 frame glyph 对齐逻辑拆开

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: drawGlyph(_:centeredIn:renderHint:in:geometry:) / verticalTrimRatio(for:geometry:)
// 功能说明: 修改前普通 frame glyph 固定按 opticalBounds 居中，而 verticalTrimRatio 直接依赖 glyphItem.symbolID.clef；
// 这意味着只要把非 clef glyph 接进来，就会被迫套用 clef 专用 trim 语义。
private func drawGlyph(
    _ resolvedLine: ResolvedGlyphLine,
    centeredIn frame: CGRect,
    renderHint: StaffGlyphRenderHint,
    in context: CGContext,
    geometry: StaffGeometry
) {
    let frameCenter = CGPoint(
        x: frame.midX,
        y: geometry.bounds.height - frame.midY
    )
    let drawOrigin = CGPoint(
        x: frameCenter.x - resolvedLine.opticalBounds.midX,
        y: frameCenter.y - resolvedLine.opticalBounds.midY
    )
    // ...
}

private func verticalTrimRatio(
    for glyphItem: StaffGlyphItem,
    geometry: StaffGeometry
) -> CGFloat {
    let clef: StaffClef
    switch glyphItem.placement {
    case let .anchor(anchor):
        clef = anchor.semantic.clef
    case .frame:
        clef = glyphItem.symbolID.clef
    }

    return geometry.configuration.clefVerticalTrimRatio(for: clef)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: drawGlyph(_:centeredIn:renderHint:in:geometry:) / alignedBounds(for:renderHint:) / verticalTrimRatio(for:geometry:)
// 功能说明: 修改后 renderer 通过 renderHint.verticalTrimMode 显式判断是否套用 clef trim；
// 普通 frame glyph 走 alignedBounds，对齐策略由 renderHint 驱动，不再偷依赖 symbol 是否属于 clef。
private func drawGlyph(
    _ resolvedLine: ResolvedGlyphLine,
    centeredIn frame: CGRect,
    renderHint: StaffGlyphRenderHint,
    in context: CGContext,
    geometry: StaffGeometry
) {
    let alignmentBounds = alignedBounds(
        for: resolvedLine,
        renderHint: renderHint
    )
    let frameCenter = CGPoint(
        x: frame.midX,
        y: geometry.bounds.height - frame.midY
    )
    let drawOrigin = CGPoint(
        x: frameCenter.x - alignmentBounds.midX,
        y: frameCenter.y - alignmentBounds.midY
    )
    // ...
}

private func alignedBounds(
    for resolvedLine: ResolvedGlyphLine,
    renderHint: StaffGlyphRenderHint
) -> CGRect {
    renderHint.prefersOpticalBoundsAlignment
        ? resolvedLine.opticalBounds
        : resolvedLine.clippedBounds
}

private func verticalTrimRatio(
    for glyphItem: StaffGlyphItem,
    geometry: StaffGeometry
) -> CGFloat {
    switch glyphItem.renderHint.verticalTrimMode {
    case .none:
        return 0
    case .clefSpecific:
        switch glyphItem.placement {
        case let .anchor(anchor):
            return geometry.configuration.clefVerticalTrimRatio(
                for: anchor.semantic.clef
            )
        case .frame:
            guard let clef = glyphItem.symbolID.clef else {
                return 0
            }

            return geometry.configuration.clefVerticalTrimRatio(for: clef)
        }
    }
}
```

## 修改结果说明

- 阶段 2 没有接入真正的 note 布局算法，也没有让控制器或平台 view 传入 `StaffScore`。
- 这一步解决的是“地基问题”，不是“出图问题”：
  - scene 现在已经能承载 note glyph 与附加线段
  - renderer 现在已经能区分 clef glyph 和普通 frame glyph
  - layer 现在已经能画 scene 里的附加线段
- 这样阶段 3 只需要专注于 `StaffScore -> StaffScene` 的 builder 逻辑，不需要再回头改 scene/render 契约。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
   - `NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift`
   - `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
   - `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
   - `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
2. 执行以下静态校验通过：
   - `xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Staff/*.swift`
3. 本阶段尚未做的验证：
   - 还未由 `StaffSceneBuilder` 真实产出 `notehead / stem / ledger line`
   - 还未把 `StaffScore` 接入平台层显示
   - 还未做运行态五线谱音符绘制联调

# 20260326_125653_notehead_visibility_fix_and_diagnostics

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_125653`
- 记录范围：五线谱音符渲染链路的“只显示符头 + notehead 排障修复”
- 本次目标：先暂时关闭 `accidental / stem / ledger line`，集中排查 `notehead` 为什么没有显示
- 根因结论：`StaffSceneBuilder` 实际已经正确产出了 `notehead`，问题不在 scene 生成，而在 `CoreTextMusicGlyphRenderer` 仍用 `CTLine` 的 line bounds 做 frame glyph 的尺寸拟合与对齐；在 `Bravura` 里，符头的 `opticalBounds` / `clippedBounds` 竖向边界远大于实际轮廓，导致符头被压缩到几乎不可见
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffDebugLogger.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 新增 `StaffNotationDisplayOptions`，把 `accidental / stem / ledger line` 是否显示收口到共享层显示策略里。
2. 默认改成 `noteheadsOnly`，当前运行态只画 `clef + staff line + notehead`，方便先集中排查符头显示问题。
3. 在 `StaffGlyphLayer` 和 `CoreTextMusicGlyphRenderer` 增加一次性 debug 日志，确认 `scene` 中是否真的生成了 `notehead`，以及 renderer 用的到底是哪套边界和字体尺寸。
4. 修正 `CoreTextMusicGlyphRenderer` 对 frame glyph 的尺寸拟合逻辑：改为使用 `CTFontGetBoundingRectsForGlyphs` 取得真实 `glyphBounds`，并允许 frame glyph 放大到填满目标 frame。
5. 将 `StaffValidation` 与当前显示策略对齐，避免验证器还在强制要求隐藏中的 `accidental / stem / ledger line` 出现。

## 修改 1：把显示策略收口为 `noteheadsOnly`

### 修改前：共享状态没有“只显示符头”的策略入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState.sceneProvider
// 功能说明: 修改前 sceneProvider 只把 clef 与 score 投影给 SceneProvider；
// builder 一旦拿到完整 score，就会继续生成 accidental / stem / ledger line，无法先退回最小可视化链路排查符头。
var sceneProvider: StaffSceneProvider {
    StaffSceneProvider(
        clef: configuration.clef,
        score: resolvedScore,
        renderHint: .staffClef(
            boundsOverlayStyle: configuration.debugOptions.showsClefBounds
            ? .clefDebug(lineWidth: configuration.debugOptions.clefBoundsLineWidth)
            : nil,
            anchorOverlayStyle: configuration.debugOptions.showsClefAnchor
            ? .clefDebug(
                lineWidth: configuration.debugOptions.clefAnchorLineWidth,
                crossHalfLength: configuration.debugOptions.clefAnchorCrossHalfLength
            )
            : nil
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.makeScene(geometry:)
// 功能说明: 修改前 SceneBuilder 会无条件把 accidental / stem / ledger line 一起塞进 scene；
// 这样运行时就算只想确认 notehead 是否进到 renderer，也会被附加图元混在一起。
for (note, noteheadFrame) in zip(score.notes, noteFrames) {
    guard let positionedPitch = pitchLayout.positionedPitch(note.pitch, in: geometry) else {
        continue
    }

    if let accidentalSymbolID = positionedPitch.accidentalSymbolID {
        glyphs.append(
            StaffGlyphItem(
                symbolID: accidentalSymbolID,
                placement: .frame(
                    accidentalFrame(
                        for: noteheadFrame,
                        centerY: positionedPitch.centerY
                    )
                ),
                tintColor: glyphTintColor,
                renderHint: .accidental()
            )
        )
    }

    glyphs.append(
        StaffGlyphItem(
            symbolID: noteheadSymbolID(for: note.duration),
            placement: .frame(
                centeredFrame(
                    center: CGPoint(
                        x: noteheadFrame.midX,
                        y: positionedPitch.centerY
                    ),
                    size: noteheadFrame.size
                )
            ),
            tintColor: glyphTintColor,
            renderHint: .notehead()
        )
    )

    if note.duration.showsStem {
        strokeItems.append(
            stemStroke(
                for: noteheadFrame,
                positionedPitch: positionedPitch,
                geometry: geometry
            )
        )
    }

    strokeItems.append(
        contentsOf: ledgerLineStrokes(
            for: noteheadFrame,
            ledgerLineYs: positionedPitch.ledgerLineYs
        )
    )
}
```

### 修改后：新增显示策略，并默认走 `noteheadsOnly`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数/成员: StaffNotationDisplayOptions / StaffGlyphSymbolID.isClef / isNotehead / isAccidental / debugName
// 功能说明: 修改后把“显示哪些记谱元素”抽成共享值对象；
// 同时把符号分类和 debugName 放回 StaffScene 共享层，供 validation、glyph layer 日志和 renderer 统一复用。
struct StaffNotationDisplayOptions: Equatable, Sendable {
    var showsAccidentals: Bool
    var showsStems: Bool
    var showsLedgerLines: Bool

    static let noteheadsOnly = StaffNotationDisplayOptions(
        showsAccidentals: false,
        showsStems: false,
        showsLedgerLines: false
    )

    static let fullNotation = StaffNotationDisplayOptions(
        showsAccidentals: true,
        showsStems: true,
        showsLedgerLines: true
    )

    var debugSummary: String {
        "accidentals=\(showsAccidentals) stems=\(showsStems) ledgerLines=\(showsLedgerLines)"
    }
}

extension StaffGlyphSymbolID {
    var isClef: Bool { ... }
    var isNotehead: Bool { ... }
    var isAccidental: Bool { ... }

    var debugName: String {
        switch self {
        case .trebleClef: return "trebleClef"
        case .bassClef: return "bassClef"
        case .noteheadWhole: return "noteheadWhole"
        case .noteheadHalf: return "noteheadHalf"
        case .noteheadBlack: return "noteheadBlack"
        case .accidentalFlat: return "accidentalFlat"
        case .accidentalNatural: return "accidentalNatural"
        case .accidentalSharp: return "accidentalSharp"
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState.sceneProvider
// 功能说明: 修改后 StaffDisplayState 在共享状态层明确指定当前只显示 notehead；
// 控制器不需要知道 builder 细节，只需要继续从 state 派生 sceneProvider。
var sceneProvider: StaffSceneProvider {
    StaffSceneProvider(
        clef: configuration.clef,
        score: resolvedScore,
        notationDisplayOptions: .noteheadsOnly,
        renderHint: .staffClef(
            boundsOverlayStyle: configuration.debugOptions.showsClefBounds
            ? .clefDebug(lineWidth: configuration.debugOptions.clefBoundsLineWidth)
            : nil,
            anchorOverlayStyle: configuration.debugOptions.showsClefAnchor
            ? .clefDebug(
                lineWidth: configuration.debugOptions.clefAnchorLineWidth,
                crossHalfLength: configuration.debugOptions.clefAnchorCrossHalfLength
            )
            : nil
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: StaffSceneProvider.init(...) / StaffSceneProvider.makeScene(geometry:)
// 功能说明: 修改后 SceneProvider 不只传 clef 和 score，还把 notationDisplayOptions 下发给 SceneBuilder；
// 这样“先关掉附加记谱元素”的决策不会散落在平台层。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var score: StaffScore?
    var notationDisplayOptions: StaffNotationDisplayOptions
    var glyphTintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint

    init(
        clef: StaffClef = .treble,
        score: StaffScore? = nil,
        notationDisplayOptions: StaffNotationDisplayOptions = .noteheadsOnly,
        glyphTintColor: StaffSceneColor = .primaryInk,
        renderHint: StaffGlyphRenderHint = .staffClef()
    ) { ... }

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        if let score, !score.isEmpty {
            return StaffSceneBuilder(
                clef: clef,
                score: score,
                notationDisplayOptions: notationDisplayOptions,
                glyphTintColor: glyphTintColor,
                clefRenderHint: renderHint
            ).makeScene(geometry: geometry)
        }

        ...
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.makeScene(geometry:) / makeNoteheadFrames(noteCount:geometry:)
// 功能说明: 修改后 SceneBuilder 只在显示策略允许时才生成 accidental / stem / ledger line；
// 同时当 accidental 被关闭时，note 排版会回退到更紧凑的 leading inset，避免给已隐藏元素预留无意义空白。
struct StaffSceneBuilder: Equatable, Sendable {
    var clef: StaffClef
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    ...
}

for (note, noteheadFrame) in zip(score.notes, noteFrames) {
    ...
    if notationDisplayOptions.showsAccidentals,
       let accidentalSymbolID = positionedPitch.accidentalSymbolID {
        glyphs.append(...)
    }

    glyphs.append(
        StaffGlyphItem(
            symbolID: noteheadSymbolID(for: note.duration),
            placement: .frame(...),
            tintColor: glyphTintColor,
            renderHint: .notehead()
        )
    )

    if notationDisplayOptions.showsStems,
       note.duration.showsStem {
        strokeItems.append(...)
    }

    if notationDisplayOptions.showsLedgerLines {
        strokeItems.append(contentsOf: ledgerLineStrokes(...))
    }
}

let minimumLeadingInset = noteheadSize.width * layoutMetrics.noteLeadingInsetInNoteheadWidths
let leftInset = notationDisplayOptions.showsAccidentals
    ? max(
        minimumLeadingInset,
        accidentalWidth + accidentalGap + (noteheadSize.width / 2)
    )
    : minimumLeadingInset
```

## 修改 2：修复 `notehead` 在 CoreText renderer 中的拟合与对齐根因

### 修改前：frame glyph 仍按 `CTLine` line bounds 做 shrink-to-fit

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: resolvedGlyphLine(for:targetSize:tintColor:verticalTrimRatio:) / drawGlyph(...)
// 功能说明: 修改前 frame glyph 和 clef 共用 line bounds 语义；
// 对 Bravura notehead 来说，CTLine 的 optical/clipped bounds 竖向高度极大，fitScale 会把符头继续缩小，最终接近不可见。
private func resolvedGlyphLine(
    for glyph: MusicGlyph,
    targetSize: CGSize,
    tintColor: StaffSceneColor,
    verticalTrimRatio: CGFloat
) -> ResolvedGlyphLine? {
    let baseFontSize = max(targetSize.height, 1)

    guard var resolved = makeResolvedGlyphLine(
        glyph: glyph,
        fontSize: baseFontSize,
        tintColor: tintColor,
        verticalTrimRatio: verticalTrimRatio
    ) else {
        return nil
    }

    let widthScale = targetSize.width / max(resolved.opticalBounds.width, 1)
    let heightScale = targetSize.height / max(resolved.opticalBounds.height, 1)
    let fitScale = min(1, widthScale, heightScale)

    if fitScale < 1 {
        resolved = makeResolvedGlyphLine(
            glyph: glyph,
            fontSize: max(baseFontSize * fitScale, 1),
            tintColor: tintColor,
            verticalTrimRatio: verticalTrimRatio
        ) ?? resolved
    }

    guard
        !resolved.opticalBounds.isNull,
        !resolved.opticalBounds.isEmpty,
        !resolved.clippedBounds.isNull,
        !resolved.clippedBounds.isEmpty
    else {
        return nil
    }

    return resolved
}

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

    drawLine(
        resolvedLine.line,
        at: drawOrigin,
        clipBounds: flippedBounds(
            for: resolvedLine.clippedBounds,
            drawOrigin: drawOrigin
        ),
        in: context,
        geometry: geometry
    )
}
```

### 修改后：frame glyph 改为使用真实 `glyphBounds`，并允许放大填满目标 frame

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: ResolvedGlyphLine / GlyphSizingMode / resolvedGlyphLine(for:targetSize:tintColor:verticalTrimRatio:sizingMode:)
// 功能说明: 修改后把 clef 和 frame glyph 的尺寸拟合语义拆开；
// clef 继续沿用 opticalBounds，而 notehead 这类 frame glyph 改用真实 glyphBounds 参与 fit，并允许按 frame 放大。
private struct ResolvedGlyphLine {
    var line: CTLine
    var fontPostScriptName: String
    var appliedFontSize: CGFloat
    var opticalBounds: CGRect
    var clippedBounds: CGRect
    var glyphBounds: CGRect
    var fittingBounds: CGRect
}

private enum GlyphSizingMode {
    case anchoredClef
    case frameGlyph

    func resolvedFitScale(
        widthScale: CGFloat,
        heightScale: CGFloat
    ) -> CGFloat {
        let rawScale = max(min(widthScale, heightScale), 0.01)

        switch self {
        case .anchoredClef:
            return min(rawScale, 1)
        case .frameGlyph:
            return rawScale
        }
    }
}

private func resolvedGlyphLine(
    for glyph: MusicGlyph,
    targetSize: CGSize,
    tintColor: StaffSceneColor,
    verticalTrimRatio: CGFloat,
    sizingMode: GlyphSizingMode
) -> ResolvedGlyphLine? {
    let baseFontSize = max(targetSize.height, 1)

    guard var resolved = makeResolvedGlyphLine(
        glyph: glyph,
        fontSize: baseFontSize,
        tintColor: tintColor,
        verticalTrimRatio: verticalTrimRatio,
        sizingMode: sizingMode
    ) else {
        return nil
    }

    let widthScale = targetSize.width / max(resolved.fittingBounds.width, 1)
    let heightScale = targetSize.height / max(resolved.fittingBounds.height, 1)
    let fitScale = sizingMode.resolvedFitScale(
        widthScale: widthScale,
        heightScale: heightScale
    )

    if abs(fitScale - 1) > 0.001 {
        resolved = makeResolvedGlyphLine(
            glyph: glyph,
            fontSize: max(baseFontSize * fitScale, 1),
            tintColor: tintColor,
            verticalTrimRatio: verticalTrimRatio,
            sizingMode: sizingMode
        ) ?? resolved
    }

    guard
        !resolved.fittingBounds.isNull,
        !resolved.fittingBounds.isEmpty
    else {
        return nil
    }

    return resolved
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: makeResolvedGlyphLine(...) / glyphBounds(for:font:fallback:) / fittingBounds(...)
// 功能说明: 修改后 frame glyph 通过 CTFontGetBoundingRectsForGlyphs 拿到单字形真实边界；
// fittingBounds 对 clef 和 notehead 走不同语义，从根上避免 notehead 再被 line bounds 误导。
private func makeResolvedGlyphLine(
    glyph: MusicGlyph,
    fontSize: CGFloat,
    tintColor: StaffSceneColor,
    verticalTrimRatio: CGFloat,
    sizingMode: GlyphSizingMode
) -> ResolvedGlyphLine? {
    ...
    let opticalBounds = CTLineGetBoundsWithOptions(
        line,
        [.useOpticalBounds]
    )
    let clippedBounds = trimmedBounds(
        from: opticalBounds,
        verticalTrimRatio: verticalTrimRatio
    )
    let glyphBounds = glyphBounds(
        for: glyph,
        font: font,
        fallback: clippedBounds
    )
    let fittingBounds = fittingBounds(
        for: sizingMode,
        opticalBounds: opticalBounds,
        clippedBounds: clippedBounds,
        glyphBounds: glyphBounds
    )
    ...
}

private func glyphBounds(
    for glyph: MusicGlyph,
    font: CTFont,
    fallback: CGRect
) -> CGRect {
    let characters = Array(glyph.string.utf16)
    guard characters.count == 1 else {
        return fallback
    }

    var resolvedCharacters = characters
    var glyphs = [CGGlyph](repeating: 0, count: 1)
    guard CTFontGetGlyphsForCharacters(font, &resolvedCharacters, &glyphs, 1) else {
        return fallback
    }

    let bounds = CTFontGetBoundingRectsForGlyphs(
        font,
        .default,
        &glyphs,
        nil,
        1
    )
    guard !bounds.isNull, !bounds.isEmpty else {
        return fallback
    }

    return bounds
}

private func fittingBounds(
    for sizingMode: GlyphSizingMode,
    opticalBounds: CGRect,
    clippedBounds: CGRect,
    glyphBounds: CGRect
) -> CGRect {
    switch sizingMode {
    case .anchoredClef:
        return opticalBounds
    case .frameGlyph:
        return glyphBounds
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: drawGlyph(_:glyphItem:targetSize:centeredIn:renderHint:in:geometry:)
// 功能说明: 修改后 notehead 的对齐与 clip 都改为基于 glyphBounds；
// 这样 drawOrigin 真正围绕符头外轮廓计算，而不是围绕被放大的 CTLine 包围盒计算。
private func drawGlyph(
    _ resolvedLine: ResolvedGlyphLine,
    glyphItem: StaffGlyphItem,
    targetSize: CGSize,
    centeredIn frame: CGRect,
    renderHint: StaffGlyphRenderHint,
    in context: CGContext,
    geometry: StaffGeometry
) {
    let alignmentBounds = resolvedLine.glyphBounds
    let frameCenter = CGPoint(
        x: frame.midX,
        y: geometry.bounds.height - frame.midY
    )
    let drawOrigin = CGPoint(
        x: frameCenter.x - alignmentBounds.midX,
        y: frameCenter.y - alignmentBounds.midY
    )

    logFrameGlyphIfNeeded(
        glyphItem: glyphItem,
        targetSize: targetSize,
        frame: frame,
        drawOrigin: drawOrigin,
        resolvedLine: resolvedLine,
        geometry: geometry
    )

    drawLine(
        resolvedLine.line,
        at: drawOrigin,
        clipBounds: flippedBounds(
            for: resolvedLine.glyphBounds,
            drawOrigin: drawOrigin
        ),
        in: context,
        geometry: geometry
    )

    drawBoundsOverlayIfNeeded(
        logicalBounds(
            for: resolvedLine.glyphBounds,
            drawOrigin: drawOrigin,
            geometry: geometry
        ),
        renderHint: renderHint,
        in: context
    )
}
```

## 修改 3：补 notehead 排障日志与日志开关

### 修改前：没有符头专用诊断开关，也没有统一日志器

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数/成员: StaffConfiguration.DebugOptions
// 功能说明: 修改前 DebugOptions 只覆盖 clef 的包围框和锚点开关；
// 如果要排查 notehead，既没有显式配置入口，也没有稳定的运行态日志开关。
struct DebugOptions: Equatable, Sendable {
    var showsClefBounds: Bool
    var clefBoundsLineWidth: CGFloat
    var showsClefAnchor: Bool
    var clefAnchorLineWidth: CGFloat
    var clefAnchorCrossHalfLength: CGFloat

    static let `default` = DebugOptions()

    init(
        showsClefBounds: Bool = false,
        clefBoundsLineWidth: CGFloat = 1,
        showsClefAnchor: Bool = false,
        clefAnchorLineWidth: CGFloat = 1,
        clefAnchorCrossHalfLength: CGFloat = 4
    ) {
        self.showsClefBounds = showsClefBounds
        self.clefBoundsLineWidth = max(clefBoundsLineWidth, 0.5)
        self.showsClefAnchor = showsClefAnchor
        self.clefAnchorLineWidth = max(clefAnchorLineWidth, 0.5)
        self.clefAnchorCrossHalfLength = max(clefAnchorCrossHalfLength, 2)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift
// 函数/成员: StaffGlyphLayer.draw(in:)
// 功能说明: 修改前 glyph layer 直接拿 scene 去 renderer 绘制；
// 控制台里看不到“scene 里到底有没有 notehead”这类关键排障信息。
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
```

### 修改后：新增 `showsNoteheadDiagnostics`、统一日志器、scene / renderer 两段式日志

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数/成员: StaffConfiguration.DebugOptions.init(...)
// 功能说明: 修改后 DebugOptions 新增 showsNoteheadDiagnostics；
// 这样 notehead 排障可以由共享配置控制，而不是临时散落 print。
struct DebugOptions: Equatable, Sendable {
    var showsClefBounds: Bool
    var clefBoundsLineWidth: CGFloat
    var showsClefAnchor: Bool
    var clefAnchorLineWidth: CGFloat
    var clefAnchorCrossHalfLength: CGFloat
    var showsNoteheadDiagnostics: Bool

    static let `default` = DebugOptions()

    init(
        showsClefBounds: Bool = false,
        clefBoundsLineWidth: CGFloat = 1,
        showsClefAnchor: Bool = false,
        clefAnchorLineWidth: CGFloat = 1,
        clefAnchorCrossHalfLength: CGFloat = 4,
        showsNoteheadDiagnostics: Bool = false
    ) {
        self.showsClefBounds = showsClefBounds
        self.clefBoundsLineWidth = max(clefBoundsLineWidth, 0.5)
        self.showsClefAnchor = showsClefAnchor
        self.clefAnchorLineWidth = max(clefAnchorLineWidth, 0.5)
        self.clefAnchorCrossHalfLength = max(clefAnchorCrossHalfLength, 2)
        self.showsNoteheadDiagnostics = showsNoteheadDiagnostics
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffDebugLogger.swift
// 函数/成员: StaffDebugLogger.logOnce(key:message:) / format(...)
// 功能说明: 修改后新增统一 staff 调试日志器；
// 用 logOnce 避免同一帧或同一状态下重复刷屏，并统一格式化 point / size / rect 输出。
enum StaffDebugLogger {
    private static let lock = NSLock()
    private static var emittedKeys: Set<String> = []

    static func logOnce(
        key: String,
        message: @autoclosure () -> String
    ) {
        #if DEBUG
        lock.lock()
        let shouldEmit = emittedKeys.insert(key).inserted
        lock.unlock()

        guard shouldEmit else {
            return
        }

        print(message())
        #endif
    }

    static func format(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    static func format(_ point: CGPoint) -> String {
        "(\(format(point.x)), \(format(point.y)))"
    }

    static func format(_ size: CGSize) -> String {
        "(\(format(size.width)) x \(format(size.height)))"
    }

    static func format(_ rect: CGRect) -> String {
        "[x=\(format(rect.minX)), y=\(format(rect.minY)), w=\(format(rect.width)), h=\(format(rect.height))]"
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift
// 函数/成员: StaffGlyphLayer.draw(in:) / logNoteheadSceneIfNeeded(scene:geometry:)
// 功能说明: 修改后 glyph layer 会先打印 scene 级诊断，再交给 renderer；
// 这一步能直接证明 notehead 是否已经在 builder 阶段生成出来。
override func draw(in context: CGContext) {
    let geometry = StaffGeometry(
        configuration: configuration,
        bounds: bounds,
        orientation: configuration.canvasOrientation
    )
    let scene = sceneProvider.makeScene(geometry: geometry)
    logNoteheadSceneIfNeeded(
        scene: scene,
        geometry: geometry
    )
    guard !scene.glyphs.isEmpty || !scene.strokeItems.isEmpty else {
        return
    }
    ...
}

private func logNoteheadSceneIfNeeded(
    scene: StaffScene,
    geometry: StaffGeometry
) {
    #if DEBUG
    guard configuration.debugOptions.showsNoteheadDiagnostics else {
        return
    }

    let noteheadEntries = scene.glyphs.enumerated().compactMap { index, glyph -> String? in
        guard glyph.symbolID.isNotehead else {
            return nil
        }

        guard case let .frame(frame) = glyph.placement else {
            return "#\(index):\(glyph.symbolID.debugName):non-frame"
        }

        return "#\(index):\(glyph.symbolID.debugName):frame=\(StaffDebugLogger.format(frame))"
    }

    StaffDebugLogger.logOnce(
        key: ...,
        message: """
        [StaffDebug][Scene] clef=\(configuration.clef.title) notation=\(sceneProvider.notationDisplayOptions.debugSummary) drawingRect=\(StaffDebugLogger.format(geometry.drawingRect)) glyphCount=\(scene.glyphs.count) strokeCount=\(scene.strokeItems.count) noteheads=\(noteheadEntries.isEmpty ? "none" : noteheadEntries.joined(separator: "; "))
        """
    )
    #endif
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: logFrameGlyphIfNeeded(glyphItem:targetSize:frame:drawOrigin:resolvedLine:geometry:)
// 功能说明: 修改后 renderer 级日志会把 notehead 的 frame、fontSize、glyphBounds、opticalBounds、drawOrigin 全部打出来；
// 这一步用于确认 scene 已经正确生成后，问题是否出在 renderer 的边界与排版。
private func logFrameGlyphIfNeeded(
    glyphItem: StaffGlyphItem,
    targetSize: CGSize,
    frame: CGRect,
    drawOrigin: CGPoint,
    resolvedLine: ResolvedGlyphLine,
    geometry: StaffGeometry
) {
    #if DEBUG
    guard
        geometry.configuration.debugOptions.showsNoteheadDiagnostics,
        glyphItem.symbolID.isNotehead
    else {
        return
    }

    StaffDebugLogger.logOnce(
        key: ...,
        message: """
        [StaffDebug][Renderer] symbol=\(glyphItem.symbolID.debugName) frame=\(StaffDebugLogger.format(frame)) targetSize=\(StaffDebugLogger.format(targetSize)) font=\(resolvedLine.fontPostScriptName) fontSize=\(StaffDebugLogger.format(resolvedLine.appliedFontSize)) fittingBounds=\(StaffDebugLogger.format(resolvedLine.fittingBounds)) glyphBounds=\(StaffDebugLogger.format(resolvedLine.glyphBounds)) opticalBounds=\(StaffDebugLogger.format(resolvedLine.opticalBounds)) clippedBounds=\(StaffDebugLogger.format(resolvedLine.clippedBounds)) drawOrigin=\(StaffDebugLogger.format(drawOrigin))
        """
    )
    #endif
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: staffDisplayState
// 功能说明: 修改后 iOS 默认开启 notehead diagnostics，方便直接在真机/模拟器控制台观察排障日志。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true,
            showsNoteheadDiagnostics: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: staffDisplayState
// 功能说明: 修改后 macOS 也默认开启同一套 notehead diagnostics，保持双平台排障入口一致。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true,
            showsNoteheadDiagnostics: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
)
```

## 修改 4：让 `StaffValidation` 跟随当前 `noteheadsOnly` 策略

### 修改前：验证器仍以“完整记谱元素都应该出现”为预期

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationFixture / makeFixtures() / validateSceneCounts(...) / manualChecklist(for:)
// 功能说明: 修改前 validation fixture 不知道当前显示策略；
// 它仍按完整记谱场景去要求 accidental / stem / ledger line 数量与手工回归清单。
private struct StaffValidationFixture {
    var name: String
    var configuration: StaffConfiguration
    var score: StaffScore
    var bounds: CGRect
    var expectedLedgerLineCount: Int
}

let expectedAccidentalCount = fixture.score.notes.filter {
    $0.pitch.accidental != .natural
}.count

let expectedStemCount = fixture.score.notes.filter(\.duration.showsStem).count

if actualLedgerLineCount != fixture.expectedLedgerLineCount {
    record("ledger line 数量错误，期望 \(fixture.expectedLedgerLineCount)，实际 \(actualLedgerLineCount)。")
}

var checklist = [
    "启动 App，确认五线谱除 clef 外还能看到 demo notehead、stem 和 accidental，且没有回退成 clef-only 场景。",
    "在 settings 中切换 Treble / Bass，确认同一组 demo notes 会按新 clef 重新布局，accidental 仍位于 notehead 左侧。",
    "观察包含高低音边界的音符，确认 ledger line 会随音符出现且与 notehead 对齐。",
    "调整窗口大小或设备方向，确认 note spacing 与 glyph 位置稳定更新，不出现 clefArea 与 noteArea 重叠。"
]
```

### 修改后：fixture、自动断言、手工清单一起对齐到当前运行策略

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationFixture / makeFixtures() / validate(_:) / validateSceneCounts(...) / manualChecklist(for:)
// 功能说明: 修改后 validation fixture 显式持有 notationDisplayOptions；
// 当前阶段统一走 noteheadsOnly，因此自动断言与手工清单都不再要求隐藏中的 accidental / stem / ledger line 可见。
private struct StaffValidationFixture {
    var name: String
    var configuration: StaffConfiguration
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var bounds: CGRect
    var expectedLedgerLineCount: Int
}

return [
    StaffValidationFixture(
        name: "treble-default-demo",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.defaultDemo(clef: .treble),
        notationDisplayOptions: .noteheadsOnly,
        bounds: fixtureBounds(configuration: trebleConfiguration),
        expectedLedgerLineCount: 0
    ),
    ...
]

let scene = StaffSceneProvider(
    clef: fixture.configuration.clef,
    score: fixture.score,
    notationDisplayOptions: fixture.notationDisplayOptions
).makeScene(geometry: geometry)

if fixture.notationDisplayOptions.showsAccidentals {
    validateAccidentals(
        scene: scene,
        fixture: fixture,
        record: record
    )
}

let expectedAccidentalCount = fixture.notationDisplayOptions.showsAccidentals
    ? fixture.score.notes.filter {
        $0.pitch.accidental != .natural
    }.count
    : 0

let expectedStemCount = fixture.notationDisplayOptions.showsStems
    ? fixture.score.notes.filter(\.duration.showsStem).count
    : 0

let expectedLedgerLineCount = fixture.notationDisplayOptions.showsLedgerLines
    ? fixture.expectedLedgerLineCount
    : 0

var checklist = [
    "启动 App，确认五线谱除 clef 外已经能看到 demo notehead，且没有回退成 clef-only 场景。",
    "当前阶段故意不绘制 accidental / stem / ledger line；确认界面上只看到 clef、staff line 与 notehead。",
    "在 settings 中切换 Treble / Bass，确认同一组 demo notes 会按新 clef 重新布局，notehead 的上下行关系正确。",
    "调整窗口大小或设备方向，确认 note spacing 与 glyph 位置稳定更新，不出现 clefArea 与 noteArea 重叠。"
]
```

## 运行期排障结论

- `scene` 日志已经证明 `notehead` 本来就在共享层正确生成，不是 `StaffSceneBuilder` 丢了符头。
- `renderer` 日志进一步证明：`noteheadBlack` 的目标 frame 只有 `19.14 x 13.20`，但旧逻辑参考的 `opticalBounds` 高度会膨胀到 `212.47`；这就是符头被挤没的根因。
- 修复后 renderer 改用 `glyphBounds` 和更大的 `fontSize` 去适配 frame，因此符头恢复可见。

```bash
# 文件路径: iOS 运行时控制台输出（非仓库文件）
# 函数/成员: [StaffDebug][Scene] / [StaffDebug][Renderer]
# 功能说明: 修改后日志直接证明 scene 中已有 8 个 notehead，且 renderer 已经按 glyphBounds 而不是 line optical bounds 拟合 notehead。
[StaffDebug][Scene] clef=Treble notation=accidentals=false stems=false ledgerLines=false drawingRect=[x=35.20, y=32.40, w=369.60, h=115.20] glyphCount=9 strokeCount=0 noteheads=#1:noteheadBlack:frame=[x=168.48, y=95.40, w=19.14, h=13.20]; #2:noteheadBlack:frame=[x=197.59, y=89.40, w=19.14, h=13.20]; #3:noteheadBlack:frame=[x=226.70, y=83.40, w=19.14, h=13.20]; #4:noteheadHalf:frame=[x=255.81, y=71.40, w=19.14, h=13.20]; #5:noteheadBlack:frame=[x=284.93, y=65.40, w=19.14, h=13.20]; #6:noteheadBlack:frame=[x=314.04, y=59.40, w=19.14, h=13.20]; #7:noteheadHalf:frame=[x=343.15, y=53.40, w=19.14, h=13.20]; #8:noteheadWhole:frame=[x=372.26, y=47.40, w=19.14, h=13.20]
[StaffDebug][Renderer] symbol=noteheadBlack frame=[x=168.48, y=95.40, w=19.14, h=13.20] targetSize=(19.14 x 13.20) font=Bravura fontSize=52.80 fittingBounds=[x=0.00, y=-6.60, w=15.58, h=13.20] glyphBounds=[x=0.00, y=-6.60, w=15.58, h=13.20] opticalBounds=[x=0.00, y=-106.23, w=15.58, h=212.47] clippedBounds=[x=0.00, y=-106.23, w=15.58, h=212.47] drawOrigin=(170.26, 78.00)
[StaffDebug][Renderer] symbol=noteheadWhole frame=[x=372.26, y=47.40, w=19.14, h=13.20] targetSize=(19.14 x 13.20) font=Bravura fontSize=45.36 fittingBounds=[x=0.00, y=-5.67, w=19.14, h=11.34] glyphBounds=[x=0.00, y=-5.67, w=19.14, h=11.34] opticalBounds=[x=0.00, y=-91.26, w=19.14, h=182.51] clippedBounds=[x=0.00, y=-91.26, w=19.14, h=182.51] drawOrigin=(372.26, 126.00)
```

## 修改结果说明

- 当前运行态故意退回到 `noteheadsOnly`，这是为了先把“scene 有没有生成符头”和“renderer 有没有把符头画出来”两件事从复杂记谱元素里剥离出来。
- 这次真正让符头重新出现的关键改动不在 builder，而在 renderer：
- 以前是 `CTLine optical/clipped bounds -> shrink-to-fit -> 对齐/clip`
- 现在是 `CTFont glyphBounds -> frameGlyph fit -> glyphBounds 对齐/clip`
- `StaffDebugLogger + Scene/Renderer 日志` 只是帮助确认根因，不是让符头显示出来的主因。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
- `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffDebugLogger.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
- `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

2. 执行以下静态类型校验通过：

```bash
# 文件路径: 项目根目录（系统命令）
# 函数/成员: xcrun swiftc -typecheck
# 功能说明: 修改后对 Shared/Fretboard、Shared/Controls、Shared/Staff 与 iOS/macOS 入口做静态类型校验，确认 notehead 排障改动可编译。
xcrun swiftc -typecheck \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  NoteMaster_Ver_1/Shared/Controls/*.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift \
  NoteMaster_Ver_1/Platform/iOS/Controls/*.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift \
  NoteMaster_Ver_1/Platform/macOS/Controls/*.swift
```

3. 执行共享层命令行验证通过：

```bash
# 文件路径: 项目根目录（系统命令）
# 函数/成员: StaffValidationRunner.run(platform: .commandLine)
# 功能说明: 修改后按当前 noteheadsOnly 策略运行共享层 fixture 验证，确认 4 组 fixture 仍然全部通过。
[StaffValidation][commandLine] automated=PASS fixtures=4
通过夹具: treble-default-demo, bass-ascending-reference, treble-ledger-both-sides, bass-ledger-both-sides
自动化问题:
- 无
手工回归清单:
1. 启动 App，确认五线谱除 clef 外已经能看到 demo notehead，且没有回退成 clef-only 场景。
2. 当前阶段故意不绘制 accidental / stem / ledger line；确认界面上只看到 clef、staff line 与 notehead。
3. 在 settings 中切换 Treble / Bass，确认同一组 demo notes 会按新 clef 重新布局，notehead 的上下行关系正确。
4. 调整窗口大小或设备方向，确认 note spacing 与 glyph 位置稳定更新，不出现 clefArea 与 noteArea 重叠。
5. 命令行只覆盖共享层 scene fixture，不覆盖 iOS/macOS 运行时渲染与交互。
```

4. 当前仍未恢复的能力：
- 运行态仍然故意不绘制 `accidental / stem / ledger line`
- 当前仍处在“先确认 notehead 基本显示正确”的排障阶段，后续恢复完整记谱时需要再把显示策略切回 `fullNotation`

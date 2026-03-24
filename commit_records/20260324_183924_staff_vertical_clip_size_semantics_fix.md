20260324_183924_staff_vertical_clip_size_semantics_fix

# Staff Vertical Clip 大小语义修正记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift`

## 修改前

### renderer 把 `Vertical Clip` 同时当成“裁切框”和“缩放拟合框”

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：ResolvedGlyphLine, resolvedGlyphLine(for:targetSize:tintColor:verticalTrimRatio:), makeResolvedGlyphLine(glyph:fontSize:tintColor:verticalTrimRatio:)
// 功能说明：修改前 `effectiveBounds` 同时承担“可见裁切窗口”和“glyph fit 尺寸基准”两种职责；
// 一旦 vertical trim 把 bounds 裁小，`fitScale` 就会按更小的高度重新放大字体，导致 clef 变大。
private struct ResolvedGlyphLine {
    var line: CTLine
    var opticalBounds: CGRect
    var effectiveBounds: CGRect
}

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

    let widthScale = targetSize.width / max(resolved.effectiveBounds.width, 1)
    let heightScale = targetSize.height / max(resolved.effectiveBounds.height, 1)
    let fitScale = min(widthScale, heightScale)

    if fitScale.isFinite, fitScale > 0, abs(fitScale - 1) > 0.0001 {
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
        !resolved.effectiveBounds.isNull,
        !resolved.effectiveBounds.isEmpty
    else {
        return nil
    }

    return resolved
}

private func makeResolvedGlyphLine(
    glyph: MusicGlyph,
    fontSize: CGFloat,
    tintColor: StaffSceneColor,
    verticalTrimRatio: CGFloat
) -> ResolvedGlyphLine? {
    let line = CTLineCreateWithAttributedString(attributedText)
    let opticalBounds = CTLineGetBoundsWithOptions(
        line,
        [.useOpticalBounds]
    )
    let effectiveBounds = trimmedBounds(
        from: opticalBounds,
        verticalTrimRatio: verticalTrimRatio
    )

    return ResolvedGlyphLine(
        line: line,
        opticalBounds: opticalBounds,
        effectiveBounds: effectiveBounds
    )
}
```

### frame 布局和调试框也跟着 `effectiveBounds` 走，裁切还会改变 glyph 的视觉位置

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：drawAnchoredGlyph(_:anchor:renderHint:in:geometry:), drawGlyph(_:centeredIn:renderHint:in:geometry:)
// 功能说明：修改前 anchor 绘制与 frame 绘制都直接使用 `effectiveBounds` 作为 clip 和显示框；
// 其中 frame 布局还用 `effectiveBounds.midX/midY` 参与居中，导致 vertical clip 不仅改大小，还会影响位置。
private func drawAnchoredGlyph(
    _ resolvedLine: ResolvedGlyphLine,
    anchor: ClefAnchor,
    renderHint: StaffGlyphRenderHint,
    in context: CGContext,
    geometry: StaffGeometry
) {
    drawLine(
        resolvedLine.line,
        at: drawOrigin,
        clipBounds: flippedBounds(
            for: resolvedLine.effectiveBounds,
            drawOrigin: drawOrigin
        ),
        in: context,
        geometry: geometry
    )
    drawBoundsOverlayIfNeeded(
        logicalBounds(
            for: resolvedLine.effectiveBounds,
            drawOrigin: drawOrigin,
            geometry: geometry
        ),
        renderHint: renderHint,
        in: context
    )
}

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
        x: frameCenter.x - resolvedLine.effectiveBounds.midX,
        y: frameCenter.y - resolvedLine.effectiveBounds.midY
    )

    drawLine(
        resolvedLine.line,
        at: drawOrigin,
        clipBounds: flippedBounds(
            for: resolvedLine.effectiveBounds,
            drawOrigin: drawOrigin
        ),
        in: context,
        geometry: geometry
    )
}
```

## 修改后

### renderer 明确拆分“完整布局框”和“最终裁切框”

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：ResolvedGlyphLine, resolvedGlyphLine(for:targetSize:tintColor:verticalTrimRatio:), makeResolvedGlyphLine(glyph:fontSize:tintColor:verticalTrimRatio:)
// 功能说明：修改后 `opticalBounds` 只负责 glyph 的缩放拟合与定位；
// `clippedBounds` 只负责最终可见裁切窗口，vertical clip 不再改变 clef 的大小语义。
private struct ResolvedGlyphLine {
    var line: CTLine
    // opticalBounds 参与 glyph 的缩放拟合与定位；vertical clip 不应改变这部分语义。
    var opticalBounds: CGRect
    // clippedBounds 只描述最终可见裁切窗口，用于 clip 和调试显示。
    var clippedBounds: CGRect
}

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

    // vertical clip 只影响可见窗口，不参与 glyph 的尺寸拟合；
    // 因此这里继续基于完整 opticalBounds 做 shrink-to-fit，保持和引入裁切前一致的大小语义。
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

private func makeResolvedGlyphLine(
    glyph: MusicGlyph,
    fontSize: CGFloat,
    tintColor: StaffSceneColor,
    verticalTrimRatio: CGFloat
) -> ResolvedGlyphLine? {
    let line = CTLineCreateWithAttributedString(attributedText)
    let opticalBounds = CTLineGetBoundsWithOptions(
        line,
        [.useOpticalBounds]
    )
    let clippedBounds = trimmedBounds(
        from: opticalBounds,
        verticalTrimRatio: verticalTrimRatio
    )

    return ResolvedGlyphLine(
        line: line,
        opticalBounds: opticalBounds,
        clippedBounds: clippedBounds
    )
}
```

### 裁切框只用于 clip 和调试显示，布局与居中继续按完整 `opticalBounds`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：drawAnchoredGlyph(_:anchor:renderHint:in:geometry:), drawGlyph(_:centeredIn:renderHint:in:geometry:)
// 功能说明：修改后 anchor / frame 的定位语义恢复稳定：
// anchor 对齐继续使用完整 optical bounds，frame 居中也回到完整 optical bounds；
// `clippedBounds` 只用于真实裁切和调试红框显示，不再把 glyph 放大或挤偏。
private func drawAnchoredGlyph(
    _ resolvedLine: ResolvedGlyphLine,
    anchor: ClefAnchor,
    renderHint: StaffGlyphRenderHint,
    in context: CGContext,
    geometry: StaffGeometry
) {
    let anchorOffset = CGPoint(
        x: resolvedLine.opticalBounds.minX + (resolvedLine.opticalBounds.width * anchorMetrics.xRatio),
        y: resolvedLine.opticalBounds.minY + (resolvedLine.opticalBounds.height * anchorMetrics.yRatio)
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
    drawBoundsOverlayIfNeeded(
        logicalBounds(
            for: resolvedLine.clippedBounds,
            drawOrigin: drawOrigin,
            geometry: geometry
        ),
        renderHint: renderHint,
        in: context
    )
}

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
    // frame 布局继续按完整 opticalBounds 居中，避免 vertical clip 改变 glyph 的视觉尺寸和位置。
    let drawOrigin = CGPoint(
        x: frameCenter.x - resolvedLine.opticalBounds.midX,
        y: frameCenter.y - resolvedLine.opticalBounds.midY
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
    drawBoundsOverlayIfNeeded(
        logicalBounds(
            for: resolvedLine.clippedBounds,
            drawOrigin: drawOrigin,
            geometry: geometry
        ),
        renderHint: renderHint,
        in: context
    )
}
```

## 结果说明

- `Vertical Clip` 现在只影响 clef 的可见裁切窗口
- `Vertical Clip` 不再参与 `fitScale` 计算，因此不会再把 clef 放大
- `clefScale` 重新成为唯一的大小控制参数
- frame 居中和 anchor 对齐继续基于完整 `opticalBounds`，不会因裁切而漂移

## 验证情况

- `ReadLints` 检查 `CoreTextMusicGlyphRenderer.swift`，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

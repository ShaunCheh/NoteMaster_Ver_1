//
//  CoreTextMusicGlyphRenderer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import Foundation
import CoreGraphics
import CoreText

struct CoreTextMusicGlyphRenderer: MusicGlyphRenderer {
    private struct ResolvedGlyphLine {
        var line: CTLine
        var fontPostScriptName: String
        var appliedFontSize: CGFloat
        // opticalBounds 参与 glyph 的缩放拟合与定位；vertical clip 不应改变这部分语义。
        var opticalBounds: CGRect
        // clippedBounds 只描述最终可见裁切窗口，用于 clip 和调试显示。
        var clippedBounds: CGRect
        // glyphBounds 描述单个音乐符号自身的实际轮廓边界；frame glyph 需要按这个边界做 fit。
        var glyphBounds: CGRect
        // fittingBounds 是当前 glyph 应参与尺寸拟合的边界语义。
        var fittingBounds: CGRect
    }

    private typealias AnchorMetrics = StaffClefAnchorMetrics

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

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func draw(
        glyphItem: StaffGlyphItem,
        in context: CGContext,
        geometry: StaffGeometry,
        canvasOrientation: StaffCanvasOrientation
    ) {
        guard canvasOrientation == .standard else {
            assertionFailure("CoreTextMusicGlyphRenderer currently supports top-left/down orientation only.")
            return
        }

        let musicGlyph = glyphItem.symbolID.musicGlyph
        let sizingMode = sizingMode(for: glyphItem)
        let verticalTrimRatio = verticalTrimRatio(
            for: glyphItem,
            geometry: geometry
        )
        let targetSize = targetSize(
            for: glyphItem,
            geometry: geometry
        )
        guard targetSize.width > 0, targetSize.height > 0 else {
            return
        }

        guard let resolvedLine = resolvedGlyphLine(
            for: musicGlyph,
            targetSize: targetSize,
            tintColor: glyphItem.tintColor,
            verticalTrimRatio: verticalTrimRatio,
            sizingMode: sizingMode
        ) else {
            return
        }

        switch glyphItem.placement {
        case let .anchor(anchor):
            drawAnchoredGlyph(
                resolvedLine,
                anchor: anchor,
                renderHint: glyphItem.renderHint,
                in: context,
                geometry: geometry
            )
        case let .frame(frame):
            drawGlyph(
                resolvedLine,
                glyphItem: glyphItem,
                targetSize: targetSize,
                centeredIn: frame,
                renderHint: glyphItem.renderHint,
                in: context,
                geometry: geometry
            )
        }
    }

    private func targetSize(
        for glyphItem: StaffGlyphItem,
        geometry: StaffGeometry
    ) -> CGSize {
        switch glyphItem.placement {
        case let .anchor(anchor):
            return CGSize(
                width: max(geometry.clefAreaRect.width * 0.92, 1),
                height: max(anchor.targetHeight, 1)
            )
        case let .frame(frame):
            return CGSize(
                width: max(frame.width, 1),
                height: max(frame.height, 1)
            )
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

    private func makeResolvedGlyphLine(
        glyph: MusicGlyph,
        fontSize: CGFloat,
        tintColor: StaffSceneColor,
        verticalTrimRatio: CGFloat,
        sizingMode: GlyphSizingMode
    ) -> ResolvedGlyphLine? {
        guard let font = MusicFontRegistry.font(
            for: glyph.fontFace,
            size: fontSize,
            bundle: bundle
        ) else {
            assertionFailure("Music font is not available for \(glyph.fontFace.fileName).")
            return nil
        }

        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
            NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): tintColor.cgColor
        ]
        let attributedText = NSAttributedString(
            string: glyph.string,
            attributes: attributes
        )
        let line = CTLineCreateWithAttributedString(attributedText)
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

        guard
            !opticalBounds.isNull,
            !opticalBounds.isEmpty,
            !clippedBounds.isNull,
            !clippedBounds.isEmpty,
            !glyphBounds.isNull,
            !glyphBounds.isEmpty,
            !fittingBounds.isNull,
            !fittingBounds.isEmpty
        else {
            return nil
        }

        return ResolvedGlyphLine(
            line: line,
            fontPostScriptName: CTFontCopyPostScriptName(font) as String,
            appliedFontSize: fontSize,
            opticalBounds: opticalBounds,
            clippedBounds: clippedBounds,
            glyphBounds: glyphBounds,
            fittingBounds: fittingBounds
        )
    }

    private func drawAnchoredGlyph(
        _ resolvedLine: ResolvedGlyphLine,
        anchor: ClefAnchor,
        renderHint: StaffGlyphRenderHint,
        in context: CGContext,
        geometry: StaffGeometry
    ) {
        let anchorMetrics = self.anchorMetrics(
            for: anchor.semantic,
            geometry: geometry
        )
        let anchorOffset = CGPoint(
            x: resolvedLine.opticalBounds.minX + (resolvedLine.opticalBounds.width * anchorMetrics.xRatio),
            y: resolvedLine.opticalBounds.minY + (resolvedLine.opticalBounds.height * anchorMetrics.yRatio)
        )
        let flippedAnchor = CGPoint(
            x: anchor.point.x,
            y: geometry.bounds.height - anchor.point.y
        )
        let drawOrigin = CGPoint(
            x: flippedAnchor.x - anchorOffset.x,
            y: flippedAnchor.y - anchorOffset.y
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
        drawAnchorOverlayIfNeeded(
            anchor.point,
            renderHint: renderHint,
            in: context
        )
    }

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

    private func drawLine(
        _ line: CTLine,
        at origin: CGPoint,
        clipBounds: CGRect?,
        in context: CGContext,
        geometry: StaffGeometry
    ) {
        context.saveGState()
        context.textMatrix = .identity

        // 当前共享坐标固定为左上原点、y 向下；CoreText 绘制时在 renderer 内部局部翻回 y 向上。
        context.translateBy(x: 0, y: geometry.bounds.height)
        context.scaleBy(x: 1, y: -1)
        if let clipBounds {
            context.clip(to: clipBounds)
        }
        context.textPosition = origin
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func logicalBounds(
        for bounds: CGRect,
        drawOrigin: CGPoint,
        geometry: StaffGeometry
    ) -> CGRect {
        let flippedBounds = flippedBounds(
            for: bounds,
            drawOrigin: drawOrigin
        )

        return CGRect(
            x: flippedBounds.minX,
            y: geometry.bounds.height - flippedBounds.maxY,
            width: flippedBounds.width,
            height: flippedBounds.height
        )
    }

    private func flippedBounds(
        for bounds: CGRect,
        drawOrigin: CGPoint
    ) -> CGRect {
        CGRect(
            x: drawOrigin.x + bounds.minX,
            y: drawOrigin.y + bounds.minY,
            width: bounds.width,
            height: bounds.height
        )
    }

    private func drawBoundsOverlayIfNeeded(
        _ rect: CGRect,
        renderHint: StaffGlyphRenderHint,
        in context: CGContext
    ) {
        guard
            let boundsOverlayStyle = renderHint.boundsOverlayStyle,
            !rect.isNull,
            !rect.isEmpty
        else {
            return
        }

        context.saveGState()
        context.setStrokeColor(boundsOverlayStyle.strokeColor.cgColor)
        context.setLineWidth(boundsOverlayStyle.lineWidth)
        context.stroke(rect)
        context.restoreGState()
    }

    private func drawAnchorOverlayIfNeeded(
        _ point: CGPoint,
        renderHint: StaffGlyphRenderHint,
        in context: CGContext
    ) {
        guard let anchorOverlayStyle = renderHint.anchorOverlayStyle else {
            return
        }

        context.saveGState()
        context.setStrokeColor(anchorOverlayStyle.strokeColor.cgColor)
        context.setLineWidth(anchorOverlayStyle.lineWidth)
        context.setLineCap(.round)

        context.move(to: CGPoint(
            x: point.x - anchorOverlayStyle.crossHalfLength,
            y: point.y
        ))
        context.addLine(to: CGPoint(
            x: point.x + anchorOverlayStyle.crossHalfLength,
            y: point.y
        ))
        context.move(to: CGPoint(
            x: point.x,
            y: point.y - anchorOverlayStyle.crossHalfLength
        ))
        context.addLine(to: CGPoint(
            x: point.x,
            y: point.y + anchorOverlayStyle.crossHalfLength
        ))
        context.strokePath()
        context.restoreGState()
    }

    private func anchorMetrics(
        for semantic: ClefAnchor.Semantic,
        geometry: StaffGeometry
    ) -> AnchorMetrics {
        StaffClefLayoutGuide.anchorMetrics(
            for: semantic.clef,
            downwardShiftRatio: geometry.configuration.clefAnchorLogicalDownwardShiftRatio(
                for: semantic.clef
            )
        )
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

    private func trimmedBounds(
        from bounds: CGRect,
        verticalTrimRatio: CGFloat
    ) -> CGRect {
        StaffClefLayoutGuide.trimmedBounds(
            from: bounds,
            verticalTrimRatio: verticalTrimRatio
        )
    }

    private func sizingMode(
        for glyphItem: StaffGlyphItem
    ) -> GlyphSizingMode {
        switch glyphItem.placement {
        case .anchor:
            return .anchoredClef
        case .frame:
            return .frameGlyph
        }
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

        let key = [
            "renderer",
            glyphItem.symbolID.debugName,
            StaffDebugLogger.format(frame),
            StaffDebugLogger.format(resolvedLine.fittingBounds),
            StaffDebugLogger.format(resolvedLine.appliedFontSize)
        ].joined(separator: "::")

        StaffDebugLogger.logOnce(
            key: key,
            message: """
            [StaffDebug][Renderer] symbol=\(glyphItem.symbolID.debugName) frame=\(StaffDebugLogger.format(frame)) targetSize=\(StaffDebugLogger.format(targetSize)) font=\(resolvedLine.fontPostScriptName) fontSize=\(StaffDebugLogger.format(resolvedLine.appliedFontSize)) fittingBounds=\(StaffDebugLogger.format(resolvedLine.fittingBounds)) glyphBounds=\(StaffDebugLogger.format(resolvedLine.glyphBounds)) opticalBounds=\(StaffDebugLogger.format(resolvedLine.opticalBounds)) clippedBounds=\(StaffDebugLogger.format(resolvedLine.clippedBounds)) drawOrigin=\(StaffDebugLogger.format(drawOrigin))
            """
        )
        #endif
    }
}

private extension StaffSceneColor {
    var cgColor: CGColor {
        CGColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}

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
        var bounds: CGRect
    }

    private struct AnchorMetrics {
        var xRatio: CGFloat
        var yRatio: CGFloat
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
            tintColor: glyphItem.tintColor
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
        tintColor: StaffSceneColor
    ) -> ResolvedGlyphLine? {
        let baseFontSize = max(targetSize.height, 1)

        guard var resolved = makeResolvedGlyphLine(
            glyph: glyph,
            fontSize: baseFontSize,
            tintColor: tintColor
        ) else {
            return nil
        }

        let widthScale = targetSize.width / max(resolved.bounds.width, 1)
        let heightScale = targetSize.height / max(resolved.bounds.height, 1)
        let fitScale = min(1, widthScale, heightScale)

        if fitScale < 1 {
            resolved = makeResolvedGlyphLine(
                glyph: glyph,
                fontSize: max(baseFontSize * fitScale, 1),
                tintColor: tintColor
            ) ?? resolved
        }

        guard !resolved.bounds.isNull, !resolved.bounds.isEmpty else {
            return nil
        }

        return resolved
    }

    private func makeResolvedGlyphLine(
        glyph: MusicGlyph,
        fontSize: CGFloat,
        tintColor: StaffSceneColor
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
        let bounds = CTLineGetBoundsWithOptions(
            line,
            [.useOpticalBounds]
        )

        guard !bounds.isNull, !bounds.isEmpty else {
            return nil
        }

        return ResolvedGlyphLine(
            line: line,
            bounds: bounds
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
            x: resolvedLine.bounds.minX + (resolvedLine.bounds.width * anchorMetrics.xRatio),
            y: resolvedLine.bounds.minY + (resolvedLine.bounds.height * anchorMetrics.yRatio)
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
            in: context,
            geometry: geometry
        )
        drawBoundsOverlayIfNeeded(
            logicalBounds(
                for: resolvedLine,
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
            x: frameCenter.x - resolvedLine.bounds.midX,
            y: frameCenter.y - resolvedLine.bounds.midY
        )

        drawLine(
            resolvedLine.line,
            at: drawOrigin,
            in: context,
            geometry: geometry
        )
        drawBoundsOverlayIfNeeded(
            logicalBounds(
                for: resolvedLine,
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
        in context: CGContext,
        geometry: StaffGeometry
    ) {
        context.saveGState()
        context.textMatrix = .identity

        // 当前共享坐标固定为左上原点、y 向下；CoreText 绘制时在 renderer 内部局部翻回 y 向上。
        context.translateBy(x: 0, y: geometry.bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.textPosition = origin
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func logicalBounds(
        for resolvedLine: ResolvedGlyphLine,
        drawOrigin: CGPoint,
        geometry: StaffGeometry
    ) -> CGRect {
        let flippedBounds = CGRect(
            x: drawOrigin.x + resolvedLine.bounds.minX,
            y: drawOrigin.y + resolvedLine.bounds.minY,
            width: resolvedLine.bounds.width,
            height: resolvedLine.bounds.height
        )

        return CGRect(
            x: flippedBounds.minX,
            y: geometry.bounds.height - flippedBounds.maxY,
            width: flippedBounds.width,
            height: flippedBounds.height
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
        let downwardShiftRatio = geometry.configuration.clefAnchorLogicalDownwardShiftRatio(
            for: semantic.clef
        )

        switch semantic {
        case .trebleGLine:
            // 基于 Bravura clef glyph 的 CoreText optical bounds 做经验对齐，
            // 这里额外把 glyph 内部锚点按共享逻辑语义“向下”微调配置值，以新的锚点参与对齐；
            // 注意：optical bounds 的局部坐标是 y-up，因此逻辑下移要体现在更小的 yRatio 上。
            // 后续切到 CGPath renderer 时应把这类补偿迁移到新的后端实现中。
            return AnchorMetrics(
                xRatio: 0.5,
                yRatio: 0.56 - downwardShiftRatio
            )
        case .bassFLine:
            // bass clef 的语义锚点对齐到 F line 穿过双点之间的位置，
            // 因此 xRatio 需要落在 glyph 偏右的双点区域，而不是整个 glyph 的几何中心。
            return AnchorMetrics(
                xRatio: 0.74,
                yRatio: 0.5 - downwardShiftRatio
            )
        }
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

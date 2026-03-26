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
        // opticalBounds 参与 glyph 的缩放拟合与定位；vertical clip 不应改变这部分语义。
        var opticalBounds: CGRect
        // clippedBounds 只描述最终可见裁切窗口，用于 clip 和调试显示。
        var clippedBounds: CGRect
    }

    private typealias AnchorMetrics = StaffClefAnchorMetrics

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
            verticalTrimRatio: verticalTrimRatio
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

        guard
            !opticalBounds.isNull,
            !opticalBounds.isEmpty,
            !clippedBounds.isNull,
            !clippedBounds.isEmpty
        else {
            return nil
        }

        return ResolvedGlyphLine(
            line: line,
            opticalBounds: opticalBounds,
            clippedBounds: clippedBounds
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
        // 普通 frame glyph 默认按 optical bounds 对齐；若后续某些 glyph 需要按 clipped bounds 对齐，
        // 只需切换 renderHint，不必回改 renderer 的类别判断。
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

    private func alignedBounds(
        for resolvedLine: ResolvedGlyphLine,
        renderHint: StaffGlyphRenderHint
    ) -> CGRect {
        renderHint.prefersOpticalBoundsAlignment
            ? resolvedLine.opticalBounds
            : resolvedLine.clippedBounds
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

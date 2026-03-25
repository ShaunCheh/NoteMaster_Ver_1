//
//  FretboardLabelsLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics
import CoreText
import QuartzCore

final class FretboardLabelsLayer: CALayer {
    var configuration: FretboardConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            setNeedsDisplay()
        }
    }

    var scene: FretboardScene = .empty {
        didSet {
            guard oldValue != scene else {
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

    override init() {
        super.init()
        configureLayer()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? FretboardLabelsLayer {
            configuration = otherLayer.configuration
            scene = otherLayer.scene
            contentProvider = otherLayer.contentProvider
        }

        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

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

    private func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
        needsDisplayOnBoundsChange = true
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
        context.setFillColor(FretboardPalette.noteBadgeFill)
        context.fillEllipse(in: badgeRect)
        context.setStrokeColor(FretboardPalette.noteBadgeStroke)
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
            textColor: FretboardPalette.noteBadgeText
        )
        var lineBounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])

        guard !lineBounds.isNull, !lineBounds.isEmpty else {
            return nil
        }

        let widthScale = label.maxSize.width > 0
            ? label.maxSize.width / max(lineBounds.width, 1)
            : 1
        let heightScale = label.maxSize.height > 0
            ? label.maxSize.height / max(lineBounds.height, 1)
            : 1
        let fitScale = min(1, widthScale, heightScale)

        if fitScale < 1 {
            line = makeTextLine(
                text: label.text,
                fontSize: max(baseFontSize * fitScale, 1),
                textColor: FretboardPalette.noteBadgeText
            )
            lineBounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        }

        guard !lineBounds.isNull, !lineBounds.isEmpty else {
            return nil
        }

        return (line, lineBounds)
    }

    private func makeTextLine(
        text: String,
        fontSize: CGFloat,
        textColor: CGColor
    ) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): CTFontCreateWithName(
                "HelveticaNeue-Medium" as CFString,
                fontSize,
                nil
            ),
            NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): textColor
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        return CTLineCreateWithAttributedString(attributedText)
    }

    private func drawTextLine(
        _ line: CTLine,
        bounds lineBounds: CGRect,
        centeredAt center: CGPoint,
        in context: CGContext
    ) {
        context.saveGState()
        context.textMatrix = .identity

        let drawOrigin: CGPoint
        if context.ctm.d < 0 {
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)

            let flippedCenter = CGPoint(x: center.x, y: bounds.height - center.y)
            drawOrigin = CGPoint(
                x: flippedCenter.x - lineBounds.midX,
                y: flippedCenter.y - lineBounds.midY
            )
        } else {
            drawOrigin = CGPoint(
                x: center.x - lineBounds.midX,
                y: center.y - lineBounds.midY
            )
        }

        context.textPosition = drawOrigin
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

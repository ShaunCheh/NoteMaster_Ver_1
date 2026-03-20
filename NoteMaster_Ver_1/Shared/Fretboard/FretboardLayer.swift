//
//  FretboardLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

import Foundation
import CoreGraphics
import CoreText
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

    // provider 只负责音名内容，marker 仍由当前 layer 固定绘制。
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

        if let otherLayer = layer as? FretboardLayer {
            configuration = otherLayer.configuration
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

    private func configureLayer() {
        contentsScale = max(contentsScale, 2)
        needsDisplayOnBoundsChange = true
        isOpaque = false
        drawsAsynchronously = false
    }

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

    private func drawNut(in context: CGContext, geometry: FretboardGeometry) {
        guard !geometry.nutRect.isNull else {
            return
        }

        context.saveGState()
        context.setFillColor(Palette.nut)
        context.fill(geometry.nutRect)
        context.restoreGState()
    }

    private func drawStrings(in context: CGContext, geometry: FretboardGeometry) {
        guard !geometry.stringLines.isEmpty else {
            return
        }

        context.saveGState()
        context.setStrokeColor(Palette.string)
        context.setLineCap(.round)

        for stringLine in geometry.stringLines {
            context.setLineWidth(max(configuration.layoutMetrics.stringLineWidth, 1))
            context.move(to: CGPoint(x: geometry.drawingRect.minX, y: stringLine.y))
            context.addLine(to: CGPoint(x: geometry.drawingRect.maxX, y: stringLine.y))
            context.strokePath()
        }

        context.restoreGState()
    }

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

            drawTextLine(
                resolvedText.line,
                bounds: resolvedText.bounds,
                centeredAt: label.center,
                in: context
            )
        }
    }

    private func drawDisplayBorder(in context: CGContext, geometry: FretboardGeometry) {
        let path = displayPath(for: geometry)

        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(Palette.displayBorder)
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()
    }

    private func displayPath(for geometry: FretboardGeometry) -> CGPath {
        let cornerRadius = min(geometry.drawingRect.height, geometry.displaySlotWidth) * 0.12
        return CGPath(
            roundedRect: geometry.drawingRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
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
                textColor: textColor
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

private enum Palette {
    static let openStringArea = makeColor(0.93, 0.91, 0.87)
    static let fretboardWood = makeColor(0.42, 0.29, 0.19)
    static let fretMetal = makeColor(0.86, 0.86, 0.88)
    static let nut = makeColor(0.15, 0.15, 0.16)
    static let string = makeColor(0.96, 0.96, 0.97, 0.94)
    static let markerFill = makeColor(0.97, 0.95, 0.90)
    static let displayBorder = makeColor(0.22, 0.18, 0.14, 0.28)
    static let noteLabelTextOnFretboard = makeColor(0.98, 0.97, 0.95)
    static let noteLabelTextOnOpenString = makeColor(0.20, 0.16, 0.12)

    private static func makeColor(
        _ red: CGFloat,
        _ green: CGFloat,
        _ blue: CGFloat,
        _ alpha: CGFloat = 1
    ) -> CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

//
//  PianoRowLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics
import CoreText
import Foundation
import QuartzCore

struct PianoRowRenderState: Equatable, Sendable {
    static let empty = PianoRowRenderState(
        referenceNote: nil,
        previewedNotes: [],
        activeButtonDirection: nil,
        isButtonTrackingInside: false,
        isScaleActive: false
    )

    var referenceNote: NotePitch?
    var previewedNotes: Set<NotePitch>
    var activeButtonDirection: PianoStepDirection?
    var isButtonTrackingInside: Bool
    var isScaleActive: Bool
}

final class PianoRowLayer: CALayer {
    var configuration: PianoConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            setNeedsDisplay()
        }
    }

    var scene: PianoScene.RowScene = .empty {
        didSet {
            guard oldValue != scene else {
                return
            }

            setNeedsDisplay()
        }
    }

    var renderState: PianoRowRenderState = .empty {
        didSet {
            guard oldValue != renderState else {
                return
            }

            setNeedsDisplay()
        }
    }

    var contextNormalizationMode: PianoContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            setNeedsDisplay()
        }
    }

    override init() {
        super.init()
        configureLayer()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? PianoRowLayer {
            configuration = otherLayer.configuration
            scene = otherLayer.scene
            renderState = otherLayer.renderState
            contextNormalizationMode = otherLayer.contextNormalizationMode
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
            !scene.frame.isNull,
            !bounds.isEmpty
        else {
            return
        }

        context.saveGState()
        applyContextNormalizationIfNeeded(in: context)
        drawRowBackground(in: context)
        drawControlStrip(in: context)
        drawKeys(in: context)
        drawSeparatorsAndBorder(in: context)
        context.restoreGState()
    }
}

private extension PianoRowLayer {
    func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
        needsDisplayOnBoundsChange = true
    }

    func applyContextNormalizationIfNeeded(in context: CGContext) {
        contextNormalizationMode.applyIfNeeded(
            to: context,
            in: bounds
        )
    }

    func drawRowBackground(in context: CGContext) {
        context.saveGState()
        context.setFillColor(PianoLayerPalette.rowBackground)
        context.fill(bounds)
        context.restoreGState()
    }

    func drawControlStrip(in context: CGContext) {
        drawButtonStripBackground(in: context)

        drawButton(
            direction: .left,
            rect: scene.buttonLeftRect,
            in: context
        )
        drawButton(
            direction: .right,
            rect: scene.buttonRightRect,
            in: context
        )
        drawScaleArea(in: context)
    }

    func drawButtonStripBackground(in context: CGContext) {
        guard !scene.buttonStripRect.isNull, !scene.buttonStripRect.isEmpty else {
            return
        }

        context.saveGState()
        context.setFillColor(PianoLayerPalette.controlStripFill)
        context.fill(scene.buttonStripRect)
        context.restoreGState()
    }

    func drawButton(
        direction: PianoStepDirection,
        rect: CGRect,
        in context: CGContext
    ) {
        guard !rect.isNull, !rect.isEmpty else {
            return
        }

        let isActiveButton = renderState.activeButtonDirection == direction
        let fillColor: CGColor
        let strokeColor: CGColor
        let arrowColor: CGColor

        if isActiveButton, renderState.isButtonTrackingInside {
            fillColor = PianoLayerPalette.buttonPressedFill
            strokeColor = PianoLayerPalette.buttonPressedStroke
            arrowColor = PianoLayerPalette.buttonPressedArrow
        } else if isActiveButton {
            fillColor = PianoLayerPalette.buttonHoverFill
            strokeColor = PianoLayerPalette.buttonPressedStroke
            arrowColor = PianoLayerPalette.buttonArrow
        } else {
            fillColor = PianoLayerPalette.buttonFill
            strokeColor = PianoLayerPalette.buttonStroke
            arrowColor = PianoLayerPalette.buttonArrow
        }

        context.saveGState()
        context.setFillColor(fillColor)
        context.fill(rect)
        context.setStrokeColor(strokeColor)
        context.setLineWidth(1)
        context.stroke(strokedRect(rect))
        context.restoreGState()

        drawButtonArrow(
            direction: direction,
            rect: rect,
            color: arrowColor,
            in: context
        )
    }

    func drawButtonArrow(
        direction: PianoStepDirection,
        rect: CGRect,
        color: CGColor,
        in context: CGContext
    ) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        let horizontalInset = max(rect.width * 0.28, 4)
        let verticalInset = max(rect.height * 0.24, 4)
        let path = CGMutablePath()

        switch direction {
        case .left:
            path.move(
                to: CGPoint(
                    x: rect.minX + horizontalInset,
                    y: rect.midY
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.maxX - horizontalInset,
                    y: rect.minY + verticalInset
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.maxX - horizontalInset,
                    y: rect.maxY - verticalInset
                )
            )
        case .right:
            path.move(
                to: CGPoint(
                    x: rect.maxX - horizontalInset,
                    y: rect.midY
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.minX + horizontalInset,
                    y: rect.minY + verticalInset
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.minX + horizontalInset,
                    y: rect.maxY - verticalInset
                )
            )
        }

        path.closeSubpath()

        context.saveGState()
        context.addPath(path)
        context.setFillColor(color)
        context.fillPath()
        context.restoreGState()
    }

    func drawScaleArea(in context: CGContext) {
        guard !scene.scaleRect.isNull, !scene.scaleRect.isEmpty else {
            return
        }

        let scaleFill = renderState.isScaleActive
            ? PianoLayerPalette.scaleActiveFill
            : PianoLayerPalette.scaleFill

        context.saveGState()
        context.setFillColor(scaleFill)
        context.fill(scene.scaleRect)
        context.restoreGState()

        drawScaleMarkers(in: context)
        drawReferenceLine(in: context)
        drawScaleBorder(in: context)
    }

    func drawScaleMarkers(in context: CGContext) {
        guard !scene.scaleMarkers.isEmpty else {
            return
        }

        context.saveGState()
        context.clip(to: scene.scaleRect)

        let labelCenterY = scene.scaleRect.minY + (scene.scaleRect.height * 0.3)
        let tickTopY = scene.scaleRect.minY + (scene.scaleRect.height * 0.56)
        let tickBottomY = scene.scaleRect.maxY - 2

        context.setStrokeColor(PianoLayerPalette.scaleMarkerLine)
        context.setLineWidth(1)

        for marker in scene.scaleMarkers {
            context.move(to: CGPoint(x: marker.x, y: tickTopY))
            context.addLine(to: CGPoint(x: marker.x, y: tickBottomY))
        }

        context.strokePath()

        let fontSize = max(
            min(scene.scaleRect.height * 0.34, configuration.resolvedWhiteKeyWidth * 0.24),
            8
        )
        let maxLabelSize = CGSize(
            width: max(configuration.resolvedWhiteKeyWidth * 0.9, 14),
            height: max(scene.scaleRect.height * 0.32, 10)
        )

        for marker in scene.scaleMarkers {
            guard let resolvedText = resolvedTextLine(
                text: marker.labelText,
                fontSize: fontSize,
                maxSize: maxLabelSize
            ) else {
                continue
            }

            drawTextLine(
                resolvedText.line,
                bounds: resolvedText.bounds,
                centeredAt: CGPoint(x: marker.x, y: labelCenterY),
                in: context
            )
        }

        context.restoreGState()
    }

    func drawReferenceLine(in context: CGContext) {
        guard
            let referenceNote = renderState.referenceNote,
            let noteRect = scene.noteRect(for: referenceNote),
            scene.scaleRect.contains(
                CGPoint(x: noteRect.midX, y: scene.scaleRect.midY)
            )
        else {
            return
        }

        context.saveGState()
        context.setStrokeColor(PianoLayerPalette.referenceLine)
        context.setLineWidth(1.5)
        context.move(
            to: CGPoint(
                x: noteRect.midX,
                y: scene.scaleRect.minY + 1
            )
        )
        context.addLine(
            to: CGPoint(
                x: noteRect.midX,
                y: scene.scaleRect.maxY - 1
            )
        )
        context.strokePath()
        context.restoreGState()
    }

    func drawScaleBorder(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(PianoLayerPalette.scaleBorder)
        context.setLineWidth(1)
        context.stroke(strokedRect(scene.scaleRect))
        context.restoreGState()
    }

    func drawKeys(in context: CGContext) {
        guard !scene.keysRect.isNull, !scene.keysRect.isEmpty else {
            return
        }

        context.saveGState()
        context.clip(to: scene.keysRect)
        context.setFillColor(PianoLayerPalette.keysAreaBackground)
        context.fill(scene.keysRect)
        context.restoreGState()

        drawWhiteKeys(in: context)
        drawBlackKeys(in: context)
    }

    func drawWhiteKeys(in context: CGContext) {
        guard !scene.whiteKeys.isEmpty else {
            return
        }

        context.saveGState()

        for (index, whiteKey) in scene.whiteKeys.enumerated() {
            let fillRect = whiteKeyFillRect(
                for: whiteKey.rect,
                index: index,
                totalCount: scene.whiteKeys.count
            )
            let isPreviewed = renderState.previewedNotes.contains(whiteKey.note)

            switch configuration.whiteKeyStyle {
            case .outlined, .borderlessSeparatedByGaps:
                let fillColor = isPreviewed
                    ? PianoLayerPalette.previewWhiteKeyFill
                    : PianoLayerPalette.whiteKeyFill
                context.setFillColor(fillColor)
                context.fill(fillRect)

                if configuration.whiteKeyStyle == .outlined {
                    context.setStrokeColor(PianoLayerPalette.whiteKeyStroke)
                    context.setLineWidth(1)
                    context.stroke(strokedRect(whiteKey.rect))
                }
            case .skeuomorphicHighlight:
                drawSkeuomorphicWhiteKey(
                    whiteKey.rect,
                    isPreviewed: isPreviewed,
                    in: context
                )
            }
        }

        context.restoreGState()
    }

    func drawSkeuomorphicWhiteKey(
        _ rect: CGRect,
        isPreviewed: Bool,
        in context: CGContext
    ) {
        guard !rect.isEmpty else {
            return
        }

        let baseFill = isPreviewed
            ? PianoLayerPalette.previewWhiteKeyGlossBase
            : PianoLayerPalette.whiteKeyGlossBase
        let topHighlight = isPreviewed
            ? PianoLayerPalette.previewWhiteKeyGlossHighlight
            : PianoLayerPalette.whiteKeyGlossHighlight
        let midHighlight = isPreviewed
            ? PianoLayerPalette.previewWhiteKeyGlossMidHighlight
            : PianoLayerPalette.whiteKeyGlossMidHighlight
        let rightShadow = isPreviewed
            ? PianoLayerPalette.previewWhiteKeyGlossRightShadow
            : PianoLayerPalette.whiteKeyGlossRightShadow
        let bottomShadow = isPreviewed
            ? PianoLayerPalette.previewWhiteKeyGlossBottomShadow
            : PianoLayerPalette.whiteKeyGlossBottomShadow
        let strokeColor = isPreviewed
            ? PianoLayerPalette.previewWhiteKeyGlossStroke
            : PianoLayerPalette.whiteKeyGlossStroke

        context.setFillColor(baseFill)
        context.fill(rect)

        let topBandHeight = min(max(rect.height * 0.24, 2), rect.height)
        if topBandHeight > 0 {
            context.setFillColor(topHighlight)
            context.fill(
                CGRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: rect.width,
                    height: topBandHeight
                )
            )
        }

        let midBandHeight = min(max(rect.height * 0.16, 1), rect.height)
        if midBandHeight > 0 {
            context.setFillColor(midHighlight)
            context.fill(
                CGRect(
                    x: rect.minX + 1,
                    y: rect.minY + topBandHeight,
                    width: max(rect.width - 2, 0),
                    height: min(midBandHeight, max(rect.height - topBandHeight, 0))
                )
            )
        }

        let leftHighlightWidth = min(max(rect.width * 0.06, 1), rect.width)
        context.setFillColor(PianoLayerPalette.whiteKeyGlossEdgeHighlight)
        context.fill(
            CGRect(
                x: rect.minX,
                y: rect.minY,
                width: leftHighlightWidth,
                height: rect.height
            )
        )

        let rightShadowWidth = min(max(rect.width * 0.08, 1), rect.width)
        context.setFillColor(rightShadow)
        context.fill(
            CGRect(
                x: rect.maxX - rightShadowWidth,
                y: rect.minY,
                width: rightShadowWidth,
                height: rect.height
            )
        )

        let bottomShadowHeight = min(max(rect.height * 0.12, 1.5), rect.height)
        context.setFillColor(bottomShadow)
        context.fill(
            CGRect(
                x: rect.minX,
                y: rect.maxY - bottomShadowHeight,
                width: rect.width,
                height: bottomShadowHeight
            )
        )

        context.setStrokeColor(strokeColor)
        context.setLineWidth(1)
        context.stroke(strokedRect(rect))

        let innerRect = rect.insetBy(dx: 1, dy: 1)
        if !innerRect.isEmpty {
            context.setStrokeColor(PianoLayerPalette.whiteKeyGlossInnerHighlight)
            context.setLineWidth(1)
            context.move(
                to: CGPoint(
                    x: innerRect.minX,
                    y: innerRect.minY + 0.5
                )
            )
            context.addLine(
                to: CGPoint(
                    x: innerRect.maxX,
                    y: innerRect.minY + 0.5
                )
            )
            context.move(
                to: CGPoint(
                    x: innerRect.minX + 0.5,
                    y: innerRect.minY
                )
            )
            context.addLine(
                to: CGPoint(
                    x: innerRect.minX + 0.5,
                    y: innerRect.maxY
                )
            )
            context.strokePath()
        }
    }

    func whiteKeyFillRect(
        for rect: CGRect,
        index: Int,
        totalCount: Int
    ) -> CGRect {
        switch configuration.whiteKeyStyle {
        case .outlined, .skeuomorphicHighlight:
            return rect
        case .borderlessSeparatedByGaps:
            guard totalCount > 1, !rect.isEmpty else {
                return rect
            }

            let gapWidth = min(1, rect.width)
            let leftInset = index == 0 ? 0 : gapWidth * 0.5
            let rightInset = index == totalCount - 1 ? 0 : gapWidth * 0.5
            return CGRect(
                x: rect.minX + leftInset,
                y: rect.minY,
                width: max(rect.width - leftInset - rightInset, 0),
                height: rect.height
            )
        }
    }

    func drawBlackKeys(in context: CGContext) {
        guard !scene.blackKeys.isEmpty else {
            return
        }

        context.saveGState()

        for blackKey in scene.blackKeys {
            let isPreviewed = renderState.previewedNotes.contains(blackKey.note)
            let fillColor = isPreviewed
                ? PianoLayerPalette.previewBlackKeyFill
                : PianoLayerPalette.blackKeyFill
            let strokeColor = isPreviewed
                ? PianoLayerPalette.previewBlackKeyStroke
                : PianoLayerPalette.blackKeyStroke
            context.setFillColor(fillColor)
            context.fill(blackKey.rect)
            context.setStrokeColor(strokeColor)
            context.setLineWidth(1)
            context.stroke(strokedRect(blackKey.rect))
        }

        context.restoreGState()
    }

    func drawSeparatorsAndBorder(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(PianoLayerPalette.separator)
        context.setLineWidth(1)

        if !scene.controlStripRect.isNull, !scene.controlStripRect.isEmpty {
            context.move(
                to: CGPoint(
                    x: bounds.minX,
                    y: scene.controlStripRect.maxY
                )
            )
            context.addLine(
                to: CGPoint(
                    x: bounds.maxX,
                    y: scene.controlStripRect.maxY
                )
            )
        }

        context.strokePath()

        context.setStrokeColor(PianoLayerPalette.rowBorder)
        context.stroke(strokedRect(bounds))
        context.restoreGState()
    }

    func resolvedTextLine(
        text: String,
        fontSize: CGFloat,
        maxSize: CGSize
    ) -> (line: CTLine, bounds: CGRect)? {
        var line = makeTextLine(
            text: text,
            fontSize: fontSize,
            textColor: PianoLayerPalette.scaleLabelText
        )
        var lineBounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])

        guard !lineBounds.isNull, !lineBounds.isEmpty else {
            return nil
        }

        let widthScale = maxSize.width > 0
            ? maxSize.width / max(lineBounds.width, 1)
            : 1
        let heightScale = maxSize.height > 0
            ? maxSize.height / max(lineBounds.height, 1)
            : 1
        let fitScale = min(1, widthScale, heightScale)

        if fitScale < 1 {
            line = makeTextLine(
                text: text,
                fontSize: max(fontSize * fitScale, 1),
                textColor: PianoLayerPalette.scaleLabelText
            )
            lineBounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        }

        guard !lineBounds.isNull, !lineBounds.isEmpty else {
            return nil
        }

        return (line, lineBounds)
    }

    func makeTextLine(
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

    func drawTextLine(
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

            let flippedCenter = CGPoint(
                x: center.x,
                y: bounds.height - center.y
            )
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

    func strokedRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX + 0.5,
            y: rect.minY + 0.5,
            width: max(rect.width - 1, 0),
            height: max(rect.height - 1, 0)
        )
    }
}

private enum PianoLayerPalette {
    static let rowBackground = color(red: 0.93, green: 0.94, blue: 0.96)
    static let controlStripFill = color(red: 0.89, green: 0.91, blue: 0.94)
    static let buttonFill = color(red: 0.84, green: 0.86, blue: 0.90)
    static let buttonHoverFill = color(red: 0.76, green: 0.83, blue: 0.97)
    static let buttonPressedFill = color(red: 0.29, green: 0.53, blue: 0.96)
    static let buttonStroke = color(red: 0.58, green: 0.61, blue: 0.68)
    static let buttonPressedStroke = color(red: 0.16, green: 0.37, blue: 0.81)
    static let buttonArrow = color(red: 0.23, green: 0.26, blue: 0.31)
    static let buttonPressedArrow = color(red: 0.98, green: 0.99, blue: 1)
    static let scaleFill = color(red: 0.94, green: 0.96, blue: 0.99)
    static let scaleActiveFill = color(red: 0.84, green: 0.90, blue: 0.99)
    static let scaleBorder = color(red: 0.69, green: 0.74, blue: 0.82)
    static let scaleMarkerLine = color(red: 0.58, green: 0.63, blue: 0.73)
    static let scaleLabelText = color(red: 0.24, green: 0.27, blue: 0.32)
    static let referenceLine = color(red: 0.15, green: 0.41, blue: 0.88)
    static let keysAreaBackground = color(red: 0.79, green: 0.81, blue: 0.84)
    static let whiteKeyFill = color(red: 0.99, green: 0.99, blue: 1)
    static let whiteKeyStroke = color(red: 0.65, green: 0.68, blue: 0.74)
    static let previewWhiteKeyFill = color(red: 0.81, green: 0.89, blue: 1)
    static let whiteKeyGlossBase = color(red: 0.96, green: 0.97, blue: 0.99)
    static let whiteKeyGlossHighlight = color(red: 1, green: 1, blue: 1, alpha: 0.84)
    static let whiteKeyGlossMidHighlight = color(red: 1, green: 1, blue: 1, alpha: 0.32)
    static let whiteKeyGlossEdgeHighlight = color(red: 1, green: 1, blue: 1, alpha: 0.45)
    static let whiteKeyGlossRightShadow = color(red: 0.73, green: 0.76, blue: 0.82, alpha: 0.34)
    static let whiteKeyGlossBottomShadow = color(red: 0.62, green: 0.65, blue: 0.71, alpha: 0.22)
    static let whiteKeyGlossStroke = color(red: 0.69, green: 0.72, blue: 0.79)
    static let whiteKeyGlossInnerHighlight = color(red: 1, green: 1, blue: 1, alpha: 0.48)
    static let previewWhiteKeyGlossBase = color(red: 0.76, green: 0.86, blue: 0.99)
    static let previewWhiteKeyGlossHighlight = color(red: 0.98, green: 0.99, blue: 1, alpha: 0.62)
    static let previewWhiteKeyGlossMidHighlight = color(red: 0.98, green: 0.99, blue: 1, alpha: 0.20)
    static let previewWhiteKeyGlossRightShadow = color(red: 0.20, green: 0.38, blue: 0.70, alpha: 0.24)
    static let previewWhiteKeyGlossBottomShadow = color(red: 0.16, green: 0.32, blue: 0.60, alpha: 0.18)
    static let previewWhiteKeyGlossStroke = color(red: 0.39, green: 0.57, blue: 0.86)
    static let blackKeyFill = color(red: 0.14, green: 0.16, blue: 0.20)
    static let blackKeyStroke = color(red: 0.04, green: 0.05, blue: 0.08)
    static let previewBlackKeyFill = color(red: 0.28, green: 0.56, blue: 0.98)
    static let previewBlackKeyStroke = color(red: 0.13, green: 0.31, blue: 0.72)
    static let separator = color(red: 0.65, green: 0.69, blue: 0.76)
    static let rowBorder = color(red: 0.58, green: 0.62, blue: 0.70)

    static func color(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1
    ) -> CGColor {
        CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [red, green, blue, alpha]
        )!
    }
}

//
//  StaffLinesLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics
import QuartzCore

final class StaffLinesLayer: CALayer {
    var configuration: StaffConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            setNeedsDisplay()
        }
    }

    var strokeColorModel: StaffSceneColor = .primaryInk {
        didSet {
            guard oldValue != strokeColorModel else {
                return
            }

            setNeedsDisplay()
        }
    }

    var orientation: StaffCanvasOrientation = .standard {
        didSet {
            guard oldValue != orientation else {
                return
            }

            setNeedsDisplay()
        }
    }

    var contextNormalizationMode: StaffContextNormalizationMode = .none {
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

        if let otherLayer = layer as? StaffLinesLayer {
            configuration = otherLayer.configuration
            strokeColorModel = otherLayer.strokeColorModel
            orientation = otherLayer.orientation
            contextNormalizationMode = otherLayer.contextNormalizationMode
        }

        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    override func draw(in context: CGContext) {
        let geometry = StaffGeometry(
            configuration: configuration,
            bounds: bounds,
            orientation: orientation
        )
        let lineSegments = geometry.staffLineSegments
        guard !lineSegments.isEmpty else {
            return
        }

        context.saveGState()
        applyContextNormalizationIfNeeded(in: context)
        context.setStrokeColor(strokeColorModel.cgColor)
        context.setLineWidth(max(configuration.layoutMetrics.staffLineWidth, 1))
        context.setLineCap(.round)

        for lineSegment in lineSegments {
            context.move(to: lineSegment.start)
            context.addLine(to: lineSegment.end)
        }

        context.strokePath()
        context.restoreGState()
    }

    private func configureLayer() {
        isOpaque = false
        needsDisplayOnBoundsChange = true
        drawsAsynchronously = false
        contentsScale = max(contentsScale, 2)
    }

    private func applyContextNormalizationIfNeeded(in context: CGContext) {
        switch contextNormalizationMode {
        case .none:
            return
        case .flipYToTopLeft:
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
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

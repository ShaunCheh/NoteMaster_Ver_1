//
//  FretboardBoardLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics
import QuartzCore

final class FretboardBoardLayer: CALayer {
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

    var contextNormalizationMode: FretboardContextNormalizationMode = .none {
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

        if let otherLayer = layer as? FretboardBoardLayer {
            configuration = otherLayer.configuration
            scene = otherLayer.scene
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
        guard !scene.drawingRect.isNull else {
            return
        }

        applyContextNormalizationIfNeeded(in: context)
        drawDisplayBackground(in: context)
        drawFretboardBody(in: context)
        drawMarkers(in: context)
        drawFrets(in: context)
        drawNut(in: context)
        drawStrings(in: context)
        drawDisplayBorder(in: context)
    }

    private func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
        needsDisplayOnBoundsChange = true
    }

    private func applyContextNormalizationIfNeeded(in context: CGContext) {
        contextNormalizationMode.applyIfNeeded(
            to: context,
            in: bounds
        )
    }

    private func drawDisplayBackground(in context: CGContext) {
        let path = displayPath()

        context.saveGState()
        context.addPath(path)
        context.setFillColor(FretboardPalette.openStringArea)
        context.fillPath()
        context.restoreGState()
    }

    private func drawFretboardBody(in context: CGContext) {
        guard !scene.fretboardRect.isNull else {
            return
        }

        context.saveGState()
        context.addPath(displayPath())
        context.clip()
        context.setFillColor(FretboardPalette.fretboardWood)
        context.fill(scene.fretboardRect)
        context.restoreGState()
    }

    private func drawMarkers(in context: CGContext) {
        guard !scene.markerPlacements.isEmpty else {
            return
        }

        context.saveGState()
        context.setFillColor(FretboardPalette.markerFill)

        for marker in scene.markerPlacements {
            for center in marker.centers {
                let markerRect = CGRect(
                    x: center.x - (marker.diameter / 2),
                    y: center.y - (marker.diameter / 2),
                    width: marker.diameter,
                    height: marker.diameter
                )
                context.fillEllipse(in: markerRect)
            }
        }

        context.restoreGState()
    }

    private func drawFrets(in context: CGContext) {
        guard !scene.fretSegments.isEmpty else {
            return
        }

        context.saveGState()
        context.setStrokeColor(FretboardPalette.fretMetal)
        context.setLineWidth(max(configuration.layoutMetrics.fretLineWidth, 1))
        context.setLineCap(.butt)

        for fretSegment in scene.fretSegments {
            context.move(to: fretSegment.start)
            context.addLine(to: fretSegment.end)
        }

        context.strokePath()
        context.restoreGState()
    }

    private func drawNut(in context: CGContext) {
        guard !scene.nutRect.isNull else {
            return
        }

        context.saveGState()
        context.setFillColor(FretboardPalette.nut)
        context.fill(scene.nutRect)
        context.restoreGState()
    }

    private func drawStrings(in context: CGContext) {
        guard !scene.stringSegments.isEmpty else {
            return
        }

        context.saveGState()
        context.setStrokeColor(FretboardPalette.string)
        context.setLineCap(.round)
        context.setLineWidth(max(configuration.layoutMetrics.stringLineWidth, 1))

        for stringSegment in scene.stringSegments {
            context.move(to: stringSegment.start)
            context.addLine(to: stringSegment.end)
        }

        context.strokePath()
        context.restoreGState()
    }

    private func drawDisplayBorder(in context: CGContext) {
        let path = displayPath()

        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(FretboardPalette.displayBorder)
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()
    }

    private func displayPath() -> CGPath {
        let slotReference = max(
            min(scene.openStringRect.width, scene.openStringRect.height),
            0
        )
        let cornerRadiusReference = slotReference > 0
            ? slotReference
            : min(scene.drawingRect.width, scene.drawingRect.height)
        let cornerRadius = cornerRadiusReference * 0.12

        return CGPath(
            roundedRect: scene.drawingRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }
}

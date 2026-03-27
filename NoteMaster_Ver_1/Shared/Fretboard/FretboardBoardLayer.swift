//
//  FretboardBoardLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics
import QuartzCore

final class FretboardBoardLayer: CALayer {
    #if DEBUG && os(macOS)
    private var lastMacOSVerticalDrawDiagnosticSignature: String?
    #endif

    var configuration: FretboardConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            #if DEBUG && os(macOS)
            lastMacOSVerticalDrawDiagnosticSignature = nil
            #endif
            setNeedsDisplay()
        }
    }

    var scene: FretboardScene = .empty {
        didSet {
            guard oldValue != scene else {
                return
            }

            #if DEBUG && os(macOS)
            lastMacOSVerticalDrawDiagnosticSignature = nil
            #endif
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

        logMacOSVerticalDrawDiagnosticIfNeeded(context: context)
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

    private func logMacOSVerticalDrawDiagnosticIfNeeded(context: CGContext) {
        #if DEBUG && os(macOS)
        guard configuration.displayMode == .vertical else {
            return
        }

        let openStringCellMidY = scene.cellFrame(stringIndex: 0, fret: 0)?.midY ?? .nan
        let maxFretCellMidY = scene.cellFrame(
            stringIndex: 0,
            fret: configuration.maxFret
        )?.midY ?? .nan
        let ctm = context.ctm
        let signature = [
            bounds.debugDescription,
            scene.drawingRect.debugDescription,
            "\(isGeometryFlipped)",
            "\(ctm.a)",
            "\(ctm.b)",
            "\(ctm.c)",
            "\(ctm.d)",
            "\(ctm.tx)",
            "\(ctm.ty)",
            "\(openStringCellMidY)",
            "\(maxFretCellMidY)"
        ].joined(separator: "|")
        guard signature != lastMacOSVerticalDrawDiagnosticSignature else {
            return
        }

        lastMacOSVerticalDrawDiagnosticSignature = signature
        let contextOrientation = ctm.d < 0
            ? "CTM已翻转为top-left"
            : "CTM仍是bottom-left"
        let likelyCause = ctm.d > 0 && openStringCellMidY < maxFretCellMidY
            ? "scene 按 top-left 语义把低品放在更小的 y，但 macOS draw context 没翻转，所以视觉会变成下空弦上高品"
            : "需要继续结合 view/layer 日志确认"
        print(
            "[VerticalFretboard][macOS][draw] layer.isGeometryFlipped=\(isGeometryFlipped) bounds=\(bounds.debugDescription) drawingRect=\(scene.drawingRect.debugDescription) ctm=(a:\(ctm.a), b:\(ctm.b), c:\(ctm.c), d:\(ctm.d), tx:\(ctm.tx), ty:\(ctm.ty)) openStringMidY=\(openStringCellMidY) maxFretMidY=\(maxFretCellMidY) context=\(contextOrientation) inference=\(likelyCause)"
        )
        #endif
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

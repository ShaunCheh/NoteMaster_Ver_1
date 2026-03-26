//
//  StaffGlyphLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import Foundation
import CoreGraphics
import QuartzCore

// StaffGlyphLayer 只消费 renderer 协议，不直接依赖具体 CoreText 细节。
final class StaffGlyphLayer: CALayer {
    var configuration: StaffConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            setNeedsDisplay()
        }
    }

    var sceneProvider: StaffSceneProvider = .init() {
        didSet {
            guard oldValue != sceneProvider else {
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

    var resourceBundle: Bundle = .main {
        didSet {
            guard oldValue.bundleURL != resourceBundle.bundleURL else {
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

        if let otherLayer = layer as? StaffGlyphLayer {
            configuration = otherLayer.configuration
            sceneProvider = otherLayer.sceneProvider
            contextNormalizationMode = otherLayer.contextNormalizationMode
            resourceBundle = otherLayer.resourceBundle
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
            orientation: configuration.canvasOrientation
        )
        let scene = sceneProvider.makeScene(geometry: geometry)
        logNoteheadSceneIfNeeded(
            scene: scene,
            geometry: geometry
        )
        guard !scene.glyphs.isEmpty || !scene.strokeItems.isEmpty else {
            return
        }

        let renderer = MusicGlyphRendererFactory.makeRenderer(
            renderMode: configuration.renderMode,
            bundle: resourceBundle
        )

        context.saveGState()
        applyContextNormalizationIfNeeded(in: context)

        drawStrokeItems(scene.strokeItems, in: context)

        for glyph in scene.glyphs {
            renderer.draw(
                glyphItem: glyph,
                in: context,
                geometry: geometry,
                canvasOrientation: geometry.orientation
            )
        }

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

    private func drawStrokeItems(
        _ strokeItems: [StaffStrokeItem],
        in context: CGContext
    ) {
        for strokeItem in strokeItems {
            context.saveGState()
            context.setStrokeColor(strokeItem.style.strokeColor.cgColor)
            context.setLineWidth(strokeItem.style.lineWidth)
            context.setLineCap(strokeItem.style.lineCap.cgLineCap)
            context.move(to: strokeItem.start)
            context.addLine(to: strokeItem.end)
            context.strokePath()
            context.restoreGState()
        }
    }

    private func logNoteheadSceneIfNeeded(
        scene: StaffScene,
        geometry: StaffGeometry
    ) {
        #if DEBUG
        guard configuration.debugOptions.showsNoteheadDiagnostics else {
            return
        }

        let noteheadEntries = scene.glyphs.enumerated().compactMap { index, glyph -> String? in
            guard glyph.symbolID.isNotehead else {
                return nil
            }

            guard case let .frame(frame) = glyph.placement else {
                return "#\(index):\(glyph.symbolID.debugName):non-frame"
            }

            return "#\(index):\(glyph.symbolID.debugName):frame=\(StaffDebugLogger.format(frame))"
        }
        let key = [
            "scene",
            configuration.clef.title,
            sceneProvider.notationDisplayOptions.debugSummary,
            StaffDebugLogger.format(bounds),
            noteheadEntries.joined(separator: "|"),
            "strokeCount=\(scene.strokeItems.count)"
        ].joined(separator: "::")

        StaffDebugLogger.logOnce(
            key: key,
            message: """
            [StaffDebug][Scene] clef=\(configuration.clef.title) notation=\(sceneProvider.notationDisplayOptions.debugSummary) drawingRect=\(StaffDebugLogger.format(geometry.drawingRect)) glyphCount=\(scene.glyphs.count) strokeCount=\(scene.strokeItems.count) noteheads=\(noteheadEntries.isEmpty ? "none" : noteheadEntries.joined(separator: "; "))
            """
        )
        #endif
    }
}

private extension StaffStrokeLineCap {
    var cgLineCap: CGLineCap {
        switch self {
        case .butt:
            return .butt
        case .round:
            return .round
        case .square:
            return .square
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

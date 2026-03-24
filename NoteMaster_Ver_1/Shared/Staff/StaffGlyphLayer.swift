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
        let glyphs = sceneProvider.makeScene(geometry: geometry).glyphs
        guard !glyphs.isEmpty else {
            return
        }

        let renderer = MusicGlyphRendererFactory.makeRenderer(
            renderMode: configuration.renderMode,
            bundle: resourceBundle
        )

        context.saveGState()
        applyContextNormalizationIfNeeded(in: context)

        for glyph in glyphs {
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
}

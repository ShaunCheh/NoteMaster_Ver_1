//
//  StaffRootLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import Foundation
import QuartzCore

enum StaffContextNormalizationMode: Equatable, Sendable {
    case none
    case flipYToTopLeft
}

final class StaffRootLayer: CALayer {
    var configuration: StaffConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            updatePresentationModel()
        }
    }

    var sceneProvider: StaffSceneProvider = .init() {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            updatePresentationModel()
        }
    }

    var contextNormalizationMode: StaffContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            applySharedLayerSettings()
        }
    }

    var resourceBundle: Bundle = .main {
        didSet {
            guard oldValue.bundleURL != resourceBundle.bundleURL else {
                return
            }

            glyphLayer.resourceBundle = resourceBundle
            glyphLayer.setNeedsDisplay()
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            guard oldValue != contentsScale else {
                return
            }

            applySharedLayerSettings()
        }
    }

    private let linesLayer = StaffLinesLayer()
    private let glyphLayer = StaffGlyphLayer()

    override init() {
        super.init()
        configureLayer()
        updatePresentationModel()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? StaffRootLayer {
            configuration = otherLayer.configuration
            sceneProvider = otherLayer.sceneProvider
            contextNormalizationMode = otherLayer.contextNormalizationMode
            resourceBundle = otherLayer.resourceBundle
        }

        configureLayer()
        updatePresentationModel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
        updatePresentationModel()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        applySharedLayerSettings()
        updatePresentationModel()
    }

    private func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
        addSublayer(linesLayer)
        addSublayer(glyphLayer)
        applySharedLayerSettings()
    }

    private func applySharedLayerSettings() {
        linesLayer.frame = bounds
        glyphLayer.frame = bounds
        linesLayer.contentsScale = contentsScale
        glyphLayer.contentsScale = contentsScale
        linesLayer.contextNormalizationMode = contextNormalizationMode
        glyphLayer.contextNormalizationMode = contextNormalizationMode
        glyphLayer.resourceBundle = resourceBundle
    }

    private func updatePresentationModel() {
        applySharedLayerSettings()

        let geometry = StaffGeometry(
            configuration: configuration,
            bounds: bounds,
            orientation: configuration.canvasOrientation
        )
        let scene = sceneProvider.makeScene(geometry: geometry)

        linesLayer.strokeWidth = configuration.layoutMetrics.staffLineWidth
        linesLayer.lineSegments = scene.lineSegments

        glyphLayer.configuration = configuration
        glyphLayer.geometry = geometry
        glyphLayer.glyphs = scene.glyphs
    }
}

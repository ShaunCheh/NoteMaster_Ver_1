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

            invalidateSublayersForCurrentState()
        }
    }

    var sceneProvider: StaffSceneProvider = .init() {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var contextNormalizationMode: StaffContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var resourceBundle: Bundle = .main {
        didSet {
            guard oldValue.bundleURL != resourceBundle.bundleURL else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            guard oldValue != contentsScale else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    private let linesLayer = StaffLinesLayer()
    private let glyphLayer = StaffGlyphLayer()

    override init() {
        super.init()
        configureLayer()
        invalidateSublayersForCurrentState()
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
        invalidateSublayersForCurrentState()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
        invalidateSublayersForCurrentState()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        refreshForCurrentBounds()
    }

    private func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
        addSublayer(linesLayer)
        addSublayer(glyphLayer)
    }

    private func synchronizeSublayerState() {
        performWithoutImplicitAnimations {
            linesLayer.frame = bounds
            linesLayer.configuration = configuration
            linesLayer.orientation = configuration.canvasOrientation
            glyphLayer.frame = bounds
            glyphLayer.configuration = configuration
            glyphLayer.sceneProvider = sceneProvider
            linesLayer.contentsScale = contentsScale
            glyphLayer.contentsScale = contentsScale
            linesLayer.contextNormalizationMode = contextNormalizationMode
            glyphLayer.contextNormalizationMode = contextNormalizationMode
            glyphLayer.resourceBundle = resourceBundle
        }
    }

    func refreshForCurrentBounds(displayImmediately: Bool = false) {
        invalidateSublayersForCurrentState(displayImmediately: displayImmediately)
    }

    private func invalidateSublayerDisplay() {
        linesLayer.setNeedsDisplay()
        glyphLayer.setNeedsDisplay()
    }

    private func invalidateSublayersForCurrentState(displayImmediately: Bool = false) {
        synchronizeSublayerState()
        invalidateSublayerDisplay()

        if displayImmediately {
            linesLayer.displayIfNeeded()
            glyphLayer.displayIfNeeded()
        }
    }

    private func performWithoutImplicitAnimations(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updates()
        CATransaction.commit()
    }
}

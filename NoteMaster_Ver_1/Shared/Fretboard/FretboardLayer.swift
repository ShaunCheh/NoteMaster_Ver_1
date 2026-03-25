//
//  FretboardLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

import Foundation
import QuartzCore

final class FretboardLayer: CALayer {
    var configuration: FretboardConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    // provider 只负责音名内容；board 与 labels 共用同一份 scene。
    var contentProvider: (any FretboardContentProviding)? {
        didSet {
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

    private let boardLayer = FretboardBoardLayer()
    private let labelsLayer = FretboardLabelsLayer()

    override init() {
        super.init()
        configureLayer()
        invalidateSublayersForCurrentState()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? FretboardLayer {
            configuration = otherLayer.configuration
            contentProvider = otherLayer.contentProvider
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

    func refreshForCurrentBounds(displayImmediately: Bool = false) {
        invalidateSublayersForCurrentState(displayImmediately: displayImmediately)
    }

    private func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
        addSublayer(boardLayer)
        addSublayer(labelsLayer)
    }

    private func synchronizeSublayerState() {
        let scene = FretboardSceneBuilder(
            configuration: configuration
        ).makeScene(bounds: bounds)

        performWithoutImplicitAnimations {
            boardLayer.frame = bounds
            labelsLayer.frame = bounds
            boardLayer.configuration = configuration
            labelsLayer.configuration = configuration
            boardLayer.scene = scene
            labelsLayer.scene = scene
            boardLayer.contentsScale = contentsScale
            labelsLayer.contentsScale = contentsScale
            labelsLayer.contentProvider = contentProvider
        }
    }

    private func invalidateSublayerDisplay() {
        boardLayer.setNeedsDisplay()
        labelsLayer.setNeedsDisplay()
    }

    private func invalidateSublayersForCurrentState(displayImmediately: Bool = false) {
        synchronizeSublayerState()
        invalidateSublayerDisplay()

        if displayImmediately {
            boardLayer.displayIfNeeded()
            labelsLayer.displayIfNeeded()
        }
    }

    private func performWithoutImplicitAnimations(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updates()
        CATransaction.commit()
    }
}

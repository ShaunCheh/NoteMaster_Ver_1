//
//  FretboardLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

import Foundation
import QuartzCore

enum FretboardContextNormalizationMode: Equatable, Sendable {
    case none
    case flipYToTopLeft

    func normalizedPoint(
        _ point: CGPoint,
        in bounds: CGRect
    ) -> CGPoint {
        switch self {
        case .none:
            return point
        case .flipYToTopLeft:
            let mirroredY = bounds.minY + bounds.maxY - point.y
            return CGPoint(x: point.x, y: mirroredY)
        }
    }

    func applyIfNeeded(
        to context: CGContext,
        in bounds: CGRect
    ) {
        switch self {
        case .none:
            return
        case .flipYToTopLeft:
            context.translateBy(x: 0, y: bounds.minY + bounds.maxY)
            context.scaleBy(x: 1, y: -1)
        }
    }
}

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

    var feedbackOverlayState: FretboardFeedbackOverlayState = .empty {
        didSet {
            guard oldValue != feedbackOverlayState else {
                return
            }

            synchronizeFeedbackOverlayState()
            feedbackLayer.setNeedsDisplay()
        }
    }

    var contextNormalizationMode: FretboardContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
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

    private let boardLayer = FretboardBoardLayer()
    private let feedbackLayer = FretboardFeedbackLayer()
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
            feedbackOverlayState = otherLayer.feedbackOverlayState
            contextNormalizationMode = otherLayer.contextNormalizationMode
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
        addSublayer(feedbackLayer)
        addSublayer(labelsLayer)
    }

    private func synchronizeSublayerState() {
        let scene = FretboardSceneBuilder(
            configuration: configuration
        ).makeScene(bounds: bounds)

        performWithoutImplicitAnimations {
            boardLayer.frame = bounds
            feedbackLayer.frame = bounds
            labelsLayer.frame = bounds
            boardLayer.configuration = configuration
            labelsLayer.configuration = configuration
            boardLayer.scene = scene
            feedbackLayer.scene = scene
            labelsLayer.scene = scene
            boardLayer.contentsScale = contentsScale
            feedbackLayer.contentsScale = contentsScale
            labelsLayer.contentsScale = contentsScale
            boardLayer.contextNormalizationMode = contextNormalizationMode
            feedbackLayer.contextNormalizationMode = contextNormalizationMode
            labelsLayer.contextNormalizationMode = contextNormalizationMode
            labelsLayer.contentProvider = contentProvider
            feedbackLayer.feedbackOverlayState = feedbackOverlayState
        }
    }

    private func synchronizeFeedbackOverlayState() {
        performWithoutImplicitAnimations {
            feedbackLayer.feedbackOverlayState = feedbackOverlayState
        }
    }

    private func invalidateSublayerDisplay() {
        boardLayer.setNeedsDisplay()
        feedbackLayer.setNeedsDisplay()
        labelsLayer.setNeedsDisplay()
    }

    private func invalidateSublayersForCurrentState(displayImmediately: Bool = false) {
        synchronizeSublayerState()
        invalidateSublayerDisplay()

        if displayImmediately {
            boardLayer.displayIfNeeded()
            feedbackLayer.displayIfNeeded()
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

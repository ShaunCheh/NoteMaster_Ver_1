//
//  PianoKeyboardLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics
import QuartzCore

enum PianoContextNormalizationMode: Equatable, Sendable {
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

    func normalizedRect(
        _ rect: CGRect,
        in bounds: CGRect
    ) -> CGRect {
        switch self {
        case .none:
            return rect
        case .flipYToTopLeft:
            guard !rect.isNull else {
                return rect
            }

            return CGRect(
                x: rect.minX,
                y: bounds.minY + bounds.maxY - rect.maxY,
                width: rect.width,
                height: rect.height
            )
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

final class PianoKeyboardLayer: CALayer {
    var configuration: PianoConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var state: PianoComponentState = .empty {
        didSet {
            guard oldValue != state else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var contextNormalizationMode: PianoContextNormalizationMode = .none {
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

    private var rowLayers: [PianoRowLayer] = []

    override init() {
        super.init()
        configureLayer()
        invalidateSublayersForCurrentState()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? PianoKeyboardLayer {
            configuration = otherLayer.configuration
            state = otherLayer.state
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
}

private extension PianoKeyboardLayer {
    func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
    }

    func synchronizeSublayerState() {
        let scene = PianoSceneBuilder(
            configuration: configuration,
            state: state
        ).makeScene(bounds: bounds)

        performWithoutImplicitAnimations {
            ensureRowLayerCount(scene.rows.count)

            for (index, absoluteRowScene) in scene.rows.enumerated() {
                let rowLayer = rowLayers[index]
                rowLayer.frame = contextNormalizationMode.normalizedRect(
                    absoluteRowScene.frame,
                    in: bounds
                )
                rowLayer.configuration = configuration
                rowLayer.scene = absoluteRowScene.localizedToRowBounds()
                rowLayer.renderState = renderState(for: absoluteRowScene.rowIndex)
                rowLayer.contextNormalizationMode = contextNormalizationMode
                rowLayer.contentsScale = contentsScale
            }
        }
    }

    func renderState(for rowIndex: Int) -> PianoRowRenderState {
        let previewedNote = state.preview?.rowIndex == rowIndex
            ? state.preview?.note
            : nil
        let referenceNote = state.rowState(at: rowIndex)?.startNote

        let activeButtonDirection: PianoStepDirection?
        let isButtonTrackingInside: Bool
        let isScaleActive: Bool

        switch state.activeInteraction {
        case let .buttonPressed(interaction):
            activeButtonDirection = interaction.rowIndex == rowIndex
                ? interaction.direction
                : nil
            isButtonTrackingInside = interaction.rowIndex == rowIndex
                ? interaction.isTrackingInsideButton
                : false
            isScaleActive = false
        case let .scaleDrag(interaction):
            activeButtonDirection = nil
            isButtonTrackingInside = false
            isScaleActive = interaction.affectedRowIndices.contains(rowIndex)
        case .keyGlissando, .none:
            activeButtonDirection = nil
            isButtonTrackingInside = false
            isScaleActive = false
        }

        return PianoRowRenderState(
            referenceNote: referenceNote,
            previewedNote: previewedNote,
            activeButtonDirection: activeButtonDirection,
            isButtonTrackingInside: isButtonTrackingInside,
            isScaleActive: isScaleActive
        )
    }

    func ensureRowLayerCount(_ count: Int) {
        while rowLayers.count < count {
            let rowLayer = PianoRowLayer()
            rowLayers.append(rowLayer)
            addSublayer(rowLayer)
        }

        while rowLayers.count > count {
            let rowLayer = rowLayers.removeLast()
            rowLayer.removeFromSuperlayer()
        }
    }

    func invalidateSublayerDisplay(displayImmediately: Bool = false) {
        for rowLayer in rowLayers {
            rowLayer.setNeedsDisplay()
            if displayImmediately {
                rowLayer.displayIfNeeded()
            }
        }
    }

    func invalidateSublayersForCurrentState(displayImmediately: Bool = false) {
        synchronizeSublayerState()
        invalidateSublayerDisplay(displayImmediately: displayImmediately)
    }

    func performWithoutImplicitAnimations(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updates()
        CATransaction.commit()
    }
}

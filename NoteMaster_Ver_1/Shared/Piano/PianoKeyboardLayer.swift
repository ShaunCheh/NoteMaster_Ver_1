//
//  PianoKeyboardLayer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics
import Foundation
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
    private var presentationRowsOverride: [PianoRowState]?
    private var activeRowsTransitionAnimation: PianoActiveRowsTransitionAnimation?
    private var rowsTransitionTimer: Timer?

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

    deinit {
        invalidateRowsTransitionTimer()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        refreshForCurrentBounds()
    }

    func refreshForCurrentBounds(displayImmediately: Bool = false) {
        invalidateSublayersForCurrentState(displayImmediately: displayImmediately)
    }

    func startRowsTransitionAnimation(
        _ plan: PianoRowsTransitionPlan,
        completion: @escaping ([PianoRowState]) -> Void
    ) {
        guard !plan.isNoOp else {
            clearRowsTransitionPresentationOverride()
            completion(plan.toRows)
            return
        }

        _ = cancelRowsTransitionAnimation(materializeCurrentFrame: false)
        activeRowsTransitionAnimation = PianoActiveRowsTransitionAnimation(
            plan: plan,
            startedAt: CACurrentMediaTime(),
            completion: completion
        )
        presentationRowsOverride = plan.fromRows
        invalidateSublayersForCurrentState()
        scheduleRowsTransitionTimer()
    }

    func startScaleSnapAnimation(
        _ plan: PianoScaleSnapAnimationPlan,
        completion: @escaping ([PianoRowState]) -> Void
    ) {
        startRowsTransitionAnimation(plan, completion: completion)
    }

    @discardableResult
    func cancelRowsTransitionAnimation(
        materializeCurrentFrame: Bool
    ) -> [PianoRowState]? {
        let materializedRows = materializeCurrentFrame
            ? materializedRowsTransitionRows()
            : nil
        invalidateRowsTransitionTimer()
        activeRowsTransitionAnimation = nil

        if let materializedRows {
            presentationRowsOverride = materializedRows
            invalidateSublayersForCurrentState()
            return materializedRows
        }

        guard presentationRowsOverride != nil else {
            return nil
        }

        presentationRowsOverride = nil
        invalidateSublayersForCurrentState()
        return nil
    }

    @discardableResult
    func cancelScaleSnapAnimation(
        materializeCurrentFrame: Bool
    ) -> [PianoRowState]? {
        cancelRowsTransitionAnimation(
            materializeCurrentFrame: materializeCurrentFrame
        )
    }

    func clearRowsTransitionPresentationOverride() {
        guard presentationRowsOverride != nil else {
            return
        }

        presentationRowsOverride = nil
        invalidateSublayersForCurrentState()
    }

    func clearScaleSnapPresentationOverride() {
        clearRowsTransitionPresentationOverride()
    }
}

private extension PianoKeyboardLayer {
    func configureLayer() {
        isOpaque = false
        drawsAsynchronously = false
    }

    func synchronizeSublayerState() {
        let displayState = resolvedRenderState()
        let scene = PianoSceneBuilder(
            configuration: configuration,
            state: displayState
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
                rowLayer.renderState = renderState(
                    for: absoluteRowScene.rowIndex,
                    state: displayState
                )
                rowLayer.contextNormalizationMode = contextNormalizationMode
                rowLayer.contentsScale = contentsScale
            }
        }
    }

    func resolvedRenderState() -> PianoComponentState {
        guard let presentationRowsOverride else {
            return state
        }

        return PianoComponentState(
            rows: presentationRowsOverride,
            activePreviews: state.activePreviews,
            activeInteractionsByPointer: state.activeInteractionsByPointer
        )
    }

    func renderState(
        for rowIndex: Int,
        state renderState: PianoComponentState
    ) -> PianoRowRenderState {
        let previewedNotes = renderState.previewedNotes(forRowIndex: rowIndex)
        let referenceNote = renderState.rowState(at: rowIndex)?.startNote

        let activeButtonDirection: PianoStepDirection?
        let isButtonTrackingInside: Bool
        let isScaleActive: Bool

        switch renderState.activeExclusiveControlInteraction {
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
            previewedNotes: previewedNotes,
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

    func materializedRowsTransitionRows() -> [PianoRowState]? {
        guard let activeRowsTransitionAnimation else {
            return nil
        }

        let duration = max(activeRowsTransitionAnimation.plan.duration, 0.001)
        let progress = CGFloat(
            (CACurrentMediaTime() - activeRowsTransitionAnimation.startedAt) / duration
        )
        return PianoPresentationMath.rows(
            for: activeRowsTransitionAnimation.plan,
            progress: progress,
            configuration: configuration
        )
    }

    func scheduleRowsTransitionTimer() {
        invalidateRowsTransitionTimer()
        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            self?.updateRowsTransitionAnimationFrame()
        }
        rowsTransitionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func invalidateRowsTransitionTimer() {
        rowsTransitionTimer?.invalidate()
        rowsTransitionTimer = nil
    }

    func updateRowsTransitionAnimationFrame() {
        guard let activeRowsTransitionAnimation else {
            invalidateRowsTransitionTimer()
            return
        }

        let duration = max(activeRowsTransitionAnimation.plan.duration, 0.001)
        let progress = CGFloat(
            (CACurrentMediaTime() - activeRowsTransitionAnimation.startedAt) / duration
        )
        presentationRowsOverride = PianoPresentationMath.rows(
            for: activeRowsTransitionAnimation.plan,
            progress: progress,
            configuration: configuration
        )
        invalidateSublayersForCurrentState()

        guard progress >= 1 else {
            return
        }

        let completion = activeRowsTransitionAnimation.completion
        let finalRows = activeRowsTransitionAnimation.plan.toRows
        self.activeRowsTransitionAnimation = nil
        invalidateRowsTransitionTimer()
        presentationRowsOverride = finalRows
        invalidateSublayersForCurrentState()
        completion(finalRows)
    }
}

private struct PianoActiveRowsTransitionAnimation {
    var plan: PianoRowsTransitionPlan
    var startedAt: TimeInterval
    var completion: ([PianoRowState]) -> Void
}

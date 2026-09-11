//
//  iOSPianoKeyboardView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

#if os(iOS)
import UIKit

final class iOSPianoKeyboardView: UIView {
    private var componentState: PianoComponentState
    private var touchSessionTracker = PianoPointerSessionTracker<ObjectIdentifier>()

    var configuration: PianoConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var rows: [PianoRowState] {
        get {
            componentState.rows
        }
        set {
            replaceRows(newValue)
        }
    }

    var preview: PianoPreviewState? {
        componentState.preview
    }

    var showsComponentBoundsOverlay = false {
        didSet {
            guard oldValue != showsComponentBoundsOverlay else {
                return
            }

            updateComponentBoundsOverlay()
        }
    }

    var onRowsChanged: (([PianoRowState]) -> Void)?
    var onPreviewStarted: ((PianoPreviewState) -> Void)?
    var onPreviewChanged: ((PianoPreviewState) -> Void)?
    var onPreviewEnded: ((PianoPreviewState) -> Void)?

    override class var layerClass: AnyClass {
        PianoKeyboardLayer.self
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: resolvedIntrinsicHeight
        )
    }

    override init(frame: CGRect) {
        configuration = .init()
        componentState = .empty
        super.init(frame: frame)
        configureView()
    }

    convenience init(
        configuration: PianoConfiguration,
        rows: [PianoRowState]
    ) {
        self.init(frame: .zero)
        self.configuration = configuration
        componentState.rows = rows
        applyBackingState()
        applyConfiguration()
    }

    required init?(coder: NSCoder) {
        configuration = .init()
        componentState = .empty
        super.init(coder: coder)
        configureView()
    }

    func interruptActiveInteraction() {
        resetActiveInteraction(emitsPreviewEnded: true)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateContentsScale()
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContentsScale()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pianoKeyboardLayer.refreshForCurrentBounds()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleRawTouchEvent(from: touches, phase: .began)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleRawTouchEvent(from: touches, phase: .moved)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleRawTouchEvent(from: touches, phase: .ended)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleRawTouchEvent(from: touches, phase: .cancelled)
        super.touchesCancelled(touches, with: event)
    }
}

private extension iOSPianoKeyboardView {
    var pianoKeyboardLayer: PianoKeyboardLayer {
        guard let pianoKeyboardLayer = layer as? PianoKeyboardLayer else {
            fatalError("Expected PianoKeyboardLayer backing layer.")
        }

        return pianoKeyboardLayer
    }

    var resolvedIntrinsicHeight: CGFloat {
        PianoLayoutMath.totalContentHeight(
            configuration: configuration,
            rowCount: componentState.rowCount
        )
    }

    func configureView() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isMultipleTouchEnabled = true
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Piano is a weighted Exercise surface and must be able to absorb
        // vertical space left by fit-content prompt surfaces.
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyBackingState()
        applyConfiguration()
    }

    func applyConfiguration() {
        cancelRowsTransitionAnimationForExternalStateChange()
        pianoKeyboardLayer.configuration = configuration
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }

    func applyBackingState() {
        pianoKeyboardLayer.state = componentState
        updateComponentBoundsOverlay()
        invalidateIntrinsicContentSize()
    }

    func updateContentsScale() {
        pianoKeyboardLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
        updateComponentBoundsOverlay()
    }

    func updateComponentBoundsOverlay() {
        pianoKeyboardLayer.borderColor = UIColor.systemGreen.cgColor
        pianoKeyboardLayer.borderWidth = showsComponentBoundsOverlay
            ? resolvedComponentBoundsOverlayLineWidth
            : 0
    }

    var resolvedComponentBoundsOverlayLineWidth: CGFloat {
        max(1 / max(pianoKeyboardLayer.contentsScale, 1), 0.5)
    }

    func replaceRows(_ newRows: [PianoRowState]) {
        // External rows are authoritative, so reapplying them must also stop any in-flight presentation animation.
        cancelRowsTransitionAnimationForExternalStateChange()

        guard componentState.rows != newRows else {
            return
        }
        let previousPreviews = componentState.orderedActivePreviews
        componentState = componentState.replacingRowsBySanitizingInputSessions(
            with: newRows
        )
        touchSessionTracker.retainSessions(
            withPointerIDs: Set(componentState.activeInteractionsByPointer.keys)
        )

        applyBackingState()
        emitPreviewEndedEvents(
            removedFrom: previousPreviews,
            nextState: componentState
        )
    }

    func handleRawTouchEvent(
        from touches: Set<UITouch>,
        phase: PianoEventPhase
    ) {
        for touch in orderedTouches(from: touches) {
            guard let rawEvent = rawEvent(for: touch, phase: phase) else {
                continue
            }
            handleRawEvent(rawEvent)
        }
    }

    func handleRawEvent(_ rawEvent: PianoRawEvent) {
        guard !bounds.isEmpty else {
            return
        }

        if rawEvent.phase == .began {
            materializeRowsTransitionAnimationForNewInteractionIfNeeded()
        }

        let geometry = PianoGeometry(
            configuration: configuration,
            state: componentState,
            bounds: bounds
        )
        let hitResult = geometry.hitTest(
            rawEvent.locationInView,
            phase: rawEvent.phase,
            pointerID: rawEvent.pointerID
        )
        let reduction = PianoInteractionReducer.reduce(
            state: componentState,
            rawEvent: rawEvent,
            hitResult: hitResult,
            configuration: configuration
        )
        applyReduction(reduction)
    }

    func resetActiveInteraction(
        emitsPreviewEnded: Bool
    ) {
        cancelRowsTransitionAnimationForExternalStateChange()
        let interruptedPreviews = componentState.orderedActivePreviews
        let hadActiveInteraction = !componentState.activeInteractionsByPointer.isEmpty
        let hadTrackedTouches = touchSessionTracker.hasActiveSessions
        guard !interruptedPreviews.isEmpty || hadActiveInteraction || hadTrackedTouches else {
            return
        }

        _ = componentState.clearInputSessions()
        touchSessionTracker.removeAllSessions()
        applyBackingState()

        if emitsPreviewEnded {
            emitSemanticEvents(
                interruptedPreviews.map(PianoSemanticEvent.previewEnded)
            )
        }
    }

    func applyReduction(_ reduction: PianoReduction) {
        guard reduction.nextState != componentState
            || !reduction.semanticEvents.isEmpty
            || reduction.presentationCommand != nil else {
            return
        }

        componentState = reduction.nextState
        touchSessionTracker.retainSessions(
            withPointerIDs: Set(componentState.activeInteractionsByPointer.keys)
        )
        applyBackingState()
        applyPresentationCommand(reduction.presentationCommand)
        emitSemanticEvents(reduction.semanticEvents)
    }

    func applyPresentationCommand(_ presentationCommand: PianoPresentationCommand?) {
        guard let rowsTransitionPlan = presentationCommand?.rowsTransitionPlan else {
            return
        }

        pianoKeyboardLayer.startRowsTransitionAnimation(rowsTransitionPlan) { [weak self] finalRows in
            self?.finalizeRowsTransitionAnimation(with: finalRows)
        }
    }

    func finalizeRowsTransitionAnimation(with finalRows: [PianoRowState]) {
        guard componentState.rows != finalRows else {
            pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
            return
        }

        componentState.rows = finalRows
        applyBackingState()
        pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
        emitSemanticEvents([.rowsChanged(finalRows)])
    }

    func cancelRowsTransitionAnimationForExternalStateChange() {
        _ = pianoKeyboardLayer.cancelRowsTransitionAnimation(
            materializeCurrentFrame: false
        )
    }

    func materializeRowsTransitionAnimationForNewInteractionIfNeeded() {
        guard let materializedRows = pianoKeyboardLayer.cancelRowsTransitionAnimation(
            materializeCurrentFrame: true
        ) else {
            return
        }

        componentState.rows = materializedRows
        applyBackingState()
        pianoKeyboardLayer.clearRowsTransitionPresentationOverride()
        emitSemanticEvents([.rowsChanged(materializedRows)])
    }

    func orderedTouches(from touches: Set<UITouch>) -> [UITouch] {
        touches.sorted { lhs, rhs in
            ObjectIdentifier(lhs).hashValue < ObjectIdentifier(rhs).hashValue
        }
    }

    func rawEvent(
        for touch: UITouch,
        phase: PianoEventPhase
    ) -> PianoRawEvent? {
        let source = ObjectIdentifier(touch)
        let locationInView = touch.location(in: self)

        switch phase {
        case .began:
            return touchSessionTracker.begin(
                source: source,
                locationInView: locationInView
            )
        case .moved:
            return touchSessionTracker.move(
                source: source,
                locationInView: locationInView
            )
        case .ended:
            return touchSessionTracker.end(
                source: source,
                locationInView: locationInView
            )
        case .cancelled:
            return touchSessionTracker.cancel(
                source: source,
                locationInView: locationInView
            )
        }
    }

    func emitPreviewEndedEvents(
        removedFrom previousPreviews: [PianoPreviewState],
        nextState: PianoComponentState
    ) {
        let removedPreviews = previousPreviews.filter { preview in
            nextState.preview(for: preview.previewID) == nil
        }
        guard !removedPreviews.isEmpty else {
            return
        }

        emitSemanticEvents(removedPreviews.map(PianoSemanticEvent.previewEnded))
    }

    func emitSemanticEvents(_ semanticEvents: [PianoSemanticEvent]) {
        for semanticEvent in semanticEvents {
            switch semanticEvent {
            case let .rowsChanged(rows):
                onRowsChanged?(rows)
            case let .previewStarted(preview):
                onPreviewStarted?(preview)
            case let .previewChanged(preview):
                onPreviewChanged?(preview)
            case let .previewEnded(preview):
                onPreviewEnded?(preview)
            }
        }
    }
}
#endif

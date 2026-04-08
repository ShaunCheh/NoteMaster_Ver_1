//
//  macOSPianoKeyboardView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

#if os(macOS)
import AppKit

private enum macOSPianoPointerSource: Hashable {
    case mouse(buttonNumber: Int)
    case touch(ObjectIdentifier)
}

final class macOSPianoKeyboardView: NSView {
    private var componentState: PianoComponentState
    private var pointerSessionTracker = PianoPointerSessionTracker<macOSPianoPointerSource>()

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

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: resolvedIntrinsicHeight
        )
    }

    override init(frame frameRect: NSRect) {
        configuration = .init()
        componentState = .empty
        super.init(frame: frameRect)
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

    override func makeBackingLayer() -> CALayer {
        PianoKeyboardLayer()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
        refreshPresentationForResize(displayImmediately: false)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshPresentationForResize(displayImmediately: inLiveResize)
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        refreshPresentationForResize(displayImmediately: true)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        refreshPresentationForResize(displayImmediately: true)
    }

    override func mouseDown(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .began)
    }

    override func mouseDragged(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .moved)
    }

    override func mouseUp(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .ended)
    }

    override func rightMouseDown(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .began)
    }

    override func rightMouseDragged(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .moved)
    }

    override func rightMouseUp(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .ended)
    }

    override func otherMouseDown(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .began)
    }

    override func otherMouseDragged(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .moved)
    }

    override func otherMouseUp(with event: NSEvent) {
        handleRawMouseEvent(event, phase: .ended)
    }

    override func touchesBegan(with event: NSEvent) {
        handleRawTouchEvent(event, phase: .began)
        super.touchesBegan(with: event)
    }

    override func touchesMoved(with event: NSEvent) {
        handleRawTouchEvent(event, phase: .moved)
        super.touchesMoved(with: event)
    }

    override func touchesEnded(with event: NSEvent) {
        handleRawTouchEvent(event, phase: .ended)
        super.touchesEnded(with: event)
    }

    override func touchesCancelled(with event: NSEvent) {
        handleRawTouchEvent(event, phase: .cancelled)
        super.touchesCancelled(with: event)
    }
}

private extension macOSPianoKeyboardView {
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

    var resolvedContextNormalizationMode: PianoContextNormalizationMode {
        .flipYToTopLeft
    }

    func configureView() {
        wantsLayer = true
        acceptsTouchEvents = true
        layerContentsRedrawPolicy = .duringViewResize
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyBackingState()
        applyConfiguration()
    }

    func applyConfiguration() {
        cancelRowsTransitionAnimationForExternalStateChange()
        pianoKeyboardLayer.configuration = configuration
        pianoKeyboardLayer.contextNormalizationMode = resolvedContextNormalizationMode
        updateContentsScale()
        refreshPresentationForResize(displayImmediately: false)
        invalidateIntrinsicContentSize()
    }

    func applyBackingState() {
        pianoKeyboardLayer.state = componentState
        updateComponentBoundsOverlay()
        invalidateIntrinsicContentSize()
    }

    func updateContentsScale() {
        pianoKeyboardLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        updateComponentBoundsOverlay()
    }

    func refreshPresentationForResize(displayImmediately: Bool) {
        guard let pianoKeyboardLayer = layer as? PianoKeyboardLayer else {
            return
        }

        pianoKeyboardLayer.refreshForCurrentBounds(
            displayImmediately: displayImmediately
        )
    }

    func updateComponentBoundsOverlay() {
        pianoKeyboardLayer.borderColor = NSColor.systemGreen.cgColor
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
        pointerSessionTracker.retainSessions(
            withPointerIDs: Set(componentState.activeInteractionsByPointer.keys)
        )

        applyBackingState()
        emitPreviewEndedEvents(
            removedFrom: previousPreviews,
            nextState: componentState
        )
    }

    func handleRawMouseEvent(
        _ event: NSEvent,
        phase: PianoEventPhase
    ) {
        guard let rawEvent = rawEvent(forMouseEvent: event, phase: phase) else {
            return
        }
        handleRawEvent(rawEvent)
    }

    func handleRawTouchEvent(
        _ event: NSEvent,
        phase: PianoEventPhase
    ) {
        for touch in orderedTouches(
            from: event,
            matching: touchPhase(for: phase)
        ) {
            guard let rawEvent = rawEvent(forTouch: touch, phase: phase) else {
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
        let hadTrackedPointers = pointerSessionTracker.hasActiveSessions
        guard !interruptedPreviews.isEmpty || hadActiveInteraction || hadTrackedPointers else {
            return
        }

        _ = componentState.clearInputSessions()
        pointerSessionTracker.removeAllSessions()
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
        pointerSessionTracker.retainSessions(
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

    func rawEvent(
        forMouseEvent event: NSEvent,
        phase: PianoEventPhase
    ) -> PianoRawEvent? {
        let location = convert(event.locationInWindow, from: nil)
        let normalizedLocation = resolvedContextNormalizationMode.normalizedPoint(
            location,
            in: bounds
        )
        let source = macOSPianoPointerSource.mouse(
            buttonNumber: Int(event.buttonNumber)
        )

        switch phase {
        case .began:
            return pointerSessionTracker.begin(
                source: source,
                locationInView: normalizedLocation
            )
        case .moved:
            return pointerSessionTracker.move(
                source: source,
                locationInView: normalizedLocation
            )
        case .ended:
            return pointerSessionTracker.end(
                source: source,
                locationInView: normalizedLocation
            )
        case .cancelled:
            return pointerSessionTracker.cancel(
                source: source,
                locationInView: normalizedLocation
            )
        }
    }

    func rawEvent(
        forTouch touch: NSTouch,
        phase: PianoEventPhase
    ) -> PianoRawEvent? {
        guard !bounds.isEmpty else {
            return nil
        }

        let source = macOSPianoPointerSource.touch(
            ObjectIdentifier(touchIdentityObject(for: touch))
        )
        let normalizedPosition = touch.normalizedPosition
        let clampedX = min(max(normalizedPosition.x, 0), 1)
        let clampedY = min(max(normalizedPosition.y, 0), 1)
        let location = CGPoint(
            x: bounds.minX + (bounds.width * clampedX),
            y: bounds.minY + (bounds.height * clampedY)
        )
        let normalizedLocation = resolvedContextNormalizationMode.normalizedPoint(
            location,
            in: bounds
        )

        switch phase {
        case .began:
            return pointerSessionTracker.begin(
                source: source,
                locationInView: normalizedLocation
            )
        case .moved:
            return pointerSessionTracker.move(
                source: source,
                locationInView: normalizedLocation
            )
        case .ended:
            return pointerSessionTracker.end(
                source: source,
                locationInView: normalizedLocation
            )
        case .cancelled:
            return pointerSessionTracker.cancel(
                source: source,
                locationInView: normalizedLocation
            )
        }
    }

    func touchPhase(for phase: PianoEventPhase) -> NSTouch.Phase {
        switch phase {
        case .began:
            return .began
        case .moved:
            return .moved
        case .ended:
            return .ended
        case .cancelled:
            return .cancelled
        }
    }

    func orderedTouches(
        from event: NSEvent,
        matching phase: NSTouch.Phase
    ) -> [NSTouch] {
        event.touches(matching: phase, in: self).sorted { lhs, rhs in
            ObjectIdentifier(touchIdentityObject(for: lhs)).hashValue
                < ObjectIdentifier(touchIdentityObject(for: rhs)).hashValue
        }
    }

    func touchIdentityObject(for touch: NSTouch) -> AnyObject {
        touch.identity as AnyObject
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

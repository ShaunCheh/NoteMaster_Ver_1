//
//  macOSPianoKeyboardView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

#if os(macOS)
import AppKit

final class macOSPianoKeyboardView: NSView {
    private var componentState: PianoComponentState
    private var isMouseSequenceActive = false

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
        isMouseSequenceActive = true
        handleRawMouseEvent(event, phase: .began)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isMouseSequenceActive else {
            return
        }

        handleRawMouseEvent(event, phase: .moved)
    }

    override func mouseUp(with event: NSEvent) {
        guard isMouseSequenceActive else {
            return
        }

        handleRawMouseEvent(event, phase: .ended)
        isMouseSequenceActive = false
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
        layerContentsRedrawPolicy = .duringViewResize
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyBackingState()
        applyConfiguration()
    }

    func applyConfiguration() {
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
        guard componentState.rows != newRows else {
            return
        }

        let hadActiveInteraction = componentState.activeInteraction != nil
        componentState = sanitizedState(
            byReplacingRowsWith: newRows,
            from: componentState
        )

        if hadActiveInteraction, componentState.activeInteraction == nil {
            isMouseSequenceActive = false
        }

        applyBackingState()
    }

    func sanitizedState(
        byReplacingRowsWith rows: [PianoRowState],
        from currentState: PianoComponentState
    ) -> PianoComponentState {
        var nextState = currentState
        nextState.rows = rows
        nextState.preview = sanitizedPreview(
            currentState.preview,
            rowCount: rows.count
        )
        nextState.activeInteraction = sanitizedInteraction(
            currentState.activeInteraction,
            rowCount: rows.count
        )
        return nextState
    }

    func sanitizedPreview(
        _ preview: PianoPreviewState?,
        rowCount: Int
    ) -> PianoPreviewState? {
        guard let preview, (0..<rowCount).contains(preview.rowIndex) else {
            return nil
        }

        return preview
    }

    func sanitizedInteraction(
        _ interaction: PianoInteractionState?,
        rowCount: Int
    ) -> PianoInteractionState? {
        guard let interaction else {
            return nil
        }

        switch interaction {
        case let .buttonPressed(interaction):
            guard (0..<rowCount).contains(interaction.rowIndex) else {
                return nil
            }
            return .buttonPressed(interaction)
        case let .scaleDrag(interaction):
            guard (0..<rowCount).contains(interaction.rowIndex),
                  interaction.hasConsistentAffectedRows,
                  interaction.affectedRowIndices.allSatisfy({ rowIndex in
                      (0..<rowCount).contains(rowIndex)
                  }) else {
                return nil
            }
            return .scaleDrag(interaction)
        case let .keyGlissando(interaction):
            guard (0..<rowCount).contains(interaction.rowIndex),
                  interaction.currentPreview.rowIndex == interaction.rowIndex else {
                return nil
            }
            return .keyGlissando(interaction)
        }
    }

    func handleRawMouseEvent(
        _ event: NSEvent,
        phase: PianoEventPhase
    ) {
        let location = convert(event.locationInWindow, from: nil)
        let normalizedLocation = resolvedContextNormalizationMode.normalizedPoint(
            location,
            in: bounds
        )
        handleRawEvent(
            PianoRawEvent(
                phase: phase,
                locationInView: normalizedLocation
            )
        )
    }

    func handleRawEvent(_ rawEvent: PianoRawEvent) {
        guard !bounds.isEmpty else {
            return
        }

        let geometry = PianoGeometry(
            configuration: configuration,
            state: componentState,
            bounds: bounds
        )
        let hitResult = geometry.hitTest(
            rawEvent.locationInView,
            phase: rawEvent.phase
        )
        let reduction = PianoInteractionReducer.reduce(
            state: componentState,
            rawEvent: rawEvent,
            hitResult: hitResult,
            configuration: configuration
        )
        applyReduction(reduction)
    }

    func applyReduction(_ reduction: PianoReduction) {
        guard reduction.nextState != componentState || !reduction.semanticEvents.isEmpty else {
            return
        }

        componentState = reduction.nextState
        applyBackingState()
        emitSemanticEvents(reduction.semanticEvents)
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

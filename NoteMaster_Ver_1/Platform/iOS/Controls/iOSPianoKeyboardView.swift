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
    private var activeTouch: UITouch?
    private var lastTrackedLocationInView: CGPoint?

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
        isMultipleTouchEnabled = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyBackingState()
        applyConfiguration()
    }

    func applyConfiguration() {
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
        guard componentState.rows != newRows else {
            return
        }

        let hadActiveInteraction = componentState.activeInteraction != nil
        componentState = sanitizedState(
            byReplacingRowsWith: newRows,
            from: componentState
        )

        if hadActiveInteraction, componentState.activeInteraction == nil {
            activeTouch = nil
            lastTrackedLocationInView = nil
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

    func handleRawTouchEvent(
        from touches: Set<UITouch>,
        phase: PianoEventPhase
    ) {
        guard let touch = resolvedTrackedTouch(
            from: touches,
            phase: phase
        ) else {
            if phase == .ended || phase == .cancelled {
                if let lastTrackedLocationInView {
                    handleRawEvent(
                        PianoRawEvent(
                            phase: phase,
                            locationInView: lastTrackedLocationInView
                        )
                    )
                }
                activeTouch = nil
                lastTrackedLocationInView = nil
            }
            return
        }

        let locationInView = touch.location(in: self)
        lastTrackedLocationInView = locationInView
        let rawEvent = PianoRawEvent(
            phase: phase,
            locationInView: locationInView
        )
        handleRawEvent(rawEvent)

        if phase == .ended || phase == .cancelled {
            activeTouch = nil
            lastTrackedLocationInView = nil
        }
    }

    func resolvedTrackedTouch(
        from touches: Set<UITouch>,
        phase: PianoEventPhase
    ) -> UITouch? {
        switch phase {
        case .began:
            guard activeTouch == nil, let touch = touches.first else {
                return nil
            }
            activeTouch = touch
            return touch
        case .moved, .ended, .cancelled:
            guard let activeTouch else {
                return nil
            }
            return touches.first(where: { $0 === activeTouch })
        }
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

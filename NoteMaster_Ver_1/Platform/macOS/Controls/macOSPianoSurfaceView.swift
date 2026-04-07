#if os(macOS)
import AppKit

final class macOSPianoSurfaceView: NSView {
    private let chromeStyle: PianoSurfaceChromeStyle
    private let baseConfiguration: PianoConfiguration
    private var baseRows: [PianoRowState]
    private let interactionBlockerView = NSView()

    private lazy var pianoKeyboardView: macOSPianoKeyboardView = {
        let pianoKeyboardView = macOSPianoKeyboardView(
            configuration: resolvedConfiguration,
            rows: resolvedRows
        )
        pianoKeyboardView.translatesAutoresizingMaskIntoConstraints = false
        pianoKeyboardView.onRowsChanged = { [weak self] rows in
            self?.handleRowsChanged(rows)
        }
        pianoKeyboardView.onPreviewStarted = { [weak self] preview in
            self?.onPreviewStarted?(preview)
        }
        pianoKeyboardView.onPreviewChanged = { [weak self] preview in
            self?.onPreviewChanged?(preview)
        }
        pianoKeyboardView.onPreviewEnded = { [weak self] preview in
            self?.onPreviewEnded?(preview)
        }
        return pianoKeyboardView
    }()

    var panelState: PianoPanelState {
        didSet {
            guard oldValue != panelState else {
                return
            }

            applyPanelState()
        }
    }

    var showsComponentBoundsOverlay = false {
        didSet {
            guard oldValue != showsComponentBoundsOverlay else {
                return
            }

            pianoKeyboardView.showsComponentBoundsOverlay = showsComponentBoundsOverlay
        }
    }

    var isPianoInteractionEnabled = true {
        didSet {
            guard oldValue != isPianoInteractionEnabled else {
                return
            }

            if !isPianoInteractionEnabled {
                pianoKeyboardView.interruptActiveInteraction()
            }
            interactionBlockerView.isHidden = isPianoInteractionEnabled
        }
    }

    var onRowsChanged: (([PianoRowState]) -> Void)?
    var onPreviewStarted: ((PianoPreviewState) -> Void)?
    var onPreviewChanged: ((PianoPreviewState) -> Void)?
    var onPreviewEnded: ((PianoPreviewState) -> Void)?

    override var intrinsicContentSize: NSSize {
        let keyboardSize = pianoKeyboardView.intrinsicContentSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: keyboardSize.height + contentInsets.top + contentInsets.bottom
        )
    }

    init(
        chromeStyle: PianoSurfaceChromeStyle = .card,
        baseConfiguration: PianoConfiguration = PianoSurfaceDefaults.configuration,
        baseRows: [PianoRowState] = PianoSurfaceDefaults.rows,
        panelState: PianoPanelState = PianoSurfaceDefaults.panelState
    ) {
        self.chromeStyle = chromeStyle
        self.baseConfiguration = baseConfiguration
        self.baseRows = baseRows
        self.panelState = panelState
        super.init(frame: .zero)
        configureView()
        applyPanelState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var currentSettingsSlice: PianoPanelSettingsSlice {
        panelState.settingsSlice
    }

    func applySharedSettings(_ settingsSlice: PianoPanelSettingsSlice) {
        panelState = panelState.applyingSettingsSlice(settingsSlice)
    }

    func interruptActiveInteraction() {
        pianoKeyboardView.interruptActiveInteraction()
    }
}

private extension macOSPianoSurfaceView {
    var contentInsets: NSEdgeInsets {
        switch chromeStyle {
        case .plain:
            return NSEdgeInsets()
        case .card:
            return NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        }
    }

    var resolvedConfiguration: PianoConfiguration {
        PianoPanelProjection.resolvedConfiguration(
            from: baseConfiguration,
            panelState: panelState
        )
    }

    var resolvedRows: [PianoRowState] {
        PianoPanelProjection.resolvedRows(
            from: baseRows,
            panelState: panelState
        )
    }

    func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        switch chromeStyle {
        case .plain:
            layer?.backgroundColor = NSColor.clear.cgColor
        case .card:
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.cornerRadius = 16
        }

        addSubview(pianoKeyboardView)
        interactionBlockerView.translatesAutoresizingMaskIntoConstraints = false
        interactionBlockerView.wantsLayer = true
        interactionBlockerView.layer?.backgroundColor = NSColor.clear.cgColor
        interactionBlockerView.isHidden = isPianoInteractionEnabled
        addSubview(interactionBlockerView)
        NSLayoutConstraint.activate([
            pianoKeyboardView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: contentInsets.left
            ),
            pianoKeyboardView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -contentInsets.right
            ),
            pianoKeyboardView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: contentInsets.top
            ),
            pianoKeyboardView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -contentInsets.bottom
            ),
            interactionBlockerView.leadingAnchor.constraint(
                equalTo: pianoKeyboardView.leadingAnchor
            ),
            interactionBlockerView.trailingAnchor.constraint(
                equalTo: pianoKeyboardView.trailingAnchor
            ),
            interactionBlockerView.topAnchor.constraint(
                equalTo: pianoKeyboardView.topAnchor
            ),
            interactionBlockerView.bottomAnchor.constraint(
                equalTo: pianoKeyboardView.bottomAnchor
            )
        ])
    }

    func applyPanelState() {
        pianoKeyboardView.interruptActiveInteraction()
        pianoKeyboardView.configuration = resolvedConfiguration
        pianoKeyboardView.rows = resolvedRows
        pianoKeyboardView.showsComponentBoundsOverlay = showsComponentBoundsOverlay
        interactionBlockerView.isHidden = isPianoInteractionEnabled
        invalidateIntrinsicContentSize()
    }

    func handleRowsChanged(_ rows: [PianoRowState]) {
        baseRows = rows
        onRowsChanged?(rows)
        invalidateIntrinsicContentSize()
    }
}
#endif

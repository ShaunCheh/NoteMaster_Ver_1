#if os(macOS)
import AppKit

final class macOSPlayViewController: NSViewController {
    private var isSettingsPresented = false
    private var pianoPanelState = PianoSurfaceDefaults.panelState {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyPianoSurfaceState()
            applySettingsPanelState()
        }
    }
    private var playModeState = PlayModeState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyPlayPresentationState()
        }
    }

    var onRootModeChangeRequest: ((RootMode) -> Void)?

    private let scrollView = NSScrollView()
    private let contentView = NSView()

    private lazy var settingsButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.image = NSImage(
            systemSymbolName: "gearshape.fill",
            accessibilityDescription: "Settings"
        )
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .labelColor
        button.identifier = NSUserInterfaceItemIdentifier(
            "floating-play-settings-button"
        )
        button.target = self
        button.action = #selector(handleSettingsButtonTap)
        button.wantsLayer = true
        button.layer?.cornerRadius = Layout.settingsButtonSize / 2
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.12
        button.layer?.shadowRadius = 12
        button.layer?.shadowOffset = CGSize(width: 0, height: -4)
        return button
    }()

    private lazy var settingsContainerView: macOSSettingsContainerView = {
        let settingsContainerView = macOSSettingsContainerView(
            model: SettingsNavigationSnapshotBuilder.makeModel(
                from: settingsPanelStateContext
            )
        )
        settingsContainerView.onEvent = { [weak self] event in
            self?.handleSettingsPanelEvent(event)
        }
        settingsContainerView.onDismissRequest = { [weak self] in
            self?.setSettingsPresented(false)
        }
        return settingsContainerView
    }()

    private lazy var pianoSurfaceView = macOSPianoSurfaceView(
        chromeStyle: .plain,
        panelState: pianoPanelState
    )

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureLayout()
        applyPianoSurfaceState()
        applyPlayPresentationState()
        applySettingsPresentationState()
    }

    var currentPianoSettingsSlice: PianoPanelSettingsSlice {
        pianoPanelState.settingsSlice
    }

    func applySharedPianoSettings(_ settingsSlice: PianoPanelSettingsSlice) {
        let nextPanelState = pianoPanelState.applyingSettingsSlice(
            settingsSlice
        )
        guard nextPanelState != pianoPanelState else {
            return
        }

        pianoPanelState = nextPanelState
    }
}

private extension macOSPlayViewController {
    var settingsPanelStateContext: SettingsPanelStateContext {
        SettingsPanelStateContext(
            rootMode: .play,
            pianoPanelState: pianoPanelState,
            playModeState: playModeState
        )
    }

    var playPresentationState: PlayPresentationState {
        PlayCompositionPolicy.makePresentation(
            from: playModeState.compositionInput
        )
    }

    func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView

        view.addSubview(scrollView)
        contentView.addSubview(pianoSurfaceView)
        view.addSubview(settingsButton)
        view.addSubview(settingsContainerView)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            pianoSurfaceView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            pianoSurfaceView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            pianoSurfaceView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.contentTopInset
            ),
            pianoSurfaceView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            ),
            settingsButton.leadingAnchor.constraint(
                equalTo: safeArea.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            settingsButton.topAnchor.constraint(
                equalTo: safeArea.topAnchor,
                constant: Layout.topInset
            ),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            settingsContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func applyPianoSurfaceState() {
        pianoSurfaceView.applySharedSettings(
            pianoPanelState.settingsSlice
        )
        pianoSurfaceView.showsComponentBoundsOverlay = false
    }

    func applyPlayPresentationState() {
        let pianoSurfaceState = playPresentationState.effectiveSurfaceState(
            for: .piano
        )
        pianoSurfaceView.isHidden = !pianoSurfaceState.isVisible
        pianoSurfaceView.isPianoInteractionEnabled = pianoSurfaceState
            .isInteractionEnabled
    }

    func applySettingsPanelState() {
        settingsContainerView.navigationModel = SettingsNavigationSnapshotBuilder
            .makeModel(from: settingsPanelStateContext)
    }

    func setSettingsPresented(_ presented: Bool) {
        guard isSettingsPresented != presented else {
            return
        }

        isSettingsPresented = presented
        applySettingsPresentationState()
    }

    func applySettingsPresentationState() {
        settingsContainerView.setPresented(isSettingsPresented)
        settingsButton.isHidden = isSettingsPresented
        updateSettingsButtonAppearance()
    }

    func updateSettingsButtonAppearance() {
        settingsButton.contentTintColor = isSettingsPresented
            ? .white
            : .labelColor
        settingsButton.layer?.backgroundColor = (
            isSettingsPresented
                ? NSColor.controlAccentColor
                : NSColor.controlBackgroundColor
        ).cgColor
        settingsButton.toolTip = isSettingsPresented
            ? "Hide settings"
            : "Show settings"
    }

    @objc
    func handleSettingsButtonTap() {
        setSettingsPresented(!isSettingsPresented)
    }

    func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
        var nextStateContext = settingsPanelStateContext
        event.apply(to: &nextStateContext)

        if nextStateContext.rootMode != .play {
            setSettingsPresented(false)
            onRootModeChangeRequest?(nextStateContext.rootMode)
            return
        }

        let nextPianoPanelState = nextStateContext.pianoPanelState
        let nextPlayModeState = nextStateContext.playModeState

        guard nextPianoPanelState != pianoPanelState
            || nextPlayModeState != playModeState else {
            return
        }

        pianoPanelState = nextPianoPanelState
        playModeState = nextPlayModeState
    }
}

private extension macOSPlayViewController {
    enum Layout {
        static let horizontalInset: CGFloat = 16
        static let topInset: CGFloat = 12
        static let contentTopInset: CGFloat = 72
        static let bottomInset: CGFloat = 24
        static let settingsButtonSize: CGFloat = 40
    }
}
#endif

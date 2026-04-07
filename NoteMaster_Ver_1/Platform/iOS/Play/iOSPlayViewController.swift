#if os(iOS)
import UIKit

final class iOSPlayViewController: UIViewController {
    private var isSettingsPresented = false
    private var playbackCoordinator: PlaybackCoordinator?
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

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.buttonSize = .medium
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "gearshape.fill")
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 10,
            bottom: 10,
            trailing: 10
        )
        button.configuration = configuration
        button.accessibilityIdentifier = "floating-play-settings-button"
        button.addTarget(
            self,
            action: #selector(handleSettingsButtonTap),
            for: .touchUpInside
        )
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 12
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        return button
    }()

    private lazy var settingsContainerView: iOSSettingsContainerView = {
        let settingsContainerView = iOSSettingsContainerView(
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

    private lazy var pianoSurfaceView: iOSPianoSurfaceView = {
        let pianoSurfaceView = iOSPianoSurfaceView(
            chromeStyle: .plain,
            panelState: pianoPanelState
        )
        pianoSurfaceView.onPreviewStarted = { [weak self] preview in
            self?.handlePianoSemanticEvent(.previewStarted(preview))
        }
        pianoSurfaceView.onPreviewChanged = { [weak self] preview in
            self?.handlePianoSemanticEvent(.previewChanged(preview))
        }
        pianoSurfaceView.onPreviewEnded = { [weak self] preview in
            self?.handlePianoSemanticEvent(.previewEnded(preview))
        }
        return pianoSurfaceView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        applyPianoSurfaceState()
        applyPlayPresentationState()
        applySettingsPresentationState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        interruptActivePianoPlayback(reason: .viewWillDisappear)
    }

    var currentPianoSettingsSlice: PianoPanelSettingsSlice {
        pianoPanelState.settingsSlice
    }

    func setPlaybackCoordinator(_ playbackCoordinator: PlaybackCoordinator?) {
        self.playbackCoordinator = playbackCoordinator
    }

    func applySharedPianoSettings(_ settingsSlice: PianoPanelSettingsSlice) {
        let nextPanelState = pianoPanelState.applyingSettingsSlice(
            settingsSlice
        )
        guard nextPanelState != pianoPanelState else {
            return
        }

        if isViewLoaded {
            interruptActivePianoPlayback(reason: .sharedSettingsChanged)
        }
        pianoPanelState = nextPanelState
    }

    func interruptActivePianoPlayback(reason: PlaybackStopReason) {
        guard isViewLoaded else {
            playbackCoordinator?.forceStop(reason: reason)
            return
        }

        pianoSurfaceView.interruptActiveInteraction()
        playbackCoordinator?.forceStop(reason: reason)
    }
}

private extension iOSPlayViewController {
    func handlePianoSemanticEvent(_ event: PianoSemanticEvent) {
        playbackCoordinator?.handle(event)
    }

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

        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(pianoSurfaceView)
        view.addSubview(settingsButton)
        view.addSubview(settingsContainerView)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
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
        var configuration = settingsButton.configuration
            ?? UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "gearshape.fill")
        configuration.baseBackgroundColor = isSettingsPresented
            ? .systemBlue
            : .secondarySystemBackground
        configuration.baseForegroundColor = isSettingsPresented
            ? .white
            : .label
        settingsButton.configuration = configuration
        settingsButton.accessibilityLabel = isSettingsPresented
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
            interruptActivePianoPlayback(reason: .rootModeChanged)
            onRootModeChangeRequest?(nextStateContext.rootMode)
            return
        }

        let nextPianoPanelState = nextStateContext.pianoPanelState
        let nextPlayModeState = nextStateContext.playModeState

        guard nextPianoPanelState != pianoPanelState
            || nextPlayModeState != playModeState else {
            return
        }

        if nextPianoPanelState != pianoPanelState {
            interruptActivePianoPlayback(reason: .panelStateChanged)
        }
        pianoPanelState = nextPianoPanelState
        playModeState = nextPlayModeState
    }
}

private extension iOSPlayViewController {
    enum Layout {
        static let horizontalInset: CGFloat = 16
        static let topInset: CGFloat = 12
        static let contentTopInset: CGFloat = 72
        static let bottomInset: CGFloat = 24
        static let settingsButtonSize: CGFloat = 40
    }
}
#endif

#if os(macOS)
import AppKit

final class macOSRootViewController: NSViewController {
    private let exerciseViewController = macOSViewController()
    private let playViewController = macOSPlayViewController()
    private var sharedPianoSettings = PianoSurfaceDefaults.sharedSettings
    private lazy var playbackCoordinator = PlaybackCoordinator(
        backend: macOSPlaybackAudioBackend()
    )

    private(set) var rootMode: RootMode
    private var currentViewController: NSViewController?

    var activeExerciseViewController: macOSViewController? {
        rootMode == .exercise ? exerciseViewController : nil
    }

    init(rootMode: RootMode = .defaultMode) {
        self.rootMode = rootMode
        super.init(nibName: nil, bundle: nil)
        configureChildControllers()
    }

    required init?(coder: NSCoder) {
        rootMode = .defaultMode
        super.init(coder: coder)
        configureChildControllers()
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        applyRootMode(rootMode)
    }

    func setRootMode(_ rootMode: RootMode) {
        guard self.rootMode != rootMode || currentViewController == nil else {
            return
        }

        interruptActivePianoPlaybackForCurrentMode(reason: .rootModeChanged)
        syncSharedPianoSettingsFromCurrentMode()
        applySharedPianoSettingsToChildren()
        self.rootMode = rootMode
        guard isViewLoaded else {
            return
        }

        applyRootMode(rootMode)
    }
}

private extension macOSRootViewController {
    func configureChildControllers() {
        exerciseViewController.onRootModeChangeRequest = { [weak self] rootMode in
            self?.setRootMode(rootMode)
        }
        playViewController.onRootModeChangeRequest = { [weak self] rootMode in
            self?.setRootMode(rootMode)
        }
        exerciseViewController.setPlaybackCoordinator(playbackCoordinator)
        playViewController.setPlaybackCoordinator(playbackCoordinator)
        applySharedPianoSettingsToChildren()
    }

    func applyRootMode(_ rootMode: RootMode) {
        let nextViewController = viewController(for: rootMode)
        guard currentViewController !== nextViewController else {
            return
        }

        if let currentViewController {
            currentViewController.view.removeFromSuperview()
            currentViewController.removeFromParent()
        }

        addChild(nextViewController)
        nextViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextViewController.view)
        NSLayoutConstraint.activate([
            nextViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nextViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nextViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            nextViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        currentViewController = nextViewController
    }

    func viewController(for rootMode: RootMode) -> NSViewController {
        switch rootMode {
        case .exercise:
            return exerciseViewController
        case .play:
            return playViewController
        }
    }

    func syncSharedPianoSettingsFromCurrentMode() {
        switch rootMode {
        case .exercise:
            sharedPianoSettings = exerciseViewController.currentPianoSettingsSlice
        case .play:
            sharedPianoSettings = playViewController.currentPianoSettingsSlice
        }
    }

    func applySharedPianoSettingsToChildren() {
        exerciseViewController.applySharedPianoSettings(sharedPianoSettings)
        playViewController.applySharedPianoSettings(sharedPianoSettings)
    }

    func interruptActivePianoPlaybackForCurrentMode(reason: PlaybackStopReason) {
        switch rootMode {
        case .exercise:
            exerciseViewController.interruptActivePianoPlayback(reason: reason)
        case .play:
            playViewController.interruptActivePianoPlayback(reason: reason)
        }
    }
}
#endif

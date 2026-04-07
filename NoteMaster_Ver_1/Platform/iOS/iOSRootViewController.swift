#if os(iOS)
import UIKit

final class iOSRootViewController: UIViewController {
    private let exerciseViewController = iOSViewController()
    private let playViewController = iOSPlayViewController()
    private var sharedPianoSettings = PianoSurfaceDefaults.sharedSettings
    private lazy var playbackCoordinator = PlaybackCoordinator(
        backend: iOSPlaybackAudioBackend()
    )

    private(set) var rootMode: RootMode
    private var currentViewController: UIViewController?

    var activeExerciseViewController: iOSViewController? {
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
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

private extension iOSRootViewController {
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
            currentViewController.willMove(toParent: nil)
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
        nextViewController.didMove(toParent: self)
        currentViewController = nextViewController
    }

    func viewController(for rootMode: RootMode) -> UIViewController {
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

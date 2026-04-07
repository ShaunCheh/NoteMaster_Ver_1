#if os(macOS)
import AppKit

final class macOSRootViewController: NSViewController {
    private let exerciseViewController = macOSViewController()
    private let playPlaceholderViewController = macOSModePlaceholderViewController(
        titleText: "Play mode is not available yet."
    )

    private(set) var rootMode: RootMode
    private var currentViewController: NSViewController?

    var activeExerciseViewController: macOSViewController? {
        rootMode == .exercise ? exerciseViewController : nil
    }

    init(rootMode: RootMode = .defaultMode) {
        self.rootMode = rootMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        rootMode = .defaultMode
        super.init(coder: coder)
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

        self.rootMode = rootMode
        guard isViewLoaded else {
            return
        }

        applyRootMode(rootMode)
    }
}

private extension macOSRootViewController {
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
            return playPlaceholderViewController
        }
    }
}

private final class macOSModePlaceholderViewController: NSViewController {
    private let titleText: String

    init(titleText: String) {
        self.titleText = titleText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let label = NSTextField(labelWithString: titleText)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: 24
            ),
            label.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -24
            ),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
#endif

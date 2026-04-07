#if os(iOS)
import UIKit

final class iOSRootViewController: UIViewController {
    private let exerciseViewController = iOSViewController()
    private let playPlaceholderViewController = iOSModePlaceholderViewController(
        titleText: "Play mode is not available yet."
    )

    private(set) var rootMode: RootMode
    private var currentViewController: UIViewController?

    var activeExerciseViewController: iOSViewController? {
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
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

private extension iOSRootViewController {
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
            return playPlaceholderViewController
        }
    }
}

private final class iOSModePlaceholderViewController: UIViewController {
    private let titleText: String

    init(titleText: String) {
        self.titleText = titleText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = titleText
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            label.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
#endif

//
//  iOSSettingsContainerView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

#if os(iOS)
import Foundation
import UIKit

final class iOSSettingsContainerView: UIView {
    var navigationModel: SettingsNavigationModel {
        didSet {
            guard oldValue != navigationModel else {
                return
            }

            navigatorView.model = navigationModel
        }
    }

    var onEvent: ((SettingsPanelEvent) -> Void)? {
        didSet {
            navigatorView.onEvent = onEvent
        }
    }

    var navigationTitle: String = SettingsRouteID.root.fallbackTitle {
        didSet {
            updateNavigationHeaderState()
        }
    }

    var showsBackButton = false {
        didSet {
            updateNavigationHeaderState()
        }
    }

    var onBackRequest: (() -> Void)?
    var onDismissRequest: (() -> Void)?

    private let backdropView = UIControl()
    private let cardView = UIView()
    private let headerView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let navigatorHostView = UIView()
    private weak var currentNavigationContentView: UIView?
    private var hostedContentConstraints: [NSLayoutConstraint] = []
    private lazy var navigatorView: iOSSettingsNavigatorView = {
        let navigatorView = iOSSettingsNavigatorView(model: navigationModel)
        navigatorView.onEvent = onEvent
        navigatorView.onPresentationStateChange = { [weak self] state in
            self?.navigationTitle = state.title
            self?.showsBackButton = state.showsBackButton
        }
        return navigatorView
    }()
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.buttonSize = .medium
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.baseForegroundColor = .label
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 10,
            bottom: 10,
            trailing: 10
        )
        button.configuration = configuration
        button.accessibilityIdentifier = SettingsNavigationAccessibility.backButtonIdentifier
        button.accessibilityLabel = "Back to previous settings page"
        button.isHidden = true
        button.addTarget(
            self,
            action: #selector(handleBackButtonTap),
            for: .touchUpInside
        )
        return button
    }()
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.lineBreakMode = .byTruncatingTail
        label.isAccessibilityElement = true
        label.accessibilityIdentifier = SettingsNavigationAccessibility.titleIdentifier
        label.accessibilityTraits = [.header]
        return label
    }()
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.buttonSize = .medium
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "xmark")
        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 10,
            bottom: 10,
            trailing: 10
        )
        button.configuration = configuration
        button.accessibilityIdentifier = "settings-container-close-button"
        button.accessibilityLabel = "Close settings"
        button.addTarget(
            self,
            action: #selector(handleCloseButtonTap),
            for: .touchUpInside
        )
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 12
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        return button
    }()

    override init(frame: CGRect) {
        navigationModel = .empty
        super.init(frame: frame)
        configureView()
        setPresented(false)
    }

    convenience init(model: SettingsNavigationModel) {
        self.init(frame: .zero)
        navigationModel = model
        navigatorView.model = model
    }

    required init?(coder: NSCoder) {
        navigationModel = .empty
        super.init(coder: coder)
        configureView()
        setPresented(false)
    }

    func setPresented(_ presented: Bool) {
        isHidden = !presented
        alpha = presented ? 1 : 0
        isUserInteractionEnabled = presented
        accessibilityElementsHidden = !presented
    }

    // container 统一负责“请求关闭 settings 壳层”；
    // 后续右上角 close button 直接复用这条链路，不必再新开一套 dismiss 逻辑。
    private func requestDismiss() {
        onDismissRequest?()
    }

    private func configureView() {
        accessibilityIdentifier = "settings-container"
        translatesAutoresizingMaskIntoConstraints = false

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(Style.backdropOpacity)
        backdropView.accessibilityIdentifier = "settings-container-backdrop"
        backdropView.addTarget(
            self,
            action: #selector(handleBackdropTap),
            for: .touchUpInside
        )

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = Style.cardCornerRadius
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.12
        cardView.layer.shadowRadius = 24
        cardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        cardView.accessibilityIdentifier = "settings-container-card"

        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.accessibilityIdentifier = "settings-container-header"

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsHorizontalScrollIndicator = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        navigatorHostView.translatesAutoresizingMaskIntoConstraints = false
        navigatorHostView.accessibilityIdentifier = "settings-container-navigation-host"
        navigatorHostView.setContentHuggingPriority(.required, for: .vertical)
        navigatorHostView.setContentCompressionResistancePriority(.required, for: .vertical)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(backdropView)
        addSubview(cardView)
        cardView.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)
        cardView.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(navigatorHostView)

        let safeArea = safeAreaLayoutGuide
        let preferredWidthConstraint = cardView.widthAnchor.constraint(
            equalToConstant: Style.preferredCardWidth
        )
        preferredWidthConstraint.priority = .defaultHigh
        let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
            equalTo: navigatorHostView.heightAnchor
        )
        scrollHeightMatchesContentConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.topAnchor.constraint(equalTo: topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
            cardView.leadingAnchor.constraint(
                greaterThanOrEqualTo: safeArea.leadingAnchor,
                constant: Style.screenInset
            ),
            cardView.trailingAnchor.constraint(
                lessThanOrEqualTo: safeArea.trailingAnchor,
                constant: -Style.screenInset
            ),
            cardView.topAnchor.constraint(
                greaterThanOrEqualTo: safeArea.topAnchor,
                constant: Style.screenInset
            ),
            cardView.bottomAnchor.constraint(
                lessThanOrEqualTo: safeArea.bottomAnchor,
                constant: -Style.screenInset
            ),
            preferredWidthConstraint,

            headerView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor,
                constant: Style.cardContentInset
            ),
            headerView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor,
                constant: -Style.cardContentInset
            ),
            headerView.topAnchor.constraint(
                equalTo: cardView.topAnchor,
                constant: Style.cardContentInset
            ),
            headerView.heightAnchor.constraint(equalToConstant: Style.headerHeight),

            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: Style.closeButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Style.closeButtonSize),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: Style.closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: Style.closeButtonSize),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: backButton.trailingAnchor,
                constant: Style.headerTitleSpacing
            ),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: closeButton.leadingAnchor,
                constant: -Style.headerTitleSpacing
            ),

            scrollView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor,
                constant: Style.cardContentInset
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor,
                constant: -Style.cardContentInset
            ),
            scrollView.topAnchor.constraint(
                equalTo: headerView.bottomAnchor,
                constant: Style.headerBottomSpacing
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: cardView.bottomAnchor,
                constant: -Style.cardContentInset
            ),
            scrollHeightMatchesContentConstraint,
            scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Style.maximumScrollHeight),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            navigatorHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            navigatorHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            navigatorHostView.topAnchor.constraint(equalTo: contentView.topAnchor),
            navigatorHostView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        onBackRequest = { [weak self] in
            self?.navigatorView.pop()
        }
        setNavigationContentView(navigatorView)
        updateNavigationHeaderState()
    }

    func setNavigationContentView(_ view: UIView) {
        guard currentNavigationContentView !== view else {
            return
        }

        NSLayoutConstraint.deactivate(hostedContentConstraints)
        hostedContentConstraints = []
        currentNavigationContentView?.removeFromSuperview()

        if view.superview != nil {
            view.removeFromSuperview()
        }

        view.translatesAutoresizingMaskIntoConstraints = false
        navigatorHostView.addSubview(view)
        hostedContentConstraints = [
            view.leadingAnchor.constraint(equalTo: navigatorHostView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: navigatorHostView.trailingAnchor),
            view.topAnchor.constraint(equalTo: navigatorHostView.topAnchor),
            view.bottomAnchor.constraint(equalTo: navigatorHostView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(hostedContentConstraints)
        currentNavigationContentView = view
    }

    private func updateNavigationHeaderState() {
        titleLabel.text = navigationTitle
        titleLabel.accessibilityLabel = navigationTitle
        titleLabel.isHidden = navigationTitle.isEmpty
        backButton.isHidden = !showsBackButton
    }

    @objc
    private func handleBackdropTap() {
        requestDismiss()
    }

    @objc
    private func handleBackButtonTap() {
        onBackRequest?()
    }

    @objc
    private func handleCloseButtonTap() {
        requestDismiss()
    }
}

private enum Style {
    static let screenInset: CGFloat = 16
    static let preferredCardWidth: CGFloat = 360
    static let maximumScrollHeight: CGFloat = 520
    static let cardContentInset: CGFloat = 16
    static let headerHeight: CGFloat = 40
    static let headerBottomSpacing: CGFloat = 8
    static let headerTitleSpacing: CGFloat = 8
    static let closeButtonSize: CGFloat = 40
    static let cardCornerRadius: CGFloat = 22
    static let backdropOpacity: CGFloat = 0.28
}
#endif

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
    var model: SettingsPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            settingsPanelView.model = model
        }
    }

    var onEvent: ((SettingsPanelEvent) -> Void)? {
        didSet {
            settingsPanelView.onEvent = onEvent
        }
    }

    var onDismissRequest: (() -> Void)?

    private let backdropView = UIControl()
    private let cardView = UIView()
    private let headerView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let settingsPanelView: iOSSettingsPanelView
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
        model = .empty
        settingsPanelView = iOSSettingsPanelView(model: .empty)
        super.init(frame: frame)
        configureView()
        setPresented(false)
    }

    convenience init(model: SettingsPanelModel) {
        self.init(frame: .zero)
        self.model = model
        settingsPanelView.model = model
    }

    required init?(coder: NSCoder) {
        model = .empty
        settingsPanelView = iOSSettingsPanelView(model: .empty)
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
        settingsPanelView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(backdropView)
        addSubview(cardView)
        cardView.addSubview(headerView)
        headerView.addSubview(closeButton)
        cardView.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(settingsPanelView)

        let safeArea = safeAreaLayoutGuide
        let preferredWidthConstraint = cardView.widthAnchor.constraint(
            equalToConstant: Style.preferredCardWidth
        )
        preferredWidthConstraint.priority = .defaultHigh
        let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
            equalTo: settingsPanelView.heightAnchor
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

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: Style.closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: Style.closeButtonSize),

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

            settingsPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            settingsPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            settingsPanelView.topAnchor.constraint(equalTo: contentView.topAnchor),
            settingsPanelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc
    private func handleBackdropTap() {
        requestDismiss()
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
    static let closeButtonSize: CGFloat = 40
    static let cardCornerRadius: CGFloat = 22
    static let backdropOpacity: CGFloat = 0.28
}
#endif

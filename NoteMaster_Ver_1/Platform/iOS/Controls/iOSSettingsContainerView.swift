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
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let settingsPanelView: iOSSettingsPanelView

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

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsHorizontalScrollIndicator = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        settingsPanelView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(backdropView)
        addSubview(cardView)
        cardView.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(settingsPanelView)

        let safeArea = safeAreaLayoutGuide
        let preferredWidthConstraint = cardView.widthAnchor.constraint(
            equalToConstant: Style.preferredCardWidth
        )
        preferredWidthConstraint.priority = .defaultHigh

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

            scrollView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor,
                constant: Style.cardContentInset
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor,
                constant: -Style.cardContentInset
            ),
            scrollView.topAnchor.constraint(
                equalTo: cardView.topAnchor,
                constant: Style.cardContentInset
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: cardView.bottomAnchor,
                constant: -Style.cardContentInset
            ),
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
        onDismissRequest?()
    }
}

private enum Style {
    static let screenInset: CGFloat = 16
    static let preferredCardWidth: CGFloat = 360
    static let maximumScrollHeight: CGFloat = 520
    static let cardContentInset: CGFloat = 16
    static let cardCornerRadius: CGFloat = 22
    static let backdropOpacity: CGFloat = 0.28
}
#endif

//
//  macOSSettingsContainerView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

#if os(macOS)
import Foundation
import AppKit

final class macOSSettingsContainerView: NSView {
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

    private let backdropView = DismissBackgroundView()
    private let cardView = NSView()
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let settingsPanelView: macOSSettingsPanelView

    override init(frame frameRect: NSRect) {
        model = .empty
        settingsPanelView = macOSSettingsPanelView(model: .empty)
        super.init(frame: frameRect)
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
        settingsPanelView = macOSSettingsPanelView(model: .empty)
        super.init(coder: coder)
        configureView()
        setPresented(false)
    }

    func setPresented(_ presented: Bool) {
        isHidden = !presented
        alphaValue = presented ? 1 : 0
    }

    // container 统一收口 settings 壳层的 dismiss 请求；
    // 下一阶段无论是 header close button 还是背景点击，都走同一条回调链。
    private func requestDismiss() {
        onDismissRequest?()
    }

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("settings-container")
        translatesAutoresizingMaskIntoConstraints = false

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.wantsLayer = true
        backdropView.layer?.backgroundColor = NSColor.black.withAlphaComponent(
            Style.backdropOpacity
        ).cgColor
        backdropView.identifier = NSUserInterfaceItemIdentifier("settings-container-backdrop")
        backdropView.onClick = { [weak self] in
            self?.requestDismiss()
        }

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        cardView.layer?.cornerRadius = Style.cardCornerRadius
        cardView.layer?.shadowColor = NSColor.black.cgColor
        cardView.layer?.shadowOpacity = 0.12
        cardView.layer?.shadowRadius = 24
        cardView.layer?.shadowOffset = CGSize(width: 0, height: -10)
        cardView.identifier = NSUserInterfaceItemIdentifier("settings-container-card")

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView

        contentView.translatesAutoresizingMaskIntoConstraints = false
        settingsPanelView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(backdropView)
        addSubview(cardView)
        cardView.addSubview(scrollView)
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
            scrollHeightMatchesContentConstraint,
            scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Style.maximumScrollHeight),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            settingsPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            settingsPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            settingsPanelView.topAnchor.constraint(equalTo: contentView.topAnchor),
            settingsPanelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}

private final class DismissBackgroundView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
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

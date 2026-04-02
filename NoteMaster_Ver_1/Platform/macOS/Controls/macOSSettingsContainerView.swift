//
//  macOSSettingsContainerView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

#if os(macOS)
import Foundation
import AppKit

enum macOSSettingsMutationTrace {
    private(set) static var activeEventID: Int?
    private static var nextEventID: Int = 0
    private static var activeActionID: SettingsActionID?
    private static var activeRowPointer: String?
    private static var activeSenderPointer: String?

    static func shouldTrace(_ event: SettingsPanelEvent) -> Bool {
        switch event {
        case let .triggerAction(actionID):
            return actionID.rowID == .layoutPreset
        case .togglePositionPromptFilterOption, .setSliderValue, .setToggleValue:
            return false
        }
    }

    static func prepareSource(
        actionID: SettingsActionID,
        rowView: NSView,
        senderView: NSView
    ) {
        activeActionID = actionID
        activeRowPointer = pointerString(for: rowView)
        activeSenderPointer = pointerString(for: senderView)
    }

    static func begin(event: SettingsPanelEvent, state: String) -> Int {
        nextEventID += 1
        let eventID = nextEventID
        activeEventID = eventID
        log(
            "event=\(eventID) begin event=\(String(describing: event)) state=\(state) activeSource=\(describeActiveSource())"
        )
        return eventID
    }

    static func end(_ eventID: Int, state: String) {
        log(
            "event=\(eventID) end state=\(state) activeSource=\(describeActiveSource())"
        )
        if activeEventID == eventID {
            activeEventID = nil
        }
        activeActionID = nil
        activeRowPointer = nil
        activeSenderPointer = nil
    }

    static func log(_ message: String) {
        print("[SettingsTrace][macOS] \(message)")
    }

    static func logIfActive(_ message: @autoclosure () -> String) {
        guard let eventID = activeEventID else {
            return
        }

        log("event=\(eventID) \(message())")
    }

    static func describeActiveSource() -> String {
        let action = activeActionID.map { String(describing: $0) } ?? "nil"
        let rowPointer = activeRowPointer ?? "nil"
        let senderPointer = activeSenderPointer ?? "nil"
        return "action=\(action) rowPtr=\(rowPointer) senderPtr=\(senderPointer)"
    }

    static func describe(view: NSView?) -> String {
        guard let view else {
            return "view=nil"
        }

        let pointer = pointerString(for: view)
        let identifier = view.identifier?.rawValue ?? "nil"
        let hasSuperview = view.superview != nil
        let superType = view.superview.map { String(describing: type(of: $0)) } ?? "nil"
        let superIdentifier = view.superview?.identifier?.rawValue ?? "nil"
        let windowAttached = view.window != nil
        return "type=\(type(of: view)) id=\(identifier) ptr=\(pointer) hasSuperview=\(hasSuperview) superType=\(superType) superID=\(superIdentifier) windowAttached=\(windowAttached) hidden=\(view.isHidden)"
    }

    static func containsActiveSource(in rootView: NSView?) -> String {
        let containsRow = containsTrackedView(
            in: rootView,
            trackedPointer: activeRowPointer
        )
        let containsSender = containsTrackedView(
            in: rootView,
            trackedPointer: activeSenderPointer
        )
        return "containsActiveRow=\(containsRow) containsActiveSender=\(containsSender)"
    }

    private static func pointerString(for view: NSView?) -> String {
        guard let view else {
            return "nil"
        }

        return String(describing: Unmanaged.passUnretained(view).toOpaque())
    }

    private static func containsTrackedView(
        in rootView: NSView?,
        trackedPointer: String?
    ) -> Bool {
        guard let rootView, let trackedPointer else {
            return false
        }

        if pointerString(for: rootView) == trackedPointer {
            return true
        }

        return rootView.subviews.contains {
            containsTrackedView(in: $0, trackedPointer: trackedPointer)
        }
    }
}

final class macOSSettingsContainerView: NSView {
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

    private let backdropView = DismissBackgroundView()
    private let cardView = NSView()
    private let headerView = NSView()
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let navigatorHostView = NSView()
    private weak var currentNavigationContentView: NSView?
    private var hostedContentConstraints: [NSLayoutConstraint] = []
    private lazy var navigatorView: macOSSettingsNavigatorView = {
        let navigatorView = macOSSettingsNavigatorView(model: navigationModel)
        navigatorView.onEvent = onEvent
        navigatorView.onPresentationStateChange = { [weak self] state in
            self?.navigationTitle = state.title
            self?.showsBackButton = state.showsBackButton
        }
        return navigatorView
    }()
    private lazy var backButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.image = NSImage(
            systemSymbolName: "chevron.left",
            accessibilityDescription: "Back"
        )
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .labelColor
        button.identifier = NSUserInterfaceItemIdentifier(
            SettingsNavigationAccessibility.backButtonIdentifier
        )
        button.setAccessibilityLabel("Back to previous settings page")
        button.toolTip = "Back to previous settings page"
        button.target = self
        button.action = #selector(handleBackButtonTap)
        button.isHidden = true
        return button
    }()
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: SettingsRouteID.root.fallbackTitle)
        label.font = NSFont.preferredFont(forTextStyle: .headline)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.identifier = NSUserInterfaceItemIdentifier(
            SettingsNavigationAccessibility.titleIdentifier
        )
        label.setAccessibilityLabel(SettingsRouteID.root.fallbackTitle)
        return label
    }()
    private lazy var closeButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.image = NSImage(
            systemSymbolName: "xmark",
            accessibilityDescription: "Close settings"
        )
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.identifier = NSUserInterfaceItemIdentifier("settings-container-close-button")
        button.toolTip = "Close settings"
        button.target = self
        button.action = #selector(handleCloseButtonTap)
        button.wantsLayer = true
        button.layer?.cornerRadius = Style.closeButtonSize / 2
        button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.12
        button.layer?.shadowRadius = 12
        button.layer?.shadowOffset = CGSize(width: 0, height: -4)
        return button
    }()

    override init(frame frameRect: NSRect) {
        navigationModel = .empty
        super.init(frame: frameRect)
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

        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.identifier = NSUserInterfaceItemIdentifier("settings-container-header")

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.setContentHuggingPriority(.required, for: .vertical)
        contentView.setContentCompressionResistancePriority(.required, for: .vertical)
        navigatorHostView.translatesAutoresizingMaskIntoConstraints = false
        navigatorHostView.identifier = NSUserInterfaceItemIdentifier(
            "settings-container-navigation-host"
        )
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

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

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

    func setNavigationContentView(_ view: NSView) {
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
        titleLabel.stringValue = navigationTitle
        titleLabel.setAccessibilityLabel(navigationTitle)
        titleLabel.isHidden = navigationTitle.isEmpty
        backButton.isHidden = !showsBackButton
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
    static let headerHeight: CGFloat = 40
    static let headerBottomSpacing: CGFloat = 8
    static let headerTitleSpacing: CGFloat = 8
    static let closeButtonSize: CGFloat = 40
    static let cardCornerRadius: CGFloat = 22
    static let backdropOpacity: CGFloat = 0.28
}
#endif

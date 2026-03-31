//
//  macOSSettingsIndexPageView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/31.
//

#if os(macOS)
import Foundation
import AppKit

final class macOSSettingsIndexPageView: NSView {
    var routeItems: [SettingsRouteItem] {
        didSet {
            guard oldValue != routeItems else {
                return
            }

            applyRouteItems()
        }
    }

    var onRouteSelected: ((SettingsRouteID) -> Void)?

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        let stackSize = routesStackView.fittingSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
        )
    }

    private let routesStackView = NSStackView()
    private var routeButtonsByID: [SettingsRouteID: RouteButton] = [:]

    override init(frame frameRect: NSRect) {
        routeItems = []
        super.init(frame: frameRect)
        configureView()
        applyRouteItems()
    }

    convenience init(routeItems: [SettingsRouteItem]) {
        self.init(frame: .zero)
        self.routeItems = routeItems
        applyRouteItems()
    }

    required init?(coder: NSCoder) {
        routeItems = []
        super.init(coder: coder)
        configureView()
        applyRouteItems()
    }

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("settings-index-page")
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = Style.panelCornerRadius

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        routesStackView.orientation = .vertical
        routesStackView.alignment = .width
        routesStackView.distribution = .fill
        routesStackView.spacing = Style.routeSpacing
        routesStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(routesStackView)

        NSLayoutConstraint.activate([
            routesStackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.contentInsets.left
            ),
            routesStackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.contentInsets.right
            ),
            routesStackView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.contentInsets.top
            ),
            routesStackView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.contentInsets.bottom
            )
        ])
    }

    private func applyRouteItems() {
        removeObsoleteButtons(notIn: Set(routeItems.map(\.route)))

        let orderedButtons = routeItems.map { routeItem -> NSView in
            button(for: routeItem)
        }

        replaceArrangedSubviews(
            in: routesStackView,
            with: orderedButtons
        )

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    private func button(for routeItem: SettingsRouteItem) -> RouteButton {
        if let existingButton = routeButtonsByID[routeItem.route] {
            existingButton.apply(routeItem: routeItem)
            return existingButton
        }

        let button = RouteButton(frame: .zero)
        button.target = self
        button.action = #selector(handleRouteButtonTap(_:))
        button.apply(routeItem: routeItem)
        routeButtonsByID[routeItem.route] = button
        return button
    }

    private func removeObsoleteButtons(notIn validRoutes: Set<SettingsRouteID>) {
        let obsoleteRoutes = routeButtonsByID.keys.filter { !validRoutes.contains($0) }

        for route in obsoleteRoutes {
            guard let button = routeButtonsByID.removeValue(forKey: route) else {
                continue
            }

            if let stackView = button.superview as? NSStackView {
                stackView.removeArrangedSubview(button)
            }
            button.removeFromSuperview()
        }
    }

    private func replaceArrangedSubviews(
        in stackView: NSStackView,
        with views: [NSView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? NSStackView {
                parentStackView.removeArrangedSubview(view)
            }
            view.removeFromSuperview()
            stackView.addArrangedSubview(view)
        }
    }

    @objc
    private func handleRouteButtonTap(_ sender: RouteButton) {
        guard let route = sender.route else {
            return
        }

        onRouteSelected?(route)
    }
}

private final class RouteButton: NSButton {
    var route: SettingsRouteID?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureButton()
    }

    override var intrinsicContentSize: NSSize {
        let baseSize = super.intrinsicContentSize
        return NSSize(width: baseSize.width, height: max(baseSize.height, Style.minimumButtonHeight))
    }

    func apply(routeItem: SettingsRouteItem) {
        route = routeItem.route
        identifier = NSUserInterfaceItemIdentifier(
            SettingsNavigationAccessibility.routeItemIdentifier(
                for: routeItem.route
            )
        )
        setAccessibilityLabel(routeItem.title)
        toolTip = routeItem.subtitle.map {
            "\(routeItem.title) - \($0)"
        } ?? routeItem.title
        title = routeItem.title
        image = NSImage(
            systemSymbolName: "chevron.right",
            accessibilityDescription: routeItem.title
        )
        imagePosition = .imageTrailing
        contentTintColor = .secondaryLabelColor
        if let buttonCell = cell as? NSButtonCell {
            buttonCell.lineBreakMode = .byTruncatingTail
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Style.fontSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        attributedTitle = NSAttributedString(
            string: routeItem.title,
            attributes: attributes
        )
    }

    private func configureButton() {
        isBordered = false
        bezelStyle = .regularSquare
        imagePosition = .imageTrailing
        imageScaling = .scaleProportionallyDown
        alignment = .left
        wantsLayer = true
        layer?.cornerRadius = Style.buttonCornerRadius
        layer?.backgroundColor = NSColor.controlColor.cgColor
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}

private enum Style {
    static let contentInsets = NSEdgeInsets(
        top: 10,
        left: 12,
        bottom: 10,
        right: 12
    )
    static let panelCornerRadius: CGFloat = 14
    static let routeSpacing: CGFloat = 10
    static let minimumButtonHeight: CGFloat = 38
    static let buttonCornerRadius: CGFloat = 10
    static let fontSize: CGFloat = 13
}
#endif

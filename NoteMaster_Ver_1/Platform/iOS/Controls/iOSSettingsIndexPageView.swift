//
//  iOSSettingsIndexPageView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/31.
//

#if os(iOS)
import Foundation
import UIKit

final class iOSSettingsIndexPageView: UIView {
    var routeItems: [SettingsRouteItem] {
        didSet {
            guard oldValue != routeItems else {
                return
            }

            applyRouteItems()
        }
    }

    var onRouteSelected: ((SettingsRouteID) -> Void)?

    override var intrinsicContentSize: CGSize {
        let stackSize = routesStackView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: directionalLayoutMargins.top + stackSize.height + directionalLayoutMargins.bottom
        )
    }

    private let routesStackView = UIStackView()
    private var routeButtonsByID: [SettingsRouteID: RouteButton] = [:]

    override init(frame: CGRect) {
        routeItems = []
        super.init(frame: frame)
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
        accessibilityIdentifier = "settings-index-page"
        directionalLayoutMargins = Style.contentInsets
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = Style.panelCornerRadius
        layer.cornerCurve = .continuous

        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        routesStackView.axis = .vertical
        routesStackView.alignment = .fill
        routesStackView.distribution = .fill
        routesStackView.spacing = Style.routeSpacing
        routesStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(routesStackView)

        NSLayoutConstraint.activate([
            routesStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            routesStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            routesStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            routesStackView.bottomAnchor.constraint(
                lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor
            )
        ])
    }

    private func applyRouteItems() {
        removeObsoleteButtons(notIn: Set(routeItems.map(\.route)))

        let orderedButtons = routeItems.map { routeItem -> UIButton in
            button(for: routeItem)
        }

        replaceArrangedSubviews(
            in: routesStackView,
            with: orderedButtons
        )

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func button(for routeItem: SettingsRouteItem) -> RouteButton {
        if let existingButton = routeButtonsByID[routeItem.route] {
            existingButton.apply(routeItem: routeItem)
            return existingButton
        }

        let button = RouteButton(type: .system)
        button.addTarget(
            self,
            action: #selector(handleRouteButtonTap(_:)),
            for: .touchUpInside
        )
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

            if let stackView = button.superview as? UIStackView {
                stackView.removeArrangedSubview(button)
            }
            button.removeFromSuperview()
        }
    }

    private func replaceArrangedSubviews(
        in stackView: UIStackView,
        with views: [UIView]
    ) {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        for view in views {
            if let parentStackView = view.superview as? UIStackView {
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

private final class RouteButton: UIButton {
    var route: SettingsRouteID?

    func apply(routeItem: SettingsRouteItem) {
        route = routeItem.route
        accessibilityIdentifier = SettingsNavigationAccessibility.routeItemIdentifier(
            for: routeItem.route
        )
        accessibilityLabel = routeItem.subtitle.map {
            "\(routeItem.title), \($0)"
        } ?? routeItem.title

        var configuration = configuration ?? UIButton.Configuration.filled()
        configuration.title = routeItem.title
        configuration.subtitle = routeItem.subtitle
        configuration.image = UIImage(systemName: "chevron.right")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Style.chevronSpacing
        configuration.titleAlignment = .leading
        configuration.buttonSize = .large
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = .secondarySystemFill
        configuration.baseForegroundColor = .label
        configuration.contentInsets = Style.buttonContentInsets
        self.configuration = configuration
    }

    override func updateConfiguration() {
        super.updateConfiguration()

        guard route != nil else {
            return
        }

        var configuration = configuration ?? UIButton.Configuration.filled()
        configuration.baseBackgroundColor = isHighlighted
            ? .tertiarySystemFill
            : .secondarySystemFill
        self.configuration = configuration
    }
}

private enum Style {
    static let contentInsets = NSDirectionalEdgeInsets(
        top: 10,
        leading: 12,
        bottom: 10,
        trailing: 12
    )
    static let panelCornerRadius: CGFloat = 14
    static let routeSpacing: CGFloat = 10
    static let chevronSpacing: CGFloat = 12
    static let buttonContentInsets = NSDirectionalEdgeInsets(
        top: 10,
        leading: 14,
        bottom: 10,
        trailing: 14
    )
}
#endif

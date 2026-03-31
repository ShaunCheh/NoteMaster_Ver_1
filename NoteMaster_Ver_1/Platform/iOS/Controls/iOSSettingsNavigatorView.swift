//
//  iOSSettingsNavigatorView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/31.
//

#if os(iOS)
import Foundation
import UIKit

final class iOSSettingsNavigatorView: UIView {
    var model: SettingsNavigationModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModelUpdate()
        }
    }

    var onEvent: ((SettingsPanelEvent) -> Void)?

    var onPresentationStateChange: ((SettingsNavigationPresentationState) -> Void)? {
        didSet {
            notifyPresentationStateChange()
        }
    }

    override var intrinsicContentSize: CGSize {
        guard let currentPageView else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 0)
        }

        let pageSize = currentPageView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: pageSize.height
        )
    }

    private enum TransitionDirection: Equatable {
        case none
        case push
        case pop

        func enteringOffset(for width: CGFloat) -> CGFloat {
            switch self {
            case .none:
                return 0
            case .push:
                return width
            case .pop:
                return -width * 0.28
            }
        }

        func exitingOffset(for width: CGFloat) -> CGFloat {
            switch self {
            case .none:
                return 0
            case .push:
                return -width * 0.28
            case .pop:
                return width
            }
        }
    }

    private let pageHostView = UIView()
    private weak var currentPageView: UIView?
    private var currentPageConstraints: [NSLayoutConstraint] = []
    private var routeStack: [SettingsRouteID]

    override init(frame: CGRect) {
        model = .empty
        routeStack = SettingsNavigationModel.empty.reconciledPath([])
        super.init(frame: frame)
        configureView()
        replaceCurrentPage(
            with: makePageView(for: routeStack.last ?? model.rootRoute),
            transitionDirection: .none,
            animated: false
        )
    }

    convenience init(model: SettingsNavigationModel) {
        self.init(frame: .zero)
        self.model = model
        routeStack = model.reconciledPath([])
        replaceCurrentPage(
            with: makePageView(for: routeStack.last ?? model.rootRoute),
            transitionDirection: .none,
            animated: false
        )
    }

    required init?(coder: NSCoder) {
        model = .empty
        routeStack = SettingsNavigationModel.empty.reconciledPath([])
        super.init(coder: coder)
        configureView()
        replaceCurrentPage(
            with: makePageView(for: routeStack.last ?? model.rootRoute),
            transitionDirection: .none,
            animated: false
        )
    }

    func pop(animated: Bool = true) {
        guard routeStack.count > 1 else {
            return
        }

        routeStack.removeLast()
        replaceCurrentPage(
            with: makePageView(for: routeStack.last ?? model.rootRoute),
            transitionDirection: .pop,
            animated: animated
        )
    }

    private func configureView() {
        accessibilityIdentifier = SettingsNavigationAccessibility.navigatorIdentifier
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        pageHostView.translatesAutoresizingMaskIntoConstraints = false
        pageHostView.clipsToBounds = true

        addSubview(pageHostView)

        NSLayoutConstraint.activate([
            pageHostView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pageHostView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pageHostView.topAnchor.constraint(equalTo: topAnchor),
            pageHostView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func applyModelUpdate() {
        let previousPath = routeStack
        let reconciledPath = model.reconciledPath(routeStack)
        let transitionDirection = transitionDirection(
            from: previousPath,
            to: reconciledPath
        )
        let didCurrentRouteChange = previousPath.last != reconciledPath.last

        routeStack = reconciledPath
        replaceCurrentPage(
            with: makePageView(for: routeStack.last ?? model.rootRoute),
            transitionDirection: transitionDirection,
            animated: didCurrentRouteChange && transitionDirection != .none
        )
    }

    private func push(_ route: SettingsRouteID, animated: Bool = true) {
        let reconciledPath = model.reconciledPath(routeStack + [route])
        guard reconciledPath != routeStack else {
            return
        }

        routeStack = reconciledPath
        replaceCurrentPage(
            with: makePageView(for: routeStack.last ?? model.rootRoute),
            transitionDirection: .push,
            animated: animated
        )
    }

    private func makePageView(for route: SettingsRouteID) -> UIView {
        guard let page = model.page(for: route) else {
            return UIView()
        }

        switch page.content {
        case let .index(routeItems):
            let indexPageView = iOSSettingsIndexPageView(routeItems: routeItems)
            indexPageView.onRouteSelected = { [weak self] selectedRoute in
                self?.push(selectedRoute)
            }
            return indexPageView
        case let .form(sections):
            let panelView = iOSSettingsPanelView(
                model: SettingsPanelModel(sections: sections)
            )
            panelView.onEvent = onEvent
            return panelView
        }
    }

    private func replaceCurrentPage(
        with newPageView: UIView,
        transitionDirection: TransitionDirection,
        animated: Bool
    ) {
        let oldPageView = currentPageView
        let oldSnapshot = animated
            ? oldPageView?.snapshotView(afterScreenUpdates: false)
            : nil

        installCurrentPageView(newPageView)
        let pageHostWidth = max(pageHostView.bounds.width, bounds.width, 1)

        if let oldSnapshot {
            oldSnapshot.frame = pageHostView.bounds
            oldSnapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            pageHostView.addSubview(oldSnapshot)
        }

        if animated {
            newPageView.transform = CGAffineTransform(
                translationX: transitionDirection.enteringOffset(for: pageHostWidth),
                y: 0
            )
        } else {
            newPageView.transform = .identity
        }

        let animations = {
            newPageView.transform = .identity
            oldSnapshot?.transform = CGAffineTransform(
                translationX: transitionDirection.exitingOffset(for: pageHostWidth),
                y: 0
            )
            oldSnapshot?.alpha = 0
        }

        let completion: (Bool) -> Void = { _ in
            oldSnapshot?.removeFromSuperview()
            self.notifyPresentationStateChange()
        }

        if animated, transitionDirection != .none {
            UIView.animate(
                withDuration: Style.transitionDuration,
                delay: 0,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: animations,
                completion: completion
            )
        } else {
            animations()
            completion(true)
        }
    }

    private func installCurrentPageView(_ pageView: UIView) {
        NSLayoutConstraint.deactivate(currentPageConstraints)
        currentPageConstraints = []
        currentPageView?.removeFromSuperview()

        if pageView.superview != nil {
            pageView.removeFromSuperview()
        }

        pageView.translatesAutoresizingMaskIntoConstraints = false
        pageHostView.addSubview(pageView)
        currentPageConstraints = [
            pageView.leadingAnchor.constraint(equalTo: pageHostView.leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: pageHostView.trailingAnchor),
            pageView.topAnchor.constraint(equalTo: pageHostView.topAnchor),
            pageView.bottomAnchor.constraint(equalTo: pageHostView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(currentPageConstraints)
        currentPageView = pageView
        pageHostView.accessibilityIdentifier = SettingsNavigationAccessibility.pageIdentifier(
            for: routeStack.last ?? model.rootRoute
        )
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func transitionDirection(
        from previousPath: [SettingsRouteID],
        to nextPath: [SettingsRouteID]
    ) -> TransitionDirection {
        if nextPath.count < previousPath.count {
            return .pop
        }
        if nextPath.count > previousPath.count {
            return .push
        }
        return .none
    }

    private func notifyPresentationStateChange() {
        guard let currentRoute = routeStack.last,
              let page = model.page(for: currentRoute) else {
            onPresentationStateChange?(
                SettingsNavigationPresentationState(
                    title: SettingsRouteID.root.fallbackTitle,
                    showsBackButton: false
                )
            )
            return
        }

        onPresentationStateChange?(
            SettingsNavigationPresentationState(
                title: page.title,
                showsBackButton: routeStack.count > 1
            )
        )
    }
}

private enum Style {
    static let transitionDuration: TimeInterval = 0.24
}
#endif

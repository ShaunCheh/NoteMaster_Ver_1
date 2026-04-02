//
//  macOSSettingsNavigatorView.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/31.
//

#if os(macOS)
import Foundation
import AppKit
import QuartzCore

final class macOSSettingsNavigatorView: NSView {
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

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()

        guard let currentPageView else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }

        let pageSize = currentPageView.fittingSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
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

    private let pageHostView = NSView()
    private weak var currentPageView: NSView?
    private var currentPageConstraints: [NSLayoutConstraint] = []
    private var routeStack: [SettingsRouteID]

    override init(frame frameRect: NSRect) {
        model = .empty
        routeStack = SettingsNavigationModel.empty.reconciledPath([])
        super.init(frame: frameRect)
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
        identifier = NSUserInterfaceItemIdentifier(
            SettingsNavigationAccessibility.navigatorIdentifier
        )
        wantsLayer = true
        layer?.masksToBounds = true
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        pageHostView.translatesAutoresizingMaskIntoConstraints = false
        pageHostView.wantsLayer = true
        pageHostView.layer?.masksToBounds = true

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

        macOSSettingsMutationTrace.logIfActive(
            "navigator applyModelUpdate previousPath=\(previousPath) nextPath=\(reconciledPath) didCurrentRouteChange=\(didCurrentRouteChange)"
        )

        routeStack = reconciledPath
        let currentRoute = routeStack.last ?? model.rootRoute
        let currentPageModel = model.page(for: currentRoute)

        if !didCurrentRouteChange,
           let currentPageModel,
           updateCurrentPageIfPossible(
                with: currentPageModel,
                route: currentRoute
           ) {
            return
        }

        replaceCurrentPage(
            with: makePageView(for: currentPageModel, route: currentRoute),
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

    private func makePageView(for route: SettingsRouteID) -> NSView {
        makePageView(for: model.page(for: route), route: route)
    }

    private func makePageView(
        for page: SettingsPageModel?,
        route: SettingsRouteID
    ) -> NSView {
        guard let page else {
            let placeholderView = NSView()
            placeholderView.identifier = NSUserInterfaceItemIdentifier(
                SettingsNavigationAccessibility.pageIdentifier(for: route)
            )
            return placeholderView
        }

        switch page.content {
        case let .index(routeItems):
            let indexPageView = macOSSettingsIndexPageView(routeItems: routeItems)
            indexPageView.onRouteSelected = { [weak self] selectedRoute in
                self?.push(selectedRoute)
            }
            return indexPageView
        case let .form(sections):
            let panelView = macOSSettingsPanelView(
                model: SettingsPanelModel(sections: sections)
            )
            panelView.onEvent = onEvent
            return panelView
        }
    }

    private func updateCurrentPageIfPossible(
        with page: SettingsPageModel,
        route: SettingsRouteID
    ) -> Bool {
        switch (page.content, currentPageView) {
        case let (.index(routeItems), indexPageView as macOSSettingsIndexPageView):
            indexPageView.onRouteSelected = { [weak self] selectedRoute in
                self?.push(selectedRoute)
            }
            indexPageView.routeItems = routeItems
        case let (.form(sections), panelView as macOSSettingsPanelView):
            panelView.onEvent = onEvent
            panelView.model = SettingsPanelModel(sections: sections)
        default:
            return false
        }

        pageHostView.identifier = NSUserInterfaceItemIdentifier(
            SettingsNavigationAccessibility.pageIdentifier(for: route)
        )
        invalidateIntrinsicContentSize()
        needsLayout = true
        macOSSettingsMutationTrace.logIfActive(
            "navigator applyModelUpdate reuse currentPage route=\(String(describing: route)) page=\(macOSSettingsMutationTrace.describe(view: currentPageView))"
        )
        notifyPresentationStateChange()
        return true
    }

    private func replaceCurrentPage(
        with newPageView: NSView,
        transitionDirection: TransitionDirection,
        animated: Bool
    ) {
        macOSSettingsMutationTrace.logIfActive(
            "navigator replaceCurrentPage newPage=\(macOSSettingsMutationTrace.describe(view: newPageView)) transition=\(String(describing: transitionDirection)) animated=\(animated) \(macOSSettingsMutationTrace.containsActiveSource(in: currentPageView))"
        )
        let oldPageView = currentPageView
        let oldSnapshotView = animated ? snapshotView(for: oldPageView) : nil

        installCurrentPageView(newPageView)
        layoutSubtreeIfNeeded()

        let newSnapshotView = animated ? snapshotView(for: newPageView) : nil
        let pageHostWidth = max(pageHostView.bounds.width, bounds.width, 1)

        if let oldSnapshotView {
            oldSnapshotView.frame = pageHostView.bounds
            pageHostView.addSubview(oldSnapshotView)
        }

        if let newSnapshotView {
            newSnapshotView.frame = pageHostView.bounds.offsetBy(
                dx: transitionDirection.enteringOffset(for: pageHostWidth),
                dy: 0
            )
            pageHostView.addSubview(newSnapshotView)
            newPageView.alphaValue = 0
        }

        let animations = {
            oldSnapshotView?.animator().setFrameOrigin(
                CGPoint(
                x: transitionDirection.exitingOffset(for: pageHostWidth),
                y: 0
                )
            )
            oldSnapshotView?.animator().alphaValue = 0
            newSnapshotView?.animator().setFrameOrigin(.zero)
            newSnapshotView?.animator().alphaValue = 1
        }

        let completion = {
            oldSnapshotView?.removeFromSuperview()
            newSnapshotView?.removeFromSuperview()
            newPageView.alphaValue = 1
            self.notifyPresentationStateChange()
        }

        if animated, transitionDirection != .none {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Style.transitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animations()
            } completionHandler: {
                completion()
            }
        } else {
            animations()
            completion()
        }
    }

    private func installCurrentPageView(_ pageView: NSView) {
        macOSSettingsMutationTrace.logIfActive(
            "navigator installCurrentPageView remove oldPage=\(macOSSettingsMutationTrace.describe(view: currentPageView)) \(macOSSettingsMutationTrace.containsActiveSource(in: currentPageView))"
        )
        NSLayoutConstraint.deactivate(currentPageConstraints)
        currentPageConstraints = []
        currentPageView?.removeFromSuperview()

        if pageView.superview != nil {
            pageView.removeFromSuperview()
        }

        pageView.translatesAutoresizingMaskIntoConstraints = false
        pageHostView.addSubview(pageView)
        macOSSettingsMutationTrace.logIfActive(
            "navigator installCurrentPageView add newPage=\(macOSSettingsMutationTrace.describe(view: pageView)) \(macOSSettingsMutationTrace.containsActiveSource(in: pageView))"
        )
        currentPageConstraints = [
            pageView.leadingAnchor.constraint(equalTo: pageHostView.leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: pageHostView.trailingAnchor),
            pageView.topAnchor.constraint(equalTo: pageHostView.topAnchor),
            pageView.bottomAnchor.constraint(equalTo: pageHostView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(currentPageConstraints)
        currentPageView = pageView
        pageHostView.identifier = NSUserInterfaceItemIdentifier(
            SettingsNavigationAccessibility.pageIdentifier(
                for: routeStack.last ?? model.rootRoute
            )
        )
        invalidateIntrinsicContentSize()
        needsLayout = true
        macOSSettingsMutationTrace.logIfActive(
            "navigator installCurrentPageView layoutSubtreeIfNeeded pageHost=\(macOSSettingsMutationTrace.describe(view: pageHostView))"
        )
        layoutSubtreeIfNeeded()
    }

    private func snapshotView(for view: NSView?) -> NSImageView? {
        guard let view else {
            return nil
        }

        let bounds = view.bounds
        guard bounds.width > 0,
              bounds.height > 0,
              let bitmapImageRep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }

        view.cacheDisplay(in: bounds, to: bitmapImageRep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmapImageRep)

        let imageView = NSImageView(frame: pageHostView.bounds)
        imageView.image = image
        imageView.imageScaling = .scaleAxesIndependently
        imageView.alphaValue = 1
        return imageView
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
}

private enum Style {
    static let transitionDuration: TimeInterval = 0.24
}
#endif

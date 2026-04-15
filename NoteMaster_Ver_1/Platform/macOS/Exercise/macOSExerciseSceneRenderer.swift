//
//  macOSExerciseSceneRenderer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

#if os(macOS)
import AppKit

final class macOSExerciseSceneRenderer {
    struct Metrics {
        var surfaceSpacing: CGFloat
        var floatingButtonInset: CGFloat
        var floatingButtonSize: CGFloat
        var contentSizeTolerance: CGFloat
    }

    private enum HostedViewLayout: Equatable {
        case fill
        case verticallyCentered
    }

    private enum SceneHostPathComponent: Hashable {
        case splitChild(Int)
        case overlayBase
        case overlayFloatingContainer
        case collapsibleMain
        case collapsibleAccessory

        var identifierToken: String {
            switch self {
            case let .splitChild(index):
                return "split-\(index)"
            case .overlayBase:
                return "overlay-base"
            case .overlayFloatingContainer:
                return "overlay-floating"
            case .collapsibleMain:
                return "collapsible-main"
            case .collapsibleAccessory:
                return "collapsible-accessory"
            }
        }
    }

    private struct SceneHostPath: Hashable {
        static let root = SceneHostPath(components: [])

        var components: [SceneHostPathComponent]

        func appending(_ component: SceneHostPathComponent) -> SceneHostPath {
            SceneHostPath(components: components + [component])
        }

        var depth: Int {
            components.count
        }

        var identifierToken: String {
            components.isEmpty
                ? "root"
                : components.map(\.identifierToken).joined(separator: "-")
        }
    }

    private final class SceneHostView: NSView {
        let path: SceneHostPath

        init(path: SceneHostPath) {
            self.path = path
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            identifier = NSUserInterfaceItemIdentifier(
                "exercise-scene-host-\(path.identifierToken)"
            )
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func applyContainerOutline(color: NSColor?) {
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.cornerRadius = color == nil ? 0 : 14
            layer?.borderWidth = color == nil ? 0 : 2
            layer?.borderColor = color?.withAlphaComponent(0.9).cgColor
        }
    }

    private final class SurfaceSlotView: NSView {
        let surfaceID: ExerciseSurfaceID

        private var hostedViewConstraints: [NSLayoutConstraint] = []
        private weak var hostedView: NSView?
        private var hostedViewLayout: HostedViewLayout = .fill

        init(surfaceID: ExerciseSurfaceID) {
            self.surfaceID = surfaceID
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            identifier = NSUserInterfaceItemIdentifier(
                "exercise-surface-slot-\(surfaceID.rawValue)"
            )
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func install(
            _ childView: NSView,
            layout: HostedViewLayout = .fill
        ) {
            let needsSuperviewMove = childView.superview !== self
            let needsConstraintRefresh = hostedView !== childView
                || hostedViewLayout != layout
            guard needsSuperviewMove || needsConstraintRefresh else {
                return
            }

            macOSSettingsMutationTrace.logIfActive(
                "renderer slot install childView=\(macOSSettingsMutationTrace.describe(view: childView)) slotView=\(macOSSettingsMutationTrace.describe(view: self))"
            )
            NSLayoutConstraint.deactivate(hostedViewConstraints)
            hostedViewConstraints = []
            if needsSuperviewMove {
                childView.removeFromSuperview()
            }
            childView.translatesAutoresizingMaskIntoConstraints = false
            if needsSuperviewMove {
                addSubview(childView)
            }
            hostedView = childView
            hostedViewLayout = layout
            hostedViewConstraints = constraints(
                for: childView,
                layout: layout
            )
            NSLayoutConstraint.activate(hostedViewConstraints)
        }

        private func constraints(
            for childView: NSView,
            layout: HostedViewLayout
        ) -> [NSLayoutConstraint] {
            switch layout {
            case .fill:
                return [
                    childView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    childView.trailingAnchor.constraint(equalTo: trailingAnchor),
                    childView.topAnchor.constraint(equalTo: topAnchor),
                    childView.bottomAnchor.constraint(equalTo: bottomAnchor)
                ]
            case .verticallyCentered:
                let topConstraint = childView.topAnchor.constraint(
                    greaterThanOrEqualTo: topAnchor
                )
                topConstraint.priority = .defaultHigh

                let bottomConstraint = childView.bottomAnchor.constraint(
                    lessThanOrEqualTo: bottomAnchor
                )
                bottomConstraint.priority = .defaultHigh

                return [
                    childView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    childView.trailingAnchor.constraint(equalTo: trailingAnchor),
                    childView.centerYAnchor.constraint(equalTo: centerYAnchor),
                    topConstraint,
                    bottomConstraint
                ]
            }
        }
    }

    private struct SceneSyncState {
        var requiredHostPaths: Set<SceneHostPath> = [.root]
        var activeSurfaceOrder: [ExerciseSurfaceID] = []
        var didChangeStructure = false
    }

    let sceneContainerView = NSView()

    private let sceneContentView = NSView()
    private let rootHostView = SceneHostView(path: .root)
    private let fretboardHostView = NSView()
    private let fretboardViewportScrollView = NSScrollView()
    private let fretboardScrollContentView = NSView()

    private let safeAreaHeightAnchor: NSLayoutDimension
    private let metrics: Metrics
    private let sequenceRegenerateButton: NSButton
    private let staffView: macOSStaffView
    private let targetNotePromptView: macOSTargetNotePromptView
    private let naturalNoteStripView: macOSNaturalNoteStripView
    private let pianoSurfaceView: NSView
    private let fretboardView: macOSFretboardView

    private var currentPresentationState: ExercisePresentationState?
    private var currentFretboardDisplayState = FretboardDisplayState.default
    private var currentDebugState = SettingsDebugState()

    private var activeSceneConstraints: [NSLayoutConstraint] = []
    private var sceneHostViews: [SceneHostPath: SceneHostView] = [:]
    private var surfaceSlotViews: [ExerciseSurfaceID: SurfaceSlotView] = [:]
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?
    private var horizontalFretboardDocumentWidthConstraint: NSLayoutConstraint?
    private var horizontalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardDocumentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var fretboardContentCenterXConstraint: NSLayoutConstraint?

    init(
        safeAreaHeightAnchor: NSLayoutDimension,
        metrics: Metrics,
        sequenceRegenerateButton: NSButton,
        staffView: macOSStaffView,
        targetNotePromptView: macOSTargetNotePromptView,
        naturalNoteStripView: macOSNaturalNoteStripView,
        pianoSurfaceView: NSView,
        fretboardView: macOSFretboardView
    ) {
        self.safeAreaHeightAnchor = safeAreaHeightAnchor
        self.metrics = metrics
        self.sequenceRegenerateButton = sequenceRegenerateButton
        self.staffView = staffView
        self.targetNotePromptView = targetNotePromptView
        self.naturalNoteStripView = naturalNoteStripView
        self.pianoSurfaceView = pianoSurfaceView
        self.fretboardView = fretboardView

        sceneHostViews[.root] = rootHostView
        configureStaticHierarchy()
    }

    @discardableResult
    func render(
        presentationState: ExercisePresentationState,
        fretboardDisplayState: FretboardDisplayState,
        debugState: SettingsDebugState
    ) -> Bool {
        currentPresentationState = presentationState
        currentFretboardDisplayState = fretboardDisplayState
        currentDebugState = debugState

        let didChangeStructure = syncSceneHierarchy(for: presentationState.scene.root)
        updateSurfaceVisibility()
        applyCurrentFretboardLayoutState()
        return didChangeStructure
    }

    func applyFretboardDisplayState(_ fretboardDisplayState: FretboardDisplayState) {
        currentFretboardDisplayState = fretboardDisplayState
        applyCurrentFretboardLayoutState()
    }

    func handleLayoutPass() -> Bool {
        let didUpdateContentSizeConstraints = syncVerticalFretboardContentSizeConstraints()
        let didUpdateViewportPresentation = updateFretboardViewportPresentation()
        return didUpdateContentSizeConstraints || didUpdateViewportPresentation
    }

    private var isShowingFretboard: Bool {
        currentPresentationState?.isSurfaceVisible(.fretboard) ?? false
    }

    private var prefersFlexibleVerticalFretboardHeight: Bool {
        currentPresentationState?.scene.hasMixedMainAxisSizing(
            along: .vertical,
            containing: .fretboard
        ) ?? false
    }

    private var fretboardHeightPolicy: ExerciseFretboardHeightPolicy {
        currentPresentationState?.fretboardLayoutContract.heightPolicy
            ?? .followViewportRatio
    }

    private func configureStaticHierarchy() {
        sceneContainerView.translatesAutoresizingMaskIntoConstraints = false
        sceneContentView.translatesAutoresizingMaskIntoConstraints = false
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
        fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
        fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false
        naturalNoteStripView.translatesAutoresizingMaskIntoConstraints = false
        pianoSurfaceView.translatesAutoresizingMaskIntoConstraints = false
        sequenceRegenerateButton.translatesAutoresizingMaskIntoConstraints = false

        fretboardViewportScrollView.drawsBackground = false
        fretboardViewportScrollView.borderType = .noBorder
        fretboardViewportScrollView.hasVerticalScroller = false
        fretboardViewportScrollView.hasHorizontalScroller = false
        fretboardViewportScrollView.autohidesScrollers = true
        fretboardViewportScrollView.documentView = fretboardScrollContentView

        sceneContainerView.addSubview(sceneContentView)
        sceneContentView.addSubview(rootHostView)
        sceneContainerView.addSubview(sequenceRegenerateButton)
        fretboardHostView.addSubview(fretboardViewportScrollView)
        fretboardScrollContentView.addSubview(fretboardView)
        configureSurfaceSlots()

        horizontalFretboardDocumentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentView.widthAnchor
        )
        horizontalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
            equalTo: fretboardScrollContentView.widthAnchor
        )
        verticalFretboardDocumentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
            equalToConstant: currentFretboardDisplayState.configuration.verticalContentWidth(
                forViewportHeight: currentFretboardDisplayState.configuration.preferredHeight
            )
        )
        verticalFretboardDocumentWidthConstraint?.priority = .required
        verticalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
            equalToConstant: currentFretboardDisplayState.configuration.verticalContentWidth(
                forViewportHeight: currentFretboardDisplayState.configuration.preferredHeight
            )
        )
        verticalFretboardContentWidthConstraint?.priority = .required
        fretboardContentCenterXConstraint = fretboardView.centerXAnchor.constraint(
            equalTo: fretboardScrollContentView.centerXAnchor
        )

        NSLayoutConstraint.activate([
            sceneContentView.leadingAnchor.constraint(
                equalTo: sceneContainerView.leadingAnchor
            ),
            sceneContentView.trailingAnchor.constraint(
                equalTo: sceneContainerView.trailingAnchor
            ),
            sceneContentView.topAnchor.constraint(
                equalTo: sceneContainerView.topAnchor
            ),
            sceneContentView.bottomAnchor.constraint(
                equalTo: sceneContainerView.bottomAnchor
            ),
            rootHostView.leadingAnchor.constraint(equalTo: sceneContentView.leadingAnchor),
            rootHostView.trailingAnchor.constraint(equalTo: sceneContentView.trailingAnchor),
            rootHostView.topAnchor.constraint(equalTo: sceneContentView.topAnchor),
            rootHostView.bottomAnchor.constraint(equalTo: sceneContentView.bottomAnchor),
            sequenceRegenerateButton.topAnchor.constraint(
                equalTo: sceneContainerView.topAnchor,
                constant: metrics.floatingButtonInset
            ),
            sequenceRegenerateButton.trailingAnchor.constraint(
                equalTo: sceneContainerView.trailingAnchor,
                constant: -metrics.floatingButtonInset
            ),
            sequenceRegenerateButton.widthAnchor.constraint(
                equalToConstant: metrics.floatingButtonSize
            ),
            sequenceRegenerateButton.heightAnchor.constraint(
                equalToConstant: metrics.floatingButtonSize
            ),
            fretboardViewportScrollView.leadingAnchor.constraint(
                equalTo: fretboardHostView.leadingAnchor
            ),
            fretboardViewportScrollView.trailingAnchor.constraint(
                equalTo: fretboardHostView.trailingAnchor
            ),
            fretboardViewportScrollView.topAnchor.constraint(
                equalTo: fretboardHostView.topAnchor
            ),
            fretboardViewportScrollView.bottomAnchor.constraint(
                equalTo: fretboardHostView.bottomAnchor
            ),
            fretboardScrollContentView.leadingAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentView.leadingAnchor
            ),
            fretboardScrollContentView.topAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentView.topAnchor
            ),
            fretboardScrollContentView.heightAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentView.heightAnchor
            ),
            fretboardView.topAnchor.constraint(
                equalTo: fretboardScrollContentView.topAnchor
            ),
            fretboardView.bottomAnchor.constraint(
                equalTo: fretboardScrollContentView.bottomAnchor
            ),
            fretboardContentCenterXConstraint!
        ])
    }

    private func configureSurfaceSlots() {
        for surfaceID in ExerciseSurfaceID.allCases {
            let slotView = SurfaceSlotView(surfaceID: surfaceID)
            rootHostView.addSubview(slotView)
            slotView.isHidden = true
            if let surfaceView = view(for: surfaceID) {
                slotView.install(surfaceView)
            }
            surfaceSlotViews[surfaceID] = slotView
        }
    }

    @discardableResult
    private func syncSceneHierarchy(
        for rootNode: ExerciseSceneNode
    ) -> Bool {
        macOSSettingsMutationTrace.logIfActive(
            "renderer syncSceneHierarchy begin activeHosts=\(sceneHostViews.count)"
        )
        NSLayoutConstraint.deactivate(activeSceneConstraints)
        activeSceneConstraints = []

        var state = SceneSyncState()
        sync(node: rootNode, in: rootHostView, path: .root, state: &state)
        if pruneUnusedSceneHosts(requiredPaths: state.requiredHostPaths) {
            state.didChangeStructure = true
        }
        syncSurfaceSlots(activeSurfaceOrder: state.activeSurfaceOrder)
        NSLayoutConstraint.activate(activeSceneConstraints)
        return state.didChangeStructure
    }

    private func sync(
        node: ExerciseSceneNode,
        in hostView: SceneHostView,
        path: SceneHostPath,
        state: inout SceneSyncState
    ) {
        switch node {
        case let .surface(surface):
            syncSurface(surface, in: hostView, state: &state)
        case let .split(axis, children):
            syncSplit(
                axis: axis,
                children: children,
                in: hostView,
                path: path,
                state: &state
            )
        case let .overlay(base, floating):
            syncOverlay(
                base: base,
                floating: floating,
                in: hostView,
                path: path,
                state: &state
            )
        case let .collapsible(main, accessory, isExpanded):
            syncCollapsible(
                main: main,
                accessory: accessory,
                isExpanded: isExpanded,
                in: hostView,
                path: path,
                state: &state
            )
        }
    }

    private func syncSurface(
        _ surface: ExerciseSurfaceNode,
        in hostView: SceneHostView,
        state: inout SceneSyncState
    ) {
        configurePresentationStyle(for: surface)
        guard
            let slotView = surfaceSlotViews[surface.id],
            let surfaceView = view(for: surface.id)
        else {
            return
        }

        if !state.activeSurfaceOrder.contains(surface.id) {
            state.activeSurfaceOrder.append(surface.id)
        }
        slotView.install(surfaceView, layout: hostedViewLayout(for: surface))
        slotView.isHidden = false
        placeSurfaceSlot(
            slotView,
            in: hostView,
            contentInsets: contentInsets(for: surface)
        )
    }

    private func syncSplit(
        axis: ExerciseSceneAxis,
        children: [ExerciseSceneSplitChild],
        in hostView: SceneHostView,
        path: SceneHostPath,
        state: inout SceneSyncState
    ) {
        let childHostViews = children.enumerated().map { index, child in
            let childHostPath = path.appending(.splitChild(index))
            let childHostView = ensureSceneHost(
                at: childHostPath,
                in: hostView,
                state: &state
            )
            sync(
                node: child.node,
                in: childHostView,
                path: childHostPath,
                state: &state
            )
            return childHostView
        }

        applySideBySideContainerOutlines(
            to: childHostViews,
            axis: axis,
            path: path
        )

        for (index, childHostView) in childHostViews.enumerated() {
            configureMainAxisSizing(
                children[index].mainAxisSizing,
                for: childHostView,
                axis: axis
            )
        }

        for childHostView in childHostViews {
            switch axis {
            case .vertical:
                activeSceneConstraints.append(contentsOf: [
                    childHostView.leadingAnchor.constraint(
                        equalTo: hostView.leadingAnchor
                    ),
                    childHostView.trailingAnchor.constraint(
                        equalTo: hostView.trailingAnchor
                    )
                ])
            case .horizontal:
                activeSceneConstraints.append(contentsOf: [
                    childHostView.topAnchor.constraint(
                        equalTo: hostView.topAnchor
                    ),
                    childHostView.bottomAnchor.constraint(
                        equalTo: hostView.bottomAnchor
                    )
                ])
            }
        }

        if let firstChildHostView = childHostViews.first {
            switch axis {
            case .vertical:
                activeSceneConstraints.append(
                    firstChildHostView.topAnchor.constraint(
                        equalTo: hostView.topAnchor
                    )
                )
            case .horizontal:
                activeSceneConstraints.append(
                    firstChildHostView.leadingAnchor.constraint(
                        equalTo: hostView.leadingAnchor
                    )
                )
            }
        }

        let proportionalIndices = children.indices.filter {
            children[$0].mainAxisSizing.isWeighted
        }
        let referenceIndex = proportionalIndices.first

        for index in 1..<childHostViews.count {
            let previousHostView = childHostViews[index - 1]
            let childHostView = childHostViews[index]

            switch axis {
            case .vertical:
                activeSceneConstraints.append(
                    childHostView.topAnchor.constraint(
                        equalTo: previousHostView.bottomAnchor,
                        constant: metrics.surfaceSpacing
                    )
                )
            case .horizontal:
                activeSceneConstraints.append(
                    childHostView.leadingAnchor.constraint(
                        equalTo: previousHostView.trailingAnchor,
                        constant: metrics.surfaceSpacing
                    )
                )
            }

            guard
                let referenceIndex,
                proportionalIndices.contains(index),
                index != referenceIndex
            else {
                continue
            }

            let referenceWeight = max(
                children[referenceIndex].mainAxisSizing.weightedValue ?? 1,
                0.0001
            )
            let childWeight = max(
                children[index].mainAxisSizing.weightedValue ?? 1,
                0.0001
            )
            switch axis {
            case .vertical:
                activeSceneConstraints.append(
                    childHostViews[referenceIndex].heightAnchor.constraint(
                        equalTo: childHostView.heightAnchor,
                        multiplier: referenceWeight / childWeight
                    )
                )
            case .horizontal:
                activeSceneConstraints.append(
                    childHostViews[referenceIndex].widthAnchor.constraint(
                        equalTo: childHostView.widthAnchor,
                        multiplier: referenceWeight / childWeight
                    )
                )
            }
        }

        if let lastChildHostView = childHostViews.last {
            switch axis {
            case .vertical:
                activeSceneConstraints.append(
                    lastChildHostView.bottomAnchor.constraint(
                        equalTo: hostView.bottomAnchor
                    )
                )
            case .horizontal:
                activeSceneConstraints.append(
                    lastChildHostView.trailingAnchor.constraint(
                        equalTo: hostView.trailingAnchor
                    )
                )
            }
        }
    }

    private func applySideBySideContainerOutlines(
        to childHostViews: [SceneHostView],
        axis: ExerciseSceneAxis,
        path: SceneHostPath
    ) {
        let shouldOutlineContainers = axis == .horizontal
            && path == .root
            && childHostViews.count == 2
            && currentPresentationState?.renderedSceneLayout?.arrangement == .sideBySide
            && currentDebugState.showsSideBySideContainerOutlines

        for (index, childHostView) in childHostViews.enumerated() {
            childHostView.applyContainerOutline(
                color: shouldOutlineContainers
                    ? sideBySideContainerOutlineColor(for: index)
                    : nil
            )
        }
    }

    private func sideBySideContainerOutlineColor(for index: Int) -> NSColor {
        index == 0 ? .systemRed : .systemBlue
    }

    private func ensureSceneHost(
        at path: SceneHostPath,
        in parentView: NSView,
        state: inout SceneSyncState
    ) -> SceneHostView {
        state.requiredHostPaths.insert(path)

        if let existingHostView = sceneHostViews[path] {
            if existingHostView.superview !== parentView {
                macOSSettingsMutationTrace.logIfActive(
                    "renderer reparent hostView=\(macOSSettingsMutationTrace.describe(view: existingHostView)) parentView=\(macOSSettingsMutationTrace.describe(view: parentView))"
                )
                existingHostView.removeFromSuperview()
                parentView.addSubview(existingHostView)
                state.didChangeStructure = true
            }
            return existingHostView
        }

        let childHostView = SceneHostView(path: path)
        sceneHostViews[path] = childHostView
        parentView.addSubview(childHostView)
        macOSSettingsMutationTrace.logIfActive(
            "renderer add hostView=\(macOSSettingsMutationTrace.describe(view: childHostView)) parentView=\(macOSSettingsMutationTrace.describe(view: parentView))"
        )
        state.didChangeStructure = true
        return childHostView
    }

    @discardableResult
    private func pruneUnusedSceneHosts(
        requiredPaths: Set<SceneHostPath>
    ) -> Bool {
        let unusedPaths = sceneHostViews.keys
            .filter { $0 != .root && !requiredPaths.contains($0) }
            .sorted { $0.depth > $1.depth }
        guard !unusedPaths.isEmpty else {
            return false
        }

        for unusedPath in unusedPaths {
            if let unusedHostView = sceneHostViews.removeValue(forKey: unusedPath) {
                macOSSettingsMutationTrace.logIfActive(
                    "renderer remove hostView=\(macOSSettingsMutationTrace.describe(view: unusedHostView))"
                )
                unusedHostView.removeFromSuperview()
            }
        }
        return true
    }

    private func syncSurfaceSlots(
        activeSurfaceOrder: [ExerciseSurfaceID]
    ) {
        let activeSurfaceSet = Set(activeSurfaceOrder)
        for surfaceID in ExerciseSurfaceID.allCases {
            surfaceSlotViews[surfaceID]?.isHidden = !activeSurfaceSet.contains(surfaceID)
        }

        let currentActiveOrder: [ExerciseSurfaceID] = rootHostView.subviews.compactMap { subview in
            guard
                let slotView = subview as? SurfaceSlotView,
                activeSurfaceSet.contains(slotView.surfaceID)
            else {
                return nil
            }
            return slotView.surfaceID
        }
        guard currentActiveOrder != activeSurfaceOrder else {
            return
        }

        var previousActiveSlotView: NSView?
        for surfaceID in activeSurfaceOrder {
            guard let slotView = surfaceSlotViews[surfaceID] else {
                continue
            }
            rootHostView.addSubview(
                slotView,
                positioned: .above,
                relativeTo: previousActiveSlotView
            )
            previousActiveSlotView = slotView
        }
    }

    private func placeSurfaceSlot(
        _ slotView: SurfaceSlotView,
        in hostView: NSView,
        contentInsets: NSEdgeInsets
    ) {
        activeSceneConstraints.append(contentsOf: [
            slotView.leadingAnchor.constraint(
                equalTo: hostView.leadingAnchor,
                constant: contentInsets.left
            ),
            slotView.trailingAnchor.constraint(
                equalTo: hostView.trailingAnchor,
                constant: -contentInsets.right
            ),
            slotView.topAnchor.constraint(
                equalTo: hostView.topAnchor,
                constant: contentInsets.top
            ),
            slotView.bottomAnchor.constraint(
                equalTo: hostView.bottomAnchor,
                constant: -contentInsets.bottom
            )
        ])
    }

    private func hostedViewLayout(
        for surface: ExerciseSurfaceNode
    ) -> HostedViewLayout {
        guard
            surface.isNaturalNoteStripAnswerRail,
            currentPresentationState?.naturalNoteStripRailLayout?
                .usesVerticallyCenteredHostLayout == true
        else {
            return .fill
        }

        return .verticallyCentered
    }

    private func configureMainAxisSizing(
        _ mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing,
        for childHostView: NSView,
        axis: ExerciseSceneAxis
    ) {
        resetMainAxisSizingPriorities(for: childHostView)
        switch (axis, mainAxisSizing) {
        case (_, .weighted):
            return
        case (.vertical, .fitContent):
            childHostView.setContentHuggingPriority(.required, for: .vertical)
            childHostView.setContentCompressionResistancePriority(
                .required,
                for: .vertical
            )
        case (.horizontal, .fitContent):
            childHostView.setContentHuggingPriority(.required, for: .horizontal)
            childHostView.setContentCompressionResistancePriority(
                .required,
                for: .horizontal
            )
        case let (.vertical, .fixed(size)):
            childHostView.setContentHuggingPriority(.required, for: .vertical)
            childHostView.setContentCompressionResistancePriority(
                .required,
                for: .vertical
            )
            activeSceneConstraints.append(
                childHostView.heightAnchor.constraint(equalToConstant: size)
            )
        case let (.horizontal, .fixed(size)):
            childHostView.setContentHuggingPriority(.required, for: .horizontal)
            childHostView.setContentCompressionResistancePriority(
                .required,
                for: .horizontal
            )
            activeSceneConstraints.append(
                childHostView.widthAnchor.constraint(equalToConstant: size)
            )
        }
    }

    private func resetMainAxisSizingPriorities(for hostView: NSView) {
        hostView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        hostView.setContentHuggingPriority(.defaultLow, for: .vertical)
        hostView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .vertical
        )
    }

    private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
        guard surface.id == .naturalNoteStrip else {
            return
        }

        naturalNoteStripView.applyConfiguration(
            presentationStyle: surface.presentationStyle,
            horizontalLayout:
                currentPresentationState?.naturalNoteStripHorizontalLayout,
            railLayout: currentPresentationState?.naturalNoteStripRailLayout
        )
    }

    private func syncOverlay(
        base: ExerciseSceneNode,
        floating: [ExerciseSceneNode],
        in hostView: SceneHostView,
        path: SceneHostPath,
        state: inout SceneSyncState
    ) {
        let baseHostPath = path.appending(.overlayBase)
        let baseHostView = ensureSceneHost(
            at: baseHostPath,
            in: hostView,
            state: &state
        )
        activeSceneConstraints.append(contentsOf: [
            baseHostView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            baseHostView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            baseHostView.topAnchor.constraint(equalTo: hostView.topAnchor),
            baseHostView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])
        sync(node: base, in: baseHostView, path: baseHostPath, state: &state)

        let floatingHostPath = path.appending(.overlayFloatingContainer)
        let floatingHostView = ensureSceneHost(
            at: floatingHostPath,
            in: hostView,
            state: &state
        )
        activeSceneConstraints.append(contentsOf: [
            floatingHostView.leadingAnchor.constraint(
                equalTo: hostView.leadingAnchor,
                constant: metrics.surfaceSpacing
            ),
            floatingHostView.trailingAnchor.constraint(
                equalTo: hostView.trailingAnchor,
                constant: -metrics.surfaceSpacing
            ),
            floatingHostView.bottomAnchor.constraint(
                equalTo: hostView.bottomAnchor,
                constant: -metrics.surfaceSpacing
            ),
            floatingHostView.topAnchor.constraint(
                greaterThanOrEqualTo: hostView.topAnchor,
                constant: metrics.surfaceSpacing
            )
        ])

        if floating.count == 1, let floatingNode = floating.first {
            sync(
                node: floatingNode,
                in: floatingHostView,
                path: floatingHostPath,
                state: &state
            )
        } else {
            sync(
                node: .makeSplit(
                    axis: .vertical,
                    children: floating.map {
                        ExerciseSceneSplitChild(node: $0)
                    }
                ),
                in: floatingHostView,
                path: floatingHostPath,
                state: &state
            )
        }
    }

    private func syncCollapsible(
        main: ExerciseSceneNode,
        accessory: ExerciseSceneNode,
        isExpanded: Bool,
        in hostView: SceneHostView,
        path: SceneHostPath,
        state: inout SceneSyncState
    ) {
        let mainHostPath = path.appending(.collapsibleMain)
        let mainHostView = ensureSceneHost(
            at: mainHostPath,
            in: hostView,
            state: &state
        )
        activeSceneConstraints.append(contentsOf: [
            mainHostView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            mainHostView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            mainHostView.topAnchor.constraint(equalTo: hostView.topAnchor)
        ])
        sync(node: main, in: mainHostView, path: mainHostPath, state: &state)

        guard isExpanded else {
            activeSceneConstraints.append(
                mainHostView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
            )
            return
        }

        let accessoryHostPath = path.appending(.collapsibleAccessory)
        let accessoryHostView = ensureSceneHost(
            at: accessoryHostPath,
            in: hostView,
            state: &state
        )
        activeSceneConstraints.append(contentsOf: [
            accessoryHostView.leadingAnchor.constraint(
                equalTo: hostView.leadingAnchor
            ),
            accessoryHostView.trailingAnchor.constraint(
                equalTo: hostView.trailingAnchor
            ),
            accessoryHostView.topAnchor.constraint(
                equalTo: mainHostView.bottomAnchor,
                constant: metrics.surfaceSpacing
            ),
            accessoryHostView.bottomAnchor.constraint(
                equalTo: hostView.bottomAnchor
            ),
            mainHostView.heightAnchor.constraint(
                equalTo: accessoryHostView.heightAnchor,
                multiplier: 3 / accessoryWeight(for: accessory)
            )
        ])
        sync(
            node: accessory,
            in: accessoryHostView,
            path: accessoryHostPath,
            state: &state
        )
    }

    private func updateSurfaceVisibility() {
        setVisibility(
            of: .staff,
            isHidden: !(currentPresentationState?.isSurfaceVisible(.staff) ?? false)
        )
        setVisibility(
            of: .targetPrompt,
            isHidden: !(currentPresentationState?.isSurfaceVisible(.targetPrompt) ?? false)
        )
        setVisibility(
            of: .naturalNoteStrip,
            isHidden: !(currentPresentationState?.isSurfaceVisible(.naturalNoteStrip) ?? false)
        )
        setVisibility(
            of: .fretboard,
            isHidden: !(currentPresentationState?.isSurfaceVisible(.fretboard) ?? false)
        )
        setVisibility(
            of: .piano,
            isHidden: !(currentPresentationState?.isSurfaceVisible(.piano) ?? false)
        )
    }

    private func setVisibility(
        of surfaceID: ExerciseSurfaceID,
        isHidden: Bool
    ) {
        switch surfaceID {
        case .staff:
            staffView.isHidden = isHidden
        case .targetPrompt:
            targetNotePromptView.isHidden = isHidden
        case .fretboard:
            fretboardHostView.isHidden = isHidden
        case .naturalNoteStrip:
            naturalNoteStripView.isHidden = isHidden
        case .piano:
            pianoSurfaceView.isHidden = isHidden
        }
    }

    private func view(for surfaceID: ExerciseSurfaceID) -> NSView? {
        switch surfaceID {
        case .staff:
            return staffView
        case .targetPrompt:
            return targetNotePromptView
        case .fretboard:
            return fretboardHostView
        case .naturalNoteStrip:
            return naturalNoteStripView
        case .piano:
            return pianoSurfaceView
        }
    }

    private func accessoryWeight(
        for accessoryNode: ExerciseSceneNode
    ) -> CGFloat {
        let surfaceIDs = Set(accessoryNode.surfaceNodes.map(\.id))
        let showsNaturalStrip = surfaceIDs.contains(.naturalNoteStrip)
        let showsPiano = surfaceIDs.contains(.piano)

        switch (showsNaturalStrip, showsPiano) {
        case (true, true):
            return 1.6
        case (false, true):
            return 1.3
        case (true, false):
            return 0.7
        case (false, false):
            return 1
        }
    }

    private func contentInsets(
        for surface: ExerciseSurfaceNode
    ) -> NSEdgeInsets {
        if surface.id == .piano
            || (surface.id == .naturalNoteStrip && surface.isAuxiliarySurface) {
            return NSEdgeInsets(
                top: 0,
                left: metrics.surfaceSpacing,
                bottom: 0,
                right: metrics.surfaceSpacing
            )
        }

        return NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: 0
        )
    }

    private func applyCurrentFretboardLayoutState() {
        rebuildVerticalFretboardHostHeightConstraint()
        updateFretboardLayoutModeConstraints()
    }

    private func rebuildVerticalFretboardHostHeightConstraint() {
        verticalFretboardHostHeightConstraint?.isActive = false
        verticalFretboardHostHeightConstraint = nil

        guard
            isShowingFretboard,
            fretboardHeightPolicy == .followViewportRatio
        else {
            return
        }

        verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
            equalTo: safeAreaHeightAnchor,
            multiplier: currentFretboardDisplayState.verticalHostHeightRatio
        )
        verticalFretboardHostHeightConstraint?.priority = prefersFlexibleVerticalFretboardHeight
            ? .defaultHigh
            : .required
    }

    private func updateFretboardLayoutModeConstraints() {
        guard isShowingFretboard else {
            verticalFretboardHostHeightConstraint?.isActive = false
            horizontalFretboardDocumentWidthConstraint?.isActive = false
            horizontalFretboardContentWidthConstraint?.isActive = false
            verticalFretboardDocumentWidthConstraint?.isActive = false
            verticalFretboardContentWidthConstraint?.isActive = false
            fretboardViewportScrollView.hasHorizontalScroller = false
            scrollFretboardViewport(toX: 0)
            return
        }

        let isVertical = currentFretboardDisplayState.displayMode == .vertical
        let usesViewportRatio = isVertical
            && fretboardHeightPolicy == .followViewportRatio
        verticalFretboardHostHeightConstraint?.isActive = usesViewportRatio
        horizontalFretboardDocumentWidthConstraint?.isActive = !isVertical
        horizontalFretboardContentWidthConstraint?.isActive = !isVertical
        verticalFretboardDocumentWidthConstraint?.isActive = isVertical
        verticalFretboardContentWidthConstraint?.isActive = isVertical

        if !isVertical {
            fretboardViewportScrollView.hasHorizontalScroller = false
            scrollFretboardViewport(toX: 0)
        }
    }

    private func syncVerticalFretboardContentSizeConstraints() -> Bool {
        guard
            isShowingFretboard,
            currentFretboardDisplayState.displayMode == .vertical,
            let verticalFretboardDocumentWidthConstraint,
            let verticalFretboardContentWidthConstraint
        else {
            return false
        }

        let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
        let contentWidth = fretboardView.verticalContentSize.width
        guard viewportWidth > 0, contentWidth > 0 else {
            return false
        }

        var didUpdateConstraints = false
        let documentWidth = max(viewportWidth, contentWidth)
        if abs(verticalFretboardDocumentWidthConstraint.constant - documentWidth)
            > metrics.contentSizeTolerance {
            verticalFretboardDocumentWidthConstraint.constant = documentWidth
            didUpdateConstraints = true
        }

        if abs(verticalFretboardContentWidthConstraint.constant - contentWidth)
            > metrics.contentSizeTolerance {
            verticalFretboardContentWidthConstraint.constant = contentWidth
            didUpdateConstraints = true
        }

        return didUpdateConstraints
    }

    private func updateFretboardViewportPresentation() -> Bool {
        guard isShowingFretboard else {
            let didToggleScroller = fretboardViewportScrollView.hasHorizontalScroller
            fretboardViewportScrollView.hasHorizontalScroller = false
            scrollFretboardViewport(toX: 0)
            return didToggleScroller
        }

        let isVertical = currentFretboardDisplayState.displayMode == .vertical
        guard isVertical else {
            let didToggleScroller = fretboardViewportScrollView.hasHorizontalScroller
            fretboardViewportScrollView.hasHorizontalScroller = false
            return didToggleScroller
        }

        let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
        let contentWidth = verticalFretboardContentWidthConstraint?.constant
            ?? fretboardView.verticalContentSize.width
        guard viewportWidth > 0, contentWidth > 0 else {
            return false
        }

        let needsHorizontalScroll = contentWidth
            > viewportWidth + metrics.contentSizeTolerance
        let didToggleScroller = fretboardViewportScrollView.hasHorizontalScroller
            != needsHorizontalScroll
        fretboardViewportScrollView.hasHorizontalScroller = needsHorizontalScroll

        let maxOffsetX = max(contentWidth - viewportWidth, 0)
        let currentOffsetX = fretboardViewportScrollView.contentView.bounds.origin.x
        let clampedOffsetX = needsHorizontalScroll
            ? min(max(currentOffsetX, 0), maxOffsetX)
            : 0

        if abs(currentOffsetX - clampedOffsetX) > metrics.contentSizeTolerance {
            scrollFretboardViewport(toX: clampedOffsetX)
        }

        return didToggleScroller
    }

    private func scrollFretboardViewport(toX x: CGFloat) {
        fretboardViewportScrollView.contentView.scroll(to: CGPoint(x: x, y: 0))
        fretboardViewportScrollView.reflectScrolledClipView(
            fretboardViewportScrollView.contentView
        )
    }
}
#endif

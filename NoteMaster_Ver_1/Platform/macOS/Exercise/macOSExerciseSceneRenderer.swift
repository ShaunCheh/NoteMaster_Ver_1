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

    let sceneContainerView = NSView()

    private let sceneContentView = NSView()
    private let fretboardHostView = NSView()
    private let fretboardViewportScrollView = NSScrollView()
    private let fretboardScrollContentView = NSView()

    private let safeAreaHeightAnchor: NSLayoutDimension
    private let metrics: Metrics
    private let sequenceRegenerateButton: NSButton
    private let staffView: macOSStaffView
    private let targetNotePromptView: macOSTargetNotePromptView
    private let naturalNoteStripView: macOSNaturalNoteStripView
    private let pianoAccessoryView: NSView
    private let fretboardView: macOSFretboardView

    private var currentPresentationState: ExercisePresentationState?
    private var currentFretboardDisplayState = FretboardDisplayState.default

    private var activeSceneConstraints: [NSLayoutConstraint] = []
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
        pianoAccessoryView: NSView,
        fretboardView: macOSFretboardView
    ) {
        self.safeAreaHeightAnchor = safeAreaHeightAnchor
        self.metrics = metrics
        self.sequenceRegenerateButton = sequenceRegenerateButton
        self.staffView = staffView
        self.targetNotePromptView = targetNotePromptView
        self.naturalNoteStripView = naturalNoteStripView
        self.pianoAccessoryView = pianoAccessoryView
        self.fretboardView = fretboardView

        configureStaticHierarchy()
    }

    func render(
        presentationState: ExercisePresentationState,
        fretboardDisplayState: FretboardDisplayState
    ) {
        currentPresentationState = presentationState
        currentFretboardDisplayState = fretboardDisplayState

        rebuildSceneHierarchy(for: presentationState.scene.root)
        updateSurfaceVisibility()
        rebuildVerticalFretboardHostHeightConstraint()
        updateFretboardLayoutModeConstraints()
    }

    func handleLayoutPass() {
        syncVerticalFretboardContentSizeConstraints()
        updateFretboardViewportPresentation()
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
        pianoAccessoryView.translatesAutoresizingMaskIntoConstraints = false
        sequenceRegenerateButton.translatesAutoresizingMaskIntoConstraints = false

        fretboardViewportScrollView.drawsBackground = false
        fretboardViewportScrollView.borderType = .noBorder
        fretboardViewportScrollView.hasVerticalScroller = false
        fretboardViewportScrollView.hasHorizontalScroller = false
        fretboardViewportScrollView.autohidesScrollers = true
        fretboardViewportScrollView.documentView = fretboardScrollContentView

        sceneContainerView.addSubview(sceneContentView)
        sceneContainerView.addSubview(sequenceRegenerateButton)
        fretboardHostView.addSubview(fretboardViewportScrollView)
        fretboardScrollContentView.addSubview(fretboardView)

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

    private func rebuildSceneHierarchy(
        for rootNode: ExerciseSceneNode
    ) {
        NSLayoutConstraint.deactivate(activeSceneConstraints)
        activeSceneConstraints = []
        sceneContentView.subviews.forEach { $0.removeFromSuperview() }

        let rootHostView = NSView()
        rootHostView.translatesAutoresizingMaskIntoConstraints = false
        sceneContentView.addSubview(rootHostView)
        activeSceneConstraints.append(contentsOf: [
            rootHostView.leadingAnchor.constraint(
                equalTo: sceneContentView.leadingAnchor
            ),
            rootHostView.trailingAnchor.constraint(
                equalTo: sceneContentView.trailingAnchor
            ),
            rootHostView.topAnchor.constraint(
                equalTo: sceneContentView.topAnchor
            ),
            rootHostView.bottomAnchor.constraint(
                equalTo: sceneContentView.bottomAnchor
            )
        ])
        render(node: rootNode, in: rootHostView)
        NSLayoutConstraint.activate(activeSceneConstraints)
    }

    private func render(
        node: ExerciseSceneNode,
        in hostView: NSView
    ) {
        switch node {
        case let .surface(surface):
            renderSurface(surface, in: hostView)
        case let .split(axis, children):
            renderSplit(
                axis: axis,
                children: children,
                in: hostView
            )
        case let .overlay(base, floating):
            renderOverlay(
                base: base,
                floating: floating,
                in: hostView
            )
        case let .collapsible(main, accessory, isExpanded):
            renderCollapsible(
                main: main,
                accessory: accessory,
                isExpanded: isExpanded,
                in: hostView
            )
        }
    }

    private func renderSurface(
        _ surface: ExerciseSurfaceNode,
        in hostView: NSView
    ) {
        guard let surfaceView = view(for: surface.id) else {
            return
        }
        embed(
            surfaceView,
            in: hostView,
            contentInsets: contentInsets(for: surface)
        )
    }

    private func renderSplit(
        axis: ExerciseSceneAxis,
        children: [ExerciseSceneSplitChild],
        in hostView: NSView
    ) {
        let childHostViews = children.map { _ in
            let childHostView = NSView()
            childHostView.translatesAutoresizingMaskIntoConstraints = false
            hostView.addSubview(childHostView)
            return childHostView
        }

        for (index, child) in children.enumerated() {
            render(node: child.node, in: childHostViews[index])
        }

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

    private func configureMainAxisSizing(
        _ mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing,
        for childHostView: NSView,
        axis: ExerciseSceneAxis
    ) {
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

    private func renderOverlay(
        base: ExerciseSceneNode,
        floating: [ExerciseSceneNode],
        in hostView: NSView
    ) {
        let baseHostView = NSView()
        baseHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(baseHostView)
        activeSceneConstraints.append(contentsOf: [
            baseHostView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            baseHostView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            baseHostView.topAnchor.constraint(equalTo: hostView.topAnchor),
            baseHostView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])
        render(node: base, in: baseHostView)

        let floatingHostView = NSView()
        floatingHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(floatingHostView)
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
            render(node: floatingNode, in: floatingHostView)
        } else {
            render(
                node: .makeSplit(
                    axis: .vertical,
                    children: floating.map {
                        ExerciseSceneSplitChild(node: $0)
                    }
                ),
                in: floatingHostView
            )
        }
    }

    private func renderCollapsible(
        main: ExerciseSceneNode,
        accessory: ExerciseSceneNode,
        isExpanded: Bool,
        in hostView: NSView
    ) {
        let mainHostView = NSView()
        mainHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(mainHostView)
        activeSceneConstraints.append(contentsOf: [
            mainHostView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            mainHostView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            mainHostView.topAnchor.constraint(equalTo: hostView.topAnchor)
        ])
        render(node: main, in: mainHostView)

        guard isExpanded else {
            activeSceneConstraints.append(
                mainHostView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
            )
            return
        }

        let accessoryHostView = NSView()
        accessoryHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(accessoryHostView)
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
        render(node: accessory, in: accessoryHostView)
    }

    private func embed(
        _ childView: NSView,
        in hostView: NSView,
        contentInsets: NSEdgeInsets = NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: 0
        )
    ) {
        childView.removeFromSuperview()
        childView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(childView)
        activeSceneConstraints.append(contentsOf: [
            childView.leadingAnchor.constraint(
                equalTo: hostView.leadingAnchor,
                constant: contentInsets.left
            ),
            childView.trailingAnchor.constraint(
                equalTo: hostView.trailingAnchor,
                constant: -contentInsets.right
            ),
            childView.topAnchor.constraint(
                equalTo: hostView.topAnchor,
                constant: contentInsets.top
            ),
            childView.bottomAnchor.constraint(
                equalTo: hostView.bottomAnchor,
                constant: -contentInsets.bottom
            )
        ])
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
            pianoAccessoryView.isHidden = isHidden
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
            return pianoAccessoryView
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

    private func rebuildVerticalFretboardHostHeightConstraint() {
        verticalFretboardHostHeightConstraint?.isActive = false
        verticalFretboardHostHeightConstraint = nil

        guard isShowingFretboard else {
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
        verticalFretboardHostHeightConstraint?.isActive = isVertical
        horizontalFretboardDocumentWidthConstraint?.isActive = !isVertical
        horizontalFretboardContentWidthConstraint?.isActive = !isVertical
        verticalFretboardDocumentWidthConstraint?.isActive = isVertical
        verticalFretboardContentWidthConstraint?.isActive = isVertical

        if !isVertical {
            fretboardViewportScrollView.hasHorizontalScroller = false
            scrollFretboardViewport(toX: 0)
        }
    }

    private func syncVerticalFretboardContentSizeConstraints() {
        guard
            isShowingFretboard,
            currentFretboardDisplayState.displayMode == .vertical,
            let verticalFretboardDocumentWidthConstraint,
            let verticalFretboardContentWidthConstraint
        else {
            return
        }

        let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
        let contentWidth = fretboardView.verticalContentSize.width
        guard viewportWidth > 0, contentWidth > 0 else {
            return
        }

        let documentWidth = max(viewportWidth, contentWidth)
        if abs(verticalFretboardDocumentWidthConstraint.constant - documentWidth)
            > metrics.contentSizeTolerance {
            verticalFretboardDocumentWidthConstraint.constant = documentWidth
        }

        if abs(verticalFretboardContentWidthConstraint.constant - contentWidth)
            > metrics.contentSizeTolerance {
            verticalFretboardContentWidthConstraint.constant = contentWidth
        }
    }

    private func updateFretboardViewportPresentation() {
        guard isShowingFretboard else {
            fretboardViewportScrollView.hasHorizontalScroller = false
            scrollFretboardViewport(toX: 0)
            return
        }

        let isVertical = currentFretboardDisplayState.displayMode == .vertical
        guard isVertical else {
            fretboardViewportScrollView.hasHorizontalScroller = false
            return
        }

        let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
        let contentWidth = verticalFretboardContentWidthConstraint?.constant
            ?? fretboardView.verticalContentSize.width
        guard viewportWidth > 0, contentWidth > 0 else {
            return
        }

        let needsHorizontalScroll = contentWidth
            > viewportWidth + metrics.contentSizeTolerance
        fretboardViewportScrollView.hasHorizontalScroller = needsHorizontalScroll

        let maxOffsetX = max(contentWidth - viewportWidth, 0)
        let currentOffsetX = fretboardViewportScrollView.contentView.bounds.origin.x
        let clampedOffsetX = needsHorizontalScroll
            ? min(max(currentOffsetX, 0), maxOffsetX)
            : 0

        if abs(currentOffsetX - clampedOffsetX) > metrics.contentSizeTolerance {
            scrollFretboardViewport(toX: clampedOffsetX)
        }
    }

    private func scrollFretboardViewport(toX x: CGFloat) {
        fretboardViewportScrollView.contentView.scroll(to: CGPoint(x: x, y: 0))
        fretboardViewportScrollView.reflectScrolledClipView(
            fretboardViewportScrollView.contentView
        )
    }
}
#endif

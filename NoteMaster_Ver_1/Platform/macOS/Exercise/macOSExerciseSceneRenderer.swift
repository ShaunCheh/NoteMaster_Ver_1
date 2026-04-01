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

    private let primarySurfaceHostView = NSView()
    private let primarySurfaceContentView = NSView()
    private let secondarySurfaceHostView = NSView()
    private let secondarySurfaceContentView = NSView()
    private let fretboardHostView = NSView()
    private let fretboardViewportScrollView = NSScrollView()
    private let fretboardScrollContentView = NSView()

    private let safeAreaHeightAnchor: NSLayoutDimension
    private let metrics: Metrics
    private let sequenceRegenerateButton: NSButton
    private let staffView: macOSStaffView
    private let targetNotePromptView: macOSTargetNotePromptView
    private let naturalNoteStripView: macOSNaturalNoteStripView
    private let fretboardView: macOSFretboardView

    private var currentPresentationState: ExercisePresentationState?
    private var currentFretboardDisplayState = FretboardDisplayState.default

    private var activeArrangementConstraints: [NSLayoutConstraint] = []
    private var primarySurfaceConstraints: [NSLayoutConstraint] = []
    private var secondarySurfaceConstraints: [NSLayoutConstraint] = []
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
        fretboardView: macOSFretboardView
    ) {
        self.safeAreaHeightAnchor = safeAreaHeightAnchor
        self.metrics = metrics
        self.sequenceRegenerateButton = sequenceRegenerateButton
        self.staffView = staffView
        self.targetNotePromptView = targetNotePromptView
        self.naturalNoteStripView = naturalNoteStripView
        self.fretboardView = fretboardView

        configureStaticHierarchy()
    }

    func render(
        presentationState: ExercisePresentationState,
        fretboardDisplayState: FretboardDisplayState
    ) {
        currentPresentationState = presentationState
        currentFretboardDisplayState = fretboardDisplayState

        guard let resolvedLayout = resolvedLayout(from: presentationState) else {
            hideAllSurfaceHosts()
            rebuildVerticalFretboardHostHeightConstraint()
            updateFretboardLayoutModeConstraints()
            return
        }

        applyArrangement(resolvedLayout)
        apply(
            resolvedLayout.primarySurface,
            to: primarySurfaceContentView,
            storedConstraints: &primarySurfaceConstraints
        )
        if let secondarySurface = resolvedLayout.secondarySurface {
            apply(
                secondarySurface,
                to: secondarySurfaceContentView,
                storedConstraints: &secondarySurfaceConstraints
            )
        } else {
            clearSurfaceHost(
                secondarySurfaceContentView,
                storedConstraints: &secondarySurfaceConstraints
            )
        }

        updateSurfaceVisibility(for: resolvedLayout)
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

    private func configureStaticHierarchy() {
        sceneContainerView.translatesAutoresizingMaskIntoConstraints = false
        primarySurfaceHostView.translatesAutoresizingMaskIntoConstraints = false
        primarySurfaceContentView.translatesAutoresizingMaskIntoConstraints = false
        secondarySurfaceHostView.translatesAutoresizingMaskIntoConstraints = false
        secondarySurfaceContentView.translatesAutoresizingMaskIntoConstraints = false
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
        fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
        fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false
        naturalNoteStripView.translatesAutoresizingMaskIntoConstraints = false
        sequenceRegenerateButton.translatesAutoresizingMaskIntoConstraints = false

        fretboardViewportScrollView.drawsBackground = false
        fretboardViewportScrollView.borderType = .noBorder
        fretboardViewportScrollView.hasVerticalScroller = false
        fretboardViewportScrollView.hasHorizontalScroller = false
        fretboardViewportScrollView.autohidesScrollers = true
        fretboardViewportScrollView.documentView = fretboardScrollContentView

        sceneContainerView.addSubview(primarySurfaceHostView)
        sceneContainerView.addSubview(secondarySurfaceHostView)
        primarySurfaceHostView.addSubview(primarySurfaceContentView)
        primarySurfaceHostView.addSubview(sequenceRegenerateButton)
        secondarySurfaceHostView.addSubview(secondarySurfaceContentView)
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
            primarySurfaceContentView.leadingAnchor.constraint(
                equalTo: primarySurfaceHostView.leadingAnchor
            ),
            primarySurfaceContentView.trailingAnchor.constraint(
                equalTo: primarySurfaceHostView.trailingAnchor
            ),
            primarySurfaceContentView.topAnchor.constraint(
                equalTo: primarySurfaceHostView.topAnchor
            ),
            primarySurfaceContentView.bottomAnchor.constraint(
                equalTo: primarySurfaceHostView.bottomAnchor
            ),
            secondarySurfaceContentView.leadingAnchor.constraint(
                equalTo: secondarySurfaceHostView.leadingAnchor
            ),
            secondarySurfaceContentView.trailingAnchor.constraint(
                equalTo: secondarySurfaceHostView.trailingAnchor
            ),
            secondarySurfaceContentView.topAnchor.constraint(
                equalTo: secondarySurfaceHostView.topAnchor
            ),
            secondarySurfaceContentView.bottomAnchor.constraint(
                equalTo: secondarySurfaceHostView.bottomAnchor
            ),
            sequenceRegenerateButton.topAnchor.constraint(
                equalTo: primarySurfaceHostView.topAnchor,
                constant: metrics.floatingButtonInset
            ),
            sequenceRegenerateButton.trailingAnchor.constraint(
                equalTo: primarySurfaceHostView.trailingAnchor,
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

    private func resolvedLayout(
        from presentationState: ExercisePresentationState
    ) -> ExerciseRenderedSceneLayout? {
        if let renderedSceneLayout = presentationState.renderedSceneLayout {
            return renderedSceneLayout
        }

        let surfaceNodes = presentationState.scene.surfaceNodes
        guard let primarySurface = surfaceNodes.first else {
            return nil
        }

        if surfaceNodes.count > 1 {
            return ExerciseRenderedSceneLayout(
                arrangement: .stacked,
                primarySurface: primarySurface,
                primaryWeight: 1,
                secondarySurface: surfaceNodes[1],
                secondaryWeight: 1
            )
        }

        return ExerciseRenderedSceneLayout(
            arrangement: .singleSurface,
            primarySurface: primarySurface,
            primaryWeight: 1,
            secondarySurface: nil,
            secondaryWeight: nil
        )
    }

    private func applyArrangement(
        _ layout: ExerciseRenderedSceneLayout
    ) {
        NSLayoutConstraint.deactivate(activeArrangementConstraints)
        activeArrangementConstraints = []

        primarySurfaceHostView.isHidden = false
        secondarySurfaceHostView.isHidden = layout.secondarySurface == nil

        switch layout.arrangement {
        case .singleSurface:
            activeArrangementConstraints = [
                primarySurfaceHostView.leadingAnchor.constraint(
                    equalTo: sceneContainerView.leadingAnchor
                ),
                primarySurfaceHostView.trailingAnchor.constraint(
                    equalTo: sceneContainerView.trailingAnchor
                ),
                primarySurfaceHostView.topAnchor.constraint(
                    equalTo: sceneContainerView.topAnchor
                ),
                primarySurfaceHostView.bottomAnchor.constraint(
                    equalTo: sceneContainerView.bottomAnchor
                )
            ]
        case .stacked:
            let secondaryWeight = max(layout.secondaryWeight ?? 1, 0.0001)
            activeArrangementConstraints = [
                primarySurfaceHostView.leadingAnchor.constraint(
                    equalTo: sceneContainerView.leadingAnchor
                ),
                primarySurfaceHostView.trailingAnchor.constraint(
                    equalTo: sceneContainerView.trailingAnchor
                ),
                primarySurfaceHostView.topAnchor.constraint(
                    equalTo: sceneContainerView.topAnchor
                ),
                secondarySurfaceHostView.leadingAnchor.constraint(
                    equalTo: sceneContainerView.leadingAnchor
                ),
                secondarySurfaceHostView.trailingAnchor.constraint(
                    equalTo: sceneContainerView.trailingAnchor
                ),
                secondarySurfaceHostView.topAnchor.constraint(
                    equalTo: primarySurfaceHostView.bottomAnchor,
                    constant: metrics.surfaceSpacing
                ),
                secondarySurfaceHostView.bottomAnchor.constraint(
                    equalTo: sceneContainerView.bottomAnchor
                ),
                primarySurfaceHostView.heightAnchor.constraint(
                    equalTo: secondarySurfaceHostView.heightAnchor,
                    multiplier: max(layout.primaryWeight, 0.0001) / secondaryWeight
                )
            ]
        case .sideBySide:
            let secondaryWeight = max(layout.secondaryWeight ?? 1, 0.0001)
            activeArrangementConstraints = [
                primarySurfaceHostView.leadingAnchor.constraint(
                    equalTo: sceneContainerView.leadingAnchor
                ),
                primarySurfaceHostView.topAnchor.constraint(
                    equalTo: sceneContainerView.topAnchor
                ),
                primarySurfaceHostView.bottomAnchor.constraint(
                    equalTo: sceneContainerView.bottomAnchor
                ),
                secondarySurfaceHostView.leadingAnchor.constraint(
                    equalTo: primarySurfaceHostView.trailingAnchor,
                    constant: metrics.surfaceSpacing
                ),
                secondarySurfaceHostView.trailingAnchor.constraint(
                    equalTo: sceneContainerView.trailingAnchor
                ),
                secondarySurfaceHostView.topAnchor.constraint(
                    equalTo: sceneContainerView.topAnchor
                ),
                secondarySurfaceHostView.bottomAnchor.constraint(
                    equalTo: sceneContainerView.bottomAnchor
                ),
                primarySurfaceHostView.widthAnchor.constraint(
                    equalTo: secondarySurfaceHostView.widthAnchor,
                    multiplier: max(layout.primaryWeight, 0.0001) / secondaryWeight
                )
            ]
        }

        NSLayoutConstraint.activate(activeArrangementConstraints)
    }

    private func apply(
        _ surface: ExerciseSurfaceNode,
        to hostView: NSView,
        storedConstraints: inout [NSLayoutConstraint]
    ) {
        guard let surfaceView = view(for: surface.id) else {
            clearSurfaceHost(hostView, storedConstraints: &storedConstraints)
            return
        }

        if surfaceView.superview !== hostView {
            surfaceView.removeFromSuperview()
            hostView.addSubview(surfaceView)
            surfaceView.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.deactivate(storedConstraints)
        storedConstraints = [
            surfaceView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            surfaceView.topAnchor.constraint(equalTo: hostView.topAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(storedConstraints)
    }

    private func clearSurfaceHost(
        _ hostView: NSView,
        storedConstraints: inout [NSLayoutConstraint]
    ) {
        NSLayoutConstraint.deactivate(storedConstraints)
        storedConstraints = []
        hostView.subviews.forEach { $0.removeFromSuperview() }
    }

    private func updateSurfaceVisibility(
        for layout: ExerciseRenderedSceneLayout
    ) {
        staffView.isHidden = true
        targetNotePromptView.isHidden = true
        naturalNoteStripView.isHidden = true
        fretboardHostView.isHidden = true

        let primaryVisible = currentPresentationState?.isSurfaceVisible(
            layout.primarySurface.id
        ) ?? false
        primarySurfaceHostView.isHidden = !primaryVisible
        setVisibility(of: layout.primarySurface.id, isHidden: !primaryVisible)

        if let secondarySurface = layout.secondarySurface {
            let secondaryVisible = currentPresentationState?.isSurfaceVisible(
                secondarySurface.id
            ) ?? false
            secondarySurfaceHostView.isHidden = !secondaryVisible
            setVisibility(of: secondarySurface.id, isHidden: !secondaryVisible)
        } else {
            secondarySurfaceHostView.isHidden = true
        }
    }

    private func hideAllSurfaceHosts() {
        primarySurfaceHostView.isHidden = true
        secondarySurfaceHostView.isHidden = true
        staffView.isHidden = true
        targetNotePromptView.isHidden = true
        naturalNoteStripView.isHidden = true
        fretboardHostView.isHidden = true
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
            break
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
            return nil
        }
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

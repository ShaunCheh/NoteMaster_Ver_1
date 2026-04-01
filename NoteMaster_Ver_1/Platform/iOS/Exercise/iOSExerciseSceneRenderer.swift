//
//  iOSExerciseSceneRenderer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

#if os(iOS)
import UIKit

final class iOSExerciseSceneRenderer {
    struct Metrics {
        var surfaceSpacing: CGFloat
        var floatingButtonInset: CGFloat
        var floatingButtonSize: CGFloat
        var contentSizeTolerance: CGFloat
    }

    let sceneContainerView = UIView()

    private let primarySurfaceHostView = UIView()
    private let primarySurfaceContentView = UIView()
    private let secondarySurfaceHostView = UIView()
    private let secondarySurfaceContentView = UIView()
    private let fretboardHostView = UIView()
    private let fretboardViewportScrollView = UIScrollView()
    private let fretboardScrollContentView = UIView()

    private let safeAreaHeightAnchor: NSLayoutDimension
    private let metrics: Metrics
    private let sequenceRegenerateButton: UIButton
    private let staffView: iOSStaffView
    private let targetNotePromptView: iOSTargetNotePromptView
    private let naturalNoteStripView: iOSNaturalNoteStripView
    private let fretboardView: iOSFretboardView

    private var currentPresentationState: ExercisePresentationState?
    private var currentFretboardDisplayState = FretboardDisplayState.default

    private var activeArrangementConstraints: [NSLayoutConstraint] = []
    private var primarySurfaceConstraints: [NSLayoutConstraint] = []
    private var secondarySurfaceConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?
    private var horizontalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardContentWidthConstraint: NSLayoutConstraint?

    init(
        safeAreaHeightAnchor: NSLayoutDimension,
        metrics: Metrics,
        sequenceRegenerateButton: UIButton,
        staffView: iOSStaffView,
        targetNotePromptView: iOSTargetNotePromptView,
        naturalNoteStripView: iOSNaturalNoteStripView,
        fretboardView: iOSFretboardView
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
        syncVerticalFretboardContentWidthConstraint()
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

        fretboardViewportScrollView.alwaysBounceVertical = false
        fretboardViewportScrollView.alwaysBounceHorizontal = false
        fretboardViewportScrollView.showsVerticalScrollIndicator = false
        fretboardViewportScrollView.showsHorizontalScrollIndicator = false
        fretboardViewportScrollView.isDirectionalLockEnabled = true
        fretboardViewportScrollView.delaysContentTouches = false
        fretboardViewportScrollView.canCancelContentTouches = true
        fretboardViewportScrollView.panGestureRecognizer.cancelsTouchesInView = true
        fretboardViewportScrollView.contentInsetAdjustmentBehavior = .never

        sceneContainerView.addSubview(primarySurfaceHostView)
        sceneContainerView.addSubview(secondarySurfaceHostView)
        primarySurfaceHostView.addSubview(primarySurfaceContentView)
        primarySurfaceHostView.addSubview(sequenceRegenerateButton)
        secondarySurfaceHostView.addSubview(secondarySurfaceContentView)
        fretboardHostView.addSubview(fretboardViewportScrollView)
        fretboardViewportScrollView.addSubview(fretboardScrollContentView)
        fretboardScrollContentView.addSubview(fretboardView)

        horizontalFretboardContentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
            equalTo: fretboardViewportScrollView.frameLayoutGuide.widthAnchor
        )
        verticalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
            equalToConstant: currentFretboardDisplayState.configuration.verticalContentWidth(
                forViewportHeight: currentFretboardDisplayState.configuration.preferredHeight
            )
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
                equalTo: fretboardViewportScrollView.contentLayoutGuide.leadingAnchor
            ),
            fretboardScrollContentView.trailingAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentLayoutGuide.trailingAnchor
            ),
            fretboardScrollContentView.topAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentLayoutGuide.topAnchor
            ),
            fretboardScrollContentView.bottomAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentLayoutGuide.bottomAnchor
            ),
            fretboardScrollContentView.heightAnchor.constraint(
                equalTo: fretboardViewportScrollView.frameLayoutGuide.heightAnchor
            ),
            fretboardView.leadingAnchor.constraint(
                equalTo: fretboardScrollContentView.leadingAnchor
            ),
            fretboardView.trailingAnchor.constraint(
                equalTo: fretboardScrollContentView.trailingAnchor
            ),
            fretboardView.topAnchor.constraint(
                equalTo: fretboardScrollContentView.topAnchor
            ),
            fretboardView.bottomAnchor.constraint(
                equalTo: fretboardScrollContentView.bottomAnchor
            )
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
        to hostView: UIView,
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
        _ hostView: UIView,
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

    private func view(for surfaceID: ExerciseSurfaceID) -> UIView? {
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
            horizontalFretboardContentWidthConstraint?.isActive = false
            verticalFretboardContentWidthConstraint?.isActive = false
            fretboardViewportScrollView.contentInset = .zero
            fretboardViewportScrollView.scrollIndicatorInsets = .zero
            fretboardViewportScrollView.isScrollEnabled = false
            fretboardViewportScrollView.alwaysBounceHorizontal = false
            fretboardViewportScrollView.showsHorizontalScrollIndicator = false
            fretboardViewportScrollView.setContentOffset(.zero, animated: false)
            return
        }

        let isVertical = currentFretboardDisplayState.displayMode == .vertical
        verticalFretboardHostHeightConstraint?.isActive = isVertical
        horizontalFretboardContentWidthConstraint?.isActive = !isVertical
        verticalFretboardContentWidthConstraint?.isActive = isVertical

        if !isVertical {
            fretboardViewportScrollView.contentInset = .zero
            fretboardViewportScrollView.scrollIndicatorInsets = .zero
            fretboardViewportScrollView.setContentOffset(.zero, animated: false)
        }
    }

    private func syncVerticalFretboardContentWidthConstraint() {
        guard
            isShowingFretboard,
            currentFretboardDisplayState.displayMode == .vertical,
            let verticalFretboardContentWidthConstraint
        else {
            return
        }

        let targetWidth = fretboardView.verticalContentSize.width
        guard targetWidth > 0 else {
            return
        }

        if abs(verticalFretboardContentWidthConstraint.constant - targetWidth)
            > metrics.contentSizeTolerance {
            verticalFretboardContentWidthConstraint.constant = targetWidth
        }
    }

    private func updateFretboardViewportPresentation() {
        guard isShowingFretboard else {
            fretboardViewportScrollView.contentInset = .zero
            fretboardViewportScrollView.scrollIndicatorInsets = .zero
            fretboardViewportScrollView.isScrollEnabled = false
            fretboardViewportScrollView.alwaysBounceHorizontal = false
            fretboardViewportScrollView.showsHorizontalScrollIndicator = false

            if abs(fretboardViewportScrollView.contentOffset.x)
                > metrics.contentSizeTolerance
                || abs(fretboardViewportScrollView.contentOffset.y)
                > metrics.contentSizeTolerance {
                fretboardViewportScrollView.setContentOffset(.zero, animated: false)
            }
            return
        }

        let isVertical = currentFretboardDisplayState.displayMode == .vertical
        guard isVertical else {
            fretboardViewportScrollView.isScrollEnabled = false
            fretboardViewportScrollView.alwaysBounceHorizontal = false
            fretboardViewportScrollView.showsHorizontalScrollIndicator = false
            return
        }

        let viewportWidth = fretboardViewportScrollView.bounds.width
        let contentWidth = verticalFretboardContentWidthConstraint?.constant
            ?? fretboardView.verticalContentSize.width
        guard viewportWidth > 0, contentWidth > 0 else {
            return
        }

        let needsHorizontalScroll = contentWidth
            > viewportWidth + metrics.contentSizeTolerance
        let horizontalInset = needsHorizontalScroll
            ? 0
            : max((viewportWidth - contentWidth) / 2, 0)
        let inset = UIEdgeInsets(
            top: 0,
            left: horizontalInset,
            bottom: 0,
            right: horizontalInset
        )

        fretboardViewportScrollView.contentInset = inset
        fretboardViewportScrollView.scrollIndicatorInsets = inset
        fretboardViewportScrollView.isScrollEnabled = needsHorizontalScroll
        fretboardViewportScrollView.alwaysBounceHorizontal = needsHorizontalScroll
        fretboardViewportScrollView.showsHorizontalScrollIndicator = needsHorizontalScroll

        let minOffsetX = -inset.left
        let maxOffsetX = max(minOffsetX, contentWidth - viewportWidth + inset.right)
        let clampedOffsetX: CGFloat
        if needsHorizontalScroll {
            clampedOffsetX = min(
                max(fretboardViewportScrollView.contentOffset.x, minOffsetX),
                maxOffsetX
            )
        } else {
            clampedOffsetX = minOffsetX
        }

        if abs(fretboardViewportScrollView.contentOffset.x - clampedOffsetX)
            > metrics.contentSizeTolerance
            || abs(fretboardViewportScrollView.contentOffset.y)
            > metrics.contentSizeTolerance {
            fretboardViewportScrollView.setContentOffset(
                CGPoint(x: clampedOffsetX, y: 0),
                animated: false
            )
        }
    }
}
#endif

//
//  iOSViewController.swift
//  NoteMaster_Ver_1
//
//  Created by Shaun on 2026/3/19.
//

#if os(iOS)
import Foundation
import UIKit

final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyFretboardDisplayState()
        }
    }

    private var staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        ),
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
    ) {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyStaffDisplayState()
        }
    }
    // 页面编排状态独立于 staff / fretboard display state，
    // 阶段 4 由 applyPageDisplayState() 统一承接顶部和主内容区域切换。
    private var pageDisplayState = PageDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyPageDisplayState()
        }
    }

    private var isSettingsPresented = false
    private var fretboardTrainerState = FretboardNaturalNoteTrainerState()

    private var currentFretboardTrainerPrompt: FretboardNaturalNoteTrainerState.Prompt {
        fretboardTrainerState.prompt
    }

    private var currentQuarterNoteSequencePrompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt? {
        guard case .quarterNoteSequence = fretboardTrainerState.mode else {
            return nil
        }

        return fretboardTrainerState.quarterNoteSequencePrompt
    }

    private var isQuarterNoteSequenceMode: Bool {
        guard case .quarterNoteSequence = fretboardTrainerState.mode else {
            return false
        }

        return true
    }

    private var isShowingFretboardMainContent: Bool {
        pageDisplayState.mainContentMode == .fretboard
    }

    private var settingsPanelStateContext: SettingsPanelStateContext {
        SettingsPanelStateContext(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState,
            pageDisplayState: pageDisplayState
        )
    }

    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.buttonSize = .medium
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "gearshape.fill")
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 10,
            bottom: 10,
            trailing: 10
        )
        button.configuration = configuration
        button.accessibilityIdentifier = "floating-settings-button"
        button.addTarget(
            self,
            action: #selector(handleSettingsButtonTap),
            for: .touchUpInside
        )
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 12
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        return button
    }()

    private lazy var settingsContainerView: iOSSettingsContainerView = {
        let settingsContainerView = iOSSettingsContainerView(
            model: SettingsPanelSnapshotBuilder.makeModel(
                from: settingsPanelStateContext
            )
        )
        settingsContainerView.onEvent = { [weak self] event in
            self?.handleSettingsPanelEvent(event)
        }
        settingsContainerView.onDismissRequest = { [weak self] in
            self?.setSettingsPresented(false)
        }
        return settingsContainerView
    }()

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let topContentHostView = UIView()
    private let mainContentHostView = UIView()
    private let fretboardHostView = UIView()
    private let fretboardViewportScrollView = UIScrollView()
    private let fretboardScrollContentView = UIView()
    private var horizontalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?
    private var topContentStaffConstraints: [NSLayoutConstraint] = []
    private var topContentTargetPromptConstraints: [NSLayoutConstraint] = []
    private var mainContentFretboardConstraints: [NSLayoutConstraint] = []
    private var mainContentNaturalNoteStripConstraints: [NSLayoutConstraint] = []

    private lazy var fretboardView: iOSFretboardView = {
        let fretboardView = iOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { [weak self] hitResult in
            self?.handleFretboardTrainerHitResult(hitResult)
        }
        return fretboardView
    }()

    private lazy var staffView: iOSStaffView = {
        iOSStaffView(
            configuration: staffDisplayState.configuration,
            sceneProvider: staffDisplayState.sceneProvider
        )
    }()

    private lazy var targetNotePromptView: iOSTargetNotePromptView = {
        let targetNotePromptView = iOSTargetNotePromptView(
            prompt: currentFretboardTrainerPrompt
        )
        targetNotePromptView.isHidden = true
        return targetNotePromptView
    }()

    private lazy var naturalNoteStripView: iOSNaturalNoteStripView = {
        let naturalNoteStripView = iOSNaturalNoteStripView()
        naturalNoteStripView.isHidden = true
        return naturalNoteStripView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        applyDisplayState()
        applyFretboardTrainerPrompt(reason: "initial")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        syncVerticalFretboardContentWidthConstraint()
        updateFretboardViewportPresentation()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
        topContentHostView.translatesAutoresizingMaskIntoConstraints = false
        mainContentHostView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false
        naturalNoteStripView.translatesAutoresizingMaskIntoConstraints = false
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
        fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
        fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        // 点击直接透传给指板；一旦用户开始纵向拖动，scroll view 可以取消当前触摸序列并接管滚动。
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.panGestureRecognizer.cancelsTouchesInView = true
        fretboardViewportScrollView.alwaysBounceVertical = false
        fretboardViewportScrollView.alwaysBounceHorizontal = false
        fretboardViewportScrollView.showsVerticalScrollIndicator = false
        fretboardViewportScrollView.showsHorizontalScrollIndicator = false
        fretboardViewportScrollView.isDirectionalLockEnabled = true
        fretboardViewportScrollView.delaysContentTouches = false
        fretboardViewportScrollView.canCancelContentTouches = true
        fretboardViewportScrollView.panGestureRecognizer.cancelsTouchesInView = true
        fretboardViewportScrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(topContentHostView)
        topContentHostView.addSubview(staffView)
        topContentHostView.addSubview(targetNotePromptView)
        contentView.addSubview(mainContentHostView)
        mainContentHostView.addSubview(fretboardHostView)
        mainContentHostView.addSubview(naturalNoteStripView)
        fretboardHostView.addSubview(fretboardViewportScrollView)
        fretboardViewportScrollView.addSubview(fretboardScrollContentView)
        fretboardScrollContentView.addSubview(fretboardView)
        view.addSubview(settingsButton)
        view.addSubview(settingsContainerView)

        let safeArea = view.safeAreaLayoutGuide
        rebuildVerticalFretboardHostHeightConstraint()
        topContentStaffConstraints = [
            staffView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
            staffView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
            staffView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
            staffView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor)
        ]
        topContentTargetPromptConstraints = [
            targetNotePromptView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
            targetNotePromptView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
            targetNotePromptView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
            targetNotePromptView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor)
        ]
        mainContentFretboardConstraints = [
            fretboardHostView.leadingAnchor.constraint(equalTo: mainContentHostView.leadingAnchor),
            fretboardHostView.trailingAnchor.constraint(equalTo: mainContentHostView.trailingAnchor),
            fretboardHostView.topAnchor.constraint(equalTo: mainContentHostView.topAnchor),
            fretboardHostView.bottomAnchor.constraint(equalTo: mainContentHostView.bottomAnchor)
        ]
        mainContentNaturalNoteStripConstraints = [
            naturalNoteStripView.leadingAnchor.constraint(equalTo: mainContentHostView.leadingAnchor),
            naturalNoteStripView.trailingAnchor.constraint(equalTo: mainContentHostView.trailingAnchor),
            naturalNoteStripView.topAnchor.constraint(equalTo: mainContentHostView.topAnchor),
            naturalNoteStripView.bottomAnchor.constraint(equalTo: mainContentHostView.bottomAnchor)
        ]
        horizontalFretboardContentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
            equalTo: fretboardViewportScrollView.frameLayoutGuide.widthAnchor
        )
        verticalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
            equalToConstant: displayState.configuration.verticalContentWidth(
                forViewportHeight: displayState.configuration.preferredHeight
            )
        )

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            topContentHostView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.contentTopInset
            ),
            topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainContentHostView.topAnchor.constraint(
                equalTo: topContentHostView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            mainContentHostView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            ),
            fretboardViewportScrollView.leadingAnchor.constraint(equalTo: fretboardHostView.leadingAnchor),
            fretboardViewportScrollView.trailingAnchor.constraint(equalTo: fretboardHostView.trailingAnchor),
            fretboardViewportScrollView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
            fretboardViewportScrollView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor),
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
            fretboardView.leadingAnchor.constraint(equalTo: fretboardScrollContentView.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: fretboardScrollContentView.trailingAnchor),
            fretboardView.topAnchor.constraint(equalTo: fretboardScrollContentView.topAnchor),
            fretboardView.bottomAnchor.constraint(equalTo: fretboardScrollContentView.bottomAnchor),
            settingsButton.leadingAnchor.constraint(
                equalTo: safeArea.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            settingsButton.topAnchor.constraint(
                equalTo: safeArea.topAnchor,
                constant: Layout.topInset
            ),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            settingsContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateFretboardLayoutModeConstraints()
        applySettingsPresentationState()
    }

    private func updateFretboardLayoutModeConstraints() {
        guard isShowingFretboardMainContent else {
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

        let isVertical = displayState.displayMode == .vertical
        verticalFretboardHostHeightConstraint?.isActive = isVertical
        horizontalFretboardContentWidthConstraint?.isActive = !isVertical
        verticalFretboardContentWidthConstraint?.isActive = isVertical

        if !isVertical {
            fretboardViewportScrollView.contentInset = .zero
            fretboardViewportScrollView.scrollIndicatorInsets = .zero
            fretboardViewportScrollView.setContentOffset(.zero, animated: false)
        }
    }

    private func rebuildVerticalFretboardHostHeightConstraint() {
        verticalFretboardHostHeightConstraint?.isActive = false
        verticalFretboardHostHeightConstraint = nil

        guard isShowingFretboardMainContent else {
            return
        }

        verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.heightAnchor,
            multiplier: displayState.verticalHostHeightRatio
        )
    }

    private func applyDisplayState() {
        applyFretboardDisplayState()
        applyStaffDisplayState()
        applyPageDisplayState()
    }

    private func applyFretboardDisplayState() {
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
        rebuildVerticalFretboardHostHeightConstraint()
        applySettingsPanelState()
        updateFretboardLayoutModeConstraints()

        guard isShowingFretboardMainContent else {
            return
        }

        updateLayoutIfNeeded()
        syncVerticalFretboardContentWidthConstraint()
        updateLayoutIfNeeded()
        updateFretboardViewportPresentation()
    }

    private func applyStaffDisplayState() {
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        staffView.showsComponentBoundsOverlay = staffDisplayState.showsComponentBoundsOverlay
        applySettingsPanelState()
        updateLayoutIfNeeded()
    }

    private func applyPageDisplayState() {
        if !isQuarterNoteSequenceMode {
            targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
        }
        applyTopContentMode()
        applyMainContentMode()
        applySettingsPanelState()
        updateLayoutIfNeeded()

        if isShowingFretboardMainContent {
            syncVerticalFretboardContentWidthConstraint()
            updateLayoutIfNeeded()
        }

        updateFretboardViewportPresentation()
    }

    private func applyTopContentMode() {
        let showsStaff = pageDisplayState.topContentMode == .staff
        let activeConstraints = showsStaff
            ? topContentStaffConstraints
            : topContentTargetPromptConstraints
        let inactiveConstraints = showsStaff
            ? topContentTargetPromptConstraints
            : topContentStaffConstraints

        staffView.isHidden = !showsStaff
        targetNotePromptView.isHidden = showsStaff
        NSLayoutConstraint.deactivate(inactiveConstraints)
        NSLayoutConstraint.activate(activeConstraints)
    }

    private func applyMainContentMode() {
        let showsFretboard = isShowingFretboardMainContent
        let activeConstraints = showsFretboard
            ? mainContentFretboardConstraints
            : mainContentNaturalNoteStripConstraints
        let inactiveConstraints = showsFretboard
            ? mainContentNaturalNoteStripConstraints
            : mainContentFretboardConstraints

        fretboardHostView.isHidden = !showsFretboard
        naturalNoteStripView.isHidden = showsFretboard
        NSLayoutConstraint.deactivate(inactiveConstraints)
        NSLayoutConstraint.activate(activeConstraints)
        rebuildVerticalFretboardHostHeightConstraint()
        updateFretboardLayoutModeConstraints()
    }

    private func applySettingsPanelState() {
        settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
            from: settingsPanelStateContext
        )
    }

    private func updateLayoutIfNeeded() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func syncVerticalFretboardContentWidthConstraint() {
        guard
            isShowingFretboardMainContent,
            displayState.displayMode == .vertical,
            let verticalFretboardContentWidthConstraint
        else {
            return
        }

        let targetWidth = fretboardView.verticalContentSize.width
        guard targetWidth > 0 else {
            return
        }

        if abs(verticalFretboardContentWidthConstraint.constant - targetWidth) > Layout.contentSizeTolerance {
            verticalFretboardContentWidthConstraint.constant = targetWidth
        }
    }

    private func updateFretboardViewportPresentation() {
        guard isShowingFretboardMainContent else {
            fretboardViewportScrollView.contentInset = .zero
            fretboardViewportScrollView.scrollIndicatorInsets = .zero
            fretboardViewportScrollView.isScrollEnabled = false
            fretboardViewportScrollView.alwaysBounceHorizontal = false
            fretboardViewportScrollView.showsHorizontalScrollIndicator = false

            if abs(fretboardViewportScrollView.contentOffset.x) > Layout.contentSizeTolerance
                || abs(fretboardViewportScrollView.contentOffset.y) > Layout.contentSizeTolerance {
                fretboardViewportScrollView.setContentOffset(.zero, animated: false)
            }
            return
        }

        let isVertical = displayState.displayMode == .vertical
        guard isVertical else {
            fretboardViewportScrollView.isScrollEnabled = false
            fretboardViewportScrollView.alwaysBounceHorizontal = false
            fretboardViewportScrollView.showsHorizontalScrollIndicator = false
            return
        }

        let viewportWidth = fretboardViewportScrollView.bounds.width
        let contentWidth = verticalFretboardContentWidthConstraint?.constant ?? fretboardView.verticalContentSize.width
        guard viewportWidth > 0, contentWidth > 0 else {
            return
        }

        let needsHorizontalScroll = contentWidth > viewportWidth + Layout.contentSizeTolerance
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

        if abs(fretboardViewportScrollView.contentOffset.x - clampedOffsetX) > Layout.contentSizeTolerance
            || abs(fretboardViewportScrollView.contentOffset.y) > Layout.contentSizeTolerance {
            fretboardViewportScrollView.setContentOffset(
                CGPoint(x: clampedOffsetX, y: 0),
                animated: false
            )
        }
    }

    private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            handleSingleNaturalTargetHitResult(hitResult)
        case .quarterNoteSequence:
            handleQuarterNoteSequenceHitResult(hitResult)
        }
    }

    private func handleSingleNaturalTargetHitResult(_ hitResult: FretboardHitResult) {
        switch fretboardTrainerState.handle(
            hitResult: hitResult,
            configuration: displayState.configuration
        ) {
        case .ignored(.nonEndedPhase):
            return
        case .ignored(.missingHitCell):
            print(
                "[FretboardTrainer][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
            )
        case let .ignored(.unresolvedHitPitch(cell)):
            print(
                "[FretboardTrainer][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
            )
        case let .evaluated(evaluation):
            print("[iOS] \(evaluation.debugSummary())")
            if evaluation.didAdvanceTarget {
                applyFretboardTrainerPrompt(reason: "advanced")
            }
        }
    }

    private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
        guard hitResult.phase == .ended else {
            return
        }

        guard let prompt = currentQuarterNoteSequencePrompt else {
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=missingPrompt"
            )
            return
        }

        let locationSuffix: String
        if let cell = hitResult.cell {
            locationSuffix = " string=\(cell.stringIndex) fret=\(cell.fret)"
        } else {
            locationSuffix = " missingHitCell=true"
        }

        print(
            "[QuarterNoteSequence][iOS] clef=\(prompt.spec.clef.title) noteCount=\(prompt.spec.noteCount) includesAccidentals=\(prompt.spec.includesAccidentals) result=ignored reason=pendingAnswerFlow\(locationSuffix)"
        )
    }

    // trainer prompt 的平台组装入口仍然收口在控制器：
    // 这里同时同步控制台日志与目标音组件显示内容。
    private func applyFretboardTrainerPrompt(reason: String) {
        let prompt = currentFretboardTrainerPrompt
        targetNotePromptView.apply(prompt: prompt)
        print(
            "[FretboardTrainer][iOS] target=\(prompt.displayText) state=\(reason)"
        )
    }

    // 内部入口：先生成 quarter-note prompt，再把它投影到现有五线谱显示状态。
    // 后续阶段若从 settings 或调试入口切入，可直接复用这一条 controller 接线。
    func startQuarterNoteSequenceExercise(
        with spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) {
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            quarterNoteSequenceSpec: spec
        )
        let prompt = fretboardTrainerState.generateQuarterNoteSequencePrompt()
        applyQuarterNoteSequencePromptToStaff(prompt, reason: "generated")
    }

    private func applyQuarterNoteSequencePromptToStaff(
        _ prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt,
        reason: String
    ) {
        var nextPageDisplayState = pageDisplayState
        nextPageDisplayState.topContentMode = .staff

        var nextStaffDisplayState = staffDisplayState
        nextStaffDisplayState.apply(quarterNoteSequencePrompt: prompt)

        if nextPageDisplayState != pageDisplayState {
            pageDisplayState = nextPageDisplayState
        }

        if nextStaffDisplayState != staffDisplayState {
            staffDisplayState = nextStaffDisplayState
        }

        print(
            "[QuarterNoteSequence][iOS] clef=\(prompt.spec.clef.title) noteCount=\(prompt.spec.noteCount) includesAccidentals=\(prompt.spec.includesAccidentals) state=\(reason)"
        )
    }

    private func normalizeSettingsPanelStateContextForTrainerMode(
        _ stateContext: inout SettingsPanelStateContext
    ) {
        guard isQuarterNoteSequenceMode else {
            return
        }

        stateContext.pageDisplayState.topContentMode = .staff

        if let currentQuarterNoteSequencePrompt {
            stateContext.staffDisplayState.apply(
                quarterNoteSequencePrompt: currentQuarterNoteSequencePrompt
            )
        }
    }

    private func setSettingsPresented(_ presented: Bool) {
        guard isSettingsPresented != presented else {
            return
        }

        isSettingsPresented = presented
        applySettingsPresentationState()
    }

    // 控制器仍然是 settings 展示状态的唯一真相来源；
    // 后续阶段只需要扩展这里，就能统一同步页面入口按钮与 container 壳层。
    private func applySettingsPresentationState() {
        settingsContainerView.setPresented(isSettingsPresented)
        settingsButton.isHidden = isSettingsPresented
        updateSettingsButtonAppearance()
    }

    private func updateSettingsButtonAppearance() {
        var configuration = settingsButton.configuration ?? UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "gearshape.fill")
        configuration.baseBackgroundColor = isSettingsPresented
            ? .systemBlue
            : .secondarySystemBackground
        configuration.baseForegroundColor = isSettingsPresented
            ? .white
            : .label
        settingsButton.configuration = configuration
        settingsButton.accessibilityLabel = isSettingsPresented
            ? "Hide settings"
            : "Show settings"
    }

    @objc
    private func handleSettingsButtonTap() {
        setSettingsPresented(!isSettingsPresented)
    }

    private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
        var nextStateContext = settingsPanelStateContext
        event.apply(to: &nextStateContext)
        normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

        let nextDisplayState = nextStateContext.fretboardDisplayState
        let nextStaffDisplayState = nextStateContext.staffDisplayState
        let nextPageDisplayState = nextStateContext.pageDisplayState

        let didChangeFretboard = nextDisplayState != displayState
        let didChangeStaff = nextStaffDisplayState != staffDisplayState
        let didChangePage = nextPageDisplayState != pageDisplayState

        guard didChangeFretboard || didChangeStaff || didChangePage else {
            return
        }

        if didChangePage {
            pageDisplayState = nextPageDisplayState
        }

        if didChangeFretboard {
            displayState = nextDisplayState
        }

        if didChangeStaff {
            staffDisplayState = nextStaffDisplayState
        }
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let contentTopInset: CGFloat = 68
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let settingsButtonSize: CGFloat = 40
    static let contentSizeTolerance: CGFloat = 0.5
}
#endif

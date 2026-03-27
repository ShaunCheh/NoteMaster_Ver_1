//
//  macOSViewController.swift
//  NoteMaster_Ver_1
//
//  Created by Shaun on 2026/3/19.
//

#if os(macOS)
import Foundation
import AppKit

final class macOSViewController: NSViewController {
    private static let initialStaffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        ),
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
    )

    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyFretboardDisplayState()
        }
    }

    private var staffDisplayState = Self.initialStaffDisplayState {
        didSet {
            guard isViewLoaded else {
                return
            }

            if !trainerDisplayState.isSequenceMode {
                baseStaffDisplayState = staffDisplayState
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
    private var trainerDisplayState = TrainerDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applySettingsPanelState()
        }
    }
    private var baseStaffDisplayState = Self.initialStaffDisplayState

    private var isSettingsPresented = false
    private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
    private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?

    private var currentFretboardTrainerPrompt: FretboardNaturalNoteTrainerState.Prompt {
        fretboardTrainerState.prompt
    }

    private var currentGeneratedQuarterNoteSequence: GeneratedNoteSequence? {
        guard case .quarterNoteSequence = fretboardTrainerState.mode else {
            return nil
        }

        return fretboardTrainerState.generatedQuarterNoteSequence
    }

    private var currentQuarterNoteSequenceTargetPromptContent: TargetPromptContent? {
        guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
            return nil
        }

        if let quarterNoteSequenceSession,
           quarterNoteSequenceSession.generatedSequence == generatedSequence {
            return quarterNoteSequenceSession.targetPromptContent()
        }

        return generatedSequence.targetPromptContent()
    }

    private var configuredQuarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
        trainerDisplayState.sequenceConfiguration.quarterNoteSequenceSpec
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
            pageDisplayState: pageDisplayState,
            trainerDisplayState: trainerDisplayState
        )
    }

    private lazy var settingsButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.image = NSImage(
            systemSymbolName: "gearshape.fill",
            accessibilityDescription: "Settings"
        )
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .labelColor
        button.identifier = NSUserInterfaceItemIdentifier("floating-settings-button")
        button.target = self
        button.action = #selector(handleSettingsButtonTap)
        button.wantsLayer = true
        button.layer?.cornerRadius = Layout.settingsButtonSize / 2
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.12
        button.layer?.shadowRadius = 12
        button.layer?.shadowOffset = CGSize(width: 0, height: -4)
        return button
    }()

    private lazy var settingsContainerView: macOSSettingsContainerView = {
        let settingsContainerView = macOSSettingsContainerView(
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

    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let topContentHostView = NSView()
    private let mainContentHostView = NSView()
    private let fretboardHostView = NSView()
    private let fretboardViewportScrollView = NSScrollView()
    private let fretboardScrollContentView = NSView()
    private var horizontalFretboardDocumentWidthConstraint: NSLayoutConstraint?
    private var horizontalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardDocumentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var fretboardContentCenterXConstraint: NSLayoutConstraint?
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?
    private var topContentStaffConstraints: [NSLayoutConstraint] = []
    private var topContentTargetPromptConstraints: [NSLayoutConstraint] = []
    private var mainContentFretboardConstraints: [NSLayoutConstraint] = []
    private var mainContentNaturalNoteStripConstraints: [NSLayoutConstraint] = []

    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { [weak self] hitResult in
            self?.handleFretboardTrainerHitResult(hitResult)
        }
        return fretboardView
    }()

    private lazy var staffView: macOSStaffView = {
        macOSStaffView(
            configuration: staffDisplayState.configuration,
            sceneProvider: staffDisplayState.sceneProvider
        )
    }()

    private lazy var targetNotePromptView: macOSTargetNotePromptView = {
        let targetNotePromptView = macOSTargetNotePromptView(
            prompt: currentFretboardTrainerPrompt
        )
        targetNotePromptView.isHidden = true
        return targetNotePromptView
    }()

    private lazy var naturalNoteStripView: macOSNaturalNoteStripView = {
        let naturalNoteStripView = macOSNaturalNoteStripView()
        naturalNoteStripView.isHidden = true
        return naturalNoteStripView
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureLayout()
        applyDisplayState()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        syncVerticalFretboardContentSizeConstraints()
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
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
        fretboardViewportScrollView.drawsBackground = false
        fretboardViewportScrollView.borderType = .noBorder
        fretboardViewportScrollView.hasVerticalScroller = false
        fretboardViewportScrollView.hasHorizontalScroller = false
        fretboardViewportScrollView.autohidesScrollers = true
        fretboardViewportScrollView.documentView = fretboardScrollContentView
        view.addSubview(scrollView)
        contentView.addSubview(topContentHostView)
        topContentHostView.addSubview(staffView)
        topContentHostView.addSubview(targetNotePromptView)
        contentView.addSubview(mainContentHostView)
        mainContentHostView.addSubview(fretboardHostView)
        mainContentHostView.addSubview(naturalNoteStripView)
        fretboardHostView.addSubview(fretboardViewportScrollView)
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
        horizontalFretboardDocumentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentView.widthAnchor
        )
        horizontalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
            equalTo: fretboardScrollContentView.widthAnchor
        )
        verticalFretboardDocumentWidthConstraint = fretboardScrollContentView.widthAnchor.constraint(
            equalToConstant: displayState.configuration.verticalContentWidth(
                forViewportHeight: displayState.configuration.preferredHeight
            )
        )
        verticalFretboardDocumentWidthConstraint?.priority = .required
        verticalFretboardContentWidthConstraint = fretboardView.widthAnchor.constraint(
            equalToConstant: displayState.configuration.verticalContentWidth(
                forViewportHeight: displayState.configuration.preferredHeight
            )
        )
        verticalFretboardContentWidthConstraint?.priority = .required
        fretboardContentCenterXConstraint = fretboardView.centerXAnchor.constraint(
            equalTo: fretboardScrollContentView.centerXAnchor
        )

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
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
                equalTo: fretboardViewportScrollView.contentView.leadingAnchor
            ),
            fretboardScrollContentView.topAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentView.topAnchor
            ),
            fretboardScrollContentView.heightAnchor.constraint(
                equalTo: fretboardViewportScrollView.contentView.heightAnchor
            ),
            fretboardView.topAnchor.constraint(equalTo: fretboardScrollContentView.topAnchor),
            fretboardView.bottomAnchor.constraint(equalTo: fretboardScrollContentView.bottomAnchor),
            fretboardContentCenterXConstraint!,
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
            horizontalFretboardDocumentWidthConstraint?.isActive = false
            horizontalFretboardContentWidthConstraint?.isActive = false
            verticalFretboardDocumentWidthConstraint?.isActive = false
            verticalFretboardContentWidthConstraint?.isActive = false
            fretboardViewportScrollView.hasHorizontalScroller = false
            scrollFretboardViewport(toX: 0)
            return
        }

        let isVertical = displayState.displayMode == .vertical
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
        synchronizeTrainerPresentationState(reason: "initial")
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
        syncVerticalFretboardContentSizeConstraints()
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
        applyTopContentMode()
        applyMainContentMode()
        applySettingsPanelState()
        updateLayoutIfNeeded()

        if isShowingFretboardMainContent {
            syncVerticalFretboardContentSizeConstraints()
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
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    private func syncVerticalFretboardContentSizeConstraints() {
        guard
            isShowingFretboardMainContent,
            displayState.displayMode == .vertical,
            let verticalFretboardDocumentWidthConstraint,
            let verticalFretboardContentWidthConstraint
        else {
            return
        }

        let contentWidth = fretboardView.verticalContentSize.width
        let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
        guard contentWidth > 0 else {
            return
        }

        let documentWidth = max(viewportWidth, contentWidth)
        if abs(verticalFretboardDocumentWidthConstraint.constant - documentWidth) > Layout.contentSizeTolerance {
            verticalFretboardDocumentWidthConstraint.constant = documentWidth
        }

        if abs(verticalFretboardContentWidthConstraint.constant - contentWidth) > Layout.contentSizeTolerance {
            verticalFretboardContentWidthConstraint.constant = contentWidth
        }
    }

    private func updateFretboardViewportPresentation() {
        guard isShowingFretboardMainContent else {
            fretboardViewportScrollView.hasHorizontalScroller = false
            scrollFretboardViewport(toX: 0)
            return
        }

        let isVertical = displayState.displayMode == .vertical
        guard isVertical else {
            fretboardViewportScrollView.hasHorizontalScroller = false
            return
        }

        let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
        let contentWidth = verticalFretboardContentWidthConstraint?.constant ?? fretboardView.verticalContentSize.width
        guard viewportWidth > 0, contentWidth > 0 else {
            return
        }

        let needsHorizontalScroll = contentWidth > viewportWidth + Layout.contentSizeTolerance
        fretboardViewportScrollView.hasHorizontalScroller = needsHorizontalScroll

        let maxOffsetX = max(contentWidth - viewportWidth, 0)
        let currentOffsetX = fretboardViewportScrollView.contentView.bounds.origin.x
        let clampedOffsetX = needsHorizontalScroll
            ? min(max(currentOffsetX, 0), maxOffsetX)
            : 0

        if abs(currentOffsetX - clampedOffsetX) > Layout.contentSizeTolerance {
            scrollFretboardViewport(toX: clampedOffsetX)
        }
    }

    private func scrollFretboardViewport(toX x: CGFloat) {
        fretboardViewportScrollView.contentView.scroll(to: CGPoint(x: x, y: 0))
        fretboardViewportScrollView.reflectScrolledClipView(
            fretboardViewportScrollView.contentView
        )
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
                "[FretboardTrainer][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
            )
        case let .ignored(.unresolvedHitPitch(cell)):
            print(
                "[FretboardTrainer][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
            )
        case let .evaluated(evaluation):
            print("[macOS] \(evaluation.debugSummary())")
            if evaluation.didAdvanceTarget {
                applyFretboardTrainerPrompt(reason: "advanced")
            }
        }
    }

    private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
        guard hitResult.phase == .ended else {
            return
        }

        guard let selectedCell = hitResult.cell else {
            print(
                "[QuarterNoteSequence][macOS] result=ignored reason=missingHitCell"
            )
            return
        }

        guard let selectedPitch = displayState.configuration.notePitch(for: selectedCell) else {
            print(
                "[QuarterNoteSequence][macOS] result=ignored reason=unresolvedHitPitch string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
            )
            return
        }

        guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
            print(
                "[QuarterNoteSequence][macOS] result=ignored reason=missingSequence"
            )
            return
        }

        if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
            quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        }

        guard var quarterNoteSequenceSession else {
            print(
                "[QuarterNoteSequence][macOS] result=ignored reason=missingSession"
            )
            return
        }

        let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
            selectedPitch.pitchClass,
            session: &quarterNoteSequenceSession
        )
        self.quarterNoteSequenceSession = quarterNoteSequenceSession
        applyQuarterNoteSequenceProjection(
            generatedSequence,
            reason: "answered",
            showsLog: false
        )

        switch answerResult {
        case .ignored(.completedSession):
            print(
                "[QuarterNoteSequence][macOS] result=ignored reason=completedSession string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
            )
        case let .evaluated(evaluation):
            print(
                "[macOS] \(evaluation.debugSummary()) selected=\(selectedPitch.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
            )
        }
    }

    // trainer prompt 的平台组装入口仍然收口在控制器：
    // 这里同时同步控制台日志与目标音组件显示内容。
    private func applyFretboardTrainerPrompt(reason: String) {
        quarterNoteSequenceSession = nil
        let prompt = currentFretboardTrainerPrompt
        targetNotePromptView.apply(content: prompt.targetPromptContent)
        print(
            "[FretboardTrainer][macOS] target=\(prompt.displayText) state=\(reason)"
        )
    }

    // 外部入口改为直接走统一 trainerDisplayState 管线，
    // 这样 settings 切换与内部调试入口会复用同一套 sequence 同步逻辑。
    func startQuarterNoteSequenceExercise(
        with spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) {
        trainerDisplayState = TrainerDisplayState(
            exerciseMode: .sequence,
            sequenceConfiguration: TrainerSequenceConfiguration(
                quarterNoteSequenceSpec: spec
            )
        )
        synchronizeTrainerPresentationState(reason: "generated")
    }

    private func synchronizeTrainerPresentationState(reason: String) {
        switch trainerDisplayState.exerciseMode {
        case .single:
            synchronizeSingleTrainerPresentation(reason: reason)
        case .sequence:
            synchronizeQuarterNoteSequencePresentation(reason: reason)
        }
    }

    private func synchronizeSingleTrainerPresentation(reason: String) {
        if isQuarterNoteSequenceMode {
            fretboardTrainerState = FretboardNaturalNoteTrainerState()
        }

        quarterNoteSequenceSession = nil

        if staffDisplayState != baseStaffDisplayState {
            staffDisplayState = baseStaffDisplayState
        }

        applyFretboardTrainerPrompt(reason: reason)
    }

    private func synchronizeQuarterNoteSequencePresentation(reason: String) {
        if pageDisplayState.mainContentMode != .fretboard {
            pageDisplayState.setMainContentMode(.fretboard)
        }

        let requiresNewSequence: Bool
        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            requiresNewSequence = true
        case let .quarterNoteSequence(currentSpec):
            requiresNewSequence = currentSpec != configuredQuarterNoteSequenceSpec
                || currentGeneratedQuarterNoteSequence == nil
        }

        let generatedSequence: GeneratedNoteSequence
        if requiresNewSequence {
            fretboardTrainerState = FretboardNaturalNoteTrainerState(
                quarterNoteSequenceSpec: configuredQuarterNoteSequenceSpec
            )
            generatedSequence = fretboardTrainerState.generateQuarterNoteSequence()
        } else {
            generatedSequence = currentGeneratedQuarterNoteSequence!
        }

        if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
            quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        }

        applyQuarterNoteSequenceProjection(generatedSequence, reason: reason)
    }

    private func applyQuarterNoteSequenceProjection(
        _ generatedSequence: GeneratedNoteSequence,
        reason: String,
        showsLog: Bool = true
    ) {
        let content = currentQuarterNoteSequenceTargetPromptContent
            ?? generatedSequence.targetPromptContent()
        targetNotePromptView.apply(content: content)

        var nextStaffDisplayState = staffDisplayState
        nextStaffDisplayState.apply(generatedSequence: generatedSequence)

        if nextStaffDisplayState != staffDisplayState {
            staffDisplayState = nextStaffDisplayState
        }

        if showsLog {
            print(
                "[QuarterNoteSequence][macOS] clef=\(generatedSequence.clef.title) noteCount=\(generatedSequence.noteCount) includesAccidentals=\(configuredQuarterNoteSequenceSpec.includesAccidentals) state=\(reason)"
            )
        }
    }

    private func normalizeSettingsPanelStateContextForTrainerMode(
        _ stateContext: inout SettingsPanelStateContext
    ) {
        guard stateContext.trainerDisplayState.isSequenceMode else {
            return
        }

        stateContext.pageDisplayState.mainContentMode = .fretboard

        if let currentGeneratedQuarterNoteSequence {
            stateContext.staffDisplayState.apply(
                generatedSequence: currentGeneratedQuarterNoteSequence
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

    // 控制器仍然持有 settings 展示状态真相；
    // 后续阶段把页面入口按钮隐藏/恢复接到这里即可，不必分散到多个调用点。
    private func applySettingsPresentationState() {
        settingsContainerView.setPresented(isSettingsPresented)
        settingsButton.isHidden = isSettingsPresented
        updateSettingsButtonAppearance()
    }

    private func updateSettingsButtonAppearance() {
        settingsButton.contentTintColor = isSettingsPresented ? .white : .labelColor
        settingsButton.layer?.backgroundColor = (
            isSettingsPresented
                ? NSColor.controlAccentColor
                : NSColor.controlBackgroundColor
        ).cgColor
        settingsButton.toolTip = isSettingsPresented ? "Hide settings" : "Show settings"
    }

    @objc
    private func handleSettingsButtonTap() {
        setSettingsPresented(!isSettingsPresented)
    }

    private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
        var nextStateContext = settingsPanelStateContext
        event.apply(to: &nextStateContext)
        let nextRequestedStaffDisplayState = nextStateContext.staffDisplayState
        normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

        let nextDisplayState = nextStateContext.fretboardDisplayState
        let nextStaffDisplayState = nextStateContext.staffDisplayState
        let nextPageDisplayState = nextStateContext.pageDisplayState
        let nextTrainerDisplayState = nextStateContext.trainerDisplayState

        let didChangeFretboard = nextDisplayState != displayState
        let didChangeStaff = nextStaffDisplayState != staffDisplayState
        let didChangePage = nextPageDisplayState != pageDisplayState
        let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState

        guard didChangeFretboard || didChangeStaff || didChangePage || didChangeTrainer else {
            return
        }

        if nextTrainerDisplayState.isSequenceMode,
           nextRequestedStaffDisplayState != staffDisplayState {
            baseStaffDisplayState = nextRequestedStaffDisplayState
        }

        if didChangeTrainer {
            trainerDisplayState = nextTrainerDisplayState
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

        if didChangeTrainer {
            synchronizeTrainerPresentationState(reason: "exerciseModeChanged")
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

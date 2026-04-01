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

    private static let initialPianoDemoConfiguration = PianoConfiguration(
        whiteKeyWidth: 30,
        rowHeight: 216,
        rowSpacing: 10,
        scaleAreaHeight: 28,
        buttonAreaWidth: 30,
        blackKeyWidthRatio: 0.62,
        blackKeyHeightRatio: 0.6,
        whiteKeyStyle: .borderlessSeparatedByGaps,
        snapEnabled: true
    )

    private static let initialPianoDemoRows: [PianoRowState] = [
        PianoRowState(
            startNote: NotePitch(pitchClass: .c, octave: 5),
            movementScope: .cascade
        ),
        PianoRowState(
            startNote: NotePitch(pitchClass: .c, octave: 4),
            movementScope: .cascade
        ),
        PianoRowState(
            startNote: NotePitch(pitchClass: .fSharp, octave: 3),
            movementScope: .rowOnly
        )
    ]
    private static let initialPianoPanelState = PianoPanelState.inferred(
        configuration: initialPianoDemoConfiguration,
        rows: initialPianoDemoRows
    )
    private static let initialExerciseLayoutPreferences = LegacyPageLayoutAdapter
        .inferredPreferences(
            pageDisplayState: .default,
            trainerDisplayState: .default,
            pianoPanelState: initialPianoPanelState
        )
    private static let initialExercisePresentationState = ExerciseCompositionPolicy
        .makeLegacyCompatiblePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: .default,
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: initialStaffDisplayState,
                pianoPanelState: initialPianoPanelState,
                layoutPreferences: initialExerciseLayoutPreferences
            )
        )

    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyFretboardDisplayState()
        }
    }

    private var staffDisplayState = iOSViewController.initialStaffDisplayState {
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
    private var pageDisplayState = iOSViewController.initialExercisePresentationState
        .legacyPageDisplayState ?? .default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyPageDisplayState()
            handleQuarterNoteSequencePageDisplayStateTransition(
                from: oldValue,
                to: pageDisplayState
            )
        }
    }
    private var exerciseLayoutPreferences = iOSViewController
        .initialExerciseLayoutPreferences {
        didSet {
            guard isViewLoaded else {
                return
            }

            applySettingsPanelState()
        }
    }
    private var exercisePresentationState = iOSViewController
        .initialExercisePresentationState
    private var trainerDisplayState = TrainerDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applySettingsPanelState()
            applySequenceRegenerateButtonState()
        }
    }
    private var baseStaffDisplayState = iOSViewController.initialStaffDisplayState

    private var isSettingsPresented = false
    private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
    private var singleCoverageSession: FretboardNaturalNoteTrainerState.SingleCoverageSession?
    private var singleCoverageLastEvaluation: FretboardNaturalNoteTrainerState.SingleCoverageEvaluation?
    private var positionPromptSession: FretboardNaturalNoteTrainerState.PositionPromptSession?
    private var positionPromptLastEvaluation: FretboardNaturalNoteTrainerState.PositionPromptEvaluation?
    private var positionPromptOverlayPhase: FretboardFeedbackOverlayState.PositionPromptPhase?
    private var pendingPositionPromptTransitionWorkItem: DispatchWorkItem?
    private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?
    private var quarterNoteSequenceLastEvaluation: FretboardNaturalNoteTrainerState.QuarterNoteSequenceEvaluation?
    private var hasLoggedInitialLayoutPass = false
    private let pianoBaseConfiguration = iOSViewController.initialPianoDemoConfiguration
    private var pianoBaseRows = iOSViewController.initialPianoDemoRows
    private var pianoPanelState = iOSViewController.initialPianoPanelState
    private var pianoDemoPreview: PianoPreviewState?
    private var pianoDemoLastEventText = "ready"

    private func logLifecycle(_ message: String) {
        print("[Startup][iOSVC] \(message) \(debugStateSnapshot())")
    }

    private func debugStateSnapshot() -> String {
        "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
        "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
        "pageTop=\(String(describing: pageDisplayState.topContentMode)) " +
        "pageMain=\(String(describing: pageDisplayState.mainContentMode)) " +
        "displayMode=\(String(describing: displayState.displayMode)) " +
        "showsFretboard=\(isShowingFretboard) " +
        "settingsPresented=\(isSettingsPresented)"
    }

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

    private var currentSingleCoverageRequiredCells: Set<FretboardCell> {
        guard case .singleNaturalTarget = fretboardTrainerState.mode else {
            return []
        }

        return Set(
            displayState.configuration.cells(
                for: fretboardTrainerState.targetPitchClass
            )
        )
    }

    private var currentSingleCoverageTargetPromptContent: TargetPromptContent {
        guard let singleCoverageSession,
              singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) else {
            return .single(
                text: fretboardTrainerState.targetPitchClass.displayText(
                    using: displayState.spelling
                )
            )
        }

        return singleCoverageSession.targetPromptContent(
            spelling: displayState.spelling
        )
    }

    private var currentPositionPromptFilter: PositionPromptCandidateFilter {
        trainerDisplayState.positionPromptConfiguration.activeFilter
    }

    private var currentPositionPromptCandidatePoolSignature: FretboardNaturalNoteTrainerState.PositionPromptSession.SchedulingState.CandidatePoolSignature {
        FretboardNaturalNoteTrainerState.positionPromptCandidatePoolSignature(
            in: displayState.configuration,
            filter: currentPositionPromptFilter
        )
    }

    private var currentPositionPromptOverlayPhase: FretboardFeedbackOverlayState.PositionPromptPhase {
        positionPromptOverlayPhase ?? .neutralWhite
    }

    private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            guard let singleCoverageSession,
                  singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) else {
                return .empty
            }

            let wrongCell: FretboardCell?
            if let singleCoverageLastEvaluation,
               singleCoverageLastEvaluation.hitKind == .wrong {
                wrongCell = singleCoverageLastEvaluation.selectedCell
            } else {
                wrongCell = nil
            }

            return .singleCoverage(
                correctCells: singleCoverageSession.visitedCells,
                wrongCell: wrongCell
            )
        case .positionPrompt:
            guard let positionPromptSession,
                  positionPromptSessionMatchesCurrentTrainer(positionPromptSession) else {
                return .empty
            }

            return .positionPrompt(
                promptCell: currentPositionPromptOverlayCell(
                    for: positionPromptSession
                ),
                phase: currentPositionPromptOverlayPhase
            )
        case .quarterNoteSequence:
            return .empty
        }
    }

    private func currentQuarterNoteSequenceStaffPresentation(
        for generatedSequence: GeneratedNoteSequence
    ) -> StaffSequencePresentation? {
        let staffVisibleLastEvaluation = isShowingStaffTopContent
            ? quarterNoteSequenceLastEvaluation
            : nil
        if let quarterNoteSequenceSession,
           quarterNoteSequenceSession.generatedSequence == generatedSequence {
            return StaffSequencePresentation.fromProgress(
                totalCount: quarterNoteSequenceSession.totalCount,
                currentIndex: quarterNoteSequenceSession.currentIndex,
                lastEvaluatedIndex: staffVisibleLastEvaluation?.answeredIndex,
                lastEvaluationResult: staffVisibleLastEvaluation.map {
                    $0.isCorrect ? .correct : .incorrect
                }
            )
        }

        return StaffSequencePresentation.fromProgress(
            totalCount: generatedSequence.noteCount,
            currentIndex: 0
        )
    }

    private func clearQuarterNoteSequenceFeedbackState() {
        quarterNoteSequenceLastEvaluation = nil
    }

    private func clearSingleCoverageFeedbackState() {
        singleCoverageLastEvaluation = nil
    }

    private func cancelPendingPositionPromptTransition() {
        pendingPositionPromptTransitionWorkItem?.cancel()
        pendingPositionPromptTransitionWorkItem = nil
    }

    private func clearPositionPromptFeedbackState() {
        positionPromptLastEvaluation = nil
    }

    private func resetPositionPromptInteractionState() {
        cancelPendingPositionPromptTransition()
        positionPromptSession = nil
        clearPositionPromptFeedbackState()
        positionPromptOverlayPhase = nil
        updateNaturalNoteStripInteractionState()
    }

    private func resetSingleCoverageInteractionState() {
        singleCoverageSession = nil
        clearSingleCoverageFeedbackState()
    }

    private func resetQuarterNoteSequenceInteractionState() {
        quarterNoteSequenceSession = nil
        clearQuarterNoteSequenceFeedbackState()
    }

    private func singleCoverageSessionMatchesCurrentTrainer(
        _ session: FretboardNaturalNoteTrainerState.SingleCoverageSession
    ) -> Bool {
        session.targetPitchClass == fretboardTrainerState.targetPitchClass
            && session.requiredCells == currentSingleCoverageRequiredCells
    }

    private func ensureSingleCoverageSession() {
        guard case .singleNaturalTarget = fretboardTrainerState.mode else {
            return
        }

        if let singleCoverageSession,
           singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) {
            return
        }

        singleCoverageSession = fretboardTrainerState.makeSingleCoverageSession(
            configuration: displayState.configuration
        )
        clearSingleCoverageFeedbackState()
    }

    private func positionPromptSessionMatchesCurrentTrainer(
        _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
    ) -> Bool {
        guard case .positionPrompt = fretboardTrainerState.mode else {
            return false
        }
        guard positionPromptSchedulingMatchesCurrentTrainer(session) else {
            return false
        }

        let visiblePrompt = currentPositionPromptVisiblePrompt(
            for: session
        )
        return positionPromptCellMatchesCurrentTrainer(
            visiblePrompt.cell,
            expectedPitchClass: visiblePrompt.pitchClass
        )
    }

    private func positionPromptSchedulingMatchesCurrentTrainer(
        _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
    ) -> Bool {
        session.schedulingState.candidatePoolSignature
            == currentPositionPromptCandidatePoolSignature
    }

    private func currentPositionPromptVisiblePrompt(
        for session: FretboardNaturalNoteTrainerState.PositionPromptSession
    ) -> (cell: FretboardCell, pitchClass: PitchClass) {
        guard let positionPromptLastEvaluation else {
            return (
                cell: session.promptCell,
                pitchClass: session.promptPitchClass
            )
        }

        switch currentPositionPromptOverlayPhase {
        case .neutralWhite:
            return (
                cell: session.promptCell,
                pitchClass: session.promptPitchClass
            )
        case .wrongFlash, .correctHold:
            return (
                cell: positionPromptLastEvaluation.promptCell,
                pitchClass: positionPromptLastEvaluation.expectedPitchClass
            )
        }
    }

    private func positionPromptCellMatchesCurrentTrainer(
        _ cell: FretboardCell,
        expectedPitchClass: PitchClass
    ) -> Bool {
        guard let resolvedPitchClass = displayState.configuration.pitchClass(
                for: cell
              ),
              resolvedPitchClass == expectedPitchClass,
              resolvedPitchClass.isNatural else {
            return false
        }

        switch currentPositionPromptFilter {
        case let .noteNames(selectedPitchClasses):
            return selectedPitchClasses.contains(resolvedPitchClass)
        case let .frets(selectedFrets):
            return selectedFrets.contains(cell.fret)
        }
    }

    private func ensurePositionPromptSession() {
        guard case .positionPrompt = fretboardTrainerState.mode else {
            return
        }

        if let positionPromptSession,
           positionPromptSessionMatchesCurrentTrainer(positionPromptSession) {
            if positionPromptOverlayPhase == nil {
                positionPromptOverlayPhase = .neutralWhite
            }
            return
        }

        cancelPendingPositionPromptTransition()
        var generator = SystemRandomNumberGenerator()
        positionPromptSession = fretboardTrainerState.makePositionPromptSession(
            configuration: displayState.configuration,
            filter: currentPositionPromptFilter,
            using: &generator
        )
        clearPositionPromptFeedbackState()
        positionPromptOverlayPhase = .neutralWhite
    }

    private func currentPositionPromptOverlayCell(
        for session: FretboardNaturalNoteTrainerState.PositionPromptSession
    ) -> FretboardCell {
        guard let positionPromptLastEvaluation else {
            return session.promptCell
        }

        switch currentPositionPromptOverlayPhase {
        case .neutralWhite:
            return session.promptCell
        case .wrongFlash, .correctHold:
            return positionPromptLastEvaluation.promptCell
        }
    }

    private func updateSingleCoverageFeedbackState(
        with answerResult: FretboardNaturalNoteTrainerState.SingleCoverageAnswerResult
    ) {
        if case let .evaluated(evaluation) = answerResult {
            singleCoverageLastEvaluation = evaluation
        }
    }

    private func updateQuarterNoteSequenceFeedbackState(
        with answerResult: FretboardNaturalNoteTrainerState.QuarterNoteSequenceAnswerResult
    ) {
        guard isShowingStaffTopContent else {
            clearQuarterNoteSequenceFeedbackState()
            return
        }

        if case let .evaluated(evaluation) = answerResult {
            quarterNoteSequenceLastEvaluation = evaluation
        }
    }

    private func sanitizedSequenceFreeStaffDisplayState(
        _ state: StaffDisplayState
    ) -> StaffDisplayState {
        var state = state
        state.clearSequencePresentation()
        return state
    }

    private func handleQuarterNoteSequencePageDisplayStateTransition(
        from oldValue: PageDisplayState,
        to newValue: PageDisplayState
    ) {
        guard trainerDisplayState.isSequenceMode,
              oldValue.topContentMode == .staff,
              newValue.topContentMode != .staff,
              quarterNoteSequenceLastEvaluation != nil else {
            return
        }

        clearQuarterNoteSequenceFeedbackState()
        guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
            return
        }

        applyQuarterNoteSequenceProjection(
            generatedSequence,
            reason: "topContentHidden",
            showsLog: false
        )
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

    private var isShowingFretboard: Bool {
        pageDisplayState.showsFretboard
    }

    private var isShowingFretboardTopContent: Bool {
        pageDisplayState.showsFretboardInTopContent
    }

    private var isShowingFretboardMainContent: Bool {
        pageDisplayState.showsFretboardInMainContent
    }

    private var isShowingStaffTopContent: Bool {
        pageDisplayState.topContentMode == .staff
    }

    private var isShowingTargetPromptTopContent: Bool {
        pageDisplayState.topContentMode == .targetPrompt
    }

    private var isShowingNaturalNoteStripMainContent: Bool {
        pageDisplayState.mainContentMode == .naturalNoteStrip
    }

    private var settingsPanelStateContext: SettingsPanelStateContext {
        SettingsPanelStateContext(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState,
            pageDisplayState: pageDisplayState,
            exerciseLayoutPreferences: exerciseLayoutPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: pianoPanelState
        )
    }

    private var exerciseCompositionPolicyInput: ExerciseCompositionPolicyInput {
        ExerciseCompositionPolicyInput(
            trainerDisplayState: trainerDisplayState,
            fretboardTrainerState: fretboardTrainerState,
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState,
            pianoPanelState: pianoPanelState,
            layoutPreferences: exerciseLayoutPreferences
        )
    }

    private func synchronizeExerciseCompositionState(reason: String) {
        let semanticPresentationState = ExerciseCompositionPolicy.makePresentation(
            from: exerciseCompositionPolicyInput
        )
        exercisePresentationState = semanticPresentationState

        if exerciseLayoutPreferences
            != semanticPresentationState.resolvedLayoutPreferences {
            exerciseLayoutPreferences = semanticPresentationState
                .resolvedLayoutPreferences
        }

        var legacyCompatibleInput = exerciseCompositionPolicyInput
        legacyCompatibleInput.layoutPreferences = semanticPresentationState
            .resolvedLayoutPreferences
        let legacyCompatiblePresentationState = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(from: legacyCompatibleInput)

        guard let legacyPageDisplayState = legacyCompatiblePresentationState
            .legacyPageDisplayState else {
            logLifecycle(
                "synchronizeExerciseCompositionState reason=\(reason) legacyProjection=unavailable"
            )
            return
        }

        if pageDisplayState != legacyPageDisplayState {
            pageDisplayState = legacyPageDisplayState
        }
    }

    private var resolvedPianoDemoConfiguration: PianoConfiguration {
        PianoPanelProjection.resolvedConfiguration(
            from: pianoBaseConfiguration,
            panelState: pianoPanelState
        )
    }

    private var resolvedPianoDemoRows: [PianoRowState] {
        PianoPanelProjection.resolvedRows(
            from: pianoBaseRows,
            panelState: pianoPanelState
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

    private lazy var labelVisibilityButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.buttonSize = .medium
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "eye.slash.fill")
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 10,
            bottom: 10,
            trailing: 10
        )
        button.configuration = configuration
        button.accessibilityIdentifier = "floating-fretboard-label-visibility-button"
        button.addTarget(
            self,
            action: #selector(handleLabelVisibilityButtonTap),
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
            model: SettingsNavigationSnapshotBuilder.makeModel(
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

    private lazy var sequenceRegenerateButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.buttonSize = .small
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "arrow.clockwise")
        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: 8,
            bottom: 8,
            trailing: 8
        )
        button.configuration = configuration
        button.accessibilityIdentifier = "top-content-sequence-regenerate-button"
        button.accessibilityLabel = "Generate new random sequence"
        button.isHidden = true
        button.addTarget(
            self,
            action: #selector(handleSequenceRegenerateButtonTap),
            for: .touchUpInside
        )
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        return button
    }()

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let topContentHostView = UIView()
    private let mainContentHostView = UIView()
    private let pianoDemoContainerView = UIView()
    private let fretboardHostView = UIView()
    private let fretboardViewportScrollView = UIScrollView()
    private let fretboardScrollContentView = UIView()
    private var horizontalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardContentWidthConstraint: NSLayoutConstraint?
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?
    private var pianoDemoBottomToContentConstraint: NSLayoutConstraint?
    private var mainContentBottomToContentConstraint: NSLayoutConstraint?
    private var topContentStaffConstraints: [NSLayoutConstraint] = []
    private var topContentTargetPromptConstraints: [NSLayoutConstraint] = []
    private var topContentFretboardConstraints: [NSLayoutConstraint] = []
    private var mainContentFretboardConstraints: [NSLayoutConstraint] = []
    private var mainContentNaturalNoteStripConstraints: [NSLayoutConstraint] = []
    private var activeFretboardHostConstraints: [NSLayoutConstraint] = []

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
        naturalNoteStripView.onPitchClassTap = { [weak self] pitchClass in
            self?.handleNaturalNoteStripPitchClassTap(pitchClass)
        }
        naturalNoteStripView.isHidden = true
        return naturalNoteStripView
    }()

    private lazy var pianoDemoTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.text = "Piano Keyboard Demo"
        return label
    }()

    private lazy var pianoDemoStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = ""
        return label
    }()

    private lazy var pianoKeyboardView: iOSPianoKeyboardView = {
        let pianoKeyboardView = iOSPianoKeyboardView(
            configuration: resolvedPianoDemoConfiguration,
            rows: resolvedPianoDemoRows
        )
        pianoKeyboardView.onRowsChanged = { [weak self] rows in
            self?.handlePianoDemoRowsChanged(rows)
        }
        pianoKeyboardView.onPreviewStarted = { [weak self] preview in
            self?.handlePianoDemoPreviewStarted(preview)
        }
        pianoKeyboardView.onPreviewChanged = { [weak self] preview in
            self?.handlePianoDemoPreviewChanged(preview)
        }
        pianoKeyboardView.onPreviewEnded = { [weak self] preview in
            self?.handlePianoDemoPreviewEnded(preview)
        }
        return pianoKeyboardView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        logLifecycle("viewDidLoad begin")
        view.backgroundColor = .systemBackground
        configureLayout()
        applyDisplayState()
        applyPianoDemoState()
        logLifecycle("viewDidLoad end")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        syncVerticalFretboardContentWidthConstraint()
        updateFretboardViewportPresentation()
        if !hasLoggedInitialLayoutPass {
            hasLoggedInitialLayoutPass = true
            logLifecycle("first layout pass bounds=\(view.bounds)")
        }
    }

    private func configureLayout() {
        logLifecycle("configureLayout begin")
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        labelVisibilityButton.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
        topContentHostView.translatesAutoresizingMaskIntoConstraints = false
        mainContentHostView.translatesAutoresizingMaskIntoConstraints = false
        pianoDemoContainerView.translatesAutoresizingMaskIntoConstraints = false
        sequenceRegenerateButton.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false
        naturalNoteStripView.translatesAutoresizingMaskIntoConstraints = false
        pianoDemoTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        pianoDemoStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        pianoKeyboardView.translatesAutoresizingMaskIntoConstraints = false
        fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
        fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
        fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        pianoDemoContainerView.backgroundColor = .secondarySystemBackground
        pianoDemoContainerView.layer.cornerRadius = Layout.pianoDemoCornerRadius
        pianoDemoContainerView.layer.cornerCurve = .continuous
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
        topContentHostView.addSubview(sequenceRegenerateButton)
        contentView.addSubview(mainContentHostView)
        contentView.addSubview(pianoDemoContainerView)
        mainContentHostView.addSubview(fretboardHostView)
        mainContentHostView.addSubview(naturalNoteStripView)
        pianoDemoContainerView.addSubview(pianoDemoTitleLabel)
        pianoDemoContainerView.addSubview(pianoDemoStatusLabel)
        pianoDemoContainerView.addSubview(pianoKeyboardView)
        fretboardHostView.addSubview(fretboardViewportScrollView)
        fretboardViewportScrollView.addSubview(fretboardScrollContentView)
        fretboardScrollContentView.addSubview(fretboardView)
        view.addSubview(settingsButton)
        view.addSubview(labelVisibilityButton)
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
        topContentFretboardConstraints = [
            fretboardHostView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
            fretboardHostView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
            fretboardHostView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
            fretboardHostView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor)
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
        pianoDemoBottomToContentConstraint = pianoDemoContainerView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
        mainContentBottomToContentConstraint = mainContentHostView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
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
            sequenceRegenerateButton.topAnchor.constraint(
                equalTo: topContentHostView.topAnchor,
                constant: Layout.topContentFloatingButtonInset
            ),
            sequenceRegenerateButton.trailingAnchor.constraint(
                equalTo: topContentHostView.trailingAnchor,
                constant: -Layout.topContentFloatingButtonInset
            ),
            sequenceRegenerateButton.widthAnchor.constraint(
                equalToConstant: Layout.sequenceRegenerateButtonSize
            ),
            sequenceRegenerateButton.heightAnchor.constraint(
                equalToConstant: Layout.sequenceRegenerateButtonSize
            ),
            mainContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainContentHostView.topAnchor.constraint(
                equalTo: topContentHostView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            pianoDemoContainerView.topAnchor.constraint(
                equalTo: mainContentHostView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            pianoDemoContainerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            pianoDemoContainerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            pianoDemoBottomToContentConstraint!,
            pianoDemoTitleLabel.leadingAnchor.constraint(
                equalTo: pianoDemoContainerView.leadingAnchor,
                constant: Layout.pianoDemoInnerInset
            ),
            pianoDemoTitleLabel.trailingAnchor.constraint(
                equalTo: pianoDemoContainerView.trailingAnchor,
                constant: -Layout.pianoDemoInnerInset
            ),
            pianoDemoTitleLabel.topAnchor.constraint(
                equalTo: pianoDemoContainerView.topAnchor,
                constant: Layout.pianoDemoInnerInset
            ),
            pianoDemoStatusLabel.leadingAnchor.constraint(
                equalTo: pianoDemoTitleLabel.leadingAnchor
            ),
            pianoDemoStatusLabel.trailingAnchor.constraint(
                equalTo: pianoDemoTitleLabel.trailingAnchor
            ),
            pianoDemoStatusLabel.topAnchor.constraint(
                equalTo: pianoDemoTitleLabel.bottomAnchor,
                constant: Layout.pianoDemoStatusTopSpacing
            ),
            pianoKeyboardView.leadingAnchor.constraint(
                equalTo: pianoDemoTitleLabel.leadingAnchor
            ),
            pianoKeyboardView.trailingAnchor.constraint(
                equalTo: pianoDemoTitleLabel.trailingAnchor
            ),
            pianoKeyboardView.topAnchor.constraint(
                equalTo: pianoDemoStatusLabel.bottomAnchor,
                constant: Layout.pianoDemoKeyboardTopSpacing
            ),
            pianoKeyboardView.bottomAnchor.constraint(
                equalTo: pianoDemoContainerView.bottomAnchor,
                constant: -Layout.pianoDemoInnerInset
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
            labelVisibilityButton.trailingAnchor.constraint(
                equalTo: safeArea.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            labelVisibilityButton.topAnchor.constraint(
                equalTo: safeArea.topAnchor,
                constant: Layout.topInset
            ),
            labelVisibilityButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            labelVisibilityButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            settingsContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateFretboardLayoutModeConstraints()
        applySettingsPresentationState()
        logLifecycle("configureLayout end")
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

        guard isShowingFretboard else {
            return
        }

        verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.heightAnchor,
            multiplier: displayState.verticalHostHeightRatio
        )
    }

    private func applyDisplayState() {
        logLifecycle("applyDisplayState begin")
        applyFretboardDisplayState()
        applyStaffDisplayState()
        applyPageDisplayState()
        applySequenceRegenerateButtonState()
        applyLabelVisibilityButtonState()
        synchronizeTrainerPresentationState(reason: "initial")
        logLifecycle("applyDisplayState end")
    }

    private func applyFretboardDisplayState() {
        logLifecycle("applyFretboardDisplayState begin")
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
        fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
        rebuildVerticalFretboardHostHeightConstraint()
        applySettingsPanelState()
        applyLabelVisibilityButtonState()
        updateFretboardLayoutModeConstraints()

        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            applySingleCoverageProjection(
                reason: "fretboardDisplayChanged",
                showsLog: false
            )
        case .positionPrompt:
            applyPositionPromptProjection(
                reason: "fretboardDisplayChanged",
                showsLog: false
            )
        case .quarterNoteSequence:
            applyCurrentFretboardFeedbackOverlayState()
            updateNaturalNoteStripInteractionState()
        }

        guard isShowingFretboard else {
            logLifecycle("applyFretboardDisplayState end without visible fretboard")
            return
        }

        updateLayoutIfNeeded()
        syncVerticalFretboardContentWidthConstraint()
        updateLayoutIfNeeded()
        updateFretboardViewportPresentation()
        logLifecycle("applyFretboardDisplayState end")
    }

    private func applyStaffDisplayState() {
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        staffView.showsComponentBoundsOverlay = staffDisplayState.showsComponentBoundsOverlay
        applySettingsPanelState()
        updateLayoutIfNeeded()
    }

    private func applyPageDisplayState() {
        logLifecycle("applyPageDisplayState begin")
        applyFretboardHostPlacement()
        applyTopContentMode()
        applyMainContentMode()
        applySettingsPanelState()
        applyLabelVisibilityButtonState()
        updateLayoutIfNeeded()

        if isShowingFretboard {
            syncVerticalFretboardContentWidthConstraint()
            updateLayoutIfNeeded()
        }

        updateFretboardViewportPresentation()
        logLifecycle("applyPageDisplayState end")
    }

    private func applyFretboardHostPlacement() {
        let desiredHost = isShowingFretboardTopContent
            ? "top"
            : (isShowingFretboardMainContent ? "main" : "hidden")
        logLifecycle("applyFretboardHostPlacement target=\(desiredHost)")
        let desiredSuperview = isShowingFretboardTopContent
            ? topContentHostView
            : mainContentHostView
        if fretboardHostView.superview !== desiredSuperview {
            NSLayoutConstraint.deactivate(activeFretboardHostConstraints)
            activeFretboardHostConstraints = []
            fretboardHostView.removeFromSuperview()
            desiredSuperview.addSubview(fretboardHostView)
            fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
        }

        let desiredConstraints: [NSLayoutConstraint]
        if isShowingFretboardTopContent {
            desiredConstraints = topContentFretboardConstraints
        } else if isShowingFretboardMainContent {
            desiredConstraints = mainContentFretboardConstraints
        } else {
            desiredConstraints = []
        }

        NSLayoutConstraint.deactivate(activeFretboardHostConstraints)
        if !desiredConstraints.isEmpty {
            NSLayoutConstraint.activate(desiredConstraints)
        }
        activeFretboardHostConstraints = desiredConstraints
        fretboardHostView.isHidden = !isShowingFretboard
    }

    private func applyTopContentMode() {
        let activeConstraints: [NSLayoutConstraint]
        if isShowingStaffTopContent {
            activeConstraints = topContentStaffConstraints
        } else if isShowingTargetPromptTopContent {
            activeConstraints = topContentTargetPromptConstraints
        } else {
            activeConstraints = []
        }

        staffView.isHidden = !isShowingStaffTopContent
        targetNotePromptView.isHidden = !isShowingTargetPromptTopContent
        NSLayoutConstraint.deactivate(topContentStaffConstraints + topContentTargetPromptConstraints)
        if !activeConstraints.isEmpty {
            NSLayoutConstraint.activate(activeConstraints)
        }
        logLifecycle(
            "applyTopContentMode staff=\(isShowingStaffTopContent) " +
            "targetPrompt=\(isShowingTargetPromptTopContent) " +
            "fretboard=\(isShowingFretboardTopContent)"
        )
    }

    private func applyMainContentMode() {
        naturalNoteStripView.isHidden = !isShowingNaturalNoteStripMainContent
        NSLayoutConstraint.deactivate(mainContentNaturalNoteStripConstraints)
        if isShowingNaturalNoteStripMainContent {
            NSLayoutConstraint.activate(mainContentNaturalNoteStripConstraints)
        }
        rebuildVerticalFretboardHostHeightConstraint()
        updateFretboardLayoutModeConstraints()
        logLifecycle(
            "applyMainContentMode fretboard=\(isShowingFretboardMainContent) " +
            "naturalStrip=\(isShowingNaturalNoteStripMainContent)"
        )
    }

    private func applySettingsPanelState() {
        settingsContainerView.navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: settingsPanelStateContext
        )
    }

    private func updateLayoutIfNeeded() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func syncVerticalFretboardContentWidthConstraint() {
        guard
            isShowingFretboard,
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
        guard isShowingFretboard else {
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
        case .positionPrompt:
            return
        case .quarterNoteSequence:
            handleQuarterNoteSequenceHitResult(hitResult)
        }
    }

    private func handleNaturalNoteStripPitchClassTap(_ pitchClass: PitchClass) {
        switch fretboardTrainerState.mode {
        case .positionPrompt:
            handlePositionPromptAnswer(pitchClass)
        case .singleNaturalTarget, .quarterNoteSequence:
            return
        }
    }

    private func handlePositionPromptAnswer(_ pitchClass: PitchClass) {
        guard case .positionPrompt = fretboardTrainerState.mode else {
            return
        }

        guard currentPositionPromptOverlayPhase == .neutralWhite else {
            print(
                "[PositionPrompt][iOS] result=ignored reason=feedbackInProgress phase=\(positionPromptDebugName(for: currentPositionPromptOverlayPhase))"
            )
            return
        }

        ensurePositionPromptSession()
        guard var positionPromptSession,
              positionPromptSessionMatchesCurrentTrainer(positionPromptSession) else {
            print("[PositionPrompt][iOS] result=ignored reason=missingSession")
            return
        }

        let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
            pitchClass,
            configuration: displayState.configuration,
            filter: currentPositionPromptFilter,
            session: &positionPromptSession
        )
        self.positionPromptSession = positionPromptSession

        switch answerResult {
        case let .evaluated(evaluation):
            positionPromptLastEvaluation = evaluation
            if evaluation.isCorrect {
                positionPromptOverlayPhase = .correctHold
                applyPositionPromptProjection(
                    reason: "correctHold",
                    showsLog: false
                )
                schedulePositionPromptTransition(
                    after: PositionPromptTiming.correctHoldDuration
                ) { controller in
                    guard case .positionPrompt = controller.fretboardTrainerState.mode else {
                        return
                    }
                    controller.clearPositionPromptFeedbackState()
                    controller.positionPromptOverlayPhase = .neutralWhite
                    controller.applyPositionPromptProjection(reason: "advanced")
                }
            } else {
                positionPromptOverlayPhase = .wrongFlash
                applyPositionPromptProjection(
                    reason: "wrongFlash",
                    showsLog: false
                )
                schedulePositionPromptTransition(
                    after: PositionPromptTiming.wrongFlashDuration
                ) { controller in
                    guard case .positionPrompt = controller.fretboardTrainerState.mode else {
                        return
                    }
                    controller.clearPositionPromptFeedbackState()
                    controller.positionPromptOverlayPhase = .neutralWhite
                    controller.applyPositionPromptProjection(
                        reason: "wrongFlashExpired",
                        showsLog: false
                    )
                }
            }

            print("[iOS] \(evaluation.debugSummary())")
        }
    }

    private func handleSingleNaturalTargetHitResult(_ hitResult: FretboardHitResult) {
        ensureSingleCoverageSession()
        guard var singleCoverageSession else {
            print("[SingleCoverage][iOS] result=ignored reason=missingSession")
            return
        }

        let answerResult = fretboardTrainerState.handleSingleCoverageHit(
            hitResult,
            configuration: displayState.configuration,
            session: &singleCoverageSession
        )

        switch answerResult {
        case .ignored(.nonEndedPhase):
            return
        case .ignored(.missingHitCell):
            print(
                "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
            )
        case let .ignored(.unresolvedHitPitch(cell)):
            print(
                "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
            )
        case .ignored(.completedSession):
            print(
                "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=completedSession"
            )
        case let .evaluated(evaluation):
            self.singleCoverageSession = singleCoverageSession
            updateSingleCoverageFeedbackState(with: answerResult)
            if evaluation.didAdvanceTarget {
                self.singleCoverageSession = fretboardTrainerState.makeSingleCoverageSession(
                    configuration: displayState.configuration
                )
                clearSingleCoverageFeedbackState()
            }
            applySingleCoverageProjection(
                reason: evaluation.didAdvanceTarget ? "advanced" : "answered",
                showsLog: false
            )
            print("[iOS] \(evaluation.debugSummary())")
        }
    }

    private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
        guard hitResult.phase == .ended else {
            return
        }

        guard let selectedCell = hitResult.cell else {
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=missingHitCell"
            )
            return
        }

        guard let selectedPitch = displayState.configuration.notePitch(for: selectedCell) else {
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=unresolvedHitPitch string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
            )
            return
        }

        guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=missingSequence"
            )
            return
        }

        if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
            quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
            clearQuarterNoteSequenceFeedbackState()
        }

        guard var quarterNoteSequenceSession else {
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=missingSession"
            )
            return
        }

        let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
            selectedPitch.pitchClass,
            session: &quarterNoteSequenceSession
        )
        self.quarterNoteSequenceSession = quarterNoteSequenceSession
        updateQuarterNoteSequenceFeedbackState(with: answerResult)
        applyQuarterNoteSequenceProjection(
            generatedSequence,
            reason: "answered",
            showsLog: false
        )

        switch answerResult {
        case .ignored(.completedSession):
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=completedSession string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
            )
        case let .evaluated(evaluation):
            print(
                "[iOS] \(evaluation.debugSummary()) selected=\(selectedPitch.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
            )
        }
    }

    // trainer prompt 的平台组装入口仍然收口在控制器：
    // 这里同时同步控制台日志与目标音组件显示内容。
    private func applyFretboardTrainerPrompt(reason: String) {
        resetQuarterNoteSequenceInteractionState()
        applySingleCoverageProjection(reason: reason)
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
        logLifecycle("synchronizeTrainerPresentationState reason=\(reason)")
        switch trainerDisplayState.exerciseMode {
        case .single:
            synchronizeSingleTrainerPresentation(reason: reason)
        case .sequence:
            synchronizeQuarterNoteSequencePresentation(reason: reason)
        case .positionPrompt:
            synchronizePositionPromptPresentation(reason: reason)
        }
    }

    private func synchronizeSingleTrainerPresentation(reason: String) {
        if case .positionPrompt = fretboardTrainerState.mode {
            resetPositionPromptInteractionState()
        }

        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            break
        case .positionPrompt, .quarterNoteSequence:
            fretboardTrainerState = FretboardNaturalNoteTrainerState()
            resetSingleCoverageInteractionState()
        }

        if staffDisplayState != baseStaffDisplayState {
            staffDisplayState = baseStaffDisplayState
        }

        synchronizeExerciseCompositionState(reason: reason)
        applyFretboardTrainerPrompt(reason: reason)
    }

    private func synchronizePositionPromptPresentation(reason: String) {
        resetSingleCoverageInteractionState()
        resetQuarterNoteSequenceInteractionState()

        if staffDisplayState != baseStaffDisplayState {
            staffDisplayState = baseStaffDisplayState
        }

        if reason == "positionPromptFilterChanged" {
            resetPositionPromptInteractionState()
        }

        if case .positionPrompt = fretboardTrainerState.mode {
            // 已在位置题模式内时尽量保留当前 session；
            // 只有在 configuration 失效时才会在 projection 中重建。
        } else {
            resetPositionPromptInteractionState()
            fretboardTrainerState = FretboardNaturalNoteTrainerState(
                positionPromptMode: ()
            )
        }

        synchronizeExerciseCompositionState(reason: reason)
        applyPositionPromptProjection(
            reason: reason,
            showsLog: true
        )
    }

    private func synchronizeQuarterNoteSequencePresentation(reason: String) {
        resetSingleCoverageInteractionState()
        resetPositionPromptInteractionState()

        let requiresNewSequence: Bool
        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            requiresNewSequence = true
        case .positionPrompt:
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
            clearQuarterNoteSequenceFeedbackState()
        }

        synchronizeExerciseCompositionState(reason: reason)
        applyQuarterNoteSequenceProjection(generatedSequence, reason: reason)
    }

    private func applyQuarterNoteSequenceProjection(
        _ generatedSequence: GeneratedNoteSequence,
        reason: String,
        showsLog: Bool = true
    ) {
        applyCurrentFretboardFeedbackOverlayState()
        updateNaturalNoteStripInteractionState()
        let content = currentQuarterNoteSequenceTargetPromptContent
            ?? generatedSequence.targetPromptContent()
        targetNotePromptView.apply(content: content)

        var nextStaffDisplayState = staffDisplayState
        nextStaffDisplayState.apply(
            generatedSequence: generatedSequence,
            sequencePresentation: currentQuarterNoteSequenceStaffPresentation(
                for: generatedSequence
            )
        )

        if nextStaffDisplayState != staffDisplayState {
            staffDisplayState = nextStaffDisplayState
        }

        if showsLog {
            print(
                "[QuarterNoteSequence][iOS] clef=\(generatedSequence.clef.title) noteCount=\(generatedSequence.noteCount) includesAccidentals=\(configuredQuarterNoteSequenceSpec.includesAccidentals) state=\(reason)"
            )
        }
    }

    private func applyCurrentFretboardFeedbackOverlayState() {
        fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
    }

    private func updateNaturalNoteStripInteractionState() {
        guard isViewLoaded else {
            return
        }

        let isInteractionEnabled = exercisePresentationState.surfaceState(
            for: .naturalNoteStrip
        )?.isInteractionEnabled ?? false

        if trainerDisplayState.isPositionPromptMode {
            naturalNoteStripView.isUserInteractionEnabled = isInteractionEnabled
                && currentPositionPromptOverlayPhase == .neutralWhite
        } else {
            naturalNoteStripView.isUserInteractionEnabled = isInteractionEnabled
        }
    }

    private func applySingleCoverageProjection(
        reason: String,
        showsLog: Bool = true
    ) {
        ensureSingleCoverageSession()
        targetNotePromptView.apply(content: currentSingleCoverageTargetPromptContent)
        applyCurrentFretboardFeedbackOverlayState()
        updateNaturalNoteStripInteractionState()

        guard showsLog else {
            return
        }

        let progressText: String
        if let singleCoverageSession {
            progressText = "\(singleCoverageSession.visitedCount)/\(singleCoverageSession.totalCount)"
        } else {
            progressText = "0/0"
        }

        print(
            "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) progress=\(progressText) state=\(reason)"
        )
    }

    private func applyPositionPromptProjection(
        reason: String,
        showsLog: Bool = true
    ) {
        ensurePositionPromptSession()
        applyCurrentFretboardFeedbackOverlayState()
        updateNaturalNoteStripInteractionState()

        guard
            showsLog,
            let positionPromptSession,
            positionPromptSessionMatchesCurrentTrainer(positionPromptSession)
        else {
            return
        }

        let visibleCell = currentPositionPromptOverlayCell(
            for: positionPromptSession
        )
        print(
            "[PositionPrompt][iOS] prompt=\(positionPromptSession.promptPitchClass.displayText()) string=\(visibleCell.stringIndex) fret=\(visibleCell.fret) phase=\(positionPromptDebugName(for: currentPositionPromptOverlayPhase)) state=\(reason)"
        )
    }

    private func applySequenceRegenerateButtonState() {
        sequenceRegenerateButton.isHidden = !trainerDisplayState.isSequenceMode
    }

    private func applyLabelVisibilityButtonState() {
        labelVisibilityButton.isHidden = !isShowingFretboard || isSettingsPresented
        updateLabelVisibilityButtonAppearance()
    }

    private func updateLabelVisibilityButtonAppearance() {
        let showsBCEFLabels = displayState.visibility == .bcefOnly
        var configuration = labelVisibilityButton.configuration ?? UIButton.Configuration.filled()
        configuration.image = UIImage(
            systemName: showsBCEFLabels ? "eye.fill" : "eye.slash.fill"
        )
        configuration.baseBackgroundColor = showsBCEFLabels
            ? .systemBlue
            : .secondarySystemBackground
        configuration.baseForegroundColor = showsBCEFLabels
            ? .white
            : .label
        labelVisibilityButton.configuration = configuration
        labelVisibilityButton.accessibilityLabel = showsBCEFLabels
            ? "Hide BCEF fretboard labels"
            : "Show BCEF fretboard labels"
    }

    private func regenerateQuarterNoteSequence(reason: String) {
        guard trainerDisplayState.isSequenceMode else {
            return
        }

        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            quarterNoteSequenceSpec: configuredQuarterNoteSequenceSpec
        )
        resetQuarterNoteSequenceInteractionState()
        synchronizeTrainerPresentationState(reason: reason)
    }

    private func schedulePositionPromptTransition(
        after delay: TimeInterval,
        perform update: @escaping (iOSViewController) -> Void
    ) {
        cancelPendingPositionPromptTransition()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            self.pendingPositionPromptTransitionWorkItem = nil
            update(self)
        }
        pendingPositionPromptTransitionWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }

    private func positionPromptDebugName(
        for phase: FretboardFeedbackOverlayState.PositionPromptPhase
    ) -> String {
        switch phase {
        case .neutralWhite:
            return "neutralWhite"
        case .wrongFlash:
            return "wrongFlash"
        case .correctHold:
            return "correctHold"
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
        applyLabelVisibilityButtonState()
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

    private func applyPianoDemoState() {
        pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
        pianoKeyboardView.rows = resolvedPianoDemoRows
        pianoKeyboardView.showsComponentBoundsOverlay = false
        pianoDemoContainerView.isHidden = !pianoPanelState.isVisible
        pianoDemoBottomToContentConstraint?.isActive = pianoPanelState.isVisible
        mainContentBottomToContentConstraint?.isActive = !pianoPanelState.isVisible
        updatePianoDemoStatusLabel()
    }

    private func updatePianoDemoStatusLabel() {
        pianoDemoStatusLabel.text = pianoDemoStatusText()
    }

    private func pianoDemoStatusText() -> String {
        let previewText: String
        if let pianoDemoPreview {
            previewText = "row\(pianoDemoPreview.rowIndex) \(pianoDemoPreview.note.displayText())"
        } else {
            previewText = "nil"
        }

        return [
            "event: \(pianoDemoLastEventText)",
            "preview: \(previewText)",
            "panel: visible=\(pianoPanelState.isVisible) rows=\(resolvedPianoDemoRows.count) scope=\(pianoPanelState.movementScope.debugName) style=\(resolvedPianoDemoConfiguration.whiteKeyStyle.debugName) snap=\(resolvedPianoDemoConfiguration.snapEnabled)",
            "rows: \(pianoDemoRowsSummaryText(resolvedPianoDemoRows))"
        ].joined(separator: "\n")
    }

    private func pianoDemoRowsSummaryText(_ rows: [PianoRowState]) -> String {
        rows.enumerated().map { index, row in
            "r\(index)=\(row.startNote.displayText())[\(row.movementScope.debugName)]"
        }.joined(separator: " | ")
    }

    private func handlePianoDemoRowsChanged(_ rows: [PianoRowState]) {
        pianoBaseRows = rows
        pianoDemoLastEventText = "rowsChanged"
        print("[PianoDemo][iOS] rowsChanged \(pianoDemoRowsSummaryText(rows))")
        applyPianoDemoState()
    }

    private func handlePianoDemoPreviewStarted(_ preview: PianoPreviewState) {
        pianoDemoPreview = preview
        pianoDemoLastEventText = "previewStarted"
        print("[PianoDemo][iOS] previewStarted row=\(preview.rowIndex) note=\(preview.note.displayText())")
        updatePianoDemoStatusLabel()
    }

    private func handlePianoDemoPreviewChanged(_ preview: PianoPreviewState) {
        pianoDemoPreview = preview
        pianoDemoLastEventText = "previewChanged"
        print("[PianoDemo][iOS] previewChanged row=\(preview.rowIndex) note=\(preview.note.displayText())")
        updatePianoDemoStatusLabel()
    }

    private func handlePianoDemoPreviewEnded(_ preview: PianoPreviewState) {
        pianoDemoPreview = nil
        pianoDemoLastEventText = "previewEnded row=\(preview.rowIndex) note=\(preview.note.displayText())"
        print("[PianoDemo][iOS] previewEnded row=\(preview.rowIndex) note=\(preview.note.displayText())")
        updatePianoDemoStatusLabel()
    }

    @objc
    private func handleSettingsButtonTap() {
        setSettingsPresented(!isSettingsPresented)
    }

    @objc
    private func handleLabelVisibilityButtonTap() {
        displayState.visibility = displayState.visibility == .bcefOnly
            ? .none
            : .bcefOnly
    }

    @objc
    private func handleSequenceRegenerateButtonTap() {
        regenerateQuarterNoteSequence(reason: "manualRegenerated")
    }

    private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
        var nextStateContext = settingsPanelStateContext
        event.apply(to: &nextStateContext)
        let nextRequestedStaffDisplayState = nextStateContext.staffDisplayState

        let nextDisplayState = nextStateContext.fretboardDisplayState
        let nextStaffDisplayState = nextStateContext.staffDisplayState
        let nextExerciseLayoutPreferences = nextStateContext
            .exerciseLayoutPreferences
        let nextTrainerDisplayState = nextStateContext.trainerDisplayState
        let nextPianoPanelState = nextStateContext.pianoPanelState

        let didChangeFretboard = nextDisplayState != displayState
        let didChangeStaff = nextStaffDisplayState != staffDisplayState
        let didChangeExerciseLayoutPreferences =
            nextExerciseLayoutPreferences != exerciseLayoutPreferences
        let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState
        let didChangePianoPanel = nextPianoPanelState != pianoPanelState
        let didChangeExerciseMode = nextTrainerDisplayState.exerciseMode != trainerDisplayState.exerciseMode
        let didChangePositionPromptActiveFilter =
            nextTrainerDisplayState.positionPromptConfiguration.activeFilter
            != trainerDisplayState.positionPromptConfiguration.activeFilter

        guard didChangeFretboard
            || didChangeStaff
            || didChangeExerciseLayoutPreferences
            || didChangeTrainer
            || didChangePianoPanel else {
            return
        }

        if nextTrainerDisplayState.isSequenceMode,
           nextRequestedStaffDisplayState != staffDisplayState {
            baseStaffDisplayState = sanitizedSequenceFreeStaffDisplayState(
                nextRequestedStaffDisplayState
            )
        }

        if didChangeTrainer {
            trainerDisplayState = nextTrainerDisplayState
        }

        if didChangeExerciseLayoutPreferences {
            exerciseLayoutPreferences = nextExerciseLayoutPreferences
        }

        if didChangeFretboard {
            displayState = nextDisplayState
        }

        if didChangeStaff {
            staffDisplayState = nextStaffDisplayState
        }

        if didChangePianoPanel {
            pianoPanelState = nextPianoPanelState
            applyPianoDemoState()
            applySettingsPanelState()
        }

        if didChangeTrainer {
            let trainerSyncReason: String
            if didChangeExerciseMode {
                trainerSyncReason = "exerciseModeChanged"
            } else if didChangePositionPromptActiveFilter {
                trainerSyncReason = "positionPromptFilterChanged"
            } else {
                trainerSyncReason = "trainerSettingsChanged"
            }
            synchronizeTrainerPresentationState(reason: trainerSyncReason)
        } else if didChangeExerciseLayoutPreferences
            || didChangePianoPanel
            || didChangeFretboard
            || didChangeStaff {
            synchronizeExerciseCompositionState(
                reason: "settingsStateChanged"
            )
        }
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let contentTopInset: CGFloat = 68
    static let topContentFloatingButtonInset: CGFloat = 12
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let pianoDemoInnerInset: CGFloat = 16
    static let pianoDemoStatusTopSpacing: CGFloat = 8
    static let pianoDemoKeyboardTopSpacing: CGFloat = 12
    static let pianoDemoCornerRadius: CGFloat = 16
    static let settingsButtonSize: CGFloat = 40
    static let sequenceRegenerateButtonSize: CGFloat = 36
    static let contentSizeTolerance: CGFloat = 0.5
}

private enum PositionPromptTiming {
    static let wrongFlashDuration: TimeInterval = 0.28
    static let correctHoldDuration: TimeInterval = 1.0
}
#endif

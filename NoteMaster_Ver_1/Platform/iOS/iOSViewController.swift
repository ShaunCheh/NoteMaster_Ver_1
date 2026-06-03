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

    private static let initialPianoPanelState = PianoSurfaceDefaults.panelState
    private static let initialExerciseLayoutPreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            .legacyPositionPrompt,
            trainerDisplayState: .default
        )
    private static let initialExercisePresentationState = ExerciseCompositionPolicy
        .makePresentation(
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

            if !trainerDisplayState.usesQuarterNoteSequenceKernel {
                baseStaffDisplayState = staffDisplayState
            }
            applyStaffDisplayState()
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
        .initialExercisePresentationState {
        didSet {
            guard isViewLoaded else {
                return
            }

            renderExercisePresentationState()
            handleQuarterNoteSequencePresentationTransition(
                from: oldValue,
                to: exercisePresentationState
            )
            updateAnswerSurfaceInteractionState()
            applyLabelVisibilityButtonState()
        }
    }
    private var trainerDisplayState = TrainerDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applySettingsPanelState()
            applySequenceRegenerateButtonState()
            applyPianoAccessoryState()
        }
    }
    private var settingsDebugState = SettingsDebugState() {
        didSet {
            guard isViewLoaded else {
                return
            }

            renderExercisePresentationState()
        }
    }
    private var baseStaffDisplayState = iOSViewController.initialStaffDisplayState

    private var isSettingsPresented = false
    private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
    private var singleCoverageSession: FretboardNaturalNoteTrainerState.SingleCoverageSession?
    private var singleCoverageLastEvaluation: FretboardNaturalNoteTrainerState.SingleCoverageEvaluation?
    private var singleCoverageWrongCells: Set<FretboardCell> = []
    private var positionPromptSession: FretboardNaturalNoteTrainerState.PositionPromptSession?
    private var positionPromptLastEvaluation: FretboardNaturalNoteTrainerState.PositionPromptEvaluation?
    private var positionPromptOverlayPhase: FretboardFeedbackOverlayState.PositionPromptPhase?
    private var pendingPositionPromptTransitionWorkItem: DispatchWorkItem?
    private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?
    private var quarterNoteSequenceLastEvaluation: FretboardNaturalNoteTrainerState.QuarterNoteSequenceEvaluation?
    private var hasLoggedInitialLayoutPass = false
    private var pianoPanelState = iOSViewController.initialPianoPanelState
    private var playbackCoordinator: PlaybackCoordinator?
    private var lastPianoAnswerNotesByPreviewID: [PianoPreviewID: NotePitch] = [:]
    var onRootModeChangeRequest: ((RootMode) -> Void)?

    private func logLifecycle(_ message: String) {
        print("[Startup][iOSVC] \(message) \(debugStateSnapshot())")
    }

    private func debugStateSnapshot() -> String {
        "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
        "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
        "composition=\(String(describing: exerciseLayoutPreferences.compositionPreset)) " +
        "layout=\(String(describing: exerciseLayoutPreferences.layoutPreset)) " +
        "accessory=\(String(describing: exerciseLayoutPreferences.accessoryPresentation)) " +
        "piano=\(exerciseLayoutPreferences.isPianoAccessoryVisible) " +
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

    private var currentFR0TargetPromptContent: TargetPromptContent {
        .single(
            text: fretboardTrainerState.targetPitchClass.displayText(
                using: displayState.spelling
            )
        )
    }

    private var currentFR0TargetPitchClassPool: Set<PitchClass> {
        Set(trainerDisplayState.positionQuestionConfiguration.sortedSelectedPitchClasses)
    }

    private var expectedSingleCoverageTargetPool: Set<PitchClass> {
        trainerDisplayState.isFR0Mode
            ? currentFR0TargetPitchClassPool
            : Set(PitchClass.naturalCasesInOrder)
    }

    private var currentPositionQuestionCandidateFilter: PositionPromptCandidateFilter {
        trainerDisplayState.positionQuestionCandidateFilter
    }

    private var currentPositionPromptCandidatePoolSignature: FretboardNaturalNoteTrainerState.PositionPromptSession.SchedulingState.CandidatePoolSignature {
        FretboardNaturalNoteTrainerState.positionPromptCandidatePoolSignature(
            in: displayState.configuration,
            filter: currentPositionQuestionCandidateFilter
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

            let wrongCells: Set<FretboardCell>
            if trainerDisplayState.isFR0Mode {
                wrongCells = singleCoverageWrongCells
            } else if let singleCoverageLastEvaluation,
                      singleCoverageLastEvaluation.hitKind == .wrong {
                wrongCells = [singleCoverageLastEvaluation.selectedCell]
            } else {
                wrongCells = []
            }

            return .singleCoverage(
                correctCells: singleCoverageSession.visitedCells,
                wrongCells: wrongCells,
                markerShape: trainerDisplayState.isFR0Mode
                    ? .circle
                    : .roundedRect
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
        let staffVisibleLastEvaluation = isShowingStaffSurface
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
        singleCoverageWrongCells.removeAll()
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
        updateAnswerSurfaceInteractionState()
    }

    private func resetSingleCoverageInteractionState() {
        singleCoverageSession = nil
        clearSingleCoverageFeedbackState()
    }

    private func resetQuarterNoteSequenceInteractionState() {
        quarterNoteSequenceSession = nil
        clearQuarterNoteSequenceFeedbackState()
        clearPianoAnswerPreviewCache()
    }

    private func singleCoverageSessionMatchesCurrentTrainer(
        _ session: FretboardNaturalNoteTrainerState.SingleCoverageSession
    ) -> Bool {
        fretboardTrainerState.singleCoverageTargetPool
            == expectedSingleCoverageTargetPool
            && session.targetPitchClass == fretboardTrainerState.targetPitchClass
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

        switch currentPositionQuestionCandidateFilter {
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
            filter: currentPositionQuestionCandidateFilter,
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
        guard isShowingStaffSurface else {
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

    private func handleQuarterNoteSequencePresentationTransition(
        from oldValue: ExercisePresentationState,
        to newValue: ExercisePresentationState
    ) {
        guard trainerDisplayState.usesQuarterNoteSequenceKernel,
              oldValue.isSurfaceVisible(.staff),
              !newValue.isSurfaceVisible(.staff),
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
        trainerDisplayState.resolvedSequenceConfiguration.quarterNoteSequenceSpec
    }

    private var isQuarterNoteSequenceMode: Bool {
        guard case .quarterNoteSequence = fretboardTrainerState.mode else {
            return false
        }

        return true
    }

    private var isShowingFretboard: Bool {
        exercisePresentationState.isSurfaceVisible(.fretboard)
    }

    private var isShowingStaffSurface: Bool {
        exercisePresentationState.isSurfaceVisible(.staff)
    }

    private var resolvedPianoSettingsSlice: PianoPanelSettingsSlice {
        trainerDisplayState.resolvedPianoSettingsSlice(
            from: pianoPanelState.settingsSlice
        )
    }

    private var canRoutePianoPreviewAnswers: Bool {
        let pianoSurfaceState = exercisePresentationState
            .effectiveSurfaceState(for: .piano)
        return trainerDisplayState.usesQuarterNoteSequenceKernel
            && pianoSurfaceState.isAnswerEnabled
            && pianoSurfaceState.isInteractionEnabled
    }

    private var settingsPanelStateContext: SettingsPanelStateContext {
        SettingsPanelStateContext(
            rootMode: .exercise,
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState,
            exerciseLayoutPreferences: exerciseLayoutPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: pianoPanelState,
            debugState: settingsDebugState
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

    private let scrollView = iOSInteractiveSurfaceScrollView()
    private let contentView = UIView()
    private var sceneViewportHeightConstraint: NSLayoutConstraint?

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

    private lazy var exerciseSceneRenderer = iOSExerciseSceneRenderer(
        safeAreaHeightAnchor: view.safeAreaLayoutGuide.heightAnchor,
        metrics: .init(
            surfaceSpacing: Layout.verticalSpacing,
            floatingButtonInset: Layout.topContentFloatingButtonInset,
            floatingButtonSize: Layout.sequenceRegenerateButtonSize,
            contentSizeTolerance: Layout.contentSizeTolerance
        ),
        sequenceRegenerateButton: sequenceRegenerateButton,
        staffView: staffView,
        targetNotePromptView: targetNotePromptView,
        naturalNoteStripView: naturalNoteStripView,
        pianoSurfaceView: pianoSurfaceView,
        fretboardView: fretboardView
    )

    private lazy var pianoSurfaceView: iOSPianoSurfaceView = {
        let pianoSurfaceView = iOSPianoSurfaceView(
            chromeStyle: .card,
            panelState: pianoPanelState
        )
        pianoSurfaceView.onPreviewStarted = { [weak self] preview in
            self?.handlePianoSemanticEvent(.previewStarted(preview))
        }
        pianoSurfaceView.onPreviewChanged = { [weak self] preview in
            self?.handlePianoSemanticEvent(.previewChanged(preview))
        }
        pianoSurfaceView.onPreviewEnded = { [weak self] preview in
            self?.handlePianoSemanticEvent(.previewEnded(preview))
        }
        return pianoSurfaceView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        logLifecycle("viewDidLoad begin")
        view.backgroundColor = .systemBackground
        configureLayout()
        applyDisplayState()
        applyPianoAccessoryState()
        logLifecycle("viewDidLoad end")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        exerciseSceneRenderer.handleLayoutPass()
        if !hasLoggedInitialLayoutPass {
            hasLoggedInitialLayoutPass = true
            logLifecycle("first layout pass bounds=\(view.bounds)")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        interruptActivePianoPlayback(reason: .viewWillDisappear)
    }

    var currentPianoSettingsSlice: PianoPanelSettingsSlice {
        pianoPanelState.settingsSlice
    }

    func setPlaybackCoordinator(_ playbackCoordinator: PlaybackCoordinator?) {
        self.playbackCoordinator = playbackCoordinator
    }

    func applySharedPianoSettings(_ settingsSlice: PianoPanelSettingsSlice) {
        let nextPianoPanelState = pianoPanelState.applyingSettingsSlice(
            settingsSlice
        )
        guard nextPianoPanelState != pianoPanelState else {
            return
        }

        if isViewLoaded {
            interruptActivePianoPlayback(reason: .sharedSettingsChanged)
        }
        pianoPanelState = nextPianoPanelState
        if isViewLoaded {
            applyPianoAccessoryState()
            applySettingsPanelState()
            synchronizeExerciseCompositionState(
                reason: "sharedPianoSettingsChanged"
            )
        }
    }

    func interruptActivePianoPlayback(reason: PlaybackStopReason) {
        guard isViewLoaded else {
            clearPianoAnswerPreviewCache()
            playbackCoordinator?.forceStop(reason: reason)
            return
        }

        clearPianoAnswerPreviewCache()
        pianoSurfaceView.interruptActiveInteraction()
        playbackCoordinator?.forceStop(reason: reason)
    }

    private func configureLayout() {
        logLifecycle("configureLayout begin")
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        labelVisibilityButton.translatesAutoresizingMaskIntoConstraints = false
        settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        // 点击直接透传给交互 surface；一旦用户开始纵向拖动，共用 scroll host 会取消当前触摸序列并接管滚动。
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(exerciseSceneRenderer.sceneContainerView)
        view.addSubview(settingsButton)
        view.addSubview(labelVisibilityButton)
        view.addSubview(settingsContainerView)

        let safeArea = view.safeAreaLayoutGuide
        sceneViewportHeightConstraint = exerciseSceneRenderer.sceneContainerView
            .heightAnchor.constraint(
                equalTo: safeArea.heightAnchor,
                constant: -(Layout.contentTopInset + Layout.bottomInset)
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
            exerciseSceneRenderer.sceneContainerView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.contentTopInset
            ),
            exerciseSceneRenderer.sceneContainerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            exerciseSceneRenderer.sceneContainerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            exerciseSceneRenderer.sceneContainerView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            ),
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

        applySettingsPresentationState()
        updateSceneViewportHeightConstraint()
        logLifecycle("configureLayout end")
    }

    private func renderExercisePresentationState() {
        logLifecycle("renderExercisePresentationState begin")
        updateSceneViewportHeightConstraint()
        exerciseSceneRenderer.render(
            presentationState: exercisePresentationState,
            fretboardDisplayState: displayState,
            debugState: settingsDebugState
        )
        applySettingsPanelState()
        updateLayoutIfNeeded()
        exerciseSceneRenderer.handleLayoutPass()
        updateLayoutIfNeeded()
        logLifecycle("renderExercisePresentationState end")
    }

    private func updateSceneViewportHeightConstraint() {
        sceneViewportHeightConstraint?.isActive = exercisePresentationState
            .fretboardLayoutContract
            .pinsSceneToViewportHeight
    }

    private func applyDisplayState() {
        logLifecycle("applyDisplayState begin")
        applyFretboardDisplayState()
        applyStaffDisplayState()
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
        applySettingsPanelState()
        applyLabelVisibilityButtonState()
        renderExercisePresentationState()

        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            if trainerDisplayState.isFR0Mode {
                applyFR0Projection(
                    reason: "fretboardDisplayChanged",
                    showsLog: false
                )
            } else {
                applySingleCoverageProjection(
                    reason: "fretboardDisplayChanged",
                    showsLog: false
                )
            }
        case .positionPrompt:
            applyPositionPromptProjection(
                reason: "fretboardDisplayChanged",
                showsLog: false
            )
        case .quarterNoteSequence:
            applyCurrentFretboardFeedbackOverlayState()
            updateAnswerSurfaceInteractionState()
        }

        guard isShowingFretboard else {
            logLifecycle("applyFretboardDisplayState end without visible fretboard")
            return
        }

        updateLayoutIfNeeded()
        exerciseSceneRenderer.handleLayoutPass()
        updateLayoutIfNeeded()
        logLifecycle("applyFretboardDisplayState end")
    }

    private func applyStaffDisplayState() {
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        staffView.showsComponentBoundsOverlay = staffDisplayState.showsComponentBoundsOverlay
        applySettingsPanelState()
        updateLayoutIfNeeded()
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

    private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
        guard hitResult.phase == .ended else {
            return
        }

        guard let selectedCell = hitResult.cell else {
            logIgnoredFretboardAnswerHitResultMissingCell()
            return
        }

        handleExerciseAnswerEvent(
            .fretboardCell(selectedCell, from: .fretboard)
        )
    }

    private func handleNaturalNoteStripPitchClassTap(_ pitchClass: PitchClass) {
        handleExerciseAnswerEvent(
            .pitchClass(pitchClass, from: .naturalNoteStrip)
        )
    }

    private func handleExerciseAnswerEvent(_ event: ExerciseAnswerEvent) {
        switch ExerciseAnswerRouter.route(
            event,
            presentationState: exercisePresentationState,
            trainerDisplayState: trainerDisplayState,
            fretboardConfiguration: displayState.configuration
        ) {
        case let .routed(route):
            handleRoutedExerciseAnswer(route)
        case let .ignored(reason):
            logIgnoredExerciseAnswerEvent(event, reason: reason)
        }
    }

    private func handleRoutedExerciseAnswer(_ route: ExerciseAnswerRoute) {
        switch route {
        case let .singleCoverage(_, cell):
            handleSingleCoverageAnswer(cell)
        case let .quarterNoteSequence(event, answer):
            handleQuarterNoteSequenceAnswer(
                event,
                answer: answer
            )
        case let .positionPrompt(answer):
            handlePositionPromptAnswer(answer)
        }
    }

    private func logIgnoredExerciseAnswerEvent(
        _ event: ExerciseAnswerEvent,
        reason: ExerciseAnswerRouteIgnoreReason
    ) {
        guard shouldLogIgnoredExerciseAnswer(reason) else {
            return
        }

        print(
            "[ExerciseAnswerRouter][iOS] result=ignored surface=\(event.surfaceID.rawValue) reason=\(reason.debugDescription)"
        )
    }

    private func shouldLogIgnoredExerciseAnswer(
        _ reason: ExerciseAnswerRouteIgnoreReason
    ) -> Bool {
        switch reason {
        case .surfaceUnavailable, .surfaceHidden, .answerDisabled,
             .interactionDisabled:
            return false
        case .unsupportedPayload, .unresolvedPitchClass:
            return true
        }
    }

    private func logIgnoredFretboardAnswerHitResultMissingCell() {
        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            let modeName = trainerDisplayState.isFR0Mode ? "FR-0" : "SingleCoverage"
            print(
                "[\(modeName)][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
            )
        case .positionPrompt:
            print("[PositionPrompt][iOS] result=ignored reason=missingHitCell")
        case .quarterNoteSequence:
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=missingHitCell"
            )
        }
    }

    private func handlePositionPromptAnswer(
        _ routedAnswer: ExercisePositionPromptRoutedAnswer
    ) {
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

        guard let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
            routedAnswer.event,
            configuration: displayState.configuration,
            answerRule: trainerDisplayState.positionPromptAnswerRule,
            filter: currentPositionQuestionCandidateFilter,
            session: &positionPromptSession
        ) else {
            print(
                "[PositionPrompt][iOS] result=ignored reason=unresolvedAnswerEvent surface=\(routedAnswer.event.surfaceID.rawValue)"
            )
            return
        }
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

    private func handleSingleCoverageAnswer(_ selectedCell: FretboardCell) {
        ensureSingleCoverageSession()
        guard var singleCoverageSession else {
            print("[SingleCoverage][iOS] result=ignored reason=missingSession")
            return
        }

        let answerResult = fretboardTrainerState.handleSingleCoverageAnswer(
            selectedCell,
            configuration: displayState.configuration,
            session: &singleCoverageSession
        )

        switch answerResult {
        case let .ignored(.unresolvedHitPitch(cell)):
            print(
                "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
            )
        case .ignored(.completedSession):
            print(
                "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=completedSession"
            )
        case .ignored(.nonEndedPhase), .ignored(.missingHitCell):
            return
        case let .evaluated(evaluation):
            self.singleCoverageSession = singleCoverageSession
            updateSingleCoverageFeedbackState(with: answerResult)
            if trainerDisplayState.isFR0Mode,
               evaluation.hitKind == .wrong {
                singleCoverageWrongCells.insert(evaluation.selectedCell)
            }
            if evaluation.didAdvanceTarget {
                self.singleCoverageSession = fretboardTrainerState.makeSingleCoverageSession(
                    configuration: displayState.configuration
                )
                clearSingleCoverageFeedbackState()
            }
            if trainerDisplayState.isFR0Mode {
                applyFR0Projection(
                    reason: evaluation.didAdvanceTarget ? "advanced" : "answered",
                    showsLog: false
                )
            } else {
                applySingleCoverageProjection(
                    reason: evaluation.didAdvanceTarget ? "advanced" : "answered",
                    showsLog: false
                )
            }
            print("[iOS] \(evaluation.debugSummary())")
        }
    }

    private func handleQuarterNoteSequenceAnswer(
        _ event: ExerciseAnswerEvent,
        answer: ResolvedSequenceAnswer
    ) {
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
            answer,
            session: &quarterNoteSequenceSession
        )
        self.quarterNoteSequenceSession = quarterNoteSequenceSession
        updateQuarterNoteSequenceFeedbackState(with: answerResult)
        applyQuarterNoteSequenceProjection(
            generatedSequence,
            reason: "answered",
            showsLog: false
        )

        let selectedCell = event.payload.fretboardCell
        let selectedPitch = answer.notePitch ?? selectedCell.flatMap {
            displayState.configuration.notePitch(for: $0)
        }

        switch answerResult {
        case .ignored(.completedSession):
            if let selectedCell {
                print(
                    "[QuarterNoteSequence][iOS] result=ignored reason=completedSession string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
                )
            } else if let selectedPitch {
                print(
                    "[QuarterNoteSequence][iOS] result=ignored reason=completedSession answered=\(selectedPitch.displayText())"
                )
            } else {
                print(
                    "[QuarterNoteSequence][iOS] result=ignored reason=completedSession answered=\(answer.pitchClass.displayText())"
                )
            }
        case let .evaluated(evaluation):
            if let selectedCell,
               let selectedPitch {
                print(
                    "[iOS] \(evaluation.debugSummary()) selected=\(selectedPitch.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
                )
            } else if let selectedPitch {
                print(
                    "[iOS] \(evaluation.debugSummary()) answered=\(selectedPitch.displayText())"
                )
            } else {
                print(
                    "[iOS] \(evaluation.debugSummary()) answered=\(answer.pitchClass.displayText())"
                )
            }
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
        if trainerDisplayState.usesQuarterNoteSequenceKernel {
            synchronizeQuarterNoteSequencePresentation(reason: reason)
        } else if trainerDisplayState.isFR0Mode {
            synchronizeFR0Presentation(reason: reason)
        } else if trainerDisplayState.isPositionPromptMode {
            synchronizePositionPromptPresentation(reason: reason)
        } else {
            synchronizeSingleTrainerPresentation(reason: reason)
        }
    }

    private func synchronizeSingleTrainerPresentation(reason: String) {
        if case .positionPrompt = fretboardTrainerState.mode {
            resetPositionPromptInteractionState()
        }

        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            if fretboardTrainerState.singleCoverageTargetPool
                != expectedSingleCoverageTargetPool {
                resetSingleCoverageInteractionState()
                fretboardTrainerState = FretboardNaturalNoteTrainerState()
            }
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

    private func synchronizeFR0Presentation(reason: String) {
        resetPositionPromptInteractionState()
        resetQuarterNoteSequenceInteractionState()

        if staffDisplayState != baseStaffDisplayState {
            staffDisplayState = baseStaffDisplayState
        }

        if reason == "positionQuestionCandidatesChanged" {
            resetSingleCoverageInteractionState()
        }

        switch fretboardTrainerState.mode {
        case .singleNaturalTarget:
            if fretboardTrainerState.singleCoverageTargetPool
                != expectedSingleCoverageTargetPool {
                resetSingleCoverageInteractionState()
                fretboardTrainerState = FretboardNaturalNoteTrainerState(
                    singleCoverageTargetPool: currentFR0TargetPitchClassPool
                )
            }
        case .positionPrompt, .quarterNoteSequence:
            resetSingleCoverageInteractionState()
            fretboardTrainerState = FretboardNaturalNoteTrainerState(
                singleCoverageTargetPool: currentFR0TargetPitchClassPool
            )
        }

        synchronizeExerciseCompositionState(reason: reason)
        applyFR0Projection(
            reason: reason,
            showsLog: true
        )
    }

    private func synchronizePositionPromptPresentation(reason: String) {
        resetSingleCoverageInteractionState()
        resetQuarterNoteSequenceInteractionState()

        if staffDisplayState != baseStaffDisplayState {
            staffDisplayState = baseStaffDisplayState
        }

        if reason == "positionPromptFilterChanged"
            || reason == "positionQuestionCandidatesChanged" {
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
        updateAnswerSurfaceInteractionState()
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

    private func updateAnswerSurfaceInteractionState() {
        guard isViewLoaded else {
            return
        }

        let allowsLiveAnswerInteraction = !trainerDisplayState.isPositionPromptMode
            || currentPositionPromptOverlayPhase == .neutralWhite
        let fretboardInteractionEnabled = exercisePresentationState
            .effectiveSurfaceState(for: .fretboard)
            .isInteractionEnabled
        let naturalNoteStripInteractionEnabled = exercisePresentationState
            .effectiveSurfaceState(for: .naturalNoteStrip)
            .isInteractionEnabled
        let pianoInteractionEnabled = exercisePresentationState
            .effectiveSurfaceState(for: .piano)
            .isInteractionEnabled

        fretboardView.isUserInteractionEnabled = fretboardInteractionEnabled
            && allowsLiveAnswerInteraction
        naturalNoteStripView.isUserInteractionEnabled = naturalNoteStripInteractionEnabled
            && allowsLiveAnswerInteraction
        if pianoSurfaceView.isPianoInteractionEnabled && !pianoInteractionEnabled {
            interruptActivePianoPlayback(reason: .interactionDisabled)
        }
        pianoSurfaceView.isPianoInteractionEnabled = pianoInteractionEnabled
    }

    private func applySingleCoverageProjection(
        reason: String,
        showsLog: Bool = true
    ) {
        ensureSingleCoverageSession()
        targetNotePromptView.apply(content: currentSingleCoverageTargetPromptContent)
        applyCurrentFretboardFeedbackOverlayState()
        updateAnswerSurfaceInteractionState()

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

    private func applyFR0Projection(
        reason: String,
        showsLog: Bool = true
    ) {
        ensureSingleCoverageSession()
        targetNotePromptView.apply(content: currentFR0TargetPromptContent)
        applyCurrentFretboardFeedbackOverlayState()
        updateAnswerSurfaceInteractionState()

        guard showsLog else {
            return
        }

        print(
            "[FR-0][iOS] target=\(currentFretboardTrainerPrompt.displayText) state=\(reason)"
        )
    }

    private func applyPositionPromptProjection(
        reason: String,
        showsLog: Bool = true
    ) {
        ensurePositionPromptSession()
        applyCurrentFretboardFeedbackOverlayState()
        updateAnswerSurfaceInteractionState()

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
        sequenceRegenerateButton.isHidden = !trainerDisplayState
            .usesQuarterNoteSequenceKernel
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
        guard trainerDisplayState.usesQuarterNoteSequenceKernel else {
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

    private func applyPianoAccessoryState() {
        pianoSurfaceView.applySharedSettings(
            resolvedPianoSettingsSlice
        )
        pianoSurfaceView.showsComponentBoundsOverlay = false
        updateLayoutIfNeeded()
        exerciseSceneRenderer.handleLayoutPass()
    }

    private func handlePianoSemanticEvent(_ event: PianoSemanticEvent) {
        playbackCoordinator?.handle(event)
        switch event {
        case .rowsChanged:
            return
        case let .previewStarted(preview):
            routePianoPreviewAnswerIfNeeded(
                preview,
                shouldEmitDuplicateNote: true
            )
        case let .previewChanged(preview):
            routePianoPreviewAnswerIfNeeded(
                preview,
                shouldEmitDuplicateNote: false
            )
        case let .previewEnded(preview):
            lastPianoAnswerNotesByPreviewID.removeValue(forKey: preview.previewID)
        }
    }

    private func routePianoPreviewAnswerIfNeeded(
        _ preview: PianoPreviewState,
        shouldEmitDuplicateNote: Bool
    ) {
        guard canRoutePianoPreviewAnswers else {
            return
        }

        let previousNote = lastPianoAnswerNotesByPreviewID[preview.previewID]
        if !shouldEmitDuplicateNote, previousNote == preview.note {
            return
        }

        lastPianoAnswerNotesByPreviewID[preview.previewID] = preview.note
        handleExerciseAnswerEvent(
            .notePitch(preview.note, from: .piano)
        )
    }

    private func clearPianoAnswerPreviewCache() {
        lastPianoAnswerNotesByPreviewID.removeAll()
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

        if nextStateContext.rootMode != .exercise {
            setSettingsPresented(false)
            interruptActivePianoPlayback(reason: .rootModeChanged)
            onRootModeChangeRequest?(nextStateContext.rootMode)
            return
        }

        let nextRequestedStaffDisplayState = nextStateContext.staffDisplayState

        let nextDisplayState = nextStateContext.fretboardDisplayState
        let nextStaffDisplayState = nextStateContext.staffDisplayState
        let nextExerciseLayoutPreferences = nextStateContext
            .exerciseLayoutPreferences
        let nextTrainerDisplayState = nextStateContext.trainerDisplayState
        let nextPianoPanelState = nextStateContext.pianoPanelState
        let nextSettingsDebugState = nextStateContext.debugState

        let didChangeFretboard = nextDisplayState != displayState
        let didChangeStaff = nextStaffDisplayState != staffDisplayState
        let didChangeExerciseLayoutPreferences =
            nextExerciseLayoutPreferences != exerciseLayoutPreferences
        let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState
        let didChangePianoPanel = nextPianoPanelState != pianoPanelState
        let didChangeSettingsDebug = nextSettingsDebugState != settingsDebugState
        let didChangeExerciseMode = nextTrainerDisplayState.exerciseMode != trainerDisplayState.exerciseMode
        let didChangePositionQuestionCandidates =
            nextTrainerDisplayState.positionQuestionCandidateFilter
            != trainerDisplayState.positionQuestionCandidateFilter

        guard didChangeFretboard
            || didChangeStaff
            || didChangeExerciseLayoutPreferences
            || didChangeTrainer
            || didChangePianoPanel
            || didChangeSettingsDebug else {
            return
        }

        if nextTrainerDisplayState.usesQuarterNoteSequenceKernel,
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
            interruptActivePianoPlayback(reason: .panelStateChanged)
            pianoPanelState = nextPianoPanelState
            applyPianoAccessoryState()
            applySettingsPanelState()
        }

        if didChangeSettingsDebug {
            settingsDebugState = nextSettingsDebugState
        }

        if didChangeTrainer {
            let trainerSyncReason: String
            if didChangeExerciseMode {
                trainerSyncReason = "exerciseModeChanged"
            } else if didChangePositionQuestionCandidates {
                trainerSyncReason = "positionQuestionCandidatesChanged"
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

#if DEBUG
extension iOSViewController {
    func runSR1PianoAnswerSmokeTest(
        in window: UIWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        runSRPianoAnswerSmokeTest(
            in: window,
            scenarioName: "sr1_piano_answer",
            switchStepName: "switch_to_sr1",
            switchAction: .setExerciseModeSr1,
            expectedMode: .sr1,
            expectedAnswerPolicy: .pitchClass,
            expectedPianoRowCount: 1,
            wrongStepName: "wrong_piano_preview",
            makeWrongPreview: { expectedNote in
                PianoPreviewState(
                    rowIndex: 0,
                    note: expectedNote.advanced(by: 1)
                )
            },
            validateWrongPreviewSelection: { expectedNote, preview in
                guard preview.note.pitchClass != expectedNote.pitchClass else {
                    return "reason=wrong_preview_not_outside_pitch_class answered=\(preview.note.displayText()) expected=\(expectedNote.displayText())"
                }
                return nil
            },
            correctStepName: "correct_piano_preview",
            makeCorrectPreview: { expectedNote in
                PianoPreviewState(
                    rowIndex: 0,
                    note: NotePitch(
                        pitchClass: expectedNote.pitchClass,
                        octave: expectedNote.octave + 1
                    )
                )
            },
            validateCorrectPreviewSelection: { expectedNote, preview in
                guard preview.note.pitchClass == expectedNote.pitchClass,
                      preview.note != expectedNote else {
                    return "reason=correct_preview_not_pitch_class_only answered=\(preview.note.displayText()) expected=\(expectedNote.displayText())"
                }
                return nil
            },
            completion: completion
        )
    }

    func runSR2PianoAnswerSmokeTest(
        in window: UIWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        runSRPianoAnswerSmokeTest(
            in: window,
            scenarioName: "sr2_piano_answer",
            switchStepName: "switch_to_sr2",
            switchAction: .setExerciseModeSr2,
            expectedMode: .sr2,
            expectedAnswerPolicy: .exactNote,
            expectedPianoRowCount: 2,
            wrongStepName: "wrong_exact_note",
            makeWrongPreview: { expectedNote in
                PianoPreviewState(
                    rowIndex: 1,
                    note: expectedNote.advanced(by: 12)
                )
            },
            validateWrongPreviewSelection: { expectedNote, preview in
                guard preview.note.pitchClass == expectedNote.pitchClass,
                      preview.note != expectedNote else {
                    return "reason=wrong_preview_not_same_class_different_octave answered=\(preview.note.displayText()) expected=\(expectedNote.displayText())"
                }
                return nil
            },
            correctStepName: "correct_exact_note",
            makeCorrectPreview: { expectedNote in
                PianoPreviewState(
                    rowIndex: 1,
                    note: expectedNote
                )
            },
            validateCorrectPreviewSelection: { expectedNote, preview in
                guard preview.note == expectedNote else {
                    return "reason=correct_preview_not_exact_note answered=\(preview.note.displayText()) expected=\(expectedNote.displayText())"
                }
                return nil
            },
            completion: completion
        )
    }

    private func runSRPianoAnswerSmokeTest(
        in window: UIWindow,
        scenarioName: String,
        switchStepName: String,
        switchAction: SettingsActionID,
        expectedMode: TrainerExerciseMode,
        expectedAnswerPolicy: TrainerSequenceAnswerPolicy,
        expectedPianoRowCount: Int,
        wrongStepName: String,
        makeWrongPreview: @escaping (NotePitch) -> PianoPreviewState,
        validateWrongPreviewSelection: @escaping (NotePitch, PianoPreviewState) -> String?,
        correctStepName: String,
        makeCorrectPreview: @escaping (NotePitch) -> PianoPreviewState,
        validateCorrectPreviewSelection: @escaping (NotePitch, PianoPreviewState) -> String?,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            action: () -> Void,
            validate: () -> String?
        )
        var wrongPreview: PianoPreviewState?
        var wrongExpectedNote: NotePitch?
        var correctPreview: PianoPreviewState?
        var correctExpectedNote: NotePitch?

        func currentExpectedNotePitch() -> NotePitch? {
            if let currentItem = quarterNoteSequenceSession?.currentItem {
                return currentItem.expectedNotePitch
            }
            return currentGeneratedQuarterNoteSequence?.items.first?.expectedNotePitch
        }

        func settleLayout() {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        let steps: [SmokeStep] = [
            (
                name: switchStepName,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(switchAction)
                    )
                },
                validate: {
                    guard self.trainerDisplayState.exerciseMode == expectedMode else {
                        return "reason=mode_not_expected resolvedMode=\(String(describing: self.trainerDisplayState.exerciseMode)) expectedMode=\(String(describing: expectedMode))"
                    }
                    guard self.exerciseLayoutPreferences == .srPianoAnswer else {
                        return "reason=layout_not_fixed resolvedLayout=\(String(describing: self.exerciseLayoutPreferences))"
                    }
                    guard !self.exerciseLayoutPreferences.isPianoAccessoryVisible else {
                        return "reason=piano_accessory_enabled"
                    }
                    guard self.trainerDisplayState.usesQuarterNoteSequenceKernel else {
                        return "reason=sequence_kernel_disabled"
                    }
                    let resolvedSequenceConfiguration = self.trainerDisplayState
                        .resolvedSequenceConfiguration
                    guard resolvedSequenceConfiguration.clef == .treble else {
                        return "reason=clef_not_treble resolvedClef=\(String(describing: resolvedSequenceConfiguration.clef))"
                    }
                    guard resolvedSequenceConfiguration.answerPolicy == expectedAnswerPolicy else {
                        return "reason=answer_policy_not_fixed resolvedPolicy=\(String(describing: resolvedSequenceConfiguration.answerPolicy)) expectedPolicy=\(String(describing: expectedAnswerPolicy))"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .staff) == .promptOnly else {
                        return "reason=staff_not_prompt_only"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .piano) == .answerOnly else {
                        return "reason=piano_not_answer_only"
                    }
                    guard self.exercisePresentationState.containsSurface(.piano),
                          self.exercisePresentationState.isSurfaceVisible(.staff),
                          self.exercisePresentationState.isSurfaceVisible(.piano) else {
                        return "reason=sr_piano_surfaces_not_visible"
                    }
                    guard !self.exercisePresentationState.containsSurface(.fretboard),
                          self.exercisePresentationState.projectedSurfaceState(for: .fretboard) == nil else {
                        return "reason=fretboard_surface_present"
                    }
                    guard !self.exercisePresentationState.containsSurface(.naturalNoteStrip),
                          self.exercisePresentationState.projectedSurfaceState(for: .naturalNoteStrip) == nil else {
                        return "reason=strip_surface_present"
                    }
                    guard self.resolvedPianoSettingsSlice.rowCount == expectedPianoRowCount,
                          self.resolvedPianoSettingsSlice.movementScope == .rowOnly else {
                        return "reason=piano_settings_not_fixed rowCount=\(self.resolvedPianoSettingsSlice.rowCount) movement=\(self.resolvedPianoSettingsSlice.movementScope.debugName)"
                    }
                    guard self.pianoSurfaceView.currentSettingsSlice.rowCount == expectedPianoRowCount,
                          self.pianoSurfaceView.currentSettingsSlice.movementScope == .rowOnly else {
                        return "reason=piano_view_settings_not_applied rowCount=\(self.pianoSurfaceView.currentSettingsSlice.rowCount) movement=\(self.pianoSurfaceView.currentSettingsSlice.movementScope.debugName)"
                    }
                    guard self.pianoSurfaceView.isPianoInteractionEnabled else {
                        return "reason=piano_interaction_disabled"
                    }
                    guard self.currentGeneratedQuarterNoteSequence != nil else {
                        return "reason=missing_sequence"
                    }
                    guard self.staffDisplayState.sequencePresentation?.state == .idle else {
                        return "reason=staff_not_idle presentation=\(String(describing: self.staffDisplayState.sequencePresentation))"
                    }
                    guard !self.sequenceRegenerateButton.isHidden else {
                        return "reason=regenerate_hidden"
                    }
                    return nil
                }
            ),
            (
                name: wrongStepName,
                action: {
                    guard let expectedNote = currentExpectedNotePitch() else {
                        wrongExpectedNote = nil
                        wrongPreview = nil
                        return
                    }
                    wrongExpectedNote = expectedNote
                    let preview = makeWrongPreview(expectedNote)
                    wrongPreview = preview
                    self.handlePianoSemanticEvent(.previewStarted(preview))
                },
                validate: {
                    guard let wrongExpectedNote else {
                        return "reason=missing_wrong_expected_note"
                    }
                    guard let wrongPreview else {
                        return "reason=missing_wrong_preview"
                    }
                    if let selectionFailure = validateWrongPreviewSelection(
                        wrongExpectedNote,
                        wrongPreview
                    ) {
                        return selectionFailure
                    }
                    guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                        return "reason=missing_wrong_evaluation"
                    }
                    guard evaluation.comparisonPolicy == expectedAnswerPolicy else {
                        return "reason=wrong_policy resolvedPolicy=\(String(describing: evaluation.comparisonPolicy)) expectedPolicy=\(String(describing: expectedAnswerPolicy))"
                    }
                    guard !evaluation.isCorrect else {
                        return "reason=wrong_preview_marked_correct"
                    }
                    guard evaluation.expectedNotePitch == wrongExpectedNote else {
                        return "reason=wrong_expected_note_shifted answered=\(evaluation.expectedNotePitch.displayText()) expected=\(wrongExpectedNote.displayText())"
                    }
                    guard evaluation.answeredPitchClass == wrongPreview.note.pitchClass else {
                        return "reason=wrong_pitch_class_lost answered=\(evaluation.answeredPitchClass.displayText()) expected=\(wrongPreview.note.pitchClass.displayText())"
                    }
                    guard evaluation.answeredNotePitch == wrongPreview.note else {
                        return "reason=wrong_pitch_lost answered=\(String(describing: evaluation.answeredNotePitch)) expected=\(wrongPreview.note.displayText())"
                    }
                    guard self.quarterNoteSequenceSession?.currentIndex == 0 else {
                        return "reason=wrong_preview_advanced currentIndex=\(self.quarterNoteSequenceSession?.currentIndex ?? -1)"
                    }
                    guard self.staffDisplayState.sequencePresentation?.state == .wrong,
                          self.staffDisplayState.sequencePresentation?.lastEvaluationResult == .incorrect else {
                        return "reason=staff_missing_wrong_feedback presentation=\(String(describing: self.staffDisplayState.sequencePresentation))"
                    }
                    guard self.lastPianoAnswerNotesByPreviewID[wrongPreview.previewID] == wrongPreview.note else {
                        return "reason=wrong_preview_not_cached"
                    }
                    return nil
                }
            ),
            (
                name: correctStepName,
                action: {
                    if let wrongPreview {
                        self.handlePianoSemanticEvent(.previewEnded(wrongPreview))
                    }
                    guard let expectedNote = currentExpectedNotePitch() else {
                        correctExpectedNote = nil
                        correctPreview = nil
                        return
                    }
                    correctExpectedNote = expectedNote
                    let preview = makeCorrectPreview(expectedNote)
                    correctPreview = preview
                    self.handlePianoSemanticEvent(.previewStarted(preview))
                },
                validate: {
                    guard let correctExpectedNote else {
                        return "reason=missing_correct_expected_note"
                    }
                    guard let correctPreview else {
                        return "reason=missing_correct_preview"
                    }
                    if let selectionFailure = validateCorrectPreviewSelection(
                        correctExpectedNote,
                        correctPreview
                    ) {
                        return selectionFailure
                    }
                    guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                        return "reason=missing_correct_evaluation"
                    }
                    guard evaluation.comparisonPolicy == expectedAnswerPolicy else {
                        return "reason=correct_policy_mismatch resolvedPolicy=\(String(describing: evaluation.comparisonPolicy)) expectedPolicy=\(String(describing: expectedAnswerPolicy))"
                    }
                    guard evaluation.isCorrect else {
                        return "reason=correct_preview_marked_wrong"
                    }
                    guard evaluation.expectedNotePitch == correctExpectedNote else {
                        return "reason=correct_expected_note_shifted answered=\(evaluation.expectedNotePitch.displayText()) expected=\(correctExpectedNote.displayText())"
                    }
                    guard evaluation.answeredPitchClass == correctPreview.note.pitchClass else {
                        return "reason=correct_pitch_class_lost answered=\(evaluation.answeredPitchClass.displayText()) expected=\(correctPreview.note.pitchClass.displayText())"
                    }
                    guard evaluation.answeredNotePitch == correctPreview.note else {
                        return "reason=correct_pitch_lost answered=\(String(describing: evaluation.answeredNotePitch)) expected=\(correctPreview.note.displayText())"
                    }
                    guard self.quarterNoteSequenceSession?.currentIndex == 1 else {
                        return "reason=correct_preview_did_not_advance currentIndex=\(self.quarterNoteSequenceSession?.currentIndex ?? -1)"
                    }
                    guard self.staffDisplayState.sequencePresentation?.state == .correct,
                          self.staffDisplayState.sequencePresentation?.lastEvaluationResult == .correct else {
                        return "reason=staff_missing_correct_feedback presentation=\(String(describing: self.staffDisplayState.sequencePresentation))"
                    }
                    guard self.lastPianoAnswerNotesByPreviewID[correctPreview.previewID] == correctPreview.note else {
                        return "reason=correct_preview_not_cached"
                    }
                    return nil
                }
            ),
            (
                name: "switch_back_to_single",
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setExerciseModeSingle)
                    )
                },
                validate: {
                    guard self.trainerDisplayState.exerciseMode == .single else {
                        return "reason=mode_not_single resolvedMode=\(String(describing: self.trainerDisplayState.exerciseMode))"
                    }
                    guard self.quarterNoteSequenceSession == nil,
                          self.quarterNoteSequenceLastEvaluation == nil else {
                        return "reason=sequence_state_not_cleared sessionIndex=\(self.quarterNoteSequenceSession?.currentIndex ?? -1) lastEvaluation=\(String(describing: self.quarterNoteSequenceLastEvaluation))"
                    }
                    guard self.staffDisplayState.sequencePresentation == nil else {
                        return "reason=staff_sequence_feedback_leaked presentation=\(String(describing: self.staffDisplayState.sequencePresentation))"
                    }
                    guard self.lastPianoAnswerNotesByPreviewID.isEmpty else {
                        return "reason=piano_preview_cache_not_cleared cacheCount=\(self.lastPianoAnswerNotesByPreviewID.count)"
                    }
                    guard !self.exercisePresentationState.containsSurface(.piano),
                          !self.pianoSurfaceView.isPianoInteractionEnabled else {
                        return "reason=piano_surface_still_active"
                    }
                    guard self.sequenceRegenerateButton.isHidden else {
                        return "reason=regenerate_still_visible"
                    }
                    return nil
                }
            )
        ]

        print(
            "[RuntimeSmoke][iOS] begin scenario=\(scenarioName) initialMode=\(String(describing: trainerDisplayState.exerciseMode))"
        )
        runExerciseAnswerSmokeSteps(
            steps,
            index: 0,
            scenarioName: scenarioName,
            settleLayout: settleLayout,
            successSummary: {
                "[RuntimeSmoke][iOS] PASS scenario=\(scenarioName) finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) pianoVisible=\(self.exercisePresentationState.isSurfaceVisible(.piano))"
            },
            completion: completion
        )
    }

    func runSR0NoteStripAnswerSmokeTest(
        in window: UIWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            action: () -> Void,
            validate: () -> String?
        )
        var wrongPitchClass: PitchClass?
        var correctPitchClass: PitchClass?

        func currentExpectedPitchClass() -> PitchClass? {
            if let currentItem = quarterNoteSequenceSession?.currentItem {
                return currentItem.answerPitchClass
            }
            return currentGeneratedQuarterNoteSequence?.items.first?.answerPitchClass
        }

        func nextDifferentPitchClass(from pitchClass: PitchClass) -> PitchClass {
            let nextRawValue = (pitchClass.rawValue + 1) % PitchClass.allCases.count
            return PitchClass(rawValue: nextRawValue)!
        }

        func settleLayout() {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        let steps: [SmokeStep] = [
            (
                name: "switch_to_sr0",
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setExerciseModeSr0)
                    )
                },
                validate: {
                    guard self.trainerDisplayState.exerciseMode == .sr0 else {
                        return "reason=mode_not_sr0 resolvedMode=\(String(describing: self.trainerDisplayState.exerciseMode))"
                    }
                    guard self.exerciseLayoutPreferences == .srNoteStripAnswer else {
                        return "reason=layout_not_fixed resolvedLayout=\(String(describing: self.exerciseLayoutPreferences))"
                    }
                    guard self.trainerDisplayState.usesQuarterNoteSequenceKernel else {
                        return "reason=sequence_kernel_disabled"
                    }
                    let resolvedSequenceConfiguration = self.trainerDisplayState
                        .resolvedSequenceConfiguration
                    guard resolvedSequenceConfiguration.clef == .treble else {
                        return "reason=clef_not_treble resolvedClef=\(String(describing: resolvedSequenceConfiguration.clef))"
                    }
                    guard resolvedSequenceConfiguration.answerPolicy == .pitchClass else {
                        return "reason=answer_policy_not_pitch_class resolvedPolicy=\(String(describing: resolvedSequenceConfiguration.answerPolicy))"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .staff) == .promptOnly else {
                        return "reason=staff_not_prompt_only"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .naturalNoteStrip) == .answerOnly else {
                        return "reason=strip_not_answer_only"
                    }
                    guard self.exercisePresentationState.isSurfaceVisible(.staff),
                          self.exercisePresentationState.isSurfaceVisible(.naturalNoteStrip) else {
                        return "reason=sr0_surfaces_not_visible"
                    }
                    guard !self.exercisePresentationState.containsSurface(.fretboard),
                          self.exercisePresentationState.projectedSurfaceState(for: .fretboard) == nil else {
                        return "reason=fretboard_surface_present"
                    }
                    guard !self.exercisePresentationState.containsSurface(.piano),
                          self.exercisePresentationState.projectedSurfaceState(for: .piano) == nil else {
                        return "reason=piano_surface_present"
                    }
                    guard self.exercisePresentationState.scene.surfaceNode(for: .naturalNoteStrip)?.presentationStyle == .horizontalStrip else {
                        return "reason=strip_not_horizontal_strip"
                    }
                    guard self.exercisePresentationState.naturalNoteStripRailLayout == nil else {
                        return "reason=unexpected_rail_layout"
                    }
                    guard let stripLayout = self.exercisePresentationState.naturalNoteStripHorizontalLayout else {
                        return "reason=missing_horizontal_layout"
                    }
                    guard stripLayout.accidentalPlacements.count == PitchClass.accidentalCasesInOrder.count,
                          stripLayout.naturalPlacements.count == PitchClass.naturalCasesInOrder.count else {
                        return "reason=strip_layout_counts_incorrect accidentalCount=\(stripLayout.accidentalPlacements.count) naturalCount=\(stripLayout.naturalPlacements.count)"
                    }
                    guard stripLayout.accidentalPlacements.allSatisfy({ $0.row == .accidentalsTop }),
                          stripLayout.naturalPlacements.allSatisfy({ $0.row == .naturalsBottom }) else {
                        return "reason=strip_layout_rows_incorrect"
                    }
                    guard self.naturalNoteStripView.isUserInteractionEnabled else {
                        return "reason=strip_interaction_disabled"
                    }
                    guard !self.pianoSurfaceView.isPianoInteractionEnabled else {
                        return "reason=piano_interaction_enabled"
                    }
                    guard self.currentGeneratedQuarterNoteSequence != nil else {
                        return "reason=missing_sequence"
                    }
                    guard self.staffDisplayState.sequencePresentation?.state == .idle else {
                        return "reason=staff_not_idle presentation=\(String(describing: self.staffDisplayState.sequencePresentation))"
                    }
                    guard !self.sequenceRegenerateButton.isHidden else {
                        return "reason=regenerate_hidden"
                    }
                    return nil
                }
            ),
            (
                name: "wrong_strip_answer",
                action: {
                    guard let expectedPitchClass = currentExpectedPitchClass() else {
                        wrongPitchClass = nil
                        return
                    }
                    let wrongAnswer = nextDifferentPitchClass(from: expectedPitchClass)
                    wrongPitchClass = wrongAnswer
                    self.handleNaturalNoteStripPitchClassTap(wrongAnswer)
                },
                validate: {
                    guard let wrongPitchClass else {
                        return "reason=missing_wrong_pitch_class"
                    }
                    guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                        return "reason=missing_wrong_evaluation"
                    }
                    guard !evaluation.isCorrect else {
                        return "reason=wrong_strip_answer_marked_correct"
                    }
                    guard evaluation.comparisonPolicy == .pitchClass else {
                        return "reason=wrong_policy=\(String(describing: evaluation.comparisonPolicy))"
                    }
                    guard evaluation.answeredPitchClass == wrongPitchClass else {
                        return "reason=wrong_pitch_lost answered=\(evaluation.answeredPitchClass.displayText()) expected=\(wrongPitchClass.displayText())"
                    }
                    guard evaluation.answeredNotePitch == nil else {
                        return "reason=strip_wrong_answer_leaked_note_pitch answered=\(String(describing: evaluation.answeredNotePitch))"
                    }
                    guard self.quarterNoteSequenceSession?.currentIndex == 0 else {
                        return "reason=wrong_strip_answer_advanced currentIndex=\(self.quarterNoteSequenceSession?.currentIndex ?? -1)"
                    }
                    guard self.staffDisplayState.sequencePresentation?.state == .wrong,
                          self.staffDisplayState.sequencePresentation?.lastEvaluationResult == .incorrect else {
                        return "reason=staff_missing_wrong_feedback presentation=\(String(describing: self.staffDisplayState.sequencePresentation))"
                    }
                    return nil
                }
            ),
            (
                name: "correct_strip_answer",
                action: {
                    guard let expectedPitchClass = currentExpectedPitchClass() else {
                        correctPitchClass = nil
                        return
                    }
                    correctPitchClass = expectedPitchClass
                    self.handleNaturalNoteStripPitchClassTap(expectedPitchClass)
                },
                validate: {
                    guard let correctPitchClass else {
                        return "reason=missing_correct_pitch_class"
                    }
                    guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                        return "reason=missing_correct_evaluation"
                    }
                    guard evaluation.isCorrect else {
                        return "reason=correct_strip_answer_marked_wrong"
                    }
                    guard evaluation.comparisonPolicy == .pitchClass else {
                        return "reason=correct_policy=\(String(describing: evaluation.comparisonPolicy))"
                    }
                    guard evaluation.answeredPitchClass == correctPitchClass else {
                        return "reason=correct_pitch_lost answered=\(evaluation.answeredPitchClass.displayText()) expected=\(correctPitchClass.displayText())"
                    }
                    guard evaluation.answeredNotePitch == nil else {
                        return "reason=strip_correct_answer_leaked_note_pitch answered=\(String(describing: evaluation.answeredNotePitch))"
                    }
                    guard self.quarterNoteSequenceSession?.currentIndex == 1 else {
                        return "reason=correct_strip_answer_did_not_advance currentIndex=\(self.quarterNoteSequenceSession?.currentIndex ?? -1)"
                    }
                    guard self.staffDisplayState.sequencePresentation?.state == .correct,
                          self.staffDisplayState.sequencePresentation?.lastEvaluationResult == .correct else {
                        return "reason=staff_missing_correct_feedback presentation=\(String(describing: self.staffDisplayState.sequencePresentation))"
                    }
                    return nil
                }
            ),
            (
                name: "switch_back_to_single",
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setExerciseModeSingle)
                    )
                },
                validate: {
                    guard self.trainerDisplayState.exerciseMode == .single else {
                        return "reason=mode_not_single resolvedMode=\(String(describing: self.trainerDisplayState.exerciseMode))"
                    }
                    guard self.quarterNoteSequenceSession == nil,
                          self.quarterNoteSequenceLastEvaluation == nil else {
                        return "reason=sequence_state_not_cleared sessionIndex=\(self.quarterNoteSequenceSession?.currentIndex ?? -1) lastEvaluation=\(String(describing: self.quarterNoteSequenceLastEvaluation))"
                    }
                    guard self.staffDisplayState.sequencePresentation == nil else {
                        return "reason=staff_sequence_feedback_leaked presentation=\(String(describing: self.staffDisplayState.sequencePresentation))"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .fretboard) == .answerOnly else {
                        return "reason=fretboard_not_answer_only"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .naturalNoteStrip) != .answerOnly,
                          !self.exercisePresentationState
                            .effectiveSurfaceState(for: .naturalNoteStrip)
                            .isAnswerEnabled,
                          !self.naturalNoteStripView.isUserInteractionEnabled else {
                        return "reason=strip_answer_surface_not_cleared"
                    }
                    guard !self.pianoSurfaceView.isPianoInteractionEnabled else {
                        return "reason=piano_interaction_enabled"
                    }
                    guard self.sequenceRegenerateButton.isHidden else {
                        return "reason=regenerate_still_visible"
                    }
                    return nil
                }
            )
        ]

        print(
            "[RuntimeSmoke][iOS] begin scenario=sr0_note_strip_answer initialMode=\(String(describing: trainerDisplayState.exerciseMode))"
        )
        runExerciseAnswerSmokeSteps(
            steps,
            index: 0,
            scenarioName: "sr0_note_strip_answer",
            settleLayout: settleLayout,
            successSummary: {
                "[RuntimeSmoke][iOS] PASS scenario=sr0_note_strip_answer finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) stripVisible=\(self.exercisePresentationState.isSurfaceVisible(.naturalNoteStrip))"
            },
            completion: completion
        )
    }

    private func runExerciseAnswerSmokeSteps(
        _ steps: [(name: String, action: () -> Void, validate: () -> String?)],
        index: Int,
        scenarioName: String,
        settleLayout: @escaping () -> Void,
        successSummary: @escaping () -> String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard index < steps.count else {
            completion(true, successSummary())
            return
        }

        let step = steps[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print(
                "[RuntimeSmoke][iOS] step=\(step.name) begin mode=\(String(describing: self.trainerDisplayState.exerciseMode))"
            )
            step.action()
            settleLayout()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                settleLayout()
                if let failure = step.validate() {
                    completion(
                        false,
                        "[RuntimeSmoke][iOS] FAIL scenario=\(scenarioName) step=\(step.name) \(failure)"
                    )
                    return
                }
                print(
                    "[RuntimeSmoke][iOS] step=\(step.name) end mode=\(String(describing: self.trainerDisplayState.exerciseMode))"
                )
                self.runExerciseAnswerSmokeSteps(
                    steps,
                    index: index + 1,
                    scenarioName: scenarioName,
                    settleLayout: settleLayout,
                    successSummary: successSummary,
                    completion: completion
                )
            }
        }
    }

    func runFR0CircleFeedbackSmokeTest(
        in window: UIWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            action: () -> Void,
            validate: () -> String?
        )
        var wrongCell: FretboardCell?
        var correctCell: FretboardCell?

        func orderedCells(_ cells: Set<FretboardCell>) -> [FretboardCell] {
            cells.sorted {
                if $0.stringIndex == $1.stringIndex {
                    return $0.fret < $1.fret
                }
                return $0.stringIndex < $1.stringIndex
            }
        }

        func currentMarkerShape()
            -> FretboardFeedbackOverlayState.SingleCoverageMarkerShape?
        {
            guard
                case let .singleCoverage(_, _, markerShape)
                    = self.currentFretboardFeedbackOverlayState
            else {
                return nil
            }
            return markerShape
        }

        func firstWrongCell() -> FretboardCell? {
            let requiredCells = self.currentSingleCoverageRequiredCells
            for stringIndex in 0..<self.displayState.configuration.stringCount {
                for fret in 0...self.displayState.configuration.maxFret {
                    let candidate = FretboardCell(
                        stringIndex: stringIndex,
                        fret: fret
                    )
                    guard self.displayState.configuration.notePitch(for: candidate) != nil
                    else {
                        continue
                    }
                    guard !requiredCells.contains(candidate) else {
                        continue
                    }
                    return candidate
                }
            }
            return nil
        }

        func firstCorrectCell() -> FretboardCell? {
            orderedCells(self.currentSingleCoverageRequiredCells).first
        }

        func settleLayout() {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        let steps: [SmokeStep] = [
            (
                name: "switch_to_fr0",
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setExerciseModeFr0)
                    )
                },
                validate: {
                    guard self.trainerDisplayState.exerciseMode == .fr0 else {
                        return "reason=mode_not_fr0 resolvedMode=\(String(describing: self.trainerDisplayState.exerciseMode))"
                    }
                    guard
                        self.exerciseLayoutPreferences
                            == .fr0TargetPromptFretboardAnswer
                    else {
                        return "reason=layout_not_fixed resolvedLayout=\(String(describing: self.exerciseLayoutPreferences))"
                    }
                    guard
                        self.exercisePresentationState.projectedSurfaceState(
                            for: .fretboard
                        ) == .answerOnly,
                        self.exercisePresentationState.isSurfaceVisible(.fretboard)
                    else {
                        return "reason=fretboard_not_answer_only"
                    }
                    guard self.currentSingleCoverageRequiredCells.count > 1 else {
                        return "reason=fr0_target_cell_count_too_small count=\(self.currentSingleCoverageRequiredCells.count)"
                    }
                    guard self.singleCoverageWrongCells.isEmpty else {
                        return "reason=wrong_cells_not_cleared count=\(self.singleCoverageWrongCells.count)"
                    }
                    guard currentMarkerShape() == .circle else {
                        return "reason=marker_shape_not_circle resolved=\(String(describing: currentMarkerShape()))"
                    }
                    guard
                        case let .singleCoverage(correctCells, wrongCells, markerShape)
                            = self.currentFretboardFeedbackOverlayState
                    else {
                        return "reason=missing_single_coverage_overlay overlay=\(String(describing: self.currentFretboardFeedbackOverlayState))"
                    }
                    guard correctCells.isEmpty else {
                        return "reason=correct_cells_not_empty count=\(correctCells.count)"
                    }
                    guard wrongCells.isEmpty else {
                        return "reason=wrong_cells_not_empty count=\(wrongCells.count)"
                    }
                    guard markerShape == .circle else {
                        return "reason=overlay_shape_not_circle resolved=\(String(describing: markerShape))"
                    }
                    return nil
                }
            ),
            (
                name: "wrong_fr0_answer",
                action: {
                    guard let candidate = firstWrongCell() else {
                        wrongCell = nil
                        return
                    }
                    wrongCell = candidate
                    self.handleSingleCoverageAnswer(candidate)
                },
                validate: {
                    guard let wrongCell else {
                        return "reason=missing_wrong_cell"
                    }
                    guard let evaluation = self.singleCoverageLastEvaluation else {
                        return "reason=missing_wrong_evaluation"
                    }
                    guard evaluation.hitKind == .wrong else {
                        return "reason=wrong_answer_marked_correct"
                    }
                    guard evaluation.selectedCell == wrongCell else {
                        return "reason=wrong_cell_lost selected=\(evaluation.selectedCell) expected=\(wrongCell)"
                    }
                    guard self.singleCoverageWrongCells == Set([wrongCell]) else {
                        return "reason=wrong_cells_not_persisted count=\(self.singleCoverageWrongCells.count)"
                    }
                    guard
                        self.singleCoverageSession?.visitedCells.isEmpty == true
                    else {
                        return "reason=wrong_answer_mutated_correct_cells count=\(self.singleCoverageSession?.visitedCells.count ?? -1)"
                    }
                    guard
                        case let .singleCoverage(correctCells, wrongCells, markerShape)
                            = self.currentFretboardFeedbackOverlayState
                    else {
                        return "reason=missing_single_coverage_overlay_after_wrong overlay=\(String(describing: self.currentFretboardFeedbackOverlayState))"
                    }
                    guard correctCells.isEmpty else {
                        return "reason=wrong_answer_added_correct_cells count=\(correctCells.count)"
                    }
                    guard wrongCells.contains(wrongCell) else {
                        return "reason=wrong_overlay_missing_cell count=\(wrongCells.count)"
                    }
                    guard markerShape == .circle else {
                        return "reason=wrong_overlay_shape_not_circle resolved=\(String(describing: markerShape))"
                    }
                    return nil
                }
            ),
            (
                name: "correct_fr0_answer",
                action: {
                    guard let candidate = firstCorrectCell() else {
                        correctCell = nil
                        return
                    }
                    correctCell = candidate
                    self.handleSingleCoverageAnswer(candidate)
                },
                validate: {
                    guard let correctCell else {
                        return "reason=missing_correct_cell"
                    }
                    guard let evaluation = self.singleCoverageLastEvaluation else {
                        return "reason=missing_correct_evaluation"
                    }
                    guard evaluation.hitKind.isCorrect else {
                        return "reason=correct_answer_marked_wrong"
                    }
                    guard !evaluation.didAdvanceTarget else {
                        return "reason=correct_answer_advanced_too_early"
                    }
                    guard evaluation.selectedCell == correctCell else {
                        return "reason=correct_cell_lost selected=\(evaluation.selectedCell) expected=\(correctCell)"
                    }
                    guard
                        self.singleCoverageSession?.visitedCells.contains(correctCell)
                            == true
                    else {
                        return "reason=correct_cell_not_recorded"
                    }
                    guard
                        case let .singleCoverage(correctCells, wrongCells, markerShape)
                            = self.currentFretboardFeedbackOverlayState
                    else {
                        return "reason=missing_single_coverage_overlay_after_correct overlay=\(String(describing: self.currentFretboardFeedbackOverlayState))"
                    }
                    guard correctCells.contains(correctCell) else {
                        return "reason=correct_overlay_missing_cell count=\(correctCells.count)"
                    }
                    if let wrongCell {
                        guard wrongCells.contains(wrongCell) else {
                            return "reason=wrong_overlay_not_persisted_after_correct count=\(wrongCells.count)"
                        }
                    }
                    guard markerShape == .circle else {
                        return "reason=correct_overlay_shape_not_circle resolved=\(String(describing: markerShape))"
                    }
                    return nil
                }
            ),
            (
                name: "switch_back_to_single",
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setExerciseModeSingle)
                    )
                },
                validate: {
                    guard self.trainerDisplayState.exerciseMode == .single else {
                        return "reason=mode_not_single resolvedMode=\(String(describing: self.trainerDisplayState.exerciseMode))"
                    }
                    guard self.singleCoverageWrongCells.isEmpty else {
                        return "reason=wrong_cells_leaked_to_single count=\(self.singleCoverageWrongCells.count)"
                    }
                    guard
                        case let .singleCoverage(_, wrongCells, markerShape)
                            = self.currentFretboardFeedbackOverlayState
                    else {
                        return "reason=missing_single_overlay_after_switch_back overlay=\(String(describing: self.currentFretboardFeedbackOverlayState))"
                    }
                    guard wrongCells.isEmpty else {
                        return "reason=single_mode_wrong_cells_not_cleared count=\(wrongCells.count)"
                    }
                    guard markerShape == .roundedRect else {
                        return "reason=single_mode_shape_not_rounded_rect resolved=\(String(describing: markerShape))"
                    }
                    return nil
                }
            )
        ]

        print(
            "[RuntimeSmoke][iOS] begin scenario=fr0_circle_feedback initialMode=\(String(describing: trainerDisplayState.exerciseMode))"
        )
        runExerciseAnswerSmokeSteps(
            steps,
            index: 0,
            scenarioName: "fr0_circle_feedback",
            settleLayout: settleLayout,
            successSummary: {
                "[RuntimeSmoke][iOS] PASS scenario=fr0_circle_feedback finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) markerShape=\(String(describing: currentMarkerShape()))"
            },
            completion: completion
        )
    }

    func runLayoutPresetRegressionSmokeTest(
        in window: UIWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            expectedLayout: ExerciseLayoutPreset,
            action: () -> Void
        )

        let steps: [SmokeStep] = [
            (
                name: "switch_to_stacked",
                expectedLayout: .stacked,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetStacked)
                    )
                }
            ),
            (
                name: "resize_landscape_like",
                expectedLayout: .stacked,
                action: {
                    let bounds = CGRect(x: 0, y: 0, width: 874, height: 402)
                    window.bounds = bounds
                    window.frame = bounds
                    window.setNeedsLayout()
                    window.layoutIfNeeded()
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                }
            ),
            (
                name: "switch_to_side",
                expectedLayout: .sideBySide,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetSideBySide)
                    )
                }
            ),
            (
                name: "resize_portrait_like",
                expectedLayout: .sideBySide,
                action: {
                    let bounds = CGRect(x: 0, y: 0, width: 402, height: 874)
                    window.bounds = bounds
                    window.frame = bounds
                    window.setNeedsLayout()
                    window.layoutIfNeeded()
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                }
            ),
            (
                name: "switch_to_stacked_again",
                expectedLayout: .stacked,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetStacked)
                    )
                }
            ),
            (
                name: "switch_to_side_final",
                expectedLayout: .sideBySide,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetSideBySide)
                    )
                }
            )
        ]

        print(
            "[RuntimeSmoke][iOS] begin scenario=layout_preset_regression initialLayout=\(exerciseLayoutPreferences.layoutPreset.rawValue)"
        )
        runLayoutPresetRegressionSmokeSteps(
            steps,
            index: 0,
            completion: completion
        )
    }

    private func runLayoutPresetRegressionSmokeSteps(
        _ steps: [(name: String, expectedLayout: ExerciseLayoutPreset, action: () -> Void)],
        index: Int,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard index < steps.count else {
            let summary =
                "[RuntimeSmoke][iOS] PASS scenario=layout_preset_regression finalLayout=\(exerciseLayoutPreferences.layoutPreset.rawValue) sceneBounds=\(NSCoder.string(for: exerciseSceneRenderer.sceneContainerView.bounds))"
            completion(true, summary)
            return
        }

        let step = steps[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print(
                "[RuntimeSmoke][iOS] step=\(step.name) begin currentLayout=\(self.exerciseLayoutPreferences.layoutPreset.rawValue)"
            )
            step.action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let resolvedLayout = self.exerciseLayoutPreferences.layoutPreset
                let summary =
                    "[RuntimeSmoke][iOS] step=\(step.name) end resolvedLayout=\(resolvedLayout.rawValue) sceneBounds=\(NSCoder.string(for: self.exerciseSceneRenderer.sceneContainerView.bounds))"
                print(summary)

                guard resolvedLayout == step.expectedLayout else {
                    completion(
                        false,
                        "[RuntimeSmoke][iOS] FAIL scenario=layout_preset_regression step=\(step.name) expectedLayout=\(step.expectedLayout.rawValue) resolvedLayout=\(resolvedLayout.rawValue)"
                    )
                    return
                }

                self.runLayoutPresetRegressionSmokeSteps(
                    steps,
                    index: index + 1,
                    completion: completion
                )
            }
        }
    }
}
#endif

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 16
    static let contentTopInset: CGFloat = 68
    static let topContentFloatingButtonInset: CGFloat = 12
    static let verticalSpacing: CGFloat = 20
    static let bottomInset: CGFloat = 16
    static let settingsButtonSize: CGFloat = 40
    static let sequenceRegenerateButtonSize: CGFloat = 36
    static let contentSizeTolerance: CGFloat = 0.5
}

private enum PositionPromptTiming {
    static let wrongFlashDuration: TimeInterval = 0.28
    static let correctHoldDuration: TimeInterval = 1.0
}
#endif

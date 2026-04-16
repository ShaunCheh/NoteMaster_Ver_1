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

    private struct PendingPresentationTransaction {
        var settingsPanelState = false
        var fretboardDisplayState = false
        var staffDisplayState = false
        var scenePresentation = false
        var sequenceRegenerateButton = false
        var labelVisibilityButton = false
        var answerSurfaceInteraction = false
        var pianoDemoState = false
        var quarterNoteSequenceTransition: (
            old: ExercisePresentationState,
            new: ExercisePresentationState
        )?

        var hasPendingWork: Bool {
            settingsPanelState
                || fretboardDisplayState
                || staffDisplayState
                || scenePresentation
                || sequenceRegenerateButton
                || labelVisibilityButton
                || answerSurfaceInteraction
                || pianoDemoState
                || quarterNoteSequenceTransition != nil
        }

        mutating func mergeQuarterNoteSequenceTransition(
            from oldValue: ExercisePresentationState,
            to newValue: ExercisePresentationState
        ) {
            if let existingTransition = quarterNoteSequenceTransition {
                quarterNoteSequenceTransition = (
                    old: existingTransition.old,
                    new: newValue
                )
            } else {
                quarterNoteSequenceTransition = (old: oldValue, new: newValue)
            }
        }
    }

    private var displayState = FretboardDisplayState.default {
        didSet {
            invalidateFretboardDisplayPresentation()
        }
    }

    private var staffDisplayState = macOSViewController.initialStaffDisplayState {
        didSet {
            invalidateStaffDisplayPresentation()
        }
    }
    private var exerciseLayoutPreferences = macOSViewController
        .initialExerciseLayoutPreferences {
        didSet {
            invalidateSettingsPanelPresentation()
        }
    }
    private var exercisePresentationState = macOSViewController
        .initialExercisePresentationState {
        didSet {
            invalidateExerciseScenePresentation(from: oldValue)
        }
    }
    private var trainerDisplayState = TrainerDisplayState.default {
        didSet {
            invalidateTrainerDisplayPresentation()
        }
    }
    private var settingsDebugState = SettingsDebugState() {
        didSet {
            invalidateSettingsDebugPresentation()
        }
    }
    private var baseStaffDisplayState = macOSViewController.initialStaffDisplayState

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
    private var hasRenderedExerciseSceneOnce = false
    private var isSceneLayoutSettlementScheduled = false
    private var isSettlingSceneLayout = false
    private var lastSettledSceneContainerBounds: CGRect = .zero
    private var isSceneLayoutSettlementDirty = false
    private var isAwaitingSceneLayoutPass = false
    private var settingsMutationDepth = 0
    private var pianoPanelState = macOSViewController.initialPianoPanelState {
        didSet {
            invalidatePianoPanelPresentation()
        }
    }
    private var playbackCoordinator: PlaybackCoordinator?
    private var lastPianoAnswerNotesByPreviewID: [PianoPreviewID: NotePitch] = [:]
    var onRootModeChangeRequest: ((RootMode) -> Void)?
    private var presentationTransactionDepth = 0
    private var isCommittingPresentationTransaction = false
    private var isPresentationTransactionCommitScheduled = false
    private var pendingPresentationTransaction = PendingPresentationTransaction()

    private func logLifecycle(_ message: String) {
        print("[Startup][macOSVC] \(message) \(debugStateSnapshot())")
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

    private var isHandlingSettingsMutation: Bool {
        settingsMutationDepth > 0
    }

    private var hasUsableSceneLayoutBounds: Bool {
        let bounds = exerciseSceneRenderer.sceneContainerView.bounds
        return view.window != nil && bounds.width > 0 && bounds.height > 0
    }

    private var canSettleSceneLayoutNow: Bool {
        isViewLoaded &&
        hasRenderedExerciseSceneOnce &&
        !isSettlingSceneLayout &&
        !isHandlingSettingsMutation &&
        !isCommittingPresentationTransaction &&
        !isPresentationTransactionCommitScheduled &&
        !pendingPresentationTransaction.hasPendingWork &&
        hasUsableSceneLayoutBounds
    }

    private var canCommitPresentationTransactionNow: Bool {
        isViewLoaded &&
        presentationTransactionDepth == 0 &&
        !isCommittingPresentationTransaction &&
        !isHandlingSettingsMutation
    }

    private func performPresentationTransaction(
        _ mutations: () -> Void
    ) {
        presentationTransactionDepth += 1
        mutations()
        presentationTransactionDepth -= 1

        guard presentationTransactionDepth == 0 else {
            return
        }

        commitPresentationTransactionIfPossible()
    }

    private func commitPendingPresentationTransactionIfNeeded() {
        guard canCommitPresentationTransactionNow,
              pendingPresentationTransaction.hasPendingWork else {
            return
        }

        isPresentationTransactionCommitScheduled = false
        isCommittingPresentationTransaction = true
        var shouldRequestSceneLayoutSettlement = false
        var requiresDeferredSceneLayoutSettlement = false
        defer {
            isCommittingPresentationTransaction = false
            if shouldRequestSceneLayoutSettlement {
                if requiresDeferredSceneLayoutSettlement {
                    requestDeferredSceneLayoutSettlement()
                } else {
                    requestSceneLayoutSettlement()
                }
            }
            if pendingPresentationTransaction.hasPendingWork {
                commitPresentationTransactionIfPossible()
            }
        }

        while pendingPresentationTransaction.hasPendingWork {
            let transaction = pendingPresentationTransaction
            pendingPresentationTransaction = PendingPresentationTransaction()

            if transaction.settingsPanelState {
                applySettingsPanelState()
            }
            if transaction.sequenceRegenerateButton {
                applySequenceRegenerateButtonState()
            }
            if transaction.pianoDemoState {
                applyPianoDemoState()
                shouldRequestSceneLayoutSettlement = true
            }
            if transaction.fretboardDisplayState {
                applyFretboardDisplayState()
                shouldRequestSceneLayoutSettlement = true
            }
            if transaction.staffDisplayState {
                applyStaffDisplayState()
                shouldRequestSceneLayoutSettlement = true
            }
            if transaction.scenePresentation {
                let didChangeSceneStructure = renderExercisePresentationState()
                shouldRequestSceneLayoutSettlement = true
                requiresDeferredSceneLayoutSettlement =
                    requiresDeferredSceneLayoutSettlement || didChangeSceneStructure
            }
            if let transition = transaction.quarterNoteSequenceTransition {
                handleQuarterNoteSequencePresentationTransition(
                    from: transition.old,
                    to: transition.new
                )
            }
            if transaction.answerSurfaceInteraction {
                updateAnswerSurfaceInteractionState()
            }
            if transaction.labelVisibilityButton {
                applyLabelVisibilityButtonState()
            }
        }
    }

    private func schedulePresentationTransactionCommitIfNeeded() {
        guard isViewLoaded,
              pendingPresentationTransaction.hasPendingWork,
              !isPresentationTransactionCommitScheduled else {
            return
        }

        isPresentationTransactionCommitScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushScheduledPresentationTransactionCommitIfNeeded()
        }
    }

    private func flushScheduledPresentationTransactionCommitIfNeeded() {
        guard isViewLoaded else {
            return
        }

        isPresentationTransactionCommitScheduled = false
        if canCommitPresentationTransactionNow,
           pendingPresentationTransaction.hasPendingWork {
            commitPendingPresentationTransactionIfNeeded()
        } else if pendingPresentationTransaction.hasPendingWork,
                  presentationTransactionDepth == 0,
                  !isCommittingPresentationTransaction {
            schedulePresentationTransactionCommitIfNeeded()
        }
    }

    private func commitPresentationTransactionIfPossible() {
        guard isViewLoaded,
              pendingPresentationTransaction.hasPendingWork else {
            return
        }

        if canCommitPresentationTransactionNow {
            commitPendingPresentationTransactionIfNeeded()
        } else if presentationTransactionDepth == 0 {
            schedulePresentationTransactionCommitIfNeeded()
        }
    }

    private func invalidateSettingsPanelPresentation() {
        guard isViewLoaded else {
            return
        }

        pendingPresentationTransaction.settingsPanelState = true
        commitPresentationTransactionIfPossible()
    }

    private func invalidateFretboardDisplayPresentation() {
        guard isViewLoaded else {
            return
        }

        pendingPresentationTransaction.fretboardDisplayState = true
        pendingPresentationTransaction.settingsPanelState = true
        pendingPresentationTransaction.labelVisibilityButton = true
        commitPresentationTransactionIfPossible()
    }

    private func invalidateStaffDisplayPresentation() {
        if !trainerDisplayState.usesQuarterNoteSequenceKernel {
            baseStaffDisplayState = staffDisplayState
        }

        guard isViewLoaded else {
            return
        }

        pendingPresentationTransaction.staffDisplayState = true
        pendingPresentationTransaction.settingsPanelState = true
        commitPresentationTransactionIfPossible()
    }

    private func invalidateExerciseScenePresentation(
        from oldValue: ExercisePresentationState
    ) {
        guard isViewLoaded else {
            return
        }

        pendingPresentationTransaction.scenePresentation = true
        pendingPresentationTransaction.answerSurfaceInteraction = true
        pendingPresentationTransaction.labelVisibilityButton = true
        pendingPresentationTransaction.mergeQuarterNoteSequenceTransition(
            from: oldValue,
            to: exercisePresentationState
        )
        commitPresentationTransactionIfPossible()
    }

    private func invalidateTrainerDisplayPresentation() {
        guard isViewLoaded else {
            return
        }

        pendingPresentationTransaction.settingsPanelState = true
        pendingPresentationTransaction.sequenceRegenerateButton = true
        pendingPresentationTransaction.pianoDemoState = true
        commitPresentationTransactionIfPossible()
    }

    private func invalidateSettingsDebugPresentation() {
        guard isViewLoaded else {
            return
        }

        pendingPresentationTransaction.settingsPanelState = true
        pendingPresentationTransaction.scenePresentation = true
        commitPresentationTransactionIfPossible()
    }

    private func invalidatePianoPanelPresentation() {
        guard isViewLoaded else {
            return
        }

        pendingPresentationTransaction.settingsPanelState = true
        pendingPresentationTransaction.pianoDemoState = true
        commitPresentationTransactionIfPossible()
    }

    private func markInitialPresentationTransactionDirty() {
        pendingPresentationTransaction.settingsPanelState = true
        pendingPresentationTransaction.fretboardDisplayState = true
        pendingPresentationTransaction.staffDisplayState = true
        pendingPresentationTransaction.scenePresentation = true
        pendingPresentationTransaction.sequenceRegenerateButton = true
        pendingPresentationTransaction.labelVisibilityButton = true
        pendingPresentationTransaction.answerSurfaceInteraction = true
        pendingPresentationTransaction.pianoDemoState = true
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
        if exercisePresentationState != semanticPresentationState {
            exercisePresentationState = semanticPresentationState
        }

        if exerciseLayoutPreferences
            != semanticPresentationState.resolvedLayoutPreferences {
            exerciseLayoutPreferences = semanticPresentationState
                .resolvedLayoutPreferences
        }
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

    private lazy var labelVisibilityButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.image = NSImage(
            systemSymbolName: "eye.slash.fill",
            accessibilityDescription: "Show BCEF fretboard labels"
        )
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .labelColor
        button.identifier = NSUserInterfaceItemIdentifier(
            "floating-fretboard-label-visibility-button"
        )
        button.target = self
        button.action = #selector(handleLabelVisibilityButtonTap)
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

    private lazy var sequenceRegenerateButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.image = NSImage(
            systemSymbolName: "arrow.clockwise",
            accessibilityDescription: "Generate new random sequence"
        )
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.identifier = NSUserInterfaceItemIdentifier(
            "top-content-sequence-regenerate-button"
        )
        button.target = self
        button.action = #selector(handleSequenceRegenerateButtonTap)
        button.toolTip = "Generate new random sequence"
        button.isHidden = true
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        button.layer?.cornerRadius = Layout.sequenceRegenerateButtonSize / 2
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.12
        button.layer?.shadowRadius = 10
        button.layer?.shadowOffset = CGSize(width: 0, height: -4)
        return button
    }()

    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private var sceneViewportHeightConstraint: NSLayoutConstraint?

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
        naturalNoteStripView.onPitchClassTap = { [weak self] pitchClass in
            self?.handleNaturalNoteStripPitchClassTap(pitchClass)
        }
        naturalNoteStripView.isHidden = true
        return naturalNoteStripView
    }()

    private lazy var exerciseSceneRenderer = macOSExerciseSceneRenderer(
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

    private lazy var pianoSurfaceView: macOSPianoSurfaceView = {
        let pianoSurfaceView = macOSPianoSurfaceView(
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

    override func loadView() {
        print("[Startup][macOSVC] loadView begin")
        view = NSView()
        print("[Startup][macOSVC] loadView end")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logLifecycle("viewDidLoad begin")
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureLayout()
        performInitialPresentationTransaction()
        logLifecycle("viewDidLoad end")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        requestSceneLayoutSettlement()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        interruptActivePianoPlayback(reason: .viewWillDisappear)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if hasRenderedExerciseSceneOnce,
           !isSettlingSceneLayout {
            let sceneContainerBounds = exerciseSceneRenderer.sceneContainerView.bounds
                .integral
            if isAwaitingSceneLayoutPass
                || sceneContainerBounds != lastSettledSceneContainerBounds {
                requestSceneLayoutSettlementFromLayoutPass()
            }
        }
        if !hasLoggedInitialLayoutPass {
            hasLoggedInitialLayoutPass = true
            logLifecycle("first layout pass bounds=\(view.bounds)")
        }
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
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
        view.addSubview(scrollView)
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
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
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

    @discardableResult
    private func renderExercisePresentationState() -> Bool {
        logLifecycle("renderExercisePresentationState begin")
        macOSSettingsMutationTrace.logIfActive(
            "controller renderExercisePresentationState begin sceneSurfaces=\(exercisePresentationState.scene.surfaceNodes.map(\.id)) layout=\(String(describing: exerciseLayoutPreferences.layoutPreset))"
        )
        updateSceneViewportHeightConstraint()
        let didChangeSceneStructure = exerciseSceneRenderer.render(
            presentationState: exercisePresentationState,
            fretboardDisplayState: displayState,
            debugState: settingsDebugState
        )
        hasRenderedExerciseSceneOnce = true
        macOSSettingsMutationTrace.logIfActive(
            "controller renderExercisePresentationState end didChangeSceneStructure=\(didChangeSceneStructure) sceneContainer=\(macOSSettingsMutationTrace.describe(view: exerciseSceneRenderer.sceneContainerView))"
        )
        logLifecycle("renderExercisePresentationState end")
        return didChangeSceneStructure
    }

    private func updateSceneViewportHeightConstraint() {
        sceneViewportHeightConstraint?.isActive = exercisePresentationState
            .fretboardLayoutContract
            .pinsSceneToViewportHeight
    }

    private func performInitialPresentationTransaction() {
        guard isViewLoaded else {
            return
        }

        logLifecycle("performInitialPresentationTransaction begin")
        performPresentationTransaction {
            markInitialPresentationTransactionDirty()
            synchronizeTrainerPresentationState(reason: "initial")
        }
        logLifecycle("performInitialPresentationTransaction end")
    }

    private func applyFretboardDisplayState() {
        logLifecycle("applyFretboardDisplayState begin")
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
        fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
        exerciseSceneRenderer.applyFretboardDisplayState(displayState)

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
            updateAnswerSurfaceInteractionState()
        }
        logLifecycle("applyFretboardDisplayState end")
    }

    private func applyStaffDisplayState() {
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        staffView.showsComponentBoundsOverlay = staffDisplayState.showsComponentBoundsOverlay
    }

    private func applySettingsPanelState() {
        macOSSettingsMutationTrace.logIfActive(
            "controller applySettingsPanelState settingsContainer=\(macOSSettingsMutationTrace.describe(view: settingsContainerView)) layout=\(String(describing: exerciseLayoutPreferences.layoutPreset))"
        )
        settingsContainerView.navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: settingsPanelStateContext
        )
    }

    private func requestSceneLayoutSettlement() {
        isSceneLayoutSettlementDirty = true
        guard isViewLoaded, hasRenderedExerciseSceneOnce else {
            return
        }

        awaitSceneLayoutPass()
    }

    private func requestDeferredSceneLayoutSettlement() {
        isSceneLayoutSettlementDirty = true
        guard isViewLoaded, hasRenderedExerciseSceneOnce else {
            return
        }

        // A freshly rebuilt scene must not immediately force AppKit to flush
        // the scroll/document subtree in the same turn. Wait for AppKit's next
        // natural layout pass, then settle the dynamic constraints.
        awaitSceneLayoutPass()
    }

    private func requestSceneLayoutSettlementFromLayoutPass() {
        isSceneLayoutSettlementDirty = true
        isAwaitingSceneLayoutPass = false
        scheduleSceneLayoutSettlementIfNeeded()
    }

    private func awaitSceneLayoutPass() {
        isAwaitingSceneLayoutPass = true
        view.needsLayout = true
        exerciseSceneRenderer.sceneContainerView.needsLayout = true
    }

    private func scheduleSceneLayoutSettlementIfNeeded() {
        macOSSettingsMutationTrace.logIfActive(
            "controller scheduleSceneLayoutSettlement dirty=\(isSceneLayoutSettlementDirty) handlingSettingsMutation=\(isHandlingSettingsMutation) hasUsableBounds=\(hasUsableSceneLayoutBounds) rootView=\(macOSSettingsMutationTrace.describe(view: view)) settingsContainer=\(macOSSettingsMutationTrace.describe(view: settingsContainerView)) rootContainsActiveSource=\(macOSSettingsMutationTrace.containsActiveSource(in: view)) settingsContainsActiveSource=\(macOSSettingsMutationTrace.containsActiveSource(in: settingsContainerView))"
        )
        guard isViewLoaded,
              hasRenderedExerciseSceneOnce,
              isSceneLayoutSettlementDirty,
              !isSceneLayoutSettlementScheduled else {
            return
        }

        isSceneLayoutSettlementScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushScheduledSceneLayoutSettlementIfNeeded()
        }
    }

    private func flushScheduledSceneLayoutSettlementIfNeeded() {
        guard isViewLoaded else {
            return
        }

        isSceneLayoutSettlementScheduled = false
        guard isSceneLayoutSettlementDirty, canSettleSceneLayoutNow else {
            return
        }

        settleSceneLayoutIfNeeded()
    }

    private func settleSceneLayoutIfNeeded() {
        guard isSceneLayoutSettlementDirty, canSettleSceneLayoutNow else {
            return
        }
        guard !isAwaitingSceneLayoutPass else {
            return
        }

        macOSSettingsMutationTrace.logIfActive(
            "controller settleSceneLayout begin handlingSettingsMutation=\(isHandlingSettingsMutation) hasUsableBounds=\(hasUsableSceneLayoutBounds) rootView=\(macOSSettingsMutationTrace.describe(view: view)) settingsContainer=\(macOSSettingsMutationTrace.describe(view: settingsContainerView)) rootContainsActiveSource=\(macOSSettingsMutationTrace.containsActiveSource(in: view)) settingsContainsActiveSource=\(macOSSettingsMutationTrace.containsActiveSource(in: settingsContainerView))"
        )
        isSceneLayoutSettlementScheduled = false
        isSettlingSceneLayout = true
        isSceneLayoutSettlementDirty = false
        defer {
            lastSettledSceneContainerBounds = exerciseSceneRenderer.sceneContainerView
                .bounds
                .integral
            let shouldRescheduleSettlement = isSceneLayoutSettlementDirty
            isSettlingSceneLayout = false
            macOSSettingsMutationTrace.logIfActive(
                "controller settleSceneLayout end rootView=\(macOSSettingsMutationTrace.describe(view: view)) settingsContainer=\(macOSSettingsMutationTrace.describe(view: settingsContainerView)) rootContainsActiveSource=\(macOSSettingsMutationTrace.containsActiveSource(in: view)) settingsContainsActiveSource=\(macOSSettingsMutationTrace.containsActiveSource(in: settingsContainerView))"
            )
            if shouldRescheduleSettlement {
                scheduleSceneLayoutSettlementIfNeeded()
            }
        }

        let didUpdateDynamicLayout = exerciseSceneRenderer.handleLayoutPass()
        if didUpdateDynamicLayout {
            isSceneLayoutSettlementDirty = true
            awaitSceneLayoutPass()
        }
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
            "[ExerciseAnswerRouter][macOS] result=ignored surface=\(event.surfaceID.rawValue) reason=\(reason.debugDescription)"
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
            print(
                "[SingleCoverage][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
            )
        case .positionPrompt:
            print("[PositionPrompt][macOS] result=ignored reason=missingHitCell")
        case .quarterNoteSequence:
            print(
                "[QuarterNoteSequence][macOS] result=ignored reason=missingHitCell"
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
                "[PositionPrompt][macOS] result=ignored reason=feedbackInProgress phase=\(positionPromptDebugName(for: currentPositionPromptOverlayPhase))"
            )
            return
        }

        ensurePositionPromptSession()
        guard var positionPromptSession,
              positionPromptSessionMatchesCurrentTrainer(positionPromptSession) else {
            print("[PositionPrompt][macOS] result=ignored reason=missingSession")
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
                "[PositionPrompt][macOS] result=ignored reason=unresolvedAnswerEvent surface=\(routedAnswer.event.surfaceID.rawValue)"
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

            print("[macOS] \(evaluation.debugSummary())")
        }
    }

    private func handleSingleCoverageAnswer(_ selectedCell: FretboardCell) {
        ensureSingleCoverageSession()
        guard var singleCoverageSession else {
            print("[SingleCoverage][macOS] result=ignored reason=missingSession")
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
                "[SingleCoverage][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
            )
        case .ignored(.completedSession):
            print(
                "[SingleCoverage][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=completedSession"
            )
        case .ignored(.nonEndedPhase), .ignored(.missingHitCell):
            return
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
            print("[macOS] \(evaluation.debugSummary())")
        }
    }

    private func handleQuarterNoteSequenceAnswer(
        _ event: ExerciseAnswerEvent,
        answer: ResolvedSequenceAnswer
    ) {
        guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
            print(
                "[QuarterNoteSequence][macOS] result=ignored reason=missingSequence"
            )
            return
        }

        if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
            quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
            clearQuarterNoteSequenceFeedbackState()
        }

        guard var quarterNoteSequenceSession else {
            print(
                "[QuarterNoteSequence][macOS] result=ignored reason=missingSession"
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
                    "[QuarterNoteSequence][macOS] result=ignored reason=completedSession string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
                )
            } else if let selectedPitch {
                print(
                    "[QuarterNoteSequence][macOS] result=ignored reason=completedSession answered=\(selectedPitch.displayText())"
                )
            } else {
                print(
                    "[QuarterNoteSequence][macOS] result=ignored reason=completedSession answered=\(answer.pitchClass.displayText())"
                )
            }
        case let .evaluated(evaluation):
            if let selectedCell,
               let selectedPitch {
                print(
                    "[macOS] \(evaluation.debugSummary()) selected=\(selectedPitch.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
                )
            } else if let selectedPitch {
                print(
                    "[macOS] \(evaluation.debugSummary()) answered=\(selectedPitch.displayText())"
                )
            } else {
                print(
                    "[macOS] \(evaluation.debugSummary()) answered=\(answer.pitchClass.displayText())"
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
        performPresentationTransaction {
            trainerDisplayState = TrainerDisplayState(
                exerciseMode: .sequence,
                sequenceConfiguration: TrainerSequenceConfiguration(
                    quarterNoteSequenceSpec: spec
                )
            )
            synchronizeTrainerPresentationState(reason: "generated")
        }
    }

    private func synchronizeTrainerPresentationState(reason: String) {
        logLifecycle("synchronizeTrainerPresentationState reason=\(reason)")
        if trainerDisplayState.usesQuarterNoteSequenceKernel {
            synchronizeQuarterNoteSequencePresentation(reason: reason)
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
                "[QuarterNoteSequence][macOS] clef=\(generatedSequence.clef.title) noteCount=\(generatedSequence.noteCount) includesAccidentals=\(configuredQuarterNoteSequenceSpec.includesAccidentals) state=\(reason)"
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

        fretboardView.areRawEventsEnabled = fretboardInteractionEnabled
            && allowsLiveAnswerInteraction
        naturalNoteStripView.areButtonsEnabled = naturalNoteStripInteractionEnabled
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
            "[SingleCoverage][macOS] target=\(currentFretboardTrainerPrompt.displayText) progress=\(progressText) state=\(reason)"
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
            "[PositionPrompt][macOS] prompt=\(positionPromptSession.promptPitchClass.displayText()) string=\(visibleCell.stringIndex) fret=\(visibleCell.fret) phase=\(positionPromptDebugName(for: currentPositionPromptOverlayPhase)) state=\(reason)"
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
        let accessibilityLabel = showsBCEFLabels
            ? "Hide BCEF fretboard labels"
            : "Show BCEF fretboard labels"
        labelVisibilityButton.image = NSImage(
            systemSymbolName: showsBCEFLabels ? "eye.fill" : "eye.slash.fill",
            accessibilityDescription: accessibilityLabel
        )
        labelVisibilityButton.contentTintColor = showsBCEFLabels ? .white : .labelColor
        labelVisibilityButton.layer?.backgroundColor = (
            showsBCEFLabels
                ? NSColor.controlAccentColor
                : NSColor.controlBackgroundColor
        ).cgColor
        labelVisibilityButton.toolTip = accessibilityLabel
        labelVisibilityButton.setAccessibilityLabel(accessibilityLabel)
    }

    private func regenerateQuarterNoteSequence(reason: String) {
        guard trainerDisplayState.usesQuarterNoteSequenceKernel else {
            return
        }

        performPresentationTransaction {
            fretboardTrainerState = FretboardNaturalNoteTrainerState(
                quarterNoteSequenceSpec: configuredQuarterNoteSequenceSpec
            )
            resetQuarterNoteSequenceInteractionState()
            synchronizeTrainerPresentationState(reason: reason)
        }
    }

    private func schedulePositionPromptTransition(
        after delay: TimeInterval,
        perform update: @escaping (macOSViewController) -> Void
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

    // 控制器仍然持有 settings 展示状态真相；
    // 后续阶段把页面入口按钮隐藏/恢复接到这里即可，不必分散到多个调用点。
    private func applySettingsPresentationState() {
        settingsContainerView.setPresented(isSettingsPresented)
        settingsButton.isHidden = isSettingsPresented
        updateSettingsButtonAppearance()
        applyLabelVisibilityButtonState()
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

    private func applyPianoDemoState() {
        pianoSurfaceView.applySharedSettings(
            resolvedPianoSettingsSlice
        )
        pianoSurfaceView.showsComponentBoundsOverlay = false
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
        let tracedEventID = macOSSettingsMutationTrace.shouldTrace(event)
            ? macOSSettingsMutationTrace.begin(
                event: event,
                state: debugStateSnapshot()
            )
            : nil
        settingsMutationDepth += 1
        defer {
            settingsMutationDepth -= 1
            if settingsMutationDepth == 0 {
                if pendingPresentationTransaction.hasPendingWork {
                    // Scene-affecting commits must happen only after the settings
                    // control finishes dispatching its action.
                    schedulePresentationTransactionCommitIfNeeded()
                } else if isSceneLayoutSettlementDirty {
                    scheduleSceneLayoutSettlementIfNeeded()
                }
            }
        }
        defer {
            if let tracedEventID {
                macOSSettingsMutationTrace.end(
                    tracedEventID,
                    state: debugStateSnapshot()
                )
            }
        }

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
            macOSSettingsMutationTrace.logIfActive(
                "controller handleSettingsPanelEvent no-op"
            )
            return
        }

        macOSSettingsMutationTrace.logIfActive(
            "controller handleSettingsPanelEvent changes layout=\(didChangeExerciseLayoutPreferences) trainer=\(didChangeTrainer) fretboard=\(didChangeFretboard) staff=\(didChangeStaff) piano=\(didChangePianoPanel) debug=\(didChangeSettingsDebug)"
        )

        performPresentationTransaction {
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
                macOSSettingsMutationTrace.logIfActive(
                    "controller write exerciseLayoutPreferences \(String(describing: exerciseLayoutPreferences.layoutPreset)) -> \(String(describing: nextExerciseLayoutPreferences.layoutPreset))"
                )
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
                macOSSettingsMutationTrace.logIfActive(
                    "controller synchronizeTrainerPresentationState reason=\(trainerSyncReason)"
                )
                synchronizeTrainerPresentationState(reason: trainerSyncReason)
            } else if didChangeExerciseLayoutPreferences
                || didChangePianoPanel
                || didChangeFretboard
                || didChangeStaff {
                macOSSettingsMutationTrace.logIfActive(
                    "controller synchronizeExerciseCompositionState reason=settingsStateChanged"
                )
                synchronizeExerciseCompositionState(
                    reason: "settingsStateChanged"
                )
            }
        }
    }
}

#if DEBUG
extension macOSViewController {
    func runSR1PianoAnswerSmokeTest(
        in window: NSWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            action: () -> Void,
            validate: () -> String?
        )
        var wrongPreview: PianoPreviewState?
        var correctPreview: PianoPreviewState?

        func currentExpectedNotePitch() -> NotePitch? {
            if let currentItem = quarterNoteSequenceSession?.currentItem {
                return currentItem.expectedNotePitch
            }
            return currentGeneratedQuarterNoteSequence?.items.first?.expectedNotePitch
        }

        func settleLayout() {
            window.contentView?.layoutSubtreeIfNeeded()
            view.layoutSubtreeIfNeeded()
        }

        let steps: [SmokeStep] = [
            (
                name: "switch_to_sr1",
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setExerciseModeSr1)
                    )
                },
                validate: {
                    guard self.trainerDisplayState.exerciseMode == .sr1 else {
                        return "reason=mode_not_sr1 resolvedMode=\(String(describing: self.trainerDisplayState.exerciseMode))"
                    }
                    guard self.exerciseLayoutPreferences == .srPianoAnswer else {
                        return "reason=layout_not_fixed resolvedLayout=\(String(describing: self.exerciseLayoutPreferences))"
                    }
                    guard self.trainerDisplayState.usesQuarterNoteSequenceKernel else {
                        return "reason=sequence_kernel_disabled"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .staff) == .promptOnly else {
                        return "reason=staff_not_prompt_only"
                    }
                    guard self.exercisePresentationState.projectedSurfaceState(for: .piano) == .answerOnly else {
                        return "reason=piano_not_answer_only"
                    }
                    guard self.exercisePresentationState.isSurfaceVisible(.staff),
                          self.exercisePresentationState.isSurfaceVisible(.piano) else {
                        return "reason=sr1_surfaces_not_visible"
                    }
                    guard self.resolvedPianoSettingsSlice.rowCount == 1,
                          self.resolvedPianoSettingsSlice.movementScope == .rowOnly else {
                        return "reason=piano_settings_not_fixed rowCount=\(self.resolvedPianoSettingsSlice.rowCount) movement=\(self.resolvedPianoSettingsSlice.movementScope.debugName)"
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
                name: "wrong_piano_preview",
                action: {
                    guard let expectedNote = currentExpectedNotePitch() else {
                        wrongPreview = nil
                        return
                    }
                    let preview = PianoPreviewState(
                        rowIndex: 0,
                        note: expectedNote.advanced(by: 1)
                    )
                    wrongPreview = preview
                    self.handlePianoSemanticEvent(.previewStarted(preview))
                },
                validate: {
                    guard let wrongPreview else {
                        return "reason=missing_wrong_preview"
                    }
                    guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                        return "reason=missing_wrong_evaluation"
                    }
                    guard !evaluation.isCorrect else {
                        return "reason=wrong_preview_marked_correct"
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
                name: "correct_piano_preview",
                action: {
                    if let wrongPreview {
                        self.handlePianoSemanticEvent(.previewEnded(wrongPreview))
                    }
                    guard let expectedNote = currentExpectedNotePitch() else {
                        correctPreview = nil
                        return
                    }
                    let preview = PianoPreviewState(
                        rowIndex: 0,
                        note: NotePitch(
                            pitchClass: expectedNote.pitchClass,
                            octave: expectedNote.octave + 1
                        )
                    )
                    correctPreview = preview
                    self.handlePianoSemanticEvent(.previewStarted(preview))
                },
                validate: {
                    guard let correctPreview else {
                        return "reason=missing_correct_preview"
                    }
                    guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                        return "reason=missing_correct_evaluation"
                    }
                    guard evaluation.isCorrect else {
                        return "reason=correct_preview_marked_wrong"
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
            "[RuntimeSmoke][macOS] begin scenario=sr1_piano_answer initialMode=\(String(describing: trainerDisplayState.exerciseMode))"
        )
        runExerciseAnswerSmokeSteps(
            steps,
            index: 0,
            scenarioName: "sr1_piano_answer",
            settleLayout: settleLayout,
            successSummary: {
                "[RuntimeSmoke][macOS] PASS scenario=sr1_piano_answer finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) pianoVisible=\(self.exercisePresentationState.isSurfaceVisible(.piano))"
            },
            completion: completion
        )
    }

    func runSR0NoteStripAnswerSmokeTest(
        in window: NSWindow,
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
            window.contentView?.layoutSubtreeIfNeeded()
            view.layoutSubtreeIfNeeded()
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
                    guard self.naturalNoteStripView.areButtonsEnabled else {
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
                          !self.naturalNoteStripView.areButtonsEnabled else {
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
            "[RuntimeSmoke][macOS] begin scenario=sr0_note_strip_answer initialMode=\(String(describing: trainerDisplayState.exerciseMode))"
        )
        runExerciseAnswerSmokeSteps(
            steps,
            index: 0,
            scenarioName: "sr0_note_strip_answer",
            settleLayout: settleLayout,
            successSummary: {
                "[RuntimeSmoke][macOS] PASS scenario=sr0_note_strip_answer finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) stripVisible=\(self.exercisePresentationState.isSurfaceVisible(.naturalNoteStrip))"
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
                "[RuntimeSmoke][macOS] step=\(step.name) begin mode=\(String(describing: self.trainerDisplayState.exerciseMode))"
            )
            step.action()
            settleLayout()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                settleLayout()
                if let failure = step.validate() {
                    completion(
                        false,
                        "[RuntimeSmoke][macOS] FAIL scenario=\(scenarioName) step=\(step.name) \(failure)"
                    )
                    return
                }
                print(
                    "[RuntimeSmoke][macOS] step=\(step.name) end mode=\(String(describing: self.trainerDisplayState.exerciseMode))"
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

    func runLayoutPresetRegressionSmokeTest(
        in window: NSWindow,
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
                name: "resize_wide",
                expectedLayout: .stacked,
                action: {
                    var nextFrame = window.frame
                    nextFrame.size = NSSize(width: 1120, height: 720)
                    window.setFrame(nextFrame, display: true)
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
                name: "resize_compact",
                expectedLayout: .sideBySide,
                action: {
                    var nextFrame = window.frame
                    nextFrame.size = NSSize(width: 760, height: 540)
                    window.setFrame(nextFrame, display: true)
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
            "[RuntimeSmoke][macOS] begin scenario=layout_preset_regression initialLayout=\(exerciseLayoutPreferences.layoutPreset.rawValue)"
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
                "[RuntimeSmoke][macOS] PASS scenario=layout_preset_regression finalLayout=\(exerciseLayoutPreferences.layoutPreset.rawValue) sceneBounds=\(NSStringFromRect(exerciseSceneRenderer.sceneContainerView.bounds))"
            completion(true, summary)
            return
        }

        let step = steps[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print(
                "[RuntimeSmoke][macOS] step=\(step.name) begin currentLayout=\(self.exerciseLayoutPreferences.layoutPreset.rawValue)"
            )
            step.action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let resolvedLayout = self.exerciseLayoutPreferences.layoutPreset
                let summary =
                    "[RuntimeSmoke][macOS] step=\(step.name) end resolvedLayout=\(resolvedLayout.rawValue) sceneBounds=\(NSStringFromRect(self.exerciseSceneRenderer.sceneContainerView.bounds))"
                print(summary)

                guard resolvedLayout == step.expectedLayout else {
                    completion(
                        false,
                        "[RuntimeSmoke][macOS] FAIL scenario=layout_preset_regression step=\(step.name) expectedLayout=\(step.expectedLayout.rawValue) resolvedLayout=\(resolvedLayout.rawValue)"
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

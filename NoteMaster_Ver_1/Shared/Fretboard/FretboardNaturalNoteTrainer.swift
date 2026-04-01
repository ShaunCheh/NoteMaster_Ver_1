//
//  FretboardNaturalNoteTrainer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

struct FretboardNaturalNoteTrainerState: Equatable, Sendable {
    enum ExerciseMode: Equatable, Sendable {
        case singleNaturalTarget
        case positionPrompt
        case quarterNoteSequence(QuarterNoteSequenceSpec)
    }

    enum IgnoreReason: Equatable, Sendable {
        case nonEndedPhase(FretboardEventPhase)
        case missingHitCell
        case unresolvedHitPitch(FretboardCell)
    }

    struct Evaluation: Equatable, Sendable {
        var targetPitchClass: PitchClass
        var selectedCell: FretboardCell
        var selectedPitch: NotePitch
        var isCorrect: Bool
        var nextTargetPitchClass: PitchClass

        var selectedPitchClass: PitchClass {
            selectedPitch.pitchClass
        }

        var didAdvanceTarget: Bool {
            isCorrect
        }

        func debugSummary() -> String {
            let resultText = isCorrect ? "correct" : "wrong"
            return "[FretboardTrainer] target=\(targetPitchClass.displayText()) selected=\(selectedPitch.displayText()) selectedClass=\(selectedPitchClass.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret) result=\(resultText) next=\(nextTargetPitchClass.displayText())"
        }
    }

    enum EventResult: Equatable, Sendable {
        case ignored(IgnoreReason)
        case evaluated(Evaluation)
    }

    enum SingleCoverageIgnoreReason: Equatable, Sendable {
        case nonEndedPhase(FretboardEventPhase)
        case missingHitCell
        case unresolvedHitPitch(FretboardCell)
        case completedSession
    }

    enum SingleCoverageHitKind: Equatable, Sendable {
        case correctNew
        case correctRepeat
        case wrong

        var isCorrect: Bool {
            switch self {
            case .correctNew, .correctRepeat:
                return true
            case .wrong:
                return false
            }
        }

        var didIncreaseCoverage: Bool {
            self == .correctNew
        }

        var debugName: String {
            switch self {
            case .correctNew:
                return "correctNew"
            case .correctRepeat:
                return "correctRepeat"
            case .wrong:
                return "wrong"
            }
        }
    }

    struct SingleCoverageSession: Equatable, Sendable {
        var targetPitchClass: PitchClass
        var requiredCells: Set<FretboardCell>
        var visitedCells: Set<FretboardCell>

        init(
            targetPitchClass: PitchClass,
            requiredCells: Set<FretboardCell>,
            visitedCells: Set<FretboardCell> = []
        ) {
            precondition(
                visitedCells.isSubset(of: requiredCells),
                "Single coverage visited cells must stay within the required cells."
            )
            self.targetPitchClass = targetPitchClass
            self.requiredCells = requiredCells
            self.visitedCells = visitedCells
        }

        var totalCount: Int {
            requiredCells.count
        }

        var visitedCount: Int {
            visitedCells.count
        }

        var remainingCount: Int {
            max(totalCount - visitedCount, 0)
        }

        var remainingCells: Set<FretboardCell> {
            requiredCells.subtracting(visitedCells)
        }

        var isCompleted: Bool {
            remainingCells.isEmpty
        }
    }

    struct SingleCoverageEvaluation: Equatable, Sendable {
        var targetPitchClass: PitchClass
        var selectedCell: FretboardCell
        var selectedPitch: NotePitch
        var hitKind: SingleCoverageHitKind
        var visitedCount: Int
        var totalCount: Int
        var nextTargetPitchClass: PitchClass

        var selectedPitchClass: PitchClass {
            selectedPitch.pitchClass
        }

        var isCorrect: Bool {
            hitKind.isCorrect
        }

        var didIncreaseCoverage: Bool {
            hitKind.didIncreaseCoverage
        }

        var remainingCount: Int {
            max(totalCount - visitedCount, 0)
        }

        var isCoverageCompleted: Bool {
            visitedCount >= totalCount
        }

        var didAdvanceTarget: Bool {
            nextTargetPitchClass != targetPitchClass
        }

        func debugSummary() -> String {
            let resultText = isCorrect ? "correct" : "wrong"
            let stateText = isCoverageCompleted ? "completed" : "inProgress"
            return "[SingleCoverage] target=\(targetPitchClass.displayText()) selected=\(selectedPitch.displayText()) selectedClass=\(selectedPitchClass.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret) hit=\(hitKind.debugName) result=\(resultText) progress=\(visitedCount)/\(totalCount) remaining=\(remainingCount) next=\(nextTargetPitchClass.displayText()) state=\(stateText)"
        }
    }

    enum SingleCoverageAnswerResult: Equatable, Sendable {
        case ignored(SingleCoverageIgnoreReason)
        case evaluated(SingleCoverageEvaluation)
    }

    struct PositionPromptSession: Equatable, Sendable {
        struct SchedulingState: Equatable, Sendable {
            struct CandidatePoolSignature: Equatable, Sendable {
                var tuning: InstrumentTuning
                var maxFret: Int
                var filter: PositionPromptCandidateFilter
                var availableStringIndices: Set<Int>
            }

            var remainingStringsInRound: Set<Int>
            var cellHitCounts: [FretboardCell: Int]
            var candidatePoolSignature: CandidatePoolSignature

            init(
                remainingStringsInRound: Set<Int>,
                cellHitCounts: [FretboardCell: Int],
                candidatePoolSignature: CandidatePoolSignature
            ) {
                let invalidRemainingStrings = remainingStringsInRound.subtracting(
                    candidatePoolSignature.availableStringIndices
                )
                precondition(
                    invalidRemainingStrings.isEmpty,
                    "Position prompt scheduling remaining strings must stay within the current candidate pool."
                )
                precondition(
                    cellHitCounts.values.allSatisfy { $0 > 0 },
                    "Position prompt scheduling hit counts must stay positive."
                )
                self.remainingStringsInRound = remainingStringsInRound
                self.cellHitCounts = cellHitCounts
                self.candidatePoolSignature = candidatePoolSignature
            }

            func hitCount(for cell: FretboardCell) -> Int {
                cellHitCounts[cell, default: 0]
            }

            static func initial(
                promptCell: FretboardCell,
                candidatePoolSignature: CandidatePoolSignature
            ) -> SchedulingState {
                SchedulingState(
                    remainingStringsInRound: candidatePoolSignature.availableStringIndices
                        .subtracting([promptCell.stringIndex]),
                    cellHitCounts: [promptCell: 1],
                    candidatePoolSignature: candidatePoolSignature
                )
            }
        }

        var promptCell: FretboardCell
        var promptPitchClass: PitchClass
        var schedulingState: SchedulingState

        init(
            promptCell: FretboardCell,
            promptPitchClass: PitchClass,
            schedulingState: SchedulingState
        ) {
            precondition(
                promptPitchClass.isNatural,
                "Position prompt session pitch class must be a natural note."
            )
            precondition(
                schedulingState.candidatePoolSignature.availableStringIndices.contains(
                    promptCell.stringIndex
                ),
                "Position prompt session prompt string must stay within the current candidate pool."
            )
            precondition(
                !schedulingState.remainingStringsInRound.contains(
                    promptCell.stringIndex
                ),
                "Position prompt scheduling should treat the current prompt string as consumed for the active round."
            )
            precondition(
                schedulingState.hitCount(for: promptCell) > 0,
                "Position prompt scheduling must record at least one hit for the current prompt cell."
            )
            self.promptCell = promptCell
            self.promptPitchClass = promptPitchClass
            self.schedulingState = schedulingState
        }
    }

    struct PositionPromptEvaluation: Equatable, Sendable {
        var promptCell: FretboardCell
        var expectedPitchClass: PitchClass
        var answeredPitchClass: PitchClass
        var nextPromptCell: FretboardCell
        var nextPromptPitchClass: PitchClass

        var isCorrect: Bool {
            answeredPitchClass == expectedPitchClass
        }

        var didAdvancePrompt: Bool {
            isCorrect
        }

        var didChangePromptCell: Bool {
            nextPromptCell != promptCell
        }

        func debugSummary() -> String {
            let resultText = isCorrect ? "correct" : "wrong"
            let nextCellText = "string=\(nextPromptCell.stringIndex) fret=\(nextPromptCell.fret)"
            return "[PositionPrompt] prompt=\(expectedPitchClass.displayText()) string=\(promptCell.stringIndex) fret=\(promptCell.fret) answered=\(answeredPitchClass.displayText()) result=\(resultText) next=\(nextPromptPitchClass.displayText()) \(nextCellText)"
        }
    }

    enum PositionPromptAnswerResult: Equatable, Sendable {
        case evaluated(PositionPromptEvaluation)
    }

    struct QuarterNoteSequenceSpec: Equatable, Sendable {
        var clef: StaffClef
        var noteCount: Int
        var includesAccidentals: Bool

        init(
            clef: StaffClef,
            noteCount: Int,
            includesAccidentals: Bool
        ) {
            precondition(
                noteCount > 0,
                "Quarter-note sequence note count must be greater than zero."
            )
            self.clef = clef
            self.noteCount = noteCount
            self.includesAccidentals = includesAccidentals
        }
    }

    struct QuarterNoteSequencePrompt: Equatable, Sendable {
        var spec: QuarterNoteSequenceSpec
        private(set) var generatedSequence: GeneratedNoteSequence

        init(
            spec: QuarterNoteSequenceSpec,
            generatedSequence: GeneratedNoteSequence
        ) {
            precondition(
                generatedSequence.clef == spec.clef,
                "Quarter-note sequence generated sequence clef must match the spec clef."
            )
            precondition(
                generatedSequence.score.keySignature == .natural,
                "Quarter-note sequence score should use a natural key signature."
            )
            precondition(
                generatedSequence.noteCount == spec.noteCount,
                "Quarter-note sequence generated sequence note count must match the spec."
            )
            precondition(
                generatedSequence.notes.allSatisfy { $0.duration == .quarter },
                "Quarter-note sequence score should only contain quarter notes."
            )
            precondition(
                generatedSequence.answerPitchClasses.count == generatedSequence.notes.count,
                "Quarter-note sequence answers must align with the generated score."
            )
            if !spec.includesAccidentals {
                precondition(
                    generatedSequence.answerPitchClasses.allSatisfy(\.isNatural),
                    "Quarter-note sequence without accidentals must only contain natural pitches."
                )
            }
            self.spec = spec
            self.generatedSequence = generatedSequence
        }

        var score: StaffScore {
            generatedSequence.score
        }

        var expectedPitchClasses: [PitchClass] {
            generatedSequence.answerPitchClasses
        }

        var displayPitchClasses: [PitchClass] {
            generatedSequence.displayPitchClasses
        }

        var notes: [StaffScoreNote] {
            generatedSequence.notes
        }
    }

    struct QuarterNoteSequenceSession: Equatable, Sendable {
        var generatedSequence: GeneratedNoteSequence
        var currentIndex: Int

        init(
            generatedSequence: GeneratedNoteSequence,
            currentIndex: Int = 0
        ) {
            precondition(
                currentIndex >= 0 && currentIndex <= generatedSequence.noteCount,
                "Quarter-note sequence session index must stay within the sequence range."
            )
            self.generatedSequence = generatedSequence
            self.currentIndex = currentIndex
        }

        var totalCount: Int {
            generatedSequence.noteCount
        }

        var answeredCount: Int {
            currentIndex
        }

        var remainingCount: Int {
            max(totalCount - currentIndex, 0)
        }

        var isCompleted: Bool {
            currentIndex >= totalCount
        }

        var currentItem: GeneratedNoteSequenceItem? {
            guard !isCompleted else {
                return nil
            }

            return generatedSequence.items[currentIndex]
        }

        var currentExpectedPitchClass: PitchClass? {
            currentItem?.answerPitchClass
        }
    }

    enum QuarterNoteSequenceIgnoreReason: Equatable, Sendable {
        case completedSession
    }

    struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
        var expectedItem: GeneratedNoteSequenceItem
        var answeredPitchClass: PitchClass
        var answeredIndex: Int
        var nextIndex: Int
        var totalCount: Int

        var expectedPitchClass: PitchClass {
            expectedItem.answerPitchClass
        }

        var expectedWrittenPitch: StaffPitch {
            expectedItem.writtenPitch
        }

        var isCorrect: Bool {
            answeredPitchClass == expectedPitchClass
        }

        var didAdvanceIndex: Bool {
            isCorrect
        }

        var isSequenceCompleted: Bool {
            nextIndex >= totalCount
        }

        var remainingCount: Int {
            max(totalCount - nextIndex, 0)
        }

        func debugSummary() -> String {
            let resultText = isCorrect ? "correct" : "wrong"
            let stateText = isSequenceCompleted ? "completed" : "inProgress"
            return "[QuarterNoteSequence] step=\(answeredIndex + 1)/\(totalCount) expected=\(expectedPitchClass.displayText()) written=\(expectedWrittenPitch.scientificName) answered=\(answeredPitchClass.displayText()) result=\(resultText) nextIndex=\(nextIndex) remaining=\(remainingCount) state=\(stateText)"
        }
    }

    enum QuarterNoteSequenceAnswerResult: Equatable, Sendable {
        case ignored(QuarterNoteSequenceIgnoreReason)
        case evaluated(QuarterNoteSequenceEvaluation)
    }

    struct Prompt: Equatable, Sendable {
        var targetPitchClass: PitchClass

        var displayText: String {
            targetPitchClass.displayText()
        }
    }

    private(set) var mode: ExerciseMode
    private(set) var targetPitchClass: PitchClass
    private(set) var generatedQuarterNoteSequence: GeneratedNoteSequence?

    // 兼容当前单目标自然音训练链路；
    // 四分音序列模式的共享真相源为 generatedQuarterNoteSequence，
    // quarterNoteSequencePrompt 仅保留为兼容适配层。
    var prompt: Prompt {
        Prompt(targetPitchClass: targetPitchClass)
    }

    var quarterNoteSequencePrompt: QuarterNoteSequencePrompt? {
        guard case let .quarterNoteSequence(spec) = mode,
              let generatedQuarterNoteSequence else {
            return nil
        }

        return QuarterNoteSequencePrompt(
            spec: spec,
            generatedSequence: generatedQuarterNoteSequence
        )
    }

    init(targetPitchClass: PitchClass) {
        precondition(
            targetPitchClass.isNatural,
            "Target pitch class must be a natural note."
        )
        self.mode = .singleNaturalTarget
        self.targetPitchClass = targetPitchClass
        generatedQuarterNoteSequence = nil
    }

    init(quarterNoteSequenceSpec spec: QuarterNoteSequenceSpec) {
        mode = .quarterNoteSequence(spec)
        // 保留一个稳定的 legacy target 值，避免当前单目标 API 在未来迁移完成前失去初始化基线。
        targetPitchClass = .c
        generatedQuarterNoteSequence = nil
    }

    init(positionPromptMode: Void) {
        mode = .positionPrompt
        // 位置题模式当前不消费 legacy target 文本；
        // 这里保留一个稳定自然音占位值，避免旧接口在迁移完成前失去初始化基线。
        targetPitchClass = .c
        generatedQuarterNoteSequence = nil
    }

    init() {
        var generator = SystemRandomNumberGenerator()
        self.init(randomUsing: &generator)
    }

    init<R: RandomNumberGenerator>(randomUsing generator: inout R) {
        self.init(
            targetPitchClass: Self.randomNaturalPitchClass(using: &generator)
        )
    }

    mutating func generateQuarterNoteSequence() -> GeneratedNoteSequence {
        var generator = SystemRandomNumberGenerator()
        return generateQuarterNoteSequence(using: &generator)
    }

    mutating func generateQuarterNoteSequence<R: RandomNumberGenerator>(
        using generator: inout R
    ) -> GeneratedNoteSequence {
        let spec = requireQuarterNoteSequenceSpec()
        let generatedSequence = StaffQuarterNoteSequenceGenerator().makeSequence(
            spec: spec.staffGeneratorSpec,
            using: &generator
        )
        generatedQuarterNoteSequence = generatedSequence
        return generatedSequence
    }

    mutating func generateQuarterNoteSequence(
        for spec: QuarterNoteSequenceSpec
    ) -> GeneratedNoteSequence {
        mode = .quarterNoteSequence(spec)
        generatedQuarterNoteSequence = nil
        return generateQuarterNoteSequence()
    }

    mutating func generateQuarterNoteSequencePrompt() -> QuarterNoteSequencePrompt {
        var generator = SystemRandomNumberGenerator()
        return generateQuarterNoteSequencePrompt(using: &generator)
    }

    mutating func generateQuarterNoteSequencePrompt<R: RandomNumberGenerator>(
        using generator: inout R
    ) -> QuarterNoteSequencePrompt {
        let spec = requireQuarterNoteSequenceSpec()
        let generatedSequence = generateQuarterNoteSequence(using: &generator)
        return QuarterNoteSequencePrompt(
            spec: spec,
            generatedSequence: generatedSequence
        )
    }

    mutating func generateQuarterNoteSequencePrompt(
        for spec: QuarterNoteSequenceSpec
    ) -> QuarterNoteSequencePrompt {
        let generatedSequence = generateQuarterNoteSequence(for: spec)
        return QuarterNoteSequencePrompt(
            spec: spec,
            generatedSequence: generatedSequence
        )
    }

    func makeQuarterNoteSequenceSession() -> QuarterNoteSequenceSession {
        QuarterNoteSequenceSession(
            generatedSequence: requireCurrentQuarterNoteSequence()
        )
    }

    func makeSingleCoverageSession(
        configuration: FretboardConfiguration
    ) -> SingleCoverageSession {
        requireSingleNaturalTargetMode()
        return SingleCoverageSession(
            targetPitchClass: targetPitchClass,
            requiredCells: Set(configuration.cells(for: targetPitchClass))
        )
    }

    func makePositionPromptSession(
        configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter
    ) -> PositionPromptSession {
        var generator = SystemRandomNumberGenerator()
        return makePositionPromptSession(
            configuration: configuration,
            filter: filter,
            using: &generator
        )
    }

    func makePositionPromptSession(
        configuration: FretboardConfiguration,
        allowedFrets: Set<Int>
    ) -> PositionPromptSession {
        makePositionPromptSession(
            configuration: configuration,
            filter: .frets(allowedFrets)
        )
    }

    func makePositionPromptSession<R: RandomNumberGenerator>(
        configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
        using generator: inout R
    ) -> PositionPromptSession {
        let normalizedFilter = Self.normalizedPositionPromptFilter(filter)
        let filterText = Self.positionPromptFilterDebugText(normalizedFilter)
        print("[PositionPrompt][Trainer] makePositionPromptSession begin \(filterText)")
        requirePositionPromptMode()
        let session = Self.makePositionPromptSession(
            configuration: configuration,
            filter: normalizedFilter,
            excluding: nil,
            carryingOver: nil,
            using: &generator
        )
        print(
            "[PositionPrompt][Trainer] makePositionPromptSession end \(filterText) prompt=string=\(session.promptCell.stringIndex) fret=\(session.promptCell.fret) pitch=\(session.promptPitchClass.displayText()) \(Self.positionPromptSchedulingDebugText(session.schedulingState, promptCell: session.promptCell))"
        )
        return session
    }

    func makePositionPromptSession<R: RandomNumberGenerator>(
        configuration: FretboardConfiguration,
        allowedFrets: Set<Int>,
        using generator: inout R
    ) -> PositionPromptSession {
        makePositionPromptSession(
            configuration: configuration,
            filter: .frets(allowedFrets),
            using: &generator
        )
    }

    mutating func handleSingleCoverageHit(
        _ hitResult: FretboardHitResult,
        configuration: FretboardConfiguration,
        session: inout SingleCoverageSession
    ) -> SingleCoverageAnswerResult {
        var generator = SystemRandomNumberGenerator()
        return handleSingleCoverageHit(
            hitResult,
            configuration: configuration,
            session: &session,
            using: &generator
        )
    }

    mutating func handleSingleCoverageHit<R: RandomNumberGenerator>(
        _ hitResult: FretboardHitResult,
        configuration: FretboardConfiguration,
        session: inout SingleCoverageSession,
        using generator: inout R
    ) -> SingleCoverageAnswerResult {
        requireSingleNaturalTargetMode()
        guard !session.isCompleted else {
            return .ignored(.completedSession)
        }

        validateSingleCoverageSession(
            session,
            configuration: configuration
        )

        guard hitResult.phase == .ended else {
            return .ignored(.nonEndedPhase(hitResult.phase))
        }

        guard let selectedCell = hitResult.cell else {
            return .ignored(.missingHitCell)
        }

        return handleSingleCoverageAnswer(
            selectedCell,
            configuration: configuration,
            session: &session,
            using: &generator
        )
    }

    mutating func handleSingleCoverageAnswer(
        _ selectedCell: FretboardCell,
        configuration: FretboardConfiguration,
        session: inout SingleCoverageSession
    ) -> SingleCoverageAnswerResult {
        var generator = SystemRandomNumberGenerator()
        return handleSingleCoverageAnswer(
            selectedCell,
            configuration: configuration,
            session: &session,
            using: &generator
        )
    }

    mutating func handleSingleCoverageAnswer<R: RandomNumberGenerator>(
        _ selectedCell: FretboardCell,
        configuration: FretboardConfiguration,
        session: inout SingleCoverageSession,
        using generator: inout R
    ) -> SingleCoverageAnswerResult {
        requireSingleNaturalTargetMode()
        guard !session.isCompleted else {
            return .ignored(.completedSession)
        }

        validateSingleCoverageSession(
            session,
            configuration: configuration
        )

        guard let selectedPitch = configuration.notePitch(for: selectedCell) else {
            return .ignored(.unresolvedHitPitch(selectedCell))
        }

        let answeredTargetPitchClass = targetPitchClass
        let hitKind: SingleCoverageHitKind
        if selectedPitch.pitchClass == answeredTargetPitchClass {
            precondition(
                session.requiredCells.contains(selectedCell),
                "Single coverage correct pitch must belong to the session required cells."
            )
            if session.visitedCells.contains(selectedCell) {
                hitKind = .correctRepeat
            } else {
                session.visitedCells.insert(selectedCell)
                hitKind = .correctNew
            }
        } else {
            hitKind = .wrong
        }

        let nextTargetPitchClass: PitchClass
        if session.isCompleted {
            nextTargetPitchClass = advanceToNextTarget(using: &generator)
        } else {
            nextTargetPitchClass = answeredTargetPitchClass
        }

        return .evaluated(
            SingleCoverageEvaluation(
                targetPitchClass: answeredTargetPitchClass,
                selectedCell: selectedCell,
                selectedPitch: selectedPitch,
                hitKind: hitKind,
                visitedCount: session.visitedCount,
                totalCount: session.totalCount,
                nextTargetPitchClass: nextTargetPitchClass
            )
        )
    }

    mutating func handleQuarterNoteSequenceAnswer(
        _ pitchClass: PitchClass,
        session: inout QuarterNoteSequenceSession
    ) -> QuarterNoteSequenceAnswerResult {
        let generatedSequence = requireCurrentQuarterNoteSequence()
        precondition(
            session.generatedSequence == generatedSequence,
            "Quarter-note sequence session sequence must match the current trainer sequence."
        )

        guard let expectedItem = session.currentItem else {
            return .ignored(.completedSession)
        }

        let answeredIndex = session.currentIndex
        let expectedPitchClass = expectedItem.answerPitchClass
        let isCorrect = pitchClass == expectedPitchClass
        let nextIndex = isCorrect ? answeredIndex + 1 : answeredIndex
        if isCorrect {
            session.currentIndex = nextIndex
        }

        return .evaluated(
            QuarterNoteSequenceEvaluation(
                expectedItem: expectedItem,
                answeredPitchClass: pitchClass,
                answeredIndex: answeredIndex,
                nextIndex: nextIndex,
                totalCount: session.totalCount
            )
        )
    }

    mutating func handlePositionPromptAnswer(
        _ pitchClass: PitchClass,
        configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
        session: inout PositionPromptSession
    ) -> PositionPromptAnswerResult {
        var generator = SystemRandomNumberGenerator()
        return handlePositionPromptAnswer(
            pitchClass,
            configuration: configuration,
            filter: filter,
            session: &session,
            using: &generator
        )
    }

    mutating func handlePositionPromptAnswer(
        _ pitchClass: PitchClass,
        configuration: FretboardConfiguration,
        allowedFrets: Set<Int>,
        session: inout PositionPromptSession
    ) -> PositionPromptAnswerResult {
        handlePositionPromptAnswer(
            pitchClass,
            configuration: configuration,
            filter: .frets(allowedFrets),
            session: &session
        )
    }

    mutating func handlePositionPromptAnswer(
        _ event: ExerciseAnswerEvent,
        configuration: FretboardConfiguration,
        answerRule: PositionPromptAnswerRule,
        filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
        session: inout PositionPromptSession
    ) -> PositionPromptAnswerResult? {
        guard let pitchClass = Self.resolvedPositionPromptAnswerPitchClass(
            from: event,
            configuration: configuration,
            answerRule: answerRule
        ) else {
            return nil
        }

        return handlePositionPromptAnswer(
            pitchClass,
            configuration: configuration,
            filter: filter,
            session: &session
        )
    }

    mutating func handlePositionPromptAnswer<R: RandomNumberGenerator>(
        _ pitchClass: PitchClass,
        configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
        session: inout PositionPromptSession,
        using generator: inout R
    ) -> PositionPromptAnswerResult {
        requirePositionPromptMode()
        validatePositionPromptSession(
            session,
            configuration: configuration
        )

        let promptCell = session.promptCell
        let expectedPitchClass = session.promptPitchClass
        let isCorrect = pitchClass == expectedPitchClass

        let nextSession: PositionPromptSession
        if isCorrect {
            nextSession = Self.makePositionPromptSession(
                configuration: configuration,
                filter: filter,
                excluding: promptCell,
                carryingOver: session.schedulingState,
                using: &generator
            )
            session = nextSession
        } else {
            nextSession = session
        }
        let resultText = isCorrect ? "correct" : "wrong"
        print(
            "[PositionPrompt][Trainer] answer result=\(resultText) expected=\(expectedPitchClass.displayText()) answered=\(pitchClass.displayText()) current=string=\(promptCell.stringIndex) fret=\(promptCell.fret) next=string=\(nextSession.promptCell.stringIndex) fret=\(nextSession.promptCell.fret) \(Self.positionPromptSchedulingDebugText(nextSession.schedulingState, promptCell: nextSession.promptCell))"
        )

        return .evaluated(
            PositionPromptEvaluation(
                promptCell: promptCell,
                expectedPitchClass: expectedPitchClass,
                answeredPitchClass: pitchClass,
                nextPromptCell: nextSession.promptCell,
                nextPromptPitchClass: nextSession.promptPitchClass
            )
        )
    }

    mutating func handlePositionPromptAnswer<R: RandomNumberGenerator>(
        _ pitchClass: PitchClass,
        configuration: FretboardConfiguration,
        allowedFrets: Set<Int>,
        session: inout PositionPromptSession,
        using generator: inout R
    ) -> PositionPromptAnswerResult {
        handlePositionPromptAnswer(
            pitchClass,
            configuration: configuration,
            filter: .frets(allowedFrets),
            session: &session,
            using: &generator
        )
    }

    static func resolvedPitchClass(
        from event: ExerciseAnswerEvent,
        configuration: FretboardConfiguration
    ) -> PitchClass? {
        switch event.payload {
        case let .pitchClass(pitchClass):
            return pitchClass
        case let .fretboardCell(cell):
            return configuration.notePitch(for: cell)?.pitchClass
        }
    }

    static func resolvedPositionPromptAnswerPitchClass(
        from event: ExerciseAnswerEvent,
        configuration: FretboardConfiguration,
        answerRule: PositionPromptAnswerRule
    ) -> PitchClass? {
        switch answerRule {
        case .samePitchClass:
            return resolvedPitchClass(
                from: event,
                configuration: configuration
            )
        }
    }

    mutating func advanceToNextTarget() -> PitchClass {
        var generator = SystemRandomNumberGenerator()
        return advanceToNextTarget(using: &generator)
    }

    mutating func advanceToNextTarget<R: RandomNumberGenerator>(
        using generator: inout R
    ) -> PitchClass {
        requireSingleNaturalTargetMode()
        // 答对后避免立刻重复同一题目，让外层更容易感知题目已经推进。
        let nextTargetPitchClass = Self.randomNaturalPitchClass(
            excluding: targetPitchClass,
            using: &generator
        )
        targetPitchClass = nextTargetPitchClass
        return nextTargetPitchClass
    }

    mutating func handle(
        hitResult: FretboardHitResult,
        configuration: FretboardConfiguration
    ) -> EventResult {
        var generator = SystemRandomNumberGenerator()
        return handle(
            hitResult: hitResult,
            configuration: configuration,
            using: &generator
        )
    }

    mutating func handle<R: RandomNumberGenerator>(
        hitResult: FretboardHitResult,
        configuration: FretboardConfiguration,
        using generator: inout R
    ) -> EventResult {
        requireSingleNaturalTargetMode()
        guard hitResult.phase == .ended else {
            return .ignored(.nonEndedPhase(hitResult.phase))
        }

        guard let selectedCell = hitResult.cell else {
            return .ignored(.missingHitCell)
        }

        guard let selectedPitch = configuration.notePitch(for: selectedCell) else {
            return .ignored(.unresolvedHitPitch(selectedCell))
        }

        let answeredTargetPitchClass = targetPitchClass
        let isCorrect = selectedPitch.pitchClass == answeredTargetPitchClass
        let nextTargetPitchClass: PitchClass
        if isCorrect {
            nextTargetPitchClass = advanceToNextTarget(using: &generator)
        } else {
            nextTargetPitchClass = answeredTargetPitchClass
        }

        return .evaluated(
            Evaluation(
                targetPitchClass: answeredTargetPitchClass,
                selectedCell: selectedCell,
                selectedPitch: selectedPitch,
                isCorrect: isCorrect,
                nextTargetPitchClass: nextTargetPitchClass
            )
        )
    }

    private static func randomNaturalPitchClass<R: RandomNumberGenerator>(
        excluding excludedPitchClass: PitchClass? = nil,
        using generator: inout R
    ) -> PitchClass {
        let candidates = PitchClass.naturalCasesInOrder.filter { pitchClass in
            pitchClass != excludedPitchClass
        }
        let resolvedCandidates = candidates.isEmpty
            ? PitchClass.naturalCasesInOrder
            : candidates

        guard let targetPitchClass = resolvedCandidates.randomElement(using: &generator) else {
            preconditionFailure("Natural pitch class candidates should never be empty.")
        }

        return targetPitchClass
    }

    private static func makePositionPromptSession<R: RandomNumberGenerator>(
        configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter,
        excluding excludedCell: FretboardCell?,
        carryingOver schedulingState: PositionPromptSession.SchedulingState?,
        using generator: inout R
    ) -> PositionPromptSession {
        let normalizedFilter = normalizedPositionPromptFilter(filter)
        let excludedCellText: String
        if let excludedCell {
            excludedCellText = "string=\(excludedCell.stringIndex) fret=\(excludedCell.fret)"
        } else {
            excludedCellText = "nil"
        }
        let filterText = positionPromptFilterDebugText(normalizedFilter)
        print(
            "[PositionPrompt][Trainer] selectPrompt begin \(filterText) excluded=\(excludedCellText)"
        )
        let candidates = positionPromptCandidateCells(
            in: configuration,
            filter: normalizedFilter
        )
        let candidatePoolSignature = positionPromptCandidatePoolSignature(
            in: configuration,
            filter: normalizedFilter,
            candidateCells: candidates
        )
        print(
            "[PositionPrompt][Trainer] selectPrompt candidates count=\(candidates.count) \(positionPromptCandidatePoolDebugText(candidatePoolSignature))"
        )
        let candidatesByString = positionPromptCandidateCellsByString(candidates)
        let selection = selectPositionPromptCell(
            candidatesByString: candidatesByString,
            candidatePoolSignature: candidatePoolSignature,
            excluding: excludedCell,
            carryingOver: schedulingState,
            using: &generator
        )
        let promptCell = selection.promptCell
        print(
            "[PositionPrompt][Trainer] selectPrompt selectedCell string=\(promptCell.stringIndex) fret=\(promptCell.fret)"
        )
        guard let promptPitchClass = configuration.pitchClass(for: promptCell) else {
            preconditionFailure(
                "Position prompt candidate cell must resolve to a pitch class."
            )
        }
        print(
            "[PositionPrompt][Trainer] selectPrompt resolvedPitchClass=\(promptPitchClass.displayText())"
        )
        precondition(
            promptPitchClass.isNatural,
            "Position prompt candidate pitch class must be natural."
        )

        let session = PositionPromptSession(
            promptCell: promptCell,
            promptPitchClass: promptPitchClass,
            schedulingState: selection.schedulingState
        )
        print("[PositionPrompt][Trainer] selectPrompt end")
        return session
    }

    private static func positionPromptCandidateCells(
        in configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter
    ) -> [FretboardCell] {
        let normalizedFilter = normalizedPositionPromptFilter(filter)
        var cells: [FretboardCell] = []
        cells.reserveCapacity(configuration.stringCount * configuration.displayPositionCount)

        for stringIndex in 0..<configuration.stringCount {
            for fret in configuration.fretRange {
                let cell = FretboardCell(
                    stringIndex: stringIndex,
                    fret: fret
                )
                guard let pitchClass = configuration.pitchClass(for: cell),
                      pitchClass.isNatural else {
                    continue
                }
                switch normalizedFilter {
                case let .noteNames(selectedPitchClasses):
                    guard selectedPitchClasses.contains(pitchClass) else {
                        continue
                    }
                case let .frets(selectedFrets):
                    guard selectedFrets.contains(fret) else {
                        continue
                    }
                }
                cells.append(cell)
            }
        }

        return cells
    }

    private static func positionPromptCandidateCellsByString(
        _ candidateCells: [FretboardCell]
    ) -> [Int: [FretboardCell]] {
        var cellsByString: [Int: [FretboardCell]] = [:]
        cellsByString.reserveCapacity(candidateCells.count)

        for cell in candidateCells {
            cellsByString[cell.stringIndex, default: []].append(cell)
        }

        return cellsByString
    }

    static func positionPromptCandidatePoolSignature(
        in configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter
    ) -> PositionPromptSession.SchedulingState.CandidatePoolSignature {
        let normalizedFilter = normalizedPositionPromptFilter(filter)
        let candidateCells = positionPromptCandidateCells(
            in: configuration,
            filter: normalizedFilter
        )
        return positionPromptCandidatePoolSignature(
            in: configuration,
            filter: normalizedFilter,
            candidateCells: candidateCells
        )
    }

    private static func positionPromptCandidatePoolSignature(
        in configuration: FretboardConfiguration,
        filter: PositionPromptCandidateFilter,
        candidateCells: [FretboardCell]
    ) -> PositionPromptSession.SchedulingState.CandidatePoolSignature {
        PositionPromptSession.SchedulingState.CandidatePoolSignature(
            tuning: configuration.tuning,
            maxFret: configuration.maxFret,
            filter: filter,
            availableStringIndices: Set(candidateCells.map(\.stringIndex))
        )
    }

    private static func positionPromptOrderedStringText(
        _ stringIndices: Set<Int>
    ) -> String {
        let orderedStrings = stringIndices.sorted().map(String.init)
        return orderedStrings.isEmpty ? "none" : orderedStrings.joined(separator: ",")
    }

    private static func positionPromptCandidatePoolDebugText(
        _ signature: PositionPromptSession.SchedulingState.CandidatePoolSignature
    ) -> String {
        let tuningText = signature.tuning.openStringsLowToHigh.map {
            $0.displayText(showsOctave: false)
        }.joined(separator: ",")
        let filterText = positionPromptFilterDebugText(signature.filter)
        let availableStrings = positionPromptOrderedStringText(
            signature.availableStringIndices
        )
        return "poolStrings=\(availableStrings) stringCount=\(signature.tuning.stringCount) maxFret=\(signature.maxFret) tuning=\(tuningText) \(filterText)"
    }

    private static func positionPromptSchedulingDebugText(
        _ schedulingState: PositionPromptSession.SchedulingState,
        promptCell: FretboardCell? = nil
    ) -> String {
        let availableStrings =
            schedulingState.candidatePoolSignature.availableStringIndices
        let remainingStrings = schedulingState.remainingStringsInRound
        let consumedStrings = availableStrings.subtracting(remainingStrings)
        let totalStrings = availableStrings.count
        let roundProgress = "\(consumedStrings.count)/\(totalStrings)"
        let availableStringText = positionPromptOrderedStringText(
            availableStrings
        )
        let remainingStringText = positionPromptOrderedStringText(
            remainingStrings
        )
        let consumedStringText = positionPromptOrderedStringText(
            consumedStrings
        )
        let promptHitCountText: String
        if let promptCell {
            promptHitCountText = String(
                schedulingState.hitCount(for: promptCell)
            )
        } else {
            promptHitCountText = "n/a"
        }
        return "roundProgress=\(roundProgress) availableStrings=\(availableStringText) consumedStrings=\(consumedStringText) remainingStrings=\(remainingStringText) trackedCells=\(schedulingState.cellHitCounts.count) promptHits=\(promptHitCountText)"
    }

    private static func selectPositionPromptCell<R: RandomNumberGenerator>(
        candidatesByString: [Int: [FretboardCell]],
        candidatePoolSignature: PositionPromptSession.SchedulingState.CandidatePoolSignature,
        excluding excludedCell: FretboardCell?,
        carryingOver schedulingState: PositionPromptSession.SchedulingState?,
        using generator: inout R
    ) -> (
        promptCell: FretboardCell,
        schedulingState: PositionPromptSession.SchedulingState
    ) {
        let seedState = seededPositionPromptSchedulingState(
            carryingOver: schedulingState,
            candidatePoolSignature: candidatePoolSignature
        )
        let activeRoundStrings = seedState.remainingStringsInRound.isEmpty
            ? candidatePoolSignature.availableStringIndices
            : seedState.remainingStringsInRound
        let orderedActiveRoundStrings = activeRoundStrings.sorted()
        guard let selectedStringIndex = orderedActiveRoundStrings.randomElement(
            using: &generator
        ) else {
            preconditionFailure(
                "Position prompt candidate strings should never be empty."
            )
        }
        guard let stringCandidates = candidatesByString[selectedStringIndex],
              !stringCandidates.isEmpty else {
            preconditionFailure(
                "Position prompt selected string should always have at least one candidate cell."
            )
        }

        let minimumHitCount = stringCandidates.map {
            seedState.hitCount(for: $0)
        }.min() ?? 0
        let preferredCandidates = stringCandidates.filter {
            seedState.hitCount(for: $0) == minimumHitCount
        }
        let filteredPreferredCandidates = preferredCandidates.filter {
            $0 != excludedCell
        }
        let resolvedCandidates = filteredPreferredCandidates.isEmpty
            ? preferredCandidates
            : filteredPreferredCandidates
        let excludedCellWasFiltered = filteredPreferredCandidates.count
            != preferredCandidates.count
        print(
            "[PositionPrompt][Trainer] selectPrompt schedulingBefore \(positionPromptSchedulingDebugText(seedState)) activeRoundStrings=\(positionPromptOrderedStringText(activeRoundStrings)) selectedString=\(selectedStringIndex) stringCandidates=\(stringCandidates.count) minimumHitCount=\(minimumHitCount) minimumHitCandidateCount=\(preferredCandidates.count) resolvedCandidateCount=\(resolvedCandidates.count) excludedApplied=\(excludedCellWasFiltered)"
        )
        guard let promptCell = resolvedCandidates.randomElement(using: &generator) else {
            preconditionFailure(
                "Position prompt resolved candidates should never be empty."
            )
        }

        var nextHitCounts = seedState.cellHitCounts
        nextHitCounts[promptCell, default: 0] += 1
        let nextSchedulingState = PositionPromptSession.SchedulingState(
            remainingStringsInRound: activeRoundStrings.subtracting([
                selectedStringIndex
            ]),
            cellHitCounts: nextHitCounts,
            candidatePoolSignature: candidatePoolSignature
        )
        print(
            "[PositionPrompt][Trainer] selectPrompt schedulingAfter \(positionPromptSchedulingDebugText(nextSchedulingState, promptCell: promptCell))"
        )
        return (
            promptCell: promptCell,
            schedulingState: nextSchedulingState
        )
    }

    private static func seededPositionPromptSchedulingState(
        carryingOver schedulingState: PositionPromptSession.SchedulingState?,
        candidatePoolSignature: PositionPromptSession.SchedulingState.CandidatePoolSignature
    ) -> PositionPromptSession.SchedulingState {
        guard let schedulingState,
              schedulingState.candidatePoolSignature == candidatePoolSignature else {
            // 候选池身份变化后，旧轮次与命中统计全部失效，重新从当前候选弦集合开始。
            let resetReason = schedulingState == nil
                ? "newSession"
                : "candidatePoolChanged"
            let resetState = PositionPromptSession.SchedulingState(
                remainingStringsInRound: candidatePoolSignature.availableStringIndices,
                cellHitCounts: [:],
                candidatePoolSignature: candidatePoolSignature
            )
            print(
                "[PositionPrompt][Trainer] selectPrompt seed reason=\(resetReason) \(positionPromptCandidatePoolDebugText(candidatePoolSignature)) \(positionPromptSchedulingDebugText(resetState))"
            )
            return resetState
        }
        print(
            "[PositionPrompt][Trainer] selectPrompt seed reason=reused \(positionPromptCandidatePoolDebugText(candidatePoolSignature)) \(positionPromptSchedulingDebugText(schedulingState))"
        )
        return schedulingState
    }

    private static func normalizedPositionPromptFilter(
        _ filter: PositionPromptCandidateFilter
    ) -> PositionPromptCandidateFilter {
        switch filter {
        case let .noteNames(selectedPitchClasses):
            let normalizedConfiguration = TrainerPositionPromptConfiguration(
                filterMode: .noteName,
                selectedPitchClasses: selectedPitchClasses
            )
            return .noteNames(normalizedConfiguration.selectedPitchClasses)
        case let .frets(selectedFrets):
            let normalizedConfiguration = TrainerPositionPromptConfiguration(
                filterMode: .fret,
                selectedFrets: selectedFrets
            )
            return .frets(normalizedConfiguration.selectedFrets)
        }
    }

    private static func positionPromptFilterDebugText(
        _ filter: PositionPromptCandidateFilter
    ) -> String {
        switch normalizedPositionPromptFilter(filter) {
        case let .noteNames(selectedPitchClasses):
            let orderedPitchClasses =
                TrainerPositionPromptConfiguration.supportedPitchClasses
                .filter { selectedPitchClasses.contains($0) }
                .map { $0.displayText() }
                .joined(separator: ",")
            return "filterMode=noteName noteNames=\(orderedPitchClasses)"
        case let .frets(selectedFrets):
            let orderedFrets = selectedFrets.sorted().map(String.init).joined(
                separator: ","
            )
            return "filterMode=fret frets=\(orderedFrets)"
        }
    }

    private func requireSingleNaturalTargetMode(
        _ function: StaticString = #function
    ) {
        guard case .singleNaturalTarget = mode else {
            preconditionFailure(
                "\(function) requires .singleNaturalTarget mode."
            )
        }
    }

    private func requirePositionPromptMode(
        _ function: StaticString = #function
    ) {
        guard case .positionPrompt = mode else {
            preconditionFailure(
                "\(function) requires .positionPrompt mode."
            )
        }
    }

    private func validateSingleCoverageSession(
        _ session: SingleCoverageSession,
        configuration: FretboardConfiguration,
        _ function: StaticString = #function
    ) {
        precondition(
            session.targetPitchClass == targetPitchClass,
            "\(function) single coverage session target must match the trainer target."
        )
        let expectedRequiredCells = Set(
            configuration.cells(for: targetPitchClass)
        )
        precondition(
            session.requiredCells == expectedRequiredCells,
            "\(function) single coverage session required cells must match the current configuration."
        )
        precondition(
            session.visitedCells.isSubset(of: session.requiredCells),
            "\(function) single coverage session visited cells must stay within the required cells."
        )
    }

    private func validatePositionPromptSession(
        _ session: PositionPromptSession,
        configuration: FretboardConfiguration,
        _ function: StaticString = #function
    ) {
        precondition(
            session.promptPitchClass.isNatural,
            "\(function) position prompt session pitch class must stay natural."
        )
        guard let resolvedPromptPitchClass = configuration.pitchClass(for: session.promptCell) else {
            preconditionFailure(
                "\(function) position prompt session cell must resolve to a pitch class."
            )
        }
        precondition(
            resolvedPromptPitchClass == session.promptPitchClass,
            "\(function) position prompt session pitch class must match the current configuration."
        )
        precondition(
            session.schedulingState.candidatePoolSignature.availableStringIndices.contains(
                session.promptCell.stringIndex
            ),
            "\(function) position prompt session prompt string must stay within the stored candidate pool."
        )
        precondition(
            !session.schedulingState.remainingStringsInRound.contains(
                session.promptCell.stringIndex
            ),
            "\(function) position prompt session current prompt string must already be consumed in the active round."
        )
        precondition(
            session.schedulingState.remainingStringsInRound.isSubset(
                of: session.schedulingState.candidatePoolSignature.availableStringIndices
            ),
            "\(function) position prompt session remaining strings must stay within the stored candidate pool."
        )
        precondition(
            session.schedulingState.cellHitCounts.values.allSatisfy { $0 > 0 },
            "\(function) position prompt session hit counts must stay positive."
        )
        precondition(
            session.schedulingState.hitCount(for: session.promptCell) > 0,
            "\(function) position prompt session current prompt cell must have recorded history."
        )
    }

    private func requireQuarterNoteSequenceSpec(
        _ function: StaticString = #function
    ) -> QuarterNoteSequenceSpec {
        guard case let .quarterNoteSequence(spec) = mode else {
            preconditionFailure(
                "\(function) requires .quarterNoteSequence mode."
            )
        }

        return spec
    }

    private func requireCurrentQuarterNoteSequence(
        _ function: StaticString = #function
    ) -> GeneratedNoteSequence {
        requireQuarterNoteSequenceSpec(function)

        guard let generatedQuarterNoteSequence else {
            preconditionFailure(
                "\(function) requires a generated quarter-note sequence."
            )
        }

        return generatedQuarterNoteSequence
    }
}

private extension FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
    var staffGeneratorSpec: StaffQuarterNoteSequenceGenerator.Spec {
        StaffQuarterNoteSequenceGenerator.Spec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals
        )
    }
}

//
//  FretboardNaturalNoteTrainer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

struct FretboardNaturalNoteTrainerState: Equatable, Sendable {
    enum ExerciseMode: Equatable, Sendable {
        case singleNaturalTarget
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
        var score: StaffScore
        var expectedPitchClasses: [PitchClass]

        init(
            spec: QuarterNoteSequenceSpec,
            score: StaffScore,
            expectedPitchClasses: [PitchClass]
        ) {
            precondition(
                score.clef == spec.clef,
                "Quarter-note sequence score clef must match the spec clef."
            )
            precondition(
                score.keySignature == .natural,
                "Quarter-note sequence score should use a natural key signature."
            )
            precondition(
                score.notes.count == spec.noteCount,
                "Quarter-note sequence score note count must match the spec."
            )
            precondition(
                score.notes.allSatisfy { $0.duration == .quarter },
                "Quarter-note sequence score should only contain quarter notes."
            )
            precondition(
                expectedPitchClasses.count == score.notes.count,
                "Quarter-note sequence answers must align with the generated score."
            )
            if !spec.includesAccidentals {
                precondition(
                    expectedPitchClasses.allSatisfy(\.isNatural),
                    "Quarter-note sequence without accidentals must only contain natural pitches."
                )
            }
            self.spec = spec
            self.score = score
            self.expectedPitchClasses = expectedPitchClasses
        }

        var notes: [StaffScoreNote] {
            score.notes
        }
    }

    struct QuarterNoteSequenceSession: Equatable, Sendable {
        var prompt: QuarterNoteSequencePrompt
        var currentIndex: Int

        init(
            prompt: QuarterNoteSequencePrompt,
            currentIndex: Int = 0
        ) {
            precondition(
                currentIndex >= 0 && currentIndex <= prompt.expectedPitchClasses.count,
                "Quarter-note sequence session index must stay within the prompt range."
            )
            self.prompt = prompt
            self.currentIndex = currentIndex
        }

        var totalCount: Int {
            prompt.expectedPitchClasses.count
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

        var currentExpectedPitchClass: PitchClass? {
            guard !isCompleted else {
                return nil
            }

            return prompt.expectedPitchClasses[currentIndex]
        }
    }

    enum QuarterNoteSequenceIgnoreReason: Equatable, Sendable {
        case completedSession
    }

    struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
        var expectedPitchClass: PitchClass
        var answeredPitchClass: PitchClass
        var answeredIndex: Int
        var nextIndex: Int
        var totalCount: Int

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
            return "[QuarterNoteSequence] step=\(answeredIndex + 1)/\(totalCount) expected=\(expectedPitchClass.displayText()) answered=\(answeredPitchClass.displayText()) result=\(resultText) nextIndex=\(nextIndex) remaining=\(remainingCount) state=\(stateText)"
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
    private(set) var quarterNoteSequencePrompt: QuarterNoteSequencePrompt?

    // 兼容当前单目标自然音训练链路；
    // 四分音序列模式的输出走 quarterNoteSequencePrompt。
    var prompt: Prompt {
        Prompt(targetPitchClass: targetPitchClass)
    }

    init(targetPitchClass: PitchClass) {
        precondition(
            targetPitchClass.isNatural,
            "Target pitch class must be a natural note."
        )
        self.mode = .singleNaturalTarget
        self.targetPitchClass = targetPitchClass
        quarterNoteSequencePrompt = nil
    }

    init(quarterNoteSequenceSpec spec: QuarterNoteSequenceSpec) {
        mode = .quarterNoteSequence(spec)
        // 保留一个稳定的 legacy target 值，避免当前单目标 API 在未来迁移完成前失去初始化基线。
        targetPitchClass = .c
        quarterNoteSequencePrompt = nil
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

    mutating func generateQuarterNoteSequencePrompt() -> QuarterNoteSequencePrompt {
        var generator = SystemRandomNumberGenerator()
        return generateQuarterNoteSequencePrompt(using: &generator)
    }

    mutating func generateQuarterNoteSequencePrompt<R: RandomNumberGenerator>(
        using generator: inout R
    ) -> QuarterNoteSequencePrompt {
        let spec = requireQuarterNoteSequenceSpec()
        let sequence = StaffQuarterNoteSequenceGenerator().makeSequence(
            spec: spec.staffGeneratorSpec,
            using: &generator
        )
        let prompt = QuarterNoteSequencePrompt(
            spec: spec,
            score: sequence.score,
            expectedPitchClasses: sequence.expectedPitchClasses
        )
        quarterNoteSequencePrompt = prompt
        return prompt
    }

    mutating func generateQuarterNoteSequencePrompt(
        for spec: QuarterNoteSequenceSpec
    ) -> QuarterNoteSequencePrompt {
        mode = .quarterNoteSequence(spec)
        quarterNoteSequencePrompt = nil
        return generateQuarterNoteSequencePrompt()
    }

    func makeQuarterNoteSequenceSession() -> QuarterNoteSequenceSession {
        QuarterNoteSequenceSession(prompt: requireCurrentQuarterNoteSequencePrompt())
    }

    mutating func handleQuarterNoteSequenceAnswer(
        _ pitchClass: PitchClass,
        session: inout QuarterNoteSequenceSession
    ) -> QuarterNoteSequenceAnswerResult {
        let prompt = requireCurrentQuarterNoteSequencePrompt()
        precondition(
            session.prompt == prompt,
            "Quarter-note sequence session prompt must match the current trainer prompt."
        )

        guard let expectedPitchClass = session.currentExpectedPitchClass else {
            return .ignored(.completedSession)
        }

        let answeredIndex = session.currentIndex
        let isCorrect = pitchClass == expectedPitchClass
        let nextIndex = isCorrect ? answeredIndex + 1 : answeredIndex
        if isCorrect {
            session.currentIndex = nextIndex
        }

        return .evaluated(
            QuarterNoteSequenceEvaluation(
                expectedPitchClass: expectedPitchClass,
                answeredPitchClass: pitchClass,
                answeredIndex: answeredIndex,
                nextIndex: nextIndex,
                totalCount: session.totalCount
            )
        )
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

    private func requireSingleNaturalTargetMode(
        _ function: StaticString = #function
    ) {
        guard case .singleNaturalTarget = mode else {
            preconditionFailure(
                "\(function) requires .singleNaturalTarget mode."
            )
        }
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

    private func requireCurrentQuarterNoteSequencePrompt(
        _ function: StaticString = #function
    ) -> QuarterNoteSequencePrompt {
        requireQuarterNoteSequenceSpec(function)

        guard let quarterNoteSequencePrompt else {
            preconditionFailure(
                "\(function) requires a generated quarter-note sequence prompt."
            )
        }

        return quarterNoteSequencePrompt
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

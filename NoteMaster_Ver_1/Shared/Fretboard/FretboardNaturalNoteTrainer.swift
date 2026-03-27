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

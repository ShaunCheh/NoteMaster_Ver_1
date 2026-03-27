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
    }

    enum QuarterNoteSequenceAnswerResult: Equatable, Sendable {
        case pendingImplementation
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
        let prompt = StaffQuarterNoteSequenceGenerator().makePrompt(
            spec: spec,
            using: &generator
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
        guard let quarterNoteSequencePrompt else {
            preconditionFailure(
                "Generate a quarter-note sequence prompt before creating a session."
            )
        }

        return QuarterNoteSequenceSession(prompt: quarterNoteSequencePrompt)
    }

    // Step 2 stub:
    // 顺序判题会基于 session.currentIndex 对 expectedPitchClasses 逐个比较。
    mutating func handleQuarterNoteSequenceAnswer(
        _ pitchClass: PitchClass,
        session: inout QuarterNoteSequenceSession
    ) -> QuarterNoteSequenceAnswerResult {
        let _ = pitchClass
        let _ = session
        preconditionFailure(
            "Quarter-note sequence answering will be implemented in a later step."
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
}

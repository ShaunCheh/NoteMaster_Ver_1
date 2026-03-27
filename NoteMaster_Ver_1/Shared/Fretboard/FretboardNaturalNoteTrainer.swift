//
//  FretboardNaturalNoteTrainer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

struct FretboardNaturalNoteTrainerState: Equatable, Sendable {
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

    struct Prompt: Equatable, Sendable {
        var targetPitchClass: PitchClass

        var displayText: String {
            targetPitchClass.displayText()
        }
    }

    private(set) var targetPitchClass: PitchClass

    var prompt: Prompt {
        Prompt(targetPitchClass: targetPitchClass)
    }

    init(targetPitchClass: PitchClass) {
        precondition(
            targetPitchClass.isNatural,
            "Target pitch class must be a natural note."
        )
        self.targetPitchClass = targetPitchClass
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

    mutating func advanceToNextTarget() -> PitchClass {
        var generator = SystemRandomNumberGenerator()
        return advanceToNextTarget(using: &generator)
    }

    mutating func advanceToNextTarget<R: RandomNumberGenerator>(
        using generator: inout R
    ) -> PitchClass {
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
}

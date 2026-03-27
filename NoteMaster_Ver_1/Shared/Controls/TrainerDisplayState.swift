//
//  TrainerDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
}

struct TrainerSequenceConfiguration: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool

    static let `default` = TrainerSequenceConfiguration(
        clef: .treble,
        noteCount: 7,
        includesAccidentals: false
    )

    init(
        clef: StaffClef = .treble,
        noteCount: Int = 7,
        includesAccidentals: Bool = false
    ) {
        precondition(
            noteCount > 0,
            "Trainer sequence note count must be greater than zero."
        )
        self.clef = clef
        self.noteCount = noteCount
        self.includesAccidentals = includesAccidentals
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration

    static let `default` = TrainerDisplayState()

    init(
        exerciseMode: TrainerExerciseMode = .single,
        sequenceConfiguration: TrainerSequenceConfiguration = .default
    ) {
        self.exerciseMode = exerciseMode
        self.sequenceConfiguration = sequenceConfiguration
    }

    var isSequenceMode: Bool {
        exerciseMode == .sequence
    }

    mutating func setExerciseMode(_ mode: TrainerExerciseMode) {
        exerciseMode = mode
    }
}

extension TrainerSequenceConfiguration {
    init(
        quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) {
        self.init(
            clef: quarterNoteSequenceSpec.clef,
            noteCount: quarterNoteSequenceSpec.noteCount,
            includesAccidentals: quarterNoteSequenceSpec.includesAccidentals
        )
    }

    var quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
        FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals
        )
    }
}

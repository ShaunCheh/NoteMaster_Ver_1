//
//  TrainerDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
}

struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let defaultSelectedFrets = Set(supportedFretRange)
    static let `default` = TrainerPositionPromptConfiguration()

    private(set) var selectedFrets: Set<Int>

    init(
        selectedFrets: Set<Int> = Self.defaultSelectedFrets
    ) {
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    var sortedSelectedFrets: [Int] {
        selectedFrets.sorted()
    }

    func normalized() -> TrainerPositionPromptConfiguration {
        TrainerPositionPromptConfiguration(
            selectedFrets: selectedFrets
        )
    }

    func contains(_ fret: Int) -> Bool {
        selectedFrets.contains(fret)
    }

    func canDeselect(_ fret: Int) -> Bool {
        guard selectedFrets.contains(fret) else {
            return true
        }

        return selectedFrets.count > 1
    }

    func toggled(fret: Int) -> TrainerPositionPromptConfiguration {
        guard Self.supportedFretRange.contains(fret) else {
            return self
        }

        var nextSelectedFrets = selectedFrets
        if nextSelectedFrets.contains(fret) {
            guard canDeselect(fret) else {
                return self
            }
            nextSelectedFrets.remove(fret)
        } else {
            nextSelectedFrets.insert(fret)
        }

        return TrainerPositionPromptConfiguration(
            selectedFrets: nextSelectedFrets
        )
    }

    mutating func setSelectedFrets(_ selectedFrets: Set<Int>) {
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    mutating func toggleFret(_ fret: Int) {
        self = toggled(fret: fret)
    }

    private static func normalizedSelectedFrets(
        _ selectedFrets: Set<Int>
    ) -> Set<Int> {
        let normalizedFrets = Set(
            selectedFrets.filter { supportedFretRange.contains($0) }
        )
        return normalizedFrets.isEmpty
            ? defaultSelectedFrets
            : normalizedFrets
    }
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
    var positionPromptConfiguration: TrainerPositionPromptConfiguration

    static let `default` = TrainerDisplayState()

    init(
        exerciseMode: TrainerExerciseMode = .single,
        sequenceConfiguration: TrainerSequenceConfiguration = .default,
        positionPromptConfiguration: TrainerPositionPromptConfiguration = .default
    ) {
        self.exerciseMode = exerciseMode
        self.sequenceConfiguration = sequenceConfiguration
        self.positionPromptConfiguration = positionPromptConfiguration.normalized()
    }

    var isSequenceMode: Bool {
        exerciseMode == .sequence
    }

    var isPositionPromptMode: Bool {
        exerciseMode == .positionPrompt
    }

    mutating func setExerciseMode(_ mode: TrainerExerciseMode) {
        exerciseMode = mode
    }

    mutating func setPositionPromptConfiguration(
        _ configuration: TrainerPositionPromptConfiguration
    ) {
        positionPromptConfiguration = configuration.normalized()
    }

    mutating func togglePositionPromptFret(_ fret: Int) {
        positionPromptConfiguration = positionPromptConfiguration.toggled(
            fret: fret
        )
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

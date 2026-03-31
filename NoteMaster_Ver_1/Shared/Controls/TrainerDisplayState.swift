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

enum TrainerPositionPromptFilterMode: Equatable, Hashable, Sendable {
    case noteName
    case fret
}

enum PositionPromptCandidateFilter: Equatable, Sendable {
    case noteNames(Set<PitchClass>)
    case frets(Set<Int>)
}

struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let supportedPitchClasses: [PitchClass] = PitchClass.naturalCasesInOrder
    static let defaultFilterMode: TrainerPositionPromptFilterMode = .noteName
    static let defaultSelectedPitchClasses: Set<PitchClass> = [
        .c, .e, .f, .b
    ]
    static let defaultSelectedFrets: Set<Int> = [
        1, 2, 3, 4,
        8, 9, 10, 11
    ]
    static let `default` = TrainerPositionPromptConfiguration()

    var filterMode: TrainerPositionPromptFilterMode
    private(set) var selectedPitchClasses: Set<PitchClass>
    private(set) var selectedFrets: Set<Int>

    init(
        filterMode: TrainerPositionPromptFilterMode = Self.defaultFilterMode,
        selectedPitchClasses: Set<PitchClass> = Self.defaultSelectedPitchClasses,
        selectedFrets: Set<Int> = Self.defaultSelectedFrets
    ) {
        self.filterMode = filterMode
        self.selectedPitchClasses = Self.normalizedSelectedPitchClasses(
            selectedPitchClasses
        )
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    var activeFilter: PositionPromptCandidateFilter {
        switch filterMode {
        case .noteName:
            return .noteNames(selectedPitchClasses)
        case .fret:
            return .frets(selectedFrets)
        }
    }

    var sortedSelectedPitchClasses: [PitchClass] {
        Self.supportedPitchClasses.filter {
            selectedPitchClasses.contains($0)
        }
    }

    var sortedSelectedFrets: [Int] {
        selectedFrets.sorted()
    }

    var isNoteNameFilterMode: Bool {
        filterMode == .noteName
    }

    var isFretFilterMode: Bool {
        filterMode == .fret
    }

    func normalized() -> TrainerPositionPromptConfiguration {
        TrainerPositionPromptConfiguration(
            filterMode: filterMode,
            selectedPitchClasses: selectedPitchClasses,
            selectedFrets: selectedFrets
        )
    }

    func contains(_ pitchClass: PitchClass) -> Bool {
        selectedPitchClasses.contains(pitchClass)
    }

    func contains(_ fret: Int) -> Bool {
        selectedFrets.contains(fret)
    }

    func canDeselect(_ pitchClass: PitchClass) -> Bool {
        guard selectedPitchClasses.contains(pitchClass) else {
            return true
        }

        return selectedPitchClasses.count > 1
    }

    func canDeselect(_ fret: Int) -> Bool {
        guard selectedFrets.contains(fret) else {
            return true
        }

        return selectedFrets.count > 1
    }

    func toggled(pitchClass: PitchClass) -> TrainerPositionPromptConfiguration {
        guard pitchClass.isNatural else {
            return self
        }

        var nextSelectedPitchClasses = selectedPitchClasses
        if nextSelectedPitchClasses.contains(pitchClass) {
            guard canDeselect(pitchClass) else {
                return self
            }
            nextSelectedPitchClasses.remove(pitchClass)
        } else {
            nextSelectedPitchClasses.insert(pitchClass)
        }

        return TrainerPositionPromptConfiguration(
            filterMode: filterMode,
            selectedPitchClasses: nextSelectedPitchClasses,
            selectedFrets: selectedFrets
        )
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
            filterMode: filterMode,
            selectedPitchClasses: selectedPitchClasses,
            selectedFrets: nextSelectedFrets
        )
    }

    mutating func setFilterMode(_ filterMode: TrainerPositionPromptFilterMode) {
        self.filterMode = filterMode
    }

    mutating func setSelectedPitchClasses(
        _ selectedPitchClasses: Set<PitchClass>
    ) {
        self.selectedPitchClasses = Self.normalizedSelectedPitchClasses(
            selectedPitchClasses
        )
    }

    mutating func setSelectedFrets(_ selectedFrets: Set<Int>) {
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    mutating func togglePitchClass(_ pitchClass: PitchClass) {
        self = toggled(pitchClass: pitchClass)
    }

    mutating func toggleFret(_ fret: Int) {
        self = toggled(fret: fret)
    }

    private static func normalizedSelectedPitchClasses(
        _ selectedPitchClasses: Set<PitchClass>
    ) -> Set<PitchClass> {
        let normalizedPitchClasses = Set(
            selectedPitchClasses.filter(\.isNatural)
        )
        return normalizedPitchClasses.isEmpty
            ? defaultSelectedPitchClasses
            : normalizedPitchClasses
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

    static let `default` = TrainerDisplayState(
        exerciseMode: .positionPrompt
    )

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

    mutating func setPositionPromptFilterMode(
        _ filterMode: TrainerPositionPromptFilterMode
    ) {
        positionPromptConfiguration.setFilterMode(filterMode)
    }

    mutating func togglePositionPromptPitchClass(
        _ pitchClass: PitchClass
    ) {
        positionPromptConfiguration = positionPromptConfiguration.toggled(
            pitchClass: pitchClass
        )
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

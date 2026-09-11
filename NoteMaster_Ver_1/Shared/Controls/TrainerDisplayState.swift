//
//  TrainerDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

import CoreGraphics

enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case p2
    case positionPrompt
    case fr0
    case sr0
    case sr1
    case sr2
    case bcr1
}

// Sequence judging policy is configuration, not generated content.
// `.pitchClass` ignores octave, while `.exactNote` compares the full `NotePitch`.
enum TrainerSequenceAnswerPolicy: Equatable, Hashable, Sendable {
    case pitchClass
    case exactNote
}

enum TrainerBCR1QuestionMode: CaseIterable, Equatable, Hashable, Sendable {
    case line
    case space
    case mixed
}

struct TrainerBCR1QuestionConfiguration: Equatable, Sendable {
    var mode: TrainerBCR1QuestionMode

    static let `default` = TrainerBCR1QuestionConfiguration(mode: .mixed)
    static let staffAdditionalVerticalSpaces: CGFloat = 2

    var generationStrategy: StaffQuarterNoteGenerationStrategy {
        switch mode {
        case .line:
            return .diatonicProgression(
                progression: StaffDiatonicPitchProgressionSpec(
                    startPitch: StaffPitch(letter: .c, octave: 2),
                    intervalNumber: 3,
                    candidateCount: 8
                ),
                selection: StaffWithoutReplacementSelectionSpec(
                    outputCount: 8,
                    minimumLineCount: 8
                )
            )
        case .space:
            return .diatonicProgression(
                progression: StaffDiatonicPitchProgressionSpec(
                    startPitch: StaffPitch(letter: .d, octave: 2),
                    intervalNumber: 3,
                    candidateCount: 8
                ),
                selection: StaffWithoutReplacementSelectionSpec(
                    outputCount: 8,
                    minimumSpaceCount: 8
                )
            )
        case .mixed:
            return .diatonicProgression(
                progression: StaffDiatonicPitchProgressionSpec(
                    startPitch: StaffPitch(letter: .c, octave: 2),
                    intervalNumber: 2,
                    candidateCount: 16
                ),
                selection: StaffWithoutReplacementSelectionSpec(
                    outputCount: 8,
                    minimumLineCount: 1,
                    minimumSpaceCount: 1
                )
            )
        }
    }
}

enum TrainerPianoSequenceRecognitionMode: Equatable, Hashable, Sendable {
    case sr1
    case sr2
    case bcr1

    var contract: TrainerPianoSequenceRecognitionContract {
        switch self {
        case .sr1:
            return .singleRowPitchClass(clef: .treble)
        case .sr2:
            return TrainerPianoSequenceRecognitionContract(
                clef: .treble,
                answerPolicy: .exactNote,
                pianoRowCount: 2,
                pianoMovementScope: .rowOnly
            )
        case .bcr1:
            return .singleRowPitchClass(clef: .bass)
        }
    }
}

struct TrainerPianoSequenceRecognitionContract: Equatable, Sendable {
    let fixedSequenceClef: StaffClef
    let fixedExerciseLayoutPreferences: ExerciseLayoutPreferences
    let fixedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy
    let fixedPianoRowCount: Int
    let fixedPianoMovementScope: PianoMovementScope

    init(
        clef: StaffClef,
        answerPolicy: TrainerSequenceAnswerPolicy,
        pianoRowCount: Int,
        pianoMovementScope: PianoMovementScope
    ) {
        fixedSequenceClef = clef
        fixedExerciseLayoutPreferences = .pianoRecognitionAnswer
        fixedSequenceAnswerPolicy = answerPolicy
        fixedPianoRowCount = pianoRowCount
        fixedPianoMovementScope = pianoMovementScope
    }

    static func singleRowPitchClass(
        clef: StaffClef
    ) -> TrainerPianoSequenceRecognitionContract {
        TrainerPianoSequenceRecognitionContract(
            clef: clef,
            answerPolicy: .pitchClass,
            pianoRowCount: 1,
            pianoMovementScope: .rowOnly
        )
    }
}

extension TrainerExerciseMode {
    var pianoSequenceRecognitionMode: TrainerPianoSequenceRecognitionMode? {
        switch self {
        case .sr1:
            return .sr1
        case .sr2:
            return .sr2
        case .bcr1:
            return .bcr1
        case .single, .sequence, .p2, .positionPrompt, .fr0, .sr0:
            return nil
        }
    }

    var isPianoSequenceRecognitionMode: Bool {
        pianoSequenceRecognitionMode != nil
    }

    var pianoSequenceRecognitionContract:
        TrainerPianoSequenceRecognitionContract? {
        pianoSequenceRecognitionMode?.contract
    }

    var fixedCompositionPreset: ExerciseCompositionPreset? {
        fixedExerciseLayoutPreferences?.compositionPreset
    }

    var allowsAccessoryPianoPromotion: Bool {
        fixedExerciseLayoutPreferences == nil
    }

    var fixedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy? {
        switch self {
        case .sr1, .sr2, .bcr1:
            return pianoSequenceRecognitionContract?.fixedSequenceAnswerPolicy
        case .sr0:
            return .pitchClass
        case .single, .sequence, .p2, .positionPrompt, .fr0:
            return nil
        }
    }

    var fixedSequenceClef: StaffClef? {
        switch self {
        case .sr1, .sr2, .bcr1:
            return pianoSequenceRecognitionContract?.fixedSequenceClef
        case .sr0:
            return .treble
        case .single, .sequence, .p2, .positionPrompt, .fr0:
            return nil
        }
    }

    var fixedExerciseLayoutPreferences: ExerciseLayoutPreferences? {
        switch self {
        case .sr1, .sr2, .bcr1:
            return pianoSequenceRecognitionContract?
                .fixedExerciseLayoutPreferences
        case .p2:
            return .p2StaffFretboardAnswer
        case .fr0:
            return .fr0TargetPromptFretboardAnswer
        case .sr0:
            return .srNoteStripAnswer
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }

    var fixedPianoRowCount: Int? {
        switch self {
        case .sr1, .sr2, .bcr1:
            return pianoSequenceRecognitionContract?.fixedPianoRowCount
        case .single, .sequence, .p2, .positionPrompt, .fr0, .sr0:
            return nil
        }
    }

    var fixedPianoMovementScope: PianoMovementScope? {
        switch self {
        case .sr1, .sr2, .bcr1:
            return pianoSequenceRecognitionContract?.fixedPianoMovementScope
        case .single, .sequence, .p2, .positionPrompt, .fr0, .sr0:
            return nil
        }
    }

    var usesQuarterNoteSequenceKernel: Bool {
        switch self {
        case .sequence, .p2, .sr0, .sr1, .sr2, .bcr1:
            return true
        case .single, .positionPrompt, .fr0:
            return false
        }
    }

    func applyingFixedPianoSettings(
        to settingsSlice: PianoPanelSettingsSlice
    ) -> PianoPanelSettingsSlice {
        var resolvedSettingsSlice = settingsSlice
        if let fixedRowCount = fixedPianoRowCount {
            resolvedSettingsSlice.rowCount = fixedRowCount
        }
        if let fixedMovementScope = fixedPianoMovementScope {
            resolvedSettingsSlice.movementScope = fixedMovementScope
        }
        return resolvedSettingsSlice
    }
}

enum TrainerPositionPromptFilterMode: Equatable, Hashable, Sendable {
    case noteName
    case fret
}

enum PositionPromptCandidateFilter: Equatable, Sendable {
    case noteNames(Set<PitchClass>)
    case frets(Set<Int>)
}

enum PositionPromptAnswerRule: Equatable, Hashable, Sendable {
    case samePitchClass
}

struct TrainerPositionQuestionConfiguration: Equatable, Sendable {
    static let supportedPitchClasses: [PitchClass] = PitchClass.naturalCasesInOrder
    static let defaultSelectedPitchClasses: Set<PitchClass> = [
        .c, .e, .f, .b
    ]
    static let `default` = TrainerPositionQuestionConfiguration()

    private(set) var selectedPitchClasses: Set<PitchClass>

    init(
        selectedPitchClasses: Set<PitchClass> = Self.defaultSelectedPitchClasses
    ) {
        self.selectedPitchClasses = Self.normalizedSelectedPitchClasses(
            selectedPitchClasses
        )
    }

    var activeFilter: PositionPromptCandidateFilter {
        .noteNames(selectedPitchClasses)
    }

    var sortedSelectedPitchClasses: [PitchClass] {
        Self.supportedPitchClasses.filter {
            selectedPitchClasses.contains($0)
        }
    }

    func normalized() -> TrainerPositionQuestionConfiguration {
        TrainerPositionQuestionConfiguration(
            selectedPitchClasses: selectedPitchClasses
        )
    }

    func contains(_ pitchClass: PitchClass) -> Bool {
        selectedPitchClasses.contains(pitchClass)
    }

    func canDeselect(_ pitchClass: PitchClass) -> Bool {
        guard selectedPitchClasses.contains(pitchClass) else {
            return true
        }

        return selectedPitchClasses.count > 1
    }

    func toggled(
        pitchClass: PitchClass
    ) -> TrainerPositionQuestionConfiguration {
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

        return TrainerPositionQuestionConfiguration(
            selectedPitchClasses: nextSelectedPitchClasses
        )
    }

    mutating func setSelectedPitchClasses(
        _ selectedPitchClasses: Set<PitchClass>
    ) {
        self.selectedPitchClasses = Self.normalizedSelectedPitchClasses(
            selectedPitchClasses
        )
    }

    mutating func togglePitchClass(_ pitchClass: PitchClass) {
        self = toggled(pitchClass: pitchClass)
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
}

struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let supportedPitchClasses: [PitchClass] = PitchClass.naturalCasesInOrder
    static let defaultFilterMode: TrainerPositionPromptFilterMode = .noteName
    static let defaultAnswerRule: PositionPromptAnswerRule = .samePitchClass
    static let defaultSelectedPitchClasses: Set<PitchClass> = [
        .c, .e, .f, .b
    ]
    static let defaultSelectedFrets: Set<Int> = [
        1, 2, 3, 4,
        8, 9, 10, 11
    ]
    static let `default` = TrainerPositionPromptConfiguration()

    var filterMode: TrainerPositionPromptFilterMode
    var answerRule: PositionPromptAnswerRule
    private(set) var selectedPitchClasses: Set<PitchClass>
    private(set) var selectedFrets: Set<Int>

    init(
        filterMode: TrainerPositionPromptFilterMode = Self.defaultFilterMode,
        answerRule: PositionPromptAnswerRule = Self.defaultAnswerRule,
        selectedPitchClasses: Set<PitchClass> = Self.defaultSelectedPitchClasses,
        selectedFrets: Set<Int> = Self.defaultSelectedFrets
    ) {
        self.filterMode = filterMode
        self.answerRule = answerRule
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
            answerRule: answerRule,
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
            answerRule: answerRule,
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
            answerRule: answerRule,
            selectedPitchClasses: selectedPitchClasses,
            selectedFrets: nextSelectedFrets
        )
    }

    mutating func setFilterMode(_ filterMode: TrainerPositionPromptFilterMode) {
        self.filterMode = filterMode
    }

    mutating func setAnswerRule(_ answerRule: PositionPromptAnswerRule) {
        self.answerRule = answerRule
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
    var answerPolicy: TrainerSequenceAnswerPolicy
    var generationStrategy: StaffQuarterNoteGenerationStrategy

    static let `default` = TrainerSequenceConfiguration(
        clef: .treble,
        noteCount: 7,
        includesAccidentals: false,
        answerPolicy: .pitchClass
    )

    init(
        clef: StaffClef = .treble,
        noteCount: Int = 7,
        includesAccidentals: Bool = false,
        answerPolicy: TrainerSequenceAnswerPolicy,
        generationStrategy: StaffQuarterNoteGenerationStrategy =
            .clefRangeRandomWithReplacement
    ) {
        precondition(
            noteCount > 0,
            "Trainer sequence note count must be greater than zero."
        )
        self.clef = clef
        self.noteCount = noteCount
        self.includesAccidentals = includesAccidentals
        self.answerPolicy = answerPolicy
        self.generationStrategy = generationStrategy
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration
    var bcr1QuestionConfiguration: TrainerBCR1QuestionConfiguration
    var positionQuestionConfiguration: TrainerPositionQuestionConfiguration
    var positionPromptConfiguration: TrainerPositionPromptConfiguration

    static let `default` = TrainerDisplayState(
        exerciseMode: .positionPrompt
    )

    init(
        exerciseMode: TrainerExerciseMode = .single,
        sequenceConfiguration: TrainerSequenceConfiguration = .default,
        bcr1QuestionConfiguration: TrainerBCR1QuestionConfiguration = .default,
        positionQuestionConfiguration: TrainerPositionQuestionConfiguration = .default,
        positionPromptConfiguration: TrainerPositionPromptConfiguration = .default
    ) {
        self.exerciseMode = exerciseMode
        self.sequenceConfiguration = sequenceConfiguration
        self.bcr1QuestionConfiguration = bcr1QuestionConfiguration
        self.positionQuestionConfiguration = positionQuestionConfiguration.normalized()
        self.positionPromptConfiguration = positionPromptConfiguration.normalized()
    }

    var isPositionPromptMode: Bool {
        exerciseMode == .positionPrompt
    }

    var isFR0Mode: Bool {
        exerciseMode == .fr0
    }

    var usesPositionQuestionPitchClassPool: Bool {
        isPositionPromptMode || isFR0Mode
    }

    // Keep the legacy `.sequence` UI semantics stable until SR modes get
    // their own dedicated settings and scene wiring in later phases.
    var isSequenceMode: Bool {
        exerciseMode == .sequence
    }

    // This is the shared seam for modes that reuse the quarter-note sequence
    // trainer kernel, independent from which UI mode is currently selected.
    var usesQuarterNoteSequenceKernel: Bool {
        exerciseMode.usesQuarterNoteSequenceKernel
    }

    var positionPromptAnswerRule: PositionPromptAnswerRule {
        positionPromptConfiguration.answerRule
    }

    var positionQuestionCandidateFilter: PositionPromptCandidateFilter {
        positionQuestionConfiguration.activeFilter
    }

    mutating func setExerciseMode(_ mode: TrainerExerciseMode) {
        exerciseMode = mode
    }

    mutating func setBCR1QuestionMode(_ mode: TrainerBCR1QuestionMode) {
        bcr1QuestionConfiguration.mode = mode
    }

    mutating func setPositionPromptConfiguration(
        _ configuration: TrainerPositionPromptConfiguration
    ) {
        positionPromptConfiguration = configuration.normalized()
    }

    mutating func setPositionQuestionConfiguration(
        _ configuration: TrainerPositionQuestionConfiguration
    ) {
        positionQuestionConfiguration = configuration.normalized()
    }

    mutating func setPositionPromptFilterMode(
        _ filterMode: TrainerPositionPromptFilterMode
    ) {
        positionPromptConfiguration.setFilterMode(filterMode)
    }

    mutating func setPositionPromptAnswerRule(
        _ answerRule: PositionPromptAnswerRule
    ) {
        positionPromptConfiguration.setAnswerRule(answerRule)
    }

    mutating func togglePositionQuestionPitchClass(
        _ pitchClass: PitchClass
    ) {
        positionQuestionConfiguration = positionQuestionConfiguration.toggled(
            pitchClass: pitchClass
        )
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
    func applyingModeConstraints(
        _ exerciseMode: TrainerExerciseMode
    ) -> TrainerSequenceConfiguration {
        var normalized = self
        if let fixedClef = exerciseMode.fixedSequenceClef {
            normalized.clef = fixedClef
        }
        if let fixedAnswerPolicy = exerciseMode.fixedSequenceAnswerPolicy {
            normalized.answerPolicy = fixedAnswerPolicy
        }
        return normalized
    }

    init(
        quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) {
        self.init(
            clef: quarterNoteSequenceSpec.clef,
            noteCount: quarterNoteSequenceSpec.noteCount,
            includesAccidentals: quarterNoteSequenceSpec.includesAccidentals,
            answerPolicy: quarterNoteSequenceSpec.answerPolicy,
            generationStrategy: quarterNoteSequenceSpec.generationStrategy
        )
    }

    var quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
        FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals,
            answerPolicy: answerPolicy,
            generationStrategy: generationStrategy
        )
    }
}

extension TrainerDisplayState {
    var resolvedSequenceConfiguration: TrainerSequenceConfiguration {
        var resolved = sequenceConfiguration.applyingModeConstraints(exerciseMode)
        guard exerciseMode == .bcr1 else {
            return resolved
        }

        resolved.clef = .bass
        resolved.noteCount = 8
        resolved.includesAccidentals = false
        resolved.answerPolicy = .pitchClass
        resolved.generationStrategy = bcr1QuestionConfiguration.generationStrategy
        return resolved
    }

    func resolvedPianoSettingsSlice(
        from settingsSlice: PianoPanelSettingsSlice
    ) -> PianoPanelSettingsSlice {
        exerciseMode.applyingFixedPianoSettings(to: settingsSlice)
    }
}

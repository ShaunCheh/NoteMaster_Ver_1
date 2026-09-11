//
//  ExerciseLayoutPreferences.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

enum ExerciseCompositionPreset: String, CaseIterable, Equatable, Hashable, Sendable {
    case staffToFretboard
    case staffToPiano
    case staffToNaturalNoteStrip
    case targetPromptToFretboard
    case fretboardToNaturalNoteStrip
    case fretboardSelfAnswer
}

enum ExerciseLayoutPreset: String, CaseIterable, Equatable, Hashable, Sendable {
    case stacked
    case sideBySide
    case singleSurface
    case threePane
    case overlay
    case collapsibleAccessory
}

enum ExerciseAccessoryPresentation: String, CaseIterable, Equatable, Hashable, Sendable {
    case docked
    case floating
    case collapsible
}

enum ExerciseFretboardOverflowScrollAxis:
    String,
    CaseIterable,
    Equatable,
    Hashable,
    Sendable {
    case horizontal
    case vertical
}

struct ExerciseLayoutPreferences: Equatable, Sendable {
    var compositionPreset: ExerciseCompositionPreset
    var layoutPreset: ExerciseLayoutPreset
    var accessoryPresentation: ExerciseAccessoryPresentation
    var isNaturalNoteStripVisible: Bool
    var isPianoAccessoryVisible: Bool
    var isAccessoryExpanded: Bool
    var verticalFretboardWidthScale: Double
    var verticalFretboardOverflowScrollAxis: ExerciseFretboardOverflowScrollAxis

    static let `default` = ExerciseLayoutPreferences()
    static let legacyPositionPrompt = ExerciseLayoutPreferences(
        compositionPreset: .fretboardToNaturalNoteStrip,
        layoutPreset: .sideBySide,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: true,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
    static let singleFretboardSelfAnswer = ExerciseLayoutPreferences(
        compositionPreset: .fretboardSelfAnswer,
        layoutPreset: .singleSurface,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
    static let p2StaffFretboardAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToFretboard,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true,
        verticalFretboardWidthScale: 2,
        verticalFretboardOverflowScrollAxis: .vertical
    )
    static let fr0TargetPromptFretboardAnswer = ExerciseLayoutPreferences(
        compositionPreset: .targetPromptToFretboard,
        layoutPreset: .sideBySide,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
    static let pianoRecognitionAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToPiano,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
    static let srNoteStripAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToNaturalNoteStrip,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: true,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )

    init(
        compositionPreset: ExerciseCompositionPreset = .staffToFretboard,
        layoutPreset: ExerciseLayoutPreset = .sideBySide,
        accessoryPresentation: ExerciseAccessoryPresentation = .docked,
        isNaturalNoteStripVisible: Bool = false,
        isPianoAccessoryVisible: Bool = false,
        isAccessoryExpanded: Bool = true,
        verticalFretboardWidthScale: Double = 1,
        verticalFretboardOverflowScrollAxis: ExerciseFretboardOverflowScrollAxis = .horizontal
    ) {
        self.compositionPreset = compositionPreset
        self.layoutPreset = layoutPreset
        self.accessoryPresentation = accessoryPresentation
        self.isNaturalNoteStripVisible = isNaturalNoteStripVisible
        self.isPianoAccessoryVisible = isPianoAccessoryVisible
        self.isAccessoryExpanded = isAccessoryExpanded
        self.verticalFretboardWidthScale = verticalFretboardWidthScale
        self.verticalFretboardOverflowScrollAxis =
            verticalFretboardOverflowScrollAxis
    }
}

extension ExerciseCompositionPreset {
    var usesMainNaturalNoteStripAnswerSurface: Bool {
        self == .fretboardToNaturalNoteStrip
            || self == .staffToNaturalNoteStrip
    }

    var usesMainPianoAnswerSurface: Bool {
        self == .staffToPiano
    }
}

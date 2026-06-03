//
//  SettingsPanelModel.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import Foundation
import CoreGraphics

enum SettingsSelectionStyle: Equatable, Sendable {
    case singleSelection
    case independent
}

enum SettingsPresentationStyle: Equatable, Sendable {
    case chips
    case segmented
}

enum SettingsRowID: Equatable, Hashable, Sendable {
    case choice(SettingsChoiceRowID)
    case positionFilter(SettingsPositionFilterRowID)
    case slider(SettingsSliderID)
    case toggle(SettingsToggleID)
}

enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case mode
    case exercise
    case positionPrompt
    case accessories
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    static var allCases: [SettingsSectionID] {
        [
            .exercise,
            .accessories,
            .fretboard,
            .staff,
            .piano,
            .debug
        ]
    }

    static func orderedVisibleSections(
        for rootMode: RootMode
    ) -> [SettingsSectionID] {
        switch rootMode {
        case .exercise:
            return [.mode] + allCases
        case .play:
            return [
                .mode,
                .piano
            ]
        }
    }

    func isVisible(
        in rootMode: RootMode
    ) -> Bool {
        Self.orderedVisibleSections(for: rootMode).contains(self)
    }

    var title: String {
        switch self {
        case .mode:
            return "Mode"
        case .exercise:
            return "Exercise"
        case .positionPrompt:
            return "Position Prompt"
        case .accessories:
            return "Accessories"
        case .trainer:
            return "Trainer"
        case .fretboard:
            return "Fretboard"
        case .staff:
            return "Staff"
        case .layout:
            return "Layout"
        case .piano:
            return "Piano"
        case .debug:
            return "Debug"
        }
    }

    var rowIDs: [SettingsRowID] {
        switch self {
        case .mode:
            return [
                .choice(.rootMode)
            ]
        case .exercise:
            return [
                .choice(.exerciseMode),
                .positionFilter(.positionQuestionPitchClasses),
                .choice(.compositionPreset),
                .choice(.layoutPreset)
            ]
        case .positionPrompt:
            return [
                .choice(.positionPromptFilterMode),
                .positionFilter(.positionPromptFilterOptions)
            ]
        case .accessories:
            return [
                .toggle(.naturalStripVisible),
                .toggle(.pianoAccessoryVisible),
                .choice(.accessoryPresentation),
                .toggle(.accessoryExpanded)
            ]
        case .trainer:
            return [
                .choice(.exerciseMode),
                .choice(.positionPromptFilterMode),
                .positionFilter(.positionPromptFilterOptions)
            ]
        case .fretboard:
            return [
                .choice(.instrument),
                .choice(.displayMode),
                .slider(.verticalHostHeightRatio),
                .choice(.stringThickness),
                .choice(.labels),
                .choice(.spelling),
                .choice(.octave)
            ]
        case .staff:
            return [
                .choice(.clef),
                .slider(.clefScale),
                .slider(.clefVerticalTrim),
                .slider(.clefAnchorYOffset)
            ]
        case .layout:
            return [
                .slider(.verticalHostHeightRatio)
            ]
        case .piano:
            return [
                .slider(.pianoRowCount),
                .choice(.pianoMovementScope),
                .choice(.pianoWhiteKeyStyle),
                .toggle(.pianoSnapEnabled)
            ]
        case .debug:
            return [
                .toggle(.showsComponentBounds),
                .toggle(.showsSideBySideContainerOutlines)
            ]
        }
    }
}

enum SettingsPositionFilterRowID: CaseIterable, Equatable, Hashable, Sendable {
    case positionQuestionPitchClasses
    case positionPromptFilterOptions

    var sectionID: SettingsSectionID {
        switch self {
        case .positionQuestionPitchClasses:
            return .exercise
        case .positionPromptFilterOptions:
            return .positionPrompt
        }
    }

    var supportedFrets: ClosedRange<Int> {
        switch self {
        case .positionQuestionPitchClasses:
            return TrainerPositionPromptConfiguration.supportedFretRange
        case .positionPromptFilterOptions:
            return TrainerPositionPromptConfiguration.supportedFretRange
        }
    }

    var supportedPitchClasses: [PitchClass] {
        switch self {
        case .positionQuestionPitchClasses:
            return TrainerPositionQuestionConfiguration.supportedPitchClasses
        case .positionPromptFilterOptions:
            return TrainerPositionPromptConfiguration.supportedPitchClasses
        }
    }
}

enum SettingsPositionFilterOptionID: Equatable, Hashable, Sendable {
    case pitchClass(PitchClass)
    case fret(Int)

    var accessibilityIdentifierComponent: String {
        switch self {
        case let .pitchClass(pitchClass):
            return "pitch-\(pitchClass.displayText().lowercased())"
        case let .fret(fret):
            return "fret-\(fret)"
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case rootMode
    case exerciseMode
    case compositionPreset
    case layoutPreset
    case positionPromptFilterMode
    case accessoryPresentation
    case instrument
    case displayMode
    case stringThickness
    case labels
    case spelling
    case octave
    case clef
    case pianoMovementScope
    case pianoWhiteKeyStyle

    var sectionID: SettingsSectionID {
        switch self {
        case .rootMode:
            return .mode
        case .exerciseMode, .compositionPreset, .layoutPreset:
            return .exercise
        case .positionPromptFilterMode:
            return .positionPrompt
        case .accessoryPresentation:
            return .accessories
        case .instrument, .displayMode, .stringThickness, .labels, .spelling, .octave:
            return .fretboard
        case .clef:
            return .staff
        case .pianoMovementScope:
            return .piano
        case .pianoWhiteKeyStyle:
            return .piano
        }
    }

    var title: String {
        switch self {
        case .rootMode:
            return "App Mode"
        case .exerciseMode:
            return "Exercise Mode"
        case .compositionPreset:
            return "Composition Preset"
        case .layoutPreset:
            return "Layout Preset"
        case .positionPromptFilterMode:
            return "Filter"
        case .accessoryPresentation:
            return "Accessory Presentation"
        case .instrument:
            return "Instrument"
        case .displayMode:
            return "Display"
        case .stringThickness:
            return "String Thickness"
        case .labels:
            return "Labels"
        case .spelling:
            return "Spelling"
        case .octave:
            return "Octave"
        case .clef:
            return "Type"
        case .pianoMovementScope:
            return "Row Linking"
        case .pianoWhiteKeyStyle:
            return "White Keys"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .rootMode:
            return "Select whether the app shows the exercise page or the play page"
        case .exerciseMode:
            return "Select exercise mode"
        case .compositionPreset:
            return "Select which prompt and answer surface pairing should be used"
        case .layoutPreset:
            return "Select how the current exercise surfaces are arranged on screen"
        case .positionPromptFilterMode:
            return "Select which position filter mode is active"
        case .accessoryPresentation:
            return "Select how accessory surfaces should be attached to the main exercise scene"
        case .instrument:
            return "Select instrument"
        case .displayMode:
            return "Select display mode"
        case .stringThickness:
            return "Select whether all strings share one thickness or low strings are thicker than high strings"
        case .labels:
            return "Select note label visibility"
        case .spelling:
            return "Select note spelling"
        case .octave:
            return "Toggle octave display"
        case .clef:
            return "Select clef"
        case .pianoMovementScope:
            return "Select whether piano movement affects the current row or cascades across rows"
        case .pianoWhiteKeyStyle:
            return "Select whether white keys use outlined borders, gap-only separation, or a glossy skeuomorphic highlight"
        }
    }

    var selectionStyle: SettingsSelectionStyle {
        switch self {
        case .rootMode,
             .exerciseMode,
             .compositionPreset,
             .layoutPreset,
             .positionPromptFilterMode,
             .accessoryPresentation,
             .instrument,
             .displayMode,
             .stringThickness,
             .labels,
             .spelling,
             .clef,
             .pianoMovementScope,
             .pianoWhiteKeyStyle:
            return .singleSelection
        case .octave:
            return .independent
        }
    }

    var presentationStyle: SettingsPresentationStyle {
        switch self {
        case .rootMode,
             .exerciseMode,
             .positionPromptFilterMode,
             .stringThickness,
             .clef,
             .pianoMovementScope,
             .pianoWhiteKeyStyle:
            return .segmented
        case .compositionPreset,
             .layoutPreset,
             .accessoryPresentation,
             .instrument,
             .displayMode,
             .labels,
             .spelling,
             .octave:
            return .chips
        }
    }

    var actionIDs: [SettingsActionID] {
        switch self {
        case .rootMode:
            return [
                .setRootModeExercise,
                .setRootModePlay
            ]
        case .exerciseMode:
            return [
                .setExerciseModeSingle,
                .setExerciseModeSequence,
                .setExerciseModeP2,
                .setExerciseModeSr0,
                .setExerciseModeSr1,
                .setExerciseModeSr2,
                .setExerciseModeFr0,
                .setExerciseModePositionPrompt
            ]
        case .compositionPreset:
            return [
                .setCompositionPresetStaffToFretboard,
                .setCompositionPresetTargetPromptToFretboard,
                .setCompositionPresetFretboardToNaturalNoteStrip,
                .setCompositionPresetFretboardSelfAnswer
            ]
        case .layoutPreset:
            return [
                .setLayoutPresetStacked,
                .setLayoutPresetSideBySide,
                .setLayoutPresetSingleSurface
            ]
        case .positionPromptFilterMode:
            return [
                .setPositionPromptFilterModeNoteName,
                .setPositionPromptFilterModeFret
            ]
        case .accessoryPresentation:
            return [
                .setAccessoryPresentationDocked,
                .setAccessoryPresentationFloating,
                .setAccessoryPresentationCollapsible
            ]
        case .instrument:
            return [
                .setInstrumentGuitar6,
                .setInstrumentBass4,
                .setInstrumentBass5
            ]
        case .displayMode:
            return [
                .setDisplayModeHorizontal,
                .setDisplayModeVertical
            ]
        case .stringThickness:
            return [
                .setStringThicknessUniform,
                .setStringThicknessGraduated
            ]
        case .labels:
            return [
                .setVisibilityAll,
                .setVisibilityNaturalOnly,
                .setVisibilityBCEFOnly,
                .setVisibilityAccidentalOnly,
                .setVisibilityNone
            ]
        case .spelling:
            return [
                .setSpellingSharp,
                .setSpellingFlat
            ]
        case .octave:
            return [
                .toggleShowsOctave
            ]
        case .clef:
            return [
                .setClefTreble,
                .setClefBass
            ]
        case .pianoMovementScope:
            return [
                .setPianoMovementScopeCascade,
                .setPianoMovementScopeRowOnly
            ]
        case .pianoWhiteKeyStyle:
            return [
                .setPianoWhiteKeyStyleOutlined,
                .setPianoWhiteKeyStyleGapOnly,
                .setPianoWhiteKeyStyleSkeuomorphicHighlight
            ]
        }
    }
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setRootModeExercise
    case setRootModePlay
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModeP2
    case setExerciseModeSr0
    case setExerciseModeSr1
    case setExerciseModeSr2
    case setExerciseModeFr0
    case setExerciseModePositionPrompt
    case setCompositionPresetStaffToFretboard
    case setCompositionPresetTargetPromptToFretboard
    case setCompositionPresetFretboardToNaturalNoteStrip
    case setCompositionPresetFretboardSelfAnswer
    case setLayoutPresetStacked
    case setLayoutPresetSideBySide
    case setLayoutPresetSingleSurface
    case setPositionPromptFilterModeNoteName
    case setPositionPromptFilterModeFret
    case setAccessoryPresentationDocked
    case setAccessoryPresentationFloating
    case setAccessoryPresentationCollapsible
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setStringThicknessUniform
    case setStringThicknessGraduated
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityBCEFOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
    case setClefTreble
    case setClefBass
    case setPianoMovementScopeCascade
    case setPianoMovementScopeRowOnly
    case setPianoWhiteKeyStyleOutlined
    case setPianoWhiteKeyStyleGapOnly
    case setPianoWhiteKeyStyleSkeuomorphicHighlight

    var rowID: SettingsChoiceRowID {
        switch self {
        case .setRootModeExercise,
             .setRootModePlay:
            return .rootMode
        case .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModeP2,
             .setExerciseModeSr0,
             .setExerciseModeSr1,
             .setExerciseModeSr2,
             .setExerciseModeFr0,
             .setExerciseModePositionPrompt:
            return .exerciseMode
        case .setCompositionPresetStaffToFretboard,
             .setCompositionPresetTargetPromptToFretboard,
             .setCompositionPresetFretboardToNaturalNoteStrip,
             .setCompositionPresetFretboardSelfAnswer:
            return .compositionPreset
        case .setLayoutPresetStacked,
             .setLayoutPresetSideBySide,
             .setLayoutPresetSingleSurface:
            return .layoutPreset
        case .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret:
            return .positionPromptFilterMode
        case .setAccessoryPresentationDocked,
             .setAccessoryPresentationFloating,
             .setAccessoryPresentationCollapsible:
            return .accessoryPresentation
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5:
            return .instrument
        case .setDisplayModeHorizontal,
             .setDisplayModeVertical:
            return .displayMode
        case .setStringThicknessUniform,
             .setStringThicknessGraduated:
            return .stringThickness
        case .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityBCEFOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone:
            return .labels
        case .setSpellingSharp,
             .setSpellingFlat:
            return .spelling
        case .toggleShowsOctave:
            return .octave
        case .setClefTreble,
             .setClefBass:
            return .clef
        case .setPianoMovementScopeCascade,
             .setPianoMovementScopeRowOnly:
            return .pianoMovementScope
        case .setPianoWhiteKeyStyleOutlined,
             .setPianoWhiteKeyStyleGapOnly,
             .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return .pianoWhiteKeyStyle
        }
    }

    var title: String {
        switch self {
        case .setRootModeExercise:
            return "Exercise"
        case .setRootModePlay:
            return "Play"
        case .setExerciseModeSingle:
            return "Single"
        case .setExerciseModeSequence:
            return "Sequence"
        case .setExerciseModeP2:
            return "P-2"
        case .setExerciseModeSr0:
            return "SR-0"
        case .setExerciseModeSr1:
            return "SR-1"
        case .setExerciseModeSr2:
            return "SR-2"
        case .setExerciseModeFr0:
            return "FR-0"
        case .setExerciseModePositionPrompt:
            return "Position"
        case .setCompositionPresetStaffToFretboard:
            return "Staff"
        case .setCompositionPresetTargetPromptToFretboard:
            return "Target"
        case .setCompositionPresetFretboardToNaturalNoteStrip:
            return "Strip"
        case .setCompositionPresetFretboardSelfAnswer:
            return "Self"
        case .setLayoutPresetStacked:
            return "Stacked"
        case .setLayoutPresetSideBySide:
            return "Side"
        case .setLayoutPresetSingleSurface:
            return "Single"
        case .setPositionPromptFilterModeNoteName:
            return "Note Names"
        case .setPositionPromptFilterModeFret:
            return "Frets"
        case .setAccessoryPresentationDocked:
            return "Docked"
        case .setAccessoryPresentationFloating:
            return "Floating"
        case .setAccessoryPresentationCollapsible:
            return "Collapsible"
        case .setInstrumentGuitar6:
            return "Guitar 6"
        case .setInstrumentBass4:
            return "Bass 4"
        case .setInstrumentBass5:
            return "Bass 5"
        case .setDisplayModeHorizontal:
            return "Horizontal"
        case .setDisplayModeVertical:
            return "Vertical"
        case .setStringThicknessUniform:
            return "Uniform"
        case .setStringThicknessGraduated:
            return "Graduated"
        case .setVisibilityAll:
            return "All"
        case .setVisibilityNaturalOnly:
            return "Natural"
        case .setVisibilityBCEFOnly:
            return "BCEF"
        case .setVisibilityAccidentalOnly:
            return "Accidental"
        case .setVisibilityNone:
            return "None"
        case .setSpellingSharp:
            return "Sharp"
        case .setSpellingFlat:
            return "Flat"
        case .toggleShowsOctave:
            return "Octave"
        case .setClefTreble:
            return "Treble"
        case .setClefBass:
            return "Bass"
        case .setPianoMovementScopeCascade:
            return "Cascade"
        case .setPianoMovementScopeRowOnly:
            return "Row Only"
        case .setPianoWhiteKeyStyleOutlined:
            return "Outlined"
        case .setPianoWhiteKeyStyleGapOnly:
            return "Gap Only"
        case .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return "Gloss"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .setRootModeExercise:
            return "Show the exercise page"
        case .setRootModePlay:
            return "Show the play page"
        case .setExerciseModeSingle:
            return "Train a single target note"
        case .setExerciseModeSequence:
            return "Train a generated note sequence"
        case .setExerciseModeP2:
            return "Train a generated note sequence with a fixed staff-over-fretboard stacked layout"
        case .setExerciseModeSr0:
            return "Train treble staff reading with a two-row natural note strip answer surface"
        case .setExerciseModeSr1:
            return "Train treble staff reading with a single-row piano answer surface"
        case .setExerciseModeSr2:
            return "Train treble staff reading with a two-row piano answer surface and exact-note matching"
        case .setExerciseModeFr0:
            return "Train full fretboard note-name coverage with a fixed left-prompt right-fretboard side layout"
        case .setExerciseModePositionPrompt:
            return "Train note names from a highlighted fretboard position"
        case .setCompositionPresetStaffToFretboard:
            return "Use the staff as the prompt surface and the fretboard as the answer surface"
        case .setCompositionPresetTargetPromptToFretboard:
            return "Use the target prompt as the prompt surface and the fretboard as the answer surface"
        case .setCompositionPresetFretboardToNaturalNoteStrip:
            return "Use the fretboard as the prompt surface and the natural note strip as the answer surface"
        case .setCompositionPresetFretboardSelfAnswer:
            return "Use a single fretboard as both the prompt surface and the answer surface"
        case .setLayoutPresetStacked:
            return "Arrange the exercise surfaces in a top and bottom stack"
        case .setLayoutPresetSideBySide:
            return "Arrange the exercise surfaces side by side"
        case .setLayoutPresetSingleSurface:
            return "Arrange the exercise as a single shared surface"
        case .setPositionPromptFilterModeNoteName:
            return "Filter highlighted fretboard positions by note name"
        case .setPositionPromptFilterModeFret:
            return "Filter highlighted fretboard positions by fret number"
        case .setAccessoryPresentationDocked:
            return "Attach accessories directly below the main exercise content"
        case .setAccessoryPresentationFloating:
            return "Show accessories as floating overlays"
        case .setAccessoryPresentationCollapsible:
            return "Show accessories in a collapsible area"
        case .setInstrumentGuitar6:
            return "Use 6-string guitar standard tuning"
        case .setInstrumentBass4:
            return "Use 4-string bass standard tuning"
        case .setInstrumentBass5:
            return "Use 5-string bass standard tuning"
        case .setDisplayModeHorizontal:
            return "Show fretboard in horizontal mode"
        case .setDisplayModeVertical:
            return "Show fretboard in vertical mode"
        case .setStringThicknessUniform:
            return "Render all strings with the same thickness"
        case .setStringThicknessGraduated:
            return "Render low strings thicker and high strings thinner"
        case .setVisibilityAll:
            return "Show all note labels"
        case .setVisibilityNaturalOnly:
            return "Show natural note labels only"
        case .setVisibilityBCEFOnly:
            return "Show B, C, E, and F note labels only"
        case .setVisibilityAccidentalOnly:
            return "Show accidental note labels only"
        case .setVisibilityNone:
            return "Hide all note labels"
        case .setSpellingSharp:
            return "Use sharp note spelling"
        case .setSpellingFlat:
            return "Use flat note spelling"
        case .toggleShowsOctave:
            return "Toggle octave display"
        case .setClefTreble:
            return "Use treble clef"
        case .setClefBass:
            return "Use bass clef"
        case .setPianoMovementScopeCascade:
            return "Make piano movement cascade across all visible rows"
        case .setPianoMovementScopeRowOnly:
            return "Restrict piano movement to the active row only"
        case .setPianoWhiteKeyStyleOutlined:
            return "Render white keys with individual outlines"
        case .setPianoWhiteKeyStyleGapOnly:
            return "Render white keys without outlines, using gaps between keys instead"
        case .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return "Render white keys with a skeuomorphic highlight and beveled shading"
        }
    }

    func isSelected(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .setRootModeExercise:
            return stateContext.rootMode == .exercise
        case .setRootModePlay:
            return stateContext.rootMode == .play
        case .setExerciseModeSingle:
            return stateContext.trainerDisplayState.exerciseMode == .single
        case .setExerciseModeSequence:
            return stateContext.trainerDisplayState.exerciseMode == .sequence
        case .setExerciseModeP2:
            return stateContext.trainerDisplayState.exerciseMode == .p2
        case .setExerciseModeSr0:
            return stateContext.trainerDisplayState.exerciseMode == .sr0
        case .setExerciseModeSr1:
            return stateContext.trainerDisplayState.exerciseMode == .sr1
        case .setExerciseModeSr2:
            return stateContext.trainerDisplayState.exerciseMode == .sr2
        case .setExerciseModeFr0:
            return stateContext.trainerDisplayState.exerciseMode == .fr0
        case .setExerciseModePositionPrompt:
            return stateContext.trainerDisplayState.exerciseMode == .positionPrompt
        case .setCompositionPresetStaffToFretboard:
            return stateContext.exerciseLayoutPreferences.compositionPreset
                == .staffToFretboard
        case .setCompositionPresetTargetPromptToFretboard:
            return stateContext.exerciseLayoutPreferences.compositionPreset
                == .targetPromptToFretboard
        case .setCompositionPresetFretboardToNaturalNoteStrip:
            return stateContext.exerciseLayoutPreferences.compositionPreset
                == .fretboardToNaturalNoteStrip
        case .setCompositionPresetFretboardSelfAnswer:
            return stateContext.exerciseLayoutPreferences.compositionPreset
                == .fretboardSelfAnswer
        case .setLayoutPresetStacked:
            return stateContext.exerciseLayoutPreferences.layoutPreset
                == .stacked
        case .setLayoutPresetSideBySide:
            return stateContext.exerciseLayoutPreferences.layoutPreset
                == .sideBySide
        case .setLayoutPresetSingleSurface:
            return stateContext.exerciseLayoutPreferences.layoutPreset
                == .singleSurface
        case .setPositionPromptFilterModeNoteName:
            return stateContext.trainerDisplayState.positionPromptConfiguration.filterMode == .noteName
        case .setPositionPromptFilterModeFret:
            return stateContext.trainerDisplayState.positionPromptConfiguration.filterMode == .fret
        case .setAccessoryPresentationDocked:
            return stateContext.exerciseLayoutPreferences.accessoryPresentation
                == .docked
        case .setAccessoryPresentationFloating:
            return stateContext.exerciseLayoutPreferences.accessoryPresentation
                == .floating
        case .setAccessoryPresentationCollapsible:
            return stateContext.exerciseLayoutPreferences.accessoryPresentation
                == .collapsible
        case .setInstrumentGuitar6:
            return stateContext.fretboardDisplayState.configuration.instrument == .guitar6
        case .setInstrumentBass4:
            return stateContext.fretboardDisplayState.configuration.instrument == .bass4
        case .setInstrumentBass5:
            return stateContext.fretboardDisplayState.configuration.instrument == .bass5
        case .setDisplayModeHorizontal:
            return stateContext.fretboardDisplayState.displayMode == .horizontal
        case .setDisplayModeVertical:
            return stateContext.fretboardDisplayState.displayMode == .vertical
        case .setStringThicknessUniform:
            return stateContext.fretboardDisplayState.configuration.stringThicknessStyle == .uniform
        case .setStringThicknessGraduated:
            return stateContext.fretboardDisplayState.configuration.stringThicknessStyle == .graduated
        case .setVisibilityAll:
            return stateContext.fretboardDisplayState.visibility == .all
        case .setVisibilityNaturalOnly:
            return stateContext.fretboardDisplayState.visibility == .naturalOnly
        case .setVisibilityBCEFOnly:
            return stateContext.fretboardDisplayState.visibility == .bcefOnly
        case .setVisibilityAccidentalOnly:
            return stateContext.fretboardDisplayState.visibility == .accidentalOnly
        case .setVisibilityNone:
            return stateContext.fretboardDisplayState.visibility == .none
        case .setSpellingSharp:
            return stateContext.fretboardDisplayState.spelling == .sharp
        case .setSpellingFlat:
            return stateContext.fretboardDisplayState.spelling == .flat
        case .toggleShowsOctave:
            return stateContext.fretboardDisplayState.showsOctave
        case .setClefTreble:
            return stateContext.staffDisplayState.configuration.clef == .treble
        case .setClefBass:
            return stateContext.staffDisplayState.configuration.clef == .bass
        case .setPianoMovementScopeCascade:
            return stateContext.pianoPanelState.movementScope == .cascade
        case .setPianoMovementScopeRowOnly:
            return stateContext.pianoPanelState.movementScope == .rowOnly
        case .setPianoWhiteKeyStyleOutlined:
            return stateContext.pianoPanelState.whiteKeyStyle == .outlined
        case .setPianoWhiteKeyStyleGapOnly:
            return stateContext.pianoPanelState.whiteKeyStyle == .borderlessSeparatedByGaps
        case .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return stateContext.pianoPanelState.whiteKeyStyle == .skeuomorphicHighlight
        }
    }

    func isEnabled(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .setRootModeExercise,
             .setRootModePlay:
            return true
        case .setCompositionPresetStaffToFretboard:
            return LegacyPageLayoutAdapter.isCompositionPresetSupported(
                .staffToFretboard,
                for: stateContext.trainerDisplayState.exerciseMode
            )
        case .setCompositionPresetTargetPromptToFretboard:
            return LegacyPageLayoutAdapter.isCompositionPresetSupported(
                .targetPromptToFretboard,
                for: stateContext.trainerDisplayState.exerciseMode
            )
        case .setCompositionPresetFretboardToNaturalNoteStrip:
            return LegacyPageLayoutAdapter.isCompositionPresetSupported(
                .fretboardToNaturalNoteStrip,
                for: stateContext.trainerDisplayState.exerciseMode
            )
        case .setCompositionPresetFretboardSelfAnswer:
            return LegacyPageLayoutAdapter.isCompositionPresetSupported(
                .fretboardSelfAnswer,
                for: stateContext.trainerDisplayState.exerciseMode
            )
        case .setLayoutPresetStacked:
            return LegacyPageLayoutAdapter.isLayoutPresetSupported(
                .stacked,
                in: stateContext
            )
        case .setLayoutPresetSideBySide:
            return LegacyPageLayoutAdapter.isLayoutPresetSupported(
                .sideBySide,
                in: stateContext
            )
        case .setLayoutPresetSingleSurface:
            return LegacyPageLayoutAdapter.isLayoutPresetSupported(
                .singleSurface,
                in: stateContext
            )
        case .setAccessoryPresentationDocked:
            return LegacyPageLayoutAdapter.isAccessoryPresentationSupported(
                .docked
            )
        case .setAccessoryPresentationFloating:
            return LegacyPageLayoutAdapter.isAccessoryPresentationSupported(
                .floating
            )
        case .setAccessoryPresentationCollapsible:
            return LegacyPageLayoutAdapter.isAccessoryPresentationSupported(
                .collapsible
            )
        case .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModeP2,
             .setExerciseModeSr0,
             .setExerciseModeSr1,
             .setExerciseModeSr2,
             .setExerciseModeFr0,
             .setExerciseModePositionPrompt,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
             .setStringThicknessUniform,
             .setStringThicknessGraduated,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityBCEFOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave,
             .setClefTreble,
             .setClefBass,
             .setPianoMovementScopeCascade,
             .setPianoMovementScopeRowOnly,
             .setPianoWhiteKeyStyleOutlined,
             .setPianoWhiteKeyStyleGapOnly,
             .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return true
        }
    }

    func apply(to displayState: inout FretboardDisplayState) {
        switch self {
        case .setRootModeExercise,
             .setRootModePlay,
             .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModeP2,
             .setExerciseModeSr0,
             .setExerciseModeSr1,
             .setExerciseModeSr2,
             .setExerciseModeFr0,
             .setExerciseModePositionPrompt,
             .setCompositionPresetStaffToFretboard,
             .setCompositionPresetTargetPromptToFretboard,
             .setCompositionPresetFretboardToNaturalNoteStrip,
             .setCompositionPresetFretboardSelfAnswer,
             .setLayoutPresetStacked,
             .setLayoutPresetSideBySide,
             .setLayoutPresetSingleSurface,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setAccessoryPresentationDocked,
             .setAccessoryPresentationFloating,
             .setAccessoryPresentationCollapsible,
             .setPianoMovementScopeCascade,
             .setPianoMovementScopeRowOnly,
             .setPianoWhiteKeyStyleOutlined,
             .setPianoWhiteKeyStyleGapOnly,
             .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return
        case .setInstrumentGuitar6:
            displayState.configuration.tuning = .standard(for: .guitar6)
        case .setInstrumentBass4:
            displayState.configuration.tuning = .standard(for: .bass4)
        case .setInstrumentBass5:
            displayState.configuration.tuning = .standard(for: .bass5)
        case .setDisplayModeHorizontal:
            displayState.setDisplayMode(.horizontal)
        case .setDisplayModeVertical:
            displayState.setDisplayMode(.vertical)
        case .setStringThicknessUniform:
            displayState.configuration.stringThicknessStyle = .uniform
        case .setStringThicknessGraduated:
            displayState.configuration.stringThicknessStyle = .graduated
        case .setVisibilityAll:
            displayState.visibility = .all
        case .setVisibilityNaturalOnly:
            displayState.visibility = .naturalOnly
        case .setVisibilityBCEFOnly:
            displayState.visibility = .bcefOnly
        case .setVisibilityAccidentalOnly:
            displayState.visibility = .accidentalOnly
        case .setVisibilityNone:
            displayState.visibility = .none
        case .setSpellingSharp:
            displayState.spelling = .sharp
        case .setSpellingFlat:
            displayState.spelling = .flat
        case .toggleShowsOctave:
            displayState.showsOctave.toggle()
        case .setClefTreble,
             .setClefBass:
            return
        }
    }

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case .setClefTreble:
            displayState.configuration.clef = .treble
        case .setClefBass:
            displayState.configuration.clef = .bass
        case .setRootModeExercise,
             .setRootModePlay,
             .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModeP2,
             .setExerciseModeSr0,
             .setExerciseModeSr1,
             .setExerciseModeSr2,
             .setExerciseModeFr0,
             .setExerciseModePositionPrompt,
             .setCompositionPresetStaffToFretboard,
             .setCompositionPresetTargetPromptToFretboard,
             .setCompositionPresetFretboardToNaturalNoteStrip,
             .setCompositionPresetFretboardSelfAnswer,
             .setLayoutPresetStacked,
             .setLayoutPresetSideBySide,
             .setLayoutPresetSingleSurface,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setAccessoryPresentationDocked,
             .setAccessoryPresentationFloating,
             .setAccessoryPresentationCollapsible,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
             .setStringThicknessUniform,
             .setStringThicknessGraduated,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityBCEFOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave,
             .setPianoMovementScopeCascade,
             .setPianoMovementScopeRowOnly,
             .setPianoWhiteKeyStyleOutlined,
             .setPianoWhiteKeyStyleGapOnly,
             .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return
        }
    }

    func apply(to displayState: inout TrainerDisplayState) {
        switch self {
        case .setRootModeExercise,
             .setRootModePlay:
            return
        case .setExerciseModeSingle:
            displayState.setExerciseMode(.single)
        case .setExerciseModeSequence:
            displayState.setExerciseMode(.sequence)
        case .setExerciseModeP2:
            displayState.setExerciseMode(.p2)
        case .setExerciseModeSr0:
            displayState.setExerciseMode(.sr0)
        case .setExerciseModeSr1:
            displayState.setExerciseMode(.sr1)
        case .setExerciseModeSr2:
            displayState.setExerciseMode(.sr2)
        case .setExerciseModeFr0:
            displayState.setExerciseMode(.fr0)
        case .setExerciseModePositionPrompt:
            displayState.setExerciseMode(.positionPrompt)
        case .setCompositionPresetStaffToFretboard,
             .setCompositionPresetTargetPromptToFretboard,
             .setCompositionPresetFretboardToNaturalNoteStrip,
             .setCompositionPresetFretboardSelfAnswer,
             .setLayoutPresetStacked,
             .setLayoutPresetSideBySide,
             .setLayoutPresetSingleSurface:
            return
        case .setPositionPromptFilterModeNoteName:
            displayState.setPositionPromptFilterMode(.noteName)
        case .setPositionPromptFilterModeFret:
            displayState.setPositionPromptFilterMode(.fret)
        case .setAccessoryPresentationDocked,
             .setAccessoryPresentationFloating,
             .setAccessoryPresentationCollapsible:
            return
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
             .setStringThicknessUniform,
             .setStringThicknessGraduated,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityBCEFOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave,
             .setClefTreble,
             .setClefBass,
             .setPianoMovementScopeCascade,
             .setPianoMovementScopeRowOnly,
             .setPianoWhiteKeyStyleOutlined,
             .setPianoWhiteKeyStyleGapOnly,
             .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return
        }
    }

    func apply(to pianoPanelState: inout PianoPanelState) {
        switch self {
        case .setRootModeExercise,
             .setRootModePlay:
            return
        case .setPianoMovementScopeCascade:
            pianoPanelState.movementScope = .cascade
        case .setPianoMovementScopeRowOnly:
            pianoPanelState.movementScope = .rowOnly
        case .setPianoWhiteKeyStyleOutlined:
            pianoPanelState.whiteKeyStyle = .outlined
        case .setPianoWhiteKeyStyleGapOnly:
            pianoPanelState.whiteKeyStyle = .borderlessSeparatedByGaps
        case .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            pianoPanelState.whiteKeyStyle = .skeuomorphicHighlight
        case .setCompositionPresetStaffToFretboard,
             .setCompositionPresetTargetPromptToFretboard,
             .setCompositionPresetFretboardToNaturalNoteStrip,
             .setCompositionPresetFretboardSelfAnswer,
             .setLayoutPresetStacked,
             .setLayoutPresetSideBySide,
             .setLayoutPresetSingleSurface,
             .setAccessoryPresentationDocked,
             .setAccessoryPresentationFloating,
             .setAccessoryPresentationCollapsible:
            return
        case .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModeP2,
             .setExerciseModeSr0,
             .setExerciseModeSr1,
             .setExerciseModeSr2,
             .setExerciseModeFr0,
             .setExerciseModePositionPrompt,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
             .setStringThicknessUniform,
             .setStringThicknessGraduated,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityBCEFOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave,
             .setClefTreble,
             .setClefBass:
            return
        }
    }

    func apply(
        to exerciseLayoutPreferences: inout ExerciseLayoutPreferences
    ) {
        switch self {
        case .setRootModeExercise,
             .setRootModePlay:
            return
        case .setCompositionPresetStaffToFretboard:
            exerciseLayoutPreferences.compositionPreset = .staffToFretboard
        case .setCompositionPresetTargetPromptToFretboard:
            exerciseLayoutPreferences.compositionPreset = .targetPromptToFretboard
        case .setCompositionPresetFretboardToNaturalNoteStrip:
            exerciseLayoutPreferences.compositionPreset = .fretboardToNaturalNoteStrip
        case .setCompositionPresetFretboardSelfAnswer:
            exerciseLayoutPreferences.compositionPreset = .fretboardSelfAnswer
        case .setLayoutPresetStacked:
            exerciseLayoutPreferences.layoutPreset = .stacked
        case .setLayoutPresetSideBySide:
            exerciseLayoutPreferences.layoutPreset = .sideBySide
        case .setLayoutPresetSingleSurface:
            exerciseLayoutPreferences.layoutPreset = .singleSurface
        case .setAccessoryPresentationDocked:
            exerciseLayoutPreferences.accessoryPresentation = .docked
        case .setAccessoryPresentationFloating:
            exerciseLayoutPreferences.accessoryPresentation = .floating
        case .setAccessoryPresentationCollapsible:
            exerciseLayoutPreferences.accessoryPresentation = .collapsible
        case .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModeP2,
             .setExerciseModeSr0,
             .setExerciseModeSr1,
             .setExerciseModeSr2,
             .setExerciseModeFr0,
             .setExerciseModePositionPrompt,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
             .setStringThicknessUniform,
             .setStringThicknessGraduated,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityBCEFOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave,
             .setClefTreble,
             .setClefBass,
             .setPianoMovementScopeCascade,
             .setPianoMovementScopeRowOnly,
             .setPianoWhiteKeyStyleOutlined,
             .setPianoWhiteKeyStyleGapOnly,
             .setPianoWhiteKeyStyleSkeuomorphicHighlight:
            return
        }
    }

    func apply(to stateContext: inout SettingsPanelStateContext) {
        switch self {
        case .setRootModeExercise:
            stateContext.rootMode = .exercise
        case .setRootModePlay:
            stateContext.rootMode = .play
        default:
            break
        }
        apply(to: &stateContext.fretboardDisplayState)
        apply(to: &stateContext.staffDisplayState)
        apply(to: &stateContext.exerciseLayoutPreferences)
        apply(to: &stateContext.trainerDisplayState)
        apply(to: &stateContext.pianoPanelState)
        stateContext.reconcileForCurrentMode()
    }
}

struct SettingsChoiceItem: Equatable, Hashable, Sendable {
    var id: SettingsActionID
    var title: String
    var accessibilityLabel: String
    var isSelected: Bool
    var isEnabled: Bool
}

struct SettingsChoiceRow: Equatable, Sendable {
    var id: SettingsChoiceRowID
    var title: String
    var accessibilityLabel: String
    var selectionStyle: SettingsSelectionStyle
    var presentationStyle: SettingsPresentationStyle
    var choices: [SettingsChoiceItem]
}

struct SettingsPositionFilterItem: Equatable, Hashable, Sendable {
    var id: SettingsPositionFilterOptionID
    var title: String
    var accessibilityLabel: String
    var isSelected: Bool
    var isEnabled: Bool
}

struct SettingsPositionFilterRow: Equatable, Sendable {
    var id: SettingsPositionFilterRowID
    var title: String
    var accessibilityLabel: String
    var options: [SettingsPositionFilterItem]
}

enum SettingsToggleID: CaseIterable, Equatable, Hashable, Sendable {
    case showsComponentBounds
    case showsSideBySideContainerOutlines
    case naturalStripVisible
    case pianoAccessoryVisible
    case accessoryExpanded
    case pianoSnapEnabled

    var sectionID: SettingsSectionID {
        switch self {
        case .showsComponentBounds,
             .showsSideBySideContainerOutlines:
            return .debug
        case .naturalStripVisible,
             .pianoAccessoryVisible,
             .accessoryExpanded:
            return .accessories
        case .pianoSnapEnabled:
            return .piano
        }
    }

    var title: String {
        switch self {
        case .showsComponentBounds:
            return "Component Bounds"
        case .showsSideBySideContainerOutlines:
            return "Side Container Borders"
        case .naturalStripVisible:
            return "Natural Strip Visible"
        case .pianoAccessoryVisible:
            return "Piano Accessory Visible"
        case .accessoryExpanded:
            return "Accessory Expanded"
        case .pianoSnapEnabled:
            return "Snap Drag"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .showsComponentBounds:
            return "Toggle green bounds overlay for fretboard and staff"
        case .showsSideBySideContainerOutlines:
            return "Toggle red and blue borders for the side layout containers"
        case .naturalStripVisible:
            return "Toggle whether the natural note strip participates as an accessory surface"
        case .pianoAccessoryVisible:
            return "Toggle whether the piano participates as an accessory surface"
        case .accessoryExpanded:
            return "Toggle whether the accessory area starts expanded"
        case .pianoSnapEnabled:
            return "Toggle whether piano scale dragging snaps to semitone alignment when released"
        }
    }

    func resolvedValue(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .showsComponentBounds:
            return stateContext.fretboardDisplayState.showsComponentBoundsOverlay
                || stateContext.staffDisplayState.showsComponentBoundsOverlay
        case .showsSideBySideContainerOutlines:
            return stateContext.debugState.showsSideBySideContainerOutlines
        case .naturalStripVisible:
            return stateContext.exerciseLayoutPreferences.isNaturalNoteStripVisible
        case .pianoAccessoryVisible:
            return stateContext.exerciseLayoutPreferences.isPianoAccessoryVisible
        case .accessoryExpanded:
            return stateContext.exerciseLayoutPreferences.isAccessoryExpanded
        case .pianoSnapEnabled:
            return stateContext.pianoPanelState.snapEnabled
        }
    }

    func isEnabled(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .showsComponentBounds,
             .showsSideBySideContainerOutlines,
             .pianoAccessoryVisible,
             .pianoSnapEnabled:
            return true
        case .naturalStripVisible:
            return LegacyPageLayoutAdapter.isNaturalStripToggleSupported(
                in: stateContext
            )
        case .accessoryExpanded:
            return LegacyPageLayoutAdapter.isAccessoryExpandedSupported(
                accessoryPresentation: stateContext.exerciseLayoutPreferences
                    .accessoryPresentation
            )
        }
    }

    func apply(value: Bool, to displayState: inout FretboardDisplayState) {
        switch self {
        case .showsComponentBounds:
            displayState.showsComponentBoundsOverlay = value
        case .showsSideBySideContainerOutlines,
             .naturalStripVisible,
             .pianoAccessoryVisible,
             .accessoryExpanded,
             .pianoSnapEnabled:
            return
        }
    }

    func apply(value: Bool, to displayState: inout StaffDisplayState) {
        switch self {
        case .showsComponentBounds:
            displayState.showsComponentBoundsOverlay = value
        case .showsSideBySideContainerOutlines,
             .naturalStripVisible,
             .pianoAccessoryVisible,
             .accessoryExpanded,
             .pianoSnapEnabled:
            return
        }
    }

    func apply(
        value: Bool,
        to stateContext: inout SettingsPanelStateContext
    ) {
        switch self {
        case .showsComponentBounds:
            apply(value: value, to: &stateContext.fretboardDisplayState)
            apply(value: value, to: &stateContext.staffDisplayState)
        case .showsSideBySideContainerOutlines:
            stateContext.debugState.showsSideBySideContainerOutlines = value
        case .naturalStripVisible:
            stateContext.exerciseLayoutPreferences.isNaturalNoteStripVisible = value
            stateContext.reconcileForCurrentMode()
        case .pianoAccessoryVisible:
            stateContext.exerciseLayoutPreferences.isPianoAccessoryVisible = value
            stateContext.reconcileForCurrentMode()
        case .accessoryExpanded:
            stateContext.exerciseLayoutPreferences.isAccessoryExpanded = value
            stateContext.reconcileForCurrentMode()
        case .pianoSnapEnabled:
            stateContext.pianoPanelState.snapEnabled = value
        }
    }
}

struct SettingsToggleRow: Equatable, Sendable {
    var id: SettingsToggleID
    var title: String
    var accessibilityLabel: String
    var isOn: Bool
    var isEnabled: Bool
}

enum SettingsSliderID: CaseIterable, Equatable, Hashable, Sendable {
    case clefScale
    case clefVerticalTrim
    case clefAnchorYOffset
    case verticalHostHeightRatio
    case pianoRowCount

    var sectionID: SettingsSectionID {
        switch self {
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
            return .staff
        case .verticalHostHeightRatio:
            return .fretboard
        case .pianoRowCount:
            return .piano
        }
    }

    var title: String {
        switch self {
        case .clefScale:
            return "Scale"
        case .clefVerticalTrim:
            return "Vertical Clip"
        case .clefAnchorYOffset:
            return "Anchor Y Offset"
        case .verticalHostHeightRatio:
            return "Vertical Viewport Height"
        case .pianoRowCount:
            return "Rows"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .clefScale:
            return "Adjust clef scale"
        case .clefVerticalTrim:
            return "Adjust clef vertical clip"
        case .clefAnchorYOffset:
            return "Adjust clef anchor vertical offset"
        case .verticalHostHeightRatio:
            return "Adjust the visible height of the vertical fretboard viewport. Increasing height may require horizontal scrolling."
        case .pianoRowCount:
            return "Adjust the number of visible piano rows"
        }
    }

    var range: ClosedRange<CGFloat> {
        switch self {
        case .clefScale:
            return 1.0...5
        case .clefVerticalTrim:
            return 0...0.4
        case .clefAnchorYOffset:
            return (-0.25)...0.25
        case .verticalHostHeightRatio:
            return FretboardDisplayState.verticalHostHeightRatioRange
        case .pianoRowCount:
            return CGFloat(PianoPanelState.supportedRowCountRange.lowerBound)
                ... CGFloat(PianoPanelState.supportedRowCountRange.upperBound)
        }
    }

    func resolvedValue(
        in stateContext: SettingsPanelStateContext
    ) -> CGFloat {
        switch self {
        case .clefScale:
            return stateContext.staffDisplayState.configuration.layoutMetrics.clefScale
        case .clefVerticalTrim:
            return stateContext.staffDisplayState.configuration.clefVerticalTrimRatio(
                for: stateContext.staffDisplayState.configuration.clef
            )
        case .clefAnchorYOffset:
            return stateContext.staffDisplayState.configuration.clefAnchorLogicalDownwardShiftRatio(
                for: stateContext.staffDisplayState.configuration.clef
            )
        case .verticalHostHeightRatio:
            return stateContext.fretboardDisplayState.verticalHostHeightRatio
        case .pianoRowCount:
            return CGFloat(stateContext.pianoPanelState.resolvedRowCount)
        }
    }

    func isEnabled(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset, .pianoRowCount:
            return true
        case .verticalHostHeightRatio:
            return stateContext.showsVerticalViewportHeightControl
        }
    }

    func displayValue(for value: CGFloat) -> String {
        switch self {
        case .clefScale:
            return String(format: "%.2fx", Double(value))
        case .clefVerticalTrim:
            return String(format: "%.0f%%", Double(value * 100))
        case .clefAnchorYOffset:
            let normalizedValue: CGFloat = abs(value) < 0.005 ? 0 : value
            return String(format: "%+.2f", Double(normalizedValue))
        case .verticalHostHeightRatio:
            return String(format: "%.0f%%", Double(value * 100))
        case .pianoRowCount:
            return "\(Int(value.rounded()))"
        }
    }

    func clampedValue(_ value: CGFloat) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    func apply(value: CGFloat, to displayState: inout FretboardDisplayState) {
        switch self {
        case .verticalHostHeightRatio:
            displayState.setVerticalHostHeightRatio(
                clampedValue(value)
            )
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset, .pianoRowCount:
            return
        }
    }

    func apply(value: CGFloat, to displayState: inout StaffDisplayState) {
        let clampedValue = clampedValue(value)

        switch self {
        case .clefScale:
            displayState.configuration.layoutMetrics.clefScale = clampedValue
        case .clefVerticalTrim:
            displayState.configuration.setClefVerticalTrimRatio(
                clampedValue,
                for: displayState.configuration.clef
            )
        case .clefAnchorYOffset:
            displayState.configuration.setClefAnchorLogicalDownwardShiftRatio(
                clampedValue,
                for: displayState.configuration.clef
            )
        case .verticalHostHeightRatio, .pianoRowCount:
            return
        }
    }

    func apply(
        value: CGFloat,
        to stateContext: inout SettingsPanelStateContext
    ) {
        switch self {
        case .pianoRowCount:
            stateContext.pianoPanelState.rowCount = Int(clampedValue(value).rounded())
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset, .verticalHostHeightRatio:
            apply(value: value, to: &stateContext.fretboardDisplayState)
            apply(value: value, to: &stateContext.staffDisplayState)
        }
    }
}

struct SettingsSliderRow: Equatable, Sendable {
    var id: SettingsSliderID
    var title: String
    var accessibilityLabel: String
    var value: CGFloat
    var range: ClosedRange<CGFloat>
    var displayValue: String
    var isEnabled: Bool
}

enum SettingsRow: Equatable, Sendable {
    case choice(SettingsChoiceRow)
    case positionFilter(SettingsPositionFilterRow)
    case slider(SettingsSliderRow)
    case toggle(SettingsToggleRow)

    var id: SettingsRowID {
        switch self {
        case let .choice(row):
            return .choice(row.id)
        case let .positionFilter(row):
            return .positionFilter(row.id)
        case let .slider(row):
            return .slider(row.id)
        case let .toggle(row):
            return .toggle(row.id)
        }
    }
}

struct SettingsSection: Equatable, Sendable {
    var id: SettingsSectionID
    var title: String
    var rows: [SettingsRow]
}

struct SettingsPanelModel: Equatable, Sendable {
    var sections: [SettingsSection]

    static let empty = SettingsPanelModel(sections: [])

    var rows: [SettingsRow] {
        sections.flatMap(\.rows)
    }

    func choiceRow(for id: SettingsChoiceRowID) -> SettingsChoiceRow? {
        rows.compactMap { row in
            guard case let .choice(choiceRow) = row else {
                return nil
            }

            return choiceRow
        }.first { $0.id == id }
    }

    func positionFilterRow(
        for id: SettingsPositionFilterRowID
    ) -> SettingsPositionFilterRow? {
        rows.compactMap { row in
            guard case let .positionFilter(positionFilterRow) = row else {
                return nil
            }

            return positionFilterRow
        }.first { $0.id == id }
    }

    func sliderRow(for id: SettingsSliderID) -> SettingsSliderRow? {
        rows.compactMap { row in
            guard case let .slider(sliderRow) = row else {
                return nil
            }

            return sliderRow
        }.first { $0.id == id }
    }

    func toggleRow(for id: SettingsToggleID) -> SettingsToggleRow? {
        rows.compactMap { row in
            guard case let .toggle(toggleRow) = row else {
                return nil
            }

            return toggleRow
        }.first { $0.id == id }
    }
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case togglePositionFilterOption(
        SettingsPositionFilterRowID,
        SettingsPositionFilterOptionID
    )
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)

    func apply(
        to stateContext: inout SettingsPanelStateContext
    ) {
        switch self {
        case let .triggerAction(actionID):
            actionID.apply(to: &stateContext)
        case let .togglePositionFilterOption(rowID, optionID):
            switch rowID {
            case .positionQuestionPitchClasses:
                guard case let .pitchClass(pitchClass) = optionID else {
                    return
                }
                stateContext.trainerDisplayState.togglePositionQuestionPitchClass(
                    pitchClass
                )
            case .positionPromptFilterOptions:
                switch optionID {
                case let .pitchClass(pitchClass):
                    stateContext.trainerDisplayState
                        .togglePositionPromptPitchClass(
                            pitchClass
                        )
                case let .fret(fret):
                    stateContext.trainerDisplayState.togglePositionPromptFret(
                        fret
                    )
                }
            }
        case let .setSliderValue(sliderID, value):
            sliderID.apply(value: value, to: &stateContext)
        case let .setToggleValue(toggleID, value):
            toggleID.apply(value: value, to: &stateContext)
        }
    }
}

extension StaffClef {
    var settingsActionID: SettingsActionID {
        switch self {
        case .treble:
            return .setClefTreble
        case .bass:
            return .setClefBass
        }
    }
}

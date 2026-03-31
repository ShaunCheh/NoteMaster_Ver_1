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
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    var title: String {
        switch self {
        case .page:
            return "Page"
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
        case .page:
            return [
                .choice(.topContent),
                .choice(.mainContent)
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
                .toggle(.pianoVisible),
                .slider(.pianoRowCount),
                .choice(.pianoMovementScope),
                .choice(.pianoWhiteKeyStyle),
                .toggle(.pianoSnapEnabled)
            ]
        case .debug:
            return [
                .toggle(.showsComponentBounds)
            ]
        }
    }
}

enum SettingsPositionFilterRowID: CaseIterable, Equatable, Hashable, Sendable {
    case positionPromptFilterOptions

    var sectionID: SettingsSectionID {
        switch self {
        case .positionPromptFilterOptions:
            return .trainer
        }
    }

    var supportedFrets: ClosedRange<Int> {
        switch self {
        case .positionPromptFilterOptions:
            return TrainerPositionPromptConfiguration.supportedFretRange
        }
    }

    var supportedPitchClasses: [PitchClass] {
        switch self {
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
    case topContent
    case mainContent
    case exerciseMode
    case positionPromptFilterMode
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef
    case pianoMovementScope
    case pianoWhiteKeyStyle

    var sectionID: SettingsSectionID {
        switch self {
        case .topContent, .mainContent:
            return .page
        case .exerciseMode, .positionPromptFilterMode:
            return .trainer
        case .instrument, .displayMode, .labels, .spelling, .octave:
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
        case .topContent:
            return "Top Content"
        case .mainContent:
            return "Main Content"
        case .exerciseMode:
            return "Exercise Mode"
        case .positionPromptFilterMode:
            return "Filter"
        case .instrument:
            return "Instrument"
        case .displayMode:
            return "Display"
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
        case .topContent:
            return "Select top content"
        case .mainContent:
            return "Select main content"
        case .exerciseMode:
            return "Select exercise mode"
        case .positionPromptFilterMode:
            return "Select which position filter mode is active"
        case .instrument:
            return "Select instrument"
        case .displayMode:
            return "Select display mode"
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
        case .topContent,
             .mainContent,
             .exerciseMode,
             .positionPromptFilterMode,
             .instrument,
             .displayMode,
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
        case .topContent,
             .mainContent,
             .exerciseMode,
             .positionPromptFilterMode,
             .clef,
             .pianoMovementScope,
             .pianoWhiteKeyStyle:
            return .segmented
        case .instrument, .displayMode, .labels, .spelling, .octave:
            return .chips
        }
    }

    var actionIDs: [SettingsActionID] {
        switch self {
        case .topContent:
            return [
                .setTopContentStaff,
                .setTopContentTargetPrompt,
                .setTopContentFretboard
            ]
        case .mainContent:
            return [
                .setMainContentFretboard,
                .setMainContentNaturalNotes
            ]
        case .exerciseMode:
            return [
                .setExerciseModeSingle,
                .setExerciseModeSequence,
                .setExerciseModePositionPrompt
            ]
        case .positionPromptFilterMode:
            return [
                .setPositionPromptFilterModeNoteName,
                .setPositionPromptFilterModeFret
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
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setTopContentFretboard
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModePositionPrompt
    case setPositionPromptFilterModeNoteName
    case setPositionPromptFilterModeFret
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
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
        case .setTopContentStaff,
             .setTopContentTargetPrompt,
             .setTopContentFretboard:
            return .topContent
        case .setMainContentFretboard,
             .setMainContentNaturalNotes:
            return .mainContent
        case .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModePositionPrompt:
            return .exerciseMode
        case .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret:
            return .positionPromptFilterMode
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5:
            return .instrument
        case .setDisplayModeHorizontal,
             .setDisplayModeVertical:
            return .displayMode
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
        case .setTopContentStaff:
            return "Staff"
        case .setTopContentTargetPrompt:
            return "Target"
        case .setTopContentFretboard:
            return "Fretboard"
        case .setMainContentFretboard:
            return "Fretboard"
        case .setMainContentNaturalNotes:
            return "Natural Notes"
        case .setExerciseModeSingle:
            return "Single"
        case .setExerciseModeSequence:
            return "Sequence"
        case .setExerciseModePositionPrompt:
            return "Position"
        case .setPositionPromptFilterModeNoteName:
            return "Note Names"
        case .setPositionPromptFilterModeFret:
            return "Frets"
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
        case .setTopContentStaff:
            return "Show staff in the top content area"
        case .setTopContentTargetPrompt:
            return "Show target note prompt in the top content area"
        case .setTopContentFretboard:
            return "Show fretboard in the top content area"
        case .setMainContentFretboard:
            return "Show fretboard in the main content area"
        case .setMainContentNaturalNotes:
            return "Show natural note buttons in the main content area"
        case .setExerciseModeSingle:
            return "Train a single target note"
        case .setExerciseModeSequence:
            return "Train a generated note sequence"
        case .setExerciseModePositionPrompt:
            return "Train note names from a highlighted fretboard position"
        case .setPositionPromptFilterModeNoteName:
            return "Filter highlighted fretboard positions by note name"
        case .setPositionPromptFilterModeFret:
            return "Filter highlighted fretboard positions by fret number"
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
        case .setTopContentStaff:
            return stateContext.pageDisplayState.topContentMode == .staff
        case .setTopContentTargetPrompt:
            return stateContext.pageDisplayState.topContentMode == .targetPrompt
        case .setTopContentFretboard:
            return stateContext.pageDisplayState.topContentMode == .fretboard
        case .setMainContentFretboard:
            return stateContext.pageDisplayState.mainContentMode == .fretboard
        case .setMainContentNaturalNotes:
            return stateContext.pageDisplayState.mainContentMode == .naturalNoteStrip
        case .setExerciseModeSingle:
            return stateContext.trainerDisplayState.exerciseMode == .single
        case .setExerciseModeSequence:
            return stateContext.trainerDisplayState.exerciseMode == .sequence
        case .setExerciseModePositionPrompt:
            return stateContext.trainerDisplayState.exerciseMode == .positionPrompt
        case .setPositionPromptFilterModeNoteName:
            return stateContext.trainerDisplayState.positionPromptConfiguration.filterMode == .noteName
        case .setPositionPromptFilterModeFret:
            return stateContext.trainerDisplayState.positionPromptConfiguration.filterMode == .fret
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
        in _: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .setTopContentStaff,
             .setTopContentTargetPrompt,
             .setMainContentFretboard,
             .setMainContentNaturalNotes,
             .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModePositionPrompt,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
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
        case .setTopContentFretboard:
            return false
        }
    }

    func apply(to displayState: inout FretboardDisplayState) {
        switch self {
        case .setTopContentStaff,
             .setTopContentTargetPrompt,
             .setTopContentFretboard,
             .setMainContentFretboard,
             .setMainContentNaturalNotes,
             .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModePositionPrompt,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
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
        case .setTopContentStaff,
             .setTopContentTargetPrompt,
             .setTopContentFretboard,
             .setMainContentFretboard,
             .setMainContentNaturalNotes,
             .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModePositionPrompt,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
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

    func apply(to displayState: inout PageDisplayState) {
        switch self {
        case .setTopContentStaff:
            displayState.setTopContentMode(.staff)
        case .setTopContentTargetPrompt:
            displayState.setTopContentMode(.targetPrompt)
        case .setTopContentFretboard:
            displayState.setTopContentMode(.fretboard)
        case .setMainContentFretboard:
            displayState.setMainContentMode(.fretboard)
        case .setMainContentNaturalNotes:
            displayState.setMainContentMode(.naturalNoteStrip)
        case .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModePositionPrompt,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
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

    func apply(to displayState: inout TrainerDisplayState) {
        switch self {
        case .setExerciseModeSingle:
            displayState.setExerciseMode(.single)
        case .setExerciseModeSequence:
            displayState.setExerciseMode(.sequence)
        case .setExerciseModePositionPrompt:
            displayState.setExerciseMode(.positionPrompt)
        case .setPositionPromptFilterModeNoteName:
            displayState.setPositionPromptFilterMode(.noteName)
        case .setPositionPromptFilterModeFret:
            displayState.setPositionPromptFilterMode(.fret)
        case .setTopContentStaff,
             .setTopContentTargetPrompt,
             .setTopContentFretboard,
             .setMainContentFretboard,
             .setMainContentNaturalNotes,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
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
        case .setTopContentStaff,
             .setTopContentTargetPrompt,
             .setTopContentFretboard,
             .setMainContentFretboard,
             .setMainContentNaturalNotes,
             .setExerciseModeSingle,
             .setExerciseModeSequence,
             .setExerciseModePositionPrompt,
             .setPositionPromptFilterModeNoteName,
             .setPositionPromptFilterModeFret,
             .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
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

    func apply(to stateContext: inout SettingsPanelStateContext) {
        apply(to: &stateContext.fretboardDisplayState)
        apply(to: &stateContext.staffDisplayState)
        apply(to: &stateContext.pageDisplayState)
        apply(to: &stateContext.trainerDisplayState)
        apply(to: &stateContext.pianoPanelState)
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
    case pianoVisible
    case pianoSnapEnabled

    var sectionID: SettingsSectionID {
        switch self {
        case .showsComponentBounds:
            return .debug
        case .pianoVisible, .pianoSnapEnabled:
            return .piano
        }
    }

    var title: String {
        switch self {
        case .showsComponentBounds:
            return "Component Bounds"
        case .pianoVisible:
            return "Visible"
        case .pianoSnapEnabled:
            return "Snap Drag"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .showsComponentBounds:
            return "Toggle green bounds overlay for fretboard and staff"
        case .pianoVisible:
            return "Toggle whether the piano demo is visible in the page layout"
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
        case .pianoVisible:
            return stateContext.pianoPanelState.isVisible
        case .pianoSnapEnabled:
            return stateContext.pianoPanelState.snapEnabled
        }
    }

    func isEnabled(
        in _: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .showsComponentBounds, .pianoVisible, .pianoSnapEnabled:
            return true
        }
    }

    func apply(value: Bool, to displayState: inout FretboardDisplayState) {
        switch self {
        case .showsComponentBounds:
            displayState.showsComponentBoundsOverlay = value
        case .pianoVisible, .pianoSnapEnabled:
            return
        }
    }

    func apply(value: Bool, to displayState: inout StaffDisplayState) {
        switch self {
        case .showsComponentBounds:
            displayState.showsComponentBoundsOverlay = value
        case .pianoVisible, .pianoSnapEnabled:
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
        case .pianoVisible:
            stateContext.pianoPanelState.isVisible = value
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
            return .layout
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
            return "Viewport Height"
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
            return "Adjust vertical fretboard viewport height. Increasing height may require horizontal scrolling."
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
            return stateContext.fretboardDisplayState.displayMode == .vertical
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
    case togglePositionPromptFilterOption(SettingsPositionFilterOptionID)
    case setSliderValue(SettingsSliderID, CGFloat)
    case setToggleValue(SettingsToggleID, Bool)

    func apply(
        to stateContext: inout SettingsPanelStateContext
    ) {
        switch self {
        case let .triggerAction(actionID):
            actionID.apply(to: &stateContext)
        case let .togglePositionPromptFilterOption(optionID):
            switch optionID {
            case let .pitchClass(pitchClass):
                stateContext.trainerDisplayState.togglePositionPromptPitchClass(
                    pitchClass
                )
            case let .fret(fret):
                stateContext.trainerDisplayState.togglePositionPromptFret(fret)
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

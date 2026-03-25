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
    case slider(SettingsSliderID)
}

enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case layout

    var title: String {
        switch self {
        case .fretboard:
            return "Fretboard"
        case .staff:
            return "Staff"
        case .layout:
            return "Layout"
        }
    }

    var rowIDs: [SettingsRowID] {
        switch self {
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
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef

    var sectionID: SettingsSectionID {
        switch self {
        case .instrument, .displayMode, .labels, .spelling, .octave:
            return .fretboard
        case .clef:
            return .staff
        }
    }

    var title: String {
        switch self {
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
        }
    }

    var accessibilityLabel: String {
        switch self {
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
        }
    }

    var selectionStyle: SettingsSelectionStyle {
        switch self {
        case .instrument, .displayMode, .labels, .spelling, .clef:
            return .singleSelection
        case .octave:
            return .independent
        }
    }

    var presentationStyle: SettingsPresentationStyle {
        switch self {
        case .clef:
            return .segmented
        case .instrument, .displayMode, .labels, .spelling, .octave:
            return .chips
        }
    }

    var actionIDs: [SettingsActionID] {
        switch self {
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
        }
    }
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
    case setClefTreble
    case setClefBass

    var rowID: SettingsChoiceRowID {
        switch self {
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5:
            return .instrument
        case .setDisplayModeHorizontal,
             .setDisplayModeVertical:
            return .displayMode
        case .setVisibilityAll,
             .setVisibilityNaturalOnly,
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
        }
    }

    var title: String {
        switch self {
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
        }
    }

    var accessibilityLabel: String {
        switch self {
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
        }
    }

    func isSelected(
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> Bool {
        switch self {
        case .setInstrumentGuitar6:
            return fretboardDisplayState.configuration.instrument == .guitar6
        case .setInstrumentBass4:
            return fretboardDisplayState.configuration.instrument == .bass4
        case .setInstrumentBass5:
            return fretboardDisplayState.configuration.instrument == .bass5
        case .setDisplayModeHorizontal:
            return fretboardDisplayState.displayMode == .horizontal
        case .setDisplayModeVertical:
            return fretboardDisplayState.displayMode == .vertical
        case .setVisibilityAll:
            return fretboardDisplayState.visibility == .all
        case .setVisibilityNaturalOnly:
            return fretboardDisplayState.visibility == .naturalOnly
        case .setVisibilityAccidentalOnly:
            return fretboardDisplayState.visibility == .accidentalOnly
        case .setVisibilityNone:
            return fretboardDisplayState.visibility == .none
        case .setSpellingSharp:
            return fretboardDisplayState.spelling == .sharp
        case .setSpellingFlat:
            return fretboardDisplayState.spelling == .flat
        case .toggleShowsOctave:
            return fretboardDisplayState.showsOctave
        case .setClefTreble:
            return staffDisplayState.configuration.clef == .treble
        case .setClefBass:
            return staffDisplayState.configuration.clef == .bass
        }
    }

    func isEnabled(
        fretboardDisplayState _: FretboardDisplayState,
        staffDisplayState _: StaffDisplayState
    ) -> Bool {
        switch self {
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave,
             .setClefTreble,
             .setClefBass:
            return true
        }
    }

    func apply(to displayState: inout FretboardDisplayState) {
        switch self {
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
        case .setClefTreble, .setClefBass:
            return
        }
    }

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case .setClefTreble:
            displayState.configuration.clef = .treble
        case .setClefBass:
            displayState.configuration.clef = .bass
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setDisplayModeHorizontal,
             .setDisplayModeVertical,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave:
            return
        }
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

enum SettingsSliderID: CaseIterable, Equatable, Hashable, Sendable {
    case clefScale
    case clefVerticalTrim
    case clefAnchorYOffset
    case verticalHostHeightRatio

    var sectionID: SettingsSectionID {
        switch self {
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
            return .staff
        case .verticalHostHeightRatio:
            return .layout
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
            return "Height"
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
            return "Adjust vertical fretboard height"
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
        }
    }

    func resolvedValue(
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> CGFloat {
        switch self {
        case .clefScale:
            return staffDisplayState.configuration.layoutMetrics.clefScale
        case .clefVerticalTrim:
            return staffDisplayState.configuration.clefVerticalTrimRatio(
                for: staffDisplayState.configuration.clef
            )
        case .clefAnchorYOffset:
            return staffDisplayState.configuration.clefAnchorLogicalDownwardShiftRatio(
                for: staffDisplayState.configuration.clef
            )
        case .verticalHostHeightRatio:
            return fretboardDisplayState.verticalHostHeightRatio
        }
    }

    func isEnabled(
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState _: StaffDisplayState
    ) -> Bool {
        switch self {
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
            return true
        case .verticalHostHeightRatio:
            return fretboardDisplayState.displayMode == .vertical
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
        case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
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
        case .verticalHostHeightRatio:
            return
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
    case slider(SettingsSliderRow)

    var id: SettingsRowID {
        switch self {
        case let .choice(row):
            return .choice(row.id)
        case let .slider(row):
            return .slider(row.id)
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

    func sliderRow(for id: SettingsSliderID) -> SettingsSliderRow? {
        rows.compactMap { row in
            guard case let .slider(sliderRow) = row else {
                return nil
            }

            return sliderRow
        }.first { $0.id == id }
    }
}

enum SettingsPanelEvent: Equatable, Sendable {
    case triggerAction(SettingsActionID)
    case setSliderValue(SettingsSliderID, CGFloat)

    func apply(
        to fretboardDisplayState: inout FretboardDisplayState,
        and staffDisplayState: inout StaffDisplayState
    ) {
        switch self {
        case let .triggerAction(actionID):
            actionID.apply(to: &fretboardDisplayState)
            actionID.apply(to: &staffDisplayState)
        case let .setSliderValue(sliderID, value):
            sliderID.apply(value: value, to: &fretboardDisplayState)
            sliderID.apply(value: value, to: &staffDisplayState)
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

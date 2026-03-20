//
//  ButtonPanelModel.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

enum ButtonPanelSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case instrument
    case labels
    case spelling
    case octave

    var title: String {
        switch self {
        case .instrument:
            return "Instrument"
        case .labels:
            return "Labels"
        case .spelling:
            return "Spelling"
        case .octave:
            return "Octave"
        }
    }

    var selectionStyle: ButtonPanelSelectionStyle {
        switch self {
        case .instrument, .labels, .spelling:
            return .singleSelection
        case .octave:
            return .independent
        }
    }
}

enum ButtonPanelSelectionStyle: Equatable, Sendable {
    case singleSelection
    case independent
}

enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave

    var sectionID: ButtonPanelSectionID {
        switch self {
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5:
            return .instrument
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
        }
    }

    // 共享层统一定义按钮是否处于选中态，平台层只消费结果。
    func isSelected(in displayState: FretboardDisplayState) -> Bool {
        switch self {
        case .setInstrumentGuitar6:
            return displayState.configuration.instrument == .guitar6
        case .setInstrumentBass4:
            return displayState.configuration.instrument == .bass4
        case .setInstrumentBass5:
            return displayState.configuration.instrument == .bass5
        case .setVisibilityAll:
            return displayState.visibility == .all
        case .setVisibilityNaturalOnly:
            return displayState.visibility == .naturalOnly
        case .setVisibilityAccidentalOnly:
            return displayState.visibility == .accidentalOnly
        case .setVisibilityNone:
            return displayState.visibility == .none
        case .setSpellingSharp:
            return displayState.spelling == .sharp
        case .setSpellingFlat:
            return displayState.spelling == .flat
        case .toggleShowsOctave:
            return displayState.showsOctave
        }
    }

    func isEnabled(in _: FretboardDisplayState) -> Bool {
        switch self {
        case .setInstrumentGuitar6,
             .setInstrumentBass4,
             .setInstrumentBass5,
             .setVisibilityAll,
             .setVisibilityNaturalOnly,
             .setVisibilityAccidentalOnly,
             .setVisibilityNone,
             .setSpellingSharp,
             .setSpellingFlat,
             .toggleShowsOctave:
            return true
        }
    }

    // 动作到状态迁移也放在共享层，避免后续控制器各自解释 action。
    func apply(to displayState: inout FretboardDisplayState) {
        switch self {
        case .setInstrumentGuitar6:
            displayState.configuration.tuning = .standard(for: .guitar6)
        case .setInstrumentBass4:
            displayState.configuration.tuning = .standard(for: .bass4)
        case .setInstrumentBass5:
            displayState.configuration.tuning = .standard(for: .bass5)
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
        }
    }
}

struct ButtonPanelItem: Equatable, Hashable, Sendable {
    var id: ButtonPanelActionID
    var title: String
    var accessibilityLabel: String
    var isSelected: Bool
    var isEnabled: Bool
}

struct ButtonPanelSection: Equatable, Sendable {
    var id: ButtonPanelSectionID
    var title: String
    var selectionStyle: ButtonPanelSelectionStyle
    var items: [ButtonPanelItem]
}

struct ButtonPanelModel: Equatable, Sendable {
    var sections: [ButtonPanelSection]

    var items: [ButtonPanelItem] {
        sections.flatMap(\.items)
    }

    func item(for id: ButtonPanelActionID) -> ButtonPanelItem? {
        items.first { $0.id == id }
    }
}

extension FretboardDisplayState {
    mutating func apply(_ actionID: ButtonPanelActionID) {
        actionID.apply(to: &self)
    }
}

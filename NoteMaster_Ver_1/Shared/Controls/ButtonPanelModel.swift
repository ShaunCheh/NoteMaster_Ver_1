//
//  ButtonPanelModel.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

enum ButtonPanelSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case instrument
    case displayMode
    case labels
    case spelling
    case octave

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
        }
    }

    var selectionStyle: ButtonPanelSelectionStyle {
        switch self {
        case .instrument, .displayMode, .labels, .spelling:
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

    var sectionID: ButtonPanelSectionID {
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
             .setVisibilityBCEFOnly,
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
        settingsActionID.title
    }

    var accessibilityLabel: String {
        settingsActionID.accessibilityLabel
    }

    // 共享层统一定义按钮是否处于选中态，平台层只消费结果。
    func isSelected(in displayState: FretboardDisplayState) -> Bool {
        settingsActionID.isSelected(
            in: SettingsPanelStateContext(
                fretboardDisplayState: displayState,
                staffDisplayState: .default
            )
        )
    }

    func isEnabled(in displayState: FretboardDisplayState) -> Bool {
        settingsActionID.isEnabled(
            in: SettingsPanelStateContext(
                fretboardDisplayState: displayState,
                staffDisplayState: .default
            )
        )
    }

    // 动作到状态迁移也放在共享层，避免后续控制器各自解释 action。
    func apply(to displayState: inout FretboardDisplayState) {
        settingsActionID.apply(to: &displayState)
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

private extension ButtonPanelActionID {
    var settingsActionID: SettingsActionID {
        switch self {
        case .setInstrumentGuitar6:
            return .setInstrumentGuitar6
        case .setInstrumentBass4:
            return .setInstrumentBass4
        case .setInstrumentBass5:
            return .setInstrumentBass5
        case .setDisplayModeHorizontal:
            return .setDisplayModeHorizontal
        case .setDisplayModeVertical:
            return .setDisplayModeVertical
        case .setVisibilityAll:
            return .setVisibilityAll
        case .setVisibilityNaturalOnly:
            return .setVisibilityNaturalOnly
        case .setVisibilityBCEFOnly:
            return .setVisibilityBCEFOnly
        case .setVisibilityAccidentalOnly:
            return .setVisibilityAccidentalOnly
        case .setVisibilityNone:
            return .setVisibilityNone
        case .setSpellingSharp:
            return .setSpellingSharp
        case .setSpellingFlat:
            return .setSpellingFlat
        case .toggleShowsOctave:
            return .toggleShowsOctave
        }
    }
}

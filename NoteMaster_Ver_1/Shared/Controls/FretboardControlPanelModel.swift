//
//  FretboardControlPanelModel.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics

enum FretboardControlSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case layout

    var title: String {
        switch self {
        case .layout:
            return "Fretboard"
        }
    }
}

enum FretboardControlEvent: Equatable, Sendable {
    case setVerticalHostHeightRatio(CGFloat)

    func apply(to displayState: inout FretboardDisplayState) {
        switch self {
        case let .setVerticalHostHeightRatio(value):
            SettingsSliderID.verticalHostHeightRatio.apply(
                value: value,
                to: &displayState
            )
        }
    }
}

struct FretboardSliderControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case verticalHostHeightRatio

        var sectionID: FretboardControlSectionID {
            switch self {
            case .verticalHostHeightRatio:
                return .layout
            }
        }

        var title: String {
            settingsSliderID.title
        }

        var accessibilityLabel: String {
            settingsSliderID.accessibilityLabel
        }

        var range: ClosedRange<CGFloat> {
            settingsSliderID.range
        }
    }

    var id: ID
    var title: String
    var accessibilityLabel: String
    var value: CGFloat
    var range: ClosedRange<CGFloat>
    var displayValue: String
    var isEnabled: Bool
}

enum FretboardControlRowID: Equatable, Hashable, Sendable {
    case slider(FretboardSliderControlItem.ID)
}

enum FretboardControlRow: Equatable, Sendable {
    case slider(FretboardSliderControlItem)

    var id: FretboardControlRowID {
        switch self {
        case let .slider(item):
            return .slider(item.id)
        }
    }
}

struct FretboardControlSection: Equatable, Sendable {
    var id: FretboardControlSectionID
    var title: String
    var rows: [FretboardControlRow]
}

struct FretboardControlPanelModel: Equatable, Sendable {
    var sections: [FretboardControlSection]

    static let empty = FretboardControlPanelModel(sections: [])

    var rows: [FretboardControlRow] {
        sections.flatMap(\.rows)
    }

    func slider(for id: FretboardSliderControlItem.ID) -> FretboardSliderControlItem? {
        rows.compactMap { row in
            guard case let .slider(item) = row else {
                return nil
            }

            return item
        }.first { $0.id == id }
    }
}

extension FretboardDisplayState {
    mutating func apply(_ event: FretboardControlEvent) {
        event.apply(to: &self)
    }
}

private extension FretboardSliderControlItem.ID {
    var settingsSliderID: SettingsSliderID {
        switch self {
        case .verticalHostHeightRatio:
            return .verticalHostHeightRatio
        }
    }
}

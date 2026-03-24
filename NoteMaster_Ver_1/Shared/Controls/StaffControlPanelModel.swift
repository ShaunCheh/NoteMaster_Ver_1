//
//  StaffControlPanelModel.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics

enum StaffControlSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case clef

    var title: String {
        switch self {
        case .clef:
            return "Clef"
        }
    }
}

enum StaffControlEvent: Equatable, Sendable {
    case setClef(StaffClef)
    case setClefScale(CGFloat)
    case setClefAnchorLogicalDownwardShiftRatio(CGFloat)

    // 连续值的约束统一收口在共享层，避免 iOS/macOS 各自重复 clamp。
    static let clefScaleRange: ClosedRange<CGFloat> = 1.0...5
    static let clefAnchorLogicalDownwardShiftRatioRange: ClosedRange<CGFloat> = (-0.25)...0.25

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case let .setClef(clef):
            displayState.configuration.clef = clef
        case let .setClefScale(value):
            displayState.configuration.layoutMetrics.clefScale = value.clamped(
                to: Self.clefScaleRange
            )
        case let .setClefAnchorLogicalDownwardShiftRatio(value):
            displayState.configuration.setClefAnchorLogicalDownwardShiftRatio(
                value.clamped(
                    to: Self.clefAnchorLogicalDownwardShiftRatioRange
                ),
                for: displayState.configuration.clef
            )
        }
    }
}

struct StaffOptionChoice: Equatable, Hashable, Sendable {
    var clef: StaffClef
    var title: String
    var isSelected: Bool
}

struct StaffOptionControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case clef

        var sectionID: StaffControlSectionID {
            switch self {
            case .clef:
                return .clef
            }
        }

        var title: String {
            switch self {
            case .clef:
                return "Type"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .clef:
                return "Select clef"
            }
        }
    }

    var id: ID
    var title: String
    var accessibilityLabel: String
    var choices: [StaffOptionChoice]
    var isEnabled: Bool
}

struct StaffSliderControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case clefScale
        case clefAnchorYOffset

        var sectionID: StaffControlSectionID {
            switch self {
            case .clefScale, .clefAnchorYOffset:
                return .clef
            }
        }

        var title: String {
            switch self {
            case .clefScale:
                return "Scale"
            case .clefAnchorYOffset:
                return "Anchor Y Offset"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .clefScale:
                return "Adjust clef scale"
            case .clefAnchorYOffset:
                return "Adjust clef anchor vertical offset"
            }
        }

        var range: ClosedRange<CGFloat> {
            switch self {
            case .clefScale:
                return StaffControlEvent.clefScaleRange
            case .clefAnchorYOffset:
                return StaffControlEvent.clefAnchorLogicalDownwardShiftRatioRange
            }
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

enum StaffControlRowID: Equatable, Hashable, Sendable {
    case option(StaffOptionControlItem.ID)
    case slider(StaffSliderControlItem.ID)
}

enum StaffControlRow: Equatable, Sendable {
    case option(StaffOptionControlItem)
    case slider(StaffSliderControlItem)

    var id: StaffControlRowID {
        switch self {
        case let .option(item):
            return .option(item.id)
        case let .slider(item):
            return .slider(item.id)
        }
    }
}

struct StaffControlSection: Equatable, Sendable {
    var id: StaffControlSectionID
    var title: String
    var rows: [StaffControlRow]
}

struct StaffControlPanelModel: Equatable, Sendable {
    var sections: [StaffControlSection]

    static let empty = StaffControlPanelModel(sections: [])

    var rows: [StaffControlRow] {
        sections.flatMap(\.rows)
    }

    func slider(for id: StaffSliderControlItem.ID) -> StaffSliderControlItem? {
        rows.compactMap { row in
            guard case let .slider(item) = row else {
                return nil
            }

            return item
        }.first { $0.id == id }
    }

    func option(for id: StaffOptionControlItem.ID) -> StaffOptionControlItem? {
        rows.compactMap { row in
            guard case let .option(item) = row else {
                return nil
            }

            return item
        }.first { $0.id == id }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

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
    case setClefScale(CGFloat)
    case setTrebleClefAnchorLogicalDownwardShiftRatio(CGFloat)

    // 连续值的约束统一收口在共享层，避免 iOS/macOS 各自重复 clamp。
    static let clefScaleRange: ClosedRange<CGFloat> = 1.0...5
    static let trebleClefAnchorLogicalDownwardShiftRatioRange: ClosedRange<CGFloat> = (-0.25)...0.25

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case let .setClefScale(value):
            displayState.configuration.layoutMetrics.clefScale = value.clamped(
                to: Self.clefScaleRange
            )
        case let .setTrebleClefAnchorLogicalDownwardShiftRatio(value):
            displayState.configuration.trebleClefAnchorLogicalDownwardShiftRatio = value.clamped(
                to: Self.trebleClefAnchorLogicalDownwardShiftRatioRange
            )
        }
    }
}

struct StaffSliderControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case clefScale
        case trebleClefAnchorYOffset

        var sectionID: StaffControlSectionID {
            switch self {
            case .clefScale, .trebleClefAnchorYOffset:
                return .clef
            }
        }

        var title: String {
            switch self {
            case .clefScale:
                return "Scale"
            case .trebleClefAnchorYOffset:
                return "Anchor Y Offset"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .clefScale:
                return "Adjust clef scale"
            case .trebleClefAnchorYOffset:
                return "Adjust treble clef anchor vertical offset"
            }
        }

        var range: ClosedRange<CGFloat> {
            switch self {
            case .clefScale:
                return StaffControlEvent.clefScaleRange
            case .trebleClefAnchorYOffset:
                return StaffControlEvent.trebleClefAnchorLogicalDownwardShiftRatioRange
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

struct StaffControlSection: Equatable, Sendable {
    var id: StaffControlSectionID
    var title: String
    var sliders: [StaffSliderControlItem]
}

struct StaffControlPanelModel: Equatable, Sendable {
    var sections: [StaffControlSection]

    static let empty = StaffControlPanelModel(sections: [])

    var sliders: [StaffSliderControlItem] {
        sections.flatMap(\.sliders)
    }

    func slider(for id: StaffSliderControlItem.ID) -> StaffSliderControlItem? {
        sliders.first { $0.id == id }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

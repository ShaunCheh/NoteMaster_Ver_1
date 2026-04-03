//
//  ExerciseNaturalNoteStripRailPlacement.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/3.
//

import CoreGraphics

enum ExerciseNaturalNoteStripRailPlacementModel: Equatable, Sendable {
    case singleColumnChromatic12
    case staggeredNaturalAccidentalTwoColumn
}

enum ExerciseNaturalNoteStripRailTitleDisplayPolicy: Equatable, Sendable {
    case naturalsOnly
    case allPitchClasses
}

struct ExerciseNaturalNoteStripRailInsets: Equatable, Sendable {
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailInsets(
        top: 10,
        leading: 12,
        bottom: 10,
        trailing: 12
    )

    var top: Double
    var leading: Double
    var bottom: Double
    var trailing: Double

    var horizontal: Double {
        leading + trailing
    }

    var vertical: Double {
        top + bottom
    }
}

struct ExerciseNaturalNoteStripRailGeometry: Equatable, Sendable {
    static let defaultColumnGap =
        ExerciseNaturalNoteStripRailInsets.defaultSideBySideAnswerRail.horizontal
    static let defaultNaturalRowSpacing: Double = 0

    var contentInsets: ExerciseNaturalNoteStripRailInsets
    var columnGap: Double
    var naturalRowSpacing: Double
    var buttonExtent: Double

    var resolvedColumnGap: Double {
        max(columnGap, 0)
    }

    var resolvedNaturalRowSpacing: Double {
        max(naturalRowSpacing, 0)
    }

    var resolvedButtonExtent: Double {
        max(buttonExtent, 0)
    }

    var buttonSize: CGSize {
        CGSize(
            width: CGFloat(resolvedButtonExtent),
            height: CGFloat(resolvedButtonExtent)
        )
    }

    var twoColumnContentWidth: Double {
        contentInsets.leading
            + resolvedButtonExtent
            + resolvedColumnGap
            + resolvedButtonExtent
            + contentInsets.trailing
    }

    func naturalColumnContentHeight(rowCount: Int) -> Double {
        let resolvedRowCount = max(rowCount, 0)
        let gapCount = max(resolvedRowCount - 1, 0)
        return contentInsets.top
            + (resolvedButtonExtent * Double(resolvedRowCount))
            + (resolvedNaturalRowSpacing * Double(gapCount))
            + contentInsets.bottom
    }

    static func defaultStageCSideBySideAnswerRail(
        buttonExtent: Double
    ) -> ExerciseNaturalNoteStripRailGeometry {
        ExerciseNaturalNoteStripRailGeometry(
            contentInsets: .defaultSideBySideAnswerRail,
            columnGap: defaultColumnGap,
            naturalRowSpacing: defaultNaturalRowSpacing,
            buttonExtent: buttonExtent
        )
    }
}

struct ExerciseNaturalNoteStripRailLayoutContext: Equatable, Sendable {
    static let defaultTitleDisplayPolicy:
        ExerciseNaturalNoteStripRailTitleDisplayPolicy = .allPitchClasses

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var placementModel: ExerciseNaturalNoteStripRailPlacementModel
    var titleDisplayPolicy: ExerciseNaturalNoteStripRailTitleDisplayPolicy
    var geometry: ExerciseNaturalNoteStripRailGeometry
    var hostVerticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
    var pitchTopologies: [ExerciseNaturalNoteStripRailPitchTopology]
}

struct ExerciseNaturalNoteStripRailPlacement: Equatable, Sendable {
    var pitchClass: PitchClass
    var topology: ExerciseNaturalNoteStripRailPitchTopology
    var frame: CGRect
    var showsTitle: Bool
}

struct ExerciseNaturalNoteStripRailLayout: Equatable, Sendable {
    var context: ExerciseNaturalNoteStripRailLayoutContext
    var contentSize: CGSize
    var placements: [ExerciseNaturalNoteStripRailPlacement]
}

extension ExerciseNaturalNoteStripRailContract {
    var defaultLayoutContext: ExerciseNaturalNoteStripRailLayoutContext {
        ExerciseNaturalNoteStripRailLayoutContext(
            appliesToSurface: appliesToSurface,
            slotModel: slotModel,
            buttonShape: buttonShape,
            placementModel: .staggeredNaturalAccidentalTwoColumn,
            titleDisplayPolicy:
                ExerciseNaturalNoteStripRailLayoutContext.defaultTitleDisplayPolicy,
            geometry: .defaultStageCSideBySideAnswerRail(
                buttonExtent: buttonExtent
            ),
            hostVerticalAlignment: verticalAlignment,
            pitchTopologies:
                PitchClass.naturalNoteStripStaggeredRailTopologiesInChromaticOrder
        )
    }
}

extension ExerciseScene {
    var naturalNoteStripRailLayoutContext: ExerciseNaturalNoteStripRailLayoutContext?
    {
        naturalNoteStripRailContract?.defaultLayoutContext
    }
}

extension ExercisePresentationState {
    var naturalNoteStripRailLayoutContext: ExerciseNaturalNoteStripRailLayoutContext?
    {
        scene.naturalNoteStripRailLayoutContext
    }
}

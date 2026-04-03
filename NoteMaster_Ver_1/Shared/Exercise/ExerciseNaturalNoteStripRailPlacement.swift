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

    var singleColumnContentWidth: Double {
        contentInsets.leading
            + resolvedButtonExtent
            + contentInsets.trailing
    }

    var naturalRowStride: Double {
        resolvedButtonExtent + resolvedNaturalRowSpacing
    }

    var twoColumnContentWidth: Double {
        contentInsets.leading
            + resolvedButtonExtent
            + resolvedColumnGap
            + resolvedButtonExtent
            + contentInsets.trailing
    }

    func columnContentHeight(rowCount: Int) -> Double {
        let resolvedRowCount = max(rowCount, 0)
        let gapCount = max(resolvedRowCount - 1, 0)
        return contentInsets.top
            + (resolvedButtonExtent * Double(resolvedRowCount))
            + (resolvedNaturalRowSpacing * Double(gapCount))
            + contentInsets.bottom
    }

    func naturalColumnContentHeight(rowCount: Int) -> Double {
        columnContentHeight(rowCount: rowCount)
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
    // `frame` uses rail-local top-leading coordinates inside the shared content rect.
    var frame: CGRect
    var showsTitle: Bool
}

struct ExerciseNaturalNoteStripRailLayout: Equatable, Sendable {
    var context: ExerciseNaturalNoteStripRailLayoutContext
    var contentSize: CGSize
    var placements: [ExerciseNaturalNoteStripRailPlacement]
}

extension ExerciseNaturalNoteStripRailTitleDisplayPolicy {
    func showsTitle(for pitchClass: PitchClass) -> Bool {
        switch self {
        case .naturalsOnly:
            return pitchClass.isNatural
        case .allPitchClasses:
            return true
        }
    }
}

extension ExerciseNaturalNoteStripRailLayoutContext {
    var resolvedLayout: ExerciseNaturalNoteStripRailLayout {
        ExerciseNaturalNoteStripRailLayout.build(from: self)
    }
}

extension ExerciseNaturalNoteStripRailLayout {
    var buttonExtent: Double {
        context.geometry.resolvedButtonExtent
    }

    var usesVerticallyCenteredHostLayout: Bool {
        context.hostVerticalAlignment == .centered
    }

    static func build(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        ExerciseNaturalNoteStripRailLayoutBuilder.build(from: context)
    }
}

private enum ExerciseNaturalNoteStripRailLayoutBuilder {
    static func build(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        switch context.placementModel {
        case .singleColumnChromatic12:
            return buildSingleColumnChromatic12(from: context)
        case .staggeredNaturalAccidentalTwoColumn:
            return buildStaggeredNaturalAccidentalTwoColumn(from: context)
        }
    }

    private static func buildSingleColumnChromatic12(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        let geometry = context.geometry
        let rowCount = context.pitchTopologies.count
        let placements = context.pitchTopologies.enumerated().map { index, topology in
            makePlacement(
                for: topology,
                originX: geometry.contentInsets.leading,
                originY: geometry.contentInsets.top
                    + (Double(index) * geometry.naturalRowStride),
                context: context,
                geometry: geometry
            )
        }

        return ExerciseNaturalNoteStripRailLayout(
            context: context,
            contentSize: CGSize(
                width: geometry.singleColumnContentWidth,
                height: geometry.columnContentHeight(rowCount: rowCount)
            ),
            placements: placements
        )
    }

    private static func buildStaggeredNaturalAccidentalTwoColumn(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        let geometry = context.geometry
        let buttonExtent = geometry.resolvedButtonExtent
        let naturalRowCount = resolvedNaturalRowCount(from: context.pitchTopologies)
        let placements = context.pitchTopologies.map { topology in
            let centerY = resolvedCenterY(
                for: topology.anchor,
                geometry: geometry
            )
            return makePlacement(
                for: topology,
                originX: resolvedColumnOriginX(
                    for: topology.column,
                    geometry: geometry
                ),
                originY: centerY - (buttonExtent / 2),
                context: context,
                geometry: geometry
            )
        }

        return ExerciseNaturalNoteStripRailLayout(
            context: context,
            contentSize: CGSize(
                width: geometry.twoColumnContentWidth,
                height: geometry.naturalColumnContentHeight(
                    rowCount: naturalRowCount
                )
            ),
            placements: placements
        )
    }

    private static func makePlacement(
        for topology: ExerciseNaturalNoteStripRailPitchTopology,
        originX: Double,
        originY: Double,
        context: ExerciseNaturalNoteStripRailLayoutContext,
        geometry: ExerciseNaturalNoteStripRailGeometry
    ) -> ExerciseNaturalNoteStripRailPlacement {
        ExerciseNaturalNoteStripRailPlacement(
            pitchClass: topology.pitchClass,
            topology: topology,
            frame: CGRect(
                x: originX,
                y: originY,
                width: geometry.resolvedButtonExtent,
                height: geometry.resolvedButtonExtent
            ),
            showsTitle: context.titleDisplayPolicy.showsTitle(
                for: topology.pitchClass
            )
        )
    }

    private static func resolvedNaturalRowCount(
        from topologies: [ExerciseNaturalNoteStripRailPitchTopology]
    ) -> Int {
        let maxAnchorIndex = topologies.map { topology in
            switch topology.anchor {
            case let .naturalRow(index):
                return index
            case let .midpointBetweenNaturalRows(_, bottom):
                return bottom
            }
        }.max() ?? -1
        return maxAnchorIndex + 1
    }

    private static func resolvedColumnOriginX(
        for column: ExerciseNaturalNoteStripRailPitchTopologyColumn,
        geometry: ExerciseNaturalNoteStripRailGeometry
    ) -> Double {
        switch column {
        case .accidentalLeft:
            return geometry.contentInsets.leading
        case .naturalRight:
            return geometry.contentInsets.leading
                + geometry.resolvedButtonExtent
                + geometry.resolvedColumnGap
        }
    }

    private static func resolvedCenterY(
        for anchor: ExerciseNaturalNoteStripRailPitchTopologyAnchor,
        geometry: ExerciseNaturalNoteStripRailGeometry
    ) -> Double {
        switch anchor {
        case let .naturalRow(index):
            return naturalRowCenterY(index: index, geometry: geometry)
        case let .midpointBetweenNaturalRows(top, bottom):
            return (
                naturalRowCenterY(index: top, geometry: geometry)
                    + naturalRowCenterY(index: bottom, geometry: geometry)
            ) / 2
        }
    }

    private static func naturalRowCenterY(
        index: Int,
        geometry: ExerciseNaturalNoteStripRailGeometry
    ) -> Double {
        geometry.contentInsets.top
            + (geometry.resolvedButtonExtent / 2)
            + (Double(index) * geometry.naturalRowStride)
    }
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

    var naturalNoteStripRailLayout: ExerciseNaturalNoteStripRailLayout? {
        naturalNoteStripRailLayoutContext?.resolvedLayout
    }
}

extension ExercisePresentationState {
    var naturalNoteStripRailLayoutContext: ExerciseNaturalNoteStripRailLayoutContext?
    {
        scene.naturalNoteStripRailLayoutContext
    }

    var naturalNoteStripRailLayout: ExerciseNaturalNoteStripRailLayout? {
        scene.naturalNoteStripRailLayout
    }
}

//
//  ExerciseNaturalNoteStripRailPlacement.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/3.
//

import CoreGraphics

enum ExerciseNaturalNoteStripHorizontalRow: Equatable, Sendable {
    case accidentalsTop
    case naturalsBottom
}

enum ExerciseNaturalNoteStripHorizontalTitleDisplayPolicy: Equatable, Sendable {
    case naturalsOnly
    case allPitchClasses
}

struct ExerciseNaturalNoteStripHorizontalInsets: Equatable, Sendable {
    static let defaultHorizontalStrip = ExerciseNaturalNoteStripHorizontalInsets(
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

struct ExerciseNaturalNoteStripHorizontalGeometry: Equatable, Sendable {
    static let defaultColumnSpacing: Double = 6
    static let defaultRowSpacing: Double = 6
    static let defaultButtonExtent =
        ExerciseNaturalNoteStripRailContract.defaultButtonExtent

    var contentInsets: ExerciseNaturalNoteStripHorizontalInsets
    var columnSpacing: Double
    var rowSpacing: Double
    var buttonExtent: Double

    var resolvedColumnSpacing: Double {
        max(columnSpacing, 0)
    }

    var resolvedRowSpacing: Double {
        max(rowSpacing, 0)
    }

    var resolvedButtonExtent: Double {
        max(buttonExtent, 0)
    }

    func rowContentWidth(columnCount: Int) -> Double {
        let resolvedColumnCount = max(columnCount, 0)
        let gapCount = max(resolvedColumnCount - 1, 0)
        return contentInsets.leading
            + (resolvedButtonExtent * Double(resolvedColumnCount))
            + (resolvedColumnSpacing * Double(gapCount))
            + contentInsets.trailing
    }

    func contentHeight(rowCount: Int) -> Double {
        let resolvedRowCount = max(rowCount, 0)
        let gapCount = max(resolvedRowCount - 1, 0)
        return contentInsets.top
            + (resolvedButtonExtent * Double(resolvedRowCount))
            + (resolvedRowSpacing * Double(gapCount))
            + contentInsets.bottom
    }

    func twoRowContentSize(
        topColumnCount: Int,
        bottomColumnCount: Int
    ) -> CGSize {
        CGSize(
            width: max(
                rowContentWidth(columnCount: topColumnCount),
                rowContentWidth(columnCount: bottomColumnCount)
            ),
            height: contentHeight(rowCount: 2)
        )
    }

    static func defaultTwoRowHorizontalStrip(
        buttonExtent: Double = defaultButtonExtent
    ) -> ExerciseNaturalNoteStripHorizontalGeometry {
        ExerciseNaturalNoteStripHorizontalGeometry(
            contentInsets: .defaultHorizontalStrip,
            columnSpacing: defaultColumnSpacing,
            rowSpacing: defaultRowSpacing,
            buttonExtent: buttonExtent
        )
    }
}

struct ExerciseNaturalNoteStripHorizontalLayoutContext: Equatable, Sendable {
    static let defaultTitleDisplayPolicy:
        ExerciseNaturalNoteStripHorizontalTitleDisplayPolicy = .allPitchClasses

    var appliesToSurface: ExerciseSurfaceID
    var titleDisplayPolicy: ExerciseNaturalNoteStripHorizontalTitleDisplayPolicy
    var geometry: ExerciseNaturalNoteStripHorizontalGeometry
    var accidentalPitchClasses: [PitchClass]
    var naturalPitchClasses: [PitchClass]
}

struct ExerciseNaturalNoteStripHorizontalPlacement: Equatable, Sendable {
    var pitchClass: PitchClass
    var row: ExerciseNaturalNoteStripHorizontalRow
    var columnIndex: Int
    var showsTitle: Bool
}

struct ExerciseNaturalNoteStripHorizontalLayout: Equatable, Sendable {
    var context: ExerciseNaturalNoteStripHorizontalLayoutContext
    var accidentalPlacements: [ExerciseNaturalNoteStripHorizontalPlacement]
    var naturalPlacements: [ExerciseNaturalNoteStripHorizontalPlacement]
    var contentSize: CGSize

    var placementsInDisplayOrder: [ExerciseNaturalNoteStripHorizontalPlacement] {
        accidentalPlacements + naturalPlacements
    }
}

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

extension ExerciseNaturalNoteStripHorizontalTitleDisplayPolicy {
    func showsTitle(for pitchClass: PitchClass) -> Bool {
        switch self {
        case .naturalsOnly:
            return pitchClass.isNatural
        case .allPitchClasses:
            return true
        }
    }
}

extension ExerciseNaturalNoteStripHorizontalLayoutContext {
    var resolvedLayout: ExerciseNaturalNoteStripHorizontalLayout {
        ExerciseNaturalNoteStripHorizontalLayout.build(from: self)
    }
}

extension ExerciseNaturalNoteStripHorizontalLayout {
    static func build(
        from context: ExerciseNaturalNoteStripHorizontalLayoutContext
    ) -> ExerciseNaturalNoteStripHorizontalLayout {
        ExerciseNaturalNoteStripHorizontalLayoutBuilder.build(from: context)
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

private enum ExerciseNaturalNoteStripHorizontalLayoutBuilder {
    static func build(
        from context: ExerciseNaturalNoteStripHorizontalLayoutContext
    ) -> ExerciseNaturalNoteStripHorizontalLayout {
        let accidentalPlacements = context.accidentalPitchClasses.enumerated().map {
            index,
            pitchClass in
            ExerciseNaturalNoteStripHorizontalPlacement(
                pitchClass: pitchClass,
                row: .accidentalsTop,
                columnIndex: index,
                showsTitle: context.titleDisplayPolicy.showsTitle(
                    for: pitchClass
                )
            )
        }
        let naturalPlacements = context.naturalPitchClasses.enumerated().map {
            index,
            pitchClass in
            ExerciseNaturalNoteStripHorizontalPlacement(
                pitchClass: pitchClass,
                row: .naturalsBottom,
                columnIndex: index,
                showsTitle: context.titleDisplayPolicy.showsTitle(
                    for: pitchClass
                )
            )
        }

        return ExerciseNaturalNoteStripHorizontalLayout(
            context: context,
            accidentalPlacements: accidentalPlacements,
            naturalPlacements: naturalPlacements,
            contentSize: context.geometry.twoRowContentSize(
                topColumnCount: accidentalPlacements.count,
                bottomColumnCount: naturalPlacements.count
            )
        )
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
    var naturalNoteStripHorizontalLayoutContext:
        ExerciseNaturalNoteStripHorizontalLayoutContext? {
        guard let horizontalStripSurface = activeNaturalNoteStripHorizontalSurface
        else {
            return nil
        }

        return ExerciseNaturalNoteStripHorizontalLayoutContext(
            appliesToSurface: horizontalStripSurface.id,
            titleDisplayPolicy:
                ExerciseNaturalNoteStripHorizontalLayoutContext
                .defaultTitleDisplayPolicy,
            geometry: .defaultTwoRowHorizontalStrip(),
            accidentalPitchClasses: PitchClass.accidentalCasesInOrder,
            naturalPitchClasses: PitchClass.naturalCasesInOrder
        )
    }

    var naturalNoteStripHorizontalLayout: ExerciseNaturalNoteStripHorizontalLayout?
    {
        naturalNoteStripHorizontalLayoutContext?.resolvedLayout
    }

    var naturalNoteStripRailLayoutContext: ExerciseNaturalNoteStripRailLayoutContext?
    {
        naturalNoteStripRailContract?.defaultLayoutContext
    }

    var naturalNoteStripRailLayout: ExerciseNaturalNoteStripRailLayout? {
        naturalNoteStripRailLayoutContext?.resolvedLayout
    }
}

extension ExercisePresentationState {
    var naturalNoteStripHorizontalLayoutContext:
        ExerciseNaturalNoteStripHorizontalLayoutContext? {
        scene.naturalNoteStripHorizontalLayoutContext
    }

    var naturalNoteStripHorizontalLayout: ExerciseNaturalNoteStripHorizontalLayout?
    {
        scene.naturalNoteStripHorizontalLayout
    }

    var naturalNoteStripRailLayoutContext: ExerciseNaturalNoteStripRailLayoutContext?
    {
        scene.naturalNoteStripRailLayoutContext
    }

    var naturalNoteStripRailLayout: ExerciseNaturalNoteStripRailLayout? {
        scene.naturalNoteStripRailLayout
    }
}

private extension ExerciseScene {
    var activeNaturalNoteStripHorizontalSurface: ExerciseSurfaceNode? {
        let horizontalStripSurfaces = surfaceNodes.filter {
            $0.isNaturalNoteStripHorizontalStrip
        }
        guard horizontalStripSurfaces.count == 1 else {
            return nil
        }

        return horizontalStripSurfaces.first
    }
}

private extension ExerciseSurfaceNode {
    var isNaturalNoteStripHorizontalStrip: Bool {
        id == .naturalNoteStrip
            && kind == .naturalNoteStrip
            && presentationStyle == .horizontalStrip
    }
}

//
//  FretboardGeometry.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

import CoreGraphics

struct FretboardGeometry: Equatable {
    struct DisplaySlot: Equatable {
        enum Kind: Equatable {
            case openString
            case fretted(Int)
        }

        var position: Int
        var kind: Kind
        var rect: CGRect
    }

    struct StringLine: Equatable {
        var stringIndex: Int
        var y: CGFloat
    }

    struct FretLine: Equatable {
        var fret: Int
        var x: CGFloat
    }

    struct MarkerPlacement: Equatable {
        enum Style: Equatable {
            case singleDot
            case doubleDot
        }

        var fret: Int
        var style: Style
        var centers: [CGPoint]
        var diameter: CGFloat
    }

    let configuration: FretboardConfiguration
    let bounds: CGRect

    init(configuration: FretboardConfiguration, bounds: CGRect) {
        self.configuration = configuration
        self.bounds = bounds.standardized
    }

    var drawingRect: CGRect {
        Self.makeDrawingRect(bounds: bounds, metrics: configuration.layoutMetrics)
    }

    var displayPositionCount: Int {
        configuration.maxFret + 1
    }

    var displaySlotWidth: CGFloat {
        guard !drawingRect.isNull, displayPositionCount > 0 else {
            return 0
        }

        return drawingRect.width / CGFloat(displayPositionCount)
    }

    // 逻辑位置 0 是空弦区域；1...maxFret 才对应实际按弦区间。
    var displaySlots: [DisplaySlot] {
        configuration.fretRange.map { position in
            let kind: DisplaySlot.Kind = position == 0 ? .openString : .fretted(position)
            return DisplaySlot(position: position, kind: kind, rect: displaySlotRect(at: position))
        }
    }

    var openStringRect: CGRect {
        displaySlotRect(at: 0)
    }

    var nutX: CGFloat {
        guard !openStringRect.isNull else {
            return 0
        }

        return openStringRect.maxX
    }

    var nutRect: CGRect {
        guard !drawingRect.isNull else {
            return .null
        }

        let width = min(
            max(
                configuration.layoutMetrics.nutWidthRatio * drawingRect.width,
                configuration.layoutMetrics.fretLineWidth
            ),
            drawingRect.width
        )

        return CGRect(
            x: nutX - (width / 2),
            y: drawingRect.minY,
            width: width,
            height: drawingRect.height
        )
    }

    var fretboardRect: CGRect {
        guard !drawingRect.isNull else {
            return .null
        }

        let minX = min(nutRect.maxX, drawingRect.maxX)
        return CGRect(
            x: minX,
            y: drawingRect.minY,
            width: max(0, drawingRect.maxX - minX),
            height: drawingRect.height
        )
    }

    var stringLines: [StringLine] {
        stringYPositions.enumerated().map { index, y in
            StringLine(stringIndex: index, y: y)
        }
    }

    var fretLines: [FretLine] {
        guard configuration.maxFret > 0 else {
            return []
        }

        return (1...configuration.maxFret).compactMap { fret in
            fretLineX(for: fret).map { FretLine(fret: fret, x: $0) }
        }
    }

    var markerPlacements: [MarkerPlacement] {
        let doubleDotFrets = Set(configuration.markerLayout.normalizedDoubleDotFrets(upTo: configuration.maxFret))

        return configuration.markerLayout.allMarkerFrets(upTo: configuration.maxFret).compactMap { fret in
            let centers = markerCenters(for: fret)
            guard !centers.isEmpty else {
                return nil
            }

            let style: MarkerPlacement.Style = doubleDotFrets.contains(fret) ? .doubleDot : .singleDot
            return MarkerPlacement(
                fret: fret,
                style: style,
                centers: centers,
                diameter: markerDiameter
            )
        }
    }

    var stringLaneHeight: CGFloat {
        guard !drawingRect.isNull else {
            return 0
        }

        return resolvedStringLaneHeight(in: drawingRect.height)
    }

    var stringColumnRect: CGRect {
        let laneHeight = stringLaneHeight
        guard
            !drawingRect.isNull,
            configuration.stringCount > 0,
            laneHeight > 0
        else {
            return .null
        }

        let occupiedHeight = laneHeight * CGFloat(configuration.stringCount)
        return CGRect(
            x: drawingRect.minX,
            y: drawingRect.midY - (occupiedHeight / 2),
            width: drawingRect.width,
            height: occupiedHeight
        )
    }

    var stringYPositions: [CGFloat] {
        let columnRect = stringColumnRect
        let laneHeight = stringLaneHeight
        guard
            !columnRect.isNull,
            laneHeight > 0
        else {
            return []
        }

        return (0..<configuration.stringCount).map { stringIndex in
            columnRect.minY + (laneHeight * (CGFloat(stringIndex) + 0.5))
        }
    }

    var stringSpacing: CGFloat {
        guard configuration.stringCount > 1 else {
            return 0
        }

        return stringLaneHeight
    }

    var markerDiameter: CGFloat {
        guard !drawingRect.isNull else {
            return 0
        }

        let columnRect = stringColumnRect
        let verticalReference = !columnRect.isNull
            ? columnRect.height
            : drawingRect.height

        return min(displaySlotWidth, verticalReference) * configuration.layoutMetrics.markerDiameterRatio
    }

    func displaySlotRect(at position: Int) -> CGRect {
        guard configuration.fretRange.contains(position), !drawingRect.isNull else {
            return .null
        }

        return CGRect(
            x: drawingRect.minX + (CGFloat(position) * displaySlotWidth),
            y: drawingRect.minY,
            width: displaySlotWidth,
            height: drawingRect.height
        )
    }

    func fretSegmentRect(at fret: Int) -> CGRect {
        guard fret > 0 else {
            return .null
        }

        return displaySlotRect(at: fret)
    }

    func fretLineX(for fret: Int) -> CGFloat? {
        guard !drawingRect.isNull else {
            return nil
        }

        if fret == 0 {
            return nutX
        }

        guard fret > 0, fret <= configuration.maxFret else {
            return nil
        }

        return displaySlotRect(at: fret).maxX
    }

    func yPositionForString(_ stringIndex: Int) -> CGFloat? {
        guard stringIndex >= 0, stringIndex < stringYPositions.count else {
            return nil
        }

        return stringYPositions[stringIndex]
    }

    func displayPosition(forX x: CGFloat) -> Int? {
        guard
            !drawingRect.isNull,
            displaySlotWidth > 0,
            isValue(x, withinInclusiveRangeOf: drawingRect.minX, and: drawingRect.maxX)
        else {
            return nil
        }

        let relativeX = min(max(x - drawingRect.minX, 0), drawingRect.width)
        let rawPosition = Int(relativeX / displaySlotWidth)
        return min(rawPosition, configuration.maxFret)
    }

    func nearestStringIndex(forY y: CGFloat) -> Int? {
        nearestStringMatch(forY: y)?.stringIndex
    }

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase
    ) -> FretboardHitResult {
        let isInsideDrawingRect = contains(point, inInclusiveBoundsOf: drawingRect)
        let nearestString = nearestStringMatch(forY: point.y)

        guard
            isInsideDrawingRect,
            let fret = displayPosition(forX: point.x),
            let nearestString
        else {
            return FretboardHitResult(
                phase: phase,
                locationInView: point,
                cell: nil,
                isInsideDrawingRect: isInsideDrawingRect,
                distanceToNearestString: nearestString?.distance
            )
        }

        return FretboardHitResult(
            phase: phase,
            locationInView: point,
            cell: FretboardCell(
                stringIndex: nearestString.stringIndex,
                fret: fret
            ),
            isInsideDrawingRect: true,
            distanceToNearestString: nearestString.distance
        )
    }

    func markerCenters(for fret: Int) -> [CGPoint] {
        let segmentRect = fretSegmentRect(at: fret)
        guard !segmentRect.isNull else {
            return []
        }

        let centerX = segmentRect.midX
        let columnRect = stringColumnRect
        let centerY = !columnRect.isNull
            ? columnRect.midY
            : drawingRect.midY
        let singleDotFrets = Set(configuration.markerLayout.normalizedSingleDotFrets(upTo: configuration.maxFret))
        let doubleDotFrets = Set(configuration.markerLayout.normalizedDoubleDotFrets(upTo: configuration.maxFret))

        if doubleDotFrets.contains(fret) {
            let offset = markerDoubleDotOffset
            return [
                CGPoint(x: centerX, y: centerY - offset),
                CGPoint(x: centerX, y: centerY + offset)
            ]
        }

        if singleDotFrets.contains(fret) {
            return [CGPoint(x: centerX, y: centerY)]
        }

        return []
    }

    private var markerDoubleDotOffset: CGFloat {
        guard !drawingRect.isNull else {
            return 0
        }

        let columnRect = stringColumnRect
        let verticalReference = !columnRect.isNull
            ? columnRect.height
            : drawingRect.height

        return verticalReference * configuration.layoutMetrics.doubleMarkerOffsetRatio
    }

    private func nearestStringMatch(
        forY y: CGFloat
    ) -> (stringIndex: Int, distance: CGFloat)? {
        guard !stringYPositions.isEmpty else {
            return nil
        }

        return stringYPositions.enumerated()
            .map { index, stringY in
                (
                    stringIndex: index,
                    distance: abs(stringY - y)
                )
            }
            .min { lhs, rhs in
                if lhs.distance == rhs.distance {
                    return lhs.stringIndex < rhs.stringIndex
                }
                return lhs.distance < rhs.distance
            }
    }

    private func resolvedStringLaneHeight(
        in availableHeight: CGFloat
    ) -> CGFloat {
        guard
            availableHeight > 0,
            configuration.stringCount > 0
        else {
            return 0
        }

        let preferredLaneHeight = max(configuration.layoutMetrics.stringLaneHeight, 1)
        let availableLaneHeight = availableHeight / CGFloat(configuration.stringCount)
        return min(preferredLaneHeight, max(availableLaneHeight, 0))
    }

    private func contains(
        _ point: CGPoint,
        inInclusiveBoundsOf rect: CGRect
    ) -> Bool {
        guard !rect.isNull else {
            return false
        }

        return isValue(point.x, withinInclusiveRangeOf: rect.minX, and: rect.maxX)
            && isValue(point.y, withinInclusiveRangeOf: rect.minY, and: rect.maxY)
    }

    private func isValue(
        _ value: CGFloat,
        withinInclusiveRangeOf minValue: CGFloat,
        and maxValue: CGFloat
    ) -> Bool {
        value >= minValue && value <= maxValue
    }

    private static func makeDrawingRect(
        bounds: CGRect,
        metrics: FretboardConfiguration.LayoutMetrics
    ) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return .null
        }

        let horizontalInset = min(
            max(bounds.width * metrics.horizontalInsetRatio, 0),
            bounds.width / 2
        )
        let verticalInset = min(
            max(bounds.height * metrics.verticalInsetRatio, 0),
            bounds.height / 2
        )
        let rect = bounds.insetBy(dx: horizontalInset, dy: verticalInset)

        return rect.isNull || rect.isEmpty ? .null : rect
    }

}

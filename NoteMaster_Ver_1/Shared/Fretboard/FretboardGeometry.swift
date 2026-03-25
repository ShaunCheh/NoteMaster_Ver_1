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
    let scene: FretboardScene

    init(configuration: FretboardConfiguration, bounds: CGRect) {
        let normalizedBounds = bounds.standardized
        self.configuration = configuration
        self.bounds = normalizedBounds
        self.scene = FretboardSceneBuilder(
            configuration: configuration
        ).makeScene(bounds: normalizedBounds)
    }

    var drawingRect: CGRect {
        scene.drawingRect
    }

    var displayPositionCount: Int {
        configuration.displayPositionCount
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
        scene.openStringRect
    }

    var nutX: CGFloat {
        guard !openStringRect.isNull else {
            return 0
        }

        return openStringRect.maxX
    }

    var nutRect: CGRect {
        scene.nutRect
    }

    var fretboardRect: CGRect {
        scene.fretboardRect
    }

    var stringLines: [StringLine] {
        scene.stringSegments
            .sorted { $0.stringIndex < $1.stringIndex }
            .map { segment in
                StringLine(
                    stringIndex: segment.stringIndex,
                    y: (segment.start.y + segment.end.y) / 2
                )
            }
    }

    var fretLines: [FretLine] {
        scene.fretSegments
            .sorted { $0.fret < $1.fret }
            .map { segment in
                FretLine(
                    fret: segment.fret,
                    x: segment.start.x
                )
            }
    }

    var markerPlacements: [MarkerPlacement] {
        scene.markerPlacements.map { marker in
            MarkerPlacement(
                fret: marker.fret,
                style: markerStyle(from: marker.style),
                centers: marker.centers,
                diameter: marker.diameter
            )
        }
    }

    var stringLaneHeight: CGFloat {
        guard
            !drawingRect.isNull,
            configuration.stringCount > 0
        else {
            return 0
        }

        return drawingRect.height / CGFloat(configuration.stringCount)
    }

    var stringColumnRect: CGRect {
        guard
            !drawingRect.isNull,
            configuration.stringCount > 0
        else {
            return .null
        }

        return drawingRect
    }

    var stringYPositions: [CGFloat] {
        stringLines.map(\.y)
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
        guard configuration.fretRange.contains(position) else {
            return .null
        }

        return scene.fretSpanRect(at: position) ?? .null
    }

    func fretSegmentRect(at fret: Int) -> CGRect {
        guard fret > 0 else {
            return .null
        }

        return displaySlotRect(at: fret)
    }

    func fretLineX(for fret: Int) -> CGFloat? {
        if fret == 0 {
            return nutX
        }

        return scene.fretSegment(for: fret)?.start.x
    }

    func yPositionForString(_ stringIndex: Int) -> CGFloat? {
        guard let segment = scene.stringSegment(for: stringIndex) else {
            return nil
        }

        return (segment.start.y + segment.end.y) / 2
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
        FretboardSceneBuilder(configuration: configuration).hitTest(
            point,
            phase: phase,
            scene: scene
        )
    }

    func markerCenters(for fret: Int) -> [CGPoint] {
        scene.markerPlacements.first { $0.fret == fret }?.centers ?? []
    }

    private func nearestStringMatch(
        forY y: CGFloat
    ) -> (stringIndex: Int, distance: CGFloat)? {
        guard !scene.stringSegments.isEmpty else {
            return nil
        }

        return scene.stringSegments
            .map { segment in
                let stringY = (segment.start.y + segment.end.y) / 2
                return (
                    stringIndex: segment.stringIndex,
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

    private func markerStyle(
        from sceneStyle: FretboardScene.MarkerPlacement.Style
    ) -> MarkerPlacement.Style {
        switch sceneStyle {
        case .singleDot:
            return .singleDot
        case .doubleDot:
            return .doubleDot
        }
    }
}

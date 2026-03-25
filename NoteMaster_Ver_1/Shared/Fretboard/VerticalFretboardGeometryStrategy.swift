//
//  VerticalFretboardGeometryStrategy.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics

struct VerticalFretboardGeometryStrategy: FretboardGeometryStrategy {
    private static let contentFitTolerance: CGFloat = 0.5

    func makeScene(
        configuration: FretboardConfiguration,
        bounds: CGRect
    ) -> FretboardScene {
        let drawingRect = Self.makeDrawingRect(
            bounds: bounds,
            configuration: configuration
        )
        guard !drawingRect.isNull else {
            return .empty
        }

        let displayPositionCount = max(configuration.displayPositionCount, 1)
        let stringCount = max(configuration.stringCount, 1)
        let displaySlotHeight = drawingRect.height / CGFloat(displayPositionCount)
        let stringLaneWidth = drawingRect.width / CGFloat(stringCount)

        let cellFrames = configuration.fretRange.flatMap { fret in
            (0..<configuration.stringCount).map { stringIndex in
                FretboardScene.CellFrame(
                    stringIndex: stringIndex,
                    fret: fret,
                    frame: CGRect(
                        x: drawingRect.minX + (CGFloat(stringIndex) * stringLaneWidth),
                        y: drawingRect.minY + (CGFloat(fret) * displaySlotHeight),
                        width: stringLaneWidth,
                        height: displaySlotHeight
                    )
                )
            }
        }

        let stringSegments = (0..<configuration.stringCount).map { stringIndex in
            let x = drawingRect.minX + (stringLaneWidth * (CGFloat(stringIndex) + 0.5))
            return FretboardScene.StringSegment(
                stringIndex: stringIndex,
                start: CGPoint(x: x, y: drawingRect.minY),
                end: CGPoint(x: x, y: drawingRect.maxY)
            )
        }

        let fretSegments = makeFretSegments(
            configuration: configuration,
            drawingRect: drawingRect,
            displaySlotHeight: displaySlotHeight
        )
        let openStringRect = slotRect(
            for: 0,
            drawingRect: drawingRect,
            displaySlotHeight: displaySlotHeight
        )
        let nutRect = makeNutRect(
            configuration: configuration,
            drawingRect: drawingRect,
            openStringRect: openStringRect
        )
        let fretboardRect = makeFretboardRect(
            drawingRect: drawingRect,
            nutRect: nutRect
        )
        let markerPlacements = makeMarkerPlacements(
            configuration: configuration,
            drawingRect: drawingRect,
            displaySlotHeight: displaySlotHeight
        )
        let labelAnchors = cellFrames.map {
            FretboardScene.LabelAnchor(
                stringIndex: $0.stringIndex,
                fret: $0.fret,
                center: CGPoint(
                    x: $0.frame.midX,
                    y: $0.frame.midY
                ),
                cellFrame: $0.frame
            )
        }

        return FretboardScene(
            drawingRect: drawingRect,
            openStringRect: openStringRect,
            nutRect: nutRect,
            fretboardRect: fretboardRect,
            stringSegments: stringSegments,
            fretSegments: fretSegments,
            cellFrames: cellFrames,
            markerPlacements: markerPlacements,
            labelAnchors: labelAnchors
        )
    }

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase,
        configuration: FretboardConfiguration,
        scene: FretboardScene
    ) -> FretboardHitResult {
        let isInsideDrawingRect = contains(
            point,
            inInclusiveBoundsOf: scene.drawingRect
        )
        let nearestString = nearestStringMatch(
            forX: point.x,
            scene: scene
        )

        guard
            isInsideDrawingRect,
            let fret = displayPosition(
                forY: point.y,
                configuration: configuration,
                drawingRect: scene.drawingRect
            ),
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

    private func makeFretSegments(
        configuration: FretboardConfiguration,
        drawingRect: CGRect,
        displaySlotHeight: CGFloat
    ) -> [FretboardScene.FretSegment] {
        guard configuration.maxFret > 0 else {
            return []
        }

        return (1...configuration.maxFret).map { fret in
            let slotRect = slotRect(
                for: fret,
                drawingRect: drawingRect,
                displaySlotHeight: displaySlotHeight
            )
            return FretboardScene.FretSegment(
                fret: fret,
                start: CGPoint(x: drawingRect.minX, y: slotRect.maxY),
                end: CGPoint(x: drawingRect.maxX, y: slotRect.maxY)
            )
        }
    }

    private func makeNutRect(
        configuration: FretboardConfiguration,
        drawingRect: CGRect,
        openStringRect: CGRect
    ) -> CGRect {
        guard !drawingRect.isNull else {
            return .null
        }

        let height = min(
            max(
                configuration.layoutMetrics.nutWidthRatio * drawingRect.height,
                configuration.layoutMetrics.fretLineWidth
            ),
            drawingRect.height
        )

        return CGRect(
            x: drawingRect.minX,
            y: openStringRect.maxY - (height / 2),
            width: drawingRect.width,
            height: height
        )
    }

    private func makeFretboardRect(
        drawingRect: CGRect,
        nutRect: CGRect
    ) -> CGRect {
        guard !drawingRect.isNull else {
            return .null
        }

        let minY = min(nutRect.maxY, drawingRect.maxY)
        return CGRect(
            x: drawingRect.minX,
            y: minY,
            width: drawingRect.width,
            height: max(0, drawingRect.maxY - minY)
        )
    }

    private func makeMarkerPlacements(
        configuration: FretboardConfiguration,
        drawingRect: CGRect,
        displaySlotHeight: CGFloat
    ) -> [FretboardScene.MarkerPlacement] {
        guard !drawingRect.isNull else {
            return []
        }

        let markerDiameter = min(drawingRect.width, displaySlotHeight)
            * configuration.layoutMetrics.markerDiameterRatio
        let markerDoubleDotOffset = drawingRect.width
            * configuration.layoutMetrics.doubleMarkerOffsetRatio
        let singleDotFrets = Set(
            configuration.markerLayout.normalizedSingleDotFrets(
                upTo: configuration.maxFret
            )
        )
        let doubleDotFrets = Set(
            configuration.markerLayout.normalizedDoubleDotFrets(
                upTo: configuration.maxFret
            )
        )

        return configuration.markerLayout.allMarkerFrets(upTo: configuration.maxFret)
            .compactMap { fret in
                let slotRect = slotRect(
                    for: fret,
                    drawingRect: drawingRect,
                    displaySlotHeight: displaySlotHeight
                )
                guard !slotRect.isNull else {
                    return nil
                }

                let centerX = drawingRect.midX
                let centerY = slotRect.midY
                let centers: [CGPoint]
                let style: FretboardScene.MarkerPlacement.Style

                if doubleDotFrets.contains(fret) {
                    centers = [
                        CGPoint(x: centerX - markerDoubleDotOffset, y: centerY),
                        CGPoint(x: centerX + markerDoubleDotOffset, y: centerY)
                    ]
                    style = .doubleDot
                } else if singleDotFrets.contains(fret) {
                    centers = [
                        CGPoint(x: centerX, y: centerY)
                    ]
                    style = .singleDot
                } else {
                    return nil
                }

                return FretboardScene.MarkerPlacement(
                    fret: fret,
                    style: style,
                    centers: centers,
                    diameter: markerDiameter
                )
            }
    }

    private func slotRect(
        for position: Int,
        drawingRect: CGRect,
        displaySlotHeight: CGFloat
    ) -> CGRect {
        guard !drawingRect.isNull else {
            return .null
        }

        return CGRect(
            x: drawingRect.minX,
            y: drawingRect.minY + (CGFloat(position) * displaySlotHeight),
            width: drawingRect.width,
            height: displaySlotHeight
        )
    }

    private func displayPosition(
        forY y: CGFloat,
        configuration: FretboardConfiguration,
        drawingRect: CGRect
    ) -> Int? {
        guard
            !drawingRect.isNull,
            configuration.displayPositionCount > 0
        else {
            return nil
        }

        let displaySlotHeight = drawingRect.height / CGFloat(configuration.displayPositionCount)
        guard
            displaySlotHeight > 0,
            isValue(
                y,
                withinInclusiveRangeOf: drawingRect.minY,
                and: drawingRect.maxY
            )
        else {
            return nil
        }

        let relativeY = min(max(y - drawingRect.minY, 0), drawingRect.height)
        let rawPosition = Int(relativeY / displaySlotHeight)
        return min(rawPosition, configuration.maxFret)
    }

    private func nearestStringMatch(
        forX x: CGFloat,
        scene: FretboardScene
    ) -> (stringIndex: Int, distance: CGFloat)? {
        guard !scene.stringSegments.isEmpty else {
            return nil
        }

        return scene.stringSegments
            .map { segment in
                let stringX = (segment.start.x + segment.end.x) / 2
                return (
                    stringIndex: segment.stringIndex,
                    distance: abs(stringX - x)
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

    private static func makeDrawingRect(
        bounds: CGRect,
        configuration: FretboardConfiguration
    ) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return .null
        }

        let fullHeightContentWidth = configuration.verticalContentWidth(
            forViewportHeight: bounds.height
        )
        guard fullHeightContentWidth > 0 else {
            return .null
        }

        let totalWidth: CGFloat
        let totalHeight: CGFloat
        if bounds.width + contentFitTolerance >= fullHeightContentWidth {
            totalWidth = min(fullHeightContentWidth, bounds.width)
            totalHeight = bounds.height
        } else {
            totalWidth = bounds.width
            totalHeight = configuration.verticalContentHeight(
                forContentWidth: bounds.width
            )
        }

        guard totalWidth > 0, totalHeight > 0 else {
            return .null
        }

        let metrics = configuration.layoutMetrics
        let horizontalInset = min(
            max(totalWidth * metrics.horizontalInsetRatio, 0),
            totalWidth / 2
        )
        let drawingWidth = totalWidth - (horizontalInset * 2)
        guard drawingWidth > 0 else {
            return .null
        }

        let totalRect = CGRect(
            x: bounds.midX - (totalWidth / 2),
            y: bounds.midY - (totalHeight / 2),
            width: totalWidth,
            height: totalHeight
        )
        let rect = CGRect(
            x: totalRect.minX + horizontalInset,
            y: totalRect.minY,
            width: drawingWidth,
            height: totalRect.height
        )

        return rect.isNull || rect.isEmpty ? .null : rect
    }
}

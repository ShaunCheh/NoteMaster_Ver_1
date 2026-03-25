//
//  HorizontalFretboardGeometryStrategy.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics

struct HorizontalFretboardGeometryStrategy: FretboardGeometryStrategy {
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
        let displaySlotWidth = drawingRect.width / CGFloat(displayPositionCount)
        let stringLaneHeight = drawingRect.height / CGFloat(stringCount)

        let cellFrames = configuration.fretRange.flatMap { fret in
            (0..<configuration.stringCount).map { stringIndex in
                FretboardScene.CellFrame(
                    stringIndex: stringIndex,
                    fret: fret,
                    frame: CGRect(
                        x: drawingRect.minX + (CGFloat(fret) * displaySlotWidth),
                        y: drawingRect.minY + (CGFloat(stringIndex) * stringLaneHeight),
                        width: displaySlotWidth,
                        height: stringLaneHeight
                    )
                )
            }
        }

        let stringSegments = (0..<configuration.stringCount).map { stringIndex in
            let y = drawingRect.minY + (stringLaneHeight * (CGFloat(stringIndex) + 0.5))
            return FretboardScene.StringSegment(
                stringIndex: stringIndex,
                start: CGPoint(x: drawingRect.minX, y: y),
                end: CGPoint(x: drawingRect.maxX, y: y)
            )
        }

        let fretSegments = makeFretSegments(
            configuration: configuration,
            drawingRect: drawingRect,
            displaySlotWidth: displaySlotWidth
        )
        let openStringRect = slotRect(
            for: 0,
            drawingRect: drawingRect,
            displaySlotWidth: displaySlotWidth
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
            displaySlotWidth: displaySlotWidth
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
            forY: point.y,
            scene: scene
        )

        guard
            isInsideDrawingRect,
            let fret = displayPosition(
                forX: point.x,
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
        displaySlotWidth: CGFloat
    ) -> [FretboardScene.FretSegment] {
        guard configuration.maxFret > 0 else {
            return []
        }

        return (1...configuration.maxFret).map { fret in
            let slotRect = slotRect(
                for: fret,
                drawingRect: drawingRect,
                displaySlotWidth: displaySlotWidth
            )
            return FretboardScene.FretSegment(
                fret: fret,
                start: CGPoint(x: slotRect.maxX, y: drawingRect.minY),
                end: CGPoint(x: slotRect.maxX, y: drawingRect.maxY)
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

        let width = min(
            max(
                configuration.layoutMetrics.nutWidthRatio * drawingRect.width,
                configuration.layoutMetrics.fretLineWidth
            ),
            drawingRect.width
        )

        return CGRect(
            x: openStringRect.maxX - (width / 2),
            y: drawingRect.minY,
            width: width,
            height: drawingRect.height
        )
    }

    private func makeFretboardRect(
        drawingRect: CGRect,
        nutRect: CGRect
    ) -> CGRect {
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

    private func makeMarkerPlacements(
        configuration: FretboardConfiguration,
        drawingRect: CGRect,
        displaySlotWidth: CGFloat
    ) -> [FretboardScene.MarkerPlacement] {
        guard !drawingRect.isNull else {
            return []
        }

        let markerDiameter = min(displaySlotWidth, drawingRect.height)
            * configuration.layoutMetrics.markerDiameterRatio
        let markerDoubleDotOffset = drawingRect.height
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
                    displaySlotWidth: displaySlotWidth
                )
                guard !slotRect.isNull else {
                    return nil
                }

                let centerX = slotRect.midX
                let centerY = drawingRect.midY
                let centers: [CGPoint]
                let style: FretboardScene.MarkerPlacement.Style

                if doubleDotFrets.contains(fret) {
                    centers = [
                        CGPoint(x: centerX, y: centerY - markerDoubleDotOffset),
                        CGPoint(x: centerX, y: centerY + markerDoubleDotOffset)
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
        displaySlotWidth: CGFloat
    ) -> CGRect {
        guard !drawingRect.isNull else {
            return .null
        }

        return CGRect(
            x: drawingRect.minX + (CGFloat(position) * displaySlotWidth),
            y: drawingRect.minY,
            width: displaySlotWidth,
            height: drawingRect.height
        )
    }

    private func displayPosition(
        forX x: CGFloat,
        configuration: FretboardConfiguration,
        drawingRect: CGRect
    ) -> Int? {
        guard
            !drawingRect.isNull,
            configuration.displayPositionCount > 0
        else {
            return nil
        }

        let displaySlotWidth = drawingRect.width / CGFloat(configuration.displayPositionCount)
        guard
            displaySlotWidth > 0,
            isValue(
                x,
                withinInclusiveRangeOf: drawingRect.minX,
                and: drawingRect.maxX
            )
        else {
            return nil
        }

        let relativeX = min(max(x - drawingRect.minX, 0), drawingRect.width)
        let rawPosition = Int(relativeX / displaySlotWidth)
        return min(rawPosition, configuration.maxFret)
    }

    private func nearestStringMatch(
        forY y: CGFloat,
        scene: FretboardScene
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

    private static func makeDrawingRect(
        bounds: CGRect,
        configuration: FretboardConfiguration
    ) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return .null
        }

        let metrics = configuration.layoutMetrics
        let horizontalInset = min(
            max(bounds.width * metrics.horizontalInsetRatio, 0),
            bounds.width / 2
        )
        let drawingWidth = bounds.width - (horizontalInset * 2)
        guard drawingWidth > 0 else {
            return .null
        }

        // 在平台层尚未完成宽度驱动高度出口前，当前 bounds.height 可能仍来自旧链路；
        // 这里优先按宽度推导理想 drawingHeight，并在必要时裁剪到可用高度，避免几何越界。
        let idealDrawingHeight = configuration.layoutMetrics.drawingHeight(
            forAvailableWidth: bounds.width,
            displayPositionCount: configuration.displayPositionCount,
            stringCount: configuration.stringCount
        )
        let drawingHeight = min(max(idealDrawingHeight, 0), bounds.height)
        let rect = CGRect(
            x: bounds.minX + horizontalInset,
            y: bounds.midY - (drawingHeight / 2),
            width: drawingWidth,
            height: drawingHeight
        )

        return rect.isNull || rect.isEmpty ? .null : rect
    }
}

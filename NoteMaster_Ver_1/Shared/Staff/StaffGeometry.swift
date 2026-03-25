//
//  StaffGeometry.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics

struct StaffGeometry: Equatable, Sendable {
    struct StaffLineSegment: Equatable, Sendable {
        var lineIndex: Int
        var start: CGPoint
        var end: CGPoint
    }

    let configuration: StaffConfiguration
    let bounds: CGRect
    let orientation: StaffCanvasOrientation

    init(
        configuration: StaffConfiguration,
        bounds: CGRect,
        orientation: StaffCanvasOrientation? = nil
    ) {
        self.configuration = configuration
        self.bounds = bounds.standardized
        self.orientation = orientation ?? configuration.canvasOrientation
    }

    var drawingRect: CGRect {
        Self.makeDrawingRect(
            bounds: bounds,
            metrics: configuration.layoutMetrics
        )
    }

    var staffRect: CGRect {
        guard !drawingRect.isNull else {
            return .null
        }

        return CGRect(
            x: drawingRect.minX,
            y: staffTopY,
            width: drawingRect.width,
            height: staffHeight
        )
    }

    var clefAreaRect: CGRect {
        guard !drawingRect.isNull else {
            return .null
        }

        return CGRect(
            x: drawingRect.minX,
            y: drawingRect.minY,
            width: resolvedClefAreaWidth,
            height: drawingRect.height
        )
    }

    var staffHeight: CGFloat {
        guard !drawingRect.isNull else {
            return 0
        }

        return configuration.layoutMetrics.staffHeight()
    }

    var staffLineSegments: [StaffLineSegment] {
        (0..<resolvedStaffLineCount).compactMap { lineIndex in
            guard let y = lineY(at: lineIndex) else {
                return nil
            }

            return StaffLineSegment(
                lineIndex: lineIndex,
                start: CGPoint(x: drawingRect.minX, y: y),
                end: CGPoint(x: drawingRect.maxX, y: y)
            )
        }
    }

    func lineY(at index: Int) -> CGFloat? {
        guard
            !drawingRect.isNull,
            index >= 0,
            index < resolvedStaffLineCount
        else {
            return nil
        }

        return staffTopY + (CGFloat(index) * resolvedStaffSpaceHeight)
    }

    func spaceCenterY(at index: Int) -> CGFloat? {
        let maxSpaceIndex = resolvedStaffLineCount - 2
        guard
            !drawingRect.isNull,
            maxSpaceIndex >= 0,
            index >= 0,
            index <= maxSpaceIndex
        else {
            return nil
        }

        return staffTopY + ((CGFloat(index) + 0.5) * resolvedStaffSpaceHeight)
    }

    func clefAnchor(for clef: StaffClef) -> ClefAnchor {
        ClefAnchor(
            point: CGPoint(
                x: clefAreaRect.midX,
                y: lineY(at: clef.anchorLineIndex) ?? staffRect.midY
            ),
            semantic: clef.anchorSemantic,
            targetHeight: max(staffRect.height * configuration.layoutMetrics.clefScale, 1)
        )
    }

    private var resolvedStaffLineCount: Int {
        configuration.layoutMetrics.normalizedStaffLineCount
    }

    private var resolvedStaffSpaceHeight: CGFloat {
        configuration.layoutMetrics.normalizedStaffSpaceHeight
    }

    private var staffTopY: CGFloat {
        guard !drawingRect.isNull else {
            return 0
        }

        let availableTopPadding = max(drawingRect.height - staffHeight, 0)
        let resolvedTopPadding = configuration.layoutMetrics.defaultClefLayoutInsets(
            for: configuration.clef
        )?.top
        let fallbackCenteredPadding = availableTopPadding / 2

        return drawingRect.minY + min(
            max(resolvedTopPadding ?? fallbackCenteredPadding, 0),
            availableTopPadding
        )
    }

    private var resolvedClefAreaWidth: CGFloat {
        guard !drawingRect.isNull else {
            return 0
        }

        let proposedWidth = drawingRect.width * max(configuration.layoutMetrics.clefAreaWidthRatio, 0)
        let minimumWidth = resolvedStaffSpaceHeight * 2
        return min(max(proposedWidth, minimumWidth), drawingRect.width)
    }

    private static func makeDrawingRect(
        bounds: CGRect,
        metrics: StaffConfiguration.LayoutMetrics
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

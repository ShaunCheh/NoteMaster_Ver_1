//
//  PianoPresentation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics
import Foundation

struct PianoScaleSnapAnimationPlan: Equatable, Sendable {
    static let defaultDuration: TimeInterval = 0.12

    var fromRows: [PianoRowState]
    var toRows: [PianoRowState]
    var affectedRowIndices: [Int]
    var duration: TimeInterval

    init(
        fromRows: [PianoRowState],
        toRows: [PianoRowState],
        affectedRowIndices: [Int],
        duration: TimeInterval = Self.defaultDuration
    ) {
        self.fromRows = fromRows
        self.toRows = toRows
        self.affectedRowIndices = affectedRowIndices
        self.duration = duration
    }

    var hasConsistentRowCount: Bool {
        fromRows.count == toRows.count
    }

    var isNoOp: Bool {
        !hasConsistentRowCount || fromRows == toRows || affectedRowIndices.isEmpty
    }
}

enum PianoPresentationCommand: Equatable, Sendable {
    case animateScaleSnap(PianoScaleSnapAnimationPlan)
}

enum PianoPresentationMath {
    static func rows(
        for plan: PianoScaleSnapAnimationPlan,
        progress: CGFloat,
        configuration: PianoConfiguration
    ) -> [PianoRowState] {
        guard plan.hasConsistentRowCount else {
            return plan.toRows
        }

        let clampedProgress = clamp(progress)
        guard clampedProgress > 0 else {
            return plan.fromRows
        }
        guard clampedProgress < 1 else {
            return plan.toRows
        }

        let easedProgress = easeOutCubic(clampedProgress)
        let affectedRowIndices = Set(plan.affectedRowIndices)
        return zip(plan.fromRows, plan.toRows).enumerated().map { index, rows in
            let (fromRow, toRow) = rows
            guard affectedRowIndices.contains(index) else {
                return toRow
            }

            return interpolatedRow(
                from: fromRow,
                to: toRow,
                progress: easedProgress,
                configuration: configuration
            )
        }
    }

    static func interpolatedRow(
        from: PianoRowState,
        to: PianoRowState,
        progress: CGFloat,
        configuration: PianoConfiguration
    ) -> PianoRowState {
        let clampedProgress = clamp(progress)
        guard clampedProgress > 0 else {
            return from
        }
        guard clampedProgress < 1 else {
            return to
        }

        let fromAnchorX = PianoLayoutMath.noteLeadingX(
            from.startNote,
            configuration: configuration
        ) + from.offsetX
        let toAnchorX = PianoLayoutMath.noteLeadingX(
            to.startNote,
            configuration: configuration
        ) + to.offsetX
        let currentAnchorX = fromAnchorX + ((toAnchorX - fromAnchorX) * clampedProgress)
        let fromReferenceLeadingX = PianoLayoutMath.noteLeadingX(
            from.startNote,
            configuration: configuration
        )

        return PianoRowState(
            startNote: from.startNote,
            offsetX: currentAnchorX - fromReferenceLeadingX,
            movementScope: to.movementScope
        )
    }

    static func easeOutCubic(_ progress: CGFloat) -> CGFloat {
        let clampedProgress = clamp(progress)
        let inverseProgress = 1 - clampedProgress
        return 1 - (inverseProgress * inverseProgress * inverseProgress)
    }

    static func clamp(_ progress: CGFloat) -> CGFloat {
        min(max(progress, 0), 1)
    }
}

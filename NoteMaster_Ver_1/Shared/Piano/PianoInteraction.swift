//
//  PianoInteraction.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import Foundation
import CoreGraphics

enum PianoEventPhase: Equatable, Sendable {
    case began
    case moved
    case ended
    case cancelled

    var debugName: String {
        switch self {
        case .began:
            return "began"
        case .moved:
            return "moved"
        case .ended:
            return "ended"
        case .cancelled:
            return "cancelled"
        }
    }
}

enum PianoStepDirection: Int, Equatable, Hashable, Sendable {
    case left = -1
    case right = 1

    var semitoneDelta: Int {
        rawValue
    }

    var debugName: String {
        switch self {
        case .left:
            return "left"
        case .right:
            return "right"
        }
    }
}

enum PianoZone: Equatable, Hashable, Sendable {
    case buttonLeft
    case buttonRight
    case scale
    case keys
    case outside

    var buttonDirection: PianoStepDirection? {
        switch self {
        case .buttonLeft:
            return .left
        case .buttonRight:
            return .right
        case .scale, .keys, .outside:
            return nil
        }
    }

    var debugName: String {
        switch self {
        case .buttonLeft:
            return "buttonLeft"
        case .buttonRight:
            return "buttonRight"
        case .scale:
            return "scale"
        case .keys:
            return "keys"
        case .outside:
            return "outside"
        }
    }
}

struct PianoRawEvent: Equatable, Sendable {
    var phase: PianoEventPhase
    var locationInView: CGPoint
}

struct PianoHitResult: Equatable, Sendable {
    var phase: PianoEventPhase
    var locationInView: CGPoint
    var rowIndex: Int?
    var zone: PianoZone
    var note: NotePitch?
    var isInsideActiveZone: Bool

    var buttonDirection: PianoStepDirection? {
        zone.buttonDirection
    }

    var hasRowHit: Bool {
        rowIndex != nil
    }

    var hasNoteHit: Bool {
        note != nil
    }

    func debugSummary(platform: String) -> String {
        let pointText = String(
            format: "(%.1f, %.1f)",
            locationInView.x,
            locationInView.y
        )
        let rowText = rowIndex.map(String.init) ?? "nil"
        let noteText = note?.displayText() ?? "nil"
        let directionText = buttonDirection?.debugName ?? "nil"

        return "[\(platform)] phase=\(phase.debugName) row=\(rowText) zone=\(zone.debugName) note=\(noteText) direction=\(directionText) point=\(pointText) insideActiveZone=\(isInsideActiveZone)"
    }
}

struct PianoButtonPressInteraction: Equatable, Sendable {
    var rowIndex: Int
    var direction: PianoStepDirection
    var movementScope: PianoMovementScope
    var isTrackingInsideButton: Bool

    init(
        rowIndex: Int,
        direction: PianoStepDirection,
        movementScope: PianoMovementScope,
        isTrackingInsideButton: Bool = true
    ) {
        self.rowIndex = rowIndex
        self.direction = direction
        self.movementScope = movementScope
        self.isTrackingInsideButton = isTrackingInsideButton
    }
}

struct PianoScaleDragInteraction: Equatable, Sendable {
    var rowIndex: Int
    var movementScope: PianoMovementScope
    var beganLocationInView: CGPoint
    var affectedRowIndices: [Int]
    var initialOffsetsX: [CGFloat]

    var hasConsistentAffectedRows: Bool {
        affectedRowIndices.count == initialOffsetsX.count
    }
}

struct PianoKeyGlissandoInteraction: Equatable, Sendable {
    var rowIndex: Int
    var currentPreview: PianoPreviewState
}

enum PianoInteractionState: Equatable, Sendable {
    case buttonPressed(PianoButtonPressInteraction)
    case scaleDrag(PianoScaleDragInteraction)
    case keyGlissando(PianoKeyGlissandoInteraction)

    var rowIndex: Int {
        switch self {
        case let .buttonPressed(interaction):
            return interaction.rowIndex
        case let .scaleDrag(interaction):
            return interaction.rowIndex
        case let .keyGlissando(interaction):
            return interaction.rowIndex
        }
    }

    var debugName: String {
        switch self {
        case .buttonPressed:
            return "buttonPressed"
        case .scaleDrag:
            return "scaleDrag"
        case .keyGlissando:
            return "keyGlissando"
        }
    }
}

enum PianoSemanticEvent: Equatable, Sendable {
    case rowsChanged([PianoRowState])
    case previewStarted(PianoPreviewState)
    case previewChanged(PianoPreviewState)
    case previewEnded(PianoPreviewState)

    var debugName: String {
        switch self {
        case .rowsChanged:
            return "rowsChanged"
        case .previewStarted:
            return "previewStarted"
        case .previewChanged:
            return "previewChanged"
        case .previewEnded:
            return "previewEnded"
        }
    }
}

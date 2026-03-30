//
//  PianoState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics

enum PianoMovementScope: Equatable, Hashable, Sendable {
    case rowOnly
    case cascade

    var debugName: String {
        switch self {
        case .rowOnly:
            return "rowOnly"
        case .cascade:
            return "cascade"
        }
    }
}

struct PianoRowState: Equatable, Sendable {
    var startNote: NotePitch
    var offsetX: CGFloat
    var movementScope: PianoMovementScope

    init(
        startNote: NotePitch,
        offsetX: CGFloat = 0,
        movementScope: PianoMovementScope = .rowOnly
    ) {
        self.startNote = startNote
        self.offsetX = offsetX
        self.movementScope = movementScope
    }

    var startAbsoluteSemitone: Int {
        startNote.absoluteSemitone
    }

    func shiftedStartNote(by semitones: Int) -> PianoRowState {
        var nextState = self
        nextState.startNote = startNote.advanced(by: semitones)
        return nextState
    }

    func shiftedOffsetX(by deltaX: CGFloat) -> PianoRowState {
        var nextState = self
        nextState.offsetX += deltaX
        return nextState
    }
}

struct PianoPreviewState: Equatable, Sendable {
    var rowIndex: Int
    var note: NotePitch
}

struct PianoComponentState: Equatable, Sendable {
    static let empty = PianoComponentState(rows: [])

    var rows: [PianoRowState]
    var preview: PianoPreviewState?
    var activeInteraction: PianoInteractionState?

    init(
        rows: [PianoRowState],
        preview: PianoPreviewState? = nil,
        activeInteraction: PianoInteractionState? = nil
    ) {
        self.rows = rows
        self.preview = preview
        self.activeInteraction = activeInteraction
    }

    var rowCount: Int {
        rows.count
    }

    var isPreviewing: Bool {
        preview != nil
    }

    func rowState(at rowIndex: Int) -> PianoRowState? {
        guard rows.indices.contains(rowIndex) else {
            return nil
        }

        return rows[rowIndex]
    }
}

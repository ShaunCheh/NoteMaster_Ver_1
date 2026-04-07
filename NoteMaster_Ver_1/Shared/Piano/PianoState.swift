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
    var previewID: PianoPreviewID
    var rowIndex: Int
    var note: NotePitch

    init(
        previewID: PianoPreviewID = .legacyPrimary,
        rowIndex: Int,
        note: NotePitch
    ) {
        self.previewID = previewID
        self.rowIndex = rowIndex
        self.note = note
    }

    var voiceID: PianoVoiceID {
        previewID
    }
}

struct PianoComponentState: Equatable, Sendable {
    static let empty = PianoComponentState(rows: [])

    var rows: [PianoRowState]
    var activePreviews: [PianoPreviewID: PianoPreviewState]
    var activeInteractionsByPointer: [PianoPointerID: PianoInteractionState]

    init(
        rows: [PianoRowState],
        preview: PianoPreviewState? = nil,
        activeInteraction: PianoInteractionState? = nil
    ) {
        self.rows = rows
        activePreviews = [:]
        activeInteractionsByPointer = [:]
        self.preview = preview
        self.activeInteraction = activeInteraction
    }

    init(
        rows: [PianoRowState],
        activePreviews: [PianoPreviewID: PianoPreviewState],
        activeInteractionsByPointer: [PianoPointerID: PianoInteractionState] = [:]
    ) {
        self.rows = rows
        self.activePreviews = activePreviews
        self.activeInteractionsByPointer = activeInteractionsByPointer
    }

    var preview: PianoPreviewState? {
        get {
            if let preview = activePreviews[.legacyPrimary] {
                return preview
            }

            return activePreviews.values.min { lhs, rhs in
                lhs.previewID.rawValue < rhs.previewID.rawValue
            }
        }
        set {
            guard let newValue else {
                activePreviews.removeAll()
                return
            }

            // Legacy compatibility accessor: old call sites still assign a
            // single preview, so keep that write path collapsing to one entry.
            activePreviews = [newValue.previewID: newValue]
        }
    }

    var activeInteraction: PianoInteractionState? {
        get {
            if let interaction = activeInteractionsByPointer[.legacyPrimary] {
                return interaction
            }

            if let interaction = activeExclusiveControlInteraction {
                return interaction
            }

            return activeInteractionsByPointer
                .sorted { lhs, rhs in lhs.key.rawValue < rhs.key.rawValue }
                .first?
                .value
        }
        set {
            guard let newValue else {
                activeInteractionsByPointer.removeAll()
                return
            }

            // Legacy compatibility accessor: phase 2 will switch callers to the
            // pointer-indexed map directly.
            activeInteractionsByPointer = [newValue.pointerID: newValue]
        }
    }

    var rowCount: Int {
        rows.count
    }

    var isPreviewing: Bool {
        !activePreviews.isEmpty
    }

    var activeExclusiveControlInteraction: PianoInteractionState? {
        activeInteractionsByPointer.values
            .filter { $0.isExclusiveControlInteraction }
            .sorted { lhs, rhs in lhs.pointerID.rawValue < rhs.pointerID.rawValue }
            .first
    }

    var hasActiveExclusiveControlInteraction: Bool {
        activeExclusiveControlInteraction != nil
    }

    var hasActiveKeyPreviewInteractions: Bool {
        activeInteractionsByPointer.values.contains { $0.isKeyPreviewInteraction }
    }

    func interaction(for pointerID: PianoPointerID) -> PianoInteractionState? {
        activeInteractionsByPointer[pointerID]
    }

    func preview(for previewID: PianoPreviewID) -> PianoPreviewState? {
        activePreviews[previewID]
    }

    func preview(for pointerID: PianoPointerID) -> PianoPreviewState? {
        preview(for: pointerID.previewID)
    }

    func hasExclusiveControlInteraction(ownedBy pointerID: PianoPointerID) -> Bool {
        activeInteractionsByPointer.contains { entry in
            entry.key != pointerID && entry.value.isExclusiveControlInteraction
        }
    }

    mutating func setPreview(
        _ preview: PianoPreviewState?,
        for previewID: PianoPreviewID
    ) {
        guard let preview else {
            activePreviews.removeValue(forKey: previewID)
            return
        }

        activePreviews[previewID] = preview
    }

    mutating func setPreview(
        _ preview: PianoPreviewState?,
        for pointerID: PianoPointerID
    ) {
        setPreview(preview, for: pointerID.previewID)
    }

    mutating func setInteraction(
        _ interaction: PianoInteractionState?,
        for pointerID: PianoPointerID
    ) {
        guard let interaction else {
            activeInteractionsByPointer.removeValue(forKey: pointerID)
            return
        }

        activeInteractionsByPointer[pointerID] = interaction
    }

    func rowState(at rowIndex: Int) -> PianoRowState? {
        guard rows.indices.contains(rowIndex) else {
            return nil
        }

        return rows[rowIndex]
    }
}

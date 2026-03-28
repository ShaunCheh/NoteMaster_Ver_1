//
//  FretboardFeedbackOverlayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/28.
//

struct FretboardFeedbackOverlayState: Equatable, Sendable {
    var correctCells: Set<FretboardCell>
    var wrongCell: FretboardCell?

    static let empty = FretboardFeedbackOverlayState()

    init(
        correctCells: Set<FretboardCell> = [],
        wrongCell: FretboardCell? = nil
    ) {
        self.correctCells = correctCells
        self.wrongCell = wrongCell
    }

    var isEmpty: Bool {
        correctCells.isEmpty && wrongCell == nil
    }
}

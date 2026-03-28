//
//  FretboardFeedbackOverlayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/28.
//

enum FretboardFeedbackOverlayState: Equatable, Sendable {
    enum PositionPromptPhase: Equatable, Sendable {
        case neutralWhite
        case wrongFlash
        case correctHold
    }

    case empty
    case singleCoverage(
        correctCells: Set<FretboardCell>,
        wrongCell: FretboardCell?
    )
    case positionPrompt(
        promptCell: FretboardCell,
        phase: PositionPromptPhase
    )

    var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case let .singleCoverage(correctCells, wrongCell):
            return correctCells.isEmpty && wrongCell == nil
        case .positionPrompt:
            return false
        }
    }
}

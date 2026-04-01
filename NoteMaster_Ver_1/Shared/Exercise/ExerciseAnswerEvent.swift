//
//  ExerciseAnswerEvent.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

enum ExerciseAnswerPayload: Equatable, Sendable {
    case pitchClass(PitchClass)
    case fretboardCell(FretboardCell)

    var pitchClass: PitchClass? {
        guard case let .pitchClass(pitchClass) = self else {
            return nil
        }
        return pitchClass
    }

    var fretboardCell: FretboardCell? {
        guard case let .fretboardCell(cell) = self else {
            return nil
        }
        return cell
    }
}

struct ExerciseAnswerEvent: Equatable, Sendable {
    var surfaceID: ExerciseSurfaceID
    var payload: ExerciseAnswerPayload

    static func pitchClass(
        _ pitchClass: PitchClass,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .pitchClass(pitchClass)
        )
    }

    static func fretboardCell(
        _ cell: FretboardCell,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .fretboardCell(cell)
        )
    }
}

//
//  ExerciseAnswerEvent.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

enum ExerciseAnswerPayload: Equatable, Sendable {
    case pitchClass(PitchClass)
    case notePitch(NotePitch)
    case fretboardCell(FretboardCell)

    var pitchClass: PitchClass? {
        switch self {
        case let .pitchClass(pitchClass):
            return pitchClass
        case let .notePitch(notePitch):
            return notePitch.pitchClass
        case .fretboardCell:
            return nil
        }
    }

    var notePitch: NotePitch? {
        guard case let .notePitch(notePitch) = self else {
            return nil
        }
        return notePitch
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

    static func notePitch(
        _ notePitch: NotePitch,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .notePitch(notePitch)
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

struct ResolvedSequenceAnswer: Equatable, Sendable {
    var pitchClass: PitchClass
    var notePitch: NotePitch?
    var surfaceID: ExerciseSurfaceID
}

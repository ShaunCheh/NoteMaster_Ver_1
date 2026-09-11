//
//  ExerciseAnswerRouter.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

enum ExerciseAnswerRouteIgnoreReason: Equatable, Sendable {
    case surfaceUnavailable(ExerciseSurfaceID)
    case surfaceHidden(ExerciseSurfaceID)
    case answerDisabled(ExerciseSurfaceID)
    case interactionDisabled(ExerciseSurfaceID)
    case unsupportedPayload(
        ExerciseAnswerPayload,
        TrainerExerciseMode
    )
    case unresolvedPitchClass(
        FretboardCell,
        TrainerExerciseMode
    )

    var debugDescription: String {
        switch self {
        case let .surfaceUnavailable(surfaceID):
            return "surfaceUnavailable(\(surfaceID.rawValue))"
        case let .surfaceHidden(surfaceID):
            return "surfaceHidden(\(surfaceID.rawValue))"
        case let .answerDisabled(surfaceID):
            return "answerDisabled(\(surfaceID.rawValue))"
        case let .interactionDisabled(surfaceID):
            return "interactionDisabled(\(surfaceID.rawValue))"
        case let .unsupportedPayload(_, mode):
            return "unsupportedPayload(\(debugName(for: mode)))"
        case let .unresolvedPitchClass(cell, mode):
            return "unresolvedPitchClass(\(debugName(for: mode)),string=\(cell.stringIndex),fret=\(cell.fret))"
        }
    }

    private func debugName(for mode: TrainerExerciseMode) -> String {
        switch mode {
        case .single:
            return "single"
        case .sequence:
            return "sequence"
        case .p2:
            return "p2"
        case .positionPrompt:
            return "positionPrompt"
        case .fr0:
            return "fr0"
        case .sr0:
            return "sr0"
        case .sr1:
            return "sr1"
        case .sr2:
            return "sr2"
        case .bcr1:
            return "bcr1"
        }
    }
}

struct ExercisePositionPromptRoutedAnswer: Equatable, Sendable {
    var event: ExerciseAnswerEvent
    var pitchClass: PitchClass
}

enum ExerciseAnswerRoute: Equatable, Sendable {
    case singleCoverage(
        event: ExerciseAnswerEvent,
        cell: FretboardCell
    )
    case quarterNoteSequence(
        event: ExerciseAnswerEvent,
        answer: ResolvedSequenceAnswer
    )
    case positionPrompt(
        ExercisePositionPromptRoutedAnswer
    )
}

enum ExerciseAnswerRoutingResult: Equatable, Sendable {
    case routed(ExerciseAnswerRoute)
    case ignored(ExerciseAnswerRouteIgnoreReason)
}

enum ExerciseAnswerRouter {
    static func route(
        _ event: ExerciseAnswerEvent,
        presentationState: ExercisePresentationState,
        trainerDisplayState: TrainerDisplayState,
        fretboardConfiguration: FretboardConfiguration
    ) -> ExerciseAnswerRoutingResult {
        if let ignoredReason = validateAnswerSurface(
            event.surfaceID,
            in: presentationState
        ) {
            return .ignored(ignoredReason)
        }

        switch trainerDisplayState.exerciseMode {
        case .single, .fr0:
            guard let cell = event.payload.fretboardCell else {
                return .ignored(
                    .unsupportedPayload(
                        event.payload,
                        trainerDisplayState.exerciseMode
                    )
                )
            }
            return .routed(
                .singleCoverage(
                    event: event,
                    cell: cell
                )
            )
        case .sequence, .p2, .sr0, .sr1, .sr2, .bcr1:
            guard let answer = FretboardNaturalNoteTrainerState
                .resolvedSequenceAnswer(
                    from: event,
                    configuration: fretboardConfiguration
                ) else {
                if let cell = event.payload.fretboardCell {
                    return .ignored(
                        .unresolvedPitchClass(
                            cell,
                            trainerDisplayState.exerciseMode
                        )
                    )
                }
                return .ignored(
                    .unsupportedPayload(
                        event.payload,
                        trainerDisplayState.exerciseMode
                    )
                )
            }

            return .routed(
                .quarterNoteSequence(
                    event: event,
                    answer: answer
                )
            )
        case .positionPrompt:
            guard let pitchClass = FretboardNaturalNoteTrainerState
                .resolvedPositionPromptAnswerPitchClass(
                    from: event,
                    configuration: fretboardConfiguration,
                    answerRule: trainerDisplayState.positionPromptAnswerRule
                ) else {
                if let cell = event.payload.fretboardCell {
                    return .ignored(
                        .unresolvedPitchClass(
                            cell,
                            trainerDisplayState.exerciseMode
                        )
                    )
                }
                return .ignored(
                    .unsupportedPayload(
                        event.payload,
                        trainerDisplayState.exerciseMode
                    )
                )
            }

            return .routed(
                .positionPrompt(
                    ExercisePositionPromptRoutedAnswer(
                        event: event,
                        pitchClass: pitchClass
                    )
                )
            )
        }
    }

    private static func validateAnswerSurface(
        _ surfaceID: ExerciseSurfaceID,
        in presentationState: ExercisePresentationState
    ) -> ExerciseAnswerRouteIgnoreReason? {
        guard presentationState.containsSurface(surfaceID) else {
            return .surfaceUnavailable(surfaceID)
        }

        let surfaceState = presentationState.effectiveSurfaceState(for: surfaceID)
        guard surfaceState.isVisible else {
            return .surfaceHidden(surfaceID)
        }
        guard surfaceState.isAnswerEnabled else {
            return .answerDisabled(surfaceID)
        }
        guard surfaceState.isInteractionEnabled else {
            return .interactionDisabled(surfaceID)
        }
        return nil
    }
}

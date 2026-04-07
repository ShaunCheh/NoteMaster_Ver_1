//
//  RootModeState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

struct ExerciseModeState: Equatable, Sendable {
    var trainerDisplayState: TrainerDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences

    static let `default` = ExerciseModeState(
        trainerDisplayState: .default,
        exerciseLayoutPreferences: .legacyPositionPrompt
    )
}

struct PlayModeState: Equatable, Sendable {
    var isPianoInteractive: Bool

    static let `default` = PlayModeState()

    init(
        isPianoInteractive: Bool = true
    ) {
        self.isPianoInteractive = isPianoInteractive
    }

    var compositionInput: PlayCompositionPolicyInput {
        PlayCompositionPolicyInput(
            isPianoInteractive: isPianoInteractive
        )
    }
}

struct RootModeState: Equatable, Sendable {
    var rootMode: RootMode
    var exercise: ExerciseModeState
    var play: PlayModeState

    static let `default` = RootModeState()

    init(
        rootMode: RootMode = .defaultMode,
        exercise: ExerciseModeState = .default,
        play: PlayModeState = .default
    ) {
        self.rootMode = rootMode
        self.exercise = exercise
        self.play = play
    }
}

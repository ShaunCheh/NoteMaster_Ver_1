//
//  SettingsPanelStateContext.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

struct SettingsDebugState: Equatable, Sendable {
    var showsSideBySideContainerOutlines: Bool = false
}

struct SettingsPanelCommonState: Equatable, Sendable {
    var rootMode: RootMode
    var pianoPanelState: PianoPanelState
}

struct SettingsPanelExerciseState: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var modeState: ExerciseModeState
    var debugState: SettingsDebugState
}

struct SettingsPanelPlayState: Equatable, Sendable {
    var modeState: PlayModeState

    init(
        modeState: PlayModeState = .default
    ) {
        self.modeState = modeState
    }
}

struct SettingsPanelStateContext: Equatable, Sendable {
    var common: SettingsPanelCommonState
    var exercise: SettingsPanelExerciseState
    var play: SettingsPanelPlayState

    static let `default` = SettingsPanelStateContext(
        exerciseLayoutPreferences: .legacyPositionPrompt,
        trainerDisplayState: .default,
        pianoPanelState: .init()
    )
    static let playDefault = SettingsPanelStateContext(
        rootMode: .play,
        exerciseLayoutPreferences: .legacyPositionPrompt,
        trainerDisplayState: .default,
        pianoPanelState: .init()
    )

    init(
        rootMode: RootMode = .defaultMode,
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState? = nil,
        exerciseLayoutPreferences: ExerciseLayoutPreferences? = nil,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init(),
        debugState: SettingsDebugState = .init(),
        playModeState: PlayModeState = .default
    ) {
        self.common = SettingsPanelCommonState(
            rootMode: rootMode,
            pianoPanelState: pianoPanelState
        )
        self.exercise = Self.resolvedExerciseState(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState,
            pageDisplayState: pageDisplayState,
            exerciseLayoutPreferences: exerciseLayoutPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: pianoPanelState,
            debugState: debugState
        )
        self.play = SettingsPanelPlayState(modeState: playModeState)
        reconcileForCurrentMode()
    }

    var rootModeState: RootModeState {
        get {
            RootModeState(
                rootMode: common.rootMode,
                exercise: exercise.modeState,
                play: play.modeState
            )
        }
        set {
            common.rootMode = newValue.rootMode
            exercise.modeState = newValue.exercise
            play.modeState = newValue.play
        }
    }

    var rootMode: RootMode {
        get { common.rootMode }
        set { common.rootMode = newValue }
    }

    var fretboardDisplayState: FretboardDisplayState {
        get { exercise.fretboardDisplayState }
        set { exercise.fretboardDisplayState = newValue }
    }

    var staffDisplayState: StaffDisplayState {
        get { exercise.staffDisplayState }
        set { exercise.staffDisplayState = newValue }
    }

    var pageDisplayState: PageDisplayState {
        get { exercise.pageDisplayState }
        set { exercise.pageDisplayState = newValue }
    }

    var exerciseLayoutPreferences: ExerciseLayoutPreferences {
        get { exercise.modeState.exerciseLayoutPreferences }
        set { exercise.modeState.exerciseLayoutPreferences = newValue }
    }

    var trainerDisplayState: TrainerDisplayState {
        get { exercise.modeState.trainerDisplayState }
        set { exercise.modeState.trainerDisplayState = newValue }
    }

    var pianoPanelState: PianoPanelState {
        get { common.pianoPanelState }
        set { common.pianoPanelState = newValue }
    }

    var debugState: SettingsDebugState {
        get { exercise.debugState }
        set { exercise.debugState = newValue }
    }

    var playModeState: PlayModeState {
        get { play.modeState }
        set { play.modeState = newValue }
    }

    var isExerciseModeActive: Bool {
        rootMode == .exercise
    }

    var isPlayModeActive: Bool {
        rootMode == .play
    }

    mutating func reconcileForCurrentMode() {
        switch rootMode {
        case .exercise:
            LegacyPageLayoutAdapter.reconcile(&self)
        case .play:
            normalizeExerciseStateForBackgroundRetention()
        }
    }

    private static func resolvedExerciseState(
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState,
        pageDisplayState: PageDisplayState?,
        exerciseLayoutPreferences: ExerciseLayoutPreferences?,
        trainerDisplayState: TrainerDisplayState,
        pianoPanelState: PianoPanelState,
        debugState: SettingsDebugState
    ) -> SettingsPanelExerciseState {
        let resolvedLayoutPreferences = Self.resolvedLayoutPreferences(
            pageDisplayState: pageDisplayState,
            exerciseLayoutPreferences: exerciseLayoutPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: pianoPanelState
        )
        let resolvedPageDisplayState = pageDisplayState
            ?? LegacyPageLayoutAdapter.projectedPageDisplayState(
                from: resolvedLayoutPreferences,
                trainerDisplayState: trainerDisplayState
            )
        return SettingsPanelExerciseState(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState,
            pageDisplayState: resolvedPageDisplayState,
            modeState: ExerciseModeState(
                trainerDisplayState: trainerDisplayState,
                exerciseLayoutPreferences: resolvedLayoutPreferences
            ),
            debugState: debugState
        )
    }

    private static func resolvedLayoutPreferences(
        pageDisplayState: PageDisplayState?,
        exerciseLayoutPreferences: ExerciseLayoutPreferences?,
        trainerDisplayState: TrainerDisplayState,
        pianoPanelState: PianoPanelState
    ) -> ExerciseLayoutPreferences {
        if let exerciseLayoutPreferences {
            return LegacyPageLayoutAdapter.normalizedPreferences(
                exerciseLayoutPreferences,
                trainerDisplayState: trainerDisplayState
            )
        }

        if let pageDisplayState {
            return LegacyPageLayoutAdapter.inferredPreferences(
                pageDisplayState: pageDisplayState,
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: pianoPanelState
            )
        }

        var fallbackPreferences = trainerDisplayState.isPositionPromptMode
            ? ExerciseLayoutPreferences.legacyPositionPrompt
            : .default
        fallbackPreferences.isPianoAccessoryVisible = pianoPanelState.isVisible
        return LegacyPageLayoutAdapter.normalizedPreferences(
            fallbackPreferences,
            trainerDisplayState: trainerDisplayState
        )
    }

    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        let resolvedPreferences = ExerciseCompositionPolicy.normalizedPreferences(
            exerciseLayoutPreferences,
            trainerDisplayState: trainerDisplayState
        )
        let scene = ExerciseCompositionPolicy.makeScene(
            preferences: resolvedPreferences
        )
        return scene.fretboardLayoutContract(
            layoutPreferences: resolvedPreferences
        )
    }

    var showsVerticalViewportHeightControl: Bool {
        fretboardDisplayState.displayMode == .vertical
            && fretboardLayoutContract.usesVerticalViewportHeightControl
    }

    private mutating func normalizeExerciseStateForBackgroundRetention() {
        let resolvedLayoutPreferences = Self.resolvedLayoutPreferences(
            pageDisplayState: exercise.pageDisplayState,
            exerciseLayoutPreferences: exercise.modeState.exerciseLayoutPreferences,
            trainerDisplayState: exercise.modeState.trainerDisplayState,
            pianoPanelState: common.pianoPanelState
        )
        exercise.modeState.exerciseLayoutPreferences = resolvedLayoutPreferences
        exercise.pageDisplayState = LegacyPageLayoutAdapter.projectedPageDisplayState(
            from: resolvedLayoutPreferences,
            trainerDisplayState: exercise.modeState.trainerDisplayState
        )
    }
}

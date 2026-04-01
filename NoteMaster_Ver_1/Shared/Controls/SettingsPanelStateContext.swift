//
//  SettingsPanelStateContext.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState

    static let `default` = SettingsPanelStateContext(
        exerciseLayoutPreferences: .legacyPositionPrompt,
        trainerDisplayState: .default,
        pianoPanelState: .init()
    )

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState? = nil,
        exerciseLayoutPreferences: ExerciseLayoutPreferences? = nil,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init()
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.trainerDisplayState = trainerDisplayState
        self.pianoPanelState = pianoPanelState
        self.exerciseLayoutPreferences = Self.resolvedLayoutPreferences(
            pageDisplayState: pageDisplayState,
            exerciseLayoutPreferences: exerciseLayoutPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: pianoPanelState
        )
        self.pageDisplayState = pageDisplayState
            ?? LegacyPageLayoutAdapter.projectedPageDisplayState(
                from: self.exerciseLayoutPreferences,
                trainerDisplayState: trainerDisplayState
            )
        LegacyPageLayoutAdapter.reconcile(&self)
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
}

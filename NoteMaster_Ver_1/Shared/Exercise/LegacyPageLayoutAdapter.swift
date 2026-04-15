//
//  LegacyPageLayoutAdapter.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

enum LegacyPageLayoutAdapter {
    static func inferredPreferences(
        pageDisplayState: PageDisplayState,
        trainerDisplayState: TrainerDisplayState,
        pianoPanelState: PianoPanelState
    ) -> ExerciseLayoutPreferences {
        let inferredCompositionPreset: ExerciseCompositionPreset

        switch trainerDisplayState.exerciseMode {
        case .positionPrompt:
            inferredCompositionPreset = .fretboardToNaturalNoteStrip
        case .single, .sequence, .sr1, .sr2:
            switch pageDisplayState.topContentMode {
            case .targetPrompt:
                inferredCompositionPreset = .targetPromptToFretboard
            case .staff, .fretboard:
                inferredCompositionPreset = .staffToFretboard
            }
        }

        return normalizedPreferences(
            ExerciseLayoutPreferences(
                compositionPreset: inferredCompositionPreset,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: pageDisplayState.mainContentMode
                    == .naturalNoteStrip,
                isPianoAccessoryVisible: pianoPanelState.isVisible,
                isAccessoryExpanded: true
            ),
            trainerDisplayState: trainerDisplayState
        )
    }

    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        ExerciseCompositionPolicy.normalizedPreferences(
            preferences,
            trainerDisplayState: trainerDisplayState
        )
    }

    static func projectedPageDisplayState(
        from preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> PageDisplayState {
        let presentationState = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: policyInput(
                    trainerDisplayState: trainerDisplayState,
                    pianoPanelState: .init(),
                    layoutPreferences: preferences
                )
            )

        if let legacyPageDisplayState = presentationState.legacyPageDisplayState {
            return legacyPageDisplayState
        }

        switch trainerDisplayState.exerciseMode {
        case .single, .sequence, .sr1, .sr2:
            return .default
        case .positionPrompt:
            return .positionPrompt
        }
    }

    static func isCompositionPresetSupported(
        _ preset: ExerciseCompositionPreset,
        for exerciseMode: TrainerExerciseMode
    ) -> Bool {
        ExerciseCompositionPolicy.isCompositionPresetSupported(
            preset,
            for: exerciseMode
        )
    }

    static func isLayoutPresetSupported(
        _ preset: ExerciseLayoutPreset,
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        var requestedPreferences = stateContext.exerciseLayoutPreferences
        requestedPreferences.layoutPreset = preset

        let normalizedPreferences = normalizedPreferences(
            requestedPreferences,
            trainerDisplayState: stateContext.trainerDisplayState
        )
        return normalizedPreferences.layoutPreset == preset
    }

    static func isAccessoryPresentationSupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        ExerciseCompositionPolicy.isAccessoryPresentationSupported(
            presentation
        )
    }

    static func isNaturalStripToggleSupported(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        stateContext.exerciseLayoutPreferences.compositionPreset
            != .fretboardToNaturalNoteStrip
    }

    static func isAccessoryExpandedSupported(
        accessoryPresentation: ExerciseAccessoryPresentation
    ) -> Bool {
        accessoryPresentation == .collapsible
    }

    static func reconcile(
        _ stateContext: inout SettingsPanelStateContext
    ) {
        stateContext.exerciseLayoutPreferences = normalizedPreferences(
            stateContext.exerciseLayoutPreferences,
            trainerDisplayState: stateContext.trainerDisplayState
        )
        stateContext.pageDisplayState = projectedPageDisplayState(
            from: stateContext.exerciseLayoutPreferences,
            trainerDisplayState: stateContext.trainerDisplayState
        )
        stateContext.pianoPanelState.isVisible = stateContext
            .exerciseLayoutPreferences
            .isPianoAccessoryVisible
    }

    private static func policyInput(
        trainerDisplayState: TrainerDisplayState,
        pianoPanelState: PianoPanelState,
        layoutPreferences: ExerciseLayoutPreferences
    ) -> ExerciseCompositionPolicyInput {
        ExerciseCompositionPolicyInput(
            trainerDisplayState: trainerDisplayState,
            fretboardTrainerState: .init(),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: pianoPanelState,
            layoutPreferences: layoutPreferences
        )
    }
}

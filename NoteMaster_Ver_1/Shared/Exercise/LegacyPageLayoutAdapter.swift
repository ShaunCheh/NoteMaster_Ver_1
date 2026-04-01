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
        case .single, .sequence:
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
        ExerciseCompositionPolicy.legacyCompatiblePreferences(
            from: policyInput(
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: .init(),
                layoutPreferences: preferences
            )
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
        case .single, .sequence:
            return .default
        case .positionPrompt:
            return .positionPrompt
        }
    }

    static func isCompositionPresetSupported(
        _ preset: ExerciseCompositionPreset,
        for exerciseMode: TrainerExerciseMode
    ) -> Bool {
        let requestedPreferences = ExerciseLayoutPreferences(
            compositionPreset: preset,
            layoutPreset: preset == .fretboardSelfAnswer
                ? .singleSurface
                : .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: preset == .fretboardToNaturalNoteStrip,
            isPianoAccessoryVisible: false,
            isAccessoryExpanded: true
        )
        let legacyCompatiblePreferences = ExerciseCompositionPolicy
            .legacyCompatiblePreferences(
                from: policyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: exerciseMode
                    ),
                    pianoPanelState: .init(),
                    layoutPreferences: requestedPreferences
                )
            )
        return legacyCompatiblePreferences.compositionPreset == preset
    }

    static func isLayoutPresetSupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        let legacyCompatiblePreferences = ExerciseCompositionPolicy
            .legacyCompatiblePreferences(
                from: policyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .single
                    ),
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: preset
                    )
                )
            )
        return legacyCompatiblePreferences.layoutPreset == preset
    }

    static func isAccessoryPresentationSupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        let legacyCompatiblePreferences = ExerciseCompositionPolicy
            .legacyCompatiblePreferences(
                from: policyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .single
                    ),
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: .stacked,
                        accessoryPresentation: presentation
                    )
                )
            )
        return legacyCompatiblePreferences.accessoryPresentation == presentation
    }

    static func isNaturalStripToggleSupported(
        in _: SettingsPanelStateContext
    ) -> Bool {
        false
    }

    static func isAccessoryExpandedSupported(
        accessoryPresentation _: ExerciseAccessoryPresentation
    ) -> Bool {
        false
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

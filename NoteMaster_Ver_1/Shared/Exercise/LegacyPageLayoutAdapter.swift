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
        var normalized = preferences

        switch trainerDisplayState.exerciseMode {
        case .single, .sequence:
            if !isCompositionPresetSupported(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            ) {
                normalized.compositionPreset = .staffToFretboard
            }
            normalized.isNaturalNoteStripVisible = false
        case .positionPrompt:
            normalized.compositionPreset = .fretboardToNaturalNoteStrip
            normalized.isNaturalNoteStripVisible = true
        }

        if !isLayoutPresetSupported(normalized.layoutPreset) {
            normalized.layoutPreset = .stacked
        }
        if !isAccessoryPresentationSupported(
            normalized.accessoryPresentation
        ) {
            normalized.accessoryPresentation = .docked
        }
        if !isAccessoryExpandedSupported(
            accessoryPresentation: normalized.accessoryPresentation
        ) {
            normalized.isAccessoryExpanded = true
        }

        return normalized
    }

    static func projectedPageDisplayState(
        from preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> PageDisplayState {
        let normalizedPreferences = normalizedPreferences(
            preferences,
            trainerDisplayState: trainerDisplayState
        )

        switch trainerDisplayState.exerciseMode {
        case .positionPrompt:
            return .positionPrompt
        case .single, .sequence:
            switch normalizedPreferences.compositionPreset {
            case .targetPromptToFretboard:
                return PageDisplayState(
                    topContentMode: .targetPrompt,
                    mainContentMode: .fretboard
                )
            case .staffToFretboard,
                 .fretboardToNaturalNoteStrip,
                 .fretboardSelfAnswer:
                return .default
            }
        }
    }

    static func isCompositionPresetSupported(
        _ preset: ExerciseCompositionPreset,
        for exerciseMode: TrainerExerciseMode
    ) -> Bool {
        switch exerciseMode {
        case .single, .sequence:
            switch preset {
            case .staffToFretboard, .targetPromptToFretboard:
                return true
            case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
                return false
            }
        case .positionPrompt:
            return preset == .fretboardToNaturalNoteStrip
        }
    }

    static func isLayoutPresetSupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        preset == .stacked
    }

    static func isAccessoryPresentationSupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        presentation == .docked
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
}

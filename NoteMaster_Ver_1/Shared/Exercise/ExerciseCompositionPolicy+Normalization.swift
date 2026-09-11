extension ExerciseCompositionPolicy {
    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        var normalized = preferences
        if let fixedPreferences = trainerDisplayState.exerciseMode
            .fixedExerciseLayoutPreferences {
            normalized = fixedPreferences
        } else {
            normalized.compositionPreset = normalizedCompositionPreset(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            )
            normalized.layoutPreset = normalizedLayoutPreset(
                normalized.layoutPreset,
                for: normalized.compositionPreset
            )
        }

        if !isAccessoryPresentationSupported(normalized.accessoryPresentation) {
            normalized.accessoryPresentation = .docked
        }
        if normalized.accessoryPresentation != .collapsible {
            normalized.isAccessoryExpanded = true
        }

        if normalized.compositionPreset.usesMainNaturalNoteStripAnswerSurface {
            normalized.isNaturalNoteStripVisible = true
        }
        if normalized.compositionPreset.usesMainPianoAnswerSurface {
            normalized.isPianoAccessoryVisible = false
        }

        return normalized
    }

    static func isCompositionPresetSupported(
        _ preset: ExerciseCompositionPreset,
        for exerciseMode: TrainerExerciseMode
    ) -> Bool {
        if let fixedCompositionPreset = exerciseMode.fixedCompositionPreset {
            return preset == fixedCompositionPreset
        }

        switch exerciseMode {
        case .single, .sequence:
            switch preset {
            case .staffToFretboard, .targetPromptToFretboard:
                return true
            case .staffToPiano,
                 .staffToNaturalNoteStrip,
                 .fretboardToNaturalNoteStrip,
                 .fretboardSelfAnswer:
                return false
            }
        case .p2, .fr0, .sr0, .sr1, .sr2, .bcr1:
            return false
        case .positionPrompt:
            switch preset {
            case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
                return true
            case .staffToFretboard,
                 .staffToPiano,
                 .staffToNaturalNoteStrip,
                 .targetPromptToFretboard:
                return false
            }
        }
    }

    static func isAccessoryPresentationSupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        switch presentation {
        case .docked, .floating, .collapsible:
            return true
        }
    }
}

private extension ExerciseCompositionPolicy {
    static func normalizedCompositionPreset(
        _ preset: ExerciseCompositionPreset,
        for exerciseMode: TrainerExerciseMode
    ) -> ExerciseCompositionPreset {
        if let fixedCompositionPreset = exerciseMode.fixedCompositionPreset {
            return fixedCompositionPreset
        }

        guard isCompositionPresetSupported(preset, for: exerciseMode) else {
            switch exerciseMode {
            case .single, .sequence:
                return .staffToFretboard
            case .p2, .fr0, .sr0, .sr1, .sr2, .bcr1:
                return exerciseMode.fixedCompositionPreset ?? preset
            case .positionPrompt:
                return .fretboardToNaturalNoteStrip
            }
        }

        return preset
    }

    static func normalizedLayoutPreset(
        _ preset: ExerciseLayoutPreset,
        for compositionPreset: ExerciseCompositionPreset
    ) -> ExerciseLayoutPreset {
        guard !isLayoutPresetSupported(preset, for: compositionPreset) else {
            return preset
        }

        switch compositionPreset {
        case .staffToFretboard,
             .staffToPiano,
             .staffToNaturalNoteStrip,
             .targetPromptToFretboard,
             .fretboardToNaturalNoteStrip:
            return .stacked
        case .fretboardSelfAnswer:
            return .singleSurface
        }
    }

    static func isLayoutPresetSupported(
        _ preset: ExerciseLayoutPreset,
        for compositionPreset: ExerciseCompositionPreset
    ) -> Bool {
        switch compositionPreset {
        case .staffToFretboard,
             .staffToPiano,
             .staffToNaturalNoteStrip,
             .targetPromptToFretboard,
             .fretboardToNaturalNoteStrip:
            return isMultiSurfaceLayoutSupported(preset)
        case .fretboardSelfAnswer:
            return isSelfAnswerLayoutSupported(preset)
        }
    }

    static func isMultiSurfaceLayoutSupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        switch preset {
        case .stacked,
             .sideBySide,
             .threePane,
             .overlay,
             .collapsibleAccessory:
            return true
        case .singleSurface:
            return false
        }
    }

    static func isSelfAnswerLayoutSupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        switch preset {
        case .singleSurface,
             .threePane,
             .overlay,
             .collapsibleAccessory:
            return true
        case .stacked, .sideBySide:
            return false
        }
    }
}

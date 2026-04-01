//
//  ExerciseCompositionPolicy.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

struct ExerciseCompositionPolicyInput: Equatable, Sendable {
    var trainerDisplayState: TrainerDisplayState
    var fretboardTrainerState: FretboardNaturalNoteTrainerState
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pianoPanelState: PianoPanelState
    var layoutPreferences: ExerciseLayoutPreferences
}

enum ExerciseCompositionPolicy {
    static func makePresentation(
        from input: ExerciseCompositionPolicyInput
    ) -> ExercisePresentationState {
        let resolvedLayoutPreferences = ExerciseSceneValidator
            .normalizedPreferences(
                input.layoutPreferences,
                trainerDisplayState: input.trainerDisplayState
            )
        let scene = makeScene(
            preferences: resolvedLayoutPreferences
        )

        return ExercisePresentationState(
            scene: scene,
            surfaceStates: makeSurfaceStates(
                scene: scene,
                input: input,
                resolvedLayoutPreferences: resolvedLayoutPreferences
            ),
            resolvedLayoutPreferences: resolvedLayoutPreferences,
            legacyPageDisplayState: ExerciseSceneValidator
                .legacyPageDisplayState(for: scene)
        )
    }

    // 阶段 3 先让 shared policy 支持更多语义；
    // 但旧 renderer 仍只能吃 legacy page 可投影的组合，所以这里保留兼容降级入口给 adapter/控制器使用。
    static func makeLegacyCompatiblePresentation(
        from input: ExerciseCompositionPolicyInput
    ) -> ExercisePresentationState {
        var legacyCompatibleInput = input
        legacyCompatibleInput.layoutPreferences = legacyCompatiblePreferences(
            from: input
        )
        return makePresentation(from: legacyCompatibleInput)
    }

    static func legacyCompatiblePreferences(
        from input: ExerciseCompositionPolicyInput
    ) -> ExerciseLayoutPreferences {
        let resolvedPreferences = ExerciseSceneValidator.normalizedPreferences(
            input.layoutPreferences,
            trainerDisplayState: input.trainerDisplayState
        )
        var legacyCompatiblePreferences = resolvedPreferences

        legacyCompatiblePreferences.layoutPreset = .stacked
        legacyCompatiblePreferences.accessoryPresentation = .docked
        legacyCompatiblePreferences.isAccessoryExpanded = true

        switch input.trainerDisplayState.exerciseMode {
        case .single, .sequence:
            if legacyCompatiblePreferences.compositionPreset
                != .targetPromptToFretboard,
               legacyCompatiblePreferences.compositionPreset
                != .staffToFretboard {
                legacyCompatiblePreferences.compositionPreset = .staffToFretboard
            }
        case .positionPrompt:
            if legacyCompatiblePreferences.compositionPreset
                != .fretboardToNaturalNoteStrip {
                legacyCompatiblePreferences.compositionPreset = .fretboardToNaturalNoteStrip
            }
        }

        legacyCompatiblePreferences = ExerciseSceneValidator
            .normalizedPreferences(
                legacyCompatiblePreferences,
                trainerDisplayState: input.trainerDisplayState
            )

        let legacyScene = makeScene(
            preferences: legacyCompatiblePreferences
        )
        if ExerciseSceneValidator.legacyPageDisplayState(for: legacyScene) != nil {
            return legacyCompatiblePreferences
        }

        return fallbackLegacyCompatiblePreferences(
            for: input.trainerDisplayState.exerciseMode,
            isPianoAccessoryVisible: resolvedPreferences.isPianoAccessoryVisible
        )
    }

    static func makeScene(
        preferences: ExerciseLayoutPreferences
    ) -> ExerciseScene {
        let sceneSurfaces = resolvedSceneSurfaces(
            for: preferences
        )

        switch preferences.layoutPreset {
        case .stacked:
            return .stacked(
                top: sceneSurfaces.prompt,
                bottom: sceneSurfaces.answer
            )
        case .sideBySide:
            return .sideBySide(
                leading: sceneSurfaces.prompt,
                trailing: sceneSurfaces.answer
            )
        case .singleSurface:
            return .singleSurface(sceneSurfaces.prompt)
        case .threePane, .overlay, .collapsibleAccessory:
            // 当前调用方都会先走 normalizedPreferences；
            // 这里保底退回 stacked，避免高级节点在阶段 3 被误投影到未接线的 renderer。
            return .stacked(
                top: sceneSurfaces.prompt,
                bottom: sceneSurfaces.answer
            )
        }
    }

    private static func resolvedSceneSurfaces(
        for preferences: ExerciseLayoutPreferences
    ) -> (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode) {
        switch preferences.compositionPreset {
        case .staffToFretboard:
            return (.staffPrompt, .fretboardAnswer)
        case .targetPromptToFretboard:
            return (.targetPrompt, .fretboardAnswer)
        case .fretboardToNaturalNoteStrip:
            return (.fretboardPrompt, .naturalNoteStripAnswer)
        case .fretboardSelfAnswer:
            return (
                .fretboardPromptAndAnswer,
                .fretboardPromptAndAnswer
            )
        }
    }

    private static func makeSurfaceStates(
        scene: ExerciseScene,
        input: ExerciseCompositionPolicyInput,
        resolvedLayoutPreferences: ExerciseLayoutPreferences
    ) -> [ExerciseSurfaceID: ExerciseSurfaceState] {
        var surfaceStates = Dictionary(
            uniqueKeysWithValues: ExerciseSurfaceID.allCases.map {
                ($0, ExerciseSurfaceState.hidden)
            }
        )

        for surface in scene.surfaceNodes {
            surfaceStates[surface.id] = ExerciseSurfaceState(surface: surface)
        }

        if var naturalNoteStripState = surfaceStates[.naturalNoteStrip] {
            naturalNoteStripState.isVisible = resolvedLayoutPreferences
                .isNaturalNoteStripVisible
            naturalNoteStripState.isInteractionEnabled = naturalNoteStripState
                .isVisible
                && naturalNoteStripState.isAnswerEnabled
            surfaceStates[.naturalNoteStrip] = naturalNoteStripState
        }

        surfaceStates[.piano] = resolvedLayoutPreferences.isPianoAccessoryVisible
            || input.pianoPanelState.isVisible
            ? .auxiliaryOnly
            : .hidden

        return surfaceStates
    }

    private static func fallbackLegacyCompatiblePreferences(
        for exerciseMode: TrainerExerciseMode,
        isPianoAccessoryVisible: Bool
    ) -> ExerciseLayoutPreferences {
        switch exerciseMode {
        case .single, .sequence:
            return ExerciseLayoutPreferences(
                compositionPreset: .staffToFretboard,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: false,
                isPianoAccessoryVisible: isPianoAccessoryVisible,
                isAccessoryExpanded: true
            )
        case .positionPrompt:
            return ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: isPianoAccessoryVisible,
                isAccessoryExpanded: true
            )
        }
    }
}

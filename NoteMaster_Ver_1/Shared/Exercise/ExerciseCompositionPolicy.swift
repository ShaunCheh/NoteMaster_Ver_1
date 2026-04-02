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
        var resolvedLayoutPreferences = ExerciseSceneValidator
            .normalizedPreferences(
                input.layoutPreferences,
                trainerDisplayState: input.trainerDisplayState
            )
        resolvedLayoutPreferences.isPianoAccessoryVisible = resolvedLayoutPreferences
            .isPianoAccessoryVisible
            || input.pianoPanelState.isVisible
        let scene = makeScene(
            preferences: resolvedLayoutPreferences
        )

        return ExercisePresentationState(
            scene: scene,
            surfaceStates: makeSurfaceStates(scene: scene),
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
        legacyCompatiblePreferences.isNaturalNoteStripVisible = false
        legacyCompatiblePreferences.isPianoAccessoryVisible = false
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
        let mainSceneNode = makeMainSceneNode(
            from: sceneSurfaces,
            preferences: preferences
        )
        let accessoryScene = makeAccessorySceneNode(
            preferences: preferences
        )

        guard let accessoryScene else {
            return ExerciseScene(root: mainSceneNode)
        }

        return ExerciseScene(
            root: wrapMainSceneNode(
                mainSceneNode,
                accessorySceneNode: accessoryScene.node,
                accessoryMainAxisSizing: accessoryScene.mainAxisSizing,
                preferences: preferences
            )
        )
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
        scene: ExerciseScene
    ) -> [ExerciseSurfaceID: ExerciseSurfaceState] {
        var surfaceStates = Dictionary(
            uniqueKeysWithValues: ExerciseSurfaceID.allCases.map {
                ($0, ExerciseSurfaceState.hidden)
            }
        )

        let defaultPresentationState = ExercisePresentationState(scene: scene)
        for surfaceID in ExerciseSurfaceID.allCases {
            if let state = defaultPresentationState.surfaceState(
                for: surfaceID
            ) {
                surfaceStates[surfaceID] = state
            }
        }

        return surfaceStates
    }

    private static func makeMainSceneNode(
        from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
        preferences: ExerciseLayoutPreferences
    ) -> ExerciseSceneNode {
        switch resolvedMainLayoutPreset(for: preferences) {
        case .stacked:
            return .makeSplit(
                axis: .vertical,
                children: [
                    makeVerticalSceneChild(for: sceneSurfaces.prompt),
                    makeVerticalSceneChild(for: sceneSurfaces.answer)
                ]
            )
        case .sideBySide:
            return .makeSplit(
                axis: .horizontal,
                children: [
                    ExerciseSceneSplitChild(node: .surface(sceneSurfaces.prompt)),
                    ExerciseSceneSplitChild(node: .surface(sceneSurfaces.answer))
                ]
            )
        case .singleSurface:
            return .surface(sceneSurfaces.prompt)
        case .threePane, .overlay, .collapsibleAccessory:
            return .makeSplit(
                axis: .vertical,
                children: [
                    makeVerticalSceneChild(for: sceneSurfaces.prompt),
                    makeVerticalSceneChild(for: sceneSurfaces.answer)
                ]
            )
        }
    }

    private static func resolvedMainLayoutPreset(
        for preferences: ExerciseLayoutPreferences
    ) -> ExerciseLayoutPreset {
        switch preferences.layoutPreset {
        case .stacked, .sideBySide, .singleSurface:
            return preferences.layoutPreset
        case .threePane, .overlay, .collapsibleAccessory:
            return preferences.compositionPreset == .fretboardSelfAnswer
                ? .singleSurface
                : .stacked
        }
    }

    private static func makeAccessorySceneNode(
        preferences: ExerciseLayoutPreferences
    ) -> (node: ExerciseSceneNode, mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing)? {
        var accessoryChildren: [ExerciseSceneSplitChild] = []

        if preferences.isNaturalNoteStripVisible,
           preferences.compositionPreset != .fretboardToNaturalNoteStrip {
            accessoryChildren.append(
                makeVerticalSceneChild(
                    for: .naturalNoteStripAccessory,
                    weight: 0.7
                )
            )
        }

        if preferences.isPianoAccessoryVisible {
            accessoryChildren.append(
                makeVerticalSceneChild(
                    for: .pianoAccessory,
                    weight: 1.3
                )
            )
        }

        switch accessoryChildren.count {
        case 0:
            return nil
        case 1:
            return (
                node: accessoryChildren[0].node,
                mainAxisSizing: accessoryChildren[0].mainAxisSizing
            )
        default:
            let accessoryNode = ExerciseSceneNode.makeSplit(
                axis: .vertical,
                children: accessoryChildren
            )
            return (
                node: accessoryNode,
                mainAxisSizing: .weighted(
                    accessoryWeight(for: accessoryNode)
                )
            )
        }
    }

    private static func wrapMainSceneNode(
        _ mainSceneNode: ExerciseSceneNode,
        accessorySceneNode: ExerciseSceneNode,
        accessoryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing,
        preferences: ExerciseLayoutPreferences
    ) -> ExerciseSceneNode {
        switch resolvedAccessoryStrategy(for: preferences) {
        case .docked:
            return .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(
                        node: mainSceneNode,
                        mainAxisSizing: .weighted(3)
                    ),
                    ExerciseSceneSplitChild(
                        node: accessorySceneNode,
                        mainAxisSizing: accessoryMainAxisSizing
                    )
                ]
            )
        case .floating:
            return .makeOverlay(
                base: mainSceneNode,
                floating: [accessorySceneNode]
            )
        case .collapsible:
            return .makeCollapsible(
                main: mainSceneNode,
                accessory: accessorySceneNode,
                isExpanded: preferences.isAccessoryExpanded
            )
        }
    }

    private static func resolvedAccessoryStrategy(
        for preferences: ExerciseLayoutPreferences
    ) -> ExerciseAccessoryPresentation {
        switch preferences.layoutPreset {
        case .overlay:
            return .floating
        case .collapsibleAccessory:
            return .collapsible
        case .threePane:
            return .docked
        case .stacked, .sideBySide, .singleSurface:
            return preferences.accessoryPresentation
        }
    }

    private static func accessoryWeight(
        for accessorySceneNode: ExerciseSceneNode
    ) -> Double {
        let surfaceIDs = Set(accessorySceneNode.surfaceNodes.map(\.id))
        let showsNaturalStrip = surfaceIDs.contains(.naturalNoteStrip)
        let showsPiano = surfaceIDs.contains(.piano)

        switch (showsNaturalStrip, showsPiano) {
        case (true, true):
            return 1.6
        case (false, true):
            return 1.3
        case (true, false):
            return 0.7
        case (false, false):
            return 1
        }
    }

    private static func makeVerticalSceneChild(
        for surface: ExerciseSurfaceNode,
        weight: Double = 1
    ) -> ExerciseSceneSplitChild {
        ExerciseSceneSplitChild(
            node: .surface(surface),
            mainAxisSizing: surface.preferredVerticalMainAxisSizing(
                weight: weight
            )
        )
    }

    private static func fallbackLegacyCompatiblePreferences(
        for exerciseMode: TrainerExerciseMode,
        isPianoAccessoryVisible _: Bool
    ) -> ExerciseLayoutPreferences {
        switch exerciseMode {
        case .single, .sequence:
            return ExerciseLayoutPreferences(
                compositionPreset: .staffToFretboard,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: false,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        case .positionPrompt:
            return ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        }
    }
}

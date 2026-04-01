//
//  ExerciseSceneValidator.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

enum ExerciseSceneValidationIssue: Equatable, Sendable {
    case duplicateSurfaceID(ExerciseSurfaceID)
    case missingPromptSurface
    case missingAnswerSurface
}

enum ExerciseSceneValidator {
    static func validate(
        _ scene: ExerciseScene
    ) -> [ExerciseSceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [ExerciseSceneValidationIssue] = []

        for surfaceID in ExerciseSurfaceID.allCases {
            let duplicateCount = surfaceNodes.filter { $0.id == surfaceID }.count
            if duplicateCount > 1 {
                issues.append(.duplicateSurfaceID(surfaceID))
            }
        }

        if !surfaceNodes.contains(where: \.isPromptSurface) {
            issues.append(.missingPromptSurface)
        }
        if !surfaceNodes.contains(where: \.isAnswerSurface) {
            issues.append(.missingAnswerSurface)
        }

        return issues
    }

    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        var normalized = preferences

        switch trainerDisplayState.exerciseMode {
        case .single, .sequence:
            if !isCompositionPresetSemanticallySupported(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            ) {
                normalized.compositionPreset = .staffToFretboard
            }
        case .positionPrompt:
            if !isCompositionPresetSemanticallySupported(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            ) {
                normalized.compositionPreset = .fretboardToNaturalNoteStrip
            }
        }

        switch normalized.compositionPreset {
        case .staffToFretboard,
             .targetPromptToFretboard,
             .fretboardToNaturalNoteStrip:
            if !isMultiSurfaceLayoutSemanticallySupported(
                normalized.layoutPreset
            ) {
                normalized.layoutPreset = .stacked
            }
        case .fretboardSelfAnswer:
            normalized.layoutPreset = .singleSurface
        }

        if !isAccessoryPresentationSemanticallySupported(
            normalized.accessoryPresentation
        ) {
            normalized.accessoryPresentation = .docked
        }
        if normalized.accessoryPresentation != .collapsible {
            normalized.isAccessoryExpanded = true
        }

        normalized.isNaturalNoteStripVisible = normalized.compositionPreset
            == .fretboardToNaturalNoteStrip

        return normalized
    }

    static func normalizedLegacyPageDisplayState(
        from pageDisplayState: PageDisplayState,
        prioritizingTopContent: Bool
    ) -> PageDisplayState {
        var normalized = pageDisplayState

        let showsFretboardInTopContent = normalized.topContentMode == .fretboard
        let showsFretboardInMainContent = normalized.mainContentMode == .fretboard
        guard showsFretboardInTopContent && showsFretboardInMainContent else {
            return normalized
        }

        if prioritizingTopContent {
            normalized.mainContentMode = .naturalNoteStrip
        } else {
            normalized.topContentMode = .staff
        }

        return normalized
    }

    static func legacyPageDisplayState(
        for scene: ExerciseScene
    ) -> PageDisplayState? {
        guard case let .split(axis, children) = scene.root,
              axis == .vertical,
              children.count == 2,
              case let .surface(topSurface) = children[0].node,
              case let .surface(bottomSurface) = children[1].node else {
            return nil
        }

        switch (topSurface.id, bottomSurface.id) {
        case (.staff, .fretboard):
            guard topSurface.isPromptSurface,
                  bottomSurface.isAnswerSurface else {
                return nil
            }
            return .default
        case (.targetPrompt, .fretboard):
            guard topSurface.isPromptSurface,
                  bottomSurface.isAnswerSurface else {
                return nil
            }
            return PageDisplayState(
                topContentMode: .targetPrompt,
                mainContentMode: .fretboard
            )
        case (.fretboard, .naturalNoteStrip):
            guard topSurface.isPromptSurface,
                  bottomSurface.isAnswerSurface else {
                return nil
            }
            return .positionPrompt
        default:
            return nil
        }
    }

    static func isCompositionPresetSemanticallySupported(
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
            switch preset {
            case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
                return true
            case .staffToFretboard, .targetPromptToFretboard:
                return false
            }
        }
    }

    static func isMultiSurfaceLayoutSemanticallySupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        switch preset {
        case .stacked, .sideBySide:
            return true
        case .singleSurface,
             .threePane,
             .overlay,
             .collapsibleAccessory:
            return false
        }
    }

    static func isAccessoryPresentationSemanticallySupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        presentation == .docked
    }
}

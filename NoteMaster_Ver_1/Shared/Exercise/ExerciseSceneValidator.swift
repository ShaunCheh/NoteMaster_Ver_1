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
    case verticalRailRequiresHorizontalSplit(ExerciseSurfaceID)
}

enum ExerciseSceneValidator {
    static func validate(
        _ scene: ExerciseScene
    ) -> [ExerciseSceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [ExerciseSceneValidationIssue] = SceneValidator.validate(scene).map {
            mapSceneValidationIssue($0)
        }

        if !surfaceNodes.contains(where: { $0.isPromptSurface }) {
            issues.append(ExerciseSceneValidationIssue.missingPromptSurface)
        }
        if !surfaceNodes.contains(where: { $0.isAnswerSurface }) {
            issues.append(ExerciseSceneValidationIssue.missingAnswerSurface)
        }

        return issues
    }

    static func normalizedLegacyPageDisplayState(
        from pageDisplayState: PageDisplayState,
        prioritizingTopContent: Bool
    ) -> PageDisplayState {
        let normalizedContentModes = normalizedLegacyPageContentModes(
            topContentMode: pageDisplayState.topContentMode,
            mainContentMode: pageDisplayState.mainContentMode,
            prioritizingTopContent: prioritizingTopContent
        )
        var normalized = pageDisplayState
        normalized.topContentMode = normalizedContentModes.topContentMode
        normalized.mainContentMode = normalizedContentModes.mainContentMode
        return normalized
    }

    static func normalizedLegacyPageContentModes(
        topContentMode: PageTopContentMode,
        mainContentMode: PageMainContentMode,
        prioritizingTopContent: Bool
    ) -> (topContentMode: PageTopContentMode, mainContentMode: PageMainContentMode) {
        var normalizedTopContentMode = topContentMode
        var normalizedMainContentMode = mainContentMode

        let showsFretboardInTopContent = normalizedTopContentMode == .fretboard
        let showsFretboardInMainContent = normalizedMainContentMode == .fretboard
        guard showsFretboardInTopContent && showsFretboardInMainContent else {
            return (
                topContentMode: normalizedTopContentMode,
                mainContentMode: normalizedMainContentMode
            )
        }

        if prioritizingTopContent {
            normalizedMainContentMode = .naturalNoteStrip
        } else {
            normalizedTopContentMode = .staff
        }

        return (
            topContentMode: normalizedTopContentMode,
            mainContentMode: normalizedMainContentMode
        )
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

    private static func mapSceneValidationIssue(
        _ issue: SceneValidationIssue
    ) -> ExerciseSceneValidationIssue {
        switch issue {
        case let .duplicateSurfaceID(surfaceID):
            return .duplicateSurfaceID(surfaceID)
        case let .verticalRailRequiresHorizontalSplit(surfaceID):
            return .verticalRailRequiresHorizontalSplit(surfaceID)
        }
    }
}

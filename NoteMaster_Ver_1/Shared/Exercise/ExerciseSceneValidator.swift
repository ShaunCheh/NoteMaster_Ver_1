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

        issues.append(
            contentsOf: validatePresentationStyles(
                in: scene.root,
                withinHorizontalSplit: false
            )
        )

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

    private static func validatePresentationStyles(
        in node: ExerciseSceneNode,
        withinHorizontalSplit: Bool
    ) -> [ExerciseSceneValidationIssue] {
        switch node {
        case let .surface(surface):
            guard
                surface.presentationStyle == .verticalRail,
                !withinHorizontalSplit
            else {
                return []
            }
            return [.verticalRailRequiresHorizontalSplit(surface.id)]
        case let .split(axis, children):
            let nextWithinHorizontalSplit = withinHorizontalSplit
                || axis == .horizontal
            return children.flatMap {
                validatePresentationStyles(
                    in: $0.node,
                    withinHorizontalSplit: nextWithinHorizontalSplit
                )
            }
        case let .overlay(base, floating):
            return validatePresentationStyles(
                in: base,
                withinHorizontalSplit: withinHorizontalSplit
            ) + floating.flatMap {
                validatePresentationStyles(
                    in: $0,
                    withinHorizontalSplit: withinHorizontalSplit
                )
            }
        case let .collapsible(main, accessory, _):
            return validatePresentationStyles(
                in: main,
                withinHorizontalSplit: withinHorizontalSplit
            ) + validatePresentationStyles(
                in: accessory,
                withinHorizontalSplit: withinHorizontalSplit
            )
        }
    }
}

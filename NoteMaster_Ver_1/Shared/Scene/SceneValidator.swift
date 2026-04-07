//
//  SceneValidator.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

enum SceneValidationIssue: Equatable, Sendable {
    case duplicateSurfaceID(AppSurfaceID)
    case verticalRailRequiresHorizontalSplit(AppSurfaceID)
}

enum SceneValidator {
    static func validate<Surface: SceneSurfaceProtocol & Equatable & Sendable>(
        _ scene: Scene<Surface>
    ) -> [SceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [SceneValidationIssue] = []

        for surfaceID in AppSurfaceID.allCases {
            let duplicateCount = surfaceNodes.filter { $0.id == surfaceID }.count
            if duplicateCount > 1 {
                issues.append(.duplicateSurfaceID(surfaceID))
            }
        }

        issues.append(
            contentsOf: validatePresentationStyles(
                in: scene.root,
                withinHorizontalSplit: false
            )
        )

        return issues
    }

    private static func validatePresentationStyles<
        Surface: SceneSurfaceProtocol & Equatable & Sendable
    >(
        in node: SceneNode<Surface>,
        withinHorizontalSplit: Bool
    ) -> [SceneValidationIssue] {
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

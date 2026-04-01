//
//  SettingsNavigationModel.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/31.
//

import Foundation

enum SettingsRouteID: Equatable, Hashable, Sendable {
    case root
    case section(SettingsSectionID)
    case exerciseMode
    case exerciseComposition
    case exerciseLayout
    case positionPromptFilter
    case accessoryVisibility
    case accessoryPresentation
    case fretboardDisplay
    case fretboardViewport
    case trainerExercise
    case trainerPositionFilter
    case staffClef
    case staffLayout
    case pianoBehavior
    case pianoAppearance

    var fallbackTitle: String {
        switch self {
        case .root:
            return "Settings"
        case let .section(sectionID):
            return sectionID.title
        case .exerciseMode:
            return "Mode"
        case .exerciseComposition:
            return "Composition"
        case .exerciseLayout:
            return "Layout"
        case .positionPromptFilter:
            return "Filter"
        case .accessoryVisibility:
            return "Visibility"
        case .accessoryPresentation:
            return "Presentation"
        case .fretboardDisplay:
            return "Display"
        case .fretboardViewport:
            return "Vertical Viewport"
        case .trainerExercise:
            return "Exercise"
        case .trainerPositionFilter:
            return "Position Filter"
        case .staffClef:
            return "Clef"
        case .staffLayout:
            return "Layout"
        case .pianoBehavior:
            return "Behavior"
        case .pianoAppearance:
            return "Appearance"
        }
    }

    var accessibilityIdentifierComponent: String {
        switch self {
        case .root:
            return "root"
        case let .section(sectionID):
            return "section-\(String(describing: sectionID))"
        case .exerciseMode:
            return "exercise-mode"
        case .exerciseComposition:
            return "exercise-composition"
        case .exerciseLayout:
            return "exercise-layout"
        case .positionPromptFilter:
            return "position-prompt-filter"
        case .accessoryVisibility:
            return "accessory-visibility"
        case .accessoryPresentation:
            return "accessory-presentation"
        case .fretboardDisplay:
            return "fretboard-display"
        case .fretboardViewport:
            return "fretboard-viewport"
        case .trainerExercise:
            return "trainer-exercise"
        case .trainerPositionFilter:
            return "trainer-position-filter"
        case .staffClef:
            return "staff-clef"
        case .staffLayout:
            return "staff-layout"
        case .pianoBehavior:
            return "piano-behavior"
        case .pianoAppearance:
            return "piano-appearance"
        }
    }
}

struct SettingsRouteItem: Equatable, Hashable, Sendable {
    var title: String
    var subtitle: String?
    var route: SettingsRouteID
}

enum SettingsPageContent: Equatable, Sendable {
    case index([SettingsRouteItem])
    case form([SettingsSection])

    var routeItems: [SettingsRouteItem]? {
        guard case let .index(routeItems) = self else {
            return nil
        }

        return routeItems
    }

    var sections: [SettingsSection]? {
        guard case let .form(sections) = self else {
            return nil
        }

        return sections
    }
}

struct SettingsPageModel: Equatable, Sendable {
    var id: SettingsRouteID
    var title: String
    var content: SettingsPageContent

    var panelModel: SettingsPanelModel? {
        guard let sections = content.sections else {
            return nil
        }

        return SettingsPanelModel(sections: sections)
    }
}

struct SettingsNavigationPresentationState: Equatable, Sendable {
    var title: String
    var showsBackButton: Bool
}

struct SettingsNavigationModel: Equatable, Sendable {
    var rootRoute: SettingsRouteID
    var pages: [SettingsRouteID: SettingsPageModel]

    static let empty = SettingsNavigationModel(
        rootRoute: .root,
        pages: [
            .root: SettingsPageModel(
                id: .root,
                title: SettingsRouteID.root.fallbackTitle,
                content: .index([])
            )
        ]
    )

    var rootPage: SettingsPageModel? {
        page(for: rootRoute)
    }

    func page(for route: SettingsRouteID) -> SettingsPageModel? {
        pages[route]
    }

    // 路由栈规范化属于共享导航契约；
    // 当请求的深层 route 当前不存在时，统一退回到最近仍有效的父级，最后兜底 root。
    func reconciledPath(_ preferredPath: [SettingsRouteID]) -> [SettingsRouteID] {
        let candidatePath = normalizedCandidatePath(preferredPath)
        var reconciledPath: [SettingsRouteID] = [rootRoute]

        for route in candidatePath.dropFirst() {
            guard page(for: route) != nil else {
                break
            }

            if reconciledPath.last != route {
                reconciledPath.append(route)
            }
        }

        return reconciledPath
    }

    private func normalizedCandidatePath(
        _ preferredPath: [SettingsRouteID]
    ) -> [SettingsRouteID] {
        guard !preferredPath.isEmpty else {
            return [rootRoute]
        }

        var normalizedPath: [SettingsRouteID] = []

        for route in preferredPath {
            if normalizedPath.last != route {
                normalizedPath.append(route)
            }
        }

        if normalizedPath.first == rootRoute {
            return normalizedPath
        }

        return [rootRoute] + normalizedPath.filter { $0 != rootRoute }
    }
}

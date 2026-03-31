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
    case trainerPositionFilter
    case pianoAdvanced

    var fallbackTitle: String {
        switch self {
        case .root:
            return "Settings"
        case let .section(sectionID):
            return sectionID.title
        case .trainerPositionFilter:
            return "Position Filter"
        case .pianoAdvanced:
            return "Advanced"
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
}

//
//  SettingsNavigationAccessibility.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/31.
//

import Foundation

enum SettingsNavigationAccessibility {
    static let navigatorIdentifier = "settings-navigation"
    static let titleIdentifier = "settings-navigation-title"
    static let backButtonIdentifier = "settings-navigation-back-button"

    static func routeItemIdentifier(
        for route: SettingsRouteID
    ) -> String {
        "settings-navigation-route-\(route.accessibilityIdentifierComponent)"
    }

    static func pageIdentifier(
        for route: SettingsRouteID
    ) -> String {
        "settings-navigation-page-\(route.accessibilityIdentifierComponent)"
    }
}

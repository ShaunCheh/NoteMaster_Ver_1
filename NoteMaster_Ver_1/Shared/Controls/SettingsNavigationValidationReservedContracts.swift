//
//  SettingsNavigationValidationReservedContracts.swift
//  NoteMaster_Ver_1
//
//  Split from SettingsNavigationValidation for phase 6 — stable titles and accessibility identifiers.
//

import Foundation

@MainActor
extension SettingsNavigationValidationRunner {
    static func validateReservedRouteTitlesRemainStable()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "reserved_route_titles_remain_stable"
        var issues: [SettingsNavigationValidationIssue] = []

        if SettingsRouteID.root.fallbackTitle != "Settings" {
            issues.append(issue(fixtureName, "root fallbackTitle 应为 Settings。"))
        }
        if SettingsRouteID.section(.exercise).fallbackTitle != "Exercise" {
            issues.append(issue(fixtureName, "section(.exercise) fallbackTitle 应为 Exercise。"))
        }
        if SettingsRouteID.exerciseMode.fallbackTitle != "Mode" {
            issues.append(issue(fixtureName, "exerciseMode fallbackTitle 应为 Mode。"))
        }
        if SettingsRouteID.exerciseComposition.fallbackTitle != "Composition" {
            issues.append(
                issue(fixtureName, "exerciseComposition fallbackTitle 应为 Composition。")
            )
        }
        if SettingsRouteID.accessoryVisibility.fallbackTitle != "Visibility" {
            issues.append(issue(fixtureName, "accessoryVisibility fallbackTitle 应为 Visibility。"))
        }
        if SettingsRouteID.accessoryPresentation.fallbackTitle != "Presentation" {
            issues.append(
                issue(fixtureName, "accessoryPresentation fallbackTitle 应为 Presentation。")
            )
        }
        if SettingsRouteID.fretboardViewport.fallbackTitle != "Vertical Viewport" {
            issues.append(
                issue(fixtureName, "fretboardViewport fallbackTitle 应为 Vertical Viewport。")
            )
        }
        if SettingsRouteID.staffLayout.fallbackTitle != "Layout" {
            issues.append(issue(fixtureName, "staffLayout fallbackTitle 应为 Layout。"))
        }
        if SettingsRouteID.pianoBehavior.fallbackTitle != "Behavior" {
            issues.append(issue(fixtureName, "pianoBehavior fallbackTitle 应为 Behavior。"))
        }
        if SettingsRouteID.pianoAppearance.fallbackTitle != "Appearance" {
            issues.append(issue(fixtureName, "pianoAppearance fallbackTitle 应为 Appearance。"))
        }

        return issues
    }

    static func validateReservedAccessibilityIdentifiersRemainStable()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "reserved_accessibility_identifiers_remain_stable"
        var issues: [SettingsNavigationValidationIssue] = []

        if SettingsNavigationAccessibility.navigatorIdentifier != "settings-navigation" {
            issues.append(
                issue(fixtureName, "navigatorIdentifier 应为 settings-navigation。")
            )
        }
        if SettingsNavigationAccessibility.titleIdentifier != "settings-navigation-title" {
            issues.append(
                issue(fixtureName, "titleIdentifier 应为 settings-navigation-title。")
            )
        }
        if SettingsNavigationAccessibility.backButtonIdentifier != "settings-navigation-back-button" {
            issues.append(
                issue(fixtureName, "backButtonIdentifier 应为 settings-navigation-back-button。")
            )
        }
        if SettingsNavigationAccessibility.routeItemIdentifier(for: .accessoryPresentation)
            != "settings-navigation-route-accessory-presentation" {
            issues.append(
                issue(fixtureName, "accessoryPresentation route item identifier 应保持稳定。")
            )
        }
        if SettingsNavigationAccessibility.pageIdentifier(for: .section(.exercise))
            != "settings-navigation-page-section-exercise" {
            issues.append(
                issue(fixtureName, "section(.exercise) page identifier 应保持稳定。")
            )
        }

        return issues
    }
}

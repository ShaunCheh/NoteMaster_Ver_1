//
//  SettingsNavigationValidationSupport.swift
//  NoteMaster_Ver_1
//
//  Split from SettingsNavigationValidation for phase 6 — shared helpers.
//

import Foundation

@MainActor
extension SettingsNavigationValidationRunner {
    static func assertIndexPage(
        route: SettingsRouteID,
        expectedTitle: String,
        expectedRouteItems: [SettingsRouteItem],
        in navigationModel: SettingsNavigationModel,
        fixtureName: String,
        pageDescription: String,
        issues: inout [SettingsNavigationValidationIssue]
    ) {
        guard let page = navigationModel.page(for: route) else {
            issues.append(issue(fixtureName, "\(pageDescription) 缺少对应 page。"))
            return
        }

        if page.id != route {
            issues.append(issue(fixtureName, "\(pageDescription) page.id 未对齐 route。"))
        }
        if page.title != expectedTitle {
            issues.append(issue(fixtureName, "\(pageDescription) page.title 不符合预期。"))
        }

        guard let routeItems = page.content.routeItems else {
            issues.append(issue(fixtureName, "\(pageDescription) page.content 应为 index route items。"))
            return
        }

        if routeItems != expectedRouteItems {
            issues.append(issue(fixtureName, "\(pageDescription) 的 child route items 与预期不一致。"))
        }
    }

    static func assertFormPage(
        route: SettingsRouteID,
        expectedTitle: String,
        expectedSection: SettingsSection,
        in navigationModel: SettingsNavigationModel,
        fixtureName: String,
        pageDescription: String,
        issues: inout [SettingsNavigationValidationIssue]
    ) {
        guard let page = navigationModel.page(for: route) else {
            issues.append(issue(fixtureName, "\(pageDescription) 缺少对应 page。"))
            return
        }

        if page.id != route {
            issues.append(issue(fixtureName, "\(pageDescription) page.id 未对齐 route。"))
        }
        if page.title != expectedTitle {
            issues.append(issue(fixtureName, "\(pageDescription) page.title 不符合预期。"))
        }
        guard let sections = page.content.sections else {
            issues.append(issue(fixtureName, "\(pageDescription) page.content 应为 form sections。"))
            return
        }
        if sections != [expectedSection] {
            issues.append(issue(fixtureName, "\(pageDescription) 的 form section 投影与预期不一致。"))
        }
        if page.panelModel != SettingsPanelModel(sections: [expectedSection]) {
            issues.append(issue(fixtureName, "\(pageDescription) page.panelModel 应与预期单 section panel model 对齐。"))
        }
    }

    static func makeExpectedChildSection(
        title: String,
        from sourceSection: SettingsSection,
        keepingRowIDs: [SettingsRowID]
    ) -> SettingsSection {
        let allowedRowIDs = Set(keepingRowIDs)
        return SettingsSection(
            id: sourceSection.id,
            title: title,
            rows: sourceSection.rows.filter { allowedRowIDs.contains($0.id) }
        )
    }

    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> SettingsNavigationValidationIssue {
        SettingsNavigationValidationIssue(
            fixtureName: fixtureName,
            message: message
        )
    }

    static func resolveSection(
        _ sectionID: SettingsSectionID,
        in panelModel: SettingsPanelModel
    ) -> SettingsSection? {
        panelModel.sections.first(where: { $0.id == sectionID })
    }
}

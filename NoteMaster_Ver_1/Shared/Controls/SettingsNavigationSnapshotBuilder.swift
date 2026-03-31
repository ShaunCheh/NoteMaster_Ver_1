//
//  SettingsNavigationSnapshotBuilder.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/31.
//

import Foundation

enum SettingsNavigationSnapshotBuilder {
    static func makeModel(
        from stateContext: SettingsPanelStateContext
    ) -> SettingsNavigationModel {
        makeModel(
            from: SettingsPanelSnapshotBuilder.makeModel(
                from: stateContext
            )
        )
    }

    static func makeModel(
        from panelModel: SettingsPanelModel
    ) -> SettingsNavigationModel {
        var pages: [SettingsRouteID: SettingsPageModel] = [
            .root: SettingsPageModel(
                id: .root,
                title: SettingsRouteID.root.fallbackTitle,
                // root 页顺序必须与 panelModel.sections 一致，
                // 这样平台层无需再重复排序或推断分组。
                content: .index(
                    panelModel.sections.map(makeRootRouteItem(for:))
                )
            )
        ]

        for section in panelModel.sections {
            let route = SettingsRouteID.section(section.id)
            pages[route] = SettingsPageModel(
                id: route,
                title: section.title,
                content: .form([section])
            )
        }

        return SettingsNavigationModel(
            rootRoute: .root,
            pages: pages
        )
    }

    private static func makeRootRouteItem(
        for section: SettingsSection
    ) -> SettingsRouteItem {
        SettingsRouteItem(
            title: section.title,
            subtitle: nil,
            route: .section(section.id)
        )
    }
}

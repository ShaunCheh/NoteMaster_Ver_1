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
            pages.merge(
                makePages(for: section),
                uniquingKeysWith: { _, newValue in newValue }
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

    private static func makePages(
        for section: SettingsSection
    ) -> [SettingsRouteID: SettingsPageModel] {
        let route = SettingsRouteID.section(section.id)
        let childPages = makeResolvedChildPages(for: section)

        guard childPages.count > 1 else {
            return [
                route: SettingsPageModel(
                    id: route,
                    title: section.title,
                    content: .form([section])
                )
            ]
        }

        var pages: [SettingsRouteID: SettingsPageModel] = [
            route: SettingsPageModel(
                id: route,
                title: section.title,
                content: .index(
                    childPages.map { childPage in
                        SettingsRouteItem(
                            title: childPage.title,
                            subtitle: childPage.subtitle,
                            route: childPage.route
                        )
                    }
                )
            )
        ]

        for childPage in childPages {
            pages[childPage.route] = SettingsPageModel(
                id: childPage.route,
                title: childPage.title,
                content: .form([childPage.section])
            )
        }

        return pages
    }

    private static func makeResolvedChildPages(
        for section: SettingsSection
    ) -> [ResolvedChildPage] {
        guard let childPageSpecs = childPageSpecs(for: section.id) else {
            return []
        }

        let resolvedChildPages = childPageSpecs.compactMap { childPageSpec in
            resolveChildPage(
                childPageSpec,
                from: section
            )
        }

        let coveredRowIDs = Set(
            resolvedChildPages.flatMap { childPage in
                childPage.section.rows.map(\.id)
            }
        )
        let hasUncoveredRows = section.rows.contains { row in
            !coveredRowIDs.contains(row.id)
        }

        return hasUncoveredRows ? [] : resolvedChildPages
    }

    private static func resolveChildPage(
        _ childPageSpec: ChildPageSpec,
        from section: SettingsSection
    ) -> ResolvedChildPage? {
        let allowedRowIDs = Set(childPageSpec.rowIDs)
        let rows = section.rows.filter { allowedRowIDs.contains($0.id) }

        guard !rows.isEmpty else {
            return nil
        }

        return ResolvedChildPage(
            route: childPageSpec.route,
            title: childPageSpec.title,
            subtitle: childPageSpec.subtitle,
            section: SettingsSection(
                id: section.id,
                title: childPageSpec.title,
                rows: rows
            )
        )
    }

    private static func childPageSpecs(
        for sectionID: SettingsSectionID
    ) -> [ChildPageSpec]? {
        switch sectionID {
        case .mode:
            return nil
        case .exercise:
            return [
                ChildPageSpec(
                    route: .exerciseMode,
                    title: SettingsRouteID.exerciseMode.fallbackTitle,
                    subtitle: "Single, sequence, P-2, SR-0, SR-1, SR-2, or position",
                    rowIDs: [
                        .choice(.exerciseMode),
                        .positionFilter(.positionQuestionPitchClasses)
                    ]
                ),
                ChildPageSpec(
                    route: .exerciseComposition,
                    title: SettingsRouteID.exerciseComposition.fallbackTitle,
                    subtitle: "Prompt and answer pairing",
                    rowIDs: [
                        .choice(.compositionPreset)
                    ]
                ),
                ChildPageSpec(
                    route: .exerciseLayout,
                    title: SettingsRouteID.exerciseLayout.fallbackTitle,
                    subtitle: "Stacked, side, or single",
                    rowIDs: [
                        .choice(.layoutPreset)
                    ]
                )
            ]
        case .positionPrompt:
            return [
                ChildPageSpec(
                    route: .positionPromptFilter,
                    title: SettingsRouteID.positionPromptFilter.fallbackTitle,
                    subtitle: "Note names or frets",
                    rowIDs: [
                        .choice(.positionPromptFilterMode),
                        .positionFilter(.positionPromptFilterOptions)
                    ]
                )
            ]
        case .accessories:
            return [
                ChildPageSpec(
                    route: .accessoryVisibility,
                    title: SettingsRouteID.accessoryVisibility.fallbackTitle,
                    subtitle: "Natural strip and piano",
                    rowIDs: [
                        .toggle(.naturalStripVisible),
                        .toggle(.pianoAccessoryVisible)
                    ]
                ),
                ChildPageSpec(
                    route: .accessoryPresentation,
                    title: SettingsRouteID.accessoryPresentation.fallbackTitle,
                    subtitle: "Docked, floating, or collapsible",
                    rowIDs: [
                        .choice(.accessoryPresentation),
                        .toggle(.accessoryExpanded)
                    ]
                )
            ]
        case .fretboard:
            return [
                ChildPageSpec(
                    route: .fretboardDisplay,
                    title: SettingsRouteID.fretboardDisplay.fallbackTitle,
                    subtitle: "Instrument and labels",
                    rowIDs: [
                        .choice(.instrument),
                        .choice(.displayMode),
                        .choice(.stringThickness),
                        .choice(.labels),
                        .choice(.spelling),
                        .choice(.octave)
                    ]
                ),
                ChildPageSpec(
                    route: .fretboardViewport,
                    title: SettingsRouteID.fretboardViewport.fallbackTitle,
                    subtitle: "Vertical sizing",
                    rowIDs: [
                        .slider(.verticalHostHeightRatio)
                    ]
                )
            ]
        case .trainer:
            return [
                ChildPageSpec(
                    route: .trainerExercise,
                    title: SettingsRouteID.trainerExercise.fallbackTitle,
                    subtitle: "Mode",
                    rowIDs: [
                        .choice(.exerciseMode)
                    ]
                ),
                ChildPageSpec(
                    route: .trainerPositionFilter,
                    title: SettingsRouteID.trainerPositionFilter.fallbackTitle,
                    subtitle: "Note names or frets",
                    rowIDs: [
                        .choice(.positionPromptFilterMode),
                        .positionFilter(.positionPromptFilterOptions)
                    ]
                )
            ]
        case .staff:
            return [
                ChildPageSpec(
                    route: .staffClef,
                    title: SettingsRouteID.staffClef.fallbackTitle,
                    subtitle: "Type",
                    rowIDs: [
                        .choice(.clef)
                    ]
                ),
                ChildPageSpec(
                    route: .staffLayout,
                    title: SettingsRouteID.staffLayout.fallbackTitle,
                    subtitle: "Scale and trim",
                    rowIDs: [
                        .slider(.clefScale),
                        .slider(.clefVerticalTrim),
                        .slider(.clefAnchorYOffset)
                    ]
                )
            ]
        case .piano:
            return [
                ChildPageSpec(
                    route: .pianoBehavior,
                    title: SettingsRouteID.pianoBehavior.fallbackTitle,
                    subtitle: "Rows and movement",
                    rowIDs: [
                        .slider(.pianoRowCount),
                        .choice(.pianoMovementScope),
                        .toggle(.pianoSnapEnabled)
                    ]
                ),
                ChildPageSpec(
                    route: .pianoAppearance,
                    title: SettingsRouteID.pianoAppearance.fallbackTitle,
                    subtitle: "Key styling",
                    rowIDs: [
                        .choice(.pianoWhiteKeyStyle)
                    ]
                )
            ]
        case .layout, .debug:
            return nil
        }
    }
}

private struct ChildPageSpec {
    var route: SettingsRouteID
    var title: String
    var subtitle: String?
    var rowIDs: [SettingsRowID]
}

private struct ResolvedChildPage {
    var route: SettingsRouteID
    var title: String
    var subtitle: String?
    var section: SettingsSection
}

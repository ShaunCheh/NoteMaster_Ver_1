//
//  SettingsNavigationValidationRootTree.swift
//  NoteMaster_Ver_1
//
//  Split from SettingsNavigationValidation for phase 6 — root routes, page tree, play tree, root contracts.
//

import Foundation

@MainActor
extension SettingsNavigationValidationRunner {
    static func validateRootRouteItemsMatchPanelSections()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "root_route_items_match_panel_sections"
        let stateContext = SettingsPanelStateContext.default
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        guard let rootPage = navigationModel.rootPage else {
            issues.append(issue(fixtureName, "navigation model 缺少 rootPage。"))
            return issues
        }

        if rootPage.id != .root {
            issues.append(issue(fixtureName, "rootPage.id 应为 .root。"))
        }
        if rootPage.title != SettingsRouteID.root.fallbackTitle {
            issues.append(issue(fixtureName, "rootPage.title 应对齐 Settings。"))
        }

        guard let routeItems = rootPage.content.routeItems else {
            issues.append(issue(fixtureName, "rootPage.content 应为 index route items。"))
            return issues
        }

        let expectedRoutes = panelModel.sections.map { SettingsRouteID.section($0.id) }
        if routeItems.map(\.route) != expectedRoutes {
            issues.append(
                issue(fixtureName, "root route 顺序应与 panelModel.sections 顺序完全一致。")
            )
        }

        if routeItems.map(\.title) != panelModel.sections.map(\.title) {
            issues.append(
                issue(fixtureName, "root route 标题应与 section.title 一一对应。")
            )
        }

        if routeItems.contains(where: { $0.subtitle != nil }) {
            issues.append(
                issue(fixtureName, "阶段 1/2 的 root route item 不应预填 subtitle。")
            )
        }

        return issues
    }

    static func validateSplitSectionsProduceExpectedPageTree()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "split_sections_produce_expected_page_tree"
        let stateContext = SettingsPanelStateContext.default
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        guard let modeSection = resolveSection(.mode, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Mode section。"))
            return issues
        }
        guard let exerciseSection = resolveSection(.exercise, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Exercise section。"))
            return issues
        }
        guard let accessoriesSection = resolveSection(.accessories, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Accessories section。"))
            return issues
        }
        guard let fretboardSection = resolveSection(.fretboard, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Fretboard section。"))
            return issues
        }
        guard let staffSection = resolveSection(.staff, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Staff section。"))
            return issues
        }
        guard let pianoSection = resolveSection(.piano, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Piano section。"))
            return issues
        }
        guard let debugSection = resolveSection(.debug, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Debug section。"))
            return issues
        }

        if panelModel.sections.map(\.id) != expectedRootSectionIDs(for: .exercise) {
            issues.append(
                issue(
                    fixtureName,
                    "default state 的 section 顺序应保持 Mode -> Exercise -> Accessories -> Fretboard -> Staff -> Piano -> Debug。"
                )
            )
        }
        if resolveSection(.positionPrompt, in: panelModel) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "default state 不应再保留 Position Prompt section。"
                )
            )
        }
        if resolveSection(.layout, in: panelModel) != nil {
            issues.append(issue(fixtureName, "default state 不应再保留 Layout section。"))
        }
        if debugSection.rows.map(\.id) != [
            .toggle(.showsComponentBounds),
            .toggle(.showsSideBySideContainerOutlines)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Debug section rows 应保持 Component Bounds -> Side Container Borders。"
                )
            )
        }
        assertFormPage(
            route: .section(.mode),
            expectedTitle: modeSection.title,
            expectedSection: modeSection,
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Mode section",
            issues: &issues
        )
        if panelModel.toggleRow(for: .showsSideBySideContainerOutlines)?.isOn ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "default state 的 Side Container Borders 开关应默认关闭。"
                )
            )
        }
        var outlinedStateContext = stateContext
        SettingsToggleID.showsSideBySideContainerOutlines.apply(
            value: true,
            to: &outlinedStateContext
        )
        if !outlinedStateContext.debugState.showsSideBySideContainerOutlines {
            issues.append(
                issue(
                    fixtureName,
                    "Side Container Borders 开关写回后应把 debugState.showsSideBySideContainerOutlines 置为 true。"
                )
            )
        }
        let outlinedPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: outlinedStateContext
        )
        if !(outlinedPanelModel.toggleRow(
            for: .showsSideBySideContainerOutlines
        )?.isOn ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "Side Container Borders 开关写回后，settings snapshot 也应回显为 true。"
                )
            )
        }

        assertIndexPage(
            route: .section(.exercise),
            expectedTitle: exerciseSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.exerciseMode.fallbackTitle,
                    subtitle: "Single, sequence, SR-1, or position",
                    route: .exerciseMode
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.exerciseComposition.fallbackTitle,
                    subtitle: "Prompt and answer pairing",
                    route: .exerciseComposition
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.exerciseLayout.fallbackTitle,
                    subtitle: "Stacked, side, or single",
                    route: .exerciseLayout
                )
            ],
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Exercise section",
            issues: &issues
        )
        assertFormPage(
            route: .exerciseMode,
            expectedTitle: SettingsRouteID.exerciseMode.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.exerciseMode.fallbackTitle,
                from: exerciseSection,
                keepingRowIDs: [
                    .choice(.exerciseMode),
                    .positionFilter(.positionQuestionPitchClasses)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Exercise Mode",
            issues: &issues
        )
        assertFormPage(
            route: .exerciseComposition,
            expectedTitle: SettingsRouteID.exerciseComposition.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.exerciseComposition.fallbackTitle,
                from: exerciseSection,
                keepingRowIDs: [
                    .choice(.compositionPreset)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Exercise Composition",
            issues: &issues
        )
        assertFormPage(
            route: .exerciseLayout,
            expectedTitle: SettingsRouteID.exerciseLayout.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.exerciseLayout.fallbackTitle,
                from: exerciseSection,
                keepingRowIDs: [
                    .choice(.layoutPreset)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Exercise Layout",
            issues: &issues
        )

        if navigationModel.page(for: .section(.positionPrompt)) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "default state 不应继续生成 Position Prompt section page。"
                )
            )
        }

        assertIndexPage(
            route: .section(.accessories),
            expectedTitle: accessoriesSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.accessoryVisibility.fallbackTitle,
                    subtitle: "Natural strip and piano",
                    route: .accessoryVisibility
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.accessoryPresentation.fallbackTitle,
                    subtitle: "Docked, floating, or collapsible",
                    route: .accessoryPresentation
                )
            ],
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Accessories section",
            issues: &issues
        )
        assertFormPage(
            route: .accessoryVisibility,
            expectedTitle: SettingsRouteID.accessoryVisibility.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.accessoryVisibility.fallbackTitle,
                from: accessoriesSection,
                keepingRowIDs: [
                    .toggle(.naturalStripVisible),
                    .toggle(.pianoAccessoryVisible)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Accessory Visibility",
            issues: &issues
        )
        assertFormPage(
            route: .accessoryPresentation,
            expectedTitle: SettingsRouteID.accessoryPresentation.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.accessoryPresentation.fallbackTitle,
                from: accessoriesSection,
                keepingRowIDs: [
                    .choice(.accessoryPresentation),
                    .toggle(.accessoryExpanded)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Accessory Presentation",
            issues: &issues
        )

        assertFormPage(
            route: .section(.fretboard),
            expectedTitle: fretboardSection.title,
            expectedSection: fretboardSection,
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Fretboard section",
            issues: &issues
        )
        if navigationModel.page(for: .fretboardDisplay) != nil
            || navigationModel.page(for: .fretboardViewport) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "default side + vertical 场景下，Fretboard section 应收敛成单页 form，不再拆出 Display / Viewport 子页。"
                )
            )
        }

        assertIndexPage(
            route: .section(.staff),
            expectedTitle: staffSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.staffClef.fallbackTitle,
                    subtitle: "Type",
                    route: .staffClef
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.staffLayout.fallbackTitle,
                    subtitle: "Scale and trim",
                    route: .staffLayout
                )
            ],
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Staff section",
            issues: &issues
        )
        assertFormPage(
            route: .staffClef,
            expectedTitle: SettingsRouteID.staffClef.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.staffClef.fallbackTitle,
                from: staffSection,
                keepingRowIDs: [
                    .choice(.clef)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Staff Clef",
            issues: &issues
        )
        assertFormPage(
            route: .staffLayout,
            expectedTitle: SettingsRouteID.staffLayout.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.staffLayout.fallbackTitle,
                from: staffSection,
                keepingRowIDs: [
                    .slider(.clefScale),
                    .slider(.clefVerticalTrim),
                    .slider(.clefAnchorYOffset)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Staff Layout",
            issues: &issues
        )

        assertIndexPage(
            route: .section(.piano),
            expectedTitle: pianoSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.pianoBehavior.fallbackTitle,
                    subtitle: "Rows and movement",
                    route: .pianoBehavior
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.pianoAppearance.fallbackTitle,
                    subtitle: "Key styling",
                    route: .pianoAppearance
                )
            ],
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Piano section",
            issues: &issues
        )
        assertFormPage(
            route: .pianoBehavior,
            expectedTitle: SettingsRouteID.pianoBehavior.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.pianoBehavior.fallbackTitle,
                from: pianoSection,
                keepingRowIDs: [
                    .slider(.pianoRowCount),
                    .choice(.pianoMovementScope),
                    .toggle(.pianoSnapEnabled)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Piano Behavior",
            issues: &issues
        )
        assertFormPage(
            route: .pianoAppearance,
            expectedTitle: SettingsRouteID.pianoAppearance.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.pianoAppearance.fallbackTitle,
                from: pianoSection,
                keepingRowIDs: [
                    .choice(.pianoWhiteKeyStyle)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Piano Appearance",
            issues: &issues
        )

        assertFormPage(
            route: .section(.debug),
            expectedTitle: debugSection.title,
            expectedSection: debugSection,
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Debug section",
            issues: &issues
        )

        return issues
    }

    static func validatePlayRootTreeKeepsOnlyPianoPages()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "play_root_tree_keeps_only_piano_pages"
        let stateContext = SettingsPanelStateContext.playDefault
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        guard let modeSection = resolveSection(.mode, in: panelModel) else {
            issues.append(issue(fixtureName, "play mode 下应保留 Mode section。"))
            return issues
        }
        guard let pianoSection = resolveSection(.piano, in: panelModel) else {
            issues.append(issue(fixtureName, "play mode 下应保留 Piano section。"))
            return issues
        }

        if panelModel.sections.map(\.id) != expectedRootSectionIDs(for: .play) {
            issues.append(
                issue(
                    fixtureName,
                    "play mode 的 root sections 应只保留 Mode 与 Piano。"
                )
            )
        }

        if resolveSection(.exercise, in: panelModel) != nil
            || resolveSection(.accessories, in: panelModel) != nil
            || resolveSection(.fretboard, in: panelModel) != nil
            || resolveSection(.staff, in: panelModel) != nil
            || resolveSection(.debug, in: panelModel) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "play mode 不应继续暴露 exercise 专属 section。"
                )
            )
        }

        guard let rootPage = navigationModel.rootPage,
              let rootRouteItems = rootPage.content.routeItems else {
            issues.append(issue(fixtureName, "play mode navigation model 缺少 root route items。"))
            return issues
        }

        if rootRouteItems != expectedRootRouteItems(for: .play, in: panelModel) {
            issues.append(
                issue(
                    fixtureName,
                    "play mode root route 应只包含 Mode 与 Piano 入口。"
                )
            )
        }

        assertFormPage(
            route: .section(.mode),
            expectedTitle: modeSection.title,
            expectedSection: modeSection,
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Play Mode section",
            issues: &issues
        )

        assertIndexPage(
            route: .section(.piano),
            expectedTitle: pianoSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.pianoBehavior.fallbackTitle,
                    subtitle: "Rows and movement",
                    route: .pianoBehavior
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.pianoAppearance.fallbackTitle,
                    subtitle: "Key styling",
                    route: .pianoAppearance
                )
            ],
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Play Piano section",
            issues: &issues
        )
        assertFormPage(
            route: .pianoBehavior,
            expectedTitle: SettingsRouteID.pianoBehavior.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.pianoBehavior.fallbackTitle,
                from: pianoSection,
                keepingRowIDs: [
                    .slider(.pianoRowCount),
                    .choice(.pianoMovementScope),
                    .toggle(.pianoSnapEnabled)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Play Piano Behavior",
            issues: &issues
        )
        assertFormPage(
            route: .pianoAppearance,
            expectedTitle: SettingsRouteID.pianoAppearance.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.pianoAppearance.fallbackTitle,
                from: pianoSection,
                keepingRowIDs: [
                    .choice(.pianoWhiteKeyStyle)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Play Piano Appearance",
            issues: &issues
        )

        if navigationModel.page(for: .section(.exercise)) != nil
            || navigationModel.page(for: .section(.accessories)) != nil
            || navigationModel.page(for: .section(.fretboard)) != nil
            || navigationModel.page(for: .section(.staff)) != nil
            || navigationModel.page(for: .section(.debug)) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "play mode navigation tree 不应继续生成 exercise 专属 section page。"
                )
            )
        }

        return issues
    }

    static func expectedRootSectionIDs(
        for rootMode: RootMode
    ) -> [SettingsSectionID] {
        switch rootMode {
        case .exercise:
            return [
                .mode,
                .exercise,
                .accessories,
                .fretboard,
                .staff,
                .piano,
                .debug
            ]
        case .play:
            return [
                .mode,
                .piano
            ]
        }
    }

    static func expectedRootRouteItems(
        for rootMode: RootMode,
        in panelModel: SettingsPanelModel
    ) -> [SettingsRouteItem] {
        expectedRootSectionIDs(for: rootMode).compactMap { sectionID in
            guard let section = resolveSection(sectionID, in: panelModel) else {
                return nil
            }

            return SettingsRouteItem(
                title: section.title,
                subtitle: nil,
                route: .section(sectionID)
            )
        }
    }
}

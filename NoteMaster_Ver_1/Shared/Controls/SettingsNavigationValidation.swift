//
//  SettingsNavigationValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/31.
//

import Foundation

enum SettingsNavigationValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct SettingsNavigationValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct SettingsNavigationValidationReport {
    var platform: SettingsNavigationValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [SettingsNavigationValidationIssue]
    var manualChecklist: [String]

    var isPassing: Bool {
        issues.isEmpty
    }

    func debugSummary() -> String {
        let automatedStatus = isPassing ? "PASS" : "FAIL"
        let passedFixturesText = passedFixtureNames.isEmpty
            ? "无"
            : passedFixtureNames.joined(separator: ", ")
        let issuesText = issues.isEmpty
            ? "- 无"
            : issues.map { "- [\($0.fixtureName)] \($0.message)" }.joined(separator: "\n")
        let checklistText = manualChecklist.enumerated().map {
            "\($0.offset + 1). \($0.element)"
        }.joined(separator: "\n")

        return """
        [SettingsNavigationValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum SettingsNavigationValidationRunner {
    static func run(
        platform: SettingsNavigationValidationPlatform
    ) -> SettingsNavigationValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [SettingsNavigationValidationIssue] = []
        print(
            "[SettingsNavigationValidation][\(platform.displayName)] begin fixtures=\(fixtures.count)"
        )

        for fixture in fixtures {
            print(
                "[SettingsNavigationValidation][\(platform.displayName)] fixture begin name=\(fixture.name)"
            )
            let fixtureIssues = validate(fixture)
            print(
                "[SettingsNavigationValidation][\(platform.displayName)] fixture end name=\(fixture.name) issues=\(fixtureIssues.count)"
            )
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        print(
            "[SettingsNavigationValidation][\(platform.displayName)] end totalIssues=\(issues.count)"
        )

        return SettingsNavigationValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: SettingsNavigationValidationPlatform) {
        #if DEBUG
        print(
            "[SettingsNavigationValidation][\(platform.displayName)] runAndReportIfNeeded begin"
        )
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)
        print(
            "[SettingsNavigationValidation][\(platform.displayName)] runAndReportIfNeeded end passing=\(report.isPassing)"
        )

        if !report.isPassing {
            assertionFailure(summary)
        }
        #endif
    }
}

private struct SettingsNavigationValidationFixture {
    var name: String
    var validate: () -> [SettingsNavigationValidationIssue]
}

private extension SettingsNavigationValidationRunner {
    static func validate(
        _ fixture: SettingsNavigationValidationFixture
    ) -> [SettingsNavigationValidationIssue] {
        fixture.validate()
    }

    static func makeFixtures() -> [SettingsNavigationValidationFixture] {
        [
            SettingsNavigationValidationFixture(
                name: "root_route_items_match_panel_sections",
                validate: validateRootRouteItemsMatchPanelSections
            ),
            SettingsNavigationValidationFixture(
                name: "split_sections_produce_expected_page_tree",
                validate: validateSplitSectionsProduceExpectedPageTree
            ),
            SettingsNavigationValidationFixture(
                name: "trainer_route_visibility_tracks_exercise_mode",
                validate: validateTrainerRouteVisibilityTracksExerciseMode
            ),
            SettingsNavigationValidationFixture(
                name: "layout_route_visibility_tracks_display_mode",
                validate: validateLayoutRouteVisibilityTracksDisplayMode
            ),
            SettingsNavigationValidationFixture(
                name: "fretboard_string_thickness_option_tracks_state",
                validate: validateFretboardStringThicknessOptionTracksState
            ),
            SettingsNavigationValidationFixture(
                name: "legacy_page_rows_and_piano_visibility_state_remain_stable",
                validate: validateLegacyPageRowsAndPianoVisibilityStateRemainStable
            ),
            SettingsNavigationValidationFixture(
                name: "reconciled_path_falls_back_to_existing_parent",
                validate: validateReconciledPathFallsBackToExistingParent
            ),
            SettingsNavigationValidationFixture(
                name: "reserved_route_titles_remain_stable",
                validate: validateReservedRouteTitlesRemainStable
            ),
            SettingsNavigationValidationFixture(
                name: "reserved_accessibility_identifiers_remain_stable",
                validate: validateReservedAccessibilityIdentifiersRemainStable
            )
        ]
    }

    static func manualChecklist(
        for platform: SettingsNavigationValidationPlatform
    ) -> [String] {
        [
            "在 \(platform.displayName) 上确认 close 永远关闭整个 settings card，而不是只关闭当前子页。",
            "确认在 root 页隐藏返回按钮；进入 section 或更深页面后显示返回按钮，点击后只回退卡片内一层。",
            "确认 root -> Trainer / Staff / Piano 的 section page 可以继续进入深层子页，标题与内容和共享 builder 生成的 route 一致。",
            "确认当停留在 Trainer Position Filter 深层页时切换 exercise mode，卡片会自动退回最近仍有效的 Trainer 父页，而不会停留在失效子页。",
            "确认切换到 horizontal 指板布局时 Layout route 会消失；切回 vertical 后 Layout route 会恢复。",
            "确认阶段 0 期间 `Page` 分区仍保留 `Top Content / Main Content` 两行，`Piano > Behavior` 仍保留 `Visible` 开关。后续阶段替换前，这些旧入口不应先漂移。",
            "确认 iOS / macOS 上的标题、返回、关闭按钮布局与转场方向一致，没有双层导航条或页面闪跳。"
        ]
    }

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

        guard let trainerSection = resolveSection(.trainer, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Trainer section。"))
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
        guard let pageSection = resolveSection(.page, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Page section。"))
            return issues
        }
        guard let fretboardSection = resolveSection(.fretboard, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Fretboard section。"))
            return issues
        }
        guard let layoutSection = resolveSection(.layout, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Layout section。"))
            return issues
        }
        guard let debugSection = resolveSection(.debug, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Debug section。"))
            return issues
        }

        assertFormPage(
            route: .section(.page),
            expectedTitle: pageSection.title,
            expectedSection: pageSection,
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Page section",
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
        assertFormPage(
            route: .section(.layout),
            expectedTitle: layoutSection.title,
            expectedSection: layoutSection,
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Layout section",
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

        assertIndexPage(
            route: .section(.trainer),
            expectedTitle: trainerSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.trainerExercise.fallbackTitle,
                    subtitle: "Mode",
                    route: .trainerExercise
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.trainerPositionFilter.fallbackTitle,
                    subtitle: "Note names or frets",
                    route: .trainerPositionFilter
                )
            ],
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Trainer section",
            issues: &issues
        )
        assertFormPage(
            route: .trainerExercise,
            expectedTitle: SettingsRouteID.trainerExercise.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.trainerExercise.fallbackTitle,
                from: trainerSection,
                keepingRowIDs: [
                    .choice(.exerciseMode)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Trainer Exercise",
            issues: &issues
        )
        assertFormPage(
            route: .trainerPositionFilter,
            expectedTitle: SettingsRouteID.trainerPositionFilter.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.trainerPositionFilter.fallbackTitle,
                from: trainerSection,
                keepingRowIDs: [
                    .choice(.positionPromptFilterMode),
                    .positionFilter(.positionPromptFilterOptions)
                ]
            ),
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Trainer Position Filter",
            issues: &issues
        )

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
                    subtitle: "Visibility and movement",
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
                    .toggle(.pianoVisible),
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

        return issues
    }

    static func validateTrainerRouteVisibilityTracksExerciseMode()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "trainer_route_visibility_tracks_exercise_mode"
        var issues: [SettingsNavigationValidationIssue] = []

        let singleTrainerState = TrainerDisplayState(exerciseMode: .single)
        let singleStateContext = SettingsPanelStateContext(
            trainerDisplayState: singleTrainerState
        )
        let singlePanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: singleStateContext
        )
        let singleNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: singleStateContext
        )

        guard let singleTrainerSection = resolveSection(.trainer, in: singlePanelModel) else {
            issues.append(issue(fixtureName, "single 模式下应保留 Trainer section。"))
            return issues
        }

        assertFormPage(
            route: .section(.trainer),
            expectedTitle: singleTrainerSection.title,
            expectedSection: singleTrainerSection,
            in: singleNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Trainer single-mode section",
            issues: &issues
        )
        if singleNavigationModel.page(for: .trainerExercise) != nil {
            issues.append(
                issue(fixtureName, "只有一个 Trainer 子分组时，不应继续暴露 trainerExercise 深层页。")
            )
        }
        if singleNavigationModel.page(for: .trainerPositionFilter) != nil {
            issues.append(
                issue(fixtureName, "single 模式下不应暴露 trainerPositionFilter 深层页。")
            )
        }

        let positionPromptStateContext = SettingsPanelStateContext(
            pageDisplayState: .positionPrompt,
            trainerDisplayState: .default
        )
        let positionPromptNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: positionPromptStateContext
        )

        guard let trainerPage = positionPromptNavigationModel.page(for: .section(.trainer)) else {
            issues.append(issue(fixtureName, "position prompt 模式下缺少 Trainer section page。"))
            return issues
        }

        guard let trainerRouteItems = trainerPage.content.routeItems else {
            issues.append(issue(fixtureName, "position prompt 模式下 Trainer section 应变为 index page。"))
            return issues
        }
        if trainerRouteItems.map(\.route) != [
            .trainerExercise,
            .trainerPositionFilter
        ] {
            issues.append(
                issue(fixtureName, "position prompt 模式下 Trainer index route 顺序应为 Exercise -> Position Filter。")
            )
        }
        if positionPromptNavigationModel.page(for: .trainerPositionFilter) == nil {
            issues.append(issue(fixtureName, "position prompt 模式下应生成 trainerPositionFilter 深层页。"))
        }

        return issues
    }

    static func validateLayoutRouteVisibilityTracksDisplayMode()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "layout_route_visibility_tracks_display_mode"
        var issues: [SettingsNavigationValidationIssue] = []

        let verticalStateContext = SettingsPanelStateContext.default
        let verticalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: verticalStateContext
        )
        let verticalRootRoutes = verticalNavigationModel.rootPage?.content.routeItems?.map(\.route) ?? []
        if !verticalRootRoutes.contains(.section(.layout)) {
            issues.append(
                issue(fixtureName, "vertical 指板模式下 root route 应包含 Layout。")
            )
        }
        if verticalNavigationModel.page(for: .section(.layout)) == nil {
            issues.append(
                issue(fixtureName, "vertical 指板模式下应生成 Layout detail page。")
            )
        }

        var horizontalFretboardDisplayState = FretboardDisplayState.default
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalStateContext = SettingsPanelStateContext(
            fretboardDisplayState: horizontalFretboardDisplayState
        )
        let horizontalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: horizontalStateContext
        )
        let horizontalRootRoutes = horizontalNavigationModel.rootPage?.content.routeItems?.map(\.route) ?? []
        if horizontalRootRoutes.contains(.section(.layout)) {
            issues.append(
                issue(fixtureName, "horizontal 指板模式下 root route 不应继续暴露 Layout。")
            )
        }
        if horizontalNavigationModel.page(for: .section(.layout)) != nil {
            issues.append(
                issue(fixtureName, "horizontal 指板模式下不应继续生成 Layout detail page。")
            )
        }

        return issues
    }

    static func validateFretboardStringThicknessOptionTracksState()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "fretboard_string_thickness_option_tracks_state"
        var issues: [SettingsNavigationValidationIssue] = []

        let defaultStateContext = SettingsPanelStateContext.default
        let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(from: defaultStateContext)

        guard let defaultRow = defaultPanelModel.choiceRow(for: .stringThickness) else {
            issues.append(issue(fixtureName, "default state 应暴露 String Thickness 选项。"))
            return issues
        }

        if defaultRow.selectionStyle != .singleSelection {
            issues.append(issue(fixtureName, "String Thickness 应为 singleSelection。"))
        }
        if defaultRow.presentationStyle != .segmented {
            issues.append(issue(fixtureName, "String Thickness 应使用 segmented 呈现。"))
        }
        if defaultRow.choices.map(\.id) != [
            .setStringThicknessUniform,
            .setStringThicknessGraduated
        ] {
            issues.append(
                issue(fixtureName, "String Thickness 选项顺序应为 Uniform -> Graduated。")
            )
        }
        if defaultRow.choices.filter(\.isSelected).map(\.id) != [.setStringThicknessUniform] {
            issues.append(issue(fixtureName, "default state 应默认选中 Uniform。"))
        }

        var graduatedStateContext = defaultStateContext
        SettingsActionID.setStringThicknessGraduated.apply(to: &graduatedStateContext)
        if graduatedStateContext.fretboardDisplayState.configuration.stringThicknessStyle != .graduated {
            issues.append(issue(fixtureName, "Graduated action 应写回 fretboardDisplayState。"))
        }

        let graduatedPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: graduatedStateContext
        )
        guard let graduatedRow = graduatedPanelModel.choiceRow(for: .stringThickness) else {
            issues.append(issue(fixtureName, "Graduated state 仍应保留 String Thickness 选项。"))
            return issues
        }

        if graduatedRow.choices.filter(\.isSelected).map(\.id) != [.setStringThicknessGraduated] {
            issues.append(issue(fixtureName, "Graduated state 应只选中 Graduated。"))
        }

        return issues
    }

    static func validateLegacyPageRowsAndPianoVisibilityStateRemainStable()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "legacy_page_rows_and_piano_visibility_state_remain_stable"
        let defaultStateContext = SettingsPanelStateContext.default
        let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: defaultStateContext
        )
        let defaultNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: defaultStateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        guard let pageSection = resolveSection(.page, in: defaultPanelModel) else {
            issues.append(
                issue(fixtureName, "default state 应继续保留 Page section。")
            )
            return issues
        }

        if pageSection.rows.map(\.id) != [
            .choice(.topContent),
            .choice(.mainContent)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Page section row 顺序应继续保持 Top Content -> Main Content。"
                )
            )
        }

        guard let topContentRow = defaultPanelModel.choiceRow(for: .topContent) else {
            issues.append(issue(fixtureName, "default state 应继续暴露 Top Content row。"))
            return issues
        }

        if topContentRow.choices.map(\.id) != [
            .setTopContentStaff,
            .setTopContentTargetPrompt,
            .setTopContentFretboard
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Top Content row 选项顺序应继续保持 Staff -> Target -> Fretboard。"
                )
            )
        }
        if topContentRow.choices.filter(\.isSelected).map(\.id) != [
            .setTopContentStaff
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Top Content row 默认应继续选中 Staff。"
                )
            )
        }
        let fretboardTopChoiceIsEnabled = topContentRow.choices.first(
            where: { $0.id == .setTopContentFretboard }
        )?.isEnabled ?? true
        if fretboardTopChoiceIsEnabled {
            issues.append(
                issue(
                    fixtureName,
                    "Top Content row 中的 Fretboard 选项在 legacy model 下应继续保持禁用。"
                )
            )
        }

        guard let mainContentRow = defaultPanelModel.choiceRow(for: .mainContent) else {
            issues.append(issue(fixtureName, "default state 应继续暴露 Main Content row。"))
            return issues
        }

        if mainContentRow.choices.map(\.id) != [
            .setMainContentFretboard,
            .setMainContentNaturalNotes
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Main Content row 选项顺序应继续保持 Fretboard -> Natural Notes。"
                )
            )
        }
        if mainContentRow.choices.filter(\.isSelected).map(\.id) != [
            .setMainContentFretboard
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Main Content row 默认应继续选中 Fretboard。"
                )
            )
        }

        guard let pianoBehaviorPage = defaultNavigationModel.page(for: .pianoBehavior),
              let pianoBehaviorSections = pianoBehaviorPage.content.sections,
              let pianoBehaviorSection = pianoBehaviorSections.first else {
            issues.append(
                issue(fixtureName, "default state 应继续生成 Piano Behavior page。")
            )
            return issues
        }

        if pianoBehaviorSection.rows.map(\.id) != [
            .toggle(.pianoVisible),
            .slider(.pianoRowCount),
            .choice(.pianoMovementScope),
            .toggle(.pianoSnapEnabled)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Behavior page rows 应继续保持 Visible / Rows / Row Linking / Snap Drag。"
                )
            )
        }

        let defaultPianoVisibleValue = defaultPanelModel.toggleRow(
            for: .pianoVisible
        )?.isOn ?? true
        if defaultPianoVisibleValue {
            issues.append(
                issue(
                    fixtureName,
                    "default state 的 Piano Visible 开关应继续默认关闭。"
                )
            )
        }

        var visibleStateContext = defaultStateContext
        SettingsToggleID.pianoVisible.apply(value: true, to: &visibleStateContext)
        if !visibleStateContext.pianoPanelState.isVisible {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Visible 开关写回后应继续把 pianoPanelState.isVisible 置为 true。"
                )
            )
        }

        let visiblePanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: visibleStateContext
        )
        let visiblePianoVisibleValue = visiblePanelModel.toggleRow(
            for: .pianoVisible
        )?.isOn ?? false
        if !visiblePianoVisibleValue {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Visible 开关写回后，settings snapshot 也应继续回显为 true。"
                )
            )
        }

        let visibleNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: visibleStateContext
        )
        guard let visiblePianoBehaviorPage = visibleNavigationModel.page(for: .pianoBehavior),
              let visiblePianoBehaviorSection = visiblePianoBehaviorPage.content.sections?.first else {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Visible 打开后仍应继续保留 Piano Behavior page。"
                )
            )
            return issues
        }

        if !visiblePianoBehaviorSection.rows.map(\.id).contains(.toggle(.pianoVisible)) {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Visible 打开后不应移除 Visible toggle 本身。"
                )
            )
        }

        return issues
    }

    static func validateReconciledPathFallsBackToExistingParent()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "reconciled_path_falls_back_to_existing_parent"
        var issues: [SettingsNavigationValidationIssue] = []

        let startupStateContext = SettingsPanelStateContext(
            pageDisplayState: .positionPrompt,
            trainerDisplayState: .default
        )
        let startupNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: startupStateContext
        )
        let availableTrainerPath = startupNavigationModel.reconciledPath([
            .root,
            .section(.trainer),
            .trainerPositionFilter
        ])
        if availableTrainerPath != [.root, .section(.trainer), .trainerPositionFilter] {
            issues.append(
                issue(fixtureName, "已存在的 Trainer 深层 route 不应被错误回退。")
            )
        }

        let singleTrainerNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
            )
        )
        let singleTrainerFallbackPath = singleTrainerNavigationModel.reconciledPath([
            .root,
            .section(.trainer),
            .trainerPositionFilter
        ])
        if singleTrainerFallbackPath != [.root, .section(.trainer)] {
            issues.append(
                issue(fixtureName, "缺失的 Trainer 深层 route 应回退到最近仍有效的 Trainer 父级。")
            )
        }

        var horizontalFretboardDisplayState = FretboardDisplayState.default
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                fretboardDisplayState: horizontalFretboardDisplayState
            )
        )
        let layoutFallbackPath = horizontalNavigationModel.reconciledPath([
            .section(.layout)
        ])
        if layoutFallbackPath != [.root] {
            issues.append(
                issue(fixtureName, "当首个 detail route 不存在时，应直接回退到 root。")
            )
        }

        let duplicateRootPath = startupNavigationModel.reconciledPath([
            .root,
            .root,
            .section(.trainer)
        ])
        if duplicateRootPath != [.root, .section(.trainer)] {
            issues.append(
                issue(fixtureName, "reconciledPath 应去除重复 route，并保持 root 在首位。")
            )
        }

        return issues
    }

    static func validateReservedRouteTitlesRemainStable()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "reserved_route_titles_remain_stable"
        var issues: [SettingsNavigationValidationIssue] = []

        if SettingsRouteID.root.fallbackTitle != "Settings" {
            issues.append(issue(fixtureName, "root fallbackTitle 应为 Settings。"))
        }
        if SettingsRouteID.section(.trainer).fallbackTitle != "Trainer" {
            issues.append(issue(fixtureName, "section(.trainer) fallbackTitle 应为 Trainer。"))
        }
        if SettingsRouteID.trainerExercise.fallbackTitle != "Exercise" {
            issues.append(issue(fixtureName, "trainerExercise fallbackTitle 应为 Exercise。"))
        }
        if SettingsRouteID.trainerPositionFilter.fallbackTitle != "Position Filter" {
            issues.append(
                issue(fixtureName, "trainerPositionFilter fallbackTitle 应为 Position Filter。")
            )
        }
        if SettingsRouteID.staffClef.fallbackTitle != "Clef" {
            issues.append(issue(fixtureName, "staffClef fallbackTitle 应为 Clef。"))
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
        if SettingsNavigationAccessibility.routeItemIdentifier(for: .trainerPositionFilter)
            != "settings-navigation-route-trainer-position-filter" {
            issues.append(
                issue(fixtureName, "trainerPositionFilter route item identifier 应保持稳定。")
            )
        }
        if SettingsNavigationAccessibility.pageIdentifier(for: .section(.trainer))
            != "settings-navigation-page-section-trainer" {
            issues.append(
                issue(fixtureName, "section(.trainer) page identifier 应保持稳定。")
            )
        }

        return issues
    }

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

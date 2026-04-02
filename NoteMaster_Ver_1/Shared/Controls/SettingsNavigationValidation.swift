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
                name: "position_prompt_section_visibility_tracks_exercise_mode",
                validate: validatePositionPromptSectionVisibilityTracksExerciseMode
            ),
            SettingsNavigationValidationFixture(
                name: "fretboard_viewport_route_visibility_tracks_display_mode",
                validate: validateFretboardViewportRouteVisibilityTracksDisplayMode
            ),
            SettingsNavigationValidationFixture(
                name: "fretboard_string_thickness_option_tracks_state",
                validate: validateFretboardStringThicknessOptionTracksState
            ),
            SettingsNavigationValidationFixture(
                name: "exercise_and_accessory_rows_match_stage7_capabilities",
                validate: validateExerciseAndAccessoryRowsMatchStage7Capabilities
            ),
            SettingsNavigationValidationFixture(
                name: "reconciled_path_falls_back_to_existing_parent",
                validate: validateReconciledPathFallsBackToExistingParent
            ),
            SettingsNavigationValidationFixture(
                name: "exercise_layout_route_remains_stable_across_choice_updates",
                validate: validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates
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
            "确认 root -> Exercise / Accessories / Staff / Piano 的 section page 可以继续进入深层子页，标题与内容和共享 builder 生成的 route 一致。",
            "确认切换到 `single` / `sequence` 时 `Position Prompt` section 会消失；切回 `positionPrompt` 后会恢复。",
            "确认切换到 horizontal 指板布局，或在 side 布局下保持 vertical 指板时 `Fretboard > Vertical Viewport` 深层页会消失；切回 stacked + vertical 后会恢复。",
            "确认 `Exercise` 分区只显示 `Exercise Mode / Composition Preset / Layout Preset`，不再出现 `Top Content / Main Content`。",
            "确认 `Accessories` 分区包含 `Natural Strip Visible / Piano Accessory Visible / Accessory Presentation / Accessory Expanded`，`Piano > Behavior` 不再负责可见性开关。",
            "确认 `single/sequence` 下可以打开 `Natural Strip Visible`，而 `positionPrompt` 主 answer strip 场景里该 toggle 会自动禁用。",
            "确认 `Accessory Presentation` 里的 `Docked / Floating / Collapsible` 都可进入且可选；只有切到 `Collapsible` 后才启用 `Accessory Expanded`。",
            "停留在 `Exercise > Layout` 子页时直接切换 `Stacked / Side / Single`，确认当前页不会闪跳、不会被重建回上一层，且选中态立即更新。",
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

        guard let exerciseSection = resolveSection(.exercise, in: panelModel) else {
            issues.append(issue(fixtureName, "default state 应保留 Exercise section。"))
            return issues
        }
        guard let positionPromptSection = resolveSection(.positionPrompt, in: panelModel) else {
            issues.append(issue(fixtureName, "positionPrompt 默认态应保留 Position Prompt section。"))
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

        if panelModel.sections.map(\.id) != [
            .exercise,
            .positionPrompt,
            .accessories,
            .fretboard,
            .staff,
            .piano,
            .debug
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "default state 的 section 顺序应保持 Exercise -> Position Prompt -> Accessories -> Fretboard -> Staff -> Piano -> Debug。"
                )
            )
        }
        if resolveSection(.layout, in: panelModel) != nil {
            issues.append(issue(fixtureName, "default state 不应再保留 Layout section。"))
        }

        assertIndexPage(
            route: .section(.exercise),
            expectedTitle: exerciseSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.exerciseMode.fallbackTitle,
                    subtitle: "Single, sequence, or position",
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
                    .choice(.exerciseMode)
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

        assertFormPage(
            route: .section(.positionPrompt),
            expectedTitle: positionPromptSection.title,
            expectedSection: positionPromptSection,
            in: navigationModel,
            fixtureName: fixtureName,
            pageDescription: "Position Prompt section",
            issues: &issues
        )

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

    static func validatePositionPromptSectionVisibilityTracksExerciseMode()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "position_prompt_section_visibility_tracks_exercise_mode"
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

        if resolveSection(.positionPrompt, in: singlePanelModel) != nil {
            issues.append(
                issue(fixtureName, "single 模式下不应继续暴露 Position Prompt section。")
            )
        }
        if singleNavigationModel.page(for: .section(.positionPrompt)) != nil {
            issues.append(
                issue(fixtureName, "single 模式下不应继续生成 Position Prompt section page。")
            )
        }

        let positionPromptStateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: .legacyPositionPrompt,
            trainerDisplayState: .default
        )
        let positionPromptNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: positionPromptStateContext
        )

        let positionPromptPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: positionPromptStateContext
        )

        guard let positionPromptSection = resolveSection(
            .positionPrompt,
            in: positionPromptPanelModel
        ) else {
            issues.append(
                issue(fixtureName, "position prompt 模式下应保留 Position Prompt section。")
            )
            return issues
        }
        assertFormPage(
            route: .section(.positionPrompt),
            expectedTitle: positionPromptSection.title,
            expectedSection: positionPromptSection,
            in: positionPromptNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Position Prompt active section",
            issues: &issues
        )
        if positionPromptNavigationModel.page(for: .positionPromptFilter) != nil {
            issues.append(
                issue(fixtureName, "只有一个 Position Prompt 子分组时，不应继续暴露独立的深层页。")
            )
        }

        return issues
    }

    static func validateFretboardViewportRouteVisibilityTracksDisplayMode()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "fretboard_viewport_route_visibility_tracks_display_mode"
        var issues: [SettingsNavigationValidationIssue] = []

        let sideVerticalStateContext = SettingsPanelStateContext.default
        let sideVerticalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: sideVerticalStateContext
        )
        let sideVerticalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: sideVerticalStateContext
        )
        guard let sideVerticalFretboardSection = resolveSection(.fretboard, in: sideVerticalPanelModel) else {
            issues.append(issue(fixtureName, "vertical 指板模式下应保留 Fretboard section。"))
            return issues
        }
        assertFormPage(
            route: .section(.fretboard),
            expectedTitle: sideVerticalFretboardSection.title,
            expectedSection: sideVerticalFretboardSection,
            in: sideVerticalNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Side Vertical Fretboard section",
            issues: &issues
        )
        if sideVerticalNavigationModel.page(for: .fretboardViewport) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "side + vertical 指板模式下不应继续生成 Fretboard Viewport 深层页。"
                )
            )
        }

        let stackedVerticalStateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
        let stackedVerticalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: stackedVerticalStateContext
        )
        let stackedVerticalNavigationModel = SettingsNavigationSnapshotBuilder
            .makeModel(from: stackedVerticalStateContext)
        guard let stackedVerticalFretboardSection = resolveSection(
            .fretboard,
            in: stackedVerticalPanelModel
        ) else {
            issues.append(issue(fixtureName, "stacked + vertical 指板模式下应保留 Fretboard section。"))
            return issues
        }
        assertIndexPage(
            route: .section(.fretboard),
            expectedTitle: stackedVerticalFretboardSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.fretboardDisplay.fallbackTitle,
                    subtitle: "Instrument and labels",
                    route: .fretboardDisplay
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.fretboardViewport.fallbackTitle,
                    subtitle: "Vertical sizing",
                    route: .fretboardViewport
                )
            ],
            in: stackedVerticalNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Stacked Vertical Fretboard section",
            issues: &issues
        )
        if stackedVerticalNavigationModel.page(for: .fretboardViewport) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "stacked + vertical 指板模式下应继续生成 Fretboard Viewport 深层页。"
                )
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
        let horizontalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: horizontalStateContext
        )
        guard let horizontalFretboardSection = resolveSection(.fretboard, in: horizontalPanelModel) else {
            issues.append(issue(fixtureName, "horizontal 指板模式下仍应保留 Fretboard section。"))
            return issues
        }
        assertFormPage(
            route: .section(.fretboard),
            expectedTitle: horizontalFretboardSection.title,
            expectedSection: horizontalFretboardSection,
            in: horizontalNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Horizontal Fretboard section",
            issues: &issues
        )
        if horizontalNavigationModel.page(for: .fretboardViewport) != nil {
            issues.append(
                issue(fixtureName, "horizontal 指板模式下不应继续生成 Fretboard Viewport 深层页。")
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

    static func validateExerciseAndAccessoryRowsMatchStage7Capabilities()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "exercise_and_accessory_rows_match_stage7_capabilities"
        let defaultStateContext = SettingsPanelStateContext.default
        let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: defaultStateContext
        )
        let defaultNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: defaultStateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        guard let exerciseSection = resolveSection(.exercise, in: defaultPanelModel) else {
            issues.append(
                issue(fixtureName, "default state 应保留 Exercise section。")
            )
            return issues
        }
        guard let accessoriesSection = resolveSection(.accessories, in: defaultPanelModel) else {
            issues.append(
                issue(fixtureName, "default state 应保留 Accessories section。")
            )
            return issues
        }

        if resolveSection(.layout, in: defaultPanelModel) != nil {
            issues.append(issue(fixtureName, "default state 不应再暴露 Layout section。"))
        }

        if exerciseSection.rows.map(\.id) != [
            .choice(.exerciseMode),
            .choice(.compositionPreset),
            .choice(.layoutPreset)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise section row 顺序应保持 Exercise Mode -> Composition Preset -> Layout Preset。"
                )
            )
        }

        guard let compositionRow = defaultPanelModel.choiceRow(for: .compositionPreset) else {
            issues.append(issue(fixtureName, "default state 应暴露 Composition Preset row。"))
            return issues
        }

        if compositionRow.choices.map(\.id) != [
            .setCompositionPresetStaffToFretboard,
            .setCompositionPresetTargetPromptToFretboard,
            .setCompositionPresetFretboardToNaturalNoteStrip,
            .setCompositionPresetFretboardSelfAnswer
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Composition Preset row 选项顺序应保持 Staff -> Target -> Strip -> Self。"
                )
            )
        }
        if compositionRow.choices.filter(\.isSelected).map(\.id) != [
            .setCompositionPresetFretboardToNaturalNoteStrip
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 默认态应选中 Fretboard -> Natural Note Strip 组合。"
                )
            )
        }
        if compositionRow.choices.first(
            where: { $0.id == .setCompositionPresetStaffToFretboard }
        )?.isEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 默认态下 Staff -> Fretboard 不应被标记为可用。"
                )
            )
        }

        guard let layoutRow = defaultPanelModel.choiceRow(for: .layoutPreset) else {
            issues.append(issue(fixtureName, "default state 应暴露 Layout Preset row。"))
            return issues
        }

        if layoutRow.choices.map(\.id) != [
            .setLayoutPresetStacked,
            .setLayoutPresetSideBySide,
            .setLayoutPresetSingleSurface
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Layout Preset row 选项顺序应保持 Stacked -> Side -> Single。"
                )
            )
        }
        if layoutRow.choices.filter(\.isSelected).map(\.id) != [
            .setLayoutPresetSideBySide
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "default state 应默认选中 Side by Side layout。"
                )
            )
        }
        if !(layoutRow.choices.first(
            where: { $0.id == .setLayoutPresetSideBySide }
        )?.isEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "default state 应继续允许切换到 Side by Side layout。"
                )
            )
        }
        if layoutRow.choices.first(
            where: { $0.id == .setLayoutPresetSingleSurface }
        )?.isEnabled ?? false {
            issues.append(
                issue(
                    fixtureName,
                    "默认的多 surface 组合不应把 Single Surface layout 标记为可用。"
                )
            )
        }

        if accessoriesSection.rows.map(\.id) != [
            .toggle(.naturalStripVisible),
            .toggle(.pianoAccessoryVisible),
            .choice(.accessoryPresentation),
            .toggle(.accessoryExpanded)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Accessories section rows 应保持 Natural Strip / Piano Accessory / Presentation / Expanded。"
                )
            )
        }

        guard let accessoryPresentationRow = defaultPanelModel.choiceRow(
            for: .accessoryPresentation
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "default state 应暴露 Accessory Presentation row。"
                )
            )
            return issues
        }
        if accessoryPresentationRow.choices.map(\.id) != [
            .setAccessoryPresentationDocked,
            .setAccessoryPresentationFloating,
            .setAccessoryPresentationCollapsible
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Accessory Presentation row 选项顺序应保持 Docked -> Floating -> Collapsible。"
                )
            )
        }
        if accessoryPresentationRow.choices.contains(where: { !$0.isEnabled }) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 7 后 Docked / Floating / Collapsible 三种 accessory presentation 都应可用。"
                )
            )
        }
        if defaultPanelModel.toggleRow(for: .naturalStripVisible)?.isEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 默认态下的 Natural Strip Visible toggle 应保持禁用，因为 strip 已承担主 answer surface。"
                )
            )
        }
        if defaultPanelModel.toggleRow(for: .accessoryExpanded)?.isEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "默认的 Docked accessory presentation 不应提前启用 Accessory Expanded toggle。"
                )
            )
        }

        let singleModeAccessoryStateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: .default,
            trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
        )
        let singleModeAccessoryPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: singleModeAccessoryStateContext
        )
        if !(singleModeAccessoryPanelModel.toggleRow(
            for: .naturalStripVisible
        )?.isEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "single 模式下 Natural Strip Visible toggle 应允许把 strip 作为 accessory surface 打开。"
                )
            )
        }

        var collapsibleStateContext = singleModeAccessoryStateContext
        SettingsActionID.setAccessoryPresentationCollapsible.apply(
            to: &collapsibleStateContext
        )
        let collapsiblePanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: collapsibleStateContext
        )
        if !(collapsiblePanelModel.toggleRow(
            for: .accessoryExpanded
        )?.isEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "选择 Collapsible presentation 后，Accessory Expanded toggle 应被启用。"
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
            .slider(.pianoRowCount),
            .choice(.pianoMovementScope),
            .toggle(.pianoSnapEnabled)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Behavior page rows 应保持 Rows / Row Linking / Snap Drag。"
                )
            )
        }

        let defaultPianoVisibleValue = defaultPanelModel.toggleRow(
            for: .pianoAccessoryVisible
        )?.isOn ?? true
        if defaultPianoVisibleValue {
            issues.append(
                issue(
                    fixtureName,
                    "default state 的 Piano Accessory Visible 开关应默认关闭。"
                )
            )
        }

        var visibleStateContext = defaultStateContext
        SettingsToggleID.pianoAccessoryVisible.apply(
            value: true,
            to: &visibleStateContext
        )
        if !visibleStateContext.pianoPanelState.isVisible {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Accessory Visible 开关写回后应把 pianoPanelState.isVisible 置为 true。"
                )
            )
        }

        let visiblePanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: visibleStateContext
        )
        let visiblePianoVisibleValue = visiblePanelModel.toggleRow(
            for: .pianoAccessoryVisible
        )?.isOn ?? false
        if !visiblePianoVisibleValue {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Accessory Visible 开关写回后，settings snapshot 也应回显为 true。"
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
                    "Piano Accessory Visible 打开后仍应继续保留 Piano Behavior page。"
                )
            )
            return issues
        }

        if visiblePianoBehaviorSection.rows.map(\.id).contains(
            .toggle(.pianoAccessoryVisible)
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Behavior page 不应重新混入 Piano Accessory Visible toggle。"
                )
            )
        }

        return issues
    }

    static func validateReconciledPathFallsBackToExistingParent()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "reconciled_path_falls_back_to_existing_parent"
        var issues: [SettingsNavigationValidationIssue] = []

        let startupStateContext = SettingsPanelStateContext.default
        let startupNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: startupStateContext
        )
        let availableAccessoryPath = startupNavigationModel.reconciledPath([
            .root,
            .section(.accessories),
            .accessoryPresentation
        ])
        if availableAccessoryPath != [.root, .section(.accessories), .accessoryPresentation] {
            issues.append(
                issue(fixtureName, "已存在的 Accessories 深层 route 不应被错误回退。")
            )
        }

        let singleTrainerNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
            )
        )
        let missingPositionPromptPath = singleTrainerNavigationModel.reconciledPath([
            .root,
            .section(.positionPrompt)
        ])
        if missingPositionPromptPath != [.root] {
            issues.append(
                issue(fixtureName, "缺失的 Position Prompt section route 应直接回退到 root。")
            )
        }

        var horizontalFretboardDisplayState = FretboardDisplayState.default
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                fretboardDisplayState: horizontalFretboardDisplayState
            )
        )
        let viewportFallbackPath = horizontalNavigationModel.reconciledPath([
            .section(.fretboard),
            .fretboardViewport
        ])
        if viewportFallbackPath != [.root, .section(.fretboard)] {
            issues.append(
                issue(fixtureName, "缺失的 Fretboard Viewport route 应回退到最近仍有效的 Fretboard 父级。")
            )
        }

        let duplicateRootPath = startupNavigationModel.reconciledPath([
            .root,
            .root,
            .section(.exercise)
        ])
        if duplicateRootPath != [.root, .section(.exercise)] {
            issues.append(
                issue(fixtureName, "reconciledPath 应去除重复 route，并保持 root 在首位。")
            )
        }

        return issues
    }

    static func validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "exercise_layout_route_remains_stable_across_choice_updates"
        var issues: [SettingsNavigationValidationIssue] = []

        let initialStateContext = SettingsPanelStateContext.default
        let initialNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: initialStateContext
        )
        let initialLayoutPath = initialNavigationModel.reconciledPath([
            .root,
            .section(.exercise),
            .exerciseLayout
        ])

        if initialLayoutPath != [.root, .section(.exercise), .exerciseLayout] {
            issues.append(
                issue(
                    fixtureName,
                    "default state 下 Exercise > Layout 深层 route 应保持可达。"
                )
            )
        }

        var sideBySideStateContext = initialStateContext
        SettingsPanelEvent.triggerAction(.setLayoutPresetSideBySide).apply(
            to: &sideBySideStateContext
        )
        let sideBySideNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: sideBySideStateContext
        )
        let sideBySideLayoutPath = sideBySideNavigationModel.reconciledPath(
            initialLayoutPath
        )

        if sideBySideLayoutPath != initialLayoutPath {
            issues.append(
                issue(
                    fixtureName,
                    "在 Exercise > Layout 子页切换 layout 选项时，reconciledPath 不应把当前路径回退或改写到其它 route。"
                )
            )
        }

        guard let layoutPage = sideBySideNavigationModel.page(for: .exerciseLayout),
              let layoutPanelModel = layoutPage.panelModel else {
            issues.append(
                issue(
                    fixtureName,
                    "切到 Side by Side 后，navigation model 仍应暴露 Exercise Layout form page。"
                )
            )
            return issues
        }

        guard let layoutRow = layoutPanelModel.choiceRow(for: .layoutPreset) else {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise Layout page 应继续暴露 Layout Preset row。"
                )
            )
            return issues
        }

        if layoutRow.choices.filter(\.isSelected).map(\.id) != [
            .setLayoutPresetSideBySide
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "切到 Side by Side 后，Exercise Layout page 应立即只选中 Side 选项。"
                )
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

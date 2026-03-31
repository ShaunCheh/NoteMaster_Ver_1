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
                name: "section_routes_wrap_single_section_pages",
                validate: validateSectionRoutesWrapSingleSectionPages
            ),
            SettingsNavigationValidationFixture(
                name: "position_prompt_context_keeps_trainer_section_projection",
                validate: validatePositionPromptContextKeepsTrainerSectionProjection
            ),
            SettingsNavigationValidationFixture(
                name: "layout_route_visibility_tracks_display_mode",
                validate: validateLayoutRouteVisibilityTracksDisplayMode
            ),
            SettingsNavigationValidationFixture(
                name: "reconciled_path_falls_back_to_existing_parent",
                validate: validateReconciledPathFallsBackToExistingParent
            ),
            SettingsNavigationValidationFixture(
                name: "reserved_route_titles_remain_stable",
                validate: validateReservedRouteTitlesRemainStable
            )
        ]
    }

    static func manualChecklist(
        for platform: SettingsNavigationValidationPlatform
    ) -> [String] {
        [
            "在 \(platform.displayName) 上确认 settings root 页展示顺序与共享层 section 顺序一致，不会因平台实现自行重排。",
            "确认从 root 进入任一 section detail page 后，标题与内容都与该 section 对齐，没有串页或丢行。",
            "确认切换到 horizontal 指板布局时，Layout route 会消失；切回 vertical 后 Layout route 会恢复。",
            "确认当当前深层 route 因状态变化失效时，卡片内导航会回到最近仍有效的父级，无法保留时兜底 root。"
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

    static func validateSectionRoutesWrapSingleSectionPages()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "section_routes_wrap_single_section_pages"
        let stateContext = SettingsPanelStateContext.default
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        for section in panelModel.sections {
            let route = SettingsRouteID.section(section.id)
            guard let page = navigationModel.page(for: route) else {
                issues.append(
                    issue(fixtureName, "缺少 \(section.title) 的 section route page。")
                )
                continue
            }

            if page.id != route {
                issues.append(
                    issue(fixtureName, "\(section.title) page.id 未对齐 route。")
                )
            }
            if page.title != section.title {
                issues.append(
                    issue(fixtureName, "\(section.title) page.title 应与 section.title 一致。")
                )
            }

            guard let sections = page.content.sections else {
                issues.append(
                    issue(fixtureName, "\(section.title) page.content 应为 form sections。")
                )
                continue
            }

            if sections != [section] {
                issues.append(
                    issue(fixtureName, "\(section.title) page 应只承载单个且原样的 section。")
                )
            }

            let expectedPanelModel = SettingsPanelModel(sections: [section])
            if page.panelModel != expectedPanelModel {
                issues.append(
                    issue(fixtureName, "\(section.title) page.panelModel 应与单 section panel model 对齐。")
                )
            }
        }

        return issues
    }

    static func validatePositionPromptContextKeepsTrainerSectionProjection()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "position_prompt_context_keeps_trainer_section_projection"
        let stateContext = SettingsPanelStateContext(
            pageDisplayState: .positionPrompt,
            trainerDisplayState: .default
        )
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        guard let trainerSection = resolveSection(.trainer, in: panelModel) else {
            issues.append(issue(fixtureName, "position prompt 启动态应保留 Trainer section。"))
            return issues
        }

        guard let rootRouteItems = navigationModel.rootPage?.content.routeItems else {
            issues.append(issue(fixtureName, "navigation rootPage 应暴露 route items。"))
            return issues
        }

        let trainerRoute = SettingsRouteID.section(.trainer)
        guard let trainerRouteItem = rootRouteItems.first(where: { $0.route == trainerRoute }) else {
            issues.append(issue(fixtureName, "position prompt 启动态的 root route 应包含 Trainer。"))
            return issues
        }

        if trainerRouteItem.title != trainerSection.title {
            issues.append(issue(fixtureName, "Trainer route item 标题应与 Trainer section 标题一致。"))
        }

        guard let trainerPage = navigationModel.page(for: trainerRoute) else {
            issues.append(issue(fixtureName, "position prompt 启动态缺少 Trainer detail page。"))
            return issues
        }

        if trainerPage.content.sections != [trainerSection] {
            issues.append(
                issue(fixtureName, "Trainer detail page 应完整承载 startup 的 Trainer section 投影。")
            )
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
        let trainerFallbackPath = startupNavigationModel.reconciledPath([
            .root,
            .section(.trainer),
            .trainerPositionFilter
        ])
        if trainerFallbackPath != [.root, .section(.trainer)] {
            issues.append(
                issue(fixtureName, "缺失的深层 route 应回退到最近仍有效的 Trainer 父级。")
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
        if SettingsRouteID.trainerPositionFilter.fallbackTitle != "Position Filter" {
            issues.append(
                issue(fixtureName, "trainerPositionFilter fallbackTitle 应为 Position Filter。")
            )
        }
        if SettingsRouteID.pianoAdvanced.fallbackTitle != "Advanced" {
            issues.append(issue(fixtureName, "pianoAdvanced fallbackTitle 应为 Advanced。"))
        }

        return issues
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

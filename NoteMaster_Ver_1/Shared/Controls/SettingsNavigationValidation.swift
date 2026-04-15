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

@MainActor
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
    var validate: @MainActor () -> [SettingsNavigationValidationIssue]
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
                name: "play_root_tree_keeps_only_piano_pages",
                validate: validatePlayRootTreeKeepsOnlyPianoPages
            ),
            SettingsNavigationValidationFixture(
                name: "root_mode_switch_preserves_exercise_tree_and_state",
                validate: validateRootModeSwitchPreservesExerciseTreeAndState
            ),
            SettingsNavigationValidationFixture(
                name: "sr0_root_tree_drops_invalid_exercise_and_accessory_routes",
                validate: validateSR0RootTreeDropsInvalidExerciseAndAccessoryRoutes
            ),
            SettingsNavigationValidationFixture(
                name: "sr1_root_tree_drops_invalid_exercise_and_accessory_routes",
                validate: validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes
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
                name: "vertical_viewport_gate_tracks_fretboard_contract_only",
                validate: validateVerticalViewportGateTracksFretboardContractOnly
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
                name: "sr0_settings_state_freezes_fixed_presentation_options",
                validate: validateSR0SettingsStateFreezesFixedPresentationOptions
            ),
            SettingsNavigationValidationFixture(
                name: "sr1_settings_state_freezes_fixed_presentation_options",
                validate: validateSR1SettingsStateFreezesFixedPresentationOptions
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
            "确认 settings root 不再暴露 `Position Prompt` section；Position 模式相关的音名候选入口统一收口在 `Exercise > Mode`。",
            "确认切换到 horizontal 指板布局，或在 side 布局下保持 vertical 指板时 `Fretboard > Vertical Viewport` 深层页会消失；切回 stacked + vertical 后会恢复。",
            "确认 settings 中没有新增 `Rail` / `Strip Size` / `Strip Alignment` 一类入口；右侧 natural note strip 的尺寸与居中仍保持为内部布局契约。",
            "确认 `Exercise > Mode` 页始终包含 `Exercise Mode`，并且仅在 `positionPrompt` 模式下追加 `Note Names` 多选行。",
            "确认 `Accessories` 分区包含 `Natural Strip Visible / Piano Accessory Visible / Accessory Presentation / Accessory Expanded`，`Piano > Behavior` 不再负责可见性开关。",
            "确认 `single/sequence` 下可以打开 `Natural Strip Visible`，而 `positionPrompt` 主 answer strip 场景里该 toggle 会自动禁用。",
            "确认 `Accessory Presentation` 里的 `Docked / Floating / Collapsible` 都可进入且可选；只有切到 `Collapsible` 后才启用 `Accessory Expanded`。",
            "确认切到 `SR-0` 或 `SR-1` 后，settings root 会移除 `Accessories` 分区，`Exercise` 也只保留有效的 `Mode` 入口，不再暴露会被 fixed normalization 强拉回的子页。",
            "确认 `SR-0` / `SR-1` 下 `Staff > Clef` 入口都会消失；`SR-1` 还应继续隐藏 `Piano > Rows and movement`，而 `SR-0` 仍保留后台钢琴配置入口。",
            "确认 `Debug` 分区包含 `Component Bounds` 与 `Side Container Borders` 两个开关；切换 `Side Container Borders` 时 side 布局的红/蓝容器边框会立即显示或隐藏。",
            "停留在 `Exercise > Layout` 子页时直接切换 `Stacked / Side / Single`，确认当前页不会闪跳、不会被重建回上一层，且选中态立即更新。",
            "确认切到 `play` mode 的 settings 后，root 只保留 `Mode / Piano` 分区，不再暴露 `Exercise / Accessories / Fretboard / Staff / Debug`。",
            "确认从 `exercise` 切到 `play` 再切回后，原来的 exercise mode、layout preset 和 piano rows / snap 之类的设置不会丢失。",
            "确认 iOS / macOS 上的标题、返回、关闭按钮布局与转场方向一致，没有双层导航条或页面闪跳。"
        ]
    }
}

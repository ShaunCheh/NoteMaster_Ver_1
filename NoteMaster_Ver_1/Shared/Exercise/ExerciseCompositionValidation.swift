//
//  ExerciseCompositionValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

import Foundation

enum ExerciseCompositionValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct ExerciseCompositionValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct ExerciseCompositionValidationReport {
    var platform: ExerciseCompositionValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [ExerciseCompositionValidationIssue]
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
        [ExerciseCompositionValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum ExerciseCompositionValidationRunner {
    static func run(
        platform: ExerciseCompositionValidationPlatform
    ) -> ExerciseCompositionValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [ExerciseCompositionValidationIssue] = []
        print(
            "[ExerciseCompositionValidation][\(platform.displayName)] begin fixtures=\(fixtures.count)"
        )

        for fixture in fixtures {
            print(
                "[ExerciseCompositionValidation][\(platform.displayName)] fixture begin name=\(fixture.name)"
            )
            let fixtureIssues = validate(fixture)
            print(
                "[ExerciseCompositionValidation][\(platform.displayName)] fixture end name=\(fixture.name) issues=\(fixtureIssues.count)"
            )
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        print(
            "[ExerciseCompositionValidation][\(platform.displayName)] end totalIssues=\(issues.count)"
        )

        return ExerciseCompositionValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(
        platform: ExerciseCompositionValidationPlatform
    ) {
        #if DEBUG
        print(
            "[ExerciseCompositionValidation][\(platform.displayName)] runAndReportIfNeeded begin"
        )
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)
        print(
            "[ExerciseCompositionValidation][\(platform.displayName)] runAndReportIfNeeded end passing=\(report.isPassing)"
        )

        if !report.isPassing {
            assertionFailure(summary)
        }
        #endif
    }
}

private struct ExerciseCompositionValidationFixture {
    var name: String
    var validate: () -> [ExerciseCompositionValidationIssue]
}

private extension ExerciseCompositionValidationRunner {
    static func validate(
        _ fixture: ExerciseCompositionValidationFixture
    ) -> [ExerciseCompositionValidationIssue] {
        fixture.validate()
    }

    static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
        [
            ExerciseCompositionValidationFixture(
                name: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
                validate: validateLegacySingleBaseline
            ),
            ExerciseCompositionValidationFixture(
                name: "legacy_sequence_baseline_matches_stacked_staff_over_fretboard",
                validate: validateLegacySequenceBaseline
            ),
            ExerciseCompositionValidationFixture(
                name: "legacy_position_prompt_baseline_matches_fretboard_over_natural_strip",
                validate: validateLegacyPositionPromptBaseline
            ),
            ExerciseCompositionValidationFixture(
                name: "page_state_normalization_preserves_single_fretboard_slot",
                validate: validatePageStateNormalizationPreservesSingleFretboardSlot
            ),
            ExerciseCompositionValidationFixture(
                name: "layout_defaults_keep_piano_hidden_and_vertical_viewport_visible",
                validate: validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible
            ),
            ExerciseCompositionValidationFixture(
                name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
                validate: validateSharedSceneContractsCoverBasicLayouts
            ),
            ExerciseCompositionValidationFixture(
                name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
                validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
            ),
            ExerciseCompositionValidationFixture(
                name: "shared_surface_state_defaults_follow_surface_roles",
                validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
            ),
            ExerciseCompositionValidationFixture(
                name: "shared_layout_preferences_coexist_with_legacy_page_state",
                validate: validateSharedLayoutPreferencesCoexistWithLegacyPageState
            ),
            ExerciseCompositionValidationFixture(
                name: "composition_policy_projects_supported_presets_to_expected_scenes",
                validate: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes
            ),
            ExerciseCompositionValidationFixture(
                name: "accessory_scene_nodes_follow_presentation_strategy",
                validate: validateAccessorySceneNodesFollowPresentationStrategy
            ),
            ExerciseCompositionValidationFixture(
                name: "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model",
                validate: validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel
            ),
            ExerciseCompositionValidationFixture(
                name: "scene_validator_rejects_duplicate_logical_surface_ids",
                validate: validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs
            ),
            ExerciseCompositionValidationFixture(
                name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
                validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
            ),
            ExerciseCompositionValidationFixture(
                name: "answer_router_routes_stacked_side_and_single_surface_answers",
                validate: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers
            )
        ]
    }

    static func manualChecklist(
        for platform: ExerciseCompositionValidationPlatform
    ) -> [String] {
        var checklist = [
            "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
            "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
            "确认把 `Layout Preset` 切到 `Side` 后，主视觉立即切成左右双栏，而不是被自动打回 `Stacked`。",
            "确认在 `positionPrompt` 里切到 `Composition Preset = Self` 后，页面收敛为单 `fretboard`，并且 settings 重新打开后该选择仍然保留。",
            "确认 stacked/side 的 `positionPrompt` 里，只有当前 answer surface 会响应答题；prompt-only 的 `fretboard` 点击不会误触发答题。",
            "确认单 `fretboard` 自答时，点击同音位置会走统一 answer router，并在正确反馈结束后推进到下一题。",
            "确认打开 settings 只改变 card 可见性，不会重置当前 trainer mode、page layout 或 `pianoAccessoryVisible`。",
            "确认关闭 settings 后页面恢复到关闭前的 prompt/answer 组合，不会闪回 `PageDisplayState.default`。",
            "确认 `positionPrompt` 下方的 `natural note strip` 不再被拉伸到超出首屏；无需向下滚动就能看见按钮文字。",
            "确认 `Piano Accessory Visible` 默认关闭；打开后会按当前 `Accessory Presentation` 进入 docked / floating / collapsible scene，关闭后主 prompt/answer 组合不发生漂移。",
            "确认在 `single/sequence` 下打开 `Natural Strip Visible` 时，strip 会作为 accessory surface 参与布局，但不会抢走 answer surface 角色。",
            "确认 `Collapsible` accessory 收起时，隐藏的 accessory 不可见也不可交互；重新展开后恢复到原来的 surface。",
            "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
        ]

        switch platform {
        case .iOS:
            checklist.append("在 iOS 上确认打开/关闭 settings、显示/隐藏钢琴后，scroll view 位置与触摸命中不会跳变。")
        case .macOS:
            checklist.append("在 macOS 上确认 live resize、打开/关闭 settings、显示/隐藏钢琴后，主布局不会闪回到错误组合。")
        case .commandLine:
            checklist.append("命令行只能覆盖 shared 夹具；settings 开关与钢琴显隐的实际视觉同步需在 App 运行时手工回归。")
        }

        return checklist
    }

    static func validateLegacySingleBaseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
            exerciseMode: .single,
            expectedPageDisplayState: .default
        )
    }

    static func validateLegacySequenceBaseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_sequence_baseline_matches_stacked_staff_over_fretboard",
            exerciseMode: .sequence,
            expectedPageDisplayState: .default
        )
    }

    static func validateLegacyPositionPromptBaseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_position_prompt_baseline_matches_fretboard_over_natural_strip",
            exerciseMode: .positionPrompt,
            expectedPageDisplayState: .positionPrompt
        )
    }

    static func validateLegacyBaseline(
        fixtureName: String,
        exerciseMode: TrainerExerciseMode,
        expectedPageDisplayState: PageDisplayState
    ) -> [ExerciseCompositionValidationIssue] {
        var issues: [ExerciseCompositionValidationIssue] = []

        if !expectedPageDisplayState.hasValidFretboardPlacement {
            issues.append(
                issue(
                    fixtureName,
                    "legacy page baseline 必须继续保证 fretboard 只占用一个视觉槽位。"
                )
            )
        }

        let stateContext = SettingsPanelStateContext(
            pageDisplayState: expectedPageDisplayState,
            trainerDisplayState: TrainerDisplayState(exerciseMode: exerciseMode)
        )
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        guard let exerciseSection = panelModel.sections.first(where: {
            $0.id == .exercise
        }) else {
            issues.append(
                issue(
                    fixtureName,
                    "settings snapshot 应保留 Exercise section。"
                )
            )
            return issues
        }

        if exerciseSection.rows.map(\.id) != [
            .choice(.exerciseMode),
            .choice(.compositionPreset),
            .choice(.layoutPreset)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 2 的 Exercise section 应稳定暴露 Exercise Mode / Composition Preset / Layout Preset。"
                )
            )
        }

        switch exerciseMode {
        case .single, .sequence:
            if expectedPageDisplayState.topContentMode != .staff
                || expectedPageDisplayState.mainContentMode != .fretboard {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 的 legacy baseline 应保持 staff -> fretboard。"
                    )
                )
            }
            if expectedPageDisplayState.showsFretboardInTopContent
                || !expectedPageDisplayState.showsFretboardInMainContent {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 的 legacy baseline 只允许 mainContent 承载 fretboard。"
                    )
                )
            }
            if panelModel.sections.contains(where: { $0.id == .positionPrompt }) {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 模式下不应继续暴露 Position Prompt section。"
                    )
                )
            }
            if panelModel.choiceRow(for: .compositionPreset)?.choices.filter(\.isSelected)
                .map(\.id) != [.setCompositionPresetStaffToFretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 的 legacy baseline 应把 Composition Preset 映射为 Staff -> Fretboard。"
                    )
                )
            }
        case .positionPrompt:
            if expectedPageDisplayState.topContentMode != .fretboard
                || expectedPageDisplayState.mainContentMode != .naturalNoteStrip {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 legacy baseline 应保持 fretboard -> naturalNoteStrip。"
                    )
                )
            }
            if !expectedPageDisplayState.showsFretboardInTopContent
                || expectedPageDisplayState.showsFretboardInMainContent {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 legacy baseline 只允许 topContent 承载 fretboard。"
                    )
                )
            }
            let expectedPositionPromptRowIDs: [SettingsRowID] = [
                .choice(.exerciseMode),
                .choice(.compositionPreset),
                .choice(.layoutPreset)
            ]
            if exerciseSection.rows.map(\.id) != expectedPositionPromptRowIDs {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 模式下 Exercise section 应继续保留 3 行基础预设入口。"
                    )
                )
            }
            guard let positionPromptSection = panelModel.sections.first(where: {
                $0.id == .positionPrompt
            }) else {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 模式下应继续暴露 Position Prompt section。"
                    )
                )
                return issues
            }
            if positionPromptSection.rows.map(\.id) != [
                .choice(.positionPromptFilterMode),
                .positionFilter(.positionPromptFilterOptions)
            ] {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 模式下 Position Prompt section 应继续暴露 Filter / Position Filter 两行。"
                    )
                )
            }
            if panelModel.choiceRow(for: .compositionPreset)?.choices.filter(\.isSelected)
                .map(\.id) != [.setCompositionPresetFretboardToNaturalNoteStrip] {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 legacy baseline 应把 Composition Preset 映射为 Fretboard -> Natural Note Strip。"
                    )
                )
            }
        }

        return issues
    }

    static func validatePageStateNormalizationPreservesSingleFretboardSlot()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "page_state_normalization_preserves_single_fretboard_slot"
        var issues: [ExerciseCompositionValidationIssue] = []

        let topPrioritizedContentModes = ExerciseSceneValidator
            .normalizedLegacyPageContentModes(
                topContentMode: .fretboard,
                mainContentMode: .fretboard,
                prioritizingTopContent: true
            )
        let topPrioritizedState = PageDisplayState(
            topContentMode: topPrioritizedContentModes.topContentMode,
            mainContentMode: topPrioritizedContentModes.mainContentMode
        )
        if topPrioritizedState.topContentMode != .fretboard
            || topPrioritizedState.mainContentMode != .naturalNoteStrip {
            issues.append(
                issue(
                    fixtureName,
                    "shared validator 在 top 优先时应继续把 mainContent 归一化到 naturalNoteStrip。"
                )
            )
        }

        let mainPrioritizedContentModes = ExerciseSceneValidator
            .normalizedLegacyPageContentModes(
                topContentMode: .fretboard,
                mainContentMode: .fretboard,
                prioritizingTopContent: false
            )
        let mainPrioritizedState = PageDisplayState(
            topContentMode: mainPrioritizedContentModes.topContentMode,
            mainContentMode: mainPrioritizedContentModes.mainContentMode
        )
        if mainPrioritizedState.topContentMode != .staff
            || mainPrioritizedState.mainContentMode != .fretboard {
            issues.append(
                issue(
                    fixtureName,
                    "shared validator 在 main 优先时应继续把 topContent 归一化到 staff。"
                )
            )
        }

        let initNormalizedState = PageDisplayState(
            topContentMode: .fretboard,
            mainContentMode: .fretboard
        )
        if initNormalizedState != topPrioritizedState {
            issues.append(
                issue(
                    fixtureName,
                    "PageDisplayState 初始化仍应保持 top 优先的 legacy 归一化结果。"
                )
            )
        }

        if !topPrioritizedState.hasValidFretboardPlacement
            || !mainPrioritizedState.hasValidFretboardPlacement {
            issues.append(
                issue(
                    fixtureName,
                    "legacy page normalization 结果必须保持唯一 fretboard placement。"
                )
            )
        }

        return issues
    }

    static func validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "layout_defaults_keep_piano_hidden_and_vertical_viewport_visible"
        let defaultStateContext = SettingsPanelStateContext.default
        let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: defaultStateContext
        )
        var issues: [ExerciseCompositionValidationIssue] = []

        if defaultStateContext.fretboardDisplayState.displayMode != .vertical {
            issues.append(
                issue(
                    fixtureName,
                    "迁移前默认指板 displayMode 应继续保持 vertical。"
                )
            )
        }
        if defaultStateContext.pianoPanelState.isVisible {
            issues.append(
                issue(
                    fixtureName,
                    "迁移前默认 pianoPanelState.isVisible 应继续保持 false。"
                )
            )
        }
        if abs(
            defaultStateContext.fretboardDisplayState.verticalHostHeightRatio
                - FretboardDisplayState.defaultVerticalHostHeightRatio
        ) > 0.0001 {
            issues.append(
                issue(
                    fixtureName,
                    "迁移前默认 verticalHostHeightRatio 应继续对齐 defaultVerticalHostHeightRatio。"
                )
            )
        }

        guard let pianoVisibleToggle = defaultPanelModel.toggleRow(
            for: .pianoAccessoryVisible
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "default settings snapshot 应继续暴露 Piano Accessory Visible 开关。"
                )
            )
            return issues
        }
        if pianoVisibleToggle.isOn {
            issues.append(
                issue(
                    fixtureName,
                    "default settings snapshot 中的 Piano Accessory Visible 开关应继续默认关闭。"
                )
            )
        }
        if defaultPanelModel.sliderRow(for: .verticalHostHeightRatio) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "vertical default settings snapshot 应继续暴露 Viewport Height 滑块。"
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
                    "Piano Accessory Visible 开关写回后应继续把 pianoPanelState.isVisible 置为 true。"
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
                    "Piano Accessory Visible 开关写回后，settings snapshot 也应继续回显为开启。"
                )
            )
        }

        var horizontalFretboardDisplayState = defaultStateContext.fretboardDisplayState
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                fretboardDisplayState: horizontalFretboardDisplayState,
                staffDisplayState: defaultStateContext.staffDisplayState,
                exerciseLayoutPreferences: defaultStateContext
                    .exerciseLayoutPreferences,
                trainerDisplayState: defaultStateContext.trainerDisplayState,
                pianoPanelState: defaultStateContext.pianoPanelState
            )
        )
        if horizontalPanelModel.sliderRow(for: .verticalHostHeightRatio) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "horizontal settings snapshot 不应继续暴露 Viewport Height 滑块。"
                )
            )
        }

        return issues
    }

    static func validateSharedSceneContractsCoverBasicLayouts()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface"
        var issues: [ExerciseCompositionValidationIssue] = []

        let stackedScene = ExerciseScene.stacked(
            top: .staffPrompt,
            bottom: .fretboardAnswer
        )
        switch stackedScene.root {
        case let .split(axis, children):
            if axis != .vertical {
                issues.append(
                    issue(
                        fixtureName,
                        "stacked scene 应落成 vertical split。"
                    )
                )
            }
            let childSurfaceIDs = children.compactMap {
                $0.node.surfaceNodes.first?.id
            }
            if childSurfaceIDs != [.staff, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "stacked scene 应保持 staff 在上、fretboard 在下。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "stacked scene 的根节点应为 split。"
                )
            )
        }

        let sideBySideScene = ExerciseScene.sideBySide(
            leading: .targetPrompt,
            trailing: .fretboardAnswer
        )
        switch sideBySideScene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "sideBySide scene 应落成 horizontal split。"
                    )
                )
            }
            let childSurfaceIDs = children.compactMap {
                $0.node.surfaceNodes.first?.id
            }
            if childSurfaceIDs != [.targetPrompt, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "sideBySide scene 应保持 targetPrompt 在左、fretboard 在右。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide scene 的根节点应为 split。"
                )
            )
        }

        let singleSurfaceScene = ExerciseScene.singleSurface(
            .fretboardPromptAndAnswer
        )
        switch singleSurfaceScene.root {
        case let .surface(surface):
            if surface.id != .fretboard || surface.kind != .fretboard {
                issues.append(
                    issue(
                        fixtureName,
                        "singleSurface scene 应落到单个 fretboard surface。"
                    )
                )
            }
            if !surface.roles.contains(.prompt)
                || !surface.roles.contains(.answer) {
                issues.append(
                    issue(
                        fixtureName,
                        "singleSurface scene 中的 fretboard 应同时承担 prompt 与 answer。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "singleSurface scene 的根节点应为 surface。"
                )
            )
        }

        return issues
    }

    static func validateVerticalFitContentSplitSizingTracksSurfaceKinds()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "vertical_fit_content_split_sizing_tracks_surface_kinds"
        var issues: [ExerciseCompositionValidationIssue] = []

        let staffStackedScene = ExerciseScene.stacked(
            top: .staffPrompt,
            bottom: .fretboardAnswer
        )
        switch staffStackedScene.root {
        case let .split(axis, children):
            if axis != .vertical
                || children.count != 2
                || children[0].sizing != .fitContent
                || children[1].sizing != .fill {
                issues.append(
                    issue(
                        fixtureName,
                        "staff -> fretboard 的 vertical split 应保持上方 prompt fitContent、下方 fretboard fill。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard stacked scene 应继续落成 vertical split。"
                )
            )
        }

        let positionPromptScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
        switch positionPromptScene.root {
        case let .split(axis, children):
            if axis != .vertical
                || children.count != 2
                || children[0].sizing != .fill
                || children[1].sizing != .fitContent {
                issues.append(
                    issue(
                        fixtureName,
                        "fretboard -> natural note strip 的 vertical split 应保持上方 fretboard fill、下方 strip fitContent。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的主视觉 scene 应继续落成 vertical split。"
                )
            )
        }
        if !positionPromptScene.hasVerticalFitContentSplit {
            issues.append(
                issue(
                    fixtureName,
                    "包含 natural note strip answer 的 vertical split 应触发 fitContent scene 语义。"
                )
            )
        }

        let threePaneScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .staffToFretboard,
                layoutPreset: .threePane,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: true,
                isAccessoryExpanded: true
            )
        )
        switch threePaneScene.root {
        case let .split(_, children):
            guard
                children.count == 2,
                case let .split(_, accessoryChildren) = children[1].node
            else {
                issues.append(
                    issue(
                        fixtureName,
                        "threePane accessory subtree 应继续落成承载 strip/piano 的 split。"
                    )
                )
                return issues
            }
            if accessoryChildren.count != 2
                || accessoryChildren[0].sizing != .fitContent
                || accessoryChildren[1].sizing != .fill {
                issues.append(
                    issue(
                        fixtureName,
                        "threePane accessory split 应保持 strip fitContent、piano fill。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "threePane scene 应继续以 split 承载主视觉与 accessory subtree。"
                )
            )
        }

        let sideBySideScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .targetPromptToFretboard,
                layoutPreset: .sideBySide,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: false,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
        if sideBySideScene.hasVerticalFitContentSplit {
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide scene 不应误触发 vertical fitContent split 语义。"
                )
            )
        }

        return issues
    }

    static func validateSharedSurfaceStateDefaultsFollowSurfaceRoles()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_surface_state_defaults_follow_surface_roles"
        var issues: [ExerciseCompositionValidationIssue] = []
        var presentationState = ExercisePresentationState(
            scene: .singleSurface(.fretboardPromptAndAnswer)
        )

        guard let defaultFretboardState = presentationState.surfaceState(
            for: .fretboard
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "presentation state 应能为 scene 中的 fretboard 推导默认 surface state。"
                )
            )
            return issues
        }

        if !defaultFretboardState.isVisible
            || !defaultFretboardState.isPromptActive
            || !defaultFretboardState.isAnswerEnabled
            || !defaultFretboardState.isInteractionEnabled {
            issues.append(
                issue(
                    fixtureName,
                    "双角色 fretboard 的默认 surface state 应同时开启可见、prompt active、answer enabled 与 interaction enabled。"
                )
            )
        }
        if presentationState.surfaceState(for: .staff) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "presentation state 不应为不在 scene 中的 surface 凭空生成状态。"
                )
            )
        }

        presentationState.setSurfaceState(
            ExerciseSurfaceState(
                isVisible: false,
                isPromptActive: true,
                isAnswerEnabled: false,
                isInteractionEnabled: false
            ),
            for: .fretboard
        )
        let overriddenState = presentationState.surfaceState(for: .fretboard)
        if overriddenState?.isVisible ?? true
            || !(overriddenState?.isPromptActive ?? false)
            || overriddenState?.isAnswerEnabled ?? true
            || overriddenState?.isInteractionEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "显式写入的 surface state 应覆盖默认角色投影。"
                )
            )
        }

        return issues
    }

    static func validateSharedLayoutPreferencesCoexistWithLegacyPageState()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_layout_preferences_coexist_with_legacy_page_state"
        var issues: [ExerciseCompositionValidationIssue] = []
        let defaultStateContext = SettingsPanelStateContext.default

        if defaultStateContext.exerciseLayoutPreferences != .legacyPositionPrompt {
            issues.append(
                issue(
                    fixtureName,
                    "SettingsPanelStateContext.default 应对齐 positionPrompt 的 legacy ExerciseLayoutPreferences。"
                )
            )
        }

        let customPreferences = ExerciseLayoutPreferences.singleFretboardSelfAnswer
        let stateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: customPreferences,
            trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt)
        )
        if stateContext.pageDisplayState != .positionPrompt {
            issues.append(
                issue(
                    fixtureName,
                    "设置 context 应继续从 ExerciseLayoutPreferences 投影 legacy page bridge。"
                )
            )
        }
        if stateContext.exerciseLayoutPreferences != customPreferences {
            issues.append(
                issue(
                    fixtureName,
                    "并存阶段设置 context 应能携带新的 ExerciseLayoutPreferences。"
                )
            )
        }

        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        if panelModel.sections.first(where: { $0.id == .exercise }) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 2 中，shared context 新增字段不应破坏新 Exercise section 的生成。"
                )
            )
        }

        let preservedSideBySidePreferences = LegacyPageLayoutAdapter
            .normalizedPreferences(
                ExerciseLayoutPreferences(
                    compositionPreset: .targetPromptToFretboard,
                    layoutPreset: .sideBySide
                ),
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
            )
        if preservedSideBySidePreferences.layoutPreset != .sideBySide {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 4 中，bridge 不应再把已支持的 sideBySide 语义布局压回 stacked。"
                )
            )
        }

        let preservedSelfAnswerPreferences = LegacyPageLayoutAdapter
            .normalizedPreferences(
                .singleFretboardSelfAnswer,
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: .positionPrompt
                )
            )
        if preservedSelfAnswerPreferences.compositionPreset != .fretboardSelfAnswer
            || preservedSelfAnswerPreferences.layoutPreset != .singleSurface {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 4 中，positionPrompt 的单 fretboard self-answer 偏好不应在 settings bridge 往返时丢失。"
                )
            )
        }

        return issues
    }

    static func validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "composition_policy_projects_supported_presets_to_expected_scenes"
        var issues: [ExerciseCompositionValidationIssue] = []

        let sideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .targetPromptToFretboard,
                    layoutPreset: .sideBySide
                )
            )
        )
        if !ExerciseSceneValidator.validate(sideBySidePresentation.scene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide 的 targetPrompt -> fretboard 组合应生成合法 scene。"
                )
            )
        }
        switch sideBySidePresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "targetPrompt -> fretboard 的 sideBySide 组合应投影到 horizontal split。"
                    )
                )
            }
            let childSurfaceIDs = children.compactMap {
                $0.node.surfaceNodes.first?.id
            }
            if childSurfaceIDs != [.targetPrompt, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "targetPrompt -> fretboard 的 sideBySide 组合应保持 targetPrompt 在左、fretboard 在右。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide 组合应生成 split scene。"
                )
            )
        }
        if sideBySidePresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "horizontal split 在阶段 3 仍不应被误标记为 legacy page 可直接投影。"
                )
            )
        }

        let selfAnswerPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: .positionPrompt
                ),
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .singleFretboardSelfAnswer
            )
        )
        if !ExerciseSceneValidator.validate(selfAnswerPresentation.scene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 组合应生成合法 scene。"
                )
            )
        }
        switch selfAnswerPresentation.scene.root {
        case let .surface(surface):
            if surface.id != .fretboard
                || !surface.roles.contains(.prompt)
                || !surface.roles.contains(.answer) {
                issues.append(
                    issue(
                        fixtureName,
                        "single fretboard self-answer 应投影为同时承担 prompt/answer 的单 fretboard surface。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 应投影为单 surface scene。"
                )
            )
        }
        let selfAnswerFretboardState = selfAnswerPresentation.surfaceState(
            for: .fretboard
        )
        if !(selfAnswerFretboardState?.isPromptActive ?? false)
            || !(selfAnswerFretboardState?.isAnswerEnabled ?? false)
            || !(selfAnswerFretboardState?.isInteractionEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 的 fretboard surface state 应同时开启 prompt、answer 和 interaction。"
                )
            )
        }
        if selfAnswerPresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 在阶段 3 仍不应被误投影成 legacy page 双槽位。"
                )
            )
        }

        let positionPromptPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: .positionPrompt
                ),
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .legacyPositionPrompt
            )
        )
        if positionPromptPresentation.legacyPageDisplayState != .positionPrompt {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip 组合应继续投影回 legacy positionPrompt 页面。"
                )
            )
        }

        return issues
    }

    static func validateAccessorySceneNodesFollowPresentationStrategy()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "accessory_scene_nodes_follow_presentation_strategy"
        var issues: [ExerciseCompositionValidationIssue] = []

        let floatingAccessoryPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToFretboard,
                    layoutPreset: .stacked,
                    accessoryPresentation: .floating,
                    isNaturalNoteStripVisible: true
                )
            )
        )
        switch floatingAccessoryPresentation.scene.root {
        case let .overlay(base, floating):
            let baseSurfaceIDs = base.surfaceNodes.map(\.id)
            let floatingSurfaceIDs = floating.flatMap { $0.surfaceNodes }.map(\.id)
            if baseSurfaceIDs != [.staff, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "Floating accessory scene 的 base 应继续保持 staff -> fretboard 主视觉组合。"
                    )
                )
            }
            if floatingSurfaceIDs != [.naturalNoteStrip] {
                issues.append(
                    issue(
                        fixtureName,
                        "Floating accessory scene 应把 natural note strip 放进 floating accessory 节点。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "Accessory Presentation = Floating 时应生成 overlay scene。"
                )
            )
        }
        guard let floatingStripState = floatingAccessoryPresentation.surfaceState(
            for: .naturalNoteStrip
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "Floating accessory scene 应继续生成 natural note strip surface state。"
                )
            )
            return issues
        }
        if !floatingStripState.isVisible
            || floatingStripState.isAnswerEnabled
            || floatingStripState.isInteractionEnabled {
            issues.append(
                issue(
                    fixtureName,
                    "作为 accessory surface 的 natural note strip 应可见，但不能承担 answer 或交互职责。"
                )
            )
        }
        if floatingAccessoryPresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "Floating accessory scene 不应被误投影成 legacy page 双槽位。"
                )
            )
        }

        let collapsedAccessoryPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: .stacked,
                        accessoryPresentation: .collapsible,
                        isNaturalNoteStripVisible: false,
                        isPianoAccessoryVisible: true,
                        isAccessoryExpanded: false
                    )
                )
            )
        switch collapsedAccessoryPresentation.scene.root {
        case let .collapsible(main, accessory, isExpanded):
            if isExpanded {
                issues.append(
                    issue(
                        fixtureName,
                        "Accessory Presentation = Collapsible 且 isAccessoryExpanded = false 时不应错误展开 accessory。"
                    )
                )
            }
            if main.surfaceNodes.map(\.id) != [.staff, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "Collapsible scene 的 main 分支应继续保持 staff -> fretboard 主视觉组合。"
                    )
                )
            }
            if accessory.surfaceNodes.map(\.id) != [.piano] {
                issues.append(
                    issue(
                        fixtureName,
                        "Collapsible scene 的 accessory 分支应承载 piano surface。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "Accessory Presentation = Collapsible 时应生成 collapsible scene。"
                )
            )
        }
        let collapsedPianoState = collapsedAccessoryPresentation.surfaceState(
            for: .piano
        )
        if collapsedPianoState?.isVisible ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "收起的 collapsible accessory 应把 piano surface 标记为不可见。"
                )
            )
        }
        if collapsedPianoState?.isInteractionEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "收起的 collapsible accessory 不应继续保留 piano 的交互能力。"
                )
            )
        }

        let threePaneLayoutScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .staffToFretboard,
                layoutPreset: .threePane,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: true
            )
        )
        switch threePaneLayoutScene.root {
        case let .split(axis, children):
            if axis != .vertical || children.count != 2 {
                issues.append(
                    issue(
                        fixtureName,
                        "ThreePane layout 应以 vertical split 承载主内容与 accessory subtree。"
                    )
                )
            } else {
                let mainSurfaceIDs = children[0].node.surfaceNodes.map(\.id)
                let accessorySurfaceIDs = children[1].node.surfaceNodes.map(\.id)
                if mainSurfaceIDs != [.staff, .fretboard] {
                    issues.append(
                        issue(
                            fixtureName,
                            "ThreePane layout 的主分支应继续保持 staff -> fretboard 组合。"
                        )
                    )
                }
                if accessorySurfaceIDs != [.naturalNoteStrip, .piano] {
                    issues.append(
                        issue(
                            fixtureName,
                            "ThreePane layout 的 accessory 分支应同时容纳 natural note strip 与 piano。"
                        )
                    )
                }
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "layoutPreset = ThreePane 时应生成 docked split scene。"
                )
            )
        }

        return issues
    }

    static func validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model"
        var issues: [ExerciseCompositionValidationIssue] = []

        let sideBySideLegacyPresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .single
                    ),
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .targetPromptToFretboard,
                        layoutPreset: .sideBySide
                    )
                )
            )
        if sideBySideLegacyPresentation.resolvedLayoutPreferences.layoutPreset
            != .stacked {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应把 sideBySide 回退到 stacked。"
                )
            )
        }
        if sideBySideLegacyPresentation.resolvedLayoutPreferences.compositionPreset
            != .targetPromptToFretboard {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口在能保留 targetPrompt -> fretboard 时不应错误回退到 staff -> fretboard。"
                )
            )
        }
        if sideBySideLegacyPresentation.legacyPageDisplayState
            != PageDisplayState(
                topContentMode: .targetPrompt,
                mainContentMode: .fretboard
            ) {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应把 targetPrompt -> fretboard 回投影为 legacy targetPrompt 页面。"
                )
            )
        }

        let selfAnswerLegacyPresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .positionPrompt
                    ),
                    fretboardTrainerState: .init(positionPromptMode: ()),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: .singleFretboardSelfAnswer
                )
            )
        if selfAnswerLegacyPresentation.resolvedLayoutPreferences.compositionPreset
            != .fretboardToNaturalNoteStrip
            || selfAnswerLegacyPresentation.resolvedLayoutPreferences.layoutPreset
            != .stacked {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应把 single fretboard self-answer 回退到 stacked 的 fretboard -> natural note strip。"
                )
            )
        }
        if selfAnswerLegacyPresentation.legacyPageDisplayState != .positionPrompt {
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 的 legacy fallback 应继续投影到 positionPrompt 页面。"
                )
            )
        }

        let floatingAccessoryLegacyPresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .single
                    ),
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: .stacked,
                        accessoryPresentation: .floating,
                        isNaturalNoteStripVisible: true,
                        isPianoAccessoryVisible: true
                    )
                )
            )
        if floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .accessoryPresentation != .docked
            || floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .isNaturalNoteStripVisible
            || floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应清空可选 accessory scene，只保留 page model 能表达的 docked 主视觉组合。"
                )
            )
        }
        if floatingAccessoryLegacyPresentation.legacyPageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "带 floating accessory 请求的 legacy fallback 仍应继续回投影到默认 single 页面。"
                )
            )
        }

        return issues
    }

    static func validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "scene_validator_rejects_duplicate_logical_surface_ids"
        var issues: [ExerciseCompositionValidationIssue] = []

        let duplicateFretboardScene = ExerciseScene(
            root: .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(node: .surface(.fretboardPrompt)),
                    ExerciseSceneSplitChild(node: .surface(.fretboardAnswer))
                ]
            )
        )
        let duplicateIssues = ExerciseSceneValidator.validate(
            duplicateFretboardScene
        )
        if !duplicateIssues.contains(.duplicateSurfaceID(.fretboard)) {
            issues.append(
                issue(
                    fixtureName,
                    "validator 应拒绝同一个 logical fretboard 被拆成两个 scene 节点的情况。"
                )
            )
        }

        let validSelfAnswerScene = ExerciseScene.singleSurface(
            .fretboardPromptAndAnswer
        )
        if !ExerciseSceneValidator.validate(validSelfAnswerScene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "同时承担 prompt/answer 的单 fretboard scene 不应被 validator 误判为重复 surface。"
                )
            )
        }

        return issues
    }

    static func validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_answer_contracts_default_position_prompt_to_same_pitch_class"
        var issues: [ExerciseCompositionValidationIssue] = []

        let defaultConfiguration = TrainerPositionPromptConfiguration.default
        if defaultConfiguration.answerRule != .samePitchClass {
            issues.append(
                issue(
                    fixtureName,
                    "PositionPromptAnswerRule 首版默认值应为 samePitchClass。"
                )
            )
        }

        var trainerDisplayState = TrainerDisplayState(exerciseMode: .positionPrompt)
        if trainerDisplayState.positionPromptAnswerRule != .samePitchClass {
            issues.append(
                issue(
                    fixtureName,
                    "TrainerDisplayState 应暴露 samePitchClass 作为 positionPrompt 的默认答题规则。"
                )
            )
        }
        trainerDisplayState.setPositionPromptAnswerRule(.samePitchClass)
        if trainerDisplayState.positionPromptConfiguration.answerRule
            != .samePitchClass {
            issues.append(
                issue(
                    fixtureName,
                    "设置 positionPrompt answer rule 后，应写回到 positionPromptConfiguration。"
                )
            )
        }

        let fretboardCellEvent = ExerciseAnswerEvent.fretboardCell(
            FretboardCell(stringIndex: 2, fret: 3),
            from: .fretboard
        )
        if fretboardCellEvent.surfaceID != .fretboard
            || fretboardCellEvent.payload.fretboardCell
                != FretboardCell(stringIndex: 2, fret: 3) {
            issues.append(
                issue(
                    fixtureName,
                    "ExerciseAnswerEvent 应保留 fretboardCell payload 与来源 surfaceID。"
                )
            )
        }

        let pitchClassEvent = ExerciseAnswerEvent.pitchClass(
            .c,
            from: .naturalNoteStrip
        )
        if pitchClassEvent.surfaceID != .naturalNoteStrip
            || pitchClassEvent.payload.pitchClass != .c {
            issues.append(
                issue(
                    fixtureName,
                    "ExerciseAnswerEvent 应保留 pitchClass payload 与来源 surfaceID。"
                )
            )
        }

        return issues
    }

    static func validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "answer_router_routes_stacked_side_and_single_surface_answers"
        var issues: [ExerciseCompositionValidationIssue] = []
        let fretboardConfiguration = FretboardConfiguration()
        let answerCell = FretboardCell(stringIndex: 0, fret: 0)
        guard let answerPitchClass = fretboardConfiguration.pitchClass(
            for: answerCell
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 5 的 answer router 夹具需要一个可解析为 pitch class 的 fretboard cell。"
                )
            )
            return issues
        }

        let singleTrainerDisplayState = TrainerDisplayState(exerciseMode: .single)
        let stackedSinglePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: singleTrainerDisplayState,
                fretboardTrainerState: .init(targetPitchClass: .c),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .default
            )
        )
        let fretboardCellEvent = ExerciseAnswerEvent.fretboardCell(
            answerCell,
            from: .fretboard
        )
        if ExerciseAnswerRouter.route(
            fretboardCellEvent,
            presentationState: stackedSinglePresentation,
            trainerDisplayState: singleTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .singleCoverage(
                event: fretboardCellEvent,
                cell: answerCell
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "上下布局中的单音训练应把 fretboardCell 事件路由到 singleCoverage answer。"
                )
            )
        }

        let positionPromptTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .positionPrompt
        )
        let sideBySidePositionPromptPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: positionPromptTrainerDisplayState,
                    fretboardTrainerState: .init(positionPromptMode: ()),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .fretboardToNaturalNoteStrip,
                        layoutPreset: .sideBySide
                    )
                )
            )
        let naturalNoteStripEvent = ExerciseAnswerEvent.pitchClass(
            .e,
            from: .naturalNoteStrip
        )
        if ExerciseAnswerRouter.route(
            naturalNoteStripEvent,
            presentationState: sideBySidePositionPromptPresentation,
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .positionPrompt(
                ExercisePositionPromptRoutedAnswer(
                    event: naturalNoteStripEvent,
                    pitchClass: .e
                )
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "左右布局中的 positionPrompt 应允许 natural note strip 继续作为可选 answer surface。"
                )
            )
        }

        let stackedPositionPromptPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: positionPromptTrainerDisplayState,
                    fretboardTrainerState: .init(positionPromptMode: ()),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: .legacyPositionPrompt
                )
            )
        if ExerciseAnswerRouter.route(
            fretboardCellEvent,
            presentationState: stackedPositionPromptPresentation,
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .ignored(.answerDisabled(.fretboard)) {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 positionPrompt 里，prompt-only fretboard 不应再被当成唯一答题入口。"
                )
            )
        }

        let selfAnswerPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: positionPromptTrainerDisplayState,
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .singleFretboardSelfAnswer
            )
        )
        if ExerciseAnswerRouter.route(
            fretboardCellEvent,
            presentationState: selfAnswerPresentation,
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .positionPrompt(
                ExercisePositionPromptRoutedAnswer(
                    event: fretboardCellEvent,
                    pitchClass: answerPitchClass
                )
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "单 fretboard self-answer 应把 fretboardCell 解析成 pitch class，并继续路由到 positionPrompt answer。"
                )
            )
        }

        return issues
    }

    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> ExerciseCompositionValidationIssue {
        ExerciseCompositionValidationIssue(
            fixtureName: fixtureName,
            message: message
        )
    }
}

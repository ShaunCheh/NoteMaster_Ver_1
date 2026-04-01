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
            )
        ]
    }

    static func manualChecklist(
        for platform: ExerciseCompositionValidationPlatform
    ) -> [String] {
        var checklist = [
            "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
            "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
            "确认打开 settings 只改变 card 可见性，不会重置当前 trainer mode、page layout 或 `pianoVisible`。",
            "确认关闭 settings 后页面恢复到关闭前的 prompt/answer 组合，不会闪回 `PageDisplayState.default`。",
            "确认 `Piano Visible` 默认关闭；打开后只追加钢琴区域，关闭后主 prompt/answer 组合不发生漂移。",
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
        guard let trainerSection = panelModel.sections.first(where: {
            $0.id == .trainer
        }) else {
            issues.append(
                issue(
                    fixtureName,
                    "settings snapshot 应继续保留 Trainer section。"
                )
            )
            return issues
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
            let expectedTrainerRowIDs: [SettingsRowID] = [
                .choice(.exerciseMode)
            ]
            if trainerSection.rows.map(\.id) != expectedTrainerRowIDs {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 模式下 Trainer settings 应只保留 Exercise Mode 行。"
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
            let expectedTrainerRowIDs: [SettingsRowID] = [
                .choice(.exerciseMode),
                .choice(.positionPromptFilterMode),
                .positionFilter(.positionPromptFilterOptions)
            ]
            if trainerSection.rows.map(\.id) != expectedTrainerRowIDs {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 模式下 Trainer settings 应继续暴露 Exercise Mode / Filter / Position Filter 三行。"
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

        var topPrioritizedState = PageDisplayState.default
        topPrioritizedState.setTopContentMode(.fretboard)
        if topPrioritizedState.topContentMode != .fretboard
            || topPrioritizedState.mainContentMode != .naturalNoteStrip {
            issues.append(
                issue(
                    fixtureName,
                    "setTopContentMode(.fretboard) 后应继续把 mainContent 归一化到 naturalNoteStrip。"
                )
            )
        }

        var mainPrioritizedState = PageDisplayState.positionPrompt
        mainPrioritizedState.setMainContentMode(.fretboard)
        if mainPrioritizedState.topContentMode != .staff
            || mainPrioritizedState.mainContentMode != .fretboard {
            issues.append(
                issue(
                    fixtureName,
                    "setMainContentMode(.fretboard) 后应继续把 topContent 归一化到 staff。"
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
            for: .pianoVisible
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "default settings snapshot 应继续暴露 Piano Visible 开关。"
                )
            )
            return issues
        }
        if pianoVisibleToggle.isOn {
            issues.append(
                issue(
                    fixtureName,
                    "default settings snapshot 中的 Piano Visible 开关应继续默认关闭。"
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
                    "Piano Visible 开关写回后，settings snapshot 也应继续回显为开启。"
                )
            )
        }

        var horizontalFretboardDisplayState = defaultStateContext.fretboardDisplayState
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                fretboardDisplayState: horizontalFretboardDisplayState,
                staffDisplayState: defaultStateContext.staffDisplayState,
                pageDisplayState: defaultStateContext.pageDisplayState,
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

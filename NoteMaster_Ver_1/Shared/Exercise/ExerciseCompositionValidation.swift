//
//  ExerciseCompositionValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

import CoreGraphics
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

fileprivate struct ExerciseCompositionValidationFixture {
    var name: String
    var validate: () -> [ExerciseCompositionValidationIssue]
}

fileprivate extension ExerciseCompositionValidationRunner {
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
                name: "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing",
                validate: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing
            ),
            ExerciseCompositionValidationFixture(
                name: "scheme_one_horizontal_strip_semantic_boundary_stays_distinct_from_vertical_rail",
                validate:
                    validateSchemeOneHorizontalStripSemanticBoundaryStaysDistinctFromVerticalRail
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_horizontal_layout_context_freezes_two_row_defaults",
                validate:
                    validateNaturalNoteStripHorizontalLayoutContextFreezesTwoRowDefaults
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_horizontal_layout_builder_exposes_shared_layout_output",
                validate:
                    validateNaturalNoteStripHorizontalLayoutBuilderExposesSharedLayoutOutput
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_horizontal_layout_preserves_row_topology_and_content_size",
                validate:
                    validateNaturalNoteStripHorizontalLayoutPreservesRowTopologyAndContentSize
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
                validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
            ),
            ExerciseCompositionValidationFixture(
                name: "side_rail_contract_remains_orthogonal_to_fretboard_height_contract",
                validate: validateSideRailContractRemainsOrthogonalToFretboardHeightContract
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_stage_c_topology_freezes_chromatic12_semantics",
                validate: validateNaturalNoteStripStageCTopologyFreezesChromatic12Semantics
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_stage_c_layout_context_freezes_default_geometry_tokens",
                validate:
                    validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_stage_c_layout_builder_exposes_shared_layout_output",
                validate:
                    validateNaturalNoteStripStageCLayoutBuilderExposesSharedLayoutOutput
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_staggered_two_column_layout_matches_pitchclass_topology",
                validate:
                    validateNaturalNoteStripStaggeredTwoColumnLayoutMatchesPitchclassTopology
            ),
            ExerciseCompositionValidationFixture(
                name: "natural_note_strip_shared_layout_content_size_matches_intrinsic_semantics",
                validate:
                    validateNaturalNoteStripSharedLayoutContentSizeMatchesIntrinsicSemantics
            ),
            ExerciseCompositionValidationFixture(
                name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
                validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
            ),
            ExerciseCompositionValidationFixture(
                name: "phase_zero_side_by_side_invariants_preserve_composition_specific_surface_pairs",
                validate: validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs
            ),
            ExerciseCompositionValidationFixture(
                name: "shared_surface_state_defaults_follow_surface_roles",
                validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
            ),
            ExerciseCompositionValidationFixture(
                name: "surface_membership_distinguishes_absent_and_hidden_states",
                validate: validateSurfaceMembershipDistinguishesAbsentAndHiddenStates
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
                name: "staff_to_piano_scene_promotes_main_piano_answer_surface",
                validate: validateStaffToPianoScenePromotesMainPianoAnswerSurface
            ),
            ExerciseCompositionValidationFixture(
                name: "staff_to_natural_note_strip_scene_promotes_main_natural_note_strip_answer_surface",
                validate:
                    validateStaffToNaturalNoteStripScenePromotesMainNaturalNoteStripAnswerSurface
            ),
            ExerciseCompositionValidationFixture(
                name: "accessory_scene_nodes_follow_presentation_strategy",
                validate: validateAccessorySceneNodesFollowPresentationStrategy
            ),
            ExerciseCompositionValidationFixture(
                name: "staff_to_piano_skips_legacy_back_projection",
                validate: validateStaffToPianoSkipsLegacyBackProjection
            ),
            ExerciseCompositionValidationFixture(
                name: "staff_to_natural_note_strip_skips_legacy_back_projection",
                validate: validateStaffToNaturalNoteStripSkipsLegacyBackProjection
            ),
            ExerciseCompositionValidationFixture(
                name: "sr_modes_freeze_staff_to_piano_policy_contracts",
                validate: validateSRModesFreezeStaffToPianoPolicyContracts
            ),
            ExerciseCompositionValidationFixture(
                name: "sr0_mode_freezes_staff_to_natural_note_strip_policy_contracts",
                validate:
                    validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts
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
                name: "scene_validator_restricts_vertical_rail_to_horizontal_split",
                validate: validateSceneValidatorRestrictsVerticalRailToHorizontalSplit
            ),
            ExerciseCompositionValidationFixture(
                name: "viewport_pinning_contracts_preserve_rail_and_stacked_layouts",
                validate: validateViewportPinningContractsPreserveRailAndStackedLayouts
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
}

extension ExerciseCompositionValidationRunner {
    static func manualChecklist(
        for platform: ExerciseCompositionValidationPlatform
    ) -> [String] {
        var checklist = [
            "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
            "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合；其中 `stacked` 底部 `horizontalStrip` 合同在方案一中固定对应“上半音、下自然音”的双行语义。",
            "确认把 `Layout Preset` 切到 `Side` 后，主视觉立即切成左右双栏，而不是被自动打回 `Stacked`。",
            "确认 `positionPrompt + Side` 在 `fretboardToNaturalNoteStrip` 组合下呈现为左 `fretboard`、右竖排 `natural note strip`；右侧 strip 继续走 `verticalRail` 语义，不会被底部 `horizontalStrip` 合同覆盖。",
            "确认在 `positionPrompt` 里切到 `Composition Preset = Self` 后，页面收敛为单 `fretboard`，并且 settings 重新打开后该选择仍然保留。",
            "确认 stacked/side 的 `positionPrompt` 里，只有当前 answer surface 会响应答题；prompt-only 的 `fretboard` 点击不会误触发答题。",
            "确认单 `fretboard` 自答时，点击同音位置会走统一 answer router，并在正确反馈结束后推进到下一题。",
            "确认打开 settings 只改变 card 可见性，不会重置当前 trainer mode、page layout 或 `pianoAccessoryVisible`。",
            "确认关闭 settings 后页面恢复到关闭前的 prompt/answer 组合，不会闪回 `PageDisplayState.default`。",
            "确认 `positionPrompt` 下方的 `natural note strip` 不再被拉伸到超出首屏；无需向下滚动就能看见按钮文字。",
            "确认右侧 rail 场景下，首屏无需额外滚动就能同时看到完整 `fretboard` 高度与竖排 `natural note strip` 按钮列。",
            "确认切回 stacked 后，`natural note strip` 仍保持底部 `horizontalStrip` 合同，不会被错误保留成右侧 `verticalRail`。",
            "确认右侧 rail 场景中的 `natural note strip` 继续可以答题，答对/答错反馈和题目推进逻辑不变。",
            "确认 `Piano Accessory Visible` 默认关闭；打开后会按当前 `Accessory Presentation` 进入 docked / floating / collapsible scene，关闭后主 prompt/answer 组合不发生漂移。",
            "确认在 `single/sequence` 下打开 `Natural Strip Visible` 时，strip 会作为 accessory surface 参与布局，但不会抢走 answer surface 角色。",
            "确认 `Collapsible` accessory 收起时，隐藏的 accessory 不可见也不可交互；重新展开后恢复到原来的 surface。",
            "确认 `single/sequence + Side` 未投影 `natural note strip` 时，scene membership 仍为 absent，而 renderer/controller/router 只把它当作有效 `.hidden`，不会误判为混入布局。",
            "确认 `stacked + vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 或 `side` 后该滑块消失，切回 `stacked + vertical` 后沿用上次值。",
            "确认切到 `SR-0` 后主视觉稳定收敛到 `treble staff + 双行 natural note strip`，strip 答错会给五线谱错误反馈、答对会推进到下一题。",
            "确认切到 `SR-1` 后主视觉稳定收敛到 `treble staff + 单行 piano`，不会再把 `piano accessory` 或 legacy page 投影混回主场景。",
            "确认切到 `SR-2` 后主视觉稳定收敛到 `treble staff + 两行 piano`，并继续使用主场景 piano 作为 answer surface，不会把 `piano accessory` 或 legacy page 投影混回主场景。",
            "确认在 `SR-0 / SR-1 / SR-2` 之间互切，再切回非 SR 模式时，不会残留 sequence 高亮、strip / piano 旧答案缓存，answer surface 交互状态也会随模式正确清理。"
        ]

        switch platform {
        case .iOS:
            checklist.append("在 iOS 上确认打开/关闭 settings、显示/隐藏钢琴后，scroll view 位置与触摸命中不会跳变。")
            checklist.append("在 iOS 上确认右侧 rail 场景开启 viewport pin 后，不会因为内容高度漂移而把竖排音名条或左侧指板推出首屏。")
        case .macOS:
            checklist.append("在 macOS 上确认 live resize、打开/关闭 settings、显示/隐藏钢琴后，主布局不会闪回到错误组合。")
            checklist.append("在 macOS 上确认 live resize 过程中，右侧 rail 仍保持左右同高且首屏完整可见，不会把 `natural note strip` 或 `fretboard` 撑出 viewport。")
        case .commandLine:
            checklist.append("命令行只能覆盖 shared 夹具；其中 `SR-1 / SR-2` 的 `staffToPiano` family 合同会被自动化锁住，但实际视觉与答题反馈仍需在 App 运行时手工回归。")
        }

        return checklist
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

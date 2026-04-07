//
//  PianoValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import Foundation

enum PianoValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct PianoValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct PianoValidationReport {
    var platform: PianoValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [PianoValidationIssue]
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
        [PianoValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum PianoValidationRunner {
    static func run(platform: PianoValidationPlatform) -> PianoValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [PianoValidationIssue] = []
        print("[PianoValidation][\(platform.displayName)] begin fixtures=\(fixtures.count)")

        for fixture in fixtures {
            print("[PianoValidation][\(platform.displayName)] fixture begin name=\(fixture.name)")
            let fixtureIssues = validate(fixture)
            print(
                "[PianoValidation][\(platform.displayName)] fixture end name=\(fixture.name) issues=\(fixtureIssues.count)"
            )
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        print("[PianoValidation][\(platform.displayName)] end totalIssues=\(issues.count)")

        return PianoValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: PianoValidationPlatform) {
        #if DEBUG
        print("[PianoValidation][\(platform.displayName)] runAndReportIfNeeded begin")
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)
        print("[PianoValidation][\(platform.displayName)] runAndReportIfNeeded end passing=\(report.isPassing)")

        if !report.isPassing {
            assertionFailure(summary)
        }
        #endif
    }
}

private struct PianoValidationFixture {
    var name: String
    var validate: () -> [PianoValidationIssue]
}

private extension PianoValidationRunner {
    static func validate(_ fixture: PianoValidationFixture) -> [PianoValidationIssue] {
        fixture.validate()
    }

    static func makeFixtures() -> [PianoValidationFixture] {
        [
            PianoValidationFixture(
                name: "configuration_resolves_safe_metrics",
                validate: validateConfigurationResolvesSafeMetrics
            ),
            PianoValidationFixture(
                name: "piano_panel_visibility_defaults_hidden",
                validate: validatePianoPanelVisibilityDefaults
            ),
            PianoValidationFixture(
                name: "piano_panel_state_infers_and_clamps_supported_values",
                validate: validatePianoPanelStateInferenceAndClamp
            ),
            PianoValidationFixture(
                name: "piano_panel_projection_resolves_rows_and_configuration",
                validate: validatePianoPanelProjectionResolution
            ),
            PianoValidationFixture(
                name: "accidental_start_note_is_preserved",
                validate: validateAccidentalStartNote
            ),
            PianoValidationFixture(
                name: "component_state_supports_mixed_scopes",
                validate: validateComponentStateSupportsMixedScopes
            ),
            PianoValidationFixture(
                name: "scale_drag_interaction_preserves_parallel_rows",
                validate: validateScaleDragInteraction
            ),
            PianoValidationFixture(
                name: "semantic_events_keep_preview_payload",
                validate: validateSemanticEvents
            ),
            PianoValidationFixture(
                name: "hit_result_maps_button_direction",
                validate: validateHitResultButtonDirection
            ),
            PianoValidationFixture(
                name: "scene_row_frames_and_zones_are_stable",
                validate: validateSceneRowFramesAndZones
            ),
            PianoValidationFixture(
                name: "scale_markers_are_natural_only",
                validate: validateScaleMarkersUseNaturalNotesOnly
            ),
            PianoValidationFixture(
                name: "accidental_anchor_aligns_start_note_left_edge",
                validate: validateAccidentalAnchorAlignment
            ),
            PianoValidationFixture(
                name: "keys_hit_test_prioritizes_black_keys",
                validate: validateHitTestPrioritizesBlackKeys
            ),
            PianoValidationFixture(
                name: "snap_target_and_normalization_follow_note_edges",
                validate: validateSnapTargetAndNormalization
            ),
            PianoValidationFixture(
                name: "active_zone_tracking_respects_locked_mode",
                validate: validateActiveZoneTracking
            ),
            PianoValidationFixture(
                name: "button_press_lifecycle_tracks_inside_state",
                validate: validateButtonPressLifecycle
            ),
            PianoValidationFixture(
                name: "button_step_emits_rows_transition_on_finish",
                validate: validateButtonStepEmitsRowsTransitionOnFinish
            ),
            PianoValidationFixture(
                name: "button_transition_preserves_row_only_and_cascade_targets",
                validate: validateButtonStepPropagation
            ),
            PianoValidationFixture(
                name: "button_transition_interrupt_materializes_current_frame",
                validate: validateButtonTransitionInterruptMaterialization
            ),
            PianoValidationFixture(
                name: "scale_drag_updates_rows_and_emits_snap_animation_on_finish",
                validate: validateScaleDragLifecycle
            ),
            PianoValidationFixture(
                name: "scale_snap_presentation_interpolates_anchor_positions",
                validate: validateScaleSnapPresentationInterpolation
            ),
            PianoValidationFixture(
                name: "button_transition_reuses_shared_anchor_interpolation",
                validate: validateButtonTransitionPresentationInterpolation
            ),
            PianoValidationFixture(
                name: "scale_drag_exit_does_not_switch_into_key_preview",
                validate: validateScaleDragExitDoesNotStartPreview
            ),
            PianoValidationFixture(
                name: "key_glissando_emits_preview_lifecycle",
                validate: validateKeyGlissandoLifecycle
            ),
            PianoValidationFixture(
                name: "multi_pointer_key_previews_coexist_and_end_independently",
                validate: validateMultiPointerKeyPreviews
            ),
            PianoValidationFixture(
                name: "control_interactions_remain_exclusive_against_key_previews",
                validate: validateControlInteractionExclusivity
            ),
            PianoValidationFixture(
                name: "keyboard_layer_uses_one_row_layer_per_row",
                validate: validateKeyboardLayerUsesOneRowLayerPerRow
            ),
            PianoValidationFixture(
                name: "keyboard_layer_routes_visual_state_to_rows",
                validate: validateKeyboardLayerRoutesVisualStateToRows
            ),
            PianoValidationFixture(
                name: "keyboard_layer_flip_normalization_preserves_top_left_layout",
                validate: validateKeyboardLayerFlipNormalization
            )
        ]
    }

    static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
        [
            "在 \(platform.displayName) 上确认 A 区按钮按下/抬起高亮与步进触发边界一致，且点击左 / 右后键盘会以短动画移动而不是瞬时跳变。",
            "确认 A 区按钮在 rowOnly 下只移动当前行，在 cascade 下会让所有联动行同步移动。",
            "确认连续快速点击 A 区左 / 右按钮时，每次都会从当前可见中间帧继续，不会反跳到旧终点。",
            "确认按钮动画播放期间切换设置、改行数或外部覆盖 rows 时，不会残留 presentation override 或出现视觉错位。",
            "确认 B 区连续拖动离开区域后会立即停止；开启吸附时应先保留连续位置，再以短动画收口到最近锚点。",
            "确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。",
            "确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
            "确认 `Piano Accessory Visible` 默认关闭；打开后才出现钢琴区域，关闭后会恢复主内容底边约束而不是改变 prompt/answer 主组合。",
            "确认钢琴组件保持“根 layer + 每行一个 row layer”，不存在按键级拆层或隐式动画。",
            "确认 macOS 归一化后顶行仍显示在最上方，A/B/C 区命中与 iOS 保持一致。"
        ]
    }
}

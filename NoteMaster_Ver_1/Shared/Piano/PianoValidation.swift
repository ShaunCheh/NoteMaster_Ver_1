//
//  PianoValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import Foundation
import CoreGraphics
import QuartzCore

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
            "确认 `Piano Visible` 默认关闭；打开后才出现钢琴区域，关闭后会恢复主内容底边约束而不是改变 prompt/answer 主组合。",
            "确认钢琴组件保持“根 layer + 每行一个 row layer”，不存在按键级拆层或隐式动画。",
            "确认 macOS 归一化后顶行仍显示在最上方，A/B/C 区命中与 iOS 保持一致。"
        ]
    }

    static func validateConfigurationResolvesSafeMetrics() -> [PianoValidationIssue] {
        let fixtureName = "configuration_resolves_safe_metrics"
        let configuration = PianoConfiguration(
            whiteKeyWidth: -8,
            rowHeight: -12,
            rowSpacing: -4,
            scaleAreaHeight: 18,
            buttonAreaWidth: -6,
            blackKeyWidthRatio: 3,
            blackKeyHeightRatio: 0.05,
            snapEnabled: false
        )
        var issues: [PianoValidationIssue] = []

        if configuration.resolvedWhiteKeyWidth != 1 {
            issues.append(issue(fixtureName, "resolvedWhiteKeyWidth 应钳制为 1。"))
        }
        if configuration.resolvedRowHeight != 1 {
            issues.append(issue(fixtureName, "resolvedRowHeight 应钳制为 1。"))
        }
        if configuration.resolvedRowSpacing != 0 {
            issues.append(issue(fixtureName, "resolvedRowSpacing 应钳制为 0。"))
        }
        if configuration.resolvedScaleAreaHeight != 1 {
            issues.append(issue(fixtureName, "resolvedScaleAreaHeight 不应超过 resolvedRowHeight。"))
        }
        if configuration.resolvedButtonStripHeight != 0 {
            issues.append(issue(fixtureName, "当 scaleAreaHeight 已吃满整行时，buttonStripHeight 应退化为 0。"))
        }
        if configuration.keyAreaHeight != 0 {
            issues.append(issue(fixtureName, "当顶部区域吃满整行时，keyAreaHeight 应为 0。"))
        }
        if configuration.resolvedButtonAreaWidth != 0 {
            issues.append(issue(fixtureName, "resolvedButtonAreaWidth 应钳制为 0。"))
        }
        if configuration.resolvedBlackKeyWidthRatio != PianoConfiguration.blackKeyWidthRatioRange.upperBound {
            issues.append(issue(fixtureName, "blackKeyWidthRatio 应钳制到上界。"))
        }
        if configuration.resolvedBlackKeyHeightRatio != PianoConfiguration.blackKeyHeightRatioRange.lowerBound {
            issues.append(issue(fixtureName, "blackKeyHeightRatio 应钳制到下界。"))
        }

        return issues
    }

    static func validatePianoPanelVisibilityDefaults() -> [PianoValidationIssue] {
        let fixtureName = "piano_panel_visibility_defaults_hidden"
        let defaultState = PianoPanelState()
        let inferredState = PianoPanelState.inferred(
            configuration: PianoConfiguration(),
            rows: []
        )
        var settingsStateContext = SettingsPanelStateContext(
            pianoPanelState: defaultState
        )
        var issues: [PianoValidationIssue] = []

        if defaultState.isVisible {
            issues.append(issue(fixtureName, "PianoPanelState() 默认应继续保持 isVisible=false。"))
        }
        if inferredState.isVisible {
            issues.append(issue(fixtureName, "PianoPanelState.inferred(...) 默认应继续保持 isVisible=false。"))
        }
        if SettingsToggleID.pianoVisible.resolvedValue(in: settingsStateContext) {
            issues.append(issue(fixtureName, "settings snapshot 的 Piano Visible 默认不应回显为开启。"))
        }

        SettingsToggleID.pianoVisible.apply(value: true, to: &settingsStateContext)
        if !settingsStateContext.pianoPanelState.isVisible {
            issues.append(issue(fixtureName, "Piano Visible toggle 写回后应把 pianoPanelState.isVisible 置为 true。"))
        }
        if !SettingsToggleID.pianoVisible.resolvedValue(in: settingsStateContext) {
            issues.append(issue(fixtureName, "Piano Visible toggle 写回后应继续在 settings snapshot 中回显为开启。"))
        }

        return issues
    }

    static func validatePianoPanelStateInferenceAndClamp() -> [PianoValidationIssue] {
        let fixtureName = "piano_panel_state_infers_and_clamps_supported_values"
        let inferred = PianoPanelState.inferred(
            configuration: PianoConfiguration(
                whiteKeyStyle: .skeuomorphicHighlight,
                snapEnabled: false
            ),
            rows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 5),
                    movementScope: .rowOnly
                ),
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 4),
                    movementScope: .cascade
                )
            ]
        )
        let oversized = PianoPanelState(
            isVisible: false,
            rowCount: 99,
            movementScope: .cascade,
            snapEnabled: true
        )
        var issues: [PianoValidationIssue] = []

        if inferred.rowCount != 2 {
            issues.append(issue(fixtureName, "inferred rowCount 应保留当前 rows.count。"))
        }
        if inferred.isVisible {
            issues.append(issue(fixtureName, "inferred panel state 默认不应直接把钢琴标记为可见。"))
        }
        if inferred.movementScope != .rowOnly {
            issues.append(issue(fixtureName, "inferred movementScope 应沿用首行 movementScope。"))
        }
        if inferred.whiteKeyStyle != .skeuomorphicHighlight {
            issues.append(issue(fixtureName, "inferred whiteKeyStyle 应沿用 configuration.whiteKeyStyle。"))
        }
        if inferred.snapEnabled {
            issues.append(issue(fixtureName, "inferred snapEnabled 应沿用 configuration.snapEnabled。"))
        }
        if oversized.resolvedRowCount != PianoPanelState.supportedRowCountRange.upperBound {
            issues.append(issue(fixtureName, "resolvedRowCount 应钳制到 supportedRowCountRange 上界。"))
        }

        return issues
    }

    static func validatePianoPanelProjectionResolution() -> [PianoValidationIssue] {
        let fixtureName = "piano_panel_projection_resolves_rows_and_configuration"
        let baseConfiguration = PianoConfiguration(
            whiteKeyWidth: 32,
            rowHeight: 96,
            rowSpacing: 10,
            scaleAreaHeight: 28,
            buttonAreaWidth: 30,
            blackKeyWidthRatio: 0.62,
            blackKeyHeightRatio: 0.6,
            whiteKeyStyle: .outlined,
            snapEnabled: true
        )
        let baseRows = [
            PianoRowState(
                startNote: NotePitch(pitchClass: .c, octave: 5),
                offsetX: 18,
                movementScope: .rowOnly
            ),
            PianoRowState(
                startNote: NotePitch(pitchClass: .c, octave: 4),
                offsetX: 18,
                movementScope: .rowOnly
            )
        ]
        let panelState = PianoPanelState(
            isVisible: false,
            rowCount: 4,
            movementScope: .cascade,
            whiteKeyStyle: .skeuomorphicHighlight,
            snapEnabled: false
        )
        let resolvedConfiguration = PianoPanelProjection.resolvedConfiguration(
            from: baseConfiguration,
            panelState: panelState
        )
        let resolvedRows = PianoPanelProjection.resolvedRows(
            from: baseRows,
            panelState: panelState
        )
        let fallbackRows = PianoPanelProjection.resolvedRows(
            from: [],
            panelState: PianoPanelState(
                rowCount: 2,
                movementScope: .rowOnly
            )
        )
        var issues: [PianoValidationIssue] = []

        if resolvedConfiguration.snapEnabled {
            issues.append(issue(fixtureName, "panel projection 应允许单独关闭 snapEnabled。"))
        }
        if resolvedConfiguration.whiteKeyStyle != .skeuomorphicHighlight {
            issues.append(issue(fixtureName, "panel projection 应允许单独切换 whiteKeyStyle。"))
        }
        if resolvedConfiguration.whiteKeyWidth != baseConfiguration.whiteKeyWidth
            || resolvedConfiguration.rowHeight != baseConfiguration.rowHeight {
            issues.append(issue(fixtureName, "panel projection 不应意外改动除 snapEnabled / whiteKeyStyle 外的 configuration 字段。"))
        }
        if resolvedRows.count != 4 {
            issues.append(issue(fixtureName, "rowCount 扩容后应返回 4 行。"))
        }
        if resolvedRows.contains(where: { $0.movementScope != .cascade }) {
            issues.append(issue(fixtureName, "projection 应统一覆盖所有行的 movementScope。"))
        }
        if resolvedRows.map(\.offsetX) != [18, 18, 18, 18] {
            issues.append(issue(fixtureName, "projection 扩容时应保留既有 offsetX 对齐。"))
        }
        if resolvedRows.map(\.startNote) != [
            NotePitch(pitchClass: .c, octave: 5),
            NotePitch(pitchClass: .c, octave: 4),
            NotePitch(pitchClass: .c, octave: 3),
            NotePitch(pitchClass: .c, octave: 2)
        ] {
            issues.append(issue(fixtureName, "projection 扩容时应按每次 -12 semitones 追加新行。"))
        }
        if fallbackRows.map(\.startNote) != [
            NotePitch(pitchClass: .c, octave: 4),
            NotePitch(pitchClass: .c, octave: 3)
        ] {
            issues.append(issue(fixtureName, "空 rows 输入时应退化生成 C4 开始的默认行。"))
        }
        if fallbackRows.contains(where: { $0.movementScope != .rowOnly }) {
            issues.append(issue(fixtureName, "空 rows fallback 也应继承 panel 的 movementScope。"))
        }

        return issues
    }

    static func validateAccidentalStartNote() -> [PianoValidationIssue] {
        let fixtureName = "accidental_start_note_is_preserved"
        let row = PianoRowState(
            startNote: NotePitch(pitchClass: .fSharp, octave: 4),
            movementScope: .cascade
        )
        var issues: [PianoValidationIssue] = []

        if !row.startNote.pitchClass.isAccidental {
            issues.append(issue(fixtureName, "黑键起始音应被保留为变化音。"))
        }
        if row.startNote.displayText() != "F#4" {
            issues.append(issue(fixtureName, "起始音显示文本应保持 F#4。"))
        }
        if row.movementScope != .cascade {
            issues.append(issue(fixtureName, "movementScope 应保留为 cascade。"))
        }
        if row.offsetX != 0 {
            issues.append(issue(fixtureName, "默认 offsetX 应为 0。"))
        }

        return issues
    }

    static func validateComponentStateSupportsMixedScopes() -> [PianoValidationIssue] {
        let fixtureName = "component_state_supports_mixed_scopes"
        let state = PianoComponentState(
            rows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 5),
                    movementScope: .rowOnly
                ),
                PianoRowState(
                    startNote: NotePitch(pitchClass: .gSharp, octave: 4),
                    offsetX: 18,
                    movementScope: .cascade
                )
            ]
        )
        var issues: [PianoValidationIssue] = []

        if state.rowCount != 2 {
            issues.append(issue(fixtureName, "rowCount 应为 2。"))
        }
        if state.isPreviewing {
            issues.append(issue(fixtureName, "未设置 preview 时不应处于预览态。"))
        }
        if state.rowState(at: 0)?.movementScope != .rowOnly {
            issues.append(issue(fixtureName, "第 0 行应保持 rowOnly。"))
        }
        if state.rowState(at: 1)?.movementScope != .cascade {
            issues.append(issue(fixtureName, "第 1 行应保持 cascade。"))
        }
        if state.rowState(at: 2) != nil {
            issues.append(issue(fixtureName, "越界 rowState 查询应返回 nil。"))
        }

        return issues
    }

    static func validateScaleDragInteraction() -> [PianoValidationIssue] {
        let fixtureName = "scale_drag_interaction_preserves_parallel_rows"
        let interaction = PianoScaleDragInteraction(
            rowIndex: 1,
            movementScope: .cascade,
            beganLocationInView: CGPoint(x: 24, y: 12),
            affectedRowIndices: [0, 1],
            initialOffsetsX: [0, 36]
        )
        let interactionState = PianoInteractionState.scaleDrag(interaction)
        var issues: [PianoValidationIssue] = []

        if !interaction.hasConsistentAffectedRows {
            issues.append(issue(fixtureName, "affectedRowIndices 与 initialOffsetsX 长度应一致。"))
        }
        if interactionState.rowIndex != 1 {
            issues.append(issue(fixtureName, "interactionState.rowIndex 应回落到 drag 所在行。"))
        }
        if interaction.movementScope != .cascade {
            issues.append(issue(fixtureName, "scaleDrag 应保留 cascade 语义。"))
        }

        return issues
    }

    static func validateSemanticEvents() -> [PianoValidationIssue] {
        let fixtureName = "semantic_events_keep_preview_payload"
        let preview = PianoPreviewState(
            rowIndex: 0,
            note: NotePitch(pitchClass: .aSharp, octave: 3)
        )
        let rows = [
            PianoRowState(
                startNote: NotePitch(pitchClass: .dSharp, octave: 5),
                movementScope: .cascade
            )
        ]
        let events: [PianoSemanticEvent] = [
            .rowsChanged(rows),
            .previewStarted(preview),
            .previewChanged(preview),
            .previewEnded(preview)
        ]
        var issues: [PianoValidationIssue] = []

        guard case let .rowsChanged(updatedRows) = events[0] else {
            return [issue(fixtureName, "第一个语义事件应为 rowsChanged。")]
        }
        if updatedRows.first?.startNote != rows.first?.startNote {
            issues.append(issue(fixtureName, "rowsChanged 应保留 rows 载荷。"))
        }

        for event in events.dropFirst() {
            switch event {
            case let .previewStarted(value),
                 let .previewChanged(value),
                 let .previewEnded(value):
                if value != preview {
                    issues.append(issue(fixtureName, "\(event.debugName) 应保留 preview 载荷。"))
                }
            case .rowsChanged:
                issues.append(issue(fixtureName, "非首个事件不应再次出现 rowsChanged。"))
            }
        }

        return issues
    }

    static func validateHitResultButtonDirection() -> [PianoValidationIssue] {
        let fixtureName = "hit_result_maps_button_direction"
        let hit = PianoHitResult(
            phase: .ended,
            locationInView: CGPoint(x: 18, y: 9),
            rowIndex: 0,
            zone: .buttonRight,
            note: nil,
            isInsideActiveZone: true
        )
        var issues: [PianoValidationIssue] = []

        if hit.buttonDirection != .right {
            issues.append(issue(fixtureName, "buttonRight 应映射到 right direction。"))
        }
        if !hit.hasRowHit {
            issues.append(issue(fixtureName, "button hit 应带上 rowIndex。"))
        }
        if hit.hasNoteHit {
            issues.append(issue(fixtureName, "按钮命中不应附带 note。"))
        }

        return issues
    }

    static func validateSceneRowFramesAndZones() -> [PianoValidationIssue] {
        let fixtureName = "scene_row_frames_and_zones_are_stable"
        let configuration = PianoConfiguration(
            whiteKeyWidth: 40,
            rowHeight: 100,
            rowSpacing: 8,
            scaleAreaHeight: 20,
            buttonAreaWidth: 30
        )
        let state = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4)),
                PianoRowState(startNote: NotePitch(pitchClass: .fSharp, octave: 3))
            ]
        )
        let geometry = PianoGeometry(
            configuration: configuration,
            state: state,
            bounds: CGRect(x: 0, y: 0, width: 320, height: 260)
        )
        var issues: [PianoValidationIssue] = []

        guard let firstRow = geometry.rowScene(at: 0),
              let secondRow = geometry.rowScene(at: 1) else {
            return [issue(fixtureName, "应能构建出两个 row scene。")]
        }

        if firstRow.frame != CGRect(x: 0, y: 0, width: 320, height: 100) {
            issues.append(issue(fixtureName, "第一行 frame 与 rowHeight 不一致。"))
        }
        if secondRow.frame != CGRect(x: 0, y: 108, width: 320, height: 100) {
            issues.append(issue(fixtureName, "第二行 frame 应包含 rowSpacing 位移。"))
        }
        if firstRow.controlStripRect != CGRect(x: 0, y: 0, width: 320, height: 40) {
            issues.append(issue(fixtureName, "顶部控制区总 rect 应覆盖独立的 A/B 两条区域。"))
        }
        if firstRow.buttonStripRect != CGRect(x: 0, y: 0, width: 320, height: 20) {
            issues.append(issue(fixtureName, "A 区按钮条 rect 计算不正确。"))
        }
        if firstRow.buttonLeftRect != CGRect(x: 0, y: 0, width: 30, height: 20) {
            issues.append(issue(fixtureName, "左按钮区域 rect 计算不正确。"))
        }
        if firstRow.buttonRightRect != CGRect(x: 290, y: 0, width: 30, height: 20) {
            issues.append(issue(fixtureName, "右按钮区域 rect 计算不正确。"))
        }
        if firstRow.scaleRect != CGRect(x: 0, y: 20, width: 320, height: 20) {
            issues.append(issue(fixtureName, "刻度区域 rect 计算不正确。"))
        }
        if firstRow.keysRect != CGRect(x: 0, y: 40, width: 320, height: 60) {
            issues.append(issue(fixtureName, "琴键区域 rect 计算不正确。"))
        }
        if geometry.scene.contentRect.height != 208 {
            issues.append(issue(fixtureName, "contentRect.height 应等于所有行高与间距之和。"))
        }

        return issues
    }

    static func validateScaleMarkersUseNaturalNotesOnly() -> [PianoValidationIssue] {
        let fixtureName = "scale_markers_are_natural_only"
        let geometry = PianoGeometry(
            configuration: PianoConfiguration(
                whiteKeyWidth: 40,
                rowHeight: 110,
                rowSpacing: 0,
                scaleAreaHeight: 24,
                buttonAreaWidth: 24
            ),
            state: PianoComponentState(
                rows: [
                    PianoRowState(
                        startNote: NotePitch(pitchClass: .cSharp, octave: 4)
                    )
                ]
            ),
            bounds: CGRect(x: 0, y: 0, width: 300, height: 110)
        )
        var issues: [PianoValidationIssue] = []

        guard let rowScene = geometry.rowScene(at: 0) else {
            return [issue(fixtureName, "应能构建 row scene。")]
        }
        if rowScene.scaleMarkers.isEmpty {
            issues.append(issue(fixtureName, "刻度区域应生成自然音 markers。"))
        }
        if !rowScene.scaleMarkers.allSatisfy({ $0.note.pitchClass.isNatural }) {
            issues.append(issue(fixtureName, "scaleMarkers 只应包含自然音。"))
        }
        if rowScene.scaleMarkers.contains(where: { $0.note.pitchClass == .cSharp }) {
            issues.append(issue(fixtureName, "scaleMarkers 不应直接包含黑键起始音自身。"))
        }

        return issues
    }

    static func validateAccidentalAnchorAlignment() -> [PianoValidationIssue] {
        let fixtureName = "accidental_anchor_aligns_start_note_left_edge"
        let startNote = NotePitch(pitchClass: .fSharp, octave: 4)
        let geometry = PianoGeometry(
            configuration: PianoConfiguration(
                whiteKeyWidth: 42,
                rowHeight: 120,
                rowSpacing: 0,
                scaleAreaHeight: 24,
                buttonAreaWidth: 24
            ),
            state: PianoComponentState(
                rows: [
                    PianoRowState(startNote: startNote)
                ]
            ),
            bounds: CGRect(x: 0, y: 0, width: 320, height: 120)
        )
        var issues: [PianoValidationIssue] = []

        guard let rowScene = geometry.rowScene(at: 0),
              let startRect = rowScene.noteRect(for: startNote) else {
            return [issue(fixtureName, "应能命中黑键起始音的 rect。")]
        }

        if abs(startRect.minX - rowScene.keysRect.minX) > 0.001 {
            issues.append(issue(fixtureName, "黑键起始音在 offsetX=0 时应与 keysRect 左边界对齐。"))
        }

        return issues
    }

    static func validateHitTestPrioritizesBlackKeys() -> [PianoValidationIssue] {
        let fixtureName = "keys_hit_test_prioritizes_black_keys"
        let configuration = PianoConfiguration(
            whiteKeyWidth: 40,
            rowHeight: 120,
            rowSpacing: 0,
            scaleAreaHeight: 24,
            buttonAreaWidth: 24
        )
        let geometry = PianoGeometry(
            configuration: configuration,
            state: PianoComponentState(
                rows: [
                    PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
                ]
            ),
            bounds: CGRect(x: 0, y: 0, width: 320, height: 120)
        )
        var issues: [PianoValidationIssue] = []

        guard let rowScene = geometry.rowScene(at: 0),
              let cSharpRect = rowScene.noteRect(for: NotePitch(pitchClass: .cSharp, octave: 4)) else {
            return [issue(fixtureName, "应能得到 C#4 的黑键 rect。")]
        }

        let blackHit = geometry.hitTest(
            CGPoint(x: cSharpRect.midX, y: cSharpRect.midY),
            phase: .began
        )
        if blackHit.zone != .keys || blackHit.note != NotePitch(pitchClass: .cSharp, octave: 4) {
            issues.append(issue(fixtureName, "黑键区域命中应优先返回 C#4。"))
        }

        let whitePoint = CGPoint(
            x: rowScene.keysRect.minX + 10,
            y: rowScene.keysRect.maxY - 10
        )
        let whiteHit = geometry.hitTest(whitePoint, phase: .began)
        if whiteHit.note != NotePitch(pitchClass: .c, octave: 4) {
            issues.append(issue(fixtureName, "白键下半区命中应返回 C4。"))
        }

        return issues
    }

    static func validateSnapTargetAndNormalization() -> [PianoValidationIssue] {
        let fixtureName = "snap_target_and_normalization_follow_note_edges"
        let configuration = PianoConfiguration(whiteKeyWidth: 40)
        let rowState = PianoRowState(
            startNote: NotePitch(pitchClass: .c, octave: 4),
            offsetX: 40,
            movementScope: .cascade
        )
        let geometry = PianoGeometry(
            configuration: configuration,
            state: PianoComponentState(rows: [rowState]),
            bounds: CGRect(x: 0, y: 0, width: 240, height: 120)
        )
        let snapTarget = geometry.nearestSnapTarget(for: rowState)
        let normalized = geometry.normalizedSnappedRowState(rowState)
        var issues: [PianoValidationIssue] = []

        if snapTarget.note != NotePitch(pitchClass: .d, octave: 4) {
            issues.append(issue(fixtureName, "offsetX 等于一个白键宽时，应吸附到 D4。"))
        }
        if abs(snapTarget.offsetX - 40) > 0.001 {
            issues.append(issue(fixtureName, "D4 的 snap offset 应为一个白键宽。"))
        }
        if normalized.startNote != NotePitch(pitchClass: .d, octave: 4) || normalized.offsetX != 0 {
            issues.append(issue(fixtureName, "normalizedSnappedRowState 应把锚点前移到 D4 且 offsetX 归零。"))
        }
        if normalized.movementScope != .cascade {
            issues.append(issue(fixtureName, "归一化后应保留 movementScope。"))
        }

        return issues
    }

    static func validateActiveZoneTracking() -> [PianoValidationIssue] {
        let fixtureName = "active_zone_tracking_respects_locked_mode"
        let scaleDrag = PianoScaleDragInteraction(
            rowIndex: 0,
            movementScope: .rowOnly,
            beganLocationInView: CGPoint(x: 60, y: 10),
            affectedRowIndices: [0],
            initialOffsetsX: [0]
        )
        let state = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
            ],
            activeInteraction: .scaleDrag(scaleDrag)
        )
        let geometry = PianoGeometry(
            configuration: PianoConfiguration(
                whiteKeyWidth: 40,
                rowHeight: 120,
                rowSpacing: 0,
                scaleAreaHeight: 24,
                buttonAreaWidth: 24
            ),
            state: state,
            bounds: CGRect(x: 0, y: 0, width: 320, height: 120)
        )
        var issues: [PianoValidationIssue] = []

        guard let rowScene = geometry.rowScene(at: 0) else {
            return [issue(fixtureName, "应能构建 row scene。")]
        }

        let scaleHit = geometry.hitTest(
            CGPoint(x: rowScene.scaleRect.midX, y: rowScene.scaleRect.midY),
            phase: .moved
        )
        if !scaleHit.isInsideActiveZone {
            issues.append(issue(fixtureName, "scale drag 在原刻度区内移动时应保持 insideActiveZone。"))
        }

        let keyHit = geometry.hitTest(
            CGPoint(x: rowScene.keysRect.midX, y: rowScene.keysRect.midY),
            phase: .moved
        )
        if keyHit.isInsideActiveZone {
            issues.append(issue(fixtureName, "scale drag 进入 keys 区后不应继续视为 insideActiveZone。"))
        }

        return issues
    }

    static func validateButtonPressLifecycle() -> [PianoValidationIssue] {
        let fixtureName = "button_press_lifecycle_tracks_inside_state"
        let state = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
            ]
        )
        let beganReduction = PianoInteractionReducer.reduce(
            state: state,
            rawEvent: PianoRawEvent(
                phase: .began,
                locationInView: CGPoint(x: 12, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .began,
                locationInView: CGPoint(x: 12, y: 10),
                rowIndex: 0,
                zone: .buttonRight,
                note: nil,
                isInsideActiveZone: true
            ),
            configuration: PianoConfiguration()
        )
        var issues: [PianoValidationIssue] = []

        guard case let .buttonPressed(interaction)? = beganReduction.nextState.activeInteraction else {
            return [issue(fixtureName, "began 命中按钮后应建立 buttonPressed 交互。")]
        }
        if interaction.direction != .right || interaction.rowIndex != 0 {
            issues.append(issue(fixtureName, "buttonPressed 交互应保留正确的 rowIndex 和 direction。"))
        }
        if !beganReduction.needsDisplay || !beganReduction.semanticEvents.isEmpty {
            issues.append(issue(fixtureName, "按钮 began 应触发重绘，但不应产生语义事件。"))
        }

        let movedReduction = PianoInteractionReducer.reduce(
            state: beganReduction.nextState,
            rawEvent: PianoRawEvent(
                phase: .moved,
                locationInView: CGPoint(x: 180, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .moved,
                locationInView: CGPoint(x: 180, y: 10),
                rowIndex: nil,
                zone: .outside,
                note: nil,
                isInsideActiveZone: false
            ),
            configuration: PianoConfiguration()
        )

        guard case let .buttonPressed(updatedInteraction)? = movedReduction.nextState.activeInteraction else {
            issues.append(issue(fixtureName, "按钮 moved 到外部后仍应保留 buttonPressed 交互。"))
            return issues
        }
        if updatedInteraction.isTrackingInsideButton {
            issues.append(issue(fixtureName, "按钮 moved 到外部后 isTrackingInsideButton 应为 false。"))
        }

        return issues
    }

    static func validateButtonStepEmitsRowsTransitionOnFinish() -> [PianoValidationIssue] {
        let fixtureName = "button_step_emits_rows_transition_on_finish"
        let state = PianoComponentState(
            rows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 4),
                    movementScope: .rowOnly
                )
            ],
            activeInteraction: .buttonPressed(
                PianoButtonPressInteraction(
                    rowIndex: 0,
                    direction: .right,
                    movementScope: .rowOnly
                )
            )
        )
        let reduction = PianoInteractionReducer.reduce(
            state: state,
            rawEvent: PianoRawEvent(
                phase: .ended,
                locationInView: CGPoint(x: 12, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .ended,
                locationInView: CGPoint(x: 12, y: 10),
                rowIndex: 0,
                zone: .buttonRight,
                note: nil,
                isInsideActiveZone: true
            ),
            configuration: PianoConfiguration()
        )
        let expectedRows = [
            PianoRowState(
                startNote: NotePitch(pitchClass: .cSharp, octave: 4),
                movementScope: .rowOnly
            )
        ]
        var issues: [PianoValidationIssue] = []

        if reduction.nextState.rows != state.rows {
            issues.append(issue(fixtureName, "按钮 ended 时不应立即提交最终 rows。"))
        }
        if reduction.nextState.activeInteraction != nil {
            issues.append(issue(fixtureName, "按钮 ended 后应清空 activeInteraction。"))
        }
        if !reduction.semanticEvents.isEmpty {
            issues.append(issue(fixtureName, "按钮 ended 后不应立即发出 rowsChanged，应该等动画完成时再发。"))
        }
        if !reduction.needsDisplay {
            issues.append(issue(fixtureName, "按钮 ended 后输出过渡命令时应要求刷新显示。"))
        }
        guard let plan = reduction.presentationCommand?.rowsTransitionPlan else {
            issues.append(issue(fixtureName, "按钮 ended 后应输出 rows transition plan。"))
            return issues
        }
        if plan.fromRows != state.rows {
            issues.append(issue(fixtureName, "按钮 plan 的 fromRows 应等于结束时的当前 logical rows。"))
        }
        if plan.toRows != expectedRows {
            issues.append(issue(fixtureName, "按钮 plan 的 toRows 应等于按钮步进后的目标 rows。"))
        }
        if plan.affectedRowIndices != [0] {
            issues.append(issue(fixtureName, "单行 rowOnly 按钮 plan 应只覆盖第 0 行。"))
        }
        if abs(plan.duration - PianoRowsTransitionPlan.defaultDuration) > 0.0001 {
            issues.append(issue(fixtureName, "按钮 plan 应沿用默认 rows transition 时长。"))
        }

        return issues
    }

    static func validateButtonStepPropagation() -> [PianoValidationIssue] {
        let fixtureName = "button_transition_preserves_row_only_and_cascade_targets"
        var issues: [PianoValidationIssue] = []

        let rowOnlyState = PianoComponentState(
            rows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 4),
                    movementScope: .rowOnly
                ),
                PianoRowState(
                    startNote: NotePitch(pitchClass: .g, octave: 3),
                    movementScope: .rowOnly
                )
            ],
            activeInteraction: .buttonPressed(
                PianoButtonPressInteraction(
                    rowIndex: 0,
                    direction: .right,
                    movementScope: .rowOnly
                )
            )
        )
        let rowOnlyReduction = PianoInteractionReducer.reduce(
            state: rowOnlyState,
            rawEvent: PianoRawEvent(
                phase: .ended,
                locationInView: CGPoint(x: 12, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .ended,
                locationInView: CGPoint(x: 12, y: 10),
                rowIndex: 0,
                zone: .buttonRight,
                note: nil,
                isInsideActiveZone: true
            ),
            configuration: PianoConfiguration()
        )
        let expectedRowOnlyRows = [
            PianoRowState(
                startNote: NotePitch(pitchClass: .cSharp, octave: 4),
                movementScope: .rowOnly
            ),
            PianoRowState(
                startNote: NotePitch(pitchClass: .g, octave: 3),
                movementScope: .rowOnly
            )
        ]
        if rowOnlyReduction.nextState.rows != rowOnlyState.rows {
            issues.append(issue(fixtureName, "rowOnly 按钮结束时，reducer 不应立即提交最终 rows。"))
        }
        if rowOnlyReduction.nextState.activeInteraction != nil {
            issues.append(issue(fixtureName, "按钮结束后应清空 activeInteraction。"))
        }
        if !rowOnlyReduction.semanticEvents.isEmpty {
            issues.append(issue(fixtureName, "rowOnly 按钮结束时不应立即发出 rowsChanged，应该等动画完成后再发。"))
        }
        guard let rowOnlyPlan = rowOnlyReduction.presentationCommand?.rowsTransitionPlan else {
            issues.append(issue(fixtureName, "rowOnly 模式下按钮结束后应输出 rows transition plan。"))
            return issues
        }
        if rowOnlyPlan.fromRows != rowOnlyState.rows {
            issues.append(issue(fixtureName, "rowOnly plan 的 fromRows 应等于按钮结束前的当前 rows。"))
        }
        if rowOnlyPlan.toRows != expectedRowOnlyRows {
            issues.append(issue(fixtureName, "rowOnly plan 的 toRows 应只推进当前行到 C#4。"))
        }
        if rowOnlyPlan.affectedRowIndices != [0] {
            issues.append(issue(fixtureName, "rowOnly plan 应只覆盖触发行。"))
        }

        let cascadeState = PianoComponentState(
            rows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 4),
                    movementScope: .cascade
                ),
                PianoRowState(
                    startNote: NotePitch(pitchClass: .g, octave: 3),
                    movementScope: .rowOnly
                )
            ],
            activeInteraction: .buttonPressed(
                PianoButtonPressInteraction(
                    rowIndex: 0,
                    direction: .left,
                    movementScope: .cascade
                )
            )
        )
        let cascadeReduction = PianoInteractionReducer.reduce(
            state: cascadeState,
            rawEvent: PianoRawEvent(
                phase: .ended,
                locationInView: CGPoint(x: 4, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .ended,
                locationInView: CGPoint(x: 4, y: 10),
                rowIndex: 0,
                zone: .buttonLeft,
                note: nil,
                isInsideActiveZone: true
            ),
            configuration: PianoConfiguration()
        )
        let expectedCascadeRows = [
            PianoRowState(
                startNote: NotePitch(pitchClass: .b, octave: 3),
                movementScope: .cascade
            ),
            PianoRowState(
                startNote: NotePitch(pitchClass: .fSharp, octave: 3),
                movementScope: .rowOnly
            )
        ]
        if cascadeReduction.nextState.rows != cascadeState.rows {
            issues.append(issue(fixtureName, "cascade 按钮结束时，reducer 不应立即提交最终 rows。"))
        }
        if cascadeReduction.nextState.activeInteraction != nil {
            issues.append(issue(fixtureName, "cascade 按钮结束后应清空 activeInteraction。"))
        }
        if !cascadeReduction.semanticEvents.isEmpty {
            issues.append(issue(fixtureName, "cascade 按钮结束时也不应立即发出 rowsChanged。"))
        }
        guard let cascadePlan = cascadeReduction.presentationCommand?.rowsTransitionPlan else {
            issues.append(issue(fixtureName, "cascade 模式下按钮结束后应输出 rows transition plan。"))
            return issues
        }
        if cascadePlan.fromRows != cascadeState.rows {
            issues.append(issue(fixtureName, "cascade plan 的 fromRows 应等于按钮结束前的当前 rows。"))
        }
        if cascadePlan.toRows != expectedCascadeRows {
            issues.append(issue(fixtureName, "cascade plan 的 toRows 应让所有受影响行同步左移一个半音。"))
        }
        if cascadePlan.affectedRowIndices != [0, 1] {
            issues.append(issue(fixtureName, "cascade plan 应覆盖所有受影响行。"))
        }

        return issues
    }

    static func validateButtonTransitionInterruptMaterialization() -> [PianoValidationIssue] {
        let fixtureName = "button_transition_interrupt_materializes_current_frame"
        let configuration = PianoConfiguration(whiteKeyWidth: 40)
        let fromRows = [
            PianoRowState(
                startNote: NotePitch(pitchClass: .c, octave: 4),
                movementScope: .rowOnly
            )
        ]
        let toRows = [
            PianoRowState(
                startNote: NotePitch(pitchClass: .cSharp, octave: 4),
                movementScope: .rowOnly
            )
        ]
        let layer = PianoKeyboardLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 320, height: 120)
        layer.contentsScale = 2
        layer.configuration = configuration
        layer.state = PianoComponentState(rows: fromRows)
        layer.refreshForCurrentBounds()

        var completedRows: [PianoRowState]?
        layer.startRowsTransitionAnimation(
            PianoRowsTransitionPlan(
                fromRows: fromRows,
                toRows: toRows,
                affectedRowIndices: [0]
            )
        ) { finalRows in
            completedRows = finalRows
        }

        Thread.sleep(forTimeInterval: 0.03)
        let materializedRows = layer.cancelRowsTransitionAnimation(
            materializeCurrentFrame: true
        )
        defer {
            layer.clearRowsTransitionPresentationOverride()
        }

        var issues: [PianoValidationIssue] = []
        guard let materializedRows,
              let materializedRow = materializedRows.first else {
            issues.append(issue(fixtureName, "按钮过渡被打断时，应能物化出当前中间帧 rows。"))
            return issues
        }

        if completedRows != nil {
            issues.append(issue(fixtureName, "中断按钮过渡时不应提前触发完成回调。"))
        }
        if materializedRow.startNote != fromRows[0].startNote {
            issues.append(issue(fixtureName, "中间帧物化结果应保留 fromRow.startNote 作为渲染参考锚点。"))
        }
        if materializedRow.movementScope != .rowOnly {
            issues.append(issue(fixtureName, "中间帧物化结果应保留目标 movementScope。"))
        }

        let fromAnchorX = PianoLayoutMath.noteLeadingX(
            fromRows[0].startNote,
            configuration: configuration
        ) + fromRows[0].offsetX
        let toAnchorX = PianoLayoutMath.noteLeadingX(
            toRows[0].startNote,
            configuration: configuration
        ) + toRows[0].offsetX
        let currentAnchorX = PianoLayoutMath.noteLeadingX(
            materializedRow.startNote,
            configuration: configuration
        ) + materializedRow.offsetX
        let minAnchorX = min(fromAnchorX, toAnchorX)
        let maxAnchorX = max(fromAnchorX, toAnchorX)

        if currentAnchorX < minAnchorX || currentAnchorX > maxAnchorX {
            issues.append(issue(fixtureName, "中间帧物化结果的 anchorX 应位于 from / to 两端之间。"))
        }
        if abs(currentAnchorX - fromAnchorX) <= 0.001
            || abs(currentAnchorX - toAnchorX) <= 0.001 {
            issues.append(issue(fixtureName, "等待一小段时间后物化按钮过渡，结果应处于中间帧而不是任一端点。"))
        }
        if layer.cancelRowsTransitionAnimation(materializeCurrentFrame: true) != nil {
            issues.append(issue(fixtureName, "按钮过渡已被取消后，不应继续返回新的物化 rows。"))
        }

        return issues
    }

    static func validateScaleDragLifecycle() -> [PianoValidationIssue] {
        let fixtureName = "scale_drag_updates_rows_and_emits_snap_animation_on_finish"
        let configuration = PianoConfiguration(whiteKeyWidth: 40, snapEnabled: true)
        let initialState = PianoComponentState(
            rows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 4),
                    movementScope: .cascade
                ),
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 3),
                    movementScope: .rowOnly
                )
            ]
        )
        var issues: [PianoValidationIssue] = []

        let beganReduction = PianoInteractionReducer.reduce(
            state: initialState,
            rawEvent: PianoRawEvent(
                phase: .began,
                locationInView: CGPoint(x: 60, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .began,
                locationInView: CGPoint(x: 60, y: 10),
                rowIndex: 0,
                zone: .scale,
                note: NotePitch(pitchClass: .c, octave: 4),
                isInsideActiveZone: true
            ),
            configuration: configuration
        )
        guard case let .scaleDrag(interaction)? = beganReduction.nextState.activeInteraction else {
            return [issue(fixtureName, "scale began 后应建立 scaleDrag 交互。")]
        }
        if interaction.affectedRowIndices != [0, 1] {
            issues.append(issue(fixtureName, "cascade 模式下 scaleDrag 应影响所有行。"))
        }

        let movedReduction = PianoInteractionReducer.reduce(
            state: beganReduction.nextState,
            rawEvent: PianoRawEvent(
                phase: .moved,
                locationInView: CGPoint(x: 100, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .moved,
                locationInView: CGPoint(x: 100, y: 10),
                rowIndex: 0,
                zone: .scale,
                note: NotePitch(pitchClass: .d, octave: 4),
                isInsideActiveZone: true
            ),
            configuration: configuration
        )
        if movedReduction.nextState.rows[0].offsetX != -40
            || movedReduction.nextState.rows[1].offsetX != -40 {
            issues.append(issue(fixtureName, "scale moved 后应按指针位移反向更新受影响行 offsetX。"))
        }
        if movedReduction.semanticEvents != [.rowsChanged(movedReduction.nextState.rows)] {
            issues.append(issue(fixtureName, "scale moved 后应产生 rowsChanged。"))
        }

        let endedReduction = PianoInteractionReducer.reduce(
            state: movedReduction.nextState,
            rawEvent: PianoRawEvent(
                phase: .ended,
                locationInView: CGPoint(x: 100, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .ended,
                locationInView: CGPoint(x: 100, y: 10),
                rowIndex: 0,
                zone: .scale,
                note: NotePitch(pitchClass: .d, octave: 4),
                isInsideActiveZone: true
            ),
            configuration: configuration
        )
        let expectedFinalRows = movedReduction.nextState.rows
        if endedReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .c, octave: 4)
            || endedReduction.nextState.rows[0].offsetX != -40 {
            issues.append(issue(fixtureName, "吸附动画开始前，第一行应先保留连续拖动后的 C4 / offsetX=-40 位置。"))
        }
        if endedReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .c, octave: 4)
            || endedReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .c, octave: 3)
            || endedReduction.nextState.rows[1].offsetX != -40 {
            issues.append(issue(fixtureName, "吸附动画开始前，cascade 行也应保留拖动结束时的连续位置。"))
        }
        if endedReduction.nextState.activeInteraction != nil {
            issues.append(issue(fixtureName, "scale drag 结束后应清空 activeInteraction。"))
        }
        if !endedReduction.semanticEvents.isEmpty {
            issues.append(issue(fixtureName, "结束位置与上一次 moved 一致时，不应额外发出 rowsChanged。"))
        }
        guard case let .animateScaleSnap(plan)? = endedReduction.presentationCommand else {
            issues.append(issue(fixtureName, "snapEnabled 开启时，scale 结束后应输出 animateScaleSnap 命令。"))
            return issues
        }
        if plan.fromRows != expectedFinalRows {
            issues.append(issue(fixtureName, "snap plan 的 fromRows 应等于拖动结束时的连续 rows。"))
        }
        if plan.toRows[0].startNote != NotePitch(pitchClass: .b, octave: 3)
            || plan.toRows[0].offsetX != 0 {
            issues.append(issue(fixtureName, "snap plan 第一行终点应归一化到 B3 且 offsetX 为 0。"))
        }
        if plan.toRows[1].startNote != NotePitch(pitchClass: .b, octave: 2)
            || plan.toRows[1].offsetX != 0 {
            issues.append(issue(fixtureName, "snap plan 第二行终点也应同步归一化到 B2。"))
        }
        if plan.affectedRowIndices != [0, 1] {
            issues.append(issue(fixtureName, "cascade 吸附动画应覆盖所有受影响行。"))
        }
        if plan.duration < 0.10 || plan.duration > 0.12 {
            issues.append(issue(fixtureName, "snap plan 时长应保持在 0.10 到 0.12 秒范围内。"))
        }

        return issues
    }

    static func validateScaleSnapPresentationInterpolation() -> [PianoValidationIssue] {
        let fixtureName = "scale_snap_presentation_interpolates_anchor_positions"
        let configuration = PianoConfiguration(whiteKeyWidth: 40)
        let plan = PianoScaleSnapAnimationPlan(
            fromRows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 4),
                    offsetX: -40,
                    movementScope: .cascade
                )
            ],
            toRows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .b, octave: 3),
                    offsetX: 0,
                    movementScope: .cascade
                )
            ],
            affectedRowIndices: [0]
        )
        var issues: [PianoValidationIssue] = []

        let startRows = PianoPresentationMath.rows(
            for: plan,
            progress: 0,
            configuration: configuration
        )
        let middleRows = PianoPresentationMath.rows(
            for: plan,
            progress: 0.5,
            configuration: configuration
        )
        let endRows = PianoPresentationMath.rows(
            for: plan,
            progress: 1,
            configuration: configuration
        )

        if startRows != plan.fromRows {
            issues.append(issue(fixtureName, "progress=0 时应返回原始连续位置。"))
        }
        if endRows != plan.toRows {
            issues.append(issue(fixtureName, "progress=1 时应返回最终 snap 目标。"))
        }

        let expectedMiddleProgress = PianoPresentationMath.easeOutCubic(0.5)
        let fromAnchorX = PianoLayoutMath.noteLeadingX(
            plan.fromRows[0].startNote,
            configuration: configuration
        ) + plan.fromRows[0].offsetX
        let toAnchorX = PianoLayoutMath.noteLeadingX(
            plan.toRows[0].startNote,
            configuration: configuration
        ) + plan.toRows[0].offsetX
        let expectedMiddleAnchorX = fromAnchorX
            + ((toAnchorX - fromAnchorX) * expectedMiddleProgress)
        let actualMiddleAnchorX = PianoLayoutMath.noteLeadingX(
            middleRows[0].startNote,
            configuration: configuration
        ) + middleRows[0].offsetX

        if middleRows[0].startNote != plan.fromRows[0].startNote {
            issues.append(issue(fixtureName, "插值过程中应保留 fromRow 的 startNote 作为渲染参考锚点。"))
        }
        if abs(actualMiddleAnchorX - expectedMiddleAnchorX) > 0.001 {
            issues.append(issue(fixtureName, "progress=0.5 时应按 easeOutCubic 在 from / to anchorX 之间插值。"))
        }
        if middleRows[0].movementScope != .cascade {
            issues.append(issue(fixtureName, "插值后的 row 应保留目标 movementScope。"))
        }

        return issues
    }

    static func validateButtonTransitionPresentationInterpolation() -> [PianoValidationIssue] {
        let fixtureName = "button_transition_reuses_shared_anchor_interpolation"
        let configuration = PianoConfiguration(whiteKeyWidth: 40)
        let plan = PianoRowsTransitionPlan(
            fromRows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .c, octave: 4),
                    movementScope: .rowOnly
                ),
                PianoRowState(
                    startNote: NotePitch(pitchClass: .g, octave: 3),
                    movementScope: .rowOnly
                )
            ],
            toRows: [
                PianoRowState(
                    startNote: NotePitch(pitchClass: .cSharp, octave: 4),
                    movementScope: .rowOnly
                ),
                PianoRowState(
                    startNote: NotePitch(pitchClass: .g, octave: 3),
                    movementScope: .rowOnly
                )
            ],
            affectedRowIndices: [0]
        )
        var issues: [PianoValidationIssue] = []

        let startRows = PianoPresentationMath.rows(
            for: plan,
            progress: 0,
            configuration: configuration
        )
        let middleRows = PianoPresentationMath.rows(
            for: plan,
            progress: 0.5,
            configuration: configuration
        )
        let endRows = PianoPresentationMath.rows(
            for: plan,
            progress: 1,
            configuration: configuration
        )

        if startRows != plan.fromRows {
            issues.append(issue(fixtureName, "按钮过渡 progress=0 时应返回按钮触发前的原始 rows。"))
        }
        if endRows != plan.toRows {
            issues.append(issue(fixtureName, "按钮过渡 progress=1 时应返回按钮步进后的目标 rows。"))
        }
        if middleRows[1] != plan.toRows[1] {
            issues.append(issue(fixtureName, "rowOnly 按钮过渡中，未受影响行应直接保持 toRows。"))
        }

        let expectedMiddleProgress = PianoPresentationMath.easeOutCubic(0.5)
        let fromAnchorX = PianoLayoutMath.noteLeadingX(
            plan.fromRows[0].startNote,
            configuration: configuration
        ) + plan.fromRows[0].offsetX
        let toAnchorX = PianoLayoutMath.noteLeadingX(
            plan.toRows[0].startNote,
            configuration: configuration
        ) + plan.toRows[0].offsetX
        let expectedMiddleAnchorX = fromAnchorX
            + ((toAnchorX - fromAnchorX) * expectedMiddleProgress)
        let actualMiddleAnchorX = PianoLayoutMath.noteLeadingX(
            middleRows[0].startNote,
            configuration: configuration
        ) + middleRows[0].offsetX

        if middleRows[0].startNote != plan.fromRows[0].startNote {
            issues.append(issue(fixtureName, "按钮过渡插值过程中也应保留 fromRow.startNote 作为渲染参考锚点。"))
        }
        if abs(actualMiddleAnchorX - expectedMiddleAnchorX) > 0.001 {
            issues.append(issue(fixtureName, "按钮过渡 progress=0.5 时应复用共享 anchor 插值，而不是单独使用另一套按钮数学。"))
        }
        if middleRows[0].movementScope != .rowOnly {
            issues.append(issue(fixtureName, "按钮过渡插值后的目标行应保留 movementScope。"))
        }

        return issues
    }

    static func validateScaleDragExitDoesNotStartPreview() -> [PianoValidationIssue] {
        let fixtureName = "scale_drag_exit_does_not_switch_into_key_preview"
        let state = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
            ],
            activeInteraction: .scaleDrag(
                PianoScaleDragInteraction(
                    rowIndex: 0,
                    movementScope: .rowOnly,
                    beganLocationInView: CGPoint(x: 60, y: 10),
                    affectedRowIndices: [0],
                    initialOffsetsX: [0]
                )
            )
        )
        let reduction = PianoInteractionReducer.reduce(
            state: state,
            rawEvent: PianoRawEvent(
                phase: .moved,
                locationInView: CGPoint(x: 80, y: 60)
            ),
            hitResult: PianoHitResult(
                phase: .moved,
                locationInView: CGPoint(x: 80, y: 60),
                rowIndex: 0,
                zone: .keys,
                note: NotePitch(pitchClass: .c, octave: 4),
                isInsideActiveZone: false
            ),
            configuration: PianoConfiguration(snapEnabled: false)
        )
        var issues: [PianoValidationIssue] = []

        if reduction.nextState.activeInteraction != nil {
            issues.append(issue(fixtureName, "离开 scale 区后应结束 scaleDrag 交互。"))
        }
        if reduction.nextState.preview != nil {
            issues.append(issue(fixtureName, "scaleDrag 离开到 keys 区时不应切换成 preview。"))
        }
        if reduction.semanticEvents.contains(where: { event in
            switch event {
            case .previewStarted, .previewChanged, .previewEnded:
                return true
            case .rowsChanged:
                return false
            }
        }) {
            issues.append(issue(fixtureName, "scaleDrag 退出时不应发出任何 preview 生命周期事件。"))
        }

        return issues
    }

    static func validateKeyGlissandoLifecycle() -> [PianoValidationIssue] {
        let fixtureName = "key_glissando_emits_preview_lifecycle"
        let initialState = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
            ]
        )
        var issues: [PianoValidationIssue] = []

        let beganReduction = PianoInteractionReducer.reduce(
            state: initialState,
            rawEvent: PianoRawEvent(
                phase: .began,
                locationInView: CGPoint(x: 30, y: 60)
            ),
            hitResult: PianoHitResult(
                phase: .began,
                locationInView: CGPoint(x: 30, y: 60),
                rowIndex: 0,
                zone: .keys,
                note: NotePitch(pitchClass: .c, octave: 4),
                isInsideActiveZone: true
            ),
            configuration: PianoConfiguration()
        )
        if beganReduction.semanticEvents != [.previewStarted(PianoPreviewState(
            rowIndex: 0,
            note: NotePitch(pitchClass: .c, octave: 4)
        ))] {
            issues.append(issue(fixtureName, "key began 后应发出 previewStarted(C4)。"))
        }

        let movedReduction = PianoInteractionReducer.reduce(
            state: beganReduction.nextState,
            rawEvent: PianoRawEvent(
                phase: .moved,
                locationInView: CGPoint(x: 70, y: 60)
            ),
            hitResult: PianoHitResult(
                phase: .moved,
                locationInView: CGPoint(x: 70, y: 60),
                rowIndex: 0,
                zone: .keys,
                note: NotePitch(pitchClass: .d, octave: 4),
                isInsideActiveZone: true
            ),
            configuration: PianoConfiguration()
        )
        if movedReduction.semanticEvents != [.previewChanged(PianoPreviewState(
            rowIndex: 0,
            note: NotePitch(pitchClass: .d, octave: 4)
        ))] {
            issues.append(issue(fixtureName, "glissando 移动到 D4 后应发出 previewChanged(D4)。"))
        }

        let endedReduction = PianoInteractionReducer.reduce(
            state: movedReduction.nextState,
            rawEvent: PianoRawEvent(
                phase: .ended,
                locationInView: CGPoint(x: 200, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .ended,
                locationInView: CGPoint(x: 200, y: 10),
                rowIndex: nil,
                zone: .outside,
                note: nil,
                isInsideActiveZone: false
            ),
            configuration: PianoConfiguration()
        )
        if endedReduction.nextState.preview != nil || endedReduction.nextState.activeInteraction != nil {
            issues.append(issue(fixtureName, "glissando 结束后应清空 preview 和 activeInteraction。"))
        }
        if endedReduction.semanticEvents != [.previewEnded(PianoPreviewState(
            rowIndex: 0,
            note: NotePitch(pitchClass: .d, octave: 4)
        ))] {
            issues.append(issue(fixtureName, "glissando 离开后应发出 previewEnded(D4)。"))
        }

        return issues
    }

    static func validateKeyboardLayerUsesOneRowLayerPerRow() -> [PianoValidationIssue] {
        let fixtureName = "keyboard_layer_uses_one_row_layer_per_row"
        let configuration = PianoConfiguration(
            whiteKeyWidth: 40,
            rowHeight: 88,
            rowSpacing: 10,
            scaleAreaHeight: 22,
            buttonAreaWidth: 28,
            whiteKeyStyle: .borderlessSeparatedByGaps
        )
        let state = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 5)),
                PianoRowState(startNote: NotePitch(pitchClass: .gSharp, octave: 4))
            ]
        )
        let layer = PianoKeyboardLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 320, height: 186)
        layer.contentsScale = 2
        layer.configuration = configuration
        layer.state = state
        layer.refreshForCurrentBounds()

        let expectedScene = PianoSceneBuilder(
            configuration: configuration,
            state: state
        ).makeScene(bounds: layer.bounds)
        let sublayers = layer.sublayers ?? []
        let rowLayers = sublayers.compactMap { $0 as? PianoRowLayer }
        var issues: [PianoValidationIssue] = []

        if sublayers.count != state.rowCount {
            issues.append(issue(fixtureName, "根 layer 下的直接子 layer 数量应等于 rowCount。"))
        }
        if rowLayers.count != state.rowCount {
            issues.append(issue(fixtureName, "所有直接子 layer 都应为 PianoRowLayer。"))
        }
        if rowLayers.count != expectedScene.rows.count {
            issues.append(issue(fixtureName, "row layer 数量应与 scene.rows 保持一致。"))
        }

        for (index, rowLayer) in rowLayers.enumerated() {
            guard expectedScene.rows.indices.contains(index) else {
                continue
            }

            let expectedRowScene = expectedScene.rows[index]
            if rowLayer.frame != expectedRowScene.frame {
                issues.append(issue(fixtureName, "第 \(index) 行 row layer frame 应与 scene row frame 对齐。"))
            }
            if rowLayer.scene.frame.origin != .zero {
                issues.append(issue(fixtureName, "第 \(index) 行 row scene 传入 row layer 前应已本地化到局部坐标。"))
            }
            if rowLayer.contentsScale != layer.contentsScale {
                issues.append(issue(fixtureName, "第 \(index) 行 row layer 应继承根 layer 的 contentsScale。"))
            }
            if rowLayer.configuration.whiteKeyStyle != configuration.whiteKeyStyle {
                issues.append(issue(fixtureName, "第 \(index) 行 row layer 应继承 configuration.whiteKeyStyle。"))
            }
        }

        return issues
    }

    static func validateKeyboardLayerRoutesVisualStateToRows() -> [PianoValidationIssue] {
        let fixtureName = "keyboard_layer_routes_visual_state_to_rows"
        let configuration = PianoConfiguration(
            whiteKeyWidth: 42,
            rowHeight: 90,
            rowSpacing: 8,
            scaleAreaHeight: 24,
            buttonAreaWidth: 30
        )
        let layer = PianoKeyboardLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 340, height: 188)
        layer.configuration = configuration

        let buttonPreviewState = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4)),
                PianoRowState(startNote: NotePitch(pitchClass: .f, octave: 3))
            ],
            preview: PianoPreviewState(
                rowIndex: 1,
                note: NotePitch(pitchClass: .g, octave: 3)
            ),
            activeInteraction: .buttonPressed(
                PianoButtonPressInteraction(
                    rowIndex: 0,
                    direction: .right,
                    movementScope: .rowOnly,
                    isTrackingInsideButton: true
                )
            )
        )
        layer.state = buttonPreviewState
        layer.refreshForCurrentBounds()

        var issues: [PianoValidationIssue] = []
        var rowLayers = (layer.sublayers ?? []).compactMap { $0 as? PianoRowLayer }

        if rowLayers.count != 2 {
            issues.append(issue(fixtureName, "初始双行状态下应存在两个 row layer。"))
            return issues
        }

        if rowLayers[0].renderState.referenceNote != NotePitch(pitchClass: .c, octave: 4) {
            issues.append(issue(fixtureName, "第 0 行 renderState 应携带本行 startNote 作为参考线音。"))
        }
        if rowLayers[0].renderState.activeButtonDirection != .right
            || !rowLayers[0].renderState.isButtonTrackingInside {
            issues.append(issue(fixtureName, "第 0 行应接收到按钮按下高亮状态。"))
        }
        if rowLayers[0].renderState.previewedNote != nil {
            issues.append(issue(fixtureName, "第 0 行不应错误继承其他行的 preview。"))
        }
        if rowLayers[1].renderState.previewedNote != NotePitch(pitchClass: .g, octave: 3) {
            issues.append(issue(fixtureName, "第 1 行应接收到自身的 preview 音。"))
        }
        if rowLayers[1].renderState.activeButtonDirection != nil {
            issues.append(issue(fixtureName, "第 1 行不应错误继承第 0 行的按钮高亮。"))
        }

        let scaleDragState = PianoComponentState(
            rows: buttonPreviewState.rows,
            activeInteraction: .scaleDrag(
                PianoScaleDragInteraction(
                    rowIndex: 0,
                    movementScope: .cascade,
                    beganLocationInView: CGPoint(x: 18, y: 10),
                    affectedRowIndices: [0, 1],
                    initialOffsetsX: [0, 0]
                )
            )
        )
        layer.state = scaleDragState
        layer.refreshForCurrentBounds()
        rowLayers = (layer.sublayers ?? []).compactMap { $0 as? PianoRowLayer }

        if rowLayers.count != 2 {
            issues.append(issue(fixtureName, "scaleDrag 状态下应继续保留双行 row layer。"))
        }
        if rowLayers.contains(where: { !$0.renderState.isScaleActive }) {
            issues.append(issue(fixtureName, "cascade scaleDrag 时所有受影响行都应进入 scale 高亮态。"))
        }

        let singleRowState = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .a, octave: 4))
            ]
        )
        layer.state = singleRowState
        layer.refreshForCurrentBounds()
        rowLayers = (layer.sublayers ?? []).compactMap { $0 as? PianoRowLayer }

        if rowLayers.count != 1 {
            issues.append(issue(fixtureName, "rows 缩减后，row layer 数量也应同步缩减。"))
        }
        if rowLayers.first?.renderState.referenceNote != NotePitch(pitchClass: .a, octave: 4) {
            issues.append(issue(fixtureName, "缩减到单行后，剩余 row layer 的参考音应同步刷新。"))
        }

        return issues
    }

    static func validateKeyboardLayerFlipNormalization() -> [PianoValidationIssue] {
        let fixtureName = "keyboard_layer_flip_normalization_preserves_top_left_layout"
        let configuration = PianoConfiguration(
            whiteKeyWidth: 40,
            rowHeight: 80,
            rowSpacing: 10,
            scaleAreaHeight: 20,
            buttonAreaWidth: 24
        )
        let state = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4)),
                PianoRowState(startNote: NotePitch(pitchClass: .f, octave: 3))
            ]
        )
        let layer = PianoKeyboardLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        layer.contextNormalizationMode = .flipYToTopLeft
        layer.configuration = configuration
        layer.state = state
        layer.refreshForCurrentBounds()

        let expectedScene = PianoSceneBuilder(
            configuration: configuration,
            state: state
        ).makeScene(bounds: layer.bounds)
        let rowLayers = (layer.sublayers ?? []).compactMap { $0 as? PianoRowLayer }
        var issues: [PianoValidationIssue] = []

        if rowLayers.count != expectedScene.rows.count {
            issues.append(issue(fixtureName, "flip normalization 下 row layer 数量应与 scene.rows 一致。"))
            return issues
        }

        let samplePoint = CGPoint(x: 12, y: 18)
        let normalizedPoint = PianoContextNormalizationMode.flipYToTopLeft.normalizedPoint(
            samplePoint,
            in: layer.bounds
        )
        if normalizedPoint != CGPoint(x: samplePoint.x, y: layer.bounds.maxY - samplePoint.y) {
            issues.append(issue(fixtureName, "normalizedPoint 应把 bottom-left 点位翻转到 Shared 的 top-left 语义。"))
        }

        for (index, rowLayer) in rowLayers.enumerated() {
            let expectedFrame = PianoContextNormalizationMode.flipYToTopLeft.normalizedRect(
                expectedScene.rows[index].frame,
                in: layer.bounds
            )
            if rowLayer.frame != expectedFrame {
                issues.append(issue(fixtureName, "第 \(index) 行 row layer frame 应按 flipYToTopLeft 规则翻转。"))
            }
            if rowLayer.contextNormalizationMode != .flipYToTopLeft {
                issues.append(issue(fixtureName, "第 \(index) 行 row layer 应继承 flipYToTopLeft 归一化模式。"))
            }
        }

        if rowLayers[0].frame.minY <= rowLayers[1].frame.minY {
            issues.append(issue(fixtureName, "翻转后第 0 行应位于更靠上的图层位置。"))
        }

        return issues
    }

    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> PianoValidationIssue {
        PianoValidationIssue(fixtureName: fixtureName, message: message)
    }
}

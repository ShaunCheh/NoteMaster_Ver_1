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
                name: "button_step_updates_row_only_and_cascade_rows",
                validate: validateButtonStepPropagation
            ),
            PianoValidationFixture(
                name: "scale_drag_updates_rows_and_snaps_on_finish",
                validate: validateScaleDragLifecycle
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
            )
        ]
    }

    static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
        [
            "在 \(platform.displayName) 上确认 A 区按钮按下/抬起高亮与步进触发边界一致。",
            "确认 B 区连续拖动离开区域后会立即停止，且吸附开关开闭语义正确。",
            "确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。",
            "确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
            "确认钢琴组件保持“根 layer + 每行一个 row layer”，不存在按键级拆层或隐式动画。"
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
        if firstRow.buttonLeftRect != CGRect(x: 0, y: 0, width: 30, height: 20) {
            issues.append(issue(fixtureName, "左按钮区域 rect 计算不正确。"))
        }
        if firstRow.buttonRightRect != CGRect(x: 290, y: 0, width: 30, height: 20) {
            issues.append(issue(fixtureName, "右按钮区域 rect 计算不正确。"))
        }
        if firstRow.scaleRect != CGRect(x: 30, y: 0, width: 260, height: 20) {
            issues.append(issue(fixtureName, "刻度区域 rect 计算不正确。"))
        }
        if firstRow.keysRect != CGRect(x: 0, y: 20, width: 320, height: 80) {
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

    static func validateButtonStepPropagation() -> [PianoValidationIssue] {
        let fixtureName = "button_step_updates_row_only_and_cascade_rows"
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
        if rowOnlyReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .cSharp, octave: 4) {
            issues.append(issue(fixtureName, "rowOnly 模式下当前行应前进一步到 C#4。"))
        }
        if rowOnlyReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .g, octave: 3) {
            issues.append(issue(fixtureName, "rowOnly 模式下其他行不应被修改。"))
        }
        if rowOnlyReduction.nextState.activeInteraction != nil {
            issues.append(issue(fixtureName, "按钮结束后应清空 activeInteraction。"))
        }
        if rowOnlyReduction.semanticEvents != [.rowsChanged(rowOnlyReduction.nextState.rows)] {
            issues.append(issue(fixtureName, "rowOnly 步进后应产生 rowsChanged 事件。"))
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
        if cascadeReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .b, octave: 3) {
            issues.append(issue(fixtureName, "cascade 模式下触发行应左移一个半音到 B3。"))
        }
        if cascadeReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .fSharp, octave: 3) {
            issues.append(issue(fixtureName, "cascade 模式下其他行也应同步左移一个半音到 F#3。"))
        }

        return issues
    }

    static func validateScaleDragLifecycle() -> [PianoValidationIssue] {
        let fixtureName = "scale_drag_updates_rows_and_snaps_on_finish"
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
        if movedReduction.nextState.rows[0].offsetX != 40
            || movedReduction.nextState.rows[1].offsetX != 40 {
            issues.append(issue(fixtureName, "scale moved 后应按 deltaX 同步更新受影响行 offsetX。"))
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
        if endedReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .d, octave: 4)
            || endedReduction.nextState.rows[0].offsetX != 0 {
            issues.append(issue(fixtureName, "snapEnabled 开启时，第一行结束后应归一化到 D4 且 offsetX 为 0。"))
        }
        if endedReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .d, octave: 3)
            || endedReduction.nextState.rows[1].offsetX != 0 {
            issues.append(issue(fixtureName, "cascade 结束时第二行也应归一化到 D3。"))
        }
        if endedReduction.nextState.activeInteraction != nil {
            issues.append(issue(fixtureName, "scale drag 结束后应清空 activeInteraction。"))
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
            buttonAreaWidth: 28
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

    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> PianoValidationIssue {
        PianoValidationIssue(fixtureName: fixtureName, message: message)
    }
}

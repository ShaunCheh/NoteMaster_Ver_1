//
//  PianoValidationConfigurationAndProjection.swift
//  NoteMaster_Ver_1
//
//  Configuration, panel state, projection, and row/component invariants.
//

import Foundation

extension PianoValidationRunner {
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
        if SettingsToggleID.pianoAccessoryVisible.resolvedValue(in: settingsStateContext) {
            issues.append(issue(fixtureName, "settings snapshot 的 Piano Accessory Visible 默认不应回显为开启。"))
        }

        SettingsToggleID.pianoAccessoryVisible.apply(
            value: true,
            to: &settingsStateContext
        )
        if !settingsStateContext.pianoPanelState.isVisible {
            issues.append(issue(fixtureName, "Piano Accessory Visible toggle 写回后应把 pianoPanelState.isVisible 置为 true。"))
        }
        if !SettingsToggleID.pianoAccessoryVisible.resolvedValue(in: settingsStateContext) {
            issues.append(issue(fixtureName, "Piano Accessory Visible toggle 写回后应继续在 settings snapshot 中回显为开启。"))
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
}

//
//  PianoValidation.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import Foundation
import CoreGraphics

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
            )
        ]
    }

    static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
        [
            "在 \(platform.displayName) 上确认 A 区按钮按下/抬起高亮与步进触发边界一致。",
            "确认 B 区连续拖动离开区域后会立即停止，且吸附开关开闭语义正确。",
            "确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。"
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

    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> PianoValidationIssue {
        PianoValidationIssue(fixtureName: fixtureName, message: message)
    }
}

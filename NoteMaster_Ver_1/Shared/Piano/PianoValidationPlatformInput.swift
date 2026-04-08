//
//  PianoValidationPlatformInput.swift
//  NoteMaster_Ver_1
//
//  Platform input pointer session tracking and host-side cleanup semantics.
//

import CoreGraphics
import Foundation

extension PianoValidationRunner {
    static func validatePointerSessionTrackerKeepsIDsStableAndMonotonic() -> [PianoValidationIssue] {
        enum TestSource: Hashable {
            case primary
            case secondary
            case tertiary
        }

        let fixtureName = "pointer_session_tracker_keeps_ids_stable_and_monotonic"
        var tracker = PianoPointerSessionTracker<TestSource>()
        var issues: [PianoValidationIssue] = []

        guard let beganPrimary = tracker.begin(
            source: .primary,
            locationInView: CGPoint(x: 12, y: 18)
        ) else {
            return [issue(fixtureName, "primary began 应建立 pointer session。")]
        }
        guard let beganSecondary = tracker.begin(
            source: .secondary,
            locationInView: CGPoint(x: 40, y: 22)
        ) else {
            return [issue(fixtureName, "secondary began 应建立第二个独立 pointer session。")]
        }

        if beganPrimary.pointerID == beganSecondary.pointerID {
            issues.append(issue(fixtureName, "不同 source 的 began 不应复用同一个 pointerID。"))
        }
        if tracker.activePointerIDs != Set([beganPrimary.pointerID, beganSecondary.pointerID]) {
            issues.append(issue(fixtureName, "tracker 应同时保留两个活动 pointer。"))
        }

        guard let movedPrimary = tracker.move(
            source: .primary,
            locationInView: CGPoint(x: 16, y: 20)
        ) else {
            issues.append(issue(fixtureName, "已建立的 primary pointer 在 moved 时应继续产出 raw event。"))
            return issues
        }
        if movedPrimary.pointerID != beganPrimary.pointerID {
            issues.append(issue(fixtureName, "同一 source 的 moved 必须复用 began 时分配的 pointerID。"))
        }

        tracker.retainSessions(withPointerIDs: [beganPrimary.pointerID])
        if tracker.session(for: .secondary) != nil {
            issues.append(issue(fixtureName, "retainSessions 后，被裁掉的 secondary pointer 不应继续滞留。"))
        }
        if tracker.end(source: .secondary) != nil {
            issues.append(issue(fixtureName, "已被 prune 的 secondary source 不应再产生 ended raw event。"))
        }

        guard let beganTertiary = tracker.begin(
            source: .tertiary,
            locationInView: CGPoint(x: 72, y: 30)
        ) else {
            issues.append(issue(fixtureName, "新 source 在 prune 之后仍应能重新建立 pointer session。"))
            return issues
        }
        if beganTertiary.pointerID.rawValue <= beganSecondary.pointerID.rawValue {
            issues.append(issue(fixtureName, "新分配的 pointerID 应保持单调递增，避免复用旧 pointer 身份。"))
        }

        guard let endedPrimary = tracker.end(source: .primary) else {
            issues.append(issue(fixtureName, "仍然活动的 primary pointer 在 ended 时应产出 raw event。"))
            return issues
        }
        if endedPrimary.pointerID != beganPrimary.pointerID {
            issues.append(issue(fixtureName, "primary ended 必须命中最初建立的 pointerID。"))
        }

        return issues
    }

    static func validateRowReplacementAndResetClearAllPointerSessions() -> [PianoValidationIssue] {
        let fixtureName = "row_replacement_and_reset_clear_all_pointer_sessions"
        let pointerA = PianoPointerID(rawValue: 41)
        let pointerB = PianoPointerID(rawValue: 42)
        let previewA = PianoPreviewState(
            previewID: pointerA.previewID,
            rowIndex: 0,
            note: NotePitch(pitchClass: .c, octave: 4)
        )
        let previewB = PianoPreviewState(
            previewID: pointerB.previewID,
            rowIndex: 1,
            note: NotePitch(pitchClass: .g, octave: 3)
        )
        let detachedPreview = PianoPreviewState(
            previewID: PianoPreviewID(rawValue: 99),
            rowIndex: 0,
            note: NotePitch(pitchClass: .e, octave: 4)
        )
        let state = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4)),
                PianoRowState(startNote: NotePitch(pitchClass: .f, octave: 3))
            ],
            activePreviews: [
                previewA.previewID: previewA,
                previewB.previewID: previewB,
                detachedPreview.previewID: detachedPreview
            ],
            activeInteractionsByPointer: [
                pointerA: .keyGlissando(
                    PianoKeyGlissandoInteraction(
                        pointerID: pointerA,
                        rowIndex: 0,
                        currentPreview: previewA
                    )
                ),
                pointerB: .keyGlissando(
                    PianoKeyGlissandoInteraction(
                        pointerID: pointerB,
                        rowIndex: 1,
                        currentPreview: previewB
                    )
                )
            ]
        )

        let sanitizedState = state.replacingRowsBySanitizingInputSessions(
            with: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
            ]
        )
        var issues: [PianoValidationIssue] = []

        if sanitizedState.preview(for: previewA.previewID) != previewA {
            issues.append(issue(fixtureName, "仍落在合法 row 的 pointerA preview 不应在 rows 替换时被误删。"))
        }
        if sanitizedState.preview(for: previewB.previewID) != nil {
            issues.append(issue(fixtureName, "超出 rowCount 的 pointerB preview 应在 rows 替换时被清掉。"))
        }
        if sanitizedState.preview(for: detachedPreview.previewID) != detachedPreview {
            issues.append(issue(fixtureName, "合法的 preview-only 状态不应因为 rows 替换被误删。"))
        }
        if sanitizedState.interaction(for: pointerA) == nil {
            issues.append(issue(fixtureName, "仍然合法的 pointerA key interaction 应被保留。"))
        }
        if sanitizedState.interaction(for: pointerB) != nil {
            issues.append(issue(fixtureName, "超出 rowCount 的 pointerB interaction 应被移除。"))
        }

        var clearedState = sanitizedState
        let clearedPreviews = clearedState.clearInputSessions()
        if clearedPreviews != [previewA, detachedPreview] {
            issues.append(issue(fixtureName, "clearInputSessions 应返回所有活动 preview，而不是只返回兼容单值 preview。"))
        }
        if !clearedState.activePreviews.isEmpty || !clearedState.activeInteractionsByPointer.isEmpty {
            issues.append(issue(fixtureName, "clearInputSessions 之后不应残留活动 preview 或 interaction。"))
        }

        return issues
    }
}

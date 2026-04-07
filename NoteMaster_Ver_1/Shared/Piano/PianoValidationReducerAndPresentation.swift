//
//  PianoValidationReducerAndPresentation.swift
//  NoteMaster_Ver_1
//
//  Reducer lifecycles, rows / scale snap presentation math, and key preview flows.
//

import CoreGraphics
import Foundation
import QuartzCore

extension PianoValidationRunner {
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
}

//
//  PianoValidationKeyboardLayer.swift
//  NoteMaster_Ver_1
//
//  PianoKeyboardLayer structure, per-row routing, and coordinate normalization.
//

import CoreGraphics
import Foundation
import QuartzCore

extension PianoValidationRunner {
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
}

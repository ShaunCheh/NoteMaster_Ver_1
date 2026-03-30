//
//  PianoSceneBuilder.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics

struct PianoSceneBuilder: Equatable, Sendable {
    var configuration: PianoConfiguration
    var state: PianoComponentState

    func makeScene(bounds: CGRect) -> PianoScene {
        let normalizedBounds = bounds.standardized
        guard !normalizedBounds.isNull, !state.rows.isEmpty else {
            return .empty
        }

        let contentRect = CGRect(
            x: normalizedBounds.minX,
            y: normalizedBounds.minY,
            width: normalizedBounds.width,
            height: PianoLayoutMath.totalContentHeight(
                configuration: configuration,
                rowCount: state.rowCount
            )
        )

        let rows = state.rows.enumerated().map { rowIndex, rowState in
            makeRowScene(
                rowIndex: rowIndex,
                rowState: rowState,
                bounds: normalizedBounds
            )
        }

        return PianoScene(
            bounds: normalizedBounds,
            contentRect: contentRect,
            rows: rows
        )
    }

    private func makeRowScene(
        rowIndex: Int,
        rowState: PianoRowState,
        bounds: CGRect
    ) -> PianoScene.RowScene {
        let rowFrame = PianoLayoutMath.rowFrame(
            rowIndex: rowIndex,
            bounds: bounds,
            configuration: configuration
        )
        let controlStripRect = PianoLayoutMath.controlStripRect(
            for: rowFrame,
            configuration: configuration
        )
        let buttonStripRect = PianoLayoutMath.buttonStripRect(
            for: rowFrame,
            configuration: configuration
        )
        let buttonLeftRect = PianoLayoutMath.buttonLeftRect(
            in: buttonStripRect,
            configuration: configuration
        )
        let buttonRightRect = PianoLayoutMath.buttonRightRect(
            in: buttonStripRect,
            configuration: configuration
        )
        let scaleRect = PianoLayoutMath.scaleRect(
            for: rowFrame,
            configuration: configuration
        )
        let keysRect = PianoLayoutMath.keysRect(
            for: rowFrame,
            configuration: configuration
        )
        let visibleKeys = PianoLayoutMath.visibleKeys(
            rowState: rowState,
            keysRect: keysRect,
            configuration: configuration
        )
        let scaleMarkers = PianoLayoutMath.scaleMarkers(
            from: visibleKeys.whites,
            scaleRect: scaleRect
        )

        return PianoScene.RowScene(
            rowIndex: rowIndex,
            frame: rowFrame,
            controlStripRect: controlStripRect,
            buttonStripRect: buttonStripRect,
            buttonLeftRect: buttonLeftRect,
            buttonRightRect: buttonRightRect,
            scaleRect: scaleRect,
            keysRect: keysRect,
            whiteKeys: visibleKeys.whites,
            blackKeys: visibleKeys.blacks,
            scaleMarkers: scaleMarkers
        )
    }
}

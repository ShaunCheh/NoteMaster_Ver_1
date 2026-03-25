//
//  FretboardSceneBuilder.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics

struct FretboardSceneBuilder: Equatable, Sendable {
    var configuration: FretboardConfiguration

    func makeScene(bounds: CGRect) -> FretboardScene {
        let normalizedBounds = bounds.standardized

        switch configuration.displayMode {
        case .horizontal:
            return HorizontalFretboardGeometryStrategy().makeScene(
                configuration: configuration,
                bounds: normalizedBounds
            )
        case .vertical:
            return VerticalFretboardGeometryStrategy().makeScene(
                configuration: configuration,
                bounds: normalizedBounds
            )
        }
    }

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase,
        scene: FretboardScene
    ) -> FretboardHitResult {
        switch configuration.displayMode {
        case .horizontal:
            return HorizontalFretboardGeometryStrategy().hitTest(
                point,
                phase: phase,
                configuration: configuration,
                scene: scene
            )
        case .vertical:
            return VerticalFretboardGeometryStrategy().hitTest(
                point,
                phase: phase,
                configuration: configuration,
                scene: scene
            )
        }
    }
}

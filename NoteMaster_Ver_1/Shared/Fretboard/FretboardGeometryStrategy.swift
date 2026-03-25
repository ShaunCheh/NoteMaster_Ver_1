//
//  FretboardGeometryStrategy.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics

protocol FretboardGeometryStrategy: Sendable {
    func makeScene(
        configuration: FretboardConfiguration,
        bounds: CGRect
    ) -> FretboardScene

    func hitTest(
        _ point: CGPoint,
        phase: FretboardEventPhase,
        configuration: FretboardConfiguration,
        scene: FretboardScene
    ) -> FretboardHitResult
}

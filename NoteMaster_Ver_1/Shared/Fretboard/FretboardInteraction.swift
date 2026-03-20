//
//  FretboardInteraction.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

import Foundation
import CoreGraphics

enum FretboardEventPhase: Equatable, Sendable {
    case began
    case moved
    case ended
    case cancelled

    var debugName: String {
        switch self {
        case .began:
            return "began"
        case .moved:
            return "moved"
        case .ended:
            return "ended"
        case .cancelled:
            return "cancelled"
        }
    }
}

struct FretboardCell: Equatable, Hashable, Sendable {
    var stringIndex: Int
    // 0 表示空弦区域，1...maxFret 表示实际按弦区。
    var fret: Int
}

struct FretboardHitResult: Equatable, Sendable {
    var phase: FretboardEventPhase
    // 使用平台包装视图本地坐标，和 FretboardGeometry 的 bounds 语义保持一致。
    var locationInView: CGPoint
    var cell: FretboardCell?
    var isInsideDrawingRect: Bool
    var distanceToNearestString: CGFloat?

    var stringIndex: Int? {
        cell?.stringIndex
    }

    var fret: Int? {
        cell?.fret
    }

    var hasHit: Bool {
        cell != nil
    }

    func debugSummary(platform: String) -> String {
        let pointText = String(
            format: "(%.1f, %.1f)",
            locationInView.x,
            locationInView.y
        )
        let stringText = stringIndex.map(String.init) ?? "nil"
        let fretText = fret.map(String.init) ?? "nil"
        let distanceText = distanceToNearestString.map {
            String(format: "%.1f", $0)
        } ?? "nil"

        return "[\(platform)] phase=\(phase.debugName) string=\(stringText) fret=\(fretText) point=\(pointText) inside=\(isInsideDrawingRect) distance=\(distanceText)"
    }
}

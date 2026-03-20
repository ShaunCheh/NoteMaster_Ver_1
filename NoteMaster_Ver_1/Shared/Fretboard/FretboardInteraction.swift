//
//  FretboardInteraction.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

import CoreGraphics

enum FretboardEventPhase: Equatable, Sendable {
    case began
    case moved
    case ended
    case cancelled
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
}

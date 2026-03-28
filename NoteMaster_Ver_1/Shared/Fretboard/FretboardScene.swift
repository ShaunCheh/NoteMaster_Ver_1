//
//  FretboardScene.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/25.
//

import CoreGraphics

struct FretboardScene: Equatable, Sendable {
    struct CellFrame: Equatable, Sendable {
        var stringIndex: Int
        var fret: Int
        var frame: CGRect
    }

    struct StringSegment: Equatable, Sendable {
        var stringIndex: Int
        var start: CGPoint
        var end: CGPoint
    }

    struct FretSegment: Equatable, Sendable {
        var fret: Int
        var start: CGPoint
        var end: CGPoint
    }

    struct MarkerPlacement: Equatable, Sendable {
        enum Style: Equatable, Sendable {
            case singleDot
            case doubleDot
        }

        var fret: Int
        var style: Style
        var centers: [CGPoint]
        var diameter: CGFloat
    }

    struct LabelAnchor: Equatable, Sendable {
        var stringIndex: Int
        var fret: Int
        var center: CGPoint
        var cellFrame: CGRect
    }

    var drawingRect: CGRect
    var openStringRect: CGRect
    var nutRect: CGRect
    var fretboardRect: CGRect
    var stringSegments: [StringSegment]
    var fretSegments: [FretSegment]
    var cellFrames: [CellFrame]
    var markerPlacements: [MarkerPlacement]
    var labelAnchors: [LabelAnchor]

    static let empty = FretboardScene(
        drawingRect: .null,
        openStringRect: .null,
        nutRect: .null,
        fretboardRect: .null,
        stringSegments: [],
        fretSegments: [],
        cellFrames: [],
        markerPlacements: [],
        labelAnchors: []
    )

    func stringSegment(for stringIndex: Int) -> StringSegment? {
        stringSegments.first { $0.stringIndex == stringIndex }
    }

    func fretSegment(for fret: Int) -> FretSegment? {
        fretSegments.first { $0.fret == fret }
    }

    func cellFrame(stringIndex: Int, fret: Int) -> CGRect? {
        cellFrames.first {
            $0.stringIndex == stringIndex && $0.fret == fret
        }?.frame
    }

    func cellFrame(for cell: FretboardCell) -> CGRect? {
        cellFrame(
            stringIndex: cell.stringIndex,
            fret: cell.fret
        )
    }

    func fretSpanRect(at fret: Int) -> CGRect? {
        let frames = cellFrames
            .filter { $0.fret == fret }
            .map(\.frame)
        return union(of: frames)
    }

    func labelAnchor(stringIndex: Int, fret: Int) -> LabelAnchor? {
        labelAnchors.first {
            $0.stringIndex == stringIndex && $0.fret == fret
        }
    }

    private func union(of frames: [CGRect]) -> CGRect? {
        guard let firstFrame = frames.first else {
            return nil
        }

        return frames.dropFirst().reduce(firstFrame) { partialResult, frame in
            partialResult.union(frame)
        }
    }
}

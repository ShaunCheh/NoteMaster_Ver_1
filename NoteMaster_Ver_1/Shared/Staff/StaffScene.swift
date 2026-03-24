//
//  StaffScene.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics

struct ClefAnchor: Equatable, Sendable {
    enum Semantic: Equatable, Sendable {
        case trebleGLine
    }

    // 语义锚点使用共享逻辑坐标，不暴露 CoreText baseline。
    var point: CGPoint
    var semantic: Semantic
    var targetHeight: CGFloat
}

enum StaffGlyphSymbolID: Equatable, Sendable {
    case trebleClef
}

struct StaffSceneColor: Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let primaryInk = StaffSceneColor(
        red: 0.12,
        green: 0.12,
        blue: 0.14,
        alpha: 1
    )

    static let debugRed = StaffSceneColor(
        red: 0.88,
        green: 0.18,
        blue: 0.18,
        alpha: 1
    )
}

struct StaffGlyphBoundsOverlayStyle: Equatable, Sendable {
    var strokeColor: StaffSceneColor
    var lineWidth: CGFloat

    static func clefDebug(lineWidth: CGFloat = 1) -> Self {
        StaffGlyphBoundsOverlayStyle(
            strokeColor: .debugRed,
            lineWidth: max(lineWidth, 0.5)
        )
    }
}

struct StaffGlyphAnchorOverlayStyle: Equatable, Sendable {
    var strokeColor: StaffSceneColor
    var lineWidth: CGFloat
    var crossHalfLength: CGFloat

    static func clefDebug(
        lineWidth: CGFloat = 1,
        crossHalfLength: CGFloat = 4
    ) -> Self {
        StaffGlyphAnchorOverlayStyle(
            strokeColor: .debugRed,
            lineWidth: max(lineWidth, 0.5),
            crossHalfLength: max(crossHalfLength, 2)
        )
    }
}

struct StaffGlyphRenderHint: Equatable, Sendable {
    var preservesAspectRatio: Bool
    var prefersOpticalBoundsAlignment: Bool
    var boundsOverlayStyle: StaffGlyphBoundsOverlayStyle?
    var anchorOverlayStyle: StaffGlyphAnchorOverlayStyle?

    static func staffClef(
        boundsOverlayStyle: StaffGlyphBoundsOverlayStyle? = nil,
        anchorOverlayStyle: StaffGlyphAnchorOverlayStyle? = nil
    ) -> StaffGlyphRenderHint {
        StaffGlyphRenderHint(
            preservesAspectRatio: true,
            prefersOpticalBoundsAlignment: true,
            boundsOverlayStyle: boundsOverlayStyle,
            anchorOverlayStyle: anchorOverlayStyle
        )
    }
}

enum StaffGlyphPlacement: Equatable, Sendable {
    case anchor(ClefAnchor)
    case frame(CGRect)
}

struct StaffGlyphItem: Equatable, Sendable {
    var symbolID: StaffGlyphSymbolID
    var placement: StaffGlyphPlacement
    var tintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint
}

struct StaffScene: Equatable, Sendable {
    var lineSegments: [StaffGeometry.StaffLineSegment]
    var glyphs: [StaffGlyphItem]

    static let empty = StaffScene(
        lineSegments: [],
        glyphs: []
    )
}

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
        case bassFLine
    }

    // 语义锚点使用共享逻辑坐标，不暴露 CoreText baseline。
    var point: CGPoint
    var semantic: Semantic
    var targetHeight: CGFloat
}

enum StaffGlyphSymbolID: Equatable, Sendable {
    case trebleClef
    case bassClef
    case noteheadWhole
    case noteheadHalf
    case noteheadBlack
    case accidentalFlat
    case accidentalNatural
    case accidentalSharp
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
    enum VerticalTrimMode: Equatable, Sendable {
        case none
        case clefSpecific
    }

    var preservesAspectRatio: Bool
    var prefersOpticalBoundsAlignment: Bool
    var verticalTrimMode: VerticalTrimMode
    var boundsOverlayStyle: StaffGlyphBoundsOverlayStyle?
    var anchorOverlayStyle: StaffGlyphAnchorOverlayStyle?

    static func staffClef(
        boundsOverlayStyle: StaffGlyphBoundsOverlayStyle? = nil,
        anchorOverlayStyle: StaffGlyphAnchorOverlayStyle? = nil
    ) -> StaffGlyphRenderHint {
        StaffGlyphRenderHint(
            preservesAspectRatio: true,
            prefersOpticalBoundsAlignment: true,
            verticalTrimMode: .clefSpecific,
            boundsOverlayStyle: boundsOverlayStyle,
            anchorOverlayStyle: anchorOverlayStyle
        )
    }

    static func notehead(
        boundsOverlayStyle: StaffGlyphBoundsOverlayStyle? = nil
    ) -> StaffGlyphRenderHint {
        StaffGlyphRenderHint(
            preservesAspectRatio: true,
            prefersOpticalBoundsAlignment: true,
            verticalTrimMode: .none,
            boundsOverlayStyle: boundsOverlayStyle,
            anchorOverlayStyle: nil
        )
    }

    static func accidental(
        boundsOverlayStyle: StaffGlyphBoundsOverlayStyle? = nil
    ) -> StaffGlyphRenderHint {
        StaffGlyphRenderHint(
            preservesAspectRatio: true,
            prefersOpticalBoundsAlignment: true,
            verticalTrimMode: .none,
            boundsOverlayStyle: boundsOverlayStyle,
            anchorOverlayStyle: nil
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

enum StaffStrokeSemantic: Equatable, Sendable {
    case stem
    case ledgerLine
}

enum StaffStrokeLineCap: Equatable, Sendable {
    case butt
    case round
    case square
}

struct StaffStrokeStyle: Equatable, Sendable {
    var strokeColor: StaffSceneColor
    var lineWidth: CGFloat
    var lineCap: StaffStrokeLineCap

    static func stem(
        strokeColor: StaffSceneColor = .primaryInk,
        lineWidth: CGFloat = 1.4
    ) -> Self {
        StaffStrokeStyle(
            strokeColor: strokeColor,
            lineWidth: max(lineWidth, 0.5),
            lineCap: .round
        )
    }

    static func ledgerLine(
        strokeColor: StaffSceneColor = .primaryInk,
        lineWidth: CGFloat = 1.2
    ) -> Self {
        StaffStrokeStyle(
            strokeColor: strokeColor,
            lineWidth: max(lineWidth, 0.5),
            lineCap: .round
        )
    }
}

struct StaffStrokeItem: Equatable, Sendable {
    var semantic: StaffStrokeSemantic
    var start: CGPoint
    var end: CGPoint
    var style: StaffStrokeStyle
}

struct StaffScene: Equatable, Sendable {
    // 五线谱本体由独立 lines layer 绘制；scene 仍保留这份语义结果，供验证和后续 builder 使用。
    var lineSegments: [StaffGeometry.StaffLineSegment]
    // note stem / ledger line 等附加线段走 scene item，而不是伪装成 staff line。
    var strokeItems: [StaffStrokeItem]
    var glyphs: [StaffGlyphItem]

    static let empty = StaffScene(
        lineSegments: [],
        strokeItems: [],
        glyphs: []
    )
}

extension ClefAnchor.Semantic {
    var clef: StaffClef {
        switch self {
        case .trebleGLine:
            return .treble
        case .bassFLine:
            return .bass
        }
    }
}

extension StaffGlyphSymbolID {
    var clef: StaffClef? {
        switch self {
        case .trebleClef:
            return .treble
        case .bassClef:
            return .bass
        case .noteheadWhole, .noteheadHalf, .noteheadBlack,
                .accidentalFlat, .accidentalNatural, .accidentalSharp:
            return nil
        }
    }
}

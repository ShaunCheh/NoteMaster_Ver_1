//
//  StaffSceneProvider.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics

// provider 只负责把共享状态投影成语义场景，不处理字体度量和绘制细节。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var score: StaffScore?
    var glyphTintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint

    init(
        clef: StaffClef = .treble,
        score: StaffScore? = nil,
        glyphTintColor: StaffSceneColor = .primaryInk,
        renderHint: StaffGlyphRenderHint = .staffClef()
    ) {
        self.clef = clef
        self.score = score
        self.glyphTintColor = glyphTintColor
        self.renderHint = renderHint
    }

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
        }

        if let score, !score.isEmpty {
            #if DEBUG
            if score.clef != clef {
                assertionFailure(
                    "StaffSceneProvider received score.clef that does not match provider clef; provider clef will be used for layout."
                )
            }
            #endif

            return StaffSceneBuilder(
                clef: clef,
                score: score,
                glyphTintColor: glyphTintColor,
                clefRenderHint: renderHint
            ).makeScene(geometry: geometry)
        }

        let glyphs = [
            StaffGlyphItem(
                symbolID: symbolID(for: clef),
                placement: .anchor(geometry.clefAnchor(for: clef)),
                tintColor: glyphTintColor,
                renderHint: renderHint
            )
        ]

        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            strokeItems: [],
            glyphs: glyphs
        )
    }

    private func symbolID(for clef: StaffClef) -> StaffGlyphSymbolID {
        switch clef {
        case .treble:
            return .trebleClef
        case .bass:
            return .bassClef
        }
    }
}

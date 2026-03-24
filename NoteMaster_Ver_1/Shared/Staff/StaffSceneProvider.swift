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
    var glyphTintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint

    init(
        clef: StaffClef = .treble,
        glyphTintColor: StaffSceneColor = .primaryInk,
        renderHint: StaffGlyphRenderHint = .staffClef()
    ) {
        self.clef = clef
        self.glyphTintColor = glyphTintColor
        self.renderHint = renderHint
    }

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
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

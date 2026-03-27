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
    var notationDisplayOptions: StaffNotationDisplayOptions
    // 阶段 1 先把序列展示语义纳入 provider 真相源；
    // 阶段 2 再由 scene builder 消费并转成实际游标/高亮图元。
    var sequencePresentation: StaffSequencePresentation?
    var glyphTintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint

    init(
        clef: StaffClef = .treble,
        score: StaffScore? = nil,
        notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
        sequencePresentation: StaffSequencePresentation? = nil,
        glyphTintColor: StaffSceneColor = .primaryInk,
        renderHint: StaffGlyphRenderHint = .staffClef()
    ) {
        self.clef = clef
        self.score = score
        self.notationDisplayOptions = notationDisplayOptions
        self.sequencePresentation = sequencePresentation
        self.glyphTintColor = glyphTintColor
        self.renderHint = renderHint
    }

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
        }

        if let score {
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
                notationDisplayOptions: notationDisplayOptions,
                sequencePresentation: sequencePresentation,
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

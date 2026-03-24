//
//  MusicGlyphRenderer.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import CoreGraphics

// renderer 是唯一的 glyph 后端切换点；未来接入 CGPath 时不要改 scene 或 geometry 协议。
protocol MusicGlyphRenderer {
    func draw(
        glyphItem: StaffGlyphItem,
        in context: CGContext,
        geometry: StaffGeometry,
        canvasOrientation: StaffCanvasOrientation
    )
}

//
//  MusicGlyphRendererFactory.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import Foundation

enum MusicGlyphRendererFactory {
    // future CGPath backend 应只在这里接入，不要回改 scene、geometry 或平台 view 协议。
    static func makeRenderer(
        renderMode: MusicGlyphRenderMode,
        bundle: Bundle = .main
    ) -> any MusicGlyphRenderer {
        switch renderMode {
        case .automatic, .coreText:
            return CoreTextMusicGlyphRenderer(bundle: bundle)
        case .cgPath:
            assertionFailure("CGPath glyph renderer is not implemented yet; falling back to CoreText.")
            return CoreTextMusicGlyphRenderer(bundle: bundle)
        }
    }
}

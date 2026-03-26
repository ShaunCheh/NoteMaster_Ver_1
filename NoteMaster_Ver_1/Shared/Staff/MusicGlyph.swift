//
//  MusicGlyph.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

enum MusicFontFace: String, CaseIterable, Hashable, Sendable {
    case bravura
    case bravuraText

    var resourceName: String {
        switch self {
        case .bravura:
            return "Bravura"
        case .bravuraText:
            return "BravuraText"
        }
    }

    var fileExtension: String {
        "otf"
    }

    var fileName: String {
        "\(resourceName).\(fileExtension)"
    }

    // 未来 renderer 优先使用注册后的 PostScript name；这里保留文件级默认名作为回退。
    var fallbackPostScriptName: String {
        resourceName
    }
}

struct MusicGlyph: Equatable, Sendable {
    var fontFace: MusicFontFace
    var scalarValue: UInt32

    // Stage 4 的 CoreText renderer 将直接使用该字符构建 attributed string。
    var string: String {
        guard let scalar = UnicodeScalar(scalarValue) else {
            return "\u{FFFD}"
        }

        return String(scalar)
    }

    // SMuFL gClef，对应 Bravura 中的 treble clef。
    static let trebleClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE050
    )

    // SMuFL fClef，对应 Bravura 中的 bass clef。
    static let bassClef = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE062
    )

    // SMuFL noteheadWhole，对应 Bravura 中的全音符符头。
    static let noteheadWhole = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE0A2
    )

    // SMuFL noteheadHalf，对应 Bravura 中的二分音符符头。
    static let noteheadHalf = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE0A3
    )

    // SMuFL noteheadBlack，对应 Bravura 中的黑色符头。
    static let noteheadBlack = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE0A4
    )

    // SMuFL accidentalFlat，对应 Bravura 中的降号。
    static let accidentalFlat = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE260
    )

    // SMuFL accidentalNatural，对应 Bravura 中的还原号。
    static let accidentalNatural = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE261
    )

    // SMuFL accidentalSharp，对应 Bravura 中的升号。
    static let accidentalSharp = MusicGlyph(
        fontFace: .bravura,
        scalarValue: 0xE262
    )
}

extension StaffGlyphSymbolID {
    var musicGlyph: MusicGlyph {
        switch self {
        case .trebleClef:
            return .trebleClef
        case .bassClef:
            return .bassClef
        case .noteheadWhole:
            return .noteheadWhole
        case .noteheadHalf:
            return .noteheadHalf
        case .noteheadBlack:
            return .noteheadBlack
        case .accidentalFlat:
            return .accidentalFlat
        case .accidentalNatural:
            return .accidentalNatural
        case .accidentalSharp:
            return .accidentalSharp
        }
    }
}

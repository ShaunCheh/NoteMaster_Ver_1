//
//  StaffKeySignatureLayout.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

import CoreGraphics

struct StaffKeySignatureLayout: Equatable, Sendable {
    struct PositionedAccidental: Equatable, Sendable {
        var symbolID: StaffGlyphSymbolID
        var pitch: StaffPitch
        var staffPosition: Int
        var centerY: CGFloat
    }

    var clef: StaffClef

    init(clef: StaffClef) {
        self.clef = clef
    }

    func positionedAccidentals(
        for keySignature: StaffKeySignature,
        in geometry: StaffGeometry
    ) -> [PositionedAccidental] {
        guard
            let keyAccidental = keySignature.signatureAccidental,
            let symbolID = accidentalSymbolID(for: keyAccidental)
        else {
            return []
        }

        let pitchLayout = StaffPitchLayout(clef: clef)
        return keySignaturePitches(for: keyAccidental)
            .prefix(abs(keySignature.fifths))
            .compactMap { pitch in
                guard let positionedPitch = pitchLayout.positionedPitch(pitch, in: geometry) else {
                    return nil
                }

                return PositionedAccidental(
                    symbolID: symbolID,
                    pitch: pitch,
                    staffPosition: positionedPitch.staffPosition,
                    centerY: positionedPitch.centerY
                )
            }
    }

    // 调号位置使用标准记谱顺序；这里保留“书写音高”而不是半音值，
    // 后续 scene builder 只需要决定 x 方向排布即可。
    private func keySignaturePitches(
        for accidental: StaffAccidental
    ) -> [StaffPitch] {
        switch (clef, accidental) {
        case (.treble, .sharp):
            return [
                StaffPitch(letter: .f, octave: 5),
                StaffPitch(letter: .c, octave: 5),
                StaffPitch(letter: .g, octave: 5),
                StaffPitch(letter: .d, octave: 5),
                StaffPitch(letter: .a, octave: 4),
                StaffPitch(letter: .e, octave: 5),
                StaffPitch(letter: .b, octave: 4)
            ]
        case (.bass, .sharp):
            return [
                StaffPitch(letter: .f, octave: 3),
                StaffPitch(letter: .c, octave: 3),
                StaffPitch(letter: .g, octave: 3),
                StaffPitch(letter: .d, octave: 3),
                StaffPitch(letter: .a, octave: 2),
                StaffPitch(letter: .e, octave: 3),
                StaffPitch(letter: .b, octave: 2)
            ]
        case (.treble, .flat):
            return [
                StaffPitch(letter: .b, octave: 4),
                StaffPitch(letter: .e, octave: 5),
                StaffPitch(letter: .a, octave: 4),
                StaffPitch(letter: .d, octave: 5),
                StaffPitch(letter: .g, octave: 4),
                StaffPitch(letter: .c, octave: 5),
                StaffPitch(letter: .f, octave: 4)
            ]
        case (.bass, .flat):
            return [
                StaffPitch(letter: .b, octave: 2),
                StaffPitch(letter: .e, octave: 3),
                StaffPitch(letter: .a, octave: 2),
                StaffPitch(letter: .d, octave: 3),
                StaffPitch(letter: .g, octave: 2),
                StaffPitch(letter: .c, octave: 3),
                StaffPitch(letter: .f, octave: 2)
            ]
        case (_, .natural):
            return []
        }
    }

    private func accidentalSymbolID(
        for accidental: StaffAccidental
    ) -> StaffGlyphSymbolID? {
        switch accidental {
        case .flat:
            return .accidentalFlat
        case .natural:
            return nil
        case .sharp:
            return .accidentalSharp
        }
    }
}

//
//  InstrumentTuning.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

struct InstrumentTuning: Equatable, Hashable, Sendable {
    var instrument: InstrumentType
    // 空弦数组按逻辑弦序从低音到高音排列；屏幕显示方向由外层 displayMode 与几何映射决定。
    var openStringsLowToHigh: [NotePitch]

    init(instrument: InstrumentType, openStringsLowToHigh: [NotePitch]) {
        precondition(
            openStringsLowToHigh.count == instrument.stringCount,
            "Open string count must match instrument string count."
        )

        self.instrument = instrument
        self.openStringsLowToHigh = openStringsLowToHigh
    }

    var stringCount: Int {
        openStringsLowToHigh.count
    }

    func openStringPitch(for stringIndex: Int) -> NotePitch? {
        guard openStringsLowToHigh.indices.contains(stringIndex) else {
            return nil
        }

        return openStringsLowToHigh[stringIndex]
    }

    static func standard(for instrument: InstrumentType) -> InstrumentTuning {
        switch instrument {
        case .guitar6:
            return .guitar6Standard
        case .bass4:
            return .bass4Standard
        case .bass5:
            return .bass5Standard
        }
    }

    static let guitar6Standard = InstrumentTuning(
        instrument: .guitar6,
        openStringsLowToHigh: [
            NotePitch(pitchClass: .e, octave: 2),
            NotePitch(pitchClass: .a, octave: 2),
            NotePitch(pitchClass: .d, octave: 3),
            NotePitch(pitchClass: .g, octave: 3),
            NotePitch(pitchClass: .b, octave: 3),
            NotePitch(pitchClass: .e, octave: 4)
        ]
    )

    static let bass4Standard = InstrumentTuning(
        instrument: .bass4,
        openStringsLowToHigh: [
            NotePitch(pitchClass: .e, octave: 1),
            NotePitch(pitchClass: .a, octave: 1),
            NotePitch(pitchClass: .d, octave: 2),
            NotePitch(pitchClass: .g, octave: 2)
        ]
    )

    static let bass5Standard = InstrumentTuning(
        instrument: .bass5,
        openStringsLowToHigh: [
            NotePitch(pitchClass: .b, octave: 0),
            NotePitch(pitchClass: .e, octave: 1),
            NotePitch(pitchClass: .a, octave: 1),
            NotePitch(pitchClass: .d, octave: 2),
            NotePitch(pitchClass: .g, octave: 2)
        ]
    )
}

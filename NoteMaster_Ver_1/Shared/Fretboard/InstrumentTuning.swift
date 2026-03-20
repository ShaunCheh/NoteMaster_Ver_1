//
//  InstrumentTuning.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

struct InstrumentTuning: Equatable, Hashable, Sendable {
    var instrument: InstrumentType
    // 空弦顺序固定为视觉上从上到下，对应几何层的 stringIndex 方向。
    var openStringsTopToBottom: [NotePitch]

    init(instrument: InstrumentType, openStringsTopToBottom: [NotePitch]) {
        precondition(
            openStringsTopToBottom.count == instrument.stringCount,
            "Open string count must match instrument string count."
        )

        self.instrument = instrument
        self.openStringsTopToBottom = openStringsTopToBottom
    }

    var stringCount: Int {
        openStringsTopToBottom.count
    }

    func openStringPitch(for stringIndex: Int) -> NotePitch? {
        guard openStringsTopToBottom.indices.contains(stringIndex) else {
            return nil
        }

        return openStringsTopToBottom[stringIndex]
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
        openStringsTopToBottom: [
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
        openStringsTopToBottom: [
            NotePitch(pitchClass: .e, octave: 1),
            NotePitch(pitchClass: .a, octave: 1),
            NotePitch(pitchClass: .d, octave: 2),
            NotePitch(pitchClass: .g, octave: 2)
        ]
    )

    static let bass5Standard = InstrumentTuning(
        instrument: .bass5,
        openStringsTopToBottom: [
            NotePitch(pitchClass: .b, octave: 0),
            NotePitch(pitchClass: .e, octave: 1),
            NotePitch(pitchClass: .a, octave: 1),
            NotePitch(pitchClass: .d, octave: 2),
            NotePitch(pitchClass: .g, octave: 2)
        ]
    )
}

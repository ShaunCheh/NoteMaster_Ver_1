//
//  StaffScore.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

struct StaffKeySignature: Equatable, Hashable, Sendable {
    static let supportedFifthsRange = -7...7
    static let natural = StaffKeySignature(fifths: 0)

    private static let sharpOrder: [StaffPitchLetter] = [.f, .c, .g, .d, .a, .e, .b]
    private static let flatOrder: [StaffPitchLetter] = [.b, .e, .a, .d, .g, .c, .f]

    var fifths: Int

    init(fifths: Int = 0) {
        precondition(
            Self.supportedFifthsRange.contains(fifths),
            "StaffKeySignature fifths must stay within -7...7."
        )
        self.fifths = fifths
    }

    var isNatural: Bool {
        fifths == 0
    }

    var signatureAccidental: StaffAccidental? {
        if fifths > 0 {
            return .sharp
        }

        if fifths < 0 {
            return .flat
        }

        return nil
    }

    var alteredLetters: [StaffPitchLetter] {
        guard let signatureAccidental else {
            return []
        }

        let order = signatureAccidental == .sharp
            ? Self.sharpOrder
            : Self.flatOrder
        return Array(order.prefix(abs(fifths)))
    }

    func accidental(for letter: StaffPitchLetter) -> StaffAccidental {
        guard
            alteredLetters.contains(letter),
            let signatureAccidental
        else {
            return .natural
        }

        return signatureAccidental
    }
}

struct StaffMeasure: Equatable, Sendable {
    var notes: [StaffScoreNote]

    init(notes: [StaffScoreNote]) {
        self.notes = notes
    }

    var isEmpty: Bool {
        notes.isEmpty
    }
}

struct StaffScore: Equatable, Sendable {
    var clef: StaffClef
    var keySignature: StaffKeySignature
    var measures: [StaffMeasure]

    init(
        clef: StaffClef,
        keySignature: StaffKeySignature = .natural,
        measures: [StaffMeasure]
    ) {
        self.clef = clef
        self.keySignature = keySignature
        self.measures = measures
    }

    init(
        clef: StaffClef,
        keySignature: StaffKeySignature = .natural,
        notes: [StaffScoreNote]
    ) {
        self.init(
            clef: clef,
            keySignature: keySignature,
            measures: notes.isEmpty
            ? []
            : [StaffMeasure(notes: notes)]
        )
    }

    // 过渡期继续保留平铺 notes 视图，避免后续 scene builder 与验证器在阶段 1 一起被拖拽重写。
    var notes: [StaffScoreNote] {
        measures.flatMap(\.notes)
    }

    var isEmpty: Bool {
        measures.allSatisfy(\.isEmpty)
    }
}

struct StaffScoreNote: Equatable, Hashable, Sendable {
    var pitch: StaffPitch
    var duration: StaffNoteDuration

    init(
        pitch: StaffPitch,
        duration: StaffNoteDuration
    ) {
        self.pitch = pitch
        self.duration = duration
    }

    var notePitch: NotePitch {
        pitch.notePitch
    }
}

enum StaffNoteDuration: String, CaseIterable, Equatable, Hashable, Sendable {
    case whole
    case half
    case quarter

    var title: String {
        switch self {
        case .whole:
            return "Whole"
        case .half:
            return "Half"
        case .quarter:
            return "Quarter"
        }
    }

    var showsStem: Bool {
        self != .whole
    }

    var usesFilledNotehead: Bool {
        self == .quarter
    }
}

enum StaffPitchLetter: Int, CaseIterable, Equatable, Hashable, Sendable {
    case c = 0
    case d = 1
    case e = 2
    case f = 3
    case g = 4
    case a = 5
    case b = 6

    var scientificToken: String {
        switch self {
        case .c:
            return "C"
        case .d:
            return "D"
        case .e:
            return "E"
        case .f:
            return "F"
        case .g:
            return "G"
        case .a:
            return "A"
        case .b:
            return "B"
        }
    }

    var diatonicStepIndex: Int {
        rawValue
    }

    fileprivate var semitoneFromC: Int {
        switch self {
        case .c:
            return 0
        case .d:
            return 2
        case .e:
            return 4
        case .f:
            return 5
        case .g:
            return 7
        case .a:
            return 9
        case .b:
            return 11
        }
    }
}

enum StaffAccidental: Int, CaseIterable, Equatable, Hashable, Sendable {
    case flat = -1
    case natural = 0
    case sharp = 1

    var semitoneOffset: Int {
        rawValue
    }

    var scientificToken: String {
        switch self {
        case .flat:
            return "b"
        case .natural:
            return ""
        case .sharp:
            return "#"
        }
    }
}

// StaffPitch 保留书写音高，而不是只保留半音值，避免后续五线谱定位丢失 line/space 语义。
struct StaffPitch: Equatable, Hashable, Sendable {
    var letter: StaffPitchLetter
    var accidental: StaffAccidental
    var octave: Int

    init(
        letter: StaffPitchLetter,
        accidental: StaffAccidental = .natural,
        octave: Int
    ) {
        self.letter = letter
        self.accidental = accidental
        self.octave = octave
    }

    var diatonicIndex: Int {
        (octave * 7) + letter.diatonicStepIndex
    }

    var notePitch: NotePitch {
        let absoluteSemitone = (octave * 12)
            + letter.semitoneFromC
            + accidental.semitoneOffset
        let normalizedPitchClassValue = ((absoluteSemitone % 12) + 12) % 12
        let normalizedOctave = (absoluteSemitone - normalizedPitchClassValue) / 12

        guard let pitchClass = PitchClass(rawValue: normalizedPitchClassValue) else {
            preconditionFailure("Resolved pitch class must stay within 0...11.")
        }

        return NotePitch(
            pitchClass: pitchClass,
            octave: normalizedOctave
        )
    }

    var scientificName: String {
        "\(letter.scientificToken)\(accidental.scientificToken)\(octave)"
    }
}

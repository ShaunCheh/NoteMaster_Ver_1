//
//  StaffScore.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

struct StaffScore: Equatable, Sendable {
    var clef: StaffClef
    var notes: [StaffScoreNote]

    init(
        clef: StaffClef,
        notes: [StaffScoreNote]
    ) {
        self.clef = clef
        self.notes = notes
    }

    var isEmpty: Bool {
        notes.isEmpty
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

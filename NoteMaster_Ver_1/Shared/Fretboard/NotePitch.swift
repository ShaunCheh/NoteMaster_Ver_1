//
//  NotePitch.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/19.
//

enum PitchClass: Int, CaseIterable, Hashable, Sendable {
    case c = 0
    case cSharp = 1
    case d = 2
    case dSharp = 3
    case e = 4
    case f = 5
    case fSharp = 6
    case g = 7
    case gSharp = 8
    case a = 9
    case aSharp = 10
    case b = 11

    var isAccidental: Bool {
        switch self {
        case .cSharp, .dSharp, .fSharp, .gSharp, .aSharp:
            return true
        default:
            return false
        }
    }

    var isNatural: Bool {
        !isAccidental
    }

    static var naturalCasesInOrder: [PitchClass] {
        allCases.filter(\.isNatural)
    }

    static var accidentalCasesInOrder: [PitchClass] {
        allCases.filter(\.isAccidental)
    }

    func displayText(using spelling: PitchSpelling = .sharp) -> String {
        switch (self, spelling) {
        case (.c, _):
            return "C"
        case (.cSharp, .sharp):
            return "C#"
        case (.cSharp, .flat):
            return "Db"
        case (.d, _):
            return "D"
        case (.dSharp, .sharp):
            return "D#"
        case (.dSharp, .flat):
            return "Eb"
        case (.e, _):
            return "E"
        case (.f, _):
            return "F"
        case (.fSharp, .sharp):
            return "F#"
        case (.fSharp, .flat):
            return "Gb"
        case (.g, _):
            return "G"
        case (.gSharp, .sharp):
            return "G#"
        case (.gSharp, .flat):
            return "Ab"
        case (.a, _):
            return "A"
        case (.aSharp, .sharp):
            return "A#"
        case (.aSharp, .flat):
            return "Bb"
        case (.b, _):
            return "B"
        }
    }
}

enum PitchSpelling: Hashable, Sendable {
    case sharp
    case flat
}

struct NotePitch: Equatable, Hashable, Sendable {
    var pitchClass: PitchClass
    var octave: Int

    var absoluteSemitone: Int {
        (octave * 12) + pitchClass.rawValue
    }

    func advanced(by semitones: Int) -> NotePitch {
        let nextAbsoluteSemitone = absoluteSemitone + semitones
        let normalizedPitchClassValue = ((nextAbsoluteSemitone % 12) + 12) % 12
        let normalizedOctave = (nextAbsoluteSemitone - normalizedPitchClassValue) / 12

        return NotePitch(
            pitchClass: PitchClass(rawValue: normalizedPitchClassValue)!,
            octave: normalizedOctave
        )
    }

    func displayText(
        using spelling: PitchSpelling = .sharp,
        showsOctave: Bool = true
    ) -> String {
        let pitchClassText = pitchClass.displayText(using: spelling)
        return showsOctave ? "\(pitchClassText)\(octave)" : pitchClassText
    }
}

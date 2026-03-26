//
//  StaffScoreDecoding.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

import Foundation

enum StaffScoreDecodingError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingField(String)
    case invalidClef(String)
    case invalidPitch(String)
    case invalidDuration(String)

    var description: String {
        switch self {
        case let .missingField(fieldName):
            return "Missing required staff score field: \(fieldName)"
        case let .invalidClef(value):
            return "Invalid staff clef token: \(value)"
        case let .invalidPitch(value):
            return "Invalid staff pitch token: \(value)"
        case let .invalidDuration(value):
            return "Invalid staff duration token: \(value)"
        }
    }
}

struct StaffScoreDTO: Equatable, Sendable {
    var clef: String
    var notes: [StaffScoreNoteDTO]

    init(
        clef: String,
        notes: [StaffScoreNoteDTO]
    ) {
        self.clef = clef
        self.notes = notes
    }

    func resolve() throws -> StaffScore {
        StaffScore(
            clef: try StaffClef.parse(token: clef),
            notes: try notes.map { try $0.resolve() }
        )
    }

    static func decode(
        from data: Data,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> StaffScoreDTO {
        try decoder.decode(StaffScoreDTO.self, from: data)
    }

    static func decode(
        from json: String,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> StaffScoreDTO {
        try decode(from: Data(json.utf8), using: decoder)
    }
}

struct StaffScoreNoteDTO: Equatable, Sendable {
    var pitch: String
    var duration: String

    init(
        pitch: String,
        duration: String
    ) {
        self.pitch = pitch
        self.duration = duration
    }

    func resolve() throws -> StaffScoreNote {
        StaffScoreNote(
            pitch: try StaffPitch.parse(scientificPitch: pitch),
            duration: try StaffNoteDuration.parse(token: duration)
        )
    }
}

extension StaffScoreDTO: Codable {
    private enum EnglishCodingKeys: String, CodingKey {
        case clef
        case notes
    }

    private enum ChineseCodingKeys: String, CodingKey {
        case clef = "谱号"
        case notes = "音符"
    }

    init(from decoder: Decoder) throws {
        let englishContainer = try decoder.container(keyedBy: EnglishCodingKeys.self)
        let chineseContainer = try decoder.container(keyedBy: ChineseCodingKeys.self)

        clef = try StaffScoreDecodeSupport.decodeRequiredValue(
            englishContainer: englishContainer,
            englishKey: .clef,
            chineseContainer: chineseContainer,
            chineseKey: .clef,
            fieldName: "clef/谱号"
        )
        notes = try StaffScoreDecodeSupport.decodeRequiredValue(
            englishContainer: englishContainer,
            englishKey: .notes,
            chineseContainer: chineseContainer,
            chineseKey: .notes,
            fieldName: "notes/音符"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EnglishCodingKeys.self)
        try container.encode(clef, forKey: .clef)
        try container.encode(notes, forKey: .notes)
    }
}

extension StaffScoreNoteDTO: Codable {
    private enum EnglishCodingKeys: String, CodingKey {
        case pitch
        case duration
    }

    private enum ChineseCodingKeys: String, CodingKey {
        case pitch = "音高"
        case duration = "时值"
    }

    init(from decoder: Decoder) throws {
        let englishContainer = try decoder.container(keyedBy: EnglishCodingKeys.self)
        let chineseContainer = try decoder.container(keyedBy: ChineseCodingKeys.self)

        pitch = try StaffScoreDecodeSupport.decodeRequiredValue(
            englishContainer: englishContainer,
            englishKey: .pitch,
            chineseContainer: chineseContainer,
            chineseKey: .pitch,
            fieldName: "pitch/音高"
        )
        duration = try StaffScoreDecodeSupport.decodeRequiredValue(
            englishContainer: englishContainer,
            englishKey: .duration,
            chineseContainer: chineseContainer,
            chineseKey: .duration,
            fieldName: "duration/时值"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EnglishCodingKeys.self)
        try container.encode(pitch, forKey: .pitch)
        try container.encode(duration, forKey: .duration)
    }
}

extension StaffScore {
    init(dto: StaffScoreDTO) throws {
        self = try dto.resolve()
    }

    static func decode(
        from data: Data,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> StaffScore {
        try StaffScoreDTO.decode(from: data, using: decoder).resolve()
    }

    static func decode(
        from json: String,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> StaffScore {
        try StaffScoreDTO.decode(from: json, using: decoder).resolve()
    }
}

private enum StaffScoreDecodeSupport {
    static func decodeRequiredValue<Value: Decodable, EnglishKey: CodingKey, ChineseKey: CodingKey>(
        englishContainer: KeyedDecodingContainer<EnglishKey>,
        englishKey: EnglishKey,
        chineseContainer: KeyedDecodingContainer<ChineseKey>,
        chineseKey: ChineseKey,
        fieldName: String
    ) throws -> Value {
        if let value = try englishContainer.decodeIfPresent(Value.self, forKey: englishKey) {
            return value
        }

        if let value = try chineseContainer.decodeIfPresent(Value.self, forKey: chineseKey) {
            return value
        }

        throw StaffScoreDecodingError.missingField(fieldName)
    }

    static func normalizedToken(_ token: String) -> String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    static func compactPitchToken(_ token: String) -> String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}

private extension StaffClef {
    static func parse(token: String) throws -> StaffClef {
        switch StaffScoreDecodeSupport.normalizedToken(token) {
        case "treble", "g", "gclef", "高音", "高音谱号":
            return .treble
        case "bass", "f", "fclef", "低音", "低音谱号":
            return .bass
        default:
            throw StaffScoreDecodingError.invalidClef(token)
        }
    }
}

private extension StaffNoteDuration {
    static func parse(token: String) throws -> StaffNoteDuration {
        switch StaffScoreDecodeSupport.normalizedToken(token) {
        case "whole", "wholenote", "1", "全分", "全音符":
            return .whole
        case "half", "halfnote", "2", "二分", "二分音符":
            return .half
        case "quarter", "quarternote", "4", "四分", "四分音符":
            return .quarter
        default:
            throw StaffScoreDecodingError.invalidDuration(token)
        }
    }
}

private extension StaffPitch {
    static func parse(scientificPitch token: String) throws -> StaffPitch {
        let compactToken = StaffScoreDecodeSupport.compactPitchToken(token)
        guard
            let firstCharacter = compactToken.first,
            let letter = StaffPitchLetter(scientificToken: firstCharacter)
        else {
            throw StaffScoreDecodingError.invalidPitch(token)
        }

        let remainder = String(compactToken.dropFirst())
        let accidentalAndOctave = try StaffAccidental.parse(token: remainder)
        guard let octave = Int(accidentalAndOctave.octaveText) else {
            throw StaffScoreDecodingError.invalidPitch(token)
        }

        return StaffPitch(
            letter: letter,
            accidental: accidentalAndOctave.accidental,
            octave: octave
        )
    }
}

private extension StaffPitchLetter {
    init?(scientificToken: Character) {
        switch String(scientificToken).lowercased() {
        case "c":
            self = .c
        case "d":
            self = .d
        case "e":
            self = .e
        case "f":
            self = .f
        case "g":
            self = .g
        case "a":
            self = .a
        case "b":
            self = .b
        default:
            return nil
        }
    }
}

private extension StaffAccidental {
    struct ParseResult {
        var accidental: StaffAccidental
        var octaveText: String
    }

    static func parse(token: String) throws -> ParseResult {
        let normalizedToken = token.lowercased()

        if token.hasPrefix("#") || token.hasPrefix("♯") {
            return ParseResult(
                accidental: .sharp,
                octaveText: String(token.dropFirst())
            )
        }

        if normalizedToken.hasPrefix("sharp") {
            return ParseResult(
                accidental: .sharp,
                octaveText: String(token.dropFirst("sharp".count))
            )
        }

        if normalizedToken.hasPrefix("b") || token.hasPrefix("♭") {
            return ParseResult(
                accidental: .flat,
                octaveText: String(token.dropFirst())
            )
        }

        if normalizedToken.hasPrefix("flat") {
            return ParseResult(
                accidental: .flat,
                octaveText: String(token.dropFirst("flat".count))
            )
        }

        if normalizedToken.hasPrefix("n") || token.hasPrefix("♮") {
            return ParseResult(
                accidental: .natural,
                octaveText: String(token.dropFirst())
            )
        }

        if normalizedToken.hasPrefix("natural") {
            return ParseResult(
                accidental: .natural,
                octaveText: String(token.dropFirst("natural".count))
            )
        }

        return ParseResult(
            accidental: .natural,
            octaveText: token
        )
    }
}

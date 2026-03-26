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
    case invalidKeySignature(String)
    case invalidPitch(String)
    case invalidDuration(String)

    var description: String {
        switch self {
        case let .missingField(fieldName):
            return "Missing required staff score field: \(fieldName)"
        case let .invalidClef(value):
            return "Invalid staff clef token: \(value)"
        case let .invalidKeySignature(value):
            return "Invalid staff key signature token: \(value)"
        case let .invalidPitch(value):
            return "Invalid staff pitch token: \(value)"
        case let .invalidDuration(value):
            return "Invalid staff duration token: \(value)"
        }
    }
}

struct StaffKeySignatureDTO: Equatable, Sendable {
    var fifths: Int

    static let natural = StaffKeySignatureDTO()

    init(
        fifths: Int = 0
    ) {
        self.fifths = fifths
    }

    func resolve() throws -> StaffKeySignature {
        try StaffKeySignature.parse(fifths: fifths)
    }
}

struct StaffMeasureDTO: Equatable, Sendable {
    var notes: [StaffScoreNoteDTO]

    init(notes: [StaffScoreNoteDTO]) {
        self.notes = notes
    }

    func resolve() throws -> StaffMeasure {
        StaffMeasure(notes: try notes.map { try $0.resolve() })
    }
}

struct StaffScoreDTO: Equatable, Sendable {
    var clef: String
    var keySignature: StaffKeySignatureDTO
    var measures: [StaffMeasureDTO]

    init(
        clef: String,
        keySignature: StaffKeySignatureDTO = .natural,
        measures: [StaffMeasureDTO]
    ) {
        self.clef = clef
        self.keySignature = keySignature
        self.measures = measures
    }

    init(
        clef: String,
        keySignature: StaffKeySignatureDTO = .natural,
        notes: [StaffScoreNoteDTO]
    ) {
        self.init(
            clef: clef,
            keySignature: keySignature,
            measures: notes.isEmpty
            ? []
            : [StaffMeasureDTO(notes: notes)]
        )
    }

    func resolve() throws -> StaffScore {
        StaffScore(
            clef: try StaffClef.parse(token: clef),
            keySignature: try keySignature.resolve(),
            measures: try measures.map { try $0.resolve() }
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

extension StaffKeySignatureDTO: Codable {
    private enum EnglishCodingKeys: String, CodingKey {
        case fifths
    }

    private enum ChineseCodingKeys: String, CodingKey {
        case fifths = "升降号个数"
    }

    init(from decoder: Decoder) throws {
        if let singleValueContainer = try? decoder.singleValueContainer() {
            if let fifths = try? singleValueContainer.decode(Int.self) {
                self.init(fifths: fifths)
                return
            }

            if let token = try? singleValueContainer.decode(String.self) {
                self = StaffKeySignatureDTO(
                    fifths: try StaffKeySignature.parse(token: token).fifths
                )
                return
            }
        }

        let englishContainer = try decoder.container(keyedBy: EnglishCodingKeys.self)
        let chineseContainer = try decoder.container(keyedBy: ChineseCodingKeys.self)

        if let fifths = try englishContainer.decodeIfPresent(Int.self, forKey: .fifths) {
            self.init(fifths: fifths)
            return
        }

        if let token = try englishContainer.decodeIfPresent(String.self, forKey: .fifths) {
            self = StaffKeySignatureDTO(
                fifths: try StaffKeySignature.parse(token: token).fifths
            )
            return
        }

        if let fifths = try chineseContainer.decodeIfPresent(Int.self, forKey: .fifths) {
            self.init(fifths: fifths)
            return
        }

        if let token = try chineseContainer.decodeIfPresent(String.self, forKey: .fifths) {
            self = StaffKeySignatureDTO(
                fifths: try StaffKeySignature.parse(token: token).fifths
            )
            return
        }

        throw StaffScoreDecodingError.missingField("fifths/升降号个数")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EnglishCodingKeys.self)
        try container.encode(fifths, forKey: .fifths)
    }
}

extension StaffMeasureDTO: Codable {
    private enum EnglishCodingKeys: String, CodingKey {
        case notes
    }

    private enum ChineseCodingKeys: String, CodingKey {
        case notes = "音符"
    }

    init(from decoder: Decoder) throws {
        if let singleValueContainer = try? decoder.singleValueContainer(),
           let notes = try? singleValueContainer.decode([StaffScoreNoteDTO].self) {
            self.init(notes: notes)
            return
        }

        let englishContainer = try decoder.container(keyedBy: EnglishCodingKeys.self)
        let chineseContainer = try decoder.container(keyedBy: ChineseCodingKeys.self)

        let decodedNotes: [StaffScoreNoteDTO] = try StaffScoreDecodeSupport.decodeRequiredValue(
            englishContainer: englishContainer,
            englishKey: .notes,
            chineseContainer: chineseContainer,
            chineseKey: .notes,
            fieldName: "notes/音符"
        )
        self.init(notes: decodedNotes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EnglishCodingKeys.self)
        try container.encode(notes, forKey: .notes)
    }
}

extension StaffScoreDTO: Codable {
    private enum EnglishCodingKeys: String, CodingKey {
        case clef
        case keySignature
        case measures
        case notes
    }

    private enum ChineseCodingKeys: String, CodingKey {
        case clef = "谱号"
        case keySignature = "调号"
        case measures = "小节"
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
        keySignature = try StaffScoreDecodeSupport.decodeOptionalValue(
            englishContainer: englishContainer,
            englishKey: .keySignature,
            chineseContainer: chineseContainer,
            chineseKey: .keySignature
        ) ?? .natural

        if let decodedMeasures: [StaffMeasureDTO] = try StaffScoreDecodeSupport.decodeOptionalValue(
            englishContainer: englishContainer,
            englishKey: .measures,
            chineseContainer: chineseContainer,
            chineseKey: .measures
        ) {
            measures = decodedMeasures
            return
        }

        if let legacyNotes: [StaffScoreNoteDTO] = try StaffScoreDecodeSupport.decodeOptionalValue(
            englishContainer: englishContainer,
            englishKey: .notes,
            chineseContainer: chineseContainer,
            chineseKey: .notes
        ) {
            measures = legacyNotes.isEmpty
                ? []
                : [StaffMeasureDTO(notes: legacyNotes)]
            return
        }

        throw StaffScoreDecodingError.missingField("measures/小节 or notes/音符")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EnglishCodingKeys.self)
        try container.encode(clef, forKey: .clef)
        try container.encode(keySignature, forKey: .keySignature)
        try container.encode(measures, forKey: .measures)
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
    static func decodeOptionalValue<Value: Decodable, EnglishKey: CodingKey, ChineseKey: CodingKey>(
        englishContainer: KeyedDecodingContainer<EnglishKey>,
        englishKey: EnglishKey,
        chineseContainer: KeyedDecodingContainer<ChineseKey>,
        chineseKey: ChineseKey
    ) throws -> Value? {
        if let value = try englishContainer.decodeIfPresent(Value.self, forKey: englishKey) {
            return value
        }

        if let value = try chineseContainer.decodeIfPresent(Value.self, forKey: chineseKey) {
            return value
        }

        return nil
    }

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

    static func compactKeySignatureToken(_ token: String) -> String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
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

private extension StaffKeySignature {
    static func parse(fifths: Int) throws -> StaffKeySignature {
        guard StaffKeySignature.supportedFifthsRange.contains(fifths) else {
            throw StaffScoreDecodingError.invalidKeySignature(String(fifths))
        }

        return StaffKeySignature(fifths: fifths)
    }

    static func parse(token: String) throws -> StaffKeySignature {
        let compactToken = StaffScoreDecodeSupport.compactKeySignatureToken(token)

        if let fifths = Int(compactToken) {
            return try parse(fifths: fifths)
        }

        switch compactToken {
        case "", "c", "natural", "none", "无调号", "无升降", "0升", "0降",
                "0sharp", "0sharps", "0flat", "0flats":
            return .natural
        case "g", "1升", "1sharp", "1sharps":
            return try parse(fifths: 1)
        case "d", "2升", "2sharp", "2sharps":
            return try parse(fifths: 2)
        case "a", "3升", "3sharp", "3sharps":
            return try parse(fifths: 3)
        case "e", "4升", "4sharp", "4sharps":
            return try parse(fifths: 4)
        case "b", "5升", "5sharp", "5sharps":
            return try parse(fifths: 5)
        case "f#", "fsharp", "6升", "6sharp", "6sharps":
            return try parse(fifths: 6)
        case "c#", "csharp", "7升", "7sharp", "7sharps":
            return try parse(fifths: 7)
        case "f", "1降", "1flat", "1flats":
            return try parse(fifths: -1)
        case "bb", "bflat", "2降", "2flat", "2flats":
            return try parse(fifths: -2)
        case "eb", "eflat", "3降", "3flat", "3flats":
            return try parse(fifths: -3)
        case "ab", "aflat", "4降", "4flat", "4flats":
            return try parse(fifths: -4)
        case "db", "dflat", "5降", "5flat", "5flats":
            return try parse(fifths: -5)
        case "gb", "gflat", "6降", "6flat", "6flats":
            return try parse(fifths: -6)
        case "cb", "cflat", "7降", "7flat", "7flats":
            return try parse(fifths: -7)
        default:
            throw StaffScoreDecodingError.invalidKeySignature(token)
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

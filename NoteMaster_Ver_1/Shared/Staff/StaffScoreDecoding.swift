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

        if let fifths = Self.decodeFifthsValue(
            from: englishContainer,
            key: .fifths
        ) {
            self.init(fifths: fifths)
            return
        }

        if let fifths = Self.decodeFifthsValue(
            from: chineseContainer,
            key: .fifths
        ) {
            self.init(fifths: fifths)
            return
        }

        throw StaffScoreDecodingError.missingField("fifths/升降号个数")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EnglishCodingKeys.self)
        try container.encode(fifths, forKey: .fifths)
    }

    // keyed 容器里的 fifths 可能是 Int，也可能是命名调号字符串；
    // 这里显式按两种类型依次尝试，避免 decodeIfPresent(Int.self, ...) 在字符串场景下提前抛 typeMismatch。
    private static func decodeFifthsValue<Keys: CodingKey>(
        from container: KeyedDecodingContainer<Keys>,
        key: Keys
    ) -> Int? {
        if let fifths = try? container.decode(Int.self, forKey: key) {
            return fifths
        }

        if let token = try? container.decode(String.self, forKey: key) {
            return try? StaffKeySignature.parse(token: token).fifths
        }

        return nil
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

private enum StaffKeySignatureTokenParser {
    private enum TonalityMode: Sendable {
        case major
        case minor
    }

    private struct NamedTonality: Sendable {
        var tonicToken: String
        var mode: TonalityMode
    }

    private static let naturalAliases: Set<String> = [
        "",
        "natural",
        "none",
        "无调号",
        "无升降"
    ]

    private static let countAliases: [String: Int] = [
        "0升": 0,
        "0降": 0,
        "0sharp": 0,
        "0sharps": 0,
        "0flat": 0,
        "0flats": 0,
        "1升": 1,
        "1sharp": 1,
        "1sharps": 1,
        "2升": 2,
        "2sharp": 2,
        "2sharps": 2,
        "3升": 3,
        "3sharp": 3,
        "3sharps": 3,
        "4升": 4,
        "4sharp": 4,
        "4sharps": 4,
        "5升": 5,
        "5sharp": 5,
        "5sharps": 5,
        "6升": 6,
        "6sharp": 6,
        "6sharps": 6,
        "7升": 7,
        "7sharp": 7,
        "7sharps": 7,
        "1降": -1,
        "1flat": -1,
        "1flats": -1,
        "2降": -2,
        "2flat": -2,
        "2flats": -2,
        "3降": -3,
        "3flat": -3,
        "3flats": -3,
        "4降": -4,
        "4flat": -4,
        "4flats": -4,
        "5降": -5,
        "5flat": -5,
        "5flats": -5,
        "6降": -6,
        "6flat": -6,
        "6flats": -6,
        "7降": -7,
        "7flat": -7,
        "7flats": -7
    ]

    private static let majorFifthsByCanonicalTonic: [String: Int] = [
        "c": 0,
        "g": 1,
        "d": 2,
        "a": 3,
        "e": 4,
        "b": 5,
        "f#": 6,
        "c#": 7,
        "f": -1,
        "bb": -2,
        "eb": -3,
        "ab": -4,
        "db": -5,
        "gb": -6,
        "cb": -7
    ]

    private static let namedTonalitySuffixes: [(suffix: String, mode: TonalityMode)] = [
        ("major", .major),
        ("大调", .major),
        ("minor", .minor),
        ("小调", .minor)
    ]

    static func parse(token: String) throws -> StaffKeySignature {
        let compactToken = StaffScoreDecodeSupport.compactKeySignatureToken(token)

        if let fifths = Int(compactToken) {
            return try StaffKeySignature.parse(fifths: fifths)
        }

        if naturalAliases.contains(compactToken) {
            return .natural
        }

        if let fifths = countAliases[compactToken] {
            return try StaffKeySignature.parse(fifths: fifths)
        }

        // 继续兼容 bare tonic（如 "d" / "a"）；
        // 显式 major/minor 名称则走下方的 tonality 解析分支，避免把 mode 语义揉进模糊字符串裁剪。
        if let canonicalTonic = canonicalMajorTonicToken(from: compactToken),
           let fifths = majorFifthsByCanonicalTonic[canonicalTonic] {
            return try StaffKeySignature.parse(fifths: fifths)
        }

        if let namedTonality = parseNamedTonality(from: compactToken) {
            switch namedTonality.mode {
            case .major:
                guard
                    let canonicalTonic = canonicalMajorTonicToken(
                        from: namedTonality.tonicToken
                    ),
                    let fifths = majorFifthsByCanonicalTonic[canonicalTonic]
                else {
                    break
                }
                return try StaffKeySignature.parse(fifths: fifths)
            case .minor:
                break
            }
        }

        throw StaffScoreDecodingError.invalidKeySignature(token)
    }

    private static func parseNamedTonality(
        from compactToken: String
    ) -> NamedTonality? {
        for (suffix, mode) in namedTonalitySuffixes where compactToken.hasSuffix(suffix) {
            let tonicToken = String(compactToken.dropLast(suffix.count))
            guard !tonicToken.isEmpty else {
                return nil
            }

            return NamedTonality(
                tonicToken: tonicToken,
                mode: mode
            )
        }

        return nil
    }

    private static func canonicalMajorTonicToken(
        from token: String
    ) -> String? {
        switch token {
        case "c", "g", "d", "a", "e", "b", "f#", "c#", "f", "bb", "eb", "ab", "db", "gb", "cb":
            return token
        case "fsharp", "升f":
            return "f#"
        case "csharp", "升c":
            return "c#"
        case "bflat", "降b":
            return "bb"
        case "eflat", "降e":
            return "eb"
        case "aflat", "降a":
            return "ab"
        case "dflat", "降d":
            return "db"
        case "gflat", "降g":
            return "gb"
        case "cflat", "降c":
            return "cb"
        default:
            return nil
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
        try StaffKeySignatureTokenParser.parse(token: token)
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

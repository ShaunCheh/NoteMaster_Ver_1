# 20260326_150637_phase1_key_signature_domain_and_decoding

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_150637`
- 记录范围：`调号支持` 的阶段 1 实施
- 本次目标：先把 `StaffScore` 从 `clef + notes` 升级为 `clef + keySignature + measures`，并把 JSON 解码边界同步升级
- 根因结论：当前五线谱链路虽然已经能画 `clef + notehead`，但共享领域模型还没有地方挂 `keySignature` 和 `measure` 语义；如果直接从 scene builder 硬做调号，后续临时记号上下文、小节内 reset、fixture 验证都会失去真相源
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScore.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift`

## 本次完成的修改

1. 新增 `StaffKeySignature`，把调号真相统一收口为 `fifths: Int`。
2. 新增 `StaffMeasure`，为后续“小节内临时记号上下文”和“跨小节 reset”预留结构。
3. `StaffScore` 升级为 `clef + keySignature + measures`，同时保留 `notes` 的过渡期兼容投影。
4. `StaffScoreDecoding` 新增 `StaffKeySignatureDTO`、`StaffMeasureDTO`，支持 `keySignature + measures` 的 canonical JSON 形状。
5. 保留 legacy `notes` 解码入口，旧 JSON 会自动包装成单小节，避免当前 scene builder / validation / fixture 一起被拖拽重写。
6. 默认 demo fixture 已切到新的 canonical JSON 形状，让阶段 1 的新模型真正进入共享解码链路。

## 修改 1：`StaffScore` 从平铺 notes 升级为 `keySignature + measures`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScore.swift
// 函数/成员: StaffScore
// 功能说明: 修改前 StaffScore 只承载 clef 和平铺 notes；
// 调号没有挂载点，小节也没有结构容器，后续没法从共享层表达“调号默认升降”和“小节内临时记号 reset”。
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScore.swift
// 函数/成员: StaffKeySignature / StaffMeasure / StaffScore.init(clef:keySignature:measures:) / StaffScore.init(clef:keySignature:notes:) / StaffScore.notes
// 功能说明: 修改后共享领域模型正式引入调号与小节语义；
// 同时保留 notes 平铺投影，确保阶段 1 只改领域边界，不把现有 scene builder 和验证器一起拖入大改。
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
        measures.flatMap(\\.notes)
    }

    var isEmpty: Bool {
        measures.allSatisfy(\\.isEmpty)
    }
}
```

## 修改 2：`StaffScoreDecoding` 支持 `keySignature + measures`，并兼容 legacy `notes`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDecodingError / StaffScoreDTO / StaffScoreDTO.resolve() / StaffScoreDTO.Codable
// 功能说明: 修改前 DTO 边界只支持 clef + notes；
// 一旦要接调号和小节，就只能继续把字符串解析逻辑往 renderer 或 controller 挤。
enum StaffScoreDecodingError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingField(String)
    case invalidClef(String)
    case invalidPitch(String)
    case invalidDuration(String)
}

struct StaffScoreDTO: Equatable, Sendable {
    var clef: String
    var notes: [StaffScoreNoteDTO]

    func resolve() throws -> StaffScore {
        StaffScore(
            clef: try StaffClef.parse(token: clef),
            notes: try notes.map { try $0.resolve() }
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
        ...
        notes = try StaffScoreDecodeSupport.decodeRequiredValue(
            englishContainer: englishContainer,
            englishKey: .notes,
            chineseContainer: chineseContainer,
            chineseKey: .notes,
            fieldName: "notes/音符"
        )
    }
}
```

### 修改后：新增 `StaffKeySignatureDTO`、`StaffMeasureDTO` 和 canonical JSON 形状

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDecodingError.invalidKeySignature / StaffKeySignatureDTO / StaffMeasureDTO / StaffScoreDTO.resolve()
// 功能说明: 修改后 DTO 边界正式支持调号和小节；
// keySignature 继续在共享解码边界做字符串/整数归一化，领域层只吃 canonical fifths。
enum StaffScoreDecodingError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingField(String)
    case invalidClef(String)
    case invalidKeySignature(String)
    case invalidPitch(String)
    case invalidDuration(String)
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
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureDTO.Codable / StaffMeasureDTO.Codable / StaffScoreDTO.Codable
// 功能说明: 修改后 decode 入口优先支持 keySignature + measures；
// 同时保留 legacy notes 兼容路径，旧 JSON 会自动包装成单小节，避免当前 demo 和共享调用方立刻全部失效。
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

        ...
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDecodeSupport.decodeOptionalValue(...) / compactKeySignatureToken(...) / StaffKeySignature.parse(fifths:) / parse(token:)
// 功能说明: 修改后共享解码边界补了“可选字段读取”和“调号 token 归一化”；
// 这样 keySignature 既能吃 canonical fifths，也能在边界兼容 G、Bb、1升、2降 这类便捷 token。
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
```

## 修改 3：默认 demo fixture 切到 canonical JSON 形状

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.defaultDemo(clef:) / resolveScore(named:clef:notesJSON:)
// 功能说明: 修改前 fixture 仍然只生成 clef + notes 的旧 JSON 形状；
// 这样阶段 1 的 keySignature / measures 虽然存在，但共享 demo 并没有真正经过新入口。
enum StaffScoreFixtures {
    static func defaultDemo(clef: StaffClef = .treble) -> StaffScore {
        resolveScore(
            named: "default-demo",
            clef: clef,
            notesJSON: """
            [
              { "pitch": "e4",  "duration": "quarter" },
              { "pitch": "f#4", "duration": "quarter" },
              { "pitch": "g4",  "duration": "quarter" },
              { "pitch": "bb4", "duration": "half" },
              { "pitch": "c5",  "duration": "quarter" },
              { "pitch": "d5",  "duration": "quarter" },
              { "pitch": "e5",  "duration": "half" },
              { "pitch": "f5",  "duration": "whole" }
            ]
            """
        )
    }

    private static func resolveScore(
        named fixtureName: String,
        clef: StaffClef,
        notesJSON: String
    ) -> StaffScore {
        let json = \"\"\"
        {
          \"clef\": \"\\(clef.token)\",
          \"notes\": \\(notesJSON)
        }
        \"\"\"
        ...
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.defaultDemo(clef:) / resolveScore(named:clef:keySignature:notesJSON:)
// 功能说明: 修改后 fixture 直接走 canonical 的 keySignature + measures JSON 形状；
// 这样平台 demo 和后续 validation 都会自然吃到阶段 1 的新领域模型，而不是继续绕 legacy notes 入口。
enum StaffScoreFixtures {
    static func defaultDemo(clef: StaffClef = .treble) -> StaffScore {
        resolveScore(
            named: "default-demo",
            clef: clef,
            keySignature: .natural,
            notesJSON: """
            [
              { "pitch": "e4",  "duration": "quarter" },
              { "pitch": "f#4", "duration": "quarter" },
              { "pitch": "g4",  "duration": "quarter" },
              { "pitch": "bb4", "duration": "half" },
              { "pitch": "c5",  "duration": "quarter" },
              { "pitch": "d5",  "duration": "quarter" },
              { "pitch": "e5",  "duration": "half" },
              { "pitch": "f5",  "duration": "whole" }
            ]
            """
        )
    }

    private static func resolveScore(
        named fixtureName: String,
        clef: StaffClef,
        keySignature: StaffKeySignature,
        notesJSON: String
    ) -> StaffScore {
        let json = \"\"\"
        {
          \"clef\": \"\\(clef.token)\",
          \"keySignature\": {
            \"fifths\": \\(keySignature.fifths)
          },
          \"measures\": [
            {
              \"notes\": \\(notesJSON)
            }
          ]
        }
        \"\"\"

        do {
            return try StaffScore.decode(from: json)
        } catch {
            assertionFailure(
                \"Failed to decode staff score fixture '\\(fixtureName)': \\(error)\"
            )
            return StaffScore(
                clef: clef,
                notes: []
            )
        }
    }
}
```

## 修改结果说明

- 阶段 1 只改“领域模型 + 解码边界”，没有改 `StaffSceneBuilder`、`StaffPitchLayout`、`StaffSceneProvider` 的调号布局逻辑。
- 当前共享层已经具备：
- `StaffKeySignature(fifths:)` 作为调号真相源
- `StaffMeasure` 作为小节语义容器
- `StaffScore.notes` 作为过渡期兼容投影
- `StaffScoreDTO` 同时兼容 canonical `measures` 与 legacy `notes`
- 这一步之后，后续阶段 2 可以开始安全地把“调号布局”和“临时记号上下文”从 `StaffPitchLayout` 中剥离出来，而不必再回头修改 DTO 入口。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
- `NoteMaster_Ver_1/Shared/Staff/StaffScore.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift`

2. 执行以下静态校验通过：

```bash
# 文件路径: 项目根目录（系统命令）
# 函数/成员: xcrun swiftc -typecheck
# 功能说明: 修改后对 Shared/Fretboard、Shared/Controls、Shared/Staff 与 iOS/macOS 入口做静态类型校验，确认调号阶段 1 代码可编译。
xcrun swiftc -typecheck \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  NoteMaster_Ver_1/Shared/Controls/*.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift \
  NoteMaster_Ver_1/Platform/iOS/Controls/*.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift \
  NoteMaster_Ver_1/Platform/macOS/Controls/*.swift
```

3. 额外执行了新旧解码入口兼容验证，结果如下：

```bash
# 文件路径: 项目根目录（系统命令）
# 函数/成员: StaffScore.decode(from:) / StaffScoreFixtures.defaultDemo(clef:)
# 功能说明: 修改后通过临时命令行入口验证 canonical measures、legacy notes 和共享 fixture 三条路径都能正确落到新 StaffScore 结构。
legacy measures=1 fifths=0 notes=1
canonical measures=2 fifths=-2 notes=2
fixture measures=1 fifths=0 notes=8
```

4. 当前仍未覆盖的能力：
- 还没有开始实现调号 glyph 的谱面布局
- 还没有把 accidental 的显示决策从 `StaffPitchLayout` 迁出到上下文层
- 还没有做小节内临时记号状态与跨小节 reset 的 scene 逻辑

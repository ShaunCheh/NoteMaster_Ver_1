# 20260326_173854_phase4_minor_mode_extension_reserve

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_173854`
- 记录范围：`调名输入支持` 的阶段 4 实施
- 本次目标：在 DTO 调号解析边界为未来 `minor/小调` 支持预留清晰扩展口，但本轮仍保持共享领域模型与渲染主链只围绕 `StaffKeySignature(fifths:)` 工作，不把 `mode` 提前引进领域层
- 根因结论：阶段 1 已经把命名调号输入收口到 `StaffScoreDecoding.swift`，但当时对 `minor/小调` 只是“识别 suffix 后直接 break 再统一报 invalid”；这意味着结构上虽然没有堵死未来小调支持，但扩展口仍然是隐式的。更关键的是，keyed 对象路径里的 `decodeFifthsValue(...)` 之前会用 `try?` 吞掉字符串调号解析错误，导致 `{ "fifths": "F# minor" }` 这种输入不是返回真正的“当前 mode 未支持”，而是错误降级成 `missingField("fifths/升降号个数")`。阶段 4 要解决的根因，就是把“调式支持目录”和“字段存在时的原始调号错误传播”都显式化
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

## 本次完成的修改

1. `StaffScoreDecodingError` 新增 `unsupportedKeySignatureMode(String)`，让“当前未实现的小调输入”有单独错误语义，不再混在 `invalidKeySignature` 里。
2. `StaffKeySignatureTokenParser` 增加 `bareTokenCompatibilityMode`、`supportedFifthsByMode`、`parseBareCompatibleTonality(...)`、`resolveNamedTonality(...)`，把 bare token 兼容策略和未来调式支持目录显式收束到 DTO 边界。
3. `StaffKeySignatureDTO.decodeFifthsValue(...)` 改为 `throws` 并在字段存在时保留原始 token 解析错误，修复 keyed `fifths` 字符串路径把真实错误吞成 `missingField` 的问题。
4. `StaffValidationDecodeCase` 从“只支持成功解码”扩展为“成功 + 预期失败”两类 expectation；新增 `A minor`、`A小调`、`{ "fifths": "F# minor" }` 三个当前应拒绝的 decode case。
5. `manualChecklist(...)` 同步写入阶段 4 边界：`a` 仍按 `A大调` 兼容，而 `A minor / A小调` 当前会在 decode 边界明确拒绝。

## 修改 1：为“当前不支持的小调输入”补单独错误语义

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDecodingError
// 功能说明: 修改前调号解析错误只有 invalidKeySignature；
// 对于未来的 minor/小调，解析器只能在逻辑上 break 掉，无法明确表达“token 合法但 mode 当前未实现”。
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDecodingError
// 功能说明: 修改后为调式未实现增加单独错误类型；
// 这样 "A minor" / "A小调" 这类输入可以被明确标记为“当前 mode 未支持”，而不是与非法调号 token 混在一起。
enum StaffScoreDecodingError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingField(String)
    case invalidClef(String)
    case invalidKeySignature(String)
    case unsupportedKeySignatureMode(String)
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
        case let .unsupportedKeySignatureMode(value):
            return "Unsupported staff key signature mode token: \(value)"
        case let .invalidPitch(value):
            return "Invalid staff pitch token: \(value)"
        case let .invalidDuration(value):
            return "Invalid staff duration token: \(value)"
        }
    }
}
```

## 修改 2：把 bare token 兼容策略和未来调式支持目录显式收束到 DTO 解析层

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureTokenParser.parse(token:) / StaffKeySignatureTokenParser.canonicalMajorTonicToken(from:)
// 功能说明: 修改前 bare token 是通过 canonicalMajorTonicToken 隐式兼容为大调；
// 命名调号虽然能识别 major/minor suffix，但 .minor 分支只会 break，之后统一报 invalidKeySignature。
private enum StaffKeySignatureTokenParser {
    private enum TonalityMode: Sendable {
        case major
        case minor
    }

    private struct NamedTonality: Sendable {
        var tonicToken: String
        var mode: TonalityMode
    }

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

    static func parse(token: String) throws -> StaffKeySignature {
        let compactToken = StaffScoreDecodeSupport.compactKeySignatureToken(token)

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
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureTokenParser.parse(token:) /
// StaffKeySignatureTokenParser.parseBareCompatibleTonality(from:) /
// StaffKeySignatureTokenParser.resolveNamedTonality(_:originalToken:) /
// StaffKeySignatureTokenParser.canonicalTonicToken(from:)
// 功能说明: 修改后 bare token 兼容策略、mode 支持目录、以及 named tonality 解析路径都被显式抽出来；
// 当前 bare token 固定按 major 解释，future minor 只需要补 .minor 映射，不必改领域模型或渲染链。
private enum StaffKeySignatureTokenParser {
    private enum TonalityMode: String, Sendable {
        case major
        case minor
    }

    private struct NamedTonality: Sendable {
        var tonicToken: String
        var mode: TonalityMode
    }

    // bare tonic 当前继续兼容为大调；
    // 未来若补小调支持，去歧义策略只需要收敛在 DTO 边界，不会扩散到领域层。
    private static let bareTokenCompatibilityMode: TonalityMode = .major

    // 目前只有 major 真正落地到 fifths，minor 仅保留 mode 扩展口；
    // 后续支持小调时，只需要补齐 .minor 对应映射，而不必改动领域模型。
    private static let supportedFifthsByMode: [TonalityMode: [String: Int]] = [
        .major: [
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
    ]

    static func parse(token: String) throws -> StaffKeySignature {
        let compactToken = StaffScoreDecodeSupport.compactKeySignatureToken(token)

        if let bareTonality = parseBareCompatibleTonality(from: compactToken) {
            return try resolveNamedTonality(
                bareTonality,
                originalToken: token
            )
        }

        if let namedTonality = parseNamedTonality(from: compactToken) {
            return try resolveNamedTonality(
                namedTonality,
                originalToken: token
            )
        }

        throw StaffScoreDecodingError.invalidKeySignature(token)
    }

    private static func parseBareCompatibleTonality(
        from compactToken: String
    ) -> NamedTonality? {
        guard canonicalTonicToken(from: compactToken) != nil else {
            return nil
        }

        return NamedTonality(
            tonicToken: compactToken,
            mode: bareTokenCompatibilityMode
        )
    }

    private static func resolveNamedTonality(
        _ namedTonality: NamedTonality,
        originalToken: String
    ) throws -> StaffKeySignature {
        guard let canonicalTonic = canonicalTonicToken(
            from: namedTonality.tonicToken
        ) else {
            throw StaffScoreDecodingError.invalidKeySignature(originalToken)
        }

        guard let fifthsByCanonicalTonic = supportedFifthsByMode[namedTonality.mode] else {
            throw StaffScoreDecodingError.unsupportedKeySignatureMode(originalToken)
        }

        guard let fifths = fifthsByCanonicalTonic[canonicalTonic] else {
            throw StaffScoreDecodingError.invalidKeySignature(originalToken)
        }

        return try StaffKeySignature.parse(fifths: fifths)
    }
}
```

## 修改 3：修复 keyed `fifths` 路径吞掉原始调号错误的问题

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureDTO.init(from:) / StaffKeySignatureDTO.decodeFifthsValue(from:key:)
// 功能说明: 修改前 keyed 容器里的 fifths 在字符串场景下会使用 try? 吞掉解析错误；
// 这会让 { "fifths": "F# minor" } 这种“字段存在但 mode 未支持”的场景，错误退化成 missingField。
init(from decoder: Decoder) throws {
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureDTO.init(from:) / StaffKeySignatureDTO.decodeFifthsValue(from:key:)
// 功能说明: 修改后 decodeFifthsValue 改成 throws；
// 只要 key 已存在，就会把字符串 token 的原始解析错误继续上抛，避免被误判成 missingField。
init(from decoder: Decoder) throws {
    let englishContainer = try decoder.container(keyedBy: EnglishCodingKeys.self)
    let chineseContainer = try decoder.container(keyedBy: ChineseCodingKeys.self)

    if let fifths = try Self.decodeFifthsValue(
        from: englishContainer,
        key: .fifths
    ) {
        self.init(fifths: fifths)
        return
    }

    if let fifths = try Self.decodeFifthsValue(
        from: chineseContainer,
        key: .fifths
    ) {
        self.init(fifths: fifths)
        return
    }

    throw StaffScoreDecodingError.missingField("fifths/升降号个数")
}

private static func decodeFifthsValue<Keys: CodingKey>(
    from container: KeyedDecodingContainer<Keys>,
    key: Keys
) throws -> Int? {
    guard container.contains(key) else {
        return nil
    }

    if let fifths = try? container.decode(Int.self, forKey: key) {
        return fifths
    }

    if let token = try? container.decode(String.self, forKey: key) {
        return try StaffKeySignature.parse(token: token).fifths
    }

    return nil
}
```

## 修改 4：验证系统加入“预期失败”decode case，固化阶段 4 边界

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationDecodeCase / StaffValidationRunner.makeDecodeCases() / StaffValidationRunner.validate(_:)
// 功能说明: 修改前 decode 验证只能表达“应该成功”的命名调号场景；
// 像 A minor / A小调 / F# minor 这种当前必须拒绝的输入，无法进入自动回归护栏。
private struct StaffValidationDecodeCase {
    var name: String
    var json: String
    var expectedClef: StaffClef
    var expectedKeySignatureFifths: Int
    var expectedMeasureCount: Int
    var expectedNoteCount: Int
}

static func makeDecodeCases() -> [StaffValidationDecodeCase] {
    [
        decodeCase(
            name: "decode-key-a-bare-tonic-inline",
            json: decodeScoreJSON(
                keySignatureField: #""keySignature": "a""#
            ),
            expectedKeySignatureFifths: 3
        ),
        decodeCase(
            name: "decode-key-d-major-english-keyed-fifths",
            json: decodeScoreJSON(
                keySignatureField: #""keySignature": { "fifths": "D大调" }"#
            ),
            expectedKeySignatureFifths: 2
        )
    ]
}

static func validate(_ decodeCase: StaffValidationDecodeCase) -> [StaffValidationIssue] {
    var issues: [StaffValidationIssue] = []

    let score: StaffScore
    do {
        score = try StaffScore.decode(from: decodeCase.json)
    } catch {
        record("命名调号解码失败：\(error)。")
        return issues
    }

    if score.keySignature.fifths != decodeCase.expectedKeySignatureFifths {
        record("key signature fifths 解码错误，期望 \(decodeCase.expectedKeySignatureFifths)，实际 \(score.keySignature.fifths)。")
    }

    return issues
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationDecodeCase / StaffValidationDecodeExpectation /
// StaffValidationRunner.decodeFailureCase(name:json:expectedError:) /
// StaffValidationRunner.makeDecodeCases() / StaffValidationRunner.validate(_:)
// 功能说明: 修改后 decode 验证同时覆盖“应成功”和“应失败”两类场景；
// 既保留 bare token `a -> A大调` 的兼容行为，也把当前未实现的小调拒绝逻辑正式固化到回归护栏。
private struct StaffValidationDecodeCase {
    var name: String
    var json: String
    var expectation: StaffValidationDecodeExpectation
}

private enum StaffValidationDecodeExpectation {
    case success(
        clef: StaffClef,
        keySignatureFifths: Int,
        measureCount: Int,
        noteCount: Int
    )
    case failure(StaffScoreDecodingError)
}

static func makeDecodeCases() -> [StaffValidationDecodeCase] {
    [
        decodeCase(
            name: "decode-key-a-bare-tonic-inline",
            json: decodeScoreJSON(
                keySignatureField: #""keySignature": "a""#
            ),
            expectedKeySignatureFifths: 3
        ),
        decodeFailureCase(
            name: "decode-key-a-minor-en-unsupported",
            json: decodeScoreJSON(
                keySignatureField: #""keySignature": "A minor""#
            ),
            expectedError: .unsupportedKeySignatureMode("A minor")
        ),
        decodeFailureCase(
            name: "decode-key-a-minor-zh-unsupported",
            json: decodeScoreJSON(
                keySignatureField: #""keySignature": "A小调""#
            ),
            expectedError: .unsupportedKeySignatureMode("A小调")
        ),
        decodeFailureCase(
            name: "decode-key-fsharp-minor-keyed-fifths-unsupported",
            json: decodeScoreJSON(
                keySignatureField: #""keySignature": { "fifths": "F# minor" }"#
            ),
            expectedError: .unsupportedKeySignatureMode("F# minor")
        )
    ]
}

static func validate(_ decodeCase: StaffValidationDecodeCase) -> [StaffValidationIssue] {
    var issues: [StaffValidationIssue] = []

    switch decodeCase.expectation {
    case let .success(
        expectedClef,
        expectedKeySignatureFifths,
        expectedMeasureCount,
        expectedNoteCount
    ):
        let score: StaffScore
        do {
            score = try StaffScore.decode(from: decodeCase.json)
        } catch {
            record("命名调号解码失败：\(error)。")
            return issues
        }

        if score.clef != expectedClef {
            record("clef 解码错误，期望 \(expectedClef)，实际 \(score.clef)。")
        }

        if score.keySignature.fifths != expectedKeySignatureFifths {
            record("key signature fifths 解码错误，期望 \(expectedKeySignatureFifths)，实际 \(score.keySignature.fifths)。")
        }

        if score.measures.count != expectedMeasureCount {
            record("measure 数量错误，期望 \(expectedMeasureCount)，实际 \(score.measures.count)。")
        }

        if score.notes.count != expectedNoteCount {
            record("note 数量错误，期望 \(expectedNoteCount)，实际 \(score.notes.count)。")
        }
    case let .failure(expectedError):
        do {
            _ = try StaffScore.decode(from: decodeCase.json)
            record("命名调号解码本应失败，但实际成功。")
        } catch let actualError as StaffScoreDecodingError {
            if actualError != expectedError {
                record("命名调号解码错误不匹配，期望 \(expectedError)，实际 \(actualError)。")
            }
        } catch {
            record("命名调号解码错误类型不匹配，期望 \(expectedError)，实际 \(error)。")
        }
    }

    return issues
}
```

## 修改 5：手工回归清单同步 bare token 与当前小调拒绝边界

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.manualChecklist(for:)
// 功能说明: 修改前手工清单只强调命名大调输入与 keyed fifths 等价，
// 没有把 bare token `a` 的兼容语义与当前小调拒绝边界明确写出来。
var checklist = [
    "启动 App，确认默认五线谱已恢复完整记谱显示，且默认 demo 已切到命名调号输入示例：当前应能看到 `D大调` 对应的 key signature，同时保留 stem，以及需要时的 accidental / ledger line。",
    "将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 major circle-of-fifths 参考谱例：`C / G / D / A / E / B / F# / C# / F / Bb / Eb / Ab / Db / Gb / Cb`，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确。",
    "把调号输入临时切成命名形式，例如 `D大调`、`A大调`、`D major`、`A major`，以及 keyed 对象形式 `{ \"fifths\": \"D大调\" }`；确认 scene 结果与直接传 `fifths` 等价。"
]

case .commandLine:
    checklist.append("命令行已覆盖命名调号 decode 回归与共享层 scene fixture，不覆盖 iOS/macOS 运行时渲染、字体注册与交互。")
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.manualChecklist(for:)
// 功能说明: 修改后手工清单与命令行说明都显式写入阶段 4 的边界；
// 这样后续继续扩展小调时，可以明确知道当前兼容策略与预期拒绝分支是什么。
var checklist = [
    "启动 App，确认默认五线谱已恢复完整记谱显示，且默认 demo 已切到命名调号输入示例：当前应能看到 `D大调` 对应的 key signature，同时保留 stem，以及需要时的 accidental / ledger line。",
    "将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 major circle-of-fifths 参考谱例：`C / G / D / A / E / B / F# / C# / F / Bb / Eb / Ab / Db / Gb / Cb`，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确。",
    "把调号输入临时切成命名形式，例如 `D大调`、`A大调`、`D major`、`A major`，以及 keyed 对象形式 `{ \"fifths\": \"D大调\" }`；确认 scene 结果与直接传 `fifths` 等价。同时确认 bare token `a` 仍按 `A大调` 兼容，而 `A minor / A小调` 当前会在 decode 边界明确拒绝。"
]

case .commandLine:
    checklist.append("命令行已覆盖命名调号 decode 回归、bare token 兼容策略、当前未实现的小调拒绝分支，以及共享层 scene fixture；不覆盖 iOS/macOS 运行时渲染、字体注册与交互。")
```

## 验证过程中暴露并修复的真实问题

- 在第一次运行命令行验证时，新增用例 `decode-key-fsharp-minor-keyed-fifths-unsupported` 失败。
- 实际现象不是“小调被错误接受”，而是 `{ "fifths": "F# minor" }` 被错误报告成 `Missing required staff score field: fifths/升降号个数`。
- 根因是 `StaffKeySignatureDTO.decodeFifthsValue(...)` 用 `try?` 吞掉了 `StaffKeySignature.parse(token:)` 的原始错误，导致 keyed 路径无法保留“mode 未支持”的真实语义。
- 修复后再次验证，错误已变为正确的 `unsupportedKeySignatureMode("F# minor")`，并且完整验证矩阵通过。

## 本阶段明确未修改的边界

- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffScore.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffKeySignatureLayout.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffAccidentalContext.swift`
- 这意味着阶段 4 仍然遵守既定边界：只在 DTO 解码层预留调式扩展口，并通过验证护栏固定当前行为，不把 `mode` 语义提前带入领域模型与渲染主链

## 验证结果

### 静态检查

- `ReadLints` 检查以下文件，结果为无错误：
- `NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 共享层 Swift 类型检查，确认阶段 4 没有引入编译错误。
xcrun swiftc -typecheck \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  NoteMaster_Ver_1/Shared/Controls/*.swift
```

- 结果：通过

### 命令行验证

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 编译并执行 StaffValidationRunner.run(platform: .commandLine)，确认阶段 4 的 bare token 兼容与小调拒绝边界已经进入自动回归。
xcrun swiftc -o /tmp/staff_phase4_check \
  NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  /tmp/staff_phase2_check.swift && \
/tmp/staff_phase4_check
```

- 第一次运行时，`decode-key-fsharp-minor-keyed-fifths-unsupported` 暴露了 keyed `fifths` 错误传播问题，实际错误为 `Missing required staff score field: fifths/升降号个数`
- 修复 `decodeFifthsValue(...)` 的错误传播后再次运行，结果为：`[StaffValidation][commandLine] automated=PASS fixtures=53`
- 结论：阶段 4 完成后，命名大调 decode、bare token `a -> A大调` 兼容、当前小调拒绝分支，以及既有共享层 scene fixture 全部保持通过

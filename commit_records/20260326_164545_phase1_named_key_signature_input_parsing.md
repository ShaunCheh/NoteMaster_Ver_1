# 20260326_164545_phase1_named_key_signature_input_parsing

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_164545`
- 记录范围：`调名输入支持` 的阶段 1 实施
- 本次目标：在不改动共享渲染主链的前提下，让五线谱配置入口支持 `D大调`、`A大调`、`D major`、`A major` 这类命名大调输入，同时保持领域层继续只认 `StaffKeySignature(fifths:)`
- 根因结论：当前共享渲染主链已经围绕 `fifths` 正常工作，真正的缺口在 `StaffScoreDecoding.swift` 的调号输入边界；此外，`keySignature: { "fifths": "D大调" }` 这类 keyed 对象写法原先会被 `decodeIfPresent(Int.self, ...)` 提前打成 `typeMismatch`，后续字符串解析分支根本到不了
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift`

## 本次完成的修改

1. 新增 `StaffKeySignatureTokenParser`，把命名大调解析从零散 `switch` 升级为统一入口。
2. 在不污染领域层的前提下，支持 `bare tonic`、中文调名、英文 `major` 名称、中文 `升/降` 调名写法，以及旧的 `fifths` 数字/计数写法。
3. `StaffKeySignatureDTO.init(from:)` 新增 `decodeFifthsValue(...)`，修复 keyed 对象里的字符串 `fifths` 会被 `typeMismatch` 短路的问题。
4. `StaffKeySignature.parse(token:)` 改为委派给统一解析器，继续保证 decode 结果只收敛成 `StaffKeySignature(fifths:)`。
5. 解析器内部显式保留 `major / minor` 模式分支，但本阶段仍只真正实现 `major`，为后续小调扩展留出边界位置。

## 修改 1：`StaffKeySignatureDTO` 的 keyed `fifths` 解码不再被 `typeMismatch` 短路

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureDTO.init(from:)
// 功能说明: 修改前 keyed 对象写法会先按 Int 解码，再按 String 解码；
// 但当输入是 { "fifths": "D大调" } 这类字符串时，decodeIfPresent(Int.self, ...) 会直接抛 typeMismatch，
// 导致后面的字符串分支根本没有机会执行。
extension StaffKeySignatureDTO: Codable {
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
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureDTO.init(from:) / decodeFifthsValue(from:key:)
// 功能说明: 修改后 keyed 容器里的 fifths 会显式按 Int -> String 两步尝试，
// 这样 { "fifths": "D大调" } 和 { "升降号个数": "A major" } 都能进入命名调号解析，
// 而不会被 decodeIfPresent(Int.self, ...) 提前打成 typeMismatch。
extension StaffKeySignatureDTO: Codable {
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
```

## 修改 2：调号 token 解析从零散 `switch` 升级为统一的命名大调解析器

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignature.parse(token:)
// 功能说明: 修改前 parse(token:) 直接在一个 switch 里维护数字计数、bare tonic 和部分升降 token；
// 它虽然已经能识别 "d" / "a" 这类简写，但没有把“D大调 / A major”这种命名调号输入收口成统一规则，
// 也没有为后续 major/minor 分流留下明确边界。
private extension StaffKeySignature {
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
        case "bb", "bflat", "2降", "2flat", "2flats":
            return try parse(fifths: -2)
        // ... 其余升降调写法仍散落在同一个 switch 中
        default:
            throw StaffScoreDecodingError.invalidKeySignature(token)
        }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureTokenParser.parse(token:) / parseNamedTonality(from:) / canonicalMajorTonicToken(from:) / StaffKeySignature.parse(token:)
// 功能说明: 修改后命名调号解析被收口到独立解析器；
// parse(token:) 只负责委派，真正的输入语义由 major circle-of-fifths 映射、命名后缀识别和 canonical tonic 归一化共同完成。
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
    static func parse(token: String) throws -> StaffKeySignature {
        try StaffKeySignatureTokenParser.parse(token: token)
    }
}
```

## 修改 3：阶段 1 的边界职责保持在 DTO 层，没有侵入共享渲染主链

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignature.parse(token:)
// 功能说明: 修改前调号 token 的解析逻辑和领域层扩展直接耦合在一起；
// 一旦要继续扩 D大调 / A大调 / F# major / Bb major 这类名字，很容易继续把输入格式细节堆进领域扩展内部。
private extension StaffKeySignature {
    static func parse(token: String) throws -> StaffKeySignature {
        // 直接在这里解析各种输入 token
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffKeySignatureTokenParser / StaffKeySignature.parse(token:)
// 功能说明: 修改后领域层仍然只认 fifths，parse(token:) 只保留委派职责；
// 真正的“输入长什么样”被限制在 DTO 解码边界，不会传播进 StaffKeySignatureLayout / StaffAccidentalContext / StaffSceneBuilder。
private enum StaffKeySignatureTokenParser {
    // 命名调号输入边界集中在这里处理
}

private extension StaffKeySignature {
    static func parse(token: String) throws -> StaffKeySignature {
        try StaffKeySignatureTokenParser.parse(token: token)
    }
}
```

## 验证结果

1. 共享层静态类型校验

```bash
# 文件路径: 命令行验证（无源码文件）
# 函数/成员: xcrun swiftc -typecheck
# 功能说明: 对 Shared/Fretboard/*.swift、Shared/Staff/*.swift、Shared/Controls/*.swift 做阶段 1 静态类型校验。
xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift NoteMaster_Ver_1/Shared/Controls/*.swift
```

```text
# 文件路径: 命令行验证结果（无源码文件）
# 函数/成员: xcrun swiftc -typecheck 输出
# 功能说明: 命令执行成功，未产生编译错误输出。
Exit code: 0
```

2. 命名调号解码验证

```swift
// 文件路径: /tmp/staff_phase1_check.swift（临时校验脚本，非仓库文件）
// 函数/成员: Phase1DecodeCheck.main()
// 功能说明: 用最小依赖集直接验证命名调号输入会被正确收敛到 fifths；
// 覆盖 D大调、A大调、D major、A major、Bb major、降B大调、F# major、升F大调，以及 keyed 对象写法。
@main
struct Phase1DecodeCheck {
    static func main() throws {
        let inlineCases: [(token: String, expected: Int)] = [
            ("D大调", 2),
            ("A大调", 3),
            ("D major", 2),
            ("A major", 3),
            ("Bb major", -2),
            ("降B大调", -2),
            ("F# major", 6),
            ("升F大调", 6),
            ("a", 3)
        ]

        let objectCases: [(json: String, expected: Int)] = [
            (
                """
                {
                  "clef": "treble",
                  "keySignature": { "fifths": "D大调" },
                  "notes": [
                    { "pitch": "c4", "duration": "quarter" }
                  ]
                }
                """,
                2
            ),
            (
                """
                {
                  "clef": "treble",
                  "调号": { "升降号个数": "A major" },
                  "音符": [
                    { "音高": "c4", "时值": "quarter" }
                  ]
                }
                """,
                3
            )
        ]

        // ...
    }
}
```

```bash
# 文件路径: 命令行验证（无源码文件）
# 函数/成员: xcrun swiftc /tmp/staff_phase1_check.swift && /tmp/staff_phase1_check
# 功能说明: 用 NotePitch + StaffScore + StaffScoreDecoding 最小依赖集编译并运行临时校验脚本。
xcrun swiftc -o /tmp/staff_phase1_check NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Staff/StaffScore.swift NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift /tmp/staff_phase1_check.swift && /tmp/staff_phase1_check
```

```text
# 文件路径: 命令行验证结果（无源码文件）
# 函数/成员: Phase1DecodeCheck.main() 输出
# 功能说明: 命名调号输入和 keyed 对象写法共 11 组解码断言全部通过。
phase1 decode checks passed: 11 cases
```

3. IDE 诊断

```text
# 文件路径: IDE 诊断（无源码文件）
# 函数/成员: ReadLints
# 功能说明: StaffScoreDecoding.swift 本轮改动无新增 IDE 诊断。
No linter errors found.
```

## 当前阶段结论

- 阶段 1 已经把“D大调 / A大调 这种命名输入支持”真正收口到 DTO 解码边界，而不是把输入格式细节扩散到共享渲染链。
- 当前共享层仍然以 `StaffKeySignature(fifths:)` 作为唯一真相源，`StaffKeySignatureLayout`、`StaffAccidentalContext`、`StaffSceneBuilder` 不需要知道输入时到底写的是 `2` 还是 `D大调`。
- 下一阶段应该继续补 `StaffScoreFixtures.swift` 与 `StaffValidation.swift`，把 `A major` 和命名调号 decode 回归正式纳入共享层验证矩阵。

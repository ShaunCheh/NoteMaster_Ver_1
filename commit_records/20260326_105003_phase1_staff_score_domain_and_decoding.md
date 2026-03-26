# 20260326_105003_phase1_staff_score_domain_and_decoding

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_105003`
- 记录范围：`五线谱音符渲染` 的阶段 1 实施
- 本次目标：先把五线谱的乐谱输入层从“散落的字符串配置”收口为共享层强类型领域模型，并提供 JSON/字符串到领域模型的统一归一化入口
- 根因结论：当前 `Shared/Staff` 只有 `StaffConfiguration -> StaffSceneProvider -> Renderer` 这条 clef 展示链路，没有承接 `clef + notes` 的共享乐谱模型，也没有统一的音高/时值字符串解析边界；如果直接让 controller 或 renderer 消费 `g4`、`四分` 这类字符串，解析职责会泄漏到渲染链路里，后续 treble / bass 定位和 scene builder 也会缺少稳定输入
- 本次实际改动：
  - 新增 `NoteMaster_Ver_1/Shared/Staff/StaffScore.swift`
  - 新增 `NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift`

## 本次完成的修改

1. 新增 `StaffScore`、`StaffScoreNote`、`StaffNoteDuration`，建立五线谱共享领域模型。
2. 新增 `StaffPitch`、`StaffPitchLetter`、`StaffAccidental`，保留“书写音高”语义，而不只是半音值。
3. 新增 `StaffScoreDTO` 与 `StaffScoreDecodingError`，把 `treble / bass`、`g4`、`四分` 这类字符串统一归一化到共享层。
4. 兼容英文 / 中文 JSON key：
   - 根层：`clef` / `谱号`，`notes` / `音符`
   - 音符层：`pitch` / `音高`，`duration` / `时值`
5. 首批时值只收口为 `whole / half / quarter`，为后续 scene builder 和 renderer 预留稳定输入。

## 修改 1：新增五线谱共享领域模型 `StaffScore.swift`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScore.swift
// 函数/成员: 文件级（此前不存在）
// 功能说明: 修改前 Shared/Staff 下还没有承接 clef + notes 的共享乐谱领域模型；
// 五线谱模块只有 clef 展示配置，没有可供后续 scene builder 消费的强类型 score 输入。
// 修改前: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScore.swift
// 函数/成员: StaffScore / StaffScoreNote / StaffNoteDuration
// 功能说明: 修改后新增五线谱共享领域模型，先把 clef 与 notes 收口为强类型输入；
// 时值首批只支持 whole / half / quarter，并提前暴露符干与实心符头语义，供后续 scene builder 直接消费。
struct StaffScore: Equatable, Sendable {
    var clef: StaffClef
    var notes: [StaffScoreNote]

    var isEmpty: Bool {
        notes.isEmpty
    }
}

struct StaffScoreNote: Equatable, Hashable, Sendable {
    var pitch: StaffPitch
    var duration: StaffNoteDuration

    var notePitch: NotePitch {
        pitch.notePitch
    }
}

enum StaffNoteDuration: String, CaseIterable, Equatable, Hashable, Sendable {
    case whole
    case half
    case quarter

    var showsStem: Bool {
        self != .whole
    }

    var usesFilledNotehead: Bool {
        self == .quarter
    }
}
```

## 修改 2：新增 `StaffPitch`，保留书写音高语义而不是只存半音值

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScore.swift
// 函数/成员: 文件级（此前不存在 StaffPitch）
// 功能说明: 修改前 Staff 模块没有自己的书写音高类型；
// 如果直接只存 NotePitch，后续五线谱按 line / space 布局时会丢失字母名和升降记号语义。
// 修改前: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScore.swift
// 函数/成员: StaffPitch / StaffPitchLetter / StaffAccidental / StaffPitch.notePitch
// 功能说明: 修改后新增 StaffPitch，显式保留字母名、升降号和八度；
// 对外仍可投影为 NotePitch，兼容现有共享音高模型，同时为后续谱表定位保留 line / space 真相。
enum StaffPitchLetter: Int, CaseIterable, Equatable, Hashable, Sendable {
    case c = 0
    case d = 1
    case e = 2
    case f = 3
    case g = 4
    case a = 5
    case b = 6
}

enum StaffAccidental: Int, CaseIterable, Equatable, Hashable, Sendable {
    case flat = -1
    case natural = 0
    case sharp = 1
}

struct StaffPitch: Equatable, Hashable, Sendable {
    var letter: StaffPitchLetter
    var accidental: StaffAccidental
    var octave: Int

    var diatonicIndex: Int {
        (octave * 7) + letter.diatonicStepIndex
    }

    var notePitch: NotePitch {
        let absoluteSemitone = (octave * 12)
            + letter.semitoneFromC
            + accidental.semitoneOffset
        let normalizedPitchClassValue = ((absoluteSemitone % 12) + 12) % 12
        let normalizedOctave = (absoluteSemitone - normalizedPitchClassValue) / 12

        return NotePitch(
            pitchClass: PitchClass(rawValue: normalizedPitchClassValue)!,
            octave: normalizedOctave
        )
    }
}
```

## 修改 3：新增 JSON/字符串归一化入口 `StaffScoreDecoding.swift`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: 文件级（此前不存在）
// 功能说明: 修改前 Shared/Staff 下没有统一的 DTO、解码错误模型，也没有把 clef / pitch / duration 字符串
// 归一化为共享层强类型的单一入口；后续如果直接在 controller 写解析，会把边界打散。
// 修改前: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDTO.resolve() / StaffScoreNoteDTO.resolve() / StaffScore.decode(from:)
// 功能说明: 修改后新增 DTO 与共享层 decode 入口，让代码中的 JSON 风格配置先进入 DTO，
// 再统一 resolve 成 StaffScore，避免 controller 或 renderer 直接处理原始字符串。
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

struct StaffScoreNoteDTO: Equatable, Sendable {
    var pitch: String
    var duration: String

    func resolve() throws -> StaffScoreNote {
        StaffScoreNote(
            pitch: try StaffPitch.parse(scientificPitch: pitch),
            duration: try StaffNoteDuration.parse(token: duration)
        )
    }
}

extension StaffScore {
    static func decode(
        from json: String,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> StaffScore {
        try StaffScoreDTO.decode(from: json, using: decoder).resolve()
    }
}
```

## 修改 4：在共享层兼容中英文字段与时值/谱号/音高字符串

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: 文件级（此前不存在解析辅助逻辑）
// 功能说明: 修改前 Shared/Staff 下没有中英文 key 兼容，也没有 clef / duration / pitch 的标准化规则。
// 修改前: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDTO.init(from:) / StaffScoreNoteDTO.init(from:) / StaffClef.parse(token:) / StaffNoteDuration.parse(token:) / StaffPitch.parse(scientificPitch:)
// 功能说明: 修改后统一支持英文 key、中文 key，以及常见谱号 / 时值 / 科学音高记法字符串；
// 解析失败时在共享层直接抛出结构化错误，而不是把非法值放进后续 scene/render 链路。
extension StaffScoreDTO: Codable {
    private enum EnglishCodingKeys: String, CodingKey {
        case clef
        case notes
    }

    private enum ChineseCodingKeys: String, CodingKey {
        case clef = "谱号"
        case notes = "音符"
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
```

## 修改 5：修正音高预处理，保留负八度的 `-`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDecodeSupport.compactPitchToken(_:)
// 功能说明: 修改前如果把音高预处理做成“无差别移除连字符”，像 C-1 这种负八度写法会被错误抹平成 C1，
// 导致共享层在解析科学音高时丢失真实八度信息。
private enum StaffScoreDecodeSupport {
    static func compactPitchToken(_ token: String) -> String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift
// 函数/成员: StaffScoreDecodeSupport.compactPitchToken(_:)
// 功能说明: 修改后只清理空格和下划线，不再移除连字符；
// 这样像 C-1、Bb-1 这类负八度输入仍能被共享层正确解析。
private enum StaffScoreDecodeSupport {
    static func compactPitchToken(_ token: String) -> String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
```

## 修改结果说明

- 阶段 1 只新增共享层领域模型和解码边界，没有修改 `StaffConfiguration`、`StaffSceneProvider`、平台 view 或 controller 接线。
- 这一步的核心收益不是“先把 JSON 读进来”，而是把五线谱后续所有布局和渲染阶段要依赖的输入真相先固定下来：
  - `StaffScore` 负责乐谱内容；
  - `StaffPitch` 负责书写音高；
  - `StaffScoreDTO` 负责字符串边界；
  - `StaffScoreDecodingError` 负责非法输入拒绝。
- 后续阶段 2/3 可以直接围绕这些强类型输入构建 `StaffScene` 和 `StaffSceneBuilder`，而不必在渲染链路里继续处理字符串。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Shared/Staff/StaffScore.swift`
   - `NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift`
2. 执行以下静态校验通过：
   - `xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Staff/*.swift`
3. 尝试执行以下完整工程构建命令时，当前机器未指向完整 Xcode，因此未继续作为本阶段阻塞项：
   - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO`
4. 当前已知未覆盖的运行态验证点：
   - 还未把 `StaffScore` 接入 controller / view；
   - 还未进入 scene builder 和 renderer 阶段；
   - 还未做实际五线谱绘制联调。

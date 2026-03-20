20260320_104548_phase1_note_pitch_and_tuning

# 阶段 1 修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift`
- 新增 `NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift`
- 未修改 `InstrumentType.swift`
- 未修改 `FretboardConfiguration.swift`
- 未修改 `FretboardGeometry.swift`
- 未修改 `FretboardLayer.swift`

## 修改前

### 音高模型文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift
// 函数名：无（文件不存在）
// 功能说明：修改前共享层没有独立的音高模型，无法用结构化数据表达 G3、A2 这类“音级 + 八度”的音高，也无法稳定支持按半音递进。
// 该文件在修改前不存在。
```

### 调弦模型文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift
// 函数名：无（文件不存在）
// 功能说明：修改前共享层没有统一的空弦调弦结构，吉他、四弦贝斯、五弦贝斯的空弦音高没有独立的数据承载位置。
// 该文件在修改前不存在。
```

### 共享层在音乐语义上的现状

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard
// 函数名：无
// 功能说明：修改前共享层只具备乐器类型、布局配置、几何计算和静态渲染，还没有音高模型和调弦模型。
InstrumentType.swift
FretboardConfiguration.swift
FretboardGeometry.swift
FretboardLayer.swift
```

## 修改后

### 新增音高模型 `NotePitch.swift`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift
// 函数名：isAccidental, displayText(using:), advanced(by:), displayText(using:showsOctave:)
// 功能说明：新增音高层，使用 PitchClass + octave 表达音高，并支持判断变化音、按半音递进、生成带八度的文本显示。
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
```

### 新增调弦模型 `InstrumentTuning.swift`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift
// 函数名：init(instrument:openStringsTopToBottom:), stringCount, openStringPitch(for:), standard(for:)
// 功能说明：新增调弦层，明确 openStringsTopToBottom 的顺序是视觉上从上到下，并提供三种乐器的标准空弦配置。
struct InstrumentTuning: Equatable, Hashable, Sendable {
    var instrument: InstrumentType
    // 空弦顺序固定为视觉上从上到下，对应几何层的 stringIndex 方向。
    var openStringsTopToBottom: [NotePitch]

    init(instrument: InstrumentType, openStringsTopToBottom: [NotePitch]) {
        precondition(
            openStringsTopToBottom.count == instrument.stringCount,
            "Open string count must match instrument string count."
        )

        self.instrument = instrument
        self.openStringsTopToBottom = openStringsTopToBottom
    }

    var stringCount: Int {
        openStringsTopToBottom.count
    }

    func openStringPitch(for stringIndex: Int) -> NotePitch? {
        guard openStringsTopToBottom.indices.contains(stringIndex) else {
            return nil
        }

        return openStringsTopToBottom[stringIndex]
    }

    static func standard(for instrument: InstrumentType) -> InstrumentTuning {
        switch instrument {
        case .guitar6:
            return .guitar6Standard
        case .bass4:
            return .bass4Standard
        case .bass5:
            return .bass5Standard
        }
    }
}
```

### 标准调弦常量

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift
// 函数名：guitar6Standard, bass4Standard, bass5Standard
// 功能说明：为 6 弦吉他、4 弦贝斯、5 弦贝斯提供默认标准调弦，后续 provider 可直接基于这些空弦音高推导各品音名。
static let guitar6Standard = InstrumentTuning(
    instrument: .guitar6,
    openStringsTopToBottom: [
        NotePitch(pitchClass: .e, octave: 2),
        NotePitch(pitchClass: .a, octave: 2),
        NotePitch(pitchClass: .d, octave: 3),
        NotePitch(pitchClass: .g, octave: 3),
        NotePitch(pitchClass: .b, octave: 3),
        NotePitch(pitchClass: .e, octave: 4)
    ]
)

static let bass4Standard = InstrumentTuning(
    instrument: .bass4,
    openStringsTopToBottom: [
        NotePitch(pitchClass: .e, octave: 1),
        NotePitch(pitchClass: .a, octave: 1),
        NotePitch(pitchClass: .d, octave: 2),
        NotePitch(pitchClass: .g, octave: 2)
    ]
)

static let bass5Standard = InstrumentTuning(
    instrument: .bass5,
    openStringsTopToBottom: [
        NotePitch(pitchClass: .b, octave: 0),
        NotePitch(pitchClass: .e, octave: 1),
        NotePitch(pitchClass: .a, octave: 1),
        NotePitch(pitchClass: .d, octave: 2),
        NotePitch(pitchClass: .g, octave: 2)
    ]
)
```

## 结果说明

- 这次只完成了音高模型和调弦模型的建立，还没有修改 `FretboardConfiguration`，也没有引入 content provider。
- `NotePitch` 现在已经能支撑“`0` 品到任意品按半音递进”的核心计算。
- `InstrumentTuning` 已经把“空弦顺序按视觉上从上到下”的约束固化成了数据结构。
- 后续阶段 2 可以直接让 `FretboardConfiguration` 以 `tuning` 为权威，不需要再把空弦数据散落到控制器或 provider 里。

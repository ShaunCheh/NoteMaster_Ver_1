# 20260326_172040_phase3_named_key_demo_entry_migration

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_172040`
- 记录范围：`调名输入支持` 的阶段 3 实施
- 本次目标：把示例配置和平台 demo 入口切到 `D大调`、`A大调` 这种可读调名输入，同时保持共享渲染主链继续只消费 `StaffScore` 领域模型，不让输入格式污染 `StaffSceneBuilder`、`StaffKeySignatureLayout`、`StaffAccidentalContext`
- 根因结论：阶段 1 已经把命名调号解析统一收敛到 DTO 边界，阶段 2 又给 decode 和 scene 加了完整验证护栏；但对外展示的示例入口仍然在 fixture 层直接传 `StaffKeySignature(fifths:)` 或直接使用自然调默认 demo。结果是“系统已经支持调名输入”和“用户最先看到的示例入口”之间仍然脱节。阶段 3 要解决的是示例入口语义不一致，而不是重写共享渲染主链
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. `StaffScoreFixtures` 新增 `namedKeySignatureDemo(clef:)`，让默认展示谱例直接走 `"D大调"` 这种命名调号输入，而不是继续只展示自然调版本。
2. `StaffScoreFixtures.keySignatureReference(...)`、`gMajorAccidentalContextReference()`、`aMajorAccidentalContextReference()`、`bbMajorBassAccidentalContextReference()` 都切到 `keySignatureToken` 路径，让共享层对外示例统一经过命名调号解码边界。
3. iOS / macOS 控制器的默认五线谱 demo 同步切到 `StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)`。
4. `StaffValidationRunner.makeFixtures()` 新增 `treble-named-key-demo-full-notation`，把默认命名调号 demo 也纳入自动验证。
5. 在新增验证夹具时发现一个真实记谱细节：`D大调` 下不仅 `bb4` 会显示 flat，`c5` 和 `f5` 也会因为调号默认是 `C# / F#` 而显示 natural。该行为不是渲染 bug，而是正确的调号语义，已正式写入期望值。

## 修改 1：新增命名调号 demo 入口，示例不再只展示自然调默认谱例

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.defaultDemo(clef:)
// 功能说明: 修改前默认 demo 固定走自然调；
// 即使音符序列里出现了 f# / bb，这个入口本身也没有展示 "D大调" 这种用户可直接理解的调名输入。
static func defaultDemo(clef: StaffClef = .treble) -> StaffScore {
    resolveScore(
        named: "default-demo",
        clef: clef,
        keySignature: .natural,
        measures: [[
            ("e4", .quarter),
            ("f#4", .quarter),
            ("g4", .quarter),
            ("bb4", .half),
            ("c5", .quarter),
            ("d5", .quarter),
            ("e5", .half),
            ("f5", .whole)
        ]]
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.namedKeySignatureDemo(clef:)
// 功能说明: 修改后新增专门的命名调号 demo；
// 这个入口直接通过 "D大调" 走 DTO 解码边界，再进入同一套共享 StaffScore/Scene 渲染链。
static func namedKeySignatureDemo(clef: StaffClef = .treble) -> StaffScore {
    resolveScore(
        named: "named-key-signature-demo",
        clef: clef,
        keySignatureToken: "D大调",
        measures: [[
            ("e4", .quarter),
            ("f#4", .quarter),
            ("g4", .quarter),
            ("bb4", .half),
            ("c5", .quarter),
            ("d5", .quarter),
            ("e5", .half),
            ("f5", .whole)
        ]]
    )
}
```

## 修改 2：共享 fixture 的公开入口统一走命名调号 token，而不是直接暴露 `fifths`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.keySignatureReference(clef:keySignature:)
// 功能说明: 修改前 key signature 参考谱例虽然能验证共享渲染链，
// 但 fixture 输入仍然直接传领域层的 StaffKeySignature(fifths:)，没有覆盖对外演示入口的调名写法。
static func keySignatureReference(
    clef: StaffClef,
    keySignature: StaffKeySignature
) -> StaffScore {
    resolveScore(
        named: "key-signature-reference-\(clef.token)-\(keySignature.fifths)",
        clef: clef,
        keySignature: keySignature,
        measures: [referenceMeasure(for: clef, keySignature: keySignature)]
    )
}

static func gMajorAccidentalContextReference() -> StaffScore {
    resolveScore(
        named: "g-major-accidental-context",
        clef: .treble,
        keySignature: StaffKeySignature(fifths: 1),
        measures: [
            [
                ("f#4", .quarter),
                ("f#4", .quarter),
                ("f4", .quarter),
                ("f4", .quarter),
                ("f#4", .half)
            ]
        ]
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.keySignatureReference(clef:keySignature:) /
// StaffScoreFixtures.gMajorAccidentalContextReference() /
// StaffScoreFixtures.aMajorAccidentalContextReference() /
// StaffScoreFixtures.bbMajorBassAccidentalContextReference()
// 功能说明: 修改后这些公开 fixture 全部改走 keySignatureToken，
// 对外示例统一经过命名调号解码层，再落到既有的 fifths 领域模型。
static func keySignatureReference(
    clef: StaffClef,
    keySignature: StaffKeySignature
) -> StaffScore {
    resolveScore(
        named: "key-signature-reference-\(clef.token)-\(keySignature.fifths)",
        clef: clef,
        keySignatureToken: namedMajorToken(for: keySignature),
        measures: [referenceMeasure(for: clef, keySignature: keySignature)]
    )
}

static func gMajorAccidentalContextReference() -> StaffScore {
    resolveScore(
        named: "g-major-accidental-context",
        clef: .treble,
        keySignatureToken: "G大调",
        measures: [
            [
                ("f#4", .quarter),
                ("f#4", .quarter),
                ("f4", .quarter),
                ("f4", .quarter),
                ("f#4", .half)
            ]
        ]
    )
}

static func aMajorAccidentalContextReference() -> StaffScore {
    resolveScore(
        named: "a-major-accidental-context",
        clef: .treble,
        keySignatureToken: "A大调",
        measures: [
            [
                ("f#4", .quarter),
                ("c#5", .quarter),
                ("g#4", .quarter),
                ("f4", .quarter)
            ]
        ]
    )
}

static func bbMajorBassAccidentalContextReference() -> StaffScore {
    resolveScore(
        named: "bb-major-bass-accidental-context",
        clef: .bass,
        keySignatureToken: "降B大调",
        measures: [
            [
                ("bb3", .quarter),
                ("bb3", .quarter),
                ("b3", .quarter),
                ("b3", .half)
            ]
        ]
    )
}
```

### 为命名调号 fixture 补入统一辅助层

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.resolveScore(named:clef:keySignatureToken:measures:) /
// StaffScoreFixtures.namedMajorToken(for:)
// 功能说明: 修改后 fixture 侧新增 token 版 resolveScore；
// 这样共享层可以继续接收领域模型 StaffScore，但 fixture 入口已经统一改走字符串调名输入。
private static func resolveScore(
    named fixtureName: String,
    clef: StaffClef,
    keySignatureToken: String,
    measures: [MeasureDefinition]
) -> StaffScore {
    let measuresJSON = measures
        .map(measureJSON(for:))
        .joined(separator: ",\n")
    let json = """
    {
      "clef": "\(clef.token)",
      "keySignature": "\(keySignatureToken)",
      "measures": [
    \(measuresJSON)
      ]
    }
    """

    do {
        return try StaffScore.decode(from: json)
    } catch {
        assertionFailure(
            "Failed to decode staff score fixture '\(fixtureName)': \(error)"
        )
        return StaffScore(
            clef: clef,
            measures: []
        )
    }
}

private static func namedMajorToken(
    for keySignature: StaffKeySignature
) -> String {
    switch keySignature.fifths {
    case 0: return "C大调"
    case 1: return "G大调"
    case 2: return "D大调"
    case 3: return "A大调"
    case 4: return "E大调"
    case 5: return "B大调"
    case 6: return "升F大调"
    case 7: return "升C大调"
    case -1: return "F大调"
    case -2: return "降B大调"
    case -3: return "降E大调"
    case -4: return "降A大调"
    case -5: return "降D大调"
    case -6: return "降G大调"
    case -7: return "降C大调"
    default:
        preconditionFailure("Named major token must stay within -7...7.")
    }
}
```

## 修改 3：平台默认五线谱 demo 切到命名调号示例

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSViewController.staffDisplayState
// 功能说明: 修改前 iOS 默认五线谱仍然绑定自然调 demo；
// macOS 控制器使用的是同样的写法。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
)
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSViewController.staffDisplayState
// 功能说明: 修改后 iOS 默认五线谱直接展示命名调号 demo；
// macOS 控制器也同步切到同一个 fixture，从平台入口层面把示例写法改成 "D大调"。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: macOSViewController.staffDisplayState
// 功能说明: macOS 平台与 iOS 保持一致，也改为命名调号 demo 入口。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
)
```

## 修改 4：把命名调号 demo 正式纳入自动验证，并修正真实 accidental 期望

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.makeFixtures() / StaffValidationRunner.manualChecklist(for:)
// 功能说明: 修改前自动验证只覆盖 natural 的 default demo；
// 手工清单虽然要求临时切命名调号输入，但默认 demo 本身还不是命名调号场景。
var fixtures = [
    fixture(
        name: "treble-default-demo-full-notation",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.defaultDemo(clef: .treble),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [
            noteAccidental(noteIndex: 1, accidental: .sharp),
            noteAccidental(noteIndex: 3, accidental: .flat)
        ]
    ),
    fixture(
        name: "treble-default-demo-noteheads-only",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.defaultDemo(clef: .treble),
        notationDisplayOptions: .noteheadsOnly
    )
]

var checklist = [
    "启动 App，确认默认五线谱已恢复完整记谱显示：除 clef 与 notehead 外，还能看到 stem，以及需要时的 accidental / ledger line，且没有回退成 clef-only 场景。"
]
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.makeFixtures() / StaffValidationRunner.manualChecklist(for:)
// 功能说明: 修改后新增命名调号 demo 验证夹具；
// 并把默认 demo 的手工检查点改成 "当前就应看到 D大调 调号"。
// 这里的 accidental 期望值是本次阶段 3 新确认的真实语义：
// bb4 显示 flat；c5 和 f5 因为 D 大调默认是 C# / F#，所以必须显示 natural。
var fixtures = [
    fixture(
        name: "treble-default-demo-full-notation",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.defaultDemo(clef: .treble),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [
            noteAccidental(noteIndex: 1, accidental: .sharp),
            noteAccidental(noteIndex: 3, accidental: .flat)
        ]
    ),
    fixture(
        name: "treble-default-demo-noteheads-only",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.defaultDemo(clef: .treble),
        notationDisplayOptions: .noteheadsOnly
    ),
    fixture(
        name: "treble-named-key-demo-full-notation",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [
            noteAccidental(noteIndex: 3, accidental: .flat),
            noteAccidental(noteIndex: 4, accidental: .natural),
            noteAccidental(noteIndex: 7, accidental: .natural)
        ]
    )
]

var checklist = [
    "启动 App，确认默认五线谱已恢复完整记谱显示，且默认 demo 已切到命名调号输入示例：当前应能看到 `D大调` 对应的 key signature，同时保留 stem，以及需要时的 accidental / ledger line。"
]
```

## 本阶段明确未修改的共享渲染主链

- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffKeySignatureLayout.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffAccidentalContext.swift`
- 这意味着阶段 3 仍然遵守既定边界：只调整示例入口和验证护栏，不把命名调号输入格式直接带进渲染层

## 验证结果

### 静态检查

- `ReadLints` 检查以下文件，结果为无错误：
- `NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 共享层 Swift 类型检查，确认阶段 3 没有引入编译错误。
xcrun swiftc -typecheck \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  NoteMaster_Ver_1/Shared/Controls/*.swift
```

- 结果：通过

### 命令行验证

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 编译并执行 StaffValidationRunner.run(platform: .commandLine)，确认命名调号 demo 入口没有破坏既有回归矩阵。
xcrun swiftc -o /tmp/staff_phase3_check \
  NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  /tmp/staff_phase2_check.swift && \
/tmp/staff_phase3_check
```

- 结果：`[StaffValidation][commandLine] automated=PASS fixtures=50`
- 结论：阶段 3 完成后，命名调号 demo 入口、major circle-of-fifths 参考谱例、G/A/Bb accidental context、以及 `noteheadsOnly / fullNotation` 的共享层回归都保持通过

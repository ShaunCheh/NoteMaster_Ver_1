# 20260326_160231_phase5_key_signature_validation_matrix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_160231`
- 记录范围：`调号支持` 的阶段 5 实施
- 本次目标：补齐 `key signature / measure / accidental reset` 的共享层 fixture 矩阵，并把验证器从“旧 accidental 直读逻辑”升级为真正理解调号与跨小节 reset 的断言
- 根因结论：阶段 4 之后虽然共享层已经能正确生成 `keySignature + measures + accidental context` 场景，但 `StaffValidation.swift` 仍沿用“只看 `pitch.accidental` 就推断 expected accidental”的旧模型；如果不先把 fixture 和断言同时升级，后续再加 barline、和弦、拍号时，验证器会继续对真实语义给出假阳性或假阴性
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

## 本次完成的修改

1. `StaffScoreFixtures` 不再只支持默认 demo，而是正式补出 `keySignatureReference(...)`、`gMajorAccidentalContextReference()`、`bbMajorBassAccidentalContextReference()`。
2. `StaffValidationFixture` 新增 `expectedDisplayedNoteAccidentals`，用于精确描述“哪些 note 在当前上下文下应该显示 accidental”。
3. `StaffValidationRunner.makeFixtures()` 从 4 个 notehead 排障夹具升级为 17 个共享层夹具，覆盖 `C / G / D / F / Bb`、`treble / bass`、`fullNotation / noteheadsOnly`、同小节抑制与跨小节 reset。
4. `validateSceneCounts(...)` 与 `validateAccidentals(...)` 不再按旧的 `pitch.accidental != .natural` 规则猜 expected accidental，而是分别校验 key signature accidental 和 note accidental。
5. `manualChecklist(...)` 已切换到完整记谱阶段的回归内容，覆盖调号顺序、同小节 accidental 抑制、跨小节 reset，以及 `noteheadsOnly / fullNotation` 切换回归。

## 修改 1：`StaffScoreFixtures` 从“默认 demo”升级为“调号 / 小节 / accidental context”参考谱例工厂

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.defaultDemo(clef:) / resolveScore(named:clef:keySignature:notesJSON:)
// 功能说明: 修改前 fixture 工厂只有默认 demo，且 resolveScore 仍以单个 notesJSON 字符串为核心；
// 这意味着验证器如果要覆盖多小节 reset，只能在 StaffValidation.swift 里继续手写 JSON，fixture 真相源会继续分叉。
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
        let json = """
        {
          "clef": "\(clef.token)",
          "keySignature": {
            "fifths": \(keySignature.fifths)
          },
          "measures": [
            {
              "notes": \(notesJSON)
            }
          ]
        }
        """
        // ...
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.defaultDemo(clef:) / keySignatureReference(clef:keySignature:) / gMajorAccidentalContextReference() / bbMajorBassAccidentalContextReference() / resolveScore(named:clef:keySignature:measures:)
// 功能说明: 修改后 fixture 工厂统一切到 measures 级输入；
// 调号参考谱例、Treble/Bass 下的 accidental context reset 参考谱例都进入共享真相源，验证器和后续 demo 可直接复用。
enum StaffScoreFixtures {
    private typealias MeasureDefinition = [(pitch: String, duration: StaffNoteDuration)]

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

    static func keySignatureReference(
        clef: StaffClef,
        keySignature: StaffKeySignature
    ) -> StaffScore {
        resolveScore(
            named: "key-signature-reference-\(clef.token)-\(keySignature.fifths)",
            clef: clef,
            keySignature: keySignature,
            measures: [referenceMeasure(for: clef)]
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
                ],
                [
                    ("f#4", .quarter),
                    ("f4", .half)
                ]
            ]
        )
    }

    static func bbMajorBassAccidentalContextReference() -> StaffScore {
        resolveScore(
            named: "bb-major-bass-accidental-context",
            clef: .bass,
            keySignature: StaffKeySignature(fifths: -2),
            measures: [
                [
                    ("bb3", .quarter),
                    ("bb3", .quarter),
                    ("b3", .quarter),
                    ("b3", .half)
                ],
                [
                    ("bb3", .quarter),
                    ("b3", .half)
                ]
            ]
        )
    }
}
```

## 修改 2：`StaffValidationFixture` 与 `makeFixtures()` 从排障夹具升级为调号矩阵

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationFixture / StaffValidationRunner.makeFixtures()
// 功能说明: 修改前 fixture 结构只知道 score、bounds、ledger line 数量；
// makeFixtures() 也只有 4 个排障夹具，且全部固定为 noteheadsOnly，不覆盖调号、同小节 accidental 抑制和跨小节 reset。
private struct StaffValidationFixture {
    var name: String
    var configuration: StaffConfiguration
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var bounds: CGRect
    var expectedLedgerLineCount: Int
}

static func makeFixtures() -> [StaffValidationFixture] {
    return [
        StaffValidationFixture(
            name: "treble-default-demo",
            configuration: trebleConfiguration,
            score: StaffScoreFixtures.defaultDemo(clef: .treble),
            notationDisplayOptions: .noteheadsOnly,
            bounds: fixtureBounds(configuration: trebleConfiguration),
            expectedLedgerLineCount: 0
        ),
        StaffValidationFixture(
            name: "bass-ascending-reference",
            configuration: bassConfiguration,
            score: score(
                clef: .bass,
                notes: [
                    ("g2", .quarter),
                    ("a2", .quarter),
                    ("bb2", .quarter)
                    // ...
                ]
            ),
            notationDisplayOptions: .noteheadsOnly,
            bounds: fixtureBounds(configuration: bassConfiguration),
            expectedLedgerLineCount: 0
        )
        // ... 其余仍是 noteheadsOnly 排障夹具
    ]
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationFixture / StaffValidationExpectedNoteAccidental / StaffValidationRunner.makeFixtures()
// 功能说明: 修改后 fixture 结构能精确表达“哪些 note 应显示 accidental”；
// makeFixtures() 也扩成了 fullNotation、noteheadsOnly、key signature 参考谱例、Treble/Bass accidental reset 参考谱例组成的验证矩阵。
private struct StaffValidationFixture {
    var name: String
    var configuration: StaffConfiguration
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var bounds: CGRect
    var expectedLedgerLineCount: Int
    var expectedDisplayedNoteAccidentals: [StaffValidationExpectedNoteAccidental]
}

private struct StaffValidationExpectedNoteAccidental: Equatable {
    var noteIndex: Int
    var symbolID: StaffGlyphSymbolID
}

static func makeFixtures() -> [StaffValidationFixture] {
    let keySignatureFixtures: [(String, StaffKeySignature)] = [
        ("c", .natural),
        ("g", StaffKeySignature(fifths: 1)),
        ("d", StaffKeySignature(fifths: 2)),
        ("f", StaffKeySignature(fifths: -1)),
        ("bb", StaffKeySignature(fifths: -2))
    ]

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
            name: "treble-g-major-context-reset",
            configuration: trebleConfiguration,
            score: StaffScoreFixtures.gMajorAccidentalContextReference(),
            notationDisplayOptions: .fullNotation,
            expectedDisplayedNoteAccidentals: [
                noteAccidental(noteIndex: 2, accidental: .natural),
                noteAccidental(noteIndex: 4, accidental: .sharp),
                noteAccidental(noteIndex: 6, accidental: .natural)
            ]
        )
        // ... 其余还包含 bass-bb-major-context-reset，
        // 以及 treble/bass 下 C / G / D / F / Bb 的 key signature 参考谱例
    ]

    fixtures.append(
        contentsOf: keySignatureFixtures.map {
            fixture(
                name: "treble-key-\($0.0)-reference",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.keySignatureReference(
                    clef: .treble,
                    keySignature: $0.1
                ),
                notationDisplayOptions: .fullNotation
            )
        }
    )

    return fixtures
}
```

## 修改 3：`validateSceneCounts(...)` / `validateAccidentals(...)` 从旧 accidental 直读逻辑升级为调号 + 音符双层断言

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: validateSceneCounts(scene:geometry:fixture:record:) / validateAccidentals(scene:fixture:record:) / accidentalSymbolID(for:)
// 功能说明: 修改前验证器只会遍历 score.notes 并按 pitch.accidental 推导 expected accidental；
// 这种逻辑完全不知道 key signature 默认升降、同小节抑制以及显式 natural 的显示规则。
let expectedAccidentalCount = fixture.notationDisplayOptions.showsAccidentals
    ? fixture.score.notes.filter {
        $0.pitch.accidental != .natural
    }.count
    : 0

let expectedAccidentalSymbols = fixture.score.notes.compactMap {
    accidentalSymbolID(for: $0.pitch.accidental)
}

for (noteIndex, note) in fixture.score.notes.enumerated() where note.pitch.accidental != .natural {
    let accidentalFrame = accidentalFrames[accidentalIndex]
    let noteheadFrame = noteheadFrames[noteIndex]
    if accidentalFrame.maxX >= noteheadFrame.minX {
        record("accidental[\(accidentalIndex)] 没有落在 notehead[\(noteIndex)] 左侧。")
    }
}

static func accidentalSymbolID(
    for accidental: StaffAccidental
) -> StaffGlyphSymbolID? {
    switch accidental {
    case .flat:
        return .accidentalFlat
    case .natural:
        return nil
    case .sharp:
        return .accidentalSharp
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: validateSceneCounts(scene:geometry:fixture:record:) / validateAccidentals(scene:geometry:fixture:record:) / expectedKeySignatureAccidentalSymbols(for:) / expectedDisplayedNoteAccidentals(for:) / noteAccidentalSymbolID(for:)
// 功能说明: 修改后验证器先区分 key signature accidental 与 note accidental，
// 再分别校验数量、序列、staffPosition、noteIndex 映射、与 notehead 的左右关系，以及 key signature 区和首个 note cluster 不重叠。
let expectedAccidentalCount = expectedKeySignatureAccidentalSymbols(
    for: fixture
).count + expectedDisplayedNoteAccidentals(
    for: fixture
).count

let expectedKeySignatureSymbols = expectedKeySignatureAccidentalSymbols(
    for: fixture
)
let expectedNoteAccidentals = expectedDisplayedNoteAccidentals(
    for: fixture
)
let actualKeySignatureGlyphs = Array(
    accidentalGlyphs.prefix(expectedKeySignatureSymbols.count)
)
let actualNoteAccidentalGlyphs = Array(
    accidentalGlyphs.dropFirst(expectedKeySignatureSymbols.count)
)

let expectedKeySignatureStaffPositions = expectedKeySignatureStaffPositions(
    clef: fixture.configuration.clef,
    keySignature: fixture.score.keySignature,
    notationDisplayOptions: fixture.notationDisplayOptions
)

for (accidentalIndex, expectedAccidental) in expectedNoteAccidentals.enumerated() {
    let accidentalFrame = actualNoteAccidentalFrames[accidentalIndex]
    let noteheadFrame = noteheadFrames[expectedAccidental.noteIndex]
    if accidentalFrame.maxX >= noteheadFrame.minX {
        record("note accidental[\(accidentalIndex)] 没有落在 notehead[\(expectedAccidental.noteIndex)] 左侧。")
    }
    if !approximatelyEqual(accidentalFrame.midY, noteheadFrame.midY) {
        record("note accidental[\(accidentalIndex)] 与 notehead[\(expectedAccidental.noteIndex)] 的中心 Y 不一致。")
    }
}

if let lastKeySignatureFrame = actualKeySignatureFrames.last,
   let firstNoteheadFrame = noteheadFrames.first {
    var firstNoteClusterMinX = firstNoteheadFrame.minX
    if let firstExpectedNoteAccidental = expectedNoteAccidentals.first,
       firstExpectedNoteAccidental.noteIndex == 0,
       let firstNoteAccidentalFrame = actualNoteAccidentalFrames.first {
        firstNoteClusterMinX = min(
            firstNoteClusterMinX,
            firstNoteAccidentalFrame.minX
        )
    }

    if firstNoteClusterMinX <= lastKeySignatureFrame.maxX + tolerance {
        record("首个 note cluster 侵入 key signature 区域。")
    }
}

static func noteAccidentalSymbolID(
    for accidental: StaffAccidental
) -> StaffGlyphSymbolID {
    switch accidental {
    case .flat:
        return .accidentalFlat
    case .natural:
        return .accidentalNatural
    case .sharp:
        return .accidentalSharp
    }
}
```

## 修改 4：`manualChecklist(...)` 从排障期清单升级为调号支持回归清单

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: manualChecklist(for:)
// 功能说明: 修改前手工清单仍围绕 noteheadsOnly 排障阶段；
// 它假设 accidental / stem / ledger line 故意不绘制，因此已经不适合完整记谱阶段。
var checklist = [
    "启动 App，确认五线谱除 clef 外已经能看到 demo notehead，且没有回退成 clef-only 场景。",
    "当前阶段故意不绘制 accidental / stem / ledger line；确认界面上只看到 clef、staff line 与 notehead。",
    "在 settings 中切换 Treble / Bass，确认同一组 demo notes 会按新 clef 重新布局，notehead 的上下行关系正确。",
    "调整窗口大小或设备方向，确认 note spacing 与 glyph 位置稳定更新，不出现 clefArea 与 noteArea 重叠。"
]
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: manualChecklist(for:)
// 功能说明: 修改后手工清单切换到完整记谱阶段；
// 除了默认 fullNotation，还覆盖 key signature 参考谱例、G major / Bb major accidental reset、以及 noteheadsOnly / fullNotation 显式切换回归。
var checklist = [
    "启动 App，确认默认五线谱已恢复完整记谱显示：除 clef 与 notehead 外，还能看到 stem，以及需要时的 accidental / ledger line，且没有回退成 clef-only 场景。",
    "将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 `C / G / D / F / Bb` 参考谱例，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确。",
    "将共享 score 切到 `StaffScoreFixtures.gMajorAccidentalContextReference()`，确认同小节里 `f#` 会被调号抑制、写出 `f natural` 后同小节再次 `f#` 会重新显示 sharp，跨小节后恢复调号默认规则。",
    "将共享 score 切到 `StaffScoreFixtures.bbMajorBassAccidentalContextReference()`，确认 Bass + Bb major 下 `bb3` 默认不显示 accidental，`b3` 显示 natural，跨小节后再次按调号默认值重置。",
    "显式把 `staffDisplayState.notationDisplayOptions` 切到 `.noteheadsOnly` 再切回 `.fullNotation`，确认 notehead 可见性稳定，且 accidental / stem / ledger line 能正确隐藏与恢复。",
    "调整窗口大小或设备方向，确认 key signature 区与 note 区不会重叠，note spacing 与 glyph 位置稳定更新。"
]
```

## 验证结果

1. `ReadLints`

```text
# 文件路径: IDE 诊断（无源码文件）
# 函数/成员: ReadLints
# 功能说明: 本轮修改的 2 个 Staff 文件无新增 IDE 诊断。
No linter errors found.
```

2. 共享层与控制层静态类型校验

```bash
# 文件路径: 命令行验证（无源码文件）
# 函数/成员: xcrun swiftc -typecheck
# 功能说明: 对 Shared/Fretboard/*.swift、Shared/Staff/*.swift、Shared/Controls/*.swift 做阶段 5 静态类型校验。
xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift NoteMaster_Ver_1/Shared/Controls/*.swift
```

```text
# 文件路径: 命令行验证结果（无源码文件）
# 函数/成员: xcrun swiftc -typecheck 输出
# 功能说明: 命令执行成功，未产生编译错误输出。
Exit code: 0
```

3. `StaffValidationRunner` 命令行验证

```bash
# 文件路径: 临时校验脚本（无源码文件）
# 函数/成员: StaffValidationRunner.run(platform:)
# 功能说明: 直接运行共享层验证入口，确认调号矩阵、accidental context reset 和显示策略回归都能被自动夹具覆盖。
./staff_phase5_check
```

```text
# 文件路径: 临时校验脚本输出（无源码文件）
# 函数/成员: StaffValidationRunner.debugSummary()
# 功能说明:
# - automated=PASS fixtures=17: 新增后的调号矩阵和 reset 夹具全部通过；
# - 通过夹具列表已覆盖 treble/bass 下 C / G / D / F / Bb；
# - 同时覆盖 fullNotation / noteheadsOnly、G major 与 Bb major 的 accidental context reset。
[StaffValidation][commandLine] automated=PASS fixtures=17
通过夹具: treble-default-demo-full-notation, treble-default-demo-noteheads-only, bass-ascending-reference-full-notation, treble-ledger-both-sides-full-notation, bass-ledger-both-sides-full-notation, treble-g-major-context-reset, bass-bb-major-context-reset, treble-key-c-reference, treble-key-g-reference, treble-key-d-reference, treble-key-f-reference, treble-key-bb-reference, bass-key-c-reference, bass-key-g-reference, bass-key-d-reference, bass-key-f-reference, bass-key-bb-reference
自动化问题:
- 无
手工回归清单:
1. 启动 App，确认默认五线谱已恢复完整记谱显示：除 clef 与 notehead 外，还能看到 stem，以及需要时的 accidental / ledger line，且没有回退成 clef-only 场景。
2. 将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 `C / G / D / F / Bb` 参考谱例，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确。
3. 将共享 score 切到 `StaffScoreFixtures.gMajorAccidentalContextReference()`，确认同小节里 `f#` 会被调号抑制、写出 `f natural` 后同小节再次 `f#` 会重新显示 sharp，跨小节后恢复调号默认规则。
4. 将共享 score 切到 `StaffScoreFixtures.bbMajorBassAccidentalContextReference()`，确认 Bass + Bb major 下 `bb3` 默认不显示 accidental，`b3` 显示 natural，跨小节后再次按调号默认值重置。
5. 显式把 `staffDisplayState.notationDisplayOptions` 切到 `.noteheadsOnly` 再切回 `.fullNotation`，确认 notehead 可见性稳定，且 accidental / stem / ledger line 能正确隐藏与恢复。
6. 调整窗口大小或设备方向，确认 key signature 区与 note 区不会重叠，note spacing 与 glyph 位置稳定更新。
7. 命令行只覆盖共享层 scene fixture，不覆盖 iOS/macOS 运行时渲染、字体注册与交互。
```

## 当前阶段结论

- 阶段 5 已把调号支持从“共享层能力可用”推进到“共享层能力有护栏可回归”。
- 这轮的关键不是新增更多绘制逻辑，而是确保 `keySignature + measures + accidentalContext` 这条骨架已经具备可重复跑的自动验证。
- 后续如果继续扩 barline、和弦、拍号，应该优先复用这里的 fixture / validation 结构，而不是重新回到手写 ad-hoc 场景脚本。

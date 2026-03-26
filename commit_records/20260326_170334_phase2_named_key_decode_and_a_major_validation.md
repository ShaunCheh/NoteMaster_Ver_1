# 20260326_170334_phase2_named_key_decode_and_a_major_validation

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_170334`
- 记录范围：`调名输入支持` 的阶段 2 实施
- 本次目标：把阶段 1 已经具备的命名调号解码能力正式纳入共享层验证护栏，同时补 `A major` 的 accidental context 回归，并把 key signature 参考谱例从局部扩到完整 major circle-of-fifths
- 根因结论：阶段 1 之后，`StaffScoreDecoding.swift` 已经能把 `D大调 / A major` 这类输入收敛到 `fifths`，但共享层验证仍然只覆盖少量 scene fixture；命名调号 decode 回归还停留在临时命令行脚本，没有进入 `StaffValidationRunner` 报告真相源。同时，`keySignatureReference(...)` 的参考音仍然是固定的自然音组合，如果直接把调号参考矩阵扩到整个 major circle-of-fifths，会在高升降号调里意外引入 note accidental 噪音，稀释调号验证本身
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

## 本次完成的修改

1. `StaffScoreFixtures` 新增 `aMajorAccidentalContextReference()`，把 `A major` 下 `F# / C# / G#` 的默认抑制、显式 natural、同小节恢复 sharp、跨小节 reset 固化成共享夹具。
2. `keySignatureReference(...)` 改成按当前调号默认升降生成参考音，不再固定用自然音 `g/a`，从根上避免扩到完整 major circle-of-fifths 后意外长出 note accidental 噪音。
3. `StaffValidationRunner.run(...)` 现在会先执行 11 个命名调号 decode case，再执行 scene fixture；命名调号 decode 回归第一次进入统一验证报告。
4. `StaffValidationRunner.makeFixtures()` 从 `C / G / D / F / Bb` 扩到完整 major circle-of-fifths，并新增 `treble-a-major-context-reset`。
5. `manualChecklist(...)` 已同步升级，覆盖完整 major circle-of-fifths、命名调号输入、以及 `A major` accidental context reset。

## 修改 1：`StaffScoreFixtures` 不再只覆盖 G/Bb accidental context，补入 `A major`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.gMajorAccidentalContextReference() / StaffScoreFixtures.bbMajorBassAccidentalContextReference()
// 功能说明: 修改前共享夹具只覆盖 G major 和 Bb major；
// 这意味着阶段 2 想验证 `A major` 下 F# / C# / G# 三个默认升号与跨小节 reset 时，没有可复用的真相源夹具。
enum StaffScoreFixtures {
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

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.aMajorAccidentalContextReference()
// 功能说明: 修改后新增 A major 夹具；
// 第 1 小节先用 F# / C# / G# 验证调号默认抑制，再写出 f natural / c natural / g natural，
// 同小节验证 sharp 是否重新出现；第 2 小节继续验证 measure reset 后 natural 是否再次写出。
enum StaffScoreFixtures {
    static func aMajorAccidentalContextReference() -> StaffScore {
        resolveScore(
            named: "a-major-accidental-context",
            clef: .treble,
            keySignature: StaffKeySignature(fifths: 3),
            measures: [
                [
                    ("f#4", .quarter),
                    ("c#5", .quarter),
                    ("g#4", .quarter),
                    ("f4", .quarter),
                    ("f#4", .quarter),
                    ("c5", .quarter),
                    ("c5", .quarter),
                    ("g4", .quarter),
                    ("g4", .quarter)
                ],
                [
                    ("f4", .quarter),
                    ("c5", .quarter),
                    ("g4", .half)
                ]
            ]
        )
    }
}
```

## 修改 2：`keySignatureReference(...)` 的参考音改成按当前调号默认升降生成

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.keySignatureReference(clef:keySignature:) / referenceMeasure(for:)
// 功能说明: 修改前 key signature 参考谱例不区分当前调号，
// Treble 永远给 g4/a4，Bass 永远给 g2/a2；如果直接把验证矩阵扩到完整 major circle-of-fifths，
// 高升号或高降号调里会混入 note accidental，影响“只验证调号 cluster”这个目标。
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

private static func referenceMeasure(
    for clef: StaffClef
) -> MeasureDefinition {
    switch clef {
    case .treble:
        return [
            ("g4", .quarter),
            ("a4", .half)
        ]
    case .bass:
        return [
            ("g2", .quarter),
            ("a2", .half)
        ]
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.keySignatureReference(clef:keySignature:) / referenceMeasure(for:keySignature:) / referenceNaturalLetter(excluding:) / referencePitchToken(letter:accidental:clef:) / referenceOctave(for:clef:)
// 功能说明: 修改后 referenceMeasure 会优先选当前 key signature 已经被调号默认升降的字母，
// 只有在升降号数量较少时才补一个不在 alteredLetters 里的自然音；
// 这样完整调号矩阵里的参考谱例仍然主要验证 key signature glyph，不会被额外的 note accidental 污染。
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

private static func referenceMeasure(
    for clef: StaffClef,
    keySignature: StaffKeySignature
) -> MeasureDefinition {
    guard
        let signatureAccidental = keySignature.signatureAccidental,
        !keySignature.alteredLetters.isEmpty
    else {
        switch clef {
        case .treble:
            return [
                ("g4", .quarter),
                ("a4", .half)
            ]
        case .bass:
            return [
                ("g2", .quarter),
                ("a2", .half)
            ]
        }
    }

    let alteredLetters = keySignature.alteredLetters
    let primaryPitch = referencePitchToken(
        letter: alteredLetters[0],
        accidental: signatureAccidental,
        clef: clef
    )
    let secondaryPitch: String
    if alteredLetters.count > 1 {
        secondaryPitch = referencePitchToken(
            letter: alteredLetters[1],
            accidental: signatureAccidental,
            clef: clef
        )
    } else if let naturalLetter = referenceNaturalLetter(
        excluding: alteredLetters
    ) {
        secondaryPitch = referencePitchToken(
            letter: naturalLetter,
            accidental: .natural,
            clef: clef
        )
    } else {
        secondaryPitch = primaryPitch
    }

    return [
        (primaryPitch, .quarter),
        (secondaryPitch, .half)
    ]
}
```

## 修改 3：命名调号 decode 回归正式进入 `StaffValidationRunner`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.run(platform:)
// 功能说明: 修改前 run() 只跑 scene fixture；
// 命名调号 decode 回归虽然在阶段 1 通过临时脚本验证过，但并没有进入统一的 validation report。
enum StaffValidationRunner {
    static func run(platform: StaffValidationPlatform) -> StaffValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [StaffValidationIssue] = []

        for fixture in fixtures {
            let fixtureIssues = validate(fixture)
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        return StaffValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.run(platform:) / makeDecodeCases() / decodeCase(name:json:expectedKeySignatureFifths:expectedClef:expectedMeasureCount:expectedNoteCount:) / decodeScoreJSON(clefField:keySignatureField:notesField:) / validate(_ decodeCase:)
// 功能说明: 修改后命名调号 decode case 成为 StaffValidationRunner 的一等输入；
// run() 先验证 decodeCase，再验证 scene fixture，最终统一进入同一份 debugSummary 报告。
private struct StaffValidationDecodeCase {
    var name: String
    var json: String
    var expectedClef: StaffClef
    var expectedKeySignatureFifths: Int
    var expectedMeasureCount: Int
    var expectedNoteCount: Int
}

enum StaffValidationRunner {
    static func run(platform: StaffValidationPlatform) -> StaffValidationReport {
        let decodeCases = makeDecodeCases()
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [StaffValidationIssue] = []

        for decodeCase in decodeCases {
            let decodeCaseIssues = validate(decodeCase)
            if decodeCaseIssues.isEmpty {
                passedFixtureNames.append(decodeCase.name)
            } else {
                issues.append(contentsOf: decodeCaseIssues)
            }
        }

        for fixture in fixtures {
            let fixtureIssues = validate(fixture)
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        return StaffValidationReport(
            platform: platform,
            fixtureCount: decodeCases.count + fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }
}
```

## 修改 4：验证矩阵从局部调号扩到完整 major circle-of-fifths，并补 `A major` reset 语义

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.makeFixtures() / manualChecklist(for:)
// 功能说明: 修改前 key signature 参考谱例只覆盖 C / G / D / F / Bb，
// accidental context 只覆盖 G major 和 Bb major，manual checklist 也仍然停留在这组较小矩阵上。
let keySignatureFixtures: [(String, StaffKeySignature)] = [
    ("c", .natural),
    ("g", StaffKeySignature(fifths: 1)),
    ("d", StaffKeySignature(fifths: 2)),
    ("f", StaffKeySignature(fifths: -1)),
    ("bb", StaffKeySignature(fifths: -2))
]

var fixtures = [
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
    ),
    fixture(
        name: "bass-bb-major-context-reset",
        configuration: bassConfiguration,
        score: StaffScoreFixtures.bbMajorBassAccidentalContextReference(),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [
            noteAccidental(noteIndex: 2, accidental: .natural),
            noteAccidental(noteIndex: 5, accidental: .natural)
        ]
    )
]
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后 key signature 参考谱例扩到完整 major circle-of-fifths，
// 并新增 treble-a-major-context-reset，专门验证 A major 下 F# / C# / G# 的默认抑制、同小节自然还原、再次 sharp、以及跨小节 reset。
let keySignatureFixtures: [(String, StaffKeySignature)] = [
    ("c", .natural),
    ("g", StaffKeySignature(fifths: 1)),
    ("d", StaffKeySignature(fifths: 2)),
    ("a", StaffKeySignature(fifths: 3)),
    ("e", StaffKeySignature(fifths: 4)),
    ("b", StaffKeySignature(fifths: 5)),
    ("fsharp", StaffKeySignature(fifths: 6)),
    ("csharp", StaffKeySignature(fifths: 7)),
    ("f", StaffKeySignature(fifths: -1)),
    ("bb", StaffKeySignature(fifths: -2)),
    ("eb", StaffKeySignature(fifths: -3)),
    ("ab", StaffKeySignature(fifths: -4)),
    ("db", StaffKeySignature(fifths: -5)),
    ("gb", StaffKeySignature(fifths: -6)),
    ("cb", StaffKeySignature(fifths: -7))
]

var fixtures = [
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
    ),
    fixture(
        name: "treble-a-major-context-reset",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.aMajorAccidentalContextReference(),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [
            noteAccidental(noteIndex: 3, accidental: .natural),
            noteAccidental(noteIndex: 4, accidental: .sharp),
            noteAccidental(noteIndex: 5, accidental: .natural),
            noteAccidental(noteIndex: 7, accidental: .natural),
            noteAccidental(noteIndex: 9, accidental: .natural),
            noteAccidental(noteIndex: 10, accidental: .natural),
            noteAccidental(noteIndex: 11, accidental: .natural)
        ]
    )
]
```

## 验证结果

1. IDE 诊断

```text
# 文件路径: IDE 诊断（无源码文件）
# 函数/成员: ReadLints
# 功能说明: 本轮修改的 StaffScoreFixtures.swift 和 StaffValidation.swift 无新增 IDE 诊断。
No linter errors found.
```

2. 共享层静态类型校验

```bash
# 文件路径: 命令行验证（无源码文件）
# 函数/成员: xcrun swiftc -typecheck
# 功能说明: 对 Shared/Fretboard/*.swift、Shared/Staff/*.swift、Shared/Controls/*.swift 做阶段 2 静态类型校验。
xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift NoteMaster_Ver_1/Shared/Controls/*.swift
```

```text
# 文件路径: 命令行验证结果（无源码文件）
# 函数/成员: xcrun swiftc -typecheck 输出
# 功能说明: 命令执行成功，未产生编译错误输出。
Exit code: 0
```

3. `StaffValidationRunner` 命令行验证

```swift
// 文件路径: /tmp/staff_phase2_check.swift（临时校验脚本，非仓库文件）
// 函数/成员: Phase2ValidationCheck.main()
// 功能说明: 直接运行 StaffValidationRunner.run(platform: .commandLine)，
// 确认命名调号 decode case、完整 major circle-of-fifths key reference 和 A major accidental context 都已进入统一验证报告。
import Foundation

@main
struct Phase2ValidationCheck {
    static func main() {
        let report = StaffValidationRunner.run(platform: .commandLine)
        print(report.debugSummary())
        precondition(report.isPassing, report.debugSummary())
    }
}
```

```bash
# 文件路径: 命令行验证（无源码文件）
# 函数/成员: StaffValidationRunner.run(platform:)
# 功能说明: 编译并运行阶段 2 命令行验证入口。
xcrun swiftc -o /tmp/staff_phase2_check NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Staff/*.swift /tmp/staff_phase2_check.swift && /tmp/staff_phase2_check
```

```text
# 文件路径: 命令行验证结果（无源码文件）
# 函数/成员: StaffValidationReport.debugSummary()
# 功能说明:
# - automated=PASS fixtures=49：11 个命名调号 decode case + 38 个 scene fixture 全部通过；
# - key reference 已覆盖完整 major circle-of-fifths；
# - A major accidental context reset 已进入共享层自动回归。
[StaffValidation][commandLine] automated=PASS fixtures=49
通过夹具: decode-key-d-major-zh-inline, decode-key-a-major-zh-inline, decode-key-d-major-en-inline, decode-key-a-major-en-inline, decode-key-bb-major-en-inline, decode-key-bb-major-zh-inline, decode-key-fsharp-major-en-inline, decode-key-fsharp-major-zh-inline, decode-key-a-bare-tonic-inline, decode-key-d-major-english-keyed-fifths, decode-key-a-major-chinese-keyed-fifths, treble-default-demo-full-notation, treble-default-demo-noteheads-only, bass-ascending-reference-full-notation, treble-ledger-both-sides-full-notation, bass-ledger-both-sides-full-notation, treble-g-major-context-reset, treble-a-major-context-reset, bass-bb-major-context-reset, treble-key-c-reference, treble-key-g-reference, treble-key-d-reference, treble-key-a-reference, treble-key-e-reference, treble-key-b-reference, treble-key-fsharp-reference, treble-key-csharp-reference, treble-key-f-reference, treble-key-bb-reference, treble-key-eb-reference, treble-key-ab-reference, treble-key-db-reference, treble-key-gb-reference, treble-key-cb-reference, bass-key-c-reference, bass-key-g-reference, bass-key-d-reference, bass-key-a-reference, bass-key-e-reference, bass-key-b-reference, bass-key-fsharp-reference, bass-key-csharp-reference, bass-key-f-reference, bass-key-bb-reference, bass-key-eb-reference, bass-key-ab-reference, bass-key-db-reference, bass-key-gb-reference, bass-key-cb-reference
自动化问题:
- 无
手工回归清单:
1. 启动 App，确认默认五线谱已恢复完整记谱显示：除 clef 与 notehead 外，还能看到 stem，以及需要时的 accidental / ledger line，且没有回退成 clef-only 场景。
2. 将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 major circle-of-fifths 参考谱例：`C / G / D / A / E / B / F# / C# / F / Bb / Eb / Ab / Db / Gb / Cb`，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确。
3. 把调号输入临时切成命名形式，例如 `D大调`、`A大调`、`D major`、`A major`，以及 keyed 对象形式 `{ "fifths": "D大调" }`；确认 scene 结果与直接传 `fifths` 等价。
4. 将共享 score 切到 `StaffScoreFixtures.gMajorAccidentalContextReference()`，确认同小节里 `f#` 会被调号抑制、写出 `f natural` 后同小节再次 `f#` 会重新显示 sharp，跨小节后恢复调号默认规则。
5. 将共享 score 切到 `StaffScoreFixtures.aMajorAccidentalContextReference()`，确认 A major 下 `F# / C# / G#` 默认会被调号抑制；写出 `f natural` 后同小节再次 `f#` 会重新显示 sharp；同小节写出的 `c natural / g natural` 到下一小节会再次显示 natural，证明 measure reset 生效。
6. 将共享 score 切到 `StaffScoreFixtures.bbMajorBassAccidentalContextReference()`，确认 Bass + Bb major 下 `bb3` 默认不显示 accidental，`b3` 显示 natural，跨小节后再次按调号默认值重置。
7. 显式把 `staffDisplayState.notationDisplayOptions` 切到 `.noteheadsOnly` 再切回 `.fullNotation`，确认 notehead 可见性稳定，且 accidental / stem / ledger line 能正确隐藏与恢复。
8. 调整窗口大小或设备方向，确认 key signature 区与 note 区不会重叠，note spacing 与 glyph 位置稳定更新。
9. 命令行已覆盖命名调号 decode 回归与共享层 scene fixture，不覆盖 iOS/macOS 运行时渲染、字体注册与交互。
```

## 当前阶段结论

- 阶段 2 已经把“命名调号输入支持”从阶段 1 的边界能力，推进到“共享层有统一护栏”的状态。
- 这轮的关键不是继续扩渲染逻辑，而是让 decode 回归和 scene 回归进入同一份 `StaffValidationRunner` 报告，避免后续命名调号支持再次退化成只靠临时脚本证明。
- 下一阶段如果继续实施，应该优先把示例配置入口切到 `D大调` / `A大调` 这种更直观的写法，同时保持 `StaffSceneBuilder`、`StaffKeySignatureLayout`、`StaffAccidentalContext` 不被输入格式污染。

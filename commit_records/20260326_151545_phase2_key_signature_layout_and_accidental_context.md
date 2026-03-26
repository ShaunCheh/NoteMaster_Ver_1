# 20260326_151545_phase2_key_signature_layout_and_accidental_context

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_151545`
- 记录范围：`调号支持` 的阶段 2 实施
- 本次目标：拆出 `StaffKeySignatureLayout` 与 `StaffAccidentalContext`，把 accidental 决策从 `StaffPitchLayout` 中移走
- 根因结论：当前五线谱链路虽然已经具备 `keySignature` 和 `measures` 领域模型，但 accidental 的显示决策仍混在 `StaffPitchLayout` 里，导致“调号默认升降”“小节内临时记号抑制”“跨小节 reset”这些语义还没有统一真相源；如果继续把 accidental 当成几何问题处理，阶段 3 的 `SceneBuilder` 重构会继续夹杂错误职责
- 本次实际改动：
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffKeySignatureLayout.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffAccidentalContext.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`

## 本次完成的修改

1. 新增 `StaffKeySignatureLayout`，统一收口 treble / bass 下调号 sharp / flat 的标准顺序和垂直定位。
2. 新增 `StaffAccidentalContext`，用 `letter + octave` 作为小节内 accidental 状态键，并从 `keySignature` 初始化默认状态。
3. `StaffPitchLayout` 缩回纯几何职责，只保留 `staffPosition / centerY / stemDirection / ledgerLineYs`。
4. `StaffSceneBuilder` 开始按 `score.measures` 遍历音符，并在每个小节起点重置 accidental context。
5. 音符 accidental glyph 的显示规则已经从“直接看 `pitch.accidental`”升级为“比较当前书写音高与上下文中的有效 accidental”。

## 修改 1：新增 `StaffKeySignatureLayout`，为调号 cluster 提供共享布局真相源

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffKeySignatureLayout.swift
// 函数/成员: 文件级
// 功能说明: 修改前没有独立的调号布局组件；
// sharp / flat 的顺序、谱号差异和垂直落点都还没有共享层真相源。
// 修改前状态: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffKeySignatureLayout.swift
// 函数/成员: StaffKeySignatureLayout.positionedAccidentals(for:in:) / keySignaturePitches(for:)
// 功能说明: 新增调号布局器；先根据 clef 和 keySignature 决定标准音级顺序，
// 再复用 StaffPitchLayout 把这些书写音高转换成调号 glyph 所需的 staffPosition 与 centerY。
import CoreGraphics

struct StaffKeySignatureLayout: Equatable, Sendable {
    struct PositionedAccidental: Equatable, Sendable {
        var symbolID: StaffGlyphSymbolID
        var pitch: StaffPitch
        var staffPosition: Int
        var centerY: CGFloat
    }

    var clef: StaffClef

    func positionedAccidentals(
        for keySignature: StaffKeySignature,
        in geometry: StaffGeometry
    ) -> [PositionedAccidental] {
        guard
            let keyAccidental = keySignature.signatureAccidental,
            let symbolID = accidentalSymbolID(for: keyAccidental)
        else {
            return []
        }

        let pitchLayout = StaffPitchLayout(clef: clef)
        return keySignaturePitches(for: keyAccidental)
            .prefix(abs(keySignature.fifths))
            .compactMap { pitch in
                guard let positionedPitch = pitchLayout.positionedPitch(pitch, in: geometry) else {
                    return nil
                }

                return PositionedAccidental(
                    symbolID: symbolID,
                    pitch: pitch,
                    staffPosition: positionedPitch.staffPosition,
                    centerY: positionedPitch.centerY
                )
            }
    }

    private func keySignaturePitches(
        for accidental: StaffAccidental
    ) -> [StaffPitch] {
        switch (clef, accidental) {
        case (.treble, .sharp):
            return [
                StaffPitch(letter: .f, octave: 5),
                StaffPitch(letter: .c, octave: 5),
                StaffPitch(letter: .g, octave: 5)
                // ... 后续省略，其余顺序仍在文件中完整保留
            ]
        case (.bass, .flat):
            return [
                StaffPitch(letter: .b, octave: 2),
                StaffPitch(letter: .e, octave: 3),
                StaffPitch(letter: .a, octave: 2)
                // ... 后续省略，其余顺序仍在文件中完整保留
            ]
        default:
            return []
        }
    }
}
```

## 修改 2：新增 `StaffAccidentalContext`，把调号默认升降和小节内临时记号状态收口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffAccidentalContext.swift
// 函数/成员: 文件级
// 功能说明: 修改前没有独立 accidental context；
// SceneBuilder 只能直接读 note.pitch.accidental，无法表达“同小节已出现过还原号/升号”的状态变化。
// 修改前状态: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffAccidentalContext.swift
// 函数/成员: StaffAccidentalContext.resetForMeasure() / effectiveAccidental(for:) / resolveDisplayDecision(for:)
// 功能说明: 新增 accidental 上下文；默认状态来自 keySignature，
// measureOverrides 只记录当前小节内已写出的 accidental，并在新小节开始时清空。
struct StaffAccidentalContext: Equatable, Sendable {
    struct PitchScope: Hashable, Sendable {
        var letter: StaffPitchLetter
        var octave: Int

        init(pitch: StaffPitch) {
            self.letter = pitch.letter
            self.octave = pitch.octave
        }
    }

    struct Decision: Equatable, Sendable {
        var effectiveAccidentalBeforeNote: StaffAccidental
        var writtenAccidental: StaffAccidental
        var displayedAccidental: StaffAccidental?
    }

    var keySignature: StaffKeySignature
    private var measureOverrides: [PitchScope: StaffAccidental]

    mutating func resetForMeasure() {
        measureOverrides.removeAll()
    }

    func effectiveAccidental(for pitch: StaffPitch) -> StaffAccidental {
        let scope = PitchScope(pitch: pitch)
        return measureOverrides[scope] ?? keySignature.accidental(for: pitch.letter)
    }

    mutating func resolveDisplayDecision(
        for pitch: StaffPitch
    ) -> Decision {
        let effectiveAccidentalBeforeNote = effectiveAccidental(for: pitch)
        let displayedAccidental: StaffAccidental? = effectiveAccidentalBeforeNote == pitch.accidental
            ? nil
            : pitch.accidental

        measureOverrides[PitchScope(pitch: pitch)] = pitch.accidental

        return Decision(
            effectiveAccidentalBeforeNote: effectiveAccidentalBeforeNote,
            writtenAccidental: pitch.accidental,
            displayedAccidental: displayedAccidental
        )
    }
}
```

## 修改 3：`StaffPitchLayout` 去掉 accidental 决策，只保留几何定位

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift
// 函数/成员: StaffPitchLayout.PositionedPitch / positionedPitch(_:in:) / accidentalSymbolID(for:)
// 功能说明: 修改前 PositionedPitch 同时带几何结果和 accidental glyph 决策；
// 这会把“是否显示升降号”错误地绑定到单 note 几何层，而不是 measure 级语义上下文。
struct PositionedPitch: Equatable, Sendable {
    var staffPosition: Int
    var centerY: CGFloat
    var stemDirection: StemDirection
    var ledgerLineYs: [CGFloat]
    var accidentalSymbolID: StaffGlyphSymbolID?
}

func positionedPitch(
    _ pitch: StaffPitch,
    in geometry: StaffGeometry
) -> PositionedPitch? {
    // ... 前置 guard 与几何计算省略
    return PositionedPitch(
        staffPosition: staffPosition,
        centerY: centerY,
        stemDirection: stemDirection(
            for: staffPosition,
            geometry: geometry
        ),
        ledgerLineYs: ledgerLineYs(
            for: staffPosition,
            geometry: geometry
        ),
        accidentalSymbolID: accidentalSymbolID(for: pitch.accidental)
    )
}

private func accidentalSymbolID(
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
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift
// 函数/成员: StaffPitchLayout.PositionedPitch / positionedPitch(_:in:)
// 功能说明: 修改后 PitchLayout 只负责五线谱几何结果；
// accidental 是否显示、显示什么 glyph，统一交给 StaffAccidentalContext 和 SceneBuilder 决策。
struct PositionedPitch: Equatable, Sendable {
    var staffPosition: Int
    var centerY: CGFloat
    var stemDirection: StemDirection
    var ledgerLineYs: [CGFloat]
}

func positionedPitch(
    _ pitch: StaffPitch,
    in geometry: StaffGeometry
) -> PositionedPitch? {
    guard
        let bottomLineY = geometry.bottomLineY,
        geometry.staffStepHeight > 0
    else {
        return nil
    }

    let staffPosition = pitch.diatonicIndex - bottomLineReferencePitch.diatonicIndex
    let centerY = bottomLineY - (CGFloat(staffPosition) * geometry.staffStepHeight)

    return PositionedPitch(
        staffPosition: staffPosition,
        centerY: centerY,
        stemDirection: stemDirection(
            for: staffPosition,
            geometry: geometry
        ),
        ledgerLineYs: ledgerLineYs(
            for: staffPosition,
            geometry: geometry
        )
    )
}
```

## 修改 4：`StaffSceneBuilder` 改为按小节驱动 accidental context，而不是直接读 pitch.accidental

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.makeScene(geometry:)
// 功能说明: 修改前 SceneBuilder 直接遍历 score.notes，
// accidental glyph 的来源是 positionedPitch.accidentalSymbolID，因此既无法按小节 reset，也无法根据调号抑制显示。
let pitchLayout = StaffPitchLayout(clef: clef)
let noteFrames = makeNoteheadFrames(
    noteCount: score.notes.count,
    geometry: geometry
)

for (note, noteheadFrame) in zip(score.notes, noteFrames) {
    guard
        let positionedPitch = pitchLayout.positionedPitch(
            note.pitch,
            in: geometry
        )
    else {
        continue
    }

    if notationDisplayOptions.showsAccidentals,
       let accidentalSymbolID = positionedPitch.accidentalSymbolID {
        glyphs.append(
            StaffGlyphItem(
                symbolID: accidentalSymbolID,
                placement: .frame(
                    accidentalFrame(
                        for: noteheadFrame,
                        centerY: positionedPitch.centerY
                    )
                ),
                tintColor: glyphTintColor,
                renderHint: .accidental()
            )
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.makeScene(geometry:) / accidentalSymbolID(for:)
// 功能说明: 修改后 SceneBuilder 按 score.measures 遍历音符；
// 每个小节先 reset accidental context，再根据上下文决定当前 note 是否需要显示 sharp / flat / natural。
let pitchLayout = StaffPitchLayout(clef: clef)
let noteFrames = makeNoteheadFrames(
    noteCount: score.notes.count,
    geometry: geometry
)
var noteFrameIndex = 0
var accidentalContext = StaffAccidentalContext(
    keySignature: score.keySignature
)

for measure in score.measures {
    accidentalContext.resetForMeasure()

    for note in measure.notes {
        guard noteFrameIndex < noteFrames.count else {
            break
        }

        let noteheadFrame = noteFrames[noteFrameIndex]
        noteFrameIndex += 1

        guard
            let positionedPitch = pitchLayout.positionedPitch(
                note.pitch,
                in: geometry
            )
        else {
            continue
        }

        let accidentalDecision = accidentalContext.resolveDisplayDecision(
            for: note.pitch
        )
        if notationDisplayOptions.showsAccidentals,
           let displayedAccidental = accidentalDecision.displayedAccidental,
           let accidentalSymbolID = accidentalSymbolID(
                for: displayedAccidental
           ) {
            glyphs.append(
                StaffGlyphItem(
                    symbolID: accidentalSymbolID,
                    placement: .frame(
                        accidentalFrame(
                            for: noteheadFrame,
                            centerY: positionedPitch.centerY
                        )
                    ),
                    tintColor: glyphTintColor,
                    renderHint: .accidental()
                )
            )
        }
    }
}

private func accidentalSymbolID(
    for accidental: StaffAccidental
) -> StaffGlyphSymbolID? {
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

## 验证结果

1. `ReadLints`

```text
# 功能说明: 本轮新增/修改的 4 个 Staff 文件无新增 IDE 诊断。
No linter errors found.
```

2. 共享层静态类型校验

```bash
# 功能说明: 对 Shared/Fretboard/NotePitch.swift 与 Shared/Staff/*.swift 做类型校验。
xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Staff/*.swift
```

```text
# 功能说明: 命令执行成功，未产生编译错误输出。
Exit code: 0
```

3. 阶段 2 语义校验

```bash
# 功能说明: 临时构造命令行用例，验证调号布局顺序，以及同小节/跨小节 accidental 显示决策。
./staff_phase2_check
```

```text
# 功能说明:
# - trebleD=F5,C5: Treble 下 D 大调的前两个 sharp 落点顺序正确；
# - bassBb=B2,E3: Bass 下 Bb 大调的前两个 flat 落点顺序正确；
# - measure1=-,-,natural,-,sharp: G 大调中同小节 accidental 抑制与还原号/升号切换正确；
# - measure2=-,natural: 跨小节后上下文已重置回调号默认值。
trebleD=F5,C5
bassBb=B2,E3
measure1=-,-,natural,-,sharp
measure2=-,natural
```

## 当前阶段结论

- 阶段 2 已完成共享层职责拆分：`StaffPitchLayout` 只管几何，`StaffAccidentalContext` 只管记号语义，`StaffKeySignatureLayout` 只管调号 glyph 布局。
- 这一步还没有把调号 cluster 真正插入 scene 的横向布局；该工作留给阶段 3 统一在 `clef -> keySignature -> measures -> notes` 链路里完成。
- 当前 UI 默认仍处于 `noteheadsOnly` 排障显示态，所以本阶段的结果主要体现在共享层语义和 scene 入口，而不是界面直接看到调号。

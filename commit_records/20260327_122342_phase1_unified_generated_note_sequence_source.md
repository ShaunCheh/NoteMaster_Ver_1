# 20260327_122342_phase1_unified_generated_note_sequence_source

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_122342`
- 记录范围：统一序列真相源阶段 1，抽共享 `GeneratedNoteSequence` 真相源并调整 quarter-note generator / trainer 适配边界
- 本次目标：不再让 `StaffScore + expectedPitchClasses` 的临时组合充当唯一真相，而是在 shared 层先落一份可同时服务 prompt / staff / session 的底层序列模型
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`

## 根因结论

- 当前 `QuarterNoteSequencePrompt` 的核心数据仍然是 `score + expectedPitchClasses`，它更像“给五线谱看的结果壳”，而不是“多显示路径共用的一份随机序列真相源”。
- `StaffQuarterNoteSequenceGenerator` 虽然已经收口回 `Shared/Staff` 域，但它仍然把输出固定为 `Sequence(score:expectedPitchClasses:)`。这会导致后续如果要给音名组件做序列显示，只能继续从 `score` 或 `expectedPitchClasses` 反推，shared 层没有一个明确的序列对象来承接“书写音高 / 判题音名 / prompt 展示文本”这些投影职责。
- 阶段 1 的目标因此不是加 UI，而是先把数据边界打正：先有 `GeneratedNoteSequence`，再让 `staff` / `prompt` / `session` 都成为它的消费者。

## 修改 1：新增 `GeneratedNoteSequence` 作为共享序列真相源

### 修改前

- 项目内没有独立的 `GeneratedNoteSequence` 文件。
- 随机序列的真实内容散落在 `StaffQuarterNoteSequenceGenerator` 的局部变量里：先生成 `selectedPitches`，再临时拼 `score` 和 `expectedPitchClasses`，生成结束后没有一份可复用的 shared 序列对象留下来。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数/成员: makeSequence(spec:using:)
// 功能说明: 修改前 generator 直接在函数内部临时拼接 score 和 expectedPitchClasses；
// 调用方拿到的是“结果壳”，而不是一份可继续投影到 prompt / session 的共享序列真相源。
func makeSequence<R: RandomNumberGenerator>(
    spec: Spec,
    using generator: inout R
) -> Sequence {
    let candidates = resolvedCandidates(for: spec)
    guard !candidates.isEmpty else {
        preconditionFailure(
            "Quarter-note sequence pitch candidates should never be empty."
        )
    }

    let selectedPitches = (0..<spec.noteCount).map { _ in
        guard let pitch = candidates.randomElement(using: &generator) else {
            preconditionFailure(
                "Quarter-note sequence pitch selection should always succeed."
            )
        }
        return pitch
    }
    let notes = selectedPitches.map {
        StaffScoreNote(
            pitch: $0,
            duration: .quarter
        )
    }
    let score = StaffScore(
        clef: spec.clef,
        keySignature: .natural,
        measures: makeMeasures(from: notes)
    )
    let expectedPitchClasses = selectedPitches.map {
        $0.notePitch.pitchClass
    }

    return Sequence(
        score: score,
        expectedPitchClasses: expectedPitchClasses
    )
}
```

### 修改后

- 新增 `NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift`。
- 把“序列项”和“序列整体”都提升为共享类型：
  - `GeneratedNoteSequenceItem`：持有单个题目的 `writtenPitch` 与 `answerPitchClass`
  - `GeneratedNoteSequence`：持有 `clef + items`
- 这份新真相源直接提供多种投影：
  - `score`
  - `answerPitchClasses`
  - `displayPitchClasses`
  - `displayTexts(using:)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift
// 函数/成员: GeneratedNoteSequenceItem.init(writtenPitch:answerPitchClass:),
// GeneratedNoteSequence.score, displayPitchClasses, displayTexts(using:)
// 功能说明: 新增共享序列真相源，后续 prompt / staff / session 都应基于它投影，
// 而不是各自从 score 或 expectedPitchClasses 反推。
struct GeneratedNoteSequenceItem: Equatable, Hashable, Sendable {
    var writtenPitch: StaffPitch
    var answerPitchClass: PitchClass

    init(
        writtenPitch: StaffPitch,
        answerPitchClass: PitchClass? = nil
    ) {
        let resolvedAnswerPitchClass = answerPitchClass
            ?? writtenPitch.notePitch.pitchClass
        precondition(
            resolvedAnswerPitchClass == writtenPitch.notePitch.pitchClass,
            "Generated note sequence item answer pitch class must match its written pitch."
        )
        self.writtenPitch = writtenPitch
        self.answerPitchClass = resolvedAnswerPitchClass
    }

    var note: StaffScoreNote {
        StaffScoreNote(
            pitch: writtenPitch,
            duration: .quarter
        )
    }
}

struct GeneratedNoteSequence: Equatable, Sendable {
    var clef: StaffClef
    var items: [GeneratedNoteSequenceItem]

    init(
        clef: StaffClef,
        items: [GeneratedNoteSequenceItem]
    ) {
        precondition(
            !items.isEmpty,
            "Generated note sequence must contain at least one item."
        )
        self.clef = clef
        self.items = items
    }

    var answerPitchClasses: [PitchClass] {
        items.map(\.answerPitchClass)
    }

    // 第一阶段先把 prompt 展示真相收敛为 pitchClass；
    // 后续若需要保留更细的书写语义，再在此基础上扩展 display token。
    var displayPitchClasses: [PitchClass] {
        answerPitchClasses
    }

    var score: StaffScore {
        StaffScore(
            clef: clef,
            keySignature: .natural,
            measures: makeMeasures(from: notes)
        )
    }

    func displayTexts(
        using spelling: PitchSpelling = .sharp
    ) -> [String] {
        displayPitchClasses.map {
            $0.displayText(using: spelling)
        }
    }
}
```

## 修改 2：`StaffQuarterNoteSequenceGenerator` 直接返回共享真相源

### 修改前

- `StaffQuarterNoteSequenceGenerator` 通过嵌套 `Sequence` 类型返回 `score + expectedPitchClasses`。
- `makeMeasures(from:)` 也留在 generator 内部，说明 generator 同时承担了“随机挑题”和“序列投影成五线谱”的双重职责。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数/成员: Sequence, makeSequence(spec:using:), makeMeasures(from:)
// 功能说明: 修改前 generator 自己维护一层 Sequence 包装，并自己负责把随机音列投影成 score。
// 这样会让 staff 输出结构继续充当唯一真相，不利于后续 prompt / session 共享同一份序列。
struct StaffQuarterNoteSequenceGenerator: Equatable, Sendable {
    struct Sequence: Equatable, Sendable {
        var score: StaffScore
        var expectedPitchClasses: [PitchClass]

        init(
            score: StaffScore,
            expectedPitchClasses: [PitchClass]
        ) {
            precondition(
                score.keySignature == .natural,
                "Quarter-note sequence score should use a natural key signature."
            )
            precondition(
                score.notes.allSatisfy { $0.duration == .quarter },
                "Quarter-note sequence score should only contain quarter notes."
            )
            precondition(
                expectedPitchClasses.count == score.notes.count,
                "Quarter-note sequence answers must align with the generated score."
            )
            self.score = score
            self.expectedPitchClasses = expectedPitchClasses
        }
    }

    func makeSequence<R: RandomNumberGenerator>(
        spec: Spec,
        using generator: inout R
    ) -> Sequence {
        // ... 先随机选 pitch，再组 notes / score / expectedPitchClasses
    }

    private func makeMeasures(
        from notes: [StaffScoreNote]
    ) -> [StaffMeasure] {
        stride(from: 0, to: notes.count, by: 4).map { startIndex in
            let endIndex = min(startIndex + 4, notes.count)
            return StaffMeasure(
                notes: Array(notes[startIndex..<endIndex])
            )
        }
    }
}
```

### 修改后

- 删除 `Sequence` 这层中间壳。
- `makeSequence(...)` 直接返回 `GeneratedNoteSequence`。
- `makeMeasures(from:)` 从 generator 中移走，改由 `GeneratedNoteSequence.score` 自己负责 score 投影。
- 这样 generator 只负责“生成共享序列”，不再负责定义最终 consumer 的唯一读取形态。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数/成员: makeSequence(spec:using:), resolvedCandidates(for:)
// 功能说明: 修改后 generator 只负责按 spec 生成随机 writtenPitch 列表，
// 然后立刻收敛成共享 GeneratedNoteSequence，后续 score/prompt/session 都从该真相源继续投影。
struct StaffQuarterNoteSequenceGenerator: Equatable, Sendable {
    func makeSequence<R: RandomNumberGenerator>(
        spec: Spec,
        using generator: inout R
    ) -> GeneratedNoteSequence {
        let candidates = resolvedCandidates(for: spec)
        guard !candidates.isEmpty else {
            preconditionFailure(
                "Quarter-note sequence pitch candidates should never be empty."
            )
        }

        let selectedPitches = (0..<spec.noteCount).map { _ in
            guard let pitch = candidates.randomElement(using: &generator) else {
                preconditionFailure(
                    "Quarter-note sequence pitch selection should always succeed."
                )
            }
            return pitch
        }
        let items = selectedPitches.map {
            GeneratedNoteSequenceItem(
                writtenPitch: $0
            )
        }

        return GeneratedNoteSequence(
            clef: spec.clef,
            items: items
        )
    }

    private func resolvedCandidates(
        for spec: Spec
    ) -> [StaffPitch] {
        let naturalCandidates = naturalCandidates(for: spec.clef)
        guard spec.includesAccidentals else {
            return naturalCandidates
        }

        // 第一版先固定为升号拼写，不在 Bool 开关里引入降号等音语义。
        return naturalCandidates + sharpCandidates(for: spec.clef)
    }
}
```

## 修改 3：`FretboardNaturalNoteTrainerState` 保留兼容壳，但底层改挂新真相源

### 修改前

- `QuarterNoteSequencePrompt` 直接存 `score` 和 `expectedPitchClasses`。
- `generateQuarterNoteSequencePrompt(using:)` 从 generator 拿回 `Sequence` 后，再手动把它拆回 prompt 字段。
- 这意味着 trainer prompt 本身还不知道“共享序列对象”的存在，后续如果 prompt / staff / session 要共用同一份序列，仍然得继续围着 `score + expectedPitchClasses` 转。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: QuarterNoteSequencePrompt.init(spec:score:expectedPitchClasses:),
// generateQuarterNoteSequencePrompt(using:)
// 功能说明: 修改前 trainer prompt 直接持有 score 和 expectedPitchClasses，
// generator 返回什么，trainer 就按什么字段重新包装一次。
struct QuarterNoteSequencePrompt: Equatable, Sendable {
    var spec: QuarterNoteSequenceSpec
    var score: StaffScore
    var expectedPitchClasses: [PitchClass]

    init(
        spec: QuarterNoteSequenceSpec,
        score: StaffScore,
        expectedPitchClasses: [PitchClass]
    ) {
        precondition(
            score.clef == spec.clef,
            "Quarter-note sequence score clef must match the spec clef."
        )
        precondition(
            expectedPitchClasses.count == score.notes.count,
            "Quarter-note sequence answers must align with the generated score."
        )
        self.spec = spec
        self.score = score
        self.expectedPitchClasses = expectedPitchClasses
    }
}

mutating func generateQuarterNoteSequencePrompt<R: RandomNumberGenerator>(
    using generator: inout R
) -> QuarterNoteSequencePrompt {
    let spec = requireQuarterNoteSequenceSpec()
    let sequence = StaffQuarterNoteSequenceGenerator().makeSequence(
        spec: spec.staffGeneratorSpec,
        using: &generator
    )
    let prompt = QuarterNoteSequencePrompt(
        spec: spec,
        score: sequence.score,
        expectedPitchClasses: sequence.expectedPitchClasses
    )
    quarterNoteSequencePrompt = prompt
    return prompt
}
```

### 修改后

- `QuarterNoteSequencePrompt` 改为内部持有 `generatedSequence`。
- 为了不在阶段 1 一次性改爆所有调用方，保留 `score`、`expectedPitchClasses`、`notes` 这些兼容计算属性。
- 新增 `displayPitchClasses`，给阶段 2 的 prompt 序列显示留出共享读取口。
- `generateQuarterNoteSequencePrompt(using:)` 现在只做一件事：把 shared generator 结果包装成 trainer prompt。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: QuarterNoteSequencePrompt.init(spec:generatedSequence:),
// score, expectedPitchClasses, displayPitchClasses, notes,
// generateQuarterNoteSequencePrompt(using:)
// 功能说明: 修改后 trainer prompt 成为“兼容壳”，底层真相已经换成 generatedSequence；
// 这样 controller / validation 还能继续用旧接口，而后续新 UI 可以直接消费 displayPitchClasses。
struct QuarterNoteSequencePrompt: Equatable, Sendable {
    var spec: QuarterNoteSequenceSpec
    private(set) var generatedSequence: GeneratedNoteSequence

    init(
        spec: QuarterNoteSequenceSpec,
        generatedSequence: GeneratedNoteSequence
    ) {
        precondition(
            generatedSequence.clef == spec.clef,
            "Quarter-note sequence generated sequence clef must match the spec clef."
        )
        precondition(
            generatedSequence.noteCount == spec.noteCount,
            "Quarter-note sequence generated sequence note count must match the spec."
        )
        precondition(
            generatedSequence.answerPitchClasses.count == generatedSequence.notes.count,
            "Quarter-note sequence answers must align with the generated score."
        )
        if !spec.includesAccidentals {
            precondition(
                generatedSequence.answerPitchClasses.allSatisfy(\.isNatural),
                "Quarter-note sequence without accidentals must only contain natural pitches."
            )
        }
        self.spec = spec
        self.generatedSequence = generatedSequence
    }

    var score: StaffScore {
        generatedSequence.score
    }

    var expectedPitchClasses: [PitchClass] {
        generatedSequence.answerPitchClasses
    }

    var displayPitchClasses: [PitchClass] {
        generatedSequence.displayPitchClasses
    }

    var notes: [StaffScoreNote] {
        generatedSequence.notes
    }
}

mutating func generateQuarterNoteSequencePrompt<R: RandomNumberGenerator>(
    using generator: inout R
) -> QuarterNoteSequencePrompt {
    let spec = requireQuarterNoteSequenceSpec()
    let generatedSequence = StaffQuarterNoteSequenceGenerator().makeSequence(
        spec: spec.staffGeneratorSpec,
        using: &generator
    )
    let prompt = QuarterNoteSequencePrompt(
        spec: spec,
        generatedSequence: generatedSequence
    )
    quarterNoteSequencePrompt = prompt
    return prompt
}
```

## 阶段 1 完成后的状态

1. shared 层已经有了一份明确的随机序列真相源：`GeneratedNoteSequence`。
2. `StaffQuarterNoteSequenceGenerator` 的职责已经收敛为“生成序列”，不再顺手定义所有 consumer 的最终读取模型。
3. `QuarterNoteSequencePrompt` 对 controller 和 validation 仍保持兼容，因此阶段 1 没有把 UI / 控制器一起拖进来重写。
4. 阶段 2 可以直接基于 `displayPitchClasses` 或 `displayTexts(using:)` 升级目标音 prompt 组件，而不用再从 `score` 反推 prompt 展示内容。

## 验证情况

- 已对以下文件执行诊断检查，结果为 `No linter errors found`
- `NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 已检查旧的 `StaffQuarterNoteSequenceGenerator.Sequence` 引用，阶段 1 改动后没有遗留调用。
- 未执行 `xcodebuild`：当前环境仍受 Xcode command line tools 配置限制，和前几轮一致。

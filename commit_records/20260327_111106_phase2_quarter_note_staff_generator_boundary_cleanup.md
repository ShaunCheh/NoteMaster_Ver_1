# 20260327_111106_phase2_quarter_note_staff_generator_boundary_cleanup

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_111106`
- 记录范围：随机四分音训练阶段 2，shared Staff generator 边界收口
- 本次目标：把阶段 1 中已经前置落地的 `StaffQuarterNoteSequenceGenerator` 从“反向依赖 trainer 类型”的临时形态，收敛为只依赖 `Shared/Staff` 自身输入输出模型的 shared generator；同时保持 `FretboardNaturalNoteTrainerState` 对外暴露的 quarter-note sequence 生成接口不变
- 根因结论：阶段 1 为了先打通“生成输出”，`StaffQuarterNoteSequenceGenerator` 直接接受并返回 `FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec/Prompt`。这样虽然短期能跑通，但会把 `Shared/Staff` 反向耦合到 `Shared/Fretboard`，破坏当前代码库里“Staff 域负责五线谱内容模型，Trainer 域负责训练状态与适配”的边界。后续只要别处也想复用这个 generator，就不得不把 trainer 一起带进来
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift`

## 本次完成的修改

1. 在 `StaffQuarterNoteSequenceGenerator` 内部新增 `Spec` 和 `Sequence` 两个 shared 类型，让 generator 的输入输出都落在 `Shared/Staff` 域。
2. 把 generator 的入口从 `makePrompt(...)` 改成 `makeSequence(...)`，不再直接构造或返回 trainer 域的 prompt 类型。
3. 保留原来的候选池、四分音组装、每 4 个音拆 measure 的行为不变，只调整领域边界。
4. 在 `FretboardNaturalNoteTrainerState` 里增加 `QuarterNoteSequenceSpec -> StaffQuarterNoteSequenceGenerator.Spec` 的轻量适配层。
5. `trainer.generateQuarterNoteSequencePrompt(...)` 继续对外返回 `QuarterNoteSequencePrompt`，因此阶段 1 已经暴露出去的接口没有被破坏。

## 修改 1：`StaffQuarterNoteSequenceGenerator` 从“依赖 trainer 类型”收口为纯 `Shared/Staff` 生成器

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数/成员: makePrompt(spec:using:), resolvedCandidates(for:)
// 功能说明: 修改前 Staff generator 直接吃 trainer 域的 QuarterNoteSequenceSpec，
// 并直接返回 trainer 域的 QuarterNoteSequencePrompt，形成了 Staff -> Fretboard 的反向依赖。
struct StaffQuarterNoteSequenceGenerator: Equatable, Sendable {
    func makePrompt<R: RandomNumberGenerator>(
        spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec,
        using generator: inout R
    ) -> FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt {
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

        return FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt(
            spec: spec,
            score: score,
            expectedPitchClasses: expectedPitchClasses
        )
    }

    private func resolvedCandidates(
        for spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) -> [StaffPitch] {
        let naturalCandidates = naturalCandidates(for: spec.clef)
        guard spec.includesAccidentals else {
            return naturalCandidates
        }

        return naturalCandidates + sharpCandidates(for: spec.clef)
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数/成员: Spec, Sequence, makeSequence(spec:using:), resolvedCandidates(for:)
// 功能说明: 修改后 generator 的输入输出都回到 Staff 域自身；
// Trainer 只负责适配和包装，不再让 Staff 反向依赖 Fretboard 训练类型。
struct StaffQuarterNoteSequenceGenerator: Equatable, Sendable {
    struct Spec: Equatable, Sendable {
        var clef: StaffClef
        var noteCount: Int
        var includesAccidentals: Bool

        init(
            clef: StaffClef,
            noteCount: Int,
            includesAccidentals: Bool
        ) {
            precondition(
                noteCount > 0,
                "Quarter-note sequence note count must be greater than zero."
            )
            self.clef = clef
            self.noteCount = noteCount
            self.includesAccidentals = includesAccidentals
        }
    }

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

    private func resolvedCandidates(
        for spec: Spec
    ) -> [StaffPitch] {
        let naturalCandidates = naturalCandidates(for: spec.clef)
        guard spec.includesAccidentals else {
            return naturalCandidates
        }

        return naturalCandidates + sharpCandidates(for: spec.clef)
    }
}
```

## 修改 2：`FretboardNaturalNoteTrainerState` 退回适配层，只负责包装 generator 结果

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: generateQuarterNoteSequencePrompt(using:)
// 功能说明: 修改前 trainer 直接调用 StaffQuarterNoteSequenceGenerator.makePrompt(...),
// 并把自己的 QuarterNoteSequenceSpec 原样传进 Staff generator。
mutating func generateQuarterNoteSequencePrompt<R: RandomNumberGenerator>(
    using generator: inout R
) -> QuarterNoteSequencePrompt {
    let spec = requireQuarterNoteSequenceSpec()
    let prompt = StaffQuarterNoteSequenceGenerator().makePrompt(
        spec: spec,
        using: &generator
    )
    quarterNoteSequencePrompt = prompt
    return prompt
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: generateQuarterNoteSequencePrompt(using:), staffGeneratorSpec
// 功能说明: 修改后 trainer 只把自己的 spec 适配成 Staff generator 的 spec，
// 再把 sequence 结果包装回 trainer 域的 QuarterNoteSequencePrompt。
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

private extension FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
    var staffGeneratorSpec: StaffQuarterNoteSequenceGenerator.Spec {
        StaffQuarterNoteSequenceGenerator.Spec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals
        )
    }
}
```

## 当前边界

1. 阶段 2 只修正 shared 领域边界，没有新增 controller 接线、settings 暴露或顺序判题实现。
2. `QuarterNoteSequencePrompt` 的对外行为和阶段 1 保持一致；变化主要在 `StaffQuarterNoteSequenceGenerator` 的内部输入输出模型。
3. `includesAccidentals` 的第一版语义仍然不变：`false` 仅自然音，`true` 允许升号拼写，不生成降号拼写。

## 验证情况

1. 已检查 IDE 诊断，当前无新增 linter 问题：`NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`、`NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift`
2. 未执行完整 `xcodebuild` 编译验证；当前环境的 `xcode-select` 指向 Command Line Tools，无法直接完成完整 Xcode 工程构建。

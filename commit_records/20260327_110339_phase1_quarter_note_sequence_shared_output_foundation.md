# 20260327_110339_phase1_quarter_note_sequence_shared_output_foundation

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_110339`
- 记录范围：随机四分音训练阶段 1，shared 输出基础
- 本次目标：在不改 controller、settings、平台 view 的前提下，让 shared 层已经可以表达并产出“按 clef / 生成数 / 是否包含半音”生成的随机四分音序列结果
- 根因结论：修改前 `FretboardNaturalNoteTrainerState` 只支持“单个自然音目标 + 指板判题”这一种训练语义，真相源只有 `targetPitchClass`。这样即使需求已经扩展到“生成 N 个随机四分音符并最终显示到五线谱”，shared 层也没有地方承载新的模式参数、输出 `StaffScore`，更没有为后续顺序判题保留接口。如果只新增几个散落的 helper，后续 controller、validation、判题会继续围绕旧的单目标模型缝补
- 阶段说明：原计划把 `StaffQuarterNoteSequenceGenerator` 拆到后续阶段，但为了满足“阶段1只做生成输出”的明确目标，本次把最小 shared generator 一并前置；controller 接线、settings 暴露、顺序判题实现仍保持在后续阶段
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift`

## 本次完成的修改

1. 在 `FretboardNaturalNoteTrainerState` 中新增 `ExerciseMode`，把单目标自然音训练和随机四分音序列训练放到同一个 shared 训练入口下。
2. 新增 `QuarterNoteSequenceSpec`、`QuarterNoteSequencePrompt`、`QuarterNoteSequenceSession`、`QuarterNoteSequenceAnswerResult`，为“生成输出”和“后续顺序判题”建立明确类型边界。
3. 新增 `generateQuarterNoteSequencePrompt(...)` 生成入口，让 trainer 在 `.quarterNoteSequence` 模式下可以直接产出 `score + expectedPitchClasses`。
4. 新增 `StaffQuarterNoteSequenceGenerator`，负责把 `clef + noteCount + includesAccidentals` 转成 `StaffScore` 和答案真相数组。
5. 保持现有单目标自然音训练路径不变，并通过 mode guard 阻止旧的 `handle(...)` / `advanceToNextTarget(...)` 被错误用于四分音序列模式。
6. 预留 `handleQuarterNoteSequenceAnswer(...)` 打桩，明确第二步顺序判题的扩展位置，但当前不实现交互行为。

## 修改 1：`FretboardNaturalNoteTrainerState` 从“单目标自然音”扩成“多训练模式共享入口”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: Prompt, targetPitchClass, prompt, init(targetPitchClass:)
// 功能说明: 修改前 trainer 只有单个自然音目标这一种真相源；
// 无法承载 quarter-note sequence 的参数和输出。
struct FretboardNaturalNoteTrainerState: Equatable, Sendable {
    enum EventResult: Equatable, Sendable {
        case ignored(IgnoreReason)
        case evaluated(Evaluation)
    }

    struct Prompt: Equatable, Sendable {
        var targetPitchClass: PitchClass

        var displayText: String {
            targetPitchClass.displayText()
        }
    }

    private(set) var targetPitchClass: PitchClass

    var prompt: Prompt {
        Prompt(targetPitchClass: targetPitchClass)
    }

    init(targetPitchClass: PitchClass) {
        precondition(
            targetPitchClass.isNatural,
            "Target pitch class must be a natural note."
        )
        self.targetPitchClass = targetPitchClass
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: ExerciseMode, QuarterNoteSequenceSpec, QuarterNoteSequencePrompt, mode, quarterNoteSequencePrompt
// 功能说明: 修改后 trainer 先在 shared 域升级为多模式入口；
// 单目标自然音与随机四分音序列都由同一个状态容器承载。
struct FretboardNaturalNoteTrainerState: Equatable, Sendable {
    enum ExerciseMode: Equatable, Sendable {
        case singleNaturalTarget
        case quarterNoteSequence(QuarterNoteSequenceSpec)
    }

    struct QuarterNoteSequenceSpec: Equatable, Sendable {
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

    struct QuarterNoteSequencePrompt: Equatable, Sendable {
        var spec: QuarterNoteSequenceSpec
        var score: StaffScore
        var expectedPitchClasses: [PitchClass]

        init(
            spec: QuarterNoteSequenceSpec,
            score: StaffScore,
            expectedPitchClasses: [PitchClass]
        ) {
            precondition(score.clef == spec.clef)
            precondition(score.keySignature == .natural)
            precondition(score.notes.count == spec.noteCount)
            precondition(score.notes.allSatisfy { $0.duration == .quarter })
            precondition(expectedPitchClasses.count == score.notes.count)

            if !spec.includesAccidentals {
                precondition(expectedPitchClasses.allSatisfy(\.isNatural))
            }

            self.spec = spec
            self.score = score
            self.expectedPitchClasses = expectedPitchClasses
        }
    }

    private(set) var mode: ExerciseMode
    private(set) var targetPitchClass: PitchClass
    private(set) var quarterNoteSequencePrompt: QuarterNoteSequencePrompt?

    var prompt: Prompt {
        Prompt(targetPitchClass: targetPitchClass)
    }

    init(targetPitchClass: PitchClass) {
        precondition(
            targetPitchClass.isNatural,
            "Target pitch class must be a natural note."
        )
        self.mode = .singleNaturalTarget
        self.targetPitchClass = targetPitchClass
        quarterNoteSequencePrompt = nil
    }

    init(quarterNoteSequenceSpec spec: QuarterNoteSequenceSpec) {
        mode = .quarterNoteSequence(spec)
        targetPitchClass = .c
        quarterNoteSequencePrompt = nil
    }
}
```

## 修改 2：在 trainer 内补“生成输出”入口，并为第二步顺序判题留 stub

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: advanceToNextTarget(using:), handle(hitResult:configuration:using:)
// 功能说明: 修改前 trainer 只有单目标自然音训练流程；
// 没有 quarter-note sequence 的生成入口，也没有 session / answer hook。
mutating func advanceToNextTarget<R: RandomNumberGenerator>(
    using generator: inout R
) -> PitchClass {
    let nextTargetPitchClass = Self.randomNaturalPitchClass(
        excluding: targetPitchClass,
        using: &generator
    )
    targetPitchClass = nextTargetPitchClass
    return nextTargetPitchClass
}

mutating func handle<R: RandomNumberGenerator>(
    hitResult: FretboardHitResult,
    configuration: FretboardConfiguration,
    using generator: inout R
) -> EventResult {
    guard hitResult.phase == .ended else {
        return .ignored(.nonEndedPhase(hitResult.phase))
    }

    // ... 现有单目标判题逻辑
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: generateQuarterNoteSequencePrompt(...), makeQuarterNoteSequenceSession(), handleQuarterNoteSequenceAnswer(...), requireSingleNaturalTargetMode()
// 功能说明: 修改后 trainer 已经能在 quarter-note sequence 模式下产出 shared prompt；
// 同时给第二步顺序判题预留 session / answer 接口，并用 mode guard 保护旧单目标 API。
mutating func generateQuarterNoteSequencePrompt() -> QuarterNoteSequencePrompt {
    var generator = SystemRandomNumberGenerator()
    return generateQuarterNoteSequencePrompt(using: &generator)
}

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

mutating func generateQuarterNoteSequencePrompt(
    for spec: QuarterNoteSequenceSpec
) -> QuarterNoteSequencePrompt {
    mode = .quarterNoteSequence(spec)
    quarterNoteSequencePrompt = nil
    return generateQuarterNoteSequencePrompt()
}

func makeQuarterNoteSequenceSession() -> QuarterNoteSequenceSession {
    guard let quarterNoteSequencePrompt else {
        preconditionFailure(
            "Generate a quarter-note sequence prompt before creating a session."
        )
    }

    return QuarterNoteSequenceSession(prompt: quarterNoteSequencePrompt)
}

// Step 2 stub:
// 顺序判题会基于 session.currentIndex 对 expectedPitchClasses 逐个比较。
mutating func handleQuarterNoteSequenceAnswer(
    _ pitchClass: PitchClass,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult {
    let _ = pitchClass
    let _ = session
    preconditionFailure(
        "Quarter-note sequence answering will be implemented in a later step."
    )
}

mutating func advanceToNextTarget<R: RandomNumberGenerator>(
    using generator: inout R
) -> PitchClass {
    requireSingleNaturalTargetMode()
    let nextTargetPitchClass = Self.randomNaturalPitchClass(
        excluding: targetPitchClass,
        using: &generator
    )
    targetPitchClass = nextTargetPitchClass
    return nextTargetPitchClass
}

mutating func handle<R: RandomNumberGenerator>(
    hitResult: FretboardHitResult,
    configuration: FretboardConfiguration,
    using generator: inout R
) -> EventResult {
    requireSingleNaturalTargetMode()
    guard hitResult.phase == .ended else {
        return .ignored(.nonEndedPhase(hitResult.phase))
    }

    // ... 原有单目标判题逻辑
}
```

## 修改 3：新增 shared 四分音序列生成器，把 spec 转成 `StaffScore + expectedPitchClasses`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 shared 层没有专门的 generator 把 quarter-note sequence spec
// 转成 StaffScore，因此 trainer 即使扩了模式，也无法真正输出五线谱内容。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数/成员: makePrompt(spec:using:), resolvedCandidates(for:), naturalCandidates(for:), sharpCandidates(for:), makeMeasures(from:)
// 功能说明: 新增 shared generator，直接随机 StaffPitch；
// includesAccidentals=false 时只出自然音，true 时第一版只增加升号拼写，不生成降号拼写。
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

## 当前边界

1. 本次只完成 shared 输出基础；`QuarterNoteSequencePrompt` 还没有接入双平台 controller，也还没有写入 `staffDisplayState.score`。
2. `handleQuarterNoteSequenceAnswer(...)` 目前仍是明确的后续 stub，顺序判题尚未实现。
3. 本次没有改 `PageDisplayState`、`SettingsPanelModel`、双平台 controller、`TargetNotePromptView` 或 `NaturalNoteStripView`。
4. 本次没有补 `FretboardValidation` / `StaffValidation` 的自动化夹具，验证补齐留在后续阶段。

## 验证情况

1. 已检查 IDE 诊断，当前无新增 linter 问题：`NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`、`NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift`
2. 未执行完整 `xcodebuild` 编译验证；当前环境的 `xcode-select` 指向 Command Line Tools，无法直接完成完整 Xcode 工程构建。

# 20260415_144508_stage3_policy_driven_sequence_comparator

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_144508`
- 记录依据：基于当前工作区 `changes`、`git diff --stat`、`git diff --unified=20`、当前文件内容、`commit_records/20260415_142517_stage2_sequence_answer_carrier_extraction.md` 与本次验证结果整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 3”真实落地的代码改动；目标是把 sequence 判题从硬编码 `PitchClass` 比较改成按 `answerPolicy` 比较，并补齐 exact-note 共享验证
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`5 files changed, 214 insertions(+), 12 deletions(-)`
- 统计口径说明：
- 上面的 `git diff --stat` 是这 5 个文件相对 `HEAD` 的累计差异
- 其中 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`、`NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`、`NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`、`NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift` 在阶段 2 已经处于未提交修改状态，因此累计统计里包含了阶段 2 + 阶段 3 的叠加差异
- `NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift` 是本阶段新进入修改集的文件
- 本文下面“修改前 / 修改后”的代码片段，已经按“本轮实际修改前状态”重建：前 4 个文件以阶段 2 记录中的“修改后”状态作为本轮前镜像；`GeneratedNoteSequence.swift` 的“修改前”直接依据当前相对 `HEAD` 的差异还原
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerEvent.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift`
- 验证结果：
- `ReadLints`：对本轮 5 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug build CODE_SIGNING_ALLOWED=NO`：构建通过
- 说明：本记录文件本身是新增 markdown 记录，不计入上面“阶段 3 实际代码修改文件”的 5 个 `Swift` 文件统计

## 本次结论

- `GeneratedNoteSequenceItem` 现在已经显式暴露 `expectedNotePitch`
- `QuarterNoteSequenceEvaluation` 新增 `answeredNotePitch`，`isCorrect` 已改为真正按 `comparisonPolicy` 分流
- `FretboardNaturalNoteTrainerState.handleQuarterNoteSequenceAnswer(...)` 已经从接收裸 `PitchClass` 升级为接收 `ResolvedSequenceAnswer`
- 新增了统一 comparator `sequenceAnswerIsCorrect(...)`
- `debugSummary()` 已经显式输出 `policy=pitchClass / exactNote`
- `FretboardValidation` 已补上 exact-note 共享 comparator 的 4 组合同，以及 `.exactNote` session 的 wrong/correct 流程验证

## 修改 1：给生成模型补 full-note 投影，但不改内容模型形状

### 修改前

- `GeneratedNoteSequenceItem` 只暴露 `writtenPitch` 与 `answerPitchClass`
- trainer 需要 full-note 语义时，只能回到 `writtenPitch.notePitch`

```swift
// NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift
// 函数名/符号: struct GeneratedNoteSequenceItem
// 功能说明: 修改前生成模型只公开书写音高和 pitch-class 答案；
// exact-note comparator 还没有一个专门的 full-note 只读投影。
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
```

### 修改后

- 新增 `expectedNotePitch`
- 仍然不改变 `answerPitchClass` 作为内容层投影的模型边界

```swift
// NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift
// 函数名/符号: struct GeneratedNoteSequenceItem.expectedNotePitch
// 功能说明: 修改后生成模型显式暴露 full-note 投影；
// exact-note comparator 可以直接消费这个只读语义，而不用回退到更底层的写法字段。
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

    // Expose the full expected note without changing the generated answer model.
    var expectedNotePitch: NotePitch {
        writtenPitch.notePitch
    }
}
```

## 修改 2：把 quarter-note evaluator 和 comparator 真正切到按 policy 比较

### 修改前

- 这部分“修改前”以阶段 2 记录中的落地状态为准
- `QuarterNoteSequenceEvaluation` 只有 `answeredPitchClass`
- `isCorrect` 仍然硬编码为 `answeredPitchClass == expectedPitchClass`
- `handleQuarterNoteSequenceAnswer(...)` 虽然已拿到 `comparisonPolicy`，但还只是把它塞进 evaluation，并不参与比较
- `debugSummary()` 也不会打印 policy

```swift
// NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: struct QuarterNoteSequenceEvaluation / mutating func handleQuarterNoteSequenceAnswer(_:session:)
// 功能说明: 本轮修改前 trainer 已经拿到了 comparisonPolicy；
// 但 comparator 仍然硬编码为 pitch-class，相当于 exact-note seam 还没有真正闭环。
struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
    var expectedItem: GeneratedNoteSequenceItem
    var answeredPitchClass: PitchClass
    var answeredIndex: Int
    var nextIndex: Int
    var totalCount: Int
    var comparisonPolicy: TrainerSequenceAnswerPolicy

    var expectedPitchClass: PitchClass {
        expectedItem.answerPitchClass
    }

    var expectedNotePitch: NotePitch {
        expectedWrittenPitch.notePitch
    }

    var expectedWrittenPitch: StaffPitch {
        expectedItem.writtenPitch
    }

    var isCorrect: Bool {
        answeredPitchClass == expectedPitchClass
    }

    func debugSummary() -> String {
        let resultText = isCorrect ? "correct" : "wrong"
        let stateText = isSequenceCompleted ? "completed" : "inProgress"
        return "[QuarterNoteSequence] step=\(answeredIndex + 1)/\(totalCount) expected=\(expectedPitchClass.displayText()) written=\(expectedWrittenPitch.scientificName) answered=\(answeredPitchClass.displayText()) result=\(resultText) nextIndex=\(nextIndex) remaining=\(remainingCount) state=\(stateText)"
    }
}

mutating func handleQuarterNoteSequenceAnswer(
    _ answer: ResolvedSequenceAnswer,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult {
    let generatedSequence = requireCurrentQuarterNoteSequence()
    let comparisonPolicy = requireQuarterNoteSequenceSpec().answerPolicy
    precondition(
        session.generatedSequence == generatedSequence,
        "Quarter-note sequence session sequence must match the current trainer sequence."
    )

    guard let expectedItem = session.currentItem else {
        return .ignored(.completedSession)
    }

    let answeredIndex = session.currentIndex
    let nextIndex = answer.pitchClass == expectedItem.answerPitchClass
        ? answeredIndex + 1
        : answeredIndex
    if nextIndex != answeredIndex {
        session.currentIndex = nextIndex
    }

    return .evaluated(
        QuarterNoteSequenceEvaluation(
            expectedItem: expectedItem,
            answeredPitchClass: answer.pitchClass,
            answeredIndex: answeredIndex,
            nextIndex: nextIndex,
            totalCount: session.totalCount,
            comparisonPolicy: comparisonPolicy
        )
    )
}
```

### 修改后

- 新增 `answeredNotePitch`
- 新增 `sequenceAnswerIsCorrect(...)`
- `isCorrect` 现在真正按 `comparisonPolicy` 分流
- `.pitchClass` 比较 `answeredPitchClass`
- `.exactNote` 比较 `answeredNotePitch`
- `debugSummary()` 已输出 `policy=...`
- `handleQuarterNoteSequenceAnswer(...)` 已改为调用统一 comparator

```swift
// NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: struct QuarterNoteSequenceEvaluation / static func sequenceAnswerIsCorrect(_:expectedItem:comparisonPolicy:) / mutating func handleQuarterNoteSequenceAnswer(_:session:)
// 功能说明: 修改后 sequence comparator 已真正按 answerPolicy 工作；
// exact-note seam 不再只是字段预留，而是进入实际判题路径。
struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
    var expectedItem: GeneratedNoteSequenceItem
    var answeredPitchClass: PitchClass
    var answeredNotePitch: NotePitch?
    var answeredIndex: Int
    var nextIndex: Int
    var totalCount: Int
    var comparisonPolicy: TrainerSequenceAnswerPolicy

    var expectedPitchClass: PitchClass {
        expectedItem.answerPitchClass
    }

    var expectedNotePitch: NotePitch {
        expectedItem.expectedNotePitch
    }

    var expectedWrittenPitch: StaffPitch {
        expectedItem.writtenPitch
    }

    var isCorrect: Bool {
        switch comparisonPolicy {
        case .pitchClass:
            return answeredPitchClass == expectedPitchClass
        case .exactNote:
            return answeredNotePitch == expectedNotePitch
        }
    }

    func debugSummary() -> String {
        let policyText = comparisonPolicy.debugName
        let resultText = isCorrect ? "correct" : "wrong"
        let stateText = isSequenceCompleted ? "completed" : "inProgress"
        let answeredNoteText = answeredNotePitch?.displayText() ?? "nil"
        return "[QuarterNoteSequence] policy=\(policyText) step=\(answeredIndex + 1)/\(totalCount) expectedClass=\(expectedPitchClass.displayText()) expectedNote=\(expectedNotePitch.displayText()) written=\(expectedWrittenPitch.scientificName) answeredClass=\(answeredPitchClass.displayText()) answeredNote=\(answeredNoteText) result=\(resultText) nextIndex=\(nextIndex) remaining=\(remainingCount) state=\(stateText)"
    }
}

static func sequenceAnswerIsCorrect(
    _ answer: ResolvedSequenceAnswer,
    expectedItem: GeneratedNoteSequenceItem,
    comparisonPolicy: TrainerSequenceAnswerPolicy
) -> Bool {
    precondition(
        answer.notePitch?.pitchClass == answer.pitchClass || answer.notePitch == nil,
        "Resolved sequence answer note pitch must match its pitch class."
    )

    switch comparisonPolicy {
    case .pitchClass:
        return answer.pitchClass == expectedItem.answerPitchClass
    case .exactNote:
        return answer.notePitch == expectedItem.expectedNotePitch
    }
}

mutating func handleQuarterNoteSequenceAnswer(
    _ answer: ResolvedSequenceAnswer,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult {
    let generatedSequence = requireCurrentQuarterNoteSequence()
    let comparisonPolicy = requireQuarterNoteSequenceSpec().answerPolicy
    precondition(
        session.generatedSequence == generatedSequence,
        "Quarter-note sequence session sequence must match the current trainer sequence."
    )

    guard let expectedItem = session.currentItem else {
        return .ignored(.completedSession)
    }

    let answeredIndex = session.currentIndex
    let isCorrect = Self.sequenceAnswerIsCorrect(
        answer,
        expectedItem: expectedItem,
        comparisonPolicy: comparisonPolicy
    )
    let nextIndex = isCorrect ? answeredIndex + 1 : answeredIndex
    if isCorrect {
        session.currentIndex = nextIndex
    }

    return .evaluated(
        QuarterNoteSequenceEvaluation(
            expectedItem: expectedItem,
            answeredPitchClass: answer.pitchClass,
            answeredNotePitch: answer.notePitch,
            answeredIndex: answeredIndex,
            nextIndex: nextIndex,
            totalCount: session.totalCount,
            comparisonPolicy: comparisonPolicy
        )
    )
}
```

## 修改 3：双端 controller 不再把答案降级成 `pitchClass`

### 3.1 `iOSViewController.swift`

#### 修改前

- 这部分“修改前”以阶段 2 记录中的落地状态为准
- 虽然 controller 已经拿到 `ResolvedSequenceAnswer`
- 但传给 trainer 时仍然只传 `answer.pitchClass`

```swift
// NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: handleQuarterNoteSequenceAnswer(_:answer:)
// 功能说明: 本轮修改前 iOS controller 仍把完整答案降级成 pitchClass；
// 这样 exact-note comparator 即使存在，也无法从平台侧真正接收到完整输入。
private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    answer: ResolvedSequenceAnswer
) {
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        answer.pitchClass,
        session: &quarterNoteSequenceSession
    )
    // ... 其余日志逻辑保持不变 ...
}
```

#### 修改后

- iOS 现在把完整 `ResolvedSequenceAnswer` 直接传给 trainer

```swift
// NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: handleQuarterNoteSequenceAnswer(_:answer:)
// 功能说明: 修改后 iOS controller 不再丢弃 full-note 信息；
// trainer 可以直接消费完整的 sequence answer carrier。
private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    answer: ResolvedSequenceAnswer
) {
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        answer,
        session: &quarterNoteSequenceSession
    )
    // ... 其余日志逻辑保持不变 ...
}
```

### 3.2 `macOSViewController.swift`

#### 修改前

```swift
// NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handleQuarterNoteSequenceAnswer(_:answer:)
// 功能说明: 本轮修改前 macOS controller 与 iOS 一样，仍把完整答案降级成 pitchClass；
// 这会阻断 exact-note comparator 所需的 full-note 输入。
private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    answer: ResolvedSequenceAnswer
) {
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        answer.pitchClass,
        session: &quarterNoteSequenceSession
    )
    // ... 其余日志逻辑保持不变 ...
}
```

#### 修改后

```swift
// NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handleQuarterNoteSequenceAnswer(_:answer:)
// 功能说明: 修改后 macOS controller 同步把完整 sequence answer carrier 传给 trainer；
// 双端都能进入相同的 exact-note 判题链路。
private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    answer: ResolvedSequenceAnswer
) {
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        answer,
        session: &quarterNoteSequenceSession
    )
    // ... 其余日志逻辑保持不变 ...
}
```

## 修改 4：补阶段 3 验证，把 comparator 合同和 exact-note 流程真正测透

### 修改前

- 这部分“修改前”以阶段 2 记录中的落地状态为准
- `FretboardValidation` 只覆盖了阶段 2 的 answer carrier 恢复合同
- 还没有覆盖：
- 4 组 shared comparator 合同
- `.exactNote` wrong/correct session 流程
- `answeredNotePitch`
- `debugSummary()` 里的 `policy=...`

```swift
// NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 本轮修改前 validation 已经覆盖了 answer carrier 恢复；
// 但 comparator 仍然缺少 exact-note 级别的共享合同和 session 行为验证。
logStage("resolvedSequenceAnswer")
let resolvedAnswerCell = FretboardCell(
    stringIndex: 0,
    fret: fixture.configuration.fretRange.lowerBound
)
if let resolvedAnswerNotePitch = fixture.configuration.notePitch(
    for: resolvedAnswerCell
) {
    let pitchClassEvent = ExerciseAnswerEvent.pitchClass(
        resolvedAnswerNotePitch.pitchClass,
        from: .naturalNoteStrip
    )
    // ... 验证 resolvedSequenceAnswer / resolvedPitchClass ...
}

switch naturalTrainer.handleQuarterNoteSequenceAnswer(
    sequenceAnswer(incorrectPitchClass),
    session: &incorrectSession
) {
case let .evaluated(evaluation):
    if evaluation.comparisonPolicy != naturalSpec.answerPolicy {
        record("quarter-note trainer 错误作答时返回的 comparisonPolicy 未对齐当前 spec.answerPolicy。")
    }
    if evaluation.expectedNotePitch != evaluation.expectedWrittenPitch.notePitch {
        record("quarter-note trainer 错误作答时返回的 expectedNotePitch 未正确投影自 expectedWrittenPitch.notePitch。")
    }
    // ... 其余阶段 1 / 2 的旧断言 ...
default:
    record("quarter-note trainer 错误作答未返回 evaluated 结果。")
}

// 这里还没有 shared comparator 4 组合同，也没有 exact-note flow 验证。
```

### 修改后

- 新增 `policyComparator` stage，覆盖 4 组共享 comparator 合同
- 新增 `exactNoteFlow` stage，验证 `.exactNote` 下同音名不同八度错误、完全匹配正确
- 对 `.pitchClass` 旧流程补充：
- `answeredNotePitch == nil`
- `debugSummary()` 包含 `policy=pitchClass`

```swift
// NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后 validation 已把阶段 3 的 comparator 合同和 exact-note flow 锁进回归链；
// 这样 exact-note seam 不再只是实现细节，而是有共享验证保护的正式能力。
logStage("policyComparator")
let c6ExpectedItem = GeneratedNoteSequenceItem(
    writtenPitch: StaffPitch(letter: .c, octave: 6)
)
let cPitchClassAnswer = sequenceAnswer(.c)
let c3Answer = sequenceAnswer(
    .c,
    notePitch: NotePitch(pitchClass: .c, octave: 3),
    surfaceID: .fretboard
)
let c6Answer = sequenceAnswer(
    .c,
    notePitch: NotePitch(pitchClass: .c, octave: 6),
    surfaceID: .piano
)
if !FretboardNaturalNoteTrainerState.sequenceAnswerIsCorrect(
    cPitchClassAnswer,
    expectedItem: c6ExpectedItem,
    comparisonPolicy: .pitchClass
) {
    record("shared sequence comparator 未把 C6 对 C 的 pitchClass 比较判为正确。")
}
if !FretboardNaturalNoteTrainerState.sequenceAnswerIsCorrect(
    c3Answer,
    expectedItem: c6ExpectedItem,
    comparisonPolicy: .pitchClass
) {
    record("shared sequence comparator 未把 C6 对 C3 的 pitchClass 比较判为正确。")
}
if FretboardNaturalNoteTrainerState.sequenceAnswerIsCorrect(
    c3Answer,
    expectedItem: c6ExpectedItem,
    comparisonPolicy: .exactNote
) {
    record("shared sequence comparator 错把 C6 对 C3 的 exactNote 比较判为正确。")
}
if !FretboardNaturalNoteTrainerState.sequenceAnswerIsCorrect(
    c6Answer,
    expectedItem: c6ExpectedItem,
    comparisonPolicy: .exactNote
) {
    record("shared sequence comparator 未把 C6 对 C6 的 exactNote 比较判为正确。")
}

logStage("exactNoteFlow")
let exactSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
    clef: .treble,
    noteCount: 1,
    includesAccidentals: false,
    answerPolicy: .exactNote
)
var exactTrainer = FretboardNaturalNoteTrainerState(
    quarterNoteSequenceSpec: exactSpec
)
var exactWrongSession = exactTrainer.makeQuarterNoteSequenceSession()
guard let exactExpectedItem = exactWrongSession.currentItem else {
    record("exact-note quarter-note trainer 缺少首个 expected item。")
    return
}
let exactExpectedNotePitch = exactExpectedItem.expectedNotePitch
let exactWrongAnswer = sequenceAnswer(
    exactExpectedNotePitch.pitchClass,
    notePitch: NotePitch(
        pitchClass: exactExpectedNotePitch.pitchClass,
        octave: exactExpectedNotePitch.octave + 1
    ),
    surfaceID: .piano
)
switch exactTrainer.handleQuarterNoteSequenceAnswer(
    exactWrongAnswer,
    session: &exactWrongSession
) {
case let .evaluated(evaluation):
    if evaluation.answeredNotePitch != exactWrongAnswer.notePitch {
        record("exact-note quarter-note trainer 错误作答时 answeredNotePitch 未保留完整输入。")
    }
    if evaluation.isCorrect {
        record("exact-note quarter-note trainer 错把同音名不同八度输入判为正确。")
    }
    if !evaluation.debugSummary().contains("policy=exactNote") {
        record("exact-note quarter-note trainer 的 debugSummary 应输出 policy=exactNote。")
    }
default:
    record("exact-note quarter-note trainer 错误作答未返回 evaluated 结果。")
}

var exactCorrectSession = exactTrainer.makeQuarterNoteSequenceSession()
let exactCorrectAnswer = sequenceAnswer(
    exactExpectedNotePitch.pitchClass,
    notePitch: exactExpectedNotePitch,
    surfaceID: .piano
)
switch exactTrainer.handleQuarterNoteSequenceAnswer(
    exactCorrectAnswer,
    session: &exactCorrectSession
) {
case let .evaluated(evaluation):
    if !evaluation.isCorrect {
        record("exact-note quarter-note trainer 未把完全匹配的 NotePitch 判为正确。")
    }
    if !evaluation.isSequenceCompleted {
        record("exact-note quarter-note trainer 单题正确作答后应进入 completed 状态。")
    }
default:
    record("exact-note quarter-note trainer 正确作答未返回 evaluated 结果。")
}
```

## 本次没有做的事情

- 没有修改 `ExerciseAnswerEvent.swift`
- 没有修改 `ExerciseAnswerRouter.swift`
- 没有新增 `ExerciseCompositionPreset.staffToPiano`
- 没有接入 piano 输入桥
- 没有开放 `SR-1` / `SR-2` 的 settings 入口
- 没有修改 `SettingsPanelModel.swift`
- 没有修改 `ExerciseScene.swift`
- 没有接 `staffToPiano` scene

## 与计划的一致性说明

- 这次实现严格对应 `阶段 3：把 sequence 判题从硬编码 PitchClass 改成按 policy 比较`
- 实际落地内容正好覆盖了计划里的这些点：
- `handleQuarterNoteSequenceAnswer(...)` 的入参升级为 `ResolvedSequenceAnswer`
- comparator 统一收口到按 `answerPolicy` 分流
- `QuarterNoteSequenceEvaluation` 增加 `answeredNotePitch`
- `QuarterNoteSequenceEvaluation.expectedNotePitch` 改为消费生成模型的 full-note 投影
- `debugSummary()` 输出 policy
- `GeneratedNoteSequence.swift` 只补 `expectedNotePitch` 一类 computed property，不重构生成模型
- `FretboardValidation` 已覆盖 `C6 -> C` / `C6 -> C3` / `C6 -> C3` exact-note wrong / `C6 -> C6` exact-note correct 这 4 组共享 comparator 合同
- 这次没有越界进入 `阶段 4`，因为 `staffToPiano` 组合、scene、renderer 都还没有改
- 这次也没有越界进入 `阶段 5`，因为平台侧 piano 输入桥与 SR mode 入口还没有接

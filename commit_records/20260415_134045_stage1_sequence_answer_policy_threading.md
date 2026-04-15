# 20260415_134045_stage1_sequence_answer_policy_threading

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_134045`
- 记录依据：基于当前工作区 `changes`、`git diff --stat`、`git diff --unified=20`、当前文件内容与本次验证结果整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 1”真实落地的代码改动；目标是把 `answerPolicy` 挂进现有 sequence 配置链，并补齐 evaluator 侧只读投影，不改变现有 `PitchClass` 判题行为
- 当前 diff 统计：`3 files changed, 43 insertions(+), 11 deletions(-)`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerEvent.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- 验证结果：
- `ReadLints`：对上述 3 个 Swift 文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug build CODE_SIGNING_ALLOWED=NO`：构建通过
- 说明：本记录文件本身是新增 markdown 记录，不计入上面“阶段 1 实际代码修改文件”的 3 个 `Swift` 文件统计

## 本次结论

- `TrainerSequenceConfiguration` 现在正式持有 `answerPolicy`，不再只靠 `TrainerExerciseMode` 或未来 UI 入口隐式决定
- `QuarterNoteSequenceSpec` 已经把 `answerPolicy` 挂进现有 sequence 配置链，后续 controller 仍然只需要消费 `configuredQuarterNoteSequenceSpec`
- `QuarterNoteSequenceEvaluation` 已补齐 `comparisonPolicy` 与 `expectedNotePitch`，为阶段 3 的 comparator 切换提前埋好 evaluator seam
- 当前运行时判题逻辑仍然保持不变，`handleQuarterNoteSequenceAnswer(...)` 仍按 `PitchClass` 比较；本次只是把 policy 线程打通，不提前改行为
- `FretboardValidation` 已补到阶段 1 新字段，避免出现“shared 结构升级了，但验证层对新字段完全无感知”的情况

## 修改 1：把 `answerPolicy` 挂进 `TrainerSequenceConfiguration` 与 spec 双向映射

### 修改前

- `TrainerSequenceConfiguration` 只承载 `clef / noteCount / includesAccidentals`
- `default` 没有显式的 sequence 判题策略
- `quarterNoteSequenceSpec` 双向映射不会带 `answerPolicy`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: struct TrainerSequenceConfiguration / extension TrainerSequenceConfiguration
// 功能说明: 修改前 sequence 配置只负责谱面生成参数；
// `answerPolicy` 还没有进入配置链，因此 controller 侧也拿不到这个字段。
struct TrainerSequenceConfiguration: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool

    static let `default` = TrainerSequenceConfiguration(
        clef: .treble,
        noteCount: 7,
        includesAccidentals: false
    )

    init(
        clef: StaffClef = .treble,
        noteCount: Int = 7,
        includesAccidentals: Bool = false
    ) {
        precondition(
            noteCount > 0,
            "Trainer sequence note count must be greater than zero."
        )
        self.clef = clef
        self.noteCount = noteCount
        self.includesAccidentals = includesAccidentals
    }
}

extension TrainerSequenceConfiguration {
    init(
        quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) {
        self.init(
            clef: quarterNoteSequenceSpec.clef,
            noteCount: quarterNoteSequenceSpec.noteCount,
            includesAccidentals: quarterNoteSequenceSpec.includesAccidentals
        )
    }

    var quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
        FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals
        )
    }
}
```

### 修改后

- 新增 `answerPolicy`
- `default` 显式冻结为 `.pitchClass`
- spec 与 configuration 的双向映射都带上 `answerPolicy`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: struct TrainerSequenceConfiguration / extension TrainerSequenceConfiguration
// 功能说明: 修改后 sequence 配置正式承载判题策略；
// `configuredQuarterNoteSequenceSpec` 会通过这里的双向映射自动携带 `answerPolicy`。
struct TrainerSequenceConfiguration: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool
    var answerPolicy: TrainerSequenceAnswerPolicy

    static let `default` = TrainerSequenceConfiguration(
        clef: .treble,
        noteCount: 7,
        includesAccidentals: false,
        answerPolicy: .pitchClass
    )

    init(
        clef: StaffClef = .treble,
        noteCount: Int = 7,
        includesAccidentals: Bool = false,
        answerPolicy: TrainerSequenceAnswerPolicy
    ) {
        precondition(
            noteCount > 0,
            "Trainer sequence note count must be greater than zero."
        )
        self.clef = clef
        self.noteCount = noteCount
        self.includesAccidentals = includesAccidentals
        self.answerPolicy = answerPolicy
    }
}

extension TrainerSequenceConfiguration {
    init(
        quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) {
        self.init(
            clef: quarterNoteSequenceSpec.clef,
            noteCount: quarterNoteSequenceSpec.noteCount,
            includesAccidentals: quarterNoteSequenceSpec.includesAccidentals,
            answerPolicy: quarterNoteSequenceSpec.answerPolicy
        )
    }

    var quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
        FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals,
            answerPolicy: answerPolicy
        )
    }
}
```

## 修改 2：把 `QuarterNoteSequenceSpec` 与 `QuarterNoteSequenceEvaluation` 的阶段 1 seam 接通

### 2.1 `QuarterNoteSequenceSpec`

#### 修改前

- `QuarterNoteSequenceSpec` 只有内容生成字段
- 注释仍然停留在阶段 0 的“以后再把 `TrainerSequenceAnswerPolicy` 挂进来”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: struct QuarterNoteSequenceSpec
// 功能说明: 修改前 spec 还没有真正承载判题策略；
// 注释表达的是“后续阶段再把 policy 挂进来”的阶段 0 语义。
// Sequence content generation and judging policy stay decoupled.
// Stage 0 only freezes the seam here; later phases will thread
// `TrainerSequenceAnswerPolicy` through this spec instead of embedding it
// into `GeneratedNoteSequence`.
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
```

#### 修改后

- `QuarterNoteSequenceSpec` 新增 `answerPolicy`
- 语义注释同步改成当前真实状态：spec 已经承载判题策略，但仍与 `GeneratedNoteSequence` 解耦

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: struct QuarterNoteSequenceSpec
// 功能说明: 修改后 spec 正式承载 sequence 判题策略；
// 这样后续切换 pitch-class / exact-note 时，不需要改生成内容模型。
// Sequence content generation and judging policy stay decoupled.
// The spec carries the judging policy so later evaluator changes can switch
// between pitch-class and exact-note comparison without reshaping
// `GeneratedNoteSequence`.
struct QuarterNoteSequenceSpec: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool
    var answerPolicy: TrainerSequenceAnswerPolicy

    init(
        clef: StaffClef,
        noteCount: Int,
        includesAccidentals: Bool,
        answerPolicy: TrainerSequenceAnswerPolicy
    ) {
        precondition(
            noteCount > 0,
            "Quarter-note sequence note count must be greater than zero."
        )
        self.clef = clef
        self.noteCount = noteCount
        self.includesAccidentals = includesAccidentals
        self.answerPolicy = answerPolicy
    }
}
```

### 2.2 `QuarterNoteSequenceEvaluation` 与 `handleQuarterNoteSequenceAnswer(...)`

#### 修改前

- evaluator 只暴露 `PitchClass` 级别结果
- `handleQuarterNoteSequenceAnswer(...)` 不会把当前 spec 的 policy 带入 evaluation

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: struct QuarterNoteSequenceEvaluation / handleQuarterNoteSequenceAnswer(_:session:)
// 功能说明: 修改前 evaluator 只有 pitch-class 视角；
// handler 返回 evaluation 时不会回填当前 spec 的判题策略。
struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
    var expectedItem: GeneratedNoteSequenceItem
    var answeredPitchClass: PitchClass
    var answeredIndex: Int
    var nextIndex: Int
    var totalCount: Int

    var expectedPitchClass: PitchClass {
        expectedItem.answerPitchClass
    }

    var expectedWrittenPitch: StaffPitch {
        expectedItem.writtenPitch
    }
}

mutating func handleQuarterNoteSequenceAnswer(
    _ pitchClass: PitchClass,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult {
    let generatedSequence = requireCurrentQuarterNoteSequence()
    precondition(
        session.generatedSequence == generatedSequence,
        "Quarter-note sequence session sequence must match the current trainer sequence."
    )

    guard let expectedItem = session.currentItem else {
        return .ignored(.completedSession)
    }

    let answeredIndex = session.currentIndex
    let expectedPitchClass = expectedItem.answerPitchClass
    let isCorrect = pitchClass == expectedPitchClass
    let nextIndex = isCorrect ? answeredIndex + 1 : answeredIndex
    if isCorrect {
        session.currentIndex = nextIndex
    }

    return .evaluated(
        QuarterNoteSequenceEvaluation(
            expectedItem: expectedItem,
            answeredPitchClass: pitchClass,
            answeredIndex: answeredIndex,
            nextIndex: nextIndex,
            totalCount: session.totalCount
        )
    )
}
```

#### 修改后

- evaluator 新增 `comparisonPolicy`
- evaluator 新增 `expectedNotePitch`，但只是 `expectedWrittenPitch.notePitch` 的只读投影
- `handleQuarterNoteSequenceAnswer(...)` 从当前 spec 读取 `answerPolicy`，回填到 evaluation
- 当前 `isCorrect` 仍然保持旧的 `PitchClass` 比较，不提前进入阶段 3

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: struct QuarterNoteSequenceEvaluation / handleQuarterNoteSequenceAnswer(_:session:)
// 功能说明: 修改后 evaluator 已持有判题策略和完整音高投影；
// 但真正按 policy 分流比较仍留在后续阶段，本次只做配置链与 evaluation seam 贯通。
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

    // Keep the full `NotePitch` projection available so later exact-note
    // comparison can stay in the evaluator instead of reshaping the content model.
    var expectedNotePitch: NotePitch {
        expectedWrittenPitch.notePitch
    }

    var expectedWrittenPitch: StaffPitch {
        expectedItem.writtenPitch
    }
}

mutating func handleQuarterNoteSequenceAnswer(
    _ pitchClass: PitchClass,
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
    let expectedPitchClass = expectedItem.answerPitchClass
    let isCorrect = pitchClass == expectedPitchClass
    let nextIndex = isCorrect ? answeredIndex + 1 : answeredIndex
    if isCorrect {
        session.currentIndex = nextIndex
    }

    return .evaluated(
        QuarterNoteSequenceEvaluation(
            expectedItem: expectedItem,
            answeredPitchClass: pitchClass,
            answeredIndex: answeredIndex,
            nextIndex: nextIndex,
            totalCount: session.totalCount,
            comparisonPolicy: comparisonPolicy
        )
    )
}
```

## 修改 3：把阶段 1 新字段补进现有 `FretboardValidation`

### 修改前

- `naturalSpec` / `accidentalSpec` 还没有 `answerPolicy`
- validation 只验证旧的 `expectedPitchClass / answeredPitchClass / index` 等字段
- 对 `comparisonPolicy` 与 `expectedNotePitch` 没有任何约束

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改前 validation 只覆盖旧的 sequence 评估字段；
// 新增的 policy 与 full-note 投影还没有进入验证链。
let naturalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
    clef: .treble,
    noteCount: 7,
    includesAccidentals: false
)

switch naturalTrainer.handleQuarterNoteSequenceAnswer(
    incorrectPitchClass,
    session: &incorrectSession
) {
case let .evaluated(evaluation):
    if evaluation.expectedPitchClass != firstExpectedPitchClass {
        record("quarter-note trainer 错误作答时返回的 expectedPitchClass 与 session 首题不一致。")
    }
    if evaluation.answeredPitchClass != incorrectPitchClass {
        record("quarter-note trainer 错误作答时返回的 answeredPitchClass 不一致。")
    }
    // ... 其余旧断言 ...
default:
    record("quarter-note trainer 错误作答未返回 evaluated 结果。")
}

switch naturalTrainer.handleQuarterNoteSequenceAnswer(
    expectedPitchClass,
    session: &completedSession
) {
case let .evaluated(evaluation):
    if evaluation.expectedPitchClass != expectedPitchClass {
        record("quarter-note trainer 正确作答时返回的 expectedPitchClass 与当前题目不一致。")
    }
    if evaluation.answeredPitchClass != expectedPitchClass {
        record("quarter-note trainer 正确作答时返回的 answeredPitchClass 不一致。")
    }
    // ... 其余旧断言 ...
default:
    record("quarter-note trainer 正确作答未返回 evaluated 结果。")
}

let accidentalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
    clef: .bass,
    noteCount: 128,
    includesAccidentals: true
)
```

### 修改后

- `naturalSpec` / `accidentalSpec` 显式补上 `.pitchClass`
- 错误作答和正确作答两条路径都新增校验：
- `evaluation.comparisonPolicy == naturalSpec.answerPolicy`
- `evaluation.expectedNotePitch == evaluation.expectedWrittenPitch.notePitch`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后 validation 把阶段 1 新增字段纳入现有 sequence 合同；
// 这样 `answerPolicy` 与 `expectedNotePitch` 不会只存在于结构定义里而无人验证。
let naturalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
    clef: .treble,
    noteCount: 7,
    includesAccidentals: false,
    answerPolicy: .pitchClass
)

switch naturalTrainer.handleQuarterNoteSequenceAnswer(
    incorrectPitchClass,
    session: &incorrectSession
) {
case let .evaluated(evaluation):
    if evaluation.expectedPitchClass != firstExpectedPitchClass {
        record("quarter-note trainer 错误作答时返回的 expectedPitchClass 与 session 首题不一致。")
    }
    if evaluation.comparisonPolicy != naturalSpec.answerPolicy {
        record("quarter-note trainer 错误作答时返回的 comparisonPolicy 未对齐当前 spec.answerPolicy。")
    }
    if evaluation.expectedNotePitch != evaluation.expectedWrittenPitch.notePitch {
        record("quarter-note trainer 错误作答时返回的 expectedNotePitch 未正确投影自 expectedWrittenPitch.notePitch。")
    }
    if evaluation.answeredPitchClass != incorrectPitchClass {
        record("quarter-note trainer 错误作答时返回的 answeredPitchClass 不一致。")
    }
    // ... 其余旧断言 ...
default:
    record("quarter-note trainer 错误作答未返回 evaluated 结果。")
}

switch naturalTrainer.handleQuarterNoteSequenceAnswer(
    expectedPitchClass,
    session: &completedSession
) {
case let .evaluated(evaluation):
    if evaluation.expectedPitchClass != expectedPitchClass {
        record("quarter-note trainer 正确作答时返回的 expectedPitchClass 与当前题目不一致。")
    }
    if evaluation.comparisonPolicy != naturalSpec.answerPolicy {
        record("quarter-note trainer 正确作答时返回的 comparisonPolicy 未对齐当前 spec.answerPolicy。")
    }
    if evaluation.expectedNotePitch != evaluation.expectedWrittenPitch.notePitch {
        record("quarter-note trainer 正确作答时返回的 expectedNotePitch 未正确投影自 expectedWrittenPitch.notePitch。")
    }
    if evaluation.answeredPitchClass != expectedPitchClass {
        record("quarter-note trainer 正确作答时返回的 answeredPitchClass 不一致。")
    }
    // ... 其余旧断言 ...
default:
    record("quarter-note trainer 正确作答未返回 evaluated 结果。")
}

let accidentalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
    clef: .bass,
    noteCount: 128,
    includesAccidentals: true,
    answerPolicy: .pitchClass
)
```

## 本次没有做的事情

- 没有修改 `ExerciseAnswerPayload`
- 没有引入 `ResolvedSequenceAnswer`
- 没有修改 `ExerciseAnswerRouter.swift`
- 没有把 `handleQuarterNoteSequenceAnswer(...)` 的入参从 `PitchClass` 升级为统一答案载体
- 没有让 `.exactNote` 真正参与比较；`isCorrect` 仍然是 `answeredPitchClass == expectedPitchClass`
- 没有修改 `iOSViewController.swift` 或 `macOSViewController.swift`；这次不需要新 controller 代码，因为 `configuredQuarterNoteSequenceSpec` 已经通过配置映射自动拿到 `answerPolicy`
- 没有接 piano 输入桥，也没有开放 `SR-1` 运行时入口

## 与计划的一致性说明

- 这次实现严格对应 `阶段 1：把 answerPolicy 挂进现有 sequence 配置链路`
- 实际落地内容正好覆盖了计划里的这些点：
- 给 `TrainerSequenceConfiguration` 增加 `answerPolicy`
- 给 `QuarterNoteSequenceSpec` 同步增加 `answerPolicy`
- 补齐 `TrainerSequenceConfiguration.init(quarterNoteSequenceSpec:)` 与 `quarterNoteSequenceSpec` 的双向映射
- 给 `QuarterNoteSequenceEvaluation` 增加 `comparisonPolicy` 与 `expectedNotePitch`
- 保持 `GeneratedNoteSequence` 不承载判题策略
- 这次没有越界进入 `阶段 2`，因为还没有引入统一的 sequence 答案载体
- 这次也没有越界进入 `阶段 3`，因为比较逻辑还没有切到按 `comparisonPolicy` 分流

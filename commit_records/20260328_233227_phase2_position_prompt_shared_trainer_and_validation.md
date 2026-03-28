# 20260328_233227_phase2_position_prompt_shared_trainer_and_validation

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_233227`
- 记录范围：实施“位置音名模式”计划的阶段 2，只补 shared 的位置题状态机与 validation，并补齐 iOS/macOS 控制器对新 `mode` 的安全分支，不涉及白圈渲染、页面布局切换和按钮事件接线
- 本次目标：把“随机在指板选一个自然音位置，用户点击 7 个自然音按钮作答”的核心题目语义沉到 shared trainer，确保后续 UI 只做投影与时序
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 阶段 1 已经补齐了 `TrainerDisplayState.positionPrompt`、`PageDisplayState.positionPrompt` 和 settings 入口，但 shared trainer 仍然只有两条可用语义：
- “点指板答题”的 `singleNaturalTarget / singleCoverage`
- “答 PitchClass”的 `quarterNoteSequence`
- 新模式的真实交互是“题目来源于指板位置，答案来源于按钮 PitchClass”，它在输入形态上更接近 `quarterNoteSequenceAnswer`，但在题目来源和会话语义上又完全不同于 sequence
- 如果把这条逻辑直接写进控制器，shared 层就失去统一真相，后续白圈、红闪、绿停留和按钮接线都只能围绕平台状态拼装
- 因此阶段 2 的根因级修复，是在 shared 层正式引入 `positionPrompt` 的 `mode / session / evaluation / answerResult`，并用 validation 把“只抽自然音位置、错不推进、对才推进”固定下来

## 修改 1：在 `FretboardNaturalNoteTrainer.swift` 中为 shared mode 增加 `positionPrompt`

### 修改前

- `ExerciseMode` 只有 `.singleNaturalTarget` 和 `.quarterNoteSequence`
- shared trainer 没有第三种模式的真相表达

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: FretboardNaturalNoteTrainerState.ExerciseMode
// 功能说明: 修改前 shared trainer 只能表达 legacy 单目标和四分音序列两种模式，
// 还没有“位置题 + 按钮作答”的模式入口。
enum ExerciseMode: Equatable, Sendable {
    case singleNaturalTarget
    case quarterNoteSequence(QuarterNoteSequenceSpec)
}
```

### 修改后

- `ExerciseMode` 新增 `.positionPrompt`
- shared trainer 从状态层开始正式拥有第三种练习模式

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: FretboardNaturalNoteTrainerState.ExerciseMode
// 功能说明: 修改后 shared trainer 已经可以表达位置音名模式，
// 后续 session、validation 和控制器投影都以这个 mode 为分流真相。
enum ExerciseMode: Equatable, Sendable {
    case singleNaturalTarget
    case positionPrompt
    case quarterNoteSequence(QuarterNoteSequenceSpec)
}
```

## 修改 2：新增 position prompt 专用的 session / evaluation / result 类型

### 修改前

- shared 层只有 `SingleCoverageSession` 和 `QuarterNoteSequenceSession`
- 没有一个值类型可以表达：
- 当前题目的 `promptCell`
- 当前题目的正确自然音名
- 本次按钮作答是否推进到了下一题

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: SingleCoverageSession, QuarterNoteSequenceSession
// 功能说明: 修改前 shared 层已有“点击指板覆盖题”和“PitchClass 序列题”，
// 但没有“题干是位置、答案是按钮音名”的独立会话模型。
struct SingleCoverageSession: Equatable, Sendable {
    var targetPitchClass: PitchClass
    var requiredCells: Set<FretboardCell>
    var visitedCells: Set<FretboardCell>
}

struct QuarterNoteSequenceSession: Equatable, Sendable {
    var generatedSequence: GeneratedNoteSequence
    var currentIndex: Int
}
```

### 修改后

- 新增 `PositionPromptSession`
- 新增 `PositionPromptEvaluation`
- 新增 `PositionPromptAnswerResult`
- 新类型明确承载“当前题目位置、当前题目正确音名、作答后是否推进以及下一题信息”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: PositionPromptSession, PositionPromptEvaluation, PositionPromptAnswerResult
// 功能说明: 修改后 shared 层拥有位置题专用值类型，
// 可以稳定表达“当前高亮位置 -> 期望自然音 -> 本次按钮作答结果 -> 下一题位置”。
struct PositionPromptSession: Equatable, Sendable {
    var promptCell: FretboardCell
    var promptPitchClass: PitchClass

    init(
        promptCell: FretboardCell,
        promptPitchClass: PitchClass
    ) {
        precondition(
            promptPitchClass.isNatural,
            "Position prompt session pitch class must be a natural note."
        )
        self.promptCell = promptCell
        self.promptPitchClass = promptPitchClass
    }
}

struct PositionPromptEvaluation: Equatable, Sendable {
    var promptCell: FretboardCell
    var expectedPitchClass: PitchClass
    var answeredPitchClass: PitchClass
    var nextPromptCell: FretboardCell
    var nextPromptPitchClass: PitchClass

    var isCorrect: Bool {
        answeredPitchClass == expectedPitchClass
    }

    var didAdvancePrompt: Bool {
        isCorrect
    }

    var didChangePromptCell: Bool {
        nextPromptCell != promptCell
    }

    func debugSummary() -> String {
        let resultText = isCorrect ? "correct" : "wrong"
        let nextCellText = "string=\\(nextPromptCell.stringIndex) fret=\\(nextPromptCell.fret)"
        return "[PositionPrompt] prompt=\\(expectedPitchClass.displayText()) string=\\(promptCell.stringIndex) fret=\\(promptCell.fret) answered=\\(answeredPitchClass.displayText()) result=\\(resultText) next=\\(nextPromptPitchClass.displayText()) \\(nextCellText)"
    }
}

enum PositionPromptAnswerResult: Equatable, Sendable {
    case evaluated(PositionPromptEvaluation)
}
```

## 修改 3：新增 position prompt 的构造入口与按钮判题入口

### 修改前

- shared trainer 只有：
- `makeSingleCoverageSession(configuration:)`
- `makeQuarterNoteSequenceSession()`
- `handleSingleCoverageHit(...)`
- `handleQuarterNoteSequenceAnswer(...)`
- 不存在任何“从指板位置出题 + 用 `PitchClass` 按钮作答”的 dedicated API

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makeSingleCoverageSession, makeQuarterNoteSequenceSession,
// handleSingleCoverageHit, handleQuarterNoteSequenceAnswer
// 功能说明: 修改前 trainer 只有 click-on-fretboard 和 answer-by-pitchClass 两条旧语义，
// 还没有 position prompt 的创建和判题 API。
func makeQuarterNoteSequenceSession() -> QuarterNoteSequenceSession { ... }

func makeSingleCoverageSession(
    configuration: FretboardConfiguration
) -> SingleCoverageSession { ... }

mutating func handleSingleCoverageHit(
    _ hitResult: FretboardHitResult,
    configuration: FretboardConfiguration,
    session: inout SingleCoverageSession
) -> SingleCoverageAnswerResult { ... }

mutating func handleQuarterNoteSequenceAnswer(
    _ pitchClass: PitchClass,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult { ... }
```

### 修改后

- 新增 `init(positionPromptMode: Void)`，为第三模式提供稳定初始化入口
- 新增 `makePositionPromptSession(...)`
- 新增 `handlePositionPromptAnswer(...)`
- 错误答案不会改变 session；正确答案才会生成下一题并写回 session

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: init(positionPromptMode:), makePositionPromptSession(configuration:using:),
// handlePositionPromptAnswer(_:configuration:session:using:)
// 功能说明: 修改后 shared trainer 可以独立创建位置题会话，
// 并以按钮传入的 PitchClass 为输入完成“错不推进、对才推进”的 shared 判题。
init(positionPromptMode: Void) {
    mode = .positionPrompt
    // 位置题模式当前不消费 legacy target 文本；
    // 这里保留一个稳定自然音占位值，避免旧接口在迁移完成前失去初始化基线。
    targetPitchClass = .c
    generatedQuarterNoteSequence = nil
}

func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    using generator: inout R
) -> PositionPromptSession {
    requirePositionPromptMode()
    return Self.makePositionPromptSession(
        configuration: configuration,
        excluding: nil,
        using: &generator
    )
}

mutating func handlePositionPromptAnswer<R: RandomNumberGenerator>(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    session: inout PositionPromptSession,
    using generator: inout R
) -> PositionPromptAnswerResult {
    requirePositionPromptMode()
    validatePositionPromptSession(
        session,
        configuration: configuration
    )

    let promptCell = session.promptCell
    let expectedPitchClass = session.promptPitchClass
    let isCorrect = pitchClass == expectedPitchClass

    let nextSession: PositionPromptSession
    if isCorrect {
        nextSession = Self.makePositionPromptSession(
            configuration: configuration,
            excluding: promptCell,
            using: &generator
        )
        session = nextSession
    } else {
        nextSession = session
    }

    return .evaluated(
        PositionPromptEvaluation(
            promptCell: promptCell,
            expectedPitchClass: expectedPitchClass,
            answeredPitchClass: pitchClass,
            nextPromptCell: nextSession.promptCell,
            nextPromptPitchClass: nextSession.promptPitchClass
        )
    )
}
```

## 修改 4：新增 position prompt 的候选位置生成与 session 校验 helper

### 修改前

- trainer 内部只有 `randomNaturalPitchClass(...)`
- 没有“从当前配置枚举所有自然音位置”的 shared helper
- 也没有专门校验 `PositionPromptSession.promptCell` 与 `promptPitchClass` 一致性的 precondition

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: randomNaturalPitchClass, validateSingleCoverageSession
// 功能说明: 修改前 trainer 只支持随机自然音名与 single coverage session 校验，
// 还没有位置题的 candidate cell 枚举和 session 对齐校验。
private static func randomNaturalPitchClass<R: RandomNumberGenerator>(
    excluding excludedPitchClass: PitchClass? = nil,
    using generator: inout R
) -> PitchClass { ... }

private func validateSingleCoverageSession(
    _ session: SingleCoverageSession,
    configuration: FretboardConfiguration,
    _ function: StaticString = #function
) { ... }
```

### 修改后

- 新增 `positionPromptCandidateCells(in:)`
- 新增 `makePositionPromptSession(configuration:excluding:using:)`
- 新增 `requirePositionPromptMode(...)`
- 新增 `validatePositionPromptSession(...)`
- 候选题库只收集“当前指板配置里能解析为自然音的 cell”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:excluding:using:),
// positionPromptCandidateCells(in:), requirePositionPromptMode, validatePositionPromptSession
// 功能说明: 修改后 trainer 可以在 shared 层稳定枚举当前配置下的自然音位置，
// 并确保 positionPrompt session 中保存的位置与音名始终和 configuration 对齐。
private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    excluding excludedCell: FretboardCell?,
    using generator: inout R
) -> PositionPromptSession {
    let candidates = positionPromptCandidateCells(in: configuration)
    let filteredCandidates = candidates.filter { cell in
        cell != excludedCell
    }
    let resolvedCandidates = filteredCandidates.isEmpty
        ? candidates
        : filteredCandidates

    guard let promptCell = resolvedCandidates.randomElement(using: &generator) else {
        preconditionFailure("Position prompt candidates should never be empty.")
    }
    guard let promptPitchClass = configuration.pitchClass(for: promptCell) else {
        preconditionFailure("Position prompt candidate cell must resolve to a pitch class.")
    }

    return PositionPromptSession(
        promptCell: promptCell,
        promptPitchClass: promptPitchClass
    )
}

private static func positionPromptCandidateCells(
    in configuration: FretboardConfiguration
) -> [FretboardCell] {
    var cells: [FretboardCell] = []

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            let cell = FretboardCell(stringIndex: stringIndex, fret: fret)
            guard let pitchClass = configuration.pitchClass(for: cell),
                  pitchClass.isNatural else {
                continue
            }
            cells.append(cell)
        }
    }

    return cells
}

private func requirePositionPromptMode(
    _ function: StaticString = #function
) {
    guard case .positionPrompt = mode else {
        preconditionFailure("\\(function) requires .positionPrompt mode.")
    }
}

private func validatePositionPromptSession(
    _ session: PositionPromptSession,
    configuration: FretboardConfiguration,
    _ function: StaticString = #function
) {
    precondition(session.promptPitchClass.isNatural)
    guard let resolvedPromptPitchClass = configuration.pitchClass(for: session.promptCell) else {
        preconditionFailure("\\(function) position prompt session cell must resolve to a pitch class.")
    }
    precondition(resolvedPromptPitchClass == session.promptPitchClass)
}
```

## 修改 5：在 `FretboardValidation.swift` 中新增 position prompt 自动化验证

### 修改前

- validation runner 会依次调用：
- `validateNaturalNoteTrainer(...)`
- `validateSingleCoverageTrainer(...)`
- `validateQuarterNoteSequenceTrainer(...)`
- 还没有 position prompt 的 fixture 级自动校验

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: FretboardValidationRunner.validate(_:)
// 功能说明: 修改前 validation 只覆盖 legacy single、single coverage 和 quarter-note sequence，
// 还没有第三模式的位置题 shared 自检。
validateNaturalNoteTrainer(
    fixture: fixture,
    record: record
)
validateSingleCoverageTrainer(
    fixture: fixture,
    record: record
)
validateQuarterNoteSequenceTrainer(
    fixture: fixture,
    record: record
)
```

### 修改后

- 新增 `ZeroRandomNumberGenerator`，让候选选择在 validation 里可重复
- runner 中插入 `validatePositionPromptTrainer(...)`
- 新增 `positionPromptCandidateCells(configuration:)` 作为 validation 侧基准候选池

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: ZeroRandomNumberGenerator, FretboardValidationRunner.validate(_:),
// positionPromptCandidateCells(configuration:)
// 功能说明: 修改后 validation 能稳定重放 position prompt 的首题、错题与换题语义，
// 不再依赖系统随机数导致断言不可重复。
private struct ZeroRandomNumberGenerator: RandomNumberGenerator {
    mutating func next() -> UInt64 {
        0
    }
}

validateNaturalNoteTrainer(
    fixture: fixture,
    record: record
)
validateSingleCoverageTrainer(
    fixture: fixture,
    record: record
)
validatePositionPromptTrainer(
    fixture: fixture,
    record: record
)
validateQuarterNoteSequenceTrainer(
    fixture: fixture,
    record: record
)

static func positionPromptCandidateCells(
    configuration: FretboardConfiguration
) -> [FretboardCell] {
    var cells: [FretboardCell] = []
    // ... 省略循环细节，逻辑与 trainer 内部 helper 对齐：
    // 只收集 configuration 下能解析为自然音的 cell。
    return cells
}
```

## 修改 6：validation 固定了“只抽自然音位置、错不推进、对才推进”的三条语义

### 修改前

- shared validation 没有任何针对 position prompt 的断言
- 新模式就算后续接上 UI，也无法自动证明题库和推进逻辑是否正确

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateSingleCoverageTrainer, validateQuarterNoteSequenceTrainer
// 功能说明: 修改前 validation 只验证旧模式；
// 第三模式的位置题在 shared 层没有自动化语义兜底。
static func validateSingleCoverageTrainer(...) { ... }

static func validateQuarterNoteSequenceTrainer(...) { ... }
```

### 修改后

- 新增 `validatePositionPromptTrainer(...)`
- 重点覆盖：
- 新建 session 的首题是否来自自然音候选池
- 错误按钮输入后 session 是否保持不变
- 正确按钮输入后是否切换到排除当前题后的下一题

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改后 validation 会自动验证位置题的 shared 语义：
// 初始候选为自然音、错不推进、对才推进，并且新题会避开当前 promptCell。
static func validatePositionPromptTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    let candidateCells = positionPromptCandidateCells(
        configuration: configuration
    )
    let firstCandidateCell = candidateCells[0]
    let secondCandidateCell = candidateCells[1]

    var initialGenerator = ZeroRandomNumberGenerator()
    let initialTrainer = FretboardNaturalNoteTrainerState(
        positionPromptMode: ()
    )
    let initialSession = initialTrainer.makePositionPromptSession(
        configuration: configuration,
        using: &initialGenerator
    )

    var wrongGenerator = ZeroRandomNumberGenerator()
    var wrongTrainer = FretboardNaturalNoteTrainerState(
        positionPromptMode: ()
    )
    var wrongSession = wrongTrainer.makePositionPromptSession(
        configuration: configuration,
        using: &wrongGenerator
    )
    let wrongSessionSnapshot = wrongSession
    switch wrongTrainer.handlePositionPromptAnswer(
        wrongAnswer,
        configuration: configuration,
        session: &wrongSession,
        using: &wrongGenerator
    ) {
    case let .evaluated(evaluation):
        // 错误作答后 nextPromptCell / nextPromptPitchClass 都不应改变
        if evaluation.didAdvancePrompt { ... }
    }
    if wrongSession != wrongSessionSnapshot { ... }

    var correctGenerator = ZeroRandomNumberGenerator()
    var correctTrainer = FretboardNaturalNoteTrainerState(
        positionPromptMode: ()
    )
    var correctSession = correctTrainer.makePositionPromptSession(
        configuration: configuration,
        using: &correctGenerator
    )
    switch correctTrainer.handlePositionPromptAnswer(
        correctSession.promptPitchClass,
        configuration: configuration,
        session: &correctSession,
        using: &correctGenerator
    ) {
    case let .evaluated(evaluation):
        // 正确作答后应推进到排除当前题后的下一题
        if evaluation.nextPromptCell != secondCandidateCell { ... }
    }
}
```

## 修改 7：iOS / macOS 控制器补齐新 `mode` 的安全分支

### 修改前

- 控制器里凡是 `switch fretboardTrainerState.mode` 的地方，只处理 `.singleNaturalTarget` 和 `.quarterNoteSequence`
- shared trainer 一旦新增 `.positionPrompt`，平台层的 exhaustive switch 就会失配

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.handleFretboardTrainerHitResult(_:),
// iOSViewController.synchronizeQuarterNoteSequencePresentation(reason:)
// 功能说明: 修改前 iOS 控制器只认识 singleNaturalTarget 和 quarterNoteSequence。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        handleSingleNaturalTargetHitResult(hitResult)
    case .quarterNoteSequence:
        handleQuarterNoteSequenceHitResult(hitResult)
    }
}

let requiresNewSequence: Bool
switch fretboardTrainerState.mode {
case .singleNaturalTarget:
    requiresNewSequence = true
case let .quarterNoteSequence(currentSpec):
    requiresNewSequence = currentSpec != configuredQuarterNoteSequenceSpec
        || currentGeneratedQuarterNoteSequence == nil
}
```

### 修改后

- iOS/macOS 都补了 `.positionPrompt`
- 当前阶段仍然不让该模式响应指板点击，避免在按钮接线前误走旧路径
- sequence 同步时，如果当前 shared trainer 已经处于 `.positionPrompt`，也会像从 `.singleNaturalTarget` 切换过来一样强制重建 sequence

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.handleFretboardTrainerHitResult(_:),
// iOSViewController.synchronizeQuarterNoteSequencePresentation(reason:)
// 功能说明: 修改后 iOS 控制器能安全容纳 shared 的第三模式；
// 在阶段 2 仍保持“positionPrompt 不响应指板点击、切 sequence 时强制重建”的占位行为。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        handleSingleNaturalTargetHitResult(hitResult)
    case .positionPrompt:
        return
    case .quarterNoteSequence:
        handleQuarterNoteSequenceHitResult(hitResult)
    }
}

let requiresNewSequence: Bool
switch fretboardTrainerState.mode {
case .singleNaturalTarget:
    requiresNewSequence = true
case .positionPrompt:
    requiresNewSequence = true
case let .quarterNoteSequence(currentSpec):
    requiresNewSequence = currentSpec != configuredQuarterNoteSequenceSpec
        || currentGeneratedQuarterNoteSequence == nil
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.handleFretboardTrainerHitResult(_:),
// macOSViewController.synchronizeQuarterNoteSequencePresentation(reason:)
// 功能说明: 修改后 macOS 控制器与 iOS 保持同构，
// 新增 mode 后不会因为 exhaustive switch 漏分支而打断平台编译。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        handleSingleNaturalTargetHitResult(hitResult)
    case .positionPrompt:
        return
    case .quarterNoteSequence:
        handleQuarterNoteSequenceHitResult(hitResult)
    }
}

let requiresNewSequence: Bool
switch fretboardTrainerState.mode {
case .singleNaturalTarget:
    requiresNewSequence = true
case .positionPrompt:
    requiresNewSequence = true
case let .quarterNoteSequence(currentSpec):
    requiresNewSequence = currentSpec != configuredQuarterNoteSequenceSpec
        || currentGeneratedQuarterNoteSequence == nil
}
```

## 当前阶段边界

- 已完成：`positionPrompt` 的 shared mode、session/evaluation/result、随机位置出题、按钮音名判题、shared validation 覆盖
- 仍未完成：白圈/红闪/绿停留 overlay、页面“上指板下按钮”布局切换、自然音按钮事件接线、正确后 1 秒跳题的控制器时序
- 当前 iOS/macOS 控制器里对 `.positionPrompt` 仍是安全占位分支，不代表最终交互已接通

## 补充说明

- 本次改动后，`ReadLints` 未报 IDE 诊断错误
- 尝试使用 `xcodebuild -list -project "NoteMaster_Ver_1.xcodeproj"` 做工程级确认时，系统返回：
- `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`
- 因此本阶段只能确认代码层与 IDE lints 层面无明显错误，尚未完成 Xcode build 验证


# 20260328_172307_phase2_single_coverage_session_and_validation

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_172307`
- 记录范围：实施 `single覆盖反馈` 计划的阶段 2，只补 shared 的 single coverage 状态机与 validation，不涉及 prompt 进度、红绿 overlay、iOS/macOS 控制器接线
- 本次目标：把 single 从“只有一次命中结果的 legacy 判题”扩展成可复用的 coverage session 语义，为后续 UI 投影提供 shared 真相源
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 根因结论

- 阶段 1 虽然已经补齐了 `PitchClass -> [FretboardCell]` 的共享枚举能力，但 single trainer 仍然只有“单次命中结果”这套 legacy 语义。
- 当前 `FretboardNaturalNoteTrainerState.handle(...)` 会在首次正确命中时立即 `advanceToNextTarget(...)`，这使得“点对一次”和“覆盖完整题目”被绑在同一个 API 里。
- 如果直接在控制器里叠 coverage 计数，shared 真相源会分裂，后续 prompt 和 overlay 也没有统一的状态输入。
- 因此阶段 2 的根因级修复不是改控制器，而是在 shared 层正式引入 `SingleCoverageSession / Evaluation / Result`，把 single 升级成可测试的 coverage 状态机。

## 修改 1：在 `FretboardNaturalNoteTrainer.swift` 中新增 single coverage 专用类型

### 修改前

- `FretboardNaturalNoteTrainerState` 里只有 legacy `Evaluation` / `EventResult`
- `EventResult` 之后直接进入 quarter-note sequence 相关类型定义
- shared 层还没有 single coverage 的 `session / hitKind / evaluation` 值类型

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: FretboardNaturalNoteTrainerState.EventResult, FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
// 功能说明: 修改前 trainer 只有 legacy single 判题结果；
// EventResult 之后直接进入 sequence 模型，没有 single coverage session 的 shared 真相源。
enum EventResult: Equatable, Sendable {
    case ignored(IgnoreReason)
    case evaluated(Evaluation)
}

struct QuarterNoteSequenceSpec: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool
}
```

### 修改后

- 新增 `SingleCoverageIgnoreReason`
- 新增 `SingleCoverageHitKind`
- 新增 `SingleCoverageSession`
- 新增 `SingleCoverageEvaluation`
- 新增 `SingleCoverageAnswerResult`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: SingleCoverageIgnoreReason, SingleCoverageHitKind, SingleCoverageSession, SingleCoverageEvaluation, SingleCoverageAnswerResult
// 功能说明: 修改后 single trainer 拥有独立的 coverage 语义，
// 可以表达忽略原因、单次命中类型、已访问集合、总进度和是否完成覆盖。
enum SingleCoverageIgnoreReason: Equatable, Sendable {
    case nonEndedPhase(FretboardEventPhase)
    case missingHitCell
    case unresolvedHitPitch(FretboardCell)
    case completedSession
}

enum SingleCoverageHitKind: Equatable, Sendable {
    case correctNew
    case correctRepeat
    case wrong

    var isCorrect: Bool { ... }
    var didIncreaseCoverage: Bool { ... }
    var debugName: String { ... }
}

struct SingleCoverageSession: Equatable, Sendable {
    var targetPitchClass: PitchClass
    var requiredCells: Set<FretboardCell>
    var visitedCells: Set<FretboardCell>

    var totalCount: Int { requiredCells.count }
    var visitedCount: Int { visitedCells.count }
    var remainingCount: Int { max(totalCount - visitedCount, 0) }
    var remainingCells: Set<FretboardCell> {
        requiredCells.subtracting(visitedCells)
    }
    var isCompleted: Bool { remainingCells.isEmpty }
}

struct SingleCoverageEvaluation: Equatable, Sendable {
    var targetPitchClass: PitchClass
    var selectedCell: FretboardCell
    var selectedPitch: NotePitch
    var hitKind: SingleCoverageHitKind
    var visitedCount: Int
    var totalCount: Int
    var nextTargetPitchClass: PitchClass

    var isCorrect: Bool { hitKind.isCorrect }
    var didIncreaseCoverage: Bool { hitKind.didIncreaseCoverage }
    var remainingCount: Int { max(totalCount - visitedCount, 0) }
    var isCoverageCompleted: Bool { visitedCount >= totalCount }
    var didAdvanceTarget: Bool { nextTargetPitchClass != targetPitchClass }
}

enum SingleCoverageAnswerResult: Equatable, Sendable {
    case ignored(SingleCoverageIgnoreReason)
    case evaluated(SingleCoverageEvaluation)
}
```

## 修改 2：在 trainer 中新增 dedicated single coverage API，保留 legacy `handle(...)`

### 修改前

- single 只有 legacy `handle(hitResult:configuration:using:)`
- 正确命中时会直接切题，没有 session
- `makeQuarterNoteSequenceSession()` 之后就进入 sequence answer handler，single 没有独立入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makeQuarterNoteSequenceSession(), handle(hitResult:configuration:using:)
// 功能说明: 修改前 single 仍复用 legacy handle；
// 一次正确命中就会直接 advanceToNextTarget，无法表达 partial coverage 或 repeat hit。
func makeQuarterNoteSequenceSession() -> QuarterNoteSequenceSession {
    QuarterNoteSequenceSession(
        generatedSequence: requireCurrentQuarterNoteSequence()
    )
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

    guard let selectedCell = hitResult.cell else {
        return .ignored(.missingHitCell)
    }

    guard let selectedPitch = configuration.notePitch(for: selectedCell) else {
        return .ignored(.unresolvedHitPitch(selectedCell))
    }

    let answeredTargetPitchClass = targetPitchClass
    let isCorrect = selectedPitch.pitchClass == answeredTargetPitchClass
    let nextTargetPitchClass: PitchClass
    if isCorrect {
        nextTargetPitchClass = advanceToNextTarget(using: &generator)
    } else {
        nextTargetPitchClass = answeredTargetPitchClass
    }

    return .evaluated(
        Evaluation(
            targetPitchClass: answeredTargetPitchClass,
            selectedCell: selectedCell,
            selectedPitch: selectedPitch,
            isCorrect: isCorrect,
            nextTargetPitchClass: nextTargetPitchClass
        )
    )
}
```

### 修改后

- 新增 `makeSingleCoverageSession(configuration:)`
- 新增 `handleSingleCoverageHit(...)`
- 新增 `validateSingleCoverageSession(...)`
- legacy `handle(...)` 保留不动，因此阶段 2 只增加新 API，不改变现有控制器行为

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makeSingleCoverageSession(configuration:), handleSingleCoverageHit(...), validateSingleCoverageSession(...)
// 功能说明: 修改后 trainer 为 single coverage 提供 dedicated API；
// 正确新命中会增加 visitedCells，重复命中不重复计数，只有最后一个目标格命中后才推进目标音。
func makeSingleCoverageSession(
    configuration: FretboardConfiguration
) -> SingleCoverageSession {
    requireSingleNaturalTargetMode()
    return SingleCoverageSession(
        targetPitchClass: targetPitchClass,
        requiredCells: Set(configuration.cells(for: targetPitchClass))
    )
}

mutating func handleSingleCoverageHit<R: RandomNumberGenerator>(
    _ hitResult: FretboardHitResult,
    configuration: FretboardConfiguration,
    session: inout SingleCoverageSession,
    using generator: inout R
) -> SingleCoverageAnswerResult {
    requireSingleNaturalTargetMode()
    guard !session.isCompleted else {
        return .ignored(.completedSession)
    }

    validateSingleCoverageSession(
        session,
        configuration: configuration
    )

    guard hitResult.phase == .ended else {
        return .ignored(.nonEndedPhase(hitResult.phase))
    }

    guard let selectedCell = hitResult.cell else {
        return .ignored(.missingHitCell)
    }

    guard let selectedPitch = configuration.notePitch(for: selectedCell) else {
        return .ignored(.unresolvedHitPitch(selectedCell))
    }

    let answeredTargetPitchClass = targetPitchClass
    let hitKind: SingleCoverageHitKind
    if selectedPitch.pitchClass == answeredTargetPitchClass {
        if session.visitedCells.contains(selectedCell) {
            hitKind = .correctRepeat
        } else {
            session.visitedCells.insert(selectedCell)
            hitKind = .correctNew
        }
    } else {
        hitKind = .wrong
    }

    let nextTargetPitchClass: PitchClass
    if session.isCompleted {
        nextTargetPitchClass = advanceToNextTarget(using: &generator)
    } else {
        nextTargetPitchClass = answeredTargetPitchClass
    }

    return .evaluated(
        SingleCoverageEvaluation(
            targetPitchClass: answeredTargetPitchClass,
            selectedCell: selectedCell,
            selectedPitch: selectedPitch,
            hitKind: hitKind,
            visitedCount: session.visitedCount,
            totalCount: session.totalCount,
            nextTargetPitchClass: nextTargetPitchClass
        )
    )
}

private func validateSingleCoverageSession(
    _ session: SingleCoverageSession,
    configuration: FretboardConfiguration,
    _ function: StaticString = #function
) {
    precondition(
        session.targetPitchClass == targetPitchClass,
        "\(function) single coverage session target must match the trainer target."
    )
    let expectedRequiredCells = Set(
        configuration.cells(for: targetPitchClass)
    )
    precondition(
        session.requiredCells == expectedRequiredCells,
        "\(function) single coverage session required cells must match the current configuration."
    )
}
```

## 修改 3：在 `FretboardValidation.swift` 中接入 single coverage 专项回归

### 修改前

- validation 主链路只覆盖：
- `validateNaturalNoteTrainer(...)`
- `validateQuarterNoteSequenceTrainer(...)`
- 还没有 dedicated single coverage 回归函数

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: FretboardValidationRunner.validate(_:)
// 功能说明: 修改前 validation 主链路只检查 legacy single trainer 和 sequence trainer；
// single coverage 的 partial / repeat / completed 语义还没有接入回归。
validatePitchClassCellEnumeration(
    fixture: fixture,
    record: record
)
validateNaturalNoteTrainer(
    fixture: fixture,
    record: record
)
validateQuarterNoteSequenceTrainer(
    fixture: fixture,
    record: record
)
```

### 修改后

- 主链路新增 `validateSingleCoverageTrainer(...)`
- 让阶段 2 新增的 coverage 状态机在 shared validation 层立即得到回归保护

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: FretboardValidationRunner.validate(_:)
// 功能说明: 修改后 validation 在 legacy single 之后、sequence 之前
// 插入 single coverage 专项回归，锁定 session 和 answer result 的 shared 语义。
validatePitchClassCellEnumeration(
    fixture: fixture,
    record: record
)
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

## 修改 4：新增 `validateSingleCoverageTrainer(...)`，锁定 partial / repeat / completed 语义

### 修改前

- `FretboardValidation.swift` 中没有 `validateSingleCoverageTrainer(...)`
- 因而 shared 层无法自动验证：
- session 初始化是否对齐 `configuration.cells(for:)`
- 错误命中是否保持 coverage 不变
- 首次正确命中是否只增加 coverage 而不切题
- 重复命中是否返回 `.correctRepeat`
- 全部目标格完成后是否才推进

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateNaturalNoteTrainer(...)
// 功能说明: 修改前只有 legacy single 回归；
// 它验证的是“一次正确命中即切题”，并不覆盖 single coverage 的 session 语义。
var correctTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
switch correctTrainer.handle(
    hitResult: makeHitResult(
        phase: .ended,
        cell: correctCell
    ),
    configuration: configuration
) {
case let .evaluated(evaluation):
    if !evaluation.didAdvanceTarget {
        record("trainer 在答对后应把 didAdvanceTarget 标记为 true。")
    }
    if evaluation.nextTargetPitchClass == .c {
        record("trainer 在答对后未切换到新的目标音。")
    }
default:
    record("trainer 对正确命中未返回 evaluated 结果。")
}
```

### 修改后

- 新增 `validateSingleCoverageTrainer(...)`
- 验证范围包括：
- session 初始化
- non-ended / missing / unresolved ignore
- wrong hit
- `correctNew`
- `correctRepeat`
- 全部命中后的完成态与 `completedSession`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateSingleCoverageTrainer(...)
// 功能说明: 修改后新增 single coverage 专项 validation；
// 它显式锁定 partial coverage、repeat hit 和 completed session 的边界行为。
static func validateSingleCoverageTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    guard fixture.name == "horizontal-guitar6-reference" else {
        return
    }

    let configuration = fixture.configuration
    let correctCells = configuration.cells(for: .c)
    // ... 省略 session 初始化断言 ...

    var wrongTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
    var wrongSession = wrongTrainer.makeSingleCoverageSession(
        configuration: configuration
    )
    switch wrongTrainer.handleSingleCoverageHit(
        makeHitResult(
            phase: .ended,
            cell: wrongCell
        ),
        configuration: configuration,
        session: &wrongSession
    ) {
    case let .evaluated(evaluation):
        if evaluation.hitKind != .wrong {
            record("single coverage trainer 错误命中时 hitKind 应为 .wrong。")
        }
        if evaluation.didIncreaseCoverage {
            record("single coverage trainer 错误命中后不应增加 coverage。")
        }
        if evaluation.didAdvanceTarget {
            record("single coverage trainer 错误命中后不应推进目标音。")
        }
    default:
        record("single coverage trainer 对错误命中未返回 evaluated 结果。")
    }

    var partialTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
    var partialSession = partialTrainer.makeSingleCoverageSession(
        configuration: configuration
    )
    switch partialTrainer.handleSingleCoverageHit(
        makeHitResult(
            phase: .ended,
            cell: firstCorrectCell
        ),
        configuration: configuration,
        session: &partialSession
    ) {
    case let .evaluated(evaluation):
        if evaluation.hitKind != .correctNew {
            record("single coverage trainer 首次正确命中时 hitKind 应为 .correctNew。")
        }
        if evaluation.didAdvanceTarget {
            record("single coverage trainer 在未覆盖完全部位置前不应推进目标音。")
        }
    default:
        record("single coverage trainer 对首次正确命中未返回 evaluated 结果。")
    }

    switch partialTrainer.handleSingleCoverageHit(
        makeHitResult(
            phase: .ended,
            cell: firstCorrectCell
        ),
        configuration: configuration,
        session: &partialSession
    ) {
    case let .evaluated(evaluation):
        if evaluation.hitKind != .correctRepeat {
            record("single coverage trainer 重复命中已完成 cell 时 hitKind 应为 .correctRepeat。")
        }
        if evaluation.didIncreaseCoverage {
            record("single coverage trainer 重复命中已完成 cell 不应增加 coverage。")
        }
    default:
        record("single coverage trainer 对重复命中未返回 evaluated 结果。")
    }

    // ... 省略中间若干完整覆盖流程断言 ...
    if completedTrainer.handleSingleCoverageHit(
        makeHitResult(
            phase: .ended,
            cell: lastCorrectCell
        ),
        configuration: configuration,
        session: &completedSession
    ) != .ignored(.completedSession) {
        record("single coverage trainer 在 completed session 上继续命中应返回 ignored(.completedSession)。")
    }
}
```

## 影响范围与未改内容

- 本次只新增 single coverage 的 shared API，没有修改现有 `handle(hitResult:configuration:)` 的 legacy 语义。
- `FretboardNaturalNoteTrainerState.handle(...)` 仍然保留“一次正确命中即推进”的旧行为，供当前控制器继续使用。
- `TargetPromptContent` 还没有 coverage 进度表达。
- `FretboardLayer` 还没有红/绿反馈 overlay。
- `iOSViewController.swift` / `macOSViewController.swift` 还没有接入 `makeSingleCoverageSession(...)` 和 `handleSingleCoverageHit(...)`。

## 验证情况

- 已执行 `ReadLints` 检查，`FretboardNaturalNoteTrainer.swift` 与 `FretboardValidation.swift` 没有新增 linter 问题。
- 已通过 `git diff` 核对本次实际改动，只涉及上述两个 shared 文件。
- 本次没有执行工程级编译；当前会话中可用的直接验证仍以 `ReadLints` 和 shared validation 代码回读为主。

## 阶段结论

- 阶段 2 已完成：shared 层已经具备 single coverage 的正式状态机与专项回归断言。
- 后续阶段 3/4/5 只需要围绕这套 shared 真相源，继续接入 prompt 进度、红绿 overlay 与双端控制器投影。

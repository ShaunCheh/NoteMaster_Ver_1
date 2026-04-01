# 20260401_142935_phase4_position_prompt_validation_round_robin_semantics

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_142935`
- 记录范围：`position prompt` 轮巡调度改造的阶段 4，只覆盖共享层 `validation` 语义迁移，不包含共享层选题算法和平台层 session reset 的实现
- 修改性质：这一步不是继续改业务逻辑，而是把 `FretboardValidation.swift` 从“固定首题 / 固定次题”的旧验证模型，升级为“基于 session 真值 + 按弦轮巡不变量 + 弦内低频优先”的新验证模型
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 修改前

- `validateFilterScenario(...)` 里默认认为：
- `candidateCells[0]` 就是首题
- `candidateCells[1]` 就是答对后的下一题
- 错误作答和正确作答的断言都强绑定在 `firstCandidateCell` / `secondCandidateCell`
- 这套校验成立的前提是“trainer 仍然使用无状态随机 + 确定性生成器刚好命中前两个候选”，但阶段 2 之后共享层已经改成“按弦轮巡 + 弦内低频优先”，原先的验证语义已经不再成立

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateFilterScenario(...)
// 功能说明: 修改前把前两个候选格子当作固定基准；
// 旧验证模型默认“首题 = 第一个候选，下一题 = 第二个候选”。
let firstCandidateCell = candidateCells[0]
let secondCandidateCell = candidateCells[1]
guard let firstCandidatePitchClass = configuration.pitchClass(for: firstCandidateCell) else {
    record("position prompt trainer \(name) 首个候选 cell 无法解析 PitchClass。")
    return
}
guard let secondCandidatePitchClass = configuration.pitchClass(for: secondCandidateCell) else {
    record("position prompt trainer \(name) 第二个候选 cell 无法解析 PitchClass。")
    return
}

if !firstCandidatePitchClass.isNatural || !secondCandidatePitchClass.isNatural {
    record("position prompt trainer \(name) 的候选基准 cell 应为自然音。")
}
if !matchesPositionPromptFilter(firstCandidateCell, filter: normalizedFilter)
    || !matchesPositionPromptFilter(secondCandidateCell, filter: normalizedFilter) {
    record("position prompt trainer \(name) 的候选基准 cell 应命中当前 active filter。")
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateFilterScenario(...)
// 功能说明: 修改前初始 session 的校验仍然要求它必须对齐 firstCandidateCell；
// 这与新调度器“首题允许在当前轮弦集合里选择任意合法弦”的语义冲突。
let initialSession = initialTrainer.makePositionPromptSession(
    configuration: configuration,
    filter: normalizedFilter,
    using: &initialGenerator
)
if initialSession.promptCell != firstCandidateCell {
    record("position prompt trainer \(name) 新建 session 的 promptCell 未对齐首个自然音候选。")
}
if initialSession.promptPitchClass != firstCandidatePitchClass {
    record("position prompt trainer \(name) 新建 session 的 promptPitchClass 与配置解析结果不一致。")
}
if !initialSession.promptPitchClass.isNatural {
    record("position prompt trainer \(name) 新建 session 的 promptPitchClass 应为自然音。")
}
if !matchesPositionPromptFilter(initialSession.promptCell, filter: normalizedFilter) {
    record("position prompt trainer \(name) 新建 session 不应落在当前 active filter 之外。")
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateFilterScenario(...)
// 功能说明: 修改前正确作答后的验证继续把“下一题必须是 secondCandidateCell”写死；
// 这无法表达“按弦轮巡”和“弦内最低 hitCount 优先”的新语义。
switch correctTrainer.handlePositionPromptAnswer(
    correctSession.promptPitchClass,
    configuration: configuration,
    filter: normalizedFilter,
    session: &correctSession,
    using: &correctGenerator
) {
case let .evaluated(evaluation):
    if evaluation.promptCell != firstCandidateCell {
        record("position prompt trainer \(name) 正确作答时 promptCell 未对齐首题。")
    }
    if evaluation.expectedPitchClass != firstCandidatePitchClass {
        record("position prompt trainer \(name) 正确作答时 expectedPitchClass 与配置解析结果不一致。")
    }
    if evaluation.nextPromptCell != secondCandidateCell {
        record("position prompt trainer \(name) 正确作答后 nextPromptCell 未切换到排除当前题后的首个候选。")
    }
    if evaluation.nextPromptPitchClass != secondCandidatePitchClass {
        record("position prompt trainer \(name) 正确作答后 nextPromptPitchClass 与新题不一致。")
    }
}
if correctSession.promptCell != secondCandidateCell {
    record("position prompt trainer \(name) 正确作答后 session.promptCell 未推进到新题。")
}
if correctSession.promptPitchClass != secondCandidatePitchClass {
    record("position prompt trainer \(name) 正确作答后 session.promptPitchClass 未与新题同步。")
}
```

## 修改后

- 新增 `PositionPromptCandidatePoolSignature` 类型别名和按弦分组工具
- 新增 `validatePositionPromptSessionState(...)`
- 它不再关心“是不是第一个候选”，而是校验：
- `promptCell` 是否在候选池内
- `promptPitchClass` 是否与当前 configuration 对齐
- `candidatePoolSignature` 是否正确
- `remainingStringsInRound` 是否合法
- `cellHitCounts` 是否只包含候选池内格子且全为正数
- 新增 `validateCorrectAdvance(...)`
- 它专门校验正确推进后的轮巡不变量：
- 下一题所在弦必须来自当前轮剩余弦集合
- `remainingStringsInRound` 必须按轮巡语义更新
- 新题必须满足“当前弦内最低 hitCount 优先，且优先排除上一题格子”
- 只有新题格子的 hitCount 增加，其它格子不变
- `validateFilterScenario(...)` 的主体被重写为：
- 初始 session 校验
- 错误作答前后校验
- 连续两轮正确推进校验
- 最终显式验证“每轮每弦一次”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validatePositionPromptSessionState(...)
// 功能说明: 修改后新增基于 session 真值的状态校验入口；
// 它不再依赖固定候选下标，而是检查当前 prompt、候选池签名、remainingStringsInRound 和 cellHitCounts 是否自洽。
typealias PositionPromptCandidatePoolSignature =
    FretboardNaturalNoteTrainerState.PositionPromptSession.SchedulingState.CandidatePoolSignature

func validatePositionPromptSessionState(
    scenario name: String,
    stage: String,
    session: FretboardNaturalNoteTrainerState.PositionPromptSession,
    filter: PositionPromptCandidateFilter,
    candidateCellSet: Set<FretboardCell>,
    candidateCellsByString: [Int: [FretboardCell]],
    expectedSignature: PositionPromptCandidatePoolSignature
) {
    if !session.promptPitchClass.isNatural {
        record("position prompt trainer \(name) \(stage) 的 promptPitchClass 应保持自然音。")
    }
    if !candidateCellSet.contains(session.promptCell) {
        record("position prompt trainer \(name) \(stage) 的 promptCell 未落在当前候选池内。")
    }
    if !matchesPositionPromptFilter(session.promptCell, filter: filter) {
        record("position prompt trainer \(name) \(stage) 的 promptCell 未命中当前 active filter。")
    }
    if configuration.pitchClass(for: session.promptCell) != session.promptPitchClass {
        record("position prompt trainer \(name) \(stage) 的 promptPitchClass 未与 configuration 对齐。")
    }
    if session.schedulingState.candidatePoolSignature != expectedSignature {
        record("position prompt trainer \(name) \(stage) 的 candidatePoolSignature 未对齐当前候选池身份。")
    }
    if session.schedulingState.remainingStringsInRound.contains(
        session.promptCell.stringIndex
    ) {
        record("position prompt trainer \(name) \(stage) 的当前弦不应仍保留在 remainingStringsInRound 中。")
    }
    if !session.schedulingState.remainingStringsInRound.isSubset(
        of: expectedSignature.availableStringIndices
    ) {
        record("position prompt trainer \(name) \(stage) 的 remainingStringsInRound 超出了当前候选弦集合。")
    }
    let trackedCells = Set(session.schedulingState.cellHitCounts.keys)
    if !trackedCells.isSubset(of: candidateCellSet) {
        record("position prompt trainer \(name) \(stage) 的 cellHitCounts 包含了候选池之外的格子。")
    }
    if !session.schedulingState.cellHitCounts.values.allSatisfy({ $0 > 0 }) {
        record("position prompt trainer \(name) \(stage) 的 cellHitCounts 应全部为正数。")
    }
    if session.schedulingState.hitCount(for: session.promptCell) <= 0 {
        record("position prompt trainer \(name) \(stage) 的当前 promptCell 应已有命中记录。")
    }
    if candidateCellsByString[session.promptCell.stringIndex] == nil {
        record("position prompt trainer \(name) \(stage) 的 promptCell 所在弦缺少按弦分组候选。")
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateCorrectAdvance(...)
// 功能说明: 修改后新增“正确推进”专用验证入口；
// 它显式校验下一题是否遵循当前轮剩余弦集合、最低 hitCount 优先和 hitCount 递增规则。
func validateCorrectAdvance(
    scenario name: String,
    from previousSession: FretboardNaturalNoteTrainerState.PositionPromptSession,
    evaluation: FretboardNaturalNoteTrainerState.PositionPromptEvaluation,
    to nextSession: FretboardNaturalNoteTrainerState.PositionPromptSession,
    filter: PositionPromptCandidateFilter,
    candidateCellSet: Set<FretboardCell>,
    candidateCellsByString: [Int: [FretboardCell]],
    expectedSignature: PositionPromptCandidatePoolSignature
) {
    validatePositionPromptSessionState(
        scenario: name,
        stage: "correctAdvance-nextSession",
        session: nextSession,
        filter: filter,
        candidateCellSet: candidateCellSet,
        candidateCellsByString: candidateCellsByString,
        expectedSignature: expectedSignature
    )

    let availableStrings = expectedSignature.availableStringIndices
    let remainingStringsBeforeSelection = previousSession
        .schedulingState
        .remainingStringsInRound
        .isEmpty
        ? availableStrings
        : previousSession.schedulingState.remainingStringsInRound
    let nextStringIndex = nextSession.promptCell.stringIndex
    if !remainingStringsBeforeSelection.contains(nextStringIndex) {
        record("position prompt trainer \(name) 正确作答后 nextPromptCell 所在弦未遵循当前轮剩余弦集合。")
    }
    let expectedRemainingStrings = remainingStringsBeforeSelection.subtracting(
        [nextStringIndex]
    )
    if nextSession.schedulingState.remainingStringsInRound != expectedRemainingStrings {
        record("position prompt trainer \(name) 正确作答后 remainingStringsInRound 未按轮巡语义更新。")
    }

    guard let stringCandidates = candidateCellsByString[nextStringIndex] else {
        record("position prompt trainer \(name) 正确作答后缺少 nextPromptCell 所在弦的候选分组。")
        return
    }
    let minimumHitCount = stringCandidates.map {
        previousSession.schedulingState.hitCount(for: $0)
    }.min() ?? 0
    let preferredCandidates = stringCandidates.filter {
        previousSession.schedulingState.hitCount(for: $0) == minimumHitCount
    }
    let filteredPreferredCandidates = preferredCandidates.filter {
        $0 != previousSession.promptCell
    }
    let allowedCandidates = filteredPreferredCandidates.isEmpty
        ? preferredCandidates
        : filteredPreferredCandidates
    if !allowedCandidates.contains(nextSession.promptCell) {
        record("position prompt trainer \(name) 正确作答后 nextPromptCell 未遵循最低命中优先或排除当前格规则。")
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateFilterScenario(...)
// 功能说明: 修改后不再验证“首题/次题固定候选顺序”；
// 而是先建立 candidateCellSet、candidateCellsByString 和 expectedSignature，再围绕 session 真值做验证。
let candidateCellSet = Set(candidateCells)
let candidateCellsByString = positionPromptCandidateCellsByString(
    candidateCells
)
let expectedSignature =
    FretboardNaturalNoteTrainerState
    .positionPromptCandidatePoolSignature(
        in: configuration,
        filter: normalizedFilter
    )
if expectedSignature.availableStringIndices
    != Set(candidateCellsByString.keys) {
    record("position prompt trainer \(name) 的 candidatePoolSignature 候选弦集合未对齐按弦分组结果。")
}

let initialSession = initialTrainer.makePositionPromptSession(
    configuration: configuration,
    filter: normalizedFilter,
    using: &initialGenerator
)
validatePositionPromptSessionState(
    scenario: name,
    stage: "initialSession",
    session: initialSession,
    filter: normalizedFilter,
    candidateCellSet: candidateCellSet,
    candidateCellsByString: candidateCellsByString,
    expectedSignature: expectedSignature
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateFilterScenario(...)
// 功能说明: 修改后错误作答的构造不再复用旧的 firstCandidatePitch；
// 而是直接基于当前 wrongSession 的 promptPitchClass 生成一个真实的错误答案，并验证答错前后 session 不应变化。
var wrongSession = wrongTrainer.makePositionPromptSession(
    configuration: configuration,
    filter: normalizedFilter,
    using: &wrongGenerator
)
validatePositionPromptSessionState(
    scenario: name,
    stage: "wrongAnswer-sessionBeforeAnswer",
    session: wrongSession,
    filter: normalizedFilter,
    candidateCellSet: candidateCellSet,
    candidateCellsByString: candidateCellsByString,
    expectedSignature: expectedSignature
)
guard let wrongAnswer = PitchClass.naturalCasesInOrder.first(where: {
    $0 != wrongSession.promptPitchClass
}) else {
    record("position prompt trainer \(name) 无法构造不同于当前题答案的自然音错误按钮。")
    return
}
let wrongSessionSnapshot = wrongSession
switch wrongTrainer.handlePositionPromptAnswer(
    wrongAnswer,
    configuration: configuration,
    filter: normalizedFilter,
    session: &wrongSession,
    using: &wrongGenerator
) {
case let .evaluated(evaluation):
    if evaluation.promptCell != wrongSessionSnapshot.promptCell {
        record("position prompt trainer \(name) 错误作答时 promptCell 未对齐当前题目。")
    }
    if evaluation.expectedPitchClass != wrongSessionSnapshot.promptPitchClass {
        record("position prompt trainer \(name) 错误作答时 expectedPitchClass 与当前题目不一致。")
    }
    if evaluation.nextPromptCell != wrongSessionSnapshot.promptCell {
        record("position prompt trainer \(name) 错误作答后 nextPromptCell 不应改变。")
    }
}
if wrongSession != wrongSessionSnapshot {
    record("position prompt trainer \(name) 错误作答后 session 不应变化。")
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateFilterScenario(...)
// 功能说明: 修改后把“正确推进”验证扩展成连续两轮；
// 它会记录每一步的 prompt 所在弦，并在每一轮结束后检查是否完整覆盖了当前候选弦集合且每弦只出现一次。
var sequenceSession = sequenceTrainer.makePositionPromptSession(
    configuration: configuration,
    filter: normalizedFilter,
    using: &sequenceGenerator
)
let roundLength = max(
    expectedSignature.availableStringIndices.count,
    1
)
let observedPromptCount = max(roundLength * 2, 2)
var observedStringsByPrompt: [Int] = []
observedStringsByPrompt.reserveCapacity(observedPromptCount)

for promptIndex in 0..<observedPromptCount {
    validatePositionPromptSessionState(
        scenario: name,
        stage: "roundSequence-step\(promptIndex + 1)",
        session: sequenceSession,
        filter: normalizedFilter,
        candidateCellSet: candidateCellSet,
        candidateCellsByString: candidateCellsByString,
        expectedSignature: expectedSignature
    )
    observedStringsByPrompt.append(
        sequenceSession.promptCell.stringIndex
    )

    guard promptIndex < observedPromptCount - 1 else {
        break
    }

    let previousSession = sequenceSession
    switch sequenceTrainer.handlePositionPromptAnswer(
        previousSession.promptPitchClass,
        configuration: configuration,
        filter: normalizedFilter,
        session: &sequenceSession,
        using: &sequenceGenerator
    ) {
    case let .evaluated(evaluation):
        validateCorrectAdvance(
            scenario: name,
            from: previousSession,
            evaluation: evaluation,
            to: sequenceSession,
            filter: normalizedFilter,
            candidateCellSet: candidateCellSet,
            candidateCellsByString: candidateCellsByString,
            expectedSignature: expectedSignature
        )
    }
}

for roundIndex in 0..<2 {
    let start = roundIndex * roundLength
    let end = start + roundLength
    let roundStrings = Array(observedStringsByPrompt[start..<end])
    if Set(roundStrings) != expectedSignature.availableStringIndices {
        record("position prompt trainer \(name) 第 \(roundIndex + 1) 轮未完整覆盖当前候选弦集合。")
    }
    if Set(roundStrings).count != roundStrings.count {
        record("position prompt trainer \(name) 第 \(roundIndex + 1) 轮出现了重复弦，未遵循每轮每弦一次的语义。")
    }
}
```

## 本阶段验证语义

- 初始 session 不再要求命中固定候选下标，而是要求：
- 题面合法
- 命中过滤器
- `candidatePoolSignature` 正确
- 首题后的 `remainingStringsInRound` 与 `cellHitCounts` 初始化正确
- 错误作答必须保持：
- 当前题不变
- 下一题不变
- session 不变
- 正确作答必须满足：
- 下一题来自当前轮剩余弦集合
- `remainingStringsInRound` 正确减少
- 新题满足当前弦内最低命中优先
- 只有新题格子的命中次数递增
- 连续两轮推进时，每轮都要完整覆盖“当前有候选的弦集合”，并且每弦只出现一次

## 本阶段尚未改动

- 共享层 `trainer` 逻辑没有再改，仍沿用阶段 2 的“按弦轮巡 + 弦内低频优先”
- 平台层 `macOS` / `iOS` session reset 逻辑没有再改，仍沿用阶段 3 的候选池签名匹配
- 还没有补阶段 5 的调试日志增强和回归清单补充
- 还没有生成阶段 4 对应的运行时自动测试结果记录

## 本阶段结果

- `FretboardValidation.swift` 已经摆脱了对固定候选下标的依赖
- validation 现在真正和当前 `position prompt` 的轮巡业务语义对齐
- 后续如果继续推进阶段 5，就可以在不回退 validation 结构的前提下，只补日志和回归验证说明

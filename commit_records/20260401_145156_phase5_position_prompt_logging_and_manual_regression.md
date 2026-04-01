# 20260401_145156_phase5_position_prompt_logging_and_manual_regression

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260401_145156`
- 记录范围：`position prompt` 轮巡调度改造的阶段 5，只覆盖共享层调度日志增强与 `manualChecklist` 手工回归清单升级
- 修改性质：这一步不再改动轮巡选题算法本身，而是补齐“候选池身份 / 当前轮状态 / 弦内低频优先”的可观测性，并把手工回归口径从“全部合法位置随机”升级为“按弦轮巡 + 弦内低频优先”
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 修改前

- `FretboardNaturalNoteTrainer.swift` 里已经有 `PositionPrompt` 调试日志，但信息粒度偏粗：
- `makePositionPromptSession(...)` 结束时只打印 `promptCell` 与 `pitch`
- `selectPrompt` 只打印候选总数、选中的格子和解析出的音名
- `handlePositionPromptAnswer(...)` 没有统一的“本次回答结果”日志
- `seededPositionPromptSchedulingState(...)` 即使因为候选池变化而重置，也看不到具体原因
- 这样在排查“为什么下一题落到这根弦”“为什么当前轮重置”“同弦内是否真的优先低频格子”时，控制台证据不够

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession<R: RandomNumberGenerator>(configuration:filter:using:)
// 功能说明: 修改前 session 创建结束日志只打印 filter、当前题格子和音名；
// 无法直接看到当前轮次的 remainingStringsInRound、命中统计和轮次进度。
let normalizedFilter = Self.normalizedPositionPromptFilter(filter)
let filterText = Self.positionPromptFilterDebugText(normalizedFilter)
print("[PositionPrompt][Trainer] makePositionPromptSession begin \(filterText)")
requirePositionPromptMode()

let session = Self.makePositionPromptSession(
    configuration: configuration,
    filter: normalizedFilter,
    excluding: nil,
    carryingOver: nil,
    using: &generator
)

print(
    "[PositionPrompt][Trainer] makePositionPromptSession end \(filterText) prompt=string=\(session.promptCell.stringIndex) fret=\(session.promptCell.fret) pitch=\(session.promptPitchClass.displayText())"
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: selectPositionPromptCell<R: RandomNumberGenerator>(...), seededPositionPromptSchedulingState(...)
// 功能说明: 修改前选题日志只能看到候选总数，无法看到候选池身份、当前轮活跃弦集合、
// 当前弦最低命中次数、排除上一题格子是否生效，以及调度状态为何被重置。
let candidates = positionPromptCandidateCells(
    in: configuration,
    filter: normalizedFilter
)
print(
    "[PositionPrompt][Trainer] selectPrompt candidates count=\(candidates.count)"
)

let resolvedCandidates = filteredPreferredCandidates.isEmpty
    ? preferredCandidates
    : filteredPreferredCandidates

guard let promptCell = resolvedCandidates.randomElement(using: &generator) else {
    preconditionFailure(
        "Position prompt resolved candidates should never be empty."
    )
}

guard let schedulingState,
      schedulingState.candidatePoolSignature == candidatePoolSignature else {
    return PositionPromptSession.SchedulingState(
        remainingStringsInRound: candidatePoolSignature.availableStringIndices,
        cellHitCounts: [:],
        candidatePoolSignature: candidatePoolSignature
    )
}
return schedulingState
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: handlePositionPromptAnswer<R: RandomNumberGenerator>(_:configuration:filter:session:using:)
// 功能说明: 修改前回答阶段只更新 nextSession 并返回 evaluation；
// 控制台里看不到 expected / answered / next prompt / 当前调度状态的统一摘要。
let promptCell = session.promptCell
let expectedPitchClass = session.promptPitchClass
let isCorrect = pitchClass == expectedPitchClass

let nextSession: PositionPromptSession
if isCorrect {
    nextSession = Self.makePositionPromptSession(
        configuration: configuration,
        filter: filter,
        excluding: promptCell,
        carryingOver: session.schedulingState,
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
```

- `FretboardValidation.swift` 的 `manualChecklist(for:)` 也仍停留在旧口径：
- 默认音名过滤只要求“从全部合法位置随机出题”
- `Frets` / `C,E` 场景只要求“题目落在当前过滤集合内”
- 没有手工核对“每轮每弦一次”“同弦低频优先”“控制台日志字段是否齐全”的条目

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: manualChecklist(for:)
// 功能说明: 修改前位置题回归清单仍按“过滤正确 + 合法位置随机”组织；
// 它还没有把阶段 2 到阶段 5 的轮巡调度语义落成手工验证步骤。
[
    "在 `positionPrompt` 默认 `Filter = Note Names`、默认 `C / E / F / B` 状态下连续答对多次，确认当前题与下一题都只落在这些音名，且会从当前指板全部合法位置出题（包含命中这些音名的空弦）。",
    "把 `positionPrompt` 的 `Filter` 切到 `Frets`，确认会回显当前品位集合；连续答对多次，确认当前题与下一题都只落在当前已选品位。",
    "在 `positionPrompt` 里只保留 `C / E` 这两个音名后连续答对多次，确认当前题与下一题都只落在 `C / E`，不受已保存品位集合干扰。"
]
```

## 修改后

- 为共享层新增了两组统一日志文本 helper：
- `positionPromptCandidatePoolDebugText(...)` 负责把候选池身份打平为可读文本，包含 `poolStrings`、`stringCount`、`maxFret`、`tuning`、`filter`
- `positionPromptSchedulingDebugText(...)` 负责把调度状态打平为可读文本，包含 `roundProgress`、`availableStrings`、`consumedStrings`、`remainingStrings`、`trackedCells`、`promptHits`
- 这样后续所有 `PositionPrompt` 日志都能复用同一套文本结构，避免每个打印点各自拼接字段

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: positionPromptCandidatePoolDebugText(...), positionPromptSchedulingDebugText(...)
// 功能说明: 修改后新增统一日志 helper；
// 一个负责描述候选池身份，一个负责描述当前轮巡调度快照。
private static func positionPromptCandidatePoolDebugText(
    _ signature: PositionPromptSession.SchedulingState.CandidatePoolSignature
) -> String {
    let tuningText = signature.tuning.openStringsLowToHigh.map {
        $0.displayText(showsOctave: false)
    }.joined(separator: ",")
    let filterText = positionPromptFilterDebugText(signature.filter)
    let availableStrings = positionPromptOrderedStringText(
        signature.availableStringIndices
    )
    return "poolStrings=\(availableStrings) stringCount=\(signature.tuning.stringCount) maxFret=\(signature.maxFret) tuning=\(tuningText) \(filterText)"
}

private static func positionPromptSchedulingDebugText(
    _ schedulingState: PositionPromptSession.SchedulingState,
    promptCell: FretboardCell? = nil
) -> String {
    let availableStrings =
        schedulingState.candidatePoolSignature.availableStringIndices
    let remainingStrings = schedulingState.remainingStringsInRound
    let consumedStrings = availableStrings.subtracting(remainingStrings)
    let roundProgress = "\(consumedStrings.count)/\(availableStrings.count)"
    let promptHitCountText = promptCell.map {
        String(schedulingState.hitCount(for: $0))
    } ?? "n/a"

    return "roundProgress=\(roundProgress) availableStrings=\(positionPromptOrderedStringText(availableStrings)) consumedStrings=\(positionPromptOrderedStringText(consumedStrings)) remainingStrings=\(positionPromptOrderedStringText(remainingStrings)) trackedCells=\(schedulingState.cellHitCounts.count) promptHits=\(promptHitCountText)"
}
```

- `makePositionPromptSession(...)` 的结束日志升级为“当前题 + 调度快照”
- `handlePositionPromptAnswer(...)` 新增统一回答结果日志，能直接看到 `expected / answered / current / next`
- 这样在 UI 或共享层回归时，只要看一条 `answer` 日志就能知道这次答题是否推进，以及推进后当前轮状态是否正确延续

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession<R: RandomNumberGenerator>(configuration:filter:using:)
// 功能说明: 修改后在 session 创建结束时附带当前 prompt 的调度快照，
// 便于确认新建题目已经把当前弦从 remainingStringsInRound 中消费掉。
print(
    "[PositionPrompt][Trainer] makePositionPromptSession end \(filterText) prompt=string=\(session.promptCell.stringIndex) fret=\(session.promptCell.fret) pitch=\(session.promptPitchClass.displayText()) \(Self.positionPromptSchedulingDebugText(session.schedulingState, promptCell: session.promptCell))"
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: handlePositionPromptAnswer<R: RandomNumberGenerator>(_:configuration:filter:session:using:)
// 功能说明: 修改后在返回 evaluation 之前打印统一答题结果摘要；
// wrong / correct 都能看到 expected、answered、当前题、下一题和当前调度快照。
let resultText = isCorrect ? "correct" : "wrong"
print(
    "[PositionPrompt][Trainer] answer result=\(resultText) expected=\(expectedPitchClass.displayText()) answered=\(pitchClass.displayText()) current=string=\(promptCell.stringIndex) fret=\(promptCell.fret) next=string=\(nextSession.promptCell.stringIndex) fret=\(nextSession.promptCell.fret) \(Self.positionPromptSchedulingDebugText(nextSession.schedulingState, promptCell: nextSession.promptCell))"
)
```

- `selectPrompt` 主链路补齐了阶段 5 最关键的“选题上下文”日志：
- 候选总数日志现在会附带 `candidatePoolSignature` 摘要
- `selectPositionPromptCell(...)` 会在真正随机前输出 `schedulingBefore`，包括 `activeRoundStrings`、`selectedString`、`minimumHitCount`、`minimumHitCandidateCount`、`resolvedCandidateCount`、`excludedApplied`
- 选定格子后会再输出 `schedulingAfter`
- `seededPositionPromptSchedulingState(...)` 会把状态种子的来源标记成 `newSession`、`candidatePoolChanged` 或 `reused`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession<R: RandomNumberGenerator>(configuration:filter:excluding:carryingOver:using:)
// 功能说明: 修改后在 selectPrompt 入口先打印候选池身份，
// 让控制台可以区分“候选总数相同但 filter / tuning / maxFret 不同”的场景。
let candidatePoolSignature = positionPromptCandidatePoolSignature(
    in: configuration,
    filter: normalizedFilter,
    candidateCells: candidates
)
print(
    "[PositionPrompt][Trainer] selectPrompt candidates count=\(candidates.count) \(positionPromptCandidatePoolDebugText(candidatePoolSignature))"
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: selectPositionPromptCell<R: RandomNumberGenerator>(...)
// 功能说明: 修改后在正式抽取格子前后分别打印 schedulingBefore / schedulingAfter；
// 这里会把当前轮活跃弦集合、当前弦最低命中次数以及排除上一题格子的结果一起打出来。
let excludedCellWasFiltered = filteredPreferredCandidates.count
    != preferredCandidates.count
print(
    "[PositionPrompt][Trainer] selectPrompt schedulingBefore \(positionPromptSchedulingDebugText(seedState)) activeRoundStrings=\(positionPromptOrderedStringText(activeRoundStrings)) selectedString=\(selectedStringIndex) stringCandidates=\(stringCandidates.count) minimumHitCount=\(minimumHitCount) minimumHitCandidateCount=\(preferredCandidates.count) resolvedCandidateCount=\(resolvedCandidates.count) excludedApplied=\(excludedCellWasFiltered)"
)

var nextHitCounts = seedState.cellHitCounts
nextHitCounts[promptCell, default: 0] += 1
let nextSchedulingState = PositionPromptSession.SchedulingState(
    remainingStringsInRound: activeRoundStrings.subtracting([selectedStringIndex]),
    cellHitCounts: nextHitCounts,
    candidatePoolSignature: candidatePoolSignature
)
print(
    "[PositionPrompt][Trainer] selectPrompt schedulingAfter \(positionPromptSchedulingDebugText(nextSchedulingState, promptCell: promptCell))"
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: seededPositionPromptSchedulingState(carryingOver:candidatePoolSignature:)
// 功能说明: 修改后显式记录调度状态种子的来源；
// 这能直接区分“新 session”、“候选池变化导致重置”和“沿用上一题状态”三种路径。
guard let schedulingState,
      schedulingState.candidatePoolSignature == candidatePoolSignature else {
    let resetReason = schedulingState == nil
        ? "newSession"
        : "candidatePoolChanged"
    let resetState = PositionPromptSession.SchedulingState(
        remainingStringsInRound: candidatePoolSignature.availableStringIndices,
        cellHitCounts: [:],
        candidatePoolSignature: candidatePoolSignature
    )
    print(
        "[PositionPrompt][Trainer] selectPrompt seed reason=\(resetReason) \(positionPromptCandidatePoolDebugText(candidatePoolSignature)) \(positionPromptSchedulingDebugText(resetState))"
    )
    return resetState
}

print(
    "[PositionPrompt][Trainer] selectPrompt seed reason=reused \(positionPromptCandidatePoolDebugText(candidatePoolSignature)) \(positionPromptSchedulingDebugText(schedulingState))"
)
return schedulingState
```

- `manualChecklist(for:)` 也同步迁移到了新语义：
- 默认 `Note Names` 场景要求至少观察一整轮，确认“每轮每弦一次”
- `Frets` 场景要求确认“当前候选弦每轮都被覆盖”
- `C / E` 场景要求确认“同弦内优先低频格子”
- 新增一条专门检查 `[PositionPrompt][Trainer]` 调试日志字段是否齐全、切换过滤后是否重新起轮

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: manualChecklist(for:)
// 功能说明: 修改后把位置题手工回归清单改写为“轮巡调度语义 + 调试日志字段”双重校验；
// 这样运行态回归不再只验证过滤是否命中，还会验证轮次覆盖和日志是否足够支撑定位问题。
[
    "在 `positionPrompt` 默认 `Filter = Note Names`、默认 `C / E / F / B` 状态下连续答对至少 6 次，确认当前题与下一题都只落在这些音名；若当前有 6 根候选弦，则一轮 6 题内 6 根弦各出现 1 次，再进入下一轮时重新开始轮巡。",
    "把 `positionPrompt` 的 `Filter` 切到 `Frets`，确认会回显当前品位集合；连续答对多次，确认当前题与下一题都只落在当前已选品位，并且每一轮会覆盖当前有候选的每根弦一次。",
    "在 `positionPrompt` 里只保留 `C / E` 这两个音名后连续观察至少两轮，确认当前题与下一题都只落在 `C / E`；同一根弦上会优先出现此前命中次数更少的格子，不受已保存品位集合干扰。",
    "观察控制台里的 `[PositionPrompt][Trainer]` 日志，确认会打印 `poolStrings`、`activeRoundStrings`、`selectedString`、`minimumHitCount`、`minimumHitCandidateCount`、`roundProgress` 等字段；切换 `Filter` 或指板配置后，这些字段会按新的候选池重新开始。"
]
```

## 结果

- 阶段 5 完成后，`PositionPrompt` 的共享层已经具备足够的调试可观测性，可以直接从控制台确认：
- 当前候选池是谁
- 当前轮已经消费了哪些弦、还剩哪些弦
- 当前弦内为何选择这个格子
- 调度状态是复用、还是因为候选池变化被重置
- 同时，`manualChecklist` 也已经和阶段 2 到阶段 5 的真实语义对齐，后续手工回归将不再沿用“全部合法位置随机”这套旧口径

# 20260401_141110_phase2_position_prompt_round_robin_selector

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_141110`
- 记录范围：`position prompt` 轮巡调度改造的阶段 2，只覆盖共享层 `trainer` 的选题与推进逻辑，不包含平台层 session 重建边界和 validation 改写
- 修改性质：这一步从根因上替换了“全候选格子随机抽题”的共享层策略，正式改成“按弦轮巡 + 弦内低频优先”的调度器；阶段 1 里新增的 `schedulingState` 在这里开始真正参与选题
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`

## 修改前

- 首题创建时，`makePositionPromptSession(...)` 只是把 `excluding: nil` 传给私有建题函数，没有沿用任何历史调度状态
- 答对推进时，`handlePositionPromptAnswer(...)` 仍然只是把当前格子作为 `excludedCell` 传入，下一题继续在整池里随机抽
- 私有 `makePositionPromptSession(...)` 的核心逻辑是：
- 先枚举全部合法候选格
- 如果有 `excludedCell`，就先把它过滤掉
- 然后直接对过滤后的候选数组执行 `randomElement`
- 也就是说，虽然阶段 1 已经给 session 加上了 `schedulingState`，但修改前这份状态还没有参与选题

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:filter:using:)
// 功能说明: 修改前首题入口仍然是“无状态建题”；
// 共享层没有把 session.schedulingState 往下传，私有建题函数每次都从头随机。
func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
    using generator: inout R
) -> PositionPromptSession {
    let normalizedFilter = Self.normalizedPositionPromptFilter(filter)
    let filterText = Self.positionPromptFilterDebugText(normalizedFilter)
    print("[PositionPrompt][Trainer] makePositionPromptSession begin \(filterText)")
    requirePositionPromptMode()
    let session = Self.makePositionPromptSession(
        configuration: configuration,
        filter: normalizedFilter,
        excluding: nil,
        using: &generator
    )
    print(
        "[PositionPrompt][Trainer] makePositionPromptSession end \(filterText) prompt=string=\(session.promptCell.stringIndex) fret=\(session.promptCell.fret) pitch=\(session.promptPitchClass.displayText())"
    )
    return session
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: handlePositionPromptAnswer(_:configuration:filter:session:using:)
// 功能说明: 修改前答对后虽然会排除当前格子，但不会继承旧 session 的轮次与命中统计；
// 下一题本质上仍是“在排除了当前格子的整池里再随机一次”。
mutating func handlePositionPromptAnswer<R: RandomNumberGenerator>(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
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
            filter: filter,
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

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:filter:excluding:using:)
// 功能说明: 修改前私有建题核心只会把 excludedCell 从候选数组里去掉；
// 然后直接对整池候选格执行 randomElement，不区分弦，也不看 hit 次数。
private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter,
    excluding excludedCell: FretboardCell?,
    using generator: inout R
) -> PositionPromptSession {
    let normalizedFilter = normalizedPositionPromptFilter(filter)
    let candidates = positionPromptCandidateCells(
        in: configuration,
        filter: normalizedFilter
    )
    let filteredCandidates = candidates.filter { cell in
        cell != excludedCell
    }
    let resolvedCandidates = filteredCandidates.isEmpty
        ? candidates
        : filteredCandidates

    guard let promptCell = resolvedCandidates.randomElement(using: &generator) else {
        preconditionFailure(
            "Position prompt candidates should never be empty."
        )
    }
    guard let promptPitchClass = configuration.pitchClass(for: promptCell) else {
        preconditionFailure(
            "Position prompt candidate cell must resolve to a pitch class."
        )
    }

    let candidatePoolSignature = positionPromptCandidatePoolSignature(
        in: configuration,
        filter: normalizedFilter,
        candidateCells: candidates
    )
    let session = PositionPromptSession(
        promptCell: promptCell,
        promptPitchClass: promptPitchClass,
        schedulingState: .initial(
            promptCell: promptCell,
            candidatePoolSignature: candidatePoolSignature
        )
    )
    return session
}
```

## 修改后

- 首题创建入口新增 `carryingOver: nil`，显式声明“新建 session 时不继承旧调度状态”
- 答对推进入口新增 `carryingOver: session.schedulingState`，让共享层在下一题时能延续上一题的轮次和命中计数
- 私有 `makePositionPromptSession(...)` 不再直接对整池 `randomElement`
- 新增 `positionPromptCandidateCellsByString(...)`，把候选格子按弦分组
- 新增 `selectPositionPromptCell(...)`，正式实现调度规则：
- 先决定当前轮剩余可出弦
- 再从这些弦里选下一根弦
- 再在该弦内部挑选 `hitCount` 最低的格子
- 若存在 `excludedCell`，优先在最低频候选里排除它
- 最终在最低频候选集合内随机打散
- 新增 `seededPositionPromptSchedulingState(...)`，用于在候选池身份未变化时复用旧调度状态；若 `candidatePoolSignature` 变化，则自动清空旧轮次和旧命中统计

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:filter:using:) / handlePositionPromptAnswer(_:configuration:filter:session:using:)
// 功能说明: 修改后首题入口显式传 nil，答对推进显式传旧 schedulingState；
// 这样首题从新轮次开始，答对后则沿用当前轮次与命中统计继续选下一题。
func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
    using generator: inout R
) -> PositionPromptSession {
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
    return session
}

mutating func handlePositionPromptAnswer<R: RandomNumberGenerator>(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
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
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: positionPromptCandidateCellsByString(...)
// 功能说明: 修改后新增“按弦分组”入口；
// 后续选题不再直接在扁平数组上工作，而是先把候选格按 stringIndex 聚合。
private static func positionPromptCandidateCellsByString(
    _ candidateCells: [FretboardCell]
) -> [Int: [FretboardCell]] {
    var cellsByString: [Int: [FretboardCell]] = [:]
    cellsByString.reserveCapacity(candidateCells.count)

    for cell in candidateCells {
        cellsByString[cell.stringIndex, default: []].append(cell)
    }

    return cellsByString
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: selectPositionPromptCell(...)
// 功能说明: 修改后真正负责“按弦轮巡 + 弦内低频优先”的共享层调度；
// 它先在当前轮的剩余弦里选弦，再在该弦内部挑 hitCount 最低的格子，最后才在并列最低频候选里随机打散。
private static func selectPositionPromptCell<R: RandomNumberGenerator>(
    candidatesByString: [Int: [FretboardCell]],
    candidatePoolSignature: PositionPromptSession.SchedulingState.CandidatePoolSignature,
    excluding excludedCell: FretboardCell?,
    carryingOver schedulingState: PositionPromptSession.SchedulingState?,
    using generator: inout R
) -> (
    promptCell: FretboardCell,
    schedulingState: PositionPromptSession.SchedulingState
) {
    let seedState = seededPositionPromptSchedulingState(
        carryingOver: schedulingState,
        candidatePoolSignature: candidatePoolSignature
    )
    let activeRoundStrings = seedState.remainingStringsInRound.isEmpty
        ? candidatePoolSignature.availableStringIndices
        : seedState.remainingStringsInRound
    let orderedActiveRoundStrings = activeRoundStrings.sorted()
    guard let selectedStringIndex = orderedActiveRoundStrings.randomElement(
        using: &generator
    ) else {
        preconditionFailure(
            "Position prompt candidate strings should never be empty."
        )
    }
    guard let stringCandidates = candidatesByString[selectedStringIndex],
          !stringCandidates.isEmpty else {
        preconditionFailure(
            "Position prompt selected string should always have at least one candidate cell."
        )
    }

    let minimumHitCount = stringCandidates.map {
        seedState.hitCount(for: $0)
    }.min() ?? 0
    let preferredCandidates = stringCandidates.filter {
        seedState.hitCount(for: $0) == minimumHitCount
    }
    let filteredPreferredCandidates = preferredCandidates.filter {
        $0 != excludedCell
    }
    let resolvedCandidates = filteredPreferredCandidates.isEmpty
        ? preferredCandidates
        : filteredPreferredCandidates
    guard let promptCell = resolvedCandidates.randomElement(using: &generator) else {
        preconditionFailure(
            "Position prompt resolved candidates should never be empty."
        )
    }

    var nextHitCounts = seedState.cellHitCounts
    nextHitCounts[promptCell, default: 0] += 1
    let nextSchedulingState = PositionPromptSession.SchedulingState(
        remainingStringsInRound: activeRoundStrings.subtracting([
            selectedStringIndex
        ]),
        cellHitCounts: nextHitCounts,
        candidatePoolSignature: candidatePoolSignature
    )
    return (
        promptCell: promptCell,
        schedulingState: nextSchedulingState
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: seededPositionPromptSchedulingState(...)
// 功能说明: 修改后新增调度状态播种入口；
// 如果 filter / tuning / maxFret 等导致 candidatePoolSignature 变化，就丢弃旧轮次和旧计数，从新候选池重新开始。
private static func seededPositionPromptSchedulingState(
    carryingOver schedulingState: PositionPromptSession.SchedulingState?,
    candidatePoolSignature: PositionPromptSession.SchedulingState.CandidatePoolSignature
) -> PositionPromptSession.SchedulingState {
    guard let schedulingState,
          schedulingState.candidatePoolSignature == candidatePoolSignature else {
        return PositionPromptSession.SchedulingState(
            remainingStringsInRound: candidatePoolSignature.availableStringIndices,
            cellHitCounts: [:],
            candidatePoolSignature: candidatePoolSignature
        )
    }

    return schedulingState
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:filter:excluding:carryingOver:using:)
// 功能说明: 修改后私有建题核心不再直接在整池 randomElement；
// 它会先构造 candidatePoolSignature 和按弦分组结果，再委托 selectPositionPromptCell 统一完成选题。
private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter,
    excluding excludedCell: FretboardCell?,
    carryingOver schedulingState: PositionPromptSession.SchedulingState?,
    using generator: inout R
) -> PositionPromptSession {
    let normalizedFilter = normalizedPositionPromptFilter(filter)
    let candidates = positionPromptCandidateCells(
        in: configuration,
        filter: normalizedFilter
    )
    let candidatePoolSignature = positionPromptCandidatePoolSignature(
        in: configuration,
        filter: normalizedFilter,
        candidateCells: candidates
    )
    let candidatesByString = positionPromptCandidateCellsByString(candidates)
    let selection = selectPositionPromptCell(
        candidatesByString: candidatesByString,
        candidatePoolSignature: candidatePoolSignature,
        excluding: excludedCell,
        carryingOver: schedulingState,
        using: &generator
    )
    let promptCell = selection.promptCell

    guard let promptPitchClass = configuration.pitchClass(for: promptCell) else {
        preconditionFailure(
            "Position prompt candidate cell must resolve to a pitch class."
        )
    }

    let session = PositionPromptSession(
        promptCell: promptCell,
        promptPitchClass: promptPitchClass,
        schedulingState: selection.schedulingState
    )
    return session
}
```

## 本阶段调度语义

- 首题从当前候选池的新轮次开始，`remainingStringsInRound` 初始为“当前有候选的弦集合”
- 每次正确作答后，会复用上一题的 `schedulingState`
- 当本轮的 `remainingStringsInRound` 为空时，自动重开下一轮
- 选中某根弦后，会优先挑这根弦里 `cellHitCounts` 最低的格子
- 若最低频格子不止一个，仍然保持随机打散
- 若存在 `excludedCell`，会优先在最低频候选集合里排除它；只有排除后为空，才允许回退到未排除版本
- 当 `candidatePoolSignature` 变化时，旧轮次和旧命中统计会被丢弃

## 本阶段尚未改动

- `macOSViewController.swift` / `iOSViewController.swift` 还没有根据 `candidatePoolSignature` 收口 reset 规则
- `positionPromptFilterChanged` 的平台层边界仍沿用旧逻辑
- `FretboardValidation.swift` 还没迁移到新的轮巡语义，仍然保留旧的“首题/次题固定候选顺序”假设
- 日志还没有补充“当前轮剩余弦 / 当前弦最低频候选数”等更细粒度的调度字段

## 本阶段结果

- 共享层选题已经不再是“全池随机”
- 轮巡状态和格子命中统计已经真正参与 `position prompt` 的题目推进
- 后续阶段只需要继续补齐平台层生命周期和 validation 语义，而不需要再回头推翻共享层选题模型

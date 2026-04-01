# 20260401_135038_phase1_position_prompt_round_robin_session_model

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_135038`
- 记录范围：`position prompt` 轮巡调度改造的阶段 1，只覆盖共享层 `session` 建模与一致性约束，不包含平台层重建逻辑和 validation 改写
- 修改性质：这一步不是直接改出题算法，而是先把后续“按弦轮巡 + 弦内低频优先”需要的状态挂进共享层真相来源，避免阶段 2 再把状态散落到平台层
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`

## 修改前

- `PositionPromptSession` 只保存当前题面的 `promptCell` 和 `promptPitchClass`
- `makePositionPromptSession(...)` 选出当前题目后，直接用这两个字段构造 session
- `validatePositionPromptSession(...)` 只校验“当前格子能否解析为当前音名”，没有轮次、命中次数、候选池身份这些共享层不变量

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: PositionPromptSession.init(...)
// 功能说明: 修改前的 session 只承载当前题面；
// 共享层里还没有“剩余待出弦 / 格子命中次数 / 候选池身份”这些调度状态。
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:filter:excluding:using:)
// 功能说明: 修改前先随机选出一个 promptCell，再直接把 promptCell 和 promptPitchClass 写进 session；
// 这一步没有初始化任何后续轮巡需要的共享层状态。
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
precondition(
    promptPitchClass.isNatural,
    "Position prompt candidate pitch class must be natural."
)

let session = PositionPromptSession(
    promptCell: promptCell,
    promptPitchClass: promptPitchClass
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: validatePositionPromptSession(...)
// 功能说明: 修改前只保证“当前题面合法且与 configuration 对齐”；
// 还没有对调度状态做共享层约束。
private func validatePositionPromptSession(
    _ session: PositionPromptSession,
    configuration: FretboardConfiguration,
    _ function: StaticString = #function
) {
    precondition(
        session.promptPitchClass.isNatural,
        "\(function) position prompt session pitch class must stay natural."
    )
    guard let resolvedPromptPitchClass = configuration.pitchClass(for: session.promptCell) else {
        preconditionFailure(
            "\(function) position prompt session cell must resolve to a pitch class."
        )
    }
    precondition(
        resolvedPromptPitchClass == session.promptPitchClass,
        "\(function) position prompt session pitch class must match the current configuration."
    )
}
```

## 修改后

- `PositionPromptSession` 新增 `SchedulingState`
- `SchedulingState` 里新增三类共享层调度真相：
- `remainingStringsInRound`：当前轮还没出过的弦
- `cellHitCounts`：每个格子的历史命中次数
- `candidatePoolSignature`：当前候选池身份，用于后续判断过滤条件和指板配置变化时旧状态是否失效
- `makePositionPromptSession(...)` 仍然保留原来的 `randomElement` 选题方式，但在出题完成后会立刻初始化调度状态：
- 当前题所在弦会从本轮剩余弦集合中移除
- 当前题所在格子的命中次数初始化为 `1`
- `validatePositionPromptSession(...)` 新增共享层不变量校验，保证这些状态至少在结构上是自洽的

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: PositionPromptSession.init(...) / PositionPromptSession.SchedulingState.initial(...)
// 功能说明: 修改后把阶段 2 需要的轮巡状态收口进 session；
// 当前题所在弦会被视为“本轮已消费”，当前题所在格子会留下首个 hit 计数。
struct PositionPromptSession: Equatable, Sendable {
    struct SchedulingState: Equatable, Sendable {
        struct CandidatePoolSignature: Equatable, Sendable {
            var tuning: InstrumentTuning
            var maxFret: Int
            var filter: PositionPromptCandidateFilter
            var availableStringIndices: Set<Int>
        }

        var remainingStringsInRound: Set<Int>
        var cellHitCounts: [FretboardCell: Int]
        var candidatePoolSignature: CandidatePoolSignature

        init(
            remainingStringsInRound: Set<Int>,
            cellHitCounts: [FretboardCell: Int],
            candidatePoolSignature: CandidatePoolSignature
        ) {
            let invalidRemainingStrings = remainingStringsInRound.subtracting(
                candidatePoolSignature.availableStringIndices
            )
            precondition(
                invalidRemainingStrings.isEmpty,
                "Position prompt scheduling remaining strings must stay within the current candidate pool."
            )
            precondition(
                cellHitCounts.values.allSatisfy { $0 > 0 },
                "Position prompt scheduling hit counts must stay positive."
            )
            self.remainingStringsInRound = remainingStringsInRound
            self.cellHitCounts = cellHitCounts
            self.candidatePoolSignature = candidatePoolSignature
        }

        func hitCount(for cell: FretboardCell) -> Int {
            cellHitCounts[cell, default: 0]
        }

        static func initial(
            promptCell: FretboardCell,
            candidatePoolSignature: CandidatePoolSignature
        ) -> SchedulingState {
            SchedulingState(
                remainingStringsInRound: candidatePoolSignature.availableStringIndices
                    .subtracting([promptCell.stringIndex]),
                cellHitCounts: [promptCell: 1],
                candidatePoolSignature: candidatePoolSignature
            )
        }
    }

    var promptCell: FretboardCell
    var promptPitchClass: PitchClass
    var schedulingState: SchedulingState
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:filter:excluding:using:) / positionPromptCandidatePoolSignature(...)
// 功能说明: 修改后仍然沿用原来的随机选格子逻辑；
// 但在拿到 promptCell 后，会额外构造候选池身份，并把 schedulingState 一起写进 session。
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
precondition(
    promptPitchClass.isNatural,
    "Position prompt candidate pitch class must be natural."
)

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
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: positionPromptCandidatePoolSignature(in:filter:)
// 功能说明: 修改后新增共享层候选池身份构造入口；
// 它把 tuning、maxFret、normalized filter 和“当前实际有候选的弦集合”封装成一个可比较的签名。
static func positionPromptCandidatePoolSignature(
    in configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter
) -> PositionPromptSession.SchedulingState.CandidatePoolSignature {
    let normalizedFilter = normalizedPositionPromptFilter(filter)
    let candidateCells = positionPromptCandidateCells(
        in: configuration,
        filter: normalizedFilter
    )
    return positionPromptCandidatePoolSignature(
        in: configuration,
        filter: normalizedFilter,
        candidateCells: candidateCells
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: validatePositionPromptSession(...)
// 功能说明: 修改后除了校验当前题面合法，还会校验调度状态的结构一致性；
// 例如当前弦必须属于候选池、当前弦不能仍留在本轮剩余集合里、当前格子必须已有 hit 记录。
private func validatePositionPromptSession(
    _ session: PositionPromptSession,
    configuration: FretboardConfiguration,
    _ function: StaticString = #function
) {
    precondition(
        session.promptPitchClass.isNatural,
        "\(function) position prompt session pitch class must stay natural."
    )
    guard let resolvedPromptPitchClass = configuration.pitchClass(for: session.promptCell) else {
        preconditionFailure(
            "\(function) position prompt session cell must resolve to a pitch class."
        )
    }
    precondition(
        resolvedPromptPitchClass == session.promptPitchClass,
        "\(function) position prompt session pitch class must match the current configuration."
    )
    precondition(
        session.schedulingState.candidatePoolSignature.availableStringIndices.contains(
            session.promptCell.stringIndex
        ),
        "\(function) position prompt session prompt string must stay within the stored candidate pool."
    )
    precondition(
        !session.schedulingState.remainingStringsInRound.contains(
            session.promptCell.stringIndex
        ),
        "\(function) position prompt session current prompt string must already be consumed in the active round."
    )
    precondition(
        session.schedulingState.cellHitCounts.values.allSatisfy { $0 > 0 },
        "\(function) position prompt session hit counts must stay positive."
    )
    precondition(
        session.schedulingState.hitCount(for: session.promptCell) > 0,
        "\(function) position prompt session current prompt cell must have recorded history."
    )
}
```

## 本阶段尚未改动

- 出题算法还没有从“全候选格子随机”切到“按弦轮巡 + 弦内低频优先”
- `handlePositionPromptAnswer(...)` 的推进语义还没接入新的调度状态
- `macOSViewController.swift` / `iOSViewController.swift` 还没根据 `candidatePoolSignature` 收口 session reset 边界
- `FretboardValidation.swift` 还没从“首题是第一候选 / 次题是第二候选”的旧假设迁移出来

## 本阶段结果

- 共享层已经具备承载后续轮巡调度的 session 数据结构
- 后续阶段可以在不把状态散落到平台层的前提下，继续实现：
- 用 `remainingStringsInRound` 做按弦轮巡
- 用 `cellHitCounts` 做弦内低频优先
- 用 `candidatePoolSignature` 做过滤条件和指板配置变化后的失效判定

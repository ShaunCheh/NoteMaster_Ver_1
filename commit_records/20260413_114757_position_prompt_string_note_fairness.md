# 20260413_114757_position_prompt_string_note_fairness

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260413_114757`
- 记录依据：基于当前工作区 `changes` 与 `git diff -- "NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift" "NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift"` 整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `position prompt` 共享调度器与共享验证层的实际代码改动；目标是把原来的“弦公平 -> 格子公平”升级为“弦公平 -> 音名公平 -> 格子公平”
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 当前工作区的附带 markdown 变更：
- `.cursor/plans/位置题音名公平计划_062e1e61.plan.md`
- 说明：上面的 `.plan.md` 是实施前的计划文件，不承载产品逻辑实现；下面的代码说明只聚焦两处 `Swift` 文件

## 本次结论

- `PositionPromptSession.SchedulingState` 不再只记录弦轮巡和格子命中，而是新增了按弦记录的音名命中状态 `noteHitCountsByString`
- `selectPositionPromptCell(...)` 不再在选中弦后直接按最低 `cellHitCount` 选格，而是改成：
- 先选当前轮剩余弦
- 再在该弦上选 `noteHitCount` 最低的音名
- 最后在该 `(弦, 音名)` 组里选 `cellHitCount` 最低的格子，并继续尽量避开上一题同格
- runtime precondition、debug 文本、初始记账语义都一起升级，避免新旧不变量混用
- `FretboardValidation` 的 position prompt 校验从“验证同弦最低格子命中优先”升级为“验证同弦最低音名命中优先，再验证同音格子最低命中优先”
- 自动验证补了 `defaultNoteNamesPlusD` 场景，直接覆盖“默认音名集合基础上新增 D”这条路径
- iOS / macOS 控制器 API 没有改签名，本次实现仍然完全收口在 shared trainer / validation

## 修改 1：调度状态从“只记格子”扩展为“按弦记音名 + 格子”

### 修改前

- 旧 `SchedulingState` 只知道：
- 当前轮还剩哪些弦 `remainingStringsInRound`
- 每个格子被出过多少次 `cellHitCounts`
- 这意味着它只能实现“弦公平 + 格子公平”，无法表达“同一根弦上，不同音名要先均衡”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: PositionPromptSession.SchedulingState.init / hitCount(for:) / initial(promptCell:candidatePoolSignature:)
// 功能说明: 修改前调度状态只维护弦轮巡和格子命中次数；
// 同一根弦上的音名没有独立统计，因此无法实现弦内音名均衡。
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
```

### 修改后

- 新增 `noteHitCountsByString`
- 新增 `noteHitCount(forStringIndex:pitchClass:)`
- 首题初始化时，同时给当前格子的 `(弦, 音名)` 和 `cell` 各记一次命中
- 初始化和 session 校验都新增了 note 级合法性约束，保证新状态不会和旧状态脱节

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: PositionPromptSession.SchedulingState.init / noteHitCount(forStringIndex:pitchClass:) / initial(promptCell:promptPitchClass:candidatePoolSignature:)
// 功能说明: 修改后调度状态先记录“这根弦上的哪个音名出过几次”，
// 再记录具体格子的命中次数，为“弦公平 -> 音名公平 -> 格子公平”提供状态基础。
struct SchedulingState: Equatable, Sendable {
    struct CandidatePoolSignature: Equatable, Sendable {
        var tuning: InstrumentTuning
        var maxFret: Int
        var filter: PositionPromptCandidateFilter
        var availableStringIndices: Set<Int>
    }

    var remainingStringsInRound: Set<Int>
    var noteHitCountsByString: [Int: [PitchClass: Int]]
    var cellHitCounts: [FretboardCell: Int]
    var candidatePoolSignature: CandidatePoolSignature

    init(
        remainingStringsInRound: Set<Int>,
        noteHitCountsByString: [Int: [PitchClass: Int]],
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
        let invalidTrackedStrings = Set(noteHitCountsByString.keys).subtracting(
            candidatePoolSignature.availableStringIndices
        )
        precondition(
            invalidTrackedStrings.isEmpty,
            "Position prompt scheduling tracked note strings must stay within the current candidate pool."
        )
        precondition(
            noteHitCountsByString.values.allSatisfy { noteHitCounts in
                !noteHitCounts.isEmpty
                    && noteHitCounts.keys.allSatisfy(\.isNatural)
                    && noteHitCounts.values.allSatisfy { $0 > 0 }
            },
            "Position prompt scheduling note hit counts must stay positive and natural."
        )
        precondition(
            cellHitCounts.values.allSatisfy { $0 > 0 },
            "Position prompt scheduling hit counts must stay positive."
        )
        self.remainingStringsInRound = remainingStringsInRound
        self.noteHitCountsByString = noteHitCountsByString
        self.cellHitCounts = cellHitCounts
        self.candidatePoolSignature = candidatePoolSignature
    }

    func noteHitCount(
        forStringIndex stringIndex: Int,
        pitchClass: PitchClass
    ) -> Int {
        noteHitCountsByString[stringIndex]?[pitchClass] ?? 0
    }

    func hitCount(for cell: FretboardCell) -> Int {
        cellHitCounts[cell, default: 0]
    }

    static func initial(
        promptCell: FretboardCell,
        promptPitchClass: PitchClass,
        candidatePoolSignature: CandidatePoolSignature
    ) -> SchedulingState {
        SchedulingState(
            remainingStringsInRound: candidatePoolSignature.availableStringIndices
                .subtracting([promptCell.stringIndex]),
            noteHitCountsByString: [
                promptCell.stringIndex: [
                    promptPitchClass: 1
                ]
            ],
            cellHitCounts: [promptCell: 1],
            candidatePoolSignature: candidatePoolSignature
        )
    }
}
```

## 修改 2：选题核心从“选弦后直接选格”改成“选弦 -> 选音 -> 选格”

### 修改前

- 旧逻辑已经有“每轮每弦一次”
- 但选中某根弦后，会直接在该弦所有候选格里按最低 `cellHitCount` 选格
- 因为没有音名层，所以如果某个音在这根弦上有多个位置，它就会天然更容易被抽到

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: selectPositionPromptCell(candidatesByString:candidatePoolSignature:excluding:carryingOver:using:)
// 功能说明: 修改前会先选弦，但选中弦之后直接在整根弦的候选格里按最低格子命中优先；
// 这里没有单独的音名层，所以弦内不同音名的概率无法被校正到均匀。
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

### 修改后

- 私有建题流程先额外构造 `candidatesByStringAndPitchClass`
- `selectPositionPromptCell(...)` 的返回值增加了 `promptPitchClass`
- 选中弦之后，先在该弦内部找 `noteHitCount` 最低的音名，再只在这个音名对应的格子里做最低 `cellHitCount` 选择
- 选定题目后，同时更新：
- `remainingStringsInRound`
- `noteHitCountsByString`
- `cellHitCounts`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:filter:excluding:carryingOver:using:)
// 功能说明: 修改后私有建题入口会同时准备“按弦分组”和“按弦+音名分组”的候选池，
// 让后续调度器可以先做弦公平，再做音名公平，最后才落到具体格子。
let candidatesByString = positionPromptCandidateCellsByString(candidates)
let candidatesByStringAndPitchClass =
    positionPromptCandidateCellsByStringAndPitchClass(
        candidates,
        configuration: configuration
    )
let selection = selectPositionPromptCell(
    candidatesByString: candidatesByString,
    candidatesByStringAndPitchClass: candidatesByStringAndPitchClass,
    candidatePoolSignature: candidatePoolSignature,
    excluding: excludedCell,
    carryingOver: schedulingState,
    using: &generator
)
let promptCell = selection.promptCell
let promptPitchClass = selection.promptPitchClass
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: selectPositionPromptCell(candidatesByString:candidatesByStringAndPitchClass:candidatePoolSignature:excluding:carryingOver:using:)
// 功能说明: 修改后选题顺序是“选弦 -> 选最低音名命中 -> 选最低格子命中”；
// 这样同一根弦上被选中的音名会先趋于均衡，同音名下的多个格子再继续被均衡分配。
private static func selectPositionPromptCell<R: RandomNumberGenerator>(
    candidatesByString: [Int: [FretboardCell]],
    candidatesByStringAndPitchClass: [Int: [PitchClass: [FretboardCell]]],
    candidatePoolSignature: PositionPromptSession.SchedulingState.CandidatePoolSignature,
    excluding excludedCell: FretboardCell?,
    carryingOver schedulingState: PositionPromptSession.SchedulingState?,
    using generator: inout R
) -> (
    promptCell: FretboardCell,
    promptPitchClass: PitchClass,
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
    guard let stringCandidatesByPitchClass =
        candidatesByStringAndPitchClass[selectedStringIndex],
        !stringCandidatesByPitchClass.isEmpty else {
        preconditionFailure(
            "Position prompt selected string should always have at least one candidate pitch class."
        )
    }

    let availablePitchClasses = Set(stringCandidatesByPitchClass.keys)
    let orderedPitchClasses = PitchClass.naturalCasesInOrder.filter {
        availablePitchClasses.contains($0)
    }
    let minimumNoteHitCount = orderedPitchClasses.map {
        seedState.noteHitCount(
            forStringIndex: selectedStringIndex,
            pitchClass: $0
        )
    }.min() ?? 0
    let preferredPitchClasses = orderedPitchClasses.filter {
        seedState.noteHitCount(
            forStringIndex: selectedStringIndex,
            pitchClass: $0
        ) == minimumNoteHitCount
    }
    guard let selectedPitchClass = preferredPitchClasses.randomElement(
        using: &generator
    ) else {
        preconditionFailure(
            "Position prompt preferred pitch classes should never be empty."
        )
    }
    guard let pitchCandidates = stringCandidatesByPitchClass[selectedPitchClass],
          !pitchCandidates.isEmpty else {
        preconditionFailure(
            "Position prompt selected pitch class should always have at least one candidate cell."
        )
    }

    let minimumCellHitCount = pitchCandidates.map {
        seedState.hitCount(for: $0)
    }.min() ?? 0
    let preferredCandidates = pitchCandidates.filter {
        seedState.hitCount(for: $0) == minimumCellHitCount
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

    var nextNoteHitCountsByString = seedState.noteHitCountsByString
    var nextStringNoteHitCounts =
        nextNoteHitCountsByString[selectedStringIndex] ?? [:]
    nextStringNoteHitCounts[selectedPitchClass, default: 0] += 1
    nextNoteHitCountsByString[selectedStringIndex] = nextStringNoteHitCounts

    var nextHitCounts = seedState.cellHitCounts
    nextHitCounts[promptCell, default: 0] += 1
    let nextSchedulingState = PositionPromptSession.SchedulingState(
        remainingStringsInRound: activeRoundStrings.subtracting([
            selectedStringIndex
        ]),
        noteHitCountsByString: nextNoteHitCountsByString,
        cellHitCounts: nextHitCounts,
        candidatePoolSignature: candidatePoolSignature
    )
    return (
        promptCell: promptCell,
        promptPitchClass: selectedPitchClass,
        schedulingState: nextSchedulingState
    )
}
```

## 修改 3：共享验证从“看同弦最低格子”升级为“先看同弦最低音名，再看同音最低格子”

### 修改前

- 旧 `validateCorrectAdvance(...)` 会验证：
- 下一题仍然遵循当前轮剩余弦集合
- 下一题格子是否属于该弦上 `cellHitCount` 最低的候选集合
- 也就是说，验证层默认接受“只要格子命中最低就算合理”，并没有专门约束下一题音名是否在同弦上优先均衡

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateCorrectAdvance(scenario:from:evaluation:to:filter:candidateCellSet:candidateCellsByString:expectedSignature:)
// 功能说明: 修改前只校验“弦轮巡 + 同弦最低格子命中优先”；
// 验证层不会检查 nextPromptPitchClass 是否遵循同弦音名均衡。
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
    // ... 省略与旧题/新题同步相关的基础断言 ...

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

### 修改后

- 新增 `candidateCellsByStringAndPitchClass`
- 新增 note-level state 断言：
- `noteHitCountsByString` 的键必须都留在当前候选弦集合内
- 当前 `promptPitchClass` 在当前弦上必须已经有命中记录
- 在正确推进验证里，先检查下一题 `promptPitchClass` 是否属于该弦上最低 `noteHitCount` 的音名集合
- 只有通过音名层之后，才继续检查该音名下的 `cellHitCount`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validatePositionPromptSessionState(...) / validateCorrectAdvance(...)
// 功能说明: 修改后验证层会先检查同弦音名计数，再检查同音格子计数；
// 这样自动化断言会和新的调度器语义保持一致。
func validatePositionPromptSessionState(
    scenario name: String,
    stage: String,
    session: FretboardNaturalNoteTrainerState.PositionPromptSession,
    filter: PositionPromptCandidateFilter,
    candidateCellSet: Set<FretboardCell>,
    candidateCellsByString: [Int: [FretboardCell]],
    candidateCellsByStringAndPitchClass: [Int: [PitchClass: [FretboardCell]]],
    expectedSignature: PositionPromptCandidatePoolSignature
) {
    if !Set(session.schedulingState.noteHitCountsByString.keys).isSubset(
        of: expectedSignature.availableStringIndices
    ) {
        record("position prompt trainer \(name) \(stage) 的 noteHitCountsByString 包含了候选池之外的弦。")
    }
    if !session.schedulingState.noteHitCountsByString.values.allSatisfy({
        !$0.isEmpty
            && $0.keys.allSatisfy(\.isNatural)
            && $0.values.allSatisfy { $0 > 0 }
    }) {
        record("position prompt trainer \(name) \(stage) 的 noteHitCountsByString 应全部为自然音正数。")
    }
    if session.schedulingState.noteHitCount(
        forStringIndex: session.promptCell.stringIndex,
        pitchClass: session.promptPitchClass
    ) <= 0 {
        record("position prompt trainer \(name) \(stage) 的当前 promptPitchClass 应已有同弦命中记录。")
    }
}

func validateCorrectAdvance(
    scenario name: String,
    from previousSession: FretboardNaturalNoteTrainerState.PositionPromptSession,
    evaluation: FretboardNaturalNoteTrainerState.PositionPromptEvaluation,
    to nextSession: FretboardNaturalNoteTrainerState.PositionPromptSession,
    filter: PositionPromptCandidateFilter,
    candidateCellSet: Set<FretboardCell>,
    candidateCellsByString: [Int: [FretboardCell]],
    candidateCellsByStringAndPitchClass: [Int: [PitchClass: [FretboardCell]]],
    expectedSignature: PositionPromptCandidatePoolSignature
) {
    // ... 省略与旧题/新题同步、remainingStringsInRound 的基础断言 ...

    let nextStringIndex = nextSession.promptCell.stringIndex
    guard let stringCandidatesByPitchClass =
        candidateCellsByStringAndPitchClass[nextStringIndex] else {
        record("position prompt trainer \(name) 正确作答后缺少 nextPromptCell 所在弦的音名候选分组。")
        return
    }
    let availablePitchClasses = Set(stringCandidatesByPitchClass.keys)
    let orderedPitchClasses = PitchClass.naturalCasesInOrder.filter {
        availablePitchClasses.contains($0)
    }
    let minimumNoteHitCount = orderedPitchClasses.map {
        previousSession.schedulingState.noteHitCount(
            forStringIndex: nextStringIndex,
            pitchClass: $0
        )
    }.min() ?? 0
    let preferredPitchClasses = orderedPitchClasses.filter {
        previousSession.schedulingState.noteHitCount(
            forStringIndex: nextStringIndex,
            pitchClass: $0
        ) == minimumNoteHitCount
    }
    if !preferredPitchClasses.contains(nextSession.promptPitchClass) {
        record("position prompt trainer \(name) 正确作答后 nextPromptPitchClass 未遵循同弦最低音名命中优先规则。")
    }

    guard let pitchCandidates =
        stringCandidatesByPitchClass[nextSession.promptPitchClass] else {
        record("position prompt trainer \(name) 正确作答后缺少 nextPromptPitchClass 对应的格子候选分组。")
        return
    }
    let minimumHitCount = pitchCandidates.map {
        previousSession.schedulingState.hitCount(for: $0)
    }.min() ?? 0
    let preferredCandidates = pitchCandidates.filter {
        previousSession.schedulingState.hitCount(for: $0) == minimumHitCount
    }
    let filteredPreferredCandidates = preferredCandidates.filter {
        $0 != previousSession.promptCell
    }
    let allowedCandidates = filteredPreferredCandidates.isEmpty
        ? preferredCandidates
        : filteredPreferredCandidates
    if !allowedCandidates.contains(nextSession.promptCell) {
        record("position prompt trainer \(name) 正确作答后 nextPromptCell 未遵循同音格子的最低命中优先或排除当前格规则。")
    }
}
```

## 修改 4：回归场景显式补上 `default + D`

### 修改前

- 自动化只覆盖：
- 默认 `C / E / F / B`
- 子集 `C / E`
- 品位筛选场景
- 还没有一条专门回归“在默认集合基础上新增 `D`”的路径

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改前只有默认音名集合和 C/E 子集，没有把 default + D 单独固化成回归场景。
validateFilterScenario(
    name: "defaultNoteNames",
    filter: defaultPositionQuestionConfiguration.activeFilter,
    requiresNoOpenStrings: false
)
validateFilterScenario(
    name: "subset_C_E",
    filter: TrainerPositionPromptConfiguration(
        filterMode: .noteName,
        selectedPitchClasses: [.c, .e]
    ).activeFilter,
    requiresNoOpenStrings: false
)
```

### 修改后

- 额外补入 `defaultNoteNamesPlusD`
- 这样默认集合加 `D` 的候选池、推进路径、音名公平性都会被共享验证覆盖

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改后把“默认音名集合基础上新增 D”固化成单独场景，
// 用来回归 default + D 下的候选池、推进和音名公平行为。
validateFilterScenario(
    name: "defaultNoteNames",
    filter: defaultPositionQuestionConfiguration.activeFilter,
    requiresNoOpenStrings: false
)
validateFilterScenario(
    name: "subset_C_E",
    filter: TrainerPositionPromptConfiguration(
        filterMode: .noteName,
        selectedPitchClasses: [.c, .e]
    ).activeFilter,
    requiresNoOpenStrings: false
)
validateFilterScenario(
    name: "defaultNoteNamesPlusD",
    filter: TrainerPositionPromptConfiguration(
        filterMode: .noteName,
        selectedPitchClasses: [.c, .d, .e, .f, .b]
    ).activeFilter,
    requiresNoOpenStrings: false
)
```

## 未改动的层

- `Platform/iOS/iOSViewController.swift`
- `Platform/macOS/macOSViewController.swift`

说明：
- 本次没有改控制器的 API 形态
- `ensurePositionPromptSession(...)`、`handlePositionPromptAnswer(...)`、`applyPositionPromptProjection(...)` 仍然只消费 shared trainer 暴露出的 `session` / `evaluation`
- 调度升级仍然完全收口在 shared 层

## 验证结果

- `ReadLints` 检查 `FretboardNaturalNoteTrainer.swift` 与 `FretboardValidation.swift`，无 linter errors
- 已执行本地构建：
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- 结果：构建通过

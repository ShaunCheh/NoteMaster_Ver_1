# 20260329_163332_phase4_position_prompt_fret_filter_shared_trainer_filtering

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_163332`
- 记录范围：实施“Position 品位筛选”计划的阶段 4，只完成 shared `positionPrompt` trainer 的 allowed-frets 过滤、validation 同步，以及 iOS / macOS 控制器对当前筛选结果的最小透传
- 本次目标：让 `positionPrompt` 的题目候选池、正确作答后的换题、validation 基线都正式落在“已选中的品位集合”内
- 本次不包含：
- 用户切换筛选后对“当前已显示题目”是否合法的重建
- pending 反馈任务取消后的 session 时序整理
- 手工回归清单与更完整 validation 场景
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `.cursor/plans/position品位筛选_cb2e8023.plan.md`

## 本次结论

- 阶段 4 完成后，`positionPrompt` 的共享出题逻辑已经真正接入 `allowedFrets`
- 默认允许集合使用 `TrainerPositionPromptConfiguration.defaultSelectedFrets`，也就是 `1...12`；因此 `positionPrompt` 默认不再从空弦 `fret == 0` 出题
- 正确作答后生成下一题时，会沿用当前筛选结果继续抽题，而不是回退到“全指板自然音候选”
- 双端控制器虽然还没有实现“筛选变化后立即重建非法当前题”，但至少在新建题目和答对后换题这两个入口上，都已经开始把 `selectedFrets` 传入 shared trainer

## 修改 1：shared trainer 让 `makePositionPromptSession` / `handlePositionPromptAnswer` 正式接入 `allowedFrets`

### 修改前

- `makePositionPromptSession(...)` 没有 `allowedFrets` 参数
- `handlePositionPromptAnswer(...)` 也没有 `allowedFrets` 参数
- 因此即使阶段 1 已经有 `TrainerPositionPromptConfiguration.selectedFrets`，shared trainer 在出题和换题时仍然完全不知道当前品位筛选结果

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makePositionPromptSession(configuration:), makePositionPromptSession(configuration:using:),
// handlePositionPromptAnswer(_:configuration:session:), handlePositionPromptAnswer(_:configuration:session:using:)
// 功能说明: 修改前 shared trainer 的 positionPrompt 建题和换题都只依赖 configuration；
// 外层即使持有 selectedFrets，也没有入口把这些筛选条件传进来。
func makePositionPromptSession(
    configuration: FretboardConfiguration
) -> PositionPromptSession {
    var generator = SystemRandomNumberGenerator()
    return makePositionPromptSession(
        configuration: configuration,
        using: &generator
    )
}

func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    using generator: inout R
) -> PositionPromptSession {
    print("[PositionPrompt][Trainer] makePositionPromptSession begin")
    requirePositionPromptMode()
    let session = Self.makePositionPromptSession(
        configuration: configuration,
        excluding: nil,
        using: &generator
    )
    print(
        "[PositionPrompt][Trainer] makePositionPromptSession end prompt=string=\(session.promptCell.stringIndex) fret=\(session.promptCell.fret) pitch=\(session.promptPitchClass.displayText())"
    )
    return session
}

mutating func handlePositionPromptAnswer(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    session: inout PositionPromptSession
) -> PositionPromptAnswerResult {
    var generator = SystemRandomNumberGenerator()
    return handlePositionPromptAnswer(
        pitchClass,
        configuration: configuration,
        session: &session,
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

### 修改后

- `makePositionPromptSession(...)` 新增 `allowedFrets`
- `handlePositionPromptAnswer(...)` 新增 `allowedFrets`
- 所有入口默认值都统一为 `TrainerPositionPromptConfiguration.defaultSelectedFrets`
- 内部先做 `normalizedPositionPromptAllowedFrets(...)`，保证非法输入会被裁剪回合法筛选集合
- 正确作答后的下一题会继续沿用当前 `allowedFrets`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makePositionPromptSession(configuration:allowedFrets:),
// makePositionPromptSession(configuration:allowedFrets:using:),
// handlePositionPromptAnswer(_:configuration:allowedFrets:session:),
// handlePositionPromptAnswer(_:configuration:allowedFrets:session:using:)
// 功能说明: 修改后 shared trainer 的建题和换题都正式接入 allowedFrets；
// 外层控制器只要把当前 selectedFrets 传入，就能保证 positionPrompt 出题始终落在筛选集合内。
func makePositionPromptSession(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets
) -> PositionPromptSession {
    var generator = SystemRandomNumberGenerator()
    return makePositionPromptSession(
        configuration: configuration,
        allowedFrets: allowedFrets,
        using: &generator
    )
}

func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets,
    using generator: inout R
) -> PositionPromptSession {
    let normalizedAllowedFrets = Self.normalizedPositionPromptAllowedFrets(
        allowedFrets
    )
    let allowedFretsText = normalizedAllowedFrets.sorted().map(String.init).joined(
        separator: ","
    )
    print("[PositionPrompt][Trainer] makePositionPromptSession begin")
    requirePositionPromptMode()
    let session = Self.makePositionPromptSession(
        configuration: configuration,
        allowedFrets: normalizedAllowedFrets,
        excluding: nil,
        using: &generator
    )
    print(
        "[PositionPrompt][Trainer] makePositionPromptSession end allowedFrets=\(allowedFretsText) prompt=string=\(session.promptCell.stringIndex) fret=\(session.promptCell.fret) pitch=\(session.promptPitchClass.displayText())"
    )
    return session
}

mutating func handlePositionPromptAnswer(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets,
    session: inout PositionPromptSession
) -> PositionPromptAnswerResult {
    var generator = SystemRandomNumberGenerator()
    return handlePositionPromptAnswer(
        pitchClass,
        configuration: configuration,
        allowedFrets: allowedFrets,
        session: &session,
        using: &generator
    )
}

mutating func handlePositionPromptAnswer<R: RandomNumberGenerator>(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets,
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
            allowedFrets: allowedFrets,
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

## 修改 2：shared trainer 的候选池枚举改成只看允许品位，默认不再把空弦纳入 `positionPrompt`

### 修改前

- `positionPromptCandidateCells(in:)` 直接遍历 `configuration.fretRange`
- 没有任何 `allowedFrets` 过滤
- 这意味着只要空弦本身是自然音，它也会进入 `positionPrompt` 的候选池
- 私有建题函数的日志里也只有 `excludedCell`，看不到当前筛选范围

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makePositionPromptSession(configuration:excluding:using:),
// positionPromptCandidateCells(in:)
// 功能说明: 修改前建题函数只知道“排除当前 cell”，不知道“允许哪些品位”；
// candidateCells 会把 configuration.fretRange 中所有自然音位置都纳入候选，包含空弦。
private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    excluding excludedCell: FretboardCell?,
    using generator: inout R
) -> PositionPromptSession {
    let excludedCellText: String
    if let excludedCell {
        excludedCellText = "string=\(excludedCell.stringIndex) fret=\(excludedCell.fret)"
    } else {
        excludedCellText = "nil"
    }
    print(
        "[PositionPrompt][Trainer] selectPrompt begin excluded=\(excludedCellText)"
    )
    let candidates = positionPromptCandidateCells(in: configuration)
    print(
        "[PositionPrompt][Trainer] selectPrompt candidates count=\(candidates.count)"
    )
    let filteredCandidates = candidates.filter { cell in
        cell != excludedCell
    }
    let resolvedCandidates = filteredCandidates.isEmpty
        ? candidates
        : filteredCandidates
    // ...
}

private static func positionPromptCandidateCells(
    in configuration: FretboardConfiguration
) -> [FretboardCell] {
    var cells: [FretboardCell] = []
    cells.reserveCapacity(configuration.stringCount * configuration.displayPositionCount)

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            let cell = FretboardCell(
                stringIndex: stringIndex,
                fret: fret
            )
            guard let pitchClass = configuration.pitchClass(for: cell),
                  pitchClass.isNatural else {
                continue
            }
            cells.append(cell)
        }
    }

    return cells
}
```

### 修改后

- 私有建题函数新增 `allowedFrets`
- 日志里会打印归一化后的 `allowedFrets`
- `positionPromptCandidateCells(...)` 新增 `allowedFrets` 参数并统一做归一化
- 只有 `normalizedAllowedFrets.contains(fret)` 的位置才会进入候选池
- 由于默认值是 `TrainerPositionPromptConfiguration.defaultSelectedFrets`，也就是 `1...12`，所以空弦默认不会进入 `positionPrompt`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makePositionPromptSession(configuration:allowedFrets:excluding:using:),
// positionPromptCandidateCells(in:allowedFrets:), normalizedPositionPromptAllowedFrets(_:)
// 功能说明: 修改后候选池枚举会先按 allowedFrets 过滤 fret；
// 默认 positionPrompt 候选只来自 1...12 品的自然音位置，不再把空弦带入题库。
private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int>,
    excluding excludedCell: FretboardCell?,
    using generator: inout R
) -> PositionPromptSession {
    let normalizedAllowedFrets = normalizedPositionPromptAllowedFrets(
        allowedFrets
    )
    let excludedCellText: String
    if let excludedCell {
        excludedCellText = "string=\(excludedCell.stringIndex) fret=\(excludedCell.fret)"
    } else {
        excludedCellText = "nil"
    }
    let allowedFretsText = normalizedAllowedFrets.sorted().map(String.init).joined(
        separator: ","
    )
    print(
        "[PositionPrompt][Trainer] selectPrompt begin allowedFrets=\(allowedFretsText) excluded=\(excludedCellText)"
    )
    let candidates = positionPromptCandidateCells(
        in: configuration,
        allowedFrets: normalizedAllowedFrets
    )
    print(
        "[PositionPrompt][Trainer] selectPrompt candidates count=\(candidates.count)"
    )
    let filteredCandidates = candidates.filter { cell in
        cell != excludedCell
    }
    let resolvedCandidates = filteredCandidates.isEmpty
        ? candidates
        : filteredCandidates
    // ...
}

private static func positionPromptCandidateCells(
    in configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets
) -> [FretboardCell] {
    let normalizedAllowedFrets = normalizedPositionPromptAllowedFrets(
        allowedFrets
    )
    var cells: [FretboardCell] = []
    cells.reserveCapacity(configuration.stringCount * configuration.displayPositionCount)

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            guard normalizedAllowedFrets.contains(fret) else {
                continue
            }
            let cell = FretboardCell(
                stringIndex: stringIndex,
                fret: fret
            )
            guard let pitchClass = configuration.pitchClass(for: cell),
                  pitchClass.isNatural else {
                continue
            }
            cells.append(cell)
        }
    }

    return cells
}

private static func normalizedPositionPromptAllowedFrets(
    _ allowedFrets: Set<Int>
) -> Set<Int> {
    TrainerPositionPromptConfiguration(
        selectedFrets: allowedFrets
    ).selectedFrets
}
```

## 修改 3：validation 同步到新的默认语义，确认默认候选与换题结果都继续落在允许品位里

### 修改前

- validation 仍然按“全自然音候选池”建基准
- `positionPromptCandidateCells(configuration:)` 没有 `allowedFrets`
- `makePositionPromptSession(...)` / `handlePositionPromptAnswer(...)` 的测试调用也没有传 `allowedFrets`
- 因此 validation 无法断言“默认只在 `1...12` 品中出题”这层新语义

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(fixture:record:),
// positionPromptCandidateCells(configuration:)
// 功能说明: 修改前 validation 只验证“自然音位置”和“正确/错误作答时的换题语义”；
// 还没有把 allowedFrets / 默认排除空弦 納入校验。
let configuration = fixture.configuration
logStage("candidateEnumeration")
let candidateCells = positionPromptCandidateCells(
    configuration: configuration
)

let initialSession = initialTrainer.makePositionPromptSession(
    configuration: configuration,
    using: &initialGenerator
)

switch wrongTrainer.handlePositionPromptAnswer(
    wrongAnswer,
    configuration: configuration,
    session: &wrongSession,
    using: &wrongGenerator
) {
// ...
}

switch correctTrainer.handlePositionPromptAnswer(
    correctSession.promptPitchClass,
    configuration: configuration,
    session: &correctSession,
    using: &correctGenerator
) {
// ...
}

static func positionPromptCandidateCells(
    configuration: FretboardConfiguration
) -> [FretboardCell] {
    var cells: [FretboardCell] = []
    // ...
}
```

### 修改后

- validation 显式声明 `allowedFrets = TrainerPositionPromptConfiguration.defaultSelectedFrets`
- 候选枚举、建题、错答、正答全部沿用同一 `allowedFrets`
- 额外断言：
- 候选基准 cell 落在 `1...12`
- 初始 session 不落在空弦或未允许品位
- 正确作答后的 `nextPromptCell` 和最终 `session.promptCell` 都继续落在允许品位内
- validation 内部的辅助 `positionPromptCandidateCells(...)` 也同步到新的过滤语义

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(fixture:record:),
// positionPromptCandidateCells(configuration:allowedFrets:)
// 功能说明: 修改后 validation 会把默认 allowedFrets=1...12 作为基线；
// 同时验证初始题目与答对后换题都继续落在允许品位内，确保 shared trainer 过滤语义真实生效。
let configuration = fixture.configuration
let allowedFrets = TrainerPositionPromptConfiguration.defaultSelectedFrets
logStage("candidateEnumeration")
let candidateCells = positionPromptCandidateCells(
    configuration: configuration,
    allowedFrets: allowedFrets
)

if !allowedFrets.contains(firstCandidateCell.fret)
    || !allowedFrets.contains(secondCandidateCell.fret) {
    record("position prompt trainer 的默认候选基准 cell 应落在 1...12 品范围内。")
}

let initialSession = initialTrainer.makePositionPromptSession(
    configuration: configuration,
    allowedFrets: allowedFrets,
    using: &initialGenerator
)
if !allowedFrets.contains(initialSession.promptCell.fret) {
    record("position prompt trainer 默认新建 session 不应落在空弦或未允许的品位。")
}

switch wrongTrainer.handlePositionPromptAnswer(
    wrongAnswer,
    configuration: configuration,
    allowedFrets: allowedFrets,
    session: &wrongSession,
    using: &wrongGenerator
) {
// ...
}

switch correctTrainer.handlePositionPromptAnswer(
    correctSession.promptPitchClass,
    configuration: configuration,
    allowedFrets: allowedFrets,
    session: &correctSession,
    using: &correctGenerator
) {
case let .evaluated(evaluation):
    // ...
    if !allowedFrets.contains(evaluation.nextPromptCell.fret) {
        record("position prompt trainer 正确作答后 nextPromptCell 应继续落在允许品位内。")
    }
}
if !allowedFrets.contains(correctSession.promptCell.fret) {
    record("position prompt trainer 正确作答后 session.promptCell 应继续落在允许品位内。")
}

static func positionPromptCandidateCells(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets
) -> [FretboardCell] {
    let normalizedAllowedFrets = TrainerPositionPromptConfiguration(
        selectedFrets: allowedFrets
    ).selectedFrets
    var cells: [FretboardCell] = []

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            guard normalizedAllowedFrets.contains(fret) else {
                continue
            }
            let cell = FretboardCell(
                stringIndex: stringIndex,
                fret: fret
            )
            guard let pitchClass = configuration.pitchClass(for: cell),
                  pitchClass.isNatural else {
                continue
            }
            cells.append(cell)
        }
    }

    return cells
}
```

## 修改 4：双端控制器做最小透传，让 shared trainer 立刻开始使用当前筛选结果

### 修改前

- iOS / macOS 控制器在创建 `positionPromptSession` 时只传 `configuration`
- 用户点击音名按钮时，正确作答后的换题也只传 `configuration`
- 结果是即使阶段 3 的设置面板已经能改 `selectedFrets`，阶段 4 之前 shared trainer 仍然不会真正使用这组筛选

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: ensurePositionPromptSession(), handlePositionPromptAnswer(_:)
// 功能说明: 修改前 iOS 端虽然已经持有 trainerDisplayState.positionPromptConfiguration；
// 但在新建题目和答对换题时，仍未把 selectedFrets 透传给 shared trainer。
private func ensurePositionPromptSession() {
    // ...
    positionPromptSession = fretboardTrainerState.makePositionPromptSession(
        configuration: displayState.configuration,
        using: &generator
    )
    // ...
}

private func handlePositionPromptAnswer(_ pitchClass: PitchClass) {
    // ...
    let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
        pitchClass,
        configuration: displayState.configuration,
        session: &positionPromptSession
    )
    // ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: ensurePositionPromptSession(), handlePositionPromptAnswer(_:)
// 功能说明: 修改前 macOS 端与 iOS 相同；
// selectedFrets 还没有在 controller -> shared trainer 这条链路里真正生效。
private func ensurePositionPromptSession() {
    // ...
    positionPromptSession = fretboardTrainerState.makePositionPromptSession(
        configuration: displayState.configuration,
        using: &generator
    )
    // ...
}

private func handlePositionPromptAnswer(_ pitchClass: PitchClass) {
    // ...
    let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
        pitchClass,
        configuration: displayState.configuration,
        session: &positionPromptSession
    )
    // ...
}
```

### 修改后

- iOS / macOS 在建题和答对换题时都把 `trainerDisplayState.positionPromptConfiguration.selectedFrets` 传进 shared trainer
- 这是阶段 4 的“最小控制器接线”
- 它能保证：
- 新建题目按当前筛选生成
- 正确作答后的下一题按当前筛选生成
- 但它还不会在用户切换筛选后立即判定“当前题是否合法”，这一点留到阶段 5

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: ensurePositionPromptSession(), handlePositionPromptAnswer(_:)
// 功能说明: 修改后 iOS 端会把当前 selectedFrets 透传给 shared trainer；
// 这样新建题目和答对后的换题都开始遵守 positionPrompt 的品位筛选。
private func ensurePositionPromptSession() {
    // ...
    positionPromptSession = fretboardTrainerState.makePositionPromptSession(
        configuration: displayState.configuration,
        allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
        using: &generator
    )
    // ...
}

private func handlePositionPromptAnswer(_ pitchClass: PitchClass) {
    // ...
    let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
        pitchClass,
        configuration: displayState.configuration,
        allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
        session: &positionPromptSession
    )
    // ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: ensurePositionPromptSession(), handlePositionPromptAnswer(_:)
// 功能说明: 修改后 macOS 端也用当前 selectedFrets 驱动 shared trainer；
// 双端在 positionPrompt 的建题/换题入口上终于与 settings 面板状态对齐。
private func ensurePositionPromptSession() {
    // ...
    positionPromptSession = fretboardTrainerState.makePositionPromptSession(
        configuration: displayState.configuration,
        allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
        using: &generator
    )
    // ...
}

private func handlePositionPromptAnswer(_ pitchClass: PitchClass) {
    // ...
    let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
        pitchClass,
        configuration: displayState.configuration,
        allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
        session: &positionPromptSession
    )
    // ...
}
```

## 修改 5：同步计划状态，标记阶段 4 完成

### 修改前

- `phase4-trainer-filtering` 仍处于进行中
- 计划文件还没有反映“shared trainer 已经真正接入 allowed-frets 过滤”

```md
<!-- 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md -->
<!-- 函数名/符号: todo item phase4-trainer-filtering -->
<!-- 功能说明: 修改前计划文件还把阶段 4 记为进行中。 -->
- id: phase4-trainer-filtering
  content: 在 shared positionPrompt trainer 中引入 allowed frets 过滤，确保候选池与换题都只落在选中品位
  status: in_progress
```

### 修改后

- `phase4-trainer-filtering` 已标记为 `completed`
- 计划文件与当前代码状态保持一致，下一步可以进入阶段 5 的非法当前题重建与时序处理

```md
<!-- 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md -->
<!-- 函数名/符号: todo item phase4-trainer-filtering -->
<!-- 功能说明: 修改后计划文件已确认阶段 4 完成；
下一步可进入筛选变化后的 session 匹配、重建与反馈时序处理。 -->
- id: phase4-trainer-filtering
  content: 在 shared positionPrompt trainer 中引入 allowed frets 过滤，确保候选池与换题都只落在选中品位
  status: completed
```

## 验证情况

- 已对 `FretboardNaturalNoteTrainer.swift`、`FretboardValidation.swift`、`iOSViewController.swift`、`macOSViewController.swift` 运行静态诊断，`ReadLints` 未发现新增问题
- validation 代码已经同步到新的默认语义：
- 默认 `positionPrompt` 候选池使用 `1...12`
- 初始题目不再允许落在空弦
- 正确作答后的新题仍必须落在允许品位内
- 本阶段没有运行 `xcodebuild`，也没有做双端手工回归
- 当前仍保留的已知边界：
- 如果用户在当前题显示期间修改筛选，而当前题已经变成非法题，界面还不会立即重建
- 这一点正是阶段 5 要处理的内容

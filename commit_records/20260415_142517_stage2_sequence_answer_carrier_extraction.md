# 20260415_142517_stage2_sequence_answer_carrier_extraction

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_142517`
- 记录依据：基于当前工作区 `changes`、`git diff --stat`、`git diff --unified=20`、当前文件内容、`commit_records/20260415_134045_stage1_sequence_answer_policy_threading.md` 与本次验证结果整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 2”真实落地的代码改动；目标是把 sequence 答案从裸 `PitchClass` 升级为统一 carrier，让 shared 层同时能承载 `pitchClass` 与 `notePitch`
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`7 files changed, 214 insertions(+), 26 deletions(-)`
- 统计口径说明：
- 上面的 `git diff --stat` 是这 7 个文件相对 `HEAD` 的累计差异
- 其中 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift` 与 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift` 在阶段 1 已经处于未提交修改状态，因此累计统计里包含了阶段 1 + 阶段 2 的叠加差异
- 本文下面“修改前 / 修改后”的代码片段，已经按“本轮实际修改前状态”重建：对于这两个文件，以阶段 1 记录中的“修改后”状态作为本轮前镜像；其余 5 个文件的“修改前”直接依据当前相对 `HEAD` 的差异还原
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerEvent.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift`
- 验证结果：
- `ReadLints`：对本轮 7 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug build CODE_SIGNING_ALLOWED=NO`：构建通过
- 说明：本记录文件本身是新增 markdown 记录，不计入上面“阶段 2 实际代码修改文件”的 7 个 `Swift` 文件统计

## 本次结论

- `ExerciseAnswerPayload` 现在已经能同时承载 `.pitchClass`、`.notePitch`、`.fretboardCell`
- 新增 `ResolvedSequenceAnswer`，把 sequence 需要的 `pitchClass`、`notePitch?`、`surfaceID` 统一收口到一个 shared carrier
- `ExerciseAnswerRouter` 在 `.sequence / .sr1 / .sr2` 下已经不再返回裸 `PitchClass`，而是返回 `.quarterNoteSequence(event:answer:)`
- 双端 controller 已改为消费 `ResolvedSequenceAnswer`，但当前仍然只把 `answer.pitchClass` 送进 trainer，所以运行时判题行为保持不变
- shared validation 已经覆盖 `notePitch` payload 保真、`ResolvedSequenceAnswer` 解析，以及 sequence route shape 升级

## 修改 1：给 `ExerciseAnswerEvent` 增加 `notePitch` payload，并引入统一 sequence 答案载体

### 修改前

- `ExerciseAnswerPayload` 只有 `.pitchClass` 和 `.fretboardCell`
- `pitchClass` 只会从 `.pitchClass` 分支返回值
- shared 层没有统一的 sequence 答案 carrier

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerEvent.swift
// 函数名/符号: enum ExerciseAnswerPayload / struct ExerciseAnswerEvent
// 功能说明: 修改前 answer event 只能承载 pitch-class 或 fretboard cell；
// sequence shared 层还没有 full-note answer carrier，未来 piano 输入也没有标准落点。
enum ExerciseAnswerPayload: Equatable, Sendable {
    case pitchClass(PitchClass)
    case fretboardCell(FretboardCell)

    var pitchClass: PitchClass? {
        guard case let .pitchClass(pitchClass) = self else {
            return nil
        }
        return pitchClass
    }

    var fretboardCell: FretboardCell? {
        guard case let .fretboardCell(cell) = self else {
            return nil
        }
        return cell
    }
}

struct ExerciseAnswerEvent: Equatable, Sendable {
    var surfaceID: ExerciseSurfaceID
    var payload: ExerciseAnswerPayload

    static func pitchClass(
        _ pitchClass: PitchClass,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .pitchClass(pitchClass)
        )
    }

    static func fretboardCell(
        _ cell: FretboardCell,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .fretboardCell(cell)
        )
    }
}
```

### 修改后

- `ExerciseAnswerPayload` 新增 `.notePitch(NotePitch)`
- `payload.pitchClass` 现在会对 `.notePitch` 做投影
- 新增 `payload.notePitch`
- 新增 `ExerciseAnswerEvent.notePitch(...)`
- 新增 `ResolvedSequenceAnswer`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerEvent.swift
// 函数名/符号: enum ExerciseAnswerPayload / struct ExerciseAnswerEvent / struct ResolvedSequenceAnswer
// 功能说明: 修改后 answer event 能同时承载 pitchClass、notePitch、fretboardCell；
// sequence shared 层统一用 ResolvedSequenceAnswer 承载答题语义。
enum ExerciseAnswerPayload: Equatable, Sendable {
    case pitchClass(PitchClass)
    case notePitch(NotePitch)
    case fretboardCell(FretboardCell)

    var pitchClass: PitchClass? {
        switch self {
        case let .pitchClass(pitchClass):
            return pitchClass
        case let .notePitch(notePitch):
            return notePitch.pitchClass
        case .fretboardCell:
            return nil
        }
    }

    var notePitch: NotePitch? {
        guard case let .notePitch(notePitch) = self else {
            return nil
        }
        return notePitch
    }

    var fretboardCell: FretboardCell? {
        guard case let .fretboardCell(cell) = self else {
            return nil
        }
        return cell
    }
}

struct ExerciseAnswerEvent: Equatable, Sendable {
    var surfaceID: ExerciseSurfaceID
    var payload: ExerciseAnswerPayload

    static func pitchClass(
        _ pitchClass: PitchClass,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .pitchClass(pitchClass)
        )
    }

    static func notePitch(
        _ notePitch: NotePitch,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .notePitch(notePitch)
        )
    }

    static func fretboardCell(
        _ cell: FretboardCell,
        from surfaceID: ExerciseSurfaceID
    ) -> ExerciseAnswerEvent {
        ExerciseAnswerEvent(
            surfaceID: surfaceID,
            payload: .fretboardCell(cell)
        )
    }
}

struct ResolvedSequenceAnswer: Equatable, Sendable {
    var pitchClass: PitchClass
    var notePitch: NotePitch?
    var surfaceID: ExerciseSurfaceID
}
```

## 修改 2：把 sequence 路由从裸 `PitchClass` 升级为 `ResolvedSequenceAnswer`

### 2.1 `FretboardNaturalNoteTrainer.swift`

#### 修改前

- 这部分“修改前”以前一轮阶段 1 记录中的落地状态为准
- shared trainer 只有 `resolvedPitchClass(...)`
- `.pitchClass` 和 `.fretboardCell` 都会被压扁成裸 `PitchClass`
- `.notePitch` 还没有标准解析入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: static func resolvedPitchClass(from:configuration:)
// 功能说明: 本轮修改前 sequence shared 层只会恢复 pitchClass；
// 不会保留完整 NotePitch，也没有 surfaceID 级别的统一答案载体。
static func resolvedPitchClass(
    from event: ExerciseAnswerEvent,
    configuration: FretboardConfiguration
) -> PitchClass? {
    switch event.payload {
    case let .pitchClass(pitchClass):
        return pitchClass
    case let .fretboardCell(cell):
        return configuration.notePitch(for: cell)?.pitchClass
    }
}
```

#### 修改后

- 新增 `resolvedSequenceAnswer(...)`
- `.pitchClass` 会生成只带 `pitchClass` 的 carrier
- `.notePitch` 会生成保留完整 `notePitch` 的 carrier
- `.fretboardCell` 会通过 `FretboardConfiguration` 解出 `NotePitch`，再生成 carrier
- 原有 `resolvedPitchClass(...)` 现在只做投影，复用 `resolvedSequenceAnswer(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: static func resolvedSequenceAnswer(from:configuration:) / static func resolvedPitchClass(from:configuration:)
// 功能说明: 修改后 sequence shared 层统一恢复 ResolvedSequenceAnswer；
// 这样后续 SR-1 piano 与 SR-2 exact-note 都能复用同一条恢复链。
static func resolvedSequenceAnswer(
    from event: ExerciseAnswerEvent,
    configuration: FretboardConfiguration
) -> ResolvedSequenceAnswer? {
    switch event.payload {
    case let .pitchClass(pitchClass):
        return ResolvedSequenceAnswer(
            pitchClass: pitchClass,
            notePitch: nil,
            surfaceID: event.surfaceID
        )
    case let .notePitch(notePitch):
        return ResolvedSequenceAnswer(
            pitchClass: notePitch.pitchClass,
            notePitch: notePitch,
            surfaceID: event.surfaceID
        )
    case let .fretboardCell(cell):
        guard let notePitch = configuration.notePitch(for: cell) else {
            return nil
        }
        return ResolvedSequenceAnswer(
            pitchClass: notePitch.pitchClass,
            notePitch: notePitch,
            surfaceID: event.surfaceID
        )
    }
}

static func resolvedPitchClass(
    from event: ExerciseAnswerEvent,
    configuration: FretboardConfiguration
) -> PitchClass? {
    resolvedSequenceAnswer(
        from: event,
        configuration: configuration
    )?.pitchClass
}
```

### 2.2 `ExerciseAnswerRouter.swift`

#### 修改前

- sequence route 仍然把答案建模成裸 `PitchClass`
- router 只调用 `resolvedPitchClass(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: enum ExerciseAnswerRoute / static func route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能说明: 修改前 sequence route 只携带裸 pitchClass；
// 即使来源是 fretboardCell，也会在路由阶段被压扁成单一的 pitch-class 结果。
enum ExerciseAnswerRoute: Equatable, Sendable {
    case singleCoverage(
        event: ExerciseAnswerEvent,
        cell: FretboardCell
    )
    case quarterNoteSequence(
        event: ExerciseAnswerEvent,
        pitchClass: PitchClass
    )
    case positionPrompt(
        ExercisePositionPromptRoutedAnswer
    )
}

case .sequence, .sr1, .sr2:
    guard let pitchClass = FretboardNaturalNoteTrainerState
        .resolvedPitchClass(
            from: event,
            configuration: fretboardConfiguration
        ) else {
        // ... ignored branches ...
    }

    return .routed(
        .quarterNoteSequence(
            event: event,
            pitchClass: pitchClass
        )
    )
```

#### 修改后

- `ExerciseAnswerRoute.quarterNoteSequence` 改为携带 `ResolvedSequenceAnswer`
- router 改为调用 `resolvedSequenceAnswer(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: enum ExerciseAnswerRoute / static func route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能说明: 修改后 sequence route 正式切到 ResolvedSequenceAnswer；
// 现有指板与 notestrip 仍然能走旧行为，但 shared 层已保留 full-note seam。
enum ExerciseAnswerRoute: Equatable, Sendable {
    case singleCoverage(
        event: ExerciseAnswerEvent,
        cell: FretboardCell
    )
    case quarterNoteSequence(
        event: ExerciseAnswerEvent,
        answer: ResolvedSequenceAnswer
    )
    case positionPrompt(
        ExercisePositionPromptRoutedAnswer
    )
}

case .sequence, .sr1, .sr2:
    guard let answer = FretboardNaturalNoteTrainerState
        .resolvedSequenceAnswer(
            from: event,
            configuration: fretboardConfiguration
        ) else {
        // ... ignored branches ...
    }

    return .routed(
        .quarterNoteSequence(
            event: event,
            answer: answer
        )
    )
```

## 修改 3：双端 controller 改为消费 `ResolvedSequenceAnswer`

### 3.1 `iOSViewController.swift`

#### 修改前

- sequence route 消费的是 `pitchClass`
- controller 的日志只会从 `selectedCell -> selectedPitch` 或裸 `pitchClass` 中选一种输出

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: handleRoutedExerciseAnswer(_:) / handleQuarterNoteSequenceAnswer(_:pitchClass:)
// 功能说明: 修改前 iOS controller 的 sequence 消费点只接裸 pitchClass；
// 没有携带统一答案载体，也不能直接消费 notePitch payload。
private func handleRoutedExerciseAnswer(_ route: ExerciseAnswerRoute) {
    switch route {
    case let .singleCoverage(_, cell):
        handleSingleCoverageAnswer(cell)
    case let .quarterNoteSequence(event, pitchClass):
        handleQuarterNoteSequenceAnswer(
            event,
            pitchClass: pitchClass
        )
    case let .positionPrompt(answer):
        handlePositionPromptAnswer(answer)
    }
}

private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    pitchClass: PitchClass
) {
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        pitchClass,
        session: &quarterNoteSequenceSession
    )

    let selectedCell = event.payload.fretboardCell
    let selectedPitch = selectedCell.flatMap {
        displayState.configuration.notePitch(for: $0)
    }

    switch answerResult {
    case .ignored(.completedSession):
        if let selectedCell {
            // ... log cell ...
        } else {
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=completedSession answered=\(pitchClass.displayText())"
            )
        }
    case let .evaluated(evaluation):
        if let selectedCell,
           let selectedPitch {
            // ... log cell + selectedPitch ...
        } else {
            print(
                "[iOS] \(evaluation.debugSummary()) answered=\(pitchClass.displayText())"
            )
        }
    }
}
```

#### 修改后

- route 消费切到 `ResolvedSequenceAnswer`
- 仍然只把 `answer.pitchClass` 送进 trainer
- 当 `answer.notePitch` 存在时，日志优先打印完整音高

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: handleRoutedExerciseAnswer(_:) / handleQuarterNoteSequenceAnswer(_:answer:)
// 功能说明: 修改后 iOS controller 统一消费 ResolvedSequenceAnswer；
// 当前仍保持旧的 pitch-class 判题，只是把完整音高带到日志与后续阶段的输入通道里。
private func handleRoutedExerciseAnswer(_ route: ExerciseAnswerRoute) {
    switch route {
    case let .singleCoverage(_, cell):
        handleSingleCoverageAnswer(cell)
    case let .quarterNoteSequence(event, answer):
        handleQuarterNoteSequenceAnswer(
            event,
            answer: answer
        )
    case let .positionPrompt(answer):
        handlePositionPromptAnswer(answer)
    }
}

private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    answer: ResolvedSequenceAnswer
) {
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        answer.pitchClass,
        session: &quarterNoteSequenceSession
    )

    let selectedCell = event.payload.fretboardCell
    let selectedPitch = answer.notePitch ?? selectedCell.flatMap {
        displayState.configuration.notePitch(for: $0)
    }

    switch answerResult {
    case .ignored(.completedSession):
        if let selectedCell {
            // ... log cell ...
        } else if let selectedPitch {
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=completedSession answered=\(selectedPitch.displayText())"
            )
        } else {
            print(
                "[QuarterNoteSequence][iOS] result=ignored reason=completedSession answered=\(answer.pitchClass.displayText())"
            )
        }
    case let .evaluated(evaluation):
        if let selectedCell,
           let selectedPitch {
            // ... log cell + selectedPitch ...
        } else if let selectedPitch {
            print(
                "[iOS] \(evaluation.debugSummary()) answered=\(selectedPitch.displayText())"
            )
        } else {
            print(
                "[iOS] \(evaluation.debugSummary()) answered=\(answer.pitchClass.displayText())"
            )
        }
    }
}
```

### 3.2 `macOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handleRoutedExerciseAnswer(_:) / handleQuarterNoteSequenceAnswer(_:pitchClass:)
// 功能说明: 修改前 macOS controller 与 iOS 一样，只消费裸 pitchClass；
// sequence 路由层还没有 full-note carrier 进入平台侧。
private func handleRoutedExerciseAnswer(_ route: ExerciseAnswerRoute) {
    switch route {
    case let .singleCoverage(_, cell):
        handleSingleCoverageAnswer(cell)
    case let .quarterNoteSequence(event, pitchClass):
        handleQuarterNoteSequenceAnswer(
            event,
            pitchClass: pitchClass
        )
    case let .positionPrompt(answer):
        handlePositionPromptAnswer(answer)
    }
}

private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    pitchClass: PitchClass
) {
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        pitchClass,
        session: &quarterNoteSequenceSession
    )
    // ... 省略与 iOS 同构的日志逻辑 ...
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handleRoutedExerciseAnswer(_:) / handleQuarterNoteSequenceAnswer(_:answer:)
// 功能说明: 修改后 macOS controller 同步切到 ResolvedSequenceAnswer；
// 保持与 iOS 相同的共享语义和日志策略，避免双端行为分叉。
private func handleRoutedExerciseAnswer(_ route: ExerciseAnswerRoute) {
    switch route {
    case let .singleCoverage(_, cell):
        handleSingleCoverageAnswer(cell)
    case let .quarterNoteSequence(event, answer):
        handleQuarterNoteSequenceAnswer(
            event,
            answer: answer
        )
    case let .positionPrompt(answer):
        handlePositionPromptAnswer(answer)
    }
}

private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    answer: ResolvedSequenceAnswer
) {
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        answer.pitchClass,
        session: &quarterNoteSequenceSession
    )
    let selectedCell = event.payload.fretboardCell
    let selectedPitch = answer.notePitch ?? selectedCell.flatMap {
        displayState.configuration.notePitch(for: $0)
    }
    // ... 其余日志逻辑与 iOS 同步改为优先消费 answer.notePitch ...
}
```

## 修改 4：补 shared validation，锁住新 payload、route 与 helper 的合同

### 4.1 `ExerciseCompositionValidationExercisePolicy.swift`

#### 修改前

- 只验证了 `fretboardCellEvent` 与 `pitchClassEvent`
- answer router 夹具没有 sequence route 的 `ResolvedSequenceAnswer` 合同

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateAnswerEventPreservesPayloadAndSurfaceID() / validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
// 功能说明: 修改前 composition validation 只覆盖旧的 payload 类型与旧的 sequence route shape；
// shared validation 还看不见 notePitch payload 和 ResolvedSequenceAnswer。
let fretboardCellEvent = ExerciseAnswerEvent.fretboardCell(
    FretboardCell(stringIndex: 2, fret: 3),
    from: .fretboard
)
if fretboardCellEvent.surfaceID != .fretboard
    || fretboardCellEvent.payload.fretboardCell
        != FretboardCell(stringIndex: 2, fret: 3) {
    // ...
}

let pitchClassEvent = ExerciseAnswerEvent.pitchClass(
    .c,
    from: .naturalNoteStrip
)
if pitchClassEvent.surfaceID != .naturalNoteStrip
    || pitchClassEvent.payload.pitchClass != .c {
    // ...
}

guard let answerPitchClass = fretboardConfiguration.pitchClass(
    for: answerCell
) else {
    // ...
}

// 这里还没有 sequence route 的 ResolvedSequenceAnswer 断言。
```

#### 修改后

- 新增 `notePitchEvent` 保真验证
- answer router 夹具改为先拿 `answerNotePitch`
- 新增 stacked sequence 场景，要求 `.fretboardCell` 路由成带 `pitchClass + notePitch + surfaceID` 的 `ResolvedSequenceAnswer`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateAnswerEventPreservesPayloadAndSurfaceID() / validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
// 功能说明: 修改后 composition validation 能看到 notePitch payload 和 sequence 新 route shape；
// 这样 route carrier 升级不会只停留在类型定义层。
let notePitchEvent = ExerciseAnswerEvent.notePitch(
    NotePitch(pitchClass: .c, octave: 4),
    from: .piano
)
if notePitchEvent.surfaceID != .piano
    || notePitchEvent.payload.notePitch
        != NotePitch(pitchClass: .c, octave: 4)
    || notePitchEvent.payload.pitchClass != .c {
    // ...
}

guard let answerNotePitch = fretboardConfiguration.notePitch(
    for: answerCell
) else {
    // ...
}
let answerPitchClass = answerNotePitch.pitchClass

let sequenceTrainerDisplayState = TrainerDisplayState(exerciseMode: .sequence)
let stackedSequencePresentation = ExerciseCompositionPolicy.makePresentation(
    from: ExerciseCompositionPolicyInput(
        trainerDisplayState: sequenceTrainerDisplayState,
        fretboardTrainerState: .init(
            quarterNoteSequenceSpec: sequenceTrainerDisplayState
                .sequenceConfiguration
                .quarterNoteSequenceSpec
        ),
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pianoPanelState: .init(),
        layoutPreferences: .default
    )
)

if ExerciseAnswerRouter.route(
    fretboardCellEvent,
    presentationState: stackedSequencePresentation,
    trainerDisplayState: sequenceTrainerDisplayState,
    fretboardConfiguration: fretboardConfiguration
) != .routed(
    .quarterNoteSequence(
        event: fretboardCellEvent,
        answer: ResolvedSequenceAnswer(
            pitchClass: answerPitchClass,
            notePitch: answerNotePitch,
            surfaceID: .fretboard
        )
    )
) {
    // ...
}
```

### 4.2 `FretboardValidation.swift`

#### 修改前

- 这部分“修改前”以前一轮阶段 1 记录中的落地状态为准
- quarter-note validation 只检查了阶段 1 的 `comparisonPolicy / expectedNotePitch`
- 没有验证 `resolvedSequenceAnswer(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 本轮修改前 validation 只覆盖阶段 1 的 evaluator seam；
// shared answer carrier 还没有进入 quarter-note trainer 的验证链。
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
    if evaluation.comparisonPolicy != naturalSpec.answerPolicy {
        record("quarter-note trainer 错误作答时返回的 comparisonPolicy 未对齐当前 spec.answerPolicy。")
    }
    if evaluation.expectedNotePitch != evaluation.expectedWrittenPitch.notePitch {
        record("quarter-note trainer 错误作答时返回的 expectedNotePitch 未正确投影自 expectedWrittenPitch.notePitch。")
    }
    // ... 其余旧断言 ...
default:
    record("quarter-note trainer 错误作答未返回 evaluated 结果。")
}

// 这里还没有 resolvedSequenceAnswer 的 stage 级验证。
```

#### 修改后

- 新增 `logStage("resolvedSequenceAnswer")`
- 同时验证三类输入：
- `.pitchClass` -> `ResolvedSequenceAnswer(pitchClass, notePitch:nil, surfaceID:.naturalNoteStrip)`
- `.fretboardCell` -> `ResolvedSequenceAnswer(pitchClass, notePitch:resolvedNotePitch, surfaceID:.fretboard)`
- `.notePitch` -> `ResolvedSequenceAnswer(pitchClass, notePitch:resolvedNotePitch, surfaceID:.piano)`
- 继续验证 `resolvedPitchClass(...)` 能从 `.notePitch` 投影出 `PitchClass`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后 fretboard validation 把统一 sequence answer carrier 纳入合同；
// 这样阶段 2 的 helper 与 payload 升级有了 shared 层的回归保护。
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
    if FretboardNaturalNoteTrainerState.resolvedSequenceAnswer(
        from: pitchClassEvent,
        configuration: fixture.configuration
    ) != ResolvedSequenceAnswer(
        pitchClass: resolvedAnswerNotePitch.pitchClass,
        notePitch: nil,
        surfaceID: .naturalNoteStrip
    ) {
        record("resolvedSequenceAnswer 应把 pitchClass payload 解析成只带 pitchClass 的 sequence 答案。")
    }

    let fretboardCellEvent = ExerciseAnswerEvent.fretboardCell(
        resolvedAnswerCell,
        from: .fretboard
    )
    if FretboardNaturalNoteTrainerState.resolvedSequenceAnswer(
        from: fretboardCellEvent,
        configuration: fixture.configuration
    ) != ResolvedSequenceAnswer(
        pitchClass: resolvedAnswerNotePitch.pitchClass,
        notePitch: resolvedAnswerNotePitch,
        surfaceID: .fretboard
    ) {
        record("resolvedSequenceAnswer 应把 fretboardCell payload 解析成同时带 pitchClass 与 notePitch 的 sequence 答案。")
    }

    let notePitchEvent = ExerciseAnswerEvent.notePitch(
        resolvedAnswerNotePitch,
        from: .piano
    )
    if FretboardNaturalNoteTrainerState.resolvedSequenceAnswer(
        from: notePitchEvent,
        configuration: fixture.configuration
    ) != ResolvedSequenceAnswer(
        pitchClass: resolvedAnswerNotePitch.pitchClass,
        notePitch: resolvedAnswerNotePitch,
        surfaceID: .piano
    ) {
        record("resolvedSequenceAnswer 应把 notePitch payload 解析成保留完整音高的 sequence 答案。")
    }

    if FretboardNaturalNoteTrainerState.resolvedPitchClass(
        from: notePitchEvent,
        configuration: fixture.configuration
    ) != resolvedAnswerNotePitch.pitchClass {
        record("resolvedPitchClass 应继续从 notePitch payload 投影出 pitchClass。")
    }
}
```

## 本次没有做的事情

- 没有修改 `TrainerSequenceConfiguration`
- 没有修改 `QuarterNoteSequenceSpec`
- 没有修改 `QuarterNoteSequenceEvaluation`
- 没有把 `FretboardNaturalNoteTrainerState.handleQuarterNoteSequenceAnswer(...)` 的入参从 `PitchClass` 升级为 `ResolvedSequenceAnswer`
- 没有让 `comparisonPolicy` 真正控制 comparator；当前 `isCorrect` 仍然走 `answeredPitchClass == expectedPitchClass`
- 没有接入真实的 piano 事件桥；虽然 shared payload 已支持 `.notePitch`，但 UI 入口还没切到这条链
- 没有修改 `SettingsPanelModel.swift`
- 没有新增 `ExerciseCompositionPreset.staffToPiano`
- 没有开放 `SR-1` 运行时入口

## 与计划的一致性说明

- 这次实现严格对应 `阶段 2：抽出统一的 sequence 答案载体`
- 实际落地内容正好覆盖了计划里的这些点：
- 给 `ExerciseAnswerPayload` 增加 `.notePitch(NotePitch)`
- 引入 `ResolvedSequenceAnswer`
- 让 sequence 路由不再返回裸 `PitchClass`
- 在 trainer 侧新增 `resolvedSequenceAnswer(...)`，统一从 `pitchClass / fretboardCell / notePitch` 恢复 sequence 需要的语义
- `single` 与 `positionPrompt` 继续保持原有专用路由
- 这次没有越界进入 `阶段 3`，因为真正的 sequence comparator 还没有切到按 `answerPolicy` 分流
- 这次也没有越界进入 `阶段 5`，因为 piano 输入桥、SR-1 mode、`staffToPiano` scene 都还没有接通

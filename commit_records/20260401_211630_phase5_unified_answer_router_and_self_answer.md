# 20260401_211630_phase5_unified_answer_router_and_self_answer

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_211630`
- 记录范围：`场景树迁移` 计划的阶段 5；统一 answer router，并打通单 `fretboard` 自答
- 修改性质：新增 shared answer router；让 iOS/macOS 控制器改为统一路由答题；补 trainer 的事件解析与单 cell 答题入口；补交互开关与 validation
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. shared 层新增统一 `ExerciseAnswerRouter`

- 修改前：shared 层只有 `ExerciseAnswerEvent` 数据模型，没有真正的答题路由器；“哪个 surface 能答题、不同 mode 该怎么解释事件”都散落在平台控制器里。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名: 无
// 功能说明: 阶段 5 之前该文件不存在；shared 层还没有统一 answer router。
// 新增文件，无修改前实现。
```

- 修改后：新增 `ExerciseAnswerRouter`，先根据 `ExercisePresentationState.surfaceState(...)` 校验 surface 是否可答题，再把 `pitchClass` / `fretboardCell` 统一路由到 `singleCoverage`、`quarterNoteSequence`、`positionPrompt`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名: ExerciseAnswerRouteIgnoreReason.debugDescription, ExerciseAnswerRouter.route(...), ExerciseAnswerRouter.validateAnswerSurface(...)
// 功能说明: 修改后 shared 层先做 surface 可答题性校验，再把统一事件分派到各训练模式；单 fretboard 自答也从这里进入。
enum ExerciseAnswerRouteIgnoreReason: Equatable, Sendable {
    case surfaceUnavailable(ExerciseSurfaceID)
    case surfaceHidden(ExerciseSurfaceID)
    case answerDisabled(ExerciseSurfaceID)
    case interactionDisabled(ExerciseSurfaceID)
    case unsupportedPayload(
        ExerciseAnswerPayload,
        TrainerExerciseMode
    )
    case unresolvedPitchClass(
        FretboardCell,
        TrainerExerciseMode
    )

    var debugDescription: String {
        switch self {
        case let .surfaceUnavailable(surfaceID):
            return "surfaceUnavailable(\(surfaceID.rawValue))"
        case let .surfaceHidden(surfaceID):
            return "surfaceHidden(\(surfaceID.rawValue))"
        case let .answerDisabled(surfaceID):
            return "answerDisabled(\(surfaceID.rawValue))"
        case let .interactionDisabled(surfaceID):
            return "interactionDisabled(\(surfaceID.rawValue))"
        case let .unsupportedPayload(_, mode):
            return "unsupportedPayload(\(debugName(for: mode)))"
        case let .unresolvedPitchClass(cell, mode):
            return "unresolvedPitchClass(\(debugName(for: mode)),string=\(cell.stringIndex),fret=\(cell.fret))"
        }
    }

    private func debugName(for mode: TrainerExerciseMode) -> String {
        switch mode {
        case .single:
            return "single"
        case .sequence:
            return "sequence"
        case .positionPrompt:
            return "positionPrompt"
        }
    }
}

struct ExercisePositionPromptRoutedAnswer: Equatable, Sendable {
    var event: ExerciseAnswerEvent
    var pitchClass: PitchClass
}

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

enum ExerciseAnswerRoutingResult: Equatable, Sendable {
    case routed(ExerciseAnswerRoute)
    case ignored(ExerciseAnswerRouteIgnoreReason)
}

enum ExerciseAnswerRouter {
    static func route(
        _ event: ExerciseAnswerEvent,
        presentationState: ExercisePresentationState,
        trainerDisplayState: TrainerDisplayState,
        fretboardConfiguration: FretboardConfiguration
    ) -> ExerciseAnswerRoutingResult {
        if let ignoredReason = validateAnswerSurface(
            event.surfaceID,
            in: presentationState
        ) {
            return .ignored(ignoredReason)
        }

        switch trainerDisplayState.exerciseMode {
        case .single:
            guard let cell = event.payload.fretboardCell else {
                return .ignored(
                    .unsupportedPayload(
                        event.payload,
                        trainerDisplayState.exerciseMode
                    )
                )
            }
            return .routed(.singleCoverage(event: event, cell: cell))
        case .sequence:
            guard let pitchClass = FretboardNaturalNoteTrainerState
                .resolvedPitchClass(
                    from: event,
                    configuration: fretboardConfiguration
                ) else {
                if let cell = event.payload.fretboardCell {
                    return .ignored(
                        .unresolvedPitchClass(
                            cell,
                            trainerDisplayState.exerciseMode
                        )
                    )
                }
                return .ignored(
                    .unsupportedPayload(
                        event.payload,
                        trainerDisplayState.exerciseMode
                    )
                )
            }

            return .routed(
                .quarterNoteSequence(
                    event: event,
                    pitchClass: pitchClass
                )
            )
        case .positionPrompt:
            guard let pitchClass = FretboardNaturalNoteTrainerState
                .resolvedPositionPromptAnswerPitchClass(
                    from: event,
                    configuration: fretboardConfiguration,
                    answerRule: trainerDisplayState.positionPromptAnswerRule
                ) else {
                if let cell = event.payload.fretboardCell {
                    return .ignored(
                        .unresolvedPitchClass(
                            cell,
                            trainerDisplayState.exerciseMode
                        )
                    )
                }
                return .ignored(
                    .unsupportedPayload(
                        event.payload,
                        trainerDisplayState.exerciseMode
                    )
                )
            }

            return .routed(
                .positionPrompt(
                    ExercisePositionPromptRoutedAnswer(
                        event: event,
                        pitchClass: pitchClass
                    )
                )
            )
        }
    }

    private static func validateAnswerSurface(
        _ surfaceID: ExerciseSurfaceID,
        in presentationState: ExercisePresentationState
    ) -> ExerciseAnswerRouteIgnoreReason? {
        guard let surfaceState = presentationState.surfaceState(
            for: surfaceID
        ) else {
            return .surfaceUnavailable(surfaceID)
        }
        guard surfaceState.isVisible else {
            return .surfaceHidden(surfaceID)
        }
        guard surfaceState.isAnswerEnabled else {
            return .answerDisabled(surfaceID)
        }
        guard surfaceState.isInteractionEnabled else {
            return .interactionDisabled(surfaceID)
        }
        return nil
    }
}
```

## 2. `FretboardNaturalNoteTrainer` 从“分散入口”补成“统一事件可解析”

- 修改前：trainer 只能分别消费 `FretboardHitResult` 和 `PitchClass`。`single coverage` 没有“直接给 `FretboardCell`”的入口；`positionPrompt` 也只能吃已经被平台层解析好的 `PitchClass`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: handleSingleCoverageHit(...), handlePositionPromptAnswer(...)
// 功能说明: 修改前 trainer 入口按具体 view 事件分裂；single 只能吃 hitResult，positionPrompt 只能吃 pitchClass。
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

    // ... 其余 single coverage 评估逻辑省略
}

mutating func handlePositionPromptAnswer(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
    session: inout PositionPromptSession
) -> PositionPromptAnswerResult {
    var generator = SystemRandomNumberGenerator()
    return handlePositionPromptAnswer(
        pitchClass,
        configuration: configuration,
        filter: filter,
        session: &session,
        using: &generator
    )
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

    // ... 其余 positionPrompt 评估逻辑省略
}
```

- 修改后：`handleSingleCoverageHit(...)` 先把 `hitResult.cell` 收敛成统一的 `selectedCell`；新增 `handleSingleCoverageAnswer(...)`、`handlePositionPromptAnswer(_ event: ...)` 和 `resolvedPitchClass(...)`，把 `fretboardCell -> pitchClass` 的解释下沉到 shared trainer。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: handleSingleCoverageHit(...), handleSingleCoverageAnswer(...), handlePositionPromptAnswer(_ event: ...), resolvedPitchClass(...), resolvedPositionPromptAnswerPitchClass(...)
// 功能说明: 修改后 trainer 能直接消费统一 answer event；single 和 positionPrompt 都不再依赖平台层先手写解析。
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

    return handleSingleCoverageAnswer(
        selectedCell,
        configuration: configuration,
        session: &session,
        using: &generator
    )
}

mutating func handleSingleCoverageAnswer(
    _ selectedCell: FretboardCell,
    configuration: FretboardConfiguration,
    session: inout SingleCoverageSession
) -> SingleCoverageAnswerResult {
    var generator = SystemRandomNumberGenerator()
    return handleSingleCoverageAnswer(
        selectedCell,
        configuration: configuration,
        session: &session,
        using: &generator
    )
}

mutating func handlePositionPromptAnswer(
    _ event: ExerciseAnswerEvent,
    configuration: FretboardConfiguration,
    answerRule: PositionPromptAnswerRule,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
    session: inout PositionPromptSession
) -> PositionPromptAnswerResult? {
    guard let pitchClass = Self.resolvedPositionPromptAnswerPitchClass(
        from: event,
        configuration: configuration,
        answerRule: answerRule
    ) else {
        return nil
    }

    return handlePositionPromptAnswer(
        pitchClass,
        configuration: configuration,
        filter: filter,
        session: &session
    )
}

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

static func resolvedPositionPromptAnswerPitchClass(
    from event: ExerciseAnswerEvent,
    configuration: FretboardConfiguration,
    answerRule: PositionPromptAnswerRule
) -> PitchClass? {
    switch answerRule {
    case .samePitchClass:
        return resolvedPitchClass(
            from: event,
            configuration: configuration
        )
    }
}
```

## 3. iOS 控制器改为 `surface -> event -> router -> trainer`

- 修改前：`iOSViewController` 自己硬编码“哪个 view 才能答题”。`positionPrompt` 下的 `fretboard` 点击直接 `return`，`naturalNoteStrip` 仍是唯一答题入口。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: handleFretboardTrainerHitResult(...), handleNaturalNoteStripPitchClassTap(...), handlePositionPromptAnswer(...), handleSingleNaturalTargetHitResult(...), handleQuarterNoteSequenceHitResult(...)
// 功能说明: 修改前 iOS 控制器直接按 mode 分发事件；positionPrompt 的 fretboard 点击被硬编码丢弃。
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

private func handleNaturalNoteStripPitchClassTap(_ pitchClass: PitchClass) {
    switch fretboardTrainerState.mode {
    case .positionPrompt:
        handlePositionPromptAnswer(pitchClass)
    case .singleNaturalTarget, .quarterNoteSequence:
        return
    }
}

private func handlePositionPromptAnswer(_ pitchClass: PitchClass) {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return
    }

    // ... session 守卫逻辑省略

    let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
        pitchClass,
        configuration: displayState.configuration,
        filter: currentPositionPromptFilter,
        session: &positionPromptSession
    )

    // ... feedback / projection 逻辑省略
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: updateNaturalNoteStripInteractionState(...)
// 功能说明: 修改前只有 natural note strip 会跟随 surfaceState 控制交互；fretboard 没有统一 answer-surface 开关。
private func updateNaturalNoteStripInteractionState() {
    guard isViewLoaded else {
        return
    }

    let isInteractionEnabled = exercisePresentationState.surfaceState(
        for: .naturalNoteStrip
    )?.isInteractionEnabled ?? false

    if trainerDisplayState.isPositionPromptMode {
        naturalNoteStripView.isUserInteractionEnabled = isInteractionEnabled
            && currentPositionPromptOverlayPhase == .neutralWhite
    } else {
        naturalNoteStripView.isUserInteractionEnabled = isInteractionEnabled
    }
}
```

- 修改后：iOS 统一先组装 `ExerciseAnswerEvent`，再交给 `ExerciseAnswerRouter`。`single`、`sequence`、`positionPrompt` 都经同一条答题链路；同时把 `fretboard` 与 `naturalNoteStrip` 的交互能力都绑定到 `surfaceState.isInteractionEnabled`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: handleFretboardTrainerHitResult(...), handleNaturalNoteStripPitchClassTap(...), handleExerciseAnswerEvent(...), handleRoutedExerciseAnswer(...), handlePositionPromptAnswer(...), handleSingleCoverageAnswer(...), handleQuarterNoteSequenceAnswer(...)
// 功能说明: 修改后 iOS 控制器只负责把平台事件变成 ExerciseAnswerEvent，再把分发决策交给 shared router。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    guard hitResult.phase == .ended else {
        return
    }

    guard let selectedCell = hitResult.cell else {
        logIgnoredFretboardAnswerHitResultMissingCell()
        return
    }

    handleExerciseAnswerEvent(
        .fretboardCell(selectedCell, from: .fretboard)
    )
}

private func handleNaturalNoteStripPitchClassTap(_ pitchClass: PitchClass) {
    handleExerciseAnswerEvent(
        .pitchClass(pitchClass, from: .naturalNoteStrip)
    )
}

private func handleExerciseAnswerEvent(_ event: ExerciseAnswerEvent) {
    switch ExerciseAnswerRouter.route(
        event,
        presentationState: exercisePresentationState,
        trainerDisplayState: trainerDisplayState,
        fretboardConfiguration: displayState.configuration
    ) {
    case let .routed(route):
        handleRoutedExerciseAnswer(route)
    case let .ignored(reason):
        logIgnoredExerciseAnswerEvent(event, reason: reason)
    }
}

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

private func handlePositionPromptAnswer(
    _ routedAnswer: ExercisePositionPromptRoutedAnswer
) {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return
    }

    // ... session 守卫逻辑省略

    guard let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
        routedAnswer.event,
        configuration: displayState.configuration,
        answerRule: trainerDisplayState.positionPromptAnswerRule,
        filter: currentPositionPromptFilter,
        session: &positionPromptSession
    ) else {
        print(
            "[PositionPrompt][iOS] result=ignored reason=unresolvedAnswerEvent surface=\(routedAnswer.event.surfaceID.rawValue)"
        )
        return
    }

    // ... feedback / projection 逻辑省略
}

private func handleSingleCoverageAnswer(_ selectedCell: FretboardCell) {
    // ... session 守卫逻辑省略
    let answerResult = fretboardTrainerState.handleSingleCoverageAnswer(
        selectedCell,
        configuration: displayState.configuration,
        session: &singleCoverageSession
    )
    // ... projection / 日志逻辑省略
}

private func handleQuarterNoteSequenceAnswer(
    _ event: ExerciseAnswerEvent,
    pitchClass: PitchClass
) {
    // ... sequence 守卫逻辑省略
    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        pitchClass,
        session: &quarterNoteSequenceSession
    )

    let selectedCell = event.payload.fretboardCell
    let selectedPitch = selectedCell.flatMap {
        displayState.configuration.notePitch(for: $0)
    }

    // ... projection / 日志逻辑省略
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: updateAnswerSurfaceInteractionState(...)
// 功能说明: 修改后 iOS 同时控制 fretboard 与 natural note strip 的答题交互，并把 positionPrompt 的反馈动画阶段也并入统一开关。
private func updateAnswerSurfaceInteractionState() {
    guard isViewLoaded else {
        return
    }

    let allowsLiveAnswerInteraction = !trainerDisplayState.isPositionPromptMode
        || currentPositionPromptOverlayPhase == .neutralWhite
    let fretboardInteractionEnabled = exercisePresentationState.surfaceState(
        for: .fretboard
    )?.isInteractionEnabled ?? false
    let naturalNoteStripInteractionEnabled = exercisePresentationState.surfaceState(
        for: .naturalNoteStrip
    )?.isInteractionEnabled ?? false

    fretboardView.isUserInteractionEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.isUserInteractionEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
}
```

## 4. macOS 控制器与 `macOSFretboardView` 同步切到统一答题入口

- 修改前：`macOSViewController` 与 iOS 一样，`positionPrompt` 下对 `fretboard` 直接 `return`；`macOSFretboardView` 也没有可以从外部关闭原始鼠标事件的开关。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: handleFretboardTrainerHitResult(...), handleNaturalNoteStripPitchClassTap(...), handlePositionPromptAnswer(...), updateNaturalNoteStripInteractionState(...)
// 功能说明: 修改前 macOS 控制器与 iOS 同构，事件分发与交互控制都还是平台内硬编码。
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

private func handleNaturalNoteStripPitchClassTap(_ pitchClass: PitchClass) {
    switch fretboardTrainerState.mode {
    case .positionPrompt:
        handlePositionPromptAnswer(pitchClass)
    case .singleNaturalTarget, .quarterNoteSequence:
        return
    }
}

private func updateNaturalNoteStripInteractionState() {
    guard isViewLoaded else {
        return
    }

    let isInteractionEnabled = exercisePresentationState.surfaceState(
        for: .naturalNoteStrip
    )?.isInteractionEnabled ?? false

    if trainerDisplayState.isPositionPromptMode {
        naturalNoteStripView.areButtonsEnabled = isInteractionEnabled
            && currentPositionPromptOverlayPhase == .neutralWhite
    } else {
        naturalNoteStripView.areButtonsEnabled = isInteractionEnabled
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名: mouseDown(...), mouseDragged(...), mouseUp(...)
// 功能说明: 修改前 macOS fretboard view 只要收到鼠标事件就一律往外抛，没有 answer-surface 开关。
var onRawEvent: ((FretboardHitResult) -> Void)?

override func mouseDown(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .began)
}

override func mouseDragged(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .moved)
}

override func mouseUp(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .ended)
}
```

- 修改后：macOS 也统一收口到 `ExerciseAnswerRouter`；同时 `macOSFretboardView` 新增 `areRawEventsEnabled`，让 prompt-only surface 在 AppKit 层就不再继续发答题事件。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: handleFretboardTrainerHitResult(...), handleNaturalNoteStripPitchClassTap(...), handleExerciseAnswerEvent(...), handleRoutedExerciseAnswer(...), updateAnswerSurfaceInteractionState(...)
// 功能说明: 修改后 macOS 控制器与 iOS 对齐；surface 只负责发统一事件，shared router 决定这次答题是否有效。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    guard hitResult.phase == .ended else {
        return
    }

    guard let selectedCell = hitResult.cell else {
        logIgnoredFretboardAnswerHitResultMissingCell()
        return
    }

    handleExerciseAnswerEvent(
        .fretboardCell(selectedCell, from: .fretboard)
    )
}

private func handleNaturalNoteStripPitchClassTap(_ pitchClass: PitchClass) {
    handleExerciseAnswerEvent(
        .pitchClass(pitchClass, from: .naturalNoteStrip)
    )
}

private func handleExerciseAnswerEvent(_ event: ExerciseAnswerEvent) {
    switch ExerciseAnswerRouter.route(
        event,
        presentationState: exercisePresentationState,
        trainerDisplayState: trainerDisplayState,
        fretboardConfiguration: displayState.configuration
    ) {
    case let .routed(route):
        handleRoutedExerciseAnswer(route)
    case let .ignored(reason):
        logIgnoredExerciseAnswerEvent(event, reason: reason)
    }
}

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

private func updateAnswerSurfaceInteractionState() {
    guard isViewLoaded else {
        return
    }

    let allowsLiveAnswerInteraction = !trainerDisplayState.isPositionPromptMode
        || currentPositionPromptOverlayPhase == .neutralWhite
    let fretboardInteractionEnabled = exercisePresentationState.surfaceState(
        for: .fretboard
    )?.isInteractionEnabled ?? false
    let naturalNoteStripInteractionEnabled = exercisePresentationState.surfaceState(
        for: .naturalNoteStrip
    )?.isInteractionEnabled ?? false

    fretboardView.areRawEventsEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.areButtonsEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名: areRawEventsEnabled, mouseDown(...), mouseDragged(...), mouseUp(...)
// 功能说明: 修改后 macOS fretboard view 可以按 surfaceState 暂停原始鼠标事件，避免 prompt-only surface 继续冒出 answer event。
var onRawEvent: ((FretboardHitResult) -> Void)?
var areRawEventsEnabled = true

override func mouseDown(with event: NSEvent) {
    guard areRawEventsEnabled else {
        return
    }
    handleRawMouseEvent(event, phase: .began)
}

override func mouseDragged(with event: NSEvent) {
    guard areRawEventsEnabled else {
        return
    }
    handleRawMouseEvent(event, phase: .moved)
}

override func mouseUp(with event: NSEvent) {
    guard areRawEventsEnabled else {
        return
    }
    handleRawMouseEvent(event, phase: .ended)
}
```

## 5. validation 从“事件载荷契约”扩到“上下 / 左右 / 单区路由语义”

- 修改前：validation 只验证 `PositionPromptAnswerRule.default == .samePitchClass`，以及 `ExerciseAnswerEvent` 会保留 payload；还没有任何夹具锁定 `stacked` / `sideBySide` / `singleSurface self-answer` 的答题路由行为。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures(), validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass()
// 功能说明: 修改前阶段 5 的 router 语义夹具不存在，validation 只停留在 shared answer contract 的基础断言。
ExerciseCompositionValidationFixture(
    name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
    validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
)

static func validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "shared_answer_contracts_default_position_prompt_to_same_pitch_class"
    var issues: [ExerciseCompositionValidationIssue] = []

    let defaultConfiguration = TrainerPositionPromptConfiguration.default
    if defaultConfiguration.answerRule != .samePitchClass {
        issues.append(
            issue(
                fixtureName,
                "PositionPromptAnswerRule 首版默认值应为 samePitchClass。"
            )
        )
    }

    let fretboardCellEvent = ExerciseAnswerEvent.fretboardCell(
        FretboardCell(stringIndex: 2, fret: 3),
        from: .fretboard
    )
    let pitchClassEvent = ExerciseAnswerEvent.pitchClass(
        .c,
        from: .naturalNoteStrip
    )

    // ... 其余 shared answer contract 断言省略
}
```

- 修改后：新增 `answer_router_routes_stacked_side_and_single_surface_answers` 夹具，并把手工清单显式扩到“prompt-only fretboard 不得误答题”“单 fretboard 自答会推进下一题”。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改后 validation fixture 列表显式增加阶段 5 answer router 夹具，手工回归项也覆盖 stacked/side/single 三类答题语义。
ExerciseCompositionValidationFixture(
    name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
    validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
),
ExerciseCompositionValidationFixture(
    name: "answer_router_routes_stacked_side_and_single_surface_answers",
    validate: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers
)

var checklist = [
    "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
    "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
    "确认把 `Layout Preset` 切到 `Side` 后，主视觉立即切成左右双栏，而不是被自动打回 `Stacked`。",
    "确认在 `positionPrompt` 里切到 `Composition Preset = Self` 后，页面收敛为单 `fretboard`，并且 settings 重新打开后该选择仍然保留。",
    "确认 stacked/side 的 `positionPrompt` 里，只有当前 answer surface 会响应答题；prompt-only 的 `fretboard` 点击不会误触发答题。",
    "确认单 `fretboard` 自答时，点击同音位置会走统一 answer router，并在正确反馈结束后推进到下一题。",
    // ... 其余阶段 4 既有回归项省略
]
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
// 功能说明: 修改后自动化夹具直接断言三种布局下的 answer router 输出，锁住“上下 / 左右 / 单 fretboard 自答”的统一答题时序。
static func validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "answer_router_routes_stacked_side_and_single_surface_answers"
    var issues: [ExerciseCompositionValidationIssue] = []
    let fretboardConfiguration = FretboardConfiguration()
    let answerCell = FretboardCell(stringIndex: 0, fret: 0)

    // ... 前置数据准备省略

    if ExerciseAnswerRouter.route(
        fretboardCellEvent,
        presentationState: stackedSinglePresentation,
        trainerDisplayState: singleTrainerDisplayState,
        fretboardConfiguration: fretboardConfiguration
    ) != .routed(
        .singleCoverage(
            event: fretboardCellEvent,
            cell: answerCell
        )
    ) {
        issues.append(
            issue(
                fixtureName,
                "上下布局中的单音训练应把 fretboardCell 事件路由到 singleCoverage answer。"
            )
        )
    }

    if ExerciseAnswerRouter.route(
        naturalNoteStripEvent,
        presentationState: sideBySidePositionPromptPresentation,
        trainerDisplayState: positionPromptTrainerDisplayState,
        fretboardConfiguration: fretboardConfiguration
    ) != .routed(
        .positionPrompt(
            ExercisePositionPromptRoutedAnswer(
                event: naturalNoteStripEvent,
                pitchClass: .e
            )
        )
    ) {
        issues.append(
            issue(
                fixtureName,
                "左右布局中的 positionPrompt 应允许 natural note strip 继续作为可选 answer surface。"
            )
        )
    }

    if ExerciseAnswerRouter.route(
        fretboardCellEvent,
        presentationState: stackedPositionPromptPresentation,
        trainerDisplayState: positionPromptTrainerDisplayState,
        fretboardConfiguration: fretboardConfiguration
    ) != .ignored(.answerDisabled(.fretboard)) {
        issues.append(
            issue(
                fixtureName,
                "stacked 的 positionPrompt 里，prompt-only fretboard 不应再被当成唯一答题入口。"
            )
        )
    }

    if ExerciseAnswerRouter.route(
        fretboardCellEvent,
        presentationState: selfAnswerPresentation,
        trainerDisplayState: positionPromptTrainerDisplayState,
        fretboardConfiguration: fretboardConfiguration
    ) != .routed(
        .positionPrompt(
            ExercisePositionPromptRoutedAnswer(
                event: fretboardCellEvent,
                pitchClass: answerPitchClass
            )
        )
    ) {
        issues.append(
            issue(
                fixtureName,
                "单 fretboard self-answer 应把 fretboardCell 解析成 pitch class，并继续路由到 positionPrompt answer。"
            )
        )
    }

    return issues
}
```

## 验证结果

- `ReadLints`
- 检查范围：`ExerciseAnswerRouter.swift`、`FretboardNaturalNoteTrainer.swift`、`iOSViewController.swift`、`macOSViewController.swift`、`macOSFretboardView.swift`、`ExerciseCompositionValidation.swift`
- 结果：`No linter errors found.`

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build`
- 结果：`BUILD SUCCEEDED`

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build`
- 结果：`BUILD SUCCEEDED`

- 构建备注：
- 两个平台构建都通过。
- 构建输出中仍可见 `SettingsNavigationValidation.swift` 的既有 MainActor warning；这不是本次阶段 5 新引入的问题，本次未处理。

## 过程中修正

- 无额外代码修正；阶段 5 的实现在本轮记录前已经完成并通过 lints 与双平台构建。

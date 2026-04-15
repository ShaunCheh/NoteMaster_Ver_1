# 20260415_204050_stage4_sr0_sequence_answer_feedback_chain

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_204050`
- 记录依据：基于当前工作区本轮阶段 4 改动相关文件的 `git status --short -- ...`、`git diff --stat -- ...`、按文件 `git diff`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` 验证结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr0_双行strip_计划_632caead.plan.md` 实施阶段 4 的真实落地代码改动；目标是把 `SR-0` 接入现有 `sequence` 答题与反馈链路里真正缺失的 shared answer router 接线，并补上 shared validation 回归夹具
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`2 files changed, 52 insertions(+), 8 deletions(-)`
- 统计口径说明：
- `git status --short -- "NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift" "NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift"` 只包含下面 2 个 `Swift` 文件
- 本记录文件本身是新增 markdown 记录，不计入上面的 `2 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- 本次确认但未修改的关键文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`：`resolvedSequenceAnswer(...)` 在本轮前就已经支持 `.pitchClass -> ResolvedSequenceAnswer(notePitch: nil)`，因此阶段 4 不需要新增 comparator，也不需要新增 answer carrier
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 上面两个 controller 在阶段 3 已经把 `.sr0` 纳入 `.sequence, .sr0, .sr1, .sr2` 的 quarter-note sequence presentation 同步分支；本轮未再重复改动
- 验证结果：
- `ReadLints`：对本轮 2 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMasterSR0Stage4-mac-build" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" -derivedDataPath "/tmp/NoteMasterSR0Stage4-ios-build" build`：`BUILD SUCCEEDED`
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr0_双行strip_计划_632caead.plan.md`
- 没有新增 settings 中的 `SR-0` 模式入口或 navigation 可见性规则
- 没有修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 没有新增 runtime smoke
- 没有提交代码

## 本次结论

- `SR-0` 不再在 `ExerciseAnswerRouter` 里被当作阶段占位的 `unsupportedPayload` 模式
- `SR-0` 下双行 `natural note strip` 发出的 `pitchClass` 事件，现在会和 `sequence / sr1 / sr2` 一样被路由为 `quarterNoteSequence`
- shared validation 现在补上了 `SR-0` 的 answer-router 回归断言，锁定 `pitchClass-only` 的 sequence answer 载体，以及 `SR-0` 主场景缺少 `fretboard` 时的 `surfaceUnavailable(.fretboard)` 边界

## 修改 1：把 `SR-0` 并入现有 `quarterNoteSequence` 路由

### 修改前

- `ExerciseAnswerRouter.route(...)` 里的 `sequence` 分支只包含 `.sequence, .sr1, .sr2`
- `.sr0` 仍然作为单独 case 直接返回 `.ignored(.unsupportedPayload(...))`
- 结果是 `SR-0` 场景里的 `naturalNoteStrip` 点击虽然已经能产生 `ExerciseAnswerEvent.pitchClass(..., from: .naturalNoteStrip)`，但还进不了 shared sequence 判题链

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: ExerciseAnswerRouter.route
// 功能说明: 修改前 `sr0` 还是阶段边界占位；
// 它没有并入 quarter-note sequence 路由，而是被直接忽略为 unsupportedPayload。
switch trainerDisplayState.exerciseMode {
case .single:
    // ... 省略未变的 singleCoverage 路由 ...
case .sequence, .sr1, .sr2:
    guard let answer = FretboardNaturalNoteTrainerState
        .resolvedSequenceAnswer(
            from: event,
            configuration: fretboardConfiguration
        ) else {
        // ... 省略未变的 unresolved / unsupported 分支 ...
    }

    return .routed(
        .quarterNoteSequence(
            event: event,
            answer: answer
        )
    )
case .sr0:
    return .ignored(
        .unsupportedPayload(
            event.payload,
            trainerDisplayState.exerciseMode
        )
    )
case .positionPrompt:
    // ... 省略未变的 positionPrompt 路由 ...
}
```

### 修改后

- `ExerciseAnswerRouter.route(...)` 把 `.sr0` 合并进 `.sequence, .sr0, .sr1, .sr2`
- `SR-0` 正式复用既有 `FretboardNaturalNoteTrainerState.resolvedSequenceAnswer(...)`
- 对 `naturalNoteStrip` 来说，这条路由会保留 `pitchClass`，并把 `notePitch` 维持为 `nil`，正好符合阶段 4 目标

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: ExerciseAnswerRouter.route
// 功能说明: 修改后 `sr0` 正式与 `sequence / sr1 / sr2` 共用 quarter-note sequence 路由；
// 这样双行 natural note strip 的 pitchClass 输入会进入现有 shared 判题链。
switch trainerDisplayState.exerciseMode {
case .single:
    // ... 省略未变的 singleCoverage 路由 ...
case .sequence, .sr0, .sr1, .sr2:
    guard let answer = FretboardNaturalNoteTrainerState
        .resolvedSequenceAnswer(
            from: event,
            configuration: fretboardConfiguration
        ) else {
        // ... 省略未变的 unresolved / unsupported 分支 ...
    }

    return .routed(
        .quarterNoteSequence(
            event: event,
            answer: answer
        )
    )
case .positionPrompt:
    // ... 省略未变的 positionPrompt 路由 ...
}
```

## 修改 2：为 `SR-0` 补 answer-router shared validation 回归夹具

### 修改前

- `validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()` 已覆盖：
- stacked `single`
- stacked `sequence`
- side-by-side / stacked `positionPrompt`
- single-surface `fretboard self-answer`
- 但还没有任何 `SR-0` 场景下的 answer-router 回归断言

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers
// 功能说明: 修改前这个夹具只验证 single / sequence / positionPrompt / self-answer；
// `stackedPositionPromptPresentation` 之后会直接进入 `selfAnswerPresentation`，中间没有 `SR-0` 断言。
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

let selfAnswerPresentation = ExerciseCompositionPolicy.makePresentation(
    from: ExerciseCompositionPolicyInput(
        trainerDisplayState: positionPromptTrainerDisplayState,
        fretboardTrainerState: .init(positionPromptMode: ()),
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pianoPanelState: .init(),
        layoutPreferences: .singleFretboardSelfAnswer
    )
)
```

### 修改后

- 在同一个 shared validation 夹具里新增了 `SR-0` 场景输入断言
- 第一条断言验证：`naturalNoteStrip` 的 `.pitchClass(.e)` 会被路由为 `.quarterNoteSequence(... ResolvedSequenceAnswer(notePitch: nil) ...)`
- 第二条断言验证：`SR-0` 主场景没有 `fretboard` 时，`fretboardCell` 事件仍然必须是 `.ignored(.surfaceUnavailable(.fretboard))`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers
// 功能说明: 修改后同一个夹具新增了 `SR-0` answer-router 回归检查；
// 它同时锁住正确路由的正向路径，以及错误 surface 输入时的边界行为。
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

let sr0TrainerDisplayState = TrainerDisplayState(exerciseMode: .sr0)
let stackedSR0Presentation = ExerciseCompositionPolicy.makePresentation(
    from: ExerciseCompositionPolicyInput(
        trainerDisplayState: sr0TrainerDisplayState,
        fretboardTrainerState: .init(
            quarterNoteSequenceSpec: sr0TrainerDisplayState
                .resolvedSequenceConfiguration
                .quarterNoteSequenceSpec
        ),
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pianoPanelState: .init(),
        layoutPreferences: .srNoteStripAnswer
    )
)
if ExerciseAnswerRouter.route(
    naturalNoteStripEvent,
    presentationState: stackedSR0Presentation,
    trainerDisplayState: sr0TrainerDisplayState,
    fretboardConfiguration: fretboardConfiguration
) != .routed(
    .quarterNoteSequence(
        event: naturalNoteStripEvent,
        answer: ResolvedSequenceAnswer(
            pitchClass: .e,
            notePitch: nil,
            surfaceID: .naturalNoteStrip
        )
    )
) {
    issues.append(
        issue(
            fixtureName,
            "SR-0 的双行 natural note strip 点击应继续路由到 quarterNoteSequence，并保持 pitchClass-only 的 sequence 答案载体。"
        )
    )
}
if ExerciseAnswerRouter.route(
    fretboardCellEvent,
    presentationState: stackedSR0Presentation,
    trainerDisplayState: sr0TrainerDisplayState,
    fretboardConfiguration: fretboardConfiguration
) != .ignored(.surfaceUnavailable(.fretboard)) {
    issues.append(
        issue(
            fixtureName,
            "SR-0 主场景不包含 fretboard 时，fretboardCell 事件应继续被判定为 surfaceUnavailable，而不是误路由到 sequence 答题链。"
        )
    )
}

let selfAnswerPresentation = ExerciseCompositionPolicy.makePresentation(
    from: ExerciseCompositionPolicyInput(
        trainerDisplayState: positionPromptTrainerDisplayState,
        fretboardTrainerState: .init(positionPromptMode: ()),
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pianoPanelState: .init(),
        layoutPreferences: .singleFretboardSelfAnswer
    )
)
```

## 本次确认但未改动的现成链路

- 这部分不是本轮新增代码，但它解释了为什么阶段 4 最终只需要改 `router + validation`
- 第一段代码说明：shared trainer 内核早就支持把 `pitchClass` 事件解析成 `ResolvedSequenceAnswer(notePitch: nil)`
- 第二段代码说明：`iOSViewController` 在阶段 3 已经把 `.sr0` 接进 quarter-note sequence 的 presentation 同步分支；`macOSViewController` 与它保持同构，因此这次无须再改 controller 才能让 `SR-0` 生效

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: FretboardNaturalNoteTrainerState.resolvedSequenceAnswer
// 功能说明: 这段代码在阶段 4 之前就已经存在；
// 它说明 SR-0 不需要新增 comparator，也不需要新建 answer carrier。
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: iOSViewController.synchronizeTrainerPresentationState
// 功能说明: 这段代码同样来自阶段 3；
// 它说明 controller 的 quarter-note sequence presentation 同步入口早已覆盖 `sr0`。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence, .sr0, .sr1, .sr2:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}
```

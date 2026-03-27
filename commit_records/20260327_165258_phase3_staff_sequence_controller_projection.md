# 20260327_165258_phase3_staff_sequence_controller_projection

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_165258`
- 记录范围：实施 `staff序列反馈` 计划的阶段 3，把 iOS/macOS controller 中的 `session.currentIndex + lastEvaluation` 真实投影到 `StaffDisplayState.sequencePresentation`
- 本次目标：让阶段 1/2 已经准备好的 shared sequence 渲染语义，真正被双端 controller 驱动起来，从而让 staff 显示当前游标与红绿反馈
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 阶段 2 之后，`StaffSceneBuilder` 已经能够消费 `StaffSequencePresentation`，并生成竖线游标与红绿反馈，但 controller 还没有把 `currentIndex` 与 `lastEvaluation` 传进去，所以实际界面仍然看不到效果。
- 单靠 `quarterNoteSequenceSession.currentIndex` 不足以表达“刚答错但游标不前进”的状态，因此 controller 必须显式保存最近一次判题结果。
- 阶段 3 的根因级修复因此是：
- 在 controller 中新增 `quarterNoteSequenceLastEvaluation`
- 用 shared helper 把 `totalCount + currentIndex + lastEvaluation` 收敛映射为 `StaffSequencePresentation`
- 在所有 sequence projection 与重置入口统一更新这份状态

## 修改 1：在 `StaffScene.swift` 中补一个 shared 映射 helper，统一把进度状态转成展示语义

### 修改前

- `StaffSequencePresentation` 虽然已经有 `.idle / .wrong / .correct / .completed`
- 但 controller 还需要自己决定什么时候用哪一种，容易在 iOS/macOS 上各写一套映射逻辑

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 类型/函数: StaffSequencePresentation.idle(...), wrong(...), correct(...), completed(...)
// 功能说明: 修改前 shared 层只提供了若干状态构造器；
// controller 还没有一个统一入口可以把 currentIndex + lastEvaluation 映射成展示语义。
struct StaffSequencePresentation: Equatable, Sendable {
    static func idle(cursorIndex: Int) -> Self {
        StaffSequencePresentation(
            state: .idle,
            cursorIndex: cursorIndex,
            lastEvaluatedIndex: nil,
            lastEvaluationResult: nil
        )
    }

    static func wrong(
        cursorIndex: Int,
        evaluatedIndex: Int
    ) -> Self { ... }

    static func correct(
        cursorIndex: Int,
        evaluatedIndex: Int
    ) -> Self { ... }

    static func completed(
        lastEvaluatedIndex: Int? = nil,
        lastEvaluationResult: StaffSequenceEvaluationResult? = nil
    ) -> Self { ... }
}
```

### 修改后

- 新增 `StaffSequencePresentation.fromProgress(...)`
- controller 只需要传 `totalCount / currentIndex / lastEvaluatedIndex / lastEvaluationResult`
- `idle / wrong / correct / completed` 的选择规则统一收口在 shared 层

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 类型/函数: StaffSequencePresentation.fromProgress(...)
// 功能说明: 修改后 shared 层统一负责把 session 进度和最近一次判题结果映射成展示状态，
// 避免 iOS/macOS 各自实现一套 idle/wrong/correct/completed 判定。
extension StaffSequencePresentation {
    static func fromProgress(
        totalCount: Int,
        currentIndex: Int,
        lastEvaluatedIndex: Int? = nil,
        lastEvaluationResult: StaffSequenceEvaluationResult? = nil
    ) -> Self? {
        guard totalCount > 0 else {
            assertionFailure(
                "Staff sequence presentation requires a positive totalCount."
            )
            return nil
        }

        precondition(
            currentIndex >= 0 && currentIndex <= totalCount,
            "Staff sequence currentIndex must stay within 0...totalCount."
        )
        precondition(
            (lastEvaluatedIndex == nil) == (lastEvaluationResult == nil),
            "Staff sequence progress must provide both lastEvaluatedIndex and lastEvaluationResult together."
        )

        if currentIndex >= totalCount {
            return .completed(
                lastEvaluatedIndex: lastEvaluatedIndex,
                lastEvaluationResult: lastEvaluationResult
            )
        }

        guard let lastEvaluatedIndex, let lastEvaluationResult else {
            return .idle(cursorIndex: currentIndex)
        }

        switch lastEvaluationResult {
        case .correct:
            return .correct(
                cursorIndex: currentIndex,
                evaluatedIndex: lastEvaluatedIndex
            )
        case .incorrect:
            return .wrong(
                cursorIndex: currentIndex,
                evaluatedIndex: lastEvaluatedIndex
            )
        }
    }
}
```

## 修改 2：iOS controller 显式保存最近一次 sequence 判题结果

### 修改前

- `iOSViewController` 只有 `quarterNoteSequenceSession`
- `currentQuarterNoteSequenceTargetPromptContent` 只能驱动 prompt 的当前步
- staff 还拿不到“最近一次答题对错”

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: quarterNoteSequenceSession, currentQuarterNoteSequenceTargetPromptContent
// 功能说明: 修改前 iOS 只有 session 进度，没有 lastEvaluation 真相源；
// 因此无法把“刚答错 / 刚答对”的状态投影给 staff。
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?

private var currentQuarterNoteSequenceTargetPromptContent: TargetPromptContent? {
    guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
        return nil
    }

    if let quarterNoteSequenceSession,
       quarterNoteSequenceSession.generatedSequence == generatedSequence {
        return quarterNoteSequenceSession.targetPromptContent()
    }

    return generatedSequence.targetPromptContent()
}
```

### 修改后

- 新增 `quarterNoteSequenceLastEvaluation`
- 新增 `currentQuarterNoteSequenceStaffPresentation(for:)`
- 通过 shared `fromProgress(...)` 映射出当前 staff 该显示的展示语义

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: quarterNoteSequenceLastEvaluation, currentQuarterNoteSequenceStaffPresentation(for:)
// 功能说明: 修改后 iOS controller 显式保存最近一次 sequence 判题结果，
// 并把 session 进度与 lastEvaluation 收口映射成 StaffSequencePresentation。
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?
private var quarterNoteSequenceLastEvaluation: FretboardNaturalNoteTrainerState.QuarterNoteSequenceEvaluation?

private func currentQuarterNoteSequenceStaffPresentation(
    for generatedSequence: GeneratedNoteSequence
) -> StaffSequencePresentation? {
    if let quarterNoteSequenceSession,
       quarterNoteSequenceSession.generatedSequence == generatedSequence {
        return StaffSequencePresentation.fromProgress(
            totalCount: quarterNoteSequenceSession.totalCount,
            currentIndex: quarterNoteSequenceSession.currentIndex,
            lastEvaluatedIndex: quarterNoteSequenceLastEvaluation?.answeredIndex,
            lastEvaluationResult: quarterNoteSequenceLastEvaluation.map {
                $0.isCorrect ? .correct : .incorrect
            }
        )
    }

    return StaffSequencePresentation.fromProgress(
        totalCount: generatedSequence.noteCount,
        currentIndex: 0
    )
}
```

## 修改 3：iOS 在作答、重建 session、切模式、重新生成时统一维护 lastEvaluation

### 修改前

- `handleQuarterNoteSequenceHitResult(...)` 只推进 session，然后直接刷新 projection
- `applyFretboardTrainerPrompt(...)`、`synchronizeSingleTrainerPresentation(...)`、`regenerateQuarterNoteSequence(...)` 只清 `quarterNoteSequenceSession`
- 一旦引入红绿反馈，这些入口都会存在状态泄漏风险

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: handleQuarterNoteSequenceHitResult(...), applyFretboardTrainerPrompt(...),
// synchronizeSingleTrainerPresentation(...), regenerateQuarterNoteSequence(...)
// 功能说明: 修改前 iOS 没有 lastEvaluation 生命周期管理；
// sequence 切换、重新生成和单音模式恢复时也不会清理这份状态。
if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
    quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
}

let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
    selectedPitch.pitchClass,
    session: &quarterNoteSequenceSession
)
self.quarterNoteSequenceSession = quarterNoteSequenceSession
applyQuarterNoteSequenceProjection(
    generatedSequence,
    reason: "answered",
    showsLog: false
)

private func applyFretboardTrainerPrompt(reason: String) {
    quarterNoteSequenceSession = nil
    ...
}
```

### 修改后

- session 因序列变化而重建时，立即清 `quarterNoteSequenceLastEvaluation`
- 命中后如果拿到 `.evaluated(evaluation)`，就把 evaluation 存起来
- 切回 single、重新生成序列、恢复单目标 prompt 时，也会统一清理

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: handleQuarterNoteSequenceHitResult(...), applyFretboardTrainerPrompt(...),
// synchronizeSingleTrainerPresentation(...), regenerateQuarterNoteSequence(...)
// 功能说明: 修改后 iOS 把 lastEvaluation 的写入与清理都收口到 controller，
// 避免旧红绿状态泄漏到新序列或单音模式。
if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
    quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    quarterNoteSequenceLastEvaluation = nil
}

let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
    selectedPitch.pitchClass,
    session: &quarterNoteSequenceSession
)
self.quarterNoteSequenceSession = quarterNoteSequenceSession
if case let .evaluated(evaluation) = answerResult {
    quarterNoteSequenceLastEvaluation = evaluation
}
applyQuarterNoteSequenceProjection(
    generatedSequence,
    reason: "answered",
    showsLog: false
)

private func applyFretboardTrainerPrompt(reason: String) {
    quarterNoteSequenceSession = nil
    quarterNoteSequenceLastEvaluation = nil
    ...
}

private func synchronizeSingleTrainerPresentation(reason: String) {
    ...
    quarterNoteSequenceSession = nil
    quarterNoteSequenceLastEvaluation = nil
    ...
}

private func regenerateQuarterNoteSequence(reason: String) {
    ...
    quarterNoteSequenceSession = nil
    quarterNoteSequenceLastEvaluation = nil
    synchronizeTrainerPresentationState(reason: reason)
}
```

## 修改 4：iOS 的 sequence projection 与 settings 归一化现在会真正把展示状态投给 staff

### 修改前

- `applyQuarterNoteSequenceProjection(...)` 只调用 `apply(generatedSequence:)`
- `normalizeSettingsPanelStateContextForTrainerMode(...)` 也只同步 `generatedSequence`
- `baseStaffDisplayState` 在 sequence 模式下保存前不会清除临时展示状态

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyQuarterNoteSequenceProjection(...),
// normalizeSettingsPanelStateContextForTrainerMode(...), handleSettingsPanelEvent(...)
// 功能说明: 修改前 iOS 只把 generatedSequence 投给 staff，
// 而当前游标和最近一次判题结果仍然停留在 controller 里。
var nextStaffDisplayState = staffDisplayState
nextStaffDisplayState.apply(generatedSequence: generatedSequence)

if let currentGeneratedQuarterNoteSequence {
    stateContext.staffDisplayState.apply(
        generatedSequence: currentGeneratedQuarterNoteSequence
    )
}

if nextTrainerDisplayState.isSequenceMode,
   nextRequestedStaffDisplayState != staffDisplayState {
    baseStaffDisplayState = nextRequestedStaffDisplayState
}
```

### 修改后

- projection 时显式传入 `sequencePresentation`
- settings 归一化时也保持相同投影规则
- 保存 `baseStaffDisplayState` 前先 `clearSequencePresentation()`，避免恢复单音模式时把旧 feedback 带回去

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyQuarterNoteSequenceProjection(...),
// normalizeSettingsPanelStateContextForTrainerMode(...), handleSettingsPanelEvent(...)
// 功能说明: 修改后 iOS 的 prompt / staff / session 使用同一份 sequence 投影真相源。
var nextStaffDisplayState = staffDisplayState
nextStaffDisplayState.apply(
    generatedSequence: generatedSequence,
    sequencePresentation: currentQuarterNoteSequenceStaffPresentation(
        for: generatedSequence
    )
)

if let currentGeneratedQuarterNoteSequence {
    stateContext.staffDisplayState.apply(
        generatedSequence: currentGeneratedQuarterNoteSequence,
        sequencePresentation: currentQuarterNoteSequenceStaffPresentation(
            for: currentGeneratedQuarterNoteSequence
        )
    )
}

if nextTrainerDisplayState.isSequenceMode,
   nextRequestedStaffDisplayState != staffDisplayState {
    var nextBaseStaffDisplayState = nextRequestedStaffDisplayState
    nextBaseStaffDisplayState.clearSequencePresentation()
    baseStaffDisplayState = nextBaseStaffDisplayState
}
```

## 修改 5：macOS controller 对称接入同一套状态与投影逻辑

### 修改前

- `macOSViewController` 与 iOS 一样，只有 `quarterNoteSequenceSession`
- 也同样只把 `generatedSequence` 投给 staff
- 因此 macOS 侧仍然没有驱动 shared 的 sequence 游标与红绿反馈

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: quarterNoteSequenceSession, applyQuarterNoteSequenceProjection(...)
// 功能说明: 修改前 macOS 与 iOS 一样，只同步 sequence 内容，不同步 sequence 展示语义。
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?

var nextStaffDisplayState = staffDisplayState
nextStaffDisplayState.apply(generatedSequence: generatedSequence)
```

### 修改后

- 新增 `quarterNoteSequenceLastEvaluation`
- 新增 `currentQuarterNoteSequenceStaffPresentation(for:)`
- 作答推进、session 重建、模式切换、重新生成、settings 归一化与 `baseStaffDisplayState` 清理，全部与 iOS 对称

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: quarterNoteSequenceLastEvaluation,
// currentQuarterNoteSequenceStaffPresentation(for:), applyQuarterNoteSequenceProjection(...)
// 功能说明: 修改后 macOS 与 iOS 对称使用同一套 sequence staff 投影规则。
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?
private var quarterNoteSequenceLastEvaluation: FretboardNaturalNoteTrainerState.QuarterNoteSequenceEvaluation?

private func currentQuarterNoteSequenceStaffPresentation(
    for generatedSequence: GeneratedNoteSequence
) -> StaffSequencePresentation? {
    if let quarterNoteSequenceSession,
       quarterNoteSequenceSession.generatedSequence == generatedSequence {
        return StaffSequencePresentation.fromProgress(
            totalCount: quarterNoteSequenceSession.totalCount,
            currentIndex: quarterNoteSequenceSession.currentIndex,
            lastEvaluatedIndex: quarterNoteSequenceLastEvaluation?.answeredIndex,
            lastEvaluationResult: quarterNoteSequenceLastEvaluation.map {
                $0.isCorrect ? .correct : .incorrect
            }
        )
    }

    return StaffSequencePresentation.fromProgress(
        totalCount: generatedSequence.noteCount,
        currentIndex: 0
    )
}

var nextStaffDisplayState = staffDisplayState
nextStaffDisplayState.apply(
    generatedSequence: generatedSequence,
    sequencePresentation: currentQuarterNoteSequenceStaffPresentation(
        for: generatedSequence
    )
)
```

## 本阶段结果

- iOS/macOS controller 现在都会显式保存最近一次 sequence 判题结果
- `session.currentIndex + lastEvaluation` 已经通过 shared helper 映射成 `StaffSequencePresentation`
- `applyQuarterNoteSequenceProjection(...)` 与 settings 归一化入口现在都会把这份展示状态投给 staff
- `baseStaffDisplayState` 会在 sequence 模式下去除临时展示语义后再保存，避免切回 single 时残留旧游标或旧红绿状态
- 到这一阶段为止，stage 1/2/3 的链路已经打通：只要当前页面显示的是 staff，sequence 模式下就能由 controller 驱动共享 scene 呈现游标与反馈

## 验证情况

- 已对下列文件执行静态诊断检查，结果无 linter 错误：
- `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未执行 `xcodebuild` 全量编译；当前记录仅覆盖本次阶段 3 的 shared helper 与双端 controller 投影改动

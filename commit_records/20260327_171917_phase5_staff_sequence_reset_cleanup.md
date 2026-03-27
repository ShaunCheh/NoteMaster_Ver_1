# 20260327_171917_phase5_staff_sequence_reset_cleanup

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_171917`
- 记录范围：实施 `staff序列反馈` 计划的阶段 5，统一处理 sequence 反馈重置边界，防止旧红绿状态泄漏
- 本次目标：
- 在 `iOS/macOS` controller 中把 `quarterNoteSequenceSession` 与 `quarterNoteSequenceLastEvaluation` 的清理入口收口
- 让 `TopContent` 离开 `Staff` 时立即清空瞬时红绿反馈，并按当前序列进度重投影
- 在 `StaffValidation` 的手工回归清单里补“切到 `Target Prompt` 再切回 `Staff` 不应带回旧反馈”
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

## 根因结论

- 阶段 1 到阶段 4 已经把 `StaffSequencePresentation` 的 shared scene 语义、controller 投影和回归验证都接通了，但 controller 侧仍有一个状态分层问题：
- `quarterNoteSequenceSession` 是序列交互进度的真相源
- `quarterNoteSequenceLastEvaluation` 是只应在 `TopContent = Staff` 可见时才需要保留的瞬时红/绿反馈
- 修改前，这两类状态在多个入口里被直接手写 `= nil`，而 `currentQuarterNoteSequenceStaffPresentation(...)` 又始终读取 `quarterNoteSequenceLastEvaluation`，导致以下边界没有统一收口：
- 重新生成 sequence
- 切换 sequence spec
- 切回 `single` 模式
- `TopContent` 从 `Staff` 切到 `Target Prompt`
- `settings` 改写 `baseStaffDisplayState`
- 阶段 5 的根因级修复因此是三件事：
- 把“清空临时反馈”和“重置整段 sequence 会话”拆成明确 helper
- 让 staff scene 的 feedback 投影显式受 `TopContent == .staff` 约束
- 在 `pageDisplayState` 切走 `Staff` 顶部内容时统一清空旧反馈并重投影当前 sequence

## 修改 1：让 `StaffSequencePresentation` 只在 `TopContent = Staff` 时读取最近一次红绿反馈

### 修改前

- `currentQuarterNoteSequenceStaffPresentation(...)` 总是直接消费 `quarterNoteSequenceLastEvaluation`
- controller 没有 `isShowingStaffTopContent`
- 这意味着只要内存里还留着最近一次判题结果，staff scene 就会继续带着旧红/绿反馈投影

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: currentQuarterNoteSequenceStaffPresentation(...)
// 功能说明: 修改前 iOS staff sequence 投影不区分顶部当前是否正在显示 Staff，
// 只要 lastEvaluation 还在，就会继续把红/绿反馈带进 shared scene。
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

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: currentQuarterNoteSequenceStaffPresentation(...)
// 功能说明: 修改前 macOS 与 iOS 对称，staff 展示状态同样始终读取 lastEvaluation，
// 没有把顶部内容可见性纳入反馈投影条件。
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

### 修改后

- 新增 `isShowingStaffTopContent`
- `currentQuarterNoteSequenceStaffPresentation(...)` 先把 `quarterNoteSequenceLastEvaluation` 收窄成 `staffVisibleLastEvaluation`
- 当顶部当前不是 `Staff` 时，scene 只保留 sequence 进度，不再带出旧红/绿状态

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: currentQuarterNoteSequenceStaffPresentation(...), isShowingStaffTopContent
// 功能说明: 修改后 iOS 只有在 TopContent 真正显示 Staff 时，
// 最近一次判题结果才会继续参与 shared scene 的 sequence feedback 投影。
private func currentQuarterNoteSequenceStaffPresentation(
    for generatedSequence: GeneratedNoteSequence
) -> StaffSequencePresentation? {
    let staffVisibleLastEvaluation = isShowingStaffTopContent
        ? quarterNoteSequenceLastEvaluation
        : nil
    if let quarterNoteSequenceSession,
       quarterNoteSequenceSession.generatedSequence == generatedSequence {
        return StaffSequencePresentation.fromProgress(
            totalCount: quarterNoteSequenceSession.totalCount,
            currentIndex: quarterNoteSequenceSession.currentIndex,
            lastEvaluatedIndex: staffVisibleLastEvaluation?.answeredIndex,
            lastEvaluationResult: staffVisibleLastEvaluation.map {
                $0.isCorrect ? .correct : .incorrect
            }
        )
    }

    return StaffSequencePresentation.fromProgress(
        totalCount: generatedSequence.noteCount,
        currentIndex: 0
    )
}

private var isShowingStaffTopContent: Bool {
    pageDisplayState.topContentMode == .staff
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: currentQuarterNoteSequenceStaffPresentation(...), isShowingStaffTopContent
// 功能说明: 修改后 macOS 与 iOS 保持对称，
// 顶部不显示 Staff 时不会把旧红/绿反馈继续投影回五线谱 scene。
private func currentQuarterNoteSequenceStaffPresentation(
    for generatedSequence: GeneratedNoteSequence
) -> StaffSequencePresentation? {
    let staffVisibleLastEvaluation = isShowingStaffTopContent
        ? quarterNoteSequenceLastEvaluation
        : nil
    if let quarterNoteSequenceSession,
       quarterNoteSequenceSession.generatedSequence == generatedSequence {
        return StaffSequencePresentation.fromProgress(
            totalCount: quarterNoteSequenceSession.totalCount,
            currentIndex: quarterNoteSequenceSession.currentIndex,
            lastEvaluatedIndex: staffVisibleLastEvaluation?.answeredIndex,
            lastEvaluationResult: staffVisibleLastEvaluation.map {
                $0.isCorrect ? .correct : .incorrect
            }
        )
    }

    return StaffSequencePresentation.fromProgress(
        totalCount: generatedSequence.noteCount,
        currentIndex: 0
    )
}

private var isShowingStaffTopContent: Bool {
    pageDisplayState.topContentMode == .staff
}
```

## 修改 2：把 sequence 会话状态与瞬时反馈状态收口为统一 helper，并接到页面切换边界

### 修改前

- `pageDisplayState.didSet` 只负责 `applyPageDisplayState()`
- `handleQuarterNoteSequenceHitResult(...)`、`applyFretboardTrainerPrompt(...)`、`synchronizeSingleTrainerPresentation(...)`、`synchronizeQuarterNoteSequencePresentation(...)`、`regenerateQuarterNoteSequence(...)` 中散落着多处 `quarterNoteSequenceSession = nil` / `quarterNoteSequenceLastEvaluation = nil`
- `handleSettingsPanelEvent(...)` 也直接内联 `clearSequencePresentation()`，没有统一的“去 sequence 污染”入口

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: pageDisplayState.didSet, handleQuarterNoteSequenceHitResult(...), applyFretboardTrainerPrompt(...), synchronizeSingleTrainerPresentation(...), synchronizeQuarterNoteSequencePresentation(...), regenerateQuarterNoteSequence(...), handleSettingsPanelEvent(...)
// 功能说明: 修改前 iOS 的 sequence 清理逻辑散落在多个调用点，
// 顶部内容离开 Staff 时也没有专门的反馈回收边界。
private var pageDisplayState = PageDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
    }
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    ...
    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        quarterNoteSequenceLastEvaluation = nil
    }
    ...
    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    if case let .evaluated(evaluation) = answerResult {
        quarterNoteSequenceLastEvaluation = evaluation
    }
    ...
}

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

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    ...
    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        quarterNoteSequenceLastEvaluation = nil
    }
    ...
}

private func regenerateQuarterNoteSequence(reason: String) {
    ...
    quarterNoteSequenceSession = nil
    quarterNoteSequenceLastEvaluation = nil
    ...
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    ...
    if nextTrainerDisplayState.isSequenceMode,
       nextRequestedStaffDisplayState != staffDisplayState {
        var nextBaseStaffDisplayState = nextRequestedStaffDisplayState
        nextBaseStaffDisplayState.clearSequencePresentation()
        baseStaffDisplayState = nextBaseStaffDisplayState
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: pageDisplayState.didSet, handleQuarterNoteSequenceHitResult(...), applyFretboardTrainerPrompt(...), synchronizeSingleTrainerPresentation(...), synchronizeQuarterNoteSequencePresentation(...), regenerateQuarterNoteSequence(...), handleSettingsPanelEvent(...)
// 功能说明: 修改前 macOS controller 与 iOS 相同，
// sequence 状态清理散落在多个入口，没有统一处理顶部内容切换的反馈回收。
private var pageDisplayState = PageDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
    }
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    ...
    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        quarterNoteSequenceLastEvaluation = nil
    }
    ...
    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    if case let .evaluated(evaluation) = answerResult {
        quarterNoteSequenceLastEvaluation = evaluation
    }
    ...
}

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

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    ...
    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        quarterNoteSequenceLastEvaluation = nil
    }
    ...
}

private func regenerateQuarterNoteSequence(reason: String) {
    ...
    quarterNoteSequenceSession = nil
    quarterNoteSequenceLastEvaluation = nil
    ...
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    ...
    if nextTrainerDisplayState.isSequenceMode,
       nextRequestedStaffDisplayState != staffDisplayState {
        var nextBaseStaffDisplayState = nextRequestedStaffDisplayState
        nextBaseStaffDisplayState.clearSequencePresentation()
        baseStaffDisplayState = nextBaseStaffDisplayState
    }
}
```

### 修改后

- 新增 `clearQuarterNoteSequenceFeedbackState()`：只清空最近一次红/绿反馈
- 新增 `resetQuarterNoteSequenceInteractionState()`：同时清空 session 与最近一次反馈
- 新增 `updateQuarterNoteSequenceFeedbackState(...)`：只有顶部当前显示 `Staff` 时才保留本次判题结果
- 新增 `sanitizedSequenceFreeStaffDisplayState(...)`：统一把 sequence 展示语义从 `baseStaffDisplayState` 中剥离
- 新增 `handleQuarterNoteSequencePageDisplayStateTransition(...)`：当顶部从 `Staff` 切走时，立刻清掉旧反馈并对当前 sequence 重新投影
- 原先散落的直接赋空语句，统一改走这些 helper

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: pageDisplayState.didSet, clearQuarterNoteSequenceFeedbackState(), resetQuarterNoteSequenceInteractionState(), updateQuarterNoteSequenceFeedbackState(...), sanitizedSequenceFreeStaffDisplayState(...), handleQuarterNoteSequencePageDisplayStateTransition(...), handleQuarterNoteSequenceHitResult(...), applyFretboardTrainerPrompt(...), synchronizeQuarterNoteSequencePresentation(...), regenerateQuarterNoteSequence(...), handleSettingsPanelEvent(...)
// 功能说明: 修改后 iOS controller 明确区分“临时反馈清理”和“整段 sequence 会话重置”，
// 并在 TopContent 离开 Staff 时统一回收旧红/绿状态，避免它们在后续重返 Staff 时泄漏。
private var pageDisplayState = PageDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
        handleQuarterNoteSequencePageDisplayStateTransition(
            from: oldValue,
            to: pageDisplayState
        )
    }
}

private func clearQuarterNoteSequenceFeedbackState() {
    quarterNoteSequenceLastEvaluation = nil
}

private func resetQuarterNoteSequenceInteractionState() {
    quarterNoteSequenceSession = nil
    clearQuarterNoteSequenceFeedbackState()
}

private func updateQuarterNoteSequenceFeedbackState(
    with answerResult: FretboardNaturalNoteTrainerState.QuarterNoteSequenceAnswerResult
) {
    guard isShowingStaffTopContent else {
        clearQuarterNoteSequenceFeedbackState()
        return
    }

    if case let .evaluated(evaluation) = answerResult {
        quarterNoteSequenceLastEvaluation = evaluation
    }
}

private func sanitizedSequenceFreeStaffDisplayState(
    _ state: StaffDisplayState
) -> StaffDisplayState {
    var state = state
    state.clearSequencePresentation()
    return state
}

private func handleQuarterNoteSequencePageDisplayStateTransition(
    from oldValue: PageDisplayState,
    to newValue: PageDisplayState
) {
    guard trainerDisplayState.isSequenceMode,
          oldValue.topContentMode == .staff,
          newValue.topContentMode != .staff,
          quarterNoteSequenceLastEvaluation != nil else {
        return
    }

    clearQuarterNoteSequenceFeedbackState()
    guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
        return
    }

    applyQuarterNoteSequenceProjection(
        generatedSequence,
        reason: "topContentHidden",
        showsLog: false
    )
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    ...
    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        clearQuarterNoteSequenceFeedbackState()
    }
    ...
    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    updateQuarterNoteSequenceFeedbackState(with: answerResult)
    ...
}

private func applyFretboardTrainerPrompt(reason: String) {
    resetQuarterNoteSequenceInteractionState()
    ...
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    ...
    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        clearQuarterNoteSequenceFeedbackState()
    }
    ...
}

private func regenerateQuarterNoteSequence(reason: String) {
    ...
    resetQuarterNoteSequenceInteractionState()
    ...
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    ...
    if nextTrainerDisplayState.isSequenceMode,
       nextRequestedStaffDisplayState != staffDisplayState {
        baseStaffDisplayState = sanitizedSequenceFreeStaffDisplayState(
            nextRequestedStaffDisplayState
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: pageDisplayState.didSet, clearQuarterNoteSequenceFeedbackState(), resetQuarterNoteSequenceInteractionState(), updateQuarterNoteSequenceFeedbackState(...), sanitizedSequenceFreeStaffDisplayState(...), handleQuarterNoteSequencePageDisplayStateTransition(...), handleQuarterNoteSequenceHitResult(...), applyFretboardTrainerPrompt(...), synchronizeQuarterNoteSequencePresentation(...), regenerateQuarterNoteSequence(...), handleSettingsPanelEvent(...)
// 功能说明: 修改后 macOS 复用与 iOS 完全对称的 sequence 边界收口策略，
// 保证双端在 regenerate / 切模式 / 切 TopContent / settings 改写 staff 基线时行为一致。
private var pageDisplayState = PageDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
        handleQuarterNoteSequencePageDisplayStateTransition(
            from: oldValue,
            to: pageDisplayState
        )
    }
}

private func clearQuarterNoteSequenceFeedbackState() {
    quarterNoteSequenceLastEvaluation = nil
}

private func resetQuarterNoteSequenceInteractionState() {
    quarterNoteSequenceSession = nil
    clearQuarterNoteSequenceFeedbackState()
}

private func updateQuarterNoteSequenceFeedbackState(
    with answerResult: FretboardNaturalNoteTrainerState.QuarterNoteSequenceAnswerResult
) {
    guard isShowingStaffTopContent else {
        clearQuarterNoteSequenceFeedbackState()
        return
    }

    if case let .evaluated(evaluation) = answerResult {
        quarterNoteSequenceLastEvaluation = evaluation
    }
}

private func sanitizedSequenceFreeStaffDisplayState(
    _ state: StaffDisplayState
) -> StaffDisplayState {
    var state = state
    state.clearSequencePresentation()
    return state
}

private func handleQuarterNoteSequencePageDisplayStateTransition(
    from oldValue: PageDisplayState,
    to newValue: PageDisplayState
) {
    guard trainerDisplayState.isSequenceMode,
          oldValue.topContentMode == .staff,
          newValue.topContentMode != .staff,
          quarterNoteSequenceLastEvaluation != nil else {
        return
    }

    clearQuarterNoteSequenceFeedbackState()
    guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
        return
    }

    applyQuarterNoteSequenceProjection(
        generatedSequence,
        reason: "topContentHidden",
        showsLog: false
    )
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    ...
    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        clearQuarterNoteSequenceFeedbackState()
    }
    ...
    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    updateQuarterNoteSequenceFeedbackState(with: answerResult)
    ...
}

private func applyFretboardTrainerPrompt(reason: String) {
    resetQuarterNoteSequenceInteractionState()
    ...
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    ...
    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
        clearQuarterNoteSequenceFeedbackState()
    }
    ...
}

private func regenerateQuarterNoteSequence(reason: String) {
    ...
    resetQuarterNoteSequenceInteractionState()
    ...
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    ...
    if nextTrainerDisplayState.isSequenceMode,
       nextRequestedStaffDisplayState != staffDisplayState {
        baseStaffDisplayState = sanitizedSequenceFreeStaffDisplayState(
            nextRequestedStaffDisplayState
        )
    }
}
```

## 修改 3：把“切走再切回 Staff 不得带回旧红绿反馈”写进手工回归清单

### 修改前

- `StaffValidation` 的 sequence 手工清单只要求检查初始游标、错误红色、正确绿色、完成态隐藏游标
- 还没有显式覆盖 `Target Prompt -> Staff` 往返切换后的反馈泄漏问题

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: manualChecklist(for:)
// 功能说明: 修改前手工清单关注 sequence 场景本身，
// 但没有把 TopContent 来回切换后的旧反馈泄漏列为显式回归项。
"把 `TopContent` 切到 `Staff` 且 `Exercise Mode` 切到 `Sequence`：确认初始竖线游标准确对齐当前目标音；错误作答时当前音变红且游标不前进；正确作答时刚答中的音变绿且游标前进；完成整条序列后游标隐藏，但最后一次反馈颜色仍保留。",
```

### 修改后

- 手工清单在原有 sequence 验证后追加了“切到 `Target Prompt` 再切回 `Staff`”的边界检查
- 这样阶段 5 新增的状态清理逻辑有了明确的人工回归指引

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: manualChecklist(for:)
// 功能说明: 修改后手工清单把 TopContent 往返切换场景也纳入 sequence staff 回归要求，
// 明确要求验证旧红/绿反馈不会在切回 Staff 时泄漏回来。
"把 `TopContent` 切到 `Staff` 且 `Exercise Mode` 切到 `Sequence`：确认初始竖线游标准确对齐当前目标音；错误作答时当前音变红且游标不前进；正确作答时刚答中的音变绿且游标前进；完成整条序列后游标隐藏，但最后一次反馈颜色仍保留。随后切到 `Target Prompt` 再切回 `Staff`，确认旧红/绿反馈不会泄漏回来，只保留当前进度对应的中性游标或完成态。",
```

## 本阶段结果

- `iOS/macOS` 双端现在都只在 `TopContent = Staff` 时保留 sequence 红/绿反馈
- 切到 `Target Prompt` 再切回 `Staff` 时，不会因为 controller 残留 `lastEvaluation` 而把旧反馈重新画回五线谱
- `regenerate`、session 重建、切回 `single`、settings 面板改写 `baseStaffDisplayState` 等入口，已经统一改走收口 helper
- 双端 controller 的 sequence 状态边界现在保持对称，不再需要在多个入口继续堆手写 `= nil`

## 验证情况

- 已对下列文件执行静态诊断检查，结果无 linter 错误：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- 未执行 `xcodebuild` 全量编译；当前记录仅覆盖本次阶段 5 的 controller reset/cleanup 与手工回归清单更新

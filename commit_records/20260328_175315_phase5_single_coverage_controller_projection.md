# 20260328_175315_phase5_single_coverage_controller_projection

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_175315`
- 记录范围：实施 `single覆盖反馈` 计划的阶段 5，只补平台 `FretboardView` 的 overlay 透传，以及 iOS/macOS 控制器对 `SingleCoverageSession` 的投影接线
- 本次目标：让 single mode 正式从“旧的单击即推进”控制器路径迁移到 `single coverage session + prompt progress + feedback overlay` 的统一平台投影链路
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 阶段 2 已经在 shared 层提供了 `SingleCoverageSession` 和 `handleSingleCoverageHit(...)`
- 阶段 3 已经让 prompt 能表达 `singleCoverage(text:visitedCount:totalCount:)`
- 阶段 4 已经补齐 `FretboardFeedbackOverlayState`、`FretboardFeedbackLayer` 和 `FretboardLayer.feedbackOverlayState`
- 但在阶段 5 之前，iOS/macOS 控制器仍然沿用旧的 single 判定入口 `fretboardTrainerState.handle(...)`，平台 `FretboardView` 也没有把 `feedbackOverlayState` 继续下传到底层 layer
- 结果就是：shared 层已经具备“整块指板覆盖完成后再推进”的能力，但平台层既不会维持 single coverage 的 session，也不会把绿色已命中格位和红色错误格位投影到 UI
- 因此阶段 5 的根因级修复，是让平台控制器正式接手 single coverage 的状态持有、配置变化重建、prompt 投影和 overlay 投影

## 修改 1：为双端 `FretboardView` 暴露 `feedbackOverlayState` 平台透传口

### 修改前

- iOS/macOS 指板 view 只负责把 `configuration` 和 `contentProvider` 同步到 `FretboardLayer`
- 即使控制器后续持有了 `FretboardFeedbackOverlayState`，也没有平台出口把该状态继续传给 shared root layer

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名: iOSFretboardView.contentProvider, iOSFretboardView.applyConfiguration()
// 功能说明: 修改前 iOS 指板 view 只同步内容提供器与 configuration；
// 还没有 feedback overlay 的平台透传属性。
var contentProvider: (any FretboardContentProviding)? {
    didSet {
        fretboardLayer.contentProvider = contentProvider
    }
}

private func applyConfiguration() {
    lastMeasuredPrimaryDimension = nil
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    updateContentPriorities()
    invalidateIntrinsicContentSize()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名: macOSFretboardView.contentProvider, macOSFretboardView.applyConfiguration()
// 功能说明: 修改前 macOS 指板 view 与 iOS 同构；
// 只能下传基础内容状态，无法下传 single coverage 的 overlay。
var contentProvider: (any FretboardContentProviding)? {
    didSet {
        fretboardLayer.contentProvider = contentProvider
    }
}

private func applyConfiguration() {
    lastMeasuredPrimaryDimension = nil
    fretboardLayer.configuration = configuration
    fretboardLayer.contextNormalizationMode = resolvedContextNormalizationMode
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    updateContentPriorities()
    invalidateIntrinsicContentSize()
}
```

### 修改后

- iOS/macOS 指板 view 都新增了 `feedbackOverlayState`
- 属性变化时会立即下传到底层 `FretboardLayer`
- `applyConfiguration()` 也会在重新配置时把当前 overlay 一并恢复，避免 configuration 更新后丢失显示状态

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名: iOSFretboardView.feedbackOverlayState, iOSFretboardView.applyConfiguration()
// 功能说明: 修改后 iOS 指板 view 可以接收控制器投影过来的红绿反馈状态，
// 并在 configuration 重建后继续把 overlay 同步到底层 FretboardLayer。
var feedbackOverlayState: FretboardFeedbackOverlayState = .empty {
    didSet {
        guard oldValue != feedbackOverlayState else {
            return
        }

        fretboardLayer.feedbackOverlayState = feedbackOverlayState
    }
}

private func applyConfiguration() {
    lastMeasuredPrimaryDimension = nil
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    fretboardLayer.feedbackOverlayState = feedbackOverlayState
    updateContentsScale()
    updateContentPriorities()
    invalidateIntrinsicContentSize()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名: macOSFretboardView.feedbackOverlayState, macOSFretboardView.applyConfiguration()
// 功能说明: 修改后 macOS 指板 view 与 iOS 对齐，
// 正式拥有独立的 feedback overlay 下传通道。
var feedbackOverlayState: FretboardFeedbackOverlayState = .empty {
    didSet {
        guard oldValue != feedbackOverlayState else {
            return
        }

        fretboardLayer.feedbackOverlayState = feedbackOverlayState
    }
}

private func applyConfiguration() {
    lastMeasuredPrimaryDimension = nil
    fretboardLayer.configuration = configuration
    fretboardLayer.contextNormalizationMode = resolvedContextNormalizationMode
    fretboardLayer.contentProvider = contentProvider
    fretboardLayer.feedbackOverlayState = feedbackOverlayState
    updateContentsScale()
    updateContentPriorities()
    invalidateIntrinsicContentSize()
}
```

## 修改 2：在双端控制器中新增 single coverage 的平台会话与投影派生状态

### 修改前

- 控制器只持有 quarter-note sequence 的 session / evaluation
- single 模式没有独立的 `SingleCoverageSession`
- prompt 刷新入口 `applyFretboardTrainerPrompt(reason:)` 只能显示旧的 `.single(text:)`
- 更重要的是，控制器没有“当前 single coverage overlay 应该长什么样”的派生状态

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController 属性区, iOSViewController.applyFretboardTrainerPrompt(reason:)
// 功能说明: 修改前 iOS 控制器只维护 quarter-note sequence 的交互会话；
// single 模式没有自己的 session，也没有独立的 overlay / progress 投影入口。
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?
private var quarterNoteSequenceLastEvaluation: FretboardNaturalNoteTrainerState.QuarterNoteSequenceEvaluation?

private func applyFretboardTrainerPrompt(reason: String) {
    resetQuarterNoteSequenceInteractionState()
    let prompt = currentFretboardTrainerPrompt
    targetNotePromptView.apply(content: prompt.targetPromptContent)
    print(
        "[FretboardTrainer][iOS] target=\(prompt.displayText) state=\(reason)"
    )
}
```

### 修改后

- 控制器新增：
- `singleCoverageSession`
- `singleCoverageLastEvaluation`
- `currentSingleCoverageRequiredCells`
- `currentSingleCoverageTargetPromptContent`
- `currentFretboardFeedbackOverlayState`
- `singleCoverageSessionMatchesCurrentTrainer(...)`
- `ensureSingleCoverageSession()`
- `clearSingleCoverageFeedbackState()` / `resetSingleCoverageInteractionState()`
- `applyCurrentFretboardFeedbackOverlayState()`
- `applySingleCoverageProjection(reason:showsLog:)`
- 这些成员一起构成 single mode 在平台层的“真相源 + 派生投影”

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.currentSingleCoverageTargetPromptContent,
//        iOSViewController.currentFretboardFeedbackOverlayState,
//        iOSViewController.ensureSingleCoverageSession(),
//        iOSViewController.applySingleCoverageProjection(reason:showsLog:)
// 功能说明: 修改后 iOS 控制器会按当前 targetPitchClass + configuration
// 维护 single coverage session，并同时生成 prompt 进度内容和指板 feedback overlay。
private var singleCoverageSession: FretboardNaturalNoteTrainerState.SingleCoverageSession?
private var singleCoverageLastEvaluation: FretboardNaturalNoteTrainerState.SingleCoverageEvaluation?

private var currentSingleCoverageTargetPromptContent: TargetPromptContent {
    guard let singleCoverageSession,
          singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) else {
        return .single(
            text: fretboardTrainerState.targetPitchClass.displayText(
                using: displayState.spelling
            )
        )
    }

    return singleCoverageSession.targetPromptContent(
        spelling: displayState.spelling
    )
}

private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
    guard case .singleNaturalTarget = fretboardTrainerState.mode,
          let singleCoverageSession,
          singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) else {
        return .empty
    }

    let wrongCell: FretboardCell?
    if let singleCoverageLastEvaluation,
       singleCoverageLastEvaluation.hitKind == .wrong {
        wrongCell = singleCoverageLastEvaluation.selectedCell
    } else {
        wrongCell = nil
    }

    return FretboardFeedbackOverlayState(
        correctCells: singleCoverageSession.visitedCells,
        wrongCell: wrongCell
    )
}

private func ensureSingleCoverageSession() {
    guard case .singleNaturalTarget = fretboardTrainerState.mode else {
        return
    }

    if let singleCoverageSession,
       singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) {
        return
    }

    singleCoverageSession = fretboardTrainerState.makeSingleCoverageSession(
        configuration: displayState.configuration
    )
    clearSingleCoverageFeedbackState()
}

private func applySingleCoverageProjection(
    reason: String,
    showsLog: Bool = true
) {
    ensureSingleCoverageSession()
    targetNotePromptView.apply(content: currentSingleCoverageTargetPromptContent)
    applyCurrentFretboardFeedbackOverlayState()

    guard showsLog else {
        return
    }

    let progressText: String
    if let singleCoverageSession {
        progressText = "\(singleCoverageSession.visitedCount)/\(singleCoverageSession.totalCount)"
    } else {
        progressText = "0/0"
    }

    print(
        "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) progress=\(progressText) state=\(reason)"
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.currentSingleCoverageTargetPromptContent,
//        macOSViewController.currentFretboardFeedbackOverlayState,
//        macOSViewController.ensureSingleCoverageSession(),
//        macOSViewController.applySingleCoverageProjection(reason:showsLog:)
// 功能说明: 修改后 macOS 控制器采用与 iOS 同构的 single coverage 平台投影模型，
// 保证两端对 prompt 与 overlay 的解释完全一致。
private var singleCoverageSession: FretboardNaturalNoteTrainerState.SingleCoverageSession?
private var singleCoverageLastEvaluation: FretboardNaturalNoteTrainerState.SingleCoverageEvaluation?

private var currentSingleCoverageTargetPromptContent: TargetPromptContent {
    guard let singleCoverageSession,
          singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) else {
        return .single(
            text: fretboardTrainerState.targetPitchClass.displayText(
                using: displayState.spelling
            )
        )
    }

    return singleCoverageSession.targetPromptContent(
        spelling: displayState.spelling
    )
}

private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
    guard case .singleNaturalTarget = fretboardTrainerState.mode,
          let singleCoverageSession,
          singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) else {
        return .empty
    }

    let wrongCell: FretboardCell?
    if let singleCoverageLastEvaluation,
       singleCoverageLastEvaluation.hitKind == .wrong {
        wrongCell = singleCoverageLastEvaluation.selectedCell
    } else {
        wrongCell = nil
    }

    return FretboardFeedbackOverlayState(
        correctCells: singleCoverageSession.visitedCells,
        wrongCell: wrongCell
    )
}

private func ensureSingleCoverageSession() {
    guard case .singleNaturalTarget = fretboardTrainerState.mode else {
        return
    }

    if let singleCoverageSession,
       singleCoverageSessionMatchesCurrentTrainer(singleCoverageSession) {
        return
    }

    singleCoverageSession = fretboardTrainerState.makeSingleCoverageSession(
        configuration: displayState.configuration
    )
    clearSingleCoverageFeedbackState()
}

private func applySingleCoverageProjection(
    reason: String,
    showsLog: Bool = true
) {
    ensureSingleCoverageSession()
    targetNotePromptView.apply(content: currentSingleCoverageTargetPromptContent)
    applyCurrentFretboardFeedbackOverlayState()

    guard showsLog else {
        return
    }

    let progressText: String
    if let singleCoverageSession {
        progressText = "\(singleCoverageSession.visitedCount)/\(singleCoverageSession.totalCount)"
    } else {
        progressText = "0/0"
    }

    print(
        "[SingleCoverage][macOS] target=\(currentFretboardTrainerPrompt.displayText) progress=\(progressText) state=\(reason)"
    )
}
```

## 修改 3：把 single 命中处理从旧 `handle(...)` 迁移到 `handleSingleCoverageHit(...)`

### 修改前

- single 模式仍然直接调用旧的 `fretboardTrainerState.handle(hitResult:configuration:)`
- 控制器只关心单次点击对不对，以及是否立刻推进 target
- 不会记住“哪些正确格位已经覆盖过”，也不会产出红/绿 overlay 状态

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.handleSingleNaturalTargetHitResult(_:)
// 功能说明: 修改前 single 模式仍然沿用 legacy 单击判断；
// 只要 evaluation.didAdvanceTarget 为真就立即切到下一题，没有 coverage session 的概念。
private func handleSingleNaturalTargetHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.handle(
        hitResult: hitResult,
        configuration: displayState.configuration
    ) {
    case .ignored(.nonEndedPhase):
        return
    case .ignored(.missingHitCell):
        print(
            "[FretboardTrainer][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
        )
    case let .ignored(.unresolvedHitPitch(cell)):
        print(
            "[FretboardTrainer][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
        )
    case let .evaluated(evaluation):
        print("[iOS] \(evaluation.debugSummary())")
        if evaluation.didAdvanceTarget {
            applyFretboardTrainerPrompt(reason: "advanced")
        }
    }
}
```

### 修改后

- 命中入口先确保 session 已按当前 configuration 建好
- 然后调用 shared 的 `handleSingleCoverageHit(...)`
- 每次评估后都会：
- 持久化 `singleCoverageSession`
- 记录 `singleCoverageLastEvaluation`
- 在覆盖完成后为新的 target 重建 session
- 重新投影 prompt 与 overlay
- 因此 single mode 终于具备“正确新命中计数、正确重复命中不加进度、错误命中只显示红色不推进题目”的平台行为

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.handleSingleNaturalTargetHitResult(_:)
// 功能说明: 修改后 iOS single 模式切到 shared single coverage 状态机；
// 每次点击都会更新已访问集合、最近错误格位和 prompt 进度，只在覆盖完成时推进 target。
private func handleSingleNaturalTargetHitResult(_ hitResult: FretboardHitResult) {
    ensureSingleCoverageSession()
    guard var singleCoverageSession else {
        print("[SingleCoverage][iOS] result=ignored reason=missingSession")
        return
    }

    let answerResult = fretboardTrainerState.handleSingleCoverageHit(
        hitResult,
        configuration: displayState.configuration,
        session: &singleCoverageSession
    )

    switch answerResult {
    case .ignored(.nonEndedPhase):
        return
    case .ignored(.missingHitCell):
        print(
            "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
        )
    case let .ignored(.unresolvedHitPitch(cell)):
        print(
            "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
        )
    case .ignored(.completedSession):
        print(
            "[SingleCoverage][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=completedSession"
        )
    case let .evaluated(evaluation):
        self.singleCoverageSession = singleCoverageSession
        updateSingleCoverageFeedbackState(with: answerResult)
        if evaluation.didAdvanceTarget {
            self.singleCoverageSession = fretboardTrainerState.makeSingleCoverageSession(
                configuration: displayState.configuration
            )
            clearSingleCoverageFeedbackState()
        }
        applySingleCoverageProjection(
            reason: evaluation.didAdvanceTarget ? "advanced" : "answered",
            showsLog: false
        )
        print("[iOS] \(evaluation.debugSummary())")
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.handleSingleNaturalTargetHitResult(_:)
// 功能说明: 修改后 macOS single 命中处理与 iOS 保持同构，
// 确保两端都从同一个 shared coverage 状态机取结果，而不是继续走旧判断逻辑。
private func handleSingleNaturalTargetHitResult(_ hitResult: FretboardHitResult) {
    ensureSingleCoverageSession()
    guard var singleCoverageSession else {
        print("[SingleCoverage][macOS] result=ignored reason=missingSession")
        return
    }

    let answerResult = fretboardTrainerState.handleSingleCoverageHit(
        hitResult,
        configuration: displayState.configuration,
        session: &singleCoverageSession
    )

    switch answerResult {
    case .ignored(.nonEndedPhase):
        return
    case .ignored(.missingHitCell):
        print(
            "[SingleCoverage][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
        )
    case let .ignored(.unresolvedHitPitch(cell)):
        print(
            "[SingleCoverage][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
        )
    case .ignored(.completedSession):
        print(
            "[SingleCoverage][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=completedSession"
        )
    case let .evaluated(evaluation):
        self.singleCoverageSession = singleCoverageSession
        updateSingleCoverageFeedbackState(with: answerResult)
        if evaluation.didAdvanceTarget {
            self.singleCoverageSession = fretboardTrainerState.makeSingleCoverageSession(
                configuration: displayState.configuration
            )
            clearSingleCoverageFeedbackState()
        }
        applySingleCoverageProjection(
            reason: evaluation.didAdvanceTarget ? "advanced" : "answered",
            showsLog: false
        )
        print("[macOS] \(evaluation.debugSummary())")
    }
}
```

## 修改 4：在配置变化与模式切换时重建 single coverage 会话并清空不再适用的 overlay

### 修改前

- `applyFretboardDisplayState()` 只同步指板基础显示状态
- `synchronizeSingleTrainerPresentation(reason:)` 和 `synchronizeQuarterNoteSequencePresentation(reason:)` 不会清理或重建 single coverage session
- 所以一旦切换练习模式、改动 `fretRange`、改动 tuning / spelling / display configuration，single 覆盖会话与 UI 反馈之间就可能脱节

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.applyFretboardDisplayState(),
//        macOSViewController.synchronizeSingleTrainerPresentation(reason:),
//        macOSViewController.synchronizeQuarterNoteSequencePresentation(reason:)
// 功能说明: 修改前 macOS 控制器只同步基础 display state；
// 没有 single coverage session 的重建与 overlay 清理逻辑。
private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()
    // ... 仅更新布局与 viewport ...
}

private func synchronizeSingleTrainerPresentation(reason: String) {
    if isQuarterNoteSequenceMode {
        fretboardTrainerState = FretboardNaturalNoteTrainerState()
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    if pageDisplayState.mainContentMode != .fretboard {
        pageDisplayState.setMainContentMode(.fretboard)
    }

    // ... 只处理 sequence 自己的生成与投影 ...
}
```

### 修改后

- `applyFretboardDisplayState()` 会同步 `fretboardView.feedbackOverlayState`
- 当前模式为 single 时，会立刻触发 `applySingleCoverageProjection(reason:"fretboardDisplayChanged")`
- 当前模式不是 single 时，也会通过 `applyCurrentFretboardFeedbackOverlayState()` 把 overlay 收回到 `.empty`
- 从 sequence 切回 single 时，会重建单题 trainer 并清空旧 single coverage 状态
- 切到 sequence 时，会先 `resetSingleCoverageInteractionState()`，避免 single 的绿色/红色残留到序列题

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.applyFretboardDisplayState(),
//        macOSViewController.synchronizeSingleTrainerPresentation(reason:),
//        macOSViewController.synchronizeQuarterNoteSequencePresentation(reason:),
//        macOSViewController.applyCurrentFretboardFeedbackOverlayState()
// 功能说明: 修改后 macOS 控制器会在 display state 变化和模式切换时，
// 主动重建 single coverage session，并把已失效的 overlay 清空。
private func applyFretboardDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    rebuildVerticalFretboardHostHeightConstraint()
    applySettingsPanelState()
    updateFretboardLayoutModeConstraints()

    if case .singleNaturalTarget = fretboardTrainerState.mode {
        applySingleCoverageProjection(
            reason: "fretboardDisplayChanged",
            showsLog: false
        )
    } else {
        applyCurrentFretboardFeedbackOverlayState()
    }

    // ... 保持原有布局与 viewport 更新链路不变 ...
}

private func synchronizeSingleTrainerPresentation(reason: String) {
    if isQuarterNoteSequenceMode {
        fretboardTrainerState = FretboardNaturalNoteTrainerState()
        resetSingleCoverageInteractionState()
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    resetSingleCoverageInteractionState()
    if pageDisplayState.mainContentMode != .fretboard {
        pageDisplayState.setMainContentMode(.fretboard)
    }

    // ... 继续执行 sequence 自己的生成与投影 ...
}

private func applyCurrentFretboardFeedbackOverlayState() {
    fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
}
```

## 结果摘要

- 阶段 5 完成后，single mode 的平台链路已经从 shared `SingleCoverageSession` 真正取数
- prompt 显示不再只是单个音名，而是会在控制器中按当前 session 投影为 `singleCoverage` 进度内容
- 指板 overlay 会持续显示：
- 已命中的正确格位为绿色
- 最近一次错误格位为红色
- 配置变化、模式切换时，session 和 overlay 都会按当前上下文重建或清空，不再沿用失效状态

## 本阶段未涉及

- 未新增阶段 6 的 shared validation 断言
- 未整理新的人工 QA 清单
- 未做 markdown 之外的 commit / push

## 验证

- 已对本次修改的 4 个文件执行 `ReadLints`
- 结果：`No linter errors found`

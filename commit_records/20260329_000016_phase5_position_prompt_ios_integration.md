# 20260329_000016_phase5_position_prompt_ios_integration

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_000016`
- 记录范围：实施“位置音名模式”计划的阶段 5，只补 iOS 端完整链路：位置题 session/overlay 相位、底部 7 键按钮作答、错误红闪恢复白圈、正确 1 秒停留后自动推进；不涉及 macOS 对称实现
- 本次目标：让 iOS 上的第三模式可以不点指板，只通过底部自然音按钮完成作答，并正确驱动白圈/红闪/绿停留
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`

## 根因结论

- 阶段 4 已经让 iOS 控制器能把第三模式稳定收敛到 `top=fretboard, main=naturalNoteStrip`，但当时还缺少真正可运行的 iOS 交互链路
- 具体缺口有三类：
- 控制器没有自己的 `positionPromptSession / evaluation / overlayPhase / delayTask` 状态
- 底部 `naturalNoteStripView` 的 `onPitchClassTap` 没有接到位置题判题入口
- shared 层虽然已经能表达 `.positionPrompt(promptCell:phase:)`，但控制器没有去调度“错题红闪后恢复白圈、对题绿停留 1 秒后切下一题”
- 如果直接在现有阶段 4 的基础上运行，第三模式只会停留在“页面切好了，但按钮不驱动题目”的半成品状态
- 因此阶段 5 的根因级修复，是把 iOS 控制器真正升级为位置题的时序协调者：shared trainer 负责出题/判题，控制器负责按钮接线、overlay 相位与延时推进

## 修改 1：在 iOS 控制器中新增 position prompt 的本地交互状态

### 修改前

- 控制器只有 single coverage 与 quarter note sequence 两套交互状态
- `currentFretboardFeedbackOverlayState` 只会在 `.singleNaturalTarget` 下返回 overlay
- 第三模式即使进入页面，也没有 session 或白圈真相源可供投影

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: 单文件顶部的控制器状态字段, currentFretboardFeedbackOverlayState
// 功能说明: 修改前控制器只持有 single / sequence 的运行时状态；
// position prompt 既没有 session，也没有 overlay phase 或待取消的延时任务。
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
private var singleCoverageSession: FretboardNaturalNoteTrainerState.SingleCoverageSession?
private var singleCoverageLastEvaluation: FretboardNaturalNoteTrainerState.SingleCoverageEvaluation?
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?
private var quarterNoteSequenceLastEvaluation: FretboardNaturalNoteTrainerState.QuarterNoteSequenceEvaluation?

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

    return .singleCoverage(
        correctCells: singleCoverageSession.visitedCells,
        wrongCell: wrongCell
    )
}
```

### 修改后

- 新增 `positionPromptSession`
- 新增 `positionPromptLastEvaluation`
- 新增 `positionPromptOverlayPhase`
- 新增 `pendingPositionPromptTransitionWorkItem`
- `currentFretboardFeedbackOverlayState` 扩成 `singleNaturalTarget / positionPrompt / quarterNoteSequence` 三分支
- 新增 `ensurePositionPromptSession()`、`resetPositionPromptInteractionState()` 和 `currentPositionPromptOverlayCell(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: positionPromptSession, positionPromptLastEvaluation,
// positionPromptOverlayPhase, pendingPositionPromptTransitionWorkItem,
// currentFretboardFeedbackOverlayState, ensurePositionPromptSession(),
// resetPositionPromptInteractionState(), currentPositionPromptOverlayCell(for:)
// 功能说明: 修改后 iOS 控制器已经持有位置题的本地运行时真相；
// shared trainer 只负责出题与判题，白圈显示哪个格子、当前是白/红/绿哪一相位、是否还有待执行的跳题任务，都由控制器协调。
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()
private var singleCoverageSession: FretboardNaturalNoteTrainerState.SingleCoverageSession?
private var singleCoverageLastEvaluation: FretboardNaturalNoteTrainerState.SingleCoverageEvaluation?
private var positionPromptSession: FretboardNaturalNoteTrainerState.PositionPromptSession?
private var positionPromptLastEvaluation: FretboardNaturalNoteTrainerState.PositionPromptEvaluation?
private var positionPromptOverlayPhase: FretboardFeedbackOverlayState.PositionPromptPhase?
private var pendingPositionPromptTransitionWorkItem: DispatchWorkItem?
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?
private var quarterNoteSequenceLastEvaluation: FretboardNaturalNoteTrainerState.QuarterNoteSequenceEvaluation?

private var currentPositionPromptOverlayPhase: FretboardFeedbackOverlayState.PositionPromptPhase {
    positionPromptOverlayPhase ?? .neutralWhite
}

private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        // 保留旧的 single coverage overlay 投影
        return .singleCoverage(
            correctCells: singleCoverageSession?.visitedCells ?? [],
            wrongCell: nil
        )
    case .positionPrompt:
        guard let positionPromptSession,
              positionPromptSessionMatchesCurrentTrainer(positionPromptSession) else {
            return .empty
        }

        return .positionPrompt(
            promptCell: currentPositionPromptOverlayCell(
                for: positionPromptSession
            ),
            phase: currentPositionPromptOverlayPhase
        )
    case .quarterNoteSequence:
        return .empty
    }
}

private func resetPositionPromptInteractionState() {
    cancelPendingPositionPromptTransition()
    positionPromptSession = nil
    clearPositionPromptFeedbackState()
    positionPromptOverlayPhase = nil
    updateNaturalNoteStripInteractionState()
}

private func ensurePositionPromptSession() {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return
    }

    if let positionPromptSession,
       positionPromptSessionMatchesCurrentTrainer(positionPromptSession) {
        if positionPromptOverlayPhase == nil {
            positionPromptOverlayPhase = .neutralWhite
        }
        return
    }

    cancelPendingPositionPromptTransition()
    var generator = SystemRandomNumberGenerator()
    positionPromptSession = fretboardTrainerState.makePositionPromptSession(
        configuration: displayState.configuration,
        using: &generator
    )
    clearPositionPromptFeedbackState()
    positionPromptOverlayPhase = .neutralWhite
}
```

## 修改 2：把底部自然音按钮条接到位置题作答入口

### 修改前

- `naturalNoteStripView` 只是被创建并显示/隐藏
- `onPitchClassTap` 回调没有接控制器
- 控制器只有指板点击处理，没有“按钮作答位置题”的处理函数

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: naturalNoteStripView, handleFretboardTrainerHitResult(_:)
// 功能说明: 修改前自然音按钮条虽然存在，但控制器没有把按钮点击接到位置题；
// 第三模式仍然无法通过按钮完成作答。
private lazy var naturalNoteStripView: iOSNaturalNoteStripView = {
    let naturalNoteStripView = iOSNaturalNoteStripView()
    naturalNoteStripView.isHidden = true
    return naturalNoteStripView
}()

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
```

### 修改后

- 在 `naturalNoteStripView` 上绑定 `onPitchClassTap`
- 新增 `handleNaturalNoteStripPitchClassTap(_:)`
- 新增 `handlePositionPromptAnswer(_:)`
- 第三模式继续忽略指板点击，统一只接受底部按钮作答

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: naturalNoteStripView, handleNaturalNoteStripPitchClassTap(_:)
// 功能说明: 修改后自然音按钮条已接到控制器；
// 第三模式下用户点击底部 C D E F G A B 按钮，就会进入 shared position prompt 判题链路。
private lazy var naturalNoteStripView: iOSNaturalNoteStripView = {
    let naturalNoteStripView = iOSNaturalNoteStripView()
    naturalNoteStripView.onPitchClassTap = { [weak self] pitchClass in
        self?.handleNaturalNoteStripPitchClassTap(pitchClass)
    }
    naturalNoteStripView.isHidden = true
    return naturalNoteStripView
}()

private func handleNaturalNoteStripPitchClassTap(_ pitchClass: PitchClass) {
    switch fretboardTrainerState.mode {
    case .positionPrompt:
        handlePositionPromptAnswer(pitchClass)
    case .singleNaturalTarget, .quarterNoteSequence:
        return
    }
}
```

## 修改 3：在 iOS 中补齐错题红闪、对题绿停留和自动推进

### 修改前

- `synchronizePositionPromptPresentation(reason:)` 只负责把页面收敛到第三模式
- 没有 `applyPositionPromptProjection(...)`
- 没有延时任务调度函数
- 错题后不会红闪，答对后也不会延时推进

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改前阶段 4 的第三模式同步只切 mode 与页面不变量；
// 还没有 iOS 平台自己的白圈投影、按钮禁用、错题恢复和对题推进时序。
private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    if case .positionPrompt = fretboardTrainerState.mode {
        // 阶段 4 这里只先切通 mode 与页面不变量。
    } else {
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            positionPromptMode: ()
        )
    }

    applyCurrentFretboardFeedbackOverlayState()
    print(
        "[PositionPrompt][iOS] page=topFretboard/mainNaturalNotes state=\(reason)"
    )
}
```

### 修改后

- `handlePositionPromptAnswer(_:)` 中：
- 错题进入 `.wrongFlash`
- 约 `0.28s` 后恢复 `.neutralWhite`
- 对题进入 `.correctHold`
- `1.0s` 后自动切到下一题并恢复 `.neutralWhite`
- 新增 `applyPositionPromptProjection(...)`
- 新增 `updateNaturalNoteStripInteractionState()`，在红闪/绿停留期间禁用按钮，避免重复点击
- 新增 `schedulePositionPromptTransition(...)`
- 新增 `PositionPromptTiming`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: handlePositionPromptAnswer(_:), applyPositionPromptProjection(reason:showsLog:),
// updateNaturalNoteStripInteractionState(), schedulePositionPromptTransition(after:perform:),
// synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改后 iOS 控制器已经完整协调位置题交互节奏：
// 错题短红闪后回白圈留在原题；对题变绿停留 1 秒后，shared session 已经推进到下一题，再投影为新的白圈。
private func handlePositionPromptAnswer(_ pitchClass: PitchClass) {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return
    }

    guard currentPositionPromptOverlayPhase == .neutralWhite else {
        print(
            "[PositionPrompt][iOS] result=ignored reason=feedbackInProgress phase=\(positionPromptDebugName(for: currentPositionPromptOverlayPhase))"
        )
        return
    }

    ensurePositionPromptSession()
    guard var positionPromptSession,
          positionPromptSessionMatchesCurrentTrainer(positionPromptSession) else {
        print("[PositionPrompt][iOS] result=ignored reason=missingSession")
        return
    }

    let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
        pitchClass,
        configuration: displayState.configuration,
        session: &positionPromptSession
    )
    self.positionPromptSession = positionPromptSession

    switch answerResult {
    case let .evaluated(evaluation):
        positionPromptLastEvaluation = evaluation
        if evaluation.isCorrect {
            positionPromptOverlayPhase = .correctHold
            applyPositionPromptProjection(
                reason: "correctHold",
                showsLog: false
            )
            schedulePositionPromptTransition(
                after: PositionPromptTiming.correctHoldDuration
            ) { controller in
                guard case .positionPrompt = controller.fretboardTrainerState.mode else {
                    return
                }
                controller.clearPositionPromptFeedbackState()
                controller.positionPromptOverlayPhase = .neutralWhite
                controller.applyPositionPromptProjection(reason: "advanced")
            }
        } else {
            positionPromptOverlayPhase = .wrongFlash
            applyPositionPromptProjection(
                reason: "wrongFlash",
                showsLog: false
            )
            schedulePositionPromptTransition(
                after: PositionPromptTiming.wrongFlashDuration
            ) { controller in
                guard case .positionPrompt = controller.fretboardTrainerState.mode else {
                    return
                }
                controller.clearPositionPromptFeedbackState()
                controller.positionPromptOverlayPhase = .neutralWhite
                controller.applyPositionPromptProjection(
                    reason: "wrongFlashExpired",
                    showsLog: false
                )
            }
        }
    }
}

private func applyPositionPromptProjection(
    reason: String,
    showsLog: Bool = true
) {
    ensurePositionPromptSession()
    applyCurrentFretboardFeedbackOverlayState()
    updateNaturalNoteStripInteractionState()

    guard
        showsLog,
        let positionPromptSession,
        positionPromptSessionMatchesCurrentTrainer(positionPromptSession)
    else {
        return
    }

    let visibleCell = currentPositionPromptOverlayCell(
        for: positionPromptSession
    )
    print(
        "[PositionPrompt][iOS] prompt=\(positionPromptSession.promptPitchClass.displayText()) string=\(visibleCell.stringIndex) fret=\(visibleCell.fret) phase=\(positionPromptDebugName(for: currentPositionPromptOverlayPhase)) state=\(reason)"
    )
}

private func updateNaturalNoteStripInteractionState() {
    guard isViewLoaded else {
        return
    }

    if trainerDisplayState.isPositionPromptMode {
        naturalNoteStripView.isUserInteractionEnabled = currentPositionPromptOverlayPhase == .neutralWhite
    } else {
        naturalNoteStripView.isUserInteractionEnabled = true
    }
}

private func schedulePositionPromptTransition(
    after delay: TimeInterval,
    perform update: @escaping (iOSViewController) -> Void
) {
    cancelPendingPositionPromptTransition()

    let workItem = DispatchWorkItem { [weak self] in
        guard let self else {
            return
        }
        self.pendingPositionPromptTransitionWorkItem = nil
        update(self)
    }
    pendingPositionPromptTransitionWorkItem = workItem
    DispatchQueue.main.asyncAfter(
        deadline: .now() + delay,
        execute: workItem
    )
}

private enum PositionPromptTiming {
    static let wrongFlashDuration: TimeInterval = 0.28
    static let correctHoldDuration: TimeInterval = 1.0
}
```

## 修改 4：在模式切换与其他训练投影中统一取消 position prompt 的待执行任务

### 修改前

- 从第三模式切回 single/sequence 时，没有任何位置题任务清理
- 之前已经排队的红闪恢复或自动下一题任务，理论上仍可能在切走之后继续触发

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: synchronizeSingleTrainerPresentation(reason:), synchronizeQuarterNoteSequencePresentation(reason:)
// 功能说明: 修改前离开第三模式时没有显式取消 position prompt 的延时任务；
// 一旦后续接入红闪/绿停留时序，就会有旧任务残留的风险。
private func synchronizeSingleTrainerPresentation(reason: String) {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        break
    case .positionPrompt, .quarterNoteSequence:
        fretboardTrainerState = FretboardNaturalNoteTrainerState()
        resetSingleCoverageInteractionState()
    }

    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    resetSingleCoverageInteractionState()
    if pageDisplayState.mainContentMode != .fretboard {
        pageDisplayState.setMainContentMode(.fretboard)
    }
    // ...
}
```

### 修改后

- `synchronizeSingleTrainerPresentation(reason:)` 在离开 `.positionPrompt` 前先 `resetPositionPromptInteractionState()`
- `synchronizeQuarterNoteSequencePresentation(reason:)` 也会统一清掉位置题任务
- `synchronizePositionPromptPresentation(reason:)` 在首次进入第三模式时也会先清空旧任务和旧相位

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: synchronizeSingleTrainerPresentation(reason:),
// synchronizePositionPromptPresentation(reason:),
// synchronizeQuarterNoteSequencePresentation(reason:)
// 功能说明: 修改后 iOS 端的 position prompt 延时任务会在模式切换时统一取消，
// 不会让旧题目的红闪或自动推进泄漏到别的训练模式。
private func synchronizeSingleTrainerPresentation(reason: String) {
    if case .positionPrompt = fretboardTrainerState.mode {
        resetPositionPromptInteractionState()
    }

    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        break
    case .positionPrompt, .quarterNoteSequence:
        fretboardTrainerState = FretboardNaturalNoteTrainerState()
        resetSingleCoverageInteractionState()
    }

    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    if case .positionPrompt = fretboardTrainerState.mode {
        // 已在位置题模式内时尽量保留当前 session。
    } else {
        resetPositionPromptInteractionState()
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            positionPromptMode: ()
        )
    }

    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetPositionPromptInteractionState()
    if pageDisplayState.mainContentMode != .fretboard {
        pageDisplayState.setMainContentMode(.fretboard)
    }
    // ...
}
```

## 结果说明

- iOS 第三模式已经能通过底部 7 个自然音按钮作答
- 指板白圈已由控制器根据 `positionPromptSession + overlayPhase` 正常投影
- 错题会短暂红闪并恢复白圈，且停留在当前题
- 对题会变绿并在 1 秒后自动进入下一题
- 在红闪/绿停留期间，底部按钮会被暂时禁用，避免重复输入打乱时序
- 从第三模式切换到 single 或 sequence 时，待执行的延时任务会被统一取消

## 验证说明

- 已对 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift` 运行 `ReadLints`
- 本次改动未发现新增 lint 问题
- 未运行完整 `xcodebuild`

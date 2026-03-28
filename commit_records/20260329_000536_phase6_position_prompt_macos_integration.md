# 20260329_000536_phase6_position_prompt_macos_integration

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_000536`
- 记录范围：实施“位置音名模式”计划的阶段 6，只补 macOS 端完整链路：底部 7 键按钮启停与作答、位置题 session/overlay 相位、错误红闪恢复白圈、正确 1 秒停留后自动推进；不涉及新的 shared 逻辑修改
- 本次目标：让 macOS 与 iOS 保持镜像行为，在第三模式下同样实现“上指板、下自然音按钮，按钮作答，错不换题，对后延时推进”
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 阶段 5 已经把第三模式在 iOS 上完整跑通，但 macOS 仍停留在阶段 4 的“页面结构已切通，交互链路未接通”状态
- 具体缺口有四类：
- `macOSNaturalNoteStripView` 没有面向整条按钮条的启停能力，红闪/绿停留期间无法统一禁用输入
- `macOSViewController` 仍然只维护 single coverage 与 quarter note sequence 的本地交互状态，没有 `positionPromptSession / overlayPhase / delayTask`
- 底部按钮条虽然暴露了 `onPitchClassTap`，但没有接到控制器，也没有位置题专用的按钮作答入口
- `synchronizePositionPromptPresentation(reason:)` 仍然只是阶段 4 的占位版，只负责页面和 mode，不负责白圈投影、错题恢复和对题推进
- 因此阶段 6 的根因级修复，是把 iOS 阶段 5 的位置题链路镜像到 macOS：shared trainer 继续只负责出题/判题，macOS 控制器负责按钮接线、overlay 相位、延时推进与模式切换清理

## 修改 1：给 `macOSNaturalNoteStripView` 增加整组按钮的启停能力

### 修改前

- 按钮条只有 `onPitchClassTap`
- 没有统一的 `areButtonsEnabled`
- 单个按钮的 `isEnabled` 改变后也不会主动刷新外观

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名/符号: macOSNaturalNoteStripView.onPitchClassTap,
// NaturalNoteButton.applyCurrentAppearance()
// 功能说明: 修改前按钮条只负责把点击回调抛给外部；
// 控制器无法在红闪/绿停留期间统一禁用整组按钮，也无法确保禁用态立刻刷新按钮外观。
final class macOSNaturalNoteStripView: NSView {
    var onPitchClassTap: ((PitchClass) -> Void)?

    private let stackView = NSStackView()
    private lazy var buttons: [NaturalNoteButton] = {
        PitchClass.naturalCasesInOrder.map { pitchClass in
            makeButton(for: pitchClass)
        }
    }()

    private func handleButtonTap(_ sender: NaturalNoteButton) {
        guard let pitchClass = sender.pitchClass else {
            return
        }

        onPitchClassTap?(pitchClass)
    }
}

private final class NaturalNoteButton: NSButton {
    var pitchClass: PitchClass?
    private var isPressed = false
}
```

### 修改后

- 新增 `areButtonsEnabled`
- 在按钮条初始化与状态切换时统一调用 `updateButtonEnabledState()`
- `NaturalNoteButton` 重写 `isEnabled`，让禁用/启用时立即刷新视觉状态

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: updateButtonEnabledState(), NaturalNoteButton.isEnabled.didSet
// 功能说明: 修改后 macOS 按钮条可被控制器整体启停；
// 第三模式在红闪/绿停留期间可以临时禁用整组按钮，避免重复点击打乱时序。
final class macOSNaturalNoteStripView: NSView {
    var onPitchClassTap: ((PitchClass) -> Void)?
    var areButtonsEnabled = true {
        didSet {
            updateButtonEnabledState()
        }
    }

    private let stackView = NSStackView()
    private lazy var buttons: [NaturalNoteButton] = {
        PitchClass.naturalCasesInOrder.map { pitchClass in
            makeButton(for: pitchClass)
        }
    }()

    private func configureView() {
        // ... 省略布局初始化 ...
        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }
        updateButtonEnabledState()
    }

    private func updateButtonEnabledState() {
        buttons.forEach { $0.isEnabled = areButtonsEnabled }
    }
}

private final class NaturalNoteButton: NSButton {
    var pitchClass: PitchClass?
    private var isPressed = false

    override var isEnabled: Bool {
        didSet {
            applyCurrentAppearance()
        }
    }
}
```

## 修改 2：在 `macOSViewController` 中新增 position prompt 的本地状态与 overlay 真相

### 修改前

- 控制器顶部状态区只有 single coverage 与 sequence
- `currentFretboardFeedbackOverlayState` 只会在 `.singleNaturalTarget` 下返回 overlay
- 第三模式在 macOS 上没有本地 session、last evaluation、overlay 相位或待取消的延时任务

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: 控制器状态字段, currentFretboardFeedbackOverlayState
// 功能说明: 修改前 macOS 控制器没有位置题的本地运行时状态；
// 即使 shared 层已经支持 positionPrompt，macOS 端也没有白圈/红闪/绿停留的控制器真相源。
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
- 新增 `ensurePositionPromptSession()`、`resetPositionPromptInteractionState()`、`currentPositionPromptOverlayCell(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: positionPromptSession, positionPromptLastEvaluation,
// positionPromptOverlayPhase, pendingPositionPromptTransitionWorkItem,
// currentFretboardFeedbackOverlayState, ensurePositionPromptSession(),
// resetPositionPromptInteractionState(), currentPositionPromptOverlayCell(for:)
// 功能说明: 修改后 macOS 控制器已经具备位置题的本地状态与 overlay 真相；
// shared trainer 继续只做出题/判题，白圈显示哪一格、当前是白/红/绿哪一相位、是否还有待执行的跳题任务，都由控制器协调。
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

## 修改 3：把 macOS 底部自然音按钮条接到位置题作答入口

### 修改前

- `macOSNaturalNoteStripView` 被创建并布局，但控制器没有绑定 `onPitchClassTap`
- 控制器只有指板点击处理，没有“按钮作答位置题”的 macOS 入口
- 第三模式下仍然只是忽略指板点击，没有替代输入通道

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: naturalNoteStripView, handleFretboardTrainerHitResult(_:)
// 功能说明: 修改前 macOS 的底部自然音按钮条没有接到控制器；
// 第三模式页面虽然存在，但用户点击按钮并不会进入 position prompt 判题。
private lazy var naturalNoteStripView: macOSNaturalNoteStripView = {
    let naturalNoteStripView = macOSNaturalNoteStripView()
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
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: naturalNoteStripView, handleNaturalNoteStripPitchClassTap(_:)
// 功能说明: 修改后 macOS 自然音按钮条已接到控制器；
// 第三模式下用户点击底部 C D E F G A B 按钮，就会进入 shared position prompt 判题链路。
private lazy var naturalNoteStripView: macOSNaturalNoteStripView = {
    let naturalNoteStripView = macOSNaturalNoteStripView()
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

## 修改 4：在 macOS 中补齐错题红闪、对题绿停留和自动推进

### 修改前

- `synchronizePositionPromptPresentation(reason:)` 仍然是阶段 4 的占位实现
- 没有 `applyPositionPromptProjection(...)`
- 没有 macOS 平台自己的延时任务调度函数
- 错题后不会红闪，答对后不会 1 秒后推进

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改前 macOS 第三模式同步只切 mode 与页面不变量；
// 还没有白圈投影、按钮禁用、错题恢复和对题推进时序。
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
        // 阶段 4 先只建立 mode 与页面组合的不变量；
        // 具体 session 与按钮作答接线放到后续平台集成阶段。
    } else {
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            positionPromptMode: ()
        )
    }

    applyCurrentFretboardFeedbackOverlayState()
    print(
        "[PositionPrompt][macOS] page=topFretboard/mainNaturalNotes state=\(reason)"
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
- 新增 `updateNaturalNoteStripInteractionState()`，在红闪/绿停留期间禁用底部按钮
- 新增 `schedulePositionPromptTransition(...)`
- 新增 `PositionPromptTiming`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: handlePositionPromptAnswer(_:), applyPositionPromptProjection(reason:showsLog:),
// updateNaturalNoteStripInteractionState(), schedulePositionPromptTransition(after:perform:),
// synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改后 macOS 控制器已经完整协调位置题交互节奏：
// 错题短红闪后回白圈留在原题；对题变绿停留 1 秒后，shared session 已经推进到下一题，再投影为新的白圈。
private func handlePositionPromptAnswer(_ pitchClass: PitchClass) {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return
    }

    guard currentPositionPromptOverlayPhase == .neutralWhite else {
        print(
            "[PositionPrompt][macOS] result=ignored reason=feedbackInProgress phase=\(positionPromptDebugName(for: currentPositionPromptOverlayPhase))"
        )
        return
    }

    ensurePositionPromptSession()
    guard var positionPromptSession,
          positionPromptSessionMatchesCurrentTrainer(positionPromptSession) else {
        print("[PositionPrompt][macOS] result=ignored reason=missingSession")
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
        "[PositionPrompt][macOS] prompt=\(positionPromptSession.promptPitchClass.displayText()) string=\(visibleCell.stringIndex) fret=\(visibleCell.fret) phase=\(positionPromptDebugName(for: currentPositionPromptOverlayPhase)) state=\(reason)"
    )
}

private func updateNaturalNoteStripInteractionState() {
    guard isViewLoaded else {
        return
    }

    if trainerDisplayState.isPositionPromptMode {
        naturalNoteStripView.areButtonsEnabled = currentPositionPromptOverlayPhase == .neutralWhite
    } else {
        naturalNoteStripView.areButtonsEnabled = true
    }
}

private func schedulePositionPromptTransition(
    after delay: TimeInterval,
    perform update: @escaping (macOSViewController) -> Void
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

## 修改 5：在模式切换与其他训练投影中统一取消 position prompt 的待执行任务

### 修改前

- 从第三模式切回 single/sequence 时，没有显式清理 position prompt 的延时任务
- 旧的红闪恢复或自动下一题任务，理论上仍可能在切走之后继续触发

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizeSingleTrainerPresentation(reason:),
// synchronizeQuarterNoteSequencePresentation(reason:)
// 功能说明: 修改前离开第三模式时没有显式取消 position prompt 的延时任务；
// 一旦接入红闪/绿停留时序，就会有旧任务残留的风险。
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
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizeSingleTrainerPresentation(reason:),
// synchronizePositionPromptPresentation(reason:),
// synchronizeQuarterNoteSequencePresentation(reason:)
// 功能说明: 修改后 macOS 端的 position prompt 延时任务会在模式切换时统一取消，
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

- macOS 第三模式已经能通过底部 7 个自然音按钮作答
- 指板白圈已由控制器根据 `positionPromptSession + overlayPhase` 正常投影
- 错题会短暂红闪并恢复白圈，且停留在当前题
- 对题会变绿并在 1 秒后自动进入下一题
- 在红闪/绿停留期间，底部按钮会被暂时禁用，避免重复输入打乱时序
- 从第三模式切换到 single 或 sequence 时，待执行的延时任务会被统一取消
- iOS 与 macOS 现在在位置音名模式上的结构与命名已经基本保持镜像

## 验证说明

- 已对 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift` 与 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift` 运行 `ReadLints`
- 本次改动未发现新增 lint 问题
- 未运行完整 `xcodebuild`

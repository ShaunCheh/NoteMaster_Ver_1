# 20260327_113633_phase4_quarter_note_controller_score_wiring

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260327_113633`
- 记录范围：随机四分音训练阶段 4，controller 谱面接线
- 本次目标：把 `QuarterNoteSequencePrompt` 落到双平台现有的 `staffDisplayState.score` 渲染链路上，最小接线点包括同步 `staffDisplayState.configuration.clef`、写入 `staffDisplayState.score`、复用现有 `applyStaffDisplayState()`，同时避免四分音模式误走旧的单目标 trainer 判题路径
- 根因结论：阶段 1 到阶段 3 已经有了 quarter-note sequence 的 shared 输出、边界收口和自动化验证，但双平台 controller 仍然只认识旧的 `singleNaturalTarget` 流程。结果就是 `QuarterNoteSequencePrompt` 虽然能生成，却没有被投影到 `StaffDisplayState`，而且指板点击还会直接调用旧 `handle(hitResult:configuration:)`，在 `.quarterNoteSequence` 模式下触发 precondition 风险
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 在 `StaffDisplayState` 新增 `apply(quarterNoteSequencePrompt:)`，把 quarter-note prompt 投影到统一的 shared staff 显示状态。
2. 在 `iOSViewController` 新增 quarter-note 模式识别、内部启动入口、谱面落地 helper 和 settings 归一化逻辑。
3. 在 `macOSViewController` 做了与 iOS 对称的接线，保持双平台行为一致。
4. 双平台都对 `handleFretboardTrainerHitResult(_:)` 做了模式分流：旧单目标模式继续走原有判题，quarter-note 模式先走 `pendingAnswerFlow` 日志分支，避免阶段 5 之前误触发旧路径。

## 修改 1：`StaffDisplayState` 增加 quarter-note prompt 到 staff 状态的 shared 适配点

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数: apply(_ event: StaffControlEvent)
// 功能说明: 修改前 StaffDisplayState 只认识 staff 控件事件，
// controller 若要接 quarter-note prompt，只能在平台层手写 clef / score 同步。
extension StaffDisplayState {
    mutating func apply(_ event: StaffControlEvent) {
        event.apply(to: &self)
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数: apply(_ event: StaffControlEvent), apply(quarterNoteSequencePrompt:)
// 功能说明: 修改后 quarter-note 谱面写入也收口到 StaffDisplayState，
// controller 只负责调用 shared 适配点，不再分散同步 clef 与 score。
extension StaffDisplayState {
    mutating func apply(_ event: StaffControlEvent) {
        event.apply(to: &self)
    }

    // quarter-note sequence 的谱面仍然落到统一的 StaffDisplayState，
    // 控制器只需要通过这个适配点同步 clef 与 score。
    mutating func apply(
        quarterNoteSequencePrompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt
    ) {
        configuration.clef = quarterNoteSequencePrompt.spec.clef
        score = quarterNoteSequencePrompt.score
    }
}
```

## 修改 2：`iOSViewController` 增加 quarter-note 模式识别，并在页面 apply 时避免覆盖 staff 顶部内容

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数: currentFretboardTrainerPrompt, applyPageDisplayState()
// 功能说明: 修改前 controller 只认识旧单目标 prompt，
// applyPageDisplayState() 每次都会把 targetNotePromptView 重新同步成单目标显示。
private var currentFretboardTrainerPrompt: FretboardNaturalNoteTrainerState.Prompt {
    fretboardTrainerState.prompt
}

private func applyPageDisplayState() {
    targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()

    if isShowingFretboardMainContent {
        syncVerticalFretboardContentWidthConstraint()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数: currentQuarterNoteSequencePrompt, isQuarterNoteSequenceMode, applyPageDisplayState()
// 功能说明: 修改后 controller 能识别 quarter-note 模式，
// 并在该模式下避免把顶部区域重新刷回旧 target prompt 视图。
private var currentQuarterNoteSequencePrompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt? {
    guard case .quarterNoteSequence = fretboardTrainerState.mode else {
        return nil
    }

    return fretboardTrainerState.quarterNoteSequencePrompt
}

private var isQuarterNoteSequenceMode: Bool {
    guard case .quarterNoteSequence = fretboardTrainerState.mode else {
        return false
    }

    return true
}

private func applyPageDisplayState() {
    if !isQuarterNoteSequenceMode {
        targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    }
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()

    if isShowingFretboardMainContent {
        syncVerticalFretboardContentWidthConstraint()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
}
```

## 修改 3：`iOSViewController` 增加内部启动入口、指板点击分流和 settings 归一化

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数: handleFretboardTrainerHitResult(_:), applyFretboardTrainerPrompt(reason:), handleSettingsPanelEvent(_:)
// 功能说明: 修改前所有指板点击都直接进入旧 singleNaturalTarget handle(...)；
// applyFretboardTrainerPrompt 后面也没有 quarter-note 启动入口或 settings 归一化逻辑。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
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

private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    targetNotePromptView.apply(prompt: prompt)
    print(
        "[FretboardTrainer][iOS] target=\(prompt.displayText) state=\(reason)"
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    // ... 下方仍是 didChangeFretboard / didChangeStaff / didChangePage 分发
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数: handleFretboardTrainerHitResult(_:), handleQuarterNoteSequenceHitResult(_:),
// startQuarterNoteSequenceExercise(with:), applyQuarterNoteSequencePromptToStaff(_:reason:),
// normalizeSettingsPanelStateContextForTrainerMode(_:), handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS controller 会把 quarter-note 模式分流到独立分支，
// 通过内部入口生成 prompt 并把它投影到 StaffDisplayState，同时在 settings 事件后强制保持 staff 顶部内容与当前谱面真相一致。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        handleSingleNaturalTargetHitResult(hitResult)
    case .quarterNoteSequence:
        handleQuarterNoteSequenceHitResult(hitResult)
    }
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    guard hitResult.phase == .ended else {
        return
    }

    guard let prompt = currentQuarterNoteSequencePrompt else {
        print(
            "[QuarterNoteSequence][iOS] result=ignored reason=missingPrompt"
        )
        return
    }

    let locationSuffix: String
    if let cell = hitResult.cell {
        locationSuffix = " string=\(cell.stringIndex) fret=\(cell.fret)"
    } else {
        locationSuffix = " missingHitCell=true"
    }

    print(
        "[QuarterNoteSequence][iOS] clef=\(prompt.spec.clef.title) noteCount=\(prompt.spec.noteCount) includesAccidentals=\(prompt.spec.includesAccidentals) result=ignored reason=pendingAnswerFlow\(locationSuffix)"
    )
}

func startQuarterNoteSequenceExercise(
    with spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
) {
    fretboardTrainerState = FretboardNaturalNoteTrainerState(
        quarterNoteSequenceSpec: spec
    )
    let prompt = fretboardTrainerState.generateQuarterNoteSequencePrompt()
    applyQuarterNoteSequencePromptToStaff(prompt, reason: "generated")
}

private func applyQuarterNoteSequencePromptToStaff(
    _ prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt,
    reason: String
) {
    var nextPageDisplayState = pageDisplayState
    nextPageDisplayState.topContentMode = .staff

    var nextStaffDisplayState = staffDisplayState
    nextStaffDisplayState.apply(quarterNoteSequencePrompt: prompt)

    if nextPageDisplayState != pageDisplayState {
        pageDisplayState = nextPageDisplayState
    }

    if nextStaffDisplayState != staffDisplayState {
        staffDisplayState = nextStaffDisplayState
    }

    print(
        "[QuarterNoteSequence][iOS] clef=\(prompt.spec.clef.title) noteCount=\(prompt.spec.noteCount) includesAccidentals=\(prompt.spec.includesAccidentals) state=\(reason)"
    )
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard isQuarterNoteSequenceMode else {
        return
    }

    stateContext.pageDisplayState.topContentMode = .staff

    if let currentQuarterNoteSequencePrompt {
        stateContext.staffDisplayState.apply(
            quarterNoteSequencePrompt: currentQuarterNoteSequencePrompt
        )
    }
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)
    // ... 下方仍是 didChangeFretboard / didChangeStaff / didChangePage 分发
}
```

## 修改 4：`macOSViewController` 做与 iOS 对称的 quarter-note 谱面接线

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: applyPageDisplayState(), handleFretboardTrainerHitResult(_:), handleSettingsPanelEvent(_:)
// 功能说明: 修改前 macOS 侧与 iOS 一样，只有旧 singleNaturalTarget 路径；
// 顶部 prompt 会始终被旧逻辑覆盖，settings 事件后也不会自动回写当前 quarter-note 谱面。
private func applyPageDisplayState() {
    targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()

    if isShowingFretboardMainContent {
        syncVerticalFretboardContentSizeConstraints()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
}

private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.handle(
        hitResult: hitResult,
        configuration: displayState.configuration
    ) {
    case .ignored(.nonEndedPhase):
        return
    case .ignored(.missingHitCell):
        print(
            "[FretboardTrainer][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
        )
    case let .ignored(.unresolvedHitPitch(cell)):
        print(
            "[FretboardTrainer][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
        )
    case let .evaluated(evaluation):
        print("[macOS] \(evaluation.debugSummary())")
        if evaluation.didAdvanceTarget {
            applyFretboardTrainerPrompt(reason: "advanced")
        }
    }
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    // ... 下方仍是 didChangeFretboard / didChangeStaff / didChangePage 分发
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: currentQuarterNoteSequencePrompt, applyPageDisplayState(),
// handleQuarterNoteSequenceHitResult(_:), startQuarterNoteSequenceExercise(with:),
// applyQuarterNoteSequencePromptToStaff(_:reason:), normalizeSettingsPanelStateContextForTrainerMode(_:),
// handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS 与 iOS 保持对称：
// 同样能识别 quarter-note 模式、落地谱面、分流点击，并在 settings 事件后回写当前 clef / score。
private var currentQuarterNoteSequencePrompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt? {
    guard case .quarterNoteSequence = fretboardTrainerState.mode else {
        return nil
    }

    return fretboardTrainerState.quarterNoteSequencePrompt
}

private func applyPageDisplayState() {
    if !isQuarterNoteSequenceMode {
        targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    }
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    updateLayoutIfNeeded()

    if isShowingFretboardMainContent {
        syncVerticalFretboardContentSizeConstraints()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
}

private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        handleSingleNaturalTargetHitResult(hitResult)
    case .quarterNoteSequence:
        handleQuarterNoteSequenceHitResult(hitResult)
    }
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    guard hitResult.phase == .ended else {
        return
    }

    guard let prompt = currentQuarterNoteSequencePrompt else {
        print(
            "[QuarterNoteSequence][macOS] result=ignored reason=missingPrompt"
        )
        return
    }

    let locationSuffix: String
    if let cell = hitResult.cell {
        locationSuffix = " string=\(cell.stringIndex) fret=\(cell.fret)"
    } else {
        locationSuffix = " missingHitCell=true"
    }

    print(
        "[QuarterNoteSequence][macOS] clef=\(prompt.spec.clef.title) noteCount=\(prompt.spec.noteCount) includesAccidentals=\(prompt.spec.includesAccidentals) result=ignored reason=pendingAnswerFlow\(locationSuffix)"
    )
}

func startQuarterNoteSequenceExercise(
    with spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
) {
    fretboardTrainerState = FretboardNaturalNoteTrainerState(
        quarterNoteSequenceSpec: spec
    )
    let prompt = fretboardTrainerState.generateQuarterNoteSequencePrompt()
    applyQuarterNoteSequencePromptToStaff(prompt, reason: "generated")
}

private func applyQuarterNoteSequencePromptToStaff(
    _ prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt,
    reason: String
) {
    var nextPageDisplayState = pageDisplayState
    nextPageDisplayState.topContentMode = .staff

    var nextStaffDisplayState = staffDisplayState
    nextStaffDisplayState.apply(quarterNoteSequencePrompt: prompt)

    if nextPageDisplayState != pageDisplayState {
        pageDisplayState = nextPageDisplayState
    }

    if nextStaffDisplayState != staffDisplayState {
        staffDisplayState = nextStaffDisplayState
    }

    print(
        "[QuarterNoteSequence][macOS] clef=\(prompt.spec.clef.title) noteCount=\(prompt.spec.noteCount) includesAccidentals=\(prompt.spec.includesAccidentals) state=\(reason)"
    )
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard isQuarterNoteSequenceMode else {
        return
    }

    stateContext.pageDisplayState.topContentMode = .staff

    if let currentQuarterNoteSequencePrompt {
        stateContext.staffDisplayState.apply(
            quarterNoteSequencePrompt: currentQuarterNoteSequencePrompt
        )
    }
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)
    // ... 下方仍是 didChangeFretboard / didChangeStaff / didChangePage 分发
}
```

## 验证结果

- `ReadLints`：`NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`、`NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`、`NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift` 无新增诊断
- `git status --short`：本阶段实际代码改动只落在 `StaffDisplayState`、`iOSViewController`、`macOSViewController`
- `xcodebuild`：本地环境仍然缺少可用的 Xcode developer directory，本次未执行完整编译验证

## 结果

- `QuarterNoteSequencePrompt` 已经可以通过 controller 内部入口落到现有五线谱渲染链路
- 双平台 settings 事件在 quarter-note 模式下会自动回写当前 `staff` 顶部内容与 `clef / score`
- 指板点击在 quarter-note 模式下已不再误走旧单目标 trainer 逻辑；真正的顺序判题仍留在后续阶段

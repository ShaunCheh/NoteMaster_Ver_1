# 20260327_114800_phase5_quarter_note_sequence_answer_flow

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260327_114800`
- 记录范围：随机四分音训练阶段 5，顺序判题与指板答题接线
- 本次目标：实现 `QuarterNoteSequenceSession.currentIndex` 与 `handleQuarterNoteSequenceAnswer(_:)`，按 `expectedPitchClasses` 顺序判题；继续复用当前指板点击作为输入源，并把双平台 controller 的 quarter-note 分支从“仅打印 pending 日志”升级为真正的答题闭环
- 根因结论：阶段 4 已经能把随机四分音序列显示到五线谱上，但 shared 层仍然只有 `QuarterNoteSequenceSession` 壳结构和 `handleQuarterNoteSequenceAnswer(_:)` stub，controller 侧也只会在 quarter-note 模式打印 `pendingAnswerFlow`。这意味着谱面虽然能显示，但训练还不能真正进入“按顺序作答、答对推进、答错停留、答完完成”的状态机
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 在 `FretboardNaturalNoteTrainerState` 内实现 quarter-note sequence 的 shared 顺序判题状态机。
2. 在 `FretboardValidationRunner` 内补上 session 初始状态、错误作答、正确作答、完成态和 completed 后继续作答的共享回归。
3. 在 `iOSViewController` 内新增 `quarterNoteSequenceSession` 真相源，并把指板点击接入 shared 判题。
4. 在 `macOSViewController` 做与 iOS 对称的 session 与答题接线。
5. quarter-note 模式下继续强制页面保持 `topContent = staff` 且 `mainContent = fretboard`，避免 settings 把答题输入源切走。

## 修改 1：`FretboardNaturalNoteTrainerState` 从 stub 升级为真正的顺序判题状态机

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: QuarterNoteSequenceSession, QuarterNoteSequenceAnswerResult, makeQuarterNoteSequenceSession(), handleQuarterNoteSequenceAnswer(_:session:)
// 功能说明: 修改前 session 只有 prompt + currentIndex 两个字段；
// answer result 仍是 pendingImplementation；handleQuarterNoteSequenceAnswer 还没有真正判题逻辑。
struct QuarterNoteSequenceSession: Equatable, Sendable {
    var prompt: QuarterNoteSequencePrompt
    var currentIndex: Int

    init(
        prompt: QuarterNoteSequencePrompt,
        currentIndex: Int = 0
    ) {
        precondition(
            currentIndex >= 0 && currentIndex <= prompt.expectedPitchClasses.count,
            "Quarter-note sequence session index must stay within the prompt range."
        )
        self.prompt = prompt
        self.currentIndex = currentIndex
    }
}

enum QuarterNoteSequenceAnswerResult: Equatable, Sendable {
    case pendingImplementation
}

func makeQuarterNoteSequenceSession() -> QuarterNoteSequenceSession {
    guard let quarterNoteSequencePrompt else {
        preconditionFailure(
            "Generate a quarter-note sequence prompt before creating a session."
        )
    }

    return QuarterNoteSequenceSession(prompt: quarterNoteSequencePrompt)
}

mutating func handleQuarterNoteSequenceAnswer(
    _ pitchClass: PitchClass,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult {
    let _ = pitchClass
    let _ = session
    preconditionFailure(
        "Quarter-note sequence answering will be implemented in a later step."
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: QuarterNoteSequenceSession, QuarterNoteSequenceIgnoreReason, QuarterNoteSequenceEvaluation,
// QuarterNoteSequenceAnswerResult, makeQuarterNoteSequenceSession(), handleQuarterNoteSequenceAnswer(_:session:), requireCurrentQuarterNoteSequencePrompt(_:)
// 功能说明: 修改后 shared trainer 能真正按 expectedPitchClasses 顺序判题：
// 答对推进 currentIndex，答错停留当前题，答完整个序列后进入 completed 状态。
struct QuarterNoteSequenceSession: Equatable, Sendable {
    var prompt: QuarterNoteSequencePrompt
    var currentIndex: Int

    init(
        prompt: QuarterNoteSequencePrompt,
        currentIndex: Int = 0
    ) {
        precondition(
            currentIndex >= 0 && currentIndex <= prompt.expectedPitchClasses.count,
            "Quarter-note sequence session index must stay within the prompt range."
        )
        self.prompt = prompt
        self.currentIndex = currentIndex
    }

    var totalCount: Int {
        prompt.expectedPitchClasses.count
    }

    var answeredCount: Int {
        currentIndex
    }

    var remainingCount: Int {
        max(totalCount - currentIndex, 0)
    }

    var isCompleted: Bool {
        currentIndex >= totalCount
    }

    var currentExpectedPitchClass: PitchClass? {
        guard !isCompleted else {
            return nil
        }

        return prompt.expectedPitchClasses[currentIndex]
    }
}

enum QuarterNoteSequenceIgnoreReason: Equatable, Sendable {
    case completedSession
}

struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
    var expectedPitchClass: PitchClass
    var answeredPitchClass: PitchClass
    var answeredIndex: Int
    var nextIndex: Int
    var totalCount: Int

    var isCorrect: Bool {
        answeredPitchClass == expectedPitchClass
    }

    var didAdvanceIndex: Bool {
        isCorrect
    }

    var isSequenceCompleted: Bool {
        nextIndex >= totalCount
    }

    var remainingCount: Int {
        max(totalCount - nextIndex, 0)
    }

    func debugSummary() -> String {
        let resultText = isCorrect ? "correct" : "wrong"
        let stateText = isSequenceCompleted ? "completed" : "inProgress"
        return "[QuarterNoteSequence] step=\(answeredIndex + 1)/\(totalCount) expected=\(expectedPitchClass.displayText()) answered=\(answeredPitchClass.displayText()) result=\(resultText) nextIndex=\(nextIndex) remaining=\(remainingCount) state=\(stateText)"
    }
}

enum QuarterNoteSequenceAnswerResult: Equatable, Sendable {
    case ignored(QuarterNoteSequenceIgnoreReason)
    case evaluated(QuarterNoteSequenceEvaluation)
}

func makeQuarterNoteSequenceSession() -> QuarterNoteSequenceSession {
    QuarterNoteSequenceSession(prompt: requireCurrentQuarterNoteSequencePrompt())
}

mutating func handleQuarterNoteSequenceAnswer(
    _ pitchClass: PitchClass,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult {
    let prompt = requireCurrentQuarterNoteSequencePrompt()
    precondition(
        session.prompt == prompt,
        "Quarter-note sequence session prompt must match the current trainer prompt."
    )

    guard let expectedPitchClass = session.currentExpectedPitchClass else {
        return .ignored(.completedSession)
    }

    let answeredIndex = session.currentIndex
    let isCorrect = pitchClass == expectedPitchClass
    let nextIndex = isCorrect ? answeredIndex + 1 : answeredIndex
    if isCorrect {
        session.currentIndex = nextIndex
    }

    return .evaluated(
        QuarterNoteSequenceEvaluation(
            expectedPitchClass: expectedPitchClass,
            answeredPitchClass: pitchClass,
            answeredIndex: answeredIndex,
            nextIndex: nextIndex,
            totalCount: session.totalCount
        )
    )
}
```

## 修改 2：`FretboardValidation` 补上 quarter-note 顺序判题回归

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改前 validation 只验证 prompt 生成、mode 落地和 session 初始 currentIndex；
// 还没有覆盖错误作答、正确作答、完成态和 completed 后继续作答。
let naturalSession = naturalTrainer.makeQuarterNoteSequenceSession()
if naturalSession.prompt != naturalPrompt {
    record("quarter-note trainer 生成的 session prompt 与最近一次 prompt 不一致。")
}
if naturalSession.currentIndex != 0 {
    record("quarter-note trainer 新建 session 的 currentIndex 应为 0。")
}

let accidentalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
    clef: .bass,
    noteCount: 128,
    includesAccidentals: true
)
// ... 下方仍是 accidental prompt 与 mode 持久化检查
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后 validation 会覆盖 session 初始值、错误作答不推进、正确作答推进、
// 全部答完进入 completed、completed 后继续作答返回 ignored(.completedSession)。
let naturalSession = naturalTrainer.makeQuarterNoteSequenceSession()
if naturalSession.prompt != naturalPrompt {
    record("quarter-note trainer 生成的 session prompt 与最近一次 prompt 不一致。")
}
if naturalSession.currentIndex != 0 {
    record("quarter-note trainer 新建 session 的 currentIndex 应为 0。")
}
if naturalSession.totalCount != naturalPrompt.expectedPitchClasses.count {
    record("quarter-note trainer 新建 session 的 totalCount 与 prompt 不一致。")
}
if naturalSession.answeredCount != 0 || naturalSession.remainingCount != naturalSession.totalCount {
    record("quarter-note trainer 新建 session 的 answeredCount / remainingCount 初始值错误。")
}
if naturalSession.isCompleted {
    record("quarter-note trainer 新建 session 不应直接处于 completed 状态。")
}
if naturalSession.currentExpectedPitchClass != naturalPrompt.expectedPitchClasses.first {
    record("quarter-note trainer 新建 session 的 currentExpectedPitchClass 未对齐首个答案。")
}

guard let firstExpectedPitchClass = naturalPrompt.expectedPitchClasses.first else {
    record("quarter-note trainer natural prompt 缺少首个 expectedPitchClass。")
    return
}

let incorrectPitchClass = PitchClass.allCases.first { candidate in
    candidate != firstExpectedPitchClass
}
guard let incorrectPitchClass else {
    record("quarter-note trainer 无法构造与首题不同的错误答案。")
    return
}

var incorrectSession = naturalSession
switch naturalTrainer.handleQuarterNoteSequenceAnswer(
    incorrectPitchClass,
    session: &incorrectSession
) {
case let .evaluated(evaluation):
    if evaluation.expectedPitchClass != firstExpectedPitchClass {
        record("quarter-note trainer 错误作答时返回的 expectedPitchClass 与 session 首题不一致。")
    }
    if evaluation.answeredPitchClass != incorrectPitchClass {
        record("quarter-note trainer 错误作答时返回的 answeredPitchClass 不一致。")
    }
    if evaluation.isCorrect {
        record("quarter-note trainer 把错误答案误判成了正确。")
    }
    if evaluation.didAdvanceIndex {
        record("quarter-note trainer 错误作答后不应推进 currentIndex。")
    }
default:
    record("quarter-note trainer 错误作答未返回 evaluated 结果。")
}

var completedSession = naturalSession
for (index, expectedPitchClass) in naturalPrompt.expectedPitchClasses.enumerated() {
    switch naturalTrainer.handleQuarterNoteSequenceAnswer(
        expectedPitchClass,
        session: &completedSession
    ) {
    case let .evaluated(evaluation):
        let expectedNextIndex = index + 1
        let shouldComplete = expectedNextIndex == naturalPrompt.expectedPitchClasses.count
        if !evaluation.isCorrect || !evaluation.didAdvanceIndex {
            record("quarter-note trainer 正确作答后没有推进到下一题。")
        }
        if evaluation.isSequenceCompleted != shouldComplete {
            record("quarter-note trainer 的完成态判断与最后一题边界不一致。")
        }
    default:
        record("quarter-note trainer 正确作答未返回 evaluated 结果。")
        return
    }
}

if !completedSession.isCompleted {
    record("quarter-note trainer 回答完整个序列后应进入 completed 状态。")
}
if completedSession.currentExpectedPitchClass != nil {
    record("quarter-note trainer 完成序列后 currentExpectedPitchClass 应为空。")
}
if naturalTrainer.handleQuarterNoteSequenceAnswer(
    firstExpectedPitchClass,
    session: &completedSession
) != .ignored(.completedSession) {
    record("quarter-note trainer 完成序列后继续作答应返回 ignored(.completedSession)。")
}
```

## 修改 3：`iOSViewController` 从 pending 日志分支接成真正的顺序答题链路

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: handleQuarterNoteSequenceHitResult(_:), applyFretboardTrainerPrompt(reason:), startQuarterNoteSequenceExercise(with:), applyQuarterNoteSequencePromptToStaff(_:reason:), normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改前 iOS 在 quarter-note 模式下只打印 pendingAnswerFlow 日志；
// 没有 session 真相源，也没有真正调用 shared answer API。
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

private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    targetNotePromptView.apply(prompt: prompt)
    print(
        "[FretboardTrainer][iOS] target=\(prompt.displayText) state=\(reason)"
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
    // ... 下方仍是写入 staffDisplayState 并打印生成日志
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard isQuarterNoteSequenceMode else {
        return
    }

    stateContext.pageDisplayState.topContentMode = .staff
    // ... 下方仍是把当前 prompt 投影到 staffDisplayState
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: quarterNoteSequenceSession, handleQuarterNoteSequenceHitResult(_:),
// applyFretboardTrainerPrompt(reason:), startQuarterNoteSequenceExercise(with:),
// applyQuarterNoteSequencePromptToStaff(_:reason:), normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改后 iOS 用 quarterNoteSequenceSession 作为顺序答题真相源，
// 指板命中后先解析 NotePitch，再调用 shared answer API，并在 quarter-note 模式下强制保持 fretboard 作为输入源。
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    guard hitResult.phase == .ended else {
        return
    }

    guard let selectedCell = hitResult.cell else {
        print(
            "[QuarterNoteSequence][iOS] result=ignored reason=missingHitCell"
        )
        return
    }

    guard let selectedPitch = displayState.configuration.notePitch(for: selectedCell) else {
        print(
            "[QuarterNoteSequence][iOS] result=ignored reason=unresolvedHitPitch string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
        )
        return
    }

    guard currentQuarterNoteSequencePrompt != nil else {
        print(
            "[QuarterNoteSequence][iOS] result=ignored reason=missingPrompt"
        )
        return
    }

    if quarterNoteSequenceSession == nil {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    guard var quarterNoteSequenceSession else {
        print(
            "[QuarterNoteSequence][iOS] result=ignored reason=missingSession"
        )
        return
    }

    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        selectedPitch.pitchClass,
        session: &quarterNoteSequenceSession
    )
    self.quarterNoteSequenceSession = quarterNoteSequenceSession

    switch answerResult {
    case .ignored(.completedSession):
        print(
            "[QuarterNoteSequence][iOS] result=ignored reason=completedSession string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
        )
    case let .evaluated(evaluation):
        print(
            "[iOS] \(evaluation.debugSummary()) selected=\(selectedPitch.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
        )
    }
}

private func applyFretboardTrainerPrompt(reason: String) {
    quarterNoteSequenceSession = nil
    let prompt = currentFretboardTrainerPrompt
    targetNotePromptView.apply(prompt: prompt)
    print(
        "[FretboardTrainer][iOS] target=\(prompt.displayText) state=\(reason)"
    )
}

func startQuarterNoteSequenceExercise(
    with spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
) {
    fretboardTrainerState = FretboardNaturalNoteTrainerState(
        quarterNoteSequenceSpec: spec
    )
    let prompt = fretboardTrainerState.generateQuarterNoteSequencePrompt()
    quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    applyQuarterNoteSequencePromptToStaff(prompt, reason: "generated")
}

private func applyQuarterNoteSequencePromptToStaff(
    _ prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt,
    reason: String
) {
    var nextPageDisplayState = pageDisplayState
    nextPageDisplayState.topContentMode = .staff
    nextPageDisplayState.mainContentMode = .fretboard
    // ... 下方仍是写入 staffDisplayState 并打印生成日志
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard isQuarterNoteSequenceMode else {
        return
    }

    stateContext.pageDisplayState.topContentMode = .staff
    stateContext.pageDisplayState.mainContentMode = .fretboard
    // ... 下方仍是把当前 prompt 投影到 staffDisplayState
}
```

## 修改 4：`macOSViewController` 做与 iOS 对称的 session 与答题接线

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: handleQuarterNoteSequenceHitResult(_:), applyFretboardTrainerPrompt(reason:),
// startQuarterNoteSequenceExercise(with:), applyQuarterNoteSequencePromptToStaff(_:reason:),
// normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改前 macOS 侧与 iOS 一样，只停留在 pendingAnswerFlow 日志阶段，
// 还没有 session 真相源与真正的 shared 判题调用。
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

private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    targetNotePromptView.apply(prompt: prompt)
    print(
        "[FretboardTrainer][macOS] target=\(prompt.displayText) state=\(reason)"
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: quarterNoteSequenceSession, handleQuarterNoteSequenceHitResult(_:),
// applyFretboardTrainerPrompt(reason:), startQuarterNoteSequenceExercise(with:),
// applyQuarterNoteSequencePromptToStaff(_:reason:), normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改后 macOS 与 iOS 保持对称：
// 同样通过 quarterNoteSequenceSession 接管顺序答题，并继续强制 fretboard 作为 quarter-note 模式下的输入源。
private var quarterNoteSequenceSession: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession?

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    guard hitResult.phase == .ended else {
        return
    }

    guard let selectedCell = hitResult.cell else {
        print(
            "[QuarterNoteSequence][macOS] result=ignored reason=missingHitCell"
        )
        return
    }

    guard let selectedPitch = displayState.configuration.notePitch(for: selectedCell) else {
        print(
            "[QuarterNoteSequence][macOS] result=ignored reason=unresolvedHitPitch string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
        )
        return
    }

    guard currentQuarterNoteSequencePrompt != nil else {
        print(
            "[QuarterNoteSequence][macOS] result=ignored reason=missingPrompt"
        )
        return
    }

    if quarterNoteSequenceSession == nil {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    guard var quarterNoteSequenceSession else {
        print(
            "[QuarterNoteSequence][macOS] result=ignored reason=missingSession"
        )
        return
    }

    let answerResult = fretboardTrainerState.handleQuarterNoteSequenceAnswer(
        selectedPitch.pitchClass,
        session: &quarterNoteSequenceSession
    )
    self.quarterNoteSequenceSession = quarterNoteSequenceSession

    switch answerResult {
    case .ignored(.completedSession):
        print(
            "[QuarterNoteSequence][macOS] result=ignored reason=completedSession string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
        )
    case let .evaluated(evaluation):
        print(
            "[macOS] \(evaluation.debugSummary()) selected=\(selectedPitch.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret)"
        )
    }
}

private func applyFretboardTrainerPrompt(reason: String) {
    quarterNoteSequenceSession = nil
    let prompt = currentFretboardTrainerPrompt
    targetNotePromptView.apply(prompt: prompt)
    print(
        "[FretboardTrainer][macOS] target=\(prompt.displayText) state=\(reason)"
    )
}

func startQuarterNoteSequenceExercise(
    with spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
) {
    fretboardTrainerState = FretboardNaturalNoteTrainerState(
        quarterNoteSequenceSpec: spec
    )
    let prompt = fretboardTrainerState.generateQuarterNoteSequencePrompt()
    quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    applyQuarterNoteSequencePromptToStaff(prompt, reason: "generated")
}

private func applyQuarterNoteSequencePromptToStaff(
    _ prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt,
    reason: String
) {
    var nextPageDisplayState = pageDisplayState
    nextPageDisplayState.topContentMode = .staff
    nextPageDisplayState.mainContentMode = .fretboard
    // ... 下方仍是写入 staffDisplayState 并打印生成日志
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard isQuarterNoteSequenceMode else {
        return
    }

    stateContext.pageDisplayState.topContentMode = .staff
    stateContext.pageDisplayState.mainContentMode = .fretboard
    // ... 下方仍是把当前 prompt 投影到 staffDisplayState
}
```

## 验证结果

- `ReadLints`：`NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`、`NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`、`NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`、`NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift` 无新增诊断
- `rg "pendingImplementation|pendingAnswerFlow"`：无残留旧 stub / 旧 pending 日志分支
- `git status --short`：本阶段实际代码改动只落在 `FretboardNaturalNoteTrainer.swift`、`FretboardValidation.swift`、`iOSViewController.swift`、`macOSViewController.swift`
- `xcodebuild`：本地环境仍然缺少可用的 Xcode developer directory，本次未执行完整编译验证

## 结果

- quarter-note sequence 已从“仅生成谱面”升级为“可按顺序作答”的完整 shared 训练模式
- 双平台继续复用现有指板点击作为输入源，不需要新增 UI 组件就能进入顺序判题
- settings 在 quarter-note 模式下会继续保持 `staff + fretboard` 的答题页面结构，避免输入链路被切断

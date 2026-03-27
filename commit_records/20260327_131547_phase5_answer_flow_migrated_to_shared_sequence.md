# 20260327_131547_phase5_answer_flow_migrated_to_shared_sequence

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_131547`
- 记录范围：统一序列真相源阶段 5，把顺序判题状态机迁移到共享序列真相源上，并保持 `prompt / staff / session` 同步
- 本次目标：让 quarter-note sequence 的判题、当前题索引、目标音组件显示、五线谱投影都围绕同一份 `GeneratedNoteSequence` 运转，而不是继续把旧 `QuarterNoteSequencePrompt` 壳当作状态机根
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift`
- `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 根因结论

- 阶段4虽然已经把“同一份序列 -> `prompt / staff` 二选一投影”接到了 controller，但顺序判题状态机本身仍然绑在 `QuarterNoteSequencePrompt` 上：`QuarterNoteSequenceSession` 保存的是 `prompt`，controller 也在用 `currentQuarterNoteSequencePrompt` 驱动判题与刷新。
- 这意味着共享真相源 `GeneratedNoteSequence` 已经存在，但 session 并没有直接持有它；一旦后续继续清理旧适配层，`prompt / session / validation` 会再次各自维护一份“序列语义”。
- 本阶段的根因修复重点因此是：把 session、evaluation、controller 判题刷新和验证逻辑全部改成直接围绕 `GeneratedNoteSequence` 工作；`QuarterNoteSequencePrompt` 只保留为兼容适配层，不再承担状态机核心职责。

## 修改 1：`QuarterNoteSequenceSession` / `QuarterNoteSequenceEvaluation` 直接对齐共享序列

### 修改前

- `QuarterNoteSequenceSession` 保存的是 `prompt`
- 当前题通过 `prompt.expectedPitchClasses[currentIndex]` 解析
- `QuarterNoteSequenceEvaluation` 只返回 `expectedPitchClass`，看不到当前题对应的书写音高

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: QuarterNoteSequenceSession.init(...), currentExpectedPitchClass,
// QuarterNoteSequenceEvaluation.debugSummary()
// 功能说明: 修改前顺序 session 和 evaluation 直接绑定旧 QuarterNoteSequencePrompt；
// 当前题答案和总题数都从 prompt 派生，而不是从共享 GeneratedNoteSequence 派生。
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

    var currentExpectedPitchClass: PitchClass? {
        guard !isCompleted else {
            return nil
        }

        return prompt.expectedPitchClasses[currentIndex]
    }
}

struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
    var expectedPitchClass: PitchClass
    var answeredPitchClass: PitchClass
    var answeredIndex: Int
    var nextIndex: Int
    var totalCount: Int

    func debugSummary() -> String {
        let resultText = isCorrect ? "correct" : "wrong"
        let stateText = isSequenceCompleted ? "completed" : "inProgress"
        return "[QuarterNoteSequence] step=\(answeredIndex + 1)/\(totalCount) expected=\(expectedPitchClass.displayText()) answered=\(answeredPitchClass.displayText()) result=\(resultText) nextIndex=\(nextIndex) remaining=\(remainingCount) state=\(stateText)"
    }
}
```

### 修改后

- `QuarterNoteSequenceSession` 改为直接保存 `generatedSequence`
- 新增 `currentItem`，当前题不再只剩下 `PitchClass`，而是完整的 `GeneratedNoteSequenceItem`
- `QuarterNoteSequenceEvaluation` 改为返回 `expectedItem`，并新增 `expectedWrittenPitch`
- debug 日志现在可以同时打印“当前应答音名”和“该题五线谱书写音高”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: QuarterNoteSequenceSession.init(...), currentItem,
// currentExpectedPitchClass, QuarterNoteSequenceEvaluation.expectedWrittenPitch,
// QuarterNoteSequenceEvaluation.debugSummary()
// 功能说明: 修改后顺序 session 和 evaluation 直接消费共享 GeneratedNoteSequence；
// 当前题索引推进只改 currentIndex，题目内容则统一从 generatedSequence.items 读取。
struct QuarterNoteSequenceSession: Equatable, Sendable {
    var generatedSequence: GeneratedNoteSequence
    var currentIndex: Int

    init(
        generatedSequence: GeneratedNoteSequence,
        currentIndex: Int = 0
    ) {
        precondition(
            currentIndex >= 0 && currentIndex <= generatedSequence.noteCount,
            "Quarter-note sequence session index must stay within the sequence range."
        )
        self.generatedSequence = generatedSequence
        self.currentIndex = currentIndex
    }

    var totalCount: Int {
        generatedSequence.noteCount
    }

    var currentItem: GeneratedNoteSequenceItem? {
        guard !isCompleted else {
            return nil
        }

        return generatedSequence.items[currentIndex]
    }

    var currentExpectedPitchClass: PitchClass? {
        currentItem?.answerPitchClass
    }
}

struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
    var expectedItem: GeneratedNoteSequenceItem
    var answeredPitchClass: PitchClass
    var answeredIndex: Int
    var nextIndex: Int
    var totalCount: Int

    var expectedPitchClass: PitchClass {
        expectedItem.answerPitchClass
    }

    var expectedWrittenPitch: StaffPitch {
        expectedItem.writtenPitch
    }

    func debugSummary() -> String {
        let resultText = isCorrect ? "correct" : "wrong"
        let stateText = isSequenceCompleted ? "completed" : "inProgress"
        return "[QuarterNoteSequence] step=\(answeredIndex + 1)/\(totalCount) expected=\(expectedPitchClass.displayText()) written=\(expectedWrittenPitch.scientificName) answered=\(answeredPitchClass.displayText()) result=\(resultText) nextIndex=\(nextIndex) remaining=\(remainingCount) state=\(stateText)"
    }
}
```

## 修改 2：trainer 内部真相源改成 `generatedQuarterNoteSequence`，旧 prompt 收缩为兼容适配层

### 修改前

- trainer 直接保存 `quarterNoteSequencePrompt`
- 生成、建 session、判题都依赖 `requireCurrentQuarterNoteSequencePrompt()`
- `handleQuarterNoteSequenceAnswer(...)` 会校验 `session.prompt == prompt`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: quarterNoteSequencePrompt, generateQuarterNoteSequencePrompt(...),
// makeQuarterNoteSequenceSession(), handleQuarterNoteSequenceAnswer(...),
// requireCurrentQuarterNoteSequencePrompt(...)
// 功能说明: 修改前 trainer 内部把旧 QuarterNoteSequencePrompt 当成 sequence 状态根；
// 共享 GeneratedNoteSequence 只是 prompt 内部成员，还没有提升为 trainer 的直接真相源。
private(set) var quarterNoteSequencePrompt: QuarterNoteSequencePrompt?

mutating func generateQuarterNoteSequencePrompt<R: RandomNumberGenerator>(
    using generator: inout R
) -> QuarterNoteSequencePrompt {
    let spec = requireQuarterNoteSequenceSpec()
    let generatedSequence = StaffQuarterNoteSequenceGenerator().makeSequence(
        spec: spec.staffGeneratorSpec,
        using: &generator
    )
    let prompt = QuarterNoteSequencePrompt(
        spec: spec,
        generatedSequence: generatedSequence
    )
    quarterNoteSequencePrompt = prompt
    return prompt
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

    // ... 省略未改的索引推进逻辑
}

private func requireCurrentQuarterNoteSequencePrompt(
    _ function: StaticString = #function
) -> QuarterNoteSequencePrompt {
    requireQuarterNoteSequenceSpec(function)

    guard let quarterNoteSequencePrompt else {
        preconditionFailure(
            "\(function) requires a generated quarter-note sequence prompt."
        )
    }

    return quarterNoteSequencePrompt
}
```

### 修改后

- trainer 新增 `generatedQuarterNoteSequence` 作为直接真相源
- `quarterNoteSequencePrompt` 保留为计算属性兼容层，用共享 sequence 即时包装
- 新增 `generateQuarterNoteSequence(...)` 系列 API
- `makeQuarterNoteSequenceSession()` / `handleQuarterNoteSequenceAnswer(...)` / `requireCurrentQuarterNoteSequence(...)` 全部直接围绕共享 sequence 工作

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: generatedQuarterNoteSequence, quarterNoteSequencePrompt,
// generateQuarterNoteSequence(...), makeQuarterNoteSequenceSession(),
// handleQuarterNoteSequenceAnswer(...), requireCurrentQuarterNoteSequence(...)
// 功能说明: 修改后 trainer 自己直接持有 GeneratedNoteSequence；
// 旧 prompt 只剩兼容包装职责，顺序判题状态机不再依赖 prompt 壳。
private(set) var generatedQuarterNoteSequence: GeneratedNoteSequence?

var quarterNoteSequencePrompt: QuarterNoteSequencePrompt? {
    guard case let .quarterNoteSequence(spec) = mode,
          let generatedQuarterNoteSequence else {
        return nil
    }

    return QuarterNoteSequencePrompt(
        spec: spec,
        generatedSequence: generatedQuarterNoteSequence
    )
}

mutating func generateQuarterNoteSequence<R: RandomNumberGenerator>(
    using generator: inout R
) -> GeneratedNoteSequence {
    let spec = requireQuarterNoteSequenceSpec()
    let generatedSequence = StaffQuarterNoteSequenceGenerator().makeSequence(
        spec: spec.staffGeneratorSpec,
        using: &generator
    )
    generatedQuarterNoteSequence = generatedSequence
    return generatedSequence
}

func makeQuarterNoteSequenceSession() -> QuarterNoteSequenceSession {
    QuarterNoteSequenceSession(
        generatedSequence: requireCurrentQuarterNoteSequence()
    )
}

mutating func handleQuarterNoteSequenceAnswer(
    _ pitchClass: PitchClass,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult {
    let generatedSequence = requireCurrentQuarterNoteSequence()
    precondition(
        session.generatedSequence == generatedSequence,
        "Quarter-note sequence session sequence must match the current trainer sequence."
    )

    guard let expectedItem = session.currentItem else {
        return .ignored(.completedSession)
    }

    let answeredIndex = session.currentIndex
    let expectedPitchClass = expectedItem.answerPitchClass
    let isCorrect = pitchClass == expectedPitchClass
    let nextIndex = isCorrect ? answeredIndex + 1 : answeredIndex
    if isCorrect {
        session.currentIndex = nextIndex
    }

    return .evaluated(
        QuarterNoteSequenceEvaluation(
            expectedItem: expectedItem,
            answeredPitchClass: pitchClass,
            answeredIndex: answeredIndex,
            nextIndex: nextIndex,
            totalCount: session.totalCount
        )
    )
}

private func requireCurrentQuarterNoteSequence(
    _ function: StaticString = #function
) -> GeneratedNoteSequence {
    requireQuarterNoteSequenceSpec(function)

    guard let generatedQuarterNoteSequence else {
        preconditionFailure(
            "\(function) requires a generated quarter-note sequence."
        )
    }

    return generatedQuarterNoteSequence
}
```

## 修改 3：prompt/staff 适配点直接吃共享 sequence，不再以旧 prompt 为中心

### 修改前

- `QuarterNoteSequenceSession.targetPromptContent()` 还是转发给 `prompt.targetPromptContent(...)`
- `StaffDisplayState` 只有 `apply(quarterNoteSequencePrompt:)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift
// 函数/成员: QuarterNoteSequenceSession.targetPromptContent(...)
// 功能说明: 修改前 session 生成目标音组件内容时，仍然要先回到旧 prompt 壳。
extension FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession {
    func targetPromptContent(
        spelling: PitchSpelling = .sharp
    ) -> TargetPromptContent {
        prompt.targetPromptContent(
            currentIndex: currentIndex,
            spelling: spelling
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState.apply(quarterNoteSequencePrompt:)
// 功能说明: 修改前 staff 投影入口仍然只接受旧 quarter-note prompt。
extension StaffDisplayState {
    mutating func apply(
        quarterNoteSequencePrompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt
    ) {
        configuration.clef = quarterNoteSequencePrompt.spec.clef
        score = quarterNoteSequencePrompt.score
    }
}
```

### 修改后

- `QuarterNoteSequenceSession.targetPromptContent()` 改为直接从 `generatedSequence` 派生
- `StaffDisplayState` 新增 `apply(generatedSequence:)`
- 旧 `apply(quarterNoteSequencePrompt:)` 保留，但已经只是一层委托

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift
// 函数/成员: QuarterNoteSequenceSession.targetPromptContent(...)
// 功能说明: 修改后 session 的 prompt 内容直接由 shared sequence + currentIndex 组成；
// 目标音组件和顺序判题索引使用同一个真相源。
extension FretboardNaturalNoteTrainerState.QuarterNoteSequenceSession {
    func targetPromptContent(
        spelling: PitchSpelling = .sharp
    ) -> TargetPromptContent {
        generatedSequence.targetPromptContent(
            currentIndex: currentIndex,
            spelling: spelling
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState.apply(generatedSequence:),
// StaffDisplayState.apply(quarterNoteSequencePrompt:)
// 功能说明: 修改后 staff 显示直接消费共享 GeneratedNoteSequence；
// 旧 prompt 入口退化成兼容适配层，避免 display state 再反向依赖 prompt。
extension StaffDisplayState {
    mutating func apply(
        generatedSequence: GeneratedNoteSequence
    ) {
        configuration.clef = generatedSequence.clef
        score = generatedSequence.score
    }

    mutating func apply(
        quarterNoteSequencePrompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt
    ) {
        apply(generatedSequence: quarterNoteSequencePrompt.generatedSequence)
    }
}
```

## 修改 4：iOS controller 改成“读共享 sequence + 校验 session 是否同序列”

### 修改前

- iOS controller 通过 `currentQuarterNoteSequencePrompt` 取当前题序列
- `handleQuarterNoteSequenceHitResult(...)` 缺题时打印 `missingPrompt`
- `quarterNoteSequenceSession` 只在 `nil` 时初始化，不会校验它和当前题是不是同一份序列
- `synchronizeQuarterNoteSequencePresentation(...)` 使用 `generateQuarterNoteSequencePrompt()`，并把 `prompt` 传给投影函数和 `StaffDisplayState`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: currentQuarterNoteSequencePrompt,
// currentQuarterNoteSequenceTargetPromptContent,
// handleQuarterNoteSequenceHitResult(_:)
// 功能说明: 修改前 iOS controller 的判题和显示刷新都围绕旧 prompt 壳工作；
// session 只在 nil 时重建，无法显式校验当前 session 是否仍然对齐当前 sequence。
private var currentQuarterNoteSequencePrompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt? {
    guard case .quarterNoteSequence = fretboardTrainerState.mode else {
        return nil
    }

    return fretboardTrainerState.quarterNoteSequencePrompt
}

private var currentQuarterNoteSequenceTargetPromptContent: TargetPromptContent? {
    guard let prompt = currentQuarterNoteSequencePrompt else {
        return nil
    }

    if let quarterNoteSequenceSession,
       quarterNoteSequenceSession.prompt == prompt {
        return quarterNoteSequenceSession.targetPromptContent()
    }

    return prompt.targetPromptContent()
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    // ... 省略未改的 phase / cell / pitch 判空

    guard let prompt = currentQuarterNoteSequencePrompt else {
        print("[QuarterNoteSequence][iOS] result=ignored reason=missingPrompt")
        return
    }

    if quarterNoteSequenceSession == nil {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    // ... 省略未改 session 取值

    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    applyQuarterNoteSequenceProjection(
        prompt,
        reason: "answered",
        showsLog: false
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: synchronizeQuarterNoteSequencePresentation(reason:),
// applyQuarterNoteSequenceProjection(_:reason:showsLog:),
// normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改前 iOS 的 sequence 同步仍以 prompt 为核心对象；
// 生成、投影、settings 标准化都还没有直接对齐共享 GeneratedNoteSequence。
private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    let requiresNewPrompt: Bool
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        requiresNewPrompt = true
    case let .quarterNoteSequence(currentSpec):
        requiresNewPrompt = currentSpec != configuredQuarterNoteSequenceSpec
            || currentQuarterNoteSequencePrompt == nil
    }

    if requiresNewPrompt {
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            quarterNoteSequenceSpec: configuredQuarterNoteSequenceSpec
        )
    }

    let prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt
    if requiresNewPrompt || currentQuarterNoteSequencePrompt == nil {
        prompt = fretboardTrainerState.generateQuarterNoteSequencePrompt()
    } else {
        prompt = currentQuarterNoteSequencePrompt!
    }

    if quarterNoteSequenceSession?.prompt != prompt {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    applyQuarterNoteSequenceProjection(prompt, reason: reason)
}

private func applyQuarterNoteSequenceProjection(
    _ prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt,
    reason: String,
    showsLog: Bool = true
) {
    let content = currentQuarterNoteSequenceTargetPromptContent
        ?? prompt.targetPromptContent()
    targetNotePromptView.apply(content: content)

    var nextStaffDisplayState = staffDisplayState
    nextStaffDisplayState.apply(quarterNoteSequencePrompt: prompt)
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    // ... 省略未改 mainContent 归一化
    if let currentQuarterNoteSequencePrompt {
        stateContext.staffDisplayState.apply(
            quarterNoteSequencePrompt: currentQuarterNoteSequencePrompt
        )
    }
}
```

### 修改后

- iOS controller 改为通过 `currentGeneratedQuarterNoteSequence` 读取当前共享序列
- `currentQuarterNoteSequenceTargetPromptContent` 先校验 `session.generatedSequence == 当前共享序列`
- `handleQuarterNoteSequenceHitResult(...)` 在 sequence 不一致时也会重建 session，而不是只看 `nil`
- `synchronizeQuarterNoteSequencePresentation(...)` 直接调用 `generateQuarterNoteSequence()`
- `applyQuarterNoteSequenceProjection(...)` 和 `normalizeSettingsPanelStateContextForTrainerMode(...)` 都改成直接吃 `GeneratedNoteSequence`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: currentGeneratedQuarterNoteSequence,
// currentQuarterNoteSequenceTargetPromptContent,
// handleQuarterNoteSequenceHitResult(_:)
// 功能说明: 修改后 iOS controller 的答题入口直接校验共享 sequence；
// 如果当前 session 对不上当前 trainer sequence，会自动重建，避免旧 session 残留。
private var currentGeneratedQuarterNoteSequence: GeneratedNoteSequence? {
    guard case .quarterNoteSequence = fretboardTrainerState.mode else {
        return nil
    }

    return fretboardTrainerState.generatedQuarterNoteSequence
}

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

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    // ... 省略未改的 phase / cell / pitch 判空

    guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
        print("[QuarterNoteSequence][iOS] result=ignored reason=missingSequence")
        return
    }

    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    // ... 省略未改 session 取值

    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    applyQuarterNoteSequenceProjection(
        generatedSequence,
        reason: "answered",
        showsLog: false
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: synchronizeQuarterNoteSequencePresentation(reason:),
// applyQuarterNoteSequenceProjection(_:reason:showsLog:),
// normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改后 iOS 的 sequence 生成、投影、settings 标准化都直接围绕共享 sequence；
// prompt 和 staff 只是投影端，不再反向持有判题状态机语义。
private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    let requiresNewSequence: Bool
    switch fretboardTrainerState.mode {
    case .singleNaturalTarget:
        requiresNewSequence = true
    case let .quarterNoteSequence(currentSpec):
        requiresNewSequence = currentSpec != configuredQuarterNoteSequenceSpec
            || currentGeneratedQuarterNoteSequence == nil
    }

    let generatedSequence: GeneratedNoteSequence
    if requiresNewSequence {
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            quarterNoteSequenceSpec: configuredQuarterNoteSequenceSpec
        )
        generatedSequence = fretboardTrainerState.generateQuarterNoteSequence()
    } else {
        generatedSequence = currentGeneratedQuarterNoteSequence!
    }

    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    applyQuarterNoteSequenceProjection(generatedSequence, reason: reason)
}

private func applyQuarterNoteSequenceProjection(
    _ generatedSequence: GeneratedNoteSequence,
    reason: String,
    showsLog: Bool = true
) {
    let content = currentQuarterNoteSequenceTargetPromptContent
        ?? generatedSequence.targetPromptContent()
    targetNotePromptView.apply(content: content)

    var nextStaffDisplayState = staffDisplayState
    nextStaffDisplayState.apply(generatedSequence: generatedSequence)

    if showsLog {
        print(
            "[QuarterNoteSequence][iOS] clef=\(generatedSequence.clef.title) noteCount=\(generatedSequence.noteCount) includesAccidentals=\(configuredQuarterNoteSequenceSpec.includesAccidentals) state=\(reason)"
        )
    }
}

private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    // ... 省略未改 mainContent 归一化
    if let currentGeneratedQuarterNoteSequence {
        stateContext.staffDisplayState.apply(
            generatedSequence: currentGeneratedQuarterNoteSequence
        )
    }
}
```

## 修改 5：macOS controller 同构迁移到共享 sequence 判题流

### 修改前

- macOS 和 iOS 一样，仍在用 `currentQuarterNoteSequencePrompt`
- 判题后刷新和 sequence 投影也都以 `prompt` 为参数

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: currentQuarterNoteSequencePrompt,
// handleQuarterNoteSequenceHitResult(_:),
// synchronizeQuarterNoteSequencePresentation(reason:),
// applyQuarterNoteSequenceProjection(_:reason:showsLog:)
// 功能说明: 修改前 macOS 的顺序判题流与 iOS 同构，也仍然围绕旧 prompt 壳工作。
private var currentQuarterNoteSequencePrompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt? {
    guard case .quarterNoteSequence = fretboardTrainerState.mode else {
        return nil
    }

    return fretboardTrainerState.quarterNoteSequencePrompt
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    // ... 省略未改的 phase / cell / pitch 判空

    guard let prompt = currentQuarterNoteSequencePrompt else {
        print("[QuarterNoteSequence][macOS] result=ignored reason=missingPrompt")
        return
    }

    if quarterNoteSequenceSession == nil {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    applyQuarterNoteSequenceProjection(
        prompt,
        reason: "answered",
        showsLog: false
    )
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    // ... 省略未改的 mode 判断
    let prompt = fretboardTrainerState.generateQuarterNoteSequencePrompt()
    if quarterNoteSequenceSession?.prompt != prompt {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }
    applyQuarterNoteSequenceProjection(prompt, reason: reason)
}
```

### 修改后

- macOS 完整镜像 iOS：读取 `currentGeneratedQuarterNoteSequence`
- 判题前校验 `session.generatedSequence` 是否与当前 trainer sequence 一致
- sequence 生成改为 `generateQuarterNoteSequence()`
- sequence 投影改为 `applyQuarterNoteSequenceProjection(_ generatedSequence: GeneratedNoteSequence, ...)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: currentGeneratedQuarterNoteSequence,
// handleQuarterNoteSequenceHitResult(_:),
// synchronizeQuarterNoteSequencePresentation(reason:),
// applyQuarterNoteSequenceProjection(_:reason:showsLog:)
// 功能说明: 修改后 macOS 与 iOS 保持同一条共享 sequence 判题流；
// 两端平台都不再把 prompt 壳当成当前顺序训练的状态根。
private var currentGeneratedQuarterNoteSequence: GeneratedNoteSequence? {
    guard case .quarterNoteSequence = fretboardTrainerState.mode else {
        return nil
    }

    return fretboardTrainerState.generatedQuarterNoteSequence
}

private func handleQuarterNoteSequenceHitResult(_ hitResult: FretboardHitResult) {
    // ... 省略未改的 phase / cell / pitch 判空

    guard let generatedSequence = currentGeneratedQuarterNoteSequence else {
        print("[QuarterNoteSequence][macOS] result=ignored reason=missingSequence")
        return
    }

    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    applyQuarterNoteSequenceProjection(
        generatedSequence,
        reason: "answered",
        showsLog: false
    )
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    // ... 省略未改的 mode 判断
    let generatedSequence: GeneratedNoteSequence
    if requiresNewSequence {
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            quarterNoteSequenceSpec: configuredQuarterNoteSequenceSpec
        )
        generatedSequence = fretboardTrainerState.generateQuarterNoteSequence()
    } else {
        generatedSequence = currentGeneratedQuarterNoteSequence!
    }

    if quarterNoteSequenceSession?.generatedSequence != generatedSequence {
        quarterNoteSequenceSession = fretboardTrainerState.makeQuarterNoteSequenceSession()
    }

    applyQuarterNoteSequenceProjection(generatedSequence, reason: reason)
}
```

## 修改 6：共享验证改成断言 shared sequence 与 `session.currentIndex` 同步

### 修改前

- 验证仍然重点检查 `prompt` 是否被保存、`session.prompt` 是否与最近 prompt 一致
- 正确/错误作答循环主要围绕 `naturalPrompt.expectedPitchClasses`
- 还没有显式验证 `session.currentIndex -> targetPromptContent()` 是否与共享 sequence 对齐

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: validateTrainerBehavior(record:)
// 功能说明: 修改前验证仍然以 prompt 为主；
// shared sequence 和 targetPromptContent/currentIndex 的同步关系没有被单独锁住。
if naturalTrainer.quarterNoteSequencePrompt != naturalPrompt {
    record("quarter-note trainer 未保存最近一次生成的 natural prompt。")
}

let naturalSession = naturalTrainer.makeQuarterNoteSequenceSession()
if naturalSession.prompt != naturalPrompt {
    record("quarter-note trainer 生成的 session prompt 与最近一次 prompt 不一致。")
}
if naturalSession.totalCount != naturalPrompt.expectedPitchClasses.count {
    record("quarter-note trainer 新建 session 的 totalCount 与 prompt 不一致。")
}

guard let firstExpectedPitchClass = naturalPrompt.expectedPitchClasses.first else {
    record("quarter-note trainer natural prompt 缺少首个 expectedPitchClass。")
    return
}

for (index, expectedPitchClass) in naturalPrompt.expectedPitchClasses.enumerated() {
    // ... 省略未改的正确作答验证
}
```

### 修改后

- 新增 `generatedQuarterNoteSequence` 是否被保存的断言
- 新增 `session.generatedSequence == prompt.generatedSequence` 的断言
- `totalCount`、作答循环都改为基于 `generatedSequence.noteCount / answerPitchClasses`
- 新增 `session.targetPromptContent()` 是否等于 `generatedSequence.targetPromptContent(currentIndex:)` 的断言，显式锁住目标音组件与当前题索引同步

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: validateTrainerBehavior(record:)
// 功能说明: 修改后验证直接锁 shared sequence、session.currentIndex、
// targetPromptContent 三者的一致性，避免顺序判题流再次退回 prompt 壳。
if naturalTrainer.quarterNoteSequencePrompt != naturalPrompt {
    record("quarter-note trainer 未保存最近一次生成的 natural prompt。")
}
if naturalTrainer.generatedQuarterNoteSequence != naturalPrompt.generatedSequence {
    record("quarter-note trainer 未保存最近一次生成的 natural shared sequence。")
}

let naturalSession = naturalTrainer.makeQuarterNoteSequenceSession()
if naturalSession.generatedSequence != naturalPrompt.generatedSequence {
    record("quarter-note trainer 生成的 session sequence 与最近一次 shared sequence 不一致。")
}
if naturalSession.totalCount != naturalPrompt.generatedSequence.noteCount {
    record("quarter-note trainer 新建 session 的 totalCount 与 shared sequence 不一致。")
}
if naturalSession.targetPromptContent() != naturalPrompt.generatedSequence.targetPromptContent(
    currentIndex: naturalSession.currentIndex
) {
    record("quarter-note trainer 新建 session 的 targetPromptContent 未对齐 shared sequence/currentIndex。")
}

guard let firstExpectedPitchClass = naturalPrompt.generatedSequence.answerPitchClasses.first else {
    record("quarter-note trainer natural prompt 缺少首个 expectedPitchClass。")
    return
}

if incorrectSession.targetPromptContent() != naturalPrompt.generatedSequence.targetPromptContent(
    currentIndex: incorrectSession.currentIndex
) {
    record("quarter-note trainer 错误作答后 targetPromptContent 未与当前 session.currentIndex 同步。")
}

for (index, expectedPitchClass) in naturalPrompt.generatedSequence.answerPitchClasses.enumerated() {
    // ... 省略未改的正确作答验证
    if completedSession.targetPromptContent() != naturalPrompt.generatedSequence.targetPromptContent(
        currentIndex: completedSession.currentIndex
    ) {
        record("quarter-note trainer 正确作答后 targetPromptContent 未与当前 session.currentIndex 同步。")
        return
    }
}

if accidentalTrainer.generatedQuarterNoteSequence != accidentalPrompt.generatedSequence {
    record("quarter-note trainer 未保存最近一次生成的 accidental shared sequence。")
}
```

## 验证结果

- `ReadLints` 检查结果：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/TargetPromptContent.swift`
- `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 以上文件均为 `No linter errors found`
- 本次记录文件已放入：`commit_records/20260327_131547_phase5_answer_flow_migrated_to_shared_sequence.md`
- `xcodebuild` 本次仍未执行；当前环境依旧存在 active developer directory 指向 `CommandLineTools` 的限制

## 本阶段落地结果

- quarter-note sequence 的共享真相源已经从“`QuarterNoteSequencePrompt` 内部携带的 `GeneratedNoteSequence`”前移为 trainer 直接持有的 `generatedQuarterNoteSequence`
- `QuarterNoteSequenceSession` 现在只需要保存：
- 当前这份共享 sequence
- 当前答题索引 `currentIndex`
- `targetPromptContent` 与判题状态机已经共享同一个 `currentIndex`
- 双平台 controller 的 sequence 判题和刷新都已切到共享 sequence，不再把旧 prompt 壳当作当前训练状态根
- `QuarterNoteSequencePrompt` 仍然保留，但现在已经降级为兼容适配层，为阶段 6 清理旧壳层做准备

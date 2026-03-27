# 20260327_130353_phase4_controller_prompt_or_staff_projection

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_130353`
- 记录范围：统一序列真相源阶段 4，把 controller 改成“同一份序列 -> `prompt` 或 `staff` 二选一投影”
- 本次目标：不再让 quarter-note sequence 直接强制 `topContent = .staff`，而是让同一份随机序列既能驱动目标音显示组件，也能驱动五线谱；最终显示哪一个，交给页面显示状态决定
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 修改前，sequence 模式的 controller 接线仍然是“生成 prompt -> 直接写入 staff -> 强制页面顶部切到 `staff`”。这会让同一份随机序列虽然已经存在，但 `prompt` 和 `staff` 不是同一条统一投影管线。
- `settings` 切换训练模式、调试入口启动 sequence、答题后刷新当前高亮，这三条路径分别落在不同的局部逻辑里，导致后续阶段很难把 sequence 显示与判题状态机稳定收口。
- 用户手动改过的 `staffDisplayState` 在进入 sequence 模式后会被覆盖，但修改前没有一份单独的“原始 staff 基线”可恢复，退出 sequence 后容易残留旧五线谱内容。

## 修改 1：`TrainerSequenceConfiguration` 增加和 trainer domain spec 的双向桥接

### 修改前

- `TrainerSequenceConfiguration` 只是一份 settings shared state 里的配置结构。
- controller 如果要启动 quarter-note sequence，只能自己重新拼装 `QuarterNoteSequenceSpec`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/成员: TrainerSequenceConfiguration, TrainerDisplayState.setExerciseMode(_:)
// 功能说明: 修改前 sequence 配置只存在于 settings shared state；
// controller 还没有直接把这份配置桥接到 trainer domain spec 的接口。
struct TrainerSequenceConfiguration: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool

    static let `default` = TrainerSequenceConfiguration(
        clef: .treble,
        noteCount: 7,
        includesAccidentals: false
    )

    init(
        clef: StaffClef = .treble,
        noteCount: Int = 7,
        includesAccidentals: Bool = false
    ) {
        precondition(
            noteCount > 0,
            "Trainer sequence note count must be greater than zero."
        )
        self.clef = clef
        self.noteCount = noteCount
        self.includesAccidentals = includesAccidentals
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration

    mutating func setExerciseMode(_ mode: TrainerExerciseMode) {
        exerciseMode = mode
    }
}
```

### 修改后

- 新增 `TrainerSequenceConfiguration.init(quarterNoteSequenceSpec:)`
- 新增 `TrainerSequenceConfiguration.quarterNoteSequenceSpec`
- 这样 controller 在“settings shared state”和“trainer domain state”之间切换时，不需要再手工拆 `clef / noteCount / includesAccidentals`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/成员: TrainerSequenceConfiguration.init(quarterNoteSequenceSpec:),
// TrainerSequenceConfiguration.quarterNoteSequenceSpec
// 功能说明: 新增 sequence 配置和 trainer quarter-note spec 的双向桥接，
// 让 controller 可以直接复用 settings 中的共享 sequence 配置。
extension TrainerSequenceConfiguration {
    init(
        quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) {
        self.init(
            clef: quarterNoteSequenceSpec.clef,
            noteCount: quarterNoteSequenceSpec.noteCount,
            includesAccidentals: quarterNoteSequenceSpec.includesAccidentals
        )
    }

    var quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
        FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals
        )
    }
}
```

## 修改 2：iOS controller 改成统一 trainer 管线，而不是 sequence 直接强制切到五线谱

### 修改前

- 初始化阶段仍然单独调用 `applyFretboardTrainerPrompt(reason: "initial")`
- `applyPageDisplayState()` 自己决定什么时候给 `targetNotePromptView` 填单目标音
- `startQuarterNoteSequenceExercise(...)` 直接创建 sequence prompt 并调用 `applyQuarterNoteSequencePromptToStaff(...)`
- `applyQuarterNoteSequencePromptToStaff(...)` 内部强制 `topContentMode = .staff`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: viewDidLoad(), applyPageDisplayState(),
// startQuarterNoteSequenceExercise(with:), applyQuarterNoteSequencePromptToStaff(_:reason:)
// 功能说明: 修改前 quarter-note sequence 有自己独立的入口和投影逻辑，
// 并且会直接把页面顶部切到 staff，导致同一份序列无法只通过页面状态在 prompt / staff 间切换。
override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    configureLayout()
    applyDisplayState()
    applyFretboardTrainerPrompt(reason: "initial")
}

private func applyPageDisplayState() {
    if !isQuarterNoteSequenceMode {
        targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    }
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
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

    var nextStaffDisplayState = staffDisplayState
    nextStaffDisplayState.apply(quarterNoteSequencePrompt: prompt)

    if nextPageDisplayState != pageDisplayState {
        pageDisplayState = nextPageDisplayState
    }

    if nextStaffDisplayState != staffDisplayState {
        staffDisplayState = nextStaffDisplayState
    }
}
```

### 修改后

- 新增 `baseStaffDisplayState`，用来保存“非 sequence 模式下用户真正想要的 staff 状态”
- 新增 `currentQuarterNoteSequenceTargetPromptContent`，把当前 session 高亮状态优先投影给 `targetNotePromptView`
- 新增 `configuredQuarterNoteSequenceSpec`，统一从 `trainerDisplayState.sequenceConfiguration` 读取 sequence 配置
- `applyDisplayState()` 改为进入统一入口 `synchronizeTrainerPresentationState(reason: "initial")`
- `startQuarterNoteSequenceExercise(...)` 不再手工拼 controller 分支，而是直接写 `trainerDisplayState` 后复用同一套同步逻辑

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: staffDisplayState.didSet, currentQuarterNoteSequenceTargetPromptContent,
// configuredQuarterNoteSequenceSpec
// 功能说明: 修改后 controller 先把“sequence 当前显示内容”和“用户原始 staff 基线”抽出来，
// 为后面的统一 trainer 同步入口和双投影逻辑做准备。
private var staffDisplayState = Self.initialStaffDisplayState {
    didSet {
        guard isViewLoaded else {
            return
        }

        if !trainerDisplayState.isSequenceMode {
            baseStaffDisplayState = staffDisplayState
        }
        applyStaffDisplayState()
    }
}

private var baseStaffDisplayState = Self.initialStaffDisplayState

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

private var configuredQuarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
    trainerDisplayState.sequenceConfiguration.quarterNoteSequenceSpec
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyDisplayState(), startQuarterNoteSequenceExercise(with:),
// synchronizeTrainerPresentationState(reason:), synchronizeSingleTrainerPresentation(reason:),
// synchronizeQuarterNoteSequencePresentation(reason:), applyQuarterNoteSequenceProjection(_:reason:showsLog:)
// 功能说明: 修改后 single / sequence 都改走统一 trainerDisplayState 管线；
// 同一份 sequence 会同时投影到 target prompt content 和 staff score，
// 但顶部究竟显示 prompt 还是 staff，不再由 sequence 逻辑强制决定。
private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyPageDisplayState()
    synchronizeTrainerPresentationState(reason: "initial")
}

func startQuarterNoteSequenceExercise(
    with spec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
) {
    trainerDisplayState = TrainerDisplayState(
        exerciseMode: .sequence,
        sequenceConfiguration: TrainerSequenceConfiguration(
            quarterNoteSequenceSpec: spec
        )
    )
    synchronizeTrainerPresentationState(reason: "generated")
}

private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    }
}

private func synchronizeSingleTrainerPresentation(reason: String) {
    if isQuarterNoteSequenceMode {
        fretboardTrainerState = FretboardNaturalNoteTrainerState()
    }

    quarterNoteSequenceSession = nil

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    applyFretboardTrainerPrompt(reason: reason)
}

private func synchronizeQuarterNoteSequencePresentation(reason: String) {
    if pageDisplayState.mainContentMode != .fretboard {
        pageDisplayState.setMainContentMode(.fretboard)
    }

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

    if nextStaffDisplayState != staffDisplayState {
        staffDisplayState = nextStaffDisplayState
    }

    if showsLog {
        print(
            "[QuarterNoteSequence][iOS] clef=\(prompt.spec.clef.title) noteCount=\(prompt.spec.noteCount) includesAccidentals=\(prompt.spec.includesAccidentals) state=\(reason)"
        )
    }
}
```

## 修改 3：iOS settings 标准化不再强制 `topContent = .staff`，并在切模式时恢复用户 staff 基线

### 修改前

- `normalizeSettingsPanelStateContextForTrainerMode(...)` 在 sequence 模式下会直接把 `pageDisplayState.topContentMode` 改成 `.staff`
- 这意味着即便同一份 sequence 已经能喂给 `targetNotePromptView`，用户也不能只通过页面设置去看 prompt

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: normalizeSettingsPanelStateContextForTrainerMode(_:)
// 功能说明: 修改前 sequence 模式下 settings 标准化会强制顶部显示 staff，
// 使得页面状态失去对 prompt / staff 切换的最终决定权。
private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard isQuarterNoteSequenceMode else {
        return
    }

    stateContext.pageDisplayState.topContentMode = .staff
    stateContext.pageDisplayState.mainContentMode = .fretboard

    if let currentQuarterNoteSequencePrompt {
        stateContext.staffDisplayState.apply(
            quarterNoteSequencePrompt: currentQuarterNoteSequencePrompt
        )
    }
}
```

### 修改后

- 标准化逻辑改成只保证 sequence 的 `mainContentMode` 仍然是 `.fretboard`
- `topContentMode` 完全交还给页面状态自己控制
- `handleSettingsPanelEvent(_:)` 会在进入 sequence 模式前保存用户希望的 `staffDisplayState`，并在训练模式变化后统一调用 `synchronizeTrainerPresentationState(reason: "exerciseModeChanged")`
- `handleQuarterNoteSequenceHitResult(...)` 在答题后调用 `applyQuarterNoteSequenceProjection(..., showsLog: false)`，让 prompt 的当前高亮和 staff 使用的仍然是同一份 sequence 真相源

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: normalizeSettingsPanelStateContextForTrainerMode(_:),
// handleSettingsPanelEvent(_:), handleQuarterNoteSequenceHitResult(answerPitchClass:)
// 功能说明: 修改后 settings 只负责保证 sequence 训练的主内容仍是 fretboard，
// 不再替页面状态决定顶部显示；同时在模式切换和答题后，都回到统一 sequence 投影函数。
private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard stateContext.trainerDisplayState.isSequenceMode else {
        return
    }

    stateContext.pageDisplayState.mainContentMode = .fretboard

    if let currentQuarterNoteSequencePrompt {
        stateContext.staffDisplayState.apply(
            quarterNoteSequencePrompt: currentQuarterNoteSequencePrompt
        )
    }
}

private func handleQuarterNoteSequenceHitResult(answerPitchClass: PitchClass) {
    // ... 省略前置判空与 session 提取
    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    applyQuarterNoteSequenceProjection(
        prompt,
        reason: "answered",
        showsLog: false
    )
    // ... 省略答题结果分支
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    let nextRequestedStaffDisplayState = nextStateContext.staffDisplayState
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

    // ... 省略 next state 计算与 didChange 判定

    if nextTrainerDisplayState.isSequenceMode,
       nextRequestedStaffDisplayState != staffDisplayState {
        baseStaffDisplayState = nextRequestedStaffDisplayState
    }

    // ... 省略 display / page / staff 赋值

    if didChangeTrainer {
        synchronizeTrainerPresentationState(reason: "exerciseModeChanged")
    }
}
```

## 修改 4：macOS controller 做同构迁移，保持和 iOS 一致的 sequence 真相源接线

### 修改前

- macOS controller 的 sequence 接线和 iOS 一样，也是“内部生成 -> 强制 `topContent = .staff` -> 直接投影到 staff”
- 因此平台间虽然实现不同，但结构性问题完全相同

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: viewDidLoad(), applyPageDisplayState(),
// startQuarterNoteSequenceExercise(with:), applyQuarterNoteSequencePromptToStaff(_:reason:)
// 功能说明: 修改前 macOS 和 iOS 一样，sequence 会单独改写页面顶部为 staff，
// prompt / staff 之间没有统一的共享投影入口。
override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    configureLayout()
    applyDisplayState()
    applyFretboardTrainerPrompt(reason: "initial")
}

private func applyPageDisplayState() {
    if !isQuarterNoteSequenceMode {
        targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    }
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
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
    // ... 省略其余未改逻辑
}
```

### 修改后

- 新增 `baseStaffDisplayState`、`currentQuarterNoteSequenceTargetPromptContent`、`configuredQuarterNoteSequenceSpec`
- `startQuarterNoteSequenceExercise(...)` 改为写入 `trainerDisplayState`
- `synchronizeTrainerPresentationState(...)`、`synchronizeSingleTrainerPresentation(...)`、`synchronizeQuarterNoteSequencePresentation(...)`、`applyQuarterNoteSequenceProjection(...)` 与 iOS 对齐
- `normalizeSettingsPanelStateContextForTrainerMode(...)` 同样不再强制 `topContent = .staff`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: staffDisplayState.didSet, currentQuarterNoteSequenceTargetPromptContent,
// configuredQuarterNoteSequenceSpec, synchronizeTrainerPresentationState(reason:),
// synchronizeQuarterNoteSequencePresentation(reason:), applyQuarterNoteSequenceProjection(_:reason:showsLog:)
// 功能说明: 修改后 macOS 与 iOS 保持同构；
// sequence 仍然只有一份真相源，但可以同时向 prompt content 和 staff score 投影。
private var staffDisplayState = Self.initialStaffDisplayState {
    didSet {
        guard isViewLoaded else {
            return
        }

        if !trainerDisplayState.isSequenceMode {
            baseStaffDisplayState = staffDisplayState
        }
        applyStaffDisplayState()
    }
}

private var baseStaffDisplayState = Self.initialStaffDisplayState

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

private var configuredQuarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
    trainerDisplayState.sequenceConfiguration.quarterNoteSequenceSpec
}

private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    }
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

    if nextStaffDisplayState != staffDisplayState {
        staffDisplayState = nextStaffDisplayState
    }

    if showsLog {
        print(
            "[QuarterNoteSequence][macOS] clef=\(prompt.spec.clef.title) noteCount=\(prompt.spec.noteCount) includesAccidentals=\(prompt.spec.includesAccidentals) state=\(reason)"
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: normalizeSettingsPanelStateContextForTrainerMode(_:),
// handleSettingsPanelEvent(_:), handleQuarterNoteSequenceHitResult(answerPitchClass:)
// 功能说明: 修改后 macOS settings 标准化和答题刷新也统一回到 sequence 投影函数，
// 保证两端平台在“同一份序列 -> prompt 或 staff 二选一显示”的规则上完全一致。
private func normalizeSettingsPanelStateContextForTrainerMode(
    _ stateContext: inout SettingsPanelStateContext
) {
    guard stateContext.trainerDisplayState.isSequenceMode else {
        return
    }

    stateContext.pageDisplayState.mainContentMode = .fretboard

    if let currentQuarterNoteSequencePrompt {
        stateContext.staffDisplayState.apply(
            quarterNoteSequencePrompt: currentQuarterNoteSequencePrompt
        )
    }
}

private func handleQuarterNoteSequenceHitResult(answerPitchClass: PitchClass) {
    // ... 省略前置判空与 session 提取
    self.quarterNoteSequenceSession = quarterNoteSequenceSession
    applyQuarterNoteSequenceProjection(
        prompt,
        reason: "answered",
        showsLog: false
    )
    // ... 省略答题结果分支
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    let nextRequestedStaffDisplayState = nextStateContext.staffDisplayState
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

    // ... 省略 next state 计算与 didChange 判定

    if nextTrainerDisplayState.isSequenceMode,
       nextRequestedStaffDisplayState != staffDisplayState {
        baseStaffDisplayState = nextRequestedStaffDisplayState
    }

    // ... 省略 display / page / staff 赋值

    if didChangeTrainer {
        synchronizeTrainerPresentationState(reason: "exerciseModeChanged")
    }
}
```

## 验证结果

- `ReadLints` 检查结果：`TrainerDisplayState.swift`、`iOSViewController.swift`、`macOSViewController.swift` 均为 `No linter errors found`
- 本次记录文件已放入：`commit_records/20260327_130353_phase4_controller_prompt_or_staff_projection.md`
- `xcodebuild` 这次仍未执行；当前环境依旧存在 active developer directory 指向 `CommandLineTools` 的限制

## 本阶段落地结果

- sequence 训练入口已经统一收敛到 `trainerDisplayState`
- 同一份随机序列现在会同时形成两种投影：
- `TargetPromptContent`，供顶部目标音组件显示并随答题推进高亮
- `StaffScore`，供五线谱绘制
- 顶部最终显示 `prompt` 还是 `staff`，改由 `pageDisplayState.topContentMode` 决定，而不是由 sequence 训练逻辑硬编码决定
- 用户在非 sequence 模式下调整过的 `staffDisplayState` 会被保存为 `baseStaffDisplayState`，切回 single 时可以恢复

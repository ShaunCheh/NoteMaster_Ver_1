# 20260331_115103_phase6_position_filter_controller_sync

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_115103`
- 记录范围：实施“Position 过滤模式重构”计划的阶段 6，只完成 iOS / macOS controller 的同步点改造；不包含 validation 扩展，不包含启动默认值收口
- 本次目标：把 controller 里所有仍然只认 `selectedFrets` / `allowedFrets` 的位置题链路，统一切到 `trainerDisplayState.positionPromptConfiguration.activeFilter`
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次结论

- 双端 controller 现在都改为通过 `activeFilter` 读取当前位置题过滤条件
- session 合法性判断不再只检查 fret，而是会根据 `.noteNames(...)` / `.frets(...)` 两种模式分别判断
- 新建题目与答题换题入口已经把 `activeFilter` 传给 shared trainer
- settings diff 不再用“positionPromptFretsChanged”语义，而是按 `activeFilter` 变化触发重同步
- 过滤条件在 `wrongFlash` / `correctHold` 期间变化时，会先取消 pending transition 并重置旧反馈态，再重算当前题

## 修改 1：controller 当前过滤状态从 `selectedFrets` 提升为 `activeFilter`

### 修改前

- 双端 controller 都通过 `currentPositionPromptAllowedFrets` 读取当前位置题过滤条件
- 这个 helper 只暴露 `selectedFrets`，导致 controller 层天然只理解“按品位过滤”

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: currentPositionPromptAllowedFrets
// 功能说明: 修改前 iOS controller 只从 positionPromptConfiguration 中取 selectedFrets；
// controller 层还没有接入统一 activeFilter。
private var currentPositionPromptAllowedFrets: Set<Int> {
    trainerDisplayState.positionPromptConfiguration.selectedFrets
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: currentPositionPromptAllowedFrets
// 功能说明: 修改前 macOS controller 与 iOS 对称，当前位置题过滤条件仍然只认 selectedFrets。
private var currentPositionPromptAllowedFrets: Set<Int> {
    trainerDisplayState.positionPromptConfiguration.selectedFrets
}
```

### 修改后

- 双端 controller 都改为 `currentPositionPromptFilter`
- helper 的唯一真相源现在是 `positionPromptConfiguration.activeFilter`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: currentPositionPromptFilter
// 功能说明: 修改后 iOS controller 直接读取统一 activeFilter；
// 这样 noteName / fret 两种过滤模式都会进入同一条 controller 同步链路。
private var currentPositionPromptFilter: PositionPromptCandidateFilter {
    trainerDisplayState.positionPromptConfiguration.activeFilter
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: currentPositionPromptFilter
// 功能说明: 修改后 macOS controller 同步切到 activeFilter，和 iOS 保持完全对称。
private var currentPositionPromptFilter: PositionPromptCandidateFilter {
    trainerDisplayState.positionPromptConfiguration.activeFilter
}
```

## 修改 2：当前题合法性判断从“只校验 fret”改为“按当前 activeFilter 校验”

### 修改前

- `positionPromptCellMatchesCurrentTrainer(...)` 会先判断 `currentPositionPromptAllowedFrets.contains(cell.fret)`
- 这意味着 controller 只能判断“当前题目是否还落在允许品位内”，无法判断“当前题目是否仍然命中所选音名”

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: positionPromptCellMatchesCurrentTrainer(_:expectedPitchClass:)
// 功能说明: 修改前 iOS controller 对当前位置题的合法性判断只认 allowed frets；
// 题目是否符合 noteName 模式并不会在这里被校验出来。
private func positionPromptCellMatchesCurrentTrainer(
    _ cell: FretboardCell,
    expectedPitchClass: PitchClass
) -> Bool {
    guard currentPositionPromptAllowedFrets.contains(cell.fret),
          let resolvedPitchClass = displayState.configuration.pitchClass(
            for: cell
          ) else {
        return false
    }

    return resolvedPitchClass == expectedPitchClass
        && resolvedPitchClass.isNatural
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: positionPromptCellMatchesCurrentTrainer(_:expectedPitchClass:)
// 功能说明: 修改前 macOS controller 同样只校验 fret 是否在允许集合里。
private func positionPromptCellMatchesCurrentTrainer(
    _ cell: FretboardCell,
    expectedPitchClass: PitchClass
) -> Bool {
    guard currentPositionPromptAllowedFrets.contains(cell.fret),
          let resolvedPitchClass = displayState.configuration.pitchClass(
            for: cell
          ) else {
        return false
    }

    return resolvedPitchClass == expectedPitchClass
        && resolvedPitchClass.isNatural
}
```

### 修改后

- 先统一解析 `resolvedPitchClass`
- 然后根据 `currentPositionPromptFilter` 分别判断：
- `.noteNames(...)` 时检查当前题的自然音名是否仍被选中
- `.frets(...)` 时继续检查当前题是否仍落在允许品位里

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: positionPromptCellMatchesCurrentTrainer(_:expectedPitchClass:)
// 功能说明: 修改后 iOS controller 会按 activeFilter 判断当前题是否合法；
// 这让切换 filterMode 或修改当前激活模式下的选项后，都能正确判定当前题是否需要重建。
private func positionPromptCellMatchesCurrentTrainer(
    _ cell: FretboardCell,
    expectedPitchClass: PitchClass
) -> Bool {
    guard let resolvedPitchClass = displayState.configuration.pitchClass(
            for: cell
          ),
          resolvedPitchClass == expectedPitchClass,
          resolvedPitchClass.isNatural else {
        return false
    }

    switch currentPositionPromptFilter {
    case let .noteNames(selectedPitchClasses):
        return selectedPitchClasses.contains(resolvedPitchClass)
    case let .frets(selectedFrets):
        return selectedFrets.contains(cell.fret)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: positionPromptCellMatchesCurrentTrainer(_:expectedPitchClass:)
// 功能说明: 修改后 macOS controller 与 iOS 对称，根据当前 activeFilter 判断题目是否仍然有效。
private func positionPromptCellMatchesCurrentTrainer(
    _ cell: FretboardCell,
    expectedPitchClass: PitchClass
) -> Bool {
    guard let resolvedPitchClass = displayState.configuration.pitchClass(
            for: cell
          ),
          resolvedPitchClass == expectedPitchClass,
          resolvedPitchClass.isNatural else {
        return false
    }

    switch currentPositionPromptFilter {
    case let .noteNames(selectedPitchClasses):
        return selectedPitchClasses.contains(resolvedPitchClass)
    case let .frets(selectedFrets):
        return selectedFrets.contains(cell.fret)
    }
}
```

## 修改 3：建题入口与答题换题入口统一改走 `filter`

### 修改前

- `ensurePositionPromptSession()` 建题入口仍传 `selectedFrets`
- `handlePositionPromptAnswer(...)` 答题入口也仍传 `selectedFrets`
- 即使 shared trainer 已经支持统一 `filter`，controller 仍然没有真正把新模式送进去

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: ensurePositionPromptSession(), handlePositionPromptAnswer(_:)
// 功能说明: 修改前 iOS controller 的建题与答题换题入口仍然只把 selectedFrets 传给 shared trainer。
positionPromptSession = fretboardTrainerState.makePositionPromptSession(
    configuration: displayState.configuration,
    allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
    using: &generator
)

let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
    pitchClass,
    configuration: displayState.configuration,
    allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
    session: &positionPromptSession
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: ensurePositionPromptSession(), handlePositionPromptAnswer(_:)
// 功能说明: 修改前 macOS controller 同样仍然把 selectedFrets 作为唯一过滤输入传入 trainer。
positionPromptSession = fretboardTrainerState.makePositionPromptSession(
    configuration: displayState.configuration,
    allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
    using: &generator
)

let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
    pitchClass,
    configuration: displayState.configuration,
    allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
    session: &positionPromptSession
)
```

### 修改后

- 双端建题入口都传 `currentPositionPromptFilter`
- 双端答题换题入口也传 `currentPositionPromptFilter`
- 这样 controller 与 shared trainer 的统一 filter API 才真正接通

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: ensurePositionPromptSession(), handlePositionPromptAnswer(_:)
// 功能说明: 修改后 iOS controller 的建题与答题换题入口都直接走 currentPositionPromptFilter；
// UI 当前激活的过滤模式和选项集合，会真实进入 trainer 出题链路。
positionPromptSession = fretboardTrainerState.makePositionPromptSession(
    configuration: displayState.configuration,
    filter: currentPositionPromptFilter,
    using: &generator
)

let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
    pitchClass,
    configuration: displayState.configuration,
    filter: currentPositionPromptFilter,
    session: &positionPromptSession
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: ensurePositionPromptSession(), handlePositionPromptAnswer(_:)
// 功能说明: 修改后 macOS controller 对称改走 currentPositionPromptFilter，
// 不再把过滤条件硬编码成 selectedFrets。
positionPromptSession = fretboardTrainerState.makePositionPromptSession(
    configuration: displayState.configuration,
    filter: currentPositionPromptFilter,
    using: &generator
)

let answerResult = fretboardTrainerState.handlePositionPromptAnswer(
    pitchClass,
    configuration: displayState.configuration,
    filter: currentPositionPromptFilter,
    session: &positionPromptSession
)
```

## 修改 4：trainer diff 原因从“品位变化”提升为“activeFilter 变化”

### 修改前

- settings 变更后的 diff 判断逻辑是拿整个 `positionPromptConfiguration` 做比较
- reason 仍然叫 `positionPromptFretsChanged`
- 这个命名和逻辑都还停留在“只改 fret 集合”的旧语义里

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: handleSettingsPanelEvent(_:)
// 功能说明: 修改前 iOS controller 仍把 positionPrompt 配置变化视为“fret 变化”；
// 这和 filterMode / noteName 模式已经不匹配。
let didChangePositionPromptFrets = nextTrainerDisplayState.positionPromptConfiguration
    != trainerDisplayState.positionPromptConfiguration

if didChangeTrainer {
    let trainerSyncReason: String
    if didChangeExerciseMode {
        trainerSyncReason = "exerciseModeChanged"
    } else if didChangePositionPromptFrets {
        trainerSyncReason = "positionPromptFretsChanged"
    } else {
        trainerSyncReason = "trainerSettingsChanged"
    }
    synchronizeTrainerPresentationState(reason: trainerSyncReason)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handleSettingsPanelEvent(_:)
// 功能说明: 修改前 macOS controller 的 trainer diff 原因也仍然写死在 positionPromptFretsChanged。
let didChangePositionPromptFrets = nextTrainerDisplayState.positionPromptConfiguration
    != trainerDisplayState.positionPromptConfiguration

if didChangeTrainer {
    let trainerSyncReason: String
    if didChangeExerciseMode {
        trainerSyncReason = "exerciseModeChanged"
    } else if didChangePositionPromptFrets {
        trainerSyncReason = "positionPromptFretsChanged"
    } else {
        trainerSyncReason = "trainerSettingsChanged"
    }
    synchronizeTrainerPresentationState(reason: trainerSyncReason)
}
```

### 修改后

- diff 判断收口到 `positionPromptConfiguration.activeFilter`
- reason 也改成 `positionPromptFilterChanged`
- 这样无论是切 `filterMode`，还是改当前激活模式下的选项集合，都会走同一条同步分支

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS controller 按 activeFilter 变化判断是否需要重新同步位置题状态；
// 这让 filterMode 切换和当前模式选项变更都能触发统一的 session 合法性校验。
let didChangePositionPromptActiveFilter =
    nextTrainerDisplayState.positionPromptConfiguration.activeFilter
    != trainerDisplayState.positionPromptConfiguration.activeFilter

if didChangeTrainer {
    let trainerSyncReason: String
    if didChangeExerciseMode {
        trainerSyncReason = "exerciseModeChanged"
    } else if didChangePositionPromptActiveFilter {
        trainerSyncReason = "positionPromptFilterChanged"
    } else {
        trainerSyncReason = "trainerSettingsChanged"
    }
    synchronizeTrainerPresentationState(reason: trainerSyncReason)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS controller 对称按 activeFilter 变化触发 trainer 重同步。
let didChangePositionPromptActiveFilter =
    nextTrainerDisplayState.positionPromptConfiguration.activeFilter
    != trainerDisplayState.positionPromptConfiguration.activeFilter

if didChangeTrainer {
    let trainerSyncReason: String
    if didChangeExerciseMode {
        trainerSyncReason = "exerciseModeChanged"
    } else if didChangePositionPromptActiveFilter {
        trainerSyncReason = "positionPromptFilterChanged"
    } else {
        trainerSyncReason = "trainerSettingsChanged"
    }
    synchronizeTrainerPresentationState(reason: trainerSyncReason)
}
```

## 修改 5：过滤变化发生在反馈动画期间时，先取消 pending transition 再重建

### 修改前

- `synchronizePositionPromptPresentation(reason:)` 虽然会在题目失效时重建 session
- 但在 `wrongFlash` / `correctHold` 期间切过滤条件时，没有显式先清掉旧的 pending transition
- 旧题目的延迟切换逻辑仍可能继续执行

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改前 iOS controller 在 positionPrompt 配置变化时，
// 没有针对反馈动画期间的旧 pending transition 做显式收口。
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
        // 已在位置题模式内时尽量保留当前 session；
        // 只有在 configuration 失效时才会在 projection 中重建。
    } else {
        resetPositionPromptInteractionState()
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            positionPromptMode: ()
        )
    }
}
```

### 修改后

- 当 reason 是 `positionPromptFilterChanged` 且当前 phase 不是 `.neutralWhite`
- 双端 controller 都会先 `resetPositionPromptInteractionState()`
- 这一步会取消 pending transition、丢弃旧 session 和旧反馈态，再用新 filter 重算当前题

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改后 iOS controller 在过滤条件变化且反馈动画未结束时，
// 会先取消 pending transition 并清空旧的 position prompt 交互状态，再根据新 filter 重建题目。
private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    if reason == "positionPromptFilterChanged",
       currentPositionPromptOverlayPhase != .neutralWhite {
        resetPositionPromptInteractionState()
    }

    if case .positionPrompt = fretboardTrainerState.mode {
        // 已在位置题模式内时尽量保留当前 session；
        // 只有在 configuration 失效时才会在 projection 中重建。
    } else {
        resetPositionPromptInteractionState()
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            positionPromptMode: ()
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改后 macOS controller 同步收口过滤变化期间的旧反馈态与延迟切换任务。
private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    if reason == "positionPromptFilterChanged",
       currentPositionPromptOverlayPhase != .neutralWhite {
        resetPositionPromptInteractionState()
    }

    if case .positionPrompt = fretboardTrainerState.mode {
        // 已在位置题模式内时尽量保留当前 session；
        // 只有在 configuration 失效时才会在 projection 中重建。
    } else {
        resetPositionPromptInteractionState()
        fretboardTrainerState = FretboardNaturalNoteTrainerState(
            positionPromptMode: ()
        )
    }
}
```

## 验证情况

- 已对以下文件运行 `ReadLints`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 结果：无 linter 报错
- 本次未运行 `xcodebuild` / 应用启动验证，因此这份记录只确认 controller 同步改造与 IDE lint 状态

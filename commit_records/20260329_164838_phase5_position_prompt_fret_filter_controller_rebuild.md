# 20260329_164838_phase5_position_prompt_fret_filter_controller_rebuild

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_164838`
- 记录范围：实施“Position 品位筛选”计划的阶段 5，只完成 iOS / macOS 控制器侧的 `positionPrompt` session 匹配、非法题重建入口与 settings 事件同步理由细化
- 本次目标：当 `positionPrompt` 的品位筛选发生变化时，不再继续稳定显示一个已经非法的当前题目；同时尽量保持现有红闪 / 绿停留的交互节奏
- 本次不包含：
- shared trainer 的 allowed-frets 过滤逻辑
- validation 用例补充与手工回归清单
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `.cursor/plans/position品位筛选_cb2e8023.plan.md`

## 本次结论

- 阶段 5 完成后，双端控制器已经不再把 `positionPrompt` 的合法性理解为“只要 `session.promptCell` 还能解析出同一个自然音就算合法”
- 新逻辑会把当前允许品位集合 `selectedFrets` 纳入判断，并且按当前屏幕上真正可见的 prompt 进行匹配：
- `neutralWhite` 时检查当前 session 的新题
- `wrongFlash / correctHold` 时检查正在屏幕上显示的旧题
- 由于 `ensurePositionPromptSession()` 原本就具备“session 不合法时取消 pending transition 并重建”的流程，所以阶段 5 不需要大改重建函数本身，只需要把“什么叫合法”定义准确，非法题就会自动被替换
- 同时，settings 事件处理现在会区分 `exerciseModeChanged`、`positionPromptFretsChanged` 和一般 trainer 设置变化，为后续日志与行为分流提供更清晰的原因语义

## 修改 1：iOS 端把 `positionPrompt` 的 session 合法性判断升级为“当前可见 prompt + 当前允许品位”

### 修改前

- iOS 的 `positionPromptSessionMatchesCurrentTrainer(_:)` 只检查：
- trainer 当前是否还是 `.positionPrompt`
- `session.promptCell` 在当前 `displayState.configuration` 下能否解析成 `session.promptPitchClass`
- 这个判断没有纳入 `selectedFrets`
- 也没有区分当前屏幕上显示的是“session 的新题”还是“上一题的 wrongFlash / correctHold”
- 结果是筛选变化后，控制器可能继续认为一个非法的当前显示题目仍然“匹配当前 trainer”

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: positionPromptSessionMatchesCurrentTrainer(_:)
// 功能说明: 修改前 iOS 端只校验 session.promptCell 本身是否还能解析出同一个自然音；
// 没有把当前筛选品位集合和当前可见 prompt 阶段一起纳入匹配条件。
private func positionPromptSessionMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    guard case .positionPrompt = fretboardTrainerState.mode,
          let resolvedPitchClass = displayState.configuration.pitchClass(
            for: session.promptCell
          ) else {
        return false
    }

    return resolvedPitchClass == session.promptPitchClass
        && resolvedPitchClass.isNatural
}
```

### 修改后

- 新增 `currentPositionPromptAllowedFrets`
- 新增 `currentPositionPromptVisiblePrompt(for:)`
- 新增 `positionPromptCellMatchesCurrentTrainer(_:expectedPitchClass:)`
- `positionPromptSessionMatchesCurrentTrainer(_:)` 改成：
- 先根据当前 feedback phase 决定“屏幕上实际可见的 prompt 是谁”
- 再检查这个可见 prompt 的 fret 是否仍在允许集合里
- 再检查它在当前 configuration 下解析出来的 pitch class 是否仍与期望一致、且依然是自然音
- 这样当用户改完筛选后，若当前屏幕正在展示的 prompt 已经非法，控制器就会立刻把它判定为失效，从而触发重建

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: currentPositionPromptAllowedFrets,
// positionPromptSessionMatchesCurrentTrainer(_:),
// currentPositionPromptVisiblePrompt(for:),
// positionPromptCellMatchesCurrentTrainer(_:expectedPitchClass:)
// 功能说明: 修改后 iOS 端会按“当前可见 prompt + 当前允许品位”判断 session 是否仍有效；
// 这样筛选变化后，非法当前题会立即被视为失效，而合法的红闪/绿停留仍可继续完成。
private var currentPositionPromptAllowedFrets: Set<Int> {
    trainerDisplayState.positionPromptConfiguration.selectedFrets
}

private func positionPromptSessionMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return false
    }

    let visiblePrompt = currentPositionPromptVisiblePrompt(
        for: session
    )
    return positionPromptCellMatchesCurrentTrainer(
        visiblePrompt.cell,
        expectedPitchClass: visiblePrompt.pitchClass
    )
}

private func currentPositionPromptVisiblePrompt(
    for session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> (cell: FretboardCell, pitchClass: PitchClass) {
    guard let positionPromptLastEvaluation else {
        return (
            cell: session.promptCell,
            pitchClass: session.promptPitchClass
        )
    }

    switch currentPositionPromptOverlayPhase {
    case .neutralWhite:
        return (
            cell: session.promptCell,
            pitchClass: session.promptPitchClass
        )
    case .wrongFlash, .correctHold:
        return (
            cell: positionPromptLastEvaluation.promptCell,
            pitchClass: positionPromptLastEvaluation.expectedPitchClass
        )
    }
}

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

## 修改 2：macOS 端做对称改造，保证双端对“非法当前题”的判定一致

### 修改前

- macOS 与 iOS 的旧逻辑完全对称
- `positionPromptSessionMatchesCurrentTrainer(_:)` 同样只看 `session.promptCell`
- 也同样忽略了：
- 当前筛选集合 `selectedFrets`
- 当前显示阶段对应的“可见 prompt”究竟是新题还是旧题

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: positionPromptSessionMatchesCurrentTrainer(_:)
// 功能说明: 修改前 macOS 端与 iOS 相同；
// 只校验 session.promptCell 是否还能解析出 session.promptPitchClass，未纳入可见 prompt 与当前允许品位。
private func positionPromptSessionMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    guard case .positionPrompt = fretboardTrainerState.mode,
          let resolvedPitchClass = displayState.configuration.pitchClass(
            for: session.promptCell
          ) else {
        return false
    }

    return resolvedPitchClass == session.promptPitchClass
        && resolvedPitchClass.isNatural
}
```

### 修改后

- macOS 端也新增了 `currentPositionPromptAllowedFrets`
- 并复制同样的：
- `currentPositionPromptVisiblePrompt(for:)`
- `positionPromptCellMatchesCurrentTrainer(_:expectedPitchClass:)`
- 这样 AppKit 和 UIKit 在筛选变化后的 session 判定与重建时序上保持一致，不会出现一端重建、另一端继续显示非法题目的分叉

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: currentPositionPromptAllowedFrets,
// positionPromptSessionMatchesCurrentTrainer(_:),
// currentPositionPromptVisiblePrompt(for:),
// positionPromptCellMatchesCurrentTrainer(_:expectedPitchClass:)
// 功能说明: 修改后 macOS 端也按“当前可见 prompt + 当前允许品位”判断 session；
// 双端在红闪/绿停留阶段对非法题目的重建时机保持一致。
private var currentPositionPromptAllowedFrets: Set<Int> {
    trainerDisplayState.positionPromptConfiguration.selectedFrets
}

private func positionPromptSessionMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return false
    }

    let visiblePrompt = currentPositionPromptVisiblePrompt(
        for: session
    )
    return positionPromptCellMatchesCurrentTrainer(
        visiblePrompt.cell,
        expectedPitchClass: visiblePrompt.pitchClass
    )
}

private func currentPositionPromptVisiblePrompt(
    for session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> (cell: FretboardCell, pitchClass: PitchClass) {
    guard let positionPromptLastEvaluation else {
        return (
            cell: session.promptCell,
            pitchClass: session.promptPitchClass
        )
    }

    switch currentPositionPromptOverlayPhase {
    case .neutralWhite:
        return (
            cell: session.promptCell,
            pitchClass: session.promptPitchClass
        )
    case .wrongFlash, .correctHold:
        return (
            cell: positionPromptLastEvaluation.promptCell,
            pitchClass: positionPromptLastEvaluation.expectedPitchClass
        )
    }
}

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

## 修改 3：settings 事件处理区分“exercise mode 切换”和“positionPrompt 品位筛选变化”，让重建理由更准确

### 修改前

- 双端 `handleSettingsPanelEvent(_:)` 只要 `didChangeTrainer == true`
- 就一律调用 `synchronizeTrainerPresentationState(reason: "exerciseModeChanged")`
- 这会把“品位筛选变化”和“练习模式切换”混成同一种同步理由
- 虽然功能上仍然会进入同步流程，但控制器侧无法明确表达当前重建到底是因为切模式，还是因为 `positionPrompt` 的 fret-filter 改了

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: handleSettingsPanelEvent(_:)
// 功能说明: 修改前 iOS 端只要 trainerDisplayState 变化，就一律按 exerciseModeChanged 同步；
// 这样 positionPromptFretsChanged 无法被单独识别。
private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    // ...
    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState
    let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState

    guard didChangeFretboard || didChangeStaff || didChangePage || didChangeTrainer else {
        return
    }

    // ...

    if didChangeTrainer {
        synchronizeTrainerPresentationState(reason: "exerciseModeChanged")
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handleSettingsPanelEvent(_:)
// 功能说明: 修改前 macOS 端同样把所有 trainer 变化都归并为 exerciseModeChanged。
private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    // ...
    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState
    let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState

    guard didChangeFretboard || didChangeStaff || didChangePage || didChangeTrainer else {
        return
    }

    // ...

    if didChangeTrainer {
        synchronizeTrainerPresentationState(reason: "exerciseModeChanged")
    }
}
```

### 修改后

- 双端都额外计算：
- `didChangeExerciseMode`
- `didChangePositionPromptFrets`
- 然后根据变化源挑选更准确的 `trainerSyncReason`
- 这样本阶段引入的“筛选变化后若当前题非法则重建”会以 `positionPromptFretsChanged` 进入同步链路，更符合实际行为，也更利于后续日志分析和进一步扩展

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS 端会把 exercise mode 变化、positionPrompt 品位筛选变化和一般 trainer 设置变化分开识别；
// 当用户切换 fret-filter 时，控制器会以 positionPromptFretsChanged 为理由进入同步与重建流程。
private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    // ...
    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState
    let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState
    let didChangeExerciseMode = nextTrainerDisplayState.exerciseMode != trainerDisplayState.exerciseMode
    let didChangePositionPromptFrets = nextTrainerDisplayState.positionPromptConfiguration
        != trainerDisplayState.positionPromptConfiguration

    guard didChangeFretboard || didChangeStaff || didChangePage || didChangeTrainer else {
        return
    }

    // ...

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
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS 端也使用同样的 trainerSyncReason 分流逻辑；
// 双端都会把 fret-filter 变化单独识别为 positionPromptFretsChanged。
private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    // ...
    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState
    let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState
    let didChangeExerciseMode = nextTrainerDisplayState.exerciseMode != trainerDisplayState.exerciseMode
    let didChangePositionPromptFrets = nextTrainerDisplayState.positionPromptConfiguration
        != trainerDisplayState.positionPromptConfiguration

    guard didChangeFretboard || didChangeStaff || didChangePage || didChangeTrainer else {
        return
    }

    // ...

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
}
```

## 修改 4：利用既有 `ensurePositionPromptSession()` 重建流程，而不是额外发明第二套非法题修复入口

### 修改前

- 阶段 4 之前，`ensurePositionPromptSession()` 虽然已经具备：
- 取消 pending transition
- session 无效时重建
- 清空反馈态并回到 `neutralWhite`
- 但由于“session 是否有效”的定义还不包含当前筛选和当前可见 prompt，它无法在品位筛选变化后正确识别“当前题已经非法”

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: ensurePositionPromptSession()
// 功能说明: 修改前 ensurePositionPromptSession 已经具备取消 pending transition 与重建的骨架；
// 但 session 匹配条件过宽，所以筛选变化后不一定能正确触发这条重建路径。
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
        allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
        using: &generator
    )
    clearPositionPromptFeedbackState()
    positionPromptOverlayPhase = .neutralWhite
}
```

### 修改后

- 本阶段没有再复制一套新的“非法题修复函数”
- 而是通过升级 `positionPromptSessionMatchesCurrentTrainer(_:)`，让现有 `ensurePositionPromptSession()` 能在以下场景自然工作：
- 旧题依然合法：继续保留当前 feedback 时序
- 旧题已非法：取消 pending transition、立即重建、清空旧反馈并切回 `neutralWhite`
- 也就是说，阶段 5 的关键不是新增重建入口，而是让现有重建入口终于拥有正确的判定条件

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: positionPromptSessionMatchesCurrentTrainer(_:), ensurePositionPromptSession()
// 功能说明: 修改后 positionPromptSessionMatchesCurrentTrainer 会按当前可见 prompt 和当前允许品位严格判定；
// 因此 ensurePositionPromptSession 原有的“失效则取消 pending transition 并重建”流程就可以准确处理非法当前题。
private func positionPromptSessionMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return false
    }

    let visiblePrompt = currentPositionPromptVisiblePrompt(
        for: session
    )
    return positionPromptCellMatchesCurrentTrainer(
        visiblePrompt.cell,
        expectedPitchClass: visiblePrompt.pitchClass
    )
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
        allowedFrets: trainerDisplayState.positionPromptConfiguration.selectedFrets,
        using: &generator
    )
    clearPositionPromptFeedbackState()
    positionPromptOverlayPhase = .neutralWhite
}
```

## 修改 5：同步计划状态，标记阶段 5 完成

### 修改前

- `phase5-controller-rebuild` 在计划文件里仍处于进行中
- 计划状态尚未反映“控制器已经能根据筛选变化重建非法当前题”

```md
<!-- 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md -->
<!-- 函数名/符号: todo item phase5-controller-rebuild -->
<!-- 功能说明: 修改前计划文件还把阶段 5 记为进行中。 -->
- id: phase5-controller-rebuild
  content: 在 iOS/macOS 控制器中把筛选状态纳入 session 匹配与重建逻辑，筛选变化时重建非法题目并保持交互时序稳定
  status: in_progress
```

### 修改后

- `phase5-controller-rebuild` 已标记为 `completed`
- 计划文件与当前控制器代码状态保持一致，下一步可以进入阶段 6 的 validation 与回归补充

```md
<!-- 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md -->
<!-- 函数名/符号: todo item phase5-controller-rebuild -->
<!-- 功能说明: 修改后计划文件已确认阶段 5 完成；
下一步可进入自动化 validation 扩展与手工回归清单补充。 -->
- id: phase5-controller-rebuild
  content: 在 iOS/macOS 控制器中把筛选状态纳入 session 匹配与重建逻辑，筛选变化时重建非法题目并保持交互时序稳定
  status: completed
```

## 验证情况

- 已对 `iOSViewController.swift` 与 `macOSViewController.swift` 运行静态诊断，`ReadLints` 未发现新增问题
- 额外用 `git diff` 核对了两端控制器与计划文件的实际改动，确认本阶段只涉及：
- `positionPrompt` session 匹配逻辑升级
- `trainerSyncReason` 分流
- 计划状态同步
- 本阶段没有运行 `xcodebuild`，也没有做 iOS / macOS 手工点击回归
- 当前仍留待阶段 6 的内容：
- 补充自动化 validation 场景，覆盖子集筛选、最后一个品位不可取消等边界
- 补手工回归清单，验证双端实际交互时序

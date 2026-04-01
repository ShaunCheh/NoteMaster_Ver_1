# 20260401_141649_phase3_position_prompt_platform_session_reset

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_141649`
- 记录范围：`position prompt` 轮巡调度改造的阶段 3，只覆盖平台层 `session` 生命周期与 reset 边界收口，不包含共享层选题算法和 validation 改写
- 修改性质：这一步不是再改共享层出题，而是把 `macOS` / `iOS` 控制器从“只看当前题面是否合法”升级为“同时看当前题面是否合法 + 当前调度状态是否仍然属于当前候选池”，并把 `filter` 变化统一收口成强制重建 `position prompt session`
- 涉及文件：
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`

## 修改前

- 平台层判断 `positionPromptSession` 是否还能复用时，只看：
- 当前模式是否还是 `.positionPrompt`
- 当前可见的 `promptCell` 是否还能在 `displayState.configuration` 里解析出同一个自然音
- 当前可见的 `promptCell` 是否仍命中 `currentPositionPromptFilter`
- 也就是说，只要当前题面本身仍然合法，平台层就会继续保留旧 session
- 但阶段 2 之后，`session` 里已经带有 `candidatePoolSignature`、轮次和命中统计；如果 `filter`、`instrument`、`tuning`、`maxFret` 等发生变化，仅靠“当前题面合法”已经不足以判断旧调度状态还能不能复用
- 同时，`positionPromptFilterChanged` 之前只有在 overlay 不处于 `neutralWhite` 时才主动 reset，这会导致 filter 变化后在某些路径下继续沿用旧轮次

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: positionPromptSessionMatchesCurrentTrainer(_:)
// 功能说明: 修改前平台层只根据“当前可见题面”判断 session 是否可复用；
// 没有把共享层的 candidatePoolSignature 纳入匹配条件。
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: positionPromptSessionMatchesCurrentTrainer(_:)
// 功能说明: 修改前 iOS 和 macOS 保持同样的旧语义；
// 只要题面格子和当前 filter 还能对上，就继续保留旧 session。
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改前只有在 filter 变化且当前 overlay 不处于 neutralWhite 时，才会主动 reset 旧 session；
// 这会让 filter 改变后在部分路径下继续沿用旧的轮次和命中统计。
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

    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改前 iOS 也沿用同样的条件 reset；
// filter 变化并不总是会清空旧的 position prompt session。
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

    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}
```

## 修改后

- 平台层新增 `currentPositionPromptCandidatePoolSignature`
- 它会基于：
- `displayState.configuration`
- `currentPositionPromptFilter`
- 重新计算“当前候选池身份”
- 平台层新增 `positionPromptSchedulingMatchesCurrentTrainer(_:)`
- `positionPromptSessionMatchesCurrentTrainer(_:)` 现在先比较：
- `session.schedulingState.candidatePoolSignature`
- `currentPositionPromptCandidatePoolSignature`
- 只有签名匹配，才继续看当前题面是否合法
- 这样一来，只要 `filter`、`instrument`、`tuning`、`maxFret` 等导致候选池身份变化，旧 session 就会在 `ensurePositionPromptSession()` 中失效并重建
- 同时把 `positionPromptFilterChanged` 收口成无条件 `resetPositionPromptInteractionState()`，确保每次 filter 切换都从新轮次开始，不再残留旧轮次和旧 hit 统计
- `macOS` 和 `iOS` 两端都做了同样的改动，保持镜像行为

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: currentPositionPromptCandidatePoolSignature / positionPromptSessionMatchesCurrentTrainer(_:) / positionPromptSchedulingMatchesCurrentTrainer(_:)
// 功能说明: 修改后 macOS 平台层会先比较共享层 candidatePoolSignature；
// 只有当前调度状态仍属于当前候选池，才继续复用旧 session。
private var currentPositionPromptFilter: PositionPromptCandidateFilter {
    trainerDisplayState.positionPromptConfiguration.activeFilter
}

private var currentPositionPromptCandidatePoolSignature: FretboardNaturalNoteTrainerState.PositionPromptSession.SchedulingState.CandidatePoolSignature {
    FretboardNaturalNoteTrainerState.positionPromptCandidatePoolSignature(
        in: displayState.configuration,
        filter: currentPositionPromptFilter
    )
}

private func positionPromptSessionMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return false
    }
    guard positionPromptSchedulingMatchesCurrentTrainer(session) else {
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

private func positionPromptSchedulingMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    session.schedulingState.candidatePoolSignature
        == currentPositionPromptCandidatePoolSignature
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: currentPositionPromptCandidatePoolSignature / positionPromptSessionMatchesCurrentTrainer(_:) / positionPromptSchedulingMatchesCurrentTrainer(_:)
// 功能说明: 修改后 iOS 侧和 macOS 侧保持相同的签名校验逻辑；
// 旧 session 是否还能复用，不再只由当前题面决定。
private var currentPositionPromptFilter: PositionPromptCandidateFilter {
    trainerDisplayState.positionPromptConfiguration.activeFilter
}

private var currentPositionPromptCandidatePoolSignature: FretboardNaturalNoteTrainerState.PositionPromptSession.SchedulingState.CandidatePoolSignature {
    FretboardNaturalNoteTrainerState.positionPromptCandidatePoolSignature(
        in: displayState.configuration,
        filter: currentPositionPromptFilter
    )
}

private func positionPromptSessionMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    guard case .positionPrompt = fretboardTrainerState.mode else {
        return false
    }
    guard positionPromptSchedulingMatchesCurrentTrainer(session) else {
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

private func positionPromptSchedulingMatchesCurrentTrainer(
    _ session: FretboardNaturalNoteTrainerState.PositionPromptSession
) -> Bool {
    session.schedulingState.candidatePoolSignature
        == currentPositionPromptCandidatePoolSignature
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改后 macOS 平台层把 positionPromptFilterChanged 收口为无条件 reset；
// 只要 filter 改变，就明确丢弃旧轮次、旧命中统计和旧延时任务。
private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    if reason == "positionPromptFilterChanged" {
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

    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: synchronizePositionPromptPresentation(reason:)
// 功能说明: 修改后 iOS 同样在 filter 变化时无条件清空旧 session；
// 这样两端都不会再把新 filter 和旧轮次混在一起。
private func synchronizePositionPromptPresentation(reason: String) {
    resetSingleCoverageInteractionState()
    resetQuarterNoteSequenceInteractionState()

    if pageDisplayState != .positionPrompt {
        pageDisplayState = .positionPrompt
    }

    if staffDisplayState != baseStaffDisplayState {
        staffDisplayState = baseStaffDisplayState
    }

    if reason == "positionPromptFilterChanged" {
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

    applyPositionPromptProjection(
        reason: reason,
        showsLog: true
    )
}
```

## 本阶段平台层语义

- `ensurePositionPromptSession()` 仍然是平台层的统一 session 入口
- 但它现在会通过 `positionPromptSessionMatchesCurrentTrainer(_:)` 间接比较 `candidatePoolSignature`
- 只要候选池身份变化，旧 session 就会被判定为失效，并由平台层重建
- `filter` 变化时不再“尽量保留旧 session”，而是明确从新 session、新轮次开始
- `macOS` 与 `iOS` 现在在 `position prompt` 的 session 复用和 reset 行为上保持镜像

## 本阶段尚未改动

- 共享层 `trainer` 选题逻辑没有再改，仍沿用阶段 2 的“按弦轮巡 + 弦内低频优先”
- `FretboardValidation.swift` 还没有从旧的“首题/次题固定候选顺序”假设迁移到新的轮巡语义
- 还没有补充更细粒度的 `PositionPrompt` 调试日志字段，例如当前轮剩余弦和最低频候选数量
- 还没有生成阶段 3 对应的手工回归记录或自动化验证更新

## 本阶段结果

- 平台层已经能识别“当前题面虽合法，但旧调度状态已不属于当前候选池”的情况
- `positionPromptFilterChanged` 不会再残留旧轮次和旧命中统计
- 后续只需要继续推进 validation 和回归验证，不需要再回头推翻平台层 session 生命周期的收口方式

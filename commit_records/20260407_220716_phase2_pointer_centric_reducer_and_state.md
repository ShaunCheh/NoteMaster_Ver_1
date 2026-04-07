# 20260407_220716_phase2_pointer_centric_reducer_and_state

## 记录范围

本记录只覆盖刚刚这一轮“多指复音计划 phase2：把 `Shared/Piano` 的 reducer 与组件状态升级为 pointer-centric，多路交互并行”的实际代码修改。

这次修改的目标不是把平台输入宿主直接升级成真正的多触点采集，也不是把播放后端直接升级成复音 mixer；这一步只处理共享状态机本身：

- 不再按“全局唯一 `activeInteraction`”分发 reducer
- 允许多个 `keys` pointer 并发建立独立 preview / keyGlissando 会话
- 继续把 `buttonPressed` / `scaleDrag` 约束为单 owner 控制交互
- 让 `active zone` 判断与当前 pointer 会话绑定
- 增补自动化夹具，把这些行为边界固定下来

本记录参考了当前工作区的 `git diff` 与文件现状，但 **不包含原始 diff**。

当前工作区里，与本轮 phase2 直接相关的代码文件有 9 个：

- `NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationReducerAndPresentation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationInteractionAndGeometry.swift`

当前工作区另外还存在 `@.cursor/plans/多指复音计划_27c48b8b.plan.md` 的变更，但它不是本轮 phase2 代码实现的一部分，因此本记录不把它计入“修改前/修改后”范围。

---

## 1. 给 interaction 增加 pointer-centric 语义标签：`PianoInteraction.swift`

### 1.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift
// 函数名: PianoInteractionState.pointerID / rowIndex
// 功能说明: 修改前 interaction 虽然已经带有 pointerID，但 reducer 仍缺少“这是 key preview 还是独占控制交互”的统一语义入口；后续状态机只能继续写死在 switch 里。
enum PianoInteractionState: Equatable, Sendable {
    case buttonPressed(PianoButtonPressInteraction)
    case scaleDrag(PianoScaleDragInteraction)
    case keyGlissando(PianoKeyGlissandoInteraction)

    var pointerID: PianoPointerID {
        switch self {
        case let .buttonPressed(interaction):
            return interaction.pointerID
        case let .scaleDrag(interaction):
            return interaction.pointerID
        case let .keyGlissando(interaction):
            return interaction.pointerID
        }
    }

    var rowIndex: Int {
        switch self {
        case let .buttonPressed(interaction):
            return interaction.rowIndex
        case let .scaleDrag(interaction):
            return interaction.rowIndex
        case let .keyGlissando(interaction):
            return interaction.rowIndex
        }
    }
}
```

### 1.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift
// 函数名: PianoInteractionState.currentPreview / isExclusiveControlInteraction / isKeyPreviewInteraction
// 功能说明: 修改后把“当前会话是否持有 preview”“是否属于独占控制区”“是否属于 keys 预览区”抽成统一语义入口，供 state / reducer / validation 共用，而不是每处各写一份判断。
enum PianoInteractionState: Equatable, Sendable {
    case buttonPressed(PianoButtonPressInteraction)
    case scaleDrag(PianoScaleDragInteraction)
    case keyGlissando(PianoKeyGlissandoInteraction)

    var pointerID: PianoPointerID {
        switch self {
        case let .buttonPressed(interaction):
            return interaction.pointerID
        case let .scaleDrag(interaction):
            return interaction.pointerID
        case let .keyGlissando(interaction):
            return interaction.pointerID
        }
    }

    var currentPreview: PianoPreviewState? {
        switch self {
        case .buttonPressed, .scaleDrag:
            return nil
        case let .keyGlissando(interaction):
            return interaction.currentPreview
        }
    }

    var isExclusiveControlInteraction: Bool {
        switch self {
        case .buttonPressed, .scaleDrag:
            return true
        case .keyGlissando:
            return false
        }
    }

    var isKeyPreviewInteraction: Bool {
        switch self {
        case .buttonPressed, .scaleDrag:
            return false
        case .keyGlissando:
            return true
        }
    }
}
```

---

## 2. 把组件状态真正切到 pointer-centric map：`PianoState.swift`

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名: PianoComponentState.activeInteraction / preview
// 功能说明: 修改前底层虽然已经有 activePreviews / activeInteractionsByPointer 两张表，但读取逻辑仍然优先服务旧的单值访问口，reducer 也没有可复用的按 pointer 访问与写回 helper。
struct PianoComponentState: Equatable, Sendable {
    var rows: [PianoRowState]
    var activePreviews: [PianoPreviewID: PianoPreviewState]
    var activeInteractionsByPointer: [PianoPointerID: PianoInteractionState]

    var activeInteraction: PianoInteractionState? {
        get {
            if let interaction = activeInteractionsByPointer[.legacyPrimary] {
                return interaction
            }

            return activeInteractionsByPointer
                .sorted { lhs, rhs in lhs.key.rawValue < rhs.key.rawValue }
                .first?
                .value
        }
        set {
            guard let newValue else {
                activeInteractionsByPointer.removeAll()
                return
            }

            // 兼容旧调用方：phase 2 之前，状态机仍主要通过单值入口工作。
            activeInteractionsByPointer = [newValue.pointerID: newValue]
        }
    }

    var isPreviewing: Bool {
        !activePreviews.isEmpty
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名: PianoComponentState.activeInteraction / activeExclusiveControlInteraction / interaction(for:) / setPreview(_:for:) / setInteraction(_:for:)
// 功能说明: 修改后状态对象不只“存 map”，还显式提供按 pointer 的读写 helper、独占控制检测与 preview 查询；这样 reducer 可以直接操作多路会话，而不是继续经由兼容单值口压扁状态。
struct PianoComponentState: Equatable, Sendable {
    var rows: [PianoRowState]
    var activePreviews: [PianoPreviewID: PianoPreviewState]
    var activeInteractionsByPointer: [PianoPointerID: PianoInteractionState]

    var activeInteraction: PianoInteractionState? {
        get {
            if let interaction = activeInteractionsByPointer[.legacyPrimary] {
                return interaction
            }

            if let interaction = activeExclusiveControlInteraction {
                return interaction
            }

            return activeInteractionsByPointer
                .sorted { lhs, rhs in lhs.key.rawValue < rhs.key.rawValue }
                .first?
                .value
        }
        set {
            guard let newValue else {
                activeInteractionsByPointer.removeAll()
                return
            }

            // 兼容旧调用方：单值入口仍保留，但 reducer 不再依赖它。
            activeInteractionsByPointer = [newValue.pointerID: newValue]
        }
    }

    var activeExclusiveControlInteraction: PianoInteractionState? {
        activeInteractionsByPointer.values
            .filter { $0.isExclusiveControlInteraction }
            .sorted { lhs, rhs in lhs.pointerID.rawValue < rhs.pointerID.rawValue }
            .first
    }

    var hasActiveExclusiveControlInteraction: Bool {
        activeExclusiveControlInteraction != nil
    }

    var hasActiveKeyPreviewInteractions: Bool {
        activeInteractionsByPointer.values.contains { $0.isKeyPreviewInteraction }
    }

    func interaction(for pointerID: PianoPointerID) -> PianoInteractionState? {
        activeInteractionsByPointer[pointerID]
    }

    func preview(for pointerID: PianoPointerID) -> PianoPreviewState? {
        activePreviews[pointerID.previewID]
    }

    mutating func setPreview(
        _ preview: PianoPreviewState?,
        for previewID: PianoPreviewID
    ) {
        guard let preview else {
            activePreviews.removeValue(forKey: previewID)
            return
        }

        activePreviews[previewID] = preview
    }

    mutating func setInteraction(
        _ interaction: PianoInteractionState?,
        for pointerID: PianoPointerID
    ) {
        guard let interaction else {
            activeInteractionsByPointer.removeValue(forKey: pointerID)
            return
        }

        activeInteractionsByPointer[pointerID] = interaction
    }
}
```

---

## 3. 重写 reducer：从“全局唯一交互”切到“按 pointer 会话”

### 3.1 分发入口：`PianoInteractionReducer.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduce(state:rawEvent:hitResult:configuration:)
// 功能说明: 修改前 reducer 入口直接看 state.activeInteraction；这意味着只要有一个 pointer 正在交互，第二个 pointer 的 rawEvent 就会被当成“同一条全局交互的后续事件”处理。
static func reduce(
    state: PianoComponentState,
    rawEvent: PianoRawEvent,
    hitResult: PianoHitResult,
    configuration: PianoConfiguration
) -> PianoReduction {
    let hitResult = synchronizedHitResult(
        rawEvent: rawEvent,
        hitResult: hitResult
    )

    switch state.activeInteraction {
    case nil:
        return reduceWithoutActiveInteraction(
            state: state,
            rawEvent: rawEvent,
            hitResult: hitResult
        )
    case let .buttonPressed(interaction):
        return reduceButtonPress(
            interaction,
            state: state,
            hitResult: hitResult,
            configuration: configuration
        )
    case let .scaleDrag(interaction):
        return reduceScaleDrag(
            interaction,
            state: state,
            rawEvent: rawEvent,
            hitResult: hitResult,
            configuration: configuration
        )
    case let .keyGlissando(interaction):
        return reduceKeyGlissando(
            interaction,
            state: state,
            hitResult: hitResult
        )
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduce(state:rawEvent:hitResult:configuration:)
// 功能说明: 修改后 reducer 会先按 rawEvent.pointerID 找本 pointer 的活动会话；只有该 pointer 没有跟踪态时，才会进入“新建会话”分支，从根上解除第二个 key pointer 被第一个 pointer 全局覆盖的问题。
static func reduce(
    state: PianoComponentState,
    rawEvent: PianoRawEvent,
    hitResult: PianoHitResult,
    configuration: PianoConfiguration
) -> PianoReduction {
    let hitResult = synchronizedHitResult(
        rawEvent: rawEvent,
        hitResult: hitResult
    )

    guard let trackedInteraction = state.interaction(for: rawEvent.pointerID) else {
        return reduceWithoutTrackedInteraction(
            state: state,
            rawEvent: rawEvent,
            hitResult: hitResult
        )
    }

    switch trackedInteraction {
    case let .buttonPressed(interaction):
        return reduceButtonPress(
            interaction,
            state: state,
            hitResult: hitResult,
            configuration: configuration
        )
    case let .scaleDrag(interaction):
        return reduceScaleDrag(
            interaction,
            state: state,
            rawEvent: rawEvent,
            hitResult: hitResult,
            configuration: configuration
        )
    case let .keyGlissando(interaction):
        return reduceKeyGlissando(
            interaction,
            state: state,
            hitResult: hitResult
        )
    }
}
```

### 3.2 新建会话与互斥策略：`PianoInteractionReducer.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduceWithoutActiveInteraction(...)
// 功能说明: 修改前所有 began 都共用一个“无活动交互”入口，keys/button/scale 写回的都是单值 preview / activeInteraction；控制区与 keys 也没有显式的并发/互斥边界。
static func reduceWithoutActiveInteraction(
    state: PianoComponentState,
    rawEvent: PianoRawEvent,
    hitResult: PianoHitResult
) -> PianoReduction {
    guard rawEvent.phase == .began else {
        return .unchanged(state)
    }

    switch hitResult.zone {
    case .buttonLeft, .buttonRight:
        var nextState = state
        nextState.activeInteraction = .buttonPressed(
            PianoButtonPressInteraction(
                pointerID: rawEvent.pointerID,
                rowIndex: rowIndex,
                direction: direction,
                movementScope: rowState.movementScope
            )
        )
        return PianoReduction(previousState: state, nextState: nextState, semanticEvents: [])
    case .scale:
        var nextState = state
        nextState.activeInteraction = .scaleDrag(
            PianoScaleDragInteraction(
                pointerID: rawEvent.pointerID,
                rowIndex: rowIndex,
                movementScope: rowState.movementScope,
                beganLocationInView: rawEvent.locationInView,
                affectedRowIndices: affectedRowIndices,
                initialOffsetsX: initialOffsetsX
            )
        )
        return PianoReduction(previousState: state, nextState: nextState, semanticEvents: [])
    case .keys:
        let preview = PianoPreviewState(
            previewID: rawEvent.pointerID.previewID,
            rowIndex: rowIndex,
            note: note
        )

        var nextState = state
        nextState.preview = preview
        nextState.activeInteraction = .keyGlissando(
            PianoKeyGlissandoInteraction(
                pointerID: rawEvent.pointerID,
                rowIndex: rowIndex,
                currentPreview: preview
            )
        )
        return PianoReduction(
            previousState: state,
            nextState: nextState,
            semanticEvents: [.previewStarted(preview)]
        )
    case .outside:
        return .unchanged(state)
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduceWithoutTrackedInteraction(...)
// 功能说明: 修改后开始明确“keys 可并发、button/scale 独占”的 phase2 边界：有任一活动 key preview 时不允许新建 control 会话；有独占控制会话时不允许新建任何新的 key preview；keys 写回也改成 pointer-specific map。
static func reduceWithoutTrackedInteraction(
    state: PianoComponentState,
    rawEvent: PianoRawEvent,
    hitResult: PianoHitResult
) -> PianoReduction {
    guard rawEvent.phase == .began else {
        return .unchanged(state)
    }

    switch hitResult.zone {
    case .buttonLeft, .buttonRight:
        guard !state.hasActiveExclusiveControlInteraction,
              !state.hasActiveKeyPreviewInteractions else {
            return .unchanged(state)
        }

        var nextState = state
        let interaction = PianoButtonPressInteraction(
            pointerID: rawEvent.pointerID,
            rowIndex: rowIndex,
            direction: direction,
            movementScope: rowState.movementScope
        )
        nextState.setInteraction(.buttonPressed(interaction), for: rawEvent.pointerID)
        return PianoReduction(previousState: state, nextState: nextState, semanticEvents: [])

    case .scale:
        guard !state.hasActiveExclusiveControlInteraction,
              !state.hasActiveKeyPreviewInteractions else {
            return .unchanged(state)
        }

        var nextState = state
        let interaction = PianoScaleDragInteraction(
            pointerID: rawEvent.pointerID,
            rowIndex: rowIndex,
            movementScope: rowState.movementScope,
            beganLocationInView: rawEvent.locationInView,
            affectedRowIndices: affectedRowIndices,
            initialOffsetsX: initialOffsetsX
        )
        nextState.setInteraction(.scaleDrag(interaction), for: rawEvent.pointerID)
        return PianoReduction(previousState: state, nextState: nextState, semanticEvents: [])

    case .keys:
        guard !state.hasActiveExclusiveControlInteraction else {
            return .unchanged(state)
        }

        let preview = PianoPreviewState(
            previewID: rawEvent.pointerID.previewID,
            rowIndex: rowIndex,
            note: note
        )

        var nextState = state
        nextState.setPreview(preview, for: preview.previewID)
        let interaction = PianoKeyGlissandoInteraction(
            pointerID: rawEvent.pointerID,
            rowIndex: rowIndex,
            currentPreview: preview
        )
        nextState.setInteraction(.keyGlissando(interaction), for: rawEvent.pointerID)
        return PianoReduction(
            previousState: state,
            nextState: nextState,
            semanticEvents: [.previewStarted(preview)]
        )

    case .outside:
        return .unchanged(state)
    }
}
```

### 3.3 preview 结束路径：`PianoInteractionReducer.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduceKeyGlissando(...) / endPreview(...)
// 功能说明: 修改前 keyGlissando 结束时会把全局 preview / activeInteraction 一次性清空；这会让“旧 pointer 的 ended”有机会误杀别的活动会话。
if hitResult.rowIndex == interaction.rowIndex,
   hitResult.zone == .keys,
   let note = hitResult.note,
   note != interaction.currentPreview.note {
    let finalPreview = PianoPreviewState(
        previewID: interaction.currentPreview.previewID,
        rowIndex: interaction.rowIndex,
        note: note
    )

    var nextState = state
    nextState.preview = nil
    nextState.activeInteraction = nil

    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: [
            .previewChanged(finalPreview),
            .previewEnded(finalPreview)
        ]
    )
}

static func endPreview(
    state: PianoComponentState,
    preview: PianoPreviewState
) -> PianoReduction {
    var nextState = state
    nextState.preview = nil
    nextState.activeInteraction = nil

    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: [.previewEnded(preview)]
    )
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: reduceKeyGlissando(...) / endPreview(...)
// 功能说明: 修改后 preview 结束只会移除当前 previewID 与当前 pointerID 对应的那条会话；同一时刻仍在活动的其他 key pointer 会继续保留在 map 里。
if hitResult.rowIndex == interaction.rowIndex,
   hitResult.zone == .keys,
   let note = hitResult.note,
   note != interaction.currentPreview.note {
    let finalPreview = PianoPreviewState(
        previewID: interaction.currentPreview.previewID,
        rowIndex: interaction.rowIndex,
        note: note
    )

    return endPreview(
        state: state,
        preview: finalPreview,
        pointerID: interaction.pointerID,
        leadingSemanticEvents: [
            .previewChanged(finalPreview),
            .previewEnded(finalPreview)
        ]
    )
}

static func endPreview(
    state: PianoComponentState,
    preview: PianoPreviewState,
    pointerID: PianoPointerID,
    leadingSemanticEvents: [PianoSemanticEvent] = []
) -> PianoReduction {
    var nextState = state
    nextState.setPreview(nil, for: preview.previewID)
    nextState.setInteraction(nil, for: pointerID)

    return PianoReduction(
        previousState: state,
        nextState: nextState,
        semanticEvents: leadingSemanticEvents.isEmpty
            ? [.previewEnded(preview)]
            : leadingSemanticEvents
    )
}
```

---

## 4. 让 active zone 真正绑定到当前 pointer：`PianoGeometry.swift`

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名: hitTest(_:phase:) / makeHitResult(...) / isInsideActiveZone(for:)
// 功能说明: 修改前 hit test 只知道 point + phase，不知道当前事件来自哪个 pointer；isInsideActiveZone 也只能读取全局 activeInteraction，因此别的 pointer 可能继承错误的锁定区语义。
func hitTest(
    _ point: CGPoint,
    phase: PianoEventPhase
) -> PianoHitResult {
    // ... 省略其他命中分支
    return PianoHitResult(
        phase: phase,
        locationInView: normalizedPoint,
        rowIndex: nil,
        zone: .outside,
        note: nil,
        isInsideActiveZone: false
    )
}

private func makeHitResult(
    phase: PianoEventPhase,
    location: CGPoint,
    rowIndex: Int,
    zone: PianoZone,
    note: NotePitch?
) -> PianoHitResult {
    let provisionalHit = PianoHitResult(
        phase: phase,
        locationInView: location,
        rowIndex: rowIndex,
        zone: zone,
        note: note,
        isInsideActiveZone: false
    )

    return PianoHitResult(
        phase: provisionalHit.phase,
        locationInView: provisionalHit.locationInView,
        rowIndex: provisionalHit.rowIndex,
        zone: provisionalHit.zone,
        note: provisionalHit.note,
        isInsideActiveZone: isInsideActiveZone(for: provisionalHit)
    )
}

private func isInsideActiveZone(
    for hit: PianoHitResult
) -> Bool {
    guard let activeInteraction = state.activeInteraction else {
        return hit.zone != .outside
    }

    // ... 按单个全局 activeInteraction 判断
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名: hitTest(_:phase:pointerID:) / makeHitResult(...) / isInsideActiveZone(for:)
// 功能说明: 修改后 geometry 也进入 pointer-centric 语义：hitResult 从一开始就带上 pointerID，insideActiveZone 按当前 pointer 的 interaction 查询，不会把别人的锁定态借给当前命中事件。
func hitTest(
    _ point: CGPoint,
    phase: PianoEventPhase,
    pointerID: PianoPointerID = .legacyPrimary
) -> PianoHitResult {
    // ... 省略其他命中分支
    return PianoHitResult(
        pointerID: pointerID,
        phase: phase,
        locationInView: normalizedPoint,
        rowIndex: nil,
        zone: .outside,
        note: nil,
        isInsideActiveZone: false
    )
}

private func makeHitResult(
    phase: PianoEventPhase,
    location: CGPoint,
    pointerID: PianoPointerID,
    rowIndex: Int,
    zone: PianoZone,
    note: NotePitch?
) -> PianoHitResult {
    let provisionalHit = PianoHitResult(
        pointerID: pointerID,
        phase: phase,
        locationInView: location,
        rowIndex: rowIndex,
        zone: zone,
        note: note,
        isInsideActiveZone: false
    )

    return PianoHitResult(
        pointerID: provisionalHit.pointerID,
        phase: provisionalHit.phase,
        locationInView: provisionalHit.locationInView,
        rowIndex: provisionalHit.rowIndex,
        zone: provisionalHit.zone,
        note: provisionalHit.note,
        isInsideActiveZone: isInsideActiveZone(for: provisionalHit)
    )
}

private func isInsideActiveZone(
    for hit: PianoHitResult
) -> Bool {
    guard let activeInteraction = state.interaction(for: hit.pointerID) else {
        return hit.zone != .outside
    }

    switch activeInteraction {
    case let .buttonPressed(interaction):
        return hit.rowIndex == interaction.rowIndex
            && hit.buttonDirection == interaction.direction
    case let .scaleDrag(interaction):
        return hit.rowIndex == interaction.rowIndex
            && hit.zone == .scale
    case let .keyGlissando(interaction):
        return hit.rowIndex == interaction.rowIndex
            && hit.zone == .keys
            && hit.note != nil
    }
}
```

---

## 5. 平台键盘视图把 pointerID 透传给 geometry

### 5.1 `iOSPianoKeyboardView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: handleRawEvent(_:)
// 功能说明: 修改前 iOS 宿主虽然已经把 pointerID 放进 rawEvent，但调用 geometry.hitTest 时仍然只传 point + phase，pointer 语义会在命中层断掉。
let hitResult = geometry.hitTest(
    rawEvent.locationInView,
    phase: rawEvent.phase
)
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: handleRawEvent(_:)
// 功能说明: 修改后 iOS 宿主把 rawEvent.pointerID 继续传给 geometry，让 shared hit test / active zone 逻辑能真正按 pointer 会话工作。
let hitResult = geometry.hitTest(
    rawEvent.locationInView,
    phase: rawEvent.phase,
    pointerID: rawEvent.pointerID
)
```

### 5.2 `macOSPianoKeyboardView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: handleRawEvent(_:)
// 功能说明: 修改前 macOS 宿主和 iOS 一样，在 geometry 边界把 pointer 语义丢掉，导致 active zone 无法区分“当前命中来自哪个 pointer 会话”。
let hitResult = geometry.hitTest(
    rawEvent.locationInView,
    phase: rawEvent.phase
)
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: handleRawEvent(_:)
// 功能说明: 修改后 macOS 宿主也统一把 pointerID 透传下去，为后续 phase4 的真实多 pointer 输入源接线保留一致的命中契约。
let hitResult = geometry.hitTest(
    rawEvent.locationInView,
    phase: rawEvent.phase,
    pointerID: rawEvent.pointerID
)
```

---

## 6. 新增 phase2 自动化夹具入口：`PianoValidation.swift`

### 6.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures()
// 功能说明: 修改前 validation 只覆盖单 pointer keyGlissando 生命周期与既有按钮/scale 语义，还没有专门锁定“多 key pointer 并发”“control 与 key 互斥”这些 phase2 新边界。
PianoValidationFixture(
    name: "scale_drag_exit_does_not_switch_into_key_preview",
    validate: validateScaleDragExitDoesNotStartPreview
),
PianoValidationFixture(
    name: "key_glissando_emits_preview_lifecycle",
    validate: validateKeyGlissandoLifecycle
),
PianoValidationFixture(
    name: "keyboard_layer_uses_one_row_layer_per_row",
    validate: validateKeyboardLayerUsesOneRowLayerPerRow
)
```

### 6.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures()
// 功能说明: 修改后把 phase2 新行为直接接进 validation runner：一组验证多 key pointer 并发与独立结束，另一组验证控制区交互继续保持单 owner。
PianoValidationFixture(
    name: "scale_drag_exit_does_not_switch_into_key_preview",
    validate: validateScaleDragExitDoesNotStartPreview
),
PianoValidationFixture(
    name: "key_glissando_emits_preview_lifecycle",
    validate: validateKeyGlissandoLifecycle
),
PianoValidationFixture(
    name: "multi_pointer_key_previews_coexist_and_end_independently",
    validate: validateMultiPointerKeyPreviews
),
PianoValidationFixture(
    name: "control_interactions_remain_exclusive_against_key_previews",
    validate: validateControlInteractionExclusivity
),
PianoValidationFixture(
    name: "keyboard_layer_uses_one_row_layer_per_row",
    validate: validateKeyboardLayerUsesOneRowLayerPerRow
)
```

---

## 7. 新增 reducer 级别多 pointer 行为夹具：`PianoValidationReducerAndPresentation.swift`

### 7.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationReducerAndPresentation.swift
// 函数名: validateKeyGlissandoLifecycle()
// 功能说明: 修改前 reducer validation 只验证单条 keyGlissando 生命周期，无法证明两个 key pointer 会并发保留，也无法证明 control 交互会继续保持独占。
static func validateKeyGlissandoLifecycle() -> [PianoValidationIssue] {
    let fixtureName = "key_glissando_emits_preview_lifecycle"
    // ... 单 pointer 的 began / moved / ended 校验
}
```

### 7.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationReducerAndPresentation.swift
// 函数名: validateMultiPointerKeyPreviews() / validateControlInteractionExclusivity()
// 功能说明: 修改后新增两组 phase2 夹具：第一组锁定“两个 key pointer 可并发且独立结束”；第二组锁定“button/scale 仍是单 owner，不与 keys 交叉混用”。
static func validateMultiPointerKeyPreviews() -> [PianoValidationIssue] {
    let fixtureName = "multi_pointer_key_previews_coexist_and_end_independently"
    let pointerA = PianoPointerID(rawValue: 1)
    let pointerB = PianoPointerID(rawValue: 2)
    // pointerA began -> previewStarted(A)
    // pointerB began -> previewStarted(B)
    // ended(A) 之后，B 的 preview / interaction 仍然保留
    // ... 省略其余断言
}

static func validateControlInteractionExclusivity() -> [PianoValidationIssue] {
    let fixtureName = "control_interactions_remain_exclusive_against_key_previews"
    let keyPointer = PianoPointerID(rawValue: 11)
    let controlPointer = PianoPointerID(rawValue: 22)
    // key 活动时 button began 被阻断
    // key 结束后 button began 恢复建立
    // button 活动时新的 key began 再次被阻断
    // ... 省略其余断言
}
```

---

## 8. 把 active zone 夹具升级为 pointer-aware：`PianoValidationInteractionAndGeometry.swift`

### 8.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationInteractionAndGeometry.swift
// 函数名: validateActiveZoneTracking()
// 功能说明: 修改前该夹具仍按单个全局 activeInteraction 组装状态，也只验证同一个拖动会话在 scale / keys 区之间的 insideActiveZone 变化，尚未覆盖“别的 pointer 不应继承当前锁区”的约束。
let scaleDrag = PianoScaleDragInteraction(
    rowIndex: 0,
    movementScope: .rowOnly,
    beganLocationInView: CGPoint(x: 60, y: 10),
    affectedRowIndices: [0],
    initialOffsetsX: [0]
)
let state = PianoComponentState(
    rows: [
        PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
    ],
    activeInteraction: .scaleDrag(scaleDrag)
)

let scaleHit = geometry.hitTest(
    CGPoint(x: rowScene.scaleRect.midX, y: rowScene.scaleRect.midY),
    phase: .moved
)

let keyHit = geometry.hitTest(
    CGPoint(x: rowScene.keysRect.midX, y: rowScene.keysRect.midY),
    phase: .moved
)
```

### 8.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationInteractionAndGeometry.swift
// 函数名: validateActiveZoneTracking()
// 功能说明: 修改后该夹具显式构造 lockedPointer / freePointer，两次命中都带 pointerID；除了验证原 pointer 的锁区语义，也新增“其他 pointer 不应继承已锁定 pointer 的 scale active zone”断言。
let lockedPointer = PianoPointerID(rawValue: 31)
let freePointer = PianoPointerID(rawValue: 32)
let scaleDrag = PianoScaleDragInteraction(
    pointerID: lockedPointer,
    rowIndex: 0,
    movementScope: .rowOnly,
    beganLocationInView: CGPoint(x: 60, y: 10),
    affectedRowIndices: [0],
    initialOffsetsX: [0]
)
let state = PianoComponentState(
    rows: [
        PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
    ],
    activePreviews: [:],
    activeInteractionsByPointer: [
        lockedPointer: .scaleDrag(scaleDrag)
    ]
)

let scaleHit = geometry.hitTest(
    CGPoint(x: rowScene.scaleRect.midX, y: rowScene.scaleRect.midY),
    phase: .moved,
    pointerID: lockedPointer
)

let keyHit = geometry.hitTest(
    CGPoint(x: rowScene.keysRect.midX, y: rowScene.keysRect.midY),
    phase: .moved,
    pointerID: lockedPointer
)

let otherPointerKeyHit = geometry.hitTest(
    CGPoint(x: rowScene.keysRect.midX, y: rowScene.keysRect.midY),
    phase: .moved,
    pointerID: freePointer
)
```

---

## 9. 本轮 phase2 的实际落点

这轮改动完成后，共享状态机的边界变成了：

- `keys` 预览会话已经升级为按 `pointerID -> previewID` 跟踪
- 第二个 key pointer 的 `began` 不会再被第一个活动 key 会话全局屏蔽
- `previewEnded` 只会清理当前 pointer 自己的 preview / interaction，不会误伤其他活动 key pointer
- `buttonPressed` / `scaleDrag` 继续保持单 owner 控制语义，不和 keys 并发混用
- `isInsideActiveZone` 已切换成按 pointer 查询，geometry 层不再借用别的 pointer 的锁区状态
- 平台宿主虽然还没有在 phase2 实施真实多 pointer 输入源，但命中层的 pointer 契约已经接通，phase4 只需要补输入采集与指针映射

也就是说，phase2 解决的是 **共享 reducer / state 的 pointer-centric 并行语义**，而不是 **平台层真实多触点输入** 或 **播放层复音后端**。

---

## 10. 验证结果

- `ReadLints` 检查本轮改动文件：无新增诊断
- macOS Debug 构建通过：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath "/tmp/NoteMaster_Phase2_macOS" build`
- iOS Simulator Debug 构建通过：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "/tmp/NoteMaster_Phase2_iOS" build`

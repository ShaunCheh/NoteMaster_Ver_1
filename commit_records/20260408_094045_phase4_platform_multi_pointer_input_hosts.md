# 20260408_094045_phase4_platform_multi_pointer_input_hosts

## 记录范围

本记录只覆盖刚刚这一轮“多指复音计划 phase4：改造 iOS / macOS 输入宿主，产出稳定的多 pointer raw event 序列”的实际代码修改。

这次修改的目标不是把播放后端直接升级成复音 mixer，也不是再去调整 phase3 的渲染投影层；这一步只处理平台输入宿主与其配套清理语义：

- 引入共享的 pointer session tracker，统一分配 / 复用 / 结束 `PianoPointerID`
- 把 iOS 的 `activeTouch` 单槽位升级成 `UITouch -> pointer session` 映射
- 把 macOS 的 `isMouseSequenceActive` 单序列门闸升级成可同时表示 mouse / touch source 的 pointer 输入层
- 把 rows 替换、mode / settings 切换、view disappear 时的清理从单值兼容口改成全量 `activePreviews` / `activeInteractionsByPointer` 收口
- 增补 focused validation，把 pointer session 和全量清理边界固定下来

本记录参考了当前工作区的 `git diff`、`git status` 与文件现状，但 **不包含原始 diff**。

当前工作区里，与本轮 phase4 直接相关的代码文件有 6 个：

- `NoteMaster_Ver_1/Shared/Piano/PianoPointerSessionTracker.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationPlatformInput.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`

当前工作区另外还存在 `@.cursor/plans/多指复音计划_27c48b8b.plan.md` 的变更，但它不是本轮 phase4 代码实现的一部分，因此本记录不把它计入“修改前 / 修改后”范围。

---

## 1. 新增共享 pointer session tracker：`PianoPointerSessionTracker.swift`

### 1.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPointerSessionTracker.swift
// 函数名: （文件不存在）
// 功能说明: 修改前共享层没有统一的 pointer session tracker，iOS 与 macOS 宿主各自只能在本地维护单 touch / 单 mouse 状态，无法共享“分配 pointerID、复用 pointerID、prune 泄漏 session”的规则。
// 修改前该文件不存在。
```

### 1.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPointerSessionTracker.swift
// 函数名: begin(source:locationInView:) / move(source:locationInView:) / end(source:locationInView:) / cancel(source:locationInView:) / retainSessions(withPointerIDs:)
// 功能说明: 修改后新增共享 tracker，把平台原始输入 source 映射为稳定的 PianoPointerID，并统一处理 location 记忆、ended/cancelled 后移除、以及宿主 prune 时按 pointerID 保留有效 session。
struct PianoPointerSession {
    var pointerID: PianoPointerID
    var lastLocationInView: CGPoint
}

struct PianoPointerSessionTracker<Source: Hashable> {
    private(set) var sessionsBySource: [Source: PianoPointerSession] = [:]
    private var nextPointerRawValue: UInt64 = PianoPointerID.legacyPrimary.rawValue + 1

    mutating func begin(
        source: Source,
        locationInView: CGPoint
    ) -> PianoRawEvent? {
        guard sessionsBySource[source] == nil else {
            return nil
        }

        let pointerID = allocatePointerID()
        sessionsBySource[source] = PianoPointerSession(
            pointerID: pointerID,
            lastLocationInView: locationInView
        )
        return PianoRawEvent(
            pointerID: pointerID,
            phase: .began,
            locationInView: locationInView
        )
    }

    mutating func retainSessions(
        withPointerIDs pointerIDs: Set<PianoPointerID>
    ) {
        sessionsBySource = sessionsBySource.filter { entry in
            pointerIDs.contains(entry.value.pointerID)
        }
    }
}
```

---

## 2. 共享状态补上“全量 sanitize / 全量清空”入口：`PianoState.swift`

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名: isPreviewing / previewedNotes(forRowIndex:) / setInteraction(_:for:)
// 功能说明: 修改前共享状态虽然已经进入 map 结构，但宿主在 rows 替换和中断时仍主要依赖 preview / activeInteraction 单值兼容口，没有统一的“按所有 pointer sanitize / 清空”的入口。
var isPreviewing: Bool {
    !activePreviews.isEmpty
}

func previewedNotes(forRowIndex rowIndex: Int) -> Set<NotePitch> {
    Set(previews(forRowIndex: rowIndex).map(\.note))
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
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名: orderedActivePreviews / replacingRowsBySanitizingInputSessions(with:) / clearInputSessions()
// 功能说明: 修改后共享状态显式提供“有序活动 preview 列表”“按所有 pointer sanitize rows 替换”“一次性清空全部输入会话”三个入口，宿主不再只能压回单值 preview / interaction。
var orderedActivePreviews: [PianoPreviewState] {
    activePreviews.values.sorted { lhs, rhs in
        lhs.previewID.rawValue < rhs.previewID.rawValue
    }
}

func replacingRowsBySanitizingInputSessions(
    with rows: [PianoRowState]
) -> PianoComponentState {
    var nextState = self
    nextState.rows = rows

    let interactionOwnedPreviewIDs = Set(
        activeInteractionsByPointer.values.compactMap { $0.currentPreview?.previewID }
    )
    let sanitizedInteractions = activeInteractionsByPointer.compactMapValues {
        sanitizedInteraction($0, rowCount: rows.count)
    }
    let validInteractionPreviewIDs = Set(
        sanitizedInteractions.values.compactMap { $0.currentPreview?.previewID }
    )
    var sanitizedPreviews = activePreviews.filter { entry in
        (0..<rows.count).contains(entry.value.rowIndex)
            && (
                !interactionOwnedPreviewIDs.contains(entry.key)
                    || validInteractionPreviewIDs.contains(entry.key)
            )
    }

    for interaction in sanitizedInteractions.values {
        guard let preview = interaction.currentPreview else {
            continue
        }
        sanitizedPreviews[preview.previewID] = preview
    }

    nextState.activePreviews = sanitizedPreviews
    nextState.activeInteractionsByPointer = sanitizedInteractions
    return nextState
}

mutating func clearInputSessions() -> [PianoPreviewState] {
    let interruptedPreviews = orderedActivePreviews
    activePreviews.removeAll()
    activeInteractionsByPointer.removeAll()
    return interruptedPreviews
}
```

---

## 3. iOS 宿主从单 `activeTouch` 切到多 pointer：`iOSPianoKeyboardView.swift`

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: configureView() / handleRawTouchEvent(from:phase:) / resolvedTrackedTouch(from:phase:) / resetActiveInteraction(emitsPreviewEnded:)
// 功能说明: 修改前 iOS 宿主显式关闭多点触控，只跟踪一个 activeTouch；ended/cancelled 也只会给这一条 touch 补发单个 raw event，reset 时同样只清单值 preview / activeInteraction。
private var activeTouch: UITouch?
private var lastTrackedLocationInView: CGPoint?

func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    isMultipleTouchEnabled = false
    // ...
}

func handleRawTouchEvent(
    from touches: Set<UITouch>,
    phase: PianoEventPhase
) {
    guard let touch = resolvedTrackedTouch(
        from: touches,
        phase: phase
    ) else {
        if phase == .ended || phase == .cancelled {
            if let lastTrackedLocationInView {
                handleRawEvent(
                    PianoRawEvent(
                        phase: phase,
                        locationInView: lastTrackedLocationInView
                    )
                )
            }
            activeTouch = nil
            lastTrackedLocationInView = nil
        }
        return
    }

    let locationInView = touch.location(in: self)
    lastTrackedLocationInView = locationInView
    handleRawEvent(
        PianoRawEvent(
            phase: phase,
            locationInView: locationInView
        )
    )
}

func resolvedTrackedTouch(
    from touches: Set<UITouch>,
    phase: PianoEventPhase
) -> UITouch? {
    switch phase {
    case .began:
        guard activeTouch == nil, let touch = touches.first else {
            return nil
        }
        activeTouch = touch
        return touch
    case .moved, .ended, .cancelled:
        guard let activeTouch else {
            return nil
        }
        return touches.first(where: { $0 === activeTouch })
    }
}

func resetActiveInteraction(
    emitsPreviewEnded: Bool
) {
    let interruptedPreview = componentState.preview
    let hadActiveInteraction = componentState.activeInteraction != nil
    guard interruptedPreview != nil || hadActiveInteraction else {
        return
    }

    componentState.preview = nil
    componentState.activeInteraction = nil
    activeTouch = nil
    lastTrackedLocationInView = nil
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: configureView() / replaceRows(_:) / handleRawTouchEvent(from:phase:) / rawEvent(for:phase:) / resetActiveInteraction(emitsPreviewEnded:)
// 功能说明: 修改后 iOS 宿主开启多点触控，并通过 shared tracker 把每一根 UITouch 映射成独立 pointer session；rows 替换和 reset 也都会按全部活动 preview / interaction 收口，而不是只处理单值兼容口。
private var touchSessionTracker = PianoPointerSessionTracker<ObjectIdentifier>()

func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    isMultipleTouchEnabled = true
    // ...
}

func replaceRows(_ newRows: [PianoRowState]) {
    let previousPreviews = componentState.orderedActivePreviews
    componentState = componentState.replacingRowsBySanitizingInputSessions(
        with: newRows
    )
    touchSessionTracker.retainSessions(
        withPointerIDs: Set(componentState.activeInteractionsByPointer.keys)
    )

    applyBackingState()
    emitPreviewEndedEvents(
        removedFrom: previousPreviews,
        nextState: componentState
    )
}

func handleRawTouchEvent(
    from touches: Set<UITouch>,
    phase: PianoEventPhase
) {
    for touch in orderedTouches(from: touches) {
        guard let rawEvent = rawEvent(for: touch, phase: phase) else {
            continue
        }
        handleRawEvent(rawEvent)
    }
}

func rawEvent(
    for touch: UITouch,
    phase: PianoEventPhase
) -> PianoRawEvent? {
    let source = ObjectIdentifier(touch)
    let locationInView = touch.location(in: self)

    switch phase {
    case .began:
        return touchSessionTracker.begin(
            source: source,
            locationInView: locationInView
        )
    case .moved:
        return touchSessionTracker.move(
            source: source,
            locationInView: locationInView
        )
    case .ended:
        return touchSessionTracker.end(
            source: source,
            locationInView: locationInView
        )
    case .cancelled:
        return touchSessionTracker.cancel(
            source: source,
            locationInView: locationInView
        )
    }
}

func resetActiveInteraction(
    emitsPreviewEnded: Bool
) {
    let interruptedPreviews = componentState.orderedActivePreviews
    let hadActiveInteraction = !componentState.activeInteractionsByPointer.isEmpty
    let hadTrackedTouches = touchSessionTracker.hasActiveSessions
    guard !interruptedPreviews.isEmpty || hadActiveInteraction || hadTrackedTouches else {
        return
    }

    _ = componentState.clearInputSessions()
    touchSessionTracker.removeAllSessions()
    applyBackingState()

    if emitsPreviewEnded {
        emitSemanticEvents(
            interruptedPreviews.map(PianoSemanticEvent.previewEnded)
        )
    }
}
```

---

## 4. macOS 宿主从单 mouse sequence 切到统一 pointer source：`macOSPianoKeyboardView.swift`

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: mouseDown(with:) / mouseDragged(with:) / mouseUp(with:) / handleRawMouseEvent(_:phase:) / resetActiveInteraction(emitsPreviewEnded:)
// 功能说明: 修改前 macOS 宿主只依赖一个 isMouseSequenceActive 门闸来表示“当前是否有输入序列”，并且只从 mouse 事件产生单路 raw event；reset 时也仍走单值 preview / activeInteraction 清理。
private var isMouseSequenceActive = false

override func mouseDown(with event: NSEvent) {
    isMouseSequenceActive = true
    handleRawMouseEvent(event, phase: .began)
}

override func mouseDragged(with event: NSEvent) {
    guard isMouseSequenceActive else {
        return
    }

    handleRawMouseEvent(event, phase: .moved)
}

override func mouseUp(with event: NSEvent) {
    guard isMouseSequenceActive else {
        return
    }

    handleRawMouseEvent(event, phase: .ended)
    isMouseSequenceActive = false
}

func handleRawMouseEvent(
    _ event: NSEvent,
    phase: PianoEventPhase
) {
    let location = convert(event.locationInWindow, from: nil)
    let normalizedLocation = resolvedContextNormalizationMode.normalizedPoint(
        location,
        in: bounds
    )
    handleRawEvent(
        PianoRawEvent(
            phase: phase,
            locationInView: normalizedLocation
        )
    )
}

func resetActiveInteraction(
    emitsPreviewEnded: Bool
) {
    let interruptedPreview = componentState.preview
    let hadActiveInteraction = componentState.activeInteraction != nil
    guard interruptedPreview != nil || hadActiveInteraction else {
        return
    }

    componentState.preview = nil
    componentState.activeInteraction = nil
    isMouseSequenceActive = false
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: mouseDown/Dragged/Up / touchesBegan/Moved/Ended/Cancelled / rawEvent(forMouseEvent:phase:) / rawEvent(forTouch:phase:) / resetActiveInteraction(emitsPreviewEnded:)
// 功能说明: 修改后 macOS 宿主引入显式 pointer source 抽象，同时支持 mouse 和 AppKit touch；所有平台输入都会先映射成 pointer session，再统一送入 shared reducer。
private enum macOSPianoPointerSource: Hashable {
    case mouse(buttonNumber: Int)
    case touch(ObjectIdentifier)
}

private var pointerSessionTracker = PianoPointerSessionTracker<macOSPianoPointerSource>()

override func mouseDown(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .began)
}

override func rightMouseDown(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .began)
}

override func otherMouseDown(with event: NSEvent) {
    handleRawMouseEvent(event, phase: .began)
}

override func touchesBegan(with event: NSEvent) {
    handleRawTouchEvent(event, phase: .began)
    super.touchesBegan(with: event)
}

func configureView() {
    wantsLayer = true
    acceptsTouchEvents = true
    layerContentsRedrawPolicy = .duringViewResize
    // ...
}

func rawEvent(
    forMouseEvent event: NSEvent,
    phase: PianoEventPhase
) -> PianoRawEvent? {
    let location = convert(event.locationInWindow, from: nil)
    let normalizedLocation = resolvedContextNormalizationMode.normalizedPoint(
        location,
        in: bounds
    )
    let source = macOSPianoPointerSource.mouse(
        buttonNumber: Int(event.buttonNumber)
    )

    switch phase {
    case .began:
        return pointerSessionTracker.begin(
            source: source,
            locationInView: normalizedLocation
        )
    case .moved:
        return pointerSessionTracker.move(
            source: source,
            locationInView: normalizedLocation
        )
    case .ended:
        return pointerSessionTracker.end(
            source: source,
            locationInView: normalizedLocation
        )
    case .cancelled:
        return pointerSessionTracker.cancel(
            source: source,
            locationInView: normalizedLocation
        )
    }
}

func rawEvent(
    forTouch touch: NSTouch,
    phase: PianoEventPhase
) -> PianoRawEvent? {
    let source = macOSPianoPointerSource.touch(
        ObjectIdentifier(touchIdentityObject(for: touch))
    )
    let normalizedPosition = touch.normalizedPosition
    let location = CGPoint(
        x: bounds.minX + (bounds.width * min(max(normalizedPosition.x, 0), 1)),
        y: bounds.minY + (bounds.height * min(max(normalizedPosition.y, 0), 1))
    )
    let normalizedLocation = resolvedContextNormalizationMode.normalizedPoint(
        location,
        in: bounds
    )

    switch phase {
    case .began:
        return pointerSessionTracker.begin(
            source: source,
            locationInView: normalizedLocation
        )
    case .moved:
        return pointerSessionTracker.move(
            source: source,
            locationInView: normalizedLocation
        )
    case .ended:
        return pointerSessionTracker.end(
            source: source,
            locationInView: normalizedLocation
        )
    case .cancelled:
        return pointerSessionTracker.cancel(
            source: source,
            locationInView: normalizedLocation
        )
    }
}

func resetActiveInteraction(
    emitsPreviewEnded: Bool
) {
    let interruptedPreviews = componentState.orderedActivePreviews
    let hadActiveInteraction = !componentState.activeInteractionsByPointer.isEmpty
    let hadTrackedPointers = pointerSessionTracker.hasActiveSessions
    guard !interruptedPreviews.isEmpty || hadActiveInteraction || hadTrackedPointers else {
        return
    }

    _ = componentState.clearInputSessions()
    pointerSessionTracker.removeAllSessions()
    applyBackingState()
}
```

---

## 5. 把 focused validation 接进总入口：`PianoValidationPlatformInput.swift` 与 `PianoValidation.swift`

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationPlatformInput.swift
// 函数名: （文件不存在）
// 功能说明: 修改前没有专门锁定 pointer session 分配 / prune / reset 行为的 focused validation，phase4 的平台输入边界只能靠人工验证。
// 修改前该文件不存在。
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改前总验证入口还没有 phase4 的 pointer session 夹具，也没有把双平台多 pointer 输入和全量清理加入手工清单。
PianoValidationFixture(
    name: "control_interactions_remain_exclusive_against_key_previews",
    validate: validateControlInteractionExclusivity
),
PianoValidationFixture(
    name: "keyboard_layer_uses_one_row_layer_per_row",
    validate: validateKeyboardLayerUsesOneRowLayerPerRow
)

"确认同一行两个音、跨行两个音可同时高亮；快速交替两音时不会只剩一个稳定高亮。",
"确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationPlatformInput.swift
// 函数名: validatePointerSessionTrackerKeepsIDsStableAndMonotonic() / validateRowReplacementAndResetClearAllPointerSessions()
// 功能说明: 修改后新增两条 phase4 focused validation：第一条锁定 pointerID 分配稳定且单调递增；第二条锁定 rows 替换与 reset 时会按全部 preview / interaction 清理，而不是只返回兼容单值 preview。
static func validatePointerSessionTrackerKeepsIDsStableAndMonotonic() -> [PianoValidationIssue] {
    enum TestSource: Hashable {
        case primary
        case secondary
        case tertiary
    }

    var tracker = PianoPointerSessionTracker<TestSource>()
    guard let beganPrimary = tracker.begin(
        source: .primary,
        locationInView: CGPoint(x: 12, y: 18)
    ) else {
        return [issue(fixtureName, "primary began 应建立 pointer session。")]
    }
    guard let beganSecondary = tracker.begin(
        source: .secondary,
        locationInView: CGPoint(x: 40, y: 22)
    ) else {
        return [issue(fixtureName, "secondary began 应建立第二个独立 pointer session。")]
    }

    if tracker.activePointerIDs != Set([beganPrimary.pointerID, beganSecondary.pointerID]) {
        issues.append(issue(fixtureName, "tracker 应同时保留两个活动 pointer。"))
    }
    tracker.retainSessions(withPointerIDs: [beganPrimary.pointerID])
    if tracker.end(source: .secondary) != nil {
        issues.append(issue(fixtureName, "已被 prune 的 secondary source 不应再产生 ended raw event。"))
    }
    // ... 这里省略了后续对单调递增 pointerID 的断言 ...
}

static func validateRowReplacementAndResetClearAllPointerSessions() -> [PianoValidationIssue] {
    let sanitizedState = state.replacingRowsBySanitizingInputSessions(
        with: [
            PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4))
        ]
    )
    var clearedState = sanitizedState
    let clearedPreviews = clearedState.clearInputSessions()
    if clearedPreviews != [previewA, detachedPreview] {
        issues.append(issue(fixtureName, "clearInputSessions 应返回所有活动 preview，而不是只返回兼容单值 preview。"))
    }
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后 phase4 的两条 focused validation 被接入总入口，同时手工清单明确要求验证 iOS 双指并发与 macOS mouse / touch 中断时不会残留 pointer。
PianoValidationFixture(
    name: "control_interactions_remain_exclusive_against_key_previews",
    validate: validateControlInteractionExclusivity
),
PianoValidationFixture(
    name: "pointer_session_tracker_keeps_ids_stable_and_monotonic",
    validate: validatePointerSessionTrackerKeepsIDsStableAndMonotonic
),
PianoValidationFixture(
    name: "row_replacement_and_reset_clear_all_pointer_sessions",
    validate: validateRowReplacementAndResetClearAllPointerSessions
),
PianoValidationFixture(
    name: "keyboard_layer_uses_one_row_layer_per_row",
    validate: validateKeyboardLayerUsesOneRowLayerPerRow
)

"确认同一行两个音、跨行两个音可同时高亮；快速交替两音时不会只剩一个稳定高亮。",
"确认 iOS 上两根手指可并发触发两路 pointer，抬起其中一根时另一根不会被误 ended。",
"确认 macOS 上 mouse / touch pointer 中断、切换 mode、切 settings 或 view disappear 时，不会残留未清理 pointer 或重复 ended。",
"确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
```

---

## 6. 验证结果

- 对 `PianoPointerSessionTracker.swift`、`PianoState.swift`、`PianoValidationPlatformInput.swift`、`PianoValidation.swift`、`iOSPianoKeyboardView.swift`、`macOSPianoKeyboardView.swift` 执行了诊断检查，未发现新增 linter 问题。
- 已顺序执行 iOS 与 macOS 构建回归，均通过：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' build`
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=macOS' build`

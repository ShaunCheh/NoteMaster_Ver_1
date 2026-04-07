# 20260407_215420_phase1_pointer_preview_voice_identity_contracts

## 记录范围

本记录只覆盖刚刚这一轮“多指复音计划 phase1：冻结 pointer / preview / voice 共享身份契约”的实际代码修改。

这次修改的目标不是立即把钢琴输入、渲染、播放全量升级成多指复音，而是先把共享层里“谁在按、谁在预览、谁在发声”的身份模型统一下来，并保留当前单触点 / 单声部运行时行为，给后续 phase2 ~ phase5 提供稳定边界。

本记录参考了当前工作区的 `git diff` 与文件现状，但 **不包含原始 diff**。

当前工作区里，与本轮 phase1 直接相关的代码文件有 4 个：

- `NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift`

当前工作区另外还存在 `@.cursor/plans/多指复音计划_27c48b8b.plan.md` 的变更，但它不是本轮 phase1 代码实现的一部分，因此本记录不把它计入“修改前/修改后”范围。

---

## 1. 冻结共享身份模型：`PianoInteraction.swift`

### 1.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift
// 函数名: （类型定义区）
// 功能说明: 修改前共享输入层只有 phase/location 与单值 preview 语义，raw event、hit result、各类 interaction 都没有稳定 identity，后续无法把 pointer、preview、voice 一路对齐。
import Foundation
import CoreGraphics

struct PianoRawEvent: Equatable, Sendable {
    var phase: PianoEventPhase
    var locationInView: CGPoint
}

struct PianoHitResult: Equatable, Sendable {
    var phase: PianoEventPhase
    var locationInView: CGPoint
    var rowIndex: Int?
    var zone: PianoZone
    var note: NotePitch?
    var isInsideActiveZone: Bool
}

struct PianoButtonPressInteraction: Equatable, Sendable {
    var rowIndex: Int
    var direction: PianoStepDirection
    var movementScope: PianoMovementScope
    var isTrackingInsideButton: Bool
}

struct PianoScaleDragInteraction: Equatable, Sendable {
    var rowIndex: Int
    var movementScope: PianoMovementScope
    var beganLocationInView: CGPoint
    var affectedRowIndices: [Int]
    var initialOffsetsX: [CGFloat]
}

struct PianoKeyGlissandoInteraction: Equatable, Sendable {
    var rowIndex: Int
    var currentPreview: PianoPreviewState
}
```

### 1.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift
// 函数名: （类型定义区）
// 功能说明: 修改后新增 PointerId / PreviewId / VoiceId，并让 raw event、hit result、interaction 全部携带身份；这样后续 phase 才能在 reducer、render、playback 三层使用同一套 identity。
import Foundation
import CoreGraphics

struct PianoPointerID: RawRepresentable, Equatable, Hashable, Sendable {
    static let legacyPrimary = PianoPointerID(rawValue: 0)

    let rawValue: UInt64

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    var debugName: String {
        "pointer-\(rawValue)"
    }

    var previewID: PianoPreviewID {
        PianoPreviewID(rawValue: rawValue)
    }

    var voiceID: PianoVoiceID {
        previewID
    }
}

struct PianoPreviewID: RawRepresentable, Equatable, Hashable, Sendable {
    static let legacyPrimary = PianoPreviewID(rawValue: 0)

    let rawValue: UInt64

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

typealias PianoVoiceID = PianoPreviewID

struct PianoRawEvent: Equatable, Sendable {
    var pointerID: PianoPointerID
    var phase: PianoEventPhase
    var locationInView: CGPoint
}

struct PianoHitResult: Equatable, Sendable {
    var pointerID: PianoPointerID
    var phase: PianoEventPhase
    var locationInView: CGPoint
    var rowIndex: Int?
    var zone: PianoZone
    var note: NotePitch?
    var isInsideActiveZone: Bool
}

struct PianoButtonPressInteraction: Equatable, Sendable {
    var pointerID: PianoPointerID
    var rowIndex: Int
    var direction: PianoStepDirection
    var movementScope: PianoMovementScope
    var isTrackingInsideButton: Bool
}

struct PianoScaleDragInteraction: Equatable, Sendable {
    var pointerID: PianoPointerID
    var rowIndex: Int
    var movementScope: PianoMovementScope
    var beganLocationInView: CGPoint
    var affectedRowIndices: [Int]
    var initialOffsetsX: [CGFloat]
}

struct PianoKeyGlissandoInteraction: Equatable, Sendable {
    var pointerID: PianoPointerID
    var rowIndex: Int
    var currentPreview: PianoPreviewState
}

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
}
```

---

## 2. 从单值槽位升级到底层 map：`PianoState.swift`

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名: PianoPreviewState / PianoComponentState
// 功能说明: 修改前 preview 只有 rowIndex + note，组件状态只有一个 preview 和一个 activeInteraction；这会把“正在活动的输入源”强行压扁成全局唯一槽位。
struct PianoPreviewState: Equatable, Sendable {
    var rowIndex: Int
    var note: NotePitch
}

struct PianoComponentState: Equatable, Sendable {
    static let empty = PianoComponentState(rows: [])

    var rows: [PianoRowState]
    var preview: PianoPreviewState?
    var activeInteraction: PianoInteractionState?

    init(
        rows: [PianoRowState],
        preview: PianoPreviewState? = nil,
        activeInteraction: PianoInteractionState? = nil
    ) {
        self.rows = rows
        self.preview = preview
        self.activeInteraction = activeInteraction
    }

    var isPreviewing: Bool {
        preview != nil
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名: PianoPreviewState / PianoComponentState
// 功能说明: 修改后底层状态改为 activePreviews 与 activeInteractionsByPointer 两张表；同时保留 preview / activeInteraction 兼容访问口，让旧调用方还能先按单值语义工作。
struct PianoPreviewState: Equatable, Sendable {
    var previewID: PianoPreviewID
    var rowIndex: Int
    var note: NotePitch

    init(
        previewID: PianoPreviewID = .legacyPrimary,
        rowIndex: Int,
        note: NotePitch
    ) {
        self.previewID = previewID
        self.rowIndex = rowIndex
        self.note = note
    }

    var voiceID: PianoVoiceID {
        previewID
    }
}

struct PianoComponentState: Equatable, Sendable {
    static let empty = PianoComponentState(rows: [])

    var rows: [PianoRowState]
    var activePreviews: [PianoPreviewID: PianoPreviewState]
    var activeInteractionsByPointer: [PianoPointerID: PianoInteractionState]

    init(
        rows: [PianoRowState],
        preview: PianoPreviewState? = nil,
        activeInteraction: PianoInteractionState? = nil
    ) {
        self.rows = rows
        activePreviews = [:]
        activeInteractionsByPointer = [:]
        self.preview = preview
        self.activeInteraction = activeInteraction
    }

    var preview: PianoPreviewState? {
        get {
            if let preview = activePreviews[.legacyPrimary] {
                return preview
            }

            return activePreviews.values.min { lhs, rhs in
                lhs.previewID.rawValue < rhs.previewID.rawValue
            }
        }
        set {
            guard let newValue else {
                activePreviews.removeAll()
                return
            }

            // 兼容旧调用方：当前阶段仍允许把单个 preview 写回一个槽位。
            activePreviews = [newValue.previewID: newValue]
        }
    }

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

            // 兼容旧调用方：当前阶段仍让旧逻辑通过单值入口工作。
            activeInteractionsByPointer = [newValue.pointerID: newValue]
        }
    }

    var isPreviewing: Bool {
        !activePreviews.isEmpty
    }
}
```

---

## 3. 把 identity 真正写入 reducer 产物：`PianoInteractionReducer.swift`

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: synchronizedHitResult(...) / reduceWithoutActiveInteraction(...) / reduceKeyGlissando(...)
// 功能说明: 修改前 reducer 即使未来拿到多个 pointer，也会在进入状态机时丢掉 identity；previewStarted / previewChanged / previewEnded 之间没有稳定 id 关联。
static func synchronizedHitResult(
    rawEvent: PianoRawEvent,
    hitResult: PianoHitResult
) -> PianoHitResult {
    PianoHitResult(
        phase: rawEvent.phase,
        locationInView: rawEvent.locationInView,
        rowIndex: hitResult.rowIndex,
        zone: hitResult.zone,
        note: hitResult.note,
        isInsideActiveZone: hitResult.isInsideActiveZone
    )
}

let preview = PianoPreviewState(
    rowIndex: rowIndex,
    note: note
)

nextState.activeInteraction = .keyGlissando(
    PianoKeyGlissandoInteraction(
        rowIndex: rowIndex,
        currentPreview: preview
    )
)

let nextPreview = PianoPreviewState(
    rowIndex: interaction.rowIndex,
    note: note
)
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: synchronizedHitResult(...) / reduceWithoutActiveInteraction(...) / reduceButtonPress(...) / reduceKeyGlissando(...)
// 功能说明: 修改后 rawEvent 的 pointerID 会一路写入 hitResult、button/scale/keyGlissando interaction，以及 started/changed/ended 产生的 preview；这样同一条活动 preview 才能跨多个事件稳定追踪。
static func synchronizedHitResult(
    rawEvent: PianoRawEvent,
    hitResult: PianoHitResult
) -> PianoHitResult {
    PianoHitResult(
        pointerID: rawEvent.pointerID,
        phase: rawEvent.phase,
        locationInView: rawEvent.locationInView,
        rowIndex: hitResult.rowIndex,
        zone: hitResult.zone,
        note: hitResult.note,
        isInsideActiveZone: hitResult.isInsideActiveZone
    )
}

nextState.activeInteraction = .buttonPressed(
    PianoButtonPressInteraction(
        pointerID: rawEvent.pointerID,
        rowIndex: rowIndex,
        direction: direction,
        movementScope: rowState.movementScope
    )
)

let preview = PianoPreviewState(
    previewID: rawEvent.pointerID.previewID,
    rowIndex: rowIndex,
    note: note
)

nextState.activeInteraction = .keyGlissando(
    PianoKeyGlissandoInteraction(
        pointerID: rawEvent.pointerID,
        rowIndex: rowIndex,
        currentPreview: preview
    )
)

let nextPreview = PianoPreviewState(
    previewID: interaction.currentPreview.previewID,
    rowIndex: interaction.rowIndex,
    note: note
)

let finalPreview = PianoPreviewState(
    previewID: interaction.currentPreview.previewID,
    rowIndex: interaction.rowIndex,
    note: note
)
```

---

## 4. 让 playback 身份与 preview 对齐：`PlaybackCoordinator.swift`

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift
// 函数名: 成员定义 / handle(_:) / forceStop(reason:) / transitionToPreview(_:)
// 功能说明: 修改前播放层只有 currentPreview 一个槽位，previewEnded 只能按“当前是不是同一个 preview”做匹配，无法表达多活动 voice 的身份对齐关系。
protocol PlaybackAudioBackend: AnyObject {
    func startPreview(note: NotePitch)
    func replacePreview(note: NotePitch)
    func stopPreview()
}

final class PlaybackCoordinator {
    private let backend: PlaybackAudioBackend

    private(set) var currentPreview: PianoPreviewState?

    func handle(_ semanticEvent: PianoSemanticEvent) {
        switch semanticEvent {
        case let .previewEnded(preview):
            guard currentPreview == preview else {
                return
            }

            currentPreview = nil
            backend.stopPreview()
        default:
            return
        }
    }

    func forceStop(reason _: PlaybackStopReason) {
        currentPreview = nil
        backend.stopPreview()
    }
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift
// 函数名: 成员定义 / handle(_:) / forceStop(reason:) / transitionToPreview(_:)
// 功能说明: 修改后先把 voice 身份模型与 previewID 对齐，activeVoices 使用 VoiceId -> PreviewState 存储；但当前阶段仍刻意保留“单声部 backend 只播放最新 voice”的兼容行为，真正复音延后到 phase5。
typealias PlaybackVoiceID = PianoVoiceID

protocol PlaybackAudioBackend: AnyObject {
    func startPreview(note: NotePitch)
    func replacePreview(note: NotePitch)
    func stopPreview()
}

final class PlaybackCoordinator {
    private let backend: PlaybackAudioBackend

    private(set) var activeVoices: [PlaybackVoiceID: PianoPreviewState] = [:]

    var currentPreview: PianoPreviewState? {
        activeVoices.values.min { lhs, rhs in
            lhs.previewID.rawValue < rhs.previewID.rawValue
        }
    }

    func handle(_ semanticEvent: PianoSemanticEvent) {
        switch semanticEvent {
        case let .previewEnded(preview):
            guard activeVoices[preview.voiceID] == preview else {
                return
            }

            activeVoices.removeValue(forKey: preview.voiceID)
            backend.stopPreview()
        default:
            return
        }
    }

    func forceStop(reason _: PlaybackStopReason) {
        activeVoices.removeAll()
        backend.stopPreview()
    }
}

private extension PlaybackCoordinator {
    func transitionToPreview(_ preview: PianoPreviewState) {
        if let currentPreview {
            if currentPreview.note != preview.note {
                backend.replacePreview(note: preview.note)
            }

            // phase1 只冻结 identity 契约，运行时仍压回最新一个 voice。
            activeVoices = [preview.voiceID: preview]
            return
        }

        activeVoices = [preview.voiceID: preview]
        backend.startPreview(note: preview.note)
    }
}
```

---

## 5. 本轮 phase1 的实际落点

这轮改动完成后，代码层面的边界变成了：

- 输入链已经有稳定的 `PianoPointerID`
- preview 链已经有稳定的 `PianoPreviewID`
- 播放链已经明确 `PianoVoiceID` 与 preview identity 对齐
- 组件状态底层已经不再依赖“必须只有一个 preview / 一个 activeInteraction”才能表达活动会话
- 旧调用方仍可通过兼容访问口继续按单值方式工作，因此这一步没有强行把 phase2 的 pointer-centric reducer 一起提前做掉

换句话说，phase1 解决的是 **共享身份契约与状态槽位形状**，而不是 **多指并行行为本身**。真正的多 pointer 并发 reducer、multi-highlight 渲染、平台多触点输入与复音 backend，会在后续 phase 中继续展开。

---

## 6. 验证结果

- `ReadLints` 检查本轮改动文件：无新增诊断
- macOS Debug 构建通过：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath "/tmp/NoteMaster_Phase1_macOS" build`
- iOS Simulator Debug 构建通过：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "/tmp/NoteMaster_Phase1_iOS" build`

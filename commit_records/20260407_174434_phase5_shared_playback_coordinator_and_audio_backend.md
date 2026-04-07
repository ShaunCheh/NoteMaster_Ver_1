# 20260407_174434_phase5_shared_playback_coordinator_and_audio_backend

## 记录范围

本记录只覆盖刚刚这一轮 `phase5` 的实际修改，重点是把钢琴 `previewStarted / previewChanged / previewEnded` 真正接到共享播放协调器与平台音频后端，并把 mode 切换、rows 替换、view disappear、settings 改动时的强制静音链路补齐。

本记录参考了当前工作区的 `git diff` 与文件现状，但**不包含原始 diff**。  
当前工作区里仍有一个用户侧已有的 `.md` 变更：

- `.cursor/plans/play模式分阶段计划_3b30e6c6.plan.md`

这个 `.md` 不属于本轮 `phase5` 的实际代码落地，因此下面不把它算进本次记录范围。

本轮涉及文件：

- `NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift`
- `NoteMaster_Ver_1/Shared/Playback/PlaybackPitch.swift`
- `NoteMaster_Ver_1/Shared/Playback/AVFoundationTonePlaybackEngine.swift`
- `NoteMaster_Ver_1/Shared/Playback/PlaybackValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/Playback/iOSPlaybackAudioBackend.swift`
- `NoteMaster_Ver_1/Platform/macOS/Playback/macOSPlaybackAudioBackend.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`

---

## 1. 新增共享播放协调器与基础音高映射

### 1.1 `PlaybackCoordinator.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；previewStarted / previewChanged / previewEnded 只有 UI 语义事件，没有共享 PlaybackCoordinator 来统一解释“起音 / 切音 / 停音 / 强制静音”。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift
// 函数名: handle(_:) / forceStop(reason:) / transitionToPreview(_:)
// 功能说明: 修改后新增共享 PlaybackCoordinator；它只消费钢琴语义事件，并把它们统一翻译为 backend 的 start / replace / stop，同时提供 forceStop 收口 mode 切换、settings 改动、view disappear 等中断场景。
enum PlaybackStopReason: String, Sendable {
    case rootModeChanged
    case panelStateChanged
    case sharedSettingsChanged
    case viewWillDisappear
    case interactionDisabled
}

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
        case .rowsChanged:
            return
        case let .previewStarted(preview),
             let .previewChanged(preview):
            transitionToPreview(preview)
        case let .previewEnded(preview):
            guard currentPreview == preview else { return }
            currentPreview = nil
            backend.stopPreview()
        }
    }

    func forceStop(reason _: PlaybackStopReason) {
        currentPreview = nil
        backend.stopPreview()
    }
}
```

### 1.2 `PlaybackPitch.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackPitch.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；NotePitch 还没有给发声层直接可用的 MIDI 编号与频率映射。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackPitch.swift
// 函数名: midiNoteNumber / playbackFrequencyHz
// 功能说明: 修改后把 NotePitch 扩展成可直接驱动后端的播放参数，避免平台层各自重复推导音高到频率的公式。
extension NotePitch {
    var midiNoteNumber: Int {
        absoluteSemitone + 12
    }

    var playbackFrequencyHz: Double {
        440 * pow(
            2,
            Double(midiNoteNumber - 69) / 12
        )
    }
}
```

---

## 2. 新增共享 AVFoundation 发声核心与平台后端

### 2.1 `AVFoundationTonePlaybackEngine.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/AVFoundationTonePlaybackEngine.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；工程里还没有一个可被 iOS/macOS 共用的首版发声引擎。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/AVFoundationTonePlaybackEngine.swift
// 函数名: startPreview(note:) / replacePreview(note:) / stopPreview() / renderAudio(frameCount:audioBufferList:)
// 功能说明: 修改后新增共享 AVFoundation 发声引擎，用 AVAudioSourceNode 直接生成平滑的正弦波；切音时改 targetFrequency，停音时把 targetAmplitude 拉回 0，避免 click 和残音。
final class AVFoundationTonePlaybackEngine {
    private static let previewAmplitude = 0.14
    private static let smoothingFactor = 0.004
    private static let amplitudeEpsilon = 0.0001

    private struct RenderState {
        let sampleRate: Double
        var phase = 0.0
        var currentFrequencyHz = 0.0
        var targetFrequencyHz = 0.0
        var currentAmplitude = 0.0
        var targetAmplitude = 0.0

        mutating func nextSample() -> Float {
            currentFrequencyHz += (targetFrequencyHz - currentFrequencyHz)
                * AVFoundationTonePlaybackEngine.smoothingFactor
            currentAmplitude += (targetAmplitude - currentAmplitude)
                * AVFoundationTonePlaybackEngine.smoothingFactor
            let sample = sin(phase) * currentAmplitude
            phase += (2 * .pi * max(currentFrequencyHz, 0)) / sampleRate
            return Float(sample)
        }
    }

    func startPreview(note: NotePitch) {
        ensureEngineRunning()
        renderState.targetFrequencyHz = note.playbackFrequencyHz
        renderState.targetAmplitude = Self.previewAmplitude
    }

    func replacePreview(note: NotePitch) {
        ensureEngineRunning()
        renderState.targetFrequencyHz = note.playbackFrequencyHz
        renderState.targetAmplitude = Self.previewAmplitude
    }

    func stopPreview() {
        renderState.targetAmplitude = 0
    }
}
```

### 2.2 `iOSPlaybackAudioBackend.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Playback/iOSPlaybackAudioBackend.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；iOS 端还没有实现 PlaybackAudioBackend，也没有在 preview 发声前统一准备 AVAudioSession。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Playback/iOSPlaybackAudioBackend.swift
// 函数名: startPreview(note:) / replacePreview(note:) / prepareAudioSession()
// 功能说明: 修改后 iOS 后端用共享 toneEngine 发声，并在起音/切音前统一激活 AVAudioSession，避免把 session 逻辑散落到 controller。
#if os(iOS)
import AVFoundation

final class iOSPlaybackAudioBackend: PlaybackAudioBackend {
    private let toneEngine = AVFoundationTonePlaybackEngine()

    func startPreview(note: NotePitch) {
        prepareAudioSession()
        toneEngine.startPreview(note: note)
    }

    func replacePreview(note: NotePitch) {
        prepareAudioSession()
        toneEngine.replacePreview(note: note)
    }

    func stopPreview() {
        toneEngine.stopPreview()
    }
}
#endif
```

### 2.3 `macOSPlaybackAudioBackend.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Playback/macOSPlaybackAudioBackend.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；macOS 端还没有自己的 PlaybackAudioBackend 实现。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Playback/macOSPlaybackAudioBackend.swift
// 函数名: startPreview(note:) / replacePreview(note:) / stopPreview()
// 功能说明: 修改后 macOS 后端与 iOS 走同一 contract，但把平台差异限制在最薄的一层 wrapper 中。
#if os(macOS)
import AVFoundation

final class macOSPlaybackAudioBackend: PlaybackAudioBackend {
    private let toneEngine = AVFoundationTonePlaybackEngine()

    func startPreview(note: NotePitch) {
        toneEngine.startPreview(note: note)
    }

    func replacePreview(note: NotePitch) {
        toneEngine.replacePreview(note: note)
    }

    func stopPreview() {
        toneEngine.stopPreview()
    }
}
#endif
```

---

## 3. 为 keyboard / surface 补齐“中断当前预览”语义

### 3.1 `iOSPianoKeyboardView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: replaceRows(_:)
// 功能说明: 修改前 replaceRows 只会重建 rows 与 backing state；如果 rows 替换把当前 preview 清掉，不会补 previewEnded，也没有显式中断当前交互的入口。
func replaceRows(_ newRows: [PianoRowState]) {
    cancelRowsTransitionAnimationForExternalStateChange()

    guard componentState.rows != newRows else {
        return
    }
    let hadActiveInteraction = componentState.activeInteraction != nil
    componentState = sanitizedState(
        byReplacingRowsWith: newRows,
        from: componentState
    )

    if hadActiveInteraction, componentState.activeInteraction == nil {
        activeTouch = nil
        lastTrackedLocationInView = nil
    }

    applyBackingState()
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: interruptActiveInteraction() / replaceRows(_:) / resetActiveInteraction(emitsPreviewEnded:)
// 功能说明: 修改后 iOS keyboard view 既能主动中断当前触摸序列，也能在 rows 替换导致 preview 失效时补发 previewEnded，把“悬空音”问题从组件底层收掉。
func interruptActiveInteraction() {
    resetActiveInteraction(emitsPreviewEnded: true)
}

func replaceRows(_ newRows: [PianoRowState]) {
    cancelRowsTransitionAnimationForExternalStateChange()

    guard componentState.rows != newRows else {
        return
    }
    let previousPreview = componentState.preview
    let hadActiveInteraction = componentState.activeInteraction != nil
    componentState = sanitizedState(
        byReplacingRowsWith: newRows,
        from: componentState
    )

    if hadActiveInteraction, componentState.activeInteraction == nil {
        activeTouch = nil
        lastTrackedLocationInView = nil
    }

    applyBackingState()

    if let previousPreview,
       componentState.preview != previousPreview {
        emitSemanticEvents([.previewEnded(previousPreview)])
    }
}

func resetActiveInteraction(
    emitsPreviewEnded: Bool
) {
    cancelRowsTransitionAnimationForExternalStateChange()
    let interruptedPreview = componentState.preview
    let hadActiveInteraction = componentState.activeInteraction != nil
    guard interruptedPreview != nil || hadActiveInteraction else {
        return
    }

    componentState.preview = nil
    componentState.activeInteraction = nil
    activeTouch = nil
    lastTrackedLocationInView = nil
    applyBackingState()

    if emitsPreviewEnded, let interruptedPreview {
        emitSemanticEvents([.previewEnded(interruptedPreview)])
    }
}
```

### 3.2 `macOSPianoKeyboardView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: replaceRows(_:)
// 功能说明: 修改前 macOS keyboard view 也只有 rows 重建，没有一个统一的中断入口；mouse sequence 和 preview 被清空时不会主动向上层补停音事件。
func replaceRows(_ newRows: [PianoRowState]) {
    cancelRowsTransitionAnimationForExternalStateChange()

    guard componentState.rows != newRows else {
        return
    }
    let hadActiveInteraction = componentState.activeInteraction != nil
    componentState = sanitizedState(
        byReplacingRowsWith: newRows,
        from: componentState
    )

    if hadActiveInteraction, componentState.activeInteraction == nil {
        isMouseSequenceActive = false
    }

    applyBackingState()
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: interruptActiveInteraction() / replaceRows(_:) / resetActiveInteraction(emitsPreviewEnded:)
// 功能说明: 修改后 macOS 键盘组件与 iOS 对齐：rows 重建、交互中断、preview 清空都会统一走 previewEnded，controller 不再需要自己推断是否有遗留音。
func interruptActiveInteraction() {
    resetActiveInteraction(emitsPreviewEnded: true)
}

func replaceRows(_ newRows: [PianoRowState]) {
    cancelRowsTransitionAnimationForExternalStateChange()

    guard componentState.rows != newRows else {
        return
    }
    let previousPreview = componentState.preview
    let hadActiveInteraction = componentState.activeInteraction != nil
    componentState = sanitizedState(
        byReplacingRowsWith: newRows,
        from: componentState
    )

    if hadActiveInteraction, componentState.activeInteraction == nil {
        isMouseSequenceActive = false
    }

    applyBackingState()

    if let previousPreview,
       componentState.preview != previousPreview {
        emitSemanticEvents([.previewEnded(previousPreview)])
    }
}

func resetActiveInteraction(
    emitsPreviewEnded: Bool
) {
    cancelRowsTransitionAnimationForExternalStateChange()
    let interruptedPreview = componentState.preview
    let hadActiveInteraction = componentState.activeInteraction != nil
    guard interruptedPreview != nil || hadActiveInteraction else {
        return
    }

    componentState.preview = nil
    componentState.activeInteraction = nil
    isMouseSequenceActive = false
    applyBackingState()

    if emitsPreviewEnded, let interruptedPreview {
        emitSemanticEvents([.previewEnded(interruptedPreview)])
    }
}
```

### 3.3 `iOSPianoSurfaceView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift
// 函数名: isPianoInteractionEnabled / applyPanelState()
// 功能说明: 修改前 surface view 只负责把交互开关透传给 keyboard；如果 settings 改了 rows 或外层把交互关闭，当前按住的 preview 不会先被主动打断。
var isPianoInteractionEnabled = true {
    didSet {
        guard oldValue != isPianoInteractionEnabled else { return }
        pianoKeyboardView.isUserInteractionEnabled = isPianoInteractionEnabled
    }
}

func applyPanelState() {
    pianoKeyboardView.configuration = resolvedConfiguration
    pianoKeyboardView.rows = resolvedRows
    pianoKeyboardView.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    pianoKeyboardView.isUserInteractionEnabled = isPianoInteractionEnabled
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift
// 函数名: isPianoInteractionEnabled / interruptActiveInteraction() / applyPanelState()
// 功能说明: 修改后 surface 成为外层 controller 的统一中断入口；无论是 panelState 重建还是交互被禁用，都会先让 keyboard 发出 previewEnded，再切 UI 状态。
var isPianoInteractionEnabled = true {
    didSet {
        guard oldValue != isPianoInteractionEnabled else { return }
        if !isPianoInteractionEnabled {
            pianoKeyboardView.interruptActiveInteraction()
        }
        pianoKeyboardView.isUserInteractionEnabled = isPianoInteractionEnabled
    }
}

func interruptActiveInteraction() {
    pianoKeyboardView.interruptActiveInteraction()
}

func applyPanelState() {
    pianoKeyboardView.interruptActiveInteraction()
    pianoKeyboardView.configuration = resolvedConfiguration
    pianoKeyboardView.rows = resolvedRows
    pianoKeyboardView.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    pianoKeyboardView.isUserInteractionEnabled = isPianoInteractionEnabled
}
```

### 3.4 `macOSPianoSurfaceView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift
// 函数名: isPianoInteractionEnabled / applyPanelState()
// 功能说明: 修改前 macOS surface view 只会显隐 interactionBlockerView，本身不负责把当前钢琴预览手势中断掉。
var isPianoInteractionEnabled = true {
    didSet {
        guard oldValue != isPianoInteractionEnabled else { return }
        interactionBlockerView.isHidden = isPianoInteractionEnabled
    }
}

func applyPanelState() {
    pianoKeyboardView.configuration = resolvedConfiguration
    pianoKeyboardView.rows = resolvedRows
    pianoKeyboardView.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    interactionBlockerView.isHidden = isPianoInteractionEnabled
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift
// 函数名: isPianoInteractionEnabled / interruptActiveInteraction() / applyPanelState()
// 功能说明: 修改后 macOS surface 也与 iOS 对齐；外层只需要调用一个中断入口，就能同步停止 mouse sequence、preview 与 blocker 状态。
var isPianoInteractionEnabled = true {
    didSet {
        guard oldValue != isPianoInteractionEnabled else { return }
        if !isPianoInteractionEnabled {
            pianoKeyboardView.interruptActiveInteraction()
        }
        interactionBlockerView.isHidden = isPianoInteractionEnabled
    }
}

func interruptActiveInteraction() {
    pianoKeyboardView.interruptActiveInteraction()
}

func applyPanelState() {
    pianoKeyboardView.interruptActiveInteraction()
    pianoKeyboardView.configuration = resolvedConfiguration
    pianoKeyboardView.rows = resolvedRows
    pianoKeyboardView.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    interactionBlockerView.isHidden = isPianoInteractionEnabled
}
```

---

## 4. 在 play / exercise / root shell 上接入共享播放协调器

### 4.1 `iOSPlayViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: pianoSurfaceView / applySharedPianoSettings(_:) / handleSettingsPanelEvent(_:)
// 功能说明: 修改前 play controller 只负责展示 piano-only 页面与 settings；钢琴 preview 事件没有接音频后端，也没有在 mode 切换、shared settings 变化时主动停音。
private lazy var pianoSurfaceView = iOSPianoSurfaceView(
    chromeStyle: .plain,
    panelState: pianoPanelState
)

func applySharedPianoSettings(_ settingsSlice: PianoPanelSettingsSlice) {
    let nextPanelState = pianoPanelState.applyingSettingsSlice(settingsSlice)
    guard nextPanelState != pianoPanelState else { return }
    pianoPanelState = nextPanelState
}

if nextStateContext.rootMode != .play {
    setSettingsPresented(false)
    onRootModeChangeRequest?(nextStateContext.rootMode)
    return
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: setPlaybackCoordinator(_:) / handlePianoSemanticEvent(_:) / interruptActivePianoPlayback(reason:) / viewWillDisappear(_:) / handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS play controller 把 pianoSurfaceView 的 preview 事件接到共享 coordinator，并在 shared settings、panelState 变化、rootMode 切换、页面消失时统一强制静音。
private var playbackCoordinator: PlaybackCoordinator?

private lazy var pianoSurfaceView: iOSPianoSurfaceView = {
    let pianoSurfaceView = iOSPianoSurfaceView(
        chromeStyle: .plain,
        panelState: pianoPanelState
    )
    pianoSurfaceView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewStarted(preview))
    }
    pianoSurfaceView.onPreviewChanged = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewChanged(preview))
    }
    pianoSurfaceView.onPreviewEnded = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewEnded(preview))
    }
    return pianoSurfaceView
}()

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    interruptActivePianoPlayback(reason: .viewWillDisappear)
}

func interruptActivePianoPlayback(reason: PlaybackStopReason) {
    pianoSurfaceView.interruptActiveInteraction()
    playbackCoordinator?.forceStop(reason: reason)
}

if nextStateContext.rootMode != .play {
    setSettingsPresented(false)
    interruptActivePianoPlayback(reason: .rootModeChanged)
    onRootModeChangeRequest?(nextStateContext.rootMode)
    return
}
```

### 4.2 `macOSPlayViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift
// 函数名: pianoSurfaceView / applySharedPianoSettings(_:) / handleSettingsPanelEvent(_:)
// 功能说明: 修改前 macOS play controller 也只有页面壳层逻辑，没有真正的播放协调器接线与强制停音点。
private lazy var pianoSurfaceView = macOSPianoSurfaceView(
    chromeStyle: .plain,
    panelState: pianoPanelState
)

func applySharedPianoSettings(_ settingsSlice: PianoPanelSettingsSlice) {
    let nextPanelState = pianoPanelState.applyingSettingsSlice(settingsSlice)
    guard nextPanelState != pianoPanelState else { return }
    pianoPanelState = nextPanelState
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift
// 函数名: setPlaybackCoordinator(_:) / handlePianoSemanticEvent(_:) / interruptActivePianoPlayback(reason:) / viewWillDisappear() / handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS play controller 与 iOS 对齐，把 preview 事件、强制停音和 settings 变更中断都放到同一条控制链上。
private var playbackCoordinator: PlaybackCoordinator?

private lazy var pianoSurfaceView: macOSPianoSurfaceView = {
    let pianoSurfaceView = macOSPianoSurfaceView(
        chromeStyle: .plain,
        panelState: pianoPanelState
    )
    pianoSurfaceView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewStarted(preview))
    }
    pianoSurfaceView.onPreviewChanged = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewChanged(preview))
    }
    pianoSurfaceView.onPreviewEnded = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewEnded(preview))
    }
    return pianoSurfaceView
}()

override func viewWillDisappear() {
    super.viewWillDisappear()
    interruptActivePianoPlayback(reason: .viewWillDisappear)
}

func interruptActivePianoPlayback(reason: PlaybackStopReason) {
    pianoSurfaceView.interruptActiveInteraction()
    playbackCoordinator?.forceStop(reason: reason)
}
```

### 4.3 `iOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: 成员定义 / pianoAccessorySurfaceView / applySharedPianoSettings(_:) / handleSettingsPanelEvent(_:)
// 功能说明: 修改前 exercise controller 虽然已经复用钢琴 surface，但它还没有 playbackCoordinator，也没有把 preview 事件或强制静音场景接出去。
private var pianoPanelState = iOSViewController.initialPianoPanelState
var onRootModeChangeRequest: ((RootMode) -> Void)?

private lazy var pianoAccessorySurfaceView = iOSPianoSurfaceView(
    chromeStyle: .card,
    panelState: pianoPanelState
)

func applySharedPianoSettings(_ settingsSlice: PianoPanelSettingsSlice) {
    let nextPianoPanelState = pianoPanelState.applyingSettingsSlice(settingsSlice)
    guard nextPianoPanelState != pianoPanelState else { return }
    pianoPanelState = nextPianoPanelState
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: setPlaybackCoordinator(_:) / pianoAccessorySurfaceView / handlePianoSemanticEvent(_:) / interruptActivePianoPlayback(reason:) / viewWillDisappear(_:) / handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS exercise controller 也共享同一个播放协调器；只要 accessory piano 的 preview 生命周期发生变化，或者 settings / rootMode 导致钢琴状态重建，都会统一停音。
private var pianoPanelState = iOSViewController.initialPianoPanelState
private var playbackCoordinator: PlaybackCoordinator?
var onRootModeChangeRequest: ((RootMode) -> Void)?

private lazy var pianoAccessorySurfaceView: iOSPianoSurfaceView = {
    let pianoAccessorySurfaceView = iOSPianoSurfaceView(
        chromeStyle: .card,
        panelState: pianoPanelState
    )
    pianoAccessorySurfaceView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewStarted(preview))
    }
    pianoAccessorySurfaceView.onPreviewChanged = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewChanged(preview))
    }
    pianoAccessorySurfaceView.onPreviewEnded = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewEnded(preview))
    }
    return pianoAccessorySurfaceView
}()

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    interruptActivePianoPlayback(reason: .viewWillDisappear)
}

func interruptActivePianoPlayback(reason: PlaybackStopReason) {
    pianoAccessorySurfaceView.interruptActiveInteraction()
    playbackCoordinator?.forceStop(reason: reason)
}

private func handlePianoSemanticEvent(_ event: PianoSemanticEvent) {
    playbackCoordinator?.handle(event)
}
```

### 4.4 `macOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: 成员定义 / pianoAccessorySurfaceView / applySharedPianoSettings(_:) / handleSettingsPanelEvent(_:)
// 功能说明: 修改前 macOS exercise controller 同样没有共享 playbackCoordinator；钢琴 accessory 的 preview 语义只停留在 UI 层。
private var pianoPanelState = macOSViewController.initialPianoPanelState {
    didSet {
        invalidatePianoPanelPresentation()
    }
}
var onRootModeChangeRequest: ((RootMode) -> Void)?

private lazy var pianoAccessorySurfaceView = macOSPianoSurfaceView(
    chromeStyle: .card,
    panelState: pianoPanelState
)
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: setPlaybackCoordinator(_:) / pianoAccessorySurfaceView / handlePianoSemanticEvent(_:) / interruptActivePianoPlayback(reason:) / viewWillDisappear() / handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS exercise controller 与 iOS 对齐，把 preview 事件、settings 改动和页面消失时的停音统一接到共享 coordinator。
private var pianoPanelState = macOSViewController.initialPianoPanelState {
    didSet {
        invalidatePianoPanelPresentation()
    }
}
private var playbackCoordinator: PlaybackCoordinator?
var onRootModeChangeRequest: ((RootMode) -> Void)?

private lazy var pianoAccessorySurfaceView: macOSPianoSurfaceView = {
    let pianoAccessorySurfaceView = macOSPianoSurfaceView(
        chromeStyle: .card,
        panelState: pianoPanelState
    )
    pianoAccessorySurfaceView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewStarted(preview))
    }
    pianoAccessorySurfaceView.onPreviewChanged = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewChanged(preview))
    }
    pianoAccessorySurfaceView.onPreviewEnded = { [weak self] preview in
        self?.handlePianoSemanticEvent(.previewEnded(preview))
    }
    return pianoAccessorySurfaceView
}()

override func viewWillDisappear() {
    super.viewWillDisappear()
    interruptActivePianoPlayback(reason: .viewWillDisappear)
}

private func handlePianoSemanticEvent(_ event: PianoSemanticEvent) {
    playbackCoordinator?.handle(event)
}
```

### 4.5 `iOSRootViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift
// 函数名: 成员定义 / setRootMode(_:) / configureChildControllers()
// 功能说明: 修改前 root shell 只负责 exercise/play controller 切换与 sharedPianoSettings 同步；并没有一个跨 mode 共享的 PlaybackCoordinator。
private let exerciseViewController = iOSViewController()
private let playViewController = iOSPlayViewController()
private var sharedPianoSettings = PianoSurfaceDefaults.sharedSettings

func setRootMode(_ rootMode: RootMode) {
    guard self.rootMode != rootMode || currentViewController == nil else { return }
    syncSharedPianoSettingsFromCurrentMode()
    applySharedPianoSettingsToChildren()
    self.rootMode = rootMode
    applyRootMode(rootMode)
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift
// 函数名: playbackCoordinator / setRootMode(_:) / configureChildControllers() / interruptActivePianoPlaybackForCurrentMode(reason:)
// 功能说明: 修改后 iOS root shell 持有全局唯一的 playbackCoordinator，并在切 rootMode 前强制停掉当前模式下的钢琴预览，再把 coordinator 注入 exercise/play 两个子控制器。
private let exerciseViewController = iOSViewController()
private let playViewController = iOSPlayViewController()
private var sharedPianoSettings = PianoSurfaceDefaults.sharedSettings
private lazy var playbackCoordinator = PlaybackCoordinator(
    backend: iOSPlaybackAudioBackend()
)

func setRootMode(_ rootMode: RootMode) {
    guard self.rootMode != rootMode || currentViewController == nil else { return }
    interruptActivePianoPlaybackForCurrentMode(reason: .rootModeChanged)
    syncSharedPianoSettingsFromCurrentMode()
    applySharedPianoSettingsToChildren()
    self.rootMode = rootMode
    applyRootMode(rootMode)
}

func configureChildControllers() {
    exerciseViewController.setPlaybackCoordinator(playbackCoordinator)
    playViewController.setPlaybackCoordinator(playbackCoordinator)
    applySharedPianoSettingsToChildren()
}
```

### 4.6 `macOSRootViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift
// 函数名: 成员定义 / setRootMode(_:) / configureChildControllers()
// 功能说明: 修改前 macOS root shell 与 iOS 一样只同步 shared piano settings，没有共享 playbackCoordinator。
private let exerciseViewController = macOSViewController()
private let playViewController = macOSPlayViewController()
private var sharedPianoSettings = PianoSurfaceDefaults.sharedSettings
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift
// 函数名: playbackCoordinator / setRootMode(_:) / configureChildControllers() / interruptActivePianoPlaybackForCurrentMode(reason:)
// 功能说明: 修改后 macOS root shell 也接入共享 playbackCoordinator，并在 mode 切换前先向当前活跃 controller 发起统一强制停音。
private let exerciseViewController = macOSViewController()
private let playViewController = macOSPlayViewController()
private var sharedPianoSettings = PianoSurfaceDefaults.sharedSettings
private lazy var playbackCoordinator = PlaybackCoordinator(
    backend: macOSPlaybackAudioBackend()
)

func interruptActivePianoPlaybackForCurrentMode(reason: PlaybackStopReason) {
    switch rootMode {
    case .exercise:
        exerciseViewController.interruptActivePianoPlayback(reason: reason)
    case .play:
        playViewController.interruptActivePianoPlayback(reason: reason)
    }
}
```

---

## 5. 新增播放语义验证，并接入应用启动验证链

### 5.1 `PlaybackValidation.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackValidation.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；phase5 新引入的播放协调器没有自动化夹具，无法回归验证 changed+ended 背靠背、stale ended、forceStop、rowsChanged 忽略等关键语义。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackValidation.swift
// 函数名: PlaybackValidationRunner.run(platform:) / validatePreviewLifecycle() / validateChangedThenEnded() / validateForceStop()
// 功能说明: 修改后新增一套独立的 playback validation，用 backend spy 验证协调器把 preview 语义正确映射成 start / replace / stop，并覆盖强制静音和幂等边界。
enum PlaybackValidationRunner {
    static func run(platform: PlaybackValidationPlatform) -> PlaybackValidationReport {
        let fixtures = makeFixtures()
        // ... 省略汇总逻辑 ...
    }
}

private final class PlaybackValidationBackendSpy: PlaybackAudioBackend {
    var commands: [PlaybackValidationBackendCommand] = []
}

private extension PlaybackValidationRunner {
    static func makeFixtures() -> [PlaybackValidationFixture] {
        [
            PlaybackValidationFixture(
                name: "preview_lifecycle_routes_start_replace_stop",
                validate: validatePreviewLifecycle
            ),
            PlaybackValidationFixture(
                name: "changed_then_ended_does_not_leave_hanging_note",
                validate: validateChangedThenEnded
            ),
            PlaybackValidationFixture(
                name: "stale_preview_end_is_ignored",
                validate: validateStalePreviewEnd
            ),
            PlaybackValidationFixture(
                name: "force_stop_clears_active_preview",
                validate: validateForceStop
            )
        ]
    }
}
```

### 5.2 `iOSAppDelegate.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改前启动验证链只有 fretboard / staff / settings / piano / play composition / exercise composition，没有 playback validation。
print("[Startup][iOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run play composition validation")
PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改后把 playback validation 串到 app 启动验证链里，保证 coordinator 语义回归会在 iOS Debug 启动阶段尽早暴露。
print("[Startup][iOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run playback validation")
PlaybackValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run play composition validation")
PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
```

### 5.3 `macOSAppDelegate.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 修改前 macOS 启动验证链也没有 playback validation。
print("[Startup][macOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run play composition validation")
PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 修改后 macOS Debug 启动也会同步跑 playback validation，和 iOS 保持一致。
print("[Startup][macOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run playback validation")
PlaybackValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run play composition validation")
PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
```

---

## 6. 本轮修改后的实际行为变化

- `play` 页面按下钢琴键后，preview 事件会被共享 `PlaybackCoordinator` 收口，并驱动 iOS/macOS 平台后端发声。
- 滑音时如果 `previewChanged` 切到新音，协调器会走 `replacePreview`；如果 `previewChanged + previewEnded` 背靠背出现，也会在同一轮里正确完成“切音后停音”。
- `rows` 替换、`panelState` 变化、`shared settings` 变化、`viewWillDisappear`、`rootMode` 切换时，当前 preview 会被统一打断，不再依赖 keyboard view 自然收到 `ended/cancelled`。
- `rowsChanged` 事件不会直接触发发声；真正的强制静音由 keyboard/surface/controller/root shell 的显式中断链路承担。

---

## 7. 验证结果

本轮实际做了以下验证：

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build CODE_SIGNING_ALLOWED=NO`
- 对本轮改动文件执行 `ReadLints`，未发现新增诊断

验证结论：

- iOS Debug 构建通过
- macOS Debug 构建通过
- `PlaybackValidationRunner` 已接入 iOS/macOS 启动验证链

# 20260408_103137_phase5_phase6_polyphonic_playback_validation_smoke

## 记录范围

本记录只覆盖刚刚这一轮“多指复音计划 phase5 + phase6”的实际代码修改。

这轮修改的真实目标有两部分：

- 把 `PlaybackCoordinator`、平台后端协议与 `AVFoundationTonePlaybackEngine` 从单音替换模型升级成按 `VoiceId` 管理的复音播放链路。
- 把 phase6 需要的 `PlaybackValidation`、`PianoValidation` 手工检查项、以及 iOS / macOS 的 startup smoke 入口补齐，让 Debug 启动可以自动暴露回归。

这次没有去改 `.cursor/plans/多指复音计划_27c48b8b.plan.md`，也没有额外去改 controller / surface 的事件转发层；原因是现有 `previewStarted / previewChanged / previewEnded` 语义事件接线已经足够把多 preview 送入升级后的 `PlaybackCoordinator`，因此这轮真正需要落地的是播放链路本身与验证闭环。

本记录参考了当前工作区的 `git diff`、`git status`、当前代码文件内容、以及本轮实际运行的构建 / smoke 日志，但 **不包含原始 diff**。

当前工作区里，与本轮 phase5 + phase6 直接相关的代码文件有 8 个：

- `NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift`
- `NoteMaster_Ver_1/Shared/Playback/AVFoundationTonePlaybackEngine.swift`
- `NoteMaster_Ver_1/Platform/iOS/Playback/iOSPlaybackAudioBackend.swift`
- `NoteMaster_Ver_1/Platform/macOS/Playback/macOSPlaybackAudioBackend.swift`
- `NoteMaster_Ver_1/Shared/Playback/PlaybackValidation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`

当前工作区另外还存在 `@.cursor/plans/多指复音计划_27c48b8b.plan.md` 的变更，但它不是本轮 phase5 + phase6 代码实现的一部分，因此本记录不把它计入“修改前 / 修改后”范围。

---

## 1. `PlaybackCoordinator.swift`：从单 preview 切到按 `VoiceId` 管理的多声部协调器

### 1.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift
// 函数名: PlaybackAudioBackend / handle(_:) / forceStop(reason:) / transitionToPreview(_:)
// 功能说明: 修改前后端协议只有 start/replace/stop 三个单音入口；coordinator 虽然已经有 activeVoices 字典，但运行时仍会把所有播放折叠成“最后一路 preview”，并在 ended/forceStop 时直接全停单音。
typealias PlaybackVoiceID = PianoVoiceID

protocol PlaybackAudioBackend: AnyObject {
    func startPreview(note: NotePitch)
    func replacePreview(note: NotePitch)
    func stopPreview()
}

final class PlaybackCoordinator {
    private let backend: PlaybackAudioBackend

    private(set) var activeVoices: [PlaybackVoiceID: PianoPreviewState] = [:]

    func handle(_ semanticEvent: PianoSemanticEvent) {
        switch semanticEvent {
        case .rowsChanged:
            return
        case let .previewStarted(preview):
            transitionToPreview(preview)
        case let .previewChanged(preview):
            transitionToPreview(preview)
        case let .previewEnded(preview):
            guard activeVoices[preview.voiceID] == preview else {
                return
            }

            activeVoices.removeValue(forKey: preview.voiceID)
            backend.stopPreview()
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
            guard currentPreview != preview else {
                return
            }

            if currentPreview.note != preview.note {
                backend.replacePreview(note: preview.note)
            }

            activeVoices = [preview.voiceID: preview]
            return
        }

        activeVoices = [preview.voiceID: preview]
        backend.startPreview(note: preview.note)
    }
}
```

### 1.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift
// 函数名: PlaybackAudioBackend / handle(_:) / forceStop(reason:) / upsertVoice(_:)
// 功能说明: 修改后后端协议升级成按 VoiceId 寻址；coordinator 为每一路 preview 单独 upsert / stop，对 stale ended 做 voice 级隔离，forceStop 也变成 stopAllVoices。
typealias PlaybackVoiceID = PianoVoiceID

protocol PlaybackAudioBackend: AnyObject {
    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch)
    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch)
    func stopVoice(_ voiceID: PlaybackVoiceID)
    func stopAllVoices()
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
        case .rowsChanged:
            return
        case let .previewStarted(preview):
            upsertVoice(preview)
        case let .previewChanged(preview):
            upsertVoice(preview)
        case let .previewEnded(preview):
            guard activeVoices[preview.voiceID] == preview else {
                return
            }

            activeVoices.removeValue(forKey: preview.voiceID)
            backend.stopVoice(preview.voiceID)
        }
    }

    func forceStop(reason _: PlaybackStopReason) {
        activeVoices.removeAll()
        backend.stopAllVoices()
    }
}

private extension PlaybackCoordinator {
    func upsertVoice(_ preview: PianoPreviewState) {
        if let currentVoice = activeVoices[preview.voiceID] {
            guard currentVoice != preview else {
                return
            }

            activeVoices[preview.voiceID] = preview
            if currentVoice.note != preview.note {
                backend.updateVoice(preview.voiceID, note: preview.note)
            }
            return
        }

        activeVoices[preview.voiceID] = preview
        backend.startVoice(preview.voiceID, note: preview.note)
    }
}
```

---

## 2. `AVFoundationTonePlaybackEngine.swift`：从单振荡器切到多 voice mixer

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/AVFoundationTonePlaybackEngine.swift
// 函数名: RenderState / startPreview(note:) / replacePreview(note:) / stopPreview() / renderAudio(frameCount:audioBufferList:)
// 功能说明: 修改前 tone engine 只有一份 RenderState；任意新 preview 只是覆盖当前频率和幅度，renderAudio 每帧只生成一个 sample，因此本质上仍然是单音替换。
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

    private let engine = AVAudioEngine()
    private let sourceFormat: AVAudioFormat
    private var renderState: RenderState

    func startPreview(note: NotePitch) {
        ensureEngineRunning()
        let frequencyHz = note.playbackFrequencyHz
        renderState.targetFrequencyHz = frequencyHz
        if abs(renderState.currentAmplitude) < Self.amplitudeEpsilon {
            renderState.currentFrequencyHz = frequencyHz
        }
        renderState.targetAmplitude = Self.previewAmplitude
    }

    func replacePreview(note: NotePitch) {
        ensureEngineRunning()
        let frequencyHz = note.playbackFrequencyHz
        renderState.targetFrequencyHz = frequencyHz
        if abs(renderState.currentAmplitude) < Self.amplitudeEpsilon {
            renderState.currentFrequencyHz = frequencyHz
        }
        renderState.targetAmplitude = Self.previewAmplitude
    }

    func stopPreview() {
        renderState.targetAmplitude = 0
    }

    func renderAudio(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for frameIndex in 0..<Int(frameCount) {
            let sample = renderState.nextSample()
            for buffer in buffers {
                let samples = buffer.mData!.assumingMemoryBound(to: Float.self)
                samples[frameIndex] = sample
            }
        }

        return noErr
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/AVFoundationTonePlaybackEngine.swift
// 函数名: VoiceRenderState / startVoice(_:note:) / updateVoice(_:note:) / stopVoice(_:) / stopAllVoices() / renderAudio(frameCount:audioBufferList:)
// 功能说明: 修改后每个 PlaybackVoiceID 都有独立的频率/幅度/相位状态；renderAudio 在音频线程里遍历所有 voice 混音，并在幅度衰减到阈值后自动 prune 已停掉的 voice。
final class AVFoundationTonePlaybackEngine {
    private static let previewAmplitude = 0.14
    private static let smoothingFactor = 0.004
    private static let amplitudeEpsilon = 0.0001

    private struct VoiceRenderState {
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

            if targetAmplitude == 0,
               abs(currentAmplitude) < AVFoundationTonePlaybackEngine.amplitudeEpsilon {
                currentAmplitude = 0
            }

            let sample = sin(phase) * currentAmplitude
            phase += (2 * .pi * max(currentFrequencyHz, 0)) / sampleRate
            if phase >= 2 * .pi {
                phase.formTruncatingRemainder(dividingBy: 2 * .pi)
            }

            return Float(sample)
        }

        var canBePruned: Bool {
            targetAmplitude == 0
                && abs(currentAmplitude) < AVFoundationTonePlaybackEngine.amplitudeEpsilon
        }
    }

    private let engine = AVAudioEngine()
    private let sourceFormat: AVAudioFormat
    private let renderStateLock = NSLock()
    private var voiceStates: [PlaybackVoiceID: VoiceRenderState] = [:]

    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        ensureEngineRunning()
        updateVoiceState(voiceID, note: note)
    }

    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        ensureEngineRunning()
        updateVoiceState(voiceID, note: note)
    }

    func stopVoice(_ voiceID: PlaybackVoiceID) {
        renderStateLock.lock()
        defer { renderStateLock.unlock() }

        guard var voiceState = voiceStates[voiceID] else {
            return
        }
        voiceState.targetAmplitude = 0
        voiceStates[voiceID] = voiceState
    }

    func stopAllVoices() {
        renderStateLock.lock()
        voiceStates.removeAll()
        renderStateLock.unlock()
    }

    func renderAudio(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        renderStateLock.lock()
        defer { renderStateLock.unlock() }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for frameIndex in 0..<Int(frameCount) {
            let voiceIDs = Array(voiceStates.keys)
            let normalizationFactor = max(1.0, sqrt(Double(voiceIDs.count)))
            var mixedSample = 0.0

            for voiceID in voiceIDs {
                guard var voiceState = voiceStates[voiceID] else {
                    continue
                }

                mixedSample += Double(voiceState.nextSample())
                if voiceState.canBePruned {
                    voiceStates.removeValue(forKey: voiceID)
                } else {
                    voiceStates[voiceID] = voiceState
                }
            }

            let sample = Float(
                max(min(mixedSample / normalizationFactor, 1.0), -1.0)
            )
            for buffer in buffers {
                guard let mData = buffer.mData else {
                    continue
                }

                let samples = mData.assumingMemoryBound(to: Float.self)
                samples[frameIndex] = sample
            }
        }

        return noErr
    }
}
```

---

## 3. `iOSPlaybackAudioBackend.swift`：接到多 voice 协议，并避免重复配置音频 session

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Playback/iOSPlaybackAudioBackend.swift
// 函数名: startPreview(note:) / replacePreview(note:) / stopPreview() / prepareAudioSession()
// 功能说明: 修改前 iOS backend 仍按单音协议工作；每次 start/replace 都会重新 prepare AVAudioSession，无法表达按 voice 定位的独立 start/update/stop。
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

private extension iOSPlaybackAudioBackend {
    func prepareAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("[Playback][iOSBackend] audioSessionSetupFailed error=\(error)")
        }
    }
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Playback/iOSPlaybackAudioBackend.swift
// 函数名: startVoice(_:note:) / updateVoice(_:note:) / stopVoice(_:) / stopAllVoices() / prepareAudioSessionIfNeeded()
// 功能说明: 修改后 iOS backend 完整对接多 voice 协议，并把 AVAudioSession 的准备改成只做一次，避免和弦时每条 voice 都重复重配 session。
final class iOSPlaybackAudioBackend: PlaybackAudioBackend {
    private let toneEngine = AVFoundationTonePlaybackEngine()
    private var isAudioSessionPrepared = false

    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        prepareAudioSessionIfNeeded()
        toneEngine.startVoice(voiceID, note: note)
    }

    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        prepareAudioSessionIfNeeded()
        toneEngine.updateVoice(voiceID, note: note)
    }

    func stopVoice(_ voiceID: PlaybackVoiceID) {
        toneEngine.stopVoice(voiceID)
    }

    func stopAllVoices() {
        toneEngine.stopAllVoices()
    }
}

private extension iOSPlaybackAudioBackend {
    func prepareAudioSessionIfNeeded() {
        guard !isAudioSessionPrepared else {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
            isAudioSessionPrepared = true
        } catch {
            print("[Playback][iOSBackend] audioSessionSetupFailed error=\(error)")
        }
    }
}
```

---

## 4. `macOSPlaybackAudioBackend.swift`：把平台后端接口同步升级成多 voice

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Playback/macOSPlaybackAudioBackend.swift
// 函数名: startPreview(note:) / replacePreview(note:) / stopPreview()
// 功能说明: 修改前 macOS backend 和 iOS 一样仍停留在单音 start/replace/stop 语义，无法和 PlaybackCoordinator 的 voice map 一一对应。
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
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Playback/macOSPlaybackAudioBackend.swift
// 函数名: startVoice(_:note:) / updateVoice(_:note:) / stopVoice(_:) / stopAllVoices()
// 功能说明: 修改后 macOS backend 直接把 voice 级命令透传给多声部 tone engine，和共享层的 PlaybackAudioBackend 协议保持一致。
final class macOSPlaybackAudioBackend: PlaybackAudioBackend {
    private let toneEngine = AVFoundationTonePlaybackEngine()

    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        toneEngine.startVoice(voiceID, note: note)
    }

    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        toneEngine.updateVoice(voiceID, note: note)
    }

    func stopVoice(_ voiceID: PlaybackVoiceID) {
        toneEngine.stopVoice(voiceID)
    }

    func stopAllVoices() {
        toneEngine.stopAllVoices()
    }
}
```

---

## 5. `PlaybackValidation.swift`：把 validation 从单音生命周期改写成多 voice 夹具

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackValidation.swift
// 函数名: PlaybackValidationBackendCommand / makeFixtures() / validatePreviewLifecycle() / validateStalePreviewEnd() / validateForceStop()
// 功能说明: 修改前 validation 仍在验证单音 runtime：start -> replace -> stop、changedThenEnded、stalePreviewEnd、forceStop 清 currentPreview；这些夹具无法约束“并发 voice、单 voice update/stop、stopAll”的新语义。
private enum PlaybackValidationBackendCommand: Equatable {
    case start(NotePitch)
    case replace(NotePitch)
    case stop
}

private final class PlaybackValidationBackendSpy: PlaybackAudioBackend {
    var commands: [PlaybackValidationBackendCommand] = []

    func startPreview(note: NotePitch) {
        commands.append(.start(note))
    }

    func replacePreview(note: NotePitch) {
        commands.append(.replace(note))
    }

    func stopPreview() {
        commands.append(.stop)
    }
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
            ),
            PlaybackValidationFixture(
                name: "rows_changed_is_ignored",
                validate: validateRowsChangedIgnored
            )
        ]
    }
}
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Playback/PlaybackValidation.swift
// 函数名: PlaybackValidationBackendCommand / makeFixtures() / validateMultipleVoiceStart() / validateSingleVoiceUpdate() / validateSingleVoiceStop() / validateStalePreviewEndIsolation() / validateForceStopStopsAllVoices()
// 功能说明: 修改后 validation 明确锁住复音语义：多 voice 并发 start、单 voice update、单 voice stop、stale ended 隔离、stop all，以及配套的手工 smoke checklist。
private enum PlaybackValidationBackendCommand: Equatable {
    case start(PlaybackVoiceID, NotePitch)
    case update(PlaybackVoiceID, NotePitch)
    case stop(PlaybackVoiceID)
    case stopAll
}

private final class PlaybackValidationBackendSpy: PlaybackAudioBackend {
    var commands: [PlaybackValidationBackendCommand] = []

    func startVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        commands.append(.start(voiceID, note))
    }

    func updateVoice(_ voiceID: PlaybackVoiceID, note: NotePitch) {
        commands.append(.update(voiceID, note))
    }

    func stopVoice(_ voiceID: PlaybackVoiceID) {
        commands.append(.stop(voiceID))
    }

    func stopAllVoices() {
        commands.append(.stopAll)
    }
}

private extension PlaybackValidationRunner {
    static func makeFixtures() -> [PlaybackValidationFixture] {
        [
            PlaybackValidationFixture(
                name: "multiple_voices_start_independently",
                validate: validateMultipleVoiceStart
            ),
            PlaybackValidationFixture(
                name: "single_voice_update_does_not_replace_siblings",
                validate: validateSingleVoiceUpdate
            ),
            PlaybackValidationFixture(
                name: "single_voice_stop_does_not_stop_siblings",
                validate: validateSingleVoiceStop
            ),
            PlaybackValidationFixture(
                name: "stale_preview_end_is_ignored_per_voice",
                validate: validateStalePreviewEndIsolation
            ),
            PlaybackValidationFixture(
                name: "force_stop_stops_all_voices",
                validate: validateForceStopStopsAllVoices
            ),
            PlaybackValidationFixture(
                name: "rows_changed_is_ignored",
                validate: validateRowsChangedIgnored
            )
        ]
    }

    static func validateMultipleVoiceStart() -> [PlaybackValidationIssue] {
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let voiceA = preview(id: 1, rowIndex: 0, note: note(.c, octave: 4))
        let voiceB = preview(id: 2, rowIndex: 1, note: note(.g, octave: 4))

        coordinator.handle(.previewStarted(voiceA))
        coordinator.handle(.previewStarted(voiceB))

        if spy.commands != [
            .start(voiceA.voiceID, note(.c, octave: 4)),
            .start(voiceB.voiceID, note(.g, octave: 4))
        ] {
            return [issue("multiple_voices_start_independently", "两个 previewStarted 应分别路由成两个独立的 start voice 命令。")]
        }
        return []
    }

    static func validateForceStopStopsAllVoices() -> [PlaybackValidationIssue] {
        let spy = PlaybackValidationBackendSpy()
        let coordinator = PlaybackCoordinator(backend: spy)
        let voiceA = preview(id: 1, rowIndex: 0, note: note(.b, octave: 3))
        let voiceB = preview(id: 2, rowIndex: 1, note: note(.e, octave: 4))

        coordinator.handle(.previewStarted(voiceA))
        coordinator.handle(.previewStarted(voiceB))
        coordinator.forceStop(reason: .rootModeChanged)

        if spy.commands != [
            .start(voiceA.voiceID, note(.b, octave: 3)),
            .start(voiceB.voiceID, note(.e, octave: 4)),
            .stopAll
        ] {
            return [issue("force_stop_stops_all_voices", "forceStop 应路由成 stopAllVoices，而不是只停最后一路 voice。")]
        }
        return []
    }
}
```

---

## 6. `PianoValidation.swift`：补上 phase6 手工 smoke checklist

### 6.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: manualChecklist(for:)
// 功能说明: 修改前手工清单已经覆盖多 pointer 的输入与高亮，但还没有把“和弦并发时高亮数量”和“模式切换时 UI 与音频同时全停”显式写进回归口径。
static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
    [
        "确认同一行两个音、跨行两个音可同时高亮；快速交替两音时不会只剩一个稳定高亮。",
        "确认 iOS 上两根手指可并发触发两路 pointer，抬起其中一根时另一根不会被误 ended。",
        "确认 macOS 上 mouse / touch pointer 中断、切换 mode、切 settings 或 view disappear 时，不会残留未清理 pointer 或重复 ended。",
        "确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。"
    ]
}
```

### 6.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: manualChecklist(for:)
// 功能说明: 修改后手工清单把 phase6 关心的“多指和弦时高亮数量一致”和“模式切换时 UI + audio 一起全停”补成显式检查项。
static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
    [
        "确认同一行两个音、跨行两个音可同时高亮；快速交替两音时不会只剩一个稳定高亮。",
        "确认 iOS 上两根手指可并发触发两路 pointer，抬起其中一根时另一根不会被误 ended。",
        "确认 macOS 上 mouse / touch pointer 中断、切换 mode、切 settings 或 view disappear 时，不会残留未清理 pointer 或重复 ended。",
        "确认双指和弦、快速交替、以及 glissando 与和弦并发时，活动高亮数量始终与实际活动 pointer 一致。",
        "确认切换 play/exercise、关闭页面或禁用交互时，pointer 高亮与音频 voice 都会全停，不会只清 UI 不清音频。",
        "确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。"
    ]
}
```

---

## 7. `iOSAppDelegate.swift`：新增 startup validation-only smoke 入口

### 7.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:) / RuntimeSmokeScenario
// 功能说明: 修改前 iOS 启动期虽然会跑 validation，但 debug smoke 只有 layout-preset-regression 场景，没有“只跑启动 validations 然后自动退出”的入口，因此无法稳定做 startup smoke。
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    print("[Startup][iOSApp] run playback validation")
    PlaybackValidationRunner.runAndReportIfNeeded(platform: .iOS)
    print("[Startup][iOSApp] run play composition validation")
    PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
    print("[Startup][iOSApp] run exercise composition validation")
    ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)

    print("[Startup][iOSApp] create window")
    let window = UIWindow(frame: UIScreen.main.bounds)
    // ... 省略未改动代码 ...
    return true
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunLayoutPresetRegression: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == layoutPresetRegressionValue
    }
}
```

### 7.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:) / RuntimeSmokeScenario.shouldRunStartupValidationOnly
// 功能说明: 修改后 iOS 在 Debug 下支持 NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation，只跑启动期 validations 并打印 PASS 后退出，适合自动回归与快速验证挂链。
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    print("[Startup][iOSApp] run playback validation")
    PlaybackValidationRunner.runAndReportIfNeeded(platform: .iOS)
    print("[Startup][iOSApp] run play composition validation")
    PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
    print("[Startup][iOSApp] run exercise composition validation")
    ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)

    #if DEBUG
    if RuntimeSmokeScenario.shouldRunStartupValidationOnly {
        print("[RuntimeSmoke][iOS] PASS scenario=startup_validation")
        exit(0)
    }
    #endif

    print("[Startup][iOSApp] create window")
    let window = UIWindow(frame: UIScreen.main.bounds)
    // ... 省略未改动代码 ...
    return true
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"

    static var shouldRunLayoutPresetRegression: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == layoutPresetRegressionValue
    }

    static var shouldRunStartupValidationOnly: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == startupValidationValue
    }
}
```

---

## 8. `macOSAppDelegate.swift`：为 macOS 补同样的 startup validation-only smoke 入口

### 8.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:) / RuntimeSmokeScenario
// 功能说明: 修改前 macOS 也只有 layout-preset-regression 的 smoke 场景；启动期 validation 会跑，但没有“跑完 startup validations 就自动 terminate”的专用入口。
func applicationDidFinishLaunching(_ notification: Notification) {
    print("[Startup][macOSApp] run playback validation")
    PlaybackValidationRunner.runAndReportIfNeeded(platform: .macOS)
    print("[Startup][macOSApp] run play composition validation")
    PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
    print("[Startup][macOSApp] run exercise composition validation")
    ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)

    print("[Startup][macOSApp] apply aqua appearance")
    NSApp.appearance = NSAppearance(named: .aqua)
    // ... 省略未改动代码 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunLayoutPresetRegression: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == layoutPresetRegressionValue
    }
}
```

### 8.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:) / RuntimeSmokeScenario.shouldRunStartupValidationOnly
// 功能说明: 修改后 macOS 也支持 NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation，在所有启动期 validations 跑完后直接打印 PASS 并 terminate，方便 CI / 本地快速验证。
func applicationDidFinishLaunching(_ notification: Notification) {
    print("[Startup][macOSApp] run playback validation")
    PlaybackValidationRunner.runAndReportIfNeeded(platform: .macOS)
    print("[Startup][macOSApp] run play composition validation")
    PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
    print("[Startup][macOSApp] run exercise composition validation")
    ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)

    #if DEBUG
    if RuntimeSmokeScenario.shouldRunStartupValidationOnly {
        print("[RuntimeSmoke][macOS] PASS scenario=startup_validation")
        NSApp.terminate(nil)
        return
    }
    #endif

    print("[Startup][macOSApp] apply aqua appearance")
    NSApp.appearance = NSAppearance(named: .aqua)
    // ... 省略未改动代码 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"

    static var shouldRunLayoutPresetRegression: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == layoutPresetRegressionValue
    }

    static var shouldRunStartupValidationOnly: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == startupValidationValue
    }
}
```

---

## 9. 本轮实际验证结果

本轮不是只改代码未验证；实际跑过的检查如下：

- `ReadLints` 检查本轮改动文件，没有新增 lints。
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build` 通过。
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build` 通过。
- macOS startup smoke：使用 `NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation` 启动 Debug app，日志里 `PianoValidation` 32 个 fixtures 全部通过，`PlaybackValidation` 6 个 fixtures 全部通过，最终打印 `RuntimeSmoke PASS scenario=startup_validation`。
- iOS startup smoke：先安装 `Debug-iphonesimulator/NoteMaster_Ver_1.app` 到已启动模拟器，再用 `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"` 启动；日志里 `PianoValidation` 32 个 fixtures 全部通过，`PlaybackValidation` 6 个 fixtures 全部通过，最终打印 `RuntimeSmoke PASS scenario=startup_validation`。

---

## 10. 小结

这轮修改的本质不是“再补一点 UI 高亮”，而是把多 pointer / 多 preview 真正贯通到音频层和回归链路：

- 播放链路从单音替换升级成了真正的 `VoiceId` 级复音。
- 验证链路不再只验证旧的单音生命周期，而是明确锁住复音并发、单 voice 更新/停止、stale ended 隔离与 stopAll。
- 两端 app delegate 都有了可自动退出的 startup smoke 入口，后续再做回归时不需要手动打开 UI 再观察控制台。


# 20260407_172041_phase4_play_ui_shell_and_piano_only_ui

## 记录范围

本记录只覆盖刚刚这一轮 `phase4` 的实际修改，重点是把 `play` 从 root shell 里的 placeholder 落成真实的 `piano-only` 页面，并把钢琴相关状态从 exercise controller 里的 demo 语义抽出来。

本记录参考了当前工作区的 `git diff` 与文件现状，但**不包含原始 diff**。  
当前工作区里仍有一个用户侧已有的 `.md` 变更：

- `.cursor/plans/play模式分阶段计划_3b30e6c6.plan.md`

这个 `.md` 不属于本轮 phase4 实际代码落地，因此下面不把它算进本次记录范围。

本轮涉及文件：

- `NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoSurfaceDefaults.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`

---

## 1. 抽出跨 mode 共享的钢琴默认值与设置切片

### 1.1 `PianoPanelState.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名: PianoPanelState / inferred(configuration:rows:)
// 功能说明: 修改前 PianoPanelState 只保存 panel 自身状态；controller 之间没有一个轻量的“共享钢琴设置切片”，root shell 也无法只同步 rows/style/snap 这些可复用配置。
struct PianoPanelState: Equatable, Sendable {
    var isVisible: Bool
    var rowCount: Int
    var movementScope: PianoMovementScope
    var whiteKeyStyle: PianoWhiteKeyStyle
    var snapEnabled: Bool

    static func inferred(
        configuration: PianoConfiguration,
        rows: [PianoRowState]
    ) -> PianoPanelState {
        PianoPanelState(
            isVisible: false,
            rowCount: min(
                max(rows.count, Self.supportedRowCountRange.lowerBound),
                Self.supportedRowCountRange.upperBound
            ),
            movementScope: rows.first?.movementScope ?? .cascade,
            whiteKeyStyle: configuration.whiteKeyStyle,
            snapEnabled: configuration.snapEnabled
        )
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名: settingsSlice / applyingSettingsSlice(_:) / PianoPanelSettingsSlice
// 功能说明: 修改后把 rowCount / movementScope / whiteKeyStyle / snapEnabled 抽成可跨 mode 共享的设置切片；root shell 切换 exercise/play 时，只同步这组可复用配置，不再复制整块 controller 内部状态。
struct PianoPanelState: Equatable, Sendable {
    // ... 其它字段保持不变 ...

    var settingsSlice: PianoPanelSettingsSlice {
        PianoPanelSettingsSlice(
            rowCount: rowCount,
            movementScope: movementScope,
            whiteKeyStyle: whiteKeyStyle,
            snapEnabled: snapEnabled
        )
    }

    func applyingSettingsSlice(
        _ settingsSlice: PianoPanelSettingsSlice
    ) -> PianoPanelState {
        var nextState = self
        nextState.rowCount = settingsSlice.rowCount
        nextState.movementScope = settingsSlice.movementScope
        nextState.whiteKeyStyle = settingsSlice.whiteKeyStyle
        nextState.snapEnabled = settingsSlice.snapEnabled
        return nextState
    }
}

struct PianoPanelSettingsSlice: Equatable, Sendable {
    var rowCount: Int
    var movementScope: PianoMovementScope
    var whiteKeyStyle: PianoWhiteKeyStyle
    var snapEnabled: Bool

    init(
        panelState: PianoPanelState
    ) {
        self.init(
            rowCount: panelState.rowCount,
            movementScope: panelState.movementScope,
            whiteKeyStyle: panelState.whiteKeyStyle,
            snapEnabled: panelState.snapEnabled
        )
    }
}
```

### 1.2 `PianoSurfaceDefaults.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoSurfaceDefaults.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；exercise controller 自己维护一套 piano demo 默认 configuration/rows，play 路径也还没有独立默认值来源。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoSurfaceDefaults.swift
// 函数名: PianoSurfaceDefaults / PianoSurfaceChromeStyle
// 功能说明: 修改后把钢琴默认 configuration、默认 rows、推导出的 panelState，以及根容器可直接复用的 sharedSettings 全部收口到共享文件；同时定义 plain/card 两种 surface 外壳样式。
enum PianoSurfaceDefaults {
    static let configuration = PianoConfiguration(
        whiteKeyWidth: 30,
        rowHeight: 216,
        rowSpacing: 10,
        scaleAreaHeight: 28,
        buttonAreaWidth: 30,
        blackKeyWidthRatio: 0.62,
        blackKeyHeightRatio: 0.6,
        whiteKeyStyle: .borderlessSeparatedByGaps,
        snapEnabled: true
    )

    static let rows: [PianoRowState] = [
        PianoRowState(
            startNote: NotePitch(pitchClass: .c, octave: 5),
            movementScope: .cascade
        ),
        PianoRowState(
            startNote: NotePitch(pitchClass: .c, octave: 4),
            movementScope: .cascade
        ),
        PianoRowState(
            startNote: NotePitch(pitchClass: .fSharp, octave: 3),
            movementScope: .rowOnly
        )
    ]

    static let panelState = PianoPanelState.inferred(
        configuration: configuration,
        rows: rows
    )

    static let sharedSettings = PianoPanelSettingsSlice(
        panelState: panelState
    )
}

enum PianoSurfaceChromeStyle: Equatable, Sendable {
    case plain
    case card
}
```

---

## 2. 新增平台钢琴 surface 宿主

### 2.1 `iOSPianoSurfaceView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；iOS 侧只有底层的 iOSPianoKeyboardView，controller 需要自己拼接外层容器、默认配置和 settings 同步逻辑。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift
// 函数名: applySharedSettings(_:) / applyPanelState()
// 功能说明: 修改后新增 iOS 平台的钢琴宿主 view，把 keyboard、panelState、chrome 风格和 rows 变更回写收口到一个可复用组件；exercise/play 两条页面都直接复用它。
final class iOSPianoSurfaceView: UIView {
    private let chromeStyle: PianoSurfaceChromeStyle
    private let baseConfiguration: PianoConfiguration
    private var baseRows: [PianoRowState]

    var panelState: PianoPanelState {
        didSet {
            guard oldValue != panelState else {
                return
            }

            applyPanelState()
        }
    }

    var isPianoInteractionEnabled = true {
        didSet {
            guard oldValue != isPianoInteractionEnabled else {
                return
            }

            pianoKeyboardView.isUserInteractionEnabled = isPianoInteractionEnabled
        }
    }

    func applySharedSettings(_ settingsSlice: PianoPanelSettingsSlice) {
        panelState = panelState.applyingSettingsSlice(settingsSlice)
    }
}

private extension iOSPianoSurfaceView {
    func applyPanelState() {
        pianoKeyboardView.configuration = resolvedConfiguration
        pianoKeyboardView.rows = resolvedRows
        pianoKeyboardView.showsComponentBoundsOverlay = showsComponentBoundsOverlay
        pianoKeyboardView.isUserInteractionEnabled = isPianoInteractionEnabled
        invalidateIntrinsicContentSize()
    }
}
```

### 2.2 `macOSPianoSurfaceView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；macOS 侧同样没有统一的钢琴 surface 宿主，controller 只能自己维护 keyboard 容器和平台差异。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift
// 函数名: applySharedSettings(_:) / applyPanelState()
// 功能说明: 修改后新增 macOS 平台的钢琴宿主 view；由于 NSView 没有 UIKit 那样的 isUserInteractionEnabled，这里额外加了 interactionBlockerView 来实现 play/exercise 对钢琴交互开关的统一控制。
final class macOSPianoSurfaceView: NSView {
    private let chromeStyle: PianoSurfaceChromeStyle
    private let baseConfiguration: PianoConfiguration
    private var baseRows: [PianoRowState]
    private let interactionBlockerView = NSView()

    var isPianoInteractionEnabled = true {
        didSet {
            guard oldValue != isPianoInteractionEnabled else {
                return
            }

            interactionBlockerView.isHidden = isPianoInteractionEnabled
        }
    }

    func applySharedSettings(_ settingsSlice: PianoPanelSettingsSlice) {
        panelState = panelState.applyingSettingsSlice(settingsSlice)
    }
}

private extension macOSPianoSurfaceView {
    func configureView() {
        // ... 其它布局代码 ...
        addSubview(pianoKeyboardView)
        interactionBlockerView.translatesAutoresizingMaskIntoConstraints = false
        interactionBlockerView.wantsLayer = true
        interactionBlockerView.layer?.backgroundColor = NSColor.clear.cgColor
        interactionBlockerView.isHidden = isPianoInteractionEnabled
        addSubview(interactionBlockerView)
    }

    func applyPanelState() {
        pianoKeyboardView.configuration = resolvedConfiguration
        pianoKeyboardView.rows = resolvedRows
        pianoKeyboardView.showsComponentBoundsOverlay = showsComponentBoundsOverlay
        interactionBlockerView.isHidden = isPianoInteractionEnabled
        invalidateIntrinsicContentSize()
    }
}
```

---

## 3. 新增独立 `play` 页面壳层

### 3.1 `iOSPlayViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；iOS 侧没有真正的 play page，root shell 切到 play 时只会显示一个 placeholder 文案。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: settingsPanelStateContext / configureLayout() / handleSettingsPanelEvent(_:)
// 功能说明: 修改后新增 iOS play controller：页面主体只放 pianoSurfaceView，通过 PlayModeState 生成 presentation，并用 settings 中的 root mode action 回切 exercise。
final class iOSPlayViewController: UIViewController {
    private var pianoPanelState = PianoSurfaceDefaults.panelState
    private var playModeState = PlayModeState.default

    var onRootModeChangeRequest: ((RootMode) -> Void)?

    private lazy var pianoSurfaceView = iOSPianoSurfaceView(
        chromeStyle: .plain,
        panelState: pianoPanelState
    )

    private var settingsPanelStateContext: SettingsPanelStateContext {
        SettingsPanelStateContext(
            rootMode: .play,
            pianoPanelState: pianoPanelState,
            playModeState: playModeState
        )
    }

    func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
        var nextStateContext = settingsPanelStateContext
        event.apply(to: &nextStateContext)

        if nextStateContext.rootMode != .play {
            setSettingsPresented(false)
            onRootModeChangeRequest?(nextStateContext.rootMode)
            return
        }

        pianoPanelState = nextStateContext.pianoPanelState
        playModeState = nextStateContext.playModeState
    }
}
```

### 3.2 `macOSPlayViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；macOS 侧也还没有真正的 play page，root shell 只能显示 placeholder。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift
// 函数名: settingsPanelStateContext / configureLayout() / handleSettingsPanelEvent(_:)
// 功能说明: 修改后新增 macOS play controller，结构与 iOS 对齐：scrollView + pianoSurfaceView + settings 容器，页面只承载 piano，不再复用 exercise 页面树。
final class macOSPlayViewController: NSViewController {
    private var pianoPanelState = PianoSurfaceDefaults.panelState
    private var playModeState = PlayModeState.default

    var onRootModeChangeRequest: ((RootMode) -> Void)?

    private lazy var pianoSurfaceView = macOSPianoSurfaceView(
        chromeStyle: .plain,
        panelState: pianoPanelState
    )

    private var settingsPanelStateContext: SettingsPanelStateContext {
        SettingsPanelStateContext(
            rootMode: .play,
            pianoPanelState: pianoPanelState,
            playModeState: playModeState
        )
    }

    func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
        var nextStateContext = settingsPanelStateContext
        event.apply(to: &nextStateContext)

        if nextStateContext.rootMode != .play {
            setSettingsPresented(false)
            onRootModeChangeRequest?(nextStateContext.rootMode)
            return
        }

        pianoPanelState = nextStateContext.pianoPanelState
        playModeState = nextStateContext.playModeState
    }
}
```

---

## 4. 根容器从 placeholder 切到真实 play controller

### 4.1 `iOSRootViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift
// 函数名: viewController(for:)
// 功能说明: 修改前 iOS root shell 虽然已经有 RootMode，但 play 侧仍然只是一个 placeholder controller；切到 play 并不会进入真正的 piano-only 页面。
final class iOSRootViewController: UIViewController {
    private let exerciseViewController = iOSViewController()
    private let playPlaceholderViewController = iOSModePlaceholderViewController(
        titleText: "Play mode is not available yet."
    )

    func viewController(for rootMode: RootMode) -> UIViewController {
        switch rootMode {
        case .exercise:
            return exerciseViewController
        case .play:
            return playPlaceholderViewController
        }
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift
// 函数名: configureChildControllers() / setRootMode(_:) / syncSharedPianoSettingsFromCurrentMode()
// 功能说明: 修改后 iOS root shell 直接托管真实的 play controller，并在 mode 切换前后同步 sharedPianoSettings，让 exercise/play 两端的 rows/style/snap 保持一致。
final class iOSRootViewController: UIViewController {
    private let exerciseViewController = iOSViewController()
    private let playViewController = iOSPlayViewController()
    private var sharedPianoSettings = PianoSurfaceDefaults.sharedSettings

    func setRootMode(_ rootMode: RootMode) {
        guard self.rootMode != rootMode || currentViewController == nil else {
            return
        }

        syncSharedPianoSettingsFromCurrentMode()
        applySharedPianoSettingsToChildren()
        self.rootMode = rootMode
        guard isViewLoaded else {
            return
        }

        applyRootMode(rootMode)
    }
}

private extension iOSRootViewController {
    func configureChildControllers() {
        exerciseViewController.onRootModeChangeRequest = { [weak self] rootMode in
            self?.setRootMode(rootMode)
        }
        playViewController.onRootModeChangeRequest = { [weak self] rootMode in
            self?.setRootMode(rootMode)
        }
        applySharedPianoSettingsToChildren()
    }

    func viewController(for rootMode: RootMode) -> UIViewController {
        switch rootMode {
        case .exercise:
            return exerciseViewController
        case .play:
            return playViewController
        }
    }
}
```

### 4.2 `macOSRootViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift
// 函数名: viewController(for:)
// 功能说明: 修改前 macOS root shell 也只把 play 路径指向 placeholder；根模式虽然存在，但 play 页面壳层尚未落地。
final class macOSRootViewController: NSViewController {
    private let exerciseViewController = macOSViewController()
    private let playPlaceholderViewController = macOSModePlaceholderViewController(
        titleText: "Play mode is not available yet."
    )

    func viewController(for rootMode: RootMode) -> NSViewController {
        switch rootMode {
        case .exercise:
            return exerciseViewController
        case .play:
            return playPlaceholderViewController
        }
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift
// 函数名: configureChildControllers() / setRootMode(_:) / syncSharedPianoSettingsFromCurrentMode()
// 功能说明: 修改后 macOS root shell 与 iOS 对齐：play 路径切到真实 macOSPlayViewController，并在 child controller 之间同步 shared piano settings。
final class macOSRootViewController: NSViewController {
    private let exerciseViewController = macOSViewController()
    private let playViewController = macOSPlayViewController()
    private var sharedPianoSettings = PianoSurfaceDefaults.sharedSettings

    func setRootMode(_ rootMode: RootMode) {
        guard self.rootMode != rootMode || currentViewController == nil else {
            return
        }

        syncSharedPianoSettingsFromCurrentMode()
        applySharedPianoSettingsToChildren()
        self.rootMode = rootMode
        guard isViewLoaded else {
            return
        }

        applyRootMode(rootMode)
    }
}

private extension macOSRootViewController {
    func configureChildControllers() {
        exerciseViewController.onRootModeChangeRequest = { [weak self] rootMode in
            self?.setRootMode(rootMode)
        }
        playViewController.onRootModeChangeRequest = { [weak self] rootMode in
            self?.setRootMode(rootMode)
        }
        applySharedPianoSettingsToChildren()
    }
}
```

---

## 5. exercise controller 不再手搓 piano demo 容器

### 5.1 `iOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: exerciseSceneRenderer / pianoKeyboardView / applyPianoDemoState() / handlePianoDemoPreviewStarted(...)
// 功能说明: 修改前 iOS exercise controller 直接持有 piano demo 容器、标题、状态文案和 keyboard view；scene renderer 拿到的其实是这整个 demo card，本质上仍是 exercise accessory 语义。
private let pianoDemoContainerView = UIView()

private lazy var exerciseSceneRenderer = iOSExerciseSceneRenderer(
    // ... 省略其它参数 ...
    pianoAccessoryView: pianoDemoContainerView,
    fretboardView: fretboardView
)

private lazy var pianoDemoTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "Piano Keyboard Demo"
    return label
}()

private lazy var pianoDemoStatusLabel: UILabel = {
    let label = UILabel()
    label.text = ""
    return label
}()

private lazy var pianoKeyboardView: iOSPianoKeyboardView = {
    let pianoKeyboardView = iOSPianoKeyboardView(
        configuration: resolvedPianoDemoConfiguration,
        rows: resolvedPianoDemoRows
    )
    pianoKeyboardView.onPreviewStarted = { [weak self] preview in
        self?.handlePianoDemoPreviewStarted(preview)
    }
    return pianoKeyboardView
}()

private func applyPianoDemoState() {
    pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
    pianoKeyboardView.rows = resolvedPianoDemoRows
    pianoKeyboardView.showsComponentBoundsOverlay = false
    updatePianoDemoStatusLabel()
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: pianoAccessorySurfaceView / currentPianoSettingsSlice / applySharedPianoSettings(_:) / applyPianoAccessoryState() / handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS exercise controller 不再自己拼 demo card，而是直接复用 iOSPianoSurfaceView；同时新增 root mode 回切入口与 shared piano settings 接口，让 root shell 能在 exercise/play 之间同步钢琴配置。
private static let initialPianoPanelState = PianoSurfaceDefaults.panelState

private var pianoPanelState = iOSViewController.initialPianoPanelState
var onRootModeChangeRequest: ((RootMode) -> Void)?

private lazy var exerciseSceneRenderer = iOSExerciseSceneRenderer(
    // ... 省略其它参数 ...
    pianoAccessoryView: pianoAccessorySurfaceView,
    fretboardView: fretboardView
)

private lazy var pianoAccessorySurfaceView = iOSPianoSurfaceView(
    chromeStyle: .card,
    panelState: pianoPanelState
)

var currentPianoSettingsSlice: PianoPanelSettingsSlice {
    pianoPanelState.settingsSlice
}

func applySharedPianoSettings(_ settingsSlice: PianoPanelSettingsSlice) {
    let nextPianoPanelState = pianoPanelState.applyingSettingsSlice(
        settingsSlice
    )
    guard nextPianoPanelState != pianoPanelState else {
        return
    }

    pianoPanelState = nextPianoPanelState
    if isViewLoaded {
        applyPianoAccessoryState()
        applySettingsPanelState()
        synchronizeExerciseCompositionState(
            reason: "sharedPianoSettingsChanged"
        )
    }
}

private func applyPianoAccessoryState() {
    pianoAccessorySurfaceView.applySharedSettings(
        pianoPanelState.settingsSlice
    )
    pianoAccessorySurfaceView.showsComponentBoundsOverlay = false
    updateLayoutIfNeeded()
    exerciseSceneRenderer.handleLayoutPass()
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)

    if nextStateContext.rootMode != .exercise {
        setSettingsPresented(false)
        onRootModeChangeRequest?(nextStateContext.rootMode)
        return
    }

    // ... 后续仍按 exercise 路径处理 state sync ...
}
```

### 5.2 `macOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: exerciseSceneRenderer / pianoKeyboardView / applyPianoDemoState()
// 功能说明: 修改前 macOS exercise controller 同样内嵌了一套 piano demo card；renderer 拿到的是 demo 容器，而不是可复用的钢琴 surface 宿主。
private let pianoDemoContainerView = NSView()

private lazy var exerciseSceneRenderer = macOSExerciseSceneRenderer(
    // ... 省略其它参数 ...
    pianoAccessoryView: pianoDemoContainerView,
    fretboardView: fretboardView
)

private lazy var pianoKeyboardView: macOSPianoKeyboardView = {
    let pianoKeyboardView = macOSPianoKeyboardView(
        configuration: resolvedPianoDemoConfiguration,
        rows: resolvedPianoDemoRows
    )
    return pianoKeyboardView
}()

private func applyPianoDemoState() {
    pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
    pianoKeyboardView.rows = resolvedPianoDemoRows
    pianoKeyboardView.showsComponentBoundsOverlay = false
    updatePianoDemoStatusLabel()
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: pianoAccessorySurfaceView / currentPianoSettingsSlice / applySharedPianoSettings(_:) / handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS exercise controller 也切到 macOSPianoSurfaceView；根容器可通过 shared settings 同步钢琴配置，settings 中切 rootMode 时 controller 会把切换请求抛回 root shell。
private static let initialPianoPanelState = PianoSurfaceDefaults.panelState

private var pianoPanelState = macOSViewController.initialPianoPanelState {
    didSet {
        invalidatePianoPanelPresentation()
    }
}
var onRootModeChangeRequest: ((RootMode) -> Void)?

private lazy var exerciseSceneRenderer = macOSExerciseSceneRenderer(
    // ... 省略其它参数 ...
    pianoAccessoryView: pianoAccessorySurfaceView,
    fretboardView: fretboardView
)

private lazy var pianoAccessorySurfaceView = macOSPianoSurfaceView(
    chromeStyle: .card,
    panelState: pianoPanelState
)

var currentPianoSettingsSlice: PianoPanelSettingsSlice {
    pianoPanelState.settingsSlice
}

func applySharedPianoSettings(_ settingsSlice: PianoPanelSettingsSlice) {
    let nextPianoPanelState = pianoPanelState.applyingSettingsSlice(
        settingsSlice
    )
    guard nextPianoPanelState != pianoPanelState else {
        return
    }

    pianoPanelState = nextPianoPanelState
    if isViewLoaded {
        applySettingsPanelState()
        synchronizeExerciseCompositionState(
            reason: "sharedPianoSettingsChanged"
        )
    }
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)

    if nextStateContext.rootMode != .exercise {
        setSettingsPresented(false)
        onRootModeChangeRequest?(nextStateContext.rootMode)
        return
    }

    // ... 后续仍保留 macOS 的 presentation transaction 提交流程 ...
}
```

补充说明：`macOSViewController` 里 `PendingPresentationTransaction.pianoDemoState` 这个字段名这轮没有一起重命名，但它现在触发刷新的对象已经变成了 `pianoAccessorySurfaceView`，不再承载旧的 demo 文案/状态标签语义。

---

## 6. settings / navigation 接入根模式切换

### 6.1 `SettingsPanelModel.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.orderedVisibleSections(for:) / SettingsChoiceRowID / SettingsActionID
// 功能说明: 修改前 settings 已能按 rootMode 过滤 section，但 play root 只剩 Piano；模型层里没有公共 Mode section，也没有 rootMode 选择行和 setRootModeExercise / setRootModePlay 这类 action。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case exercise
    case positionPrompt
    case accessories
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    static func orderedVisibleSections(
        for rootMode: RootMode
    ) -> [SettingsSectionID] {
        switch rootMode {
        case .exercise:
            return allCases
        case .play:
            return [
                .piano
            ]
        }
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID / SettingsChoiceRowID.rootMode / SettingsActionID.setRootModeExercise|setRootModePlay
// 功能说明: 修改后 settings 增加公共 Mode 分区与 rootMode 选择行；play 模式的 root 现在保留 Mode + Piano 两块，控制器可以直接通过 settings action 切换 exercise/play。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case mode
    case exercise
    case positionPrompt
    case accessories
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    static func orderedVisibleSections(
        for rootMode: RootMode
    ) -> [SettingsSectionID] {
        switch rootMode {
        case .exercise:
            return [.mode] + allCases
        case .play:
            return [
                .mode,
                .piano
            ]
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case rootMode
    case exerciseMode
    // ...

    var actionIDs: [SettingsActionID] {
        switch self {
        case .rootMode:
            return [
                .setRootModeExercise,
                .setRootModePlay
            ]
        case .exerciseMode:
            return [
                .setExerciseModeSingle,
                .setExerciseModeSequence,
                .setExerciseModePositionPrompt
            ]
        // ...
        }
    }
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setRootModeExercise
    case setRootModePlay
    case setExerciseModeSingle
    // ...

    func apply(to stateContext: inout SettingsPanelStateContext) {
        switch self {
        case .setRootModeExercise:
            stateContext.rootMode = .exercise
        case .setRootModePlay:
            stateContext.rootMode = .play
        default:
            break
        }

        apply(to: &stateContext.fretboardDisplayState)
        apply(to: &stateContext.staffDisplayState)
        apply(to: &stateContext.exerciseLayoutPreferences)
        apply(to: &stateContext.trainerDisplayState)
        apply(to: &stateContext.pianoPanelState)
        stateContext.reconcileForCurrentMode()
    }
}
```

### 6.2 `SettingsNavigationSnapshotBuilder.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: childPageSpecs(for:)
// 功能说明: 修改前 navigation builder 没有公共 Mode section；play root 只有 Piano，所以所有 section 要么拆 child pages，要么直接 form page。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    case .exercise:
        return [
            // ...
        ]
    case .piano:
        return [
            ChildPageSpec(
                route: .pianoBehavior,
                title: SettingsRouteID.pianoBehavior.fallbackTitle,
                subtitle: "Rows and movement",
                rowIDs: [
                    .slider(.pianoRowCount),
                    .choice(.pianoMovementScope),
                    .toggle(.pianoSnapEnabled)
                ]
            )
        ]
    case .layout, .debug:
        return nil
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: childPageSpecs(for:)
// 功能说明: 修改后明确把 Mode section 视为“直接 form page”，不再拆子页；这样 play root 可以稳定呈现 `Mode / Piano` 两个入口，其中 Mode 直接承载 rootMode 选择行。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    case .mode:
        return nil
    case .exercise:
        return [
            ChildPageSpec(
                route: .exerciseMode,
                title: SettingsRouteID.exerciseMode.fallbackTitle,
                subtitle: "Single, sequence, or position",
                rowIDs: [
                    .choice(.exerciseMode),
                    .positionFilter(.positionQuestionPitchClasses)
                ]
            )
            // ... 其它 child pages 保持不变 ...
        ]
    case .piano:
        return [
            ChildPageSpec(
                route: .pianoBehavior,
                title: SettingsRouteID.pianoBehavior.fallbackTitle,
                subtitle: "Rows and movement",
                rowIDs: [
                    .slider(.pianoRowCount),
                    .choice(.pianoMovementScope),
                    .toggle(.pianoSnapEnabled)
                ]
            )
            // ...
        ]
    case .layout, .debug:
        return nil
    }
}
```

### 6.3 `SettingsNavigationValidation.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: manualChecklist(for:) / validatePlayRootTreeKeepsOnlyPianoPages() / validateRootModeSwitchPreservesExerciseTreeAndState()
// 功能说明: 修改前 validation 的 play 路径仍假设 root 只剩 Piano；模式切换校验也是直接改 stateContext.rootMode 字段，还没有覆盖新的 settings rootMode action。
static func manualChecklist(
    for platform: SettingsNavigationValidationPlatform
) -> [String] {
    [
        "确认切到 `play` mode 的 settings 后，root 只保留 `Piano` 分区，不再暴露 `Exercise / Accessories / Fretboard / Staff / Debug`。",
        "确认从 `exercise` 切到 `play` 再切回后，原来的 exercise mode、layout preset 和 piano rows / snap 之类的设置不会丢失。"
    ]
}

if panelModel.sections.map(\.id) != [.piano] {
    issues.append(
        issue(
            fixtureName,
            "play mode 的 root sections 应只保留 Piano。"
        )
    )
}

var playStateContext = exerciseStateContext
playStateContext.rootMode = .play
playStateContext.reconcileForCurrentMode()
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: manualChecklist(for:) / validateSplitSectionsProduceExpectedPageTree() / validatePlayRootTreeKeepsOnlyPianoPages() / validateRootModeSwitchPreservesExerciseTreeAndState()
// 功能说明: 修改后 validation 全面接入新的公共 Mode section：exercise root 期望是 Mode + Exercise/...，play root 期望是 Mode + Piano；同时根模式切换改为真正走 settings action，确保新入口也被自动回归覆盖到。
static func manualChecklist(
    for platform: SettingsNavigationValidationPlatform
) -> [String] {
    [
        "确认切到 `play` mode 的 settings 后，root 只保留 `Mode / Piano` 分区，不再暴露 `Exercise / Accessories / Fretboard / Staff / Debug`。",
        "确认从 `exercise` 切到 `play` 再切回后，原来的 exercise mode、layout preset 和 piano rows / snap 之类的设置不会丢失。"
    ]
}

guard let modeSection = resolveSection(.mode, in: panelModel) else {
    issues.append(issue(fixtureName, "play mode 下应保留 Mode section。"))
    return issues
}
guard let pianoSection = resolveSection(.piano, in: panelModel) else {
    issues.append(issue(fixtureName, "play mode 下应保留 Piano section。"))
    return issues
}

if panelModel.sections.map(\.id) != [.mode, .piano] {
    issues.append(
        issue(
            fixtureName,
            "play mode 的 root sections 应只保留 Mode 与 Piano。"
        )
    )
}

if rootRouteItems != [
    SettingsRouteItem(
        title: modeSection.title,
        subtitle: nil,
        route: .section(.mode)
    ),
    SettingsRouteItem(
        title: pianoSection.title,
        subtitle: nil,
        route: .section(.piano)
    )
] {
    issues.append(
        issue(
            fixtureName,
            "play mode root route 应只包含 Mode 与 Piano 入口。"
        )
    )
}

var playStateContext = exerciseStateContext
SettingsPanelEvent.triggerAction(.setRootModePlay).apply(
    to: &playStateContext
)

var restoredExerciseStateContext = playStateContext
SettingsPanelEvent.triggerAction(.setRootModeExercise).apply(
    to: &restoredExerciseStateContext
)
```

---

## 7. 验证结果

本轮修改完成后，额外做了以下验证：

- 使用 `ReadLints` 检查本轮涉及文件，无新增诊断。
- iOS Debug 构建通过：
  `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`
- macOS Debug 构建通过：
  `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build CODE_SIGNING_ALLOWED=NO`

本轮最终达成的 phase4 结果：

- 根容器已能在 `exercise` 与 `play` 间稳定切换。
- `play` 页面只显示钢琴，不再借道 exercise accessory 容器。
- exercise/play 两条路径复用同一套钢琴 surface 宿主与共享钢琴设置切片。
- settings 已新增公共 `Mode` 入口，`play` 模式下 root 只保留 `Mode / Piano`。

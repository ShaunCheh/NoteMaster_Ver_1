20260320_154728_phase1_display_state_normalization

# 原生按钮组件阶段 1 修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`

## 修改前

### 共享层还没有统一承载展示状态的文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数名：无（文件不存在）
// 功能说明：修改前项目里还没有专门承载 configuration、visibility、spelling、showsOctave 的共享展示状态文件，
// 因此控制器层只能分别持有多个独立属性，后续按钮接入时也没有单一状态源可以统一回写。
// 该文件在修改前不存在。
```

### iOS 控制器分别持有配置和 provider，还没有统一状态入口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：fretboardConfiguration, noteContentProvider, fretboardView
// 功能说明：修改前 iOS 控制器把指板配置和音名 provider 分开保存，并在创建视图时直接注入；
// 这样虽然能显示内容，但没有“状态变更 -> 统一刷新”的入口，不适合后续按钮驱动。
final class iOSViewController: UIViewController {
    private let fretboardConfiguration = FretboardConfiguration(
        tuning: .standard(for: .guitar6),
        maxFret: 12,
        preferredHeight: 180
    )
    private let noteContentProvider = NoteNameContentProvider(
        visibility: .all,
        spelling: .sharp,
        showsOctave: true
    )
    private lazy var fretboardView: iOSFretboardView = {
        let fretboardView = iOSFretboardView(configuration: fretboardConfiguration)
        fretboardView.contentProvider = noteContentProvider
        return fretboardView
    }()
}
```

### macOS 控制器也采用相同的分散状态模式

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：fretboardConfiguration, noteContentProvider, fretboardView
// 功能说明：修改前 macOS 控制器与 iOS 控制器一致，配置和 provider 分别存放，
// 高度约束也只读取初始配置值，后续如果状态改变，没有统一入口负责同步视图和约束。
final class macOSViewController: NSViewController {
    private let fretboardConfiguration = FretboardConfiguration(
        tuning: .standard(for: .guitar6),
        maxFret: 12,
        preferredHeight: 180
    )
    private let noteContentProvider = NoteNameContentProvider(
        visibility: .all,
        spelling: .sharp,
        showsOctave: true
    )
    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: fretboardConfiguration)
        fretboardView.contentProvider = noteContentProvider
        return fretboardView
    }()
}
```

## 修改后

### 新增共享展示状态 `FretboardDisplayState`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数名：default, contentProvider
// 功能说明：新增统一展示状态，把 configuration、visibility、spelling、showsOctave 收敛为单一真相来源；
// 同时通过 contentProvider 计算属性，从共享状态派生 NoteNameContentProvider，避免控制器重复拼装。
import CoreGraphics

struct FretboardDisplayState: Equatable, Sendable {
    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool

    static let `default` = FretboardDisplayState(
        configuration: FretboardConfiguration(
            tuning: .standard(for: .guitar6),
            maxFret: 12,
            preferredHeight: 180
        )
    )

    var contentProvider: NoteNameContentProvider {
        NoteNameContentProvider(
            visibility: visibility,
            spelling: spelling,
            showsOctave: showsOctave
        )
    }
}
```

### iOS 控制器改为只维护 `displayState`，并通过 `applyDisplayState()` 统一投射

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：displayState, configureFretboardView(), applyDisplayState()
// 功能说明：iOS 控制器改为只持有 displayState；状态变化时统一刷新 fretboardView 的 configuration、
// contentProvider 和高度约束，为后续按钮动作只改 displayState 打下基础。
final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }
    private var fretboardHeightConstraint: NSLayoutConstraint?

    private lazy var fretboardView: iOSFretboardView = {
        let fretboardView = iOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { hitResult in
            print(hitResult.debugSummary(platform: "iOS"))
        }
        return fretboardView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureFretboardView()
        applyDisplayState()
    }

    private func applyDisplayState() {
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardHeightConstraint?.constant = displayState.configuration.preferredHeight
    }
}
```

### macOS 控制器同步收敛到同一套状态刷新模式

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：displayState, configureFretboardView(), applyDisplayState()
// 功能说明：macOS 控制器与 iOS 保持同构，统一改成“状态变化 -> applyDisplayState -> 视图刷新”的链路，
// 从根因上避免后续按钮逻辑在两个平台控制器里各写一套状态同步代码。
final class macOSViewController: NSViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }
    private var fretboardHeightConstraint: NSLayoutConstraint?

    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { hitResult in
            print(hitResult.debugSummary(platform: "macOS"))
        }
        return fretboardView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureFretboardView()
        applyDisplayState()
    }

    private func applyDisplayState() {
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardHeightConstraint?.constant = displayState.configuration.preferredHeight
    }
}
```

### 控制器层的职责边界发生了收敛

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift, NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：applyDisplayState()
// 功能说明：阶段 1 后，控制器层不再分别管理“配置对象”和“provider 对象”的散装状态，
// 而是统一维护 displayState，并通过单一函数把共享状态投射到平台视图与约束。
private func applyDisplayState() {
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardHeightConstraint?.constant = displayState.configuration.preferredHeight
}
```

## 结果说明

- 阶段 1 的核心结果是把指板页面现有的展示配置收敛成单一状态源 `FretboardDisplayState`。
- 后续按钮组件接入时，只需要修改 `displayState`，再复用 `applyDisplayState()`，不需要在 iOS/macOS 分别维护多处状态同步逻辑。
- 本次没有修改 `iOSFretboardView`、`macOSFretboardView`、`FretboardConfiguration`、`NoteNameContentProvider` 的内部实现，只调整了共享状态承载和控制器装配方式。
- 已使用系统 `date` 生成时间戳 `20260320_154728` 作为本记录文件前缀。
- 已执行构建验证：`DEVELOPER_DIR=\"/Applications/Xcode.app/Contents/Developer\" xcodebuild -project \"NoteMaster_Ver_1.xcodeproj\" -scheme \"NoteMaster_Ver_1\" -destination \"generic/platform=macOS\" build` 与 `generic/platform=iOS Simulator` 均通过。

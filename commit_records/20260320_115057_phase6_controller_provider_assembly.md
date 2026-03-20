20260320_115057_phase6_controller_provider_assembly

# 阶段 6 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `iOSFretboardView.swift`
- 未修改 `macOSFretboardView.swift`
- 未修改 `FretboardLayer.swift`
- 未修改 `FretboardContentProvider.swift`
- 未修改 `NoteNameContentProvider.swift`

## 修改前

### iOS 控制器尚未装配音名 provider

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：fretboardConfiguration, fretboardView
// 功能说明：修改前 iOS 控制器只配置了默认调弦和指板视图，还没有持有或注入 NoteNameContentProvider，因此音名链路没有从控制器打通。
final class iOSViewController: UIViewController {
    private let fretboardConfiguration = FretboardConfiguration(
        tuning: .standard(for: .guitar6),
        maxFret: 12,
        preferredHeight: 180
    )
    private lazy var fretboardView = iOSFretboardView(configuration: fretboardConfiguration)
}
```

### macOS 控制器尚未装配音名 provider

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：fretboardConfiguration, fretboardView
// 功能说明：修改前 macOS 控制器同样只配置了默认调弦和指板视图，没有向包装视图注入 contentProvider。
final class macOSViewController: NSViewController {
    private let fretboardConfiguration = FretboardConfiguration(
        tuning: .standard(for: .guitar6),
        maxFret: 12,
        preferredHeight: 180
    )
    private lazy var fretboardView = macOSFretboardView(configuration: fretboardConfiguration)
}
```

## 修改后

### iOS 控制器装配默认音名 provider

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：noteContentProvider, fretboardView
// 功能说明：iOS 控制器新增默认的 NoteNameContentProvider，并在创建指板视图时把它注入到包装视图，打通音名显示链路。
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

### macOS 控制器装配默认音名 provider

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：noteContentProvider, fretboardView
// 功能说明：macOS 控制器新增默认的 NoteNameContentProvider，并在创建指板视图时把它注入到包装视图，打通音名显示链路。
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

### 控制器层职责变化

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift, NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：noteContentProvider, fretboardView
// 功能说明：阶段 6 后，控制器层开始承担“装配默认音名显示策略”的职责，但仍不实现任何音名推导算法，只负责创建 provider 并下发。
private let noteContentProvider = NoteNameContentProvider(
    visibility: .all,
    spelling: .sharp,
    showsOctave: true
)

private lazy var fretboardView = {
    let fretboardView = /* 平台包装视图 */
    fretboardView.contentProvider = noteContentProvider
    return fretboardView
}()
```

## 结果说明

- 阶段 6 的核心结果是把默认的 `NoteNameContentProvider` 正式装配进 iOS 和 macOS 控制器。
- 这样控制器、包装视图、共享渲染层之间的音名显示链路已经完整打通。
- 当前默认策略是：显示自然音和变化音、使用升号拼写、显示八度。
- 本次没有修改 provider 本身，也没有把音名推导逻辑回流到控制器层。

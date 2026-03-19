20260319_214430_phase5_controller_integration

# 阶段 5 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `iOSFretboardView.swift`
- 未修改 `macOSFretboardView.swift`
- 未修改共享层 `FretboardConfiguration.swift`、`FretboardGeometry.swift`、`FretboardLayer.swift`

## 修改前

### iOS 控制器仍然是占位标签

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：viewDidLoad(), configureHelloLabel()
// 功能说明：修改前 iOS 控制器只是在页面中心放了一个 hello world 标签，还没有接入指板组件。
final class iOSViewController: UIViewController {
    private let helloLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureHelloLabel()
    }

    private func configureHelloLabel() {
        helloLabel.translatesAutoresizingMaskIntoConstraints = false
        helloLabel.text = "hello world"
        helloLabel.font = .systemFont(ofSize: 32, weight: .semibold)
        helloLabel.textColor = .label
        helloLabel.textAlignment = .center

        view.addSubview(helloLabel)

        NSLayoutConstraint.activate([
            helloLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helloLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
```

### macOS 控制器仍然是占位标签

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：viewDidLoad(), configureHelloLabel()
// 功能说明：修改前 macOS 控制器同样只是在页面中心放了一个 Hello world 标签，还没有接入指板组件。
final class macOSViewController: NSViewController {
    private let helloLabel = NSTextField(labelWithString: "Hello world")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureHelloLabel()
    }

    private func configureHelloLabel() {
        helloLabel.translatesAutoresizingMaskIntoConstraints = false
        helloLabel.font = .systemFont(ofSize: 32, weight: .semibold)
        helloLabel.textColor = .labelColor
        helloLabel.alignment = .center

        view.addSubview(helloLabel)

        NSLayoutConstraint.activate([
            helloLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helloLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
```

## 修改后

### iOS 控制器接入指板组件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：viewDidLoad(), configureFretboardView()
// 功能说明：iOS 控制器改为创建 FretboardConfiguration 和 iOSFretboardView，并把组件横向贴满 safeArea、纵向居中、高度取配置值。
final class iOSViewController: UIViewController {
    private let fretboardConfiguration = FretboardConfiguration(
        instrument: .guitar6,
        maxFret: 12,
        preferredHeight: 180
    )
    private lazy var fretboardView = iOSFretboardView(configuration: fretboardConfiguration)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureFretboardView()
    }

    private func configureFretboardView() {
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide
        let heightConstraint = fretboardView.heightAnchor.constraint(
            equalToConstant: fretboardConfiguration.preferredHeight
        )

        NSLayoutConstraint.activate([
            fretboardView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            fretboardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
            heightConstraint
        ])
    }
}
```

### macOS 控制器接入指板组件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：viewDidLoad(), configureFretboardView()
// 功能说明：macOS 控制器改为创建 FretboardConfiguration 和 macOSFretboardView，并把组件横向贴满宿主 view、纵向居中、高度取配置值。
final class macOSViewController: NSViewController {
    private let fretboardConfiguration = FretboardConfiguration(
        instrument: .guitar6,
        maxFret: 12,
        preferredHeight: 180
    )
    private lazy var fretboardView = macOSFretboardView(configuration: fretboardConfiguration)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureFretboardView()
    }

    private func configureFretboardView() {
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fretboardView)

        let heightConstraint = fretboardView.heightAnchor.constraint(
            equalToConstant: fretboardConfiguration.preferredHeight
        )

        NSLayoutConstraint.activate([
            fretboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fretboardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            heightConstraint
        ])
    }
}
```

### 控制器职责边界变化

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift, NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：configureFretboardView()
// 功能说明：阶段 5 后，控制器职责从“展示占位文本”变成“创建组件、提供配置、施加页面约束”，不承担任何几何和绘制逻辑。
let heightConstraint = fretboardView.heightAnchor.constraint(
    equalToConstant: fretboardConfiguration.preferredHeight
)

NSLayoutConstraint.activate([
    fretboardView.leadingAnchor.constraint(equalTo: ...),
    fretboardView.trailingAnchor.constraint(equalTo: ...),
    fretboardView.centerYAnchor.constraint(equalTo: ...),
    heightConstraint
])
```

## 结果说明

- 阶段 5 的核心结果是把跨平台指板组件真正挂进了 iOS 和 macOS 的控制器页面。
- 组件宽度现在已经由上层控制器接管：iOS 贴 `safeArea` 左右边，macOS 贴宿主 `view` 左右边。
- 组件高度现在由 `FretboardConfiguration.preferredHeight` 提供，并通过控制器里的固定高度约束生效。
- 本次没有修改任何 `AppDelegate`，也没有把绘制逻辑回流到控制器层。

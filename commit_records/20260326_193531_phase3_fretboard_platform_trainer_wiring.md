# 20260326_193531_phase3_fretboard_platform_trainer_wiring

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_193531`
- 记录范围：阶段 3，双平台控制器接入共享 trainer
- 本次目标：在 `iOSViewController` 与 `macOSViewController` 的指板外层接入 `FretboardNaturalNoteTrainerState`，把原来的 raw hit 调试输出升级为结构化判题输出，并在页面加载时打印当前目标音
- 根因结论：阶段 2 已经把随机自然音、判题与切题逻辑沉到了 `Shared/Fretboard`，但平台控制器仍然沿用 `hitResult.debugSummary(...)` 的原始命中日志。这样即使共享 trainer 已存在，用户点击指板时也不会进入练习链路，更不会输出“目标音 / 点击音 / 是否正确 / 下一题”
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 在 `iOSViewController` 与 `macOSViewController` 中新增 `fretboardTrainerState`，作为平台外层唯一持有的训练状态。
2. 将 `fretboardView.onRawEvent` 的实现从 `print(hitResult.debugSummary(...))` 改为交给控制器侧的 trainer 处理函数。
3. 在 `viewDidLoad()` 中新增当前目标音打印，保证页面一打开就能知道本轮题目。
4. 在两个控制器中都新增 `handleFretboardTrainerHitResult(...)` 与 `printCurrentTrainerTarget(...)`，统一处理忽略事件、判题结果与答对后切题日志。

## 修改 1：iOS 控制器从 raw debug 输出切到 trainer 接线

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: fretboardView, viewDidLoad()
// 功能说明: 修改前 iOS 控制器并未持有 trainer 状态；
// 指板点击后只打印原始命中结果，页面加载时也不会输出当前目标音。
private var isSettingsPresented = false

private lazy var fretboardView: iOSFretboardView = {
    let fretboardView = iOSFretboardView(configuration: displayState.configuration)
    fretboardView.onRawEvent = { hitResult in
        print(hitResult.debugSummary(platform: "iOS"))
    }
    return fretboardView
}()

override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    configureLayout()
    applyDisplayState()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: fretboardTrainerState, fretboardView, viewDidLoad()
// 功能说明: 修改后 iOS 控制器持有 trainer 状态，并把 raw hit 事件转交给 trainer 处理；
// 页面加载完成后会立刻打印本轮目标音，点击指板后进入正式判题链路。
private var isSettingsPresented = false
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()

private lazy var fretboardView: iOSFretboardView = {
    let fretboardView = iOSFretboardView(configuration: displayState.configuration)
    fretboardView.onRawEvent = { [weak self] hitResult in
        self?.handleFretboardTrainerHitResult(hitResult)
    }
    return fretboardView
}()

override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    configureLayout()
    applyDisplayState()
    printCurrentTrainerTarget(reason: "initial")
}
```

## 修改 2：iOS 控制器新增 trainer 判题与目标音日志函数

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: handleFretboardTrainerHitResult(_:), printCurrentTrainerTarget(reason:)
// 功能说明: 修改前这两个函数不存在；
// iOS 控制器没有承接 trainer 结果，也没有统一的目标音日志输出入口。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: handleFretboardTrainerHitResult(_:), printCurrentTrainerTarget(reason:)
// 功能说明: 修改后 iOS 控制器会过滤非 ended 事件，打印无效点击原因，
// 并在判题成功时输出结构化结果；如果答对，会继续打印下一题目标音。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.handle(
        hitResult: hitResult,
        configuration: displayState.configuration
    ) {
    case .ignored(.nonEndedPhase):
        return
    case .ignored(.missingHitCell):
        print(
            "[FretboardTrainer][iOS] target=\(fretboardTrainerState.targetPitchClass.displayText()) result=ignored reason=missingHitCell"
        )
    case let .ignored(.unresolvedHitPitch(cell)):
        print(
            "[FretboardTrainer][iOS] target=\(fretboardTrainerState.targetPitchClass.displayText()) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
        )
    case let .evaluated(evaluation):
        print("[iOS] \(evaluation.debugSummary())")
        if evaluation.didAdvanceTarget {
            printCurrentTrainerTarget(reason: "advanced")
        }
    }
}

private func printCurrentTrainerTarget(reason: String) {
    print(
        "[FretboardTrainer][iOS] target=\(fretboardTrainerState.targetPitchClass.displayText()) state=\(reason)"
    )
}
```

## 修改 3：macOS 控制器从 raw debug 输出切到 trainer 接线

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: fretboardView, viewDidLoad()
// 功能说明: 修改前 macOS 控制器与 iOS 一样，只打印 raw mouse 命中结果；
// 控制器没有持有 trainer，也没有页面加载后的初始目标音日志。
private var isSettingsPresented = false

private lazy var fretboardView: macOSFretboardView = {
    let fretboardView = macOSFretboardView(configuration: displayState.configuration)
    fretboardView.onRawEvent = { hitResult in
        print(hitResult.debugSummary(platform: "macOS"))
    }
    return fretboardView
}()

override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    configureLayout()
    applyDisplayState()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: fretboardTrainerState, fretboardView, viewDidLoad()
// 功能说明: 修改后 macOS 控制器与 iOS 对称接入 trainer；
// raw mouse 命中事件不再直接打印，而是进入共享练习判题链路。
private var isSettingsPresented = false
private var fretboardTrainerState = FretboardNaturalNoteTrainerState()

private lazy var fretboardView: macOSFretboardView = {
    let fretboardView = macOSFretboardView(configuration: displayState.configuration)
    fretboardView.onRawEvent = { [weak self] hitResult in
        self?.handleFretboardTrainerHitResult(hitResult)
    }
    return fretboardView
}()

override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    configureLayout()
    applyDisplayState()
    printCurrentTrainerTarget(reason: "initial")
}
```

## 修改 4：macOS 控制器新增 trainer 判题与目标音日志函数

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: handleFretboardTrainerHitResult(_:), printCurrentTrainerTarget(reason:)
// 功能说明: 修改前这两个函数不存在；
// macOS 控制器还没有统一的 trainer 日志和答对后切题通知入口。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: handleFretboardTrainerHitResult(_:), printCurrentTrainerTarget(reason:)
// 功能说明: 修改后 macOS 控制器会对 trainer 结果做统一日志输出，
// 包括忽略原因、判题摘要，以及答对后的下一题目标音。
private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.handle(
        hitResult: hitResult,
        configuration: displayState.configuration
    ) {
    case .ignored(.nonEndedPhase):
        return
    case .ignored(.missingHitCell):
        print(
            "[FretboardTrainer][macOS] target=\(fretboardTrainerState.targetPitchClass.displayText()) result=ignored reason=missingHitCell"
        )
    case let .ignored(.unresolvedHitPitch(cell)):
        print(
            "[FretboardTrainer][macOS] target=\(fretboardTrainerState.targetPitchClass.displayText()) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
        )
    case let .evaluated(evaluation):
        print("[macOS] \(evaluation.debugSummary())")
        if evaluation.didAdvanceTarget {
            printCurrentTrainerTarget(reason: "advanced")
        }
    }
}

private func printCurrentTrainerTarget(reason: String) {
    print(
        "[FretboardTrainer][macOS] target=\(fretboardTrainerState.targetPitchClass.displayText()) state=\(reason)"
    )
}
```

## 这次修改解决了什么

- 解决了“shared trainer 已存在，但平台层仍停留在 raw debug 输出”的接线缺口。
- 让 iOS / macOS 都开始真正消费 `FretboardNaturalNoteTrainerState`。
- 让页面加载后就有当前目标音日志，点击后有结构化判题日志，答对后还能自动打印下一题。

## 本次明确未修改的边界

- 未修改 `iOSFretboardView.swift`
- 未修改 `macOSFretboardView.swift`
- 未修改 `FretboardNaturalNoteTrainer.swift`
- 未修改任何 settings panel / scroll layout / 几何计算逻辑
- 未引入新的 UI 控件，当前仍然只输出控制台结果

## 验证结果

### 静态检查

- `ReadLints` 检查以下 2 个文件，结果为无错误：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 使用 macOS SDK 对项目内 Swift 文件做 typecheck，确认控制器接入 trainer 后仍能通过真实编译链路。
xcrun swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk NoteMaster_Ver_1/**/*.swift
```

- 结果：通过

### 环境限制

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 尝试读取 iOS Simulator SDK 路径，用于做 iOS 侧命令行 typecheck。
xcrun --sdk iphonesimulator --show-sdk-path
```

- 结果：失败，当前环境缺少 `iphonesimulator` SDK
- 结论：阶段 3 的 shared + macOS 实际编译链路已通过；iOS 侧命令行 typecheck 受本机 SDK 环境限制，未能执行

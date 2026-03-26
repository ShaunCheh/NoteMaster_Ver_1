# 20260326_194916_phase5_fretboard_prompt_boundary

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_194916`
- 记录范围：阶段 5，目标音 prompt 边界收口
- 本次目标：在不新增 UI 的前提下，为后续“目标音展示 overlay / label”预留清晰边界，让控制器通过统一的 prompt 入口消费 trainer 状态，而不是直接散落读取 `targetPitchClass`
- 根因结论：阶段 3 虽然已经把 trainer 接到双平台控制器，但控制器仍然直接读取 `fretboardTrainerState.targetPitchClass` 并打印。这样后续一旦要在页面上显示目标音，就容易继续在多个地方重复读取 trainer 内部状态，甚至倒逼去改 `FretboardView` 或把练习状态塞进 `FretboardDisplayState`
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 在 `FretboardNaturalNoteTrainerState` 中新增只读 `Prompt` 结构与 `prompt` 派生属性。
2. 在 `iOSViewController` / `macOSViewController` 中新增 `currentFretboardTrainerPrompt`，控制器不再直接散落读取 trainer 内部状态。
3. 将 `printCurrentTrainerTarget(...)` 收口为 `applyFretboardTrainerPrompt(...)`，并在函数注释中明确“后续如果要显示目标音 UI，就在这里同步 overlay”。
4. 将控制台输出改为统一使用 `prompt.displayText`，把“读取状态”和“应用展示语义”的边界固定下来。

## 修改 1：shared trainer 新增只读 prompt 视图模型

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: EventResult, targetPitchClass
// 功能说明: 修改前 trainer 只暴露内部业务状态 targetPitchClass；
// 平台层如果要显示或输出当前目标音，只能直接读取内部状态，没有统一的展示语义出口。
enum EventResult: Equatable, Sendable {
    case ignored(IgnoreReason)
    case evaluated(Evaluation)
}

private static let naturalPitchClasses: [PitchClass] = [
    .c, .d, .e, .f, .g, .a, .b
]

private(set) var targetPitchClass: PitchClass
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: Prompt, prompt
// 功能说明: 修改后 trainer 提供了只读 prompt 视图模型；
// 后续无论是控制台输出还是页面目标音 overlay，都可以通过同一条展示语义入口读取当前题目。
enum EventResult: Equatable, Sendable {
    case ignored(IgnoreReason)
    case evaluated(Evaluation)
}

struct Prompt: Equatable, Sendable {
    var targetPitchClass: PitchClass

    var displayText: String {
        targetPitchClass.displayText()
    }
}

private static let naturalPitchClasses: [PitchClass] = [
    .c, .d, .e, .f, .g, .a, .b
]

private(set) var targetPitchClass: PitchClass

var prompt: Prompt {
    Prompt(targetPitchClass: targetPitchClass)
}
```

## 修改 2：iOS 控制器从直接读取 target 切到统一应用 prompt

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: viewDidLoad(), handleFretboardTrainerHitResult(_:), printCurrentTrainerTarget(reason:)
// 功能说明: 修改前 iOS 控制器直接读取 fretboardTrainerState.targetPitchClass 并打印；
// 目标音的“如何展示/如何同步”没有统一出口，后续如果要上 UI 容易继续在多个调用点重复读取状态。
override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    configureLayout()
    applyDisplayState()
    printCurrentTrainerTarget(reason: "initial")
}

private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.handle(
        hitResult: hitResult,
        configuration: displayState.configuration
    ) {
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
    default:
        return
    }
}

private func printCurrentTrainerTarget(reason: String) {
    print(
        "[FretboardTrainer][iOS] target=\(fretboardTrainerState.targetPitchClass.displayText()) state=\(reason)"
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: currentFretboardTrainerPrompt, viewDidLoad(), handleFretboardTrainerHitResult(_:), applyFretboardTrainerPrompt(reason:)
// 功能说明: 修改后 iOS 控制器统一通过 prompt 消费 trainer 的展示语义；
// 当前阶段仍然只打印控制台，但后续如果要显示目标音 UI，只需要在 applyFretboardTrainerPrompt(...) 中同步 overlay。
private var currentFretboardTrainerPrompt: FretboardNaturalNoteTrainerState.Prompt {
    fretboardTrainerState.prompt
}

override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    configureLayout()
    applyDisplayState()
    applyFretboardTrainerPrompt(reason: "initial")
}

private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.handle(
        hitResult: hitResult,
        configuration: displayState.configuration
    ) {
    case .ignored(.missingHitCell):
        print(
            "[FretboardTrainer][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
        )
    case let .ignored(.unresolvedHitPitch(cell)):
        print(
            "[FretboardTrainer][iOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
        )
    case let .evaluated(evaluation):
        print("[iOS] \(evaluation.debugSummary())")
        if evaluation.didAdvanceTarget {
            applyFretboardTrainerPrompt(reason: "advanced")
        }
    default:
        return
    }
}

// 当前阶段只输出控制台；后续如果要显示目标音 UI，只需在这里同步 overlay。
private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    print(
        "[FretboardTrainer][iOS] target=\(prompt.displayText) state=\(reason)"
    )
}
```

## 修改 3：macOS 控制器对称切到统一应用 prompt

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: viewDidLoad(), handleFretboardTrainerHitResult(_:), printCurrentTrainerTarget(reason:)
// 功能说明: 修改前 macOS 控制器与 iOS 一样，直接读取 trainer 内部状态并打印；
// 页面层并没有一个稳定的“应用当前目标音展示语义”的入口。
override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    configureLayout()
    applyDisplayState()
    printCurrentTrainerTarget(reason: "initial")
}

private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.handle(
        hitResult: hitResult,
        configuration: displayState.configuration
    ) {
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
    default:
        return
    }
}

private func printCurrentTrainerTarget(reason: String) {
    print(
        "[FretboardTrainer][macOS] target=\(fretboardTrainerState.targetPitchClass.displayText()) state=\(reason)"
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: currentFretboardTrainerPrompt, viewDidLoad(), handleFretboardTrainerHitResult(_:), applyFretboardTrainerPrompt(reason:)
// 功能说明: 修改后 macOS 控制器与 iOS 对称，通过 prompt 统一消费当前目标音；
// 未来如果要新增 macOS 目标音标签或 overlay，只需在 applyFretboardTrainerPrompt(...) 中同步。
private var currentFretboardTrainerPrompt: FretboardNaturalNoteTrainerState.Prompt {
    fretboardTrainerState.prompt
}

override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    configureLayout()
    applyDisplayState()
    applyFretboardTrainerPrompt(reason: "initial")
}

private func handleFretboardTrainerHitResult(_ hitResult: FretboardHitResult) {
    switch fretboardTrainerState.handle(
        hitResult: hitResult,
        configuration: displayState.configuration
    ) {
    case .ignored(.missingHitCell):
        print(
            "[FretboardTrainer][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=missingHitCell"
        )
    case let .ignored(.unresolvedHitPitch(cell)):
        print(
            "[FretboardTrainer][macOS] target=\(currentFretboardTrainerPrompt.displayText) result=ignored reason=unresolvedHitPitch string=\(cell.stringIndex) fret=\(cell.fret)"
        )
    case let .evaluated(evaluation):
        print("[macOS] \(evaluation.debugSummary())")
        if evaluation.didAdvanceTarget {
            applyFretboardTrainerPrompt(reason: "advanced")
        }
    default:
        return
    }
}

// 当前阶段只输出控制台；后续如果要显示目标音 UI，只需在这里同步 overlay。
private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    print(
        "[FretboardTrainer][macOS] target=\(prompt.displayText) state=\(reason)"
    )
}
```

## 这次修改解决了什么

- 解决了“控制器直接读取 trainer 内部状态，未来目标音 UI 没有稳定接入点”的边界问题。
- 把“业务状态”与“展示语义”分成了 `trainer` 和 `prompt` 两层。
- 把未来目标音 UI 的接入点固定到了控制器侧 `applyFretboardTrainerPrompt(...)`，不需要回改 `FretboardView`。
- 保持 `FretboardDisplayState` 不承载练习业务，避免把页面展示状态和训练状态耦死。

## 本次明确未修改的边界

- 未修改 `FretboardDisplayState.swift`
- 未修改 `iOSFretboardView.swift`
- 未修改 `macOSFretboardView.swift`
- 未新增任何页面 UI 控件
- 当前仍然只输出控制台结果，不显示目标音 overlay

## 验证结果

### 静态检查

- `ReadLints` 检查以下 3 个文件，结果为无错误：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 使用 macOS SDK 对项目内 Swift 文件做 typecheck，确认 prompt 边界收口后整个项目仍能通过编译。
xcrun swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk NoteMaster_Ver_1/**/*.swift
```

- 结果：通过

### 命令行验证

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 使用临时入口编译并执行 FretboardValidationRunner.run(platform: .commandLine)，确认阶段 5 的边界收口没有破坏既有共享层回归。
xcrun swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  -o /tmp/fretboard_validation_check \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  /tmp/fretboard_validation_check.swift && \
/tmp/fretboard_validation_check
```

- 结果：`[FretboardValidation][commandLine] automated=PASS fixtures=7`
- 结论：阶段 5 的 prompt 边界收口没有引入新的 shared 层回归问题，既有 validation runner 继续通过

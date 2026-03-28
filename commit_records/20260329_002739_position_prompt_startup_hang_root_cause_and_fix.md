# 20260329_002739_position_prompt_startup_hang_root_cause_and_fix

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_002739`
- 记录范围：排查“位置音名模式接入后，macOS 窗口启动失败、iOS 首屏发白”的启动卡死问题；本次记录包含问题现象、日志推进、根因判断与最终修复
- 本次问题：两个平台都在应用启动早期卡住，表象分别是 macOS 窗口不出现、iOS 一直白屏
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 记录说明：补日志过程中曾把 `joined(separator: ",")` 误写成带转义的字符串字面量并触发一次 `Unterminated string literal`；该问题已在同轮修正。以下代码块均为最终落库的有效版本

## 根因结论

- `-[NSApplication(NSWindowRestoration) restoreWindowWithIdentifier:state:completionHandler:] Unable to find className=(null)` 只是伴随出现的窗口恢复警告，不是这次卡死主因
- 真正阻塞启动的是共享层 `FretboardValidationRunner.runAndReportIfNeeded(...)`
- 通过逐层补日志，最终把问题缩到：
- `horizontal-guitar6-reference`
- `validatePositionPromptTrainer`
- `stage=initialSession`
- `FretboardNaturalNoteTrainer.makePositionPromptSession(...)`
- 更精确地说，卡在 `resolvedCandidates.randomElement(using: &generator)` 这一行之前后之间
- 根因是 validation 使用的伪随机源原先为 `ZeroRandomNumberGenerator`，它的 `next()` 永远返回 `0`
- 新增的 `positionPrompt` 校验首次使用了 `randomElement(using:)`；当候选数量是 `48` 这类非 2 的幂时，Swift 标准库会走拒绝采样
- 随机源若永远产出同一个不被接受的值，就可能永远采不到结果，最终表现为 validation 卡死，进而让 macOS 窗口创建和 iOS 根控制器显示都无法继续

## 日志分析摘要

- 第一层日志表明启动停在 `run fretboard validation` 之后，尚未进入 `run staff validation`、`create root view controller`、`create window`
- 第二层日志表明 `makeScene`、几何校验、命中测试、普通 natural trainer 和 single coverage trainer 全部正常
- 第三层日志把范围继续缩到 `validatePositionPromptTrainer -> initialSession`
- 第四层日志表明 `positionPrompt` 候选格已经成功枚举为 `48` 个，但在真正从候选集合里取随机元素时卡住

日志来源：运行期控制台输出，以下片段直接反映了卡死边界。

```text
[Startup][macOSApp] run fretboard validation
[FretboardValidation][macOS] fixture begin name=horizontal-guitar6-reference
[FretboardValidation][fixture=horizontal-guitar6-reference] step begin name=validatePositionPromptTrainer
[FretboardValidation][fixture=horizontal-guitar6-reference][validatePositionPromptTrainer] stage=initialSession
[PositionPrompt][Trainer] makePositionPromptSession begin
[PositionPrompt][Trainer] selectPrompt begin excluded=nil
[PositionPrompt][Trainer] selectPrompt candidates count=48
[PositionPrompt][Trainer] selectPrompt filtered count=48
[PositionPrompt][Trainer] selectPrompt resolved count=48
```

- 关键观察：日志已经打印出 `resolved count=48`，但没有继续出现 `selectedCell`
- 这意味着程序不是卡在候选格枚举，也不是卡在 `pitchClass(for:)` 解析，而是卡在 `randomElement(using:)` 的随机取样过程中

## 修改 1：在应用入口和控制器生命周期补启动日志

### 修改前

- 应用入口只做初始化，不输出边界日志
- 控制器生命周期、页面编排和指板 host 放置也没有启动期快照
- 结果是用户只能看到“没起窗口 / 白屏”，无法判断是卡在 validation、控制器初始化，还是布局/投影阶段

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift,
// NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:),
// application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改前启动链路没有分段日志；
// 无法从控制台直接看出应用停在 validation、ViewController 创建还是 window/rootViewController 绑定。

// macOS
func applicationDidFinishLaunching(_ notification: Notification) {
    MusicFontRegistry.bootstrapIfNeeded()
    FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
    StaffValidationRunner.runAndReportIfNeeded(platform: .macOS)
    NSApp.appearance = NSAppearance(named: .aqua)

    let viewController = macOSViewController()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.contentViewController = viewController
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    self.window = window
}

// iOS
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    MusicFontRegistry.bootstrapIfNeeded()
    FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)
    StaffValidationRunner.runAndReportIfNeeded(platform: .iOS)

    let window = UIWindow(frame: UIScreen.main.bounds)
    window.overrideUserInterfaceStyle = .light
    window.rootViewController = iOSViewController()
    window.backgroundColor = .systemBackground
    window.makeKeyAndVisible()
    self.window = window
    return true
}
```

### 修改后

- `AppDelegate` 显式打印启动边界：字体、validation、控制器创建、窗口绑定、显示
- `iOSViewController` / `macOSViewController` 增加 `logLifecycle(_:)` 与状态快照
- 控制器在 `loadView`、`viewDidLoad`、`configureLayout()`、`applyDisplayState()`、`applyPageDisplayState()`、`applyFretboardHostPlacement()` 等关键点都能输出当前页面/模式状态

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift,
// NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:),
// application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改后入口会把“启动卡在哪一步”直接打印到控制台；
// 一旦日志停在 validation 之前或之后，就能立刻判断 UI 是否尚未开始创建。

// macOS
func applicationDidFinishLaunching(_ notification: Notification) {
    print("[Startup][macOSApp] applicationDidFinishLaunching begin")
    print("[Startup][macOSApp] bootstrap music fonts")
    MusicFontRegistry.bootstrapIfNeeded()
    print("[Startup][macOSApp] run fretboard validation")
    FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
    print("[Startup][macOSApp] run staff validation")
    StaffValidationRunner.runAndReportIfNeeded(platform: .macOS)
    print("[Startup][macOSApp] apply aqua appearance")
    NSApp.appearance = NSAppearance(named: .aqua)

    print("[Startup][macOSApp] create root view controller")
    let viewController = macOSViewController()
    print("[Startup][macOSApp] create window")
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    print("[Startup][macOSApp] attach contentViewController")
    window.contentViewController = viewController
    print("[Startup][macOSApp] make window key and visible")
    window.makeKeyAndOrderFront(nil)
    print("[Startup][macOSApp] activate app")
    NSApp.activate(ignoringOtherApps: true)
    self.window = window
    print("[Startup][macOSApp] applicationDidFinishLaunching end")
}

// iOS
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    print("[Startup][iOSApp] didFinishLaunching begin")
    print("[Startup][iOSApp] bootstrap music fonts")
    MusicFontRegistry.bootstrapIfNeeded()
    print("[Startup][iOSApp] run fretboard validation")
    FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)
    print("[Startup][iOSApp] run staff validation")
    StaffValidationRunner.runAndReportIfNeeded(platform: .iOS)

    print("[Startup][iOSApp] create window")
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.overrideUserInterfaceStyle = .light
    print("[Startup][iOSApp] create root view controller")
    window.rootViewController = iOSViewController()
    window.backgroundColor = .systemBackground
    print("[Startup][iOSApp] make window key and visible")
    window.makeKeyAndVisible()
    self.window = window
    print("[Startup][iOSApp] didFinishLaunching end")
    return true
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift,
// NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: logLifecycle(_:), debugStateSnapshot(), loadView(),
// viewDidLoad(), applyDisplayState(), applyPageDisplayState()
// 功能说明: 修改后控制器会把“当前 trainer mode / page top-main 布局 / fretboard 是否显示”
// 作为状态快照打印出来，便于排除“validation 已过、但控制器或布局链路没跑通”的情况。

private var hasLoggedInitialLayoutPass = false

private func logLifecycle(_ message: String) {
    print("[Startup][macOSVC] \(message) \(debugStateSnapshot())")
}

private func debugStateSnapshot() -> String {
    "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
    "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
    "pageTop=\(String(describing: pageDisplayState.topContentMode)) " +
    "pageMain=\(String(describing: pageDisplayState.mainContentMode)) " +
    "displayMode=\(String(describing: displayState.displayMode)) " +
    "showsFretboard=\(isShowingFretboard) " +
    "settingsPresented=\(isSettingsPresented)"
}

override func loadView() {
    print("[Startup][macOSVC] loadView begin")
    view = NSView()
    print("[Startup][macOSVC] loadView end")
}

override func viewDidLoad() {
    super.viewDidLoad()
    logLifecycle("viewDidLoad begin")
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    configureLayout()
    applyDisplayState()
    logLifecycle("viewDidLoad end")
}
```

## 修改 2：在 `FretboardValidation` 增加 fixture / step / stage 级日志

### 修改前

- validation 只有最终 summary
- 一旦某个 fixture 中途卡死，控制台只能看到“开始跑了某个 fixture”，看不到具体停在 `makeScene`、几何校验、命中测试还是 trainer 校验
- `validatePositionPromptTrainer` 内部也没有 `candidateEnumeration / initialSession / wrongAnswer / correctAnswer` 这样的阶段日志

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validate(_:), validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改前 validation 直接串行调用所有校验函数；
// 一旦其中某一步阻塞，只能看到 fixture begin，看不到更细的停顿边界。

static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
    let sceneBuilder = FretboardSceneBuilder(configuration: fixture.configuration)
    let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
    var issues: [FretboardValidationIssue] = []

    validateBoundsContainment(scene: scene, fixture: fixture, record: record)
    validateVerticalHeightConsumption(scene: scene, fixture: fixture, record: record)
    validateSceneCounts(scene: scene, fixture: fixture, record: record)
    validateCellAndAnchorMapping(scene: scene, fixture: fixture, record: record)
    validateCellAspectRatio(scene: scene, fixture: fixture, record: record)
    validateAxisOrientation(scene: scene, fixture: fixture, record: record)
    validateMarkerPlacements(scene: scene, fixture: fixture, record: record)
    validateHitTesting(scene: scene, fixture: fixture, sceneBuilder: sceneBuilder, record: record)
    validatePitchResolution(fixture: fixture, record: record)
    validatePitchClassCellEnumeration(fixture: fixture, record: record)
    validateNaturalNoteTrainer(fixture: fixture, record: record)
    validateSingleCoverageTrainer(fixture: fixture, record: record)
    validatePositionPromptTrainer(fixture: fixture, record: record)
    validateQuarterNoteSequenceTrainer(fixture: fixture, record: record)

    return issues
}

static func validatePositionPromptTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    let configuration = fixture.configuration
    let candidateCells = positionPromptCandidateCells(configuration: configuration)
    var initialGenerator = ZeroRandomNumberGenerator()
    let initialTrainer = FretboardNaturalNoteTrainerState(positionPromptMode: ())
    let initialSession = initialTrainer.makePositionPromptSession(
        configuration: configuration,
        using: &initialGenerator
    )

    guard let wrongAnswer = PitchClass.naturalCasesInOrder.first(where: {
        $0 != initialSession.promptPitchClass
    }) else {
        record("position prompt trainer 无法构造错误按钮。")
        return
    }
}
```

### 修改后

- `validate(_:)` 新增 `logStep` 和 `runStep`
- `makeScene` 前后、每个 `validateXxx(...)` 的 begin/end 都会打印
- `validatePositionPromptTrainer` 额外打印 `candidateEnumeration`、`initialSessionCreated`、`resolveWrongAnswer` 等细粒度阶段

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validate(_:), validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改后 validation 能把“卡在第几个 fixture、第几个 step、哪个 stage”
// 精确打印出来，从而把问题从“启动失败”收窄到具体共享函数。

static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
    let sceneBuilder = FretboardSceneBuilder(configuration: fixture.configuration)
    var issues: [FretboardValidationIssue] = []

    func logStep(_ phase: String, _ name: String) {
        print("[FretboardValidation][fixture=\(fixture.name)] step \(phase) name=\(name)")
    }

    func runStep(_ name: String, _ body: () -> Void) {
        logStep("begin", name)
        body()
        logStep("end", name)
    }

    logStep("begin", "makeScene")
    let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
    logStep("end", "makeScene")

    runStep("validateBoundsContainment") {
        validateBoundsContainment(scene: scene, fixture: fixture, record: record)
    }
    runStep("validateHitTesting") {
        validateHitTesting(scene: scene, fixture: fixture, sceneBuilder: sceneBuilder, record: record)
    }
    runStep("validatePositionPromptTrainer") {
        validatePositionPromptTrainer(fixture: fixture, record: record)
    }

    return issues
}

static func validatePositionPromptTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    func logStage(_ name: String) {
        print("[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] stage=\(name)")
    }

    let configuration = fixture.configuration
    logStage("candidateEnumeration")
    let candidateCells = positionPromptCandidateCells(configuration: configuration)
    // ... 省略候选校验 ...

    logStage("initialSession")
    var initialGenerator = DeterministicRandomNumberGenerator()
    let initialTrainer = FretboardNaturalNoteTrainerState(positionPromptMode: ())
    let initialSession = initialTrainer.makePositionPromptSession(
        configuration: configuration,
        using: &initialGenerator
    )
    print(
        "[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] initialSessionCreated cell=string=\(initialSession.promptCell.stringIndex) fret=\(initialSession.promptCell.fret) pitch=\(initialSession.promptPitchClass.displayText())"
    )

    print(
        "[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] resolveWrongAnswer firstCandidatePitch=\(firstCandidatePitchClass.displayText()) naturalCases=\(PitchClass.naturalCasesInOrder.map { $0.displayText() }.joined(separator: ","))"
    )
    guard let wrongAnswer = PitchClass.naturalCasesInOrder.first(where: {
        $0 != firstCandidatePitchClass
    }) else {
        record("position prompt trainer 无法构造不同于首题答案的自然音错误按钮。")
        return
    }
    print(
        "[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] wrongAnswerResolved pitch=\(wrongAnswer.displayText())"
    )
}
```

## 修改 3：在 `positionPrompt` 共享 trainer 内部补选题日志

### 修改前

- 共享 trainer 的 `makePositionPromptSession(...)` 直接返回 session
- 内部 helper 也直接在候选数组上做 `randomElement(using:)`
- 一旦卡在取样阶段，只能从 validation 外层看到“initialSession 没返回”，却不知道内部到底走到了哪一步

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:using:),
// makePositionPromptSession(configuration:excluding:using:)
// 功能说明: 修改前 position prompt 选题 helper 不打印任何内部状态；
// 只能知道“session 没构造出来”，却看不到候选数量、过滤结果和实际卡住的位置。

func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    using generator: inout R
) -> PositionPromptSession {
    requirePositionPromptMode()
    return Self.makePositionPromptSession(
        configuration: configuration,
        excluding: nil,
        using: &generator
    )
}

private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    excluding excludedCell: FretboardCell?,
    using generator: inout R
) -> PositionPromptSession {
    let candidates = positionPromptCandidateCells(in: configuration)
    let filteredCandidates = candidates.filter { cell in
        cell != excludedCell
    }
    let resolvedCandidates = filteredCandidates.isEmpty
        ? candidates
        : filteredCandidates

    guard let promptCell = resolvedCandidates.randomElement(using: &generator) else {
        preconditionFailure("Position prompt candidates should never be empty.")
    }

    guard let promptPitchClass = configuration.pitchClass(for: promptCell) else {
        preconditionFailure("Position prompt candidate cell must resolve to a pitch class.")
    }

    return PositionPromptSession(
        promptCell: promptCell,
        promptPitchClass: promptPitchClass
    )
}
```

### 修改后

- `makePositionPromptSession(...)` 增加 begin/end 日志
- 内部 helper 额外打印 `excluded`、`candidates count`、`filtered count`、`resolved count`、`selectedCell`、`resolvedPitchClass`
- 这组日志直接证明了程序停在 `randomElement(using:)`，而不是更前面的枚举或更后面的解析

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名: makePositionPromptSession(configuration:using:),
// makePositionPromptSession(configuration:excluding:using:)
// 功能说明: 修改后共享 trainer 会把 position prompt 的选题过程逐步打印出来；
// 当 validation 再次卡住时，可以用最后一条日志直接定位到具体语句。

func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    using generator: inout R
) -> PositionPromptSession {
    print("[PositionPrompt][Trainer] makePositionPromptSession begin")
    requirePositionPromptMode()
    let session = Self.makePositionPromptSession(
        configuration: configuration,
        excluding: nil,
        using: &generator
    )
    print(
        "[PositionPrompt][Trainer] makePositionPromptSession end prompt=string=\(session.promptCell.stringIndex) fret=\(session.promptCell.fret) pitch=\(session.promptPitchClass.displayText())"
    )
    return session
}

private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    excluding excludedCell: FretboardCell?,
    using generator: inout R
) -> PositionPromptSession {
    let excludedCellText: String
    if let excludedCell {
        excludedCellText = "string=\(excludedCell.stringIndex) fret=\(excludedCell.fret)"
    } else {
        excludedCellText = "nil"
    }
    print("[PositionPrompt][Trainer] selectPrompt begin excluded=\(excludedCellText)")

    let candidates = positionPromptCandidateCells(in: configuration)
    print("[PositionPrompt][Trainer] selectPrompt candidates count=\(candidates.count)")

    let filteredCandidates = candidates.filter { cell in
        cell != excludedCell
    }
    print("[PositionPrompt][Trainer] selectPrompt filtered count=\(filteredCandidates.count)")

    let resolvedCandidates = filteredCandidates.isEmpty
        ? candidates
        : filteredCandidates
    print("[PositionPrompt][Trainer] selectPrompt resolved count=\(resolvedCandidates.count)")

    guard let promptCell = resolvedCandidates.randomElement(using: &generator) else {
        preconditionFailure("Position prompt candidates should never be empty.")
    }
    print("[PositionPrompt][Trainer] selectPrompt selectedCell string=\(promptCell.stringIndex) fret=\(promptCell.fret)")

    guard let promptPitchClass = configuration.pitchClass(for: promptCell) else {
        preconditionFailure("Position prompt candidate cell must resolve to a pitch class.")
    }
    print("[PositionPrompt][Trainer] selectPrompt resolvedPitchClass=\(promptPitchClass.displayText())")

    let session = PositionPromptSession(
        promptCell: promptCell,
        promptPitchClass: promptPitchClass
    )
    print("[PositionPrompt][Trainer] selectPrompt end")
    return session
}
```

## 修改 4：将 validation 的“恒零随机源”改成可重复但不会卡死的递增随机源

### 修改前

- validation 中的 `ZeroRandomNumberGenerator` 永远返回 `0`
- 在旧 natural trainer / single coverage 校验里，这种写法还能工作，因为它们只需要“固定结果”
- 但在这次新增的 `positionPrompt` 校验中，`randomElement(using:)` 会直接消费这个随机源
- 当标准库因为拒绝采样无法接受永远相同的返回值时，就会卡死在取样环节

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: ZeroRandomNumberGenerator,
// validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改前 validation 的“确定性随机源”实际上是恒零输出；
// 它能让测试结果看起来稳定，但在 position prompt 引入 randomElement(using:) 后会导致启动期死锁式卡住。

private struct ZeroRandomNumberGenerator: RandomNumberGenerator {
    mutating func next() -> UInt64 {
        0
    }
}

var initialGenerator = ZeroRandomNumberGenerator()
var wrongGenerator = ZeroRandomNumberGenerator()
var correctGenerator = ZeroRandomNumberGenerator()
```

### 修改后

- 改为 `DeterministicRandomNumberGenerator`
- `next()` 输出 `0, 1, 2, 3...` 的递增序列
- 这样既保持 validation 的可重复性，又避免 `randomElement(using:)` 因恒零输入而卡死
- `positionPrompt` 校验中的三个 deterministic generator 实例全部同步切换

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: DeterministicRandomNumberGenerator,
// validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改后 validation 仍保持“可重复”，但不会再把标准库随机取样卡死；
// 这是这次启动卡死问题的最终根因修复。

// 避免固定返回 0 触发标准库随机取样的拒绝采样死循环；
// 递增序列仍然是可重复的，且对 validation 足够稳定。
private struct DeterministicRandomNumberGenerator: RandomNumberGenerator {
    private var value: UInt64 = 0

    mutating func next() -> UInt64 {
        defer { value &+= 1 }
        return value
    }
}

var initialGenerator = DeterministicRandomNumberGenerator()
var wrongGenerator = DeterministicRandomNumberGenerator()
var correctGenerator = DeterministicRandomNumberGenerator()
```

## 最终结果

- 启动路径的日志边界已经补齐：现在能区分是卡在 `AppDelegate`、`ViewController` 还是 shared validation
- `FretboardValidation` 已具备 fixture / step / stage 三级定位能力
- `positionPrompt` 共享 trainer 的选题过程已有内部日志
- 真正导致卡死的 deterministic RNG 已完成替换，修复点收敛在 `Shared/Fretboard/FretboardValidation.swift`
- 若后续还有新的启动问题，控制台已经可以直接给出更精确的下一层边界，而不需要重新从“窗口起不来 / 白屏”这种表象开始猜

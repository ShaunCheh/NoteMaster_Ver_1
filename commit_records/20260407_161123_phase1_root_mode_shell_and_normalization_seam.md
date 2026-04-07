# 20260407_161123_phase1_root_mode_shell_and_normalization_seam

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260407_161123`
- 记录范围：`play 模式分阶段计划` 的 `phase 1`
- 修改目标：
  - 在平台入口之上先建立 `RootMode` 与根容器壳层，但默认用户路径仍然是 `exercise`
  - 给后续 scene core 迁移预留一个过渡命名层
  - 将 exercise 专属的 layout normalization / support rules 从 `ExerciseSceneValidator` 抽离到 `ExerciseCompositionPolicy` 侧
  - 保持当前 exercise 启动、settings 和 layout smoke 行为不变
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/App/RootMode.swift`
  - `NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

- 平台入口直接把窗口根控制器绑死到 `iOSViewController` / `macOSViewController`，还没有 `RootMode` 和根容器壳层。
- `play` 模式虽然在计划里已经被定义为顶层互斥模式，但代码里还没有任何根级模式切换边界。
- `ExerciseSceneValidator` 同时承担了两类职责：
  - scene 结构校验
  - exercise 专属的 layout normalization / preset support 语义
- 调用方把 “layout 是否合法、是否需要纠偏” 统一依赖到 validator 上，导致 validator 既像校验器，又像 policy。
- Shared 层还没有一个“通用 scene 命名入口”的过渡文件；后续 phase 2 如果直接大面积改名，爆炸半径会很大。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改前 iOS 入口直接把窗口根控制器绑定为 exercise 控制器，没有 root shell。
print("[Startup][iOSApp] create root view controller")
window.rootViewController = iOSViewController()

#if DEBUG
if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let viewController = window.rootViewController
            as? iOSViewController
        else {
            let summary =
                "[RuntimeSmoke][iOS] FAIL scenario=layout_preset_regression reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }
        // 这里直接假设 root 就是 exercise 控制器。
        viewController.runLayoutPresetRegressionSmokeTest(in: window) { _, _ in }
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 修改前 macOS 入口同样直接把窗口内容控制器绑定为 exercise 控制器。
print("[Startup][macOSApp] create root view controller")
let viewController = macOSViewController()
print("[Startup][macOSApp] attach contentViewController")
window.contentViewController = viewController

#if DEBUG
if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let viewController = window.contentViewController
            as? macOSViewController
        else {
            let summary =
                "[RuntimeSmoke][macOS] FAIL scenario=layout_preset_regression reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }
        // 这里同样把 smoke test 和 exercise 根控制器写死绑在一起。
        viewController.runLayoutPresetRegressionSmokeTest(in: window) { _, _ in }
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: normalizedPreferences(_:trainerDisplayState:), isCompositionPresetSemanticallySupported(_:for:), isAccessoryPresentationSemanticallySupported(_:)
// 功能说明: 修改前 validator 同时承担结构校验和 exercise 专属语义归一化，职责混杂。
enum ExerciseSceneValidator {
    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        var normalized = preferences

        switch trainerDisplayState.exerciseMode {
        case .single, .sequence:
            if !isCompositionPresetSemanticallySupported(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            ) {
                normalized.compositionPreset = .staffToFretboard
            }
        case .positionPrompt:
            if !isCompositionPresetSemanticallySupported(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            ) {
                normalized.compositionPreset = .fretboardToNaturalNoteStrip
            }
        }

        if !isAccessoryPresentationSemanticallySupported(
            normalized.accessoryPresentation
        ) {
            normalized.accessoryPresentation = .docked
        }
        return normalized
    }
}
```

```text
# 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前还没有 iOS 根容器壳层。
（文件不存在）
```

```text
# 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前还没有 macOS 根容器壳层。
（文件不存在）
```

```text
# 文件路径: NoteMaster_Ver_1/Shared/App/RootMode.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前没有根级模式枚举，exercise 与未来 play 还没有共同的顶层模式入口。
（文件不存在）
```

```text
# 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前没有 scene core 的过渡命名层，后续 phase 2 直接改名的成本会很高。
（文件不存在）
```

## 修改后

### 1. 新增根级模式枚举

- 新增 `RootMode`
- 当前只把默认值锁定为 `.exercise`
- `play` 先进入类型系统，但还不暴露完整产品实现

```swift
// 文件路径: NoteMaster_Ver_1/Shared/App/RootMode.swift
// 函数名: RootMode.debugName
// 功能说明: 新增根级模式入口，为 exercise / play 的互斥切换先建立统一抽象。
enum RootMode: String, Equatable, Hashable, Sendable {
    case exercise
    case play

    static let defaultMode: RootMode = .exercise

    var debugName: String {
        rawValue
    }
}
```

### 2. 新增 iOS / macOS 根容器壳层

- 新增 `iOSRootViewController` 与 `macOSRootViewController`
- 这两个壳层现在只做一件事：根据 `RootMode` 承载 child controller
- 现阶段默认仍然装载 exercise 控制器
- `play` 先用占位 VC 保持 mode shell 真实存在，避免 phase 2/3 再回头补入口边界
- 额外暴露 `activeExerciseViewController`，用于兼容现有 smoke test

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSRootViewController.swift
// 函数名: activeExerciseViewController, setRootMode(_:), applyRootMode(_:)
// 功能说明: iOS 根容器收口 RootMode；当前默认仍挂 exercise，play 先占位，兼容 smoke test 的 exercise 控制器获取逻辑。
final class iOSRootViewController: UIViewController {
    private let exerciseViewController = iOSViewController()
    private let playPlaceholderViewController = iOSModePlaceholderViewController(
        titleText: "Play mode is not available yet."
    )

    private(set) var rootMode: RootMode
    private var currentViewController: UIViewController?

    var activeExerciseViewController: iOSViewController? {
        rootMode == .exercise ? exerciseViewController : nil
    }

    func setRootMode(_ rootMode: RootMode) {
        guard self.rootMode != rootMode || currentViewController == nil else {
            return
        }
        self.rootMode = rootMode
        guard isViewLoaded else {
            return
        }
        applyRootMode(rootMode)
    }

    func applyRootMode(_ rootMode: RootMode) {
        let nextViewController = viewController(for: rootMode)
        guard currentViewController !== nextViewController else {
            return
        }
        // 根容器统一负责 child controller 的装载与替换，避免 AppDelegate 继续绑死到 exercise 控制器。
        addChild(nextViewController)
        view.addSubview(nextViewController.view)
        nextViewController.didMove(toParent: self)
        currentViewController = nextViewController
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSRootViewController.swift
// 函数名: activeExerciseViewController, setRootMode(_:), applyRootMode(_:)
// 功能说明: macOS 根容器与 iOS 对齐，先把 root mode 的 child-hosting 壳层立住。
final class macOSRootViewController: NSViewController {
    private let exerciseViewController = macOSViewController()
    private let playPlaceholderViewController = macOSModePlaceholderViewController(
        titleText: "Play mode is not available yet."
    )

    private(set) var rootMode: RootMode
    private var currentViewController: NSViewController?

    var activeExerciseViewController: macOSViewController? {
        rootMode == .exercise ? exerciseViewController : nil
    }

    func setRootMode(_ rootMode: RootMode) {
        guard self.rootMode != rootMode || currentViewController == nil else {
            return
        }
        self.rootMode = rootMode
        guard isViewLoaded else {
            return
        }
        applyRootMode(rootMode)
    }

    func applyRootMode(_ rootMode: RootMode) {
        let nextViewController = viewController(for: rootMode)
        guard currentViewController !== nextViewController else {
            return
        }
        // 与 iOS 一样，统一由 root shell 托管子控制器生命周期。
        addChild(nextViewController)
        view.addSubview(nextViewController.view)
        currentViewController = nextViewController
    }
}
```

### 3. 平台入口改为先挂 root shell

- iOS / macOS 的 `AppDelegate` 现在都先创建 root shell
- smoke test 不再假设窗口根控制器就是 exercise 控制器，而是通过 `activeExerciseViewController` 取出 exercise child
- 这一步确保 phase 1 就把“根模式壳层”接到了真实入口上，而不是只停留在类型层

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改后 iOS 入口先挂 root shell，再从 shell 取回 active exercise 控制器以兼容现有 smoke test。
print("[Startup][iOSApp] create root view controller")
window.rootViewController = iOSRootViewController()

#if DEBUG
if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let rootViewController = window.rootViewController
            as? iOSRootViewController,
            let viewController = rootViewController.activeExerciseViewController
        else {
            let summary =
                "[RuntimeSmoke][iOS] FAIL scenario=layout_preset_regression reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }
        // smoke test 仍然跑 exercise，但入口获取方式已经过 root shell。
        viewController.runLayoutPresetRegressionSmokeTest(in: window) { _, _ in }
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 修改后 macOS 入口也先挂 root shell，exercise 控制器通过 shell 的 activeExerciseViewController 暴露。
print("[Startup][macOSApp] create root view controller")
let viewController = macOSRootViewController()
print("[Startup][macOSApp] attach contentViewController")
window.contentViewController = viewController

#if DEBUG
if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let rootViewController = window.contentViewController
            as? macOSRootViewController,
            let viewController = rootViewController.activeExerciseViewController
        else {
            let summary =
                "[RuntimeSmoke][macOS] FAIL scenario=layout_preset_regression reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }
        // smoke test 仍然命中 exercise child，而不是直接假设 root 就是 macOSViewController。
        viewController.runLayoutPresetRegressionSmokeTest(in: window) { _, _ in }
    }
}
#endif
```

### 4. 新增 scene core 过渡命名层

- 新增 `SceneCoreCompatibility.swift`
- 当前实现还是 `typealias`，不改行为
- 目的不是“已经完成通用化”，而是为 phase 2 的正式上提先预留一个稳定命名入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift
// 函数名: N/A
// 功能说明: 新增 scene core 过渡命名层，让后续新代码可以逐步转向通用命名，而旧 exercise 类型先继续工作。
typealias AppScene = ExerciseScene
typealias AppSceneNode = ExerciseSceneNode
typealias AppSceneAxis = ExerciseSceneAxis
typealias AppSceneSplitChild = ExerciseSceneSplitChild
typealias AppSceneSplitChildMainAxisSizing = ExerciseSceneSplitChildMainAxisSizing
typealias AppSurfaceID = ExerciseSurfaceID
typealias AppSurfaceNode = ExerciseSurfaceNode
typealias AppSurfaceState = ExerciseSurfaceState
typealias AppPresentationState = ExercisePresentationState
```

### 5. 将 exercise 专属 normalization 从 validator 抽到 policy

- 新增 `ExerciseCompositionPolicy+Normalization.swift`
- 现在由 `ExerciseCompositionPolicy` 负责：
  - `normalizedPreferences`
  - `isCompositionPresetSupported`
  - `isAccessoryPresentationSupported`
  - layout preset 的 support / fallback
- `ExerciseSceneValidator` 收敛为：
  - `validate(_:)` 结构校验
  - legacy page 投影
  - vertical rail 结构约束
- 这一步把 “校验器” 和 “exercise policy” 的职责边界拆开了

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名: normalizedPreferences(_:trainerDisplayState:), isCompositionPresetSupported(_:for:), isAccessoryPresentationSupported(_:)
// 功能说明: 修改后 exercise 的 layout normalization / support rules 统一归到 policy 侧，validator 不再承载这部分语义。
extension ExerciseCompositionPolicy {
    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        var normalized = preferences
        normalized.compositionPreset = normalizedCompositionPreset(
            normalized.compositionPreset,
            for: trainerDisplayState.exerciseMode
        )
        normalized.layoutPreset = normalizedLayoutPreset(
            normalized.layoutPreset,
            for: normalized.compositionPreset
        )

        if !isAccessoryPresentationSupported(normalized.accessoryPresentation) {
            normalized.accessoryPresentation = .docked
        }
        if normalized.accessoryPresentation != .collapsible {
            normalized.isAccessoryExpanded = true
        }

        if normalized.compositionPreset == .fretboardToNaturalNoteStrip {
            normalized.isNaturalNoteStripVisible = true
        }
        return normalized
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: validate(_:), legacyPageDisplayState(for:)
// 功能说明: 修改后 validator 收敛为结构校验和 legacy page 投影，不再包含 exercise 专属的 layout normalization/support rules。
enum ExerciseSceneValidator {
    static func validate(
        _ scene: ExerciseScene
    ) -> [ExerciseSceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [ExerciseSceneValidationIssue] = []

        for surfaceID in ExerciseSurfaceID.allCases {
            let duplicateCount = surfaceNodes.filter { $0.id == surfaceID }.count
            if duplicateCount > 1 {
                issues.append(.duplicateSurfaceID(surfaceID))
            }
        }
        if !surfaceNodes.contains(where: \\.isPromptSurface) {
            issues.append(.missingPromptSurface)
        }
        if !surfaceNodes.contains(where: \\.isAnswerSurface) {
            issues.append(.missingAnswerSurface)
        }
        return issues
    }

    static func legacyPageDisplayState(
        for scene: ExerciseScene
    ) -> PageDisplayState? {
        // 仍由 validator 保留 legacy page bridge 的投影职责。
        nil
    }
}
```

### 6. 调用方改为依赖 policy seam

- `ExerciseCompositionPolicy` 内部不再通过 validator 做 normalization，而是直接调用自己的 normalization extension
- `LegacyPageLayoutAdapter` 与 `SettingsPanelStateContext` 也改为依赖 `ExerciseCompositionPolicy.normalizedPreferences(...)`
- 这样 phase 1 就完成了 seam 的切换，但旧功能行为仍然走相同语义

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: makePresentation(from:), legacyCompatiblePreferences(from:)
// 功能说明: 修改后 policy 内部直接使用自己的 normalization seam，避免继续反向依赖 validator。
enum ExerciseCompositionPolicy {
    static func makePresentation(
        from input: ExerciseCompositionPolicyInput
    ) -> ExercisePresentationState {
        var resolvedLayoutPreferences = ExerciseCompositionPolicy
            .normalizedPreferences(
                input.layoutPreferences,
                trainerDisplayState: input.trainerDisplayState
            )
        resolvedLayoutPreferences.isPianoAccessoryVisible = resolvedLayoutPreferences
            .isPianoAccessoryVisible
            || input.pianoPanelState.isVisible
        let scene = makeScene(preferences: resolvedLayoutPreferences)
        return ExercisePresentationState(
            scene: scene,
            surfaceStates: makeSurfaceStates(scene: scene),
            resolvedLayoutPreferences: resolvedLayoutPreferences,
            legacyPageDisplayState: ExerciseSceneValidator
                .legacyPageDisplayState(for: scene)
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名: normalizedPreferences(_:trainerDisplayState:), isCompositionPresetSupported(_:for:), isAccessoryPresentationSupported(_:)
// 功能说明: 修改后 legacy bridge 仍然对外保留原入口，但内部已切到新的 policy seam。
enum LegacyPageLayoutAdapter {
    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        ExerciseCompositionPolicy.normalizedPreferences(
            preferences,
            trainerDisplayState: trainerDisplayState
        )
    }

    static func isCompositionPresetSupported(
        _ preset: ExerciseCompositionPreset,
        for exerciseMode: TrainerExerciseMode
    ) -> Bool {
        ExerciseCompositionPolicy.isCompositionPresetSupported(
            preset,
            for: exerciseMode
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: fretboardLayoutContract
// 功能说明: 修改后 settings context 计算 fretboardLayoutContract 时，直接依赖 policy seam，而不是再走 validator 的 exercise 语义分支。
var fretboardLayoutContract: ExerciseFretboardLayoutContract {
    let resolvedPreferences = ExerciseCompositionPolicy.normalizedPreferences(
        exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState
    )
    let scene = ExerciseCompositionPolicy.makeScene(
        preferences: resolvedPreferences
    )
    return scene.fretboardLayoutContract
}
```

## 验证结果

- `ReadLints` 检查本次新增和修改的相关文件，未发现 diagnostics
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'generic/platform=iOS' build` 通过
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'generic/platform=macOS' build` 通过

```sh
# 文件路径: N/A（命令行验证）
# 函数名: N/A
# 功能说明: phase 1 完成后执行的时间戳、lint 与双平台编译验证命令。
date '+%Y%m%d_%H%M%S'
xcodebuild -list -project "NoteMaster_Ver_1.xcodeproj"
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'generic/platform=iOS' build
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'generic/platform=macOS' build
```

```text
# 文件路径: N/A（命令行验证结果）
# 函数名: N/A
# 功能说明: 本次记录对应的关键验证结果摘要。
时间戳: 20260407_161123
ReadLints: No linter errors found.
iOS build: succeeded
macOS build: succeeded
```

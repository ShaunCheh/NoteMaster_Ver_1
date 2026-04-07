# 20260407_163144_phase2_scene_core_play_policy_and_validation

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260407_163144`
- 记录范围：`play 模式分阶段计划` 的 `phase 2`
- 修改目标：
  - 把当前 `Exercise*` 体系里的通用 scene tree / surface contract / 通用 surface state 上提到 `Shared/Scene`
  - 让 `ExerciseScene` 与 `ExerciseSceneValidator` 退回到 exercise 专属语义兼容桥
  - 新增独立的 `play` scene policy 与 validation runner，证明 `piano-only` scene 已经可以脱离 exercise 语义存在
  - 在 iOS / macOS 启动阶段把 `play composition validation` 接进现有验证链
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/Scene/SceneCore.swift`
  - `NoteMaster_Ver_1/Shared/Scene/SceneValidator.swift`
  - `NoteMaster_Ver_1/Shared/Scene/ScenePresentationState.swift`
  - `NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`
  - `NoteMaster_Ver_1/Shared/Play/PlayCompositionPolicy.swift`
  - `NoteMaster_Ver_1/Shared/Play/PlayCompositionValidation.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- 本阶段刻意未直接修改：
  - `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`：为了不在同一阶段同时切 renderer 与 scene core，这一版先新增 `ScenePresentationState.swift`，现有 exercise renderer 继续沿用旧的 `ExercisePresentationState`

## 1. 新增 `SceneCore.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCore.swift
// 函数名: （文件不存在）
// 功能说明: 修改前还没有独立的通用 SceneCore，scene tree / surface contract 仍然寄生在 ExerciseScene.swift 中。
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCore.swift
// 函数名: SceneSurfaceProtocol, AppSurfaceNode, SceneNode, Scene
// 功能说明: 修改后新增真正的通用 scene core；exercise / play 只需要各自提供 surface 包装，就能共享同一套场景树与布局节点。
protocol SceneSurfaceProtocol {
    var id: AppSurfaceID { get }
    var presentationStyle: AppSurfacePresentationStyle { get }
}

nonisolated struct AppSurfaceNode: SceneSurfaceProtocol, Equatable, Sendable {
    var id: AppSurfaceID
    var kind: AppSurfaceKind
    var presentationStyle: AppSurfacePresentationStyle
}

indirect enum SceneNode<Surface: SceneSurfaceProtocol & Equatable & Sendable>:
    Equatable, Sendable {
    case surface(Surface)
    case split(axis: SceneAxis, children: [SceneSplitChild<Surface>])
    case overlay(base: SceneNode<Surface>, floating: [SceneNode<Surface>])
    case collapsible(
        main: SceneNode<Surface>,
        accessory: SceneNode<Surface>,
        isExpanded: Bool
    )
}

struct Scene<Surface: SceneSurfaceProtocol & Equatable & Sendable>: Equatable,
    Sendable {
    var root: SceneNode<Surface>

    static func singleSurface(_ surface: Surface) -> Scene<Surface> {
        Scene(root: .surface(surface))
    }
}
```

## 2. 新增 `SceneValidator.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneValidator.swift
// 函数名: （文件不存在）
// 功能说明: 修改前没有独立的通用结构校验层，重复 surface 与 vertical rail 等结构规则都写在 ExerciseSceneValidator.swift 里。
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneValidator.swift
// 函数名: validate(_:), validatePresentationStyles(in:withinHorizontalSplit:)
// 功能说明: 修改后把纯结构校验上提到 Shared/Scene，后续 exercise / play / 其他 mode 都可以复用同一套 validator。
enum SceneValidationIssue: Equatable, Sendable {
    case duplicateSurfaceID(AppSurfaceID)
    case verticalRailRequiresHorizontalSplit(AppSurfaceID)
}

enum SceneValidator {
    static func validate<Surface: SceneSurfaceProtocol & Equatable & Sendable>(
        _ scene: Scene<Surface>
    ) -> [SceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [SceneValidationIssue] = []

        for surfaceID in AppSurfaceID.allCases {
            let duplicateCount = surfaceNodes.filter { $0.id == surfaceID }.count
            if duplicateCount > 1 {
                issues.append(.duplicateSurfaceID(surfaceID))
            }
        }

        issues.append(
            contentsOf: validatePresentationStyles(
                in: scene.root,
                withinHorizontalSplit: false
            )
        )

        return issues
    }
}
```

## 3. 新增 `ScenePresentationState.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/ScenePresentationState.swift
// 函数名: （文件不存在）
// 功能说明: 修改前没有通用的 scene presentation state；可见性和交互性只存在于 ExercisePresentationState.swift 中。
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/ScenePresentationState.swift
// 函数名: projectedSurfaceState(for:), effectiveSurfaceState(for:), setSurfaceState(_:for:)
// 功能说明: 修改后新增 mode 无关的通用 surface state，只保留 visibility / interaction 这类根模式可共享的能力。
struct SceneSurfaceState: Equatable, Sendable {
    var isVisible: Bool
    var isInteractionEnabled: Bool

    static let hidden = SceneSurfaceState(
        isVisible: false,
        isInteractionEnabled: false
    )
    static let passive = SceneSurfaceState(
        isVisible: true,
        isInteractionEnabled: false
    )
    static let interactive = SceneSurfaceState(
        isVisible: true,
        isInteractionEnabled: true
    )
}

struct ScenePresentationState<Surface: SceneSurfaceProtocol & Equatable & Sendable>:
    Equatable, Sendable {
    var scene: Scene<Surface>
    private(set) var surfaceStates: [AppSurfaceID: SceneSurfaceState]

    func projectedSurfaceState(
        for surfaceID: AppSurfaceID
    ) -> SceneSurfaceState? {
        guard containsSurface(surfaceID) else {
            return nil
        }
        return surfaceStates[surfaceID] ?? .passive
    }
}
```

## 4. 更新 `SceneCoreCompatibility.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift
// 函数名: （文件级 typealias）
// 功能说明: 修改前这个兼容层只是把 App* 命名直接别名到 Exercise*，本质上还没有真正的通用 scene core。
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

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift
// 函数名: （文件级 typealias）
// 功能说明: 修改后 App* 命名正式指向 Shared/Scene 中的新 core，exercise 不再是 App scene 的底层实现本体。
typealias AppScene = Scene<AppSurfaceNode>
typealias AppSceneNode = SceneNode<AppSurfaceNode>
typealias AppSceneAxis = SceneAxis
typealias AppSceneSplitChild = SceneSplitChild<AppSurfaceNode>
typealias AppSceneSplitChildMainAxisSizing = SceneSplitChildMainAxisSizing
typealias AppSurfaceState = SceneSurfaceState
typealias AppPresentationState = ScenePresentationState<AppSurfaceNode>
```

## 5. 更新 `ExerciseScene.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSurfaceNode, ExerciseSceneNode, ExerciseScene
// 功能说明: 修改前 exercise 自己定义了完整的 surface / node / scene 树，通用能力和训练语义混在同一个文件里。
enum ExerciseSurfaceID: String, CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case targetPrompt
    case naturalNoteStrip
    case piano
}

enum ExerciseSceneAxis: String, Equatable, Hashable, Sendable {
    case vertical
    case horizontal
}

struct ExerciseSurfaceNode: Equatable, Sendable {
    var id: ExerciseSurfaceID
    var kind: ExerciseSurfaceKind
    private(set) var roles: Set<ExerciseRole>
    var presentationStyle: ExerciseSurfacePresentationStyle
}

indirect enum ExerciseSceneNode: Equatable, Sendable {
    case surface(ExerciseSurfaceNode)
    case split(axis: ExerciseSceneAxis, children: [ExerciseSceneSplitChild])
    case overlay(base: ExerciseSceneNode, floating: [ExerciseSceneNode])
    case collapsible(
        main: ExerciseSceneNode,
        accessory: ExerciseSceneNode,
        isExpanded: Bool
    )
}

struct ExerciseScene: Equatable, Sendable {
    var root: ExerciseSceneNode
}
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSurfaceNode, Scene.stacked(top:bottom:), Scene.sideBySide(leading:trailing:)
// 功能说明: 修改后 exercise 只保留训练语义包装；底层 scene tree 改由 Shared/Scene 承载，exercise 通过 typealias 和扩展回填既有 API。
typealias ExerciseSurfaceID = AppSurfaceID
typealias ExerciseSurfaceKind = AppSurfaceKind
typealias ExerciseSurfacePresentationStyle = AppSurfacePresentationStyle
typealias ExerciseSceneAxis = SceneAxis
typealias ExerciseSceneSplitChildMainAxisSizing = SceneSplitChildMainAxisSizing
typealias ExerciseSceneSplitChild = SceneSplitChild<ExerciseSurfaceNode>
typealias ExerciseSceneNode = SceneNode<ExerciseSurfaceNode>
typealias ExerciseScene = Scene<ExerciseSurfaceNode>

nonisolated struct ExerciseSurfaceNode: SceneSurfaceProtocol, Equatable, Sendable {
    private var baseSurface: AppSurfaceNode
    private(set) var roles: Set<ExerciseRole>

    var id: ExerciseSurfaceID {
        get { baseSurface.id }
        set { baseSurface.id = newValue }
    }

    var kind: ExerciseSurfaceKind {
        get { baseSurface.kind }
        set { baseSurface.kind = newValue }
    }

    var presentationStyle: ExerciseSurfacePresentationStyle {
        get { baseSurface.presentationStyle }
        set { baseSurface.presentationStyle = newValue }
    }
}

extension Scene where Surface == ExerciseSurfaceNode {
    static func stacked(
        top: ExerciseSurfaceNode,
        bottom: ExerciseSurfaceNode
    ) -> ExerciseScene {
        // 既有 stacked 组合逻辑仍保留在 exercise 侧，只是承载容器换成了通用 Scene。
        ExerciseScene(
            root: .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(node: .surface(top)),
                    ExerciseSceneSplitChild(node: .surface(bottom))
                ]
            )
        )
    }
}
```

## 6. 更新 `ExerciseSceneValidator.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: validate(_:), validatePresentationStyles(in:withinHorizontalSplit:)
// 功能说明: 修改前 ExerciseSceneValidator 既做 exercise 语义校验，也自己做重复 surface / vertical rail 的结构校验。
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

        if !surfaceNodes.contains(where: \.isPromptSurface) {
            issues.append(.missingPromptSurface)
        }
        if !surfaceNodes.contains(where: \.isAnswerSurface) {
            issues.append(.missingAnswerSurface)
        }

        issues.append(
            contentsOf: validatePresentationStyles(
                in: scene.root,
                withinHorizontalSplit: false
            )
        )

        return issues
    }
}
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: validate(_:), mapSceneValidationIssue(_:)
// 功能说明: 修改后结构规则统一委托给 SceneValidator；exercise 自己只补 prompt / answer 这类训练语义约束，并负责把通用问题映射回 exercise 枚举。
enum ExerciseSceneValidator {
    static func validate(
        _ scene: ExerciseScene
    ) -> [ExerciseSceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [ExerciseSceneValidationIssue] = SceneValidator.validate(scene).map {
            mapSceneValidationIssue($0)
        }

        if !surfaceNodes.contains(where: { $0.isPromptSurface }) {
            issues.append(ExerciseSceneValidationIssue.missingPromptSurface)
        }
        if !surfaceNodes.contains(where: { $0.isAnswerSurface }) {
            issues.append(ExerciseSceneValidationIssue.missingAnswerSurface)
        }

        return issues
    }

    private static func mapSceneValidationIssue(
        _ issue: SceneValidationIssue
    ) -> ExerciseSceneValidationIssue {
        switch issue {
        case let .duplicateSurfaceID(surfaceID):
            return .duplicateSurfaceID(surfaceID)
        case let .verticalRailRequiresHorizontalSplit(surfaceID):
            return .verticalRailRequiresHorizontalSplit(surfaceID)
        }
    }
}
```

## 7. 新增 `PlayCompositionPolicy.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Play/PlayCompositionPolicy.swift
// 函数名: （文件不存在）
// 功能说明: 修改前没有独立的 play policy；piano 仍然只存在于 exercise accessory 语义里。
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Play/PlayCompositionPolicy.swift
// 函数名: makePresentation(from:), makeScene()
// 功能说明: 修改后 play 侧第一次拥有独立 policy，直接输出 piano-only scene，不依赖 prompt / answer / LegacyPageLayoutAdapter。
typealias PlayScene = AppScene
typealias PlaySceneNode = AppSceneNode
typealias PlayPresentationState = AppPresentationState

struct PlayCompositionPolicyInput: Equatable, Sendable {
    var isPianoInteractive: Bool = true
}

enum PlayCompositionPolicy {
    static func makePresentation(
        from input: PlayCompositionPolicyInput = PlayCompositionPolicyInput()
    ) -> PlayPresentationState {
        PlayPresentationState(
            scene: makeScene(),
            surfaceStates: [
                .piano: input.isPianoInteractive ? .interactive : .passive
            ]
        )
    }

    static func makeScene() -> PlayScene {
        PlayScene.singleSurface(.piano)
    }
}
```

## 8. 新增 `PlayCompositionValidation.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Play/PlayCompositionValidation.swift
// 函数名: （文件不存在）
// 功能说明: 修改前没有针对 play scene 的 automated validation，piano-only scene 也没有独立的自动化回归入口。
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Play/PlayCompositionValidation.swift
// 函数名: run(platform:), runAndReportIfNeeded(platform:), validatePlayPolicyEmitsSinglePianoSurface(), validatePlayPolicyKeepsPianoVisibleAndInteractive()
// 功能说明: 修改后新增 play validation runner，自动检查 play policy 输出的 scene 是否只包含 piano，且 piano 默认可见、可交互。
enum PlayCompositionValidationRunner {
    static func run(
        platform: PlayCompositionValidationPlatform
    ) -> PlayCompositionValidationReport {
        let fixtures = makeFixtures()
        // ... 省略未改动的 runner 汇总逻辑 ...
        return PlayCompositionValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }
}

private extension PlayCompositionValidationRunner {
    static func makeFixtures() -> [PlayCompositionValidationFixture] {
        [
            PlayCompositionValidationFixture(
                name: "play_policy_emits_single_piano_surface",
                validate: validatePlayPolicyEmitsSinglePianoSurface
            ),
            PlayCompositionValidationFixture(
                name: "play_policy_keeps_piano_visible_and_interactive",
                validate: validatePlayPolicyKeepsPianoVisibleAndInteractive
            )
        ]
    }

    static func validatePlayPolicyEmitsSinglePianoSurface()
        -> [PlayCompositionValidationIssue] {
        let presentation = PlayCompositionPolicy.makePresentation()
        let structureIssues = SceneValidator.validate(presentation.scene)
        // 这里冻结 play scene 的根拓扑：只允许 1 个 piano surface，且不能混入其他 surface。
        // ... 省略其余 issue 组装逻辑 ...
        return issues
    }
}
```

## 9. 更新 `iOSAppDelegate.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改前 iOS 启动阶段只会跑已有 validation runner，还不会验证新的 play scene policy。
print("[Startup][iOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run exercise composition validation")
ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改后 iOS 启动时新增 play composition validation，让 piano-only scene 的基础契约进入既有 debug 验证链。
print("[Startup][iOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run play composition validation")
PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run exercise composition validation")
ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
```

## 10. 更新 `macOSAppDelegate.swift`

修改前：

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 修改前 macOS 启动阶段也还没有 play composition validation。
print("[Startup][macOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run exercise composition validation")
ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
```

修改后：

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 修改后 macOS 启动阶段同样接入 play composition validation，保证双平台都对 piano-only scene 做自动化守卫。
print("[Startup][macOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run play composition validation")
PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run exercise composition validation")
ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
```

## 验证结果

- `ReadLints`：本次修改涉及文件无新增诊断
- iOS Debug 构建通过：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build`
- macOS Debug 构建通过：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`

## 结果说明

- `phase 2` 完成后，通用 scene core 已经可以独立表达 `play` 的 `piano-only scene`
- 当前 `play` 还只是模型层 / validation 层打通，真实页面壳层与 settings 分流仍然留在后续 `phase 3` / `phase 4`
- 这次补上的 `nonisolated struct AppSurfaceNode` / `nonisolated struct ExerciseSurfaceNode` 属于 phase 2 实施过程中的编译根因修正，最终状态已经包含在上面的“修改后”代码片段中

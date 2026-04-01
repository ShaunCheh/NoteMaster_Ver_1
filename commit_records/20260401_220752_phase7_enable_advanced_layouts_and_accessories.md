# 20260401_220752_phase7_enable_advanced_layouts_and_accessories

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_220752`
- 记录范围：`场景树迁移` 计划的阶段 7；正式开启高级布局与辅助区
- 修改性质：让 `ExerciseCompositionPolicy` / `ExerciseSceneValidator` 生成高级 scene tree；iOS / macOS renderer 改为递归渲染 `split / overlay / collapsible`；钢琴和可选 `naturalNoteStrip` 不再由控制器在页面底部外挂
- 修改统计：`13 files changed, 1418 insertions(+), 601 deletions(-)`
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. `ExerciseScene` 与 `ExercisePresentationState` 显式区分 answer strip 和 accessory strip

- 修改前：shared contract 里只有 `naturalNoteStripAnswer` 这一种 strip surface，`ExercisePresentationState` 也只会按 surface 本身的 roles 给默认状态，不理解 `collapsible` 收起后的可见性继承。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSurfaceNode.naturalNoteStripAnswer, ExerciseSurfaceNode.pianoAccessory
// 功能说明: 修改前只有 answer 语义的 natural note strip，没有独立的 accessory strip 节点。
extension ExerciseSurfaceNode {
    static let naturalNoteStripAnswer = ExerciseSurfaceNode(
        id: .naturalNoteStrip,
        kind: .naturalNoteStrip,
        roles: [.answer]
    )
    static let pianoAccessory = ExerciseSurfaceNode(
        id: .piano,
        kind: .piano,
        roles: [.auxiliary]
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseSurfaceState.init(surface:isVisible:), ExercisePresentationState.surfaceState(for:)
// 功能说明: 修改前默认 surface state 只看 surface 本身的 roles，不会沿 scene tree 继续传播 overlay/collapsible 的可见性。
struct ExerciseSurfaceState: Equatable, Sendable {
    init(
        surface: ExerciseSurfaceNode,
        isVisible: Bool = true
    ) {
        self.init(
            isVisible: isVisible,
            isPromptActive: surface.isPromptSurface,
            isAnswerEnabled: surface.isAnswerSurface,
            isInteractionEnabled: surface.isAnswerSurface
                || surface.isAuxiliarySurface
        )
    }
}

struct ExercisePresentationState: Equatable, Sendable {
    func surfaceState(
        for surfaceID: ExerciseSurfaceID
    ) -> ExerciseSurfaceState? {
        if let state = surfaceStates[surfaceID] {
            return state
        }

        guard let surface = scene.surfaceNode(for: surfaceID) else {
            return nil
        }

        return ExerciseSurfaceState(surface: surface)
    }
}
```

- 修改后：新增 `naturalNoteStripAccessory`，把 strip 的 answer / auxiliary 语义拆开；`ExercisePresentationState` 改成按 scene tree 递归推导默认状态，`collapsible` 收起的 accessory 会自动变成不可见、不可交互，auxiliary surface 里只有钢琴默认保留交互。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSurfaceNode.naturalNoteStripAnswer, ExerciseSurfaceNode.naturalNoteStripAccessory, ExerciseSurfaceNode.pianoAccessory
// 功能说明: 修改后 shared contract 明确区分 natural note strip 的 answer surface 与 accessory surface。
extension ExerciseSurfaceNode {
    static let naturalNoteStripAnswer = ExerciseSurfaceNode(
        id: .naturalNoteStrip,
        kind: .naturalNoteStrip,
        roles: [.answer]
    )
    static let naturalNoteStripAccessory = ExerciseSurfaceNode(
        id: .naturalNoteStrip,
        kind: .naturalNoteStrip,
        roles: [.auxiliary]
    )
    static let pianoAccessory = ExerciseSurfaceNode(
        id: .piano,
        kind: .piano,
        roles: [.auxiliary]
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseSurfaceState.init(surface:isVisible:), ExerciseSurfaceState.defaultInteractionEnabled(for:), ExercisePresentationState.surfaceState(for:), ExercisePresentationState.defaultSurfaceState(for:in:inheritedVisibility:)
// 功能说明: 修改后 surface state 会沿 overlay/collapsible scene tree 递归推导；隐藏的 accessory 自动丢失可见性与交互能力。
struct ExerciseSurfaceState: Equatable, Sendable {
    init(
        surface: ExerciseSurfaceNode,
        isVisible: Bool = true
    ) {
        self.init(
            isVisible: isVisible,
            isPromptActive: isVisible && surface.isPromptSurface,
            isAnswerEnabled: isVisible && surface.isAnswerSurface,
            isInteractionEnabled: isVisible
                && Self.defaultInteractionEnabled(for: surface)
        )
    }

    private static func defaultInteractionEnabled(
        for surface: ExerciseSurfaceNode
    ) -> Bool {
        if surface.isAnswerSurface {
            return true
        }

        if surface.isAuxiliarySurface {
            return surface.id == .piano
        }

        return false
    }
}

struct ExercisePresentationState: Equatable, Sendable {
    func surfaceState(
        for surfaceID: ExerciseSurfaceID
    ) -> ExerciseSurfaceState? {
        if let state = surfaceStates[surfaceID] {
            return state
        }

        return defaultSurfaceState(
            for: surfaceID,
            in: scene.root,
            inheritedVisibility: true
        )
    }

    private func defaultSurfaceState(
        for surfaceID: ExerciseSurfaceID,
        in node: ExerciseSceneNode,
        inheritedVisibility: Bool
    ) -> ExerciseSurfaceState? {
        switch node {
        case let .surface(surface):
            guard surface.id == surfaceID else {
                return nil
            }
            return ExerciseSurfaceState(
                surface: surface,
                isVisible: inheritedVisibility
            )
        case let .split(_, children):
            return children.compactMap {
                defaultSurfaceState(
                    for: surfaceID,
                    in: $0.node,
                    inheritedVisibility: inheritedVisibility
                )
            }.first
        case let .overlay(base, floating):
            if let match = defaultSurfaceState(
                for: surfaceID,
                in: base,
                inheritedVisibility: inheritedVisibility
            ) {
                return match
            }
            return floating.compactMap {
                defaultSurfaceState(
                    for: surfaceID,
                    in: $0,
                    inheritedVisibility: inheritedVisibility
                )
            }.first
        case let .collapsible(main, accessory, isExpanded):
            if let match = defaultSurfaceState(
                for: surfaceID,
                in: main,
                inheritedVisibility: inheritedVisibility
            ) {
                return match
            }
            return defaultSurfaceState(
                for: surfaceID,
                in: accessory,
                inheritedVisibility: inheritedVisibility && isExpanded
            )
        }
    }
}
```

## 2. `ExerciseSceneValidator` 不再把高级布局和 accessory 语义提前归零

- 修改前：validator 仍把 `fretboardSelfAnswer` 强制压回 `singleSurface`，只承认 `stacked / sideBySide`，而 `floating / collapsible` 也会被归一化回 `.docked`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: ExerciseSceneValidator.normalizedPreferences(...), ExerciseSceneValidator.isMultiSurfaceLayoutSemanticallySupported(...), ExerciseSceneValidator.isAccessoryPresentationSemanticallySupported(...)
// 功能说明: 修改前 advanced layout 和 accessory presentation 还没有正式开放。
enum ExerciseSceneValidator {
    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        var normalized = preferences

        switch normalized.compositionPreset {
        case .staffToFretboard,
             .targetPromptToFretboard,
             .fretboardToNaturalNoteStrip:
            if !isMultiSurfaceLayoutSemanticallySupported(
                normalized.layoutPreset
            ) {
                normalized.layoutPreset = .stacked
            }
        case .fretboardSelfAnswer:
            normalized.layoutPreset = .singleSurface
        }

        if !isAccessoryPresentationSemanticallySupported(
            normalized.accessoryPresentation
        ) {
            normalized.accessoryPresentation = .docked
        }
        if normalized.accessoryPresentation != .collapsible {
            normalized.isAccessoryExpanded = true
        }

        normalized.isNaturalNoteStripVisible = normalized.compositionPreset
            == .fretboardToNaturalNoteStrip
        return normalized
    }

    static func isMultiSurfaceLayoutSemanticallySupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        switch preset {
        case .stacked, .sideBySide:
            return true
        case .singleSurface,
             .threePane,
             .overlay,
             .collapsibleAccessory:
            return false
        }
    }

    static func isAccessoryPresentationSemanticallySupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        presentation == .docked
    }
}
```

- 修改后：validator 会保留高级布局语义，只在真正不合法的组合上兜底；`threePane / overlay / collapsibleAccessory` 以及 `docked / floating / collapsible` 都进入正式支持集合。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: ExerciseSceneValidator.normalizedPreferences(...), ExerciseSceneValidator.isMultiSurfaceLayoutSemanticallySupported(...), ExerciseSceneValidator.isSelfAnswerLayoutSemanticallySupported(...), ExerciseSceneValidator.isAccessoryPresentationSemanticallySupported(...)
// 功能说明: 修改后 validator 负责守住语义边界，但不再提前抹掉阶段 7 打开的高级布局能力。
enum ExerciseSceneValidator {
    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        var normalized = preferences

        switch normalized.compositionPreset {
        case .staffToFretboard,
             .targetPromptToFretboard,
             .fretboardToNaturalNoteStrip:
            if !isMultiSurfaceLayoutSemanticallySupported(
                normalized.layoutPreset
            ) {
                normalized.layoutPreset = .stacked
            }
        case .fretboardSelfAnswer:
            if !isSelfAnswerLayoutSemanticallySupported(
                normalized.layoutPreset
            ) {
                normalized.layoutPreset = .singleSurface
            }
        }

        if !isAccessoryPresentationSemanticallySupported(
            normalized.accessoryPresentation
        ) {
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

    static func isMultiSurfaceLayoutSemanticallySupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        switch preset {
        case .stacked,
             .sideBySide,
             .threePane,
             .overlay,
             .collapsibleAccessory:
            return true
        case .singleSurface:
            return false
        }
    }

    static func isSelfAnswerLayoutSemanticallySupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        switch preset {
        case .singleSurface,
             .threePane,
             .overlay,
             .collapsibleAccessory:
            return true
        case .stacked, .sideBySide:
            return false
        }
    }

    static func isAccessoryPresentationSemanticallySupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        switch presentation {
        case .docked, .floating, .collapsible:
            return true
        }
    }
}
```

## 3. `ExerciseCompositionPolicy` 正式生成 accessory scene node，`LegacyPageLayoutAdapter` 只保留 bridge 兜底

- 修改前：policy 还会把 `threePane / overlay / collapsibleAccessory` 全部退回 `stacked`，`makeSurfaceStates(...)` 也直接把钢琴显隐塞进平面字典；adapter 侧则把 accessory 能力统一标记成不支持。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: ExerciseCompositionPolicy.makePresentation(...), ExerciseCompositionPolicy.makeScene(...), ExerciseCompositionPolicy.makeSurfaceStates(...)
// 功能说明: 修改前 shared policy 还没有真正生成 accessory subtree，高级布局都被压回 legacy 可投影组合。
enum ExerciseCompositionPolicy {
    static func makePresentation(
        from input: ExerciseCompositionPolicyInput
    ) -> ExercisePresentationState {
        let resolvedLayoutPreferences = ExerciseSceneValidator
            .normalizedPreferences(
                input.layoutPreferences,
                trainerDisplayState: input.trainerDisplayState
            )
        let scene = makeScene(
            preferences: resolvedLayoutPreferences
        )

        return ExercisePresentationState(
            scene: scene,
            surfaceStates: makeSurfaceStates(
                scene: scene,
                input: input,
                resolvedLayoutPreferences: resolvedLayoutPreferences
            ),
            resolvedLayoutPreferences: resolvedLayoutPreferences,
            legacyPageDisplayState: ExerciseSceneValidator
                .legacyPageDisplayState(for: scene)
        )
    }

    static func makeScene(
        preferences: ExerciseLayoutPreferences
    ) -> ExerciseScene {
        let sceneSurfaces = resolvedSceneSurfaces(
            for: preferences
        )

        switch preferences.layoutPreset {
        case .stacked:
            return .stacked(
                top: sceneSurfaces.prompt,
                bottom: sceneSurfaces.answer
            )
        case .sideBySide:
            return .sideBySide(
                leading: sceneSurfaces.prompt,
                trailing: sceneSurfaces.answer
            )
        case .singleSurface:
            return .singleSurface(sceneSurfaces.prompt)
        case .threePane, .overlay, .collapsibleAccessory:
            return .stacked(
                top: sceneSurfaces.prompt,
                bottom: sceneSurfaces.answer
            )
        }
    }

    private static func makeSurfaceStates(
        scene: ExerciseScene,
        input: ExerciseCompositionPolicyInput,
        resolvedLayoutPreferences: ExerciseLayoutPreferences
    ) -> [ExerciseSurfaceID: ExerciseSurfaceState] {
        // ... 中间字典初始化省略
        if var naturalNoteStripState = surfaceStates[.naturalNoteStrip] {
            naturalNoteStripState.isVisible = resolvedLayoutPreferences
                .isNaturalNoteStripVisible
            naturalNoteStripState.isInteractionEnabled = naturalNoteStripState
                .isVisible
                && naturalNoteStripState.isAnswerEnabled
            surfaceStates[.naturalNoteStrip] = naturalNoteStripState
        }

        surfaceStates[.piano] = resolvedLayoutPreferences.isPianoAccessoryVisible
            || input.pianoPanelState.isVisible
            ? .auxiliaryOnly
            : .hidden
        return surfaceStates
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名: LegacyPageLayoutAdapter.isAccessoryPresentationSupported(...), LegacyPageLayoutAdapter.isNaturalStripToggleSupported(...), LegacyPageLayoutAdapter.isAccessoryExpandedSupported(...)
// 功能说明: 修改前 settings 侧仍然把 accessory 高级能力视为未开放。
enum LegacyPageLayoutAdapter {
    static func isAccessoryPresentationSupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        let legacyCompatiblePreferences = ExerciseCompositionPolicy
            .legacyCompatiblePreferences(
                from: policyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .single
                    ),
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: .stacked,
                        accessoryPresentation: presentation
                    )
                )
            )
        return legacyCompatiblePreferences.accessoryPresentation == presentation
    }

    static func isNaturalStripToggleSupported(
        in _: SettingsPanelStateContext
    ) -> Bool {
        false
    }

    static func isAccessoryExpandedSupported(
        accessoryPresentation _: ExerciseAccessoryPresentation
    ) -> Bool {
        false
    }
}
```

- 修改后：policy 先拼 main scene，再按 `natural strip / piano / accessoryPresentation` 生成 accessory subtree，并用 `overlay / collapsible / docked split` 包装回 root；legacy bridge 会主动清掉超出旧 page model 的 accessory scene，只保留可投影的主视觉组合。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: ExerciseCompositionPolicy.makePresentation(...), ExerciseCompositionPolicy.legacyCompatiblePreferences(...), ExerciseCompositionPolicy.makeScene(...), ExerciseCompositionPolicy.makeAccessorySceneNode(...), ExerciseCompositionPolicy.wrapMainSceneNode(...)
// 功能说明: 修改后 shared policy 正式生成 accessory scene tree；legacy compatible 路径只保留旧 page model 能表达的主视觉。
enum ExerciseCompositionPolicy {
    static func makePresentation(
        from input: ExerciseCompositionPolicyInput
    ) -> ExercisePresentationState {
        var resolvedLayoutPreferences = ExerciseSceneValidator
            .normalizedPreferences(
                input.layoutPreferences,
                trainerDisplayState: input.trainerDisplayState
            )
        resolvedLayoutPreferences.isPianoAccessoryVisible = resolvedLayoutPreferences
            .isPianoAccessoryVisible
            || input.pianoPanelState.isVisible
        let scene = makeScene(
            preferences: resolvedLayoutPreferences
        )

        return ExercisePresentationState(
            scene: scene,
            surfaceStates: makeSurfaceStates(scene: scene),
            resolvedLayoutPreferences: resolvedLayoutPreferences,
            legacyPageDisplayState: ExerciseSceneValidator
                .legacyPageDisplayState(for: scene)
        )
    }

    static func legacyCompatiblePreferences(
        from input: ExerciseCompositionPolicyInput
    ) -> ExerciseLayoutPreferences {
        let resolvedPreferences = ExerciseSceneValidator.normalizedPreferences(
            input.layoutPreferences,
            trainerDisplayState: input.trainerDisplayState
        )
        var legacyCompatiblePreferences = resolvedPreferences

        legacyCompatiblePreferences.layoutPreset = .stacked
        legacyCompatiblePreferences.accessoryPresentation = .docked
        legacyCompatiblePreferences.isNaturalNoteStripVisible = false
        legacyCompatiblePreferences.isPianoAccessoryVisible = false
        legacyCompatiblePreferences.isAccessoryExpanded = true
        // ... exerciseMode 兼容兜底省略
        return legacyCompatiblePreferences
    }

    static func makeScene(
        preferences: ExerciseLayoutPreferences
    ) -> ExerciseScene {
        let sceneSurfaces = resolvedSceneSurfaces(
            for: preferences
        )
        let mainSceneNode = makeMainSceneNode(
            from: sceneSurfaces,
            preferences: preferences
        )
        let accessorySceneNode = makeAccessorySceneNode(
            preferences: preferences
        )

        guard let accessorySceneNode else {
            return ExerciseScene(root: mainSceneNode)
        }

        return ExerciseScene(
            root: wrapMainSceneNode(
                mainSceneNode,
                accessorySceneNode: accessorySceneNode,
                preferences: preferences
            )
        )
    }

    private static func makeAccessorySceneNode(
        preferences: ExerciseLayoutPreferences
    ) -> ExerciseSceneNode? {
        var accessoryChildren: [ExerciseSceneSplitChild] = []

        if preferences.isNaturalNoteStripVisible,
           preferences.compositionPreset != .fretboardToNaturalNoteStrip {
            accessoryChildren.append(
                ExerciseSceneSplitChild(
                    node: .surface(.naturalNoteStripAccessory),
                    weight: 0.7
                )
            )
        }

        if preferences.isPianoAccessoryVisible {
            accessoryChildren.append(
                ExerciseSceneSplitChild(
                    node: .surface(.pianoAccessory),
                    weight: 1.3
                )
            )
        }

        switch accessoryChildren.count {
        case 0:
            return nil
        case 1:
            return accessoryChildren[0].node
        default:
            return .makeSplit(
                axis: .vertical,
                children: accessoryChildren
            )
        }
    }

    private static func wrapMainSceneNode(
        _ mainSceneNode: ExerciseSceneNode,
        accessorySceneNode: ExerciseSceneNode,
        preferences: ExerciseLayoutPreferences
    ) -> ExerciseSceneNode {
        switch resolvedAccessoryStrategy(for: preferences) {
        case .docked:
            return .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(node: mainSceneNode, weight: 3),
                    ExerciseSceneSplitChild(
                        node: accessorySceneNode,
                        weight: accessoryWeight(for: accessorySceneNode)
                    )
                ]
            )
        case .floating:
            return .makeOverlay(
                base: mainSceneNode,
                floating: [accessorySceneNode]
            )
        case .collapsible:
            return .makeCollapsible(
                main: mainSceneNode,
                accessory: accessorySceneNode,
                isExpanded: preferences.isAccessoryExpanded
            )
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名: LegacyPageLayoutAdapter.isAccessoryPresentationSupported(...), LegacyPageLayoutAdapter.isNaturalStripToggleSupported(...), LegacyPageLayoutAdapter.isAccessoryExpandedSupported(...)
// 功能说明: 修改后 settings 只对真正需要禁用的组合做语义约束，不再把阶段 7 能力整体锁死。
enum LegacyPageLayoutAdapter {
    static func isAccessoryPresentationSupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        ExerciseSceneValidator.isAccessoryPresentationSemanticallySupported(
            presentation
        )
    }

    static func isNaturalStripToggleSupported(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        stateContext.exerciseLayoutPreferences.compositionPreset
            != .fretboardToNaturalNoteStrip
    }

    static func isAccessoryExpandedSupported(
        accessoryPresentation: ExerciseAccessoryPresentation
    ) -> Bool {
        accessoryPresentation == .collapsible
    }
}
```

## 4. iOS / macOS renderer 从“双面板专用”升级成递归 scene tree renderer

- 修改前：两个平台的 renderer 都只认识 `primarySurface + secondarySurface` 这一层平面布局，`piano` 也不属于 renderer 管辖范围。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.render(...), iOSExerciseSceneRenderer.applyArrangement(...), iOSExerciseSceneRenderer.view(for:)
// 功能说明: 修改前 iOS renderer 只能吃投影后的双面板 layout，piano 不是 scene surface。
final class iOSExerciseSceneRenderer {
    private let primarySurfaceHostView = UIView()
    private let primarySurfaceContentView = UIView()
    private let secondarySurfaceHostView = UIView()
    private let secondarySurfaceContentView = UIView()
    private var activeArrangementConstraints: [NSLayoutConstraint] = []
    private var primarySurfaceConstraints: [NSLayoutConstraint] = []
    private var secondarySurfaceConstraints: [NSLayoutConstraint] = []

    func render(
        presentationState: ExercisePresentationState,
        fretboardDisplayState: FretboardDisplayState
    ) {
        currentPresentationState = presentationState
        currentFretboardDisplayState = fretboardDisplayState

        guard let resolvedLayout = resolvedLayout(from: presentationState) else {
            hideAllSurfaceHosts()
            rebuildVerticalFretboardHostHeightConstraint()
            updateFretboardLayoutModeConstraints()
            return
        }

        applyArrangement(resolvedLayout)
        apply(
            resolvedLayout.primarySurface,
            to: primarySurfaceContentView,
            storedConstraints: &primarySurfaceConstraints
        )
        // ... secondary surface 省略
    }

    private func view(for surfaceID: ExerciseSurfaceID) -> UIView? {
        switch surfaceID {
        case .staff:
            return staffView
        case .targetPrompt:
            return targetNotePromptView
        case .fretboard:
            return fretboardHostView
        case .naturalNoteStrip:
            return naturalNoteStripView
        case .piano:
            return nil
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: macOSExerciseSceneRenderer.render(...), macOSExerciseSceneRenderer.applyArrangement(...), macOSExerciseSceneRenderer.view(for:)
// 功能说明: 修改前 macOS renderer 也是同一套双面板假设，无法直接渲染 overlay / collapsible accessory。
final class macOSExerciseSceneRenderer {
    private let primarySurfaceHostView = NSView()
    private let primarySurfaceContentView = NSView()
    private let secondarySurfaceHostView = NSView()
    private let secondarySurfaceContentView = NSView()
    private var activeArrangementConstraints: [NSLayoutConstraint] = []
    private var primarySurfaceConstraints: [NSLayoutConstraint] = []
    private var secondarySurfaceConstraints: [NSLayoutConstraint] = []

    func render(
        presentationState: ExercisePresentationState,
        fretboardDisplayState: FretboardDisplayState
    ) {
        currentPresentationState = presentationState
        currentFretboardDisplayState = fretboardDisplayState

        guard let resolvedLayout = resolvedLayout(from: presentationState) else {
            hideAllSurfaceHosts()
            rebuildVerticalFretboardHostHeightConstraint()
            updateFretboardLayoutModeConstraints()
            return
        }

        applyArrangement(resolvedLayout)
        // ... primary / secondary host 省略
    }

    private func view(for surfaceID: ExerciseSurfaceID) -> NSView? {
        switch surfaceID {
        case .staff:
            return staffView
        case .targetPrompt:
            return targetNotePromptView
        case .fretboard:
            return fretboardHostView
        case .naturalNoteStrip:
            return naturalNoteStripView
        case .piano:
            return nil
        }
    }
}
```

- 修改后：两个平台都改成以 `sceneContentView + activeSceneConstraints` 递归渲染整棵 `ExerciseSceneNode`；`pianoAccessoryView` 进入 renderer，`split / overlay / collapsible` 都由 renderer 直接落成约束树。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.init(...), iOSExerciseSceneRenderer.render(...), iOSExerciseSceneRenderer.rebuildSceneHierarchy(...), iOSExerciseSceneRenderer.render(node:in:), iOSExerciseSceneRenderer.renderOverlay(...), iOSExerciseSceneRenderer.renderCollapsible(...), iOSExerciseSceneRenderer.view(for:)
// 功能说明: 修改后 iOS renderer 直接递归渲染 scene tree，并把 piano accessory 收编进 renderer 自己的布局域。
final class iOSExerciseSceneRenderer {
    private let sceneContentView = UIView()
    private let pianoAccessoryView: UIView
    private var activeSceneConstraints: [NSLayoutConstraint] = []

    init(
        safeAreaHeightAnchor: NSLayoutDimension,
        metrics: Metrics,
        sequenceRegenerateButton: UIButton,
        staffView: iOSStaffView,
        targetNotePromptView: iOSTargetNotePromptView,
        naturalNoteStripView: iOSNaturalNoteStripView,
        pianoAccessoryView: UIView,
        fretboardView: iOSFretboardView
    ) {
        self.safeAreaHeightAnchor = safeAreaHeightAnchor
        self.metrics = metrics
        self.sequenceRegenerateButton = sequenceRegenerateButton
        self.staffView = staffView
        self.targetNotePromptView = targetNotePromptView
        self.naturalNoteStripView = naturalNoteStripView
        self.pianoAccessoryView = pianoAccessoryView
        self.fretboardView = fretboardView
        configureStaticHierarchy()
    }

    func render(
        presentationState: ExercisePresentationState,
        fretboardDisplayState: FretboardDisplayState
    ) {
        currentPresentationState = presentationState
        currentFretboardDisplayState = fretboardDisplayState
        rebuildSceneHierarchy(for: presentationState.scene.root)
        updateSurfaceVisibility()
        rebuildVerticalFretboardHostHeightConstraint()
        updateFretboardLayoutModeConstraints()
    }

    private func rebuildSceneHierarchy(
        for rootNode: ExerciseSceneNode
    ) {
        NSLayoutConstraint.deactivate(activeSceneConstraints)
        activeSceneConstraints = []
        sceneContentView.subviews.forEach { $0.removeFromSuperview() }
        // ... root host 建立省略
        render(node: rootNode, in: rootHostView)
        NSLayoutConstraint.activate(activeSceneConstraints)
    }

    private func render(
        node: ExerciseSceneNode,
        in hostView: UIView
    ) {
        switch node {
        case let .surface(surface):
            renderSurface(surface, in: hostView)
        case let .split(axis, children):
            renderSplit(axis: axis, children: children, in: hostView)
        case let .overlay(base, floating):
            renderOverlay(base: base, floating: floating, in: hostView)
        case let .collapsible(main, accessory, isExpanded):
            renderCollapsible(
                main: main,
                accessory: accessory,
                isExpanded: isExpanded,
                in: hostView
            )
        }
    }

    private func renderOverlay(
        base: ExerciseSceneNode,
        floating: [ExerciseSceneNode],
        in hostView: UIView
    ) {
        // ... base host 省略
        let floatingHostView = UIView()
        floatingHostView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(floatingHostView)
        activeSceneConstraints.append(contentsOf: [
            floatingHostView.leadingAnchor.constraint(
                equalTo: hostView.leadingAnchor,
                constant: metrics.surfaceSpacing
            ),
            floatingHostView.trailingAnchor.constraint(
                equalTo: hostView.trailingAnchor,
                constant: -metrics.surfaceSpacing
            ),
            floatingHostView.bottomAnchor.constraint(
                equalTo: hostView.bottomAnchor,
                constant: -metrics.surfaceSpacing
            )
        ])
        // ... floating subtree 继续递归
    }

    private func renderCollapsible(
        main: ExerciseSceneNode,
        accessory: ExerciseSceneNode,
        isExpanded: Bool,
        in hostView: UIView
    ) {
        let mainHostView = UIView()
        // ... main host 省略
        guard isExpanded else {
            activeSceneConstraints.append(
                mainHostView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
            )
            return
        }
        // ... accessory host 省略
    }

    private func view(for surfaceID: ExerciseSurfaceID) -> UIView? {
        switch surfaceID {
        case .staff:
            return staffView
        case .targetPrompt:
            return targetNotePromptView
        case .fretboard:
            return fretboardHostView
        case .naturalNoteStrip:
            return naturalNoteStripView
        case .piano:
            return pianoAccessoryView
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: macOSExerciseSceneRenderer.init(...), macOSExerciseSceneRenderer.render(...), macOSExerciseSceneRenderer.rebuildSceneHierarchy(...), macOSExerciseSceneRenderer.render(node:in:), macOSExerciseSceneRenderer.renderOverlay(...), macOSExerciseSceneRenderer.renderCollapsible(...), macOSExerciseSceneRenderer.view(for:)
// 功能说明: 修改后 macOS renderer 与 iOS 保持同一套 scene tree 渲染语义，只是约束宿主换成 NSView/NSScrollView。
final class macOSExerciseSceneRenderer {
    private let sceneContentView = NSView()
    private let pianoAccessoryView: NSView
    private var activeSceneConstraints: [NSLayoutConstraint] = []

    func render(
        presentationState: ExercisePresentationState,
        fretboardDisplayState: FretboardDisplayState
    ) {
        currentPresentationState = presentationState
        currentFretboardDisplayState = fretboardDisplayState
        rebuildSceneHierarchy(for: presentationState.scene.root)
        updateSurfaceVisibility()
        rebuildVerticalFretboardHostHeightConstraint()
        updateFretboardLayoutModeConstraints()
    }

    private func render(
        node: ExerciseSceneNode,
        in hostView: NSView
    ) {
        switch node {
        case let .surface(surface):
            renderSurface(surface, in: hostView)
        case let .split(axis, children):
            renderSplit(axis: axis, children: children, in: hostView)
        case let .overlay(base, floating):
            renderOverlay(base: base, floating: floating, in: hostView)
        case let .collapsible(main, accessory, isExpanded):
            renderCollapsible(
                main: main,
                accessory: accessory,
                isExpanded: isExpanded,
                in: hostView
            )
        }
    }

    private func view(for surfaceID: ExerciseSurfaceID) -> NSView? {
        switch surfaceID {
        case .staff:
            return staffView
        case .targetPrompt:
            return targetNotePromptView
        case .fretboard:
            return fretboardHostView
        case .naturalNoteStrip:
            return naturalNoteStripView
        case .piano:
            return pianoAccessoryView
        }
    }
}
```

## 5. iOS / macOS 控制器清理钢琴“页面底部外挂”路径

- 修改前：控制器自己维护 `pianoDemoContainerView -> contentView.bottomAnchor` 的额外壳层约束，并通过 `applyPianoDemoState()` 手动切换主内容与钢琴容器的 bottom constraint。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.debugStateSnapshot(), iOSViewController.configureLayout(), iOSViewController.applyPianoDemoState()
// 功能说明: 修改前 iOS 控制器仍直接把钢琴容器挂在 sceneContainerView 下面。
final class iOSViewController: UIViewController {
    private func debugStateSnapshot() -> String {
        "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
        "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
        "composition=\(String(describing: exerciseLayoutPreferences.compositionPreset)) " +
        "layout=\(String(describing: exerciseLayoutPreferences.layoutPreset)) " +
        "displayMode=\(String(describing: displayState.displayMode)) " +
        "showsFretboard=\(isShowingFretboard) " +
        "settingsPresented=\(isSettingsPresented)"
    }

    private let pianoDemoContainerView = UIView()
    private var pianoDemoBottomToContentConstraint: NSLayoutConstraint?
    private var mainContentBottomToContentConstraint: NSLayoutConstraint?

    private func configureLayout() {
        contentView.addSubview(exerciseSceneRenderer.sceneContainerView)
        contentView.addSubview(pianoDemoContainerView)
        pianoDemoBottomToContentConstraint = pianoDemoContainerView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
        mainContentBottomToContentConstraint = exerciseSceneRenderer.sceneContainerView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
        // ... 其余约束省略
    }

    private func applyPianoDemoState() {
        pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
        pianoKeyboardView.rows = resolvedPianoDemoRows
        pianoKeyboardView.showsComponentBoundsOverlay = false
        pianoDemoContainerView.isHidden = !pianoPanelState.isVisible
        pianoDemoBottomToContentConstraint?.isActive = pianoPanelState.isVisible
        mainContentBottomToContentConstraint?.isActive = !pianoPanelState.isVisible
        updatePianoDemoStatusLabel()
        updateLayoutIfNeeded()
        exerciseSceneRenderer.handleLayoutPass()
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.debugStateSnapshot(), macOSViewController.configureLayout(), macOSViewController.applyPianoDemoState()
// 功能说明: 修改前 macOS 控制器也保留了同样的底部外挂钢琴容器路径。
final class macOSViewController: NSViewController {
    private func debugStateSnapshot() -> String {
        "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
        "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
        "composition=\(String(describing: exerciseLayoutPreferences.compositionPreset)) " +
        "layout=\(String(describing: exerciseLayoutPreferences.layoutPreset)) " +
        "displayMode=\(String(describing: displayState.displayMode)) " +
        "showsFretboard=\(isShowingFretboard) " +
        "settingsPresented=\(isSettingsPresented)"
    }

    private let pianoDemoContainerView = NSView()
    private var pianoDemoBottomToContentConstraint: NSLayoutConstraint?
    private var mainContentBottomToContentConstraint: NSLayoutConstraint?

    private func applyPianoDemoState() {
        pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
        pianoKeyboardView.rows = resolvedPianoDemoRows
        pianoKeyboardView.showsComponentBoundsOverlay = false
        pianoDemoContainerView.isHidden = !pianoPanelState.isVisible
        pianoDemoBottomToContentConstraint?.isActive = pianoPanelState.isVisible
        mainContentBottomToContentConstraint?.isActive = !pianoPanelState.isVisible
        updatePianoDemoStatusLabel()
        updateLayoutIfNeeded()
        exerciseSceneRenderer.handleLayoutPass()
    }
}
```

- 修改后：控制器只保留钢琴内容状态，不再决定钢琴在页面上的空间位置；`pianoDemoContainerView` 作为 `pianoAccessoryView` 传给 renderer，自身不再参与 `contentView` 的外部布局链。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.debugStateSnapshot(), iOSViewController.exerciseSceneRenderer, iOSViewController.configureLayout(), iOSViewController.applyPianoDemoState()
// 功能说明: 修改后 iOS 控制器只负责钢琴内容刷新，scene 位置完全交给 renderer。
final class iOSViewController: UIViewController {
    private func debugStateSnapshot() -> String {
        "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
        "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
        "composition=\(String(describing: exerciseLayoutPreferences.compositionPreset)) " +
        "layout=\(String(describing: exerciseLayoutPreferences.layoutPreset)) " +
        "accessory=\(String(describing: exerciseLayoutPreferences.accessoryPresentation)) " +
        "piano=\(exerciseLayoutPreferences.isPianoAccessoryVisible) " +
        "displayMode=\(String(describing: displayState.displayMode)) " +
        "showsFretboard=\(isShowingFretboard) " +
        "settingsPresented=\(isSettingsPresented)"
    }

    private let pianoDemoContainerView = UIView()

    private lazy var exerciseSceneRenderer = iOSExerciseSceneRenderer(
        safeAreaHeightAnchor: view.safeAreaLayoutGuide.heightAnchor,
        metrics: .init(
            surfaceSpacing: Layout.verticalSpacing,
            floatingButtonInset: Layout.topContentFloatingButtonInset,
            floatingButtonSize: Layout.sequenceRegenerateButtonSize,
            contentSizeTolerance: Layout.contentSizeTolerance
        ),
        sequenceRegenerateButton: sequenceRegenerateButton,
        staffView: staffView,
        targetNotePromptView: targetNotePromptView,
        naturalNoteStripView: naturalNoteStripView,
        pianoAccessoryView: pianoDemoContainerView,
        fretboardView: fretboardView
    )

    private func configureLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(exerciseSceneRenderer.sceneContainerView)
        pianoDemoContainerView.addSubview(pianoDemoTitleLabel)
        pianoDemoContainerView.addSubview(pianoDemoStatusLabel)
        pianoDemoContainerView.addSubview(pianoKeyboardView)

        NSLayoutConstraint.activate([
            exerciseSceneRenderer.sceneContainerView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.contentTopInset
            ),
            exerciseSceneRenderer.sceneContainerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            exerciseSceneRenderer.sceneContainerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            exerciseSceneRenderer.sceneContainerView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            )
        ])
    }

    private func applyPianoDemoState() {
        pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
        pianoKeyboardView.rows = resolvedPianoDemoRows
        pianoKeyboardView.showsComponentBoundsOverlay = false
        updatePianoDemoStatusLabel()
        updateLayoutIfNeeded()
        exerciseSceneRenderer.handleLayoutPass()
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.debugStateSnapshot(), macOSViewController.exerciseSceneRenderer, macOSViewController.configureLayout(), macOSViewController.applyPianoDemoState()
// 功能说明: 修改后 macOS 控制器同样只负责钢琴内容更新，不再维护外挂底部约束。
final class macOSViewController: NSViewController {
    private func debugStateSnapshot() -> String {
        "trainerDisplay=\(String(describing: trainerDisplayState.exerciseMode)) " +
        "trainerCore=\(String(describing: fretboardTrainerState.mode)) " +
        "composition=\(String(describing: exerciseLayoutPreferences.compositionPreset)) " +
        "layout=\(String(describing: exerciseLayoutPreferences.layoutPreset)) " +
        "accessory=\(String(describing: exerciseLayoutPreferences.accessoryPresentation)) " +
        "piano=\(exerciseLayoutPreferences.isPianoAccessoryVisible) " +
        "displayMode=\(String(describing: displayState.displayMode)) " +
        "showsFretboard=\(isShowingFretboard) " +
        "settingsPresented=\(isSettingsPresented)"
    }

    private let pianoDemoContainerView = NSView()

    private lazy var exerciseSceneRenderer = macOSExerciseSceneRenderer(
        safeAreaHeightAnchor: view.safeAreaLayoutGuide.heightAnchor,
        metrics: .init(
            surfaceSpacing: Layout.verticalSpacing,
            floatingButtonInset: Layout.topContentFloatingButtonInset,
            floatingButtonSize: Layout.sequenceRegenerateButtonSize,
            contentSizeTolerance: Layout.contentSizeTolerance
        ),
        sequenceRegenerateButton: sequenceRegenerateButton,
        staffView: staffView,
        targetNotePromptView: targetNotePromptView,
        naturalNoteStripView: naturalNoteStripView,
        pianoAccessoryView: pianoDemoContainerView,
        fretboardView: fretboardView
    )

    private func applyPianoDemoState() {
        pianoKeyboardView.configuration = resolvedPianoDemoConfiguration
        pianoKeyboardView.rows = resolvedPianoDemoRows
        pianoKeyboardView.showsComponentBoundsOverlay = false
        updatePianoDemoStatusLabel()
        updateLayoutIfNeeded()
        exerciseSceneRenderer.handleLayoutPass()
    }
}
```

## 6. settings / navigation 文案与 validation 升级到阶段 7 语义

- 修改前：settings snapshot 仍用“for now”文案暗示高级能力未接线；toggle 的可访问性描述还是“挂在主内容下面”的旧说法；validation 也还按阶段 2/3 的保守能力边界断言。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: SettingsNavigationSnapshotBuilder.childPageSpecs(for:)
// 功能说明: 修改前导航子页标题仍然用“for now”提示布局和 accessory presentation 还没有真正放开。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    case .exercise:
        return [
            ChildPageSpec(
                route: .exerciseLayout,
                title: SettingsRouteID.exerciseLayout.fallbackTitle,
                subtitle: "Stacked for now",
                rowIDs: [
                    .choice(.layoutPreset)
                ]
            )
        ]
    case .accessories:
        return [
            ChildPageSpec(
                route: .accessoryPresentation,
                title: SettingsRouteID.accessoryPresentation.fallbackTitle,
                subtitle: "Docked for now",
                rowIDs: [
                    .choice(.accessoryPresentation),
                    .toggle(.accessoryExpanded)
                ]
            )
        ]
    default:
        return nil
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsToggleID.accessibilityLabel
// 功能说明: 修改前 toggle 的说明文案仍把 accessory 解释成“挂在主内容下面”的旧页面模型。
enum SettingsToggleID: CaseIterable, Equatable, Hashable, Sendable {
    var accessibilityLabel: String {
        switch self {
        case .naturalStripVisible:
            return "Toggle whether the natural note strip accessory is visible"
        case .pianoAccessoryVisible:
            return "Toggle whether the piano accessory is visible beneath the main exercise content"
        default:
            return ""
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: SettingsNavigationValidationRunner.makeFixtures(), SettingsNavigationValidationRunner.manualChecklist(for:), SettingsNavigationValidationRunner.validatePhase2ExerciseAndAccessoryRowsRemainStable()
// 功能说明: 修改前 validation fixture 名称和断言都还停留在“高级能力未开放”的旧阶段。
private extension SettingsNavigationValidationRunner {
    static func makeFixtures() -> [SettingsNavigationValidationFixture] {
        [
            SettingsNavigationValidationFixture(
                name: "phase2_exercise_and_accessory_rows_remain_stable",
                validate: validatePhase2ExerciseAndAccessoryRowsRemainStable
            )
        ]
    }

    static func manualChecklist(
        for platform: SettingsNavigationValidationPlatform
    ) -> [String] {
        [
            "确认 `Accessories` 分区包含 `Natural Strip Visible / Piano Accessory Visible / Accessory Presentation / Accessory Expanded`，`Piano > Behavior` 不再负责可见性开关。"
        ]
    }

    static func validatePhase2ExerciseAndAccessoryRowsRemainStable()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "phase2_exercise_and_accessory_rows_remain_stable"
        // ... 默认 state 下 Side by Side 不应提前放开 等旧断言省略
        return []
    }
}
```

- 修改后：文案直接反映阶段 7 已开启的能力边界；validation 也改成校验 `Side by Side`、`Docked / Floating / Collapsible`、`Collapsible -> Accessory Expanded` 等真实行为。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: SettingsNavigationSnapshotBuilder.childPageSpecs(for:)
// 功能说明: 修改后导航文案直接反映阶段 7 已开放的布局与 accessory presentation 能力。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    case .exercise:
        return [
            ChildPageSpec(
                route: .exerciseLayout,
                title: SettingsRouteID.exerciseLayout.fallbackTitle,
                subtitle: "Stacked, side, or single",
                rowIDs: [
                    .choice(.layoutPreset)
                ]
            )
        ]
    case .accessories:
        return [
            ChildPageSpec(
                route: .accessoryPresentation,
                title: SettingsRouteID.accessoryPresentation.fallbackTitle,
                subtitle: "Docked, floating, or collapsible",
                rowIDs: [
                    .choice(.accessoryPresentation),
                    .toggle(.accessoryExpanded)
                ]
            )
        ]
    default:
        return nil
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsToggleID.accessibilityLabel
// 功能说明: 修改后 toggle 文案不再描述“挂在主内容下面”，而是描述 accessory surface 参与编排的语义。
enum SettingsToggleID: CaseIterable, Equatable, Hashable, Sendable {
    var accessibilityLabel: String {
        switch self {
        case .naturalStripVisible:
            return "Toggle whether the natural note strip participates as an accessory surface"
        case .pianoAccessoryVisible:
            return "Toggle whether the piano participates as an accessory surface"
        default:
            return ""
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: SettingsNavigationValidationRunner.makeFixtures(), SettingsNavigationValidationRunner.manualChecklist(for:), SettingsNavigationValidationRunner.validateExerciseAndAccessoryRowsMatchStage7Capabilities()
// 功能说明: 修改后 validation 会校验阶段 7 真正开放的 settings 能力和导航路径。
private extension SettingsNavigationValidationRunner {
    static func makeFixtures() -> [SettingsNavigationValidationFixture] {
        [
            SettingsNavigationValidationFixture(
                name: "exercise_and_accessory_rows_match_stage7_capabilities",
                validate: validateExerciseAndAccessoryRowsMatchStage7Capabilities
            )
        ]
    }

    static func manualChecklist(
        for platform: SettingsNavigationValidationPlatform
    ) -> [String] {
        [
            "确认 `single/sequence` 下可以打开 `Natural Strip Visible`，而 `positionPrompt` 主 answer strip 场景里该 toggle 会自动禁用。",
            "确认 `Accessory Presentation` 里的 `Docked / Floating / Collapsible` 都可进入且可选；只有切到 `Collapsible` 后才启用 `Accessory Expanded`。"
        ]
    }

    static func validateExerciseAndAccessoryRowsMatchStage7Capabilities()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "exercise_and_accessory_rows_match_stage7_capabilities"
        var issues: [SettingsNavigationValidationIssue] = []

        if !(layoutRow.choices.first(
            where: { $0.id == .setLayoutPresetSideBySide }
        )?.isEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "default state 应继续允许切换到 Side by Side layout。"
                )
            )
        }
        if layoutRow.choices.first(
            where: { $0.id == .setLayoutPresetSingleSurface }
        )?.isEnabled ?? false {
            issues.append(
                issue(
                    fixtureName,
                    "默认的多 surface 组合不应把 Single Surface layout 标记为可用。"
                )
            )
        }

        guard let accessoryPresentationRow = defaultPanelModel.choiceRow(
            for: .accessoryPresentation
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "default state 应暴露 Accessory Presentation row。"
                )
            )
            return issues
        }

        if accessoryPresentationRow.choices.map(\.id) != [
            .setAccessoryPresentationDocked,
            .setAccessoryPresentationFloating,
            .setAccessoryPresentationCollapsible
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Accessory Presentation row 选项顺序应保持 Docked -> Floating -> Collapsible。"
                )
            )
        }
        if accessoryPresentationRow.choices.contains(where: { !$0.isEnabled }) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 7 后 Docked / Floating / Collapsible 三种 accessory presentation 都应可用。"
                )
            )
        }

        if defaultPanelModel.toggleRow(for: .naturalStripVisible)?.isEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 默认态下的 Natural Strip Visible toggle 应保持禁用，因为 strip 已承担主 answer surface。"
                )
            )
        }

        // ... single 模式下 strip accessory 可开、Collapsible 时 Expanded toggle 启用等断言省略
        return issues
    }
}
```

## 7. `ExerciseCompositionValidation` 补阶段 7 的自动化夹具与 legacy fallback 断言

- 修改前：shared validation 只覆盖阶段 3 之前的 scene 合法性、layout preset 投影和 legacy fallback；还没有针对 accessory presentation / collapsible / threePane 的专项夹具。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures(), ExerciseCompositionValidationRunner.manualChecklist(for:), ExerciseCompositionValidationRunner.validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
// 功能说明: 修改前 validation 还没有阶段 7 的 accessory scene 夹具。
private extension ExerciseCompositionValidationRunner {
    static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
        [
            ExerciseCompositionValidationFixture(
                name: "composition_policy_projects_supported_presets_to_expected_scenes",
                validate: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes
            ),
            ExerciseCompositionValidationFixture(
                name: "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model",
                validate: validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel
            )
        ]
    }

    static func manualChecklist(
        for platform: ExerciseCompositionValidationPlatform
    ) -> [String] {
        var checklist = [
            "确认 `Piano Accessory Visible` 默认关闭；打开后只追加钢琴区域，关闭后主 prompt/answer 组合不发生漂移。"
        ]
        return checklist
    }
}
```

- 修改后：新增 `accessory_scene_nodes_follow_presentation_strategy` 夹具，验证 `floating / collapsible / threePane` 的 tree 结构、surface state 和 legacy fallback；手工回归清单也同步覆盖 accessory scene 的真实行为。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures(), ExerciseCompositionValidationRunner.manualChecklist(for:), ExerciseCompositionValidationRunner.validateAccessorySceneNodesFollowPresentationStrategy(), ExerciseCompositionValidationRunner.validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
// 功能说明: 修改后 validation 正式覆盖阶段 7 的 accessory scene 编排与 legacy bridge 约束。
private extension ExerciseCompositionValidationRunner {
    static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
        [
            ExerciseCompositionValidationFixture(
                name: "composition_policy_projects_supported_presets_to_expected_scenes",
                validate: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes
            ),
            ExerciseCompositionValidationFixture(
                name: "accessory_scene_nodes_follow_presentation_strategy",
                validate: validateAccessorySceneNodesFollowPresentationStrategy
            ),
            ExerciseCompositionValidationFixture(
                name: "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model",
                validate: validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel
            )
        ]
    }

    static func manualChecklist(
        for platform: ExerciseCompositionValidationPlatform
    ) -> [String] {
        var checklist = [
            "确认 `Piano Accessory Visible` 默认关闭；打开后会按当前 `Accessory Presentation` 进入 docked / floating / collapsible scene，关闭后主 prompt/answer 组合不发生漂移。",
            "确认在 `single/sequence` 下打开 `Natural Strip Visible` 时，strip 会作为 accessory surface 参与布局，但不会抢走 answer surface 角色。",
            "确认 `Collapsible` accessory 收起时，隐藏的 accessory 不可见也不可交互；重新展开后恢复到原来的 surface。"
        ]
        return checklist
    }

    static func validateAccessorySceneNodesFollowPresentationStrategy()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "accessory_scene_nodes_follow_presentation_strategy"
        var issues: [ExerciseCompositionValidationIssue] = []

        let floatingAccessoryPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToFretboard,
                    layoutPreset: .stacked,
                    accessoryPresentation: .floating,
                    isNaturalNoteStripVisible: true
                )
            )
        )
        switch floatingAccessoryPresentation.scene.root {
        case let .overlay(base, floating):
            let baseSurfaceIDs = base.surfaceNodes.map(\.id)
            let floatingSurfaceIDs = floating.flatMap { $0.surfaceNodes }.map(\.id)
            // ... floating accessory 结构断言省略
            _ = (baseSurfaceIDs, floatingSurfaceIDs)
        default:
            issues.append(
                issue(
                    fixtureName,
                    "Accessory Presentation = Floating 时应生成 overlay scene。"
                )
            )
        }

        let collapsedAccessoryPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: .stacked,
                        accessoryPresentation: .collapsible,
                        isPianoAccessoryVisible: true,
                        isAccessoryExpanded: false
                    )
                )
            )
        let collapsedPianoState = collapsedAccessoryPresentation.surfaceState(
            for: .piano
        )
        if collapsedPianoState?.isVisible ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "收起的 collapsible accessory 应把 piano surface 标记为不可见。"
                )
            )
        }
        if collapsedPianoState?.isInteractionEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "收起的 collapsible accessory 不应继续保留 piano 的交互能力。"
                )
            )
        }

        let threePaneLayoutScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .staffToFretboard,
                layoutPreset: .threePane,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: true
            )
        )
        // ... threePane accessory subtree 断言省略
        _ = threePaneLayoutScene

        return issues
    }

    static func validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model"
        var issues: [ExerciseCompositionValidationIssue] = []

        let floatingAccessoryLegacyPresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .single
                    ),
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: .stacked,
                        accessoryPresentation: .floating,
                        isNaturalNoteStripVisible: true,
                        isPianoAccessoryVisible: true
                    )
                )
            )
        if floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .accessoryPresentation != .docked
            || floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .isNaturalNoteStripVisible
            || floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应清空可选 accessory scene，只保留 page model 能表达的 docked 主视觉组合。"
                )
            )
        }

        return issues
    }
}
```

## 8. 验证结果

- `ReadLints`
  结果：`No linter errors found.`
- macOS Debug 构建
  命令：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build`
  结果：`BUILD SUCCEEDED`
- iOS Simulator Debug 构建
  命令：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build`
  结果：`BUILD SUCCEEDED`

## 9. 构建备注

- 两个平台的 Debug 构建都通过，说明 shared policy / validator、双平台 renderer、双平台 controller 的阶段 7 接线在编译层面已经闭合。
- 本次记录没有放原始 `git diff`，代码块都是按实际改动整理后的“修改前 / 修改后”片段。

## 10. 过程中修正

- 第一次跑 macOS 构建时，`ExercisePresentationState.swift` 里静态辅助函数调用漏写了 `Self.`，导致编译失败；修正后重新跑双平台构建均通过。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseSurfaceState.init(surface:isVisible:)
// 功能说明: 过程中修正构建错误；把静态辅助函数调用改成显式的 Self.defaultInteractionEnabled(for:)。
self.init(
    isVisible: isVisible,
    isPromptActive: isVisible && surface.isPromptSurface,
    isAnswerEnabled: isVisible && surface.isAnswerSurface,
    isInteractionEnabled: isVisible
        && Self.defaultInteractionEnabled(for: surface)
)
```

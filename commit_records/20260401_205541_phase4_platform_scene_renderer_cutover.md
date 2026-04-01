# 20260401_205541_phase4_platform_scene_renderer_cutover

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_205541`
- 记录范围：`场景树迁移` 计划的阶段 4；从 iOS/macOS 控制器抽离平台 renderer，复用现有 surface 实例直接渲染 `ExerciseScene`
- 修改性质：新增双平台 renderer；让控制器改为消费 `ExercisePresentationState`；补 shared 渲染布局投影；放松 settings/legacy bridge 对 `sideBySide` / `singleSurface` 的压制；补齐阶段 4 validation
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 修改前

### 1. `ExercisePresentationState` 还不能直接给 renderer 提供“单区 / 上下 / 左右”的可渲染布局投影

- 修改前 shared 层只有 `scene + surfaceStates`，renderer 如果想消费 scene，仍需要平台控制器自己去解释 split 结构。
- 也没有统一的 `isSurfaceVisible(...)` 快捷入口，控制器还在继续绕 `pageDisplayState` 判断 surface 可见性。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExercisePresentationState.surfaceState(...), ExercisePresentationState.setSurfaceState(...)
// 功能说明: 修改前 presentation state 只承载 scene 与 surface state，不负责把场景树收敛成 renderer 可直接消费的布局结构。
struct ExercisePresentationState: Equatable, Sendable {
    var scene: ExerciseScene
    var resolvedLayoutPreferences: ExerciseLayoutPreferences
    var legacyPageDisplayState: PageDisplayState?
    private(set) var surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState]

    init(
        scene: ExerciseScene,
        surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState] = [:],
        resolvedLayoutPreferences: ExerciseLayoutPreferences = .default,
        legacyPageDisplayState: PageDisplayState? = nil
    ) {
        self.scene = scene
        self.resolvedLayoutPreferences = resolvedLayoutPreferences
        self.legacyPageDisplayState = legacyPageDisplayState
        self.surfaceStates = surfaceStates
    }

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

    mutating func setSurfaceState(
        _ state: ExerciseSurfaceState,
        for surfaceID: ExerciseSurfaceID
    ) {
        surfaceStates[surfaceID] = state
    }
}
```

### 2. iOS / macOS 控制器仍把 `top/main` 双槽位当成主渲染真相

- 修改前 `pageDisplayState.didSet` 会直接触发 `applyPageDisplayState()`，页面语义和宿主切换都还压在控制器里。
- `configureLayout()` 里显式创建 `topContentHostView` / `mainContentHostView` / `fretboardHostView`，再配合 `applyFretboardHostPlacement()`、`applyTopContentMode()`、`applyMainContentMode()` 手动搬 view。
- `viewDidLayoutSubviews()` / `viewDidLayout()` 也仍然直接调用指板 viewport 同步函数，而不是交给独立 renderer。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: pageDisplayState, exercisePresentationState
// 功能说明: 修改前 iOS 控制器里 pageDisplayState 仍直接驱动页面编排，exercisePresentationState 还不是渲染入口。
private var pageDisplayState = iOSViewController.initialExercisePresentationState
    .legacyPageDisplayState ?? .default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
        handleQuarterNoteSequencePageDisplayStateTransition(
            from: oldValue,
            to: pageDisplayState
        )
    }
}
private var exerciseLayoutPreferences = iOSViewController
    .initialExerciseLayoutPreferences {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}
private var exercisePresentationState = iOSViewController
    .initialExercisePresentationState
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: viewDidLayoutSubviews(), configureLayout(), applyPageDisplayState(), applyFretboardHostPlacement(), applyTopContentMode(), applyMainContentMode()
// 功能说明: 修改前 iOS 控制器自己创建双槽位宿主并维护所有 surface 搬移与指板 viewport 几何。
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    syncVerticalFretboardContentWidthConstraint()
    updateFretboardViewportPresentation()
    if !hasLoggedInitialLayoutPass {
        hasLoggedInitialLayoutPass = true
        logLifecycle("first layout pass bounds=\(view.bounds)")
    }
}

private func configureLayout() {
    logLifecycle("configureLayout begin")
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    labelVisibilityButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    topContentHostView.translatesAutoresizingMaskIntoConstraints = false
    mainContentHostView.translatesAutoresizingMaskIntoConstraints = false
    // ... 其他未改动属性初始化省略
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    topContentHostView.addSubview(sequenceRegenerateButton)
    contentView.addSubview(mainContentHostView)
    mainContentHostView.addSubview(fretboardHostView)
    mainContentHostView.addSubview(naturalNoteStripView)
    // ... 其他未改动布局约束省略
}

private func applyPageDisplayState() {
    logLifecycle("applyPageDisplayState begin")
    applyFretboardHostPlacement()
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    updateLayoutIfNeeded()

    if isShowingFretboard {
        syncVerticalFretboardContentWidthConstraint()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
    logLifecycle("applyPageDisplayState end")
}

private func applyFretboardHostPlacement() {
    let desiredHost = isShowingFretboardTopContent
        ? "top"
        : (isShowingFretboardMainContent ? "main" : "hidden")
    logLifecycle("applyFretboardHostPlacement target=\(desiredHost)")
    let desiredSuperview = isShowingFretboardTopContent
        ? topContentHostView
        : mainContentHostView
    // ... 其余旧宿主切换逻辑省略
}

private func applyTopContentMode() {
    let activeConstraints: [NSLayoutConstraint]
    if isShowingStaffTopContent {
        activeConstraints = topContentStaffConstraints
    } else if isShowingTargetPromptTopContent {
        activeConstraints = topContentTargetPromptConstraints
    } else {
        activeConstraints = []
    }
    // ... 其余旧顶部槽位切换逻辑省略
}

private func applyMainContentMode() {
    naturalNoteStripView.isHidden = !isShowingNaturalNoteStripMainContent
    NSLayoutConstraint.deactivate(mainContentNaturalNoteStripConstraints)
    if isShowingNaturalNoteStripMainContent {
        NSLayoutConstraint.activate(mainContentNaturalNoteStripConstraints)
    }
    rebuildVerticalFretboardHostHeightConstraint()
    updateFretboardLayoutModeConstraints()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: viewDidLayout(), applyPageDisplayState()
// 功能说明: 修改前 macOS 控制器与 iOS 同构，也直接持有 top/main 双槽位和 page 驱动渲染链路。
override func viewDidLayout() {
    super.viewDidLayout()
    syncVerticalFretboardContentSizeConstraints()
    updateFretboardViewportPresentation()
    if !hasLoggedInitialLayoutPass {
        hasLoggedInitialLayoutPass = true
        logLifecycle("first layout pass bounds=\(view.bounds)")
    }
}

private func applyPageDisplayState() {
    logLifecycle("applyPageDisplayState begin")
    applyFretboardHostPlacement()
    applyTopContentMode()
    applyMainContentMode()
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    updateLayoutIfNeeded()

    if isShowingFretboard {
        syncVerticalFretboardContentSizeConstraints()
        updateLayoutIfNeeded()
    }

    updateFretboardViewportPresentation()
    logLifecycle("applyPageDisplayState end")
}
```

### 3. 阶段 4 之前还不存在独立的平台 scene renderer

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: N/A（修改前文件不存在）
// 功能说明: 修改前没有独立的 iOS scene renderer；scene 到 view 宿主的解释和几何处理都散落在 iOSViewController 内部。
// （文件不存在）
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: N/A（修改前文件不存在）
// 功能说明: 修改前没有独立的 macOS scene renderer；scene 到 AppKit view 宿主的解释和滚动几何都散落在 macOSViewController 内部。
// （文件不存在）
```

### 4. settings bridge 仍会按 legacy page 能力裁剪 layout preset

- 修改前 `LegacyPageLayoutAdapter.normalizedPreferences()` 直接走 `ExerciseCompositionPolicy.legacyCompatiblePreferences(...)`。
- 这意味着就算 settings 已经允许用户选 `sideBySide` / `singleSurface`，也会先被 legacy 兼容层强行压回旧页面模型能表达的布局。
- `SettingsPanelModel.isEnabled(...)` 也只按 preset 自身判断，不会结合当前 `stateContext.exerciseLayoutPreferences` 做语义归一化。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名: normalizedPreferences(...), isCompositionPresetSupported(...), isLayoutPresetSupported(...)
// 功能说明: 修改前 legacy adapter 的“归一化”实际上直接等价于 legacyCompatiblePreferences，会提前把新布局语义压回旧页面能力。
static func normalizedPreferences(
    _ preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> ExerciseLayoutPreferences {
    ExerciseCompositionPolicy.legacyCompatiblePreferences(
        from: policyInput(
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: .init(),
            layoutPreferences: preferences
        )
    )
}

static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    let requestedPreferences = ExerciseLayoutPreferences(
        compositionPreset: preset,
        layoutPreset: preset == .fretboardSelfAnswer
            ? .singleSurface
            : .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: preset == .fretboardToNaturalNoteStrip,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
    let legacyCompatiblePreferences = ExerciseCompositionPolicy
        .legacyCompatiblePreferences(
            from: policyInput(
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: exerciseMode
                ),
                pianoPanelState: .init(),
                layoutPreferences: requestedPreferences
            )
        )
    return legacyCompatiblePreferences.compositionPreset == preset
}

static func isLayoutPresetSupported(
    _ preset: ExerciseLayoutPreset
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
                    layoutPreset: preset
                )
            )
        )
    return legacyCompatiblePreferences.layoutPreset == preset
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsActionID.isEnabled(in:)
// 功能说明: 修改前 layout preset 的可用性判断没有带入当前 settings context，因此无法区分“当前组合下语义允许，但 legacy page 不可直接投影”的情况。
case .setLayoutPresetStacked:
    return LegacyPageLayoutAdapter.isLayoutPresetSupported(.stacked)
case .setLayoutPresetSideBySide:
    return LegacyPageLayoutAdapter.isLayoutPresetSupported(.sideBySide)
case .setLayoutPresetSingleSurface:
    return LegacyPageLayoutAdapter.isLayoutPresetSupported(
        .singleSurface
    )
```

### 5. validation 还没锁定阶段 4 的 `sideBySide` / `single self-answer` 语义保留

- 修改前手工清单还没有覆盖“切到左右布局是否立即生效”“单 fretboard 自答设置往返后是否保留”。
- 自动化夹具也没有检查 `LegacyPageLayoutAdapter.normalizedPreferences(...)` 是否仍然保留新语义，而不是回退成 `stacked`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: manualChecklist(for:), validateSharedLayoutPreferencesCoexistWithLegacyPageState()
// 功能说明: 修改前阶段 4 的手工回归项与 bridge 保留语义断言都还不存在。
static func manualChecklist(
    for platform: ExerciseCompositionValidationPlatform
) -> [String] {
    var checklist = [
        "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
        "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
        "确认打开 settings 只改变 card 可见性，不会重置当前 trainer mode、page layout 或 `pianoAccessoryVisible`。",
        "确认关闭 settings 后页面恢复到关闭前的 prompt/answer 组合，不会闪回 `PageDisplayState.default`。",
        "确认 `Piano Accessory Visible` 默认关闭；打开后只追加钢琴区域，关闭后主 prompt/answer 组合不发生漂移。",
        "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
    ]
    // ... 平台分支逻辑省略
    return checklist
}

static func validateSharedLayoutPreferencesCoexistWithLegacyPageState()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "shared_layout_preferences_coexist_with_legacy_page_state"
    var issues: [ExerciseCompositionValidationIssue] = []
    let defaultStateContext = SettingsPanelStateContext.default
    // ... 旧有 default / context 共存断言省略

    let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
    if panelModel.sections.first(where: { $0.id == .exercise }) == nil {
        issues.append(
            issue(
                fixtureName,
                "阶段 2 中，shared context 新增字段不应破坏新 Exercise section 的生成。"
            )
        )
    }

    return issues
}
```

## 修改后

### 1. `ExercisePresentationState` 新增 renderer-friendly 布局投影

- 新增 `ExerciseRenderedSceneArrangement` 与 `ExerciseRenderedSceneLayout`，把 scene 收敛成 renderer 直接可消费的单区 / 上下 / 左右模型。
- 新增 `isSurfaceVisible(...)` 与 `renderedSceneLayout`，让平台 renderer 和控制器不再绕 `PageDisplayState` 读 surface 可见性。
- `overlay` / `collapsible` 在阶段 4 先回落到主节点布局，保证 renderer cutover 不提前耦合高级布局。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseRenderedSceneArrangement, ExerciseRenderedSceneLayout, ExercisePresentationState.isSurfaceVisible(...), ExercisePresentationState.renderedSceneLayout
// 功能说明: 修改后 shared 层可以直接把场景树投影成 renderer 可消费的布局描述，平台控制器不需要再自己解释 split/surface 节点。
struct ExercisePresentationState: Equatable, Sendable {
    var scene: ExerciseScene
    var resolvedLayoutPreferences: ExerciseLayoutPreferences
    var legacyPageDisplayState: PageDisplayState?
    private(set) var surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState]

    // ... 既有 init / surfaceState / setSurfaceState 逻辑省略
}

enum ExerciseRenderedSceneArrangement: Equatable, Sendable {
    case singleSurface
    case stacked
    case sideBySide
}

struct ExerciseRenderedSceneLayout: Equatable, Sendable {
    var arrangement: ExerciseRenderedSceneArrangement
    var primarySurface: ExerciseSurfaceNode
    var primaryWeight: Double
    var secondarySurface: ExerciseSurfaceNode?
    var secondaryWeight: Double?
}

extension ExercisePresentationState {
    func isSurfaceVisible(_ surfaceID: ExerciseSurfaceID) -> Bool {
        surfaceState(for: surfaceID)?.isVisible ?? false
    }

    var renderedSceneLayout: ExerciseRenderedSceneLayout? {
        renderedSceneLayout(for: scene.root)
    }

    private func renderedSceneLayout(
        for node: ExerciseSceneNode
    ) -> ExerciseRenderedSceneLayout? {
        switch node {
        case let .surface(surface):
            return ExerciseRenderedSceneLayout(
                arrangement: .singleSurface,
                primarySurface: surface,
                primaryWeight: 1,
                secondarySurface: nil,
                secondaryWeight: nil
            )
        case let .split(axis, children):
            guard children.count == 2,
                  case let .surface(primarySurface) = children[0].node,
                  case let .surface(secondarySurface) = children[1].node else {
                return nil
            }

            return ExerciseRenderedSceneLayout(
                arrangement: axis == .vertical ? .stacked : .sideBySide,
                primarySurface: primarySurface,
                primaryWeight: children[0].weight,
                secondarySurface: secondarySurface,
                secondaryWeight: children[1].weight
            )
        case let .overlay(base, _):
            return renderedSceneLayout(for: base)
        case let .collapsible(main, _, _):
            return renderedSceneLayout(for: main)
        }
    }
}
```

### 2. 新增 iOS / macOS 平台 scene renderer

- 新增 `iOSExerciseSceneRenderer.swift` 与 `macOSExerciseSceneRenderer.swift`。
- 两个 renderer 都复用现有 `staffView` / `targetNotePromptView` / `naturalNoteStripView` / `fretboardView` / `sequenceRegenerateButton`，不创建第二份真实 surface 实例。
- iOS / macOS 各自保留本平台需要的 viewport / scroll / constraint 几何细节，但 scene 解读、surface host 安装、可见性同步都收敛进 renderer。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: render(...), handleLayoutPass(), configureStaticHierarchy(), resolvedLayout(...)
// 功能说明: 新增 iOS renderer，统一消费 ExercisePresentationState，负责 sceneContainer、surface host 复用与 vertical fretboard viewport 几何。
#if os(iOS)
import UIKit

final class iOSExerciseSceneRenderer {
    struct Metrics {
        var surfaceSpacing: CGFloat
        var floatingButtonInset: CGFloat
        var floatingButtonSize: CGFloat
        var contentSizeTolerance: CGFloat
    }

    let sceneContainerView = UIView()

    // ... 其他 renderer 属性省略

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
        if let secondarySurface = resolvedLayout.secondarySurface {
            apply(
                secondarySurface,
                to: secondarySurfaceContentView,
                storedConstraints: &secondarySurfaceConstraints
            )
        } else {
            clearSurfaceHost(
                secondarySurfaceContentView,
                storedConstraints: &secondarySurfaceConstraints
            )
        }

        updateSurfaceVisibility(for: resolvedLayout)
        rebuildVerticalFretboardHostHeightConstraint()
        updateFretboardLayoutModeConstraints()
    }

    func handleLayoutPass() {
        syncVerticalFretboardContentWidthConstraint()
        updateFretboardViewportPresentation()
    }

    private func resolvedLayout(
        from presentationState: ExercisePresentationState
    ) -> ExerciseRenderedSceneLayout? {
        if let renderedSceneLayout = presentationState.renderedSceneLayout {
            return renderedSceneLayout
        }

        let surfaceNodes = presentationState.scene.surfaceNodes
        guard let primarySurface = surfaceNodes.first else {
            return nil
        }

        if surfaceNodes.count > 1 {
            return ExerciseRenderedSceneLayout(
                arrangement: .stacked,
                primarySurface: primarySurface,
                primaryWeight: 1,
                secondarySurface: surfaceNodes[1],
                secondaryWeight: 1
            )
        }

        return ExerciseRenderedSceneLayout(
            arrangement: .singleSurface,
            primarySurface: primarySurface,
            primaryWeight: 1,
            secondarySurface: nil,
            secondaryWeight: nil
        )
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: render(...), handleLayoutPass(), configureStaticHierarchy(), resolvedLayout(...)
// 功能说明: 新增 macOS renderer，复用相同 scene 布局语义，并保留 NSScrollView / document width / centerX 等 AppKit 专有几何处理。
#if os(macOS)
import AppKit

final class macOSExerciseSceneRenderer {
    struct Metrics {
        var surfaceSpacing: CGFloat
        var floatingButtonInset: CGFloat
        var floatingButtonSize: CGFloat
        var contentSizeTolerance: CGFloat
    }

    let sceneContainerView = NSView()

    // ... 其他 renderer 属性省略

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
        if let secondarySurface = resolvedLayout.secondarySurface {
            apply(
                secondarySurface,
                to: secondarySurfaceContentView,
                storedConstraints: &secondarySurfaceConstraints
            )
        } else {
            clearSurfaceHost(
                secondarySurfaceContentView,
                storedConstraints: &secondarySurfaceConstraints
            )
        }

        updateSurfaceVisibility(for: resolvedLayout)
        rebuildVerticalFretboardHostHeightConstraint()
        updateFretboardLayoutModeConstraints()
    }

    func handleLayoutPass() {
        syncVerticalFretboardContentSizeConstraints()
        updateFretboardViewportPresentation()
    }

    private func resolvedLayout(
        from presentationState: ExercisePresentationState
    ) -> ExerciseRenderedSceneLayout? {
        if let renderedSceneLayout = presentationState.renderedSceneLayout {
            return renderedSceneLayout
        }

        let surfaceNodes = presentationState.scene.surfaceNodes
        guard let primarySurface = surfaceNodes.first else {
            return nil
        }

        if surfaceNodes.count > 1 {
            return ExerciseRenderedSceneLayout(
                arrangement: .stacked,
                primarySurface: primarySurface,
                primaryWeight: 1,
                secondarySurface: surfaceNodes[1],
                secondaryWeight: 1
            )
        }

        return ExerciseRenderedSceneLayout(
            arrangement: .singleSurface,
            primarySurface: primarySurface,
            primaryWeight: 1,
            secondarySurface: nil,
            secondaryWeight: nil
        )
    }
}
#endif
```

### 3. iOS / macOS 控制器改为消费 `ExercisePresentationState`

- `pageDisplayState` 现在只负责 legacy bridge 同步 settings，不再直接驱动页面渲染。
- `exercisePresentationState.didSet` 成为真正的渲染入口，统一调用 `renderExercisePresentationState()`。
- `viewDidLayoutSubviews()` / `viewDidLayout()` 只保留 `exerciseSceneRenderer.handleLayoutPass()`。
- `configureLayout()` 不再显式装配 `topContentHostView` / `mainContentHostView`，而是把 `exerciseSceneRenderer.sceneContainerView` 作为主场景容器挂到页面上。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: pageDisplayState, exercisePresentationState, exerciseSceneRenderer
// 功能说明: 修改后 iOS 控制器把页面渲染入口切到 exercisePresentationState.didSet，pageDisplayState 只保留 settings bridge 兼容职责。
private var pageDisplayState = iOSViewController.initialExercisePresentationState
    .legacyPageDisplayState ?? .default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}
private var exercisePresentationState = iOSViewController
    .initialExercisePresentationState {
    didSet {
        guard isViewLoaded else {
            return
        }

        renderExercisePresentationState()
        handleQuarterNoteSequencePresentationTransition(
            from: oldValue,
            to: exercisePresentationState
        )
        applyLabelVisibilityButtonState()
    }
}

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
    fretboardView: fretboardView
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: viewDidLayoutSubviews(), configureLayout(), renderExercisePresentationState(), applyDisplayState(), applyFretboardDisplayState()
// 功能说明: 修改后 iOS 控制器不再自己切 top/main 宿主，而是把 sceneContainer 作为页面主区域，再把 render/layout pass 交给 renderer。
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    exerciseSceneRenderer.handleLayoutPass()
    if !hasLoggedInitialLayoutPass {
        hasLoggedInitialLayoutPass = true
        logLifecycle("first layout pass bounds=\(view.bounds)")
    }
}

private func configureLayout() {
    logLifecycle("configureLayout begin")
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    labelVisibilityButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    pianoDemoContainerView.translatesAutoresizingMaskIntoConstraints = false
    // ... 其他未改动初始化省略
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(exerciseSceneRenderer.sceneContainerView)
    contentView.addSubview(pianoDemoContainerView)
    // ... 其他未改动子视图挂载省略

    mainContentBottomToContentConstraint = exerciseSceneRenderer.sceneContainerView.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor,
        constant: -Layout.bottomInset
    )

    NSLayoutConstraint.activate([
        // ... 其他未改动基础约束省略
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
        pianoDemoContainerView.topAnchor.constraint(
            equalTo: exerciseSceneRenderer.sceneContainerView.bottomAnchor,
            constant: Layout.verticalSpacing
        )
        // ... 其他未改动约束省略
    ])
}

private func renderExercisePresentationState() {
    logLifecycle("renderExercisePresentationState begin")
    exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
    applySettingsPanelState()
    updateLayoutIfNeeded()
    exerciseSceneRenderer.handleLayoutPass()
    updateLayoutIfNeeded()
    logLifecycle("renderExercisePresentationState end")
}

private func applyDisplayState() {
    logLifecycle("applyDisplayState begin")
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applySequenceRegenerateButtonState()
    applyLabelVisibilityButtonState()
    synchronizeTrainerPresentationState(reason: "initial")
    logLifecycle("applyDisplayState end")
}

private func applyFretboardDisplayState() {
    logLifecycle("applyFretboardDisplayState begin")
    fretboardView.configuration = displayState.configuration
    fretboardView.contentProvider = displayState.contentProvider
    fretboardView.feedbackOverlayState = currentFretboardFeedbackOverlayState
    fretboardView.showsComponentBoundsOverlay = displayState.showsComponentBoundsOverlay
    applySettingsPanelState()
    applyLabelVisibilityButtonState()
    renderExercisePresentationState()

    // ... trainer mode 分支逻辑省略

    guard isShowingFretboard else {
        logLifecycle("applyFretboardDisplayState end without visible fretboard")
        return
    }

    updateLayoutIfNeeded()
    exerciseSceneRenderer.handleLayoutPass()
    updateLayoutIfNeeded()
    logLifecycle("applyFretboardDisplayState end")
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: pageDisplayState, exercisePresentationState, viewDidLayout(), renderExercisePresentationState()
// 功能说明: 修改后 macOS 控制器与 iOS 同步切到 renderer 驱动；live layout pass 与 scene 渲染入口统一改走 exerciseSceneRenderer。
private var pageDisplayState = macOSViewController.initialExercisePresentationState
    .legacyPageDisplayState ?? .default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}
private var exercisePresentationState = macOSViewController
    .initialExercisePresentationState {
    didSet {
        guard isViewLoaded else {
            return
        }

        renderExercisePresentationState()
        handleQuarterNoteSequencePresentationTransition(
            from: oldValue,
            to: exercisePresentationState
        )
        applyLabelVisibilityButtonState()
    }
}

override func viewDidLayout() {
    super.viewDidLayout()
    exerciseSceneRenderer.handleLayoutPass()
    if !hasLoggedInitialLayoutPass {
        hasLoggedInitialLayoutPass = true
        logLifecycle("first layout pass bounds=\(view.bounds)")
    }
}

private func renderExercisePresentationState() {
    logLifecycle("renderExercisePresentationState begin")
    exerciseSceneRenderer.render(
        presentationState: exercisePresentationState,
        fretboardDisplayState: displayState
    )
    applySettingsPanelState()
    updateLayoutIfNeeded()
    exerciseSceneRenderer.handleLayoutPass()
    updateLayoutIfNeeded()
    logLifecycle("renderExercisePresentationState end")
}
```

### 4. settings bridge 改为“保留语义布局，legacy page 只做兼容回投影”

- `LegacyPageLayoutAdapter.normalizedPreferences(...)` 现在只走 `ExerciseSceneValidator.normalizedPreferences(...)`，不再等价于 `legacyCompatiblePreferences(...)`。
- `isCompositionPresetSupported(...)` 改成直接查询语义层支持矩阵。
- `isLayoutPresetSupported(...)` 改为接收 `SettingsPanelStateContext`，结合当前 composition / trainer mode 做真实的语义归一化判断。
- `SettingsPanelModel.isEnabled(...)` 也同步传入 `stateContext`，这样 `Side` / `Single` 的开关就不再被 legacy page 表达能力错误禁用。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名: normalizedPreferences(...), isCompositionPresetSupported(...), isLayoutPresetSupported(...)
// 功能说明: 修改后 legacy adapter 的“归一化”回到 shared 语义层；只有 projectedPageDisplayState(...) 仍负责把结果压到 legacy page 模型。
static func normalizedPreferences(
    _ preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> ExerciseLayoutPreferences {
    ExerciseSceneValidator.normalizedPreferences(
        preferences,
        trainerDisplayState: trainerDisplayState
    )
}

static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    ExerciseSceneValidator.isCompositionPresetSemanticallySupported(
        preset,
        for: exerciseMode
    )
}

static func isLayoutPresetSupported(
    _ preset: ExerciseLayoutPreset,
    in stateContext: SettingsPanelStateContext
) -> Bool {
    var requestedPreferences = stateContext.exerciseLayoutPreferences
    requestedPreferences.layoutPreset = preset

    let normalizedPreferences = normalizedPreferences(
        requestedPreferences,
        trainerDisplayState: stateContext.trainerDisplayState
    )
    return normalizedPreferences.layoutPreset == preset
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsActionID.isEnabled(in:)
// 功能说明: 修改后 layout preset 的可用性判断显式带入当前 stateContext，从而保留已接通 renderer 的语义布局。
case .setLayoutPresetStacked:
    return LegacyPageLayoutAdapter.isLayoutPresetSupported(
        .stacked,
        in: stateContext
    )
case .setLayoutPresetSideBySide:
    return LegacyPageLayoutAdapter.isLayoutPresetSupported(
        .sideBySide,
        in: stateContext
    )
case .setLayoutPresetSingleSurface:
    return LegacyPageLayoutAdapter.isLayoutPresetSupported(
        .singleSurface,
        in: stateContext
    )
```

### 5. validation 与手工清单补阶段 4 检查

- `manualChecklist(...)` 新增左右布局与单 `fretboard` 自答的手工回归项。
- `validateSharedLayoutPreferencesCoexistWithLegacyPageState()` 新增两类断言：
  1. `sideBySide` 不应再被 bridge 压回 `stacked`
  2. `positionPrompt` 下的 `singleFretboardSelfAnswer` 不应在 settings 往返时丢失

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: manualChecklist(for:), validateSharedLayoutPreferencesCoexistWithLegacyPageState()
// 功能说明: 修改后 validation 开始锁定阶段 4 的新 renderer 语义，确保左右布局与单 fretboard 自答不会在 bridge 往返时被回退。
static func manualChecklist(
    for platform: ExerciseCompositionValidationPlatform
) -> [String] {
    var checklist = [
        "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
        "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合。",
        "确认把 `Layout Preset` 切到 `Side` 后，主视觉立即切成左右双栏，而不是被自动打回 `Stacked`。",
        "确认在 `positionPrompt` 里切到 `Composition Preset = Self` 后，页面收敛为单 `fretboard`，并且 settings 重新打开后该选择仍然保留。",
        "确认打开 settings 只改变 card 可见性，不会重置当前 trainer mode、page layout 或 `pianoAccessoryVisible`。",
        "确认关闭 settings 后页面恢复到关闭前的 prompt/answer 组合，不会闪回 `PageDisplayState.default`。",
        "确认 `Piano Accessory Visible` 默认关闭；打开后只追加钢琴区域，关闭后主 prompt/answer 组合不发生漂移。",
        "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
    ]
    // ... 平台分支逻辑省略
    return checklist
}

static func validateSharedLayoutPreferencesCoexistWithLegacyPageState()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "shared_layout_preferences_coexist_with_legacy_page_state"
    var issues: [ExerciseCompositionValidationIssue] = []
    // ... 既有 default / context 共存断言省略

    let preservedSideBySidePreferences = LegacyPageLayoutAdapter
        .normalizedPreferences(
            ExerciseLayoutPreferences(
                compositionPreset: .targetPromptToFretboard,
                layoutPreset: .sideBySide
            ),
            trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
        )
    if preservedSideBySidePreferences.layoutPreset != .sideBySide {
        issues.append(
            issue(
                fixtureName,
                "阶段 4 中，bridge 不应再把已支持的 sideBySide 语义布局压回 stacked。"
            )
        )
    }

    let preservedSelfAnswerPreferences = LegacyPageLayoutAdapter
        .normalizedPreferences(
            .singleFretboardSelfAnswer,
            trainerDisplayState: TrainerDisplayState(
                exerciseMode: .positionPrompt
            )
        )
    if preservedSelfAnswerPreferences.compositionPreset != .fretboardSelfAnswer
        || preservedSelfAnswerPreferences.layoutPreset != .singleSurface {
        issues.append(
            issue(
                fixtureName,
                "阶段 4 中，positionPrompt 的单 fretboard self-answer 偏好不应在 settings bridge 往返时丢失。"
            )
        )
    }

    return issues
}
```

## 验证结果

- `ReadLints`：`No linter errors found.`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build`：通过
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build`：通过

## 过程中修正

- 首次双平台构建失败：新增 renderer 文件未加平台条件编译，macOS 目标解析 `UIKit` 失败，iOS 目标解析 `AppKit` 失败。
- 修正方式：在 `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift` 添加 `#if os(iOS)`，在 `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift` 添加 `#if os(macOS)`，随后重新构建双平台通过。

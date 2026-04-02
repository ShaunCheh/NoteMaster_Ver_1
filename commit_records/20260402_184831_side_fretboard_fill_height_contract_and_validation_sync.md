# 20260402_184831_side_fretboard_fill_height_contract_and_validation_sync

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260402_184831`
- 记录范围：让所有包含主 `fretboard` 的 `sideBySide` 场景在 iOS / macOS 上撑满可视区域，并同步 settings / quick panel / validation
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本轮实际落地文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
  - `NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. 背景与根因

- 目标：`side` 模式下，不论是 `positionPrompt`、`single` 还是 `sequence`，只要主视觉里存在 `fretboard`，它都应该贴满当前可视列高度。
- 旧实现的问题不是单个数字不对，而是高度决策分散在两层：
  1. `scene` 根容器是否 pin 到 viewport 高度，由 `requiresViewportPinnedHeight` 隐式推导。
  2. `fretboardHostView` 自身是否继续吃 `verticalHostHeightRatio`，由平台 renderer 再次隐式决定。
- 结果：`side` 下即使横向 split 已经把左右列顶/底对齐，`fretboard` 仍可能因为旧的 ratio 语义或未 pin 的 scene 根高度而显得比 `stacked` 更矮。

## 2. 修改一：把“side + 主 fretboard”提升为共享 layout contract

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数: ExerciseSceneNode.requiresViewportPinnedHeight
// 修改前说明: scene 是否 pin 到 viewport 高度，只由 vertical mixed sizing 或 verticalRail 决定；
// 纯 side + fretboard 场景没有显式 contract。
var requiresViewportPinnedHeight: Bool {
    hasMixedMainAxisSizing(along: .vertical)
        || surfaceNodes.contains(where: {
            $0.presentationStyle == .verticalRail
        })
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数: ExercisePresentationState.renderedSceneLayout
// 修改前说明: shared 层只有 rendered arrangement 信息，没有“fretboard 高度策略”这一层语义。
struct ExerciseRenderedSceneLayout: Equatable, Sendable {
    var arrangement: ExerciseRenderedSceneArrangement
    var primarySurface: ExerciseSurfaceNode
    var primaryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing
    var secondarySurface: ExerciseSurfaceNode?
    var secondaryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing?
}

extension ExercisePresentationState {
    var renderedSceneLayout: ExerciseRenderedSceneLayout? {
        renderedSceneLayout(for: scene.root)
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数: ExerciseSceneNode.containsMainFretboardInSideBySideLayout, ExerciseSceneNode.requiresViewportPinnedHeight
// 修改后说明: shared scene 直接识别“横向 split 中包含主 fretboard”的场景，
// 并把它并入 viewport pin 语义，避免 platform 再猜。
extension ExerciseSceneNode {
    var containsMainFretboardInSideBySideLayout: Bool {
        switch self {
        case .surface:
            return false
        case let .split(axis, children):
            let isCurrentSideBySideFretboard = axis == .horizontal
                && children.count >= 2
                && children.contains { $0.node.containsSurface(.fretboard) }
            return isCurrentSideBySideFretboard
                || children.contains {
                    $0.node.containsMainFretboardInSideBySideLayout
                }
        case let .overlay(base, _):
            return base.containsMainFretboardInSideBySideLayout
        case let .collapsible(main, _, _):
            return main.containsMainFretboardInSideBySideLayout
        }
    }

    var requiresViewportPinnedHeight: Bool {
        hasMixedMainAxisSizing(along: .vertical)
            || surfaceNodes.contains(where: {
                $0.presentationStyle == .verticalRail
            })
            || containsMainFretboardInSideBySideLayout
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数: ExerciseScene.fretboardLayoutContract, ExercisePresentationState.fretboardLayoutContract
// 修改后说明: 新增共享 contract，把“scene 是否 pin viewport”与
// “fretboard 是 followViewportRatio 还是 fillAvailableHeight”收口到同一处。
enum ExerciseFretboardHeightPolicy: Equatable, Sendable {
    case followViewportRatio
    case fillAvailableHeight
}

struct ExerciseFretboardLayoutContract: Equatable, Sendable {
    var pinsSceneToViewportHeight: Bool
    var heightPolicy: ExerciseFretboardHeightPolicy

    var usesVerticalViewportHeightControl: Bool {
        heightPolicy == .followViewportRatio
    }
}

extension ExerciseScene {
    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: requiresViewportPinnedHeight,
            heightPolicy: containsMainFretboardInSideBySideLayout
                ? .fillAvailableHeight
                : .followViewportRatio
        )
    }
}

extension ExercisePresentationState {
    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        scene.fretboardLayoutContract
    }
}
```

- 结果：`sideBySide + 主 fretboard` 不再只是 platform 看到的“一个横向布局”，而是 shared 层明确表达出的“需要 pin viewport，且 fretboard 要跟随容器高度”的 contract。

## 3. 修改二：controller 改为消费共享的 viewport pin 语义

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: updateSceneViewportHeightConstraint()
// 修改前说明: controller 直接读取 scene.requiresViewportPinnedHeight，
// 无法区分“旧的 rail/mixed 语义”与“新的 side + fretboard fill-height 语义”。
private func updateSceneViewportHeightConstraint() {
    sceneViewportHeightConstraint?.isActive = exercisePresentationState.scene
        .requiresViewportPinnedHeight
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: updateSceneViewportHeightConstraint()
// 修改后说明: controller 改为消费 shared contract；iOS 对应文件做了同样调整。
private func updateSceneViewportHeightConstraint() {
    sceneViewportHeightConstraint?.isActive = exercisePresentationState
        .fretboardLayoutContract
        .pinsSceneToViewportHeight
}
```

- 对应镜像改动：
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`

- 结果：scene 根容器是否钉到 viewport 高度，统一由 shared contract 驱动，macOS / iOS 不再各自解释。

## 4. 修改三：renderer 在 side 下停止施加 ratio 高度约束，让 fretboard 跟随容器高度

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数: rebuildVerticalFretboardHostHeightConstraint(), updateFretboardLayoutModeConstraints()
// 修改前说明: 只要显示 fretboard，就会准备一条基于 safe area * ratio 的高度约束；
// 只要 displayMode == vertical，就会激活这条约束，与 side 下“由外部容器决定高度”的目标冲突。
private func rebuildVerticalFretboardHostHeightConstraint() {
    verticalFretboardHostHeightConstraint?.isActive = false
    verticalFretboardHostHeightConstraint = nil

    guard isShowingFretboard else {
        return
    }

    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: safeAreaHeightAnchor,
        multiplier: currentFretboardDisplayState.verticalHostHeightRatio
    )
    verticalFretboardHostHeightConstraint?.priority = prefersFlexibleVerticalFretboardHeight
        ? .defaultHigh
        : .required
}

private func updateFretboardLayoutModeConstraints() {
    let isVertical = currentFretboardDisplayState.displayMode == .vertical
    verticalFretboardHostHeightConstraint?.isActive = isVertical
    horizontalFretboardDocumentWidthConstraint?.isActive = !isVertical
    horizontalFretboardContentWidthConstraint?.isActive = !isVertical
    verticalFretboardDocumentWidthConstraint?.isActive = isVertical
    verticalFretboardContentWidthConstraint?.isActive = isVertical
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数: fretboardHeightPolicy, rebuildVerticalFretboardHostHeightConstraint(), updateFretboardLayoutModeConstraints()
// 修改后说明: renderer 先读取 shared 的高度策略；
// 只有 followViewportRatio 时才创建和激活 ratio 高度约束。iOS 对应 renderer 同步做了相同调整。
private var fretboardHeightPolicy: ExerciseFretboardHeightPolicy {
    currentPresentationState?.fretboardLayoutContract.heightPolicy
        ?? .followViewportRatio
}

private func rebuildVerticalFretboardHostHeightConstraint() {
    verticalFretboardHostHeightConstraint?.isActive = false
    verticalFretboardHostHeightConstraint = nil

    guard
        isShowingFretboard,
        fretboardHeightPolicy == .followViewportRatio
    else {
        return
    }

    verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
        equalTo: safeAreaHeightAnchor,
        multiplier: currentFretboardDisplayState.verticalHostHeightRatio
    )
    verticalFretboardHostHeightConstraint?.priority = prefersFlexibleVerticalFretboardHeight
        ? .defaultHigh
        : .required
}

private func updateFretboardLayoutModeConstraints() {
    let isVertical = currentFretboardDisplayState.displayMode == .vertical
    let usesViewportRatio = isVertical
        && fretboardHeightPolicy == .followViewportRatio
    verticalFretboardHostHeightConstraint?.isActive = usesViewportRatio
    horizontalFretboardDocumentWidthConstraint?.isActive = !isVertical
    horizontalFretboardContentWidthConstraint?.isActive = !isVertical
    verticalFretboardDocumentWidthConstraint?.isActive = isVertical
    verticalFretboardContentWidthConstraint?.isActive = isVertical
}
```

- 对应镜像改动：
  - `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`

- 结果：`side` 下主 `fretboard` 不再被 `verticalHostHeightRatio` 人为限高，而是由横向 split 的父列约束决定最终高度；`stacked` 仍继续沿用 ratio 语义。

## 5. 修改四：settings / quick panel 跟着共享 contract 走，隐藏 side 下失效的 slider

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数: shouldInclude(sliderID:stateContext:)
// 修改前说明: Vertical Viewport Height 只看 displayMode == vertical，
// 完全不知道 side 下已经不再使用 verticalHostHeightRatio。
private static func shouldInclude(
    sliderID: SettingsSliderID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch sliderID {
    case .verticalHostHeightRatio:
        return stateContext.fretboardDisplayState.displayMode == .vertical
    case .pianoRowCount:
        return true
    case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
        return true
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift
// 函数: makeModel(from:)
// 修改前说明: quick panel 同样只看 vertical displayMode，side 下会继续露出失效 slider。
static func makeModel(from displayState: FretboardDisplayState) -> FretboardControlPanelModel {
    guard displayState.displayMode == .vertical else {
        return .empty
    }

    return FretboardControlPanelModel(
        sections: FretboardControlSectionID.allCases.compactMap {
            makeSection(
                id: $0,
                displayState: displayState
            )
        }
    )
}
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数: fretboardLayoutContract, showsVerticalViewportHeightControl
// 修改后说明: Settings 层先用 shared scene contract 统一判断当前是否仍需要 vertical viewport slider。
var fretboardLayoutContract: ExerciseFretboardLayoutContract {
    let resolvedPreferences = ExerciseSceneValidator.normalizedPreferences(
        exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState
    )
    let scene = ExerciseCompositionPolicy.makeScene(
        preferences: resolvedPreferences
    )
    return scene.fretboardLayoutContract
}

var showsVerticalViewportHeightControl: Bool {
    fretboardDisplayState.displayMode == .vertical
        && fretboardLayoutContract.usesVerticalViewportHeightControl
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数: shouldInclude(sliderID:stateContext:)
// 修改后说明: slider 的出现条件改为复用 shared contract；
// SettingsPanelModel 和 quick panel builder 也同步跟着这套 gate。
private static func shouldInclude(
    sliderID: SettingsSliderID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch sliderID {
    case .verticalHostHeightRatio:
        return stateContext.showsVerticalViewportHeightControl
    case .pianoRowCount:
        return true
    case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
        return true
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift
// 函数: makeModel(from:showsVerticalViewportHeightControl:)
// 修改后说明: quick panel 也显式接收“当前是否应显示 Vertical Viewport Height”。
static func makeModel(
    from displayState: FretboardDisplayState,
    showsVerticalViewportHeightControl: Bool = true
) -> FretboardControlPanelModel {
    guard
        displayState.displayMode == .vertical,
        showsVerticalViewportHeightControl
    else {
        return .empty
    }

    return FretboardControlPanelModel(
        sections: FretboardControlSectionID.allCases.compactMap {
            makeSection(
                id: $0,
                displayState: displayState
            )
        }
    )
}
```

- 对应同步文件：
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`

- 结果：`side + vertical` 下，`Vertical Viewport Height` 不再继续显示；`stacked + vertical` 仍然保留。

## 6. 修改五：navigation / composition validation 对齐到新语义

### 6.1 SettingsNavigationValidation

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数: validateSplitSectionsProduceExpectedPageTree(), validateFretboardViewportRouteVisibilityTracksDisplayMode()
// 修改前说明: default vertical 仍然假设 Fretboard section 会拆成 Display / Viewport 两个子页。
assertIndexPage(
    route: .section(.fretboard),
    expectedTitle: fretboardSection.title,
    expectedRouteItems: [
        SettingsRouteItem(
            title: SettingsRouteID.fretboardDisplay.fallbackTitle,
            subtitle: "Instrument and labels",
            route: .fretboardDisplay
        ),
        SettingsRouteItem(
            title: SettingsRouteID.fretboardViewport.fallbackTitle,
            subtitle: "Vertical sizing",
            route: .fretboardViewport
        )
    ],
    in: navigationModel,
    fixtureName: fixtureName,
    pageDescription: "Fretboard section",
    issues: &issues
)
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数: validateSplitSectionsProduceExpectedPageTree()
// 修改后说明: default side + vertical 下，Fretboard section 应直接收敛为单页 form，不再拆出 Viewport 深层页。
assertFormPage(
    route: .section(.fretboard),
    expectedTitle: fretboardSection.title,
    expectedSection: fretboardSection,
    in: navigationModel,
    fixtureName: fixtureName,
    pageDescription: "Fretboard section",
    issues: &issues
)
if navigationModel.page(for: .fretboardDisplay) != nil
    || navigationModel.page(for: .fretboardViewport) != nil {
    issues.append(
        issue(
            fixtureName,
            "default side + vertical 场景下，Fretboard section 应收敛成单页 form，不再拆出 Display / Viewport 子页。"
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数: validateFretboardViewportRouteVisibilityTracksDisplayMode()
// 修改后说明: side + vertical 与 horizontal 都不再出现 Viewport 深层页；
// stacked + vertical 仍然必须保留该路由。
if sideVerticalNavigationModel.page(for: .fretboardViewport) != nil {
    issues.append(
        issue(
            fixtureName,
            "side + vertical 指板模式下不应继续生成 Fretboard Viewport 深层页。"
        )
    )
}

assertIndexPage(
    route: .section(.fretboard),
    expectedTitle: stackedVerticalFretboardSection.title,
    expectedRouteItems: [
        SettingsRouteItem(
            title: SettingsRouteID.fretboardDisplay.fallbackTitle,
            subtitle: "Instrument and labels",
            route: .fretboardDisplay
        ),
        SettingsRouteItem(
            title: SettingsRouteID.fretboardViewport.fallbackTitle,
            subtitle: "Vertical sizing",
            route: .fretboardViewport
        )
    ],
    in: stackedVerticalNavigationModel,
    fixtureName: fixtureName,
    pageDescription: "Stacked Vertical Fretboard section",
    issues: &issues
)
```

### 6.2 ExerciseCompositionValidation

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible(), validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()
// 修改前说明: default settings snapshot 仍要求暴露 Viewport Height；
// targetPrompt/staff 的 sideBySide 组合仍要求“不应误触发 viewport pin”。
if defaultPanelModel.sliderRow(for: .verticalHostHeightRatio) == nil {
    issues.append(
        issue(
            fixtureName,
            "vertical default settings snapshot 应继续暴露 Viewport Height 滑块。"
        )
    )
}

if sideBySideTargetPromptPresentation.scene.requiresViewportPinnedHeight {
    issues.append(
        issue(
            fixtureName,
            "targetPrompt -> fretboard 的 sideBySide 组合在阶段 2 不应误触发 viewport pin 高度语义。"
        )
    )
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible()
// 修改后说明: default side + vertical 下不再暴露 slider；显式 stacked + vertical 仍然必须保留。
if defaultPanelModel.sliderRow(for: .verticalHostHeightRatio) != nil {
    issues.append(
        issue(
            fixtureName,
            "默认 side settings snapshot 不应继续暴露 Viewport Height 滑块。"
        )
    )
}

if stackedVerticalPanelModel.sliderRow(for: .verticalHostHeightRatio) == nil {
    issues.append(
        issue(
            fixtureName,
            "stacked + vertical settings snapshot 应继续暴露 Viewport Height 滑块。"
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes(), validateViewportPinningContractsPreserveRailAndStackedLayouts()
// 修改后说明: side + 主 fretboard 的 shared contract 现在必须同时满足
// “pin viewport”与“fillAvailableHeight”；stacked 继续走 followViewportRatio。
if !sideBySideTargetPromptPresentation.scene.requiresViewportPinnedHeight {
    issues.append(
        issue(
            fixtureName,
            "targetPrompt -> fretboard 的 sideBySide 组合在阶段 2 应通过 shared helper 请求 viewport pin 高度。"
        )
    )
}
if sideBySideTargetPromptPresentation.fretboardLayoutContract.heightPolicy
    != .fillAvailableHeight {
    issues.append(
        issue(
            fixtureName,
            "targetPrompt -> fretboard 的 sideBySide 组合在阶段 2 应让主 fretboard 跟随 side 容器填满高度。"
        )
    )
}

if stackedPresentation.fretboardLayoutContract.heightPolicy
    != .followViewportRatio {
    issues.append(
        issue(
            fixtureName,
            "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续沿用 viewport ratio 高度语义。"
        )
    )
}
```

- 结果：validation 不再沿用“旧 side 不 pin / 默认 vertical 必有 slider”的假设，而是明确冻结新的共享高度 contract。

## 7. 最终结果

- `sideBySide + 主 fretboard` 统一收口为 shared contract：
  - `pinsSceneToViewportHeight = true`
  - `heightPolicy = fillAvailableHeight`
- `stacked` 继续保留 `followViewportRatio`
- macOS / iOS controller 都改为消费这套 contract
- macOS / iOS renderer 都改为只在 `followViewportRatio` 下使用 `verticalHostHeightRatio`
- `side + vertical` 下 `Vertical Viewport Height` 与 `Fretboard > Vertical Viewport` 子页消失
- `stacked + vertical` 下相关 slider 与 route 继续保留

## 8. 验证结果

- `ReadLints` 检查本轮修改文件：无新增 linter 错误
- macOS 构建验证：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build` 通过
- iOS 模拟器构建验证：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build` 通过
- 当前仓库里已有的旧 warning 仍存在，本轮未额外处理
- 本轮未额外执行启动后的手工界面截图/录屏验证

## 9. 一句话总结

这次改动不是把 `side` 下某个高度比例调大，而是从架构上把“scene 是否贴满 viewport”和“fretboard 是否跟随容器高度”抽成共享 contract，再让平台 renderer、settings 和 validation 全部消费同一套语义，从根因上消除了 `side` 下高度偏矮与控件语义失真的问题。

---
name: side fretboard height
overview: 为所有包含主 `fretboard` 的 `sideBySide` 场景建立统一的共享高度 contract，让 scene 容器与 fretboard 宿主都由共享语义决定是否铺满可视区域，并同步 settings、quick panel 与 validation。
todos:
  - id: shared-height-contract
    content: 在 shared exercise 层新增 scene viewport pin 与 fretboard height 的统一 contract
    status: completed
  - id: controllers-consume-contract
    content: 让 iOS/macOS controller 改为消费新的 viewport pin contract
    status: completed
  - id: renderers-fill-height
    content: 让 iOS/macOS renderer 在 side 下移除 ratio 高度约束并跟随容器高度
    status: completed
  - id: settings-hide-dead-slider
    content: 同步 settings 与 quick panel，在 side 下隐藏 Vertical Viewport Height
    status: completed
  - id: validation-upgrade
    content: 更新 composition/navigation/fretboard validation 以冻结新语义
    status: completed
  - id: build-and-regression
    content: 执行双端构建与 side/stacked 高度回归验证
    status: completed
isProject: false
---

# Side 模式指板铺满高度计划

## 目标

- 让所有包含主 `fretboard` 的 `sideBySide` 场景在 iOS / macOS 上都撑满可视区域。
- 把“scene 是否 pin 到 viewport 高度”和“fretboard 是否跟随容器高度”收口到共享 contract，避免平台 renderer 再靠启发式约束决定高度。
- `side` 下隐藏 `Vertical Viewport Height`，避免 settings / quick panel 暴露失效控件。

## 现状收敛

- [NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift) 已把 `sideBySide` 投影成横向 split，左右 child host 在 renderer 中会被顶/底对齐。
- [NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift) 与 [NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift](NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift) 目前只在 `scene.requiresViewportPinnedHeight` 为真时启用 `sceneViewportHeightConstraint`，纯 `side` 场景不一定 pin 根容器高度。
- [NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift) 与 [NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift) 还会给 `fretboardHostView` 施加 `safeAreaHeight * verticalHostHeightRatio` 的额外高度约束，这和“外部容器决定高度”冲突。
- [NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift)、[NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift)、[NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift) 当前只按 `displayMode == .vertical` 暴露 `Vertical Viewport Height`，没有感知 `side` 下的新 fill-height 语义。

## 实施步骤

### 1. 新增共享高度 contract

- 在 [NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift](NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift) 附近新增共享布局 contract，例如：
- `pinSceneToViewportHeight`
- `fretboardHeightPolicy`（如 `followViewportRatio` / `fillAvailableHeight`）
- 该 contract 从 `scene`、`resolvedLayoutPreferences`、`renderedSceneLayout` 推导，不挂在平台 renderer，也不塞进 `ExerciseSurfaceState`。
- 推导规则按本次确认收口：所有包含主 `fretboard` 的 `sideBySide` 场景一律走 `pinSceneToViewportHeight = true`、`fretboardHeightPolicy = fillAvailableHeight`；`stacked` / `singleSurface` 继续沿用 ratio 语义。

### 2. 控制器消费统一的 viewport pin 语义

- 在 [NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift) 与 [NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift](NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift) 中，把 `updateSceneViewportHeightConstraint()` 从直接读取 `scene.requiresViewportPinnedHeight` 改为读取新的共享 contract。
- 保持 `sceneViewportHeightConstraint` 只负责“scene 根容器是否钉到 safe area 高度”，不要继续混入 fretboard 自身高度决策。
- 复查 macOS 的 settlement / layout pass 路径，确保 scene root 被 pin 后不会引入新的布局抖动。

### 3. Renderer 改为按高度策略切换约束

- 在 [NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift) 与 [NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift) 中，让 `rebuildVerticalFretboardHostHeightConstraint()` / `updateFretboardLayoutModeConstraints()` 基于新的 shared `fretboardHeightPolicy` 行为切换。
- `fillAvailableHeight` 下：不再激活 `verticalFretboardHostHeightConstraint`，让 `side` 横向 split 的父列约束决定 `fretboardHostView` 的最终高度；fretboard 只根据拿到的 viewport height 更新内容尺寸和滚动表现。
- `followViewportRatio` 下：保留现有 `verticalHostHeightRatio` 逻辑，避免影响 `stacked` 与非 `side` 路径。
- 不做平台层的孤立 `if side` 特判，platform 只消费 shared contract。

### 4. Settings 与 quick panel 同步到新语义

- 在 [NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift](NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift) 增加统一 helper，或在 builder 内复用同一套 shared 推导，判断当前是否仍需要 `verticalHostHeightRatio`。
- 更新 [NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift)、[NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift)、[NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift](NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift)，让 `side` 下隐藏 `Vertical Viewport Height` 和 `Fretboard > Vertical Viewport` 子页。
- 更新 [NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift)，确保 quick panel 也不会在 `side` 下暴露失效 slider。

### 5. Validation 一起升级

- 在 [NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift) 冻结新的共享 contract：
- `sideBySide` + 主 `fretboard` => scene 需要 pin viewport，高度策略为 fill available height
- `stacked` / `singleSurface` => 维持 ratio-driven 语义
- 更新之前把某些 `sideBySide` 视为“不应 pin viewport”的 fixture，避免 shared contract 与 validation 再次分叉。
- 在 [NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift](NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift) 更新 `fretboardViewport` 的出现条件、默认 snapshot 和路径回退断言。
- 视需要检查 [NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift](NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift) 中与 `defaultVerticalHostHeightRatio` 相关的断言，把范围收窄到仍使用 ratio 的场景。

### 6. 验证与回归

- 构建验证：macOS / iOS 都跑 `xcodebuild`。
- 手工回归至少覆盖：
- `positionPrompt` / `single` / `sequence`
- `stacked` / `sideBySide`
- `vertical` / `horizontal` fretboard display mode
- 带 `verticalRail` 的右侧 strip 和不带 rail 的 side 场景
- live resize、切换 layout 时 settings 子页稳定性、启动默认 layout = `side`
- 重点观察：`side` 下 fretboard 是否真正贴满可视列高度、底部是否残留空白、scroll/constraint 是否振荡、`Vertical Viewport Height` 是否完全从不适用路径消失。

## 关键文件

- [NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift](NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift)
- [NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift)
- [NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift)
- [NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift](NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift)
- [NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift)
- [NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift)
- [NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift](NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift)
- [NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift)
- [NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift)
- [NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift)
- [NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift](NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift)
- [NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift](NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift)


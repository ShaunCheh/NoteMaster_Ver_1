---
name: macos layout guard
overview: 修复 macOS 上 `stacked/side` 切换反复崩溃的问题，通过建立“settings 事件栈内禁止 root layout”的硬边界，重新收口 scene render 与 layout settlement 的职责，同时保留已生效的 settings 复用修复。
todos:
  - id: add-settings-mutation-guard
    content: 为 settings event 整段生命周期建立通用 mutation guard，替换当前仅用于 trace 的窄信号
    status: pending
  - id: split-render-and-settle
    content: 把 renderExercisePresentationState 收敛成只做 Phase A，移除同步 root layout flush
    status: pending
  - id: rebuild-settlement-path
    content: 重写 settlement 调度逻辑，保证只在脱离 settings action 栈后执行 root-level settlement
    status: pending
  - id: verify-macos-toggle-regression
    content: 验证启动首帧、stacked/side 往返切换、settings 子页稳定性以及双平台构建
    status: pending
isProject: false
---

# macOS 切换防崩计划

## 目标

让 macOS 上 `Layout Preset` 在 `stacked` 与 `side` 间反复切换时不再崩溃，并且不回退已经生效的 same-route settings page/row/button 复用修复。

## 现状结论

- 当前问题链路仍然是同步的：`handleSettingsPanelEvent()` -> `synchronizeExerciseCompositionState()` -> `exercisePresentationState.didSet` -> `renderExercisePresentationState()` -> `settleSceneLayoutIfNeeded()` -> `view.layoutSubtreeIfNeeded()`。
- [NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift) 里 `renderExercisePresentationState()` 仍会直接触发 settlement；而 settlement 的布局目标是控制器根 `view`，会把仍在 dispatch 的 settings 子树一起拉进本次布局。
- [NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift](NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift) 的 `render()` 负责 scene tree 重建，这部分可以保留；真正需要从 action 栈中移出的，是 root-level layout flush。
- [NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift) 已有 `macOSSettingsMutationTrace`，但当前 `activeEventID` 只是窄范围 trace 信号，不能直接当长期稳定的防崩边界。

## 修改方案

- 在 [NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift) 建立真正的“settings mutation 进行中”保护信号。
不是继续依赖当前只覆盖 `layoutPreset` 的 trace，而是给 `handleSettingsPanelEvent()` 整段生命周期一个统一的 mutation guard，用来表达“当前仍在 settings action 同步栈内”。
- 把 `renderExercisePresentationState()` 改成纯 `Phase A`。
它只负责更新 `sceneViewportHeightConstraint`、调用 renderer 的 `render()`、标记 scene 已渲染和 settlement dirty；不再在这里同步执行 `layoutSubtreeIfNeeded()`。
- 重写 `scheduleSceneLayoutSettlementIfNeeded()` / `settleSceneLayoutIfNeeded()` 的职责边界。
如果当前仍在 settings mutation 栈内，或首帧 bounds 仍未稳定，就只做合并调度并推迟到下一轮主线程；只有脱离 mutation 栈后，才执行受控的两阶段 settlement。
- 保留 `viewDidLayout()` 作为几何变化观察者，不让它直接承担动态约束修改职责。
它只负责发现 `sceneContainerView.bounds` 变化并触发下一次调度，不在 AppKit layout 回调里同步改 scene 动态约束。
- 保留并冻结现有 settings 复用链路。
[NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsNavigatorView.swift)、[NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift)、[NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsIndexPageView.swift) 不回退，避免重新引入“当前 page/row/button 在 action 期间被拆掉”的旧问题。

## 验证边界

- macOS 启动首帧：确认不再白屏，首帧内容能在 bounds 稳定后正常 settle。
- `stacked -> side -> stacked` 往返切换：连续多次切换不崩溃，且 `natural note strip` 在 rail/stacked 间形态恢复正确。
- Settings 稳定性：停留在 `Exercise > Layout` 子页直接切换 layout，不跳页、不闪回、不 teardown 当前 page。
- 构建回归：至少重新验证 macOS 与 iOS 编译链，确认本次 controller 收口调整没有引入跨平台编译回归。

## 交付标准

- `settings` 事件同步栈内不再发生 root `layoutSubtreeIfNeeded()`。
- scene render 与 scene settlement 的职责边界在 controller 内单点收口，后续再改 layout preset 不会反复踩回同类崩溃。
- 已经修好的 settings same-route 复用边界保持不变。


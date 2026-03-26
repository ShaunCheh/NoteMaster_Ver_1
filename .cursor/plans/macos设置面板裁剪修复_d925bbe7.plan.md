---
name: macOS设置面板裁剪修复
overview: 修复 macOS 设置面板中 `Spelling` 等标题被垂直压缩显示不全的问题，优先从 `NSScrollView` 与 `documentView` 的架构约束根因入手，而不是局部调字号或间距。方案会保持 shared settings model 与 iOS 实现不变，只收敛到 macOS 容器与必要的标题抗压缩加固。
todos:
  - id: audit-container-constraints
    content: 重构 `macOSSettingsContainerView` 的 `NSScrollView/documentView` 约束，让内容高度由 `settingsPanelView` 驱动并在超高时滚动
    status: pending
  - id: harden-choice-row-title
    content: 在 `macOSSettingsPanelView.ChoiceRowView` 上补充标题垂直抗压缩保护，避免边界场景再次被压扁
    status: pending
  - id: verify-macos-settings-layout
    content: 验证 macOS 设置弹层在短内容、长内容、模型切换后的完整显示与滚动行为
    status: pending
isProject: false
---

# macOS 设置面板裁剪修复计划

## 目标

修正 macOS 设置卡片里 settings 内容区的滚动/高度语义，让 `settingsPanelView` 的真实内容高度驱动 `documentView`，超出卡片上限时通过纵向滚动承载，而不是把 `ChoiceRowView` 内部标题压扁。

## 架构判断

- 根因主入口在 [NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift)。当前容器把 `contentView` 四边钉到 `scrollView.contentView`，同时又把 `settingsPanelView` 四边钉满 `contentView`，导致文档区高度被锁进视口高度语义里。
- 内容固有高度由 [NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift) 的 `intrinsicContentSize` 提供，这条职责边界本身是对的，应该保留。
- 项目里已有一条更合理的 macOS scroll 架构参考： [NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift](NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift) 的主滚动区没有把 `documentView.bottom` 锁死到 `clip view.bottom`；iOS 侧 [NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift](NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift) 也通过 `contentLayoutGuide/frameLayoutGuide` 明确区分了内容区和视口。

## 修改方案

### 1. 先从容器层修正滚动内容高度语义

- 在 [NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift) 重构 `NSScrollView` 约束。
- 目标是让 `contentView` / `settingsPanelView` 的真实高度可以大于 scroll 可视高度。
- 优先采用与现有项目架构一致的方案：去掉把 `documentView` 高度锁进 `scrollView.contentView` 的约束关系，保留宽度约束与顶部约束，让 `settingsPanelView` 通过 intrinsic height 撑开 `documentView`。
- 如果当前部署目标允许并且工程已有稳定使用方式，也可以评估改成与 iOS 对齐的 `contentLayoutGuide/frameLayoutGuide` 语义；但实现上以最少新概念、最贴近现有 macOS 代码惯例为准。
- 保留现有 `scrollView.height == settingsPanelView.height` 的低优先级“贴内容高度”策略，以及 `scrollView.height <= maximumScrollHeight` 的上限策略，确保内容少时卡片不空、内容多时可滚动。

### 2. 对标题行做局部抗压缩加固

- 在 [NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift) 的 `ChoiceRowView` 上补一层防御性布局设置。
- 重点不是改视觉样式，而是提高标题在垂直方向的抗压缩能力，避免未来某些边界场景下标题再次被先行压到 0 高度。
- 这一步只作为保险，不承担根因修复职责。

### 3. 保持边界稳定，不扩散到共享层和 iOS

- 不修改 [NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift](NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift) 与 [NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift](NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift)。
- 不修改 iOS 侧 settings panel / container 的布局实现，避免把 macOS 专属问题扩散到双端共享层。

## 验证计划

- 在 macOS 设置面板中确认 `Spelling`、`Octave`、`Content`、`Type` 等靠下 row 的标题完整显示。
- 确认内容较少时，settings 卡片高度仍然跟随内容，不出现大块空白。
- 确认内容超过 `maximumScrollHeight` 时，面板可以纵向滚动到底部，底部 row 不再被压扁。
- 验证切换顶部内容、指板模式、Clef、Label 等会触发 `applyModel()` 的场景后，高度与滚动仍然稳定。
- 跑最近修改文件的 lint，确保未引入新的 macOS 布局相关告警。

## 风险与回归点

- `NSScrollView` 的 `documentView` 约束改动可能影响初次展示时的 content size 计算，需要重点观察打开设置弹层的首帧布局。
- 如果只做 `ChoiceRowView` 标题加固而不修容器，问题会在更多 row 或更小窗口上继续出现，因此必须以容器重构为主、标题加固为辅。
- 由于 [NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift](NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift) 是设置壳层唯一入口，这次改动应局限在设置浮层，不会波及主页面滚动区。


# 20260911_161756_bcr1_fit_content_surface_layout_fix

- 时间戳来源：系统自带命令 `date '+%Y%m%d_%H%M%S%n%Y-%m-%d %H:%M:%S %z'`
- 时间戳结果：`20260911_161756`
- 本地时间：`2026-09-11 16:17:56 +0800`
- 记录范围：修复 BCR-1 三层 Exercise Scene 中 `.fitContent` surface 被垂直拉伸的问题；使“线上 / 间上 / 混合”选择器与 Staff 保持各自的固有高度，并让加权 Piano surface 吸收剩余高度
- 记录依据：创建本记录前的 `git status --short`、`git diff --name-status`、`git diff --stat`、`git diff --numstat`、按文件检查的当前 Changes，以及实际执行的双平台构建与 runtime smoke 输出
- 本记录不粘贴原始 `git diff`；下文使用整理后的“修改前 / 修改后”代码片段说明实际差异
- 创建本记录前的当前 Changes：仅有 6 个已修改 Swift 文件，统计为 `120 insertions(+) / 2 deletions(-)`；没有其它已修改或未跟踪文件
- 本记录步骤只新增此 Markdown 文件；没有继续修改 Swift 源代码、没有修改既有 Markdown 文件、没有提交 Git commit

```bash
# 文件路径: /Users/shaun/cloudDev/NoteMaster_Ver_1（工程记录命令）
# 命令/测试名: 系统 date 命令
# 功能说明: 生成本记录文件名和标题使用的下划线时间戳；以下为实际命令和实际输出。
date '+%Y%m%d_%H%M%S%n%Y-%m-%d %H:%M:%S %z'

# 实际输出:
20260911_161756
2026-09-11 16:17:56 +0800
```

## 1. 创建记录前的实际 Changes

### 1.1 iOS

- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
  - `.fitContent` sizing 从只设置无固有尺寸的 child host，改为同时约束实际 surface view
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
  - Piano 的垂直 content hugging priority 从 `.required` 改为 `.defaultLow`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - BCR-1 runtime smoke 新增真实 frame 与 intrinsic height 的比较

### 1.2 macOS

- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
  - 镜像 iOS 的 `.fitContent` 实际 surface priority 处理
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
  - 镜像 iOS 的 Piano 垂直 content hugging priority 调整
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
  - 镜像 iOS 的 BCR-1 真实 frame 回归断言

## 2. 问题现象与根因

截图中的 BCR-1 Scene 是三层垂直布局：

1. `questionModeSelector`：上层，`.fitContent`
2. `staff`：中层，`.fitContent`
3. `piano`：下层，`.weighted(1)`

选择器自身已经有固有高度：iOS/macOS 都是系统 segmented control 的固有高度加上下各 `8pt`，不是选择器直接声明了几百点的固定高度。

但原 renderer 对 `.fitContent` 只给中间的 `childHostView` 设置 hugging/compression priority。这个 host 是普通 `UIView` / `NSView`，本身没有 intrinsic content size；真正具有固有高度的是其内部被 top/bottom 填充约束固定到 host 的 selector 或 Staff view。

因此，在根 Scene 需要填满 viewport 时，Auto Layout 无法通过无固有尺寸的 host 可靠地保护 selector/Staff 高度。Piano keyboard 还以 `.required` 垂直 hugging 阻止自身扩展，导致剩余垂直空间可能被错误分配给上方 `.fitContent` surface，表现为截图中的超高 segmented control 区域。

修复目标不是给 BCR-1 selector 追加固定高度，而是恢复 Scene 的通用 sizing 合同：

- `.fitContent` 必须约束真正带 intrinsic size 的 surface
- `.weighted` surface 必须能够接收剩余空间
- 规则必须同时用于 iOS/macOS 和其它未来 `.fitContent` surface

## 3. Renderer：`.fitContent` 从 host priority 扩展为实际 surface priority

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.configureMainAxisSizing(_:for:axis:)
// 功能说明: 修改前仅给 childHostView 设置优先级；childHostView 没有 intrinsic content size，
// 因此不能直接代表嵌入其内部的 selector、Staff 等实际 surface 的内容高度。
private func configureMainAxisSizing(
    _ mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing,
    for childHostView: UIView,
    axis: ExerciseSceneAxis
) {
    switch (axis, mainAxisSizing) {
    case (_, .weighted):
        return
    case (.vertical, .fitContent):
        childHostView.setContentHuggingPriority(.required, for: .vertical)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    case (.horizontal, .fitContent):
        childHostView.setContentHuggingPriority(.required, for: .horizontal)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
    // fixed 分支保持原有实现。
    }
}
```

macOS 的 `macOSExerciseSceneRenderer.configureMainAxisSizing(_:for:axis:)` 具有同样的 host-only 行为。

### 3.2 修改后

`renderSplit(axis:children:in:)` 现在把每个 child 对应的 `ExerciseSceneNode` 一并传入 sizing 函数。这样 renderer 可以从直接 `.surface` node 找到实际 UIKit/AppKit view。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.renderSplit(axis:children:in:)
// 功能说明: 将 Scene child node 交给尺寸策略，使 .fitContent 能解析真实 surface，而不是只处理 host。
for (index, childHostView) in childHostViews.enumerated() {
    configureMainAxisSizing(
        children[index].mainAxisSizing,
        for: childHostView,
        node: children[index].node,
        axis: axis
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.configureMainAxisSizing(_:for:node:axis:),
//        iOSExerciseSceneRenderer.configureFitContentPriorities(for:axis:)
// 功能说明: .fitContent 除保留 host 的优先级外，还直接锁定实际 surface 的 hugging/compression；
// 仅接受直接 surface node，若 Scene 合同被破坏则在 Debug 中触发 assertion。
private func configureMainAxisSizing(
    _ mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing,
    for childHostView: UIView,
    node: ExerciseSceneNode,
    axis: ExerciseSceneAxis
) {
    switch (axis, mainAxisSizing) {
    case (_, .weighted):
        return
    case (.vertical, .fitContent):
        configureFitContentPriorities(for: node, axis: .vertical)
        childHostView.setContentHuggingPriority(.required, for: .vertical)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    case (.horizontal, .fitContent):
        configureFitContentPriorities(for: node, axis: .horizontal)
        childHostView.setContentHuggingPriority(.required, for: .horizontal)
        childHostView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
    // fixed 分支保持原有实现。
    }
}

private func configureFitContentPriorities(
    for node: ExerciseSceneNode,
    axis: ExerciseSceneAxis
) {
    guard
        case let .surface(surface) = node,
        let surfaceView = view(for: surface.id)
    else {
        assertionFailure(
            "fitContent scene children must contain a direct surface."
        )
        return
    }

    switch axis {
    case .vertical:
        surfaceView.setContentHuggingPriority(.required, for: .vertical)
        surfaceView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    case .horizontal:
        surfaceView.setContentHuggingPriority(.required, for: .horizontal)
        surfaceView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: macOSExerciseSceneRenderer.configureMainAxisSizing(_:for:node:axis:),
//        macOSExerciseSceneRenderer.configureFitContentPriorities(for:axis:)
// 功能说明: macOS 镜像从直接 Exercise surface 解析 NSView，并在对应主轴设置 required 优先级；
// 这样 BCR-1 与 iOS 使用相同的 .fitContent 业务合同。
private func configureFitContentPriorities(
    for node: ExerciseSceneNode,
    axis: ExerciseSceneAxis
) {
    guard
        case let .surface(surface) = node,
        let surfaceView = view(for: surface.id)
    else {
        assertionFailure(
            "fitContent scene children must contain a direct surface."
        )
        return
    }

    switch axis {
    case .vertical:
        surfaceView.setContentHuggingPriority(.required, for: .vertical)
        surfaceView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    case .horizontal:
        surfaceView.setContentHuggingPriority(.required, for: .horizontal)
        surfaceView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
    }
}
```

实际效果：

- BCR-1 selector 的子 view 保持 `intrinsicContentSize.height`
- BCR-1 Staff 保持 `StaffConfiguration.preferredHeight`
- 其它 direct `.fitContent` Scene surface 同样获得正确的内容优先级
- 若将来 `.fitContent` 使用非 direct surface child，Debug assertion 能立即暴露错误的 Scene 结构

## 4. Piano：使 weighted surface 吸收剩余垂直空间

### 4.1 修改前

Piano keyboard 在垂直方向具有 `.required` content hugging priority。这与它作为 `.weighted(1)` answer surface 的职责冲突：它会尝试保留自己的 intrinsic height，而不是优先接收 `.fitContent` 上方区域之外的可用空间。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: iOSPianoKeyboardView.configureView()
// 功能说明: 修改前 Piano 垂直 hugging 为 required，会与上方 fit-content surface 竞争 viewport 的剩余高度。
func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    isMultipleTouchEnabled = true
    setContentHuggingPriority(.defaultLow, for: .horizontal)
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    applyBackingState()
    applyConfiguration()
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名: iOSPianoKeyboardView.configureView()
// 功能说明: Piano 仍以 required compression resistance 保护最小可用内容高度，
// 但以 defaultLow hugging 接收 weighted Scene 剩余高度。
func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    isMultipleTouchEnabled = true
    setContentHuggingPriority(.defaultLow, for: .horizontal)
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    // Piano is a weighted Exercise surface and must be able to absorb
    // vertical space left by fit-content prompt surfaces.
    setContentHuggingPriority(.defaultLow, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    applyBackingState()
    applyConfiguration()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名: macOSPianoKeyboardView.configureView()
// 功能说明: macOS 对 Piano 使用相同的“低 hugging、必需压缩阻力”规则，
// 保证 weighted answer surface 吸收剩余高度而不会低于可用的固有内容高度。
func configureView() {
    wantsLayer = true
    acceptsTouchEvents = true
    layerContentsRedrawPolicy = .duringViewResize
    setContentHuggingPriority(.defaultLow, for: .horizontal)
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    // Piano is a weighted Exercise surface and must be able to absorb
    // vertical space left by fit-content prompt surfaces.
    setContentHuggingPriority(.defaultLow, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    applyBackingState()
    applyConfiguration()
}
```

这不是把 Piano 设为无约束高度。它仍保留 required compression resistance，因此不能被压缩到低于最小内容需要；变化仅允许它扩展以填补 Scene 剩余高度。

## 5. Runtime smoke：从结构验证补足真实高度验证

### 5.1 修改前

原 BCR-1 runtime smoke 验证了：

- Scene 有 `selector -> Staff -> Piano` 三个 child
- 三者 sizing 声明为 `.fitContent / .fitContent / .weighted(1)`
- selector 可见、文本和默认选中态正确
- Staff 使用 BCR-1 额外垂直留白

但这些只验证了共享 Scene 数据模型，无法发现 renderer 最终把实际 selector 或 Staff frame 拉高的问题。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.runBCR1PianoAnswerSmokeTest(in:completion:) 的 switch_to_bcr1_default_mixed 验证闭包
// 功能说明: 修改前只验证 selector 的可见性、文案、默认模式和 Staff 配置，不读取真实 bounds 高度。
guard self.exercisePresentationState
    .projectedSurfaceState(for: .questionModeSelector)
    == .auxiliaryOnly,
    self.bcr1QuestionModeSelectorView.displayedTitles
        == ["线上", "间上", "混合"],
    self.bcr1QuestionModeSelectorView.selectedMode == .mixed,
    !self.bcr1QuestionModeSelectorView.isHidden,
    self.staffDisplayState.configuration.additionalVerticalStaffSpaces
        == TrainerBCR1QuestionConfiguration
            .staffAdditionalVerticalSpaces else {
    return "reason=selector_not_visible_default_mixed"
}
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.runBCR1PianoAnswerSmokeTest(in:completion:) 的 switch_to_bcr1_default_mixed 验证闭包
// 功能说明: 在 UI 已完成布局后，验证 selector 和 Staff 的实际 bounds.height
// 与其 intrinsicContentSize.height 的偏差不超过 Layout.contentSizeTolerance。
let selectorIntrinsicHeight =
    self.bcr1QuestionModeSelectorView.intrinsicContentSize.height
let staffIntrinsicHeight =
    self.staffView.intrinsicContentSize.height
guard selectorIntrinsicHeight > 0,
      staffIntrinsicHeight > 0,
      abs(
        self.bcr1QuestionModeSelectorView.bounds.height
            - selectorIntrinsicHeight
      ) <= Layout.contentSizeTolerance,
      abs(
        self.staffView.bounds.height
            - staffIntrinsicHeight
      ) <= Layout.contentSizeTolerance else {
    return "reason=fit_content_height_mismatch selector=\(self.bcr1QuestionModeSelectorView.bounds.height)/\(selectorIntrinsicHeight) staff=\(self.staffView.bounds.height)/\(staffIntrinsicHeight)"
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.runBCR1PianoAnswerSmokeTest(in:completion:) 的 switch_to_bcr1_default_mixed 验证闭包
// 功能说明: macOS 使用与 iOS 相同的 intrinsic/frame 容差检查，防止双平台 layout contract 漂移。
let selectorIntrinsicHeight =
    self.bcr1QuestionModeSelectorView.intrinsicContentSize.height
let staffIntrinsicHeight =
    self.staffView.intrinsicContentSize.height
guard selectorIntrinsicHeight > 0,
      staffIntrinsicHeight > 0,
      abs(
        self.bcr1QuestionModeSelectorView.bounds.height
            - selectorIntrinsicHeight
      ) <= Layout.contentSizeTolerance,
      abs(
        self.staffView.bounds.height
            - staffIntrinsicHeight
      ) <= Layout.contentSizeTolerance else {
    return "reason=fit_content_height_mismatch selector=\(self.bcr1QuestionModeSelectorView.bounds.height)/\(selectorIntrinsicHeight) staff=\(self.staffView.bounds.height)/\(staffIntrinsicHeight)"
}
```

`Layout.contentSizeTolerance` 在 iOS/macOS 都是 `0.5pt`。该断言直接覆盖截图中出现的问题：若 selector 或 Staff 被额外拉伸，smoke 会输出实际 frame/intrinsic 高度并失败，而不再只报告 Scene 数据模型正确。

## 6. 实施过程中的实际定位结果

初次只让 selector 获取固有高度时，iOS BCR-1 runtime smoke 的实际输出为：

```bash
# 文件路径: iOS BCR-1 runtime smoke 输出
# 命令/测试名: RuntimeSmokeScenario.bcr1-piano-answer
# 功能说明: selector 已是正确固有高度，但 Staff 仍被拉伸，证明剩余高度分配仍未交给 weighted Piano。
[RuntimeSmoke][iOS] FAIL scenario=bcr1_piano_answer step=switch_to_bcr1_default_mixed reason=fit_content_height_mismatch selector=47.0/47.0 staff=359.0/131.25
```

该输出确认问题并非 selector 的 intrinsic size 丢失，而是 weighted Piano 的 required vertical hugging 阻止它吸收剩余高度。将 Piano vertical hugging 调整为 `.defaultLow` 后，iOS 与 macOS 的最终 BCR-1 runtime smoke 都通过。

## 7. 最终验证结果

### 7.1 静态检查

- 对 6 个修改后的 Swift 文件读取 IDE diagnostics：无 linter 错误
- `git diff --check`：通过

### 7.2 双平台 Debug 构建

```bash
# 文件路径: /Users/shaun/cloudDev/NoteMaster_Ver_1（工程验证命令）
# 命令/测试名: xcodebuild macOS 与 iOS Simulator Debug
# 功能说明: 编译最终的 renderer、Piano priority 和 runtime smoke frame 断言。
xcodebuild \
  -project NoteMaster_Ver_1.xcodeproj \
  -scheme NoteMaster_Ver_1 \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/NoteMaster-FitContent-macOS \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project NoteMaster_Ver_1.xcodeproj \
  -scheme NoteMaster_Ver_1 \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/NoteMaster-FitContent-iOS \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- macOS Debug：`** BUILD SUCCEEDED **`
- iOS Simulator Debug：`** BUILD SUCCEEDED **`

构建输出仍包含工程既有的 Swift 并发隔离 warning，以及 macOS `acceptsTouchEvents` deprecation warning；它们不由本次改动引入，且没有阻断构建。

### 7.3 最终 BCR-1 runtime smoke

```bash
# 文件路径: /tmp/NoteMaster-FitContent-macOS/Build/Products/Debug/NoteMaster_Ver_1.app
# 命令/测试名: RuntimeSmokeScenario.bcr1-piano-answer（macOS）
# 功能说明: 切入 BCR-1、完成真实布局、验证 selector/Staff 的 intrinsic frame，
# 并继续验证选择器切换、生成、判题、播放中断和离开模式后的状态清理。
NOTE_MASTER_RUNTIME_SMOKE_TEST=bcr1-piano-answer \
  /tmp/NoteMaster-FitContent-macOS/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1
```

```bash
# 文件路径: /tmp/NoteMaster-FitContent-iOS/Build/Products/Debug-iphonesimulator/NoteMaster_Ver_1.app
# 命令/测试名: RuntimeSmokeScenario.bcr1-piano-answer（iOS Simulator）
# 功能说明: 安装最终 Simulator build 并运行与 macOS 相同的 BCR-1 真实 frame 回归测试。
xcrun simctl install DD672436-D01E-40AA-92E3-3FDACB01D5CE \
  /tmp/NoteMaster-FitContent-iOS/Build/Products/Debug-iphonesimulator/NoteMaster_Ver_1.app

SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=bcr1-piano-answer \
  xcrun simctl launch --console-pty --terminate-running-process \
  DD672436-D01E-40AA-92E3-3FDACB01D5CE \
  shaunyu.NoteMaster-Ver-1
```

最终实际结果：

- macOS：`[RuntimeSmoke][macOS] PASS scenario=bcr1_piano_answer finalMode=single`
- iOS Simulator：`[RuntimeSmoke][iOS] PASS scenario=bcr1_piano_answer finalMode=single`

在最终实现之前、同一功能修复流程中还已执行：

- 双平台 startup validation：全部 PASS
- 双平台 SR-0、SR-1、SR-2 runtime smoke：全部 PASS

这确认新的实际 surface sizing 规则没有破坏既有的 natural note strip、Staff-to-Piano 或 sequence answer 流程。

## 8. 明确未修改的边界

- 没有给 BCR-1 selector 设置固定高度、最大高度或仅针对 BCR-1 的高度常量
- 没有改变 selector 自身的“系统 segmented control 固有高度 + 16pt”定义
- 没有改变 BCR-1 的“线上 / 间上 / 混合”选项、出题策略、8 音数量、谱号或判题规则
- 没有改变 Scene 模型的 `.fitContent / .weighted(1)` 声明
- 没有改变 Piano 的横向 priority
- 没有移除 Piano 的垂直 compression resistance
- 没有修改 Settings、Staff 音高生成、Playback、Exercise policy 或 shared validation 文件
- 没有修改任何既有 Markdown 文件
- 没有提交 Git commit

## 9. 结论

本次修复将 `.fitContent` 从“只标记没有固有尺寸的布局 host”改为“实际保护直接 surface 的固有尺寸”，并让 `.weighted(1)` Piano 遵循其应有的剩余空间吸收职责。最终 BCR-1 的 selector 与 Staff 以内容高度呈现，Piano 占用剩余垂直区域；该行为不是固定像素补丁，而是同时适用于 iOS/macOS 的通用 Scene sizing 规则。真实 frame 断言已加入双平台 BCR-1 runtime smoke，以防止该问题再次静默回归。

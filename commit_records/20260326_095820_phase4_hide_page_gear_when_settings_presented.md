# 20260326_095820_phase4_hide_page_gear_when_settings_presented

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_095820`
- 记录范围：`设置关闭按钮` 方案3 的阶段4实施
- 本次目标：在 settings 打开时，让页面左上角齿轮按钮真正隐藏；在 settings 关闭后恢复显示
- 根因结论：阶段1到阶段3已经完成了 container 壳层边界收口，并在 iOS / macOS 的 settings card 内加入了右上角关闭按钮，但 controller 侧的 `applySettingsPresentationState()` 仍然只做：
  - `settingsContainerView.setPresented(isSettingsPresented)`
  - `updateSettingsButtonAppearance()`
- 也就是说，页面左上角齿轮按钮只是被 settings overlay 盖住，而不是真正从页面层级和交互层级里隐藏
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 在 iOS / macOS 的 `applySettingsPresentationState()` 中新增 `settingsButton.isHidden = isSettingsPresented`。
2. 保持 controller 仍然是 settings 展示状态的唯一真相来源，不新增新的布尔状态。
3. 保持 backdrop 点击关闭、card 右上角 close button 关闭、`setSettingsPresented(false)` 这条链路完全不变。
4. 阶段4完成后，方案3的核心交互链路闭环：
   - 页面左上角齿轮负责打开；
   - 打开后页面左上角齿轮真隐藏；
   - card 右上角 close button 负责关闭；
   - 关闭后页面左上角齿轮恢复。

## 修改 1：iOS controller 在 settings 打开时真隐藏页面齿轮

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applySettingsPresentationState()
// 功能说明: 修改前 iOS controller 只同步 settingsContainerView 的显隐和齿轮按钮样式，
// 但没有真正隐藏页面左上角齿轮按钮；settings 打开后它只是被 overlay 盖住。
private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    updateSettingsButtonAppearance()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applySettingsPresentationState()
// 功能说明: 修改后 iOS controller 在展示 settings 时直接隐藏页面齿轮按钮，
// 关闭 settings 时自动恢复显示；controller 仍然是展示状态真相源。
private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    settingsButton.isHidden = isSettingsPresented
    updateSettingsButtonAppearance()
}
```

## 修改 2：macOS controller 对称隐藏 / 恢复页面齿轮

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: applySettingsPresentationState()
// 功能说明: 修改前 macOS controller 与 iOS 一样，只同步 container 可见性和入口按钮样式，
// 没有把页面左上角齿轮按钮真正从视图树可见层里隐藏。
private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    updateSettingsButtonAppearance()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: applySettingsPresentationState()
// 功能说明: 修改后 macOS controller 也在 settings 打开时直接隐藏页面齿轮按钮，
// 关闭时恢复；这样双平台的入口按钮语义完全一致。
private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    settingsButton.isHidden = isSettingsPresented
    updateSettingsButtonAppearance()
}
```

## 修改结果说明

- 阶段4没有改动 container 结构、shared settings model、settings panel content，也没有新增任何新的 controller 状态字段。
- 这一步只是在阶段1已经收口好的 `applySettingsPresentationState()` 单点里补上一行真正的显隐同步，让页面左上角齿轮按钮从“被遮住”变成“真隐藏”。
- 关闭路径保持不变：
  - backdrop 点击关闭；
  - card 右上角 close button 关闭；
  - 都仍然回到 `setSettingsPresented(false)`。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
   - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
2. 执行以下静态校验通过：
   - `swiftc -typecheck NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift NoteMaster_Ver_1/Shared/Controls/*.swift NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift`
3. 本轮还未做运行态手工联调；后续在 App 内需要继续验证的点包括：
   - settings 打开时页面齿轮是否立即消失；
   - 通过 backdrop 和 card 右上角 close button 关闭后，页面齿轮是否稳定恢复；
   - 连续多次打开/关闭是否会出现齿轮按钮状态不同步。

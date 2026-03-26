# 20260326_092907_phase1_settings_close_button_boundary_freeze

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_092907`
- 记录范围：`设置关闭按钮` 方案3 的阶段1实施
- 本次目标：先冻结“谁持有 settings 展示状态真相、谁统一发起 dismiss 请求”这两个边界，为后续把页面齿轮真隐藏、并在卡片右上角接入关闭按钮做铺垫
- 根因结论：当前代码虽然已经能打开/关闭 settings container，但展示状态应用和 dismiss 请求都还散落在多个直接调用点里：
  - controller 里直接在不同位置分别调用 `settingsContainerView.setPresented(...)` 和 `updateSettingsButtonAppearance()`；
  - container 里 backdrop 直接调用 `onDismissRequest?()`，还没有收口成“壳层 dismiss 请求”的统一入口。
- 如果不先收口这两个边界，下一阶段把右上角 close button 接进 card header 时，就会继续复制一套关闭链路，并把“入口按钮隐藏/恢复”逻辑散落在多个调用点中。
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`

## 本次完成的修改

1. 在 iOS / macOS controller 中新增 `applySettingsPresentationState()`，把 settings container 的显隐和入口按钮外观同步收口到单点。
2. 在 iOS / macOS settings container 中新增 `requestDismiss()`，把 backdrop 点击关闭改成统一走容器级 dismiss 请求入口。
3. 保持 shared settings model、settings panel content view、以及任何可见 UI 结构都不变；阶段1只做职责边界固化，不提前引入 header 或关闭按钮。
4. 结果上这一步没有任何预期的可见 UI 改动，但后续阶段只要扩展 controller 的 `applySettingsPresentationState()` 与 container 的 `requestDismiss()`，就能接入“隐藏页面齿轮”和“卡片右上角关闭按钮”。

## 修改 1：controller 侧把 settings 展示状态应用收口成单点

### iOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: configureLayout() / setSettingsPresented(_:)
// 功能说明: 修改前 iOS 控制器在初始化和运行期切换时，分别直接调用
// settingsContainerView.setPresented(...) 与 updateSettingsButtonAppearance()；
// settings 展示状态的应用还没有被收口成统一入口。
private func configureLayout() {
    // ... layout constraints ...
    updateFretboardLayoutModeConstraints()
    updateSettingsButtonAppearance()
    settingsContainerView.setPresented(false)
}

private func setSettingsPresented(_ presented: Bool) {
    guard isSettingsPresented != presented else {
        return
    }

    isSettingsPresented = presented
    settingsContainerView.setPresented(presented)
    updateSettingsButtonAppearance()
}
```

### iOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: configureLayout() / setSettingsPresented(_:) / applySettingsPresentationState()
// 功能说明: 修改后 iOS 控制器明确成为 settings 展示状态的唯一真相来源；
// 初始化和切换时都统一走 applySettingsPresentationState()，为后续“隐藏页面齿轮按钮”
// 和“同步 container 壳层可见性”提供单一扩展点。
private func configureLayout() {
    // ... layout constraints ...
    updateFretboardLayoutModeConstraints()
    applySettingsPresentationState()
}

private func setSettingsPresented(_ presented: Bool) {
    guard isSettingsPresented != presented else {
        return
    }

    isSettingsPresented = presented
    applySettingsPresentationState()
}

// 控制器仍然是 settings 展示状态的唯一真相来源；
// 后续阶段只需要扩展这里，就能统一同步页面入口按钮与 container 壳层。
private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    updateSettingsButtonAppearance()
}
```

### macOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: configureLayout() / setSettingsPresented(_:)
// 功能说明: 修改前 macOS 控制器与 iOS 一样，初始化和运行期切换时
// 都直接分散调用 settingsContainerView.setPresented(...) 与 updateSettingsButtonAppearance()，
// 没有统一的 settings 展示状态应用入口。
private func configureLayout() {
    // ... layout constraints ...
    updateFretboardLayoutModeConstraints()
    updateSettingsButtonAppearance()
    settingsContainerView.setPresented(false)
}

private func setSettingsPresented(_ presented: Bool) {
    guard isSettingsPresented != presented else {
        return
    }

    isSettingsPresented = presented
    settingsContainerView.setPresented(presented)
    updateSettingsButtonAppearance()
}
```

### macOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: configureLayout() / setSettingsPresented(_:) / applySettingsPresentationState()
// 功能说明: 修改后 macOS 控制器同样把 settings 展示状态应用收口到 applySettingsPresentationState()；
// 后续阶段只需要在这里接入“打开时隐藏页面齿轮、关闭时恢复齿轮”即可，不必追着多个调用点同步。
private func configureLayout() {
    // ... layout constraints ...
    updateFretboardLayoutModeConstraints()
    applySettingsPresentationState()
}

private func setSettingsPresented(_ presented: Bool) {
    guard isSettingsPresented != presented else {
        return
    }

    isSettingsPresented = presented
    applySettingsPresentationState()
}

// 控制器仍然持有 settings 展示状态真相；
// 后续阶段把页面入口按钮隐藏/恢复接到这里即可，不必分散到多个调用点。
private func applySettingsPresentationState() {
    settingsContainerView.setPresented(isSettingsPresented)
    updateSettingsButtonAppearance()
}
```

## 修改 2：container 侧把 dismiss 请求收口成统一入口

### iOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: handleBackdropTap()
// 功能说明: 修改前 iOS settings container 的背景点击直接调用 onDismissRequest?()；
// 如果后续在 card header 增加 close button，就会继续复制一份平级 dismiss 逻辑。
@objc
private func handleBackdropTap() {
    onDismissRequest?()
}
```

### iOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: requestDismiss() / handleBackdropTap()
// 功能说明: 修改后 iOS container 统一负责“请求关闭 settings 壳层”；
// backdrop 先走 requestDismiss()，下一阶段右上角 close button 也直接复用这条链路。
// 这样关闭行为仍然留在 container 壳层，不会污染 shared settings 内容组件。
// container 统一负责“请求关闭 settings 壳层”；
// 后续右上角 close button 直接复用这条链路，不必再新开一套 dismiss 逻辑。
private func requestDismiss() {
    onDismissRequest?()
}

@objc
private func handleBackdropTap() {
    requestDismiss()
}
```

### macOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: configureView() 中的 backdropView.onClick
// 功能说明: 修改前 macOS settings container 的背景点击闭包直接调用 onDismissRequest?()；
// 关闭行为还没有被提炼为 container 壳层的统一请求入口。
private func configureView() {
    // ... other setup ...
    backdropView.onClick = { [weak self] in
        self?.onDismissRequest?()
    }
    // ... constraints ...
}
```

### macOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: requestDismiss() / configureView() 中的 backdropView.onClick
// 功能说明: 修改后 macOS container 把 dismiss 请求统一收口到 requestDismiss()；
// 下一阶段无论是 header close button 还是背景点击，都走同一条回调链，不再复制关闭逻辑。
// container 统一收口 settings 壳层的 dismiss 请求；
// 下一阶段无论是 header close button 还是背景点击，都走同一条回调链。
private func requestDismiss() {
    onDismissRequest?()
}

private func configureView() {
    // ... other setup ...
    backdropView.onClick = { [weak self] in
        self?.requestDismiss()
    }
    // ... constraints ...
}
```

## 修改结果说明

- 阶段1不引入任何可见 UI 变化：
  - 页面左上角齿轮按钮还没有真正隐藏；
  - settings card 右上角还没有 close button；
  - settings panel / container 的布局结构也还没有变化。
- 这一步只是在平台层提前固定好两个后续会被复用的扩展点：
  1. `applySettingsPresentationState()`：后续用于同步“container 可见性 + 页面入口按钮隐藏/恢复 + 入口按钮样式”。
  2. `requestDismiss()`：后续用于统一承接 backdrop 点击与 card header close button 的关闭请求。
- 这样做的直接收益是：
  - controller 仍然是唯一展示状态真相源；
  - container 仍然是 settings 壳层关闭请求的唯一发起者；
  - shared settings 内容层完全不需要知道“关闭面板”这件事。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
   - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
   - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
   - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
2. `swiftc -typecheck` 通过，校验范围包含：
   - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
   - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
   - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
   - `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
   - `NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift`
   - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
   - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
   - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
   - `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
   - `NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift`
   - `NoteMaster_Ver_1/Shared/Controls/*.swift`
   - `NoteMaster_Ver_1/Shared/Fretboard/*.swift`
   - `NoteMaster_Ver_1/Shared/Staff/*.swift`
3. 本轮未做运行态 UI 联调，因为阶段1本身不引入可见交互变化；真正需要手工验证的将是后续 header / close button 落地后的阶段2及以后。

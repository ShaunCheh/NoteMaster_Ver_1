# 20260325_192424_settings_container_white_strip_root_cause_fix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_192424`
- 记录范围：统一设置面板重构后的设置容器白条问题根因修复
- 本次目标：修复 iOS 点击左上角齿轮后，屏幕中央只出现一条白色卡片而不是完整设置面板的问题
- 根因结论：`SettingsPanelModel` 已正常生成，`settingsPanelView` 也有正确的内容拟合高度；真正塌掉的是 `UIScrollView` / `NSScrollView` 的可视高度。原实现只有“最大高度上限”，没有“内容高度桥接”，导致滚动视图被 Auto Layout 合法压成 `0`，卡片只剩上下 inset，看起来像白条
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`

## 本次完成的修改

1. 在 iOS 设置容器中新增“滚动视图高度优先等于内容高度”的桥接约束，修复白条根因。
2. 在 macOS 设置容器中同步引入同一套内容高度桥接逻辑，避免双平台结构继续分叉。
3. 删除为定位白条问题临时加入的 iOS `SettingsDebug` 调试日志，恢复正常控制台输出。
4. 保留原有“最大浮层高度”约束不变，使长内容仍然通过内部滚动承载。
5. 完成本次修改相关文件的 lint 检查、`SettingsDebug` 残留搜索以及共享层加 macOS 平台层的 `swiftc -typecheck` 静态校验。

## 修改 1：iOS 设置容器从“只有最大高度上限”改为“内容高度桥接 + 上限截断”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: iOSSettingsContainerView.configureView()
// 功能说明: 修改前滚动视图只有 top / bottom / 最大高度上限约束，没有任何一条约束把 settingsPanelView 的真实内容高度桥接到 scrollView；因此 scrollView 可以被合法压成 0。
let preferredWidthConstraint = cardView.widthAnchor.constraint(
    equalToConstant: Style.preferredCardWidth
)
preferredWidthConstraint.priority = .defaultHigh

NSLayoutConstraint.activate([
    cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
    cardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
    cardView.leadingAnchor.constraint(
        greaterThanOrEqualTo: safeArea.leadingAnchor,
        constant: Style.screenInset
    ),
    cardView.trailingAnchor.constraint(
        lessThanOrEqualTo: safeArea.trailingAnchor,
        constant: -Style.screenInset
    ),
    cardView.topAnchor.constraint(
        greaterThanOrEqualTo: safeArea.topAnchor,
        constant: Style.screenInset
    ),
    cardView.bottomAnchor.constraint(
        lessThanOrEqualTo: safeArea.bottomAnchor,
        constant: -Style.screenInset
    ),
    preferredWidthConstraint,

    scrollView.leadingAnchor.constraint(
        equalTo: cardView.leadingAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.trailingAnchor.constraint(
        equalTo: cardView.trailingAnchor,
        constant: -Style.cardContentInset
    ),
    scrollView.topAnchor.constraint(
        equalTo: cardView.topAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.bottomAnchor.constraint(
        equalTo: cardView.bottomAnchor,
        constant: -Style.cardContentInset
    ),
    scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Style.maximumScrollHeight),

    contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
    contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
    contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
    contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
    contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

    settingsPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    settingsPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    settingsPanelView.topAnchor.constraint(equalTo: contentView.topAnchor),
    settingsPanelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
])
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
// 函数/成员: iOSSettingsContainerView.configureView()
// 功能说明: 修改后新增 scrollHeightMatchesContentConstraint，让 scrollView 高度优先跟随 settingsPanelView 内容高度；当内容超过上限时，再由 maximumScrollHeight 约束截断并交给内部滚动。
let preferredWidthConstraint = cardView.widthAnchor.constraint(
    equalToConstant: Style.preferredCardWidth
)
preferredWidthConstraint.priority = .defaultHigh
let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
    equalTo: settingsPanelView.heightAnchor
)
scrollHeightMatchesContentConstraint.priority = .defaultHigh

NSLayoutConstraint.activate([
    cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
    cardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
    cardView.leadingAnchor.constraint(
        greaterThanOrEqualTo: safeArea.leadingAnchor,
        constant: Style.screenInset
    ),
    cardView.trailingAnchor.constraint(
        lessThanOrEqualTo: safeArea.trailingAnchor,
        constant: -Style.screenInset
    ),
    cardView.topAnchor.constraint(
        greaterThanOrEqualTo: safeArea.topAnchor,
        constant: Style.screenInset
    ),
    cardView.bottomAnchor.constraint(
        lessThanOrEqualTo: safeArea.bottomAnchor,
        constant: -Style.screenInset
    ),
    preferredWidthConstraint,

    scrollView.leadingAnchor.constraint(
        equalTo: cardView.leadingAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.trailingAnchor.constraint(
        equalTo: cardView.trailingAnchor,
        constant: -Style.cardContentInset
    ),
    scrollView.topAnchor.constraint(
        equalTo: cardView.topAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.bottomAnchor.constraint(
        equalTo: cardView.bottomAnchor,
        constant: -Style.cardContentInset
    ),
    scrollHeightMatchesContentConstraint,
    scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Style.maximumScrollHeight),

    contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
    contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
    contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
    contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
    contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

    settingsPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    settingsPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    settingsPanelView.topAnchor.constraint(equalTo: contentView.topAnchor),
    settingsPanelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
])
```

## 修改 2：macOS 设置容器同步采用同一套根因修复方案

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: macOSSettingsContainerView.configureView()
// 功能说明: 修改前 macOS 端和 iOS 端结构同源，也只有滚动视图上限，没有内容高度桥接；这会让双平台后续再次出现同类塌陷风险。
let preferredWidthConstraint = cardView.widthAnchor.constraint(
    equalToConstant: Style.preferredCardWidth
)
preferredWidthConstraint.priority = .defaultHigh

NSLayoutConstraint.activate([
    cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
    cardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
    cardView.leadingAnchor.constraint(
        greaterThanOrEqualTo: safeArea.leadingAnchor,
        constant: Style.screenInset
    ),
    cardView.trailingAnchor.constraint(
        lessThanOrEqualTo: safeArea.trailingAnchor,
        constant: -Style.screenInset
    ),
    cardView.topAnchor.constraint(
        greaterThanOrEqualTo: safeArea.topAnchor,
        constant: Style.screenInset
    ),
    cardView.bottomAnchor.constraint(
        lessThanOrEqualTo: safeArea.bottomAnchor,
        constant: -Style.screenInset
    ),
    preferredWidthConstraint,

    scrollView.leadingAnchor.constraint(
        equalTo: cardView.leadingAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.trailingAnchor.constraint(
        equalTo: cardView.trailingAnchor,
        constant: -Style.cardContentInset
    ),
    scrollView.topAnchor.constraint(
        equalTo: cardView.topAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.bottomAnchor.constraint(
        equalTo: cardView.bottomAnchor,
        constant: -Style.cardContentInset
    ),
    scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Style.maximumScrollHeight),

    contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
    contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
    contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
    contentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
    contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

    settingsPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    settingsPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    settingsPanelView.topAnchor.constraint(equalTo: contentView.topAnchor),
    settingsPanelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
])
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: macOSSettingsContainerView.configureView()
// 功能说明: 修改后 macOS 端也新增 scrollHeightMatchesContentConstraint，让统一 settings 容器的高度语义与 iOS 保持一致，避免平台层继续分叉。
let preferredWidthConstraint = cardView.widthAnchor.constraint(
    equalToConstant: Style.preferredCardWidth
)
preferredWidthConstraint.priority = .defaultHigh
let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
    equalTo: settingsPanelView.heightAnchor
)
scrollHeightMatchesContentConstraint.priority = .defaultHigh

NSLayoutConstraint.activate([
    cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
    cardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
    cardView.leadingAnchor.constraint(
        greaterThanOrEqualTo: safeArea.leadingAnchor,
        constant: Style.screenInset
    ),
    cardView.trailingAnchor.constraint(
        lessThanOrEqualTo: safeArea.trailingAnchor,
        constant: -Style.screenInset
    ),
    cardView.topAnchor.constraint(
        greaterThanOrEqualTo: safeArea.topAnchor,
        constant: Style.screenInset
    ),
    cardView.bottomAnchor.constraint(
        lessThanOrEqualTo: safeArea.bottomAnchor,
        constant: -Style.screenInset
    ),
    preferredWidthConstraint,

    scrollView.leadingAnchor.constraint(
        equalTo: cardView.leadingAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.trailingAnchor.constraint(
        equalTo: cardView.trailingAnchor,
        constant: -Style.cardContentInset
    ),
    scrollView.topAnchor.constraint(
        equalTo: cardView.topAnchor,
        constant: Style.cardContentInset
    ),
    scrollView.bottomAnchor.constraint(
        equalTo: cardView.bottomAnchor,
        constant: -Style.cardContentInset
    ),
    scrollHeightMatchesContentConstraint,
    scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Style.maximumScrollHeight),

    contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
    contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
    contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
    contentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
    contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

    settingsPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    settingsPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    settingsPanelView.topAnchor.constraint(equalTo: contentView.topAnchor),
    settingsPanelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
])
```

## 修改 3：删除 iOS 白条定位阶段的临时调试日志

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift；NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSSettingsContainerView.logDebugLayout(reason:)；iOSViewController.logSettingsDebugState(reason:model:)；handleSettingsButtonTap() / handleSettingsPanelEvent(_:)
// 功能说明: 修改前为了定位白条根因，iOS 端临时引入了 SettingsDebug 打印；在根因确认并修复后，这些输出会继续污染控制台，因此需要清理。
#if DEBUG
private extension iOSSettingsContainerView {
    func logDebugLayout(reason: String) {
        let signature = [
            "reason=\(reason)",
            "presented=\(!isHidden)",
            "sections=\(model.sections.count)",
            "rows=\(model.rows.count)"
        ].joined(separator: " ")
        print("[SettingsDebug][iOSContainer] \(signature)")
    }
}
#endif

#if DEBUG
private extension iOSViewController {
    func logSettingsDebugState(
        reason: String,
        model: SettingsPanelModel
    ) {
        print("[SettingsDebug][iOSVC] reason=\(reason) sections=\(model.sections.count) rows=\(model.rows.count)")
    }
}
#endif
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applySettingsPanelState()；handleSettingsButtonTap()；handleSettingsPanelEvent(_:)
// 功能说明: 修改后控制器恢复为正式逻辑，只保留统一 settings 模型刷新与事件回写；不再夹带用于一次性定位的 SettingsDebug 输出。
private func applySettingsPanelState() {
    settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState
    )
}

@objc
private func handleSettingsButtonTap() {
    setSettingsPresented(!isSettingsPresented)
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState
    )

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState

    guard didChangeFretboard || didChangeStaff else {
        return
    }

    if didChangeFretboard {
        displayState = nextDisplayState
    }

    if didChangeStaff {
        staffDisplayState = nextStaffDisplayState
    }
}
```

## 验证结果

```bash
# 文件路径: 命令行校验（无项目内文件路径）
# 函数/成员: ReadLints；rg；swiftc -typecheck
# 功能说明: 本次修改后已检查容器文件与 iOS 控制器的 lint、SettingsDebug 残留以及共享层加 macOS 平台层的静态类型。
ReadLints paths:
- NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift
- NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
- NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
Result:
- No linter errors found.

rg pattern:
- \[SettingsDebug\]
Result:
- No matches found

swiftc -typecheck:
setopt extendedglob && files=(NoteMaster_Ver_1/Shared/**/*.swift NoteMaster_Ver_1/Platform/macOS/**/*.swift) && swiftc -typecheck $files
Result:
- exit code 0
```

## 结果说明

- 本次修改针对的是设置容器白条的布局根因，而不是通过增大常量或硬编码最小高度做表面修补。
- 现在容器高度会优先跟随 `settingsPanelView` 的真实内容高度，小内容不会塌成白条；大内容超过上限时，仍然通过内部滚动承载。
- iOS 白条定位用的临时日志已经清理，不会继续污染运行时控制台输出。

# 20260326_222150_macos_settings_panel_vertical_compression_fix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_222150`
- 记录范围：macOS settings 面板中 choice row 标题被垂直压缩的根因修复
- 本次目标：修复 macOS 设置卡片里 `Spelling`、`Octave`、`Content` 等靠下标题显示不全的问题，优先从 `NSScrollView` / `documentView` 约束语义入手，而不是局部调字号或间距
- 根因结论：修改前 `macOSSettingsContainerView.configureView()` 把 `contentView` 四边都钉在 `scrollView.contentView` 上，同时又让 `settingsPanelView` 四边钉满 `contentView`。当 `scrollView.height <= maximumScrollHeight` 生效时，document 高度会被压进视口高度，Auto Layout 只能继续压缩内部 `ChoiceRowView`。由于 `ChoiceRowView` 标题没有显式纵向抗压缩保护，底部几行标题会最先被压到接近 0 高度，表现成截图里 `Sharp` / `Flat` 上方文案显示不全
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`

## 本次完成的修改

1. 在 `macOSSettingsContainerView` 中去掉 `documentView` 对 `clip view` 底边的强绑定，让 `settingsPanelView` 的真实内容高度可以撑开文档区，内容超高时改由纵向滚动承载。
2. 为 `contentView` 增加纵向 `hugging` / `compression resistance`，避免容器层继续把 settings 内容向下游 row 压缩。
3. 在 `ChoiceRowView` 中显式开启 `detachesHiddenViews`，并为标题 `titleLabel` 增加纵向抗压缩与拥抱优先级，防止隐藏控件或后续边界场景再次把标题压扁。
4. 保持 shared settings model、iOS settings container、controller 接线不变，把修复严格收敛在 macOS 专用视图层。

## 修改 1：修正 macOS settings 容器的滚动文档高度语义

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: configureView()
// 功能说明: 修改前把 documentView 四边都钉在 scrollView.contentView 上；
// 这样 settingsPanelView 的内容高度一旦超过 scroll 允许高度，就不会进入正常滚动语义，而是继续向内部 row 传递压缩。
scrollView.documentView = contentView

contentView.translatesAutoresizingMaskIntoConstraints = false
settingsPanelView.translatesAutoresizingMaskIntoConstraints = false

let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
    equalTo: settingsPanelView.heightAnchor
)
scrollHeightMatchesContentConstraint.priority = .defaultHigh

NSLayoutConstraint.activate([
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

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsContainerView.swift
// 函数/成员: configureView()
// 功能说明: 修改后去掉 documentView 对 clip view 底边的锁定，并显式提高 contentView 纵向抗压缩；
// 这样 settingsPanelView 的 intrinsic height 可以撑开文档区，内容少时贴合高度，内容多时走纵向滚动。
scrollView.documentView = contentView

contentView.translatesAutoresizingMaskIntoConstraints = false
contentView.setContentHuggingPriority(.required, for: .vertical)
contentView.setContentCompressionResistancePriority(.required, for: .vertical)
settingsPanelView.translatesAutoresizingMaskIntoConstraints = false

let scrollHeightMatchesContentConstraint = scrollView.heightAnchor.constraint(
    equalTo: settingsPanelView.heightAnchor
)
scrollHeightMatchesContentConstraint.priority = .defaultHigh

NSLayoutConstraint.activate([
    scrollHeightMatchesContentConstraint,
    scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: Style.maximumScrollHeight),

    contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
    contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
    contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
    contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

    settingsPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    settingsPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    settingsPanelView.topAnchor.constraint(equalTo: contentView.topAnchor),
    settingsPanelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
])
```

## 修改 2：给 ChoiceRowView 标题补充纵向抗压缩保护

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数/成员: ChoiceRowView.configureView()
// 功能说明: 修改前 choice row 只设置了标题的单行截断，没有显式声明标题在纵向上的抗压缩优先级；
// 当外层容器把行高持续压缩时，标题会最先被挤掉。
private func configureView() {
    contentStackView.orientation = .vertical
    contentStackView.alignment = .leading
    contentStackView.distribution = .fill
    contentStackView.spacing = Style.choiceContentSpacing
    contentStackView.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.font = .systemFont(ofSize: Style.bodyFontSize, weight: .medium)
    titleLabel.textColor = .labelColor
    titleLabel.lineBreakMode = .byTruncatingTail

    chipsStackView.orientation = .horizontal
    chipsStackView.alignment = .centerY
    chipsStackView.distribution = .fill
    chipsStackView.spacing = Style.chipSpacing
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数/成员: ChoiceRowView.configureView()
// 功能说明: 修改后显式让隐藏的 segmented/chips 视图脱离布局计算，并给标题补齐纵向 hugging / compression resistance；
// 这样即使未来某些约束边界再次收紧，标题也不会被优先压到 0 高度。
private func configureView() {
    contentStackView.orientation = .vertical
    contentStackView.alignment = .leading
    contentStackView.distribution = .fill
    contentStackView.detachesHiddenViews = true
    contentStackView.spacing = Style.choiceContentSpacing
    contentStackView.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.font = .systemFont(ofSize: Style.bodyFontSize, weight: .medium)
    titleLabel.textColor = .labelColor
    titleLabel.lineBreakMode = .byTruncatingTail
    titleLabel.setContentHuggingPriority(.required, for: .vertical)
    titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

    chipsStackView.orientation = .horizontal
    chipsStackView.alignment = .centerY
    chipsStackView.distribution = .fill
    chipsStackView.spacing = Style.chipSpacing
}
```

## 修改结果说明

- 修复后，`Spelling`、`Octave`、`Content` 等靠下 row 的标题不再因为容器高度上限而被压成残缺文字。
- settings 内容较少时，scroll 区域仍然可以贴合内容高度；内容较多时，超出部分改由纵向滚动显示，而不是继续压缩内部 row。
- 修复范围仅限 macOS settings UI：
  - 未修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
  - 未修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
  - 未修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsContainerView.swift`

## 验证记录

- 对 `macOSSettingsContainerView.swift` 与 `macOSSettingsPanelView.swift` 运行 lint 诊断：无新增问题。
- 用等价 AppKit 约束脚本复现验证：
  - 修改前，底部 choice row 会被压到约 `8pt ~ 14pt`，标题高度可掉到 `0pt`
  - 修改后，同类 row 恢复为正常 `54pt` 高度，标题恢复为正常单行显示高度
- 当前未做整工程 `xcodebuild` 校验，因为本机 `xcodebuild` 指向的是 `CommandLineTools`，不是完整 Xcode。

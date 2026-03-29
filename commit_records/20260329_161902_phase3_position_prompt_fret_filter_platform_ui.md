# 20260329_161902_phase3_position_prompt_fret_filter_platform_ui

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_161902`
- 记录范围：实施“Position 品位筛选”计划的阶段 3，只完成 iOS / macOS unified settings panel 的 12 格品位筛选 UI、选中态回显、禁用态呈现以及 `togglePositionPromptFret` 事件透传
- 本次目标：把阶段 2 的隐藏占位 `fretFilter` 行替换为真正可见、可点击、可回显的单行 12 格控件
- 本次不包含：
- shared trainer 的 allowed frets 出题过滤
- 控制器层基于筛选变化的 session 重建
- validation 用例扩展
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- `.cursor/plans/position品位筛选_cb2e8023.plan.md`

## 本次结论

- 阶段 3 完成后，`positionPrompt` 模式下的 `Trainer` 分区已经能真实显示一行 `1...12` 的品位按钮，而不再是阶段 2 的隐藏占位 view
- 双端按钮都会根据 shared snapshot 正确回显 `isSelected` / `isEnabled`，因此“最后一个已选品位不可取消”已经能在 UI 上以禁用但仍高亮的状态表达出来
- 双端按钮点击都会统一发出 `SettingsPanelEvent.togglePositionPromptFret(fret)`，后续阶段 4 和阶段 5 可以继续复用阶段 1 / 阶段 2 已建立的 shared 状态链路

## 修改 1：iOS 端把占位 `fretFilter` 行替换成真正的 12 格筛选控件

### 修改前

- `controlView(for:)` 的 `.fretFilter` 分支仍然挂的是 `FretFilterPlaceholderRowView`
- 占位 view 只有 `accessibilityIdentifier`
- view 会被直接隐藏，不参与交互
- 结果是 shared 层虽然已经能构建 `SettingsFretFilterRow`，但 iOS 界面上仍然看不到真正的 12 格品位按钮

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterPlaceholderRowView.apply(item:)
// 功能说明: 修改前 iOS 端只用一个隐藏占位 view 承接 .fretFilter；
// shared 快照已经有 1...12 数据，但平台层还没有把它渲染成实际控件。
private func controlView(for row: SettingsRow) -> UIView {
    switch row {
    case let .choice(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ChoiceRowView {
            existingRow.apply(item: item)
            return existingRow
        }
        // ...
    case let .fretFilter(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? FretFilterPlaceholderRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = FretFilterPlaceholderRowView()
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    case let .slider(item):
        // ...
    case let .toggle(item):
        // ...
    }
}

private final class FretFilterPlaceholderRowView: UIView {
    override var intrinsicContentSize: CGSize {
        .zero
    }

    func apply(item: SettingsFretFilterRow) {
        accessibilityIdentifier = "settings-panel-fret-filter-row-\(String(describing: item.id))"
        isUserInteractionEnabled = false
        isHidden = true
    }
}
```

### 修改后

- `.fretFilter` 分支现在挂 `FretFilterRowView`
- `FretFilterRowView` 使用标题 + 横向等宽 `UIStackView` 渲染 12 个格子
- 行内会缓存 `buttonsByFret`，支持重复 `apply(item:)` 时按 fret 复用按钮
- 每个按钮点击后统一透传到 `onEvent?(.togglePositionPromptFret(fret))`
- 这样阶段 2 的 `SettingsFretFilterRow` 已经真正落地成 iOS 可见 UI

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterRowView, handleFretButtonTap(_:)
// 功能说明: 修改后 iOS 端会把 shared 的 fret-filter row 渲染成真实 12 格按钮；
// 点击任意可用格子都会转成 togglePositionPromptFret(fret) 事件，继续沿用 shared 状态链路。
private func controlView(for row: SettingsRow) -> UIView {
    switch row {
    case let .choice(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ChoiceRowView {
            existingRow.apply(item: item)
            return existingRow
        }
        // ...
    case let .fretFilter(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? FretFilterRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = FretFilterRowView()
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    case let .slider(item):
        // ...
    case let .toggle(item):
        // ...
    }
}

private final class FretFilterRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var buttonsByFret: [Int: FretFilterButton] = [:]

    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let fretsStackView = UIStackView()

    func apply(item: SettingsFretFilterRow) {
        accessibilityIdentifier = "settings-panel-fret-filter-row-\(String(describing: item.id))"
        accessibilityLabel = item.accessibilityLabel
        titleLabel.text = item.title
        removeObsoleteButtons(notIn: Set(item.frets.map(\.fret)))

        let orderedButtons = item.frets.map { fret -> UIView in
            fretButton(for: fret)
        }

        replaceArrangedSubviews(
            in: fretsStackView,
            with: orderedButtons
        )
        isUserInteractionEnabled = item.frets.contains(where: { $0.isEnabled })
    }

    @objc
    private func handleFretButtonTap(_ sender: FretFilterButton) {
        guard
            let fret = sender.fret,
            sender.isEnabled
        else {
            return
        }

        onEvent?(.togglePositionPromptFret(fret))
    }
}
```

## 修改 2：iOS 端新增专用 `FretFilterButton` 样式，让选中态、未选中态、禁用态都能直观看出来

### 修改前

- 阶段 2 的 iOS 平台层没有真正的 fret button
- 因此也不存在：
- 12 个格子的文本显示
- 选中态高亮
- 最后一个已选品位的“禁用但保持高亮”外观

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: 无
// 功能说明: 修改前 iOS 端没有专用 FretFilterButton；
// 平台层还没有把 SettingsFretFilterItem 的 isSelected / isEnabled 投影成具体按钮外观。
private final class FretFilterPlaceholderRowView: UIView {
    override var intrinsicContentSize: CGSize {
        .zero
    }

    func apply(item: SettingsFretFilterRow) {
        accessibilityIdentifier = "settings-panel-fret-filter-row-\(String(describing: item.id))"
        isUserInteractionEnabled = false
        isHidden = true
    }
}
```

### 修改后

- 新增 `FretFilterButton`
- 文本使用等宽数字字体，保证 `1...12` 视觉更整齐
- `updateConfiguration()` 里根据 `isSelected / isEnabled / isHighlighted` 组合出背景色和前景色
- 被禁用但仍选中的格子会继续保持蓝色系高亮，而不是退回普通灰色，方便用户看出“这是当前最后一个已选品位”
- 行级 style 常量新增了 `fretFilterContentSpacing`、`fretFilterSpacing`、`fretFilterButtonFontSize`、`fretFilterButtonContentInsets`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: FretFilterButton.apply(item:), updateConfiguration(), resolvedBackgroundColor(), resolvedForegroundColor()
// 功能说明: 修改后 iOS 端每个 fret 都有专用按钮样式；
// shared 快照里的 selected / enabled 状态会被直接转成可见外观，尤其覆盖“最后一个已选不可取消”的禁用高亮态。
private final class FretFilterButton: UIButton {
    var fret: Int?

    func apply(item: SettingsFretFilterItem) {
        fret = item.fret
        isSelected = item.isSelected
        isEnabled = item.isEnabled
        accessibilityLabel = item.accessibilityLabel
        accessibilityIdentifier = "settings-panel-fret-\(item.fret)"
        setTitle(item.title, for: .normal)
        setNeedsUpdateConfiguration()
    }

    override func updateConfiguration() {
        super.updateConfiguration()

        guard fret != nil else {
            return
        }

        var nextConfiguration = configuration ?? UIButton.Configuration.filled()
        var attributedTitle = AttributedString(title(for: .normal) ?? "")
        attributedTitle.font = UIFont.monospacedDigitSystemFont(
            ofSize: Style.fretFilterButtonFontSize,
            weight: .semibold
        )
        nextConfiguration.attributedTitle = attributedTitle
        nextConfiguration.buttonSize = .small
        nextConfiguration.cornerStyle = .medium
        nextConfiguration.contentInsets = Style.fretFilterButtonContentInsets
        nextConfiguration.baseBackgroundColor = resolvedBackgroundColor()
        nextConfiguration.baseForegroundColor = resolvedForegroundColor()
        configuration = nextConfiguration
    }

    private func resolvedBackgroundColor() -> UIColor {
        if isSelected {
            if !isEnabled {
                return .systemBlue.withAlphaComponent(0.38)
            }

            return isHighlighted ? .systemBlue.withAlphaComponent(0.78) : .systemBlue
        }

        if !isEnabled {
            return .quaternarySystemFill
        }

        return isHighlighted ? .tertiarySystemFill : .secondarySystemFill
    }

    private func resolvedForegroundColor() -> UIColor {
        if isSelected {
            return .white.withAlphaComponent(isEnabled ? 1 : 0.84)
        }

        if !isEnabled {
            return .tertiaryLabel
        }

        return .label
    }
}

private enum Style {
    static let fretFilterContentSpacing: CGFloat = 8
    static let fretFilterSpacing: CGFloat = 4
    static let fretFilterButtonFontSize: CGFloat = 12
    static let fretFilterButtonContentInsets = NSDirectionalEdgeInsets(
        top: 6,
        leading: 0,
        bottom: 6,
        trailing: 0
    )
}
```

## 修改 3：macOS 端把占位 `fretFilter` 行替换成真正的 12 格筛选控件

### 修改前

- macOS 和 iOS 一样，`.fretFilter` 分支仍然使用 `FretFilterPlaceholderRowView`
- 阶段 2 只是保证 shared 模型扩容后 AppKit 分支不会漏掉 switch 穷举
- 但真正的 12 格按钮仍然没有落地

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterPlaceholderRowView.apply(item:)
// 功能说明: 修改前 macOS 端也只挂了一个隐藏占位 row；
// 平台层还没有把 shared 的 fret-filter 数据渲染为可交互的 12 格按钮。
private func controlView(for row: SettingsRow) -> NSView {
    switch row {
    case let .choice(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ChoiceRowView {
            existingRow.apply(item: item)
            return existingRow
        }
        // ...
    case let .fretFilter(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? FretFilterPlaceholderRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = FretFilterPlaceholderRowView(frame: .zero)
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    case let .slider(item):
        // ...
    case let .toggle(item):
        // ...
    }
}

private final class FretFilterPlaceholderRowView: NSView {
    override var intrinsicContentSize: NSSize {
        .zero
    }

    func apply(item: SettingsFretFilterRow) {
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-fret-filter-row-\(String(describing: item.id))"
        )
        isHidden = true
    }
}
```

### 修改后

- macOS 的 `.fretFilter` 分支改成 `FretFilterRowView`
- `FretFilterRowView` 使用纵向 `contentStackView` 承载标题与一行横向等宽按钮
- 每个按钮用 `target/action` 统一发出 `togglePositionPromptFret(fret)`
- 与 iOS 一样，行内会按 fret 复用按钮实例，保证多次 `apply(item:)` 时只更新状态、不重复创建控件

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: controlView(for:), FretFilterRowView, handleFretButtonTap(_:)
// 功能说明: 修改后 macOS 端也把 shared 的 fret-filter row 渲染成真实 12 格控件；
// AppKit 按钮点击统一进入 togglePositionPromptFret(fret) 事件链路。
private func controlView(for row: SettingsRow) -> NSView {
    switch row {
    case let .choice(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? ChoiceRowView {
            existingRow.apply(item: item)
            return existingRow
        }
        // ...
    case let .fretFilter(item):
        let rowID = row.id
        if let existingRow = controlViewsByID[rowID] as? FretFilterRowView {
            existingRow.apply(item: item)
            return existingRow
        }

        detachControlViewIfNeeded(for: rowID)

        let rowView = FretFilterRowView(frame: .zero)
        rowView.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        rowView.apply(item: item)
        controlViewsByID[rowID] = rowView
        return rowView
    case let .slider(item):
        // ...
    case let .toggle(item):
        // ...
    }
}

private final class FretFilterRowView: NSView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var buttonsByFret: [Int: FretFilterButton] = [:]

    private let contentStackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let fretsStackView = NSStackView()

    func apply(item: SettingsFretFilterRow) {
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-fret-filter-row-\(String(describing: item.id))"
        )
        toolTip = item.accessibilityLabel
        titleLabel.stringValue = item.title
        removeObsoleteButtons(notIn: Set(item.frets.map(\.fret)))

        let orderedButtons = item.frets.map { fret -> NSView in
            fretButton(for: fret)
        }

        replaceArrangedSubviews(
            in: fretsStackView,
            with: orderedButtons
        )
    }

    @objc
    private func handleFretButtonTap(_ sender: FretFilterButton) {
        guard
            let fret = sender.fret,
            sender.isEnabled
        else {
            return
        }

        onEvent?(.togglePositionPromptFret(fret))
    }
}
```

## 修改 4：macOS 端新增专用 `FretFilterButton` 样式，让 AppKit 版本也具备清晰的选中/禁用反馈

### 修改前

- 阶段 2 的 macOS 平台层没有真实的 fret button
- 因此也没有：
- 等宽数字标题
- 自定义圆角按钮外观
- “已选但因最后一个已选品位而不可取消”的禁用高亮态

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: 无
// 功能说明: 修改前 macOS 端没有 FretFilterButton；
// 平台层不能把 shared 的 SettingsFretFilterItem 状态投影成实际按钮外观。
private final class FretFilterPlaceholderRowView: NSView {
    override var intrinsicContentSize: NSSize {
        .zero
    }

    func apply(item: SettingsFretFilterRow) {
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-fret-filter-row-\(String(describing: item.id))"
        )
        isHidden = true
    }
}
```

### 修改后

- 新增 macOS 版 `FretFilterButton`
- `intrinsicContentSize` 保证了最小宽高，避免 `1` 和 `12` 宽度差异太大时造成视觉不稳定
- `applyCurrentAppearance()` 会根据 `state / isEnabled / isPressed` 更新 layer 背景色和文字颜色
- 选中且禁用的按钮仍保留 accent 色系，只是降低透明度，以表达“这是最后一个已选品位”
- style 常量新增了最小按钮尺寸、圆角、字体大小和内容 inset

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: FretFilterButton.intrinsicContentSize, apply(item:), applyCurrentAppearance(),
// resolvedBackgroundColor(), resolvedForegroundColor()
// 功能说明: 修改后 macOS 端每个 fret 都有独立按钮外观；
// shared 快照中的选中态与禁用态会被直观映射为 AppKit 按钮样式。
private final class FretFilterButton: NSButton {
    var fret: Int?

    private var isPressed = false

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(
            width: max(
                Style.minimumFretFilterButtonWidth,
                size.width + Style.fretFilterButtonContentInsets.left + Style.fretFilterButtonContentInsets.right
            ),
            height: max(
                Style.minimumFretFilterButtonHeight,
                size.height + Style.fretFilterButtonContentInsets.top + Style.fretFilterButtonContentInsets.bottom
            )
        )
    }

    func apply(item: SettingsFretFilterItem) {
        fret = item.fret
        state = item.isSelected ? .on : .off
        isEnabled = item.isEnabled
        title = item.title
        toolTip = item.accessibilityLabel
        identifier = NSUserInterfaceItemIdentifier(
            "settings-panel-fret-\(item.fret)"
        )
        applyCurrentAppearance()
        invalidateIntrinsicContentSize()
    }

    private func applyCurrentAppearance() {
        layer?.backgroundColor = resolvedBackgroundColor().cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: Style.fretFilterButtonFontSize,
                    weight: .semibold
                ),
                .foregroundColor: resolvedForegroundColor()
            ]
        )
    }

    private func resolvedBackgroundColor() -> NSColor {
        if state == .on {
            if !isEnabled {
                return NSColor.controlAccentColor.withAlphaComponent(0.38)
            }

            return isPressed
                ? NSColor.controlAccentColor.withAlphaComponent(0.78)
                : NSColor.controlAccentColor
        }

        if !isEnabled {
            return .quaternaryLabelColor.withAlphaComponent(0.12)
        }

        return isPressed
            ? NSColor.quaternaryLabelColor.withAlphaComponent(0.18)
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.1)
    }

    private func resolvedForegroundColor() -> NSColor {
        if state == .on {
            return .white.withAlphaComponent(isEnabled ? 1 : 0.84)
        }

        if !isEnabled {
            return .disabledControlTextColor
        }

        return .labelColor
    }
}

private enum Style {
    static let minimumFretFilterButtonWidth: CGFloat = 24
    static let minimumFretFilterButtonHeight: CGFloat = 28
    static let fretFilterContentSpacing: CGFloat = 8
    static let fretFilterSpacing: CGFloat = 4
    static let fretFilterButtonCornerRadius: CGFloat = 8
    static let fretFilterButtonFontSize: CGFloat = 12
    static let fretFilterButtonContentInsets = NSEdgeInsets(
        top: 5,
        left: 0,
        bottom: 5,
        right: 0
    )
}
```

## 修改 5：同步计划状态，标记阶段 3 完成

### 修改前

- `phase3-platform-settings-ui` 还处于进行中
- 计划文件尚未体现“双端 12 格 UI 已经接通”的当前状态

```md
<!-- 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md -->
<!-- 函数名/符号: todo item phase3-platform-settings-ui -->
<!-- 功能说明: 修改前计划文件仍把阶段 3 标记为进行中。 -->
- id: phase3-platform-settings-ui
  content: 在 iOS/macOS SettingsPanelView 新增 12 格单行品位筛选控件，并接通事件与回显
  status: in_progress
```

### 修改后

- `phase3-platform-settings-ui` 已标记为 `completed`
- 计划文件与当前代码状态保持一致，下一步可以进入阶段 4 的 shared trainer 出题过滤

```md
<!-- 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md -->
<!-- 函数名/符号: todo item phase3-platform-settings-ui -->
<!-- 功能说明: 修改后计划文件已确认阶段 3 完成，下一步可进入 allowed frets 的 shared trainer 过滤。 -->
- id: phase3-platform-settings-ui
  content: 在 iOS/macOS SettingsPanelView 新增 12 格单行品位筛选控件，并接通事件与回显
  status: completed
```

## 验证情况

- 已对 `iOSSettingsPanelView.swift` 与 `macOSSettingsPanelView.swift` 运行静态诊断，`ReadLints` 未发现新增问题
- 本阶段没有运行 `xcodebuild`，也没有做双端手工点击回归
- 当前阶段边界符合计划：
- shared settings model 没有新增结构变化
- 双端平台 UI 已经从隐藏占位升级为真实 12 格筛选控件
- shared trainer 出题仍未根据 `selectedFrets` 过滤，这部分保留到阶段 4

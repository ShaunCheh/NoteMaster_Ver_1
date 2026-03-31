# 20260331_111645_phase4_position_filter_view_unification

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_111645`
- 记录范围：实施“Position 过滤模式重构”计划的阶段 4，只完成 iOS / macOS settings 表现层的通用化收口；不包含 shared trainer 候选池改造，不包含 controller 的 session 重建逻辑，不包含 validation 扩展
- 本次目标：把双端 settings 行控件从残留的 `Fret...` 专用命名收口为真正的 `PositionFilter...` 通用控件，同时保持现有 row diff / 缓存机制、视觉风格和交互事件不变
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`

## 本次结论

- 双端 `positionFilter` row 的承载控件已经从 `FretFilterRowView` / `FretFilterButton` 收口成 `PositionFilterRowView` / `PositionFilterButton`
- row 工厂仍然沿用 `controlViewsByID` 的复用逻辑，没有破坏 settings panel 的局部刷新机制
- 内部容器命名已从 `fretsStackView` 抽象为 `optionsStackView`，按钮构造与点击处理也同步改成通用 `option` 语义
- iOS / macOS 两端的样式常量都从 `fretFilter...` 重命名为 `positionFilter...`
- 按钮标题字体从“仅数字等宽”切成“整串等宽”，让 `C D E F G A B` 与 `1...12` 共用同一套按钮表现

## 修改 1：双端 row 工厂继续复用缓存，但承载 view 改为通用 `PositionFilterRowView`

### 修改前

- `positionFilter` row 虽然已经是通用 row id，但工厂里仍然强转 / 创建 `FretFilterRowView`
- 这意味着表现层命名仍然停留在“品位过滤”的历史语义上

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: iOSSettingsPanelView.controlView(for:)
// 功能说明: 修改前 iOS 侧虽然已经接收通用的 positionFilter row，
// 但缓存复用与新建路径仍然绑定 FretFilterRowView。
case let .positionFilter(item):
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: macOSSettingsPanelView.controlView(for:)
// 功能说明: 修改前 macOS 侧与 iOS 对称，positionFilter row 仍然复用 FretFilterRowView。
case let .positionFilter(item):
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
```

### 修改后

- 双端 row 工厂都改成 `PositionFilterRowView`
- 现有的 `rowID -> view` 复用路径保持不变，阶段 4 只收口 view 命名与承载语义

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: iOSSettingsPanelView.controlView(for:)
// 功能说明: 修改后 iOS 侧继续沿用 controlViewsByID 的缓存复用，
// 但 positionFilter row 的真实承载 view 已切换为 PositionFilterRowView。
case let .positionFilter(item):
    let rowID = row.id
    if let existingRow = controlViewsByID[rowID] as? PositionFilterRowView {
        existingRow.apply(item: item)
        return existingRow
    }

    detachControlViewIfNeeded(for: rowID)

    let rowView = PositionFilterRowView()
    rowView.onEvent = { [weak self] event in
        self?.onEvent?(event)
    }
    rowView.apply(item: item)
    controlViewsByID[rowID] = rowView
    return rowView
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: macOSSettingsPanelView.controlView(for:)
// 功能说明: 修改后 macOS 侧对称切到 PositionFilterRowView，
// 同时保留原有 row diff / 局部刷新的缓存机制。
case let .positionFilter(item):
    let rowID = row.id
    if let existingRow = controlViewsByID[rowID] as? PositionFilterRowView {
        existingRow.apply(item: item)
        return existingRow
    }

    detachControlViewIfNeeded(for: rowID)

    let rowView = PositionFilterRowView(frame: .zero)
    rowView.onEvent = { [weak self] event in
        self?.onEvent?(event)
    }
    rowView.apply(item: item)
    controlViewsByID[rowID] = rowView
    return rowView
```

## 修改 2：iOS 侧把 `FretFilter...` 行控件收口为通用 `PositionFilter...`

### 修改前

- iOS 行控件类名、按钮类名、容器命名、事件方法名都还是 `fret`
- 这种命名虽然能工作，但和当前“音名 / 品位”双模式的通用语义已经不一致

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: FretFilterRowView, FretFilterButton
// 功能说明: 修改前 iOS 侧 positionFilter 行仍使用 fret 专用命名；
// 内部容器叫 fretsStackView，按钮工厂叫 fretButton，点击事件也叫 handleFretButtonTap。
private final class FretFilterRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var buttonsByOptionID: [SettingsPositionFilterOptionID: FretFilterButton] = [:]

    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let fretsStackView = UIStackView()

    func apply(item: SettingsPositionFilterRow) {
        titleLabel.text = item.title
        let orderedButtons = item.options.map { fret -> UIView in
            fretButton(for: fret)
        }

        replaceArrangedSubviews(
            in: fretsStackView,
            with: orderedButtons
        )
    }

    private func fretButton(for item: SettingsPositionFilterItem) -> FretFilterButton {
        let button = FretFilterButton(frame: .zero)
        button.addTarget(
            self,
            action: #selector(handleFretButtonTap(_:)),
            for: .touchUpInside
        )
        return button
    }
}

private final class FretFilterButton: UIButton {
    var optionID: SettingsPositionFilterOptionID?
}
```

### 修改后

- iOS 侧统一改成 `PositionFilterRowView` / `PositionFilterButton`
- `fretsStackView` 改成 `optionsStackView`
- `fretButton(...)` / `handleFretButtonTap(...)` 改成通用 `option` 语义
- 外部事件仍然是 `togglePositionPromptFilterOption(...)`，因此没有改动 shared settings 协议面

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: PositionFilterRowView, PositionFilterButton
// 功能说明: 修改后 iOS 侧 positionFilter 行真正变成通用 option row；
// 不再把内部命名绑死在 fret 语义上，从而同时承载音名按钮和品位按钮。
private final class PositionFilterRowView: UIView {
    var onEvent: ((SettingsPanelEvent) -> Void)?

    private var buttonsByOptionID: [SettingsPositionFilterOptionID: PositionFilterButton] = [:]

    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let optionsStackView = UIStackView()

    func apply(item: SettingsPositionFilterRow) {
        titleLabel.text = item.title
        let orderedButtons = item.options.map { option -> UIView in
            optionButton(for: option)
        }

        replaceArrangedSubviews(
            in: optionsStackView,
            with: orderedButtons
        )
    }

    private func optionButton(for item: SettingsPositionFilterItem) -> PositionFilterButton {
        let button = PositionFilterButton(frame: .zero)
        button.addTarget(
            self,
            action: #selector(handleOptionButtonTap(_:)),
            for: .touchUpInside
        )
        return button
    }
}

private final class PositionFilterButton: UIButton {
    var optionID: SettingsPositionFilterOptionID?
}
```

## 修改 3：macOS 侧做对称收口，并把按钮字体切成通用等宽字体

### 修改前

- macOS 侧与 iOS 对称，残留的是 `FretFilterRowView` / `FretFilterButton`
- 按钮标题字体使用 `NSFont.monospacedDigitSystemFont(...)`
- 这个字体策略更偏向数字按钮，不适合长期承载 `C D E F G A B`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: FretFilterRowView, FretFilterButton.applyCurrentAppearance()
// 功能说明: 修改前 macOS 侧仍然是 fret 专用控件命名，
// 并且按钮标题使用 monospacedDigitSystemFont，更偏向数字场景。
private final class FretFilterRowView: NSView {
    private var buttonsByOptionID: [SettingsPositionFilterOptionID: FretFilterButton] = [:]

    private let titleLabel = NSTextField(labelWithString: "")
    private let fretsStackView = NSStackView()

    private func fretButton(for item: SettingsPositionFilterItem) -> FretFilterButton {
        let button = FretFilterButton(frame: .zero)
        button.target = self
        button.action = #selector(handleFretButtonTap(_:))
        return button
    }
}

private final class FretFilterButton: NSButton {
    private func applyCurrentAppearance() {
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: Style.fretFilterButtonFontSize,
                    weight: .semibold
                )
            ]
        )
    }
}
```

### 修改后

- macOS 侧统一为 `PositionFilterRowView` / `PositionFilterButton`
- 内部也改成 `optionsStackView` / `optionButton(...)` / `handleOptionButtonTap(...)`
- 按钮字体改成 `NSFont.monospacedSystemFont(...)`，让字母和数字都走同一套等宽表现

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: PositionFilterRowView, PositionFilterButton.applyCurrentAppearance()
// 功能说明: 修改后 macOS 侧彻底收口为 positionFilter 通用控件；
// 按钮标题切到 monospacedSystemFont，以适配音名字母和数字两类选项。
private final class PositionFilterRowView: NSView {
    private var buttonsByOptionID: [SettingsPositionFilterOptionID: PositionFilterButton] = [:]

    private let titleLabel = NSTextField(labelWithString: "")
    private let optionsStackView = NSStackView()

    private func optionButton(for item: SettingsPositionFilterItem) -> PositionFilterButton {
        let button = PositionFilterButton(frame: .zero)
        button.target = self
        button.action = #selector(handleOptionButtonTap(_:))
        return button
    }
}

private final class PositionFilterButton: NSButton {
    private func applyCurrentAppearance() {
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedSystemFont(
                    ofSize: Style.positionFilterButtonFontSize,
                    weight: .semibold
                )
            ]
        )
    }
}
```

## 修改 4：双端样式常量从 `fretFilter...` 收口为 `positionFilter...`

### 修改前

- 样式常量命名仍然写死在 `fretFilter`
- 这种残留会让 view 命名已经抽象、样式命名却仍停在旧语义，后续维护会继续产生割裂

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: Style
// 功能说明: 修改前 iOS 样式常量仍沿用 fretFilter 前缀。
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

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: Style
// 功能说明: 修改前 macOS 样式常量同样仍然沿用 fretFilter 前缀。
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

### 修改后

- 双端样式常量都切成 `positionFilter...`
- macOS 还同步把最小尺寸、圆角、内边距命名也一起收口，避免新的 view 仍依赖旧常量名

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名/符号: Style
// 功能说明: 修改后 iOS 样式常量与 PositionFilterRowView / PositionFilterButton 保持一致命名。
private enum Style {
    static let positionFilterContentSpacing: CGFloat = 8
    static let positionFilterSpacing: CGFloat = 4
    static let positionFilterButtonFontSize: CGFloat = 12
    static let positionFilterButtonContentInsets = NSDirectionalEdgeInsets(
        top: 6,
        leading: 0,
        bottom: 6,
        trailing: 0
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名/符号: Style
// 功能说明: 修改后 macOS 样式常量同步收口为 positionFilter 前缀，
// 让按钮尺寸、圆角和内边距都与新的通用控件命名保持一致。
private enum Style {
    static let minimumPositionFilterButtonWidth: CGFloat = 24
    static let minimumPositionFilterButtonHeight: CGFloat = 28
    static let positionFilterContentSpacing: CGFloat = 8
    static let positionFilterSpacing: CGFloat = 4
    static let positionFilterButtonCornerRadius: CGFloat = 8
    static let positionFilterButtonFontSize: CGFloat = 12
    static let positionFilterButtonContentInsets = NSEdgeInsets(
        top: 5,
        left: 0,
        bottom: 5,
        right: 0
    )
}
```

## 验证情况

- 已对 `iOSSettingsPanelView.swift` 与 `macOSSettingsPanelView.swift` 运行 `ReadLints`
- 结果：无 linter 报错
- 本次未运行 `xcodebuild` / 应用启动验证，因此这份记录只确认表现层代码收口与 IDE lint 状态

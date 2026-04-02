# 20260402_110929_phase4_enable_vertical_rail_strip_views

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260402_110929`
- 记录范围：实施 `右侧音名条布局` 计划的阶段 `4`，让双平台 `NaturalNoteStripView` 真正支持 `horizontalStrip` / `verticalRail` 两种内部排布，并让 renderer 在渲染 `naturalNoteStrip` surface 时按 shared `presentationStyle` 驱动平台视图模式
- 修改目标：
  - 让 `naturalNoteStrip` 不再只会渲染底部横条，而是能在右侧 rail 场景切成纵向按钮列
  - 让 intrinsic size 按模式输出：横条给高度、竖条给宽度
  - 让 button/view 的 hugging / compression priority 随模式切换，避免 rail 宽度被内容异常拉宽
  - 保持点击事件、按钮标识、可见性和 answer 路由不变
- 修改统计：`4 files changed, 168 insertions(+), 25 deletions(-)`
- 涉及文件：
  - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
  - `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`

## 1. `iOSNaturalNoteStripView.swift`：从单一横条升级为可切换的 strip / rail 视图

- 修改前：iOS 端 `naturalNoteStrip` 只有一个固定形态：
  - `stackView.axis` 固定为 `.horizontal`
  - `intrinsicContentSize` 永远只提供高度
  - view 和 button 的横向 hugging / compression priority 是写死的，不能针对 rail 场景收口宽度

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: intrinsicContentSize, configureView(), NaturalNoteButton.configureButton()
// 功能说明: 修改前 iOS strip 只支持底部横条布局；intrinsic size 只给高度，stack 永远横向，按钮横向优先级固定为低。
final class iOSNaturalNoteStripView: UIView {
    var onPitchClassTap: ((PitchClass) -> Void)?

    override var intrinsicContentSize: CGSize {
        let stackSize = stackView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: directionalLayoutMargins.top + stackSize.height + directionalLayoutMargins.bottom
        )
    }

    private func configureView() {
        accessibilityIdentifier = "natural-note-strip-view"
        directionalLayoutMargins = Style.contentInsets
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = Style.cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = Style.borderWidth
        layer.borderColor = UIColor.separator.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = Style.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }
}

private final class NaturalNoteButton: UIButton {
    private func configureButton() {
        configuration = .filled()
        configuration?.buttonSize = .medium
        configuration?.cornerStyle = .capsule
        configuration?.contentInsets = Style.buttonContentInsets

        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.7
        titleLabel?.lineBreakMode = .byClipping

        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}
```

- 修改后：iOS 端新增 `LayoutMode` 和 `applyPresentationStyle(...)`，把 shared `presentationStyle` 映射到平台层布局模式；`applyLayoutMode()` 会统一切换：
  - `stackView.axis`
  - view 自身的主轴 hugging / compression priority
  - button 的横向优先级
  - intrinsic size 的宽高语义

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: intrinsicContentSize, applyPresentationStyle(_:), configureView(), makeButton(for:), applyLayoutMode(), NaturalNoteButton.applyLayoutMode(_:)
// 功能说明: 修改后 iOS strip 可在 horizontalStrip / verticalRail 两种模式间切换；横条继续给高度，竖条改为给宽度，并同步收口按钮与容器的横向优先级。
final class iOSNaturalNoteStripView: UIView {
    enum LayoutMode: Equatable {
        case horizontalStrip
        case verticalRail
    }

    var onPitchClassTap: ((PitchClass) -> Void)?
    var layoutMode: LayoutMode = .horizontalStrip {
        didSet {
            guard oldValue != layoutMode else {
                return
            }
            applyLayoutMode()
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        let stackSize = stackView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
        switch layoutMode {
        case .horizontalStrip:
            return CGSize(
                width: UIView.noIntrinsicMetric,
                height: directionalLayoutMargins.top + stackSize.height + directionalLayoutMargins.bottom
            )
        case .verticalRail:
            return CGSize(
                width: directionalLayoutMargins.leading + stackSize.width + directionalLayoutMargins.trailing,
                height: UIView.noIntrinsicMetric
            )
        }
    }

    func applyPresentationStyle(
        _ presentationStyle: ExerciseSurfacePresentationStyle
    ) {
        switch presentationStyle {
        case .verticalRail:
            layoutMode = .verticalRail
        case .standard, .horizontalStrip:
            layoutMode = .horizontalStrip
        }
    }

    private func configureView() {
        accessibilityIdentifier = "natural-note-strip-view"
        directionalLayoutMargins = Style.contentInsets
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = Style.cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = Style.borderWidth
        layer.borderColor = UIColor.separator.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        stackView.spacing = Style.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])

        applyLayoutMode()
    }

    private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
        let button = NaturalNoteButton(frame: .zero)
        button.apply(pitchClass: pitchClass)
        button.applyLayoutMode(layoutMode)
        button.addTarget(
            self,
            action: #selector(handleButtonTap(_:)),
            for: .touchUpInside
        )
        return button
    }

    private func applyLayoutMode() {
        switch layoutMode {
        case .horizontalStrip:
            stackView.axis = .horizontal
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        case .verticalRail:
            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.defaultLow, for: .vertical)
            setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        }

        buttons.forEach { $0.applyLayoutMode(layoutMode) }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}

private final class NaturalNoteButton: UIButton {
    func applyLayoutMode(_ layoutMode: iOSNaturalNoteStripView.LayoutMode) {
        switch layoutMode {
        case .horizontalStrip:
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.defaultLow, for: .horizontal)
        case .verticalRail:
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.required, for: .horizontal)
        }
    }
}
```

## 2. `macOSNaturalNoteStripView.swift`：同步支持 rail 模式与宽度型 intrinsic size

- 修改前：macOS 端与 iOS 端的问题相同，只会渲染一条固定的横向 `NSStackView`，并且只提供 intrinsic height。按钮默认一直是横向低优先级，无法针对竖向 rail 收口宽度。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: intrinsicContentSize, configureView(), NaturalNoteButton.configureButton()
// 功能说明: 修改前 macOS strip 只有底部横条形态；stack 永远横向，intrinsic size 只给高度，按钮横向优先级固定为低。
final class macOSNaturalNoteStripView: NSView {
    var onPitchClassTap: ((PitchClass) -> Void)?
    var areButtonsEnabled = true {
        didSet {
            updateButtonEnabledState()
        }
    }

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        let stackSize = stackView.fittingSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
        )
    }

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("natural-note-strip-view")
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = Style.cornerRadius
        layer?.borderWidth = Style.borderWidth
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillEqually
        stackView.spacing = Style.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }
        updateButtonEnabledState()

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.contentInsets.left
            ),
            stackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.contentInsets.right
            ),
            stackView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.contentInsets.top
            ),
            stackView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.contentInsets.bottom
            )
        ])
    }
}

private final class NaturalNoteButton: NSButton {
    private func configureButton() {
        setButtonType(.momentaryPushIn)
        bezelStyle = .regularSquare
        isBordered = false
        focusRingType = .default
        wantsLayer = true
        layer?.cornerRadius = Style.buttonCornerRadius
        layer?.masksToBounds = true

        if let buttonCell = cell as? NSButtonCell {
            buttonCell.lineBreakMode = .byClipping
            buttonCell.usesSingleLineMode = true
        }

        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}
```

- 修改后：macOS 端同样引入 `LayoutMode`、`applyPresentationStyle(...)` 和 `applyLayoutMode()`。这样 shared scene 发出的 `verticalRail` 现在可以真正转成平台层纵向按钮列，且 rail 模式下 intrinsic size 会改为输出宽度而不是高度。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: intrinsicContentSize, applyPresentationStyle(_:), configureView(), makeButton(for:), applyLayoutMode(), NaturalNoteButton.applyLayoutMode(_:)
// 功能说明: 修改后 macOS strip 与 iOS 端对齐，支持 horizontalStrip / verticalRail 双模式，并在 rail 模式下收紧横向优先级与 intrinsic width。
final class macOSNaturalNoteStripView: NSView {
    enum LayoutMode: Equatable {
        case horizontalStrip
        case verticalRail
    }

    var onPitchClassTap: ((PitchClass) -> Void)?
    var areButtonsEnabled = true {
        didSet {
            updateButtonEnabledState()
        }
    }
    var layoutMode: LayoutMode = .horizontalStrip {
        didSet {
            guard oldValue != layoutMode else {
                return
            }
            applyLayoutMode()
        }
    }

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        let stackSize = stackView.fittingSize
        switch layoutMode {
        case .horizontalStrip:
            return NSSize(
                width: NSView.noIntrinsicMetric,
                height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
            )
        case .verticalRail:
            return NSSize(
                width: Style.contentInsets.left + stackSize.width + Style.contentInsets.right,
                height: NSView.noIntrinsicMetric
            )
        }
    }

    func applyPresentationStyle(
        _ presentationStyle: ExerciseSurfacePresentationStyle
    ) {
        switch presentationStyle {
        case .verticalRail:
            layoutMode = .verticalRail
        case .standard, .horizontalStrip:
            layoutMode = .horizontalStrip
        }
    }

    private func configureView() {
        identifier = NSUserInterfaceItemIdentifier("natural-note-strip-view")
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = Style.cornerRadius
        layer?.borderWidth = Style.borderWidth
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(
            Style.borderOpacity
        ).cgColor
        stackView.spacing = Style.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }
        updateButtonEnabledState()

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Style.contentInsets.left
            ),
            stackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Style.contentInsets.right
            ),
            stackView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Style.contentInsets.top
            ),
            stackView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Style.contentInsets.bottom
            )
        ])

        applyLayoutMode()
    }

    private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
        let button = NaturalNoteButton(frame: .zero)
        button.apply(pitchClass: pitchClass)
        button.applyLayoutMode(layoutMode)
        button.target = self
        button.action = #selector(handleButtonTap(_:))
        return button
    }

    private func applyLayoutMode() {
        switch layoutMode {
        case .horizontalStrip:
            stackView.orientation = .horizontal
            stackView.alignment = .centerY
            stackView.distribution = .fillEqually
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        case .verticalRail:
            stackView.orientation = .vertical
            stackView.alignment = .centerX
            stackView.distribution = .fillEqually
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.defaultLow, for: .vertical)
            setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        }

        buttons.forEach { $0.applyLayoutMode(layoutMode) }
        invalidateIntrinsicContentSize()
        needsLayout = true
    }
}

private final class NaturalNoteButton: NSButton {
    func applyLayoutMode(_ layoutMode: macOSNaturalNoteStripView.LayoutMode) {
        switch layoutMode {
        case .horizontalStrip:
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.defaultLow, for: .horizontal)
        case .verticalRail:
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.required, for: .horizontal)
        }
    }
}
```

## 3. 双平台 renderer：把 shared `presentationStyle` 真正下发到平台视图

- 修改前：双平台 renderer 的 `renderSurface(...)` 只会按 `surface.id` 拿现成 view 并 `embed(...)`，不会读取 `surface.presentationStyle`。这意味着阶段 `2` 发出来的 `verticalRail` 语义虽然已经存在于 shared scene 里，但 view 层依然只会沿用默认横条形态。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: renderSurface(_:in:)
// 功能说明: 修改前 iOS renderer 不消费 surface.presentationStyle；拿到 naturalNoteStripView 后直接 embed，无法驱动 rail 模式。
private func renderSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: UIView
) {
    guard let surfaceView = view(for: surface.id) else {
        return
    }
    embed(
        surfaceView,
        in: hostView,
        contentInsets: contentInsets(for: surface)
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: renderSurface(_:in:)
// 功能说明: 修改前 macOS renderer 同样只按 surfaceID 取 view，不会把 verticalRail / horizontalStrip 语义传给 naturalNoteStripView。
private func renderSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: NSView
) {
    guard let surfaceView = view(for: surface.id) else {
        return
    }
    embed(
        surfaceView,
        in: hostView,
        contentInsets: contentInsets(for: surface)
    )
}
```

- 修改后：双平台 renderer 都新增 `configurePresentationStyle(for:)`。当前只在 `surface.id == .naturalNoteStrip` 时生效，把 `surface.presentationStyle` 映射到对应平台的 `NaturalNoteStripView.applyPresentationStyle(...)`；其它 surface 不受影响。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: renderSurface(_:in:), configurePresentationStyle(for:)
// 功能说明: 修改后 iOS renderer 会在 embed 前先把 shared surface.presentationStyle 下发给 naturalNoteStripView，从而让 rail scene 真正切到 verticalRail 布局。
private func renderSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: UIView
) {
    configurePresentationStyle(for: surface)
    guard let surfaceView = view(for: surface.id) else {
        return
    }
    embed(
        surfaceView,
        in: hostView,
        contentInsets: contentInsets(for: surface)
    )
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名: renderSurface(_:in:), configurePresentationStyle(for:)
// 功能说明: 修改后 macOS renderer 与 iOS 对齐，natural note strip 在渲染时会显式接收 shared scene 发出的 presentationStyle。
private func renderSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: NSView
) {
    configurePresentationStyle(for: surface)
    guard let surfaceView = view(for: surface.id) else {
        return
    }
    embed(
        surfaceView,
        in: hostView,
        contentInsets: contentInsets(for: surface)
    )
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
}
```

## 4. 验证结果

- `ReadLints`：`iOSNaturalNoteStripView.swift`、`macOSNaturalNoteStripView.swift`、`iOSExerciseSceneRenderer.swift`、`macOSExerciseSceneRenderer.swift` 无新增 linter 问题
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'platform=macOS' build`：通过
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'generic/platform=iOS Simulator' build`：通过

## 5. 阶段边界

- 本次记录只覆盖阶段 `4` 的 strip view 竖排化与 renderer 接线
- shared scene contract、composition policy、answer 路由和 surface 身份没有改动
- viewport 高度收口与 validation 回归补强仍属于阶段 `5`

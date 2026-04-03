# 20260403_170534_stage4_scheme_c_platform_vertical_rail_placement

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_170534`
- 记录范围：只记录方案 C 的阶段4代码改动，即让双端 `NaturalNoteStripView` 的 `verticalRail` 改为消费 shared placement；不记录阶段5+ 的 renderer / host 对齐清理
- 当前 `git status` 中还包含计划文件 `/.cursor/plans/rail_placement_phases_c_51a1bd19.plan.md`；该文件不属于本记录范围，本记录只说明本轮实际代码改动
- 本记录不放原始 `git diff`，只按真实代码状态说明“修改前 / 修改后”
- 本轮代码改动文件：
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- 本轮相关代码文件状态（`git status --short`）：
- `M NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `M NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- 本轮 `git diff --stat`（仅上述代码文件）：`2 files changed, 215 insertions(+), 50 deletions(-)`

## 1. 本轮目标

- 阶段4的目标不是再扩 shared builder，而是把阶段2/3已经冻结好的 `ExerciseNaturalNoteStripRailLayout` 真正接到平台 view。
- `horizontalStrip` 继续沿用既有 `stackView`，避免一次性重写整棵控件树。
- `verticalRail` 不再靠平台层单列 `stackView` 自己推导 12 个槽位的高度、顺序和宽度，而是只消费 shared placement 的 `contentSize` 与 `placements`。

## 2. 修改一：把 `verticalRail` 的尺寸真相切到 shared `contentSize`

### 2.1 macOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - macOSNaturalNoteStripView.activeRailButtonExtent
// - macOSNaturalNoteStripView.activeRailCrossAxisWidthScale
// - macOSNaturalNoteStripView.verticalRailContentWidth
// - macOSNaturalNoteStripView.verticalRailIntrinsicWidth
// - macOSNaturalNoteStripView.verticalRailIntrinsicHeight
// 修改前说明:
// 1. vertical rail 的宽度仍由“单个按钮宽度 + 内容内边距”再乘 crossAxisWidthScale 得出。
// 2. vertical rail 的高度仍由 slotCount == 12 的单列 stack 公式推出。
private var activeRailButtonExtent: CGFloat {
    CGFloat(activeRailContract.buttonExtent)
}
private var activeRailCrossAxisWidthScale: CGFloat {
    CGFloat(activeRailContract.resolvedCrossAxisWidthScale)
}
private var verticalRailContentWidth: CGFloat {
    Style.contentInsets.left
        + activeRailButtonExtent
        + Style.contentInsets.right
}
private var verticalRailIntrinsicWidth: CGFloat {
    switch activeRailContract.crossAxisPolicy {
    case .fitContent:
        return verticalRailContentWidth * activeRailCrossAxisWidthScale
    }
}
private var verticalRailIntrinsicHeight: CGFloat {
    switch activeRailContract.mainAxisPolicy {
    case .contentSized:
        let slotCount = CGFloat(activeRailContract.slotModel.slotCount)
        let totalSpacing = max(0, slotCount - 1) * Style.itemSpacing
        return Style.contentInsets.top
            + (slotCount * activeRailButtonExtent)
            + totalSpacing
            + Style.contentInsets.bottom
    }
}
```

### 2.2 macOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - macOSNaturalNoteStripView.activeRailLayout
// - macOSNaturalNoteStripView.verticalRailIntrinsicWidth
// - macOSNaturalNoteStripView.verticalRailIntrinsicHeight
// - macOSNaturalNoteStripView.layout()
// 修改后说明:
// 1. rail 的宽高都直接读 shared layout 的 contentSize。
// 2. 平台层不再自己根据 12 槽位 stack 公式推导 rail intrinsic size。
// 3. layout() 中补一个统一入口，保证 shared placement 会在视图布局阶段落成真实 frame。
private var activeRailLayout: ExerciseNaturalNoteStripRailLayout {
    activeRailContract.defaultLayoutContext.resolvedLayout
}
private var verticalRailIntrinsicWidth: CGFloat {
    CGFloat(activeRailLayout.contentSize.width)
}
private var verticalRailIntrinsicHeight: CGFloat {
    CGFloat(activeRailLayout.contentSize.height)
}

override func layout() {
    super.layout()
    layoutRailCanvasIfNeeded()
}
```

### 2.3 iOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - iOSNaturalNoteStripView.activeRailButtonExtent
// - iOSNaturalNoteStripView.activeRailCrossAxisWidthScale
// - iOSNaturalNoteStripView.verticalRailContentWidth
// - iOSNaturalNoteStripView.verticalRailIntrinsicWidth
// - iOSNaturalNoteStripView.verticalRailIntrinsicHeight
// 修改前说明:
// 1. iOS 端与 macOS 端相同，rail 宽高仍来自旧的单列合同推导。
// 2. shared placement 虽然已经存在，但平台 view 还没有真正消费 contentSize。
private var activeRailButtonExtent: CGFloat {
    CGFloat(activeRailContract.buttonExtent)
}
private var activeRailCrossAxisWidthScale: CGFloat {
    CGFloat(activeRailContract.resolvedCrossAxisWidthScale)
}
private var verticalRailContentWidth: CGFloat {
    directionalLayoutMargins.leading
        + activeRailButtonExtent
        + directionalLayoutMargins.trailing
}
private var verticalRailIntrinsicWidth: CGFloat {
    switch activeRailContract.crossAxisPolicy {
    case .fitContent:
        return verticalRailContentWidth * activeRailCrossAxisWidthScale
    }
}
private var verticalRailIntrinsicHeight: CGFloat {
    switch activeRailContract.mainAxisPolicy {
    case .contentSized:
        let slotCount = CGFloat(activeRailContract.slotModel.slotCount)
        let totalSpacing = max(0, slotCount - 1) * Style.itemSpacing
        return directionalLayoutMargins.top
            + (slotCount * activeRailButtonExtent)
            + totalSpacing
            + directionalLayoutMargins.bottom
    }
}
```

### 2.4 iOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - iOSNaturalNoteStripView.activeRailLayout
// - iOSNaturalNoteStripView.verticalRailIntrinsicWidth
// - iOSNaturalNoteStripView.verticalRailIntrinsicHeight
// - iOSNaturalNoteStripView.layoutSubviews()
// 修改后说明:
// 1. iOS 端也把 rail intrinsic size 的真相切到 shared layout。
// 2. layoutSubviews() 成为 placement frame 落地的统一时机。
private var activeRailLayout: ExerciseNaturalNoteStripRailLayout {
    activeRailContract.defaultLayoutContext.resolvedLayout
}
private var verticalRailIntrinsicWidth: CGFloat {
    CGFloat(activeRailLayout.contentSize.width)
}
private var verticalRailIntrinsicHeight: CGFloat {
    CGFloat(activeRailLayout.contentSize.height)
}

override func layoutSubviews() {
    super.layoutSubviews()
    layoutRailCanvasIfNeeded()
}
```

## 3. 修改二：引入 placement-backed 容器，保留 `horizontalStrip`，切换 `verticalRail` 到 `railCanvasView`

### 3.1 macOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - macOSNaturalNoteStripView.stackView
// - macOSNaturalNoteStripView.configureView()
// - macOSNaturalNoteStripView.applyLayoutMode()
// 修改前说明:
// 1. 整个控件只有一个 stackView 容器。
// 2. horizontal / vertical 两种模式都在同一个 stackView 上切 axis。
private let stackView = NSStackView()

private func configureView() {
    // ... 其他样式代码省略 ...
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

private func applyLayoutMode() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillEqually
    case .verticalRail:
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .fill
    }

    buttons.forEach {
        $0.applyLayoutMode(layoutMode, railContract: activeRailContract)
    }
}
```

### 3.2 macOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - macOSNaturalNoteStripView.railCanvasView
// - macOSNaturalNoteStripView.configureView()
// - macOSNaturalNoteStripView.applyLayoutMode()
// - macOSNaturalNoteStripView.syncButtonContainer()
// - macOSNaturalNoteStripView.detachButtonFromCurrentContainer(_:)
// 修改后说明:
// 1. horizontalStrip 继续用 stackView。
// 2. verticalRail 改为 railCanvasView 容器，按钮会在两种宿主之间切换。
// 3. 平台层不再依赖“竖向 stack 排列顺序”来表达 rail 几何。
private let stackView = NSStackView()
private let railCanvasView = RailCanvasView()

private func configureView() {
    // ... 其他样式代码省略 ...
    stackView.spacing = Style.itemSpacing
    stackView.translatesAutoresizingMaskIntoConstraints = false
    railCanvasView.isHidden = true

    addSubview(stackView)
    addSubview(railCanvasView)
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

private func applyLayoutMode() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillEqually
    case .verticalRail:
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .fill
    }

    syncButtonContainer()
    buttons.forEach {
        $0.applyLayoutMode(layoutMode, railContract: activeRailContract)
        $0.applyVisibleTitle(
            resolvedVisibleTitle(for: $0.pitchClass)
        )
    }
}

private func syncButtonContainer() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.isHidden = false
        railCanvasView.isHidden = true
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            stackView.addArrangedSubview(button)
        }
    case .verticalRail:
        stackView.isHidden = true
        railCanvasView.isHidden = false
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            railCanvasView.addSubview(button)
        }
    }
}

private func detachButtonFromCurrentContainer(_ button: NaturalNoteButton) {
    if stackView.arrangedSubviews.contains(button) {
        stackView.removeArrangedSubview(button)
    }
    button.removeFromSuperview()
}
```

### 3.3 iOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - iOSNaturalNoteStripView.stackView
// - iOSNaturalNoteStripView.configureView()
// - iOSNaturalNoteStripView.applyLayoutMode()
// 修改前说明:
// 1. iOS 端也只有 stackView 一个容器。
// 2. vertical rail 仍通过 stackView.axis = .vertical 表达内部布局。
private let stackView = UIStackView()

private func configureView() {
    // ... 其他样式代码省略 ...
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

private func applyLayoutMode() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
    case .verticalRail:
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
    }

    buttons.forEach {
        $0.applyLayoutMode(layoutMode, railContract: activeRailContract)
    }
}
```

### 3.4 iOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - iOSNaturalNoteStripView.railCanvasView
// - iOSNaturalNoteStripView.configureView()
// - iOSNaturalNoteStripView.applyLayoutMode()
// - iOSNaturalNoteStripView.syncButtonContainer()
// - iOSNaturalNoteStripView.detachButtonFromCurrentContainer(_:)
// 修改后说明:
// 1. iOS 端与 macOS 端保持同构：stackView 只服务 horizontalStrip。
// 2. verticalRail 改为 railCanvasView 容器，后续 frame 由 shared placement 驱动。
private let stackView = UIStackView()
private let railCanvasView = UIView()

private func configureView() {
    // ... 其他样式代码省略 ...
    stackView.spacing = Style.itemSpacing
    stackView.translatesAutoresizingMaskIntoConstraints = false
    railCanvasView.isHidden = true
    railCanvasView.clipsToBounds = true

    addSubview(stackView)
    addSubview(railCanvasView)

    NSLayoutConstraint.activate([
        stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
        stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
        stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
        stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
    ])
}

private func applyLayoutMode() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
    case .verticalRail:
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
    }

    syncButtonContainer()
    buttons.forEach {
        $0.applyLayoutMode(layoutMode, railContract: activeRailContract)
        $0.applyVisibleTitle(
            resolvedVisibleTitle(for: $0.pitchClass)
        )
    }
}

private func syncButtonContainer() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.isHidden = false
        railCanvasView.isHidden = true
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            stackView.addArrangedSubview(button)
        }
    case .verticalRail:
        stackView.isHidden = true
        railCanvasView.isHidden = false
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            railCanvasView.addSubview(button)
        }
    }
}

private func detachButtonFromCurrentContainer(_ button: NaturalNoteButton) {
    if stackView.arrangedSubviews.contains(button) {
        stackView.removeArrangedSubview(button)
    }
    button.removeFromSuperview()
}
```

## 4. 修改三：按 shared placement 设置按钮 frame，并把标题显示切到 `showsTitle`

### 4.1 macOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - NaturalNoteButton.apply(pitchClass:)
// - PitchClass.stripVisibleTitle
// 修改前说明:
// 1. 按钮标题在 apply(pitchClass:) 时一次性写死。
// 2. 没有从 shared placement 读取 showsTitle，也没有 rail-local frame 布局入口。
func apply(pitchClass: PitchClass) {
    self.pitchClass = pitchClass
    self.title = pitchClass.stripVisibleTitle
    toolTip = "Choose note \(pitchClass.stripAccessibilityLabel)"
    identifier = NSUserInterfaceItemIdentifier(
        "natural-note-strip-button-\(pitchClass.stripIdentifierToken)"
    )
    applyCurrentAppearance()
    invalidateIntrinsicContentSize()
}

private extension PitchClass {
    var stripVisibleTitle: String {
        isNatural ? displayText() : ""
    }
}
```

### 4.2 macOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - macOSNaturalNoteStripView.resolvedVisibleTitle(for:)
// - macOSNaturalNoteStripView.railPlacement(for:)
// - macOSNaturalNoteStripView.layoutRailCanvasIfNeeded()
// - RailCanvasView.isFlipped
// - NaturalNoteButton.applyVisibleTitle(_:)
// - PitchClass.stripVisibleTitle(showsTitle:)
// 修改后说明:
// 1. 标题显示改为读 shared placement.showsTitle，而不是平台层自己假设“只有自然音显示标题”。
// 2. 按钮 frame 直接读 placement.frame，坐标系保持 rail-local top-leading。
// 3. macOS 额外引入 flipped canvas，保证 shared y 坐标无需在平台层反算。
private func resolvedVisibleTitle(for pitchClass: PitchClass?) -> String {
    guard let pitchClass else {
        return ""
    }

    switch layoutMode {
    case .horizontalStrip:
        return pitchClass.stripVisibleTitle
    case .verticalRail:
        return pitchClass.stripVisibleTitle(
            showsTitle: railPlacement(for: pitchClass)?.showsTitle ?? false
        )
    }
}

private func railPlacement(
    for pitchClass: PitchClass
) -> ExerciseNaturalNoteStripRailPlacement? {
    activeRailLayout.placements.first { $0.pitchClass == pitchClass }
}

private func layoutRailCanvasIfNeeded() {
    guard layoutMode == .verticalRail else {
        railCanvasView.frame = .zero
        return
    }

    let contentSize = CGSize(
        width: verticalRailIntrinsicWidth,
        height: verticalRailIntrinsicHeight
    )
    let contentFrame = CGRect(
        x: max(0, (bounds.width - contentSize.width) / 2),
        y: max(0, (bounds.height - contentSize.height) / 2),
        width: min(bounds.width, contentSize.width),
        height: min(bounds.height, contentSize.height)
    )
    railCanvasView.frame = contentFrame

    buttons.forEach { button in
        guard
            let pitchClass = button.pitchClass,
            let placement = railPlacement(for: pitchClass)
        else {
            button.isHidden = true
            return
        }

        button.isHidden = false
        button.frame = placement.frame
    }
}

private final class RailCanvasView: NSView {
    override var isFlipped: Bool {
        true
    }
}

func apply(pitchClass: PitchClass) {
    self.pitchClass = pitchClass
    toolTip = "Choose note \(pitchClass.stripAccessibilityLabel)"
    identifier = NSUserInterfaceItemIdentifier(
        "natural-note-strip-button-\(pitchClass.stripIdentifierToken)"
    )
    applyVisibleTitle(pitchClass.stripVisibleTitle)
}

func applyVisibleTitle(_ title: String) {
    self.title = title
    applyCurrentAppearance()
    invalidateIntrinsicContentSize()
}

private extension PitchClass {
    var stripVisibleTitle: String {
        isNatural ? displayText() : ""
    }

    func stripVisibleTitle(showsTitle: Bool) -> String {
        showsTitle ? displayText() : ""
    }
}
```

### 4.3 iOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - NaturalNoteButton.apply(pitchClass:)
// - PitchClass.stripVisibleTitle
// 修改前说明:
// 1. iOS 端同样在按钮初始化时就把标题写死。
// 2. 没有单独的 placement frame 布局逻辑，也没有按 showsTitle 切换标题的入口。
func apply(pitchClass: PitchClass) {
    self.pitchClass = pitchClass
    accessibilityIdentifier = "natural-note-strip-button-\(pitchClass.stripIdentifierToken)"
    accessibilityLabel = "Choose note \(pitchClass.stripAccessibilityLabel)"
    setTitle(pitchClass.stripVisibleTitle, for: .normal)
    invalidateIntrinsicContentSize()
    setNeedsUpdateConfiguration()
}

private extension PitchClass {
    var stripVisibleTitle: String {
        isNatural ? displayText() : ""
    }
}
```

### 4.4 iOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - iOSNaturalNoteStripView.resolvedVisibleTitle(for:)
// - iOSNaturalNoteStripView.railPlacement(for:)
// - iOSNaturalNoteStripView.layoutRailCanvasIfNeeded()
// - NaturalNoteButton.applyVisibleTitle(_:)
// - PitchClass.stripVisibleTitle(showsTitle:)
// 修改后说明:
// 1. iOS 端也改为读 shared placement.showsTitle。
// 2. railCanvasView 的 frame 会整体居中，按钮 frame 逐个落到 placement 给出的局部坐标。
private func resolvedVisibleTitle(for pitchClass: PitchClass?) -> String {
    guard let pitchClass else {
        return ""
    }

    switch layoutMode {
    case .horizontalStrip:
        return pitchClass.stripVisibleTitle
    case .verticalRail:
        return pitchClass.stripVisibleTitle(
            showsTitle: railPlacement(for: pitchClass)?.showsTitle ?? false
        )
    }
}

private func railPlacement(
    for pitchClass: PitchClass
) -> ExerciseNaturalNoteStripRailPlacement? {
    activeRailLayout.placements.first { $0.pitchClass == pitchClass }
}

private func layoutRailCanvasIfNeeded() {
    guard layoutMode == .verticalRail else {
        railCanvasView.frame = .zero
        return
    }

    let contentSize = CGSize(
        width: verticalRailIntrinsicWidth,
        height: verticalRailIntrinsicHeight
    )
    let contentFrame = CGRect(
        x: max(0, (bounds.width - contentSize.width) / 2),
        y: max(0, (bounds.height - contentSize.height) / 2),
        width: min(bounds.width, contentSize.width),
        height: min(bounds.height, contentSize.height)
    )
    railCanvasView.frame = contentFrame

    buttons.forEach { button in
        guard
            let pitchClass = button.pitchClass,
            let placement = railPlacement(for: pitchClass)
        else {
            button.isHidden = true
            return
        }

        button.isHidden = false
        button.frame = placement.frame
    }
}

func apply(pitchClass: PitchClass) {
    self.pitchClass = pitchClass
    accessibilityIdentifier = "natural-note-strip-button-\(pitchClass.stripIdentifierToken)"
    accessibilityLabel = "Choose note \(pitchClass.stripAccessibilityLabel)"
    applyVisibleTitle(pitchClass.stripVisibleTitle)
}

func applyVisibleTitle(_ title: String) {
    setTitle(title, for: .normal)
    invalidateIntrinsicContentSize()
    setNeedsUpdateConfiguration()
}

private extension PitchClass {
    var stripVisibleTitle: String {
        isNatural ? displayText() : ""
    }

    func stripVisibleTitle(showsTitle: Bool) -> String {
        showsTitle ? displayText() : ""
    }
}
```

## 5. 结果与边界

- `horizontalStrip` 路径仍保持 stack-based 实现，没有在本轮被重写。
- `verticalRail` 的宽高、按钮相对位置、标题显示策略，都已经切到 shared placement 出口。
- renderer 侧的 `verticallyCentered` / host 对齐逻辑还没有清理；这属于阶段5范围，不在本记录内。

## 6. 验证结果

- 代码诊断：`ReadLints` 检查 `macOSNaturalNoteStripView.swift` 与 `iOSNaturalNoteStripView.swift`，结果为无错误
- macOS 构建验证：

```bash
# 验证命令: macOS Debug 构建
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO
```

- 构建结果：`BUILD SUCCEEDED`
- iOS Simulator 构建验证：

```bash
# 验证命令: iOS Simulator Debug 构建
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO
```

- 构建结果：`BUILD SUCCEEDED`
- runtime smoke：本轮未执行；按计划留待阶段5/6一并回归

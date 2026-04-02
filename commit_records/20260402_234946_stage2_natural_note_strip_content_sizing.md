# 20260402_234946_stage2_natural_note_strip_content_sizing

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260402_234946`
- 记录范围：只记录方案 B 的阶段 2 落地，即让双端 `NaturalNoteStripView` 变成基于 shared rail contract 的内容尺寸视图
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本记录中的“修改前”，指 `20260402_233111_stage1_natural_note_strip_rail_contract.md` 记录完成后的代码状态
- 本轮实际改动文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
  - `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
  - `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- 本轮未改动但继续复用的文件：
  - `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
  - `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`

## 1. 本轮目标

- 阶段 1 已经把 right rail 的 shared contract 立起来了，但双端 `NaturalNoteStripView` 仍然没有真正消费这些字段。
- 旧视图的核心问题有两个：
  - `verticalRail` 下高度仍不是内容高度，父容器一拉伸，按钮就会被 `fillEqually` 平均撑长。
  - iOS 版 `intrinsicContentSize` 里还直接调用了 `layoutIfNeeded()`，这是典型的重入式布局风险点。
- 阶段 2 的目标，是让 strip view 自己具备“固定正方形按钮 + 有限内容高度 + 纯计算 intrinsic size”的能力，但暂时不做 renderer 里的垂直居中嵌入。

## 2. 修改一：把 shared 默认 rail contract 暴露给平台视图直接复用

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailContract, ExerciseScene.naturalNoteStripRailContract
// 修改前说明: 默认 rail contract 只在 private extension 里定义，
// 共享层能返回 contract，但平台视图本身还不能直接复用这个默认值。
struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 20

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
}

private extension ExerciseNaturalNoteStripRailContract {
    static let sideBySideAnswerRailDefault = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        verticalAlignment: .centered
    )
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail,
//           ExerciseScene.naturalNoteStripRailContract
// 修改后说明: 默认 right rail contract 被提升为共享静态默认值，
// 双端视图即使先于 renderer 接入，也可以直接拿同一份 shared 几何默认语义。
struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 20
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        verticalAlignment: .centered
    )

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
}

extension ExerciseScene {
    var naturalNoteStripRailContract: ExerciseNaturalNoteStripRailContract? {
        guard
            containsNaturalNoteStripAnswerRailInSideBySideLayout,
            let renderedSceneLayout,
            renderedSceneLayout.arrangement == .sideBySide,
            renderedSceneLayout.primarySurface.id == .fretboard,
            renderedSceneLayout.secondarySurface?.isNaturalNoteStripAnswerRail == true,
            renderedSceneLayout.secondaryMainAxisSizing == .fitContent
        else {
            return nil
        }

        return .defaultSideBySideAnswerRail
    }
}
```

### 2.3 这一改动解决了什么

- 平台层现在可以无分叉地复用 shared 默认值，不需要自己再写死 `20`、`fitContent`、`centered` 这类 rail 几何常量。
- 阶段 2 可以先让视图消费 contract，阶段 3 再让 renderer 接同一套 contract，而不是两边各自持有一份默认配置。

## 3. 修改二：macOS `NaturalNoteStripView` 改为 contract 驱动的内容尺寸视图

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数: intrinsicContentSize, applyLayoutMode()
// 修改前说明: verticalRail 只给 width，不给 height；
// 同时 stackView 还是 fillEqually，父容器给多少高度，按钮就会被等分拉长多少。
override var intrinsicContentSize: NSSize {
    switch layoutMode {
    case .horizontalStrip:
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top
                + tallestButtonIntrinsicHeight
                + Style.contentInsets.bottom
        )
    case .verticalRail:
        return NSSize(
            width: Style.contentInsets.left
                + widestButtonIntrinsicWidth
                + Style.contentInsets.right,
            height: NSView.noIntrinsicMetric
        )
    }
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
        stackView.distribution = .fillEqually
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数: NaturalNoteButton.intrinsicContentSize, NaturalNoteButton.applyLayoutMode(_:)
// 修改前说明: 按钮尺寸仍是“文本 intrinsic + padding + minimumHeight”，
// verticalRail 下没有固定正方形边长。
override var intrinsicContentSize: NSSize {
    let size = super.intrinsicContentSize
    return NSSize(
        width: size.width + Style.buttonContentInsets.left + Style.buttonContentInsets.right,
        height: max(
            size.height + Style.buttonContentInsets.top + Style.buttonContentInsets.bottom,
            Style.minimumButtonHeight
        )
    )
}

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
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数: applyRailContract(_:), intrinsicContentSize, verticalRailIntrinsicWidth, verticalRailIntrinsicHeight
// 修改后说明: macOS strip 先持有一份 active rail contract，
// verticalRail 的 width / height 都改为纯计算，不再依赖父布局的回灌。
private var railContract: ExerciseNaturalNoteStripRailContract = .defaultSideBySideAnswerRail {
    didSet {
        guard oldValue != railContract else {
            return
        }
        applyLayoutMode()
    }
}

override var intrinsicContentSize: NSSize {
    switch layoutMode {
    case .horizontalStrip:
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top
                + tallestButtonIntrinsicHeight
                + Style.contentInsets.bottom
        )
    case .verticalRail:
        return NSSize(
            width: verticalRailIntrinsicWidth,
            height: verticalRailIntrinsicHeight
        )
    }
}

private var verticalRailIntrinsicWidth: CGFloat {
    switch activeRailContract.crossAxisPolicy {
    case .fitContent:
        return Style.contentInsets.left
            + activeRailButtonExtent
            + Style.contentInsets.right
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

func applyRailContract(_ railContract: ExerciseNaturalNoteStripRailContract?) {
    self.railContract = railContract ?? .defaultSideBySideAnswerRail
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数: applyLayoutMode(), NaturalNoteButton.intrinsicContentSize,
//       NaturalNoteButton.applyLayoutMode(_:railContract:)
// 修改后说明: verticalRail 改为 fill 而不是 fillEqually；
// 按钮 intrinsic 直接返回 contract 指定的正方形边长，并把纵向 hugging / resistance 提高到 required。
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
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    buttons.forEach {
        $0.applyLayoutMode(layoutMode, railContract: activeRailContract)
    }
}

override var intrinsicContentSize: NSSize {
    switch layoutMode {
    case .horizontalStrip:
        let size = super.intrinsicContentSize
        return NSSize(
            width: size.width
                + Style.buttonContentInsets.left
                + Style.buttonContentInsets.right,
            height: max(
                size.height
                    + Style.buttonContentInsets.top
                    + Style.buttonContentInsets.bottom,
                Style.minimumButtonHeight
            )
        )
    case .verticalRail:
        let buttonExtent = CGFloat(railContract.buttonExtent)
        return NSSize(width: buttonExtent, height: buttonExtent)
    }
}

func applyLayoutMode(
    _ layoutMode: macOSNaturalNoteStripView.LayoutMode,
    railContract: ExerciseNaturalNoteStripRailContract
) {
    self.layoutMode = layoutMode
    self.railContract = railContract
    switch layoutMode {
    case .horizontalStrip:
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    case .verticalRail:
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
    }
}
```

### 3.3 这一改动解决了什么

- macOS 版 strip 终于有了真实的 vertical rail 内容高度。
- 旧的“按钮被整列高度等分拉长”路径被拆掉了，因为：
  - view 本身现在给出有限高度
  - stack 不再 `fillEqually`
  - 按钮直接返回正方形 intrinsic size

## 4. 修改三：iOS `NaturalNoteStripView` 改为纯计算内容尺寸，并清掉重入式布局

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数: intrinsicContentSize, applyLayoutMode()
// 修改前说明: intrinsicContentSize 里直接 layoutIfNeeded，再走 systemLayoutSizeFitting；
// verticalRail 同样不给有限高度，stack 仍是 fillEqually。
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

private func applyLayoutMode() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
    case .verticalRail:
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数: NaturalNoteButton.updateConfiguration(), NaturalNoteButton.applyLayoutMode(_:)
// 修改前说明: verticalRail 按钮仍然复用横条按钮配置，
// 没有固定正方形边长，也没有按 rail 模式缩减 contentInsets。
override func updateConfiguration() {
    var nextConfiguration = configuration ?? UIButton.Configuration.filled()
    nextConfiguration.title = title(for: .normal)
    nextConfiguration.buttonSize = .medium
    nextConfiguration.cornerStyle = .capsule
    nextConfiguration.contentInsets = Style.buttonContentInsets
    configuration = nextConfiguration
}

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
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数: applyRailContract(_:), intrinsicContentSize, verticalRailIntrinsicWidth, verticalRailIntrinsicHeight
// 修改后说明: iOS 版把 intrinsic 尺寸改成纯计算，彻底去掉了 layoutIfNeeded() 的重入风险。
private var railContract: ExerciseNaturalNoteStripRailContract = .defaultSideBySideAnswerRail {
    didSet {
        guard oldValue != railContract else {
            return
        }
        applyLayoutMode()
    }
}

override var intrinsicContentSize: CGSize {
    switch layoutMode {
    case .horizontalStrip:
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: directionalLayoutMargins.top
                + tallestButtonIntrinsicHeight
                + directionalLayoutMargins.bottom
        )
    case .verticalRail:
        return CGSize(
            width: verticalRailIntrinsicWidth,
            height: verticalRailIntrinsicHeight
        )
    }
}

private var verticalRailIntrinsicWidth: CGFloat {
    switch activeRailContract.crossAxisPolicy {
    case .fitContent:
        return directionalLayoutMargins.leading
            + activeRailButtonExtent
            + directionalLayoutMargins.trailing
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

func applyRailContract(_ railContract: ExerciseNaturalNoteStripRailContract?) {
    self.railContract = railContract ?? .defaultSideBySideAnswerRail
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数: applyLayoutMode(), NaturalNoteButton.intrinsicContentSize,
//       NaturalNoteButton.updateConfiguration(), NaturalNoteButton.applyLayoutMode(_:railContract:)
// 修改后说明: verticalRail 改为固定正方形按钮；配置里的 buttonSize、contentInsets、字体都按 rail 模式缩紧；
// stack 改为 fill，纵向 hugging / resistance 提升到 required。
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
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    buttons.forEach {
        $0.applyLayoutMode(layoutMode, railContract: activeRailContract)
    }
}

override var intrinsicContentSize: CGSize {
    switch layoutMode {
    case .horizontalStrip:
        return super.intrinsicContentSize
    case .verticalRail:
        let buttonExtent = CGFloat(railContract.buttonExtent)
        return CGSize(width: buttonExtent, height: buttonExtent)
    }
}

override func updateConfiguration() {
    var nextConfiguration = configuration ?? UIButton.Configuration.filled()
    nextConfiguration.title = title(for: .normal)
    nextConfiguration.buttonSize = layoutMode == .verticalRail ? .mini : .medium
    nextConfiguration.cornerStyle = .capsule
    nextConfiguration.contentInsets = resolvedContentInsets()
    let resolvedFont = resolvedTitleFont()
    nextConfiguration.titleTextAttributesTransformer =
        UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = resolvedFont
            return outgoing
        }
    configuration = nextConfiguration
}

func applyLayoutMode(
    _ layoutMode: iOSNaturalNoteStripView.LayoutMode,
    railContract: ExerciseNaturalNoteStripRailContract
) {
    self.layoutMode = layoutMode
    self.railContract = railContract
    switch layoutMode {
    case .horizontalStrip:
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    case .verticalRail:
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
    }
}
```

### 4.3 这一改动解决了什么

- iOS 版 `intrinsicContentSize` 已经不再触发布局，从根上避开了之前那类重入式布局风险。
- `verticalRail` 的按钮几何和内容高度现在与 macOS 保持同一套 shared contract 语义。

## 5. 本轮没有改什么

- `macOSExerciseSceneRenderer.swift` 和 `iOSExerciseSceneRenderer.swift` 还没有在 `configurePresentationStyle(for:)` 里调用 `applyRailContract(_:)`。
- 右侧整列里“内容垂直居中”的那部分约束还没有落地，仍属于阶段 3。
- 也就是说，阶段 2 解决的是“view 自己知道该多高、按钮该多大”，不是“父容器已经按正确方式安放它”。

## 6. 最终状态总结

- 双端 strip view 都已经具备：
  - shared rail contract 输入口
  - vertical rail 下有限的 intrinsic width / height
  - 固定正方形按钮尺寸
  - `fill` 而不是 `fillEqually` 的纵向堆叠方式
  - 纵向 hugging / compression resistance 提升
- iOS 版额外完成了一个关键清理：
  - 移除 `intrinsicContentSize` 中的 `layoutIfNeeded()`

## 7. 验证结果

- `ReadLints` 检查相关文件：无 linter 错误
- 构建验证命令：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`
- 构建结果：
  - macOS：`BUILD SUCCEEDED`
  - iOS Simulator：`BUILD SUCCEEDED`

## 8. 对后续阶段的直接意义

- 阶段 3 不需要再处理按钮尺寸和内容高度算法，只需要把 renderer 的嵌入约束改成：
  - slot 仍铺满整列
  - strip 本身用内容高度
  - 在列内 `centerY`
- 到这一步，造成“rail 太长”的视图内原因已经处理完，剩下的是父容器如何摆放它。

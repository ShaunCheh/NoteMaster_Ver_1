# 20260325_141530_phase5_platform_sizing_host_layout

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260325_141530`
- 记录范围：指板竖向 Scene 重构的阶段 5
- 本阶段目标：改造 iOS/macOS 为 host 高度驱动、指板宽度自适应且居中，同时把共享层的尺寸出口统一收敛到 `displayMode`

## 本阶段完成的修改

1. 在 `FretboardConfiguration` 中补齐 vertical 模式的宽高比与总尺寸出口，并让公共尺寸 API 按 `displayMode` 分发。
2. 在 `VerticalFretboardGeometryStrategy` 中移除本地重复的宽高比公式，改为直接复用共享配置层的尺寸真相。
3. 将 `iOSFretboardView` 与 `macOSFretboardView` 改成分模式 intrinsic：horizontal 走“宽度驱动高度”，vertical 走“高度驱动宽度”。
4. 在 `iOSViewController` 与 `macOSViewController` 中引入 `fretboardHostView`，实现横向全宽、竖向定高居中两套布局约束。

## 修改 1：`FretboardConfiguration` 的尺寸出口改为按 `displayMode` 生效

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.LayoutMetrics.totalWidth(...), heightToWidthMultiplier(...), widthToHeightMultiplier(...), resolvedHeight(forAvailableWidth:), resolvedWidth(forAvailableHeight:), heightToWidthMultiplier, widthToHeightMultiplier
// 功能说明: 修改前所有公共尺寸出口都默认沿用 horizontal 的宽度优先公式，vertical 模式虽然已经存在，但平台层拿到的仍然是横向宽高比。
struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        func totalWidth(
            forAvailableHeight height: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedHeightToWidthMultiplier = heightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
            guard resolvedHeightToWidthMultiplier > 0 else {
                return 0
            }

            return max(height, 0) / resolvedHeightToWidthMultiplier
        }

        func heightToWidthMultiplier(
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedDisplayPositionCount = max(displayPositionCount, 1)
            let resolvedStringCount = max(stringCount, 1)
            return drawingWidthFactor
                / drawingHeightFactor
                * CGFloat(resolvedStringCount)
                / (CGFloat(resolvedDisplayPositionCount) * resolvedCellWidthToHeightRatio)
        }

        func widthToHeightMultiplier(
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedHeightToWidthMultiplier = heightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
            guard resolvedHeightToWidthMultiplier > 0 else {
                return 0
            }

            return 1 / resolvedHeightToWidthMultiplier
        }
    }

    func resolvedHeight(forAvailableWidth width: CGFloat) -> CGFloat {
        layoutMetrics.totalHeight(
            forAvailableWidth: width,
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    }

    func resolvedWidth(forAvailableHeight height: CGFloat) -> CGFloat {
        layoutMetrics.totalWidth(
            forAvailableHeight: height,
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    }

    var heightToWidthMultiplier: CGFloat {
        layoutMetrics.heightToWidthMultiplier(
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    }

    var widthToHeightMultiplier: CGFloat {
        layoutMetrics.widthToHeightMultiplier(
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.LayoutMetrics.verticalWidthToHeightMultiplier(...), verticalHeightToWidthMultiplier(...), verticalTotalWidth(...), verticalTotalHeight(...), resolvedHeight(forAvailableWidth:), resolvedWidth(forAvailableHeight:), heightToWidthMultiplier, widthToHeightMultiplier
// 功能说明: 修改后共享配置层直接输出 horizontal / vertical 两套真实尺寸关系；平台层与 scene 层都从这里读取统一的宽高比真相。
struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        func verticalWidthToHeightMultiplier(
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedDisplayPositionCount = max(displayPositionCount, 1)
            let resolvedStringCount = max(stringCount, 1)
            return drawingHeightFactor
                / drawingWidthFactor
                * CGFloat(resolvedStringCount)
                * resolvedCellWidthToHeightRatio
                / CGFloat(resolvedDisplayPositionCount)
        }

        func verticalHeightToWidthMultiplier(
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            let resolvedWidthToHeightMultiplier = verticalWidthToHeightMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
            guard resolvedWidthToHeightMultiplier > 0 else {
                return 0
            }

            return 1 / resolvedWidthToHeightMultiplier
        }

        func verticalTotalWidth(
            forAvailableHeight height: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            max(height, 0) * verticalWidthToHeightMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }

        func verticalTotalHeight(
            forAvailableWidth width: CGFloat,
            displayPositionCount: Int,
            stringCount: Int
        ) -> CGFloat {
            max(width, 0) * verticalHeightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }
    }

    func resolvedHeight(forAvailableWidth width: CGFloat) -> CGFloat {
        switch displayMode {
        case .horizontal:
            return layoutMetrics.totalHeight(
                forAvailableWidth: width,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        case .vertical:
            return layoutMetrics.verticalTotalHeight(
                forAvailableWidth: width,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }
    }

    func resolvedWidth(forAvailableHeight height: CGFloat) -> CGFloat {
        switch displayMode {
        case .horizontal:
            return layoutMetrics.totalWidth(
                forAvailableHeight: height,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        case .vertical:
            return layoutMetrics.verticalTotalWidth(
                forAvailableHeight: height,
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }
    }

    var heightToWidthMultiplier: CGFloat {
        switch displayMode {
        case .horizontal:
            return layoutMetrics.heightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        case .vertical:
            return layoutMetrics.verticalHeightToWidthMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }
    }

    var widthToHeightMultiplier: CGFloat {
        switch displayMode {
        case .horizontal:
            return layoutMetrics.widthToHeightMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        case .vertical:
            return layoutMetrics.verticalWidthToHeightMultiplier(
                displayPositionCount: displayPositionCount,
                stringCount: stringCount
            )
        }
    }
}
```

## 修改 2：`VerticalFretboardGeometryStrategy` 改为复用共享宽高比真相

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: VerticalFretboardGeometryStrategy.makeDrawingRect(bounds:configuration:), verticalWidthToHeightMultiplier(configuration:)
// 功能说明: 修改前竖向几何策略在本地重复维护一套宽高比公式，scene 层和平台层容易出现各算各的情况。
struct VerticalFretboardGeometryStrategy: FretboardGeometryStrategy {
    private static let minimumLayoutFactor: CGFloat = 0.01
    private static let minimumAspectRatio: CGFloat = 0.01

    private static func makeDrawingRect(
        bounds: CGRect,
        configuration: FretboardConfiguration
    ) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return .null
        }

        let widthToHeightMultiplier = verticalWidthToHeightMultiplier(
            configuration: configuration
        )
        guard widthToHeightMultiplier > 0 else {
            return .null
        }

        // ... 根据本地 widthToHeightMultiplier 继续推导 totalWidth / totalHeight ...
        return rect.isNull || rect.isEmpty ? .null : rect
    }

    private static func verticalWidthToHeightMultiplier(
        configuration: FretboardConfiguration
    ) -> CGFloat {
        let metrics = configuration.layoutMetrics
        let drawingWidthFactor = max(
            1 - (metrics.horizontalInsetRatio * 2),
            minimumLayoutFactor
        )
        let drawingHeightFactor = max(
            1 - (metrics.verticalInsetRatio * 2),
            minimumLayoutFactor
        )
        let resolvedCellWidthToHeightRatio = max(
            metrics.cellWidthToHeightRatio,
            minimumAspectRatio
        )
        let displayPositionCount = max(configuration.displayPositionCount, 1)
        let stringCount = max(configuration.stringCount, 1)

        return drawingHeightFactor
            / drawingWidthFactor
            * CGFloat(stringCount)
            / (CGFloat(displayPositionCount) * resolvedCellWidthToHeightRatio)
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: VerticalFretboardGeometryStrategy.makeDrawingRect(bounds:configuration:)
// 功能说明: 修改后竖向几何直接复用 configuration.widthToHeightMultiplier，scene 和平台 intrinsic 出口共享同一份宽高比真相。
struct VerticalFretboardGeometryStrategy: FretboardGeometryStrategy {
    private static func makeDrawingRect(
        bounds: CGRect,
        configuration: FretboardConfiguration
    ) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return .null
        }

        let widthToHeightMultiplier = configuration.widthToHeightMultiplier
        guard widthToHeightMultiplier > 0 else {
            return .null
        }

        let totalWidth: CGFloat
        let totalHeight: CGFloat
        let widthUsingFullHeight = bounds.height * widthToHeightMultiplier
        if widthUsingFullHeight <= bounds.width {
            totalWidth = widthUsingFullHeight
            totalHeight = bounds.height
        } else {
            totalWidth = bounds.width
            totalHeight = bounds.width / widthToHeightMultiplier
        }

        // ... 后续 inset、centering、drawingRect 计算保持不变 ...
        return rect.isNull || rect.isEmpty ? .null : rect
    }
}
```

## 修改 3：`iOSFretboardView` / `macOSFretboardView` 改为分模式 intrinsic

### iOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数/成员: intrinsicContentSize, configureView(), applyConfiguration(), resolvedIntrinsicHeight, invalidateIntrinsicSizeForCurrentWidthIfNeeded()
// 功能说明: 修改前 iOS 指板视图始终把“宽度驱动高度”当成唯一出口，vertical 模式没有“高度反推宽度”的 intrinsic 能力。
final class iOSFretboardView: UIView {
    private var lastMeasuredLayoutWidth: CGFloat?

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: resolvedIntrinsicHeight
        )
    }

    private func configureView() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyConfiguration()
    }

    private func applyConfiguration() {
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }

    private var resolvedIntrinsicHeight: CGFloat {
        guard bounds.width > 0 else {
            return configuration.preferredHeight
        }

        return configuration.resolvedHeight(forAvailableWidth: bounds.width)
    }

    private func invalidateIntrinsicSizeForCurrentWidthIfNeeded() {
        let currentWidth = bounds.width
        guard lastMeasuredLayoutWidth != currentWidth else {
            return
        }

        lastMeasuredLayoutWidth = currentWidth
        invalidateIntrinsicContentSize()
    }
}
```

### iOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数/成员: intrinsicContentSize, applyConfiguration(), resolvedIntrinsicHeight, resolvedIntrinsicWidth, updateContentPriorities(), invalidateIntrinsicSizeForCurrentPrimaryDimensionIfNeeded()
// 功能说明: 修改后 iOS 指板视图会按 displayMode 切换 intrinsic 主轴；horizontal 看宽度，vertical 看高度，并同步切换 Auto Layout 优先级。
final class iOSFretboardView: UIView {
    private var lastMeasuredPrimaryDimension: CGFloat?

    override var intrinsicContentSize: CGSize {
        switch configuration.displayMode {
        case .horizontal:
            return CGSize(
                width: UIView.noIntrinsicMetric,
                height: resolvedIntrinsicHeight
            )
        case .vertical:
            return CGSize(
                width: resolvedIntrinsicWidth,
                height: UIView.noIntrinsicMetric
            )
        }
    }

    private func applyConfiguration() {
        lastMeasuredPrimaryDimension = nil
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        updateContentPriorities()
        invalidateIntrinsicContentSize()
    }

    private var resolvedIntrinsicHeight: CGFloat {
        guard bounds.width > 0 else {
            return configuration.preferredHeight
        }

        return configuration.resolvedHeight(forAvailableWidth: bounds.width)
    }

    private var resolvedIntrinsicWidth: CGFloat {
        guard bounds.height > 0 else {
            return configuration.resolvedWidth(forAvailableHeight: configuration.preferredHeight)
        }

        return configuration.resolvedWidth(forAvailableHeight: bounds.height)
    }

    private func updateContentPriorities() {
        switch configuration.displayMode {
        case .horizontal:
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        case .vertical:
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.defaultLow, for: .vertical)
            setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        }
    }

    private func invalidateIntrinsicSizeForCurrentPrimaryDimensionIfNeeded() {
        let currentPrimaryDimension: CGFloat
        switch configuration.displayMode {
        case .horizontal:
            currentPrimaryDimension = bounds.width
        case .vertical:
            currentPrimaryDimension = bounds.height
        }

        guard lastMeasuredPrimaryDimension != currentPrimaryDimension else {
            return
        }

        lastMeasuredPrimaryDimension = currentPrimaryDimension
        invalidateIntrinsicContentSize()
    }
}
```

### macOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数/成员: intrinsicContentSize, configureView(), applyConfiguration(), resolvedIntrinsicHeight, setFrameSize(_:)
// 功能说明: 修改前 macOS 指板视图同样只有“宽度驱动高度”这一条 intrinsic 链路，竖向模式无法利用宿主高度反推宽度。
final class macOSFretboardView: NSView {
    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: resolvedIntrinsicHeight
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        let previousWidth = frame.size.width
        super.setFrameSize(newSize)

        guard previousWidth != newSize.width else {
            return
        }

        invalidateIntrinsicContentSize()
    }

    private func configureView() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyConfiguration()
    }
}
```

### macOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数/成员: intrinsicContentSize, applyConfiguration(), resolvedIntrinsicHeight, resolvedIntrinsicWidth, updateContentPriorities(), invalidateIntrinsicSizeForCurrentPrimaryDimensionIfNeeded(), setFrameSize(_:)
// 功能说明: 修改后 macOS 指板视图与 iOS 保持同一尺寸语义：horizontal 用宽度求高度，vertical 用高度求宽度，并按模式切换布局优先级。
final class macOSFretboardView: NSView {
    private var lastMeasuredPrimaryDimension: CGFloat?

    override var intrinsicContentSize: NSSize {
        switch configuration.displayMode {
        case .horizontal:
            return NSSize(
                width: NSView.noIntrinsicMetric,
                height: resolvedIntrinsicHeight
            )
        case .vertical:
            return NSSize(
                width: resolvedIntrinsicWidth,
                height: NSView.noIntrinsicMetric
            )
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateIntrinsicSizeForCurrentPrimaryDimensionIfNeeded()
    }

    private func applyConfiguration() {
        lastMeasuredPrimaryDimension = nil
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        updateContentPriorities()
        invalidateIntrinsicContentSize()
    }

    private var resolvedIntrinsicWidth: CGFloat {
        guard bounds.height > 0 else {
            return configuration.resolvedWidth(forAvailableHeight: configuration.preferredHeight)
        }

        return configuration.resolvedWidth(forAvailableHeight: bounds.height)
    }

    private func updateContentPriorities() {
        switch configuration.displayMode {
        case .horizontal:
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .vertical)
        case .vertical:
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentHuggingPriority(.defaultLow, for: .vertical)
            setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        }
    }

    private func invalidateIntrinsicSizeForCurrentPrimaryDimensionIfNeeded() {
        let currentPrimaryDimension: CGFloat
        switch configuration.displayMode {
        case .horizontal:
            currentPrimaryDimension = bounds.width
        case .vertical:
            currentPrimaryDimension = bounds.height
        }

        guard lastMeasuredPrimaryDimension != currentPrimaryDimension else {
            return
        }

        lastMeasuredPrimaryDimension = currentPrimaryDimension
        invalidateIntrinsicContentSize()
    }
}
```

## 修改 4：`iOSViewController` / `macOSViewController` 引入 `fretboardHostView`

### iOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSViewController.configureLayout(), applyFretboardDisplayState()
// 功能说明: 修改前 iOS 控制器直接把 fretboardView 挂在 contentView 上，并始终使用 leading / trailing 全宽约束，无法表达“竖向模式高驱动、宽度自适应且居中”。
final class iOSViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private func configureLayout() {
        // ... 省略上方按钮面板 / 五线谱约束 ...
        contentView.addSubview(fretboardView)

        NSLayoutConstraint.activate([
            fretboardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            fretboardView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            )
        ])
    }

    private func applyFretboardDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        updateLayoutIfNeeded()
    }
}
```

### iOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSViewController.configureLayout(), updateFretboardLayoutModeConstraints(), applyFretboardDisplayState(), Layout.verticalFretboardHostHeightRatio
// 功能说明: 修改后 iOS 控制器通过 fretboardHostView 承接竖向模式的外层高度，横向继续全宽铺开，竖向则改为固定 host 高度、指板水平居中且宽度不超过 host。
final class iOSViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let fretboardHostView = UIView()
    private var horizontalFretboardConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?

    private func configureLayout() {
        // ... 省略上方按钮面板 / 五线谱约束 ...
        contentView.addSubview(fretboardHostView)
        fretboardHostView.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide
        verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
            equalTo: safeArea.heightAnchor,
            multiplier: Layout.verticalFretboardHostHeightRatio
        )
        horizontalFretboardConstraints = [
            fretboardView.leadingAnchor.constraint(equalTo: fretboardHostView.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: fretboardHostView.trailingAnchor)
        ]
        verticalFretboardConstraints = [
            fretboardView.centerXAnchor.constraint(equalTo: fretboardHostView.centerXAnchor),
            fretboardView.widthAnchor.constraint(lessThanOrEqualTo: fretboardHostView.widthAnchor)
        ]

        NSLayoutConstraint.activate([
            fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            fretboardHostView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardHostView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            ),
            fretboardView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
            fretboardView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor)
        ])

        updateFretboardLayoutModeConstraints()
    }

    private func updateFretboardLayoutModeConstraints() {
        let isVertical = displayState.displayMode == .vertical
        verticalFretboardHostHeightConstraint?.isActive = isVertical
        horizontalFretboardConstraints.forEach { $0.isActive = !isVertical }
        verticalFretboardConstraints.forEach { $0.isActive = isVertical }
    }

    private func applyFretboardDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        updateFretboardLayoutModeConstraints()
        updateLayoutIfNeeded()
    }
}

private enum Layout {
    // 调整这个比例即可平衡竖向指板与按钮面板/五线谱的可视占比。
    static let verticalFretboardHostHeightRatio: CGFloat = 0.72
}
```

### macOS 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: macOSViewController.configureLayout(), applyFretboardDisplayState()
// 功能说明: 修改前 macOS 控制器同样直接把 fretboardView 绑在 contentView 上，只有全宽约束，没有竖向居中和 host 高度出口。
final class macOSViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let contentView = NSView()

    private func configureLayout() {
        // ... 省略上方按钮面板 / 五线谱约束 ...
        contentView.addSubview(fretboardView)

        NSLayoutConstraint.activate([
            fretboardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            fretboardView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            )
        ])
    }

    private func applyFretboardDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        updateLayoutIfNeeded()
    }
}
```

### macOS 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: macOSViewController.configureLayout(), updateFretboardLayoutModeConstraints(), applyFretboardDisplayState(), Layout.verticalFretboardHostHeightRatio
// 功能说明: 修改后 macOS 控制器与 iOS 采用同一套 host 方案，让竖向指板可以占满 host 高度、宽度自适应并居中显示。
final class macOSViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let fretboardHostView = NSView()
    private var horizontalFretboardConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardConstraints: [NSLayoutConstraint] = []
    private var verticalFretboardHostHeightConstraint: NSLayoutConstraint?

    private func configureLayout() {
        // ... 省略上方按钮面板 / 五线谱约束 ...
        contentView.addSubview(fretboardHostView)
        fretboardHostView.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide
        verticalFretboardHostHeightConstraint = fretboardHostView.heightAnchor.constraint(
            equalTo: safeArea.heightAnchor,
            multiplier: Layout.verticalFretboardHostHeightRatio
        )
        horizontalFretboardConstraints = [
            fretboardView.leadingAnchor.constraint(equalTo: fretboardHostView.leadingAnchor),
            fretboardView.trailingAnchor.constraint(equalTo: fretboardHostView.trailingAnchor)
        ]
        verticalFretboardConstraints = [
            fretboardView.centerXAnchor.constraint(equalTo: fretboardHostView.centerXAnchor),
            fretboardView.widthAnchor.constraint(lessThanOrEqualTo: fretboardHostView.widthAnchor)
        ]

        NSLayoutConstraint.activate([
            fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            fretboardHostView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardHostView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Layout.bottomInset
            ),
            fretboardView.topAnchor.constraint(equalTo: fretboardHostView.topAnchor),
            fretboardView.bottomAnchor.constraint(equalTo: fretboardHostView.bottomAnchor)
        ])

        updateFretboardLayoutModeConstraints()
    }

    private func updateFretboardLayoutModeConstraints() {
        let isVertical = displayState.displayMode == .vertical
        verticalFretboardHostHeightConstraint?.isActive = isVertical
        horizontalFretboardConstraints.forEach { $0.isActive = !isVertical }
        verticalFretboardConstraints.forEach { $0.isActive = isVertical }
    }

    private func applyFretboardDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        updateFretboardLayoutModeConstraints()
        updateLayoutIfNeeded()
    }
}

private enum Layout {
    // 调整这个比例即可平衡竖向指板与按钮面板/五线谱的可视占比。
    static let verticalFretboardHostHeightRatio: CGFloat = 0.72
}
```

## 验证情况

1. 已检查本阶段涉及文件的 IDE diagnostics：无新增报错。
2. 已执行 `swiftc -typecheck` 覆盖当前 `NoteMaster_Ver_1` 下全部 Swift 源文件：通过。
3. 未执行 `xcodebuild`：当前环境仍然是 Command Line Tools 目录，不是完整 Xcode toolchain。


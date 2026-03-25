# 20260325_205407_phase2_vertical_fretboard_platform_content_size_export

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_205407`
- 记录范围：竖向指板局部横滚方案的阶段2实施
- 本次目标：在 iOS / macOS 平台 `FretboardView` 层显式暴露“竖向内容尺寸”出口，并把竖向模式的 intrinsic width 接到阶段1新建的 shared 尺寸契约上
- 根因结论：阶段1虽然已经在 shared 层拆出了 `verticalContentLayout(forViewportHeight:)`，但平台 `FretboardView` 仍然通过旧的 `resolvedWidth(forAvailableHeight:)` 隐式取宽度，外部控制器无法直接读取“当前视口高度对应的整把竖向指板内容宽度”。如果不先把这个平台出口显式化，下一阶段控制器引入局部横向滚动时，仍然需要在控制器里重复拼装尺寸逻辑
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`

## 本次完成的修改

1. 在 `iOSFretboardView` 中新增 `verticalContentLayout` 与 `verticalContentSize`，把“当前竖向视口高度 -> 内容宽度”的平台尺寸出口显式暴露出来。
2. 在 `macOSFretboardView` 中同步新增同名尺寸出口，保持双平台结构对称。
3. 将 iOS / macOS 端竖向模式的 intrinsic width 都改为直接使用 `verticalContentSize.width`，不再通过旧的隐式宽度路径取值。
4. 将原先语义含混的 `resolvedIntrinsicWidth` 收口为 `resolvedVerticalViewportHeight`，明确它表达的是“当前可见竖向视口高度”，而不是“内容宽度”。
5. 保持横向模式现有 intrinsic 行为不变，也不触碰控制器约束和滚动容器，为阶段3单独引入局部横向滚动保留清晰边界。
6. 完成本轮相关文件的 lint 检查和 `swiftc -typecheck` 静态校验。

## 修改 1：iOS 平台显式暴露竖向内容尺寸出口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数/成员: iOSFretboardView.intrinsicContentSize / resolvedIntrinsicWidth
// 功能说明: 修改前 iOS 平台竖向模式的 intrinsic width 仍然直接调用旧的 resolvedWidth(forAvailableHeight:)，
// 外部拿不到“当前视口高度 -> 内容尺寸”的显式平台出口。
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

private var resolvedIntrinsicWidth: CGFloat {
    guard bounds.height > 0 else {
        return configuration.resolvedWidth(forAvailableHeight: configuration.preferredHeight)
    }

    return configuration.resolvedWidth(forAvailableHeight: bounds.height)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数/成员: iOSFretboardView.intrinsicContentSize / verticalContentLayout / verticalContentSize / resolvedVerticalViewportHeight
// 功能说明: 修改后 iOS 平台显式暴露竖向内容尺寸出口，并让 intrinsic width 直接取 verticalContentSize.width，
// 为下一阶段局部横向滚动容器直接消费内容宽度打基础。
override var intrinsicContentSize: CGSize {
    switch configuration.displayMode {
    case .horizontal:
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: resolvedIntrinsicHeight
        )
    case .vertical:
        return CGSize(
            width: verticalContentSize.width,
            height: UIView.noIntrinsicMetric
        )
    }
}

// 阶段 2 显式暴露“当前竖向视口高度 -> 内容宽度”的平台出口，供后续局部横向滚动直接消费。
var verticalContentLayout: FretboardConfiguration.VerticalContentLayout {
    guard configuration.displayMode == .vertical else {
        return .init(
            viewportHeight: 0,
            contentWidth: 0
        )
    }

    return configuration.verticalContentLayout(
        forViewportHeight: resolvedVerticalViewportHeight
    )
}

var verticalContentSize: CGSize {
    verticalContentLayout.contentSize
}

private var resolvedVerticalViewportHeight: CGFloat {
    guard bounds.height > 0 else {
        return configuration.preferredHeight
    }

    return bounds.height
}
```

## 修改 2：macOS 平台同步暴露竖向内容尺寸出口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数/成员: macOSFretboardView.intrinsicContentSize / resolvedIntrinsicWidth
// 功能说明: 修改前 macOS 平台和 iOS 一样，竖向模式只有隐式宽度推导，没有显式的内容尺寸出口。
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

private var resolvedIntrinsicWidth: CGFloat {
    guard bounds.height > 0 else {
        return configuration.resolvedWidth(forAvailableHeight: configuration.preferredHeight)
    }

    return configuration.resolvedWidth(forAvailableHeight: bounds.height)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数/成员: macOSFretboardView.intrinsicContentSize / verticalContentLayout / verticalContentSize / resolvedVerticalViewportHeight
// 功能说明: 修改后 macOS 平台以完全对称的方式暴露竖向内容尺寸出口，保证后续控制器接入横向滚动时不分平台走偏。
override var intrinsicContentSize: NSSize {
    switch configuration.displayMode {
    case .horizontal:
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: resolvedIntrinsicHeight
        )
    case .vertical:
        return NSSize(
            width: verticalContentSize.width,
            height: NSView.noIntrinsicMetric
        )
    }
}

// 阶段 2 显式暴露“当前竖向视口高度 -> 内容宽度”的平台出口，供后续局部横向滚动直接消费。
var verticalContentLayout: FretboardConfiguration.VerticalContentLayout {
    guard configuration.displayMode == .vertical else {
        return .init(
            viewportHeight: 0,
            contentWidth: 0
        )
    }

    return configuration.verticalContentLayout(
        forViewportHeight: resolvedVerticalViewportHeight
    )
}

var verticalContentSize: CGSize {
    verticalContentLayout.contentSize
}

private var resolvedVerticalViewportHeight: CGFloat {
    guard bounds.height > 0 else {
        return configuration.preferredHeight
    }

    return bounds.height
}
```

## 阶段2结果说明

- 这一轮仍然没有改控制器布局，也没有引入 `UIScrollView` / `NSScrollView` 版的指板局部横向滚动容器，所以页面行为暂时不会变化。
- 阶段2的作用是把“shared 尺寸真相”往平台 `FretboardView` 再推进一层：后续控制器不需要再自己根据 `bounds.height` 去猜内容宽度，可以直接读 `verticalContentLayout` / `verticalContentSize`。
- 绿色边界仍然画在 `fretboardView.bounds` 上，因此等阶段3把 `fretboardView` 放进局部横向滚动容器后，绿色边界就会代表真实指板内容矩形，而不是外层 viewport。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
   - `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
2. 执行 `swiftc -typecheck NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift NoteMaster_Ver_1/Shared/Fretboard/*.swift`，结果通过。
3. 结构上确认：
   - iOS / macOS 平台层都已具备显式的 `verticalContentLayout` / `verticalContentSize` 出口；
   - 竖向模式 intrinsic width 已统一转到新 shared 契约；
   - 横向模式原有 intrinsic 行为未被改动。

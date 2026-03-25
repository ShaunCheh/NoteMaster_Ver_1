# 20260325_204433_phase1_vertical_fretboard_shared_content_size_contract

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_204433`
- 记录范围：竖向指板局部横滚方案的阶段1实施
- 本次目标：在 shared 层把“竖向视口高度”和“竖向内容宽度”显式拆开，建立后续局部横向滚动要消费的统一尺寸契约
- 根因结论：当前 shared 层虽然已经有 `verticalTotalWidth(...)` / `resolvedWidth(forAvailableHeight:)`，但它们混合了承载“页面分配的可见高度”和“整把竖向指板内容宽度”两种语义。后续如果平台层直接引入局部横向滚动，就仍然需要自行猜测哪个值是 viewport、哪个值是 content，从而继续让布局真相分散在 shared 和平台层两边
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 本次完成的修改

1. 在 `FretboardConfiguration.LayoutMetrics` 中新增 `verticalContentWidth(...)` 与 `verticalContentHeight(...)`，显式表达竖向模式下“视口高度 -> 内容宽度”和“内容宽度 -> 内容高度”的双向尺寸换算。
2. 在 `FretboardConfiguration` 中新增 `VerticalContentLayout`、`verticalContentLayout(forViewportHeight:)`、`verticalContentWidth(forViewportHeight:)`、`verticalContentHeight(forContentWidth:)`，把竖向局部横滚阶段的 shared 尺寸真相收口到一个稳定出口。
3. 保留 `resolvedWidth(forAvailableHeight:)` / `resolvedHeight(forAvailableWidth:)` 兼容旧平台调用，但内部已经转调新契约，避免后续 shared / platform 再出现两套竖向尺寸语义。
4. 将 `FretboardValidation` 的竖向 fixture 改为直接依赖新尺寸契约，确保自动化验证与后续横滚改造站在同一条真相链路上。
5. 完成本轮相关文件的 lint 检查和 `swiftc -typecheck` 静态校验。

## 修改 1：在 shared 布局度量层显式补出“竖向内容宽度 / 内容高度”语义

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.LayoutMetrics.verticalTotalWidth(...) / verticalTotalHeight(...)
// 功能说明: 修改前 shared 层只有 verticalTotalWidth / verticalTotalHeight 两个乘子换算函数，
// 但没有显式表达“viewport height”和“content width”的业务语义，调用方只能从函数名和上下文猜测。
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.LayoutMetrics.verticalContentWidth(...) / verticalContentHeight(...)
// 功能说明: 修改后 shared 层显式提供“给定竖向视口高度时，整把指板内容需要的宽度”
// 和“给定竖向内容宽度时，保持同一比例所需的内容高度”两个语义化出口，
// 后续平台层引入局部横向滚动时可以直接消费，不再猜测乘子代表的业务含义。
func verticalContentWidth(
    forViewportHeight viewportHeight: CGFloat,
    displayPositionCount: Int,
    stringCount: Int
) -> CGFloat {
    verticalTotalWidth(
        forAvailableHeight: viewportHeight,
        displayPositionCount: displayPositionCount,
        stringCount: stringCount
    )
}

func verticalContentHeight(
    forContentWidth contentWidth: CGFloat,
    displayPositionCount: Int,
    stringCount: Int
) -> CGFloat {
    verticalTotalHeight(
        forAvailableWidth: contentWidth,
        displayPositionCount: displayPositionCount,
        stringCount: stringCount
    )
}
```

## 修改 2：在 `FretboardConfiguration` 中建立阶段1新的 shared 尺寸契约

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.resolvedHeight(...) / resolvedWidth(...)
// 功能说明: 修改前 shared 配置层没有“竖向内容布局”对象，调用方只能直接使用 resolvedWidth / resolvedHeight；
// 这让旧平台布局和后续横滚方案共用同一个宽高出口，语义上依然混杂。
var displayPositionCount: Int {
    maxFret + 1
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.VerticalContentLayout / verticalContentLayout(...) / resolvedHeight(...) / resolvedWidth(...)
// 功能说明: 修改后 shared 层新增 VerticalContentLayout 作为竖向局部横滚阶段的尺寸真相对象；
// 页面负责给出 viewportHeight，shared 统一派生 contentWidth。旧的 resolvedWidth / resolvedHeight 仍保留，
// 但内部已经转到新语义，避免兼容阶段出现两套竖向尺寸计算口径。
struct VerticalContentLayout: Equatable, Sendable {
    var viewportHeight: CGFloat
    var contentWidth: CGFloat

    var contentSize: CGSize {
        CGSize(
            width: contentWidth,
            height: viewportHeight
        )
    }
}

var displayPositionCount: Int {
    maxFret + 1
}

func verticalContentLayout(
    forViewportHeight viewportHeight: CGFloat
) -> VerticalContentLayout {
    let resolvedViewportHeight = max(viewportHeight, 0)
    return VerticalContentLayout(
        viewportHeight: resolvedViewportHeight,
        contentWidth: layoutMetrics.verticalContentWidth(
            forViewportHeight: resolvedViewportHeight,
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    )
}

func verticalContentWidth(
    forViewportHeight viewportHeight: CGFloat
) -> CGFloat {
    verticalContentLayout(forViewportHeight: viewportHeight).contentWidth
}

func verticalContentHeight(
    forContentWidth contentWidth: CGFloat
) -> CGFloat {
    layoutMetrics.verticalContentHeight(
        forContentWidth: contentWidth,
        displayPositionCount: displayPositionCount,
        stringCount: stringCount
    )
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
        // 兼容当前平台层旧调用；后续竖向局部横滚新链路应优先使用 verticalContentHeight / Layout。
        return verticalContentHeight(forContentWidth: width)
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
        // 兼容当前平台层旧调用；后续竖向局部横滚新链路应优先使用 verticalContentWidth / Layout。
        return verticalContentWidth(forViewportHeight: height)
    }
}
```

## 修改 3：让 shared 自动化验证开始依赖新尺寸契约

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.verticalFixture(...)
// 功能说明: 修改前竖向夹具直接调用 resolvedWidth(forAvailableHeight:)，
// 这意味着验证链路仍然走旧的“高度 -> 宽度”兼容出口，没有明确站在新的 content layout 契约上。
static func verticalFixture(
    name: String,
    instrument: InstrumentType,
    widthOverride: CGFloat? = nil
) -> FretboardValidationFixture {
    let configuration = FretboardConfiguration(
        displayMode: .vertical,
        tuning: .standard(for: instrument),
        maxFret: 12
    )
    let resolvedWidth = configuration.resolvedWidth(forAvailableHeight: verticalFixtureHeight)
    let width = widthOverride ?? resolvedWidth

    return FretboardValidationFixture(
        name: name,
        configuration: configuration,
        bounds: CGRect(
            origin: .zero,
            size: CGSize(
                width: width,
                height: verticalFixtureHeight
            )
        )
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.verticalFixture(...)
// 功能说明: 修改后竖向夹具显式通过 verticalContentLayout(forViewportHeight:) 取得内容宽度与内容尺寸，
// 让自动化验证和后续局部横滚平台实现共享同一条尺寸真相链路。
static func verticalFixture(
    name: String,
    instrument: InstrumentType,
    widthOverride: CGFloat? = nil
) -> FretboardValidationFixture {
    let configuration = FretboardConfiguration(
        displayMode: .vertical,
        tuning: .standard(for: instrument),
        maxFret: 12
    )
    let contentLayout = configuration.verticalContentLayout(
        forViewportHeight: verticalFixtureHeight
    )
    let width = widthOverride ?? contentLayout.contentWidth

    return FretboardValidationFixture(
        name: name,
        configuration: configuration,
        bounds: CGRect(
            origin: .zero,
            size: CGSize(
                width: width,
                height: contentLayout.contentSize.height
            )
        )
    )
}
```

## 阶段1结果说明

- 这一轮还没有改平台 `FretboardView`、控制器约束或滚动容器，所以 UI 行为暂时不会变化。
- 阶段1的价值在于：后续平台层不再需要从 `resolvedWidth(forAvailableHeight:)` 这类兼容接口里反推“这是 viewport 还是 content”，而是可以直接消费 `verticalContentLayout(forViewportHeight:)` 作为竖向局部横滚的 shared 真相源。
- 同时，旧接口仍然保留，因此当前代码不会因为阶段1而提前破坏现有平台层。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
   - `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
2. 执行 `swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift`，结果通过。
3. 结构上确认：
   - shared 层已经具备 `viewportHeight -> contentWidth` 的显式竖向尺寸真相；
   - 验证夹具已经切换到新契约；
   - 旧平台调用仍然通过兼容接口工作。

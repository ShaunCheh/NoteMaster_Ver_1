# 20260325_213558_phase5_vertical_geometry_full_height

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_213558`
- 记录范围：竖向指板横滚方案的阶段5实施
- 本次目标：校正 shared 竖向几何，让竖向模式下的指板内容优先吃满组件高度，收掉绿色边界内残留的上下 letterbox 根因
- 根因结论：阶段1到阶段4虽然已经把“页面给定竖向视口高度 -> shared 反推出内容宽度 -> 平台局部横向滚动容器消费内容宽度”这条链路打通了，但 shared 层还残留两处旧语义：
  - `FretboardConfiguration.LayoutMetrics.verticalWidthToHeightMultiplier(...)` 仍把上下 inset 一并折进“竖向内容宽度倍率”，导致平台即使给了足够宽的 `bounds`，shared 推出来的“满高内容宽度”也偏大；
  - `VerticalFretboardGeometryStrategy.makeDrawingRect(...)` 仍按“整图塞进 bounds 后再居中”的方式装箱，并且继续在竖向模式下额外吃 `verticalInsetRatio`，于是内容在宽度充足时仍会保留不必要的上下留白
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 本次完成的修改

1. 重写竖向内容宽高倍率的含义，让“竖向内容宽度”真正表达“当内容吃满全部 viewport 高度时需要的总宽度”，不再把上下 inset 混入该真相。
2. 重写 `VerticalFretboardGeometryStrategy.makeDrawingRect(...)` 的装箱逻辑：当 `bounds.width` 已经足够承载满高内容时，优先固定 `totalHeight = bounds.height`；只有当宽度真的不足时，才回退到“按宽度反推高度”的分支。
3. 删除竖向几何里对 `verticalInsetRatio` 的额外消费，让最终 `drawingRect` 在满高分支下真正贴住 `bounds` 的上下边界。
4. 扩展共享自动化验证：新增“高度驱动场景必须吃满 `bounds.height`”断言，并把 `vertical-guitar6-width-constrained` 夹具宽度从 `220` 收紧到 `120`，确保验证能真实覆盖“宽度不足”的退化路径。

## 修改 1：竖向内容宽度倍率从“包含上下 inset 的总高”改为“高度优先吃满视口”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.LayoutMetrics.verticalWidthToHeightMultiplier(displayPositionCount:stringCount:)
// 功能说明: 修改前竖向内容宽高倍率沿用了 drawingHeightFactor / drawingWidthFactor 共同折算的旧语义，
// 这会把上下 inset 也算进“竖向内容宽度真相”，从而让平台宽度已经足够时仍然保留满高所不需要的额外宽度。
func verticalWidthToHeightMultiplier(
    displayPositionCount: Int,
    stringCount: Int
) -> CGFloat {
    let resolvedDisplayPositionCount = max(displayPositionCount, 1)
    let resolvedStringCount = max(stringCount, 1)
    // vertical 模式沿用同一套“长:短”比例真相，但长边改为品位方向（y 轴）；
    // 因此这里需要把 horizontal 的 width/height 比例翻转到 width/height 的倒数。
    return drawingHeightFactor
        / drawingWidthFactor
        * CGFloat(resolvedStringCount)
        / (CGFloat(resolvedDisplayPositionCount) * resolvedCellWidthToHeightRatio)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.LayoutMetrics.verticalWidthToHeightMultiplier(displayPositionCount:stringCount:)
// 功能说明: 修改后竖向内容宽度明确表达“内容吃满整个 viewport 高度时所需的总宽度”；
// 这里保留左右 inset，但不再把上下 inset 折进倍率，避免 shared 自己继续制造满高场景下的额外纵向留白。
func verticalWidthToHeightMultiplier(
    displayPositionCount: Int,
    stringCount: Int
) -> CGFloat {
    let resolvedDisplayPositionCount = max(displayPositionCount, 1)
    let resolvedStringCount = max(stringCount, 1)
    // 竖向局部横滚语义下，绿色边界代表真实内容矩形：
    // 指板内容应优先吃满整个可见高度，因此这里只保留左右 inset，
    // 不再把上下 inset 也折进 width/height 倍率，否则内容宽度充足时仍会保留上下 letterbox。
    return CGFloat(resolvedStringCount)
        / (drawingWidthFactor
            * CGFloat(resolvedDisplayPositionCount)
            * resolvedCellWidthToHeightRatio)
}
```

## 修改 2：竖向几何装箱逻辑改为“高度优先”，并移除额外上下 inset

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: VerticalFretboardGeometryStrategy.makeDrawingRect(bounds:configuration:)
// 功能说明: 修改前竖向几何仍按 width/height 双向 fit 选择 totalRect，
// 然后继续套一层 verticalInset；即使 bounds 已经足够宽，也会把内容高度缩短后再垂直居中。
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

    guard totalWidth > 0, totalHeight > 0 else {
        return .null
    }

    let metrics = configuration.layoutMetrics
    let horizontalInset = min(
        max(totalWidth * metrics.horizontalInsetRatio, 0),
        totalWidth / 2
    )
    let verticalInset = min(
        max(totalHeight * metrics.verticalInsetRatio, 0),
        totalHeight / 2
    )
    let drawingWidth = totalWidth - (horizontalInset * 2)
    let drawingHeight = totalHeight - (verticalInset * 2)
    guard drawingWidth > 0, drawingHeight > 0 else {
        return .null
    }

    let totalRect = CGRect(
        x: bounds.midX - (totalWidth / 2),
        y: bounds.midY - (totalHeight / 2),
        width: totalWidth,
        height: totalHeight
    )
    let rect = CGRect(
        x: totalRect.minX + horizontalInset,
        y: totalRect.minY + verticalInset,
        width: drawingWidth,
        height: drawingHeight
    )

    return rect.isNull || rect.isEmpty ? .null : rect
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift
// 函数/成员: VerticalFretboardGeometryStrategy.contentFitTolerance + makeDrawingRect(bounds:configuration:)
// 功能说明: 修改后 shared 几何先根据“满高内容宽度”判断当前 bounds 是否足够宽；
// 宽度充足时直接固定 totalHeight = bounds.height，让 drawingRect 贴住上下边界；宽度不足时才回退到按宽度反推高度的旧退化路径。
private static let contentFitTolerance: CGFloat = 0.5

private static func makeDrawingRect(
    bounds: CGRect,
    configuration: FretboardConfiguration
) -> CGRect {
    guard bounds.width > 0, bounds.height > 0 else {
        return .null
    }

    let fullHeightContentWidth = configuration.verticalContentWidth(
        forViewportHeight: bounds.height
    )
    guard fullHeightContentWidth > 0 else {
        return .null
    }

    let totalWidth: CGFloat
    let totalHeight: CGFloat
    if bounds.width + contentFitTolerance >= fullHeightContentWidth {
        totalWidth = min(fullHeightContentWidth, bounds.width)
        totalHeight = bounds.height
    } else {
        totalWidth = bounds.width
        totalHeight = configuration.verticalContentHeight(
            forContentWidth: bounds.width
        )
    }

    guard totalWidth > 0, totalHeight > 0 else {
        return .null
    }

    let metrics = configuration.layoutMetrics
    let horizontalInset = min(
        max(totalWidth * metrics.horizontalInsetRatio, 0),
        totalWidth / 2
    )
    let drawingWidth = totalWidth - (horizontalInset * 2)
    guard drawingWidth > 0 else {
        return .null
    }

    let totalRect = CGRect(
        x: bounds.midX - (totalWidth / 2),
        y: bounds.midY - (totalHeight / 2),
        width: totalWidth,
        height: totalHeight
    )
    let rect = CGRect(
        x: totalRect.minX + horizontalInset,
        y: totalRect.minY,
        width: drawingWidth,
        height: totalRect.height
    )

    return rect.isNull || rect.isEmpty ? .null : rect
}
```

## 修改 3：共享验证补齐“满高场景必须吃满高度”的断言，并收紧宽度受限夹具

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.makeFixtures() / validate(_:)
// 功能说明: 修改前自动化验证只检查比例、轴向、命中和 bounds containment，
// 但没有验证“当 bounds 已经足够宽时 drawingRect 是否真的吃满高度”；同时 width-constrained 夹具宽度偏宽，退化分支覆盖不够尖锐。
static func makeFixtures() -> [FretboardValidationFixture] {
    [
        // ... other fixtures ...
        verticalFixture(
            name: "vertical-guitar6-width-constrained",
            instrument: .guitar6,
            widthOverride: 220
        )
    ]
}

static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
    let sceneBuilder = FretboardSceneBuilder(configuration: fixture.configuration)
    let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
    var issues: [FretboardValidationIssue] = []

    // ... record helper ...

    validateBoundsContainment(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateSceneCounts(
        scene: scene,
        fixture: fixture,
        record: record
    )
    // ... other validations ...
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.makeFixtures() / validate(_:) / validateVerticalHeightConsumption(scene:fixture:record:)
// 功能说明: 修改后共享验证新增“满高场景必须吃满 bounds.height”的专用断言，
// 并把 width-constrained 夹具收紧到更小宽度，让退化分支与满高分支都能被自动化测试稳定覆盖。
static func makeFixtures() -> [FretboardValidationFixture] {
    [
        // ... other fixtures ...
        verticalFixture(
            name: "vertical-guitar6-width-constrained",
            instrument: .guitar6,
            widthOverride: 120
        )
    ]
}

static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
    let sceneBuilder = FretboardSceneBuilder(configuration: fixture.configuration)
    let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
    var issues: [FretboardValidationIssue] = []

    // ... record helper ...

    validateBoundsContainment(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateVerticalHeightConsumption(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateSceneCounts(
        scene: scene,
        fixture: fixture,
        record: record
    )
    // ... other validations ...
}

static func validateVerticalHeightConsumption(
    scene: FretboardScene,
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    guard fixture.configuration.displayMode == .vertical else {
        return
    }

    let fullHeightContentWidth = fixture.configuration.verticalContentWidth(
        forViewportHeight: fixture.bounds.height
    )
    guard fixture.bounds.width + tolerance >= fullHeightContentWidth else {
        return
    }

    if !approximatelyEqual(scene.drawingRect.minY, fixture.bounds.minY)
        || !approximatelyEqual(scene.drawingRect.maxY, fixture.bounds.maxY) {
        record("vertical 高度驱动场景下 drawingRect 未优先吃满 bounds.height。")
    }
}
```

## 修改结果说明

- 经过这次阶段5收口后，shared 层对“竖向内容矩形”的定义已经与阶段1到阶段4的平台局部横向滚动容器对齐：
  - 页面/宿主继续决定可见高度；
  - shared 根据这个高度推导真正的内容宽度；
  - 当平台传回来的 `bounds` 已经等于“内容宽 x 视口高”时，shared 几何不再自行再做一层竖向压缩与居中。
- 这次没有改动 marker、label anchor、hit-test 计算骨架，也没有再碰平台控制器约束链路；重点仅限于 shared 的尺寸语义和几何装箱逻辑。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
   - `NoteMaster_Ver_1/Shared/Fretboard/VerticalFretboardGeometryStrategy.swift`
   - `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
2. `swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift`：通过。
3. 命令行执行 `FretboardValidationRunner.run(platform: .commandLine)`：`PASS`。
4. 自动化夹具通过数量：`7 / 7`。
5. 通过夹具：
   - `horizontal-guitar6-reference`
   - `horizontal-bass4-reference`
   - `horizontal-bass5-reference`
   - `vertical-guitar6-height-driven`
   - `vertical-bass4-height-driven`
   - `vertical-bass5-height-driven`
   - `vertical-guitar6-width-constrained`

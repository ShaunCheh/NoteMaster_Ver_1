# 20260325_151537_vertical_cell_aspect_ratio_root_cause_fix

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260325_151537`
- 记录范围：竖向模式品格长宽比根因修正
- 本次目标：从共享尺寸真相层修正 vertical 模式品格比例，确保横向与竖向使用同一套“长:短”比例真相，只是长边主轴互换

## 问题现象与根因

1. 问题现象：在 vertical 模式下，品格虽然已经按“品位沿 y 轴、弦沿 x 轴”布局，但格子的长边仍偏向 `x` 轴，看起来更像横向模式被旋转了坐标，而不是主轴真正翻转。
2. 根因：`FretboardConfiguration.LayoutMetrics.verticalWidthToHeightMultiplier(...)` 沿用了 horizontal 的 `cellWidthToHeightRatio` 乘法方向，导致 vertical 模式下仍在维持“宽大于高”的格子比例。
3. 修正原则：不做局部绘制补丁，而是直接修正共享尺寸真相；同时补强验证器，确保后续不会再把 vertical 的长短边方向算反。

## 本次完成的修改

1. 修正 `FretboardConfiguration.LayoutMetrics.verticalWidthToHeightMultiplier(...)`，把 vertical 模式的 `width / height` 比例改为 horizontal 真相的倒数。
2. 在 `FretboardValidation` 中新增 `validateCellAspectRatio(...)`，显式校验 horizontal / vertical 两种模式下的品格比例。
3. 在 `FretboardValidation.validateAxisOrientation(...)` 中新增“长边主轴”断言，要求 horizontal 长边沿 `x`、vertical 长边沿 `y`。
4. 重新执行共享层 fixture 验证，确认根因修正后自动化结果仍为 `PASS`。

## 修改 1：从共享尺寸真相层修正 vertical 模式的长宽比公式

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.LayoutMetrics.verticalWidthToHeightMultiplier(displayPositionCount:stringCount:)
// 功能说明: 修改前 vertical 直接复用 horizontal 的 width/height 乘法方向，导致竖向模式下 cell 仍然更宽而不是更高。
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.LayoutMetrics.verticalWidthToHeightMultiplier(displayPositionCount:stringCount:)
// 功能说明: 修改后 vertical 沿用同一套“长:短”比例真相，但把长边切到品位方向（y 轴）；因此 width/height 必须使用 horizontal 比例的倒数。
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

## 修改 2：验证器新增 `validateCellAspectRatio(...)`，直接校验横竖模式的品格比例

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.validate(_:), validateCellAndAnchorMapping(...), validateAxisOrientation(...)
// 功能说明: 修改前验证器会检查 scene 数量、轴向与命中，但不会显式验证 cell 的 width/height 比例是否符合横竖模式预期。
static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
    let sceneBuilder = FretboardSceneBuilder(configuration: fixture.configuration)
    let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
    var issues: [FretboardValidationIssue] = []

    // ... 省略 record 与 drawingRect 校验 ...

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
    validateCellAndAnchorMapping(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateAxisOrientation(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateMarkerPlacements(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateHitTesting(
        scene: scene,
        fixture: fixture,
        sceneBuilder: sceneBuilder,
        record: record
    )

    return issues
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.validate(_:), validateCellAspectRatio(...)
// 功能说明: 修改后验证器会显式核对每个 cell 的 width/height 比例；horizontal 期望等于配置真相，vertical 期望等于该比例的倒数。
static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
    let sceneBuilder = FretboardSceneBuilder(configuration: fixture.configuration)
    let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
    var issues: [FretboardValidationIssue] = []

    // ... 省略 record 与 drawingRect 校验 ...

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
    validateCellAndAnchorMapping(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateCellAspectRatio(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateAxisOrientation(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateMarkerPlacements(
        scene: scene,
        fixture: fixture,
        record: record
    )
    validateHitTesting(
        scene: scene,
        fixture: fixture,
        sceneBuilder: sceneBuilder,
        record: record
    )

    return issues
}

static func validateCellAspectRatio(
    scene: FretboardScene,
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    let ratio = max(
        fixture.configuration.layoutMetrics.cellWidthToHeightRatio,
        tolerance
    )
    let expectedWidthToHeightRatio: CGFloat

    switch fixture.configuration.displayMode {
    case .horizontal:
        expectedWidthToHeightRatio = ratio
    case .vertical:
        expectedWidthToHeightRatio = 1 / ratio
    }

    for cell in scene.cellFrames {
        guard cell.frame.width > 0, cell.frame.height > 0 else {
            record("cell(\(cell.stringIndex), \(cell.fret)) 的尺寸非法。")
            continue
        }

        let actualWidthToHeightRatio = cell.frame.width / cell.frame.height
        if !approximatelyEqual(actualWidthToHeightRatio, expectedWidthToHeightRatio) {
            record(
                "cell(\(cell.stringIndex), \(cell.fret)) 的 width/height 比例错误，期望 \(expectedWidthToHeightRatio)，实际 \(actualWidthToHeightRatio)。"
            )
            break
        }
    }
}
```

## 修改 3：验证器新增“长边主轴”断言，防止 vertical 再次算反

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.validateAxisOrientation(...)
// 功能说明: 修改前这里只检查弦线/品位线方向与坐标递增关系，没有直接约束 cell 的长边到底沿 x 还是沿 y。
static func validateAxisOrientation(
    scene: FretboardScene,
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    let configuration = fixture.configuration
    let orderedStrings = scene.stringSegments.sorted { $0.stringIndex < $1.stringIndex }
    let orderedFrets = scene.fretSegments.sorted { $0.fret < $1.fret }

    switch configuration.displayMode {
    case .horizontal:
        if !isStrictlyIncreasing(orderedStrings.map { midpoint(of: $0).y }) {
            record("horizontal 模式下弦序没有按低音到高音沿 y 轴递增。")
        }
        if !isStrictlyIncreasing(orderedFrets.map(\.start.x)) {
            record("horizontal 模式下品位没有沿 x 轴递增。")
        }
    case .vertical:
        if !isStrictlyIncreasing(orderedStrings.map { midpoint(of: $0).x }) {
            record("vertical 模式下弦序没有按低音到高音沿 x 轴递增。")
        }
        if !isStrictlyIncreasing(orderedFrets.map(\.start.y)) {
            record("vertical 模式下品位没有沿 y 轴递增。")
        }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.validateAxisOrientation(...)
// 功能说明: 修改后除了检查弦/品位轴向，还要求 horizontal 的 cell 长边沿 x、vertical 的 cell 长边沿 y，直接防止主轴翻转回归。
static func validateAxisOrientation(
    scene: FretboardScene,
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    let configuration = fixture.configuration
    let orderedStrings = scene.stringSegments.sorted { $0.stringIndex < $1.stringIndex }
    let orderedFrets = scene.fretSegments.sorted { $0.fret < $1.fret }

    switch configuration.displayMode {
    case .horizontal:
        if !isStrictlyIncreasing(orderedStrings.map { midpoint(of: $0).y }) {
            record("horizontal 模式下弦序没有按低音到高音沿 y 轴递增。")
        }
        if !isStrictlyIncreasing(orderedFrets.map(\.start.x)) {
            record("horizontal 模式下品位没有沿 x 轴递增。")
        }

        if let firstCell = scene.cellFrames.first,
           !(firstCell.frame.width > firstCell.frame.height + tolerance) {
            record("horizontal 模式下 cell 长边应沿 x 轴。")
        }
    case .vertical:
        if !isStrictlyIncreasing(orderedStrings.map { midpoint(of: $0).x }) {
            record("vertical 模式下弦序没有按低音到高音沿 x 轴递增。")
        }
        if !isStrictlyIncreasing(orderedFrets.map(\.start.y)) {
            record("vertical 模式下品位没有沿 y 轴递增。")
        }

        if let firstCell = scene.cellFrames.first,
           !(firstCell.frame.height > firstCell.frame.width + tolerance) {
            record("vertical 模式下 cell 长边应沿 y 轴。")
        }
    }
}
```

## 验证情况

1. 已检查本次涉及文件的 IDE diagnostics：无新增报错。
2. 已执行 `swiftc -typecheck` 覆盖当前 `NoteMaster_Ver_1` 下全部 Swift 源文件：通过。
3. 已重新执行共享层 fixture 验证，输出摘要如下：

```shell
# 文件路径: 无（命令行验证输出）
# 函数/成员: FretboardValidationRunner.run(platform:)
# 功能说明: 重新执行共享层验证器，确认 vertical 长宽比根因修正后，所有 fixture 仍然通过。
[FretboardValidation][commandLine] automated=PASS fixtures=7
通过夹具: horizontal-guitar6-reference, horizontal-bass4-reference, horizontal-bass5-reference, vertical-guitar6-height-driven, vertical-bass4-height-driven, vertical-bass5-height-driven, vertical-guitar6-width-constrained
自动化问题:
- 无
手工回归清单:
1. 切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。
2. 点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。
3. 在 vertical 模式下改变窗口或设备高度，确认指板宽度会自适应变化并保持水平居中。
4. 命令行只能覆盖共享层自动化夹具；iOS 滚动与 macOS live resize 需在 App 运行时手工回归。
```

## 修正后的结论

1. `horizontal` 现在仍保持 `cell.width / cell.height = cellWidthToHeightRatio`。
2. `vertical` 现在改为 `cell.height / cell.width = cellWidthToHeightRatio`，等价于 `cell.width / cell.height = 1 / cellWidthToHeightRatio`。
3. 因此横向与竖向模式现在使用的是同一套“长:短”比例真相，只是长边主轴分别落在 `x` 与 `y`。


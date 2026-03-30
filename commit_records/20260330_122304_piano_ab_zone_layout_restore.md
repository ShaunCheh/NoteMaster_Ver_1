# 20260330_122304_piano_ab_zone_layout_restore

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_122304`
- 记录范围：修正钢琴键盘单行 `A/B/C` 区域的视觉布局误解，将先前“同一顶栏里的横向三分”恢复为“`A` 顶部按钮条 + `B` 下方刻度条 + `C` 琴键区”的上下三层关系
- 本次目标：只修改 `Shared/Piano` 的配置、scene、geometry、layer 绘制与 validation 预期；不改交互 reducer 的语义，不改 iOS/macOS 平台壳层接口
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoScene.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次结论

- 修改前，`A` 区左右按钮和 `B` 区刻度被放进了同一个 `controlStripRect`，视觉上等价于“顶栏横向三分”
- 修改后，顶部控制区仍然存在，但其内部被恢复为上下两层：
- 第一层是 `A` 区按钮条，左右按钮都属于这条顶栏
- 第二层是 `B` 区刻度条，宽度覆盖整行
- 第三层是 `C` 区琴键区，整体向下顺延
- 这次修正只改了几何与绘制关系，没有改变：
- `A` 区按钮点击后步进一个半音并吸附的语义
- `B` 区拖动控制滚动、离开 `B` 即停止的语义
- `C` 区滑音预览、不触发滚动的语义

## 修改前的问题

- 修改前的核心偏差不是 hit zone 混淆，而是视觉布局理解错了
- 在 Shared 几何里，`buttonLeftRect`、`scaleRect`、`buttonRightRect` 都由同一个 `controlStripRect` 横向切分出来
- 在 Shared 绘制里，又把这个 `controlStripRect` 整块统一填色，所以最终看起来就像左右箭头被画进了 `B` 区

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift
// 函数名: makeRowScene(rowIndex:rowState:bounds:)
// 功能说明: 修改前直接从同一个 controlStripRect 中切出左右按钮和中间刻度，版式上属于横向三分。
let controlStripRect = PianoLayoutMath.controlStripRect(
    for: rowFrame,
    configuration: configuration
)
let buttonLeftRect = PianoLayoutMath.buttonLeftRect(
    in: controlStripRect,
    configuration: configuration
)
let buttonRightRect = PianoLayoutMath.buttonRightRect(
    in: controlStripRect,
    configuration: configuration
)
let scaleRect = PianoLayoutMath.scaleRect(
    in: controlStripRect,
    configuration: configuration
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: drawControlStrip(in:)
// 功能说明: 修改前先整块填充 controlStripRect，再在这块统一背景中画按钮和刻度，视觉上会把 A 区并进 B 区顶栏。
func drawControlStrip(in context: CGContext) {
    guard !scene.controlStripRect.isNull, !scene.controlStripRect.isEmpty else {
        return
    }

    context.saveGState()
    context.setFillColor(PianoLayerPalette.controlStripFill)
    context.fill(scene.controlStripRect)
    context.restoreGState()

    drawButton(
        direction: .left,
        rect: scene.buttonLeftRect,
        in: context
    )
    drawButton(
        direction: .right,
        rect: scene.buttonRightRect,
        in: context
    )
    drawScaleArea(in: context)
}
```

## 修改 1：配置层从“单层顶部区”改为“A+B 两层控制区”

### 修改前

- 修改前，`scaleAreaHeight` 既承担 `B` 区刻度高度，又被拿来作为整个顶部控制区高度
- 这会导致 `keysRect` 只下移一层高度，无法表达“按钮条在上、刻度条在下”的关系

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: rowHeight 注释, resolvedScaleAreaHeight, keyAreaHeight
// 功能说明: 修改前把顶部 A/B 控制区整体都压缩进单个 scaleAreaHeight 中。
var whiteKeyWidth: CGFloat
// rowHeight 表示单行总高度；顶部 A/B 区高度由 scaleAreaHeight 单独控制。
var rowHeight: CGFloat

var resolvedScaleAreaHeight: CGFloat {
    min(max(scaleAreaHeight, 0), resolvedRowHeight)
}

var keyAreaHeight: CGFloat {
    max(resolvedRowHeight - resolvedScaleAreaHeight, 0)
}
```

### 修改后

- 新增 `resolvedButtonStripHeight`
- 新增 `resolvedControlAreaHeight`
- `keyAreaHeight` 不再只减去 `scaleAreaHeight`，而是减去整块 `A+B` 控制区高度
- 这样就能在不引入新配置字段的前提下，把现有 `scaleAreaHeight` 扩展成“上下两条控制区”的基础尺寸

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: resolvedButtonStripHeight, resolvedControlAreaHeight, keyAreaHeight
// 功能说明: 先求 A 区按钮条高度，再把 A+B 控制区总高度提供给 geometry 使用，从而把 C 区整体下移到正确位置。
var whiteKeyWidth: CGFloat
// rowHeight 表示单行总高度；顶部 A/B 区按上下两条控制区布局。
var rowHeight: CGFloat

var resolvedScaleAreaHeight: CGFloat {
    min(max(scaleAreaHeight, 0), resolvedRowHeight)
}

var resolvedButtonStripHeight: CGFloat {
    min(
        resolvedScaleAreaHeight,
        max(resolvedRowHeight - resolvedScaleAreaHeight, 0)
    )
}

var resolvedControlAreaHeight: CGFloat {
    resolvedButtonStripHeight + resolvedScaleAreaHeight
}

var keyAreaHeight: CGFloat {
    max(resolvedRowHeight - resolvedControlAreaHeight, 0)
}
```

## 修改 2：Scene 显式拆出 `buttonStripRect`

### 修改前

- 修改前的 `RowScene` 只有：
- 总控制区 `controlStripRect`
- 左右按钮 `buttonLeftRect` / `buttonRightRect`
- 刻度区 `scaleRect`
- 没有一个单独表示 `A` 区整条顶栏的字段
- 这使得 row layer 只能拿 `controlStripRect` 当顶部统一背景

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoScene.swift
// 函数名/符号: PianoScene.RowScene.empty, PianoScene.RowScene.localizedToRowBounds()
// 功能说明: 修改前没有 buttonStripRect，只有总控制区和各子块 rect。
static let empty = RowScene(
    rowIndex: 0,
    frame: .null,
    controlStripRect: .null,
    buttonLeftRect: .null,
    buttonRightRect: .null,
    scaleRect: .null,
    keysRect: .null,
    whiteKeys: [],
    blackKeys: [],
    scaleMarkers: []
)

var rowIndex: Int
var frame: CGRect
var controlStripRect: CGRect
var buttonLeftRect: CGRect
var buttonRightRect: CGRect
var scaleRect: CGRect
var keysRect: CGRect

func localizedToRowBounds() -> RowScene {
    RowScene(
        rowIndex: rowIndex,
        frame: CGRect(origin: .zero, size: frame.size),
        controlStripRect: controlStripRect.offsetBy(dx: dx, dy: dy),
        buttonLeftRect: buttonLeftRect.offsetBy(dx: dx, dy: dy),
        buttonRightRect: buttonRightRect.offsetBy(dx: dx, dy: dy),
        scaleRect: scaleRect.offsetBy(dx: dx, dy: dy),
        keysRect: keysRect.offsetBy(dx: dx, dy: dy),
        // ... 其余字段保持本地化
    )
}
```

### 修改后

- `RowScene` 新增 `buttonStripRect`
- `localizedToRowBounds()` 也同步本地化这个字段
- 这样 row layer 可以分别拿：
- `buttonStripRect` 画 `A` 区背景
- `scaleRect` 画 `B` 区背景

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoScene.swift
// 函数名/符号: PianoScene.RowScene.empty, PianoScene.RowScene.localizedToRowBounds()
// 功能说明: 修改后显式保存 A 区整条按钮条 rect，给 geometry 和 row layer 提供独立的顶层背景边界。
static let empty = RowScene(
    rowIndex: 0,
    frame: .null,
    controlStripRect: .null,
    buttonStripRect: .null,
    buttonLeftRect: .null,
    buttonRightRect: .null,
    scaleRect: .null,
    keysRect: .null,
    whiteKeys: [],
    blackKeys: [],
    scaleMarkers: []
)

var rowIndex: Int
var frame: CGRect
var controlStripRect: CGRect
var buttonStripRect: CGRect
var buttonLeftRect: CGRect
var buttonRightRect: CGRect
var scaleRect: CGRect
var keysRect: CGRect

func localizedToRowBounds() -> RowScene {
    RowScene(
        rowIndex: rowIndex,
        frame: CGRect(origin: .zero, size: frame.size),
        controlStripRect: controlStripRect.offsetBy(dx: dx, dy: dy),
        buttonStripRect: buttonStripRect.offsetBy(dx: dx, dy: dy),
        buttonLeftRect: buttonLeftRect.offsetBy(dx: dx, dy: dy),
        buttonRightRect: buttonRightRect.offsetBy(dx: dx, dy: dy),
        scaleRect: scaleRect.offsetBy(dx: dx, dy: dy),
        keysRect: keysRect.offsetBy(dx: dx, dy: dy),
        // ... 其余字段保持本地化
    )
}
```

## 修改 3：SceneBuilder / Geometry 从“横向三分”恢复为“上下三层”

### 修改前

- 修改前的 `makeRowScene(...)` 只生成一个 `controlStripRect`
- 左右按钮从这条顶栏左右切出
- `scaleRect` 则吃掉中间剩余宽度
- `keysRect` 只在一个 `scaleAreaHeight` 之后开始

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift
// 函数名: makeRowScene(rowIndex:rowState:bounds:)
// 功能说明: 修改前把 A/B 都放进同一个 controlStripRect，再从中横向切块。
let controlStripRect = PianoLayoutMath.controlStripRect(
    for: rowFrame,
    configuration: configuration
)
let buttonLeftRect = PianoLayoutMath.buttonLeftRect(
    in: controlStripRect,
    configuration: configuration
)
let buttonRightRect = PianoLayoutMath.buttonRightRect(
    in: controlStripRect,
    configuration: configuration
)
let scaleRect = PianoLayoutMath.scaleRect(
    in: controlStripRect,
    configuration: configuration
)
let keysRect = PianoLayoutMath.keysRect(
    for: rowFrame,
    configuration: configuration
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名: controlStripRect(for:configuration:), keysRect(for:configuration:), scaleRect(in:configuration:)
// 功能说明: 修改前 controlStripRect 只有一层高度，scaleRect 只占中间剩余宽度，keysRect 只下移一层。
static func controlStripRect(
    for rowFrame: CGRect,
    configuration: PianoConfiguration
) -> CGRect {
    CGRect(
        x: rowFrame.minX,
        y: rowFrame.minY,
        width: rowFrame.width,
        height: configuration.resolvedScaleAreaHeight
    )
}

static func keysRect(
    for rowFrame: CGRect,
    configuration: PianoConfiguration
) -> CGRect {
    let controlHeight = configuration.resolvedScaleAreaHeight
    return CGRect(
        x: rowFrame.minX,
        y: rowFrame.minY + controlHeight,
        width: rowFrame.width,
        height: max(rowFrame.height - controlHeight, 0)
    )
}

static func scaleRect(
    in controlStripRect: CGRect,
    configuration: PianoConfiguration
) -> CGRect {
    let buttonWidth = resolvedButtonWidth(
        in: controlStripRect,
        configuration: configuration
    )
    let originX = controlStripRect.minX + buttonWidth
    let width = max(controlStripRect.width - (buttonWidth * 2), 0)
    return CGRect(
        x: originX,
        y: controlStripRect.minY,
        width: width,
        height: controlStripRect.height
    )
}
```

### 修改后

- `controlStripRect` 现在表示 `A+B` 两层的总高度
- 新增 `buttonStripRect` 专门表示 `A` 区顶条
- `scaleRect` 改为整行宽度，并位于按钮条下方
- `keysRect` 按 `resolvedControlAreaHeight` 下移，确保 `C` 区从 `A+B` 下方开始

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift
// 函数名: makeRowScene(rowIndex:rowState:bounds:)
// 功能说明: 修改后先生成 A 区按钮条，再生成位于其下方且全宽的 B 区刻度条，最后再生成 C 区琴键区。
let controlStripRect = PianoLayoutMath.controlStripRect(
    for: rowFrame,
    configuration: configuration
)
let buttonStripRect = PianoLayoutMath.buttonStripRect(
    for: rowFrame,
    configuration: configuration
)
let buttonLeftRect = PianoLayoutMath.buttonLeftRect(
    in: buttonStripRect,
    configuration: configuration
)
let buttonRightRect = PianoLayoutMath.buttonRightRect(
    in: buttonStripRect,
    configuration: configuration
)
let scaleRect = PianoLayoutMath.scaleRect(
    for: rowFrame,
    configuration: configuration
)
let keysRect = PianoLayoutMath.keysRect(
    for: rowFrame,
    configuration: configuration
)

return PianoScene.RowScene(
    rowIndex: rowIndex,
    frame: rowFrame,
    controlStripRect: controlStripRect,
    buttonStripRect: buttonStripRect,
    buttonLeftRect: buttonLeftRect,
    buttonRightRect: buttonRightRect,
    scaleRect: scaleRect,
    keysRect: keysRect,
    whiteKeys: visibleKeys.whites,
    blackKeys: visibleKeys.blacks,
    scaleMarkers: scaleMarkers
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名: controlStripRect(for:configuration:), buttonStripRect(for:configuration:), keysRect(for:configuration:), scaleRect(for:configuration:)
// 功能说明: 修改后 geometry 明确表达 A/B/C 三层关系，避免视觉和命中语义再出现歧义。
static func controlStripRect(
    for rowFrame: CGRect,
    configuration: PianoConfiguration
) -> CGRect {
    CGRect(
        x: rowFrame.minX,
        y: rowFrame.minY,
        width: rowFrame.width,
        height: configuration.resolvedControlAreaHeight
    )
}

static func buttonStripRect(
    for rowFrame: CGRect,
    configuration: PianoConfiguration
) -> CGRect {
    CGRect(
        x: rowFrame.minX,
        y: rowFrame.minY,
        width: rowFrame.width,
        height: configuration.resolvedButtonStripHeight
    )
}

static func keysRect(
    for rowFrame: CGRect,
    configuration: PianoConfiguration
) -> CGRect {
    let controlHeight = configuration.resolvedControlAreaHeight
    return CGRect(
        x: rowFrame.minX,
        y: rowFrame.minY + controlHeight,
        width: rowFrame.width,
        height: max(rowFrame.height - controlHeight, 0)
    )
}

static func scaleRect(
    for rowFrame: CGRect,
    configuration: PianoConfiguration
) -> CGRect {
    CGRect(
        x: rowFrame.minX,
        y: rowFrame.minY + configuration.resolvedButtonStripHeight,
        width: rowFrame.width,
        height: configuration.resolvedScaleAreaHeight
    )
}
```

## 修改 4：RowLayer 绘制只给 `A` 区画顶条背景，`B` 区单独画刻度条

### 修改前

- 修改前，`drawControlStrip(in:)` 会先给整个 `controlStripRect` 统一填色
- 随后再在同一块背景中画按钮和刻度
- 所以视觉上 `A` 按钮天然“镶嵌”在 `B` 顶栏里

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: drawControlStrip(in:)
// 功能说明: 修改前整块填充 controlStripRect，无法体现 A 区顶条与 B 区刻度条的上下分离。
func drawControlStrip(in context: CGContext) {
    guard !scene.controlStripRect.isNull, !scene.controlStripRect.isEmpty else {
        return
    }

    context.saveGState()
    context.setFillColor(PianoLayerPalette.controlStripFill)
    context.fill(scene.controlStripRect)
    context.restoreGState()

    drawButton(
        direction: .left,
        rect: scene.buttonLeftRect,
        in: context
    )
    drawButton(
        direction: .right,
        rect: scene.buttonRightRect,
        in: context
    )
    drawScaleArea(in: context)
}
```

### 修改后

- `drawControlStrip(in:)` 改为先画 `buttonStripRect`
- `B` 区仍然走 `drawScaleArea(in:)`
- 这样 `A`、`B` 的背景由两个独立 rect 控制

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: drawControlStrip(in:), drawButtonStripBackground(in:)
// 功能说明: 修改后只给 A 区的按钮条单独填背景，B 区刻度仍由 drawScaleArea(in:) 独立绘制。
func drawControlStrip(in context: CGContext) {
    drawButtonStripBackground(in: context)

    drawButton(
        direction: .left,
        rect: scene.buttonLeftRect,
        in: context
    )
    drawButton(
        direction: .right,
        rect: scene.buttonRightRect,
        in: context
    )
    drawScaleArea(in: context)
}

func drawButtonStripBackground(in context: CGContext) {
    guard !scene.buttonStripRect.isNull, !scene.buttonStripRect.isEmpty else {
        return
    }

    context.saveGState()
    context.setFillColor(PianoLayerPalette.controlStripFill)
    context.fill(scene.buttonStripRect)
    context.restoreGState()
}
```

## 修改 5：Validation 夹具预期切换到新的 A/B/C 三层几何

### 修改前

- 修改前的 validation 预期仍然认为：
- `scaleRect` 位于 `x = 30 ... 290`
- `keysRect` 只从 `y = 20` 开始
- 这对应的正是旧版“左右按钮占两侧，中间才是 B 区”的几何模型

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateSceneRowFramesAndZones(), validateConfigurationResolvesSafeMetrics()
// 功能说明: 修改前的夹具仍以单层顶部控制区为预期，没有覆盖 buttonStripHeight 和 A/B 两层总高度。
if configuration.resolvedScaleAreaHeight != 1 {
    issues.append(issue(fixtureName, "resolvedScaleAreaHeight 不应超过 resolvedRowHeight。"))
}
if configuration.keyAreaHeight != 0 {
    issues.append(issue(fixtureName, "当顶部区域吃满整行时，keyAreaHeight 应为 0。"))
}

if firstRow.buttonLeftRect != CGRect(x: 0, y: 0, width: 30, height: 20) {
    issues.append(issue(fixtureName, "左按钮区域 rect 计算不正确。"))
}
if firstRow.buttonRightRect != CGRect(x: 290, y: 0, width: 30, height: 20) {
    issues.append(issue(fixtureName, "右按钮区域 rect 计算不正确。"))
}
if firstRow.scaleRect != CGRect(x: 30, y: 0, width: 260, height: 20) {
    issues.append(issue(fixtureName, "刻度区域 rect 计算不正确。"))
}
if firstRow.keysRect != CGRect(x: 0, y: 20, width: 320, height: 80) {
    issues.append(issue(fixtureName, "琴键区域 rect 计算不正确。"))
}
```

### 修改后

- 新增 `resolvedButtonStripHeight` 的夹具断言
- `validateSceneRowFramesAndZones()` 现在明确检查：
- `controlStripRect` 为两层总高 `40`
- `buttonStripRect` 为顶层 `20`
- `scaleRect` 为整行宽、位于 `y = 20`
- `keysRect` 从 `y = 40` 开始

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateSceneRowFramesAndZones(), validateConfigurationResolvesSafeMetrics()
// 功能说明: 修改后把 fixture 预期同步更新为 A/B/C 三层关系，防止后续又回退到横向三分版式。
if configuration.resolvedScaleAreaHeight != 1 {
    issues.append(issue(fixtureName, "resolvedScaleAreaHeight 不应超过 resolvedRowHeight。"))
}
if configuration.resolvedButtonStripHeight != 0 {
    issues.append(issue(fixtureName, "当 scaleAreaHeight 已吃满整行时，buttonStripHeight 应退化为 0。"))
}
if configuration.keyAreaHeight != 0 {
    issues.append(issue(fixtureName, "当顶部区域吃满整行时，keyAreaHeight 应为 0。"))
}

if firstRow.controlStripRect != CGRect(x: 0, y: 0, width: 320, height: 40) {
    issues.append(issue(fixtureName, "顶部控制区总 rect 应覆盖独立的 A/B 两条区域。"))
}
if firstRow.buttonStripRect != CGRect(x: 0, y: 0, width: 320, height: 20) {
    issues.append(issue(fixtureName, "A 区按钮条 rect 计算不正确。"))
}
if firstRow.buttonLeftRect != CGRect(x: 0, y: 0, width: 30, height: 20) {
    issues.append(issue(fixtureName, "左按钮区域 rect 计算不正确。"))
}
if firstRow.buttonRightRect != CGRect(x: 290, y: 0, width: 30, height: 20) {
    issues.append(issue(fixtureName, "右按钮区域 rect 计算不正确。"))
}
if firstRow.scaleRect != CGRect(x: 0, y: 20, width: 320, height: 20) {
    issues.append(issue(fixtureName, "刻度区域 rect 计算不正确。"))
}
if firstRow.keysRect != CGRect(x: 0, y: 40, width: 320, height: 60) {
    issues.append(issue(fixtureName, "琴键区域 rect 计算不正确。"))
}
```

## 验证情况

- `ReadLints`：本次修改的 `Shared/Piano` 文件无新增诊断
- `xcrun swiftc -typecheck`：已通过，覆盖以下文件：
- `NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoScene.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `PianoValidationRunner` 的命令行直接执行仍然没有稳定输出，本次不把它作为通过依据；这和前几轮阶段记录里的现象一致

## 对后续阶段的影响

- 这次修复不要求改动平台触控/鼠标输入桥接
- 这次修复也不要求改动 reducer，因为 `A/B/C` 的命中语义名称和状态机都没变
- 后续如果需要进一步贴近原始草图，还可以继续把：
- `A` 区按钮条高度
- `B` 区刻度条高度
- 由当前共享 `scaleAreaHeight` 的实现，拆成两个独立配置项

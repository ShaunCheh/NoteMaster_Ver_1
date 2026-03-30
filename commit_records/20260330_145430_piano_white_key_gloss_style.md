# 20260330_145430_piano_white_key_gloss_style

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_145430`
- 记录范围：为钢琴白键新增“拟物高光”样式，并把该样式接入现有 `White Keys` 控制面板选项
- 本次目标：在保留 `Outlined`、`Gap Only` 两种现有白键样式的前提下，新增第三种 `Gloss` 风格；不改钢琴交互语义，不改平台 wrapper，不新增专门的 settings view
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`

## 本次结论

- 修改前，白键样式和控制面板都只支持两种：
- `.outlined`
- `.borderlessSeparatedByGaps`
- 修改后，`PianoWhiteKeyStyle` 新增第三种：
- `.skeuomorphicHighlight`
- 控制面板 `White Keys` 也同步增加第三个可选项：
- `Gloss`
- 新样式不再只是“纯色填充 + 可选描边”
- 而是给白键增加了：
- 顶部高光带
- 中部二次高光
- 左缘内提亮
- 右缘阴影
- 底部阴影
- 外描边与内侧高光线
- 让白键呈现更接近拟物琴键的立体高光效果

## 修改前的问题

- 修改前，白键绘制层虽然已经支持两种风格
- 但没有第三种更立体、更有高光层次的样式
- 控制面板里的 `White Keys` 也只有两个选项
- 所以如果要做“拟物高光”，就必须同时改：
- `PianoWhiteKeyStyle`
- `PianoRowLayer.drawWhiteKeys(in:)`
- `SettingsPanelModel` 的 `White Keys` choice row
- `PianoValidation` 对 panel inference / projection 的样式覆盖

## 修改 1：在 `PianoWhiteKeyStyle` 中新增拟物高光样式

### 修改前

- 修改前，白键样式枚举只有 `outlined` 和 `borderlessSeparatedByGaps`
- `debugName` 也只有对应的两个值

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: PianoWhiteKeyStyle, PianoWhiteKeyStyle.debugName
// 功能说明: 修改前白键样式枚举只有“描边”和“键间缝”两种，没有拟物高光风格。
enum PianoWhiteKeyStyle: Equatable, Sendable {
    case outlined
    case borderlessSeparatedByGaps

    var debugName: String {
        switch self {
        case .outlined:
            return "outlined"
        case .borderlessSeparatedByGaps:
            return "gapOnly"
        }
    }
}
```

### 修改后

- 修改后，新增 `.skeuomorphicHighlight`
- `debugName` 同步增加 `gloss`
- 后续控制器状态文本和面板投影都可以直接复用这个 debug 名称

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: PianoWhiteKeyStyle, PianoWhiteKeyStyle.debugName
// 功能说明: 修改后新增拟物高光白键样式，并提供统一的调试文本标识。
enum PianoWhiteKeyStyle: Equatable, Sendable {
    case outlined
    case borderlessSeparatedByGaps
    case skeuomorphicHighlight

    var debugName: String {
        switch self {
        case .outlined:
            return "outlined"
        case .borderlessSeparatedByGaps:
            return "gapOnly"
        case .skeuomorphicHighlight:
            return "gloss"
        }
    }
}
```

## 修改 2：白键绘制分支新增拟物高光渲染

### 修改前

- 修改前，`drawWhiteKeys(in:)` 只分两类：
- `.outlined`
- `.borderlessSeparatedByGaps`
- 前者是纯色填充加描边
- 后者是纯色填充加键间留缝
- 没有第三种专门的拟物渲染函数

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: drawWhiteKeys(in:), whiteKeyFillRect(for:index:totalCount:)
// 功能说明: 修改前 drawWhiteKeys 只有 outlined / gapOnly 两条分支，不支持拟物高光白键。
func drawWhiteKeys(in context: CGContext) {
    guard !scene.whiteKeys.isEmpty else {
        return
    }

    context.saveGState()

    for (index, whiteKey) in scene.whiteKeys.enumerated() {
        let fillRect = whiteKeyFillRect(
            for: whiteKey.rect,
            index: index,
            totalCount: scene.whiteKeys.count
        )
        let isPreviewed = renderState.previewedNote == whiteKey.note

        switch configuration.whiteKeyStyle {
        case .outlined, .borderlessSeparatedByGaps:
            let fillColor = isPreviewed
                ? PianoLayerPalette.previewWhiteKeyFill
                : PianoLayerPalette.whiteKeyFill
            context.setFillColor(fillColor)
            context.fill(fillRect)

            if configuration.whiteKeyStyle == .outlined {
                context.setStrokeColor(PianoLayerPalette.whiteKeyStroke)
                context.setLineWidth(1)
                context.stroke(strokedRect(whiteKey.rect))
            }
        }
    }

    context.restoreGState()
}

func whiteKeyFillRect(
    for rect: CGRect,
    index: Int,
    totalCount: Int
) -> CGRect {
    switch configuration.whiteKeyStyle {
    case .outlined:
        return rect
    case .borderlessSeparatedByGaps:
        // ... 仅 gapOnly 使用留缝逻辑
        return rect
    }
}
```

### 修改后

- 修改后，`drawWhiteKeys(in:)` 增加 `.skeuomorphicHighlight` 分支
- 并新增 `drawSkeuomorphicWhiteKey(...)`
- 这个函数会按顺序绘制：
- 底色
- 顶部高光带
- 中部高光带
- 左缘提亮
- 右缘阴影
- 底部阴影
- 外描边
- 内侧高光线
- `whiteKeyFillRect(...)` 也同步调整：拟物高光样式和 `outlined` 一样使用完整键面，不使用 gap-only 的缩缝矩形

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: drawWhiteKeys(in:), drawSkeuomorphicWhiteKey(_:isPreviewed:in:), whiteKeyFillRect(for:index:totalCount:)
// 功能说明: 修改后新增拟物高光白键分支，通过多层高光/阴影与描线组合出立体感。
func drawWhiteKeys(in context: CGContext) {
    guard !scene.whiteKeys.isEmpty else {
        return
    }

    context.saveGState()

    for (index, whiteKey) in scene.whiteKeys.enumerated() {
        let fillRect = whiteKeyFillRect(
            for: whiteKey.rect,
            index: index,
            totalCount: scene.whiteKeys.count
        )
        let isPreviewed = renderState.previewedNote == whiteKey.note

        switch configuration.whiteKeyStyle {
        case .outlined, .borderlessSeparatedByGaps:
            let fillColor = isPreviewed
                ? PianoLayerPalette.previewWhiteKeyFill
                : PianoLayerPalette.whiteKeyFill
            context.setFillColor(fillColor)
            context.fill(fillRect)

            if configuration.whiteKeyStyle == .outlined {
                context.setStrokeColor(PianoLayerPalette.whiteKeyStroke)
                context.setLineWidth(1)
                context.stroke(strokedRect(whiteKey.rect))
            }
        case .skeuomorphicHighlight:
            drawSkeuomorphicWhiteKey(
                whiteKey.rect,
                isPreviewed: isPreviewed,
                in: context
            )
        }
    }

    context.restoreGState()
}

func drawSkeuomorphicWhiteKey(
    _ rect: CGRect,
    isPreviewed: Bool,
    in context: CGContext
) {
    guard !rect.isEmpty else {
        return
    }

    let baseFill = isPreviewed
        ? PianoLayerPalette.previewWhiteKeyGlossBase
        : PianoLayerPalette.whiteKeyGlossBase
    let topHighlight = isPreviewed
        ? PianoLayerPalette.previewWhiteKeyGlossHighlight
        : PianoLayerPalette.whiteKeyGlossHighlight
    let midHighlight = isPreviewed
        ? PianoLayerPalette.previewWhiteKeyGlossMidHighlight
        : PianoLayerPalette.whiteKeyGlossMidHighlight
    let rightShadow = isPreviewed
        ? PianoLayerPalette.previewWhiteKeyGlossRightShadow
        : PianoLayerPalette.whiteKeyGlossRightShadow
    let bottomShadow = isPreviewed
        ? PianoLayerPalette.previewWhiteKeyGlossBottomShadow
        : PianoLayerPalette.whiteKeyGlossBottomShadow
    let strokeColor = isPreviewed
        ? PianoLayerPalette.previewWhiteKeyGlossStroke
        : PianoLayerPalette.whiteKeyGlossStroke

    context.setFillColor(baseFill)
    context.fill(rect)

    // 顶部高光带
    let topBandHeight = min(max(rect.height * 0.24, 2), rect.height)
    if topBandHeight > 0 {
        context.setFillColor(topHighlight)
        context.fill(
            CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: topBandHeight
            )
        )
    }

    // 中部补一层较弱高光，避免高光只停留在最顶部
    let midBandHeight = min(max(rect.height * 0.16, 1), rect.height)
    if midBandHeight > 0 {
        context.setFillColor(midHighlight)
        context.fill(
            CGRect(
                x: rect.minX + 1,
                y: rect.minY + topBandHeight,
                width: max(rect.width - 2, 0),
                height: min(midBandHeight, max(rect.height - topBandHeight, 0))
            )
        )
    }

    let leftHighlightWidth = min(max(rect.width * 0.06, 1), rect.width)
    context.setFillColor(PianoLayerPalette.whiteKeyGlossEdgeHighlight)
    context.fill(
        CGRect(
            x: rect.minX,
            y: rect.minY,
            width: leftHighlightWidth,
            height: rect.height
        )
    )

    let rightShadowWidth = min(max(rect.width * 0.08, 1), rect.width)
    context.setFillColor(rightShadow)
    context.fill(
        CGRect(
            x: rect.maxX - rightShadowWidth,
            y: rect.minY,
            width: rightShadowWidth,
            height: rect.height
        )
    )

    let bottomShadowHeight = min(max(rect.height * 0.12, 1.5), rect.height)
    context.setFillColor(bottomShadow)
    context.fill(
        CGRect(
            x: rect.minX,
            y: rect.maxY - bottomShadowHeight,
            width: rect.width,
            height: bottomShadowHeight
        )
    )

    context.setStrokeColor(strokeColor)
    context.setLineWidth(1)
    context.stroke(strokedRect(rect))

    let innerRect = rect.insetBy(dx: 1, dy: 1)
    if !innerRect.isEmpty {
        context.setStrokeColor(PianoLayerPalette.whiteKeyGlossInnerHighlight)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: innerRect.minX, y: innerRect.minY + 0.5))
        context.addLine(to: CGPoint(x: innerRect.maxX, y: innerRect.minY + 0.5))
        context.move(to: CGPoint(x: innerRect.minX + 0.5, y: innerRect.minY))
        context.addLine(to: CGPoint(x: innerRect.minX + 0.5, y: innerRect.maxY))
        context.strokePath()
    }
}

func whiteKeyFillRect(
    for rect: CGRect,
    index: Int,
    totalCount: Int
) -> CGRect {
    switch configuration.whiteKeyStyle {
    case .outlined, .skeuomorphicHighlight:
        return rect
    case .borderlessSeparatedByGaps:
        // ... 只有 gapOnly 继续使用留缝矩形
        return rect
    }
}
```

## 修改 3：新增拟物高光调色板

### 修改前

- 修改前，白键调色板只有：
- 普通填充
- 普通描边
- preview 填充
- 没有用于拟物高光的多层颜色组

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: PianoLayerPalette.whiteKeyFill, whiteKeyStroke, previewWhiteKeyFill
// 功能说明: 修改前 palette 里只有基础白键配色，没有 gloss 风格所需的高光/阴影颜色。
static let whiteKeyFill = color(red: 0.99, green: 0.99, blue: 1)
static let whiteKeyStroke = color(red: 0.65, green: 0.68, blue: 0.74)
static let previewWhiteKeyFill = color(red: 0.81, green: 0.89, blue: 1)
```

### 修改后

- 修改后，palette 补了一整组 gloss 颜色：
- base
- top highlight
- mid highlight
- edge highlight
- right shadow
- bottom shadow
- stroke
- inner highlight
- 以及对应的 preview 版本

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: PianoLayerPalette.whiteKeyGloss*
// 功能说明: 修改后为拟物高光白键补齐基础色、高光、阴影、描边与 preview 版本颜色。
static let whiteKeyGlossBase = color(red: 0.96, green: 0.97, blue: 0.99)
static let whiteKeyGlossHighlight = color(red: 1, green: 1, blue: 1, alpha: 0.84)
static let whiteKeyGlossMidHighlight = color(red: 1, green: 1, blue: 1, alpha: 0.32)
static let whiteKeyGlossEdgeHighlight = color(red: 1, green: 1, blue: 1, alpha: 0.45)
static let whiteKeyGlossRightShadow = color(red: 0.73, green: 0.76, blue: 0.82, alpha: 0.34)
static let whiteKeyGlossBottomShadow = color(red: 0.62, green: 0.65, blue: 0.71, alpha: 0.22)
static let whiteKeyGlossStroke = color(red: 0.69, green: 0.72, blue: 0.79)
static let whiteKeyGlossInnerHighlight = color(red: 1, green: 1, blue: 1, alpha: 0.48)
static let previewWhiteKeyGlossBase = color(red: 0.76, green: 0.86, blue: 0.99)
static let previewWhiteKeyGlossHighlight = color(red: 0.98, green: 0.99, blue: 1, alpha: 0.62)
static let previewWhiteKeyGlossMidHighlight = color(red: 0.98, green: 0.99, blue: 1, alpha: 0.20)
static let previewWhiteKeyGlossRightShadow = color(red: 0.20, green: 0.38, blue: 0.70, alpha: 0.24)
static let previewWhiteKeyGlossBottomShadow = color(red: 0.16, green: 0.32, blue: 0.60, alpha: 0.18)
static let previewWhiteKeyGlossStroke = color(red: 0.39, green: 0.57, blue: 0.86)
```

## 修改 4：控制面板 `White Keys` 增加第三个选项 `Gloss`

### 修改前

- 修改前，`White Keys` 这行只有两个 action：
- `Outlined`
- `Gap Only`
- 说明文字里也只提到：
- outlined borders
- gap-only separation

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.accessibilityLabel, SettingsChoiceRowID.actionIDs, SettingsActionID
// 功能说明: 修改前 White Keys 面板行只有两种样式选项，没有 gloss。
case .pianoWhiteKeyStyle:
    return "Select whether white keys use outlined borders or gap-only separation"

case .pianoWhiteKeyStyle:
    return [
        .setPianoWhiteKeyStyleOutlined,
        .setPianoWhiteKeyStyleGapOnly
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    // ... 原有 action 保持不变
    case setPianoWhiteKeyStyleOutlined
    case setPianoWhiteKeyStyleGapOnly
}
```

### 修改后

- 修改后，`White Keys` action 列表增加第三个：
- `.setPianoWhiteKeyStyleSkeuomorphicHighlight`
- 标题显示为 `Gloss`
- 辅助说明也同步扩展到三种样式
- 选中态和 `apply(to pianoPanelState:)` 也都接到了 `.skeuomorphicHighlight`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.accessibilityLabel, SettingsChoiceRowID.actionIDs, SettingsActionID.title/accessibilityLabel/isSelected/apply(to pianoPanelState:)
// 功能说明: 修改后 White Keys 面板行新增 Gloss 选项，并能正确驱动 pianoPanelState.whiteKeyStyle。
case .pianoWhiteKeyStyle:
    return "Select whether white keys use outlined borders, gap-only separation, or a glossy skeuomorphic highlight"

case .pianoWhiteKeyStyle:
    return [
        .setPianoWhiteKeyStyleOutlined,
        .setPianoWhiteKeyStyleGapOnly,
        .setPianoWhiteKeyStyleSkeuomorphicHighlight
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    // ... 原有 action 保持不变
    case setPianoWhiteKeyStyleOutlined
    case setPianoWhiteKeyStyleGapOnly
    case setPianoWhiteKeyStyleSkeuomorphicHighlight
}

case .setPianoWhiteKeyStyleSkeuomorphicHighlight:
    return "Gloss"

case .setPianoWhiteKeyStyleSkeuomorphicHighlight:
    return "Render white keys with a skeuomorphic highlight and beveled shading"

case .setPianoWhiteKeyStyleSkeuomorphicHighlight:
    return stateContext.pianoPanelState.whiteKeyStyle == .skeuomorphicHighlight

case .setPianoWhiteKeyStyleSkeuomorphicHighlight:
    pianoPanelState.whiteKeyStyle = .skeuomorphicHighlight
```

## 修改 5：把 panel inference / projection 校验切到新样式

### 修改前

- 修改前，面板相关 validation 只用 `gapOnly` 校验白键样式链路
- 新增 `gloss` 后，如果不更新 fixture，就只能证明旧样式还能工作

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validatePianoPanelStateInferenceAndClamp(), validatePianoPanelProjectionResolution()
// 功能说明: 修改前 panel validation 用的是 gapOnly，不会覆盖新加的 gloss 样式。
let inferred = PianoPanelState.inferred(
    configuration: PianoConfiguration(
        whiteKeyStyle: .borderlessSeparatedByGaps,
        snapEnabled: false
    ),
    rows: [
        // ...
    ]
)

if inferred.whiteKeyStyle != .borderlessSeparatedByGaps {
    issues.append(issue(fixtureName, "inferred whiteKeyStyle 应沿用 configuration.whiteKeyStyle。"))
}

let panelState = PianoPanelState(
    isVisible: false,
    rowCount: 4,
    movementScope: .cascade,
    whiteKeyStyle: .borderlessSeparatedByGaps,
    snapEnabled: false
)

if resolvedConfiguration.whiteKeyStyle != .borderlessSeparatedByGaps {
    issues.append(issue(fixtureName, "panel projection 应允许单独切换 whiteKeyStyle。"))
}
```

### 修改后

- 修改后，两组 fixture 都改成直接覆盖 `skeuomorphicHighlight`
- 这样 automation 会真正碰到第三种样式

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validatePianoPanelStateInferenceAndClamp(), validatePianoPanelProjectionResolution()
// 功能说明: 修改后 panel validation 直接覆盖 gloss 样式，确保推断与投影都支持新分支。
let inferred = PianoPanelState.inferred(
    configuration: PianoConfiguration(
        whiteKeyStyle: .skeuomorphicHighlight,
        snapEnabled: false
    ),
    rows: [
        // ...
    ]
)

if inferred.whiteKeyStyle != .skeuomorphicHighlight {
    issues.append(issue(fixtureName, "inferred whiteKeyStyle 应沿用 configuration.whiteKeyStyle。"))
}

let panelState = PianoPanelState(
    isVisible: false,
    rowCount: 4,
    movementScope: .cascade,
    whiteKeyStyle: .skeuomorphicHighlight,
    snapEnabled: false
)

if resolvedConfiguration.whiteKeyStyle != .skeuomorphicHighlight {
    issues.append(issue(fixtureName, "panel projection 应允许单独切换 whiteKeyStyle。"))
}
```

## 本次没有改动的部分

- `PianoPanelState.swift` 没改
- 因为它在上一轮已经能承载 `whiteKeyStyle`，这次只是在该枚举里新增第三个 case
- `iOSViewController.swift` / `macOSViewController.swift` 也没改
- 因为它们已经通过 `resolvedPianoDemoConfiguration.whiteKeyStyle.debugName` 显示当前样式
- `SettingsPanelSnapshotBuilder.swift` 也没改
- 原因是现有 snapshot builder 会自动吃下新增的 `SettingsActionID`

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelState, PianoPanelProjection
// 功能说明: 本次未修改；上一轮已经完成 whiteKeyStyle 的面板状态承载与配置投影。
(未修改，本次记录不重复展开代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: pianoDemoStatusText(), applyPianoDemoState()
// 功能说明: 本次未修改；控制器已通过 resolvedPianoDemoConfiguration 自动反映新样式。
(未修改，本次记录不重复展开代码)
```

## 验证情况

- `ReadLints`：本次修改相关文件无新增诊断
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`：通过
- 本次全量 typecheck 仍有 2 条仓库原有 warning：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次未做双平台手工 UI 回归；当前验证以静态编译和 panel validation 更新为主

## 对后续调整的影响

- 现在 `White Keys` 面板行已经支持 3 种风格：
- `Outlined`
- `Gap Only`
- `Gloss`
- 后续如果还要继续补：
- 亮度更强的高光
- 更重的底部阴影
- 圆角拟物白键
- 都可以继续沿着 `drawSkeuomorphicWhiteKey(...)` 和 `PianoLayerPalette.whiteKeyGloss*` 这条线扩展

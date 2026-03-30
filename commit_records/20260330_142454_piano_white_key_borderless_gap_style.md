# 20260330_142454_piano_white_key_borderless_gap_style

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_142454`
- 记录范围：为钢琴白键新增“无边框，只靠键间缝分隔”的样式，并将当前双平台 piano demo 切换到该样式
- 本次目标：在不破坏现有描边样式的前提下，新增一个可配置的白键视觉风格；当前 demo 直接启用该风格，但不扩展控制面板，不修改黑键绘制和交互语义
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`

## 本次结论

- 修改前，白键只有一种样式：每个白键先填充，再做 `1pt` 描边
- 修改后，shared 配置新增 `PianoWhiteKeyStyle`
- 当前支持两种样式：
- `.outlined`
- `.borderlessSeparatedByGaps`
- 新样式下：
- 白键不再逐个描边
- 改为把每个白键的填充矩形在内部边缘各缩出半个缝宽
- 相邻两个白键之间露出底下的 `keysAreaBackground`
- 视觉上形成“无边框，只靠键间缝分隔”的效果
- 同时为了兼容旧行为，`PianoConfiguration` 默认样式仍然保留为 `.outlined`
- 当前 iOS / macOS demo 显式切到 `.borderlessSeparatedByGaps`

## 修改前的问题

- 修改前，白键样式是写死在 `PianoRowLayer.drawWhiteKeys(in:)` 里的
- 每个白键都会执行：
- `fill(whiteKey.rect)`
- `stroke(strokedRect(whiteKey.rect))`
- 这意味着：
- 没有白键样式配置入口
- 不能在保留旧样式的同时增加新样式
- “无边框只靠键间缝分隔”无法通过配置切换实现

## 修改 1：在 shared 配置层新增白键样式枚举

### 修改前

- 修改前，`PianoConfiguration` 没有任何白键样式字段
- 白键画不画边框完全由绘制函数内部硬编码决定

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: PianoConfiguration, PianoConfiguration.init(...)
// 功能说明: 修改前配置层没有 whiteKeyStyle，白键视觉样式无法通过 configuration 注入。
struct PianoConfiguration: Equatable, Sendable {
    static let blackKeyWidthRatioRange: ClosedRange<CGFloat> = 0.2...0.95
    static let blackKeyHeightRatioRange: ClosedRange<CGFloat> = 0.2...1

    var whiteKeyWidth: CGFloat
    var rowHeight: CGFloat
    var rowSpacing: CGFloat
    var scaleAreaHeight: CGFloat
    var buttonAreaWidth: CGFloat
    var blackKeyWidthRatio: CGFloat
    var blackKeyHeightRatio: CGFloat
    var snapEnabled: Bool

    init(
        whiteKeyWidth: CGFloat = 44,
        rowHeight: CGFloat = 160,
        rowSpacing: CGFloat = 12,
        scaleAreaHeight: CGFloat = 34,
        buttonAreaWidth: CGFloat = 28,
        blackKeyWidthRatio: CGFloat = 0.62,
        blackKeyHeightRatio: CGFloat = 0.6,
        snapEnabled: Bool = true
    ) {
        self.whiteKeyWidth = whiteKeyWidth
        self.rowHeight = rowHeight
        self.rowSpacing = rowSpacing
        self.scaleAreaHeight = scaleAreaHeight
        self.buttonAreaWidth = buttonAreaWidth
        self.blackKeyWidthRatio = blackKeyWidthRatio
        self.blackKeyHeightRatio = blackKeyHeightRatio
        self.snapEnabled = snapEnabled
    }
}
```

### 修改后

- 修改后，新增 `PianoWhiteKeyStyle`
- `PianoConfiguration` 增加 `whiteKeyStyle`
- 默认值设为 `.outlined`
- 这样旧调用点即使不传这个字段，行为也不会变化

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: PianoWhiteKeyStyle, PianoConfiguration, PianoConfiguration.init(...)
// 功能说明: 修改后 whiteKeyStyle 成为 shared configuration 的一部分，支持保留旧样式并新增“无边框键间缝”样式。
enum PianoWhiteKeyStyle: Equatable, Sendable {
    case outlined
    case borderlessSeparatedByGaps
}

struct PianoConfiguration: Equatable, Sendable {
    static let blackKeyWidthRatioRange: ClosedRange<CGFloat> = 0.2...0.95
    static let blackKeyHeightRatioRange: ClosedRange<CGFloat> = 0.2...1

    var whiteKeyWidth: CGFloat
    var rowHeight: CGFloat
    var rowSpacing: CGFloat
    var scaleAreaHeight: CGFloat
    var buttonAreaWidth: CGFloat
    var blackKeyWidthRatio: CGFloat
    var blackKeyHeightRatio: CGFloat
    var whiteKeyStyle: PianoWhiteKeyStyle
    var snapEnabled: Bool

    init(
        whiteKeyWidth: CGFloat = 44,
        rowHeight: CGFloat = 160,
        rowSpacing: CGFloat = 12,
        scaleAreaHeight: CGFloat = 34,
        buttonAreaWidth: CGFloat = 28,
        blackKeyWidthRatio: CGFloat = 0.62,
        blackKeyHeightRatio: CGFloat = 0.6,
        whiteKeyStyle: PianoWhiteKeyStyle = .outlined,
        snapEnabled: Bool = true
    ) {
        self.whiteKeyWidth = whiteKeyWidth
        self.rowHeight = rowHeight
        self.rowSpacing = rowSpacing
        self.scaleAreaHeight = scaleAreaHeight
        self.buttonAreaWidth = buttonAreaWidth
        self.blackKeyWidthRatio = blackKeyWidthRatio
        self.blackKeyHeightRatio = blackKeyHeightRatio
        self.whiteKeyStyle = whiteKeyStyle
        self.snapEnabled = snapEnabled
    }
}
```

## 修改 2：把白键绘制从“固定描边”改成“按样式分支”

### 修改前

- 修改前，`drawWhiteKeys(in:)` 会无条件对每个白键描边
- 这使得“无边框”样式无法落地

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: drawWhiteKeys(in:)
// 功能说明: 修改前白键总是 fill 后再 stroke，边框样式是写死的。
func drawWhiteKeys(in context: CGContext) {
    guard !scene.whiteKeys.isEmpty else {
        return
    }

    context.saveGState()

    for whiteKey in scene.whiteKeys {
        let fillColor = renderState.previewedNote == whiteKey.note
            ? PianoLayerPalette.previewWhiteKeyFill
            : PianoLayerPalette.whiteKeyFill
        context.setFillColor(fillColor)
        context.fill(whiteKey.rect)
        context.setStrokeColor(PianoLayerPalette.whiteKeyStroke)
        context.setLineWidth(1)
        context.stroke(strokedRect(whiteKey.rect))
    }

    context.restoreGState()
}
```

### 修改后

- 修改后，`drawWhiteKeys(in:)` 改成：
- 先根据 `whiteKeyStyle` 计算 `fillRect`
- `.outlined` 时保持原逻辑
- `.borderlessSeparatedByGaps` 时不描边，只缩出内部缝隙
- 新增 `whiteKeyFillRect(for:index:totalCount:)`
- 其中首尾白键保持外边缘贴齐，只在相邻白键之间各缩出 `0.5pt + 0.5pt`
- 最终形成 `1pt` 的键间缝

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: drawWhiteKeys(in:), whiteKeyFillRect(for:index:totalCount:)
// 功能说明: 修改后白键填充矩形会按样式调整；新样式不描边，改为通过相邻白键之间的留缝呈现分隔。
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
        let fillColor = renderState.previewedNote == whiteKey.note
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
        guard totalCount > 1, !rect.isEmpty else {
            return rect
        }

        let gapWidth = min(1, rect.width)
        let leftInset = index == 0 ? 0 : gapWidth * 0.5
        let rightInset = index == totalCount - 1 ? 0 : gapWidth * 0.5
        return CGRect(
            x: rect.minX + leftInset,
            y: rect.minY,
            width: max(rect.width - leftInset - rightInset, 0),
            height: rect.height
        )
    }
}
```

## 修改 3：把当前双平台 demo 显式切到新样式

### 修改前

- 修改前，双平台 demo 都沿用 `PianoConfiguration` 默认样式
- 因为没有 `whiteKeyStyle` 字段，所以白键还是老的描边样式

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改前 iOS demo 没有 whiteKeyStyle，默认表现为旧的逐键描边白键样式。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 136,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    snapEnabled: true
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改前 macOS demo 同样没有 whiteKeyStyle，默认也是旧的描边白键样式。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 136,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    snapEnabled: true
)
```

### 修改后

- 修改后，iOS / macOS 两边的 `initialPianoDemoConfiguration` 都显式传入：
- `whiteKeyStyle: .borderlessSeparatedByGaps`
- 因此当前 demo 会直接显示新样式
- 但 shared 默认值仍是 `.outlined`，其他调用点不会被动改掉

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改后 iOS demo 显式切到“无边框、只靠键间缝分隔”的白键样式。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 136,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    whiteKeyStyle: .borderlessSeparatedByGaps,
    snapEnabled: true
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改后 macOS demo 同步切到“无边框、只靠键间缝分隔”的白键样式。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 136,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    whiteKeyStyle: .borderlessSeparatedByGaps,
    snapEnabled: true
)
```

## 修改 4：补充 row layer 样式透传校验

### 修改前

- 修改前，`validateKeyboardLayerUsesOneRowLayerPerRow()` 只校验：
- row layer 数量
- frame
- scene 本地化
- `contentsScale`
- 还没有任何关于白键样式配置透传的检查

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateKeyboardLayerUsesOneRowLayerPerRow()
// 功能说明: 修改前该 fixture 不关心 whiteKeyStyle 是否从 root layer 正确传到 row layer。
let configuration = PianoConfiguration(
    whiteKeyWidth: 40,
    rowHeight: 88,
    rowSpacing: 10,
    scaleAreaHeight: 22,
    buttonAreaWidth: 28
)

if rowLayer.contentsScale != layer.contentsScale {
    issues.append(issue(fixtureName, "第 \(index) 行 row layer 应继承根 layer 的 contentsScale。"))
}
```

### 修改后

- 修改后，这个 fixture 在构造配置时明确传入新样式
- 同时增加断言，要求每个 row layer 都继承 `configuration.whiteKeyStyle`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateKeyboardLayerUsesOneRowLayerPerRow()
// 功能说明: 修改后 fixture 会校验 whiteKeyStyle 也能从 keyboard layer 正确透传到每个 row layer。
let configuration = PianoConfiguration(
    whiteKeyWidth: 40,
    rowHeight: 88,
    rowSpacing: 10,
    scaleAreaHeight: 22,
    buttonAreaWidth: 28,
    whiteKeyStyle: .borderlessSeparatedByGaps
)

if rowLayer.contentsScale != layer.contentsScale {
    issues.append(issue(fixtureName, "第 \(index) 行 row layer 应继承根 layer 的 contentsScale。"))
}
if rowLayer.configuration.whiteKeyStyle != configuration.whiteKeyStyle {
    issues.append(issue(fixtureName, "第 \(index) 行 row layer 应继承 configuration.whiteKeyStyle。"))
}
```

## 本次没有改动的部分

- `PianoGeometry` 没改
- 因为新样式不需要改变按键布局和 hit test 几何
- `PianoInteractionReducer` 没改
- 因为这次只是视觉样式变化，不涉及 A/B/C 区交互语义
- 黑键绘制逻辑也没改
- 黑键仍然沿用当前的填充 + 描边样式
- `SettingsPanel` 也没加白键样式开关
- 当前只是直接把 demo 配到新样式，不是先做面板可切换

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名/符号: makeVisibleKeys(...), keyRect(...)
// 功能说明: 本次未修改；白键样式切换不影响键位几何和命中区域。
(未修改，本次记录不重复展开代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: reduce(...), applyScaleDrag(...), beginKeyGlissando(...)
// 功能说明: 本次未修改；白键样式变化不应牵动交互 reducer。
(未修改，本次记录不重复展开代码)
```

## 验证情况

- `ReadLints`：本次修改相关文件无新增诊断
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`：通过
- 本次全量 typecheck 仍有 2 条仓库原有 warning：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次未做双平台手工 UI 回归截图；当前验证以 shared 配置透传校验、lint 和全量静态编译为主

## 对后续调整的影响

- 现在白键样式已经有 shared 配置入口，后续如果要继续加：
- 更细/更宽的键间缝
- 圆角白键
- 无边框但保留顶部描线
- 都可以继续沿着 `PianoWhiteKeyStyle + drawWhiteKeys(in:)` 这条链扩展
- 如果后续要把它暴露到控制面板，也可以直接接到：
- `SettingsPanelModel`
- `PianoPanelState`
- `PianoPanelProjection`
- 当前这次实现已经把样式切换点放到合适的 shared 配置层了

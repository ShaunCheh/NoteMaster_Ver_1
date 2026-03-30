# 20260330_132056_piano_key_height_doubled

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_132056`
- 记录范围：将当前钢琴 demo 的琴键区高度调整为原来的两倍
- 本次目标：只调整双平台 demo 初始钢琴配置中的单行总高度，使 `C` 区琴键高度从原来的 `40` 提升到 `80`；不改 shared piano 几何公式、不改控制面板 schema、不改交互 reducer
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift`

## 本次结论

- 修改前，当前 piano demo 的初始配置里 `rowHeight = 96`
- 由于顶部 `A/B` 控制区在当前配置下固定占用 `56`，所以真实键区高度是：
- `96 - 56 = 40`
- 用户要求“把琴键的高度改成现在的两倍”，目标是把 `C` 区从 `40` 提升到 `80`
- 因此不能直接把整行总高度乘二到 `192`
- 而是要把 `rowHeight` 调整到：
- `80 + 56 = 136`
- 修改后，iOS / macOS 两边的 demo 初始配置都从 `96` 调到 `136`
- 顶部 `A/B` 区保持不变，只有 `C` 区琴键高度翻倍

## 修改前的高度计算关系

- 这次没有改 shared 几何公式
- 但需要先明确当前代码里“琴键高度”并不等于 `rowHeight`
- 真正的键区高度来自：
- `keyAreaHeight = resolvedRowHeight - resolvedControlAreaHeight`
- 在当前 demo 参数里：
- `scaleAreaHeight = 28`
- `resolvedButtonStripHeight = 28`
- `resolvedControlAreaHeight = 56`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: resolvedButtonStripHeight, resolvedControlAreaHeight, keyAreaHeight
// 功能说明: 这段 shared 配置公式未修改；它决定了顶部 A/B 控制区和底部 C 区琴键区的高度关系。
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

## 修改前的问题

- 修改前，双平台 demo 的 `initialPianoDemoConfiguration` 都把 `rowHeight` 固定写成 `96`
- 配合当前 `scaleAreaHeight = 28` 的布局，最终 `keyAreaHeight` 只有 `40`
- 这和“把琴键高度翻倍”的目标不一致

## 修改 1：调大 iOS demo 的初始钢琴总高度

### 修改前

- iOS 控制器里 piano demo 的初始高度仍是 `96`
- 在当前 shared 公式下，这只会得到 `40` 的键区高度

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改前 iOS demo 的初始 rowHeight 为 96，顶部控制区不变时，C 区键高只有 40。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 96,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    snapEnabled: true
)
```

### 修改后

- 修改后，把 iOS demo 的 `rowHeight` 调整为 `136`
- 顶部 `A/B` 区仍然维持原尺寸，新增的高度全部落到 `C` 区键面
- 因此键区高度从 `40` 变为 `80`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改后 iOS demo 的 rowHeight 调整为 136，使当前配置下的 C 区琴键高度从 40 提升到 80。
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

## 修改 2：同步调大 macOS demo 的初始钢琴总高度

### 修改前

- macOS 控制器与 iOS 保持同样的初始值
- 因此也同样只有 `40` 的键区高度

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改前 macOS demo 的初始 rowHeight 同样为 96，因此键区高度也只有 40。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 96,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    snapEnabled: true
)
```

### 修改后

- 修改后，同步把 macOS demo 的 `rowHeight` 调整为 `136`
- 保证双平台 demo 的视觉高度和键区比例保持一致

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改后 macOS demo 同步把 rowHeight 调整为 136，保持与 iOS 一致的双倍键区高度。
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

## 为什么这次不是把 `rowHeight` 直接改成两倍

- 这次用户要求的是“琴键高度翻倍”，不是“整行总高度翻倍”
- 当前一行由三块组成：
- `A` 区按钮条
- `B` 区刻度条
- `C` 区琴键区
- 其中 `A+B` 在当前 demo 配置下合计固定为 `56`
- 所以如果把 `rowHeight` 从 `96` 直接翻倍到 `192`，得到的是：
- `192 - 56 = 136`
- 这会让键区比原来的 `40` 大出很多，不是“两倍”而是 `3.4x`
- 因此正确做法是只补足键区需要增加的 `40`，把总高调到 `136`

## 本次没有改动的部分

- `PianoConfiguration` 的 shared 默认值 `rowHeight: 160` 没改
- 因为这次需求针对的是“当前 piano demo”
- 不是要全局修改所有未来使用 `PianoConfiguration()` 默认值的场景
- `SettingsPanel` 也没新增“键高”或“行高”控件
- 这次只是直接调整 demo 初始配置，不涉及新的面板参数

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: init(...)
// 功能说明: 本次未修改 shared 默认 rowHeight；仅调大双平台 demo 的 initialPianoDemoConfiguration。
(未修改，本次记录不重复展开完整代码)
```

## 验证情况

- `ReadLints`：`iOSViewController.swift`、`macOSViewController.swift` 无新增诊断
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`：通过
- 本次全量 typecheck 仍有 2 条仓库原有 warning：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次未单独做 iOS / macOS 手工 UI 回归；当前验证以静态编译和局部诊断检查为主

## 对后续调整的影响

- 现在的 demo 键区高度已经翻倍，但这还是“固定初始值”
- 如果后续要把键高开放到控制面板里，建议不要再直接改控制器常量
- 而是把 `rowHeight` 作为新的 piano panel 控制项，继续沿着：
- `SettingsPanelModel`
- `PianoPanelState`
- `PianoPanelProjection`
- 这条链路扩展

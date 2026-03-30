# 20260330_153500_piano_key_height_doubled_again

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_153500`
- 记录范围：将当前钢琴 demo 的琴键区高度，在上一轮基础上再次调整为当前的 2 倍
- 本次目标：只调整双平台 demo 初始钢琴配置中的单行总高度，使 `C` 区琴键高度从当前的 `80` 提升到 `160`；不改 shared piano 几何公式、不改控制面板 schema、不改交互 reducer
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

- 修改前，当前 piano demo 的初始配置里 `rowHeight = 136`
- 由于顶部 `A/B` 控制区在当前配置下仍固定占用 `56`，所以真实键区高度是：
- `136 - 56 = 80`
- 用户这次要求“把琴键高度调整到现在的 2 倍”，目标是把 `C` 区从 `80` 提升到 `160`
- 因此不能把 shared 几何公式改掉，也不需要改 `scaleAreaHeight`
- 只需要把 demo 的 `rowHeight` 调整到：
- `160 + 56 = 216`
- 修改后，iOS / macOS 两边的 demo 初始配置都从 `136` 调到 `216`
- 顶部 `A/B` 区保持不变，新增出来的高度全部落到 `C` 区琴键区

## 修改前的高度计算关系

- 这次没有改 shared 几何公式
- 但要先明确当前代码里“琴键高度”并不直接等于 `rowHeight`
- 真正的键区高度来自：
- `keyAreaHeight = resolvedRowHeight - resolvedControlAreaHeight`
- 在当前 demo 参数里：
- `scaleAreaHeight = 28`
- `resolvedButtonStripHeight = 28`
- `resolvedControlAreaHeight = 56`
- 所以：
- 修改前 `keyAreaHeight = 136 - 56 = 80`
- 修改后 `keyAreaHeight = 216 - 56 = 160`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: resolvedButtonStripHeight, resolvedControlAreaHeight, keyAreaHeight
// 功能说明: 这段 shared 配置公式本次未修改；它继续决定顶部 A/B 控制区与底部 C 区琴键区的高度关系。
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

- 修改前，双平台 demo 的 `initialPianoDemoConfiguration` 都把 `rowHeight` 固定写成 `136`
- 在当前 shared 公式下，这只能得到 `80` 的键区高度
- 这与这次“基于当前高度再翻倍”的目标不一致

## 修改 1：继续调大 iOS demo 的初始钢琴总高度

### 修改前

- iOS 控制器里 piano demo 的初始高度是 `136`
- 配合当前 shared 公式，最终 `C` 区键高只有 `80`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改前 iOS demo 的初始 rowHeight 为 136，顶部控制区不变时，C 区键高为 80。
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

### 修改后

- 修改后，把 iOS demo 的 `rowHeight` 调整为 `216`
- 顶部 `A/B` 区仍保持原尺寸
- 因此新增高度全部进入 `C` 区键面，键区高度从 `80` 变为 `160`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改后 iOS demo 的 rowHeight 调整为 216，使当前配置下的 C 区琴键高度从 80 提升到 160。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 216,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    whiteKeyStyle: .borderlessSeparatedByGaps,
    snapEnabled: true
)
```

## 修改 2：同步调大 macOS demo 的初始钢琴总高度

### 修改前

- macOS 控制器与 iOS 保持同样的初始值
- 因此也同样只有 `80` 的键区高度

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改前 macOS demo 的初始 rowHeight 为 136，当前布局下的 C 区键高为 80。
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

### 修改后

- 修改后，macOS demo 同步把 `rowHeight` 调整到 `216`
- 这样双平台的默认钢琴高度行为保持一致
- `C` 区键面也同步从 `80` 提升到 `160`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: initialPianoDemoConfiguration
// 功能说明: 修改后 macOS demo 同步把 rowHeight 调整为 216，保持与 iOS 一致的双倍键区高度。
private static let initialPianoDemoConfiguration = PianoConfiguration(
    whiteKeyWidth: 30,
    rowHeight: 216,
    rowSpacing: 10,
    scaleAreaHeight: 28,
    buttonAreaWidth: 30,
    blackKeyWidthRatio: 0.62,
    blackKeyHeightRatio: 0.6,
    whiteKeyStyle: .borderlessSeparatedByGaps,
    snapEnabled: true
)
```

## 本次没有改动的部分

- `Shared/Piano/PianoConfiguration.swift` 没改
- 因为这次不需要改变高度换算规则，只需要在现有规则下重新设定 demo 初始总高度
- `PianoPanelState.swift` / `SettingsPanelModel.swift` 也没改
- 因为这次不是新增控制项，而是直接调整默认 demo 参数
- `PianoRowLayer.swift` 和交互 reducer 也没改
- 因为渲染逻辑与交互逻辑都能自动适配新的几何高度

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: keyAreaHeight
// 功能说明: 本次未修改；高度变化完全来自平台控制器中的初始 rowHeight 参数变化。
(未修改，本次记录不重复展开更多代码)
```

## 验证情况

- `ReadLints`：本次修改相关文件无新增诊断
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`：通过
- 本次全量 typecheck 仍有 2 条仓库原有 warning：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次未做双平台手工 UI 回归；当前验证以静态编译和控制器配置差异检查为主

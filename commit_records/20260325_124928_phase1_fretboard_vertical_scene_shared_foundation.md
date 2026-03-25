# 20260325_124928_phase1_fretboard_vertical_scene_shared_foundation

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260325_124928`
- 记录范围：指板竖向 Scene 重构的阶段 1
- 本阶段目标：只建立共享层语义接缝，不改几何映射、不改渲染行为、不改平台布局

## 本阶段完成的修改

1. 新增独立的 `displayMode` 类型，作为后续横向 / 竖向模式的共享入口。
2. 在 `FretboardConfiguration` 中接入 `displayMode`，并补齐“高度反推宽度”的对称尺寸 API。
3. 在 `FretboardDisplayState` 中增加 `displayMode` 代理，保持控制器继续只消费共享状态。
4. 将 `InstrumentTuning` 的弦序命名从“屏幕方向语义”改为“逻辑弦序语义”，为后续 vertical 的“左低右高”做准备。

## 修改 1：新增 `FretboardDisplayMode`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardDisplayMode.swift
// 函数/成员: 无（文件不存在）
// 功能说明: 修改前共享层没有独立的指板显示模式类型，horizontal / vertical 语义还没有入口。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardDisplayMode.swift
// 函数/成员: FretboardDisplayMode
// 功能说明: 为共享层建立 horizontal / vertical 显示模式入口，先只定义语义，不接入几何与渲染细节。
enum FretboardDisplayMode: Equatable, Sendable {
    // 品位沿 x 轴向右递增；弦按低音到高音沿 y 轴向下排列。
    case horizontal
    // 品位沿 y 轴向下递增；弦按低音到高音沿 x 轴向右排列；音名文字保持正立。
    case vertical
}
```

## 修改 2：`FretboardConfiguration` 接入模式和对称尺寸出口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.init(...), resolvedHeight(forAvailableWidth:), heightToWidthMultiplier
// 功能说明: 修改前配置层只有“宽度推高度”链路，没有 displayMode，也没有“高度反推宽度”出口。
struct FretboardConfiguration: Equatable, Sendable {
    // 运行期配置以 tuning 为真相来源，instrument 由 tuning 派生。
    var tuning: InstrumentTuning
    var maxFret: Int
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout

    init(
        tuning: InstrumentTuning = .standard(for: .guitar6),
        maxFret: Int = 12,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.tuning = tuning
        self.maxFret = max(0, maxFret)
        self.layoutMetrics = layoutMetrics
        self.markerLayout = markerLayout
    }

    func resolvedHeight(forAvailableWidth width: CGFloat) -> CGFloat {
        layoutMetrics.totalHeight(
            forAvailableWidth: width,
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
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: FretboardConfiguration.init(...), resolvedHeight(forAvailableWidth:), resolvedWidth(forAvailableHeight:), heightToWidthMultiplier, widthToHeightMultiplier
// 功能说明: 在不改变现有 horizontal 默认行为的前提下，把 displayMode 和“高度反推宽度”能力接入配置层。
struct FretboardConfiguration: Equatable, Sendable {
    // 运行期配置以 tuning 为真相来源，instrument 由 tuning 派生。
    var displayMode: FretboardDisplayMode
    var tuning: InstrumentTuning
    var maxFret: Int
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout

    init(
        displayMode: FretboardDisplayMode = .horizontal,
        tuning: InstrumentTuning = .standard(for: .guitar6),
        maxFret: Int = 12,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.displayMode = displayMode
        self.tuning = tuning
        self.maxFret = max(0, maxFret)
        self.layoutMetrics = layoutMetrics
        self.markerLayout = markerLayout
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

### `LayoutMetrics` 的对称尺寸补充

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: LayoutMetrics.totalWidth(...), LayoutMetrics.widthToHeightMultiplier(...)
// 功能说明: 复用现有 cell 比例真相，先补齐由高度反推宽度的数学出口，为后续 vertical host-height 布局做准备。
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
```

## 修改 3：`FretboardDisplayState` 增加 `displayMode` 代理

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数/成员: FretboardDisplayState.default, init(...)
// 功能说明: 修改前显示状态没有显式暴露 displayMode，默认配置只包含 tuning 和 maxFret。
struct FretboardDisplayState: Equatable, Sendable {
    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool

    static let `default` = FretboardDisplayState(
        configuration: FretboardConfiguration(
            tuning: .standard(for: .guitar6),
            maxFret: 12
        )
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数/成员: FretboardDisplayState.default, displayMode
// 功能说明: 让共享显示状态可以直接代理 configuration.displayMode，后续按钮面板和控制器都走统一状态入口。
struct FretboardDisplayState: Equatable, Sendable {
    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool

    static let `default` = FretboardDisplayState(
        configuration: FretboardConfiguration(
            displayMode: .horizontal,
            tuning: .standard(for: .guitar6),
            maxFret: 12
        )
    )

    // displayMode 仍以 configuration 为真相来源；这里提供共享状态级别的语义代理。
    var displayMode: FretboardDisplayMode {
        get { configuration.displayMode }
        set { configuration.displayMode = newValue }
    }
}
```

## 修改 4：`InstrumentTuning` 的弦序命名去掉屏幕方向耦合

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift
// 函数/成员: openStringsTopToBottom, init(...), openStringPitch(for:)
// 功能说明: 修改前弦序命名绑定了“视觉上从上到下”的屏幕方向，不利于后续 vertical 的左低右高语义。
struct InstrumentTuning: Equatable, Hashable, Sendable {
    var instrument: InstrumentType
    // 空弦顺序固定为视觉上从上到下，对应几何层的 stringIndex 方向。
    var openStringsTopToBottom: [NotePitch]

    init(instrument: InstrumentType, openStringsTopToBottom: [NotePitch]) {
        precondition(
            openStringsTopToBottom.count == instrument.stringCount,
            "Open string count must match instrument string count."
        )

        self.instrument = instrument
        self.openStringsTopToBottom = openStringsTopToBottom
    }

    func openStringPitch(for stringIndex: Int) -> NotePitch? {
        guard openStringsTopToBottom.indices.contains(stringIndex) else {
            return nil
        }

        return openStringsTopToBottom[stringIndex]
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift
// 函数/成员: openStringsLowToHigh, init(...), openStringPitch(for:)
// 功能说明: 把弦序语义改成“逻辑上从低音到高音”，把屏幕方向交给后续 displayMode / geometry 层处理。
struct InstrumentTuning: Equatable, Hashable, Sendable {
    var instrument: InstrumentType
    // 空弦数组按逻辑弦序从低音到高音排列；屏幕显示方向由外层 displayMode 与几何映射决定。
    var openStringsLowToHigh: [NotePitch]

    init(instrument: InstrumentType, openStringsLowToHigh: [NotePitch]) {
        precondition(
            openStringsLowToHigh.count == instrument.stringCount,
            "Open string count must match instrument string count."
        )

        self.instrument = instrument
        self.openStringsLowToHigh = openStringsLowToHigh
    }

    func openStringPitch(for stringIndex: Int) -> NotePitch? {
        guard openStringsLowToHigh.indices.contains(stringIndex) else {
            return nil
        }

        return openStringsLowToHigh[stringIndex]
    }
}
```

### 标准调弦数据的迁移方式

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift
// 函数/成员: guitar6Standard, bass4Standard, bass5Standard
// 功能说明: 数据内容没有变，只把参数名从屏幕方向语义改成了逻辑弦序语义。
static let guitar6Standard = InstrumentTuning(
    instrument: .guitar6,
    openStringsLowToHigh: [
        NotePitch(pitchClass: .e, octave: 2),
        NotePitch(pitchClass: .a, octave: 2),
        NotePitch(pitchClass: .d, octave: 3),
        NotePitch(pitchClass: .g, octave: 3),
        NotePitch(pitchClass: .b, octave: 3),
        NotePitch(pitchClass: .e, octave: 4)
    ]
)
```

## 本阶段未修改的部分

1. 没有修改 `FretboardGeometry`，所以当前命中与几何仍是既有的 horizontal 实现。
2. 没有修改 `FretboardLayer`，所以当前渲染仍按原有横向指板工作。
3. 没有修改 iOS / macOS 平台视图和控制器布局，所以当前仍是“占满宽度，高度自适应”的页面结构。

## 验证结果

1. 已检查本阶段涉及文件的 IDE 诊断，未发现 linter / 语法报错。
2. 本次未执行完整编译，也未运行 UI 验证；后续阶段进入 scene / strategy 重构时再统一做构建和回归。

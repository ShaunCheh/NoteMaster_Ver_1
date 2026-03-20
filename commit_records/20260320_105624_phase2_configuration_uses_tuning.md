20260320_105624_phase2_configuration_uses_tuning

# 阶段 2 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NotePitch.swift`
- 未修改 `InstrumentTuning.swift`
- 未修改 `FretboardGeometry.swift`
- 未修改 `FretboardLayer.swift`

## 修改前

### `FretboardConfiguration` 仍以 `instrument` 为权威

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：init(instrument:maxFret:preferredHeight:layoutMetrics:markerLayout:), stringCount
// 功能说明：修改前配置层仍然直接存 instrument，并通过 instrument.stringCount 推导弦数，运行期还没有以 tuning 作为单一真相来源。
struct FretboardConfiguration: Equatable, Sendable {
    var instrument: InstrumentType
    var maxFret: Int
    var preferredHeight: CGFloat
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout

    init(
        instrument: InstrumentType = .guitar6,
        maxFret: Int = 12,
        preferredHeight: CGFloat = 180,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.instrument = instrument
        self.maxFret = max(0, maxFret)
        self.preferredHeight = max(1, preferredHeight)
        self.layoutMetrics = layoutMetrics
        self.markerLayout = markerLayout
    }

    var stringCount: Int {
        instrument.stringCount
    }
}
```

### 控制器仍通过 `instrument` 初始化配置

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift, NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：fretboardConfiguration
// 功能说明：修改前两个控制器都还是通过 instrument 入口构造默认配置，尚未切换到 tuning 入口。
private let fretboardConfiguration = FretboardConfiguration(
    instrument: .guitar6,
    maxFret: 12,
    preferredHeight: 180
)
```

## 修改后

### `FretboardConfiguration` 以 `tuning` 为运行期真相

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：init(tuning:maxFret:preferredHeight:layoutMetrics:markerLayout:), instrument, stringCount
// 功能说明：配置层改为直接持有 tuning，并把 instrument 与 stringCount 改成从 tuning 派生，避免乐器类型和空弦配置出现双重真相。
struct FretboardConfiguration: Equatable, Sendable {
    // 运行期配置以 tuning 为真相来源，instrument 由 tuning 派生。
    var tuning: InstrumentTuning
    var maxFret: Int
    var preferredHeight: CGFloat
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout

    init(
        tuning: InstrumentTuning = .standard(for: .guitar6),
        maxFret: Int = 12,
        preferredHeight: CGFloat = 180,
        layoutMetrics: LayoutMetrics = .default,
        markerLayout: MarkerLayout = .standard
    ) {
        self.tuning = tuning
        self.maxFret = max(0, maxFret)
        self.preferredHeight = max(1, preferredHeight)
        self.layoutMetrics = layoutMetrics
        self.markerLayout = markerLayout
    }

    var instrument: InstrumentType {
        tuning.instrument
    }

    var stringCount: Int {
        tuning.stringCount
    }
}
```

### 保留兼容性的 `instrument` 初始化入口

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：init(instrument:maxFret:preferredHeight:layoutMetrics:markerLayout:)
// 功能说明：为了不让旧调用点瞬间失效，保留 instrument 入口，但内部统一转成 InstrumentTuning.standard(for:)。
init(
    instrument: InstrumentType,
    maxFret: Int = 12,
    preferredHeight: CGFloat = 180,
    layoutMetrics: LayoutMetrics = .default,
    markerLayout: MarkerLayout = .standard
) {
    self.init(
        tuning: .standard(for: instrument),
        maxFret: maxFret,
        preferredHeight: preferredHeight,
        layoutMetrics: layoutMetrics,
        markerLayout: markerLayout
    )
}
```

### 两个平台控制器切到 `tuning` 入口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift, NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：fretboardConfiguration
// 功能说明：两个控制器的默认配置改为显式使用标准调弦，避免继续扩散旧的 instrument 入口。
private let fretboardConfiguration = FretboardConfiguration(
    tuning: .standard(for: .guitar6),
    maxFret: 12,
    preferredHeight: 180
)
```

## 结果说明

- 阶段 2 的核心结果是把配置层从“乐器类型驱动”收敛成“调弦驱动”，让 `tuning` 成为运行期唯一真相来源。
- `instrument` 现在只是 `tuning.instrument` 的派生结果，`stringCount` 也不再依赖 `InstrumentType` 直接推导。
- 两个平台控制器已经同步切到 `tuning` 入口，后续 provider 可以直接从 `configuration.tuning` 读取空弦音高。
- 本次还没有引入 provider 和音名绘制，只是先把配置层的数据源收干净。

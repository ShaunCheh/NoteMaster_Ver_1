20260320_173743_phase1_fixed_lane_height_configuration

# 固定弦高阶段 1 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 配置层仍以固定总高为真相

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：init(tuning:maxFret:preferredHeight:layoutMetrics:markerLayout:), preferredHeight
// 功能说明：修改前 configuration 把 preferredHeight 作为存储属性保存，固定总高是运行期真相，弦数变化不会自动影响总高度。
struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        var stringEdgeInsetRatio: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            stringEdgeInsetRatio: 0.09,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )
    }

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
}
```

### 默认显示状态里还写死了 180 高度

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数名：default
// 功能说明：修改前默认 displayState 在构造 configuration 时显式写死 preferredHeight: 180，因此默认高度不会随弦数自动派生。
static let `default` = FretboardDisplayState(
    configuration: FretboardConfiguration(
        tuning: .standard(for: .guitar6),
        maxFret: 12,
        preferredHeight: 180
    )
)
```

## 修改后

### 配置层引入固定弦高并把总高改成派生值

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：stringBandHeight(forStringCount:), drawingHeight(forStringCount:), preferredHeight(forStringCount:), preferredHeight
// 功能说明：修改后配置层新增 stringLaneHeight 作为垂直布局真相，并根据弦数、stringEdgeInsetRatio、verticalInsetRatio 派生总高度 preferredHeight。
struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        var stringEdgeInsetRatio: CGFloat
        // 每根弦占据的垂直车道高度，弦位应落在车道中心。
        var stringLaneHeight: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            stringEdgeInsetRatio: 0.09,
            stringLaneHeight: 17,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )

        private static let minimumLayoutFactor: CGFloat = 0.01

        func stringBandHeight(forStringCount stringCount: Int) -> CGFloat {
            CGFloat(max(stringCount, 1)) * max(stringLaneHeight, 1)
        }

        func drawingHeight(forStringCount stringCount: Int) -> CGFloat {
            let stringBandHeight = stringBandHeight(forStringCount: stringCount)
            let stringBandFactor = max(
                1 - (stringEdgeInsetRatio * 2),
                Self.minimumLayoutFactor
            )
            return stringBandHeight / stringBandFactor
        }

        func preferredHeight(forStringCount stringCount: Int) -> CGFloat {
            let drawingHeight = drawingHeight(forStringCount: stringCount)
            let drawingFactor = max(
                1 - (verticalInsetRatio * 2),
                Self.minimumLayoutFactor
            )
            return drawingHeight / drawingFactor
        }
    }

    var tuning: InstrumentTuning
    var maxFret: Int
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout

    var preferredHeight: CGFloat {
        layoutMetrics.preferredHeight(forStringCount: stringCount)
    }
}
```

### 构造器移除固定总高输入

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：init(tuning:maxFret:layoutMetrics:markerLayout:), init(instrument:maxFret:layoutMetrics:markerLayout:)
// 功能说明：修改后 configuration 的两个构造器都不再接收 preferredHeight 参数，高度完全由派生规则决定，避免出现“双重真相”。
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

init(
    instrument: InstrumentType,
    maxFret: Int = 12,
    layoutMetrics: LayoutMetrics = .default,
    markerLayout: MarkerLayout = .standard
) {
    self.init(
        tuning: .standard(for: instrument),
        maxFret: maxFret,
        layoutMetrics: layoutMetrics,
        markerLayout: markerLayout
    )
}
```

### 默认显示状态去掉硬编码高度

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数名：default
// 功能说明：修改后默认 displayState 不再写死 preferredHeight: 180，而是依赖 configuration 根据默认弦数自动派生高度。
static let `default` = FretboardDisplayState(
    configuration: FretboardConfiguration(
        tuning: .standard(for: .guitar6),
        maxFret: 12
    )
)
```

## 结果说明

- 阶段 1 的核心结果是把“固定弦高”引入配置层，并让总高度从弦数自动派生。
- 当前高度真相已经从“固定总高”切换成“固定 stringLaneHeight + 派生 preferredHeight”。
- 默认显示状态也不再硬编码 `180` 高度。
- 这一阶段还没有修改几何层的弦位排布算法，所以“弦位于固定弦高中心”的几何语义要到下一阶段才会真正落地。
- 已执行 `ReadLints` 检查且无报错；补全按钮面板视图依赖后，`xcrun swiftc -typecheck` 通过。

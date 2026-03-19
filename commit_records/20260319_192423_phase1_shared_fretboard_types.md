20260319_192423_phase1_shared_fretboard_types

# 阶段 1 修改记录

## 本次变更范围

- 新增共享目录 `NoteMaster_Ver_1/Shared/Fretboard`
- 新增 `InstrumentType.swift`
- 新增 `FretboardConfiguration.swift`
- 未修改 `iOSViewController.swift`、`macOSViewController.swift`、`iOSAppDelegate.swift`、`macOSAppDelegate.swift`

## 修改前

### 共享指板目录

```bash
# 文件路径：NoteMaster_Ver_1/Shared/Fretboard
# 函数名：无
# 功能说明：修改前项目中不存在共享指板目录，平台层也没有可复用的指板模型类型。
ls: NoteMaster_Ver_1/Shared/Fretboard: No such file or directory
```

### 乐器枚举

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/InstrumentType.swift
// 函数名：无（文件不存在）
// 功能说明：修改前没有统一的乐器枚举，无法在共享层稳定表达 6 弦吉他、4 弦贝斯、5 弦贝斯。
// 该文件在修改前不存在。
```

### 指板配置

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：无（文件不存在）
// 功能说明：修改前没有共享配置对象，最高品、高度、marker 规则和布局参数都没有统一承载位置。
// 该文件在修改前不存在。
```

## 修改后

### 新增目录结构

```bash
# 文件路径：NoteMaster_Ver_1/Shared/Fretboard
# 函数名：无
# 功能说明：新增共享指板目录，先承载阶段 1 的类型定义，为后续几何计算和 CALayer 绘制打底。
InstrumentType.swift
FretboardConfiguration.swift
```

### 新增 `InstrumentType.swift`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/InstrumentType.swift
// 函数名：stringCount
// 功能说明：定义三种乐器类型，并统一输出弦数，后续共享绘制层不需要再在平台侧分别判断。
enum InstrumentType: CaseIterable, Sendable {
    case guitar6
    case bass4
    case bass5

    var stringCount: Int {
        switch self {
        case .guitar6:
            return 6
        case .bass4:
            return 4
        case .bass5:
            return 5
        }
    }
}
```

### 新增 `FretboardConfiguration.swift`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：init(...), allMarkerFrets(upTo:), normalizedSingleDotFrets(upTo:), normalizedDoubleDotFrets(upTo:)
// 功能说明：统一承载乐器、最高品、组件高度、布局比例和 marker 规则，并在进入绘制前完成基础归一化。
import CoreGraphics

struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )
    }

    struct MarkerLayout: Equatable, Sendable {
        var singleDotFrets: [Int]
        var doubleDotFrets: [Int]

        static let standard = MarkerLayout(
            singleDotFrets: [3, 5, 7, 9],
            doubleDotFrets: [12]
        )

        func allMarkerFrets(upTo maxFret: Int) -> [Int] {
            Array(Set(
                normalizedSingleDotFrets(upTo: maxFret)
                + normalizedDoubleDotFrets(upTo: maxFret)
            )).sorted()
        }

        func normalizedSingleDotFrets(upTo maxFret: Int) -> [Int] {
            Self.normalize(singleDotFrets, maxFret: maxFret)
        }

        func normalizedDoubleDotFrets(upTo maxFret: Int) -> [Int] {
            Self.normalize(doubleDotFrets, maxFret: maxFret)
        }

        private static func normalize(_ frets: [Int], maxFret: Int) -> [Int] {
            Array(Set(frets.filter { $0 > 0 && $0 <= maxFret })).sorted()
        }
    }

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

    var fretRange: ClosedRange<Int> {
        0...maxFret
    }

    var stringCount: Int {
        instrument.stringCount
    }
}
```

## 结果说明

- 这次只完成了共享模型边界的建立，没有接入任何视图，也没有开始 `CALayer` 绘制。
- `InstrumentType` 已经把三种目标乐器和弦数统一抽象出来。
- `FretboardConfiguration` 已经把 `maxFret`、`preferredHeight`、默认 marker 规则以及后续绘制所需的布局比例集中到共享层。
- 后续阶段 2 和阶段 3 可以直接基于这两个文件实现几何规则和共享渲染层，无需再把参数定义散落到平台代码里。

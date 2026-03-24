20260324_211742_phase1_fretboard_width_first_configuration_foundation

# Phase 1 Fretboard Width-First Configuration Foundation 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`

## 修改前

### `LayoutMetrics` 仍以固定弦高作为尺寸真相，只能按弦数反推总高度

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：LayoutMetrics.stringBandHeight(forStringCount:) / drawingHeight(forStringCount:) / preferredHeight(forStringCount:)
// 功能说明：修改前共享配置层只有“固定弦高 -> 绘制高度 -> 总高度”这一条链路；
// 指板总高只和 `stringLaneHeight`、`stringCount`、`verticalInsetRatio` 有关，还没有“宽度优先”的比例真相。
struct LayoutMetrics: Equatable, Sendable {
    var horizontalInsetRatio: CGFloat
    var verticalInsetRatio: CGFloat
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
        stringBandHeight(forStringCount: stringCount)
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
```

### `FretboardConfiguration` 只暴露与宽度无关的 `preferredHeight`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：stringCount / preferredHeight
// 功能说明：修改前配置对象只向平台层暴露固定高度出口；
// 平台视图无法直接从配置层拿到“给定宽度时应有多高”或“高宽比例系数”。
var stringCount: Int {
    tuning.stringCount
}

var preferredHeight: CGFloat {
    layoutMetrics.preferredHeight(forStringCount: stringCount)
}
```

## 修改后

### `LayoutMetrics` 新增 cell 宽高比，并补齐宽度优先的派生 API

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：LayoutMetrics.drawingWidth(forAvailableWidth:) / cellWidth(forAvailableWidth:displayPositionCount:) / cellHeight(forAvailableWidth:displayPositionCount:) / drawingHeight(forAvailableWidth:displayPositionCount:stringCount:) / totalHeight(forAvailableWidth:displayPositionCount:stringCount:) / heightToWidthMultiplier(displayPositionCount:stringCount:) / legacyPreferredHeight(forStringCount:)
// 功能说明：修改后共享配置层把 `cellWidthToHeightRatio` 引入为宽度优先链路的真相来源；
// 新增“给定宽度 -> cell 宽 -> cell 高 -> drawingHeight -> totalHeight”的完整派生路径，
// 同时保留 `legacyPreferredHeight` 作为后续平台尺寸出口迁移前的兼容层。
struct LayoutMetrics: Equatable, Sendable {
    var horizontalInsetRatio: CGFloat
    var verticalInsetRatio: CGFloat
    // 宽度优先链路的真相来源：单个显示格子的宽高比（width / height）。
    var cellWidthToHeightRatio: CGFloat
    // 兼容旧的固定弦高链路；后续平台尺寸出口迁移完成后移除。
    var stringLaneHeight: CGFloat
    var nutWidthRatio: CGFloat
    var fretLineWidth: CGFloat
    var stringLineWidth: CGFloat
    var markerDiameterRatio: CGFloat
    var doubleMarkerOffsetRatio: CGFloat

    static let `default` = LayoutMetrics(
        horizontalInsetRatio: 0.04,
        verticalInsetRatio: 0.16,
        cellWidthToHeightRatio: 1.6,
        stringLaneHeight: 17,
        nutWidthRatio: 0.014,
        fretLineWidth: 1,
        stringLineWidth: 1.5,
        markerDiameterRatio: 0.15,
        doubleMarkerOffsetRatio: 0.18
    )

    private static let minimumLayoutFactor: CGFloat = 0.01
    private static let minimumAspectRatio: CGFloat = 0.01

    private var drawingWidthFactor: CGFloat {
        max(1 - (horizontalInsetRatio * 2), Self.minimumLayoutFactor)
    }

    private var drawingHeightFactor: CGFloat {
        max(1 - (verticalInsetRatio * 2), Self.minimumLayoutFactor)
    }

    private var resolvedCellWidthToHeightRatio: CGFloat {
        max(cellWidthToHeightRatio, Self.minimumAspectRatio)
    }

    func drawingWidth(forAvailableWidth width: CGFloat) -> CGFloat {
        max(width, 0) * drawingWidthFactor
    }

    func cellWidth(
        forAvailableWidth width: CGFloat,
        displayPositionCount: Int
    ) -> CGFloat {
        let resolvedDisplayPositionCount = max(displayPositionCount, 1)
        return drawingWidth(forAvailableWidth: width) / CGFloat(resolvedDisplayPositionCount)
    }

    func cellHeight(
        forAvailableWidth width: CGFloat,
        displayPositionCount: Int
    ) -> CGFloat {
        cellWidth(
            forAvailableWidth: width,
            displayPositionCount: displayPositionCount
        ) / resolvedCellWidthToHeightRatio
    }

    func drawingHeight(
        forAvailableWidth width: CGFloat,
        displayPositionCount: Int,
        stringCount: Int
    ) -> CGFloat {
        CGFloat(max(stringCount, 1)) * cellHeight(
            forAvailableWidth: width,
            displayPositionCount: displayPositionCount
        )
    }

    func totalHeight(
        forAvailableWidth width: CGFloat,
        displayPositionCount: Int,
        stringCount: Int
    ) -> CGFloat {
        drawingHeight(
            forAvailableWidth: width,
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        ) / drawingHeightFactor
    }

    func heightToWidthMultiplier(
        displayPositionCount: Int,
        stringCount: Int
    ) -> CGFloat {
        let resolvedDisplayPositionCount = max(displayPositionCount, 1)
        let resolvedStringCount = max(stringCount, 1)
        return drawingWidthFactor
            / drawingHeightFactor
            * CGFloat(resolvedStringCount)
            / (CGFloat(resolvedDisplayPositionCount) * resolvedCellWidthToHeightRatio)
    }

    func legacyPreferredHeight(forStringCount stringCount: Int) -> CGFloat {
        let stringBandHeight = CGFloat(max(stringCount, 1)) * max(stringLaneHeight, 1)
        return stringBandHeight / drawingHeightFactor
    }
}
```

### `FretboardConfiguration` 新增宽度驱动出口，但继续保留旧的 `preferredHeight`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：displayPositionCount / resolvedHeight(forAvailableWidth:) / heightToWidthMultiplier / preferredHeight
// 功能说明：修改后配置对象能够直接提供“当前列数语义”“给定宽度时的总高度”“高宽比例系数”；
// 为避免阶段 1 直接冲击平台层，`preferredHeight` 仍暂时回落到兼容链路。
var stringCount: Int {
    tuning.stringCount
}

var displayPositionCount: Int {
    maxFret + 1
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

// 兼容当前平台尺寸出口；后续阶段改为消费宽度优先的 resolvedHeight/heightToWidthMultiplier。
var preferredHeight: CGFloat {
    layoutMetrics.legacyPreferredHeight(forStringCount: stringCount)
}
```

## 结果说明

- 共享配置层已经具备“宽度优先”的尺寸派生能力，后续 `FretboardGeometry` 和双平台视图可以直接消费 `resolvedHeight(forAvailableWidth:)` 或 `heightToWidthMultiplier`。
- `displayPositionCount` 已收口到配置层，继续保持“空弦区不单独建模，仍按 `maxFret + 1` 等宽列处理”的语义。
- 阶段 1 仍保留 `stringLaneHeight` 和旧的 `preferredHeight`，目的是在几何层和平台层尚未同步迁移前，避免先把现有指板高度出口打断。
- 本阶段没有修改 `FretboardGeometry`、`NoteNameContentProvider`、`iOSFretboardView`、`macOSFretboardView`。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`，无新增诊断。
- 已执行 Swift 源码级类型检查，结果通过。
- 当前机器的 developer directory 指向 `CommandLineTools`，未使用 `xcodebuild` 作为本阶段验证入口。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对项目 Swift 源码执行静态类型检查，确认阶段 1 的共享配置层改动没有引入编译期错误。
swiftc -typecheck NoteMaster_Ver_1/**/*.swift
```

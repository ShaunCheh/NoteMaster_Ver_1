20260320_124627_phase1_shared_interaction_model

# Raw 事件阶段 1 修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 共享层还没有 raw 事件交互模型文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift
// 函数名：无（文件不存在）
// 功能说明：修改前 Shared/Fretboard 下还没有专门承载 raw 事件阶段和命中结果的共享模型文件，因此后续 iOS/macOS 原始事件无法共用统一的数据结构。
// 该文件在修改前不存在。
```

### raw 事件语义在共享层没有统一承载位置

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard
// 函数名：无
// 功能说明：修改前共享层已有配置、几何、渲染和音名 provider 等能力，但还没有“事件阶段 / 命中单元 / 命中结果”的统一交互语义模型。
InstrumentType.swift
InstrumentTuning.swift
FretboardConfiguration.swift
FretboardGeometry.swift
FretboardLayer.swift
FretboardContentProvider.swift
NoteNameContentProvider.swift
NotePitch.swift
```

## 修改后

### 新增共享交互模型 `FretboardInteraction.swift`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift
// 函数名：stringIndex, fret, hasHit
// 功能说明：新增 FretboardEventPhase、FretboardCell、FretboardHitResult，统一 raw 事件阶段、命中的弦品单元，以及平台包装视图向外抛出的命中结果格式。
import CoreGraphics

enum FretboardEventPhase: Equatable, Sendable {
    case began
    case moved
    case ended
    case cancelled
}

struct FretboardCell: Equatable, Hashable, Sendable {
    var stringIndex: Int
    // 0 表示空弦区域，1...maxFret 表示实际按弦区。
    var fret: Int
}

struct FretboardHitResult: Equatable, Sendable {
    var phase: FretboardEventPhase
    // 使用平台包装视图本地坐标，和 FretboardGeometry 的 bounds 语义保持一致。
    var locationInView: CGPoint
    var cell: FretboardCell?
    var isInsideDrawingRect: Bool
    var distanceToNearestString: CGFloat?

    var stringIndex: Int? {
        cell?.stringIndex
    }

    var fret: Int? {
        cell?.fret
    }

    var hasHit: Bool {
        cell != nil
    }
}
```

### 新增模型的职责边界

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift
// 函数名：FretboardEventPhase, FretboardCell, FretboardHitResult
// 功能说明：阶段 1 只先定义共享语义，不在这个阶段实现几何命中算法，也不在平台视图中接入 touches 或 mouse 事件。
enum FretboardEventPhase {
    case began
    case moved
    case ended
    case cancelled
}

struct FretboardCell {
    var stringIndex: Int
    var fret: Int
}

struct FretboardHitResult {
    var phase: FretboardEventPhase
    var locationInView: CGPoint
    var cell: FretboardCell?
    var isInsideDrawingRect: Bool
    var distanceToNearestString: CGFloat?
}
```

## 结果说明

- 阶段 1 的核心结果是先把 raw 事件链路要共用的交互语义模型固定下来。
- 这样阶段 2 在 `FretboardGeometry` 中实现 `hitTest` 时，就可以直接返回统一的 `FretboardHitResult`，避免 iOS/macOS 后续各自长出不同结构。
- 当前这一步还没有接入 `touchesBegan / mouseDown`，也没有打印控制台日志；它只负责把共享数据结构准备好。
- 已对共享指板模块执行 `xcrun swiftc -typecheck`，本次新增文件通过静态类型检查。

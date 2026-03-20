20260320_135850_phase5_controller_console_output

# Raw 事件阶段 5 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`

## 修改前

### 共享交互模型还没有统一的控制台日志格式

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift
// 函数名：hasHit
// 功能说明：修改前共享交互模型只提供命中数据本身，还没有统一的调试字符串格式；如果直接在控制器打印，iOS 和 macOS 很容易各自拼出不同的日志结构。
import CoreGraphics

enum FretboardEventPhase: Equatable, Sendable {
    case began
    case moved
    case ended
    case cancelled
}

struct FretboardHitResult: Equatable, Sendable {
    var phase: FretboardEventPhase
    var locationInView: CGPoint
    var cell: FretboardCell?
    var isInsideDrawingRect: Bool
    var distanceToNearestString: CGFloat?

    var hasHit: Bool {
        cell != nil
    }
}
```

### iOS 控制器还没有装配 `onRawEvent`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：fretboardView
// 功能说明：修改前 iOS 控制器只负责装配 noteContentProvider，没有把 raw 命中结果接出来，因此不会往控制台输出任何点击结果。
private lazy var fretboardView: iOSFretboardView = {
    let fretboardView = iOSFretboardView(configuration: fretboardConfiguration)
    fretboardView.contentProvider = noteContentProvider
    return fretboardView
}()
```

### macOS 控制器还没有装配 `onRawEvent`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：fretboardView
// 功能说明：修改前 macOS 控制器同样只装配了 noteContentProvider，还没有把 raw mouse 命中结果接到控制台输出链路上。
private lazy var fretboardView: macOSFretboardView = {
    let fretboardView = macOSFretboardView(configuration: fretboardConfiguration)
    fretboardView.contentProvider = noteContentProvider
    return fretboardView
}()
```

## 修改后

### 共享交互模型新增统一调试日志格式

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift
// 函数名：debugName, debugSummary(platform:)
// 功能说明：修改后共享交互模型开始统一管理 raw 事件的调试字符串格式，让 iOS 和 macOS 都复用同一套日志拼接规则。
import Foundation
import CoreGraphics

enum FretboardEventPhase: Equatable, Sendable {
    case began
    case moved
    case ended
    case cancelled

    var debugName: String {
        switch self {
        case .began:
            return "began"
        case .moved:
            return "moved"
        case .ended:
            return "ended"
        case .cancelled:
            return "cancelled"
        }
    }
}

struct FretboardHitResult: Equatable, Sendable {
    var phase: FretboardEventPhase
    var locationInView: CGPoint
    var cell: FretboardCell?
    var isInsideDrawingRect: Bool
    var distanceToNearestString: CGFloat?

    func debugSummary(platform: String) -> String {
        let pointText = String(
            format: "(%.1f, %.1f)",
            locationInView.x,
            locationInView.y
        )
        let stringText = stringIndex.map(String.init) ?? "nil"
        let fretText = fret.map(String.init) ?? "nil"
        let distanceText = distanceToNearestString.map {
            String(format: "%.1f", $0)
        } ?? "nil"

        return "[\(platform)] phase=\(phase.debugName) string=\(stringText) fret=\(fretText) point=\(pointText) inside=\(isInsideDrawingRect) distance=\(distanceText)"
    }
}
```

### iOS 控制器接入 raw 命中结果并打印

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：fretboardView
// 功能说明：修改后 iOS 控制器在创建指板视图时装配 onRawEvent，把共享命中结果直接打印到控制台。
private lazy var fretboardView: iOSFretboardView = {
    let fretboardView = iOSFretboardView(configuration: fretboardConfiguration)
    fretboardView.contentProvider = noteContentProvider
    fretboardView.onRawEvent = { hitResult in
        print(hitResult.debugSummary(platform: "iOS"))
    }
    return fretboardView
}()
```

### macOS 控制器接入 raw 命中结果并打印

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：fretboardView
// 功能说明：修改后 macOS 控制器同样在创建指板视图时装配 onRawEvent，把共享命中结果直接打印到控制台。
private lazy var fretboardView: macOSFretboardView = {
    let fretboardView = macOSFretboardView(configuration: fretboardConfiguration)
    fretboardView.contentProvider = noteContentProvider
    fretboardView.onRawEvent = { hitResult in
        print(hitResult.debugSummary(platform: "macOS"))
    }
    return fretboardView
}()
```

### 控制台输出格式被统一收敛到共享层

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift, NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift, NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：debugSummary(platform:), fretboardView
// 功能说明：阶段 5 后，控制器只负责选择平台标识并调用 print，具体日志格式完全由共享层统一输出。
let summary = hitResult.debugSummary(platform: "iOS")
print(summary)

let macSummary = hitResult.debugSummary(platform: "macOS")
print(macSummary)
```

## 结果说明

- 阶段 5 的核心结果是：raw 事件命中结果已经正式接入 iOS 和 macOS 控制器，并能直接输出到控制台。
- 共享层新增 `debugSummary(platform:)` 后，日志格式不再散落在两个控制器里，后续如果要调整打印格式，只需要改一处。
- 当前控制台输出格式固定为：`[platform] phase=... string=... fret=... point=(x, y) inside=... distance=...`。
- 已对相关共享文件、平台视图和两个控制器执行 `xcrun swiftc -typecheck`，补全 `NoteNameContentProvider.swift` 与 `FretboardLayer.swift` 依赖后检查通过，`ReadLints` 也无报错。

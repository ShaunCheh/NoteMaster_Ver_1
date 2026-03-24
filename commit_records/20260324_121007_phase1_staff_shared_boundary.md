20260324_121007_phase1_staff_shared_boundary

# Staff 阶段 1 共享边界修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- 新增 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 未修改现有 `Fretboard` 渲染、几何和平台包装实现

## 修改前

### 修改前只有 `Fretboard` 域的共享配置骨架，没有 `Staff` 对应的共享配置与坐标方向类型

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名：FretboardConfiguration.LayoutMetrics.preferredHeight(forStringCount:), FretboardConfiguration.preferredHeight
// 功能说明：修改前项目只有指板域的配置、布局参数和首选高度计算；五线谱域还没有独立的 configuration、clef、renderMode、canvasOrientation 入口。
import CoreGraphics

struct FretboardConfiguration: Equatable, Sendable {
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

        func preferredHeight(forStringCount stringCount: Int) -> CGFloat {
            let drawingHeight = drawingHeight(forStringCount: stringCount)
            let drawingFactor = max(
                1 - (verticalInsetRatio * 2),
                Self.minimumLayoutFactor
            )
            return drawingHeight / drawingFactor
        }
    }

    var preferredHeight: CGFloat {
        layoutMetrics.preferredHeight(forStringCount: stringCount)
    }
}
```

### 修改前只有 `FretboardDisplayState` 这种“状态 -> provider”的共享状态模式，没有 `Staff` 对应状态入口

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数名：FretboardDisplayState.contentProvider（计算属性）
// 功能说明：修改前控制器只存在指板域的共享状态派生入口；五线谱域还没有对应的 display state 和 sceneProvider 入口。
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

    // 控制器只维护共享状态，provider 统一从状态派生。
    var contentProvider: NoteNameContentProvider {
        NoteNameContentProvider(
            visibility: visibility,
            spelling: spelling,
            showsOctave: showsOctave
        )
    }
}
```

## 修改后

### 1. 新增显式的 `Staff` 画布方向类型，固定左上角原点、`y` 向下

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift
// 函数名：StaffCanvasOrientation.standard（静态属性）
// 功能说明：把五线谱域的统一逻辑坐标显式建模，避免后续几何层和渲染层再去隐式猜测平台坐标方向。
struct StaffCanvasOrientation: Equatable, Sendable {
    enum Origin: Equatable, Sendable {
        case topLeft
    }

    enum VerticalAxisDirection: Equatable, Sendable {
        case down
    }

    var origin: Origin
    var verticalAxisDirection: VerticalAxisDirection

    static let standard = Self(
        origin: .topLeft,
        verticalAxisDirection: .down
    )
}
```

### 2. 新增 `StaffConfiguration`，把布局参数、clef、renderMode 和首选高度计算收敛到共享配置层

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：LayoutMetrics.staffHeight(), LayoutMetrics.minimumDrawingHeight(), LayoutMetrics.preferredHeight(), StaffConfiguration.preferredHeight（计算属性）
// 功能说明：新增 Staff 域配置边界，并把 canvasOrientation 纳入配置；阶段 1 就为后续 geometry/renderer 统一输入契约。
import CoreGraphics

// 显式保留未来的 glyph 后端切换点；阶段 1/4 仍默认回落到 CoreText。
enum MusicGlyphRenderMode: Equatable, Sendable {
    case automatic
    case coreText
    case cgPath
}

enum StaffClef: Equatable, Sendable {
    case treble
}

struct StaffConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        var staffLineCount: Int
        // 相邻两条 staff line 之间的垂直距离。
        var staffSpaceHeight: CGFloat
        var clefAreaWidthRatio: CGFloat
        var staffLineWidth: CGFloat
        // clef 的目标高度相对于 staff 高度的比例。
        var clefScale: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.08,
            verticalInsetRatio: 0.18,
            staffLineCount: 5,
            staffSpaceHeight: 12,
            clefAreaWidthRatio: 0.22,
            staffLineWidth: 1,
            clefScale: 1.6
        )

        func staffHeight() -> CGFloat {
            CGFloat(normalizedStaffLineCount - 1) * normalizedStaffSpaceHeight
        }

        // 首版需要给 treble clef 预留超出五线高度的可绘制空间。
        func minimumDrawingHeight() -> CGFloat {
            let resolvedStaffHeight = staffHeight()
            return max(resolvedStaffHeight, resolvedStaffHeight * max(clefScale, 1))
        }

        func preferredHeight() -> CGFloat {
            let drawingFactor = max(
                1 - (verticalInsetRatio * 2),
                Self.minimumLayoutFactor
            )
            return minimumDrawingHeight() / drawingFactor
        }
    }

    // Shared/Staff 统一约定使用左上原点、y 向下的逻辑坐标。
    var canvasOrientation: StaffCanvasOrientation
    var clef: StaffClef
    var renderMode: MusicGlyphRenderMode
    var layoutMetrics: LayoutMetrics

    var preferredHeight: CGFloat {
        layoutMetrics.preferredHeight()
    }
}
```

### 3. 新增阶段 1 的 `StaffSceneProvider` 占位入口，先把“状态 -> 场景入口”边界建起来

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数名：init(clef:)
// 功能说明：阶段 1 先固定场景入口类型，只保留 clef 语义；真正基于 geometry 生成 lineSegments/glyphs 的逻辑留到阶段 2。
// 阶段 1 先固定“状态 -> 场景入口”的共享边界；
// 真正基于 geometry 产出 scene 的逻辑留到阶段 2 再补齐。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef

    init(clef: StaffClef = .treble) {
        self.clef = clef
    }
}
```

### 4. 新增 `StaffDisplayState`，对齐现有 `FretboardDisplayState` 的控制器状态模型

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数名：sceneProvider（计算属性）
// 功能说明：让控制器未来只维护 StaffConfiguration，再由共享状态统一派生 StaffSceneProvider，避免平台层直接拼装场景入口。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration

    static let `default` = StaffDisplayState(
        configuration: StaffConfiguration()
    )

    // 控制器只维护共享状态，scene provider 统一从状态派生。
    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(clef: configuration.clef)
    }
}
```

## 结果与边界变化

- `Shared/Staff` 目录从无到有，阶段 1 已经形成最小可编译的共享域骨架。
- `Staff` 域的坐标契约已经从计划文本变成代码类型：左上角原点、`y` 向下。
- `Staff` 域的配置边界已经落下，不再需要等到 geometry/renderer 阶段再反向决定 clef、renderMode 或 preferredHeight 的归属。
- 控制器未来可以直接对齐 `FretboardDisplayState` 的使用方式，先持有 `StaffDisplayState`，再从共享状态派生 `sceneProvider`。
- 阶段 2 还未实现 `StaffGeometry`、`ClefAnchor`、`StaffScene` 真正的几何与语义场景模型；当前 `StaffSceneProvider` 仍是占位入口，这一点本次没有提前越界实现。

## 验证情况

- `ReadLints` 检查新增文件后，没有新增诊断。
- 使用 `swiftc -typecheck` 对以下文件进行了静态类型检查，并已通过：
  - `NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
  - `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 尝试使用 `xcodebuild` 做工程级编译验证时失败，原因是当前机器的 active developer directory 指向 `CommandLineTools`，不是完整 Xcode；因此本次没有拿到工程级 build 结果。

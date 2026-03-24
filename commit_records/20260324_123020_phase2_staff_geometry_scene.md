20260324_123020_phase2_staff_geometry_scene

# Staff 阶段 2 几何与语义场景修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`

## 修改前

### 修改前 `StaffSceneProvider` 仍是阶段 1 的占位入口，还不能从 geometry 产出语义场景

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数名：init(clef:)
// 功能说明：修改前 provider 只保存 clef 语义，不包含 lineSegments、glyphs，也没有 geometry -> scene 的投影能力。
// 阶段 1 先固定“状态 -> 场景入口”的共享边界；
// 真正基于 geometry 产出 scene 的逻辑留到阶段 2 再补齐。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef

    init(clef: StaffClef = .treble) {
        self.clef = clef
    }
}
```

### 修改前还没有 `StaffGeometry`，五线、clef 区域和逻辑锚点都没有共享几何模型

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数名：无
// 功能说明：修改前该文件不存在；drawingRect、staffRect、clefAreaRect、lineY、spaceCenterY、clefAnchor 都还没有共享层实现。
// 文件不存在
```

### 修改前还没有 `StaffScene`，语义锚点和 glyph 场景结构也未建立

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数名：无
// 功能说明：修改前该文件不存在；ClefAnchor、StaffGlyphItem、StaffScene 等语义模型尚未定义。
// 文件不存在
```

## 修改后

### 1. 新增 `StaffGeometry`，把五线谱首版所需的共享几何计算集中到单一模型

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数名：drawingRect, staffRect, clefAreaRect, staffLineSegments, lineY(at:), spaceCenterY(at:), clefAnchor(for:)
// 功能说明：新增共享几何层，统一负责可绘制区域、五线位置、clef 区域和 treble clef 语义锚点计算。
import CoreGraphics

struct StaffGeometry: Equatable, Sendable {
    struct StaffLineSegment: Equatable, Sendable {
        var lineIndex: Int
        var start: CGPoint
        var end: CGPoint
    }

    let configuration: StaffConfiguration
    let bounds: CGRect
    let orientation: StaffCanvasOrientation

    init(
        configuration: StaffConfiguration,
        bounds: CGRect,
        orientation: StaffCanvasOrientation? = nil
    ) {
        self.configuration = configuration
        self.bounds = bounds.standardized
        self.orientation = orientation ?? configuration.canvasOrientation
    }

    var staffRect: CGRect {
        CGRect(
            x: drawingRect.minX,
            y: staffTopY,
            width: drawingRect.width,
            height: staffHeight
        )
    }

    var clefAreaRect: CGRect {
        CGRect(
            x: drawingRect.minX,
            y: drawingRect.minY,
            width: resolvedClefAreaWidth,
            height: drawingRect.height
        )
    }

    var staffLineSegments: [StaffLineSegment] {
        (0..<resolvedStaffLineCount).compactMap { lineIndex in
            guard let y = lineY(at: lineIndex) else {
                return nil
            }

            return StaffLineSegment(
                lineIndex: lineIndex,
                start: CGPoint(x: drawingRect.minX, y: y),
                end: CGPoint(x: drawingRect.maxX, y: y)
            )
        }
    }

    func lineY(at index: Int) -> CGFloat? {
        guard index >= 0, index < resolvedStaffLineCount else {
            return nil
        }

        return staffTopY + (CGFloat(index) * resolvedStaffSpaceHeight)
    }

    func clefAnchor(for clef: StaffClef) -> ClefAnchor {
        switch clef {
        case .treble:
            return ClefAnchor(
                point: CGPoint(
                    x: clefAreaRect.midX,
                    y: lineY(at: 3) ?? staffRect.midY
                ),
                semantic: .trebleGLine,
                targetHeight: max(staffRect.height * configuration.layoutMetrics.clefScale, 1)
            )
        }
    }
}
```

### 2. 新增 `StaffScene`，把几何事实和渲染后端之间的语义层补齐

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数名：ClefAnchor, StaffGlyphRenderHint.staffClef, StaffScene.empty
// 功能说明：新增语义场景层，统一表达 clef 锚点、glyph 标识、颜色、渲染提示和最终 scene 结构，不向上泄漏 CoreText baseline。
import CoreGraphics

struct ClefAnchor: Equatable, Sendable {
    enum Semantic: Equatable, Sendable {
        case trebleGLine
    }

    // 语义锚点使用共享逻辑坐标，不暴露 CoreText baseline。
    var point: CGPoint
    var semantic: Semantic
    var targetHeight: CGFloat
}

enum StaffGlyphSymbolID: Equatable, Sendable {
    case trebleClef
}

struct StaffGlyphRenderHint: Equatable, Sendable {
    var preservesAspectRatio: Bool
    var prefersOpticalBoundsAlignment: Bool

    static let staffClef = StaffGlyphRenderHint(
        preservesAspectRatio: true,
        prefersOpticalBoundsAlignment: true
    )
}

enum StaffGlyphPlacement: Equatable, Sendable {
    case anchor(ClefAnchor)
    case frame(CGRect)
}

struct StaffGlyphItem: Equatable, Sendable {
    var symbolID: StaffGlyphSymbolID
    var placement: StaffGlyphPlacement
    var tintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint
}

struct StaffScene: Equatable, Sendable {
    var lineSegments: [StaffGeometry.StaffLineSegment]
    var glyphs: [StaffGlyphItem]

    static let empty = StaffScene(
        lineSegments: [],
        glyphs: []
    )
}
```

### 3. `StaffSceneProvider` 从占位入口升级为真正的 `geometry -> scene` 投影器

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数名：init(clef:glyphTintColor:), makeScene(geometry:), symbolID(for:)
// 功能说明：修改后 provider 开始消费 StaffGeometry，并产出 lineSegments + trebleClef glyph 的首版 StaffScene。
// provider 只负责把共享状态投影成语义场景，不处理字体度量和绘制细节。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var glyphTintColor: StaffSceneColor

    init(
        clef: StaffClef = .treble,
        glyphTintColor: StaffSceneColor = .primaryInk
    ) {
        self.clef = clef
        self.glyphTintColor = glyphTintColor
    }

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
        }

        let glyphs = [
            StaffGlyphItem(
                symbolID: symbolID(for: clef),
                placement: .anchor(geometry.clefAnchor(for: clef)),
                tintColor: glyphTintColor,
                renderHint: .staffClef
            )
        ]

        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            glyphs: glyphs
        )
    }

    private func symbolID(for clef: StaffClef) -> StaffGlyphSymbolID {
        switch clef {
        case .treble:
            return .trebleClef
        }
    }
}
```

## 结果与边界变化

- `Staff` 域现在已经从“只有配置和状态入口”升级到“配置 + 几何 + 语义场景”三层共享结构。
- 坐标与布局规则已经进入代码：
  - `drawingRect`
  - `staffRect`
  - `clefAreaRect`
  - `lineY(at:)`
  - `spaceCenterY(at:)`
  - `clefAnchor(for:)`
- `treble clef` 的首版锚点语义已经固定到 `.trebleGLine`，并通过 `lineY(at: 3)` 落到共享逻辑坐标。
- `StaffSceneProvider` 现在可以稳定地把 `StaffGeometry` 投影成 `StaffScene`，为后续字体映射和渲染器接入准备好输入。
- 本次仍然没有实现字体注册、Bravura glyph 映射、CoreText renderer、平台 layer/view 接入，这些边界没有越界进入阶段 3/4/5。

## 验证情况

- `ReadLints` 检查阶段 2 相关文件后，没有新增诊断。
- 使用 `swiftc -typecheck` 对以下文件进行了静态类型检查，并已通过：
  - `NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
  - `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 本次没有执行工程级 `xcodebuild` 验证；当前确认范围是共享层静态类型检查通过。

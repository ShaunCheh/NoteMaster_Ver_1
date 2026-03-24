20260324_143037_phase5_staff_shared_layers

# Staff 阶段 5 共享 Layer 组合修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/MusicGlyphRendererFactory.swift`

## 修改前

### 修改前还没有 `StaffRootLayer`，几何、场景和子 layer 之间没有统一的共享宿主层

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：无
// 功能说明：修改前该文件不存在；configuration -> geometry -> scene -> child layers 的共享组合链路还没有建立。
// 文件不存在
```

### 修改前还没有 `StaffLinesLayer`，五线绘制还没有从根层职责中单独拆出

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift
// 函数名：无
// 功能说明：修改前该文件不存在；五线的纯几何绘制还没有独立的共享 layer 承载。
// 文件不存在
```

### 修改前还没有 `StaffGlyphLayer`，scene 中的 glyph 也没有独立的共享 layer 去消费 renderer

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift
// 函数名：无
// 功能说明：修改前该文件不存在；scene.glyphs 虽然已经能被 renderer 消费，但还没有专门的共享 layer 负责遍历和绘制。
// 文件不存在
```

## 修改后

### 1. 新增 `StaffRootLayer`，把 configuration、geometry、scene 和子 layer 分发串起来

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：configureLayer(), applySharedLayerSettings(), updatePresentationModel(), layoutSublayers()
// 功能说明：新增共享根 layer，负责托管五线层和 glyph 层，并在 bounds/configuration/sceneProvider 变化时重建 geometry 与 scene，再分发给子层。
import Foundation
import QuartzCore

enum StaffContextNormalizationMode: Equatable, Sendable {
    case none
    case flipYToTopLeft
}

final class StaffRootLayer: CALayer {
    var configuration: StaffConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            updatePresentationModel()
        }
    }

    var sceneProvider: StaffSceneProvider = .init() {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            updatePresentationModel()
        }
    }

    var contextNormalizationMode: StaffContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            applySharedLayerSettings()
        }
    }

    private let linesLayer = StaffLinesLayer()
    private let glyphLayer = StaffGlyphLayer()

    override func layoutSublayers() {
        super.layoutSublayers()
        applySharedLayerSettings()
        updatePresentationModel()
    }

    private func applySharedLayerSettings() {
        linesLayer.frame = bounds
        glyphLayer.frame = bounds
        linesLayer.contentsScale = contentsScale
        glyphLayer.contentsScale = contentsScale
        linesLayer.contextNormalizationMode = contextNormalizationMode
        glyphLayer.contextNormalizationMode = contextNormalizationMode
        glyphLayer.resourceBundle = resourceBundle
    }

    private func updatePresentationModel() {
        applySharedLayerSettings()

        let geometry = StaffGeometry(
            configuration: configuration,
            bounds: bounds,
            orientation: configuration.canvasOrientation
        )
        let scene = sceneProvider.makeScene(geometry: geometry)

        linesLayer.strokeWidth = configuration.layoutMetrics.staffLineWidth
        linesLayer.lineSegments = scene.lineSegments

        glyphLayer.configuration = configuration
        glyphLayer.geometry = geometry
        glyphLayer.glyphs = scene.glyphs
    }
}
```

### 2. 新增 `StaffLinesLayer`，把五线绘制收口到纯几何 layer

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift
// 函数名：draw(in:), applyContextNormalizationIfNeeded(in:), configureLayer()
// 功能说明：新增五线 layer，只消费 geometry 产出的 lineSegments，负责纯几何描边，不接触字体和 glyph renderer。
import CoreGraphics
import QuartzCore

final class StaffLinesLayer: CALayer {
    var lineSegments: [StaffGeometry.StaffLineSegment] = [] {
        didSet {
            guard oldValue != lineSegments else {
                return
            }

            setNeedsDisplay()
        }
    }

    var strokeColorModel: StaffSceneColor = .primaryInk
    var strokeWidth: CGFloat = 1
    var contextNormalizationMode: StaffContextNormalizationMode = .none

    override func draw(in context: CGContext) {
        guard !lineSegments.isEmpty else {
            return
        }

        context.saveGState()
        applyContextNormalizationIfNeeded(in: context)
        context.setStrokeColor(strokeColorModel.cgColor)
        context.setLineWidth(max(strokeWidth, 1))
        context.setLineCap(.round)

        for lineSegment in lineSegments {
            context.move(to: lineSegment.start)
            context.addLine(to: lineSegment.end)
        }

        context.strokePath()
        context.restoreGState()
    }

    private func applyContextNormalizationIfNeeded(in context: CGContext) {
        switch contextNormalizationMode {
        case .none:
            return
        case .flipYToTopLeft:
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
        }
    }
}
```

### 3. 新增 `StaffGlyphLayer`，把 scene.glyphs 与 renderer factory 接起来

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift
// 函数名：draw(in:), applyContextNormalizationIfNeeded(in:), configureLayer()
// 功能说明：新增 glyph layer，遍历 scene.glyphs，并通过 MusicGlyphRendererFactory 调用当前配置的 glyph 后端。
import Foundation
import CoreGraphics
import QuartzCore

// StaffGlyphLayer 只消费 renderer 协议，不直接依赖具体 CoreText 细节。
final class StaffGlyphLayer: CALayer {
    var configuration: StaffConfiguration = .init()
    var geometry: StaffGeometry?
    var glyphs: [StaffGlyphItem] = []
    var contextNormalizationMode: StaffContextNormalizationMode = .none
    var resourceBundle: Bundle = .main

    override func draw(in context: CGContext) {
        guard
            let geometry,
            !glyphs.isEmpty
        else {
            return
        }

        let renderer = MusicGlyphRendererFactory.makeRenderer(
            renderMode: configuration.renderMode,
            bundle: resourceBundle
        )

        context.saveGState()
        applyContextNormalizationIfNeeded(in: context)

        for glyph in glyphs {
            renderer.draw(
                glyphItem: glyph,
                in: context,
                geometry: geometry,
                canvasOrientation: geometry.orientation
            )
        }

        context.restoreGState()
    }

    private func applyContextNormalizationIfNeeded(in context: CGContext) {
        switch contextNormalizationMode {
        case .none:
            return
        case .flipYToTopLeft:
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
        }
    }
}
```

## 结果与边界变化

- `Staff` 域现在已经从“有 geometry、有 scene、有 renderer”升级到“有共享 root layer + 两个职责清晰的子 layer”。
- `StaffRootLayer` 已经形成稳定的数据流：
  - `configuration`
  - `StaffGeometry`
  - `StaffScene`
  - `StaffLinesLayer` / `StaffGlyphLayer`
- 平台坐标归一化的共享入口已经显式建模为 `StaffContextNormalizationMode`，为后面平台 view 接入 `none / flipYToTopLeft` 做好了共享层准备。
- `StaffLinesLayer` 只负责五线几何绘制，`StaffGlyphLayer` 只负责遍历 glyph 并调用 renderer，职责边界已经分开。
- 本次仍然没有实现 `iOSStaffView`、`macOSStaffView`、控制器接入和最终页面展示，阶段边界保持在 5。

## 验证情况

- `ReadLints` 检查阶段 5 相关文件后，没有新增诊断。
- 使用 `swiftc -typecheck` 对以下共享层文件进行了静态类型检查，并已通过：
  - `NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicFontRegistry.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicGlyphRenderer.swift`
  - `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
  - `NoteMaster_Ver_1/Shared/Staff/MusicGlyphRendererFactory.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
  - `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`
  - `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 本次没有执行工程级 `xcodebuild` 验证；当前确认范围是共享层静态类型检查和编辑器诊断通过。

20260324_192151_phase2_staff_lines_drawtime_geometry

# Phase 2 Staff Lines Draw-Time Geometry 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`

## 修改前

### `StaffLinesLayer` 仍依赖 root 推送的 `lineSegments` 与 `strokeWidth` 快照

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift
// 函数名：lineSegments.didSet / strokeWidth.didSet / init(layer:) / draw(in:)
// 功能说明：修改前五线谱 layer 的真相来源是外部传入的 `lineSegments` 和 `strokeWidth`；
// `draw(in:)` 只负责消费快照数组描边，无法在每次绘制时直接基于当前 bounds 现算几何。
final class StaffLinesLayer: CALayer {
    var lineSegments: [StaffGeometry.StaffLineSegment] = [] {
        didSet {
            guard oldValue != lineSegments else {
                return
            }

            setNeedsDisplay()
        }
    }

    var strokeWidth: CGFloat = 1 {
        didSet {
            guard oldValue != strokeWidth else {
                return
            }

            setNeedsDisplay()
        }
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? StaffLinesLayer {
            lineSegments = otherLayer.lineSegments
            strokeColorModel = otherLayer.strokeColorModel
            strokeWidth = otherLayer.strokeWidth
            contextNormalizationMode = otherLayer.contextNormalizationMode
        }
    }

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
}
```

### `StaffRootLayer` 还在把 `scene.lineSegments` 推给五线谱 layer

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：applySharedLayerSettings() / updatePresentationModel()
// 功能说明：修改前 root layer 虽然已经有阶段 1 的 resize 刷新入口，
// 但五线谱数据仍然来自 `scene.lineSegments` 快照，并由 root 在 presentation 更新时推送给 lines layer。
final class StaffRootLayer: CALayer {
    private func applySharedLayerSettings() {
        performWithoutImplicitAnimations {
            linesLayer.frame = bounds
            glyphLayer.frame = bounds
            linesLayer.contentsScale = contentsScale
            glyphLayer.contentsScale = contentsScale
            linesLayer.contextNormalizationMode = contextNormalizationMode
            glyphLayer.contextNormalizationMode = contextNormalizationMode
            glyphLayer.resourceBundle = resourceBundle
        }
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
        invalidateSublayerDisplay()
    }
}
```

## 修改后

### `StaffLinesLayer` 改为在 `draw(in:)` 中按当前 `bounds` 现算 `StaffGeometry`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift
// 函数名：configuration.didSet / orientation.didSet / init(layer:) / draw(in:)
// 功能说明：修改后五线谱 layer 不再缓存 `lineSegments` / `strokeWidth`，
// 而是直接持有 `configuration` 和 `orientation`，在每次绘制时基于当前 bounds 构造 `StaffGeometry`，
// 再用 `geometry.staffLineSegments` 和 `configuration.layoutMetrics.staffLineWidth` 画线。
final class StaffLinesLayer: CALayer {
    var configuration: StaffConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            setNeedsDisplay()
        }
    }

    var orientation: StaffCanvasOrientation = .standard {
        didSet {
            guard oldValue != orientation else {
                return
            }

            setNeedsDisplay()
        }
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? StaffLinesLayer {
            configuration = otherLayer.configuration
            strokeColorModel = otherLayer.strokeColorModel
            orientation = otherLayer.orientation
            contextNormalizationMode = otherLayer.contextNormalizationMode
        }
    }

    override func draw(in context: CGContext) {
        let geometry = StaffGeometry(
            configuration: configuration,
            bounds: bounds,
            orientation: orientation
        )
        let lineSegments = geometry.staffLineSegments
        guard !lineSegments.isEmpty else {
            return
        }

        context.saveGState()
        applyContextNormalizationIfNeeded(in: context)
        context.setStrokeColor(strokeColorModel.cgColor)
        context.setLineWidth(max(configuration.layoutMetrics.staffLineWidth, 1))
        context.setLineCap(.round)

        for lineSegment in lineSegments {
            context.move(to: lineSegment.start)
            context.addLine(to: lineSegment.end)
        }

        context.strokePath()
        context.restoreGState()
    }
}
```

### `StaffRootLayer` 断开 `lineSegments` 快照推送，只同步 lines layer 的最小输入

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：applySharedLayerSettings() / updatePresentationModel()
// 功能说明：修改后 root layer 不再把 `scene.lineSegments` 和 `strokeWidth` 推给 lines layer，
// 而是只同步 `configuration`、`canvasOrientation`、frame、contentsScale 和 contextNormalizationMode；
// 五线谱的几何真相来源正式切到 lines layer 自己的 draw-time 计算。
final class StaffRootLayer: CALayer {
    private func applySharedLayerSettings() {
        performWithoutImplicitAnimations {
            linesLayer.frame = bounds
            linesLayer.configuration = configuration
            linesLayer.orientation = configuration.canvasOrientation
            glyphLayer.frame = bounds
            linesLayer.contentsScale = contentsScale
            glyphLayer.contentsScale = contentsScale
            linesLayer.contextNormalizationMode = contextNormalizationMode
            glyphLayer.contextNormalizationMode = contextNormalizationMode
            glyphLayer.resourceBundle = resourceBundle
        }
    }

    private func updatePresentationModel() {
        applySharedLayerSettings()
        let geometry = StaffGeometry(
            configuration: configuration,
            bounds: bounds,
            orientation: configuration.canvasOrientation
        )
        let scene = sceneProvider.makeScene(geometry: geometry)

        glyphLayer.configuration = configuration
        glyphLayer.geometry = geometry
        glyphLayer.glyphs = scene.glyphs
        invalidateSublayerDisplay()
    }
}
```

## 结果说明

- `StaffLinesLayer` 的真相来源已从“root 推送的线段快照”切到“当前 bounds + configuration + orientation”。
- `StaffRootLayer` 已不再直接控制五线谱线段数组，只负责同步共享输入和继续维护 glyph 的旧路径。
- 这一阶段只迁移了五线谱；`clef` 的 geometry / scene 仍然保留在 `StaffGlyphLayer` 的旧快照链路，留到阶段 3 处理。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift` 与 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`，无新增诊断。
- 已执行 staff 相关文件与 `macOSStaffView.swift` 的静态类型检查，结果通过。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对阶段 2 涉及的 Staff 共享层与 macOS 视图执行静态类型检查，确认 draw-time 线段迁移后可通过编译期校验。
xcrun swiftc -parse-as-library -typecheck \
  "NoteMaster_Ver_1/Shared/Staff/MusicFontRegistry.swift" \
  "NoteMaster_Ver_1/Shared/Staff/StaffScene.swift" \
  "NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift" \
  "NoteMaster_Ver_1/Shared/Staff/StaffCanvasOrientation.swift" \
  "NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift" \
  "NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift" \
  "NoteMaster_Ver_1/Shared/Staff/MusicGlyphRenderer.swift" \
  "NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift" \
  "NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift" \
  "NoteMaster_Ver_1/Shared/Staff/MusicGlyphRendererFactory.swift" \
  "NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift" \
  "NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift" \
  "NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift" \
  "NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift"
```

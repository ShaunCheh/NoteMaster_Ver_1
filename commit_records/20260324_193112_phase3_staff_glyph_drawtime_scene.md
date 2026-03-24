20260324_193112_phase3_staff_glyph_drawtime_scene

# Phase 3 Staff Glyph Draw-Time Scene 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`

## 修改前

### `StaffGlyphLayer` 仍依赖 root 推送的 `geometry` 与 `glyphs` 快照

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift
// 函数名：geometry.didSet / glyphs.didSet / init(layer:) / draw(in:)
// 功能说明：修改前 glyph layer 只消费外部传入的 `geometry` 和 `glyphs`；
// `draw(in:)` 不会基于当前 bounds 自己现算 geometry，也不会自己向 sceneProvider 取 glyph scene。
final class StaffGlyphLayer: CALayer {
    var geometry: StaffGeometry? {
        didSet {
            guard oldValue != geometry else {
                return
            }

            setNeedsDisplay()
        }
    }

    var glyphs: [StaffGlyphItem] = [] {
        didSet {
            guard oldValue != glyphs else {
                return
            }

            setNeedsDisplay()
        }
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? StaffGlyphLayer {
            configuration = otherLayer.configuration
            geometry = otherLayer.geometry
            glyphs = otherLayer.glyphs
            contextNormalizationMode = otherLayer.contextNormalizationMode
            resourceBundle = otherLayer.resourceBundle
        }

        configureLayer()
    }

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
}
```

### `StaffRootLayer` 还在现算 glyph 的 `geometry + scene` 并推给 glyph layer

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：applySharedLayerSettings() / updatePresentationModel()
// 功能说明：修改前 root layer 虽然已经把五线谱迁到 draw-time，
// 但 clef glyph 仍然通过 `updatePresentationModel()` 现算 geometry / scene，再把结果快照推给 glyph layer。
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

## 修改后

### `StaffGlyphLayer` 改为在 `draw(in:)` 中按当前 `bounds` 现算 `geometry` 与 glyph scene

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift
// 函数名：sceneProvider.didSet / init(layer:) / draw(in:)
// 功能说明：修改后 glyph layer 不再缓存 `geometry` 和 `glyphs`，
// 而是直接持有 `sceneProvider`，并在每次绘制时基于当前 bounds 构造 `StaffGeometry`，
// 然后即时调用 `sceneProvider.makeScene(geometry:)` 取 glyph scene 再交给 renderer。
final class StaffGlyphLayer: CALayer {
    var sceneProvider: StaffSceneProvider = .init() {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            setNeedsDisplay()
        }
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let otherLayer = layer as? StaffGlyphLayer {
            configuration = otherLayer.configuration
            sceneProvider = otherLayer.sceneProvider
            contextNormalizationMode = otherLayer.contextNormalizationMode
            resourceBundle = otherLayer.resourceBundle
        }

        configureLayer()
    }

    override func draw(in context: CGContext) {
        let geometry = StaffGeometry(
            configuration: configuration,
            bounds: bounds,
            orientation: configuration.canvasOrientation
        )
        let glyphs = sceneProvider.makeScene(geometry: geometry).glyphs
        guard !glyphs.isEmpty else {
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
}
```

### `StaffRootLayer` 断开 glyph 快照推送，只同步 glyph layer 的最小输入

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：applySharedLayerSettings() / updatePresentationModel()
// 功能说明：修改后 root layer 不再构造 glyph 的 `geometry` / `scene` 快照，
// 而是只同步 `glyphLayer.configuration`、`glyphLayer.sceneProvider`、frame、contentsScale、contextNormalizationMode 和 resourceBundle；
// glyph 的真相来源正式切到 glyph layer 自己的 draw-time 计算。
final class StaffRootLayer: CALayer {
    private func applySharedLayerSettings() {
        performWithoutImplicitAnimations {
            linesLayer.frame = bounds
            linesLayer.configuration = configuration
            linesLayer.orientation = configuration.canvasOrientation
            glyphLayer.frame = bounds
            glyphLayer.configuration = configuration
            glyphLayer.sceneProvider = sceneProvider
            linesLayer.contentsScale = contentsScale
            glyphLayer.contentsScale = contentsScale
            linesLayer.contextNormalizationMode = contextNormalizationMode
            glyphLayer.contextNormalizationMode = contextNormalizationMode
            glyphLayer.resourceBundle = resourceBundle
        }
    }

    private func updatePresentationModel() {
        applySharedLayerSettings()
        invalidateSublayerDisplay()
    }
}
```

## 结果说明

- `StaffGlyphLayer` 的真相来源已从“root 推送的 geometry/glyphs 快照”切到“当前 bounds + configuration + sceneProvider”。
- `StaffRootLayer` 已不再负责 clef glyph 的 geometry / scene 计算，只继续承担共享输入同步与统一失效。
- 到这一阶段，五线谱和 clef 都已经切到 draw-time 计算路径；阶段 4 只需要继续清理 root 的命名和失效职责，不再改绘制真相来源。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift` 与 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`，无新增诊断。
- 已执行 staff 相关文件与 `macOSStaffView.swift` 的静态类型检查，结果通过。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对阶段 3 涉及的 Staff 共享层与 macOS 视图执行静态类型检查，确认 glyph draw-time 迁移后可通过编译期校验。
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

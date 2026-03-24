20260324_130940_phase4_staff_coretext_renderer

# Staff 阶段 4 CoreText 渲染器修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Staff/MusicGlyphRenderer.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- 新增 `NoteMaster_Ver_1/Shared/Staff/MusicGlyphRendererFactory.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/MusicGlyph.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/MusicFontRegistry.swift`

## 修改前

### 修改前还没有统一的 glyph renderer 协议，后端切换点尚未建立

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicGlyphRenderer.swift
// 函数名：无
// 功能说明：修改前该文件不存在；StaffScene 与具体渲染后端之间还没有稳定的共享协议，renderMode 也没有实际分发落点。
// 文件不存在
```

### 修改前还没有 `CoreTextMusicGlyphRenderer`，`StaffScene` 中的 glyph 还不能真正走 CoreText 测量和绘制链路

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：无
// 功能说明：修改前该文件不存在；Bravura glyph 虽然已经有符号映射和字体注册，但还没有变成 CTLine 并按 ClefAnchor 落到逻辑坐标。
// 文件不存在
```

### 修改前还没有 `MusicGlyphRendererFactory`，`renderMode` 仍停留在配置层，没有真正落到后端分发

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicGlyphRendererFactory.swift
// 函数名：无
// 功能说明：修改前该文件不存在；.automatic / .coreText / .cgPath 还没有统一的 renderer 选择入口。
// 文件不存在
```

## 修改后

### 1. 新增 `MusicGlyphRenderer` 协议，固定后端无关的渲染接口

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicGlyphRenderer.swift
// 函数名：draw(glyphItem:in:geometry:canvasOrientation:)
// 功能说明：新增统一的 glyph 渲染后端接口，把 scene/geometry 和具体 CoreText/CGPath 实现隔离开来。
import CoreGraphics

// renderer 是唯一的 glyph 后端切换点；未来接入 CGPath 时不要改 scene 或 geometry 协议。
protocol MusicGlyphRenderer {
    func draw(
        glyphItem: StaffGlyphItem,
        in context: CGContext,
        geometry: StaffGeometry,
        canvasOrientation: StaffCanvasOrientation
    )
}
```

### 2. 新增 `CoreTextMusicGlyphRenderer`，把 Bravura glyph 变成 `CTLine` 并按 `ClefAnchor` 落位

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：draw(glyphItem:in:geometry:canvasOrientation:), resolvedGlyphLine(for:targetSize:tintColor:), drawAnchoredGlyph(_:anchor:in:geometry:), drawLine(_:at:in:geometry:)
// 功能说明：新增 CoreText 后端，从 MusicGlyph + MusicFontRegistry 构建 CTLine，做 optical bounds 拟合，并把 baseline/锚点补偿收口在 renderer 内部。
import Foundation
import CoreGraphics
import CoreText

struct CoreTextMusicGlyphRenderer: MusicGlyphRenderer {
    private struct ResolvedGlyphLine {
        var line: CTLine
        var bounds: CGRect
    }

    private struct AnchorMetrics {
        var xRatio: CGFloat
        var yRatio: CGFloat
    }

    func draw(
        glyphItem: StaffGlyphItem,
        in context: CGContext,
        geometry: StaffGeometry,
        canvasOrientation: StaffCanvasOrientation
    ) {
        guard canvasOrientation == .standard else {
            assertionFailure("CoreTextMusicGlyphRenderer currently supports top-left/down orientation only.")
            return
        }

        let musicGlyph = glyphItem.symbolID.musicGlyph
        let targetSize = targetSize(
            for: glyphItem,
            geometry: geometry
        )

        guard let resolvedLine = resolvedGlyphLine(
            for: musicGlyph,
            targetSize: targetSize,
            tintColor: glyphItem.tintColor
        ) else {
            return
        }

        switch glyphItem.placement {
        case let .anchor(anchor):
            drawAnchoredGlyph(
                resolvedLine,
                anchor: anchor,
                in: context,
                geometry: geometry
            )
        case let .frame(frame):
            drawGlyph(
                resolvedLine,
                centeredIn: frame,
                in: context,
                geometry: geometry
            )
        }
    }

    private func resolvedGlyphLine(
        for glyph: MusicGlyph,
        targetSize: CGSize,
        tintColor: StaffSceneColor
    ) -> ResolvedGlyphLine? {
        let baseFontSize = max(targetSize.height, 1)
        // 先按目标高度建字，再根据 optical bounds 二次收缩。
        guard var resolved = makeResolvedGlyphLine(
            glyph: glyph,
            fontSize: baseFontSize,
            tintColor: tintColor
        ) else {
            return nil
        }

        let widthScale = targetSize.width / max(resolved.bounds.width, 1)
        let heightScale = targetSize.height / max(resolved.bounds.height, 1)
        let fitScale = min(1, widthScale, heightScale)

        if fitScale < 1 {
            resolved = makeResolvedGlyphLine(
                glyph: glyph,
                fontSize: max(baseFontSize * fitScale, 1),
                tintColor: tintColor
            ) ?? resolved
        }

        return resolved
    }

    private func drawAnchoredGlyph(
        _ resolvedLine: ResolvedGlyphLine,
        anchor: ClefAnchor,
        in context: CGContext,
        geometry: StaffGeometry
    ) {
        let anchorMetrics = self.anchorMetrics(for: anchor.semantic)
        let anchorOffset = CGPoint(
            x: resolvedLine.bounds.minX + (resolvedLine.bounds.width * anchorMetrics.xRatio),
            y: resolvedLine.bounds.minY + (resolvedLine.bounds.height * anchorMetrics.yRatio)
        )
        let flippedAnchor = CGPoint(
            x: anchor.point.x,
            y: geometry.bounds.height - anchor.point.y
        )
        let drawOrigin = CGPoint(
            x: flippedAnchor.x - anchorOffset.x,
            y: flippedAnchor.y - anchorOffset.y
        )

        drawLine(
            resolvedLine.line,
            at: drawOrigin,
            in: context,
            geometry: geometry
        )
    }

    private func drawLine(
        _ line: CTLine,
        at origin: CGPoint,
        in context: CGContext,
        geometry: StaffGeometry
    ) {
        context.saveGState()
        context.textMatrix = .identity

        // 当前共享坐标固定为左上原点、y 向下；CoreText 绘制时在 renderer 内部局部翻回 y 向上。
        context.translateBy(x: 0, y: geometry.bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.textPosition = origin
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
```

### 3. 新增 `MusicGlyphRendererFactory`，把 `renderMode` 真正落到后端分发

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/MusicGlyphRendererFactory.swift
// 函数名：makeRenderer(renderMode:bundle:)
// 功能说明：新增渲染器工厂，把配置层的 renderMode 连接到具体后端，并为未来 CGPath renderer 预留唯一接入点。
import Foundation

enum MusicGlyphRendererFactory {
    // future CGPath backend 应只在这里接入，不要回改 scene、geometry 或平台 view 协议。
    static func makeRenderer(
        renderMode: MusicGlyphRenderMode,
        bundle: Bundle = .main
    ) -> any MusicGlyphRenderer {
        switch renderMode {
        case .automatic, .coreText:
            return CoreTextMusicGlyphRenderer(bundle: bundle)
        case .cgPath:
            assertionFailure("CGPath glyph renderer is not implemented yet; falling back to CoreText.")
            return CoreTextMusicGlyphRenderer(bundle: bundle)
        }
    }
}
```

## 结果与边界变化

- `Staff` 域现在已经从“有配置、有 geometry、有 scene”进入“scene 可以真正被 glyph renderer 消费”的阶段。
- `renderMode` 不再只是配置项，已经通过 `MusicGlyphRendererFactory` 真正落到后端选择。
- `CoreTextMusicGlyphRenderer` 已经完成：
  - `MusicGlyph` -> `CTLine`
  - optical bounds 拟合
  - `ClefAnchor` 驱动的锚点绘制
  - renderer 内部局部坐标翻转
- baseline/optical bounds 的补偿被收口在 renderer 内部，没有回流到 `StaffSceneProvider` 或 `StaffGeometry`。
- 本次仍然没有实现 `StaffRootLayer`、`StaffGlyphLayer`、`StaffLinesLayer`、`iOSStaffView`、`macOSStaffView`，阶段边界保持在 4。

## 验证情况

- `ReadLints` 检查阶段 4 相关文件后，没有新增诊断。
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
  - `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 本次没有执行工程级 `xcodebuild` 验证；当前确认范围是共享层静态类型检查和编辑器诊断通过。

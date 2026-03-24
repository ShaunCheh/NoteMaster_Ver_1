20260324_191230_phase1_staff_resize_root_live_resize

# Phase 1 Staff Resize Root Live Resize 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift`

## 修改前

### `StaffRootLayer` 仍在 layout 和属性变更时直接生成快照，并且子 layer frame 更新没有显式关闭隐式动画

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：configuration.didSet / sceneProvider.didSet / layoutSublayers() / applySharedLayerSettings() / updatePresentationModel()
// 功能说明：修改前 root layer 在配置变化、provider 变化以及 layout 阶段都会直接生成 geometry / scene 快照，
// 同时对子 layer 的 frame 和共享属性赋值没有包在禁用 action 的事务里；在 macOS live resize 期间，
// 旧内容可能先被系统按新 frame 临时拉伸，再等下一次重绘纠正。
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

### `macOSStaffView` 只在普通状态下等待 `setNeedsDisplay`，live resize 期间缺少主动刷新入口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift
// 函数名：viewDidMoveToWindow() / configureView() / applyState()
// 功能说明：修改前 macOS 视图使用 `.onSetNeedsDisplay`，拖动窗口时没有在 frame 变化或 live resize 生命周期里
// 主动驱动 root layer 立即刷新；因此五线谱宽度经常要等鼠标停下后才整体更新。
final class macOSStaffView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
    }

    private func configureView() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyState()
    }

    private func applyState() {
        var resolvedConfiguration = configuration
        resolvedConfiguration.canvasOrientation = .standard

        staffRootLayer.configuration = resolvedConfiguration
        staffRootLayer.sceneProvider = sceneProvider
        staffRootLayer.contextNormalizationMode = .flipYToTopLeft
        staffRootLayer.resourceBundle = .main
        updateContentsScale()
        invalidateIntrinsicContentSize()
    }
}
```

## 修改后

### `StaffRootLayer` 增加统一刷新入口，并在共享 layer 属性同步时禁用隐式动画

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：configuration.didSet / sceneProvider.didSet / layoutSublayers() / applySharedLayerSettings() / refreshForCurrentBounds(displayImmediately:) / invalidateLegacyPresentationSnapshot() / performWithoutImplicitAnimations(_:)
// 功能说明：修改后 root layer 先收口为“同步子 layer 共享状态 + 触发失效/刷新”的职责，
// 在 frame、contentsScale、上下文模式同步时统一关闭隐式动画，并提供 `refreshForCurrentBounds` 供 macOS live resize 主动调用，
// 为后续阶段把 geometry / scene 真正迁移到 draw-time 计算打基础。
final class StaffRootLayer: CALayer {
    var configuration: StaffConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            invalidateLegacyPresentationSnapshot()
        }
    }

    var sceneProvider: StaffSceneProvider = .init() {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            invalidateLegacyPresentationSnapshot()
        }
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        refreshForCurrentBounds()
    }

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

    func refreshForCurrentBounds(displayImmediately: Bool = false) {
        updatePresentationModel()
        if displayImmediately {
            linesLayer.displayIfNeeded()
            glyphLayer.displayIfNeeded()
        }
    }

    private func invalidateLegacyPresentationSnapshot() {
        setNeedsLayout()
        refreshForCurrentBounds()
    }

    private func performWithoutImplicitAnimations(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updates()
        CATransaction.commit()
    }
}
```

### `macOSStaffView` 改成 live resize 友好的 redraw policy，并在 resize 生命周期里主动刷新 root layer

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift
// 函数名：viewDidMoveToWindow() / setFrameSize(_:) / viewWillStartLiveResize() / viewDidEndLiveResize() / configureView() / applyState() / refreshPresentationForResize(displayImmediately:)
// 功能说明：修改后 macOS 视图把 redraw policy 切到 `.duringViewResize`，
// 并在 frame 变化、live resize 开始/结束、状态应用后都主动调用 root layer 刷新，
// 让五线谱和 clef 在窗口拖动过程中更早进入正确的重绘节奏。
final class macOSStaffView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
        refreshPresentationForResize(displayImmediately: false)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshPresentationForResize(displayImmediately: inLiveResize)
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        refreshPresentationForResize(displayImmediately: true)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        refreshPresentationForResize(displayImmediately: true)
    }

    private func configureView() {
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        applyState()
    }

    private func applyState() {
        var resolvedConfiguration = configuration
        resolvedConfiguration.canvasOrientation = .standard

        staffRootLayer.configuration = resolvedConfiguration
        staffRootLayer.sceneProvider = sceneProvider
        staffRootLayer.contextNormalizationMode = .flipYToTopLeft
        staffRootLayer.resourceBundle = .main
        updateContentsScale()
        refreshPresentationForResize(displayImmediately: false)
        invalidateIntrinsicContentSize()
    }

    private func refreshPresentationForResize(displayImmediately: Bool) {
        guard let staffRootLayer = layer as? StaffRootLayer else {
            return
        }

        staffRootLayer.refreshForCurrentBounds(displayImmediately: displayImmediately)
    }
}
```

## 结果说明

- `StaffRootLayer` 已具备阶段 1 需要的统一刷新入口，后续阶段可以直接把 draw-time 现算迁入子 layer，而不用再改平台层调用面。
- macOS 端现在会在 live resize 过程中更积极地同步 root layer，而不是只等普通的 `setNeedsDisplay` 节奏。
- 这一阶段仍然保留了 `updatePresentationModel()` 的 geometry / scene 快照逻辑；真正的根因迁移会在阶段 2 和阶段 3 完成。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift` 与 `NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift`，无新增诊断。
- 已执行 staff 相关文件与 `macOSStaffView.swift` 的静态类型检查，结果通过。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对本次阶段 1 涉及的 Staff 共享层与 macOS 视图执行静态类型检查，确认修改后可通过编译期校验。
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

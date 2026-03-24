20260324_193658_phase4_staff_root_invalidation_cleanup

# Phase 4 Staff Root Invalidation Cleanup 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift`

## 修改前

### `StaffRootLayer` 仍保留 `updatePresentationModel()` / `invalidateLegacyPresentationSnapshot()` 这类旧命名路径

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：configuration.didSet / sceneProvider.didSet / applySharedLayerSettings() / refreshForCurrentBounds(displayImmediately:) / updatePresentationModel() / invalidateLegacyPresentationSnapshot()
// 功能说明：修改前 root layer 虽然已经不再计算 lines/glyph 的快照内容，
// 但仍沿用“presentation model / legacy snapshot”这一套旧命名和分流路径；
// `configuration`、`sceneProvider`、`contentsScale`、`resourceBundle` 等变化没有全部统一收口到同一个失效入口。
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

    func refreshForCurrentBounds(displayImmediately: Bool = false) {
        updatePresentationModel()
        if displayImmediately {
            linesLayer.displayIfNeeded()
            glyphLayer.displayIfNeeded()
        }
    }

    private func updatePresentationModel() {
        applySharedLayerSettings()
        invalidateSublayerDisplay()
    }

    private func invalidateLegacyPresentationSnapshot() {
        setNeedsLayout()
        refreshForCurrentBounds()
    }
}
```

## 修改后

### `StaffRootLayer` 改为统一的“同步子 layer 状态 + 统一失效”路径

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
// 函数名：configuration.didSet / sceneProvider.didSet / contextNormalizationMode.didSet / resourceBundle.didSet / contentsScale.didSet / synchronizeSublayerState() / refreshForCurrentBounds(displayImmediately:) / invalidateSublayersForCurrentState(displayImmediately:)
// 功能说明：修改后 root layer 删除了 `updatePresentationModel()` 与 `invalidateLegacyPresentationSnapshot()`，
// 把 `configuration`、`sceneProvider`、`contentsScale`、`bounds`、`contextNormalizationMode`、`resourceBundle`
// 全部统一收口到 `invalidateSublayersForCurrentState`；root 的职责只剩“同步共享输入 + 触发两层重绘”。
final class StaffRootLayer: CALayer {
    var configuration: StaffConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var sceneProvider: StaffSceneProvider = .init() {
        didSet {
            guard oldValue != sceneProvider else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var contextNormalizationMode: StaffContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var resourceBundle: Bundle = .main {
        didSet {
            guard oldValue.bundleURL != resourceBundle.bundleURL else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            guard oldValue != contentsScale else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    private func synchronizeSublayerState() {
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

    func refreshForCurrentBounds(displayImmediately: Bool = false) {
        invalidateSublayersForCurrentState(displayImmediately: displayImmediately)
    }

    private func invalidateSublayersForCurrentState(displayImmediately: Bool = false) {
        synchronizeSublayerState()
        invalidateSublayerDisplay()

        if displayImmediately {
            linesLayer.displayIfNeeded()
            glyphLayer.displayIfNeeded()
        }
    }
}
```

## 结果说明

- `StaffRootLayer` 的旧命名路径已经删除，代码层不再残留 `updatePresentationModel()` / `invalidateLegacyPresentationSnapshot()`。
- `configuration`、`sceneProvider`、`contentsScale`、`bounds`、`contextNormalizationMode`、`resourceBundle` 现在都走统一的 root 失效入口。
- lines layer 与 glyph layer 的 draw-time 真相来源没有被再次改动；阶段 4 只做 root 职责清理。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift`，无新增诊断。
- 已执行 staff 相关文件与 `macOSStaffView.swift` 的静态类型检查，结果通过。
- 已在代码范围内搜索 `updatePresentationModel` / `invalidateLegacyPresentationSnapshot`，`NoteMaster_Ver_1` 源码目录下无残留匹配。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对阶段 4 涉及的 Staff 共享层与 macOS 视图执行静态类型检查，确认 root 统一失效清理后可通过编译期校验。
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

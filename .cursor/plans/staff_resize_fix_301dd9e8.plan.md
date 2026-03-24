---
name: staff_resize_fix
overview: 按你选的方案 B，保留 `StaffRootLayer + StaffLinesLayer + StaffGlyphLayer` 分层，但把几何与 scene 迁移到 draw-time 计算，并补齐 macOS live resize 的重绘时机与子 layer 行为控制，消除 clef 拉伸与五线谱宽度延迟更新。
todos:
  - id: phase1-root-resize
    content: 收缩 StaffRootLayer 职责并补齐 macOS live resize/redraw 基础行为
    status: completed
  - id: phase2-lines-drawtime
    content: 把 StaffLinesLayer 改为 draw-time 基于当前 bounds 现算 StaffGeometry
    status: completed
  - id: phase3-glyph-drawtime
    content: 把 StaffGlyphLayer 改为 draw-time 基于当前 bounds 现算 geometry 与 scene
    status: completed
  - id: phase4-invalidation-cleanup
    content: 清理 RootLayer 的缓存推送路径并统一失效策略
    status: pending
  - id: phase5-verify-resize
    content: 验证 macOS live resize 行为并做静态检查
    status: pending
isProject: false
---

# Staff macOS Resize 修复计划

## 当前热点

```swift
// /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift
private func updatePresentationModel() {
    let geometry = StaffGeometry(
        configuration: configuration,
        bounds: bounds,
        orientation: configuration.canvasOrientation
    )
    let scene = sceneProvider.makeScene(geometry: geometry)

    linesLayer.lineSegments = scene.lineSegments
    glyphLayer.geometry = geometry
    glyphLayer.glyphs = scene.glyphs
}
```

这段代码把 `bounds -> geometry -> scene` 放在 layout 阶段做快照，再推给子 layer；方案 B 的核心就是把这条链改成 draw-time 现算，让 `StaffLinesLayer` 与 `StaffGlyphLayer` 在每次绘制时都直接消费当前 `bounds`。

## 目标文件

- [macOSStaffView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift)
- [StaffRootLayer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift)
- [StaffLinesLayer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift)
- [StaffGlyphLayer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift)
- [StaffGeometry.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift)
- [StaffSceneProvider.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift)
- [iOSStaffView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift)

## 分阶段实施

### 阶段 1：收缩 `StaffRootLayer` 职责，补 live resize 基础行为

- 在 [StaffRootLayer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift) 中把 root 的职责收缩为：
  - 管子 layer 的 `frame`
  - 管 `contentsScale`
  - 管 `contextNormalizationMode`
  - 管 `resourceBundle`
  - 在配置或 provider 变化时，只做 invalidate，不再生成 `geometry`/`scene` 快照
- 为 root 更新子 layer `frame` 的路径显式禁用隐式 layer action，避免 resize 过程里旧内容被临时拉伸。
- 在 [macOSStaffView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift) 中把 macOS 的 redraw policy 调整到 live resize 友好的模式，并在需要时补充 bounds 变化期间的主动失效。
- 同步检查 [iOSStaffView.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift)，只做接口一致性对齐，不改变 iOS 语义。

### 阶段 2：把五线谱线段迁移到 `StaffLinesLayer.draw(in:)` 现算

- 在 [StaffLinesLayer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffLinesLayer.swift) 中新增绘制所需的最小输入：
  - `configuration`
  - `orientation`
- `draw(in:)` 内直接基于当前 `bounds` 构造 `StaffGeometry(configuration:bounds:orientation:)`，使用 `geometry.staffLineSegments` 画线。
- 移除 root 对 `lineSegments` 快照的依赖，让 lines layer 的真相来源从“缓存数组”改成“当前 bounds + configuration”。
- 保持 [StaffGeometry.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift) 纯函数属性不变，只迁移调用时机。

### 阶段 3：把 glyph scene 迁移到 `StaffGlyphLayer.draw(in:)` 现算

- 在 [StaffGlyphLayer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffGlyphLayer.swift) 中新增 `sceneProvider` 输入。
- `draw(in:)` 内直接按当前 `bounds` 构造 `StaffGeometry`，再调用 [StaffSceneProvider.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift) 的 `makeScene(geometry:)`，遍历 `scene.glyphs` 调 renderer。
- 去掉 `geometry` / `glyphs` 作为跨 layout-draw 缓存真相的角色，让 clef 与五线谱都在同一帧绑定到当前宽度。
- 保持 `CoreTextMusicGlyphRenderer`、`MusicGlyphRendererFactory`、`StaffConfiguration` 的共享语义不变，避免把 resize 修复扩散成 renderer 重构。

### 阶段 4：清理缓存路径并统一失效策略

- 回到 [StaffRootLayer.swift](/Users/shaun/Library/Mobile Documents/com~~apple~~CloudDocs/Develop/NoteMaster_Ver_1/NoteMaster_Ver_1/Shared/Staff/StaffRootLayer.swift)，删除或瘦身 `updatePresentationModel()`，把它改成纯 invalidate / shared settings 路径。
- 确保这些变化都会触发两层重绘：
  - `configuration`
  - `sceneProvider`
  - `contentsScale`
  - `bounds`
  - `contextNormalizationMode`
  - `resourceBundle`
- 检查 `init(layer:)` 的复制逻辑，确保 `sceneProvider`、`configuration`、`orientation` 等新输入在 layer copy 时不丢失。

### 阶段 5：验证与回归

- 手工验证 macOS live resize：
  - 横向拖宽时 `clef` 不再先压扁再回弹
  - 五线谱宽度在拖动过程中连续更新
  - `Vertical Clip`、`Scale`、`Anchor Y Offset` 在 resize 前后语义不变
  - `Treble / Bass` 切换后行为一致
- 静态验证：
  - `ReadLints` 检查改动文件
  - `xcrun swiftc -parse-as-library -typecheck` 全量类型检查
- 如果 live resize 仍有轻微闪烁，再决定是否补充更细粒度的 macOS view 级 resize hook；这一步放在最后，不提前把平台特化逻辑混进共享层。

## 风险与取舍

- `StaffLinesLayer` 与 `StaffGlyphLayer` 都在 draw-time 现算时，会各自创建一遍 `StaffGeometry`；这是方案 B 为换取 resize 正确性接受的小重复，先不要过早做共享缓存。
- `StaffGlyphLayer` draw-time 现算会让 `sceneProvider.makeScene` 在 redraw 时频繁调用；当前 scene 很轻，优先保证 resize 正确性。
- 这次计划不走单层 `StaffRendererLayer`，因为你已经明确选了方案 B；所以会保留分层，但把“真相来源”从 layout 快照迁回 draw-time。


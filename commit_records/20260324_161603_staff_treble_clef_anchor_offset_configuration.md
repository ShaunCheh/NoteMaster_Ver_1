20260324_161603_staff_treble_clef_anchor_offset_configuration

# treble clef 锚点偏移配置化记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 配置层没有显式暴露 treble clef 的内部锚点下移比例

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：init(...)
// 功能说明：修改前 `StaffConfiguration` 只管理坐标、谱号、渲染模式、布局和调试开关；
// treble clef 的内部锚点下移比例没有显式配置项，后端只能自己维护私有常量。
struct StaffConfiguration: Equatable, Sendable {
    // Shared/Staff 统一约定使用左上原点、y 向下的逻辑坐标。
    var canvasOrientation: StaffCanvasOrientation
    var clef: StaffClef
    var renderMode: MusicGlyphRenderMode
    var layoutMetrics: LayoutMetrics
    var debugOptions: DebugOptions

    init(
        canvasOrientation: StaffCanvasOrientation = .standard,
        clef: StaffClef = .treble,
        renderMode: MusicGlyphRenderMode = .automatic,
        layoutMetrics: LayoutMetrics = .default,
        debugOptions: DebugOptions = .default
    ) {
        self.canvasOrientation = canvasOrientation
        self.clef = clef
        self.renderMode = renderMode
        self.layoutMetrics = layoutMetrics
        self.debugOptions = debugOptions
    }
}
```

### CoreText renderer 把 `0.11` 固定在私有常量里

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：anchorMetrics(for:)
// 功能说明：修改前 treble clef 的 11% 下移量硬编码在 renderer 私有常量中，
// 控制器和共享配置层都无法显式调整这个值。
struct CoreTextMusicGlyphRenderer: MusicGlyphRenderer {
    private enum ClefAnchorTuning {
        // 这个值表达“在共享左上/y-down 语义里向下移动多少”；
        // 但 CoreText optical bounds 的局部坐标是 y-up，所以落到 yRatio 时要做减法。
        static let trebleClefLogicalDownwardShiftRatio: CGFloat = 0.11
    }

    // ... 省略无关代码 ...

    private func anchorMetrics(for semantic: ClefAnchor.Semantic) -> AnchorMetrics {
        switch semantic {
        case .trebleGLine:
            return AnchorMetrics(
                xRatio: 0.5,
                yRatio: 0.56 - ClefAnchorTuning.trebleClefLogicalDownwardShiftRatio
            )
        }
    }
}
```

### 平台 demo 只能走默认行为，不能显式说明当前使用的锚点偏移量

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：staffDisplayState（属性初始化）
// 功能说明：修改前 iOS demo 只显式传入 `renderMode` 和调试开关，treble clef 的锚点偏移仍然隐含在 renderer 内部。
private let staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    )
)
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：staffDisplayState（属性初始化）
// 功能说明：修改前 macOS demo 与 iOS 相同，也没有显式声明 treble clef 的锚点偏移量。
private let staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    )
)
```

## 修改后

### 配置层新增 treble clef 内部锚点下移比例参数

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：init(...)
// 功能说明：修改后把 treble clef 的 glyph 内部锚点下移比例提升到共享配置层；
// 正值统一表示在左上原点、y 向下语义里的“向下偏移”。
struct StaffConfiguration: Equatable, Sendable {
    // Shared/Staff 统一约定使用左上原点、y 向下的逻辑坐标。
    var canvasOrientation: StaffCanvasOrientation
    var clef: StaffClef
    var renderMode: MusicGlyphRenderMode
    var layoutMetrics: LayoutMetrics
    // 以共享逻辑坐标语义描述 treble clef 的 glyph 内部锚点下移比例；正值表示向下。
    var trebleClefAnchorLogicalDownwardShiftRatio: CGFloat
    var debugOptions: DebugOptions

    init(
        canvasOrientation: StaffCanvasOrientation = .standard,
        clef: StaffClef = .treble,
        renderMode: MusicGlyphRenderMode = .automatic,
        layoutMetrics: LayoutMetrics = .default,
        trebleClefAnchorLogicalDownwardShiftRatio: CGFloat = 0.11,
        debugOptions: DebugOptions = .default
    ) {
        self.canvasOrientation = canvasOrientation
        self.clef = clef
        self.renderMode = renderMode
        self.layoutMetrics = layoutMetrics
        self.trebleClefAnchorLogicalDownwardShiftRatio = trebleClefAnchorLogicalDownwardShiftRatio
        self.debugOptions = debugOptions
    }
}
```

### CoreText renderer 改为从 `StaffConfiguration` 读取偏移值

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：drawAnchoredGlyph(_:anchor:renderHint:in:geometry:), anchorMetrics(for:geometry:)
// 功能说明：修改后 renderer 不再依赖私有常量，而是从 `geometry.configuration` 读取 treble clef 锚点下移比例；
// 同时保留 CoreText `y-up` 局部坐标下的减法换算，避免共享语义方向再次写反。
private func drawAnchoredGlyph(
    _ resolvedLine: ResolvedGlyphLine,
    anchor: ClefAnchor,
    renderHint: StaffGlyphRenderHint,
    in context: CGContext,
    geometry: StaffGeometry
) {
    let anchorMetrics = self.anchorMetrics(
        for: anchor.semantic,
        geometry: geometry
    )
    let anchorOffset = CGPoint(
        x: resolvedLine.bounds.minX + (resolvedLine.bounds.width * anchorMetrics.xRatio),
        y: resolvedLine.bounds.minY + (resolvedLine.bounds.height * anchorMetrics.yRatio)
    )

    // ... 省略无关代码 ...
}

private func anchorMetrics(
    for semantic: ClefAnchor.Semantic,
    geometry: StaffGeometry
) -> AnchorMetrics {
    switch semantic {
    case .trebleGLine:
        return AnchorMetrics(
            xRatio: 0.5,
            yRatio: 0.56 - geometry.configuration.trebleClefAnchorLogicalDownwardShiftRatio
        )
    }
}
```

### 平台 demo 改为显式声明当前使用的锚点偏移比例

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：staffDisplayState（属性初始化）
// 功能说明：修改后 iOS demo 会显式传入 `trebleClefAnchorLogicalDownwardShiftRatio: 0.11`，
// 让当前可视化结果与共享配置保持一致，也方便后续继续微调。
private let staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.11,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    )
)
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：staffDisplayState（属性初始化）
// 功能说明：修改后 macOS demo 与 iOS 一样显式传入 `0.11`，
// 避免平台展示依赖 renderer 私有默认值，保持调试输入可追踪。
private let staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.11,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    )
)
```

## 结果说明

- treble clef 的 `11%` 内部锚点下移量已经从 renderer 私有实现细节提升为共享配置输入
- `CoreTextMusicGlyphRenderer` 继续负责 CoreText 局部坐标到共享逻辑坐标的方向换算
- iOS 和 macOS 当前演示入口都已显式写出 `0.11`，后续微调无需再改 renderer 源码

## 验证情况

- `ReadLints` 检查本次修改文件，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

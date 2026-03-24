20260324_174146_staff_default_clef_scale_and_anchor_offset

# Staff 默认 clef 参数调整记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `StaffControlPanel` 共享模型、快照构建器和平台视图实现

## 修改前

### 共享配置层里，treble clef 的默认大小和默认 anchor 偏移仍然是旧值

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：LayoutMetrics.default, init(...)
// 功能说明：修改前共享默认值仍然是 `clefScale = 1.6`、`trebleClefAnchorLogicalDownwardShiftRatio = 0.11`；
// 新建的 StaffConfiguration 和未显式覆盖的场景，都会先吃到这组旧默认值。
struct StaffConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.08,
            verticalInsetRatio: 0.18,
            staffLineCount: 5,
            staffSpaceHeight: 12,
            clefAreaWidthRatio: 0.22,
            staffLineWidth: 1,
            clefScale: 1.6
        )
    }

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

### iOS/macOS 演示入口还在显式覆盖旧的 anchor 偏移默认值

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：staffDisplayState（属性初始化）
// 功能说明：修改前 iOS demo 仍显式传入 `trebleClefAnchorLogicalDownwardShiftRatio: 0.11`，
// 会把共享层即使将来调整过的默认值重新覆盖回旧值。
private var staffDisplayState = StaffDisplayState(
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
// 功能说明：修改前 macOS demo 同样显式传入 `0.11`，与共享默认值绑定关系不一致。
private var staffDisplayState = StaffDisplayState(
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

## 修改后

### 共享配置层默认值改为 `clefScale = 4`、`anchor offset = 0.06`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：LayoutMetrics.default, init(...)
// 功能说明：修改后把 treble clef 的共享默认大小提升到 `4`，
// 并把默认 anchor Y 偏移调整为 `0.06`，让新建的 StaffConfiguration 直接吃到新的默认参数。
struct StaffConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.08,
            verticalInsetRatio: 0.18,
            staffLineCount: 5,
            staffSpaceHeight: 12,
            clefAreaWidthRatio: 0.22,
            staffLineWidth: 1,
            clefScale: 4
        )
    }

    init(
        canvasOrientation: StaffCanvasOrientation = .standard,
        clef: StaffClef = .treble,
        renderMode: MusicGlyphRenderMode = .automatic,
        layoutMetrics: LayoutMetrics = .default,
        trebleClefAnchorLogicalDownwardShiftRatio: CGFloat = 0.06,
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

### iOS/macOS 演示入口同步对齐到新的默认 anchor 偏移

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：staffDisplayState（属性初始化）
// 功能说明：修改后 iOS demo 显式传入 `0.06`，与共享默认 anchor 偏移保持一致，
// 避免页面仍然吃到旧的 `0.11`。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
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
// 功能说明：修改后 macOS demo 也改为显式传入 `0.06`，
// 保证双平台演示入口和共享默认参数对齐。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    )
)
```

## 结果说明

- 新建的 `StaffConfiguration` 现在默认使用 `clef scale = 4`
- 新建的 `StaffConfiguration` 现在默认使用 `anchor Y offset = 0.06`
- 当前 iOS / macOS 演示入口也已经同步对齐到新的默认 anchor 偏移
- `StaffControlPanel` 原有滑块范围仍然覆盖这两个新默认值，不会把它们夹回旧值

## 验证情况

- `ReadLints` 检查 `StaffConfiguration.swift`、`iOSViewController.swift`、`macOSViewController.swift`，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

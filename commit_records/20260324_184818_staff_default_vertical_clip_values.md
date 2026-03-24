20260324_184818_staff_default_vertical_clip_values

# Staff 默认 Vertical Clip 参数调整记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`

## 修改前

### 共享配置层里的 clef vertical clip 默认值仍然是 0

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：init(...)
// 功能说明：修改前 treble / bass 的 vertical clip 默认值都是 `0`；
// 新建的 StaffConfiguration 会先吃到“不开裁切”的默认状态，必须手动调 slider 才会出现裁切效果。
struct StaffConfiguration: Equatable, Sendable {
    init(
        canvasOrientation: StaffCanvasOrientation = .standard,
        clef: StaffClef = .treble,
        renderMode: MusicGlyphRenderMode = .automatic,
        layoutMetrics: LayoutMetrics = .default,
        trebleClefAnchorLogicalDownwardShiftRatio: CGFloat = 0.06,
        bassClefAnchorLogicalDownwardShiftRatio: CGFloat = 0,
        trebleClefVerticalTrimRatio: CGFloat = 0,
        bassClefVerticalTrimRatio: CGFloat = 0,
        debugOptions: DebugOptions = .default
    ) {
        self.canvasOrientation = canvasOrientation
        self.clef = clef
        self.renderMode = renderMode
        self.layoutMetrics = layoutMetrics
        self.trebleClefAnchorLogicalDownwardShiftRatio = trebleClefAnchorLogicalDownwardShiftRatio
        self.bassClefAnchorLogicalDownwardShiftRatio = bassClefAnchorLogicalDownwardShiftRatio
        self.trebleClefVerticalTrimRatio = trebleClefVerticalTrimRatio
        self.bassClefVerticalTrimRatio = bassClefVerticalTrimRatio
        self.debugOptions = debugOptions
    }
}
```

## 修改后

### 共享配置层默认改为 treble 20%，bass 33%

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：init(...)
// 功能说明：修改后把 treble clef 的默认 vertical clip 提升到 `0.2`，
// 把 bass clef 的默认 vertical clip 提升到 `0.33`，让新建的 StaffConfiguration 直接使用新的默认裁切值。
struct StaffConfiguration: Equatable, Sendable {
    init(
        canvasOrientation: StaffCanvasOrientation = .standard,
        clef: StaffClef = .treble,
        renderMode: MusicGlyphRenderMode = .automatic,
        layoutMetrics: LayoutMetrics = .default,
        trebleClefAnchorLogicalDownwardShiftRatio: CGFloat = 0.06,
        bassClefAnchorLogicalDownwardShiftRatio: CGFloat = 0,
        trebleClefVerticalTrimRatio: CGFloat = 0.2,
        bassClefVerticalTrimRatio: CGFloat = 0.33,
        debugOptions: DebugOptions = .default
    ) {
        self.canvasOrientation = canvasOrientation
        self.clef = clef
        self.renderMode = renderMode
        self.layoutMetrics = layoutMetrics
        self.trebleClefAnchorLogicalDownwardShiftRatio = trebleClefAnchorLogicalDownwardShiftRatio
        self.bassClefAnchorLogicalDownwardShiftRatio = bassClefAnchorLogicalDownwardShiftRatio
        self.trebleClefVerticalTrimRatio = trebleClefVerticalTrimRatio
        self.bassClefVerticalTrimRatio = bassClefVerticalTrimRatio
        self.debugOptions = debugOptions
    }
}
```

## 结果说明

- 新建的 `StaffConfiguration` 现在默认使用 `treble vertical clip = 20%`
- 新建的 `StaffConfiguration` 现在默认使用 `bass vertical clip = 33%`
- `Vertical Clip` 滑块的共享范围仍然覆盖这两个默认值，不会在初始化时被夹回旧值

## 验证情况

- `ReadLints` 检查 `StaffConfiguration.swift`，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

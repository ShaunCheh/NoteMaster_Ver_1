20260324_182412_staff_clef_vertical_clip_slider

# Staff Clef Vertical Clip 滑块记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 修改前

### 共享配置层只有 clef 大小和 anchor 偏移，没有“裁切空白”的显式参数

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：init(...), clefAnchorLogicalDownwardShiftRatio(for:), setClefAnchorLogicalDownwardShiftRatio(_:for:)
// 功能说明：修改前配置层只保存各 clef 的 anchor 偏移，不保存 glyph 上下空白裁切比例；
// renderer 因此只能按完整 optical bounds 做缩放与绘制，无法通过共享状态裁掉上下留白。
struct StaffConfiguration: Equatable, Sendable {
    var canvasOrientation: StaffCanvasOrientation
    var clef: StaffClef
    var renderMode: MusicGlyphRenderMode
    var layoutMetrics: LayoutMetrics
    var trebleClefAnchorLogicalDownwardShiftRatio: CGFloat
    var bassClefAnchorLogicalDownwardShiftRatio: CGFloat
    var debugOptions: DebugOptions

    init(
        canvasOrientation: StaffCanvasOrientation = .standard,
        clef: StaffClef = .treble,
        renderMode: MusicGlyphRenderMode = .automatic,
        layoutMetrics: LayoutMetrics = .default,
        trebleClefAnchorLogicalDownwardShiftRatio: CGFloat = 0.06,
        bassClefAnchorLogicalDownwardShiftRatio: CGFloat = 0,
        debugOptions: DebugOptions = .default
    ) {
        self.canvasOrientation = canvasOrientation
        self.clef = clef
        self.renderMode = renderMode
        self.layoutMetrics = layoutMetrics
        self.trebleClefAnchorLogicalDownwardShiftRatio = trebleClefAnchorLogicalDownwardShiftRatio
        self.bassClefAnchorLogicalDownwardShiftRatio = bassClefAnchorLogicalDownwardShiftRatio
        self.debugOptions = debugOptions
    }

    func clefAnchorLogicalDownwardShiftRatio(for clef: StaffClef) -> CGFloat {
        switch clef {
        case .treble:
            return trebleClefAnchorLogicalDownwardShiftRatio
        case .bass:
            return bassClefAnchorLogicalDownwardShiftRatio
        }
    }

    mutating func setClefAnchorLogicalDownwardShiftRatio(
        _ value: CGFloat,
        for clef: StaffClef
    ) {
        switch clef {
        case .treble:
            trebleClefAnchorLogicalDownwardShiftRatio = value
        case .bass:
            bassClefAnchorLogicalDownwardShiftRatio = value
        }
    }
}
```

### 共享控制模型和快照构建器没有 clef 裁切 slider

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift
// 函数名：apply(to:)
// 功能说明：修改前控制事件只支持 clef 切换、scale、anchor offset；
// slider ID 里也没有 vertical clip，因此两个平台面板都不可能出现这个滑块。
enum StaffControlEvent: Equatable, Sendable {
    case setClef(StaffClef)
    case setClefScale(CGFloat)
    case setClefAnchorLogicalDownwardShiftRatio(CGFloat)

    static let clefScaleRange: ClosedRange<CGFloat> = 1.0...5
    static let clefAnchorLogicalDownwardShiftRatioRange: ClosedRange<CGFloat> = (-0.25)...0.25

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case let .setClef(clef):
            displayState.configuration.clef = clef
        case let .setClefScale(value):
            displayState.configuration.layoutMetrics.clefScale = value.clamped(
                to: Self.clefScaleRange
            )
        case let .setClefAnchorLogicalDownwardShiftRatio(value):
            displayState.configuration.setClefAnchorLogicalDownwardShiftRatio(
                value.clamped(
                    to: Self.clefAnchorLogicalDownwardShiftRatioRange
                ),
                for: displayState.configuration.clef
            )
        }
    }
}

struct StaffSliderControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case clefScale
        case clefAnchorYOffset
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift
// 函数名：resolvedValue(for:displayState:), isEnabled(for:displayState:), displayValue(for:value:)
// 功能说明：修改前 SnapshotBuilder 只会为 `Scale` 和 `Anchor Y Offset` 生成值与文案，
// 没有 “Vertical Clip” 对应的值读取、可用性判断和百分比显示。
private static func resolvedValue(
    for sliderID: StaffSliderControlItem.ID,
    displayState: StaffDisplayState
) -> CGFloat {
    switch sliderID {
    case .clefScale:
        return displayState.configuration.layoutMetrics.clefScale
    case .clefAnchorYOffset:
        return displayState.configuration.clefAnchorLogicalDownwardShiftRatio(
            for: displayState.configuration.clef
        )
    }
}

private static func isEnabled(
    for sliderID: StaffSliderControlItem.ID,
    displayState _: StaffDisplayState
) -> Bool {
    switch sliderID {
    case .clefScale, .clefAnchorYOffset:
        return true
    }
}

private static func displayValue(
    for sliderID: StaffSliderControlItem.ID,
    value: CGFloat
) -> String {
    switch sliderID {
    case .clefScale:
        return String(format: "%.2fx", Double(value))
    case .clefAnchorYOffset:
        let normalizedValue: CGFloat = abs(value) < 0.005 ? 0 : value
        return String(format: "%+.2f", Double(normalizedValue))
    }
}
```

### 双平台面板的 slider 事件映射里没有 clef 裁切事件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift
// 函数名：makeEvent(value:)
// 功能说明：修改前 iOS 面板只能把 slider 映射成 scale 或 anchor offset 事件。
private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .clefScale:
            return .setClefScale(value)
        case .clefAnchorYOffset:
            return .setClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift
// 函数名：makeEvent(value:)
// 功能说明：修改前 macOS 面板与 iOS 对称，也没有 clef 裁切事件的入口。
private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .clefScale:
            return .setClefScale(value)
        case .clefAnchorYOffset:
            return .setClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

### CoreText renderer 只按完整 bounds 拟合和绘制，无法真正裁掉上下空白

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：resolvedGlyphLine(for:targetSize:tintColor:), makeResolvedGlyphLine(glyph:fontSize:tintColor:),
//        drawAnchoredGlyph(_:anchor:renderHint:in:geometry:), drawGlyph(_:centeredIn:renderHint:in:geometry:),
//        drawLine(_:at:in:geometry:), logicalBounds(for:drawOrigin:geometry:)
// 功能说明：修改前 renderer 只有一个完整 `bounds`；
// fit 逻辑还用 `min(1, widthScale, heightScale)` 限制了只缩小不放大，导致即使想裁空白，也没有真实的裁切参与拟合和绘制。
private struct ResolvedGlyphLine {
    var line: CTLine
    var bounds: CGRect
}

private func resolvedGlyphLine(
    for glyph: MusicGlyph,
    targetSize: CGSize,
    tintColor: StaffSceneColor
) -> ResolvedGlyphLine? {
    let baseFontSize = max(targetSize.height, 1)

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

    guard !resolved.bounds.isNull, !resolved.bounds.isEmpty else {
        return nil
    }

    return resolved
}

private func makeResolvedGlyphLine(
    glyph: MusicGlyph,
    fontSize: CGFloat,
    tintColor: StaffSceneColor
) -> ResolvedGlyphLine? {
    let line = CTLineCreateWithAttributedString(attributedText)
    let bounds = CTLineGetBoundsWithOptions(
        line,
        [.useOpticalBounds]
    )

    return ResolvedGlyphLine(
        line: line,
        bounds: bounds
    )
}

private func drawAnchoredGlyph(
    _ resolvedLine: ResolvedGlyphLine,
    anchor: ClefAnchor,
    renderHint: StaffGlyphRenderHint,
    in context: CGContext,
    geometry: StaffGeometry
) {
    let anchorOffset = CGPoint(
        x: resolvedLine.bounds.minX + (resolvedLine.bounds.width * anchorMetrics.xRatio),
        y: resolvedLine.bounds.minY + (resolvedLine.bounds.height * anchorMetrics.yRatio)
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
    context.translateBy(x: 0, y: geometry.bounds.height)
    context.scaleBy(x: 1, y: -1)
    context.textPosition = origin
    CTLineDraw(line, context)
}
```

## 修改后

### 共享配置层新增各 clef 的 vertical trim 参数

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数名：init(...), clefVerticalTrimRatio(for:), setClefVerticalTrimRatio(_:for:)
// 功能说明：修改后配置层为 treble / bass 分别保存 vertical trim 比例；
// 这样 slider 调整的是共享语义参数，而不是平台层的临时裁剪技巧。
struct StaffConfiguration: Equatable, Sendable {
    var canvasOrientation: StaffCanvasOrientation
    var clef: StaffClef
    var renderMode: MusicGlyphRenderMode
    var layoutMetrics: LayoutMetrics
    var trebleClefAnchorLogicalDownwardShiftRatio: CGFloat
    var bassClefAnchorLogicalDownwardShiftRatio: CGFloat
    var trebleClefVerticalTrimRatio: CGFloat
    var bassClefVerticalTrimRatio: CGFloat
    var debugOptions: DebugOptions

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

    func clefVerticalTrimRatio(for clef: StaffClef) -> CGFloat {
        switch clef {
        case .treble:
            return trebleClefVerticalTrimRatio
        case .bass:
            return bassClefVerticalTrimRatio
        }
    }

    mutating func setClefVerticalTrimRatio(
        _ value: CGFloat,
        for clef: StaffClef
    ) {
        switch clef {
        case .treble:
            trebleClefVerticalTrimRatio = value
        case .bass:
            bassClefVerticalTrimRatio = value
        }
    }
}
```

### 控制模型与快照构建器新增 `Vertical Clip` 滑块

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift
// 函数名：apply(to:)
// 功能说明：修改后共享控制模型新增 `setClefVerticalTrimRatio` 事件、
// `clefVerticalTrimRatioRange` 范围，以及 `clefVerticalTrim` slider 标识。
enum StaffControlEvent: Equatable, Sendable {
    case setClef(StaffClef)
    case setClefScale(CGFloat)
    case setClefVerticalTrimRatio(CGFloat)
    case setClefAnchorLogicalDownwardShiftRatio(CGFloat)

    static let clefScaleRange: ClosedRange<CGFloat> = 1.0...5
    static let clefVerticalTrimRatioRange: ClosedRange<CGFloat> = 0...0.4
    static let clefAnchorLogicalDownwardShiftRatioRange: ClosedRange<CGFloat> = (-0.25)...0.25

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case let .setClef(clef):
            displayState.configuration.clef = clef
        case let .setClefScale(value):
            displayState.configuration.layoutMetrics.clefScale = value.clamped(
                to: Self.clefScaleRange
            )
        case let .setClefVerticalTrimRatio(value):
            displayState.configuration.setClefVerticalTrimRatio(
                value.clamped(
                    to: Self.clefVerticalTrimRatioRange
                ),
                for: displayState.configuration.clef
            )
        case let .setClefAnchorLogicalDownwardShiftRatio(value):
            displayState.configuration.setClefAnchorLogicalDownwardShiftRatio(
                value.clamped(
                    to: Self.clefAnchorLogicalDownwardShiftRatioRange
                ),
                for: displayState.configuration.clef
            )
        }
    }
}

struct StaffSliderControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case clefScale
        case clefVerticalTrim
        case clefAnchorYOffset

        var title: String {
            switch self {
            case .clefScale:
                return "Scale"
            case .clefVerticalTrim:
                return "Vertical Clip"
            case .clefAnchorYOffset:
                return "Anchor Y Offset"
            }
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift
// 函数名：resolvedValue(for:displayState:), isEnabled(for:displayState:), displayValue(for:value:)
// 功能说明：修改后 SnapshotBuilder 能读取当前 clef 的 vertical trim 值，
// 并把 UI 文案格式化成百分比，便于肉眼调节裁切程度。
private static func resolvedValue(
    for sliderID: StaffSliderControlItem.ID,
    displayState: StaffDisplayState
) -> CGFloat {
    switch sliderID {
    case .clefScale:
        return displayState.configuration.layoutMetrics.clefScale
    case .clefVerticalTrim:
        return displayState.configuration.clefVerticalTrimRatio(
            for: displayState.configuration.clef
        )
    case .clefAnchorYOffset:
        return displayState.configuration.clefAnchorLogicalDownwardShiftRatio(
            for: displayState.configuration.clef
        )
    }
}

private static func isEnabled(
    for sliderID: StaffSliderControlItem.ID,
    displayState _: StaffDisplayState
) -> Bool {
    switch sliderID {
    case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
        return true
    }
}

private static func displayValue(
    for sliderID: StaffSliderControlItem.ID,
    value: CGFloat
) -> String {
    switch sliderID {
    case .clefScale:
        return String(format: "%.2fx", Double(value))
    case .clefVerticalTrim:
        return String(format: "%.0f%%", Double(value * 100))
    case .clefAnchorYOffset:
        let normalizedValue: CGFloat = abs(value) < 0.005 ? 0 : value
        return String(format: "%+.2f", Double(normalizedValue))
    }
}
```

### 双平台面板把新 slider 事件接入现有状态流

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSStaffControlPanelView.swift
// 函数名：makeEvent(value:)
// 功能说明：修改后 iOS 面板可以把 `Vertical Clip` slider 映射成共享事件。
private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .clefScale:
            return .setClefScale(value)
        case .clefVerticalTrim:
            return .setClefVerticalTrimRatio(value)
        case .clefAnchorYOffset:
            return .setClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSStaffControlPanelView.swift
// 函数名：makeEvent(value:)
// 功能说明：修改后 macOS 面板与 iOS 对称，也支持上送 clef 裁切事件。
private extension StaffSliderControlItem.ID {
    func makeEvent(value: CGFloat) -> StaffControlEvent {
        switch self {
        case .clefScale:
            return .setClefScale(value)
        case .clefVerticalTrim:
            return .setClefVerticalTrimRatio(value)
        case .clefAnchorYOffset:
            return .setClefAnchorLogicalDownwardShiftRatio(value)
        }
    }
}
```

### CoreText renderer 改为按“裁切后的有效 bounds”拟合和绘制

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数名：resolvedGlyphLine(for:targetSize:tintColor:verticalTrimRatio:),
//        makeResolvedGlyphLine(glyph:fontSize:tintColor:verticalTrimRatio:),
//        drawAnchoredGlyph(_:anchor:renderHint:in:geometry:),
//        drawGlyph(_:centeredIn:renderHint:in:geometry:),
//        drawLine(_:at:clipBounds:in:geometry:),
//        verticalTrimRatio(for:geometry:), trimmedBounds(from:verticalTrimRatio:)
// 功能说明：修改后 renderer 同时维护 `opticalBounds` 与 `effectiveBounds`；
// `effectiveBounds` 用于尺寸拟合、居中和调试框，`clipBounds` 用于真实裁切绘制，
// 从根因上把“去掉字形上下空白”接进了渲染链路。
private struct ResolvedGlyphLine {
    var line: CTLine
    var opticalBounds: CGRect
    var effectiveBounds: CGRect
}

private func resolvedGlyphLine(
    for glyph: MusicGlyph,
    targetSize: CGSize,
    tintColor: StaffSceneColor,
    verticalTrimRatio: CGFloat
) -> ResolvedGlyphLine? {
    let baseFontSize = max(targetSize.height, 1)

    guard var resolved = makeResolvedGlyphLine(
        glyph: glyph,
        fontSize: baseFontSize,
        tintColor: tintColor,
        verticalTrimRatio: verticalTrimRatio
    ) else {
        return nil
    }

    let widthScale = targetSize.width / max(resolved.effectiveBounds.width, 1)
    let heightScale = targetSize.height / max(resolved.effectiveBounds.height, 1)
    let fitScale = min(widthScale, heightScale)

    // 根因修正：这里不再限制“只能缩小”，而是按有效裁切框双向 fit。
    if fitScale.isFinite, fitScale > 0, abs(fitScale - 1) > 0.0001 {
        resolved = makeResolvedGlyphLine(
            glyph: glyph,
            fontSize: max(baseFontSize * fitScale, 1),
            tintColor: tintColor,
            verticalTrimRatio: verticalTrimRatio
        ) ?? resolved
    }

    return resolved
}

private func makeResolvedGlyphLine(
    glyph: MusicGlyph,
    fontSize: CGFloat,
    tintColor: StaffSceneColor,
    verticalTrimRatio: CGFloat
) -> ResolvedGlyphLine? {
    let line = CTLineCreateWithAttributedString(attributedText)
    let opticalBounds = CTLineGetBoundsWithOptions(
        line,
        [.useOpticalBounds]
    )
    let effectiveBounds = trimmedBounds(
        from: opticalBounds,
        verticalTrimRatio: verticalTrimRatio
    )

    return ResolvedGlyphLine(
        line: line,
        opticalBounds: opticalBounds,
        effectiveBounds: effectiveBounds
    )
}

private func drawAnchoredGlyph(
    _ resolvedLine: ResolvedGlyphLine,
    anchor: ClefAnchor,
    renderHint: StaffGlyphRenderHint,
    in context: CGContext,
    geometry: StaffGeometry
) {
    let anchorOffset = CGPoint(
        x: resolvedLine.opticalBounds.minX + (resolvedLine.opticalBounds.width * anchorMetrics.xRatio),
        y: resolvedLine.opticalBounds.minY + (resolvedLine.opticalBounds.height * anchorMetrics.yRatio)
    )

    drawLine(
        resolvedLine.line,
        at: drawOrigin,
        clipBounds: flippedBounds(
            for: resolvedLine.effectiveBounds,
            drawOrigin: drawOrigin
        ),
        in: context,
        geometry: geometry
    )
}

private func drawLine(
    _ line: CTLine,
    at origin: CGPoint,
    clipBounds: CGRect?,
    in context: CGContext,
    geometry: StaffGeometry
) {
    context.translateBy(x: 0, y: geometry.bounds.height)
    context.scaleBy(x: 1, y: -1)
    if let clipBounds {
        context.clip(to: clipBounds)
    }
    context.textPosition = origin
    CTLineDraw(line, context)
}

private func verticalTrimRatio(
    for glyphItem: StaffGlyphItem,
    geometry: StaffGeometry
) -> CGFloat {
    let clef: StaffClef
    switch glyphItem.placement {
    case let .anchor(anchor):
        clef = anchor.semantic.clef
    case .frame:
        clef = glyphItem.symbolID.clef
    }

    return geometry.configuration.clefVerticalTrimRatio(for: clef)
}

private func trimmedBounds(
    from bounds: CGRect,
    verticalTrimRatio: CGFloat
) -> CGRect {
    let clampedTrimRatio = min(max(verticalTrimRatio, 0), 0.45)
    guard clampedTrimRatio > 0 else {
        return bounds
    }

    let maximumInset = max((bounds.height - 1) / 2, 0)
    let inset = min(bounds.height * clampedTrimRatio, maximumInset)
    let trimmedBounds = bounds.insetBy(dx: 0, dy: inset)

    return trimmedBounds.isNull || trimmedBounds.isEmpty ? .null : trimmedBounds
}
```

## 结果说明

- 两个平台的 `StaffControlPanel` 都新增了 `Vertical Clip` 滑块
- `Vertical Clip` 按“当前 clef”分别保存和编辑，不会把 treble / bass 的裁切值混在一起
- renderer 现在不是只改一个表面数值，而是真正按裁切后的有效 bounds 重新 fit glyph
- 绘制阶段会对 glyph 执行实际 clip，因此可以把上下大块空白裁掉
- 这次同时修正了 fit 逻辑只能缩小不能放大的问题，避免裁切值被老逻辑吃掉

## 验证情况

- `ReadLints` 检查上述修改文件，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

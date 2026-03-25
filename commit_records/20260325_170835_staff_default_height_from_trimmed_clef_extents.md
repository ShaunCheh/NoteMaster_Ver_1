# 20260325_170835_staff_default_height_from_trimmed_clef_extents

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_170835`
- 记录范围：将五线谱默认高度从 `clefScale` 对称保守高度，改为基于默认 clef 裁后 extents 反推
- 本次目标：从根因上收敛五线谱下方的大空白，让默认高度与默认 clef 的实际可见范围对齐，同时保持运行时 `Vertical Clip` 滑块不回流修改页面布局高度

## 本次完成的修改

1. 新增 `StaffClefLayoutGuide.swift`，把默认 clef 的裁后可见 extents、anchor 对齐语义、trim 逻辑收口为共享真相。
2. 改造 `StaffConfiguration.LayoutMetrics`，让 `preferredHeight` 不再直接使用旧的 `clefScale` 保守高度，而是根据默认 clef 裁后 extents 计算。
3. 改造 `StaffGeometry.staffTopY`，让五线不再在 `drawingRect` 中垂直居中，而是按默认 clef 的顶部外扩量定位。
4. 改造 `CoreTextMusicGlyphRenderer`，复用 `StaffClefLayoutGuide` 里的 anchor/trim 语义，避免布局计算和实际绘制出现两套真相。
5. 执行类型校验，确认共享层改造没有打断现有编译链。

## 修改 1：新增 `StaffClefLayoutGuide.swift`，把默认 clef 裁后 extents 收口为共享真相

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffClefLayoutGuide.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前没有专门承接默认 clef 裁后 extents 的共享层；默认高度、anchor 对齐和 trim 逻辑分别散落在 StaffConfiguration、StaffGeometry、CoreTextMusicGlyphRenderer 中。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffClefLayoutGuide.swift
// 函数/成员: StaffClefLayoutGuide.defaultLayoutInsets(...), anchorMetrics(...), trimmedBounds(...), measureDefaultVisibleExtentRatios(...)
// 功能说明: 修改后共享层会测量默认 clef 的 opticalBounds 与默认裁切窗口，反推出相对锚点的 top / bottom 可见 extents，并统一提供 anchor / trim 真相给布局和 renderer 复用。
enum StaffClefLayoutGuide {
    private static let measurementGlyphHeight: CGFloat = 1000
    private static let lock = NSLock()
    private static var cachedDefaultVisibleExtentRatios: [StaffClef: StaffClefVisibleExtents] = [:]

    static func defaultLayoutInsets(
        for clef: StaffClef,
        staffHeight: CGFloat,
        staffSpaceHeight: CGFloat,
        clefScale: CGFloat,
        bundle: Bundle = .main
    ) -> StaffClefLayoutInsets? {
        guard staffHeight > 0, staffSpaceHeight > 0 else {
            return nil
        }

        guard let visibleExtentRatios = defaultVisibleExtentRatios(
            for: clef,
            bundle: bundle
        ) else {
            return nil
        }

        let targetHeight = max(staffHeight * max(clefScale, 1), 1)
        let visibleExtents = visibleExtentRatios.scaled(by: targetHeight)
        let anchorOffsetFromStaffTop = min(
            max(CGFloat(clef.anchorLineIndex) * staffSpaceHeight, 0),
            staffHeight
        )
        let anchorOffsetToStaffBottom = max(staffHeight - anchorOffsetFromStaffTop, 0)

        return StaffClefLayoutInsets(
            top: max(visibleExtents.top - anchorOffsetFromStaffTop, 0),
            bottom: max(visibleExtents.bottom - anchorOffsetToStaffBottom, 0)
        )
    }

    static func anchorMetrics(
        for clef: StaffClef,
        downwardShiftRatio: CGFloat
    ) -> StaffClefAnchorMetrics {
        switch clef {
        case .treble:
            return StaffClefAnchorMetrics(
                xRatio: 0.5,
                yRatio: 0.56 - downwardShiftRatio
            )
        case .bass:
            return StaffClefAnchorMetrics(
                xRatio: 0.74,
                yRatio: 0.5 - downwardShiftRatio
            )
        }
    }

    static func trimmedBounds(
        from bounds: CGRect,
        verticalTrimRatio: CGFloat
    ) -> CGRect {
        // ... 省略空值与 clamp 保护 ...
        let maximumInset = max((bounds.height - 1) / 2, 0)
        let inset = min(bounds.height * clampedTrimRatio, maximumInset)
        let trimmedBounds = bounds.insetBy(dx: 0, dy: inset)
        return trimmedBounds.isNull || trimmedBounds.isEmpty ? .null : trimmedBounds
    }
}
```

## 修改 2：`StaffConfiguration.preferredHeight` 改为基于默认 clef 裁后 extents 反推

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数/成员: StaffConfiguration.LayoutMetrics.minimumDrawingHeight(), preferredHeight(), StaffConfiguration.preferredHeight
// 功能说明: 修改前默认高度只看 staffHeight 和 clefScale，等价于给 clef 预留一块上下对称的保守可绘制空间，不关心默认 clef 裁切后的真实可见范围。
func minimumDrawingHeight() -> CGFloat {
    let resolvedStaffHeight = staffHeight()
    return max(resolvedStaffHeight, resolvedStaffHeight * max(clefScale, 1))
}

func preferredHeight() -> CGFloat {
    let drawingFactor = max(
        1 - (verticalInsetRatio * 2),
        Self.minimumLayoutFactor
    )
    return minimumDrawingHeight() / drawingFactor
}

var preferredHeight: CGFloat {
    layoutMetrics.preferredHeight()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 函数/成员: StaffConfiguration.LayoutMetrics.legacyMinimumDrawingHeight(), defaultClefLayoutInsets(for:), minimumDrawingHeight(for:), preferredHeight(for:), StaffConfiguration.preferredHeight
// 功能说明: 修改后默认高度改为根据默认 clef 的裁后 top / bottom extents 计算；若字体资源不可用，则回退到旧的保守高度策略，避免 intrinsic size 失效。
private func legacyMinimumDrawingHeight() -> CGFloat {
    let resolvedStaffHeight = staffHeight()
    return max(resolvedStaffHeight, resolvedStaffHeight * max(clefScale, 1))
}

func defaultClefLayoutInsets(for clef: StaffClef) -> StaffClefLayoutInsets? {
    StaffClefLayoutGuide.defaultLayoutInsets(
        for: clef,
        staffHeight: staffHeight(),
        staffSpaceHeight: normalizedStaffSpaceHeight,
        clefScale: clefScale
    )
}

func minimumDrawingHeight(for clef: StaffClef) -> CGFloat {
    let resolvedStaffHeight = staffHeight()

    guard let layoutInsets = defaultClefLayoutInsets(for: clef) else {
        return legacyMinimumDrawingHeight()
    }

    return max(
        resolvedStaffHeight + layoutInsets.top + layoutInsets.bottom,
        resolvedStaffHeight
    )
}

func preferredHeight(for clef: StaffClef) -> CGFloat {
    let drawingFactor = max(
        1 - (verticalInsetRatio * 2),
        Self.minimumLayoutFactor
    )
    return minimumDrawingHeight(for: clef) / drawingFactor
}

var preferredHeight: CGFloat {
    layoutMetrics.preferredHeight(for: clef)
}
```

## 修改 3：`StaffGeometry.staffTopY` 不再垂直居中，而是按默认 top inset 放置五线

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数/成员: StaffGeometry.clefAnchor(for:), staffTopY
// 功能说明: 修改前 clef anchor 的 line / semantic 分支在 geometry 里重复展开；staffTopY 直接把五线放到 drawingRect 的垂直中心，因此下方会吃掉与上方对称的大量空白。
func clefAnchor(for clef: StaffClef) -> ClefAnchor {
    switch clef {
    case .treble:
        return ClefAnchor(
            point: CGPoint(
                x: clefAreaRect.midX,
                y: lineY(at: 3) ?? staffRect.midY
            ),
            semantic: .trebleGLine,
            targetHeight: max(staffRect.height * configuration.layoutMetrics.clefScale, 1)
        )
    case .bass:
        return ClefAnchor(
            point: CGPoint(
                x: clefAreaRect.midX,
                y: lineY(at: 1) ?? staffRect.midY
            ),
            semantic: .bassFLine,
            targetHeight: max(staffRect.height * configuration.layoutMetrics.clefScale, 1)
        )
    }
}

private var staffTopY: CGFloat {
    drawingRect.midY - (staffHeight / 2)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数/成员: StaffGeometry.clefAnchor(for:), staffTopY
// 功能说明: 修改后 clef 的 line / semantic 语义收口到 StaffClef 扩展；staffTopY 取默认 clef 的 top inset 作为首选定位，只有无法解析默认 extents 时才回退到旧的居中策略。
func clefAnchor(for clef: StaffClef) -> ClefAnchor {
    ClefAnchor(
        point: CGPoint(
            x: clefAreaRect.midX,
            y: lineY(at: clef.anchorLineIndex) ?? staffRect.midY
        ),
        semantic: clef.anchorSemantic,
        targetHeight: max(staffRect.height * configuration.layoutMetrics.clefScale, 1)
    )
}

private var staffTopY: CGFloat {
    guard !drawingRect.isNull else {
        return 0
    }

    let availableTopPadding = max(drawingRect.height - staffHeight, 0)
    let resolvedTopPadding = configuration.layoutMetrics.defaultClefLayoutInsets(
        for: configuration.clef
    )?.top
    let fallbackCenteredPadding = availableTopPadding / 2

    return drawingRect.minY + min(
        max(resolvedTopPadding ?? fallbackCenteredPadding, 0),
        availableTopPadding
    )
}
```

## 修改 4：`CoreTextMusicGlyphRenderer` 复用同一套 anchor / trim 真相

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: AnchorMetrics, anchorMetrics(for:geometry:), trimmedBounds(from:verticalTrimRatio:)
// 功能说明: 修改前 renderer 自己维护了一套 clef anchor 比例与 trim 逻辑；布局层如果改高度语义，很容易和 renderer 的实际绘制再次分叉。
private struct AnchorMetrics {
    var xRatio: CGFloat
    var yRatio: CGFloat
}

private func anchorMetrics(
    for semantic: ClefAnchor.Semantic,
    geometry: StaffGeometry
) -> AnchorMetrics {
    let downwardShiftRatio = geometry.configuration.clefAnchorLogicalDownwardShiftRatio(
        for: semantic.clef
    )

    switch semantic {
    case .trebleGLine:
        return AnchorMetrics(
            xRatio: 0.5,
            yRatio: 0.56 - downwardShiftRatio
        )
    case .bassFLine:
        return AnchorMetrics(
            xRatio: 0.74,
            yRatio: 0.5 - downwardShiftRatio
        )
    }
}

private func trimmedBounds(
    from bounds: CGRect,
    verticalTrimRatio: CGFloat
) -> CGRect {
    let maximumInset = max((bounds.height - 1) / 2, 0)
    let inset = min(bounds.height * clampedTrimRatio, maximumInset)
    let trimmedBounds = bounds.insetBy(dx: 0, dy: inset)
    return trimmedBounds.isNull || trimmedBounds.isEmpty ? .null : trimmedBounds
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: AnchorMetrics, anchorMetrics(for:geometry:), trimmedBounds(from:verticalTrimRatio:)
// 功能说明: 修改后 renderer 直接复用 StaffClefLayoutGuide 的 anchor / trim 真相，默认高度计算与实际 glyph 绘制共享同一套语义。
private typealias AnchorMetrics = StaffClefAnchorMetrics

private func anchorMetrics(
    for semantic: ClefAnchor.Semantic,
    geometry: StaffGeometry
) -> AnchorMetrics {
    StaffClefLayoutGuide.anchorMetrics(
        for: semantic.clef,
        downwardShiftRatio: geometry.configuration.clefAnchorLogicalDownwardShiftRatio(
            for: semantic.clef
        )
    )
}

private func trimmedBounds(
    from bounds: CGRect,
    verticalTrimRatio: CGFloat
) -> CGRect {
    StaffClefLayoutGuide.trimmedBounds(
        from: bounds,
        verticalTrimRatio: verticalTrimRatio
    )
}
```

## 验证情况

1. 已执行 `swiftc -typecheck` 覆盖当前工程全部 Swift 源文件，结果通过。
2. 已检查本次修改涉及文件的 lints，结果无新增问题。
3. 尚未执行 iOS / macOS 运行时手工 UI 回归；默认 treble / bass 下五线谱与指板间距是否完全符合预期，还需要在应用内再看一次实际表现。

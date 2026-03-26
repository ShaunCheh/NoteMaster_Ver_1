# 20260326_180944_clef_key_signature_gap_root_cause_fix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_180944`
- 记录范围：五线谱 `clef -> key signature` 间距过大的根因修复
- 本次目标：按当前共享层代码架构，从根因上修复“调号离 clef 太远”的问题，而不是单纯压缩一个间距常量
- 根因结论：问题不在调号内部 `# / b` glyph 的横向 spacing，也不在 `keySignatureToNoteGapInSpaces`。真正的根因是 `StaffSceneBuilder.resolvedContentStartX(...)` 把调号起点绑定到了 `geometry.clefAreaRect.maxX`，也就是整块 `clef` 预留区的右边界；但 `treble/bass clef` 实际可见字形往往比这块预留区窄很多，于是 clef 右侧的大块空白也被一起算进了调号前导距离
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffClefLayoutGuide.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

## 本次完成的修改

1. 在 `StaffClefLayoutGuide` 中补了 `StaffClefHorizontalExtents`、`defaultHorizontalExtents(...)` 和横向 measurement cache，让共享层可以在不依赖 renderer 实时绘制的前提下，得到 clef 的实际可见横向范围。
2. 在 `StaffGeometry` 中新增 `clefVisibleMaxX(for:)` 和 `clefContentStartX(for:gapInSpaces:)`，把“clef 实际可见右边界 + gap”正式收敛成几何真相源。
3. `StaffSceneBuilder.resolvedContentStartX(...)` 不再直接使用 `clefAreaRect.maxX`，而是统一改走 `geometry.clefContentStartX(...)`。
4. `CoreTextMusicGlyphRenderer.targetSize(...)` 的 anchored clef 宽度不再单独写死 `0.92`，改为复用 `StaffClefLayoutGuide.anchoredTargetWidthRatio`，保证 renderer 和几何计算使用同一套 fit 语义。
5. `StaffValidation.validateAccidentals(...)` 增加了“首个调号 glyph 起点必须等于 clef 实际可见右边界 + gap”的自动回归护栏，防止后续又退回到按整块 `clefAreaRect` 撑开间距。

## 修改 1：问题根因在 `resolvedContentStartX(...)` 绑定了整块 `clefAreaRect`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.resolvedContentStartX(geometry:)
// 功能说明: 修改前调号与后续 note 区的起点直接依赖 clefAreaRect.maxX；
// 这会把整个 clef 预留区都算进来，导致实际字形比预留区窄时，调号被推得过远。
private func resolvedContentStartX(
    geometry: StaffGeometry
) -> CGFloat {
    min(
        geometry.clefAreaRect.maxX
            + (geometry.staffSpaceHeight * layoutMetrics.clefToNoteGapInSpaces),
        geometry.drawingRect.maxX
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.resolvedContentStartX(geometry:)
// 功能说明: 修改后调号与 note 区的起点统一走 geometry.clefContentStartX(...)；
// SceneBuilder 不再自己猜 clef 右边界，而是依赖几何层提供的“clef 实际可见右边界 + gap”。
private func resolvedContentStartX(
    geometry: StaffGeometry
) -> CGFloat {
    geometry.clefContentStartX(
        for: clef,
        gapInSpaces: layoutMetrics.clefToNoteGapInSpaces
    )
}
```

## 修改 2：在几何层补出 clef 实际可见右边界，成为内容起点真相源

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数/成员: StaffGeometry.clefAnchor(for:)
// 功能说明: 修改前几何层只提供 clef 的锚点位置；
// 上层没有“clef 实际可见横向边界”这个语义，只能退回去使用 clefAreaRect.maxX。
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数/成员: StaffGeometry.clefVisibleMaxX(for:) / StaffGeometry.clefContentStartX(for:gapInSpaces:)
// 功能说明: 修改后几何层显式暴露 clef 实际可见右边界；
// 后续调号起点和 note 区起点都可以统一依赖这两个方法，而不是各自重复推导。
func clefVisibleMaxX(for clef: StaffClef) -> CGFloat {
    guard !drawingRect.isNull else {
        return 0
    }

    let anchor = clefAnchor(for: clef)
    guard let horizontalExtents = StaffClefLayoutGuide.defaultHorizontalExtents(
        for: clef,
        targetHeight: anchor.targetHeight,
        targetWidth: max(
            clefAreaRect.width * StaffClefLayoutGuide.anchoredTargetWidthRatio,
            1
        ),
        downwardShiftRatio: configuration.clefAnchorLogicalDownwardShiftRatio(
            for: clef
        )
    ) else {
        return min(clefAreaRect.maxX, drawingRect.maxX)
    }

    return min(anchor.point.x + horizontalExtents.trailing, drawingRect.maxX)
}

func clefContentStartX(
    for clef: StaffClef,
    gapInSpaces: CGFloat
) -> CGFloat {
    min(
        clefVisibleMaxX(for: clef)
            + (staffSpaceHeight * gapInSpaces),
        drawingRect.maxX
    )
}
```

## 修改 3：把 renderer 内部的 anchored clef fit 语义抽回共享层复用

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: CoreTextMusicGlyphRenderer.targetSize(for:geometry:)
// 功能说明: 修改前 renderer 内部自己把 anchored clef 的目标宽度写死为 0.92 * clefAreaRect.width；
// 但几何层无法复用这套语义，所以无法反推出 clef 实际可见右边界。
private func targetSize(
    for glyphItem: StaffGlyphItem,
    geometry: StaffGeometry
) -> CGSize {
    switch glyphItem.placement {
    case let .anchor(anchor):
        return CGSize(
            width: max(geometry.clefAreaRect.width * 0.92, 1),
            height: max(anchor.targetHeight, 1)
        )
    case let .frame(frame):
        return CGSize(
            width: max(frame.width, 1),
            height: max(frame.height, 1)
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffClefLayoutGuide.swift
// 函数/成员: StaffClefLayoutGuide.defaultHorizontalExtents(for:targetHeight:targetWidth:downwardShiftRatio:)
// 功能说明: 修改后共享层先测出默认 clef 的 optical 宽高比，再按 renderer 同样的 fit 规则反推出当前目标尺寸下的可见横向 extents；
// 这让几何层可以在不真正绘制 glyph 的情况下，得到与 renderer 一致的 clef 可见宽度。
static func defaultHorizontalExtents(
    for clef: StaffClef,
    targetHeight: CGFloat,
    targetWidth: CGFloat,
    downwardShiftRatio: CGFloat,
    bundle: Bundle = .main
) -> StaffClefHorizontalExtents? {
    guard targetHeight > 0, targetWidth > 0 else {
        return nil
    }

    guard let measuredMetrics = defaultMeasuredMetrics(
        for: clef,
        bundle: bundle
    ) else {
        return nil
    }

    let baseOpticalWidth = measuredMetrics.opticalWidthToFontSize * targetHeight
    let baseOpticalHeight = measuredMetrics.opticalHeightToFontSize * targetHeight
    let widthScale = targetWidth / max(baseOpticalWidth, 1)
    let heightScale = targetHeight / max(baseOpticalHeight, 1)
    let fitScale = min(
        max(min(widthScale, heightScale), 0.01),
        1
    )
    let resolvedOpticalWidth = baseOpticalWidth * fitScale
    let anchorMetrics = anchorMetrics(
        for: clef,
        downwardShiftRatio: downwardShiftRatio
    )

    return StaffClefHorizontalExtents(
        leading: resolvedOpticalWidth * anchorMetrics.xRatio,
        trailing: resolvedOpticalWidth * (1 - anchorMetrics.xRatio)
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift
// 函数/成员: CoreTextMusicGlyphRenderer.targetSize(for:geometry:)
// 功能说明: 修改后 renderer 与几何层共享同一个 anchoredTargetWidthRatio 常量，
// 避免“几何层按一种宽度估算、renderer 按另一种宽度实际绘制”导致重新出现间距漂移。
private func targetSize(
    for glyphItem: StaffGlyphItem,
    geometry: StaffGeometry
) -> CGSize {
    switch glyphItem.placement {
    case let .anchor(anchor):
        return CGSize(
            width: max(
                geometry.clefAreaRect.width * StaffClefLayoutGuide.anchoredTargetWidthRatio,
                1
            ),
            height: max(anchor.targetHeight, 1)
        )
    case let .frame(frame):
        return CGSize(
            width: max(frame.width, 1),
            height: max(frame.height, 1)
        )
    }
}
```

## 修改 4：回归验证新增 clef 可见边界护栏

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.validateAccidentals(scene:geometry:fixture:record:)
// 功能说明: 修改前验证只检查调号序列、staffPosition、x 递增以及首个 note cluster 不要侵入调号区；
// 但没有检查“首个调号 glyph 是否被 clefAreaRect 的空白错误推远”。
let actualKeySignatureSymbols = actualKeySignatureGlyphs.map(\.symbolID)
if actualKeySignatureSymbols != expectedKeySignatureSymbols {
    record("key signature accidental 序列错误，期望 \(expectedKeySignatureSymbols)，实际 \(actualKeySignatureSymbols)。")
}

let expectedKeySignatureStaffPositions = expectedKeySignatureStaffPositions(
    clef: fixture.configuration.clef,
    keySignature: fixture.score.keySignature,
    notationDisplayOptions: fixture.notationDisplayOptions
)
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.validateAccidentals(scene:geometry:fixture:record:)
// 功能说明: 修改后新增“首个调号 glyph 起点”和“不得侵入 clef 实际可见边界”两条自动化护栏；
// 这能直接防止后续又把内容起点退回到 clefAreaRect.maxX。
let actualKeySignatureSymbols = actualKeySignatureGlyphs.map(\.symbolID)
if actualKeySignatureSymbols != expectedKeySignatureSymbols {
    record("key signature accidental 序列错误，期望 \(expectedKeySignatureSymbols)，实际 \(actualKeySignatureSymbols)。")
}

if let firstKeySignatureFrame = actualKeySignatureFrames.first {
    let expectedStartX = geometry.clefContentStartX(
        for: fixture.configuration.clef,
        gapInSpaces: StaffSceneBuilder.LayoutMetrics.default.clefToNoteGapInSpaces
    )
    if !approximatelyEqual(firstKeySignatureFrame.minX, expectedStartX) {
        record("首个 key signature accidental 起点错误，期望 \(expectedStartX)，实际 \(firstKeySignatureFrame.minX)。")
    }

    if firstKeySignatureFrame.minX <= geometry.clefVisibleMaxX(for: fixture.configuration.clef) + tolerance {
        record("首个 key signature accidental 侵入 clef 可见边界。")
    }
}

let expectedKeySignatureStaffPositions = expectedKeySignatureStaffPositions(
    clef: fixture.configuration.clef,
    keySignature: fixture.score.keySignature,
    notationDisplayOptions: fixture.notationDisplayOptions
)
```

## 修改 5：手工回归清单明确修复目标，不再只关注调号数量和顺序

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.manualChecklist(for:)
// 功能说明: 修改前手工清单要求检查调号 glyph 的数量、顺序和垂直落点，
// 但没有把“调号应当贴近 clef 实际可见右边界”写成明确验收条件。
var checklist = [
    "启动 App，确认默认五线谱已恢复完整记谱显示，且默认 demo 已切到命名调号输入示例：当前应能看到 `D大调` 对应的 key signature，同时保留 stem，以及需要时的 accidental / ledger line。",
    "将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 major circle-of-fifths 参考谱例：`C / G / D / A / E / B / F# / C# / F / Bb / Eb / Ab / Db / Gb / Cb`，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确。"
]
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationRunner.manualChecklist(for:)
// 功能说明: 修改后把“首个调号 glyph 应紧贴 clef 实际可见右边界”写进手工清单，
// 让视觉验收目标与自动回归护栏保持一致。
var checklist = [
    "启动 App，确认默认五线谱已恢复完整记谱显示，且默认 demo 已切到命名调号输入示例：当前应能看到 `D大调` 对应的 key signature，同时保留 stem，以及需要时的 accidental / ledger line。",
    "将共享 score 临时切到 `StaffScoreFixtures.keySignatureReference(...)` 的 major circle-of-fifths 参考谱例：`C / G / D / A / E / B / F# / C# / F / Bb / Eb / Ab / Db / Gb / Cb`，并在 Treble / Bass 间切换；确认调号 glyph 数量、sharp/flat 顺序和垂直落点正确，同时首个调号 glyph 紧贴 clef 实际可见右边界，不再被整块 clefArea 预留宽度推得过远。"
]
```

## 本次明确未采用的修法

- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift` 里的 `clefAreaWidthRatio`
- 未压缩 `StaffSceneBuilder.LayoutMetrics.keySignatureAccidentalSpacingToAccidentalWidth`
- 未压缩 `StaffSceneBuilder.LayoutMetrics.keySignatureToNoteGapInSpaces`
- 这意味着本次不是通过“把常量调小一些”来掩盖现象，而是把内容起点语义改回到 clef 实际可见边界

## 本次明确未修改的其他边界

- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffKeySignatureLayout.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffAccidentalContext.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Staff/StaffScoreDecoding.swift`
- 未修改平台控制器与 demo fixture 输入入口

## 验证结果

### 静态检查

- `ReadLints` 检查以下文件，结果为无错误：
- `NoteMaster_Ver_1/Shared/Staff/StaffClefLayoutGuide.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Staff/CoreTextMusicGlyphRenderer.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 共享层 Swift 类型检查，确认 clef 与调号间距根因修复没有引入编译错误。
xcrun swiftc -typecheck \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  NoteMaster_Ver_1/Shared/Controls/*.swift
```

- 结果：通过

### 命令行验证

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 编译并执行 StaffValidationRunner.run(platform: .commandLine)，确认 clef 可见边界修复与既有调号回归矩阵同时通过。
xcrun swiftc -o /tmp/staff_clef_gap_fix_check \
  NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  /tmp/staff_phase2_check.swift && \
/tmp/staff_clef_gap_fix_check
```

- 结果：`[StaffValidation][commandLine] automated=PASS fixtures=53`
- 结论：修复后，命名调号 decode、major circle-of-fifths、G/A/Bb accidental context、`noteheadsOnly / fullNotation` 切换，以及新增的 clef 可见边界护栏全部保持通过

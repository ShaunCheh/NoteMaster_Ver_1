# 20260326_153227_phase3_scene_builder_key_signature_measure_flow

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_153227`
- 记录范围：`调号支持` 的阶段 3 实施
- 本次目标：把 `StaffSceneBuilder` 重构为 `clef -> keySignature -> measures -> notes`，并让 `StaffSceneProvider` 不再吞掉 `keySignature-only` 场景
- 根因结论：阶段 2 之后虽然已经有了 `StaffKeySignatureLayout` 和 `StaffAccidentalContext`，但 scene 生成链路仍然把横向布局建立在“只有 clef + note 序列”的前提上；`noteAreaRect` 还不知道调号 cluster 的宽度，`StaffSceneProvider` 也会在 `score.notes` 为空时绕过 builder，导致“只有调号、没有 note”的 score 直接丢失
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`

## 本次完成的修改

1. `StaffSceneBuilder.makeScene(geometry:)` 现在正式按 `clef -> keySignature -> measures -> notes` 生成 scene。
2. `StaffSceneBuilder.LayoutMetrics` 增加了调号到音符区的间距参数，不再只围绕 clef 和单 note accidental 预留空间。
3. 调号 cluster 的 x 方向排布已接入 `StaffKeySignatureLayout`，scene 可以直接产出 key signature glyph。
4. note 横向布局改成按“每个 note 实际需要的 leading accessory 宽度”分配空间，避免 accidental 与调号区重叠。
5. `StaffSceneProvider` 只要拿到 `score` 就会走 builder，因此 `keySignature-only` 的 score 不会再被误判为空场景。

## 修改 1：`StaffSceneBuilder.makeScene(geometry:)` 从“clef + note 列表”升级为“clef -> keySignature -> measures -> notes”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.makeScene(geometry:)
// 功能说明: 修改前 scene builder 只会先画 clef，然后直接按平铺 notes 生成 notehead / accidental / stem / ledger line；
// keySignature 既没有独立 cluster，也没有独立横向区域。
func makeScene(geometry: StaffGeometry) -> StaffScene {
    guard !geometry.drawingRect.isNull else {
        return .empty
    }

    var glyphs: [StaffGlyphItem] = [
        StaffGlyphItem(
            symbolID: clefSymbolID,
            placement: .anchor(geometry.clefAnchor(for: clef)),
            tintColor: glyphTintColor,
            renderHint: clefRenderHint
        )
    ]
    var strokeItems: [StaffStrokeItem] = []

    guard !score.notes.isEmpty else {
        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            strokeItems: strokeItems,
            glyphs: glyphs
        )
    }

    let pitchLayout = StaffPitchLayout(clef: clef)
    let noteFrames = makeNoteheadFrames(
        noteCount: score.notes.count,
        geometry: geometry
    )
    var noteFrameIndex = 0
    var accidentalContext = StaffAccidentalContext(
        keySignature: score.keySignature
    )

    for measure in score.measures {
        accidentalContext.resetForMeasure()

        for note in measure.notes {
            guard noteFrameIndex < noteFrames.count else {
                break
            }

            let noteheadFrame = noteFrames[noteFrameIndex]
            noteFrameIndex += 1
            // ... 后续继续直接画 note accidental / notehead / stem / ledger line
        }
    }

    return StaffScene(
        lineSegments: geometry.staffLineSegments,
        strokeItems: strokeItems,
        glyphs: glyphs
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.makeScene(geometry:)
// 功能说明: 修改后 scene builder 会先生成 keySignature glyph cluster，
// 再基于 measure 级 accidental context 和 keySignatureClusterWidth 计算 note 区域与 note cluster 的真实布局。
func makeScene(geometry: StaffGeometry) -> StaffScene {
    guard !geometry.drawingRect.isNull else {
        return .empty
    }

    let noteheadSize = resolvedNoteheadSize(geometry: geometry)
    var glyphs: [StaffGlyphItem] = [
        StaffGlyphItem(
            symbolID: clefSymbolID,
            placement: .anchor(geometry.clefAnchor(for: clef)),
            tintColor: glyphTintColor,
            renderHint: clefRenderHint
        )
    ]
    var strokeItems: [StaffStrokeItem] = []

    let keySignatureGlyphLayouts = resolvedKeySignatureGlyphLayouts(
        geometry: geometry,
        noteheadSize: noteheadSize
    )
    glyphs.append(
        contentsOf: keySignatureGlyphLayouts.map {
            StaffGlyphItem(
                symbolID: $0.symbolID,
                placement: .frame($0.frame),
                tintColor: glyphTintColor,
                renderHint: .accidental()
            )
        }
    )

    let noteSemanticLayouts = resolvedNoteSemanticLayouts(geometry: geometry)
    let noteLayouts = resolvedNoteLayouts(
        noteSemanticLayouts: noteSemanticLayouts,
        geometry: geometry,
        noteheadSize: noteheadSize,
        keySignatureClusterWidth: resolvedKeySignatureClusterWidth(
            from: keySignatureGlyphLayouts
        )
    )

    for noteLayout in noteLayouts {
        if notationDisplayOptions.showsAccidentals,
           let displayedAccidental = noteLayout.displayedAccidental,
           let accidentalSymbolID = accidentalSymbolID(for: displayedAccidental) {
            glyphs.append(
                StaffGlyphItem(
                    symbolID: accidentalSymbolID,
                    placement: .frame(
                        accidentalFrame(
                            for: noteLayout.noteheadFrame,
                            centerY: noteLayout.positionedPitch.centerY
                        )
                    ),
                    tintColor: glyphTintColor,
                    renderHint: .accidental()
                )
            )
        }

        glyphs.append(
            StaffGlyphItem(
                symbolID: noteheadSymbolID(for: noteLayout.note.duration),
                placement: .frame(noteLayout.noteheadFrame),
                tintColor: glyphTintColor,
                renderHint: .notehead()
            )
        )
        // ... 后续继续生成 stem / ledger line
    }

    return StaffScene(
        lineSegments: geometry.staffLineSegments,
        strokeItems: strokeItems,
        glyphs: glyphs
    )
}
```

## 修改 2：`StaffSceneBuilder` 的横向分区从“clef 后直接 noteArea”升级为“clefArea -> keySignatureArea -> noteArea”

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.makeNoteheadFrames(noteCount:geometry:) / resolvedNoteAreaRect(geometry:) / resolvedNoteCenterXs(noteCount:noteAreaRect:noteheadWidth:leftInset:rightInset:)
// 功能说明: 修改前 note 区域只考虑 clef 之后的整体空间；
// leftInset 只会围绕“单个 note 可能有 accidental”做保守预留，不知道 keySignature cluster 的真实宽度。
private func makeNoteheadFrames(
    noteCount: Int,
    geometry: StaffGeometry
) -> [CGRect] {
    guard
        noteCount > 0,
        !geometry.drawingRect.isNull,
        geometry.staffSpaceHeight > 0
    else {
        return []
    }

    let noteheadSize = resolvedNoteheadSize(geometry: geometry)
    let noteAreaRect = resolvedNoteAreaRect(geometry: geometry)
    guard !noteAreaRect.isNull, !noteAreaRect.isEmpty else {
        return []
    }

    let accidentalWidth = noteheadSize.width * layoutMetrics.accidentalWidthToNoteheadWidth
    let accidentalGap = noteheadSize.width * layoutMetrics.accidentalGapToNoteheadWidth
    let minimumLeadingInset = noteheadSize.width * layoutMetrics.noteLeadingInsetInNoteheadWidths
    let leftInset = notationDisplayOptions.showsAccidentals
        ? max(
            minimumLeadingInset,
            accidentalWidth + accidentalGap + (noteheadSize.width / 2)
        )
        : minimumLeadingInset
    let rightInset = noteheadSize.width * layoutMetrics.noteTrailingInsetInNoteheadWidths

    let centerXs = resolvedNoteCenterXs(
        noteCount: noteCount,
        noteAreaRect: noteAreaRect,
        noteheadWidth: noteheadSize.width,
        leftInset: leftInset,
        rightInset: rightInset
    )

    return centerXs.map {
        centeredFrame(
            center: CGPoint(x: $0, y: geometry.staffRect.midY),
            size: noteheadSize
        )
    }
}

private func resolvedNoteAreaRect(
    geometry: StaffGeometry
) -> CGRect {
    let minX = min(
        geometry.clefAreaRect.maxX
            + (geometry.staffSpaceHeight * layoutMetrics.clefToNoteGapInSpaces),
        geometry.drawingRect.maxX
    )
    // ...
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.resolvedKeySignatureGlyphLayouts(geometry:noteheadSize:) / resolvedNoteLayouts(noteSemanticLayouts:geometry:noteheadSize:keySignatureClusterWidth:) / resolvedNoteAreaRect(geometry:keySignatureClusterWidth:) / resolvedNoteCenterXs(noteAreaRect:noteheadWidth:leadingAccessoryWidths:)
// 功能说明: 修改后 note 区域起点明确受 keySignatureClusterWidth 控制，
// 每个 note 的横向中心点也由“该 note 实际需要的 leading accessory 宽度”参与计算，不再是单一 leftInset。
private func resolvedKeySignatureGlyphLayouts(
    geometry: StaffGeometry,
    noteheadSize: CGSize
) -> [KeySignatureGlyphLayout] {
    guard notationDisplayOptions.showsAccidentals else {
        return []
    }

    let keySignatureAccidentals = StaffKeySignatureLayout(clef: clef)
        .positionedAccidentals(
            for: score.keySignature,
            in: geometry
        )
    guard !keySignatureAccidentals.isEmpty else {
        return []
    }

    let accidentalSize = resolvedAccidentalSize(noteheadSize: noteheadSize)
    let startX = resolvedContentStartX(geometry: geometry)
    let spacing = accidentalSize.width
        * layoutMetrics.keySignatureAccidentalSpacingToAccidentalWidth

    return keySignatureAccidentals.enumerated().map { index, accidental in
        let centerX = startX
            + (accidentalSize.width / 2)
            + (CGFloat(index) * (accidentalSize.width + spacing))
        return KeySignatureGlyphLayout(
            symbolID: accidental.symbolID,
            frame: centeredFrame(
                center: CGPoint(x: centerX, y: accidental.centerY),
                size: accidentalSize
            )
        )
    }
}

private func resolvedNoteAreaRect(
    geometry: StaffGeometry,
    keySignatureClusterWidth: CGFloat
) -> CGRect {
    let contentStartX = resolvedContentStartX(geometry: geometry)
    let minX = min(
        contentStartX
            + keySignatureClusterWidth
            + (
                keySignatureClusterWidth > 0
                ? geometry.staffSpaceHeight * layoutMetrics.keySignatureToNoteGapInSpaces
                : 0
            ),
        geometry.drawingRect.maxX
    )
    // ...
}

private func resolvedNoteCenterXs(
    noteAreaRect: CGRect,
    noteheadWidth: CGFloat,
    leadingAccessoryWidths: [CGFloat]
) -> [CGFloat] {
    let clusterWidths = leadingAccessoryWidths.map { $0 + noteheadWidth }
    let totalClusterWidth = clusterWidths.reduce(0, +)
    let remainingWidth = max(noteAreaRect.width - totalClusterWidth, 0)

    // ... 中间省略 leading / trailing inset 和 interClusterGap 计算

    var currentX = noteAreaRect.minX + appliedLeadingInset
    var centerXs: [CGFloat] = []
    for index in leadingAccessoryWidths.indices {
        centerXs.append(
            currentX + leadingAccessoryWidths[index] + (noteheadWidth / 2)
        )
        currentX += clusterWidths[index] + interClusterGap
    }
    return centerXs
}
```

## 修改 3：`StaffSceneProvider` 不再把 `keySignature-only` 的 score 判成空场景

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: StaffSceneProvider.makeScene(geometry:)
// 功能说明: 修改前 provider 只有在 score 非空且 score.notes 非空时才会走 builder；
// 如果 score 里只有 clef + keySignature、没有 notes，就会错误回退到 clef-only 场景。
func makeScene(geometry: StaffGeometry) -> StaffScene {
    guard !geometry.drawingRect.isNull else {
        return .empty
    }

    if let score, !score.isEmpty {
        #if DEBUG
        if score.clef != clef {
            assertionFailure(
                "StaffSceneProvider received score.clef that does not match provider clef; provider clef will be used for layout."
            )
        }
        #endif

        return StaffSceneBuilder(
            clef: clef,
            score: score,
            notationDisplayOptions: notationDisplayOptions,
            glyphTintColor: glyphTintColor,
            clefRenderHint: renderHint
        ).makeScene(geometry: geometry)
    }

    // ... 后续回退到 clef-only scene
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: StaffSceneProvider.makeScene(geometry:)
// 功能说明: 修改后 provider 只要拿到 score 就交给 builder；
// 这样“只有 keySignature、没有 notes”的 score 也能通过 scene builder 生成调号 cluster。
func makeScene(geometry: StaffGeometry) -> StaffScene {
    guard !geometry.drawingRect.isNull else {
        return .empty
    }

    if let score {
        #if DEBUG
        if score.clef != clef {
            assertionFailure(
                "StaffSceneProvider received score.clef that does not match provider clef; provider clef will be used for layout."
            )
        }
        #endif

        return StaffSceneBuilder(
            clef: clef,
            score: score,
            notationDisplayOptions: notationDisplayOptions,
            glyphTintColor: glyphTintColor,
            clefRenderHint: renderHint
        ).makeScene(geometry: geometry)
    }

    // ... 后续无 score 时仍保持 clef-only 回退路径
}
```

## 验证结果

1. `ReadLints`：本轮修改的 `StaffSceneBuilder.swift`、`StaffSceneProvider.swift` 无新增 IDE 诊断。
2. 共享层静态类型校验通过：

```bash
# 文件路径: 命令行验证（无源码文件）
# 函数/成员: xcrun swiftc -typecheck
# 功能说明: 对 Shared/Fretboard/NotePitch.swift 与 Shared/Staff/*.swift 做阶段 3 静态类型校验。
xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Staff/*.swift
```

3. 阶段 3 语义校验通过，关键结果如下：
- `keyOnlyFull=trebleClef,accidentalSharp,accidentalSharp`
- `keyOnlyHidden=trebleClef`
- `cMajorDistance=4.98`
- `gMajorDistance=120.23`
- `resetAccidentals=accidentalSharp,accidentalNatural,accidentalNatural`

这些结果分别说明：
- `keySignature-only` 的 score 已经能产出调号 scene，而不再掉回 clef-only。
- 在 `noteheadsOnly` 排障显示态下，调号仍会被显示策略正确抑制。
- 同一个 `f#4` 在 C 大调与 G 大调下保持相同书写音高位置，但 accidental 的横向布局与显示策略已经正确不同。
- 跨小节后 accidental context 已经重置回调号默认状态。

## 当前阶段结论

- 阶段 3 已经把调号和小节语义真正接进 scene 生成主链路，不再只是阶段 2 的独立组件堆叠。
- 当前默认 UI 仍然停在 `noteheadsOnly` 排障态，所以这一步的结果已经进入共享 scene，但平台界面默认不会把调号直接显示出来。
- 下一阶段应恢复完整记谱显示策略，并让调号 accidental 与 note accidental 共用同一套显示开关。

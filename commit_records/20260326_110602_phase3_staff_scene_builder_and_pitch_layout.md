# 20260326_110602_phase3_staff_scene_builder_and_pitch_layout

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_110602`
- 记录范围：`五线谱音符渲染` 的阶段 3 实施
- 本次目标：新增共享层 `StaffSceneBuilder` 和 `StaffPitchLayout`，把 `StaffScore` 真正转换成 `clef + notehead + accidental + stem + ledger line`
- 根因结论：阶段 2 已经把 `StaffScene` / `renderer` 通用化，但还没有“从乐谱语义到可绘制场景”的核心算法：
  - `Shared/Staff` 还没有统一的 `StaffScore -> StaffScene` builder
  - 没有 treble / bass 下的音高到五线谱位置映射
  - `StaffSceneProvider` 仍然只会画 clef
  - `StaffGeometry` 也还没暴露 builder 真正需要的步进几何量
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
  - 新增 `NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift`
  - 新增 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`

## 本次完成的修改

1. 在 `StaffGeometry` 中新增 `staffLineCount`、`staffSpaceHeight`、`staffStepHeight`、`topLineY`、`bottomLineY`，把 builder 所需几何量收口为共享属性。
2. 新增 `StaffPitchLayout`，统一计算：
   - treble / bass 下的音高垂直位置
   - 符干方向
   - ledger line 的 y 坐标
   - accidental 对应的 glyph symbol
3. 新增 `StaffSceneBuilder`，把 `StaffScore` 转成 `StaffScene`，产出：
   - clef glyph
   - accidental glyph
   - notehead glyph
   - stem stroke
   - ledger line stroke
4. 修改 `StaffSceneProvider`，支持可选 `score`，有 score 时走 builder，无 score 时保持旧的 clef-only 回退路径。

## 修改 1：给 `StaffGeometry` 暴露 builder 需要的公共几何量

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数/成员: StaffGeometry
// 功能说明: 修改前 StaffGeometry 只暴露 drawingRect、staffRect、clefAreaRect、staffHeight 和 lineY / spaceCenterY；
// builder 如果要做音高步进定位，只能重复推导 staffLineCount、spaceHeight、stepHeight 和底线位置。
struct StaffGeometry: Equatable, Sendable {
    // ...
    var staffHeight: CGFloat {
        guard !drawingRect.isNull else {
            return 0
        }

        return configuration.layoutMetrics.staffHeight()
    }
    // ...
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift
// 函数/成员: staffLineCount / staffSpaceHeight / staffStepHeight / topLineY / bottomLineY
// 功能说明: 修改后 StaffGeometry 直接暴露 builder 所需的公共几何量，
// 后续 pitch layout 不再自己重复拼装五线谱步进数据。
struct StaffGeometry: Equatable, Sendable {
    // ...
    var staffLineCount: Int {
        resolvedStaffLineCount
    }

    var staffSpaceHeight: CGFloat {
        resolvedStaffSpaceHeight
    }

    var staffStepHeight: CGFloat {
        resolvedStaffSpaceHeight / 2
    }

    var topLineY: CGFloat? {
        lineY(at: 0)
    }

    var bottomLineY: CGFloat? {
        lineY(at: resolvedStaffLineCount - 1)
    }
    // ...
}
```

## 修改 2：新增 `StaffPitchLayout`，收口 treble / bass 下的音高定位算法

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift
// 函数/成员: 文件级（此前不存在）
// 功能说明: 修改前 Shared/Staff 下没有统一的 pitch layout 层；
// treble / bass 的底线参考音、符干方向和加线计算都还没有共享实现。
// 修改前: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift
// 函数/成员: StaffPitchLayout.positionedPitch(_:in:) / bottomLineReferencePitch / stemDirection(for:geometry:) / ledgerLineYs(for:geometry:)
// 功能说明: 修改后 Shared/Staff 有了独立的音高布局层；
// 它把 StaffPitch 映射为 staffPosition、centerY、stemDirection、ledgerLineYs 和 accidental glyph，供 scene builder 直接消费。
struct StaffPitchLayout: Equatable, Sendable {
    struct PositionedPitch: Equatable, Sendable {
        var staffPosition: Int
        var centerY: CGFloat
        var stemDirection: StemDirection
        var ledgerLineYs: [CGFloat]
        var accidentalSymbolID: StaffGlyphSymbolID?
    }

    func positionedPitch(
        _ pitch: StaffPitch,
        in geometry: StaffGeometry
    ) -> PositionedPitch? {
        guard
            let bottomLineY = geometry.bottomLineY,
            geometry.staffStepHeight > 0
        else {
            return nil
        }

        let staffPosition = pitch.diatonicIndex - bottomLineReferencePitch.diatonicIndex
        let centerY = bottomLineY - (CGFloat(staffPosition) * geometry.staffStepHeight)

        return PositionedPitch(
            staffPosition: staffPosition,
            centerY: centerY,
            stemDirection: stemDirection(
                for: staffPosition,
                geometry: geometry
            ),
            ledgerLineYs: ledgerLineYs(
                for: staffPosition,
                geometry: geometry
            ),
            accidentalSymbolID: accidentalSymbolID(for: pitch.accidental)
        )
    }

    private var bottomLineReferencePitch: StaffPitch {
        switch clef {
        case .treble:
            return StaffPitch(letter: .e, octave: 4)
        case .bass:
            return StaffPitch(letter: .g, octave: 2)
        }
    }
}
```

## 修改 3：新增 `StaffSceneBuilder`，把 `StaffScore` 转成可绘制场景

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: 文件级（此前不存在）
// 功能说明: 修改前 Shared/Staff 下没有 builder 承接 StaffScore；
// 即使已有 score、scene 和 renderer，也没有地方负责把音符排成 notehead / accidental / stem / ledger line。
// 修改前: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: makeScene(geometry:) / makeNoteheadFrames(noteCount:geometry:) / stemStroke(for:positionedPitch:geometry:) / ledgerLineStrokes(for:ledgerLineYs:)
// 功能说明: 修改后 builder 成为 Shared/Staff 中承接 score 语义的主入口；
// 它负责 clef 以外的 note glyph / stroke 生产，把 score 转为 renderer 可直接消费的 scene。
struct StaffSceneBuilder: Equatable, Sendable {
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

        for (note, noteheadFrame) in zip(score.notes, noteFrames) {
            // accidental glyph
            // notehead glyph
            // stem stroke
            // ledger line strokes
        }

        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            strokeItems: strokeItems,
            glyphs: glyphs
        )
    }
}
```

## 修改 4：让 `StaffSceneProvider` 接入 builder，并保留 clef-only 回退

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: StaffSceneProvider / makeScene(geometry:)
// 功能说明: 修改前 provider 只有 clef、glyphTintColor、renderHint 三个输入；
// makeScene(geometry:) 只会返回 clef glyph，不承接 score，也不会调 builder。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var glyphTintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
        }

        let glyphs = [
            StaffGlyphItem(
                symbolID: symbolID(for: clef),
                placement: .anchor(geometry.clefAnchor(for: clef)),
                tintColor: glyphTintColor,
                renderHint: renderHint
            )
        ]

        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            strokeItems: [],
            glyphs: glyphs
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: StaffSceneProvider / makeScene(geometry:)
// 功能说明: 修改后 provider 可以选择性持有 score；
// 有 score 时统一交给 StaffSceneBuilder，无 score 时继续维持 clef-only 行为，避免当前 UI 直接回归。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var score: StaffScore?
    var glyphTintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
        }

        if let score, !score.isEmpty {
            return StaffSceneBuilder(
                clef: clef,
                score: score,
                glyphTintColor: glyphTintColor,
                clefRenderHint: renderHint
            ).makeScene(geometry: geometry)
        }

        let glyphs = [
            StaffGlyphItem(
                symbolID: symbolID(for: clef),
                placement: .anchor(geometry.clefAnchor(for: clef)),
                tintColor: glyphTintColor,
                renderHint: renderHint
            )
        ]

        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            strokeItems: [],
            glyphs: glyphs
        )
    }
}
```

## 修改结果说明

- 阶段 3 已经把“从乐谱语义到场景结果”的根路径打通了，但还没有把 `score` 接进 `StaffDisplayState` 和 controller。
- 这一步完成后，Shared/Staff 现在已经具备：
  - 共享领域输入：`StaffScore`
  - 音高布局层：`StaffPitchLayout`
  - 场景构建层：`StaffSceneBuilder`
  - 渲染投影入口：`StaffSceneProvider(score: ...)`
- 下一阶段只需要把 score 注入现有平台状态链路，就能在界面上真实显示音符。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Shared/Staff/StaffGeometry.swift`
   - `NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift`
   - `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
   - `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
2. 执行以下静态校验通过：
   - `xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Staff/*.swift`
3. 当前已知未覆盖项：
   - 还未把 `score` 接到 `StaffDisplayState`
   - 还未把 demo fixture 注入 iOS / macOS controller
   - 还未做运行态五线谱显示联调

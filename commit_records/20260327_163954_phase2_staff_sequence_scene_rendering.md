# 20260327_163954_phase2_staff_sequence_scene_rendering

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_163954`
- 记录范围：实施 `staff序列反馈` 计划的阶段 2，把 `sequencePresentation` 真正接入 shared 的 `StaffSceneProvider -> StaffSceneBuilder -> StaffScene` 渲染链
- 本次目标：让 shared scene 直接表达两类 sequence 反馈语义
- `当前目标音`：通过竖线游标落到当前 note 的 x 位置
- `最近一次判题结果`：通过 note 级别颜色统一作用到 `notehead / accidental / stem / ledger line`
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

## 根因结论

- 阶段 1 之后，`StaffDisplayState` 与 `StaffSceneProvider` 已经可以携带 `sequencePresentation`，但 scene builder 仍然没有消费它，所以共享渲染链依旧只能画静态谱面。
- 如果继续把游标和红绿反馈放在平台层临时叠加，iOS/macOS 就会重复计算 note 位置，重新回到分叉实现。
- 因此阶段 2 的根因级修复，是把 sequence 显示语义直接变成 `StaffScene` 里的颜色和 stroke，而不是新增平台 overlay。

## 修改 1：在 `StaffScene.swift` 中补齐 sequence 颜色与游标 stroke 语义

### 修改前

- `StaffSceneColor` 只有默认墨色和 debug 红色
- `StaffStrokeSemantic` 只有 `stem` 和 `ledgerLine`
- `StaffStrokeStyle` 也只有对应的两种样式工厂

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 类型/函数: StaffSceneColor, StaffStrokeSemantic, StaffStrokeStyle.stem(...), StaffStrokeStyle.ledgerLine(...)
// 功能说明: 修改前 shared staff scene 只能表达普通记谱线段；
// 还没有 sequence 正确/错误颜色和竖线游标的正式语义入口。
struct StaffSceneColor: Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let primaryInk = StaffSceneColor(
        red: 0.12,
        green: 0.12,
        blue: 0.14,
        alpha: 1
    )

    static let debugRed = StaffSceneColor(
        red: 0.88,
        green: 0.18,
        blue: 0.18,
        alpha: 1
    )
}

enum StaffStrokeSemantic: Equatable, Sendable {
    case stem
    case ledgerLine
}

struct StaffStrokeStyle: Equatable, Sendable {
    static func stem(
        strokeColor: StaffSceneColor = .primaryInk,
        lineWidth: CGFloat = 1.4
    ) -> Self { ... }

    static func ledgerLine(
        strokeColor: StaffSceneColor = .primaryInk,
        lineWidth: CGFloat = 1.2
    ) -> Self { ... }
}
```

### 修改后

- `StaffSceneColor` 新增 `sequenceCorrectGreen`、`sequenceIncorrectRed`、`sequenceCursorBlue`
- `StaffStrokeSemantic` 新增 `.sequenceCursor`
- `StaffStrokeStyle` 新增 `sequenceCursor(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 类型/函数: StaffSceneColor, StaffStrokeSemantic, StaffStrokeStyle.sequenceCursor(...)
// 功能说明: 修改后 shared scene 已经能直接表达 sequence 的红绿反馈和竖线游标样式。
struct StaffSceneColor: Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let primaryInk = StaffSceneColor(
        red: 0.12,
        green: 0.12,
        blue: 0.14,
        alpha: 1
    )

    static let debugRed = StaffSceneColor(
        red: 0.88,
        green: 0.18,
        blue: 0.18,
        alpha: 1
    )

    static let sequenceCorrectGreen = StaffSceneColor(
        red: 0.18,
        green: 0.62,
        blue: 0.28,
        alpha: 1
    )

    static let sequenceIncorrectRed = StaffSceneColor(
        red: 0.84,
        green: 0.24,
        blue: 0.2,
        alpha: 1
    )

    static let sequenceCursorBlue = StaffSceneColor(
        red: 0.2,
        green: 0.45,
        blue: 0.9,
        alpha: 0.95
    )
}

enum StaffStrokeSemantic: Equatable, Sendable {
    case stem
    case ledgerLine
    case sequenceCursor
}

struct StaffStrokeStyle: Equatable, Sendable {
    static func sequenceCursor(
        strokeColor: StaffSceneColor = .sequenceCursorBlue,
        lineWidth: CGFloat = 1.6
    ) -> Self {
        StaffStrokeStyle(
            strokeColor: strokeColor,
            lineWidth: max(lineWidth, 0.75),
            lineCap: .round
        )
    }
}
```

## 修改 2：让 `StaffSceneProvider` 把 `sequencePresentation` 继续传给 builder

### 修改前

- `StaffSceneProvider` 已持有 `sequencePresentation`
- 但在构建 `StaffSceneBuilder` 时，这个字段还没有继续传下去

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 类型/函数: StaffSceneProvider.makeScene(geometry:)
// 功能说明: 修改前 provider 虽然保存了 sequencePresentation，
// 但 builder 侧完全收不到这份状态，scene 仍然只能画静态谱面。
return StaffSceneBuilder(
    clef: clef,
    score: score,
    notationDisplayOptions: notationDisplayOptions,
    glyphTintColor: glyphTintColor,
    clefRenderHint: renderHint
).makeScene(geometry: geometry)
```

### 修改后

- `sequencePresentation` 被继续传给 `StaffSceneBuilder`
- 使 builder 能在 note 布局之后决定游标和颜色

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 类型/函数: StaffSceneProvider.makeScene(geometry:)
// 功能说明: 修改后 provider 成为 sequence 展示语义进入 scene builder 的正式入口。
return StaffSceneBuilder(
    clef: clef,
    score: score,
    notationDisplayOptions: notationDisplayOptions,
    sequencePresentation: sequencePresentation,
    glyphTintColor: glyphTintColor,
    clefRenderHint: renderHint
).makeScene(geometry: geometry)
```

## 修改 3：在 `StaffSceneBuilder` 中把 sequence 状态投影成游标和 note 级别颜色

### 修改前

- `StaffSceneBuilder` 没有 `sequencePresentation`
- 所有 note glyph 和 stroke 都统一使用 `glyphTintColor`
- 没有 cursor stroke，也没有按 note index 决定颜色的逻辑

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 类型/函数: StaffSceneBuilder.makeScene(geometry:)
// 功能说明: 修改前 builder 只负责静态记谱布局；
// notehead / accidental / stem / ledger line 全都走同一种颜色。
struct StaffSceneBuilder: Equatable, Sendable {
    var clef: StaffClef
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var glyphTintColor: StaffSceneColor
    var clefRenderHint: StaffGlyphRenderHint
    var layoutMetrics: LayoutMetrics
}

for noteLayout in noteLayouts {
    if notationDisplayOptions.showsNoteAccidentals,
       let displayedAccidental = noteLayout.displayedAccidental,
       let accidentalSymbolID = accidentalSymbolID(for: displayedAccidental) {
        glyphs.append(
            StaffGlyphItem(
                symbolID: accidentalSymbolID,
                placement: .frame(...),
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

    if notationDisplayOptions.showsStems,
       noteLayout.note.duration.showsStem {
        strokeItems.append(
            stemStroke(
                for: noteLayout.noteheadFrame,
                positionedPitch: noteLayout.positionedPitch,
                geometry: geometry
            )
        )
    }
}
```

### 修改后

- `StaffSceneBuilder` 新增 `sequencePresentation`
- 在 note 布局完成后先尝试生成 `sequenceCursor`
- 按 note 的扁平顺序给每个 note 计算 `noteTintColor`
- `notehead / accidental / stem / ledger line` 使用同一反馈色，避免平台层分别高亮不同子图元

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 类型/函数: StaffSceneBuilder.makeScene(geometry:)
// 功能说明: 修改后 builder 会把 sequence 状态投影成游标和整颗音符的颜色反馈。
struct StaffSceneBuilder: Equatable, Sendable {
    var clef: StaffClef
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var sequencePresentation: StaffSequencePresentation?
    var glyphTintColor: StaffSceneColor
    var clefRenderHint: StaffGlyphRenderHint
    var layoutMetrics: LayoutMetrics
}

if let cursorStroke = sequenceCursorStroke(
    noteLayouts: noteLayouts,
    geometry: geometry
) {
    strokeItems.append(cursorStroke)
}

let noteCount = noteLayouts.count
for (noteIndex, noteLayout) in noteLayouts.enumerated() {
    let noteTintColor = noteTintColor(
        for: noteIndex,
        noteCount: noteCount
    )

    if notationDisplayOptions.showsNoteAccidentals,
       let displayedAccidental = noteLayout.displayedAccidental,
       let accidentalSymbolID = accidentalSymbolID(for: displayedAccidental) {
        glyphs.append(
            StaffGlyphItem(
                symbolID: accidentalSymbolID,
                placement: .frame(...),
                tintColor: noteTintColor,
                renderHint: .accidental()
            )
        )
    }

    glyphs.append(
        StaffGlyphItem(
            symbolID: noteheadSymbolID(for: noteLayout.note.duration),
            placement: .frame(noteLayout.noteheadFrame),
            tintColor: noteTintColor,
            renderHint: .notehead()
        )
    )

    if notationDisplayOptions.showsStems,
       noteLayout.note.duration.showsStem {
        strokeItems.append(
            stemStroke(
                for: noteLayout.noteheadFrame,
                positionedPitch: noteLayout.positionedPitch,
                geometry: geometry,
                strokeColor: noteTintColor
            )
        )
    }

    if notationDisplayOptions.showsLedgerLines {
        strokeItems.append(
            contentsOf: ledgerLineStrokes(
                for: noteLayout.noteheadFrame,
                ledgerLineYs: noteLayout.positionedPitch.ledgerLineYs,
                strokeColor: noteTintColor
            )
        )
    }
}
```

## 修改 4：把 builder 的辅助函数扩展为 sequence 专用语义入口

### 修改前

- `stemStroke(...)` 和 `ledgerLineStrokes(...)` 直接闭包捕获 `glyphTintColor`
- 没有专门解析 `cursorIndex / lastEvaluatedIndex` 的辅助函数

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 类型/函数: stemStroke(...), ledgerLineStrokes(...)
// 功能说明: 修改前辅助函数只能生成默认颜色的 stem / ledger line，
// 也没有 sequence 当前题索引的解析和保护逻辑。
private func stemStroke(
    for noteheadFrame: CGRect,
    positionedPitch: StaffPitchLayout.PositionedPitch,
    geometry: StaffGeometry
) -> StaffStrokeItem {
    StaffStrokeItem(
        semantic: .stem,
        start: CGPoint(x: stemX, y: startY),
        end: CGPoint(x: stemX, y: endY),
        style: .stem(
            strokeColor: glyphTintColor
        )
    )
}

private func ledgerLineStrokes(
    for noteheadFrame: CGRect,
    ledgerLineYs: [CGFloat]
) -> [StaffStrokeItem] {
    ledgerLineYs.map {
        StaffStrokeItem(
            semantic: .ledgerLine,
            start: CGPoint(x: startX, y: $0),
            end: CGPoint(x: endX, y: $0),
            style: .ledgerLine(
                strokeColor: glyphTintColor
            )
        )
    }
}
```

### 修改后

- `stemStroke(...)` 和 `ledgerLineStrokes(...)` 改为显式接收 `strokeColor`
- 新增 `noteTintColor(...)`
- 新增 `sequenceCursorStroke(...)`
- 新增 `resolvedSequenceIndex(...)`，对 `cursorIndex` / `lastEvaluatedIndex` 做渲染边界校验

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 类型/函数: stemStroke(...), ledgerLineStrokes(...), noteTintColor(...),
// sequenceCursorStroke(...), resolvedSequenceIndex(...)
// 功能说明: 修改后辅助函数把 sequence 反馈收敛到 builder 内部，避免平台重复推导。
private func stemStroke(
    for noteheadFrame: CGRect,
    positionedPitch: StaffPitchLayout.PositionedPitch,
    geometry: StaffGeometry,
    strokeColor: StaffSceneColor
) -> StaffStrokeItem {
    StaffStrokeItem(
        semantic: .stem,
        start: CGPoint(x: stemX, y: startY),
        end: CGPoint(x: stemX, y: endY),
        style: .stem(
            strokeColor: strokeColor
        )
    )
}

private func ledgerLineStrokes(
    for noteheadFrame: CGRect,
    ledgerLineYs: [CGFloat],
    strokeColor: StaffSceneColor
) -> [StaffStrokeItem] {
    ledgerLineYs.map {
        StaffStrokeItem(
            semantic: .ledgerLine,
            start: CGPoint(x: startX, y: $0),
            end: CGPoint(x: endX, y: $0),
            style: .ledgerLine(
                strokeColor: strokeColor
            )
        )
    }
}

private func noteTintColor(
    for noteIndex: Int,
    noteCount: Int
) -> StaffSceneColor { ... }

private func sequenceCursorStroke(
    noteLayouts: [PositionedNoteLayout],
    geometry: StaffGeometry
) -> StaffStrokeItem? { ... }

private func resolvedSequenceIndex(
    _ index: Int?,
    label: String,
    noteCount: Int
) -> Int? { ... }
```

## 修改 5：在 `StaffValidation.swift` 中接住新的 `sequenceCursor` 语义

### 修改前

- `validateStrokeSemantics(...)` 的 `switch` 只覆盖 `stem` 和 `ledgerLine`
- 一旦引入新的 stroke semantic，validation 就不会检查它的几何合法性

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 类型/函数: validateStrokeSemantics(scene:fixture:record:)
// 功能说明: 修改前 validation 只校验 stem / ledger line 两类 stroke 语义。
switch stroke.semantic {
case .stem:
    if !approximatelyEqual(stroke.start.x, stroke.end.x) {
        record("stem[\\(index)] 不是竖线。")
    }
case .ledgerLine:
    if !approximatelyEqual(stroke.start.y, stroke.end.y) {
        record("ledgerLine[\\(index)] 不是横线。")
    }

    if !(stroke.end.x > stroke.start.x + tolerance) {
        record("ledgerLine[\\(index)] 宽度非法。")
    }
}
```

### 修改后

- 新增 `.sequenceCursor` 分支
- 至少先保证 cursor 是合法竖线，且高度大于 0

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 类型/函数: validateStrokeSemantics(scene:fixture:record:)
// 功能说明: 修改后 validation 已能识别 sequenceCursor 这类新的 shared scene 语义。
switch stroke.semantic {
case .stem:
    if !approximatelyEqual(stroke.start.x, stroke.end.x) {
        record("stem[\\(index)] 不是竖线。")
    }
case .ledgerLine:
    if !approximatelyEqual(stroke.start.y, stroke.end.y) {
        record("ledgerLine[\\(index)] 不是横线。")
    }

    if !(stroke.end.x > stroke.start.x + tolerance) {
        record("ledgerLine[\\(index)] 宽度非法。")
    }
case .sequenceCursor:
    if !approximatelyEqual(stroke.start.x, stroke.end.x) {
        record("sequenceCursor[\\(index)] 不是竖线。")
    }

    if !(stroke.end.y > stroke.start.y + tolerance) {
        record("sequenceCursor[\\(index)] 高度非法。")
    }
}
```

## 本阶段结果

- shared scene 渲染链已经能表达 `sequenceCursor` 和最近一次判题的红绿颜色
- `notehead / accidental / stem / ledger line` 已经收敛为同一 note 级别反馈色，不再需要平台层分别着色
- 当前 note 的竖线游标也已经是 `StaffScene` 的一部分，而不是额外 overlay
- 本阶段仍未修改 iOS/macOS controller，因此界面暂时不会实际出现这些效果；等阶段 3 把 `currentIndex + lastEvaluation` 投影进 `sequencePresentation` 后，渲染结果就会生效

## 验证情况

- 已对下列文件执行静态诊断检查，结果无 linter 错误：
- `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- 未执行 `xcodebuild` 全量编译；当前记录仅覆盖本次 shared scene 渲染链改动与静态检查结果

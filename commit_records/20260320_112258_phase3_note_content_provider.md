20260320_112258_phase3_note_content_provider

# 阶段 3 修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift`
- 新增 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`
- 未修改 `FretboardLayer.swift`
- 未修改 `iOSFretboardView.swift`
- 未修改 `macOSFretboardView.swift`
- 未修改 `iOSViewController.swift`
- 未修改 `macOSViewController.swift`

## 修改前

### provider 协议文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift
// 函数名：无（文件不存在）
// 功能说明：修改前共享层没有统一的内容 provider 协议，缺少“给定当前 configuration 和 geometry，生成一组可绘制文本标签”的抽象层。
// 该文件在修改前不存在。
```

### 音名 provider 文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数名：无（文件不存在）
// 功能说明：修改前共享层没有专门负责音名内容推导的 provider，音高模型和调弦模型虽然已经存在，但还没有把它们转成每根弦每一品的文本标签。
// 该文件在修改前不存在。
```

### 共享层在“内容生成”上的现状

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard
// 函数名：无
// 功能说明：修改前共享层只完成了音高、调弦、几何与静态渲染，但没有内容生成层。
InstrumentType.swift
NotePitch.swift
InstrumentTuning.swift
FretboardConfiguration.swift
FretboardGeometry.swift
FretboardLayer.swift
```

## 修改后

### 新增 provider 基础协议与标签内容结构

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift
// 函数名：allows(_:), makeLabels(configuration:geometry:)
// 功能说明：新增内容 provider 抽象层，统一描述文本标签内容，以及“显示自然音 / 显示变化音”的组合策略。
import CoreGraphics

// 仅控制音名文本的可见性，不影响指板 marker 的绘制。
struct NoteLabelVisibility: Equatable, Hashable, Sendable {
    var showsNaturalNotes: Bool
    var showsAccidentals: Bool

    static let all = NoteLabelVisibility(
        showsNaturalNotes: true,
        showsAccidentals: true
    )

    static let naturalOnly = NoteLabelVisibility(
        showsNaturalNotes: true,
        showsAccidentals: false
    )

    static let accidentalOnly = NoteLabelVisibility(
        showsNaturalNotes: false,
        showsAccidentals: true
    )

    static let none = NoteLabelVisibility(
        showsNaturalNotes: false,
        showsAccidentals: false
    )

    func allows(_ pitchClass: PitchClass) -> Bool {
        pitchClass.isAccidental ? showsAccidentals : showsNaturalNotes
    }
}

struct FretboardLabelContent: Equatable, Sendable {
    var stringIndex: Int
    var fret: Int
    var text: String
    var center: CGPoint
    var maxSize: CGSize
    var fontSize: CGFloat
}

protocol FretboardContentProviding: Sendable {
    func makeLabels(
        configuration: FretboardConfiguration,
        geometry: FretboardGeometry
    ) -> [FretboardLabelContent]
}
```

### 新增音名内容 provider

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数名：init(visibility:spelling:showsOctave:layoutMetrics:), makeLabels(configuration:geometry:)
// 功能说明：新增音名 provider，根据 tuning、fretRange 和 geometry 生成每根弦每一品的音名标签。
import CoreGraphics

struct NoteNameContentProvider: FretboardContentProviding, Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var verticalOffsetRatio: CGFloat
        var maxLabelWidthRatio: CGFloat
        var maxLabelHeightRatio: CGFloat
        var fontScale: CGFloat

        static let `default` = LayoutMetrics(
            verticalOffsetRatio: 0.28,
            maxLabelWidthRatio: 0.88,
            maxLabelHeightRatio: 0.9,
            fontScale: 0.46
        )
    }

    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool
    var layoutMetrics: LayoutMetrics
}
```

### 基于 tuning 和 geometry 生成标签

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数名：makeLabels(configuration:geometry:)
// 功能说明：对每根弦和每个 fret 循环，根据空弦音高按半音递进，过滤自然音/变化音可见性，并生成文本标签内容。
func makeLabels(
    configuration: FretboardConfiguration,
    geometry: FretboardGeometry
) -> [FretboardLabelContent] {
    var labels: [FretboardLabelContent] = []

    for stringIndex in 0..<configuration.stringCount {
        guard
            let openPitch = configuration.tuning.openStringPitch(for: stringIndex),
            let stringY = geometry.yPositionForString(stringIndex)
        else {
            continue
        }

        for fret in configuration.fretRange {
            let pitch = openPitch.advanced(by: fret)
            guard visibility.allows(pitch.pitchClass) else {
                continue
            }

            let slotRect = geometry.displaySlotRect(at: fret)
            guard !slotRect.isNull else {
                continue
            }

            labels.append(
                makeLabelContent(
                    pitch: pitch,
                    stringIndex: stringIndex,
                    fret: fret,
                    stringY: stringY,
                    slotRect: slotRect,
                    geometry: geometry
                )
            )
        }
    }

    return labels
}
```

### 标签布局参数与单条标签内容组装

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数名：makeLabelContent(pitch:stringIndex:fret:stringY:slotRect:geometry:), resolvedMaxLabelHeight(slotRect:geometry:), verticalOffsetReference(slotRect:geometry:)
// 功能说明：统一计算标签的中心点、最大尺寸和字体大小，避免将文字布局逻辑散落到未来的渲染层中。
private func makeLabelContent(
    pitch: NotePitch,
    stringIndex: Int,
    fret: Int,
    stringY: CGFloat,
    slotRect: CGRect,
    geometry: FretboardGeometry
) -> FretboardLabelContent {
    let maxLabelHeight = resolvedMaxLabelHeight(slotRect: slotRect, geometry: geometry)
    let proposedCenterY = stringY - (verticalOffsetReference(slotRect: slotRect, geometry: geometry) * layoutMetrics.verticalOffsetRatio)
    let minCenterY = slotRect.minY + (maxLabelHeight / 2)
    let maxCenterY = slotRect.maxY - (maxLabelHeight / 2)
    let clampedCenterY = min(max(proposedCenterY, minCenterY), maxCenterY)
    let maxLabelWidth = max(slotRect.width * layoutMetrics.maxLabelWidthRatio, 0)
    let fontSize = min(
        slotRect.width * layoutMetrics.fontScale,
        maxLabelHeight * 0.9
    )

    return FretboardLabelContent(
        stringIndex: stringIndex,
        fret: fret,
        text: pitch.displayText(using: spelling, showsOctave: showsOctave),
        center: CGPoint(x: slotRect.midX, y: clampedCenterY),
        maxSize: CGSize(width: maxLabelWidth, height: maxLabelHeight),
        fontSize: fontSize
    )
}
```

## 结果说明

- 阶段 3 的核心结果是把“音名该显示什么、显示在哪里”从渲染层里提前抽象成独立的 provider 层。
- `NoteLabelVisibility` 现在已经能表达“显示自然音 / 显示变化音”的组合，并且明确不影响 marker。
- `NoteNameContentProvider` 已经能基于 `configuration.tuning` 和 `geometry` 生成每根弦每一品的文本标签内容。
- 本次还没有修改 `FretboardLayer`，所以音名还没有真正被绘制到指板上；下一阶段才会把 provider 接进共享渲染层。

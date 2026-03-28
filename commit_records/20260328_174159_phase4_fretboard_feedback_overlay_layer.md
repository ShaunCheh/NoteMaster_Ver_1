# 20260328_174159_phase4_fretboard_feedback_overlay_layer

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_174159`
- 记录范围：实施 `single覆盖反馈` 计划的阶段 4，只补独立的指板反馈 overlay 通道，不涉及控制器接线、prompt 投影触发逻辑、实际运行时状态喂入
- 本次目标：为后续 single coverage 的红/绿点击反馈准备共享状态模型、独立绘制 layer 和 `FretboardLayer` 层级接线
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardScene.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardPalette.swift`

## 根因结论

- 阶段 1 到阶段 3 已经分别补齐了目标位置枚举、single coverage session 和 prompt 进度内容，但指板绘制链路仍然只有 `boardLayer + labelsLayer` 两层。
- 如果直接把红/绿反馈塞进 `FretboardLabelsLayer`，基础音名 badge 的职责会被训练状态污染，后续也难以独立扩展动画或错误反馈策略。
- 同时，现有 shared 指板几何已经有 `cellFrames` 和 `contextNormalizationMode`，说明更合适的方案是追加一层独立 overlay，而不是改写底板或 label provider 逻辑。
- 因此阶段 4 的根因级修复是在 shared 绘制层中正式引入 `feedbackOverlayState + feedbackLayer`，并插入 `boardLayer -> feedbackLayer -> labelsLayer` 的层级。

## 修改 1：新增 `FretboardFeedbackOverlayState.swift`，承载红/绿反馈的共享状态

### 修改前

- shared 指板模块里没有专门表达“正确 cell 集合 + 最近一次错误 cell”的值类型
- `FretboardLayer` 只能同步 configuration、scene、contentProvider 和 contextNormalizationMode
- 没有统一的 overlay 真相源供后续控制器投影使用

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名: FretboardLayer.configuration, FretboardLayer.contentProvider, FretboardLayer.contextNormalizationMode
// 功能说明: 修改前 FretboardLayer 只同步底板、标签和坐标归一化相关状态；
// 还没有任何 feedback overlay 的共享状态入口。
final class FretboardLayer: CALayer {
    var configuration: FretboardConfiguration = .init() { ... }
    var contentProvider: (any FretboardContentProviding)? { ... }
    var contextNormalizationMode: FretboardContextNormalizationMode = .none { ... }
}
```

### 修改后

- 新增 `FretboardFeedbackOverlayState`
- 它明确表达：
- `correctCells: Set<FretboardCell>`
- `wrongCell: FretboardCell?`
- `isEmpty`
- `empty`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift
// 函数名: FretboardFeedbackOverlayState.init(...), FretboardFeedbackOverlayState.isEmpty
// 功能说明: 修改后 shared 层有了独立的 feedback overlay 真相源；
// 正确命中使用 correctCells，错误命中使用 wrongCell，便于控制器后续直接投影。
struct FretboardFeedbackOverlayState: Equatable, Sendable {
    var correctCells: Set<FretboardCell>
    var wrongCell: FretboardCell?

    static let empty = FretboardFeedbackOverlayState()

    init(
        correctCells: Set<FretboardCell> = [],
        wrongCell: FretboardCell? = nil
    ) {
        self.correctCells = correctCells
        self.wrongCell = wrongCell
    }

    var isEmpty: Bool {
        correctCells.isEmpty && wrongCell == nil
    }
}
```

## 修改 2：在 `FretboardScene.swift` 和 `FretboardPalette.swift` 中补齐 overlay 绘制支撑

### 修改前

- `FretboardScene` 只能通过 `(stringIndex, fret)` 单独查 `cellFrame`
- `FretboardPalette` 只有底板、品丝、音名 badge 的颜色
- feedback layer 若要按 `FretboardCell` 绘制，需要先补几何和颜色语义

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardScene.swift
// 函数名: FretboardScene.cellFrame(stringIndex:fret:)
// 功能说明: 修改前 scene 只能通过 stringIndex + fret 取单个 cell frame；
// 还没有直接按 FretboardCell 的便捷查询入口。
func cellFrame(stringIndex: Int, fret: Int) -> CGRect? {
    cellFrames.first {
        $0.stringIndex == stringIndex && $0.fret == fret
    }?.frame
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardPalette.swift
// 函数名: FretboardPalette.noteBadgeFill, noteBadgeStroke, noteBadgeText
// 功能说明: 修改前 palette 只有底板和标签绘制颜色；
// 没有“正确绿色 / 错误红色”的 overlay 语义色。
enum FretboardPalette {
    static let noteBadgeFill = makeColor(0.98, 0.97, 0.94, 0.98)
    static let noteBadgeStroke = makeColor(0.23, 0.18, 0.14, 0.36)
    static let noteBadgeText = makeColor(0.16, 0.12, 0.09)
}
```

### 修改后

- `FretboardScene` 新增 `cellFrame(for cell: FretboardCell)`
- `FretboardPalette` 新增：
- `feedbackCorrectFill`
- `feedbackCorrectStroke`
- `feedbackWrongFill`
- `feedbackWrongStroke`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardScene.swift
// 函数名: FretboardScene.cellFrame(for:)
// 功能说明: 修改后 feedback layer 可以直接按 FretboardCell 查询几何 frame，
// 不再需要自己拆 stringIndex/fret。
func cellFrame(for cell: FretboardCell) -> CGRect? {
    cellFrame(
        stringIndex: cell.stringIndex,
        fret: cell.fret
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardPalette.swift
// 函数名: FretboardPalette.feedbackCorrectFill / feedbackCorrectStroke / feedbackWrongFill / feedbackWrongStroke
// 功能说明: 修改后 overlay 绘制有了独立的正确/错误语义色，
// 且使用半透明 fill + 较深 stroke，避免完全遮挡底板和标签。
enum FretboardPalette {
    static let feedbackCorrectFill = makeColor(0.18, 0.70, 0.36, 0.28)
    static let feedbackCorrectStroke = makeColor(0.12, 0.58, 0.28, 0.82)
    static let feedbackWrongFill = makeColor(0.86, 0.24, 0.24, 0.26)
    static let feedbackWrongStroke = makeColor(0.78, 0.14, 0.14, 0.84)
}
```

## 修改 3：新增 `FretboardFeedbackLayer.swift`，独立绘制正确/错误反馈

### 修改前

- 指板绘制层只有 `FretboardBoardLayer` 和 `FretboardLabelsLayer`
- 没有任何专门的 feedback layer
- label 层只负责画 badge 和文字，不包含红/绿训练反馈

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLabelsLayer.swift
// 函数名: FretboardLabelsLayer.draw(in:), drawLabelBadge(for:in:)
// 功能说明: 修改前 labels layer 只负责音名标签渲染；
// 它不理解训练反馈状态，也不画正确/错误高亮。
override func draw(in context: CGContext) {
    context.clear(bounds)
    guard
        !scene.drawingRect.isNull,
        let contentProvider
    else {
        return
    }

    applyContextNormalizationIfNeeded(in: context)
    let labels = contentProvider.makeLabels(
        configuration: configuration,
        scene: scene
    )
    guard !labels.isEmpty else {
        return
    }

    for label in labels {
        guard let resolvedText = resolvedTextLine(for: label) else {
            continue
        }

        drawLabelBadge(for: label, in: context)
        drawTextLine(
            resolvedText.line,
            bounds: resolvedText.bounds,
            centeredAt: label.center,
            in: context
        )
    }
}
```

### 修改后

- 新增 `FretboardFeedbackLayer`
- 它维护：
- `scene`
- `contextNormalizationMode`
- `feedbackOverlayState`
- 绘制策略是：
- 先按 `correctCells` 画绿色半透明 rounded rect
- 再按 `wrongCell` 画红色半透明 rounded rect
- 并复用 `displayPath()` 对外轮廓进行裁剪，避免越出指板

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift
// 函数名: draw(in:), drawFeedback(for:fillColor:strokeColor:in:), displayPath()
// 功能说明: 修改后新增独立 feedback layer；
// 它只消费 overlay state 和 scene，专门负责在正确/错误 cell 上绘制高亮反馈。
final class FretboardFeedbackLayer: CALayer {
    var scene: FretboardScene = .empty { ... }
    var contextNormalizationMode: FretboardContextNormalizationMode = .none { ... }
    var feedbackOverlayState: FretboardFeedbackOverlayState = .empty { ... }

    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard
            !scene.drawingRect.isNull,
            !feedbackOverlayState.isEmpty
        else {
            return
        }

        applyContextNormalizationIfNeeded(in: context)

        context.saveGState()
        context.addPath(displayPath())
        context.clip()

        let orderedCorrectCells = feedbackOverlayState.correctCells.sorted { ... }
        for cell in orderedCorrectCells {
            drawFeedback(
                for: cell,
                fillColor: FretboardPalette.feedbackCorrectFill,
                strokeColor: FretboardPalette.feedbackCorrectStroke,
                in: context
            )
        }

        if let wrongCell = feedbackOverlayState.wrongCell {
            drawFeedback(
                for: wrongCell,
                fillColor: FretboardPalette.feedbackWrongFill,
                strokeColor: FretboardPalette.feedbackWrongStroke,
                in: context
            )
        }

        context.restoreGState()
    }
}
```

## 修改 4：在 `FretboardLayer.swift` 中接入 `feedbackLayer`

### 修改前

- `FretboardLayer` 只有 `boardLayer` 和 `labelsLayer`
- `configureLayer()` 只添加两层
- `synchronizeSublayerState()` 只同步底板和标签，不同步 feedback overlay

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名: configureLayer(), synchronizeSublayerState(), invalidateSublayerDisplay()
// 功能说明: 修改前 FretboardLayer 只维护 boardLayer 和 labelsLayer，
// 没有插入 feedback overlay，也没有 feedbackOverlayState 入口。
private let boardLayer = FretboardBoardLayer()
private let labelsLayer = FretboardLabelsLayer()

private func configureLayer() {
    isOpaque = false
    drawsAsynchronously = false
    addSublayer(boardLayer)
    addSublayer(labelsLayer)
}

private func synchronizeSublayerState() {
    let scene = FretboardSceneBuilder(
        configuration: configuration
    ).makeScene(bounds: bounds)

    performWithoutImplicitAnimations {
        boardLayer.frame = bounds
        labelsLayer.frame = bounds
        boardLayer.scene = scene
        labelsLayer.scene = scene
        boardLayer.contextNormalizationMode = contextNormalizationMode
        labelsLayer.contextNormalizationMode = contextNormalizationMode
        labelsLayer.contentProvider = contentProvider
    }
}
```

### 修改后

- 新增 `feedbackOverlayState`
- 新增 `feedbackLayer`
- 层级变为 `boardLayer -> feedbackLayer -> labelsLayer`
- `synchronizeSublayerState()` 同步 frame、scene、`contentsScale`、`contextNormalizationMode` 和 overlay state
- `invalidateSublayerDisplay()` / `displayIfNeeded()` 也把 `feedbackLayer` 纳入

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 函数名: feedbackOverlayState, configureLayer(), synchronizeSublayerState(), synchronizeFeedbackOverlayState()
// 功能说明: 修改后 FretboardLayer 把 feedback overlay 正式插入指板层级；
// 后续控制器只需要写入 feedbackOverlayState，就能驱动红/绿绘制。
var feedbackOverlayState: FretboardFeedbackOverlayState = .empty {
    didSet {
        guard oldValue != feedbackOverlayState else {
            return
        }

        synchronizeFeedbackOverlayState()
        feedbackLayer.setNeedsDisplay()
    }
}

private let boardLayer = FretboardBoardLayer()
private let feedbackLayer = FretboardFeedbackLayer()
private let labelsLayer = FretboardLabelsLayer()

private func configureLayer() {
    isOpaque = false
    drawsAsynchronously = false
    addSublayer(boardLayer)
    addSublayer(feedbackLayer)
    addSublayer(labelsLayer)
}

private func synchronizeSublayerState() {
    let scene = FretboardSceneBuilder(
        configuration: configuration
    ).makeScene(bounds: bounds)

    performWithoutImplicitAnimations {
        boardLayer.frame = bounds
        feedbackLayer.frame = bounds
        labelsLayer.frame = bounds
        boardLayer.scene = scene
        feedbackLayer.scene = scene
        labelsLayer.scene = scene
        boardLayer.contentsScale = contentsScale
        feedbackLayer.contentsScale = contentsScale
        labelsLayer.contentsScale = contentsScale
        boardLayer.contextNormalizationMode = contextNormalizationMode
        feedbackLayer.contextNormalizationMode = contextNormalizationMode
        labelsLayer.contextNormalizationMode = contextNormalizationMode
        labelsLayer.contentProvider = contentProvider
        feedbackLayer.feedbackOverlayState = feedbackOverlayState
    }
}

private func synchronizeFeedbackOverlayState() {
    performWithoutImplicitAnimations {
        feedbackLayer.feedbackOverlayState = feedbackOverlayState
    }
}
```

## 影响范围与未改内容

- 本次只补了 overlay 通道本身，还没有把任何运行时状态喂给 `feedbackOverlayState`。
- `iOSViewController.swift` / `macOSViewController.swift` 还没有开始把 `SingleCoverageEvaluation` 投影成绿色 `correctCells` 或红色 `wrongCell`。
- `iOSFretboardView.swift` / `macOSFretboardView.swift` 还没有暴露 overlay state 写入接口，因为目前阶段 4 只到 shared 层。
- prompt 进度和 overlay 之间还没有联动，这部分要等控制器阶段统一接线。

## 验证情况

- 已执行 `ReadLints` 检查，`FretboardFeedbackOverlayState.swift`、`FretboardFeedbackLayer.swift`、`FretboardLayer.swift`、`FretboardScene.swift`、`FretboardPalette.swift` 没有新增 linter 问题。
- 已通过 `git diff` 核对本次实际改动，确认只涉及上述五个 shared 文件。
- 本次没有执行工程级编译或运行时渲染验证；当前阶段的确认主要依赖代码回读和静态检查。

## 阶段结论

- 阶段 4 已完成：shared 绘制层已经具备独立的红/绿 feedback overlay 通道。
- 后续阶段 5 只要把控制器里的 single coverage 状态投影到 `feedbackOverlayState`，红/绿点击反馈就能真正出现在指板上。

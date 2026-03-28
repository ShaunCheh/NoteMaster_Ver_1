# 20260328_234051_phase3_position_prompt_feedback_overlay_rendering

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_234051`
- 记录范围：实施“位置音名模式”计划的阶段 3，只补 shared 指板 feedback overlay 的状态模型、颜色语义和绘制分流，并修补 iOS/macOS 控制器对旧 single coverage overlay 的兼容投影；不涉及页面布局切换、按钮答题接线、错误红闪时序调度和 1 秒后自动推进
- 本次目标：让 shared 层先能稳定表达并绘制两套 overlay 语义
- `singleCoverage`：延续原有“正确绿色覆盖 + 错误红色覆盖”
- `positionPrompt`：新增“白圈待答 / 红闪错误 / 绿停留正确”三相位
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardPalette.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 阶段 2 已经把 `positionPrompt` 的 shared trainer 状态机补齐，但指板 overlay 仍然只有 single coverage 时代留下来的扁平状态：`correctCells + wrongCell`
- 这种状态结构只能描述“多个格子被覆盖为绿 / 一个格子被覆盖为红”，无法描述位置题的“当前只有一个 promptCell，但它会在白、红、绿三种反馈相位之间切换”
- 如果继续把白圈/红闪/绿停留塞进控制器临时状态，而不升级 shared overlay 真相，后续双端 controller、layer 和定时器都会围绕平台分支重复拼装
- 因此阶段 3 的根因级修复，是先在 shared feedback overlay 层引入按模式分流的状态模型，再让绘制层按模式分别渲染矩形覆盖与圆形 prompt 指示器

## 修改 1：把 `FretboardFeedbackOverlayState` 从扁平 struct 升级为按模式分流的 enum

### 修改前

- overlay 状态是一个扁平 `struct`
- 只能表达 single coverage 的“正确集合 + 错误单点”
- 无法承载位置题的 `promptCell + phase`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift
// 函数名/符号: FretboardFeedbackOverlayState.init(...), FretboardFeedbackOverlayState.isEmpty
// 功能说明: 修改前 overlay 真相源只面向 single coverage；
// 无法表达“同一个 promptCell 在白圈 / 红闪 / 绿停留之间切换”的位置题语义。
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

### 修改后

- 状态模型升级为 `enum`
- 保留 `singleCoverage` 的旧语义
- 新增 `positionPrompt(promptCell:phase:)`
- 新增 `PositionPromptPhase`，把位置题的白/红/绿相位收敛到 shared 层

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift
// 函数名/符号: FretboardFeedbackOverlayState.PositionPromptPhase,
// FretboardFeedbackOverlayState.isEmpty
// 功能说明: 修改后 overlay 真相源已经能同时承载 single coverage 和 position prompt；
// 后续控制器只需要投影 promptCell + phase，不必再自己拼装绘制语义。
enum FretboardFeedbackOverlayState: Equatable, Sendable {
    enum PositionPromptPhase: Equatable, Sendable {
        case neutralWhite
        case wrongFlash
        case correctHold
    }

    case empty
    case singleCoverage(
        correctCells: Set<FretboardCell>,
        wrongCell: FretboardCell?
    )
    case positionPrompt(
        promptCell: FretboardCell,
        phase: PositionPromptPhase
    )

    var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case let .singleCoverage(correctCells, wrongCell):
            return correctCells.isEmpty && wrongCell == nil
        case .positionPrompt:
            return false
        }
    }
}
```

## 修改 2：让 `FretboardFeedbackLayer` 按 overlay 模式分流绘制

### 修改前

- `draw(in:)` 直接读取 `feedbackOverlayState.correctCells` 和 `feedbackOverlayState.wrongCell`
- 绘制能力只覆盖 single coverage 的矩形高亮
- 没有 position prompt 的圆形指示器，也没有白/红/绿相位分流

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift
// 函数名: FretboardFeedbackLayer.draw(in:), drawFeedback(for:fillColor:strokeColor:in:)
// 功能说明: 修改前 feedback layer 固定按“绿块集合 + 红块单点”绘制；
// 没有办法根据训练模式切到圆形 prompt indicator。
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

    let orderedCorrectCells = feedbackOverlayState.correctCells.sorted {
        if $0.stringIndex == $1.stringIndex {
            return $0.fret < $1.fret
        }
        return $0.stringIndex < $1.stringIndex
    }
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
```

### 修改后

- `draw(in:)` 改为按 `feedbackOverlayState` 分流
- `singleCoverage` 继续走旧的矩形覆盖
- `positionPrompt` 新增圆形 prompt indicator
- 新增 `drawSingleCoverageFeedback(...)`
- 新增 `drawPositionPromptIndicator(...)`
- 新增 `positionPromptRect(...)`
- 新增 `colors(for:)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift
// 函数名: draw(in:), drawSingleCoverageFeedback(correctCells:wrongCell:in:),
// drawPositionPromptIndicator(for:phase:in:), positionPromptRect(for:), colors(for:)
// 功能说明: 修改后 feedback layer 会根据 overlay mode 自动切换绘制语义；
// single coverage 仍画矩形覆盖，position prompt 改为画白/红/绿三相位圆圈。
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

    switch feedbackOverlayState {
    case .empty:
        break
    case let .singleCoverage(correctCells, wrongCell):
        drawSingleCoverageFeedback(
            correctCells: correctCells,
            wrongCell: wrongCell,
            in: context
        )
    case let .positionPrompt(promptCell, phase):
        drawPositionPromptIndicator(
            for: promptCell,
            phase: phase,
            in: context
        )
    }

    context.restoreGState()
}

private func drawSingleCoverageFeedback(
    correctCells: Set<FretboardCell>,
    wrongCell: FretboardCell?,
    in context: CGContext
) {
    let orderedCorrectCells = correctCells.sorted {
        if $0.stringIndex == $1.stringIndex {
            return $0.fret < $1.fret
        }
        return $0.stringIndex < $1.stringIndex
    }
    for cell in orderedCorrectCells {
        drawFeedback(
            for: cell,
            fillColor: FretboardPalette.feedbackCorrectFill,
            strokeColor: FretboardPalette.feedbackCorrectStroke,
            in: context
        )
    }

    if let wrongCell {
        drawFeedback(
            for: wrongCell,
            fillColor: FretboardPalette.feedbackWrongFill,
            strokeColor: FretboardPalette.feedbackWrongStroke,
            in: context
        )
    }
}

private func drawPositionPromptIndicator(
    for cell: FretboardCell,
    phase: FretboardFeedbackOverlayState.PositionPromptPhase,
    in context: CGContext
) {
    guard
        let cellFrame = scene.cellFrame(for: cell),
        !cellFrame.isNull,
        !cellFrame.isEmpty
    else {
        return
    }

    let indicatorRect = positionPromptRect(for: cellFrame)
    guard !indicatorRect.isEmpty else {
        return
    }

    let indicatorPath = CGPath(
        ellipseIn: indicatorRect,
        transform: nil
    )
    let colors = colors(for: phase)

    context.saveGState()
    context.addPath(indicatorPath)
    context.setFillColor(colors.fillColor)
    context.fillPath()
    context.addPath(indicatorPath)
    context.setStrokeColor(colors.strokeColor)
    context.setLineWidth(resolvedPositionPromptStrokeWidth)
    context.strokePath()
    context.restoreGState()
}

private func colors(
    for phase: FretboardFeedbackOverlayState.PositionPromptPhase
) -> (fillColor: CGColor, strokeColor: CGColor) {
    switch phase {
    case .neutralWhite:
        return (
            fillColor: FretboardPalette.positionPromptNeutralFill,
            strokeColor: FretboardPalette.positionPromptNeutralStroke
        )
    case .wrongFlash:
        return (
            fillColor: FretboardPalette.positionPromptWrongFill,
            strokeColor: FretboardPalette.positionPromptWrongStroke
        )
    case .correctHold:
        return (
            fillColor: FretboardPalette.positionPromptCorrectFill,
            strokeColor: FretboardPalette.positionPromptCorrectStroke
        )
    }
}
```

## 修改 3：在 `FretboardPalette` 中补齐 position prompt 的专用颜色语义

### 修改前

- palette 里只有 single coverage 时代的红绿覆盖色
- 没有白圈待答、红闪错误、绿停留正确这组位置题专用语义色

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardPalette.swift
// 函数名/符号: FretboardPalette.feedbackCorrectFill / feedbackCorrectStroke /
// feedbackWrongFill / feedbackWrongStroke
// 功能说明: 修改前 palette 只定义了 single coverage 的红绿矩形覆盖颜色；
// position prompt 还没有自己的白圈 / 红闪 / 绿停留色板。
enum FretboardPalette {
    static let feedbackCorrectFill = makeColor(0.18, 0.70, 0.36, 0.28)
    static let feedbackCorrectStroke = makeColor(0.12, 0.58, 0.28, 0.82)
    static let feedbackWrongFill = makeColor(0.86, 0.24, 0.24, 0.26)
    static let feedbackWrongStroke = makeColor(0.78, 0.14, 0.14, 0.84)
}
```

### 修改后

- 继续保留 single coverage 的红绿块颜色
- 额外补充 position prompt 的白圈/红闪/绿停留颜色
- 让圆形 prompt indicator 和旧矩形覆盖层共用一套集中式 palette

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardPalette.swift
// 函数名/符号: FretboardPalette.positionPromptNeutralFill / positionPromptNeutralStroke /
// positionPromptCorrectFill / positionPromptCorrectStroke /
// positionPromptWrongFill / positionPromptWrongStroke
// 功能说明: 修改后 palette 已经能给 position prompt 提供独立的圆圈颜色语义，
// 避免把白圈逻辑硬套到旧的 single coverage 红绿块颜色上。
enum FretboardPalette {
    static let feedbackCorrectFill = makeColor(0.18, 0.70, 0.36, 0.28)
    static let feedbackCorrectStroke = makeColor(0.12, 0.58, 0.28, 0.82)
    static let feedbackWrongFill = makeColor(0.86, 0.24, 0.24, 0.26)
    static let feedbackWrongStroke = makeColor(0.78, 0.14, 0.14, 0.84)
    static let positionPromptNeutralFill = makeColor(0.99, 0.99, 0.98, 0.94)
    static let positionPromptNeutralStroke = makeColor(0.22, 0.18, 0.14, 0.60)
    static let positionPromptCorrectFill = makeColor(0.18, 0.70, 0.36, 0.34)
    static let positionPromptCorrectStroke = makeColor(0.12, 0.58, 0.28, 0.92)
    static let positionPromptWrongFill = makeColor(0.86, 0.24, 0.24, 0.32)
    static let positionPromptWrongStroke = makeColor(0.78, 0.14, 0.14, 0.92)
}
```

## 修改 4：修补 iOS/macOS 控制器对新 overlay enum 的兼容投影

### 修改前

- `currentFretboardFeedbackOverlayState` 仍按旧的 struct 初始化方式返回
- 在 `FretboardFeedbackOverlayState` 升级为 enum 后，这种调用方式将不再成立

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: currentFretboardFeedbackOverlayState
// 功能说明: 修改前 iOS/macOS 控制器仍然假定 overlay 是扁平 struct，
// 返回值使用旧式 init(correctCells:wrongCell:) 组装。
return FretboardFeedbackOverlayState(
    correctCells: singleCoverageSession.visitedCells,
    wrongCell: wrongCell
)
```

### 修改后

- iOS/macOS 控制器都改成显式返回 `.singleCoverage(...)`
- 这样阶段 3 改完 shared overlay 之后，旧 single coverage 逻辑仍能原样工作
- 位置题的 `.positionPrompt(...)` 投影入口则留给下一阶段 controller 接线

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: currentFretboardFeedbackOverlayState
// 功能说明: 修改后 iOS/macOS 控制器已显式声明当前返回的是 single coverage overlay；
// 既兼容新的 enum 模型，也为后续 position prompt 投影分支预留出口。
return .singleCoverage(
    correctCells: singleCoverageSession.visitedCells,
    wrongCell: wrongCell
)
```

## 结果说明

- shared overlay 真相源已经具备双语义承载能力：`singleCoverage` 与 `positionPrompt`
- shared feedback layer 已能绘制 position prompt 的圆形白圈/红闪/绿停留
- iOS/macOS 现有 single coverage 指板反馈投影已兼容新的 overlay enum
- 本阶段仍未接入：
- `positionPrompt` 在 controller 中的实际投影
- 错误作答后的短暂红闪恢复白圈
- 正确作答后的 1 秒停留与自动下一题
- 顶部指板 / 底部自然音按钮布局切换

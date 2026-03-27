# 20260327_162322_phase1_staff_sequence_shared_state

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_162322`
- 记录范围：实施 `staff序列反馈` 计划的阶段 1，只补 shared staff sequence 展示状态与 provider 接线，不涉及双端 view，也不涉及实际游标/红绿绘制
- 本次目标：先把 `cursorIndex`、`lastEvaluatedIndex`、`lastEvaluationResult` 以及 `idle / wrong / correct / completed` 四种 staff sequence 展示语义放进 shared 真相源，再让 `StaffDisplayState -> StaffSceneProvider` 可以统一承载这份状态
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`

## 根因结论

- 当前序列训练的“当前进度”和“最近一次判题结果”只存在于 trainer / controller 侧，staff 共享模块还没有一个正式的 sequence 展示语义承载点。
- 在这一步之前，`StaffDisplayState` 和 `StaffSceneProvider` 只能表达静态记谱输入，不能表达“当前题是谁、上一次作答是对还是错、游标是否应该显示”。
- 因此阶段 1 的根因级修复不是直接去画竖线，而是先把 sequence 展示状态标准化为 shared 值类型，再把它纳入 `StaffDisplayState -> StaffSceneProvider` 的派生链路。

## 修改 1：在 `StaffScene.swift` 中引入共享的 sequence 展示语义

### 修改前

- `StaffScene.swift` 里只有 staff 图元颜色、glyph/stroke 等基础语义
- 还没有专门表达 sequence 游标与最近一次判题结果的共享值类型

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 类型/函数: StaffSceneColor, StaffGlyphBoundsOverlayStyle
// 功能说明: 修改前 shared staff 模块只定义了颜色和图元样式；
// 还没有 sequence 当前游标、最近一次判题结果、完成态等展示语义。
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

struct StaffGlyphBoundsOverlayStyle: Equatable, Sendable {
    var strokeColor: StaffSceneColor
    var lineWidth: CGFloat
}
```

### 修改后

- 新增 `StaffSequenceEvaluationResult`
- 新增 `StaffSequencePresentation`
- 通过私有初始化器和若干静态构造函数，把合法的 sequence 展示状态固定下来，避免后续 controller 或 builder 各自发明状态组合

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 类型/函数: StaffSequencePresentation.init(...), idle(...), wrong(...), correct(...), completed(...)
// 功能说明: 修改后 sequence 展示语义被提升为 shared 值类型；
// 用统一入口约束 idle / wrong / correct / completed 的字段组合合法性。
enum StaffSequenceEvaluationResult: Equatable, Sendable {
    case correct
    case incorrect
}

struct StaffSequencePresentation: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case idle
        case wrong
        case correct
        case completed
    }

    var state: State
    var cursorIndex: Int?
    var lastEvaluatedIndex: Int?
    var lastEvaluationResult: StaffSequenceEvaluationResult?

    private init(
        state: State,
        cursorIndex: Int?,
        lastEvaluatedIndex: Int?,
        lastEvaluationResult: StaffSequenceEvaluationResult?
    ) {
        if let cursorIndex {
            precondition(
                cursorIndex >= 0,
                "Staff sequence cursor index must not be negative."
            )
        }
        if let lastEvaluatedIndex {
            precondition(
                lastEvaluatedIndex >= 0,
                "Staff sequence last evaluated index must not be negative."
            )
        }

        switch state {
        case .idle:
            precondition(cursorIndex != nil)
            precondition(lastEvaluatedIndex == nil && lastEvaluationResult == nil)
        case .wrong:
            precondition(cursorIndex != nil)
            precondition(lastEvaluatedIndex != nil)
            precondition(lastEvaluationResult == .incorrect)
        case .correct:
            precondition(cursorIndex != nil)
            precondition(lastEvaluatedIndex != nil)
            precondition(lastEvaluationResult == .correct)
        case .completed:
            precondition(cursorIndex == nil)
            precondition(
                (lastEvaluatedIndex == nil) == (lastEvaluationResult == nil)
            )
        }

        self.state = state
        self.cursorIndex = cursorIndex
        self.lastEvaluatedIndex = lastEvaluatedIndex
        self.lastEvaluationResult = lastEvaluationResult
    }

    static func idle(cursorIndex: Int) -> Self { ... }
    static func wrong(cursorIndex: Int, evaluatedIndex: Int) -> Self { ... }
    static func correct(cursorIndex: Int, evaluatedIndex: Int) -> Self { ... }
    static func completed(
        lastEvaluatedIndex: Int? = nil,
        lastEvaluationResult: StaffSequenceEvaluationResult? = nil
    ) -> Self { ... }
}
```

## 修改 2：让 `StaffSceneProvider` 正式接受 sequence 展示状态

### 修改前

- `StaffSceneProvider` 只接收 `clef`、`score`、`notationDisplayOptions`、`glyphTintColor`、`renderHint`
- sequence 相关语义还没有进入 provider 真相源

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 类型/函数: StaffSceneProvider.init(...), makeScene(geometry:)
// 功能说明: 修改前 provider 只能表达静态五线谱输入；
// 还无法携带 sequence 当前游标与最近一次判题反馈。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var score: StaffScore?
    var notationDisplayOptions: StaffNotationDisplayOptions
    var glyphTintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint

    init(
        clef: StaffClef = .treble,
        score: StaffScore? = nil,
        notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
        glyphTintColor: StaffSceneColor = .primaryInk,
        renderHint: StaffGlyphRenderHint = .staffClef()
    ) {
        self.clef = clef
        self.score = score
        self.notationDisplayOptions = notationDisplayOptions
        self.glyphTintColor = glyphTintColor
        self.renderHint = renderHint
    }
}
```

### 修改后

- `StaffSceneProvider` 新增 `sequencePresentation`
- 初始化器同步扩展这个参数
- 这一步先把 shared 状态通路搭起来，实际消费逻辑留给下一阶段的 `StaffSceneBuilder`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 类型/函数: StaffSceneProvider.init(...), makeScene(geometry:)
// 功能说明: 修改后 provider 成为 sequence 展示语义的共享入口；
// 阶段 2 再由 scene builder 把它转成游标和高亮图元。
struct StaffSceneProvider: Equatable, Sendable {
    var clef: StaffClef
    var score: StaffScore?
    var notationDisplayOptions: StaffNotationDisplayOptions
    var sequencePresentation: StaffSequencePresentation?
    var glyphTintColor: StaffSceneColor
    var renderHint: StaffGlyphRenderHint

    init(
        clef: StaffClef = .treble,
        score: StaffScore? = nil,
        notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
        sequencePresentation: StaffSequencePresentation? = nil,
        glyphTintColor: StaffSceneColor = .primaryInk,
        renderHint: StaffGlyphRenderHint = .staffClef()
    ) {
        self.clef = clef
        self.score = score
        self.notationDisplayOptions = notationDisplayOptions
        self.sequencePresentation = sequencePresentation
        self.glyphTintColor = glyphTintColor
        self.renderHint = renderHint
    }
}
```

## 修改 3：让 `StaffDisplayState` 可以持有并派生 sequence 展示状态

### 修改前

- `StaffDisplayState` 本身不持有 sequence 展示语义
- `sceneProvider` 只能从静态 score 派生
- `apply(generatedSequence:)` 也只能更新 `clef` 和 `score`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 类型/函数: StaffDisplayState.init(...), sceneProvider, apply(generatedSequence:)
// 功能说明: 修改前 StaffDisplayState 还没有承载 sequence 展示状态；
// controller 无法把当前游标和最近一次判题结果统一投影给 provider。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration
    var score: StaffScore?
    var notationDisplayOptions: StaffNotationDisplayOptions
    var showsComponentBoundsOverlay: Bool

    init(
        configuration: StaffConfiguration,
        score: StaffScore? = nil,
        notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
        showsComponentBoundsOverlay: Bool = false
    ) {
        self.configuration = configuration
        self.score = score
        self.notationDisplayOptions = notationDisplayOptions
        self.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    }

    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            score: resolvedScore,
            notationDisplayOptions: notationDisplayOptions,
            renderHint: .staffClef(...)
        )
    }
}

extension StaffDisplayState {
    mutating func apply(
        generatedSequence: GeneratedNoteSequence
    ) {
        configuration.clef = generatedSequence.clef
        score = generatedSequence.score
    }
}
```

### 修改后

- `StaffDisplayState` 新增 `sequencePresentation`
- `sceneProvider` 改为从 state 统一派生这份语义
- `apply(generatedSequence:)` 扩展为 `apply(generatedSequence:sequencePresentation:)`
- 新增 `clearSequencePresentation()`，为后续阶段的状态重置留出共享入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 类型/函数: StaffDisplayState.init(...), sceneProvider, apply(generatedSequence:sequencePresentation:), clearSequencePresentation()
// 功能说明: 修改后 StaffDisplayState 可以显式承载 sequence 展示状态；
// controller 后续只需要更新 shared state，即可统一派生 provider。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration
    var score: StaffScore?
    var notationDisplayOptions: StaffNotationDisplayOptions
    var sequencePresentation: StaffSequencePresentation?
    var showsComponentBoundsOverlay: Bool

    init(
        configuration: StaffConfiguration,
        score: StaffScore? = nil,
        notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
        sequencePresentation: StaffSequencePresentation? = nil,
        showsComponentBoundsOverlay: Bool = false
    ) {
        self.configuration = configuration
        self.score = score
        self.notationDisplayOptions = notationDisplayOptions
        self.sequencePresentation = sequencePresentation
        self.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    }

    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            score: resolvedScore,
            notationDisplayOptions: notationDisplayOptions,
            sequencePresentation: sequencePresentation,
            renderHint: .staffClef(...)
        )
    }
}

extension StaffDisplayState {
    mutating func apply(
        generatedSequence: GeneratedNoteSequence,
        sequencePresentation: StaffSequencePresentation? = nil
    ) {
        configuration.clef = generatedSequence.clef
        score = generatedSequence.score
        self.sequencePresentation = sequencePresentation
    }

    mutating func clearSequencePresentation() {
        sequencePresentation = nil
    }
}
```

## 本阶段结果

- shared staff 模块已经具备正式的 sequence 展示状态建模能力
- `StaffDisplayState -> StaffSceneProvider` 已经可以统一携带这份语义
- 现有旧调用方仍可继续工作，因为 `apply(generatedSequence:)` 通过默认参数保持兼容
- 本阶段尚未开始实际绘制竖线游标，也尚未在 `StaffSceneBuilder` 中消费 `sequencePresentation`

## 验证情况

- 已对下列文件执行静态诊断检查，结果无 linter 错误：
- `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 未执行 `xcodebuild` 全量编译；当前记录仅覆盖本次 shared 层改动与静态检查结果

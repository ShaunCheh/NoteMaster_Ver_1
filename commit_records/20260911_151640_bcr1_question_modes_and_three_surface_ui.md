# 20260911_151640_bcr1_question_modes_and_three_surface_ui

- 时间戳来源：系统自带命令 `date '+%Y%m%d_%H%M%S'`
- 时间戳结果：`20260911_151640`
- 记录范围：为 `Bass Clef Recognition-1` 增加“线上 / 间上 / 混合”三种出题子模式、通用自然音级序列生成策略、三层 Exercise Scene、双平台选择器、切换事务以及相关验证
- 记录依据：创建本记录前的 `git status --short`、`git diff --name-status`、`git diff --stat`、`git diff --numstat`、按文件检查的当前 Changes、4 个未跟踪 Swift 新文件及已经执行的双平台构建和 runtime smoke 输出
- 本记录不粘贴原始 `git diff`，而是按照当前实际代码归纳修改前后的数据合同、函数职责、界面结构和运行行为
- 创建记录前，`NoteMaster_Ver_1/` 下有 19 个已修改 Swift 文件，tracked source diff 为 `1628 insertions / 86 deletions`；另有 4 个未跟踪 Swift 新文件，未包含在该 diff 数字中
- 当前 `.cursor/plans/20260911_1446_bcr1-question-modes_cbf1c234.plan.md` 也处于 modified 状态；它不属于本记录归纳的 Swift 实现范围，本次记录步骤没有修改该计划文件
- 本 Markdown 是本次记录步骤唯一新增的文件；没有继续修改任何 Swift 源代码，也没有提交 Git commit

```bash
# 文件路径: /Users/shaun/cloudDev/NoteMaster_Ver_1
# 命令/函数名: 系统 date 命令
# 功能说明: 生成本记录文件名与一级标题使用的时间戳；以下为实际命令及输出。
date '+%Y%m%d_%H%M%S'

# 实际输出:
20260911_151640
```

## 1. 创建记录前的实际 Changes

### 1.1 新增文件

- `NoteMaster_Ver_1/Shared/Staff/StaffDiatonicPitchSequenceGenerator.swift`
  - 定义“起始音 + 固定音程编号 + 候选数量”的自然音级 progression
  - 将自然音级索引安全映射回 `StaffPitch`
- `NoteMaster_Ver_1/Shared/Controls/BCR1QuestionModeSelectorModel.swift`
  - 定义选择器 choice、model 和 event
  - 固定显示顺序为“线上 / 间上 / 混合”
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSBCR1QuestionModeSelectorView.swift`
  - 使用 `UISegmentedControl` 渲染 shared selector model
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSBCR1QuestionModeSelectorView.swift`
  - 使用 `NSSegmentedControl` 镜像实现相同的选择器合同

### 1.2 修改的产品代码

- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
  - 新增 BCR-1 子模式状态、默认值、生成策略和固定 8 个自然音的 resolved contract
- `NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift`
  - 在旧有“谱号音域内有放回随机”之外新增 progression 无放回抽样策略
- `NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift`
  - 暴露 clef-relative staff position，并统一判定线上/间上
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
  - 将 generation strategy 从 display state 贯穿至 quarter-note generator spec
- `NoteMaster_Ver_1/Shared/Scene/SceneCore.swift`
  - 新增 `questionModeSelector` surface ID/kind
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
  - 定义 BCR-1 selector auxiliary surface，并补齐三层 scene 的 viewport 约束语义
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
  - BCR-1 构建 `selector -> Staff -> Piano` 的三层垂直 scene
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
  - selector 获得可交互 auxiliary state；rendered layout 从固定一/二子节点改为 N-child 摘要
- `NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift`
  - 新增按 staff-space 计量的额外垂直留白配置
- `NoteMaster_Ver_1/Shared/Playback/PlaybackCoordinator.swift`
  - 新增 `.bcr1QuestionModeChanged` 停止播放原因
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
  - 接入 selector surface
  - 将 regenerate button 从整棵 scene 顶层迁移到实际 prompt surface host
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
  - 持有和刷新 selector
  - 处理子模式切换、停止播放、状态清理、重新生成及 BCR-1 runtime smoke
  - 仅在 BCR-1 应用额外 Staff 垂直留白，离开模式时恢复基线

### 1.3 修改的验证代码

- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`

这些验证分别锁定 Settings 固定合同、三层 Scene、N-child rendered layout、三种音符池、无放回约束、选择器默认值、Staff 边界以及模式间状态隔离。

## 2. 修改前的 BCR-1 实际行为

修改前已经存在 `TrainerExerciseMode.bcr1`，并已固定：

- Bass Clef
- `Staff -> Piano`
- 单行钢琴
- `.rowOnly`
- `.pitchClass` 判题

但 BCR-1 尚无独立出题子模式。它仍沿用普通 sequence 的 `noteCount`、`includesAccidentals` 和 Bass Clef 候选池，并采用有放回随机，因此：

- 不能表达“只出线上音”或“只出间上音”
- 同一题内可能重复音符
- 数量不固定为 8
- 没有“线上 / 间上 / 混合”选择器
- Scene 仍只有 Staff 与 Piano 两个区域

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/类型名: TrainerSequenceConfiguration, TrainerDisplayState.resolvedSequenceConfiguration
// 功能说明: 修改前只解析谱号与判题等已有 mode constraints，没有 BCR-1 子模式和独立生成策略。
struct TrainerSequenceConfiguration: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool
    var answerPolicy: TrainerSequenceAnswerPolicy
}

extension TrainerDisplayState {
    var resolvedSequenceConfiguration: TrainerSequenceConfiguration {
        sequenceConfiguration.applyingModeConstraints(exerciseMode)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数名: StaffQuarterNoteSequenceGenerator.makeSequence(spec:using:)
// 功能说明: 修改前从谱号对应候选池逐次 randomElement；这是有放回抽样，允许重复。
let candidates = resolvedCandidates(for: spec)
let selectedPitches = (0..<spec.noteCount).map { _ in
    guard let pitch = candidates.randomElement(using: &generator) else {
        preconditionFailure(
            "Quarter-note sequence pitch selection should always succeed."
        )
    }
    return pitch
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: ExerciseCompositionPolicy.makeMainSceneNode(from:preferences:trainerDisplayState:)
// 功能说明: 修改前 BCR-1 与其它 stacked recognition scene 一样，只生成 prompt 和 answer 两个 child。
return .makeSplit(
    axis: .vertical,
    children: [
        makeVerticalSceneChild(for: sceneSurfaces.prompt),
        makeVerticalSceneChild(for: sceneSurfaces.answer)
    ]
)
```

## 3. 修改后的 BCR-1 最终合同

共同固定合同：

- `clef = .bass`
- `noteCount = 8`
- `includesAccidentals = false`
- `answerPolicy = .pitchClass`
- Piano 固定 1 row
- Piano movement 固定 `.rowOnly`
- 默认子模式为 `.mixed`
- 每次先构造候选音序列，再执行约束式无放回抽样，最后整体随机打乱

三个子模式的精确语义：

1. 线上 `.line`
   - progression：`起始 C2 / 音程编号 3 / 候选数量 8`
   - 洗牌前候选：`C2 E2 G2 B2 D3 F3 A3 C4`
   - 输出 8 个，全部为 Bass Clef 的线位置
   - 因候选数和输出数均为 8，最终每个候选恰好出现一次，只改变顺序
2. 间上 `.space`
   - progression：`起始 D2 / 音程编号 3 / 候选数量 8`
   - 洗牌前候选：`D2 F2 A2 C3 E3 G3 B3 D4`
   - 输出 8 个，全部为 Bass Clef 的间位置
   - 同样每个候选恰好出现一次，只改变顺序
3. 混合 `.mixed`
   - progression：`起始 C2 / 音程编号 2 / 候选数量 16`
   - 候选为 `C2...D4` 的 16 个连续自然音
   - 无放回随机选 8 个
   - 至少包含 1 个线上音和 1 个间上音
   - 不要求“4 个线上音 + 4 个间上音”
   - 最终整体洗牌

这里的 `intervalNumber = 3` 表示自然音级三度；实际 diatonic index 步长为 `3 - 1 = 2`。

## 4. 通用自然音级 progression

### 4.1 修改前

项目中不存在“起始音 + 固定音程 + 候选数量”的通用自然音级生成器。线上音和间上音若直接写成两个固定数组，会使后续改成四度、五度时需要改业务分支。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffDiatonicPitchSequenceGenerator.swift
// 类型/函数名: StaffDiatonicPitchProgressionSpec, StaffDiatonicPitchSequenceGenerator.makeCandidates(for:)
// 功能说明: 修改前该文件和对应的 progression 抽象均不存在。
// 修改前状态: 无通用自然音级 progression 类型。
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffDiatonicPitchSequenceGenerator.swift
// 类型/函数名: StaffDiatonicPitchProgressionSpec.diatonicStepCount, StaffDiatonicPitchSequenceGenerator.makeCandidates(for:)
// 功能说明: 按自然音级索引生成候选；只接受自然起始音，音程至少为二度，候选数量必须大于零。
struct StaffDiatonicPitchProgressionSpec: Equatable, Sendable {
    var startPitch: StaffPitch
    var intervalNumber: Int
    var candidateCount: Int

    var diatonicStepCount: Int {
        intervalNumber - 1
    }
}

struct StaffDiatonicPitchSequenceGenerator: Equatable, Sendable {
    func makeCandidates(
        for spec: StaffDiatonicPitchProgressionSpec
    ) -> [StaffPitch] {
        (0..<spec.candidateCount).map { offset in
            StaffPitch(
                naturalDiatonicIndex: spec.startPitch.diatonicIndex
                    + (offset * spec.diatonicStepCount)
            )
        }
    }
}
```

该抽象不包含“混合”业务概念。它只负责确定性地产生 progression 候选；BCR-1 的混合约束由抽样策略组合完成，因此未来可以复用同一个 progression 生成器表达四度、五度等候选序列。

## 5. 线上/间上分类与约束式无放回抽样

### 5.1 修改前

`StaffPitchLayout.positionedPitch` 内部会计算 staff position，但外部没有统一的“line / space”分类 API；sequence generator 也只有有放回随机。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift
// 函数名: StaffPitchLayout.positionedPitch(_:in:)
// 功能说明: 修改前 staffPosition 是函数内部局部值，生成策略无法复用 clef-relative 位置语义。
let staffPosition =
    pitch.diatonicIndex - bottomLineReferencePitch.diatonicIndex
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffPitchLayout.swift
// 类型/函数名: StaffPositionKind, StaffPitchLayout.staffPosition(for:), StaffPitchLayout.positionKind(for:)
// 功能说明: 以当前谱号底线参考音为基准；偶数 staff position 为线，奇数为间，谱表外加线/加间使用同一规则。
enum StaffPositionKind: Equatable, Hashable, Sendable {
    case line
    case space
}

func staffPosition(for pitch: StaffPitch) -> Int {
    pitch.diatonicIndex - bottomLineReferencePitch.diatonicIndex
}

func positionKind(for pitch: StaffPitch) -> StaffPositionKind {
    staffPosition(for: pitch).isMultiple(of: 2)
        ? .line
        : .space
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 类型名: StaffWithoutReplacementSelectionSpec, StaffQuarterNoteGenerationStrategy
// 功能说明: 新策略携带输出数量以及 line/space 最小数量；旧策略保留为默认值以维持 SR 和普通 Sequence 行为。
struct StaffWithoutReplacementSelectionSpec: Equatable, Sendable {
    var outputCount: Int
    var minimumLineCount: Int
    var minimumSpaceCount: Int
}

enum StaffQuarterNoteGenerationStrategy: Equatable, Sendable {
    case clefRangeRandomWithReplacement
    case diatonicProgression(
        progression: StaffDiatonicPitchProgressionSpec,
        selection: StaffWithoutReplacementSelectionSpec
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffQuarterNoteSequenceGenerator.swift
// 函数名: StaffQuarterNoteSequenceGenerator.selectWithoutReplacement(candidates:clef:spec:using:)
// 功能说明: 先从 remaining 中满足最低 line/space 数量，再随机补足输出数量，最后洗牌；remove(at:) 保证同一候选不会重复入选。
var remaining = candidates
var selected: [StaffPitch] = []
let layout = StaffPitchLayout(clef: clef)

removeRandomCandidates(
    count: spec.minimumLineCount,
    kind: .line,
    from: &remaining,
    into: &selected,
    layout: layout,
    using: &generator
)
removeRandomCandidates(
    count: spec.minimumSpaceCount,
    kind: .space,
    from: &remaining,
    into: &selected,
    layout: layout,
    using: &generator
)

while selected.count < spec.outputCount {
    selected.append(
        removeRandomCandidate(from: &remaining, using: &generator)
    )
}

selected.shuffle(using: &generator)
return selected
```

旧的 `.clefRangeRandomWithReplacement` 被保留并继续作为默认 strategy。这样此次改动没有静默改变 SR-0、SR-1、SR-2 或普通 Sequence 的既有随机语义。

## 6. BCR-1 子模式状态与 resolved sequence

### 6.1 修改前

BCR-1 没有子模式字段，`TrainerDisplayState` 只携带共享 `sequenceConfiguration`。模式约束只固定了 BCR-1 的 Bass Clef 与 pitch-class 等 recognition 合同，不固定 8 个自然音，也没有 generation strategy。

### 6.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 类型/属性名: TrainerBCR1QuestionMode, TrainerBCR1QuestionConfiguration.generationStrategy
// 功能说明: 将三个 UI 子模式映射成声明式 progression + selection 合同，默认 mixed。
enum TrainerBCR1QuestionMode: CaseIterable, Equatable, Hashable, Sendable {
    case line
    case space
    case mixed
}

struct TrainerBCR1QuestionConfiguration: Equatable, Sendable {
    var mode: TrainerBCR1QuestionMode

    static let `default` = TrainerBCR1QuestionConfiguration(mode: .mixed)

    var generationStrategy: StaffQuarterNoteGenerationStrategy {
        switch mode {
        case .line:
            return .diatonicProgression(
                progression: .init(
                    startPitch: StaffPitch(letter: .c, octave: 2),
                    intervalNumber: 3,
                    candidateCount: 8
                ),
                selection: .init(outputCount: 8, minimumLineCount: 8)
            )
        case .space:
            return .diatonicProgression(
                progression: .init(
                    startPitch: StaffPitch(letter: .d, octave: 2),
                    intervalNumber: 3,
                    candidateCount: 8
                ),
                selection: .init(outputCount: 8, minimumSpaceCount: 8)
            )
        case .mixed:
            return .diatonicProgression(
                progression: .init(
                    startPitch: StaffPitch(letter: .c, octave: 2),
                    intervalNumber: 2,
                    candidateCount: 16
                ),
                selection: .init(
                    outputCount: 8,
                    minimumLineCount: 1,
                    minimumSpaceCount: 1
                )
            )
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名: TrainerDisplayState.resolvedSequenceConfiguration
// 功能说明: 只在 BCR-1 覆盖共享 sequence 请求，集中锁定 Bass、8 个自然音、pitchClass 和当前子模式 strategy。
var resolvedSequenceConfiguration: TrainerSequenceConfiguration {
    var resolved = sequenceConfiguration.applyingModeConstraints(exerciseMode)
    guard exerciseMode == .bcr1 else {
        return resolved
    }

    resolved.clef = .bass
    resolved.noteCount = 8
    resolved.includesAccidentals = false
    resolved.answerPolicy = .pitchClass
    resolved.generationStrategy =
        bcr1QuestionConfiguration.generationStrategy
    return resolved
}
```

`generationStrategy` 同步贯穿：

`TrainerSequenceConfiguration`
→ `FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec`
→ `StaffQuarterNoteSequenceGenerator.Spec`
→ `makeSequence(spec:using:)`

因此子模式变化会改变 quarter-note spec 的值身份，并触发真正的内容重新生成，而不是只改变 UI 标签。

## 7. Shared 选择器模型与双平台视图

### 7.1 修改前

不存在 BCR-1 selector model、event 或平台 view，也没有与三种子模式对应的 accessibility 标识。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/BCR1QuestionModeSelectorModel.swift
// 类型/函数名: BCR1QuestionModeSelectorModel.make(from:), BCR1QuestionModeSelectorEvent
// 功能说明: 修改前该文件不存在，BCR-1 场景没有子模式选择器模型和事件。
// 修改前状态: 无 selector model / event。
```

### 7.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/BCR1QuestionModeSelectorModel.swift
// 函数名: BCR1QuestionModeSelectorModel.make(from:)
// 功能说明: 从 TrainerDisplayState 投影固定顺序和单一选中态；平台层不自行解释业务模式。
static func make(from state: TrainerDisplayState) -> Self {
    let selectedMode = state.bcr1QuestionConfiguration.mode
    return Self(
        accessibilityLabel: "选择 BCR-1 音符位置模式",
        choices: [
            .init(mode: .line, title: "线上", isSelected: selectedMode == .line),
            .init(mode: .space, title: "间上", isSelected: selectedMode == .space),
            .init(mode: .mixed, title: "混合", isSelected: selectedMode == .mixed)
        ]
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSBCR1QuestionModeSelectorView.swift
// 函数名: iOSBCR1QuestionModeSelectorView.apply(model:), handleSelectionChanged(_:)
// 功能说明: apply 阶段重建 segment 并同步 selected index；用户事件通过 shared event 回传，isApplyingModel 防止模型刷新反向触发业务操作。
func apply(model: BCR1QuestionModeSelectorModel) {
    choices = model.choices
    isApplyingModel = true
    segmentedControl.removeAllSegments()
    // 按 model.choices 顺序写入“线上 / 间上 / 混合”并设置选中项。
    segmentedControl.selectedSegmentIndex = selectedIndex
    isApplyingModel = false
}

@objc
private func handleSelectionChanged(_ sender: UISegmentedControl) {
    guard !isApplyingModel,
          choices.indices.contains(sender.selectedSegmentIndex) else {
        return
    }
    onEvent?(.select(choices[sender.selectedSegmentIndex].mode))
}
```

`macOSBCR1QuestionModeSelectorView` 使用相同的 model/event 流程，只将平台控件替换为 `NSSegmentedControl`。两个平台都提供稳定的 selector 和 segmented-control accessibility identifier。

## 8. Exercise Scene：从上下两层改为上中下三层

### 8.1 修改前

BCR-1 的主场景沿用普通 `.staffToPiano + .stacked`，结构为：

- 上：Staff prompt
- 下：Piano answer

Scene surface 集合中没有 selector；rendered layout 摘要也只支持一个或两个直接 surface child。

### 8.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCore.swift
// 类型名: AppSurfaceID, AppSurfaceKind
// 功能说明: 将问题模式选择器建模为真正的 scene surface，而不是 controller 在 scene 外叠加的临时控件。
enum AppSurfaceID: String, CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case targetPrompt
    case naturalNoteStrip
    case piano
    case questionModeSelector
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: ExerciseCompositionPolicy.makeMainSceneNode(from:preferences:trainerDisplayState:)
// 功能说明: BCR-1 专用三层垂直 scene；selector 和 Staff 按内容高度，Piano 消耗剩余空间。
if trainerDisplayState?.exerciseMode == .bcr1 {
    return .makeSplit(
        axis: .vertical,
        children: [
            ExerciseSceneSplitChild(
                node: .surface(.bcr1QuestionModeSelector),
                mainAxisSizing: .fitContent
            ),
            ExerciseSceneSplitChild(
                node: .surface(sceneSurfaces.prompt),
                mainAxisSizing: .fitContent
            ),
            ExerciseSceneSplitChild(
                node: .surface(sceneSurfaces.answer),
                mainAxisSizing: .weighted(1)
            )
        ]
    )
}
```

最终顺序和角色严格为：

- `questionModeSelector`：上层，`.auxiliary`，可见、可交互，不承担 prompt/answer
- `staff`：中层，`.prompt`
- `piano`：下层，`.answer`

三层尺寸严格为：

- `.fitContent`
- `.fitContent`
- `.weighted(1)`

### 8.3 Rendered layout 从固定双 child 泛化为 N-child

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 类型/函数名: ExerciseRenderedSceneLayout, ExerciseSceneNode.renderedSceneLayout
// 功能说明: 修改前结构直接保存 primary/secondary；split 不是恰好两个 surface 时返回 nil。
struct ExerciseRenderedSceneLayout: Equatable, Sendable {
    var arrangement: ExerciseRenderedSceneArrangement
    var primarySurface: ExerciseSurfaceNode
    var primaryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing
    var secondarySurface: ExerciseSurfaceNode?
    var secondaryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing?
}

guard children.count == 2,
      case let .surface(primarySurface) = children[0].node,
      case let .surface(secondarySurface) = children[1].node else {
    return nil
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 类型/函数名: ExerciseRenderedSceneChild, ExerciseRenderedSceneLayout, ExerciseSceneNode.renderedSceneLayout
// 功能说明: 修改后完整保留所有直接 surface child；兼容 accessor 仍从 children[0] 和 children[1] 投影旧 primary/secondary 语义。
struct ExerciseRenderedSceneChild: Equatable, Sendable {
    var surface: ExerciseSurfaceNode
    var mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing
}

struct ExerciseRenderedSceneLayout: Equatable, Sendable {
    var arrangement: ExerciseRenderedSceneArrangement
    var children: [ExerciseRenderedSceneChild]
}

let renderedChildren: [ExerciseRenderedSceneChild] =
    children.compactMap { child in
        guard case let .surface(surface) = child.node else {
            return nil
        }
        return ExerciseRenderedSceneChild(
            surface: surface,
            mainAxisSizing: child.mainAxisSizing
        )
    }
guard renderedChildren.count == children.count else {
    return nil
}
```

这项泛化是三层 scene 能被布局合同和验证完整观察到的必要条件；旧的一/二 surface 场景继续通过兼容 accessor 工作。

## 9. Regenerate button 跟随真正的 prompt surface

### 9.1 修改前

regenerate button 固定添加到整个 `sceneContainerView` 的右上角。加入 selector 后，如果继续沿用该位置，按钮会视觉上落入最上方 selector 区域，而不是 Staff 出题区。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.configureStaticHierarchy()
// 功能说明: 修改前按钮属于整个 scene container，并固定锚定 scene 顶部；macOS 具有同构实现。
sceneContainerView.addSubview(sceneContentView)
sceneContainerView.addSubview(sequenceRegenerateButton)

sequenceRegenerateButton.topAnchor.constraint(
    equalTo: sceneContainerView.topAnchor,
    constant: metrics.floatingButtonInset
)
```

### 9.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: iOSExerciseSceneRenderer.renderSurface(_:in:), installSequenceRegenerateButton(inPromptHost:)
// 功能说明: 渲染到带 prompt role 的 surface 时迁移按钮并重新建立约束，使 BCR-1 中按钮归属于 Staff host。
private func renderSurface(
    _ surface: ExerciseSurfaceNode,
    in hostView: UIView
) {
    // ... 嵌入实际 surface view ...
    if surface.isPromptSurface {
        installSequenceRegenerateButton(inPromptHost: hostView)
    }
}

private func installSequenceRegenerateButton(
    inPromptHost hostView: UIView
) {
    sequenceRegenerateButton.removeFromSuperview()
    hostView.addSubview(sequenceRegenerateButton)
    // 按 prompt host 的 top/trailing 锚定按钮。
}
```

macOS renderer 采用相同规则，将按钮安装到 prompt `SurfaceSlotView`。因此：

- BCR-1 中按钮位于中间 Staff 出题区
- selector 区不承载 regenerate button
- 其它含 prompt surface 的 scene 继续取得同一按钮

## 10. 子模式切换事务

### 10.1 修改前

没有 BCR-1 selector event handler，也不存在专门的播放停止原因。切换子模式时需要清理哪些状态尚无实现。

### 10.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.handleBCR1QuestionModeSelectorEvent(_:)
// 功能说明: 仅在当前确为 BCR-1 且 mode 实际变化时执行；重复点击当前项是 no-op。
private func handleBCR1QuestionModeSelectorEvent(
    _ event: BCR1QuestionModeSelectorEvent
) {
    guard
        case let .select(nextMode) = event,
        trainerDisplayState.exerciseMode == .bcr1,
        nextMode != trainerDisplayState.bcr1QuestionConfiguration.mode
    else {
        return
    }

    interruptActivePianoPlayback(reason: .bcr1QuestionModeChanged)
    trainerDisplayState.setBCR1QuestionMode(nextMode)
    resetQuarterNoteSequenceInteractionState()
    synchronizeTrainerPresentationState(reason: "bcr1QuestionModeChanged")
}
```

macOS 在 `performPresentationTransaction` 内执行同一顺序，保证 AppKit 的 scene/state 更新原子化。

实际事务语义为：

1. 忽略非 BCR-1 事件和重复选择
2. 以 `.bcr1QuestionModeChanged` 停止当前 Piano preview/voice
3. 写入新的 `bcr1QuestionConfiguration.mode`
4. 清理旧 sequence session、答题 evaluation、Staff feedback 和 Piano preview cache
5. 使用新 resolved generation strategy 立即生成新题
6. selector 选中态、Staff 序列和 Piano 作答状态在同一轮同步

手动点击 regenerate 只重新生成当前 strategy，不改当前 line/space/mixed 子模式。

## 11. BCR-1 专用 Staff 垂直留白

### 11.1 修改前

Staff 高度只由 clef 的基础 preferred height 决定。新 BCR-1 音域扩展到 `C2...D4` 后，边界音符的 notehead、stem 或 ledger line 可能超出原来的 drawing bounds。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 属性名: StaffConfiguration.preferredHeight
// 功能说明: 修改前没有模式可选的额外垂直留白，所有 Staff 共用基础高度。
var preferredHeight: CGFloat {
    layoutMetrics.preferredHeight(for: clef)
}
```

### 11.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffConfiguration.swift
// 属性名: StaffConfiguration.additionalVerticalStaffSpaces, preferredHeight
// 功能说明: 额外空间使用 staff-space 作为单位，只增加外围呼吸空间，不改变五线间距几何。
var additionalVerticalStaffSpaces: CGFloat

var preferredHeight: CGFloat {
    layoutMetrics.preferredHeight(for: clef)
        + (
            layoutMetrics.normalizedStaffSpaceHeight
                * additionalVerticalStaffSpaces
        )
}
```

BCR-1 使用 `TrainerBCR1QuestionConfiguration.staffAdditionalVerticalSpaces = 2`。双平台 controller 只在当前模式为 `.bcr1` 时应用该值；离开 BCR-1 或清除 sequence presentation 时恢复 `baseStaffDisplayState` 的值，避免影响 SR 和普通 Staff。

## 12. 验证覆盖的修改前后

### 12.1 修改前

已有验证只覆盖旧 BCR-1 的 Bass / single-row / pitch-class recognition 合同；没有验证：

- 三个子模式的精确候选池
- 无放回和混合最低覆盖约束
- 默认 `.mixed`
- selector 顺序与角色
- 三层 Scene 与 N-child rendered layout
- 切换时的播放中断和状态清理
- 边界音符的 Staff containment

### 12.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: FretboardValidationRunner.validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 锁定两个三度池、16 音混合池、line/space 分类、无重复、8 音数量、默认 mixed 及 selector 顺序。
let expectedLinePitches = [
    "C2", "E2", "G2", "B2", "D3", "F3", "A3", "C4"
]
let expectedSpacePitches = [
    "D2", "F2", "A2", "C3", "E3", "G3", "B3", "D4"
]

// mixed 输出必须是 16 音池的 8 个唯一自然音，
// 且实际 StaffPositionKind 集合必须同时包含 .line 和 .space。
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名: ExerciseCompositionValidationRunner.validateBCR1QuestionModeSelectorBuildsThreeSurfaceScene()
// 功能说明: 验证三层顺序、尺寸、角色、viewport 固定语义和 SR-1 不泄漏 selector。
if surfaces.map(\.id)
    != [.questionModeSelector, .staff, .piano] {
    issues.append(
        issue(
            fixtureName,
            "BCR-1 三层 surface 顺序应严格为 selector、staff、piano。"
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 夹具/函数名: bass-bcr1-boundary-sequence-feedback / StaffValidationRunner
// 功能说明: 用 BCR-1 的低音和高音边界及反馈绘制状态验证 notehead、stem、ledger line 均落在 drawing bounds 内。
let bcr1BassConfiguration = StaffConfiguration(
    clef: .bass,
    renderMode: .coreText,
    additionalVerticalStaffSpaces:
        TrainerBCR1QuestionConfiguration.staffAdditionalVerticalSpaces
)
```

双平台 BCR-1 runtime smoke 还实际验证：

- 从 Settings 切入 BCR-1 后默认 `.mixed`
- selector 显示“线上 / 间上 / 混合”
- Scene 顺序和 sizing 正确
- regenerate button 属于 Staff prompt host
- mixed 序列为 8 个唯一自然音，并同时包含 line/space
- 错误答案不推进
- 切到 `.line` 会重置 session、反馈、preview cache 和 playback
- 重复选择 `.line` 不重新生成
- 切到 `.space` 会清理预先注入的交互状态并重新生成
- 手动 regenerate 保持 `.space`
- 同 pitch class、不同 octave 按 `.pitchClass` 判定正确并推进
- 离开 BCR-1 后 selector、session、反馈、cache 和额外 Staff 留白均不泄漏

## 13. 实施中出现并修正的问题

### 13.1 N-child compactMap 类型推断

第一次编译 N-child rendered layout 时，Swift 无法从包含 `nil` 的 closure 自动推断 `compactMap` 的元素类型。最终为 `renderedChildren` 显式声明 `[ExerciseRenderedSceneChild]`，保留同一业务逻辑并通过编译。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExerciseSceneNode.renderedSceneLayout
// 功能说明: 显式结果类型解决 compactMap 泛型推断，不改变“仅接受直接 surface child”的合同。
let renderedChildren: [ExerciseRenderedSceneChild] =
    children.compactMap { child in
        guard case let .surface(surface) = child.node else {
            return nil
        }
        return ExerciseRenderedSceneChild(
            surface: surface,
            mainAxisSizing: child.mainAxisSizing
        )
    }
```

### 13.2 BCR-1 边界音符超出 Staff bounds

第一次启动验证中，新增 `bass-bcr1-boundary-sequence-feedback` 夹具发现 `C2` 边界绘制超出旧 Staff bounds。最终没有放宽全局 containment 断言，也没有裁掉边界音，而是增加按模式配置的 `additionalVerticalStaffSpaces`，并限定只由 BCR-1 controller 应用。

这保证了：

- `C2...D4` 的目标音域保持不变
- Staff 绘制仍满足 containment
- SR-0、SR-1、SR-2 的既有 Staff 高度不变
- 离开 BCR-1 后额外空间被清理

## 14. 最终验证结果

### 14.1 静态检查

- 本次涉及的 Swift 文件 IDE diagnostics：无新增问题
- `git diff --check`：通过

### 14.2 双平台 Debug 构建

```bash
# 文件路径: /Users/shaun/cloudDev/NoteMaster_Ver_1
# 命令/函数名: xcodebuild macOS / iOS Simulator Debug
# 功能说明: 分别编译 shared、平台 selector、renderer、controller 和 validation 接线。
xcodebuild \
  -project NoteMaster_Ver_1.xcodeproj \
  -scheme NoteMaster_Ver_1 \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/NoteMaster-BCR1-macOS-final \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project NoteMaster_Ver_1.xcodeproj \
  -scheme NoteMaster_Ver_1 \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/NoteMaster-BCR1-iOS-final \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- macOS Debug：`** BUILD SUCCEEDED **`
- iOS Simulator Debug：`** BUILD SUCCEEDED **`

### 14.3 双平台 startup validation

最终 macOS 结果：

- `FretboardValidation`: `automated=PASS fixtures=7`
- `StaffValidation`: `automated=PASS fixtures=58`
- `SettingsNavigationValidation`: `automated=PASS fixtures=24`
- `PianoValidation`: `automated=PASS fixtures=32`
- `PlaybackValidation`: `automated=PASS fixtures=6`
- `PlayCompositionValidation`: `automated=PASS fixtures=2`
- `ExerciseCompositionValidation`: `automated=PASS fixtures=40`
- `PASS scenario=startup_validation`

最终 iOS runtime 启动过程输出相同的各 validation PASS 计数。

### 14.4 BCR-1 runtime smoke

- macOS：`PASS scenario=bcr1_piano_answer finalMode=single`
- iOS Simulator：`PASS scenario=bcr1_piano_answer finalMode=single`

### 14.5 SR 回归 smoke

- macOS：
  - `PASS scenario=sr0_note_strip_answer`
  - `PASS scenario=sr1_piano_answer`
  - `PASS scenario=sr2_piano_answer`
- iOS Simulator：
  - `PASS scenario=sr0_note_strip_answer`
  - `PASS scenario=sr1_piano_answer`
  - `PASS scenario=sr2_piano_answer`

这组回归实际确认旧有 SR family 仍使用原有 scene、判题和生成入口，没有因 BCR-1 selector 或无放回策略发生行为漂移。

## 15. 明确未修改的边界

- 没有改变 `TrainerExerciseMode.bcr1` 原有的 Bass Clef、单行钢琴、`.rowOnly` 和 `.pitchClass` 基础 recognition 合同
- 没有把混合模式固定为 4 个线上音加 4 个间上音
- 没有在通用 progression generator 内加入 BCR-1 或 mixed 特例
- 没有改变旧 `.clefRangeRandomWithReplacement` 的默认行为
- 没有改变 SR-0、SR-1、SR-2 的 generation strategy
- 没有把 selector 放入 Settings；它属于 BCR-1 Exercise scene 的上层区域
- 没有把 regenerate button 放在 selector 区域
- 没有全局增大所有 Staff 的高度
- 没有修改任何已有 Markdown 文件
- 没有修改计划文件
- 没有提交 Git commit

## 16. 结论

本次实现不是为三种模式各写一套固定音符数组和平台分支，而是建立了三层可组合合同：

1. 通用 progression 负责按“起始音、音程编号、候选数量”生成自然音级候选；
2. 通用 selection 负责按 clef-relative line/space 最小数量进行无放回抽样和最终洗牌；
3. BCR-1 configuration 只负责把 `.line / .space / .mixed` 映射为具体参数。

界面侧将 selector 建模为正式 auxiliary surface，使 BCR-1 的 Scene 成为 `selector -> Staff -> Piano` 三层结构。双平台 controller 使用相同 shared model 和切换事务，保证切换时停止播放、清空旧交互状态并立即依据新策略重新出题；完整的 shared validation、双平台 runtime smoke 和 SR 回归均已通过。

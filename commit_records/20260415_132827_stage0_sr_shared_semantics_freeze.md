# 20260415_132827_stage0_sr_shared_semantics_freeze

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_132827`
- 记录依据：基于当前工作区 `changes`、`git diff --stat`、`git diff --unified=12` 整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 0”真实落地的代码改动；目标是冻结 `SR-1 / SR-2` 的共享语义边界，不开放 UI 入口，不接 `staffToPiano`
- 当前 diff 统计：`10 files changed, 64 insertions(+), 12 deletions(-)`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift`
- 验证结果：
- `ReadLints`：无诊断错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug build CODE_SIGNING_ALLOWED=NO`：构建通过
- 说明：本记录文件本身是新增的 markdown 记录，不计入上面“阶段 0 实际代码修改文件”的 10 个 `Swift` 文件范围

## 本次结论

- `TrainerExerciseMode` 现在已经预留了 `.sr1` 与 `.sr2`，后续阶段不需要再返工 mode 命名
- 新增了 `TrainerSequenceAnswerPolicy`，并用 `fixedSequenceAnswerPolicy` 明确了 `SR-1 -> .pitchClass`、`SR-2 -> .exactNote` 的冻结语义
- 新增了 `usesQuarterNoteSequenceKernel`，把“是否复用 `quarterNoteSequence` 内核”从旧的 `isSequenceMode` UI 语义里拆开
- 为了保证阶段 0 之后工程仍可编译，所有依赖 `TrainerExerciseMode` 的关键 `switch` 都补齐了 `sr1 / sr2` 的穷举分支
- 这些新分支当前都只是 sequence-compatible fallback，不代表已经开放 SR 运行时行为
- `QuarterNoteSequenceSpec`、`GeneratedNoteSequenceItem` 等处只增加了语义注释，明确后续 exact-note seam 的 ownership；`answerPolicy` 还没有真正接入配置链

## 修改 1：冻结 `TrainerDisplayState` 的共享语义边界

### 修改前

- 旧的 `TrainerExerciseMode` 只有 `single / sequence / positionPrompt`
- 旧的 `isSequenceMode` 同时承担“UI 选中态”和“是否复用 quarter-note sequence 内核”的双重语义
- 旧结构里没有 `SR-1 / SR-2` 对应的固定判题策略语义

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: enum TrainerExerciseMode / var isSequenceMode
// 功能说明: 修改前只有旧三态 exercise mode；
// `isSequenceMode` 直接绑定 `.sequence`，没有为 SR 模式预留独立的共享语义 seam。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode

    var isSequenceMode: Bool {
        exerciseMode == .sequence
    }
}
```

### 修改后

- 预留了 `sr1 / sr2`
- 新增 `TrainerSequenceAnswerPolicy`
- 新增 `fixedSequenceAnswerPolicy`
- 保留旧 `isSequenceMode`，但只让它继续表示老的 `.sequence` UI 语义
- 新增 `usesQuarterNoteSequenceKernel`，单独表达“是否复用 quarter-note sequence trainer 内核”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: enum TrainerExerciseMode / enum TrainerSequenceAnswerPolicy / fixedSequenceAnswerPolicy / isSequenceMode / usesQuarterNoteSequenceKernel
// 功能说明: 修改后先冻结 SR 共享语义；
// 不提前开放 SR UI，只把 mode 形状、固定判题策略和内核复用谓词预留出来。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
    case sr1
    case sr2
}

enum TrainerSequenceAnswerPolicy: Equatable, Hashable, Sendable {
    case pitchClass
    case exactNote
}

extension TrainerExerciseMode {
    var fixedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy? {
        switch self {
        case .sr1:
            return .pitchClass
        case .sr2:
            return .exactNote
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode

    // 保持旧的 `.sequence` UI 语义，避免阶段 0 提前牵动 settings 选中态和既有入口。
    var isSequenceMode: Bool {
        exerciseMode == .sequence
    }

    // 这是后续阶段真正要消费的共享 seam：哪些 mode 复用 quarter-note sequence 内核。
    var usesQuarterNoteSequenceKernel: Bool {
        switch exerciseMode {
        case .sequence, .sr1, .sr2:
            return true
        case .single, .positionPrompt:
            return false
        }
    }
}
```

## 修改 2：在 shared scene / legacy fallback 层补齐 `sr1 / sr2` 穷举分支

### 2.1 `ExerciseCompositionPolicy+Normalization.swift`

#### 修改前

- normalization 只认识 `.single / .sequence / .positionPrompt`
- 一旦 `TrainerExerciseMode` 新增 case，这里的 `switch` 就会失去穷举性

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: isCompositionPresetSupported(_:for:) / normalizedCompositionPreset(_:for:)
// 功能说明: 修改前 normalization 只覆盖旧三种 exercise mode。
static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    switch exerciseMode {
    case .single, .sequence:
        // old sequence-compatible branch
    case .positionPrompt:
        // old position prompt branch
    }
}

static func normalizedCompositionPreset(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> ExerciseCompositionPreset {
    guard isCompositionPresetSupported(preset, for: exerciseMode) else {
        switch exerciseMode {
        case .single, .sequence:
            return .staffToFretboard
        case .positionPrompt:
            return .fretboardToNaturalNoteStrip
        }
    }
    return preset
}
```

#### 修改后

- `sr1 / sr2` 暂时并入旧的 sequence-compatible normalization 分支
- 新增注释，明确这只是阶段 0 的过渡语义，不代表 `staffToPiano` 已经落地

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: isCompositionPresetSupported(_:for:) / normalizedCompositionPreset(_:for:)
// 功能说明: 修改后给 SR mode 补齐穷举分支；
// 在 `staffToPiano` 落地前，SR mode 暂时走旧的 sequence-compatible normalization envelope。
static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    // Stage 0 only reserves SR modes. Until `staffToPiano` lands, keep them
    // on the existing sequence-compatible normalization envelope.
    switch exerciseMode {
    case .single, .sequence, .sr1, .sr2:
        // temporary sequence-compatible branch
    case .positionPrompt:
        // existing position prompt branch
    }
}

static func normalizedCompositionPreset(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> ExerciseCompositionPreset {
    guard isCompositionPresetSupported(preset, for: exerciseMode) else {
        switch exerciseMode {
        case .single, .sequence, .sr1, .sr2:
            return .staffToFretboard
        case .positionPrompt:
            return .fretboardToNaturalNoteStrip
        }
    }
    return preset
}
```

### 2.2 `ExerciseCompositionPolicy.swift`

#### 修改前

- legacy-compatible preferences 的 fallback 只覆盖 `single / sequence`
- 新增 SR mode 后，这里会变成不完整分支

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: legacyCompatiblePreferences(from:) / fallbackLegacyCompatiblePreferences(for:isPianoAccessoryVisible:)
// 功能说明: 修改前 legacy-compatible fallback 只覆盖旧的 single 和 sequence。
switch input.trainerDisplayState.exerciseMode {
case .single, .sequence:
    legacyCompatiblePreferences.compositionPreset = .staffToFretboard
case .positionPrompt:
    legacyCompatiblePreferences.compositionPreset = .fretboardToNaturalNoteStrip
}

switch exerciseMode {
case .single, .sequence:
    return ExerciseLayoutPreferences(
        compositionPreset: .staffToFretboard,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
case .positionPrompt:
    return ExerciseLayoutPreferences(
        compositionPreset: .fretboardToNaturalNoteStrip,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: true,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
}
```

#### 修改后

- `sr1 / sr2` 暂时跟 `single / sequence` 一样走 `staffToFretboard` 的 legacy-compatible fallback
- 这一步的目的只是保持阶段 0 后 shared scene policy 仍然可编译、可运行

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: legacyCompatiblePreferences(from:) / fallbackLegacyCompatiblePreferences(for:isPianoAccessoryVisible:)
// 功能说明: 修改后把 SR mode 纳入旧的 sequence-compatible fallback，
// 只保证阶段 0 的 shared policy 编译和兼容行为，不提前切到 `staffToPiano`。
switch input.trainerDisplayState.exerciseMode {
case .single, .sequence, .sr1, .sr2:
    legacyCompatiblePreferences.compositionPreset = .staffToFretboard
case .positionPrompt:
    legacyCompatiblePreferences.compositionPreset = .fretboardToNaturalNoteStrip
}

switch exerciseMode {
case .single, .sequence, .sr1, .sr2:
    return ExerciseLayoutPreferences(
        compositionPreset: .staffToFretboard,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
case .positionPrompt:
    return ExerciseLayoutPreferences(
        compositionPreset: .fretboardToNaturalNoteStrip,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: true,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
}
```

### 2.3 `LegacyPageLayoutAdapter.swift`

#### 修改前

- 从 `PageDisplayState` 推导 composition preset、以及从 preferences 回投影 `PageDisplayState` 时，都只认识旧三态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: inferredPreferences(pageDisplayState:trainerDisplayState:pianoPanelState:) / projectedPageDisplayState(from:trainerDisplayState:)
// 功能说明: 修改前 legacy adapter 只覆盖旧三种 exercise mode。
switch trainerDisplayState.exerciseMode {
case .positionPrompt:
    inferredCompositionPreset = .fretboardToNaturalNoteStrip
case .single, .sequence:
    inferredCompositionPreset = .staffToFretboard
}

switch trainerDisplayState.exerciseMode {
case .single, .sequence:
    return .default
case .positionPrompt:
    return .positionPrompt
}
```

#### 修改后

- `sr1 / sr2` 暂时归到旧的 sequence-compatible legacy 分支
- 依旧没有开放任何 SR 专属 legacy 投影

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: inferredPreferences(pageDisplayState:trainerDisplayState:pianoPanelState:) / projectedPageDisplayState(from:trainerDisplayState:)
// 功能说明: 修改后让 legacy adapter 对 SR mode 保持编译期穷举；
// 阶段 0 仍然只走旧的 sequence-compatible fallback，不引入 SR 专属 page 投影。
switch trainerDisplayState.exerciseMode {
case .positionPrompt:
    inferredCompositionPreset = .fretboardToNaturalNoteStrip
case .single, .sequence, .sr1, .sr2:
    inferredCompositionPreset = .staffToFretboard
}

switch trainerDisplayState.exerciseMode {
case .single, .sequence, .sr1, .sr2:
    return .default
case .positionPrompt:
    return .positionPrompt
}
```

## 修改 3：在路由与 shared validation 层补齐 `sr1 / sr2`

### 3.1 `ExerciseAnswerRouter.swift`

#### 修改前

- debug 输出里没有 `sr1 / sr2`
- sequence 路由分支只接受 `.sequence`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: debugName(for:) / route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能说明: 修改前 router 只识别旧三态 exercise mode。
private func debugName(for mode: TrainerExerciseMode) -> String {
    switch mode {
    case .single:
        return "single"
    case .sequence:
        return "sequence"
    case .positionPrompt:
        return "positionPrompt"
    }
}

switch trainerDisplayState.exerciseMode {
case .single:
    // single coverage routing
case .sequence:
    // quarter note sequence routing
case .positionPrompt:
    // position prompt routing
}
```

#### 修改后

- debug 文本补齐 `sr1 / sr2`
- `sr1 / sr2` 暂时共用旧 sequence routing 分支，只保证阶段 0 编译与共享路由语义冻结

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: debugName(for:) / route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能说明: 修改后 router 对 SR mode 完成穷举补齐；
// 阶段 0 仍然只复用旧的 sequence-compatible route shape。
private func debugName(for mode: TrainerExerciseMode) -> String {
    switch mode {
    case .single:
        return "single"
    case .sequence:
        return "sequence"
    case .positionPrompt:
        return "positionPrompt"
    case .sr1:
        return "sr1"
    case .sr2:
        return "sr2"
    }
}

switch trainerDisplayState.exerciseMode {
case .single:
    // single coverage routing
case .sequence, .sr1, .sr2:
    // temporary sequence-compatible quarter note routing
case .positionPrompt:
    // position prompt routing
}
```

### 3.2 `ExerciseCompositionValidationExercisePolicy.swift`

#### 修改前

- legacy baseline validation 只把 `single / sequence` 视为同一组 exercise row 约束

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateLegacyBaseline(fixtureName:exerciseMode:expectedPageDisplayState:)
// 功能说明: 修改前 validation 只把旧的 single / sequence 作为同一类 baseline。
switch exerciseMode {
case .single, .sequence:
    // validate Exercise Mode / Composition Preset / Layout Preset rows
case .positionPrompt:
    // validate position prompt baseline
}
```

#### 修改后

- SR mode 暂时并入旧的 `single / sequence` baseline validation 分支
- 这保证阶段 0 之后 validation runner 仍然能编译和执行

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateLegacyBaseline(fixtureName:exerciseMode:expectedPageDisplayState:)
// 功能说明: 修改后 SR mode 在阶段 0 暂时沿用旧 sequence-compatible baseline，
// 只为保持 validation runner 穷举完整，不代表 SR UI 已经开放。
switch exerciseMode {
case .single, .sequence, .sr1, .sr2:
    // temporary sequence-compatible baseline validation
case .positionPrompt:
    // existing position prompt baseline validation
}
```

## 修改 4：双端 controller 只补 `switch` 穷举，不提前开放 SR 入口

### 4.1 `iOSViewController.swift`

#### 修改前

- `synchronizeTrainerPresentationState(reason:)` 只对 `.sequence` 调用 `synchronizeQuarterNoteSequencePresentation(reason:)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改前 iOS controller 只把 `.sequence` 送入 quarter-note sequence presentation。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}
```

#### 修改后

- `sr1 / sr2` 暂时并入旧的 quarter-note sequence presentation 分支
- 这里只是 controller 分发补齐，不是 SR 功能接线完成

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改后 iOS controller 对 SR mode 完成穷举补齐；
// 阶段 0 仍然只走 sequence-compatible presentation，不开放 SR 专属 UI。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence, .sr1, .sr2:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}
```

### 4.2 `macOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改前 macOS controller 与 iOS 一样，只把 `.sequence` 送入 quarter-note sequence presentation。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改后 macOS controller 也完成 SR mode 穷举补齐；
// 目前只是与旧 sequence 分支共用分发，不代表 SR UI 已经接通。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence, .sr1, .sr2:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}
```

## 修改 5：用注释冻结 exact-note seam 的 ownership，不改运行时行为

### 5.1 `FretboardNaturalNoteTrainer.swift`

#### 修改前

- `QuarterNoteSequenceSpec` 没有额外注释说明“内容生成”和“判题策略”要解耦
- `expectedWrittenPitch` 也没有明确说明它是 future exact-note seam 的依托

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: QuarterNoteSequenceSpec / QuarterNoteSequenceEvaluation.expectedWrittenPitch
// 功能说明: 修改前结构上已经保留了 written pitch，
// 但代码本身没有明确标注“它服务后续 exact-note seam”的责任边界。
struct QuarterNoteSequenceSpec: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool
}

struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
    var expectedItem: GeneratedNoteSequenceItem

    var expectedWrittenPitch: StaffPitch {
        expectedItem.writtenPitch
    }
}
```

#### 修改后

- 只加注释，不改行为
- 明确 `QuarterNoteSequenceSpec` 将来会接 `TrainerSequenceAnswerPolicy`
- 明确 `expectedWrittenPitch` 未来服务 exact-note judging

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: QuarterNoteSequenceSpec / QuarterNoteSequenceEvaluation.expectedWrittenPitch
// 功能说明: 修改后只冻结语义注释；
// 说明 sequence 内容模型与判题策略必须解耦，并保留 full written pitch 作为 future exact-note seam。
// Sequence content generation and judging policy stay decoupled.
// Stage 0 only freezes the seam here; later phases will thread
// `TrainerSequenceAnswerPolicy` through this spec instead of embedding it
// into `GeneratedNoteSequence`.
struct QuarterNoteSequenceSpec: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool
}

struct QuarterNoteSequenceEvaluation: Equatable, Sendable {
    var expectedItem: GeneratedNoteSequenceItem

    // Keep the full written pitch available so future exact-note judging can
    // compare `writtenPitch.notePitch` without reshaping the generated content.
    var expectedWrittenPitch: StaffPitch {
        expectedItem.writtenPitch
    }
}
```

### 5.2 `GeneratedNoteSequence.swift`

#### 修改前

- `writtenPitch` 和 `answerPitchClass` 的 role 已经存在，但没有明确说明“当前还是 pitch-class answer，未来 exact-note 通过外部 policy 选择”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift
// 函数名/符号: struct GeneratedNoteSequenceItem
// 功能说明: 修改前内容模型只体现字段，不直接说明 future exact-note seam 的 ownership。
struct GeneratedNoteSequenceItem: Equatable, Hashable, Sendable {
    var writtenPitch: StaffPitch
    var answerPitchClass: PitchClass
}
```

#### 修改后

- 只加注释，不改字段形状
- 明确 `writtenPitch` 保留完整音高
- 明确 `answerPitchClass` 仍是当前内容模型里的旧答案形状，exact-note 要靠外部 policy 切换

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/GeneratedNoteSequence.swift
// 函数名/符号: struct GeneratedNoteSequenceItem
// 功能说明: 修改后只补注释；
// 明确 `writtenPitch` 保留完整音高，`answerPitchClass` 仍然只是当前阶段的内容层答案投影。
struct GeneratedNoteSequenceItem: Equatable, Hashable, Sendable {
    // Keep the written pitch intact so future exact-note judging can compare the
    // full `NotePitch` without changing the generated content shape.
    var writtenPitch: StaffPitch

    // Current sequence answers are still modeled as pitch class only.
    // Later phases will select between `pitchClass` and exact-note judging via
    // external policy rather than by mutating this content model.
    var answerPitchClass: PitchClass
}
```

## 本次没有做的事情

- 没有给 `TrainerSequenceConfiguration` 增加 `answerPolicy`
- 没有给 `QuarterNoteSequenceSpec` 增加 `answerPolicy`
- 没有新增 `ResolvedSequenceAnswer`
- 没有修改 `ExerciseAnswerPayload`
- 没有新增 `ExerciseCompositionPreset.staffToPiano`
- 没有新增 `ExerciseSurfaceNode.pianoAnswer`
- 没有修改 `SettingsPanelModel.swift` 去开放 `setExerciseModeSr1`
- 没有修改 `SettingsPanelSnapshotBuilder.swift` / `SettingsNavigationSnapshotBuilder.swift` 去隐藏 SR-1 下的无效设置
- 没有改 `handlePianoSemanticEvent(_:)`，因此钢琴输入还没有进入答题管线
- 没有让 `SR-1` 真正运行起来；当前所有 `sr1 / sr2` 分支都只是为了阶段 0 的共享语义冻结与编译期穷举补齐

## 与计划的一致性说明

- 这次实现严格对应 `阶段 0：冻结共享语义边界`
- 实际落地内容只包含：
- `TrainerSequenceAnswerPolicy`
- `TrainerExerciseMode.sr1 / .sr2`
- `fixedSequenceAnswerPolicy`
- `usesQuarterNoteSequenceKernel`
- 以及为编译通过而必须补齐的 sequence-compatible `switch` 穷举分支
- 这次没有越界进入 `阶段 1`，因为 `answerPolicy` 还没有真正挂入 `TrainerSequenceConfiguration -> QuarterNoteSequenceSpec`
- 这次也没有越界进入 `阶段 5`，因为 settings 入口、scene 归一化、piano 输入桥都还没接

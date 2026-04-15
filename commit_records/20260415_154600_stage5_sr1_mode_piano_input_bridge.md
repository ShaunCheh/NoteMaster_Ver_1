# 20260415_154600_stage5_sr1_mode_piano_input_bridge

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_154600`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat`、按文件分组的 `git diff --unified=12`、当前文件内容，以及本轮 lint / build 验证结果整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 5”真实落地的代码改动；目标是把 `SR-1` mode 正式接通到 shared normalization、settings 可见性、iOS/macOS controller 以及 piano 答题输入桥接
- 重要说明：本轮部分文件在更早阶段已发生过结构演进，因此下文“修改前”代码块只还原与阶段 5 直接相关的局部上下文；还原口径以本轮 diff 命中的 symbol 和上下文为准
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`11 files changed, 304 insertions(+), 31 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 11 个 `Swift` 文件，因此本次统计口径直接等同于阶段 5 本轮改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `11 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`：阶段 5 先同步已有 root-tree 期望，不新增新的 validation fixture 聚合入口
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoSurfaceView.swift`：底层 preview 事件形状已够用，本轮不重写组件事件模型
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoSurfaceView.swift`：同上，继续透传 previewStarted / previewChanged / previewEnded
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`：阶段 4 已经接通 `staffToPiano` scene，本轮重点是 mode 归一化与 controller 输入桥接，不再扩 blast radius
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`：阶段 4 已明确 `staffToPiano` 的 legacy fallback，本轮通过 mode 固定约束与 validation 改为 `sr1` 入口来消费既有语义
- 验证结果：
- `ReadLints`：对本轮 11 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`：构建通过
- 第一次并行触发的 `xcodebuild ... -destination "generic/platform=iOS Simulator" build` 因同一 `DerivedData` 上并发构建导致 `build.db` 锁冲突失败；失败原因为构建数据库锁，而不是代码编译错误
- 随后串行重跑 `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build`：构建通过
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr1判题分阶段_3443803b.plan.md`
- 没有创建额外文档，除本记录文件外不新增其它 markdown
- 没有提交代码

## 本次结论

- `SR-1` 已作为正式 exercise mode 暴露到 settings，且选中态、标题、写回路径已接通
- `SR-1` / `SR-2` 的固定约束已经收口到 shared 层：`staffToPiano + stacked + treble + 单行 piano + rowOnly`，并继续分别固定 `answerPolicy = .pitchClass / .exactNote`
- settings snapshot 已在 `SR-1` 下隐藏会被 normalization 强拉回的行：`compositionPreset`、`layoutPreset`、`accessoryPresentation`、accessory 三个 toggle、`clef`、`pianoRowCount`、`pianoMovementScope`
- iOS / macOS controller 中原先挂在 `isSequenceMode` 的关键 sequence guard 已迁到 `usesQuarterNoteSequenceKernel`
- piano preview 现在是双路：一路继续走 `playbackCoordinator`，一路在 `.piano` 作为 answer surface 时桥接为 `ExerciseAnswerEvent.notePitch(...)`
- `previewChanged` 已增加同音高去重缓存，`previewEnded` / interaction reset / playback interrupt 都会清理缓存
- `staffToPiano` 的 validation fixture 入口已从普通 `.single` 场景切到真实 `.sr1` 场景，避免测试语义和产品入口脱节

## 修改 1：把 SR-1 / SR-2 的固定约束收口到 shared 层

### 修改前

- `ExerciseLayoutPreferences` 没有可复用的 `SR` 固定布局常量
- `TrainerExerciseMode` 只有 `fixedSequenceAnswerPolicy`
- `TrainerSequenceConfiguration` 不会按 mode 再做一层 clef / policy 固定约束

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: struct ExerciseLayoutPreferences
// 功能说明: 修改前只有 default / legacyPositionPrompt / singleFretboardSelfAnswer；
// SR 模式还没有统一的固定 layout 常量。
struct ExerciseLayoutPreferences: Equatable, Sendable {
    // ... 省略未变字段 ...
    static let `default` = ExerciseLayoutPreferences()
    static let legacyPositionPrompt = ExerciseLayoutPreferences(
        compositionPreset: .fretboardToNaturalNoteStrip,
        layoutPreset: .sideBySide,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: true,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
    static let singleFretboardSelfAnswer = ExerciseLayoutPreferences(
        compositionPreset: .fretboardSelfAnswer,
        layoutPreset: .singleSurface,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
}
```

```swift
// NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: extension TrainerExerciseMode / extension TrainerSequenceConfiguration
// 功能说明: 修改前 shared 层只冻结了 SR 的 answerPolicy；
// clef、layout、piano rows、movementScope 仍散落在平台侧处理。
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

extension TrainerSequenceConfiguration {
    var quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
        FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals,
            answerPolicy: answerPolicy
        )
    }
}
```

### 修改后

- 新增 `ExerciseLayoutPreferences.srPianoAnswer`
- `TrainerExerciseMode` 新增 `fixedSequenceClef`、`fixedExerciseLayoutPreferences`、`fixedPianoRowCount`、`fixedPianoMovementScope`
- `TrainerSequenceConfiguration.applyingModeConstraints(...)` 与 `TrainerDisplayState.resolvedSequenceConfiguration` 把 SR 模式的 fixed constraints 统一投影成运行时配置

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: struct ExerciseLayoutPreferences.srPianoAnswer
// 功能说明: 修改后新增 SR 模式共用的固定布局常量；
// 后续 normalization 可以直接收口到 staffToPiano + stacked，而不是平台侧重复特判。
struct ExerciseLayoutPreferences: Equatable, Sendable {
    // ... 省略未变字段 ...
    static let srPianoAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToPiano,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
}
```

```swift
// NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: extension TrainerExerciseMode / extension TrainerSequenceConfiguration / extension TrainerDisplayState
// 功能说明: 修改后 SR 固定约束统一收口到 shared 模型；
// controller 只消费 resolvedSequenceConfiguration / fixed layout，不再各端各写一套 SR-1 参数钳制。
extension TrainerExerciseMode {
    var fixedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy? { /* ... 保持已有逻辑 ... */ }

    var fixedSequenceClef: StaffClef? {
        switch self {
        case .sr1, .sr2:
            return .treble
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }

    var fixedExerciseLayoutPreferences: ExerciseLayoutPreferences? {
        switch self {
        case .sr1, .sr2:
            return .srPianoAnswer
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }

    var fixedPianoRowCount: Int? {
        switch self {
        case .sr1, .sr2:
            return 1
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }

    var fixedPianoMovementScope: PianoMovementScope? {
        switch self {
        case .sr1, .sr2:
            return .rowOnly
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }
}

extension TrainerSequenceConfiguration {
    func applyingModeConstraints(
        _ exerciseMode: TrainerExerciseMode
    ) -> TrainerSequenceConfiguration {
        var normalized = self
        if let fixedClef = exerciseMode.fixedSequenceClef {
            normalized.clef = fixedClef
        }
        if let fixedAnswerPolicy = exerciseMode.fixedSequenceAnswerPolicy {
            normalized.answerPolicy = fixedAnswerPolicy
        }
        return normalized
    }
}

extension TrainerDisplayState {
    var resolvedSequenceConfiguration: TrainerSequenceConfiguration {
        sequenceConfiguration.applyingModeConstraints(exerciseMode)
    }
}
```

## 修改 2：让 normalization 真正把 SR-1 / SR-2 固定到 `staffToPiano`

### 修改前

- `normalizedPreferences(...)` 只是普通地规整 preset / layout
- `single / sequence / sr1 / sr2` 都被视为同一组 preset 支持范围
- `normalizedCompositionPreset(...)` 在不支持时统一回退到 `.staffToFretboard`

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: static func normalizedPreferences(_:trainerDisplayState:) / isCompositionPresetSupported(_:for:) / normalizedCompositionPreset(_:for:)
// 功能说明: 修改前 SR 模式虽然在枚举里存在，但没有真正把 staffToPiano 固定成 mode 级约束；
// single / sequence 也会被视为支持 staffToPiano。
static func normalizedPreferences(
    _ preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> ExerciseLayoutPreferences {
    var normalized = preferences
    normalized.compositionPreset = normalizedCompositionPreset(
        normalized.compositionPreset,
        for: trainerDisplayState.exerciseMode
    )
    normalized.layoutPreset = normalizedLayoutPreset(
        normalized.layoutPreset,
        for: normalized.compositionPreset
    )
    // ... 省略未变 accessory 归一化 ...
    return normalized
}

static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    switch exerciseMode {
    case .single, .sequence, .sr1, .sr2:
        switch preset {
        case .staffToFretboard, .staffToPiano, .targetPromptToFretboard:
            return true
        case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
            return false
        }
    case .positionPrompt:
        // ... 省略未变逻辑 ...
    }
}
```

### 修改后

- `sr1 / sr2` 进入 `normalizedPreferences(...)` 时直接优先覆盖为 `fixedExerciseLayoutPreferences`
- `single / sequence` 不再把 `staffToPiano` 视为正式支持 preset
- `sr1 / sr2` 的 fallback 统一回到 `.staffToPiano`，避免切出 SR 后再残留成“无 settings 选中项”的非法组合

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: static func normalizedPreferences(_:trainerDisplayState:) / isCompositionPresetSupported(_:for:) / normalizedCompositionPreset(_:for:)
// 功能说明: 修改后 SR-1 / SR-2 会先吃固定 layout 常量，再继续走 accessory 压平；
// 同时 single / sequence 与 SR 模式的 preset 支持矩阵被正式分开。
static func normalizedPreferences(
    _ preferences: ExerciseLayoutPreferences,
    trainerDisplayState: TrainerDisplayState
) -> ExerciseLayoutPreferences {
    var normalized = preferences
    if let fixedPreferences = trainerDisplayState.exerciseMode
        .fixedExerciseLayoutPreferences {
        normalized = fixedPreferences
    } else {
        normalized.compositionPreset = normalizedCompositionPreset(
            normalized.compositionPreset,
            for: trainerDisplayState.exerciseMode
        )
        normalized.layoutPreset = normalizedLayoutPreset(
            normalized.layoutPreset,
            for: normalized.compositionPreset
        )
    }

    if normalized.compositionPreset.usesMainPianoAnswerSurface {
        normalized.isPianoAccessoryVisible = false
    }
    return normalized
}

static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    switch exerciseMode {
    case .single, .sequence:
        switch preset {
        case .staffToFretboard, .targetPromptToFretboard:
            return true
        case .staffToPiano, .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
            return false
        }
    case .sr1, .sr2:
        return preset == .staffToPiano
    case .positionPrompt:
        // ... 省略未变逻辑 ...
        return false
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
        case .sr1, .sr2:
            return .staffToPiano
        case .positionPrompt:
            return .fretboardToNaturalNoteStrip
        }
    }
    return preset
}
```

## 修改 3：在 settings 中正式开放 `SR-1` mode

### 修改前

- `SettingsChoiceRowID.exerciseMode` 只有 `Single / Sequence / Position`
- `SettingsActionID` 没有 `setExerciseModeSr1`
- 选中态、标题、accessibility label 和 `TrainerDisplayState` 写回路径也都没有 `sr1`

```swift
// NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / enum SettingsActionID / SettingsActionID.isSelected(...) / SettingsActionID.apply(to: inout TrainerDisplayState)
// 功能说明: 修改前 Exercise Mode 行只能切 single / sequence / position；
// settings 面板还没有 SR-1 的 action、标题、选中态和写回路径。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModePositionPrompt
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setRootModeExercise
    case setRootModePlay
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModePositionPrompt
    // ... 省略未变 action ...
}

case .setExerciseModeSingle:
    return stateContext.trainerDisplayState.exerciseMode == .single
case .setExerciseModeSequence:
    return stateContext.trainerDisplayState.exerciseMode == .sequence
case .setExerciseModePositionPrompt:
    return stateContext.trainerDisplayState.exerciseMode == .positionPrompt

case .setExerciseModeSingle:
    displayState.setExerciseMode(.single)
case .setExerciseModeSequence:
    displayState.setExerciseMode(.sequence)
case .setExerciseModePositionPrompt:
    displayState.setExerciseMode(.positionPrompt)
```

### 修改后

- 新增 `setExerciseModeSr1`
- `Exercise Mode` 行正式变成 `Single / Sequence / SR-1 / Position`
- 标题、accessibility、选中态、`TrainerDisplayState` 写回路径全部补齐
- 其余 `switch` 的穷举分支也同步纳入 `setExerciseModeSr1`，避免遗漏

```swift
// NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs / enum SettingsActionID / SettingsActionID.isSelected(...) / SettingsActionID.apply(to: inout TrainerDisplayState)
// 功能说明: 修改后 SettingsPanelModel 已正式暴露 SR-1 入口；
// Exercise Mode 的 UI 选择、选中态和状态写回都统一经过共享 action。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeSr1,
        .setExerciseModePositionPrompt
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setRootModeExercise
    case setRootModePlay
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModeSr1
    case setExerciseModePositionPrompt
    // ... 省略未变 action ...
}

case .setExerciseModeSr1:
    return "SR-1"

case .setExerciseModeSr1:
    return "Train treble staff reading with a single-row piano answer surface"

case .setExerciseModeSr1:
    return stateContext.trainerDisplayState.exerciseMode == .sr1

case .setExerciseModeSr1:
    displayState.setExerciseMode(.sr1)
```

## 修改 4：在 settings snapshot / navigation 中隐藏 SR-1 下的无效项，并同步导航文案

### 修改前

- `SettingsPanelSnapshotBuilder` 对 toggle 没有单独的 `shouldInclude(...)`
- `compositionPreset`、`layoutPreset`、`accessoryPresentation`、`pianoRowCount`、`pianoMovementScope`、accessory toggle、`clef` 在任何 mode 下都会继续显示
- `Exercise > Mode` 导航副标题仍是 `"Single, sequence, or position"`

```swift
// NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: makeRow(id:stateContext:) / shouldInclude(choiceRowID:stateContext:) / shouldInclude(sliderID:stateContext:)
// 功能说明: 修改前 snapshot builder 只对 choice / slider / positionFilter 做显隐；
// SR-1 下会被 normalization 强拉回的行仍会继续显示。
case let .toggle(toggleID):
    return .toggle(
        makeToggleRow(
            id: toggleID,
            stateContext: stateContext
        )
    )

private static func shouldInclude(
    choiceRowID: SettingsChoiceRowID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch choiceRowID {
    case .positionPromptFilterMode:
        return stateContext.trainerDisplayState.isPositionPromptMode
    default:
        return true
    }
}

private static func shouldInclude(
    sliderID: SettingsSliderID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch sliderID {
    case .verticalHostHeightRatio:
        return stateContext.showsVerticalViewportHeightControl
    case .pianoRowCount:
        return true
    case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
        return true
    }
}
```

```swift
// NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: private static func childPageSpecs(for:)
// 功能说明: 修改前 Exercise > Mode 的导航副标题还没有 SR-1。
ChildPageSpec(
    route: .exerciseMode,
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, or position",
    rowIDs: [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses)
    ]
)
```

### 修改后

- `SettingsPanelSnapshotBuilder` 为 toggle 新增 `shouldInclude(...)`
- SR 固定场景下会隐藏：
- `compositionPreset`
- `layoutPreset`
- `accessoryPresentation`
- `naturalStripVisible`
- `pianoAccessoryVisible`
- `accessoryExpanded`
- `clef`
- `pianoRowCount`
- `pianoMovementScope`
- 导航副标题与 root-tree validation 期望一并改成 `"Single, sequence, SR-1, or position"`

```swift
// NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: makeRow(id:stateContext:) / shouldInclude(choiceRowID:stateContext:) / shouldInclude(sliderID:stateContext:) / shouldInclude(toggleID:stateContext:)
// 功能说明: 修改后 SR 固定 presentation mode 下会直接隐藏会被 normalization 强拉回的设置项；
// 导航树和面板快照都会基于同一份 panel model 自动同步裁剪。
case let .toggle(toggleID):
    guard shouldInclude(
        toggleID: toggleID,
        stateContext: stateContext
    ) else {
        return nil
    }
    return .toggle(
        makeToggleRow(
            id: toggleID,
            stateContext: stateContext
        )
    )

private static func shouldInclude(
    choiceRowID: SettingsChoiceRowID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch choiceRowID {
    case .compositionPreset,
         .layoutPreset,
         .accessoryPresentation:
        return !hasFixedExercisePresentationMode(stateContext)
    case .positionPromptFilterMode:
        return stateContext.trainerDisplayState.isPositionPromptMode
    case .clef:
        return stateContext.trainerDisplayState.exerciseMode
            .fixedSequenceClef == nil
    case .pianoMovementScope:
        return stateContext.trainerDisplayState.exerciseMode
            .fixedPianoMovementScope == nil
    default:
        return true
    }
}

private static func shouldInclude(
    sliderID: SettingsSliderID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch sliderID {
    case .verticalHostHeightRatio:
        return stateContext.showsVerticalViewportHeightControl
    case .pianoRowCount:
        return stateContext.trainerDisplayState.exerciseMode
            .fixedPianoRowCount == nil
    case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
        return true
    }
}

private static func shouldInclude(
    toggleID: SettingsToggleID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch toggleID {
    case .naturalStripVisible,
         .pianoAccessoryVisible,
         .accessoryExpanded:
        return !hasFixedExercisePresentationMode(stateContext)
    case .showsComponentBounds,
         .showsSideBySideContainerOutlines,
         .pianoSnapEnabled:
        return true
    }
}
```

```swift
// NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: private static func childPageSpecs(for:)
// 功能说明: 修改后导航文案与新增的 SR-1 mode 保持一致。
ChildPageSpec(
    route: .exerciseMode,
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, SR-1, or position",
    rowIDs: [
        .choice(.exerciseMode),
        .positionFilter(.positionQuestionPitchClasses)
    ]
)
```

```swift
// NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名/符号: validateSplitSectionsProduceExpectedPageTree()
// 功能说明: 修改后 root-tree validation 的期望副标题同步改成带 SR-1 的版本；
// 避免共享导航树和验证文案发生漂移。
SettingsRouteItem(
    title: SettingsRouteID.exerciseMode.fallbackTitle,
    subtitle: "Single, sequence, SR-1, or position",
    route: .exerciseMode
)
```

## 修改 5：iOS controller 把 SR-1 正式接到 sequence kernel 和 piano 答题桥

### 修改前

- `baseStaffDisplayState`、staff hidden transition、regenerate 按钮、手动 regenerate、settings diff 等仍挂在 `isSequenceMode`
- `configuredQuarterNoteSequenceSpec` 直接吃 `sequenceConfiguration`
- `applyPianoAccessoryState()` 直接使用 `pianoPanelState.settingsSlice`
- `handlePianoSemanticEvent(...)` 只做 playback，不会产生答题事件
- `.piano` 的交互状态没有纳入 `updateAnswerSurfaceInteractionState()`

```swift
// NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: staffDisplayState.didSet / configuredQuarterNoteSequenceSpec / updateAnswerSurfaceInteractionState() / applySequenceRegenerateButtonState() / regenerateQuarterNoteSequence(reason:) / applyPianoAccessoryState() / handlePianoSemanticEvent(_:)
// 功能说明: 修改前 iOS controller 仍按旧 sequence UI 语义工作；
// piano preview 事件只会驱动 playback，不会进入 exercise answer router。
if !trainerDisplayState.isSequenceMode {
    baseStaffDisplayState = staffDisplayState
}

private var configuredQuarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
    trainerDisplayState.sequenceConfiguration.quarterNoteSequenceSpec
}

private func updateAnswerSurfaceInteractionState() {
    let fretboardInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .fretboard)
        .isInteractionEnabled
    let naturalNoteStripInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .naturalNoteStrip)
        .isInteractionEnabled

    fretboardView.isUserInteractionEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.isUserInteractionEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
}

private func applySequenceRegenerateButtonState() {
    sequenceRegenerateButton.isHidden = !trainerDisplayState.isSequenceMode
}

private func regenerateQuarterNoteSequence(reason: String) {
    guard trainerDisplayState.isSequenceMode else {
        return
    }
    // ...
}

private func applyPianoAccessoryState() {
    pianoSurfaceView.applySharedSettings(
        pianoPanelState.settingsSlice
    )
}

private func handlePianoSemanticEvent(_ event: PianoSemanticEvent) {
    playbackCoordinator?.handle(event)
}
```

### 修改后

- iOS 端所有关键 sequence guard 改为 `usesQuarterNoteSequenceKernel`
- `configuredQuarterNoteSequenceSpec` 改用 `resolvedSequenceConfiguration`
- 新增 `resolvedPianoSettingsSlice`，让 SR 模式单行 `piano` / `rowOnly` 也从 controller 统一落地到 surface
- 新增 `canRoutePianoPreviewAnswers`、`lastPianoAnswerNotesByPreviewID`、`routePianoPreviewAnswerIfNeeded(...)`
- `previewStarted` 立即桥接答题，`previewChanged` 只在音高变化时桥接，`previewEnded` / reset / interrupt 会清缓存
- `.piano` surface 的 interaction enable/disable 正式接入 `updateAnswerSurfaceInteractionState()`

```swift
// NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: staffDisplayState.didSet / configuredQuarterNoteSequenceSpec / resolvedPianoSettingsSlice / canRoutePianoPreviewAnswers / updateAnswerSurfaceInteractionState() / applyPianoAccessoryState() / handlePianoSemanticEvent(_:) / routePianoPreviewAnswerIfNeeded(_:shouldEmitDuplicateNote:)
// 功能说明: 修改后 iOS controller 已把 SR-1 接到 shared sequence kernel，
// 同时把 piano preview 事件拆成“播放反馈 + 答题事件”双路，并给 previewChanged 增加同音高去重。
if !trainerDisplayState.usesQuarterNoteSequenceKernel {
    baseStaffDisplayState = staffDisplayState
}

private var configuredQuarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
    trainerDisplayState.resolvedSequenceConfiguration.quarterNoteSequenceSpec
}

private var resolvedPianoSettingsSlice: PianoPanelSettingsSlice {
    var settingsSlice = pianoPanelState.settingsSlice
    if let fixedRowCount = trainerDisplayState.exerciseMode.fixedPianoRowCount {
        settingsSlice.rowCount = fixedRowCount
    }
    if let fixedMovementScope = trainerDisplayState.exerciseMode.fixedPianoMovementScope {
        settingsSlice.movementScope = fixedMovementScope
    }
    return settingsSlice
}

private var canRoutePianoPreviewAnswers: Bool {
    let pianoSurfaceState = exercisePresentationState
        .effectiveSurfaceState(for: .piano)
    return trainerDisplayState.usesQuarterNoteSequenceKernel
        && pianoSurfaceState.isAnswerEnabled
        && pianoSurfaceState.isInteractionEnabled
}

private func updateAnswerSurfaceInteractionState() {
    let fretboardInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .fretboard)
        .isInteractionEnabled
    let naturalNoteStripInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .naturalNoteStrip)
        .isInteractionEnabled
    let pianoInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .piano)
        .isInteractionEnabled

    fretboardView.isUserInteractionEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.isUserInteractionEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
    if pianoSurfaceView.isPianoInteractionEnabled && !pianoInteractionEnabled {
        interruptActivePianoPlayback(reason: .interactionDisabled)
    }
    pianoSurfaceView.isPianoInteractionEnabled = pianoInteractionEnabled
}

private func applySequenceRegenerateButtonState() {
    sequenceRegenerateButton.isHidden = !trainerDisplayState
        .usesQuarterNoteSequenceKernel
}

private func regenerateQuarterNoteSequence(reason: String) {
    guard trainerDisplayState.usesQuarterNoteSequenceKernel else {
        return
    }
    // ...
}

private func applyPianoAccessoryState() {
    pianoSurfaceView.applySharedSettings(
        resolvedPianoSettingsSlice
    )
}

private func handlePianoSemanticEvent(_ event: PianoSemanticEvent) {
    playbackCoordinator?.handle(event)
    switch event {
    case .rowsChanged:
        return
    case let .previewStarted(preview):
        routePianoPreviewAnswerIfNeeded(preview, shouldEmitDuplicateNote: true)
    case let .previewChanged(preview):
        routePianoPreviewAnswerIfNeeded(preview, shouldEmitDuplicateNote: false)
    case let .previewEnded(preview):
        lastPianoAnswerNotesByPreviewID.removeValue(forKey: preview.previewID)
    }
}

private func routePianoPreviewAnswerIfNeeded(
    _ preview: PianoPreviewState,
    shouldEmitDuplicateNote: Bool
) {
    guard canRoutePianoPreviewAnswers else {
        return
    }

    let previousNote = lastPianoAnswerNotesByPreviewID[preview.previewID]
    if !shouldEmitDuplicateNote, previousNote == preview.note {
        return
    }

    lastPianoAnswerNotesByPreviewID[preview.previewID] = preview.note
    handleExerciseAnswerEvent(
        .notePitch(preview.note, from: .piano)
    )
}
```

## 修改 6：macOS controller 与 iOS 保持同构的 SR-1 输入桥和交互约束

### 修改前

- `invalidateStaffDisplayPresentation()`、staff hidden transition、regenerate 按钮、手动 regenerate、settings diff 仍依赖 `isSequenceMode`
- `applyPianoDemoState()` 直接吃 `pianoPanelState.settingsSlice`
- `handlePianoSemanticEvent(...)` 只走 playback
- `.piano` surface 没接进交互 enable/disable 状态机

```swift
// NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: invalidateStaffDisplayPresentation() / configuredQuarterNoteSequenceSpec / updateAnswerSurfaceInteractionState() / applySequenceRegenerateButtonState() / regenerateQuarterNoteSequence(reason:) / applyPianoDemoState() / handlePianoSemanticEvent(_:)
// 功能说明: 修改前 macOS 端和 iOS 一样，还没有把 SR-1 的 piano 输入桥接进答题管线。
if !trainerDisplayState.isSequenceMode {
    baseStaffDisplayState = staffDisplayState
}

private var configuredQuarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
    trainerDisplayState.sequenceConfiguration.quarterNoteSequenceSpec
}

private func updateAnswerSurfaceInteractionState() {
    let fretboardInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .fretboard)
        .isInteractionEnabled
    let naturalNoteStripInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .naturalNoteStrip)
        .isInteractionEnabled

    fretboardView.areRawEventsEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.areButtonsEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
}

private func applySequenceRegenerateButtonState() {
    sequenceRegenerateButton.isHidden = !trainerDisplayState.isSequenceMode
}

private func regenerateQuarterNoteSequence(reason: String) {
    guard trainerDisplayState.isSequenceMode else {
        return
    }
    // ...
}

private func applyPianoDemoState() {
    pianoSurfaceView.applySharedSettings(
        pianoPanelState.settingsSlice
    )
}

private func handlePianoSemanticEvent(_ event: PianoSemanticEvent) {
    playbackCoordinator?.handle(event)
}
```

### 修改后

- macOS 端与 iOS 一样把 sequence guard 统一切到 `usesQuarterNoteSequenceKernel`
- 通过 `resolvedPianoSettingsSlice` 统一落地单行 / `rowOnly`
- `.piano` surface 进入 `updateAnswerSurfaceInteractionState()`
- `previewStarted / previewChanged / previewEnded` 也正式桥接为答题事件并带缓存去重

```swift
// NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: invalidateStaffDisplayPresentation() / configuredQuarterNoteSequenceSpec / resolvedPianoSettingsSlice / canRoutePianoPreviewAnswers / updateAnswerSurfaceInteractionState() / applyPianoDemoState() / handlePianoSemanticEvent(_:) / routePianoPreviewAnswerIfNeeded(_:shouldEmitDuplicateNote:)
// 功能说明: 修改后 macOS controller 与 iOS 保持同一套 SR-1 语义：
// 继续保留 playback，另外按 surface role 把 piano preview 送进 exercise answer router。
if !trainerDisplayState.usesQuarterNoteSequenceKernel {
    baseStaffDisplayState = staffDisplayState
}

private var configuredQuarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
    trainerDisplayState.resolvedSequenceConfiguration.quarterNoteSequenceSpec
}

private var resolvedPianoSettingsSlice: PianoPanelSettingsSlice {
    var settingsSlice = pianoPanelState.settingsSlice
    if let fixedRowCount = trainerDisplayState.exerciseMode.fixedPianoRowCount {
        settingsSlice.rowCount = fixedRowCount
    }
    if let fixedMovementScope = trainerDisplayState.exerciseMode.fixedPianoMovementScope {
        settingsSlice.movementScope = fixedMovementScope
    }
    return settingsSlice
}

private var canRoutePianoPreviewAnswers: Bool {
    let pianoSurfaceState = exercisePresentationState
        .effectiveSurfaceState(for: .piano)
    return trainerDisplayState.usesQuarterNoteSequenceKernel
        && pianoSurfaceState.isAnswerEnabled
        && pianoSurfaceState.isInteractionEnabled
}

private func updateAnswerSurfaceInteractionState() {
    let fretboardInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .fretboard)
        .isInteractionEnabled
    let naturalNoteStripInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .naturalNoteStrip)
        .isInteractionEnabled
    let pianoInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .piano)
        .isInteractionEnabled

    fretboardView.areRawEventsEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.areButtonsEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
    if pianoSurfaceView.isPianoInteractionEnabled && !pianoInteractionEnabled {
        interruptActivePianoPlayback(reason: .interactionDisabled)
    }
    pianoSurfaceView.isPianoInteractionEnabled = pianoInteractionEnabled
}

private func applySequenceRegenerateButtonState() {
    sequenceRegenerateButton.isHidden = !trainerDisplayState
        .usesQuarterNoteSequenceKernel
}

private func regenerateQuarterNoteSequence(reason: String) {
    guard trainerDisplayState.usesQuarterNoteSequenceKernel else {
        return
    }
    // ...
}

private func applyPianoDemoState() {
    pianoSurfaceView.applySharedSettings(
        resolvedPianoSettingsSlice
    )
}

private func handlePianoSemanticEvent(_ event: PianoSemanticEvent) {
    playbackCoordinator?.handle(event)
    switch event {
    case .rowsChanged:
        return
    case let .previewStarted(preview):
        routePianoPreviewAnswerIfNeeded(preview, shouldEmitDuplicateNote: true)
    case let .previewChanged(preview):
        routePianoPreviewAnswerIfNeeded(preview, shouldEmitDuplicateNote: false)
    case let .previewEnded(preview):
        lastPianoAnswerNotesByPreviewID.removeValue(forKey: preview.previewID)
    }
}

private func routePianoPreviewAnswerIfNeeded(
    _ preview: PianoPreviewState,
    shouldEmitDuplicateNote: Bool
) {
    guard canRoutePianoPreviewAnswers else {
        return
    }

    let previousNote = lastPianoAnswerNotesByPreviewID[preview.previewID]
    if !shouldEmitDuplicateNote, previousNote == preview.note {
        return
    }

    lastPianoAnswerNotesByPreviewID[preview.previewID] = preview.note
    handleExerciseAnswerEvent(
        .notePitch(preview.note, from: .piano)
    )
}
```

## 修改 7：把 `staffToPiano` validation 的入口场景切到真实 `SR-1`

### 修改前

- 阶段 4 新增的 `staffToPiano` fixture 仍以 `.single` 构造 `trainerDisplayState`
- 这能覆盖 scene 结构，但还不是最终产品入口

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateStaffToPianoSkipsLegacyBackProjection()
// 功能说明: 修改前 validation 仍用 .single 作为 staffToPiano 的测试入口；
// 还没有把真实 SR-1 mode 语义纳入 policy fixture。
static func validateStaffToPianoSkipsLegacyBackProjection()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "staff_to_piano_skips_legacy_back_projection"
    var issues: [ExerciseCompositionValidationIssue] = []

    let trainerDisplayState = TrainerDisplayState(exerciseMode: .single)
    // ...
}
```

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validateStaffToPianoScenePromotesMainPianoAnswerSurface()
// 功能说明: 修改前 makePresentation(...) 的验证入口同样还是 .single。
let presentation = ExerciseCompositionPolicy.makePresentation(
    from: ExerciseCompositionPolicyInput(
        trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
        fretboardTrainerState: .init(),
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pianoPanelState: PianoPanelState(isVisible: true),
        layoutPreferences: ExerciseLayoutPreferences(
            compositionPreset: .staffToPiano,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: false,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: true
        )
    )
)
```

### 修改后

- 两个 fixture 都改为 `TrainerDisplayState(exerciseMode: .sr1)`
- 这样 validation 锁住的不再只是“某个 preset 能工作”，而是“真实 SR-1 入口下的 shared 合同能工作”

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateStaffToPianoSkipsLegacyBackProjection()
// 功能说明: 修改后 policy validation 直接走真实 SR-1 入口；
// 能同时验证 mode 固定约束和 staffToPiano / legacy fallback 的组合行为。
static func validateStaffToPianoSkipsLegacyBackProjection()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "staff_to_piano_skips_legacy_back_projection"
    var issues: [ExerciseCompositionValidationIssue] = []

    let trainerDisplayState = TrainerDisplayState(exerciseMode: .sr1)
    // ...
}
```

```swift
// NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validateStaffToPianoScenePromotesMainPianoAnswerSurface()
// 功能说明: 修改后 scene-core validation 里的 makePresentation(...) 也改成 SR-1；
// 这样 surface role、duplicate piano 防线和 mode normalization 是同一个入口面。
let presentation = ExerciseCompositionPolicy.makePresentation(
    from: ExerciseCompositionPolicyInput(
        trainerDisplayState: TrainerDisplayState(exerciseMode: .sr1),
        fretboardTrainerState: .init(),
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pianoPanelState: PianoPanelState(isVisible: true),
        layoutPreferences: ExerciseLayoutPreferences(
            compositionPreset: .staffToPiano,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: false,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: true
        )
    )
)
```

## 当前工作区状态

- 当前 `git status --short` 只包含上文列出的 11 个 `Swift` 文件
- 本记录文件已新增到 `commit_records/20260415_154600_stage5_sr1_mode_piano_input_bridge.md`
- 代码仍未提交

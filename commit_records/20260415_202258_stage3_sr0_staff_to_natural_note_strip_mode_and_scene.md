# 20260415_202258_stage3_sr0_staff_to_natural_note_strip_mode_and_scene

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_202258`
- 记录依据：基于当前工作区 `git status --short`、阶段 3 相关 11 个文件的 `git diff --stat`、按文件分组的 `git diff --unified=20`、当前文件内容，以及上一轮阶段 3 已完成的 `ReadLints` / `xcodebuild` 验证结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `.cursor/plans/sr0_双行strip_计划_632caead.plan.md` 实施阶段 3 的真实落地代码改动；目标是在 shared 层新增 `staff -> naturalNoteStrip` 组合，并把 `SR-0` 作为固定的 `treble + pitchClass + stacked staff+strip` 模式接入现有 presentation contract
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`11 files changed, 374 insertions(+), 17 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 11 个 `Swift` 文件，因此本次统计口径直接等同于阶段 3 改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `11 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`：阶段 3 不新增 `setExerciseModeSr0`，不提前进入 settings 入口改造
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`、`NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`：阶段 3 不处理 fixed-presentation 的隐藏规则，留到阶段 5
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`：本轮不改 legacy page model，本来就应让 `staff + naturalNoteStrip` 继续保持 `non-legacy`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`、`NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`：阶段 2 已完成双行 strip 视图，本轮不重复改平台视图
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`：阶段 3 不接 SR-0 判题 comparator，不改 sequence trainer 内核
- 验证结果：
- `ReadLints`：对本轮 11 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMasterSR0Stage3-mac-build" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" -derivedDataPath "/tmp/NoteMasterSR0Stage3-ios-build" build`：`BUILD SUCCEEDED`
- 本次没做的事情：
- 没有修改 `.cursor/plans/sr0_双行strip_计划_632caead.plan.md`
- 没有新增 settings 中的 `SR-0` 选择项、row/action 映射或 navigation route
- 没有把 `SR-0` 接入 `ExerciseAnswerRouter` 的 quarter-note sequence 判题链；目前只做了显式的阶段边界占位
- 没有补 runtime smoke、settings navigation validation、fretboard validation 或手工清单更新
- 没有提交代码

## 本次结论

- `ExerciseCompositionPreset` 现在新增了 `staffToNaturalNoteStrip`，并有对应的固定 layout 常量 `ExerciseLayoutPreferences.srNoteStripAnswer`
- `TrainerExerciseMode` 现在新增了 `sr0`，其 fixed contract 被锁定为 `treble + pitchClass + staffToNaturalNoteStrip + stacked`
- `ExerciseCompositionPolicy` / `ExerciseCompositionPolicy+Normalization` 现在可以稳定把 `SR-0` 归一化并投影成 `staffPrompt + naturalNoteStripAnswer` 主场景
- shared validation 新增了两类自动化断言：`SR-0` fixed mode seam、`staff -> naturalNoteStrip` 场景合同
- 为了让新增 enum case 保持编译与状态同步，本轮只做了最小兼容修补：controller 将 `sr0` 归到 quarter-note sequence 同步分支，`ExerciseAnswerRouter` 暂时对 `sr0` 显式忽略，等待阶段 4 正式接线

## 修改 1：新增 `SR-0` 的 shared preset 常量与 fixed mode 合同

### 修改前

- `ExerciseCompositionPreset` 只有 `staffToPiano`，没有 `staffToNaturalNoteStrip`
- `ExerciseLayoutPreferences` 只有 `srPianoAnswer`
- `TrainerExerciseMode` 只有 `sr1` / `sr2`
- fixed sequence answer policy / clef / layout 只为 `SR-1`、`SR-2` 生效

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: ExerciseCompositionPreset / ExerciseLayoutPreferences.srPianoAnswer / ExerciseCompositionPreset.usesMainNaturalNoteStripAnswerSurface
// 功能说明: 修改前 shared layout 层只有 `staffToPiano` 的 SR 固定组合；
// 还不存在 `staffToNaturalNoteStrip` 或 `srNoteStripAnswer`。
enum ExerciseCompositionPreset: String, CaseIterable, Equatable, Hashable, Sendable {
    case staffToFretboard
    case staffToPiano
    case targetPromptToFretboard
    case fretboardToNaturalNoteStrip
    case fretboardSelfAnswer
}

struct ExerciseLayoutPreferences: Equatable, Sendable {
    static let srPianoAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToPiano,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
}

extension ExerciseCompositionPreset {
    var usesMainNaturalNoteStripAnswerSurface: Bool {
        self == .fretboardToNaturalNoteStrip
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode / fixedSequenceAnswerPolicy / fixedSequenceClef / fixedExerciseLayoutPreferences / usesQuarterNoteSequenceKernel
// 功能说明: 修改前 `TrainerExerciseMode` 里还没有 `sr0`；
// fixed 合同只覆盖 `SR-1` 和 `SR-2`。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
    case sr1
    case sr2
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
}

extension TrainerDisplayState {
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

### 修改后

- `ExerciseCompositionPreset` 新增 `staffToNaturalNoteStrip`
- `ExerciseLayoutPreferences` 新增 `srNoteStripAnswer`
- `TrainerExerciseMode` 新增 `sr0`
- `SR-0` 被固定到 `pitchClass + treble + srNoteStripAnswer`
- `usesQuarterNoteSequenceKernel` 也显式纳入 `sr0`
- `SR-0` 不继承任何 piano 固定行数或 movement scope

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: ExerciseCompositionPreset / ExerciseLayoutPreferences.srNoteStripAnswer / ExerciseCompositionPreset.usesMainNaturalNoteStripAnswerSurface
// 功能说明: 修改后 shared layout 层正式具备 `staffToNaturalNoteStrip`；
// SR-0 的固定 layout 常量也被收口到这里。
enum ExerciseCompositionPreset: String, CaseIterable, Equatable, Hashable, Sendable {
    case staffToFretboard
    case staffToPiano
    case staffToNaturalNoteStrip
    case targetPromptToFretboard
    case fretboardToNaturalNoteStrip
    case fretboardSelfAnswer
}

struct ExerciseLayoutPreferences: Equatable, Sendable {
    static let srPianoAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToPiano,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
    static let srNoteStripAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToNaturalNoteStrip,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: true,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )
}

extension ExerciseCompositionPreset {
    var usesMainNaturalNoteStripAnswerSurface: Bool {
        self == .fretboardToNaturalNoteStrip
            || self == .staffToNaturalNoteStrip
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode / fixedSequenceAnswerPolicy / fixedSequenceClef / fixedExerciseLayoutPreferences / usesQuarterNoteSequenceKernel
// 功能说明: 修改后 `TrainerExerciseMode` 增加 `sr0`；
// 其 shared fixed contract 明确冻结为 `treble + pitchClass + srNoteStripAnswer`。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
    case sr0
    case sr1
    case sr2
}

extension TrainerExerciseMode {
    var fixedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy? {
        switch self {
        case .sr0, .sr1:
            return .pitchClass
        case .sr2:
            return .exactNote
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }

    var fixedSequenceClef: StaffClef? {
        switch self {
        case .sr0, .sr1, .sr2:
            return .treble
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }

    var fixedExerciseLayoutPreferences: ExerciseLayoutPreferences? {
        switch self {
        case .sr0:
            return .srNoteStripAnswer
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
        case .single, .sequence, .positionPrompt, .sr0:
            return nil
        }
    }

    var fixedPianoMovementScope: PianoMovementScope? {
        switch self {
        case .sr1, .sr2:
            return .rowOnly
        case .single, .sequence, .positionPrompt, .sr0:
            return nil
        }
    }
}

extension TrainerDisplayState {
    var usesQuarterNoteSequenceKernel: Bool {
        switch exerciseMode {
        case .sequence, .sr0, .sr1, .sr2:
            return true
        case .single, .positionPrompt:
            return false
        }
    }
}
```

## 修改 2：把 `staff -> naturalNoteStrip` 接入 shared composition / normalization

### 修改前

- `resolvedSceneSurfaces(for:)` 不认识 `staffToNaturalNoteStrip`
- `makeSideBySideSceneNode(...)` 只有 `fretboardToNaturalNoteStrip` 会走右侧 `verticalRail`
- normalization 层没有 `sr0`，也没有 `staffToNaturalNoteStrip`
- legacy 兼容路径只知道 `single / sequence / sr1 / sr2`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.resolvedSceneSurfaces / makeSideBySideSceneNode / fallbackLegacyCompatiblePreferences / legacyCompatibleTrainerDisplayState
// 功能说明: 修改前 scene builder 还不能生成 `staff + natural note strip`；
// fixed SR fallback 也只处理 `SR-1 / SR-2`。
private static func resolvedSceneSurfaces(
    for preferences: ExerciseLayoutPreferences
) -> (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode) {
    switch preferences.compositionPreset {
    case .staffToFretboard:
        return (.staffPrompt, .fretboardAnswer)
    case .staffToPiano:
        return (.staffPrompt, .pianoAnswer)
    case .targetPromptToFretboard:
        return (.targetPrompt, .fretboardAnswer)
    case .fretboardToNaturalNoteStrip:
        return (.fretboardPrompt, .naturalNoteStripAnswer)
    case .fretboardSelfAnswer:
        return (.fretboardPromptAndAnswer, .fretboardPromptAndAnswer)
    }
}

private static func makeSideBySideSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    switch preferences.compositionPreset {
    case .fretboardToNaturalNoteStrip:
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(node: .surface(sceneSurfaces.prompt), mainAxisSizing: .weighted(1)),
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.answer.withPresentationStyle(.verticalRail)),
                    mainAxisSizing: .fitContent
                )
            ]
        )
    // ... 省略未变 case：`.staffToFretboard` / `.staffToPiano` / `.targetPromptToFretboard`
    //     继续保持左右双 weighted 的 horizontal split；
    //     `.fretboardSelfAnswer` 继续保持单 surface ...
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: isCompositionPresetSupported / normalizedCompositionPreset / normalizedLayoutPreset / isLayoutPresetSupported
// 功能说明: 修改前 normalization 没有 `sr0` 分支；
// `staffToNaturalNoteStrip` 也不在 supported preset / layout matrix 里。
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
        switch preset {
        case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
            return true
        case .staffToFretboard, .staffToPiano, .targetPromptToFretboard:
            return false
        }
    }
}

private static func normalizedCompositionPreset(
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

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: inferredPreferences / fallbackPageDisplayState
// 功能说明: 修改前 legacy bridge 的 exerciseMode 分组里还没有 `sr0`。
switch trainerDisplayState.exerciseMode {
case .positionPrompt:
    inferredCompositionPreset = .fretboardToNaturalNoteStrip
case .single, .sequence, .sr1, .sr2:
    // ... 保持既有逻辑 ...
    inferredCompositionPreset = .staffToFretboard
}

private static func fallbackPageDisplayState(
    for exerciseMode: TrainerExerciseMode
) -> PageDisplayState {
    switch exerciseMode {
    case .single, .sequence, .sr1, .sr2:
        return .default
    case .positionPrompt:
        return .positionPrompt
    }
}
```

### 修改后

- `ExerciseCompositionPolicy` 现在可以直接生成 `staffPrompt + naturalNoteStripAnswer`
- `staffToNaturalNoteStrip` 在 `sideBySide` 下也与 `fretboardToNaturalNoteStrip` 一样，会把 answer surface 投影成右侧 `verticalRail`
- normalization 明确把 `sr0` 限定为 `staffToNaturalNoteStrip`
- legacy bridge 与 explicit legacy fallback 只做最小兼容：把 `sr0` 纳入与其他 sequence 类模式同组的 fallback 处理，不提前做 settings/route 改造

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.resolvedSceneSurfaces / makeSideBySideSceneNode / fallbackLegacyCompatiblePreferences / legacyCompatibleTrainerDisplayState
// 功能说明: 修改后 shared scene builder 能生成 `staff + natural note strip`；
// 同时保证 `sr0` 的 explicit legacy fallback 仍回退到 legacy 可表达的旧组合。
private static func resolvedSceneSurfaces(
    for preferences: ExerciseLayoutPreferences
) -> (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode) {
    switch preferences.compositionPreset {
    case .staffToFretboard:
        return (.staffPrompt, .fretboardAnswer)
    case .staffToPiano:
        return (.staffPrompt, .pianoAnswer)
    case .staffToNaturalNoteStrip:
        return (.staffPrompt, .naturalNoteStripAnswer)
    case .targetPromptToFretboard:
        return (.targetPrompt, .fretboardAnswer)
    case .fretboardToNaturalNoteStrip:
        return (.fretboardPrompt, .naturalNoteStripAnswer)
    case .fretboardSelfAnswer:
        return (.fretboardPromptAndAnswer, .fretboardPromptAndAnswer)
    }
}

private static func makeSideBySideSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    switch preferences.compositionPreset {
    case .fretboardToNaturalNoteStrip, .staffToNaturalNoteStrip:
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.prompt),
                    mainAxisSizing: .weighted(1)
                ),
                ExerciseSceneSplitChild(
                    node: .surface(
                        sceneSurfaces.answer.withPresentationStyle(.verticalRail)
                    ),
                    mainAxisSizing: .fitContent
                )
            ]
        )
    // ... 省略未变 case：`.staffToFretboard` / `.staffToPiano` / `.targetPromptToFretboard`
    //     继续保持左右双 weighted 的 horizontal split；
    //     `.fretboardSelfAnswer` 继续保持单 surface ...
    }
}

private static func fallbackLegacyCompatiblePreferences(
    for exerciseMode: TrainerExerciseMode,
    isPianoAccessoryVisible _: Bool
) -> ExerciseLayoutPreferences {
    switch exerciseMode {
    case .single, .sequence, .sr0, .sr1, .sr2:
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
}

private static func legacyCompatibleTrainerDisplayState(
    _ trainerDisplayState: TrainerDisplayState
) -> TrainerDisplayState {
    var legacyCompatibleState = trainerDisplayState
    switch legacyCompatibleState.exerciseMode {
    case .sr0, .sr1, .sr2:
        legacyCompatibleState.exerciseMode = .sequence
    case .single, .sequence, .positionPrompt:
        break
    }
    return legacyCompatibleState
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: isCompositionPresetSupported / normalizedCompositionPreset / normalizedLayoutPreset / isLayoutPresetSupported
// 功能说明: 修改后 `sr0` 进入 shared normalization matrix；
// `staffToNaturalNoteStrip` 也成为合法的 multi-surface preset。
static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    switch exerciseMode {
    case .single, .sequence:
        switch preset {
        case .staffToFretboard, .targetPromptToFretboard:
            return true
        case .staffToPiano,
             .staffToNaturalNoteStrip,
             .fretboardToNaturalNoteStrip,
             .fretboardSelfAnswer:
            return false
        }
    case .sr0:
        return preset == .staffToNaturalNoteStrip
    case .sr1, .sr2:
        return preset == .staffToPiano
    case .positionPrompt:
        switch preset {
        case .fretboardToNaturalNoteStrip, .fretboardSelfAnswer:
            return true
        case .staffToFretboard,
             .staffToPiano,
             .staffToNaturalNoteStrip,
             .targetPromptToFretboard:
            return false
        }
    }
}

private static func normalizedCompositionPreset(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> ExerciseCompositionPreset {
    guard isCompositionPresetSupported(preset, for: exerciseMode) else {
        switch exerciseMode {
        case .single, .sequence:
            return .staffToFretboard
        case .sr0:
            return .staffToNaturalNoteStrip
        case .sr1, .sr2:
            return .staffToPiano
        case .positionPrompt:
            return .fretboardToNaturalNoteStrip
        }
    }

    return preset
}

private static func normalizedLayoutPreset(
    _ preset: ExerciseLayoutPreset,
    for compositionPreset: ExerciseCompositionPreset
) -> ExerciseLayoutPreset {
    switch compositionPreset {
    case .staffToFretboard,
         .staffToPiano,
         .staffToNaturalNoteStrip,
         .targetPromptToFretboard,
         .fretboardToNaturalNoteStrip:
        return .stacked
    case .fretboardSelfAnswer:
        return .singleSurface
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名/符号: inferredPreferences / fallbackPageDisplayState
// 功能说明: 修改后 legacy bridge 先把 `sr0` 纳入旧 fallback 分组；
// 这只是阶段 3 的兼容修补，不等于阶段 5 的 settings 入口改造。
switch trainerDisplayState.exerciseMode {
case .positionPrompt:
    inferredCompositionPreset = .fretboardToNaturalNoteStrip
case .single, .sequence, .sr0, .sr1, .sr2:
    // ... 保持既有逻辑 ...
    inferredCompositionPreset = .staffToFretboard
}

private static func fallbackPageDisplayState(
    for exerciseMode: TrainerExerciseMode
) -> PageDisplayState {
    switch exerciseMode {
    case .single, .sequence, .sr0, .sr1, .sr2:
        return .default
    case .positionPrompt:
        return .positionPrompt
    }
}
```

## 修改 3：新增 `SR-0` 的 shared validation，并注册到 composition validation runner

### 修改前

- `ExerciseCompositionValidation.swift` 只注册了 `staff_to_piano_*` 与 `sr_modes_freeze_staff_to_piano_policy_contracts`
- 没有 `staff_to_natural_note_strip_*` fixture
- 没有 `sr0_mode_freezes_staff_to_natural_note_strip_policy_contracts`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.makeFixtures
// 功能说明: 修改前 validation runner 只登记了 `staffToPiano` 与 `SR-1 / SR-2` 的相关夹具；
// 还没有 SR-0 的 scene / mode 合同验证入口。
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_scene_promotes_main_piano_answer_surface",
    validate: validateStaffToPianoScenePromotesMainPianoAnswerSurface
),
ExerciseCompositionValidationFixture(
    name: "accessory_scene_nodes_follow_presentation_strategy",
    validate: validateAccessorySceneNodesFollowPresentationStrategy
),
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_skips_legacy_back_projection",
    validate: validateStaffToPianoSkipsLegacyBackProjection
),
ExerciseCompositionValidationFixture(
    name: "sr_modes_freeze_staff_to_piano_policy_contracts",
    validate: validateSRModesFreezeStaffToPianoPolicyContracts
)
```

### 修改后

- `ExerciseCompositionValidation.swift` 新增两个 fixture 注册
- `ExerciseCompositionValidationExercisePolicy.swift` 新增 `validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts()`
- `ExerciseCompositionValidationSceneCore.swift` 新增 `validateStaffToNaturalNoteStripScenePromotesMainNaturalNoteStripAnswerSurface()`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.makeFixtures
// 功能说明: 修改后 validation runner 正式把 SR-0 的 fixed mode seam 和 scene seam 纳入自动化矩阵。
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_scene_promotes_main_piano_answer_surface",
    validate: validateStaffToPianoScenePromotesMainPianoAnswerSurface
),
ExerciseCompositionValidationFixture(
    name: "staff_to_natural_note_strip_scene_promotes_main_natural_note_strip_answer_surface",
    validate:
        validateStaffToNaturalNoteStripScenePromotesMainNaturalNoteStripAnswerSurface
),
ExerciseCompositionValidationFixture(
    name: "accessory_scene_nodes_follow_presentation_strategy",
    validate: validateAccessorySceneNodesFollowPresentationStrategy
),
ExerciseCompositionValidationFixture(
    name: "staff_to_piano_skips_legacy_back_projection",
    validate: validateStaffToPianoSkipsLegacyBackProjection
),
ExerciseCompositionValidationFixture(
    name: "sr_modes_freeze_staff_to_piano_policy_contracts",
    validate: validateSRModesFreezeStaffToPianoPolicyContracts
),
ExerciseCompositionValidationFixture(
    name: "sr0_mode_freezes_staff_to_natural_note_strip_policy_contracts",
    validate:
        validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts
// 功能说明: 修改后新增 SR-0 fixed mode 夹具；
// 这里锁住 `treble + pitchClass + srNoteStripAnswer + usesQuarterNoteSequenceKernel`。
static func validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "sr0_mode_freezes_staff_to_natural_note_strip_policy_contracts"
    var issues: [ExerciseCompositionValidationIssue] = []
    let trainerDisplayState = TrainerDisplayState(
        exerciseMode: .sr0,
        sequenceConfiguration: TrainerSequenceConfiguration(
            clef: .bass,
            noteCount: 5,
            includesAccidentals: true,
            answerPolicy: .exactNote
        )
    )
    let requestedPreferences = ExerciseLayoutPreferences(
        compositionPreset: .targetPromptToFretboard,
        layoutPreset: .sideBySide,
        accessoryPresentation: .floating,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: true,
        isAccessoryExpanded: false
    )
    let resolvedSequenceConfiguration = trainerDisplayState
        .resolvedSequenceConfiguration
    let normalizedPreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            requestedPreferences,
            trainerDisplayState: trainerDisplayState
        )
    let normalizedLegacyPreferences = LegacyPageLayoutAdapter
        .normalizedPreferences(
            requestedPreferences,
            trainerDisplayState: trainerDisplayState
        )

    if !trainerDisplayState.usesQuarterNoteSequenceKernel {
        issues.append(issue(fixtureName, "SR-0 应继续复用 quarter-note sequence kernel，而不是退回 single/position prompt 路径。"))
    }
    if resolvedSequenceConfiguration.clef != .treble {
        issues.append(issue(fixtureName, "SR-0 的 resolvedSequenceConfiguration 应强制锁定 treble clef。"))
    }
    if resolvedSequenceConfiguration.answerPolicy != .pitchClass {
        issues.append(issue(fixtureName, "SR-0 的 resolvedSequenceConfiguration.answerPolicy 应固定为 .pitchClass。"))
    }
    if normalizedPreferences != .srNoteStripAnswer
        || normalizedLegacyPreferences != .srNoteStripAnswer {
        issues.append(issue(fixtureName, "SR-0 的 shared / legacy normalization 都应统一收敛到 `srNoteStripAnswer`。"))
    }
    if !ExerciseCompositionPolicy.isCompositionPresetSupported(
        .staffToNaturalNoteStrip,
        for: .sr0
    ) {
        issues.append(issue(fixtureName, "SR-0 应显式支持 `staffToNaturalNoteStrip` composition preset。"))
    }
    // ... 省略其余现态断言：非法 preset 暴露检查、piano 固定约束缺失检查等 ...
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validateStaffToNaturalNoteStripScenePromotesMainNaturalNoteStripAnswerSurface
// 功能说明: 修改后新增 `staff -> naturalNoteStrip` 主场景夹具；
// 它同时校验 raw scene 与 normalized presentation scene 的 surface 身份、presentation style 和 non-legacy 语义。
static func validateStaffToNaturalNoteStripScenePromotesMainNaturalNoteStripAnswerSurface()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "staff_to_natural_note_strip_scene_promotes_main_natural_note_strip_answer_surface"
    var issues: [ExerciseCompositionValidationIssue] = []

    let rawScene = ExerciseCompositionPolicy.makeScene(
        preferences: ExerciseLayoutPreferences(
            compositionPreset: .staffToNaturalNoteStrip,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: false,
            isAccessoryExpanded: true
        )
    )
    let rawSurfaceIDs = rawScene.surfaceNodes.map(\.id)
    let rawStripSurfaceCount = rawScene.surfaceNodes.filter {
        $0.id == .naturalNoteStrip
    }.count

    if rawSurfaceIDs.count != 2
        || Set(rawSurfaceIDs) != Set([.staff, .naturalNoteStrip]) {
        issues.append(issue(fixtureName, "`staffToNaturalNoteStrip` scene 应只保留主 `staff` 与主 `natural note strip`。"))
    }
    if ExerciseSceneValidator.legacyPageDisplayState(for: rawScene) != nil {
        issues.append(issue(fixtureName, "`staffToNaturalNoteStrip` 的 raw scene 应被视为 non-legacy 新场景，而不是回投影成旧 page 结构。"))
    }
    if rawStripSurfaceCount != 1 {
        issues.append(issue(fixtureName, "`staffToNaturalNoteStrip` 的 raw scene 里只允许存在一个逻辑 `.naturalNoteStrip` surface。"))
    }

    let presentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: TrainerDisplayState(exerciseMode: .sr0),
            fretboardTrainerState: .init(),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: PianoPanelState(isVisible: true),
            layoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .targetPromptToFretboard,
                layoutPreset: .sideBySide,
                accessoryPresentation: .floating,
                isNaturalNoteStripVisible: false,
                isPianoAccessoryVisible: true,
                isAccessoryExpanded: false
            )
        )
    )
    if presentation.resolvedLayoutPreferences != .srNoteStripAnswer {
        issues.append(issue(fixtureName, "SR-0 的 makePresentation 应固定收敛到 `srNoteStripAnswer`。"))
    }
    if presentation.projectedSurfaceState(for: .staff) != .promptOnly
        || presentation.projectedSurfaceState(for: .naturalNoteStrip) != .answerOnly {
        issues.append(issue(fixtureName, "`staffToNaturalNoteStrip` 的最终 presentation 应保持 staff=promptOnly、naturalNoteStrip=answerOnly。"))
    }
    if presentation.containsSurface(.fretboard)
        || presentation.containsSurface(.piano) {
        issues.append(issue(fixtureName, "`staffToNaturalNoteStrip` scene 不应混入 `fretboard` 或 `piano`。"))
    }
    // ... 省略其余现态断言：vertical split 结构、fitContent sizing、horizontalStrip style、non-legacy state 等 ...
    return issues
}
```

## 修改 4：为新增 `sr0` 做最小兼容修补，但不提前进入阶段 4 / 5

### 修改前

- `ExerciseAnswerRouter` 没有 `sr0` debugName，也没有 `sr0` 分支
- 双端 controller 只把 `.sequence / .sr1 / .sr2` 归到 quarter-note sequence presentation 同步分支

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: ExerciseAnswerRouteIgnoreReason.debugName / ExerciseAnswerRouter.route
// 功能说明: 修改前 answer router 不认识 `sr0`；
// 新增 mode 后如果不补分支，会直接卡在 enum 穷举和调试输出上。
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
    // ... 保持既有逻辑 ...
    return .routed(.singleCoverage(event: event, cell: cell))
case .sequence, .sr1, .sr2:
    // ... 保持既有逻辑 ...
    return .routed(.quarterNoteSequence(event: event, answer: answer))
case .positionPrompt:
    // ... 省略未变逻辑：继续解析 positionPrompt 的 pitchClass
    //     并路由到 `.positionPrompt(...)` ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: iOSViewController.synchronizeTrainerPresentationState
// 功能说明: 修改前 iOS controller 只把 `.sequence / .sr1 / .sr2` 归到统一 sequence 展示同步分支。
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

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: macOSViewController.synchronizeTrainerPresentationState
// 功能说明: 修改前 macOS controller 也只把 `.sequence / .sr1 / .sr2` 归到统一 sequence 展示同步分支。
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

### 修改后

- `ExerciseAnswerRouter` 现在显式认识 `sr0`
- 但为了遵守阶段边界，本轮没有把 `sr0` 提前并入 `.quarterNoteSequence(...)`，而是显式返回 `.ignored(.unsupportedPayload(...))`
- 双端 controller 现在都把 `.sr0` 纳入 quarter-note sequence 展示同步分支，使 mode 切换、sequence prompt 投影和 scene 刷新先能走通

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名/符号: ExerciseAnswerRouteIgnoreReason.debugName / ExerciseAnswerRouter.route
// 功能说明: 修改后 answer router 显式认识 `sr0`；
// 但阶段 3 只做边界占位，不提前抢跑阶段 4 的 sequence 判题接线。
private func debugName(for mode: TrainerExerciseMode) -> String {
    switch mode {
    case .single:
        return "single"
    case .sequence:
        return "sequence"
    case .positionPrompt:
        return "positionPrompt"
    case .sr0:
        return "sr0"
    case .sr1:
        return "sr1"
    case .sr2:
        return "sr2"
    }
}

switch trainerDisplayState.exerciseMode {
case .single:
    // ... 保持既有逻辑 ...
    return .routed(.singleCoverage(event: event, cell: cell))
case .sequence, .sr1, .sr2:
    // ... 保持既有逻辑 ...
    return .routed(.quarterNoteSequence(event: event, answer: answer))
case .sr0:
    return .ignored(
        .unsupportedPayload(
            event.payload,
            trainerDisplayState.exerciseMode
        )
    )
case .positionPrompt:
    // ... 省略未变逻辑：继续解析 positionPrompt 的 pitchClass
    //     并路由到 `.positionPrompt(...)` ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: iOSViewController.synchronizeTrainerPresentationState
// 功能说明: 修改后 iOS controller 会把 `sr0` 纳入统一 quarter-note sequence 展示同步分支；
// 这一步只处理 prompt/projection 同步，不代表判题链已经接好。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence, .sr0, .sr1, .sr2:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: macOSViewController.synchronizeTrainerPresentationState
// 功能说明: 修改后 macOS controller 与 iOS 一样，把 `sr0` 归到统一 sequence 展示同步分支。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence, .sr0, .sr1, .sr2:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizePositionPromptPresentation(reason: reason)
    }
}
```

## 结果对照

- shared mode 层：现在已经有 `TrainerExerciseMode.sr0`
- shared layout 层：现在已经有 `ExerciseCompositionPreset.staffToNaturalNoteStrip` 和 `ExerciseLayoutPreferences.srNoteStripAnswer`
- shared scene 层：现在已经能稳定生成 `staffPrompt + naturalNoteStripAnswer`
- shared normalization 层：现在会把 `SR-0` 强制收敛到固定 preset，而不是允许自由组合漂移
- shared validation 层：现在已把 `SR-0` 的 fixed policy 与 `staff + strip` 场景合同写成自动化夹具
- 阶段边界：`ExerciseAnswerRouter` 对 `sr0` 当前仍显式忽略，这是本轮刻意保留的未完成口，等待阶段 4 正式接入 sequence 答题链

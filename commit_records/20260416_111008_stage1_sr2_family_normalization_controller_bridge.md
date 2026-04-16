# 20260416_111008_stage1_sr2_family_normalization_controller_bridge

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260416_111008`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat -- ...`、按文件 `git diff -- ...`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` / `startup-validation` / `SR-0` / `SR-1` smoke 结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md` 实施阶段 1 的真实落地代码改动；目标是把阶段 0 冻结好的 `SRPianoReadingFamily` 合同继续接入 `normalization`、`ExerciseCompositionPolicy` 和双端 controller 共享链路
- 重要说明：
- 本轮是“在阶段 0 的 family contract 基础上继续接线”，不是开启阶段 2；因此 `SR-2` 当前仍保持 `exactNote + 1 row + rowOnly`，尚未切到 `2 rows`
- 本轮第一次构建失败的真实原因不是架构设计错误，而是我在 `ExerciseCompositionValidationExercisePolicy.swift` 的测试夹具里误用了不存在的 `PianoWhiteKeyStyle.gapOnly`；工程里的真实枚举值是 `.borderlessSeparatedByGaps`，修正后双平台构建与回归全部通过
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`6 files changed, 162 insertions(+), 68 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 6 个 `Swift` 文件，因此本次统计口径直接等同于阶段 1 改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `6 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次确认但未修改的关键文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- 阶段 0 已经把 family contract 与 `FretboardValidation` seam 收口到位；本轮通过启动验证链与既有 smoke 复跑确认，没有新增代码改动
- 验证结果：
- `ReadLints`：对本轮 6 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage1_mac" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage1_ios" build`：`BUILD SUCCEEDED`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：macOS 运行结果为 `PASS scenario=startup_validation`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：iOS Simulator 运行结果为 `PASS scenario=startup_validation`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer`：macOS 运行结果为 `PASS scenario=sr0_note_strip_answer finalMode=single stripVisible=true`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer`：iOS Simulator 运行结果为 `PASS scenario=sr0_note_strip_answer finalMode=single stripVisible=true`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：macOS 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：iOS Simulator 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- `ExerciseCompositionValidation` 在 iOS / macOS 启动验证链里均为 `automated=PASS`，其中 `sr_modes_freeze_staff_to_piano_policy_contracts` 夹具都为 `issues=0`
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md`
- 没有开放 `SR-2` 的 settings / navigation 入口
- 没有把 `SR-2` 的 `fixedPianoRowCount` 改成 `2`
- 没有新增 `SR-2` runtime smoke
- 没有修改任何 `.md` 计划文件或旧记录文件
- 没有提交代码

## 本次结论

- `TrainerDisplayState` 现在不仅提供阶段 0 的 `srPianoReadingContract`，还补齐了 `fixedCompositionPreset`、`allowsAccessoryPianoPromotion`、`exerciseMode.usesQuarterNoteSequenceKernel`、`applyingFixedPianoSettings(...)`、`resolvedPianoSettingsSlice(...)` 等共享 helper
- `ExerciseCompositionPolicy+Normalization` 与 `ExerciseCompositionPolicy` 不再各自手搓 `sr1/sr2` 的 preset / piano promotion / legacy fallback 规则，而是直接消费这些 helper
- iOS / macOS controller 不再手写“`fixedPianoRowCount + fixedPianoMovementScope` 拼 settings slice”和“`case .sequence, .sr0, .sr1, .sr2` 走 quarterNoteSequence”这类分支，而是统一通过 `TrainerDisplayState` 的共享入口完成
- 当前产品行为保持不变：`SR-1` 仍是 `pitchClass + 1 row + rowOnly`，`SR-2` 仍是 `exactNote + 1 row + rowOnly`

## 修改 1：在 `TrainerDisplayState` 补齐供 policy / normalization / controller 复用的 family helper

### 修改前

- 阶段 0 虽然已经有 `srPianoReadingContract`
- 但 `fixedCompositionPreset`、accessory piano promotion 开关、以及 piano settings slice 的应用方式仍然散落在其它层自己推导

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode.srPianoReadingContract / TrainerDisplayState.usesQuarterNoteSequenceKernel
// 功能说明: 阶段1修改前，shared 层只有 contract 本身；
// 其它层还没有可直接复用的 composition / accessory / piano settings helper。
extension TrainerExerciseMode {
    var srPianoReadingContract: TrainerSRPianoReadingContract? {
        srPianoReadingMode?.contract
    }

    var fixedPianoRowCount: Int? {
        switch self {
        case .sr1, .sr2:
            return srPianoReadingContract?.fixedPianoRowCount
        case .single, .sequence, .positionPrompt, .sr0:
            return nil
        }
    }
}

extension TrainerDisplayState {
    var usesQuarterNoteSequenceKernel: Bool {
        exerciseMode.usesQuarterNoteSequenceKernel
    }
}
```

### 修改后

- 新增 `fixedCompositionPreset`
- 新增 `allowsAccessoryPianoPromotion`
- 把 `usesQuarterNoteSequenceKernel` 下沉到 `TrainerExerciseMode`
- 新增 `applyingFixedPianoSettings(...)` 与 `resolvedPianoSettingsSlice(...)`
- 这样后面 `normalization / policy / controller` 都可以从共享层直接拿到一致结果

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode.fixedCompositionPreset / allowsAccessoryPianoPromotion / applyingFixedPianoSettings(to:) / TrainerDisplayState.resolvedPianoSettingsSlice(from:)
// 功能说明: 修改后 family contract 的共享消费入口都集中在 TrainerDisplayState 一侧，
// 其它层不需要再手写 `SR-1 / SR-2` 的 preset、piano settings 和 accessory promotion 规则。
extension TrainerExerciseMode {
    var fixedCompositionPreset: ExerciseCompositionPreset? {
        fixedExerciseLayoutPreferences?.compositionPreset
    }

    var allowsAccessoryPianoPromotion: Bool {
        fixedExerciseLayoutPreferences == nil
    }

    var usesQuarterNoteSequenceKernel: Bool {
        switch self {
        case .sequence, .sr0, .sr1, .sr2:
            return true
        case .single, .positionPrompt:
            return false
        }
    }

    func applyingFixedPianoSettings(
        to settingsSlice: PianoPanelSettingsSlice
    ) -> PianoPanelSettingsSlice {
        var resolvedSettingsSlice = settingsSlice
        if let fixedRowCount = fixedPianoRowCount {
            resolvedSettingsSlice.rowCount = fixedRowCount
        }
        if let fixedMovementScope = fixedPianoMovementScope {
            resolvedSettingsSlice.movementScope = fixedMovementScope
        }
        return resolvedSettingsSlice
    }
}

extension TrainerDisplayState {
    func resolvedPianoSettingsSlice(
        from settingsSlice: PianoPanelSettingsSlice
    ) -> PianoPanelSettingsSlice {
        exerciseMode.applyingFixedPianoSettings(to: settingsSlice)
    }
}
```

## 修改 2：让 `ExerciseCompositionPolicy+Normalization` 与 `ExerciseCompositionPolicy` 直接消费 family helper

### 修改前

- `ExerciseCompositionPolicy+Normalization.swift` 仍用 `case .sr1, .sr2` 写死 `staffToPiano`
- `ExerciseCompositionPolicy.swift` 仍直接用 `fixedExerciseLayoutPreferences == nil` 判定 accessory piano promotion
- legacy fallback 仍在本地 `switch` `sr0 / sr1 / sr2`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: ExerciseCompositionPolicy.isCompositionPresetSupported(_:for:) / normalizedCompositionPreset(_:for:)
// 功能说明: 修改前 normalization 仍靠 mode 分支硬编码 `SR-1 / SR-2 -> staffToPiano`，
// 还没有通过共享 helper 收口 preset 规则。
static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    switch exerciseMode {
    case .sr0:
        return preset == .staffToNaturalNoteStrip
    case .sr1, .sr2:
        return preset == .staffToPiano
    // ... 省略其它 case ...
    }
}

static func normalizedCompositionPreset(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> ExerciseCompositionPreset {
    guard isCompositionPresetSupported(preset, for: exerciseMode) else {
        switch exerciseMode {
        case .sr0:
            return .staffToNaturalNoteStrip
        case .sr1, .sr2:
            return .staffToPiano
        // ... 省略其它 case ...
        }
    }
    return preset
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.makePresentation(from:) / legacyCompatibleTrainerDisplayState(_:)
// 功能说明: 修改前 policy 仍在本地直接判断 fixed layout 与 SR mode 分支；
// accessory promotion 和 legacy fallback 还没有吃到共享 helper。
let allowsAccessoryPianoPromotion =
    input.trainerDisplayState.exerciseMode.fixedExerciseLayoutPreferences
    == nil

switch legacyCompatibleState.exerciseMode {
case .sr0, .sr1, .sr2:
    legacyCompatibleState.exerciseMode = .sequence
case .single, .sequence, .positionPrompt:
    break
}
```

### 修改后

- `ExerciseCompositionPolicy+Normalization.swift` 先看 `fixedCompositionPreset`
- `ExerciseCompositionPolicy.swift` 直接用 `allowsAccessoryPianoPromotion`
- legacy fallback 改成消费 `isPositionPromptMode` 与 `exerciseMode.usesQuarterNoteSequenceKernel`
- 这样 `SRPianoReadingFamily` 以后如果新增成员，不需要在 policy 层再到处补平行分支

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift
// 函数名/符号: ExerciseCompositionPolicy.isCompositionPresetSupported(_:for:) / normalizedCompositionPreset(_:for:)
// 功能说明: 修改后 preset support 和 preset normalization 都优先看 fixedCompositionPreset；
// SR fixed mode 的 composition 规则不再散落在本地 `switch` 里。
static func isCompositionPresetSupported(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> Bool {
    if let fixedCompositionPreset = exerciseMode.fixedCompositionPreset {
        return preset == fixedCompositionPreset
    }

    switch exerciseMode {
    case .single, .sequence:
        // ... 保持既有逻辑 ...
        return true
    case .sr0, .sr1, .sr2:
        return false
    case .positionPrompt:
        // ... 保持既有逻辑 ...
        return true
    }
}

static func normalizedCompositionPreset(
    _ preset: ExerciseCompositionPreset,
    for exerciseMode: TrainerExerciseMode
) -> ExerciseCompositionPreset {
    if let fixedCompositionPreset = exerciseMode.fixedCompositionPreset {
        return fixedCompositionPreset
    }
    // ... 保持既有 fallback 逻辑 ...
    return preset
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.makePresentation(from:) / legacyCompatiblePreferences(from:) / legacyCompatibleTrainerDisplayState(_:)
// 功能说明: 修改后 policy 与 legacy fallback 都直接消费共享 helper；
// accessory piano promotion、positionPrompt fallback、quarter-note legacy host mode 不再手工枚举 SR family。
resolvedLayoutPreferences.isPianoAccessoryVisible =
    resolvedLayoutPreferences.isPianoAccessoryVisible
    || (
        input.trainerDisplayState.exerciseMode
            .allowsAccessoryPianoPromotion
            && input.pianoPanelState.isVisible
            && !resolvedLayoutPreferences.compositionPreset
            .usesMainPianoAnswerSurface
    )

if input.trainerDisplayState.isPositionPromptMode {
    legacyCompatiblePreferences.compositionPreset = .fretboardToNaturalNoteStrip
} else {
    // ... staffToFretboard / targetPromptToFretboard fallback ...
}

if legacyCompatibleState.exerciseMode.usesQuarterNoteSequenceKernel,
   legacyCompatibleState.exerciseMode != .sequence {
    legacyCompatibleState.exerciseMode = .sequence
}
```

## 修改 3：让 iOS / macOS controller 改为走共享 helper，而不是手搓 `SR` 分支

### 修改前

- 双端 controller 都自己拼 `resolvedPianoSettingsSlice`
- `synchronizeTrainerPresentationState(...)` 也直接列出 `.sequence, .sr0, .sr1, .sr2`
- 这会让 family contract 明明在 shared 层，但 controller 仍然保留一份平行知识

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: iOSViewController.resolvedPianoSettingsSlice / synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改前 controller 仍然自己拼 fixed piano settings，
// 并手写 `SR` family 的 sequence 路由分支。
private var resolvedPianoSettingsSlice: PianoPanelSettingsSlice {
    var settingsSlice = pianoPanelState.settingsSlice
    if let fixedRowCount = trainerDisplayState.exerciseMode.fixedPianoRowCount {
        settingsSlice.rowCount = fixedRowCount
    }
    if let fixedMovementScope = trainerDisplayState.exerciseMode
        .fixedPianoMovementScope {
        settingsSlice.movementScope = fixedMovementScope
    }
    return settingsSlice
}

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

### 修改后

- 双端 controller 都改成调用 `trainerDisplayState.resolvedPianoSettingsSlice(...)`
- `synchronizeTrainerPresentationState(...)` 改为优先看 `usesQuarterNoteSequenceKernel`
- `iOS` 与 `macOS` 本轮是镜像修改，下面用 `iOS` 代码做代表；`macOS` 对应落点是 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: iOSViewController.resolvedPianoSettingsSlice / synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改后 controller 不再维护第二份 `SR` family 规则；
// 是否走 sequence kernel、以及如何覆盖 piano settings，都统一委托给 TrainerDisplayState。
private var resolvedPianoSettingsSlice: PianoPanelSettingsSlice {
    trainerDisplayState.resolvedPianoSettingsSlice(
        from: pianoPanelState.settingsSlice
    )
}

private func synchronizeTrainerPresentationState(reason: String) {
    if trainerDisplayState.usesQuarterNoteSequenceKernel {
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    } else if trainerDisplayState.isPositionPromptMode {
        synchronizePositionPromptPresentation(reason: reason)
    } else {
        synchronizeSingleTrainerPresentation(reason: reason)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: macOSViewController.resolvedPianoSettingsSlice / synchronizeTrainerPresentationState(reason:)
// 功能说明: macOS 端与 iOS 保持同样的 shared helper 接线方式，
// 防止双平台在阶段 2 开始出现“shared 已经改了、某一端 controller 还在用旧分支”的漂移。
private var resolvedPianoSettingsSlice: PianoPanelSettingsSlice {
    trainerDisplayState.resolvedPianoSettingsSlice(
        from: pianoPanelState.settingsSlice
    )
}

private func synchronizeTrainerPresentationState(reason: String) {
    if trainerDisplayState.usesQuarterNoteSequenceKernel {
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    } else if trainerDisplayState.isPositionPromptMode {
        synchronizePositionPromptPresentation(reason: reason)
    } else {
        synchronizeSingleTrainerPresentation(reason: reason)
    }
}
```

## 修改 4：在 `ExerciseCompositionValidationExercisePolicy` 增补阶段 1 helper 校验

### 修改前

- 阶段 0 的 `validateSRModesFreezeStaffToPianoPolicyContracts()` 只校验 contract 本身与 fixed accessor 的结果
- 还没有校验新增的 `fixedCompositionPreset`、`allowsAccessoryPianoPromotion`、`applyingFixedPianoSettings(...)`
- 也还没有显式校验 `SR-0` 不应继承 `SRPianoReadingFamily` 的 piano settings helper

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 修改前阶段0夹具已经验证了 contract 与 fixed accessor；
// 但阶段1新增的 shared helper 还没有进入自动化覆盖。
if exerciseMode.fixedExerciseLayoutPreferences
    != contract.fixedExerciseLayoutPreferences {
    issues.append(
        issue(
            fixtureName,
            "\(modeDebugName) 的 fixedExerciseLayoutPreferences 应直接来自 SR piano reading contract。"
        )
    )
}
if exerciseMode.fixedPianoMovementScope
    != contract.fixedPianoMovementScope {
    issues.append(
        issue(
            fixtureName,
            "\(modeDebugName) 的 fixedPianoMovementScope 应直接来自 SR piano reading contract。"
        )
    )
}
```

### 修改后

- 新增 `requestedPianoSettingsSlice`
- 校验 `fixedCompositionPreset`
- 校验 `allowsAccessoryPianoPromotion`
- 校验 `applyingFixedPianoSettings(...)` 只覆盖 `rowCount / movementScope`，不篡改 `whiteKeyStyle / snapEnabled`
- 校验 `SR-0` 走同一个 helper 时必须保持原样，不能误继承 `SRPianoReadingFamily`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts() / validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts()
// 功能说明: 修改后 validation 会覆盖阶段1新增的 composition / accessory / piano settings helper；
// 同时显式防止 `SR-0` 被错误并入 SR piano reading family 的 helper 链。
let requestedPianoSettingsSlice = PianoPanelSettingsSlice(
    rowCount: 4,
    movementScope: .cascade,
    whiteKeyStyle: .borderlessSeparatedByGaps,
    snapEnabled: false
)
let resolvedPianoSettingsSlice = exerciseMode
    .applyingFixedPianoSettings(to: requestedPianoSettingsSlice)

if exerciseMode.fixedCompositionPreset
    != contract.fixedExerciseLayoutPreferences.compositionPreset {
    issues.append(
        issue(
            fixtureName,
            "\(modeDebugName) 的 fixedCompositionPreset 应与集中 SR layout contract 对齐。"
        )
    )
}
if exerciseMode.allowsAccessoryPianoPromotion {
    issues.append(
        issue(
            fixtureName,
            "\(modeDebugName) 作为 fixed SR piano reading mode，不应允许 accessory piano promotion。"
        )
    )
}
if resolvedPianoSettingsSlice.rowCount != contract.fixedPianoRowCount
    || resolvedPianoSettingsSlice.movementScope
    != contract.fixedPianoMovementScope {
    issues.append(
        issue(
            fixtureName,
            "\(modeDebugName) 的 resolvedPianoSettingsSlice 应通过共享 helper 收敛到 contract 指定的行数与 movementScope。"
        )
    )
}

if trainerDisplayState.exerciseMode.fixedCompositionPreset
    != .staffToNaturalNoteStrip {
    issues.append(
        issue(
            fixtureName,
            "SR-0 的 fixedCompositionPreset 应固定为 `staffToNaturalNoteStrip`。"
        )
    )
}
if resolvedPianoSettingsSlice != requestedPianoSettingsSlice {
    issues.append(
        issue(
            fixtureName,
            "SR-0 不应继承 SR piano reading family 的固定 piano settings helper；其 piano panel 设置应保持原样。"
        )
    )
}
```

## 本轮调试与修正

- 首次构建失败点：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 第一次实现阶段1夹具时误用了不存在的 white key style 枚举值，导致双平台构建同时失败。
let requestedPianoSettingsSlice = PianoPanelSettingsSlice(
    rowCount: 4,
    movementScope: .cascade,
    whiteKeyStyle: .gapOnly,
    snapEnabled: false
)
```

- 最终修正：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 工程里的真实枚举 case 是 `.borderlessSeparatedByGaps`；
// 修正后 validation helper 可以继续表达“rowCount / movementScope 以外的字段应保持原样”的测试意图。
let requestedPianoSettingsSlice = PianoPanelSettingsSlice(
    rowCount: 4,
    movementScope: .cascade,
    whiteKeyStyle: .borderlessSeparatedByGaps,
    snapEnabled: false
)
```

## 本轮产出对后续阶段的直接意义

- 阶段 2 可以直接在 `TrainerSRPianoReadingMode.sr2.contract` 上把 `pianoRowCount` 从 `1` 改成 `2`；`normalization / policy / controller` 已经不需要再为此额外改一套并行逻辑
- 阶段 3 如果开放 `SR-2` 的 settings / navigation 入口，现有 shared helper 与 validation 已经能保证 preset / accessory / piano settings 的消费链是一致的
- 现有 `SR-0 / SR-1` smoke 已经证明：阶段 1 把 controller / policy 从手工分支切到 shared helper 后，没有引入现有 SR 模式回归

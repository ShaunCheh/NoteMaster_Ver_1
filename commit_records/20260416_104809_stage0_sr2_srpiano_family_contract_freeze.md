# 20260416_104809_stage0_sr2_srpiano_family_contract_freeze

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260416_104809`
- 记录依据：基于当前工作区 `changes`、`git status --short -- ...`、`git diff --stat -- ...`、按文件 `git diff -- ...`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` / `startup-validation` 结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md` 实施阶段 0 的真实落地代码改动；目标是冻结 `SR-1 / SR-2` 的统一 `SR piano reading family` 合同
- 重要说明：
- 本轮第一次构建时，`TrainerDisplayState.swift` 中几处 `switch` 在抽出集中 contract 后没有显式覆盖 `.sr1 / .sr2`，触发了 `switch must be exhaustive`；最终修正为“枚举分支保持穷尽，分支内部仍只委托到 contract”，因此最终代码既满足阶段 0 的集中收口，也满足 Swift 的编译约束
- 这一步只冻结 family 合同，`SR-2` 仍保持 `exactNote + 1 row + rowOnly`；把 `rowCount` 切到 `2` 是阶段 2 的工作，不在本次记录范围内
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`3 files changed, 241 insertions(+), 28 deletions(-)`
- 统计口径说明：
- 当前 `git status --short -- ...` 只包含下面 3 个 `Swift` 文件，因此本次统计口径直接等同于阶段 0 改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `3 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 验证结果：
- `ReadLints`：对上述 3 个文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage0_mac" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage0_ios" build`：`BUILD SUCCEEDED`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：macOS 运行结果为 `PASS scenario=startup_validation`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：iOS Simulator 运行结果为 `PASS scenario=startup_validation`
- `ExerciseCompositionValidation` 在 iOS / macOS 启动验证链里均为 `automated=PASS`，其中 `sr_modes_freeze_staff_to_piano_policy_contracts` 夹具都为 `issues=0`
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md`
- 没有开放 `SR-2` 的 settings / navigation 入口
- 没有把 `SR-2` 的 `fixedPianoRowCount` 改成 `2`
- 没有新增 `SR-2` runtime smoke
- 没有提交代码

## 本次结论

- `SR-1 / SR-2` 现在已经有统一的 `SR piano reading family` 合同入口，后续不需要再在多个 accessor、validation fixture 里重复推导固定矩阵
- `ExerciseCompositionValidation` 现在校验的是“实际 accessor 是否委托到集中 contract”，而不是继续靠硬编码的 `.pitchClass / .exactNote / .srPianoAnswer` 分散断言
- `FretboardValidation` 现在不仅验证 `resolvedSequenceConfiguration` 的结果，还会验证 family 成员身份、共享基线、差异矩阵，以及各个固定 accessor 的委托关系
- 当前产品行为不变：`SR-1` 仍是 `pitchClass + 1 row + rowOnly`，`SR-2` 仍是 `exactNote + 1 row + rowOnly`

## 修改 1：在 `TrainerDisplayState` 收口 `SR piano reading family` 的固定矩阵

### 修改前

- `SR-1 / SR-2` 的固定值散落在多个 accessor 里
- 后续如果要把 `SR-2` 改成两行，必须同时改 `answerPolicy`、`rowCount`、`movementScope`、`layoutPreferences` 等多处入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode.fixedSequenceAnswerPolicy / fixedSequenceClef / fixedExerciseLayoutPreferences / fixedPianoRowCount / fixedPianoMovementScope
// 功能说明: 修改前 `SR-1` / `SR-2` 的固定矩阵分散在多个 accessor 中；
// 后续想改 `SR-2` 差异项时，需要在多处 `switch` 同步维护。
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
}
```

### 修改后

- 新增 `TrainerSRPianoReadingMode` 与 `TrainerSRPianoReadingContract`
- 让 `TrainerExerciseMode` 上所有与 `SR-1 / SR-2` 相关的固定 accessor 都委托到同一份 contract
- 阶段 0 先保持 `SR-2` 仍为 `pianoRowCount: 1`，只把差异入口集中起来，不提前改变产品行为

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerSRPianoReadingMode.contract / TrainerExerciseMode.srPianoReadingContract / fixedSequenceAnswerPolicy
// 功能说明: 修改后先把 `SR-1 / SR-2` 的共享基线与差异矩阵集中到 contract；
// 原有 accessor 继续保留，但不再各自维护固定值，而是统一委托到 contract。
enum TrainerSRPianoReadingMode: Equatable, Hashable, Sendable {
    case sr1
    case sr2

    var contract: TrainerSRPianoReadingContract {
        switch self {
        case .sr1:
            return TrainerSRPianoReadingContract(
                answerPolicy: .pitchClass,
                pianoRowCount: 1,
                pianoMovementScope: .rowOnly
            )
        case .sr2:
            return TrainerSRPianoReadingContract(
                answerPolicy: .exactNote,
                pianoRowCount: 1,
                pianoMovementScope: .rowOnly
            )
        }
    }
}

struct TrainerSRPianoReadingContract: Equatable, Sendable {
    let fixedSequenceClef: StaffClef
    let fixedExerciseLayoutPreferences: ExerciseLayoutPreferences
    let fixedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy
    let fixedPianoRowCount: Int
    let fixedPianoMovementScope: PianoMovementScope
}

extension TrainerExerciseMode {
    var srPianoReadingContract: TrainerSRPianoReadingContract? {
        srPianoReadingMode?.contract
    }

    var fixedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy? {
        switch self {
        case .sr1, .sr2:
            return srPianoReadingContract?.fixedSequenceAnswerPolicy
        case .sr0:
            return .pitchClass
        case .single, .sequence, .positionPrompt:
            return nil
        }
    }
}
```

## 修改 2：在 `ExerciseCompositionValidationExercisePolicy` 把 `SR` policy 校验切到集中 contract

### 修改前

- `validateSRModesFreezeStaffToPianoPolicyContracts()` 直接吃 `expectedAnswerPolicy`
- 校验重点是硬编码的 `.pitchClass / .exactNote / .srPianoAnswer`
- 这样即便后续真正抽出了集中 contract，也无法保证 accessor 是不是已经都接到同一来源

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 修改前该夹具主要验证硬编码结果；
// 它能证明“最终结果是对的”，但不能证明“固定值来源已经集中收口”。
static func validateSRModesFreezeStaffToPianoPolicyContracts()
    -> [ExerciseCompositionValidationIssue] {
    func validateMode(
        _ exerciseMode: TrainerExerciseMode,
        requestedAnswerPolicy: TrainerSequenceAnswerPolicy,
        expectedAnswerPolicy: TrainerSequenceAnswerPolicy
    ) {
        // ... 省略前文未变上下文 ...
        if resolvedSequenceConfiguration.answerPolicy != expectedAnswerPolicy {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeDebugName) 的 resolvedSequenceConfiguration.answerPolicy 应固定为 \(expectedAnswerPolicy)。"
                )
            )
        }
        if normalizedPreferences != .srPianoAnswer {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeDebugName) 的 shared normalization 应统一收敛到固定的 SR layout。"
                )
            )
        }
    }

    validateMode(
        .sr1,
        requestedAnswerPolicy: .exactNote,
        expectedAnswerPolicy: .pitchClass
    )
    validateMode(
        .sr2,
        requestedAnswerPolicy: .pitchClass,
        expectedAnswerPolicy: .exactNote
    )
}
```

### 修改后

- 先要求 `.sr1 / .sr2` 必须属于统一 family，并且能拿到 `srPianoReadingContract`
- 再验证 `fixedSequenceClef`、`fixedSequenceAnswerPolicy`、`fixedExerciseLayoutPreferences`、`fixedPianoRowCount`、`fixedPianoMovementScope` 是否都来自 contract
- 最后单独验证 family 共享基线与差异矩阵，确保 `SR-1 / SR-2` 以后继续沿同一条 contract 演进

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 修改后该夹具既验证最终结果，也验证固定矩阵是否已经统一委托到 SR piano reading contract。
static func validateSRModesFreezeStaffToPianoPolicyContracts()
    -> [ExerciseCompositionValidationIssue] {
    func validateMode(
        _ exerciseMode: TrainerExerciseMode,
        requestedAnswerPolicy: TrainerSequenceAnswerPolicy
    ) {
        guard exerciseMode.isSRPianoReadingMode else {
            issues.append(
                issue(
                    fixtureName,
                    "\(String(describing: exerciseMode)) 应被标记为统一的 SR piano reading family 成员。"
                )
            )
            return
        }
        guard let contract = exerciseMode.srPianoReadingContract else {
            issues.append(
                issue(
                    fixtureName,
                    "\(String(describing: exerciseMode)) 应暴露集中式 SR piano reading contract。"
                )
            )
            return
        }

        if exerciseMode.fixedSequenceAnswerPolicy
            != contract.fixedSequenceAnswerPolicy {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeDebugName) 的 fixedSequenceAnswerPolicy 应直接来自 SR piano reading contract。"
                )
            )
        }
        if normalizedPreferences != contract.fixedExerciseLayoutPreferences {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeDebugName) 的 shared normalization 应统一收敛到固定的 SR staff-to-piano layout。"
                )
            )
        }
        if exerciseMode.fixedPianoRowCount != contract.fixedPianoRowCount {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeDebugName) 的 fixedPianoRowCount 应直接来自 SR piano reading contract。"
                )
            )
        }
    }

    guard let sr1Contract = TrainerExerciseMode.sr1.srPianoReadingContract,
          let sr2Contract = TrainerExerciseMode.sr2.srPianoReadingContract else {
        issues.append(
            issue(
                fixtureName,
                "SR-1 / SR-2 应共享可读取的 SR piano reading contract。"
            )
        )
        return issues
    }
    if sr1Contract.fixedSequenceAnswerPolicy
        == sr2Contract.fixedSequenceAnswerPolicy {
        issues.append(
            issue(
                fixtureName,
                "SR-1 / SR-2 的集中 contract 至少应在 answerPolicy 上保留差异矩阵。"
            )
        )
    }
}
```

## 修改 3：在 `FretboardValidation` 锁住 family seam 与 accessor delegation

### 修改前

- `modePolicySeam` 只验证了 `SR-1 / SR-2` 的结果值
- 还没有验证 `.sr1 / .sr2` 是否真的共享同一个 family 入口
- 也没有验证 `fixedSequenceClef / fixedSequenceAnswerPolicy / fixedPianoRowCount` 这些 accessor 是否都已经委托到统一 contract

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: FretboardValidationRunner.validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改前这里只验证 `resolvedSequenceConfiguration` 的最终结果；
// 还没有把 family 成员关系、集中 contract、accessor 委托关系锁进 validation。
logStage("modePolicySeam")
let sr1DisplayState = TrainerDisplayState(
    exerciseMode: .sr1,
    sequenceConfiguration: TrainerSequenceConfiguration(
        clef: .bass,
        noteCount: 7,
        includesAccidentals: false,
        answerPolicy: .exactNote
    )
)
let sr1ResolvedSequenceConfiguration = sr1DisplayState
    .resolvedSequenceConfiguration
if sr1ResolvedSequenceConfiguration.clef != .treble {
    record("SR-1 的 resolvedSequenceConfiguration 应强制锁定 treble clef。")
}
if sr1ResolvedSequenceConfiguration.answerPolicy != .pitchClass {
    record("SR-1 的 resolvedSequenceConfiguration.answerPolicy 应固定为 .pitchClass。")
}
```

### 修改后

- 在 `modePolicySeam` 开头先验证 `.sr1 / .sr2` 的 family 身份和 contract 可读性
- 再验证共享基线、差异矩阵，以及所有固定 accessor 是否都委托到 `srPianoReadingContract`
- `resolvedSequenceConfiguration` 的断言也改为对齐 contract，而不是继续写死字面值

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: FretboardValidationRunner.validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后 `modePolicySeam` 会同时验证 family 成员身份、contract 基线、
// accessor 委托关系，以及 `resolvedSequenceConfiguration` 是否与集中 contract 对齐。
logStage("modePolicySeam")
if !TrainerExerciseMode.sr1.isSRPianoReadingMode
    || !TrainerExerciseMode.sr2.isSRPianoReadingMode {
    record("SR-1 / SR-2 应共享统一的 SR piano reading family 入口。")
}
let sr1ModeContract = TrainerExerciseMode.sr1.srPianoReadingContract
    ?? TrainerSRPianoReadingMode.sr1.contract
let sr2ModeContract = TrainerExerciseMode.sr2.srPianoReadingContract
    ?? TrainerSRPianoReadingMode.sr2.contract
if sr1ModeContract.fixedSequenceClef != sr2ModeContract.fixedSequenceClef
    || sr1ModeContract.fixedExerciseLayoutPreferences
    != sr2ModeContract.fixedExerciseLayoutPreferences {
    record("SR-1 / SR-2 的 family 基线应继续共享同一份 treble + srPianoAnswer 合同。")
}
if sr1ModeContract.fixedSequenceAnswerPolicy != .pitchClass
    || sr2ModeContract.fixedSequenceAnswerPolicy != .exactNote {
    record("SR piano reading contract 应继续保留 SR-1 pitchClass / SR-2 exactNote 的判题差异。")
}
if TrainerExerciseMode.sr1.fixedPianoRowCount
    != sr1ModeContract.fixedPianoRowCount
    || TrainerExerciseMode.sr2.fixedPianoRowCount
    != sr2ModeContract.fixedPianoRowCount {
    record("SR-1 / SR-2 的固定 accessors 应全部委托到集中式 SR piano reading contract。")
}

let sr1ResolvedSequenceConfiguration = sr1DisplayState
    .resolvedSequenceConfiguration
if sr1ResolvedSequenceConfiguration.clef != sr1ModeContract.fixedSequenceClef {
    record("SR-1 的 resolvedSequenceConfiguration.clef 应与集中 contract 对齐。")
}
if sr1ResolvedSequenceConfiguration.answerPolicy
    != sr1ModeContract.fixedSequenceAnswerPolicy {
    record("SR-1 的 resolvedSequenceConfiguration.answerPolicy 应与集中 contract 对齐。")
}
```

## 本轮产出对后续阶段的直接意义

- 阶段 1 可以直接把 `normalization / controller` 的消费方切到 `srPianoReadingContract`，不用再重新定义 `SR-1 / SR-2` 固定矩阵
- 阶段 2 如果要把 `SR-2` 改成 `2 rows`，只需要调整 `TrainerSRPianoReadingMode.sr2.contract` 的 `pianoRowCount`
- 阶段 3 以后即便开放 `SR-2` settings 入口，`ExerciseCompositionValidation` 与 `FretboardValidation` 也已经能提前阻止 fixed contract 回退到分散维护状态

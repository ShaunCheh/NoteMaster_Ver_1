# 20260416_123144_stage2_sr2_exact_note_two_row_contract

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260416_123144`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat -- ...`、按文件 `git diff -- ...`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` / `startup-validation` / `SR-1` smoke 结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md` 实施阶段 2 的真实落地代码改动；目标是在不碰 scene / renderer / keyboard 组件的前提下，把 `SR-2` 从 family contract 自然切到 `exactNote + 2 rows + rowOnly`
- 重要说明：
- 本轮不是阶段 3；没有开放 `SR-2` 的 settings / navigation 入口
- 本轮不是阶段 4；没有新增 `SR-2` runtime smoke 场景
- 当前 `git status --short` 只包含 3 个 `Swift` 文件，因此本次记录口径与阶段 2 的真实改动集完全一致
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`3 files changed, 27 insertions(+), 1 deletion(-)`
- 本记录文件本身是新增 markdown 记录，不计入上面的 diff 统计
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次确认但未修改的关键文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 验证结果：
- `ReadLints`：对本轮 3 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage2_mac" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage2_ios" build`：`BUILD SUCCEEDED`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：macOS 运行结果为 `PASS scenario=startup_validation`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：iOS Simulator 运行结果为 `PASS scenario=startup_validation`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：macOS 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：iOS Simulator 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- `ExerciseCompositionValidation` 在 iOS / macOS 启动验证链里均为 `automated=PASS fixtures=37`，其中 `sr_modes_freeze_staff_to_piano_policy_contracts` 夹具都为 `issues=0`
- 本轮调试过程中的非代码问题：
- macOS runtime smoke 首次在沙箱内执行时直接 `exit 134` 且无有效输出；随后以相同命令在非沙箱环境重跑，通过，因此不计为代码失败
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md`
- 没有修改任何旧的 `.md` 记录文件
- 没有开放 `SR-2` 的 settings / navigation 入口
- 没有新增 `SR-2` 专属 smoke 场景
- 没有提交代码

## 本次结论

- `SR-2` 的真实产品差异已经从 family contract 收口为 `exactNote + 2 rows + rowOnly`
- 阶段 2 没有回头加 controller if/else，也没有去改 `staffToPiano` scene、renderer 或钢琴组件本身
- 共享 validation 现在不仅验证 `answerPolicy` 差异，还显式锁死 `SR-1 = 1 row`、`SR-2 = 2 rows`、两者都保持 `rowOnly`
- 由于 `PianoPanelProjection.resolvedRows(...)` 与 `PianoInteractionReducer.resolvedAffectedRowIndices(...)` 早已支持多行与单行作用域，本轮只需要改 contract 和 seam 验证，不需要制造额外 blast radius

## 修改 1：把 `SR-2` 的 family contract 从单行钢琴切到双行钢琴

### 修改前

- 阶段 1 结束时，`SR-2` 虽然已经固定为 `exactNote`
- 但 `TrainerSRPianoReadingMode.sr2.contract` 仍把 `pianoRowCount` 写死成 `1`
- 这会让 `resolvedPianoSettingsSlice` 继续把控制器链路里的钢琴固定成单行，导致阶段 2 的真实产品差异还没落地

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerSRPianoReadingMode.contract
// 功能说明: 修改前 `sr2` 仍沿用阶段1的 1 行钢琴固定值；
// 因此虽然判题策略已经切到 `exactNote`，但 UI 侧还不会自然长成两行钢琴。
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
```

### 修改后

- 只改 `sr2.contract` 这一处 family 固定值
- `answerPolicy` 继续保持 `exactNote`
- `fixedPianoRowCount` 从 `1` 改为 `2`
- `fixedPianoMovementScope` 继续保持 `rowOnly`
- 阶段 1 已接好的 shared helper / controller 链路会自动消费这组固定值，不需要再改其它层

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerSRPianoReadingMode.contract
// 功能说明: 修改后 `sr2` 的 family contract 直接固定为 `exactNote + 2 rows + rowOnly`；
// 双端 controller 会通过阶段1引入的 shared helper 自然收到两行钢琴配置。
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
                pianoRowCount: 2,
                pianoMovementScope: .rowOnly
            )
        }
    }
}
```

## 修改 2：在 `ExerciseCompositionValidation` 显式锁死行数合同

### 修改前

- 阶段 1 的 `sr_modes_freeze_staff_to_piano_policy_contracts` 已经会检查：
- `SR-1 / SR-2` 共享 treble + `srPianoAnswer`
- `fixedSequenceAnswerPolicy` 分别是 `pitchClass / exactNote`
- `resolvedPianoSettingsSlice` 会对齐到 contract
- 但它还没有直接写死“`SR-1 = 1 row / SR-2 = 2 rows / rowOnly`”
- 也就是说，如果未来有人把 `sr2` 又改回 1 行，只靠原来的夹具信息量还不够聚焦

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 修改前只验证 shared family 的公共基线与 answerPolicy 差异；
// 对阶段2最关键的 `rowOnly + 1/2 行矩阵` 还没有单独立合同。
if sr1Contract.fixedPianoMovementScope
    != sr2Contract.fixedPianoMovementScope {
    issues.append(
        issue(
            fixtureName,
            "SR-1 / SR-2 的 movementScope 如需分叉，也应只通过集中 contract 修改；当前不应在其它分支偷跑分裂。"
        )
    )
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
```

### 修改后

- 新增 `rowOnly` 显式断言
- 新增 `SR-1 = 1 row / SR-2 = 2 rows` 显式断言
- 这样阶段 2 的产品矩阵在 shared validation 层被单独钉死，而不是仅靠间接推导

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 修改后 shared validation 会直接锁死阶段2的行数合同；
// 如果以后有人把 `SR-2` 改回单行、或让 movementScope 脱离 `rowOnly`，启动验证会直接报错。
if sr1Contract.fixedPianoMovementScope
    != sr2Contract.fixedPianoMovementScope {
    issues.append(
        issue(
            fixtureName,
            "SR-1 / SR-2 的 movementScope 如需分叉，也应只通过集中 contract 修改；当前不应在其它分支偷跑分裂。"
        )
    )
}
if sr1Contract.fixedPianoMovementScope != .rowOnly
    || sr2Contract.fixedPianoMovementScope != .rowOnly {
    issues.append(
        issue(
            fixtureName,
            "阶段 2 的 SR piano reading family 应继续锁死 rowOnly；若后续要改两行联动，只能改集中 contract 与对应 smoke。"
        )
    )
}
if sr1Contract.fixedPianoRowCount != 1
    || sr2Contract.fixedPianoRowCount != 2 {
    issues.append(
        issue(
            fixtureName,
            "阶段 2 的 SR piano reading family 应显式锁死 SR-1 = 1 row、SR-2 = 2 rows，避免回退成同一行数配置。"
        )
    )
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
```

## 修改 3：在 `FretboardValidation` 的 mode seam 上同步锁死同一份矩阵

### 修改前

- `FretboardValidation` 在阶段 0 已经验证：
- `SR-1 / SR-2` 暴露统一 `srPianoReadingContract`
- 共享同一份 clef / layout 基线
- `answerPolicy` 保持 `pitchClass / exactNote` 差异
- 但它同样还没有直接宣告“`SR-2` 必须是 2 行”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: FretboardValidationRunner.validateQuarterNoteSequenceTrainer()
// 功能说明: 修改前的 mode seam 只校验 family 身份、公共基线和 answerPolicy 差异；
// 还没有把阶段2新增的 `rowOnly + 1/2 行` 视为独立合同。
if sr1ModeContract.fixedPianoMovementScope
    != sr2ModeContract.fixedPianoMovementScope {
    record("SR-1 / SR-2 的 movementScope 如需分叉，也应只改集中 contract，而不是重新散落到多个 switch。")
}
if sr1ModeContract.fixedSequenceAnswerPolicy != .pitchClass
    || sr2ModeContract.fixedSequenceAnswerPolicy != .exactNote {
    record("SR piano reading contract 应继续保留 SR-1 pitchClass / SR-2 exactNote 的判题差异。")
}
```

### 修改后

- 在 shared trainer seam 里补上同样的 `rowOnly` / `1 行 vs 2 行` 断言
- 这样即使未来有人只改 contract、忘了同步 shared validation 语义，这个 seam 也会拦住

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: FretboardValidationRunner.validateQuarterNoteSequenceTrainer()
// 功能说明: 修改后 mode seam 会直接验证阶段2的键盘行数矩阵；
// 这保证了 trainer 层对 `SR-1 / SR-2` 的理解和 composition / controller 的 fixed contract 保持一致。
if sr1ModeContract.fixedPianoMovementScope
    != sr2ModeContract.fixedPianoMovementScope {
    record("SR-1 / SR-2 的 movementScope 如需分叉，也应只改集中 contract，而不是重新散落到多个 switch。")
}
if sr1ModeContract.fixedPianoMovementScope != .rowOnly
    || sr2ModeContract.fixedPianoMovementScope != .rowOnly {
    record("阶段 2 的 SR piano reading family 应继续锁死 rowOnly；若后续要改两行联动，只能改集中 contract 与对应 smoke。")
}
if sr1ModeContract.fixedPianoRowCount != 1
    || sr2ModeContract.fixedPianoRowCount != 2 {
    record("阶段 2 的 SR piano reading family 应显式锁死 SR-1 = 1 row、SR-2 = 2 rows，避免回退成同一行数配置。")
}
if sr1ModeContract.fixedSequenceAnswerPolicy != .pitchClass
    || sr2ModeContract.fixedSequenceAnswerPolicy != .exactNote {
    record("SR piano reading contract 应继续保留 SR-1 pitchClass / SR-2 exactNote 的判题差异。")
}
```

## 阶段边界确认：为什么这次没有改钢琴组件

- 阶段 2 计划明确要求“不改 scene，不改 renderer，不改 keyboard 组件”
- 这不是偷懒，而是因为阶段 1 已经把 `fixedPianoRowCount / fixedPianoMovementScope` 接到 shared helper 和 controller
- 同时钢琴底层本来就已经具备：
- 按 `rowCount` 自动裁剪 / 追加 row
- 按 `rowOnly` 只作用当前行
- 所以本轮只需改 family contract，不需要再深入 `Shared/Piano` 做额外改造

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelProjection.resolvedRows(from:panelState:)
// 功能说明: 该逻辑在本轮修改前就已经支持按 `resolvedRowCount` 自动截断或补齐钢琴行；
// 阶段2只需要把 `SR-2` 的 fixed row count 切到 2，就能复用这里的多行扩展能力。
static func resolvedRows(
    from baseRows: [PianoRowState],
    panelState: PianoPanelState
) -> [PianoRowState] {
    let targetRowCount = panelState.resolvedRowCount
    let scopedRows = rowsApplyingMovementScope(
        to: baseRows,
        movementScope: panelState.movementScope
    )

    guard !scopedRows.isEmpty else {
        return makeFallbackRows(
            rowCount: targetRowCount,
            movementScope: panelState.movementScope
        )
    }

    if scopedRows.count == targetRowCount {
        return scopedRows
    }

    if scopedRows.count > targetRowCount {
        return Array(scopedRows.prefix(targetRowCount))
    }

    var expandedRows = scopedRows
    while expandedRows.count < targetRowCount {
        expandedRows.append(
            appendedRow(
                after: expandedRows.last,
                movementScope: panelState.movementScope
            )
        )
    }
    return expandedRows
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名/符号: PianoInteractionReducer.resolvedAffectedRowIndices(rowIndex:movementScope:rowCount:)
// 功能说明: `rowOnly` 的交互语义在本轮之前就已存在；
// 因此阶段2只需继续把 `SR-2` 固定在 `rowOnly`，不必重新改答题交互逻辑。
static func resolvedAffectedRowIndices(
    rowIndex: Int,
    movementScope: PianoMovementScope,
    rowCount: Int
) -> [Int] {
    guard rowCount > 0 else {
        return []
    }

    switch movementScope {
    case .rowOnly:
        guard (0..<rowCount).contains(rowIndex) else {
            return []
        }
        return [rowIndex]
    case .cascade:
        return Array(0..<rowCount)
    }
}
```

## 本轮实际命令

```bash
# 文件路径: 工程级验证命令
# 函数名: date / xcodebuild / runtime smoke
# 功能说明: 本次阶段2记录使用的时间戳命令与实际跑过的构建、启动验证、回归 smoke 命令。
date +"%Y%m%d_%H%M%S"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage2_mac" build
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage2_ios" build
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation "/tmp/NoteMaster_Ver_1_stage2_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer "/tmp/NoteMaster_Ver_1_stage2_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl boot "iPhone 17" >/dev/null 2>&1 || true
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl bootstatus "iPhone 17" -b
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl install booted "/tmp/NoteMaster_Ver_1_stage2_ios/Build/Products/Debug-iphonesimulator/NoteMaster_Ver_1.app"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
```

## 对后续阶段的直接意义

- 阶段 3 可以在不再触碰 family 核心合同的前提下，单独开放 `SR-2` 的 settings / navigation 入口
- 阶段 4 新增 `SR-2` runtime smoke 时，不需要再为“到底是不是两行钢琴”补一层产品推导；只需要围绕当前已冻结的 contract 补 smoke 断言
- 如果后续产品要把 `SR-2` 改成“两行联动”，也只应该改集中 contract 与对应 smoke，不应该回到 controller / scene / renderer 层重新散落逻辑

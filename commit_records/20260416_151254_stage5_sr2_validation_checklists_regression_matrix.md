# 20260416_151254_stage5_sr2_validation_checklists_regression_matrix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260416_151254`
- 记录依据：基于当前工作区 `git status --short`、`git diff --stat -- ...`、按文件 `git diff -- ...`、当前文件内容，以及本轮已有的 `ReadLints`、双端 `xcodebuild`、双端 `startup-validation` 结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md` 实施阶段 5 的真实落地代码改动；目标是把 `SR-2` 从“已有 contract / settings / runtime smoke”继续补齐到 shared validation 聚合、手工回归清单和 SR 模式回归矩阵
- 当前 `git status --short` 只包含下面 4 个 `Swift` 文件，因此本次记录口径与阶段 5 的真实改动集一致
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`4 files changed, 23 insertions(+), 7 deletions(-)`
- 本记录文件本身是新增 markdown 记录，不计入上面的 diff 统计
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本次确认但未修改的关键文件：
- `.cursor/plans/sr2两行钢琴_4531b6e9.plan.md`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- 验证结果：
- `ReadLints`：当前仍报 `19` 条 `SourceKit` 诊断，全部集中在 `SettingsNavigationValidation.swift`，现象与前面阶段一致
- `xcodebuild`：macOS `BUILD SUCCEEDED`
- `xcodebuild`：iOS Simulator `BUILD SUCCEEDED`
- `startup-validation`：macOS 上 `ExerciseCompositionValidation(37)`、`SettingsNavigationValidation(19)`、`FretboardValidation(7)` 全部 `PASS`
- `startup-validation`：iOS 上 `ExerciseCompositionValidation(37)`、`SettingsNavigationValidation(19)`、`FretboardValidation(7)` 全部 `PASS`
- 重要说明：
- 本轮没有修改 `SR-2` 的固定 contract、本轮也没有再改 runtime smoke 入口；阶段 5 的改动全部集中在 validation 聚合器与手工回归口径
- `ReadLints` 仍报的 19 条 `Cannot find ... in scope (SourceKit)` 未导致双端编译或启动验证失败，因此本记录如实记为 IDE 诊断滞后，不据此继续改代码
- 本次没做的事情：
- 没有修改任何旧的 markdown 记录文件
- 没有修改计划文件
- 没有提交代码

## 工作区依据

```bash
# 文件路径: 仓库工作区（git status / git diff --stat）
# 函数名/符号: git status --short / git diff --stat
# 功能说明: 阶段 5 的真实改动集只有 4 个 Swift 文件；本记录文件新增前，工作区没有额外的阶段 5 代码改动。
M NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
M NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
M NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
M NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift

.../Shared/Controls/SettingsNavigationValidation.swift  |  2 ++
.../Shared/Exercise/ExerciseCompositionValidation.swift |  5 +++--
.../ExerciseCompositionValidationExercisePolicy.swift   | 17 ++++++++++++++---
.../Shared/Fretboard/FretboardValidation.swift          |  6 ++++--
4 files changed, 23 insertions(+), 7 deletions(-)
```

## 本次结论

- 阶段 5 没有再扩展 `SR-2` 的业务流，而是把前面几个阶段已经落地的 `SR-2` 约束继续写进 shared validation 聚合器，避免后续回归时只剩“运行正常”而没有“自动化断言”
- `ExerciseCompositionValidationExercisePolicy` 现在不再只检查 `SR-1 / SR-2` 的 `answerPolicy` 是否不同，而是显式锁死 `staffToPiano`、`SR-1 = .pitchClass`、`SR-2 = .exactNote`
- `ExerciseCompositionValidation`、`FretboardValidation`、`SettingsNavigationValidation` 三条手工回归清单都已补上 `SR-2` 相关检查点，并把 `SR-0 / SR-1 / SR-2` 的互切残留、`SR-2` 设置页面冻结项、`SR-1 / SR-2` 判题矩阵写进回归口径

## 修改 1：强化 `SR-1 / SR-2` family contract 的自动化断言

### 修改前

- `validateSRModesFreezeStaffToPianoPolicyContracts()` 已经能检查 `SR-1 / SR-2` 共用 `srPianoReadingContract`
- 但在关键约束上只做到“二者存在差异”，没有把阶段 2/3 的目标值显式锁死
- 这意味着如果以后把 `SR-1` 改成别的 policy，只要它和 `SR-2` 不一样，旧断言仍可能放行

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 修改前只保证 `SR-1 / SR-2` 至少在 `answerPolicy` 上存在差异，
// 并没有显式锁死 `staffToPiano` 主场景以及 `SR-1 = .pitchClass`、`SR-2 = .exactNote`。
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

### 修改后

- 新增 `compositionPreset == .staffToPiano` 的显式断言，防止 family 主场景被偷偷改回别的 preset
- 把 answer policy 的检查从“二者不同”升级成“`SR-1` 必须是 `.pitchClass`，`SR-2` 必须是 `.exactNote`”
- 这样一来，阶段 2 定下来的 `SR-2` 精确八度判题合同被直接写进 automated fixture

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 修改后把 `SR-1 / SR-2` family 的主场景与判题策略显式锁死，
// 避免只满足“二者不同”却偏离阶段 2/3 目标值的回归从 automated fixture 中漏掉。
if sr1Contract.fixedExerciseLayoutPreferences.compositionPreset
    != .staffToPiano
    || sr2Contract.fixedExerciseLayoutPreferences.compositionPreset
    != .staffToPiano {
    issues.append(
        issue(
            fixtureName,
            "SR-1 / SR-2 的 family 主场景都应继续显式锁死为 `staffToPiano`。"
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
if sr1Contract.fixedSequenceAnswerPolicy != .pitchClass
    || sr2Contract.fixedSequenceAnswerPolicy != .exactNote {
    issues.append(
        issue(
            fixtureName,
            "SR piano reading contract 应继续显式锁死 SR-1 = .pitchClass、SR-2 = .exactNote，而不是只满足“二者不同”。"
        )
    )
}
```

## 修改 2：补齐 `ExerciseCompositionValidation` 的 `SR-2` 主场景与跨模式切换回归口径

### 修改前

- `manualChecklist(for:)` 已经覆盖 `SR-0`、`SR-1`
- 但还没有 `SR-2` 的主视觉要求，也没有把 `SR-2` 纳入 `SR-0 / SR-1 / 非 SR` 的互切残留检查
- `commandLine` 口径也没有强调 `SR-1 / SR-2` 的 `staffToPiano` family 已有自动化断言、但视觉和反馈仍要手工验证

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.manualChecklist(for:)
// 功能说明: 修改前手工回归只覆盖 `SR-0` 和 `SR-1` 的主视觉；
// `SR-2` 以及三种 SR 模式之间的切换残留还没有进入统一 checklist。
"确认切到 `SR-0` 后主视觉稳定收敛到 `treble staff + 双行 natural note strip`，strip 答错会给五线谱错误反馈、答对会推进到下一题。",
"确认切到 `SR-1` 后主视觉稳定收敛到 `treble staff + 单行 piano`，不会再把 `piano accessory` 或 legacy page 投影混回主场景。",
"确认在 `SR-0` 与 `SR-1` 之间互切，再切回非 SR 模式时，不会残留 sequence 高亮、strip / piano 旧答案缓存，answer surface 交互状态也会随模式正确清理。"

// ... 省略未修改代码 ...

checklist.append("命令行只能覆盖 shared 夹具；settings 开关与钢琴显隐的实际视觉同步需在 App 运行时手工回归。")
```

### 修改后

- checklist 新增 `SR-2 = treble staff + 两行 piano + 主场景 piano answer surface` 的视觉约束
- 互切残留检查扩成 `SR-0 / SR-1 / SR-2`
- `commandLine` 说明改成：`SR-1 / SR-2` 的 family contract 已被 automated fixture 锁住，但视觉与答题反馈仍需要真机/模拟器回归

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.manualChecklist(for:)
// 功能说明: 修改后把 `SR-2` 纳入 exercise composition 的主场景与跨模式残留回归；
// 同时明确区分“命令行自动化已锁住 family contract”和“运行时视觉/反馈仍需手工确认”。
"确认切到 `SR-0` 后主视觉稳定收敛到 `treble staff + 双行 natural note strip`，strip 答错会给五线谱错误反馈、答对会推进到下一题。",
"确认切到 `SR-1` 后主视觉稳定收敛到 `treble staff + 单行 piano`，不会再把 `piano accessory` 或 legacy page 投影混回主场景。",
"确认切到 `SR-2` 后主视觉稳定收敛到 `treble staff + 两行 piano`，并继续使用主场景 piano 作为 answer surface，不会把 `piano accessory` 或 legacy page 投影混回主场景。",
"确认在 `SR-0 / SR-1 / SR-2` 之间互切，再切回非 SR 模式时，不会残留 sequence 高亮、strip / piano 旧答案缓存，answer surface 交互状态也会随模式正确清理。"

// ... 省略未修改代码 ...

checklist.append("命令行只能覆盖 shared 夹具；其中 `SR-1 / SR-2` 的 `staffToPiano` family 合同会被自动化锁住，但实际视觉与答题反馈仍需在 App 运行时手工回归。")
```

## 修改 3：补齐 `FretboardValidation` 的 `SR-1 / SR-2` 判题矩阵回归口径

### 修改前

- `FretboardValidation` 的手工清单主要聚焦指板、`positionPrompt`、过滤器、旧的 pitch-class 判题行为
- 还没有把 `SR-1` 与 `SR-2` 的“同音名不同八度”差异写成显式回归项
- `commandLine` 说明也还是泛化版本，没有指出 `SR-2` 的 `exactNote` seam 已被自动化锁住

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: FretboardValidationRunner.manualChecklist(for:)
// 功能说明: 修改前没有单独描述 `SR-1 / SR-2` 的判题矩阵；
// checklist 还停留在旧的 pitch-class 基线与一般交互验证。
"尝试连续取消品位直到只剩最后一个已选格子，再继续点击该格子；确认 UI 仍保持至少一个品位被选中。",
"在 `wrongFlash` 或 `correctHold` 期间切换过滤模式或当前激活模式下的过滤选项；若当前可见题目已变成非法题，确认界面会平滑切换到新题，不残留错误 overlay 或延时切题任务。"

// ... 省略未修改代码 ...

checklist.append("命令行只能覆盖共享层自动化夹具；iOS 滚动与 macOS live resize 需在 App 运行时手工回归。")
```

### 修改后

- checklist 明确写出 `SR-1`：题目 `C5` 时输入 `C6` 仍应判对，因为继续按 `pitchClass`
- checklist 明确写出 `SR-2`：题目 `C5` 时输入 `C6` 判错、输入 `C5` 判对，因为继续按 `exactNote`
- 同时把 `SR-2` 的 `noteCount / includesAccidentals` 不被模式 seam 篡改写进命令行说明

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: FretboardValidationRunner.manualChecklist(for:)
// 功能说明: 修改后把 `SR-1 / SR-2` 的目标判题矩阵写成显式回归用例，
// 避免后续只记得“SR-2 是精确八度”但没有可执行的人工验证口径。
"尝试连续取消品位直到只剩最后一个已选格子，再继续点击该格子；确认 UI 仍保持至少一个品位被选中。",
"在 `wrongFlash` 或 `correctHold` 期间切换过滤模式或当前激活模式下的过滤选项；若当前可见题目已变成非法题，确认界面会平滑切换到新题，不残留错误 overlay 或延时切题任务。",
"切到 `SR-1` 后，确认五线谱题目继续使用 treble clef，钢琴保持单行；当题目是 `C5` 时，输入 `C6` 仍判 correct，说明 `SR-1` 继续按 `pitchClass` 判题。",
"切到 `SR-2` 后，确认五线谱题目继续使用 treble clef，钢琴切成两行；当题目是 `C5` 时，输入 `C6` 判 wrong、输入 `C5` 判 correct，说明 `SR-2` 继续按 `exactNote` 判题。"

// ... 省略未修改代码 ...

checklist.append("命令行只能覆盖共享层自动化夹具；其中 `SR-2` 不篡改 `noteCount / includesAccidentals`、且继续按 `exactNote` 判题的 mode seam 已由自动化锁住，iOS 滚动与 macOS live resize 仍需在 App 运行时手工回归。")
```

## 修改 4：补齐 `SettingsNavigationValidation` 的 `SR-2` 设置冻结回归口径

### 修改前

- `SettingsNavigationValidation` 的手工清单已经覆盖 `SR-0`、`SR-1`
- 但 `SR-2` 虽然在 automated fixtures 里已经有 `sr2_root_tree...` 和 `sr2_settings_state...`，手工 checklist 还没有同步补上
- 因此看代码时无法从 checklist 直接看出 `SR-2` 应隐藏哪些 fixed 项

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: SettingsNavigationValidationRunner.manualChecklist(for:)
// 功能说明: 修改前手工回归只写到了 `SR-0 / SR-1`；
// `SR-2` 的 subtitle、选中态和固定项隐藏规则还没有进入 checklist。
"确认切到 `SR-0` 或 `SR-1` 后，settings root 会移除 `Accessories` 分区，`Exercise` 也只保留有效的 `Mode` 入口，不再暴露会被 fixed normalization 强拉回的子页。",
"确认 `SR-0` / `SR-1` 下 `Staff > Clef` 入口都会消失；`SR-1` 还应继续隐藏 `Piano > Rows and movement`，而 `SR-0` 仍保留后台钢琴配置入口。",
"确认 `Debug` 分区包含 `Component Bounds` 与 `Side Container Borders` 两个开关；切换 `Side Container Borders` 时 side 布局的红/蓝容器边框会立即显示或隐藏。"
```

### 修改后

- checklist 新增 `Exercise > Mode` subtitle 继续明确包含 `SR-2`
- 新增 `SR-2` 选中态不能回退到 `SR-1` 或 `Sequence`
- 新增 `SR-2` 与 `SR-1` 一样移除 `Accessories`、隐藏 `Staff > Clef` 与 `Piano > Rows and movement`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: SettingsNavigationValidationRunner.manualChecklist(for:)
// 功能说明: 修改后把 `SR-2` 的 settings 导航冻结项补进手工回归，
// 让 automated fixture 与人工验收口径在同一文件中保持一致。
"确认切到 `SR-0` 或 `SR-1` 后，settings root 会移除 `Accessories` 分区，`Exercise` 也只保留有效的 `Mode` 入口，不再暴露会被 fixed normalization 强拉回的子页。",
"确认 `SR-0` / `SR-1` 下 `Staff > Clef` 入口都会消失；`SR-1` 还应继续隐藏 `Piano > Rows and movement`，而 `SR-0` 仍保留后台钢琴配置入口。",
"确认 `Exercise > Mode` 页的 subtitle 继续明确包含 `SR-2`；切到 `SR-2` 后，`Exercise Mode` 选中态会稳定落在 `SR-2`，而不是回退到 `SR-1` 或 `Sequence`。",
"确认切到 `SR-2` 后，settings root 会像 `SR-1` 一样移除 `Accessories` 分区与无效 exercise 子页，并继续隐藏 `Staff > Clef` 与 `Piano > Rows and movement`，避免固定项被 UI 暴露出来。",
"确认 `Debug` 分区包含 `Component Bounds` 与 `Side Container Borders` 两个开关；切换 `Side Container Borders` 时 side 布局的红/蓝容器边框会立即显示或隐藏。"
```

## 验证与诊断

### `ReadLints`

- 当前 IDE 仍报旧的 `SourceKit` 误诊，集中在 `SettingsNavigationValidation.swift`
- 本轮没有为了压这个误诊去改代码，因为同一轮双端编译与双端启动验证均已通过

```bash
# 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
# 函数名/符号: ReadLints / SettingsNavigationValidationRunner.makeFixtures()
# 功能说明: 当前 IDE 仍报 19 条 `Cannot find ... in scope (SourceKit)`；
# 这些诊断集中指向已在其它 split validation 文件中定义的 helper，现象与前面阶段一致。
ReadLints:
- SettingsNavigationValidation.swift: 19 errors
- Cannot find 'validateRootRouteItemsMatchPanelSections' in scope
- Cannot find 'validateSplitSectionsProduceExpectedPageTree' in scope
- Cannot find 'validatePlayRootTreeKeepsOnlyPianoPages' in scope
- Cannot find 'validateRootModeSwitchPreservesExerciseTreeAndState' in scope
- Cannot find 'validateSR0RootTreeDropsInvalidExerciseAndAccessoryRoutes' in scope
- Cannot find 'validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes' in scope
- Cannot find 'validateSR2RootTreeDropsInvalidExerciseAndAccessoryRoutes' in scope
- Cannot find 'validatePositionPromptSectionVisibilityTracksExerciseMode' in scope
- Cannot find 'validateFretboardViewportRouteVisibilityTracksDisplayMode' in scope
- Cannot find 'validateVerticalViewportGateTracksFretboardContractOnly' in scope
- Cannot find 'validateFretboardStringThicknessOptionTracksState' in scope
- Cannot find 'validateExerciseAndAccessoryRowsMatchStage7Capabilities' in scope
- Cannot find 'validateReconciledPathFallsBackToExistingParent' in scope
- Cannot find 'validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates' in scope
- Cannot find 'validateSR0SettingsStateFreezesFixedPresentationOptions' in scope
- Cannot find 'validateSR1SettingsStateFreezesFixedPresentationOptions' in scope
- Cannot find 'validateSR2SettingsStateFreezesFixedPresentationOptions' in scope
- Cannot find 'validateReservedRouteTitlesRemainStable' in scope
- Cannot find 'validateReservedAccessibilityIdentifiersRemainStable' in scope
```

### 双端 `xcodebuild`

```bash
# 文件路径: N/A（命令行构建验证）
# 函数名/符号: xcodebuild -project NoteMaster_Ver_1.xcodeproj -scheme NoteMaster_Ver_1
# 功能说明: 阶段 5 的 4 个 shared validation 文件改完后，双端 Debug 构建都成功。
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild \
  -project "NoteMaster_Ver_1.xcodeproj" \
  -scheme "NoteMaster_Ver_1" \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "/tmp/NoteMaster_Ver_1_stage5_mac" build
** BUILD SUCCEEDED **

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild \
  -project "NoteMaster_Ver_1.xcodeproj" \
  -scheme "NoteMaster_Ver_1" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -derivedDataPath "/tmp/NoteMaster_Ver_1_stage5_ios" build
** BUILD SUCCEEDED **
```

### 双端 `startup-validation`

```bash
# 文件路径: N/A（命令行启动验证）
# 函数名/符号: NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation
# 功能说明: 阶段 5 涉及的 3 条 validation 链路在 iOS / macOS 上均通过；
# 其中 `sr_modes_freeze_staff_to_piano_policy_contracts`、`sr2_root_tree_drops_invalid_exercise_and_accessory_routes`
# 与 `sr2_settings_state_freezes_fixed_presentation_options` 都明确返回 0 issue。
[ExerciseCompositionValidation][macOS] fixture end name=sr_modes_freeze_staff_to_piano_policy_contracts issues=0
[ExerciseCompositionValidation][macOS] automated=PASS fixtures=37
[ExerciseCompositionValidation][macOS] runAndReportIfNeeded end passing=true
[SettingsNavigationValidation][macOS] fixture end name=sr2_root_tree_drops_invalid_exercise_and_accessory_routes issues=0
[SettingsNavigationValidation][macOS] fixture end name=sr2_settings_state_freezes_fixed_presentation_options issues=0
[SettingsNavigationValidation][macOS] automated=PASS fixtures=19
[SettingsNavigationValidation][macOS] runAndReportIfNeeded end passing=true
[FretboardValidation][macOS] automated=PASS fixtures=7
[FretboardValidation][macOS] runAndReportIfNeeded end passing=true

[ExerciseCompositionValidation][iOS] fixture end name=sr_modes_freeze_staff_to_piano_policy_contracts issues=0
[ExerciseCompositionValidation][iOS] automated=PASS fixtures=37
[ExerciseCompositionValidation][iOS] runAndReportIfNeeded end passing=true
[SettingsNavigationValidation][iOS] fixture end name=sr2_root_tree_drops_invalid_exercise_and_accessory_routes issues=0
[SettingsNavigationValidation][iOS] fixture end name=sr2_settings_state_freezes_fixed_presentation_options issues=0
[SettingsNavigationValidation][iOS] automated=PASS fixtures=19
[SettingsNavigationValidation][iOS] runAndReportIfNeeded end passing=true
[FretboardValidation][iOS] automated=PASS fixtures=7
[FretboardValidation][iOS] runAndReportIfNeeded end passing=true
```

## 收口说明

- 阶段 5 到这里的真实代码变更已经完整落盘到本文件
- 这份记录只覆盖 shared validation 聚合、手工 checklist 和回归矩阵，不包含阶段 4 的 runtime smoke 代码
- 当前工作区依然保持未提交状态

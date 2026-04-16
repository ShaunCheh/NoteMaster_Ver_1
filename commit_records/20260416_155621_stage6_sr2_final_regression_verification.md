# 20260416_155621_stage6_sr2_final_regression_verification

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260416_155621`
- 记录依据：基于当前工作区 `git status --short`、`git diff --stat`、阶段 6 实际跑过的 `ReadLints`、双端 `xcodebuild`、双端 `startup-validation`、以及 `SR-0 / SR-1 / SR-2` 双端 runtime smoke 结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md` 实施阶段 6 的真实落地结果；阶段 6 的目标是做最终回归验证，而不是继续改代码
- 重要说明：
- 本轮没有修改任何 `Swift` 源文件；`git status --short` 与 `git diff --stat` 在创建本记录前均为空
- 因为没有代码修改，所以本次“修改前 / 修改后”的核心差异不是源码，而是“阶段 6 验证尚未执行”与“阶段 6 验证全部通过”这两个状态
- 本记录文件本身是新增 markdown，不计入“阶段 6 无代码 diff”的结论
- `ReadLints` 仍只报 `SettingsNavigationValidation.swift` 的既有 `19` 条 `SourceKit` 误报，没有新增真实编译错误
- `macOS startup-validation` 首次在沙箱中运行时仍出现既有环境问题：进程直接 `exit 134` 且无有效输出；随后以无沙箱权限重跑通过，因此如实记录为环境问题，不视为代码回归
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：无
- 统计口径说明：
- 当前 `git status --short` 为空，`git diff --stat` 为空，因此阶段 6 本轮没有任何待提交代码改动
- 本次实际代码修改文件：无
- 本次确认但未修改的关键文件：
- `.cursor/plans/sr2两行钢琴_4531b6e9.plan.md`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- 验证结果：
- `ReadLints`：当前仍报 `19` 条 `SourceKit` 误报，全部集中在 `SettingsNavigationValidation.swift`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage6_mac" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage6_ios" build`：`BUILD SUCCEEDED`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：macOS 最终运行结果为 `PASS scenario=startup_validation`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation`：iOS Simulator 最终运行结果为 `PASS scenario=startup_validation`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer`：macOS 运行结果为 `PASS scenario=sr0_note_strip_answer finalMode=single stripVisible=true`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer`：iOS Simulator 运行结果为 `PASS scenario=sr0_note_strip_answer finalMode=single stripVisible=true`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：macOS 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：iOS Simulator 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer`：macOS 运行结果为 `PASS scenario=sr2_piano_answer finalMode=single pianoVisible=false`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer`：iOS Simulator 运行结果为 `PASS scenario=sr2_piano_answer finalMode=single pianoVisible=false`
- 本次没做的事情：
- 没有修改任何 `Swift` 文件
- 没有修改 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md`
- 没有修改任何旧的 markdown 记录文件
- 没有提交代码

## 本次结论

- 阶段 6 的真实落地结果是：`SR-2` 方案三在当前代码基线上已经完成最终回归验证收口，不需要再补新的修复代码
- `SR-0 / SR-1 / SR-2` 三条 SR 模式链路在同一轮回归中都通过了 shared validation、双端构建和双端 runtime smoke
- family 收口没有污染旧模式：`SR-0` 仍是双行 `strip`；`SR-1` 仍是单行 `piano + pitchClass`；`SR-2` 仍是两行 `piano + exactNote`

## 状态变化 1：阶段 6 前后工作区都没有代码 diff

### 修改前

- 进入阶段 6 前，代码层已经在前五个阶段收口完成；这一步的任务是“验证”，不是“继续改 Swift”

```bash
# 文件路径: 仓库工作区
# 函数名/符号: git status --short / git diff --stat
# 功能说明: 阶段 6 开始前，工作区已经是 clean 状态，没有待提交代码改动。
# git status --short
# <空输出>
#
# git diff --stat
# <空输出>
```

### 修改后

- 阶段 6 的 shared validation、双端构建和三条 SR smoke 全部跑完后，在创建本记录前工作区仍然是 clean 状态
- 这说明阶段 6 没有引入新的源码修改，新增的只有验证结论本身

```bash
# 文件路径: 仓库工作区
# 函数名/符号: git status --short / git diff --stat
# 功能说明: 阶段 6 全部验证结束后、创建本记录前再次检查工作区，结果仍然没有任何代码 diff。
# git status --short
# <空输出>
#
# git diff --stat
# <空输出>
```

## 状态变化 2：IDE lint 快照未变，但没有真实编译回归

### 修改前

- 前面阶段已经出现过 `SettingsNavigationValidation.swift` 的 `SourceKit` 诊断滞后
- 阶段 6 的预期不是“消灭 IDE 误报”，而是确认它没有演化成真实构建失败

### 修改后

- 重新执行 `ReadLints` 后，问题数量和分布没有变化：仍然只有同一组 `19` 条 `SourceKit` 误报
- 这组误报随后被双端 `xcodebuild` 与双端 `startup-validation` 证明不是实际编译回归

```bash
# 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
# 函数名/符号: ReadLints / SettingsNavigationValidationRunner.makeFixtures()
# 功能说明: 阶段 6 重跑 lint 后，仍只有既有的 SourceKit 索引滞后；
# 误报全部集中在 split validation helper 的作用域解析，不代表真实构建失败。
ReadLints:
- 19 errors
- Cannot find 'validateRootRouteItemsMatchPanelSections' in scope (SourceKit)
- Cannot find 'validateSplitSectionsProduceExpectedPageTree' in scope (SourceKit)
- Cannot find 'validatePlayRootTreeKeepsOnlyPianoPages' in scope (SourceKit)
- Cannot find 'validateRootModeSwitchPreservesExerciseTreeAndState' in scope (SourceKit)
- Cannot find 'validateSR0RootTreeDropsInvalidExerciseAndAccessoryRoutes' in scope (SourceKit)
- Cannot find 'validateSR1RootTreeDropsInvalidExerciseAndAccessoryRoutes' in scope (SourceKit)
- Cannot find 'validateSR2RootTreeDropsInvalidExerciseAndAccessoryRoutes' in scope (SourceKit)
- Cannot find 'validatePositionPromptSectionVisibilityTracksExerciseMode' in scope (SourceKit)
- Cannot find 'validateFretboardViewportRouteVisibilityTracksDisplayMode' in scope (SourceKit)
- Cannot find 'validateVerticalViewportGateTracksFretboardContractOnly' in scope (SourceKit)
- Cannot find 'validateFretboardStringThicknessOptionTracksState' in scope (SourceKit)
- Cannot find 'validateExerciseAndAccessoryRowsMatchStage7Capabilities' in scope (SourceKit)
- Cannot find 'validateReconciledPathFallsBackToExistingParent' in scope (SourceKit)
- Cannot find 'validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates' in scope (SourceKit)
- Cannot find 'validateSR0SettingsStateFreezesFixedPresentationOptions' in scope (SourceKit)
- Cannot find 'validateSR1SettingsStateFreezesFixedPresentationOptions' in scope (SourceKit)
- Cannot find 'validateSR2SettingsStateFreezesFixedPresentationOptions' in scope (SourceKit)
- Cannot find 'validateReservedRouteTitlesRemainStable' in scope (SourceKit)
- Cannot find 'validateReservedAccessibilityIdentifiersRemainStable' in scope (SourceKit)
```

## 验证 1：双端构建与 shared validation 全通过

### 修改前

- 阶段 6 开始前，计划要求重新确认 `ExerciseCompositionValidation`、`SettingsNavigationValidation`、`FretboardValidation` 三条 shared validation 链在当前二进制上仍然一起通过
- 同时还要确认前面阶段改过的 shared / settings / controller / app delegate 文件在双端构建上没有隐藏回归

### 修改后

- 双端 `xcodebuild` 均为 `BUILD SUCCEEDED`
- 双端 `startup-validation` 中，`FretboardValidation(7)`、`SettingsNavigationValidation(19)`、`ExerciseCompositionValidation(37)` 全部 `PASS`
- `macOS startup-validation` 首次在沙箱内直接运行时仍然 `exit 134`，随后使用无沙箱权限重跑通过；该现象与前面阶段一致，属于环境问题

```bash
# 文件路径: 工程级验证命令
# 函数名/符号: xcodebuild / xcrun simctl / NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation
# 功能说明: 阶段 6 的 shared validation 与构建命令链；先构建，再跑双端 startup-validation。
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage6_mac" build
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage6_ios" build
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl boot "iPhone 17" >/dev/null 2>&1 || true
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl bootstatus "iPhone 17" -b
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation "/tmp/NoteMaster_Ver_1_stage6_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl install booted "/tmp/NoteMaster_Ver_1_stage6_ios/Build/Products/Debug-iphonesimulator/NoteMaster_Ver_1.app"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/ecb55d67-f1f7-4374-99ed-fd90fdb92f3c.txt
# 函数名/符号: xcodebuild -destination "platform=macOS"
# 功能说明: macOS Debug 构建日志摘录。
** BUILD SUCCEEDED **
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/6104d118-c331-421f-ac2c-f6908d5087e1.txt
# 函数名/符号: xcodebuild -destination "platform=iOS Simulator,name=iPhone 17"
# 功能说明: iOS Simulator Debug 构建日志摘录。
** BUILD SUCCEEDED **
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/81338bb1-4db3-4d5b-b008-8246a106eaf8.txt
# 函数名/符号: NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation
# 功能说明: macOS startup-validation 最终通过日志摘录；三条 shared validation 链与启动 smoke 均为 PASS。
[FretboardValidation][macOS] automated=PASS fixtures=7
[FretboardValidation][macOS] runAndReportIfNeeded end passing=true
[SettingsNavigationValidation][macOS] automated=PASS fixtures=19
[SettingsNavigationValidation][macOS] runAndReportIfNeeded end passing=true
[ExerciseCompositionValidation][macOS] automated=PASS fixtures=37
[ExerciseCompositionValidation][macOS] runAndReportIfNeeded end passing=true
[RuntimeSmoke][macOS] PASS scenario=startup_validation
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/96090775-08c3-40e0-a98a-8724f10b57b3.txt
# 函数名/符号: SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation
# 功能说明: iOS startup-validation 最终通过日志摘录；三条 shared validation 链与启动 smoke 均为 PASS。
[FretboardValidation][iOS] automated=PASS fixtures=7
[FretboardValidation][iOS] runAndReportIfNeeded end passing=true
[SettingsNavigationValidation][iOS] automated=PASS fixtures=19
[SettingsNavigationValidation][iOS] runAndReportIfNeeded end passing=true
[ExerciseCompositionValidation][iOS] automated=PASS fixtures=37
[ExerciseCompositionValidation][iOS] runAndReportIfNeeded end passing=true
[RuntimeSmoke][iOS] PASS scenario=startup_validation
```

```bash
# 文件路径: macOS startup-validation 首次沙箱运行
# 函数名/符号: NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation
# 功能说明: 首次在沙箱内直接运行 macOS app 时，仍命中既有环境问题；
# 没有产出有效日志，进程直接以 exit 134 退出，随后用无沙箱权限重跑通过。
sandbox run -> exit 134
unsandboxed rerun -> PASS scenario=startup_validation
```

## 验证 2：`SR-0 / SR-1 / SR-2` 最终 runtime smoke 全通过

### 修改前

- 阶段 6 的最后一段要求按 `SR-0 -> SR-1 -> SR-2` 顺序把三条 smoke 都重新跑一遍
- 核心目的不是再证明 `SR-2` 能跑，而是确认 `SR-2` 的 family 收口没有顺手带坏 `SR-0 / SR-1`

### 修改后

- `SR-0` 双端 smoke 通过，说明主场景仍是双行 `strip`，没有被 `staffToPiano family` 污染
- `SR-1` 双端 smoke 通过，说明它仍是单行 `piano`，切回 `single` 后 `pianoVisible=false`
- `SR-2` 双端 smoke 通过，说明两行 `piano + exactNote` 路径仍然成立，切回 `single` 后清理也通过

```bash
# 文件路径: 工程级验证命令
# 函数名/符号: NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer / sr1-piano-answer / sr2-piano-answer
# 功能说明: 阶段 6 按 SR 回归顺序依次执行三条双端 smoke；
# 先验证 `SR-0`，再验证 `SR-1`，最后验证 `SR-2`。
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer "/tmp/NoteMaster_Ver_1_stage6_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"

NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer "/tmp/NoteMaster_Ver_1_stage6_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"

NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer "/tmp/NoteMaster_Ver_1_stage6_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/57af1cb1-264e-4174-b3f9-f1d5d046e3b8.txt
# 函数名/符号: NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer
# 功能说明: macOS `SR-0` smoke 通过，说明切回 single 后 strip 虽可作为 accessory 保留，但主答题面已正确退出。
[RuntimeSmoke][macOS] PASS scenario=sr0_note_strip_answer finalMode=single stripVisible=true
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/b6e7fae6-a8ca-45da-bad7-089aed4fb299.txt
# 函数名/符号: SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer
# 功能说明: iOS `SR-0` smoke 通过，与 macOS 结果一致。
[RuntimeSmoke][iOS] PASS scenario=sr0_note_strip_answer finalMode=single stripVisible=true
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/2bf8531a-fb70-4ee3-a6e8-c834e344c4d8.txt
# 函数名/符号: NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer
# 功能说明: macOS `SR-1` smoke 通过，说明 family 收口后它仍保持单行 piano 路径。
[RuntimeSmoke][macOS] PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/a2143e67-4754-4e7d-ae08-408ec5ca4130.txt
# 函数名/符号: SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer
# 功能说明: iOS `SR-1` smoke 通过，与 macOS 结果一致。
[RuntimeSmoke][iOS] PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/d2887560-d5b6-4f1d-af99-73b4a4d69f7f.txt
# 函数名/符号: NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer
# 功能说明: macOS `SR-2` smoke 通过，说明两行 piano 与 exact-note 判题链继续成立。
[RuntimeSmoke][macOS] PASS scenario=sr2_piano_answer finalMode=single pianoVisible=false
```

```bash
# 文件路径: /Users/shaun/.cursor/projects/Users-shaun-Library-Mobile-Documents-com-apple-CloudDocs-Develop-NoteMaster-Ver-1/agent-tools/1f034041-ab1f-456d-b061-c966cacdb755.txt
# 函数名/符号: SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer
# 功能说明: iOS `SR-2` smoke 通过，与 macOS 结果一致。
[RuntimeSmoke][iOS] PASS scenario=sr2_piano_answer finalMode=single pianoVisible=false
```

## 对后续阶段的直接意义

- `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md` 的 6 个阶段都已经按计划落地完成
- 当前不需要再为了阶段 6 补新的修复代码；如果后面还有变更，应该是新的需求，而不是本计划遗留
- 这份记录的核心价值不是“列出代码 diff”，而是如实确认：在没有新增代码改动的前提下，阶段 6 把最终回归验证顺序完整跑通了

## 工程级验证命令清单

```bash
# 文件路径: 工程级验证命令
# 函数名/符号: date / git status / git diff / ReadLints / xcodebuild / startup-validation / SR runtime smoke
# 功能说明: 本记录对应的实际命令集合；阶段 6 没有代码修改，因此主要是状态采集与回归验证命令。
date +"%Y%m%d_%H%M%S"
git status --short
git diff --stat

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage6_mac" build
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage6_ios" build
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl boot "iPhone 17" >/dev/null 2>&1 || true
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl bootstatus "iPhone 17" -b
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation "/tmp/NoteMaster_Ver_1_stage6_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl install booted "/tmp/NoteMaster_Ver_1_stage6_ios/Build/Products/Debug-iphonesimulator/NoteMaster_Ver_1.app"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"

NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer "/tmp/NoteMaster_Ver_1_stage6_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer "/tmp/NoteMaster_Ver_1_stage6_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer "/tmp/NoteMaster_Ver_1_stage6_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
```

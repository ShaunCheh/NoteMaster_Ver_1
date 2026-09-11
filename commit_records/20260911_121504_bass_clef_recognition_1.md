# 20260911_121504_bass_clef_recognition_1

- 时间戳来源：系统自带命令 `date '+%Y%m%d_%H%M%S%n%Y-%m-%d %H:%M:%S %z'`
- 时间戳结果：`20260911_121504`
- 本地时间：`2026-09-11 12:15:04 +0800`
- 记录范围：在 `Settings > Exercise > Mode` 新增 `Bass Clef Recognition-1`，其训练行为与 `SR-1` 相同，唯一模式差异是将固定谱号由 Treble Clef 改为 Bass Clef
- 记录依据：创建本记录前的 `git status --short`、`git diff --name-status`、`git diff --stat`、`git diff --numstat`、按文件检查的当前 Changes、最终源代码、双平台构建输出、启动验证输出及 macOS BCR-1 runtime smoke 输出
- 本记录不粘贴原始 `git diff`，而是按当前实际代码归纳修改前后的合同、接线、界面入口与验证结果
- 创建本记录前的代码改动统计：`17 files changed, 490 insertions(+), 131 deletions(-)`
- 本 Markdown 文件是本轮记录步骤唯一新增的文件，不计入上述代码改动统计

```bash
# 文件路径: /Users/shaun/cloudDev/NoteMaster_Ver_1（工程命令记录）
# 命令/函数名: 系统 date 命令
# 功能说明: 生成本记录文件名和标题使用的时间戳；以下结果来自实际命令输出。
date '+%Y%m%d_%H%M%S%n%Y-%m-%d %H:%M:%S %z'

# 实际输出:
20260911_121504
2026-09-11 12:15:04 +0800
```

## 1. 创建记录前的实际 Changes

创建本记录前，工作区包含以下 17 个已修改 Swift 文件：

- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`：新增 BCR-1 runtime smoke 启动入口
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`：新增 BCR-1 smoke wrapper，并把单行 pitch-class smoke 与预期谱号参数化
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`：镜像新增 BCR-1 runtime smoke 启动入口
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`：镜像新增 BCR-1 smoke wrapper，并参数化共享 smoke runner
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`：在 Exercise Mode 导航副标题中加入新模式
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`：注册 BCR-1 settings/navigation 夹具并补充手工回归项
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`：验证 BCR-1 固定模式会裁掉无效设置路由
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`：验证入口、选中态、Bass Clef、单行钢琴及固定项隐藏规则
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`：新增 BCR-1 action、标题、无障碍说明、选中态和状态写回
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`：新增 `.bcr1`，并把原 SR piano reading 合同扩展为可参数化谱号的 piano sequence recognition 合同
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`：把 BCR-1 接入 quarter-note sequence 答题路由
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`：把 BCR-1 纳入固定场景 normalization
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`：注册扩展后的 piano recognition 合同夹具
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`：验证 BCR-1 与 SR-1 仅在谱号上分叉
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`：将只以 SR 命名的钢琴主场景常量泛化为 recognition family 常量
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`：补齐 BCR-1 的 legacy fallback 穷举分支
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`：补齐 BCR-1 合同、Bass sequence 生成及手工回归验证

创建记录前没有其它未提交文件；上述 Changes 均属于本次 BCR-1 实现。

## 2. 修改目标与最终模式合同

`Bass Clef Recognition-1` 的最终合同为：

- 内部模式：`TrainerExerciseMode.bcr1`
- Settings 标题：`Bass Clef Recognition-1`
- 出题内核：继续复用 quarter-note sequence kernel
- 主场景：`Staff -> Piano`
- 主布局：`stacked`
- 谱号：固定 `.bass`
- 判题策略：固定 `.pitchClass`，即忽略八度
- 钢琴行数：固定 `1`
- 钢琴移动范围：固定 `.rowOnly`
- `noteCount` 与 `includesAccidentals`：继续保留当前 sequence 配置，不被 BCR-1 强行覆盖
- 与 SR-1 的实际差异：只有固定谱号不同；其余固定合同由同一个 `singleRowPitchClass(clef:)` 构造入口生成

## 3. Shared 模式合同：从固定 Treble SR family 改为可参数化谱号

### 3.1 修改前

修改前只存在 `SR-1 / SR-2` piano reading family，而且合同构造器将 Treble Clef 写死。直接把 BCR-1 塞进该类型会造成命名失真，也会让 Bass Clef 只能在外围添加特殊分支。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/符号名: TrainerExerciseMode, TrainerSRPianoReadingMode, TrainerSRPianoReadingContract.init
// 功能说明: 修改前 exercise mode 没有 BCR-1；SR piano 合同内部把谱号固定为 treble。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case p2
    case positionPrompt
    case fr0
    case sr0
    case sr1
    case sr2
}

enum TrainerSRPianoReadingMode: Equatable, Hashable, Sendable {
    case sr1
    case sr2
}

struct TrainerSRPianoReadingContract: Equatable, Sendable {
    init(
        answerPolicy: TrainerSequenceAnswerPolicy,
        pianoRowCount: Int,
        pianoMovementScope: PianoMovementScope
    ) {
        // 修改前谱号无法由模式合同调用方指定。
        fixedSequenceClef = .treble
        fixedExerciseLayoutPreferences = .srPianoAnswer
        fixedSequenceAnswerPolicy = answerPolicy
        fixedPianoRowCount = pianoRowCount
        fixedPianoMovementScope = pianoMovementScope
    }
}
```

### 3.2 修改后

模式 family 被泛化为 `TrainerPianoSequenceRecognitionMode`。谱号成为集中合同的一部分，SR-1 与 BCR-1 都调用 `singleRowPitchClass(clef:)`，从结构上保证两者只传入不同 clef。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/符号名: TrainerExerciseMode, TrainerPianoSequenceRecognitionMode.contract
// 功能说明: 新增 bcr1，并让 SR-1/BCR-1 复用同一个单行 pitch-class 合同构造器。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case p2
    case positionPrompt
    case fr0
    case sr0
    case sr1
    case sr2
    case bcr1
}

enum TrainerPianoSequenceRecognitionMode: Equatable, Hashable, Sendable {
    case sr1
    case sr2
    case bcr1

    var contract: TrainerPianoSequenceRecognitionContract {
        switch self {
        case .sr1:
            return .singleRowPitchClass(clef: .treble)
        case .sr2:
            return TrainerPianoSequenceRecognitionContract(
                clef: .treble,
                answerPolicy: .exactNote,
                pianoRowCount: 2,
                pianoMovementScope: .rowOnly
            )
        case .bcr1:
            return .singleRowPitchClass(clef: .bass)
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/符号名: TrainerPianoSequenceRecognitionContract.init, singleRowPitchClass(clef:)
// 功能说明: clef 被参数化；单行 pitch-class 的其它字段只定义一次，防止 SR-1 与 BCR-1 后续漂移。
struct TrainerPianoSequenceRecognitionContract: Equatable, Sendable {
    let fixedSequenceClef: StaffClef
    let fixedExerciseLayoutPreferences: ExerciseLayoutPreferences
    let fixedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy
    let fixedPianoRowCount: Int
    let fixedPianoMovementScope: PianoMovementScope

    init(
        clef: StaffClef,
        answerPolicy: TrainerSequenceAnswerPolicy,
        pianoRowCount: Int,
        pianoMovementScope: PianoMovementScope
    ) {
        fixedSequenceClef = clef
        fixedExerciseLayoutPreferences = .pianoRecognitionAnswer
        fixedSequenceAnswerPolicy = answerPolicy
        fixedPianoRowCount = pianoRowCount
        fixedPianoMovementScope = pianoMovementScope
    }

    static func singleRowPitchClass(
        clef: StaffClef
    ) -> TrainerPianoSequenceRecognitionContract {
        TrainerPianoSequenceRecognitionContract(
            clef: clef,
            answerPolicy: .pitchClass,
            pianoRowCount: 1,
            pianoMovementScope: .rowOnly
        )
    }
}
```

### 3.3 固定 accessor 与 sequence kernel 接线

修改前，相关 accessor 只识别 `.sr1 / .sr2`；修改后 `.bcr1` 从同一集中合同取得 clef、layout、answer policy、row count 和 movement scope，并被归入 sequence kernel。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/符号名: TrainerExerciseMode.fixedSequenceClef, fixedSequenceAnswerPolicy, fixedExerciseLayoutPreferences, fixedPianoRowCount, fixedPianoMovementScope, usesQuarterNoteSequenceKernel
// 功能说明: BCR-1 的全部固定值都通过 recognition contract 暴露，controller/policy 无需写一套 Bass 特例。
var fixedSequenceClef: StaffClef? {
    switch self {
    case .sr1, .sr2, .bcr1:
        return pianoSequenceRecognitionContract?.fixedSequenceClef
    case .sr0:
        return .treble
    case .single, .sequence, .p2, .positionPrompt, .fr0:
        return nil
    }
}

var usesQuarterNoteSequenceKernel: Bool {
    switch self {
    case .sequence, .p2, .sr0, .sr1, .sr2, .bcr1:
        return true
    case .single, .positionPrompt, .fr0:
        return false
    }
}

// fixedSequenceAnswerPolicy / fixedExerciseLayoutPreferences /
// fixedPianoRowCount / fixedPianoMovementScope 使用相同的 family 委托方式。
```

## 4. 主场景、Normalization 与答题路由

### 4.1 Layout 常量改名

修改前固定主钢琴场景名为 `.srPianoAnswer`，名称无法准确覆盖 BCR-1；修改后改为 `.pianoRecognitionAnswer`。其实际布局值没有改变。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数/符号名: ExerciseLayoutPreferences.pianoRecognitionAnswer
// 功能说明: 固定 recognition 主场景仍是 staffToPiano + stacked，且不把主钢琴误当成 accessory。
static let pianoRecognitionAnswer = ExerciseLayoutPreferences(
    compositionPreset: .staffToPiano,
    layoutPreset: .stacked,
    accessoryPresentation: .docked,
    isNaturalNoteStripVisible: false,
    isPianoAccessoryVisible: false,
    isAccessoryExpanded: true
)
```

### 4.2 修改前的模式分发

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名: ExerciseAnswerRouter.route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能说明: 修改前 quarter-note sequence 路由没有 BCR-1，新增模式会落入未覆盖的模式矩阵。
switch trainerDisplayState.exerciseMode {
case .single, .fr0:
    // ... singleCoverage 路由 ...
case .sequence, .p2, .sr0, .sr1, .sr2:
    // ... quarterNoteSequence 路由 ...
case .positionPrompt:
    // ... positionPrompt 路由 ...
}
```

### 4.3 修改后的模式分发

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名: ExerciseAnswerRouter.route(_:presentationState:trainerDisplayState:fretboardConfiguration:)
// 功能说明: BCR-1 与 SR-1 共用 sequence 答题链；notePitch 输入会保留完整音高，再按合同的 pitchClass 策略比较。
switch trainerDisplayState.exerciseMode {
case .single, .fr0:
    // ... singleCoverage 路由保持不变 ...
case .sequence, .p2, .sr0, .sr1, .sr2, .bcr1:
    // ... 解析 ResolvedSequenceAnswer 并路由到 quarterNoteSequence ...
case .positionPrompt:
    // ... positionPrompt 路由保持不变 ...
}
```

`ExerciseCompositionPolicy+Normalization.swift` 与 `LegacyPageLayoutAdapter.swift` 的穷举分支同步加入 `.bcr1`。实际结果是：

- 任意外部请求的 composition/layout 都会被 BCR-1 的 fixed contract 收敛到 `.pianoRecognitionAnswer`
- legacy 页面模型只保留 `.default` 兼容投影，不伪造不存在的 legacy piano 组合
- BCR-1 不允许 accessory piano promotion
- `noteCount` 与 `includesAccidentals` 不被 normalization 改写

## 5. Settings 入口与固定项隐藏

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号名: SettingsChoiceRowID.actionIDs
// 功能说明: 修改前 Exercise Mode 列表中不存在 BCR-1。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeP2,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModeSr2,
        .setExerciseModeFr0,
        .setExerciseModePositionPrompt
    ]
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号名: SettingsChoiceRowID.actionIDs, SettingsActionID.setExerciseModeBcr1
// 功能说明: 新选项位于 SR-2 后、FR-0 前；点击后写回 TrainerExerciseMode.bcr1。
case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModeP2,
        .setExerciseModeSr0,
        .setExerciseModeSr1,
        .setExerciseModeSr2,
        .setExerciseModeBcr1,
        .setExerciseModeFr0,
        .setExerciseModePositionPrompt
    ]
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号名: SettingsActionID.title, accessibilityLabel, isSelected(in:), apply(to:)
// 功能说明: 新 action 拥有完整标题、无障碍语义、选中态以及 trainer state 写回路径。
case .setExerciseModeBcr1:
    return "Bass Clef Recognition-1"

case .setExerciseModeBcr1:
    return "Train bass-clef sequence recognition with a single-row piano answer surface"

case .setExerciseModeBcr1:
    return stateContext.trainerDisplayState.exerciseMode == .bcr1

case .setExerciseModeBcr1:
    displayState.setExerciseMode(.bcr1)
```

`SettingsNavigationSnapshotBuilder.childPageSpecs(for:)` 的 Mode 副标题由：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: SettingsNavigationSnapshotBuilder.childPageSpecs(for:)
// 功能说明: 修改前 Exercise Mode 导航副标题未列出 BCR-1。
let subtitleBefore =
    "Single, sequence, P-2, SR-0, SR-1, SR-2, FR-0, or position"
```

改为：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: SettingsNavigationSnapshotBuilder.childPageSpecs(for:)
// 功能说明: 修改后副标题按实际选项顺序加入 Bass Clef Recognition-1。
let subtitleAfter =
    "Single, sequence, P-2, SR-0, SR-1, SR-2, Bass Clef Recognition-1, FR-0, or position"
```

本次没有修改 `SettingsPanelSnapshotBuilder.swift`。BCR-1 通过现有通用规则自动获得与 SR-1 相同的固定项隐藏行为：

- 隐藏 Exercise Composition
- 隐藏 Exercise Layout
- 移除 Accessories 分区
- 隐藏 Staff Clef 选择
- 隐藏 Piano Rows
- 隐藏 Piano Movement
- 保留 Staff clef layout sliders
- 保留 Piano White Key Style 与 Snap Drag

这些隐藏规则来自 `.fixedExerciseLayoutPreferences`、`.fixedSequenceClef`、`.fixedPianoRowCount` 和 `.fixedPianoMovementScope`，没有新增按 `.bcr1` 判断的 UI 特例。

## 6. 双平台 Controller 与 runtime smoke

### 6.1 修改前

原有共享钢琴 smoke runner 名为 `runSRPianoAnswerSmokeTest`，并在 runner 内把 `.treble` 写死，因此不能真实验证 Bass Clef 模式。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: runSRPianoAnswerSmokeTest(in:scenarioName:switchStepName:switchAction:expectedMode:...)
// 功能说明: 修改前 runner 只能验证 Treble Clef；macOS 对应函数具有相同限制。
private func runSRPianoAnswerSmokeTest(
    in window: UIWindow,
    scenarioName: String,
    switchStepName: String,
    switchAction: SettingsActionID,
    expectedMode: TrainerExerciseMode,
    expectedAnswerPolicy: TrainerSequenceAnswerPolicy,
    expectedPianoRowCount: Int,
    // ... 其余参数 ...
) {
    // ... 切换模式并读取 resolvedSequenceConfiguration ...
    guard resolvedSequenceConfiguration.clef == .treble else {
        return "reason=clef_not_treble"
    }
}
```

### 6.2 修改后

iOS 与 macOS 分别新增 BCR-1 wrapper，并将 SR-1/BCR-1 的共同 pitch-class 行为收敛到 `runPitchClassPianoRecognitionSmokeTest`。底层 runner 政名为 `runPianoRecognitionAnswerSmokeTest`，同时增加 `expectedClef`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: runBCR1PianoAnswerSmokeTest(in:completion:)
// 功能说明: iOS BCR-1 smoke 通过参数声明新模式、Bass Clef 和对应 Settings action。
func runBCR1PianoAnswerSmokeTest(
    in window: UIWindow,
    completion: @escaping (Bool, String) -> Void
) {
    runPitchClassPianoRecognitionSmokeTest(
        in: window,
        scenarioName: "bcr1_piano_answer",
        switchStepName: "switch_to_bcr1",
        switchAction: .setExerciseModeBcr1,
        expectedMode: .bcr1,
        expectedClef: .bass,
        completion: completion
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: runBCR1PianoAnswerSmokeTest(in:completion:)
// 功能说明: macOS 镜像使用同一参数矩阵，避免双平台出现不同的 BCR-1 合同。
func runBCR1PianoAnswerSmokeTest(
    in window: NSWindow,
    completion: @escaping (Bool, String) -> Void
) {
    runPitchClassPianoRecognitionSmokeTest(
        in: window,
        scenarioName: "bcr1_piano_answer",
        switchStepName: "switch_to_bcr1",
        switchAction: .setExerciseModeBcr1,
        expectedMode: .bcr1,
        expectedClef: .bass,
        completion: completion
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: runPianoRecognitionAnswerSmokeTest(in:scenarioName:switchStepName:switchAction:expectedMode:expectedClef:...)
// 功能说明: 共享 runner 现在按调用方传入的 clef 验证实际 resolved configuration；macOS 使用镜像实现。
private func runPianoRecognitionAnswerSmokeTest(
    in window: UIWindow,
    scenarioName: String,
    switchStepName: String,
    switchAction: SettingsActionID,
    expectedMode: TrainerExerciseMode,
    expectedClef: StaffClef,
    expectedAnswerPolicy: TrainerSequenceAnswerPolicy,
    expectedPianoRowCount: Int,
    // ... 其余 smoke 参数 ...
) {
    // ... 切换模式并等待布局稳定 ...
    guard self.exerciseLayoutPreferences == .pianoRecognitionAnswer else {
        return "reason=layout_not_fixed"
    }
    guard resolvedSequenceConfiguration.clef == expectedClef else {
        return "reason=clef_not_expected"
    }
    // ... 继续验证 answer policy、surface、row count、movement 与答题反馈 ...
}
```

`iOSAppDelegate.swift` 与 `macOSAppDelegate.swift` 同步增加：

- 环境变量值：`bcr1-piano-answer`
- gate：`RuntimeSmokeScenario.shouldRunBCR1PianoAnswerSmoke`
- 启动分支：调度 `runBCR1PianoAnswerSmokeTest`
- iOS PASS 后使用 `exit(0)`；macOS PASS 后使用 `NSApp.terminate(nil)`
- FAIL 时继续使用现有 `fatalError(summary)` 约定

## 7. 自动化验证改动

### 7.1 Recognition 合同验证

`ExerciseCompositionValidationRunner.validateSRModesFreezeStaffToPianoPolicyContracts()` 改名为 `validatePianoRecognitionModesFreezeStaffToPianoPolicyContracts()`，夹具名同步从 SR 专用名称泛化为：

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures()
// 功能说明: 注册泛化后的 piano recognition policy validation 夹具。
let fixtureName =
    "piano_recognition_modes_freeze_staff_to_piano_policy_contracts"
```

该夹具现在同时验证：

- SR-1、SR-2、BCR-1 都属于统一 recognition family
- SR-1/SR-2 固定 `.treble`
- BCR-1 固定 `.bass`
- SR-1/BCR-1 固定 `.pitchClass + 1 row + rowOnly`
- SR-2 继续固定 `.exactNote + 2 rows + rowOnly`
- 三者共用 `.staffToPiano + stacked` 主场景
- 各固定 accessor 均委托到集中合同
- normalization 不篡改 `noteCount` 与 `includesAccidentals`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名: ExerciseCompositionValidationRunner.validatePianoRecognitionModesFreezeStaffToPianoPolicyContracts()
// 功能说明: 将 BCR-1 与 SR-1 的共同字段逐项比较，只允许 fixedSequenceClef 分叉。
if sr1Contract.fixedSequenceClef != .treble
    || sr2Contract.fixedSequenceClef != .treble
    || bcr1Contract.fixedSequenceClef != .bass {
    issues.append(
        issue(
            fixtureName,
            "识别模式谱号应固定为 SR-1 / SR-2 = treble、BCR-1 = bass。"
        )
    )
}

if sr1Contract.fixedPianoRowCount != 1
    || sr2Contract.fixedPianoRowCount != 2
    || bcr1Contract.fixedPianoRowCount != 1 {
    // ... 记录固定行数合同漂移 ...
}

if sr1Contract.fixedSequenceAnswerPolicy != .pitchClass
    || sr2Contract.fixedSequenceAnswerPolicy != .exactNote
    || bcr1Contract.fixedSequenceAnswerPolicy != .pitchClass {
    // ... 记录判题策略合同漂移 ...
}
```

### 7.2 Settings 与导航验证

新增两个启动期夹具：

- `bcr1_root_tree_drops_invalid_exercise_and_accessory_routes`
- `bcr1_settings_state_freezes_fixed_presentation_options`

它们验证：

- Settings mode 列表存在 `Bass Clef Recognition-1`
- 标题和 accessibility label 与模型一致
- 点击 action 后只选中 BCR-1
- resolved clef 为 `.bass`
- resolved answer policy 为 `.pitchClass`
- piano row count 为 `1`
- movement scope 为 `.rowOnly`
- Composition、Layout、Accessories、Clef、Rows、Movement 的隐藏规则与 SR-1 一致

### 7.3 Sequence 生成验证

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: FretboardValidationRunner.validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 用与 BCR-1 相反的请求值构造状态，确认 fixed contract 实际覆盖为 Bass + pitchClass，并生成 Bass sequence。
let bcr1DisplayState = TrainerDisplayState(
    exerciseMode: .bcr1,
    sequenceConfiguration: TrainerSequenceConfiguration(
        clef: .treble,
        noteCount: 5,
        includesAccidentals: true,
        answerPolicy: .exactNote
    )
)
let bcr1ResolvedSequenceConfiguration = bcr1DisplayState
    .resolvedSequenceConfiguration

var bcr1Trainer = FretboardNaturalNoteTrainerState(
    quarterNoteSequenceSpec:
        bcr1ResolvedSequenceConfiguration.quarterNoteSequenceSpec
)
let bcr1GeneratedSequence = bcr1Trainer.generateQuarterNoteSequence()

if bcr1GeneratedSequence.clef != .bass {
    record("BCR-1 生成的共享 sequence 应实际携带 bass clef。")
}
```

## 8. 实施过程中出现并修正的问题

实施中曾有两类中间构建失败，最终均已修正：

1. 将 family 类型由 `TrainerSRPianoReading*` 改名为 `TrainerPianoSequenceRecognition*` 后，旧 validation 仍引用旧符号。随后将这些验证整体迁移到新 family，并加入 BCR-1 断言。
2. 首次 iOS Simulator 构建时，新增验证错误读取了不存在的 `GeneratedNoteSequence.answerPolicy`。实际 answer policy 属于 resolved sequence configuration / session comparison contract，不属于 generated content；因此删除该错误读取，保留对 `bcr1ResolvedSequenceConfiguration.answerPolicy == .pitchClass` 的正确断言。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: FretboardValidationRunner.validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 中间错误代码把判题策略当成 GeneratedNoteSequence 的字段；该字段实际不存在。
// 最终代码中已删除下面这段错误访问：
if bcr1GeneratedSequence.answerPolicy != .pitchClass {
    record("BCR-1 生成的共享 sequence 应实际携带 pitchClass 判题策略。")
}
```

最终验证分别在正确所有者上检查：

- `bcr1ResolvedSequenceConfiguration.answerPolicy == .pitchClass`
- `bcr1GeneratedSequence.clef == .bass`
- runtime evaluation 的 `comparisonPolicy == .pitchClass`

## 9. 最终验证结果

### 9.1 静态检查

- 对本次涉及的 17 个 Swift 文件执行 IDE linter 检查
- 结果：无 linter 错误
- `git diff --check`：通过

### 9.2 macOS Debug 构建

```bash
# 文件路径: /Users/shaun/cloudDev/NoteMaster_Ver_1（工程验证命令）
# 命令/函数名: xcodebuild macOS Debug
# 功能说明: 使用独立 DerivedData 验证 shared、macOS controller、settings 与 smoke 接线。
xcodebuild \
  -project NoteMaster_Ver_1.xcodeproj \
  -scheme NoteMaster_Ver_1 \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/NoteMaster-BCR1-macOS-final \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- 最终结果：`** BUILD SUCCEEDED **`

### 9.3 iOS Simulator Debug 构建

```bash
# 文件路径: /Users/shaun/cloudDev/NoteMaster_Ver_1（工程验证命令）
# 命令/函数名: xcodebuild iOS Simulator Debug
# 功能说明: 构建通用 iOS Simulator 目标，验证 iOS AppDelegate/ViewController 与 shared 代码。
xcodebuild \
  -project NoteMaster_Ver_1.xcodeproj \
  -scheme NoteMaster_Ver_1 \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/NoteMaster-BCR1-iOS-final \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- 最终结果：`** BUILD SUCCEEDED **`
- 本次检查时没有 booted iOS Simulator，因此没有宣称执行过 iOS BCR-1 runtime smoke

### 9.4 macOS 启动验证

```bash
# 文件路径: /tmp/NoteMaster-BCR1-macOS-final/Build/Products/Debug/NoteMaster_Ver_1.app
# 命令/函数名: RuntimeSmokeScenario.startup-validation
# 功能说明: 运行最终二进制的启动期共享验证集合。
NOTE_MASTER_RUNTIME_SMOKE_TEST=startup-validation \
  /tmp/NoteMaster-BCR1-macOS-final/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1
```

最终结果：

- `FretboardValidation`：`automated=PASS fixtures=7`
- `StaffValidation`：`automated=PASS fixtures=57`
- `SettingsNavigationValidation`：`automated=PASS fixtures=24`
- `PianoValidation`：`automated=PASS fixtures=32`
- `PlaybackValidation`：`automated=PASS fixtures=6`
- `PlayCompositionValidation`：`automated=PASS fixtures=2`
- `ExerciseCompositionValidation`：`automated=PASS fixtures=39`
- BCR-1 root-tree、settings-state 与 piano-recognition-policy 夹具均为 `issues=0`

### 9.5 macOS BCR-1 runtime smoke

```bash
# 文件路径: /tmp/NoteMaster-BCR1-macOS-final/Build/Products/Debug/NoteMaster_Ver_1.app
# 命令/函数名: RuntimeSmokeScenario.bcr1-piano-answer
# 功能说明: 从 Settings action 切入 BCR-1，验证真实 controller、Bass sequence、主钢琴答题与 pitch-class 反馈链。
NOTE_MASTER_RUNTIME_SMOKE_TEST=bcr1-piano-answer \
  /tmp/NoteMaster-BCR1-macOS-final/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1
```

最终实际日志要点：

```bash
# 文件路径: macOS BCR-1 runtime smoke 最终日志
# 函数名: runBCR1PianoAnswerSmokeTest / QuarterNoteSequence answer flow
# 功能说明: E3 题目下 F3 判错且不推进；E4 与 E3 音级相同，按 pitchClass 判对并推进。
[QuarterNoteSequence][macOS] clef=Bass noteCount=7 includesAccidentals=false state=exerciseModeChanged
[macOS] [QuarterNoteSequence] policy=pitchClass step=1/7 expectedClass=E expectedNote=E3 written=E3 answeredClass=F answeredNote=F3 result=wrong nextIndex=0 remaining=7 state=inProgress answered=F3
[macOS] [QuarterNoteSequence] policy=pitchClass step=1/7 expectedClass=E expectedNote=E3 written=E3 answeredClass=E answeredNote=E4 result=correct nextIndex=1 remaining=6 state=inProgress answered=E4
[RuntimeSmoke][macOS] PASS scenario=bcr1_piano_answer finalMode=single pianoVisible=false
```

该结果实际证明：

- 生成序列使用 Bass Clef
- 错误音级不会推进题目
- 同音级不同八度会被判定为正确
- 正确后 session 从 index `0` 推进到 `1`
- smoke 完成后能正常切回 `single`

### 9.6 构建中的既有非阻断 warning

最终构建仍会输出工程原有的 Swift 并发隔离 warning，以及 `FretboardValidation.swift` 中既有的 `initialTrainer` 未修改 warning。本次未为记录工作扩大范围处理这些既有问题；它们没有阻断本次双平台构建和启动验证。

## 10. 明确未修改的边界

- 没有修改 quarter-note sequence 的音符候选池实现；Bass Clef 使用现有 bass 候选音域
- 没有修改 sequence 的 `noteCount` 与 `includesAccidentals` 用户配置语义
- 没有修改 SR-0、SR-1、SR-2 的既有模式合同
- 没有新增独立 BCR-1 scene renderer；它复用共享 Staff/Piano composition
- 没有在 Settings renderer 中添加按 BCR-1 判断的特殊布局分支
- 没有修改任何旧 Markdown 文件
- 没有修改任何计划文件
- 没有提交 Git commit
- 创建本记录时没有继续修改任何 Swift 源代码

## 11. 结论

本次不是复制一套 SR-1 分支，而是把原本固定 Treble、以 SR 命名的 piano reading family 泛化为可参数化 clef 的 piano sequence recognition contract。`SR-1` 与 `Bass Clef Recognition-1` 现在共用 `singleRowPitchClass(clef:)`，因此单行钢琴、row-only、pitch-class 判题和 Staff-to-Piano stacked 场景只维护一份；BCR-1 唯一传入的差异是 `.bass`。Settings、normalization、answer router、双平台 controller 与 validation 均已接通这一共享合同。

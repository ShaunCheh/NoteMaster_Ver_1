# 20260327_124719_phase3_trainer_display_state_and_exercise_mode

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_124719`
- 记录范围：统一序列真相源阶段 3，把训练模式提升为 shared settings state，并在控制面板中新增 `Exercise Mode`
- 本次目标：让 `Single / Sequence` 不再只是 controller 私有分支，而是进入 `SettingsPanelStateContext` 统一真相源，支持控制面板稳定显示、切换和回显
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 当前 sequence / single 的训练语义虽然已经存在于 `FretboardNaturalNoteTrainerState.mode`，但它还没有进入 settings shared state，所以控制面板没有一份稳定、可回显、可传递的训练模式真相源。
- 如果直接在 controller 里临时判断 `fretboardTrainerState.mode` 来决定按钮高亮，控制面板会继续依赖平台侧的临时解释，后续阶段 4/5 很难把“设置选择”“显示投影”“判题状态机”收敛到同一条 shared 数据流。
- 本阶段的根因修复重点因此是：先把 `Exercise Mode` 提升进 `SettingsPanelStateContext`，再让 settings action 直接读写这份 shared state；至于实际训练行为切换，按计划留到后续阶段统一接线。

## 修改 1：新增 `TrainerDisplayState`，为 settings 提供独立训练模式真相源

### 修改前

- 项目内没有独立的 `TrainerDisplayState` 文件。
- 训练模式没有 shared 控制面板状态承载位，`Single / Sequence` 也没有自己的共享配置结构。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/成员: N/A（修改前无此文件）
// 功能说明: 修改前没有独立的 shared trainer display state；
// Exercise Mode 还无法进入 settings 真相源。
// 修改前无此文件。
```

### 修改后

- 新增 `TrainerExerciseMode`
- 新增 `TrainerSequenceConfiguration(clef, noteCount, includesAccidentals)`
- 新增 `TrainerDisplayState(exerciseMode, sequenceConfiguration)`
- 先给 sequence 模式收一个最小共享配置默认值，为后续阶段继续暴露更多 settings 行做准备

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数/成员: TrainerExerciseMode, TrainerSequenceConfiguration.init(...),
// TrainerDisplayState.init(...), TrainerDisplayState.setExerciseMode(_:)
// 功能说明: 新增 shared trainer display state，把 Exercise Mode 和 sequence 基础配置
// 从 controller 私有判断提升为可放入 settings 上下文的统一状态。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
}

struct TrainerSequenceConfiguration: Equatable, Sendable {
    var clef: StaffClef
    var noteCount: Int
    var includesAccidentals: Bool

    static let `default` = TrainerSequenceConfiguration(
        clef: .treble,
        noteCount: 7,
        includesAccidentals: false
    )

    init(
        clef: StaffClef = .treble,
        noteCount: Int = 7,
        includesAccidentals: Bool = false
    ) {
        precondition(
            noteCount > 0,
            "Trainer sequence note count must be greater than zero."
        )
        self.clef = clef
        self.noteCount = noteCount
        self.includesAccidentals = includesAccidentals
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration

    static let `default` = TrainerDisplayState()

    init(
        exerciseMode: TrainerExerciseMode = .single,
        sequenceConfiguration: TrainerSequenceConfiguration = .default
    ) {
        self.exerciseMode = exerciseMode
        self.sequenceConfiguration = sequenceConfiguration
    }

    mutating func setExerciseMode(_ mode: TrainerExerciseMode) {
        exerciseMode = mode
    }
}
```

## 修改 2：`SettingsPanelStateContext` 纳入 `trainerDisplayState`

### 修改前

- `SettingsPanelStateContext` 只有：
  - `fretboardDisplayState`
  - `staffDisplayState`
  - `pageDisplayState`
- 所以 settings action 根本没有地方读取或写回训练模式。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数/成员: SettingsPanelStateContext.default
// 功能说明: 修改前 settings 上下文只包含 fretboard / staff / page，
// 训练模式没有进入统一 settings 真相源。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState

    static let `default` = SettingsPanelStateContext(
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pageDisplayState: .default
    )
}
```

### 修改后

- `SettingsPanelStateContext` 新增 `trainerDisplayState`
- 默认值初始化也统一切到可扩展的自定义 `init(...)`
- 这样后续任何 settings action / snapshot builder / controller 都能通过同一个 stateContext 读写训练模式

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数/成员: SettingsPanelStateContext.init(...), SettingsPanelStateContext.default
// 功能说明: 修改后 trainerDisplayState 被纳入 settings shared context；
// Exercise Mode 已经成为控制面板可消费、可迁移的统一状态字段。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var trainerDisplayState: TrainerDisplayState

    static let `default` = SettingsPanelStateContext()

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState = .default,
        trainerDisplayState: TrainerDisplayState = .default
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.pageDisplayState = pageDisplayState
        self.trainerDisplayState = trainerDisplayState
    }
}
```

## 修改 3：`SettingsPanelModel` 新增 `Trainer` section 和 `Exercise Mode` row

### 修改前

- `SettingsSectionID` 只有 `page / fretboard / staff / layout / debug`
- `SettingsChoiceRowID` 没有 `exerciseMode`
- `SettingsActionID` 也没有 `Single / Sequence`
- 所以 snapshot builder 即便重建模型，也不可能产出训练模式那一行

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSectionID, SettingsChoiceRowID, SettingsActionID
// 功能说明: 修改前 settings 域没有 trainer section，也没有 Exercise Mode row，
// 控制面板只能表达页面布局、指板显示、五线谱配置等状态。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case fretboard
    case staff
    case layout
    case debug
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
    case setClefTreble
    case setClefBass
}
```

### 修改后

- 新增 `SettingsSectionID.trainer`
- 新增 `SettingsChoiceRowID.exerciseMode`
- 新增 `SettingsActionID.setExerciseModeSingle / setExerciseModeSequence`
- `Exercise Mode` 使用 segmented 风格，和 `Top Content / Main Content / Clef` 保持一致

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSectionID.rowIDs, SettingsChoiceRowID.actionIDs,
// SettingsActionID.rowID, title, accessibilityLabel
// 功能说明: 修改后 settings 模型能直接生成 Trainer section 和 Exercise Mode row，
// 并为 Single / Sequence 两个选项提供共享 action 定义。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
        case .page:
            return [
                .choice(.topContent),
                .choice(.mainContent)
            ]
        case .trainer:
            return [
                .choice(.exerciseMode)
            ]
        case .fretboard:
            return [
                .choice(.instrument),
                .choice(.displayMode),
                .choice(.labels),
                .choice(.spelling),
                .choice(.octave)
            ]
        case .staff:
            return [
                .choice(.clef),
                .slider(.clefScale),
                .slider(.clefVerticalTrim),
                .slider(.clefAnchorYOffset)
            ]
        case .layout:
            return [
                .slider(.verticalHostHeightRatio)
            ]
        case .debug:
            return [
                .toggle(.showsComponentBounds)
            ]
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case exerciseMode
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef

    var actionIDs: [SettingsActionID] {
        switch self {
        case .exerciseMode:
            return [
                .setExerciseModeSingle,
                .setExerciseModeSequence
            ]
        // ... 其余 row 维持原有定义
        default:
            return []
        }
    }
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setExerciseModeSingle
    case setExerciseModeSequence
    // ... 其余 action 维持原有定义
}
```

## 修改 4：`SettingsPanelModel` 让 `Exercise Mode` 真正读写 `trainerDisplayState`

### 修改前

- `isSelected(in:)` 只会查询 page / fretboard / staff 状态
- `apply(to stateContext:)` 也只会把 action 落到：
  - `fretboardDisplayState`
  - `staffDisplayState`
  - `pageDisplayState`
- 即使未来控制面板上有 `Exercise Mode` 按钮，也没有状态迁移入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsActionID.isSelected(in:), SettingsActionID.apply(to:stateContext:)
// 功能说明: 修改前 settings action 既不会读取 trainer state，也不会把 action 写回 trainer state。
func isSelected(
    in stateContext: SettingsPanelStateContext
) -> Bool {
    switch self {
    case .setTopContentStaff:
        return stateContext.pageDisplayState.topContentMode == .staff
    case .setTopContentTargetPrompt:
        return stateContext.pageDisplayState.topContentMode == .targetPrompt
    case .setMainContentFretboard:
        return stateContext.pageDisplayState.mainContentMode == .fretboard
    case .setMainContentNaturalNotes:
        return stateContext.pageDisplayState.mainContentMode == .naturalNoteStrip
    // ... 其余分支只读取 fretboard / staff
    default:
        return false
    }
}

func apply(to stateContext: inout SettingsPanelStateContext) {
    apply(to: &stateContext.fretboardDisplayState)
    apply(to: &stateContext.staffDisplayState)
    apply(to: &stateContext.pageDisplayState)
}
```

### 修改后

- `isSelected(in:)` 新增对 `trainerDisplayState.exerciseMode` 的查询
- 新增 `apply(to displayState: inout TrainerDisplayState)`
- `apply(to stateContext:)` 把 trainer state 纳入统一动作迁移

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsActionID.isSelected(in:),
// SettingsActionID.apply(to: TrainerDisplayState),
// SettingsActionID.apply(to: SettingsPanelStateContext)
// 功能说明: 修改后 Exercise Mode 的选中态和状态迁移都走 trainerDisplayState，
// 控制面板不再需要从 controller 私有逻辑反推当前训练模式。
func isSelected(
    in stateContext: SettingsPanelStateContext
) -> Bool {
    switch self {
    case .setExerciseModeSingle:
        return stateContext.trainerDisplayState.exerciseMode == .single
    case .setExerciseModeSequence:
        return stateContext.trainerDisplayState.exerciseMode == .sequence
    case .setTopContentStaff:
        return stateContext.pageDisplayState.topContentMode == .staff
    case .setTopContentTargetPrompt:
        return stateContext.pageDisplayState.topContentMode == .targetPrompt
    case .setMainContentFretboard:
        return stateContext.pageDisplayState.mainContentMode == .fretboard
    case .setMainContentNaturalNotes:
        return stateContext.pageDisplayState.mainContentMode == .naturalNoteStrip
    // ... 其余分支维持原有读取逻辑
    default:
        return false
    }
}

func apply(to displayState: inout TrainerDisplayState) {
    switch self {
    case .setExerciseModeSingle:
        displayState.setExerciseMode(.single)
    case .setExerciseModeSequence:
        displayState.setExerciseMode(.sequence)
    default:
        return
    }
}

func apply(to stateContext: inout SettingsPanelStateContext) {
    apply(to: &stateContext.fretboardDisplayState)
    apply(to: &stateContext.staffDisplayState)
    apply(to: &stateContext.pageDisplayState)
    apply(to: &stateContext.trainerDisplayState)
}
```

## 修改 5：双平台 controller 持久化 `trainerDisplayState`，让控制面板选择能稳定回显

### 修改前

- iOS / macOS controller 都没有 `trainerDisplayState`
- `settingsPanelStateContext` 不会把训练模式带进 settings
- `handleSettingsPanelEvent(_:)` 也只会比较并落地 fretboard / staff / page 三类状态变化

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: settingsPanelStateContext, handleSettingsPanelEvent(_:)
// 功能说明: 修改前 iOS controller 不持有 trainer display state，
// 所以 settings panel 的选择无法在 controller 内稳定保存和回显。
private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextPageDisplayState = nextStateContext.pageDisplayState

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState

    guard didChangeFretboard || didChangeStaff || didChangePage else {
        return
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: settingsPanelStateContext, handleSettingsPanelEvent(_:)
// 功能说明: 修改前 macOS controller 与 iOS 同构，也没有 trainer display state 的持久化入口。
private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextPageDisplayState = nextStateContext.pageDisplayState

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState

    guard didChangeFretboard || didChangeStaff || didChangePage else {
        return
    }
}
```

### 修改后

- iOS / macOS controller 都新增 `trainerDisplayState`
- `settingsPanelStateContext` 开始把它带入统一 snapshot
- `handleSettingsPanelEvent(_:)` 开始计算 `didChangeTrainer`
- 当只切 `Exercise Mode` 时，controller 也会真正持久化这次状态变化

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: trainerDisplayState, settingsPanelStateContext, handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS controller 会持有并持久化 trainerDisplayState，
// 使 Exercise Mode 在 settings panel 中具备稳定选择态和回显能力。
private var trainerDisplayState = TrainerDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}

private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState,
        trainerDisplayState: trainerDisplayState
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextPageDisplayState = nextStateContext.pageDisplayState
    let nextTrainerDisplayState = nextStateContext.trainerDisplayState

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState
    let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState

    guard didChangeFretboard || didChangeStaff || didChangePage || didChangeTrainer else {
        return
    }

    if didChangeTrainer {
        trainerDisplayState = nextTrainerDisplayState
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: trainerDisplayState, settingsPanelStateContext, handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS controller 同步持有 trainerDisplayState，
// 让双平台控制面板对 Exercise Mode 的选中态保持一致的 shared 持久化行为。
private var trainerDisplayState = TrainerDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applySettingsPanelState()
    }
}

private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState,
        trainerDisplayState: trainerDisplayState
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)
    normalizeSettingsPanelStateContextForTrainerMode(&nextStateContext)

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextPageDisplayState = nextStateContext.pageDisplayState
    let nextTrainerDisplayState = nextStateContext.trainerDisplayState

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState
    let didChangeTrainer = nextTrainerDisplayState != trainerDisplayState

    guard didChangeFretboard || didChangeStaff || didChangePage || didChangeTrainer else {
        return
    }

    if didChangeTrainer {
        trainerDisplayState = nextTrainerDisplayState
    }
}
```

## 为什么 `SettingsPanelSnapshotBuilder.swift` 没改

- 本阶段没有修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- 原因不是遗漏，而是它本来就通过：
  - `SettingsSectionID.allCases`
  - `SettingsSectionID.rowIDs`
  - `SettingsChoiceRowID.actionIDs`
  自动生成 snapshot
- 所以在 `SettingsPanelModel.swift` 中新增 `trainer / exerciseMode / Single / Sequence` 后，snapshot builder 会自动收编新 section 和新 row，不需要额外写一次平台无关的分支代码

## 阶段 3 完成后的状态

1. `Exercise Mode` 已经进入 shared settings state
2. 控制面板已经能显示 `Trainer` section 和 `Single / Sequence` 选择项
3. 双平台 controller 已经会持久化这个选择，因此面板高亮和回显是稳定的
4. 本阶段仍然没有把这个选择直接驱动到训练行为切换，这是刻意保留给阶段 4 的边界

## 验证情况

- 已对以下文件执行诊断检查，结果为 `No linter errors found`
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 已额外核对：
  - `trainerDisplayState` 已进入 `SettingsPanelStateContext`
  - `SettingsActionID.apply(to: stateContext)` 已纳入 trainer 分支
  - 双平台 controller 都会持久化 `didChangeTrainer`
- 未执行 `xcodebuild`：当前环境仍受 Xcode command line tools 配置限制，和前几轮一致。

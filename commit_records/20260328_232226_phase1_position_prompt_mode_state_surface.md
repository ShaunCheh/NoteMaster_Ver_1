# 20260328_232226_phase1_position_prompt_mode_state_surface

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_232226`
- 记录范围：实施“位置音名模式”计划的阶段 1，只补状态面、页面组合表达与 settings 映射，不接入共享判题、布局切换和按钮答题
- 本次目标：先让“第三训练模式 + 上指板下按钮”在 shared state 与 settings 层有合法承载，避免后续阶段一边做 trainer 一边补状态真相
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 根因结论

- 修改前，训练模式真相 `TrainerExerciseMode` 只有 `single` 和 `sequence` 两项，shared state 无法承载新的“位置音名”模式
- 修改前，页面编排真相 `PageDisplayState` 只能表达“上方 staff/target、下方 fretboard/natural notes”这两组二选一，不存在 `top=fretboard` 的合法状态
- 修改前，settings 面板虽然已有 `exerciseMode`、`topContent`、`mainContent` 三类入口，但都缺少新模式对应的 action 和映射，后续阶段无法走统一 settings 管线
- 因此阶段 1 的根因级修复，不是直接做交互，而是先补齐 trainer/page/settings 的状态面，并让控制器在新枚举 case 出现后仍保持稳定编译与占位行为

## 修改 1：`TrainerDisplayState` 新增第三训练模式

### 修改前

- `TrainerExerciseMode` 只有 `single` 与 `sequence`
- `TrainerDisplayState` 只有 `isSequenceMode`，没有新模式的便捷判断

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode, TrainerDisplayState.isSequenceMode
// 功能说明: 修改前 trainer 状态层只能表达 single / sequence 两种练习模式。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration

    var isSequenceMode: Bool {
        exerciseMode == .sequence
    }

    mutating func setExerciseMode(_ mode: TrainerExerciseMode) {
        exerciseMode = mode
    }
}
```

### 修改后

- `TrainerExerciseMode` 增加 `positionPrompt`
- `TrainerDisplayState` 增加 `isPositionPromptMode`，为后续阶段的 normalize 与控制器投影提供显式入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode, TrainerDisplayState.isSequenceMode, TrainerDisplayState.isPositionPromptMode
// 功能说明: 修改后 trainer 状态层已经可以表达第三种“位置音名”练习模式，
// 为后续 shared trainer、settings 和控制器投影提供统一状态真相。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration

    var isSequenceMode: Bool {
        exerciseMode == .sequence
    }

    var isPositionPromptMode: Bool {
        exerciseMode == .positionPrompt
    }

    mutating func setExerciseMode(_ mode: TrainerExerciseMode) {
        exerciseMode = mode
    }
}
```

## 修改 2：`PageDisplayState` 补齐“上指板、下按钮”的页面状态表达

### 修改前

- `PageTopContentMode` 只有 `.staff` 和 `.targetPrompt`
- `PageMainContentMode` 只有 `.fretboard` 和 `.naturalNoteStrip`
- 页面状态只负责简单赋值，没有“同一时刻 fretboard 只能占一个槽位”的集中式收敛

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数名/符号: PageTopContentMode, PageMainContentMode, PageDisplayState.setTopContentMode, PageDisplayState.setMainContentMode
// 功能说明: 修改前页面编排只能表达“顶部显示谱/target、主区显示指板/音名条”的旧组合，
// 不能承载 top=fretboard, main=naturalNoteStrip 的新布局。
enum PageTopContentMode: Equatable, Hashable, Sendable {
    case staff
    case targetPrompt
}

enum PageMainContentMode: Equatable, Hashable, Sendable {
    case fretboard
    case naturalNoteStrip
}

struct PageDisplayState: Equatable, Sendable {
    var topContentMode: PageTopContentMode
    var mainContentMode: PageMainContentMode

    mutating func setTopContentMode(_ mode: PageTopContentMode) {
        topContentMode = mode
    }

    mutating func setMainContentMode(_ mode: PageMainContentMode) {
        mainContentMode = mode
    }
}
```

### 修改后

- `PageTopContentMode` 新增 `.fretboard`
- 新增 `PageDisplayState.positionPrompt` 作为后续阶段可直接复用的标准组合
- 新增 `showsFretboardInTopContent` / `showsFretboardInMainContent` / `showsFretboard`
- 新增 `normalizeFretboardPlacement(...)`，避免出现 `top=fretboard` 与 `main=fretboard` 同时成立的冲突状态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数名/符号: PageTopContentMode, PageDisplayState.positionPrompt,
// PageDisplayState.setTopContentMode, PageDisplayState.setMainContentMode,
// PageDisplayState.normalizeFretboardPlacement
// 功能说明: 修改后页面状态已经能表达“上指板、下自然音按钮”，
// 并通过集中式收敛保证 fretboard 不会同时占据 top/main 两个槽位。
enum PageTopContentMode: Equatable, Hashable, Sendable {
    case staff
    case targetPrompt
    case fretboard
}

enum PageMainContentMode: Equatable, Hashable, Sendable {
    case fretboard
    case naturalNoteStrip
}

struct PageDisplayState: Equatable, Sendable {
    var topContentMode: PageTopContentMode
    var mainContentMode: PageMainContentMode

    static let positionPrompt = PageDisplayState(
        topContentMode: .fretboard,
        mainContentMode: .naturalNoteStrip
    )

    var showsFretboardInTopContent: Bool {
        topContentMode == .fretboard
    }

    var showsFretboardInMainContent: Bool {
        mainContentMode == .fretboard
    }

    var showsFretboard: Bool {
        showsFretboardInTopContent || showsFretboardInMainContent
    }

    mutating func setTopContentMode(_ mode: PageTopContentMode) {
        topContentMode = mode
        normalizeFretboardPlacement(prioritizingTopContent: true)
    }

    mutating func setMainContentMode(_ mode: PageMainContentMode) {
        mainContentMode = mode
        normalizeFretboardPlacement(prioritizingTopContent: false)
    }

    private mutating func normalizeFretboardPlacement(
        prioritizingTopContent: Bool
    ) {
        guard !(topContentMode == .fretboard && mainContentMode == .fretboard) else {
            return
        }

        if prioritizingTopContent {
            mainContentMode = .naturalNoteStrip
        } else {
            topContentMode = .staff
        }
    }
}
```

## 修改 3：`SettingsPanelModel` 新增第三训练模式，并补齐 topContent 的 fretboard 状态面

### 修改前

- `exerciseMode` 只有 `Single` / `Sequence`
- `topContent` 只有 `Staff` / `Target`
- `SettingsActionID` 也没有对应的 `Position` 或 `TopContentFretboard` action

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs, SettingsActionID
// 功能说明: 修改前 settings 无法从 UI 状态层选择第三训练模式，
// 也无法表达 topContent=fretboard 的页面编排。
case .topContent:
    return [
        .setTopContentStaff,
        .setTopContentTargetPrompt
    ]

case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setExerciseModeSingle
    case setExerciseModeSequence
    // ... 省略其他 action ...
}
```

### 修改后

- `exerciseMode` 新增 `Position`
- `topContent` 新增 `Fretboard`
- `SettingsActionID`、`title`、`accessibilityLabel`、`isSelected`、`apply(to:)` 全链路同步补齐

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsChoiceRowID.actionIDs, SettingsActionID.rowID,
// SettingsActionID.title, SettingsActionID.accessibilityLabel
// 功能说明: 修改后 settings 已经具备第三训练模式与 top=fretboard 的状态承载能力，
// 后续阶段可以直接复用这些 action 做 normalize 和控制器投影。
case .topContent:
    return [
        .setTopContentStaff,
        .setTopContentTargetPrompt,
        .setTopContentFretboard
    ]

case .exerciseMode:
    return [
        .setExerciseModeSingle,
        .setExerciseModeSequence,
        .setExerciseModePositionPrompt
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setTopContentFretboard
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModePositionPrompt
    // ... 省略其他 action ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsActionID.isSelected,
// SettingsActionID.apply(to: inout PageDisplayState),
// SettingsActionID.apply(to: inout TrainerDisplayState)
// 功能说明: 修改后 settings action 不只是有文案，
// 还具备了与 PageDisplayState / TrainerDisplayState 对应的状态映射能力。
case .setTopContentFretboard:
    return stateContext.pageDisplayState.topContentMode == .fretboard
case .setExerciseModePositionPrompt:
    return stateContext.trainerDisplayState.exerciseMode == .positionPrompt

case .setTopContentFretboard:
    displayState.setTopContentMode(.fretboard)

case .setExerciseModePositionPrompt:
    displayState.setExerciseMode(.positionPrompt)
```

### 阶段 1 的额外约束

- 这次虽然把 `setTopContentFretboard` 状态面补出来了，但出于阶段边界控制，当前先不允许用户直接从 settings 点击启用
- 这样做是为了让状态层完整，但避免在布局与投影还没接完前，把半成品入口暴露到 UI

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsActionID.isEnabled
// 功能说明: 阶段 1 先把 top=fretboard 作为状态面补齐，
// 但暂时禁用 settings 入口，防止用户提前切到尚未接入布局的页面组合。
func isEnabled(
    in _: SettingsPanelStateContext
) -> Bool {
    switch self {
    case .setTopContentStaff,
         .setTopContentTargetPrompt,
         .setMainContentFretboard,
         .setMainContentNaturalNotes,
         .setExerciseModeSingle,
         .setExerciseModeSequence,
         .setExerciseModePositionPrompt:
        return true
    case .setTopContentFretboard:
        return false
    // ... 省略其他 case ...
    }
}
```

## 修改 4：iOS / macOS 控制器补齐 `positionPrompt` 的占位分支

### 修改前

- `synchronizeTrainerPresentationState(reason:)` 只处理 `.single` 与 `.sequence`
- 一旦 shared 状态层先新增第三 case，控制器的 switch 就会失配

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改前 iOS 控制器只认识 single / sequence 两种 trainer mode。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改前 macOS 控制器与 iOS 同构，
// 也还没有第三模式的占位投影分支。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    }
}
```

### 修改后

- iOS/macOS 都补了 `.positionPrompt`
- 阶段 1 先临时复用 `single` 的旧投影，保证新枚举落地后工程仍可稳定编译和运行
- 这不是最终功能行为，只是阶段 1 的占位策略

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改后 iOS 控制器已经能接住第三训练模式；
// 但在后续布局与按钮判题接入前，先临时沿用 single 投影避免进入未定义 UI。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizeSingleTrainerPresentation(reason: reason)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.synchronizeTrainerPresentationState(reason:)
// 功能说明: 修改后 macOS 控制器与 iOS 保持同构；
// 先只打通状态面，不在阶段 1 提前接入未完成的新布局。
private func synchronizeTrainerPresentationState(reason: String) {
    switch trainerDisplayState.exerciseMode {
    case .single:
        synchronizeSingleTrainerPresentation(reason: reason)
    case .sequence:
        synchronizeQuarterNoteSequencePresentation(reason: reason)
    case .positionPrompt:
        synchronizeSingleTrainerPresentation(reason: reason)
    }
}
```

## 当前阶段边界

- 已完成：第三训练模式的状态承载、页面组合表达、settings 映射、控制器 switch 占位
- 未完成：shared trainer 的 `session / evaluation / 按钮判题`、指板白圈/红闪/绿停留、实际“上指板下按钮”布局切换、按钮点击接线
- 当前如果在 settings 里选中 `Position`，控制器仍会临时沿用 single 的旧投影，这是本阶段刻意保留的占位行为，不代表最终交付效果


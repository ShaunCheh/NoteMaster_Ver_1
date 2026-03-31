# 20260331_121408_phase8_position_filter_startup_defaults_guard

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_121408`
- 记录范围：实施“Position 过滤模式重构”计划的阶段 8，只完成默认值与启动行为的回归护栏收口；没有新增运行时生产代码改动
- 本次目标：确认并锁定以下启动默认行为
- `TrainerDisplayState.default` 仍默认进入 `.positionPrompt`
- `positionPromptConfiguration.default` 默认走 `noteName`
- 默认多选项回显 `C/E/F/B`
- 设置面板首次打开时，`Trainer` 区第一眼看到 `Filter = Note Names`
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 本次结论

- 经过阶段 8 收口检查，运行时默认值链路本身已经满足目标，没有再额外修改生产代码
- 本阶段真正新增的是“启动默认值 + startup settings projection”的自动 validation 护栏
- validation 现在不仅校验默认 `noteName` / `C/E/F/B`，还会直接构造 startup 的 `SettingsPanelStateContext`，断言首屏 Trainer 区确实回显：
- `Exercise Mode = Position Prompt`
- `Filter = Note Names`
- `Note Names` 按钮顺序 `C/D/E/F/G/A/B`
- 默认选中集合 `C/E/F/B`
- 手工 checklist 也补上了“应用启动后直接打开设置面板”的首屏回归项

## 修改 1：把“默认配置检查”升级为“默认配置 + startup settings projection 检查”

### 修改前

- `validatePositionPromptTrainer(...)` 虽然已经会检查默认 `filterMode` 与默认 `selectedPitchClasses`
- 但它还不会验证“应用启动后 settings 面板第一眼看到什么”
- 换句话说，默认 domain state 虽然对了，但还没有自动验证 startup snapshot 是否真的投影成 `Filter = Note Names` 和 `C/E/F/B`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...)
// 功能说明: 修改前 validation 只检查默认 position prompt configuration；
// 还没有把 startup settings model 的首屏投影纳入自动回归护栏。
logStage("defaultConfiguration")
let defaultPositionPromptConfiguration =
    TrainerPositionPromptConfiguration.default
if defaultPositionPromptConfiguration.filterMode != .noteName {
    record("position prompt 默认 filterMode 应为 .noteName。")
}
if defaultPositionPromptConfiguration.selectedPitchClasses
    != TrainerPositionPromptConfiguration.defaultSelectedPitchClasses {
    record("position prompt 默认 selectedPitchClasses 未对齐 C/E/F/B。")
}
if defaultPositionPromptConfiguration.selectedFrets
    != TrainerPositionPromptConfiguration.defaultSelectedFrets {
    record("position prompt 默认 selectedFrets 未保留既有品位集合。")
}
switch defaultPositionPromptConfiguration.activeFilter {
case let .noteNames(selectedPitchClasses):
    if selectedPitchClasses
        != TrainerPositionPromptConfiguration.defaultSelectedPitchClasses {
        record("position prompt 默认 activeFilter 未对齐默认音名集合。")
    }
case .frets:
    record("position prompt 默认 activeFilter 不应落在 fret 模式。")
}
```

### 修改后

- 保留原有默认 configuration 检查
- 继续新增 `startupSettingsProjection` 这一段
- 直接构造 startup 的 `SettingsPanelStateContext(pageDisplayState: .positionPrompt, trainerDisplayState: .default)`
- 然后用 `SettingsPanelSnapshotBuilder.makeModel(...)` 断言首屏 Trainer 区 row 顺序、Filter row 选中态、以及音名按钮回显都正确

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...)
// 功能说明: 修改后 validation 不只检查默认 domain 配置，
// 还会直接检查 startup 时 SettingsPanelSnapshotBuilder 的首屏投影是否回显为 Position Prompt + Note Names + C/E/F/B。
logStage("defaultConfiguration")
let defaultPositionPromptConfiguration =
    TrainerPositionPromptConfiguration.default
if TrainerDisplayState.default.exerciseMode != .positionPrompt {
    record("TrainerDisplayState.default 应继续默认进入 .positionPrompt。")
}
if defaultPositionPromptConfiguration.filterMode != .noteName {
    record("position prompt 默认 filterMode 应为 .noteName。")
}
if defaultPositionPromptConfiguration.selectedPitchClasses
    != TrainerPositionPromptConfiguration.defaultSelectedPitchClasses {
    record("position prompt 默认 selectedPitchClasses 未对齐 C/E/F/B。")
}

logStage("startupSettingsProjection")
let startupSettingsModel = SettingsPanelSnapshotBuilder.makeModel(
    from: SettingsPanelStateContext(
        pageDisplayState: .positionPrompt,
        trainerDisplayState: .default
    )
)
if let startupTrainerSection = startupSettingsModel.sections.first(where: {
    $0.id == .trainer
}) {
    let expectedStartupTrainerRowIDs: [SettingsRowID] = [
        .choice(.exerciseMode),
        .choice(.positionPromptFilterMode),
        .positionFilter(.positionPromptFilterOptions)
    ]
    if startupTrainerSection.rows.map(\.id) != expectedStartupTrainerRowIDs {
        record("startup settings model 的 Trainer row 顺序未对齐 Exercise Mode / Filter / Position Filter。")
    }
    // ... 继续校验 Filter row 选中态与 Note Names option row 的默认回显 ...
}
```

## 修改 2：新增 startup Trainer 区首屏回显的结构化断言

### 修改前

- 自动 validation 不知道 `Trainer` section 里应出现哪些 row
- 也不知道 `Filter` row 应该默认选中 `Note Names`
- 更不知道 `positionPromptFilterOptions` row 应该渲染 `Note Names` 标题和默认选中 `C/E/F/B`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...)
// 功能说明: 修改前没有对 startup settings snapshot 的 Trainer 区结构做任何自动断言。
// 也就是说，首屏回显如果被后续改坏，只靠已有 validation 不一定能发现。
// （此处在修改前没有对应代码块）
```

### 修改后

- 新增 `resolveChoiceRow(...)` / `resolvePositionFilterRow(...)`
- 自动断言 Trainer 区 row 顺序必须是：
- `Exercise Mode`
- `Filter`
- `Position Filter Options`
- 自动断言：
- `Exercise Mode` 默认选中 `Position Prompt`
- `Filter` 默认选中 `Note Names`
- `Position Filter row.title == "Note Names"`
- 选项顺序是 `C/D/E/F/G/A/B`
- 默认选中集合是 `C/E/F/B`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: resolveChoiceRow(_:in:), resolvePositionFilterRow(_:in:),
// validatePositionPromptTrainer(...)
// 功能说明: 修改后 validation 会直接拆解 startup Trainer section，
// 对 row 顺序、默认 mode、默认 Filter、以及音名按钮的顺序/选中态做结构化断言。
func resolveChoiceRow(
    _ rowID: SettingsChoiceRowID,
    in section: SettingsSection
) -> SettingsChoiceRow? {
    for row in section.rows {
        guard case let .choice(choiceRow) = row,
              choiceRow.id == rowID else {
            continue
        }
        return choiceRow
    }
    return nil
}

func resolvePositionFilterRow(
    _ rowID: SettingsPositionFilterRowID,
    in section: SettingsSection
) -> SettingsPositionFilterRow? {
    for row in section.rows {
        guard case let .positionFilter(positionFilterRow) = row,
              positionFilterRow.id == rowID else {
            continue
        }
        return positionFilterRow
    }
    return nil
}

if let filterModeRow = resolveChoiceRow(
    .positionPromptFilterMode,
    in: startupTrainerSection
) {
    let expectedFilterModeChoiceIDs: [SettingsActionID] = [
        .setPositionPromptFilterModeNoteName,
        .setPositionPromptFilterModeFret
    ]
    if filterModeRow.choices.map(\.id) != expectedFilterModeChoiceIDs {
        record("startup settings model 的 Filter row 选项顺序未对齐 Note Names / Frets。")
    }
}

if let startupPositionFilterRow = resolvePositionFilterRow(
    .positionPromptFilterOptions,
    in: startupTrainerSection
) {
    let expectedOptionIDs = TrainerPositionPromptConfiguration.supportedPitchClasses.map {
        SettingsPositionFilterOptionID.pitchClass($0)
    }
    let expectedSelectedOptionIDs = Set(
        TrainerPositionPromptConfiguration.defaultSelectedPitchClasses.map {
            SettingsPositionFilterOptionID.pitchClass($0)
        }
    )
    let actualSelectedOptionIDs = Set(
        startupPositionFilterRow.options
            .filter(\.isSelected)
            .map(\.id)
    )
    if actualSelectedOptionIDs != expectedSelectedOptionIDs {
        record("startup settings model 的音名过滤按钮默认选中集合未对齐 C/E/F/B。")
    }
}
```

## 修改 3：手工 checklist 补上“应用启动后直接打开设置面板”的首屏回归

### 修改前

- 手工 checklist 已经覆盖了 `Filter = Note Names` / `Frets` 的切换
- 但没有单独要求“应用刚启动后，不做任何切换，直接打开 settings panel”
- 这会让“首屏默认回显”仍然缺少显式回归步骤

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: manualChecklist(for:)
// 功能说明: 修改前 checklist 虽然覆盖了 positionPrompt 下的 Filter 行，
// 但还没有独立的“应用启动后第一眼”回归项。
var checklist = [
    "在 `single` 与 `sequence` 模式下打开设置面板，确认 `Trainer` 分区不显示 `Filter` 与位置题多选过滤行；切到 `positionPrompt` 后确认出现 `Filter = Note Names`，且默认选中 `C / E / F / B`。",
    "在 `positionPrompt` 默认 `Filter = Note Names`、默认 `C / E / F / B` 状态下连续答对多次，确认当前题与下一题都只落在这些音名，且会从当前指板全部合法位置出题（包含命中这些音名的空弦）。",
    "把 `positionPrompt` 的 `Filter` 切到 `Frets`，确认会回显当前品位集合；连续答对多次，确认当前题与下一题都只落在当前已选品位。"
]
```

### 修改后

- checklist 最前面新增了一条 startup 回归项
- 要求直接验证：
- `Exercise Mode = Position Prompt`
- `Filter = Note Names`
- 默认多选回显 `C/E/F/B`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: manualChecklist(for:)
// 功能说明: 修改后 checklist 把“应用启动后第一眼”的 startup 回显也纳入了手工回归基线。
var checklist = [
    "应用启动后不做额外切换，直接打开设置面板；确认 `Trainer` 分区第一眼看到 `Exercise Mode = Position Prompt`、`Filter = Note Names`，并且多选按钮默认回显 `C / E / F / B`。",
    "在 `single` 与 `sequence` 模式下打开设置面板，确认 `Trainer` 分区不显示 `Filter` 与位置题多选过滤行；切到 `positionPrompt` 后确认出现 `Filter = Note Names`，且默认选中 `C / E / F / B`。",
    "在 `positionPrompt` 默认 `Filter = Note Names`、默认 `C / E / F / B` 状态下连续答对多次，确认当前题与下一题都只落在这些音名，且会从当前指板全部合法位置出题（包含命中这些音名的空弦）。",
    "把 `positionPrompt` 的 `Filter` 切到 `Frets`，确认会回显当前品位集合；连续答对多次，确认当前题与下一题都只落在当前已选品位。"
]
```

## 验证情况

- 已对 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift` 运行 `ReadLints`
- 结果：无 linter 报错
- 本次没有新增运行时生产代码改动，所以也没有额外的 controller / trainer 代码 lint 变更
- 本次未运行 `xcodebuild` / 应用启动验证；这份记录确认的是阶段 8 新增的 startup 回归护栏

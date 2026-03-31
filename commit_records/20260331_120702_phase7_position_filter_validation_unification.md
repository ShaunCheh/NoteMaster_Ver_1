# 20260331_120702_phase7_position_filter_validation_unification

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_120702`
- 记录范围：实施“Position 过滤模式重构”计划的阶段 7，只完成 shared validation 的统一 filter 扩展；不包含启动默认值收口
- 本次目标：把 `FretboardValidation.validatePositionPromptTrainer(...)` 从“只覆盖品位过滤场景”扩成“统一 activeFilter 场景”，补齐默认音名模式、音名子集、品位模式与最后一个选项保护
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 本次结论

- `validatePositionPromptTrainer(...)` 已经从旧的 `allowedFrets` 场景验证器升级为统一 `PositionPromptCandidateFilter` 验证器
- 自动验证现在同时覆盖：
- 默认 `noteName` 模式 `C/E/F/B`
- 音名子集场景 `C/E`
- 默认 `fret` 场景
- 品位子集场景 `1/3/5/7`
- “最后一个音名不可取消”与“最后一个品位不可取消”
- validation 内部辅助 `positionPromptCandidateCells(...)` 也同步升级为统一 filter 版本
- 手工回归 checklist 已改成新的 `Note Names | Frets` 语义，不再停留在旧的 `Frets` 专用口径

## 修改 1：主验证器从 `allowedFrets` 场景改成统一 `filter` 场景

### 修改前

- `validatePositionPromptTrainer(...)` 内部只有 `validateAllowedFretsScenario(...)`
- 这个验证器只能枚举“允许品位集合”，自动验证无法覆盖默认 `noteName` 模式和音名子集模式

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...), validateAllowedFretsScenario(...)
// 功能说明: 修改前 position prompt validation 只支持按品位验证；
// 自动验证入口只能构造 allowedFrets 场景，无法直接覆盖 noteName 模式。
func validateAllowedFretsScenario(
    name: String,
    allowedFrets: Set<Int>,
    requiresNoOpenStrings: Bool
) {
    let normalizedAllowedFrets = TrainerPositionPromptConfiguration(
        selectedFrets: allowedFrets
    ).selectedFrets

    let candidateCells = positionPromptCandidateCells(
        configuration: configuration,
        allowedFrets: normalizedAllowedFrets
    )

    if !candidateCells.allSatisfy({ normalizedAllowedFrets.contains($0.fret) }) {
        record("position prompt trainer \(name) 的候选池包含了未允许的品位。")
    }

    let initialSession = initialTrainer.makePositionPromptSession(
        configuration: configuration,
        allowedFrets: normalizedAllowedFrets,
        using: &initialGenerator
    )
}
```

### 修改后

- 主验证器改成 `validateFilterScenario(...)`
- 新增 `matchesPositionPromptFilter(...)` 作为统一合法性判断基线
- 自动验证现在对 `.noteNames(...)` 和 `.frets(...)` 两种 filter 走同一条验证路径

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...), matchesPositionPromptFilter(_:filter:),
// validateFilterScenario(name:filter:requiresNoOpenStrings:)
// 功能说明: 修改后 position prompt validation 正式切到统一 filter 场景；
// 候选池、首题、错误作答、正确换题都按 activeFilter 验证，不再只认 fret 集合。
func matchesPositionPromptFilter(
    _ cell: FretboardCell,
    filter: PositionPromptCandidateFilter
) -> Bool {
    guard let pitchClass = configuration.pitchClass(for: cell),
          pitchClass.isNatural else {
        return false
    }

    switch Self.normalizedPositionPromptFilter(filter) {
    case let .noteNames(selectedPitchClasses):
        return selectedPitchClasses.contains(pitchClass)
    case let .frets(selectedFrets):
        return selectedFrets.contains(cell.fret)
    }
}

func validateFilterScenario(
    name: String,
    filter: PositionPromptCandidateFilter,
    requiresNoOpenStrings: Bool
) {
    let normalizedFilter = Self.normalizedPositionPromptFilter(filter)

    let candidateCells = positionPromptCandidateCells(
        configuration: configuration,
        filter: normalizedFilter
    )

    if !candidateCells.allSatisfy({
        matchesPositionPromptFilter($0, filter: normalizedFilter)
    }) {
        record("position prompt trainer \(name) 的候选池包含了未命中当前 active filter 的位置。")
    }

    let initialSession = initialTrainer.makePositionPromptSession(
        configuration: configuration,
        filter: normalizedFilter,
        using: &initialGenerator
    )
}
```

## 修改 2：错误作答 / 正确换题验证改为断言“始终命中 activeFilter”

### 修改前

- 错误作答和正确换题后的断言都只检查 `nextPromptCell.fret` 是否还在 `allowedFrets`
- 这无法证明在 `noteName` 模式下，下一题仍然落在所选音名集合内

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...)
// 功能说明: 修改前错误作答 / 正确换题后的合法性断言仍然只认 allowedFrets。
if !normalizedAllowedFrets.contains(evaluation.nextPromptCell.fret) {
    record("position prompt trainer \(name) 错误作答后 nextPromptCell 仍应落在允许品位内。")
}

if !normalizedAllowedFrets.contains(evaluation.nextPromptCell.fret) {
    record("position prompt trainer \(name) 正确作答后 nextPromptCell 应继续落在允许品位内。")
}
```

### 修改后

- 错误作答后的 `nextPromptCell`
- 正确换题后的 `nextPromptCell`
- 推进后的 `session.promptCell`
- 现在都统一通过 `matchesPositionPromptFilter(...)` 断言“仍命中当前 activeFilter”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...)
// 功能说明: 修改后错误作答不换题、正确作答换到新题，这两条契约都统一要求题目继续命中 activeFilter。
if !matchesPositionPromptFilter(
    evaluation.nextPromptCell,
    filter: normalizedFilter
) {
    record("position prompt trainer \(name) 错误作答后 nextPromptCell 仍应命中当前 active filter。")
}

if !matchesPositionPromptFilter(
    evaluation.nextPromptCell,
    filter: normalizedFilter
) {
    record("position prompt trainer \(name) 正确作答后 nextPromptCell 应继续命中当前 active filter。")
}

if !matchesPositionPromptFilter(correctSession.promptCell, filter: normalizedFilter) {
    record("position prompt trainer \(name) 正确作答后 session.promptCell 应继续命中当前 active filter。")
}
```

## 修改 3：补齐默认 note-name、音名子集、最后一个音名保护

### 修改前

- validation 只检查“最后一个品位不可取消”
- 场景只覆盖默认品位集合和 `1/3/5/7`
- 默认 `noteName = C/E/F/B` 与“最后一个音名不可取消”都没有自动验证

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...)
// 功能说明: 修改前 validation 只覆盖 default frets / subset frets，
// 以及最后一个已选品位保护，没有覆盖默认音名模式和最后一个音名保护。
let lockedFretConfiguration = TrainerPositionPromptConfiguration(
    selectedFrets: [7]
)
if lockedFretConfiguration.canDeselect(7) {
    record("position prompt 配置在只剩最后一个已选品位时不应允许 canDeselect 返回 true。")
}

validateAllowedFretsScenario(
    name: "defaultSelectedFrets",
    allowedFrets: TrainerPositionPromptConfiguration.defaultSelectedFrets,
    requiresNoOpenStrings: true
)
validateAllowedFretsScenario(
    name: "subset_1_3_5_7",
    allowedFrets: [1, 3, 5, 7],
    requiresNoOpenStrings: true
)
```

### 修改后

- 新增默认配置断言：`filterMode == .noteName`、默认 `selectedPitchClasses == C/E/F/B`
- 新增“最后一个音名不可取消”保护验证
- 自动场景扩展为：
- `defaultNoteNames`
- `subset_C_E`
- `defaultSelectedFrets`
- `subset_1_3_5_7`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(...)
// 功能说明: 修改后 validation 会显式校验默认 noteName 配置、音名子集场景，
// 并验证“最后一个音名不可取消”与“最后一个品位不可取消”两条保护逻辑。
let defaultPositionPromptConfiguration =
    TrainerPositionPromptConfiguration.default
if defaultPositionPromptConfiguration.filterMode != .noteName {
    record("position prompt 默认 filterMode 应为 .noteName。")
}
if defaultPositionPromptConfiguration.selectedPitchClasses
    != TrainerPositionPromptConfiguration.defaultSelectedPitchClasses {
    record("position prompt 默认 selectedPitchClasses 未对齐 C/E/F/B。")
}

let lockedPitchClassConfiguration = TrainerPositionPromptConfiguration(
    selectedPitchClasses: [.c]
)
if lockedPitchClassConfiguration.canDeselect(.c) {
    record("position prompt 配置在只剩最后一个已选音名时不应允许 canDeselect 返回 true。")
}

validateFilterScenario(
    name: "defaultNoteNames",
    filter: defaultPositionPromptConfiguration.activeFilter,
    requiresNoOpenStrings: false
)
validateFilterScenario(
    name: "subset_C_E",
    filter: TrainerPositionPromptConfiguration(
        filterMode: .noteName,
        selectedPitchClasses: [.c, .e]
    ).activeFilter,
    requiresNoOpenStrings: false
)
validateFilterScenario(
    name: "defaultSelectedFrets",
    filter: TrainerPositionPromptConfiguration(
        filterMode: .fret,
        selectedFrets: TrainerPositionPromptConfiguration.defaultSelectedFrets
    ).activeFilter,
    requiresNoOpenStrings: true
)
```

## 修改 4：validation 辅助候选池函数同步改成统一 `filter`

### 修改前

- validation 内部的 `positionPromptCandidateCells(...)` 仍然只接受 `allowedFrets`
- 这会导致“主验证器升级了，但辅助基准候选池仍然停在旧语义”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: positionPromptCandidateCells(configuration:allowedFrets:)
// 功能说明: 修改前 validation 侧的基准候选池仍然只按 allowedFrets 过滤。
static func positionPromptCandidateCells(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets
) -> [FretboardCell] {
    let normalizedAllowedFrets = TrainerPositionPromptConfiguration(
        selectedFrets: allowedFrets
    ).selectedFrets

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            guard normalizedAllowedFrets.contains(fret) else {
                continue
            }
            // ...
        }
    }
}
```

### 修改后

- 新增 `normalizedPositionPromptFilter(_:)`
- `positionPromptCandidateCells(...)` 改成接受统一 `filter`
- `noteName` / `fret` 两种模式都用同一份 validation 基准候选池

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: normalizedPositionPromptFilter(_:), positionPromptCandidateCells(configuration:filter:)
// 功能说明: 修改后 validation 侧的基准候选池与 shared trainer 语义对齐，
// 同时支持 noteName / fret 两种互斥过滤模式。
static func normalizedPositionPromptFilter(
    _ filter: PositionPromptCandidateFilter
) -> PositionPromptCandidateFilter {
    switch filter {
    case let .noteNames(selectedPitchClasses):
        return TrainerPositionPromptConfiguration(
            filterMode: .noteName,
            selectedPitchClasses: selectedPitchClasses
        ).activeFilter
    case let .frets(selectedFrets):
        return TrainerPositionPromptConfiguration(
            filterMode: .fret,
            selectedFrets: selectedFrets
        ).activeFilter
    }
}

static func positionPromptCandidateCells(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter
) -> [FretboardCell] {
    let normalizedFilter = normalizedPositionPromptFilter(filter)

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            // ...
            switch normalizedFilter {
            case let .noteNames(selectedPitchClasses):
                guard selectedPitchClasses.contains(pitchClass) else {
                    continue
                }
            case let .frets(selectedFrets):
                guard selectedFrets.contains(fret) else {
                    continue
                }
            }
        }
    }
}
```

## 修改 5：手工回归 checklist 从旧的 `Frets` 口径更新到 `Note Names | Frets`

### 修改前

- checklist 仍然要求“确认默认选中 `1...12`”
- 也只提到“切换品位筛选”
- 和现在默认 `Filter = Note Names`、默认 `C/E/F/B` 的真实行为已经不一致

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: manualChecklist(for:)
// 功能说明: 修改前手工回归清单仍然停留在旧的 fret-only 语义。
[
    "在 `single` 与 `sequence` 模式下打开设置面板，确认 `Trainer` 分区不显示 `Frets` 这一行；切到 `positionPrompt` 后再确认该行出现，并默认选中 `1...12`。",
    "在 `positionPrompt` 默认全选状态下连续答对多次，确认题目不会落在空弦，只会出现在 `1...12` 品。",
    "在 `positionPrompt` 里只保留 `1 / 3 / 5 / 7` 这几个品位后连续答对多次，确认当前题与下一题都只落在这些品位。"
]
```

### 修改后

- checklist 先验证 `Filter = Note Names` 与默认 `C/E/F/B`
- 再验证切到 `Frets` 后的回显和行为
- 还补了“只保留 `C/E`”和“反馈动画期间切过滤模式/选项”的回归项

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: manualChecklist(for:)
// 功能说明: 修改后手工回归清单与新的 Note Names / Frets 双模式行为保持一致。
[
    "在 `single` 与 `sequence` 模式下打开设置面板，确认 `Trainer` 分区不显示 `Filter` 与位置题多选过滤行；切到 `positionPrompt` 后确认出现 `Filter = Note Names`，且默认选中 `C / E / F / B`。",
    "在 `positionPrompt` 默认 `Filter = Note Names`、默认 `C / E / F / B` 状态下连续答对多次，确认当前题与下一题都只落在这些音名，且会从当前指板全部合法位置出题（包含命中这些音名的空弦）。",
    "把 `positionPrompt` 的 `Filter` 切到 `Frets`，确认会回显当前品位集合；连续答对多次，确认当前题与下一题都只落在当前已选品位。",
    "在 `positionPrompt` 里只保留 `C / E` 这两个音名后连续答对多次，确认当前题与下一题都只落在 `C / E`，不受已保存品位集合干扰。",
    "在 `wrongFlash` 或 `correctHold` 期间切换过滤模式或当前激活模式下的过滤选项；若当前可见题目已变成非法题，确认界面会平滑切换到新题，不残留错误 overlay 或延时切题任务。"
]
```

## 验证情况

- 已对以下文件运行 `ReadLints`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 结果：无 linter 报错
- 本次未运行 `xcodebuild` / 应用启动验证，因此这份记录只确认 validation 改造与 IDE lint 状态

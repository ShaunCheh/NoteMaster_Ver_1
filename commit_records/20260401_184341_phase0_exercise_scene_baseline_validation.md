# 20260401_184341_phase0_exercise_scene_baseline_validation

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_184341`
- 记录范围：`场景树迁移` 计划的阶段 0，只覆盖“迁移前基线冻结”，不引入 `ExerciseScene`、不切换 renderer、不调整用户可见布局
- 修改性质：新增 shared 基线校验、补强现有 validation 断言与手工清单、把阶段 0 校验接入 iOS/macOS 启动链路
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`

## 修改前

- Shared 层已经有 `Fretboard / Staff / SettingsNavigation / Piano` 四类 validation，但没有一条专门冻结“旧页面编排基线”的 validation runner。
- `SettingsNavigationValidation` 更关注导航树、路由显隐、字符串稳定性，还没有明确锁定 `Page` 分区、`Top Content / Main Content`、`Piano Visible` 这些旧入口必须在阶段 0 保持不动。
- `FretboardValidation` 虽然覆盖了几何、trainer、`positionPrompt`、`quarterNoteSequence`，但没有单独验证：
  - `single / sequence` 继续保持 `staff -> fretboard`
  - `positionPrompt` 继续保持 `fretboard -> naturalNoteStrip`
  - 默认 `vertical viewport` 仍然是旧值
- `PianoValidation` 还没有显式冻结 `PianoPanelState.isVisible` 的默认隐藏语义，也没有验证 settings 层对 `pianoVisible` 的写回回显。
- iOS/macOS 启动链路只跑了 `Fretboard / Staff / SettingsNavigation` 三条 validation，`PianoValidationRunner` 和新的页面编排基线 validation 都不会在 Debug 启动时自动执行。

```text
# 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前 Shared 层没有专门冻结旧页面编排基线的 validation runner。
（文件不存在）
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改前 iOS 启动阶段只会自动执行 fretboard / staff / settings navigation 三条 validation。
print("[Startup][iOSApp] run fretboard validation")
FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run staff validation")
StaffValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .iOS)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改前 fixture 列表与手工清单没有锁定 Page 分区旧入口和 Piano Visible 的兼容基线。
SettingsNavigationValidationFixture(
    name: "fretboard_string_thickness_option_tracks_state",
    validate: validateFretboardStringThicknessOptionTracksState
),
SettingsNavigationValidationFixture(
    name: "reconciled_path_falls_back_to_existing_parent",
    validate: validateReconciledPathFallsBackToExistingParent
)

[
    "在 \\(platform.displayName) 上确认 close 永远关闭整个 settings card，而不是只关闭当前子页。",
    "确认在 root 页隐藏返回按钮；进入 section 或更深页面后显示返回按钮，点击后只回退卡片内一层。",
    "确认 root -> Trainer / Staff / Piano 的 section page 可以继续进入深层子页，标题与内容和共享 builder 生成的 route 一致。"
]
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validate(_:)
// 功能说明: 修改前 Fretboard validation 会跑 trainer/geometry 相关夹具，但不会单独冻结旧页面编排基线。
runStep("validateSingleCoverageTrainer") {
    validateSingleCoverageTrainer(
        fixture: fixture,
        record: record
    )
}
runStep("validatePositionPromptTrainer") {
    validatePositionPromptTrainer(
        fixture: fixture,
        record: record
    )
}
runStep("validateQuarterNoteSequenceTrainer") {
    validateQuarterNoteSequenceTrainer(
        fixture: fixture,
        record: record
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures(), validatePianoPanelStateInferenceAndClamp()
// 功能说明: 修改前没有显式校验 pianoVisible 的默认隐藏语义，只验证了 panel inference/clamp。
PianoValidationFixture(
    name: "configuration_resolves_safe_metrics",
    validate: validateConfigurationResolvesSafeMetrics
),
PianoValidationFixture(
    name: "piano_panel_state_infers_and_clamps_supported_values",
    validate: validatePianoPanelStateInferenceAndClamp
)

if inferred.rowCount != 2 {
    issues.append(issue(fixtureName, "inferred rowCount 应保留当前 rows.count。"))
}
if inferred.movementScope != .rowOnly {
    issues.append(issue(fixtureName, "inferred movementScope 应沿用首行 movementScope。"))
}
```

## 修改后

### 1. 新增独立的页面编排基线 validation runner

- 新增 `ExerciseCompositionValidationRunner`
- 用单独的 shared 文件冻结旧编排模型，而不是把这批约束继续散落到 `FretboardValidation` 或 controller 里
- 首批固定了 5 组基线：
  - `single` -> `staff over fretboard`
  - `sequence` -> `staff over fretboard`
  - `positionPrompt` -> `fretboard over naturalNoteStrip`
  - `PageDisplayState` 的单 `fretboard` 归一化规则
  - `pianoVisible` 与 `vertical viewport` 的默认状态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures()
// 功能说明: 修改后新增专门的阶段 0 shared runner，集中冻结旧页面编排和旧设置投影基线。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
            validate: validateLegacySingleBaseline
        ),
        ExerciseCompositionValidationFixture(
            name: "legacy_sequence_baseline_matches_stacked_staff_over_fretboard",
            validate: validateLegacySequenceBaseline
        ),
        ExerciseCompositionValidationFixture(
            name: "legacy_position_prompt_baseline_matches_fretboard_over_natural_strip",
            validate: validateLegacyPositionPromptBaseline
        ),
        ExerciseCompositionValidationFixture(
            name: "page_state_normalization_preserves_single_fretboard_slot",
            validate: validatePageStateNormalizationPreservesSingleFretboardSlot
        ),
        ExerciseCompositionValidationFixture(
            name: "layout_defaults_keep_piano_hidden_and_vertical_viewport_visible",
            validate: validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible
        )
    ]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateLegacyBaseline(fixtureName:exerciseMode:expectedPageDisplayState:)
// 功能说明: 修改后把 single / sequence / positionPrompt 三条 legacy 组合收口成同一套断言，
// 同时检查对应模式下 Trainer settings snapshot 仍然投影成旧结构。
let stateContext = SettingsPanelStateContext(
    pageDisplayState: expectedPageDisplayState,
    trainerDisplayState: TrainerDisplayState(exerciseMode: exerciseMode)
)
let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)

switch exerciseMode {
case .single, .sequence:
    if expectedPageDisplayState.topContentMode != .staff
        || expectedPageDisplayState.mainContentMode != .fretboard {
        issues.append(
            issue(
                fixtureName,
                "single / sequence 的 legacy baseline 应保持 staff -> fretboard。"
            )
        )
    }
case .positionPrompt:
    if expectedPageDisplayState.topContentMode != .fretboard
        || expectedPageDisplayState.mainContentMode != .naturalNoteStrip {
        issues.append(
            issue(
                fixtureName,
                "positionPrompt 的 legacy baseline 应保持 fretboard -> naturalNoteStrip。"
            )
        )
    }
}
```

### 2. 补强 SettingsNavigationValidation 的旧入口基线

- 新增 `legacy_page_rows_and_piano_visibility_state_remain_stable`
- 明确锁定阶段 0 仍必须保留的旧入口：
  - `Page` 分区
  - `Top Content`
  - `Main Content`
  - `Piano Behavior > Visible`
- 同时把这部分加入 `manualChecklist`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改后把 legacy page / pianoVisible 兼容基线加入自动化 fixture 与手工回归清单。
SettingsNavigationValidationFixture(
    name: "fretboard_string_thickness_option_tracks_state",
    validate: validateFretboardStringThicknessOptionTracksState
),
SettingsNavigationValidationFixture(
    name: "legacy_page_rows_and_piano_visibility_state_remain_stable",
    validate: validateLegacyPageRowsAndPianoVisibilityStateRemainStable
),
SettingsNavigationValidationFixture(
    name: "reconciled_path_falls_back_to_existing_parent",
    validate: validateReconciledPathFallsBackToExistingParent
)

"确认阶段 0 期间 `Page` 分区仍保留 `Top Content / Main Content` 两行，`Piano > Behavior` 仍保留 `Visible` 开关。后续阶段替换前，这些旧入口不应先漂移。"
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: validateLegacyPageRowsAndPianoVisibilityStateRemainStable()
// 功能说明: 修改后显式验证 Page section、Top/Main Content 默认选择与 Piano Visible 的写回回显。
if pageSection.rows.map(\\.id) != [
    .choice(.topContent),
    .choice(.mainContent)
] {
    issues.append(
        issue(
            fixtureName,
            "Page section row 顺序应继续保持 Top Content -> Main Content。"
        )
    )
}

let fretboardTopChoiceIsEnabled = topContentRow.choices.first(
    where: { $0.id == .setTopContentFretboard }
)?.isEnabled ?? true
if fretboardTopChoiceIsEnabled {
    issues.append(
        issue(
            fixtureName,
            "Top Content row 中的 Fretboard 选项在 legacy model 下应继续保持禁用。"
        )
    )
}

if pianoBehaviorSection.rows.map(\\.id) != [
    .toggle(.pianoVisible),
    .slider(.pianoRowCount),
    .choice(.pianoMovementScope),
    .toggle(.pianoSnapEnabled)
] {
    issues.append(
        issue(
            fixtureName,
            "Piano Behavior page rows 应继续保持 Visible / Rows / Row Linking / Snap Drag。"
        )
    )
}
```

### 3. 补强 FretboardValidation 的旧布局锚点

- 在 `validate(_:)` 主流程里新增 `validateLegacyLayoutBaselines`
- 专门冻结：
  - `PageDisplayState.default`
  - `PageDisplayState.positionPrompt`
  - 默认 `verticalHostHeightRatio`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validate(_:)
// 功能说明: 修改后把 legacy layout baseline 校验作为单独步骤接入 Fretboard validation 主流程。
runStep("validateQuarterNoteSequenceTrainer") {
    validateQuarterNoteSequenceTrainer(
        fixture: fixture,
        record: record
    )
}
runStep("validateLegacyLayoutBaselines") {
    validateLegacyLayoutBaselines(
        fixture: fixture,
        record: record
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateLegacyLayoutBaselines(fixture:record:)
// 功能说明: 修改后只在 reference fixture 上冻结旧页面编排组合与默认 viewport 参数。
let defaultPageDisplayState = PageDisplayState.default
if defaultPageDisplayState.topContentMode != .staff
    || defaultPageDisplayState.mainContentMode != .fretboard {
    record("legacy default page baseline 应继续保持 staff -> fretboard。")
}
if defaultPageDisplayState.showsFretboardInTopContent
    || !defaultPageDisplayState.showsFretboardInMainContent
    || !defaultPageDisplayState.hasValidFretboardPlacement {
    record("legacy default page baseline 应继续只在 mainContent 承载 fretboard。")
}

let positionPromptPageDisplayState = PageDisplayState.positionPrompt
if positionPromptPageDisplayState.topContentMode != .fretboard
    || positionPromptPageDisplayState.mainContentMode != .naturalNoteStrip {
    record("legacy positionPrompt baseline 应继续保持 fretboard -> naturalNoteStrip。")
}

if !approximatelyEqual(
    FretboardDisplayState.default.verticalHostHeightRatio,
    FretboardDisplayState.defaultVerticalHostHeightRatio
) {
    record("迁移前 default verticalHostHeightRatio 应继续对齐 defaultVerticalHostHeightRatio。")
}
```

### 4. 补强 PianoValidation 的默认隐藏语义

- 新增 `piano_panel_visibility_defaults_hidden`
- 把 `PianoPanelState()`、`PianoPanelState.inferred(...)`、`SettingsToggleID.pianoVisible` 的默认关闭语义收口成一条夹具
- 在 `validatePianoPanelStateInferenceAndClamp()` 里补上 `inferred.isVisible` 的显式断言

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改后把钢琴默认隐藏的兼容基线纳入自动化和手工回归范围。
PianoValidationFixture(
    name: "configuration_resolves_safe_metrics",
    validate: validateConfigurationResolvesSafeMetrics
),
PianoValidationFixture(
    name: "piano_panel_visibility_defaults_hidden",
    validate: validatePianoPanelVisibilityDefaults
),
PianoValidationFixture(
    name: "piano_panel_state_infers_and_clamps_supported_values",
    validate: validatePianoPanelStateInferenceAndClamp
)

"确认 `Piano Visible` 默认关闭；打开后才出现钢琴区域，关闭后会恢复主内容底边约束而不是改变 prompt/answer 主组合。"
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validatePianoPanelVisibilityDefaults(), validatePianoPanelStateInferenceAndClamp()
// 功能说明: 修改后显式验证默认隐藏和 settings toggle 回写，同时补上 inferred.isVisible 的断言。
let defaultState = PianoPanelState()
let inferredState = PianoPanelState.inferred(
    configuration: PianoConfiguration(),
    rows: []
)

if defaultState.isVisible {
    issues.append(issue(fixtureName, "PianoPanelState() 默认应继续保持 isVisible=false。"))
}
if inferredState.isVisible {
    issues.append(issue(fixtureName, "PianoPanelState.inferred(...) 默认应继续保持 isVisible=false。"))
}

SettingsToggleID.pianoVisible.apply(value: true, to: &settingsStateContext)
if !settingsStateContext.pianoPanelState.isVisible {
    issues.append(issue(fixtureName, "Piano Visible toggle 写回后应把 pianoPanelState.isVisible 置为 true。"))
}

if inferred.isVisible {
    issues.append(issue(fixtureName, "inferred panel state 默认不应直接把钢琴标记为可见。"))
}
```

### 5. 把阶段 0 基线接入启动校验链路

- iOS/macOS 的 Debug 启动阶段现在会自动跑：
  - `PianoValidationRunner`
  - `ExerciseCompositionValidationRunner`
- 这样后续只要有人改坏旧编排基线，启动时就能直接看到 assertion failure，而不是等到阶段 2/3 再手工发现

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改后 iOS 启动阶段除了旧三条 validation 之外，还会自动执行 piano 与 exercise composition 基线校验。
print("[Startup][iOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run exercise composition validation")
ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 修改后 macOS 启动阶段同样把 piano 与 exercise composition 基线校验接入了统一启动链路。
print("[Startup][macOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run piano validation")
PianoValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run exercise composition validation")
ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
```

## 验证结果

- `ReadLints`：本次涉及文件无 lint 报错
- 构建验证：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination "platform=macOS" build` 通过
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination "generic/platform=iOS Simulator" build` 通过
- 运行时说明：
  - 我没有在这一步实际启动 App
  - 但后续以 Debug 方式启动 iOS/macOS App 时，会自动执行新接入的 `PianoValidationRunner` 与 `ExerciseCompositionValidationRunner`

## 当前结论

- 阶段 0 已完成，仓库现在已经有一套明确的“旧页面编排基线防护网”
- 后续进入阶段 1 时，可以在不动 renderer 的前提下并行引入 `ExerciseScene` 相关 shared 契约
- 一旦阶段 1/2/3 的改动误伤了旧的 `staff -> fretboard` / `fretboard -> naturalNoteStrip` / `pianoVisible` / `vertical viewport` 行为，这批基线校验会在最早阶段报警

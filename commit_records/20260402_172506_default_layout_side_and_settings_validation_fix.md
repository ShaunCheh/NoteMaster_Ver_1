# 20260402_172506_default_layout_side_and_settings_validation_fix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260402_172506`
- 记录范围：将应用默认 `Layout Preset` 改为 `sideBySide`，并修正因此触发的启动期 `SettingsNavigationValidation` 断言失败
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本轮实际落地文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`

## 1. 背景与问题现象

- 需求：无论 macOS 还是 iOS，应用启动后的默认 `layout` 都改为 `side`
- 第一阶段修改完成后，`ExerciseLayoutPreferences` 的共享默认值已经切到 `sideBySide`
- 随后在 iOS / macOS 启动期，`DEBUG` 校验 `SettingsNavigationValidation.runAndReportIfNeeded(platform:)` 失败，并在 `assertionFailure(...)` 处直接终止

```text
# 日志来源: iOS/macOS 启动期自动校验 | 函数: SettingsNavigationValidationRunner.runAndReportIfNeeded(platform:)
[SettingsNavigationValidation][iOS] automated=FAIL fixtures=10
通过夹具: root_route_items_match_panel_sections, split_sections_produce_expected_page_tree, position_prompt_section_visibility_tracks_exercise_mode, fretboard_viewport_route_visibility_tracks_display_mode, fretboard_string_thickness_option_tracks_state, reconciled_path_falls_back_to_existing_parent, exercise_layout_route_remains_stable_across_choice_updates, reserved_route_titles_remain_stable, reserved_accessibility_identifier
```

- 通过列表里缺失的唯一夹具是 `exercise_and_accessory_rows_match_stage7_capabilities`
- 这说明崩溃不是新逻辑本身坏了，而是启动期的共享校验还保留着“默认 layout = stacked”的旧假设

## 2. 根因

根因分成两层：

1. `ExerciseLayoutPreferences` 的默认值已经被改为 `sideBySide`，所以共享状态、平台控制器启动默认值都会跟着切到 `side`
2. 部分 validation 代码仍然把“旧默认值”当成“显式 stacked 夹具”来使用，导致语义混淆：
   - `ExerciseCompositionValidation.swift` 里有 3 处测试本意是“验证 stacked 语义”，但之前借用了 `.legacyPositionPrompt`
   - `SettingsNavigationValidation.swift` 里有 1 处直接断言默认选中项必须是 `Stacked`

所以这次修复不是只改一个启动断言，而是把“默认值”和“显式 stacked 夹具”彻底拆开。

## 3. 修改一：共享默认 layout 改为 `sideBySide`

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数/符号: ExerciseLayoutPreferences.legacyPositionPrompt, ExerciseLayoutPreferences.init(...)
// 修改前说明: 共享默认值和 positionPrompt 启动默认值都仍然落到 stacked。
static let `default` = ExerciseLayoutPreferences()
static let legacyPositionPrompt = ExerciseLayoutPreferences(
    compositionPreset: .fretboardToNaturalNoteStrip,
    layoutPreset: .stacked,
    accessoryPresentation: .docked,
    isNaturalNoteStripVisible: true,
    isPianoAccessoryVisible: false,
    isAccessoryExpanded: true
)

init(
    compositionPreset: ExerciseCompositionPreset = .staffToFretboard,
    layoutPreset: ExerciseLayoutPreset = .stacked,
    accessoryPresentation: ExerciseAccessoryPresentation = .docked,
    isNaturalNoteStripVisible: Bool = false,
    isPianoAccessoryVisible: Bool = false,
    isAccessoryExpanded: Bool = true
) {
    self.compositionPreset = compositionPreset
    self.layoutPreset = layoutPreset
    self.accessoryPresentation = accessoryPresentation
    self.isNaturalNoteStripVisible = isNaturalNoteStripVisible
    self.isPianoAccessoryVisible = isPianoAccessoryVisible
    self.isAccessoryExpanded = isAccessoryExpanded
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数/符号: ExerciseLayoutPreferences.legacyPositionPrompt, ExerciseLayoutPreferences.init(...)
// 修改后说明: 共享默认值和 positionPrompt 启动默认值统一切到 sideBySide。
static let `default` = ExerciseLayoutPreferences()
static let legacyPositionPrompt = ExerciseLayoutPreferences(
    compositionPreset: .fretboardToNaturalNoteStrip,
    layoutPreset: .sideBySide,
    accessoryPresentation: .docked,
    isNaturalNoteStripVisible: true,
    isPianoAccessoryVisible: false,
    isAccessoryExpanded: true
)

init(
    compositionPreset: ExerciseCompositionPreset = .staffToFretboard,
    layoutPreset: ExerciseLayoutPreset = .sideBySide,
    accessoryPresentation: ExerciseAccessoryPresentation = .docked,
    isNaturalNoteStripVisible: Bool = false,
    isPianoAccessoryVisible: Bool = false,
    isAccessoryExpanded: Bool = true
) {
    self.compositionPreset = compositionPreset
    self.layoutPreset = layoutPreset
    self.accessoryPresentation = accessoryPresentation
    self.isNaturalNoteStripVisible = isNaturalNoteStripVisible
    self.isPianoAccessoryVisible = isPianoAccessoryVisible
    self.isAccessoryExpanded = isAccessoryExpanded
}
```

- 结果：默认应用状态改为 `side`
- 影响面：`SettingsPanelStateContext.default`、iOS/macOS 控制器启动默认布局、以及共享 state 的默认构造都会继承这个变化

## 4. 修改二：把 stacked 语义夹具从“借用 legacy 默认”改成“显式 stacked”

受影响函数：

- `validateSurfaceMembershipDistinguishesAbsentAndHiddenStates()`
- `validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()`
- `validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()`

这 3 处修改模式相同，下面展示一处代表性修改。

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateSurfaceMembershipDistinguishesAbsentAndHiddenStates()
// 修改前说明: 这里本意是构造“显式 stacked 的 positionPrompt 场景”，
// 但实际却借用了 .legacyPositionPrompt；一旦 legacy 默认切到 side，这里就不再稳定表示 stacked。
let stackedPositionPromptPresentation = ExerciseCompositionPolicy
    .makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: TrainerDisplayState(
                exerciseMode: .positionPrompt
            ),
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: .legacyPositionPrompt
        )
    )
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateSurfaceMembershipDistinguishesAbsentAndHiddenStates()
// 修改后说明: stacked 基线不再依赖 legacy 默认值，而是显式构造 stacked 语义。
let stackedPositionPromptPresentation = ExerciseCompositionPolicy
    .makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: TrainerDisplayState(
                exerciseMode: .positionPrompt
            ),
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
    )
```

- 同样的显式 `stacked` 替换也应用到了：
  - `validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()`
  - `validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()`

- 结果：validation 不再把“默认值变化”误当成“stacked 语义回归”

## 5. 修改三：修正启动期 `SettingsNavigationValidation` 的默认选中断言

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数: validateExerciseAndAccessoryRowsMatchStage7Capabilities()
// 修改前说明: 启动期导航夹具仍然断言默认 Layout Preset 必须选中 stacked。
if layoutRow.choices.filter(\.isSelected).map(\.id) != [
    .setLayoutPresetStacked
] {
    issues.append(
        issue(
            fixtureName,
            "default state 应继续默认选中 Stacked layout。"
        )
    )
}
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数: validateExerciseAndAccessoryRowsMatchStage7Capabilities()
// 修改后说明: 夹具默认选中项对齐到新的 sideBySide 启动默认值。
if layoutRow.choices.filter(\.isSelected).map(\.id) != [
    .setLayoutPresetSideBySide
] {
    issues.append(
        issue(
            fixtureName,
            "default state 应默认选中 Side by Side layout。"
        )
    )
}
```

- 结果：`runAndReportIfNeeded(platform:)` 不会再因为这条过期断言在 iOS / macOS 启动期直接 `assertionFailure(...)`

## 6. 最终结果

- 共享默认 `Layout Preset` 已切换为 `sideBySide`
- 所有需要“显式 stacked 语义”的 validation 夹具，已经与启动默认值彻底解耦
- 启动期 `SettingsNavigationValidation` 默认选中断言已经对齐到新默认值

## 7. 验证结果

- `ReadLints` 检查本轮修改文件：无新增 linter 错误
- macOS 构建验证：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build` 通过
- iOS 模拟器构建验证：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build` 通过

## 8. 一句话总结

这次修改不是单纯“把默认 layout 改成 side”，而是同步把所有仍然依赖“旧默认 = stacked”的共享校验一起校正；这样默认值变化、显式 stacked 夹具、以及启动期 validation 三者的语义才重新一致。

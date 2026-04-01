# 20260401_193410_phase2_settings_preset_migration

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_193410`
- 记录范围：`场景树迁移` 计划的阶段 2；把设置项从 `Page / Top Content / Main Content` 迁到 `Composition Preset / Layout Preset / Accessory Presentation`，但短期仍通过 bridge 投影回旧 `PageDisplayState`
- 修改性质：新增 legacy layout bridge；重组 settings 分区、路由和 snapshot；迁移主要 validation 断言与关键手工清单到新入口；现有 iOS / macOS renderer 暂不切换
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`

## 修改前

- Shared 层还没有把新 `ExerciseLayoutPreferences` 与旧 `PageDisplayState` 连接起来的 bridge 文件。

```text
# 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
# 函数名: N/A（修改前文件不存在）
# 功能说明: 修改前没有统一的兼容层来完成“旧页面状态 -> 新预设偏好 -> 旧页面状态”的推导与回投影。
（文件不存在）
```

- `SettingsPanelStateContext` 虽然已经并存了 `exerciseLayoutPreferences` 字段，但默认值仍是直接注入 `.default`，不会从 legacy 状态自动推导。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: init(...), static let `default`
// 功能说明: 修改前 settings shared context 不会根据 legacy page/piano/trainer 状态反推新的布局偏好。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState

    static let `default` = SettingsPanelStateContext()

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState = .default,
        exerciseLayoutPreferences: ExerciseLayoutPreferences = .default,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init()
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.pageDisplayState = pageDisplayState
        self.exerciseLayoutPreferences = exerciseLayoutPreferences
        self.trainerDisplayState = trainerDisplayState
        self.pianoPanelState = pianoPanelState
    }
}
```

- settings 入口仍然以 `Page / Trainer / Layout` 为中心组织；`Top Content / Main Content / Piano Visible` 这些旧坑位入口还在主 UI 模型里。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.rowIDs, SettingsChoiceRowID.sectionID, SettingsToggleID.sectionID
// 功能说明: 修改前分区和 row 仍围绕 page slot 模型组织，位置题过滤也仍挂在 Trainer 分区里。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case piano
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
                .choice(.exerciseMode),
                .choice(.positionPromptFilterMode),
                .positionFilter(.positionPromptFilterOptions)
            ]
        case .fretboard:
            return [
                .choice(.instrument),
                .choice(.displayMode),
                .choice(.stringThickness),
                .choice(.labels),
                .choice(.spelling),
                .choice(.octave)
            ]
        case .layout:
            return [
                .slider(.verticalHostHeightRatio)
            ]
        case .piano:
            return [
                .toggle(.pianoVisible),
                .slider(.pianoRowCount),
                .choice(.pianoMovementScope),
                .choice(.pianoWhiteKeyStyle),
                .toggle(.pianoSnapEnabled)
            ]
        // ... case .staff / .debug 等其他未改动分区省略
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case exerciseMode
    case positionPromptFilterMode
    case instrument
    case displayMode
    // ... 其他未改动 case 省略

    var sectionID: SettingsSectionID {
        switch self {
        case .topContent, .mainContent:
            return .page
        case .exerciseMode, .positionPromptFilterMode:
            return .trainer
        // ... case .instrument / .displayMode / .clef / .pianoMovementScope 等其他映射省略
        }
    }
}

enum SettingsToggleID: CaseIterable, Equatable, Hashable, Sendable {
    case showsComponentBounds
    case pianoVisible
    case pianoSnapEnabled

    var sectionID: SettingsSectionID {
        switch self {
        case .showsComponentBounds:
            return .debug
        case .pianoVisible, .pianoSnapEnabled:
            return .piano
        }
    }
}
```

- `SettingsPanelSnapshotBuilder` 生成 snapshot 时不会先对新旧状态做 reconcile，所以新偏好与旧 page state 之间没有统一归一化入口。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: makeModel(from:)
// 功能说明: 修改前 snapshot builder 直接使用传入 stateContext 生成 section，不会先走 bridge 归一化。
enum SettingsPanelSnapshotBuilder {
    static func makeModel(
        from stateContext: SettingsPanelStateContext
    ) -> SettingsPanelModel {
        SettingsPanelModel(
            sections: SettingsSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    stateContext: stateContext
                )
            }
        )
    }
}
```

- settings 路由模型和子页树还没有 `Exercise / Accessories / Fretboard Viewport` 这些新入口。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: SettingsRouteID.fallbackTitle, accessibilityIdentifierComponent
// 功能说明: 修改前 route 只覆盖 Trainer / Staff / Piano 等旧结构。
enum SettingsRouteID: Equatable, Hashable, Sendable {
    case root
    case section(SettingsSectionID)
    case trainerExercise
    case trainerPositionFilter
    case staffClef
    case staffLayout
    case pianoBehavior
    case pianoAppearance
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: childPageSpecs(for:)
// 功能说明: 修改前导航树仍使用 Trainer / Page / Layout 结构，Piano Behavior 仍直接暴露 Visible 开关。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    case .trainer:
        return [
            ChildPageSpec(
                route: .trainerExercise,
                title: SettingsRouteID.trainerExercise.fallbackTitle,
                subtitle: "Mode",
                rowIDs: [
                    .choice(.exerciseMode)
                ]
            ),
            ChildPageSpec(
                route: .trainerPositionFilter,
                title: SettingsRouteID.trainerPositionFilter.fallbackTitle,
                subtitle: "Note names or frets",
                rowIDs: [
                    .choice(.positionPromptFilterMode),
                    .positionFilter(.positionPromptFilterOptions)
                ]
            )
        ]
    case .piano:
        return [
            ChildPageSpec(
                route: .pianoBehavior,
                title: SettingsRouteID.pianoBehavior.fallbackTitle,
                subtitle: "Visibility and movement",
                rowIDs: [
                    .toggle(.pianoVisible),
                    .slider(.pianoRowCount),
                    .choice(.pianoMovementScope),
                    .toggle(.pianoSnapEnabled)
                ]
            )
        ]
    case .page, .fretboard, .layout, .debug:
        return nil
    // ... case .staff 等其他未改动分支省略
    }
}
```

- 自动验证仍然冻结在旧入口：fixture 名、手工清单、断言对象都还是 `Trainer / Page / Layout / Piano Visible`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:)
// 功能说明: 修改前导航 validation 仍锁定旧分区、旧 route 和旧手工回归项。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "trainer_route_visibility_tracks_exercise_mode",
            validate: validateTrainerRouteVisibilityTracksExerciseMode
        ),
        SettingsNavigationValidationFixture(
            name: "layout_route_visibility_tracks_display_mode",
            validate: validateLayoutRouteVisibilityTracksDisplayMode
        ),
        SettingsNavigationValidationFixture(
            name: "legacy_page_rows_and_piano_visibility_state_remain_stable",
            validate: validateLegacyPageRowsAndPianoVisibilityStateRemainStable
        )
    ]
}

static func manualChecklist(
    for platform: SettingsNavigationValidationPlatform
) -> [String] {
    [
        "确认 root -> Trainer / Staff / Piano 的 section page 可以继续进入深层子页，标题与内容和共享 builder 生成的 route 一致。",
        "确认当停留在 Trainer Position Filter 深层页时切换 exercise mode，卡片会自动退回最近仍有效的 Trainer 父页，而不会停留在失效子页。",
        "确认切换到 horizontal 指板布局时 Layout route 会消失；切回 vertical 后 Layout route 会恢复。",
        "确认阶段 0 期间 `Page` 分区仍保留 `Top Content / Main Content` 两行，`Piano > Behavior` 仍保留 `Visible` 开关。后续阶段替换前，这些旧入口不应先漂移。"
    ]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateLegacyBaseline(...), validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible()
// 功能说明: 修改前 composition validation 仍从 Trainer / Piano Visible 等旧入口回看 settings snapshot。
let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
guard let trainerSection = panelModel.sections.first(where: {
    $0.id == .trainer
}) else {
    issues.append(
        issue(
            fixtureName,
            "settings snapshot 应继续保留 Trainer section。"
        )
    )
    return issues
}

let expectedTrainerRowIDs: [SettingsRowID] = [
    .choice(.exerciseMode),
    .choice(.positionPromptFilterMode),
    .positionFilter(.positionPromptFilterOptions)
]

guard let pianoVisibleToggle = defaultPanelModel.toggleRow(
    for: .pianoVisible
) else {
    issues.append(
        issue(
            fixtureName,
            "default settings snapshot 应继续暴露 Piano Visible 开关。"
        )
    )
    return issues
}

SettingsToggleID.pianoVisible.apply(value: true, to: &visibleStateContext)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateDefaultConfigurationAndProjection(), manualChecklist(for:)
// 功能说明: 修改前 startup projection 仍从 Trainer section 验证默认回显，手工清单也仍引用旧的 pianoVisible。
if let startupTrainerSection = startupSettingsModel.sections.first(where: {
    $0.id == .trainer
}) {
    let expectedStartupTrainerRowIDs: [SettingsRowID] = [
        .choice(.exerciseMode),
        .choice(.positionPromptFilterMode),
        .positionFilter(.positionPromptFilterOptions)
    ]
    // ... 其他旧断言省略
}

"在 `single` 与 `sequence` 模式下确认页面继续保持上方 `staff`、下方 `fretboard`；切回 `positionPrompt` 后确认恢复为上方 `fretboard`、下方 `natural note strip`，且不受 `pianoVisible` 与 viewport 调整影响。"
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: manualChecklist(for:), validatePianoPanelVisibilityDefaults()
// 功能说明: 修改前 Piano validation 仍围绕 `Piano Visible` 开关验证默认显隐。
"确认 `Piano Visible` 默认关闭；打开后才出现钢琴区域，关闭后会恢复主内容底边约束而不是改变 prompt/answer 主组合。"

if SettingsToggleID.pianoVisible.resolvedValue(in: settingsStateContext) {
    issues.append(issue(fixtureName, "settings snapshot 的 Piano Visible 默认不应回显为开启。"))
}

SettingsToggleID.pianoVisible.apply(value: true, to: &settingsStateContext)
if !SettingsToggleID.pianoVisible.resolvedValue(in: settingsStateContext) {
    issues.append(issue(fixtureName, "Piano Visible toggle 写回后应继续在 settings snapshot 中回显为开启。"))
}
```

## 修改后

### 1. 新增 legacy layout bridge，把新预设先投影回旧页面模型

- 新增 `LegacyPageLayoutAdapter`
- 负责三件事：从 legacy state 反推 `ExerciseLayoutPreferences`、按当前 `exerciseMode` 做归一化、再把新偏好投影回旧 `PageDisplayState`
- 在阶段 2 里也集中声明了哪些新预设当前只是“可见但不可用”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/LegacyPageLayoutAdapter.swift
// 函数名: inferredPreferences(...), normalizedPreferences(...), projectedPageDisplayState(...), reconcile(...)
// 功能说明: 新增 settings migration bridge，负责新旧布局模型并存阶段的推导、约束和回投影。
enum LegacyPageLayoutAdapter {
    static func inferredPreferences(
        pageDisplayState: PageDisplayState,
        trainerDisplayState: TrainerDisplayState,
        pianoPanelState: PianoPanelState
    ) -> ExerciseLayoutPreferences {
        let inferredCompositionPreset: ExerciseCompositionPreset

        switch trainerDisplayState.exerciseMode {
        case .positionPrompt:
            inferredCompositionPreset = .fretboardToNaturalNoteStrip
        case .single, .sequence:
            switch pageDisplayState.topContentMode {
            case .targetPrompt:
                inferredCompositionPreset = .targetPromptToFretboard
            case .staff, .fretboard:
                inferredCompositionPreset = .staffToFretboard
            }
        }

        return normalizedPreferences(
            ExerciseLayoutPreferences(
                compositionPreset: inferredCompositionPreset,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: pageDisplayState.mainContentMode
                    == .naturalNoteStrip,
                isPianoAccessoryVisible: pianoPanelState.isVisible,
                isAccessoryExpanded: true
            ),
            trainerDisplayState: trainerDisplayState
        )
    }

    static func normalizedPreferences(
        _ preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> ExerciseLayoutPreferences {
        var normalized = preferences

        switch trainerDisplayState.exerciseMode {
        case .single, .sequence:
            if !isCompositionPresetSupported(
                normalized.compositionPreset,
                for: trainerDisplayState.exerciseMode
            ) {
                normalized.compositionPreset = .staffToFretboard
            }
            normalized.isNaturalNoteStripVisible = false
        case .positionPrompt:
            normalized.compositionPreset = .fretboardToNaturalNoteStrip
            normalized.isNaturalNoteStripVisible = true
        }

        if !isLayoutPresetSupported(normalized.layoutPreset) {
            normalized.layoutPreset = .stacked
        }
        if !isAccessoryPresentationSupported(
            normalized.accessoryPresentation
        ) {
            normalized.accessoryPresentation = .docked
        }
        if !isAccessoryExpandedSupported(
            accessoryPresentation: normalized.accessoryPresentation
        ) {
            normalized.isAccessoryExpanded = true
        }

        return normalized
    }

    static func projectedPageDisplayState(
        from preferences: ExerciseLayoutPreferences,
        trainerDisplayState: TrainerDisplayState
    ) -> PageDisplayState {
        let normalizedPreferences = normalizedPreferences(
            preferences,
            trainerDisplayState: trainerDisplayState
        )

        switch trainerDisplayState.exerciseMode {
        case .positionPrompt:
            return .positionPrompt
        case .single, .sequence:
            switch normalizedPreferences.compositionPreset {
            case .targetPromptToFretboard:
                return PageDisplayState(
                    topContentMode: .targetPrompt,
                    mainContentMode: .fretboard
                )
            case .staffToFretboard,
                 .fretboardToNaturalNoteStrip,
                 .fretboardSelfAnswer:
                return .default
            }
        }
    }

    static func isLayoutPresetSupported(
        _ preset: ExerciseLayoutPreset
    ) -> Bool {
        preset == .stacked
    }

    static func isAccessoryPresentationSupported(
        _ presentation: ExerciseAccessoryPresentation
    ) -> Bool {
        presentation == .docked
    }

    static func isNaturalStripToggleSupported(
        in _: SettingsPanelStateContext
    ) -> Bool {
        false
    }

    static func isAccessoryExpandedSupported(
        accessoryPresentation _: ExerciseAccessoryPresentation
    ) -> Bool {
        false
    }

    static func reconcile(
        _ stateContext: inout SettingsPanelStateContext
    ) {
        stateContext.exerciseLayoutPreferences = normalizedPreferences(
            stateContext.exerciseLayoutPreferences,
            trainerDisplayState: stateContext.trainerDisplayState
        )
        stateContext.pageDisplayState = projectedPageDisplayState(
            from: stateContext.exerciseLayoutPreferences,
            trainerDisplayState: stateContext.trainerDisplayState
        )
        stateContext.pianoPanelState.isVisible = stateContext
            .exerciseLayoutPreferences
            .isPianoAccessoryVisible
    }
}
```

### 2. `SettingsPanelStateContext` 默认值改为从 legacy 状态反推新偏好

- `default` 直接对齐 `positionPrompt` 旧基线
- 初始化时如果调用方没显式传入 `exerciseLayoutPreferences`，就通过 bridge 自动推导

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: init(...), static let `default`
// 功能说明: 修改后 settings shared context 默认先沿用旧状态，再自动推导出新的 exerciseLayoutPreferences。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState

    static let `default` = SettingsPanelStateContext(
        pageDisplayState: .positionPrompt,
        trainerDisplayState: .default,
        pianoPanelState: .init()
    )

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState = .default,
        exerciseLayoutPreferences: ExerciseLayoutPreferences? = nil,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init()
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.pageDisplayState = pageDisplayState
        self.trainerDisplayState = trainerDisplayState
        self.pianoPanelState = pianoPanelState
        self.exerciseLayoutPreferences = exerciseLayoutPreferences
            ?? LegacyPageLayoutAdapter.inferredPreferences(
                pageDisplayState: pageDisplayState,
                trainerDisplayState: trainerDisplayState,
                pianoPanelState: pianoPanelState
            )
    }
}
```

### 3. settings 主模型迁到 Exercise / Position Prompt / Accessories

- `SettingsSectionID.allCases` 现在只把新分区暴露给 UI
- `Composition Preset / Layout Preset / Accessory Presentation` 成为新的显式 row
- `verticalHostHeightRatio` 从旧 `Layout` 分区迁进 `Fretboard`
- `pianoVisible` 被迁移为 `pianoAccessoryVisible`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.rowIDs, SettingsChoiceRowID.sectionID, title, actionIDs
// 功能说明: 修改后 settings UI 入口改为预设模型，旧的 Page / Layout / Piano Visible 不再进入可见分区树。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case exercise
    case positionPrompt
    case accessories
    case page
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    static var allCases: [SettingsSectionID] {
        [
            .exercise,
            .positionPrompt,
            .accessories,
            .fretboard,
            .staff,
            .piano,
            .debug
        ]
    }

    var rowIDs: [SettingsRowID] {
        switch self {
        case .exercise:
            return [
                .choice(.exerciseMode),
                .choice(.compositionPreset),
                .choice(.layoutPreset)
            ]
        case .positionPrompt:
            return [
                .choice(.positionPromptFilterMode),
                .positionFilter(.positionPromptFilterOptions)
            ]
        case .accessories:
            return [
                .toggle(.naturalStripVisible),
                .toggle(.pianoAccessoryVisible),
                .choice(.accessoryPresentation),
                .toggle(.accessoryExpanded)
            ]
        case .fretboard:
            return [
                .choice(.instrument),
                .choice(.displayMode),
                .slider(.verticalHostHeightRatio),
                .choice(.stringThickness),
                .choice(.labels),
                .choice(.spelling),
                .choice(.octave)
            ]
        case .piano:
            return [
                .slider(.pianoRowCount),
                .choice(.pianoMovementScope),
                .choice(.pianoWhiteKeyStyle),
                .toggle(.pianoSnapEnabled)
            ]
        // ... 旧分区仍保留 enum case 以兼容编译，但不再出现在 allCases 中
        // ... case .staff / .debug 等其他分支省略
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case exerciseMode
    case compositionPreset
    case layoutPreset
    case positionPromptFilterMode
    case accessoryPresentation
    case instrument
    case displayMode
    // ... 其他未改动 case 省略

    var sectionID: SettingsSectionID {
        switch self {
        case .topContent, .mainContent:
            return .page
        case .exerciseMode, .compositionPreset, .layoutPreset:
            return .exercise
        case .positionPromptFilterMode:
            return .positionPrompt
        case .accessoryPresentation:
            return .accessories
        // ... case .instrument / .displayMode / .clef / .pianoMovementScope 等其他映射省略
        }
    }

    var actionIDs: [SettingsActionID] {
        switch self {
        case .exerciseMode:
            return [
                .setExerciseModeSingle,
                .setExerciseModeSequence,
                .setExerciseModePositionPrompt
            ]
        case .compositionPreset:
            return [
                .setCompositionPresetStaffToFretboard,
                .setCompositionPresetTargetPromptToFretboard,
                .setCompositionPresetFretboardToNaturalNoteStrip,
                .setCompositionPresetFretboardSelfAnswer
            ]
        case .layoutPreset:
            return [
                .setLayoutPresetStacked,
                .setLayoutPresetSideBySide,
                .setLayoutPresetSingleSurface
            ]
        case .accessoryPresentation:
            return [
                .setAccessoryPresentationDocked,
                .setAccessoryPresentationFloating,
                .setAccessoryPresentationCollapsible
            ]
        // ... case .instrument / .displayMode / .labels / .spelling / .clef 等其他 action 映射省略
        }
    }
}
```

### 4. action / toggle 写回逻辑改成“先写预设，再 reconcile”

- 新 action 先改写 `ExerciseLayoutPreferences`
- 新 action 的可用性由 `LegacyPageLayoutAdapter` 统一控制，避免把未实现布局误显示为可用
- legacy `Top Content / Main Content` action 仍能工作，但写回后会重新反推新偏好，避免两套状态漂移
- accessories toggle 也不再直接改 page slot，而是改新偏好再 reconcile

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsActionID.isEnabled(in:), apply(to exerciseLayoutPreferences:), apply(to stateContext:)
// 功能说明: 修改后 action 既能控制新预设，也会在需要时通过 bridge 回写 legacy page state。
func isEnabled(
    in stateContext: SettingsPanelStateContext
) -> Bool {
    switch self {
    case .setCompositionPresetStaffToFretboard:
        return LegacyPageLayoutAdapter.isCompositionPresetSupported(
            .staffToFretboard,
            for: stateContext.trainerDisplayState.exerciseMode
        )
    case .setCompositionPresetTargetPromptToFretboard:
        return LegacyPageLayoutAdapter.isCompositionPresetSupported(
            .targetPromptToFretboard,
            for: stateContext.trainerDisplayState.exerciseMode
        )
    case .setCompositionPresetFretboardToNaturalNoteStrip:
        return LegacyPageLayoutAdapter.isCompositionPresetSupported(
            .fretboardToNaturalNoteStrip,
            for: stateContext.trainerDisplayState.exerciseMode
        )
    case .setCompositionPresetFretboardSelfAnswer:
        return LegacyPageLayoutAdapter.isCompositionPresetSupported(
            .fretboardSelfAnswer,
            for: stateContext.trainerDisplayState.exerciseMode
        )
    case .setLayoutPresetStacked:
        return LegacyPageLayoutAdapter.isLayoutPresetSupported(.stacked)
    case .setLayoutPresetSideBySide:
        return LegacyPageLayoutAdapter.isLayoutPresetSupported(.sideBySide)
    case .setLayoutPresetSingleSurface:
        return LegacyPageLayoutAdapter.isLayoutPresetSupported(
            .singleSurface
        )
    case .setAccessoryPresentationDocked:
        return LegacyPageLayoutAdapter.isAccessoryPresentationSupported(
            .docked
        )
    case .setAccessoryPresentationFloating:
        return LegacyPageLayoutAdapter.isAccessoryPresentationSupported(
            .floating
        )
    case .setAccessoryPresentationCollapsible:
        return LegacyPageLayoutAdapter.isAccessoryPresentationSupported(
            .collapsible
        )
    // ... 其余旧 action 仍沿用既有可用性逻辑
    }
}

func apply(
    to exerciseLayoutPreferences: inout ExerciseLayoutPreferences
) {
    switch self {
    case .setCompositionPresetStaffToFretboard:
        exerciseLayoutPreferences.compositionPreset = .staffToFretboard
    case .setCompositionPresetTargetPromptToFretboard:
        exerciseLayoutPreferences.compositionPreset = .targetPromptToFretboard
    case .setCompositionPresetFretboardToNaturalNoteStrip:
        exerciseLayoutPreferences.compositionPreset = .fretboardToNaturalNoteStrip
    case .setCompositionPresetFretboardSelfAnswer:
        exerciseLayoutPreferences.compositionPreset = .fretboardSelfAnswer
    case .setLayoutPresetStacked:
        exerciseLayoutPreferences.layoutPreset = .stacked
    case .setLayoutPresetSideBySide:
        exerciseLayoutPreferences.layoutPreset = .sideBySide
    case .setLayoutPresetSingleSurface:
        exerciseLayoutPreferences.layoutPreset = .singleSurface
    case .setAccessoryPresentationDocked:
        exerciseLayoutPreferences.accessoryPresentation = .docked
    case .setAccessoryPresentationFloating:
        exerciseLayoutPreferences.accessoryPresentation = .floating
    case .setAccessoryPresentationCollapsible:
        exerciseLayoutPreferences.accessoryPresentation = .collapsible
    // ... 其余非布局预设 action 不会改写 exerciseLayoutPreferences
    }
}

func apply(to stateContext: inout SettingsPanelStateContext) {
    apply(to: &stateContext.fretboardDisplayState)
    apply(to: &stateContext.staffDisplayState)
    apply(to: &stateContext.pageDisplayState)
    apply(to: &stateContext.exerciseLayoutPreferences)
    apply(to: &stateContext.trainerDisplayState)
    apply(to: &stateContext.pianoPanelState)
    if usesLegacyPagePlacementAction {
        stateContext.exerciseLayoutPreferences = LegacyPageLayoutAdapter
            .inferredPreferences(
                pageDisplayState: stateContext.pageDisplayState,
                trainerDisplayState: stateContext.trainerDisplayState,
                pianoPanelState: stateContext.pianoPanelState
            )
    }
    LegacyPageLayoutAdapter.reconcile(&stateContext)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsToggleID.sectionID, resolvedValue(in:), isEnabled(in:), apply(value:to:)
// 功能说明: 修改后 accessories toggle 不再直接等同于旧 page slot，而是回读 / 写入新的布局偏好。
enum SettingsToggleID: CaseIterable, Equatable, Hashable, Sendable {
    case showsComponentBounds
    case naturalStripVisible
    case pianoAccessoryVisible
    case accessoryExpanded
    case pianoSnapEnabled

    var sectionID: SettingsSectionID {
        switch self {
        case .showsComponentBounds:
            return .debug
        case .naturalStripVisible,
             .pianoAccessoryVisible,
             .accessoryExpanded:
            return .accessories
        case .pianoSnapEnabled:
            return .piano
        }
    }

    func resolvedValue(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .showsComponentBounds:
            return stateContext.fretboardDisplayState.showsComponentBoundsOverlay
                || stateContext.staffDisplayState.showsComponentBoundsOverlay
        case .naturalStripVisible:
            return stateContext.exerciseLayoutPreferences.isNaturalNoteStripVisible
        case .pianoAccessoryVisible:
            return stateContext.exerciseLayoutPreferences.isPianoAccessoryVisible
        case .accessoryExpanded:
            return stateContext.exerciseLayoutPreferences.isAccessoryExpanded
        case .pianoSnapEnabled:
            return stateContext.pianoPanelState.snapEnabled
        }
    }

    func isEnabled(
        in stateContext: SettingsPanelStateContext
    ) -> Bool {
        switch self {
        case .showsComponentBounds, .pianoAccessoryVisible, .pianoSnapEnabled:
            return true
        case .naturalStripVisible:
            return LegacyPageLayoutAdapter.isNaturalStripToggleSupported(
                in: stateContext
            )
        case .accessoryExpanded:
            return LegacyPageLayoutAdapter.isAccessoryExpandedSupported(
                accessoryPresentation: stateContext.exerciseLayoutPreferences
                    .accessoryPresentation
            )
        }
    }

    func apply(
        value: Bool,
        to stateContext: inout SettingsPanelStateContext
    ) {
        switch self {
        case .showsComponentBounds:
            apply(value: value, to: &stateContext.fretboardDisplayState)
            apply(value: value, to: &stateContext.staffDisplayState)
        case .naturalStripVisible:
            stateContext.exerciseLayoutPreferences.isNaturalNoteStripVisible = value
            LegacyPageLayoutAdapter.reconcile(&stateContext)
        case .pianoAccessoryVisible:
            stateContext.exerciseLayoutPreferences.isPianoAccessoryVisible = value
            LegacyPageLayoutAdapter.reconcile(&stateContext)
        case .accessoryExpanded:
            stateContext.exerciseLayoutPreferences.isAccessoryExpanded = value
            LegacyPageLayoutAdapter.reconcile(&stateContext)
        case .pianoSnapEnabled:
            stateContext.pianoPanelState.snapEnabled = value
        }
    }
}
```

### 5. snapshot builder 改为先 reconcile，再生成 section

- 所有 settings snapshot 都先走一次 bridge
- 这样 UI 层拿到的永远是“新预设 + 旧 page state”已经对齐后的状态

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: makeModel(from:)
// 功能说明: 修改后 snapshot builder 会在生成 section 前先统一归一化 stateContext。
enum SettingsPanelSnapshotBuilder {
    static func makeModel(
        from stateContext: SettingsPanelStateContext
    ) -> SettingsPanelModel {
        var normalizedStateContext = stateContext
        LegacyPageLayoutAdapter.reconcile(&normalizedStateContext)

        return SettingsPanelModel(
            sections: SettingsSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    stateContext: normalizedStateContext
                )
            }
        )
    }
}
```

### 6. 路由与子页树迁到新分区结构

- 新增 `exerciseMode / exerciseComposition / exerciseLayout / accessoryVisibility / accessoryPresentation / fretboardViewport` 等 route
- `Position Prompt` 变成独立 section
- `Piano > Behavior` 不再负责显隐，只保留 rows 和 movement

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: SettingsRouteID.fallbackTitle, accessibilityIdentifierComponent
// 功能说明: 修改后新增 route id，用来承载 Exercise / Accessories / Fretboard 的拆分子页。
enum SettingsRouteID: Equatable, Hashable, Sendable {
    case root
    case section(SettingsSectionID)
    case exerciseMode
    case exerciseComposition
    case exerciseLayout
    case positionPromptFilter
    case accessoryVisibility
    case accessoryPresentation
    case fretboardDisplay
    case fretboardViewport
    case trainerExercise
    case trainerPositionFilter
    case staffClef
    case staffLayout
    case pianoBehavior
    case pianoAppearance

    var fallbackTitle: String {
        switch self {
        case .root:
            return "Settings"
        case let .section(sectionID):
            return sectionID.title
        case .exerciseMode:
            return "Mode"
        case .exerciseComposition:
            return "Composition"
        case .exerciseLayout:
            return "Layout"
        case .positionPromptFilter:
            return "Filter"
        case .accessoryVisibility:
            return "Visibility"
        case .accessoryPresentation:
            return "Presentation"
        case .fretboardDisplay:
            return "Display"
        case .fretboardViewport:
            return "Vertical Viewport"
        // ... case .trainerExercise / .trainerPositionFilter / .staffClef / .staffLayout / .pianoBehavior / .pianoAppearance 省略
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: childPageSpecs(for:)
// 功能说明: 修改后新的 settings 分区会展开成新的子页树，旧的 page/layout 入口不再参与导航。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    case .exercise:
        return [
            ChildPageSpec(
                route: .exerciseMode,
                title: SettingsRouteID.exerciseMode.fallbackTitle,
                subtitle: "Single, sequence, or position",
                rowIDs: [
                    .choice(.exerciseMode)
                ]
            ),
            ChildPageSpec(
                route: .exerciseComposition,
                title: SettingsRouteID.exerciseComposition.fallbackTitle,
                subtitle: "Prompt and answer pairing",
                rowIDs: [
                    .choice(.compositionPreset)
                ]
            ),
            ChildPageSpec(
                route: .exerciseLayout,
                title: SettingsRouteID.exerciseLayout.fallbackTitle,
                subtitle: "Stacked for now",
                rowIDs: [
                    .choice(.layoutPreset)
                ]
            )
        ]
    case .positionPrompt:
        return [
            ChildPageSpec(
                route: .positionPromptFilter,
                title: SettingsRouteID.positionPromptFilter.fallbackTitle,
                subtitle: "Note names or frets",
                rowIDs: [
                    .choice(.positionPromptFilterMode),
                    .positionFilter(.positionPromptFilterOptions)
                ]
            )
        ]
    case .accessories:
        return [
            ChildPageSpec(
                route: .accessoryVisibility,
                title: SettingsRouteID.accessoryVisibility.fallbackTitle,
                subtitle: "Natural strip and piano",
                rowIDs: [
                    .toggle(.naturalStripVisible),
                    .toggle(.pianoAccessoryVisible)
                ]
            ),
            ChildPageSpec(
                route: .accessoryPresentation,
                title: SettingsRouteID.accessoryPresentation.fallbackTitle,
                subtitle: "Docked for now",
                rowIDs: [
                    .choice(.accessoryPresentation),
                    .toggle(.accessoryExpanded)
                ]
            )
        ]
    case .fretboard:
        return [
            ChildPageSpec(
                route: .fretboardDisplay,
                title: SettingsRouteID.fretboardDisplay.fallbackTitle,
                subtitle: "Instrument and labels",
                rowIDs: [
                    .choice(.instrument),
                    .choice(.displayMode),
                    .choice(.stringThickness),
                    .choice(.labels),
                    .choice(.spelling),
                    .choice(.octave)
                ]
            ),
            ChildPageSpec(
                route: .fretboardViewport,
                title: SettingsRouteID.fretboardViewport.fallbackTitle,
                subtitle: "Vertical sizing",
                rowIDs: [
                    .slider(.verticalHostHeightRatio)
                ]
            )
        ]
    case .piano:
        return [
            ChildPageSpec(
                route: .pianoBehavior,
                title: SettingsRouteID.pianoBehavior.fallbackTitle,
                subtitle: "Rows and movement",
                rowIDs: [
                    .slider(.pianoRowCount),
                    .choice(.pianoMovementScope),
                    .toggle(.pianoSnapEnabled)
                ]
            )
        ]
    case .page, .layout, .debug:
        return nil
    // ... case .trainer / .staff 等其他兼容分支省略
    }
}
```

### 7. validation 主体迁到新设置入口，并同步钢琴/位置题断言

- `SettingsNavigationValidation` 不再检查 `Trainer / Layout / Page`
- `ExerciseCompositionValidation` 改为验证新 `Exercise section` 与 legacy 基线映射
- `FretboardValidation` 改为验证 `Exercise + Position Prompt` 的 startup projection
- `PianoValidation` 改为验证 `Piano Accessory Visible`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures(), manualChecklist(for:), validatePhase2ExerciseAndAccessoryRowsRemainStable()
// 功能说明: 修改后导航 validation 的 fixture、手工清单和稳定性断言全部切到阶段 2 新入口。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "position_prompt_section_visibility_tracks_exercise_mode",
            validate: validatePositionPromptSectionVisibilityTracksExerciseMode
        ),
        SettingsNavigationValidationFixture(
            name: "fretboard_viewport_route_visibility_tracks_display_mode",
            validate: validateFretboardViewportRouteVisibilityTracksDisplayMode
        ),
        SettingsNavigationValidationFixture(
            name: "phase2_exercise_and_accessory_rows_remain_stable",
            validate: validatePhase2ExerciseAndAccessoryRowsRemainStable
        )
    ]
}

static func manualChecklist(
    for platform: SettingsNavigationValidationPlatform
) -> [String] {
    [
        "确认 root -> Exercise / Accessories / Staff / Piano 的 section page 可以继续进入深层子页，标题与内容和共享 builder 生成的 route 一致。",
        "确认切换到 `single` / `sequence` 时 `Position Prompt` section 会消失；切回 `positionPrompt` 后会恢复。",
        "确认切换到 horizontal 指板布局时 `Fretboard > Vertical Viewport` 深层页会消失；切回 vertical 后会恢复。",
        "确认 `Exercise` 分区只显示 `Exercise Mode / Composition Preset / Layout Preset`，不再出现 `Top Content / Main Content`。",
        "确认 `Accessories` 分区包含 `Natural Strip Visible / Piano Accessory Visible / Accessory Presentation / Accessory Expanded`，`Piano > Behavior` 不再负责可见性开关。"
    ]
}

static func validatePhase2ExerciseAndAccessoryRowsRemainStable()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "phase2_exercise_and_accessory_rows_remain_stable"
    let defaultStateContext = SettingsPanelStateContext.default
    let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(
        from: defaultStateContext
    )
    var issues: [SettingsNavigationValidationIssue] = []

    guard let exerciseSection = resolveSection(.exercise, in: defaultPanelModel) else {
        issues.append(
            issue(fixtureName, "default state 应保留 Exercise section。")
        )
        return issues
    }
    guard let accessoriesSection = resolveSection(.accessories, in: defaultPanelModel) else {
        issues.append(
            issue(fixtureName, "default state 应保留 Accessories section。")
        )
        return issues
    }

    if resolveSection(.page, in: defaultPanelModel) != nil {
        issues.append(issue(fixtureName, "default state 不应再暴露 Page section。"))
    }
    if exerciseSection.rows.map(\.id) != [
        .choice(.exerciseMode),
        .choice(.compositionPreset),
        .choice(.layoutPreset)
    ] {
        issues.append(
            issue(
                fixtureName,
                "Exercise section row 顺序应保持 Exercise Mode -> Composition Preset -> Layout Preset。"
            )
        )
    }
    if accessoriesSection.rows.map(\.id) != [
        .toggle(.naturalStripVisible),
        .toggle(.pianoAccessoryVisible),
        .choice(.accessoryPresentation),
        .toggle(.accessoryExpanded)
    ] {
        issues.append(
            issue(
                fixtureName,
                "Accessories section rows 应保持 Natural Strip / Piano Accessory / Presentation / Expanded。"
            )
        )
    }
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateLegacyBaseline(...), validateSharedLayoutPreferencesCoexistWithLegacyPageState()
// 功能说明: 修改后 composition validation 直接校验新 Exercise section 的默认回显，以及它与旧 page baseline 的映射关系。
let stateContext = SettingsPanelStateContext(
    pageDisplayState: expectedPageDisplayState,
    trainerDisplayState: TrainerDisplayState(exerciseMode: exerciseMode)
)
let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
guard let exerciseSection = panelModel.sections.first(where: {
    $0.id == .exercise
}) else {
    issues.append(
        issue(
            fixtureName,
            "settings snapshot 应保留 Exercise section。"
        )
    )
    return issues
}

if exerciseSection.rows.map(\.id) != [
    .choice(.exerciseMode),
    .choice(.compositionPreset),
    .choice(.layoutPreset)
] {
    issues.append(
        issue(
            fixtureName,
            "阶段 2 的 Exercise section 应稳定暴露 Exercise Mode / Composition Preset / Layout Preset。"
        )
    )
}

if panelModel.choiceRow(for: .compositionPreset)?.choices.filter(\.isSelected)
    .map(\.id) != [.setCompositionPresetStaffToFretboard] {
    issues.append(
        issue(
            fixtureName,
            "single / sequence 的 legacy baseline 应把 Composition Preset 映射为 Staff -> Fretboard。"
        )
    )
}

if defaultStateContext.exerciseLayoutPreferences != .legacyPositionPrompt {
    issues.append(
        issue(
            fixtureName,
            "SettingsPanelStateContext.default 应对齐 positionPrompt 的 legacy ExerciseLayoutPreferences。"
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validateDefaultConfigurationAndProjection(), manualChecklist(for:)
// 功能说明: 修改后 startup projection 改为验证 Exercise / Position Prompt 两个新分区的默认回显。
let startupSettingsModel = SettingsPanelSnapshotBuilder.makeModel(
    from: SettingsPanelStateContext(
        pageDisplayState: .positionPrompt,
        trainerDisplayState: .default
    )
)
if let startupExerciseSection = startupSettingsModel.sections.first(where: {
    $0.id == .exercise
}) {
    let expectedStartupExerciseRowIDs: [SettingsRowID] = [
        .choice(.exerciseMode),
        .choice(.compositionPreset),
        .choice(.layoutPreset)
    ]
    if startupExerciseSection.rows.map(\.id) != expectedStartupExerciseRowIDs {
        record("startup settings model 的 Exercise row 顺序未对齐 Exercise Mode / Composition Preset / Layout Preset。")
    }
}

if let startupPositionPromptSection = startupSettingsModel.sections.first(where: {
    $0.id == .positionPrompt
}) {
    let expectedStartupPositionPromptRowIDs: [SettingsRowID] = [
        .choice(.positionPromptFilterMode),
        .positionFilter(.positionPromptFilterOptions)
    ]
    if startupPositionPromptSection.rows.map(\.id)
        != expectedStartupPositionPromptRowIDs {
        record("startup settings model 的 Position Prompt row 顺序未对齐 Filter / Position Filter。")
    }
}

"在 `single` 与 `sequence` 模式下确认页面继续保持上方 `staff`、下方 `fretboard`；切回 `positionPrompt` 后确认恢复为上方 `fretboard`、下方 `natural note strip`，且不受 `pianoAccessoryVisible` 与 viewport 调整影响。"
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: manualChecklist(for:), validatePianoPanelVisibilityDefaults()
// 功能说明: 修改后 Piano validation 改为使用 Accessories 分区中的 `Piano Accessory Visible` 开关。
"确认 `Piano Accessory Visible` 默认关闭；打开后才出现钢琴区域，关闭后会恢复主内容底边约束而不是改变 prompt/answer 主组合。"

if SettingsToggleID.pianoAccessoryVisible.resolvedValue(in: settingsStateContext) {
    issues.append(issue(fixtureName, "settings snapshot 的 Piano Accessory Visible 默认不应回显为开启。"))
}

SettingsToggleID.pianoAccessoryVisible.apply(
    value: true,
    to: &settingsStateContext
)
if !settingsStateContext.pianoPanelState.isVisible {
    issues.append(issue(fixtureName, "Piano Accessory Visible toggle 写回后应把 pianoPanelState.isVisible 置为 true。"))
}
if !SettingsToggleID.pianoAccessoryVisible.resolvedValue(in: settingsStateContext) {
    issues.append(issue(fixtureName, "Piano Accessory Visible toggle 写回后应继续在 settings snapshot 中回显为开启。"))
}
```

## 验证结果

- `ReadLints`：通过
- `macOS` Debug build：通过
- `iOS Simulator` Debug build：通过
- 备注：首次尝试使用 `iPhone 16` 作为 destination 失败，原因是本机没有该 simulator；改用本机已有的 `iPhone 17, OS 26.1` 后通过，这不是代码问题

```sh
# 文件路径: N/A（命令行验证）
# 函数名: N/A
# 功能说明: 本次记录对应的时间戳获取与关键验证命令。
date +"%Y%m%d_%H%M%S"
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build
```

```text
# 文件路径: N/A（验证结果摘要）
# 函数名: N/A
# 功能说明: 本次阶段 2 修改对应的关键检查结果摘要。
时间戳: 20260401_193410
ReadLints: No linter errors found.
macOS build: succeeded
iOS Simulator build: succeeded
备注: iPhone 16 destination 不存在；切换到现有 iPhone 17, OS 26.1 后构建通过。
```

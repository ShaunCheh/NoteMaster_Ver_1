# 20260407_165136_phase3_root_mode_state_settings_split_and_navigation_validation

## 记录范围

本记录只覆盖刚刚这一轮 `phase3` 的实际修改，不包含工作区里其它更早阶段留下的未提交改动。

涉及文件：

- `NoteMaster_Ver_1/Shared/App/RootModeState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

---

## 1. 新增根模式状态容器

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/App/RootModeState.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；项目里只有 RootMode 枚举，没有一个明确承载 exercise / play 双态的根级状态容器。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/App/RootModeState.swift
// 函数名: ExerciseModeState / PlayModeState / RootModeState
// 功能说明: 修改后新增根级状态容器，把 exercise 专属状态和 play 专属状态并列收口到 RootModeState，避免继续把 play 语义塞进 TrainerDisplayState。
struct ExerciseModeState: Equatable, Sendable {
    var trainerDisplayState: TrainerDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences

    static let `default` = ExerciseModeState(
        trainerDisplayState: .default,
        exerciseLayoutPreferences: .legacyPositionPrompt
    )
}

struct PlayModeState: Equatable, Sendable {
    var isPianoInteractive: Bool

    static let `default` = PlayModeState()

    init(
        isPianoInteractive: Bool = true
    ) {
        self.isPianoInteractive = isPianoInteractive
    }

    var compositionInput: PlayCompositionPolicyInput {
        PlayCompositionPolicyInput(
            isPianoInteractive: isPianoInteractive
        )
    }
}

struct RootModeState: Equatable, Sendable {
    var rootMode: RootMode
    var exercise: ExerciseModeState
    var play: PlayModeState
}
```

---

## 2. `SettingsPanelStateContext` 从单体上下文拆成三段 slice

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: SettingsPanelStateContext.init(...)
// 功能说明: 修改前 settings context 是一个扁平大结构，exercise / play / 公共项全部混在一起；初始化时也总是直接走 LegacyPageLayoutAdapter.reconcile。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var exerciseLayoutPreferences: ExerciseLayoutPreferences
    var trainerDisplayState: TrainerDisplayState
    var pianoPanelState: PianoPanelState
    var debugState: SettingsDebugState

    init(
        fretboardDisplayState: FretboardDisplayState = .default,
        staffDisplayState: StaffDisplayState = .default,
        pageDisplayState: PageDisplayState? = nil,
        exerciseLayoutPreferences: ExerciseLayoutPreferences? = nil,
        trainerDisplayState: TrainerDisplayState = .default,
        pianoPanelState: PianoPanelState = .init(),
        debugState: SettingsDebugState = .init()
    ) {
        self.fretboardDisplayState = fretboardDisplayState
        self.staffDisplayState = staffDisplayState
        self.trainerDisplayState = trainerDisplayState
        self.pianoPanelState = pianoPanelState
        self.debugState = debugState
        self.exerciseLayoutPreferences = Self.resolvedLayoutPreferences(
            pageDisplayState: pageDisplayState,
            exerciseLayoutPreferences: exerciseLayoutPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: pianoPanelState
        )
        self.pageDisplayState = pageDisplayState
            ?? LegacyPageLayoutAdapter.projectedPageDisplayState(
                from: self.exerciseLayoutPreferences,
                trainerDisplayState: trainerDisplayState
            )
        LegacyPageLayoutAdapter.reconcile(&self)
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名: SettingsPanelCommonState / SettingsPanelExerciseState / SettingsPanelPlayState / reconcileForCurrentMode()
// 功能说明: 修改后把 settings context 拆成 common / exercise / play 三层；exercise 继续保留旧 reconcile 语义，play 只做后台保留态的 normalize，不再误触发 exercise-only 规则。
struct SettingsPanelCommonState: Equatable, Sendable {
    var rootMode: RootMode
    var pianoPanelState: PianoPanelState
}

struct SettingsPanelExerciseState: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState
    var modeState: ExerciseModeState
    var debugState: SettingsDebugState
}

struct SettingsPanelPlayState: Equatable, Sendable {
    var modeState: PlayModeState
}

struct SettingsPanelStateContext: Equatable, Sendable {
    var common: SettingsPanelCommonState
    var exercise: SettingsPanelExerciseState
    var play: SettingsPanelPlayState

    static let playDefault = SettingsPanelStateContext(
        rootMode: .play,
        exerciseLayoutPreferences: .legacyPositionPrompt,
        trainerDisplayState: .default,
        pianoPanelState: .init()
    )

    var rootModeState: RootModeState {
        get {
            RootModeState(
                rootMode: common.rootMode,
                exercise: exercise.modeState,
                play: play.modeState
            )
        }
        set {
            common.rootMode = newValue.rootMode
            exercise.modeState = newValue.exercise
            play.modeState = newValue.play
        }
    }

    mutating func reconcileForCurrentMode() {
        switch rootMode {
        case .exercise:
            LegacyPageLayoutAdapter.reconcile(&self)
        case .play:
            normalizeExerciseStateForBackgroundRetention()
        }
    }
}
```

---

## 3. `SettingsPanelModel` 改成 mode-aware，并把写回入口改成 mode-aware reconcile

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.allCases / SettingsActionID.apply(to:) / SettingsToggleID.apply(value:to:)
// 功能说明: 修改前 section 顺序只有 exercise 这一路，所有 settings 写回后都直接走 LegacyPageLayoutAdapter.reconcile。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case exercise
    case positionPrompt
    case accessories
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    static var allCases: [SettingsSectionID] {
        [
            .exercise,
            .accessories,
            .fretboard,
            .staff,
            .piano,
            .debug
        ]
    }
}

func apply(to stateContext: inout SettingsPanelStateContext) {
    apply(to: &stateContext.fretboardDisplayState)
    apply(to: &stateContext.staffDisplayState)
    apply(to: &stateContext.exerciseLayoutPreferences)
    apply(to: &stateContext.trainerDisplayState)
    apply(to: &stateContext.pianoPanelState)
    LegacyPageLayoutAdapter.reconcile(&stateContext)
}

case .naturalStripVisible:
    stateContext.exerciseLayoutPreferences.isNaturalNoteStripVisible = value
    LegacyPageLayoutAdapter.reconcile(&stateContext)
case .pianoAccessoryVisible:
    stateContext.exerciseLayoutPreferences.isPianoAccessoryVisible = value
    LegacyPageLayoutAdapter.reconcile(&stateContext)
case .accessoryExpanded:
    stateContext.exerciseLayoutPreferences.isAccessoryExpanded = value
    LegacyPageLayoutAdapter.reconcile(&stateContext)
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.orderedVisibleSections(for:) / SettingsActionID.apply(to:) / SettingsToggleID.apply(value:to:)
// 功能说明: 修改后 section 可见性由 rootMode 决定；写回后统一走 stateContext.reconcileForCurrentMode()，保证 exercise / play 两条路径各自回到正确的 normalize 逻辑。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case exercise
    case positionPrompt
    case accessories
    case trainer
    case fretboard
    case staff
    case layout
    case piano
    case debug

    static var allCases: [SettingsSectionID] {
        [
            .exercise,
            .accessories,
            .fretboard,
            .staff,
            .piano,
            .debug
        ]
    }

    static func orderedVisibleSections(
        for rootMode: RootMode
    ) -> [SettingsSectionID] {
        switch rootMode {
        case .exercise:
            return allCases
        case .play:
            return [
                .piano
            ]
        }
    }
}

func apply(to stateContext: inout SettingsPanelStateContext) {
    apply(to: &stateContext.fretboardDisplayState)
    apply(to: &stateContext.staffDisplayState)
    apply(to: &stateContext.exerciseLayoutPreferences)
    apply(to: &stateContext.trainerDisplayState)
    apply(to: &stateContext.pianoPanelState)
    stateContext.reconcileForCurrentMode()
}

case .naturalStripVisible:
    stateContext.exerciseLayoutPreferences.isNaturalNoteStripVisible = value
    stateContext.reconcileForCurrentMode()
case .pianoAccessoryVisible:
    stateContext.exerciseLayoutPreferences.isPianoAccessoryVisible = value
    stateContext.reconcileForCurrentMode()
case .accessoryExpanded:
    stateContext.exerciseLayoutPreferences.isAccessoryExpanded = value
    stateContext.reconcileForCurrentMode()
```

---

## 4. `SettingsPanelSnapshotBuilder` 只构建当前根模式可见的 section

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: makeModel(from:)
// 功能说明: 修改前 snapshot builder 一上来就按 exercise 规则 reconcile，然后无差别遍历 SettingsSectionID.allCases。
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

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: makeModel(from:)
// 功能说明: 修改后 snapshot builder 先按当前 rootMode 做 normalize，再根据 orderedVisibleSections(for:) 只投影当前模式真正应该出现的 section。
enum SettingsPanelSnapshotBuilder {
    static func makeModel(
        from stateContext: SettingsPanelStateContext
    ) -> SettingsPanelModel {
        var normalizedStateContext = stateContext
        normalizedStateContext.reconcileForCurrentMode()

        return SettingsPanelModel(
            sections: SettingsSectionID.orderedVisibleSections(
                for: normalizedStateContext.rootMode
            ).compactMap {
                makeSection(
                    id: $0,
                    stateContext: normalizedStateContext
                )
            }
        )
    }
}
```

---

## 5. `SettingsNavigationValidation` 新增 play 树与 root mode 切换回归

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改前 validation 只覆盖 exercise 路径，没有 play root tree，也没有 exercise -> play -> exercise 的状态保留校验。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "root_route_items_match_panel_sections",
            validate: validateRootRouteItemsMatchPanelSections
        ),
        SettingsNavigationValidationFixture(
            name: "split_sections_produce_expected_page_tree",
            validate: validateSplitSectionsProduceExpectedPageTree
        ),
        SettingsNavigationValidationFixture(
            name: "position_prompt_section_visibility_tracks_exercise_mode",
            validate: validatePositionPromptSectionVisibilityTracksExerciseMode
        )
    ]
}

static func manualChecklist(
    for platform: SettingsNavigationValidationPlatform
) -> [String] {
    [
        "在 \\(platform.displayName) 上确认 close 永远关闭整个 settings card，而不是只关闭当前子页。",
        "确认在 root 页隐藏返回按钮；进入 section 或更深页面后显示返回按钮，点击后只回退卡片内一层。",
        "确认 iOS / macOS 上的标题、返回、关闭按钮布局与转场方向一致，没有双层导航条或页面闪跳。"
    ]
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后 validation fixture 列表和手工回归清单都显式纳入 play 路径，以及根模式切换后的状态保留要求。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "root_route_items_match_panel_sections",
            validate: validateRootRouteItemsMatchPanelSections
        ),
        SettingsNavigationValidationFixture(
            name: "split_sections_produce_expected_page_tree",
            validate: validateSplitSectionsProduceExpectedPageTree
        ),
        SettingsNavigationValidationFixture(
            name: "play_root_tree_keeps_only_piano_pages",
            validate: validatePlayRootTreeKeepsOnlyPianoPages
        ),
        SettingsNavigationValidationFixture(
            name: "root_mode_switch_preserves_exercise_tree_and_state",
            validate: validateRootModeSwitchPreservesExerciseTreeAndState
        ),
        SettingsNavigationValidationFixture(
            name: "position_prompt_section_visibility_tracks_exercise_mode",
            validate: validatePositionPromptSectionVisibilityTracksExerciseMode
        )
    ]
}

static func manualChecklist(
    for platform: SettingsNavigationValidationPlatform
) -> [String] {
    [
        "确认切到 `play` mode 的 settings 后，root 只保留 `Piano` 分区，不再暴露 `Exercise / Accessories / Fretboard / Staff / Debug`。",
        "确认从 `exercise` 切到 `play` 再切回后，原来的 exercise mode、layout preset 和 piano rows / snap 之类的设置不会丢失。",
        "确认 iOS / macOS 上的标题、返回、关闭按钮布局与转场方向一致，没有双层导航条或页面闪跳。"
    ]
}
```

### 新增的 play / mode-switch 自动化校验

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: validatePlayRootTreeKeepsOnlyPianoPages() / validateRootModeSwitchPreservesExerciseTreeAndState()
// 功能说明: 修改后新增两组关键回归校验：一组验证 play 模式下 settings root 只剩 Piano；另一组验证切到 play 再切回 exercise 后，旧的 route 与状态仍能恢复。
static func validatePlayRootTreeKeepsOnlyPianoPages()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "play_root_tree_keeps_only_piano_pages"
    let stateContext = SettingsPanelStateContext.playDefault
    let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
    let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: stateContext
    )
    var issues: [SettingsNavigationValidationIssue] = []

    guard let pianoSection = resolveSection(.piano, in: panelModel) else {
        issues.append(issue(fixtureName, "play mode 下应保留 Piano section。"))
        return issues
    }

    if panelModel.sections.map(\.id) != [.piano] {
        issues.append(
            issue(
                fixtureName,
                "play mode 的 root sections 应只保留 Piano。"
            )
        )
    }

    if navigationModel.page(for: .section(.exercise)) != nil
        || navigationModel.page(for: .section(.accessories)) != nil
        || navigationModel.page(for: .section(.fretboard)) != nil
        || navigationModel.page(for: .section(.staff)) != nil
        || navigationModel.page(for: .section(.debug)) != nil {
        issues.append(
            issue(
                fixtureName,
                "play mode navigation tree 不应继续生成 exercise 专属 section page。"
            )
        )
    }

    return issues
}

static func validateRootModeSwitchPreservesExerciseTreeAndState()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "root_mode_switch_preserves_exercise_tree_and_state"
    var exerciseStateContext = SettingsPanelStateContext.default
    SettingsPanelEvent.triggerAction(.setExerciseModeSequence).apply(
        to: &exerciseStateContext
    )
    SettingsPanelEvent.triggerAction(.setLayoutPresetSideBySide).apply(
        to: &exerciseStateContext
    )
    SettingsPanelEvent.setSliderValue(.pianoRowCount, 5).apply(
        to: &exerciseStateContext
    )
    SettingsPanelEvent.setToggleValue(.pianoSnapEnabled, false).apply(
        to: &exerciseStateContext
    )

    var playStateContext = exerciseStateContext
    playStateContext.rootMode = .play
    playStateContext.reconcileForCurrentMode()

    var restoredExerciseStateContext = playStateContext
    restoredExerciseStateContext.rootMode = .exercise
    restoredExerciseStateContext.reconcileForCurrentMode()

    // ... 中间还有 panel / navigation 断言 ...
    return issues
}
```

---

## 6. 双平台 controller 显式声明当前 settings 上下文属于 `exercise`

### `iOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: settingsPanelStateContext
// 功能说明: 修改前 controller 在构造 settingsPanelStateContext 时没有明确带上 rootMode。
private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        exerciseLayoutPreferences: exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: pianoPanelState,
        debugState: settingsDebugState
    )
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: settingsPanelStateContext
// 功能说明: 修改后 iOS controller 明确告诉 settings snapshot 这是一条 exercise 路径，避免 phase3 新上下文默认值把 mode 来源留成隐式约定。
private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        rootMode: .exercise,
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        exerciseLayoutPreferences: exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: pianoPanelState,
        debugState: settingsDebugState
    )
}
```

### `macOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: settingsPanelStateContext
// 功能说明: 修改前 macOS controller 也没有显式传入 rootMode，仍默认依赖旧的 exercise-only 构造假设。
private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        exerciseLayoutPreferences: exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: pianoPanelState,
        debugState: settingsDebugState
    )
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: settingsPanelStateContext
// 功能说明: 修改后 macOS controller 同样显式固定为 exercise rootMode，让平台层在 phase4 之前继续稳定复用旧 exercise 容器。
private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        rootMode: .exercise,
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        exerciseLayoutPreferences: exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState,
        pianoPanelState: pianoPanelState,
        debugState: settingsDebugState
    )
}
```

---

## 7. 验证结果

### 时间戳来源

```bash
# 文件路径: 系统命令 / 时间戳采集
# 函数名: date
# 功能说明: 本次记录文件名使用系统自带 date 命令生成的时间戳。
date +"%Y%m%d_%H%M%S"
# 输出: 20260407_165136
```

### 本轮实际执行的验证

```bash
# 文件路径: 工程级验证命令
# 函数名: xcodebuild
# 功能说明: phase3 改动完成后，实际执行了双平台 Debug 构建验证。
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" \
-scheme "NoteMaster_Ver_1" \
-configuration Debug \
-destination "generic/platform=iOS Simulator" \
build CODE_SIGNING_ALLOWED=NO
# 结果: BUILD SUCCEEDED

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" \
-scheme "NoteMaster_Ver_1" \
-configuration Debug \
-destination "generic/platform=macOS" \
build CODE_SIGNING_ALLOWED=NO
# 结果: BUILD SUCCEEDED
# 备注: 第一次和 iOS 并发构建时命中过 Xcode build.db 锁；随后串行重跑 macOS 构建并通过。
```

- IDE 诊断检查：本轮改动文件 `ReadLints` 无新增错误。

---

## 8. 本轮落地结论

本轮 phase3 实际完成的是：

- 新增根模式状态容器 `RootModeState`，把 `exercise` 与 `play` 的状态边界显式化。
- 把 `SettingsPanelStateContext` 从 exercise-only 单体上下文拆成 `common + exercise + play` 三段。
- 让 `SettingsPanelModel` / `SettingsPanelSnapshotBuilder` / `SettingsNavigationValidation` 都具备 `rootMode` 感知能力。
- 为 `play` 新增 settings root tree 校验，并补上 `exercise -> play -> exercise` 的状态保留回归。
- 在 iOS / macOS 现有 exercise controller 上继续显式固定 `rootMode: .exercise`，保证 phase4 前旧页面壳层仍稳定可用。

# 20260407_181342_settings_navigation_validation_root_contract_and_mainactor_fix

## 记录范围

本记录只覆盖刚刚这一轮对 `SettingsNavigationValidation.swift` 的修复，目标是解决 iOS / macOS 共用的 settings navigation validation 在 `root mode` 往返场景下发生契约漂移的问题，并同时收口这份 validation 文件本身的 `MainActor` 隔离警告。

本记录参考了当前工作区的 `git diff` 与文件现状，但**不包含原始 diff**。  
当前工作区里仍有一个用户侧已有的 `.md` 变更：

- `.cursor/plans/play模式分阶段计划_3b30e6c6.plan.md`

此外，上一轮 `phase5` 的播放链路改动已经单独记录在：

- `commit_records/20260407_174434_phase5_shared_playback_coordinator_and_audio_backend.md`

下面这份记录**不重复描述 phase5 主体代码**，只描述刚刚新增的 validation 修复。

本轮涉及文件：

- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`

---

## 1. 收口 validation runner 的 MainActor 边界

### 1.1 `SettingsNavigationValidationRunner` / `SettingsNavigationValidationFixture`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: SettingsNavigationValidationRunner / SettingsNavigationValidationFixture
// 功能说明: 修改前 runner 本身没有声明 MainActor，fixture 闭包也是普通同步闭包；
// 当 validate* 方法因为构建 navigation/panel model 而被编译器推到 main actor 后，
// 这里会出现成批的“call to main actor-isolated static method in a synchronous nonisolated context”警告。
enum SettingsNavigationValidationRunner {
    static func run(
        platform: SettingsNavigationValidationPlatform
    ) -> SettingsNavigationValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [SettingsNavigationValidationIssue] = []
        // ... 省略其余逻辑 ...
    }
}

private struct SettingsNavigationValidationFixture {
    var name: String
    var validate: () -> [SettingsNavigationValidationIssue]
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: SettingsNavigationValidationRunner / SettingsNavigationValidationFixture
// 功能说明: 修改后把整份 shared validation runner 明确放到 MainActor 上执行，
// fixture 闭包也同步声明为 @MainActor；这样 iOS / macOS 共用同一份 validation 时，
// actor 语义不再漂移，也不会再在这个文件里产生成批隔离 warning。
@MainActor
enum SettingsNavigationValidationRunner {
    static func run(
        platform: SettingsNavigationValidationPlatform
    ) -> SettingsNavigationValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [SettingsNavigationValidationIssue] = []
        // ... 省略其余逻辑 ...
    }
}

private struct SettingsNavigationValidationFixture {
    var name: String
    var validate: @MainActor () -> [SettingsNavigationValidationIssue]
}
```

---

## 2. 把 root section 契约从“多处手写数组”收口成单一来源

### 2.1 `validateSplitSectionsProduceExpectedPageTree()` / `validatePlayRootTreeKeepsOnlyPianoPages()` / `validateRootModeSwitchPreservesExerciseTreeAndState()`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: validateSplitSectionsProduceExpectedPageTree() / validatePlayRootTreeKeepsOnlyPianoPages() / validateRootModeSwitchPreservesExerciseTreeAndState()
// 功能说明: 修改前 exercise/play 的 root section 期望被分别硬编码在多个 fixture 中；
// 其中 root_mode_switch_preserves_exercise_tree_and_state 里还残留旧数组，
// 从 play 切回 exercise 时少了 `.mode`，导致共享 validation 在 iOS / macOS 上一起失败。
if panelModel.sections.map(\.id) != [
    .mode,
    .exercise,
    .accessories,
    .fretboard,
    .staff,
    .piano,
    .debug
] {
    issues.append(
        issue(
            fixtureName,
            "default state 的 section 顺序应保持 Mode -> Exercise -> Accessories -> Fretboard -> Staff -> Piano -> Debug。"
        )
    )
}

if panelModel.sections.map(\.id) != [.mode, .piano] {
    issues.append(
        issue(
            fixtureName,
            "play mode 的 root sections 应只保留 Mode 与 Piano。"
        )
    )
}

if restoredExercisePanelModel.sections.map(\.id) != [
    .exercise,
    .accessories,
    .fretboard,
    .staff,
    .piano,
    .debug
] {
    issues.append(
        issue(
            fixtureName,
            "从 play 切回 exercise 后，旧的 exercise root tree 应完整恢复。"
        )
    )
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: expectedRootSectionIDs(for:) / validateSplitSectionsProduceExpectedPageTree() / validatePlayRootTreeKeepsOnlyPianoPages() / validateRootModeSwitchPreservesExerciseTreeAndState()
// 功能说明: 修改后把 exercise / play 的 root section 契约统一收口到 expectedRootSectionIDs(for:)；
// 所有相关 fixture 都共享这一份期望，不再各自拷贝数组，从根因上避免“有的地方更新了 Mode，有的地方没更新”的漂移。
if panelModel.sections.map(\.id) != expectedRootSectionIDs(for: .exercise) {
    issues.append(
        issue(
            fixtureName,
            "default state 的 section 顺序应保持 Mode -> Exercise -> Accessories -> Fretboard -> Staff -> Piano -> Debug。"
        )
    )
}

if panelModel.sections.map(\.id) != expectedRootSectionIDs(for: .play) {
    issues.append(
        issue(
            fixtureName,
            "play mode 的 root sections 应只保留 Mode 与 Piano。"
        )
    )
}

if playPanelModel.sections.map(\.id) != expectedRootSectionIDs(for: .play) {
    issues.append(
        issue(
            fixtureName,
            "切到 play 后，settings root 应只保留 Mode 与 Piano section。"
        )
    )
}

if restoredExercisePanelModel.sections.map(\.id) != expectedRootSectionIDs(for: .exercise) {
    issues.append(
        issue(
            fixtureName,
            "从 play 切回 exercise 后，旧的 exercise root tree 应完整恢复。"
        )
    )
}

static func expectedRootSectionIDs(
    for rootMode: RootMode
) -> [SettingsSectionID] {
    switch rootMode {
    case .exercise:
        return [
            .mode,
            .exercise,
            .accessories,
            .fretboard,
            .staff,
            .piano,
            .debug
        ]
    case .play:
        return [
            .mode,
            .piano
        ]
    }
}
```

---

## 3. 把 root route item 期望也收口成单一来源

### 3.1 `validatePlayRootTreeKeepsOnlyPianoPages()`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: validatePlayRootTreeKeepsOnlyPianoPages()
// 功能说明: 修改前 play mode root route 的期望也在 fixture 内手写展开；
// section 契约一旦再变化，route item 断言也需要手工同步，维护点分散。
if rootRouteItems != [
    SettingsRouteItem(
        title: modeSection.title,
        subtitle: nil,
        route: .section(.mode)
    ),
    SettingsRouteItem(
        title: pianoSection.title,
        subtitle: nil,
        route: .section(.piano)
    )
] {
    issues.append(
        issue(
            fixtureName,
            "play mode root route 应只包含 Mode 与 Piano 入口。"
        )
    )
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: expectedRootRouteItems(for:in:) / validatePlayRootTreeKeepsOnlyPianoPages()
// 功能说明: 修改后 route item 期望也从共享 helper 生成；这样 root section 顺序、标题、route 结构都由同一份契约派生，
// 不再需要在 play fixture 里额外复制一遍 SettingsRouteItem 数组。
if rootRouteItems != expectedRootRouteItems(for: .play, in: panelModel) {
    issues.append(
        issue(
            fixtureName,
            "play mode root route 应只包含 Mode 与 Piano 入口。"
        )
    )
}

static func expectedRootRouteItems(
    for rootMode: RootMode,
    in panelModel: SettingsPanelModel
) -> [SettingsRouteItem] {
    expectedRootSectionIDs(for: rootMode).compactMap { sectionID in
        guard let section = resolveSection(sectionID, in: panelModel) else {
            return nil
        }

        return SettingsRouteItem(
            title: section.title,
            subtitle: nil,
            route: .section(sectionID)
        )
    }
}
```

---

## 4. 这次修复后的实际效果

- `root_mode_switch_preserves_exercise_tree_and_state` 不再使用过期的 exercise root sections 数组，回切 `exercise` 后会按最新约定验证 `Mode + Exercise + Accessories + Fretboard + Staff + Piano + Debug`。
- `split_sections_produce_expected_page_tree`、`play_root_tree_keeps_only_piano_pages`、`root_mode_switch_preserves_exercise_tree_and_state` 三个 fixture 共用同一份 root 契约，后续 root tree 若再扩展，不会出现只改一半 fixture 的问题。
- `SettingsNavigationValidation.swift` 里原本那组 `main actor-isolated static method` warning 被一起消掉，iOS / macOS 共用这份 validation 时的 actor 边界更稳定。

---

## 5. 验证结果

本轮实际做了以下验证：

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build CODE_SIGNING_ALLOWED=NO`
- 对 `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift` 执行 `ReadLints`，未发现新增诊断
- 额外做了一次 macOS 启动级抽查：应用已越过之前会立刻触发的 `SettingsNavigationValidation.swift:111` 崩溃点，随后手动结束进程；本轮未单独做完整 iOS 启动级运行验证

验证结论：

- iOS Debug 构建通过
- macOS Debug 构建通过
- `SettingsNavigationValidation.swift` 相关 `MainActor` warning 已消失

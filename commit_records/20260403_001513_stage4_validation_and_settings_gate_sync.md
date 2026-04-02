# 20260403_001513_stage4_validation_and_settings_gate_sync

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_001513`
- 记录范围：只记录方案 B 的阶段 4 落地，即把 rail contract 的回归断言补齐到 shared validation，并把 `Vertical Viewport` 的 settings gate 明确冻结为只跟 `fretboardLayoutContract` 走
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本记录中的“修改前”，指 `20260403_000303_stage3_natural_note_strip_renderer_centering.md` 记录完成后的代码状态
- 本轮实际改动文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`

## 1. 本轮目标

- 阶段 3 已经把 right rail 的内容尺寸和 renderer 居中路径打通，但如果不把 contract 关系冻结到 shared validation，后续很容易再次退回“局部看起来没问题、全局语义悄悄漂移”的状态。
- 阶段 4 的目标不是继续扩 UI，而是补齐两类不变量：
- `naturalNoteStripRailContract` 与 `fretboardLayoutContract` 必须保持正交，不能互相污染。
- settings/navigation 对 `Vertical Viewport Height` 的显隐判断，必须继续只由 `fretboardLayoutContract` 决定，不能因为 rail contract 存在就意外暴露新的设置项。

## 2. 修改一：给 `ExerciseCompositionValidation` 增加“rail contract 与 fretboard 高度 contract 正交”夹具

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: makeFixtures(), validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// 修改前说明: 旧夹具已经能冻结 rail contract 的默认字段，
// 也会顺带检查 side rail 场景下 fretboard 的 heightPolicy 是 fillAvailableHeight，
// 但还没有一个独立夹具去覆盖：
// 1. side rail / stacked rail / 非 rail side 三种场景的 contract 正交关系
// 2. ExerciseScene -> ExercisePresentationState 的 rail contract 透传一致性
// 3. usesVerticalViewportHeightControl 不应被 rail contract 误打开
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
    validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
)

static func validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults"
    var issues: [ExerciseCompositionValidationIssue] = []

    // 这里主要冻结 rail contract 自身字段
    switch railPresentation.naturalNoteStripRailContract {
    case let .some(railContract):
        if railContract.buttonShape != .square
            || railContract.buttonExtent
            != ExerciseNaturalNoteStripRailContract.defaultButtonExtent {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 rail contract 应继续给出 square + 20 的默认按钮几何语义。"
                )
            )
        }
    case .none:
        issues.append(
            issue(
                fixtureName,
                "sideBySide 的 fretboard -> natural note strip scene 在阶段 1 应暴露 active rail contract，而不是 nil。"
            )
        )
    }

    // 这里只对 side rail 的 fretboard height 做了单点检查
    if railPresentation.fretboardLayoutContract.heightPolicy
        != .fillAvailableHeight {
        issues.append(
            issue(
                fixtureName,
                "阶段 1 引入 rail contract 时，不应反向破坏 side fretboard 的 fillAvailableHeight 语义。"
            )
        )
    }

    return issues
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: makeFixtures(), validateSideRailContractRemainsOrthogonalToFretboardHeightContract()
// 修改后说明: 新增一个独立夹具，把 side rail / stacked rail / 非 rail side
// 三种组合下的 rail contract 与 fretboardLayoutContract 关系显式冻结下来。
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
    validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
),
ExerciseCompositionValidationFixture(
    name: "side_rail_contract_remains_orthogonal_to_fretboard_height_contract",
    validate: validateSideRailContractRemainsOrthogonalToFretboardHeightContract
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
)

static func validateSideRailContractRemainsOrthogonalToFretboardHeightContract()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "side_rail_contract_remains_orthogonal_to_fretboard_height_contract"
    var issues: [ExerciseCompositionValidationIssue] = []

    let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt),
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .sideBySide
            )
        )
    )

    // 冻结 side rail 场景下 rail contract 的精确输出
    if sideRailPresentation.naturalNoteStripRailContract
        != .defaultSideBySideAnswerRail {
        issues.append(
            issue(
                fixtureName,
                "sideBySide 的 fretboard -> natural note strip presentation 应继续精确暴露默认 rail contract。"
            )
        )
    }
    if sideRailPresentation.scene.naturalNoteStripRailContract
        != .defaultSideBySideAnswerRail {
        issues.append(
            issue(
                fixtureName,
                "ExerciseScene 应继续把 side rail 的 shared 默认 contract 原样透传给 presentation 层。"
            )
        )
    }

    // 冻结 side rail 场景下 fretboard 高度 contract，不允许 rail contract 反向篡改
    if sideRailPresentation.fretboardLayoutContract
        != ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: true,
            heightPolicy: .fillAvailableHeight
        ) {
        issues.append(
            issue(
                fixtureName,
                "side rail 场景下的 fretboardLayoutContract 应继续保持 viewport pin + fillAvailableHeight。"
            )
        )
    }
    if sideRailPresentation.fretboardLayoutContract
        .usesVerticalViewportHeightControl {
        issues.append(
            issue(
                fixtureName,
                "side rail 场景下的 fretboard 高度应由容器填满，不应重新打开 Vertical Viewport Height 控制语义。"
            )
        )
    }

    let stackedRailPresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt),
            fretboardTrainerState: .init(positionPromptMode: ()),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked
            )
        )
    )

    // 冻结 stacked 场景：不允许误带 rail contract，且继续使用 viewport ratio
    if stackedRailPresentation.naturalNoteStripRailContract != nil
        || stackedRailPresentation.scene.naturalNoteStripRailContract != nil {
        issues.append(
            issue(
                fixtureName,
                "stacked 的 fretboard -> natural note strip 场景不应误暴露 right rail contract。"
            )
        )
    }
    if stackedRailPresentation.fretboardLayoutContract
        != ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: true,
            heightPolicy: .followViewportRatio
        ) {
        issues.append(
            issue(
                fixtureName,
                "stacked 场景下的 fretboardLayoutContract 应继续保持 viewport pin + followViewportRatio。"
            )
        )
    }

    let sideTargetPromptPresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
            fretboardTrainerState: .init(),
            fretboardDisplayState: .default,
            staffDisplayState: .default,
            pianoPanelState: .init(),
            layoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .targetPromptToFretboard,
                layoutPreset: .sideBySide
            )
        )
    )

    // 冻结非 rail 的 sideBySide 场景：仍然是 fillAvailableHeight，但不应误携带 rail contract
    if sideTargetPromptPresentation.naturalNoteStripRailContract != nil
        || sideTargetPromptPresentation.scene.naturalNoteStripRailContract != nil {
        issues.append(
            issue(
                fixtureName,
                "不包含 natural note strip answer rail 的 sideBySide 场景不应误携带 rail contract。"
            )
        )
    }
    if sideTargetPromptPresentation.fretboardLayoutContract.heightPolicy
        != .fillAvailableHeight
        || sideTargetPromptPresentation.fretboardLayoutContract
        .usesVerticalViewportHeightControl {
        issues.append(
            issue(
                fixtureName,
                "sideBySide 的非 rail fretboard 场景仍应保持 fillAvailableHeight，证明 rail contract 不会篡改 side 布局的 fretboard 高度语义。"
            )
        )
    }

    return issues
}
```

### 2.3 这一改动解决了什么

- 现在 shared 层不再只是“冻结 rail contract 自己长什么样”，而是把它和 `fretboardLayoutContract` 的边界一起冻结住了。
- 这能防止后续有人在调整 rail 语义时，不小心把 `fillAvailableHeight` / `followViewportRatio` / `usesVerticalViewportHeightControl` 这些 fretboard 语义改坏。
- `ExerciseScene` 到 `ExercisePresentationState` 的 contract 透传也被明确校验，避免将来 scene 层和 presentation 层各自返回不同 rail contract。

## 3. 修改二：给 `SettingsNavigationValidation` 增加“Vertical Viewport gate 只跟 fretboard contract 走”的夹具

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数/符号: makeFixtures(), manualChecklist(for:), validateFretboardViewportRouteVisibilityTracksDisplayMode()
// 修改前说明: 旧逻辑已经能验证 viewport 深层页在 side / stacked / horizontal 三种显示路径上的出现与消失，
// 但验证仍停留在 route/page 层，没有把 gate 的来源显式冻结到 fretboardLayoutContract。
// 同时 manual checklist 也没有明确声明 settings 不新增 rail 配置入口。
SettingsNavigationValidationFixture(
    name: "fretboard_viewport_route_visibility_tracks_display_mode",
    validate: validateFretboardViewportRouteVisibilityTracksDisplayMode
),
SettingsNavigationValidationFixture(
    name: "fretboard_string_thickness_option_tracks_state",
    validate: validateFretboardStringThicknessOptionTracksState
)

[
    "确认切换到 horizontal 指板布局，或在 side 布局下保持 vertical 指板时 `Fretboard > Vertical Viewport` 深层页会消失；切回 stacked + vertical 后会恢复。",
    "确认 `Exercise` 分区只显示 `Exercise Mode / Composition Preset / Layout Preset`，不再出现 `Top Content / Main Content`。"
]

static func validateFretboardViewportRouteVisibilityTracksDisplayMode()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "fretboard_viewport_route_visibility_tracks_display_mode"
    var issues: [SettingsNavigationValidationIssue] = []

    let sideVerticalStateContext = SettingsPanelStateContext.default
    let sideVerticalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: sideVerticalStateContext
    )
    if sideVerticalNavigationModel.page(for: .fretboardViewport) != nil {
        issues.append(
            issue(
                fixtureName,
                "side + vertical 指板模式下不应继续生成 Fretboard Viewport 深层页。"
            )
        )
    }

    let stackedVerticalStateContext = SettingsPanelStateContext(
        exerciseLayoutPreferences: ExerciseLayoutPreferences(
            compositionPreset: .fretboardToNaturalNoteStrip,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: false,
            isAccessoryExpanded: true
        )
    )
    let stackedVerticalNavigationModel = SettingsNavigationSnapshotBuilder
        .makeModel(from: stackedVerticalStateContext)
    if stackedVerticalNavigationModel.page(for: .fretboardViewport) == nil {
        issues.append(
            issue(
                fixtureName,
                "stacked + vertical 指板模式下应继续生成 Fretboard Viewport 深层页。"
            )
        )
    }

    return issues
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数/符号: makeFixtures(), manualChecklist(for:), validateVerticalViewportGateTracksFretboardContractOnly()
// 修改后说明: 新增一个 contract 级 fixture，直接断言 side / stacked / horizontal 三种状态下
// Vertical Viewport 的 gate 只由 fretboardLayoutContract 和 showsVerticalViewportHeightControl 决定。
SettingsNavigationValidationFixture(
    name: "fretboard_viewport_route_visibility_tracks_display_mode",
    validate: validateFretboardViewportRouteVisibilityTracksDisplayMode
),
SettingsNavigationValidationFixture(
    name: "vertical_viewport_gate_tracks_fretboard_contract_only",
    validate: validateVerticalViewportGateTracksFretboardContractOnly
),
SettingsNavigationValidationFixture(
    name: "fretboard_string_thickness_option_tracks_state",
    validate: validateFretboardStringThicknessOptionTracksState
)

[
    "确认切换到 horizontal 指板布局，或在 side 布局下保持 vertical 指板时 `Fretboard > Vertical Viewport` 深层页会消失；切回 stacked + vertical 后会恢复。",
    "确认 settings 中没有新增 `Rail` / `Strip Size` / `Strip Alignment` 一类入口；右侧 natural note strip 的尺寸与居中仍保持为内部布局契约。"
]

static func validateVerticalViewportGateTracksFretboardContractOnly()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "vertical_viewport_gate_tracks_fretboard_contract_only"
    var issues: [SettingsNavigationValidationIssue] = []

    let sideStateContext = SettingsPanelStateContext.default
    let sidePanelModel = SettingsPanelSnapshotBuilder.makeModel(from: sideStateContext)
    guard let sideFretboardSection = resolveSection(.fretboard, in: sidePanelModel) else {
        issues.append(issue(fixtureName, "default side state 应保留 Fretboard section。"))
        return issues
    }

    // 默认 side：fretboard contract 仍是 fillAvailableHeight，因此不应显示 viewport height 控件
    if sideStateContext.exerciseLayoutPreferences.layoutPreset != .sideBySide {
        issues.append(
            issue(
                fixtureName,
                "default settings state 应继续规范化到 Side by Side layout。"
            )
        )
    }
    if sideStateContext.fretboardLayoutContract
        != ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: true,
            heightPolicy: .fillAvailableHeight
        ) {
        issues.append(
            issue(
                fixtureName,
                "default side state 下的 viewport gate 应继续读取 fillAvailableHeight 的 fretboard contract。"
            )
        )
    }
    if sideStateContext.fretboardLayoutContract
        .usesVerticalViewportHeightControl
        || sideStateContext.showsVerticalViewportHeightControl {
        issues.append(
            issue(
                fixtureName,
                "default side state 不应因为内部 rail contract 而重新显示 Vertical Viewport Height 控件。"
            )
        )
    }
    if sideFretboardSection.rows.map(\.id).contains(.slider(.verticalHostHeightRatio)) {
        issues.append(
            issue(
                fixtureName,
                "default side state 的 Fretboard section 不应直接混入 Vertical Viewport Height slider。"
            )
        )
    }

    let stackedStateContext = SettingsPanelStateContext(
        exerciseLayoutPreferences: ExerciseLayoutPreferences(
            compositionPreset: .fretboardToNaturalNoteStrip,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: false,
            isAccessoryExpanded: true
        )
    )

    // stacked：fretboard contract 仍是 followViewportRatio，因此应继续显示 viewport height 控件
    if stackedStateContext.fretboardLayoutContract
        != ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: true,
            heightPolicy: .followViewportRatio
        ) {
        issues.append(
            issue(
                fixtureName,
                "stacked state 下的 viewport gate 应继续读取 followViewportRatio 的 fretboard contract。"
            )
        )
    }
    if !stackedStateContext.fretboardLayoutContract
        .usesVerticalViewportHeightControl
        || !stackedStateContext.showsVerticalViewportHeightControl {
        issues.append(
            issue(
                fixtureName,
                "stacked + vertical state 应继续显示 Vertical Viewport Height 控件。"
            )
        )
    }

    var horizontalFretboardDisplayState = FretboardDisplayState.default
    horizontalFretboardDisplayState.setDisplayMode(.horizontal)
    let horizontalStateContext = SettingsPanelStateContext(
        fretboardDisplayState: horizontalFretboardDisplayState
    )

    // horizontal：显示模式直接关掉 vertical viewport gate
    if horizontalStateContext.showsVerticalViewportHeightControl {
        issues.append(
            issue(
                fixtureName,
                "horizontal 指板模式不应暴露 Vertical Viewport Height 控件。"
            )
        )
    }

    return issues
}
```

### 3.3 这一改动解决了什么

- 旧夹具只能说明“viewport 页最后有没有出现”，新夹具则把“为什么出现/为什么不出现”收口到了 contract 层。
- 这能防止以后有人在 settings builder 或 navigation builder 里直接看 rail 语义做分支，导致 `Vertical Viewport Height` 被错误暴露。
- manual checklist 也明确写死了一条产品边界：阶段 4 不新增 rail 尺寸/对齐设置项，rail contract 继续保持内部布局契约。

## 4. 本轮没有改什么

- 没有修改 `ExerciseNaturalNoteStripRailContract` 的字段定义、默认值和推导入口。
- 没有修改 `NaturalNoteStripView`、双端 renderer、`fretboard` 渲染链和布局约束。
- 没有新增任何 settings choice / toggle / route，也没有把 rail contract 暴露成新的设置页入口。
- 没有修改默认 layout、导航树结构、`Accessory Presentation` 行为或已有 route 标题。

## 5. 最终状态总结

- 到阶段 4 为止，方案 B 的 shared contract 已经不只是“能算出来”，而是“有回归护栏”了。
- `ExerciseCompositionValidation` 现在会同时冻结：
- side rail 场景必须产出 rail contract
- stacked rail 场景不能误带 rail contract
- 非 rail 的 sideBySide 场景不能误带 rail contract
- side / stacked / horizontal 下的 `fretboardLayoutContract` 语义不能被 rail contract 污染
- `SettingsNavigationValidation` 现在会同时冻结：
- `Vertical Viewport` 的显隐继续只由 `fretboardLayoutContract` 和 `showsVerticalViewportHeightControl` 决定
- settings 不新增 rail 配置入口

## 6. 验证结果

- `ReadLints` 检查相关文件：无 linter 错误
- 构建验证命令（macOS）：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- 构建验证命令（iOS Simulator）：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`
- 构建结果（macOS）：`BUILD SUCCEEDED`
- 构建结果（iOS Simulator）：`BUILD SUCCEEDED`
- 本记录只覆盖 shared validation / settings gate 的实现与构建验证；side / stacked 切换、启动、窗口尺寸变化的手工回归仍属于后续阶段 5

## 7. 对阶段 5 的直接意义

- 阶段 5 可以把注意力集中到双端手工回归，不需要再反复确认“当前看到的 viewport / rail 行为到底是不是 contract 漂移”。
- 如果之后再次出现 `Vertical Viewport Height` 在 side 模式错误出现，或者 stacked 模式错误消失，优先看阶段 4 新增的 settings fixture 是否先报错。
- 如果之后再次出现 rail contract 和 fretboard 高度语义互相污染，优先看阶段 4 新增的 shared fixture 是否已经能提前把问题拦住。

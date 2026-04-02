# 20260402_124609_exercise_state_semantics_root_fix

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260402_124609`
- 记录范围：实施 `exercise-state-semantics` 计划，把 `Exercise` 共享层里的 `scene membership`、`projected state`、`effective state` 三套语义彻底拆开，并同步迁移 `policy / router / controller / validation`
- 修改前基线：以上一轮 `右侧音名条布局` 阶段 `5` 完成后的工作区状态为准；本记录不放原始 `git diff`，只按真实功能变化记录“修改前 / 修改后”
- 修改目标：
  - 不再用 `surfaceState(for:)` 的 `nil / hidden` 偶然行为推断 `surface` 是否真的存在于 `scene tree`
  - 让 `ExerciseCompositionPolicy.makeSurfaceStates(scene:)` 改成稀疏存储，只保存真正投影到 `scene` 里的 surface 状态
  - 让 `ExerciseAnswerRouter`、双平台 `ViewController`、`ExerciseCompositionValidation` 都改用新的结构/状态边界
  - 增加共享回归夹具，冻结 `absent != hidden` 的根因边界
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 1. `ExerciseScene.swift`：把“是否在 scene tree 中”收敛成显式 membership helper

- 修改前：shared 层只有 `surfaceNode(for:)`，消费层想判断某个 `surface` 是否真的在 `scene` 里，只能自己用 `surfaceNode(for:) != nil` 这种实现细节；`hasMixedMainAxisSizing(along:containing:)` 也直接复用了这套细节判断。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSceneNode.surfaceNode(for:), ExerciseSceneNode.hasMixedMainAxisSizing(along:containing:)
// 功能说明: 修改前没有显式 membership API，调用方只能通过 surfaceNode(...) != nil 间接判断某个 surface 是否在 scene tree 中。
func surfaceNode(for surfaceID: ExerciseSurfaceID) -> ExerciseSurfaceNode? {
    switch self {
    case let .surface(surface):
        return surface.id == surfaceID ? surface : nil
    case let .split(_, children):
        return children.compactMap {
            $0.node.surfaceNode(for: surfaceID)
        }.first
    case let .overlay(base, floating):
        if let match = base.surfaceNode(for: surfaceID) {
            return match
        }
        return floating.compactMap {
            $0.surfaceNode(for: surfaceID)
        }.first
    case let .collapsible(main, accessory, _):
        if let match = main.surfaceNode(for: surfaceID) {
            return match
        }
        return accessory.surfaceNode(for: surfaceID)
    }
}

func hasMixedMainAxisSizing(
    along axis: ExerciseSceneAxis,
    containing surfaceID: ExerciseSurfaceID
) -> Bool {
    switch self {
    case .surface:
        return false
    case let .split(splitAxis, children):
        let hasCurrentMixedMainAxisSizing = splitAxis == axis
            && children.contains(where: { $0.mainAxisSizing.isWeighted })
            && children.contains(where: { !$0.mainAxisSizing.isWeighted })
            && children.contains {
                $0.node.surfaceNode(for: surfaceID) != nil
            }
        // ... 其余未改动逻辑省略 ...
        return hasCurrentMixedMainAxisSizing
    default:
        return false
    }
}
```

- 修改后：新增 `containsSurface(_:)`，shared 层统一提供结构 membership 语义；原本内联的 `surfaceNode(...) != nil` 判断也统一收口到这个 helper。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift
// 函数名: ExerciseSceneNode.containsSurface(_:), ExerciseScene.containsSurface(_:), ExerciseSceneNode.hasMixedMainAxisSizing(along:containing:)
// 功能说明: 修改后把“某个 surface 是否真实存在于 scene tree 中”沉淀为显式 shared API，供 validation、router、presentation state 统一复用。
func containsSurface(_ surfaceID: ExerciseSurfaceID) -> Bool {
    surfaceNode(for: surfaceID) != nil
}

func containsSurface(_ surfaceID: ExerciseSurfaceID) -> Bool {
    root.containsSurface(surfaceID)
}

func hasMixedMainAxisSizing(
    along axis: ExerciseSceneAxis,
    containing surfaceID: ExerciseSurfaceID
) -> Bool {
    switch self {
    case .surface:
        return false
    case let .split(splitAxis, children):
        let hasCurrentMixedMainAxisSizing = splitAxis == axis
            && children.contains(where: { $0.mainAxisSizing.isWeighted })
            && children.contains(where: { !$0.mainAxisSizing.isWeighted })
            && children.contains { $0.node.containsSurface(surfaceID) }
        // ... 其余未改动逻辑省略 ...
        return hasCurrentMixedMainAxisSizing
    default:
        return false
    }
}
```

## 2. `ExercisePresentationState.swift`：拆分 `projected state` 与 `effective state`

- 修改前：`surfaceState(for:)` 同时承担两种职责。
  - 先读 `surfaceStates` 字典，回答“当前状态是什么”
  - 读不到时再递归 `scene tree`，顺便回答“这个 surface 有没有”
  这导致调用方很容易把 `surfaceState(...) != nil` 误当成结构 membership。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExercisePresentationState.init(...), surfaceState(for:), setSurfaceState(_:for:), isSurfaceVisible(_:)
// 功能说明: 修改前 presentation state 只有一个 surfaceState 入口，既表达“在不在 scene 中”，也表达“当前状态是什么”，语义混在一起。
init(
    scene: ExerciseScene,
    surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState] = [:],
    resolvedLayoutPreferences: ExerciseLayoutPreferences = .default,
    legacyPageDisplayState: PageDisplayState? = nil
) {
    self.scene = scene
    self.resolvedLayoutPreferences = resolvedLayoutPreferences
    self.legacyPageDisplayState = legacyPageDisplayState
    self.surfaceStates = surfaceStates
}

func surfaceState(
    for surfaceID: ExerciseSurfaceID
) -> ExerciseSurfaceState? {
    if let state = surfaceStates[surfaceID] {
        return state
    }

    return defaultSurfaceState(
        for: surfaceID,
        in: scene.root,
        inheritedVisibility: true
    )
}

mutating func setSurfaceState(
    _ state: ExerciseSurfaceState,
    for surfaceID: ExerciseSurfaceID
) {
    surfaceStates[surfaceID] = state
}

func isSurfaceVisible(_ surfaceID: ExerciseSurfaceID) -> Bool {
    surfaceState(for: surfaceID)?.isVisible ?? false
}
```

- 修改后：明确拆成三层语义。
  - `containsSurface(_:)`：只回答结构上在不在
  - `projectedSurfaceState(for:)`：只对 `scene` 里真实存在的 surface 返回状态
  - `effectiveSurfaceState(for:)`：面向 UI / 交互的闭世界结果，不存在就收口成 `.hidden`
  同时初始化和 `setSurfaceState` 都会过滤掉不在 `scene` 里的键，避免稀疏状态表再次被污染。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名: ExercisePresentationState.init(...), containsSurface(_:), projectedSurfaceState(for:), effectiveSurfaceState(for:), setSurfaceState(_:for:), normalizedSurfaceStates(_:in:), isSurfaceVisible(_:)
// 功能说明: 修改后显式拆出 membership / projected / effective 三套 API，并让 surfaceStates 只保存 scene 内真实投影出的 surface。
init(
    scene: ExerciseScene,
    surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState] = [:],
    resolvedLayoutPreferences: ExerciseLayoutPreferences = .default,
    legacyPageDisplayState: PageDisplayState? = nil
) {
    self.scene = scene
    self.resolvedLayoutPreferences = resolvedLayoutPreferences
    self.legacyPageDisplayState = legacyPageDisplayState
    self.surfaceStates = Self.normalizedSurfaceStates(
        surfaceStates,
        in: scene
    )
}

func containsSurface(_ surfaceID: ExerciseSurfaceID) -> Bool {
    scene.containsSurface(surfaceID)
}

func projectedSurfaceState(
    for surfaceID: ExerciseSurfaceID
) -> ExerciseSurfaceState? {
    guard containsSurface(surfaceID) else {
        return nil
    }

    if let state = surfaceStates[surfaceID] {
        return state
    }

    return defaultProjectedSurfaceState(
        for: surfaceID,
        in: scene.root,
        inheritedVisibility: true
    )
}

func effectiveSurfaceState(
    for surfaceID: ExerciseSurfaceID
) -> ExerciseSurfaceState {
    projectedSurfaceState(for: surfaceID) ?? .hidden
}

mutating func setSurfaceState(
    _ state: ExerciseSurfaceState,
    for surfaceID: ExerciseSurfaceID
) {
    guard containsSurface(surfaceID) else {
        surfaceStates.removeValue(forKey: surfaceID)
        return
    }

    surfaceStates[surfaceID] = state
}

private static func normalizedSurfaceStates(
    _ surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState],
    in scene: ExerciseScene
) -> [ExerciseSurfaceID: ExerciseSurfaceState] {
    surfaceStates.reduce(into: [:]) { partialResult, entry in
        guard scene.containsSurface(entry.key) else {
            return
        }

        partialResult[entry.key] = entry.value
    }
}

func isSurfaceVisible(_ surfaceID: ExerciseSurfaceID) -> Bool {
    effectiveSurfaceState(for: surfaceID).isVisible
}
```

## 3. `ExerciseCompositionPolicy.swift`：状态表从“全量 hidden 预填”改成“仅存 projected surface”

- 修改前：`makeSurfaceStates(scene:)` 会先把 `ExerciseSurfaceID.allCases` 全部写成 `.hidden`，再用默认投影结果覆盖。这会把“不在 scene 中”和“在 scene 中但 hidden”都挤压成“字典里有值”。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: ExerciseCompositionPolicy.makeSurfaceStates(scene:)
// 功能说明: 修改前先给所有 ExerciseSurfaceID 预置 hidden，再回填默认状态，直接制造了 absent / hidden 的语义混淆。
private static func makeSurfaceStates(
    scene: ExerciseScene
) -> [ExerciseSurfaceID: ExerciseSurfaceState] {
    var surfaceStates = Dictionary(
        uniqueKeysWithValues: ExerciseSurfaceID.allCases.map {
            ($0, ExerciseSurfaceState.hidden)
        }
    )

    let defaultPresentationState = ExercisePresentationState(scene: scene)
    for surfaceID in ExerciseSurfaceID.allCases {
        if let state = defaultPresentationState.surfaceState(
            for: surfaceID
        ) {
            surfaceStates[surfaceID] = state
        }
    }

    return surfaceStates
}
```

- 修改后：只遍历 `scene.surfaceNodes`，并且只保存 `projectedSurfaceState` 能取到的状态；`.hidden` 退回到读取层语义，不再作为存储层的全量默认值。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: ExerciseCompositionPolicy.makeSurfaceStates(scene:)
// 功能说明: 修改后 surfaceStates 变成稀疏表，只存 scene tree 里真实投影出的 surface，缺席 surface 不再被预填 hidden。
private static func makeSurfaceStates(
    scene: ExerciseScene
) -> [ExerciseSurfaceID: ExerciseSurfaceState] {
    let defaultPresentationState = ExercisePresentationState(scene: scene)
    return scene.surfaceNodes.reduce(into: [:]) { surfaceStates, surface in
        guard let state = defaultPresentationState.projectedSurfaceState(
            for: surface.id
        ) else {
            return
        }

        surfaceStates[surface.id] = state
    }
}
```

## 4. `ExerciseAnswerRouter.swift` 与双平台 `ViewController`：消费层不再依赖 `nil` 的偶然含义

- 修改前：`ExerciseAnswerRouter` 通过 `surfaceState(for:) == nil` 直接返回 `surfaceUnavailable`；双平台 controller 也通过 `surfaceState(... )?.isInteractionEnabled ?? false` 读交互开关。这样一旦状态表被全量预填，调用方就会把“缺席 surface”误当成“存在但 hidden / disabled”。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名: ExerciseAnswerRouter.validateAnswerSurface(_:in:)
// 功能说明: 修改前 answer router 直接拿 surfaceState(for:) 的 nil 语义判断 surfaceUnavailable，隐式依赖了旧状态表实现。
private static func validateAnswerSurface(
    _ surfaceID: ExerciseSurfaceID,
    in presentationState: ExercisePresentationState
) -> ExerciseAnswerRouteIgnoreReason? {
    guard let surfaceState = presentationState.surfaceState(
        for: surfaceID
    ) else {
        return .surfaceUnavailable(surfaceID)
    }
    guard surfaceState.isVisible else {
        return .surfaceHidden(surfaceID)
    }
    guard surfaceState.isAnswerEnabled else {
        return .answerDisabled(surfaceID)
    }
    guard surfaceState.isInteractionEnabled else {
        return .interactionDisabled(surfaceID)
    }
    return nil
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.updateAnswerSurfaceInteractionState()
// 功能说明: 修改前 iOS controller 直接从 surfaceState(...)? 里读交互开关；如果 surfaceState 的 nil/hidden 语义混淆，这里也会跟着被污染。
private func updateAnswerSurfaceInteractionState() {
    guard isViewLoaded else {
        return
    }

    let allowsLiveAnswerInteraction = !trainerDisplayState.isPositionPromptMode
        || currentPositionPromptOverlayPhase == .neutralWhite
    let fretboardInteractionEnabled = exercisePresentationState.surfaceState(
        for: .fretboard
    )?.isInteractionEnabled ?? false
    let naturalNoteStripInteractionEnabled = exercisePresentationState.surfaceState(
        for: .naturalNoteStrip
    )?.isInteractionEnabled ?? false

    fretboardView.isUserInteractionEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.isUserInteractionEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
}
```

- 修改后：router 先查 `containsSurface` 再读 `effectiveSurfaceState`，把“未投影”和“已投影但不可见/不可答/不可交互”重新分开；双平台 controller 则统一消费 `effectiveSurfaceState`，明确自己只关心当前有效交互态。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
// 函数名: ExerciseAnswerRouter.validateAnswerSurface(_:in:)
// 功能说明: 修改后 answer router 先用 containsSurface 判断结构缺席，再用 effectiveSurfaceState 判断可见性、答题能力和交互能力。
private static func validateAnswerSurface(
    _ surfaceID: ExerciseSurfaceID,
    in presentationState: ExercisePresentationState
) -> ExerciseAnswerRouteIgnoreReason? {
    guard presentationState.containsSurface(surfaceID) else {
        return .surfaceUnavailable(surfaceID)
    }

    let surfaceState = presentationState.effectiveSurfaceState(for: surfaceID)
    guard surfaceState.isVisible else {
        return .surfaceHidden(surfaceID)
    }
    guard surfaceState.isAnswerEnabled else {
        return .answerDisabled(surfaceID)
    }
    guard surfaceState.isInteractionEnabled else {
        return .interactionDisabled(surfaceID)
    }
    return nil
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: iOSViewController.updateAnswerSurfaceInteractionState()
// 功能说明: 修改后 iOS controller 明确只消费 effective state，不再依赖 nil 代表结构缺席的旧偶然语义。
private func updateAnswerSurfaceInteractionState() {
    guard isViewLoaded else {
        return
    }

    let allowsLiveAnswerInteraction = !trainerDisplayState.isPositionPromptMode
        || currentPositionPromptOverlayPhase == .neutralWhite
    let fretboardInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .fretboard)
        .isInteractionEnabled
    let naturalNoteStripInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .naturalNoteStrip)
        .isInteractionEnabled

    fretboardView.isUserInteractionEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.isUserInteractionEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名: macOSViewController.updateAnswerSurfaceInteractionState()
// 功能说明: 修改后 macOS controller 与 iOS 保持同一套 effective state 消费边界，避免平台间再次出现 nil/hidden 语义漂移。
private func updateAnswerSurfaceInteractionState() {
    guard isViewLoaded else {
        return
    }

    let allowsLiveAnswerInteraction = !trainerDisplayState.isPositionPromptMode
        || currentPositionPromptOverlayPhase == .neutralWhite
    let fretboardInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .fretboard)
        .isInteractionEnabled
    let naturalNoteStripInteractionEnabled = exercisePresentationState
        .effectiveSurfaceState(for: .naturalNoteStrip)
        .isInteractionEnabled

    fretboardView.areRawEventsEnabled = fretboardInteractionEnabled
        && allowsLiveAnswerInteraction
    naturalNoteStripView.areButtonsEnabled = naturalNoteStripInteractionEnabled
        && allowsLiveAnswerInteraction
}
```

## 5. `ExerciseCompositionValidation.swift`：把旧断言迁移到新语义，并新增根因回归夹具

- 修改前：validation 里仍然把 `surfaceState(...) != nil` 当成 membership 判断；这正是这次 fatal error 的直接触发点。与此同时，回归清单里也还没有显式冻结 `absent != hidden`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures(), manualChecklist(for:), validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs(), validateSharedSurfaceStateDefaultsFollowSurfaceRoles()
// 功能说明: 修改前 validation 仍在用 surfaceState(...) != nil 推断“有没有混入某个 surface”，没有专门冻结 absent / hidden 边界的 fixture。
ExerciseCompositionValidationFixture(
    name: "shared_surface_state_defaults_follow_surface_roles",
    validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
),
ExerciseCompositionValidationFixture(
    name: "shared_layout_preferences_coexist_with_legacy_page_state",
    validate: validateSharedLayoutPreferencesCoexistWithLegacyPageState
)

var checklist = [
    "确认 `Collapsible` accessory 收起时，隐藏的 accessory 不可见也不可交互；重新展开后恢复到原来的 surface。",
    "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
]

if sideBySideTargetPromptPresentation.surfaceState(
    for: .naturalNoteStrip
) != nil {
    issues.append(
        issue(
            fixtureName,
            "targetPrompt -> fretboard 的 sideBySide 组合在阶段 0 不应混入 natural note strip surface。"
        )
    )
}

guard let defaultFretboardState = presentationState.surfaceState(
    for: .fretboard
) else {
    return issues
}

if presentationState.surfaceState(for: .staff) != nil {
    issues.append(
        issue(
            fixtureName,
            "presentation state 不应为不在 scene 中的 surface 凭空生成状态。"
        )
    )
}
```

- 修改后：fixture 注册新增 `surface_membership_distinguishes_absent_and_hidden_states`；旧的 `surfaceState != nil` 断言全部迁移到 `containsSurface / projectedSurfaceState / effectiveSurfaceState`；同时补上手工回归项和 router 的 `surfaceUnavailable` 回归用例。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.makeFixtures(), manualChecklist(for:)
// 功能说明: 修改后 validation 入口显式新增 absent / hidden 回归夹具，并把这条边界同步写进手工检查清单。
ExerciseCompositionValidationFixture(
    name: "shared_surface_state_defaults_follow_surface_roles",
    validate: validateSharedSurfaceStateDefaultsFollowSurfaceRoles
),
ExerciseCompositionValidationFixture(
    name: "surface_membership_distinguishes_absent_and_hidden_states",
    validate: validateSurfaceMembershipDistinguishesAbsentAndHiddenStates
),
ExerciseCompositionValidationFixture(
    name: "shared_layout_preferences_coexist_with_legacy_page_state",
    validate: validateSharedLayoutPreferencesCoexistWithLegacyPageState
)

var checklist = [
    "确认 `Collapsible` accessory 收起时，隐藏的 accessory 不可见也不可交互；重新展开后恢复到原来的 surface。",
    "确认 `single/sequence + Side` 未投影 `natural note strip` 时，scene membership 仍为 absent，而 renderer/controller/router 只把它当作有效 `.hidden`，不会误判为混入布局。",
    "确认 `vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 后该滑块消失，切回后沿用上次值。"
]
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateSharedSurfaceStateDefaultsFollowSurfaceRoles(), validateSurfaceMembershipDistinguishesAbsentAndHiddenStates()
// 功能说明: 修改后 validation 明确分别校验结构 membership、projected state 和 effective state，冻结 absent != hidden 的共享边界。
guard let defaultFretboardState = presentationState.projectedSurfaceState(
    for: .fretboard
) else {
    return issues
}

if presentationState.containsSurface(.staff) {
    issues.append(
        issue(
            fixtureName,
            "presentation state 不应把不在 scene 中的 surface 误报为结构成员。"
        )
    )
}
if presentationState.projectedSurfaceState(for: .staff) != nil {
    issues.append(
        issue(
            fixtureName,
            "presentation state 不应为不在 scene 中的 surface 凭空生成状态。"
        )
    )
}
if presentationState.effectiveSurfaceState(for: .staff) != .hidden {
    issues.append(
        issue(
            fixtureName,
            "presentation state 应把不在 scene 中的 surface 统一收口为 hidden 的 effective state。"
        )
    )
}

static func validateSurfaceMembershipDistinguishesAbsentAndHiddenStates()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "surface_membership_distinguishes_absent_and_hidden_states"
    var issues: [ExerciseCompositionValidationIssue] = []

    let targetPromptSideBySidePresentation = ExerciseCompositionPolicy
        .makePresentation(
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
    if targetPromptSideBySidePresentation.containsSurface(.naturalNoteStrip) {
        issues.append(
            issue(
                fixtureName,
                "targetPrompt -> fretboard 的 sideBySide 组合不应把 natural note strip 记为 scene 成员。"
            )
        )
    }
    if targetPromptSideBySidePresentation.projectedSurfaceState(
        for: .naturalNoteStrip
    ) != nil {
        issues.append(
            issue(
                fixtureName,
                "targetPrompt -> fretboard 的 sideBySide 组合不应为缺席的 natural note strip 暴露 projected state。"
            )
        )
    }
    if targetPromptSideBySidePresentation.effectiveSurfaceState(
        for: .naturalNoteStrip
    ) != .hidden {
        issues.append(
            issue(
                fixtureName,
                "targetPrompt -> fretboard 的 sideBySide 组合应把缺席的 natural note strip 收口为 hidden effective state。"
            )
        )
    }

    // ... staff -> fretboard sideBySide、fretboard -> naturalNoteStrip sideBySide / stacked 的边界冻结逻辑省略 ...
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
// 功能说明: 修改后新增 answer router 回归用例，保证“未投影的 strip 事件”仍然返回 surfaceUnavailable，而不会被 effective hidden 吞掉。
let absentStripEvent = ExerciseAnswerEvent.pitchClass(
    .c,
    from: .naturalNoteStrip
)
if ExerciseAnswerRouter.route(
    absentStripEvent,
    presentationState: stackedSinglePresentation,
    trainerDisplayState: singleTrainerDisplayState,
    fretboardConfiguration: fretboardConfiguration
) != .ignored(.surfaceUnavailable(.naturalNoteStrip)) {
    issues.append(
        issue(
            fixtureName,
            "未投影的 natural note strip 事件应继续被 answer router 判定为 surfaceUnavailable，而不是退化成 hidden/disabled。"
        )
    )
}
```

## 6. 验证记录

- `ReadLints`：本次改动涉及文件未发现新增 lint 错误
- 构建验证：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`：通过
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build`：通过
- 运行验证：
  - iOS Simulator 实际启动通过，日志中 `ExerciseCompositionValidation][iOS] automated=PASS fixtures=20`
  - iOS 启动日志确认新增夹具 `surface_membership_distinguishes_absent_and_hidden_states` 已执行并通过
  - macOS 启动链路尝试执行过，但本次在更早的 `StaffValidation` 阶段发生无关崩溃，因此没有拿到 macOS 版 `ExerciseCompositionValidation` 的启动日志；这不影响本次 shared / iOS 回归结果

## 7. 本次根因修复的最终收口

- 结构真相：统一通过 `containsSurface(_:)` 判断
- 投影状态：统一通过 `projectedSurfaceState(for:)` 判断
- UI / 交互闭世界状态：统一通过 `effectiveSurfaceState(for:)` 判断
- 状态表存储：只存 `scene tree` 中真实投影出的 surface
- validation / router / controller：不再依赖 `surfaceState(for:)` 的旧 `nil` 偶然语义

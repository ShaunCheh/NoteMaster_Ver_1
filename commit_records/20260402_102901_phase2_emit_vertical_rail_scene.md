# 20260402_102901_phase2_emit_vertical_rail_scene

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260402_102901`
- 记录范围：实施 `右侧音名条布局` 计划的阶段 `2`，只把“什么场景应该发出右侧 `verticalRail` 语义”固化到 shared `ExerciseCompositionPolicy` / `ExerciseSceneValidator` / `ExerciseCompositionValidation`，不进入 renderer 分宽和 `NaturalNoteStripView` 竖排实现
- 修改目标：
  - 让 `fretboardToNaturalNoteStrip + sideBySide` 在 shared scene 上正式投影为“左 `fretboard`、右 `naturalNoteStrip verticalRail`”
  - 保持 `targetPromptToFretboard + sideBySide`、`staffToFretboard + sideBySide` 继续走普通双 `weighted` 路径
  - 在 validator 层补上 `verticalRail` 只能出现在 `horizontal split` 里的共享约束
  - 更新 shared validation，把阶段 `2` 的 rail 语义和旧路径边界一起冻结下来
- 修改统计：`3 files changed, 439 insertions(+), 15 deletions(-)`
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. `ExerciseCompositionPolicy.swift`：`sideBySide` 从统一双栏投影升级为“按 compositionPreset 分流”

- 修改前：`makeMainSceneNode(...)` 在 `layoutPreset == .sideBySide` 时，一律直接返回两个默认 `surface` child 的 `horizontal split`。这意味着 `fretboardToNaturalNoteStrip + sideBySide` 虽然左右布局已经存在，但 shared policy 还不会主动发出 `verticalRail + fitContent` 语义。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: makeMainSceneNode(from:preferences:)
// 功能说明: 修改前 sideBySide 不区分 compositionPreset，所有双栏组合都走同一个默认 horizontal split。
private static func makeMainSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    switch resolvedMainLayoutPreset(for: preferences) {
    case .stacked:
        return .makeSplit(
            axis: .vertical,
            children: [
                makeVerticalSceneChild(for: sceneSurfaces.prompt),
                makeVerticalSceneChild(for: sceneSurfaces.answer)
            ]
        )
    case .sideBySide:
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(node: .surface(sceneSurfaces.prompt)),
                ExerciseSceneSplitChild(node: .surface(sceneSurfaces.answer))
            ]
        )
    case .singleSurface:
        return .surface(sceneSurfaces.prompt)
    case .threePane, .overlay, .collapsibleAccessory:
        return .makeSplit(
            axis: .vertical,
            children: [
                makeVerticalSceneChild(for: sceneSurfaces.prompt),
                makeVerticalSceneChild(for: sceneSurfaces.answer)
            ]
        )
    }
}
```

- 修改后：`sideBySide` 改为委托给 `makeSideBySideSceneNode(...)`。这里正式把 rail 语义收口到 shared policy：
  - `fretboardToNaturalNoteStrip`：左侧 `fretboard` 保持 `.weighted(1)`，右侧 `naturalNoteStrip` 改为 `.fitContent`，同时打上 `.verticalRail`
  - `staffToFretboard`、`targetPromptToFretboard`：继续保持双 `weighted`
  - 不修改 `stacked` / accessory 路径

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名: makeMainSceneNode(from:preferences:), makeSideBySideSceneNode(from:preferences:)
// 功能说明: 修改后 sideBySide 的 shared scene 投影开始区分 compositionPreset；只有 fretboardToNaturalNoteStrip 会发出 verticalRail + fitContent。
private static func makeMainSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    switch resolvedMainLayoutPreset(for: preferences) {
    case .stacked:
        return .makeSplit(
            axis: .vertical,
            children: [
                makeVerticalSceneChild(for: sceneSurfaces.prompt),
                makeVerticalSceneChild(for: sceneSurfaces.answer)
            ]
        )
    case .sideBySide:
        return makeSideBySideSceneNode(
            from: sceneSurfaces,
            preferences: preferences
        )
    case .singleSurface:
        return .surface(sceneSurfaces.prompt)
    case .threePane, .overlay, .collapsibleAccessory:
        return .makeSplit(
            axis: .vertical,
            children: [
                makeVerticalSceneChild(for: sceneSurfaces.prompt),
                makeVerticalSceneChild(for: sceneSurfaces.answer)
            ]
        )
    }
}

private static func makeSideBySideSceneNode(
    from sceneSurfaces: (prompt: ExerciseSurfaceNode, answer: ExerciseSurfaceNode),
    preferences: ExerciseLayoutPreferences
) -> ExerciseSceneNode {
    switch preferences.compositionPreset {
    case .fretboardToNaturalNoteStrip:
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.prompt),
                    mainAxisSizing: .weighted(1)
                ),
                ExerciseSceneSplitChild(
                    node: .surface(
                        sceneSurfaces.answer.withPresentationStyle(
                            .verticalRail
                        )
                    ),
                    mainAxisSizing: .fitContent
                )
            ]
        )
    case .staffToFretboard, .targetPromptToFretboard:
        return .makeSplit(
            axis: .horizontal,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.prompt),
                    mainAxisSizing: .weighted(1)
                ),
                ExerciseSceneSplitChild(
                    node: .surface(sceneSurfaces.answer),
                    mainAxisSizing: .weighted(1)
                )
            ]
        )
    case .fretboardSelfAnswer:
        return .surface(sceneSurfaces.prompt)
    }
}
```

## 2. `ExerciseSceneValidator.swift`：新增 `verticalRail` 的 shared 约束

- 修改前：`ExerciseSceneValidator.validate(...)` 只做两类事情：
  - 检查 logical surface 重复
  - 检查是否至少存在 prompt / answer surface

  它还不会约束 `presentationStyle == .verticalRail` 的 surface 必须出现在什么语境里，因此 shared 层无法阻止“把 vertical rail strip 放进 stacked scene”这种语义错误。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: validate(_:)
// 功能说明: 修改前 validator 只校验 duplicate / missing prompt / missing answer，不校验 presentationStyle 语境。
enum ExerciseSceneValidationIssue: Equatable, Sendable {
    case duplicateSurfaceID(ExerciseSurfaceID)
    case missingPromptSurface
    case missingAnswerSurface
}

enum ExerciseSceneValidator {
    static func validate(
        _ scene: ExerciseScene
    ) -> [ExerciseSceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [ExerciseSceneValidationIssue] = []

        for surfaceID in ExerciseSurfaceID.allCases {
            let duplicateCount = surfaceNodes.filter { $0.id == surfaceID }.count
            if duplicateCount > 1 {
                issues.append(.duplicateSurfaceID(surfaceID))
            }
        }

        if !surfaceNodes.contains(where: \.isPromptSurface) {
            issues.append(.missingPromptSurface)
        }
        if !surfaceNodes.contains(where: \.isAnswerSurface) {
            issues.append(.missingAnswerSurface)
        }

        return issues
    }
}
```

- 修改后：新增 `verticalRailRequiresHorizontalSplit(ExerciseSurfaceID)`，并通过 `validatePresentationStyles(...)` 递归扫描 scene tree：
  - 如果某个 `surface.presentationStyle == .verticalRail`
  - 且它不在 `horizontal split` 语境里
  - 就返回 `.verticalRailRequiresHorizontalSplit(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: validate(_:), validatePresentationStyles(in:withinHorizontalSplit:)
// 功能说明: 修改后 validator 会显式约束 verticalRail 只能出现在 horizontal split 语境下。
enum ExerciseSceneValidationIssue: Equatable, Sendable {
    case duplicateSurfaceID(ExerciseSurfaceID)
    case missingPromptSurface
    case missingAnswerSurface
    case verticalRailRequiresHorizontalSplit(ExerciseSurfaceID)
}

enum ExerciseSceneValidator {
    static func validate(
        _ scene: ExerciseScene
    ) -> [ExerciseSceneValidationIssue] {
        let surfaceNodes = scene.surfaceNodes
        var issues: [ExerciseSceneValidationIssue] = []

        for surfaceID in ExerciseSurfaceID.allCases {
            let duplicateCount = surfaceNodes.filter { $0.id == surfaceID }.count
            if duplicateCount > 1 {
                issues.append(.duplicateSurfaceID(surfaceID))
            }
        }

        if !surfaceNodes.contains(where: \.isPromptSurface) {
            issues.append(.missingPromptSurface)
        }
        if !surfaceNodes.contains(where: \.isAnswerSurface) {
            issues.append(.missingAnswerSurface)
        }

        issues.append(
            contentsOf: validatePresentationStyles(
                in: scene.root,
                withinHorizontalSplit: false
            )
        )

        return issues
    }

    private static func validatePresentationStyles(
        in node: ExerciseSceneNode,
        withinHorizontalSplit: Bool
    ) -> [ExerciseSceneValidationIssue] {
        switch node {
        case let .surface(surface):
            guard
                surface.presentationStyle == .verticalRail,
                !withinHorizontalSplit
            else {
                return []
            }
            return [.verticalRailRequiresHorizontalSplit(surface.id)]
        case let .split(axis, children):
            let nextWithinHorizontalSplit = withinHorizontalSplit
                || axis == .horizontal
            return children.flatMap {
                validatePresentationStyles(
                    in: $0.node,
                    withinHorizontalSplit: nextWithinHorizontalSplit
                )
            }
        case let .overlay(base, floating):
            return validatePresentationStyles(
                in: base,
                withinHorizontalSplit: withinHorizontalSplit
            ) + floating.flatMap {
                validatePresentationStyles(
                    in: $0,
                    withinHorizontalSplit: withinHorizontalSplit
                )
            }
        case let .collapsible(main, accessory, _):
            return validatePresentationStyles(
                in: main,
                withinHorizontalSplit: withinHorizontalSplit
            ) + validatePresentationStyles(
                in: accessory,
                withinHorizontalSplit: withinHorizontalSplit
            )
        }
    }
}
```

## 3. `ExerciseCompositionValidation.swift`：把阶段 2 的 rail 语义冻结到 shared validation

- 修改前：validation 已有阶段 `0/1` 的基线，但在 `positionPrompt + sideBySide` 场景里，仍然默认它保持“普通双 weighted sideBySide”；同时也没有一条 fixture 专门验证 `verticalRail` 只能位于 `horizontal split`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures(), validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs(), validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()
// 功能说明: 修改前 validation 还没有显式注册 verticalRail validator 夹具，也还没把 positionPrompt sideBySide 升级为 rail 语义。
ExerciseCompositionValidationFixture(
    name: "scene_validator_rejects_duplicate_logical_surface_ids",
    validate: validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs
),
ExerciseCompositionValidationFixture(
    name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
    validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
),

if children.contains(where: { !$0.mainAxisSizing.isWeighted }) {
    issues.append(
        issue(
            fixtureName,
            "\(sceneDescription) 在阶段 0 仍应保持 sideBySide child 的默认 weighted 主轴尺寸语义。"
        )
    )
}

// 旧版还没有明确校验：
// - positionPrompt + sideBySide 的右侧 strip 是否已经变成 verticalRail
// - 右侧 strip 是否已经改成 fitContent
// - verticalRail 是否被错误放进 stacked scene
```

- 修改后：这一轮 validation 做了三类升级：
  - 在 fixtures 列表里注册 `scene_validator_restricts_vertical_rail_to_horizontal_split`
  - 更新 `validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()`，让 `positionPrompt + sideBySide` 从“普通双 weighted”升级为“左 weighted、右 fitContent、右侧 verticalRail”
  - 扩充 `validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()`，把 rail scene 的 shape、sizing、presentationStyle、legacyPage 投影边界一起锁住

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures(), validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()
// 功能说明: 修改后 fixtures 会执行 verticalRail 约束夹具，并把阶段 2 的 rail 语义写进 sideBySide 基线。
ExerciseCompositionValidationFixture(
    name: "scene_validator_rejects_duplicate_logical_surface_ids",
    validate: validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs
),
ExerciseCompositionValidationFixture(
    name: "scene_validator_restricts_vertical_rail_to_horizontal_split",
    validate: validateSceneValidatorRestrictsVerticalRailToHorizontalSplit
),
ExerciseCompositionValidationFixture(
    name: "shared_answer_contracts_default_position_prompt_to_same_pitch_class",
    validate: validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass
),

switch sideBySidePositionPromptPresentation.scene.root {
case let .split(axis, children):
    if axis != .horizontal
        || children.count != 2
        || children[0].mainAxisSizing != .weighted(1)
        || children[1].mainAxisSizing != .fitContent {
        issues.append(
            issue(
                fixtureName,
                "positionPrompt 的 sideBySide 组合在阶段 2 应升级为左 fretboard weighted(1)、右 strip fitContent 的主轴尺寸语义。"
            )
        )
    }
    guard
        case let .surface(promptSurface) = children[0].node,
        case let .surface(stripSurface) = children[1].node
    else {
        issues.append(
            issue(
                fixtureName,
                "positionPrompt 的 sideBySide 组合在阶段 2 应继续由两个 surface child 组成。"
            )
        )
        break
    }
    if promptSurface.presentationStyle != .standard
        || stripSurface.presentationStyle != .verticalRail {
        issues.append(
            issue(
                fixtureName,
                "positionPrompt 的 sideBySide 组合在阶段 2 应保持左侧 standard fretboard、右侧 verticalRail strip。"
            )
        )
    }
default:
    break
}
if !sideBySidePositionPromptPresentation.scene
    .hasMixedMainAxisSizing(along: .horizontal) {
    issues.append(
        issue(
            fixtureName,
            "positionPrompt 的 sideBySide 组合在阶段 2 应触发 horizontal mixed main-axis sizing 语义。"
        )
    )
}
if !sideBySidePositionPromptPresentation.scene.requiresViewportPinnedHeight {
    issues.append(
        issue(
            fixtureName,
            "positionPrompt 的 sideBySide 组合在阶段 2 应通过 shared helper 请求 viewport pin 高度。"
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes(), validateSceneValidatorRestrictsVerticalRailToHorizontalSplit()
// 功能说明: 修改后新增 rail 语义的 policy 夹具和 validator 夹具，锁住新的 scene 投影边界。
let sideBySidePositionPromptPresentation = ExerciseCompositionPolicy
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
                layoutPreset: .sideBySide
            )
        )
    )
if !ExerciseSceneValidator.validate(
    sideBySidePositionPromptPresentation.scene
).isEmpty {
    issues.append(
        issue(
            fixtureName,
            "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应生成合法 scene。"
        )
    )
}
switch sideBySidePositionPromptPresentation.scene.root {
case let .split(axis, children):
    if axis != .horizontal {
        issues.append(
            issue(
                fixtureName,
                "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应投影到 horizontal split。"
            )
        )
    }
    if children.count != 2
        || children[0].mainAxisSizing != .weighted(1)
        || children[1].mainAxisSizing != .fitContent {
        issues.append(
            issue(
                fixtureName,
                "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应保持左 weighted(1)、右 fitContent 的主轴尺寸语义。"
            )
        )
    }
default:
    issues.append(
        issue(
            fixtureName,
            "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应生成 split scene。"
        )
    )
}

static func validateSceneValidatorRestrictsVerticalRailToHorizontalSplit()
    -> [ExerciseCompositionValidationIssue] {
    let invalidVerticalRailStackedScene = ExerciseScene(
        root: .makeSplit(
            axis: .vertical,
            children: [
                ExerciseSceneSplitChild(
                    node: .surface(.fretboardPrompt),
                    mainAxisSizing: .weighted(1)
                ),
                ExerciseSceneSplitChild(
                    node: .surface(
                        .naturalNoteStripAnswer.withPresentationStyle(
                            .verticalRail
                        )
                    ),
                    mainAxisSizing: .fitContent
                )
            ]
        )
    )
    let invalidIssues = ExerciseSceneValidator.validate(
        invalidVerticalRailStackedScene
    )
    if !invalidIssues.contains(
        .verticalRailRequiresHorizontalSplit(.naturalNoteStrip)
    ) {
        issues.append(
            issue(
                fixtureName,
                "validator 应拒绝把 verticalRail strip 放进非 horizontal split 语境。"
            )
        )
    }
}
```

## 验证结果

- `ReadLints` 检查以下文件：无新增 lint
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 构建验证：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'platform=macOS' build`：通过
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -destination 'generic/platform=iOS Simulator' build`：通过

## 阶段 2 完成状态

- 已完成：
  - `ExerciseCompositionPolicy` 正式发出 `verticalRail + fitContent` 的 sideBySide rail scene
  - `ExerciseSceneValidator` 增加 `verticalRail` 语境约束
  - shared validation 更新到阶段 `2` 预期
- 尚未开始：
  - horizontal split 真正按 `fitContent / fixed / weighted` 分宽
  - `NaturalNoteStripView` 的竖排 UI 实现

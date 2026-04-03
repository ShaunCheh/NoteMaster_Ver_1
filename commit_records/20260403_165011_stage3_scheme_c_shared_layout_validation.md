# 20260403_165011_stage3_scheme_c_shared_layout_validation

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_165011`
- 记录范围：只记录方案 C 的阶段3代码改动，即把 shared placement 的关键几何语义冻结进 automated validation；不记录阶段4+ 的平台渲染切换
- 当前 `git status` 中还包含计划文件 `/.cursor/plans/rail_placement_phases_c_51a1bd19.plan.md`；该文件不属于本记录范围，本记录只说明本轮实际代码改动
- 本记录不放原始 `git diff`，只按真实代码状态说明“修改前 / 修改后”
- 本轮代码改动文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本轮相关代码文件状态（`git status --short`）：
- `M NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本轮 `git diff --stat`（仅上述代码文件）：`1 file changed, 395 insertions(+), 10 deletions(-)`

## 1. 本轮目标

- 阶段3不改 `iOS/macOS NaturalNoteStripView`，也不改 shared builder。
- 目标是把阶段2已经算出来的 `naturalNoteStripRailLayout` 真正冻结成 shared 不变量，让方案 C 的核心价值落到 automated validation，而不是只靠肉眼看 UI。
- 本轮只改 `ExerciseCompositionValidation.swift`，不扩散到 settings 行为；`SettingsNavigationValidation.swift` 现有“不要新增 Rail / Strip Size / Strip Alignment 入口”的 gate 保持不变。

## 2. 修改一：在 fixture 注册区接入阶段3的 placement 几何校验

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: ExerciseCompositionValidationRunner.makeFixtures()
// 修改前说明:
// 1. fixture 注册区只覆盖到阶段2。
// 2. 还没有专门冻结“双列错位几何关系”和“shared contentSize 语义”的 fixture。
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_layout_context_freezes_default_geometry_tokens",
    validate:
        validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_layout_builder_exposes_shared_layout_output",
    validate:
        validateNaturalNoteStripStageCLayoutBuilderExposesSharedLayoutOutput
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
)
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: ExerciseCompositionValidationRunner.makeFixtures()
// 修改后说明:
// 1. 在阶段0/1/2 fixture 之后继续注册阶段3 fixture。
// 2. 从这个阶段开始，rail 的列归属、中点关系与 contentSize 语义都会在启动 validation 中自动执行。
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_layout_context_freezes_default_geometry_tokens",
    validate:
        validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_layout_builder_exposes_shared_layout_output",
    validate:
        validateNaturalNoteStripStageCLayoutBuilderExposesSharedLayoutOutput
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_staggered_two_column_layout_matches_pitchclass_topology",
    validate:
        validateNaturalNoteStripStaggeredTwoColumnLayoutMatchesPitchclassTopology
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_shared_layout_content_size_matches_intrinsic_semantics",
    validate:
        validateNaturalNoteStripSharedLayoutContentSizeMatchesIntrinsicSemantics
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
)
```

## 3. 修改二：扩展现有 fixture，把 contract / orthogonal 校验升级成 contract + placement 摘要

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// - validateSideRailContractRemainsOrthogonalToFretboardHeightContract()
// 修改前说明:
// 1. 这两个 fixture 主要只校验 rail contract 与 fretboard height contract。
// 2. 阶段2虽然已经有 shared layout 输出，但这里还没有把它纳入“不回退”断言。
switch railPresentation.naturalNoteStripRailContract {
case let .some(railContract):
    if railContract.appliesToSurface != .naturalNoteStrip {
        issues.append(
            issue(
                fixtureName,
                "阶段 1 的 rail contract 应继续显式指向 natural note strip surface。"
            )
        )
    }

    if railContract.slotModel != .chromatic12Preserved
        || railContract.slotModel.slotCount != PitchClass.allCases.count {
        issues.append(
            issue(
                fixtureName,
                "阶段 1 的 rail contract 应继续冻结为保留 12 个 PitchClass 槽位的语义。"
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
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// - validateSideRailContractRemainsOrthogonalToFretboardHeightContract()
// 修改后说明:
// 1. 现有 fixture 不再只看 contract，还会同时检查 shared rail layout 摘要是否存在、是否保持 12 个 placements。
// 2. orthogonal fixture 现在还会验证 shared layout 纯粹由 rail contract / layoutContext 决定，
//    不受 fretboardLayoutContract 影响。
switch railPresentation.naturalNoteStripRailLayout {
case let .some(layout):
    if layout.context.appliesToSurface != .naturalNoteStrip
        || layout.context.slotModel != .chromatic12Preserved
        || layout.placements.count != PitchClass.allCases.count
        || layout.placements.map(\.pitchClass) != PitchClass.allCases {
        issues.append(
            issue(
                fixtureName,
                "阶段 3 的 rail contract 应继续稳定投影为 shared rail layout 摘要：12 个 chromatic placements 与 natural note strip surface 作用域都不能丢。"
            )
        )
    }

    if layout.contentSize.width <= 0 || layout.contentSize.height <= 0 {
        issues.append(
            issue(
                fixtureName,
                "阶段 3 的 rail contract 应继续投影出正值 contentSize 的 shared rail layout 摘要，而不是零尺寸布局。"
            )
        )
    }
case .none:
    issues.append(
        issue(
            fixtureName,
            "sideBySide 的 fretboard -> natural note strip scene 在阶段 3 应同时暴露 active shared rail layout 摘要，而不是 nil。"
        )
    )
}

if railPresentation.scene.naturalNoteStripRailLayout
    != railPresentation.naturalNoteStripRailLayout {
    issues.append(
        issue(
            fixtureName,
            "阶段 3 的 ExerciseScene 应继续把 shared rail layout 摘要原样透传给 presentation 层。"
        )
    )
}

let expectedPureSharedLayout =
    ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
        .defaultLayoutContext.resolvedLayout
if sideRailPresentation.naturalNoteStripRailLayout
    != expectedPureSharedLayout {
    issues.append(
        issue(
            fixtureName,
            "sideBySide 的 shared rail layout 应继续只由 rail contract / layoutContext 决定，而不依赖 fretboardLayoutContract。"
        )
    )
}
if sideRailPresentation.scene.naturalNoteStripRailLayout
    != expectedPureSharedLayout {
    issues.append(
        issue(
            fixtureName,
            "ExerciseScene 应继续把由默认 rail contract 纯计算出来的 shared rail layout 原样透传给 presentation 层。"
        )
    )
}

// 非 rail 场景现在也同步校验“不应误暴露 shared rail layout”。
if stackedRailPresentation.naturalNoteStripRailContract != nil
    || stackedRailPresentation.scene.naturalNoteStripRailContract != nil
    || stackedRailPresentation.naturalNoteStripRailLayout != nil
    || stackedRailPresentation.scene.naturalNoteStripRailLayout != nil {
    issues.append(
        issue(
            fixtureName,
            "stacked 的 fretboard -> natural note strip 场景不应误暴露 right rail contract / shared rail layout。"
        )
    )
}
```

## 4. 修改三：新增“拓扑几何”和“contentSize 语义”两个阶段3 fixture

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - validateNaturalNoteStripStaggeredTwoColumnLayoutMatchesPitchclassTopology()（无）
// - validateNaturalNoteStripSharedLayoutContentSizeMatchesIntrinsicSemantics()（无）
// 修改前说明:
// 1. shared rail layout 虽然已经能算出 placements 与 contentSize，
//    但还没有 automated validation 去冻结左右列位置、自然音主行步长、中点关系与最终 contentSize。
// 2. 也还没有 validation 去证明 shared width 已经不再依赖过渡字段 crossAxisWidthScale。
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - validateNaturalNoteStripStaggeredTwoColumnLayoutMatchesPitchclassTopology()
// - validateNaturalNoteStripSharedLayoutContentSizeMatchesIntrinsicSemantics()
// 修改后说明:
// 1. 第一个 fixture 冻结双列错位拓扑：自然音右列、升号左列、升号位于相邻自然音中点、
//    自然音主行中心按 naturalRowStride 连续递增。
// 2. 第二个 fixture 冻结 shared contentSize 语义：宽度来自两列按钮 + 列间距 + insets，
//    高度来自 7 个自然音主行，而不是旧的 12 槽位单列公式。
static func validateNaturalNoteStripStaggeredTwoColumnLayoutMatchesPitchclassTopology()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "natural_note_strip_staggered_two_column_layout_matches_pitchclass_topology"
    var issues: [ExerciseCompositionValidationIssue] = []
    let tolerance = 0.0001

    func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

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

    guard let layout = sideRailPresentation.naturalNoteStripRailLayout else {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 3 应能从 side rail presentation 读到 active shared rail layout。"
            )
        )
        return issues
    }

    let geometry = layout.context.geometry
    let expectedAccidentalX = geometry.contentInsets.leading
    let expectedNaturalX = geometry.contentInsets.leading
        + geometry.resolvedButtonExtent
        + geometry.resolvedColumnGap

    let naturalCenters = PitchClass.naturalCasesInOrder.compactMap {
        pitchClass -> Double? in
        guard let currentPlacement = layout.placements.first(where: {
            $0.pitchClass == pitchClass
        }) else {
            return nil
        }

        if !approximatelyEqual(
            Double(currentPlacement.frame.minX),
            expectedNaturalX
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 应继续把自然音 \(pitchClass.displayText()) 放在右列固定 x 位置。"
                )
            )
        }

        return Double(currentPlacement.frame.midY)
    }

    let hasBrokenNaturalStride = zip(
        naturalCenters,
        naturalCenters.dropFirst()
    ).contains(where: { pair in
        !approximatelyEqual(pair.1 - pair.0, geometry.naturalRowStride)
    })
    if hasBrokenNaturalStride {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 3 应继续让 C-D-E-F-G-A-B 的主行中心按 naturalRowStride 连续递增。"
            )
        )
    }

    for pitchClass in PitchClass.accidentalCasesInOrder {
        guard let currentPlacement = layout.placements.first(where: {
            $0.pitchClass == pitchClass
        }) else {
            continue
        }

        if !approximatelyEqual(
            Double(currentPlacement.frame.minX),
            expectedAccidentalX
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 应继续把 accidental \(pitchClass.displayText()) 放在左列固定 x 位置。"
                )
            )
        }
    }

    return issues
}

static func validateNaturalNoteStripSharedLayoutContentSizeMatchesIntrinsicSemantics()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "natural_note_strip_shared_layout_content_size_matches_intrinsic_semantics"
    var issues: [ExerciseCompositionValidationIssue] = []
    let tolerance = 0.0001

    func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

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

    guard let layout = sideRailPresentation.naturalNoteStripRailLayout else {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 3 应能从 side rail presentation 读到 active shared rail layout。"
            )
        )
        return issues
    }

    let geometry = layout.context.geometry
    let expectedContentWidth = geometry.twoColumnContentWidth
    let expectedContentHeight = geometry.naturalColumnContentHeight(
        rowCount: PitchClass.naturalCasesInOrder.count
    )
    let legacySingleColumnHeight = geometry.columnContentHeight(
        rowCount: layout.context.slotModel.slotCount
    )

    if !approximatelyEqual(
        Double(layout.contentSize.width),
        expectedContentWidth
    ) || !approximatelyEqual(
        Double(layout.contentSize.height),
        expectedContentHeight
    ) {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 3 的 shared rail contentSize 应继续由两列按钮宽度、列间距、7 个自然音主行与内容内边距共同决定。"
            )
        )
    }

    if approximatelyEqual(
        Double(layout.contentSize.height),
        legacySingleColumnHeight
    ) {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 3 的 shared rail contentHeight 不应退回 12 槽位单列公式；它必须继续来自 7 个自然音主行。"
            )
        )
    }

    var widenedScaleContract =
        ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
    widenedScaleContract.crossAxisWidthScale = 99
    let widenedScaleLayout = widenedScaleContract.defaultLayoutContext
        .resolvedLayout
    if widenedScaleLayout != layout {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 3 的 shared rail layout 不应再依赖过渡字段 crossAxisWidthScale；width 必须继续由 shared geometry 自身决定。"
            )
        )
    }

    return issues
}
```

## 5. 验证结果

- `ReadLints` 检查：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`：无 linter 问题
- 构建验证：
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`：`BUILD SUCCEEDED`
- 开发过程中的编译期修正：
- 新增 `naturalCenters` 计算时，`compactMap` 闭包显式写成 `pitchClass -> Double? in`，避免 Swift 无法推断返回类型
- 自然音主行步长校验改为 `contains(where:)`，避免把 `zip(...)` 误写成需要 `Equatable` 的 `contains(_:)`

## 6. 本轮结论

- 阶段3之后，方案 C 的 shared placement 已经不再只是“能算出来”，而是已经被 automated validation 明确锁住。
- 阶段4开始改双端 `NaturalNoteStripView` 时，如果列归属、中点关系、contentSize 或 shared/source-of-truth 再次回退，这一轮新增的 validation 应该会先暴露问题。

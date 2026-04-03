# 20260403_162154_stage1_scheme_c_shared_rail_layout_context

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_162154`
- 记录范围：只记录方案 C 的阶段1代码改动，即补齐 shared rail placement 所需的数据模型、几何 token 与 validation 冻结，不记录阶段2+ 的 placement builder / 双端渲染替换
- 当前 `git status` 中还包含计划文件 `/.cursor/plans/rail_placement_phases_c_51a1bd19.plan.md`；该文件不属于本记录范围，本记录只说明这次刚刚落地的代码改动
- 本记录不放原始 `git diff`，只按真实代码状态说明“修改前 / 修改后”
- 本轮代码改动文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本轮相关代码文件状态（`git status --short`）：
- `M NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `?? NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`

## 1. 本轮目标

- 阶段1不直接实现双列错位按钮的 frame 计算，也不改 `iOS/macOS NaturalNoteStripView`。
- 先把 shared 层补到“已经具备直接产出 placement 所需的类型边界”，避免阶段2继续把几何规则散落在平台 `Style` 和 `stackView` 上。
- 保留现有 `ExerciseNaturalNoteStripRailContract` 作为高层语义入口，但把 placement model、geometry token、title policy 和 derived layout context 提升为 shared 真相来源。

## 2. 修改一：新增 shared rail placement 数据模型与 derived layout context

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数/符号: （无，文件不存在）
// 修改前说明:
// 1. shared 层还没有独立的 rail placement 数据模型文件。
// 2. 阶段0虽然已经冻结了 PitchClass -> 双列错位 topology，但还没有 geometry token、
//    placement model、title display policy、layout context 这些阶段2 builder 必需输入。
// 3. ExerciseScene / ExercisePresentationState 也没有专门暴露 derived rail layout context，
//    后续仍然会被迫回到平台层临时拼装。
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数/符号:
// - ExerciseNaturalNoteStripRailPlacementModel
// - ExerciseNaturalNoteStripRailTitleDisplayPolicy
// - ExerciseNaturalNoteStripRailInsets
// - ExerciseNaturalNoteStripRailGeometry
// - ExerciseNaturalNoteStripRailLayoutContext
// - ExerciseNaturalNoteStripRailPlacement
// - ExerciseNaturalNoteStripRailLayout
// - ExerciseNaturalNoteStripRailContract.defaultLayoutContext
// - ExerciseScene.naturalNoteStripRailLayoutContext
// - ExercisePresentationState.naturalNoteStripRailLayoutContext
// 修改后说明:
// 1. shared 层新增 placement model，明确后续要走 single-column 还是 staggered two-column。
// 2. 把 placement 计算必须知道的几何 token 提升到 shared：
//    contentInsets / columnGap / naturalRowSpacing / buttonExtent。
// 3. 通过 defaultLayoutContext 把 contract、geometry、title policy 和 topology 装配成阶段2可直接消费的 derived 输入。
// 4. ExerciseScene / ExercisePresentationState 都开始统一暴露 naturalNoteStripRailLayoutContext，
//    后续 builder 与 renderer 可以从同一 shared 入口读取。
import CoreGraphics

enum ExerciseNaturalNoteStripRailPlacementModel: Equatable, Sendable {
    case singleColumnChromatic12
    case staggeredNaturalAccidentalTwoColumn
}

enum ExerciseNaturalNoteStripRailTitleDisplayPolicy: Equatable, Sendable {
    case naturalsOnly
    case allPitchClasses
}

struct ExerciseNaturalNoteStripRailInsets: Equatable, Sendable {
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailInsets(
        top: 10,
        leading: 12,
        bottom: 10,
        trailing: 12
    )

    var top: Double
    var leading: Double
    var bottom: Double
    var trailing: Double

    var horizontal: Double {
        leading + trailing
    }

    var vertical: Double {
        top + bottom
    }
}

struct ExerciseNaturalNoteStripRailGeometry: Equatable, Sendable {
    static let defaultColumnGap =
        ExerciseNaturalNoteStripRailInsets.defaultSideBySideAnswerRail.horizontal
    static let defaultNaturalRowSpacing: Double = 0

    var contentInsets: ExerciseNaturalNoteStripRailInsets
    var columnGap: Double
    var naturalRowSpacing: Double
    var buttonExtent: Double

    var resolvedColumnGap: Double {
        max(columnGap, 0)
    }

    var resolvedNaturalRowSpacing: Double {
        max(naturalRowSpacing, 0)
    }

    var resolvedButtonExtent: Double {
        max(buttonExtent, 0)
    }

    var buttonSize: CGSize {
        CGSize(
            width: CGFloat(resolvedButtonExtent),
            height: CGFloat(resolvedButtonExtent)
        )
    }

    // 两列内容宽度先与当前 fitContent(x2) 过渡语义保持一致，
    // 后续阶段2/3再让真正的 shared contentSize 成为最终真相来源。
    var twoColumnContentWidth: Double {
        contentInsets.leading
            + resolvedButtonExtent
            + resolvedColumnGap
            + resolvedButtonExtent
            + contentInsets.trailing
    }

    // 自然音主列高度基于 7 个 natural row 计算，不再从 12 个单列槽位反推。
    func naturalColumnContentHeight(rowCount: Int) -> Double {
        let resolvedRowCount = max(rowCount, 0)
        let gapCount = max(resolvedRowCount - 1, 0)
        return contentInsets.top
            + (resolvedButtonExtent * Double(resolvedRowCount))
            + (resolvedNaturalRowSpacing * Double(gapCount))
            + contentInsets.bottom
    }

    static func defaultStageCSideBySideAnswerRail(
        buttonExtent: Double
    ) -> ExerciseNaturalNoteStripRailGeometry {
        ExerciseNaturalNoteStripRailGeometry(
            contentInsets: .defaultSideBySideAnswerRail,
            columnGap: defaultColumnGap,
            naturalRowSpacing: defaultNaturalRowSpacing,
            buttonExtent: buttonExtent
        )
    }
}

struct ExerciseNaturalNoteStripRailLayoutContext: Equatable, Sendable {
    static let defaultTitleDisplayPolicy:
        ExerciseNaturalNoteStripRailTitleDisplayPolicy = .allPitchClasses

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var placementModel: ExerciseNaturalNoteStripRailPlacementModel
    var titleDisplayPolicy: ExerciseNaturalNoteStripRailTitleDisplayPolicy
    var geometry: ExerciseNaturalNoteStripRailGeometry
    var hostVerticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
    var pitchTopologies: [ExerciseNaturalNoteStripRailPitchTopology]
}

struct ExerciseNaturalNoteStripRailPlacement: Equatable, Sendable {
    var pitchClass: PitchClass
    var topology: ExerciseNaturalNoteStripRailPitchTopology
    var frame: CGRect
    var showsTitle: Bool
}

struct ExerciseNaturalNoteStripRailLayout: Equatable, Sendable {
    var context: ExerciseNaturalNoteStripRailLayoutContext
    var contentSize: CGSize
    var placements: [ExerciseNaturalNoteStripRailPlacement]
}

extension ExerciseNaturalNoteStripRailContract {
    var defaultLayoutContext: ExerciseNaturalNoteStripRailLayoutContext {
        ExerciseNaturalNoteStripRailLayoutContext(
            appliesToSurface: appliesToSurface,
            slotModel: slotModel,
            buttonShape: buttonShape,
            placementModel: .staggeredNaturalAccidentalTwoColumn,
            titleDisplayPolicy:
                ExerciseNaturalNoteStripRailLayoutContext.defaultTitleDisplayPolicy,
            geometry: .defaultStageCSideBySideAnswerRail(
                buttonExtent: buttonExtent
            ),
            hostVerticalAlignment: verticalAlignment,
            pitchTopologies:
                PitchClass.naturalNoteStripStaggeredRailTopologiesInChromaticOrder
        )
    }
}

extension ExerciseScene {
    var naturalNoteStripRailLayoutContext: ExerciseNaturalNoteStripRailLayoutContext?
    {
        naturalNoteStripRailContract?.defaultLayoutContext
    }
}

extension ExercisePresentationState {
    var naturalNoteStripRailLayoutContext: ExerciseNaturalNoteStripRailLayoutContext?
    {
        scene.naturalNoteStripRailLayoutContext
    }
}
```

## 3. 修改二：把阶段1的 shared layout context 几何默认值冻结进 validation

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - ExerciseCompositionValidationRunner.makeFixtures()
// - validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens()（无）
// 修改前说明:
// 1. validation 只冻结到了阶段0 topology，不校验阶段1的 layoutContext / geometry token。
// 2. 也就是说，就算后面有人把 10/12 inset、24 columnGap、title policy、
//    或 side rail 的 scene scope 改坏，shared 层还没有自动化回归能第一时间兜住。
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_topology_freezes_chromatic12_semantics",
    validate: validateNaturalNoteStripStageCTopologyFreezesChromatic12Semantics
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
)
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - ExerciseCompositionValidationRunner.makeFixtures()
// - validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens()
// 修改后说明:
// 1. 新增阶段1 fixture，把 layoutContext 的默认 geometry token、title policy、
//    placement model、scene scope 和 topology 透传关系一起冻结下来。
// 2. 这样阶段2开始实现 builder 时，只要改坏 shared 输入边界，validation 会先报错。
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_topology_freezes_chromatic12_semantics",
    validate: validateNaturalNoteStripStageCTopologyFreezesChromatic12Semantics
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_layout_context_freezes_default_geometry_tokens",
    validate:
        validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
)

static func validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "natural_note_strip_stage_c_layout_context_freezes_default_geometry_tokens"
    var issues: [ExerciseCompositionValidationIssue] = []

    let positionPromptTrainerDisplayState = TrainerDisplayState(
        exerciseMode: .positionPrompt
    )
    let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: positionPromptTrainerDisplayState,
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
    let expectedInsets =
        ExerciseNaturalNoteStripRailInsets.defaultSideBySideAnswerRail
    let expectedGeometry =
        ExerciseNaturalNoteStripRailGeometry.defaultStageCSideBySideAnswerRail(
            buttonExtent:
                ExerciseNaturalNoteStripRailContract.defaultButtonExtent
        )
    let expectedLegacyCompatibleContentWidth =
        (expectedInsets.leading
            + ExerciseNaturalNoteStripRailContract.defaultButtonExtent
            + expectedInsets.trailing)
        * ExerciseNaturalNoteStripRailContract.defaultCrossAxisWidthScale
    let expectedNaturalColumnContentHeight =
        expectedInsets.top
        + (ExerciseNaturalNoteStripRailContract.defaultButtonExtent
            * Double(PitchClass.naturalCasesInOrder.count))
        + expectedInsets.bottom

    switch sideRailPresentation.naturalNoteStripRailLayoutContext {
    case let .some(layoutContext):
        if layoutContext.appliesToSurface != .naturalNoteStrip {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 layoutContext 应继续显式绑定 natural note strip surface。"
                )
            )
        }

        if layoutContext.slotModel != .chromatic12Preserved {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 layoutContext 应继续保留 chromatic12Preserved 的 12 个语义槽位。"
                )
            )
        }

        if layoutContext.buttonShape != .square {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 layoutContext 应继续冻结 square 按钮形状。"
                )
            )
        }

        if layoutContext.placementModel
            != .staggeredNaturalAccidentalTwoColumn {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 layoutContext 应继续明确声明 staggeredNaturalAccidentalTwoColumn placement model。"
                )
            )
        }

        if layoutContext.titleDisplayPolicy != .allPitchClasses {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 layoutContext 应继续冻结 allPitchClasses 标题策略，避免平台层各自决定 accidental 是否显示标题。"
                )
            )
        }

        if layoutContext.hostVerticalAlignment != .centered {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 layoutContext 应继续把 host 对齐语义冻结为 centered。"
                )
            )
        }

        if layoutContext.geometry != expectedGeometry {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 layoutContext 应继续冻结 shared rail geometry token：10/12 inset、24 columnGap、0 naturalRowSpacing、buttonExtent 跟随 contract。"
                )
            )
        }

        if layoutContext.geometry.twoColumnContentWidth
            != expectedLegacyCompatibleContentWidth {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的两列 rail contentWidth 应继续与现有 fitContent(x2) 过渡宽度兼容。"
                )
            )
        }

        if layoutContext.geometry.naturalColumnContentHeight(
            rowCount: PitchClass.naturalCasesInOrder.count
        ) != expectedNaturalColumnContentHeight {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的自然音主列高度应继续由 7 个自然音按钮与 contentInsets 直接决定，保持 0 行距语义。"
                )
            )
        }

        if layoutContext.pitchTopologies
            != PitchClass.naturalNoteStripStaggeredRailTopologiesInChromaticOrder
        {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 layoutContext 应继续直接透传阶段 0 冻结的双列错位 pitch topology。"
                )
            )
        }
    case .none:
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 1 的 side rail presentation 应暴露 active layoutContext，而不是 nil。"
            )
        )
    }

    if sideRailPresentation.scene.naturalNoteStripRailLayoutContext
        != sideRailPresentation.naturalNoteStripRailLayoutContext {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 1 的 ExerciseScene 应继续把 shared rail layoutContext 原样透传给 presentation 层。"
            )
        )
    }

    let stackedRailPresentation = ExerciseCompositionPolicy.makePresentation(
        from: ExerciseCompositionPolicyInput(
            trainerDisplayState: positionPromptTrainerDisplayState,
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
    if stackedRailPresentation.naturalNoteStripRailLayoutContext != nil
        || stackedRailPresentation.scene.naturalNoteStripRailLayoutContext
        != nil {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 1 的 stacked scene 不应误暴露 natural note strip rail layoutContext。"
            )
        )
    }

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
    if targetPromptSideBySidePresentation.naturalNoteStripRailLayoutContext
        != nil
        || targetPromptSideBySidePresentation.scene
            .naturalNoteStripRailLayoutContext != nil {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 1 的非 rail sideBySide scene 不应误暴露 natural note strip rail layoutContext。"
            )
        )
    }

    return issues
}
```

## 4. 验证结果

- `ReadLints` 检查：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`：无 linter 问题
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`：无 linter 问题
- 构建验证：
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`：`BUILD SUCCEEDED`
- 运行时 smoke：
- macOS：尝试执行 `NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression .../NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1`，但沙箱启动失败；提权重试时命令被中断，因此本轮不计为通过
- iOS Simulator：当前环境里的 `CoreSimulatorService` 不可用，`simctl` 无法正常访问设备集，因此本轮没有完成 iOS smoke 实跑

## 5. 本轮结论

- 阶段1已经把方案 C 所需的 shared rail placement 类型边界补齐：shared 现在不仅知道 topology，还知道 placement model、geometry token、title policy 和 derived layout context。
- 阶段2接下来可以直接基于 `naturalNoteStripRailLayoutContext` 实现 deterministic placement builder，而不需要再把两列错位规则散落到平台层重新推导。

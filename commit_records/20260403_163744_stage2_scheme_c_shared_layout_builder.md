# 20260403_163744_stage2_scheme_c_shared_layout_builder

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_163744`
- 记录范围：只记录方案 C 的阶段2代码改动，即实现 shared rail placement builder，并把 shared layout 输出接到 `ExerciseScene` / `ExercisePresentationState`；不记录阶段3+ 的更细粒度 placement validation 与双端渲染替换
- 当前 `git status` 中还包含计划文件 `/.cursor/plans/rail_placement_phases_c_51a1bd19.plan.md`；该文件不属于本记录范围，本记录只说明本轮实际代码改动
- 本记录不放原始 `git diff`，只按真实代码状态说明“修改前 / 修改后”
- 本轮代码改动文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本轮相关代码文件状态（`git status --short`）：
- `M NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `M NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`
- 本轮 `git diff --stat`（仅上述两个代码文件）：`2 files changed, 358 insertions(+), 1 deletion(-)`

## 1. 本轮目标

- 阶段2不改 `iOS/macOS NaturalNoteStripView` 的实际渲染路径，平台仍然保持当前单列 `stackView` 路径。
- 先把 shared 层真正补齐到“已经能单独算出 rail 的 placements + contentSize”。
- 让后续阶段4的平台改造只消费 shared placement，而不是继续在平台层自行推导 `C#` 位于 `C/D` 中点。

## 2. 修改一：在 shared 层实现 deterministic 的 rail layout builder

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数/符号:
// - ExerciseNaturalNoteStripRailGeometry.twoColumnContentWidth
// - ExerciseNaturalNoteStripRailGeometry.naturalColumnContentHeight(rowCount:)
// - ExerciseNaturalNoteStripRailLayout
// - ExerciseScene.naturalNoteStripRailLayoutContext
// - ExercisePresentationState.naturalNoteStripRailLayoutContext
// 修改前说明:
// 1. 阶段1只补齐了 placement model / geometry token / layoutContext 这些 shared 输入。
// 2. shared 层还不能真正产出 placements，也还没有 contentSize 的最终 builder。
// 3. ExerciseScene / ExercisePresentationState 只暴露 layoutContext，没有暴露真正的 shared rail layout 输出。
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

    var twoColumnContentWidth: Double {
        contentInsets.leading
            + resolvedButtonExtent
            + resolvedColumnGap
            + resolvedButtonExtent
            + contentInsets.trailing
    }

    func naturalColumnContentHeight(rowCount: Int) -> Double {
        let resolvedRowCount = max(rowCount, 0)
        let gapCount = max(resolvedRowCount - 1, 0)
        return contentInsets.top
            + (resolvedButtonExtent * Double(resolvedRowCount))
            + (resolvedNaturalRowSpacing * Double(gapCount))
            + contentInsets.bottom
    }
}

struct ExerciseNaturalNoteStripRailLayout: Equatable, Sendable {
    var context: ExerciseNaturalNoteStripRailLayoutContext
    var contentSize: CGSize
    var placements: [ExerciseNaturalNoteStripRailPlacement]
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

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数/符号:
// - ExerciseNaturalNoteStripRailGeometry.singleColumnContentWidth
// - ExerciseNaturalNoteStripRailGeometry.naturalRowStride
// - ExerciseNaturalNoteStripRailGeometry.columnContentHeight(rowCount:)
// - ExerciseNaturalNoteStripRailTitleDisplayPolicy.showsTitle(for:)
// - ExerciseNaturalNoteStripRailLayoutContext.resolvedLayout
// - ExerciseNaturalNoteStripRailLayout.build(from:)
// - ExerciseNaturalNoteStripRailLayoutBuilder
// - ExerciseScene.naturalNoteStripRailLayout
// - ExercisePresentationState.naturalNoteStripRailLayout
// 修改后说明:
// 1. 新增 pure builder，把 single-column 与 staggered two-column 两条 shared 计算路径都收口到同一个入口。
// 2. 自然音主行中心、accidental 中点、左右列 x 坐标、contentSize 都在 shared 一次性计算。
// 3. `frame` 统一使用 rail-local top-leading 坐标，后续平台只负责消费，不再二次推导几何。
// 4. Scene / Presentation 开始统一暴露 `naturalNoteStripRailLayout`，阶段4可以直接接平台 view。
struct ExerciseNaturalNoteStripRailGeometry: Equatable, Sendable {
    // 兼容单列 chromatic12 路径，避免 shared builder 只有双列模式。
    var singleColumnContentWidth: Double {
        contentInsets.leading
            + resolvedButtonExtent
            + contentInsets.trailing
    }

    // 一个自然音主行的步长 = 按钮尺寸 + 主行间距。
    var naturalRowStride: Double {
        resolvedButtonExtent + resolvedNaturalRowSpacing
    }

    var twoColumnContentWidth: Double {
        contentInsets.leading
            + resolvedButtonExtent
            + resolvedColumnGap
            + resolvedButtonExtent
            + contentInsets.trailing
    }

    func columnContentHeight(rowCount: Int) -> Double {
        let resolvedRowCount = max(rowCount, 0)
        let gapCount = max(resolvedRowCount - 1, 0)
        return contentInsets.top
            + (resolvedButtonExtent * Double(resolvedRowCount))
            + (resolvedNaturalRowSpacing * Double(gapCount))
            + contentInsets.bottom
    }

    func naturalColumnContentHeight(rowCount: Int) -> Double {
        columnContentHeight(rowCount: rowCount)
    }
}

extension ExerciseNaturalNoteStripRailTitleDisplayPolicy {
    func showsTitle(for pitchClass: PitchClass) -> Bool {
        switch self {
        case .naturalsOnly:
            return pitchClass.isNatural
        case .allPitchClasses:
            return true
        }
    }
}

extension ExerciseNaturalNoteStripRailLayoutContext {
    var resolvedLayout: ExerciseNaturalNoteStripRailLayout {
        ExerciseNaturalNoteStripRailLayout.build(from: self)
    }
}

extension ExerciseNaturalNoteStripRailLayout {
    static func build(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        ExerciseNaturalNoteStripRailLayoutBuilder.build(from: context)
    }
}

private enum ExerciseNaturalNoteStripRailLayoutBuilder {
    static func build(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        switch context.placementModel {
        case .singleColumnChromatic12:
            return buildSingleColumnChromatic12(from: context)
        case .staggeredNaturalAccidentalTwoColumn:
            return buildStaggeredNaturalAccidentalTwoColumn(from: context)
        }
    }

    // 兼容路径：保留单列 chromatic12 的 shared 计算方式。
    private static func buildSingleColumnChromatic12(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        let geometry = context.geometry
        let rowCount = context.pitchTopologies.count
        let placements = context.pitchTopologies.enumerated().map { index, topology in
            makePlacement(
                for: topology,
                originX: geometry.contentInsets.leading,
                originY: geometry.contentInsets.top
                    + (Double(index) * geometry.naturalRowStride),
                context: context,
                geometry: geometry
            )
        }

        return ExerciseNaturalNoteStripRailLayout(
            context: context,
            contentSize: CGSize(
                width: geometry.singleColumnContentWidth,
                height: geometry.columnContentHeight(rowCount: rowCount)
            ),
            placements: placements
        )
    }

    // 阶段2核心路径：shared 直接产出双列错位布局。
    private static func buildStaggeredNaturalAccidentalTwoColumn(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        let geometry = context.geometry
        let buttonExtent = geometry.resolvedButtonExtent
        let naturalRowCount = resolvedNaturalRowCount(from: context.pitchTopologies)
        let placements = context.pitchTopologies.map { topology in
            let centerY = resolvedCenterY(
                for: topology.anchor,
                geometry: geometry
            )
            return makePlacement(
                for: topology,
                originX: resolvedColumnOriginX(
                    for: topology.column,
                    geometry: geometry
                ),
                originY: centerY - (buttonExtent / 2),
                context: context,
                geometry: geometry
            )
        }

        return ExerciseNaturalNoteStripRailLayout(
            context: context,
            contentSize: CGSize(
                width: geometry.twoColumnContentWidth,
                height: geometry.naturalColumnContentHeight(
                    rowCount: naturalRowCount
                )
            ),
            placements: placements
        )
    }

    private static func makePlacement(
        for topology: ExerciseNaturalNoteStripRailPitchTopology,
        originX: Double,
        originY: Double,
        context: ExerciseNaturalNoteStripRailLayoutContext,
        geometry: ExerciseNaturalNoteStripRailGeometry
    ) -> ExerciseNaturalNoteStripRailPlacement {
        ExerciseNaturalNoteStripRailPlacement(
            pitchClass: topology.pitchClass,
            topology: topology,
            frame: CGRect(
                x: originX,
                y: originY,
                width: geometry.resolvedButtonExtent,
                height: geometry.resolvedButtonExtent
            ),
            showsTitle: context.titleDisplayPolicy.showsTitle(
                for: topology.pitchClass
            )
        )
    }
}

extension ExerciseScene {
    var naturalNoteStripRailLayout: ExerciseNaturalNoteStripRailLayout? {
        naturalNoteStripRailLayoutContext?.resolvedLayout
    }
}

extension ExercisePresentationState {
    var naturalNoteStripRailLayout: ExerciseNaturalNoteStripRailLayout? {
        scene.naturalNoteStripRailLayout
    }
}
```

## 3. 修改二：新增阶段2 validation，冻结 shared layout 输出边界

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - 文件导入区
// - ExerciseCompositionValidationRunner.makeFixtures()
// - validateNaturalNoteStripStageCLayoutBuilderExposesSharedLayoutOutput()（无）
// 修改前说明:
// 1. validation 只冻结到 stage0 topology 和 stage1 layoutContext。
// 2. shared builder 已经准备接入，但 automated validation 还没有任何夹具去确认
//    “side rail scene 必须暴露 shared layout 输出、并且每个语义槽位都有 placement”。
import Foundation

ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_layout_context_freezes_default_geometry_tokens",
    validate:
        validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens
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
// - 文件导入区
// - ExerciseCompositionValidationRunner.makeFixtures()
// - validateNaturalNoteStripStageCLayoutBuilderExposesSharedLayoutOutput()
// 修改后说明:
// 1. 增加 `CoreGraphics` 导入，让 validation 可以直接检查 placement.frame 的宽高。
// 2. 新增 stage2 fixture，把 shared rail layout 的存在性、slot 对齐、正值 contentSize、
//    frame 尺寸和 scene/presentation 透传边界一起锁住。
import CoreGraphics
import Foundation

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

static func validateNaturalNoteStripStageCLayoutBuilderExposesSharedLayoutOutput()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "natural_note_strip_stage_c_layout_builder_exposes_shared_layout_output"
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

    let expectedPitchClasses = PitchClass.allCases
    switch sideRailPresentation.naturalNoteStripRailLayout {
    case let .some(layout):
        if layout.context != sideRailPresentation.naturalNoteStripRailLayoutContext {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 shared rail layout 应继续直接引用当前 presentation 暴露的 layoutContext。"
                )
            )
        }

        if layout.placements.map(\.pitchClass) != expectedPitchClasses {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 shared rail layout 应继续按 chromatic12 顺序输出 C/C#/D/.../B 的 placements。"
                )
            )
        }

        if layout.placements.count != layout.context.slotModel.slotCount {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 shared rail layout 应继续为每个语义槽位产出一个 placement。"
                )
            )
        }

        if layout.contentSize.width <= 0 || layout.contentSize.height <= 0 {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 shared rail layout 应继续产出正值 contentSize，而不是零尺寸布局。"
                )
            )
        }

        let resolvedButtonExtent = layout.context.geometry.resolvedButtonExtent
        let hasMismatchedButtonFrames = layout.placements.contains { placement in
            placement.frame.width != resolvedButtonExtent
                || placement.frame.height != resolvedButtonExtent
        }
        if hasMismatchedButtonFrames {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 shared rail layout 应继续让全部 placement frame 与 rail buttonExtent 对齐。"
                )
            )
        }

        if layout.context.titleDisplayPolicy == .allPitchClasses
            && layout.placements.contains(where: { !$0.showsTitle }) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 shared rail layout 在 allPitchClasses 策略下，不应漏掉任何按钮标题可见性。"
                )
            )
        }
    case .none:
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 2 的 side rail presentation 应暴露 active shared rail layout，而不是 nil。"
            )
        )
    }

    if sideRailPresentation.scene.naturalNoteStripRailLayout
        != sideRailPresentation.naturalNoteStripRailLayout {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 2 的 ExerciseScene 应继续把 shared rail layout 原样透传给 presentation 层。"
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
- 编译期问题与修复：
- 在新增 stage2 fixture 后，`ExerciseCompositionValidation.swift` 因为直接读取 `placement.frame.width/height`，需要显式 `import CoreGraphics`
- 补上导入后，双端构建恢复通过

## 5. 本轮结论

- 阶段2已经把 shared builder 真正建立起来：shared 现在不只知道“布局应该长什么样”，而是已经能直接算出 `placements + contentSize`。
- 阶段4开始改双端 `NaturalNoteStripView` 时，可以直接消费 `naturalNoteStripRailLayout`，不需要再在平台层重新推导错位双列的几何关系。

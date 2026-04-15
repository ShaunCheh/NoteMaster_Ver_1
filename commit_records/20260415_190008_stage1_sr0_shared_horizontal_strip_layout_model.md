# 20260415_190008_stage1_sr0_shared_horizontal_strip_layout_model

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_190008`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat`、按文件分组的 `git diff --unified=12`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` 验证结果整理，不直接粘贴原始 `git diff`
- 记录范围：本次只记录“实施阶段 1”真实落地的代码改动；目标是抽取 `horizontalStrip` 的 shared 双行布局模型，并把它作为稳定 contract 暴露给 `ExerciseScene` / `ExercisePresentationState`
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`5 files changed, 637 insertions(+), 4 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 5 个 `Swift` 文件，因此本次统计口径直接等同于阶段 1 本轮改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `5 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`：阶段 1 不提前消费 shared horizontal layout，平台双行视图留到阶段 2
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`：同上，继续保持现有 `horizontalStrip` 单行 stack 实现
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`：本轮不提前透传 horizontal layout 到 renderer
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`：同上，避免阶段边界外扩
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`：本轮不新增 `staffToNaturalNoteStrip` 或 `SR-0` mode，只补 shared layout contract
- `NoteMaster_Ver_1/Shared/Scene/SceneCore.swift`：阶段 0 已冻结 `horizontalStrip / verticalRail` 语义，本轮不再改枚举边界
- 验证结果：
- `ReadLints`：对本轮 5 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath /tmp/NoteMasterStage1-mac-build build`：构建通过
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr0_双行strip_计划_632caead.plan.md`
- 没有触碰 iOS / macOS `NaturalNoteStripView` 的 `horizontalStrip` 具体双行实现
- 没有新增 `SR-0` mode、`staffToNaturalNoteStrip` preset 或 `ExerciseCompositionPolicy` 的主场景组合逻辑
- 没有提交代码

## 本次结论

- `horizontalStrip` 现在在 shared 层已有独立的双行布局 contract：上行半音、下行自然音、统一标题策略、统一内容尺寸语义
- `ExerciseScene` 与 `ExercisePresentationState` 现在可以像 rail 一样，对外暴露 `naturalNoteStripHorizontalLayoutContext` 与 `naturalNoteStripHorizontalLayout`
- `PitchClass.accidentalCasesInOrder` 被收口回核心 pitch 类型，避免它继续散落在 `ExercisePresentationState.swift`
- 新增 3 个阶段 1 fixture，把 horizontal layout 的默认 geometry、builder 输出、行拓扑和 `contentSize` 写成 shared validation
- 视觉层暂时不会变化，因为平台 view 还没有消费这套 contract；这正是阶段 2 的职责

## 修改 1：把 `accidentalCasesInOrder` 收口到 `PitchClass` 核心定义

### 修改前

- `PitchClass.naturalCasesInOrder` 在 `NotePitch.swift`
- `PitchClass.accidentalCasesInOrder` 却挂在 `ExercisePresentationState.swift` 的 extension 里
- 这会让 horizontal layout 的顺序语义依赖 exercise 模块文件，而不是音高核心类型

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名/符号: extension PitchClass.accidentalCasesInOrder
// 功能说明: 修改前 accidental 顺序 helper 挂在 exercise 侧；
// 新的 horizontalStrip shared layout 想复用它时，会把核心顺序语义绑到非核心文件上。
extension PitchClass {
    static var accidentalCasesInOrder: [PitchClass] {
        allCases.filter(\.isAccidental)
    }

    static var naturalNoteStripStaggeredRailTopologiesInChromaticOrder:
        [ExerciseNaturalNoteStripRailPitchTopology] {
        allCases.map(\.naturalNoteStripStaggeredRailPitchTopology)
    }
}
```

### 修改后

- `naturalCasesInOrder` 与 `accidentalCasesInOrder` 统一放回 `NotePitch.swift`
- `ExercisePresentationState.swift` 只保留 rail topology 相关 extension

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift
// 函数名/符号: enum PitchClass.naturalCasesInOrder / accidentalCasesInOrder
// 功能说明: 修改后把自然音与半音的基础顺序都收口到 PitchClass；
// horizontalStrip 与 verticalRail 都以这里作为共享顺序来源。
enum PitchClass: Int, CaseIterable, Hashable, Sendable {
    case c = 0
    case cSharp = 1
    // ... 省略未变 case ...
    case b = 11

    var isAccidental: Bool { /* ... 保持既有逻辑 ... */ }
    var isNatural: Bool { !isAccidental }

    static var naturalCasesInOrder: [PitchClass] {
        allCases.filter(\.isNatural)
    }

    static var accidentalCasesInOrder: [PitchClass] {
        allCases.filter(\.isAccidental)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名/符号: extension PitchClass.naturalNoteStripStaggeredRailTopologiesInChromaticOrder
// 功能说明: 修改后 exercise 侧只保留 rail topology 投影；
// accidental 顺序 helper 不再重复定义。
extension PitchClass {
    static var naturalNoteStripStaggeredRailTopologiesInChromaticOrder:
        [ExerciseNaturalNoteStripRailPitchTopology] {
        allCases.map(\.naturalNoteStripStaggeredRailPitchTopology)
    }

    var naturalNoteStripStaggeredRailPitchTopology:
        ExerciseNaturalNoteStripRailPitchTopology {
        // ... 保持既有 rail topology 逻辑 ...
    }
}
```

## 修改 2：在 shared 层新增双行 `horizontalStrip` 布局模型

### 修改前

- `ExerciseNaturalNoteStripRailPlacement.swift` 只有 rail 两列错位模型
- `ExerciseScene` / `ExercisePresentationState` 也只暴露 `naturalNoteStripRailLayoutContext` / `naturalNoteStripRailLayout`
- `horizontalStrip` 还没有共享的 row topology、geometry token 或 `contentSize` 计算

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数名/符号: ExerciseNaturalNoteStripRailLayoutContext / ExerciseNaturalNoteStripRailLayout / ExerciseScene.naturalNoteStripRailLayoutContext
// 功能说明: 修改前 shared 层只表达 right-side verticalRail；
// bottom horizontalStrip 还没有自己的共享 layout contract。
struct ExerciseNaturalNoteStripRailLayoutContext: Equatable, Sendable {
    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var placementModel: ExerciseNaturalNoteStripRailPlacementModel
    var titleDisplayPolicy: ExerciseNaturalNoteStripRailTitleDisplayPolicy
    var geometry: ExerciseNaturalNoteStripRailGeometry
    var hostVerticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
    var pitchTopologies: [ExerciseNaturalNoteStripRailPitchTopology]
}

struct ExerciseNaturalNoteStripRailLayout: Equatable, Sendable {
    var context: ExerciseNaturalNoteStripRailLayoutContext
    var contentSize: CGSize
    var placements: [ExerciseNaturalNoteStripRailPlacement]
}

extension ExerciseScene {
    var naturalNoteStripRailLayoutContext: ExerciseNaturalNoteStripRailLayoutContext? {
        naturalNoteStripRailContract?.defaultLayoutContext
    }

    var naturalNoteStripRailLayout: ExerciseNaturalNoteStripRailLayout? {
        naturalNoteStripRailLayoutContext?.resolvedLayout
    }
}
```

### 修改后

- 新增 `ExerciseNaturalNoteStripHorizontalRow`
- 新增 `ExerciseNaturalNoteStripHorizontalInsets / Geometry / LayoutContext / Placement / Layout`
- `Geometry` 明确冻结 `10/12` inset、`6` 列距、`6` 行距、`buttonExtent = 50`
- builder 输出双行 placement 与 `contentSize`
- `ExerciseScene` / `ExercisePresentationState` 正式暴露 horizontal layout context / layout

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数名/符号: ExerciseNaturalNoteStripHorizontalRow / ExerciseNaturalNoteStripHorizontalGeometry / ExerciseNaturalNoteStripHorizontalLayoutContext / ExerciseNaturalNoteStripHorizontalLayout
// 功能说明: 修改后新增 horizontalStrip 的双行 shared contract；
// 上行半音、下行自然音、标题策略和内容尺寸都在 shared 层统一表达。
enum ExerciseNaturalNoteStripHorizontalRow: Equatable, Sendable {
    case accidentalsTop
    case naturalsBottom
}

enum ExerciseNaturalNoteStripHorizontalTitleDisplayPolicy: Equatable, Sendable {
    case naturalsOnly
    case allPitchClasses
}

struct ExerciseNaturalNoteStripHorizontalGeometry: Equatable, Sendable {
    static let defaultColumnSpacing: Double = 6
    static let defaultRowSpacing: Double = 6
    static let defaultButtonExtent =
        ExerciseNaturalNoteStripRailContract.defaultButtonExtent

    var contentInsets: ExerciseNaturalNoteStripHorizontalInsets
    var columnSpacing: Double
    var rowSpacing: Double
    var buttonExtent: Double

    func rowContentWidth(columnCount: Int) -> Double { /* ... */ }
    func contentHeight(rowCount: Int) -> Double { /* ... */ }

    func twoRowContentSize(
        topColumnCount: Int,
        bottomColumnCount: Int
    ) -> CGSize {
        CGSize(
            width: max(
                rowContentWidth(columnCount: topColumnCount),
                rowContentWidth(columnCount: bottomColumnCount)
            ),
            height: contentHeight(rowCount: 2)
        )
    }

    static func defaultTwoRowHorizontalStrip(
        buttonExtent: Double = defaultButtonExtent
    ) -> ExerciseNaturalNoteStripHorizontalGeometry {
        ExerciseNaturalNoteStripHorizontalGeometry(
            contentInsets: .defaultHorizontalStrip,
            columnSpacing: defaultColumnSpacing,
            rowSpacing: defaultRowSpacing,
            buttonExtent: buttonExtent
        )
    }
}

struct ExerciseNaturalNoteStripHorizontalLayoutContext: Equatable, Sendable {
    static let defaultTitleDisplayPolicy:
        ExerciseNaturalNoteStripHorizontalTitleDisplayPolicy = .allPitchClasses

    var appliesToSurface: ExerciseSurfaceID
    var titleDisplayPolicy: ExerciseNaturalNoteStripHorizontalTitleDisplayPolicy
    var geometry: ExerciseNaturalNoteStripHorizontalGeometry
    var accidentalPitchClasses: [PitchClass]
    var naturalPitchClasses: [PitchClass]
}

struct ExerciseNaturalNoteStripHorizontalPlacement: Equatable, Sendable {
    var pitchClass: PitchClass
    var row: ExerciseNaturalNoteStripHorizontalRow
    var columnIndex: Int
    var showsTitle: Bool
}

struct ExerciseNaturalNoteStripHorizontalLayout: Equatable, Sendable {
    var context: ExerciseNaturalNoteStripHorizontalLayoutContext
    var accidentalPlacements: [ExerciseNaturalNoteStripHorizontalPlacement]
    var naturalPlacements: [ExerciseNaturalNoteStripHorizontalPlacement]
    var contentSize: CGSize
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数名/符号: ExerciseNaturalNoteStripHorizontalLayoutBuilder.build(from:) / ExerciseScene.naturalNoteStripHorizontalLayoutContext / ExercisePresentationState.naturalNoteStripHorizontalLayout
// 功能说明: 修改后 scene 与 presentation 都能对外暴露 horizontalStrip 的共享 layout 摘要；
// 这样阶段 2 的平台 view 可以直接消费 shared contract，而不是两端各自拼顺序。
private enum ExerciseNaturalNoteStripHorizontalLayoutBuilder {
    static func build(
        from context: ExerciseNaturalNoteStripHorizontalLayoutContext
    ) -> ExerciseNaturalNoteStripHorizontalLayout {
        let accidentalPlacements = context.accidentalPitchClasses.enumerated().map {
            index, pitchClass in
            ExerciseNaturalNoteStripHorizontalPlacement(
                pitchClass: pitchClass,
                row: .accidentalsTop,
                columnIndex: index,
                showsTitle: context.titleDisplayPolicy.showsTitle(for: pitchClass)
            )
        }
        let naturalPlacements = context.naturalPitchClasses.enumerated().map {
            index, pitchClass in
            ExerciseNaturalNoteStripHorizontalPlacement(
                pitchClass: pitchClass,
                row: .naturalsBottom,
                columnIndex: index,
                showsTitle: context.titleDisplayPolicy.showsTitle(for: pitchClass)
            )
        }

        return ExerciseNaturalNoteStripHorizontalLayout(
            context: context,
            accidentalPlacements: accidentalPlacements,
            naturalPlacements: naturalPlacements,
            contentSize: context.geometry.twoRowContentSize(
                topColumnCount: accidentalPlacements.count,
                bottomColumnCount: naturalPlacements.count
            )
        )
    }
}

extension ExerciseScene {
    var naturalNoteStripHorizontalLayoutContext:
        ExerciseNaturalNoteStripHorizontalLayoutContext? {
        guard let horizontalStripSurface = activeNaturalNoteStripHorizontalSurface
        else {
            return nil
        }

        return ExerciseNaturalNoteStripHorizontalLayoutContext(
            appliesToSurface: horizontalStripSurface.id,
            titleDisplayPolicy:
                ExerciseNaturalNoteStripHorizontalLayoutContext
                .defaultTitleDisplayPolicy,
            geometry: .defaultTwoRowHorizontalStrip(),
            accidentalPitchClasses: PitchClass.accidentalCasesInOrder,
            naturalPitchClasses: PitchClass.naturalCasesInOrder
        )
    }

    var naturalNoteStripHorizontalLayout: ExerciseNaturalNoteStripHorizontalLayout? {
        naturalNoteStripHorizontalLayoutContext?.resolvedLayout
    }
}

extension ExercisePresentationState {
    var naturalNoteStripHorizontalLayoutContext:
        ExerciseNaturalNoteStripHorizontalLayoutContext? {
        scene.naturalNoteStripHorizontalLayoutContext
    }

    var naturalNoteStripHorizontalLayout: ExerciseNaturalNoteStripHorizontalLayout? {
        scene.naturalNoteStripHorizontalLayout
    }
}
```

## 修改 3：新增阶段 1 fixture，冻结 horizontal layout context / builder / contentSize

### 修改前

- 既有 `ExerciseCompositionValidationSceneCore.swift` 已覆盖阶段 0 语义边界和 verticalRail contract
- 但还没有 fixture 去验证 horizontal layout context、layout builder 输出，或双行 `contentSize` 语义
- `ExerciseCompositionValidation.swift` 也还没有把这些 fixture 注册进 runner

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.makeFixtures()
// 功能说明: 修改前 runner 只执行阶段 0 的 horizontalStrip 语义边界 fixture，
// 还没有阶段 1 的 horizontal layout context / builder / contentSize 夹具入口。
ExerciseCompositionValidationFixture(
    name: "scheme_one_horizontal_strip_semantic_boundary_stays_distinct_from_vertical_rail",
    validate:
        validateSchemeOneHorizontalStripSemanticBoundaryStaysDistinctFromVerticalRail
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
    validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
)
```

### 修改后

- 新增 `validateNaturalNoteStripHorizontalLayoutContextFreezesTwoRowDefaults()`
- 新增 `validateNaturalNoteStripHorizontalLayoutBuilderExposesSharedLayoutOutput()`
- 新增 `validateNaturalNoteStripHorizontalLayoutPreservesRowTopologyAndContentSize()`
- fixture 同时验证：
- `stacked` 主 strip 和 accessory strip 都会暴露 horizontal layout context
- `sideBySide + verticalRail` 和非 strip scene 不会误暴露 horizontal layout
- 顶部/底部 row topology、列索引顺序、`contentSize` 计算保持稳定

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名/符号: validateNaturalNoteStripHorizontalLayoutContextFreezesTwoRowDefaults() / validateNaturalNoteStripHorizontalLayoutBuilderExposesSharedLayoutOutput() / validateNaturalNoteStripHorizontalLayoutPreservesRowTopologyAndContentSize()
// 功能说明: 修改后把 horizontalStrip 的阶段 1 shared contract 写成自动化夹具；
// 不再依赖“平台层之后会自己按对的顺序去排”的隐含假设。
static func validateNaturalNoteStripHorizontalLayoutContextFreezesTwoRowDefaults()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "natural_note_strip_horizontal_layout_context_freezes_two_row_defaults"
    var issues: [ExerciseCompositionValidationIssue] = []
    let expectedContext = ExerciseNaturalNoteStripHorizontalLayoutContext(
        appliesToSurface: .naturalNoteStrip,
        titleDisplayPolicy:
            ExerciseNaturalNoteStripHorizontalLayoutContext.defaultTitleDisplayPolicy,
        geometry: .defaultTwoRowHorizontalStrip(
            buttonExtent: ExerciseNaturalNoteStripHorizontalGeometry.defaultButtonExtent
        ),
        accidentalPitchClasses: PitchClass.accidentalCasesInOrder,
        naturalPitchClasses: PitchClass.naturalCasesInOrder
    )

    // ... 省略未变断言：
    // 1. stacked 主 strip 暴露 expectedContext
    // 2. accessory strip 也暴露 expectedContext
    // 3. side rail / 非 strip scene 返回 nil
    return issues
}

static func validateNaturalNoteStripHorizontalLayoutBuilderExposesSharedLayoutOutput()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "natural_note_strip_horizontal_layout_builder_exposes_shared_layout_output"
    var issues: [ExerciseCompositionValidationIssue] = []

    // ... 省略未变断言：
    // 1. accidentalPlacements 顺序等于 PitchClass.accidentalCasesInOrder
    // 2. naturalPlacements 顺序等于 PitchClass.naturalCasesInOrder
    // 3. layout.contentSize 为正值，且 scene/presentation 透传一致
    return issues
}

static func validateNaturalNoteStripHorizontalLayoutPreservesRowTopologyAndContentSize()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "natural_note_strip_horizontal_layout_preserves_row_topology_and_content_size"
    var issues: [ExerciseCompositionValidationIssue] = []

    // ... 省略未变断言：
    // 1. 顶部 placements 全部在 accidentalsTop
    // 2. 底部 placements 全部在 naturalsBottom
    // 3. 列索引保持 0..<count
    // 4. contentSize 继续由共享 geometry token 与上下两行按钮数共同决定
    return issues
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.makeFixtures()
// 功能说明: 修改后把阶段 1 的 horizontal layout fixtures 正式纳入 runner；
// 后续阶段改平台实现时，可以直接复用这些 shared 夹具兜底。
ExerciseCompositionValidationFixture(
    name: "scheme_one_horizontal_strip_semantic_boundary_stays_distinct_from_vertical_rail",
    validate:
        validateSchemeOneHorizontalStripSemanticBoundaryStaysDistinctFromVerticalRail
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_horizontal_layout_context_freezes_two_row_defaults",
    validate:
        validateNaturalNoteStripHorizontalLayoutContextFreezesTwoRowDefaults
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_horizontal_layout_builder_exposes_shared_layout_output",
    validate:
        validateNaturalNoteStripHorizontalLayoutBuilderExposesSharedLayoutOutput
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_horizontal_layout_preserves_row_topology_and_content_size",
    validate:
        validateNaturalNoteStripHorizontalLayoutPreservesRowTopologyAndContentSize
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
    validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
)
```

## 对阶段计划的对应关系

- 对应 `sr0_双行strip_计划_632caead.plan.md` 的“阶段 1：抽取共享的双行 horizontalStrip 布局模型”
- 已完成：
- 在 shared 层建立上半音 / 下自然音的双行顺序模型
- 为 horizontalStrip 建立独立的 geometry token 和 `contentSize` 计算
- 在 `ExerciseScene` / `ExercisePresentationState` 暴露 horizontal layout context 与 layout
- 用 validation fixture 冻结 context、builder 输出、row topology 和尺寸语义
- 尚未开始：
- 阶段 2 的 iOS / macOS `NaturalNoteStripView` 双行实现
- renderer 向平台 view 透传 horizontal layout 的消费逻辑
- 阶段 3 之后的 `SR-0` mode / preset / answer flow / settings 接入

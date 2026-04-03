# 20260403_155412_stage0_scheme_c_topology_boundary_freeze

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`，结果为 `20260403_155412`
- 记录范围：只记录方案 C 的阶段0代码改动，用于冻结 shared 语义边界与 validation，不记录后续阶段1+的 placement / 平台渲染实现
- 当前 `git status` 中还包含计划文件 `/.cursor/plans/rail_placement_phases_c_51a1bd19.plan.md`；该文件属于规划产物，本记录只对实际代码改动做“修改前 / 修改后”说明
- 本记录不放原始 `git diff`，只按真实改动说明“修改前 / 修改后”
- 本轮代码改动文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本轮 `git diff --stat`（仅上述两个代码文件）：`2 files changed, 312 insertions(+)`

## 1. 本轮目标

- 先不实现双列错位 UI，也不改双端 `NaturalNoteStripView`。
- 先把方案 C 最重要的 shared 边界冻结下来：`12 个 PitchClass 语义槽位` 与 `未来双列错位视觉拓扑` 是两个层次，不能继续混在平台层单列 `stackView` 里。
- 这一步的职责是给阶段1/阶段2提供 shared 真相来源，并用 validation 把它锁死。

## 2. 修改一：在 shared 层引入 natural note strip 的非几何拓扑语义

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailContract,
//           ExerciseNaturalNoteStripRailSlotModel,
//           extension PitchClass
// 修改前说明:
// 1. shared 层只知道 rail contract 的粗粒度语义，比如 buttonExtent / fitContent / centered。
// 2. 它还不知道“自然音在右列、升号在左列、升号位于相邻自然音中点”这种拓扑关系。
// 3. PitchClass 只有 naturalCasesInOrder，没有 accidental 顺序与 side rail 双列错位的 shared 拓扑出口。
enum ExerciseNaturalNoteStripRailSlotModel: Equatable, Sendable {
    case chromatic12Preserved

    var slotCount: Int {
        PitchClass.allCases.count
    }
}

enum ExerciseNaturalNoteStripRailButtonShape: Equatable, Sendable {
    case square
}

enum ExerciseNaturalNoteStripRailMainAxisPolicy: Equatable, Sendable {
    case contentSized
}

enum ExerciseNaturalNoteStripRailCrossAxisPolicy: Equatable, Sendable {
    case fitContent
}

enum ExerciseNaturalNoteStripRailVerticalAlignment: Equatable, Sendable {
    case centered
}

struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 50
    static let defaultCrossAxisWidthScale: Double = 2
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        crossAxisWidthScale: defaultCrossAxisWidthScale,
        verticalAlignment: .centered
    )

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var crossAxisWidthScale: Double
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
}

// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift
// 函数/符号: PitchClass.naturalCasesInOrder
// 修改前说明: 只冻结了自然音顺序，还没有 accidental 顺序与 rail 双列错位的拓扑真相来源。
extension PitchClass {
    static var naturalCasesInOrder: [PitchClass] {
        allCases.filter(\\.isNatural)
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号:
// - ExerciseNaturalNoteStripRailPitchTopologyColumn
// - ExerciseNaturalNoteStripRailPitchTopologyAnchor
// - ExerciseNaturalNoteStripRailPitchTopology
// - PitchClass.accidentalCasesInOrder
// - PitchClass.naturalNoteStripStaggeredRailTopologiesInChromaticOrder
// - PitchClass.naturalNoteStripStaggeredRailPitchTopology
// 修改后说明:
// 1. shared 层新增“非几何拓扑”抽象，先表达谁在左列/右列、谁是自然音主行、谁位于相邻自然音中点。
// 2. 这一步仍然不产出 frame，也不做 placement builder；它只是冻结方案 C 阶段0的 shared 真相来源。
enum ExerciseNaturalNoteStripRailPitchTopologyColumn: Equatable, Sendable {
    case accidentalLeft
    case naturalRight
}

enum ExerciseNaturalNoteStripRailPitchTopologyAnchor: Equatable, Sendable {
    case naturalRow(index: Int)
    case midpointBetweenNaturalRows(top: Int, bottom: Int)
}

struct ExerciseNaturalNoteStripRailPitchTopology: Equatable, Sendable {
    var pitchClass: PitchClass
    var column: ExerciseNaturalNoteStripRailPitchTopologyColumn
    var anchor: ExerciseNaturalNoteStripRailPitchTopologyAnchor
}

extension PitchClass {
    static var accidentalCasesInOrder: [PitchClass] {
        allCases.filter(\\.isAccidental)
    }

    static var naturalNoteStripStaggeredRailTopologiesInChromaticOrder:
        [ExerciseNaturalNoteStripRailPitchTopology] {
        allCases.map(\\.naturalNoteStripStaggeredRailPitchTopology)
    }

    var naturalNoteStripStaggeredRailPitchTopology:
        ExerciseNaturalNoteStripRailPitchTopology {
        switch self {
        case .c:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 0)
            )
        case .cSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 0, bottom: 1)
            )
        case .d:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 1)
            )
        case .dSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 1, bottom: 2)
            )
        case .e:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 2)
            )
        case .f:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 3)
            )
        case .fSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 3, bottom: 4)
            )
        case .g:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 4)
            )
        case .gSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 4, bottom: 5)
            )
        case .a:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 5)
            )
        case .aSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 5, bottom: 6)
            )
        case .b:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 6)
            )
        }
    }
}
```

### 2.3 这一改动解决了什么

- 先把“未来双列错位应该长成什么样”从平台 `stackView` 推导里剥出来，放进 shared。
- 明确冻结了：
- 自然音右列：`C D E F G A B`
- 升号左列：`C# D# F# G# A#`
- `C# / D# / F# / G# / A#` 落在相邻自然音中点
- `E-F`、`B-C` 之间没有 accidental 中点
- 但还没有进入具体几何阶段，所以本轮不产出 frame，不碰平台约束。

## 3. 修改二：新增阶段0 validation fixture，把拓扑与 12 语义槽位冻结成 shared 不变量

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - ExerciseCompositionValidationRunner.makeFixtures()
// - validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// - validateSideRailContractRemainsOrthogonalToFretboardHeightContract()
// 修改前说明:
// validation 已经能冻结 rail contract 的作用域、buttonExtent、fitContent(x2)、centered，
// 但还没有任何一条 fixture 显式冻结“方案 C 的双列错位拓扑边界”。
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
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号:
// - ExerciseCompositionValidationRunner.makeFixtures()
// - validateNaturalNoteStripStageCTopologyFreezesChromatic12Semantics()
// 修改后说明:
// 新增方案 C 阶段0的 fixture，专门冻结 shared 层的拓扑边界，
// 防止后面阶段1/2实现 placement 时又退回平台层 patch。
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
    validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
),
ExerciseCompositionValidationFixture(
    name: "side_rail_contract_remains_orthogonal_to_fretboard_height_contract",
    validate: validateSideRailContractRemainsOrthogonalToFretboardHeightContract
),
ExerciseCompositionValidationFixture(
    name: "natural_note_strip_stage_c_topology_freezes_chromatic12_semantics",
    validate: validateNaturalNoteStripStageCTopologyFreezesChromatic12Semantics
),
ExerciseCompositionValidationFixture(
    name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
    validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateNaturalNoteStripStageCTopologyFreezesChromatic12Semantics()
// 修改后说明:
// 这条夹具把阶段0的 shared 边界一次性冻结下来：
// 1. naturalCasesInOrder 仍然是 C-D-E-F-G-A-B
// 2. accidentalCasesInOrder 仍然是 C#-D#-F#-G#-A#
// 3. 自然音全部在右列，accidental 全部在左列
// 4. 自然音主行索引固定是 0...6
// 5. accidental midpoint 只允许 [0,1] [1,2] [3,4] [4,5] [5,6]
// 6. side rail 的 slotModel 仍然是 chromatic12Preserved，对应 12 个语义槽位
static func validateNaturalNoteStripStageCTopologyFreezesChromatic12Semantics()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName =
        "natural_note_strip_stage_c_topology_freezes_chromatic12_semantics"
    var issues: [ExerciseCompositionValidationIssue] = []

    let expectedNaturals: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
    let expectedAccidentals: [PitchClass] = [
        .cSharp,
        .dSharp,
        .fSharp,
        .gSharp,
        .aSharp
    ]
    let expectedAccidentalMidpointPairs = [
        [0, 1],
        [1, 2],
        [3, 4],
        [4, 5],
        [5, 6]
    ]

    // ... 中间省略若干断言 ...

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
    if sideRailPresentation.naturalNoteStripRailContract?.slotModel.slotCount
        != 12 {
        issues.append(
            issue(
                fixtureName,
                "方案 C 阶段 0 应继续保持 side rail 的 12 个语义槽位，与未来双列错位视觉拓扑一一对应。"
            )
        )
    }

    return issues
}
```

### 3.3 这一改动解决了什么

- 方案 C 阶段0不再只是“计划里说了”，而是有了自动化断言。
- 后面如果有人误把 `E-F`、`B-C` 之间也塞出 accidental 位，或者把自然音列/升号列左右翻转，validation 会直接报错。
- 也防止后续实现 placement 时，偷偷把 `12 个语义槽位` 收缩成 `7 个视觉按钮`。

## 4. 本轮没有改什么

- 没有新增 `shared placement builder`。
- 没有新增 `ExerciseNaturalNoteStripRailLayout` 或具体 frame 结构。
- 没有修改 `macOSNaturalNoteStripView.swift` / `iOSNaturalNoteStripView.swift`。
- 没有修改 renderer 的 host / slot 布局。
- 没有修改 settings/navigation 结构，也没有新增任何 settings 配置项。
- 没有改变当前 UI：现在界面依然是单列竖排 rail。

## 5. 验证结果

- `ReadLints` 检查：
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 结果：无 linter 错误

- 编译验证：
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=macOS,name=My Mac' build`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build`
- 结果：双端 `BUILD SUCCEEDED`

- 运行时验证：
- macOS 启动链路中，`ExerciseCompositionValidation` 新 fixture
  `natural_note_strip_stage_c_topology_freezes_chromatic12_semantics`
  执行结果为 `issues=0`
- iOS 启动链路中，同名 fixture 执行结果为 `issues=0`
- 双端 `layout_preset_regression` runtime smoke 结果：`PASS`

## 6. 最终状态总结

- 方案 C 的阶段0已经把 shared 语义边界冻结下来：
- `12 个 PitchClass` 仍然是 rail 的语义真相来源
- 自然音右列、升号左列、升号位于相邻自然音中点的拓扑关系已经进入 shared
- `E-F`、`B-C` 之间没有 accidental 拓扑位
- 现在还没有进入“算出具体坐标”的阶段，所以 UI 仍保持旧样式
- 这一步的价值在于：后续阶段1/阶段2做 placement 和双端渲染时，不再需要先争论拓扑真相，而是直接基于本轮冻结下来的 shared helper 与 validation 继续推进

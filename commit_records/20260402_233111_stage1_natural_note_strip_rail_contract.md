# 20260402_233111_stage1_natural_note_strip_rail_contract

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260402_233111`
- 记录范围：只记录方案 B 的阶段 1 落地，即把阶段 0 的 `naturalNoteStrip` rail boundary 升级为真正可消费的 shared `rail contract`
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本记录中的“修改前”，指 `20260402_232212_stage0_natural_note_strip_rail_boundary_freeze.md` 记录完成后的代码状态
- 本轮实际改动文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本轮未改动但继续复用的文件：
  - `NoteMaster_Ver_1/Shared/Exercise/ExerciseScene.swift`

## 1. 本轮目标

- 阶段 0 只冻结了 right rail 的作用域边界，但 platform 层还拿不到按钮尺寸、主轴策略、交叉轴策略、垂直对齐这些可直接消费的字段。
- 阶段 1 的目标，是把 `boundary` 升级成和 `ExerciseFretboardLayoutContract` 同级的 shared contract。
- 这一步仍然不改 `NaturalNoteStripView` 和 `renderer`，先把 shared 层的输出接口定型。

## 2. 修改一：把 `boundary` 升级成可消费的 `rail contract`

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailSlotModel,
//           ExerciseNaturalNoteStripRailLayoutIntent,
//           ExerciseNaturalNoteStripRailBoundary
// 修改前说明: 阶段 0 只有“是否进入 rail 作用域”的边界对象，
// 还不能直接表达按钮几何、主轴策略、交叉轴策略和垂直对齐。
enum ExerciseNaturalNoteStripRailSlotModel: Equatable, Sendable {
    case chromatic12Preserved

    var slotCount: Int {
        PitchClass.allCases.count
    }
}

enum ExerciseNaturalNoteStripRailLayoutIntent: Equatable, Sendable {
    case contentSizedAndVerticallyCentered
}

enum ExerciseNaturalNoteStripRailBoundary: Equatable, Sendable {
    case inactive
    case sideBySideAnswerRail(
        slotModel: ExerciseNaturalNoteStripRailSlotModel,
        layoutIntent: ExerciseNaturalNoteStripRailLayoutIntent
    )

    var isEnabled: Bool {
        if case .inactive = self {
            return false
        }
        return true
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExercisePresentationState.naturalNoteStripRailBoundary,
//           ExerciseScene.naturalNoteStripRailBoundary
// 修改前说明: shared 层只能回答“当前是不是 active rail boundary”，
// 还不能把具体布局参数输出给后续平台层。
extension ExercisePresentationState {
    var naturalNoteStripRailBoundary: ExerciseNaturalNoteStripRailBoundary {
        scene.naturalNoteStripRailBoundary
    }
}

extension ExerciseScene {
    var naturalNoteStripRailBoundary: ExerciseNaturalNoteStripRailBoundary {
        guard containsNaturalNoteStripAnswerRailInSideBySideLayout else {
            return .inactive
        }

        return .sideBySideAnswerRail(
            slotModel: .chromatic12Preserved,
            layoutIntent: .contentSizedAndVerticallyCentered
        )
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailButtonShape,
//           ExerciseNaturalNoteStripRailMainAxisPolicy,
//           ExerciseNaturalNoteStripRailCrossAxisPolicy,
//           ExerciseNaturalNoteStripRailVerticalAlignment,
//           ExerciseNaturalNoteStripRailContract
// 修改后说明: 阶段 1 把 rail 的最小可消费几何语义提升到 shared contract，
// 直接给出按钮形状、默认边长、主轴 sizing、交叉轴 sizing 和垂直对齐。
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
    static let defaultButtonExtent: Double = 20

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExercisePresentationState.naturalNoteStripRailContract,
//           ExerciseScene.naturalNoteStripRailContract
// 修改后说明: ExerciseScene 现在返回可空的 rail contract；
// 只有目标 scene 真正满足 sideBySide + 左 fretboard + 右 naturalNoteStrip verticalRail + fitContent 时才输出。
private extension ExerciseNaturalNoteStripRailContract {
    static let sideBySideAnswerRailDefault = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        verticalAlignment: .centered
    )
}

extension ExercisePresentationState {
    var naturalNoteStripRailContract: ExerciseNaturalNoteStripRailContract? {
        scene.naturalNoteStripRailContract
    }
}

extension ExerciseScene {
    var naturalNoteStripRailContract: ExerciseNaturalNoteStripRailContract? {
        guard
            containsNaturalNoteStripAnswerRailInSideBySideLayout,
            let renderedSceneLayout,
            renderedSceneLayout.arrangement == .sideBySide,
            renderedSceneLayout.primarySurface.id == .fretboard,
            renderedSceneLayout.secondarySurface?.isNaturalNoteStripAnswerRail == true,
            renderedSceneLayout.secondaryMainAxisSizing == .fitContent
        else {
            return nil
        }

        return .sideBySideAnswerRailDefault
    }
}
```

### 2.3 这一改动解决了什么

- shared 层现在已经能直接回答：
  - 当前 rail contract 是否启用
  - 按钮默认是否为正方形
  - 默认按钮边长是多少
  - 主轴是否按内容高度
  - 交叉轴是否按内容宽度
  - 垂直方向是否需要居中
- 后续阶段 2/3 可以直接消费这些字段，不需要再从阶段 0 的 `boundary` 二次映射。

## 3. 修改二：把 validation 从 `boundary` 升级为 `contract` 断言

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: makeFixtures(),
//           validateNaturalNoteStripRailBoundaryFreezesScopeBeforeLayoutContract()
// 修改前说明: validation 只冻结了阶段 0 的边界语义，
// 还没有断言 button shape、button extent、main/cross axis policy、vertical alignment。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing",
            validate: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing
        ),
        ExerciseCompositionValidationFixture(
            name: "natural_note_strip_rail_boundary_freezes_scope_before_layout_contract",
            validate: validateNaturalNoteStripRailBoundaryFreezesScopeBeforeLayoutContract
        ),
        ExerciseCompositionValidationFixture(
            name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
            validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
        )
    ]
}

static func validateNaturalNoteStripRailBoundaryFreezesScopeBeforeLayoutContract()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "natural_note_strip_rail_boundary_freezes_scope_before_layout_contract"
    var issues: [ExerciseCompositionValidationIssue] = []

    switch railPresentation.naturalNoteStripRailBoundary {
    case let .sideBySideAnswerRail(slotModel, layoutIntent):
        if slotModel != .chromatic12Preserved
            || slotModel.slotCount != PitchClass.allCases.count {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 的 right rail 边界应继续冻结为保留 12 个 PitchClass 槽位的语义。"
                )
            )
        }

        if layoutIntent != .contentSizedAndVerticallyCentered {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 的 right rail 边界应先冻结为内容高度加垂直居中的目标语义。"
                )
            )
        }
    case .inactive:
        issues.append(
            issue(
                fixtureName,
                "sideBySide 的 fretboard -> natural note strip scene 在阶段 0 应暴露 active rail boundary，而不是 inactive。"
            )
        )
    }

    return issues
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: makeFixtures(),
//           validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// 修改后说明: fixture 名称和断言语义一起升级；
// 现在不只验证作用域，还验证阶段 1 输出的默认几何 contract。
static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
    [
        ExerciseCompositionValidationFixture(
            name: "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing",
            validate: validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing
        ),
        ExerciseCompositionValidationFixture(
            name: "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults",
            validate: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults
        ),
        ExerciseCompositionValidationFixture(
            name: "vertical_fit_content_split_sizing_tracks_surface_kinds",
            validate: validateVerticalFitContentSplitSizingTracksSurfaceKinds
        )
    ]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数/符号: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// 修改后说明: validation 现在直接锁住阶段 1 的 contract 默认值，
// 同时继续防止 stacked / targetPrompt->fretboard / staff->fretboard 误激活。
static func validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults"
    var issues: [ExerciseCompositionValidationIssue] = []

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

        if railContract.mainAxisPolicy != .contentSized
            || railContract.crossAxisPolicy != .fitContent
            || railContract.verticalAlignment != .centered {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 rail contract 应继续给出 contentSized / fitContent / centered 的 shared 布局语义。"
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

    return issues
}
```

### 3.3 这一改动解决了什么

- validation 不再只验证“有没有进作用域”，而是开始验证“shared 输出的 contract 到底长什么样”。
- 这样后面平台层如果要消费 `buttonExtent = 20`、`mainAxisPolicy = .contentSized`、`verticalAlignment = .centered`，shared 层已经有自动化基线。

## 4. 本轮没有改什么

- `ExerciseScene.swift` 没有新增改动，阶段 1 直接复用了阶段 0 已经落好的 `containsNaturalNoteStripAnswerRailInSideBySideLayout` 作用域 helper。
- iOS / macOS 的 `NaturalNoteStripView` 还没有开始消费这个 contract。
- iOS / macOS 的 `renderer` 也还没有接入 `centerY + contentSized` 约束逻辑。

## 5. 最终状态总结

- shared 层现在已经有两种并行 contract：
  - `ExerciseFretboardLayoutContract`
  - `ExerciseNaturalNoteStripRailContract`
- `naturalNoteStrip` 的 right rail 场景现在不仅能被识别，还能输出完整的默认布局 contract。
- 这个 contract 只会在目标场景启用：
  - `sideBySide`
  - 左侧主 surface 是 `fretboard`
  - 右侧 secondary surface 是 `naturalNoteStrip` 的 `verticalRail`
  - secondary main-axis sizing 是 `fitContent`
- 其他场景保持 `nil`，避免把方案 B 误扩散到不相关布局。

## 6. 验证结果

- `ReadLints` 检查相关文件：无 linter 错误
- 构建验证命令：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- 构建结果：`BUILD SUCCEEDED`

## 7. 对后续阶段的直接意义

- 阶段 2 可以直接让 `iOSNaturalNoteStripView` 和 `macOSNaturalNoteStripView` 消费：
  - `buttonShape`
  - `buttonExtent`
  - `mainAxisPolicy`
  - `crossAxisPolicy`
- 阶段 3 可以直接让双端 `renderer` 消费：
  - `verticalAlignment`
  - `mainAxisPolicy = .contentSized`
  - `crossAxisPolicy = .fitContent`
- 到这一步，shared 侧关于 right rail 的“作用域 + 几何默认值”已经完成，不需要后面再回头补接口。

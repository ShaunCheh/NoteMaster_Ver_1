# 20260330_104121_phase1_piano_shared_models_and_validation

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260330_104121`
- 记录范围：实施“钢琴键盘组件”计划的阶段 1，只落 `Shared/Piano` 的配置、状态、交互基础类型与最小 validation runner
- 本次目标：在不接入 `iOS/macOS` 平台视图、不实现几何命中、不实现 reducer / layer 的前提下，先把钢琴组件的共享模型地基搭起来
- 本次实际新增文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `iOS/macOS` 视图壳层
- `PianoGeometry` / `PianoSceneBuilder`
- `PianoInteractionReducer`
- `PianoKeyboardLayer`
- `iOSAppDelegate.swift` / `macOSAppDelegate.swift`

## 本次结论

- 修改前，项目里还没有 `Shared/Piano/` 目录，也没有独立的钢琴配置、状态、交互、validation 基础模型
- 修改后，`Shared/Piano/` 已经具备阶段 1 所需的四块基础能力：
- `PianoConfiguration`：承接键宽、行高、A/B 区尺寸、黑键比例、吸附开关及安全钳制值
- `PianoRowState / PianoComponentState`：承接每行独立 `startNote + offsetX + movementScope`，以及 `preview` 与 `activeInteraction`
- `PianoInteraction`：承接 `A/B/C` 交互所需的 phase、zone、命中结果、交互会话和语义事件
- `PianoValidationRunner`：承接阶段 1 的最小自动化夹具与手工回归清单
- 本次修改仍然严格停留在计划里的阶段 1，没有提前下沉到平台层或绘制层

## 修改前总体现状

- 修改前，钢琴组件相关的共享模型是空白状态
- 项目里有现成的音高基础类型 `NotePitch`，也有指板交互类型 `FretboardInteraction`，但没有钢琴专用的 `Piano*` 类型
- 因此还无法在 Shared 层表达：
- 多行钢琴每行独立起始音
- `A/B/C` 三个区域的交互语义
- 钢琴自己的 validation runner

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/
// 函数名/符号: 不适用（目录不存在）
// 功能说明: 修改前项目内没有 Shared/Piano 目录，也没有钢琴组件自己的共享配置、状态、交互、验证文件。
(无代码)
```

## 修改 1：新增 `PianoConfiguration.swift`

### 修改前

- 修改前没有钢琴配置模型
- `whiteKeyWidth`、`rowHeight`、`scaleAreaHeight`、黑键比例、吸附开关这些参数都还没有共享承载对象
- 也没有对无效尺寸做统一的安全钳制出口

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前没有钢琴几何配置模型，后续 Geometry / Layer / 平台壳层还没有共同依赖的配置真相源。
(无代码)
```

### 修改后

- 新增 `PianoConfiguration`
- 固化了阶段 1 需要的配置字段：
- `whiteKeyWidth`
- `rowHeight`
- `rowSpacing`
- `scaleAreaHeight`
- `buttonAreaWidth`
- `blackKeyWidthRatio`
- `blackKeyHeightRatio`
- `snapEnabled`
- 同时新增了 `resolved*` 和 `keyAreaHeight`，把后续几何层要用到的安全值先统一好

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift
// 函数名/符号: PianoConfiguration.init(...), resolvedWhiteKeyWidth, resolvedScaleAreaHeight, keyAreaHeight
// 功能说明: 为钢琴组件提供统一配置真相源，并在 Shared 层先完成尺寸/比例的安全钳制。
struct PianoConfiguration: Equatable, Sendable {
    static let blackKeyWidthRatioRange: ClosedRange<CGFloat> = 0.2...0.95
    static let blackKeyHeightRatioRange: ClosedRange<CGFloat> = 0.2...1

    var whiteKeyWidth: CGFloat
    // rowHeight 表示单行总高度；顶部 A/B 区高度由 scaleAreaHeight 单独控制。
    var rowHeight: CGFloat
    var rowSpacing: CGFloat
    var scaleAreaHeight: CGFloat
    var buttonAreaWidth: CGFloat
    var blackKeyWidthRatio: CGFloat
    var blackKeyHeightRatio: CGFloat
    var snapEnabled: Bool

    var resolvedWhiteKeyWidth: CGFloat {
        max(whiteKeyWidth, 1)
    }

    var resolvedScaleAreaHeight: CGFloat {
        min(max(scaleAreaHeight, 0), resolvedRowHeight)
    }

    var keyAreaHeight: CGFloat {
        max(resolvedRowHeight - resolvedScaleAreaHeight, 0)
    }
}
```

## 修改 2：新增 `PianoState.swift`

### 修改前

- 修改前没有钢琴自己的状态模型
- 也就还无法在 Shared 层表达“每行独立 `startNote + offsetX + movementScope`”
- `preview`、`activeInteraction`、组件级 `rows` 也都没有状态容器

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前没有钢琴行状态和组件状态模型，无法表达多行联动和预览/交互会话。
(无代码)
```

### 修改后

- 新增 `PianoMovementScope`
- 新增 `PianoRowState`
- 新增 `PianoPreviewState`
- 新增 `PianoComponentState`
- 并补了两个便于后续 reducer 使用的小工具：
- `shiftedStartNote(by:)`
- `shiftedOffsetX(by:)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名/符号: PianoMovementScope, PianoRowState.shiftedStartNote(by:), PianoRowState.shiftedOffsetX(by:), PianoComponentState.rowState(at:)
// 功能说明: 固化多行钢琴的核心状态模型，明确每行独立 startNote/offsetX/movementScope，并为组件级 preview/interaction 预留容器。
enum PianoMovementScope: Equatable, Hashable, Sendable {
    case rowOnly
    case cascade
}

struct PianoRowState: Equatable, Sendable {
    var startNote: NotePitch
    var offsetX: CGFloat
    var movementScope: PianoMovementScope

    func shiftedStartNote(by semitones: Int) -> PianoRowState {
        var nextState = self
        nextState.startNote = startNote.advanced(by: semitones)
        return nextState
    }

    func shiftedOffsetX(by deltaX: CGFloat) -> PianoRowState {
        var nextState = self
        nextState.offsetX += deltaX
        return nextState
    }
}

struct PianoComponentState: Equatable, Sendable {
    var rows: [PianoRowState]
    var preview: PianoPreviewState?
    var activeInteraction: PianoInteractionState?

    func rowState(at rowIndex: Int) -> PianoRowState? {
        guard rows.indices.contains(rowIndex) else {
            return nil
        }
        return rows[rowIndex]
    }
}
```

## 修改 3：新增 `PianoInteraction.swift`

### 修改前

- 修改前没有钢琴自己的交互语义层
- `A/B/C` 的区分、按钮方向、命中结果、拖动会话、滑音会话、高层语义事件都还没有类型承载
- 这意味着后续即使写平台输入，也没有一套稳定的 Shared 交互结构可供 Geometry / Reducer 消费

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前没有钢琴组件专用的 phase / zone / hit result / semantic event / interaction state。
(无代码)
```

### 修改后

- 新增 `PianoEventPhase`
- 新增 `PianoStepDirection`
- 新增 `PianoZone`
- 新增 `PianoRawEvent`
- 新增 `PianoHitResult`
- 新增 3 类会话状态：
- `PianoButtonPressInteraction`
- `PianoScaleDragInteraction`
- `PianoKeyGlissandoInteraction`
- 新增 `PianoInteractionState` 和 `PianoSemanticEvent`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift
// 函数名/符号: PianoZone.buttonDirection, PianoHitResult.debugSummary(platform:), PianoInteractionState, PianoSemanticEvent
// 功能说明: 把 A/B/C 区交互拆成可共享的交互类型，为后续 Geometry 命中结果和 Reducer 状态机提供统一输入/输出结构。
enum PianoZone: Equatable, Hashable, Sendable {
    case buttonLeft
    case buttonRight
    case scale
    case keys
    case outside

    var buttonDirection: PianoStepDirection? {
        switch self {
        case .buttonLeft:
            return .left
        case .buttonRight:
            return .right
        case .scale, .keys, .outside:
            return nil
        }
    }
}

struct PianoHitResult: Equatable, Sendable {
    var phase: PianoEventPhase
    var locationInView: CGPoint
    var rowIndex: Int?
    var zone: PianoZone
    var note: NotePitch?
    var isInsideActiveZone: Bool

    var buttonDirection: PianoStepDirection? {
        zone.buttonDirection
    }
}

enum PianoInteractionState: Equatable, Sendable {
    case buttonPressed(PianoButtonPressInteraction)
    case scaleDrag(PianoScaleDragInteraction)
    case keyGlissando(PianoKeyGlissandoInteraction)
}

enum PianoSemanticEvent: Equatable, Sendable {
    case rowsChanged([PianoRowState])
    case previewStarted(PianoPreviewState)
    case previewChanged(PianoPreviewState)
    case previewEnded(PianoPreviewState)
}
```

## 修改 4：新增 `PianoValidation.swift`

### 修改前

- 修改前项目里只有 `FretboardValidationRunner` 和 `StaffValidationRunner`
- 钢琴组件还没有自己的 validation runner
- 阶段 1 的配置钳制、黑键起始音、混合作用域、按钮方向映射这些基础约束也还没有自动化夹具

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前钢琴组件没有 validation runner，也没有阶段 1 级别的自动化夹具和手工回归清单。
(无代码)
```

### 修改后

- 新增 `PianoValidationPlatform`
- 新增 `PianoValidationIssue`
- 新增 `PianoValidationReport`
- 新增 `PianoValidationRunner`
- 当前夹具覆盖：
- `configuration_resolves_safe_metrics`
- `accidental_start_note_is_preserved`
- `component_state_supports_mixed_scopes`
- `scale_drag_interaction_preserves_parallel_rows`
- `semantic_events_keep_preview_payload`
- `hit_result_maps_button_direction`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: PianoValidationRunner.run(platform:), runAndReportIfNeeded(platform:), makeFixtures(), validateConfigurationResolvesSafeMetrics()
// 功能说明: 延续项目现有 ValidationRunner 风格，为钢琴阶段 1 的共享模型建立最小自动化夹具与手工回归清单。
enum PianoValidationRunner {
    static func run(platform: PianoValidationPlatform) -> PianoValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [PianoValidationIssue] = []

        for fixture in fixtures {
            let fixtureIssues = validate(fixture)
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        return PianoValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: PianoValidationPlatform) {
        #if DEBUG
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)
        if !report.isPassing {
            assertionFailure(summary)
        }
        #endif
    }
}

private extension PianoValidationRunner {
    static func makeFixtures() -> [PianoValidationFixture] {
        [
            PianoValidationFixture(
                name: "configuration_resolves_safe_metrics",
                validate: validateConfigurationResolvesSafeMetrics
            ),
            PianoValidationFixture(
                name: "accidental_start_note_is_preserved",
                validate: validateAccidentalStartNote
            )
            // ... 其余阶段 1 基础夹具略 ...
        ]
    }
}
```

## 验证情况

- 本次不是只“写了文件没校验”，而是做了以下验证
- `ReadLints`：新增 `Shared/Piano` 目录无 linter 错误
- `swiftc -typecheck`：对新增文件做了语法/类型级检查，结果通过
- `xcodebuild`：尝试过整工程构建，但当前系统 active developer directory 指向 `CommandLineTools`，不是完整 Xcode，因此不能在本次记录里给出工程级 build pass

```text
// 验证命令: xcrun swiftc -typecheck ...
// 功能说明: 对 NotePitch.swift + 新增 Shared/Piano 文件做阶段 1 的语法/类型检查。
xcrun swiftc -typecheck \
  "NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoState.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift" \
  "NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift"

// 结果: 通过
```

```text
// 验证命令: xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" build
// 功能说明: 尝试做工程级构建验证，但当前机器未切到完整 Xcode。
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

## 本次明确没有做的事

- 没有新增 `PianoGeometry.swift`
- 没有新增 `PianoSceneBuilder.swift`
- 没有新增 `PianoInteractionReducer.swift`
- 没有新增 `PianoKeyboardLayer.swift` / `PianoRowLayer.swift`
- 没有把 `PianoValidationRunner` 挂到 `iOSAppDelegate.swift` 或 `macOSAppDelegate.swift`
- 没有实现 `iOSPianoKeyboardView` / `macOSPianoKeyboardView`

## 对后续阶段的影响

- 阶段 2 可以直接基于 `PianoConfiguration`、`PianoRowState`、`PianoHitResult` 去做几何与命中
- 阶段 3 可以直接基于 `PianoInteractionState` 和 `PianoSemanticEvent` 去做 reducer
- 阶段 4 以后平台壳层和 layer 代码，不需要再回头重塑阶段 1 的基础模型

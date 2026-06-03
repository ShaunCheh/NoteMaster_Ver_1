# 20260603_185346_fr0_circle_feedback_marker_shape_refactor

## 记录范围

本记录只覆盖刚刚这一轮把 `FR-0` 的反馈标记从“沿用 `singleCoverage` 的圆角矩形”改成“真正的圆形”，并补齐回归校验的实际修改。

整理依据来自当前工作区的：

- `date +%Y%m%d_%H%M%S`，得到时间戳：`20260603_185346`
- `git status --short`
- 这 6 个业务 Swift 文件的 `git diff --stat`
- 这 6 个业务 Swift 文件的 `git diff`

本文**不直接粘贴原始 `git diff`**，而是把真实改动按“修改前 / 修改后”的方式重新整理成可读片段。

## 当前 changes 说明

本轮业务代码涉及 6 个 Swift 文件：

- `NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`

对应代码统计为：

- `6 files changed`
- `653 insertions(+)`
- `25 deletions(-)`

当前工作区里还存在两个**非业务逻辑**的 changes：

- `NoteMaster_Ver_1.xcodeproj/project.xcworkspace/xcuserdata/shaun.xcuserdatad/UserInterfaceState.xcuserstate`
- `.build/`

其中：

- `xcuserstate` 是 IDE 本地界面状态写回
- `.build/` 是构建与 smoke 验证产生的本地产物

下面的修改说明与代码片段，**只覆盖上面那 6 个 Swift 业务文件**。

## 根因摘要

问题的根因不是“某个平台忘了画圆”，而是 shared 反馈链路里，`singleCoverage` 这个 overlay state 在修改前只携带 `correctCells / wrongCells`，**不携带 marker 形状**。  
结果就是：`FR-0` 虽然语义上需要圆形，但 shared 渲染层拿到的状态并不知道这一点，只能走默认的 `roundedRect` 路径。

这次修复按根因拆成三层：

1. 先把 `markerShape` 提升为 `singleCoverage` 的 shared 状态契约
2. 再让 `FretboardFeedbackLayer` 按 `markerShape` 在 `roundedRect / circle` 之间分派
3. 最后由 iOS / macOS 控制器在 `FR-0` 下明确传 `.circle`，普通 `single` 保持 `.roundedRect`

---

## 1. Shared 状态契约：`singleCoverage` 从“只带 cell”升级为“cell + markerShape”

修改前，`singleCoverage` 只保存正确/错误位置集合，渲染层无法从状态本身判断当前应该画圆还是圆角矩形。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift
// 函数名/符号: FretboardFeedbackOverlayState.singleCoverage / isEmpty
// 功能注释: 修改前，singleCoverage 只有对错 cell 集合，没有 marker 形状；
// 功能注释: 这意味着 FR-0 在 shared 层没有独立的“画圆”入口。
enum FretboardFeedbackOverlayState: Equatable, Sendable {
    enum PositionPromptPhase: Equatable, Sendable {
        case neutralWhite
        case wrongFlash
        case correctHold
    }

    case empty
    case singleCoverage(
        correctCells: Set<FretboardCell>,
        wrongCells: Set<FretboardCell>
    )
    case positionPrompt(
        promptCell: FretboardCell,
        phase: PositionPromptPhase
    )

    var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case let .singleCoverage(correctCells, wrongCells):
            return correctCells.isEmpty && wrongCells.isEmpty
        case .positionPrompt:
            return false
        }
    }
}
```

修改后，把 `markerShape` 正式放进 `singleCoverage` 的 shared 契约里，`FR-0` 需要画圆这件事终于能被稳定地向下传到渲染层。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackOverlayState.swift
// 函数名/符号: FretboardFeedbackOverlayState.SingleCoverageMarkerShape / singleCoverage / isEmpty
// 功能注释: 修改后，singleCoverage 明确携带 markerShape；
// 功能注释: 平台层只需声明 FR-0 用 .circle，其余模式用 .roundedRect，渲染层即可按状态工作。
enum FretboardFeedbackOverlayState: Equatable, Sendable {
    enum SingleCoverageMarkerShape: Equatable, Sendable {
        case roundedRect
        case circle
    }

    enum PositionPromptPhase: Equatable, Sendable {
        case neutralWhite
        case wrongFlash
        case correctHold
    }

    case empty
    case singleCoverage(
        correctCells: Set<FretboardCell>,
        wrongCells: Set<FretboardCell>,
        markerShape: SingleCoverageMarkerShape
    )
    case positionPrompt(
        promptCell: FretboardCell,
        phase: PositionPromptPhase
    )

    var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case let .singleCoverage(correctCells, wrongCells, _):
            return correctCells.isEmpty && wrongCells.isEmpty
        case .positionPrompt:
            return false
        }
    }
}
```

---

## 2. Shared 渲染链路：从固定 `roundedRect` 改为按 `markerShape` 分派

修改前，`singleCoverage` 分支固定调用 `drawFeedback`，里面只有 `CGPath(roundedRect: ...)`；只有 `positionPrompt` 才会走 `ellipseIn`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift
// 函数名/符号: draw(in:) / drawSingleCoverageFeedback / drawFeedback / positionPromptRect
// 功能注释: 修改前，singleCoverage 的绘制路径被硬编码为 roundedRect；
// 功能注释: positionPrompt 虽然会画圆，但它的圆形几何并没有开放给 FR-0 复用。
switch feedbackOverlayState {
case .empty:
    break
case let .singleCoverage(correctCells, wrongCells):
    drawSingleCoverageFeedback(
        correctCells: correctCells,
        wrongCells: wrongCells,
        in: context
    )
case let .positionPrompt(promptCell, phase):
    drawPositionPromptIndicator(
        for: promptCell,
        phase: phase,
        in: context
    )
}

private func drawFeedback(
    for cell: FretboardCell,
    fillColor: CGColor,
    strokeColor: CGColor,
    in context: CGContext
) {
    let highlightRect = insetFeedbackRect(for: cellFrame)
    let highlightPath = CGPath(
        roundedRect: highlightRect,
        cornerWidth: resolvedCornerRadius(for: highlightRect),
        cornerHeight: resolvedCornerRadius(for: highlightRect),
        transform: nil
    )
    // ... 省略未改动的 fill / stroke 代码 ...
}

private func drawPositionPromptIndicator(
    for cell: FretboardCell,
    phase: FretboardFeedbackOverlayState.PositionPromptPhase,
    in context: CGContext
) {
    let indicatorRect = positionPromptRect(for: cellFrame)
    let indicatorPath = CGPath(
        ellipseIn: indicatorRect,
        transform: nil
    )
    // ... 省略未改动的 fill / stroke 代码 ...
}
```

修改后，`singleCoverage` 也可以按状态选择 `roundedRect` 或 `circle`，并且 `FR-0` 与 `positionPrompt` 复用了同一个圆形几何出口 `circularMarkerRect`。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardFeedbackLayer.swift
// 函数名/符号: draw(in:) / drawSingleCoverageFeedback / drawSingleCoverageMarker / circularMarkerRect
// 功能注释: 修改后，singleCoverage 根据 markerShape 选择圆角矩形或圆形；
// 功能注释: circularMarkerRect 成为统一的圆形几何函数，FR-0 和 positionPrompt 共用同一套圆尺寸规则。
switch feedbackOverlayState {
case .empty:
    break
case let .singleCoverage(correctCells, wrongCells, markerShape):
    drawSingleCoverageFeedback(
        correctCells: correctCells,
        wrongCells: wrongCells,
        markerShape: markerShape,
        in: context
    )
case let .positionPrompt(promptCell, phase):
    drawPositionPromptIndicator(
        for: promptCell,
        phase: phase,
        in: context
    )
}

private func drawSingleCoverageMarker(
    for cell: FretboardCell,
    markerShape: FretboardFeedbackOverlayState.SingleCoverageMarkerShape,
    fillColor: CGColor,
    strokeColor: CGColor,
    in context: CGContext
) {
    let markerPath: CGPath
    let strokeWidth: CGFloat

    switch markerShape {
    case .roundedRect:
        let highlightRect = insetFeedbackRect(for: cellFrame)
        markerPath = CGPath(
            roundedRect: highlightRect,
            cornerWidth: resolvedCornerRadius(for: highlightRect),
            cornerHeight: resolvedCornerRadius(for: highlightRect),
            transform: nil
        )
        strokeWidth = resolvedStrokeWidth
    case .circle:
        let markerRect = circularMarkerRect(for: cellFrame)
        markerPath = CGPath(
            ellipseIn: markerRect,
            transform: nil
        )
        strokeWidth = resolvedCircularMarkerStrokeWidth
    }

    // ... 省略未改动的 fill / stroke 代码 ...
}

private func drawPositionPromptIndicator(
    for cell: FretboardCell,
    phase: FretboardFeedbackOverlayState.PositionPromptPhase,
    in context: CGContext
) {
    let indicatorRect = circularMarkerRect(for: cellFrame)
    let indicatorPath = CGPath(
        ellipseIn: indicatorRect,
        transform: nil
    )
    // ... 省略未改动的 fill / stroke 代码 ...
}

private func circularMarkerRect(for cellFrame: CGRect) -> CGRect {
    let minDimension = min(cellFrame.width, cellFrame.height)
    let maxDiameter = max(
        minDimension - (Style.positionPromptMinimumInset * 2),
        0
    )
    let preferredDiameter = minDimension * Style.positionPromptDiameterRatio
    let diameter = min(
        max(preferredDiameter, Style.positionPromptMinimumDiameter),
        maxDiameter
    )
    // ... 省略未改动的边界保护和返回代码 ...
}
```

---

## 3. 双平台 overlay 接线：`FR-0` 传 `.circle`，普通 `single` 保持 `.roundedRect`

修改前，iOS 和 macOS 的 `currentFretboardFeedbackOverlayState` 都只把 `correctCells / wrongCells` 传给 `singleCoverage`，没有形状选择。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: currentFretboardFeedbackOverlayState
// 功能注释: 修改前，平台层没有把“FR-0 要画圆”的意图传给 shared overlay state；
// 功能注释: macOS 同一位置的逻辑与这里同构，问题也完全一致。
private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
    // ... 省略未改动的 session / wrongCells 计算 ...
    return .singleCoverage(
        correctCells: singleCoverageSession.visitedCells,
        wrongCells: wrongCells
    )
}
```

修改后，iOS 在 `FR-0` 下明确传 `.circle`，而普通 `single` 继续用 `.roundedRect`，所以这次修复不会把旧模式的视觉语义一起改掉。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: currentFretboardFeedbackOverlayState
// 功能注释: 修改后，iOS 在 FR-0 下明确传 .circle；
// 功能注释: 同时保留 FR-0 的持久 wrongCells 行为，普通 single 仍然只显示单个最近错误并用 roundedRect。
private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
    // ... 省略未改动的 session / wrongCells 计算 ...
    return .singleCoverage(
        correctCells: singleCoverageSession.visitedCells,
        wrongCells: wrongCells,
        markerShape: trainerDisplayState.isFR0Mode
            ? .circle
            : .roundedRect
    )
}
```

macOS 侧做了对称修改，保持两端行为一致。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: currentFretboardFeedbackOverlayState
// 功能注释: 修改后，macOS 与 iOS 完全同构，FR-0 走 .circle，普通 single 保持 .roundedRect；
// 功能注释: 这样 shared 渲染层拿到的状态在双平台上是一致的。
private var currentFretboardFeedbackOverlayState: FretboardFeedbackOverlayState {
    // ... 省略未改动的 session / wrongCells 计算 ...
    return .singleCoverage(
        correctCells: singleCoverageSession.visitedCells,
        wrongCells: wrongCells,
        markerShape: trainerDisplayState.isFR0Mode
            ? .circle
            : .roundedRect
    )
}
```

---

## 4. Runtime smoke 入口：新增 `fr0-circle-feedback` 场景

修改前，两个 `AppDelegate` 都只有既有的 `SR0 / SR1 / SR2 / layout / startup-validation` 场景，没有 `FR-0` 圆形反馈的专项入口。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名/符号: application(_:didFinishLaunchingWithOptions:) / RuntimeSmokeScenario
// 功能注释: 修改前，没有 FR-0 circle feedback 的独立 smoke 场景值，也没有对应分派。
if RuntimeSmokeScenario.shouldRunSR0NoteStripAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunSR2PianoAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ...
}

private enum RuntimeSmokeScenario {
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let sr2PianoAnswerValue = "sr2-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"
}
```

修改后，iOS 侧新增了 `fr0-circle-feedback` 的环境变量值与调度逻辑，直接把入口接到专用 smoke 函数。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名/符号: application(_:didFinishLaunchingWithOptions:) / RuntimeSmokeScenario
// 功能注释: 修改后，iOS 可以通过 NOTE_MASTER_RUNTIME_SMOKE_TEST=fr0-circle-feedback
// 功能注释: 直接调起 FR-0 圆形反馈回归场景，验证 shared 状态、渲染选择和模式切换恢复。
if RuntimeSmokeScenario.shouldRunSR0NoteStripAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunSR2PianoAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunFR0CircleFeedbackSmoke {
    viewController.runFR0CircleFeedbackSmokeTest(
        in: window
    ) { passed, summary in
        print(summary)
        if passed {
            exit(0)
        } else {
            fatalError(summary)
        }
    }
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ...
}

private enum RuntimeSmokeScenario {
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let sr2PianoAnswerValue = "sr2-piano-answer"
    static let fr0CircleFeedbackValue = "fr0-circle-feedback"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"

    static var shouldRunFR0CircleFeedbackSmoke: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == fr0CircleFeedbackValue
    }
}
```

macOS 侧做了同样的接线，确保桌面端也能直接跑到这条回归路径。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名/符号: applicationDidFinishLaunching(_:) / RuntimeSmokeScenario
// 功能注释: 修改后，macOS 与 iOS 使用同名 smoke 场景值 fr0-circle-feedback；
// 功能注释: 这样可以在 macOS 真机窗口链路里验证 FR-0 的圆形反馈与切回 single 的恢复行为。
if RuntimeSmokeScenario.shouldRunSR0NoteStripAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunSR2PianoAnswerSmoke {
    // ...
} else if RuntimeSmokeScenario.shouldRunFR0CircleFeedbackSmoke {
    viewController.runFR0CircleFeedbackSmokeTest(
        in: window
    ) { passed, summary in
        print(summary)
        if passed {
            NSApp.terminate(nil)
        } else {
            fatalError(summary)
        }
    }
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ...
}

private enum RuntimeSmokeScenario {
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let sr2PianoAnswerValue = "sr2-piano-answer"
    static let fr0CircleFeedbackValue = "fr0-circle-feedback"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"

    static var shouldRunFR0CircleFeedbackSmoke: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == fr0CircleFeedbackValue
    }
}
```

---

## 5. 新增专项 smoke 函数：验证 `FR-0 -> circle` 与 `single -> roundedRect`

修改前，这两个控制器扩展里都没有 `runFR0CircleFeedbackSmokeTest(in:completion:)`，只有原本的 `SR0` 和 layout 回归函数。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: extension iOSViewController runtime smoke API
// 功能注释: 修改前，iOS 只有既有 smoke 入口，没有 FR-0 圆形反馈专项函数；
// 功能注释: macOS 同名扩展在修改前也处于同样状态。
func runSR0NoteStripAnswerSmokeTest(
    in window: UIWindow,
    completion: @escaping (Bool, String) -> Void
) {
    // ...
}

func runLayoutPresetRegressionSmokeTest(
    in window: UIWindow,
    completion: @escaping (Bool, String) -> Void
) {
    // ...
}
```

修改后，iOS 新增 `runFR0CircleFeedbackSmokeTest`，在同一个 smoke 里把“切到 FR-0 后应该是圆形”“wrong/correct 过程中仍保持圆形”“切回 single 后恢复 roundedRect”一次性校验完。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: runFR0CircleFeedbackSmokeTest(in:completion:)
// 功能注释: 修改后，iOS 侧新增 FR-0 圆形反馈专项 smoke；
// 功能注释: 该函数不只校验开始时是 circle，还会校验 wrong/correct 过程中 circle 不丢失，
// 功能注释: 并在切回 single 后断言 markerShape 恢复为 roundedRect。
func runFR0CircleFeedbackSmokeTest(
    in window: UIWindow,
    completion: @escaping (Bool, String) -> Void
) {
    func currentMarkerShape()
        -> FretboardFeedbackOverlayState.SingleCoverageMarkerShape?
    {
        guard
            case let .singleCoverage(_, _, markerShape)
                = self.currentFretboardFeedbackOverlayState
        else {
            return nil
        }
        return markerShape
    }

    let steps: [SmokeStep] = [
        (
            name: "switch_to_fr0",
            action: {
                self.handleSettingsPanelEvent(
                    .triggerAction(.setExerciseModeFr0)
                )
            },
            validate: {
                guard currentMarkerShape() == .circle else {
                    return "reason=marker_shape_not_circle ..."
                }
                return nil
            }
        ),
        // 功能注释: 中间还有 wrong_fr0_answer / correct_fr0_answer 两步，
        // 功能注释: 会继续验证 wrongCells 持久保留、correctCells 正确累计，且 markerShape 始终为 .circle。
        (
            name: "switch_back_to_single",
            action: {
                self.handleSettingsPanelEvent(
                    .triggerAction(.setExerciseModeSingle)
                )
            },
            validate: {
                guard
                    case let .singleCoverage(_, wrongCells, markerShape)
                        = self.currentFretboardFeedbackOverlayState
                else {
                    return "reason=missing_single_overlay_after_switch_back ..."
                }
                guard wrongCells.isEmpty else {
                    return "reason=single_mode_wrong_cells_not_cleared ..."
                }
                guard markerShape == .roundedRect else {
                    return "reason=single_mode_shape_not_rounded_rect ..."
                }
                return nil
            }
        )
    ]

    runExerciseAnswerSmokeSteps(
        steps,
        index: 0,
        scenarioName: "fr0_circle_feedback",
        settleLayout: settleLayout,
        successSummary: {
            "[RuntimeSmoke][iOS] PASS scenario=fr0_circle_feedback ..."
        },
        completion: completion
    )
}
```

macOS 侧新增了同名函数与同构断言，保证双平台回归点一致。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: runFR0CircleFeedbackSmokeTest(in:completion:)
// 功能注释: 修改后，macOS 侧新增与 iOS 对称的 FR-0 圆形反馈专项 smoke；
// 功能注释: 它验证的不是单一 UI 结果，而是整条状态链路：FR-0 时 .circle，切回 single 时 .roundedRect。
func runFR0CircleFeedbackSmokeTest(
    in window: NSWindow,
    completion: @escaping (Bool, String) -> Void
) {
    func currentMarkerShape()
        -> FretboardFeedbackOverlayState.SingleCoverageMarkerShape?
    {
        guard
            case let .singleCoverage(_, _, markerShape)
                = self.currentFretboardFeedbackOverlayState
        else {
            return nil
        }
        return markerShape
    }

    let steps: [SmokeStep] = [
        (
            name: "switch_to_fr0",
            action: {
                self.handleSettingsPanelEvent(
                    .triggerAction(.setExerciseModeFr0)
                )
            },
            validate: {
                guard currentMarkerShape() == .circle else {
                    return "reason=marker_shape_not_circle ..."
                }
                return nil
            }
        ),
        // 功能注释: 中间还会验证 wrong / correct 两步保持 .circle，
        // 功能注释: 最后一跳切回 single 后要求 markerShape 恢复为 .roundedRect。
        (
            name: "switch_back_to_single",
            action: {
                self.handleSettingsPanelEvent(
                    .triggerAction(.setExerciseModeSingle)
                )
            },
            validate: {
                guard
                    case let .singleCoverage(_, wrongCells, markerShape)
                        = self.currentFretboardFeedbackOverlayState
                else {
                    return "reason=missing_single_overlay_after_switch_back ..."
                }
                guard wrongCells.isEmpty else {
                    return "reason=single_mode_wrong_cells_not_cleared ..."
                }
                guard markerShape == .roundedRect else {
                    return "reason=single_mode_shape_not_rounded_rect ..."
                }
                return nil
            }
        )
    ]

    runExerciseAnswerSmokeSteps(
        steps,
        index: 0,
        scenarioName: "fr0_circle_feedback",
        settleLayout: settleLayout,
        successSummary: {
            "[RuntimeSmoke][macOS] PASS scenario=fr0_circle_feedback ..."
        },
        completion: completion
    )
}
```

---

## 验证结果

本轮改动完成后，已经实际执行并通过了以下验证：

- `macOS Debug build` 通过
- `iOS Simulator Debug build` 通过
- `macOS startup-validation` 通过
- `macOS fr0-circle-feedback runtime smoke` 通过

## 本轮结论

这次修改不是简单把某处 `roundedRect` 临时替换成 `ellipseIn`，而是从 shared 状态契约开始，把 `singleCoverage` 的“形状选择权”补齐为正式能力：

- `FR-0` 现在有了真正的 `.circle` 渲染通路
- `Position` 原本的圆形几何被复用，没有另起一套尺寸逻辑
- 普通 `single` 仍然保持原有的 `.roundedRect` 视觉语义
- 双平台都有对称改动和专项 smoke，后续回归时更容易第一时间发现形状退化

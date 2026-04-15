# 20260415_214900_stage6_sr0_validation_runtime_smoke

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_214900`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat -- ...`、按文件 `git diff -- ...`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` / runtime smoke 结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr0_双行strip_计划_632caead.plan.md` 实施阶段 6 的真实落地代码改动；目标是补齐 `SR-0` 的 automated validation seam、双端 `runtime smoke` 与回归清单，并把验证过程中暴露出的 shared 根因一并收口
- 重要说明：
- 本轮第一次启动 `SR-0` smoke 时，`ExerciseCompositionValidation` 先暴露出真实 shared 回归：`ExerciseCompositionPolicy.makePresentation(...)` 会在 fixed `SR-0` 模式下因为 `pianoPanelState.isVisible` 再次把 accessory piano 混回主场景，导致 `staff_to_natural_note_strip_scene_promotes_main_natural_note_strip_answer_surface` 失败
- 上述 shared 根因修复后，第一次 `SR-0` smoke 的 `switch_back_to_single` 断言又暴露出一个 smoke 合同写得过死的问题：`single` 模式下 `natural note strip` 可以继续作为 accessory 保留，但不应继续是 answer surface；因此最终断言收口为“strip 不再 answer-enabled / 不再可作为 SR-0 主答题面”
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`7 files changed, 611 insertions(+), 19 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 7 个 `Swift` 文件，因此本次统计口径直接等同于阶段 6 本轮改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `7 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次确认但未修改的关键文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- 上述 shared validation 文件在阶段 3 / 5 已经接入了对应 `SR-0` 夹具；本轮通过启动链和 smoke 复跑验证，没有新增代码改动
- 验证结果：
- `ReadLints`：对本轮 7 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" -derivedDataPath "/tmp/NoteMasterStage6SR0-mac-build" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath "/tmp/NoteMasterStage6SR0-ios-build" build`：`BUILD SUCCEEDED`
- `macOS` 启动验证链：`FretboardValidation / StaffValidation / SettingsNavigationValidation / PianoValidation / PlaybackValidation / PlayCompositionValidation / ExerciseCompositionValidation` 最终均为 `automated=PASS`，其中 `ExerciseCompositionValidation` 为 `fixtures=37`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer`：macOS 运行结果为 `PASS scenario=sr0_note_strip_answer finalMode=single stripVisible=true`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr0-note-strip-answer`：iOS Simulator 运行结果为 `PASS scenario=sr0_note_strip_answer finalMode=single stripVisible=true`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：macOS 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer`：iOS Simulator 运行结果为 `PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false`
- 本次没做的事情：
- 没有修改 `@.cursor/plans/sr0_双行strip_计划_632caead.plan.md`
- 没有新增除本记录文件外的其它 markdown
- 没有提交代码

## 本次结论

- `FretboardValidation` 现在正式锁住了 `SR-0` 的 `resolvedSequenceConfiguration` seam：`treble + pitchClass + usesQuarterNoteSequenceKernel`
- `ExerciseCompositionPolicy.makePresentation(...)` 已从 shared 层阻止 fixed `SR-0` 模式被 `pianoPanelState.isVisible` 重新混回 accessory piano，根因上修复了 `staff + strip` 主场景被污染的问题
- iOS / macOS 都已接入 `sr0-note-strip-answer` runtime smoke，并把既有 `sr1-piano-answer` 改为共用 smoke runner，防止方案一引入 `SR-1` 回归
- `ExerciseCompositionValidation` 的手工回归清单已补到 `SR-0` 与方案一全局 `horizontalStrip` 语义

## 修改 1：在 `FretboardValidation` 中锁住 `SR-0` 的 sequence seam

### 修改前

- `validateQuarterNoteSequenceTrainer(...)` 的 `modePolicySeam` 只从 `SR-1` 开始，`SR-0` 还没有进入 shared seam 验证

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: FretboardValidationRunner.validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改前 quarter-note sequence 的 mode seam 只验证了 `SR-1` / `SR-2`；
// `SR-0` 还没有被锁进 resolvedSequenceConfiguration 合同。
logStage("modePolicySeam")
let sr1DisplayState = TrainerDisplayState(
    exerciseMode: .sr1,
    sequenceConfiguration: TrainerSequenceConfiguration(
        clef: .bass,
        noteCount: 7,
        includesAccidentals: false,
        answerPolicy: .exactNote
    )
)
let sr1ResolvedSequenceConfiguration = sr1DisplayState
    .resolvedSequenceConfiguration
if !sr1DisplayState.usesQuarterNoteSequenceKernel {
    record("SR-1 display state 应继续复用 quarter-note sequence kernel。")
}
```

### 修改后

- 先显式构造 `SR-0` 的反向输入，再断言 mode constraint 最终一定收敛到 `treble + pitchClass`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: FretboardValidationRunner.validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后 `SR-0` seam 被正式纳入 shared validation；
// 即便外部塞入 `bass + exactNote`，resolved configuration 仍必须回到 `treble + pitchClass`。
logStage("modePolicySeam")
let sr0DisplayState = TrainerDisplayState(
    exerciseMode: .sr0,
    sequenceConfiguration: TrainerSequenceConfiguration(
        clef: .bass,
        noteCount: 5,
        includesAccidentals: true,
        answerPolicy: .exactNote
    )
)
let sr0ResolvedSequenceConfiguration = sr0DisplayState
    .resolvedSequenceConfiguration
if !sr0DisplayState.usesQuarterNoteSequenceKernel {
    record("SR-0 display state 应继续复用 quarter-note sequence kernel。")
}
if sr0ResolvedSequenceConfiguration.clef != .treble {
    record("SR-0 的 resolvedSequenceConfiguration 应强制锁定 treble clef。")
}
if sr0ResolvedSequenceConfiguration.answerPolicy != .pitchClass {
    record("SR-0 的 resolvedSequenceConfiguration.answerPolicy 应固定为 .pitchClass。")
}
if sr0ResolvedSequenceConfiguration.noteCount != 5
    || !sr0ResolvedSequenceConfiguration.includesAccidentals {
    record("SR-0 mode constraint 不应篡改 noteCount 或 includesAccidentals。")
}

let sr1DisplayState = TrainerDisplayState(
    exerciseMode: .sr1,
    sequenceConfiguration: TrainerSequenceConfiguration(
        clef: .bass,
        noteCount: 7,
        includesAccidentals: false,
        answerPolicy: .exactNote
    )
)
```

## 修改 2：在 `ExerciseCompositionPolicy` 从根因阻止 fixed SR 模式把 accessory piano 混回主场景

### 修改前

- 只要 `pianoPanelState.isVisible == true`，`makePresentation(...)` 就会把 `isPianoAccessoryVisible` 打开
- 这条逻辑不区分 fixed `SR-0 / SR-1 / SR-2` 模式，导致 fixed 主场景也可能被 accessory piano 污染

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.makePresentation(from:)
// 功能说明: 修改前只要 piano panel 当前是 visible，就会尝试把 accessory piano 并回 resolved layout；
// 这在 fixed `SR-0` 模式下会破坏 `staff + strip` 主场景合同。
static func makePresentation(
    from input: ExerciseCompositionPolicyInput
) -> ExercisePresentationState {
    var resolvedLayoutPreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            input.layoutPreferences,
            trainerDisplayState: input.trainerDisplayState
        )
    resolvedLayoutPreferences.isPianoAccessoryVisible =
        resolvedLayoutPreferences.isPianoAccessoryVisible
        || (
            input.pianoPanelState.isVisible
                && !resolvedLayoutPreferences.compositionPreset
                .usesMainPianoAnswerSurface
        )
    let scene = makeScene(
        preferences: resolvedLayoutPreferences
    )
    // ... 省略后文未变逻辑 ...
}
```

### 修改后

- 先用 `fixedExerciseLayoutPreferences == nil` 作为 shared gate
- 只有非 fixed mode 才允许根据 `pianoPanelState.isVisible` 自动提升 accessory piano

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
// 函数名/符号: ExerciseCompositionPolicy.makePresentation(from:)
// 功能说明: 修改后 fixed exercise presentation mode 不再允许 accessory piano promotion；
// 这样 `SR-0` / `SR-1` / `SR-2` 的 fixed 主场景不会再被当前 panel 可见性反向污染。
static func makePresentation(
    from input: ExerciseCompositionPolicyInput
) -> ExercisePresentationState {
    var resolvedLayoutPreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            input.layoutPreferences,
            trainerDisplayState: input.trainerDisplayState
        )
    let allowsAccessoryPianoPromotion =
        input.trainerDisplayState.exerciseMode.fixedExerciseLayoutPreferences
        == nil
    resolvedLayoutPreferences.isPianoAccessoryVisible =
        resolvedLayoutPreferences.isPianoAccessoryVisible
        || (
            allowsAccessoryPianoPromotion
                && input.pianoPanelState.isVisible
                && !resolvedLayoutPreferences.compositionPreset
                .usesMainPianoAnswerSurface
        )
    let scene = makeScene(
        preferences: resolvedLayoutPreferences
    )
    // ... 省略后文未变逻辑 ...
}
```

## 修改 3：在 `ExerciseCompositionValidation` 补齐阶段 6 手工回归清单

### 修改前

- 手工清单只强调了 `positionPrompt` 底部 `horizontalStrip` 与 `SR-1`
- 还没有把 `SR-0` 主视觉、答题反馈、以及 `SR-0 / SR-1` 互切清理写进 checklist

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.manualChecklist(for:)
// 功能说明: 修改前阶段 6 的 checklist 还没有 `SR-0` 回归项；
// 对方案一的描述也还没有把 `stacked` 语义说得更明确。
var checklist = [
    "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
    "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合；其中底部 `horizontalStrip` 合同在方案一中固定对应“上半音、下自然音”的双行语义。",
    // ... 省略中间未变项 ...
    "确认 `stacked + vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 或 `side` 后该滑块消失，切回 `stacked + vertical` 后沿用上次值。",
    "确认切到 `SR-1` 后主视觉稳定收敛到 `treble staff + 单行 piano`，不会再把 `piano accessory` 或 legacy page 投影混回主场景。",
    "确认 `SR-1` 下钢琴答错会给五线谱错误反馈、答对会推进到下一题；随后切回非 SR 模式时不会残留 sequence 高亮或钢琴答题缓存。"
]
```

### 修改后

- 把 `positionPrompt` 的描述收口为 `stacked` 双行 `horizontalStrip`
- 新增 `SR-0` 主视觉 / 反馈项，并把最后一条升级为 `SR-0` 与 `SR-1` 互切清理

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名/符号: ExerciseCompositionValidationRunner.manualChecklist(for:)
// 功能说明: 修改后 checklist 会明确覆盖方案一的全局 `horizontalStrip` 语义、`SR-0` 主答题链路，
// 以及 `SR-0 / SR-1` 互切后的状态清理边界。
var checklist = [
    "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
    "确认 `positionPrompt` 继续使用上方 `fretboard`、下方 `natural note strip` 的主视觉组合；其中 `stacked` 底部 `horizontalStrip` 合同在方案一中固定对应“上半音、下自然音”的双行语义。",
    // ... 省略中间未变项 ...
    "确认 `stacked + vertical` 模式下保留 `Viewport Height` 滑块；切到 `horizontal` 或 `side` 后该滑块消失，切回 `stacked + vertical` 后沿用上次值。",
    "确认切到 `SR-0` 后主视觉稳定收敛到 `treble staff + 双行 natural note strip`，strip 答错会给五线谱错误反馈、答对会推进到下一题。",
    "确认切到 `SR-1` 后主视觉稳定收敛到 `treble staff + 单行 piano`，不会再把 `piano accessory` 或 legacy page 投影混回主场景。",
    "确认在 `SR-0` 与 `SR-1` 之间互切，再切回非 SR 模式时，不会残留 sequence 高亮、strip / piano 旧答案缓存，answer surface 交互状态也会随模式正确清理。"
]
```

## 修改 4：在 `iOS / macOS AppDelegate` 接入 `sr0-note-strip-answer` 启动场景

### 修改前

- 启动入口只认识 `sr1-piano-answer / layout-preset-regression / startup-validation`
- 还不能从环境变量直接调度 `SR-0` smoke

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名/符号: iOSAppDelegate.application(_:didFinishLaunchingWithOptions:) / RuntimeSmokeScenario
// 功能说明: 修改前 iOS 启动入口只调度 `SR-1` 与布局回归 smoke；
// `SR-0` 还没有独立 scenario 值。
#if DEBUG
if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    print("[RuntimeSmoke][iOS] scheduled scenario=sr1_piano_answer")
    // ... 省略后文未变逻辑 ...
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    print("[RuntimeSmoke][iOS] scheduled scenario=layout_preset_regression")
    // ... 省略后文未变逻辑 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"
}
#endif
```

### 修改后

- iOS / macOS 两端都新增 `sr0-note-strip-answer` 环境值和调度分支
- 成功后分别 `exit(0)` / `NSApp.terminate(nil)`，失败则 `fatalError(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名/符号: iOSAppDelegate.application(_:didFinishLaunchingWithOptions:) / RuntimeSmokeScenario
// 功能说明: 修改后 iOS 启动入口先识别 `sr0-note-strip-answer`；
// 这样可以通过环境变量直接拉起 `SR-0` smoke，而不影响既有 `SR-1` / layout smoke。
#if DEBUG
if RuntimeSmokeScenario.shouldRunSR0NoteStripAnswerSmoke {
    print("[RuntimeSmoke][iOS] scheduled scenario=sr0-note-strip-answer")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let rootViewController = window.rootViewController
            as? iOSRootViewController,
            let viewController = rootViewController.activeExerciseViewController
        else {
            let summary =
                "[RuntimeSmoke][iOS] FAIL scenario=sr0-note-strip-answer reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }

        viewController.runSR0NoteStripAnswerSmokeTest(
            in: window
        ) { passed, summary in
            print(summary)
            if passed {
                exit(0)
            } else {
                fatalError(summary)
            }
        }
    }
} else if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    print("[RuntimeSmoke][iOS] scheduled scenario=sr1_piano_answer")
    // ... 省略后文未变逻辑 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"

    static var shouldRunSR0NoteStripAnswerSmoke: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == sr0NoteStripAnswerValue
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名/符号: macOSAppDelegate.applicationDidFinishLaunching(_:) / RuntimeSmokeScenario
// 功能说明: 修改后 macOS 入口镜像接入 `sr0-note-strip-answer`；
// 与 iOS 保持同一套 scenario naming 和失败语义，只把成功退出方式换成 `NSApp.terminate(nil)`。
#if DEBUG
if RuntimeSmokeScenario.shouldRunSR0NoteStripAnswerSmoke {
    print("[RuntimeSmoke][macOS] scheduled scenario=sr0-note-strip-answer")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let rootViewController = window.contentViewController
            as? macOSRootViewController,
            let viewController = rootViewController.activeExerciseViewController
        else {
            let summary =
                "[RuntimeSmoke][macOS] FAIL scenario=sr0-note-strip-answer reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }

        viewController.runSR0NoteStripAnswerSmokeTest(
            in: window
        ) { passed, summary in
            print(summary)
            if passed {
                NSApp.terminate(nil)
            } else {
                fatalError(summary)
            }
        }
    }
} else if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    print("[RuntimeSmoke][macOS] scheduled scenario=sr1_piano_answer")
    // ... 省略后文未变逻辑 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"
}
#endif
```

## 修改 5：在 `iOS / macOS ViewController` 新增 `SR-0` smoke，并把 `SR-1 / SR-0` 统一到共享 runner

### 修改前

- `SR-1` 只走专用的 `runSR1PianoAnswerSmokeSteps(...)`
- 没有 `runSR0NoteStripAnswerSmokeTest(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: iOSViewController.runSR1PianoAnswerSmokeTest(in:completion:) / runSR1PianoAnswerSmokeSteps(_:index:settleLayout:completion:)
// 功能说明: 修改前 iOS 只有 `SR-1` 钢琴 smoke；
// 执行器和场景都写死在 `runSR1PianoAnswerSmokeSteps` 里，无法复用给 `SR-0`。
print(
    "[RuntimeSmoke][iOS] begin scenario=sr1_piano_answer initialMode=\(String(describing: trainerDisplayState.exerciseMode))"
)
runSR1PianoAnswerSmokeSteps(
    steps,
    index: 0,
    settleLayout: settleLayout,
    completion: completion
)

private func runSR1PianoAnswerSmokeSteps(
    _ steps: [(name: String, action: () -> Void, validate: () -> String?)],
    index: Int,
    settleLayout: @escaping () -> Void,
    completion: @escaping (Bool, String) -> Void
) {
    guard index < steps.count else {
        let summary =
            "[RuntimeSmoke][iOS] PASS scenario=sr1_piano_answer finalMode=\(String(describing: trainerDisplayState.exerciseMode)) pianoVisible=\(exercisePresentationState.isSurfaceVisible(.piano))"
        completion(true, summary)
        return
    }
    // ... 省略递归执行逻辑 ...
}
```

### 修改后

- 把 `SR-1` 的递归 runner 提炼成 `runExerciseAnswerSmokeSteps(...)`
- 新增 `runSR0NoteStripAnswerSmokeTest(...)`，覆盖 `switch_to_sr0 / wrong_strip_answer / correct_strip_answer / switch_back_to_single`
- `switch_back_to_single` 的最终断言收口为“strip 不再 answer-enabled / 不再可交互”，而不是错误要求 strip 必须彻底消失

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: iOSViewController.runSR0NoteStripAnswerSmokeTest(in:completion:) / runExerciseAnswerSmokeSteps(_:index:scenarioName:settleLayout:successSummary:completion:)
// 功能说明: 修改后 iOS 新增 `SR-0` 专项 smoke，并把 `SR-1` / `SR-0` 都统一到共享执行器；
// `SR-0` 会验证 fixed layout、双行 strip 拓扑、错答 / 正答反馈，以及切回 `single` 后 answer surface 清理。
func runSR0NoteStripAnswerSmokeTest(
    in window: UIWindow,
    completion: @escaping (Bool, String) -> Void
) {
    typealias SmokeStep = (
        name: String,
        action: () -> Void,
        validate: () -> String?
    )
    var wrongPitchClass: PitchClass?
    var correctPitchClass: PitchClass?

    func currentExpectedPitchClass() -> PitchClass? {
        if let currentItem = quarterNoteSequenceSession?.currentItem {
            return currentItem.answerPitchClass
        }
        return currentGeneratedQuarterNoteSequence?.items.first?.answerPitchClass
    }

    let steps: [SmokeStep] = [
        (
            name: "switch_to_sr0",
            action: {
                self.handleSettingsPanelEvent(
                    .triggerAction(.setExerciseModeSr0)
                )
            },
            validate: {
                guard self.exerciseLayoutPreferences == .srNoteStripAnswer else {
                    return "reason=layout_not_fixed resolvedLayout=\(String(describing: self.exerciseLayoutPreferences))"
                }
                guard self.exercisePresentationState.projectedSurfaceState(for: .naturalNoteStrip) == .answerOnly else {
                    return "reason=strip_not_answer_only"
                }
                guard let stripLayout = self.exercisePresentationState.naturalNoteStripHorizontalLayout,
                      stripLayout.accidentalPlacements.allSatisfy({ $0.row == .accidentalsTop }),
                      stripLayout.naturalPlacements.allSatisfy({ $0.row == .naturalsBottom }) else {
                    return "reason=strip_layout_rows_incorrect"
                }
                return nil
            }
        ),
        (
            name: "wrong_strip_answer",
            action: {
                // ... 省略 wrong pitchClass 生成 ...
            },
            validate: {
                guard let evaluation = self.quarterNoteSequenceLastEvaluation,
                      !evaluation.isCorrect,
                      evaluation.answeredNotePitch == nil else {
                    return "reason=missing_or_invalid_wrong_evaluation"
                }
                return nil
            }
        ),
        (
            name: "switch_back_to_single",
            action: {
                self.handleSettingsPanelEvent(
                    .triggerAction(.setExerciseModeSingle)
                )
            },
            validate: {
                guard self.exercisePresentationState.projectedSurfaceState(for: .naturalNoteStrip) != .answerOnly,
                      !self.exercisePresentationState
                        .effectiveSurfaceState(for: .naturalNoteStrip)
                        .isAnswerEnabled,
                      !self.naturalNoteStripView.isUserInteractionEnabled else {
                    return "reason=strip_answer_surface_not_cleared"
                }
                return nil
            }
        )
    ]

    runExerciseAnswerSmokeSteps(
        steps,
        index: 0,
        scenarioName: "sr0_note_strip_answer",
        settleLayout: settleLayout,
        successSummary: {
            "[RuntimeSmoke][iOS] PASS scenario=sr0_note_strip_answer finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) stripVisible=\(self.exercisePresentationState.isSurfaceVisible(.naturalNoteStrip))"
        },
        completion: completion
    )
}

private func runExerciseAnswerSmokeSteps(
    _ steps: [(name: String, action: () -> Void, validate: () -> String?)],
    index: Int,
    scenarioName: String,
    settleLayout: @escaping () -> Void,
    successSummary: @escaping () -> String,
    completion: @escaping (Bool, String) -> Void
) {
    guard index < steps.count else {
        completion(true, successSummary())
        return
    }
    // ... 省略共享递归执行逻辑 ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: macOSViewController.runSR0NoteStripAnswerSmokeTest(in:completion:) / runExerciseAnswerSmokeSteps(_:index:scenarioName:settleLayout:successSummary:completion:)
// 功能说明: 修改后 macOS 侧与 iOS 保持同一 smoke 拓扑；
// 主要差异只剩下 `layoutSubtreeIfNeeded` 与 `naturalNoteStripView.areButtonsEnabled` 这类平台 API。
func runSR0NoteStripAnswerSmokeTest(
    in window: NSWindow,
    completion: @escaping (Bool, String) -> Void
) {
    // ... 省略与 iOS 对齐的前置状态与 step 构造 ...

    runExerciseAnswerSmokeSteps(
        steps,
        index: 0,
        scenarioName: "sr0_note_strip_answer",
        settleLayout: settleLayout,
        successSummary: {
            "[RuntimeSmoke][macOS] PASS scenario=sr0_note_strip_answer finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) stripVisible=\(self.exercisePresentationState.isSurfaceVisible(.naturalNoteStrip))"
        },
        completion: completion
    )
}

private func runExerciseAnswerSmokeSteps(
    _ steps: [(name: String, action: () -> Void, validate: () -> String?)],
    index: Int,
    scenarioName: String,
    settleLayout: @escaping () -> Void,
    successSummary: @escaping () -> String,
    completion: @escaping (Bool, String) -> Void
) {
    guard index < steps.count else {
        completion(true, successSummary())
        return
    }
    // ... 省略共享递归执行逻辑 ...
}
```

## 验证过程中真实暴露的问题与修正

- 第一次双端 `xcodebuild` 失败，错误为：
- `iOSViewController.swift:2010: error: value of type 'StaffClef' has no member 'rawValue'`
- `macOSViewController.swift:2416: error: value of type 'StaffClef' has no member 'rawValue'`
- 修正方式：把 smoke 里的 `resolvedClef` 输出从 `.rawValue` 改为 `String(describing: resolvedSequenceConfiguration.clef)`，随后双端重新构建通过
- 第一次 macOS `SR-0` smoke 启动时，`ExerciseCompositionValidation` 失败：
- `[staff_to_natural_note_strip_scene_promotes_main_natural_note_strip_answer_surface] SR-0 的 makePresentation 应固定收敛到 srNoteStripAnswer`
- `[staff_to_natural_note_strip_scene_promotes_main_natural_note_strip_answer_surface] staffToNaturalNoteStrip scene 不应混入 fretboard 或 piano`
- 根因修正：见上文 `ExerciseCompositionPolicy.makePresentation(...)` 的 `allowsAccessoryPianoPromotion` gate
- 第一次 macOS `SR-0` smoke 在 `switch_back_to_single` 步骤失败，原因为 `reason=strip_surface_still_active`
- 解释与修正：
- 失败原因不是产品 bug，而是 smoke 断言过度要求 strip 必须完全消失
- 按当前 shared contract，切回 `single` 后 `naturalNoteStrip` 仍可能作为 accessory 保留，但它不应再是 `answerOnly`，也不应继续可交互
- 因此最终代码把断言收口为 `projectedSurfaceState(for: .naturalNoteStrip) != .answerOnly`、`!effectiveSurfaceState(...).isAnswerEnabled`，以及平台 view 的交互关闭

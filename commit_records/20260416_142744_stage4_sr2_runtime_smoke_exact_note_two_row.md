# 20260416_142744_stage4_sr2_runtime_smoke_exact_note_two_row

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260416_142744`
- 记录依据：基于当前工作区 `changes`、`git status --short`、`git diff --stat -- ...`、按文件 `git diff -- ...`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` / `RuntimeSmoke` 结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `@.cursor/plans/sr2两行钢琴_4531b6e9.plan.md` 实施阶段 4 的真实落地代码改动；目标是把 `SR-2` 的 `exactNote + 两行 piano` 从 shared contract 扩成双端真实 runtime smoke，并顺手把 `SR-1` 的既有钢琴 smoke 收敛成可复用 runner
- 重要说明：
- 本轮是阶段 4，不是阶段 5；没有修改 `ExerciseCompositionValidation.swift`、`ExerciseCompositionValidationExercisePolicy.swift`、`FretboardValidation.swift`
- 本轮是 runtime smoke / controller 层修改，不涉及 settings、navigation、plan 文件，也没有修改任何旧的 `.md` 记录文件
- 当前 `git status --short` 只包含下面 4 个 `Swift` 文件，因此本次记录口径与阶段 4 的真实改动集完全一致
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`4 files changed, 428 insertions(+), 46 deletions(-)`
- 本记录文件本身是新增 markdown 记录，不计入上面的 diff 统计
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本次确认但未修改的关键文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `.cursor/plans/sr2两行钢琴_4531b6e9.plan.md`
- 验证结果：
- `ReadLints`：对本轮 4 个改动文件读取诊断，无错误
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage4_mac" build`：`BUILD SUCCEEDED`
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage4_ios" build`：`BUILD SUCCEEDED`
- `NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer`：macOS 最终运行结果为 `PASS scenario=sr2_piano_answer`
- `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer`：iOS Simulator 最终运行结果为 `PASS scenario=sr2_piano_answer`
- 额外回归：`NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer` 与 `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer` 在最终二进制上均为 `PASS scenario=sr1_piano_answer`
- 双端 `xcodebuild` 仍会打印 2 条既有 warning，位置在本轮未修改文件：`Shared/Fretboard/FretboardNaturalNoteTrainer.swift` 与 `Shared/Staff/StaffAccidentalContext.swift`
- 本轮调试过程中的非代码问题：
- 首次在沙箱内直接运行 macOS `sr2-piano-answer` 仍然出现 `exit 134` 且无有效日志；与前面阶段碰到的 macOS sandbox 运行问题一致，随后在无沙箱环境重跑通过，因此如实记录为环境问题，不视为本轮代码失败
- 本次没做的事情：
- 没有修改任何 shared validation 聚合器；阶段 5 再处理
- 没有修改计划文件
- 没有修改任何旧的 markdown 记录文件
- 没有提交代码

## 本次结论

- `SR-2` 现在已经拥有可单独触发的双端 runtime smoke 入口，不再只停留在 shared contract / settings 层
- `SR-1` 原本那套专用钢琴 smoke 没有继续横向复制，而是被收敛成 `runSRPianoAnswerSmokeTest(...)`，`SR-1 / SR-2` 仅通过参数矩阵分叉
- `SR-2` smoke 在真实 controller 链路上同时锁住了 4 类运行时合同：`staff + piano` 主场景可见、`answerPolicy == .exactNote`、`rowCount == 2 && movementScope == .rowOnly`、同音名不同八度会判错但完全相同音高会判对
- 最后一轮小修只动了 smoke 的成功摘要字符串：把切回 `single` 后已经失真、容易误导阅读的 `rowCount` 从 PASS 总结行里去掉，没有改任何判题逻辑

## 修改 1：在 `iOSAppDelegate` 增加 `sr2-piano-answer` 调度入口

### 修改前

- iOS 端 `application(_:didFinishLaunchingWithOptions:)` 已经能调度 `SR-0`、`SR-1` 和 `layout-preset-regression`
- 但 `RuntimeSmokeScenario` 里没有 `sr2-piano-answer` 环境变量，也没有对应分支
- 这意味着即便阶段 2/3 已经把 `SR-2` 接进 shared contract 和 settings，iOS 端仍然没有独立的 `SR-2` 运行时 smoke 启动入口

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名/符号: iOSAppDelegate.application(_:didFinishLaunchingWithOptions:) / RuntimeSmokeScenario
// 功能说明: 修改前 iOS 端只认识 `sr0-note-strip-answer`、`sr1-piano-answer` 和 `layout-preset-regression`；
// `sr2-piano-answer` 环境变量既不会被识别，也不会调度到任何 exercise controller smoke。
} else if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    print("[RuntimeSmoke][iOS] scheduled scenario=sr1_piano_answer")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        // ... 省略中间 guard 与回调 ...
        viewController.runSR1PianoAnswerSmokeTest(
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
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ... 其他 smoke 保持原样 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunSR1PianoAnswerSmoke: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == sr1PianoAnswerValue
    }
}
```

### 修改后

- iOS 启动链新增 `RuntimeSmokeScenario.shouldRunSR2PianoAnswerSmoke`
- 当环境变量为 `sr2-piano-answer` 时，app delegate 会像 `SR-1` 一样延迟调度到 `activeExerciseViewController`
- 成功时继续 `exit(0)`，失败时 `fatalError(summary)`，与现有 smoke runner 行为保持一致

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名/符号: iOSAppDelegate.application(_:didFinishLaunchingWithOptions:) / RuntimeSmokeScenario
// 功能说明: 修改后 iOS 启动链正式接入 `sr2-piano-answer`；
// app delegate 能根据环境变量调度 `runSR2PianoAnswerSmokeTest(...)`，并通过同一套 PASS / FAIL 退出策略收口。
} else if RuntimeSmokeScenario.shouldRunSR2PianoAnswerSmoke {
    print("[RuntimeSmoke][iOS] scheduled scenario=sr2_piano_answer")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let rootViewController = window.rootViewController
            as? iOSRootViewController,
            let viewController = rootViewController.activeExerciseViewController
        else {
            let summary =
                "[RuntimeSmoke][iOS] FAIL scenario=sr2_piano_answer reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }

        viewController.runSR2PianoAnswerSmokeTest(
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
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ... 其他 smoke 保持原样 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let sr2PianoAnswerValue = "sr2-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunSR2PianoAnswerSmoke: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == sr2PianoAnswerValue
    }
}
```

## 修改 2：在 `macOSAppDelegate` 镜像增加 `sr2-piano-answer` 调度入口

### 修改前

- macOS 端和 iOS 一样，已有 `SR-0 / SR-1 / layout-preset-regression` 三种 smoke 调度分支
- 但 `RuntimeSmokeScenario` 没有 `sr2-piano-answer` 的 value / gate
- 所以 macOS 端也无法单独把 `SR-2` smoke 从应用启动链拉起来

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名/符号: macOSAppDelegate.applicationDidFinishLaunching(_:) / RuntimeSmokeScenario
// 功能说明: 修改前 macOS 端只识别 `SR-0 / SR-1 / layout-preset-regression`；
// `SR-2` 尚未拥有独立的 app launch smoke 入口。
} else if RuntimeSmokeScenario.shouldRunSR1PianoAnswerSmoke {
    print("[RuntimeSmoke][macOS] scheduled scenario=sr1_piano_answer")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        // ... 省略中间 guard 与回调 ...
        viewController.runSR1PianoAnswerSmokeTest(
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
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ... 其他 smoke 保持原样 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunSR1PianoAnswerSmoke: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == sr1PianoAnswerValue
    }
}
```

### 修改后

- macOS 启动链新增 `RuntimeSmokeScenario.shouldRunSR2PianoAnswerSmoke`
- `sr2-piano-answer` 会调度到 `runSR2PianoAnswerSmokeTest(...)`
- PASS 时继续 `NSApp.terminate(nil)`，FAIL 时继续 `fatalError(summary)`，镜像对齐 iOS 侧策略

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名/符号: macOSAppDelegate.applicationDidFinishLaunching(_:) / RuntimeSmokeScenario
// 功能说明: 修改后 macOS 启动链正式接入 `SR-2` runtime smoke；
// app delegate 能根据环境变量调度 `runSR2PianoAnswerSmokeTest(...)`，并沿用既有的 PASS / FAIL 退出约定。
} else if RuntimeSmokeScenario.shouldRunSR2PianoAnswerSmoke {
    print("[RuntimeSmoke][macOS] scheduled scenario=sr2_piano_answer")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let rootViewController = window.contentViewController
            as? macOSRootViewController,
            let viewController = rootViewController.activeExerciseViewController
        else {
            let summary =
                "[RuntimeSmoke][macOS] FAIL scenario=sr2_piano_answer reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }

        viewController.runSR2PianoAnswerSmokeTest(
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
} else if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    // ... 其他 smoke 保持原样 ...
}

private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let sr0NoteStripAnswerValue = "sr0-note-strip-answer"
    static let sr1PianoAnswerValue = "sr1-piano-answer"
    static let sr2PianoAnswerValue = "sr2-piano-answer"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunSR2PianoAnswerSmoke: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == sr2PianoAnswerValue
    }
}
```

## 修改 3：在 `iOSViewController` 把 `SR-1` 专用脚本抽成共享 `SR piano` runner，并把 `SR-2` 参数化接入

### 修改前

- iOS 端只有 `runSR1PianoAnswerSmokeTest(...)`
- 这套脚本把 `switch_to_sr1 / wrong_piano_preview / correct_piano_preview`、`pitchClass` 语义和 `1 row` 断言全部写死在一个函数里
- 如果继续为 `SR-2` 复制一整套脚本，会把 controller smoke 再次分叉成两份近似代码，后续任何一步断言收口都要同步改两处

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: runSR1PianoAnswerSmokeTest(in:completion:)
// 功能说明: 修改前 `SR-1` smoke 是一套写死在函数里的专用脚本；
// mode、answerPolicy、rowCount、wrong/correct 预览选择和成功摘要都直接绑定到 `SR-1`，无法无损复用给 `SR-2`。
func runSR1PianoAnswerSmokeTest(
    in window: UIWindow,
    completion: @escaping (Bool, String) -> Void
) {
    typealias SmokeStep = (
        name: String,
        action: () -> Void,
        validate: () -> String?
    )
    var wrongPreview: PianoPreviewState?
    var correctPreview: PianoPreviewState?

    let steps: [SmokeStep] = [
        (
            name: "switch_to_sr1",
            action: {
                self.handleSettingsPanelEvent(
                    .triggerAction(.setExerciseModeSr1)
                )
            },
            validate: {
                guard self.trainerDisplayState.exerciseMode == .sr1 else {
                    return "reason=mode_not_sr1"
                }
                guard self.resolvedPianoSettingsSlice.rowCount == 1,
                      self.resolvedPianoSettingsSlice.movementScope == .rowOnly else {
                    return "reason=piano_settings_not_fixed"
                }
                return nil
            }
        ),
        (
            name: "wrong_piano_preview",
            action: {
                let preview = PianoPreviewState(
                    rowIndex: 0,
                    note: expectedNote.advanced(by: 1)
                )
                wrongPreview = preview
                self.handlePianoSemanticEvent(.previewStarted(preview))
            },
            validate: {
                guard !evaluation.isCorrect else {
                    return "reason=wrong_preview_marked_correct"
                }
                return nil
            }
        ),
        (
            name: "correct_piano_preview",
            action: {
                let preview = PianoPreviewState(
                    rowIndex: 0,
                    note: NotePitch(
                        pitchClass: expectedNote.pitchClass,
                        octave: expectedNote.octave + 1
                    )
                )
                correctPreview = preview
                self.handlePianoSemanticEvent(.previewStarted(preview))
            },
            validate: {
                guard evaluation.isCorrect else {
                    return "reason=correct_preview_marked_wrong"
                }
                return nil
            }
        )
    ]

    runExerciseAnswerSmokeSteps(
        steps,
        index: 0,
        scenarioName: "sr1_piano_answer",
        settleLayout: settleLayout,
        successSummary: {
            "[RuntimeSmoke][iOS] PASS scenario=sr1_piano_answer finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) pianoVisible=\(self.exercisePresentationState.isSurfaceVisible(.piano))"
        },
        completion: completion
    )
}
```

### 修改后

- `runSR1PianoAnswerSmokeTest(...)` 变成参数 wrapper，继续表达 `pitchClass + 1 row`
- 新增 `runSR2PianoAnswerSmokeTest(...)`，通过参数矩阵表达 `exactNote + 2 rows`
- 新增 `runSRPianoAnswerSmokeTest(...)`，集中收口这 3 组关键断言：
- `switch_to_sr*` 时要同时验证 `exerciseMode`、`resolvedSequenceConfiguration.answerPolicy`、`staff + piano` 主场景、无 accessory piano、`rowCount / movementScope` 是否同时落到 controller slice 和 platform view
- `wrong_*` / `correct_*` 时不只看 `isCorrect`，还验证 `expectedNotePitch`、`answeredPitchClass`、`answeredNotePitch`、`comparisonPolicy`、`currentIndex` 和 preview cache 是否完整对齐
- 成功摘要改成只保留 `scenarioName + finalMode + pianoVisible`；因为最后一步已经切回 `single`，继续打印 `rowCount` 会读到默认场景值，容易误导成“SR-2 最终只有 3 行”

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名/符号: runSR1PianoAnswerSmokeTest / runSR2PianoAnswerSmokeTest / runSRPianoAnswerSmokeTest
// 功能说明: 修改后 iOS 端把 `SR-1 / SR-2` 收口到同一个 `SR piano` smoke runner；
// `SR-2` 通过 `exactNote + 2 rows + same-pitch-class-wrong-octave` 参数矩阵接入，避免继续复制整套脚本。
func runSR1PianoAnswerSmokeTest(
    in window: UIWindow,
    completion: @escaping (Bool, String) -> Void
) {
    runSRPianoAnswerSmokeTest(
        in: window,
        scenarioName: "sr1_piano_answer",
        switchStepName: "switch_to_sr1",
        switchAction: .setExerciseModeSr1,
        expectedMode: .sr1,
        expectedAnswerPolicy: .pitchClass,
        expectedPianoRowCount: 1,
        wrongStepName: "wrong_piano_preview",
        makeWrongPreview: { expectedNote in
            PianoPreviewState(rowIndex: 0, note: expectedNote.advanced(by: 1))
        },
        validateWrongPreviewSelection: { expectedNote, preview in
            guard preview.note.pitchClass != expectedNote.pitchClass else {
                return "reason=wrong_preview_not_outside_pitch_class"
            }
            return nil
        },
        correctStepName: "correct_piano_preview",
        makeCorrectPreview: { expectedNote in
            PianoPreviewState(
                rowIndex: 0,
                note: NotePitch(
                    pitchClass: expectedNote.pitchClass,
                    octave: expectedNote.octave + 1
                )
            )
        },
        validateCorrectPreviewSelection: { expectedNote, preview in
            guard preview.note.pitchClass == expectedNote.pitchClass,
                  preview.note != expectedNote else {
                return "reason=correct_preview_not_pitch_class_only"
            }
            return nil
        },
        completion: completion
    )
}

func runSR2PianoAnswerSmokeTest(
    in window: UIWindow,
    completion: @escaping (Bool, String) -> Void
) {
    runSRPianoAnswerSmokeTest(
        in: window,
        scenarioName: "sr2_piano_answer",
        switchStepName: "switch_to_sr2",
        switchAction: .setExerciseModeSr2,
        expectedMode: .sr2,
        expectedAnswerPolicy: .exactNote,
        expectedPianoRowCount: 2,
        wrongStepName: "wrong_exact_note",
        makeWrongPreview: { expectedNote in
            PianoPreviewState(rowIndex: 1, note: expectedNote.advanced(by: 12))
        },
        validateWrongPreviewSelection: { expectedNote, preview in
            guard preview.note.pitchClass == expectedNote.pitchClass,
                  preview.note != expectedNote else {
                return "reason=wrong_preview_not_same_class_different_octave"
            }
            return nil
        },
        correctStepName: "correct_exact_note",
        makeCorrectPreview: { expectedNote in
            PianoPreviewState(rowIndex: 1, note: expectedNote)
        },
        validateCorrectPreviewSelection: { expectedNote, preview in
            guard preview.note == expectedNote else {
                return "reason=correct_preview_not_exact_note"
            }
            return nil
        },
        completion: completion
    )
}

private func runSRPianoAnswerSmokeTest(
    in window: UIWindow,
    scenarioName: String,
    switchStepName: String,
    switchAction: SettingsActionID,
    expectedMode: TrainerExerciseMode,
    expectedAnswerPolicy: TrainerSequenceAnswerPolicy,
    expectedPianoRowCount: Int,
    wrongStepName: String,
    makeWrongPreview: @escaping (NotePitch) -> PianoPreviewState,
    validateWrongPreviewSelection: @escaping (NotePitch, PianoPreviewState) -> String?,
    correctStepName: String,
    makeCorrectPreview: @escaping (NotePitch) -> PianoPreviewState,
    validateCorrectPreviewSelection: @escaping (NotePitch, PianoPreviewState) -> String?,
    completion: @escaping (Bool, String) -> Void
) {
    var wrongPreview: PianoPreviewState?
    var wrongExpectedNote: NotePitch?
    var correctPreview: PianoPreviewState?
    var correctExpectedNote: NotePitch?
    // ... 省略 settleLayout / currentExpectedNotePitch / steps 其他分支定义 ...
    guard !self.exerciseLayoutPreferences.isPianoAccessoryVisible else {
        return "reason=piano_accessory_enabled"
    }
    guard resolvedSequenceConfiguration.answerPolicy == expectedAnswerPolicy else {
        return "reason=answer_policy_not_fixed"
    }
    guard self.resolvedPianoSettingsSlice.rowCount == expectedPianoRowCount,
          self.resolvedPianoSettingsSlice.movementScope == .rowOnly else {
        return "reason=piano_settings_not_fixed"
    }
    guard self.pianoSurfaceView.currentSettingsSlice.rowCount == expectedPianoRowCount,
          self.pianoSurfaceView.currentSettingsSlice.movementScope == .rowOnly else {
        return "reason=piano_view_settings_not_applied"
    }
    // ... 省略 switch_to_sr* 与 action 部分 ...
    (
        name: wrongStepName,
        action: { /* 省略 makeWrongPreview / previewStarted */ },
        validate: {
            guard let wrongExpectedNote, let wrongPreview else {
                return "reason=missing_wrong_payload"
            }
            guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                return "reason=missing_wrong_evaluation"
            }
            guard evaluation.comparisonPolicy == expectedAnswerPolicy else {
                return "reason=wrong_policy"
            }
            guard evaluation.expectedNotePitch == wrongExpectedNote else {
                return "reason=wrong_expected_note_shifted"
            }
            guard evaluation.answeredPitchClass == wrongPreview.note.pitchClass else {
                return "reason=wrong_pitch_class_lost"
            }
            guard evaluation.answeredNotePitch == wrongPreview.note else {
                return "reason=wrong_pitch_lost"
            }
            return nil
        }
    ),
    (
        name: correctStepName,
        action: { /* 省略 makeCorrectPreview / previewStarted */ },
        validate: {
            guard let correctExpectedNote, let correctPreview else {
                return "reason=missing_correct_payload"
            }
            guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                return "reason=missing_correct_evaluation"
            }
            guard evaluation.comparisonPolicy == expectedAnswerPolicy else {
                return "reason=correct_policy_mismatch"
            }
            guard evaluation.expectedNotePitch == correctExpectedNote else {
                return "reason=correct_expected_note_shifted"
            }
            guard evaluation.answeredPitchClass == correctPreview.note.pitchClass else {
                return "reason=correct_pitch_class_lost"
            }
            guard evaluation.answeredNotePitch == correctPreview.note else {
                return "reason=correct_pitch_lost"
            }
            return nil
        }
    )

    runExerciseAnswerSmokeSteps(
        steps,
        index: 0,
        scenarioName: scenarioName,
        settleLayout: settleLayout,
        successSummary: {
            "[RuntimeSmoke][iOS] PASS scenario=\(scenarioName) finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) pianoVisible=\(self.exercisePresentationState.isSurfaceVisible(.piano))"
        },
        completion: completion
    )
}
```

## 修改 4：在 `macOSViewController` 镜像抽出共享 `SR piano` runner，并把 `SR-2` 参数化接入

### 修改前

- macOS 端原本也只有 `runSR1PianoAnswerSmokeTest(...)`
- 它和 iOS 一样，把 `SR-1` 的 step 名、判题语义、行数合同和成功摘要都写死在单个函数里
- 这样如果阶段 4 直接再写一个独立的 `runSR2...`，controller smoke 逻辑会继续 iOS / macOS 双端成对复制，而且 `SR-1` 与 `SR-2` 之间还会再复制一层

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: runSR1PianoAnswerSmokeTest(in:completion:)
// 功能说明: 修改前 macOS 端和 iOS 端一样，只有一套绑定到 `SR-1` 的专用钢琴 smoke；
// 所有 step 名称、答案语义、固定行数断言和最终 PASS 文案都内嵌在同一个函数里。
func runSR1PianoAnswerSmokeTest(
    in window: NSWindow,
    completion: @escaping (Bool, String) -> Void
) {
    typealias SmokeStep = (
        name: String,
        action: () -> Void,
        validate: () -> String?
    )

    let steps: [SmokeStep] = [
        (
            name: "switch_to_sr1",
            action: {
                self.handleSettingsPanelEvent(
                    .triggerAction(.setExerciseModeSr1)
                )
            },
            validate: {
                guard self.trainerDisplayState.exerciseMode == .sr1 else {
                    return "reason=mode_not_sr1"
                }
                guard self.resolvedPianoSettingsSlice.rowCount == 1,
                      self.resolvedPianoSettingsSlice.movementScope == .rowOnly else {
                    return "reason=piano_settings_not_fixed"
                }
                return nil
            }
        ),
        (
            name: "wrong_piano_preview",
            action: {
                let preview = PianoPreviewState(
                    rowIndex: 0,
                    note: expectedNote.advanced(by: 1)
                )
                self.handlePianoSemanticEvent(.previewStarted(preview))
            },
            validate: {
                guard !evaluation.isCorrect else {
                    return "reason=wrong_preview_marked_correct"
                }
                return nil
            }
        ),
        (
            name: "correct_piano_preview",
            action: {
                let preview = PianoPreviewState(
                    rowIndex: 0,
                    note: NotePitch(
                        pitchClass: expectedNote.pitchClass,
                        octave: expectedNote.octave + 1
                    )
                )
                self.handlePianoSemanticEvent(.previewStarted(preview))
            },
            validate: {
                guard evaluation.isCorrect else {
                    return "reason=correct_preview_marked_wrong"
                }
                return nil
            }
        )
    ]

    runExerciseAnswerSmokeSteps(
        steps,
        index: 0,
        scenarioName: "sr1_piano_answer",
        settleLayout: settleLayout,
        successSummary: {
            "[RuntimeSmoke][macOS] PASS scenario=sr1_piano_answer finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) pianoVisible=\(self.exercisePresentationState.isSurfaceVisible(.piano))"
        },
        completion: completion
    )
}
```

### 修改后

- macOS 端与 iOS 端对称新增 `runSR2PianoAnswerSmokeTest(...)`
- `runSR1PianoAnswerSmokeTest(...)` 也被改成 wrapper，继续只负责给共享 runner 传入 `SR-1` 的参数矩阵
- 新增 `runSRPianoAnswerSmokeTest(...)` 后，macOS 端也能统一验证 `exactNote + 2 rows + rowOnly` 的真实运行时合同，并保持最终 PASS 摘要与 iOS 一致

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名/符号: runSR1PianoAnswerSmokeTest / runSR2PianoAnswerSmokeTest / runSRPianoAnswerSmokeTest
// 功能说明: 修改后 macOS 端与 iOS 端对称共享同一套 `SR piano` smoke runner；
// `SR-2` 不再需要单独复制完整脚本，而是通过参数化把 `exactNote + 2 rows` 接进同一条控制器验证链。
func runSR1PianoAnswerSmokeTest(
    in window: NSWindow,
    completion: @escaping (Bool, String) -> Void
) {
    runSRPianoAnswerSmokeTest(
        in: window,
        scenarioName: "sr1_piano_answer",
        switchStepName: "switch_to_sr1",
        switchAction: .setExerciseModeSr1,
        expectedMode: .sr1,
        expectedAnswerPolicy: .pitchClass,
        expectedPianoRowCount: 1,
        wrongStepName: "wrong_piano_preview",
        makeWrongPreview: { expectedNote in
            PianoPreviewState(rowIndex: 0, note: expectedNote.advanced(by: 1))
        },
        validateWrongPreviewSelection: { expectedNote, preview in
            guard preview.note.pitchClass != expectedNote.pitchClass else {
                return "reason=wrong_preview_not_outside_pitch_class"
            }
            return nil
        },
        correctStepName: "correct_piano_preview",
        makeCorrectPreview: { expectedNote in
            PianoPreviewState(
                rowIndex: 0,
                note: NotePitch(
                    pitchClass: expectedNote.pitchClass,
                    octave: expectedNote.octave + 1
                )
            )
        },
        validateCorrectPreviewSelection: { expectedNote, preview in
            guard preview.note.pitchClass == expectedNote.pitchClass,
                  preview.note != expectedNote else {
                return "reason=correct_preview_not_pitch_class_only"
            }
            return nil
        },
        completion: completion
    )
}

func runSR2PianoAnswerSmokeTest(
    in window: NSWindow,
    completion: @escaping (Bool, String) -> Void
) {
    runSRPianoAnswerSmokeTest(
        in: window,
        scenarioName: "sr2_piano_answer",
        switchStepName: "switch_to_sr2",
        switchAction: .setExerciseModeSr2,
        expectedMode: .sr2,
        expectedAnswerPolicy: .exactNote,
        expectedPianoRowCount: 2,
        wrongStepName: "wrong_exact_note",
        makeWrongPreview: { expectedNote in
            PianoPreviewState(rowIndex: 1, note: expectedNote.advanced(by: 12))
        },
        validateWrongPreviewSelection: { expectedNote, preview in
            guard preview.note.pitchClass == expectedNote.pitchClass,
                  preview.note != expectedNote else {
                return "reason=wrong_preview_not_same_class_different_octave"
            }
            return nil
        },
        correctStepName: "correct_exact_note",
        makeCorrectPreview: { expectedNote in
            PianoPreviewState(rowIndex: 1, note: expectedNote)
        },
        validateCorrectPreviewSelection: { expectedNote, preview in
            guard preview.note == expectedNote else {
                return "reason=correct_preview_not_exact_note"
            }
            return nil
        },
        completion: completion
    )
}

private func runSRPianoAnswerSmokeTest(
    in window: NSWindow,
    scenarioName: String,
    switchStepName: String,
    switchAction: SettingsActionID,
    expectedMode: TrainerExerciseMode,
    expectedAnswerPolicy: TrainerSequenceAnswerPolicy,
    expectedPianoRowCount: Int,
    wrongStepName: String,
    makeWrongPreview: @escaping (NotePitch) -> PianoPreviewState,
    validateWrongPreviewSelection: @escaping (NotePitch, PianoPreviewState) -> String?,
    correctStepName: String,
    makeCorrectPreview: @escaping (NotePitch) -> PianoPreviewState,
    validateCorrectPreviewSelection: @escaping (NotePitch, PianoPreviewState) -> String?,
    completion: @escaping (Bool, String) -> Void
) {
    var wrongPreview: PianoPreviewState?
    var wrongExpectedNote: NotePitch?
    var correctPreview: PianoPreviewState?
    var correctExpectedNote: NotePitch?
    // ... 省略 settleLayout / currentExpectedNotePitch / steps 其他分支定义 ...
    guard !self.exerciseLayoutPreferences.isPianoAccessoryVisible else {
        return "reason=piano_accessory_enabled"
    }
    guard resolvedSequenceConfiguration.answerPolicy == expectedAnswerPolicy else {
        return "reason=answer_policy_not_fixed"
    }
    guard self.resolvedPianoSettingsSlice.rowCount == expectedPianoRowCount,
          self.resolvedPianoSettingsSlice.movementScope == .rowOnly else {
        return "reason=piano_settings_not_fixed"
    }
    guard self.pianoSurfaceView.currentSettingsSlice.rowCount == expectedPianoRowCount,
          self.pianoSurfaceView.currentSettingsSlice.movementScope == .rowOnly else {
        return "reason=piano_view_settings_not_applied"
    }
    // ... 省略 switch_to_sr* 与 action 部分 ...
    (
        name: wrongStepName,
        action: { /* 省略 makeWrongPreview / previewStarted */ },
        validate: {
            guard let wrongExpectedNote, let wrongPreview else {
                return "reason=missing_wrong_payload"
            }
            guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                return "reason=missing_wrong_evaluation"
            }
            guard evaluation.comparisonPolicy == expectedAnswerPolicy else {
                return "reason=wrong_policy"
            }
            guard evaluation.expectedNotePitch == wrongExpectedNote else {
                return "reason=wrong_expected_note_shifted"
            }
            guard evaluation.answeredPitchClass == wrongPreview.note.pitchClass else {
                return "reason=wrong_pitch_class_lost"
            }
            guard evaluation.answeredNotePitch == wrongPreview.note else {
                return "reason=wrong_pitch_lost"
            }
            return nil
        }
    ),
    (
        name: correctStepName,
        action: { /* 省略 makeCorrectPreview / previewStarted */ },
        validate: {
            guard let correctExpectedNote, let correctPreview else {
                return "reason=missing_correct_payload"
            }
            guard let evaluation = self.quarterNoteSequenceLastEvaluation else {
                return "reason=missing_correct_evaluation"
            }
            guard evaluation.comparisonPolicy == expectedAnswerPolicy else {
                return "reason=correct_policy_mismatch"
            }
            guard evaluation.expectedNotePitch == correctExpectedNote else {
                return "reason=correct_expected_note_shifted"
            }
            guard evaluation.answeredPitchClass == correctPreview.note.pitchClass else {
                return "reason=correct_pitch_class_lost"
            }
            guard evaluation.answeredNotePitch == correctPreview.note else {
                return "reason=correct_pitch_lost"
            }
            return nil
        }
    )

    runExerciseAnswerSmokeSteps(
        steps,
        index: 0,
        scenarioName: scenarioName,
        settleLayout: settleLayout,
        successSummary: {
            "[RuntimeSmoke][macOS] PASS scenario=\(scenarioName) finalMode=\(String(describing: self.trainerDisplayState.exerciseMode)) pianoVisible=\(self.exercisePresentationState.isSurfaceVisible(.piano))"
        },
        completion: completion
    )
}
```

## 双端 `SR-2` runtime smoke 实际输出摘录

### iOS：同音名不同八度判错，完全相同音高判对

```bash
# 文件路径: iOS SR-2 runtime smoke 日志摘录
# 函数名: RuntimeSmoke / QuarterNoteSequence
# 功能说明: 真实运行时日志显示 `SR-2` 在 iOS 上按 `exactNote` 比较；
# 同音名不同八度的 `G5` 会判错，完全相同的 `G4` 会判对并推进到下一题。
[RuntimeSmoke][iOS] step=switch_to_sr2 end mode=sr2
[RuntimeSmoke][iOS] step=wrong_exact_note begin mode=sr2
[iOS] [QuarterNoteSequence] policy=exactNote step=1/7 expectedClass=G expectedNote=G4 written=G4 answeredClass=G answeredNote=G5 result=wrong nextIndex=0 remaining=7 state=inProgress answered=G5
[RuntimeSmoke][iOS] step=wrong_exact_note end mode=sr2
[RuntimeSmoke][iOS] step=correct_exact_note begin mode=sr2
[iOS] [QuarterNoteSequence] policy=exactNote step=1/7 expectedClass=G expectedNote=G4 written=G4 answeredClass=G answeredNote=G4 result=correct nextIndex=1 remaining=6 state=inProgress answered=G4
[RuntimeSmoke][iOS] step=correct_exact_note end mode=sr2
[RuntimeSmoke][iOS] PASS scenario=sr2_piano_answer finalMode=single pianoVisible=false
```

### macOS：同音名不同八度判错，完全相同音高判对

```bash
# 文件路径: macOS SR-2 runtime smoke 日志摘录
# 函数名: RuntimeSmoke / QuarterNoteSequence
# 功能说明: 真实运行时日志显示 `SR-2` 在 macOS 上也按 `exactNote` 比较；
# 同音名不同八度的 `B5` 不会推进 session，而完全相同的 `B4` 会推进到下一题。
[RuntimeSmoke][macOS] step=switch_to_sr2 end mode=sr2
[RuntimeSmoke][macOS] step=wrong_exact_note begin mode=sr2
[macOS] [QuarterNoteSequence] policy=exactNote step=1/7 expectedClass=B expectedNote=B4 written=B4 answeredClass=B answeredNote=B5 result=wrong nextIndex=0 remaining=7 state=inProgress answered=B5
[RuntimeSmoke][macOS] step=wrong_exact_note end mode=sr2
[RuntimeSmoke][macOS] step=correct_exact_note begin mode=sr2
[macOS] [QuarterNoteSequence] policy=exactNote step=1/7 expectedClass=B expectedNote=B4 written=B4 answeredClass=B answeredNote=B4 result=correct nextIndex=1 remaining=6 state=inProgress answered=B4
[RuntimeSmoke][macOS] step=correct_exact_note end mode=sr2
[RuntimeSmoke][macOS] PASS scenario=sr2_piano_answer finalMode=single pianoVisible=false
```

## 最终态 `SR-1` 回归摘录

```bash
# 文件路径: iOS SR-1 runtime smoke 日志摘录
# 函数名: RuntimeSmoke / QuarterNoteSequence
# 功能说明: 共享 runner 收口后，`SR-1` 仍保持原有 `pitchClass` 语义；
# `C#5` 判错、同音名不同八度的 `C6` 判对，说明阶段 4 没把旧模式带坏。
[RuntimeSmoke][iOS] step=wrong_piano_preview begin mode=sr1
[iOS] [QuarterNoteSequence] policy=pitchClass step=1/7 expectedClass=C expectedNote=C5 written=C5 answeredClass=C# answeredNote=C#5 result=wrong nextIndex=0 remaining=7 state=inProgress answered=C#5
[RuntimeSmoke][iOS] step=correct_piano_preview begin mode=sr1
[iOS] [QuarterNoteSequence] policy=pitchClass step=1/7 expectedClass=C expectedNote=C5 written=C5 answeredClass=C answeredNote=C6 result=correct nextIndex=1 remaining=6 state=inProgress answered=C6
[RuntimeSmoke][iOS] PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false
```

```bash
# 文件路径: macOS SR-1 runtime smoke 日志摘录
# 函数名: RuntimeSmoke / QuarterNoteSequence
# 功能说明: macOS 端共享 runner 收口后，`SR-1` 也继续保持 `pitchClass` 判题；
# `C#5` 判错、`C6` 判对，说明阶段 4 的抽象没有改变既有 SR-1 行为。
[RuntimeSmoke][macOS] step=wrong_piano_preview begin mode=sr1
[macOS] [QuarterNoteSequence] policy=pitchClass step=1/7 expectedClass=C expectedNote=C5 written=C5 answeredClass=C# answeredNote=C#5 result=wrong nextIndex=0 remaining=7 state=inProgress answered=C#5
[RuntimeSmoke][macOS] step=correct_piano_preview begin mode=sr1
[macOS] [QuarterNoteSequence] policy=pitchClass step=1/7 expectedClass=C expectedNote=C5 written=C5 answeredClass=C answeredNote=C6 result=correct nextIndex=1 remaining=6 state=inProgress answered=C6
[RuntimeSmoke][macOS] PASS scenario=sr1_piano_answer finalMode=single pianoVisible=false
```

## 本轮实际命令

```bash
# 文件路径: 工程级验证命令
# 函数名: date / git / xcodebuild / RuntimeSmoke
# 功能说明: 本次阶段4记录使用的时间戳命令、diff 统计命令，以及实际跑过的构建和双端 smoke 命令。
date +"%Y%m%d_%H%M%S"
git status --short
git diff --stat -- "NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift" "NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift" "NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift" "NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage4_mac" build
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath "/tmp/NoteMaster_Ver_1_stage4_ios" build
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer "/tmp/NoteMaster_Ver_1_stage4_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl install booted "/tmp/NoteMaster_Ver_1_stage4_ios/Build/Products/Debug-iphonesimulator/NoteMaster_Ver_1.app"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr2-piano-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer "/tmp/NoteMaster_Ver_1_stage4_mac/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
SIMCTL_CHILD_NSUnbufferedIO=YES SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=sr1-piano-answer DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcrun simctl launch --console-pty --terminate-running-process booted "shaunyu.NoteMaster-Ver-1"
```

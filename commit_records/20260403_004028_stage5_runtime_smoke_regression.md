# 20260403_004028_stage5_runtime_smoke_regression

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_004028`
- 记录范围：只记录方案 B 的阶段 5 落地，即把 side / stacked 切换与尺寸变化的高风险运行时链路做成双端可重复执行的 smoke 回归，并完成实际运行验证
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本记录中的“修改前”，指 `20260403_001513_stage4_validation_and_settings_gate_sync.md` 记录完成后的代码状态
- 本轮实际改动文件：
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`

## 1. 本轮目标

- 阶段 4 之后，shared validation 与 settings gate 已经有自动化护栏，但这些夹具都只覆盖“启动时能否通过语义断言”。
- 历史上最反复的问题，不只是启动期语义错误，而是运行中的 `side <-> stacked` 切换、窗口尺寸变化、设备方向变化附近的布局重入与崩溃链。
- 阶段 5 的目标，是把这条高风险运行时链路做成可重复执行的双端 smoke 回归，而不是继续依赖手工来回点设置页验证。

## 2. 修改一：在双端 `AppDelegate` 增加 DEBUG-only smoke 入口

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数: applicationDidFinishLaunching(_:)
// 修改前说明: macOS 启动只会顺序跑 shared validation，然后创建窗口并展示根控制器。
// 启动期断言虽然会执行，但没有任何入口能在应用跑起来后继续自动触发 side/stacked 切换链路。
print("[Startup][macOSApp] activate app")
NSApp.activate(ignoringOtherApps: true)
self.window = window
print("[Startup][macOSApp] applicationDidFinishLaunching end")
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数: application(_:didFinishLaunchingWithOptions:)
// 修改前说明: iOS 也是同样模型，启动期 validation 结束后直接展示 UIWindow。
// 后续 layout preset 的运行时切换只能靠人工操作 settings UI，无法从命令行稳定重放。
print("[Startup][iOSApp] make window key and visible")
window.makeKeyAndVisible()
self.window = window
print("[Startup][iOSApp] didFinishLaunching end")
return true
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数: applicationDidFinishLaunching(_:)
// 修改后说明: macOS 在 DEBUG 下新增环境变量门控。
// 当 NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression 时，
// 启动完成后会自动调度运行时 smoke；通过则退出，失败则直接 fatalError。
print("[Startup][macOSApp] activate app")
NSApp.activate(ignoringOtherApps: true)
self.window = window

#if DEBUG
if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    print(
        "[RuntimeSmoke][macOS] scheduled scenario=layout_preset_regression"
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let viewController = window.contentViewController
            as? macOSViewController
        else {
            let summary =
                "[RuntimeSmoke][macOS] FAIL scenario=layout_preset_regression reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }

        viewController.runLayoutPresetRegressionSmokeTest(
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
}
#endif

print("[Startup][macOSApp] applicationDidFinishLaunching end")

#if DEBUG
private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunLayoutPresetRegression: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == layoutPresetRegressionValue
    }
}
#endif
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数: application(_:didFinishLaunchingWithOptions:)
// 修改后说明: iOS 保持与 macOS 对齐。
// 在 simctl 环境下通过 SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST 透传同一个变量，
// 让 simulator 启动后自动执行运行时 smoke，成功后 exit(0)，失败则 fatalError。
print("[Startup][iOSApp] make window key and visible")
window.makeKeyAndVisible()
self.window = window

#if DEBUG
if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
    print("[RuntimeSmoke][iOS] scheduled scenario=layout_preset_regression")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard
            let self,
            let window = self.window,
            let viewController = window.rootViewController
            as? iOSViewController
        else {
            let summary =
                "[RuntimeSmoke][iOS] FAIL scenario=layout_preset_regression reason=missing_window_or_view_controller"
            print(summary)
            fatalError(summary)
        }

        viewController.runLayoutPresetRegressionSmokeTest(
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
}
#endif

print("[Startup][iOSApp] didFinishLaunching end")
return true

#if DEBUG
private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunLayoutPresetRegression: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == layoutPresetRegressionValue
    }
}
#endif
```

### 2.3 这一改动解决了什么

- 启动期 validation 和运行时 smoke 现在被统一串在同一条启动链上，不需要为回归测试另外造一套入口。
- smoke 只在 `DEBUG` 且命中特定环境变量时才会执行，不会污染正常启动路径，也不会改变生产语义。
- 回归结果现在是“机器可判定”的：通过就退出，失败就明确报错，而不是靠人看日志猜测是否稳定。

## 3. 修改二：在 `macOSViewController` 增加真实 layout preset 切换 smoke harness

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: handleSettingsPanelEvent(_:)
// 修改前说明: macOS 只有正常的 settings 事件处理链。
// 也就是说 controller 本身能处理 layout preset 切换，但没有任何可复用的调试回归函数
// 去自动执行 "side -> stacked -> side + resize" 这种高风险序列。
private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)

    let nextExerciseLayoutPreferences = nextStateContext
        .exerciseLayoutPreferences
    let didChangeExerciseLayoutPreferences =
        nextExerciseLayoutPreferences != exerciseLayoutPreferences

    guard didChangeExerciseLayoutPreferences else {
        return
    }

    performPresentationTransaction {
        if didChangeExerciseLayoutPreferences {
            exerciseLayoutPreferences = nextExerciseLayoutPreferences
        }

        synchronizeExerciseCompositionState(
            reason: "settingsStateChanged"
        )
    }
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数: runLayoutPresetRegressionSmokeTest(in:completion:),
//       runLayoutPresetRegressionSmokeSteps(_:index:completion:)
// 修改后说明: 新增 DEBUG-only smoke harness，直接复用 controller 内部真实 settings 事件链，
// 顺序执行 side -> stacked -> side，并插入宽/窄窗口变化，逐步验证当前 layoutPreset 是否符合预期。
#if DEBUG
extension macOSViewController {
    func runLayoutPresetRegressionSmokeTest(
        in window: NSWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            expectedLayout: ExerciseLayoutPreset,
            action: () -> Void
        )

        let steps: [SmokeStep] = [
            (
                name: "switch_to_stacked",
                expectedLayout: .stacked,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetStacked)
                    )
                }
            ),
            (
                name: "resize_wide",
                expectedLayout: .stacked,
                action: {
                    var nextFrame = window.frame
                    nextFrame.size = NSSize(width: 1120, height: 720)
                    window.setFrame(nextFrame, display: true)
                }
            ),
            (
                name: "switch_to_side",
                expectedLayout: .sideBySide,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetSideBySide)
                    )
                }
            ),
            (
                name: "resize_compact",
                expectedLayout: .sideBySide,
                action: {
                    var nextFrame = window.frame
                    nextFrame.size = NSSize(width: 760, height: 540)
                    window.setFrame(nextFrame, display: true)
                }
            ),
            (
                name: "switch_to_stacked_again",
                expectedLayout: .stacked,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetStacked)
                    )
                }
            ),
            (
                name: "switch_to_side_final",
                expectedLayout: .sideBySide,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetSideBySide)
                    )
                }
            )
        ]

        print(
            "[RuntimeSmoke][macOS] begin scenario=layout_preset_regression initialLayout=\(exerciseLayoutPreferences.layoutPreset.rawValue)"
        )
        runLayoutPresetRegressionSmokeSteps(
            steps,
            index: 0,
            completion: completion
        )
    }

    private func runLayoutPresetRegressionSmokeSteps(
        _ steps: [(name: String, expectedLayout: ExerciseLayoutPreset, action: () -> Void)],
        index: Int,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard index < steps.count else {
            let summary =
                "[RuntimeSmoke][macOS] PASS scenario=layout_preset_regression finalLayout=\(exerciseLayoutPreferences.layoutPreset.rawValue) sceneBounds=\(NSStringFromRect(exerciseSceneRenderer.sceneContainerView.bounds))"
            completion(true, summary)
            return
        }

        let step = steps[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print(
                "[RuntimeSmoke][macOS] step=\(step.name) begin currentLayout=\(self.exerciseLayoutPreferences.layoutPreset.rawValue)"
            )
            step.action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let resolvedLayout = self.exerciseLayoutPreferences.layoutPreset
                let summary =
                    "[RuntimeSmoke][macOS] step=\(step.name) end resolvedLayout=\(resolvedLayout.rawValue) sceneBounds=\(NSStringFromRect(self.exerciseSceneRenderer.sceneContainerView.bounds))"
                print(summary)

                guard resolvedLayout == step.expectedLayout else {
                    completion(
                        false,
                        "[RuntimeSmoke][macOS] FAIL scenario=layout_preset_regression step=\(step.name) expectedLayout=\(step.expectedLayout.rawValue) resolvedLayout=\(resolvedLayout.rawValue)"
                    )
                    return
                }

                self.runLayoutPresetRegressionSmokeSteps(
                    steps,
                    index: index + 1,
                    completion: completion
                )
            }
        }
    }
}
#endif
```

### 3.3 这一改动解决了什么

- 现在 macOS 的回归不再只是“启动能不能过”，而是能真实走到之前最容易触发 `EXC_BAD_ACCESS` 的 settings 切换链路。
- smoke 直接复用了 `handleSettingsPanelEvent(.triggerAction(.setLayoutPreset...))`，因此验证的是实际生产事件路径，不是另写一套假的状态切换逻辑。
- 窗口宽/窄变化也被纳入了同一条回归链里，能顺带覆盖 live resize 附近的布局稳定性。

## 4. 修改三：在 `iOSViewController` 增加对等的运行时 smoke harness

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数: handleSettingsPanelEvent(_:)
// 修改前说明: iOS 同样只有正常的 settings 事件处理链。
// controller 可以响应 layout preset 切换，但没有自动化入口去串联切换与近似旋转/尺寸变化回归。
private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)

    let nextExerciseLayoutPreferences = nextStateContext
        .exerciseLayoutPreferences
    let didChangeExerciseLayoutPreferences =
        nextExerciseLayoutPreferences != exerciseLayoutPreferences

    guard didChangeExerciseLayoutPreferences else {
        return
    }

    if didChangeExerciseLayoutPreferences {
        exerciseLayoutPreferences = nextExerciseLayoutPreferences
    }

    synchronizeExerciseCompositionState(
        reason: "settingsStateChanged"
    )
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数: runLayoutPresetRegressionSmokeTest(in:completion:),
//       runLayoutPresetRegressionSmokeSteps(_:index:completion:)
// 修改后说明: iOS 版 smoke harness 与 macOS 保持同一语义：
// 真实切换 side/stacked，并插入 portrait-like / landscape-like 尺寸变化。
// 这里的 bounds 日志用 NSCoder.string(for:) 输出，避免当前 iOS SDK 下 NSStringFromCGRect 的过时编译问题。
#if DEBUG
extension iOSViewController {
    func runLayoutPresetRegressionSmokeTest(
        in window: UIWindow,
        completion: @escaping (Bool, String) -> Void
    ) {
        typealias SmokeStep = (
            name: String,
            expectedLayout: ExerciseLayoutPreset,
            action: () -> Void
        )

        let steps: [SmokeStep] = [
            (
                name: "switch_to_stacked",
                expectedLayout: .stacked,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetStacked)
                    )
                }
            ),
            (
                name: "resize_landscape_like",
                expectedLayout: .stacked,
                action: {
                    let bounds = CGRect(x: 0, y: 0, width: 874, height: 402)
                    window.bounds = bounds
                    window.frame = bounds
                    window.setNeedsLayout()
                    window.layoutIfNeeded()
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                }
            ),
            (
                name: "switch_to_side",
                expectedLayout: .sideBySide,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetSideBySide)
                    )
                }
            ),
            (
                name: "resize_portrait_like",
                expectedLayout: .sideBySide,
                action: {
                    let bounds = CGRect(x: 0, y: 0, width: 402, height: 874)
                    window.bounds = bounds
                    window.frame = bounds
                    window.setNeedsLayout()
                    window.layoutIfNeeded()
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                }
            ),
            (
                name: "switch_to_stacked_again",
                expectedLayout: .stacked,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetStacked)
                    )
                }
            ),
            (
                name: "switch_to_side_final",
                expectedLayout: .sideBySide,
                action: {
                    self.handleSettingsPanelEvent(
                        .triggerAction(.setLayoutPresetSideBySide)
                    )
                }
            )
        ]

        print(
            "[RuntimeSmoke][iOS] begin scenario=layout_preset_regression initialLayout=\(exerciseLayoutPreferences.layoutPreset.rawValue)"
        )
        runLayoutPresetRegressionSmokeSteps(
            steps,
            index: 0,
            completion: completion
        )
    }

    private func runLayoutPresetRegressionSmokeSteps(
        _ steps: [(name: String, expectedLayout: ExerciseLayoutPreset, action: () -> Void)],
        index: Int,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard index < steps.count else {
            let summary =
                "[RuntimeSmoke][iOS] PASS scenario=layout_preset_regression finalLayout=\(exerciseLayoutPreferences.layoutPreset.rawValue) sceneBounds=\(NSCoder.string(for: exerciseSceneRenderer.sceneContainerView.bounds))"
            completion(true, summary)
            return
        }

        let step = steps[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print(
                "[RuntimeSmoke][iOS] step=\(step.name) begin currentLayout=\(self.exerciseLayoutPreferences.layoutPreset.rawValue)"
            )
            step.action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let resolvedLayout = self.exerciseLayoutPreferences.layoutPreset
                let summary =
                    "[RuntimeSmoke][iOS] step=\(step.name) end resolvedLayout=\(resolvedLayout.rawValue) sceneBounds=\(NSCoder.string(for: self.exerciseSceneRenderer.sceneContainerView.bounds))"
                print(summary)

                guard resolvedLayout == step.expectedLayout else {
                    completion(
                        false,
                        "[RuntimeSmoke][iOS] FAIL scenario=layout_preset_regression step=\(step.name) expectedLayout=\(step.expectedLayout.rawValue) resolvedLayout=\(resolvedLayout.rawValue)"
                    )
                    return
                }

                self.runLayoutPresetRegressionSmokeSteps(
                    steps,
                    index: index + 1,
                    completion: completion
                )
            }
        }
    }
}
#endif
```

### 4.3 这一改动解决了什么

- iOS 现在不再只验证“模拟器能启动 + validation 能通过”，而是会真实执行 `side -> stacked -> side` 与近似旋转的尺寸变化链路。
- 这样可以覆盖之前最容易被忽略的“启动没问题，但切换后才出错”的运行时风险。
- `NSCoder.string(for:)` 也顺手把 smoke 日志里的 bounds 序列化收口到了当前 SDK 支持的 API，避免调试辅助逻辑本身引入编译噪音。

## 5. 本轮没有改什么

- 没有修改 `ExerciseNaturalNoteStripRailContract`、`fretboardLayoutContract`、renderer 约束策略或 `NaturalNoteStripView` 的内容尺寸算法。
- 没有新增任何用户可见的 settings 开关、导航入口或调试按钮。
- 没有改变正常启动路径；新的 smoke 逻辑只在 `DEBUG` 且命中特定环境变量时才会执行。
- 没有引入新的业务语义分支，依旧复用真实的 `SettingsPanelEvent` 与 controller 内部状态同步链路。

## 6. 最终状态总结

- 到阶段 5 为止，方案 B 的验证已经从“shared 语义断言”扩展到了“高风险运行时切换链路自动回归”。
- 双端应用现在都支持在启动后自动执行：
- `side -> stacked -> side`
- 一次额外尺寸变化
- 每一步都检查 `exerciseLayoutPreferences.layoutPreset` 是否与预期一致
- 通过则输出 `PASS` 摘要，失败则立即输出 `FAIL` 并终止
- 这意味着之前最容易反复出现的“切换时才崩”问题，已经不再只能靠人工复测发现。

## 7. 验证结果

- `ReadLints` 检查相关文件：无 linter 错误
- 构建验证命令（macOS）：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- 构建验证命令（iOS Simulator）：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`
- 构建结果（macOS）：`BUILD SUCCEEDED`
- 构建结果（iOS Simulator）：`BUILD SUCCEEDED`
- 启动期 validation 实跑结果：
- macOS：`SettingsNavigationValidation automated=PASS fixtures=11`，`ExerciseCompositionValidation automated=PASS fixtures=22`
- iOS：`SettingsNavigationValidation automated=PASS fixtures=11`，`ExerciseCompositionValidation automated=PASS fixtures=22`
- 运行时 smoke 实跑结果：
- macOS：带 `NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression` 启动后，`PASS`，退出码 `0`
- iOS Simulator：通过 `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression` 透传环境变量后，`PASS`，退出码 `0`
- 两端 smoke 都实际完成了：
- `side -> stacked -> side`
- 尺寸变化
- 最终回到 `sideBySide`
- 本轮自动化日志中未出现 `EXC_BAD_ACCESS`、`assertionFailure`、`fatal error`

## 8. 尚未自动化的边界

- 本轮已经自动覆盖了“启动 + 切换 + resize/近似旋转”的高风险链路。
- 但像“按钮在视觉上是否刚好是 `20x20`、右侧 strip 是否在人眼观感上完全居中”这类像素级 UI 结果，仍然属于手工视觉回归范畴。
- 阶段 5 这次解决的是“稳定性与回归重放”，不是把所有视觉验收都转成自动化图像比对。

## 9. 对后续维护的直接意义

- 以后如果 side/stacked 切换再次变脆，不需要先靠手工点一遍 settings；直接带环境变量启动就能重放同一条 smoke 链。
- 如果未来修改 renderer、settings 事件分发或 controller 的 presentation transaction，再出现运行时崩溃，阶段 5 这条 smoke 应该会先暴露问题。
- 这也让后续关于 side rail 的修改可以更放心地迭代，因为“启动期没问题但切换就崩”的历史坑，现在已经有自动化回归护栏了。

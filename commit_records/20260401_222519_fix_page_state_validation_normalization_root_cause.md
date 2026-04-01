# 20260401_222519_fix_page_state_validation_normalization_root_cause

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260401_222519`
- 记录范围：阶段 7 完成后，对 `ExerciseCompositionValidation` 启动期 fatal assertion 的根因修复
- 触发现象：DEBUG 启动时 `ExerciseCompositionValidationRunner.runAndReportIfNeeded(...)` 汇总出自动化夹具失败，最终在 `assertionFailure(summary)` 处中断；根因不是 `assertionFailure` 本身，而是 `page_state_normalization_preserves_single_fretboard_slot` 夹具的输入语义失真
- 根因概括：`PageDisplayState.init(...)` 会在构造时自动按 top 优先做 legacy 归一化，但 validation 夹具仍把 `PageDisplayState(top: .fretboard, main: .fretboard)` 当成“原始未归一化输入”去测 `main` 优先分支，导致 `main` 优先路径实际上永远喂不到
- 修改性质：把 legacy page 归一化拆成“原始 top/main mode -> 归一化 mode”的纯函数；`PageDisplayState` 和 validation 都走同一条 raw mode 归一化链，消除“构造对象时偷偷归一化”对夹具输入的污染
- 修改统计：`3 files changed, 51 insertions(+), 22 deletions(-)`
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift`
- `NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`

## 1. `ExerciseSceneValidator` 抽出“原始 legacy content modes -> 归一化结果”的纯函数

- 修改前：`normalizedLegacyPageDisplayState(...)` 直接接收 `PageDisplayState` 并在内部改写它。这样一来，所有想测试“原始 top/main 输入”的调用方，都必须先构造 `PageDisplayState` 实例；但这个类型自身又会在 `init(...)` 中自动归一化，导致原始输入语义在进入 validator 前就被污染。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: ExerciseSceneValidator.normalizedLegacyPageDisplayState(from:prioritizingTopContent:)
// 功能说明: 修改前 validator 只能接收已经构造好的 PageDisplayState，无法独立处理“原始 top/main mode”输入。
static func normalizedLegacyPageDisplayState(
    from pageDisplayState: PageDisplayState,
    prioritizingTopContent: Bool
) -> PageDisplayState {
    var normalized = pageDisplayState

    let showsFretboardInTopContent = normalized.topContentMode == .fretboard
    let showsFretboardInMainContent = normalized.mainContentMode == .fretboard
    guard showsFretboardInTopContent && showsFretboardInMainContent else {
        return normalized
    }

    if prioritizingTopContent {
        normalized.mainContentMode = .naturalNoteStrip
    } else {
        normalized.topContentMode = .staff
    }

    return normalized
}
```

- 修改后：新增 `normalizedLegacyPageContentModes(...)`，把归一化拆成一个只依赖原始 `PageTopContentMode` / `PageMainContentMode` 的纯函数；`normalizedLegacyPageDisplayState(...)` 再基于这个 helper 回填到 `PageDisplayState`。这样 `PageDisplayState`、validation、以及未来任何需要测“原始输入”的地方，都可以共享同一条可测试、可复用的归一化逻辑。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseSceneValidator.swift
// 函数名: ExerciseSceneValidator.normalizedLegacyPageDisplayState(from:prioritizingTopContent:), ExerciseSceneValidator.normalizedLegacyPageContentModes(topContentMode:mainContentMode:prioritizingTopContent:)
// 功能说明: 修改后 validator 先处理原始 top/main mode，再按需投影回 PageDisplayState，避免 PageDisplayState.init 的自动归一化污染测试输入。
static func normalizedLegacyPageDisplayState(
    from pageDisplayState: PageDisplayState,
    prioritizingTopContent: Bool
) -> PageDisplayState {
    let normalizedContentModes = normalizedLegacyPageContentModes(
        topContentMode: pageDisplayState.topContentMode,
        mainContentMode: pageDisplayState.mainContentMode,
        prioritizingTopContent: prioritizingTopContent
    )
    var normalized = pageDisplayState
    normalized.topContentMode = normalizedContentModes.topContentMode
    normalized.mainContentMode = normalizedContentModes.mainContentMode
    return normalized
}

static func normalizedLegacyPageContentModes(
    topContentMode: PageTopContentMode,
    mainContentMode: PageMainContentMode,
    prioritizingTopContent: Bool
) -> (topContentMode: PageTopContentMode, mainContentMode: PageMainContentMode) {
    var normalizedTopContentMode = topContentMode
    var normalizedMainContentMode = mainContentMode

    let showsFretboardInTopContent = normalizedTopContentMode == .fretboard
    let showsFretboardInMainContent = normalizedMainContentMode == .fretboard
    guard showsFretboardInTopContent && showsFretboardInMainContent else {
        return (
            topContentMode: normalizedTopContentMode,
            mainContentMode: normalizedMainContentMode
        )
    }

    if prioritizingTopContent {
        normalizedMainContentMode = .naturalNoteStrip
    } else {
        normalizedTopContentMode = .staff
    }

    return (
        topContentMode: normalizedTopContentMode,
        mainContentMode: normalizedMainContentMode
    )
}
```

## 2. `PageDisplayState.init(...)` 改成直接消费 raw mode helper，不再先构造自己再二次归一化

- 修改前：`PageDisplayState.init(...)` 先把传入值赋给 `self`，再调用 `normalizedLegacyPageDisplayState(from:self, ...)`。这让 `PageDisplayState` 本身继续保持“初始化即归一化”的语义，但也意味着任何通过 `PageDisplayState(...)` 构造出的对象，都已经不是原始输入了。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数名: PageDisplayState.init(...)
// 功能说明: 修改前 init 先构造 PageDisplayState 自身，再把自身送回 validator 做 top 优先归一化。
init(
    topContentMode: PageTopContentMode = .staff,
    mainContentMode: PageMainContentMode = .fretboard
) {
    self.topContentMode = topContentMode
    self.mainContentMode = mainContentMode
    self = ExerciseSceneValidator.normalizedLegacyPageDisplayState(
        from: self,
        prioritizingTopContent: true
    )
}
```

- 修改后：`PageDisplayState.init(...)` 直接调用 `normalizedLegacyPageContentModes(...)`，先拿到归一化后的 raw modes，再赋值给 `self`。这样 `PageDisplayState` 仍然保持“初始化即 top 优先归一化”的业务语义，但归一化入口已经和 validator 的 raw mode helper 合并，不再额外制造“对象已归一化、调用方却以为它还是原始输入”的结构性歧义。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数名: PageDisplayState.init(...)
// 功能说明: 修改后 init 直接消费 raw mode helper，再落成 PageDisplayState，避免通过 self 二次归一化造成输入语义混淆。
init(
    topContentMode: PageTopContentMode = .staff,
    mainContentMode: PageMainContentMode = .fretboard
) {
    let normalizedContentModes = ExerciseSceneValidator
        .normalizedLegacyPageContentModes(
        topContentMode: topContentMode,
        mainContentMode: mainContentMode,
        prioritizingTopContent: true
    )
    self.topContentMode = normalizedContentModes.topContentMode
    self.mainContentMode = normalizedContentModes.mainContentMode
}
```

## 3. `ExerciseCompositionValidation` 不再用“已自动归一化的 PageDisplayState”去伪装原始输入

- 修改前：`validatePageStateNormalizationPreservesSingleFretboardSlot()` 在测试 top 优先 / main 优先两个 legacy 归一化分支时，直接构造 `PageDisplayState(top: .fretboard, main: .fretboard)` 再传给 `normalizedLegacyPageDisplayState(...)`。但这个构造动作本身已经触发了 top 优先归一化，因此 `main` 优先分支根本拿不到它想测的原始输入。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.validatePageStateNormalizationPreservesSingleFretboardSlot()
// 功能说明: 修改前夹具把自动归一化后的 PageDisplayState 当作原始输入，导致 main 优先路径实际不可达。
static func validatePageStateNormalizationPreservesSingleFretboardSlot()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "page_state_normalization_preserves_single_fretboard_slot"
    var issues: [ExerciseCompositionValidationIssue] = []

    let topPrioritizedState = ExerciseSceneValidator
        .normalizedLegacyPageDisplayState(
            from: PageDisplayState(
                topContentMode: .fretboard,
                mainContentMode: .fretboard
            ),
            prioritizingTopContent: true
        )

    let mainPrioritizedState = ExerciseSceneValidator
        .normalizedLegacyPageDisplayState(
            from: PageDisplayState(
                topContentMode: .fretboard,
                mainContentMode: .fretboard
            ),
            prioritizingTopContent: false
        )

    let initNormalizedState = PageDisplayState(
        topContentMode: .fretboard,
        mainContentMode: .fretboard
    )
    // ... 后续断言省略
    return issues
}
```

- 修改后：这个夹具改成先用 `normalizedLegacyPageContentModes(...)` 显式处理 raw mode，再把结果装配成 `PageDisplayState` 去做后续断言。这样它能分别测到 top 优先和 main 优先两条真实路径，同时保留 `PageDisplayState.init(...)` 仍然默认 top 优先归一化的业务断言。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: ExerciseCompositionValidationRunner.validatePageStateNormalizationPreservesSingleFretboardSlot()
// 功能说明: 修改后夹具先显式处理 raw top/main mode，再分别验证 top 优先、main 优先和 PageDisplayState.init 的默认归一化语义。
static func validatePageStateNormalizationPreservesSingleFretboardSlot()
    -> [ExerciseCompositionValidationIssue] {
    let fixtureName = "page_state_normalization_preserves_single_fretboard_slot"
    var issues: [ExerciseCompositionValidationIssue] = []

    let topPrioritizedContentModes = ExerciseSceneValidator
        .normalizedLegacyPageContentModes(
            topContentMode: .fretboard,
            mainContentMode: .fretboard,
            prioritizingTopContent: true
        )
    let topPrioritizedState = PageDisplayState(
        topContentMode: topPrioritizedContentModes.topContentMode,
        mainContentMode: topPrioritizedContentModes.mainContentMode
    )

    let mainPrioritizedContentModes = ExerciseSceneValidator
        .normalizedLegacyPageContentModes(
            topContentMode: .fretboard,
            mainContentMode: .fretboard,
            prioritizingTopContent: false
        )
    let mainPrioritizedState = PageDisplayState(
        topContentMode: mainPrioritizedContentModes.topContentMode,
        mainContentMode: mainPrioritizedContentModes.mainContentMode
    )

    let initNormalizedState = PageDisplayState(
        topContentMode: .fretboard,
        mainContentMode: .fretboard
    )
    if initNormalizedState != topPrioritizedState {
        issues.append(
            issue(
                fixtureName,
                "PageDisplayState 初始化仍应保持 top 优先的 legacy 归一化结果。"
            )
        )
    }

    return issues
}
```

## 4. 修复后的影响边界

- `PageDisplayState` 的业务语义没有变化：仍然保持“初始化默认走 top 优先归一化”。
- `ExerciseSceneValidator` 现在额外暴露了 raw mode 级别的 helper，调用方可以明确表达“我是在测原始输入”还是“我是在处理已构造状态”。
- `ExerciseCompositionValidation` 恢复了对 `main` 优先 legacy 归一化路径的真实覆盖，不再依赖一个已经会自动归一化的对象实例伪装原始输入。

## 5. 验证结果

- `ReadLints`
  结果：`No linter errors found.`
- macOS Debug 构建
  命令：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" build`
  结果：`BUILD SUCCEEDED`
- iOS Simulator Debug 构建
  命令：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" build`
  结果：`BUILD SUCCEEDED`

## 6. 构建与回归备注

- 本次修复直接针对触发 fatal 的 validation 夹具输入失真问题，而不是简单注释掉 `assertionFailure` 或放宽断言条件。
- 当前命令行验证覆盖到了 lint 和双平台编译链闭合；没有在当前 shell 环境里稳定重放完整 App 启动链输出。

# 20260329_170153_phase6_position_prompt_fret_filter_validation_and_checklist

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_170153`
- 记录范围：实施“Position 品位筛选”计划的阶段 6，只补充 shared validation 与手工回归清单，不改动 iOS / macOS 控制器和设置 UI 结构
- 本次目标：把 `positionPrompt` 的品位筛选能力补成可回归的验证资产，覆盖默认全选、子集筛选、排除空弦、最后一个品位不可取消，以及筛选切换时的界面稳定性检查
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `.cursor/plans/position品位筛选_cb2e8023.plan.md`

## 本次结论

- `validatePositionPromptTrainer(fixture:record:)` 不再只验证“默认全选 `1...12`”这一条路径，而是抽成了一个可复用的 `validateAllowedFretsScenario(...)` 场景校验器
- 自动化校验现在会同时覆盖：
- 默认全选 `1...12` 时，候选池与 session 都不包含空弦
- 子集 `{1, 3, 5, 7}` 时，出题、错题保持、答对换题都继续落在允许品位内
- 只剩最后一个已选品位时，`canDeselect(_:)` 与 `toggled(fret:)` 不会把它取消
- `manualChecklist(for:)` 已补上 positionPrompt 品位筛选对应的手工回归项，方便后续在 iOS / macOS 实机确认 UI 与交互时序
- 计划文件里的 `phase6-validation` 已收尾为 `completed`

## 修改 1：`validatePositionPromptTrainer(...)` 从“单一默认场景”扩展为“多场景校验 + 最后一个品位保护断言”

### 修改前

- 旧实现只围绕 `allowedFrets = defaultSelectedFrets` 跑一套固定流程
- 它能覆盖默认 `1...12` 的基本出题、答错不换题、答对换题
- 但还不能复用到子集筛选 `{1, 3, 5, 7}`
- 也没有显式断言“最后一个已选品位不可取消”这一条状态约束

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改前只针对默认 allowedFrets 跑一套固定验证流程；
// 缺少对子集筛选场景的复用入口，也没有覆盖最后一个品位不可取消的保护断言。
static func validatePositionPromptTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    guard fixture.name == "horizontal-guitar6-reference" else {
        return
    }

    func logStage(_ name: String) {
        print("[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] stage=\(name)")
    }

    let configuration = fixture.configuration
    let allowedFrets = TrainerPositionPromptConfiguration.defaultSelectedFrets
    logStage("candidateEnumeration")
    let candidateCells = positionPromptCandidateCells(
        configuration: configuration,
        allowedFrets: allowedFrets
    )
    guard candidateCells.count >= 2 else {
        record("position prompt trainer 缺少至少两个自然音位置，无法验证换题语义。")
        return
    }

    // ... 这里继续用同一组 allowedFrets 依次校验 initial / wrong / correct 三段流程 ...
}
```

### 修改后

- 新增 `validateAllowedFretsScenario(name:allowedFrets:requiresNoOpenStrings:)`
- 这个内部辅助函数会对指定品位集合重复跑完整流程：
- 候选池是否只含允许品位
- 是否排除了空弦
- 新建 session 是否落在允许品位
- 错误作答后是否仍停留在当前合法题
- 正确作答后排除当前题再换题时，是否仍落在允许品位
- 在函数尾部新增 `lastSelectedFretGuard` 断言，直接验证 `TrainerPositionPromptConfiguration` 的最后一个品位保护语义
- 最后分别执行：
- `defaultSelectedFrets`
- `subset_1_3_5_7`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: validatePositionPromptTrainer(fixture:record:)
// 功能说明: 修改后把品位校验抽成可复用场景，既覆盖默认 1...12，
// 也覆盖子集 {1,3,5,7}；同时补上“最后一个已选品位不可取消”的状态断言。
static func validatePositionPromptTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    guard fixture.name == "horizontal-guitar6-reference" else {
        return
    }

    func logStage(_ name: String) {
        print("[FretboardValidation][fixture=\(fixture.name)][validatePositionPromptTrainer] stage=\(name)")
    }

    let configuration = fixture.configuration

    func validateAllowedFretsScenario(
        name: String,
        allowedFrets: Set<Int>,
        requiresNoOpenStrings: Bool
    ) {
        let normalizedAllowedFrets = TrainerPositionPromptConfiguration(
            selectedFrets: allowedFrets
        ).selectedFrets

        logStage("\(name)-candidateEnumeration")
        let candidateCells = positionPromptCandidateCells(
            configuration: configuration,
            allowedFrets: normalizedAllowedFrets
        )
        guard candidateCells.count >= 2 else {
            record("position prompt trainer \(name) 缺少至少两个自然音位置，无法验证换题语义。")
            return
        }

        if !candidateCells.allSatisfy({ normalizedAllowedFrets.contains($0.fret) }) {
            record("position prompt trainer \(name) 的候选池包含了未允许的品位。")
        }
        if requiresNoOpenStrings,
           candidateCells.contains(where: { $0.fret == 0 }) {
            record("position prompt trainer \(name) 候选池不应包含空弦。")
        }

        // ... 这里继续复用同一套 initial / wrong / correct 流程，
        // 并把所有断言都绑定到当前 normalizedAllowedFrets ...
    }

    logStage("lastSelectedFretGuard")
    let lockedFretConfiguration = TrainerPositionPromptConfiguration(
        selectedFrets: [7]
    )
    if lockedFretConfiguration.canDeselect(7) {
        record("position prompt 配置在只剩最后一个已选品位时不应允许 canDeselect 返回 true。")
    }
    if lockedFretConfiguration.toggled(fret: 7).selectedFrets != Set([7]) {
        record("position prompt 配置在只剩最后一个已选品位时，不应允许 toggled(fret:) 取消该品位。")
    }

    validateAllowedFretsScenario(
        name: "defaultSelectedFrets",
        allowedFrets: TrainerPositionPromptConfiguration.defaultSelectedFrets,
        requiresNoOpenStrings: true
    )
    validateAllowedFretsScenario(
        name: "subset_1_3_5_7",
        allowedFrets: [1, 3, 5, 7],
        requiresNoOpenStrings: true
    )
}
```

## 修改 2：`manualChecklist(for:)` 补齐 positionPrompt 品位筛选的手工回归项

### 修改前

- 原手工清单主要覆盖通用指板点击、目标音判定、vertical 几何与平台行为
- 没有任何一条专门检查：
- `single / sequence` 是否隐藏 `Frets` 行
- `positionPrompt` 默认是否全选 `1...12`
- 子集筛选后出题是否受限
- 最后一个品位是否不能取消
- 在 `wrongFlash / correctHold` 阶段切换筛选时，是否能平滑重建非法题

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: manualChecklist(for:)
// 功能说明: 修改前的手工清单只覆盖指板与 vertical 相关回归，
// 还没有 positionPrompt 品位筛选自己的 UI / 时序检查项。
static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
    var checklist = [
        "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
        "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
        "观察页面加载后的控制台目标音日志；点击与目标同名但不同八度的音位，确认判定为 correct，并立即打印下一题目标音。",
        "当目标音为 C 时点击 C# 等升降音，确认控制台判定为 wrong，且当前目标音不切换。",
        "在 vertical 模式下拖动高度滑块，确认指板 host 高度立即跟随变化，滑块数值与页面可见占比一致。",
        "在 vertical 模式下改变窗口或设备高度，并在 Horizontal / Vertical 之间往返切换；确认指板宽度会自适应变化并保持水平居中，且切回 vertical 后沿用上次滑块值。"
    ]

    // ... 后面继续按平台追加 iOS / macOS / commandLine 专属项 ...
}
```

### 修改后

- 在通用 checklist 尾部追加了 5 条与本次功能直接对应的回归项
- 这些项把自动化覆盖不到的 UI 表现、模式切换可见性、错误 overlay 清理与延时任务稳定性都纳入了手工验收范围

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名/符号: manualChecklist(for:)
// 功能说明: 修改后把 positionPrompt 品位筛选的可见性、默认值、
// 子集出题范围、最后一个品位保护、反馈阶段切换稳定性都写入手工回归清单。
static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
    var checklist = [
        "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
        "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
        "观察页面加载后的控制台目标音日志；点击与目标同名但不同八度的音位，确认判定为 correct，并立即打印下一题目标音。",
        "当目标音为 C 时点击 C# 等升降音，确认控制台判定为 wrong，且当前目标音不切换。",
        "在 vertical 模式下拖动高度滑块，确认指板 host 高度立即跟随变化，滑块数值与页面可见占比一致。",
        "在 vertical 模式下改变窗口或设备高度，并在 Horizontal / Vertical 之间往返切换；确认指板宽度会自适应变化并保持水平居中，且切回 vertical 后沿用上次滑块值。",
        "在 `single` 与 `sequence` 模式下打开设置面板，确认 `Trainer` 分区不显示 `Frets` 这一行；切到 `positionPrompt` 后再确认该行出现，并默认选中 `1...12`。",
        "在 `positionPrompt` 默认全选状态下连续答对多次，确认题目不会落在空弦，只会出现在 `1...12` 品。",
        "在 `positionPrompt` 里只保留 `1 / 3 / 5 / 7` 这几个品位后连续答对多次，确认当前题与下一题都只落在这些品位。",
        "尝试连续取消品位直到只剩最后一个已选格子，再继续点击该格子；确认 UI 仍保持至少一个品位被选中。",
        "在 `wrongFlash` 或 `correctHold` 期间切换品位筛选；若当前可见题目已变成非法题，确认界面会平滑切换到新题，不残留错误 overlay 或延时切题任务。"
    ]

    // ... 后面继续按平台追加 iOS / macOS / commandLine 专属项 ...
}
```

## 修改 3：计划文件把 `phase6-validation` 标记为已完成

### 修改前

- 阶段 6 实施前，这一项仍未收尾
- 当前工作区里需要把该阶段状态从进行中切到完成，和实际代码状态保持一致

```yaml
# 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md
# 函数名/符号: todos[phase6-validation]
# 功能说明: 修改前阶段 6 还没有在计划文件里正式收尾。
- id: phase6-validation
  content: 补充 FretboardValidation 与手工回归清单，覆盖全选、子集筛选、排除空弦与最后一个品位不可取消等场景
  status: in_progress
```

### 修改后

- 计划文件已经和当前实现状态对齐
- `phase6-validation` 现已标记为 `completed`

```yaml
# 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md
# 函数名/符号: todos[phase6-validation]
# 功能说明: 修改后阶段 6 已正式收尾，计划状态与当前代码实现保持一致。
- id: phase6-validation
  content: 补充 FretboardValidation 与手工回归清单，覆盖全选、子集筛选、排除空弦与最后一个品位不可取消等场景
  status: completed
```

## 验证情况

- 已对 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift` 读取静态诊断，当前无 linter 错误
- 本次未运行 `xcodebuild` 或双端实机手工回归；新增的手工回归路径已写入 `manualChecklist(for:)`，后续可直接按清单执行

## 与阶段目标的对应关系

- “默认全选 `1...12` 时，候选池不含空弦”：已在 `validateAllowedFretsScenario(name: "defaultSelectedFrets", ...)` 中覆盖
- “子集 `{1, 3, 5, 7}` 时，新建题目与答对后换题都只落在这些品位”：已在 `validateAllowedFretsScenario(name: "subset_1_3_5_7", ...)` 中覆盖
- “当排除当前题目后重新抽题，仍满足 `allowedFrets`”：已通过 `correctAnswer` 分支对 `evaluation.nextPromptCell` 与 `correctSession.promptCell` 进行断言
- “最后一个品位不可取消”：已通过 `lockedFretConfiguration.canDeselect(7)` 与 `toggled(fret: 7)` 两个断言覆盖
- “补手工回归清单”：已在 `manualChecklist(for:)` 中追加 positionPrompt fret filter 相关项

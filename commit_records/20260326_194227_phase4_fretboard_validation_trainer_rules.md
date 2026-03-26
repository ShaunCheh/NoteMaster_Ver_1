# 20260326_194227_phase4_fretboard_validation_trainer_rules

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_194227`
- 记录范围：阶段 4，共享层指板验证补齐音高解析与自然音 trainer 规则
- 本次目标：把阶段 1 的音高解析出口与阶段 2/3 的自然音练习规则正式纳入 `FretboardValidationRunner` 自动化覆盖范围，并同步补齐手工回归清单
- 根因结论：修改前 `FretboardValidationRunner` 只覆盖几何、命中、marker 与朝向等共享层场景，但对 `notePitch / pitchClass` 的解析真相，以及 `FretboardNaturalNoteTrainerState` 的判题规则完全没有自动化保护。这样即使功能能跑，一旦后续改动把 `C#` 误判成 `C`、或者把答错后的切题规则写坏，也不会被现有 validation 发现
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 本次完成的修改

1. 在 `validate(_ fixture:)` 的总装配流程中新增 `validatePitchResolution(...)` 与 `validateNaturalNoteTrainer(...)`。
2. 新增音高解析验证：覆盖 `notePitch` / `pitchClass` 的直接入口、`FretboardCell` 入口以及越界输入。
3. 新增自然音 trainer 验证：覆盖非 `ended` 事件忽略、空命中忽略、非法 cell 忽略、升降音误判保护、不同八度同名音命中为正确，以及答对后切题规则。
4. 扩展 `manualChecklist(...)`，补上目标音日志、同名异八度正确、升降音错误且不切题等手工验证项。
5. 增加 `makeHitResult(...)` 辅助构造器，供 validation 夹具复用生成 trainer 输入事件。

## 修改 1：validation runner 总装配新增音高解析与 trainer 规则校验

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.validate(_:)
// 功能说明: 修改前 validation runner 只覆盖几何、scene、marker 和命中测试；
// 对 notePitch / pitchClass 解析与自然音 trainer 判题规则没有自动化校验入口。
validateHitTesting(
    scene: scene,
    fixture: fixture,
    sceneBuilder: sceneBuilder,
    record: record
)

return issues
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationRunner.validate(_:)
// 功能说明: 修改后 validation runner 在既有几何验证之后，
// 继续执行音高解析与 trainer 规则验证，确保功能规则也纳入共享层回归保护。
validateHitTesting(
    scene: scene,
    fixture: fixture,
    sceneBuilder: sceneBuilder,
    record: record
)
validatePitchResolution(
    fixture: fixture,
    record: record
)
validateNaturalNoteTrainer(
    fixture: fixture,
    record: record
)

return issues
```

## 修改 2：新增音高解析自动化验证

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: validatePitchResolution(fixture:record:)
// 功能说明: 修改前该函数不存在；
// 共享层没有自动化检查去验证 stringIndex + fret -> NotePitch / PitchClass 的解析真相是否正确。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: validatePitchResolution(fixture:record:)
// 功能说明: 修改后 validation 会逐弦逐品验证 NotePitch / PitchClass 解析，
// 并确认 FretboardCell 入口与直接入口一致，同时对越界 stringIndex / fret 做 nil 保护检查。
static func validatePitchResolution(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    let configuration = fixture.configuration

    for stringIndex in 0..<configuration.stringCount {
        guard let openPitch = configuration.tuning.openStringPitch(for: stringIndex) else {
            record("string[\(stringIndex)] 找不到空弦音高。")
            continue
        }

        for fret in configuration.fretRange {
            let expectedPitch = openPitch.advanced(by: fret)
            let cell = FretboardCell(
                stringIndex: stringIndex,
                fret: fret
            )

            guard let resolvedPitch = configuration.notePitch(
                stringIndex: stringIndex,
                fret: fret
            ) else {
                record("cell(\(stringIndex), \(fret)) 无法解析 NotePitch。")
                continue
            }

            if resolvedPitch != expectedPitch {
                record(
                    "cell(\(stringIndex), \(fret)) NotePitch 解析错误，期望 \(expectedPitch.displayText())，实际 \(resolvedPitch.displayText())。"
                )
            }

            if configuration.notePitch(for: cell) != expectedPitch {
                record("cell(\(stringIndex), \(fret)) 的 cell 入口 NotePitch 解析与直接入口不一致。")
            }

            if configuration.pitchClass(
                stringIndex: stringIndex,
                fret: fret
            ) != expectedPitch.pitchClass {
                record("cell(\(stringIndex), \(fret)) 的 pitchClass 解析与 NotePitch 不一致。")
            }
        }
    }

    if configuration.notePitch(stringIndex: -1, fret: 0) != nil {
        record("非法 stringIndex(-1) 仍然解析出了 NotePitch。")
    }
}
```

## 修改 3：新增自然音 trainer 自动化验证

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: validateNaturalNoteTrainer(fixture:record:)
// 功能说明: 修改前该函数不存在；
// 共享层没有自动化验证去保护“忽略非 ended、升降音不判成自然音、答对才切题”等 trainer 规则。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: validateNaturalNoteTrainer(fixture:record:)
// 功能说明: 修改后 validation 会针对自然音 trainer 执行规则级回归，
// 覆盖无效点击忽略、升降音误判保护、同名异八度命中为正确，以及答对后切题逻辑。
static func validateNaturalNoteTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    guard fixture.name == "horizontal-guitar6-reference" else {
        return
    }

    let configuration = fixture.configuration
    let correctCell = FretboardCell(stringIndex: 2, fret: 10)
    let accidentalCell = FretboardCell(stringIndex: 1, fret: 4)
    let invalidCell = FretboardCell(
        stringIndex: configuration.stringCount,
        fret: 0
    )

    var ignoredPhaseTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
    let ignoredPhaseResult = ignoredPhaseTrainer.handle(
        hitResult: makeHitResult(
            phase: .began,
            cell: correctCell
        ),
        configuration: configuration
    )
    if ignoredPhaseResult != .ignored(.nonEndedPhase(.began)) {
        record("trainer 对非 ended 事件未返回 ignored(.nonEndedPhase(.began))。")
    }

    var incorrectTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
    switch incorrectTrainer.handle(
        hitResult: makeHitResult(
            phase: .ended,
            cell: accidentalCell
        ),
        configuration: configuration
    ) {
    case let .evaluated(evaluation):
        if evaluation.isCorrect {
            record("trainer 把升降音错判成了目标自然音。")
        }
        if evaluation.nextTargetPitchClass != .c {
            record("trainer 在答错后不应切换到下一题。")
        }
    default:
        record("trainer 对错误命中未返回 evaluated 结果。")
    }

    var correctTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
    switch correctTrainer.handle(
        hitResult: makeHitResult(
            phase: .ended,
            cell: correctCell
        ),
        configuration: configuration
    ) {
    case let .evaluated(evaluation):
        if !evaluation.isCorrect {
            record("trainer 未把同名异八度的 C 判定为正确。")
        }
        if evaluation.nextTargetPitchClass == .c {
            record("trainer 在答对后未切换到新的目标音。")
        }
    default:
        record("trainer 对正确命中未返回 evaluated 结果。")
    }
}
```

## 修改 4：手工回归清单补充练习流验证项

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: manualChecklist(for:)
// 功能说明: 修改前手工清单只覆盖指板几何、点击命中、高度滑块和尺寸变化；
// 没有覆盖目标音日志、同名异八度判定和升降音误判保护。
var checklist = [
    "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
    "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
    "在 vertical 模式下拖动高度滑块，确认指板 host 高度立即跟随变化，滑块数值与页面可见占比一致。",
    "在 vertical 模式下改变窗口或设备高度，并在 Horizontal / Vertical 之间往返切换；确认指板宽度会自适应变化并保持水平居中，且切回 vertical 后沿用上次滑块值。"
]
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: manualChecklist(for:)
// 功能说明: 修改后手工清单补充了练习流验证项，
// 明确要求验证初始目标音日志、同名异八度正确、升降音错误且不切题。
var checklist = [
    "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
    "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
    "观察页面加载后的控制台目标音日志；点击与目标同名但不同八度的音位，确认判定为 correct，并立即打印下一题目标音。",
    "当目标音为 C 时点击 C# 等升降音，确认控制台判定为 wrong，且当前目标音不切换。",
    "在 vertical 模式下拖动高度滑块，确认指板 host 高度立即跟随变化，滑块数值与页面可见占比一致。",
    "在 vertical 模式下改变窗口或设备高度，并在 Horizontal / Vertical 之间往返切换；确认指板宽度会自适应变化并保持水平居中，且切回 vertical 后沿用上次滑块值。"
]
```

## 修改 5：新增 validation 专用 hitResult 构造器

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: makeHitResult(phase:cell:)
// 功能说明: 修改前该辅助函数不存在；
// trainer 规则验证无法在共享层方便地构造统一的 FretboardHitResult 夹具。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: makeHitResult(phase:cell:)
// 功能说明: 修改后 validation 可以统一构造 ended / began / 空命中 / 非法 cell 等事件输入，
// 避免 trainer 测试逻辑在多个调用点重复拼装 FretboardHitResult。
static func makeHitResult(
    phase: FretboardEventPhase,
    cell: FretboardCell?
) -> FretboardHitResult {
    FretboardHitResult(
        phase: phase,
        locationInView: .zero,
        cell: cell,
        isInsideDrawingRect: cell != nil,
        distanceToNearestString: nil
    )
}
```

## 这次修改解决了什么

- 解决了“指板 validation 只看几何，不看功能规则”的共享层保护缺口。
- 让 `notePitch / pitchClass` 解析真相正式进入自动化回归。
- 让自然音 trainer 的关键规则正式进入自动化回归：忽略条件、同名异八度正确、升降音错误、答对后切题。
- 让手工回归清单和当前练习功能语义保持一致。

## 本次明确未修改的边界

- 未修改 `FretboardNaturalNoteTrainer.swift`
- 未修改 `iOSViewController.swift`
- 未修改 `macOSViewController.swift`
- 未修改任何几何布局、滚动、或平台视图代码
- 未新增新的 fixture 文件，仍沿用现有 `FretboardValidationRunner` 夹具体系

## 验证结果

### 静态检查

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`，结果为无错误

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 对 Shared/Fretboard 下的 Swift 文件执行 typecheck，确认新增 validation 逻辑不引入编译问题。
xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift
```

- 结果：通过

### 命令行验证

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 使用临时入口编译并执行 FretboardValidationRunner.run(platform: .commandLine)，确认自动化夹具与新增规则校验全部通过。
xcrun swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  -o /tmp/fretboard_validation_check \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  /tmp/fretboard_validation_check.swift && \
/tmp/fretboard_validation_check
```

- 结果：`[FretboardValidation][commandLine] automated=PASS fixtures=7`
- 结论：阶段 4 新增的音高解析与自然音 trainer 规则已经纳入共享层回归，并在命令行 validation runner 下通过

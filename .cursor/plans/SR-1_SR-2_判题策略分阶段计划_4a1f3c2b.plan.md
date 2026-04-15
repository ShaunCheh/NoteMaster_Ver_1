---
name: ""
overview: ""
todos: []
isProject: false
---

可以，方案三就按“先抽象答案语义，再接 `SR-1` 模式”推进。  
核心结论先定死：

- `SR-1` / `SR-2` 不要再各自造一套 trainer 内核，继续复用现在的 `quarterNoteSequence` 内容生成链路。
- `answerPolicy` 是“判题规则”，不是“谱面内容”，所以它应该挂在 `TrainerSequenceConfiguration -> QuarterNoteSequenceSpec` 这条链路上，不应该塞进 `GeneratedNoteSequence` 本体。
- `SR-1` 先用 `.pitchClass`，`SR-2` 以后只把 mode 归一化切到 `.exactNote`。
- 这里的 `exactNote` 先明确成 `NotePitch` 级别，也就是“音名 + 八度”。不比较记谱 spelling，`C#` / `Db` 这种书写等价问题不纳入这次埋点范围。

这几处代码就是现在的根：

```424:441:NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
extension TrainerSequenceConfiguration {
    init(
        quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec
    ) {
        self.init(
            clef: quarterNoteSequenceSpec.clef,
            noteCount: quarterNoteSequenceSpec.noteCount,
            includesAccidentals: quarterNoteSequenceSpec.includesAccidentals
        )
    }

    var quarterNoteSequenceSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec {
        FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
            clef: clef,
            noteCount: noteCount,
            includesAccidentals: includesAccidentals
        )
    }
}
```

```105:132:NoteMaster_Ver_1/Shared/Exercise/ExerciseAnswerRouter.swift
case .sequence:
    guard let pitchClass = FretboardNaturalNoteTrainerState
        .resolvedPitchClass(
            from: event,
            configuration: fretboardConfiguration
        ) else {
        if let cell = event.payload.fretboardCell {
            return .ignored(
                .unresolvedPitchClass(
                    cell,
                    trainerDisplayState.exerciseMode
                )
            )
        }
        return .ignored(
            .unsupportedPayload(
                event.payload,
                trainerDisplayState.exerciseMode
            )
        )
    }

    return .routed(
        .quarterNoteSequence(
            event: event,
            pitchClass: pitchClass
        )
    )
```

```797:827:NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
mutating func handleQuarterNoteSequenceAnswer(
    _ pitchClass: PitchClass,
    session: inout QuarterNoteSequenceSession
) -> QuarterNoteSequenceAnswerResult {
    let generatedSequence = requireCurrentQuarterNoteSequence()
    precondition(
        session.generatedSequence == generatedSequence,
        "Quarter-note sequence session sequence must match the current trainer sequence."
    )

    guard let expectedItem = session.currentItem else {
        return .ignored(.completedSession)
    }

    let answeredIndex = session.currentIndex
    let expectedPitchClass = expectedItem.answerPitchClass
    let isCorrect = pitchClass == expectedPitchClass
    let nextIndex = isCorrect ? answeredIndex + 1 : answeredIndex
    if isCorrect {
        session.currentIndex = nextIndex
    }

    return .evaluated(
        QuarterNoteSequenceEvaluation(
            expectedItem: expectedItem,
            answeredPitchClass: pitchClass,
            answeredIndex: answeredIndex,
            nextIndex: nextIndex,
            totalCount: session.totalCount
        )
    )
}
```

```18:31:NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift
static func makePresentation(
    from input: ExerciseCompositionPolicyInput
) -> ExercisePresentationState {
    var resolvedLayoutPreferences = ExerciseCompositionPolicy
        .normalizedPreferences(
            input.layoutPreferences,
            trainerDisplayState: input.trainerDisplayState
        )
    resolvedLayoutPreferences.isPianoAccessoryVisible = resolvedLayoutPreferences
        .isPianoAccessoryVisible
        || input.pianoPanelState.isVisible
    let scene = makeScene(
        preferences: resolvedLayoutPreferences
    )
```

`iOSExerciseSceneRenderer` / `macOSExerciseSceneRenderer` 本身已经能挂 `.piano` surface，所以真正要改的不是 renderer 能不能显示钢琴，而是“答题抽象”“preset 组合”“主场景 piano 与 accessory piano 去重”。

##阶段 0：冻结共享语义边界
目标：先把 SR-1 / SR-2 的语义边界定住，避免后面一边做一边改定义。

改动面：`Shared/Controls/TrainerDisplayState.swift`、`Shared/Fretboard/FretboardNaturalNoteTrainer.swift`、相关 validation 文件。

要定下来的约束：

- 新增 `TrainerSequenceAnswerPolicy`，建议只有两个 case：`.pitchClass`、`.exactNote`。
- `SR-1` 固定使用 `.pitchClass`。
- `SR-2` 未来固定使用 `.exactNote`。
- `exactNote` 只比较 `writtenPitch.notePitch` 和输入 `NotePitch`，不比较 spelling。
- `quarterNoteSequence` 继续是内容引擎，`SR-1` / `SR-2` 只存在于 `TrainerExerciseMode` 和 composition / controller 层，不下沉成新的 trainer mode。

完成标准：

- 命名和语义一次定死。
- 不改任何运行时行为。

##阶段 1：把 `answerPolicy` 挂进现有 sequence 配置链路
目标：先把“判题策略”放进现在已经存在的配置传输链，而不是另拉一条 SR 专属配置通道。

改动面：`Shared/Controls/TrainerDisplayState.swift`、`Shared/Fretboard/FretboardNaturalNoteTrainer.swift`、`Platform/iOS/iOSViewController.swift`、`Platform/macOS/macOSViewController.swift`。

具体做法：

- 给 `TrainerSequenceConfiguration` 增加 `answerPolicy`，默认 `.pitchClass`。
- 给 `FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec` 同步增加 `answerPolicy`。
- 补齐 `TrainerSequenceConfiguration.init(quarterNoteSequenceSpec:)` 和 `quarterNoteSequenceSpec` 的双向映射。
- `QuarterNoteSequenceEvaluation` 里提前预埋 `comparisonPolicy`，并增加 `expectedNotePitch` 的只读投影。
- 这里不把 `answerPolicy` 塞进 `GeneratedNoteSequence`，因为它不是谱面内容。

完成标准：

- 现有 `single / sequence / positionPrompt` 编译通过，行为完全不变。
- `configuredQuarterNoteSequenceSpec` 这条现有 controller 链路自动带上新字段，不需要开新入口。

##阶段 2：抽出统一的 sequence 答案载体
目标：先解决“router 只能产出 `PitchClass`”这个根问题。

改动面：`Shared/Exercise/ExerciseAnswerEvent.swift`、`Shared/Exercise/ExerciseAnswerRouter.swift`、`Shared/Fretboard/FretboardNaturalNoteTrainer.swift`。

建议新增两个共享契约：

- `ExerciseAnswerPayload.notePitch(NotePitch)`
- `ResolvedSequenceAnswer`
内容至少包含：`pitchClass`、`notePitch?`、`surfaceID`

具体做法：

- `ExerciseAnswerPayload` 增加 `.notePitch(NotePitch)`。
- `ExerciseAnswerRouter` 的 sequence 分支不再返回裸 `pitchClass`，而是返回 `ResolvedSequenceAnswer`。
- `FretboardNaturalNoteTrainerState` 新增类似 `resolvedSequenceAnswer(from:event, configuration:)` 的 helper。
- `single` 和 `positionPrompt` 先保持现在的专用路由，不强行在这一阶段全部统一，避免 blast radius 过大。

完成标准：

- 指板和 notestrip 现有 sequence 路由结果不变。
- shared 层已经能承载“有 `pitchClass` 也有 `notePitch`”的答案输入。

##阶段 3：把 sequence 判题从“硬编码 pitchClass”改成“按 policy 比较”
目标：把 SR-2 最关键的 seam 真正埋进 trainer，而不是只在设置里挂个字段。

改动面：`Shared/Fretboard/FretboardNaturalNoteTrainer.swift`、`Shared/Fretboard/GeneratedNoteSequence.swift`、相关 validation。

具体做法：

- `handleQuarterNoteSequenceAnswer` 入参从 `PitchClass` 改成 `ResolvedSequenceAnswer`。
- 比较逻辑改成统一 comparator：
  - `.pitchClass`：比较 `resolved.pitchClass == expectedItem.answerPitchClass`
  - `.exactNote`：比较 `resolved.notePitch == expectedItem.writtenPitch.notePitch`
- `QuarterNoteSequenceEvaluation` 增加：
  - `comparisonPolicy`
  - `answeredNotePitch`
  - `expectedNotePitch`
- `debugSummary()` 把 policy 打出来，后面排查 SR-1 / SR-2 会很省事。
- `GeneratedNoteSequenceItem` 不需要大改，只增加 `expectedNotePitch` 一类的 computed property 即可。

完成标准：

- 现在 UI 还没接 piano，也要先把 comparator 测透。
- 至少覆盖这 4 组自动化校验：
  - 期望 `C6`，回答 `C`，`.pitchClass` 下为正确
  - 期望 `C6`，回答 `C3`，`.pitchClass` 下为正确
  - 期望 `C6`，回答 `C3`，`.exactNote` 下为错误
  - 期望 `C6`，回答 `C6`，`.exactNote` 下为正确

##阶段 4：新增 `staffToPiano` 组合，让 piano 成为正式 answer surface
目标：让 SR-1 像现在“指板 + notestrip”一样走正式 scene 组合，而不是 controller 临时拼 UI。

改动面：`Shared/Exercise/ExerciseLayoutPreferences.swift`、`Shared/Exercise/ExerciseScene.swift`、`Shared/Exercise/ExerciseCompositionPolicy.swift`、`Shared/Exercise/ExerciseCompositionPolicy+Normalization.swift`、`Shared/Exercise/ExerciseSceneValidator.swift`、平台 renderer。

具体做法：

- 新增 `ExerciseCompositionPreset.staffToPiano`。
- 新增 `ExerciseSurfaceNode.pianoAnswer`，roles 为 `[.answer]`。
- `ExerciseCompositionPolicy.resolvedSceneSurfaces()` 支持返回 `(.staffPrompt, .pianoAnswer)`。
- `stacked` 下沿用现在的 vertical split 规则：上方 `staff.fitContent`，下方 `piano.weighted`。
- `iOSExerciseSceneRenderer` / `macOSExerciseSceneRenderer` 里的 `pianoAccessoryView` 建议去语义化，改名为 `pianoSurfaceView` 或同等级命名；否则主场景里放 piano 时名字已经不成立。
- 关键去重点：当 `compositionPreset == .staffToPiano` 时，强制 `isPianoAccessoryVisible = false`，否则当前 `ExerciseCompositionPolicy.makePresentation()` 会把 `pianoPanelState.isVisible` 自动并进 accessory，直接制造重复 `.piano` surface 风险。
- `LegacyPageLayoutAdapter` 不要尝试把 `staffToPiano` 反投影成 `PageDisplayState`；SR-1 走 full `ExerciseScene`，`legacyPageDisplayState` 允许为 `nil`。

完成标准：

- 内部已经能构造出稳定的 `staff -> piano` stacked scene。
- scene validator 不出现 duplicate surface / visibility 错乱。
- 不依赖“钢琴 accessory 开关”来显示 SR-1 主答题键盘。

##阶段 5：引入 `SR-1` mode，并把 piano 输入接进答题管线
目标：把 UI 模式、布局组合、判题策略和平台输入彻底串起来。

改动面：`Shared/Controls/TrainerDisplayState.swift`、`Shared/Controls/SettingsPanelModel.swift`、`Shared/Exercise/LegacyPageLayoutAdapter.swift`、`Platform/iOS/iOSViewController.swift`、`Platform/macOS/macOSViewController.swift`。

具体做法：

- 新增 `TrainerExerciseMode.sr1`。
- `synchronizeTrainerPresentationState()` 新增 `sr1` 分支，但底层继续复用 `FretboardNaturalNoteTrainerState.quarterNoteSequence`。
- `SR-1` 的 normalization 固定为：
  - `compositionPreset = .staffToPiano`
  - `layoutPreset = .stacked`
  - `sequenceConfiguration.clef = .treble`
  - `sequenceConfiguration.answerPolicy = .pitchClass`
  - `pianoPanelState.rowCount = 1`
  - `pianoPanelState.movementScope = .rowOnly`
  - `isPianoAccessoryVisible = false`
- 不把 `answerPolicy` 暴露成 settings 行；它由 mode 决定。
- `pianoRowCount` 和 `pianoMovementScope` 在 SR-1 下建议隐藏或禁用：
  - 单行键盘是模式定义，不应该被用户改掉
  - `movementScope` 在单行场景里本身也没有业务意义
- staff 的 bass 选项在 SR-1 下也建议隐藏或禁用，避免用户改了又被 normalization 强制拉回 treble。
- 平台输入桥接：
  - `previewStarted` 发送 `ExerciseAnswerEvent.notePitch(preview.note, from: .piano)`
  - `previewChanged` 只有在 note 真变化时才发送，避免同一 preview 重复判题
  - `previewEnded` 清理 dedupe cache
- `handlePianoSemanticEvent()` 变成双路：
  - 一路继续喂 `playbackCoordinator`
  - 一路在 SR-1 且 `.piano` 为 answer surface 时，转成 exercise answer event
- `updateAnswerSurfaceInteractionState()` 补上 `.piano` 的 enable/disable 联动。

完成标准：

- 切到 `SR-1` 后，界面稳定变成“treble staff + 单行 piano”。
- 五线谱是 `C6` 时，按 `C3` / `C4` 都算正确。
- 钢琴播放反馈和答题反馈能共存，不互相吞事件。

##阶段 6：把 validation 补齐，并把 SR-2 seam 真的封装好
目标：确保 SR-2 以后不是“再来一次大改”。

改动面：`Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`、`Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`、`Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`、相关 shared validation。

要补的验证：

- 新 mode `sr1` 的 settings 可见性和选择状态。
- `SR-1` 下 composition/layout/treble/单行 piano 的 normalization。
- `staffToPiano` scene 的 surface state：
  - `.staff` 是 prompt-only
  - `.piano` 是 answer-only
- `legacyPageDisplayState == nil` 是允许且预期的。
- `.exactNote` comparator 虽然 UI 还没开，但 shared 测试必须先覆盖。
- accessory piano 与 main piano 不可同场共存。
- iOS / macOS 两端都要补一轮 smoke 验证：键盘输入、staff 红绿反馈、切模式后状态清理。

完成标准：

- SR-2 到来时，只需要新增 `TrainerExerciseMode.sr2`，并把 normalization 中的 `answerPolicy` 从 `.pitchClass` 切到 `.exactNote`。
- 不需要再改 router 结构、不需要再改 trainer comparator、不需要再改 `staffToPiano` scene。

##我建议的交付切片

- `PR-1`：阶段 0-3。只做 shared 语义、policy comparator、`staffToPiano` scene，不开 SR-1 UI。
- `PR-2`：阶段 5。接 `SR-1` mode、settings、iOS/macOS piano 输入桥。
- `PR-3`：阶段 6。补 validation，确认 SR-2 seam 已经闭环。

如果你愿意，我下一条可以直接把这个计划再压成“实施清单版”，按文件列出每一阶段具体要改哪些 symbol。
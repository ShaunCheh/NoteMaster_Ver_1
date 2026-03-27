# 20260327_112049_phase3_quarter_note_shared_validation

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260327_112049`
- 记录范围：随机四分音训练阶段 3，shared 验证补齐
- 本次目标：把 `quarterNoteSequence` 的共享层约束接入现有 `FretboardValidationRunner`，覆盖数量、谱号、四分音时值、`expectedPitchClasses` 对齐、自然音过滤、`includesAccidentals == true` 时禁止 `flat` 拼写，以及旧 `singleNaturalTarget` trainer 回归
- 根因结论：阶段 1 和阶段 2 已经打通了随机四分音输出与 `Shared/Staff` 边界，但自动化验证仍然只覆盖旧的单目标自然音 trainer。这样一来，`QuarterNoteSequencePrompt` 的关键约束虽然分散在 precondition 和生成器实现里，却没有统一纳入共享层 validation runner；后续只要改候选池、measure 拆分或 accidental 策略，就可能在不碰 UI 的情况下引入行为回归
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 本次完成的修改

1. 在 `FretboardValidationRunner.validate(_:)` 中接入 `validateQuarterNoteSequenceTrainer(...)`，把 quarter-note sequence 并入现有 shared 自动化验证主流程。
2. 新增 `validateQuarterNoteSequenceTrainer(...)`，分别覆盖 `natural-only` 和 `includesAccidentals=true` 两条生成路径，并校验 trainer 的 `mode`、`quarterNoteSequencePrompt`、`QuarterNoteSequenceSession` 是否按预期落地。
3. 新增 `validateQuarterNoteSequencePrompt(...)`，把 `prompt.score`、`prompt.expectedPitchClasses`、measure 拆分与 accidental 规则集中到一个共享 helper 中断言。
4. 保留原有 `validateNaturalNoteTrainer(...)` 不动，继续回归旧 `singleNaturalTarget` 训练链路。

## 修改 1：把 quarter-note sequence 验证接入现有 runner 主流程

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数: validate(_ fixture:)
// 功能说明: 修改前 runner 在 pitch resolution 之后只回归旧 natural-note trainer，
// 还没有把 quarter-note sequence 纳入 shared 自动化验证主流程。
static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
    // ... 上方仍是 scene / hitTest / pitch resolution 验证
    validatePitchResolution(
        fixture: fixture,
        record: record
    )
    validateNaturalNoteTrainer(
        fixture: fixture,
        record: record
    )

    return issues
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数: validate(_ fixture:)
// 功能说明: 修改后保留旧 natural-note trainer 回归，同时把 quarter-note sequence
// 验证挂到同一条 shared validation pipeline，避免新模式游离在自动化覆盖之外。
static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
    // ... 上方仍是 scene / hitTest / pitch resolution 验证
    validatePitchResolution(
        fixture: fixture,
        record: record
    )
    validateNaturalNoteTrainer(
        fixture: fixture,
        record: record
    )
    validateQuarterNoteSequenceTrainer(
        fixture: fixture,
        record: record
    )

    return issues
}
```

## 修改 2：新增 quarter-note trainer 的场景级 shared 验证入口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数: validateNaturalNoteTrainer(fixture:record:), manualChecklist(for:)
// 功能说明: 修改前自动化验证只覆盖旧 singleNaturalTarget trainer；
// natural-note trainer 断言结束后，文件直接进入手工回归清单，没有 quarter-note sequence 的共享层验证入口。
static func validateNaturalNoteTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    // ... 上方仍是现有单目标 natural-note trainer 的正确/错误/忽略路径断言
}

static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
    var checklist = [
        // ... 现有手工回归清单
    ]
    return checklist
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后新增 quarter-note sequence 的共享层验证入口，
// 分别覆盖 natural-only 与 includesAccidentals=true 两条生成路径，
// 并校验 trainer.mode、prompt 持久化、session 初始状态是否正确。
static func validateQuarterNoteSequenceTrainer(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    guard fixture.name == "horizontal-guitar6-reference" else {
        return
    }

    let naturalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
        clef: .treble,
        noteCount: 7,
        includesAccidentals: false
    )
    var naturalTrainer = FretboardNaturalNoteTrainerState(
        quarterNoteSequenceSpec: naturalSpec
    )
    let naturalPrompt = naturalTrainer.generateQuarterNoteSequencePrompt()
    validateQuarterNoteSequencePrompt(
        naturalPrompt,
        expectedSpec: naturalSpec,
        requiresNaturalOnly: true,
        requiresAccidentalEvidence: false,
        record: record
    )
    // ... 中间仍有 mode / quarterNoteSequencePrompt / session 一致性检查

    let accidentalSpec = FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec(
        clef: .bass,
        noteCount: 128,
        includesAccidentals: true
    )
    var accidentalTrainer = FretboardNaturalNoteTrainerState(targetPitchClass: .c)
    let accidentalPrompt = accidentalTrainer.generateQuarterNoteSequencePrompt(
        for: accidentalSpec
    )
    validateQuarterNoteSequencePrompt(
        accidentalPrompt,
        expectedSpec: accidentalSpec,
        requiresNaturalOnly: false,
        requiresAccidentalEvidence: true,
        record: record
    )
    // ... 中间仍有 mode / quarterNoteSequencePrompt 保存一致性检查
}
```

## 修改 3：新增 prompt 级结构断言，集中验证数量 / 谱号 / 时值 / accidental 规则

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数: manualChecklist(for:)
// 功能说明: 修改前没有 quarter-note prompt 的专用验证 helper，
// score.noteCount、measure 拆分、expectedPitchClasses 对齐、natural-only 与 no-flat 规则
// 都没有统一进入 shared validation runner。
static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
    var checklist = [
        "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
        "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。"
        // ... 下方仍是现有手工回归清单
    ]
    return checklist
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数: validateQuarterNoteSequencePrompt(_:expectedSpec:requiresNaturalOnly:requiresAccidentalEvidence:record:)
// 功能说明: 修改后把 quarter-note prompt 的核心共享约束集中到一个 helper，
// 统一验证数量、谱号、四分音时值、measure 拆分、pitchClass 对齐，以及 natural-only / sharp-only 规则。
static func validateQuarterNoteSequencePrompt(
    _ prompt: FretboardNaturalNoteTrainerState.QuarterNoteSequencePrompt,
    expectedSpec: FretboardNaturalNoteTrainerState.QuarterNoteSequenceSpec,
    requiresNaturalOnly: Bool,
    requiresAccidentalEvidence: Bool,
    record: (String) -> Void
) {
    if prompt.spec != expectedSpec {
        record("quarter-note trainer 生成的 prompt.spec 与期望 spec 不一致。")
    }

    if prompt.score.clef != expectedSpec.clef {
        record("quarter-note trainer 生成的 score clef 与 spec 不一致。")
    }

    if prompt.score.keySignature != .natural {
        record("quarter-note trainer 生成的 score key signature 应保持 natural。")
    }

    if prompt.notes.count != expectedSpec.noteCount {
        record("quarter-note trainer 生成的 note 数量错误，期望 \(expectedSpec.noteCount)，实际 \(prompt.notes.count)。")
    }

    if prompt.expectedPitchClasses.count != prompt.notes.count {
        record("quarter-note trainer 的 expectedPitchClasses 数量与 score.notes 不一致。")
    }

    if prompt.notes.contains(where: { $0.duration != .quarter }) {
        record("quarter-note trainer 生成了非四分音符时值。")
    }

    let expectedMeasureCount = (expectedSpec.noteCount + 3) / 4
    if prompt.score.measures.count != expectedMeasureCount {
        record(
            "quarter-note trainer 生成的 measure 数量错误，期望 \(expectedMeasureCount)，实际 \(prompt.score.measures.count)。"
        )
    }

    let scorePitchClasses = prompt.notes.map(\.notePitch.pitchClass)
    if scorePitchClasses != prompt.expectedPitchClasses {
        record("quarter-note trainer 的 expectedPitchClasses 与 score.notes 派生结果不一致。")
    }

    if requiresNaturalOnly {
        if prompt.expectedPitchClasses.contains(where: \.isAccidental) {
            record("quarter-note trainer 在 natural-only 模式下生成了非自然音 pitchClass。")
        }
        if prompt.notes.contains(where: { $0.pitch.accidental != .natural }) {
            record("quarter-note trainer 在 natural-only 模式下生成了带临时记号的 StaffPitch。")
        }
    } else {
        if prompt.notes.contains(where: { $0.pitch.accidental == .flat }) {
            record("quarter-note trainer 在 includesAccidentals=true 模式下生成了 flat 拼写。")
        }
        if requiresAccidentalEvidence && !prompt.notes.contains(where: { $0.pitch.accidental == .sharp }) {
            record("quarter-note trainer 在 includesAccidentals=true 模式下未生成任何升号音，无法证明候选池允许半音。")
        }
    }
}
```

## 验证结果

- `ReadLints`：`NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift` 无新增诊断
- `git status --short`：本阶段新增/修改只落在 `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- `xcodebuild`：本地环境仍然缺少可用的 Xcode developer directory，本次未执行完整编译验证

## 结果

- quarter-note sequence 已进入共享层自动化回归链路，不再只靠构造时 precondition 零散兜底
- 旧 `singleNaturalTarget` trainer 验证保持不变，阶段 3 没有改动其断言逻辑
- 本阶段仍未接 controller / staff UI；显示接线仍留在后续阶段

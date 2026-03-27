# 20260327_170426_phase4_staff_sequence_validation_regression

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_170426`
- 记录范围：实施 `staff序列反馈` 计划的阶段 4，为 shared scene 与 sequence 状态机补齐自动化回归验证
- 本次目标：
- 在 `StaffValidation` 中补 `TopContent = Staff`、`Exercise Mode = Sequence` 的 scene 级回归夹具
- 在 `FretboardValidation` 中补 `StaffSequencePresentation.fromProgress(...)` 与 sequence session/evaluation 的对齐断言
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 根因结论

- 阶段 1 到阶段 3 已经把 `sequencePresentation` 从 shared state、scene builder 一路接到了双端 controller，但现有自动化验证仍主要覆盖两类内容：
- `StaffValidation` 覆盖的是静态 staff scene 的 notehead / accidental / stem / ledger line 布局
- `FretboardValidation` 覆盖的是 quarter-note sequence trainer 的 session 推进与 prompt 同步
- 缺口在于：还没有人系统验证 `sequence cursor`、红绿反馈颜色、以及 `StaffSequencePresentation.fromProgress(...)` 与 trainer session/evaluation 的映射关系。
- 阶段 4 的根因级修复因此是双层补齐验证：
- 在 `StaffValidation` 加 sequence fixture 和 scene 断言
- 在 `FretboardValidation` 加 sequence 状态机到 `StaffSequencePresentation` 的对齐断言

## 修改 1：让 `StaffValidationFixture` 与 provider 验证入口接受 `sequencePresentation`

### 修改前

- `StaffValidationFixture` 只描述 `score / notationDisplayOptions / bounds`
- `fixture(...)` helper 也没有 `sequencePresentation`
- `validate(_ fixture:)` 在构建 `StaffSceneProvider` 时不会把 sequence 状态传进去

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 类型/函数: StaffValidationFixture, fixture(...), validate(_ fixture:)
// 功能说明: 修改前 StaffValidation 只能验证静态 staff scene；
// 无法为 sequence cursor 和红绿反馈构造专门的 fixture。
private struct StaffValidationFixture {
    var name: String
    var configuration: StaffConfiguration
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var bounds: CGRect
    var expectedLedgerLineCount: Int
    var expectedDisplayedNoteAccidentals: [StaffValidationExpectedNoteAccidental]
}

static func fixture(
    name: String,
    configuration: StaffConfiguration,
    score: StaffScore,
    notationDisplayOptions: StaffNotationDisplayOptions,
    extraVerticalSpaces: CGFloat = 0,
    expectedLedgerLineCount: Int = 0,
    expectedDisplayedNoteAccidentals: [StaffValidationExpectedNoteAccidental] = []
) -> StaffValidationFixture { ... }

static func validate(_ fixture: StaffValidationFixture) -> [StaffValidationIssue] {
    let scene = StaffSceneProvider(
        clef: fixture.configuration.clef,
        score: fixture.score,
        notationDisplayOptions: fixture.notationDisplayOptions
    ).makeScene(geometry: geometry)
    ...
}
```

### 修改后

- `StaffValidationFixture` 新增 `sequencePresentation`
- `fixture(...)` helper 新增同名参数
- `validate(_ fixture:)` 构建 `StaffSceneProvider` 时会把这份状态带进去

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 类型/函数: StaffValidationFixture, fixture(...), validate(_ fixture:)
// 功能说明: 修改后 StaffValidation 可以直接构造 sequence 场景，
// 并让 provider/builder 走和运行时一致的 shared 渲染路径。
private struct StaffValidationFixture {
    var name: String
    var configuration: StaffConfiguration
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var bounds: CGRect
    var expectedLedgerLineCount: Int
    var expectedDisplayedNoteAccidentals: [StaffValidationExpectedNoteAccidental]
    var sequencePresentation: StaffSequencePresentation?
}

static func fixture(
    name: String,
    configuration: StaffConfiguration,
    score: StaffScore,
    notationDisplayOptions: StaffNotationDisplayOptions,
    extraVerticalSpaces: CGFloat = 0,
    expectedLedgerLineCount: Int = 0,
    expectedDisplayedNoteAccidentals: [StaffValidationExpectedNoteAccidental] = [],
    sequencePresentation: StaffSequencePresentation? = nil
) -> StaffValidationFixture { ... }

static func validate(_ fixture: StaffValidationFixture) -> [StaffValidationIssue] {
    let scene = StaffSceneProvider(
        clef: fixture.configuration.clef,
        score: fixture.score,
        notationDisplayOptions: fixture.notationDisplayOptions,
        sequencePresentation: fixture.sequencePresentation
    ).makeScene(geometry: geometry)
    ...
}
```

## 修改 2：在 `StaffValidation` 中加入 sequence fixture，并补 scene 级断言

### 修改前

- `makeFixtures()` 只有静态记谱相关场景
- `validateSceneCounts(...)` 不会校验 `sequenceCursor` 数量
- `validate(_ fixture:)` 的校验链也没有 sequence 专用检查

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 类型/函数: makeFixtures(), validateSceneCounts(...), validate(_ fixture:)
// 功能说明: 修改前 StaffValidation 只覆盖静态五线谱布局，
// 还没有初始游标、错误反馈、正确反馈、完成态这类 sequence 回归场景。
var fixtures = [
    fixture(
        name: "treble-default-demo-full-notation",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.defaultDemo(clef: .treble),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [
            noteAccidental(noteIndex: 1, accidental: .sharp),
            noteAccidental(noteIndex: 3, accidental: .flat)
        ]
    ),
    fixture(
        name: "treble-named-key-demo-full-notation",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [...]
    )
]

static func validateSceneCounts(
    scene: StaffScene,
    geometry: StaffGeometry,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    let actualLedgerLineCount = scene.strokeItems.filter { $0.semantic == .ledgerLine }.count
    if actualLedgerLineCount != expectedLedgerLineCount {
        record("ledger line 数量错误，期望 \\(expectedLedgerLineCount)，实际 \\(actualLedgerLineCount)。")
    }
}
```

### 修改后

- `makeFixtures()` 新增 4 个 sequence fixture
- `validateSceneCounts(...)` 增加 `sequence cursor` 数量断言
- `validate(_ fixture:)` 追加 `validateSequencePresentation(...)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 类型/函数: makeFixtures(), validateSceneCounts(...), validate(_ fixture:)
// 功能说明: 修改后 StaffValidation 会自动覆盖 sequence 初始/错误/正确/完成态场景。
var fixtures = [
    fixture(
        name: "treble-sequence-initial-cursor-default-demo",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.defaultDemo(clef: .treble),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [
            noteAccidental(noteIndex: 1, accidental: .sharp),
            noteAccidental(noteIndex: 3, accidental: .flat)
        ],
        sequencePresentation: .idle(cursorIndex: 0)
    ),
    fixture(
        name: "treble-sequence-wrong-current-accidental-feedback",
        configuration: trebleConfiguration,
        score: StaffScoreFixtures.defaultDemo(clef: .treble),
        notationDisplayOptions: .fullNotation,
        expectedDisplayedNoteAccidentals: [
            noteAccidental(noteIndex: 1, accidental: .sharp),
            noteAccidental(noteIndex: 3, accidental: .flat)
        ],
        sequencePresentation: .wrong(
            cursorIndex: 1,
            evaluatedIndex: 1
        )
    ),
    fixture(
        name: "treble-sequence-correct-ledger-advance",
        configuration: trebleConfiguration,
        score: score(
            clef: .treble,
            measures: [[
                ("c4", .quarter),
                ("a5", .quarter),
                ("c6", .half)
            ]]
        ),
        notationDisplayOptions: .fullNotation,
        extraVerticalSpaces: 8,
        expectedLedgerLineCount: 4,
        sequencePresentation: .correct(
            cursorIndex: 2,
            evaluatedIndex: 1
        )
    ),
    fixture(
        name: "treble-sequence-completed-no-cursor",
        configuration: trebleConfiguration,
        score: score(
            clef: .treble,
            measures: [[
                ("c4", .quarter),
                ("a5", .quarter),
                ("c6", .half)
            ]]
        ),
        notationDisplayOptions: .fullNotation,
        extraVerticalSpaces: 8,
        expectedLedgerLineCount: 4,
        sequencePresentation: .completed(
            lastEvaluatedIndex: 2,
            lastEvaluationResult: .correct
        )
    )
]

let expectedCursorCount = fixture.sequencePresentation?.showsCursor == true ? 1 : 0
let actualCursorCount = scene.strokeItems.filter { $0.semantic == .sequenceCursor }.count
if actualCursorCount != expectedCursorCount {
    record("sequence cursor 数量错误，期望 \\(expectedCursorCount)，实际 \\(actualCursorCount)。")
}

validateSequencePresentation(
    scene: scene,
    geometry: geometry,
    fixture: fixture,
    record: record
)
```

## 修改 3：新增 `validateSequencePresentation(...)`，校验游标几何和颜色反馈

### 修改前

- `StaffValidation` 没有专门校验 sequence 展示语义
- 不会检查：
- cursor 是否对齐当前 note 的中心 X
- 完成态是否隐藏游标
- notehead / accidental / stem / ledger line 是否正确变红或变绿
- key signature accidental 是否仍保持默认墨色

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 类型/函数: validateStrokeSemantics(...), manualChecklist(for:)
// 功能说明: 修改前 validation 只验证了普通 stroke 语义，
// 还没有 sequence cursor 和反馈颜色的专门回归检查。
static func validateStrokeSemantics(
    scene: StaffScene,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    for (index, stroke) in scene.strokeItems.enumerated() {
        switch stroke.semantic {
        case .stem:
            ...
        case .ledgerLine:
            ...
        case .sequenceCursor:
            if !approximatelyEqual(stroke.start.x, stroke.end.x) {
                record("sequenceCursor[\\(index)] 不是竖线。")
            }
        }
    }
}
```

### 修改后

- 新增 `validateSequencePresentation(...)`
- 新增 `expectedSequenceTintColor(...)`
- 新增 `noteIndex(for:noteheadFrames:)`
- 手工回归清单也加了一条 sequence staff 场景

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 类型/函数: validateSequencePresentation(...), expectedSequenceTintColor(...), noteIndex(for:noteheadFrames:), manualChecklist(for:)
// 功能说明: 修改后 StaffValidation 能自动验证 sequence cursor 的位置、颜色，
// 以及 notehead / accidental / stem / ledger line 的反馈色是否和 sequencePresentation 对齐。
static func validateSequencePresentation(
    scene: StaffScene,
    geometry: StaffGeometry,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    guard let sequencePresentation = fixture.sequencePresentation else {
        return
    }

    let noteheadGlyphs = scene.glyphs.filter(\\.symbolID.isNotehead)
    let noteheadFrames = noteheadGlyphs.compactMap { frame(of: $0) }
    let cursorStrokes = scene.strokeItems.filter { $0.semantic == .sequenceCursor }

    if let cursorIndex = sequencePresentation.cursorIndex {
        if let cursorStroke = cursorStrokes.first {
            let expectedX = noteheadFrames[cursorIndex].midX
            if !approximatelyEqual(cursorStroke.start.x, expectedX)
                || !approximatelyEqual(cursorStroke.end.x, expectedX) {
                record("sequence cursor 未对齐到 notehead[\\(cursorIndex)] 的中心 X。")
            }

            if cursorStroke.style.strokeColor != .sequenceCursorBlue {
                record("sequence cursor 颜色错误。")
            }
        }
    } else if !cursorStrokes.isEmpty {
        record("完成态或无游标态不应生成 sequence cursor。")
    }

    for (noteIndex, noteheadGlyph) in noteheadGlyphs.enumerated() {
        let expectedTintColor = expectedSequenceTintColor(
            noteIndex: noteIndex,
            presentation: sequencePresentation
        )
        if noteheadGlyph.tintColor != expectedTintColor {
            record("notehead[\\(noteIndex)] 的 sequence tintColor 错误。")
        }
    }
}

static func expectedSequenceTintColor(
    noteIndex: Int,
    presentation: StaffSequencePresentation
) -> StaffSceneColor { ... }

static func noteIndex(
    for stroke: StaffStrokeItem,
    noteheadFrames: [CGRect]
) -> Int? { ... }

// 手工回归新增：TopContent=Staff + Exercise Mode=Sequence
// 需要确认初始游标、错误红色、正确绿色、完成态隐藏游标。
```

## 修改 4：在 `FretboardValidation` 中补 `StaffSequencePresentation.fromProgress(...)` 的状态机对齐断言

### 修改前

- `validateQuarterNoteSequenceTrainer(...)` 已经覆盖了：
- session 初始化
- 错误作答不推进
- 正确作答推进
- 完成态忽略后续输入
- 但还没有验证这些状态是否能正确映射成 `StaffSequencePresentation`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 类型/函数: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改前 quarter-note trainer 只验证 prompt/session/evaluation 本身，
// 还没有把这些状态和 staff sequence 展示语义关联起来。
if naturalSession.targetPromptContent() != naturalPrompt.generatedSequence.targetPromptContent(
    currentIndex: naturalSession.currentIndex
) {
    record("quarter-note trainer 新建 session 的 targetPromptContent 未对齐 shared sequence/currentIndex。")
}

switch naturalTrainer.handleQuarterNoteSequenceAnswer(
    incorrectPitchClass,
    session: &incorrectSession
) {
case let .evaluated(evaluation):
    if evaluation.didAdvanceIndex {
        record("quarter-note trainer 错误作答后不应推进 currentIndex。")
    }
default:
    record("quarter-note trainer 错误作答未返回 evaluated 结果。")
}
```

### 修改后

- 新建 session 时会验证 `fromProgress(...)` 是否映射为 `.idle`
- 错误作答后会验证是否映射为 `.wrong`
- 正确作答后会验证是否映射为 `.correct`
- 完成最后一题后会验证是否映射为 `.completed`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 类型/函数: validateQuarterNoteSequenceTrainer(fixture:record:)
// 功能说明: 修改后 FretboardValidation 会验证 trainer 状态机与 StaffSequencePresentation 的共享映射是否一致。
if let initialStaffPresentation = StaffSequencePresentation.fromProgress(
    totalCount: naturalSession.totalCount,
    currentIndex: naturalSession.currentIndex
) {
    if initialStaffPresentation != .idle(cursorIndex: naturalSession.currentIndex) {
        record("quarter-note trainer 新建 session 的 staff sequence presentation 未映射为 idle(cursorIndex: currentIndex)。")
    }
}

switch naturalTrainer.handleQuarterNoteSequenceAnswer(
    incorrectPitchClass,
    session: &incorrectSession
) {
case let .evaluated(evaluation):
    if let incorrectStaffPresentation = StaffSequencePresentation.fromProgress(
        totalCount: incorrectSession.totalCount,
        currentIndex: incorrectSession.currentIndex,
        lastEvaluatedIndex: evaluation.answeredIndex,
        lastEvaluationResult: .incorrect
    ) {
        if incorrectStaffPresentation != .wrong(
            cursorIndex: incorrectSession.currentIndex,
            evaluatedIndex: evaluation.answeredIndex
        ) {
            record("quarter-note trainer 错误作答后的 staff sequence presentation 未与 session/evaluation 对齐。")
        }
    }
default:
    record("quarter-note trainer 错误作答未返回 evaluated 结果。")
}

if let correctStaffPresentation = StaffSequencePresentation.fromProgress(
    totalCount: completedSession.totalCount,
    currentIndex: evaluation.nextIndex,
    lastEvaluatedIndex: evaluation.answeredIndex,
    lastEvaluationResult: .correct
) {
    let expectedStaffPresentation: StaffSequencePresentation
    if shouldComplete {
        expectedStaffPresentation = .completed(
            lastEvaluatedIndex: evaluation.answeredIndex,
            lastEvaluationResult: .correct
        )
    } else {
        expectedStaffPresentation = .correct(
            cursorIndex: evaluation.nextIndex,
            evaluatedIndex: evaluation.answeredIndex
        )
    }

    if correctStaffPresentation != expectedStaffPresentation {
        record("quarter-note trainer 正确作答后的 staff sequence presentation 未与 session/evaluation 对齐。")
    }
}
```

## 本阶段结果

- `StaffValidation` 现在已经能自动验证 sequence cursor 与红绿反馈
- `FretboardValidation` 现在已经能自动验证 trainer 状态机与 `StaffSequencePresentation.fromProgress(...)` 的映射关系
- 这样阶段 1 到阶段 3 的结果不再只是“代码接通”，而是有了共享层回归保护

## 验证情况

- 已对下列文件执行静态诊断检查，结果无 linter 错误：
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 未执行 `xcodebuild` 全量编译；当前记录仅覆盖本次阶段 4 的验证扩展与静态检查结果

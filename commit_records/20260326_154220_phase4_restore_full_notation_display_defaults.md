# 20260326_154220_phase4_restore_full_notation_display_defaults

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_154220`
- 记录范围：`调号支持` 的阶段 4 实施
- 本次目标：把当前分支从 `noteheadsOnly` 排障态恢复为默认完整记谱模式，并让调号 accidental 与音符 accidental 共用同一套显示开关
- 根因结论：阶段 3 已经把 `keySignature + measures + accidental context` 接进 scene 生成主链路，但默认平台接线仍然硬编码在 `noteheadsOnly`，导致共享层虽然有能力输出完整记谱 scene，平台默认状态却还停在排障模式；同时 `showsAccidentals` 这个单一布尔值在调用点上缺少“调号 accidental / note accidental”语义边界，后续很容易继续被误用
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffScene.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift`
- 修改 `NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. `StaffNotationDisplayOptions` 新增 `showsKeySignatureAccidentals` 与 `showsNoteAccidentals`，把同一套 accidental 显示开关收口成更明确的语义访问点。
2. `StaffDisplayState` 新增 `notationDisplayOptions` 状态字段，默认值恢复为 `.fullNotation`，不再把 `.noteheadsOnly` 写死在 `sceneProvider` 组装点。
3. `StaffSceneProvider` 与 `StaffSceneBuilder` 的默认 `notationDisplayOptions` 都恢复为 `.fullNotation`。
4. `StaffSceneBuilder` 在调号 cluster 与音符 accidental 两处改为分别读取 `showsKeySignatureAccidentals` / `showsNoteAccidentals`，但底层仍共用同一套 accidental 开关真相。
5. iOS / macOS 平台默认关闭 `showsNoteheadDiagnostics`，避免调号支持接入后继续长期刷 notehead 排障日志。

## 修改 1：`StaffNotationDisplayOptions` 从调试期二元开关升级为语义化访问点

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数/成员: StaffNotationDisplayOptions.noteheadsOnly / fullNotation / debugSummary
// 功能说明: 修改前只有 showsAccidentals 这一层布尔开关；
// 调号 accidental 和音符 accidental 是否显示，只能由调用方自行揣测这一位布尔值具体覆盖哪些区域。
struct StaffNotationDisplayOptions: Equatable, Sendable {
    var showsAccidentals: Bool
    var showsStems: Bool
    var showsLedgerLines: Bool

    static let noteheadsOnly = StaffNotationDisplayOptions(
        showsAccidentals: false,
        showsStems: false,
        showsLedgerLines: false
    )

    static let fullNotation = StaffNotationDisplayOptions(
        showsAccidentals: true,
        showsStems: true,
        showsLedgerLines: true
    )

    var debugSummary: String {
        "accidentals=\(showsAccidentals) stems=\(showsStems) ledgerLines=\(showsLedgerLines)"
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScene.swift
// 函数/成员: StaffNotationDisplayOptions.showsKeySignatureAccidentals / showsNoteAccidentals / debugSummary
// 功能说明: 修改后 accidental 仍共用同一套底层真相源，但对外暴露成“调号 accidental / 音符 accidental”的语义访问点，
// 避免 builder、provider 或后续验证器继续直接把 showsAccidentals 当作模糊概念使用。
struct StaffNotationDisplayOptions: Equatable, Sendable {
    var showsAccidentals: Bool
    var showsStems: Bool
    var showsLedgerLines: Bool

    static let noteheadsOnly = StaffNotationDisplayOptions(
        showsAccidentals: false,
        showsStems: false,
        showsLedgerLines: false
    )

    static let fullNotation = StaffNotationDisplayOptions(
        showsAccidentals: true,
        showsStems: true,
        showsLedgerLines: true
    )

    // 调号 accidental 与 note accidental 在阶段 4 继续共用同一套显示策略；
    // 这里拆成语义化访问点，避免调用方继续直接猜“showsAccidentals”具体覆盖哪些区域。
    var showsKeySignatureAccidentals: Bool {
        showsAccidentals
    }

    var showsNoteAccidentals: Bool {
        showsAccidentals
    }

    var debugSummary: String {
        "keySignatureAccidentals=\(showsKeySignatureAccidentals) noteAccidentals=\(showsNoteAccidentals) stems=\(showsStems) ledgerLines=\(showsLedgerLines)"
    }
}
```

## 修改 2：`StaffDisplayState` 不再把 `.noteheadsOnly` 写死，默认恢复为完整记谱模式

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState.init(configuration:score:showsComponentBoundsOverlay:) / sceneProvider
// 功能说明: 修改前 StaffDisplayState 没有 notationDisplayOptions 状态字段；
// sceneProvider 创建时会直接硬编码 .noteheadsOnly，导致平台默认一直停在排障显示模式。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration
    var score: StaffScore?
    var showsComponentBoundsOverlay: Bool

    init(
        configuration: StaffConfiguration,
        score: StaffScore? = nil,
        showsComponentBoundsOverlay: Bool = false
    ) {
        self.configuration = configuration
        self.score = score
        self.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    }

    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            score: resolvedScore,
            notationDisplayOptions: .noteheadsOnly,
            renderHint: .staffClef(
                // ...
            )
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState.notationDisplayOptions / init(configuration:score:notationDisplayOptions:showsComponentBoundsOverlay:) / sceneProvider
// 功能说明: 修改后显示策略进入 StaffDisplayState 真相源；
// 默认值恢复为 .fullNotation，同时仍保留显式传入 .noteheadsOnly 的能力，便于后续调试或验证场景复用。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration
    var score: StaffScore?
    var notationDisplayOptions: StaffNotationDisplayOptions
    var showsComponentBoundsOverlay: Bool

    init(
        configuration: StaffConfiguration,
        score: StaffScore? = nil,
        notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
        showsComponentBoundsOverlay: Bool = false
    ) {
        self.configuration = configuration
        self.score = score
        self.notationDisplayOptions = notationDisplayOptions
        self.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    }

    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            score: resolvedScore,
            notationDisplayOptions: notationDisplayOptions,
            renderHint: .staffClef(
                // ...
            )
        )
    }
}
```

## 修改 3：`StaffSceneProvider` / `StaffSceneBuilder` 默认恢复为 `.fullNotation`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: StaffSceneProvider.init(clef:score:notationDisplayOptions:glyphTintColor:renderHint:)
// 功能说明: 修改前 provider 默认仍然回落到 .noteheadsOnly；
// 即使共享层已经具备完整记谱能力，默认调用方如果不显式覆写，仍会得到排障态 scene。
init(
    clef: StaffClef = .treble,
    score: StaffScore? = nil,
    notationDisplayOptions: StaffNotationDisplayOptions = .noteheadsOnly,
    glyphTintColor: StaffSceneColor = .primaryInk,
    renderHint: StaffGlyphRenderHint = .staffClef()
) {
    self.clef = clef
    self.score = score
    self.notationDisplayOptions = notationDisplayOptions
    self.glyphTintColor = glyphTintColor
    self.renderHint = renderHint
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.init(clef:score:notationDisplayOptions:glyphTintColor:clefRenderHint:layoutMetrics:)
// 功能说明: 修改前 builder 默认也停留在 .noteheadsOnly，
// 这会让默认场景生成链路继续偏向排障模式，而不是完整记谱模式。
init(
    clef: StaffClef,
    score: StaffScore,
    notationDisplayOptions: StaffNotationDisplayOptions = .noteheadsOnly,
    glyphTintColor: StaffSceneColor = .primaryInk,
    clefRenderHint: StaffGlyphRenderHint = .staffClef(),
    layoutMetrics: LayoutMetrics = .default
) {
    self.clef = clef
    self.score = score
    self.notationDisplayOptions = notationDisplayOptions
    self.glyphTintColor = glyphTintColor
    self.clefRenderHint = clefRenderHint
    self.layoutMetrics = layoutMetrics
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneProvider.swift
// 函数/成员: StaffSceneProvider.init(clef:score:notationDisplayOptions:glyphTintColor:renderHint:)
// 功能说明: 修改后 provider 默认显示策略恢复为 .fullNotation；
// 平台只要使用默认 StaffDisplayState，就会消费到完整记谱 scene，而不是排障态 scene。
init(
    clef: StaffClef = .treble,
    score: StaffScore? = nil,
    notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
    glyphTintColor: StaffSceneColor = .primaryInk,
    renderHint: StaffGlyphRenderHint = .staffClef()
) {
    self.clef = clef
    self.score = score
    self.notationDisplayOptions = notationDisplayOptions
    self.glyphTintColor = glyphTintColor
    self.renderHint = renderHint
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: StaffSceneBuilder.init(clef:score:notationDisplayOptions:glyphTintColor:clefRenderHint:layoutMetrics:)
// 功能说明: 修改后 builder 默认值同步改为 .fullNotation，
// 让 provider、display state、builder 三层的默认显示策略保持一致。
init(
    clef: StaffClef,
    score: StaffScore,
    notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
    glyphTintColor: StaffSceneColor = .primaryInk,
    clefRenderHint: StaffGlyphRenderHint = .staffClef(),
    layoutMetrics: LayoutMetrics = .default
) {
    self.clef = clef
    self.score = score
    self.notationDisplayOptions = notationDisplayOptions
    self.glyphTintColor = glyphTintColor
    self.clefRenderHint = clefRenderHint
    self.layoutMetrics = layoutMetrics
}
```

## 修改 4：`StaffSceneBuilder` 明确区分调号 accidental 与音符 accidental 的语义访问点

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: makeScene(geometry:) / resolvedKeySignatureGlyphLayouts(geometry:noteheadSize:) / resolvedLeadingAccessoryWidth(displayedAccidental:noteheadSize:)
// 功能说明: 修改前 builder 在调号 cluster 和音符 accidental 两处都直接读取 showsAccidentals；
// 虽然行为上是共用一套开关，但代码语义层没有明确表达“这是调号 accidental 还是 note accidental”。
for noteLayout in noteLayouts {
    if notationDisplayOptions.showsAccidentals,
       let displayedAccidental = noteLayout.displayedAccidental,
       let accidentalSymbolID = accidentalSymbolID(
            for: displayedAccidental
       ) {
        // ...
    }
}

private func resolvedKeySignatureGlyphLayouts(
    geometry: StaffGeometry,
    noteheadSize: CGSize
) -> [KeySignatureGlyphLayout] {
    guard notationDisplayOptions.showsAccidentals else {
        return []
    }
    // ...
}

private func resolvedLeadingAccessoryWidth(
    displayedAccidental: StaffAccidental?,
    noteheadSize: CGSize
) -> CGFloat {
    guard
        notationDisplayOptions.showsAccidentals,
        displayedAccidental != nil
    else {
        return 0
    }
    // ...
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffSceneBuilder.swift
// 函数/成员: makeScene(geometry:) / resolvedKeySignatureGlyphLayouts(geometry:noteheadSize:) / resolvedLeadingAccessoryWidth(displayedAccidental:noteheadSize:)
// 功能说明: 修改后 builder 在调号 cluster 与音符 accidental 两处分别读取 showsKeySignatureAccidentals / showsNoteAccidentals；
// 这样既保留了同一套 accidental 开关真相源，也把两类 accidental 的语义边界直接写进调用点。
for noteLayout in noteLayouts {
    if notationDisplayOptions.showsNoteAccidentals,
       let displayedAccidental = noteLayout.displayedAccidental,
       let accidentalSymbolID = accidentalSymbolID(
            for: displayedAccidental
       ) {
        // ...
    }
}

private func resolvedKeySignatureGlyphLayouts(
    geometry: StaffGeometry,
    noteheadSize: CGSize
) -> [KeySignatureGlyphLayout] {
    guard notationDisplayOptions.showsKeySignatureAccidentals else {
        return []
    }
    // ...
}

private func resolvedLeadingAccessoryWidth(
    displayedAccidental: StaffAccidental?,
    noteheadSize: CGSize
) -> CGFloat {
    guard
        notationDisplayOptions.showsNoteAccidentals,
        displayedAccidental != nil
    else {
        return 0
    }
    // ...
}
```

## 修改 5：平台默认关闭 notehead 诊断日志，避免长期刷屏

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSViewController.staffDisplayState
// 功能说明: 修改前 iOS 默认把 showsNoteheadDiagnostics 打开；
// 这是 notehead 排障期的临时策略，不适合在调号支持接入后长期保留。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true,
            showsNoteheadDiagnostics: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: macOSViewController.staffDisplayState
// 功能说明: 修改前 macOS 默认也开启了 showsNoteheadDiagnostics；
// 这会让阶段 4 之后默认运行态继续刷 notehead 调试日志。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true,
            showsNoteheadDiagnostics: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
)
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: iOSViewController.staffDisplayState
// 功能说明: 修改后 iOS 仍保留 clef overlay 调试，但 notehead 诊断回落到默认关闭；
// 这样默认场景不会继续刷排障日志，同时仍保留按需打开调试开关的能力。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: macOSViewController.staffDisplayState
// 功能说明: 修改后 macOS 与 iOS 保持同一默认调试策略；
// 默认不再输出 notehead 诊断日志，但保留 clef overlay 调试能力。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
)
```

## 验证结果

1. `ReadLints`

```text
# 文件路径: IDE 诊断（无源码文件）
# 函数/成员: ReadLints
# 功能说明: 本轮修改的 6 个文件无新增 IDE 诊断。
No linter errors found.
```

2. 共享层与控制层静态类型校验

```bash
# 文件路径: 命令行验证（无源码文件）
# 函数/成员: xcrun swiftc -typecheck
# 功能说明: 对 Shared/Fretboard/*.swift、Shared/Staff/*.swift、Shared/Controls/*.swift 做阶段 4 静态类型校验。
xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift NoteMaster_Ver_1/Shared/Controls/*.swift
```

```text
# 文件路径: 命令行验证结果（无源码文件）
# 函数/成员: xcrun swiftc -typecheck 输出
# 功能说明: 命令执行成功，未产生编译错误输出。
Exit code: 0
```

3. 阶段 4 语义校验

```bash
# 文件路径: 临时校验脚本（无源码文件）
# 函数/成员: staff_phase4_check
# 功能说明: 验证 StaffDisplayState 默认显示策略已恢复为 fullNotation，
# 同时 noteheadsOnly 仍然可显式指定并正确抑制 accidental / stem / ledger line。
./staff_phase4_check
```

```text
# 文件路径: 临时校验脚本输出（无源码文件）
# 函数/成员: staff_phase4_check 输出
# 功能说明:
# - defaultNotation: 默认 StaffDisplayState 已恢复为完整记谱模式；
# - defaultGlyphs: 默认 scene 同时包含 key signature accidental、note accidental 和 notehead；
# - noteheadsOnlyGlyphs: 显式指定 noteheadsOnly 时，scene 仍只保留 clef 与 notehead。
defaultNotation=keySignatureAccidentals=true noteAccidentals=true stems=true ledgerLines=true
defaultGlyphs=trebleClef,accidentalSharp,accidentalSharp,accidentalNatural,noteheadBlack
noteheadsOnlyGlyphs=trebleClef,noteheadBlack
```

## 当前阶段结论

- 阶段 4 已把默认显示策略从排障期的 `noteheadsOnly` 恢复为可工作的 `fullNotation`。
- 调号 accidental 与音符 accidental 现在在共享层明确走同一套开关语义，但调用点已经具备清晰的语义边界，便于后续阶段继续扩验证器。
- 平台默认接线不需要知道 accidental context 或 key signature layout 的实现细节，只继续消费共享 `StaffDisplayState.sceneProvider`。

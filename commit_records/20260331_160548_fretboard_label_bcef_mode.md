# 20260331_160548_fretboard_label_bcef_mode

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_160548`
- 记录范围：为 fretboard 的 `Labels` 增加 `BCEF` 模式，只显示 `B / C / E / F`
- 修改性质：从共享可见性模型的根因入手，把 label 可见性从“自然音/变化音二值开关”提升为“按 pitch class 精确过滤”，并同步补齐设置面板、旧按钮面板兼容层与自动化校验
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 修改前

- `NoteLabelVisibility` 只有 `showsNaturalNotes` / `showsAccidentals` 两个布尔位，只能表达 `All / Natural / Accidental / None`，无法表达 `BCEF` 这类自然音子集。
- Settings 的 `Labels` 行没有 `BCEF` 选项，`SettingsActionID` 也没有对应动作，自然无法保存、回显和应用这种模式。
- 旧的 `ButtonPanelActionID` 映射链路同样没有 `BCEF`，即使后续只修新设置面板，也会留下新旧入口不一致的问题。
- Fretboard validation 没有自动验证 label 可见性模式，`BCEF` 若以后被改坏，只能靠手工回归发现。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift
// 函数名: NoteLabelVisibility / allows(_:)
// 功能说明: 修改前可见性模型只区分“自然音是否显示”“变化音是否显示”，
// 不能表达只显示 B/C/E/F 这类 pitch class 子集。
struct NoteLabelVisibility: Equatable, Hashable, Sendable {
    var showsNaturalNotes: Bool
    var showsAccidentals: Bool

    static let all = NoteLabelVisibility(
        showsNaturalNotes: true,
        showsAccidentals: true
    )

    static let naturalOnly = NoteLabelVisibility(
        showsNaturalNotes: true,
        showsAccidentals: false
    )

    static let accidentalOnly = NoteLabelVisibility(
        showsNaturalNotes: false,
        showsAccidentals: true
    )

    static let none = NoteLabelVisibility(
        showsNaturalNotes: false,
        showsAccidentals: false
    )

    func allows(_ pitchClass: PitchClass) -> Bool {
        pitchClass.isAccidental ? showsAccidentals : showsNaturalNotes
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsChoiceRowID.actionIDs / SettingsActionID
// 功能说明: 修改前 Settings 的 Labels 行只暴露 4 个模式，
// action 枚举里也没有 BCEF 的状态入口。
case .labels:
    return [
        .setVisibilityAll,
        .setVisibilityNaturalOnly,
        .setVisibilityAccidentalOnly,
        .setVisibilityNone
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名: ButtonPanelActionID / settingsActionID
// 功能说明: 修改前旧 button panel 兼容层也没有 BCEF，
// 如果只改新设置面板，会出现两个入口对同一状态定义不一致的问题。
enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
}

private extension ButtonPanelActionID {
    var settingsActionID: SettingsActionID {
        switch self {
        case .setVisibilityAll:
            return .setVisibilityAll
        case .setVisibilityNaturalOnly:
            return .setVisibilityNaturalOnly
        case .setVisibilityAccidentalOnly:
            return .setVisibilityAccidentalOnly
        case .setVisibilityNone:
            return .setVisibilityNone
        // ... 其他 case 保持不变
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validate(_:) / manualChecklist(for:)
// 功能说明: 修改前 validation 还没有 label visibility 自动化校验；
// 手工清单里也没有 BCEF 模式的回归项。
runStep("validatePitchClassCellEnumeration") {
    validatePitchClassCellEnumeration(
        fixture: fixture,
        record: record
    )
}
runStep("validateNaturalNoteTrainer") {
    validateNaturalNoteTrainer(
        fixture: fixture,
        record: record
    )
}

static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
    var checklist = [
        "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
        "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。"
    ]
    // ...
}
```

## 修改后

- `NoteLabelVisibility` 现在用 `visiblePitchClasses: Set<PitchClass>` 表达可见范围，并新增 `.bcefOnly`，渲染层从模型上就具备了只显示 `B / C / E / F` 的能力。
- `SettingsPanelModel` 补齐 `setVisibilityBCEFOnly`，把 `BCEF` 接进 `Labels` 行，并完成标题、无障碍文案、选中态判断和状态写回。
- `ButtonPanelModel` 同步补齐 `BCEF`，避免新旧入口对同一显示状态出现分叉。
- `FretboardValidation` 新增 `validateLabelVisibilityModes`，自动验证 `all / naturalOnly / bcefOnly / accidentalOnly / none` 五种模式，并把 `BCEF` 加入手工清单。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift
// 函数名: NoteLabelVisibility / allows(_:)
// 功能说明: 修改后改为按 pitch class 精确控制 label 可见性，
// 新增 bcefOnly，让 BCEF 成为共享层的一等模式。
struct NoteLabelVisibility: Equatable, Hashable, Sendable {
    private static let allPitchClasses = Set(PitchClass.allCases)
    private static let naturalPitchClasses = Set(PitchClass.naturalCasesInOrder)
    private static let accidentalPitchClasses = Set(
        PitchClass.allCases.filter(\.isAccidental)
    )

    var visiblePitchClasses: Set<PitchClass>

    static let all = NoteLabelVisibility(
        visiblePitchClasses: allPitchClasses
    )

    static let naturalOnly = NoteLabelVisibility(
        visiblePitchClasses: naturalPitchClasses
    )

    static let bcefOnly = NoteLabelVisibility(
        visiblePitchClasses: [
            .b,
            .c,
            .e,
            .f
        ]
    )

    static let accidentalOnly = NoteLabelVisibility(
        visiblePitchClasses: accidentalPitchClasses
    )

    static let none = NoteLabelVisibility(
        visiblePitchClasses: []
    )

    func allows(_ pitchClass: PitchClass) -> Bool {
        visiblePitchClasses.contains(pitchClass)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsChoiceRowID.actionIDs / SettingsActionID.title / isSelected(in:) / apply(to:)
// 功能说明: 修改后 Settings 的 Labels 行正式纳入 BCEF，
// 并把显示文案、选中判断和共享状态写回链一次补齐。
case .labels:
    return [
        .setVisibilityAll,
        .setVisibilityNaturalOnly,
        .setVisibilityBCEFOnly,
        .setVisibilityAccidentalOnly,
        .setVisibilityNone
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityBCEFOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
}

case .setVisibilityBCEFOnly:
    return "BCEF"

case .setVisibilityBCEFOnly:
    return "Show B, C, E, and F note labels only"

case .setVisibilityBCEFOnly:
    return stateContext.fretboardDisplayState.visibility == .bcefOnly

case .setVisibilityBCEFOnly:
    displayState.visibility = .bcefOnly
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名: ButtonPanelActionID / sectionID / settingsActionID
// 功能说明: 修改后旧 button panel 兼容层与 SettingsActionID 保持同一套 BCEF 定义，
// 避免历史入口与新面板出现行为分叉。
enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityBCEFOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
}

case .setVisibilityAll,
     .setVisibilityNaturalOnly,
     .setVisibilityBCEFOnly,
     .setVisibilityAccidentalOnly,
     .setVisibilityNone:
    return .labels

case .setVisibilityBCEFOnly:
    return .setVisibilityBCEFOnly
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validate(_:) / validateLabelVisibilityModes(...) / manualChecklist(for:)
// 功能说明: 修改后新增 label visibility 自动化校验，
// 显式验证 bcefOnly 只会保留 B/C/E/F 对应的格子和标签。
runStep("validatePitchClassCellEnumeration") {
    validatePitchClassCellEnumeration(
        fixture: fixture,
        record: record
    )
}
runStep("validateLabelVisibilityModes") {
    validateLabelVisibilityModes(
        fixture: fixture,
        scene: scene,
        record: record
    )
}

static func validateLabelVisibilityModes(
    fixture: FretboardValidationFixture,
    scene: FretboardScene,
    record: (String) -> Void
) {
    let visibilityFixtures: [(String, NoteLabelVisibility, Set<PitchClass>)] = [
        ("all", .all, Set(PitchClass.allCases)),
        ("naturalOnly", .naturalOnly, Set(PitchClass.naturalCasesInOrder)),
        ("bcefOnly", .bcefOnly, Set([.b, .c, .e, .f])),
        ("accidentalOnly", .accidentalOnly, Set(PitchClass.allCases.filter(\.isAccidental))),
        ("none", .none, Set<PitchClass>())
    ]

    // ... 逐模式构造 labels，断言 cell 集合与期望 pitch class 集合完全一致
}

static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
    var checklist = [
        "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
        "在设置面板的 `Labels` 中切到 `BCEF`，确认指板只显示 `B / C / E / F`；再切回 `All / Natural / Accidental / None`，确认不会残留错误标签。"
    ]
    // ...
}
```

## 验证

- `ReadLints` 检查以下文件，无新增 linter 错误：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 已执行 iOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build`
- 已执行 macOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx CODE_SIGNING_ALLOWED=NO build`

## 结果

- 新增记录文件：`commit_records/20260331_160548_fretboard_label_bcef_mode.md`
- 当前这次改动未提交 git，仅完成代码修改与记录落盘

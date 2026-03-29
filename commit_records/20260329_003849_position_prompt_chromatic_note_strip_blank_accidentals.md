# 20260329_003849_position_prompt_chromatic_note_strip_blank_accidentals

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_003849`
- 记录范围：将位置音名模式底部按钮面板从 7 个自然音按钮扩展为 12 个半音位按钮；自然音继续显示文字，升降号按钮先用空白按钮占位
- 本次目标：满足“在 C 和 D 中间插入一个 `C Sharp / D flat` 按钮位，按钮上先不显示文字”的需求，并将同样的处理推广为完整的 12 半音按钮条
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- 本次未修改文件：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`

## 需求结论

- 原有底部按钮条只按 `PitchClass.naturalCasesInOrder` 生成 7 个自然音按钮：`C D E F G A B`
- 新需求要求在自然音之间加入半音按钮位，例如 `C` 与 `D` 之间插入 `C Sharp / D flat`
- 为了避免后续再逐个补位，本次直接把按钮条扩展为完整 12 半音顺序：
- `C, C#, D, D#, E, F, F#, G, G#, A, A#, B`
- 其中自然音按钮继续显示文字；升降号按钮当前保持可点击，但按钮标题先显示为空字符串
- 控制器与共享 trainer 不需要改动，因为按钮点击仍然回传正确的 `PitchClass`

## 修改 1：按钮来源从 7 个自然音扩展为 12 个半音位

### 修改前

- iOS 与 macOS 两端的按钮条都只按 `PitchClass.naturalCasesInOrder` 创建按钮
- 结果是底部面板结构固定为 7 格，没有半音按钮位

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: iOSNaturalNoteStripView.buttons
// 功能说明: 修改前 iOS 底部按钮条只生成 7 个自然音按钮；
// 位置音名模式无法在 C 和 D 之间插入半音位按钮。
private let stackView = UIStackView()
private lazy var buttons: [NaturalNoteButton] = {
    PitchClass.naturalCasesInOrder.map { pitchClass in
        makeButton(for: pitchClass)
    }
}()
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: macOSNaturalNoteStripView.buttons
// 功能说明: 修改前 macOS 与 iOS 同样只创建 7 个自然音按钮；
// 半音按钮既没有视觉槽位，也没有点击入口。
private let stackView = NSStackView()
private lazy var buttons: [NaturalNoteButton] = {
    PitchClass.naturalCasesInOrder.map { pitchClass in
        makeButton(for: pitchClass)
    }
}()
```

### 修改后

- 两端统一改为按 `PitchClass.allCases` 生成按钮
- 底部面板现在是完整 12 格半音顺序，而不是 7 个自然音

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: iOSNaturalNoteStripView.buttons
// 功能说明: 修改后 iOS 按钮条按完整 12 半音顺序生成按钮；
// 底部面板已经具备自然音和升降号按钮位。
private let stackView = UIStackView()
private lazy var buttons: [NaturalNoteButton] = {
    PitchClass.allCases.map { pitchClass in
        makeButton(for: pitchClass)
    }
}()
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: macOSNaturalNoteStripView.buttons
// 功能说明: 修改后 macOS 按钮条也改成 12 半音全量生成；
// 两个平台的按钮顺序和可点击语义保持一致。
private let stackView = NSStackView()
private lazy var buttons: [NaturalNoteButton] = {
    PitchClass.allCases.map { pitchClass in
        makeButton(for: pitchClass)
    }
}()
```

## 修改 2：自然音继续显示文字，升降号按钮先显示为空白

### 修改前

- `apply(pitchClass:)` 直接使用 `pitchClass.displayText()` 作为按钮标题
- 因此如果直接切到 12 半音，升降号按钮会立刻显示 `C# / D# / F# / G# / A#`
- 这不符合“先用空白按钮占位”的需求

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: NaturalNoteButton.apply(pitchClass:)
// 功能说明: 修改前 iOS 每个按钮都直接显示 pitchClass 文本；
// 如果扩到 12 键，升降号按钮会直接显示尖号文字，而不是空白占位。
func apply(pitchClass: PitchClass) {
    self.pitchClass = pitchClass
    let title = pitchClass.displayText()
    accessibilityIdentifier = "natural-note-strip-button-\(title.lowercased())"
    accessibilityLabel = "Choose natural note \(title)"
    setTitle(title, for: .normal)
    setNeedsUpdateConfiguration()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: NaturalNoteButton.apply(pitchClass:)
// 功能说明: 修改前 macOS 也把 pitchClass 文本直接作为按钮标题；
// 扩到半音后会直接显示升降号文本，而不是留空。
func apply(pitchClass: PitchClass) {
    self.pitchClass = pitchClass
    let title = pitchClass.displayText()
    self.title = title
    toolTip = "Choose natural note \(title)"
    identifier = NSUserInterfaceItemIdentifier(
        "natural-note-strip-button-\(title.lowercased())"
    )
    applyCurrentAppearance()
    invalidateIntrinsicContentSize()
}
```

### 修改后

- 抽出 `PitchClass.stripVisibleTitle`
- 自然音返回 `C / D / E / F / G / A / B`
- 升降号按钮返回空字符串 `""`
- 因此按钮仍然存在、仍可点击，但视觉上先作为空白半音位使用

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: NaturalNoteButton.apply(pitchClass:), PitchClass.stripVisibleTitle
// 功能说明: 修改后 iOS 的自然音按钮继续显示字母；
// 升降号按钮虽然仍然绑定正确的 PitchClass，但标题先显示为空白。
func apply(pitchClass: PitchClass) {
    self.pitchClass = pitchClass
    accessibilityIdentifier = "natural-note-strip-button-\(pitchClass.stripIdentifierToken)"
    accessibilityLabel = "Choose note \(pitchClass.stripAccessibilityLabel)"
    setTitle(pitchClass.stripVisibleTitle, for: .normal)
    setNeedsUpdateConfiguration()
}

private extension PitchClass {
    var stripVisibleTitle: String {
        isNatural ? displayText() : ""
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: NaturalNoteButton.apply(pitchClass:), PitchClass.stripVisibleTitle
// 功能说明: 修改后 macOS 与 iOS 保持同一视觉语义；
// 自然音显示标题，升降号按钮先作为空白按钮占位。
func apply(pitchClass: PitchClass) {
    self.pitchClass = pitchClass
    self.title = pitchClass.stripVisibleTitle
    toolTip = "Choose note \(pitchClass.stripAccessibilityLabel)"
    identifier = NSUserInterfaceItemIdentifier(
        "natural-note-strip-button-\(pitchClass.stripIdentifierToken)"
    )
    applyCurrentAppearance()
    invalidateIntrinsicContentSize()
}

private extension PitchClass {
    var stripVisibleTitle: String {
        isNatural ? displayText() : ""
    }
}
```

## 修改 3：为半音按钮补稳定的无障碍标签和按钮标识

### 修改前

- 按钮 ID 与无障碍描述都依赖按钮标题
- 这在 7 个自然音按钮阶段没有问题
- 但如果升降号按钮标题改为空白，原有做法就会让这些按钮失去有意义的标识信息

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: NaturalNoteButton.apply(pitchClass:)
// 功能说明: 修改前 iOS 的 accessibility ID 与 label 都直接依赖 title；
// 一旦标题留空，升降号按钮就没有稳定、可识别的辅助信息。
let title = pitchClass.displayText()
accessibilityIdentifier = "natural-note-strip-button-\(title.lowercased())"
accessibilityLabel = "Choose natural note \(title)"
setTitle(title, for: .normal)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: NaturalNoteButton.apply(pitchClass:)
// 功能说明: 修改前 macOS 的 toolTip 和 identifier 也直接依赖 title；
// 标题留空后，升降号按钮将缺少稳定的语义标识。
let title = pitchClass.displayText()
self.title = title
toolTip = "Choose natural note \(title)"
identifier = NSUserInterfaceItemIdentifier(
    "natural-note-strip-button-\(title.lowercased())"
)
```

### 修改后

- 新增 `PitchClass.stripAccessibilityLabel`
- 新增 `PitchClass.stripIdentifierToken`
- 升降号按钮虽然不显示文字，但仍保留可读语义，例如：
- `C sharp / D flat`
- `F sharp / G flat`
- 同时 ID 也保持稳定，例如：
- `natural-note-strip-button-c-sharp-d-flat`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: PitchClass.stripAccessibilityLabel, PitchClass.stripIdentifierToken
// 功能说明: 修改后 iOS 的空白半音按钮仍有稳定 accessibility label 和 identifier；
// 这样即使不显示文字，也不会丢失点击语义和后续自动化定位能力。
private extension PitchClass {
    var stripAccessibilityLabel: String {
        switch self {
        case .c:
            return "C"
        case .cSharp:
            return "C sharp / D flat"
        case .d:
            return "D"
        case .dSharp:
            return "D sharp / E flat"
        case .e:
            return "E"
        case .f:
            return "F"
        case .fSharp:
            return "F sharp / G flat"
        case .g:
            return "G"
        case .gSharp:
            return "G sharp / A flat"
        case .a:
            return "A"
        case .aSharp:
            return "A sharp / B flat"
        case .b:
            return "B"
        }
    }

    var stripIdentifierToken: String {
        switch self {
        case .c:
            return "c"
        case .cSharp:
            return "c-sharp-d-flat"
        case .d:
            return "d"
        case .dSharp:
            return "d-sharp-e-flat"
        case .e:
            return "e"
        case .f:
            return "f"
        case .fSharp:
            return "f-sharp-g-flat"
        case .g:
            return "g"
        case .gSharp:
            return "g-sharp-a-flat"
        case .a:
            return "a"
        case .aSharp:
            return "a-sharp-b-flat"
        case .b:
            return "b"
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名: PitchClass.stripAccessibilityLabel, PitchClass.stripIdentifierToken
// 功能说明: 修改后 macOS 与 iOS 使用同一套半音语义映射；
// 空白按钮虽然不显示字，但 toolTip 与 identifier 仍能区分具体音级。
private extension PitchClass {
    var stripAccessibilityLabel: String {
        switch self {
        case .c:
            return "C"
        case .cSharp:
            return "C sharp / D flat"
        case .d:
            return "D"
        case .dSharp:
            return "D sharp / E flat"
        case .e:
            return "E"
        case .f:
            return "F"
        case .fSharp:
            return "F sharp / G flat"
        case .g:
            return "G"
        case .gSharp:
            return "G sharp / A flat"
        case .a:
            return "A"
        case .aSharp:
            return "A sharp / B flat"
        case .b:
            return "B"
        }
    }

    var stripIdentifierToken: String {
        switch self {
        case .c:
            return "c"
        case .cSharp:
            return "c-sharp-d-flat"
        case .d:
            return "d"
        case .dSharp:
            return "d-sharp-e-flat"
        case .e:
            return "e"
        case .f:
            return "f"
        case .fSharp:
            return "f-sharp-g-flat"
        case .g:
            return "g"
        case .gSharp:
            return "g-sharp-a-flat"
        case .a:
            return "a"
        case .aSharp:
            return "a-sharp-b-flat"
        case .b:
            return "b"
        }
    }
}
```

## 修改 4：为 12 格布局收紧按钮间距和横向内边距

### 修改前

- 7 键布局时，按钮之间的 `itemSpacing` 和按钮内边距都偏宽
- 直接扩到 12 键后会显得过挤，按钮内容区浪费过多横向空间

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名/符号: Style.itemSpacing, Style.buttonContentInsets
// 功能说明: 修改前 iOS 的横向间距与按钮左右内边距按 7 键布局设计；
// 扩到 12 键后会显得过宽。
private enum Style {
    static let itemSpacing: CGFloat = 8
    static let buttonContentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 12,
        bottom: 8,
        trailing: 12
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名/符号: Style.itemSpacing, Style.buttonContentInsets
// 功能说明: 修改前 macOS 也沿用 7 键布局间距；
// 若改成 12 键，按钮槽位会明显偏挤。
private enum Style {
    static let itemSpacing: CGFloat = 8
    static let buttonContentInsets = NSEdgeInsets(
        top: 7,
        left: 12,
        bottom: 7,
        right: 12
    )
}
```

### 修改后

- `itemSpacing` 从 `8` 收到 `6`
- 按钮左右内边距从 `12` 收到 `8`
- 这样在不改控制器布局的前提下，12 键面板更容易在原有主内容区域里放下

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名/符号: Style.itemSpacing, Style.buttonContentInsets
// 功能说明: 修改后 iOS 在扩到 12 键后仍保持相对均匀的横向布局；
// 自然音按钮与空白半音按钮都能落在原有面板宽度内。
private enum Style {
    static let itemSpacing: CGFloat = 6
    static let buttonContentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 8,
        bottom: 8,
        trailing: 8
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名/符号: Style.itemSpacing, Style.buttonContentInsets
// 功能说明: 修改后 macOS 的 12 键按钮条也同步收窄横向间距；
// 保持双端布局密度一致，避免一端更挤一端更松。
private enum Style {
    static let itemSpacing: CGFloat = 6
    static let buttonContentInsets = NSEdgeInsets(
        top: 7,
        left: 8,
        bottom: 7,
        right: 8
    )
}
```

## 最终结果

- 位置音名模式底部按钮条已从 7 个自然音扩成完整 12 半音顺序
- 自然音按钮继续显示字母
- 升降号按钮目前先使用空白按钮占位，但仍然保留正确的 `PitchClass` 点击语义
- iOS 与 macOS 的按钮顺序、无障碍语义与按钮标识保持一致
- 由于控制器仍按 `PitchClass` 回调，本次改动不需要额外调整作答链路
- 本轮改动后已检查两个按钮条文件的 lints，未发现新增错误

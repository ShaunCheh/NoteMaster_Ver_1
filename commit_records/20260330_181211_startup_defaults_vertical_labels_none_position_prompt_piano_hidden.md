# 20260330_181211_startup_defaults_vertical_labels_none_position_prompt_piano_hidden

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_181211`
- 记录范围：启动默认值收口
- 本次目标：把启动时的共享默认状态统一改为 `fretboard = vertical`、`labels = none`、`exercise mode = position`、`selected frets = 1/2/3/4/8/9/10/11`、`piano visible = false`
- 根因说明：这些默认值的真相源不在平台按钮层，而在共享状态默认构造和 `PianoPanelState.inferred(...)`；因此本次记录按源头说明，而不是只描述表层 UI 现象
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift`

## 修改前总览

- `fretboard` 启动默认是 `horizontal`
- `labels` 启动默认是 `all`
- `exercise mode` 启动默认是 `single`
- `position` 模式默认选中品位是 `1...12`
- `piano visible` 启动默认是 `true`

## 修改 1：指板启动默认改为 `vertical`，labels 启动默认改为 `none`

### 修改前

- 共享默认状态里，`FretboardDisplayState.default` 直接把 `displayMode` 设成 `.horizontal`
- `default` 没有显式传入 `visibility`，因此会沿用 `init(...)` 的默认参数 `.all`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数名/符号: FretboardDisplayState.default, FretboardDisplayState.init(...)
// 功能说明: 修改前启动默认方向是 horizontal；labels 未在 default 中显式覆盖，因此会落到 init 默认值 .all。
static let `default` = FretboardDisplayState(
    configuration: FretboardConfiguration(
        displayMode: .horizontal,
        tuning: .standard(for: .guitar6),
        maxFret: 12
    ),
    verticalHostHeightRatio: defaultVerticalHostHeightRatio
)

init(
    configuration: FretboardConfiguration,
    visibility: NoteLabelVisibility = .all,
    spelling: PitchSpelling = .sharp,
    showsOctave: Bool = true,
    showsComponentBoundsOverlay: Bool = false,
    verticalHostHeightRatio: CGFloat = defaultVerticalHostHeightRatio
)
```

### 修改后

- `displayMode` 改成 `.vertical`
- `visibility` 在共享默认值里显式指定为 `.none`
- `init(...)` 的默认参数保持不动，真正变化点收口在启动真相源 `FretboardDisplayState.default`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数名/符号: FretboardDisplayState.default, FretboardDisplayState.init(...)
// 功能说明: 修改后启动默认方向改为 vertical，并在共享默认状态层显式把 labels 设为 none。
static let `default` = FretboardDisplayState(
    configuration: FretboardConfiguration(
        displayMode: .vertical,
        tuning: .standard(for: .guitar6),
        maxFret: 12
    ),
    visibility: .none,
    verticalHostHeightRatio: defaultVerticalHostHeightRatio
)

init(
    configuration: FretboardConfiguration,
    visibility: NoteLabelVisibility = .all,
    spelling: PitchSpelling = .sharp,
    showsOctave: Bool = true,
    showsComponentBoundsOverlay: Bool = false,
    verticalHostHeightRatio: CGFloat = defaultVerticalHostHeightRatio
)
```

## 修改 2：exercise mode 启动默认改为 `position`，默认品位改为 `1/2/3/4/8/9/10/11`

### 修改前

- `TrainerPositionPromptConfiguration.defaultSelectedFrets` 直接是 `Set(supportedFretRange)`，也就是 `1...12`
- `TrainerDisplayState.default` 没有显式传参，因此启动时会落到 `init(...)` 的默认 `exerciseMode: .single`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerPositionPromptConfiguration.defaultSelectedFrets, TrainerDisplayState.default, TrainerDisplayState.init(...)
// 功能说明: 修改前 position 模式默认选中全部 1...12 品位，且启动 exercise mode 默认落在 single。
static let defaultSelectedFrets = Set(supportedFretRange)

static let `default` = TrainerDisplayState()

init(
    exerciseMode: TrainerExerciseMode = .single,
    sequenceConfiguration: TrainerSequenceConfiguration = .default,
    positionPromptConfiguration: TrainerPositionPromptConfiguration = .default
)
```

### 修改后

- `defaultSelectedFrets` 收口为 `[1, 2, 3, 4, 8, 9, 10, 11]`
- `TrainerDisplayState.default` 显式指定 `exerciseMode: .positionPrompt`
- UI 文案里的 `position` 在共享状态代码里对应的是 `.positionPrompt`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerPositionPromptConfiguration.defaultSelectedFrets, TrainerDisplayState.default, TrainerDisplayState.init(...)
// 功能说明: 修改后启动时直接进入 positionPrompt，并把默认品位限制为 1/2/3/4/8/9/10/11。
static let defaultSelectedFrets: Set<Int> = [
    1, 2, 3, 4,
    8, 9, 10, 11
]

static let `default` = TrainerDisplayState(
    exerciseMode: .positionPrompt
)

init(
    exerciseMode: TrainerExerciseMode = .single,
    sequenceConfiguration: TrainerSequenceConfiguration = .default,
    positionPromptConfiguration: TrainerPositionPromptConfiguration = .default
)
```

## 修改 3：piano 的 visible 启动默认改为关闭，并同步修正 `inferred(...)` 入口

### 修改前

- `PianoPanelState.init(...)` 的默认参数是 `isVisible: true`
- 控制器启动时不是简单调用 `.init()`，而是走 `PianoPanelState.inferred(...)`
- `inferred(...)` 之前也写死了 `isVisible: true`，所以如果只改 `init(...)`，控制器启动路径仍然会绕过去

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelState.init(...), PianoPanelState.inferred(...)
// 功能说明: 修改前无论直接构造还是从 inferred 启动构造，piano 面板默认都是可见的。
init(
    isVisible: Bool = true,
    rowCount: Int = 3,
    movementScope: PianoMovementScope = .cascade,
    whiteKeyStyle: PianoWhiteKeyStyle = .outlined,
    snapEnabled: Bool = true
)

static func inferred(
    configuration: PianoConfiguration,
    rows: [PianoRowState]
) -> PianoPanelState {
    PianoPanelState(
        isVisible: true,
        rowCount: min(
            max(rows.count, Self.supportedRowCountRange.lowerBound),
            Self.supportedRowCountRange.upperBound
        ),
        movementScope: rows.first?.movementScope ?? .cascade,
        whiteKeyStyle: configuration.whiteKeyStyle,
        snapEnabled: configuration.snapEnabled
    )
}
```

### 修改后

- `init(...)` 默认值改为 `isVisible: false`
- `inferred(...)` 也同步改成 `isVisible: false`
- 这样直接构造和控制器启动推导两条路径都统一成“启动默认关闭 piano”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPanelState.swift
// 函数名/符号: PianoPanelState.init(...), PianoPanelState.inferred(...)
// 功能说明: 修改后直接构造和 inferred 构造都统一默认为隐藏 piano 面板，避免控制器入口绕过默认值。
init(
    isVisible: Bool = false,
    rowCount: Int = 3,
    movementScope: PianoMovementScope = .cascade,
    whiteKeyStyle: PianoWhiteKeyStyle = .outlined,
    snapEnabled: Bool = true
)

static func inferred(
    configuration: PianoConfiguration,
    rows: [PianoRowState]
) -> PianoPanelState {
    PianoPanelState(
        isVisible: false,
        rowCount: min(
            max(rows.count, Self.supportedRowCountRange.lowerBound),
            Self.supportedRowCountRange.upperBound
        ),
        movementScope: rows.first?.movementScope ?? .cascade,
        whiteKeyStyle: configuration.whiteKeyStyle,
        snapEnabled: configuration.snapEnabled
    )
}
```

## 最终启动默认值

- `fretboard`: `vertical`
- `labels`: `none`
- `exercise mode`: `position`（代码枚举值为 `.positionPrompt`）
- `selected frets`: `1, 2, 3, 4, 8, 9, 10, 11`
- `piano visible`: `false`

## 验证

- 已检查本次修改文件的 lints：无新增报错
- 已通过 macOS Debug 构建验证：`DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`

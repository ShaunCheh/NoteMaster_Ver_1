# 20260331_113614_phase5_position_filter_shared_trainer_filter_api

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_113614`
- 记录范围：实施“Position 过滤模式重构”计划的阶段 5，只完成 shared trainer 候选池接口与建题/换题链路的统一 filter 改造；不包含 iOS / macOS controller 的同步改造，不包含 validation 扩展
- 本次目标：把 `FretboardNaturalNoteTrainer` 从旧的 `allowedFrets` 单一入口提升成统一 `PositionPromptCandidateFilter` 入口，同时保持“先过滤，再生成”和“按位置均匀抽样”的原有出题契约不变
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`

## 本次结论

- `makePositionPromptSession(...)` 与 `handlePositionPromptAnswer(...)` 的核心入口已经提升到 `filter: PositionPromptCandidateFilter`
- shared trainer 内部的 `excluding current promptCell` 换题逻辑已经同步切到统一 filter 链路
- 候选池枚举不再只认 `allowedFrets`，而是根据 `.noteNames(...)` / `.frets(...)` 两种 filter 分流
- 旧的 `allowedFrets` 对外调用口仍然保留为兼容桥接，因此 controller / validation 在下一阶段前不会被这一步直接打断
- begin / end 日志也改成输出统一 filter 信息，便于后续联调 `noteName` / `fret` 两种模式

## 修改 1：对外 API 从 `allowedFrets` 提升为统一 `filter`，同时保留兼容桥接

### 修改前

- `makePositionPromptSession(...)` 和 `handlePositionPromptAnswer(...)` 都只接受 `allowedFrets`
- 这使得 trainer 的共享入口天然只理解“按品位过滤”，无法直接承载“按音名过滤”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makePositionPromptSession(configuration:allowedFrets:),
// makePositionPromptSession(configuration:allowedFrets:using:),
// handlePositionPromptAnswer(_:configuration:allowedFrets:session:),
// handlePositionPromptAnswer(_:configuration:allowedFrets:session:using:)
// 功能说明: 修改前 shared trainer 对外只暴露 allowedFrets 入口；
// 这会把 Position Prompt 的过滤能力限制死在“按品位筛选”这一种模式上。
func makePositionPromptSession(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets
) -> PositionPromptSession {
    var generator = SystemRandomNumberGenerator()
    return makePositionPromptSession(
        configuration: configuration,
        allowedFrets: allowedFrets,
        using: &generator
    )
}

func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets,
    using generator: inout R
) -> PositionPromptSession {
    let normalizedAllowedFrets = Self.normalizedPositionPromptAllowedFrets(
        allowedFrets
    )
    // ... 省略日志与建题
}

mutating func handlePositionPromptAnswer(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets,
    session: inout PositionPromptSession
) -> PositionPromptAnswerResult {
    var generator = SystemRandomNumberGenerator()
    return handlePositionPromptAnswer(
        pitchClass,
        configuration: configuration,
        allowedFrets: allowedFrets,
        session: &session,
        using: &generator
    )
}
```

### 修改后

- 核心入口改成 `filter: PositionPromptCandidateFilter`
- 默认值直接对齐 `TrainerPositionPromptConfiguration.default.activeFilter`
- 旧 `allowedFrets` 入口被保留成桥接层，内部统一转成 `.frets(allowedFrets)` 再进入新链路

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makePositionPromptSession(configuration:filter:),
// makePositionPromptSession(configuration:filter:using:),
// handlePositionPromptAnswer(_:configuration:filter:session:),
// handlePositionPromptAnswer(_:configuration:filter:session:using:)
// 功能说明: 修改后 shared trainer 对外正式提升到统一 filter 入口；
// 同时保留 allowedFrets 兼容桥接，避免下一阶段 controller / validation 之前先断编。
func makePositionPromptSession(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter
) -> PositionPromptSession {
    var generator = SystemRandomNumberGenerator()
    return makePositionPromptSession(
        configuration: configuration,
        filter: filter,
        using: &generator
    )
}

func makePositionPromptSession(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int>
) -> PositionPromptSession {
    makePositionPromptSession(
        configuration: configuration,
        filter: .frets(allowedFrets)
    )
}

mutating func handlePositionPromptAnswer(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter = TrainerPositionPromptConfiguration.default.activeFilter,
    session: inout PositionPromptSession
) -> PositionPromptAnswerResult {
    var generator = SystemRandomNumberGenerator()
    return handlePositionPromptAnswer(
        pitchClass,
        configuration: configuration,
        filter: filter,
        session: &session,
        using: &generator
    )
}

mutating func handlePositionPromptAnswer(
    _ pitchClass: PitchClass,
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int>,
    session: inout PositionPromptSession
) -> PositionPromptAnswerResult {
    handlePositionPromptAnswer(
        pitchClass,
        configuration: configuration,
        filter: .frets(allowedFrets),
        session: &session
    )
}
```

## 修改 2：内部建题与答对换题链路从 `allowedFrets` 切到统一 `filter`

### 修改前

- 内部 `makePositionPromptSession(configuration:allowedFrets:excluding:using:)` 仍然只接收品位集合
- 答对后换题时也沿用 `allowedFrets`
- 这意味着即使 settings 层已经能切到 `noteName` 模式，shared trainer 也不会真正按音名筛题

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makePositionPromptSession(configuration:allowedFrets:excluding:using:),
// handlePositionPromptAnswer(_:configuration:allowedFrets:session:using:)
// 功能说明: 修改前内部选题与答对换题链路都只认 allowedFrets；
// 共享 trainer 的真正出题路径还没有接入 noteName / fret 两种统一过滤模式。
private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    allowedFrets: Set<Int>,
    excluding excludedCell: FretboardCell?,
    using generator: inout R
) -> PositionPromptSession {
    let normalizedAllowedFrets = normalizedPositionPromptAllowedFrets(
        allowedFrets
    )
    let allowedFretsText = normalizedAllowedFrets.sorted().map(String.init).joined(
        separator: ","
    )
    print(
        "[PositionPrompt][Trainer] selectPrompt begin allowedFrets=\(allowedFretsText) excluded=\(excludedCellText)"
    )
    let candidates = positionPromptCandidateCells(
        in: configuration,
        allowedFrets: normalizedAllowedFrets
    )
    // ... 省略抽样逻辑
}

if isCorrect {
    nextSession = Self.makePositionPromptSession(
        configuration: configuration,
        allowedFrets: allowedFrets,
        excluding: promptCell,
        using: &generator
    )
}
```

### 修改后

- 内部建题函数提升成 `makePositionPromptSession(configuration:filter:excluding:using:)`
- 正确作答后的换题也统一改走 `filter`
- `excluding current promptCell` 规则保持不变，只是换成在统一候选池上做排除

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: makePositionPromptSession(configuration:filter:excluding:using:),
// handlePositionPromptAnswer(_:configuration:filter:session:using:)
// 功能说明: 修改后内部建题与答对换题链路都切到统一 filter；
// 仍然保持“先过滤，再随机抽一个位置”，并保留 excluding 当前 promptCell 的换题规则。
private static func makePositionPromptSession<R: RandomNumberGenerator>(
    configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter,
    excluding excludedCell: FretboardCell?,
    using generator: inout R
) -> PositionPromptSession {
    let normalizedFilter = normalizedPositionPromptFilter(filter)
    let filterText = positionPromptFilterDebugText(normalizedFilter)
    print(
        "[PositionPrompt][Trainer] selectPrompt begin \(filterText) excluded=\(excludedCellText)"
    )
    let candidates = positionPromptCandidateCells(
        in: configuration,
        filter: normalizedFilter
    )
    // ... 省略抽样逻辑
}

if isCorrect {
    nextSession = Self.makePositionPromptSession(
        configuration: configuration,
        filter: filter,
        excluding: promptCell,
        using: &generator
    )
}
```

## 修改 3：候选池从“只按品位过滤”升级为“按音名 / 品位二选一过滤”

### 修改前

- `positionPromptCandidateCells(...)` 会先判断 `normalizedAllowedFrets.contains(fret)`
- 这使得候选池只能保留某些品位上的自然音位置，完全不支持“先遍历整个指板，再按音名筛”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: positionPromptCandidateCells(in:allowedFrets:)
// 功能说明: 修改前候选池只支持按品位过滤；
// 它先看 fret 是否在 allowedFrets 里，再判断该位置是不是自然音。
private static func positionPromptCandidateCells(
    in configuration: FretboardConfiguration,
    allowedFrets: Set<Int> = TrainerPositionPromptConfiguration.defaultSelectedFrets
) -> [FretboardCell] {
    let normalizedAllowedFrets = normalizedPositionPromptAllowedFrets(
        allowedFrets
    )
    var cells: [FretboardCell] = []

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            guard normalizedAllowedFrets.contains(fret) else {
                continue
            }
            let cell = FretboardCell(
                stringIndex: stringIndex,
                fret: fret
            )
            guard let pitchClass = configuration.pitchClass(for: cell),
                  pitchClass.isNatural else {
                continue
            }
            cells.append(cell)
        }
    }

    return cells
}
```

### 修改后

- 候选池函数改成 `positionPromptCandidateCells(in:filter:)`
- `noteName` 分支会遍历 `configuration.fretRange` 里的全部位置，再按自然音名集合筛
- `fret` 分支继续保留旧行为，只保留允许品位里的自然音位置

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: positionPromptCandidateCells(in:filter:)
// 功能说明: 修改后候选池先统一枚举当前指板的所有位置，
// 再根据 filterMode 分流到 noteNames 或 frets 两种互斥过滤规则。
private static func positionPromptCandidateCells(
    in configuration: FretboardConfiguration,
    filter: PositionPromptCandidateFilter
) -> [FretboardCell] {
    let normalizedFilter = normalizedPositionPromptFilter(filter)
    var cells: [FretboardCell] = []

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            let cell = FretboardCell(
                stringIndex: stringIndex,
                fret: fret
            )
            guard let pitchClass = configuration.pitchClass(for: cell),
                  pitchClass.isNatural else {
                continue
            }
            switch normalizedFilter {
            case let .noteNames(selectedPitchClasses):
                guard selectedPitchClasses.contains(pitchClass) else {
                    continue
                }
            case let .frets(selectedFrets):
                guard selectedFrets.contains(fret) else {
                    continue
                }
            }
            cells.append(cell)
        }
    }

    return cells
}
```

## 修改 4：过滤归一化从 `allowedFrets` helper 升级为统一 filter helper，并补齐调试文本

### 修改前

- shared trainer 只有 `normalizedPositionPromptAllowedFrets(_:)`
- 归一化逻辑只能修正 fret 集合，无法对 `noteName` 模式的音名集合做统一归一化
- 日志里也只有 `allowedFrets=...`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: normalizedPositionPromptAllowedFrets(_:)
// 功能说明: 修改前 shared trainer 只会归一化 allowedFrets，
// 无法统一处理 noteName / fret 两种过滤输入，也无法输出统一的 filter 调试信息。
private static func normalizedPositionPromptAllowedFrets(
    _ allowedFrets: Set<Int>
) -> Set<Int> {
    TrainerPositionPromptConfiguration(
        selectedFrets: allowedFrets
    ).selectedFrets
}
```

### 修改后

- 新增 `normalizedPositionPromptFilter(_:)`
- `noteName` 分支复用 `TrainerPositionPromptConfiguration` 的自然音归一化
- `fret` 分支继续复用品位归一化
- 额外补上 `positionPromptFilterDebugText(_:)`，统一输出 `filterMode=...`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数名/符号: normalizedPositionPromptFilter(_:), positionPromptFilterDebugText(_:)
// 功能说明: 修改后 shared trainer 统一归一化两种 filter 输入，
// 并把 noteName / fret 的调试日志都收口为同一套文本格式。
private static func normalizedPositionPromptFilter(
    _ filter: PositionPromptCandidateFilter
) -> PositionPromptCandidateFilter {
    switch filter {
    case let .noteNames(selectedPitchClasses):
        let normalizedConfiguration = TrainerPositionPromptConfiguration(
            filterMode: .noteName,
            selectedPitchClasses: selectedPitchClasses
        )
        return .noteNames(normalizedConfiguration.selectedPitchClasses)
    case let .frets(selectedFrets):
        let normalizedConfiguration = TrainerPositionPromptConfiguration(
            filterMode: .fret,
            selectedFrets: selectedFrets
        )
        return .frets(normalizedConfiguration.selectedFrets)
    }
}

private static func positionPromptFilterDebugText(
    _ filter: PositionPromptCandidateFilter
) -> String {
    switch normalizedPositionPromptFilter(filter) {
    case let .noteNames(selectedPitchClasses):
        let orderedPitchClasses =
            TrainerPositionPromptConfiguration.supportedPitchClasses
            .filter { selectedPitchClasses.contains($0) }
            .map { $0.displayText() }
            .joined(separator: ",")
        return "filterMode=noteName noteNames=\(orderedPitchClasses)"
    case let .frets(selectedFrets):
        let orderedFrets = selectedFrets.sorted().map(String.init).joined(
            separator: ","
        )
        return "filterMode=fret frets=\(orderedFrets)"
    }
}
```

## 验证情况

- 已对以下文件运行 `ReadLints`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 结果：无 linter 报错
- 本次未运行 `xcodebuild` / 应用启动验证，因此这份记录只确认 shared trainer 改造与 IDE lint 状态

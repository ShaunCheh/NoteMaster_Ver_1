# 20260331_103556_phase1_position_filter_unified_domain_model

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_103556`
- 记录范围：实施“Position 过滤模式重构”计划的阶段 1，只完成 shared 状态模型重构，不涉及设置面板快照、双端 UI、shared trainer 候选池或 controller 重建
- 本次目标：把当前只支持“按品位过滤”的 `TrainerPositionPromptConfiguration` 升级为统一过滤域模型，为后续阶段接入“按音名过滤 + 过滤模式互斥 + 默认 CEFB”打基础
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`

## 本次结论

- `positionPrompt` 的共享状态已经从“只有 `selectedFrets`”升级为“`filterMode + selectedPitchClasses + selectedFrets`”
- 默认过滤模式已经改成 `noteName`
- 默认音名集合已经收口为 `C/E/F/B`
- 旧的品位相关 API 仍保留，便于后续阶段逐步把 settings / trainer / controller 接到新模型上
- 这一阶段还没有修改任何 UI 或出题逻辑，因此用户可见行为暂时不会变化

## 修改 1：新增统一过滤模式枚举与候选过滤抽象

### 修改前

- 共享状态层没有“过滤模式”的概念
- `positionPrompt` 只能表达“选中了哪些品位”
- 后续如果直接再加“按音名过滤”，只能继续在各层叠加特例分支

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerExerciseMode, TrainerPositionPromptConfiguration
// 功能说明: 修改前 positionPrompt 配置层没有 filterMode，也没有统一候选过滤抽象；
// shared 状态只能承载 selectedFrets，无法表达“按音名过滤”和“过滤模式互斥”。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
}

struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let defaultSelectedFrets: Set<Int> = [
        1, 2, 3, 4,
        8, 9, 10, 11
    ]
    static let `default` = TrainerPositionPromptConfiguration()

    private(set) var selectedFrets: Set<Int>
}
```

### 修改后

- 新增 `TrainerPositionPromptFilterMode`
- 新增 `PositionPromptCandidateFilter`
- `TrainerPositionPromptConfiguration` 正式具备“当前激活哪一种过滤”的状态出口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerPositionPromptFilterMode, PositionPromptCandidateFilter, TrainerPositionPromptConfiguration.activeFilter
// 功能说明: 修改后 shared 状态先明确“当前是按音名过滤还是按品位过滤”，
// 再通过 activeFilter 暴露统一候选过滤出口，供后续 settings / trainer / controller 复用。
enum TrainerPositionPromptFilterMode: Equatable, Hashable, Sendable {
    case noteName
    case fret
}

enum PositionPromptCandidateFilter: Equatable, Sendable {
    case noteNames(Set<PitchClass>)
    case frets(Set<Int>)
}

struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let supportedPitchClasses: [PitchClass] = PitchClass.naturalCasesInOrder
    static let defaultFilterMode: TrainerPositionPromptFilterMode = .noteName

    var filterMode: TrainerPositionPromptFilterMode
    private(set) var selectedPitchClasses: Set<PitchClass>
    private(set) var selectedFrets: Set<Int>

    var activeFilter: PositionPromptCandidateFilter {
        switch filterMode {
        case .noteName:
            return .noteNames(selectedPitchClasses)
        case .fret:
            return .frets(selectedFrets)
        }
    }
}
```

## 修改 2：把默认值从“默认品位集合”扩展为“双集合 + 默认音名模式”

### 修改前

- 默认值只有 `defaultSelectedFrets`
- 没有默认音名集合
- 没有“默认进入按音名过滤”的共享层入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerPositionPromptConfiguration.defaultSelectedFrets, TrainerPositionPromptConfiguration.init(...)
// 功能说明: 修改前默认值只覆盖品位集合，positionPrompt 启动时没有 note-name filter 的共享层默认状态。
struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let defaultSelectedFrets: Set<Int> = [
        1, 2, 3, 4,
        8, 9, 10, 11
    ]
    static let `default` = TrainerPositionPromptConfiguration()

    private(set) var selectedFrets: Set<Int>

    init(
        selectedFrets: Set<Int> = Self.defaultSelectedFrets
    ) {
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }
}
```

### 修改后

- 默认过滤模式改成 `noteName`
- 默认音名集合改成 `C/E/F/B`
- 原有默认品位集合继续保留，便于以后切回 `fret` 模式时直接沿用

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerPositionPromptConfiguration.defaultFilterMode, defaultSelectedPitchClasses, defaultSelectedFrets, init(...)
// 功能说明: 修改后 shared 层默认就具备“按音名过滤 + 默认 CEFB”的启动状态；
// 同时继续保存默认品位集合，支持未来在两种过滤模式之间互斥切换但不丢历史选择。
struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let supportedPitchClasses: [PitchClass] = PitchClass.naturalCasesInOrder
    static let defaultFilterMode: TrainerPositionPromptFilterMode = .noteName
    static let defaultSelectedPitchClasses: Set<PitchClass> = [
        .c, .e, .f, .b
    ]
    static let defaultSelectedFrets: Set<Int> = [
        1, 2, 3, 4,
        8, 9, 10, 11
    ]
    static let `default` = TrainerPositionPromptConfiguration()

    init(
        filterMode: TrainerPositionPromptFilterMode = Self.defaultFilterMode,
        selectedPitchClasses: Set<PitchClass> = Self.defaultSelectedPitchClasses,
        selectedFrets: Set<Int> = Self.defaultSelectedFrets
    ) {
        self.filterMode = filterMode
        self.selectedPitchClasses = Self.normalizedSelectedPitchClasses(
            selectedPitchClasses
        )
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }
}
```

## 修改 3：把“至少保留一个已选项”的约束从单一品位扩展到音名与品位两侧

### 修改前

- 只有品位集合具备：
- `contains(_ fret:)`
- `canDeselect(_ fret:)`
- `toggled(fret:)`
- `toggleFret(_:)`
- 没有音名侧的对称 API

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: contains(_ fret:), canDeselect(_ fret:), toggled(fret:), toggleFret(_:)
// 功能说明: 修改前“最后一个不可取消”的共享层约束只覆盖品位集合，音名集合还没有对应能力。
func contains(_ fret: Int) -> Bool {
    selectedFrets.contains(fret)
}

func canDeselect(_ fret: Int) -> Bool {
    guard selectedFrets.contains(fret) else {
        return true
    }

    return selectedFrets.count > 1
}

func toggled(fret: Int) -> TrainerPositionPromptConfiguration {
    guard Self.supportedFretRange.contains(fret) else {
        return self
    }

    var nextSelectedFrets = selectedFrets
    if nextSelectedFrets.contains(fret) {
        guard canDeselect(fret) else {
            return self
        }
        nextSelectedFrets.remove(fret)
    } else {
        nextSelectedFrets.insert(fret)
    }

    return TrainerPositionPromptConfiguration(
        selectedFrets: nextSelectedFrets
    )
}
```

### 修改后

- 新增音名侧的：
- `contains(_ pitchClass:)`
- `canDeselect(_ pitchClass:)`
- `toggled(pitchClass:)`
- `togglePitchClass(_:)`
- 这样“至少保留一个已选项”的保护逻辑，不再只属于 `fret`，而是正式成为统一过滤域模型的一部分

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: contains(_ pitchClass:), canDeselect(_ pitchClass:), toggled(pitchClass:), togglePitchClass(_:)
// 功能说明: 修改后音名集合也具备与品位集合对称的查询、切换与最后一个已选项保护逻辑；
// 后续 settings panel 可以直接复用这些共享规则，无需在 iOS/macOS 侧重复实现。
func contains(_ pitchClass: PitchClass) -> Bool {
    selectedPitchClasses.contains(pitchClass)
}

func canDeselect(_ pitchClass: PitchClass) -> Bool {
    guard selectedPitchClasses.contains(pitchClass) else {
        return true
    }

    return selectedPitchClasses.count > 1
}

func toggled(pitchClass: PitchClass) -> TrainerPositionPromptConfiguration {
    guard pitchClass.isNatural else {
        return self
    }

    var nextSelectedPitchClasses = selectedPitchClasses
    if nextSelectedPitchClasses.contains(pitchClass) {
        guard canDeselect(pitchClass) else {
            return self
        }
        nextSelectedPitchClasses.remove(pitchClass)
    } else {
        nextSelectedPitchClasses.insert(pitchClass)
    }

    return TrainerPositionPromptConfiguration(
        filterMode: filterMode,
        selectedPitchClasses: nextSelectedPitchClasses,
        selectedFrets: selectedFrets
    )
}

mutating func togglePitchClass(_ pitchClass: PitchClass) {
    self = toggled(pitchClass: pitchClass)
}
```

## 修改 4：把 `TrainerDisplayState` 的公开入口补齐到过滤模式与音名集合

### 修改前

- `TrainerDisplayState` 对外只提供：
- `setPositionPromptConfiguration(_:)`
- `togglePositionPromptFret(_:)`
- 没有过滤模式切换入口
- 没有音名切换入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerDisplayState.setPositionPromptConfiguration(_:), togglePositionPromptFret(_:)
// 功能说明: 修改前 display state 对外只暴露品位切换入口；
// settings panel 下一阶段如果要接 note-name filter，没有可复用的状态更新接口。
mutating func setPositionPromptConfiguration(
    _ configuration: TrainerPositionPromptConfiguration
) {
    positionPromptConfiguration = configuration.normalized()
}

mutating func togglePositionPromptFret(_ fret: Int) {
    positionPromptConfiguration = positionPromptConfiguration.toggled(
        fret: fret
    )
}
```

### 修改后

- 新增：
- `setPositionPromptFilterMode(_:)`
- `togglePositionPromptPitchClass(_:)`
- 这样后续阶段只要把 settings event 接到这些入口即可

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerDisplayState.setPositionPromptFilterMode(_:), togglePositionPromptPitchClass(_:), togglePositionPromptFret(_:)
// 功能说明: 修改后 TrainerDisplayState 对外正式暴露“切过滤模式”和“切音名集合”的共享入口；
// 后续 settings panel / controller 不必直接操作内部存储字段。
mutating func setPositionPromptFilterMode(
    _ filterMode: TrainerPositionPromptFilterMode
) {
    positionPromptConfiguration.setFilterMode(filterMode)
}

mutating func togglePositionPromptPitchClass(
    _ pitchClass: PitchClass
) {
    positionPromptConfiguration = positionPromptConfiguration.toggled(
        pitchClass: pitchClass
    )
}

mutating func togglePositionPromptFret(_ fret: Int) {
    positionPromptConfiguration = positionPromptConfiguration.toggled(
        fret: fret
    )
}
```

## 验证

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`：无 linter 错误
- 尝试执行工程构建校验：

```shell
# 文件路径: NoteMaster_Ver_1.xcodeproj
# 函数名/符号: xcodebuild Debug build
# 功能说明: 尝试用本机 Xcode 构建工程，确认阶段 1 单文件共享状态改动没有引入编译问题。
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

- 构建未能继续，原因不是代码报错，而是当前环境的开发者目录仍指向 `CommandLineTools`：

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

## 后续阶段衔接

- 阶段 2 可以开始把 `SettingsPanelModel` 从专用 `.fretFilter` 事件/行模型，抽象成通用 position filter 模型
- 阶段 3 可以让 `SettingsPanelSnapshotBuilder` 根据 `filterMode` 渲染 `C D E F G A B` 或 `1...12`
- 阶段 5 再把 shared trainer 当前的 `allowedFrets` API 提升成统一 `activeFilter` API

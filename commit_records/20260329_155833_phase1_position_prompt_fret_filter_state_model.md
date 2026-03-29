# 20260329_155833_phase1_position_prompt_fret_filter_state_model

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260329_155833`
- 记录范围：实施“Position 品位筛选”计划的阶段 1，只完成 shared trainer display state 的状态建模，不涉及设置面板 UI、shared 出题过滤或双端控制器重建
- 本次目标：把 `positionPrompt` 专属的“允许品位集合”正式纳入 `TrainerDisplayState`，并在 shared 状态层收口以下约束：
- 默认选中 `1...12`
- 非法品位自动裁剪
- 空集合自动回退为默认全选
- 最后一个已选品位不可取消
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift`
- `.cursor/plans/position品位筛选_cb2e8023.plan.md`

## 本次结论

- 阶段 1 不触碰设置面板或出题链路，先只把“选中了哪些品位”收敛成共享状态模型
- 这样后续阶段 2 的设置面板、阶段 4 的 shared trainer 过滤、阶段 5 的控制器 session 重建，都可以复用同一套 `positionPromptConfiguration`
- 同时，这一层就提前把“至少保留一个已选品位”的约束固化下来，避免后续 UI 和业务层各自重复写一份判定逻辑

## 修改 1：`TrainerDisplayState` 里新增 `positionPrompt` 专属配置模型

### 修改前

- `TrainerDisplayState` 只包含：
- `exerciseMode`
- `sequenceConfiguration`
- 没有地方保存 `positionPrompt` 模式下的品位筛选状态
- 因此后续无论是设置面板回显，还是 shared trainer 出题过滤，都缺少统一真相源

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerDisplayState
// 功能说明: 修改前 TrainerDisplayState 只覆盖 single / sequence 相关状态；
// positionPrompt 没有自己的配置对象，也没有“允许品位集合”的持久状态。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration

    static let `default` = TrainerDisplayState()

    init(
        exerciseMode: TrainerExerciseMode = .single,
        sequenceConfiguration: TrainerSequenceConfiguration = .default
    ) {
        self.exerciseMode = exerciseMode
        self.sequenceConfiguration = sequenceConfiguration
    }

    var isSequenceMode: Bool {
        exerciseMode == .sequence
    }

    var isPositionPromptMode: Bool {
        exerciseMode == .positionPrompt
    }

    mutating func setExerciseMode(_ mode: TrainerExerciseMode) {
        exerciseMode = mode
    }
}
```

### 修改后

- 新增 `TrainerPositionPromptConfiguration`
- 将 `positionPromptConfiguration` 挂入 `TrainerDisplayState`
- 初始化时统一做 `normalized()`，保证进入状态树的值始终合法
- `TrainerDisplayState` 额外暴露：
- `setPositionPromptConfiguration(_:)`
- `togglePositionPromptFret(_:)`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerPositionPromptConfiguration,
// TrainerDisplayState.positionPromptConfiguration,
// setPositionPromptConfiguration(_:), togglePositionPromptFret(_:)
// 功能说明: 修改后 positionPrompt 的品位筛选配置成为 trainer display state 的正式组成部分；
// 后续设置面板、shared trainer、双端控制器都可以围绕这一个真相源工作。
enum TrainerExerciseMode: Equatable, Hashable, Sendable {
    case single
    case sequence
    case positionPrompt
}

struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let defaultSelectedFrets = Set(supportedFretRange)
    static let `default` = TrainerPositionPromptConfiguration()

    private(set) var selectedFrets: Set<Int>

    init(
        selectedFrets: Set<Int> = Self.defaultSelectedFrets
    ) {
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    var sortedSelectedFrets: [Int] {
        selectedFrets.sorted()
    }

    func normalized() -> TrainerPositionPromptConfiguration {
        TrainerPositionPromptConfiguration(
            selectedFrets: selectedFrets
        )
    }

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

    mutating func setSelectedFrets(_ selectedFrets: Set<Int>) {
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    mutating func toggleFret(_ fret: Int) {
        self = toggled(fret: fret)
    }

    private static func normalizedSelectedFrets(
        _ selectedFrets: Set<Int>
    ) -> Set<Int> {
        let normalizedFrets = Set(
            selectedFrets.filter { supportedFretRange.contains($0) }
        )
        return normalizedFrets.isEmpty
            ? defaultSelectedFrets
            : normalizedFrets
    }
}

struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration
    var positionPromptConfiguration: TrainerPositionPromptConfiguration

    static let `default` = TrainerDisplayState()

    init(
        exerciseMode: TrainerExerciseMode = .single,
        sequenceConfiguration: TrainerSequenceConfiguration = .default,
        positionPromptConfiguration: TrainerPositionPromptConfiguration = .default
    ) {
        self.exerciseMode = exerciseMode
        self.sequenceConfiguration = sequenceConfiguration
        self.positionPromptConfiguration = positionPromptConfiguration.normalized()
    }

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
}
```

## 修改 2：把“默认全选、非法值裁剪、空集合回退、最后一个不可取消”收口到配置对象内部

### 修改前

- 这四类规则在 shared 状态层完全不存在
- 如果后续直接在设置面板或控制器里临时判断，会出现：
- iOS 一套
- macOS 一套
- shared trainer 再补一套
- 结果是约束散落，后续容易不一致

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: 无
// 功能说明: 修改前没有 positionPrompt 专属配置结构；
// “默认值/归一化/最后一个不可取消”都还没有共享层入口。
struct TrainerDisplayState: Equatable, Sendable {
    var exerciseMode: TrainerExerciseMode
    var sequenceConfiguration: TrainerSequenceConfiguration
}
```

### 修改后

- `supportedFretRange = 1...12`
- `defaultSelectedFrets = Set(1...12)`
- `normalizedSelectedFrets(_:)` 负责：
- 过滤掉 `1...12` 以外的值
- 若结果为空则回退为默认全选
- `canDeselect(_:)` 和 `toggled(fret:)` 负责“最后一个已选品位不可取消”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名: normalizedSelectedFrets(_:), canDeselect(_:), toggled(fret:)
// 功能说明: 修改后 positionPrompt 品位筛选的核心约束都集中在配置对象内部；
// UI 和业务层只要调用这些 API，就能天然遵守“只允许 1~12、至少保留一个”的规则。
struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    static let supportedFretRange: ClosedRange<Int> = 1...12
    static let defaultSelectedFrets = Set(supportedFretRange)

    private(set) var selectedFrets: Set<Int>

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

    private static func normalizedSelectedFrets(
        _ selectedFrets: Set<Int>
    ) -> Set<Int> {
        let normalizedFrets = Set(
            selectedFrets.filter { supportedFretRange.contains($0) }
        )
        return normalizedFrets.isEmpty
            ? defaultSelectedFrets
            : normalizedFrets
    }
}
```

## 修改 3：把 `selectedFrets` 改成只读暴露，避免后续阶段绕过约束直接写坏状态

### 修改前

- 如果 `selectedFrets` 对外可直接写，后续阶段很容易出现：
- 某一层直接塞入空集合
- 或者塞入 `0 / 13 / 99` 这类超出 `1...12` 的值
- 这会让“共享状态层先把约束收口”的阶段目标被破坏

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: TrainerPositionPromptConfiguration.selectedFrets
// 功能说明: 这一层在阶段 1 的设计目标里要求状态不变量内聚；
// 因此 selectedFrets 不能被外部任意写坏。
struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    var selectedFrets: Set<Int>
}
```

### 修改后

- `selectedFrets` 改成 `private(set)`
- 通过：
- `init(selectedFrets:)`
- `setSelectedFrets(_:)`
- `toggleFret(_:)`
- `toggled(fret:)`
- 统一修改

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TrainerDisplayState.swift
// 函数名/符号: selectedFrets, setSelectedFrets(_:), toggleFret(_:)
// 功能说明: 修改后外部只能通过配置对象提供的入口更新选中品位集合；
// 这样后续阶段即使跨文件接入，也不会绕开归一化和“至少保留一个”的约束。
struct TrainerPositionPromptConfiguration: Equatable, Sendable {
    private(set) var selectedFrets: Set<Int>

    mutating func setSelectedFrets(_ selectedFrets: Set<Int>) {
        self.selectedFrets = Self.normalizedSelectedFrets(selectedFrets)
    }

    mutating func toggleFret(_ fret: Int) {
        self = toggled(fret: fret)
    }
}
```

## 修改 4：同步计划文件中的阶段状态

### 修改前

- 阶段 1 已实际完成，但计划 frontmatter 仍然还是 `pending`

```yaml
# 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md
# 函数名/符号: frontmatter.todos.phase1-state.status
# 功能说明: 修改前计划文件尚未反映阶段 1 已完成；
# 不利于后续继续按阶段推进时快速对齐当前进度。
todos:
  - id: phase1-state
    content: 扩展 TrainerDisplayState，新增 positionPrompt 专属品位筛选配置与至少保留一个品位的归一化/切换辅助方法
    status: pending
```

### 修改后

- 仅将阶段 1 的状态同步为 `completed`
- 不提前更改后续阶段

```yaml
# 文件路径: .cursor/plans/position品位筛选_cb2e8023.plan.md
# 函数名/符号: frontmatter.todos.phase1-state.status
# 功能说明: 修改后计划文件与代码实际进度保持一致；
# 后续继续实施阶段 2 时可以直接以当前计划状态为准。
todos:
  - id: phase1-state
    content: 扩展 TrainerDisplayState，新增 positionPrompt 专属品位筛选配置与至少保留一个品位的归一化/切换辅助方法
    status: completed
```

## 最终结果

- `positionPrompt` 模式已经有了正式的 shared 品位筛选状态模型
- 默认可选品位被明确限定为 `1...12`
- 空集合与非法值在进入状态层时就会被归一化
- “最后一个已选品位不可取消”的规则已经在状态层落地
- 阶段 2 可以直接在设置面板里基于 `trainerDisplayState.positionPromptConfiguration` 做 12 格回显与事件接线
- 本轮修改后已检查 `TrainerDisplayState.swift` 的 lints，未发现新增错误

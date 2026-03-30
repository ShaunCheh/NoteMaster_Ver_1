# 20260330_165847_phase1_button_rows_transition_abstraction

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_165847`
- 记录范围：按钮步进动画方案的阶段 1，只把当前只服务 `B` 区 `scale snap` 的 shared 动画命名抽象成通用 `rows transition` 能力
- 本次目标：先完成 shared 层的命名抽象和兼容转发，为后续“wrapper 统一接线”和“按钮步进复用过渡动画”做准备；本阶段不改变当前 `B` 区动画行为，不改 iOS / macOS wrapper，不改按钮 reducer 语义
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `.cursor/plans/按钮步进动画_211eb374.plan.md`（计划文件不计入本次功能记录）

## 本次结论

- 修改前，当前显式吸附动画虽然已经能做“`rows` 从 `fromRows` 过渡到 `toRows`”
- 但命名仍然强绑定在：
- `scale`
- `snap`
- 这会让后续把同一套机制复用到 `A` 区按钮步进时，语义上变得别扭
- 修改后，shared 层先补齐了一层更通用的命名：
- `PianoRowsTransitionPlan`
- `animateRowsTransition(...)`
- `startRowsTransitionAnimation(...)`
- `cancelRowsTransitionAnimation(...)`
- `clearRowsTransitionPresentationOverride()`
- 同时，为了保证阶段 1 不动现有 `B` 区调用点，又保留了兼容层：
- `typealias PianoScaleSnapAnimationPlan = PianoRowsTransitionPlan`
- 旧的 `startScaleSnapAnimation(...)`
- 旧的 `cancelScaleSnapAnimation(...)`
- 旧的 `clearScaleSnapPresentationOverride()`
- 因此本阶段结束后：
- shared 内部已经具备更通用的抽象命名
- 当前 `B` 区吸附动画行为完全不变
- iOS / macOS wrapper 暂时也不需要同步修改

## 修改前的问题

- 修改前，动画计划类型和 layer API 全都写成“只服务 `scale snap`”的语义
- 例如：
- `PianoScaleSnapAnimationPlan`
- `.animateScaleSnap(...)`
- `startScaleSnapAnimation(...)`
- 但它们底层真正做的事情其实是：
- 接收一组 `fromRows`
- 接收一组 `toRows`
- 对受影响行做中间帧插值
- 让 layer 用这组中间帧 rows 重建 scene
- 也就是说，能力本身已经是通用的，绑定住的主要只是命名

## 修改 1：把 presentation plan 先抽象成通用 `rows transition`

### 修改前

- 修改前，计划类型直接叫 `PianoScaleSnapAnimationPlan`
- `PianoPresentationCommand` 里也只有 `.animateScaleSnap(...)`
- `PianoPresentationMath.rows(...)` 的参数类型同样写死为 `PianoScaleSnapAnimationPlan`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift
// 函数名/符号: PianoScaleSnapAnimationPlan, PianoPresentationCommand, PianoPresentationMath.rows(...)
// 功能说明: 修改前这套计划和命令命名仍然绑定在 scale snap 语义上。
struct PianoScaleSnapAnimationPlan: Equatable, Sendable {
    static let defaultDuration: TimeInterval = 0.12

    var fromRows: [PianoRowState]
    var toRows: [PianoRowState]
    var affectedRowIndices: [Int]
    var duration: TimeInterval

    var isNoOp: Bool {
        !hasConsistentRowCount || fromRows == toRows || affectedRowIndices.isEmpty
    }
}

enum PianoPresentationCommand: Equatable, Sendable {
    case animateScaleSnap(PianoScaleSnapAnimationPlan)
}

enum PianoPresentationMath {
    static func rows(
        for plan: PianoScaleSnapAnimationPlan,
        progress: CGFloat,
        configuration: PianoConfiguration
    ) -> [PianoRowState] {
        // ...
    }
}
```

### 修改后

- 修改后，先把通用名补出来：
- `PianoRowsTransitionPlan`
- `PianoPresentationCommand.animateRowsTransition(_:)`
- `rowsTransitionPlan`
- 同时保留 `typealias PianoScaleSnapAnimationPlan = PianoRowsTransitionPlan`
- 这样当前老调用点还能继续工作，后续新调用点则可以直接使用通用命名

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoPresentation.swift
// 函数名/符号: PianoRowsTransitionPlan, PianoPresentationCommand.animateRowsTransition(_:), PianoPresentationCommand.rowsTransitionPlan
// 功能说明: 修改后先把行过渡能力抽象成通用 rows transition 命名，同时保留旧的 scale snap 类型别名做兼容。
struct PianoRowsTransitionPlan: Equatable, Sendable {
    static let defaultDuration: TimeInterval = 0.12

    var fromRows: [PianoRowState]
    var toRows: [PianoRowState]
    var affectedRowIndices: [Int]
    var duration: TimeInterval

    var isNoOp: Bool {
        !hasConsistentRowCount || fromRows == toRows || affectedRowIndices.isEmpty
    }
}

typealias PianoScaleSnapAnimationPlan = PianoRowsTransitionPlan

enum PianoPresentationCommand: Equatable, Sendable {
    case animateScaleSnap(PianoRowsTransitionPlan)

    static func animateRowsTransition(
        _ plan: PianoRowsTransitionPlan
    ) -> PianoPresentationCommand {
        .animateScaleSnap(plan)
    }

    var rowsTransitionPlan: PianoRowsTransitionPlan? {
        switch self {
        case let .animateScaleSnap(plan):
            return plan
        }
    }
}

enum PianoPresentationMath {
    static func rows(
        for plan: PianoRowsTransitionPlan,
        progress: CGFloat,
        configuration: PianoConfiguration
    ) -> [PianoRowState] {
        // ...
    }
}
```

## 修改 2：reducer 改用新的通用命令入口构造过渡计划

### 修改前

- 修改前，`finalizeScaleDrag(...)` 里还是直接构造：
- `.animateScaleSnap(PianoScaleSnapAnimationPlan(...))`
- 这在功能上没问题，但仍旧把 reducer 的表达绑定在“scale snap”这个旧语义上

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: finalizeScaleDrag(_:state:configuration:finalRows:)
// 功能说明: 修改前 reducer 在 B 区结束时直接通过 animateScaleSnap + PianoScaleSnapAnimationPlan 构造过渡命令。
if snappedRows != finalRows {
    presentationCommand = .animateScaleSnap(
        PianoScaleSnapAnimationPlan(
            fromRows: finalRows,
            toRows: snappedRows,
            affectedRowIndices: interaction.affectedRowIndices
        )
    )
} else {
    presentationCommand = nil
}
```

### 修改后

- 修改后，reducer 改成通过新的通用入口来表达“行过渡”：
- `.animateRowsTransition(PianoRowsTransitionPlan(...))`
- 注意这里只是“构造方式”改成通用命名
- reducer 的行为本身没有改：
- 仍然是先保留 `finalRows`
- 仍然是给出一个过渡计划
- 仍然不直接提交 snapped rows

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: finalizeScaleDrag(_:state:configuration:finalRows:)
// 功能说明: 修改后 reducer 通过更通用的 animateRowsTransition + PianoRowsTransitionPlan 构造过渡命令，行为保持不变。
if snappedRows != finalRows {
    presentationCommand = .animateRowsTransition(
        PianoRowsTransitionPlan(
            fromRows: finalRows,
            toRows: snappedRows,
            affectedRowIndices: interaction.affectedRowIndices
        )
    )
} else {
    presentationCommand = nil
}
```

## 修改 3：把 keyboard layer 的内部运行时 API 切到通用命名，并保留旧接口转发

### 修改前

- 修改前，`PianoKeyboardLayer` 的内部运行时状态和方法名都带有明显的 `scale snap` 语义：
- `activeScaleSnapAnimation`
- `scaleSnapTimer`
- `startScaleSnapAnimation(...)`
- `cancelScaleSnapAnimation(...)`
- `clearScaleSnapPresentationOverride()`
- `materializedScaleSnapRows()`
- `scheduleScaleSnapTimer()`
- `invalidateScaleSnapTimer()`
- `updateScaleSnapAnimationFrame()`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: activeScaleSnapAnimation, scaleSnapTimer, startScaleSnapAnimation(_:completion:)
// 功能说明: 修改前 keyboard layer 的内部运行时命名全部绑定在 scale snap 语义上。
private var activeScaleSnapAnimation: PianoActiveScaleSnapAnimation?
private var scaleSnapTimer: Timer?

func startScaleSnapAnimation(
    _ plan: PianoScaleSnapAnimationPlan,
    completion: @escaping ([PianoRowState]) -> Void
) {
    guard !plan.isNoOp else {
        clearScaleSnapPresentationOverride()
        completion(plan.toRows)
        return
    }

    _ = cancelScaleSnapAnimation(materializeCurrentFrame: false)
    activeScaleSnapAnimation = PianoActiveScaleSnapAnimation(
        plan: plan,
        startedAt: CACurrentMediaTime(),
        completion: completion
    )
    presentationRowsOverride = plan.fromRows
    invalidateSublayersForCurrentState()
    scheduleScaleSnapTimer()
}
```

### 修改后

- 修改后，真正的内部实现切到了通用 `rows transition` 命名：
- `activeRowsTransitionAnimation`
- `rowsTransitionTimer`
- `startRowsTransitionAnimation(...)`
- `cancelRowsTransitionAnimation(...)`
- `clearRowsTransitionPresentationOverride()`
- `materializedRowsTransitionRows()`
- `scheduleRowsTransitionTimer()`
- `invalidateRowsTransitionTimer()`
- `updateRowsTransitionAnimationFrame()`
- 同时保留旧的 `scale snap` 方法作为一层兼容转发，这样当前 wrapper 完全不用改

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: activeRowsTransitionAnimation, rowsTransitionTimer, startRowsTransitionAnimation(_:completion:)
// 功能说明: 修改后 keyboard layer 内部真正运行的过渡动画 API 已切到通用 rows transition 命名。
private var activeRowsTransitionAnimation: PianoActiveRowsTransitionAnimation?
private var rowsTransitionTimer: Timer?

func startRowsTransitionAnimation(
    _ plan: PianoRowsTransitionPlan,
    completion: @escaping ([PianoRowState]) -> Void
) {
    guard !plan.isNoOp else {
        clearRowsTransitionPresentationOverride()
        completion(plan.toRows)
        return
    }

    _ = cancelRowsTransitionAnimation(materializeCurrentFrame: false)
    activeRowsTransitionAnimation = PianoActiveRowsTransitionAnimation(
        plan: plan,
        startedAt: CACurrentMediaTime(),
        completion: completion
    )
    presentationRowsOverride = plan.fromRows
    invalidateSublayersForCurrentState()
    scheduleRowsTransitionTimer()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名: startScaleSnapAnimation(_:completion:), cancelScaleSnapAnimation(materializeCurrentFrame:), clearScaleSnapPresentationOverride()
// 功能说明: 修改后旧的 scale snap API 保留为兼容转发壳，确保阶段 1 不需要改 wrapper。
func startScaleSnapAnimation(
    _ plan: PianoScaleSnapAnimationPlan,
    completion: @escaping ([PianoRowState]) -> Void
) {
    startRowsTransitionAnimation(plan, completion: completion)
}

@discardableResult
func cancelScaleSnapAnimation(
    materializeCurrentFrame: Bool
) -> [PianoRowState]? {
    cancelRowsTransitionAnimation(
        materializeCurrentFrame: materializeCurrentFrame
    )
}

func clearScaleSnapPresentationOverride() {
    clearRowsTransitionPresentationOverride()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名: materializedRowsTransitionRows(), scheduleRowsTransitionTimer(), invalidateRowsTransitionTimer(), updateRowsTransitionAnimationFrame()
// 功能说明: 修改后定时驱动和当前帧物化逻辑也同步切到通用 rows transition 命名。
func materializedRowsTransitionRows() -> [PianoRowState]? {
    guard let activeRowsTransitionAnimation else {
        return nil
    }

    let duration = max(activeRowsTransitionAnimation.plan.duration, 0.001)
    let progress = CGFloat(
        (CACurrentMediaTime() - activeRowsTransitionAnimation.startedAt) / duration
    )
    return PianoPresentationMath.rows(
        for: activeRowsTransitionAnimation.plan,
        progress: progress,
        configuration: configuration
    )
}

func scheduleRowsTransitionTimer() {
    invalidateRowsTransitionTimer()
    let timer = Timer(
        timeInterval: 1.0 / 60.0,
        repeats: true
    ) { [weak self] _ in
        self?.updateRowsTransitionAnimationFrame()
    }
    rowsTransitionTimer = timer
    RunLoop.main.add(timer, forMode: .common)
}

func updateRowsTransitionAnimationFrame() {
    guard let activeRowsTransitionAnimation else {
        invalidateRowsTransitionTimer()
        return
    }

    let duration = max(activeRowsTransitionAnimation.plan.duration, 0.001)
    let progress = CGFloat(
        (CACurrentMediaTime() - activeRowsTransitionAnimation.startedAt) / duration
    )
    presentationRowsOverride = PianoPresentationMath.rows(
        for: activeRowsTransitionAnimation.plan,
        progress: progress,
        configuration: configuration
    )
    invalidateSublayersForCurrentState()
    // ... 完成后回调最终 rows
}
```

## 本次没有改动的部分

- iOS / macOS wrapper 没改
- 因为阶段 1 的目标就是让 shared 先具备通用命名，同时保留旧接口兼容，不要求 platform 立刻跟进
- `PianoValidation.swift` 也没改
- 因为这一步没有改动画语义，也没有改 reducer / layer 的功能性输出，只是先抽象命名和内部实现入口
- `PianoSceneBuilder.swift` 和 `PianoRowLayer.swift` 同样没改
- 因为本阶段仍然沿用“中间帧 rows -> scene -> row layer”这条既有渲染链

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: applyPresentationCommand(_:), finalizeScaleSnapAnimation(with:)
// 功能说明: 本阶段未修改；wrapper 继续使用旧的 scale snap 兼容接口，因此 B 区行为保持不变。
(未修改，本次记录不重复展开代码)
```

## 验证情况

- `ReadLints`：本次修改相关文件无新增诊断
- `xcrun swiftc -typecheck NoteMaster_Ver_1/**/*.swift`：通过
- 本次全量 typecheck 仍有 2 条仓库原有 warning：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 本阶段未做手工 UI 回归；当前验证以静态编译通过和“现有 `B` 区 wrapper 无需修改仍可编译”这两点为主

## 对后续阶段的影响

- 现在阶段 2 可以直接把 iOS / macOS wrapper 的消费命名统一到 `rows transition`
- 阶段 3 再让按钮步进复用同一套过渡计划时，也不需要再倒回来改 shared 核心命名
- 由于阶段 1 保留了旧接口兼容层，所以后续阶段可以分步推进，而不是一次性大范围联动改名

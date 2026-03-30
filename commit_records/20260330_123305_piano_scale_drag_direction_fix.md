# 20260330_123305_piano_scale_drag_direction_fix

- 时间戳来源：系统命令 `date "+%Y%m%d_%H%M%S"`，结果为 `20260330_123305`
- 记录范围：修正钢琴键盘 `B` 区刻度条在拖动时响应方向与光标/手指移动方向相反的问题
- 本次目标：只修正 `scaleDrag` 对内部 `offsetX` 的映射方向，并同步更新验证夹具预期；不改几何布局、不改平台输入桥接、不改 `A/C` 区交互语义
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoScene.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`

## 本次结论

- 修改前，`B` 区拖动把指针的 `deltaX` 直接加到内部 `offsetX`
- 但当前几何实现里，键位渲染使用的是 `originX ... - rowState.offsetX`
- 这意味着：
- 手指/光标向右拖时，`offsetX` 变大
- 键盘内容反而会向左移动
- 用户看到的结果就是“刻度条响应方向反了”
- 修改后，`scaleDrag` 改为把 `deltaX` 反向映射到内部 `offsetX`
- 这样：
- 右拖时内部 `offsetX` 减小
- 键盘内容向右移动
- 左拖时内部 `offsetX` 增大
- 键盘内容向左移动
- 视觉效果恢复为和手指/光标同向的直接操控语义

## 修改前的问题

- 这次问题不是 hitTest 错了，也不是 `A/B/C` 区域关系错了
- 根因在于 reducer 对 `scaleDrag` 的位移符号处理和当前 `offsetX` 的几何含义不一致
- 当前实现中，`B` 区拖动只改 `offsetX`
- 而 `offsetX` 在几何里的语义是“起始音左边缘相对视图左边缘再向左偏移多少”
- 所以只要把指针位移直接做 `+ deltaX`，就会和直接操控的视觉语义相反

## 修改 1：修正 `scaleDrag` 对内部 `offsetX` 的更新方向

### 修改前

- 修改前，`applyScaleDrag(...)` 直接把 `deltaX` 加到 `initialOffsetsX`
- 这会把“指针右移”解释成“内部左边缘偏移增加”
- 最终表现为内容向左滚动

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: applyScaleDrag(rows:interaction:currentLocationInView:)
// 功能说明: 修改前把指针位移直接累加到 offsetX，导致 B 区拖动的视觉方向与手指/光标方向相反。
static func applyScaleDrag(
    rows: [PianoRowState],
    interaction: PianoScaleDragInteraction,
    currentLocationInView: CGPoint
) -> [PianoRowState] {
    let deltaX = currentLocationInView.x - interaction.beganLocationInView.x
    var nextRows = rows

    for (offsetIndex, rowIndex) in interaction.affectedRowIndices.enumerated() {
        guard nextRows.indices.contains(rowIndex),
              interaction.initialOffsetsX.indices.contains(offsetIndex) else {
            continue
        }

        nextRows[rowIndex].offsetX = interaction.initialOffsetsX[offsetIndex] + deltaX
    }

    return nextRows
}
```

### 修改后

- 修改后，`applyScaleDrag(...)` 保留原有 `deltaX` 计算方式
- 但真正写回 `offsetX` 时改成 `initialOffset - deltaX`
- 这样 reducer 的拖动语义就和现有几何公式对齐了
- 同时补了一段注释，避免后续再次把这个符号改回去

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift
// 函数名: applyScaleDrag(rows:interaction:currentLocationInView:)
// 功能说明: 修改后按直接操控语义更新 offsetX；右拖时内容跟着右移，因此内部 left-edge offset 需要减小。
static func applyScaleDrag(
    rows: [PianoRowState],
    interaction: PianoScaleDragInteraction,
    currentLocationInView: CGPoint
) -> [PianoRowState] {
    let deltaX = currentLocationInView.x - interaction.beganLocationInView.x
    var nextRows = rows

    for (offsetIndex, rowIndex) in interaction.affectedRowIndices.enumerated() {
        guard nextRows.indices.contains(rowIndex),
              interaction.initialOffsetsX.indices.contains(offsetIndex) else {
            continue
        }

        // Pointer drag uses direct-manipulation semantics: dragging right moves the
        // keyboard content right, which means the internal left-edge offset decreases.
        nextRows[rowIndex].offsetX = interaction.initialOffsetsX[offsetIndex] - deltaX
    }

    return nextRows
}
```

## 修改 2：同步更新 `scaleDrag` 生命周期夹具的方向预期

### 修改前

- 修改前的验证夹具是按旧符号写的
- 它默认认为：
- 从 `x = 60` 拖到 `x = 100`
- `offsetX` 应该变成 `40`
- 吸附结束后，第一行会落到 `D4`
- 第二行会落到 `D3`
- 这些预期和“方向反了”的旧实现是一致的，但和用户想要的直接操控语义不一致

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateScaleDragLifecycle()
// 功能说明: 修改前的 fixture 默认把“右拖”理解成 offsetX 正向增长，因此吸附结果会前移到 D4 / D3。
let movedReduction = PianoInteractionReducer.reduce(
    state: beganReduction.nextState,
    rawEvent: PianoRawEvent(
        phase: .moved,
        locationInView: CGPoint(x: 100, y: 10)
    ),
    hitResult: PianoHitResult(
        phase: .moved,
        locationInView: CGPoint(x: 100, y: 10),
        rowIndex: 0,
        zone: .scale,
        note: NotePitch(pitchClass: .d, octave: 4),
        isInsideActiveZone: true
    ),
    configuration: configuration
)
if movedReduction.nextState.rows[0].offsetX != 40
    || movedReduction.nextState.rows[1].offsetX != 40 {
    issues.append(issue(fixtureName, "scale moved 后应按 deltaX 同步更新受影响行 offsetX。"))
}

let endedReduction = PianoInteractionReducer.reduce(
    state: movedReduction.nextState,
    rawEvent: PianoRawEvent(
        phase: .ended,
        locationInView: CGPoint(x: 100, y: 10)
    ),
    hitResult: PianoHitResult(
        phase: .ended,
        locationInView: CGPoint(x: 100, y: 10),
        rowIndex: 0,
        zone: .scale,
        note: NotePitch(pitchClass: .d, octave: 4),
        isInsideActiveZone: true
    ),
    configuration: configuration
)
if endedReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .d, octave: 4)
    || endedReduction.nextState.rows[0].offsetX != 0 {
    issues.append(issue(fixtureName, "snapEnabled 开启时，第一行结束后应归一化到 D4 且 offsetX 为 0。"))
}
if endedReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .d, octave: 3)
    || endedReduction.nextState.rows[1].offsetX != 0 {
    issues.append(issue(fixtureName, "cascade 结束时第二行也应归一化到 D3。"))
}
```

### 修改后

- 修改后，fixture 明确切换到新的直接操控预期：
- 同样从 `x = 60` 拖到 `x = 100`
- `offsetX` 应为 `-40`
- 结束吸附后，第一行从 `C4` 向更早的音吸附到 `B3`
- 第二行同步吸附到 `B2`
- 这样 validation 会和新的拖动方向保持一致

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: validateScaleDragLifecycle()
// 功能说明: 修改后 fixture 以“右拖即内容右移”的语义校验 scaleDrag，因此 offsetX 预期变为负值，吸附目标改为 B3 / B2。
let movedReduction = PianoInteractionReducer.reduce(
    state: beganReduction.nextState,
    rawEvent: PianoRawEvent(
        phase: .moved,
        locationInView: CGPoint(x: 100, y: 10)
    ),
    hitResult: PianoHitResult(
        phase: .moved,
        locationInView: CGPoint(x: 100, y: 10),
        rowIndex: 0,
        zone: .scale,
        note: NotePitch(pitchClass: .d, octave: 4),
        isInsideActiveZone: true
    ),
    configuration: configuration
)
if movedReduction.nextState.rows[0].offsetX != -40
    || movedReduction.nextState.rows[1].offsetX != -40 {
    issues.append(issue(fixtureName, "scale moved 后应按指针位移反向更新受影响行 offsetX。"))
}

let endedReduction = PianoInteractionReducer.reduce(
    state: movedReduction.nextState,
    rawEvent: PianoRawEvent(
        phase: .ended,
        locationInView: CGPoint(x: 100, y: 10)
    ),
    hitResult: PianoHitResult(
        phase: .ended,
        locationInView: CGPoint(x: 100, y: 10),
        rowIndex: 0,
        zone: .scale,
        note: NotePitch(pitchClass: .d, octave: 4),
        isInsideActiveZone: true
    ),
    configuration: configuration
)
if endedReduction.nextState.rows[0].startNote != NotePitch(pitchClass: .b, octave: 3)
    || endedReduction.nextState.rows[0].offsetX != 0 {
    issues.append(issue(fixtureName, "snapEnabled 开启时，第一行右拖结束后应归一化到 B3 且 offsetX 为 0。"))
}
if endedReduction.nextState.rows[1].startNote != NotePitch(pitchClass: .b, octave: 2)
    || endedReduction.nextState.rows[1].offsetX != 0 {
    issues.append(issue(fixtureName, "cascade 结束时第二行也应同步归一化到 B2。"))
}
```

## 本次没有改动的部分

- 没有改 `PianoGeometry.keyRect(...)` 的几何公式
- 没有改 `PianoSceneBuilder` 的 `A/B/C` 区域布局
- 没有改 `iOSPianoKeyboardView` 或 `macOSPianoKeyboardView` 的原始输入转发
- 也就是说，本次不是重新定义拖动模型，而是让 reducer 的符号处理和既有几何/渲染语义重新对齐

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift
// 函数名: keyRect(for:rowState:keysRect:configuration:)
// 功能说明: 本次未改；当前几何仍通过 “noteLeadingX(...) - rowState.offsetX” 决定键位的可视位置。
(未修改，本次记录不重复展开代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift
// 函数名/符号: handleRawEvent(...)
// 功能说明: 本次未改；iOS 端仍然只负责把原始 touch 转成 PianoRawEvent，再交给 Shared reducer。
(未修改，本次记录不重复展开代码)
```

## 验证情况

- `ReadLints`：`PianoInteractionReducer.swift`、`PianoValidation.swift` 无新增诊断
- `xcrun swiftc -typecheck`：已通过，覆盖以下文件：
- `NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteraction.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoScene.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoSceneBuilder.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoGeometry.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoInteractionReducer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未做双平台实际 UI 拖动的手工回归；当前验证仍以静态检查和 Shared 夹具同步为主

## 对后续阶段的影响

- 后续如果再补 `PianoValidationRunner` 的稳定命令行执行链路，这个方向修正已经有对应 fixture 兜底
- 若后面要继续优化 `B` 区交互体验，例如：
- 惯性滚动
- 更细粒度吸附策略
- 不同平台对 mouse/touch 的差异处理
- 都应继续遵循这次确定下来的“内容跟手”的直接操控语义，而不是恢复到旧的反向映射

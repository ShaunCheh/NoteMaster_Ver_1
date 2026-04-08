# 20260408_091749_phase3_multi_preview_rendering_projection

## 记录范围

本记录只覆盖刚刚这一轮“多指复音计划 phase3：升级键盘渲染层，支持每行多活动 preview 高亮与多路交互投影”的实际代码修改。

这次修改的目标不是把 iOS / macOS 输入宿主直接升级成真正的多 pointer 采集，也不是把播放后端直接升级成复音 mixer；这一步只处理渲染投影层本身：

- 让每一行从 `activePreviews` 聚合出完整高亮音集合，而不是继续依赖单值 `preview`
- 让 `rows transition` 的 `presentation override` 不再把多 preview 状态压回单值
- 让白键 / 黑键的高亮判断从单音比较变成集合包含
- 增补自动化夹具，把同一行多音、跨行多音和 transition 期间不丢高亮的边界固定下来

本记录参考了当前工作区的 `git diff` 与文件现状，但 **不包含原始 diff**。

当前工作区里，与本轮 phase3 直接相关的代码文件有 5 个：

- `NoteMaster_Ver_1/Shared/Piano/PianoState.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`

当前工作区另外还存在 `@.cursor/plans/多指复音计划_27c48b8b.plan.md` 的变更，但它不是本轮 phase3 代码实现的一部分，因此本记录不把它计入“修改前 / 修改后”范围。

---

## 1. 给组件状态补上“按行聚合 preview”入口：`PianoState.swift`

### 1.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名: preview(for:) / hasExclusiveControlInteraction(ownedBy:)
// 功能说明: 修改前共享状态只提供按 pointer 查询 preview 的入口；渲染层如果要画某一行的全部活动音，只能继续依赖兼容单值 preview。
func preview(for pointerID: PianoPointerID) -> PianoPreviewState? {
    preview(for: pointerID.previewID)
}

func hasExclusiveControlInteraction(ownedBy pointerID: PianoPointerID) -> Bool {
    activeInteractionsByPointer.contains { entry in
        entry.key != pointerID && entry.value.isExclusiveControlInteraction
    }
}
```

### 1.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoState.swift
// 函数名: previews(forRowIndex:) / previewedNotes(forRowIndex:)
// 功能说明: 修改后新增按行聚合 helper，渲染层可以直接拿到同一行全部活动 preview，再映射成去重后的高亮音集合。
func previews(forRowIndex rowIndex: Int) -> [PianoPreviewState] {
    activePreviews.values
        .filter { $0.rowIndex == rowIndex }
        .sorted { lhs, rhs in lhs.previewID.rawValue < rhs.previewID.rawValue }
}

func previewedNotes(forRowIndex rowIndex: Int) -> Set<NotePitch> {
    Set(previews(forRowIndex: rowIndex).map(\.note))
}
```

---

## 2. 修正根 layer 的状态投影，不再在动画期压回单值 preview：`PianoKeyboardLayer.swift`

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名: resolvedRenderState() / renderState(for:state:)
// 功能说明: 修改前 presentationRowsOverride 生效时，根 layer 会重新走 preview / activeInteraction 兼容单值口；这会把 phase2 的多 preview 状态压扁，只保留一个高亮音。
func resolvedRenderState() -> PianoComponentState {
    guard let presentationRowsOverride else {
        return state
    }

    return PianoComponentState(
        rows: presentationRowsOverride,
        preview: state.preview,
        activeInteraction: state.activeInteraction
    )
}

func renderState(
    for rowIndex: Int,
    state renderState: PianoComponentState
) -> PianoRowRenderState {
    let previewedNote = renderState.preview?.rowIndex == rowIndex
        ? renderState.preview?.note
        : nil

    switch renderState.activeInteraction {
    // ... 这里省略了与本次变更无关的控制区高亮分支 ...
    }

    return PianoRowRenderState(
        referenceNote: referenceNote,
        previewedNote: previewedNote,
        activeButtonDirection: activeButtonDirection,
        isButtonTrackingInside: isButtonTrackingInside,
        isScaleActive: isScaleActive
    )
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名: resolvedRenderState() / renderState(for:state:)
// 功能说明: 修改后 rows transition 只替换 rows 本身，activePreviews / activeInteractionsByPointer 原样保留；每一行的 renderState 直接按行聚合 previewedNotes，并只读取独占控制交互的视觉状态。
func resolvedRenderState() -> PianoComponentState {
    guard let presentationRowsOverride else {
        return state
    }

    return PianoComponentState(
        rows: presentationRowsOverride,
        activePreviews: state.activePreviews,
        activeInteractionsByPointer: state.activeInteractionsByPointer
    )
}

func renderState(
    for rowIndex: Int,
    state renderState: PianoComponentState
) -> PianoRowRenderState {
    let previewedNotes = renderState.previewedNotes(forRowIndex: rowIndex)
    let referenceNote = renderState.rowState(at: rowIndex)?.startNote

    switch renderState.activeExclusiveControlInteraction {
    // ... 这里省略了与本次变更无关的控制区高亮分支 ...
    }

    return PianoRowRenderState(
        referenceNote: referenceNote,
        previewedNotes: previewedNotes,
        activeButtonDirection: activeButtonDirection,
        isButtonTrackingInside: isButtonTrackingInside,
        isScaleActive: isScaleActive
    )
}
```

---

## 3. 把按键高亮从“单音比较”升级为“集合包含”：`PianoRowLayer.swift`

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: PianoRowRenderState / drawWhiteKeys(in:) / drawBlackKeys(in:)
// 功能说明: 修改前每一行最多只能持有一个 `previewedNote`，白键和黑键的高亮判断都是 `== one note`。
struct PianoRowRenderState: Equatable, Sendable {
    static let empty = PianoRowRenderState(
        referenceNote: nil,
        previewedNote: nil,
        activeButtonDirection: nil,
        isButtonTrackingInside: false,
        isScaleActive: false
    )

    var referenceNote: NotePitch?
    var previewedNote: NotePitch?
    var activeButtonDirection: PianoStepDirection?
    var isButtonTrackingInside: Bool
    var isScaleActive: Bool
}

let isPreviewed = renderState.previewedNote == whiteKey.note

let fillColor = renderState.previewedNote == blackKey.note
    ? PianoLayerPalette.previewBlackKeyFill
    : PianoLayerPalette.blackKeyFill
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名: PianoRowRenderState / drawWhiteKeys(in:) / drawBlackKeys(in:)
// 功能说明: 修改后每一行持有 `Set<NotePitch>`，白键和黑键都按集合包含关系判断高亮，因此同一行多个活动音可以同时显示。
struct PianoRowRenderState: Equatable, Sendable {
    static let empty = PianoRowRenderState(
        referenceNote: nil,
        previewedNotes: [],
        activeButtonDirection: nil,
        isButtonTrackingInside: false,
        isScaleActive: false
    )

    var referenceNote: NotePitch?
    var previewedNotes: Set<NotePitch>
    var activeButtonDirection: PianoStepDirection?
    var isButtonTrackingInside: Bool
    var isScaleActive: Bool
}

let isPreviewed = renderState.previewedNotes.contains(whiteKey.note)

let isPreviewed = renderState.previewedNotes.contains(blackKey.note)
let fillColor = isPreviewed
    ? PianoLayerPalette.previewBlackKeyFill
    : PianoLayerPalette.blackKeyFill
```

---

## 4. 更新渲染夹具，让回归测试真正覆盖“多高亮”场景：`PianoValidationKeyboardLayer.swift`

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationKeyboardLayer.swift
// 函数名: validateKeyboardLayerRoutesVisualStateToRows()
// 功能说明: 修改前这个夹具仍按单 preview 模型构造状态，只验证“第 1 行有一个 preview 音”，没有覆盖同一行多音和清理旧高亮的边界。
let buttonPreviewState = PianoComponentState(
    rows: [
        PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4)),
        PianoRowState(startNote: NotePitch(pitchClass: .f, octave: 3))
    ],
    preview: PianoPreviewState(
        rowIndex: 1,
        note: NotePitch(pitchClass: .g, octave: 3)
    ),
    activeInteraction: .buttonPressed(
        PianoButtonPressInteraction(
            rowIndex: 0,
            direction: .right,
            movementScope: .rowOnly,
            isTrackingInsideButton: true
        )
    )
)

if rowLayers[0].renderState.previewedNote != nil {
    issues.append(issue(fixtureName, "第 0 行不应错误继承其他行的 preview。"))
}
if rowLayers[1].renderState.previewedNote != NotePitch(pitchClass: .g, octave: 3) {
    issues.append(issue(fixtureName, "第 1 行应接收到自身的 preview 音。"))
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationKeyboardLayer.swift
// 函数名: validateKeyboardLayerRoutesVisualStateToRows()
// 功能说明: 修改后夹具先构造跨行 + 同行多 preview，再切到 buttonPressed / scaleDrag，验证每行只投影自己的高亮集合，且切换到控制交互后旧 preview 不会残留。
let previewRow0 = NotePitch(pitchClass: .c, octave: 4)
let previewRow1A = NotePitch(pitchClass: .g, octave: 3)
let previewRow1B = NotePitch(pitchClass: .a, octave: 3)
let previewState = PianoComponentState(
    rows: [
        PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4)),
        PianoRowState(startNote: NotePitch(pitchClass: .f, octave: 3))
    ],
    activePreviews: [
        PianoPreviewID(rawValue: 101): PianoPreviewState(
            previewID: PianoPreviewID(rawValue: 101),
            rowIndex: 0,
            note: previewRow0
        ),
        PianoPreviewID(rawValue: 102): PianoPreviewState(
            previewID: PianoPreviewID(rawValue: 102),
            rowIndex: 1,
            note: previewRow1A
        ),
        PianoPreviewID(rawValue: 103): PianoPreviewState(
            previewID: PianoPreviewID(rawValue: 103),
            rowIndex: 1,
            note: previewRow1B
        )
    ]
)

if rowLayers[0].renderState.previewedNotes != Set([previewRow0]) {
    issues.append(issue(fixtureName, "第 0 行应只投影自身的 preview 音集合。"))
}
if rowLayers[1].renderState.previewedNotes != Set([previewRow1A, previewRow1B]) {
    issues.append(issue(fixtureName, "第 1 行应同时保留同一行的多个 preview 音。"))
}
if !rowLayers[1].renderState.previewedNotes.isEmpty {
    issues.append(issue(fixtureName, "清空 preview 后，第 1 行不应残留其他 pointer 的旧高亮。"))
}
```

### 4.3 新增 transition 期间不丢多 preview 的夹具

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationKeyboardLayer.swift
// 函数名: validateKeyboardLayerPreservesMultiPreviewDuringRowsTransition()
// 功能说明: 修改后新增专门夹具，锁住 rows transition presentation override 生效期间，多 preview 仍按原行正确投影，不会被压回单值或直接丢失。
static func validateKeyboardLayerPreservesMultiPreviewDuringRowsTransition() -> [PianoValidationIssue] {
    let fixtureName = "keyboard_layer_preserves_multi_preview_during_rows_transition"
    // ... 这里省略了状态与 transitionPlan 的构造 ...
    layer.startRowsTransitionAnimation(transitionPlan) { _ in }
    let rowLayers = (layer.sublayers ?? []).compactMap { $0 as? PianoRowLayer }

    if rowLayers.indices.contains(0),
        rowLayers[0].renderState.previewedNotes != Set([row0Preview]) {
        issues.append(issue(fixtureName, "rows transition presentation override 生效时，第 0 行 preview 集合不应被压回单值。"))
    }
    if rowLayers.indices.contains(1),
        rowLayers[1].renderState.previewedNotes != Set([row1PreviewA, row1PreviewB]) {
        issues.append(issue(fixtureName, "rows transition presentation override 生效时，第 1 行多 preview 高亮不应丢失。"))
    }

    _ = layer.cancelRowsTransitionAnimation(materializeCurrentFrame: false)
    return issues
}
```

---

## 5. 把新增夹具接入总验证入口与手工清单：`PianoValidation.swift`

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改前总验证入口只覆盖基础 keyboard layer 路由，没有把“transition 期间保留多 preview”纳入自动化，也没有把多高亮回归加入手工清单。
PianoValidationFixture(
    name: "keyboard_layer_routes_visual_state_to_rows",
    validate: validateKeyboardLayerRoutesVisualStateToRows
),
PianoValidationFixture(
    name: "keyboard_layer_flip_normalization_preserves_top_left_layout",
    validate: validateKeyboardLayerFlipNormalization
)

"确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。",
"确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后把 phase3 的新夹具纳入自动化入口，并补充手工验证项，明确要求检查同一行 / 跨行多音的同时高亮与快速交替稳定性。
PianoValidationFixture(
    name: "keyboard_layer_routes_visual_state_to_rows",
    validate: validateKeyboardLayerRoutesVisualStateToRows
),
PianoValidationFixture(
    name: "keyboard_layer_preserves_multi_preview_during_rows_transition",
    validate: validateKeyboardLayerPreservesMultiPreviewDuringRowsTransition
),
PianoValidationFixture(
    name: "keyboard_layer_flip_normalization_preserves_top_left_layout",
    validate: validateKeyboardLayerFlipNormalization
)

"确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。",
"确认同一行两个音、跨行两个音可同时高亮；快速交替两音时不会只剩一个稳定高亮。",
"确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
```

---

## 6. 验证结果

- 对 `PianoState.swift`、`PianoKeyboardLayer.swift`、`PianoRowLayer.swift`、`PianoValidationKeyboardLayer.swift`、`PianoValidation.swift` 执行了诊断检查，未发现新增 linter 问题。
- 已顺序执行 iOS 与 macOS 构建回归，均通过：
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' build`
  - `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination 'platform=macOS' build`

# 20260330_112720_phase4_piano_layer_rendering_stack

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260330_112720`
- 记录范围：实施“钢琴键盘组件”计划的阶段 4，只落 `Shared/Piano` 的最少 layer 绘制栈与对应 validation
- 本次目标：在不接入 `iOS/macOS` 平台视图的前提下，先把钢琴组件的渲染层落成“根 layer + 每行一个 row layer”，并补齐最小自动化检查
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Shared/Piano/PianoScene.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `iOSPianoKeyboardView` / `macOSPianoKeyboardView`
- `iOSViewController.swift` / `macOSViewController.swift`
- `iOSAppDelegate.swift` / `macOSAppDelegate.swift`

## 本次结论

- 修改前，`Shared/Piano` 已经有状态、几何、场景和 reducer，但还没有真正的钢琴 layer 绘制栈
- 修改后，阶段 4 已落成三块核心能力：
- `PianoScene.RowScene.localizedToRowBounds()`：把 Shared 场景中的绝对坐标转成单行 layer 可直接绘制的局部坐标
- `PianoKeyboardLayer`：负责维护根 layer、按行增减 `PianoRowLayer`、同步 scene/state，并统一关闭隐式动画
- `PianoRowLayer`：一次性绘制单行的 `A/B/C` 区，包含按钮、自然音刻度、参考线、白键黑键和 preview/drag/button 高亮
- 同时，`PianoValidation` 已补充阶段 4 的 layer 数量与视觉状态路由夹具，防止后续改动把“按行拆层”的约束弄丢

## 修改前总体现状

- 修改前，`Shared/Piano` 能解决“怎么布局、怎么命中、交互状态怎么推进”
- 但还不能解决：
- 如何把一行钢琴真实画出来
- 根 layer 如何按 `rows.count` 管理子 layer 数量
- `preview`、`buttonPressed`、`scaleDrag` 这些状态如何映射成视觉高亮
- 如何确保阶段 4 继续遵守“少 layer、无隐式动画”的约束

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前 Shared/Piano 还没有钢琴根 layer，无法把 scene/state 投影成实际的 CALayer 树。
(无代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前也没有单行绘制 layer，A/B/C 区按钮、刻度、琴键与高亮都还只是计划中的绘制责任。
(无代码)
```

## 修改 1：给 `PianoScene.RowScene` 补局部坐标化能力

### 修改前

- 修改前，`RowScene` 只保存 scene builder 产出的绝对坐标
- 这意味着后续如果把某一行交给独立的 `PianoRowLayer` 绘制，就还需要在 layer 内自己做坐标平移
- 这种做法会让 row layer 的绘制入口掺杂额外的坐标换算，不利于保持单行绘制职责清晰

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoScene.swift
// 函数名/符号: PianoScene.RowScene.localizedToRowBounds()
// 功能说明: 修改前不存在；RowScene 只有 noteRect/scaleMarker 查询，没有“转成本地坐标版本”的能力。
(无代码)
```

### 修改后

- 新增 `RowScene.empty`，方便 `PianoRowLayer` 在无场景时保持稳定默认值
- 新增 `localizedToRowBounds()`，把 `frame`、`A/B/C` 区矩形、白键、黑键和刻度点都整体平移到单行局部坐标
- 这样 `PianoKeyboardLayer` 只要把局部化后的 `RowScene` 交给 `PianoRowLayer`，后者就能直接按自身 `bounds` 绘制

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoScene.swift
// 函数名/符号: PianoScene.RowScene.empty, PianoScene.RowScene.localizedToRowBounds()
// 功能说明: 为单行绘制 layer 提供稳定空场景，并把 Shared 场景里的绝对坐标收口成 row layer 可直接使用的局部坐标。
struct PianoScene: Equatable, Sendable {
    struct RowScene: Equatable, Sendable {
        static let empty = RowScene(
            rowIndex: 0,
            frame: .null,
            controlStripRect: .null,
            buttonLeftRect: .null,
            buttonRightRect: .null,
            scaleRect: .null,
            keysRect: .null,
            whiteKeys: [],
            blackKeys: [],
            scaleMarkers: []
        )

        func localizedToRowBounds() -> RowScene {
            guard !frame.isNull else {
                return self
            }

            let dx = -frame.minX
            let dy = -frame.minY

            return RowScene(
                rowIndex: rowIndex,
                frame: CGRect(origin: .zero, size: frame.size),
                controlStripRect: controlStripRect.offsetBy(dx: dx, dy: dy),
                buttonLeftRect: buttonLeftRect.offsetBy(dx: dx, dy: dy),
                buttonRightRect: buttonRightRect.offsetBy(dx: dx, dy: dy),
                scaleRect: scaleRect.offsetBy(dx: dx, dy: dy),
                keysRect: keysRect.offsetBy(dx: dx, dy: dy),
                whiteKeys: whiteKeys.map { key in
                    WhiteKey(
                        note: key.note,
                        rect: key.rect.offsetBy(dx: dx, dy: dy)
                    )
                },
                blackKeys: blackKeys.map { key in
                    BlackKey(
                        note: key.note,
                        rect: key.rect.offsetBy(dx: dx, dy: dy)
                    )
                },
                scaleMarkers: scaleMarkers.map { marker in
                    ScaleMarker(
                        note: marker.note,
                        x: marker.x + dx,
                        labelText: marker.labelText
                    )
                }
            )
        }
    }
}
```

## 修改 2：新增 `PianoKeyboardLayer` 作为根绘制层

### 修改前

- 修改前没有钢琴根 layer
- 因而也没有统一入口去做：
- `configuration/state/contentsScale` 变化时的 scene 重建
- `rows.count` 对应的 row layer 增减
- `CATransaction.setDisableActions(true)` 的无隐式动画同步

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: synchronizeSublayerState(), ensureRowLayerCount(_:)
// 功能说明: 修改前文件不存在，因此也没有“根 layer + 每行一个 row layer”的同步逻辑。
(无代码)
```

### 修改后

- 新增 `PianoKeyboardLayer`
- `configuration`、`state`、`contentsScale` 变化时统一触发 `invalidateSublayersForCurrentState()`
- `synchronizeSublayerState()` 内部用 `PianoSceneBuilder` 重建当前 scene
- `ensureRowLayerCount(_:)` 把直接子 layer 数量严格约束为 `scene.rows.count`
- `renderState(for:)` 把 Shared 的 `preview`、`buttonPressed`、`scaleDrag` 状态映射为单行绘制层需要的视觉状态
- 所有 sublayer frame/state 的同步都包在 `performWithoutImplicitAnimations` 里，阶段 4 就先把“无隐式动画”这条约束钉死

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: PianoKeyboardLayer.synchronizeSublayerState(), renderState(for:), ensureRowLayerCount(_:)
// 功能说明: 用一个根 layer 管理整张钢琴的行级绘制层，负责 scene 同步、视觉状态路由和最少 sublayer 数量控制。
final class PianoKeyboardLayer: CALayer {
    var configuration: PianoConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var state: PianoComponentState = .empty {
        didSet {
            guard oldValue != state else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    private var rowLayers: [PianoRowLayer] = []

    func synchronizeSublayerState() {
        let scene = PianoSceneBuilder(
            configuration: configuration,
            state: state
        ).makeScene(bounds: bounds)

        performWithoutImplicitAnimations {
            ensureRowLayerCount(scene.rows.count)

            for (index, absoluteRowScene) in scene.rows.enumerated() {
                let rowLayer = rowLayers[index]
                rowLayer.frame = absoluteRowScene.frame
                rowLayer.configuration = configuration
                rowLayer.scene = absoluteRowScene.localizedToRowBounds()
                rowLayer.renderState = renderState(for: absoluteRowScene.rowIndex)
                rowLayer.contentsScale = contentsScale
            }
        }
    }

    func renderState(for rowIndex: Int) -> PianoRowRenderState {
        let previewedNote = state.preview?.rowIndex == rowIndex
            ? state.preview?.note
            : nil
        let referenceNote = state.rowState(at: rowIndex)?.startNote

        switch state.activeInteraction {
        case let .buttonPressed(interaction):
            return PianoRowRenderState(
                referenceNote: referenceNote,
                previewedNote: previewedNote,
                activeButtonDirection: interaction.rowIndex == rowIndex ? interaction.direction : nil,
                isButtonTrackingInside: interaction.rowIndex == rowIndex ? interaction.isButtonTrackingInside : false,
                isScaleActive: false
            )
        case let .scaleDrag(interaction):
            return PianoRowRenderState(
                referenceNote: referenceNote,
                previewedNote: previewedNote,
                activeButtonDirection: nil,
                isButtonTrackingInside: false,
                isScaleActive: interaction.affectedRowIndices.contains(rowIndex)
            )
        case .keyGlissando, .none:
            return PianoRowRenderState(
                referenceNote: referenceNote,
                previewedNote: previewedNote,
                activeButtonDirection: nil,
                isButtonTrackingInside: false,
                isScaleActive: false
            )
        }
    }

    func ensureRowLayerCount(_ count: Int) {
        while rowLayers.count < count {
            let rowLayer = PianoRowLayer()
            rowLayers.append(rowLayer)
            addSublayer(rowLayer)
        }

        while rowLayers.count > count {
            let rowLayer = rowLayers.removeLast()
            rowLayer.removeFromSuperlayer()
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: PianoKeyboardLayer.performWithoutImplicitAnimations(_:)
// 功能说明: 对所有 row layer 的 frame/state 更新显式关闭隐式动画，保证阶段 4 的绘制栈行为稳定可控。
func performWithoutImplicitAnimations(_ updates: () -> Void) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    updates()
    CATransaction.commit()
}
```

## 修改 3：新增 `PianoRowLayer` 负责单行一次性绘制

### 修改前

- 修改前没有 `PianoRowLayer`
- 因此按钮背景、箭头、刻度、参考线、白键、黑键、preview 高亮都还没有实际的绘制落点
- 也没有一份“专门给绘制使用”的单行视觉状态结构

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: PianoRowRenderState, draw(in:)
// 功能说明: 修改前文件不存在，单行绘制和视觉高亮还没有正式代码承载。
(无代码)
```

### 修改后

- 新增 `PianoRowRenderState`
- 这份状态只保留绘制关心的内容：
- `referenceNote`
- `previewedNote`
- `activeButtonDirection`
- `isButtonTrackingInside`
- `isScaleActive`
- 新增 `PianoRowLayer.draw(in:)`
- 单行 layer 会一次性画完：
- 行背景
- `A` 区按钮
- `B` 区自然音刻度和参考线
- `C` 区白键黑键
- 行分隔线和边框

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: PianoRowRenderState, PianoRowLayer.draw(in:)
// 功能说明: 把 Shared 层的视觉状态收口成单行绘制输入，并让每个 row layer 一次性完成本行 A/B/C 区渲染。
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

final class PianoRowLayer: CALayer {
    var configuration: PianoConfiguration = .init()
    var scene: PianoScene.RowScene = .empty
    var renderState: PianoRowRenderState = .empty

    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard
            !scene.frame.isNull,
            !bounds.isEmpty
        else {
            return
        }

        drawRowBackground(in: context)
        drawControlStrip(in: context)
        drawKeys(in: context)
        drawSeparatorsAndBorder(in: context)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: drawButton(direction:rect:in:), drawScaleArea(in:), drawReferenceLine(in:)
// 功能说明: A 区按按钮状态切换填充与箭头颜色，B 区根据 scale 活动态绘制刻度背景，并用 startNote 的可见位置画参考线。
func drawButton(
    direction: PianoStepDirection,
    rect: CGRect,
    in context: CGContext
) {
    let isActiveButton = renderState.activeButtonDirection == direction
    let fillColor: CGColor

    if isActiveButton, renderState.isButtonTrackingInside {
        fillColor = PianoLayerPalette.buttonPressedFill
    } else if isActiveButton {
        fillColor = PianoLayerPalette.buttonHoverFill
    } else {
        fillColor = PianoLayerPalette.buttonFill
    }

    context.setFillColor(fillColor)
    context.fill(rect)
    drawButtonArrow(
        direction: direction,
        rect: rect,
        color: isActiveButton && renderState.isButtonTrackingInside
            ? PianoLayerPalette.buttonPressedArrow
            : PianoLayerPalette.buttonArrow,
        in: context
    )
}

func drawScaleArea(in context: CGContext) {
    let scaleFill = renderState.isScaleActive
        ? PianoLayerPalette.scaleActiveFill
        : PianoLayerPalette.scaleFill

    context.setFillColor(scaleFill)
    context.fill(scene.scaleRect)
    drawScaleMarkers(in: context)
    drawReferenceLine(in: context)
    drawScaleBorder(in: context)
}

func drawReferenceLine(in context: CGContext) {
    guard
        let referenceNote = renderState.referenceNote,
        let noteRect = scene.noteRect(for: referenceNote),
        scene.scaleRect.contains(
            CGPoint(x: noteRect.midX, y: scene.scaleRect.midY)
        )
    else {
        return
    }

    context.setStrokeColor(PianoLayerPalette.referenceLine)
    context.setLineWidth(1.5)
    context.move(to: CGPoint(x: noteRect.midX, y: scene.scaleRect.minY + 1))
    context.addLine(to: CGPoint(x: noteRect.midX, y: scene.scaleRect.maxY - 1))
    context.strokePath()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: drawWhiteKeys(in:), drawBlackKeys(in:)
// 功能说明: C 区琴键仍保持单层绘制，不拆按键级 layer；preview 命中的白键和黑键分别使用不同高亮色。
func drawWhiteKeys(in context: CGContext) {
    for whiteKey in scene.whiteKeys {
        let fillColor = renderState.previewedNote == whiteKey.note
            ? PianoLayerPalette.previewWhiteKeyFill
            : PianoLayerPalette.whiteKeyFill
        context.setFillColor(fillColor)
        context.fill(whiteKey.rect)
        context.setStrokeColor(PianoLayerPalette.whiteKeyStroke)
        context.setLineWidth(1)
        context.stroke(strokedRect(whiteKey.rect))
    }
}

func drawBlackKeys(in context: CGContext) {
    for blackKey in scene.blackKeys {
        let fillColor = renderState.previewedNote == blackKey.note
            ? PianoLayerPalette.previewBlackKeyFill
            : PianoLayerPalette.blackKeyFill
        let strokeColor = renderState.previewedNote == blackKey.note
            ? PianoLayerPalette.previewBlackKeyStroke
            : PianoLayerPalette.blackKeyStroke
        context.setFillColor(fillColor)
        context.fill(blackKey.rect)
        context.setStrokeColor(strokeColor)
        context.setLineWidth(1)
        context.stroke(strokedRect(blackKey.rect))
    }
}
```

## 修改 4：扩展 `PianoValidation`，补阶段 4 的 layer 约束检查

### 修改前

- 修改前 validation 只覆盖了：
- 配置安全值
- 黑键起始音
- scene 与 geometry
- reducer 交互生命周期
- 但还没有任何夹具去验证：
- 根 layer 的子 layer 数量是否等于行数
- row scene 是否被正确局部化
- preview、按钮按下态、scaleDrag 高亮是否被正确路由到对应的行
- rows 缩减时旧 row layer 是否被回收

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: validateKeyboardLayerUsesOneRowLayerPerRow(), validateKeyboardLayerRoutesVisualStateToRows()
// 功能说明: 修改前不存在；阶段 4 的 layer 结构约束和视觉状态路由尚未自动化校验。
(无代码)
```

### 修改后

- `makeFixtures()` 新增两个阶段 4 夹具：
- `keyboard_layer_uses_one_row_layer_per_row`
- `keyboard_layer_routes_visual_state_to_rows`
- `manualChecklist` 也追加了“根 layer + 每行一个 row layer、无按键级拆层、无隐式动画”的人工检查项
- 新夹具直接实例化 `PianoKeyboardLayer`，检查 row layer 数量、frame 对齐、局部坐标化、contentsScale 继承，以及按钮/preview/scaleDrag 三类视觉状态的路由结果

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: makeFixtures(), manualChecklist(for:)
// 功能说明: 把阶段 4 的绘制栈约束纳入 Shared validation，防止后续平台接入时破坏少 layer 目标。
static func makeFixtures() -> [PianoValidationFixture] {
    [
        // ... 前面阶段 1~3 的夹具略 ...
        PianoValidationFixture(
            name: "keyboard_layer_uses_one_row_layer_per_row",
            validate: validateKeyboardLayerUsesOneRowLayerPerRow
        ),
        PianoValidationFixture(
            name: "keyboard_layer_routes_visual_state_to_rows",
            validate: validateKeyboardLayerRoutesVisualStateToRows
        )
    ]
}

static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
    [
        "在 \(platform.displayName) 上确认 A 区按钮按下/抬起高亮与步进触发边界一致。",
        "确认 B 区连续拖动离开区域后会立即停止，且吸附开关开闭语义正确。",
        "确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。",
        "确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
        "确认钢琴组件保持“根 layer + 每行一个 row layer”，不存在按键级拆层或隐式动画。"
    ]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: validateKeyboardLayerUsesOneRowLayerPerRow(), validateKeyboardLayerRoutesVisualStateToRows()
// 功能说明: 直接实例化 PianoKeyboardLayer，检查行级 sublayer 数量、scene/frame 同步，以及 preview/button/scale 三类视觉状态是否路由到正确行。
static func validateKeyboardLayerUsesOneRowLayerPerRow() -> [PianoValidationIssue] {
    let layer = PianoKeyboardLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 320, height: 186)
    layer.contentsScale = 2
    layer.configuration = configuration
    layer.state = state
    layer.refreshForCurrentBounds()

    let sublayers = layer.sublayers ?? []
    let rowLayers = sublayers.compactMap { $0 as? PianoRowLayer }

    if sublayers.count != state.rowCount {
        issues.append(issue(fixtureName, "根 layer 下的直接子 layer 数量应等于 rowCount。"))
    }
    if rowLayers.count != expectedScene.rows.count {
        issues.append(issue(fixtureName, "row layer 数量应与 scene.rows 保持一致。"))
    }
    if rowLayer.scene.frame.origin != .zero {
        issues.append(issue(fixtureName, "row scene 传入 row layer 前应已本地化到局部坐标。"))
    }
    return issues
}

static func validateKeyboardLayerRoutesVisualStateToRows() -> [PianoValidationIssue] {
    layer.state = buttonPreviewState
    layer.refreshForCurrentBounds()

    if rowLayers[0].renderState.activeButtonDirection != .right
        || !rowLayers[0].renderState.isButtonTrackingInside {
        issues.append(issue(fixtureName, "第 0 行应接收到按钮按下高亮状态。"))
    }
    if rowLayers[1].renderState.previewedNote != NotePitch(pitchClass: .g, octave: 3) {
        issues.append(issue(fixtureName, "第 1 行应接收到自身的 preview 音。"))
    }

    layer.state = scaleDragState
    layer.refreshForCurrentBounds()
    if rowLayers.contains(where: { !$0.renderState.isScaleActive }) {
        issues.append(issue(fixtureName, "cascade scaleDrag 时所有受影响行都应进入 scale 高亮态。"))
    }

    layer.state = singleRowState
    layer.refreshForCurrentBounds()
    if rowLayers.count != 1 {
        issues.append(issue(fixtureName, "rows 缩减后，row layer 数量也应同步缩减。"))
    }
    return issues
}
```

## 验证结果

- 本轮已执行 `ReadLints` 检查新增/修改文件，结果：无 linter 报错
- 本轮已执行类型检查：
- `xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Piano/*.swift`
- 结果：通过
- 本轮没有额外完成独立的运行时界面验证；平台壳层与控制器 demo 仍留待阶段 5 之后联调

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: 阶段 4 验证结论
// 功能说明: 当前 Shared/Piano 已具备最少 layer 绘制栈；平台壳层尚未接入，因此验证以静态检查和 layer 夹具为主。
- ReadLints: 无报错
- swiftc -typecheck: 通过
- 平台运行时联调: 未在本轮进行
```

## 阶段 4 收口说明

- 这一轮严格停留在 `Shared/Piano` 绘制层，没有提前进入 `UIView/NSView` 输入桥接
- 当前钢琴组件的 Shared 内核已经具备：
- `state + geometry + reducer + layer`
- 下一阶段可以直接接 `iOS` 薄壳，把 raw touch 命中到 Shared reducer，再把 `PianoComponentState` 回写到 `PianoKeyboardLayer`

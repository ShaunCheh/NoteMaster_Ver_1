# 20260330_115728_phase6_piano_macos_view_wrapper

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260330_115728`
- 记录范围：实施“钢琴键盘组件”计划的阶段 6，只落 `macOS` 薄壳 `NSView`，并补齐 piano layer 栈在 `macOS` 下所需的坐标归一化支持
- 本次目标：在不接入控制器 demo 的前提下，让 `macOS` 端也能直接消费 `Shared/Piano` 的 `geometry + reducer + layer`
- 本次实际新增/修改文件：
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- 本次未改动内容：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSPianoKeyboardView.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1.xcodeproj/project.pbxproj`

## 本次结论

- 修改前，钢琴组件已经具备：
- Shared：`state + geometry + reducer + layer`
- iOS：`UIView + raw touch + semantic callbacks`
- 但 `macOS` 端还没有一个真正的 `NSView` 去承接 raw mouse
- 同时，钢琴当前的 layer 栈是“根 layer + 多个 row layer”，如果直接搬到 `macOS`，只做点位翻转还不够，row layer 的纵向 `frame` 和绘制上下文也需要统一翻成 top-left 语义
- 修改后，阶段 6 收口成两部分：
- `PianoContextNormalizationMode`：把点位、矩形和绘制上下文统一支持 `flipYToTopLeft`
- `macOSPianoKeyboardView`：把 raw mouse、resize 刷新、Shared reducer、layer 回写和高层回调接通

## 修改前总体现状

- 修改前，`macOS` 侧还没有钢琴专用视图
- `Shared/Piano` 的 row layer 栈也还默认按 iOS 风格的 top-left 语义同步 `frame` 和绘制
- 因此阶段 6 之前仍然缺少：
- `NSView.makeBackingLayer() -> PianoKeyboardLayer`
- `mouseDown/Dragged/Up` 到 `PianoRawEvent` 的桥接
- AppKit 坐标到 Shared top-left 语义的点位归一化
- row layer 的纵向 frame 翻转和绘制上下文翻转

```text
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名/符号: 文件不存在
// 功能说明: 修改前 macOS 侧还没有钢琴专用 NSView，Shared/Piano 无法被 AppKit 直接消费。
(无代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: PianoContextNormalizationMode, contextNormalizationMode
// 功能说明: 修改前 PianoKeyboardLayer 还没有显式坐标归一化模型，row layer frame 按 scene 原始 top-left 坐标直接落入 CALayer。
(无代码)
```

## 修改 1：为 piano layer 栈补 `macOS` 可用的坐标归一化模型

### 修改前

- 修改前，钢琴 layer 栈没有自己的 `contextNormalizationMode`
- 没有统一入口去翻转：
- AppKit 的 bottom-left 点位
- 多行 row layer 的纵向 frame
- 单行 row layer 的绘制上下文
- 这意味着如果直接在 `macOS` 下复用阶段 4 的 layer，同一份 scene 里的顶行/底行可能会在视图里上下颠倒

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: PianoContextNormalizationMode.normalizedPoint(_:in:), normalizedRect(_:in:), applyIfNeeded(to:in:)
// 功能说明: 修改前不存在；钢琴 layer 栈还没有独立的点位/矩形/绘制上下文归一化基础设施。
(无代码)
```

### 修改后

- 在 `PianoKeyboardLayer.swift` 中新增 `PianoContextNormalizationMode`
- 暴露三类统一能力：
- `normalizedPoint(_:in:)`
- `normalizedRect(_:in:)`
- `applyIfNeeded(to:in:)`
- 首版只定义两个模式：
- `.none`
- `.flipYToTopLeft`
- 这样平台层和单行绘制层就能共享一份显式的 top-left 归一化语义，而不需要分别写各自的翻转逻辑

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: PianoContextNormalizationMode.normalizedPoint(_:in:), normalizedRect(_:in:), applyIfNeeded(to:in:)
// 功能说明: 为钢琴 layer 栈提供统一的坐标归一化入口，既能翻转 AppKit 点位，也能翻转 row layer frame 和 CGContext。
enum PianoContextNormalizationMode: Equatable, Sendable {
    case none
    case flipYToTopLeft

    func normalizedPoint(
        _ point: CGPoint,
        in bounds: CGRect
    ) -> CGPoint {
        switch self {
        case .none:
            return point
        case .flipYToTopLeft:
            let mirroredY = bounds.minY + bounds.maxY - point.y
            return CGPoint(x: point.x, y: mirroredY)
        }
    }

    func normalizedRect(
        _ rect: CGRect,
        in bounds: CGRect
    ) -> CGRect {
        switch self {
        case .none:
            return rect
        case .flipYToTopLeft:
            guard !rect.isNull else {
                return rect
            }

            return CGRect(
                x: rect.minX,
                y: bounds.minY + bounds.maxY - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        }
    }

    func applyIfNeeded(
        to context: CGContext,
        in bounds: CGRect
    ) {
        switch self {
        case .none:
            return
        case .flipYToTopLeft:
            context.translateBy(x: 0, y: bounds.minY + bounds.maxY)
            context.scaleBy(x: 1, y: -1)
        }
    }
}
```

## 修改 2：让根 layer 和 row layer 真正消费归一化模式

### 修改前

- 修改前，`PianoKeyboardLayer.synchronizeSublayerState()` 直接把 `scene.rows[index].frame` 塞给 row layer
- `PianoRowLayer.draw(in:)` 也直接以当前 `CGContext` 原始坐标绘制
- 在 iOS 上这样没问题，但对 `macOS` 来说不够

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: synchronizeSublayerState()
// 功能说明: 修改前直接使用 absoluteRowScene.frame，没有按 bottom-left -> top-left 规则翻转 row layer 的 frame。
(无代码)
```

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: contextNormalizationMode, applyContextNormalizationIfNeeded(in:), draw(in:)
// 功能说明: 修改前不存在这些符号，row layer 绘制上下文还不会按 macOS 需要做翻转。
(无代码)
```

### 修改后

- `PianoKeyboardLayer` 新增 `contextNormalizationMode`
- `synchronizeSublayerState()` 现在会先用 `normalizedRect(...)` 翻转 row layer 的 frame
- 然后把同一份模式继续传给 `PianoRowLayer`
- `PianoRowLayer` 新增 `contextNormalizationMode`
- `draw(in:)` 开头会调用 `applyContextNormalizationIfNeeded(in:)`
- 这样单行 layer 内仍然可以复用 Shared 里按 top-left 语义生成的 `controlStripRect / keysRect / noteRect`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift
// 函数名/符号: PianoKeyboardLayer.contextNormalizationMode, synchronizeSublayerState()
// 功能说明: 根 layer 负责把 row layer 的 frame 翻到 macOS 对应位置，并把同一套归一化模式传给单行绘制层。
final class PianoKeyboardLayer: CALayer {
    var contextNormalizationMode: PianoContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    func synchronizeSublayerState() {
        let scene = PianoSceneBuilder(
            configuration: configuration,
            state: state
        ).makeScene(bounds: bounds)

        performWithoutImplicitAnimations {
            ensureRowLayerCount(scene.rows.count)

            for (index, absoluteRowScene) in scene.rows.enumerated() {
                let rowLayer = rowLayers[index]
                rowLayer.frame = contextNormalizationMode.normalizedRect(
                    absoluteRowScene.frame,
                    in: bounds
                )
                rowLayer.configuration = configuration
                rowLayer.scene = absoluteRowScene.localizedToRowBounds()
                rowLayer.renderState = renderState(for: absoluteRowScene.rowIndex)
                rowLayer.contextNormalizationMode = contextNormalizationMode
                rowLayer.contentsScale = contentsScale
            }
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift
// 函数名/符号: PianoRowLayer.contextNormalizationMode, applyContextNormalizationIfNeeded(in:), draw(in:)
// 功能说明: 单行绘制层在真正绘图前统一翻转 CGContext，保证 Shared scene 的 top-left 几何在 macOS 上仍能正确复用。
final class PianoRowLayer: CALayer {
    var contextNormalizationMode: PianoContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            setNeedsDisplay()
        }
    }

    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard
            !scene.frame.isNull,
            !bounds.isEmpty
        else {
            return
        }

        context.saveGState()
        applyContextNormalizationIfNeeded(in: context)
        drawRowBackground(in: context)
        drawControlStrip(in: context)
        drawKeys(in: context)
        drawSeparatorsAndBorder(in: context)
        context.restoreGState()
    }
}

func applyContextNormalizationIfNeeded(in context: CGContext) {
    contextNormalizationMode.applyIfNeeded(
        to: context,
        in: bounds
    )
}
```

## 修改 3：新增 `macOSPianoKeyboardView`

### 修改前

- 修改前没有 `macOSPianoKeyboardView`
- 所以也没有：
- `makeBackingLayer() -> PianoKeyboardLayer`
- `mouseDown/Dragged/Up` 到 `PianoRawEvent` 的桥接
- live resize 时的 layer 刷新策略
- 与 iOS 同名的 `rows/configuration/onPreview*` API

```text
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名/符号: makeBackingLayer(), mouseDown(with:), mouseDragged(with:), mouseUp(with:)
// 功能说明: 修改前文件不存在，macOS 平台还没有钢琴的 AppKit 薄壳。
(无代码)
```

### 修改后

- 新增 `macOSPianoKeyboardView`
- 对外 API 与 iOS 保持同名：
- `configuration`
- `rows`
- `preview`
- `onRowsChanged`
- `onPreviewStarted`
- `onPreviewChanged`
- `onPreviewEnded`
- 视图内部以 `PianoKeyboardLayer` 为 backing layer
- `mouseDown/Dragged/Up` 直接桥接 raw mouse
- 进入 Shared 之前先把 AppKit 点位用 `resolvedContextNormalizationMode.normalizedPoint(...)` 翻成 top-left 语义
- `viewDidMoveToWindow`、`setFrameSize`、`viewWillStartLiveResize`、`viewDidEndLiveResize` 统一刷新 layer，避免窗口缩放时渲染滞后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名/符号: macOSPianoKeyboardView, makeBackingLayer(), viewDidMoveToWindow(), setFrameSize(_:)
// 功能说明: 建立 AppKit 薄壳，让 macOS 端直接用 PianoKeyboardLayer 作为 backing layer，并在窗口缩放与 backing scale 变化时主动刷新。
final class macOSPianoKeyboardView: NSView {
    private var componentState: PianoComponentState
    private var isMouseSequenceActive = false

    var configuration: PianoConfiguration {
        didSet {
            guard oldValue != configuration else {
                return
            }

            applyConfiguration()
        }
    }

    var rows: [PianoRowState] {
        get {
            componentState.rows
        }
        set {
            replaceRows(newValue)
        }
    }

    override func makeBackingLayer() -> CALayer {
        PianoKeyboardLayer()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
        refreshPresentationForResize(displayImmediately: false)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshPresentationForResize(displayImmediately: inLiveResize)
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        refreshPresentationForResize(displayImmediately: true)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        refreshPresentationForResize(displayImmediately: true)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名/符号: mouseDown(with:), mouseDragged(with:), mouseUp(with:), handleRawMouseEvent(_:phase:)
// 功能说明: 不借助 NSGestureRecognizer，直接把鼠标输入桥接到 Shared 的 PianoRawEvent，并先做 AppKit -> top-left 坐标归一化。
override func mouseDown(with event: NSEvent) {
    isMouseSequenceActive = true
    handleRawMouseEvent(event, phase: .began)
}

override func mouseDragged(with event: NSEvent) {
    guard isMouseSequenceActive else {
        return
    }

    handleRawMouseEvent(event, phase: .moved)
}

override func mouseUp(with event: NSEvent) {
    guard isMouseSequenceActive else {
        return
    }

    handleRawMouseEvent(event, phase: .ended)
    isMouseSequenceActive = false
}

func handleRawMouseEvent(
    _ event: NSEvent,
    phase: PianoEventPhase
) {
    let location = convert(event.locationInWindow, from: nil)
    let normalizedLocation = resolvedContextNormalizationMode.normalizedPoint(
        location,
        in: bounds
    )
    handleRawEvent(
        PianoRawEvent(
            phase: phase,
            locationInView: normalizedLocation
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名/符号: applyConfiguration(), handleRawEvent(_:) , applyReduction(_:) , emitSemanticEvents(_:)
// 功能说明: 把 macOS 平台层的配置、命中、reducer 输出和高层回调收口到一个薄壳里，与 iOS 侧保持同名语义。
func applyConfiguration() {
    pianoKeyboardLayer.configuration = configuration
    pianoKeyboardLayer.contextNormalizationMode = resolvedContextNormalizationMode
    updateContentsScale()
    refreshPresentationForResize(displayImmediately: false)
    invalidateIntrinsicContentSize()
}

func handleRawEvent(_ rawEvent: PianoRawEvent) {
    guard !bounds.isEmpty else {
        return
    }

    let geometry = PianoGeometry(
        configuration: configuration,
        state: componentState,
        bounds: bounds
    )
    let hitResult = geometry.hitTest(
        rawEvent.locationInView,
        phase: rawEvent.phase
    )
    let reduction = PianoInteractionReducer.reduce(
        state: componentState,
        rawEvent: rawEvent,
        hitResult: hitResult,
        configuration: configuration
    )
    applyReduction(reduction)
}

func applyReduction(_ reduction: PianoReduction) {
    guard reduction.nextState != componentState || !reduction.semanticEvents.isEmpty else {
        return
    }

    componentState = reduction.nextState
    applyBackingState()
    emitSemanticEvents(reduction.semanticEvents)
}

func emitSemanticEvents(_ semanticEvents: [PianoSemanticEvent]) {
    for semanticEvent in semanticEvents {
        switch semanticEvent {
        case let .rowsChanged(rows):
            onRowsChanged?(rows)
        case let .previewStarted(preview):
            onPreviewStarted?(preview)
        case let .previewChanged(preview):
            onPreviewChanged?(preview)
        case let .previewEnded(preview):
            onPreviewEnded?(preview)
        }
    }
}
```

## 修改 4：扩展 validation，补 `macOS` 归一化夹具

### 修改前

- 修改前 `PianoValidation` 已覆盖：
- 共享模型
- scene / geometry
- reducer 生命周期
- layer 数量与视觉状态路由
- 但还没有任何夹具验证：
- `flipYToTopLeft` 下 row layer frame 是否翻转到正确位置
- `PianoRowLayer` 是否继承同一套归一化模式
- top row 在 `macOS` 归一化后是否仍显示在最上方

```text
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: validateKeyboardLayerFlipNormalization()
// 功能说明: 修改前不存在；阶段 6 的 macOS 归一化行为还没有自动化夹具。
(无代码)
```

### 修改后

- `makeFixtures()` 新增：
- `keyboard_layer_flip_normalization_preserves_top_left_layout`
- `manualChecklist(for:)` 也补了一条 `macOS` 专项检查项
- 新夹具会直接实例化 `PianoKeyboardLayer`，把模式切到 `.flipYToTopLeft`，再检查：
- `normalizedPoint(...)` 的点位翻转结果
- row layer `frame`
- row layer `contextNormalizationMode`
- 顶行是否仍处于视觉最上方

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: makeFixtures(), manualChecklist(for:)
// 功能说明: 把 macOS 归一化行为纳入 PianoValidation，避免后续平台改动破坏 top-left 语义。
PianoValidationFixture(
    name: "keyboard_layer_flip_normalization_preserves_top_left_layout",
    validate: validateKeyboardLayerFlipNormalization
)

static func manualChecklist(for platform: PianoValidationPlatform) -> [String] {
    [
        "在 \(platform.displayName) 上确认 A 区按钮按下/抬起高亮与步进触发边界一致。",
        "确认 B 区连续拖动离开区域后会立即停止，且吸附开关开闭语义正确。",
        "确认 C 区滑音过程中只更新预览音，不导致 rows 的 startNote 或 offsetX 变化。",
        "确认一次输入序列会锁定在 A/B/C 其中一种模式，不会在 B 区拖动时切换成 C 区预览。",
        "确认钢琴组件保持“根 layer + 每行一个 row layer”，不存在按键级拆层或隐式动画。",
        "确认 macOS 归一化后顶行仍显示在最上方，A/B/C 区命中与 iOS 保持一致。"
    ]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名/符号: validateKeyboardLayerFlipNormalization()
// 功能说明: 直接构造 PianoKeyboardLayer 并切到 flipYToTopLeft，验证点位翻转、row frame 翻转和 row layer 模式继承。
static func validateKeyboardLayerFlipNormalization() -> [PianoValidationIssue] {
    let layer = PianoKeyboardLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
    layer.contextNormalizationMode = .flipYToTopLeft
    layer.configuration = configuration
    layer.state = state
    layer.refreshForCurrentBounds()

    let normalizedPoint = PianoContextNormalizationMode.flipYToTopLeft.normalizedPoint(
        CGPoint(x: 12, y: 18),
        in: layer.bounds
    )

    let expectedFrame = PianoContextNormalizationMode.flipYToTopLeft.normalizedRect(
        expectedScene.rows[index].frame,
        in: layer.bounds
    )

    if rowLayer.frame != expectedFrame {
        issues.append(issue(fixtureName, "第 \(index) 行 row layer frame 应按 flipYToTopLeft 规则翻转。"))
    }
    if rowLayer.contextNormalizationMode != .flipYToTopLeft {
        issues.append(issue(fixtureName, "第 \(index) 行 row layer 应继承 flipYToTopLeft 归一化模式。"))
    }
    if rowLayers[0].frame.minY <= rowLayers[1].frame.minY {
        issues.append(issue(fixtureName, "翻转后第 0 行应位于更靠上的图层位置。"))
    }

    return issues
}
```

## 工程接入说明

- 这轮新增了 `Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- 但没有手工改 `xcodeproj`
- 原因和阶段 5 一样：当前工程使用文件系统同步 group，新增文件会被工程自动感知

```text
// 文件路径: NoteMaster_Ver_1.xcodeproj/project.pbxproj
// 函数名/符号: PBXFileSystemSynchronizedRootGroup, fileSystemSynchronizedGroups
// 功能说明: 工程采用文件系统同步 group，因此阶段 6 新增的 macOS 文件无需手工加入 xcodeproj。
/* Begin PBXFileSystemSynchronizedRootGroup section */
    isa = PBXFileSystemSynchronizedRootGroup;
/* End PBXFileSystemSynchronizedRootGroup section */

fileSystemSynchronizedGroups = (
    // ... 工程启用文件系统同步 ...
)
```

## 验证结果

- 本轮已执行 `ReadLints` 检查：
- `NoteMaster_Ver_1/Shared/Piano/PianoKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoRowLayer.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- 结果：无 linter 报错
- 本轮已执行类型检查：
- `xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift NoteMaster_Ver_1/Shared/Piano/*.swift NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift`
- 结果：通过
- 本轮还尝试直接执行 `PianoValidationRunner`，但命令行方式没有返回可判定的 summary 输出，因此不把它算作已完成的运行时验证
- 本轮未做控制器级 demo、窗口运行时联调或 A/B/C 命中人工回归；这些仍留待后续阶段收口

```text
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSPianoKeyboardView.swift
// 函数名/符号: 阶段 6 验证结论
// 功能说明: 当前阶段以 macOS 壳层落地、共享归一化补齐和静态检查为主，尚未进入控制器或窗口运行时联调。
- ReadLints: 无报错
- swiftc -typecheck: 通过
- PianoValidationRunner 命令行执行: 有尝试，但无可判定输出
- 控制器/窗口运行时联调: 本轮未执行
```

## 阶段 6 收口说明

- 这一轮完成后，钢琴组件已经具备：
- Shared：`state + geometry + reducer + layer + macOS normalization`
- iOS：`UIView + raw touch + semantic callbacks`
- macOS：`NSView + raw mouse + live resize refresh + semantic callbacks`
- 下一阶段可以直接实施阶段 7，把双平台最小 demo 接到控制器层，验证 `rowsChanged` 与 `preview` 生命周期在真实页面里的闭环

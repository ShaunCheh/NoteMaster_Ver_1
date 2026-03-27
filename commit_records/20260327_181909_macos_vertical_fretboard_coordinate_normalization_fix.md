# 20260327_181909_macos_vertical_fretboard_coordinate_normalization_fix

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260327_181909`
- 记录范围：修复 `macOS` 平台下 `vertical` 模式 fretboard 上下颠倒的根因问题
- 本次目标：
- 在不改 shared `vertical scene` 几何语义的前提下，为 `macOS fretboard` 渲染链补齐 top-left 坐标归一化
- 让 `mouse hitTest` 使用与绘制完全一致的坐标变换，避免“画正了但点击还是反的”
- 在 shared validation 中补充对归一化命中语义的回归覆盖，并移除为定位根因临时添加的调试日志
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardBoardLayer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardLabelsLayer.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 根因结论

- shared 层对 `vertical fretboard` 的契约本来就是正确的：`FretboardValidation` 明确要求 `vertical` 为“上空弦下高品、品位沿 y 轴递增、文字正立”。
- 问题出在 `macOS` 平台：`NSView/CALayer` 默认使用 bottom-left 坐标语义，而 shared `vertical scene` 使用的是 top-left 语义。
- 修改前，`macOSFretboardView` 把原始 view 本地坐标直接送进 `FretboardGeometry.hitTest(...)`，`FretboardBoardLayer/FretboardLabelsLayer` 也直接按未归一化的 `CGContext` 绘制。
- 这意味着渲染与命中共用同一组 shared scene 数据，却没有在平台层统一坐标系，最终表现为：
- 视觉上：`vertical fretboard` 上下颠倒
- 交互上：一旦只修绘制不修命中，就会出现“画正了但点反了”
- 这次修复的根因策略因此不是去改 `VerticalFretboardGeometryStrategy.swift`，而是：
- 在 `FretboardLayer` 引入正式的坐标归一化模式
- 让 `board/labels` 绘制与 `macOS mouse hitTest` 复用同一套归一化 helper
- 在修复后移除本次用于确认根因的临时日志

## 修改 1：在 `FretboardLayer` 正式引入坐标归一化契约

### 修改前

- `FretboardLayer` 只负责同步 `configuration / contentProvider / contentsScale`
- 没有表达“当前平台绘制上下文是否需要翻转到 top-left”的 shared 状态
- `boardLayer` 和 `labelsLayer` 也拿不到统一的归一化配置

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 类型/函数: FretboardLayer, synchronizeSublayerState()
// 功能说明: 修改前 fretboard root layer 只同步 scene 与 contentProvider，
// 没有共享的坐标归一化模式，子 layer 只能直接依赖平台默认 CGContext 语义。
final class FretboardLayer: CALayer {
    var configuration: FretboardConfiguration = .init() {
        didSet {
            guard oldValue != configuration else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    var contentProvider: (any FretboardContentProviding)? {
        didSet {
            invalidateSublayersForCurrentState()
        }
    }

    override var contentsScale: CGFloat {
        didSet {
            guard oldValue != contentsScale else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    private let boardLayer = FretboardBoardLayer()
    private let labelsLayer = FretboardLabelsLayer()

    private func synchronizeSublayerState() {
        let scene = FretboardSceneBuilder(
            configuration: configuration
        ).makeScene(bounds: bounds)

        performWithoutImplicitAnimations {
            boardLayer.frame = bounds
            labelsLayer.frame = bounds
            boardLayer.configuration = configuration
            labelsLayer.configuration = configuration
            boardLayer.scene = scene
            labelsLayer.scene = scene
            boardLayer.contentsScale = contentsScale
            labelsLayer.contentsScale = contentsScale
            labelsLayer.contentProvider = contentProvider
        }
    }
}
```

### 修改后

- 新增 `FretboardContextNormalizationMode`
- 在 shared root layer 内统一定义：
- `normalizedPoint(...)`：供平台命中入口把 raw 坐标映射到 shared scene 语义
- `applyIfNeeded(...)`：供 `draw(in:)` 在 CGContext 上执行相同的翻转
- `FretboardLayer` 新增 `contextNormalizationMode`，并把它向 `boardLayer` / `labelsLayer` 同步下发

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift
// 类型/函数: FretboardContextNormalizationMode, FretboardLayer.contextNormalizationMode, synchronizeSublayerState()
// 功能说明: 修改后 fretboard root layer 成为渲染坐标归一化的共享入口；
// draw 与 hitTest 都复用同一套 top-left 对齐规则，不再各写一套镜像逻辑。
enum FretboardContextNormalizationMode: Equatable, Sendable {
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

final class FretboardLayer: CALayer {
    var contextNormalizationMode: FretboardContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            invalidateSublayersForCurrentState()
        }
    }

    private func synchronizeSublayerState() {
        let scene = FretboardSceneBuilder(
            configuration: configuration
        ).makeScene(bounds: bounds)

        performWithoutImplicitAnimations {
            boardLayer.frame = bounds
            labelsLayer.frame = bounds
            boardLayer.configuration = configuration
            labelsLayer.configuration = configuration
            boardLayer.scene = scene
            labelsLayer.scene = scene
            boardLayer.contentsScale = contentsScale
            labelsLayer.contentsScale = contentsScale
            boardLayer.contextNormalizationMode = contextNormalizationMode
            labelsLayer.contextNormalizationMode = contextNormalizationMode
            labelsLayer.contentProvider = contentProvider
        }
    }
}
```

## 修改 2：让 `board/labels` 在 `draw(in:)` 入口统一使用归一化 CGContext

### 修改前

- `FretboardBoardLayer` 和 `FretboardLabelsLayer` 都没有 `contextNormalizationMode`
- `draw(in:)` 直接使用当前平台给到的 CGContext
- 为定位根因，`FretboardBoardLayer` 里临时塞入了一段 `macOS vertical` 的诊断日志

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardBoardLayer.swift
// 类型/函数: FretboardBoardLayer.draw(in:), logMacOSVerticalDrawDiagnosticIfNeeded(...)
// 功能说明: 修改前 board layer 直接吃平台默认 CGContext；
// 为确认 root cause 临时插入了 macOS vertical draw 诊断日志。
final class FretboardBoardLayer: CALayer {
    #if DEBUG && os(macOS)
    private var lastMacOSVerticalDrawDiagnosticSignature: String?
    #endif

    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard !scene.drawingRect.isNull else {
            return
        }

        logMacOSVerticalDrawDiagnosticIfNeeded(context: context)
        drawDisplayBackground(in: context)
        drawFretboardBody(in: context)
        drawMarkers(in: context)
        drawFrets(in: context)
        drawNut(in: context)
        drawStrings(in: context)
        drawDisplayBorder(in: context)
    }

    private func logMacOSVerticalDrawDiagnosticIfNeeded(context: CGContext) {
        #if DEBUG && os(macOS)
        ...
        #endif
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLabelsLayer.swift
// 类型/函数: FretboardLabelsLayer.draw(in:)
// 功能说明: 修改前 labels layer 虽然在 drawTextLine(...) 里区分了 CTM 正反向，
// 但 draw(in:) 入口本身没有和 board layer 共享同一套上下文归一化开关。
final class FretboardLabelsLayer: CALayer {
    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard
            !scene.drawingRect.isNull,
            let contentProvider
        else {
            return
        }

        let labels = contentProvider.makeLabels(
            configuration: configuration,
            scene: scene
        )
        guard !labels.isEmpty else {
            return
        }

        for label in labels {
            guard let resolvedText = resolvedTextLine(for: label) else {
                continue
            }

            drawLabelBadge(for: label, in: context)
            drawTextLine(
                resolvedText.line,
                bounds: resolvedText.bounds,
                centeredAt: label.center,
                in: context
            )
        }
    }
}
```

### 修改后

- `FretboardBoardLayer` 与 `FretboardLabelsLayer` 都新增 `contextNormalizationMode`
- 两个 `draw(in:)` 入口都先调用 `applyContextNormalizationIfNeeded(...)`
- 临时 `macOS vertical` 定位日志已完全移除
- 这样图形和文字使用的是同一套归一化后的 CGContext，不再出现 board 和 label 各画各的坐标系

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardBoardLayer.swift
// 类型/函数: FretboardBoardLayer.contextNormalizationMode, draw(in:), applyContextNormalizationIfNeeded(...)
// 功能说明: 修改后 board layer 在真正绘制 scene 之前先把 CGContext 归一化到 top-left，
// 不再依赖临时诊断日志，也不再把平台默认 bottom-left 直接暴露给 shared scene。
final class FretboardBoardLayer: CALayer {
    var contextNormalizationMode: FretboardContextNormalizationMode = .none {
        didSet {
            guard oldValue != contextNormalizationMode else {
                return
            }

            setNeedsDisplay()
        }
    }

    override func draw(in context: CGContext) {
        context.clear(bounds)
        guard !scene.drawingRect.isNull else {
            return
        }

        applyContextNormalizationIfNeeded(in: context)
        drawDisplayBackground(in: context)
        drawFretboardBody(in: context)
        drawMarkers(in: context)
        drawFrets(in: context)
        drawNut(in: context)
        drawStrings(in: context)
        drawDisplayBorder(in: context)
    }

    private func applyContextNormalizationIfNeeded(in context: CGContext) {
        contextNormalizationMode.applyIfNeeded(
            to: context,
            in: bounds
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardLabelsLayer.swift
// 类型/函数: FretboardLabelsLayer.contextNormalizationMode, draw(in:), applyContextNormalizationIfNeeded(...)
// 功能说明: 修改后 labels layer 与 board layer 共用同一套归一化模式，
// 文字与 badge 的绘制上下文保持一致，避免“板子翻了但标签没翻”的分裂状态。
final class FretboardLabelsLayer: CALayer {
    var contextNormalizationMode: FretboardContextNormalizationMode = .none {
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
            !scene.drawingRect.isNull,
            let contentProvider
        else {
            return
        }

        applyContextNormalizationIfNeeded(in: context)
        let labels = contentProvider.makeLabels(
            configuration: configuration,
            scene: scene
        )
        ...
    }

    private func applyContextNormalizationIfNeeded(in context: CGContext) {
        contextNormalizationMode.applyIfNeeded(
            to: context,
            in: bounds
        )
    }
}
```

## 修改 3：在 `macOSFretboardView` 只对 `vertical` 模式启用归一化，并让 `hitTest` 复用同一 helper

### 修改前

- `applyConfiguration()` 只设置 `configuration/contentProvider`
- `handleRawMouseEvent(...)` 把 `convert(event.locationInWindow, from: nil)` 得到的 raw `NSView` 本地坐标直接送进 `geometry.hitTest(...)`
- 同时为了排查问题，`macOSFretboardView` 里保留了两组临时诊断函数

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 类型/函数: applyConfiguration(), handleRawMouseEvent(...), logVerticalCoordinateDiagnostic(...), logVerticalHitDiagnostic(...)
// 功能说明: 修改前 macOS 平台层没有声明“当前 displayMode 是否需要坐标归一化”，
// 绘制与命中都直接落在平台默认 bottom-left 语义上，只能依赖临时日志判断为什么会颠倒。
final class macOSFretboardView: NSView {
    private var lastMeasuredPrimaryDimension: CGFloat?
    private var lastVerticalCoordinateDiagnosticSignature: String?

    private func applyConfiguration() {
        lastMeasuredPrimaryDimension = nil
        lastVerticalCoordinateDiagnosticSignature = nil
        fretboardLayer.configuration = configuration
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        updateContentPriorities()
        invalidateIntrinsicContentSize()
        logVerticalCoordinateDiagnostic(reason: "applyConfiguration")
    }

    private func handleRawMouseEvent(
        _ event: NSEvent,
        phase: FretboardEventPhase
    ) {
        let location = convert(event.locationInWindow, from: nil)
        let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
        let hitResult = geometry.hitTest(location, phase: phase)
        logVerticalHitDiagnostic(hitResult)
        onRawEvent?(hitResult)
    }

    private func logVerticalCoordinateDiagnostic(reason: String) { ... }
    private func logVerticalHitDiagnostic(_ hitResult: FretboardHitResult) { ... }
}
```

### 修改后

- 新增 `resolvedContextNormalizationMode`
- 只在 `vertical` 模式返回 `.flipYToTopLeft`，`horizontal` 保持 `.none`
- `applyConfiguration()` 把这份模式下发给 `fretboardLayer`
- `handleRawMouseEvent(...)` 先把 raw `NSView` 点位用同一 helper 归一化，再送入 `FretboardGeometry.hitTest(...)`
- 用完的调试日志全部移除，不把定位代码残留在运行时路径

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 类型/函数: applyConfiguration(), resolvedContextNormalizationMode, handleRawMouseEvent(...)
// 功能说明: 修改后 macOS 平台层成为“启用 vertical top-left 归一化”的唯一入口，
// 并确保 raw mouse 命中与渲染共享同一坐标变换，不会出现“画正了但点击还是反的”。
final class macOSFretboardView: NSView {
    private var lastMeasuredPrimaryDimension: CGFloat?

    private func applyConfiguration() {
        lastMeasuredPrimaryDimension = nil
        fretboardLayer.configuration = configuration
        fretboardLayer.contextNormalizationMode = resolvedContextNormalizationMode
        fretboardLayer.contentProvider = contentProvider
        updateContentsScale()
        updateContentPriorities()
        invalidateIntrinsicContentSize()
    }

    // macOS 默认 view/layer 坐标是 bottom-left；shared vertical scene 使用 top-left 语义。
    private var resolvedContextNormalizationMode: FretboardContextNormalizationMode {
        switch configuration.displayMode {
        case .horizontal:
            return .none
        case .vertical:
            return .flipYToTopLeft
        }
    }

    private func handleRawMouseEvent(
        _ event: NSEvent,
        phase: FretboardEventPhase
    ) {
        let location = convert(event.locationInWindow, from: nil)
        let geometryLocation = resolvedContextNormalizationMode.normalizedPoint(
            location,
            in: bounds
        )
        let geometry = FretboardGeometry(configuration: configuration, bounds: bounds)
        let hitResult = geometry.hitTest(geometryLocation, phase: phase)
        onRawEvent?(hitResult)
    }
}
```

## 修改 4：补充交互语义注释与归一化命中回归验证

### 修改前

- `FretboardHitResult.locationInView` 的注释只说“平台包装视图本地坐标”
- `FretboardValidation.validateHitTesting(...)` 只验证 scene 自己的 `anchor.center -> hitTest(anchor.center)` 是否自洽
- 还没有覆盖“如果平台先拿到底部原点坐标，再经过统一归一化后，是否仍能打回同一个 cell”
- `macOS` 手工清单也没有明确要求验证“顶部空弦区 / 底部高品区点击不再上下反向”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift
// 类型/函数: FretboardHitResult
// 功能说明: 修改前注释只强调平台本地坐标，
// 但没有明确如果平台存在坐标翻转，应先做归一化再写入这里。
struct FretboardHitResult: Equatable, Sendable {
    var phase: FretboardEventPhase
    // 使用平台包装视图本地坐标，和 FretboardGeometry 的 bounds 语义保持一致。
    var locationInView: CGPoint
    ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 类型/函数: validateHitTesting(...), manualChecklist(for:)
// 功能说明: 修改前自动化命中测试只验证 scene 中心点是否命中自己，
// 还没有补“display 坐标先镜像、再归一化”的回归场景；macOS 手工清单也未覆盖顶部/底部点击反向。
static func validateHitTesting(
    scene: FretboardScene,
    fixture: FretboardValidationFixture,
    sceneBuilder: FretboardSceneBuilder,
    record: (String) -> Void
) {
    for anchor in scene.labelAnchors {
        let hit = sceneBuilder.hitTest(
            anchor.center,
            phase: .began,
            scene: scene
        )
        ...
    }
}

case .macOS:
    checklist.append("在 macOS 上执行 live resize，确认 vertical 模式不闪烁，指板在 resize 过程中保持居中且命中仍正常。")
```

### 修改后

- `FretboardHitResult.locationInView` 明确改成“与 `FretboardGeometry.bounds` 一致的本地坐标语义”
- `FretboardValidation.validateHitTesting(...)` 在 `vertical` 模式补了一层：
- 先构造一个 bottom-left 显示点 `mirroredDisplayPoint`
- 再调用 `FretboardContextNormalizationMode.flipYToTopLeft.normalizedPoint(...)`
- 断言它能回到 shared `anchor.center`
- 再断言归一化后的命中结果仍命中同一个 `FretboardCell`
- `macOS` 手工清单补上“顶部空弦区 / 底部高品区点击不再上下反向”

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift
// 类型/函数: FretboardHitResult
// 功能说明: 修改后交互模型显式规定了 locationInView 的共享语义，
// 平台层若存在坐标翻转，必须先归一化到 shared geometry 坐标再写入命中结果。
struct FretboardHitResult: Equatable, Sendable {
    var phase: FretboardEventPhase
    // 使用与 FretboardGeometry.bounds 一致的本地坐标语义；
    // 平台层若存在坐标翻转，会先做必要归一化后再写入这里。
    var locationInView: CGPoint
    ...
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 类型/函数: validateHitTesting(...), manualChecklist(for:)
// 功能说明: 修改后 validation 不再只验证 shared scene 自洽，
// 也验证“display 坐标先镜像、再归一化”后仍能回到同一个 vertical cell。
static func validateHitTesting(
    scene: FretboardScene,
    fixture: FretboardValidationFixture,
    sceneBuilder: FretboardSceneBuilder,
    record: (String) -> Void
) {
    for anchor in scene.labelAnchors {
        let hit = sceneBuilder.hitTest(
            anchor.center,
            phase: .began,
            scene: scene
        )
        ...
    }

    if fixture.configuration.displayMode == .vertical {
        for anchor in scene.labelAnchors {
            let expectedCell = FretboardCell(
                stringIndex: anchor.stringIndex,
                fret: anchor.fret
            )
            let mirroredDisplayPoint = CGPoint(
                x: anchor.center.x,
                y: fixture.bounds.minY + fixture.bounds.maxY - anchor.center.y
            )
            let normalizedPoint = FretboardContextNormalizationMode.flipYToTopLeft
                .normalizedPoint(
                    mirroredDisplayPoint,
                    in: fixture.bounds
                )

            if !approximatelyEqual(normalizedPoint.x, anchor.center.x)
                || !approximatelyEqual(normalizedPoint.y, anchor.center.y) {
                record("vertical 模式下坐标归一化后未回到 anchor(\\(anchor.stringIndex), \\(anchor.fret)) 的共享几何中心。")
            }

            let normalizedHit = sceneBuilder.hitTest(
                normalizedPoint,
                phase: .began,
                scene: scene
            )
            if normalizedHit.cell != expectedCell {
                record("vertical 模式下归一化后的命中测试未命中 (\\(anchor.stringIndex), \\(anchor.fret))，实际 \\(String(describing: normalizedHit.cell))。")
            }
        }
    }
}

case .macOS:
    checklist.append("在 macOS 上执行 live resize，确认 vertical 模式不闪烁，指板在 resize 过程中保持居中且命中仍正常。")
    checklist.append("在 macOS 的 vertical 模式下分别点击顶部空弦区与底部高品区，确认可见格子与控制台 string / fret 一致，不再出现上下反向。")
```

## 本阶段结果

- `macOS vertical fretboard` 现在会在渲染入口统一翻转到 top-left 语义，视觉不再上下颠倒
- `mouse hitTest` 现在会先做与绘制一致的归一化，再送入 shared `FretboardGeometry`
- `board/labels` 与 `hitTest` 不再各自维护一套隐式坐标规则
- 根因修复没有去篡改 shared `vertical geometry` 公式，因此 iOS / commandLine / shared validation 的既有契约保持不变
- 本次为定位根因临时加入的 `[VerticalFretboard][macOS]` 诊断日志已全部移除

## 验证情况

- 已对下列文件执行静态诊断检查，结果无 linter 错误：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardBoardLayer.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardLabelsLayer.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`
- 未执行 `xcodebuild` 全量编译；当前记录覆盖的是本次 macOS vertical fretboard 坐标归一化、命中对齐与 validation 清理

# P-2 答题指板宽度翻倍与组件内纵向滚动修改记录

- 记录时间戳：`20260504_235054`
- 记录文件名：`20260504_235054_p2_answer_fretboard_width_x2_local_vertical_scroll.md`
- 记录依据：基于当前工作区的 `git status --short`、本轮 6 个已修改代码文件的 `git diff`、`git diff --stat` 整理；本文不直接粘贴原始 `git diff`。
- 差异概览：`6 files changed, 365 insertions(+), 37 deletions(-)`。

## 触达范围

本轮实际修改的代码文件如下：

- `NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`

本轮修改只针对 `P-2` 模式下的下方答题指板，不改顶部五线谱，也不改其他 exercise mode。

## 修改 1：把 `P-2` 的“宽度 x2 + overflow 纵向滚动”提升为 shared layout preference

修改前，`P-2` 虽然已经固定成 `staff -> fretboard` 的 stacked 结构，但 `ExerciseLayoutPreferences` 本身并不携带“竖向指板宽度倍率”与“overflow 滚动方向”这两个显式语义。也就是说，renderer 只能沿用现有的默认竖向指板策略，无法只对 `P-2` 精准下发“宽度优先 + 组件内纵滚”的 contract。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: ExerciseLayoutPreferences / p2StaffFretboardAnswer / init(...)
// 功能说明: 修改前 P-2 只固定 composition/layout/accessory，本身不携带竖向指板宽度倍率与 overflow 方向。
struct ExerciseLayoutPreferences: Equatable, Sendable {
    var compositionPreset: ExerciseCompositionPreset
    var layoutPreset: ExerciseLayoutPreset
    var accessoryPresentation: ExerciseAccessoryPresentation
    var isNaturalNoteStripVisible: Bool
    var isPianoAccessoryVisible: Bool
    var isAccessoryExpanded: Bool

    static let p2StaffFretboardAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToFretboard,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true
    )

    init(
        compositionPreset: ExerciseCompositionPreset = .staffToFretboard,
        layoutPreset: ExerciseLayoutPreset = .sideBySide,
        accessoryPresentation: ExerciseAccessoryPresentation = .docked,
        isNaturalNoteStripVisible: Bool = false,
        isPianoAccessoryVisible: Bool = false,
        isAccessoryExpanded: Bool = true
    ) {
        // ...
    }
}
```

修改后，新增了 `ExerciseFretboardOverflowScrollAxis`，并把 `verticalFretboardWidthScale`、`verticalFretboardOverflowScrollAxis` 写进 `ExerciseLayoutPreferences`。这样 `P-2` 的 fixed layout contract 不再只是“上下两个组件”，而是显式声明了“竖向指板宽度乘 2，overflow 改走本组件内纵向滚动”。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseLayoutPreferences.swift
// 函数名/符号: ExerciseFretboardOverflowScrollAxis / ExerciseLayoutPreferences / p2StaffFretboardAnswer / init(...)
// 功能说明: 修改后 shared preference 层直接携带 P-2 专用的宽度倍率与 overflow 滚动方向，避免 renderer 写死 mode 特判。
enum ExerciseFretboardOverflowScrollAxis:
    String,
    CaseIterable,
    Equatable,
    Hashable,
    Sendable {
    case horizontal
    case vertical
}

struct ExerciseLayoutPreferences: Equatable, Sendable {
    var compositionPreset: ExerciseCompositionPreset
    var layoutPreset: ExerciseLayoutPreset
    var accessoryPresentation: ExerciseAccessoryPresentation
    var isNaturalNoteStripVisible: Bool
    var isPianoAccessoryVisible: Bool
    var isAccessoryExpanded: Bool
    var verticalFretboardWidthScale: Double
    var verticalFretboardOverflowScrollAxis: ExerciseFretboardOverflowScrollAxis

    static let p2StaffFretboardAnswer = ExerciseLayoutPreferences(
        compositionPreset: .staffToFretboard,
        layoutPreset: .stacked,
        accessoryPresentation: .docked,
        isNaturalNoteStripVisible: false,
        isPianoAccessoryVisible: false,
        isAccessoryExpanded: true,
        verticalFretboardWidthScale: 2,
        verticalFretboardOverflowScrollAxis: .vertical
    )

    init(
        compositionPreset: ExerciseCompositionPreset = .staffToFretboard,
        layoutPreset: ExerciseLayoutPreset = .sideBySide,
        accessoryPresentation: ExerciseAccessoryPresentation = .docked,
        isNaturalNoteStripVisible: Bool = false,
        isPianoAccessoryVisible: Bool = false,
        isAccessoryExpanded: Bool = true,
        verticalFretboardWidthScale: Double = 1,
        verticalFretboardOverflowScrollAxis: ExerciseFretboardOverflowScrollAxis = .horizontal
    ) {
        self.verticalFretboardWidthScale = verticalFretboardWidthScale
        self.verticalFretboardOverflowScrollAxis =
            verticalFretboardOverflowScrollAxis
    }
}
```

## 修改 2：让 presentation / scene contract 能读取这条 `P-2` 专用语义

修改前，`ExerciseFretboardLayoutContract` 只描述“是否 pin 到 viewport 高度”和“高度策略”。`ExercisePresentationState`、`ExerciseScene`、`SettingsPanelStateContext` 也都只会拿到这两个旧字段，所以 renderer 看不到 `P-2` 的宽度倍率与纵滚语义。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名/符号: ExerciseFretboardLayoutContract / ExercisePresentationState.fretboardLayoutContract / ExerciseScene.fretboardLayoutContract
// 功能说明: 修改前 contract 只表达 pin + height policy，presentation 无法把 P-2 的宽度驱动语义下发给平台层。
struct ExerciseFretboardLayoutContract: Equatable, Sendable {
    var pinsSceneToViewportHeight: Bool
    var heightPolicy: ExerciseFretboardHeightPolicy

    var usesVerticalViewportHeightControl: Bool {
        heightPolicy == .followViewportRatio
    }
}

extension ExercisePresentationState {
    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        scene.fretboardLayoutContract
    }
}

extension ExerciseScene {
    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: requiresViewportPinnedHeight,
            heightPolicy: containsMainFretboardInSideBySideLayout
                ? .fillAvailableHeight
                : .followViewportRatio
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名/符号: fretboardLayoutContract
// 功能说明: 修改前 settings stateContext 读取到的也是不含 P-2 宽度倍率语义的旧 contract。
var fretboardLayoutContract: ExerciseFretboardLayoutContract {
    let resolvedPreferences = ExerciseCompositionPolicy.normalizedPreferences(
        exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState
    )
    let scene = ExerciseCompositionPolicy.makeScene(
        preferences: resolvedPreferences
    )
    return scene.fretboardLayoutContract
}
```

修改后，`ExerciseFretboardLayoutContract` 扩展出 `verticalFretboardWidthScale`、`verticalFretboardOverflowScrollAxis`、`resolvedVerticalFretboardWidthScale` 和 `usesWidthDrivenVerticalOverflow`。同时 `ExerciseScene` 新增了带 `layoutPreferences` 入参的 contract 构造函数，`ExercisePresentationState` 与 `SettingsPanelStateContext` 都改为从 resolved preferences 读取这条新语义。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数名/符号: ExerciseFretboardLayoutContract / ExercisePresentationState.fretboardLayoutContract / ExerciseScene.fretboardLayoutContract(layoutPreferences:)
// 功能说明: 修改后 shared contract 会把 P-2 的 width x2 + local vertical scroll 语义一路传到 renderer。
struct ExerciseFretboardLayoutContract: Equatable, Sendable {
    var pinsSceneToViewportHeight: Bool
    var heightPolicy: ExerciseFretboardHeightPolicy
    var verticalFretboardWidthScale: Double
    var verticalFretboardOverflowScrollAxis: ExerciseFretboardOverflowScrollAxis

    init(
        pinsSceneToViewportHeight: Bool,
        heightPolicy: ExerciseFretboardHeightPolicy,
        verticalFretboardWidthScale: Double = 1,
        verticalFretboardOverflowScrollAxis:
            ExerciseFretboardOverflowScrollAxis = .horizontal
    ) {
        self.pinsSceneToViewportHeight = pinsSceneToViewportHeight
        self.heightPolicy = heightPolicy
        self.verticalFretboardWidthScale = verticalFretboardWidthScale
        self.verticalFretboardOverflowScrollAxis =
            verticalFretboardOverflowScrollAxis
    }

    var usesWidthDrivenVerticalOverflow: Bool {
        verticalFretboardOverflowScrollAxis == .vertical
            && resolvedVerticalFretboardWidthScale > 1
    }
}

extension ExercisePresentationState {
    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        scene.fretboardLayoutContract(
            layoutPreferences: resolvedLayoutPreferences
        )
    }
}

extension ExerciseScene {
    func fretboardLayoutContract(
        layoutPreferences: ExerciseLayoutPreferences
    ) -> ExerciseFretboardLayoutContract {
        ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: requiresViewportPinnedHeight,
            heightPolicy: containsMainFretboardInSideBySideLayout
                ? .fillAvailableHeight
                : .followViewportRatio,
            verticalFretboardWidthScale: layoutPreferences
                .verticalFretboardWidthScale,
            verticalFretboardOverflowScrollAxis: layoutPreferences
                .verticalFretboardOverflowScrollAxis
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数名/符号: fretboardLayoutContract
// 功能说明: 修改后 settings stateContext 会按 resolvedPreferences 读取完整 contract，避免 validation 仍停留在旧 pin/height 语义。
var fretboardLayoutContract: ExerciseFretboardLayoutContract {
    let resolvedPreferences = ExerciseCompositionPolicy.normalizedPreferences(
        exerciseLayoutPreferences,
        trainerDisplayState: trainerDisplayState
    )
    let scene = ExerciseCompositionPolicy.makeScene(
        preferences: resolvedPreferences
    )
    return scene.fretboardLayoutContract(
        layoutPreferences: resolvedPreferences
    )
}
```

## 修改 3：iOS renderer 从“横向局部滚动”升级为 `P-2` 专用的“宽度驱动 + 组件内纵向滚动”

修改前，iOS 竖向指板的动态链路只有 `syncVerticalFretboardContentWidthConstraint()`，核心思路是“页面先给高度，shared 几何反推出内容宽度”；scroll host 只会处理横向 overflow，并且把 `y` offset 强制钳成 `0`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名/符号: handleLayoutPass / syncVerticalFretboardContentWidthConstraint / updateFretboardViewportPresentation
// 功能说明: 修改前 iOS 竖向指板只同步 content width，并且只支持组件内横向滚动。
func handleLayoutPass() {
    syncVerticalFretboardContentWidthConstraint()
    updateFretboardViewportPresentation()
}

private func syncVerticalFretboardContentWidthConstraint() {
    guard
        isShowingFretboard,
        currentFretboardDisplayState.displayMode == .vertical,
        let verticalFretboardContentWidthConstraint
    else {
        return
    }

    let targetWidth = fretboardView.verticalContentSize.width
    guard targetWidth > 0 else {
        return
    }

    if abs(verticalFretboardContentWidthConstraint.constant - targetWidth)
        > metrics.contentSizeTolerance {
        verticalFretboardContentWidthConstraint.constant = targetWidth
    }
}

private func updateFretboardViewportPresentation() {
    let viewportWidth = fretboardViewportScrollView.bounds.width
    let contentWidth = verticalFretboardContentWidthConstraint?.constant
        ?? fretboardView.verticalContentSize.width
    let needsHorizontalScroll = contentWidth
        > viewportWidth + metrics.contentSizeTolerance

    fretboardViewportScrollView.isScrollEnabled = needsHorizontalScroll
    fretboardViewportScrollView.alwaysBounceHorizontal = needsHorizontalScroll
    fretboardViewportScrollView.showsHorizontalScrollIndicator = needsHorizontalScroll

    fretboardViewportScrollView.setContentOffset(
        CGPoint(x: clampedOffsetX, y: 0),
        animated: false
    )
}
```

修改后，iOS renderer 新增了：

- `fretboardLayoutContract` / `usesWidthDrivenVerticalOverflow` / `resolvedVerticalFretboardWidthScale`
- `fretboardScrollContentHeightMatchesViewportConstraint`
- `verticalFretboardContentHeightConstraint`
- `resolvedVerticalFretboardContentSize(forViewportHeight:)`

这样 `P-2` 才能在同一套竖向指板 host 里，从“按高度求宽度”切成“基准宽度 * 2 后再反推内容高度”，并且把 overflow 从横向转为纵向。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名/符号: fretboardLayoutContract / usesWidthDrivenVerticalOverflow / resolvedVerticalFretboardContentSize(forViewportHeight:)
// 功能说明: 修改后 iOS renderer 会读取 shared contract，只在符合 contract 时启用 width-driven vertical overflow。
private var fretboardLayoutContract: ExerciseFretboardLayoutContract {
    currentPresentationState?.fretboardLayoutContract
        ?? ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: true,
            heightPolicy: .followViewportRatio
        )
}

private var usesWidthDrivenVerticalOverflow: Bool {
    currentFretboardDisplayState.displayMode == .vertical
        && fretboardLayoutContract.usesWidthDrivenVerticalOverflow
}

private var resolvedVerticalFretboardWidthScale: CGFloat {
    CGFloat(fretboardLayoutContract.resolvedVerticalFretboardWidthScale)
}

private func resolvedVerticalFretboardContentSize(
    forViewportHeight viewportHeight: CGFloat
) -> CGSize {
    let configuration = currentFretboardDisplayState.configuration
    let baseWidth = configuration.verticalContentWidth(
        forViewportHeight: viewportHeight
    )

    guard usesWidthDrivenVerticalOverflow else {
        return CGSize(width: baseWidth, height: viewportHeight)
    }

    let scaledWidth = baseWidth * resolvedVerticalFretboardWidthScale
    return CGSize(
        width: scaledWidth,
        height: configuration.verticalContentHeight(
            forContentWidth: scaledWidth
        )
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名/符号: configureStaticHierarchy / updateFretboardLayoutModeConstraints / syncVerticalFretboardContentSizeConstraints / updateFretboardViewportPresentation
// 功能说明: 修改后 iOS scroll host 会在 P-2 下切到 content height 可变、组件内纵向滚动；其他模式仍保持原链路。
private var fretboardScrollContentHeightMatchesViewportConstraint:
    NSLayoutConstraint?
private var verticalFretboardContentHeightConstraint: NSLayoutConstraint?

func handleLayoutPass() {
    syncVerticalFretboardContentSizeConstraints()
    updateFretboardViewportPresentation()
}

private func updateFretboardLayoutModeConstraints() {
    let usesVerticalOverflow = isVertical && usesWidthDrivenVerticalOverflow
    fretboardScrollContentHeightMatchesViewportConstraint?.isActive =
        !usesVerticalOverflow
    verticalFretboardContentHeightConstraint?.isActive = usesVerticalOverflow
}

private func syncVerticalFretboardContentSizeConstraints() {
    let viewportHeight = fretboardViewportScrollView.bounds.height
    let targetContentSize = resolvedVerticalFretboardContentSize(
        forViewportHeight: viewportHeight
    )

    verticalFretboardContentWidthConstraint.constant =
        targetContentSize.width

    guard
        usesWidthDrivenVerticalOverflow,
        let verticalFretboardContentHeightConstraint
    else {
        return
    }

    verticalFretboardContentHeightConstraint.constant =
        targetContentSize.height
}

private func updateFretboardViewportPresentation() {
    let needsHorizontalScroll = contentWidth
        > viewportWidth + metrics.contentSizeTolerance
    let needsVerticalScroll = contentHeight
        > viewportHeight + metrics.contentSizeTolerance

    fretboardViewportScrollView.isScrollEnabled =
        needsHorizontalScroll || needsVerticalScroll
    fretboardViewportScrollView.alwaysBounceHorizontal = needsHorizontalScroll
    fretboardViewportScrollView.alwaysBounceVertical = needsVerticalScroll
    fretboardViewportScrollView.showsHorizontalScrollIndicator = needsHorizontalScroll
    fretboardViewportScrollView.showsVerticalScrollIndicator =
        needsVerticalScroll

    fretboardViewportScrollView.setContentOffset(
        CGPoint(x: clampedOffsetX, y: clampedOffsetY),
        animated: false
    )
}
```

## 修改 4：macOS renderer 同步切到同一条 contract，并补上 documentView 的 top-left 语义

修改前，macOS 竖向指板同样只有“宽度受内容驱动、滚动只看 X 轴”的逻辑；document view 也是普通 `NSView`，scroll helper 只会把视口滚到 `(x, 0)`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名/符号: fretboardScrollContentView / syncVerticalFretboardContentSizeConstraints / updateFretboardViewportPresentation / scrollFretboardViewport(toX:)
// 功能说明: 修改前 macOS 竖向指板只处理 document width 和 horizontal scroller，不支持组件内纵向滚动。
private let fretboardScrollContentView = NSView()

private func syncVerticalFretboardContentSizeConstraints() -> Bool {
    let viewportWidth = fretboardViewportScrollView.contentView.bounds.width
    let contentWidth = fretboardView.verticalContentSize.width
    let documentWidth = max(viewportWidth, contentWidth)

    verticalFretboardDocumentWidthConstraint.constant = documentWidth
    verticalFretboardContentWidthConstraint.constant = contentWidth
    return didUpdateConstraints
}

private func updateFretboardViewportPresentation() -> Bool {
    let needsHorizontalScroll = contentWidth
        > viewportWidth + metrics.contentSizeTolerance
    fretboardViewportScrollView.hasHorizontalScroller = needsHorizontalScroll

    let clampedOffsetX = needsHorizontalScroll
        ? min(max(currentOffsetX, 0), maxOffsetX)
        : 0
    scrollFretboardViewport(toX: clampedOffsetX)
    return didToggleScroller
}

private func scrollFretboardViewport(toX x: CGFloat) {
    fretboardViewportScrollView.contentView.scroll(to: CGPoint(x: x, y: 0))
    fretboardViewportScrollView.reflectScrolledClipView(
        fretboardViewportScrollView.contentView
    )
}
```

修改后，macOS 端除了同步 iOS 那条 width-driven vertical overflow contract 外，还额外做了两件事：

1. 引入 `FretboardScrollContentView: NSView` 并覆写 `isFlipped = true`，让 document view 的坐标语义与 shared vertical scene 的 top-left 语义一致。
2. 补上 `verticalFretboardDocumentHeightConstraint`、`hasVerticalScroller`、`scrollFretboardViewport(toX:y:)`，把纵向 overflow 真正落进组件内部。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名/符号: FretboardScrollContentView / fretboardScrollContentView / verticalFretboardDocumentHeightConstraint
// 功能说明: 修改后 macOS documentView 改成 flipped 容器，并补齐 document height 约束，为组件内纵向滚动提供几何基础。
private final class FretboardScrollContentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private let fretboardScrollContentView = FretboardScrollContentView()
private var fretboardScrollContentHeightMatchesViewportConstraint:
    NSLayoutConstraint?
private var verticalFretboardDocumentHeightConstraint: NSLayoutConstraint?

private func configureStaticHierarchy() {
    fretboardScrollContentHeightMatchesViewportConstraint =
        fretboardScrollContentView.heightAnchor.constraint(
            equalTo: fretboardViewportScrollView.contentView.heightAnchor
        )
    verticalFretboardDocumentHeightConstraint =
        fretboardScrollContentView.heightAnchor.constraint(
            equalToConstant: currentFretboardDisplayState.configuration.preferredHeight
        )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名/符号: updateFretboardLayoutModeConstraints / syncVerticalFretboardContentSizeConstraints / updateFretboardViewportPresentation / scrollFretboardViewport(toX:y:)
// 功能说明: 修改后 macOS 会在 P-2 下启用 width x2 + document height + local vertical scroll；非 P-2 不受影响。
private func updateFretboardLayoutModeConstraints() {
    let usesVerticalOverflow = isVertical && usesWidthDrivenVerticalOverflow
    fretboardScrollContentHeightMatchesViewportConstraint?.isActive =
        !usesVerticalOverflow
    verticalFretboardDocumentHeightConstraint?.isActive = usesVerticalOverflow
    fretboardViewportScrollView.hasVerticalScroller = false
}

private func syncVerticalFretboardContentSizeConstraints() -> Bool {
    let targetContentSize = resolvedVerticalFretboardContentSize(
        forViewportHeight: viewportHeight
    )
    let documentWidth = max(viewportWidth, targetContentSize.width)

    verticalFretboardDocumentWidthConstraint.constant = documentWidth
    verticalFretboardContentWidthConstraint.constant = targetContentSize.width

    if usesWidthDrivenVerticalOverflow,
       let verticalFretboardDocumentHeightConstraint {
        verticalFretboardDocumentHeightConstraint.constant =
            targetContentSize.height
    }

    return didUpdateConstraints
}

private func updateFretboardViewportPresentation() -> Bool {
    let needsHorizontalScroll = contentWidth
        > viewportWidth + metrics.contentSizeTolerance
    let needsVerticalScroll = contentHeight
        > viewportHeight + metrics.contentSizeTolerance

    fretboardViewportScrollView.hasHorizontalScroller = needsHorizontalScroll
    fretboardViewportScrollView.hasVerticalScroller = needsVerticalScroll

    let clampedOffsetX = needsHorizontalScroll
        ? min(max(currentOffsetX, 0), maxOffsetX)
        : 0
    let clampedOffsetY = needsVerticalScroll
        ? min(max(currentOffsetY, 0), maxOffsetY)
        : 0

    scrollFretboardViewport(toX: clampedOffsetX, y: clampedOffsetY)
    return didToggleHorizontalScroller || didToggleVerticalScroller
}

private func scrollFretboardViewport(toX x: CGFloat, y: CGFloat) {
    fretboardViewportScrollView.contentView.scroll(to: CGPoint(x: x, y: y))
    fretboardViewportScrollView.reflectScrolledClipView(
        fretboardViewportScrollView.contentView
    )
}
```

## 修改 5：把这条 `P-2` 专用 contract 固定进 validation，防止以后静默回退

修改前，`ExerciseCompositionValidationExercisePolicy` 只校验 `P-2` 是否仍然落在 `p2StaffFretboardAnswer` 这个 fixed layout preference 上，但不会继续确认“宽度 x2 + local vertical scroll”这层 renderer 依赖的 contract 语义。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateLegacyBaseline(fixtureName:exerciseMode:expectedPageDisplayState:)
// 功能说明: 修改前 validation 只断言 P-2 的 fixed layout preference，没有继续锁住竖向指板的宽度倍率与 overflow 方向。
if stateContext.exerciseLayoutPreferences != .p2StaffFretboardAnswer {
    issues.append(
        issue(
            fixtureName,
            "P-2 的 legacy baseline 应继续收敛到固定的 `staffToFretboard + stacked` layout contract。"
        )
    )
}
```

修改后，validation 会继续断言 `stateContext.fretboardLayoutContract` 必须是：

- `pinsSceneToViewportHeight: true`
- `heightPolicy: .followViewportRatio`
- `verticalFretboardWidthScale: 2`
- `verticalFretboardOverflowScrollAxis: .vertical`

并且显式要求 `usesWidthDrivenVerticalOverflow == true`，防止后面有人保留 `P-2` mode 与 stacked scene，但把这次真正需要的答题指板几何 contract 又悄悄退回旧行为。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名/符号: validateLegacyBaseline(fixtureName:exerciseMode:expectedPageDisplayState:)
// 功能说明: 修改后 validation 会把 P-2 下方答题指板的 width x2 + local vertical scroll 语义一并锁住。
if stateContext.exerciseLayoutPreferences != .p2StaffFretboardAnswer {
    issues.append(
        issue(
            fixtureName,
            "P-2 的 legacy baseline 应继续收敛到固定的 `staffToFretboard + stacked` layout contract。"
        )
    )
}

if stateContext.fretboardLayoutContract
    != ExerciseFretboardLayoutContract(
        pinsSceneToViewportHeight: true,
        heightPolicy: .followViewportRatio,
        verticalFretboardWidthScale: 2,
        verticalFretboardOverflowScrollAxis: .vertical
    )
    || !stateContext.fretboardLayoutContract
    .usesWidthDrivenVerticalOverflow {
    issues.append(
        issue(
            fixtureName,
            "P-2 的 fixed presentation contract 应继续把下方竖向指板切到 `width x2 + local vertical scroll` 语义。"
        )
    )
}
```

## 验证结果

本轮在代码修改后执行了以下构建验证：

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS" build`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`

结果：两端构建均通过。

构建日志中仍存在若干项目内既有 warning（例如 actor isolation、deprecated API 等），本轮没有新增编译错误。

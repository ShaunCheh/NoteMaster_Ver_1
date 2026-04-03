# 20260403_172300_stage5_scheme_c_renderer_host_alignment_single_source

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_172300`
- 记录范围：只记录方案 C 的阶段5代码改动，即清理 renderer 与 host 对齐耦合，把平台渲染侧的 rail 几何真相统一收口到 `naturalNoteStripRailLayout`
- 本记录中的“修改前”：
- 对 `macOSNaturalNoteStripView.swift` / `iOSNaturalNoteStripView.swift`，指上一轮 `20260403_170534_stage4_scheme_c_platform_vertical_rail_placement.md` 记录完成后的代码状态
- 对 renderer 与 shared helper，指本轮阶段5开始前的代码状态
- 当前 `git status` 中还包含计划文件 `/.cursor/plans/rail_placement_phases_c_51a1bd19.plan.md`；该文件不属于本记录范围，本记录只说明本轮实际代码改动
- 本记录不放原始 `git diff`，只按真实代码状态说明“修改前 / 修改后”
- 本轮代码改动文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- 本轮相关代码文件状态（`git status --short`）：
- `M NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`
- `M NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `M NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- `M NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `M NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- 本轮 `git diff --stat`（仅上述代码文件）：`5 files changed, 71 insertions(+), 49 deletions(-)`

## 1. 本轮目标

- 阶段4已经让双端 `NaturalNoteStripView` 开始渲染 shared placement，但平台 view 仍然保留了一条“从 `railContract` 再转成 layout”的本地推导路径。
- renderer 侧也仍在直接读取 `naturalNoteStripRailContract` 判断 host 是否应该纵向居中。
- 阶段5的目标，是把这两处并存的几何来源收口成一份 shared 真相：`naturalNoteStripRailLayout`。

## 2. 修改一：在 shared layout 上补齐平台层真正需要的 helper

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数/符号: extension ExerciseNaturalNoteStripRailLayout
// 修改前说明:
// 1. 平台层只能拿到 contentSize 和 placements。
// 2. renderer 仍然只能回退去读 contract 判断 host 是否 vertical centered。
// 3. button extent 也没有从 shared layout 暴露统一 helper。
extension ExerciseNaturalNoteStripRailLayout {
    static func build(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        ExerciseNaturalNoteStripRailLayoutBuilder.build(from: context)
    }
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift
// 函数/符号: extension ExerciseNaturalNoteStripRailLayout
// 修改后说明:
// 1. `buttonExtent` 让平台按钮尺寸、字体、圆角都能直接读 shared layout。
// 2. `usesVerticallyCenteredHostLayout` 让 renderer 不再直接碰 rail contract。
extension ExerciseNaturalNoteStripRailLayout {
    var buttonExtent: Double {
        context.geometry.resolvedButtonExtent
    }

    var usesVerticallyCenteredHostLayout: Bool {
        context.hostVerticalAlignment == .centered
    }

    static func build(
        from context: ExerciseNaturalNoteStripRailLayoutContext
    ) -> ExerciseNaturalNoteStripRailLayout {
        ExerciseNaturalNoteStripRailLayoutBuilder.build(from: context)
    }
}
```

## 3. 修改二：macOS `NaturalNoteStripView` 从“持有 contract”切到“持有 layout”

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - macOSNaturalNoteStripView.railContract
// - macOSNaturalNoteStripView.activeRailLayout
// - macOSNaturalNoteStripView.applyRailContract(_:)
// - macOSNaturalNoteStripView.makeButton(for:)
// 修改前说明:
// 1. 虽然 vertical rail 已经开始消费 placement frame，但 view 仍然保存 rail contract。
// 2. `activeRailLayout` 依然是在平台层现算 `defaultLayoutContext.resolvedLayout`。
// 3. renderer 传给 view 的入口还是 `applyRailContract(_:)`。
private var railContract: ExerciseNaturalNoteStripRailContract =
    .defaultSideBySideAnswerRail {
    didSet {
        guard oldValue != railContract else {
            return
        }
        applyLayoutMode()
    }
}

private var activeRailContract: ExerciseNaturalNoteStripRailContract {
    railContract
}

private var activeRailLayout: ExerciseNaturalNoteStripRailLayout {
    activeRailContract.defaultLayoutContext.resolvedLayout
}

func applyRailContract(_ railContract: ExerciseNaturalNoteStripRailContract?) {
    self.railContract = railContract ?? .defaultSideBySideAnswerRail
}

private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
    let button = NaturalNoteButton(frame: .zero)
    button.apply(pitchClass: pitchClass)
    button.applyLayoutMode(layoutMode, railContract: activeRailContract)
    button.target = self
    button.action = #selector(handleButtonTap(_:))
    return button
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - defaultNaturalNoteStripRailLayout
// - macOSNaturalNoteStripView.railLayout
// - macOSNaturalNoteStripView.activeRailLayout
// - macOSNaturalNoteStripView.applyRailLayout(_:)
// - macOSNaturalNoteStripView.makeButton(for:)
// 修改后说明:
// 1. view 直接持有 `ExerciseNaturalNoteStripRailLayout`，不再保留 rail contract 作为平台渲染真相。
// 2. renderer 传入的入口改成 `applyRailLayout(_:)`。
// 3. 默认值也从“默认 contract”切成“默认 layout”。
private let defaultNaturalNoteStripRailLayout =
    ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
        .defaultLayoutContext
        .resolvedLayout

private var railLayout: ExerciseNaturalNoteStripRailLayout =
    defaultNaturalNoteStripRailLayout {
    didSet {
        guard oldValue != railLayout else {
            return
        }
        applyLayoutMode()
    }
}

private var activeRailLayout: ExerciseNaturalNoteStripRailLayout {
    railLayout
}

func applyRailLayout(_ railLayout: ExerciseNaturalNoteStripRailLayout?) {
    self.railLayout = railLayout ?? defaultNaturalNoteStripRailLayout
}

private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
    let button = NaturalNoteButton(frame: .zero)
    button.apply(pitchClass: pitchClass)
    button.applyLayoutMode(layoutMode, railLayout: activeRailLayout)
    button.target = self
    button.action = #selector(handleButtonTap(_:))
    return button
}
```

### 3.3 按钮子视图修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - NaturalNoteButton.railContract
// - NaturalNoteButton.intrinsicContentSize
// - NaturalNoteButton.applyLayoutMode(_:railContract:)
// - NaturalNoteButton.resolvedFont()
// - NaturalNoteButton.resolvedCornerRadius()
// 修改前说明:
// 1. 按钮尺寸、字体和圆角仍然直接读 railContract.buttonExtent。
// 2. 这会让 shared placement 与平台按钮外观各自再持有一份 button extent 来源。
private var railContract: ExerciseNaturalNoteStripRailContract =
    .defaultSideBySideAnswerRail

override var intrinsicContentSize: NSSize {
    switch layoutMode {
    case .horizontalStrip:
        // ... 省略未改动代码 ...
        return size
    case .verticalRail:
        let buttonExtent = CGFloat(railContract.buttonExtent)
        return NSSize(width: buttonExtent, height: buttonExtent)
    }
}

func applyLayoutMode(
    _ layoutMode: macOSNaturalNoteStripView.LayoutMode,
    railContract: ExerciseNaturalNoteStripRailContract
) {
    self.layoutMode = layoutMode
    self.railContract = railContract
    // ... 省略未改动代码 ...
}

private func resolvedFont() -> NSFont {
    switch layoutMode {
    case .horizontalStrip:
        return NSFont.systemFont(ofSize: Style.fontSize, weight: .medium)
    case .verticalRail:
        let railFontSize = min(
            Style.fontSize,
            max(9, CGFloat(railContract.buttonExtent) * 0.55)
        )
        return NSFont.systemFont(ofSize: railFontSize, weight: .medium)
    }
}

private func resolvedCornerRadius() -> CGFloat {
    switch layoutMode {
    case .horizontalStrip:
        return Style.buttonCornerRadius
    case .verticalRail:
        return CGFloat(railContract.buttonExtent) / 2
    }
}
```

### 3.4 按钮子视图修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号:
// - NaturalNoteButton.railLayout
// - NaturalNoteButton.activeRailButtonExtent
// - NaturalNoteButton.intrinsicContentSize
// - NaturalNoteButton.applyLayoutMode(_:railLayout:)
// - NaturalNoteButton.resolvedFont()
// - NaturalNoteButton.resolvedCornerRadius()
// 修改后说明:
// 1. 按钮侧也完全切到 shared layout，不再自己读 contract。
// 2. `buttonExtent` 只剩一份 shared 来源，避免 view / button / renderer 三处漂移。
private var railLayout: ExerciseNaturalNoteStripRailLayout =
    defaultNaturalNoteStripRailLayout

private var activeRailButtonExtent: CGFloat {
    CGFloat(railLayout.buttonExtent)
}

override var intrinsicContentSize: NSSize {
    switch layoutMode {
    case .horizontalStrip:
        // ... 省略未改动代码 ...
        return size
    case .verticalRail:
        return NSSize(
            width: activeRailButtonExtent,
            height: activeRailButtonExtent
        )
    }
}

func applyLayoutMode(
    _ layoutMode: macOSNaturalNoteStripView.LayoutMode,
    railLayout: ExerciseNaturalNoteStripRailLayout
) {
    self.layoutMode = layoutMode
    self.railLayout = railLayout
    // ... 省略未改动代码 ...
}

private func resolvedFont() -> NSFont {
    switch layoutMode {
    case .horizontalStrip:
        return NSFont.systemFont(ofSize: Style.fontSize, weight: .medium)
    case .verticalRail:
        let railFontSize = min(
            Style.fontSize,
            max(9, activeRailButtonExtent * 0.55)
        )
        return NSFont.systemFont(ofSize: railFontSize, weight: .medium)
    }
}

private func resolvedCornerRadius() -> CGFloat {
    switch layoutMode {
    case .horizontalStrip:
        return Style.buttonCornerRadius
    case .verticalRail:
        return activeRailButtonExtent / 2
    }
}
```

## 4. 修改三：iOS `NaturalNoteStripView` 做对等收口

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - iOSNaturalNoteStripView.railContract
// - iOSNaturalNoteStripView.activeRailLayout
// - iOSNaturalNoteStripView.applyRailContract(_:)
// - iOSNaturalNoteStripView.makeButton(for:)
// 修改前说明:
// 1. iOS 端与 macOS 端相同，平台 view 仍然持有 contract。
// 2. layout 依然是在 view 层从 contract 推出来的。
private var railContract: ExerciseNaturalNoteStripRailContract =
    .defaultSideBySideAnswerRail {
    didSet {
        guard oldValue != railContract else {
            return
        }
        applyLayoutMode()
    }
}

private var activeRailContract: ExerciseNaturalNoteStripRailContract {
    railContract
}

private var activeRailLayout: ExerciseNaturalNoteStripRailLayout {
    activeRailContract.defaultLayoutContext.resolvedLayout
}

func applyRailContract(_ railContract: ExerciseNaturalNoteStripRailContract?) {
    self.railContract = railContract ?? .defaultSideBySideAnswerRail
}

private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
    let button = NaturalNoteButton(frame: .zero)
    button.apply(pitchClass: pitchClass)
    button.applyLayoutMode(layoutMode, railContract: activeRailContract)
    button.addTarget(
        self,
        action: #selector(handleButtonTap(_:)),
        for: .touchUpInside
    )
    return button
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - defaultNaturalNoteStripRailLayout
// - iOSNaturalNoteStripView.railLayout
// - iOSNaturalNoteStripView.activeRailLayout
// - iOSNaturalNoteStripView.applyRailLayout(_:)
// - iOSNaturalNoteStripView.makeButton(for:)
// 修改后说明:
// 1. iOS 端对齐 macOS：view 直接持有 shared layout。
// 2. 平台渲染入口改为 `applyRailLayout(_:)`，去掉 contract 到 layout 的二次投影。
private let defaultNaturalNoteStripRailLayout =
    ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
        .defaultLayoutContext
        .resolvedLayout

private var railLayout: ExerciseNaturalNoteStripRailLayout =
    defaultNaturalNoteStripRailLayout {
    didSet {
        guard oldValue != railLayout else {
            return
        }
        applyLayoutMode()
    }
}

private var activeRailLayout: ExerciseNaturalNoteStripRailLayout {
    railLayout
}

func applyRailLayout(_ railLayout: ExerciseNaturalNoteStripRailLayout?) {
    self.railLayout = railLayout ?? defaultNaturalNoteStripRailLayout
}

private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
    let button = NaturalNoteButton(frame: .zero)
    button.apply(pitchClass: pitchClass)
    button.applyLayoutMode(layoutMode, railLayout: activeRailLayout)
    button.addTarget(
        self,
        action: #selector(handleButtonTap(_:)),
        for: .touchUpInside
    )
    return button
}
```

### 4.3 按钮子视图修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - NaturalNoteButton.railContract
// - NaturalNoteButton.intrinsicContentSize
// - NaturalNoteButton.applyLayoutMode(_:railContract:)
// - NaturalNoteButton.resolvedTitleFont()
// 修改前说明:
// 1. iOS 按钮尺寸与字体也还在直接读 railContract.buttonExtent。
// 2. shared layout 已经算好的按钮尺寸没有成为平台唯一来源。
private var railContract: ExerciseNaturalNoteStripRailContract =
    .defaultSideBySideAnswerRail

override var intrinsicContentSize: CGSize {
    switch layoutMode {
    case .horizontalStrip:
        return super.intrinsicContentSize
    case .verticalRail:
        let buttonExtent = CGFloat(railContract.buttonExtent)
        return CGSize(width: buttonExtent, height: buttonExtent)
    }
}

func applyLayoutMode(
    _ layoutMode: iOSNaturalNoteStripView.LayoutMode,
    railContract: ExerciseNaturalNoteStripRailContract
) {
    self.layoutMode = layoutMode
    self.railContract = railContract
    // ... 省略未改动代码 ...
}

private func resolvedTitleFont() -> UIFont {
    switch layoutMode {
    case .horizontalStrip:
        return UIFont.systemFont(ofSize: Style.fontSize, weight: .medium)
    case .verticalRail:
        let railFontSize = min(
            Style.fontSize,
            max(9, CGFloat(railContract.buttonExtent) * 0.55)
        )
        return UIFont.systemFont(ofSize: railFontSize, weight: .medium)
    }
}
```

### 4.4 按钮子视图修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号:
// - NaturalNoteButton.railLayout
// - NaturalNoteButton.activeRailButtonExtent
// - NaturalNoteButton.intrinsicContentSize
// - NaturalNoteButton.applyLayoutMode(_:railLayout:)
// - NaturalNoteButton.resolvedTitleFont()
// 修改后说明:
// 1. iOS 按钮尺寸、字体也改为直接消费 shared layout。
// 2. `buttonExtent` 不再在平台按钮层重复读取 contract。
private var railLayout: ExerciseNaturalNoteStripRailLayout =
    defaultNaturalNoteStripRailLayout

private var activeRailButtonExtent: CGFloat {
    CGFloat(railLayout.buttonExtent)
}

override var intrinsicContentSize: CGSize {
    switch layoutMode {
    case .horizontalStrip:
        return super.intrinsicContentSize
    case .verticalRail:
        return CGSize(
            width: activeRailButtonExtent,
            height: activeRailButtonExtent
        )
    }
}

func applyLayoutMode(
    _ layoutMode: iOSNaturalNoteStripView.LayoutMode,
    railLayout: ExerciseNaturalNoteStripRailLayout
) {
    self.layoutMode = layoutMode
    self.railLayout = railLayout
    // ... 省略未改动代码 ...
}

private func resolvedTitleFont() -> UIFont {
    switch layoutMode {
    case .horizontalStrip:
        return UIFont.systemFont(ofSize: Style.fontSize, weight: .medium)
    case .verticalRail:
        let railFontSize = min(
            Style.fontSize,
            max(9, activeRailButtonExtent * 0.55)
        )
        return UIFont.systemFont(ofSize: railFontSize, weight: .medium)
    }
}
```

## 5. 修改四：双端 renderer 的 host 对齐判断改为读 shared layout

### 5.1 macOS renderer 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数/符号:
// - macOSExerciseSceneRenderer.hostedViewLayout(for:)
// - macOSExerciseSceneRenderer.configurePresentationStyle(for:)
// 修改前说明:
// 1. renderer 直接读取 naturalNoteStripRailContract。
// 2. host 居中语义与平台 view 内部 layout 真相并不是同一个出口。
private func hostedViewLayout(
    for surface: ExerciseSurfaceNode
) -> HostedViewLayout {
    guard
        surface.id == .naturalNoteStrip,
        surface.presentationStyle == .verticalRail,
        let railContract = currentPresentationState?.naturalNoteStripRailContract,
        railContract.appliesToSurface == .naturalNoteStrip,
        railContract.mainAxisPolicy == .contentSized,
        railContract.verticalAlignment == .centered
    else {
        return .fill
    }

    return .verticallyCentered
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
    naturalNoteStripView.applyRailContract(
        currentPresentationState?.naturalNoteStripRailContract
    )
}
```

### 5.2 macOS renderer 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数/符号:
// - macOSExerciseSceneRenderer.hostedViewLayout(for:)
// - macOSExerciseSceneRenderer.configurePresentationStyle(for:)
// 修改后说明:
// 1. host 对齐只认 `naturalNoteStripRailLayout` 暴露出来的 shared helper。
// 2. renderer 不再成为第二个 rail contract 解释器。
private func hostedViewLayout(
    for surface: ExerciseSurfaceNode
) -> HostedViewLayout {
    guard
        surface.isNaturalNoteStripAnswerRail,
        currentPresentationState?.naturalNoteStripRailLayout?
            .usesVerticallyCenteredHostLayout == true
    else {
        return .fill
    }

    return .verticallyCentered
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
    naturalNoteStripView.applyRailLayout(
        currentPresentationState?.naturalNoteStripRailLayout
    )
}
```

### 5.3 iOS renderer 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数/符号:
// - iOSExerciseSceneRenderer.embeddedViewLayout(for:)
// - iOSExerciseSceneRenderer.configurePresentationStyle(for:)
// 修改前说明:
// 1. iOS renderer 同样直接看 rail contract。
// 2. host 垂直居中语义与 shared layout 输出还没有完全收口。
private func embeddedViewLayout(
    for surface: ExerciseSurfaceNode
) -> EmbeddedViewLayout {
    guard
        surface.id == .naturalNoteStrip,
        surface.presentationStyle == .verticalRail,
        let railContract = currentPresentationState?.naturalNoteStripRailContract,
        railContract.appliesToSurface == .naturalNoteStrip,
        railContract.mainAxisPolicy == .contentSized,
        railContract.verticalAlignment == .centered
    else {
        return .fill
    }

    return .verticallyCentered
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
    naturalNoteStripView.applyRailContract(
        currentPresentationState?.naturalNoteStripRailContract
    )
}
```

### 5.4 iOS renderer 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数/符号:
// - iOSExerciseSceneRenderer.embeddedViewLayout(for:)
// - iOSExerciseSceneRenderer.configurePresentationStyle(for:)
// 修改后说明:
// 1. iOS renderer 与 macOS 对齐，统一改读 shared layout。
// 2. renderer 与 platform view 现在都只从同一份 rail layout 读取 host / content 语义。
private func embeddedViewLayout(
    for surface: ExerciseSurfaceNode
) -> EmbeddedViewLayout {
    guard
        surface.isNaturalNoteStripAnswerRail,
        currentPresentationState?.naturalNoteStripRailLayout?
            .usesVerticallyCenteredHostLayout == true
    else {
        return .fill
    }

    return .verticallyCentered
}

private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
    naturalNoteStripView.applyRailLayout(
        currentPresentationState?.naturalNoteStripRailLayout
    )
}
```

## 6. 本轮结果

- `NaturalNoteStripView` 不再从 `ExerciseNaturalNoteStripRailContract` 临时推导 `ExerciseNaturalNoteStripRailLayout`
- 双端按钮尺寸、字体、圆角与 rail host 对齐，统一改由 shared layout 驱动
- renderer 不再并行解释 rail contract，从而避免出现“shared contract 一份、platform view 一份、renderer 又判断一份”的三源漂移
- 阶段4引入的 `railCanvasView` 保留不变；阶段5只收口真相来源，不再改 rail placement 几何本身

## 7. 验证结果

- `ReadLints` 检查以下 5 个改动文件：无 linter 错误
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`

```bash
# 文件路径: （无，命令行验证）
# 函数/符号: macOS Debug build
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO
```

- 构建结果：`BUILD SUCCEEDED`

```bash
# 文件路径: （无，命令行验证）
# 函数/符号: iOS Simulator Debug build
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO
```

- 构建结果：`BUILD SUCCEEDED`
- macOS 启动期 validation 实跑结果：
- `FretboardValidation automated=PASS fixtures=7`
- `StaffValidation automated=PASS fixtures=57`
- `SettingsNavigationValidation automated=PASS fixtures=11`
- `PianoValidation automated=PASS fixtures=27`
- `ExerciseCompositionValidation automated=PASS fixtures=27`

```bash
# 文件路径: （无，命令行验证）
# 函数/符号: macOS runtime smoke
NSUnbufferedIO=YES NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression \
"/Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1/.phase5-smoke/Build/Products/Debug/NoteMaster_Ver_1.app/Contents/MacOS/NoteMaster_Ver_1"
```

- macOS runtime smoke 实跑结果：`PASS scenario=layout_preset_regression finalLayout=sideBySide`
- 覆盖场景：
- `sideBySide -> stacked -> sideBySide`
- 窗口宽度放大 / 缩小
- 最终回到 `sideBySide`
- iOS runtime smoke：本轮未能实跑；当前环境里的 `CoreSimulatorService` 不可用，`simctl` 无法正常访问 simulator device set
- 本轮临时生成的 `.phase5-smoke` 构建目录已在记录完成前删除，不属于保留改动

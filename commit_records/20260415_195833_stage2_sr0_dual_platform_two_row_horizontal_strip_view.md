# 20260415_195833_stage2_sr0_dual_platform_two_row_horizontal_strip_view

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260415_195833`
- 记录依据：基于当前工作区 `git status --short`、阶段 2 四个文件的 `git diff --stat`、按文件分组的 `git diff --unified=20`、当前文件内容，以及本轮 `ReadLints` / `xcodebuild` 复核结果整理；不直接粘贴原始 `git diff`
- 记录范围：本次只记录 `.cursor/plans/sr0_双行strip_计划_632caead.plan.md` 实施阶段 2 的真实落地代码改动；目标是在 iOS / macOS 上把 `horizontalStrip` 升级成消费 shared horizontal layout 的双行容器，同时保持 `verticalRail` 的旧语义与 frame-based rail 布局不变
- 当前涉及文件相对 `HEAD` 的累计 diff 统计：`4 files changed, 317 insertions(+), 88 deletions(-)`
- 统计口径说明：
- 当前 `git status --short` 只包含下面这 4 个 `Swift` 文件，因此本次统计口径直接等同于阶段 2 改动集
- 本记录文件本身是新增 markdown 记录，不计入上面的 `4 files changed`
- 本次实际代码修改文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift`
- 本次未改动但刻意保持不动的文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseNaturalNoteStripRailPlacement.swift`：阶段 1 已经定义 shared horizontal layout，本轮只消费 contract，不再回改 shared 模型
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`：不再新增 display-state seam，直接复用阶段 1 已暴露的 `naturalNoteStripHorizontalLayout`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionPolicy.swift`：阶段 2 不提前引入 `SR-0` mode / `staffToNaturalNoteStrip` preset 的主场景组合
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`、`NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`：本轮不增加新 fixture，先把平台视图消费 shared layout 的链路打通
- `NoteMaster_Ver_1/Shared/Scene/SceneCore.swift`：阶段 0 已冻结 `horizontalStrip / verticalRail` 语义，本轮不再改枚举边界
- 验证结果：
- `ReadLints`：对本轮 4 个改动文件读取诊断，无错误
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "platform=macOS" -derivedDataPath "/tmp/NoteMasterSR0Stage2-mac-build" build`：`BUILD SUCCEEDED`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" -derivedDataPath "/tmp/NoteMasterSR0Stage2-ios-build" build`：`BUILD SUCCEEDED`
- 本次没做的事情：
- 没有修改 `.cursor/plans/sr0_双行strip_计划_632caead.plan.md`
- 没有新增 `SR-0` mode、`staffToNaturalNoteStrip` preset、判题路由或设置项
- 没有改动 shared horizontal layout 的数据结构、geometry token、行拓扑或 validation fixture
- 没有改变 `verticalRail` 的 rail placement、`contentSize` 语义和手动 frame 布局路径
- 没有提交代码

## 本次结论

- iOS / macOS 的 `horizontalStrip` 都不再把 12 个按钮直接平铺成单行，而是改成“上排半音、下排自然音”的双行容器
- 两个平台都开始消费 `currentPresentationState?.naturalNoteStripHorizontalLayout`，让内边距、行距、列距、标题显隐和 `contentSize` 高度统一来自 shared contract
- `verticalRail` 仍然沿用既有 railLayout + manual frame 路径，没有被双行 strip 逻辑污染
- macOS renderer 的 natural-note-strip 接口从“分两步下发 style / railLayout”收敛成与 iOS 一致的 `applyConfiguration(...)`

## 修改 1：`iOSNaturalNoteStripView` 从单行 strip 升级为 shared 双行 strip

### 修改前

- `horizontalStrip` 没有自己的 shared layout 输入
- 高度只按“顶部 margin + 最高按钮 + 底部 margin”估算
- 所有按钮直接塞进一个横向 `UIStackView`
- 标题显隐没有读取 `horizontalPlacement.showsTitle`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名/符号: iOSNaturalNoteStripView.applyConfiguration / intrinsicContentSize / applyCurrentConfiguration / syncButtonContainer / resolvedVisibleTitle
// 功能说明: 修改前 iOS horizontalStrip 只是单行 stack；
// 只接收 railLayout，不消费 shared horizontal layout。
private let defaultNaturalNoteStripRailLayout =
    ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
        .defaultLayoutContext
        .resolvedLayout

final class iOSNaturalNoteStripView: UIView {
    private var layoutMode: LayoutMode = .horizontalStrip
    private var railLayout: ExerciseNaturalNoteStripRailLayout =
        defaultNaturalNoteStripRailLayout

    override var intrinsicContentSize: CGSize {
        switch layoutMode {
        case .horizontalStrip:
            return CGSize(
                width: UIView.noIntrinsicMetric,
                height: directionalLayoutMargins.top
                    + tallestButtonIntrinsicHeight
                    + directionalLayoutMargins.bottom
            )
        case .verticalRail:
            return CGSize(
                width: verticalRailIntrinsicWidth,
                height: verticalRailIntrinsicHeight
            )
        }
    }

    private let stackView = UIStackView()
    private let railCanvasView = UIView()

    func applyConfiguration(
        presentationStyle: ExerciseSurfacePresentationStyle,
        railLayout: ExerciseNaturalNoteStripRailLayout?
    ) {
        let nextLayoutMode = resolvedLayoutMode(for: presentationStyle)
        let nextRailLayout = railLayout ?? defaultNaturalNoteStripRailLayout
        guard
            layoutMode != nextLayoutMode
                || self.railLayout != nextRailLayout
        else {
            return
        }

        layoutMode = nextLayoutMode
        self.railLayout = nextRailLayout
        applyCurrentConfiguration()
    }

    private func applyCurrentConfiguration() {
        switch layoutMode {
        case .horizontalStrip:
            stackView.axis = .horizontal
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
        case .verticalRail:
            stackView.axis = .vertical
            stackView.alignment = .center
            stackView.distribution = .fill
        }

        syncButtonContainer()
    }

    private func syncButtonContainer() {
        switch layoutMode {
        case .horizontalStrip:
            stackView.isHidden = false
            railCanvasView.isHidden = true
            buttons.forEach { button in
                detachButtonFromCurrentContainer(button)
                prepareButtonForStackViewLayout(button)
                stackView.addArrangedSubview(button)
            }
        case .verticalRail:
            // ... 省略未变 rail 路径 ...
            break
        }
    }

    private func resolvedVisibleTitle(for pitchClass: PitchClass?) -> String {
        guard let pitchClass else { return "" }

        switch layoutMode {
        case .horizontalStrip:
            return pitchClass.stripVisibleTitle
        case .verticalRail:
            return pitchClass.stripVisibleTitle(
                showsTitle: railPlacement(for: pitchClass)?.showsTitle ?? false
            )
        }
    }
}
```

### 修改后

- 新增默认 `defaultNaturalNoteStripHorizontalLayout`
- `applyConfiguration` 同时接收 `presentationStyle / horizontalLayout / railLayout`
- `horizontalStrip` 变成纵向主 stack + 两个横向 row stack
- 高度、margins、row/column spacing、标题显隐都从 shared horizontal layout 读出来

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名/符号: iOSNaturalNoteStripView.applyConfiguration / applyCurrentConfiguration / syncHorizontalStripRows / configureHorizontalStripContainer
// 功能说明: 修改后 iOS horizontalStrip 消费 shared 双行布局；
// 上排放半音按钮，下排放自然音按钮，且标题显隐由 horizontal placement 决定。
private let defaultNaturalNoteStripHorizontalLayout =
    ExerciseNaturalNoteStripHorizontalLayoutContext(
        appliesToSurface: .naturalNoteStrip,
        titleDisplayPolicy:
            ExerciseNaturalNoteStripHorizontalLayoutContext
            .defaultTitleDisplayPolicy,
        geometry: .defaultTwoRowHorizontalStrip(),
        accidentalPitchClasses: PitchClass.accidentalCasesInOrder,
        naturalPitchClasses: PitchClass.naturalCasesInOrder
    ).resolvedLayout

final class iOSNaturalNoteStripView: UIView {
    private var layoutMode: LayoutMode = .horizontalStrip
    private var horizontalLayout: ExerciseNaturalNoteStripHorizontalLayout =
        defaultNaturalNoteStripHorizontalLayout
    private var railLayout: ExerciseNaturalNoteStripRailLayout =
        defaultNaturalNoteStripRailLayout

    private let stackView = UIStackView()
    private let accidentalRowStackView = UIStackView()
    private let naturalRowStackView = UIStackView()
    private let railCanvasView = UIView()

    private var activeHorizontalLayout: ExerciseNaturalNoteStripHorizontalLayout {
        horizontalLayout
    }

    override var intrinsicContentSize: CGSize {
        switch layoutMode {
        case .horizontalStrip:
            return CGSize(
                width: UIView.noIntrinsicMetric,
                height: CGFloat(activeHorizontalLayout.contentSize.height)
            )
        case .verticalRail:
            return CGSize(
                width: verticalRailIntrinsicWidth,
                height: verticalRailIntrinsicHeight
            )
        }
    }

    func applyConfiguration(
        presentationStyle: ExerciseSurfacePresentationStyle,
        horizontalLayout: ExerciseNaturalNoteStripHorizontalLayout?,
        railLayout: ExerciseNaturalNoteStripRailLayout?
    ) {
        let nextLayoutMode = resolvedLayoutMode(for: presentationStyle)
        let nextHorizontalLayout =
            horizontalLayout ?? defaultNaturalNoteStripHorizontalLayout
        let nextRailLayout = railLayout ?? defaultNaturalNoteStripRailLayout
        guard
            layoutMode != nextLayoutMode
                || self.horizontalLayout != nextHorizontalLayout
                || self.railLayout != nextRailLayout
        else {
            return
        }

        layoutMode = nextLayoutMode
        self.horizontalLayout = nextHorizontalLayout
        self.railLayout = nextRailLayout
        applyCurrentConfiguration()
    }

    private func applyCurrentConfiguration() {
        switch layoutMode {
        case .horizontalStrip:
            directionalLayoutMargins = resolvedHorizontalLayoutMargins()
            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
            stackView.spacing = resolvedHorizontalRowSpacing
            accidentalRowStackView.spacing = resolvedHorizontalColumnSpacing
            naturalRowStackView.spacing = resolvedHorizontalColumnSpacing
        case .verticalRail:
            directionalLayoutMargins = Style.contentInsets
        }

        syncButtonContainer()
    }

    private func syncHorizontalStripRows() {
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            button.isHidden = true
        }

        resolvedHorizontalButtons(for: .accidentalsTop).forEach { button in
            prepareButtonForStackViewLayout(button)
            button.isHidden = false
            accidentalRowStackView.addArrangedSubview(button)
        }
        resolvedHorizontalButtons(for: .naturalsBottom).forEach { button in
            prepareButtonForStackViewLayout(button)
            button.isHidden = false
            naturalRowStackView.addArrangedSubview(button)
        }
    }

    private func resolvedVisibleTitle(for pitchClass: PitchClass?) -> String {
        guard let pitchClass else { return "" }

        switch layoutMode {
        case .horizontalStrip:
            return pitchClass.stripVisibleTitle(
                showsTitle: horizontalPlacement(for: pitchClass)?.showsTitle
                    ?? false
            )
        case .verticalRail:
            return pitchClass.stripVisibleTitle(
                showsTitle: railPlacement(for: pitchClass)?.showsTitle ?? false
            )
        }
    }

    private func configureHorizontalStripContainer() {
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually

        accidentalRowStackView.axis = .horizontal
        accidentalRowStackView.alignment = .fill
        accidentalRowStackView.distribution = .fillEqually

        naturalRowStackView.axis = .horizontal
        naturalRowStackView.alignment = .fill
        naturalRowStackView.distribution = .fillEqually

        stackView.addArrangedSubview(accidentalRowStackView)
        stackView.addArrangedSubview(naturalRowStackView)
    }
}
```

## 修改 2：`macOSNaturalNoteStripView` 从单行 strip 升级为 shared 双行 strip，并把配置入口收敛成统一接口

### 修改前

- `layoutMode` 与 `railLayout` 分别用 `didSet` 驱动刷新
- renderer 需要先调 `applyPresentationStyle(...)`，再调 `applyRailLayout(...)`
- `horizontalStrip` 仍是单行 `NSStackView`
- 内边距固定绑死在 `Style.contentInsets`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名/符号: macOSNaturalNoteStripView.applyPresentationStyle / applyRailLayout / intrinsicContentSize / applyLayoutMode / syncButtonContainer
// 功能说明: 修改前 macOS 侧把布局切换和 railLayout 更新拆成两个入口；
// horizontalStrip 仍然是一行 stack，没有 shared horizontal layout 输入。
final class macOSNaturalNoteStripView: NSView {
    var layoutMode: LayoutMode = .horizontalStrip {
        didSet {
            guard oldValue != layoutMode else { return }
            applyLayoutMode()
        }
    }

    private var railLayout: ExerciseNaturalNoteStripRailLayout =
        defaultNaturalNoteStripRailLayout {
            didSet {
                guard oldValue != railLayout else { return }
                applyLayoutMode()
            }
        }

    override var intrinsicContentSize: NSSize {
        switch layoutMode {
        case .horizontalStrip:
            return NSSize(
                width: NSView.noIntrinsicMetric,
                height: Style.contentInsets.top
                    + tallestButtonIntrinsicHeight
                    + Style.contentInsets.bottom
            )
        case .verticalRail:
            return NSSize(
                width: verticalRailIntrinsicWidth,
                height: verticalRailIntrinsicHeight
            )
        }
    }

    func applyPresentationStyle(
        _ presentationStyle: ExerciseSurfacePresentationStyle
    ) {
        switch presentationStyle {
        case .verticalRail:
            layoutMode = .verticalRail
        case .standard, .horizontalStrip:
            layoutMode = .horizontalStrip
        }
    }

    func applyRailLayout(_ railLayout: ExerciseNaturalNoteStripRailLayout?) {
        self.railLayout = railLayout ?? defaultNaturalNoteStripRailLayout
    }

    private func applyLayoutMode() {
        switch layoutMode {
        case .horizontalStrip:
            stackView.orientation = .horizontal
            stackView.alignment = .centerY
            stackView.distribution = .fillEqually
        case .verticalRail:
            stackView.orientation = .vertical
            stackView.alignment = .centerX
            stackView.distribution = .fill
        }

        syncButtonContainer()
    }

    private func syncButtonContainer() {
        switch layoutMode {
        case .horizontalStrip:
            buttons.forEach { button in
                detachButtonFromCurrentContainer(button)
                stackView.addArrangedSubview(button)
            }
        case .verticalRail:
            // ... 省略未变 rail 路径 ...
            break
        }
    }
}
```

### 修改后

- 统一成 `applyConfiguration(presentationStyle:horizontalLayout:railLayout:)`
- 新增 `horizontalLayout` 状态、双行 row stack，以及四条可更新的 `stackView` 约束
- `horizontalStrip` 的 insets / rowSpacing / columnSpacing / `contentSize` 高度全部读取 shared contract
- `verticalRail` 继续走旧的 rail canvas，只在切换回 rail 时把约束常量还原成 `Style.contentInsets`

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数名/符号: macOSNaturalNoteStripView.applyConfiguration / configureHorizontalStripContainer / updateHorizontalStripInsets / applyLayoutMode / syncHorizontalStripRows
// 功能说明: 修改后 macOS horizontalStrip 和 iOS 一样消费 shared 双行布局；
// 同时把配置入口合并，避免 renderer 分两次下发布局状态。
private let defaultNaturalNoteStripHorizontalLayout =
    ExerciseNaturalNoteStripHorizontalLayoutContext(
        appliesToSurface: .naturalNoteStrip,
        titleDisplayPolicy:
            ExerciseNaturalNoteStripHorizontalLayoutContext
            .defaultTitleDisplayPolicy,
        geometry: .defaultTwoRowHorizontalStrip(),
        accidentalPitchClasses: PitchClass.accidentalCasesInOrder,
        naturalPitchClasses: PitchClass.naturalCasesInOrder
    ).resolvedLayout

final class macOSNaturalNoteStripView: NSView {
    private var layoutMode: LayoutMode = .horizontalStrip
    private var horizontalLayout: ExerciseNaturalNoteStripHorizontalLayout =
        defaultNaturalNoteStripHorizontalLayout
    private var railLayout: ExerciseNaturalNoteStripRailLayout =
        defaultNaturalNoteStripRailLayout

    private let stackView = NSStackView()
    private let accidentalRowStackView = NSStackView()
    private let naturalRowStackView = NSStackView()
    private let railCanvasView = RailCanvasView()
    private var stackViewLeadingConstraint: NSLayoutConstraint?
    private var stackViewTrailingConstraint: NSLayoutConstraint?
    private var stackViewTopConstraint: NSLayoutConstraint?
    private var stackViewBottomConstraint: NSLayoutConstraint?

    func applyConfiguration(
        presentationStyle: ExerciseSurfacePresentationStyle,
        horizontalLayout: ExerciseNaturalNoteStripHorizontalLayout?,
        railLayout: ExerciseNaturalNoteStripRailLayout?
    ) {
        let nextLayoutMode = resolvedLayoutMode(for: presentationStyle)
        let nextHorizontalLayout =
            horizontalLayout ?? defaultNaturalNoteStripHorizontalLayout
        let nextRailLayout = railLayout ?? defaultNaturalNoteStripRailLayout
        guard
            layoutMode != nextLayoutMode
                || self.horizontalLayout != nextHorizontalLayout
                || self.railLayout != nextRailLayout
        else {
            return
        }

        layoutMode = nextLayoutMode
        self.horizontalLayout = nextHorizontalLayout
        self.railLayout = nextRailLayout
        applyLayoutMode()
    }

    private func configureHorizontalStripContainer() {
        stackView.orientation = .vertical
        stackView.alignment = .width
        stackView.distribution = .fillEqually

        accidentalRowStackView.orientation = .horizontal
        accidentalRowStackView.alignment = .height
        accidentalRowStackView.distribution = .fillEqually

        naturalRowStackView.orientation = .horizontal
        naturalRowStackView.alignment = .height
        naturalRowStackView.distribution = .fillEqually

        stackView.addArrangedSubview(accidentalRowStackView)
        stackView.addArrangedSubview(naturalRowStackView)
    }

    private func updateHorizontalStripInsets() {
        let contentInsets = resolvedHorizontalLayoutInsets()
        stackViewLeadingConstraint?.constant = contentInsets.left
        stackViewTrailingConstraint?.constant = -contentInsets.right
        stackViewTopConstraint?.constant = contentInsets.top
        stackViewBottomConstraint?.constant = -contentInsets.bottom
    }

    private func applyLayoutMode() {
        switch layoutMode {
        case .horizontalStrip:
            updateHorizontalStripInsets()
            stackView.orientation = .vertical
            stackView.alignment = .width
            stackView.distribution = .fillEqually
            stackView.spacing = resolvedHorizontalRowSpacing
            accidentalRowStackView.spacing = resolvedHorizontalColumnSpacing
            naturalRowStackView.spacing = resolvedHorizontalColumnSpacing
        case .verticalRail:
            stackViewLeadingConstraint?.constant = Style.contentInsets.left
            stackViewTrailingConstraint?.constant = -Style.contentInsets.right
            stackViewTopConstraint?.constant = Style.contentInsets.top
            stackViewBottomConstraint?.constant = -Style.contentInsets.bottom
        }

        syncButtonContainer()
    }

    private func syncHorizontalStripRows() {
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            button.isHidden = true
        }

        resolvedHorizontalButtons(for: .accidentalsTop).forEach { button in
            button.isHidden = false
            accidentalRowStackView.addArrangedSubview(button)
        }
        resolvedHorizontalButtons(for: .naturalsBottom).forEach { button in
            button.isHidden = false
            naturalRowStackView.addArrangedSubview(button)
        }
    }
}
```

## 修改 3：renderer 开始把 shared `horizontalLayout` 透传给平台 strip view

### iOS renderer

修改前是“只传 `presentationStyle + railLayout`”；修改后增加 `horizontalLayout` 透传。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名/符号: iOSExerciseSceneRenderer.configurePresentationStyle
// 功能说明: 修改前 renderer 不向 iOS strip view 透传 shared horizontal layout。
private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyConfiguration(
        presentationStyle: surface.presentationStyle,
        railLayout: currentPresentationState?.naturalNoteStripRailLayout
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名/符号: iOSExerciseSceneRenderer.configurePresentationStyle
// 功能说明: 修改后 renderer 同时把 horizontalLayout 和 railLayout 下发给 iOS strip view。
private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyConfiguration(
        presentationStyle: surface.presentationStyle,
        horizontalLayout: currentPresentationState?.naturalNoteStripHorizontalLayout,
        railLayout: currentPresentationState?.naturalNoteStripRailLayout
    )
}
```

### macOS renderer

修改前需要分两步调用 `applyPresentationStyle` / `applyRailLayout`；修改后和 iOS 一样统一走 `applyConfiguration(...)`。

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名/符号: macOSExerciseSceneRenderer.configurePresentationStyle
// 功能说明: 修改前 renderer 只能分别下发 presentationStyle 和 railLayout；
// 没有 horizontalLayout 这一条共享 contract 的平台接线。
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

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Exercise/macOSExerciseSceneRenderer.swift
// 函数名/符号: macOSExerciseSceneRenderer.configurePresentationStyle
// 功能说明: 修改后 macOS renderer 与 iOS 一样统一下发 style + horizontalLayout + railLayout。
private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyConfiguration(
        presentationStyle: surface.presentationStyle,
        horizontalLayout:
            currentPresentationState?.naturalNoteStripHorizontalLayout,
        railLayout: currentPresentationState?.naturalNoteStripRailLayout
    )
}
```

## 结果对照

- 视觉结果：`horizontalStrip` 现在在两端都是双行布局，上排 `C# / D# / F# / G# / A#`，下排 `C / D / E / F / G / A / B`
- 数据来源：按钮顺序、行归属、标题显隐、间距和内边距不再由平台 view 本地随意决定，而是收口到 shared `ExerciseNaturalNoteStripHorizontalLayout`
- 兼容结果：`verticalRail` 仍保持 side-by-side rail 的旧布局与旧标题策略，没有被 `horizontalStrip` 的双行实现反向影响

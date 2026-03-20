20260320_163815_phase3_ios_button_panel_view

# 原生按钮组件阶段 3 修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`

## 修改前

### iOS 平台还没有独立的原生按钮容器文件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift
// 函数名：无（文件不存在）
// 功能说明：修改前 iOS 平台侧还没有专门消费 ButtonPanelModel 的原生按钮组件，
// 阶段 2 虽然已经把按钮语义模型抽到 Shared，但 UIKit 侧还没有独立的 UIView 容器负责渲染这些按钮。
// 该文件在修改前不存在。
```

### iOS 控制器当前仍只装配指板视图，没有按钮容器接线

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：displayState, fretboardView, configureFretboardView(), applyDisplayState()
// 功能说明：修改前阶段 3 开始前，iOS 控制器仍然只持有指板展示状态和 fretboardView，
// 还没有 buttonPanelView、也没有按钮点击回调接线，因此需要先把独立组件本身落地。
final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }
    private var fretboardHeightConstraint: NSLayoutConstraint?

    private lazy var fretboardView: iOSFretboardView = {
        let fretboardView = iOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { hitResult in
            print(hitResult.debugSummary(platform: "iOS"))
        }
        return fretboardView
    }()
}
```

## 修改后

### 新增 `iOSButtonPanelView`，对外只暴露 `model` 和 `onAction`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift
// 函数名：model, onAction, intrinsicContentSize, applyModel()
// 功能说明：新增独立的 UIKit 按钮容器，直接消费共享层 ButtonPanelModel；
// 外部只需要设置 model 和 onAction，组件内部自己完成 section 结构同步、按钮增删和尺寸计算。
#if os(iOS)
import UIKit

final class iOSButtonPanelView: UIView {
    var model: ButtonPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModel()
        }
    }

    var onAction: ((ButtonPanelActionID) -> Void)?

    override var intrinsicContentSize: CGSize {
        let stackSize = sectionsStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: directionalLayoutMargins.top + stackSize.height + directionalLayoutMargins.bottom
        )
    }

    private let sectionsStackView = UIStackView()
    private var sectionStacks: [ButtonPanelSectionID: UIStackView] = [:]
    private var buttonsByActionID: [ButtonPanelActionID: PanelActionButton] = [:]

    private func applyModel() {
        removeObsoleteButtons(notIn: Set(model.items.map(\.id)))
        removeObsoleteSectionStacks(notIn: Set(model.sections.map(\.id)))
        // ... 同步 section 顺序和按钮视图 ...
    }
}
#endif
```

### 新增 section / button 同步与点击动作转发机制

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift
// 函数名：syncButtons(in:for:), actionButton(for:sectionID:), handleButtonTap(_:)
// 功能说明：按钮容器根据共享 section/items 生成或复用 UIButton 实例，
// 并在用户点击时把 ButtonPanelActionID 原样抛给外层，不在 UIKit 层解释业务动作。
private func syncButtons(
    in sectionStack: UIStackView,
    for section: ButtonPanelSection
) {
    let orderedButtons = section.items.map { item -> UIButton in
        let button = actionButton(
            for: item,
            sectionID: section.id
        )
        return button
    }

    replaceArrangedSubviews(
        in: sectionStack,
        with: orderedButtons
    )
}

private func actionButton(
    for item: ButtonPanelItem,
    sectionID: ButtonPanelSectionID
) -> PanelActionButton {
    if let existingButton = buttonsByActionID[item.id] {
        existingButton.sectionID = sectionID
        existingButton.apply(item: item)
        return existingButton
    }

    let button = PanelActionButton(frame: .zero)
    button.sectionID = sectionID
    button.addTarget(
        self,
        action: #selector(handleButtonTap(_:)),
        for: .touchUpInside
    )
    button.apply(item: item)
    buttonsByActionID[item.id] = button
    return button
}

@objc
private func handleButtonTap(_ sender: PanelActionButton) {
    guard let actionID = sender.actionID else {
        return
    }

    onAction?(actionID)
}
```

### 新增 `PanelActionButton`，统一选中态、禁用态和系统样式

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift
// 函数名：apply(item:), updateConfiguration(), resolvedBackgroundColor(), resolvedForegroundColor()
// 功能说明：按钮子类只负责把共享模型里的 title / isSelected / isEnabled 映射到 UIButton.Configuration，
// 统一处理胶囊样式、前景色、背景色和 accessibility，不把业务判断回流到平台层。
private final class PanelActionButton: UIButton {
    var actionID: ButtonPanelActionID?

    func apply(item: ButtonPanelItem) {
        actionID = item.id
        isSelected = item.isSelected
        isEnabled = item.isEnabled
        accessibilityLabel = item.accessibilityLabel
        accessibilityIdentifier = "button-panel-\(item.id)"
        setTitle(item.title, for: .normal)
        setNeedsUpdateConfiguration()
    }

    override func updateConfiguration() {
        super.updateConfiguration()

        guard actionID != nil else {
            return
        }

        var nextConfiguration = configuration ?? UIButton.Configuration.filled()
        nextConfiguration.title = title(for: .normal)
        nextConfiguration.buttonSize = .medium
        nextConfiguration.cornerStyle = .capsule
        nextConfiguration.contentInsets = Style.buttonContentInsets
        nextConfiguration.baseBackgroundColor = resolvedBackgroundColor()
        nextConfiguration.baseForegroundColor = resolvedForegroundColor()
        configuration = nextConfiguration

        accessibilityTraits = isSelected
            ? [.button, .selected]
            : [.button]
    }
}
```

## 结果说明

- 阶段 3 的核心结果是：iOS 侧已经有了一个独立的原生按钮组件 `iOSButtonPanelView`，它直接消费阶段 2 的共享按钮模型。
- 当前这一步只完成组件本身，没有修改 `iOSViewController` 去接入 `buttonPanelView`，这是有意保持阶段边界，控制器接线仍留在后续阶段。
- 组件内部已经具备 section 同步、按钮实例复用、点击动作转发、选中态和禁用态样式映射能力。
- 已执行构建验证：`DEVELOPER_DIR=\"/Applications/Xcode.app/Contents/Developer\" xcodebuild -project \"NoteMaster_Ver_1.xcodeproj\" -scheme \"NoteMaster_Ver_1\" -destination \"generic/platform=macOS\" build` 与 `generic/platform=iOS Simulator` 均通过。
- 已使用系统 `date` 生成时间戳 `20260320_163815` 作为本记录文件前缀。

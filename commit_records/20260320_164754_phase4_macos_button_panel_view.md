20260320_164754_phase4_macos_button_panel_view

# 原生按钮组件阶段 4 修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift`

## 修改前

### macOS 平台还没有独立的原生按钮容器文件

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift
// 函数名：无（文件不存在）
// 功能说明：修改前 macOS 平台侧还没有专门消费 ButtonPanelModel 的 AppKit 按钮组件，
// 阶段 3 虽然已经有了 iOSButtonPanelView，但 macOS 还没有对应的独立 NSView 容器。
// 该文件在修改前不存在。
```

### macOS 控制器当前仍只装配指板视图，没有按钮容器接线

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：displayState, fretboardView, configureFretboardView(), applyDisplayState()
// 功能说明：修改前阶段 4 开始前，macOS 控制器仍然只维护 displayState 和 fretboardView，
// 还没有 buttonPanelView，也没有按钮动作回调链路，因此需要先把独立组件本身实现出来。
final class macOSViewController: NSViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }
    private var fretboardHeightConstraint: NSLayoutConstraint?

    private lazy var fretboardView: macOSFretboardView = {
        let fretboardView = macOSFretboardView(configuration: displayState.configuration)
        fretboardView.onRawEvent = { hitResult in
            print(hitResult.debugSummary(platform: "macOS"))
        }
        return fretboardView
    }()
}
```

## 修改后

### 新增 `macOSButtonPanelView`，保持与 iOS 一致的 `model/onAction` 协议

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift
// 函数名：model, onAction, intrinsicContentSize, applyModel()
// 功能说明：新增独立的 AppKit 按钮容器，直接消费共享层 ButtonPanelModel；
// 对外仍然是 model 和 onAction，内部自己处理 section 同步、按钮复用和内容尺寸计算。
#if os(macOS)
import AppKit

final class macOSButtonPanelView: NSView {
    var model: ButtonPanelModel {
        didSet {
            guard oldValue != model else {
                return
            }

            applyModel()
        }
    }

    var onAction: ((ButtonPanelActionID) -> Void)?

    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        let stackSize = sectionsStackView.fittingSize
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Style.contentInsets.top + stackSize.height + Style.contentInsets.bottom
        )
    }

    private let sectionsStackView = NSStackView()
    private var sectionStacks: [ButtonPanelSectionID: NSStackView] = [:]
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
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift
// 函数名：syncButtons(in:for:), actionButton(for:sectionID:), handleButtonTap(_:)
// 功能说明：按钮容器根据共享 section/items 生成或复用 NSButton，
// 并在点击时把 ButtonPanelActionID 原样回调给外层，组件本身不解释业务动作。
private func syncButtons(
    in sectionStack: NSStackView,
    for section: ButtonPanelSection
) {
    let orderedButtons = section.items.map { item -> NSView in
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
    button.target = self
    button.action = #selector(handleButtonTap(_:))
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

### 新增 `PanelActionButton`，统一 AppKit 侧选中态、禁用态和按下态样式

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift
// 函数名：apply(item:), mouseDown(with:), applyCurrentAppearance(), resolvedBackgroundColor(), resolvedForegroundColor()
// 功能说明：按钮子类负责把共享模型里的 title / isSelected / isEnabled 映射到 NSButton 的 state 和 attributedTitle，
// 并在 AppKit 侧内聚按下态、选中态、禁用态样式，不把样式逻辑泄漏到控制器层。
private final class PanelActionButton: NSButton {
    var actionID: ButtonPanelActionID?

    private var isPressed = false

    func apply(item: ButtonPanelItem) {
        actionID = item.id
        state = item.isSelected ? .on : .off
        isEnabled = item.isEnabled
        title = item.title
        toolTip = item.accessibilityLabel
        identifier = NSUserInterfaceItemIdentifier("button-panel-\(String(describing: item.id))")
        applyCurrentAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        applyCurrentAppearance()
        super.mouseDown(with: event)
        isPressed = false
        applyCurrentAppearance()
    }

    private func applyCurrentAppearance() {
        layer?.backgroundColor = resolvedBackgroundColor().cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: Style.fontSize, weight: .medium),
                .foregroundColor: resolvedForegroundColor()
            ]
        )
    }
}
```

## 结果说明

- 阶段 4 的核心结果是：macOS 侧已经有了一个独立的原生按钮组件 `macOSButtonPanelView`，并且继续使用阶段 2 的共享按钮模型。
- 这个组件在对外协议上与 `iOSButtonPanelView` 保持一致，但内部完全使用 `NSView + NSStackView + NSButton`，没有把 UIKit 实现硬搬过来。
- 当前这一步仍然只完成组件本身，没有修改 `macOSViewController` 去接入 `buttonPanelView`，控制器接线仍留在后续阶段。
- 已执行构建验证：`DEVELOPER_DIR=\"/Applications/Xcode.app/Contents/Developer\" xcodebuild -project \"NoteMaster_Ver_1.xcodeproj\" -scheme \"NoteMaster_Ver_1\" -destination \"generic/platform=macOS\" build` 与 `generic/platform=iOS Simulator` 均通过。
- 已使用系统 `date` 生成时间戳 `20260320_164754` 作为本记录文件前缀。

20260320_175811_phase4_derived_height_propagation

# 固定弦高阶段 4 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`

## 修改前

### 平台指板视图只暴露 intrinsic size，但没有显式提高纵向布局优先级

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：configureView(), applyConfiguration()
// 功能说明：修改前 iOS 指板视图虽然会在 configuration 变化后刷新 intrinsicContentSize，但没有显式声明纵向 hugging / compression resistance，平台层的派生高度出口还不够强。
private func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    applyConfiguration()
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    invalidateIntrinsicContentSize()
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：configureView(), applyConfiguration()
// 功能说明：修改前 macOS 指板视图同样只会失效 intrinsicContentSize，但没有把纵向布局优先级提升到 required，控制器仍更依赖外部高度约束。
private func configureView() {
    wantsLayer = true
    layerContentsRedrawPolicy = .onSetNeedsDisplay
    applyConfiguration()
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    invalidateIntrinsicContentSize()
}
```

### 双平台控制器仍然手动持有并更新固定高度约束

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：fretboardHeightConstraint, configureLayout(), applyDisplayState()
// 功能说明：修改前 iOS 控制器会显式创建 heightConstraint，并在每次 displayState 变化时手动同步 preferredHeight，导致控制器和平台视图同时维护高度出口。
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

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide
        let heightConstraint = fretboardView.heightAnchor.constraint(
            equalToConstant: displayState.configuration.preferredHeight
        )
        fretboardHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            // ... 其他约束省略 ...
            fretboardView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            heightConstraint,
            fretboardView.bottomAnchor.constraint(
                lessThanOrEqualTo: safeArea.bottomAnchor,
                constant: -Layout.bottomInset
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardHeightConstraint?.constant = displayState.configuration.preferredHeight
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：fretboardHeightConstraint, configureLayout(), applyDisplayState()
// 功能说明：修改前 macOS 控制器也保留了一份显式高度约束，并在 applyDisplayState 中手动改 constant，平台链路还没有完全只消费派生高度。
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

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide
        let heightConstraint = fretboardView.heightAnchor.constraint(
            equalToConstant: displayState.configuration.preferredHeight
        )
        fretboardHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            // ... 其他约束省略 ...
            fretboardView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            heightConstraint,
            fretboardView.bottomAnchor.constraint(
                lessThanOrEqualTo: safeArea.bottomAnchor,
                constant: -Layout.bottomInset
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        fretboardHeightConstraint?.constant = displayState.configuration.preferredHeight
    }
}
```

## 修改后

### 平台指板视图把派生高度作为唯一 intrinsic size 出口，并提高纵向优先级

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
// 函数名：configureView(), applyConfiguration()
// 功能说明：修改后 iOS 指板视图显式提高纵向 hugging / compression resistance，让 intrinsicContentSize.height = configuration.preferredHeight 成为更可靠的高度出口。
private func configureView() {
    backgroundColor = .clear
    isOpaque = false
    contentMode = .redraw
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    applyConfiguration()
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    invalidateIntrinsicContentSize()
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：configureView(), applyConfiguration()
// 功能说明：修改后 macOS 指板视图也把纵向布局优先级提升到 required，从而让派生高度继续只通过 intrinsicContentSize 暴露给 Auto Layout。
private func configureView() {
    wantsLayer = true
    layerContentsRedrawPolicy = .onSetNeedsDisplay
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    applyConfiguration()
}

private func applyConfiguration() {
    fretboardLayer.configuration = configuration
    fretboardLayer.contentProvider = contentProvider
    updateContentsScale()
    invalidateIntrinsicContentSize()
}
```

### 双平台控制器去掉显式高度约束，只负责刷新状态和布局

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：configureLayout(), applyDisplayState()
// 功能说明：修改后 iOS 控制器不再持有 fretboardHeightConstraint，也不再手动同步 preferredHeight；displayState 变化后仅更新配置与内容，并触发布局系统重新消费 intrinsic size。
final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // ... 其他约束省略 ...
            fretboardView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.bottomAnchor.constraint(
                lessThanOrEqualTo: safeArea.bottomAnchor,
                constant: -Layout.bottomInset
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}
```

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：configureLayout(), applyDisplayState()
// 功能说明：修改后 macOS 控制器同样移除了手动 heightConstraint，同步 displayState 后只触发一次布局刷新，让 Auto Layout 直接消费平台视图的 intrinsicContentSize.height。
final class macOSViewController: NSViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(fretboardView)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // ... 其他约束省略 ...
            fretboardView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.bottomAnchor.constraint(
                lessThanOrEqualTo: safeArea.bottomAnchor,
                constant: -Layout.bottomInset
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }
}
```

## 结果说明

- 阶段 4 的核心结果，是让 `preferredHeight` 的传播链从“控制器手动同步约束 + 平台视图 intrinsic size”收口为“平台视图 intrinsic size 单一出口”。
- `ButtonPanelModel` 仍然只改 `displayState.configuration.tuning`，没有新增任何“手动改高度”的分支逻辑。
- 双平台 `FretboardView` 现在都具备纵向 required 级别的 hugging / compression resistance，更适合承接派生高度语义。
- 双平台控制器里已经不再存在 `fretboardHeightConstraint` 残留，避免再次出现双重高度真相。
- 已执行 `ReadLints` 检查且无报错；`xcrun swiftc -typecheck` 通过。

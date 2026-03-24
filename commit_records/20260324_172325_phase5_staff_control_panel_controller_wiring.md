20260324_172325_phase5_staff_control_panel_controller_wiring

# StaffControlPanel 阶段 5 控制器接线记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改共享 `Staff` 渲染层和 `StaffControlPanel` 平台视图本体

## 修改前

### iOS 控制器里的 `staffDisplayState` 还是不可变常量，页面上也还没有 `staffControlPanelView`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：staffDisplayState（属性初始化）, configureLayout(), applyDisplayState()
// 功能说明：修改前 iOS 控制器里 `staffDisplayState` 是 `let`，还没有 StaffControlPanel；
// 布局顺序只有 buttonPanelView -> staffView -> fretboardView，且 `applyDisplayState()` 会一起刷新所有内容。
final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }

    private let staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.11,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        )
    )

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(staffView)
        view.addSubview(fretboardView)

        NSLayoutConstraint.activate([
            staffView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            )
        ])
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}
```

### macOS 控制器的状态流和布局也还是旧结构

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：staffDisplayState（属性初始化）, configureLayout(), applyDisplayState()
// 功能说明：修改前 macOS 控制器与 iOS 对称，仍然没有 StaffControlPanel 的接线入口；
// slider 事件没有地方进入 `StaffDisplayState.apply(_:)`，staff 和 fretboard 也没有拆分刷新链。
final class macOSViewController: NSViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyDisplayState()
        }
    }

    private let staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.11,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        )
    )

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(staffView)
        view.addSubview(fretboardView)
    }

    private func applyDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }
}
```

## 修改后

### iOS 控制器改为持有可变 `staffDisplayState`，新增 `staffControlPanelView`，并拆分 fretboard / staff 刷新链

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：staffDisplayState（属性初始化）, configureLayout(), applyFretboardDisplayState(), applyStaffDisplayState(), handleStaffControlEvent(_:)
// 功能说明：修改后 iOS 控制器把 StaffControlPanel 真正接入页面和状态流；
// `staffDisplayState` 改为可变状态，slider 事件通过 `handleStaffControlEvent(_:)` 进入共享 reducer，
// 并且把 fretboard 和 staff 的刷新链拆开，避免拖动 slider 时无意义刷新指板。
final class iOSViewController: UIViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyFretboardDisplayState()
        }
    }

    private var staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.11,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        )
    ) {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyStaffDisplayState()
        }
    }

    private lazy var staffControlPanelView: iOSStaffControlPanelView = {
        let staffControlPanelView = iOSStaffControlPanelView(
            model: StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
        )
        staffControlPanelView.onEvent = { [weak self] event in
            self?.handleStaffControlEvent(event)
        }
        return staffControlPanelView
    }()

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffControlPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(staffControlPanelView)
        view.addSubview(staffView)
        view.addSubview(fretboardView)

        NSLayoutConstraint.activate([
            staffControlPanelView.topAnchor.constraint(
                equalTo: buttonPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            staffView.topAnchor.constraint(
                equalTo: staffControlPanelView.bottomAnchor,
                constant: Layout.verticalSpacing
            ),
            fretboardView.topAnchor.constraint(
                equalTo: staffView.bottomAnchor,
                constant: Layout.verticalSpacing
            )
        ])
    }

    private func applyFretboardDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        updateLayoutIfNeeded()
    }

    private func applyStaffDisplayState() {
        staffControlPanelView.model = StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        updateLayoutIfNeeded()
    }

    private func handleStaffControlEvent(_ event: StaffControlEvent) {
        var nextStaffDisplayState = staffDisplayState
        nextStaffDisplayState.apply(event)

        guard nextStaffDisplayState != staffDisplayState else {
            return
        }

        staffDisplayState = nextStaffDisplayState
    }
}
```

### macOS 控制器同步接入 `macOSStaffControlPanelView`，保持与 iOS 一致的数据流

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：staffDisplayState（属性初始化）, configureLayout(), applyFretboardDisplayState(), applyStaffDisplayState(), handleStaffControlEvent(_:)
// 功能说明：修改后 macOS 控制器与 iOS 保持同一套接线方式；
// StaffControlPanel 现在位于按钮面板与 staff 视图之间，slider 事件统一走 `StaffDisplayState.apply(_:)`。
final class macOSViewController: NSViewController {
    private var displayState = FretboardDisplayState.default {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyFretboardDisplayState()
        }
    }

    private var staffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.11,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        )
    ) {
        didSet {
            guard isViewLoaded else {
                return
            }

            applyStaffDisplayState()
        }
    }

    private lazy var staffControlPanelView: macOSStaffControlPanelView = {
        let staffControlPanelView = macOSStaffControlPanelView(
            model: StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
        )
        staffControlPanelView.onEvent = { [weak self] event in
            self?.handleStaffControlEvent(event)
        }
        return staffControlPanelView
    }()

    private func configureLayout() {
        buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffControlPanelView.translatesAutoresizingMaskIntoConstraints = false
        staffView.translatesAutoresizingMaskIntoConstraints = false
        fretboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanelView)
        view.addSubview(staffControlPanelView)
        view.addSubview(staffView)
        view.addSubview(fretboardView)
    }

    private func applyFretboardDisplayState() {
        buttonPanelView.model = ButtonPanelSnapshotBuilder.makeModel(from: displayState)
        fretboardView.configuration = displayState.configuration
        fretboardView.contentProvider = displayState.contentProvider
        updateLayoutIfNeeded()
    }

    private func applyStaffDisplayState() {
        staffControlPanelView.model = StaffControlPanelSnapshotBuilder.makeModel(from: staffDisplayState)
        staffView.configuration = staffDisplayState.configuration
        staffView.sceneProvider = staffDisplayState.sceneProvider
        updateLayoutIfNeeded()
    }

    private func handleStaffControlEvent(_ event: StaffControlEvent) {
        var nextStaffDisplayState = staffDisplayState
        nextStaffDisplayState.apply(event)

        guard nextStaffDisplayState != staffDisplayState else {
            return
        }

        staffDisplayState = nextStaffDisplayState
    }
}
```

## 结果说明

- `staffDisplayState` 现在已经是控制器层真正可变的单一事实来源
- `StaffControlPanel` 已经接入 iOS / macOS 页面布局和事件流
- slider 事件会先进入 `StaffDisplayState.apply(_:)`，再更新 `staffView`
- staff 与 fretboard 的刷新链已经拆开，避免调 clef 锚点时无意义刷新指板

## 验证情况

- `ReadLints` 检查 `iOSViewController.swift`、`macOSViewController.swift`，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

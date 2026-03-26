# 20260326_215302_phase5_top_content_apply_pipeline

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_215302`
- 记录范围：顶部内容切换方案的阶段 5，控制器页面级 apply 链收口
- 本次目标：在双平台控制器中新增 `applyTopContentDisplayState()`，把 settings 事件、staff apply 和 trainer prompt 更新正式串成统一入口
- 根因结论：修改前虽然已经有 `TopContentDisplayState`、`Content` settings row、`targetNotePromptView` 和 `topContentHostView`，但页面级显示模式还没有统一 apply 入口。顶部内容切换只停留在 state 变化层，prompt view 更新也还留在控制台输出分支里，导致“状态已存在、布局已存在、视图已存在，但行为还没有真正闭环”
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 把 `topContentDisplayState` 从普通存储属性升级为带 `didSet` 的页面级状态入口，变化后直接触发 `applyTopContentDisplayState()`。
2. 将顶部内容子视图约束从“初始化时全部常驻激活”改为两组可切换的约束数组：`topContentStaffConstraints` 与 `topContentTargetPromptConstraints`。
3. 新增 `applyTopContentDisplayState()`，根据 `TopContentMode` 统一切换顶部可见视图、激活正确约束，并刷新 settings 快照。
4. 扩展 `applyDisplayState()`，让页面初始化与后续 display state 刷新都进入顶部内容 apply 链。
5. 扩展 `applyFretboardTrainerPrompt(reason:)`，让 trainer prompt 不再只写控制台，而是同步更新 `targetNotePromptView`。
6. 简化 `handleSettingsPanelEvent(_:)`，删除“仅 top content 变化时手动刷新 settings”这类临时分支，改由 `topContentDisplayState.didSet` 统一驱动页面级刷新。

## 修改 1：iOS 控制器把顶部内容模式接入统一 apply 入口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: topContentDisplayState, configureLayout(), applyDisplayState()
// 功能说明: 修改前 topContentDisplayState 只是普通存储属性；
// 顶部子视图约束在 configureLayout() 中一次性常驻激活，页面级 display apply 链也还没进入顶部内容模式。
private var topContentDisplayState = TopContentDisplayState.default

private func configureLayout() {
    // ... 省略未改动初始化代码 ...
    NSLayoutConstraint.activate([
        // ... 省略未改动滚动容器约束 ...
        topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        staffView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
        staffView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
        staffView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor),
        targetNotePromptView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
        targetNotePromptView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
        targetNotePromptView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
        targetNotePromptView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor),
        // ... 省略未改动约束 ...
    ])
}

private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: topContentDisplayState, topContentStaffConstraints, topContentTargetPromptConstraints,
//            configureLayout(), applyDisplayState(), applyTopContentDisplayState()
// 功能说明: 修改后页面级顶部内容模式拥有明确的控制器 apply 入口；
// 通过两组约束切换 staff / prompt 的布局归属，而不是让两套约束永久同时存在。
private var topContentDisplayState = TopContentDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyTopContentDisplayState()
    }
}

private var topContentStaffConstraints: [NSLayoutConstraint] = []
private var topContentTargetPromptConstraints: [NSLayoutConstraint] = []

private func configureLayout() {
    // ... 省略未改动初始化代码 ...
    topContentStaffConstraints = [
        staffView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
        staffView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
        staffView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor)
    ]
    topContentTargetPromptConstraints = [
        targetNotePromptView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
        targetNotePromptView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
        targetNotePromptView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
        targetNotePromptView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor)
    ]

    NSLayoutConstraint.activate([
        // ... 省略未改动滚动容器约束 ...
        topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        // 顶部内容子视图约束改由 topContentStaffConstraints / topContentTargetPromptConstraints 统一切换。
        // ... 省略未改动约束 ...
    ])
}

private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyTopContentDisplayState()
}

private func applyTopContentDisplayState() {
    let showsStaff = topContentDisplayState.mode == .staff
    let activeConstraints = showsStaff
        ? topContentStaffConstraints
        : topContentTargetPromptConstraints
    let inactiveConstraints = showsStaff
        ? topContentTargetPromptConstraints
        : topContentStaffConstraints

    targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    staffView.isHidden = !showsStaff
    targetNotePromptView.isHidden = showsStaff
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
    applySettingsPanelState()
    updateLayoutIfNeeded()
}
```

## 修改 2：iOS 控制器把 trainer prompt 与 settings 事件链收口到页面级模式入口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyFretboardTrainerPrompt(reason:), handleSettingsPanelEvent(_:)
// 功能说明: 修改前 trainer prompt 还只负责控制台输出；
// settings 对 top content 的变化需要额外的“仅刷新 settings 快照”临时分支来兜底。
private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    print(
        "[FretboardTrainer][iOS] target=\(prompt.displayText) state=\(reason)"
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    var nextTopContentDisplayState = topContentDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState,
        topContentDisplayState: &nextTopContentDisplayState
    )

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangeTopContent = nextTopContentDisplayState != topContentDisplayState

    guard didChangeFretboard || didChangeStaff || didChangeTopContent else {
        return
    }

    if didChangeTopContent {
        topContentDisplayState = nextTopContentDisplayState
    }

    if didChangeFretboard {
        displayState = nextDisplayState
    }

    if didChangeStaff {
        staffDisplayState = nextStaffDisplayState
    }

    if didChangeTopContent, !didChangeFretboard, !didChangeStaff {
        applySettingsPanelState()
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: applyFretboardTrainerPrompt(reason:), handleSettingsPanelEvent(_:)
// 功能说明: 修改后 trainer prompt 的平台组装入口会同步更新目标音组件；
// settings 对顶部内容模式的变化不再依赖局部补丁，而是交给 topContentDisplayState.didSet -> applyTopContentDisplayState() 统一处理。
private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    targetNotePromptView.apply(prompt: prompt)
    print(
        "[FretboardTrainer][iOS] target=\(prompt.displayText) state=\(reason)"
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    var nextTopContentDisplayState = topContentDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState,
        topContentDisplayState: &nextTopContentDisplayState
    )

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangeTopContent = nextTopContentDisplayState != topContentDisplayState

    guard didChangeFretboard || didChangeStaff || didChangeTopContent else {
        return
    }

    if didChangeTopContent {
        topContentDisplayState = nextTopContentDisplayState
    }

    if didChangeFretboard {
        displayState = nextDisplayState
    }

    if didChangeStaff {
        staffDisplayState = nextStaffDisplayState
    }
}
```

## 修改 3：macOS 控制器对称接入顶部内容模式统一 apply 链

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: topContentDisplayState, configureLayout(), applyDisplayState()
// 功能说明: 修改前 macOS 与 iOS 一样，顶部内容模式状态虽然存在，
// 但还没有页面级 didSet apply 入口，顶部子视图约束也仍是初始化时一次性激活。
private var topContentDisplayState = TopContentDisplayState.default

private func configureLayout() {
    // ... 省略未改动初始化代码 ...
    NSLayoutConstraint.activate([
        // ... 省略未改动滚动容器约束 ...
        topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        staffView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
        staffView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
        staffView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor),
        targetNotePromptView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
        targetNotePromptView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
        targetNotePromptView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
        targetNotePromptView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor),
        // ... 省略未改动约束 ...
    ])
}

private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: topContentDisplayState, topContentStaffConstraints, topContentTargetPromptConstraints,
//            configureLayout(), applyDisplayState(), applyTopContentDisplayState()
// 功能说明: 修改后 macOS 控制器与 iOS 对称，把顶部内容模式正式并入页面级 apply 链；
// 约束切换、显隐切换和 settings 刷新都统一落在控制器组装层。
private var topContentDisplayState = TopContentDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyTopContentDisplayState()
    }
}

private var topContentStaffConstraints: [NSLayoutConstraint] = []
private var topContentTargetPromptConstraints: [NSLayoutConstraint] = []

private func configureLayout() {
    // ... 省略未改动初始化代码 ...
    topContentStaffConstraints = [
        staffView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
        staffView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
        staffView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor)
    ]
    topContentTargetPromptConstraints = [
        targetNotePromptView.leadingAnchor.constraint(equalTo: topContentHostView.leadingAnchor),
        targetNotePromptView.trailingAnchor.constraint(equalTo: topContentHostView.trailingAnchor),
        targetNotePromptView.topAnchor.constraint(equalTo: topContentHostView.topAnchor),
        targetNotePromptView.bottomAnchor.constraint(equalTo: topContentHostView.bottomAnchor)
    ]

    NSLayoutConstraint.activate([
        // ... 省略未改动滚动容器约束 ...
        topContentHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        topContentHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        // 顶部内容子视图约束改由 topContentStaffConstraints / topContentTargetPromptConstraints 统一切换。
        // ... 省略未改动约束 ...
    ])
}

private func applyDisplayState() {
    applyFretboardDisplayState()
    applyStaffDisplayState()
    applyTopContentDisplayState()
}

private func applyTopContentDisplayState() {
    let showsStaff = topContentDisplayState.mode == .staff
    let activeConstraints = showsStaff
        ? topContentStaffConstraints
        : topContentTargetPromptConstraints
    let inactiveConstraints = showsStaff
        ? topContentTargetPromptConstraints
        : topContentStaffConstraints

    targetNotePromptView.apply(prompt: currentFretboardTrainerPrompt)
    staffView.isHidden = !showsStaff
    targetNotePromptView.isHidden = showsStaff
    NSLayoutConstraint.deactivate(inactiveConstraints)
    NSLayoutConstraint.activate(activeConstraints)
    applySettingsPanelState()
    updateLayoutIfNeeded()
}
```

## 修改 4：macOS 控制器同步收口 trainer prompt 与 settings 事件链

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: applyFretboardTrainerPrompt(reason:), handleSettingsPanelEvent(_:)
// 功能说明: 修改前 macOS 端也还是“控制台输出 + 局部补丁刷新”的状态；
// 顶部内容模式切换还没有被真正并入页面级 apply 链。
private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    print(
        "[FretboardTrainer][macOS] target=\(prompt.displayText) state=\(reason)"
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    var nextTopContentDisplayState = topContentDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState,
        topContentDisplayState: &nextTopContentDisplayState
    )

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangeTopContent = nextTopContentDisplayState != topContentDisplayState

    guard didChangeFretboard || didChangeStaff || didChangeTopContent else {
        return
    }

    if didChangeTopContent {
        topContentDisplayState = nextTopContentDisplayState
    }

    if didChangeFretboard {
        displayState = nextDisplayState
    }

    if didChangeStaff {
        staffDisplayState = nextStaffDisplayState
    }

    if didChangeTopContent, !didChangeFretboard, !didChangeStaff {
        applySettingsPanelState()
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: applyFretboardTrainerPrompt(reason:), handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS 的 trainer prompt 更新链与页面级 top content 切换链完成收口；
// prompt view 内容更新、顶部模式切换和 settings 刷新都回到统一控制器入口处理。
private func applyFretboardTrainerPrompt(reason: String) {
    let prompt = currentFretboardTrainerPrompt
    targetNotePromptView.apply(prompt: prompt)
    print(
        "[FretboardTrainer][macOS] target=\(prompt.displayText) state=\(reason)"
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    var nextTopContentDisplayState = topContentDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState,
        topContentDisplayState: &nextTopContentDisplayState
    )

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangeTopContent = nextTopContentDisplayState != topContentDisplayState

    guard didChangeFretboard || didChangeStaff || didChangeTopContent else {
        return
    }

    if didChangeTopContent {
        topContentDisplayState = nextTopContentDisplayState
    }

    if didChangeFretboard {
        displayState = nextDisplayState
    }

    if didChangeStaff {
        staffDisplayState = nextStaffDisplayState
    }
}
```

## 这次修改解决了什么

- 解决了“顶部模式状态、顶部宿主容器、目标音组件都已存在，但页面行为还没有真正闭环”的根因问题。
- 把顶部内容切换从“settings 改 state”推进为“settings 改 state -> 控制器统一 apply -> 页面真实切换显示内容”。
- 把目标音组件内容更新正式并入 trainer prompt 的平台组装入口，不再只是控制台输出。
- 删除了针对 top content 的局部补丁刷新分支，控制器职责边界更清晰：页面级模式由 `applyTopContentDisplayState()` 统一处理。

## 本次明确未修改的边界

- 未修改 `SettingsPanelModel.swift`
- 未修改 `SettingsPanelSnapshotBuilder.swift`
- 未修改 `iOSTargetNotePromptView.swift`
- 未修改 `macOSTargetNotePromptView.swift`
- 未补充 `FretboardValidation.swift` 的回归项
- 未新增额外命令行校验逻辑；阶段 6 再补 shared/manual 验证

## 验证结果

### 静态检查

- `ReadLints` 检查以下 2 个文件，结果为无错误：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 功能说明: 使用 macOS SDK 对项目内 Swift 文件做 typecheck，确认顶部内容页面级 apply 链收口后编译链保持通过。
xcrun swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk NoteMaster_Ver_1/**/*.swift
```

- 结果：通过
- 结论：阶段 5 已完成双平台顶部内容切换与 prompt 同步的控制器级收口，并保持当前工程静态检查与类型检查通过

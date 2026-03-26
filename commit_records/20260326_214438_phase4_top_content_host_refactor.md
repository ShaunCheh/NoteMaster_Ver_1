# 20260326_214438_phase4_top_content_host_refactor

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_214438`
- 记录范围：顶部内容切换方案的阶段 4，顶部区域 `topContentHostView` 重构
- 本次目标：把双平台控制器顶部区域从“`staffView` 直接挂在页面内容里”重构为“`topContentHostView` 托管 `staffView` + `targetNotePromptView`”
- 根因结论：修改前顶部布局链路直接写死为 `contentView -> staffView -> fretboardHostView`。这样即使阶段 3 已经有了双平台目标音组件，也没有一个共享的顶部内容宿主来承接“显示五线谱 / 显示目标音组件”的切换，后续会被迫在控制器里继续堆分支和临时约束
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 在 iOS / macOS 控制器中新增 `topContentHostView`，作为顶部区域的统一宿主。
2. 在 iOS / macOS 控制器中新增 `targetNotePromptView` 属性，并先默认隐藏，等待后续阶段接入显示模式切换。
3. 把 `staffView` 从 `contentView` 的直接子视图迁移到 `topContentHostView` 下。
4. 把顶部区域的布局角色从 `staffView` 切换为 `topContentHostView`，并将 `fretboardHostView.topAnchor` 改接到 `topContentHostView.bottomAnchor`。

## 修改 1：iOS 控制器把顶部区域重构为 `topContentHostView`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: contentView, staffView, configureLayout()
// 功能说明: 修改前顶部区域还是 staffView 直接占位；
// 页面结构里还没有 host 容器来同时托管五线谱和目标音组件。
private let scrollView = UIScrollView()
private let contentView = UIView()
private let fretboardHostView = UIView()
private let fretboardViewportScrollView = UIScrollView()
private let fretboardScrollContentView = UIView()

private lazy var staffView: iOSStaffView = {
    iOSStaffView(
        configuration: staffDisplayState.configuration,
        sceneProvider: staffDisplayState.sceneProvider
    )
}()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
    fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
    fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardHostView)
    // ... 省略未改动 addSubview 代码 ...

    NSLayoutConstraint.activate([
        // ... 省略未改动滚动容器约束 ...
        staffView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        staffView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.topAnchor.constraint(
            equalTo: staffView.bottomAnchor,
            constant: Layout.verticalSpacing
        )
        // ... 省略未改动约束 ...
    ])
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: topContentHostView, targetNotePromptView, configureLayout()
// 功能说明: 修改后 iOS 顶部区域先被抽成 host 容器；
// staffView 和 targetNotePromptView 都进入同一个宿主，后续只需要切换宿主内部显隐即可。
private let scrollView = UIScrollView()
private let contentView = UIView()
private let topContentHostView = UIView()
private let fretboardHostView = UIView()
private let fretboardViewportScrollView = UIScrollView()
private let fretboardScrollContentView = UIView()

private lazy var staffView: iOSStaffView = {
    iOSStaffView(
        configuration: staffDisplayState.configuration,
        sceneProvider: staffDisplayState.sceneProvider
    )
}()

private lazy var targetNotePromptView: iOSTargetNotePromptView = {
    let targetNotePromptView = iOSTargetNotePromptView(
        prompt: currentFretboardTrainerPrompt
    )
    targetNotePromptView.isHidden = true
    return targetNotePromptView
}()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    topContentHostView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false
    fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
    fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
    fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    contentView.addSubview(fretboardHostView)
    // ... 省略未改动 addSubview 代码 ...

    NSLayoutConstraint.activate([
        // ... 省略未改动滚动容器约束 ...
        topContentHostView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
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
        fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.topAnchor.constraint(
            equalTo: topContentHostView.bottomAnchor,
            constant: Layout.verticalSpacing
        )
        // ... 省略未改动约束 ...
    ])
}
```

## 修改 2：macOS 控制器对称引入 `topContentHostView`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: contentView, staffView, configureLayout()
// 功能说明: 修改前 macOS 控制器与 iOS 一样，顶部布局角色由 staffView 直接承担；
// 目标音组件虽然已经存在，但还没有位置挂入顶部区域结构。
private let scrollView = NSScrollView()
private let contentView = NSView()
private let fretboardHostView = NSView()
private let fretboardViewportScrollView = NSScrollView()
private let fretboardScrollContentView = NSView()

private lazy var staffView: macOSStaffView = {
    macOSStaffView(
        configuration: staffDisplayState.configuration,
        sceneProvider: staffDisplayState.sceneProvider
    )
}()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
    fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
    fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardHostView)
    // ... 省略未改动 addSubview 代码 ...

    NSLayoutConstraint.activate([
        // ... 省略未改动滚动容器约束 ...
        staffView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        staffView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.topAnchor.constraint(
            equalTo: staffView.bottomAnchor,
            constant: Layout.verticalSpacing
        )
        // ... 省略未改动约束 ...
    ])
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: topContentHostView, targetNotePromptView, configureLayout()
// 功能说明: 修改后 macOS 控制器与 iOS 对称重构顶部宿主；
// 这样双平台后续都能通过同一套页面级模式状态来切换顶部显示内容。
private let scrollView = NSScrollView()
private let contentView = NSView()
private let topContentHostView = NSView()
private let fretboardHostView = NSView()
private let fretboardViewportScrollView = NSScrollView()
private let fretboardScrollContentView = NSView()

private lazy var staffView: macOSStaffView = {
    macOSStaffView(
        configuration: staffDisplayState.configuration,
        sceneProvider: staffDisplayState.sceneProvider
    )
}()

private lazy var targetNotePromptView: macOSTargetNotePromptView = {
    let targetNotePromptView = macOSTargetNotePromptView(
        prompt: currentFretboardTrainerPrompt
    )
    targetNotePromptView.isHidden = true
    return targetNotePromptView
}()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    topContentHostView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    targetNotePromptView.translatesAutoresizingMaskIntoConstraints = false
    fretboardHostView.translatesAutoresizingMaskIntoConstraints = false
    fretboardViewportScrollView.translatesAutoresizingMaskIntoConstraints = false
    fretboardScrollContentView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    contentView.addSubview(topContentHostView)
    topContentHostView.addSubview(staffView)
    topContentHostView.addSubview(targetNotePromptView)
    contentView.addSubview(fretboardHostView)
    // ... 省略未改动 addSubview 代码 ...

    NSLayoutConstraint.activate([
        // ... 省略未改动滚动容器约束 ...
        topContentHostView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
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
        fretboardHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        fretboardHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardHostView.topAnchor.constraint(
            equalTo: topContentHostView.bottomAnchor,
            constant: Layout.verticalSpacing
        )
        // ... 省略未改动约束 ...
    ])
}
```

## 这次修改解决了什么

- 解决了“顶部区域没有宿主容器，无法真正承接内容切换”的结构问题。
- 让 `staffView` 与 `targetNotePromptView` 首次进入同一层级的页面容器，后续不需要再反向拆布局。
- 把 `fretboardHostView` 的上边依赖从具体内容视图切换为宿主容器，明确了页面编排边界。
- 为下一阶段的 `applyTopContentDisplayState()` 提前固定了双平台一致的布局骨架。

## 本次明确未修改的边界

- 未新增 `applyTopContentDisplayState()`
- 未根据 `topContentDisplayState.mode` 切换 `staffView` / `targetNotePromptView` 显隐
- 未修改 `applyFretboardTrainerPrompt(reason:)` 去更新 prompt view
- 未改变 settings 事件处理逻辑
- 当前 `targetNotePromptView` 只是接入 host 并默认隐藏，页面视觉行为暂时仍等同于显示五线谱

## 验证结果

### 静态检查

- `ReadLints` 检查以下 2 个文件，结果为无错误：
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 功能说明: 使用 macOS SDK 对项目内 Swift 文件做 typecheck，确认顶部 host 重构后编译链保持通过。
xcrun swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk NoteMaster_Ver_1/**/*.swift
```

- 结果：通过
- 结论：阶段 4 已完成双平台顶部 host 结构重构，并保持当前工程静态检查与类型检查通过

# 20260326_211644_phase1_top_content_display_state_foundation

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_211644`
- 记录范围：顶部内容切换方案的阶段 1，页面级顶部内容状态基础
- 本次目标：为“显示五线谱 / 显示目标音组件”的顶部内容切换建立独立的页面级 shared 状态，不把这类模式状态塞进 `StaffDisplayState` 或 `FretboardDisplayState`
- 根因结论：修改前项目里只有 `StaffDisplayState` 和 `FretboardDisplayState` 两类显示状态。它们分别服务于五线谱和指板本身的内部显示语义，但还没有一个状态专门表达“顶部区域当前显示的是什么内容”。如果直接把这个模式硬塞进现有 display state，后续顶部内容切换会和 staff / fretboard 内部语义耦在一起
- 本次实际改动：
- 新增 `NoteMaster_Ver_1/Shared/Controls/TopContentDisplayState.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 新增 `TopContentMode`，明确定义顶部区域的两种内容模式：`staff` 与 `targetPrompt`。
2. 新增 `TopContentDisplayState`，作为页面级顶部内容模式真相源，并提供默认值 `.staff`。
3. 在 `iOSViewController` 与 `macOSViewController` 中新增 `topContentDisplayState` 占位属性，明确后续 settings 和顶部 host 都会依赖这一路状态。

## 修改 1：新增独立的页面级顶部内容状态文件

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TopContentDisplayState.swift
// 函数/成员: 整个文件
// 功能说明: 修改前该文件不存在；
// 项目里没有独立的 shared 页面级状态来表达顶部区域当前显示的是五线谱还是目标音组件。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TopContentDisplayState.swift
// 函数/成员: TopContentMode, TopContentDisplayState, setMode(_:)
// 功能说明: 修改后新增独立的页面级顶部内容状态；
// 这类模式状态不进入五线谱或指板内部 display state，而是作为页面编排语义单独存在。
enum TopContentMode: Equatable, Hashable, Sendable {
    case staff
    case targetPrompt
}

struct TopContentDisplayState: Equatable, Sendable {
    // 顶部内容模式属于页面编排状态，不进入五线谱或指板内部 display state。
    var mode: TopContentMode

    static let `default` = TopContentDisplayState(mode: .staff)

    init(mode: TopContentMode = .staff) {
        self.mode = mode
    }

    mutating func setMode(_ mode: TopContentMode) {
        self.mode = mode
    }
}
```

## 修改 2：iOS 控制器开始持有顶部内容状态

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: staffDisplayState, isSettingsPresented
// 功能说明: 修改前 iOS 控制器只持有 staff / fretboard 两路显示状态，
// 还没有第三路页面级状态来承接顶部内容切换。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
) {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyStaffDisplayState()
    }
}

private var isSettingsPresented = false
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: topContentDisplayState
// 功能说明: 修改后 iOS 控制器显式持有页面级顶部内容状态；
// 这一步先把状态边界立住，后续阶段再把 settings 与 topContentHostView 接进来。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
) {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyStaffDisplayState()
    }
}
// 顶部内容模式独立于 staff / fretboard display state；
// 后续阶段再接 settings 与 topContentHostView。
private var topContentDisplayState = TopContentDisplayState.default

private var isSettingsPresented = false
```

## 修改 3：macOS 控制器对称持有顶部内容状态

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: staffDisplayState, isSettingsPresented
// 功能说明: 修改前 macOS 控制器与 iOS 一样，只持有 staff / fretboard 两路显示状态；
// 顶部区域显示什么内容还没有单独的页面级真相源。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
) {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyStaffDisplayState()
    }
}

private var isSettingsPresented = false
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: topContentDisplayState
// 功能说明: 修改后 macOS 控制器与 iOS 对称，显式持有页面级顶部内容状态；
// 这样后续做双平台 topContentHostView 和 settings 接线时，不会再回头调整状态归属。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
) {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyStaffDisplayState()
    }
}
// 顶部内容模式独立于 staff / fretboard display state；
// 后续阶段再接 settings 与 topContentHostView。
private var topContentDisplayState = TopContentDisplayState.default

private var isSettingsPresented = false
```

## 这次修改解决了什么

- 解决了“顶部区域切换缺少独立状态真相源”的基础结构问题。
- 明确顶部内容模式属于页面编排状态，而不是 staff / fretboard 内部显示状态。
- 为后续阶段 2 的 settings choice row 和阶段 4 的 `topContentHostView` 重构提前固定了状态归属。

## 本次明确未修改的边界

- 未修改 `SettingsPanelModel.swift`
- 未修改 `SettingsPanelSnapshotBuilder.swift`
- 未修改任何 settings 平台视图
- 未修改顶部布局结构，当前仍然是 `staffView` 直接占据顶部区域
- 未新增目标音显示组件

## 验证结果

### 静态检查

- `ReadLints` 检查以下 3 个文件，结果为无错误：
- `NoteMaster_Ver_1/Shared/Controls/TopContentDisplayState.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 使用 macOS SDK 对项目内 Swift 文件做 typecheck，确认新增页面级顶部内容状态后编译链保持通过。
xcrun swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk NoteMaster_Ver_1/**/*.swift
```

- 结果：通过
- 结论：阶段 1 只新增了状态真相与控制器占位，不引入行为变化，但已经为后续 settings 和顶部布局重构奠定了稳定边界

# 20260327_095304_phase1_pagestate_domain_and_settings_context

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_095304`
- 记录范围：`PageDisplayState` 阶段 1，页面状态域收口与 settings 上下文重构
- 本次目标：把现有只覆盖顶部区域的页面状态提升为统一 `PageDisplayState`，同时把 settings 读写链路从“三路并列 state 参数”收口为单一 `SettingsPanelStateContext`
- 根因结论：修改前页面级状态只存在于 `TopContentDisplayState`，settings 事件和快照构建依赖 `fretboard/staff/topContent` 三路并列参数；这会导致后续一旦接入主内容区域模式，就要继续扩 `SettingsPanelEvent.apply(...)`、`SettingsPanelSnapshotBuilder.makeModel(...)` 和双平台 controller 的签名，页面编排状态也会继续分散
- 本次实际改动：
- 新增 `NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift`
- 新增 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 删除 `NoteMaster_Ver_1/Shared/Controls/TopContentDisplayState.swift`

## 修改 1：页面状态从 `TopContentDisplayState` 升级为 `PageDisplayState`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/TopContentDisplayState.swift
// 函数/成员: TopContentMode, TopContentDisplayState
// 功能说明: 修改前页面级状态只覆盖顶部区域，没有主内容模式，也没有为后续页面扩展预留统一入口。
enum TopContentMode: Equatable, Hashable, Sendable {
    case staff
    case targetPrompt
}

struct TopContentDisplayState: Equatable, Sendable {
    var mode: TopContentMode

    static let `default` = TopContentDisplayState(mode: .staff)

    mutating func setMode(_ mode: TopContentMode) {
        self.mode = mode
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift
// 函数/成员: PageTopContentMode, PageMainContentMode, PageDisplayState
// 功能说明: 修改后统一承载顶部区域和主内容区域两类页面编排状态；
// 当前默认行为仍保持“顶部显示 staff、主内容显示 fretboard”。
enum PageTopContentMode: Equatable, Hashable, Sendable {
    case staff
    case targetPrompt
}

enum PageMainContentMode: Equatable, Hashable, Sendable {
    case fretboard
    case naturalNoteStrip
}

struct PageDisplayState: Equatable, Sendable {
    var topContentMode: PageTopContentMode
    var mainContentMode: PageMainContentMode

    static let `default` = PageDisplayState(
        topContentMode: .staff,
        mainContentMode: .fretboard
    )

    mutating func setTopContentMode(_ mode: PageTopContentMode) {
        topContentMode = mode
    }

    mutating func setMainContentMode(_ mode: PageMainContentMode) {
        mainContentMode = mode
    }
}
```

## 修改 2：新增 `SettingsPanelStateContext`，把 settings 三路状态收口为一个上下文

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsPanelEvent.apply(to:and:topContentDisplayState:)
// 功能说明: 修改前 SettingsPanelEvent 需要显式接收三份独立 state；
// 后续页面状态继续增加时，这个入口会继续增长参数。
func apply(
    to fretboardDisplayState: inout FretboardDisplayState,
    and staffDisplayState: inout StaffDisplayState,
    topContentDisplayState: inout TopContentDisplayState
) {
    switch self {
    case let .triggerAction(actionID):
        actionID.apply(to: &fretboardDisplayState)
        actionID.apply(to: &staffDisplayState)
        actionID.apply(to: &topContentDisplayState)
    case let .setSliderValue(sliderID, value):
        sliderID.apply(value: value, to: &fretboardDisplayState)
        sliderID.apply(value: value, to: &staffDisplayState)
    case let .setToggleValue(toggleID, value):
        toggleID.apply(value: value, to: &fretboardDisplayState)
        toggleID.apply(value: value, to: &staffDisplayState)
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift
// 函数/成员: SettingsPanelStateContext
// 功能说明: 修改后把 settings 读写链路所需的三份显示状态装配成单一上下文；
// controller、snapshot builder 和 event apply 统一使用这一个入口。
struct SettingsPanelStateContext: Equatable, Sendable {
    var fretboardDisplayState: FretboardDisplayState
    var staffDisplayState: StaffDisplayState
    var pageDisplayState: PageDisplayState

    static let `default` = SettingsPanelStateContext(
        fretboardDisplayState: .default,
        staffDisplayState: .default,
        pageDisplayState: .default
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsPanelEvent.apply(to:)
// 功能说明: 修改后 SettingsPanelEvent 只接收一个 stateContext；
// action、slider、toggle 都先落到同一个组合上下文，再由外层拆回各自 state。
func apply(
    to stateContext: inout SettingsPanelStateContext
) {
    switch self {
    case let .triggerAction(actionID):
        actionID.apply(to: &stateContext)
    case let .setSliderValue(sliderID, value):
        sliderID.apply(value: value, to: &stateContext)
    case let .setToggleValue(toggleID, value):
        toggleID.apply(value: value, to: &stateContext)
    }
}
```

## 修改 3：`SettingsActionID` 与 `SettingsPanelSnapshotBuilder` 改为直接消费组合上下文

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsActionID.isSelected(fretboardDisplayState:staffDisplayState:topContentDisplayState:)
// 功能说明: 修改前 choice row 的选中态计算显式依赖三份独立 state，
// 只要页面状态字段继续增加，这里就要继续扩签名。
func isSelected(
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState,
    topContentDisplayState: TopContentDisplayState
) -> Bool {
    switch self {
    case .setTopContentStaff:
        return topContentDisplayState.mode == .staff
    case .setTopContentTargetPrompt:
        return topContentDisplayState.mode == .targetPrompt
    default:
        return false
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeModel(fretboardDisplayState:staffDisplayState:topContentDisplayState:)
// 功能说明: 修改前 snapshot builder 也依赖三份并列参数，和 event apply 的扩展压力完全同步。
static func makeModel(
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState,
    topContentDisplayState: TopContentDisplayState
) -> SettingsPanelModel {
    SettingsPanelModel(
        sections: SettingsSectionID.allCases.compactMap {
            makeSection(
                id: $0,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState,
                topContentDisplayState: topContentDisplayState
            )
        }
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsActionID.isSelected(in:), SettingsActionID.apply(to:), SettingsActionID.apply(to:stateContext:)
// 功能说明: 修改后页面级读写统一走 stateContext；
// 顶部内容动作不再写入独立的 TopContentDisplayState，而是落到 PageDisplayState.topContentMode。
func isSelected(
    in stateContext: SettingsPanelStateContext
) -> Bool {
    switch self {
    case .setTopContentStaff:
        return stateContext.pageDisplayState.topContentMode == .staff
    case .setTopContentTargetPrompt:
        return stateContext.pageDisplayState.topContentMode == .targetPrompt
    case .setClefTreble:
        return stateContext.staffDisplayState.configuration.clef == .treble
    case .setClefBass:
        return stateContext.staffDisplayState.configuration.clef == .bass
    default:
        return false
    }
}

func apply(to displayState: inout PageDisplayState) {
    switch self {
    case .setTopContentStaff:
        displayState.setTopContentMode(.staff)
    case .setTopContentTargetPrompt:
        displayState.setTopContentMode(.targetPrompt)
    default:
        return
    }
}

func apply(to stateContext: inout SettingsPanelStateContext) {
    apply(to: &stateContext.fretboardDisplayState)
    apply(to: &stateContext.staffDisplayState)
    apply(to: &stateContext.pageDisplayState)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeModel(from:), makeChoiceItem(id:stateContext:)
// 功能说明: 修改后 snapshot builder 只依赖一个 SettingsPanelStateContext；
// 这样快照构建和事件写回共用同一份状态真相，不再分别维护多参数签名。
static func makeModel(
    from stateContext: SettingsPanelStateContext
) -> SettingsPanelModel {
    SettingsPanelModel(
        sections: SettingsSectionID.allCases.compactMap {
            makeSection(
                id: $0,
                stateContext: stateContext
            )
        }
    )
}

private static func makeChoiceItem(
    id: SettingsActionID,
    stateContext: SettingsPanelStateContext
) -> SettingsChoiceItem {
    SettingsChoiceItem(
        id: id,
        title: id.title,
        accessibilityLabel: id.accessibilityLabel,
        isSelected: id.isSelected(in: stateContext),
        isEnabled: id.isEnabled(in: stateContext)
    )
}
```

## 修改 4：双平台 controller 改为持有 `pageDisplayState`，并通过 context 驱动 settings

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: topContentDisplayState, applyTopContentDisplayState(), handleSettingsPanelEvent(_:)
// 功能说明: 修改前 controller 直接持有 TopContentDisplayState，
// settings 事件回写时需要先组装三份 next state，再分别比较和赋值。
private var topContentDisplayState = TopContentDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyTopContentDisplayState()
    }
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
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: pageDisplayState, settingsPanelStateContext, applyPageDisplayState(), handleSettingsPanelEvent(_:)
// 功能说明: 修改后 controller 只把页面编排状态暴露为 PageDisplayState；
// settings 相关读取和写回都通过 SettingsPanelStateContext 收口，顶部 UI 切换逻辑则先保留在 applyPageDisplayState()。
private var pageDisplayState = PageDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
    }
}

private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState
    )
}

private func applyPageDisplayState() {
    let showsStaff = pageDisplayState.topContentMode == .staff
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
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextPageDisplayState = nextStateContext.pageDisplayState
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: pageDisplayState, settingsPanelStateContext, applyPageDisplayState(), handleSettingsPanelEvent(_:)
// 功能说明: macOS controller 与 iOS 对称迁移到同一套页面状态和 settings context 语义；
// 当前阶段仍只把 PageDisplayState.topContentMode 接进顶部内容区域。
private var pageDisplayState = PageDisplayState.default {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyPageDisplayState()
    }
}

private var settingsPanelStateContext: SettingsPanelStateContext {
    SettingsPanelStateContext(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        pageDisplayState: pageDisplayState
    )
}
```

## 修改 5：旧 `ButtonPanel` 桥接层同步切到新的 settings 上下文

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelActionID.isSelected(in:), ButtonPanelActionID.isEnabled(in:)
// 功能说明: 修改前 ButtonPanel 对 SettingsActionID 的桥接仍然传旧的 TopContentDisplayState.default。
func isSelected(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isSelected(
        fretboardDisplayState: displayState,
        staffDisplayState: .default,
        topContentDisplayState: .default
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelActionID.isSelected(in:), ButtonPanelActionID.isEnabled(in:)
// 功能说明: 修改后旧 ButtonPanel 继续保持默认 staff/page 语义，但桥接入口已经统一到 SettingsPanelStateContext。
func isSelected(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isSelected(
        in: SettingsPanelStateContext(
            fretboardDisplayState: displayState,
            staffDisplayState: .default,
            pageDisplayState: .default
        )
    )
}
```

## 本阶段刻意未做的修改

- 尚未把 settings 面板里的 `Content` row 重构成独立 `Page` section
- 尚未接入 `PageDisplayState.mainContentMode` 的 UI 使用方
- 尚未新增 `mainContentHostView`
- 尚未新增 iOS / macOS 的自然音按钮组件
- 尚未抽取 `C D E F G A B` 的 shared 单一真相

## 修改结果说明

- 页面级状态的共享入口已经从 `TopContentDisplayState` 迁移到 `PageDisplayState`
- settings 读写链路已经从多 `inout` 参数收口到 `SettingsPanelStateContext`
- 双平台 controller 已经统一改为：
  - 读 settings 快照时使用 `settingsPanelStateContext`
  - 回写 settings 事件时先更新 `nextStateContext`
  - 页面编排层入口改为 `applyPageDisplayState()`
- 当前行为上仍与阶段 0 保持一致：
  - 顶部区域仍可在 `staff` / `targetPrompt` 间切换
  - 主内容区域仍然只有 `fretboard`
- `TopContentDisplayState.swift` 已删除，避免新旧页面状态类型并存

## 验证记录

- 对以下文件运行 lint/诊断检查：无新增问题
  - `NoteMaster_Ver_1/Shared/Controls/PageDisplayState.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelStateContext.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
  - `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 用文本搜索确认运行代码中不再残留 `TopContentDisplayState` / `TopContentMode` / `topContentDisplayState` 的引用
- 当前未做整工程 `xcodebuild` 编译验证，原因是本机 `xcodebuild` 指向的是 `CommandLineTools`，不是完整 Xcode，报错如下：
  - `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`

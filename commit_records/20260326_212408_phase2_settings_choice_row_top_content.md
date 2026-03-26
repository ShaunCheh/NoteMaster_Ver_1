# 20260326_212408_phase2_settings_choice_row_top_content

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_212408`
- 记录范围：顶部内容切换方案的阶段 2，shared settings 模型与事件链扩展
- 本次目标：在现有 settings 架构下新增 `Content` choice row，并把 settings 事件从原来的 fretboard / staff 两路 state，扩展到第三路 `TopContentDisplayState`
- 根因结论：修改前 `SettingsPanelModel`、`SettingsPanelSnapshotBuilder`、双平台控制器里的 settings 处理链路，都只理解 `FretboardDisplayState` 与 `StaffDisplayState`。这样即使阶段 1 已经有了 `TopContentDisplayState`，settings 仍然无法把“顶部显示五线谱 / 显示目标音”作为 shared 真相去渲染、选中和派发事件，平台层只能各自打补丁，状态边界会重新发散
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 在 `Staff` section 下新增 `Content` choice row，定义 `Staff / Target` 两个 action。
2. 扩展 `SettingsActionID` 的选中态、可用态与 `apply` 逻辑，使其能直接读写 `TopContentDisplayState`。
3. 扩展 `SettingsPanelSnapshotBuilder.makeModel(...)`，让 settings 快照构建正式接收第三路 state。
4. 修改 iOS / macOS 控制器的 settings 初始化、刷新与事件处理逻辑，让 `topContentDisplayState` 进入统一事件链。
5. 补齐 `ButtonPanelModel` 的兼容调用，避免 `SettingsActionID` 方法签名扩展后留下编译缺口。

## 修改 1：`SettingsPanelModel` 新增 `Content` choice row

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSectionID.rowIDs, SettingsChoiceRowID, SettingsActionID
// 功能说明: 修改前 Staff 分组只有 clef 和三个 slider；
// shared settings 模型还没有任何一行可以表达“顶部内容模式”，也没有对应 action。
case .staff:
    return [
        .choice(.clef),
        .slider(.clefScale),
        .slider(.clefVerticalTrim),
        .slider(.clefAnchorYOffset)
    ]

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
    case setClefTreble
    case setClefBass
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSectionID.rowIDs, SettingsChoiceRowID, SettingsActionID
// 功能说明: 修改后 Staff 分组新增 Content choice row，
// 并用 shared action 明确表达顶部区域显示五线谱还是目标音组件。
case .staff:
    return [
        .choice(.content),
        .choice(.clef),
        .slider(.clefScale),
        .slider(.clefVerticalTrim),
        .slider(.clefAnchorYOffset)
    ]

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case content
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef

    var title: String {
        switch self {
        case .content:
            return "Content"
        // ... 其余 case 保持原有逻辑 ...
        }
    }

    var actionIDs: [SettingsActionID] {
        switch self {
        case .content:
            return [
                .setTopContentStaff,
                .setTopContentTargetPrompt
            ]
        // ... 其余 case 保持原有逻辑 ...
        }
    }
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
    case setClefTreble
    case setClefBass
}
```

## 修改 2：`SettingsActionID` 与 `SettingsPanelEvent` 正式扩到第三路 state

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsActionID.isSelected(...), isEnabled(...), SettingsPanelEvent.apply(...)
// 功能说明: 修改前选中态和事件派发只看 fretboard / staff 两路 state；
// Content row 即使加出来，也没有 shared 读写入口把状态真正接通。
func isSelected(
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState
) -> Bool {
    switch self {
    case .setClefTreble:
        return staffDisplayState.configuration.clef == .treble
    case .setClefBass:
        return staffDisplayState.configuration.clef == .bass
    // ... 其余 case 只处理 fretboard / staff ...
    }
}

func isEnabled(
    fretboardDisplayState _: FretboardDisplayState,
    staffDisplayState _: StaffDisplayState
) -> Bool {
    true
}

func apply(
    to fretboardDisplayState: inout FretboardDisplayState,
    and staffDisplayState: inout StaffDisplayState
) {
    switch self {
    case let .triggerAction(actionID):
        actionID.apply(to: &fretboardDisplayState)
        actionID.apply(to: &staffDisplayState)
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
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsActionID.isSelected(...), isEnabled(...), apply(to: inout TopContentDisplayState), SettingsPanelEvent.apply(...)
// 功能说明: 修改后 Content row 的选中态、事件派发与状态落地都走 shared 真相链路；
// 平台层不需要自己解释“Target / Staff”按钮含义，只消费第三路 display state 的结果。
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
    case .setClefTreble:
        return staffDisplayState.configuration.clef == .treble
    case .setClefBass:
        return staffDisplayState.configuration.clef == .bass
    // ... 其余 case 保持原有逻辑 ...
    }
}

func isEnabled(
    fretboardDisplayState _: FretboardDisplayState,
    staffDisplayState _: StaffDisplayState,
    topContentDisplayState _: TopContentDisplayState
) -> Bool {
    true
}

func apply(to displayState: inout TopContentDisplayState) {
    switch self {
    case .setTopContentStaff:
        displayState.setMode(.staff)
    case .setTopContentTargetPrompt:
        displayState.setMode(.targetPrompt)
    // ... 其余 action 不影响顶部内容模式 ...
    }
}

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

## 修改 3：`SettingsPanelSnapshotBuilder` 透传 `TopContentDisplayState`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: makeModel(...), makeSection(...), makeRow(...), makeChoiceRow(...), makeChoiceItem(...)
// 功能说明: 修改前 settings 快照构建只接收 fretboard / staff 两路输入；
// 即使 shared model 新增 Content row，也无法根据顶部内容状态计算选中态。
static func makeModel(
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState
) -> SettingsPanelModel {
    SettingsPanelModel(
        sections: SettingsSectionID.allCases.compactMap {
            makeSection(
                id: $0,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        }
    )
}

private static func makeChoiceItem(
    id: SettingsActionID,
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState
) -> SettingsChoiceItem {
    SettingsChoiceItem(
        id: id,
        title: id.title,
        accessibilityLabel: id.accessibilityLabel,
        isSelected: id.isSelected(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        ),
        isEnabled: id.isEnabled(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        )
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: makeModel(...), makeSection(...), makeRow(...), makeChoiceRow(...), makeChoiceItem(...)
// 功能说明: 修改后 settings 快照构建把第三路 topContentDisplayState 一路透传到底；
// Content row 的选中态和可用态从 snapshot builder 开始就是 shared 统一结果。
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

private static func makeChoiceItem(
    id: SettingsActionID,
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState,
    topContentDisplayState: TopContentDisplayState
) -> SettingsChoiceItem {
    SettingsChoiceItem(
        id: id,
        title: id.title,
        accessibilityLabel: id.accessibilityLabel,
        isSelected: id.isSelected(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState,
            topContentDisplayState: topContentDisplayState
        ),
        isEnabled: id.isEnabled(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState,
            topContentDisplayState: topContentDisplayState
        )
    )
}
```

## 修改 4：`ButtonPanelModel` 补齐兼容参数，消除 shared 调用缺口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelActionID.isSelected(in:), isEnabled(in:)
// 功能说明: 修改前 ButtonPanel 复用 SettingsActionID 的选中态与可用态计算，
// 但方法签名还是旧的两路 state 版本。
func isSelected(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isSelected(
        fretboardDisplayState: displayState,
        staffDisplayState: .default
    )
}

func isEnabled(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isEnabled(
        fretboardDisplayState: displayState,
        staffDisplayState: .default
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数/成员: ButtonPanelActionID.isSelected(in:), isEnabled(in:)
// 功能说明: 修改后 ButtonPanel 用默认的 TopContentDisplayState 补齐第三参，
// 保持旧按钮面板在 shared API 演进后继续可编译，并且不改变它原本只关心 fretboard 的职责边界。
func isSelected(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isSelected(
        fretboardDisplayState: displayState,
        staffDisplayState: .default,
        topContentDisplayState: .default
    )
}

func isEnabled(in displayState: FretboardDisplayState) -> Bool {
    settingsActionID.isEnabled(
        fretboardDisplayState: displayState,
        staffDisplayState: .default,
        topContentDisplayState: .default
    )
}
```

## 修改 5：双平台控制器把 `topContentDisplayState` 接入 settings 初始化、刷新与事件处理

### 修改前（iOS）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: settingsContainerView, applySettingsPanelState(), handleSettingsPanelEvent(_:)
// 功能说明: 修改前 iOS 控制器构建 settings model 和处理 settings 事件时，
// 只传递 fretboard / staff 两路状态；顶部内容状态还没有进入控制器的统一 apply 链。
private lazy var settingsContainerView: iOSSettingsContainerView = {
    let settingsContainerView = iOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState
        )
    )
    // ... 省略未改动代码 ...
}()

private func applySettingsPanelState() {
    settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState
    )

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState

    guard didChangeFretboard || didChangeStaff else {
        return
    }
}
```

### 修改后（iOS）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: settingsContainerView, applySettingsPanelState(), handleSettingsPanelEvent(_:)
// 功能说明: 修改后 iOS 控制器把 topContentDisplayState 接入 settings 构建与事件处理；
// 即使本阶段还没真正切顶部 UI，settings 自身也已经能维护 Content row 的选中态真相。
private lazy var settingsContainerView: iOSSettingsContainerView = {
    let settingsContainerView = iOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState,
            topContentDisplayState: topContentDisplayState
        )
    )
    // ... 省略未改动代码 ...
}()

private func applySettingsPanelState() {
    settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        topContentDisplayState: topContentDisplayState
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

    if didChangeTopContent, !didChangeFretboard, !didChangeStaff {
        applySettingsPanelState()
    }
}
```

### 修改前（macOS）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: settingsContainerView, applySettingsPanelState(), handleSettingsPanelEvent(_:)
// 功能说明: 修改前 macOS 控制器与 iOS 对称，也只处理两路 display state；
// settings 面板里的顶部内容切换还没有 shared 化入口。
private lazy var settingsContainerView: macOSSettingsContainerView = {
    let settingsContainerView = macOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState
        )
    )
    // ... 省略未改动代码 ...
}()

private func applySettingsPanelState() {
    settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState
    )
}

private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextDisplayState = displayState
    var nextStaffDisplayState = staffDisplayState
    event.apply(
        to: &nextDisplayState,
        and: &nextStaffDisplayState
    )

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState

    guard didChangeFretboard || didChangeStaff else {
        return
    }
}
```

### 修改后（macOS）

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: settingsContainerView, applySettingsPanelState(), handleSettingsPanelEvent(_:)
// 功能说明: 修改后 macOS 控制器与 iOS 对称接入 topContentDisplayState；
// 双平台 settings 现在已经共享同一条顶部内容模式事件链，不会再各自解释 Content row。
private lazy var settingsContainerView: macOSSettingsContainerView = {
    let settingsContainerView = macOSSettingsContainerView(
        model: SettingsPanelSnapshotBuilder.makeModel(
            fretboardDisplayState: displayState,
            staffDisplayState: staffDisplayState,
            topContentDisplayState: topContentDisplayState
        )
    )
    // ... 省略未改动代码 ...
}()

private func applySettingsPanelState() {
    settingsContainerView.model = SettingsPanelSnapshotBuilder.makeModel(
        fretboardDisplayState: displayState,
        staffDisplayState: staffDisplayState,
        topContentDisplayState: topContentDisplayState
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

    if didChangeTopContent, !didChangeFretboard, !didChangeStaff {
        applySettingsPanelState()
    }
}
```

## 这次修改解决了什么

- 解决了“阶段 1 已经有 `TopContentDisplayState`，但 settings 体系仍然完全感知不到它”的结构断层。
- 让 `Content` choice row 的定义、选中态、事件派发和状态落地都收口到 shared 层，而不是在 iOS / macOS 各自写特殊判断。
- 提前把阶段 4 需要的 `applyTopContentDisplayState()` 链路边界打通，避免后续顶部 host view 接入时再反向重构 settings。
- 顺带消除了 `ButtonPanelModel` 因 shared API 扩签名导致的编译缺口。

## 本次明确未修改的边界

- 未新增 iOS `UIView` 目标音组件
- 未新增 macOS `NSView` 目标音组件
- 未改造顶部区域布局，当前顶部仍然直接摆放 `staffView`
- 未引入 `topContentHostView`
- 未实现真正的“切换后显示目标音组件”视觉效果；本阶段只完成 settings 侧的 shared 事件链
- 未新增验证规则，validation 补充会放到后续阶段

## 验证结果

### 静态检查

- `ReadLints` 检查以下 5 个文件，结果为无错误：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 使用 macOS SDK 对项目内 Swift 文件做 typecheck，确认 settings 第三路 state 接线后编译链保持通过。
xcrun swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk NoteMaster_Ver_1/**/*.swift
```

- 结果：通过
- 结论：阶段 2 已把 `Content` row 和第三路 `TopContentDisplayState` 事件链接通，当前代码库静态检查与类型检查均保持通过

# 20260327_100220_phase2_settings_page_section_and_main_content_row

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_100220`
- 记录范围：`PageDisplayState` 阶段 2，shared settings 域整形
- 本次目标：把原来语义含混、挂在 `Staff` section 下的 `Content` row 正式拆成独立的 `Page` section，并补齐 `Main Content` 对 `PageDisplayState.mainContentMode` 的 shared 动作语义
- 根因结论：修改前 settings 里的页面编排入口仍然叫 `Content`，而且被放在 `Staff` section 下面；这会让“页面区域切换”继续被误解成五线谱内部配置。与此同时，虽然阶段1已经引入了 `PageDisplayState.mainContentMode`，但 settings 还没有任何 action 可以写入它，导致页面状态模型和 settings 域仍然不对称
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`

## 本次完成的修改

1. 新增独立的 `Page` section，并把页面编排相关 row 从 `Staff` section 中迁出。
2. 把旧的 `Content` row 拆成两个明确语义的 row：
   - `Top Content`
   - `Main Content`
3. 新增 `setMainContentFretboard` / `setMainContentNaturalNotes` 两个 `SettingsActionID`。
4. 把 `Main Content` 的选中态和状态迁移正式接到 `PageDisplayState.mainContentMode`。
5. 保持 `SettingsPanelSnapshotBuilder`、双平台 controller 和平台 settings view 不变，继续复用阶段1已经完成的通用快照/事件链路。

## 修改 1：新增独立 `Page` section，并把页面编排 row 从 `Staff` section 中迁出

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSectionID, SettingsSectionID.rowIDs, SettingsChoiceRowID.sectionID
// 功能说明: 修改前页面编排入口仍然是 Staff section 下的单个 Content row；
// 这样“页面级切换”会继续和 staff 内部配置混在一起。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case layout
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
        case .fretboard:
            return [
                .choice(.instrument),
                .choice(.displayMode),
                .choice(.labels),
                .choice(.spelling),
                .choice(.octave)
            ]
        case .staff:
            return [
                .choice(.content),
                .choice(.clef),
                .slider(.clefScale),
                .slider(.clefVerticalTrim),
                .slider(.clefAnchorYOffset)
            ]
        case .layout:
            return [
                .slider(.verticalHostHeightRatio)
            ]
        case .debug:
            return [
                .toggle(.showsComponentBounds)
            ]
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case content
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef

    var sectionID: SettingsSectionID {
        switch self {
        case .instrument, .displayMode, .labels, .spelling, .octave:
            return .fretboard
        case .content, .clef:
            return .staff
        }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSectionID, SettingsSectionID.rowIDs, SettingsChoiceRowID.sectionID
// 功能说明: 修改后页面编排入口被提升为独立的 Page section；
// Staff section 只保留 clef 和相关 slider，页面与 staff 的职责边界清晰分离。
enum SettingsSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case page
    case fretboard
    case staff
    case layout
    case debug

    var rowIDs: [SettingsRowID] {
        switch self {
        case .page:
            return [
                .choice(.topContent),
                .choice(.mainContent)
            ]
        case .fretboard:
            return [
                .choice(.instrument),
                .choice(.displayMode),
                .choice(.labels),
                .choice(.spelling),
                .choice(.octave)
            ]
        case .staff:
            return [
                .choice(.clef),
                .slider(.clefScale),
                .slider(.clefVerticalTrim),
                .slider(.clefAnchorYOffset)
            ]
        case .layout:
            return [
                .slider(.verticalHostHeightRatio)
            ]
        case .debug:
            return [
                .toggle(.showsComponentBounds)
            ]
        }
    }
}

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef

    var sectionID: SettingsSectionID {
        switch self {
        case .topContent, .mainContent:
            return .page
        case .instrument, .displayMode, .labels, .spelling, .octave:
            return .fretboard
        case .clef:
            return .staff
        }
    }
}
```

## 修改 2：把旧 `Content` row 拆成 `Top Content` / `Main Content`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsChoiceRowID.title, SettingsChoiceRowID.accessibilityLabel, SettingsChoiceRowID.presentationStyle, SettingsChoiceRowID.actionIDs
// 功能说明: 修改前只有一个 Content row；
// 它只能表达顶部内容切换，无法承载主内容模式。
enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case content
    // ... 其他 row

    var title: String {
        switch self {
        case .content:
            return "Content"
        default:
            return ""
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .content:
            return "Select top content"
        default:
            return ""
        }
    }

    var presentationStyle: SettingsPresentationStyle {
        switch self {
        case .content, .clef:
            return .segmented
        default:
            return .chips
        }
    }

    var actionIDs: [SettingsActionID] {
        switch self {
        case .content:
            return [
                .setTopContentStaff,
                .setTopContentTargetPrompt
            ]
        default:
            return []
        }
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsChoiceRowID.title, SettingsChoiceRowID.accessibilityLabel, SettingsChoiceRowID.presentationStyle, SettingsChoiceRowID.actionIDs
// 功能说明: 修改后拆成 Top Content 和 Main Content 两个 segmented row；
// shared settings 域可以分别表达顶部区域模式和主内容区域模式。
enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    // ... 其他 row

    var title: String {
        switch self {
        case .topContent:
            return "Top Content"
        case .mainContent:
            return "Main Content"
        default:
            return ""
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .topContent:
            return "Select top content"
        case .mainContent:
            return "Select main content"
        default:
            return ""
        }
    }

    var presentationStyle: SettingsPresentationStyle {
        switch self {
        case .topContent, .mainContent, .clef:
            return .segmented
        default:
            return .chips
        }
    }

    var actionIDs: [SettingsActionID] {
        switch self {
        case .topContent:
            return [
                .setTopContentStaff,
                .setTopContentTargetPrompt
            ]
        case .mainContent:
            return [
                .setMainContentFretboard,
                .setMainContentNaturalNotes
            ]
        default:
            return []
        }
    }
}
```

## 修改 3：新增 `Main Content` 动作，并把它们接到 `PageDisplayState.mainContentMode`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsActionID, SettingsActionID.rowID, SettingsActionID.isSelected(in:), SettingsActionID.apply(to: PageDisplayState)
// 功能说明: 修改前只有顶部内容动作，没有任何 action 可以写入 mainContentMode；
// 因此 PageDisplayState.mainContentMode 还没有 settings 入口。
enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    // ...
}

var rowID: SettingsChoiceRowID {
    switch self {
    case .setTopContentStaff,
         .setTopContentTargetPrompt:
        return .content
    default:
        return .instrument
    }
}

func isSelected(
    in stateContext: SettingsPanelStateContext
) -> Bool {
    switch self {
    case .setTopContentStaff:
        return stateContext.pageDisplayState.topContentMode == .staff
    case .setTopContentTargetPrompt:
        return stateContext.pageDisplayState.topContentMode == .targetPrompt
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsActionID, SettingsActionID.rowID, SettingsActionID.title, SettingsActionID.isSelected(in:), SettingsActionID.apply(to: PageDisplayState)
// 功能说明: 修改后 Main Content 有了独立 action 和选中规则；
// settings row 可以直接驱动 PageDisplayState.mainContentMode，但页面上的真实视图切换仍留到后续阶段实现。
enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    // ...
}

var rowID: SettingsChoiceRowID {
    switch self {
    case .setTopContentStaff,
         .setTopContentTargetPrompt:
        return .topContent
    case .setMainContentFretboard,
         .setMainContentNaturalNotes:
        return .mainContent
    default:
        return .instrument
    }
}

var title: String {
    switch self {
    case .setMainContentFretboard:
        return "Fretboard"
    case .setMainContentNaturalNotes:
        return "Natural Notes"
    default:
        return ""
    }
}

func isSelected(
    in stateContext: SettingsPanelStateContext
) -> Bool {
    switch self {
    case .setTopContentStaff:
        return stateContext.pageDisplayState.topContentMode == .staff
    case .setTopContentTargetPrompt:
        return stateContext.pageDisplayState.topContentMode == .targetPrompt
    case .setMainContentFretboard:
        return stateContext.pageDisplayState.mainContentMode == .fretboard
    case .setMainContentNaturalNotes:
        return stateContext.pageDisplayState.mainContentMode == .naturalNoteStrip
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
    case .setMainContentFretboard:
        displayState.setMainContentMode(.fretboard)
    case .setMainContentNaturalNotes:
        displayState.setMainContentMode(.naturalNoteStrip)
    default:
        return
    }
}
```

## 修改 4：本阶段刻意不改 builder / controller / 平台视图

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeModel(from:)
// 功能说明: 修改前 builder 已经是通用 section/row 构造器，只要 SettingsSectionID / SettingsChoiceRowID / SettingsActionID 更新，快照就会自动跟进。
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
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeModel(from:)
// 功能说明: 本阶段不需要修改 builder；
// Page section 与新增 action 会被现有通用构造逻辑自动纳入快照。
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: handleSettingsPanelEvent(_:)
// 功能说明: 本阶段也不需要修改 controller；
// 现有事件回写链路已经会把新增的 mainContent action 写入 pageDisplayState。
private func handleSettingsPanelEvent(_ event: SettingsPanelEvent) {
    var nextStateContext = settingsPanelStateContext
    event.apply(to: &nextStateContext)

    let nextDisplayState = nextStateContext.fretboardDisplayState
    let nextStaffDisplayState = nextStateContext.staffDisplayState
    let nextPageDisplayState = nextStateContext.pageDisplayState

    let didChangeFretboard = nextDisplayState != displayState
    let didChangeStaff = nextStaffDisplayState != staffDisplayState
    let didChangePage = nextPageDisplayState != pageDisplayState
    // ... 其余逻辑不变
}
```

## 修改结果说明

- settings shared model 现在已经能明确表达两类页面编排模式：
  - `Top Content`
  - `Main Content`
- 页面编排语义不再混挂在 `Staff` section 下，settings 域的职责边界和 `PageDisplayState` 一致了。
- `Main Content` 现在已经能把选择结果写入 `PageDisplayState.mainContentMode`。
- 当前还没有做主内容区域的真实视图切换，所以这次修改的效果主要体现在：
  - settings 面板模型层
  - page state 写入链路
  - 后续阶段4的接缝已经就位

## 本阶段刻意未做的修改

- 未修改 `SettingsPanelSnapshotBuilder.swift`
- 未修改 `iOSSettingsPanelView.swift`
- 未修改 `macOSSettingsPanelView.swift`
- 未修改 `iOSViewController.swift`
- 未修改 `macOSViewController.swift`
- 未新增 `mainContentHostView`
- 未新增自然音按钮组件

## 验证记录

- 对 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift` 运行 lint/诊断：无新增问题
- 用全文检索确认旧的 `.content` row 语义已清理干净，代码中只保留新的：
  - `Page`
  - `Top Content`
  - `Main Content`
  - `setMainContentFretboard`
  - `setMainContentNaturalNotes`
- 当前工作区在本阶段结束后仅有一个未提交修改文件：
  - `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`

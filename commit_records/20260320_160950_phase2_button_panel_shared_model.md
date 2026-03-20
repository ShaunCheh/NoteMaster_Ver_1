20260320_160950_phase2_button_panel_shared_model

# 原生按钮组件阶段 2 修改记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- 新增 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`

## 修改前

### 共享层还没有按钮语义模型文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls
// 函数名：无
// 功能说明：修改前 Shared/Controls 目录下只有展示状态文件，还没有承载按钮分组、按钮动作、按钮快照的共享语义层。
FretboardDisplayState.swift
```

### 展示状态只能派生 provider，还不能表达按钮动作和按钮快照

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift
// 函数名：contentProvider
// 功能说明：修改前共享层只有 displayState 本身以及从状态派生 NoteNameContentProvider 的能力，
// 还没有 action id、section、item，也没有“按钮动作 -> 状态迁移”的统一承载位置。
struct FretboardDisplayState: Equatable, Sendable {
    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool

    var contentProvider: NoteNameContentProvider {
        NoteNameContentProvider(
            visibility: visibility,
            spelling: spelling,
            showsOctave: showsOctave
        )
    }
}
```

### 平台层后续如果直接做按钮，会缺少统一的共享输入模型

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls
// 函数名：无
// 功能说明：修改前项目里没有 ButtonPanelModel 和 SnapshotBuilder，
// 因此后续 iOS/macOS 如果直接开始做按钮容器，就只能各自拼接标题、分组和选中规则，容易重新分叉。
// 修改前不存在下列文件：
// - ButtonPanelModel.swift
// - ButtonPanelSnapshotBuilder.swift
```

## 修改后

### 新增共享按钮语义模型 `ButtonPanelModel.swift`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名：title, selectionStyle, sectionID, accessibilityLabel, isSelected(in:), isEnabled(in:), apply(to:)
// 功能说明：新增按钮分组、按钮选择模式、按钮动作、按钮项、按钮分组和整体快照模型，
// 并把标题、可访问文案、选中规则、启用规则、状态迁移规则统一收敛到共享层。
enum ButtonPanelSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case labels
    case spelling
    case octave

    var title: String {
        switch self {
        case .labels:
            return "Labels"
        case .spelling:
            return "Spelling"
        case .octave:
            return "Octave"
        }
    }

    var selectionStyle: ButtonPanelSelectionStyle {
        switch self {
        case .labels, .spelling:
            return .singleSelection
        case .octave:
            return .independent
        }
    }
}

enum ButtonPanelActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave

    func isSelected(in displayState: FretboardDisplayState) -> Bool {
        // 根据共享 displayState 统一计算按钮选中态。
    }

    func apply(to displayState: inout FretboardDisplayState) {
        // 把按钮动作统一映射到 displayState 的状态迁移。
    }
}

struct ButtonPanelModel: Equatable, Sendable {
    var sections: [ButtonPanelSection]
}
```

### 新增按钮快照构建器 `ButtonPanelSnapshotBuilder.swift`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift
// 函数名：makeModel(from:), makeSection(id:displayState:), makeItem(for:displayState:)
// 功能说明：新增纯共享 builder，把 FretboardDisplayState 映射成平台无关的 ButtonPanelModel；
// 平台层后续只消费 sections/items，不再自己拼接标题、分组或选中逻辑。
enum ButtonPanelSnapshotBuilder {
    static func makeModel(from displayState: FretboardDisplayState) -> ButtonPanelModel {
        ButtonPanelModel(
            sections: ButtonPanelSectionID.allCases.map {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }

    private static func makeSection(
        id: ButtonPanelSectionID,
        displayState: FretboardDisplayState
    ) -> ButtonPanelSection {
        let actions = ButtonPanelActionID.allCases.filter { $0.sectionID == id }

        return ButtonPanelSection(
            id: id,
            title: id.title,
            selectionStyle: id.selectionStyle,
            items: actions.map {
                makeItem(
                    for: $0,
                    displayState: displayState
                )
            }
        )
    }
}
```

### `displayState` 现在可以直接消费共享动作语义

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名：apply(_:)
// 功能说明：通过扩展把按钮动作回写能力挂到 FretboardDisplayState 上，
// 后续控制器收到 actionId 后，可以直接调用 displayState.apply(actionId) 完成共享状态迁移。
extension FretboardDisplayState {
    mutating func apply(_ actionID: ButtonPanelActionID) {
        actionID.apply(to: &self)
    }
}
```

## 结果说明

- 阶段 2 的核心结果是把“按钮是什么、按钮如何分组、按钮何时选中、按钮点击后如何改变共享状态”全部收敛到 `Shared/Controls`。
- 这样后续阶段 3 和阶段 4 在实现 `UIKit/AppKit` 原生按钮容器时，只需要消费 `ButtonPanelModel`，不需要各自重新解释业务规则。
- 本次没有修改任何平台视图和控制器，也没有把按钮逻辑回流到 `iOSViewController` 或 `macOSViewController`。
- 已执行构建验证：`DEVELOPER_DIR=\"/Applications/Xcode.app/Contents/Developer\" xcodebuild -project \"NoteMaster_Ver_1.xcodeproj\" -scheme \"NoteMaster_Ver_1\" -destination \"generic/platform=macOS\" build` 与 `generic/platform=iOS Simulator` 均通过。
- 已使用系统 `date` 生成时间戳 `20260320_160950` 作为本记录文件前缀。

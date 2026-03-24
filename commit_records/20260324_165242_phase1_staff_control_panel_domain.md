20260324_165242_phase1_staff_control_panel_domain

# StaffControlPanel 阶段 1 共享域建模记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift`
- 修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
- 未修改 iOS / macOS 平台面板视图和控制器接线

## 修改前

### 项目里还没有 `StaffControlPanel` 的共享控制模型文件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift
// 函数名：无（新文件）
// 功能说明：修改前项目中不存在 StaffControlPanel 的共享控制域定义；
// slider 事件、section、slider item、panel model 以及共享 clamp 规则都还没有落位。
```

### `StaffDisplayState` 只能派生 `sceneProvider`，还不能统一消费 slider 事件

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数名：sceneProvider（计算属性）
// 功能说明：修改前 `StaffDisplayState` 只负责持有 `configuration` 并派生 `sceneProvider`，
// 还没有 `apply(_ event:)` 这类共享 reducer 入口，因此后续平台 slider 无法走统一状态迁移。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration

    static let `default` = StaffDisplayState(
        configuration: StaffConfiguration()
    )

    init(configuration: StaffConfiguration) {
        self.configuration = configuration
    }

    // 控制器只维护共享状态，scene provider 统一从状态派生。
    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            renderHint: .staffClef(
                boundsOverlayStyle: configuration.debugOptions.showsClefBounds
                ? .clefDebug(lineWidth: configuration.debugOptions.clefBoundsLineWidth)
                : nil,
                anchorOverlayStyle: configuration.debugOptions.showsClefAnchor
                ? .clefDebug(
                    lineWidth: configuration.debugOptions.clefAnchorLineWidth,
                    crossHalfLength: configuration.debugOptions.clefAnchorCrossHalfLength
                )
                : nil
            )
        )
    }
}
```

## 修改后

### 新增 `StaffControlPanel` 的共享事件、section、slider item 和 panel model

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelModel.swift
// 函数名：StaffControlEvent.apply(to:), StaffControlPanelModel.slider(for:)
// 功能说明：修改后新增 Staff 专用控制域模型，把 slider 事件、section、item 和 panel model 放到共享层，
// 并把 treble clef 锚点 y 偏移的范围约束统一收口到 `StaffControlEvent`，避免平台层各自 clamp。
import CoreGraphics

enum StaffControlSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case clef

    var title: String {
        switch self {
        case .clef:
            return "Clef"
        }
    }
}

enum StaffControlEvent: Equatable, Sendable {
    case setTrebleClefAnchorLogicalDownwardShiftRatio(CGFloat)

    // 连续值的约束统一收口在共享层，避免 iOS/macOS 各自重复 clamp。
    static let trebleClefAnchorLogicalDownwardShiftRatioRange: ClosedRange<CGFloat> = (-0.25)...0.25

    func apply(to displayState: inout StaffDisplayState) {
        switch self {
        case let .setTrebleClefAnchorLogicalDownwardShiftRatio(value):
            displayState.configuration.trebleClefAnchorLogicalDownwardShiftRatio = value.clamped(
                to: Self.trebleClefAnchorLogicalDownwardShiftRatioRange
            )
        }
    }
}

struct StaffSliderControlItem: Equatable, Hashable, Sendable {
    enum ID: CaseIterable, Equatable, Hashable, Sendable {
        case trebleClefAnchorYOffset

        var sectionID: StaffControlSectionID {
            switch self {
            case .trebleClefAnchorYOffset:
                return .clef
            }
        }

        var title: String {
            switch self {
            case .trebleClefAnchorYOffset:
                return "Anchor Y Offset"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .trebleClefAnchorYOffset:
                return "Adjust treble clef anchor vertical offset"
            }
        }

        var range: ClosedRange<CGFloat> {
            switch self {
            case .trebleClefAnchorYOffset:
                return StaffControlEvent.trebleClefAnchorLogicalDownwardShiftRatioRange
            }
        }
    }

    var id: ID
    var title: String
    var accessibilityLabel: String
    var value: CGFloat
    var range: ClosedRange<CGFloat>
    var displayValue: String
    var isEnabled: Bool
}

struct StaffControlSection: Equatable, Sendable {
    var id: StaffControlSectionID
    var title: String
    var sliders: [StaffSliderControlItem]
}

struct StaffControlPanelModel: Equatable, Sendable {
    var sections: [StaffControlSection]

    static let empty = StaffControlPanelModel(sections: [])

    var sliders: [StaffSliderControlItem] {
        sections.flatMap(\.sliders)
    }

    func slider(for id: StaffSliderControlItem.ID) -> StaffSliderControlItem? {
        sliders.first { $0.id == id }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
```

### `StaffDisplayState` 新增共享 reducer 入口，供后续平台 slider 直接复用

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数名：apply(_:)
// 功能说明：修改后 `StaffDisplayState` 增加统一的事件消费入口；
// 后续 iOS/macOS 控制器收到 slider 回调后，只需要转发 `StaffControlEvent`，不必自己解释配置写法。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration

    static let `default` = StaffDisplayState(
        configuration: StaffConfiguration()
    )

    init(configuration: StaffConfiguration) {
        self.configuration = configuration
    }

    // 控制器只维护共享状态，scene provider 统一从状态派生。
    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            renderHint: .staffClef(
                boundsOverlayStyle: configuration.debugOptions.showsClefBounds
                ? .clefDebug(lineWidth: configuration.debugOptions.clefBoundsLineWidth)
                : nil,
                anchorOverlayStyle: configuration.debugOptions.showsClefAnchor
                ? .clefDebug(
                    lineWidth: configuration.debugOptions.clefAnchorLineWidth,
                    crossHalfLength: configuration.debugOptions.clefAnchorCrossHalfLength
                )
                : nil
            )
        )
    }
}

extension StaffDisplayState {
    mutating func apply(_ event: StaffControlEvent) {
        event.apply(to: &self)
    }
}
```

## 结果说明

- `StaffControlPanel` 的共享控制域已经建立完成
- `trebleClefAnchorLogicalDownwardShiftRatio` 的 slider 事件现在有了统一的共享事件入口
- 连续值的范围约束已经收口在共享层，后续平台视图只负责发事件和展示模型
- 当前阶段仍未触及平台 slider 视图与控制器布局，符合阶段 1 范围

## 验证情况

- `ReadLints` 检查 `StaffControlPanelModel.swift`、`StaffDisplayState.swift`，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

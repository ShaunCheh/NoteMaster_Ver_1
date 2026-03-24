20260324_170103_phase2_staff_control_panel_snapshot_builder

# StaffControlPanel 阶段 2 快照构建记录

## 本次变更范围

- 新增 `NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift`
- 未修改 `StaffControlPanel` 共享模型、平台视图和控制器接线

## 修改前

### 项目里还没有 `StaffControlPanelSnapshotBuilder`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift
// 函数名：无（新文件）
// 功能说明：修改前项目中不存在 StaffControlPanel 的快照构建器；
// `StaffDisplayState` 还不能被投影成平台可直接消费的 slider section / item / display text。
```

## 修改后

### 新增共享快照构建器，把 `StaffDisplayState` 投影成 slider 可消费的 `StaffControlPanelModel`

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift
// 函数名：makeModel(from:), makeSection(id:displayState:), makeSlider(for:displayState:), displayValue(for:)
// 功能说明：修改后新增 StaffControlPanelSnapshotBuilder，负责从 StaffDisplayState 生成 section、slider 当前值、范围和显示文本；
// 同时把 `+0.11` 这类显示格式和接近 0 的归一化处理收口在共享层，避免平台各自拼字符串。
import Foundation
import CoreGraphics

enum StaffControlPanelSnapshotBuilder {
    static func makeModel(from displayState: StaffDisplayState) -> StaffControlPanelModel {
        StaffControlPanelModel(
            sections: StaffControlSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }

    private static func makeSection(
        id: StaffControlSectionID,
        displayState: StaffDisplayState
    ) -> StaffControlSection? {
        let sliders = StaffSliderControlItem.ID.allCases
            .filter { $0.sectionID == id }
            .map {
                makeSlider(
                    for: $0,
                    displayState: displayState
                )
            }

        guard !sliders.isEmpty else {
            return nil
        }

        return StaffControlSection(
            id: id,
            title: id.title,
            sliders: sliders
        )
    }

    private static func makeSlider(
        for sliderID: StaffSliderControlItem.ID,
        displayState: StaffDisplayState
    ) -> StaffSliderControlItem {
        let range = sliderID.range
        let value = resolvedValue(
            for: sliderID,
            displayState: displayState
        )
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)

        return StaffSliderControlItem(
            id: sliderID,
            title: sliderID.title,
            accessibilityLabel: sliderID.accessibilityLabel,
            value: clampedValue,
            range: range,
            displayValue: displayValue(for: clampedValue),
            isEnabled: isEnabled(
                for: sliderID,
                displayState: displayState
            )
        )
    }

    private static func resolvedValue(
        for sliderID: StaffSliderControlItem.ID,
        displayState: StaffDisplayState
    ) -> CGFloat {
        switch sliderID {
        case .trebleClefAnchorYOffset:
            return displayState.configuration.trebleClefAnchorLogicalDownwardShiftRatio
        }
    }

    private static func isEnabled(
        for sliderID: StaffSliderControlItem.ID,
        displayState _: StaffDisplayState
    ) -> Bool {
        switch sliderID {
        case .trebleClefAnchorYOffset:
            return true
        }
    }

    private static func displayValue(for value: CGFloat) -> String {
        // 避免接近 0 的值在 UI 上显示成 -0.00。
        let normalizedValue: CGFloat = abs(value) < 0.005 ? 0 : value
        return String(format: "%+.2f", Double(normalizedValue))
    }
}
```

## 结果说明

- `StaffDisplayState` 现在已经可以被投影成平台无关的 slider 展示模型
- `trebleClefAnchorLogicalDownwardShiftRatio` 的当前值、范围和展示文本都统一由共享层生成
- 后续 iOS / macOS 平台面板只需要消费 `StaffControlPanelModel`，不必自己理解 `StaffConfiguration` 的细节

## 验证情况

- `ReadLints` 检查 `StaffControlPanelSnapshotBuilder.swift`，无新增诊断
- 使用 `xcrun swiftc -parse-as-library -typecheck` 对项目 Swift 文件做静态检查，结果通过

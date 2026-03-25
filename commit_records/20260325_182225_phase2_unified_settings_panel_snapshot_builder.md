# 20260325_182225_phase2_unified_settings_panel_snapshot_builder

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_182225`
- 记录范围：方案 D 的实施阶段 2，统一快照构建器
- 本次目标：新增 `SettingsPanelSnapshotBuilder`，把当前 `ButtonPanelSnapshotBuilder`、`StaffControlPanelSnapshotBuilder`、`FretboardControlPanelSnapshotBuilder` 三套分散的快照派生逻辑，收口到统一的 `SettingsPanelModel` 生成入口中；本阶段不修改平台 UI 和控制器接线
- 本次实际改动：只新增了 1 个共享层 Swift 文件 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`

## 本次完成的修改

1. 新增 `SettingsPanelSnapshotBuilder.swift`，建立统一 settings 面板快照入口。
2. 将指板离散设置、五线谱设置、布局设置三组 section 的派生逻辑收口到新 builder。
3. 将 `verticalHostHeightRatio` 的显示条件收口到新 builder，而不是继续由平台层或旧 panel builder 分散解释。
4. 保持旧的三个 snapshot builder 文件不动，作为后续平台视图迁移前的兼容基线。
5. 完成新增文件的 lint 检查与共享层 `swiftc -typecheck` 校验。

## 修改 1：新增统一快照入口 `SettingsPanelSnapshotBuilder`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前项目中没有统一的 settings 快照构建器；后续若要渲染统一的 SettingsPanelView，控制器拿不到单一的 SettingsPanelModel。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeModel(fretboardDisplayState:staffDisplayState:)
// 功能说明: 修改后通过一个统一入口，把两份 display state 派生为完整的 SettingsPanelModel，供后续统一 settings 平台视图直接消费。
import Foundation
import CoreGraphics

enum SettingsPanelSnapshotBuilder {
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
}
```

## 修改 2：把原来分散在三套旧 builder 的派生逻辑收口到统一 builder

### 修改前：指板离散设置由 `ButtonPanelSnapshotBuilder` 单独派生

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift
// 函数/成员: ButtonPanelSnapshotBuilder.makeModel(from:), makeSection(id:displayState:), makeItem(for:displayState:)
// 功能说明: 修改前 instrument / displayMode / labels / spelling / octave 仍然由旧的 ButtonPanelSnapshotBuilder 返回 ButtonPanelModel。
enum ButtonPanelSnapshotBuilder {
    private static let orderedSectionIDs: [ButtonPanelSectionID] = [
        .instrument,
        .displayMode,
        .labels,
        .spelling,
        .octave
    ]

    static func makeModel(from displayState: FretboardDisplayState) -> ButtonPanelModel {
        ButtonPanelModel(
            sections: orderedSectionIDs.map {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }
}
```

### 修改前：五线谱设置由 `StaffControlPanelSnapshotBuilder` 单独派生

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift
// 函数/成员: StaffControlPanelSnapshotBuilder.makeModel(from:), makeRows(for:displayState:)
// 功能说明: 修改前 clef / clefScale / clefVerticalTrim / clefAnchorYOffset 仍然由旧的 StaffControlPanelSnapshotBuilder 返回 StaffControlPanelModel。
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

    private static func makeRows(
        for sectionID: StaffControlSectionID,
        displayState: StaffDisplayState
    ) -> [StaffControlRow] {
        let optionRows = StaffOptionControlItem.ID.allCases
            .filter { $0.sectionID == sectionID }
            .map {
                StaffControlRow.option(
                    makeOption(
                        for: $0,
                        displayState: displayState
                    )
                )
            }

        let sliderRows = StaffSliderControlItem.ID.allCases
            .filter { $0.sectionID == sectionID }
            .map {
                StaffControlRow.slider(
                    makeSlider(
                        for: $0,
                        displayState: displayState
                    )
                )
            }

        return optionRows + sliderRows
    }
}
```

### 修改前：竖向指板高度设置由 `FretboardControlPanelSnapshotBuilder` 单独派生

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift
// 函数/成员: FretboardControlPanelSnapshotBuilder.makeModel(from:)
// 功能说明: 修改前 vertical fretboard height 由旧的 FretboardControlPanelSnapshotBuilder 单独生成，并在入口直接判断 vertical 模式。
enum FretboardControlPanelSnapshotBuilder {
    static func makeModel(from displayState: FretboardDisplayState) -> FretboardControlPanelModel {
        guard displayState.displayMode == .vertical else {
            return .empty
        }

        return FretboardControlPanelModel(
            sections: FretboardControlSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    displayState: displayState
                )
            }
        )
    }
}
```

### 修改后：统一 builder 直接构建 choice row / slider row

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: makeSection(id:fretboardDisplayState:staffDisplayState:), makeRow(id:fretboardDisplayState:staffDisplayState:), makeChoiceRow(id:fretboardDisplayState:staffDisplayState:), makeSliderRow(id:fretboardDisplayState:staffDisplayState:)
// 功能说明: 修改后新的 builder 统一遍历 SettingsSectionID / SettingsRowID，并基于 SettingsActionID、SettingsSliderID 直接生成 SettingsChoiceRow 与 SettingsSliderRow。
enum SettingsPanelSnapshotBuilder {
    private static func makeSection(
        id: SettingsSectionID,
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> SettingsSection? {
        let rows = id.rowIDs.compactMap {
            makeRow(
                id: $0,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            )
        }

        guard !rows.isEmpty else {
            return nil
        }

        return SettingsSection(
            id: id,
            title: id.title,
            rows: rows
        )
    }

    private static func makeRow(
        id: SettingsRowID,
        fretboardDisplayState: FretboardDisplayState,
        staffDisplayState: StaffDisplayState
    ) -> SettingsRow? {
        switch id {
        case let .choice(choiceRowID):
            return .choice(
                makeChoiceRow(
                    id: choiceRowID,
                    fretboardDisplayState: fretboardDisplayState,
                    staffDisplayState: staffDisplayState
                )
            )
        case let .slider(sliderID):
            guard shouldInclude(
                sliderID: sliderID,
                fretboardDisplayState: fretboardDisplayState,
                staffDisplayState: staffDisplayState
            ) else {
                return nil
            }

            return .slider(
                makeSliderRow(
                    id: sliderID,
                    fretboardDisplayState: fretboardDisplayState,
                    staffDisplayState: staffDisplayState
                )
            )
        }
    }
}
```

## 修改 3：把 `Layout` 区的显示条件收口到统一 builder

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelSnapshotBuilder.swift
// 函数/成员: FretboardControlPanelSnapshotBuilder.makeModel(from:)
// 功能说明: 修改前“竖向模式才显示高度 slider”这条规则只存在于旧的 FretboardControlPanelSnapshotBuilder 入口，无法直接服务新的统一 settings panel。
static func makeModel(from displayState: FretboardDisplayState) -> FretboardControlPanelModel {
    guard displayState.displayMode == .vertical else {
        return .empty
    }

    return FretboardControlPanelModel(
        sections: FretboardControlSectionID.allCases.compactMap {
            makeSection(
                id: $0,
                displayState: displayState
            )
        }
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeSection(id:fretboardDisplayState:staffDisplayState:), shouldInclude(sliderID:fretboardDisplayState:staffDisplayState:)
// 功能说明: 修改后“是否展示某个设置项”的判断被集中放回统一 builder；当 vertical 高度 slider 不满足显示条件时，Layout section 会因为 rows 为空而自然消失。
private static func makeSection(
    id: SettingsSectionID,
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState
) -> SettingsSection? {
    let rows = id.rowIDs.compactMap {
        makeRow(
            id: $0,
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        )
    }

    guard !rows.isEmpty else {
        return nil
    }

    return SettingsSection(
        id: id,
        title: id.title,
        rows: rows
    )
}

private static func shouldInclude(
    sliderID: SettingsSliderID,
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState _: StaffDisplayState
) -> Bool {
    switch sliderID {
    case .verticalHostHeightRatio:
        return fretboardDisplayState.displayMode == .vertical
    case .clefScale, .clefVerticalTrim, .clefAnchorYOffset:
        return true
    }
}
```

## 修改 4：统一 slider 行的值解析、clamp 后显示值与可用态

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffControlPanelSnapshotBuilder.swift
// 函数/成员: makeSlider(for:displayState:)
// 功能说明: 修改前 staff slider 的 value / range / displayValue / isEnabled 在旧 builder 中单独拼装。
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
        displayValue: displayValue(
            for: sliderID,
            value: clampedValue
        ),
        isEnabled: isEnabled(
            for: sliderID,
            displayState: displayState
        )
    )
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeSliderRow(id:fretboardDisplayState:staffDisplayState:)
// 功能说明: 修改后 slider 行统一从 SettingsSliderID 获取 range、resolvedValue、displayValue 和 isEnabled，避免继续分散在旧 builder 里重复实现。
private static func makeSliderRow(
    id: SettingsSliderID,
    fretboardDisplayState: FretboardDisplayState,
    staffDisplayState: StaffDisplayState
) -> SettingsSliderRow {
    let range = id.range
    let value = id.resolvedValue(
        fretboardDisplayState: fretboardDisplayState,
        staffDisplayState: staffDisplayState
    )
    let clampedValue = min(max(value, range.lowerBound), range.upperBound)

    return SettingsSliderRow(
        id: id,
        title: id.title,
        accessibilityLabel: id.accessibilityLabel,
        value: clampedValue,
        range: range,
        displayValue: id.displayValue(for: clampedValue),
        isEnabled: id.isEnabled(
            fretboardDisplayState: fretboardDisplayState,
            staffDisplayState: staffDisplayState
        )
    )
}
```

## 验证结果

1. `SettingsPanelSnapshotBuilder.swift` 已执行 lint 检查，结果为无 linter 错误。
2. 共享层 Swift 文件已执行 `swiftc -typecheck`，结果通过。
3. 本阶段没有改动平台 view、控制器布局和事件接线，因此本次记录不包含任何 UI 结构变化。

## 结果说明

- 阶段 2 完成后，共享层已经具备“从 `FretboardDisplayState` + `StaffDisplayState` 一次性派生 `SettingsPanelModel`”的能力。
- 旧的三个 snapshot builder 仍然保留，当前只是把“统一 settings panel 所需的快照真相”建立起来，还没有切换平台层消费方。
- 因此此阶段结束后，代码层面已经新增统一 builder，但界面上不会出现可见变化；可见变化会发生在后续统一 settings 平台视图和控制器迁移阶段。

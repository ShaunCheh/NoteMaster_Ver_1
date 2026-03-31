# 20260331_110023_phase3_position_filter_snapshot_projection

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_110023`
- 记录范围：实施“Position 过滤模式重构”计划的阶段 3，只完成 settings 快照投影与 `Trainer` 分区 row 组成的收口；不包含 shared trainer 候选池改造，不包含 controller 的 session 重建逻辑，不包含 validation 扩展
- 本次目标：让 settings 快照真正由 `TrainerPositionPromptConfiguration.filterMode` 驱动，在 `positionPrompt` 模式下显示过滤模式切换 row，并让通用多选 row 在 `Note Names` 与 `Frets` 之间切换
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`

## 本次结论

- `Trainer` 分区现在会在 `exerciseMode` 后面挂上 `positionPromptFilterMode` 这条 choice row
- 过滤模式相关 row 只会在 `positionPrompt` 模式下出现，不会污染其他练习模式的 settings 面板
- 通用多选 row 不再固定渲染 `Frets`，而是根据 `filterMode` 在 `C D E F G A B` 与 `1...12` 之间切换
- “至少保留 1 个选中项”的禁用逻辑已经同时作用于音名过滤和品位过滤

## 修改 1：`Trainer` 分区补上过滤模式切换 row

### 修改前

- `Trainer` 分区只有 `exerciseMode` 和通用多选 row
- 即使阶段 2 已经引入了 `positionPromptFilterMode` 的 action / event，快照入口仍然没有把这条 row 放进来

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsSectionID.rowIDs
// 功能说明: 修改前 Trainer 分区只挂 exerciseMode 和通用多选 row；
// 过滤模式切换 row 还没有进入 snapshot 的 row 列表，因此界面上无法出现 Filter 分段选择。
var rowIDs: [SettingsRowID] {
    switch self {
    case .trainer:
        return [
            .choice(.exerciseMode),
            .positionFilter(.positionPromptFilterOptions)
        ]
    default:
        return []
    }
}
```

### 修改后

- `Trainer` 分区现在显式加入 `.choice(.positionPromptFilterMode)`
- 这样 snapshot builder 在处理 `trainer` 分区时，才有机会真正投影出 `Filter: Note Names | Frets`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名/符号: SettingsSectionID.rowIDs
// 功能说明: 修改后 Trainer 分区把过滤模式切换 row 正式纳入 row 列表；
// 这让 settings 快照可以先渲染 Filter 分段选择，再渲染对应的通用多选项。
var rowIDs: [SettingsRowID] {
    switch self {
    case .trainer:
        return [
            .choice(.exerciseMode),
            .choice(.positionPromptFilterMode),
            .positionFilter(.positionPromptFilterOptions)
        ]
    default:
        return []
    }
}
```

## 修改 2：choice row 也接入 `positionPrompt` 模式显隐

### 修改前

- `makeRow(id:stateContext:)` 对 `.choice(...)` 没有显隐判断
- 这意味着一旦把 `.choice(.positionPromptFilterMode)` 放进 `rowIDs`，它会在非 `positionPrompt` 模式下也被无条件渲染出来

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: SettingsPanelSnapshotBuilder.makeRow(id:stateContext:)
// 功能说明: 修改前 choice row 没有 shouldInclude 判断；
// 如果后续直接把 positionPromptFilterMode 放进 Trainer 分区，它会泄漏到其他 exercise mode。
private static func makeRow(
    id: SettingsRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsRow? {
    switch id {
    case let .choice(choiceRowID):
        return .choice(
            makeChoiceRow(
                id: choiceRowID,
                stateContext: stateContext
            )
        )
    case let .positionFilter(positionFilterRowID):
        guard shouldInclude(
            positionFilterRowID: positionFilterRowID,
            stateContext: stateContext
        ) else {
            return nil
        }
        // ... 省略其他分支
        return nil
    }
}
```

### 修改后

- `choice` 分支新增 `shouldInclude(choiceRowID:stateContext:)`
- 目前只对 `.positionPromptFilterMode` 做特判，要求 `trainerDisplayState.isPositionPromptMode == true`
- 这样 `Filter` row 与通用多选 row 的出现条件保持一致

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: SettingsPanelSnapshotBuilder.makeRow(id:stateContext:),
//            SettingsPanelSnapshotBuilder.shouldInclude(choiceRowID:stateContext:)
// 功能说明: 修改后 choice row 也走显隐判定；
// positionPromptFilterMode 只会在 Position Prompt 模式下投影出来，避免污染其他练习模式。
private static func makeRow(
    id: SettingsRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsRow? {
    switch id {
    case let .choice(choiceRowID):
        guard shouldInclude(
            choiceRowID: choiceRowID,
            stateContext: stateContext
        ) else {
            return nil
        }

        return .choice(
            makeChoiceRow(
                id: choiceRowID,
                stateContext: stateContext
            )
        )
    case let .positionFilter(positionFilterRowID):
        guard shouldInclude(
            positionFilterRowID: positionFilterRowID,
            stateContext: stateContext
        ) else {
            return nil
        }
        // ... 省略其他分支
        return nil
    }
}

private static func shouldInclude(
    choiceRowID: SettingsChoiceRowID,
    stateContext: SettingsPanelStateContext
) -> Bool {
    switch choiceRowID {
    case .positionPromptFilterMode:
        return stateContext.trainerDisplayState.isPositionPromptMode
    default:
        return true
    }
}
```

## 修改 3：通用多选 row 改为按 `filterMode` 投影音名或品位

### 修改前

- `makePositionFilterRow(...)` 仍然硬编码为 `Frets`
- 即使 shared state 已经有 `filterMode` / `selectedPitchClasses`，快照层仍只会渲染 `1...12`
- 这也是阶段 2 结束时“UI 结构已抽象，但新过滤模式尚未真正暴露”的直接原因

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: SettingsPanelSnapshotBuilder.makePositionFilterRow(id:stateContext:)
// 功能说明: 修改前 position filter row 仍然固定渲染 Frets；
// snapshot 没有读取 filterMode，因此 noteName 模式不会映射成 C D E F G A B 这组按钮。
private static func makePositionFilterRow(
    id: SettingsPositionFilterRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsPositionFilterRow {
    let configuration = stateContext.trainerDisplayState.positionPromptConfiguration

    return SettingsPositionFilterRow(
        id: id,
        title: "Frets",
        accessibilityLabel: "Select the frets used when generating position prompt questions",
        options: id.supportedFrets.map { fret in
            let isSelected = configuration.contains(fret)
            return SettingsPositionFilterItem(
                id: .fret(fret),
                title: "\(fret)",
                accessibilityLabel: "Toggle fret \(fret) for position prompt questions",
                isSelected: isSelected,
                isEnabled: !isSelected || configuration.canDeselect(fret)
            )
        }
    )
}
```

### 修改后

- `makePositionFilterRow(...)` 现在直接读取 `configuration.filterMode`
- `noteName` 分支按 `id.supportedPitchClasses` 输出 `C D E F G A B`
- `fret` 分支继续输出 `1...12`
- 两个分支都保留“最后一个已选项不可取消”的保护逻辑

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名/符号: SettingsPanelSnapshotBuilder.makePositionFilterRow(id:stateContext:)
// 功能说明: 修改后 position filter row 完全由 filterMode 驱动；
// noteName 模式渲染自然音按钮，fret 模式渲染品位按钮，并分别复用对应的“至少保留 1 个”保护逻辑。
private static func makePositionFilterRow(
    id: SettingsPositionFilterRowID,
    stateContext: SettingsPanelStateContext
) -> SettingsPositionFilterRow {
    let configuration = stateContext.trainerDisplayState.positionPromptConfiguration

    switch configuration.filterMode {
    case .noteName:
        return SettingsPositionFilterRow(
            id: id,
            title: "Note Names",
            accessibilityLabel: "Select the note names used when generating position prompt questions",
            options: id.supportedPitchClasses.map { pitchClass in
                let title = pitchClass.displayText()
                let isSelected = configuration.contains(pitchClass)
                return SettingsPositionFilterItem(
                    id: .pitchClass(pitchClass),
                    title: title,
                    accessibilityLabel: "Toggle note name \(title) for position prompt questions",
                    isSelected: isSelected,
                    isEnabled: !isSelected || configuration.canDeselect(pitchClass)
                )
            }
        )
    case .fret:
        return SettingsPositionFilterRow(
            id: id,
            title: "Frets",
            accessibilityLabel: "Select the frets used when generating position prompt questions",
            options: id.supportedFrets.map { fret in
                let isSelected = configuration.contains(fret)
                return SettingsPositionFilterItem(
                    id: .fret(fret),
                    title: "\(fret)",
                    accessibilityLabel: "Toggle fret \(fret) for position prompt questions",
                    isSelected: isSelected,
                    isEnabled: !isSelected || configuration.canDeselect(fret)
                )
            }
        )
    }
}
```

## 验证情况

- 已对 `SettingsPanelModel.swift` 与 `SettingsPanelSnapshotBuilder.swift` 运行 `ReadLints`
- 结果：无 linter 报错
- 本次未运行 `xcodebuild` / 应用启动验证，因此这份记录只确认静态改动与 IDE lint 状态

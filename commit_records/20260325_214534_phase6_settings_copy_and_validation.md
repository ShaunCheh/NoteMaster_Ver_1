# 20260325_214534_phase6_settings_copy_and_validation

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260325_214534`
- 记录范围：竖向指板横滚方案的阶段6实施
- 本次目标：在不改 settings 结构与状态语义的前提下，补齐 `Height` 滑块文案，让它准确表达“这是竖向指板的可见视口高度；增大后可能带来局部横向滚动”
- 根因结论：阶段1到阶段5已经把“竖向模式下内容吃满高度、宽度由局部横向滚动消化”的布局语义落地了，但统一设置面板仍把 `verticalHostHeightRatio` 展示成笼统的 `Height`，无障碍文案也没有提示“增大高度可能触发横向滚动”，容易让人误以为它是在直接调节指板内容本体高度
- 本次实际改动：
  - 修改 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`

## 本次完成的修改

1. 将 `SettingsSliderID.verticalHostHeightRatio` 的标题从 `Height` 改为 `Viewport Height`。
2. 将对应无障碍文案从“调整竖向指板高度”改为“调整竖向指板视口高度，增大后可能需要横向滚动”。
3. 保持 `SettingsPanelSnapshotBuilder`、`FretboardControlPanelModel` 和平台设置面板结构不变，因为它们本来就复用 `SettingsSliderID` 的标题与可访问性文案；这次只改共享文案真相源即可同时影响统一 settings 和旧控制面板。

## 修改 1：标题从 `Height` 改为 `Viewport Height`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSliderID.title
// 功能说明: 修改前竖向指板高度滑块的标题过于笼统，只表达“Height”，
// 没有区分“指板内容高度”和“页面里分配给指板的可见视口高度”。
var title: String {
    switch self {
    case .clefScale:
        return "Scale"
    case .clefVerticalTrim:
        return "Vertical Clip"
    case .clefAnchorYOffset:
        return "Anchor Y Offset"
    case .verticalHostHeightRatio:
        return "Height"
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSliderID.title
// 功能说明: 修改后标题明确表达这是“竖向指板视口高度”而不是直接修改指板内容本体，
// 与当前“宿主高度 + 局部横向滚动”的真实语义保持一致。
var title: String {
    switch self {
    case .clefScale:
        return "Scale"
    case .clefVerticalTrim:
        return "Vertical Clip"
    case .clefAnchorYOffset:
        return "Anchor Y Offset"
    case .verticalHostHeightRatio:
        return "Viewport Height"
    }
}
```

## 修改 2：无障碍文案补充“可能触发横向滚动”的语义

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSliderID.accessibilityLabel
// 功能说明: 修改前无障碍文案只说“Adjust vertical fretboard height”，
// 无法反映阶段1到阶段5已经建立的“增大视口高度后，额外宽度由局部横向滚动承接”的行为。
var accessibilityLabel: String {
    switch self {
    case .clefScale:
        return "Adjust clef scale"
    case .clefVerticalTrim:
        return "Adjust clef vertical clip"
    case .clefAnchorYOffset:
        return "Adjust clef anchor vertical offset"
    case .verticalHostHeightRatio:
        return "Adjust vertical fretboard height"
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/成员: SettingsSliderID.accessibilityLabel
// 功能说明: 修改后无障碍文案把“这是视口高度”和“增大后可能出现横向滚动”一起说清楚，
// 避免用户继续按“直接拉伸指板内容高度”的旧心智来理解这个滑块。
var accessibilityLabel: String {
    switch self {
    case .clefScale:
        return "Adjust clef scale"
    case .clefVerticalTrim:
        return "Adjust clef vertical clip"
    case .clefAnchorYOffset:
        return "Adjust clef anchor vertical offset"
    case .verticalHostHeightRatio:
        return "Adjust vertical fretboard viewport height. Increasing height may require horizontal scrolling."
    }
}
```

## 无需额外修改的复用链路

### 旧指板控制面板本来就复用同一份文案

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/FretboardControlPanelModel.swift
// 函数/成员: FretboardSliderControlItem.ID.title / accessibilityLabel
// 功能说明: 旧指板控制面板并没有自维护一份单独的标题或无障碍文案，
// 而是直接委托给 SettingsSliderID；因此阶段6不需要再改这个文件。
var title: String {
    settingsSliderID.title
}

var accessibilityLabel: String {
    settingsSliderID.accessibilityLabel
}
```

### 统一设置面板快照构建器也直接透传这份文案

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数/成员: SettingsPanelSnapshotBuilder.makeSliderRow(id:fretboardDisplayState:staffDisplayState:)
// 功能说明: 统一 settings 面板的 slider row 也是从 SettingsSliderID 直接读取 title / accessibilityLabel，
// 所以共享文案真相源一旦修正，UI 层无需再做额外补丁。
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
```

## 修改结果说明

- 本轮没有更改 `verticalHostHeightRatio` 的状态、取值范围、事件分发或快照结构，只是把共享文案真相源收口到了正确语义。
- 由于旧控制面板和统一设置面板都复用 `SettingsSliderID` 文案，这次只改一处就能同时覆盖两条 UI 链路，符合阶段6“轻改文案、不动结构”的计划。

## 验证结果

1. `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`，无新增问题。
2. `swiftc -typecheck NoteMaster_Ver_1/Shared/Controls/*.swift NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift`：通过。
3. 命令行执行 `FretboardValidationRunner.run(platform: .commandLine)`：`PASS`。
4. 自动化夹具通过数量：`7 / 7`。
5. 通过夹具：
   - `horizontal-guitar6-reference`
   - `horizontal-bass4-reference`
   - `horizontal-bass5-reference`
   - `vertical-guitar6-height-driven`
   - `vertical-bass4-height-driven`
   - `vertical-bass5-height-driven`
   - `vertical-guitar6-width-constrained`
6. 尚未实际执行 App 运行态手工联调：
   - `iOS` 旋转
   - `macOS` live resize
   - 页面纵向滚动与指板局部横向滚动的真实交互

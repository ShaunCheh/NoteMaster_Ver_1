# 20260911_115020_settings_exercise_vertical_option_layout

- 时间戳来源：系统命令 `date '+%Y%m%d_%H%M%S'`
- 时间戳结果：`20260911_115020`
- 记录范围：将 `Settings > Exercise` 下的具体选择项改为纵向排列
- 记录依据：创建本记录前的 `git diff`、当前 Changes、双平台构建结果
- 本记录不粘贴原始 `git diff`，而是按实际代码归纳修改前后的结构与行为
- 本轮记录步骤只新增本 Markdown 文件，没有继续修改源代码

```bash
# 执行目录: /Users/shaun/cloudDev/NoteMaster_Ver_1
# 命令说明: 使用系统自带 date 命令生成本记录的文件名前缀和标题时间戳。
date '+%Y%m%d_%H%M%S'
# 输出: 20260911_115020
```

## 1. 实际修改文件

- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`

当前 Changes 中还存在 `.gitignore` 修改，其内容是加入 `UserInterfaceState.xcuserstate` 忽略规则；该修改不是本次 Exercise 纵向排列工作产生的，因此不纳入下面的修改前后说明。

## 2. 修改前的实际情况

1. `Settings > Exercise` 的 `Mode / Composition / Layout` 二级入口原本就由 Settings 导航索引页纵向排列，本次没有修改这一级导航。
2. 进入具体页面后：
   - `Exercise Mode` 使用横向 `segmented` 控件。
   - `Composition Preset` 和 `Layout Preset` 使用横向 chips。
   - `Note Names` 使用横向等宽按钮。
3. shared settings 模型只能表达 `chips` 或 `segmented`，不能表达 chips 的排列轴。
4. iOS 和 macOS 渲染器都把 chips 与 position-filter 选项容器硬编码为横向。

根因不是选项数据顺序错误，而是 shared model 缺少“横向 / 纵向”布局契约，导致平台渲染层只能默认使用横向排列。

## 3. Shared Model：新增选项排列轴契约

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号: SettingsPresentationStyle, SettingsChoiceRowID.presentationStyle
// 功能说明: 修改前 presentationStyle 只能区分 chips 与 segmented，
// 无法告诉 iOS/macOS chips 应横向还是纵向排列。
enum SettingsPresentationStyle: Equatable, Sendable {
    case chips
    case segmented
}

var presentationStyle: SettingsPresentationStyle {
    switch self {
    case .rootMode,
         .exerciseMode,
         .positionPromptFilterMode,
         .stringThickness,
         .clef,
         .pianoMovementScope,
         .pianoWhiteKeyStyle:
        return .segmented
    case .compositionPreset,
         .layoutPreset,
         .accessoryPresentation,
         .instrument,
         .displayMode,
         .labels,
         .spelling,
         .octave:
        return .chips
    }
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号: SettingsOptionsAxis, SettingsPresentationStyle, SettingsChoiceRowID.presentationStyle
// 功能说明: shared model 现在明确携带 chips 的排列轴；
// Exercise 的三个 choice row 使用纵向 chips，其他页面原有 chips 继续保持横向。
enum SettingsOptionsAxis: Equatable, Sendable {
    case horizontal
    case vertical
}

enum SettingsPresentationStyle: Equatable, Sendable {
    case chips(axis: SettingsOptionsAxis)
    case segmented
}

var presentationStyle: SettingsPresentationStyle {
    switch self {
    case .rootMode,
         .positionPromptFilterMode,
         .stringThickness,
         .clef,
         .pianoMovementScope,
         .pianoWhiteKeyStyle:
        return .segmented
    case .exerciseMode,
         .compositionPreset,
         .layoutPreset:
        return .chips(axis: .vertical)
    case .accessoryPresentation,
         .instrument,
         .displayMode,
         .labels,
         .spelling,
         .octave:
        return .chips(axis: .horizontal)
    }
}
```

实际行为变化：

- `Exercise Mode` 从横向 segmented 改为纵向 chips。
- `Composition Preset` 从横向 chips 改为纵向 chips。
- `Layout Preset` 从横向 chips 改为纵向 chips。
- 其他 Settings choice row 的呈现方式保持原样。
- 选项的数据顺序、选中逻辑、启用逻辑和 action ID 均未改变。

## 4. Position Filter：为 Note Names 增加纵向布局信息

### 4.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号: SettingsPositionFilterRowID, SettingsPositionFilterRow
// 功能说明: 修改前 position-filter row 只有选项数据，没有排列轴；
// 平台层只能将 C/D/E/F/G/A/B 固定画成一条横向按钮栏。
enum SettingsPositionFilterRowID: CaseIterable, Equatable, Hashable, Sendable {
    case positionQuestionPitchClasses
    case positionPromptFilterOptions

    // ... sectionID、supportedFrets、supportedPitchClasses 保持原有实现 ...
}

struct SettingsPositionFilterRow: Equatable, Sendable {
    var id: SettingsPositionFilterRowID
    var title: String
    var accessibilityLabel: String
    var options: [SettingsPositionFilterItem]
}
```

### 4.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数/符号: SettingsPositionFilterRowID.optionsAxis, SettingsPositionFilterRow
// 功能说明: Exercise 内的出题音名池明确使用纵向布局；
// 独立 position-prompt filter 的原有布局契约继续保持横向。
enum SettingsPositionFilterRowID: CaseIterable, Equatable, Hashable, Sendable {
    case positionQuestionPitchClasses
    case positionPromptFilterOptions

    var optionsAxis: SettingsOptionsAxis {
        switch self {
        case .positionQuestionPitchClasses:
            return .vertical
        case .positionPromptFilterOptions:
            return .horizontal
        }
    }
}

struct SettingsPositionFilterRow: Equatable, Sendable {
    var id: SettingsPositionFilterRowID
    var title: String
    var accessibilityLabel: String
    var optionsAxis: SettingsOptionsAxis
    var options: [SettingsPositionFilterItem]
}
```

`positionQuestionPitchClasses` 对应 `Settings > Exercise > Mode` 中的 `Note Names`，其按钮仍按 `C → D → E → F → G → A → B` 排序，只是排列方向从横向变成纵向。

## 5. Snapshot Builder：把 shared 布局契约写入快照

### 5.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: SettingsPanelSnapshotBuilder.makePositionFilterRow(id:stateContext:)
// 功能说明: 修改前快照只携带标题、无障碍文本和 options，
// 没有向平台渲染器传递排列轴。
return SettingsPositionFilterRow(
    id: id,
    title: "Note Names",
    accessibilityLabel: "Select the note names used when generating position questions",
    options: id.supportedPitchClasses.map { pitchClass in
        // ... 根据配置生成选项及选中状态 ...
    }
)
```

### 5.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: SettingsPanelSnapshotBuilder.makePositionFilterRow(id:stateContext:)
// 功能说明: 快照现在从 row ID 取得 optionsAxis，
// 使 iOS 与 macOS 消费同一份 shared 排列结果。
return SettingsPositionFilterRow(
    id: id,
    title: "Note Names",
    accessibilityLabel: "Select the note names used when generating position questions",
    optionsAxis: id.optionsAxis,
    options: id.supportedPitchClasses.map { pitchClass in
        // ... 根据配置生成选项及选中状态 ...
    }
)
```

`optionsAxis: id.optionsAxis` 同时加入了该函数内创建 `SettingsPositionFilterRow` 的三个分支，避免同一模型存在漏传布局属性的路径。

## 6. iOS：按 shared axis 切换 UIStackView

### 6.1 Choice row 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名: ChoiceRowView.apply(item:), ChoiceRowView.applyChipButtons(item:)
// 功能说明: 修改前 chips 不携带 axis，chipsStackView 在 configureView() 中固定为 horizontal；
// Exercise Mode 则走横向 UISegmentedControl。
switch item.presentationStyle {
case .chips:
    applyChipButtons(item: item)
    chipsStackView.isHidden = false
    segmentedControl.isHidden = true
case .segmented:
    applySegmentedControl(item: item)
    chipsStackView.isHidden = true
    segmentedControl.isHidden = false
}

private func applyChipButtons(item: SettingsChoiceRow) {
    removeObsoleteButtons(notIn: Set(item.choices.map(\.id)))
    // ... 按 item.choices 原有顺序复用并装入按钮 ...
}
```

### 6.2 Choice row 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名: ChoiceRowView.apply(item:), ChoiceRowView.applyChipButtons(item:axis:)
// 功能说明: iOS renderer 不再判断具体 Exercise row ID，
// 而是直接执行 shared model 给出的 axis；纵向 stack 中按钮按容器宽度填充。
switch item.presentationStyle {
case let .chips(axis):
    applyChipButtons(
        item: item,
        axis: axis
    )
    chipsStackView.isHidden = false
    segmentedControl.isHidden = true
case .segmented:
    applySegmentedControl(item: item)
    chipsStackView.isHidden = true
    segmentedControl.isHidden = false
}

private func applyChipButtons(
    item: SettingsChoiceRow,
    axis: SettingsOptionsAxis
) {
    chipsStackView.axis = axis == .vertical ? .vertical : .horizontal
    removeObsoleteButtons(notIn: Set(item.choices.map(\.id)))
    // ... 按 item.choices 原有顺序复用并装入按钮 ...
}
```

### 6.3 Note Names 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名: PositionFilterRowView.configureView(), PositionFilterRowView.apply(item:)
// 功能说明: 修改前 optionsStackView 固定为横向，并让全部音名按钮等宽。
optionsStackView.axis = .horizontal
optionsStackView.alignment = .fill
optionsStackView.distribution = .fillEqually
optionsStackView.spacing = Style.positionFilterSpacing

func apply(item: SettingsPositionFilterRow) {
    // ... 更新标题与按钮缓存 ...
    let orderedButtons = item.options.map { option -> UIView in
        optionButton(for: option)
    }
    // ... 更新 arrangedSubviews ...
}
```

### 6.4 Note Names 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSSettingsPanelView.swift
// 函数名: PositionFilterRowView.apply(item:)
// 功能说明: apply 时根据快照切换 axis 与 distribution；
// Exercise Note Names 纵向填充，仍保留横向场景的 fillEqually 行为。
func apply(item: SettingsPositionFilterRow) {
    // ... 更新标题与按钮缓存 ...
    optionsStackView.axis = item.optionsAxis == .vertical
        ? .vertical
        : .horizontal
    optionsStackView.distribution = item.optionsAxis == .vertical
        ? .fill
        : .fillEqually

    let orderedButtons = item.options.map { option -> UIView in
        optionButton(for: option)
    }
    // ... 更新 arrangedSubviews ...
}
```

## 7. macOS：按 shared axis 切换 NSStackView，并保证纵向按钮填满宽度

### 7.1 Choice row 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名: ChoiceRowView.apply(item:), ChoiceRowView.applyChipButtons(item:)
// 功能说明: 修改前 chipsStackView 固定为 horizontal/centerY，
// shared model 没有 axis 可供 macOS renderer 使用。
switch item.presentationStyle {
case .chips:
    applyChipButtons(item: item)
    chipsStackView.isHidden = false
    segmentedControl.isHidden = true
case .segmented:
    applySegmentedControl(item: item)
    chipsStackView.isHidden = true
    segmentedControl.isHidden = false
}

private func applyChipButtons(item: SettingsChoiceRow) {
    removeObsoleteButtons(notIn: Set(item.choices.map(\.id)))
    // ... 按原有顺序更新按钮 ...
}
```

### 7.2 Choice row 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名: ChoiceRowView.apply(item:), ChoiceRowView.applyChipButtons(item:axis:)
// 功能说明: macOS renderer 根据 shared axis 同步切换外层对齐、stack orientation 和交叉轴对齐；
// .width 让纵向选项使用可用内容宽度，横向场景仍保持 leading/centerY。
switch item.presentationStyle {
case let .chips(axis):
    applyChipButtons(
        item: item,
        axis: axis
    )
    chipsStackView.isHidden = false
    segmentedControl.isHidden = true
case .segmented:
    contentStackView.alignment = .leading
    applySegmentedControl(item: item)
    chipsStackView.isHidden = true
    segmentedControl.isHidden = false
}

private func applyChipButtons(
    item: SettingsChoiceRow,
    axis: SettingsOptionsAxis
) {
    contentStackView.alignment = axis == .vertical ? .width : .leading
    chipsStackView.orientation = axis == .vertical ? .vertical : .horizontal
    chipsStackView.alignment = axis == .vertical ? .width : .centerY
    removeObsoleteButtons(notIn: Set(item.choices.map(\.id)))
    // ... 按原有顺序更新按钮 ...
}
```

### 7.3 Note Names 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名: PositionFilterRowView.configureView(), PositionFilterRowView.apply(item:)
// 功能说明: 修改前 position-filter 容器固定使用横向、居中和等宽分布。
optionsStackView.orientation = .horizontal
optionsStackView.alignment = .centerY
optionsStackView.distribution = .fillEqually
optionsStackView.spacing = Style.positionFilterSpacing

func apply(item: SettingsPositionFilterRow) {
    // ... 更新标题与按钮缓存 ...
    let orderedButtons = item.options.map { option -> NSView in
        optionButton(for: option)
    }
    // ... 更新 arrangedSubviews ...
}
```

### 7.4 Note Names 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSSettingsPanelView.swift
// 函数名: PositionFilterRowView.apply(item:)
// 功能说明: macOS position-filter 根据 optionsAxis 同时调整外层宽度对齐、
// orientation、交叉轴对齐和 distribution，保证纵向音名按钮逐行填充。
func apply(item: SettingsPositionFilterRow) {
    // ... 更新标题与按钮缓存 ...
    contentStackView.alignment = item.optionsAxis == .vertical
        ? .width
        : .leading
    optionsStackView.orientation = item.optionsAxis == .vertical
        ? .vertical
        : .horizontal
    optionsStackView.alignment = item.optionsAxis == .vertical
        ? .width
        : .centerY
    optionsStackView.distribution = item.optionsAxis == .vertical
        ? .fill
        : .fillEqually

    let orderedButtons = item.options.map { option -> NSView in
        optionButton(for: option)
    }
    // ... 更新 arrangedSubviews ...
}
```

## 8. Validation：锁定 Exercise 纵向布局契约

### 8.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名: SettingsNavigationValidationRunner.validateSplitSectionsProduceExpectedPageTree()
// 功能说明: 修改前夹具会验证 section 和 route 树，但不会验证 Exercise 内部选项的排列轴。
if resolveSection(.layout, in: panelModel) != nil {
    issues.append(issue(fixtureName, "default state 不应再保留 Layout section。"))
}

if debugSection.rows.map(\.id) != [
    .toggle(.showsComponentBounds),
    .toggle(.showsSideBySideContainerOutlines)
] {
    // ... 原有 Debug section 顺序校验 ...
}
```

### 8.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名: SettingsNavigationValidationRunner.validateSplitSectionsProduceExpectedPageTree()
// 功能说明: 启动期 shared validation 现在会锁定三个 Exercise choice row
// 以及 Note Names 的纵向契约，防止后续改动静默退回横向。
for rowID in [
    SettingsChoiceRowID.exerciseMode,
    .compositionPreset,
    .layoutPreset
] {
    guard let row = panelModel.choiceRow(for: rowID) else {
        issues.append(
            issue(
                fixtureName,
                "Exercise section 缺少 \(String(describing: rowID)) choice row。"
            )
        )
        continue
    }

    if row.presentationStyle != .chips(axis: .vertical) {
        issues.append(
            issue(
                fixtureName,
                "Exercise section 的 \(String(describing: rowID)) 选项应使用纵向列表。"
            )
        )
    }
}

if panelModel.positionFilterRow(
    for: .positionQuestionPitchClasses
)?.optionsAxis != .vertical {
    issues.append(
        issue(
            fixtureName,
            "Exercise section 的 Note Names 选项应使用纵向列表。"
        )
    )
}
```

## 9. 修改后的最终表现

- `Settings > Exercise` 的二级入口仍按原顺序纵向显示：
  - `Mode`
  - `Composition`
  - `Layout`
- `Mode` 页内的模式选项改为纵向，顺序不变：
  - `Single`
  - `Sequence`
  - `P-2`
  - `SR-0`
  - `SR-1`
  - `SR-2`
  - `FR-0`
  - `Position`
- `Composition` 页内选项改为纵向，顺序不变：
  - `Staff`
  - `Target`
  - `Strip`
  - `Self`
- `Layout` 页内选项改为纵向，顺序不变：
  - `Stacked`
  - `Side`
  - `Single`
- `Position / FR-0` 相关的 `Note Names` 改为纵向，顺序不变：
  - `C`
  - `D`
  - `E`
  - `F`
  - `G`
  - `A`
  - `B`

固定展示模式下隐藏 `Composition / Layout` 的既有导航规则没有变化；本次只改变可见选项的排列方式。

## 10. 明确未修改的边界

- 未修改任何 Exercise 模式枚举或选项顺序。
- 未修改选项的选中态、启用态、点击事件或状态写回逻辑。
- 未修改 Exercise scene、composition policy 或 layout policy。
- 未修改 Settings 根页面和 Exercise 二级导航的排列。
- 未修改 Accessories、Fretboard、Staff、Piano、Debug 等其他页面的既有布局。
- 未提交 Git commit。

## 11. 验证结果

### 11.1 静态检查

- 对本次修改的 5 个 Swift 文件执行 IDE linter 检查。
- 结果：无 linter 错误。
- `git diff --check` 通过。

### 11.2 macOS Debug 构建

```bash
# 执行目录: /Users/shaun/cloudDev/NoteMaster_Ver_1
# 命令说明: 使用独立 DerivedData 构建 macOS arm64 Debug 目标，验证 shared model 与 macOS renderer。
xcodebuild \
  -project NoteMaster_Ver_1.xcodeproj \
  -scheme NoteMaster_Ver_1 \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/NoteMaster_Ver_1-mac-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- 结果：`** BUILD SUCCEEDED **`
- 非阻断提示：App Intents metadata extraction 因项目未依赖 `AppIntents.framework` 而跳过。

### 11.3 iOS Simulator Debug 构建

```bash
# 执行目录: /Users/shaun/cloudDev/NoteMaster_Ver_1
# 命令说明: 使用独立 DerivedData 构建通用 iOS Simulator Debug 目标，验证 shared model 与 iOS renderer。
xcodebuild \
  -project NoteMaster_Ver_1.xcodeproj \
  -scheme NoteMaster_Ver_1 \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/NoteMaster_Ver_1-ios-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- 结果：`** BUILD SUCCEEDED **`
- 非阻断提示：构建过程提示使用 ad-hoc signing 并关闭 hardened runtime。

## 12. 结论

本次修改通过 shared settings model 显式增加排列轴，而不是在 iOS/macOS 中按具体 row ID 写特殊分支。`Exercise Mode / Composition Preset / Layout Preset / Note Names` 因此由同一份 shared 契约驱动为纵向排列，双平台行为保持一致，其他 Settings 页面保持原状。

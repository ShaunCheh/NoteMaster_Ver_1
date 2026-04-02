# 20260403_004936_side_rail_button_extent_50

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_004936`
- 记录范围：只记录方案 B 完成后，对 side 模式右侧 `naturalNoteStrip` rail 按钮边长的 follow-up 调整，即把共享按钮边长 token 从 `20` 提升到 `50`
- 本记录不放原始 `git diff`，只按真实改动记录“修改前 / 修改后”
- 本记录中的“修改前”，指 `20260403_004028_stage5_runtime_smoke_regression.md` 记录完成后的代码状态
- 本轮实际改动文件：
- `NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- 本轮未改动但继续复用的文件：
- `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`

## 1. 本轮目标

- 用户明确要求把 side 模式右侧 rail 按钮的边长从 `20` 改成 `50`。
- 这次不能在平台层单独写死 `50`，因为当前架构里 rail 按钮尺寸的根因控制点已经被收口到 shared `ExerciseNaturalNoteStripRailContract.buttonExtent`。
- 所以本轮真正要改的是 shared token，而不是再在 AppKit / UIKit 里各打一层局部补丁。

## 2. 修改一：把 shared rail contract 的默认按钮边长从 `20` 提升到 `50`

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailContract.defaultButtonExtent,
//           ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
// 修改前说明: side 模式右侧 natural note strip rail 的共享默认按钮边长固定为 20。
// 只要 scene 命中 sideBySide + right rail contract，这个值就会继续流向双端视图。
struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 20
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        verticalAlignment: .centered
    )

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExercisePresentationState.swift
// 函数/符号: ExerciseNaturalNoteStripRailContract.defaultButtonExtent,
//           ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
// 修改后说明: shared rail contract 的默认按钮边长统一提升为 50。
// 这样命中 right rail contract 的双端视图都会自动拿到 50x50，而不需要平台分叉修改。
struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 50
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        verticalAlignment: .centered
    )

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment
}
```

### 2.3 这一改动解决了什么

- side 模式右侧 rail 的按钮边长根因上已经从 `20` 变成 `50`。
- 因为 `buttonExtent` 同时参与“按钮 intrinsic size”和“rail 总内容高度计算”，所以这次不仅按钮会变大，整条竖排 strip 的内容高度也会自动变大。
- 这仍然保持了方案 B 的架构前提：尺寸来源在 shared contract，而不是平台层魔法数。

## 3. 修改二：同步 shared validation 文案，避免断言描述与真实 token 分叉

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// 修改前说明: 自动化断言已经把 buttonExtent 与 shared 默认值绑定在一起，
// 但报错文案仍写死“square + 20”，会和本轮真实默认值产生分叉。
if railContract.buttonShape != .square
    || railContract.buttonExtent
    != ExerciseNaturalNoteStripRailContract.defaultButtonExtent {
    issues.append(
        issue(
            fixtureName,
            "阶段 1 的 rail contract 应继续给出 square + 20 的默认按钮几何语义。"
        )
    )
}
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数: validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
// 修改后说明: 校验逻辑继续绑定 shared 默认值，
// 同时把报错文案同步改成 square + 50，保证断言语义与真实代码一致。
if railContract.buttonShape != .square
    || railContract.buttonExtent
    != ExerciseNaturalNoteStripRailContract.defaultButtonExtent {
    issues.append(
        issue(
            fixtureName,
            "阶段 1 的 rail contract 应继续给出 square + 50 的默认按钮几何语义。"
        )
    )
}
```

### 3.3 这一改动解决了什么

- 自动化 validation 继续站在 shared token 上做断言，不会因为文案还写着 `20` 而误导后续排查。
- 这也避免了未来看到 validation 失败时，日志描述和真实运行值不一致的问题。

## 4. 本轮未改动但为什么会立即生效

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/符号: activeRailButtonExtent, verticalRailIntrinsicHeight,
//           NaturalNoteButton.intrinsicContentSize
// 说明: macOS rail 视图本来就在直接消费 shared contract 的 buttonExtent。
// 所以 shared token 改成 50 后，按钮尺寸和 rail 总高度都会自动跟着变。
private var activeRailButtonExtent: CGFloat {
    CGFloat(activeRailContract.buttonExtent)
}

private var verticalRailIntrinsicHeight: CGFloat {
    switch activeRailContract.mainAxisPolicy {
    case .contentSized:
        let slotCount = CGFloat(activeRailContract.slotModel.slotCount)
        let totalSpacing = max(0, slotCount - 1) * Style.itemSpacing
        return Style.contentInsets.top
            + (slotCount * activeRailButtonExtent)
            + totalSpacing
            + Style.contentInsets.bottom
    }
}

override var intrinsicContentSize: NSSize {
    switch layoutMode {
    case .verticalRail:
        let buttonExtent = CGFloat(railContract.buttonExtent)
        return NSSize(width: buttonExtent, height: buttonExtent)
    case .horizontalStrip:
        return super.intrinsicContentSize
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/符号: activeRailButtonExtent, verticalRailIntrinsicHeight,
//           NaturalNoteButton.intrinsicContentSize
// 说明: iOS 路径与 macOS 对齐，同样直接消费 shared contract 的 buttonExtent。
private var activeRailButtonExtent: CGFloat {
    CGFloat(activeRailContract.buttonExtent)
}

private var verticalRailIntrinsicHeight: CGFloat {
    switch activeRailContract.mainAxisPolicy {
    case .contentSized:
        let slotCount = CGFloat(activeRailContract.slotModel.slotCount)
        let totalSpacing = max(0, slotCount - 1) * Style.itemSpacing
        return directionalLayoutMargins.top
            + (slotCount * activeRailButtonExtent)
            + totalSpacing
            + directionalLayoutMargins.bottom
    }
}

override var intrinsicContentSize: CGSize {
    switch layoutMode {
    case .verticalRail:
        let buttonExtent = CGFloat(railContract.buttonExtent)
        return CGSize(width: buttonExtent, height: buttonExtent)
    case .horizontalStrip:
        return super.intrinsicContentSize
    }
}
```

### 4.1 这一节说明了什么

- 本轮虽然只改了 shared 层 2 个文件，但不是“局部碰巧生效”，而是因为双端消费链本来就已经被方案 B 收口到 `buttonExtent`。
- 这就是这次修改为什么属于根因点，而不是平台层 patch。

## 5. 本轮没有改什么

- 没有修改 `slotModel`，仍然保留 12 个 `PitchClass` 槽位。
- 没有修改 renderer 的垂直居中嵌入逻辑。
- 没有修改 `fretboardLayoutContract`、settings/navigation gate 或默认 layout。
- 没有新增任何 settings 配置项，也没有把 rail button size 暴露给用户设置页。

## 6. 最终状态总结

- side 模式右侧 `naturalNoteStrip` rail 的共享按钮边长现在是 `50`。
- 因为双端按钮 intrinsic size 都直接取 `railContract.buttonExtent`，所以现在实际按钮尺寸是 `50x50`。
- 因为 rail 的总高度也是按 `slotCount * buttonExtent + spacing + insets` 计算，所以整条 strip 在 side 模式下也会同步变高。
- 这一轮仍然保持当前架构的约束：
- 尺寸来源在 shared contract
- 双端视图只负责消费 contract
- renderer 只负责居中与嵌入，不自己决定按钮边长

## 7. 验证结果

- `ReadLints` 检查相关文件：无 linter 错误
- 构建验证命令（macOS）：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- 构建验证命令（iOS Simulator）：`xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO`
- 构建结果（macOS）：`BUILD SUCCEEDED`
- 构建结果（iOS Simulator）：`BUILD SUCCEEDED`
- 运行时 smoke 实跑结果：
- macOS：带 `NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression` 启动后，`PASS`，退出码 `0`
- iOS Simulator：通过 `SIMCTL_CHILD_NOTE_MASTER_RUNTIME_SMOKE_TEST=layout-preset-regression` 透传环境变量后，`PASS`，退出码 `0`
- 这说明把边长从 `20` 提升到 `50` 之后，没有把阶段 5 刚补上的 side / stacked 切换与尺寸变化回归再次打坏

## 8. 这轮变化带来的直接影响

- side 模式右侧 rail 的视觉占用会明显变大。
- 因为仍保留 12 个槽位，所以总内容高度增长会比较明显，这属于当前 contract 语义的直接结果，不是额外的布局回退。
- 如果后续用户继续调大或调小边长，仍然应该优先改 shared `defaultButtonExtent`，而不是去平台视图层单独写死数值。

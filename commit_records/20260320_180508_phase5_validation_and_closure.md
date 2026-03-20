20260320_180508_phase5_validation_and_closure

# 固定弦高阶段 5 修改记录

## 本次变更范围

- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 本阶段只完成验证与收口，没有新增或修改 Swift 源码

## 修改前

### 乐器切换已经只改 `tuning`，总高由配置层自动派生

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift, NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift
// 函数名：preferredHeight, apply(to:)
// 功能说明：阶段 5 开始前，乐器切换链路已经收口到“ButtonPanel 只改 tuning，preferredHeight 由 configuration 自动派生”，但还没有完成统一验证。
var preferredHeight: CGFloat {
    layoutMetrics.preferredHeight(forStringCount: stringCount)
}

func apply(to displayState: inout FretboardDisplayState) {
    switch self {
    case .setInstrumentGuitar6:
        displayState.configuration.tuning = .standard(for: .guitar6)
    case .setInstrumentBass4:
        displayState.configuration.tuning = .standard(for: .bass4)
    case .setInstrumentBass5:
        displayState.configuration.tuning = .standard(for: .bass5)
    case .setVisibilityAll:
        displayState.visibility = .all
    case .setVisibilityNaturalOnly:
        displayState.visibility = .naturalOnly
    case .setVisibilityAccidentalOnly:
        displayState.visibility = .accidentalOnly
    case .setVisibilityNone:
        displayState.visibility = .none
    case .setSpellingSharp:
        displayState.spelling = .sharp
    case .setSpellingFlat:
        displayState.spelling = .flat
    case .toggleShowsOctave:
        displayState.showsOctave.toggle()
    }
}
```

### 平台层已经只通过 `intrinsicContentSize` 暴露派生高度

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
// 函数名：intrinsicContentSize
// 功能说明：阶段 5 开始前，平台指板视图已经把 configuration.preferredHeight 作为固有高度暴露给 Auto Layout，但还没有完成统一验证。
override var intrinsicContentSize: NSSize {
    NSSize(
        width: NSView.noIntrinsicMetric,
        height: configuration.preferredHeight
    )
}
```

### 共享层已经具备 badge 与 raw 命中的最终语义

```swift
// 文件路径：NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift, NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift
// 函数名：resolvedBadgeDiameter(slotRect:geometry:), hitTest(_:phase:)
// 功能说明：阶段 5 开始前，共享层已经使用固定 lane 高度计算 badge，并通过 hitTest 返回 stringIndex/fret，但还没有完成 4/5/6 弦统一验证。
private func resolvedBadgeDiameter(
    slotRect: CGRect,
    geometry: FretboardGeometry
) -> CGFloat {
    let referenceHeight = geometry.stringLaneHeight > 0
        ? geometry.stringLaneHeight
        : slotRect.height * 0.24
    let heightDrivenDiameter = referenceHeight * layoutMetrics.badgeDiameterRatio
    let widthDrivenDiameter = slotRect.width * layoutMetrics.maxBadgeWidthRatio

    return max(min(heightDrivenDiameter, widthDrivenDiameter), 0)
}

func hitTest(
    _ point: CGPoint,
    phase: FretboardEventPhase
) -> FretboardHitResult {
    let isInsideDrawingRect = contains(point, inInclusiveBoundsOf: drawingRect)
    let nearestString = nearestStringMatch(forY: point.y)

    guard
        isInsideDrawingRect,
        let fret = displayPosition(forX: point.x),
        let nearestString
    else {
        return FretboardHitResult(
            phase: phase,
            locationInView: point,
            cell: nil,
            isInsideDrawingRect: isInsideDrawingRect,
            distanceToNearestString: nearestString?.distance
        )
    }

    return FretboardHitResult(
        phase: phase,
        locationInView: point,
        cell: FretboardCell(
            stringIndex: nearestString.stringIndex,
            fret: fret
        ),
        isInsideDrawingRect: true,
        distanceToNearestString: nearestString.distance
    )
}
```

## 修改后

### 源代码保持不变，阶段 5 完成全链路类型检查

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：阶段 5 对固定弦高链路涉及的共享层、共享状态、双平台视图和双平台控制器执行完整的 swiftc 类型检查。
xcrun swiftc -typecheck \
  "NoteMaster_Ver_1/Shared/Fretboard/FretboardContentProvider.swift" \
  "NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift" \
  "NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift" \
  "NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift" \
  "NoteMaster_Ver_1/Shared/Fretboard/FretboardLayer.swift" \
  "NoteMaster_Ver_1/Shared/Fretboard/InstrumentType.swift" \
  "NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift" \
  "NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift" \
  "NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift" \
  "NoteMaster_Ver_1/Shared/Controls/FretboardDisplayState.swift" \
  "NoteMaster_Ver_1/Shared/Controls/ButtonPanelModel.swift" \
  "NoteMaster_Ver_1/Shared/Controls/ButtonPanelSnapshotBuilder.swift" \
  "NoteMaster_Ver_1/Platform/iOS/Controls/iOSButtonPanelView.swift" \
  "NoteMaster_Ver_1/Platform/macOS/Controls/macOSButtonPanelView.swift" \
  "NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift" \
  "NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift" \
  "NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift" \
  "NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift"
```

```text
# 文件路径：无（类型检查与 IDE 诊断结果）
# 函数名：无
# 功能说明：阶段 5 的类型检查与 IDE lints 检查都已通过。
swiftc -typecheck: exit_code=0
No linter errors found.
```

### 搜索结果确认 `preferredHeight` 的消费点已经收口，旧约束残留已移除

```text
# 文件路径：无（搜索结果）
# 函数名：无
# 功能说明：阶段 5 使用搜索结果确认 preferredHeight 只剩配置层和双平台 intrinsicContentSize 在消费，旧的 fretboardHeightConstraint 已完全移除。
NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
  50:        func preferredHeight(forStringCount stringCount: Int) -> CGFloat {
  133:    var preferredHeight: CGFloat {
  134:        layoutMetrics.preferredHeight(forStringCount: stringCount)

NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift
  38:            height: configuration.preferredHeight

NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift
  34:            height: configuration.preferredHeight

fretboardHeightConstraint:
No matches found
```

### 共享层脚本验证覆盖了 4/5/6 弦总高、弦距、badge 和 raw 命中结果

```text
# 文件路径：无（共享脚本验证输出）
# 函数名：无
# 功能说明：阶段 5 的脚本依次切换 guitar6 / bass4 / bass5，验证 preferredHeight、laneHeight、stringSpacing、badgeDiameter，并对所有弦的 0/1/中间/最高品进行 hitTest 校验，同时确认指板外点击会 miss。
instrument=guitar6 strings=6 height=182.93 lane=17.00 spacing=17.00 badge=13.26
instrument=bass4 strings=4 height=121.95 lane=17.00 spacing=17.00 badge=13.26
instrument=bass5 strings=5 height=152.44 lane=17.00 spacing=17.00 badge=13.26
validation=ok
```

### macOS 平台视图的固有高度会随乐器切换自动变化

```text
# 文件路径：无（macOS 平台视图验证输出）
# 函数名：无
# 功能说明：阶段 5 直接实例化 macOSFretboardView 并切换 configuration.tuning，确认 intrinsicContentSize.height 会自动跟随 configuration.preferredHeight 变化。
macOSView heights guitar=182.93 bass4=121.95 bass5=152.44
validation=ok
```

### 阶段 5 的验证结论

```text
# 文件路径：无（验证结论）
# 函数名：无
# 功能说明：阶段 5 收口后的结论是：固定弦高链路已经在共享配置、共享几何、badge 渲染、raw hitTest、平台 intrinsic size 以及控制器状态传播上全部闭环。
1. guitar6 / bass4 / bass5 的总高度会随弦数变化，且三者值互不相同。
2. 4 弦、5 弦、6 弦场景下的 laneHeight 与 stringSpacing 都稳定为 17.00。
3. badge 直径在 4/5/6 弦场景下都保持 13.26，没有因弦数变化而继续缩小。
4. raw hitTest 在绘制区域内会返回正确的 stringIndex / fret，在绘制区域外会正确 miss。
5. macOSFretboardView 的 intrinsicContentSize.height 会随 configuration.tuning 自动变化。
6. 当前阶段没有新增 Swift 源码修改；iOS/macOS 真机或模拟器中的人工 UI 点击验证仍未执行，本阶段收口基于静态检查与脚本验证完成。
```

## 结果说明

- 阶段 5 没有修改任何 Swift 源码；核心工作是完成验证与收口。
- 固定弦高方案目前已经完成从配置层、几何层、渲染层到平台消费层的闭环验证。
- `preferredHeight` 的消费点已经收口为配置层与双平台 `FretboardView` 的 `intrinsicContentSize`，旧的控制器显式高度约束已不存在。
- 当前唯一未覆盖的是实际运行中的人工交互体验验证；这不影响本阶段关于“高度派生与几何命中语义”的收口结论。

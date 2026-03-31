# 20260331_172229_fretboard_string_thickness_settings

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_172229`
- 记录范围：为设置面板新增“低音弦更粗、高音弦更细”的可选项，并把弦宽渲染从“统一固定粗细”升级为“支持统一/渐变两种模式”
- 修改性质：不是单纯加一个 UI 文案，而是把“弦粗细模式”下沉为共享配置真相来源，再由设置面板驱动共享状态，最终由渲染层按弦序解析每根弦的线宽
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardBoardLayer.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`

## 修改前

- 指板配置层只有一个统一的 `stringLineWidth`，没有“弦粗细模式”这个业务概念。
- 渲染层在 `drawStrings(in:)` 里只设置一次 `lineWidth`，后续所有弦共用这一条宽度。
- 设置面板 `Fretboard` 分组没有控制弦粗细的选项，用户无法在 UI 中切换“低音弦更粗”。
- 共享层验证里也没有专门检查这个选项是否存在、默认值是否正确、状态切换后是否回写。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名: FretboardConfiguration.LayoutMetrics.default
// 功能说明: 修改前配置层只有统一的 stringLineWidth；
// 没有 stringThicknessStyle，也没有低音弦/高音弦的比例参数。
struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        var cellWidthToHeightRatio: CGFloat
        var stringLaneHeight: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            cellWidthToHeightRatio: 1.6,
            stringLaneHeight: 17,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardBoardLayer.swift
// 函数名: drawStrings(in:)
// 功能说明: 修改前在进入循环前只设置一次 lineWidth；
// 因此每根弦都按同一粗细绘制，不区分低音弦和高音弦。
private func drawStrings(in context: CGContext) {
    guard !scene.stringSegments.isEmpty else {
        return
    }

    context.saveGState()
    context.setStrokeColor(FretboardPalette.string)
    context.setLineCap(.round)
    context.setLineWidth(max(configuration.layoutMetrics.stringLineWidth, 1))

    for stringSegment in scene.stringSegments {
        context.move(to: stringSegment.start)
        context.addLine(to: stringSegment.end)
    }

    context.strokePath()
    context.restoreGState()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.rowIDs / SettingsChoiceRowID / SettingsActionID
// 功能说明: 修改前 Fretboard 分组没有 stringThickness 这一行；
// action 层也不存在 Uniform / Graduated 两个动作，设置面板无法驱动弦粗细模式。
case .fretboard:
    return [
        .choice(.instrument),
        .choice(.displayMode),
        .choice(.labels),
        .choice(.spelling),
        .choice(.octave)
    ]

enum SettingsChoiceRowID: CaseIterable, Equatable, Hashable, Sendable {
    case topContent
    case mainContent
    case exerciseMode
    case positionPromptFilterMode
    case instrument
    case displayMode
    case labels
    case spelling
    case octave
    case clef
    case pianoMovementScope
    case pianoWhiteKeyStyle
}

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setTopContentStaff
    case setTopContentTargetPrompt
    case setTopContentFretboard
    case setMainContentFretboard
    case setMainContentNaturalNotes
    case setExerciseModeSingle
    case setExerciseModeSequence
    case setExerciseModePositionPrompt
    case setPositionPromptFilterModeNoteName
    case setPositionPromptFilterModeFret
    case setInstrumentGuitar6
    case setInstrumentBass4
    case setInstrumentBass5
    case setDisplayModeHorizontal
    case setDisplayModeVertical
    case setVisibilityAll
    case setVisibilityNaturalOnly
    case setVisibilityBCEFOnly
    case setVisibilityAccidentalOnly
    case setVisibilityNone
    case setSpellingSharp
    case setSpellingFlat
    case toggleShowsOctave
    case setClefTreble
    case setClefBass
    case setPianoMovementScopeCascade
    case setPianoMovementScopeRowOnly
    case setPianoWhiteKeyStyleOutlined
    case setPianoWhiteKeyStyleGapOnly
    case setPianoWhiteKeyStyleSkeuomorphicHighlight
}
```

## 修改后

- 新增 `FretboardStringThicknessStyle`，把弦粗细模式正式纳入共享配置。
- 在 `LayoutMetrics` 中新增低音弦/高音弦宽度比例，并提供 `resolvedStringLineWidth(...)` 作为唯一的宽度解析入口。
- 渲染层改为“逐根弦解析线宽后立即绘制”，从根因上消除“所有弦只能固定同宽”的限制。
- 设置面板 `Fretboard` 分组新增 `String Thickness` 行，提供 `Uniform` / `Graduated` 两个选项，并将选中态与 `displayState.configuration.stringThicknessStyle` 绑定。
- 新增共享层验证夹具，覆盖默认选中态、动作写回、切换后的面板选中态。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名: FretboardStringThicknessStyle / FretboardConfiguration.LayoutMetrics.default
// 功能说明: 修改后配置层引入弦粗细模式枚举；
// default 中除了统一基准线宽，还提供低音弦与高音弦的比例参数。
enum FretboardStringThicknessStyle: CaseIterable, Equatable, Hashable, Sendable {
    case uniform
    case graduated
}

struct FretboardConfiguration: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var horizontalInsetRatio: CGFloat
        var verticalInsetRatio: CGFloat
        var cellWidthToHeightRatio: CGFloat
        var stringLaneHeight: CGFloat
        var nutWidthRatio: CGFloat
        var fretLineWidth: CGFloat
        var stringLineWidth: CGFloat
        var bassStringLineWidthRatio: CGFloat
        var trebleStringLineWidthRatio: CGFloat
        var markerDiameterRatio: CGFloat
        var doubleMarkerOffsetRatio: CGFloat

        static let `default` = LayoutMetrics(
            horizontalInsetRatio: 0.04,
            verticalInsetRatio: 0.16,
            cellWidthToHeightRatio: 1.6,
            stringLaneHeight: 17,
            nutWidthRatio: 0.014,
            fretLineWidth: 1,
            stringLineWidth: 1.5,
            bassStringLineWidthRatio: 1.45,
            trebleStringLineWidthRatio: 0.85,
            markerDiameterRatio: 0.15,
            doubleMarkerOffsetRatio: 0.18
        )
    }

    var displayMode: FretboardDisplayMode
    var tuning: InstrumentTuning
    var maxFret: Int
    var stringThicknessStyle: FretboardStringThicknessStyle
    var layoutMetrics: LayoutMetrics
    var markerLayout: MarkerLayout
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名: FretboardConfiguration.LayoutMetrics.resolvedStringLineWidth(...)
// 功能说明: 修改后所有弦宽都必须先经过这个解析入口；
// uniform 返回统一宽度，graduated 则按弦序在低音弦和高音弦之间线性插值。
func resolvedStringLineWidth(
    for stringIndex: Int,
    stringCount: Int,
    style: FretboardStringThicknessStyle
) -> CGFloat {
    let baseWidth = max(stringLineWidth, Self.minimumLineWidth)

    switch style {
    case .uniform:
        return baseWidth
    case .graduated:
        return interpolatedStringLineWidth(
            for: stringIndex,
            stringCount: stringCount,
            baseWidth: baseWidth
        )
    }
}

private func interpolatedStringLineWidth(
    for stringIndex: Int,
    stringCount: Int,
    baseWidth: CGFloat
) -> CGFloat {
    let resolvedStringCount = max(stringCount, 1)
    guard resolvedStringCount > 1 else {
        return baseWidth
    }

    // 低序号弦视作低音弦端，使用更粗的比例；
    // 高序号弦逐步过渡到更细的高音弦比例。
    let resolvedStringIndex = min(max(stringIndex, 0), resolvedStringCount - 1)
    let progress = CGFloat(resolvedStringIndex) / CGFloat(resolvedStringCount - 1)
    let thickerRatio = max(
        max(bassStringLineWidthRatio, trebleStringLineWidthRatio),
        Self.minimumLineWidthRatio
    )
    let thinnerRatio = max(
        min(bassStringLineWidthRatio, trebleStringLineWidthRatio),
        Self.minimumLineWidthRatio
    )
    let lowStringWidth = max(baseWidth * thickerRatio, Self.minimumLineWidth)
    let highStringWidth = max(baseWidth * thinnerRatio, Self.minimumLineWidth)
    return lowStringWidth + ((highStringWidth - lowStringWidth) * progress)
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardBoardLayer.swift
// 函数名: drawStrings(in:)
// 功能说明: 修改后渲染层不再复用单一 lineWidth；
// 每根弦都会根据 stringIndex、stringCount、stringThicknessStyle 解析出自己的宽度后再绘制。
private func drawStrings(in context: CGContext) {
    guard !scene.stringSegments.isEmpty else {
        return
    }

    context.saveGState()
    context.setStrokeColor(FretboardPalette.string)
    context.setLineCap(.round)

    for stringSegment in scene.stringSegments {
        // 逐根弦解析宽度，避免低音弦/高音弦被统一成同一粗细。
        context.setLineWidth(
            configuration.layoutMetrics.resolvedStringLineWidth(
                for: stringSegment.stringIndex,
                stringCount: configuration.stringCount,
                style: configuration.stringThicknessStyle
            )
        )
        context.move(to: stringSegment.start)
        context.addLine(to: stringSegment.end)
        context.strokePath()
    }

    context.restoreGState()
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsSectionID.rowIDs / SettingsChoiceRowID.actionIDs / SettingsActionID
// 功能说明: 修改后设置面板在 Fretboard 分组新增 String Thickness；
// 该行使用 Uniform / Graduated 两个动作驱动共享状态，不再需要平台层额外解释业务语义。
case .fretboard:
    return [
        .choice(.instrument),
        .choice(.displayMode),
        .choice(.stringThickness),
        .choice(.labels),
        .choice(.spelling),
        .choice(.octave)
    ]

case .stringThickness:
    return [
        .setStringThicknessUniform,
        .setStringThicknessGraduated
    ]

enum SettingsActionID: CaseIterable, Equatable, Hashable, Sendable {
    case setStringThicknessUniform
    case setStringThicknessGraduated
    // ... 其他 action 省略
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelModel.swift
// 函数名: SettingsActionID.isSelected(in:) / SettingsActionID.apply(to: inout FretboardDisplayState)
// 功能说明: 修改后设置项的选中态与状态迁移都直接绑定到 stringThicknessStyle；
// 面板显示和真实渲染配置共享同一个真相来源。
case .setStringThicknessUniform:
    return stateContext.fretboardDisplayState.configuration.stringThicknessStyle == .uniform
case .setStringThicknessGraduated:
    return stateContext.fretboardDisplayState.configuration.stringThicknessStyle == .graduated

// ... 其他 case 省略

case .setStringThicknessUniform:
    displayState.configuration.stringThicknessStyle = .uniform
case .setStringThicknessGraduated:
    displayState.configuration.stringThicknessStyle = .graduated
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures() / validateFretboardStringThicknessOptionTracksState()
// 功能说明: 修改后新增共享层验证夹具；
// 用来约束 String Thickness 行必须存在、默认选中 Uniform、切换后必须正确回写为 Graduated。
SettingsNavigationValidationFixture(
    name: "fretboard_string_thickness_option_tracks_state",
    validate: validateFretboardStringThicknessOptionTracksState
)

static func validateFretboardStringThicknessOptionTracksState()
    -> [SettingsNavigationValidationIssue] {
    let fixtureName = "fretboard_string_thickness_option_tracks_state"
    var issues: [SettingsNavigationValidationIssue] = []

    let defaultStateContext = SettingsPanelStateContext.default
    let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(from: defaultStateContext)

    guard let defaultRow = defaultPanelModel.choiceRow(for: .stringThickness) else {
        issues.append(issue(fixtureName, "default state 应暴露 String Thickness 选项。"))
        return issues
    }

    if defaultRow.choices.filter(\.isSelected).map(\.id) != [.setStringThicknessUniform] {
        issues.append(issue(fixtureName, "default state 应默认选中 Uniform。"))
    }

    var graduatedStateContext = defaultStateContext
    SettingsActionID.setStringThicknessGraduated.apply(to: &graduatedStateContext)
    if graduatedStateContext.fretboardDisplayState.configuration.stringThicknessStyle != .graduated {
        issues.append(issue(fixtureName, "Graduated action 应写回 fretboardDisplayState。"))
    }

    return issues
}
```

## 效果总结

- 用户现在可以直接在设置面板中切换：
- `Uniform`：所有弦保持统一粗细
- `Graduated`：低音弦更粗，高音弦更细
- 共享状态、设置面板选中态、实际渲染结果三者已经打通，不再是“面板值”和“绘制行为”分离的状态

## 验证情况

- 已对本次涉及文件执行 IDE 诊断检查：`ReadLints` 无报错
- 本记录未附带 GIF diff，改动前后通过代码块和文字说明如实记录

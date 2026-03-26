# 20260326_192249_phase1_fretboard_shared_pitch_resolution

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_192249`
- 记录范围：阶段 1，共享层 `cell -> pitch` 真相收口
- 本次目标：把 `stringIndex + fret -> NotePitch / PitchClass` 从局部渲染逻辑中抽出，沉到 `Shared/Fretboard` 作为统一出口，为后续点击判题复用
- 根因结论：修改前音高推导公式只存在于 `NoteNameContentProvider.makeLabels(...)` 内部；标签渲染能算出音高，但点击判题链路没有共享 API 可复用。如果后续直接在控制器或 trainer 里再写一遍，就会继续制造第二套真相
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`

## 本次完成的修改

1. 在 `InstrumentTuning` 增加基础音高映射出口：`notePitch(stringIndex:fret:)` 与 `pitchClass(stringIndex:fret:)`。
2. 在 `FretboardConfiguration` 增加带配置边界校验的封装：校验 `stringIndex` 与 `fretRange`，并补 `FretboardCell` 入口。
3. 在 `NoteNameContentProvider.makeLabels(...)` 中删除局部音高推导，改为统一调用 `configuration.notePitch(...)`。

## 修改 1：`InstrumentTuning` 新增基础音高映射出口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift
// 函数/成员: openStringPitch(for:)
// 功能说明: 修改前 InstrumentTuning 只暴露空弦音高；
// 调用方如果想从 stringIndex + fret 直接得到 NotePitch / PitchClass，只能在外层自行拼装公式。
func openStringPitch(for stringIndex: Int) -> NotePitch? {
    guard openStringsLowToHigh.indices.contains(stringIndex) else {
        return nil
    }

    return openStringsLowToHigh[stringIndex]
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift
// 函数/成员: notePitch(stringIndex:fret:), pitchClass(stringIndex:fret:)
// 功能说明: 修改后把“空弦音高 + 品位半音偏移”收口为共享真相；
// 后续无论是标签渲染还是点击判题，都可以复用这条基础映射链路。
func notePitch(
    stringIndex: Int,
    fret: Int
) -> NotePitch? {
    guard
        fret >= 0,
        let openPitch = openStringPitch(for: stringIndex)
    else {
        return nil
    }

    return openPitch.advanced(by: fret)
}

func pitchClass(
    stringIndex: Int,
    fret: Int
) -> PitchClass? {
    notePitch(
        stringIndex: stringIndex,
        fret: fret
    )?.pitchClass
}
```

## 修改 2：`FretboardConfiguration` 增加带边界校验的调用入口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: fretRange, stringCount, displayPositionCount
// 功能说明: 修改前 FretboardConfiguration 持有当前指板配置边界，
// 但没有把这些边界和音高解析封成一个可直接复用的调用入口。
var fretRange: ClosedRange<Int> {
    0...maxFret
}

var stringCount: Int {
    tuning.stringCount
}

var displayPositionCount: Int {
    maxFret + 1
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数/成员: notePitch(stringIndex:fret:), notePitch(for:), pitchClass(stringIndex:fret:), pitchClass(for:)
// 功能说明: 修改后 FretboardConfiguration 负责做当前配置下的 stringIndex / fret 边界校验，
// 并为点击命中的 FretboardCell 提供直接解析入口，避免平台层重复理解配置语义。
func notePitch(
    stringIndex: Int,
    fret: Int
) -> NotePitch? {
    guard
        (0..<stringCount).contains(stringIndex),
        fretRange.contains(fret)
    else {
        return nil
    }

    return tuning.notePitch(
        stringIndex: stringIndex,
        fret: fret
    )
}

func notePitch(for cell: FretboardCell) -> NotePitch? {
    notePitch(
        stringIndex: cell.stringIndex,
        fret: cell.fret
    )
}

func pitchClass(
    stringIndex: Int,
    fret: Int
) -> PitchClass? {
    notePitch(
        stringIndex: stringIndex,
        fret: fret
    )?.pitchClass
}

func pitchClass(for cell: FretboardCell) -> PitchClass? {
    notePitch(for: cell)?.pitchClass
}
```

## 修改 3：`NoteNameContentProvider` 删除局部重复推导，统一走共享出口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数/成员: NoteNameContentProvider.makeLabels(configuration:scene:)
// 功能说明: 修改前 makeLabels(...) 自己读取 openStringPitch，并在循环里直接 advanced(by: fret)；
// 这导致音高推导公式只存在于渲染路径中，后续点击判题无法直接复用。
for stringIndex in 0..<configuration.stringCount {
    guard
        let openPitch = configuration.tuning.openStringPitch(for: stringIndex)
    else {
        continue
    }

    for fret in configuration.fretRange {
        let pitch = openPitch.advanced(by: fret)
        guard visibility.allows(pitch.pitchClass) else {
            continue
        }

        // ... 后续继续根据 pitch 生成 label 内容
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift
// 函数/成员: NoteNameContentProvider.makeLabels(configuration:scene:)
// 功能说明: 修改后渲染层不再自己计算音高，而是直接复用 configuration.notePitch(...);
// 这样标签显示和后续点击判题会共享同一条音高解析真相链路。
for stringIndex in 0..<configuration.stringCount {
    for fret in configuration.fretRange {
        guard
            let pitch = configuration.notePitch(
                stringIndex: stringIndex,
                fret: fret
            ),
            visibility.allows(pitch.pitchClass)
        else {
            continue
        }

        // ... 后续继续根据 pitch 生成 label 内容
    }
}
```

## 这次修改解决了什么

- 解决了“音高解析只存在于标签渲染内部”的结构问题。
- 为后续 `FretboardHitResult.cell -> PitchClass` 判题提供了直接可复用的 shared 入口。
- 消除了标签渲染和点击判题未来各写一套 `openPitch.advanced(by: fret)` 的重复风险。

## 本次明确未修改的边界

- 未修改 `iOSViewController` 与 `macOSViewController`
- 未修改 `iOSFretboardView` 与 `macOSFretboardView`
- 未新增 trainer 状态机
- 未引入任何目标音 UI

## 验证结果

- `ReadLints` 检查以下 3 个文件，结果为无错误：
- `NoteMaster_Ver_1/Shared/Fretboard/InstrumentTuning.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/NoteNameContentProvider.swift`
- 额外核对：项目内直接使用 `openStringPitch(for:) + advanced(by: fret)` 的重复实现已收口，当前只保留在 `InstrumentTuning.notePitch(...)` 这一处作为共享真相源

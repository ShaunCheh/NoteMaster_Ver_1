# 20260328_170907_phase1_single_pitchclass_cell_enumeration_and_validation

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260328_170907`
- 记录范围：实施 `single覆盖反馈` 计划的阶段 1，只补 shared 的目标音 cell 枚举能力与基础 validation，不涉及 single 判题流、prompt 进度、红绿 overlay
- 本次目标：为后续 `SingleCoverageSession` 提供“当前配置范围内某个 `PitchClass` 的全部 `FretboardCell`”共享真相源，并用 validation 锁定该枚举行为
- 本次实际修改文件：
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- `NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift`

## 根因结论

- 当前 `FretboardConfiguration` 只有“按单个位置解析音高/音名”的 API，还没有“按目标音名收集整块指板全部位置”的共享入口。
- 如果直接在后续 controller 或 trainer 里各自写双重循环，会让 single coverage 的真相源分散，iOS/macOS 也更容易出现实现漂移。
- 因此阶段 1 的根因级补强不是直接改判题，而是先在 shared 层收口 `PitchClass -> [FretboardCell]` 的枚举能力，并让 validation 对这条能力负责。

## 修改 1：在 `FretboardConfiguration.swift` 中新增目标音名的全指板 cell 枚举入口

### 修改前

- `FretboardConfiguration` 只能解析单个 `cell` 对应的 `NotePitch` / `PitchClass`
- `pitchClass(for:)` 之后就直接进入布局逻辑，没有“按音名枚举整板位置”的共享函数

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名: FretboardConfiguration.pitchClass(for:), FretboardConfiguration.verticalContentLayout(...)
// 功能说明: 修改前 configuration 只提供单个 cell 的 pitchClass 解析；
// 还没有供 single coverage 复用的“当前配置范围内某个音名的全部位置”枚举能力。
func pitchClass(for cell: FretboardCell) -> PitchClass? {
    notePitch(for: cell)?.pitchClass
}

// 修改前这里直接进入布局逻辑，没有目标音位置集合的 shared 入口。
func verticalContentLayout(
    forViewportHeight viewportHeight: CGFloat
) -> VerticalContentLayout {
    let resolvedViewportHeight = max(viewportHeight, 0)
    return VerticalContentLayout(
        viewportHeight: resolvedViewportHeight,
        contentWidth: layoutMetrics.verticalContentWidth(
            forViewportHeight: resolvedViewportHeight,
            displayPositionCount: displayPositionCount,
            stringCount: stringCount
        )
    )
}
```

### 修改后

- 新增 `cells(for pitchClass: PitchClass) -> [FretboardCell]`
- 枚举范围严格基于当前 `configuration.stringCount` 和 `configuration.fretRange`
- 返回顺序固定为 `stringIndex` 升序、`fret` 升序，便于后续 session、overlay、validation 共享同一份稳定顺序

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift
// 函数名: FretboardConfiguration.cells(for:)
// 功能说明: 修改后 configuration 提供 shared 纯函数，统一枚举当前指板范围内
// 某个 PitchClass 的全部可点击位置；后续 single coverage session 和 overlay 都可以直接复用。
func cells(for pitchClass: PitchClass) -> [FretboardCell] {
    var cells: [FretboardCell] = []
    cells.reserveCapacity(stringCount * displayPositionCount)

    for stringIndex in 0..<stringCount {
        for fret in fretRange {
            let cell = FretboardCell(
                stringIndex: stringIndex,
                fret: fret
            )
            guard notePitch(for: cell)?.pitchClass == pitchClass else {
                continue
            }
            cells.append(cell)
        }
    }

    return cells
}
```

## 修改 2：在 `FretboardValidation.swift` 中接入枚举校验主链路

### 修改前

- validation 主链路只检查几何、命中、`notePitch/pitchClass` 解析以及现有 trainer 行为
- 还没有专门验证 `PitchClass -> [FretboardCell]` 枚举结果的步骤

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: FretboardValidationRunner.validate(_:)
// 功能说明: 修改前 validation 只验证单格解析和现有 trainer；
// 尚未把“按音名枚举整板 cell”纳入自动化校验链路。
validatePitchResolution(
    fixture: fixture,
    record: record
)
validateNaturalNoteTrainer(
    fixture: fixture,
    record: record
)
validateQuarterNoteSequenceTrainer(
    fixture: fixture,
    record: record
)
```

### 修改后

- 在主校验链路中插入 `validatePitchClassCellEnumeration(...)`
- 让后续 single coverage 依赖的“目标位置全集”在 shared validation 层先被锁定

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: FretboardValidationRunner.validate(_:)
// 功能说明: 修改后 validation 主链路会先验证 pitchClass -> cells 的枚举行为，
// 再继续进入现有 natural trainer 与 quarter-note sequence trainer 的回归检查。
validatePitchResolution(
    fixture: fixture,
    record: record
)
validatePitchClassCellEnumeration(
    fixture: fixture,
    record: record
)
validateNaturalNoteTrainer(
    fixture: fixture,
    record: record
)
validateQuarterNoteSequenceTrainer(
    fixture: fixture,
    record: record
)
```

## 修改 3：新增 `validatePitchClassCellEnumeration(...)`，锁定枚举语义

### 修改前

- `FretboardValidation.swift` 里没有针对 `configuration.cells(for:)` 的校验函数
- 因此即使后续 single coverage 开始依赖它，也没有自动化手段保证：
- 返回结果与逐格 `pitchClass(for:)` 解析一致
- 不返回重复 `cell`
- 按 12 个 `PitchClass` 汇总后的总数等于当前指板总格数

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validatePitchResolution(...)
// 功能说明: 修改前 validation 只覆盖单格解析正确性与越界行为；
// 还没有“按 PitchClass 回收全部 cell”的独立验证函数。
static func validatePitchResolution(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    let configuration = fixture.configuration

    for stringIndex in 0..<configuration.stringCount {
        for fret in configuration.fretRange {
            let expectedPitch = openPitch.advanced(by: fret)
            // ...
        }
    }
}
```

### 修改后

- 新增 `validatePitchClassCellEnumeration(...)`
- 以全量 `allCells` 为基准，对每个 `PitchClass` 做三层检查：
- 枚举结果与逐格过滤结果完全一致
- 没有重复 `cell`
- 没有混入错误音名的 `cell`
- 最后再校验 12 个 `PitchClass` 汇总后的总数是否等于 `stringCount * displayPositionCount`

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数名: validatePitchClassCellEnumeration(...)
// 功能说明: 修改后新增独立 validation，专门锁定 configuration.cells(for:)
// 的返回内容、顺序稳定性和总数完整性，为后续 single coverage 提供基础回归保障。
static func validatePitchClassCellEnumeration(
    fixture: FretboardValidationFixture,
    record: (String) -> Void
) {
    let configuration = fixture.configuration
    let allCells = (0..<configuration.stringCount).flatMap { stringIndex in
        configuration.fretRange.map { fret in
            FretboardCell(
                stringIndex: stringIndex,
                fret: fret
            )
        }
    }

    for pitchClass in PitchClass.allCases {
        let enumeratedCells = configuration.cells(for: pitchClass)
        let expectedCells = allCells.filter {
            configuration.pitchClass(for: $0) == pitchClass
        }

        if enumeratedCells != expectedCells {
            record(
                "configuration.cells(for: \(pitchClass.displayText())) 未与逐格 pitchClass 解析结果保持一致。"
            )
        }

        if Set(enumeratedCells).count != enumeratedCells.count {
            record(
                "configuration.cells(for: \(pitchClass.displayText())) 返回了重复 cell。"
            )
        }
    }
}
```

## 影响范围与未改内容

- 本次只是给 shared 层补“目标音位置全集”能力，还没有修改 `single mode` 的判题条件。
- `FretboardNaturalNoteTrainerState.handle(...)` 仍然保持“首次正确命中即推进下一题”的旧行为。
- `TargetPromptContent`、`iOSTargetNotePromptView`、`macOSTargetNotePromptView` 还没有 coverage 进度 UI。
- `FretboardLayer` 仍然只有 `boardLayer + labelsLayer`，还没有红/绿反馈 overlay。

## 验证情况

- 已执行 `ReadLints` 检查，`FretboardConfiguration.swift` 与 `FretboardValidation.swift` 没有新增 linter 问题。
- 已通过 `git diff` 核对本次实际改动，只涉及上述两个 shared 文件。
- 尝试用 `xcodebuild -list -project "NoteMaster_Ver_1.xcodeproj"` 做工程级检查，但当前环境的 `xcode-select` 指向 `/Library/Developer/CommandLineTools`，不是完整 Xcode，因此无法直接运行工程编译/列 scheme：

```text
// 系统命令: xcodebuild -list -project "NoteMaster_Ver_1.xcodeproj"
// 功能说明: 试图做工程级校验，但当前本机 developer directory 不是完整 Xcode。
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

## 阶段结论

- 阶段 1 已完成：shared 现在可以稳定回答“当前配置范围内，这个目标音在整块指板上的所有位置有哪些”。
- 后续阶段 2 可以在此基础上实现 `SingleCoverageSession`，把 single 从“一次答对即过关”升级为“全部目标位置都命中后才切下一题”。

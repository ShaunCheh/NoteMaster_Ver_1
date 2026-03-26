# 20260326_193022_phase2_fretboard_natural_note_trainer

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260326_193022`
- 记录范围：阶段 2，共享层自然音练习状态机
- 本次目标：在 `Shared/Fretboard` 建立一份可复用的 trainer 状态机，统一承接随机自然音题目、点击判题、答对后切题，为后续 iOS / macOS 外层控制器接线做准备
- 根因结论：阶段 1 已经把 `FretboardCell -> NotePitch / PitchClass` 的解析真相收口到了共享层，但项目里仍然没有“当前目标音是什么、何时判题、答对后如何推进到下一题”的共享状态。如果直接在平台控制器里临时写随机逻辑和判题逻辑，就会让 iOS / macOS 各自维护一套业务规则
- 本次实际改动：
- 新增 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`

## 本次完成的修改

1. 新增 `FretboardNaturalNoteTrainerState`，作为共享层自然音练习状态机。
2. 将题目集合收口为 `C D E F G A B`，并支持默认随机与可注入随机源。
3. 新增 `handle(hitResult:configuration:)` 判题入口，只处理 `.ended` 命中，并忽略八度仅按 `PitchClass` 判题。
4. 实现“答对后切下一题、答错保留当前题目”的共享推进逻辑。

## 修改 1：新增共享 trainer 类型，承接题目状态与事件结果

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: 整个文件
// 功能说明: 修改前该文件不存在；项目里没有共享的自然音练习状态机，
// 当前目标音、无效点击原因、判题结果结构体都还没有统一建模。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: FretboardNaturalNoteTrainerState, IgnoreReason, Evaluation, EventResult
// 功能说明: 修改后共享层新增 trainer 状态机与结构化结果模型；
// 平台层后续只需要把 hitResult 交给 trainer，即可得到忽略原因或判题结果。
struct FretboardNaturalNoteTrainerState: Equatable, Sendable {
    enum IgnoreReason: Equatable, Sendable {
        case nonEndedPhase(FretboardEventPhase)
        case missingHitCell
        case unresolvedHitPitch(FretboardCell)
    }

    struct Evaluation: Equatable, Sendable {
        var targetPitchClass: PitchClass
        var selectedCell: FretboardCell
        var selectedPitch: NotePitch
        var isCorrect: Bool
        var nextTargetPitchClass: PitchClass
    }

    enum EventResult: Equatable, Sendable {
        case ignored(IgnoreReason)
        case evaluated(Evaluation)
    }

    private static let naturalPitchClasses: [PitchClass] = [
        .c, .d, .e, .f, .g, .a, .b
    ]

    private(set) var targetPitchClass: PitchClass
}
```

## 修改 2：建立自然音题目生成与切题逻辑

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: init(), init(randomUsing:), advanceToNextTarget(using:), randomNaturalPitchClass(excluding:using:)
// 功能说明: 修改前该文件不存在；
// 项目里没有统一的自然音候选集合，也没有默认随机入口和答对后切题逻辑。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: init(), init(randomUsing:), advanceToNextTarget(using:), randomNaturalPitchClass(excluding:using:)
// 功能说明: 修改后 trainer 把自然音候选集合收口为 C D E F G A B，
// 并支持默认随机与可注入随机源；答对后会切到下一个自然音，并避免立刻重复当前题目。
init() {
    var generator = SystemRandomNumberGenerator()
    self.init(randomUsing: &generator)
}

init<R: RandomNumberGenerator>(randomUsing generator: inout R) {
    self.init(
        targetPitchClass: Self.randomNaturalPitchClass(using: &generator)
    )
}

mutating func advanceToNextTarget<R: RandomNumberGenerator>(
    using generator: inout R
) -> PitchClass {
    let nextTargetPitchClass = Self.randomNaturalPitchClass(
        excluding: targetPitchClass,
        using: &generator
    )
    targetPitchClass = nextTargetPitchClass
    return nextTargetPitchClass
}

private static func randomNaturalPitchClass<R: RandomNumberGenerator>(
    excluding excludedPitchClass: PitchClass? = nil,
    using generator: inout R
) -> PitchClass {
    let candidates = naturalPitchClasses.filter { pitchClass in
        pitchClass != excludedPitchClass
    }
    let resolvedCandidates = candidates.isEmpty
        ? naturalPitchClasses
        : candidates

    guard let targetPitchClass = resolvedCandidates.randomElement(using: &generator) else {
        preconditionFailure("Natural pitch class candidates should never be empty.")
    }

    return targetPitchClass
}
```

## 修改 3：建立共享判题入口，只按 PitchClass 判题并过滤无效点击

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: handle(hitResult:configuration:), handle(hitResult:configuration:using:)
// 功能说明: 修改前该文件不存在；
// 项目里没有共享入口负责过滤非 ended 事件、无命中点击和不可解析音高，
// 也没有统一实现“忽略八度，仅按 PitchClass 判题”的逻辑。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: handle(hitResult:configuration:), handle(hitResult:configuration:using:)
// 功能说明: 修改后 trainer 只消费 ended 命中事件；
// 命中后通过 configuration.notePitch(for:) 解析 NotePitch，并忽略八度仅比较 PitchClass。
mutating func handle<R: RandomNumberGenerator>(
    hitResult: FretboardHitResult,
    configuration: FretboardConfiguration,
    using generator: inout R
) -> EventResult {
    guard hitResult.phase == .ended else {
        return .ignored(.nonEndedPhase(hitResult.phase))
    }

    guard let selectedCell = hitResult.cell else {
        return .ignored(.missingHitCell)
    }

    guard let selectedPitch = configuration.notePitch(for: selectedCell) else {
        return .ignored(.unresolvedHitPitch(selectedCell))
    }

    let answeredTargetPitchClass = targetPitchClass
    let isCorrect = selectedPitch.pitchClass == answeredTargetPitchClass
    let nextTargetPitchClass: PitchClass
    if isCorrect {
        nextTargetPitchClass = advanceToNextTarget(using: &generator)
    } else {
        nextTargetPitchClass = answeredTargetPitchClass
    }

    return .evaluated(
        Evaluation(
            targetPitchClass: answeredTargetPitchClass,
            selectedCell: selectedCell,
            selectedPitch: selectedPitch,
            isCorrect: isCorrect,
            nextTargetPitchClass: nextTargetPitchClass
        )
    )
}
```

## 修改 4：增加调试摘要，便于平台层直接输出控制台结果

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: Evaluation.debugSummary()
// 功能说明: 修改前该文件不存在；
// 共享层没有结构化的 trainer 调试输出，平台层如果要打印结果，只能自行拼装日志字符串。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: Evaluation.debugSummary()
// 功能说明: 修改后共享层提供统一的控制台摘要格式，
// 后续 iOS / macOS 控制器接线时可以直接复用，不需要各自重复拼接日志内容。
func debugSummary() -> String {
    let resultText = isCorrect ? "correct" : "wrong"
    return "[FretboardTrainer] target=\(targetPitchClass.displayText()) selected=\(selectedPitch.displayText()) selectedClass=\(selectedPitchClass.displayText()) string=\(selectedCell.stringIndex) fret=\(selectedCell.fret) result=\(resultText) next=\(nextTargetPitchClass.displayText())"
}
```

## 这次修改解决了什么

- 解决了“共享层只有音高解析，没有练习状态机”的结构缺口。
- 把自然音题目集合、判题规则、忽略事件规则、答对后切题规则都收口到了 shared 层。
- 为后续 iOS / macOS 外层控制器接线提供了统一业务接口，避免双平台各自实现一套练习逻辑。

## 本次明确未修改的边界

- 未修改 `iOSViewController` 与 `macOSViewController`
- 未修改 `iOSFretboardView` 与 `macOSFretboardView`
- 未修改 `FretboardInteraction.swift`
- 未修改 `NoteMaster_Ver_1.xcodeproj/project.pbxproj`
- 当前工程使用 `PBXFileSystemSynchronizedRootGroup`，因此新增 shared 文件不需要手动写入 `pbxproj`

## 验证结果

### 静态检查

- `ReadLints` 检查 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`，结果为无错误

### 类型检查

```bash
# 执行位置: /Users/shaun/Library/Mobile Documents/com~apple~CloudDocs/Develop/NoteMaster_Ver_1
# 命令说明: 对 Shared/Fretboard 下的 Swift 文件执行 typecheck，确认新增 trainer 状态机不依赖平台层也能通过编译。
xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift
```

- 结果：通过
- 结论：阶段 2 新增的共享 trainer 状态机已经能独立参与 shared 层编译，后续可以直接接入平台控制器

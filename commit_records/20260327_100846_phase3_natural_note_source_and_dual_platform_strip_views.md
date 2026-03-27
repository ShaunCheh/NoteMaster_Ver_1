# 20260327_100846_phase3_natural_note_source_and_dual_platform_strip_views

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_100846`
- 记录范围：`PageDisplayState` 阶段 3，自然音单一真相源与双平台自然音按钮组件
- 本次目标：把 `C D E F G A B` 的顺序和自然音判断收敛到 shared `PitchClass`，并补齐 iOS / macOS 两端的单行自然音按钮组件，为后续 `Main Content` 切换接线提供统一 UI 载体
- 根因结论：修改前自然音集合只存在于 `FretboardNaturalNoteTrainerState` 的私有数组里；一旦新主内容组件也要显示 `CDEFGAB`，就只能再复制一份顺序和筛选规则。这样 shared 逻辑和平台 UI 会各自维护一套自然音真相，后续只要顺序、筛选条件或展示规则发生变化，就会出现不一致。同时，双平台此前也没有承载 `PageMainContentMode.naturalNoteStrip` 的具体视图组件
- 本次实际改动：
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift`
- 修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`
- 新增 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- 新增 `NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`

## 本次完成的修改

1. 在 `PitchClass` 中新增 `isNatural` 与 `naturalCasesInOrder`，把 `CDEFGAB` 提升为 shared 单一真相源。
2. 让 `FretboardNaturalNoteTrainerState` 不再维护私有自然音数组，统一复用 `PitchClass.naturalCasesInOrder`。
3. 新增 iOS 自然音按钮组件，使用 `UIStackView + UIButton` 实现一行 7 个按钮、不换行、等宽分布。
4. 新增 macOS 对称组件，使用 `NSStackView + NSButton` 实现同样的布局和点击回调接口。
5. 两端组件都保持“薄视图”职责，只暴露 `onPitchClassTap`，暂不把 trainer 状态或 controller 逻辑塞进组件内部。

## 修改 1：把自然音顺序和语义收敛到 `PitchClass`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift
// 函数/成员: PitchClass.isAccidental
// 功能说明: 修改前 PitchClass 只能判断是否为升降号；
// 没有“自然音”共享语义，也没有按顺序暴露 CDEFGAB 集合。
enum PitchClass: Int, CaseIterable, Hashable, Sendable {
    case c = 0
    case cSharp = 1
    case d = 2
    case dSharp = 3
    case e = 4
    case f = 5
    case fSharp = 6
    case g = 7
    case gSharp = 8
    case a = 9
    case aSharp = 10
    case b = 11

    var isAccidental: Bool {
        switch self {
        case .cSharp, .dSharp, .fSharp, .gSharp, .aSharp:
            return true
        default:
            return false
        }
    }

    // ... 下方仍是原有的 displayText(using:) 文本映射逻辑
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift
// 函数/成员: PitchClass.isNatural, PitchClass.naturalCasesInOrder
// 功能说明: 修改后把“自然音判断”和“有序自然音集合”都收敛到 PitchClass；
// trainer 和新按钮组件统一从这里取 CDEFGAB，不再各自维护。
enum PitchClass: Int, CaseIterable, Hashable, Sendable {
    case c = 0
    case cSharp = 1
    case d = 2
    case dSharp = 3
    case e = 4
    case f = 5
    case fSharp = 6
    case g = 7
    case gSharp = 8
    case a = 9
    case aSharp = 10
    case b = 11

    var isAccidental: Bool {
        switch self {
        case .cSharp, .dSharp, .fSharp, .gSharp, .aSharp:
            return true
        default:
            return false
        }
    }

    var isNatural: Bool {
        !isAccidental
    }

    static var naturalCasesInOrder: [PitchClass] {
        allCases.filter(\.isNatural)
    }

    // ... 下方仍是原有的 displayText(using:) 文本映射逻辑
}
```

## 修改 2：让 trainer 复用 shared 自然音真相源

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: naturalPitchClasses, init(targetPitchClass:), randomNaturalPitchClass(excluding:using:)
// 功能说明: 修改前 trainer 内部私有维护一份 CDEFGAB；
// 目标音校验和随机出题都依赖这份本地数组，和外部 UI 没有共享真相源。
struct FretboardNaturalNoteTrainerState: Equatable, Sendable {
    private static let naturalPitchClasses: [PitchClass] = [
        .c, .d, .e, .f, .g, .a, .b
    ]

    private(set) var targetPitchClass: PitchClass

    init(targetPitchClass: PitchClass) {
        precondition(
            Self.naturalPitchClasses.contains(targetPitchClass),
            "Target pitch class must be a natural note."
        )
        self.targetPitchClass = targetPitchClass
    }

    // ... 中间无关逻辑省略

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
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift
// 函数/成员: init(targetPitchClass:), randomNaturalPitchClass(excluding:using:)
// 功能说明: 修改后 trainer 不再维护自己的自然音数组；
// 目标音校验和随机出题统一复用 PitchClass.isNatural / naturalCasesInOrder。
struct FretboardNaturalNoteTrainerState: Equatable, Sendable {
    private(set) var targetPitchClass: PitchClass

    init(targetPitchClass: PitchClass) {
        precondition(
            targetPitchClass.isNatural,
            "Target pitch class must be a natural note."
        )
        self.targetPitchClass = targetPitchClass
    }

    // ... 中间无关逻辑省略

    private static func randomNaturalPitchClass<R: RandomNumberGenerator>(
        excluding excludedPitchClass: PitchClass? = nil,
        using generator: inout R
    ) -> PitchClass {
        let candidates = PitchClass.naturalCasesInOrder.filter { pitchClass in
            pitchClass != excludedPitchClass
        }
        let resolvedCandidates = candidates.isEmpty
            ? PitchClass.naturalCasesInOrder
            : candidates

        guard let targetPitchClass = resolvedCandidates.randomElement(using: &generator) else {
            preconditionFailure("Natural pitch class candidates should never be empty.")
        }

        return targetPitchClass
    }
}
```

## 修改 3：新增 iOS 自然音按钮组件

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 iOS 侧还没有自然音按钮条组件；
// Main Content 即使切到自然音模式，也没有可直接承载 CDEFGAB 的 UIView。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数/成员: iOSNaturalNoteStripView.configureView(), makeButton(for:), handleButtonTap(_:)
// 功能说明: 新增 iOS 自然音按钮条，统一基于 PitchClass.naturalCasesInOrder 生成 7 个按钮；
// 使用横向 UIStackView + fillEqually 保证单行、不换行、等宽分布，并通过 onPitchClassTap 向外透传点击结果。
#if os(iOS)
import UIKit

final class iOSNaturalNoteStripView: UIView {
    var onPitchClassTap: ((PitchClass) -> Void)?

    private let stackView = UIStackView()
    private lazy var buttons: [NaturalNoteButton] = {
        PitchClass.naturalCasesInOrder.map { pitchClass in
            makeButton(for: pitchClass)
        }
    }()

    private func configureView() {
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = Style.itemSpacing

        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }
        // ... 约束代码省略
    }

    private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
        let button = NaturalNoteButton(frame: .zero)
        button.apply(pitchClass: pitchClass)
        button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)
        return button
    }

    @objc
    private func handleButtonTap(_ sender: NaturalNoteButton) {
        guard let pitchClass = sender.pitchClass else { return }
        onPitchClassTap?(pitchClass)
    }
}
#endif
```

## 修改 4：新增 macOS 对称自然音按钮组件

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/成员: 文件不存在
// 功能说明: 修改前 macOS 侧也没有与 iOS 对称的自然音按钮条组件；
// 页面主内容区域暂时无法在 AppKit 下承载 CDEFGAB 的单行按钮视图。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift
// 函数/成员: macOSNaturalNoteStripView.configureView(), makeButton(for:), handleButtonTap(_:)
// 功能说明: 新增 macOS 自然音按钮条，与 iOS 侧保持对称；
// 使用横向 NSStackView + fillEqually 保证单行、不换行、等宽分布，并通过 onPitchClassTap 对外回传点击音名。
#if os(macOS)
import AppKit

final class macOSNaturalNoteStripView: NSView {
    var onPitchClassTap: ((PitchClass) -> Void)?

    private let stackView = NSStackView()
    private lazy var buttons: [NaturalNoteButton] = {
        PitchClass.naturalCasesInOrder.map { pitchClass in
            makeButton(for: pitchClass)
        }
    }()

    private func configureView() {
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillEqually
        stackView.spacing = Style.itemSpacing

        addSubview(stackView)
        buttons.forEach { stackView.addArrangedSubview($0) }
        // ... 约束代码省略
    }

    private func makeButton(for pitchClass: PitchClass) -> NaturalNoteButton {
        let button = NaturalNoteButton(frame: .zero)
        button.apply(pitchClass: pitchClass)
        button.target = self
        button.action = #selector(handleButtonTap(_:))
        return button
    }

    @objc
    private func handleButtonTap(_ sender: NaturalNoteButton) {
        guard let pitchClass = sender.pitchClass else { return }
        onPitchClassTap?(pitchClass)
    }
}
#endif
```

## 当前边界

1. 阶段 3 只完成了 shared 真相源和双平台组件准备。
2. `PageMainContentMode.naturalNoteStrip` 还没有接入双平台 controller 的主内容 host，这部分属于后续阶段 4 的范围。

## 验证情况

1. 已检查 IDE 诊断，当前无新增 linter 问题：`NoteMaster_Ver_1/Shared/Fretboard/NotePitch.swift`、`NoteMaster_Ver_1/Shared/Fretboard/FretboardNaturalNoteTrainer.swift`、`NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`、`NoteMaster_Ver_1/Platform/macOS/Controls/macOSNaturalNoteStripView.swift`
2. 未执行完整 `xcodebuild` 编译验证；当前环境的 `xcode-select` 指向 Command Line Tools，无法直接完成完整 Xcode 工程构建。

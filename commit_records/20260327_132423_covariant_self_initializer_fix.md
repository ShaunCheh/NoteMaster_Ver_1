# 20260327_132423_covariant_self_initializer_fix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260327_132423`
- 记录范围：修复 `Covariant 'Self' type cannot be referenced from a stored property initializer`
- 本次目标：消除 `macOSViewController.swift` 中的编译错误，并同步修正 iOS 对称实现里的同类隐患
- 本次实际修改文件：
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`

## 根因结论

- `initialStaffDisplayState` 是定义在类上的静态成员。
- `staffDisplayState` 和 `baseStaffDisplayState` 是类的存储属性；它们在初始化表达式里写成了 `Self.initialStaffDisplayState`。
- 对类类型来说，Swift 不允许在存储属性初始化器中引用协变 `Self`，因此会报 `Covariant 'Self' type cannot be referenced from a stored property initializer`。
- 这次不是只改报错的 macOS 端，而是把 iOS 对称实现一起改掉，避免同样的问题在另一端继续潜伏。

## 修改 1：macOS 端把 `Self` 改成具体类名

### 修改前

- `staffDisplayState` 和 `baseStaffDisplayState` 都直接引用 `Self.initialStaffDisplayState`
- 这会触发当前用户看到的编译错误

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: staffDisplayState, baseStaffDisplayState
// 功能说明: 修改前在类的存储属性初始化器中直接引用协变 Self；
// 该写法会触发 Swift 的 covariant Self 编译限制。
final class macOSViewController: NSViewController {
    private static let initialStaffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        ),
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
    )

    private var staffDisplayState = Self.initialStaffDisplayState {
        didSet {
            guard isViewLoaded else {
                return
            }

            if !trainerDisplayState.isSequenceMode {
                baseStaffDisplayState = staffDisplayState
            }
            applyStaffDisplayState()
        }
    }

    private var baseStaffDisplayState = Self.initialStaffDisplayState
}
```

### 修改后

- 把 `Self.initialStaffDisplayState` 显式改为 `macOSViewController.initialStaffDisplayState`
- 保持原有初始化语义不变，只修复 Swift 对协变 `Self` 的限制

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: staffDisplayState, baseStaffDisplayState
// 功能说明: 修改后改为引用具体类名的静态成员；
// 这样既保留默认 staff 初始值，又满足类存储属性初始化器的 Swift 规则。
final class macOSViewController: NSViewController {
    private static let initialStaffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        ),
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
    )

    private var staffDisplayState = macOSViewController.initialStaffDisplayState {
        didSet {
            guard isViewLoaded else {
                return
            }

            if !trainerDisplayState.isSequenceMode {
                baseStaffDisplayState = staffDisplayState
            }
            applyStaffDisplayState()
        }
    }

    private var baseStaffDisplayState = macOSViewController.initialStaffDisplayState
}
```

## 修改 2：iOS 对称实现同步修正

### 修改前

- iOS 端使用了同样的写法
- 虽然这次报错点出现在 macOS，但 iOS 端结构完全对称，属于同一根因

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: staffDisplayState, baseStaffDisplayState
// 功能说明: 修改前 iOS 端与 macOS 端同构，也在类的存储属性初始化器中引用了 Self。
final class iOSViewController: UIViewController {
    private static let initialStaffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        ),
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
    )

    private var staffDisplayState = Self.initialStaffDisplayState {
        didSet {
            guard isViewLoaded else {
                return
            }

            if !trainerDisplayState.isSequenceMode {
                baseStaffDisplayState = staffDisplayState
            }
            applyStaffDisplayState()
        }
    }

    private var baseStaffDisplayState = Self.initialStaffDisplayState
}
```

### 修改后

- 同样改成显式类名 `iOSViewController.initialStaffDisplayState`
- 保证两端平台保持同构，后续不会再出现一端修了、另一端继续报同类错的情况

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: staffDisplayState, baseStaffDisplayState
// 功能说明: 修改后 iOS 端也改为引用具体类名的静态成员，
// 保持与 macOS 端一致的根因级修复策略。
final class iOSViewController: UIViewController {
    private static let initialStaffDisplayState = StaffDisplayState(
        configuration: StaffConfiguration(
            renderMode: .coreText,
            trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
            debugOptions: .init(
                showsClefBounds: true,
                showsClefAnchor: true
            )
        ),
        score: StaffScoreFixtures.namedKeySignatureDemo(clef: .treble)
    )

    private var staffDisplayState = iOSViewController.initialStaffDisplayState {
        didSet {
            guard isViewLoaded else {
                return
            }

            if !trainerDisplayState.isSequenceMode {
                baseStaffDisplayState = staffDisplayState
            }
            applyStaffDisplayState()
        }
    }

    private var baseStaffDisplayState = iOSViewController.initialStaffDisplayState
}
```

## 验证结果

- `ReadLints` 检查结果：
- `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 以上文件均为 `No linter errors found`
- 本次记录文件已放入：`commit_records/20260327_132423_covariant_self_initializer_fix.md`
- 本次没有执行 `xcodebuild`；这里只记录本次实际做过的静态诊断结果

## 本次修复结果

- 已消除 macOS 端 `Covariant 'Self' type cannot be referenced from a stored property initializer` 的直接触发点
- iOS/macOS 两端现在都不再在类的存储属性初始化器中引用协变 `Self`
- 修改只涉及初始化表达式写法，没有改变 `initialStaffDisplayState` 的实际默认值和后续 `didSet` 行为

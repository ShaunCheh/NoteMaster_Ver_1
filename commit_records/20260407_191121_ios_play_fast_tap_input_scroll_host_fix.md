# 20260407_191121_ios_play_fast_tap_input_scroll_host_fix

## 记录范围

本记录只覆盖刚刚这一轮针对 `play mode` 下“快速点击琴键时，不出现命中高亮，也不发出声音”的根因修复。

这次修复的目标不是改 `Shared/Piano` 的交互状态机，也不是改 `Shared/Playback` 的播放语义，而是把 **iOS 平台上“滚动容器承载可交互 surface”** 的触摸仲裁契约收口到单点，避免 `play` 页继续漏配、`exercise` 页继续手写一份、renderer 再手写一份。

本记录参考了当前工作区的 `git diff` 与文件现状，但 **不包含原始 diff**。

当前工作区里，这次修复实际涉及的代码文件只有 4 个：

- `NoteMaster_Ver_1/Platform/iOS/iOSInteractiveSurfaceScrollView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`

---

## 1. 根因收口：新增 iOS 交互 surface 专用 scroll host

### 1.1 `iOSInteractiveSurfaceScrollView.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSInteractiveSurfaceScrollView.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；iOS 上“滚动容器里承载可交互 surface”的触摸策略只能分散在各个 controller / renderer 里手写，play 页面遗漏时不会有公共边界兜底。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSInteractiveSurfaceScrollView.swift
// 函数名: init(frame:) / init?(coder:) / touchesShouldBegin(_:with:in:) / touchesShouldCancel(in:) / configureInteractionContract()
// 功能说明: 修改后新增专用 iOSInteractiveSurfaceScrollView，把“初始点击立即透传给交互子视图；形成滚动后允许 scroll view 接管”的平台契约收口到一个公共类，供 play / exercise / renderer 统一复用。
#if os(iOS)
import UIKit

final class iOSInteractiveSurfaceScrollView: UIScrollView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureInteractionContract()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureInteractionContract()
    }

    override func touchesShouldBegin(
        _ touches: Set<UITouch>,
        with event: UIEvent?,
        in view: UIView
    ) -> Bool {
        true
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        true
    }
}

private extension iOSInteractiveSurfaceScrollView {
    func configureInteractionContract() {
        delaysContentTouches = false
        canCancelContentTouches = true
        panGestureRecognizer.cancelsTouchesInView = true
    }
}
#endif
```

---

## 2. `play mode` 页面切到统一的交互 scroll host

### 2.1 `iOSPlayViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: 成员定义 / configureLayout()
// 功能说明: 修改前 play 页直接用普通 UIScrollView 承载 pianoSurfaceView，只配置了滚动行为，没有配置“点击优先透传给交互子视图”的触摸契约；快速点按时，scroll view 可能延迟或吞掉 began。
private let scrollView = UIScrollView()
private let contentView = UIView()

func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false

    scrollView.alwaysBounceVertical = true
    scrollView.alwaysBounceHorizontal = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.isDirectionalLockEnabled = true

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(pianoSurfaceView)
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: 成员定义 / configureLayout()
// 功能说明: 修改后 play 页不再直接持有普通 UIScrollView，而是切到统一的 iOSInteractiveSurfaceScrollView；这样钢琴 surface 的初始点按会立刻下发给键盘视图，纵向拖动时又仍可被 scroll host 接管。
private let scrollView = iOSInteractiveSurfaceScrollView()
private let contentView = UIView()

func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false

    scrollView.alwaysBounceVertical = true
    scrollView.alwaysBounceHorizontal = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.isDirectionalLockEnabled = true
    // Piano surface needs the initial tap immediately; once the gesture
    // turns into a pan, the shared interactive scroll host will cancel it.

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(pianoSurfaceView)
}
```

---

## 3. 旧的 `exercise` 容器改为复用同一契约

### 3.1 `iOSViewController.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: 成员定义 / configureLayout()
// 功能说明: 修改前 exercise controller 已经有正确的 scroll host 触摸策略，但它是 controller 内部手写的局部实现；这意味着 play 页仍可能漏配，平台层没有一个可复用的单一真相。
private let scrollView = UIScrollView()
private let contentView = UIView()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    scrollView.alwaysBounceHorizontal = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.isDirectionalLockEnabled = true
    // 点击直接透传给指板；一旦用户开始纵向拖动，scroll view 可以取消当前触摸序列并接管滚动。
    scrollView.delaysContentTouches = false
    scrollView.canCancelContentTouches = true
    scrollView.panGestureRecognizer.cancelsTouchesInView = true
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名: 成员定义 / configureLayout()
// 功能说明: 修改后 exercise controller 与 play 页共享同一个交互 scroll host，不再自己维护一套等价配置；这样平台输入层的契约来源只有一个。
private let scrollView = iOSInteractiveSurfaceScrollView()
private let contentView = UIView()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    scrollView.alwaysBounceHorizontal = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.isDirectionalLockEnabled = true
    // 点击直接透传给交互 surface；一旦用户开始纵向拖动，共用 scroll host 会取消当前触摸序列并接管滚动。
}
```

---

## 4. renderer 里的局部 scroll 配置也同步收回

### 4.1 `iOSExerciseSceneRenderer.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: 成员定义 / configureStaticHierarchy()
// 功能说明: 修改前 renderer 里的 fretboard viewport 也直接持有普通 UIScrollView，并在 renderer 内部重复写一套 delaysContentTouches / canCancelContentTouches / cancelsTouchesInView；同类平台契约继续分散。
private let fretboardViewportScrollView = UIScrollView()

private func configureStaticHierarchy() {
    fretboardViewportScrollView.alwaysBounceVertical = false
    fretboardViewportScrollView.alwaysBounceHorizontal = false
    fretboardViewportScrollView.showsVerticalScrollIndicator = false
    fretboardViewportScrollView.showsHorizontalScrollIndicator = false
    fretboardViewportScrollView.isDirectionalLockEnabled = true
    fretboardViewportScrollView.delaysContentTouches = false
    fretboardViewportScrollView.canCancelContentTouches = true
    fretboardViewportScrollView.panGestureRecognizer.cancelsTouchesInView = true
    fretboardViewportScrollView.contentInsetAdjustmentBehavior = .never
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: 成员定义 / configureStaticHierarchy()
// 功能说明: 修改后 renderer 也切到 iOSInteractiveSurfaceScrollView；滚动行为仍按 viewport 的需要单独配置，但交互触摸策略不再在 renderer 内重复定义。
private let fretboardViewportScrollView = iOSInteractiveSurfaceScrollView()

private func configureStaticHierarchy() {
    fretboardViewportScrollView.alwaysBounceVertical = false
    fretboardViewportScrollView.alwaysBounceHorizontal = false
    fretboardViewportScrollView.showsVerticalScrollIndicator = false
    fretboardViewportScrollView.showsHorizontalScrollIndicator = false
    fretboardViewportScrollView.isDirectionalLockEnabled = true
    fretboardViewportScrollView.contentInsetAdjustmentBehavior = .never
}
```

---

## 5. 这次修复后的实际效果

- `play mode` 下的钢琴页面不再使用普通 `UIScrollView` 直接承载交互 surface，而是走统一的 `iOSInteractiveSurfaceScrollView`。
- 原来只存在于 `exercise` controller 和 renderer 内部的触摸策略，已经被提升为 iOS 平台公共 scroll host 契约。
- 这样修复后，快速点按钢琴键时，`iOSPianoKeyboardView` 更容易稳定收到 `.began`，从而继续走：
  - `PianoRawEvent(.began)`
  - `PianoInteractionReducer.reduceWithoutActiveInteraction(...)`
  - `previewStarted`
  - 键盘命中高亮
  - `PlaybackCoordinator.startPreview(...)`
- 这次没有改 `Shared/Piano/PianoInteractionReducer.swift`，也没有改 `Shared/Playback/PlaybackCoordinator.swift`；修复点被严格限制在 iOS 平台输入宿主层。

---

## 6. 验证结果

本轮实际做了以下验证：

- 对以下文件执行 `ReadLints`，未发现新增诊断：
  - `NoteMaster_Ver_1/Platform/iOS/iOSInteractiveSurfaceScrollView.swift`
  - `NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS" build`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`

验证结论：

- iOS Debug 构建通过
- macOS Debug 构建通过
- 本轮没有单独执行设备/模拟器上的手动快速点按 smoke test；运行态交互效果仍需你在 `play mode` 下实际点按确认

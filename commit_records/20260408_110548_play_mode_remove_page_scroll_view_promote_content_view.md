# 20260408_110548_play_mode_remove_page_scroll_view_promote_content_view

## 记录范围

本记录只覆盖刚刚这一轮针对 `play mode` 页面结构的实际代码修改。

这次修改的目标不是继续调整 `Shared/Play` 的 scene policy，也不是去改 `Shared/Piano` 的交互状态机；目标很单一：

- 去掉 `play mode` 页面级 `scrollView`
- 把 `contentView` 提升为页面主内容容器
- 保留钢琴组件的固有高度语义，避免移除滚动后把钢琴错误拉伸成整页高度

本记录参考了当前工作区这两个文件的 `git diff`、`git status` 与文件现状，但 **不包含原始 diff**。

这次修改实际只涉及 2 个代码文件：

- `NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift`
- `NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift`

当前工作区里还存在其它未提交变更，但它们不是本轮“移除 play mode 页面级 scroll view”的实现内容，因此本记录不把它们计入“修改前 / 修改后”范围。

---

## 1. iOS：`iOSPlayViewController.swift`

### 1.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: 成员定义 / configureLayout()
// 功能说明: 修改前 play 页通过页面级 iOSInteractiveSurfaceScrollView 承载 contentView，再由 contentView 承载 pianoSurfaceView；钢琴区域的底部与 contentView 底部是强等式，页面本身仍属于滚动容器。
private let scrollView = iOSInteractiveSurfaceScrollView()
private let contentView = UIView()

func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false

    scrollView.alwaysBounceVertical = true
    scrollView.alwaysBounceHorizontal = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.isDirectionalLockEnabled = true
    // Piano surface needs the initial tap immediately; once the gesture
    // turns into a pan, the shared interactive scroll host will cancel it.

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(pianoSurfaceView)
    view.addSubview(settingsButton)
    view.addSubview(settingsContainerView)

    let safeArea = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
        contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        pianoSurfaceView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        pianoSurfaceView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

### 1.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: 成员定义 / configureLayout()
// 功能说明: 修改后页面级 scroll host 被删除，contentView 直接成为 safe area 下的主内容容器；钢琴仍从顶部布局，但底部约束改成 <=，避免 contentView 填满页面后反向把 pianoSurfaceView 强行拉伸到整页高度。
private let contentView = UIView()

func configureLayout() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    // Play 页面只有钢琴主内容，不再通过 scroll host 承载内容，
    // 这样钢琴输入不会再参与页面级滚动仲裁。
    view.addSubview(contentView)
    contentView.addSubview(pianoSurfaceView)
    view.addSubview(settingsButton)
    view.addSubview(settingsContainerView)

    let safeArea = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
        contentView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: safeArea.topAnchor),
        contentView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
        pianoSurfaceView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        pianoSurfaceView.bottomAnchor.constraint(
            lessThanOrEqualTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

---

## 2. macOS：`macOSPlayViewController.swift`

### 2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift
// 函数名: 成员定义 / configureLayout()
// 功能说明: 修改前 macOS play 页也通过页面级 NSScrollView 承载 contentView，再由 contentView 承载 pianoSurfaceView；页面级滚动容器仍存在，钢琴底部同样是与 contentView 底部的强等式。
private let scrollView = NSScrollView()
private let contentView = NSView()

func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false

    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.documentView = contentView

    view.addSubview(scrollView)
    contentView.addSubview(pianoSurfaceView)
    view.addSubview(settingsButton)
    view.addSubview(settingsContainerView)

    let safeArea = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
        contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
        contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        pianoSurfaceView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        pianoSurfaceView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

### 2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift
// 函数名: 成员定义 / configureLayout()
// 功能说明: 修改后 macOS play 页和 iOS 一样去掉了页面级 scroll host，contentView 直接挂到 safe area；钢琴底部改成 <= 容器底部，保证 contentView 填满页面时仍由钢琴自身 intrinsic height 决定实际内容高度。
private let contentView = NSView()

func configureLayout() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    settingsContainerView.translatesAutoresizingMaskIntoConstraints = false
    // Play 页面只有钢琴主内容，不再通过 scroll host 承载内容，
    // 这样鼠标/触摸输入不会先经过页面级滚动容器。
    view.addSubview(contentView)
    contentView.addSubview(pianoSurfaceView)
    view.addSubview(settingsButton)
    view.addSubview(settingsContainerView)

    let safeArea = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
        contentView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: safeArea.topAnchor),
        contentView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
        pianoSurfaceView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.contentTopInset
        ),
        pianoSurfaceView.bottomAnchor.constraint(
            lessThanOrEqualTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

---

## 3. 为什么底部约束从 `==` 改成 `<=`

### 3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: configureLayout()
// 功能说明: 修改前因为 contentView 位于 scroll content 链路里，pianoSurfaceView 与 contentView.bottom 的强等式表示“用钢琴内容去定义滚动内容高度”。
pianoSurfaceView.topAnchor.constraint(
    equalTo: contentView.topAnchor,
    constant: Layout.contentTopInset
),
pianoSurfaceView.bottomAnchor.constraint(
    equalTo: contentView.bottomAnchor,
    constant: -Layout.bottomInset
)
```

### 3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Play/iOSPlayViewController.swift
// 函数名: configureLayout()
// 功能说明: 修改后 contentView 直接 fill safe area；如果继续保持 bottom ==，Auto Layout 会把 pianoSurfaceView 反向拉伸到整页高度，因此这里必须降成 <=，让钢琴维持自身 intrinsicContentSize，高度不足时只是在底部留白。
pianoSurfaceView.topAnchor.constraint(
    equalTo: contentView.topAnchor,
    constant: Layout.contentTopInset
),
pianoSurfaceView.bottomAnchor.constraint(
    lessThanOrEqualTo: contentView.bottomAnchor,
    constant: -Layout.bottomInset
)
```

同样的原因也适用于 `NoteMaster_Ver_1/Platform/macOS/Play/macOSPlayViewController.swift`。

---

## 4. 本轮实际验证结果

本轮不是只改未验，实际验证如下：

- `ReadLints` 检查 `iOSPlayViewController.swift`、`macOSPlayViewController.swift`，无新增诊断。
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS Simulator" build` 通过。
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build` 通过。

---

## 5. 小结

这次修改后的 `play mode` 页面层级从：

```text
view
└─ scrollView
   └─ contentView
      └─ pianoSurfaceView
```

变成：

```text
view
└─ contentView
   └─ pianoSurfaceView
```

也就是说，页面级滚动容器已经被拿掉，`contentView` 现在就是 `play mode` 的直接主内容容器。


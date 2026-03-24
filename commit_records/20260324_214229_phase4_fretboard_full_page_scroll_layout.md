20260324_214229_phase4_fretboard_full_page_scroll_layout

# Phase 4 Fretboard Full-Page Scroll Layout 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardConfiguration.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift`

## 修改前

### iOS 控制器仍把四个子视图直接挂在根视图上，最后由 `safeArea.bottom` 收口

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：configureLayout()
// 功能说明：修改前页面还没有整页滚动容器；
// `buttonPanelView`、`staffControlPanelView`、`staffView`、`fretboardView` 都直接加在控制器根视图上，
// 最后一块通过 `fretboardView.bottom <= safeArea.bottom` 收口，内容高度不会进入滚动链路。
private func configureLayout() {
    buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffControlPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(buttonPanelView)
    view.addSubview(staffControlPanelView)
    view.addSubview(staffView)
    view.addSubview(fretboardView)

    let safeArea = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
        buttonPanelView.leadingAnchor.constraint(
            equalTo: safeArea.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        buttonPanelView.trailingAnchor.constraint(
            equalTo: safeArea.trailingAnchor,
            constant: -Layout.horizontalInset
        ),
        buttonPanelView.topAnchor.constraint(
            equalTo: safeArea.topAnchor,
            constant: Layout.topInset
        ),
        staffControlPanelView.leadingAnchor.constraint(
            equalTo: safeArea.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        staffControlPanelView.trailingAnchor.constraint(
            equalTo: safeArea.trailingAnchor,
            constant: -Layout.horizontalInset
        ),
        staffControlPanelView.topAnchor.constraint(
            equalTo: buttonPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        staffView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        staffView.topAnchor.constraint(
            equalTo: staffControlPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        fretboardView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        fretboardView.topAnchor.constraint(
            equalTo: staffView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardView.bottomAnchor.constraint(
            lessThanOrEqualTo: safeArea.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

### macOS 控制器也仍是根视图直挂四块内容，没有 `NSScrollView`

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：configureLayout()
// 功能说明：修改前 macOS 页面结构和 iOS 一样，仍是根视图直接堆叠四个内容块；
// 布局末端仍然通过 `fretboardView.bottom <= safeArea.bottom` 结束，尚未把页面内容放进 document/content 容器。
private func configureLayout() {
    buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffControlPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(buttonPanelView)
    view.addSubview(staffControlPanelView)
    view.addSubview(staffView)
    view.addSubview(fretboardView)

    let safeArea = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
        buttonPanelView.leadingAnchor.constraint(
            equalTo: safeArea.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        buttonPanelView.trailingAnchor.constraint(
            equalTo: safeArea.trailingAnchor,
            constant: -Layout.horizontalInset
        ),
        buttonPanelView.topAnchor.constraint(
            equalTo: safeArea.topAnchor,
            constant: Layout.topInset
        ),
        staffControlPanelView.leadingAnchor.constraint(
            equalTo: safeArea.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        staffControlPanelView.trailingAnchor.constraint(
            equalTo: safeArea.trailingAnchor,
            constant: -Layout.horizontalInset
        ),
        staffControlPanelView.topAnchor.constraint(
            equalTo: buttonPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        staffView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        staffView.topAnchor.constraint(
            equalTo: staffControlPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
        fretboardView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        fretboardView.topAnchor.constraint(
            equalTo: staffView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardView.bottomAnchor.constraint(
            lessThanOrEqualTo: safeArea.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

## 修改后

### iOS 控制器引入 `UIScrollView + contentView`，页面内容整体进入纵向滚动链路

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：scrollView / contentView / configureLayout()
// 功能说明：修改后 iOS 控制器新增整页滚动容器和内容容器，
// 四个现有子视图全部迁入 `contentView`；内容宽度固定跟随 `scrollView.frameLayoutGuide.width`，
// 布局末端改为 `fretboardView.bottom == contentView.bottom`，让总内容高度由子视图链路自然推导。
private let scrollView = UIScrollView()
private let contentView = UIView()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffControlPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(buttonPanelView)
    contentView.addSubview(staffControlPanelView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardView)

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
        buttonPanelView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        buttonPanelView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -Layout.horizontalInset
        ),
        buttonPanelView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.topInset
        ),
        staffControlPanelView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        staffControlPanelView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -Layout.horizontalInset
        ),
        staffControlPanelView.topAnchor.constraint(
            equalTo: buttonPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        staffView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        staffView.topAnchor.constraint(
            equalTo: staffControlPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        fretboardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardView.topAnchor.constraint(
            equalTo: staffView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

### macOS 控制器引入 `NSScrollView + contentView`，页面内容改为 document 语义

```swift
// 文件路径：NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数名：scrollView / contentView / configureLayout()
// 功能说明：修改后 macOS 控制器新增 `NSScrollView` 和 document 内容容器，
// 通过 `scrollView.documentView = contentView` 承载整页内容；内容宽度绑定到 `scrollView.contentView.width`，
// 最后一块同样改为收口到 `contentView.bottom`，为后续窗口拉伸和整页滚动提供统一宿主。
private let scrollView = NSScrollView()
private let contentView = NSView()

private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffControlPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.documentView = contentView
    view.addSubview(scrollView)
    contentView.addSubview(buttonPanelView)
    contentView.addSubview(staffControlPanelView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardView)

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
        buttonPanelView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        buttonPanelView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -Layout.horizontalInset
        ),
        buttonPanelView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: Layout.topInset
        ),
        staffControlPanelView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: Layout.horizontalInset
        ),
        staffControlPanelView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -Layout.horizontalInset
        ),
        staffControlPanelView.topAnchor.constraint(
            equalTo: buttonPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        staffView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        staffView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        staffView.topAnchor.constraint(
            equalTo: staffControlPanelView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        fretboardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        fretboardView.topAnchor.constraint(
            equalTo: staffView.bottomAnchor,
            constant: Layout.verticalSpacing
        ),
        fretboardView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Layout.bottomInset
        )
    ])
}
```

## 结果说明

- 双平台页面结构已经从“根视图直接堆内容”切到“整页滚动容器 + 内容容器”。
- `buttonPanelView`、`staffControlPanelView`、`staffView`、`fretboardView` 现在都挂在 `contentView` 里，内容总高度会顺着底部收口进入滚动链路。
- 阶段 4 只改控制器布局宿主，没有改共享几何、双平台指板视图的尺寸出口，也没有改交互策略。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift` 与 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`，无新增诊断。
- 已执行 Swift 源码级类型检查，结果通过。
- 本阶段尚未执行 iOS/macOS 的人工 UI 滚动验证；整页滚动的运行时表现仍需后续真机、模拟器或桌面窗口实测确认。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对项目 Swift 源码执行静态类型检查，确认阶段 4 的控制器布局改动没有引入编译期错误。
swiftc -typecheck NoteMaster_Ver_1/**/*.swift
```

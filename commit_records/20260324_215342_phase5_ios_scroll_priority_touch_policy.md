20260324_215342_phase5_ios_scroll_priority_touch_policy

# Phase 5 iOS Scroll Priority Touch Policy 修改记录

## 本次变更范围

- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
- 未修改 `NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardInteraction.swift`
- 未修改 `NoteMaster_Ver_1/Shared/Fretboard/FretboardGeometry.swift`

## 修改前

### iOS 控制器虽然已经引入整页 `UIScrollView`，但没有显式声明 scroll 与指板触摸的优先级策略

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：configureLayout()
// 功能说明：修改前 iOS 页面已经有 `UIScrollView + contentView`，
// 但 scroll view 仍完全依赖 UIKit 默认 touch 策略；
// “点击应尽快到达指板”与“纵向拖动应让整页滚动接管”的边界没有被代码显式声明。
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
    // ... 其余约束省略 ...
}
```

## 修改后

### iOS 控制器显式收口为“点击透传，纵向拖动可取消触摸并接管滚动”的 scroll 策略

```swift
// 文件路径：NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数名：configureLayout()
// 功能说明：修改后 iOS 控制器在 scroll 容器初始化阶段显式声明交互边界：
// 关闭横向 bounce 与横向滚动指示器，点击尽快透传给内容视图；
// 一旦用户开始纵向拖动，scroll view 可以取消当前触摸序列并接管滚动，和“整页自然滚动优先”的需求保持一致。
private func configureLayout() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    buttonPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffControlPanelView.translatesAutoresizingMaskIntoConstraints = false
    staffView.translatesAutoresizingMaskIntoConstraints = false
    fretboardView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    scrollView.alwaysBounceHorizontal = false
    scrollView.showsHorizontalScrollIndicator = false
    // 点击直接透传给指板；一旦用户开始纵向拖动，scroll view 可以取消当前触摸序列并接管滚动。
    scrollView.delaysContentTouches = false
    scrollView.canCancelContentTouches = true
    scrollView.panGestureRecognizer.cancelsTouchesInView = true
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(buttonPanelView)
    contentView.addSubview(staffControlPanelView)
    contentView.addSubview(staffView)
    contentView.addSubview(fretboardView)
    // ... 其余约束省略 ...
}
```

## 结果说明

- iOS 整页 scroll 容器现在不再完全依赖 UIKit 默认触摸策略，而是显式收口到“整页滚动优先”的交互边界。
- 当前实现的语义是：短点击/短触摸可以更快到达指板；一旦用户开始纵向拖动，scroll view 可以取消当前触摸序列并接管滚动。
- 阶段 5 没有尝试保住连续拖动命中，也没有新增自定义 gesture recognizer；这一步只做最小而明确的策略声明。
- 本阶段没有改 macOS，因为此前确认的优先级约束只针对 iOS 整页滚动场景。

## 验证情况

- `ReadLints` 检查 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`，无新增诊断。
- 已执行 Swift 源码级类型检查，结果通过。
- 本阶段尚未执行真机或模拟器中的手势实测；“拖动被取消后 raw 事件的实际序列”仍需运行时验证。

```shell
# 文件路径：无（命令行验证）
# 函数名：无
# 功能说明：对项目 Swift 源码执行静态类型检查，确认阶段 5 的 iOS 交互策略改动没有引入编译期错误。
swiftc -typecheck NoteMaster_Ver_1/**/*.swift
```

# 20260403_192004_ios_natural_note_strip_top_left_overlap_diagnosis_and_fix

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260403_192004`
- 记录范围：只记录这次 iOS `naturalNoteStrip` 在 App 冷启动进入 `side` 布局时，12 个音名按钮挤在左上角的问题排查与修复过程
- 本记录中的“修改前”：
- 对 `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift` / `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`，指阶段5完成后、开始排查这个 iOS 启动问题之前的代码状态
- 对“日志分析 / 原因分析 / 解决方案”，按本次真实排查顺序记录：先做临时日志，得出第一轮“时序问题”结论；随后根据复测现象继续下钻，最终修到 Auto Layout / frame 布局交接这一层
- 本记录不放原始 `git diff`，只按真实代码状态说明“修改前 / 修改后 / 排查结论”
- 本轮相关代码文件：
- `NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- `NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- 本轮相关代码文件状态（`git status --short`）：
- `M NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift`
- `M NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift`
- 本轮 `git diff --stat`（仅上述代码文件）：`2 files changed, 69 insertions(+), 46 deletions(-)`

## 1. 问题现象

- 现象只发生在 iOS 启动首帧进入 `side` 布局时。
- `naturalNoteStrip` 的 12 个按钮不是按 shared placement 分散开，而是视觉上全部挤在左上角。
- 手动切到 `stacked`，再切回 `side` 后，按钮又会恢复正常散开。

## 2. 临时日志排查与第一轮结论

### 2.1 排查方式

- 为了定位启动首帧到底是哪一层出错，临时在 `iOSNaturalNoteStripView.swift` 和 `iOSExerciseSceneRenderer.swift` 加了 `DEBUG` 级打点。
- 打点关注的事件只有三类：
- renderer 何时把 `presentationStyle` / `railLayout` 下发到 `naturalNoteStripView`
- `naturalNoteStripView` 何时切到 `verticalRail`
- `placement.frame` 何时真正落到每个按钮上
- 结论确认后，这批临时日志已经从代码中移除，不保留到最终版本。

### 2.2 关键日志证据

```text
# 日志来源: iOS 冷启动运行日志（临时 RailTrace 打点）
# 关联文件: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift -> renderSurface(_:,in:) / configurePresentationStyle(for:)
# 关联文件: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift -> applyLayoutMode() / layoutRailCanvasIfNeeded()
[RailTrace][iOSRenderer] event=renderSurface.begin ... layout=size={148, 370},centered=true,placements=12
[RailTrace][iOSStrip] event=applyLayoutMode mode=verticalRail ... bounds={{0, 0}, {0, 0}} canvas={{0, 0}, {0, 0}} ... buttons={C{frame={{0, 0}, {0, 0}}...}}
[RailTrace][iOSStrip] event=layoutRailCanvasIfNeeded ... bounds={{0, 0}, {148, 370}} ... buttons={C{frame={{86, 10}, {50, 50}}...}}
```

### 2.3 第一轮分析结论

- 第一条日志说明 shared 层给出的 `ExerciseNaturalNoteStripRailLayout` 从启动第一帧开始就是完整的，不是 builder 算错。
- 第二条日志说明：在首轮 side 渲染里，`naturalNoteStripView` 已经切进 `verticalRail`，但当时 `bounds` 仍然是 `0`，按钮还没真正拿到最终 frame。
- 第三条日志说明：只要首轮 layout pass 真正发生，按钮就能按 placement 散开。
- 所以第一轮结论是：问题看起来像“时序问题”，也就是 placement 落地时机晚于容器切换时机。

## 3. 第一轮修复：把配置入口收口成一次原子更新

### 3.1 renderer 下发配置的方式

#### 3.1.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: configurePresentationStyle(for:)
// 修改前说明:
// 1. renderer 分两次调用 `naturalNoteStripView`。
// 2. `presentationStyle` 与 `railLayout` 不是一个原子更新。
private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyPresentationStyle(surface.presentationStyle)
    naturalNoteStripView.applyRailLayout(
        currentPresentationState?.naturalNoteStripRailLayout
    )
}
```

#### 3.1.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
// 函数名: configurePresentationStyle(for:)
// 修改后说明:
// 1. renderer 只保留一次 `applyConfiguration(...)` 调用。
// 2. `presentationStyle` 与 `railLayout` 在同一次入口里一起生效。
private func configurePresentationStyle(for surface: ExerciseSurfaceNode) {
    guard surface.id == .naturalNoteStrip else {
        return
    }

    naturalNoteStripView.applyConfiguration(
        presentationStyle: surface.presentationStyle,
        railLayout: currentPresentationState?.naturalNoteStripRailLayout
    )
}
```

### 3.2 `iOSNaturalNoteStripView` 的配置入口

#### 3.2.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: applyPresentationStyle(_:), applyRailLayout(_:), layoutSubviews()
// 修改前说明:
// 1. `layoutMode` 和 `railLayout` 都是带 `didSet` 的独立入口。
// 2. 每次单独变化都会触发一次 `applyLayoutMode()`。
// 3. placement 落地依赖后续 `layoutSubviews()` 再补一次。
var layoutMode: LayoutMode = .horizontalStrip {
    didSet {
        guard oldValue != layoutMode else {
            return
        }
        applyLayoutMode()
    }
}

private var railLayout: ExerciseNaturalNoteStripRailLayout =
    defaultNaturalNoteStripRailLayout {
    didSet {
        guard oldValue != railLayout else {
            return
        }
        applyLayoutMode()
    }
}

func applyPresentationStyle(_ presentationStyle: ExerciseSurfacePresentationStyle) {
    switch presentationStyle {
    case .verticalRail:
        layoutMode = .verticalRail
    case .standard, .horizontalStrip:
        layoutMode = .horizontalStrip
    }
}

func applyRailLayout(_ railLayout: ExerciseNaturalNoteStripRailLayout?) {
    self.railLayout = railLayout ?? defaultNaturalNoteStripRailLayout
}

override func layoutSubviews() {
    super.layoutSubviews()
    layoutRailCanvasIfNeeded()
}
```

#### 3.2.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: applyConfiguration(presentationStyle:railLayout:), layoutSubviews()
// 修改后说明:
// 1. `layoutMode` 与 `railLayout` 不再分开更新。
// 2. 新入口只在“组合配置真的变化”时才刷新一次。
// 3. `layoutSubviews()` 只负责宿主内的 railCanvas 定位，不再承担首轮 placement 落地。
private var layoutMode: LayoutMode = .horizontalStrip
private var railLayout: ExerciseNaturalNoteStripRailLayout =
    defaultNaturalNoteStripRailLayout

func applyConfiguration(
    presentationStyle: ExerciseSurfacePresentationStyle,
    railLayout: ExerciseNaturalNoteStripRailLayout?
) {
    let nextLayoutMode = resolvedLayoutMode(for: presentationStyle)
    let nextRailLayout = railLayout ?? defaultNaturalNoteStripRailLayout
    guard
        layoutMode != nextLayoutMode
            || self.railLayout != nextRailLayout
    else {
        return
    }

    layoutMode = nextLayoutMode
    self.railLayout = nextRailLayout
    applyCurrentConfiguration()
}

override func layoutSubviews() {
    super.layoutSubviews()
    updateRailCanvasFrameIfNeeded()
}
```

### 3.3 把 placement 落地与宿主居中拆开

#### 3.3.1 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: layoutRailCanvasIfNeeded()
// 修改前说明:
// 1. `railCanvasView` 的 frame 计算和按钮 placement 落地混在一个函数里。
// 2. 这条路径主要依赖 `layoutSubviews()` 触发。
private func layoutRailCanvasIfNeeded() {
    guard layoutMode == .verticalRail else {
        railCanvasView.frame = .zero
        return
    }

    let contentSize = CGSize(
        width: verticalRailIntrinsicWidth,
        height: verticalRailIntrinsicHeight
    )
    let contentFrame = CGRect(
        x: max(0, (bounds.width - contentSize.width) / 2),
        y: max(0, (bounds.height - contentSize.height) / 2),
        width: min(bounds.width, contentSize.width),
        height: min(bounds.height, contentSize.height)
    )
    railCanvasView.frame = contentFrame

    buttons.forEach { button in
        guard
            let pitchClass = button.pitchClass,
            let placement = railPlacement(for: pitchClass)
        else {
            button.isHidden = true
            return
        }

        button.isHidden = false
        button.frame = placement.frame
    }
}
```

#### 3.3.2 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: applyCurrentConfiguration(), applyRailContentLayout(), updateRailCanvasFrameIfNeeded()
// 修改后说明:
// 1. `applyCurrentConfiguration()` 在配置切换时立即把 placement 写进按钮。
// 2. `updateRailCanvasFrameIfNeeded()` 只负责把整块 railCanvas 居中到宿主里。
// 3. 这样按钮内容布局不再依赖下一轮 `layoutSubviews()` 才发生。
private func applyCurrentConfiguration() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        // ... 省略无关 hugging / resistance 代码 ...
    case .verticalRail:
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        // ... 省略无关 hugging / resistance 代码 ...
    }

    syncButtonContainer()
    buttons.forEach {
        $0.applyLayoutMode(layoutMode, railLayout: activeRailLayout)
        $0.applyVisibleTitle(
            resolvedVisibleTitle(for: $0.pitchClass)
        )
    }
    applyRailContentLayout()
    invalidateIntrinsicContentSize()
    setNeedsLayout()
}

private func applyRailContentLayout() {
    guard layoutMode == .verticalRail else {
        railCanvasView.frame = .zero
        return
    }

    buttons.forEach { button in
        guard
            let pitchClass = button.pitchClass,
            let placement = railPlacement(for: pitchClass)
        else {
            button.isHidden = true
            return
        }

        button.isHidden = false
        button.frame = placement.frame
    }
    updateRailCanvasFrameIfNeeded()
}

private func updateRailCanvasFrameIfNeeded() {
    guard layoutMode == .verticalRail else {
        railCanvasView.frame = .zero
        return
    }

    let contentSize = CGSize(
        width: verticalRailIntrinsicWidth,
        height: verticalRailIntrinsicHeight
    )
    railCanvasView.frame = resolvedRailCanvasFrame(for: contentSize)
}
```

### 3.4 第一轮修复后的判断

- 这一轮修复的目标，是把“配置切换”和“placement 落地”收口到一个确定的调用时机里。
- 它确实修掉了“靠下一次 `layoutSubviews()` 才补 frame”这一层问题。
- 但用户复测后仍然反馈“还是挤在一起”，说明这还不是最底层的根因。

## 4. 第二轮原因分析：问题不只是时序，还是布局系统交接

- 复测仍然异常后，重新检查 `iOSNaturalNoteStripView.swift` 发现：同一批 `UIButton` 被复用了两套布局系统。
- 在 `horizontalStrip` 下，它们是 `UIStackView` 的 `arrangedSubview`，由 Auto Layout 管。
- 在 `verticalRail` 下，它们又被移到 `railCanvasView` 里，通过 `button.frame = placement.frame` 手动摆放。
- 真正漏掉的一步是：按钮从 `UIStackView` 脱离后，没有显式切回“手动 frame 布局模式”。
- 结果就是：代码虽然写入了 `button.frame`，但按钮仍带着 Auto Layout 接管状态，下一轮又会被系统压回左上角附近，看起来就像“12 个按钮又挤到一起了”。

### 4.1 暴露问题的旧代码

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: syncButtonContainer()
// 修改前说明:
// 1. 这里只做了按钮的容器迁移。
// 2. 没有显式切换按钮的布局机制。
// 3. 从 `stackView` 切到 `railCanvasView` 后，按钮仍可能残留 Auto Layout 接管状态。
private func syncButtonContainer() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.isHidden = false
        railCanvasView.isHidden = true
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            stackView.addArrangedSubview(button)
        }
    case .verticalRail:
        stackView.isHidden = true
        railCanvasView.isHidden = false
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            railCanvasView.addSubview(button)
        }
    }
}
```

## 5. 最终根因修复：容器迁移时显式切换布局机制

### 5.1 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
// 函数名: syncButtonContainer(), prepareButtonForStackViewLayout(_:), prepareButtonForManualRailLayout(_:)
// 修改后说明:
// 1. 按钮进 `stackView` 时，显式交还给 Auto Layout。
// 2. 按钮进 `railCanvasView` 时，显式切回手动 frame 布局。
// 3. 这样 `button.frame = placement.frame` 才不会被后续 Auto Layout 再压回左上角。
private func syncButtonContainer() {
    switch layoutMode {
    case .horizontalStrip:
        stackView.isHidden = false
        railCanvasView.isHidden = true
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            prepareButtonForStackViewLayout(button)
            stackView.addArrangedSubview(button)
        }
    case .verticalRail:
        stackView.isHidden = true
        railCanvasView.isHidden = false
        buttons.forEach { button in
            detachButtonFromCurrentContainer(button)
            prepareButtonForManualRailLayout(button)
            railCanvasView.addSubview(button)
        }
    }
}

private func prepareButtonForStackViewLayout(_ button: NaturalNoteButton) {
    button.translatesAutoresizingMaskIntoConstraints = false
}

private func prepareButtonForManualRailLayout(_ button: NaturalNoteButton) {
    // 同一批按钮会在 stack-based 与 frame-based 布局之间复用。
    // 进入 verticalRail 时，必须显式切回手动布局模式。
    button.translatesAutoresizingMaskIntoConstraints = true
}
```

## 6. 这次问题的真实结论

- 第一轮日志结论没有错：shared placement 的确从一开始就是对的。
- 但第一轮修复只解决了“placement 落地时机偏后”的问题，还没修掉更深的一层。
- 真正的根因，是按钮在 `UIStackView` 路径和 `railCanvasView` 路径之间切换时，没有完成 Auto Layout 与 frame 布局之间的所有权交接。
- 所以最终修法不是继续补 `layoutIfNeeded()`，也不是再加一次强制刷新，而是把“容器迁移”和“布局机制迁移”绑定到一起。
- 临时 RailTrace 日志在结论确认后已经删除，避免继续污染启动日志。

## 7. 验证情况

```text
# 验证来源: 本轮本地检查
# 关联文件: NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift
# 关联文件: NoteMaster_Ver_1/Platform/iOS/Exercise/iOSExerciseSceneRenderer.swift
ReadLints:
- NoteMaster_Ver_1/Platform/iOS/Controls/iOSNaturalNoteStripView.swift -> No linter errors found

xcodebuild:
- 命令: xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
- 结果: Exit code 0
```

## 8. 仍待补充的回归

- 由于之前 `CoreSimulatorService` 曾不稳定，本轮先完成了静态检查与 iOS simulator build。
- 等 simulator 服务稳定后，还需要补一轮真正的 iOS 冷启动 smoke，确认首帧进入 `side` 时按钮不再聚集到左上角。

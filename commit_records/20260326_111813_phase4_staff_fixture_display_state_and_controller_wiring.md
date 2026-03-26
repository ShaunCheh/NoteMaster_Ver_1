# 20260326_111813_phase4_staff_fixture_display_state_and_controller_wiring

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_111813`
- 记录范围：`五线谱音符渲染` 的阶段 4 实施
- 本次目标：把共享 demo `StaffScore` 接入 `StaffDisplayState` 与 iOS / macOS controller，让现有五线谱视图真正吃到音符数据
- 根因结论：阶段 3 虽然已经完成了 `StaffScore -> StaffSceneBuilder -> StaffScene -> Renderer` 共享层链路，但平台侧仍然没有任何地方把 `score` 注入这条链路：
  - `StaffDisplayState` 只持有 `configuration`
  - `sceneProvider` 仍然只从 `configuration.clef` 派生
  - iOS / macOS controller 初始化时都没有共享 demo score
  - settings panel 虽然已经统一依赖 `staffDisplayState`，但并不需要因为接入 score 而改模型结构
- 本次实际改动：
  - 新增 `NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift`
  - 修改 `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
  - 修改 `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
  - 修改 `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`

## 本次完成的修改

1. 新增 `StaffScoreFixtures.defaultDemo(clef:)`，用代码中的 JSON 字符串构造共享 demo 谱例。
2. 在 `StaffDisplayState` 中新增 `score`，并把 `score` 接入 `sceneProvider`。
3. 在 `StaffDisplayState` 中新增 `resolvedScore`，确保渲染时始终以当前 `configuration.clef` 作为视觉真相来源。
4. 在 iOS / macOS controller 初始化 `staffDisplayState` 时注入同一份共享 fixture。
5. 保持 settings 面板结构不变，不把 fixture 选择做成新的设置项。

## 修改 1：新增共享 demo fixture `StaffScoreFixtures.swift`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: 文件级（此前不存在）
// 功能说明: 修改前 Shared/Staff 下还没有共享 demo 谱例工厂；
// iOS / macOS 如果要演示音符渲染，只能各自散落地写一份 score 或直接写死在 controller 里。
// 修改前: 文件不存在。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift
// 函数/成员: StaffScoreFixtures.defaultDemo(clef:) / resolveScore(named:clef:notesJSON:)
// 功能说明: 修改后 Shared/Staff 提供统一的 demo 谱例入口；
// fixture 内部直接复用阶段 1 的 StaffScore.decode(from:) 解码链路，避免 controller 自己拼领域对象。
enum StaffScoreFixtures {
    static func defaultDemo(clef: StaffClef = .treble) -> StaffScore {
        resolveScore(
            named: "default-demo",
            clef: clef,
            notesJSON: """
            [
              { "pitch": "e4",  "duration": "quarter" },
              { "pitch": "f#4", "duration": "quarter" },
              { "pitch": "g4",  "duration": "quarter" },
              { "pitch": "bb4", "duration": "half" },
              { "pitch": "c5",  "duration": "quarter" },
              { "pitch": "d5",  "duration": "quarter" },
              { "pitch": "e5",  "duration": "half" },
              { "pitch": "f5",  "duration": "whole" }
            ]
            """
        )
    }

    private static func resolveScore(
        named fixtureName: String,
        clef: StaffClef,
        notesJSON: String
    ) -> StaffScore {
        let json = """
        {
          "clef": "\(clef.token)",
          "notes": \(notesJSON)
        }
        """

        return (try? StaffScore.decode(from: json)) ?? StaffScore(clef: clef, notes: [])
    }
}
```

## 修改 2：`StaffDisplayState` 新增 `score`，并把内容输入接入 `sceneProvider`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState / sceneProvider
// 功能说明: 修改前 StaffDisplayState 只持有 configuration 和平台展示态，
// sceneProvider 只根据 configuration.clef 派生，五线谱视图拿不到任何音符内容输入。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration
    var showsComponentBoundsOverlay: Bool

    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            renderHint: .staffClef(
                boundsOverlayStyle: configuration.debugOptions.showsClefBounds
                ? .clefDebug(lineWidth: configuration.debugOptions.clefBoundsLineWidth)
                : nil,
                anchorOverlayStyle: configuration.debugOptions.showsClefAnchor
                ? .clefDebug(
                    lineWidth: configuration.debugOptions.clefAnchorLineWidth,
                    crossHalfLength: configuration.debugOptions.clefAnchorCrossHalfLength
                )
                : nil
            )
        )
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift
// 函数/成员: StaffDisplayState / sceneProvider / resolvedScore
// 功能说明: 修改后 StaffDisplayState 同时承接配置与 score；
// sceneProvider 在投影时会拿到 resolvedScore，从而把 controller 注入的乐谱内容真正送进共享渲染链路。
struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration
    var score: StaffScore?
    var showsComponentBoundsOverlay: Bool

    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            score: resolvedScore,
            renderHint: .staffClef(
                boundsOverlayStyle: configuration.debugOptions.showsClefBounds
                ? .clefDebug(lineWidth: configuration.debugOptions.clefBoundsLineWidth)
                : nil,
                anchorOverlayStyle: configuration.debugOptions.showsClefAnchor
                ? .clefDebug(
                    lineWidth: configuration.debugOptions.clefAnchorLineWidth,
                    crossHalfLength: configuration.debugOptions.clefAnchorCrossHalfLength
                )
                : nil
            )
        )
    }

    private var resolvedScore: StaffScore? {
        guard var score else {
            return nil
        }

        score.clef = configuration.clef
        return score
    }
}
```

## 修改 3：iOS controller 初始化 staff 状态时注入共享 fixture

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: staffDisplayState
// 功能说明: 修改前 iOS controller 初始化的 StaffDisplayState 只有 configuration，
// 五线谱视图即使能消费 sceneProvider，也只能拿到 clef-only 场景。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    )
) {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyStaffDisplayState()
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift
// 函数/成员: staffDisplayState
// 功能说明: 修改后 iOS controller 在初始化 staff 状态时直接注入共享 demo score；
// 这样现有 applyStaffDisplayState() 与 staffView.sceneProvider 不用改结构，就能开始渲染音符。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
) {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyStaffDisplayState()
    }
}
```

## 修改 4：macOS controller 对称注入同一份共享 fixture

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: staffDisplayState
// 功能说明: 修改前 macOS controller 与 iOS 一样，初始化 staffDisplayState 时只有 configuration；
// 双平台虽然共享了五线谱 view 和 scene/render 链路，但还没有共享的 score 真相源。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    )
) {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyStaffDisplayState()
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift
// 函数/成员: staffDisplayState
// 功能说明: 修改后 macOS controller 也注入同一份共享 demo score；
// iOS / macOS 现在通过同一个 fixture 工厂获得 staff 内容输入，避免两端各维护一份演示谱例。
private var staffDisplayState = StaffDisplayState(
    configuration: StaffConfiguration(
        renderMode: .coreText,
        trebleClefAnchorLogicalDownwardShiftRatio: 0.06,
        debugOptions: .init(
            showsClefBounds: true,
            showsClefAnchor: true
        )
    ),
    score: StaffScoreFixtures.defaultDemo(clef: .treble)
) {
    didSet {
        guard isViewLoaded else {
            return
        }

        applyStaffDisplayState()
    }
}
```

## 修改结果说明

- 阶段 4 只改“内容接线”，没有改 settings 面板结构，也没有新增任何新的 settings row / event。
- 这一步之后，五线谱组件的真实链路已经变成：
  - `StaffScoreFixtures` 生成 demo score
  - controller 注入 `StaffDisplayState.score`
  - `StaffDisplayState.sceneProvider` 派生 `StaffSceneProvider(score:)`
  - `StaffSceneProvider` 调 `StaffSceneBuilder`
  - `staffView` / `StaffGlyphLayer` 负责展示
- `resolvedScore` 的存在很关键：它保证了当前 UI 中 `configuration.clef` 仍然是显示真相来源，后续即使用户切换 clef，也不会因为 fixture 里残留旧 clef 而出现 provider / score 不一致。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
   - `NoteMaster_Ver_1/Shared/Staff/StaffScoreFixtures.swift`
   - `NoteMaster_Ver_1/Shared/Controls/StaffDisplayState.swift`
   - `NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift`
   - `NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift`
2. 执行以下静态校验通过：
   - `xcrun swiftc -typecheck NoteMaster_Ver_1/Shared/Fretboard/*.swift NoteMaster_Ver_1/Shared/Controls/*.swift NoteMaster_Ver_1/Shared/Staff/*.swift NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift NoteMaster_Ver_1/Platform/iOS/Controls/*.swift NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift NoteMaster_Ver_1/Platform/macOS/Controls/*.swift`
3. 当前仍未覆盖的运行态验证点：
   - 还未做 iOS / macOS 实机或模拟器的五线谱显示联调
   - 还未验证切换 clef 后，demo note 是否按新 clef 正确重新布局
   - 还未补共享层自动化 fixture 验证器

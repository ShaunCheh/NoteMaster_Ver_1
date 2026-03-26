# 20260326_113007_phase5_staff_validation_runner_and_debug_hook

- 时间戳来源：系统命令 `date +%Y%m%d_%H%M%S`，结果为 `20260326_113007`
- 记录范围：`五线谱音符渲染` 的阶段 5 实施
- 本次目标：补共享层验证器与启动期 debug 报告，为 `StaffScore -> StaffSceneBuilder -> StaffScene -> Renderer` 链路建立回归护栏
- 根因结论：阶段 4 已经把 demo score 接进了渲染链路，但还缺少共享层 fixture、语义级自动校验、以及 iOS / macOS 启动期的 fail-fast 报告入口
- 本次实际改动：
- 新增 `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- 修改 `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- 修改 `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`

## 本次完成的修改

1. 新增 `StaffValidationPlatform`、`StaffValidationIssue`、`StaffValidationReport`、`StaffValidationRunner`，对齐 `FretboardValidation` 的共享层验证结构。
2. 用 4 个 fixture 覆盖 `treble` / `bass`、升降号、stem、上下加线场景。
3. 把 `scene` 中与 note 渲染强相关的不变量变成自动断言，包括 `clef`、`notehead`、`accidental`、`stem`、`ledger line` 的数量与几何语义。
4. 给 staff 验证器补了平台相关的手工回归清单，明确 iOS / macOS 运行态仍需观察的点。
5. 在 iOS / macOS App 启动入口接入 `StaffValidationRunner.runAndReportIfNeeded(platform:)`，让 Debug 模式可以自动打印摘要并在失败时直接断言。

## 修改 1：新增共享层验证器 `StaffValidation.swift`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: 文件级（此前不存在）
// 功能说明: 修改前 Shared/Staff 下还没有任何 staff 自动验证器；
// 阶段 4 虽然已经能渲染 demo notes，但没有 fixture、没有自动化断言，也没有统一的 debugSummary / 手工回归清单。
// 修改前: 文件不存在。
```

### 修改后：报告模型与 debug 入口

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationPlatform / StaffValidationIssue / StaffValidationReport.debugSummary() / StaffValidationRunner.runAndReportIfNeeded(platform:)
// 功能说明: 修改后 Shared/Staff 新增与 FretboardValidation 对齐的验证报告模型；
// Debug 启动时会输出 PASS/FAIL 摘要，并在失败时 assertionFailure，避免五线谱语义回归被静默带入运行态。
enum StaffValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct StaffValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct StaffValidationReport {
    var platform: StaffValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [StaffValidationIssue]
    var manualChecklist: [String]

    var isPassing: Bool {
        issues.isEmpty
    }

    func debugSummary() -> String {
        let automatedStatus = isPassing ? "PASS" : "FAIL"
        let passedFixturesText = passedFixtureNames.isEmpty
            ? "无"
            : passedFixtureNames.joined(separator: ", ")
        let issuesText = issues.isEmpty
            ? "- 无"
            : issues.map { "- [\($0.fixtureName)] \($0.message)" }.joined(separator: "\n")
        let checklistText = manualChecklist.enumerated().map {
            "\($0.offset + 1). \($0.element)"
        }.joined(separator: "\n")

        return """
        [StaffValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum StaffValidationRunner {
    static func run(platform: StaffValidationPlatform) -> StaffValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [StaffValidationIssue] = []

        for fixture in fixtures {
            let fixtureIssues = validate(fixture)
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        return StaffValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: StaffValidationPlatform) {
        #if DEBUG
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)

        if !report.isPassing {
            assertionFailure(summary)
        }
        #endif
    }
}
```

### 修改后：fixture 与场景输入

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: StaffValidationFixture / makeFixtures() / fixtureBounds(configuration:extraVerticalSpaces:) / score(clef:notes:)
// 功能说明: 修改后 validation runner 不直接硬编码 scene，而是先构建 fixture；
// fixture 同时收口 configuration、score、bounds 与 ledger line 期望值，从而覆盖 treble / bass、升降号和上下加线场景。
private struct StaffValidationFixture {
    var name: String
    var configuration: StaffConfiguration
    var score: StaffScore
    var bounds: CGRect
    var expectedLedgerLineCount: Int
}

private extension StaffValidationRunner {
    static let tolerance: CGFloat = 0.001
    static let fixtureWidth: CGFloat = 860

    static func makeFixtures() -> [StaffValidationFixture] {
        let trebleConfiguration = StaffConfiguration(
            clef: .treble,
            renderMode: .coreText
        )
        let bassConfiguration = StaffConfiguration(
            clef: .bass,
            renderMode: .coreText
        )

        return [
            StaffValidationFixture(
                name: "treble-default-demo",
                configuration: trebleConfiguration,
                score: StaffScoreFixtures.defaultDemo(clef: .treble),
                bounds: fixtureBounds(configuration: trebleConfiguration),
                expectedLedgerLineCount: 0
            ),
            StaffValidationFixture(
                name: "bass-ascending-reference",
                configuration: bassConfiguration,
                score: score(
                    clef: .bass,
                    notes: [
                        ("g2", .quarter),
                        ("a2", .quarter),
                        ("bb2", .quarter),
                        ("c3", .half),
                        ("d3", .quarter),
                        ("e3", .quarter),
                        ("f3", .half),
                        ("a3", .whole)
                    ]
                ),
                bounds: fixtureBounds(configuration: bassConfiguration),
                expectedLedgerLineCount: 0
            ),
            StaffValidationFixture(
                name: "treble-ledger-both-sides",
                configuration: trebleConfiguration,
                score: score(
                    clef: .treble,
                    notes: [
                        ("c4", .quarter),
                        ("a5", .quarter),
                        ("c6", .half)
                    ]
                ),
                bounds: fixtureBounds(
                    configuration: trebleConfiguration,
                    extraVerticalSpaces: 8
                ),
                expectedLedgerLineCount: 4
            ),
            StaffValidationFixture(
                name: "bass-ledger-both-sides",
                configuration: bassConfiguration,
                score: score(
                    clef: .bass,
                    notes: [
                        ("e2", .quarter),
                        ("c4", .quarter),
                        ("e4", .half)
                    ]
                ),
                bounds: fixtureBounds(
                    configuration: bassConfiguration,
                    extraVerticalSpaces: 8
                ),
                expectedLedgerLineCount: 4
            )
        ]
    }

    static func fixtureBounds(
        configuration: StaffConfiguration,
        extraVerticalSpaces: CGFloat = 0
    ) -> CGRect {
        let extraHeight = configuration.layoutMetrics.normalizedStaffSpaceHeight * extraVerticalSpaces
        return CGRect(
            origin: .zero,
            size: CGSize(
                width: fixtureWidth,
                height: configuration.preferredHeight + extraHeight
            )
        )
    }

    static func score(
        clef: StaffClef,
        notes: [(String, StaffNoteDuration)]
    ) -> StaffScore {
        do {
            return try StaffScoreDTO(
                clef: clefToken(clef),
                notes: notes.map {
                    StaffScoreNoteDTO(
                        pitch: $0.0,
                        duration: $0.1.rawValue
                    )
                }
            ).resolve()
        } catch {
            assertionFailure("Failed to build staff validation score: \(error)")
            return StaffScore(clef: clef, notes: [])
        }
    }
}
```

### 修改后：核心自动校验与手工回归清单

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift
// 函数/成员: validate(_:) / validateSceneCounts(...) / validateNoteheadLayout(...) / validateAccidentals(...) / validatePitchOrdering(...) / validateStrokeSemantics(...) / manualChecklist(for:)
// 功能说明: 修改后把 note 渲染链路的关键不变量都沉到共享层自动断言；
// 既验证 scene 数量和符号类型，也验证 notehead 网格对齐、升降号左右关系、音高上下行、stem / ledger line 的方向与边界。
static func validate(_ fixture: StaffValidationFixture) -> [StaffValidationIssue] {
    let geometry = StaffGeometry(
        configuration: fixture.configuration,
        bounds: fixture.bounds
    )
    let scene = StaffSceneProvider(
        clef: fixture.configuration.clef,
        score: fixture.score
    ).makeScene(geometry: geometry)
    var issues: [StaffValidationIssue] = []

    func record(_ message: String) {
        issues.append(
            StaffValidationIssue(
                fixtureName: fixture.name,
                message: message
            )
        )
    }

    guard !geometry.drawingRect.isNull, !geometry.drawingRect.isEmpty else {
        record("geometry.drawingRect 为空，未生成有效几何。")
        return issues
    }

    validateSceneCounts(scene: scene, geometry: geometry, fixture: fixture, record: record)
    validateNoteheadLayout(scene: scene, geometry: geometry, fixture: fixture, record: record)
    validateAccidentals(scene: scene, fixture: fixture, record: record)
    validatePitchOrdering(scene: scene, fixture: fixture, record: record)
    validateStrokeSemantics(scene: scene, fixture: fixture, record: record)
    return issues
}

static func validateSceneCounts(
    scene: StaffScene,
    geometry: StaffGeometry,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    if scene.lineSegments.count != geometry.staffLineCount {
        record("staff line 数量错误，期望 \(geometry.staffLineCount)，实际 \(scene.lineSegments.count)。")
    }

    let clefGlyphs = scene.glyphs.filter(\.symbolID.isClef)
    let noteheadGlyphs = scene.glyphs.filter(\.symbolID.isNotehead)
    let actualAccidentalCount = scene.glyphs.filter(\.symbolID.isAccidental).count
    let actualStemCount = scene.strokeItems.filter { $0.semantic == .stem }.count
    let actualLedgerLineCount = scene.strokeItems.filter { $0.semantic == .ledgerLine }.count

    // 这里分别约束 clef、notehead、accidental、stem、ledger line 的数量与类型。
    // ... 其余 record(...) 断言与当前文件一致，此处省略重复分支。
}

static func validateNoteheadLayout(
    scene: StaffScene,
    geometry: StaffGeometry,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    let noteheadGlyphs = scene.glyphs.filter(\.symbolID.isNotehead)
    let noteheadFrames = noteheadGlyphs.compactMap { frame(of: $0) }

    for (noteIndex, frame) in noteheadFrames.enumerated() {
        if frame.minX <= geometry.clefAreaRect.maxX {
            record("notehead[\(noteIndex)] 侵入 clefAreaRect。")
        }

        if let bottomLineY = geometry.bottomLineY {
            let rawStep = (bottomLineY - frame.midY) / geometry.staffStepHeight
            if !approximatelyEqual(rawStep.rounded(), rawStep) {
                record("notehead[\(noteIndex)] 未对齐到五线谱 line/space 网格。")
            }
        }
    }

    let centerXs = noteheadFrames.map(\.midX)
    if !isStrictlyIncreasing(centerXs) {
        record("notehead 的 x 位置没有按音符顺序严格递增。")
    }
}

static func validateAccidentals(
    scene: StaffScene,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    let accidentalGlyphs = scene.glyphs.filter(\.symbolID.isAccidental)
    let accidentalFrames = accidentalGlyphs.compactMap { frame(of: $0) }
    let noteheadFrames = scene.glyphs.filter(\.symbolID.isNotehead).compactMap { frame(of: $0) }

    var accidentalIndex = 0
    for (noteIndex, note) in fixture.score.notes.enumerated() where note.pitch.accidental != .natural {
        let accidentalFrame = accidentalFrames[accidentalIndex]
        let noteheadFrame = noteheadFrames[noteIndex]
        if accidentalFrame.maxX >= noteheadFrame.minX {
            record("accidental[\(accidentalIndex)] 没有落在 notehead[\(noteIndex)] 左侧。")
        }
        accidentalIndex += 1
    }
}

static func validatePitchOrdering(
    scene: StaffScene,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    let noteheadFrames = scene.glyphs.filter(\.symbolID.isNotehead).compactMap { frame(of: $0) }

    for index in 1..<fixture.score.notes.count {
        let previousPitch = fixture.score.notes[index - 1].pitch.diatonicIndex
        let currentPitch = fixture.score.notes[index].pitch.diatonicIndex
        let previousY = noteheadFrames[index - 1].midY
        let currentY = noteheadFrames[index].midY

        if currentPitch > previousPitch, !(currentY < previousY - tolerance) {
            record("音高递增时 notehead[\(index)] 没有向上移动。")
        } else if currentPitch < previousPitch, !(currentY > previousY + tolerance) {
            record("音高递减时 notehead[\(index)] 没有向下移动。")
        }
    }
}

static func validateStrokeSemantics(
    scene: StaffScene,
    fixture: StaffValidationFixture,
    record: (String) -> Void
) {
    for (index, stroke) in scene.strokeItems.enumerated() {
        switch stroke.semantic {
        case .stem:
            if !approximatelyEqual(stroke.start.x, stroke.end.x) {
                record("stem[\(index)] 不是竖线。")
            }
        case .ledgerLine:
            if !approximatelyEqual(stroke.start.y, stroke.end.y) {
                record("ledgerLine[\(index)] 不是横线。")
            }
        }
    }
}

static func manualChecklist(for platform: StaffValidationPlatform) -> [String] {
    var checklist = [
        "启动 App，确认五线谱除 clef 外还能看到 demo notehead、stem 和 accidental，且没有回退成 clef-only 场景。",
        "在 settings 中切换 Treble / Bass，确认同一组 demo notes 会按新 clef 重新布局，accidental 仍位于 notehead 左侧。",
        "观察包含高低音边界的音符，确认 ledger line 会随音符出现且与 notehead 对齐。",
        "调整窗口大小或设备方向，确认 note spacing 与 glyph 位置稳定更新，不出现 clefArea 与 noteArea 重叠。"
    ]

    switch platform {
    case .iOS:
        checklist.append("在 iOS 上验证 settings 打开/关闭与滚动共存时，五线谱内容不会闪烁或错位。")
    case .macOS:
        checklist.append("在 macOS 上执行 live resize，确认五线谱中的 notehead / stem / ledger line 在 resize 过程中保持稳定。")
    case .commandLine:
        checklist.append("命令行只覆盖共享层 scene fixture，不覆盖 iOS/macOS 运行时渲染与交互。")
    }

    return checklist
}
```

## 修改 2：iOS 启动入口接入 `StaffValidationRunner`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数/成员: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改前 iOS 启动入口只会跑 FretboardValidationRunner；
// staff 渲染链路即使发生语义回归，也不会在 Debug 启动时自动输出摘要或触发 fail-fast。
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    MusicFontRegistry.bootstrapIfNeeded()
    FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)

    let window = UIWindow(frame: UIScreen.main.bounds)
    // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
    window.overrideUserInterfaceStyle = .light
    window.rootViewController = iOSViewController()
    window.backgroundColor = .systemBackground
    window.makeKeyAndVisible()
    self.window = window
    return true
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数/成员: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改后 iOS 启动入口会并行跑 fretboard 与 staff 两套共享层验证；
// 这样五线谱 scene 的数量、几何与语义回归会在应用启动时直接暴露。
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    MusicFontRegistry.bootstrapIfNeeded()
    FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)
    StaffValidationRunner.runAndReportIfNeeded(platform: .iOS)

    let window = UIWindow(frame: UIScreen.main.bounds)
    // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
    window.overrideUserInterfaceStyle = .light
    window.rootViewController = iOSViewController()
    window.backgroundColor = .systemBackground
    window.makeKeyAndVisible()
    self.window = window
    return true
}
```

## 修改 3：macOS 启动入口对称接入 `StaffValidationRunner`

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数/成员: applicationDidFinishLaunching(_:)
// 功能说明: 修改前 macOS 启动入口与 iOS 一样，只接入了 fretboard 验证；
// staff 共享层没有任何启动期自动回归护栏。
func applicationDidFinishLaunching(_ notification: Notification) {
    MusicFontRegistry.bootstrapIfNeeded()
    FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
    // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
    NSApp.appearance = NSAppearance(named: .aqua)

    let viewController = macOSViewController()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.contentMinSize = NSSize(width: 640, height: 420)
    window.title = "NoteMaster_Ver_1"
    window.center()
    window.contentViewController = viewController
    window.makeKeyAndOrderFront(nil)
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数/成员: applicationDidFinishLaunching(_:)
// 功能说明: 修改后 macOS 启动入口同样会执行 staff 验证摘要；
// 双平台现在都能在 Debug 启动期对 note 渲染链路做自动 fail-fast。
func applicationDidFinishLaunching(_ notification: Notification) {
    MusicFontRegistry.bootstrapIfNeeded()
    FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
    StaffValidationRunner.runAndReportIfNeeded(platform: .macOS)
    // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
    NSApp.appearance = NSAppearance(named: .aqua)

    let viewController = macOSViewController()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.contentMinSize = NSSize(width: 640, height: 420)
    window.title = "NoteMaster_Ver_1"
    window.center()
    window.contentViewController = viewController
    window.makeKeyAndOrderFront(nil)
}
```

## 修改结果说明

- 阶段 5 没有改动五线谱运行时渲染算法，而是把阶段 1 到阶段 4 引入的核心语义变成共享层自动回归护栏。
- `StaffValidationRunner` 现在可以独立以 `commandLine` / `iOS` / `macOS` 三种平台上下文输出报告。
- 这一步之后，staff 链路的开发期保护变成：
- `fixture -> StaffSceneProvider(score:) -> scene 自动断言 -> debugSummary -> assertionFailure`
- 后续如果改坏了 `notehead`、`accidental`、`stem`、`ledger line`、`pitch ordering` 或 `clef` 对齐，Debug 启动时会更早暴露问题。

## 验证结果

1. `ReadLints` 检查以下文件，无新增问题：
- `NoteMaster_Ver_1/Shared/Staff/StaffValidation.swift`
- `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
- `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`
2. 执行以下静态校验通过：

```bash
# 文件路径: 项目根目录（系统命令）
# 函数/成员: xcrun swiftc -typecheck
# 功能说明: 修改后对 Shared/Fretboard、Shared/Controls、Shared/Staff 与 iOS/macOS 相关入口做静态类型校验，确认阶段 5 代码可编译。
xcrun swiftc -typecheck \
  NoteMaster_Ver_1/Shared/Fretboard/*.swift \
  NoteMaster_Ver_1/Shared/Controls/*.swift \
  NoteMaster_Ver_1/Shared/Staff/*.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSViewController.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSStaffView.swift \
  NoteMaster_Ver_1/Platform/iOS/iOSFretboardView.swift \
  NoteMaster_Ver_1/Platform/iOS/Controls/*.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSViewController.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSStaffView.swift \
  NoteMaster_Ver_1/Platform/macOS/macOSFretboardView.swift \
  NoteMaster_Ver_1/Platform/macOS/Controls/*.swift
```

3. 额外执行了共享层 command line 验证，结果为 PASS：

```bash
# 文件路径: 项目根目录（系统命令）
# 函数/成员: StaffValidationRunner.run(platform: .commandLine)
# 功能说明: 修改后通过临时命令行入口编译并执行 staff 验证器，确认 4 个 fixture 均通过。
[StaffValidation][commandLine] automated=PASS fixtures=4
通过夹具: treble-default-demo, bass-ascending-reference, treble-ledger-both-sides, bass-ledger-both-sides
自动化问题:
- 无
手工回归清单:
1. 启动 App，确认五线谱除 clef 外还能看到 demo notehead、stem 和 accidental，且没有回退成 clef-only 场景。
2. 在 settings 中切换 Treble / Bass，确认同一组 demo notes 会按新 clef 重新布局，accidental 仍位于 notehead 左侧。
3. 观察包含高低音边界的音符，确认 ledger line 会随音符出现且与 notehead 对齐。
4. 调整窗口大小或设备方向，确认 note spacing 与 glyph 位置稳定更新，不出现 clefArea 与 noteArea 重叠。
5. 命令行只覆盖共享层 scene fixture，不覆盖 iOS/macOS 运行时渲染与交互。
```

4. 当前仍未覆盖的运行态验证点：
- 还未做 iOS / macOS App 内的手工视觉回归
- 还未实际观察 settings 切换 `Treble / Bass` 时的运行态重布局效果
- 还未验证 live resize / 设备旋转下的真实字形稳定性

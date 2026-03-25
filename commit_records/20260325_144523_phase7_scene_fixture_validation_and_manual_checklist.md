# 20260325_144523_phase7_scene_fixture_validation_and_manual_checklist

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260325_144523`
- 记录范围：指板竖向 Scene 重构的阶段 7
- 本阶段目标：在没有 `Tests` target 的前提下，为指板建立可重复运行的共享层 `scene fixture` 验证器，并把双平台手工回归清单收口到统一出口

## 本阶段完成的修改

1. 新增 `FretboardValidation.swift`，集中承接共享层 fixture、自动化不变量校验、验证报告和双平台手工回归清单。
2. 在 `iOSAppDelegate` 启动入口接入 `FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)`，让调试启动时自动打印验证结果。
3. 在 `macOSAppDelegate` 启动入口接入 `FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)`，让调试启动时自动打印验证结果。
4. 实际执行了一次命令行共享夹具验证，结果为 `automated=PASS`、`fixtures=7`。

## 修改 1：新增 `FretboardValidation.swift`，把 fixture / 自动校验 / 手工清单统一收口

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: 无（文件不存在）
// 功能说明: 修改前仓库里没有可重复执行的指板共享层验证器；scene 结构、轴向规则、marker 方向、命中测试与手工回归清单都没有统一出口。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: FretboardValidationReport.debugSummary(), FretboardValidationRunner.run(platform:), runAndReportIfNeeded(platform:)
// 功能说明: 修改后共享层新增统一验证报告模型；调试启动与命令行都可以复用同一套自动化夹具与输出摘要。
enum FretboardValidationPlatform: String {
    case iOS
    case macOS
    case commandLine

    var displayName: String {
        rawValue
    }
}

struct FretboardValidationIssue: Equatable {
    var fixtureName: String
    var message: String
}

struct FretboardValidationReport {
    var platform: FretboardValidationPlatform
    var fixtureCount: Int
    var passedFixtureNames: [String]
    var issues: [FretboardValidationIssue]
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
        [FretboardValidation][\(platform.displayName)] automated=\(automatedStatus) fixtures=\(fixtureCount)
        通过夹具: \(passedFixturesText)
        自动化问题:
        \(issuesText)
        手工回归清单:
        \(checklistText)
        """
    }
}

enum FretboardValidationRunner {
    static func run(platform: FretboardValidationPlatform) -> FretboardValidationReport {
        let fixtures = makeFixtures()
        var passedFixtureNames: [String] = []
        var issues: [FretboardValidationIssue] = []

        for fixture in fixtures {
            let fixtureIssues = validate(fixture)
            if fixtureIssues.isEmpty {
                passedFixtureNames.append(fixture.name)
            } else {
                issues.append(contentsOf: fixtureIssues)
            }
        }

        return FretboardValidationReport(
            platform: platform,
            fixtureCount: fixtures.count,
            passedFixtureNames: passedFixtureNames,
            issues: issues,
            manualChecklist: manualChecklist(for: platform)
        )
    }

    static func runAndReportIfNeeded(platform: FretboardValidationPlatform) {
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

## 修改 2：在 `FretboardValidation.swift` 中定义 fixture 矩阵、几何不变量与手工回归清单

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: 无（文件不存在）
// 功能说明: 修改前不存在 shared fixture 矩阵，也没有自动校验 drawingRect / cellFrames / marker / hitTest / axis orientation 的规则。
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Fretboard/FretboardValidation.swift
// 函数/成员: makeFixtures(), validate(_:), validateBoundsContainment(...), validateSceneCounts(...), validateAxisOrientation(...), validateMarkerPlacements(...), validateHitTesting(...), manualChecklist(for:)
// 功能说明: 修改后共享层把 horizontal / vertical、guitar6 / bass4 / bass5、宽度受限 vertical 等场景固化成 fixture，并用统一规则检查几何真相与命中行为。
private extension FretboardValidationRunner {
    static let tolerance: CGFloat = 0.001
    static let horizontalFixtureWidth: CGFloat = 860
    static let verticalFixtureHeight: CGFloat = 520

    static func makeFixtures() -> [FretboardValidationFixture] {
        [
            horizontalFixture(
                name: "horizontal-guitar6-reference",
                instrument: .guitar6
            ),
            horizontalFixture(
                name: "horizontal-bass4-reference",
                instrument: .bass4
            ),
            horizontalFixture(
                name: "horizontal-bass5-reference",
                instrument: .bass5
            ),
            verticalFixture(
                name: "vertical-guitar6-height-driven",
                instrument: .guitar6
            ),
            verticalFixture(
                name: "vertical-bass4-height-driven",
                instrument: .bass4
            ),
            verticalFixture(
                name: "vertical-bass5-height-driven",
                instrument: .bass5
            ),
            verticalFixture(
                name: "vertical-guitar6-width-constrained",
                instrument: .guitar6,
                widthOverride: 220
            )
        ]
    }

    static func validate(_ fixture: FretboardValidationFixture) -> [FretboardValidationIssue] {
        let sceneBuilder = FretboardSceneBuilder(configuration: fixture.configuration)
        let scene = sceneBuilder.makeScene(bounds: fixture.bounds)
        var issues: [FretboardValidationIssue] = []

        func record(_ message: String) {
            issues.append(
                FretboardValidationIssue(
                    fixtureName: fixture.name,
                    message: message
                )
            )
        }

        guard !scene.drawingRect.isNull, !scene.drawingRect.isEmpty else {
            record("scene.drawingRect 为空，未生成有效几何。")
            return issues
        }

        validateBoundsContainment(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateSceneCounts(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateCellAndAnchorMapping(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateAxisOrientation(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateMarkerPlacements(
            scene: scene,
            fixture: fixture,
            record: record
        )
        validateHitTesting(
            scene: scene,
            fixture: fixture,
            sceneBuilder: sceneBuilder,
            record: record
        )

        return issues
    }

    static func validateAxisOrientation(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        record: (String) -> Void
    ) {
        let configuration = fixture.configuration
        let orderedStrings = scene.stringSegments.sorted { $0.stringIndex < $1.stringIndex }
        let orderedFrets = scene.fretSegments.sorted { $0.fret < $1.fret }

        switch configuration.displayMode {
        case .horizontal:
            // horizontal: 弦应为横线，品位应为竖线，弦沿 y 轴递增，品位沿 x 轴递增。
            if !isStrictlyIncreasing(orderedStrings.map { midpoint(of: $0).y }) {
                record("horizontal 模式下弦序没有按低音到高音沿 y 轴递增。")
            }
            if !isStrictlyIncreasing(orderedFrets.map(\.start.x)) {
                record("horizontal 模式下品位没有沿 x 轴递增。")
            }
        case .vertical:
            // vertical: 弦应为竖线，品位应为横线，弦沿 x 轴递增，品位沿 y 轴递增。
            if !isStrictlyIncreasing(orderedStrings.map { midpoint(of: $0).x }) {
                record("vertical 模式下弦序没有按低音到高音沿 x 轴递增。")
            }
            if !isStrictlyIncreasing(orderedFrets.map(\.start.y)) {
                record("vertical 模式下品位没有沿 y 轴递增。")
            }
        }
    }

    static func validateHitTesting(
        scene: FretboardScene,
        fixture: FretboardValidationFixture,
        sceneBuilder: FretboardSceneBuilder,
        record: (String) -> Void
    ) {
        for anchor in scene.labelAnchors {
            let hit = sceneBuilder.hitTest(
                anchor.center,
                phase: .began,
                scene: scene
            )
            let expectedCell = FretboardCell(
                stringIndex: anchor.stringIndex,
                fret: anchor.fret
            )

            if hit.cell != expectedCell {
                record("命中测试未命中中心点 (\(anchor.stringIndex), \(anchor.fret))，实际 \(String(describing: hit.cell))。")
            }
        }

        let outsidePoint = CGPoint(
            x: scene.drawingRect.minX - 1,
            y: scene.drawingRect.minY - 1
        )
        let outsideHit = sceneBuilder.hitTest(
            outsidePoint,
            phase: .began,
            scene: scene
        )
        if outsideHit.cell != nil || outsideHit.isInsideDrawingRect {
            record("drawingRect 外部点仍然命中了有效格子。")
        }
    }

    static func manualChecklist(for platform: FretboardValidationPlatform) -> [String] {
        var checklist = [
            "切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。",
            "点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。",
            "在 vertical 模式下改变窗口或设备高度，确认指板宽度会自适应变化并保持水平居中。"
        ]

        switch platform {
        case .iOS:
            checklist.append("在 iOS 上同时验证滚动与点击：轻点/短拖动仍命中，纵向拖动可平滑接管 scroll view。")
        case .macOS:
            checklist.append("在 macOS 上执行 live resize，确认 vertical 模式不闪烁，指板在 resize 过程中保持居中且命中仍正常。")
        case .commandLine:
            checklist.append("命令行只能覆盖共享层自动化夹具；iOS 滚动与 macOS live resize 需在 App 运行时手工回归。")
        }

        return checklist
    }
}
```

## 修改 3：在 `iOSAppDelegate` 启动入口接入验证器

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数/成员: iOSAppDelegate.application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改前 iOS 入口只负责 bootstrap music font 与创建 window，调试启动时不会自动跑指板共享验证。
final class iOSAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MusicFontRegistry.bootstrapIfNeeded()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = iOSViewController()
        window.backgroundColor = .systemBackground
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数/成员: iOSAppDelegate.application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改后 iOS 调试启动会先执行共享层指板验证，并把 PASS/FAIL 报告打印到控制台；失败时会在 DEBUG 下直接暴露。
final class iOSAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MusicFontRegistry.bootstrapIfNeeded()
        FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = iOSViewController()
        window.backgroundColor = .systemBackground
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
```

## 修改 4：在 `macOSAppDelegate` 启动入口接入验证器

### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数/成员: macOSAppDelegate.applicationDidFinishLaunching(_:)
// 功能说明: 修改前 macOS 入口同样不会在调试启动时自动跑指板共享验证，只负责 bootstrap 与创建窗口。
final class macOSAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MusicFontRegistry.bootstrapIfNeeded()
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
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
```

### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数/成员: macOSAppDelegate.applicationDidFinishLaunching(_:)
// 功能说明: 修改后 macOS 调试启动会自动执行同一套共享层指板验证，并把手工回归清单与自动化结果打印到控制台。
final class macOSAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MusicFontRegistry.bootstrapIfNeeded()
        FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
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
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
```

## 验证情况

1. 已检查本阶段涉及文件的 IDE diagnostics：无新增报错。
2. 已执行 `swiftc -typecheck` 覆盖当前 `NoteMaster_Ver_1` 下全部 Swift 源文件：通过。
3. 已实际执行一次共享层命令行夹具验证，输出摘要如下：

```shell
# 命令: 临时编译并执行共享层 FretboardValidationRunner
# 功能说明: 不依赖 Tests target，直接验证 scene fixture 的自动化结果与手工回归清单生成是否正常。
swiftc Shared/Fretboard/FretboardDisplayMode.swift \
       Shared/Fretboard/InstrumentType.swift \
       Shared/Fretboard/NotePitch.swift \
       Shared/Fretboard/InstrumentTuning.swift \
       Shared/Fretboard/FretboardConfiguration.swift \
       Shared/Fretboard/FretboardInteraction.swift \
       Shared/Fretboard/FretboardScene.swift \
       Shared/Fretboard/FretboardGeometryStrategy.swift \
       Shared/Fretboard/HorizontalFretboardGeometryStrategy.swift \
       Shared/Fretboard/VerticalFretboardGeometryStrategy.swift \
       Shared/Fretboard/FretboardSceneBuilder.swift \
       Shared/Fretboard/FretboardValidation.swift \
       /tmp/main.swift \
       -o /tmp/fretboard_validation_runner && /tmp/fretboard_validation_runner

[FretboardValidation][commandLine] automated=PASS fixtures=7
通过夹具: horizontal-guitar6-reference, horizontal-bass4-reference, horizontal-bass5-reference, vertical-guitar6-height-driven, vertical-bass4-height-driven, vertical-bass5-height-driven, vertical-guitar6-width-constrained
自动化问题:
- 无
手工回归清单:
1. 切换 Guitar 6 / Bass 4 / Bass 5，并在 Horizontal / Vertical 之间切换；确认 horizontal 视觉回归不变，vertical 为“左低右高、上空弦下高品、文字正立”。
2. 点击空弦区与普通品位区，确认控制台输出的 string / fret 与可见格子一致。
3. 在 vertical 模式下改变窗口或设备高度，确认指板宽度会自适应变化并保持水平居中。
4. 命令行只能覆盖共享层自动化夹具；iOS 滚动与 macOS live resize 需在 App 运行时手工回归。
```

4. 当前环境仍未执行真实的 iOS / macOS App 交互式手工回归，因为缺完整 Xcode toolchain；本阶段已把对应 checklist 收口到代码与调试启动输出，便于你本地运行 App 时按同一套矩阵验证。


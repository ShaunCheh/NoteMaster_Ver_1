# 20260331_142208_settings_navigation_phase2_shared_validation_hook

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_142208`
- 记录范围：实施“卡片内设置导航改造”的阶段 2，共享导航投影校验与启动挂接
- 修改性质：新增共享 navigation validation runner，并把它接入 iOS/macOS 启动校验链
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
  - `NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift`
  - `NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift`

## 修改前

- `SettingsNavigationModel` 只有基础的 `rootRoute/pages/page(for:)` 能力，还没有统一的 route fallback 规则。
- 项目里还没有独立的 `SettingsNavigationValidationRunner`。
- `iOSAppDelegate` 和 `macOSAppDelegate` 启动时只跑了 `FretboardValidationRunner` 与 `StaffValidationRunner`，不会自动校验 settings navigation projection。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: page(for:)
// 功能说明: 修改前共享导航模型只支持查询 page，
// 但还没有“当前深层 route 失效时如何退回父级”的统一契约。
struct SettingsNavigationModel: Equatable, Sendable {
    var rootRoute: SettingsRouteID
    var pages: [SettingsRouteID: SettingsPageModel]

    static let empty = SettingsNavigationModel(
        rootRoute: .root,
        pages: [
            .root: SettingsPageModel(
                id: .root,
                title: SettingsRouteID.root.fallbackTitle,
                content: .index([])
            )
        ]
    )

    var rootPage: SettingsPageModel? {
        page(for: rootRoute)
    }

    func page(for route: SettingsRouteID) -> SettingsPageModel? {
        pages[route]
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/符号: 文件级新增
// 功能说明: 修改前该文件不存在，项目里没有独立的 settings navigation validation runner。
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 修改前 iOS 启动链只跑 fretboard/staff validation，
// settings navigation projection 还没有被纳入自动校验。
print("[Startup][iOSApp] run fretboard validation")
FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run staff validation")
StaffValidationRunner.runAndReportIfNeeded(platform: .iOS)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 修改前 macOS 启动链同样没有 settings navigation validation。
print("[Startup][macOSApp] run fretboard validation")
FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run staff validation")
StaffValidationRunner.runAndReportIfNeeded(platform: .macOS)
```

## 修改后

- 在 `SettingsNavigationModel` 里新增了 `reconciledPath(_:)` 和 `normalizedCandidatePath(_:)`，把 route fallback 规则收口到共享层。
- 新增独立文件 `SettingsNavigationValidation.swift`，沿用现有 validation runner 风格，专门校验共享 navigation projection。
- 在 `iOSAppDelegate` / `macOSAppDelegate` 中把 `SettingsNavigationValidationRunner.runAndReportIfNeeded(...)` 接到了启动链里。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: reconciledPath(_:)
// 功能说明: 新增共享 route 回退规则；
// 当请求路径里的深层 route 当前不存在时，统一退回最近仍有效的父级，最后兜底 root。
func reconciledPath(_ preferredPath: [SettingsRouteID]) -> [SettingsRouteID] {
    let candidatePath = normalizedCandidatePath(preferredPath)
    var reconciledPath: [SettingsRouteID] = [rootRoute]

    for route in candidatePath.dropFirst() {
        guard page(for: route) != nil else {
            break
        }

        if reconciledPath.last != route {
            reconciledPath.append(route)
        }
    }

    return reconciledPath
}

// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: normalizedCandidatePath(_:)
// 功能说明: 新增路径规范化逻辑；
// 负责补 root、去重重复 route，并保证 root 始终在首位。
private func normalizedCandidatePath(
    _ preferredPath: [SettingsRouteID]
) -> [SettingsRouteID] {
    guard !preferredPath.isEmpty else {
        return [rootRoute]
    }

    var normalizedPath: [SettingsRouteID] = []

    for route in preferredPath {
        if normalizedPath.last != route {
            normalizedPath.append(route)
        }
    }

    if normalizedPath.first == rootRoute {
        return normalizedPath
    }

    return [rootRoute] + normalizedPath.filter { $0 != rootRoute }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: runAndReportIfNeeded(platform:)
// 功能说明: 新增独立 navigation validation runner，
// 沿用现有 DEBUG 启动校验模式，在失败时输出摘要并触发 assertionFailure。
enum SettingsNavigationValidationRunner {
    static func runAndReportIfNeeded(platform: SettingsNavigationValidationPlatform) {
        #if DEBUG
        print(
            "[SettingsNavigationValidation][\\(platform.displayName)] runAndReportIfNeeded begin"
        )
        let report = run(platform: platform)
        let summary = report.debugSummary()
        print(summary)
        print(
            "[SettingsNavigationValidation][\\(platform.displayName)] runAndReportIfNeeded end passing=\\(report.isPassing)"
        )

        if !report.isPassing {
            assertionFailure(summary)
        }
        #endif
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures()
// 功能说明: 新增共享 navigation projection 的自动化夹具，
// 当前覆盖 root 顺序、section detail 包裹、positionPrompt 启动态、Layout route 显隐、route fallback、预留 route 标题稳定性。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "root_route_items_match_panel_sections",
            validate: validateRootRouteItemsMatchPanelSections
        ),
        SettingsNavigationValidationFixture(
            name: "section_routes_wrap_single_section_pages",
            validate: validateSectionRoutesWrapSingleSectionPages
        ),
        SettingsNavigationValidationFixture(
            name: "position_prompt_context_keeps_trainer_section_projection",
            validate: validatePositionPromptContextKeepsTrainerSectionProjection
        ),
        SettingsNavigationValidationFixture(
            name: "layout_route_visibility_tracks_display_mode",
            validate: validateLayoutRouteVisibilityTracksDisplayMode
        ),
        SettingsNavigationValidationFixture(
            name: "reconciled_path_falls_back_to_existing_parent",
            validate: validateReconciledPathFallsBackToExistingParent
        ),
        SettingsNavigationValidationFixture(
            name: "reserved_route_titles_remain_stable",
            validate: validateReservedRouteTitlesRemainStable
        )
    ]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/iOS/iOSAppDelegate.swift
// 函数名: application(_:didFinishLaunchingWithOptions:)
// 功能说明: 把 settings navigation validation 接入 iOS 启动校验链，
// 让共享页面树投影在启动时就被验证。
print("[Startup][iOSApp] run fretboard validation")
FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run staff validation")
StaffValidationRunner.runAndReportIfNeeded(platform: .iOS)
print("[Startup][iOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .iOS)
```

```swift
// 文件路径: NoteMaster_Ver_1/Platform/macOS/macOSAppDelegate.swift
// 函数名: applicationDidFinishLaunching(_:)
// 功能说明: 把 settings navigation validation 接入 macOS 启动校验链，
// 保证双平台都会在启动时跑同一套共享导航投影验证。
print("[Startup][macOSApp] run fretboard validation")
FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run staff validation")
StaffValidationRunner.runAndReportIfNeeded(platform: .macOS)
print("[Startup][macOSApp] run settings navigation validation")
SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .macOS)
```

## 当前 validation 覆盖范围

- `root_route_items_match_panel_sections`
- `section_routes_wrap_single_section_pages`
- `position_prompt_context_keeps_trainer_section_projection`
- `layout_route_visibility_tracks_display_mode`
- `reconciled_path_falls_back_to_existing_parent`
- `reserved_route_titles_remain_stable`

## 本次明确没有改动的部分

- 没有修改 `SettingsNavigationSnapshotBuilder`
- 没有修改 `SettingsPanelEvent`
- 没有修改 `SettingsPanelStateContext`
- 没有修改任何 `iOS/macOS` settings card UI
- 没有开始实现 navigator 壳层

## 验证

```bash
// 文件路径: NoteMaster_Ver_1.xcodeproj
// 函数名/场景: 阶段2 macOS 工程级验证
// 功能说明: 使用完整 Xcode 构建 macOS 目标，确认共享 validation 与启动挂接编译通过。
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" \
-scheme "NoteMaster_Ver_1" \
-configuration Debug \
-destination "generic/platform=macOS" \
CODE_SIGNING_ALLOWED=NO build

// 结果: Exit code 0
```

```bash
// 文件路径: NoteMaster_Ver_1.xcodeproj
// 函数名/场景: 阶段2 iOS 工程级验证
// 功能说明: 使用完整 Xcode 构建 iOS 目标，确认共享 validation 与启动挂接在 iOS 侧同样通过。
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" \
-scheme "NoteMaster_Ver_1" \
-configuration Debug \
-destination "generic/platform=iOS" \
CODE_SIGNING_ALLOWED=NO build

// 结果: Exit code 0
```

```text
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名/场景: IDE 诊断检查
// 功能说明: 检查阶段2新增/修改文件是否有静态诊断问题。
ReadLints 结果：No linter errors found.
```

## 结论

- 阶段 2 的重点不是 UI，而是把“settings navigation 的共享投影正确性”纳入自动校验。
- 修改后，route fallback 规则已经不再分散在未来平台层里，而是提前收口在 `SettingsNavigationModel`。
- 同时，iOS/macOS 启动链都已经接入这套 validation，为后续阶段 3/4 的 card 内 navigator 改造提供了共享护栏。

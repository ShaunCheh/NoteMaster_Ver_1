# 20260331_141124_settings_navigation_phase1_shared_route_projection

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_141124`
- 记录范围：实施“卡片内设置导航改造”的阶段 1，共享导航模型落地
- 修改性质：新增共享层 route/page 投影能力；不改现有 UI 壳层，不改控制器接线
- 涉及文件：
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`

## 修改前

- 共享层原先只有 `SettingsPanelStateContext -> SettingsPanelSnapshotBuilder -> SettingsPanelModel` 这一条投影链路。
- 也就是说，设置系统只有 `section / row` 结构，没有共享的 `route / page / navigation` 抽象。
- 如果后续 `iOS` / `macOS` 要做卡片内导航，平台层只能各自从 `panelModel.sections` 再推导页面树，存在漂移风险。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsPanelSnapshotBuilder.swift
// 函数名: makeModel(from:)
// 功能说明: 修改前共享层的设置投影终点只有 SettingsPanelModel；
// 这里能稳定产出 section/row，但还没有 root page / detail page / route 树。
enum SettingsPanelSnapshotBuilder {
    static func makeModel(
        from stateContext: SettingsPanelStateContext
    ) -> SettingsPanelModel {
        SettingsPanelModel(
            sections: SettingsSectionID.allCases.compactMap {
                makeSection(
                    id: $0,
                    stateContext: stateContext
                )
            }
        )
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名/符号: 文件级新增
// 功能说明: 修改前该文件不存在，共享层没有 route/page/content 模型。
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名/符号: 文件级新增
// 功能说明: 修改前该文件不存在，也没有把 SettingsPanelModel 投影为 root->section 页面树的 builder。
```

## 修改后

- 新增 `SettingsRouteID`、`SettingsRouteItem`、`SettingsPageContent`、`SettingsPageModel`、`SettingsNavigationModel`。
- 第一版先只落地 `root` 与 `section(SettingsSectionID)`，同时预留深层 route：
  - `trainerPositionFilter`
  - `pianoAdvanced`
- 新增 `SettingsNavigationSnapshotBuilder`，先复用现有 `SettingsPanelSnapshotBuilder`，再把 `panelModel.sections` 投影为：
  - `root` 页：section 入口列表
  - `section` 页：单个 `SettingsSection` 的 form page
- `root` 页顺序严格跟随 `panelModel.sections`，没有把排序逻辑分散到平台层。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名/符号: SettingsRouteID / SettingsPageContent / SettingsNavigationModel
// 功能说明: 新增共享导航模型，给后续 iOS/macOS 卡片内 navigator 提供统一的页面树输入。
enum SettingsRouteID: Equatable, Hashable, Sendable {
    case root
    case section(SettingsSectionID)
    case trainerPositionFilter
    case pianoAdvanced

    var fallbackTitle: String {
        switch self {
        case .root:
            return "Settings"
        case let .section(sectionID):
            return sectionID.title
        case .trainerPositionFilter:
            return "Position Filter"
        case .pianoAdvanced:
            return "Advanced"
        }
    }
}

enum SettingsPageContent: Equatable, Sendable {
    case index([SettingsRouteItem])
    case form([SettingsSection])
}

struct SettingsNavigationModel: Equatable, Sendable {
    var rootRoute: SettingsRouteID
    var pages: [SettingsRouteID: SettingsPageModel]
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名/符号: SettingsPageModel.panelModel
// 功能说明: 新增 form page -> SettingsPanelModel 的适配出口，
// 后续 detail page 可以继续复用现有 SettingsPanelView，而不用重写 row/section 渲染层。
struct SettingsPageModel: Equatable, Sendable {
    var id: SettingsRouteID
    var title: String
    var content: SettingsPageContent

    var panelModel: SettingsPanelModel? {
        guard let sections = content.sections else {
            return nil
        }

        return SettingsPanelModel(sections: sections)
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: makeModel(from:)
// 功能说明: 新增导航快照构建器；先复用现有 panel snapshot，
// 再稳定投影出 root 页和单 section detail page。
enum SettingsNavigationSnapshotBuilder {
    static func makeModel(
        from stateContext: SettingsPanelStateContext
    ) -> SettingsNavigationModel {
        makeModel(
            from: SettingsPanelSnapshotBuilder.makeModel(
                from: stateContext
            )
        )
    }

    static func makeModel(
        from panelModel: SettingsPanelModel
    ) -> SettingsNavigationModel {
        var pages: [SettingsRouteID: SettingsPageModel] = [
            .root: SettingsPageModel(
                id: .root,
                title: SettingsRouteID.root.fallbackTitle,
                // root 页顺序必须与 panelModel.sections 一致，
                // 这样平台层无需再重复排序或推断分组。
                content: .index(
                    panelModel.sections.map(makeRootRouteItem(for:))
                )
            )
        ]

        for section in panelModel.sections {
            let route = SettingsRouteID.section(section.id)
            pages[route] = SettingsPageModel(
                id: route,
                title: section.title,
                content: .form([section])
            )
        }

        return SettingsNavigationModel(
            rootRoute: .root,
            pages: pages
        )
    }
}
```

## 本次明确没有改动的部分

- 没有修改 `SettingsPanelEvent`
- 没有修改 `SettingsPanelStateContext`
- 没有修改 `SettingsPanelSnapshotBuilder`
- 没有修改 `iOSSettingsContainerView` / `macOSSettingsContainerView`
- 没有修改 `iOSViewController` / `macOSViewController`
- 没有接入 validation runner
- 没有新增任何平台 UI 行为

## 验证

```bash
# 文件路径: commit_records/20260331_141124_settings_navigation_phase1_shared_route_projection.md
# 函数名/场景: 文件名时间戳来源
# 功能说明: 使用系统自带 date 命令获取当前记录文件的时间戳前缀。
date +"%Y%m%d_%H%M%S"
# 输出: 20260331_141124
```

```bash
# 文件路径: NoteMaster_Ver_1.xcodeproj
# 函数名/场景: 阶段1工程级验证
# 功能说明: 使用完整 Xcode 的 DEVELOPER_DIR 临时构建 macOS 目标，
# 验证新增共享层文件已经被工程识别并通过编译。
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
xcodebuild -project "NoteMaster_Ver_1.xcodeproj" \
-scheme "NoteMaster_Ver_1" \
-configuration Debug \
-destination "generic/platform=macOS" \
CODE_SIGNING_ALLOWED=NO build

# 结果: Exit code 0
```

- `ReadLints` 检查：
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift`
  - `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- 结果：`No linter errors found.`

## 结论

- 这次阶段 1 的落点是：先把“共享页面树”建出来，而不是直接改平台层 UI。
- 修改前，项目只有 `SettingsPanelModel`；修改后，项目已经具备共享的 `SettingsNavigationModel` 与 `root -> section` 页面树投影能力。
- 这样后续阶段做 `iOS/macOS` 卡片内导航时，可以直接消费统一 route/page 模型，避免两端各自硬编码页面结构。

# 20260331_150301_settings_navigation_phase5_deep_route_splitting

- 时间戳来源：系统命令 `date +"%Y%m%d_%H%M%S"`，结果为 `20260331_150301`
- 记录范围：实施“卡片内设置导航改造”的阶段 5，完成深层页拆分重区
- 修改性质：把 `Trainer / Staff / Piano` 从“单个 section form 页”推进为“共享 builder 决定的 section index + child form page”，并同步更新共享 validation 契约
- 涉及文件：
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`

## 修改前

- 共享 route 层虽然已经预留了 `trainerPositionFilter` 与 `pianoAdvanced`，但这些 route 还没有真正被 `SettingsNavigationSnapshotBuilder` 生成。
- `SettingsNavigationSnapshotBuilder.makeModel(from:)` 对所有 section 都一律生成 `.form([section])`，也就是说 `Trainer / Staff / Piano` 即使已经越来越臃肿，仍然只能停留在单页表单里。
- validation 仍然以“所有 section route 都包单个 section form page”为前提，只验证单页投影，没有验证真正的子页树、动态 route 显隐和深层回退。

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: SettingsRouteID
// 功能说明: 修改前共享 route 只保留了极少数预留深层 route；
// 但还没有把 Trainer / Staff / Piano 真正拆成稳定可用的子页结构。
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: makeModel(from panelModel:)
// 功能说明: 修改前 builder 对每个 section 都直接生成 form page，
// 不会进一步把 row 拆成二级页或三级页。
static func makeModel(
    from panelModel: SettingsPanelModel
) -> SettingsNavigationModel {
    var pages: [SettingsRouteID: SettingsPageModel] = [
        .root: SettingsPageModel(
            id: .root,
            title: SettingsRouteID.root.fallbackTitle,
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
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures() / validateSectionRoutesWrapSingleSectionPages()
// 功能说明: 修改前 validation 仍然假设所有 section route 都是单页 form；
// 因此无法约束深层 route 的出现、消失、顺序和回退行为。
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
        )
    ]
}

static func validateSectionRoutesWrapSingleSectionPages()
    -> [SettingsNavigationValidationIssue] {
    for section in panelModel.sections {
        let route = SettingsRouteID.section(section.id)
        guard let page = navigationModel.page(for: route) else {
            continue
        }

        guard let sections = page.content.sections else {
            continue
        }

        if sections != [section] {
            issues.append(
                issue(fixtureName, "\(section.title) page 应只承载单个且原样的 section。")
            )
        }
    }
}
```

## 修改后

- `SettingsRouteID` 补齐了真正落地的子页 route：
- `Trainer`：`trainerExercise`、`trainerPositionFilter`
- `Staff`：`staffClef`、`staffLayout`
- `Piano`：`pianoBehavior`、`pianoAppearance`
- `SettingsNavigationSnapshotBuilder` 不再对 section 一刀切，而是先看当前 section 的实际可见 row，再决定：
- 如果该 section 没有配置 child page spec，继续保留单页 form
- 如果只有 1 个 child group 实际有内容，回退为单页 form，避免多套一层无意义导航
- 只有当 child groups 数量大于 1 且覆盖了该 section 的全部可见 rows 时，才生成 section index page + child form pages
- 这样深层 route 的显隐完全依赖共享层最终投影出来的 rows，而不是平台层重复 hardcode 条件。
- `SettingsNavigationValidation` 同步升级为“页面树契约测试”，开始验证：
- 哪些 section 仍然应该是 form page
- 哪些 section 已经变为 index page
- child route 的顺序、标题、承载 rows 是否正确
- `positionPrompt` 与 `single` 等不同 trainer 状态下，Trainer 深层 route 是否按预期出现或消失
- 深层 route 存在时不应误回退，不存在时必须回到最近有效父级

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationModel.swift
// 函数名: SettingsRouteID
// 功能说明: 修改后共享 route 层正式补齐阶段 5 需要的深层页标识，
// 让 Trainer / Staff / Piano 的子页能够稳定出现在共享页面树中。
enum SettingsRouteID: Equatable, Hashable, Sendable {
    case root
    case section(SettingsSectionID)
    case trainerExercise
    case trainerPositionFilter
    case staffClef
    case staffLayout
    case pianoBehavior
    case pianoAppearance

    var fallbackTitle: String {
        switch self {
        case .root:
            return "Settings"
        case let .section(sectionID):
            return sectionID.title
        case .trainerExercise:
            return "Exercise"
        case .trainerPositionFilter:
            return "Position Filter"
        case .staffClef:
            return "Clef"
        case .staffLayout:
            return "Layout"
        case .pianoBehavior:
            return "Behavior"
        case .pianoAppearance:
            return "Appearance"
        }
    }

    var accessibilityIdentifierComponent: String {
        switch self {
        case .root:
            return "root"
        case let .section(sectionID):
            return "section-\(String(describing: sectionID))"
        case .trainerExercise:
            return "trainer-exercise"
        case .trainerPositionFilter:
            return "trainer-position-filter"
        case .staffClef:
            return "staff-clef"
        case .staffLayout:
            return "staff-layout"
        case .pianoBehavior:
            return "piano-behavior"
        case .pianoAppearance:
            return "piano-appearance"
        }
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: makePages(for:) / makeResolvedChildPages(for:)
// 功能说明: 修改后 builder 先解析 section 的实际 child pages，
// 只有在“子页数量大于 1 且完整覆盖当前 section 可见 rows”时才把 section 变成 index page。
private static func makePages(
    for section: SettingsSection
) -> [SettingsRouteID: SettingsPageModel] {
    let route = SettingsRouteID.section(section.id)
    let childPages = makeResolvedChildPages(for: section)

    guard childPages.count > 1 else {
        return [
            route: SettingsPageModel(
                id: route,
                title: section.title,
                content: .form([section])
            )
        ]
    }

    var pages: [SettingsRouteID: SettingsPageModel] = [
        route: SettingsPageModel(
            id: route,
            title: section.title,
            content: .index(
                childPages.map { childPage in
                    SettingsRouteItem(
                        title: childPage.title,
                        subtitle: childPage.subtitle,
                        route: childPage.route
                    )
                }
            )
        )
    ]

    for childPage in childPages {
        pages[childPage.route] = SettingsPageModel(
            id: childPage.route,
            title: childPage.title,
            content: .form([childPage.section])
        )
    }

    return pages
}

private static func makeResolvedChildPages(
    for section: SettingsSection
) -> [ResolvedChildPage] {
    guard let childPageSpecs = childPageSpecs(for: section.id) else {
        return []
    }

    let resolvedChildPages = childPageSpecs.compactMap { childPageSpec in
        resolveChildPage(
            childPageSpec,
            from: section
        )
    }

    let coveredRowIDs = Set(
        resolvedChildPages.flatMap { childPage in
            childPage.section.rows.map(\.id)
        }
    )
    let hasUncoveredRows = section.rows.contains { row in
        !coveredRowIDs.contains(row.id)
    }

    return hasUncoveredRows ? [] : resolvedChildPages
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationSnapshotBuilder.swift
// 函数名: childPageSpecs(for:)
// 功能说明: 修改后共享层明确声明了重区的拆分策略，
// 并把每个子页实际承载的 rowIDs 固定在 builder 中统一管理。
private static func childPageSpecs(
    for sectionID: SettingsSectionID
) -> [ChildPageSpec]? {
    switch sectionID {
    case .trainer:
        return [
            ChildPageSpec(
                route: .trainerExercise,
                title: SettingsRouteID.trainerExercise.fallbackTitle,
                subtitle: "Mode",
                rowIDs: [
                    .choice(.exerciseMode)
                ]
            ),
            ChildPageSpec(
                route: .trainerPositionFilter,
                title: SettingsRouteID.trainerPositionFilter.fallbackTitle,
                subtitle: "Note names or frets",
                rowIDs: [
                    .choice(.positionPromptFilterMode),
                    .positionFilter(.positionPromptFilterOptions)
                ]
            )
        ]
    case .staff:
        return [
            ChildPageSpec(
                route: .staffClef,
                title: SettingsRouteID.staffClef.fallbackTitle,
                subtitle: "Type",
                rowIDs: [
                    .choice(.clef)
                ]
            ),
            ChildPageSpec(
                route: .staffLayout,
                title: SettingsRouteID.staffLayout.fallbackTitle,
                subtitle: "Scale and trim",
                rowIDs: [
                    .slider(.clefScale),
                    .slider(.clefVerticalTrim),
                    .slider(.clefAnchorYOffset)
                ]
            )
        ]
    case .piano:
        return [
            ChildPageSpec(
                route: .pianoBehavior,
                title: SettingsRouteID.pianoBehavior.fallbackTitle,
                subtitle: "Visibility and movement",
                rowIDs: [
                    .toggle(.pianoVisible),
                    .slider(.pianoRowCount),
                    .choice(.pianoMovementScope),
                    .toggle(.pianoSnapEnabled)
                ]
            ),
            ChildPageSpec(
                route: .pianoAppearance,
                title: SettingsRouteID.pianoAppearance.fallbackTitle,
                subtitle: "Key styling",
                rowIDs: [
                    .choice(.pianoWhiteKeyStyle)
                ]
            )
        ]
    case .page, .fretboard, .layout, .debug:
        return nil
    }
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures() / validateSplitSectionsProduceExpectedPageTree()
// 功能说明: 修改后 validation 不再把“所有 section 都是 form”当作前提，
// 而是开始校验真正的页面树结构和 child route 投影。
static func makeFixtures() -> [SettingsNavigationValidationFixture] {
    [
        SettingsNavigationValidationFixture(
            name: "root_route_items_match_panel_sections",
            validate: validateRootRouteItemsMatchPanelSections
        ),
        SettingsNavigationValidationFixture(
            name: "split_sections_produce_expected_page_tree",
            validate: validateSplitSectionsProduceExpectedPageTree
        ),
        SettingsNavigationValidationFixture(
            name: "trainer_route_visibility_tracks_exercise_mode",
            validate: validateTrainerRouteVisibilityTracksExerciseMode
        )
    ]
}

static func validateSplitSectionsProduceExpectedPageTree()
    -> [SettingsNavigationValidationIssue] {
    assertFormPage(
        route: .section(.page),
        expectedTitle: pageSection.title,
        expectedSection: pageSection,
        in: navigationModel,
        fixtureName: fixtureName,
        pageDescription: "Page section",
        issues: &issues
    )

    assertIndexPage(
        route: .section(.trainer),
        expectedTitle: trainerSection.title,
        expectedRouteItems: [
            SettingsRouteItem(
                title: SettingsRouteID.trainerExercise.fallbackTitle,
                subtitle: "Mode",
                route: .trainerExercise
            ),
            SettingsRouteItem(
                title: SettingsRouteID.trainerPositionFilter.fallbackTitle,
                subtitle: "Note names or frets",
                route: .trainerPositionFilter
            )
        ],
        in: navigationModel,
        fixtureName: fixtureName,
        pageDescription: "Trainer section",
        issues: &issues
    )
}
```

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: validateTrainerRouteVisibilityTracksExerciseMode() / validateReconciledPathFallsBackToExistingParent()
// 功能说明: 修改后 validation 额外约束了动态 route 的显隐与回退；
// 例如 single 模式下 Trainer 不应继续拆子页，而 positionPrompt 模式下必须出现 Position Filter 深层页。
static func validateTrainerRouteVisibilityTracksExerciseMode()
    -> [SettingsNavigationValidationIssue] {
    let singleTrainerState = TrainerDisplayState(exerciseMode: .single)
    let singleNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: SettingsPanelStateContext(
            trainerDisplayState: singleTrainerState
        )
    )

    if singleNavigationModel.page(for: .trainerExercise) != nil {
        issues.append(
            issue(fixtureName, "只有一个 Trainer 子分组时，不应继续暴露 trainerExercise 深层页。")
        )
    }
    if singleNavigationModel.page(for: .trainerPositionFilter) != nil {
        issues.append(
            issue(fixtureName, "single 模式下不应暴露 trainerPositionFilter 深层页。")
        )
    }

    let positionPromptNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: SettingsPanelStateContext(
            pageDisplayState: .positionPrompt,
            trainerDisplayState: .default
        )
    )
    if positionPromptNavigationModel.page(for: .trainerPositionFilter) == nil {
        issues.append(
            issue(fixtureName, "position prompt 模式下应生成 trainerPositionFilter 深层页。")
        )
    }
}

static func validateReconciledPathFallsBackToExistingParent()
    -> [SettingsNavigationValidationIssue] {
    let startupNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: SettingsPanelStateContext(
            pageDisplayState: .positionPrompt,
            trainerDisplayState: .default
        )
    )

    let availableTrainerPath = startupNavigationModel.reconciledPath([
        .root,
        .section(.trainer),
        .trainerPositionFilter
    ])
    if availableTrainerPath != [.root, .section(.trainer), .trainerPositionFilter] {
        issues.append(
            issue(fixtureName, "已存在的 Trainer 深层 route 不应被错误回退。")
        )
    }

    let singleTrainerNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
        from: SettingsPanelStateContext(
            trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
        )
    )
    let singleTrainerFallbackPath = singleTrainerNavigationModel.reconciledPath([
        .root,
        .section(.trainer),
        .trainerPositionFilter
    ])
    if singleTrainerFallbackPath != [.root, .section(.trainer)] {
        issues.append(
            issue(fixtureName, "缺失的 Trainer 深层 route 应回退到最近仍有效的 Trainer 父级。")
        )
    }
}
```

## 结果归纳

- 阶段 5 完成后，`Trainer / Staff / Piano` 的信息架构不再硬塞进单个 section form 页，而是由共享 builder 基于实际可见 rows 动态拆页。
- 平台层无需增加新的条件分支，仍然只消费 `SettingsNavigationModel`，因此 iOS/macOS 的导航结构保持同步。
- 当某个重区在当前状态下只剩一个有效子分组时，builder 会自动退回单页 form，避免引入多余的中间 index 页。
- 当某个深层 route 在当前状态下确实存在时，`reconciledPath` 会保留它；当它因状态变化失效时，仍会退回最近有效父页。

## 验证结果

- `ReadLints`：本次涉及文件无新增 linter 报错
- iOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS" build`
- macOS 编译验证：
- `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`
- 当前记录覆盖的是阶段 5 的共享页面树拆分与 validation 收敛；手工点击回归与阶段 6 的无障碍/清理工作尚未开始

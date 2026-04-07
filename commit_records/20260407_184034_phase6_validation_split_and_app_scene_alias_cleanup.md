# 20260407_184034_phase6_validation_split_and_app_scene_alias_cleanup

## 记录范围

本记录只覆盖刚刚这一轮 `phase6` 的实际修改，重点是把已经稳定下来的双模式架构做结构性收尾：

- 将超大的 validation 文件按职责拆分，避免继续把所有 `validate*` 堆在一个文件里。
- 保留现有行为与现有 `Runner` API，不做新的模式语义改写。
- 收掉 `SceneCoreCompatibility` 这种过渡性命名，把仍然需要保留的 `AppScene*` alias 迁移到命名更准确的位置。

本记录参考了当前工作区的 `git diff` 与文件现状，但 **不包含原始 diff**。  
当前工作区里仍有一个用户侧已有的 `.md` 文件：

- `.cursor/plans/play模式分阶段计划_3b30e6c6.plan.md`

这个 `.md` 不属于本轮 `phase6` 的实际代码落地，因此下面不把它算进本次记录范围。

本轮涉及文件：

- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationSupport.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift`
- `NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationReservedContracts.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationHelpers.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationConfigurationAndProjection.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationInteractionAndGeometry.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationReducerAndPresentation.swift`
- `NoteMaster_Ver_1/Shared/Piano/PianoValidationKeyboardLayer.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift`
- `NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift`
- `NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift`
- `NoteMaster_Ver_1/Shared/Scene/AppSceneTypeAliases.swift`

---

## 1. `SettingsNavigationValidation` 按职责拆分

### 1.1 `SettingsNavigationValidation.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: makeFixtures() / validateRootRouteItemsMatchPanelSections() / validateSplitSectionsProduceExpectedPageTree() / resolveSection(...)
// 功能说明: 修改前这个文件既承载 Runner / Report / Fixture 注册，又承载 root tree、state 切换、保留标题、accessibility 标识符、assert helper 等所有 validate* 与辅助函数；单文件持续膨胀。
private extension SettingsNavigationValidationRunner {
    static func makeFixtures() -> [SettingsNavigationValidationFixture] {
        [
            SettingsNavigationValidationFixture(
                name: "root_route_items_match_panel_sections",
                validate: validateRootRouteItemsMatchPanelSections
            ),
            SettingsNavigationValidationFixture(
                name: "split_sections_produce_expected_page_tree",
                validate: validateSplitSectionsProduceExpectedPageTree
            )
            // ... 同文件里继续注册并实现其余所有 fixtures ...
        ]
    }

    static func validateRootRouteItemsMatchPanelSections()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "root_route_items_match_panel_sections"
        let stateContext = SettingsPanelStateContext.default
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )
        // ... 与 rootPage / panelModel.sections 对齐的断言逻辑 ...
    }

    static func resolveSection(
        _ sectionID: SettingsSectionID,
        in panelModel: SettingsPanelModel
    ) -> SettingsSection? {
        panelModel.sections.first(where: { $0.id == sectionID })
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidation.swift
// 函数名: run(platform:) / runAndReportIfNeeded(platform:) / makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后主文件只保留对外 Runner、Report、Fixture 注册和 checklist；真正的 validate* 与 helper 都被拆到按职责命名的新文件中，主文件回到“入口与装配”角色。
@MainActor
enum SettingsNavigationValidationRunner {
    static func run(
        platform: SettingsNavigationValidationPlatform
    ) -> SettingsNavigationValidationReport {
        let fixtures = makeFixtures()
        // ... 遍历 fixtures、汇总 passedFixtureNames 与 issues ...
    }
}

private extension SettingsNavigationValidationRunner {
    static func makeFixtures() -> [SettingsNavigationValidationFixture] {
        [
            SettingsNavigationValidationFixture(
                name: "root_route_items_match_panel_sections",
                validate: validateRootRouteItemsMatchPanelSections
            ),
            SettingsNavigationValidationFixture(
                name: "root_mode_switch_preserves_exercise_tree_and_state",
                validate: validateRootModeSwitchPreservesExerciseTreeAndState
            ),
            SettingsNavigationValidationFixture(
                name: "reserved_accessibility_identifiers_remain_stable",
                validate: validateReservedAccessibilityIdentifiersRemainStable
            )
        ]
    }

    static func manualChecklist(
        for platform: SettingsNavigationValidationPlatform
    ) -> [String] {
        [
            "确认切到 `play` mode 的 settings 后，root 只保留 `Mode / Piano` 分区，不再暴露 `Exercise / Accessories / Fretboard / Staff / Debug`。",
            "确认从 `exercise` 切到 `play` 再切回后，原来的 exercise mode、layout preset 和 piano rows / snap 之类的设置不会丢失。"
        ]
    }
}
```

### 1.2 `SettingsNavigationValidationSupport.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationSupport.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；assertIndexPage / assertFormPage / makeExpectedChildSection / issue / resolveSection 等辅助函数都散落在 SettingsNavigationValidation.swift 内部。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationSupport.swift
// 函数名: assertIndexPage(...) / assertFormPage(...) / makeExpectedChildSection(...) / issue(...) / resolveSection(...)
// 功能说明: 修改后把跨多个 fixture 共享的断言与 section helper 抽到单独 support 文件，避免 root/state/reserved 几组 validation 重复持有同一套工具函数。
@MainActor
extension SettingsNavigationValidationRunner {
    static func assertIndexPage(
        route: SettingsRouteID,
        expectedTitle: String,
        expectedRouteItems: [SettingsRouteItem],
        in navigationModel: SettingsNavigationModel,
        fixtureName: String,
        pageDescription: String,
        issues: inout [SettingsNavigationValidationIssue]
    ) {
        guard let page = navigationModel.page(for: route) else {
            issues.append(issue(fixtureName, "\(pageDescription) 缺少对应 page。"))
            return
        }
        // ... page.id / title / routeItems 的通用断言 ...
    }

    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> SettingsNavigationValidationIssue {
        SettingsNavigationValidationIssue(
            fixtureName: fixtureName,
            message: message
        )
    }
}
```

### 1.3 `SettingsNavigationValidationRootTree.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；root route、exercise/play root tree、expectedRootSectionIDs / expectedRootRouteItems 这组根契约逻辑仍和其它导航校验混在同一个大文件里。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationRootTree.swift
// 函数名: validateRootRouteItemsMatchPanelSections() / validateSplitSectionsProduceExpectedPageTree() / validatePlayRootTreeKeepsOnlyPianoPages() / expectedRootSectionIDs(for:) / expectedRootRouteItems(for:in:)
// 功能说明: 修改后把 root tree 相关夹具和根契约 helper 收口到同一文件；exercise / play 两种 root sections 的唯一真实来源也保留在这里，避免再出现多处复制数组后漂移。
@MainActor
extension SettingsNavigationValidationRunner {
    static func validateRootRouteItemsMatchPanelSections()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "root_route_items_match_panel_sections"
        let stateContext = SettingsPanelStateContext.default
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )
        // ... rootPage 与 panelModel.sections 顺序/标题一致性断言 ...
    }

    static func expectedRootSectionIDs(
        for rootMode: RootMode
    ) -> [SettingsSectionID] {
        switch rootMode {
        case .exercise:
            return [.mode, .exercise, .accessories, .fretboard, .staff, .piano, .debug]
        case .play:
            return [.mode, .piano]
        }
    }

    static func expectedRootRouteItems(
        for rootMode: RootMode,
        in panelModel: SettingsPanelModel
    ) -> [SettingsRouteItem] {
        expectedRootSectionIDs(for: rootMode).compactMap { sectionID in
            guard let section = resolveSection(sectionID, in: panelModel) else {
                return nil
            }
            return SettingsRouteItem(
                title: section.title,
                subtitle: nil,
                route: .section(sectionID)
            )
        }
    }
}
```

### 1.4 `SettingsNavigationValidationStateAndNavigation.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；root mode 切换、Exercise/Layout 深层 route 稳定性、reconciledPath fallback、viewport 显隐等状态与导航联动校验仍在同一个 monolith 里。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationStateAndNavigation.swift
// 函数名: validateRootModeSwitchPreservesExerciseTreeAndState() / validatePositionPromptSectionVisibilityTracksExerciseMode() / validateFretboardViewportRouteVisibilityTracksDisplayMode() / validateReconciledPathFallsBackToExistingParent()
// 功能说明: 修改后把“状态变更后页面树如何回显”的夹具独立出来，让 root mode 切换、section 可见性与导航回退契约集中维护。
@MainActor
extension SettingsNavigationValidationRunner {
    static func validateRootModeSwitchPreservesExerciseTreeAndState()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "root_mode_switch_preserves_exercise_tree_and_state"
        var exerciseStateContext = SettingsPanelStateContext.default
        SettingsPanelEvent.triggerAction(.setExerciseModeSequence).apply(
            to: &exerciseStateContext
        )
        SettingsPanelEvent.triggerAction(.setLayoutPresetSideBySide).apply(
            to: &exerciseStateContext
        )

        var playStateContext = exerciseStateContext
        SettingsPanelEvent.triggerAction(.setRootModePlay).apply(
            to: &playStateContext
        )

        var restoredExerciseStateContext = playStateContext
        SettingsPanelEvent.triggerAction(.setRootModeExercise).apply(
            to: &restoredExerciseStateContext
        )

        if restoredExerciseStateContext.exerciseLayoutPreferences.layoutPreset != .sideBySide {
            // ... 切回 exercise 后保留原状态 ...
        }
        if restoredExerciseStateContext.pianoPanelState.resolvedRowCount != 5 {
            // ... 切回 exercise 后保留 piano 行数 ...
        }
        // ... restored root tree 与深层 route 可达性断言 ...
    }
}
```

### 1.5 `SettingsNavigationValidationReservedContracts.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationReservedContracts.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；route title 与 accessibility identifier 稳定性校验只是 monolith 底部的一小组函数，不具备独立职责边界。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Controls/SettingsNavigationValidationReservedContracts.swift
// 函数名: validateReservedRouteTitlesRemainStable() / validateReservedAccessibilityIdentifiersRemainStable()
// 功能说明: 修改后把“对外文案/identifier 必须稳定”的保留契约单独成组，避免后续继续和页面树、状态切换逻辑混在一起。
@MainActor
extension SettingsNavigationValidationRunner {
    static func validateReservedRouteTitlesRemainStable()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "reserved_route_titles_remain_stable"
        var issues: [SettingsNavigationValidationIssue] = []

        if SettingsRouteID.root.fallbackTitle != "Settings" {
            issues.append(issue(fixtureName, "root fallbackTitle 应为 Settings。"))
        }
        if SettingsRouteID.pianoBehavior.fallbackTitle != "Behavior" {
            issues.append(issue(fixtureName, "pianoBehavior fallbackTitle 应为 Behavior。"))
        }
        return issues
    }

    static func validateReservedAccessibilityIdentifiersRemainStable()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "reserved_accessibility_identifiers_remain_stable"
        var issues: [SettingsNavigationValidationIssue] = []

        if SettingsNavigationAccessibility.navigatorIdentifier != "settings-navigation" {
            issues.append(issue(fixtureName, "navigatorIdentifier 应为 settings-navigation。"))
        }
        if SettingsNavigationAccessibility.pageIdentifier(for: .section(.exercise))
            != "settings-navigation-page-section-exercise" {
            issues.append(issue(fixtureName, "section(.exercise) page identifier 应保持稳定。"))
        }
        return issues
    }
}
```

---

## 2. `PianoValidation` 按职责拆分

### 2.1 `PianoValidation.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: makeFixtures() / validateConfigurationResolvesSafeMetrics() / validatePianoPanelProjectionResolution() / validateButtonPressLifecycle() / validateKeyboardLayerUsesOneRowLayerPerRow()
// 功能说明: 修改前主文件同时承载平台/报告模型、fixture 装配、配置投影、交互几何、Reducer、KeyboardLayer 等全部钢琴校验逻辑；它甚至直接引入了 CoreGraphics / QuartzCore。
import Foundation
import CoreGraphics
import QuartzCore

private extension PianoValidationRunner {
    static func makeFixtures() -> [PianoValidationFixture] {
        [
            PianoValidationFixture(
                name: "configuration_resolves_safe_metrics",
                validate: validateConfigurationResolvesSafeMetrics
            ),
            PianoValidationFixture(
                name: "button_press_lifecycle_tracks_inside_state",
                validate: validateButtonPressLifecycle
            ),
            PianoValidationFixture(
                name: "keyboard_layer_uses_one_row_layer_per_row",
                validate: validateKeyboardLayerUsesOneRowLayerPerRow
            )
        ]
    }

    static func validateConfigurationResolvesSafeMetrics() -> [PianoValidationIssue] {
        let configuration = PianoConfiguration(
            whiteKeyWidth: -8,
            rowHeight: -12,
            rowSpacing: -4,
            scaleAreaHeight: 18,
            buttonAreaWidth: -6
        )
        // ... 同文件里继续塞配置/交互/渲染各类断言 ...
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidation.swift
// 函数名: run(platform:) / runAndReportIfNeeded(platform:) / makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后主文件只保留 Runner、Report、fixture 装配和 checklist；具体 validate* 已按配置、交互、Reducer、KeyboardLayer 几组拆到独立文件，主文件不再混入图形框架依赖。
import Foundation

enum PianoValidationRunner {
    static func run(platform: PianoValidationPlatform) -> PianoValidationReport {
        let fixtures = makeFixtures()
        // ... 汇总 passedFixtureNames 与 issues ...
    }
}

private extension PianoValidationRunner {
    static func makeFixtures() -> [PianoValidationFixture] {
        [
            PianoValidationFixture(
                name: "configuration_resolves_safe_metrics",
                validate: validateConfigurationResolvesSafeMetrics
            ),
            PianoValidationFixture(
                name: "button_transition_interrupt_materializes_current_frame",
                validate: validateButtonTransitionInterruptMaterialization
            ),
            PianoValidationFixture(
                name: "keyboard_layer_flip_normalization_preserves_top_left_layout",
                validate: validateKeyboardLayerFlipNormalization
            )
        ]
    }
}
```

### 2.2 `PianoValidationHelpers.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationHelpers.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；issue(_:_:) 只是附着在 monolith 底部的一个小 helper。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationHelpers.swift
// 函数名: issue(_:_:)
// 功能说明: 修改后把所有钢琴 validation 共用的 issue 构造 helper 独立出来，减少各职责文件重复拼装 PianoValidationIssue。
extension PianoValidationRunner {
    static func issue(
        _ fixtureName: String,
        _ message: String
    ) -> PianoValidationIssue {
        PianoValidationIssue(fixtureName: fixtureName, message: message)
    }
}
```

### 2.3 `PianoValidationConfigurationAndProjection.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationConfigurationAndProjection.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；配置钳制、PianoPanelState 推断、panel projection、空 rows fallback 等逻辑都和交互/渲染夹具混在同一个大文件里。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationConfigurationAndProjection.swift
// 函数名: validateConfigurationResolvesSafeMetrics() / validatePianoPanelVisibilityDefaults() / validatePianoPanelStateInferenceAndClamp() / validatePianoPanelProjectionResolution() / validateAccidentalStartNote()
// 功能说明: 修改后把“静态配置与 projection 契约”独立成组，方便后续只在配置层变更时定位对应 validation。
extension PianoValidationRunner {
    static func validateConfigurationResolvesSafeMetrics() -> [PianoValidationIssue] {
        let fixtureName = "configuration_resolves_safe_metrics"
        let configuration = PianoConfiguration(
            whiteKeyWidth: -8,
            rowHeight: -12,
            rowSpacing: -4,
            scaleAreaHeight: 18,
            buttonAreaWidth: -6,
            blackKeyWidthRatio: 3,
            blackKeyHeightRatio: 0.05,
            snapEnabled: false
        )
        // ... 参数钳制断言 ...
    }

    static func validatePianoPanelProjectionResolution() -> [PianoValidationIssue] {
        let fixtureName = "piano_panel_projection_resolves_rows_and_configuration"
        let resolvedConfiguration = PianoPanelProjection.resolvedConfiguration(
            from: baseConfiguration,
            panelState: panelState
        )
        let resolvedRows = PianoPanelProjection.resolvedRows(
            from: baseRows,
            panelState: panelState
        )
        // ... rowCount 扩容、movementScope 覆盖、fallback rows 断言 ...
    }
}
```

### 2.4 `PianoValidationInteractionAndGeometry.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationInteractionAndGeometry.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；PianoSemanticEvent、PianoHitResult、PianoGeometry 与 row scene 几何断言都还混在 monolith 里。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationInteractionAndGeometry.swift
// 函数名: validateScaleDragInteraction() / validateSemanticEvents() / validateHitResultButtonDirection() / validateSceneRowFramesAndZones() / validateSnapTargetAndNormalization()
// 功能说明: 修改后把输入语义与几何/命中测试夹具放到同一职责文件，聚焦“用户输入与场景几何如何对齐”。
extension PianoValidationRunner {
    static func validateSemanticEvents() -> [PianoValidationIssue] {
        let fixtureName = "semantic_events_keep_preview_payload"
        let preview = PianoPreviewState(
            rowIndex: 0,
            note: NotePitch(pitchClass: .aSharp, octave: 3)
        )
        let events: [PianoSemanticEvent] = [
            .rowsChanged(rows),
            .previewStarted(preview),
            .previewChanged(preview),
            .previewEnded(preview)
        ]
        // ... rowsChanged / previewStarted / previewChanged / previewEnded 载荷不丢失 ...
    }

    static func validateSceneRowFramesAndZones() -> [PianoValidationIssue] {
        let fixtureName = "scene_row_frames_and_zones_are_stable"
        let geometry = PianoGeometry(
            configuration: configuration,
            state: state,
            bounds: CGRect(x: 0, y: 0, width: 320, height: 260)
        )
        // ... row frame / buttonRect / scaleRect / keysRect / contentRect 断言 ...
    }
}
```

### 2.5 `PianoValidationReducerAndPresentation.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationReducerAndPresentation.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；按钮按下、按钮步进、动画中断物化、scale drag 收口、preview 生命周期等所有 reducer/presentation 断言仍在 monolith 中间连续堆叠。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationReducerAndPresentation.swift
// 函数名: validateButtonPressLifecycle() / validateButtonStepEmitsRowsTransitionOnFinish() / validateButtonTransitionInterruptMaterialization() / validateScaleDragLifecycle() / validateKeyGlissandoLifecycle()
// 功能说明: 修改后把 reducer 生命周期、presentation override、中间帧物化与 key preview 语义集中到同一文件，便于围绕交互状态机回归。
extension PianoValidationRunner {
    static func validateButtonPressLifecycle() -> [PianoValidationIssue] {
        let fixtureName = "button_press_lifecycle_tracks_inside_state"
        let beganReduction = PianoInteractionReducer.reduce(
            state: state,
            rawEvent: PianoRawEvent(
                phase: .began,
                locationInView: CGPoint(x: 12, y: 10)
            ),
            hitResult: PianoHitResult(
                phase: .began,
                locationInView: CGPoint(x: 12, y: 10),
                rowIndex: 0,
                zone: .buttonRight,
                note: nil,
                isInsideActiveZone: true
            ),
            configuration: PianoConfiguration()
        )
        // ... began / moved 生命周期断言 ...
    }

    static func validateButtonTransitionInterruptMaterialization()
        -> [PianoValidationIssue] {
        let fixtureName = "button_transition_interrupt_materializes_current_frame"
        layer.startRowsTransitionAnimation(
            PianoRowsTransitionPlan(
                fromRows: fromRows,
                toRows: toRows,
                affectedRowIndices: [0]
            )
        ) { finalRows in
            completedRows = finalRows
        }
        Thread.sleep(forTimeInterval: 0.03)
        let materializedRows = layer.cancelRowsTransitionAnimation(
            materializeCurrentFrame: true
        )
        // ... 中间帧物化与完成回调时序断言 ...
    }
}
```

### 2.6 `PianoValidationKeyboardLayer.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationKeyboardLayer.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；PianoKeyboardLayer 的行层结构、状态路由与 flipYToTopLeft 归一化校验都还在 monolith 尾部。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Piano/PianoValidationKeyboardLayer.swift
// 函数名: validateKeyboardLayerUsesOneRowLayerPerRow() / validateKeyboardLayerRoutesVisualStateToRows() / validateKeyboardLayerFlipNormalization()
// 功能说明: 修改后把渲染层级结构与坐标归一化校验独立成 KeyboardLayer 专属文件，职责边界比原来更清楚。
extension PianoValidationRunner {
    static func validateKeyboardLayerUsesOneRowLayerPerRow() -> [PianoValidationIssue] {
        let fixtureName = "keyboard_layer_uses_one_row_layer_per_row"
        let layer = PianoKeyboardLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 320, height: 186)
        layer.state = state
        layer.refreshForCurrentBounds()
        // ... 根 layer 直接子层数量、row layer frame、contentsScale 断言 ...
    }

    static func validateKeyboardLayerRoutesVisualStateToRows() -> [PianoValidationIssue] {
        let fixtureName = "keyboard_layer_routes_visual_state_to_rows"
        let buttonPreviewState = PianoComponentState(
            rows: [
                PianoRowState(startNote: NotePitch(pitchClass: .c, octave: 4)),
                PianoRowState(startNote: NotePitch(pitchClass: .f, octave: 3))
            ],
            preview: PianoPreviewState(
                rowIndex: 1,
                note: NotePitch(pitchClass: .g, octave: 3)
            )
        )
        // ... 不同行之间的 renderState 路由隔离断言 ...
    }
}
```

---

## 3. `ExerciseCompositionValidation` 按职责拆分

### 3.1 `ExerciseCompositionValidation.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: makeFixtures() / validateLegacySingleBaseline() / validateSharedSceneContractsCoverBasicLayouts() / validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
// 功能说明: 修改前这个文件同时承载 legacy baseline、scene core 结构、natural note strip 几何、viewport pin、answer router 等全部 exercise composition validation；一个文件里跨了“训练语义”和“通用 scene 结构”两类职责。
private struct ExerciseCompositionValidationFixture {
    var name: String
    var validate: () -> [ExerciseCompositionValidationIssue]
}

private extension ExerciseCompositionValidationRunner {
    static func validateLegacySingleBaseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
            exerciseMode: .single,
            expectedPageDisplayState: .default
        )
    }

    static func validateSharedSceneContractsCoverBasicLayouts()
        -> [ExerciseCompositionValidationIssue] {
        let stackedScene = ExerciseScene.stacked(
            top: .staffPrompt,
            bottom: .fretboardAnswer
        )
        // ... 同文件里继续校验 scene graph / layout / policy / answer router ...
    }
}
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidation.swift
// 函数名: run(platform:) / runAndReportIfNeeded(platform:) / makeFixtures() / manualChecklist(for:)
// 功能说明: 修改后主文件只保留 Runner、Report、fixture 注册、manual checklist 与 issue helper；validate* 实现被拆到 scene-core 和 exercise-policy 两个附属文件中。
fileprivate struct ExerciseCompositionValidationFixture {
    var name: String
    var validate: () -> [ExerciseCompositionValidationIssue]
}

fileprivate extension ExerciseCompositionValidationRunner {
    static func makeFixtures() -> [ExerciseCompositionValidationFixture] {
        [
            ExerciseCompositionValidationFixture(
                name: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
                validate: validateLegacySingleBaseline
            ),
            ExerciseCompositionValidationFixture(
                name: "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface",
                validate: validateSharedSceneContractsCoverBasicLayouts
            ),
            ExerciseCompositionValidationFixture(
                name: "answer_router_routes_stacked_side_and_single_surface_answers",
                validate: validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers
            )
        ]
    }
}

extension ExerciseCompositionValidationRunner {
    static func manualChecklist(
        for platform: ExerciseCompositionValidationPlatform
    ) -> [String] {
        var checklist = [
            "确认 `single` 与 `sequence` 继续使用上方 `staff`、下方 `fretboard` 的主视觉组合。",
            "确认 `positionPrompt + Side` 在 `fretboardToNaturalNoteStrip` 组合下呈现为左 `fretboard`、右竖排 `natural note strip`，并且左右两块保持同高。"
        ]
        // ... commandLine / iOS / macOS 共用 checklist 汇总 ...
        return checklist
    }
}
```

### 3.2 `ExerciseCompositionValidationSceneCore.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；shared scene contract、natural note strip rail、surface membership、scene validator、viewport pin 等“结构性校验”都混在 ExerciseCompositionValidation.swift 里。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationSceneCore.swift
// 函数名: validateSharedSceneContractsCoverBasicLayouts() / validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing() / validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs() / validateViewportPinningContractsPreserveRailAndStackedLayouts()
// 功能说明: 修改后把 scene graph、surface role、rail layout、validator 与 viewport pin 契约独立成 scene-core 组，后续再扩 mode 时不会继续把这些结构校验和 trainer 语义混在一起。
extension ExerciseCompositionValidationRunner {
    static func validateSharedSceneContractsCoverBasicLayouts()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface"
        let stackedScene = ExerciseScene.stacked(
            top: .staffPrompt,
            bottom: .fretboardAnswer
        )
        // ... stacked / sideBySide / singleSurface 的 scene 根节点与 mainAxisSizing 断言 ...
    }

    static func validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "scene_validator_rejects_duplicate_logical_surface_ids"
        let duplicateFretboardScene = ExerciseScene(
            root: .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(node: .surface(.fretboardPrompt)),
                    ExerciseSceneSplitChild(node: .surface(.fretboardAnswer))
                ]
            )
        )
        let duplicateIssues = ExerciseSceneValidator.validate(
            duplicateFretboardScene
        )
        // ... duplicateSurfaceID / self-answer scene 合法性断言 ...
    }
}
```

### 3.3 `ExerciseCompositionValidationExercisePolicy.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；legacy baseline、page normalization、composition policy 投影、accessory fallback、answer router 等训练/策略校验全都和 scene-core 校验堆在同一个大文件里。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Exercise/ExerciseCompositionValidationExercisePolicy.swift
// 函数名: validateLegacySingleBaseline() / validatePageStateNormalizationPreservesSingleFretboardSlot() / validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes() / validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
// 功能说明: 修改后把 exercise 自身的训练语义、legacy 兼容与答题路由契约独立出来，和 scene-core 结构校验解耦。
extension ExerciseCompositionValidationRunner {
    static func validateLegacySingleBaseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
            exerciseMode: .single,
            expectedPageDisplayState: .default
        )
    }

    static func validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "answer_router_routes_stacked_side_and_single_surface_answers"
        let fretboardConfiguration = FretboardConfiguration()
        let answerCell = FretboardCell(stringIndex: 0, fret: 0)
        let stackedSinglePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                fretboardTrainerState: .init(targetPitchClass: .c),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .default
            )
        )
        // ... stacked / side / self-answer 三种答题路由断言 ...
    }
}
```

---

## 4. `AppScene` 别名命名清理

### 4.1 `SceneCoreCompatibility.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift
// 函数名: （文件级定义）
// 功能说明: 修改前通用的 AppScene* alias 仍然放在一个名为 Compatibility 的文件里；它的内容其实已经不是“临时兼容桥”，但命名仍在向新代码路径泄漏过渡语义。
typealias AppScene = Scene<AppSurfaceNode>
typealias AppSceneNode = SceneNode<AppSurfaceNode>
typealias AppSceneAxis = SceneAxis
typealias AppSceneSplitChild = SceneSplitChild<AppSurfaceNode>
typealias AppSceneSplitChildMainAxisSizing = SceneSplitChildMainAxisSizing
typealias AppSurfaceState = SceneSurfaceState
typealias AppPresentationState = ScenePresentationState<AppSurfaceNode>
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/SceneCoreCompatibility.swift
// 函数名: （文件级定义）
// 功能说明: 修改后该文件已删除；这些 alias 没有被移除，而是迁移到了命名更准确的 AppSceneTypeAliases.swift。
```

### 4.2 `AppSceneTypeAliases.swift`

#### 修改前

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/AppSceneTypeAliases.swift
// 函数名: （文件级定义）
// 功能说明: 修改前该文件不存在；AppScene* 仍挂在旧的 SceneCoreCompatibility.swift 里。
```

#### 修改后

```swift
// 文件路径: NoteMaster_Ver_1/Shared/Scene/AppSceneTypeAliases.swift
// 函数名: （文件级定义）
// 功能说明: 修改后把 AppScene / AppPresentationState 等 alias 迁移到命名更准确的新文件里；符号本身不变，只清理“compatibility”这层过渡命名。
typealias AppScene = Scene<AppSurfaceNode>
typealias AppSceneNode = SceneNode<AppSurfaceNode>
typealias AppSceneAxis = SceneAxis
typealias AppSceneSplitChild = SceneSplitChild<AppSurfaceNode>
typealias AppSceneSplitChildMainAxisSizing = SceneSplitChildMainAxisSizing
typealias AppSurfaceState = SceneSurfaceState
typealias AppPresentationState = ScenePresentationState<AppSurfaceNode>
```

---

## 5. 这次 `phase6` 后的实际效果

- `SettingsNavigationValidation` 不再把 root tree、状态切换、保留标题、accessibility 标识符和断言工具都堆在同一个文件里；根契约 `expectedRootSectionIDs / expectedRootRouteItems` 仍保留，但已经被收口到 `RootTree` 职责文件中。
- `PianoValidation` 主文件不再混入 `CoreGraphics / QuartzCore` 与一长串交互/渲染夹具；配置投影、几何命中、Reducer 状态机、KeyboardLayer 结构已经可以按职责独立维护。
- `ExerciseCompositionValidation` 终于把 “scene-core 结构校验” 和 “exercise policy / answer routing 校验” 拆开，后续如果再加新 mode，不需要继续在一个 4000+ 行 monolith 里加函数。
- `SceneCoreCompatibility.swift` 被删除，但 `AppScene*` alias 没有丢失；只是换到 `AppSceneTypeAliases.swift`，把“兼容层”语义从新代码路径里清掉。
- 这一轮的目标是结构清理，不是行为改写；现有 fixtures 名称、`Runner` 入口和双模式契约都保持不变。

---

## 6. 验证结果

本轮实际做了以下验证：

- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=iOS" build`
- `xcodebuild -project "NoteMaster_Ver_1.xcodeproj" -scheme "NoteMaster_Ver_1" -configuration Debug -destination "generic/platform=macOS" build`
- 对本轮新增/修改的 phase6 Swift 文件执行 `ReadLints`，未发现新增诊断

验证结论：

- iOS Debug 构建通过
- macOS Debug 构建通过
- 本轮 validation 拆分、alias 文件迁移没有引入新的编译或 lint 回归

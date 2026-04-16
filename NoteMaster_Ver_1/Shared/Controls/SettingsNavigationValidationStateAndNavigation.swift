//
//  SettingsNavigationValidationStateAndNavigation.swift
//  NoteMaster_Ver_1
//
//  Split from SettingsNavigationValidation for phase 6 — state transitions, panels, path reconciliation.
//

import Foundation

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
        SettingsPanelEvent.setSliderValue(.pianoRowCount, 5).apply(
            to: &exerciseStateContext
        )
        SettingsPanelEvent.setToggleValue(.pianoSnapEnabled, false).apply(
            to: &exerciseStateContext
        )

        var playStateContext = exerciseStateContext
        SettingsPanelEvent.triggerAction(.setRootModePlay).apply(
            to: &playStateContext
        )
        let playPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: playStateContext
        )

        var restoredExerciseStateContext = playStateContext
        SettingsPanelEvent.triggerAction(.setRootModeExercise).apply(
            to: &restoredExerciseStateContext
        )
        let restoredExercisePanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: restoredExerciseStateContext
        )
        let restoredNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: restoredExerciseStateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        if playPanelModel.sections.map(\.id) != expectedRootSectionIDs(for: .play) {
            issues.append(
                issue(
                    fixtureName,
                    "切到 play 后，settings root 应只保留 Mode 与 Piano section。"
                )
            )
        }

        if restoredExerciseStateContext.trainerDisplayState.exerciseMode != .sequence {
            issues.append(
                issue(
                    fixtureName,
                    "从 play 切回 exercise 后，exerciseMode 应保留为 sequence。"
                )
            )
        }
        if restoredExerciseStateContext.exerciseLayoutPreferences.layoutPreset != .sideBySide {
            issues.append(
                issue(
                    fixtureName,
                    "从 play 切回 exercise 后，layoutPreset 应保留为 sideBySide。"
                )
            )
        }
        if restoredExerciseStateContext.pianoPanelState.resolvedRowCount != 5 {
            issues.append(
                issue(
                    fixtureName,
                    "从 play 切回 exercise 后，piano rows 设置应保持为 5。"
                )
            )
        }
        if restoredExerciseStateContext.pianoPanelState.snapEnabled {
            issues.append(
                issue(
                    fixtureName,
                    "从 play 切回 exercise 后，piano snap 设置应保持为 false。"
                )
            )
        }

        if restoredExercisePanelModel.sections.map(\.id) != expectedRootSectionIDs(for: .exercise) {
            issues.append(
                issue(
                    fixtureName,
                    "从 play 切回 exercise 后，旧的 exercise root tree 应完整恢复。"
                )
            )
        }

        if restoredNavigationModel.reconciledPath([
            .root,
            .section(.exercise),
            .exerciseLayout
        ]) != [
            .root,
            .section(.exercise),
            .exerciseLayout
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "从 play 切回 exercise 后，Exercise > Layout 深层 route 应重新可达。"
                )
            )
        }

        return issues
    }

    static func validatePositionPromptSectionVisibilityTracksExerciseMode()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "position_prompt_section_visibility_tracks_exercise_mode"
        var issues: [SettingsNavigationValidationIssue] = []

        let singleTrainerState = TrainerDisplayState(exerciseMode: .single)
        let singleStateContext = SettingsPanelStateContext(
            trainerDisplayState: singleTrainerState
        )
        let singlePanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: singleStateContext
        )
        let singleNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: singleStateContext
        )

        if resolveSection(.positionPrompt, in: singlePanelModel) != nil {
            issues.append(
                issue(fixtureName, "single 模式下不应继续暴露 Position Prompt section。")
            )
        }
        if singleNavigationModel.page(for: .section(.positionPrompt)) != nil {
            issues.append(
                issue(fixtureName, "single 模式下不应继续生成 Position Prompt section page。")
            )
        }

        let positionPromptStateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: .legacyPositionPrompt,
            trainerDisplayState: .default
        )
        let positionPromptNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: positionPromptStateContext
        )

        let positionPromptPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: positionPromptStateContext
        )

        if resolveSection(.positionPrompt, in: positionPromptPanelModel) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 模式下不应继续暴露 Position Prompt section。"
                )
            )
        }
        if positionPromptNavigationModel.page(for: .section(.positionPrompt)) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 模式下不应继续生成 Position Prompt section page。"
                )
            )
        }
        guard let exerciseSection = resolveSection(
            .exercise,
            in: positionPromptPanelModel
        ) else {
            issues.append(
                issue(fixtureName, "positionPrompt 模式下应保留 Exercise section。")
            )
            return issues
        }
        assertFormPage(
            route: .exerciseMode,
            expectedTitle: SettingsRouteID.exerciseMode.fallbackTitle,
            expectedSection: makeExpectedChildSection(
                title: SettingsRouteID.exerciseMode.fallbackTitle,
                from: exerciseSection,
                keepingRowIDs: [
                    .choice(.exerciseMode),
                    .positionFilter(.positionQuestionPitchClasses)
                ]
            ),
            in: positionPromptNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Position exercise mode page",
            issues: &issues
        )

        return issues
    }

    static func validateFretboardViewportRouteVisibilityTracksDisplayMode()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "fretboard_viewport_route_visibility_tracks_display_mode"
        var issues: [SettingsNavigationValidationIssue] = []

        let sideVerticalStateContext = SettingsPanelStateContext.default
        let sideVerticalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: sideVerticalStateContext
        )
        let sideVerticalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: sideVerticalStateContext
        )
        guard let sideVerticalFretboardSection = resolveSection(.fretboard, in: sideVerticalPanelModel) else {
            issues.append(issue(fixtureName, "vertical 指板模式下应保留 Fretboard section。"))
            return issues
        }
        assertFormPage(
            route: .section(.fretboard),
            expectedTitle: sideVerticalFretboardSection.title,
            expectedSection: sideVerticalFretboardSection,
            in: sideVerticalNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Side Vertical Fretboard section",
            issues: &issues
        )
        if sideVerticalNavigationModel.page(for: .fretboardViewport) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "side + vertical 指板模式下不应继续生成 Fretboard Viewport 深层页。"
                )
            )
        }

        let stackedVerticalStateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
        let stackedVerticalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: stackedVerticalStateContext
        )
        let stackedVerticalNavigationModel = SettingsNavigationSnapshotBuilder
            .makeModel(from: stackedVerticalStateContext)
        guard let stackedVerticalFretboardSection = resolveSection(
            .fretboard,
            in: stackedVerticalPanelModel
        ) else {
            issues.append(issue(fixtureName, "stacked + vertical 指板模式下应保留 Fretboard section。"))
            return issues
        }
        assertIndexPage(
            route: .section(.fretboard),
            expectedTitle: stackedVerticalFretboardSection.title,
            expectedRouteItems: [
                SettingsRouteItem(
                    title: SettingsRouteID.fretboardDisplay.fallbackTitle,
                    subtitle: "Instrument and labels",
                    route: .fretboardDisplay
                ),
                SettingsRouteItem(
                    title: SettingsRouteID.fretboardViewport.fallbackTitle,
                    subtitle: "Vertical sizing",
                    route: .fretboardViewport
                )
            ],
            in: stackedVerticalNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Stacked Vertical Fretboard section",
            issues: &issues
        )
        if stackedVerticalNavigationModel.page(for: .fretboardViewport) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "stacked + vertical 指板模式下应继续生成 Fretboard Viewport 深层页。"
                )
            )
        }

        var horizontalFretboardDisplayState = FretboardDisplayState.default
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalStateContext = SettingsPanelStateContext(
            fretboardDisplayState: horizontalFretboardDisplayState
        )
        let horizontalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: horizontalStateContext
        )
        let horizontalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: horizontalStateContext
        )
        guard let horizontalFretboardSection = resolveSection(.fretboard, in: horizontalPanelModel) else {
            issues.append(issue(fixtureName, "horizontal 指板模式下仍应保留 Fretboard section。"))
            return issues
        }
        assertFormPage(
            route: .section(.fretboard),
            expectedTitle: horizontalFretboardSection.title,
            expectedSection: horizontalFretboardSection,
            in: horizontalNavigationModel,
            fixtureName: fixtureName,
            pageDescription: "Horizontal Fretboard section",
            issues: &issues
        )
        if horizontalNavigationModel.page(for: .fretboardViewport) != nil {
            issues.append(
                issue(fixtureName, "horizontal 指板模式下不应继续生成 Fretboard Viewport 深层页。")
            )
        }

        return issues
    }

    static func validateVerticalViewportGateTracksFretboardContractOnly()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "vertical_viewport_gate_tracks_fretboard_contract_only"
        var issues: [SettingsNavigationValidationIssue] = []

        let sideStateContext = SettingsPanelStateContext.default
        let sidePanelModel = SettingsPanelSnapshotBuilder.makeModel(from: sideStateContext)
        guard let sideFretboardSection = resolveSection(.fretboard, in: sidePanelModel) else {
            issues.append(issue(fixtureName, "default side state 应保留 Fretboard section。"))
            return issues
        }

        if sideStateContext.exerciseLayoutPreferences.layoutPreset != .sideBySide {
            issues.append(
                issue(
                    fixtureName,
                    "default settings state 应继续规范化到 Side by Side layout。"
                )
            )
        }
        if sideStateContext.fretboardLayoutContract
            != ExerciseFretboardLayoutContract(
                pinsSceneToViewportHeight: true,
                heightPolicy: .fillAvailableHeight
            ) {
            issues.append(
                issue(
                    fixtureName,
                    "default side state 下的 viewport gate 应继续读取 fillAvailableHeight 的 fretboard contract。"
                )
            )
        }
        if sideStateContext.fretboardLayoutContract
            .usesVerticalViewportHeightControl
            || sideStateContext.showsVerticalViewportHeightControl {
            issues.append(
                issue(
                    fixtureName,
                    "default side state 不应因为内部 rail contract 而重新显示 Vertical Viewport Height 控件。"
                )
            )
        }
        if sideFretboardSection.rows.map(\.id).contains(.slider(.verticalHostHeightRatio)) {
            issues.append(
                issue(
                    fixtureName,
                    "default side state 的 Fretboard section 不应直接混入 Vertical Viewport Height slider。"
                )
            )
        }

        let stackedStateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
        if stackedStateContext.fretboardLayoutContract
            != ExerciseFretboardLayoutContract(
                pinsSceneToViewportHeight: true,
                heightPolicy: .followViewportRatio
            ) {
            issues.append(
                issue(
                    fixtureName,
                    "stacked state 下的 viewport gate 应继续读取 followViewportRatio 的 fretboard contract。"
                )
            )
        }
        if !stackedStateContext.fretboardLayoutContract
            .usesVerticalViewportHeightControl
            || !stackedStateContext.showsVerticalViewportHeightControl {
            issues.append(
                issue(
                    fixtureName,
                    "stacked + vertical state 应继续显示 Vertical Viewport Height 控件。"
                )
            )
        }

        var horizontalFretboardDisplayState = FretboardDisplayState.default
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalStateContext = SettingsPanelStateContext(
            fretboardDisplayState: horizontalFretboardDisplayState
        )
        if horizontalStateContext.showsVerticalViewportHeightControl {
            issues.append(
                issue(
                    fixtureName,
                    "horizontal 指板模式不应暴露 Vertical Viewport Height 控件。"
                )
            )
        }

        return issues
    }

    static func validateFretboardStringThicknessOptionTracksState()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "fretboard_string_thickness_option_tracks_state"
        var issues: [SettingsNavigationValidationIssue] = []

        let defaultStateContext = SettingsPanelStateContext.default
        let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(from: defaultStateContext)

        guard let defaultRow = defaultPanelModel.choiceRow(for: .stringThickness) else {
            issues.append(issue(fixtureName, "default state 应暴露 String Thickness 选项。"))
            return issues
        }

        if defaultRow.selectionStyle != .singleSelection {
            issues.append(issue(fixtureName, "String Thickness 应为 singleSelection。"))
        }
        if defaultRow.presentationStyle != .segmented {
            issues.append(issue(fixtureName, "String Thickness 应使用 segmented 呈现。"))
        }
        if defaultRow.choices.map(\.id) != [
            .setStringThicknessUniform,
            .setStringThicknessGraduated
        ] {
            issues.append(
                issue(fixtureName, "String Thickness 选项顺序应为 Uniform -> Graduated。")
            )
        }
        if defaultRow.choices.filter(\.isSelected).map(\.id) != [.setStringThicknessUniform] {
            issues.append(issue(fixtureName, "default state 应默认选中 Uniform。"))
        }

        var graduatedStateContext = defaultStateContext
        SettingsActionID.setStringThicknessGraduated.apply(to: &graduatedStateContext)
        if graduatedStateContext.fretboardDisplayState.configuration.stringThicknessStyle != .graduated {
            issues.append(issue(fixtureName, "Graduated action 应写回 fretboardDisplayState。"))
        }

        let graduatedPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: graduatedStateContext
        )
        guard let graduatedRow = graduatedPanelModel.choiceRow(for: .stringThickness) else {
            issues.append(issue(fixtureName, "Graduated state 仍应保留 String Thickness 选项。"))
            return issues
        }

        if graduatedRow.choices.filter(\.isSelected).map(\.id) != [.setStringThicknessGraduated] {
            issues.append(issue(fixtureName, "Graduated state 应只选中 Graduated。"))
        }

        return issues
    }

    static func validateExerciseAndAccessoryRowsMatchStage7Capabilities()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "exercise_and_accessory_rows_match_stage7_capabilities"
        let defaultStateContext = SettingsPanelStateContext.default
        let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: defaultStateContext
        )
        let defaultNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: defaultStateContext
        )
        var issues: [SettingsNavigationValidationIssue] = []

        guard let exerciseSection = resolveSection(.exercise, in: defaultPanelModel) else {
            issues.append(
                issue(fixtureName, "default state 应保留 Exercise section。")
            )
            return issues
        }
        guard let accessoriesSection = resolveSection(.accessories, in: defaultPanelModel) else {
            issues.append(
                issue(fixtureName, "default state 应保留 Accessories section。")
            )
            return issues
        }

        if resolveSection(.layout, in: defaultPanelModel) != nil {
            issues.append(issue(fixtureName, "default state 不应再暴露 Layout section。"))
        }

        if exerciseSection.rows.map(\.id) != [
            .choice(.exerciseMode),
            .positionFilter(.positionQuestionPitchClasses),
            .choice(.compositionPreset),
            .choice(.layoutPreset)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise section row 顺序应保持 Exercise Mode -> Position Question Notes -> Composition Preset -> Layout Preset。"
                )
            )
        }

        guard let compositionRow = defaultPanelModel.choiceRow(for: .compositionPreset) else {
            issues.append(issue(fixtureName, "default state 应暴露 Composition Preset row。"))
            return issues
        }

        if compositionRow.choices.map(\.id) != [
            .setCompositionPresetStaffToFretboard,
            .setCompositionPresetTargetPromptToFretboard,
            .setCompositionPresetFretboardToNaturalNoteStrip,
            .setCompositionPresetFretboardSelfAnswer
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Composition Preset row 选项顺序应保持 Staff -> Target -> Strip -> Self。"
                )
            )
        }
        if compositionRow.choices.filter(\.isSelected).map(\.id) != [
            .setCompositionPresetFretboardToNaturalNoteStrip
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 默认态应选中 Fretboard -> Natural Note Strip 组合。"
                )
            )
        }
        if compositionRow.choices.first(
            where: { $0.id == .setCompositionPresetStaffToFretboard }
        )?.isEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 默认态下 Staff -> Fretboard 不应被标记为可用。"
                )
            )
        }

        guard let layoutRow = defaultPanelModel.choiceRow(for: .layoutPreset) else {
            issues.append(issue(fixtureName, "default state 应暴露 Layout Preset row。"))
            return issues
        }

        if layoutRow.choices.map(\.id) != [
            .setLayoutPresetStacked,
            .setLayoutPresetSideBySide,
            .setLayoutPresetSingleSurface
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Layout Preset row 选项顺序应保持 Stacked -> Side -> Single。"
                )
            )
        }
        if layoutRow.choices.filter(\.isSelected).map(\.id) != [
            .setLayoutPresetSideBySide
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "default state 应默认选中 Side by Side layout。"
                )
            )
        }
        if !(layoutRow.choices.first(
            where: { $0.id == .setLayoutPresetSideBySide }
        )?.isEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "default state 应继续允许切换到 Side by Side layout。"
                )
            )
        }
        if layoutRow.choices.first(
            where: { $0.id == .setLayoutPresetSingleSurface }
        )?.isEnabled ?? false {
            issues.append(
                issue(
                    fixtureName,
                    "默认的多 surface 组合不应把 Single Surface layout 标记为可用。"
                )
            )
        }

        if accessoriesSection.rows.map(\.id) != [
            .toggle(.naturalStripVisible),
            .toggle(.pianoAccessoryVisible),
            .choice(.accessoryPresentation),
            .toggle(.accessoryExpanded)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Accessories section rows 应保持 Natural Strip / Piano Accessory / Presentation / Expanded。"
                )
            )
        }

        guard let accessoryPresentationRow = defaultPanelModel.choiceRow(
            for: .accessoryPresentation
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "default state 应暴露 Accessory Presentation row。"
                )
            )
            return issues
        }
        if accessoryPresentationRow.choices.map(\.id) != [
            .setAccessoryPresentationDocked,
            .setAccessoryPresentationFloating,
            .setAccessoryPresentationCollapsible
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Accessory Presentation row 选项顺序应保持 Docked -> Floating -> Collapsible。"
                )
            )
        }
        if accessoryPresentationRow.choices.contains(where: { !$0.isEnabled }) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 7 后 Docked / Floating / Collapsible 三种 accessory presentation 都应可用。"
                )
            )
        }
        if defaultPanelModel.toggleRow(for: .naturalStripVisible)?.isEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 默认态下的 Natural Strip Visible toggle 应保持禁用，因为 strip 已承担主 answer surface。"
                )
            )
        }
        if defaultPanelModel.toggleRow(for: .accessoryExpanded)?.isEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "默认的 Docked accessory presentation 不应提前启用 Accessory Expanded toggle。"
                )
            )
        }

        let singleModeAccessoryStateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: .default,
            trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
        )
        let singleModeAccessoryPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: singleModeAccessoryStateContext
        )
        if !(singleModeAccessoryPanelModel.toggleRow(
            for: .naturalStripVisible
        )?.isEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "single 模式下 Natural Strip Visible toggle 应允许把 strip 作为 accessory surface 打开。"
                )
            )
        }

        var collapsibleStateContext = singleModeAccessoryStateContext
        SettingsActionID.setAccessoryPresentationCollapsible.apply(
            to: &collapsibleStateContext
        )
        let collapsiblePanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: collapsibleStateContext
        )
        if !(collapsiblePanelModel.toggleRow(
            for: .accessoryExpanded
        )?.isEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "选择 Collapsible presentation 后，Accessory Expanded toggle 应被启用。"
                )
            )
        }

        guard let pianoBehaviorPage = defaultNavigationModel.page(for: .pianoBehavior),
              let pianoBehaviorSections = pianoBehaviorPage.content.sections,
              let pianoBehaviorSection = pianoBehaviorSections.first else {
            issues.append(
                issue(fixtureName, "default state 应继续生成 Piano Behavior page。")
            )
            return issues
        }

        if pianoBehaviorSection.rows.map(\.id) != [
            .slider(.pianoRowCount),
            .choice(.pianoMovementScope),
            .toggle(.pianoSnapEnabled)
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Behavior page rows 应保持 Rows / Row Linking / Snap Drag。"
                )
            )
        }

        let defaultPianoVisibleValue = defaultPanelModel.toggleRow(
            for: .pianoAccessoryVisible
        )?.isOn ?? true
        if defaultPianoVisibleValue {
            issues.append(
                issue(
                    fixtureName,
                    "default state 的 Piano Accessory Visible 开关应默认关闭。"
                )
            )
        }

        var visibleStateContext = defaultStateContext
        SettingsToggleID.pianoAccessoryVisible.apply(
            value: true,
            to: &visibleStateContext
        )
        if !visibleStateContext.pianoPanelState.isVisible {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Accessory Visible 开关写回后应把 pianoPanelState.isVisible 置为 true。"
                )
            )
        }

        let visiblePanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: visibleStateContext
        )
        let visiblePianoVisibleValue = visiblePanelModel.toggleRow(
            for: .pianoAccessoryVisible
        )?.isOn ?? false
        if !visiblePianoVisibleValue {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Accessory Visible 开关写回后，settings snapshot 也应回显为 true。"
                )
            )
        }

        let visibleNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: visibleStateContext
        )
        guard let visiblePianoBehaviorPage = visibleNavigationModel.page(for: .pianoBehavior),
              let visiblePianoBehaviorSection = visiblePianoBehaviorPage.content.sections?.first else {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Accessory Visible 打开后仍应继续保留 Piano Behavior page。"
                )
            )
            return issues
        }

        if visiblePianoBehaviorSection.rows.map(\.id).contains(
            .toggle(.pianoAccessoryVisible)
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "Piano Behavior page 不应重新混入 Piano Accessory Visible toggle。"
                )
            )
        }

        return issues
    }

    static func validateReconciledPathFallsBackToExistingParent()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "reconciled_path_falls_back_to_existing_parent"
        var issues: [SettingsNavigationValidationIssue] = []

        let startupStateContext = SettingsPanelStateContext.default
        let startupNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: startupStateContext
        )
        let availableAccessoryPath = startupNavigationModel.reconciledPath([
            .root,
            .section(.accessories),
            .accessoryPresentation
        ])
        if availableAccessoryPath != [.root, .section(.accessories), .accessoryPresentation] {
            issues.append(
                issue(fixtureName, "已存在的 Accessories 深层 route 不应被错误回退。")
            )
        }

        let singleTrainerNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
            )
        )
        let missingPositionPromptPath = singleTrainerNavigationModel.reconciledPath([
            .root,
            .section(.positionPrompt)
        ])
        if missingPositionPromptPath != [.root] {
            issues.append(
                issue(fixtureName, "缺失的 Position Prompt section route 应直接回退到 root。")
            )
        }

        var horizontalFretboardDisplayState = FretboardDisplayState.default
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                fretboardDisplayState: horizontalFretboardDisplayState
            )
        )
        let viewportFallbackPath = horizontalNavigationModel.reconciledPath([
            .section(.fretboard),
            .fretboardViewport
        ])
        if viewportFallbackPath != [.root, .section(.fretboard)] {
            issues.append(
                issue(fixtureName, "缺失的 Fretboard Viewport route 应回退到最近仍有效的 Fretboard 父级。")
            )
        }

        let duplicateRootPath = startupNavigationModel.reconciledPath([
            .root,
            .root,
            .section(.exercise)
        ])
        if duplicateRootPath != [.root, .section(.exercise)] {
            issues.append(
                issue(fixtureName, "reconciledPath 应去除重复 route，并保持 root 在首位。")
            )
        }

        return issues
    }

    static func validateExerciseLayoutRouteRemainsStableAcrossChoiceUpdates()
        -> [SettingsNavigationValidationIssue] {
        let fixtureName = "exercise_layout_route_remains_stable_across_choice_updates"
        var issues: [SettingsNavigationValidationIssue] = []

        let initialStateContext = SettingsPanelStateContext.default
        let initialNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: initialStateContext
        )
        let initialLayoutPath = initialNavigationModel.reconciledPath([
            .root,
            .section(.exercise),
            .exerciseLayout
        ])

        if initialLayoutPath != [.root, .section(.exercise), .exerciseLayout] {
            issues.append(
                issue(
                    fixtureName,
                    "default state 下 Exercise > Layout 深层 route 应保持可达。"
                )
            )
        }

        var sideBySideStateContext = initialStateContext
        SettingsPanelEvent.triggerAction(.setLayoutPresetSideBySide).apply(
            to: &sideBySideStateContext
        )
        let sideBySideNavigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: sideBySideStateContext
        )
        let sideBySideLayoutPath = sideBySideNavigationModel.reconciledPath(
            initialLayoutPath
        )

        if sideBySideLayoutPath != initialLayoutPath {
            issues.append(
                issue(
                    fixtureName,
                    "在 Exercise > Layout 子页切换 layout 选项时，reconciledPath 不应把当前路径回退或改写到其它 route。"
                )
            )
        }

        guard let layoutPage = sideBySideNavigationModel.page(for: .exerciseLayout),
              let layoutPanelModel = layoutPage.panelModel else {
            issues.append(
                issue(
                    fixtureName,
                    "切到 Side by Side 后，navigation model 仍应暴露 Exercise Layout form page。"
                )
            )
            return issues
        }

        guard let layoutRow = layoutPanelModel.choiceRow(for: .layoutPreset) else {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise Layout page 应继续暴露 Layout Preset row。"
                )
            )
            return issues
        }

        if layoutRow.choices.filter(\.isSelected).map(\.id) != [
            .setLayoutPresetSideBySide
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "切到 Side by Side 后，Exercise Layout page 应立即只选中 Side 选项。"
                )
            )
        }

        return issues
    }

    static func validateSR0SettingsStateFreezesFixedPresentationOptions()
        -> [SettingsNavigationValidationIssue] {
        validateSRFixedSettingsState(
            triggerAction: .setExerciseModeSr0,
            expectedExerciseMode: .sr0,
            modeTitle: "SR-0",
            fixtureName: "sr0_settings_state_freezes_fixed_presentation_options",
            expectedLayoutPreferences: .srNoteStripAnswer,
            hidesPianoRowsAndMovement: false,
            expectedSequenceAnswerPolicy: .pitchClass,
            expectedResolvedPianoRowCount: 6,
            expectedResolvedPianoMovementScope: .cascade
        )
    }

    static func validateSR1SettingsStateFreezesFixedPresentationOptions()
        -> [SettingsNavigationValidationIssue] {
        validateSRFixedSettingsState(
            triggerAction: .setExerciseModeSr1,
            expectedExerciseMode: .sr1,
            modeTitle: "SR-1",
            fixtureName: "sr1_settings_state_freezes_fixed_presentation_options",
            expectedLayoutPreferences: .srPianoAnswer,
            hidesPianoRowsAndMovement: true,
            expectedSequenceAnswerPolicy: .pitchClass,
            expectedResolvedPianoRowCount: 1,
            expectedResolvedPianoMovementScope: .rowOnly
        )
    }

    static func validateSR2SettingsStateFreezesFixedPresentationOptions()
        -> [SettingsNavigationValidationIssue] {
        validateSRFixedSettingsState(
            triggerAction: .setExerciseModeSr2,
            expectedExerciseMode: .sr2,
            modeTitle: "SR-2",
            fixtureName: "sr2_settings_state_freezes_fixed_presentation_options",
            expectedLayoutPreferences: .srPianoAnswer,
            hidesPianoRowsAndMovement: true,
            expectedSequenceAnswerPolicy: .exactNote,
            expectedResolvedPianoRowCount: 2,
            expectedResolvedPianoMovementScope: .rowOnly
        )
    }

    private static func validateSRFixedSettingsState(
        triggerAction: SettingsActionID,
        expectedExerciseMode: TrainerExerciseMode,
        modeTitle: String,
        fixtureName: String,
        expectedLayoutPreferences: ExerciseLayoutPreferences,
        hidesPianoRowsAndMovement: Bool,
        expectedSequenceAnswerPolicy: TrainerSequenceAnswerPolicy,
        expectedResolvedPianoRowCount: Int,
        expectedResolvedPianoMovementScope: PianoMovementScope
    ) -> [SettingsNavigationValidationIssue] {
        var issues: [SettingsNavigationValidationIssue] = []
        var stateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardSelfAnswer,
                layoutPreset: .singleSurface,
                accessoryPresentation: .collapsible,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: true,
                isAccessoryExpanded: false
            ),
            trainerDisplayState: TrainerDisplayState(
                exerciseMode: .single,
                sequenceConfiguration: TrainerSequenceConfiguration(
                    clef: .bass,
                    noteCount: 5,
                    includesAccidentals: true,
                    answerPolicy: .exactNote
                )
            ),
            pianoPanelState: PianoPanelState(
                isVisible: true,
                rowCount: 6,
                movementScope: .cascade
            )
        )
        SettingsPanelEvent.triggerAction(triggerAction).apply(to: &stateContext)

        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        let navigationModel = SettingsNavigationSnapshotBuilder.makeModel(
            from: stateContext
        )
        let resolvedSequenceConfiguration = stateContext.trainerDisplayState
            .resolvedSequenceConfiguration
        let resolvedPianoSettingsSlice = stateContext.trainerDisplayState
            .resolvedPianoSettingsSlice(from: stateContext.pianoPanelState.settingsSlice)
        let expectedExerciseModeChoices: [SettingsActionID] = [
            .setExerciseModeSingle,
            .setExerciseModeSequence,
            .setExerciseModeSr0,
            .setExerciseModeSr1,
            .setExerciseModeSr2,
            .setExerciseModePositionPrompt
        ]
        let expectedExerciseModeTitles = [
            "Single",
            "Sequence",
            "SR-0",
            "SR-1",
            "SR-2",
            "Position"
        ]
        let expectedStaffSectionRowIDs: [SettingsRowID] = [
            .slider(.clefScale),
            .slider(.clefVerticalTrim),
            .slider(.clefAnchorYOffset)
        ]
        let expectedPianoSectionRowIDs: [SettingsRowID] = hidesPianoRowsAndMovement
            ? [
                .choice(.pianoWhiteKeyStyle),
                .toggle(.pianoSnapEnabled)
            ]
            : [
                .slider(.pianoRowCount),
                .choice(.pianoMovementScope),
                .choice(.pianoWhiteKeyStyle),
                .toggle(.pianoSnapEnabled)
            ]
        let expectedPianoBehaviorRowIDs: [SettingsRowID] = hidesPianoRowsAndMovement
            ? [
                .toggle(.pianoSnapEnabled)
            ]
            : [
                .slider(.pianoRowCount),
                .choice(.pianoMovementScope),
                .toggle(.pianoSnapEnabled)
            ]

        if stateContext.trainerDisplayState.exerciseMode != expectedExerciseMode {
            issues.append(
                issue(
                    fixtureName,
                    "触发 \(triggerAction) 后，trainerDisplayState.exerciseMode 应切到 \(expectedExerciseMode)。"
                )
            )
        }
        if stateContext.exerciseLayoutPreferences != expectedLayoutPreferences {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) 的 settings writeback 应把 exerciseLayoutPreferences 固定收敛到 \(expectedLayoutPreferences)。"
                )
            )
        }
        if stateContext.pageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) 的 settings state 仍应保留 legacy 默认 pageState 作为后台兼容值，而不是伪造新的 legacy 组合。"
                )
            )
        }
        if stateContext.pianoPanelState.isVisible {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) 的 settings writeback 应同步清掉 accessory piano 显隐状态。"
                )
            )
        }
        if resolvedSequenceConfiguration.clef != .treble
            || resolvedSequenceConfiguration.answerPolicy
            != expectedSequenceAnswerPolicy {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) 的 resolvedSequenceConfiguration 应强制固定为 treble + \(expectedSequenceAnswerPolicy)。"
                )
            )
        }
        if resolvedSequenceConfiguration.noteCount != 5
            || !resolvedSequenceConfiguration.includesAccidentals {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) 只应钳制 clef / answerPolicy；其余 sequence 配置仍应保留。"
                )
            )
        }
        if resolvedPianoSettingsSlice.rowCount != expectedResolvedPianoRowCount
            || resolvedPianoSettingsSlice.movementScope
            != expectedResolvedPianoMovementScope {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) 的 settings state 应通过 shared helper 收敛到 rowCount=\(expectedResolvedPianoRowCount) / movementScope=\(expectedResolvedPianoMovementScope)。"
                )
            )
        }

        guard let exerciseModeRow = panelModel.choiceRow(for: .exerciseMode) else {
            issues.append(
                issue(fixtureName, "\(modeTitle) state 应继续暴露 Exercise Mode row。")
            )
            return issues
        }

        if exerciseModeRow.choices.map(\.id) != expectedExerciseModeChoices {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise Mode row 的选项顺序应继续保持 Single / Sequence / SR-0 / SR-1 / SR-2 / Position。"
                )
            )
        }
        if exerciseModeRow.choices.map(\.title) != expectedExerciseModeTitles {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise Mode row 的标题顺序应继续保持 Single / Sequence / SR-0 / SR-1 / SR-2 / Position。"
                )
            )
        }
        if exerciseModeRow.choices.filter(\.isSelected).map(\.id) != [triggerAction] {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) state 下 Exercise Mode row 应只选中 \(modeTitle)。"
                )
            )
        }
        guard let sr2Choice = exerciseModeRow.choices.first(where: { choice in
            choice.id == .setExerciseModeSr2
        }) else {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise Mode row 应正式暴露 `SR-2` 选项，而不是只存在于内部 contract。"
                )
            )
            return issues
        }
        if sr2Choice.title != "SR-2" {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise Mode row 中 `SR-2` 选项的标题应保持为 `SR-2`。"
                )
            )
        }
        if sr2Choice.accessibilityLabel
            != "Train treble staff reading with a two-row piano answer surface and exact-note matching" {
            issues.append(
                issue(
                    fixtureName,
                    "Exercise Mode row 中 `SR-2` 选项的 accessibility label 应明确表达 two-row piano + exact-note matching。"
                )
            )
        }
        if panelModel.choiceRow(for: .compositionPreset) != nil
            || panelModel.choiceRow(for: .layoutPreset) != nil
            || panelModel.choiceRow(for: .accessoryPresentation) != nil
            || panelModel.toggleRow(for: .naturalStripVisible) != nil
            || panelModel.toggleRow(for: .pianoAccessoryVisible) != nil
            || panelModel.toggleRow(for: .accessoryExpanded) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) state 下所有会被 fixed presentation 强拉回的 Exercise / Accessories 行都应从 panel snapshot 中隐藏。"
                )
            )
        }
        if resolveSection(.accessories, in: panelModel) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) state 下 Accessories section 应整体消失，而不是保留一个空分区。"
                )
            )
        }

        guard let staffSection = resolveSection(.staff, in: panelModel) else {
            issues.append(
                issue(fixtureName, "\(modeTitle) state 下仍应保留 Staff section。")
            )
            return issues
        }

        if staffSection.rows.map(\.id) != expectedStaffSectionRowIDs {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) state 下 Staff section 应只保留 Clef Layout sliders，并隐藏固定的 Clef 入口。"
                )
            )
        }

        guard let pianoSection = resolveSection(.piano, in: panelModel) else {
            issues.append(
                issue(fixtureName, "\(modeTitle) state 下仍应保留 Piano section。")
            )
            return issues
        }

        if pianoSection.rows.map(\.id) != expectedPianoSectionRowIDs {
            issues.append(
                issue(
                    fixtureName,
                    hidesPianoRowsAndMovement
                        ? "\(modeTitle) state 下 Piano section 应只保留 White Key Style 与 Snap Drag。"
                        : "\(modeTitle) state 下 Piano section 应保留 Rows / Movement / White Key Style / Snap Drag。"
                )
            )
        }

        guard let pianoBehaviorPage = navigationModel.page(for: .pianoBehavior),
              let pianoBehaviorSection = pianoBehaviorPage.content.sections?.first else {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) state 下仍应生成 Piano Behavior page。"
                )
            )
            return issues
        }

        if pianoBehaviorSection.rows.map(\.id) != expectedPianoBehaviorRowIDs {
            issues.append(
                issue(
                    fixtureName,
                    hidesPianoRowsAndMovement
                        ? "\(modeTitle) state 下 Piano Behavior page 应收敛为只包含 Snap Drag。"
                        : "\(modeTitle) state 下 Piano Behavior page 应保留 Rows / Movement / Snap Drag。"
                )
            )
        }
        if navigationModel.page(for: .pianoAppearance) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) state 下仍应保留 Piano Appearance page。"
                )
            )
        }
        if navigationModel.reconciledPath([
            .root,
            .section(.piano),
            .pianoBehavior
        ]) != [
            .root,
            .section(.piano),
            .pianoBehavior
        ] {
            issues.append(
                issue(
                    fixtureName,
                    "\(modeTitle) state 下 Piano > Behavior 路径仍应保持可达。"
                )
            )
        }

        return issues
    }
}

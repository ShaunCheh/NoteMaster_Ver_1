//
//  ExerciseCompositionValidationExercisePolicy.swift
//  NoteMaster_Ver_1
//
//  Trainer / settings / composition policy / answer routing contracts
//  for automated exercise composition validation.
//

import CoreGraphics
import Foundation

extension ExerciseCompositionValidationRunner {

    static func validateLegacySingleBaseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_single_baseline_matches_stacked_staff_over_fretboard",
            exerciseMode: .single,
            expectedPageDisplayState: .default
        )
    }

    static func validateLegacySequenceBaseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_sequence_baseline_matches_stacked_staff_over_fretboard",
            exerciseMode: .sequence,
            expectedPageDisplayState: .default
        )
    }

    static func validateLegacyP2Baseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_p2_baseline_matches_stacked_staff_over_fretboard",
            exerciseMode: .p2,
            expectedPageDisplayState: .default
        )
    }

    static func validateLegacyPositionPromptBaseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_position_prompt_baseline_matches_fretboard_over_natural_strip",
            exerciseMode: .positionPrompt,
            expectedPageDisplayState: .positionPrompt
        )
    }

    static func validateLegacyFR0Baseline()
        -> [ExerciseCompositionValidationIssue] {
        validateLegacyBaseline(
            fixtureName: "legacy_fr0_baseline_matches_target_prompt_over_fretboard",
            exerciseMode: .fr0,
            expectedPageDisplayState: PageDisplayState(
                topContentMode: .targetPrompt,
                mainContentMode: .fretboard
            )
        )
    }

    static func validateLegacyBaseline(
        fixtureName: String,
        exerciseMode: TrainerExerciseMode,
        expectedPageDisplayState: PageDisplayState
    ) -> [ExerciseCompositionValidationIssue] {
        var issues: [ExerciseCompositionValidationIssue] = []

        if !expectedPageDisplayState.hasValidFretboardPlacement {
            issues.append(
                issue(
                    fixtureName,
                    "legacy page baseline 必须继续保证 fretboard 只占用一个视觉槽位。"
                )
            )
        }

        let stateContext = SettingsPanelStateContext(
            pageDisplayState: expectedPageDisplayState,
            trainerDisplayState: TrainerDisplayState(exerciseMode: exerciseMode)
        )
        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        guard let exerciseSection = panelModel.sections.first(where: {
            $0.id == .exercise
        }) else {
            issues.append(
                issue(
                    fixtureName,
                    "settings snapshot 应保留 Exercise section。"
                )
            )
            return issues
        }

        switch exerciseMode {
        case .single, .sequence:
            if exerciseSection.rows.map(\.id) != [
                .choice(.exerciseMode),
                .choice(.compositionPreset),
                .choice(.layoutPreset)
            ] {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 模式下的 Exercise section 应暴露 Exercise Mode / Composition Preset / Layout Preset。"
                    )
                )
            }
            if expectedPageDisplayState.topContentMode != .staff
                || expectedPageDisplayState.mainContentMode != .fretboard {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 的 legacy baseline 应保持 staff -> fretboard。"
                    )
                )
            }
            if expectedPageDisplayState.showsFretboardInTopContent
                || !expectedPageDisplayState.showsFretboardInMainContent {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 的 legacy baseline 只允许 mainContent 承载 fretboard。"
                    )
                )
            }
            if panelModel.sections.contains(where: { $0.id == .positionPrompt }) {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 模式下不应继续暴露 Position Prompt section。"
                    )
                )
            }
            if panelModel.choiceRow(for: .compositionPreset)?.choices.filter(\.isSelected)
                .map(\.id) != [.setCompositionPresetStaffToFretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "single / sequence 的 legacy baseline 应把 Composition Preset 映射为 Staff -> Fretboard。"
                    )
                )
            }
        case .fr0:
            if expectedPageDisplayState.topContentMode != .targetPrompt
                || expectedPageDisplayState.mainContentMode != .fretboard {
                issues.append(
                    issue(
                        fixtureName,
                        "FR-0 的 legacy baseline 应保持 targetPrompt -> fretboard。"
                    )
                )
            }
            if expectedPageDisplayState.showsFretboardInTopContent
                || !expectedPageDisplayState.showsFretboardInMainContent {
                issues.append(
                    issue(
                        fixtureName,
                        "FR-0 的 legacy baseline 只允许 mainContent 承载 fretboard。"
                    )
                )
            }
            if exerciseSection.rows.map(\.id) != [
                .choice(.exerciseMode),
                .positionFilter(.positionQuestionPitchClasses)
            ] {
                issues.append(
                    issue(
                        fixtureName,
                        "FR-0 模式下的 Exercise section 应暴露 Exercise Mode / Note Names，并隐藏固定的 Composition / Layout。"
                    )
                )
            }
            if stateContext.exerciseLayoutPreferences
                != .fr0TargetPromptFretboardAnswer {
                issues.append(
                    issue(
                        fixtureName,
                        "FR-0 的 legacy baseline 应继续收敛到固定的 `targetPromptToFretboard + sideBySide` layout contract。"
                    )
                )
            }
            if panelModel.choiceRow(for: .compositionPreset) != nil
                || panelModel.choiceRow(for: .layoutPreset) != nil
                || panelModel.sections.contains(where: { $0.id == .accessories }) {
                issues.append(
                    issue(
                        fixtureName,
                        "FR-0 的 fixed presentation baseline 不应继续暴露 Composition / Layout / Accessories。"
                    )
                )
            }
            if panelModel.sections.contains(where: { $0.id == .positionPrompt }) {
                issues.append(
                    issue(
                        fixtureName,
                        "FR-0 模式下不应继续暴露 Position Prompt section。"
                    )
                )
            }
        case .p2:
            if exerciseSection.rows.map(\.id) != [
                .choice(.exerciseMode)
            ] {
                issues.append(
                    issue(
                        fixtureName,
                        "P-2 的 legacy baseline 应把 Exercise section 收敛为只保留 Exercise Mode。"
                    )
                )
            }
            if expectedPageDisplayState.topContentMode != .staff
                || expectedPageDisplayState.mainContentMode != .fretboard {
                issues.append(
                    issue(
                        fixtureName,
                        "P-2 的 legacy baseline 应保持 staff -> fretboard。"
                    )
                )
            }
            if expectedPageDisplayState.showsFretboardInTopContent
                || !expectedPageDisplayState.showsFretboardInMainContent {
                issues.append(
                    issue(
                        fixtureName,
                        "P-2 的 legacy baseline 只允许 mainContent 承载 fretboard。"
                    )
                )
            }
            if stateContext.exerciseLayoutPreferences != .p2StaffFretboardAnswer {
                issues.append(
                    issue(
                        fixtureName,
                        "P-2 的 legacy baseline 应继续收敛到固定的 `staffToFretboard + stacked` layout contract。"
                    )
                )
            }
            if stateContext.fretboardLayoutContract
                != ExerciseFretboardLayoutContract(
                    pinsSceneToViewportHeight: true,
                    heightPolicy: .followViewportRatio,
                    verticalFretboardWidthScale: 2,
                    verticalFretboardOverflowScrollAxis: .vertical
                )
                || !stateContext.fretboardLayoutContract
                .usesWidthDrivenVerticalOverflow {
                issues.append(
                    issue(
                        fixtureName,
                        "P-2 的 fixed presentation contract 应继续把下方竖向指板切到 `width x2 + local vertical scroll` 语义。"
                    )
                )
            }
            if panelModel.choiceRow(for: .compositionPreset) != nil
                || panelModel.choiceRow(for: .layoutPreset) != nil
                || panelModel.sections.contains(where: { $0.id == .accessories }) {
                issues.append(
                    issue(
                        fixtureName,
                        "P-2 的 fixed presentation baseline 不应继续暴露 Composition / Layout / Accessories。"
                    )
                )
            }
            if panelModel.sections.contains(where: { $0.id == .positionPrompt }) {
                issues.append(
                    issue(
                        fixtureName,
                        "P-2 模式下不应继续暴露 Position Prompt section。"
                    )
                )
            }
        case .sr0, .sr1, .sr2, .bcr1:
            issues.append(
                issue(
                    fixtureName,
                    "固定识别模式应使用各自的 mode contract 夹具，不应走 legacy baseline 验证入口。"
                )
            )
        case .positionPrompt:
            if expectedPageDisplayState.topContentMode != .fretboard
                || expectedPageDisplayState.mainContentMode != .naturalNoteStrip {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 legacy baseline 应保持 fretboard -> naturalNoteStrip。"
                    )
                )
            }
            if !expectedPageDisplayState.showsFretboardInTopContent
                || expectedPageDisplayState.showsFretboardInMainContent {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 legacy baseline 只允许 topContent 承载 fretboard。"
                    )
                )
            }
            let expectedPositionPromptRowIDs: [SettingsRowID] = [
                .choice(.exerciseMode),
                .positionFilter(.positionQuestionPitchClasses),
                .choice(.compositionPreset),
                .choice(.layoutPreset)
            ]
            if exerciseSection.rows.map(\.id) != expectedPositionPromptRowIDs {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 模式下 Exercise section 应暴露 Exercise Mode / Note Names / Composition Preset / Layout Preset。"
                    )
                )
            }
            if panelModel.sections.contains(where: { $0.id == .positionPrompt }) {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 模式下不应继续暴露 Position Prompt section。"
                    )
                )
            }
            if panelModel.choiceRow(for: .compositionPreset)?.choices.filter(\.isSelected)
                .map(\.id) != [.setCompositionPresetFretboardToNaturalNoteStrip] {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 legacy baseline 应把 Composition Preset 映射为 Fretboard -> Natural Note Strip。"
                    )
                )
            }
        }

        return issues
    }

    static func validatePageStateNormalizationPreservesSingleFretboardSlot()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "page_state_normalization_preserves_single_fretboard_slot"
        var issues: [ExerciseCompositionValidationIssue] = []

        let topPrioritizedContentModes = ExerciseSceneValidator
            .normalizedLegacyPageContentModes(
                topContentMode: .fretboard,
                mainContentMode: .fretboard,
                prioritizingTopContent: true
            )
        let topPrioritizedState = PageDisplayState(
            topContentMode: topPrioritizedContentModes.topContentMode,
            mainContentMode: topPrioritizedContentModes.mainContentMode
        )
        if topPrioritizedState.topContentMode != .fretboard
            || topPrioritizedState.mainContentMode != .naturalNoteStrip {
            issues.append(
                issue(
                    fixtureName,
                    "shared validator 在 top 优先时应继续把 mainContent 归一化到 naturalNoteStrip。"
                )
            )
        }

        let mainPrioritizedContentModes = ExerciseSceneValidator
            .normalizedLegacyPageContentModes(
                topContentMode: .fretboard,
                mainContentMode: .fretboard,
                prioritizingTopContent: false
            )
        let mainPrioritizedState = PageDisplayState(
            topContentMode: mainPrioritizedContentModes.topContentMode,
            mainContentMode: mainPrioritizedContentModes.mainContentMode
        )
        if mainPrioritizedState.topContentMode != .staff
            || mainPrioritizedState.mainContentMode != .fretboard {
            issues.append(
                issue(
                    fixtureName,
                    "shared validator 在 main 优先时应继续把 topContent 归一化到 staff。"
                )
            )
        }

        let initNormalizedState = PageDisplayState(
            topContentMode: .fretboard,
            mainContentMode: .fretboard
        )
        if initNormalizedState != topPrioritizedState {
            issues.append(
                issue(
                    fixtureName,
                    "PageDisplayState 初始化仍应保持 top 优先的 legacy 归一化结果。"
                )
            )
        }

        if !topPrioritizedState.hasValidFretboardPlacement
            || !mainPrioritizedState.hasValidFretboardPlacement {
            issues.append(
                issue(
                    fixtureName,
                    "legacy page normalization 结果必须保持唯一 fretboard placement。"
                )
            )
        }

        return issues
    }

    static func validateLayoutDefaultsKeepPianoHiddenAndVerticalViewportVisible()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "layout_defaults_keep_piano_hidden_and_vertical_viewport_visible"
        let defaultStateContext = SettingsPanelStateContext.default
        let defaultPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: defaultStateContext
        )
        var issues: [ExerciseCompositionValidationIssue] = []

        if defaultStateContext.fretboardDisplayState.displayMode != .vertical {
            issues.append(
                issue(
                    fixtureName,
                    "迁移前默认指板 displayMode 应继续保持 vertical。"
                )
            )
        }
        if defaultStateContext.pianoPanelState.isVisible {
            issues.append(
                issue(
                    fixtureName,
                    "迁移前默认 pianoPanelState.isVisible 应继续保持 false。"
                )
            )
        }
        if abs(
            defaultStateContext.fretboardDisplayState.verticalHostHeightRatio
                - FretboardDisplayState.defaultVerticalHostHeightRatio
        ) > 0.0001 {
            issues.append(
                issue(
                    fixtureName,
                    "迁移前默认 verticalHostHeightRatio 应继续对齐 defaultVerticalHostHeightRatio。"
                )
            )
        }

        guard let pianoVisibleToggle = defaultPanelModel.toggleRow(
            for: .pianoAccessoryVisible
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "default settings snapshot 应继续暴露 Piano Accessory Visible 开关。"
                )
            )
            return issues
        }
        if pianoVisibleToggle.isOn {
            issues.append(
                issue(
                    fixtureName,
                    "default settings snapshot 中的 Piano Accessory Visible 开关应继续默认关闭。"
                )
            )
        }
        if defaultPanelModel.sliderRow(for: .verticalHostHeightRatio) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "默认 side settings snapshot 不应继续暴露 Viewport Height 滑块。"
                )
            )
        }

        let stackedVerticalStateContext = SettingsPanelStateContext(
            fretboardDisplayState: defaultStateContext.fretboardDisplayState,
            staffDisplayState: defaultStateContext.staffDisplayState,
            exerciseLayoutPreferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            ),
            trainerDisplayState: defaultStateContext.trainerDisplayState,
            pianoPanelState: defaultStateContext.pianoPanelState
        )
        let stackedVerticalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: stackedVerticalStateContext
        )
        if stackedVerticalPanelModel.sliderRow(for: .verticalHostHeightRatio) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "stacked + vertical settings snapshot 应继续暴露 Viewport Height 滑块。"
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
                    "Piano Accessory Visible 开关写回后应继续把 pianoPanelState.isVisible 置为 true。"
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
                    "Piano Accessory Visible 开关写回后，settings snapshot 也应继续回显为开启。"
                )
            )
        }

        var horizontalFretboardDisplayState = defaultStateContext.fretboardDisplayState
        horizontalFretboardDisplayState.setDisplayMode(.horizontal)
        let horizontalPanelModel = SettingsPanelSnapshotBuilder.makeModel(
            from: SettingsPanelStateContext(
                fretboardDisplayState: horizontalFretboardDisplayState,
                staffDisplayState: defaultStateContext.staffDisplayState,
                exerciseLayoutPreferences: defaultStateContext
                    .exerciseLayoutPreferences,
                trainerDisplayState: defaultStateContext.trainerDisplayState,
                pianoPanelState: defaultStateContext.pianoPanelState
            )
        )
        if horizontalPanelModel.sliderRow(for: .verticalHostHeightRatio) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "horizontal settings snapshot 不应继续暴露 Viewport Height 滑块。"
                )
            )
        }

        return issues
    }
    static func validateSharedLayoutPreferencesCoexistWithLegacyPageState()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_layout_preferences_coexist_with_legacy_page_state"
        var issues: [ExerciseCompositionValidationIssue] = []
        let defaultStateContext = SettingsPanelStateContext.default

        if defaultStateContext.exerciseLayoutPreferences != .legacyPositionPrompt {
            issues.append(
                issue(
                    fixtureName,
                    "SettingsPanelStateContext.default 应对齐 positionPrompt 的 legacy ExerciseLayoutPreferences。"
                )
            )
        }

        let customPreferences = ExerciseLayoutPreferences.singleFretboardSelfAnswer
        let stateContext = SettingsPanelStateContext(
            exerciseLayoutPreferences: customPreferences,
            trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt)
        )
        if stateContext.pageDisplayState != .positionPrompt {
            issues.append(
                issue(
                    fixtureName,
                    "设置 context 应继续从 ExerciseLayoutPreferences 投影 legacy page bridge。"
                )
            )
        }
        if stateContext.exerciseLayoutPreferences != customPreferences {
            issues.append(
                issue(
                    fixtureName,
                    "并存阶段设置 context 应能携带新的 ExerciseLayoutPreferences。"
                )
            )
        }

        let panelModel = SettingsPanelSnapshotBuilder.makeModel(from: stateContext)
        if panelModel.sections.first(where: { $0.id == .exercise }) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 2 中，shared context 新增字段不应破坏新 Exercise section 的生成。"
                )
            )
        }

        let preservedSideBySidePreferences = LegacyPageLayoutAdapter
            .normalizedPreferences(
                ExerciseLayoutPreferences(
                    compositionPreset: .targetPromptToFretboard,
                    layoutPreset: .sideBySide
                ),
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single)
            )
        if preservedSideBySidePreferences.layoutPreset != .sideBySide {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 4 中，bridge 不应再把已支持的 sideBySide 语义布局压回 stacked。"
                )
            )
        }

        let preservedSelfAnswerPreferences = LegacyPageLayoutAdapter
            .normalizedPreferences(
                .singleFretboardSelfAnswer,
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: .positionPrompt
                )
            )
        if preservedSelfAnswerPreferences.compositionPreset != .fretboardSelfAnswer
            || preservedSelfAnswerPreferences.layoutPreset != .singleSurface {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 4 中，positionPrompt 的单 fretboard self-answer 偏好不应在 settings bridge 往返时丢失。"
                )
            )
        }

        return issues
    }

    static func validateCompositionPolicyProjectsSupportedPresetsToExpectedScenes()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "composition_policy_projects_supported_presets_to_expected_scenes"
        var issues: [ExerciseCompositionValidationIssue] = []

        let sideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .targetPromptToFretboard,
                    layoutPreset: .sideBySide
                )
            )
        )
        if !ExerciseSceneValidator.validate(sideBySidePresentation.scene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide 的 targetPrompt -> fretboard 组合应生成合法 scene。"
                )
            )
        }
        switch sideBySidePresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "targetPrompt -> fretboard 的 sideBySide 组合应投影到 horizontal split。"
                    )
                )
            }
            let childSurfaceIDs = children.compactMap {
                $0.node.surfaceNodes.first?.id
            }
            if childSurfaceIDs != [.targetPrompt, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "targetPrompt -> fretboard 的 sideBySide 组合应保持 targetPrompt 在左、fretboard 在右。"
                    )
                )
            }
            if children.count != 2
                || !children[0].mainAxisSizing.isWeighted
                || !children[1].mainAxisSizing.isWeighted {
                issues.append(
                    issue(
                        fixtureName,
                        "targetPrompt -> fretboard 的 sideBySide 组合在阶段 2 仍应保持双 weighted 主轴尺寸语义。"
                    )
                )
            }
            guard
                children.count == 2,
                case let .surface(promptSurface) = children[0].node,
                case let .surface(answerSurface) = children[1].node
            else {
                break
            }
            if promptSurface.presentationStyle != .standard
                || answerSurface.presentationStyle != .standard {
                issues.append(
                    issue(
                        fixtureName,
                        "targetPrompt -> fretboard 的 sideBySide 组合在阶段 2 不应带入 verticalRail presentation style。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide 组合应生成 split scene。"
                )
            )
        }
        if sideBySidePresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "horizontal split 在阶段 3 仍不应被误标记为 legacy page 可直接投影。"
                )
            )
        }

        let fr0SideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .fr0),
                fretboardTrainerState: .init(
                    singleCoverageTargetPool: Set([.a, .c, .e])
                ),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToFretboard,
                    layoutPreset: .stacked,
                    accessoryPresentation: .collapsible,
                    isNaturalNoteStripVisible: true,
                    isPianoAccessoryVisible: true,
                    isAccessoryExpanded: false
                )
            )
        )
        if fr0SideBySidePresentation.resolvedLayoutPreferences
            != .fr0TargetPromptFretboardAnswer {
            issues.append(
                issue(
                    fixtureName,
                    "FR-0 的 shared normalization 应强制固定到 `targetPromptToFretboard + sideBySide`。"
                )
            )
        }
        if !ExerciseSceneValidator.validate(
            fr0SideBySidePresentation.scene
        ).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "FR-0 的固定 targetPrompt -> fretboard sideBySide 组合应生成合法 scene。"
                )
            )
        }
        switch fr0SideBySidePresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal
                || children.count != 2
                || children[0].mainAxisSizing != .fitContent
                || children[1].mainAxisSizing != .weighted(1) {
                issues.append(
                    issue(
                        fixtureName,
                        "FR-0 的 sideBySide 组合应保持左 fitContent、右 weighted(1) 的主轴尺寸语义。"
                    )
                )
            }
            let childSurfaceIDs = children.compactMap {
                $0.node.surfaceNodes.first?.id
            }
            if childSurfaceIDs != [.targetPrompt, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "FR-0 的 sideBySide 组合应保持左 targetPrompt、右 fretboard。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "FR-0 的固定布局应生成 horizontal split scene。"
                )
            )
        }
        if !fr0SideBySidePresentation.scene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "FR-0 的 sideBySide 组合应继续通过 shared helper 请求 viewport pin 高度。"
                )
            )
        }
        if fr0SideBySidePresentation.fretboardLayoutContract.heightPolicy
            != .fillAvailableHeight {
            issues.append(
                issue(
                    fixtureName,
                    "FR-0 的主 fretboard 应继续跟随 side 容器填满高度。"
                )
            )
        }
        if fr0SideBySidePresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "FR-0 的 horizontal split 主场景不应被误标记为 legacy page 可直接投影。"
                )
            )
        }

        let sideBySidePositionPromptPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .positionPrompt
                    ),
                    fretboardTrainerState: .init(positionPromptMode: ()),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .fretboardToNaturalNoteStrip,
                        layoutPreset: .sideBySide
                    )
                )
            )
        if !ExerciseSceneValidator.validate(
            sideBySidePositionPromptPresentation.scene
        ).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应生成合法 scene。"
                )
            )
        }
        switch sideBySidePositionPromptPresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应投影到 horizontal split。"
                    )
                )
            }
            let childSurfaceIDs = children.compactMap {
                $0.node.surfaceNodes.first?.id
            }
            if childSurfaceIDs != [.fretboard, .naturalNoteStrip] {
                issues.append(
                    issue(
                        fixtureName,
                        "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应保持 fretboard 在左、natural note strip 在右。"
                    )
                )
            }
            if children.count != 2
                || children[0].mainAxisSizing != .weighted(1)
                || children[1].mainAxisSizing != .fitContent {
                issues.append(
                    issue(
                        fixtureName,
                        "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应保持左 weighted(1)、右 fitContent 的主轴尺寸语义。"
                    )
                )
            }
            guard
                children.count == 2,
                case let .surface(promptSurface) = children[0].node,
                case let .surface(answerSurface) = children[1].node
            else {
                break
            }
            if promptSurface.presentationStyle != .standard
                || answerSurface.presentationStyle != .verticalRail {
                issues.append(
                    issue(
                        fixtureName,
                        "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应保持左侧 standard fretboard、右侧 verticalRail strip。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应生成 split scene。"
                )
            )
        }
        if !sideBySidePositionPromptPresentation.scene
            .hasMixedMainAxisSizing(along: .horizontal) {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应触发 horizontal mixed main-axis sizing 语义。"
                )
            )
        }
        if !sideBySidePositionPromptPresentation.scene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 应通过 verticalRail 语义要求 viewport pin 高度。"
                )
            )
        }
        if sideBySidePositionPromptPresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 sideBySide 组合在阶段 2 仍不应被误投影成 legacy page 双槽位。"
                )
            )
        }

        let selfAnswerPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: .positionPrompt
                ),
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .singleFretboardSelfAnswer
            )
        )
        if !ExerciseSceneValidator.validate(selfAnswerPresentation.scene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 组合应生成合法 scene。"
                )
            )
        }
        switch selfAnswerPresentation.scene.root {
        case let .surface(surface):
            if surface.id != .fretboard
                || !surface.roles.contains(.prompt)
                || !surface.roles.contains(.answer) {
                issues.append(
                    issue(
                        fixtureName,
                        "single fretboard self-answer 应投影为同时承担 prompt/answer 的单 fretboard surface。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 应投影为单 surface scene。"
                )
            )
        }
        let selfAnswerFretboardState = selfAnswerPresentation.projectedSurfaceState(
            for: .fretboard
        )
        if !(selfAnswerFretboardState?.isPromptActive ?? false)
            || !(selfAnswerFretboardState?.isAnswerEnabled ?? false)
            || !(selfAnswerFretboardState?.isInteractionEnabled ?? false) {
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 的 fretboard surface state 应同时开启 prompt、answer 和 interaction。"
                )
            )
        }
        if selfAnswerPresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 在阶段 3 仍不应被误投影成 legacy page 双槽位。"
                )
            )
        }

        let positionPromptPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(
                    exerciseMode: .positionPrompt
                ),
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .fretboardToNaturalNoteStrip,
                    layoutPreset: .stacked,
                    accessoryPresentation: .docked,
                    isNaturalNoteStripVisible: true,
                    isPianoAccessoryVisible: false,
                    isAccessoryExpanded: true
                )
            )
        )
        if positionPromptPresentation.legacyPageDisplayState != .positionPrompt {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip 组合应继续投影回 legacy positionPrompt 页面。"
                )
            )
        }

        return issues
    }

    static func validateAccessorySceneNodesFollowPresentationStrategy()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "accessory_scene_nodes_follow_presentation_strategy"
        var issues: [ExerciseCompositionValidationIssue] = []

        let floatingAccessoryPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToFretboard,
                    layoutPreset: .stacked,
                    accessoryPresentation: .floating,
                    isNaturalNoteStripVisible: true
                )
            )
        )
        switch floatingAccessoryPresentation.scene.root {
        case let .overlay(base, floating):
            let baseSurfaceIDs = base.surfaceNodes.map(\.id)
            let floatingSurfaceIDs = floating.flatMap { $0.surfaceNodes }.map(\.id)
            if baseSurfaceIDs != [.staff, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "Floating accessory scene 的 base 应继续保持 staff -> fretboard 主视觉组合。"
                    )
                )
            }
            if floatingSurfaceIDs != [.naturalNoteStrip] {
                issues.append(
                    issue(
                        fixtureName,
                        "Floating accessory scene 应把 natural note strip 放进 floating accessory 节点。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "Accessory Presentation = Floating 时应生成 overlay scene。"
                )
            )
        }
        guard let floatingStripState = floatingAccessoryPresentation
            .projectedSurfaceState(
            for: .naturalNoteStrip
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "Floating accessory scene 应继续生成 natural note strip surface state。"
                )
            )
            return issues
        }
        if !floatingStripState.isVisible
            || floatingStripState.isAnswerEnabled
            || floatingStripState.isInteractionEnabled {
            issues.append(
                issue(
                    fixtureName,
                    "作为 accessory surface 的 natural note strip 应可见，但不能承担 answer 或交互职责。"
                )
            )
        }
        if floatingAccessoryPresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "Floating accessory scene 不应被误投影成 legacy page 双槽位。"
                )
            )
        }

        let collapsedAccessoryPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: .stacked,
                        accessoryPresentation: .collapsible,
                        isNaturalNoteStripVisible: false,
                        isPianoAccessoryVisible: true,
                        isAccessoryExpanded: false
                    )
                )
            )
        switch collapsedAccessoryPresentation.scene.root {
        case let .collapsible(main, accessory, isExpanded):
            if isExpanded {
                issues.append(
                    issue(
                        fixtureName,
                        "Accessory Presentation = Collapsible 且 isAccessoryExpanded = false 时不应错误展开 accessory。"
                    )
                )
            }
            if main.surfaceNodes.map(\.id) != [.staff, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "Collapsible scene 的 main 分支应继续保持 staff -> fretboard 主视觉组合。"
                    )
                )
            }
            if accessory.surfaceNodes.map(\.id) != [.piano] {
                issues.append(
                    issue(
                        fixtureName,
                        "Collapsible scene 的 accessory 分支应承载 piano surface。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "Accessory Presentation = Collapsible 时应生成 collapsible scene。"
                )
            )
        }
        if !collapsedAccessoryPresentation.containsSurface(.piano) {
            issues.append(
                issue(
                    fixtureName,
                    "收起的 collapsible accessory 仍应在 scene 中保留 piano surface，只是 effective state 变为隐藏。"
                )
            )
        }
        let collapsedPianoState = collapsedAccessoryPresentation
            .projectedSurfaceState(
            for: .piano
        )
        if collapsedPianoState?.isVisible ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "收起的 collapsible accessory 应把 piano surface 标记为不可见。"
                )
            )
        }
        if collapsedPianoState?.isInteractionEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "收起的 collapsible accessory 不应继续保留 piano 的交互能力。"
                )
            )
        }

        let threePaneLayoutScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .staffToFretboard,
                layoutPreset: .threePane,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: true
            )
        )
        switch threePaneLayoutScene.root {
        case let .split(axis, children):
            if axis != .vertical || children.count != 2 {
                issues.append(
                    issue(
                        fixtureName,
                        "ThreePane layout 应以 vertical split 承载主内容与 accessory subtree。"
                    )
                )
            } else {
                let mainSurfaceIDs = children[0].node.surfaceNodes.map(\.id)
                let accessorySurfaceIDs = children[1].node.surfaceNodes.map(\.id)
                if mainSurfaceIDs != [.staff, .fretboard] {
                    issues.append(
                        issue(
                            fixtureName,
                            "ThreePane layout 的主分支应继续保持 staff -> fretboard 组合。"
                        )
                    )
                }
                if accessorySurfaceIDs != [.naturalNoteStrip, .piano] {
                    issues.append(
                        issue(
                            fixtureName,
                            "ThreePane layout 的 accessory 分支应同时容纳 natural note strip 与 piano。"
                        )
                    )
                }
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "layoutPreset = ThreePane 时应生成 docked split scene。"
                )
            )
        }

        return issues
    }

    static func validateStaffToPianoSkipsLegacyBackProjection()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "staff_to_piano_skips_legacy_back_projection"
        var issues: [ExerciseCompositionValidationIssue] = []

        let trainerDisplayState = TrainerDisplayState(exerciseMode: .sr1)
        let requestedPreferences = ExerciseLayoutPreferences(
            compositionPreset: .staffToPiano,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: false,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: true
        )
        let normalizedPreferences = LegacyPageLayoutAdapter.normalizedPreferences(
            requestedPreferences,
            trainerDisplayState: trainerDisplayState
        )
        if normalizedPreferences.compositionPreset != .staffToPiano {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 在 legacy adapter 的 normalize 阶段不应被提前改写成 legacy preset。"
                )
            )
        }
        if normalizedPreferences.isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 在 legacy adapter 的 normalize 阶段应强制关闭 piano accessory。"
                )
            )
        }

        let projectedPageDisplayState = LegacyPageLayoutAdapter
            .projectedPageDisplayState(
                from: requestedPreferences,
                trainerDisplayState: trainerDisplayState
            )
        if projectedPageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 在 legacy adapter 中应直接回落到默认 legacy page，而不是伪造新的 page 投影。"
                )
            )
        }

        var stateContext = SettingsPanelStateContext(
            pageDisplayState: .default,
            exerciseLayoutPreferences: requestedPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: PianoPanelState(isVisible: true)
        )
        LegacyPageLayoutAdapter.reconcile(&stateContext)
        if stateContext.exerciseLayoutPreferences.compositionPreset != .staffToPiano
            || stateContext.exerciseLayoutPreferences.isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "settings bridge 在回写 `staffToPiano` 时应保留该 preset，并继续压平 piano accessory。"
                )
            )
        }
        if stateContext.pageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "settings bridge 不应尝试把 `staffToPiano` 反投影成新的 legacy page 组合。"
                )
            )
        }
        if stateContext.pianoPanelState.isVisible {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 的 settings reconcile 应同步清掉 accessory piano 的显隐状态。"
                )
            )
        }

        let legacyCompatiblePresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: trainerDisplayState,
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: PianoPanelState(isVisible: true),
                    layoutPreferences: requestedPreferences
                )
            )
        if legacyCompatiblePresentation.resolvedLayoutPreferences.compositionPreset
            != .staffToFretboard
            || legacyCompatiblePresentation.resolvedLayoutPreferences.layoutPreset
            != .stacked {
            issues.append(
                issue(
                    fixtureName,
                    "显式请求 legacy-compatible presentation 时，`staffToPiano` 应回退到 legacy 可表达的 `staffToFretboard + stacked`。"
                )
            )
        }
        if legacyCompatiblePresentation.resolvedLayoutPreferences
            .isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "legacy-compatible fallback 不应把 piano accessory 带回 legacy scene。"
                )
            )
        }
        if legacyCompatiblePresentation.legacyPageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 的 legacy-compatible fallback 应继续回投影到默认 legacy page。"
                )
            )
        }

        return issues
    }

    static func validateStaffToNaturalNoteStripSkipsLegacyBackProjection()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "staff_to_natural_note_strip_skips_legacy_back_projection"
        var issues: [ExerciseCompositionValidationIssue] = []

        let trainerDisplayState = TrainerDisplayState(exerciseMode: .sr0)
        let requestedPreferences = ExerciseLayoutPreferences(
            compositionPreset: .staffToNaturalNoteStrip,
            layoutPreset: .stacked,
            accessoryPresentation: .docked,
            isNaturalNoteStripVisible: true,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: true
        )
        let normalizedPreferences = LegacyPageLayoutAdapter.normalizedPreferences(
            requestedPreferences,
            trainerDisplayState: trainerDisplayState
        )
        if normalizedPreferences.compositionPreset != .staffToNaturalNoteStrip {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 在 legacy adapter 的 normalize 阶段不应被提前改写成 legacy preset。"
                )
            )
        }
        if !normalizedPreferences.isNaturalNoteStripVisible
            || normalizedPreferences.isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 在 legacy adapter 的 normalize 阶段应保留主 strip，并继续压平 piano accessory。"
                )
            )
        }

        let projectedPageDisplayState = LegacyPageLayoutAdapter
            .projectedPageDisplayState(
                from: requestedPreferences,
                trainerDisplayState: trainerDisplayState
            )
        if projectedPageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 在 legacy adapter 中应直接回落到默认 legacy page，而不是伪造新的 page 投影。"
                )
            )
        }

        var stateContext = SettingsPanelStateContext(
            pageDisplayState: .default,
            exerciseLayoutPreferences: requestedPreferences,
            trainerDisplayState: trainerDisplayState,
            pianoPanelState: PianoPanelState(isVisible: true)
        )
        LegacyPageLayoutAdapter.reconcile(&stateContext)
        if stateContext.exerciseLayoutPreferences != .srNoteStripAnswer {
            issues.append(
                issue(
                    fixtureName,
                    "settings bridge 在回写 `staffToNaturalNoteStrip` 时应保留该 preset，并继续对齐到 `srNoteStripAnswer`。"
                )
            )
        }
        if stateContext.pageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "settings bridge 不应尝试把 `staffToNaturalNoteStrip` 反投影成新的 legacy page 组合。"
                )
            )
        }
        if stateContext.pianoPanelState.isVisible {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 的 settings reconcile 应同步清掉 accessory piano 的显隐状态。"
                )
            )
        }

        let legacyCompatiblePresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: trainerDisplayState,
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: PianoPanelState(isVisible: true),
                    layoutPreferences: requestedPreferences
                )
            )
        if legacyCompatiblePresentation.resolvedLayoutPreferences.compositionPreset
            != .staffToFretboard
            || legacyCompatiblePresentation.resolvedLayoutPreferences.layoutPreset
            != .stacked {
            issues.append(
                issue(
                    fixtureName,
                    "显式请求 legacy-compatible presentation 时，`staffToNaturalNoteStrip` 应回退到 legacy 可表达的 `staffToFretboard + stacked`。"
                )
            )
        }
        if legacyCompatiblePresentation.resolvedLayoutPreferences
            .isNaturalNoteStripVisible
            || legacyCompatiblePresentation.resolvedLayoutPreferences
            .isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "legacy-compatible fallback 不应把主 strip 或 piano accessory 带回 legacy scene。"
                )
            )
        }
        if legacyCompatiblePresentation.legacyPageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 的 legacy-compatible fallback 应继续回投影到默认 legacy page。"
                )
            )
        }

        return issues
    }

    static func validatePianoRecognitionModesFreezeStaffToPianoPolicyContracts()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "piano_recognition_modes_freeze_staff_to_piano_policy_contracts"
        var issues: [ExerciseCompositionValidationIssue] = []

        func validateMode(
            _ exerciseMode: TrainerExerciseMode,
            requestedAnswerPolicy: TrainerSequenceAnswerPolicy
        ) {
            guard exerciseMode.isPianoSequenceRecognitionMode else {
                issues.append(
                    issue(
                        fixtureName,
                        "\(String(describing: exerciseMode)) 应被标记为统一的 piano sequence recognition family 成员。"
                    )
                )
                return
            }
            guard let contract = exerciseMode
                .pianoSequenceRecognitionContract else {
                issues.append(
                    issue(
                        fixtureName,
                        "\(String(describing: exerciseMode)) 应暴露集中式 piano sequence recognition contract。"
                    )
                )
                return
            }
            let requestedClef: StaffClef = contract.fixedSequenceClef == .treble
                ? .bass
                : .treble
            let trainerDisplayState = TrainerDisplayState(
                exerciseMode: exerciseMode,
                sequenceConfiguration: TrainerSequenceConfiguration(
                    clef: requestedClef,
                    noteCount: 5,
                    includesAccidentals: true,
                    answerPolicy: requestedAnswerPolicy
                )
            )
            let requestedPreferences = ExerciseLayoutPreferences(
                compositionPreset: .targetPromptToFretboard,
                layoutPreset: .sideBySide,
                accessoryPresentation: .floating,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: true,
                isAccessoryExpanded: false
            )
            let modeDebugName = String(describing: exerciseMode)
            let resolvedSequenceConfiguration = trainerDisplayState
                .resolvedSequenceConfiguration
            let normalizedPreferences = ExerciseCompositionPolicy
                .normalizedPreferences(
                    requestedPreferences,
                    trainerDisplayState: trainerDisplayState
                )
            let normalizedLegacyPreferences = LegacyPageLayoutAdapter
                .normalizedPreferences(
                    requestedPreferences,
                    trainerDisplayState: trainerDisplayState
                )
            let requestedPianoSettingsSlice = PianoPanelSettingsSlice(
                rowCount: 4,
                movementScope: .cascade,
                whiteKeyStyle: .borderlessSeparatedByGaps,
                snapEnabled: false
            )
            let resolvedPianoSettingsSlice = exerciseMode
                .applyingFixedPianoSettings(to: requestedPianoSettingsSlice)

            if !trainerDisplayState.usesQuarterNoteSequenceKernel {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 应继续复用 quarter-note sequence kernel，而不是退回 single/position prompt 路径。"
                    )
                )
            }
            if exerciseMode.fixedCompositionPreset
                != contract.fixedExerciseLayoutPreferences.compositionPreset {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 fixedCompositionPreset 应与集中 recognition layout contract 对齐。"
                    )
                )
            }
            if exerciseMode.allowsAccessoryPianoPromotion {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 作为 fixed piano recognition mode，不应允许 accessory piano promotion。"
                    )
                )
            }
            if exerciseMode.fixedSequenceClef != contract.fixedSequenceClef {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 fixedSequenceClef 应直接来自 piano recognition contract。"
                    )
                )
            }
            if resolvedSequenceConfiguration.clef != contract.fixedSequenceClef {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 resolvedSequenceConfiguration.clef 应与集中 contract 对齐。"
                    )
                )
            }
            if exerciseMode.fixedSequenceAnswerPolicy
                != contract.fixedSequenceAnswerPolicy {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 fixedSequenceAnswerPolicy 应直接来自 piano recognition contract。"
                    )
                )
            }
            if resolvedSequenceConfiguration.answerPolicy
                != contract.fixedSequenceAnswerPolicy {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 resolvedSequenceConfiguration.answerPolicy 应固定为 \(contract.fixedSequenceAnswerPolicy)，而不是沿用请求值 \(requestedAnswerPolicy)。"
                    )
                )
            }
            if resolvedSequenceConfiguration.noteCount != 5
                || !resolvedSequenceConfiguration.includesAccidentals {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 只应钳制 clef / answerPolicy；noteCount 与 includesAccidentals 应继续保留用户配置。"
                    )
                )
            }
            if exerciseMode.fixedExerciseLayoutPreferences
                != contract.fixedExerciseLayoutPreferences {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 fixedExerciseLayoutPreferences 应直接来自 piano recognition contract。"
                    )
                )
            }
            if normalizedPreferences != contract.fixedExerciseLayoutPreferences {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 shared normalization 应统一收敛到固定的 staff-to-piano layout。"
                    )
                )
            }
            if normalizedLegacyPreferences != contract.fixedExerciseLayoutPreferences {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 settings / legacy bridge normalization 也应与 shared normalization 对齐。"
                    )
                )
            }
            if exerciseMode.fixedPianoRowCount != contract.fixedPianoRowCount {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 fixedPianoRowCount 应直接来自 piano recognition contract。"
                    )
                )
            }
            if exerciseMode.fixedPianoMovementScope
                != contract.fixedPianoMovementScope {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 fixedPianoMovementScope 应直接来自 piano recognition contract。"
                    )
                )
            }
            if resolvedPianoSettingsSlice.rowCount != contract.fixedPianoRowCount
                || resolvedPianoSettingsSlice.movementScope
                != contract.fixedPianoMovementScope {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 resolvedPianoSettingsSlice 应通过共享 helper 收敛到 contract 指定的行数与 movementScope。"
                    )
                )
            }
            if resolvedPianoSettingsSlice.whiteKeyStyle
                != requestedPianoSettingsSlice.whiteKeyStyle
                || resolvedPianoSettingsSlice.snapEnabled
                != requestedPianoSettingsSlice.snapEnabled {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 的 piano settings helper 只应覆盖 fixed 行数/移动策略，不应篡改其它 piano panel 设置。"
                    )
                )
            }
            if !ExerciseCompositionPolicy.isCompositionPresetSupported(
                .staffToPiano,
                for: exerciseMode
            ) {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 应显式支持 `staffToPiano` composition preset。"
                    )
                )
            }
            if ExerciseCompositionPolicy.isCompositionPresetSupported(
                .staffToFretboard,
                for: exerciseMode
            ) {
                issues.append(
                    issue(
                        fixtureName,
                        "\(modeDebugName) 不应再把 `staffToFretboard` 暴露成可选主场景，避免 recognition seam 漂回 legacy 组合。"
                    )
                )
            }
        }

        validateMode(
            .sr1,
            requestedAnswerPolicy: .exactNote
        )
        validateMode(
            .sr2,
            requestedAnswerPolicy: .pitchClass
        )
        validateMode(
            .bcr1,
            requestedAnswerPolicy: .exactNote
        )

        guard let sr1Contract = TrainerExerciseMode.sr1
                .pianoSequenceRecognitionContract,
              let sr2Contract = TrainerExerciseMode.sr2
                .pianoSequenceRecognitionContract,
              let bcr1Contract = TrainerExerciseMode.bcr1
                .pianoSequenceRecognitionContract else {
            issues.append(
                issue(
                    fixtureName,
                    "SR-1 / SR-2 / BCR-1 应共享可读取的 piano sequence recognition contract。"
                )
            )
            return issues
        }
        if sr1Contract.fixedSequenceClef != .treble
            || sr2Contract.fixedSequenceClef != .treble
            || bcr1Contract.fixedSequenceClef != .bass {
            issues.append(
                issue(
                    fixtureName,
                    "识别模式谱号应固定为 SR-1 / SR-2 = treble、BCR-1 = bass。"
                )
            )
        }
        if sr1Contract.fixedExerciseLayoutPreferences
            != sr2Contract.fixedExerciseLayoutPreferences
            || sr1Contract.fixedExerciseLayoutPreferences
            != bcr1Contract.fixedExerciseLayoutPreferences {
            issues.append(
                issue(
                    fixtureName,
                    "SR-1 / SR-2 / BCR-1 应共享同一份 staff-to-piano stacked layout。"
                )
            )
        }
        if sr1Contract.fixedExerciseLayoutPreferences.compositionPreset
            != .staffToPiano
            || sr2Contract.fixedExerciseLayoutPreferences.compositionPreset
            != .staffToPiano
            || bcr1Contract.fixedExerciseLayoutPreferences.compositionPreset
            != .staffToPiano {
            issues.append(
                issue(
                    fixtureName,
                    "SR-1 / SR-2 / BCR-1 的主场景都应显式锁死为 `staffToPiano`。"
                )
            )
        }
        if sr1Contract.fixedPianoMovementScope
            != sr2Contract.fixedPianoMovementScope
            || sr1Contract.fixedPianoMovementScope
            != bcr1Contract.fixedPianoMovementScope {
            issues.append(
                issue(
                    fixtureName,
                    "识别模式的 movementScope 应统一通过集中 contract 管理。"
                )
            )
        }
        if sr1Contract.fixedPianoMovementScope != .rowOnly
            || sr2Contract.fixedPianoMovementScope != .rowOnly
            || bcr1Contract.fixedPianoMovementScope != .rowOnly {
            issues.append(
                issue(
                    fixtureName,
                    "piano sequence recognition family 应继续锁死 rowOnly。"
                )
            )
        }
        if sr1Contract.fixedPianoRowCount != 1
            || sr2Contract.fixedPianoRowCount != 2
            || bcr1Contract.fixedPianoRowCount != 1 {
            issues.append(
                issue(
                    fixtureName,
                    "钢琴行数应固定为 SR-1 / BCR-1 = 1 row、SR-2 = 2 rows。"
                )
            )
        }
        if sr1Contract.fixedSequenceAnswerPolicy != .pitchClass
            || sr2Contract.fixedSequenceAnswerPolicy != .exactNote
            || bcr1Contract.fixedSequenceAnswerPolicy != .pitchClass {
            issues.append(
                issue(
                    fixtureName,
                    "判题策略应固定为 SR-1 / BCR-1 = .pitchClass、SR-2 = .exactNote。"
                )
            )
        }

        return issues
    }

    static func validateSR0ModeFreezesStaffToNaturalNoteStripPolicyContracts()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "sr0_mode_freezes_staff_to_natural_note_strip_policy_contracts"
        var issues: [ExerciseCompositionValidationIssue] = []
        let trainerDisplayState = TrainerDisplayState(
            exerciseMode: .sr0,
            sequenceConfiguration: TrainerSequenceConfiguration(
                clef: .bass,
                noteCount: 5,
                includesAccidentals: true,
                answerPolicy: .exactNote
            )
        )
        let requestedPreferences = ExerciseLayoutPreferences(
            compositionPreset: .targetPromptToFretboard,
            layoutPreset: .sideBySide,
            accessoryPresentation: .floating,
            isNaturalNoteStripVisible: false,
            isPianoAccessoryVisible: true,
            isAccessoryExpanded: false
        )
        let resolvedSequenceConfiguration = trainerDisplayState
            .resolvedSequenceConfiguration
        let normalizedPreferences = ExerciseCompositionPolicy
            .normalizedPreferences(
                requestedPreferences,
                trainerDisplayState: trainerDisplayState
            )
        let normalizedLegacyPreferences = LegacyPageLayoutAdapter
            .normalizedPreferences(
                requestedPreferences,
                trainerDisplayState: trainerDisplayState
            )
        let requestedPianoSettingsSlice = PianoPanelSettingsSlice(
            rowCount: 4,
            movementScope: .cascade,
            whiteKeyStyle: .borderlessSeparatedByGaps,
            snapEnabled: false
        )
        let resolvedPianoSettingsSlice = trainerDisplayState.exerciseMode
            .applyingFixedPianoSettings(to: requestedPianoSettingsSlice)

        if !trainerDisplayState.usesQuarterNoteSequenceKernel {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 应继续复用 quarter-note sequence kernel，而不是退回 single/position prompt 路径。"
                )
            )
        }
        if trainerDisplayState.exerciseMode.fixedCompositionPreset
            != .staffToNaturalNoteStrip {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 的 fixedCompositionPreset 应固定为 `staffToNaturalNoteStrip`。"
                )
            )
        }
        if trainerDisplayState.exerciseMode.allowsAccessoryPianoPromotion {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 作为 fixed layout mode，不应允许 accessory piano promotion。"
                )
            )
        }
        if resolvedSequenceConfiguration.clef != .treble {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 的 resolvedSequenceConfiguration 应强制锁定 treble clef。"
                )
            )
        }
        if resolvedSequenceConfiguration.answerPolicy != .pitchClass {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 的 resolvedSequenceConfiguration.answerPolicy 应固定为 .pitchClass。"
                )
            )
        }
        if resolvedSequenceConfiguration.noteCount != 5
            || !resolvedSequenceConfiguration.includesAccidentals {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 mode constraint 只应钳制 clef / answerPolicy；noteCount 与 includesAccidentals 应继续保留用户配置。"
                )
            )
        }
        if resolvedPianoSettingsSlice != requestedPianoSettingsSlice {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 不应继承 piano sequence recognition family 的固定 piano settings helper；其 piano panel 设置应保持原样。"
                )
            )
        }
        if normalizedPreferences != .srNoteStripAnswer {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 的 shared normalization 应统一收敛到固定的 SR staff-to-natural-note-strip layout。"
                )
            )
        }
        if normalizedLegacyPreferences != .srNoteStripAnswer {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 的 settings / legacy bridge normalization 也应与 shared normalization 对齐到同一份 SR layout 常量。"
                )
            )
        }
        if !ExerciseCompositionPolicy.isCompositionPresetSupported(
            .staffToNaturalNoteStrip,
            for: .sr0
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 应显式支持 `staffToNaturalNoteStrip` composition preset。"
                )
            )
        }
        if ExerciseCompositionPolicy.isCompositionPresetSupported(
            .staffToFretboard,
            for: .sr0
        ) || ExerciseCompositionPolicy.isCompositionPresetSupported(
            .staffToPiano,
            for: .sr0
        ) || ExerciseCompositionPolicy.isCompositionPresetSupported(
            .fretboardToNaturalNoteStrip,
            for: .sr0
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 不应暴露 `staffToFretboard` / `staffToPiano` / `fretboardToNaturalNoteStrip` 等其它主场景 preset，避免模式语义漂移。"
                )
            )
        }
        if trainerDisplayState.exerciseMode.fixedPianoRowCount != nil
            || trainerDisplayState.exerciseMode.fixedPianoMovementScope != nil {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 不应继承 SR-1/SR-2 的 piano 固定行数或 movement scope 约束。"
                )
            )
        }

        return issues
    }

    static func validateLegacyCompatiblePolicyFallsBackWhenSceneExceedsPageModel()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "legacy_compatible_policy_falls_back_when_scene_exceeds_page_model"
        var issues: [ExerciseCompositionValidationIssue] = []

        let sideBySideLegacyPresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .single
                    ),
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .targetPromptToFretboard,
                        layoutPreset: .sideBySide
                    )
                )
            )
        if sideBySideLegacyPresentation.resolvedLayoutPreferences.layoutPreset
            != .stacked {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应把 sideBySide 回退到 stacked。"
                )
            )
        }
        if sideBySideLegacyPresentation.resolvedLayoutPreferences.compositionPreset
            != .targetPromptToFretboard {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口在能保留 targetPrompt -> fretboard 时不应错误回退到 staff -> fretboard。"
                )
            )
        }
        if sideBySideLegacyPresentation.legacyPageDisplayState
            != PageDisplayState(
                topContentMode: .targetPrompt,
                mainContentMode: .fretboard
            ) {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应把 targetPrompt -> fretboard 回投影为 legacy targetPrompt 页面。"
                )
            )
        }

        let selfAnswerLegacyPresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .positionPrompt
                    ),
                    fretboardTrainerState: .init(positionPromptMode: ()),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: .singleFretboardSelfAnswer
                )
            )
        if selfAnswerLegacyPresentation.resolvedLayoutPreferences.compositionPreset
            != .fretboardToNaturalNoteStrip
            || selfAnswerLegacyPresentation.resolvedLayoutPreferences.layoutPreset
            != .stacked {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应把 single fretboard self-answer 回退到 stacked 的 fretboard -> natural note strip。"
                )
            )
        }
        if selfAnswerLegacyPresentation.legacyPageDisplayState != .positionPrompt {
            issues.append(
                issue(
                    fixtureName,
                    "single fretboard self-answer 的 legacy fallback 应继续投影到 positionPrompt 页面。"
                )
            )
        }

        let floatingAccessoryLegacyPresentation = ExerciseCompositionPolicy
            .makeLegacyCompatiblePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: TrainerDisplayState(
                        exerciseMode: .single
                    ),
                    fretboardTrainerState: .init(),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .staffToFretboard,
                        layoutPreset: .stacked,
                        accessoryPresentation: .floating,
                        isNaturalNoteStripVisible: true,
                        isPianoAccessoryVisible: true
                    )
                )
            )
        if floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .accessoryPresentation != .docked
            || floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .isNaturalNoteStripVisible
            || floatingAccessoryLegacyPresentation.resolvedLayoutPreferences
            .isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "legacy 兼容入口应清空可选 accessory scene，只保留 page model 能表达的 docked 主视觉组合。"
                )
            )
        }
        if floatingAccessoryLegacyPresentation.legacyPageDisplayState != .default {
            issues.append(
                issue(
                    fixtureName,
                    "带 floating accessory 请求的 legacy fallback 仍应继续回投影到默认 single 页面。"
                )
            )
        }

        return issues
    }
    static func validateSharedAnswerContractsDefaultPositionPromptToSamePitchClass()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_answer_contracts_default_position_prompt_to_same_pitch_class"
        var issues: [ExerciseCompositionValidationIssue] = []

        let defaultConfiguration = TrainerPositionPromptConfiguration.default
        if defaultConfiguration.answerRule != .samePitchClass {
            issues.append(
                issue(
                    fixtureName,
                    "PositionPromptAnswerRule 首版默认值应为 samePitchClass。"
                )
            )
        }

        var trainerDisplayState = TrainerDisplayState(exerciseMode: .positionPrompt)
        if trainerDisplayState.positionPromptAnswerRule != .samePitchClass {
            issues.append(
                issue(
                    fixtureName,
                    "TrainerDisplayState 应暴露 samePitchClass 作为 positionPrompt 的默认答题规则。"
                )
            )
        }
        trainerDisplayState.setPositionPromptAnswerRule(.samePitchClass)
        if trainerDisplayState.positionPromptConfiguration.answerRule
            != .samePitchClass {
            issues.append(
                issue(
                    fixtureName,
                    "设置 positionPrompt answer rule 后，应写回到 positionPromptConfiguration。"
                )
            )
        }

        let fretboardCellEvent = ExerciseAnswerEvent.fretboardCell(
            FretboardCell(stringIndex: 2, fret: 3),
            from: .fretboard
        )
        if fretboardCellEvent.surfaceID != .fretboard
            || fretboardCellEvent.payload.fretboardCell
                != FretboardCell(stringIndex: 2, fret: 3) {
            issues.append(
                issue(
                    fixtureName,
                    "ExerciseAnswerEvent 应保留 fretboardCell payload 与来源 surfaceID。"
                )
            )
        }

        let pitchClassEvent = ExerciseAnswerEvent.pitchClass(
            .c,
            from: .naturalNoteStrip
        )
        if pitchClassEvent.surfaceID != .naturalNoteStrip
            || pitchClassEvent.payload.pitchClass != .c {
            issues.append(
                issue(
                    fixtureName,
                    "ExerciseAnswerEvent 应保留 pitchClass payload 与来源 surfaceID。"
                )
            )
        }

        let notePitchEvent = ExerciseAnswerEvent.notePitch(
            NotePitch(pitchClass: .c, octave: 4),
            from: .piano
        )
        if notePitchEvent.surfaceID != .piano
            || notePitchEvent.payload.notePitch
                != NotePitch(pitchClass: .c, octave: 4)
            || notePitchEvent.payload.pitchClass != .c {
            issues.append(
                issue(
                    fixtureName,
                    "ExerciseAnswerEvent 应保留 notePitch payload、pitchClass 投影与来源 surfaceID。"
                )
            )
        }

        return issues
    }

    static func validateAnswerRouterRoutesStackedSideAndSingleSurfaceAnswers()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "answer_router_routes_stacked_side_and_single_surface_answers"
        var issues: [ExerciseCompositionValidationIssue] = []
        let fretboardConfiguration = FretboardConfiguration()
        let answerCell = FretboardCell(stringIndex: 0, fret: 0)
        guard let answerNotePitch = fretboardConfiguration.notePitch(
            for: answerCell
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 5 的 answer router 夹具需要一个可解析为 note pitch 的 fretboard cell。"
                )
            )
            return issues
        }
        let answerPitchClass = answerNotePitch.pitchClass

        let singleTrainerDisplayState = TrainerDisplayState(exerciseMode: .single)
        let stackedSinglePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: singleTrainerDisplayState,
                fretboardTrainerState: .init(targetPitchClass: .c),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .default
            )
        )
        let sequenceTrainerDisplayState = TrainerDisplayState(exerciseMode: .sequence)
        let stackedSequencePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: sequenceTrainerDisplayState,
                fretboardTrainerState: .init(
                    quarterNoteSequenceSpec: sequenceTrainerDisplayState
                        .sequenceConfiguration
                        .quarterNoteSequenceSpec
                ),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .default
            )
        )
        let fretboardCellEvent = ExerciseAnswerEvent.fretboardCell(
            answerCell,
            from: .fretboard
        )
        if ExerciseAnswerRouter.route(
            fretboardCellEvent,
            presentationState: stackedSinglePresentation,
            trainerDisplayState: singleTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .singleCoverage(
                event: fretboardCellEvent,
                cell: answerCell
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "上下布局中的单音训练应把 fretboardCell 事件路由到 singleCoverage answer。"
                )
            )
        }
        if ExerciseAnswerRouter.route(
            fretboardCellEvent,
            presentationState: stackedSequencePresentation,
            trainerDisplayState: sequenceTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .quarterNoteSequence(
                event: fretboardCellEvent,
                answer: ResolvedSequenceAnswer(
                    pitchClass: answerPitchClass,
                    notePitch: answerNotePitch,
                    surfaceID: .fretboard
                )
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "上下布局中的 sequence 应把 fretboardCell 事件路由为携带 pitchClass 与 notePitch 的 ResolvedSequenceAnswer。"
                )
            )
        }
        let absentStripEvent = ExerciseAnswerEvent.pitchClass(
            .c,
            from: .naturalNoteStrip
        )
        if ExerciseAnswerRouter.route(
            absentStripEvent,
            presentationState: stackedSinglePresentation,
            trainerDisplayState: singleTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .ignored(.surfaceUnavailable(.naturalNoteStrip)) {
            issues.append(
                issue(
                    fixtureName,
                    "未投影的 natural note strip 事件应继续被 answer router 判定为 surfaceUnavailable，而不是退化成 hidden/disabled。"
                )
            )
        }

        let positionPromptTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .positionPrompt
        )
        let sideBySidePositionPromptPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: positionPromptTrainerDisplayState,
                    fretboardTrainerState: .init(positionPromptMode: ()),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .fretboardToNaturalNoteStrip,
                        layoutPreset: .sideBySide
                    )
                )
            )
        let naturalNoteStripEvent = ExerciseAnswerEvent.pitchClass(
            .e,
            from: .naturalNoteStrip
        )
        if ExerciseAnswerRouter.route(
            naturalNoteStripEvent,
            presentationState: sideBySidePositionPromptPresentation,
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .positionPrompt(
                ExercisePositionPromptRoutedAnswer(
                    event: naturalNoteStripEvent,
                    pitchClass: .e
                )
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "左右布局中的 positionPrompt 应允许 natural note strip 继续作为可选 answer surface。"
                )
            )
        }

        let stackedPositionPromptPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: positionPromptTrainerDisplayState,
                    fretboardTrainerState: .init(positionPromptMode: ()),
                    fretboardDisplayState: .default,
                    staffDisplayState: .default,
                    pianoPanelState: .init(),
                    layoutPreferences: ExerciseLayoutPreferences(
                        compositionPreset: .fretboardToNaturalNoteStrip,
                        layoutPreset: .stacked,
                        accessoryPresentation: .docked,
                        isNaturalNoteStripVisible: true,
                        isPianoAccessoryVisible: false,
                        isAccessoryExpanded: true
                    )
                )
            )
        if ExerciseAnswerRouter.route(
            naturalNoteStripEvent,
            presentationState: stackedPositionPromptPresentation,
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .positionPrompt(
                ExercisePositionPromptRoutedAnswer(
                    event: naturalNoteStripEvent,
                    pitchClass: .e
                )
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "上下布局中的 positionPrompt 应继续允许 natural note strip 作为 answer surface。"
                )
            )
        }
        if ExerciseAnswerRouter.route(
            fretboardCellEvent,
            presentationState: stackedPositionPromptPresentation,
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .ignored(.answerDisabled(.fretboard)) {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 positionPrompt 里，prompt-only fretboard 不应再被当成唯一答题入口。"
                )
            )
        }

        let sr0TrainerDisplayState = TrainerDisplayState(exerciseMode: .sr0)
        let stackedSR0Presentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: sr0TrainerDisplayState,
                fretboardTrainerState: .init(
                    quarterNoteSequenceSpec: sr0TrainerDisplayState
                        .resolvedSequenceConfiguration
                        .quarterNoteSequenceSpec
                ),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .srNoteStripAnswer
            )
        )
        if ExerciseAnswerRouter.route(
            naturalNoteStripEvent,
            presentationState: stackedSR0Presentation,
            trainerDisplayState: sr0TrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .quarterNoteSequence(
                event: naturalNoteStripEvent,
                answer: ResolvedSequenceAnswer(
                    pitchClass: .e,
                    notePitch: nil,
                    surfaceID: .naturalNoteStrip
                )
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 的双行 natural note strip 点击应继续路由到 quarterNoteSequence，并保持 pitchClass-only 的 sequence 答案载体。"
                )
            )
        }
        if ExerciseAnswerRouter.route(
            fretboardCellEvent,
            presentationState: stackedSR0Presentation,
            trainerDisplayState: sr0TrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .ignored(.surfaceUnavailable(.fretboard)) {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 主场景不包含 fretboard 时，fretboardCell 事件应继续被判定为 surfaceUnavailable，而不是误路由到 sequence 答题链。"
                )
            )
        }

        let selfAnswerPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: positionPromptTrainerDisplayState,
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: .singleFretboardSelfAnswer
            )
        )
        if ExerciseAnswerRouter.route(
            fretboardCellEvent,
            presentationState: selfAnswerPresentation,
            trainerDisplayState: positionPromptTrainerDisplayState,
            fretboardConfiguration: fretboardConfiguration
        ) != .routed(
            .positionPrompt(
                ExercisePositionPromptRoutedAnswer(
                    event: fretboardCellEvent,
                    pitchClass: answerPitchClass
                )
            )
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "单 fretboard self-answer 应把 fretboardCell 解析成 pitch class，并继续路由到 positionPrompt answer。"
                )
            )
        }

        return issues
    }
}

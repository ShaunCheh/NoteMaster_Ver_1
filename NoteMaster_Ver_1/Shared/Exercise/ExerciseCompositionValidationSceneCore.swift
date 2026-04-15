//
//  ExerciseCompositionValidationSceneCore.swift
//  NoteMaster_Ver_1
//
//  Scene graph, surface membership, scene validator, and natural-note-strip layout contracts
//  for automated exercise composition validation.
//

import CoreGraphics
import Foundation

extension ExerciseCompositionValidationRunner {

    static func validateSharedSceneContractsCoverBasicLayouts()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_scene_contracts_cover_stacked_side_by_side_and_single_surface"
        var issues: [ExerciseCompositionValidationIssue] = []

        let stackedScene = ExerciseScene.stacked(
            top: .staffPrompt,
            bottom: .fretboardAnswer
        )
        switch stackedScene.root {
        case let .split(axis, children):
            if axis != .vertical {
                issues.append(
                    issue(
                        fixtureName,
                        "stacked scene 应落成 vertical split。"
                    )
                )
            }
            let childSurfaceIDs = children.compactMap {
                $0.node.surfaceNodes.first?.id
            }
            if childSurfaceIDs != [.staff, .fretboard] {
                issues.append(
                    issue(
                        fixtureName,
                        "stacked scene 应保持 staff 在上、fretboard 在下。"
                    )
                )
            }
            if children.count != 2
                || children[0].mainAxisSizing != .fitContent
                || children[1].mainAxisSizing != .weighted(1) {
                issues.append(
                    issue(
                        fixtureName,
                        "stacked scene 应继续保持上方 staff fitContent、下方 fretboard weighted(1) 的主轴尺寸语义。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "stacked scene 的根节点应为 split。"
                )
            )
        }

        let sideBySideScene = ExerciseScene.sideBySide(
            leading: .targetPrompt,
            trailing: .fretboardAnswer
        )
        switch sideBySideScene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "sideBySide scene 应落成 horizontal split。"
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
                        "sideBySide scene 应保持 targetPrompt 在左、fretboard 在右。"
                    )
                )
            }
            if children.count != 2
                || !children[0].mainAxisSizing.isWeighted
                || !children[1].mainAxisSizing.isWeighted {
                issues.append(
                    issue(
                        fixtureName,
                        "sideBySide scene 在阶段 1 应继续保持双 weighted 的默认主轴尺寸语义。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide scene 的根节点应为 split。"
                )
            )
        }

        let singleSurfaceScene = ExerciseScene.singleSurface(
            .fretboardPromptAndAnswer
        )
        switch singleSurfaceScene.root {
        case let .surface(surface):
            if surface.id != .fretboard || surface.kind != .fretboard {
                issues.append(
                    issue(
                        fixtureName,
                        "singleSurface scene 应落到单个 fretboard surface。"
                    )
                )
            }
            if !surface.roles.contains(.prompt)
                || !surface.roles.contains(.answer) {
                issues.append(
                    issue(
                        fixtureName,
                        "singleSurface scene 中的 fretboard 应同时承担 prompt 与 answer。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "singleSurface scene 的根节点应为 surface。"
                )
            )
        }

        return issues
    }

    static func validateSharedSceneContractExposesPresentationStylesAndMainAxisSizing()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_scene_contract_exposes_presentation_styles_and_main_axis_sizing"
        var issues: [ExerciseCompositionValidationIssue] = []

        if ExerciseSurfaceNode.staffPrompt.presentationStyle != .standard
            || ExerciseSurfaceNode.fretboardAnswer.presentationStyle != .standard
            || ExerciseSurfaceNode.targetPrompt.presentationStyle != .standard {
            issues.append(
                issue(
                    fixtureName,
                    "非 strip surface 在阶段 1 应默认保持 standard presentation style。"
                )
            )
        }

        if ExerciseSurfaceNode.naturalNoteStripAnswer.presentationStyle
            != .horizontalStrip
            || ExerciseSurfaceNode.naturalNoteStripAccessory.presentationStyle
            != .horizontalStrip {
            issues.append(
                issue(
                    fixtureName,
                    "natural note strip 的静态 surface 节点在阶段 1 应默认保持 horizontalStrip presentation style。"
                )
            )
        }

        let verticalRailStrip = ExerciseSurfaceNode.naturalNoteStripAnswer
            .withPresentationStyle(.verticalRail)
        if verticalRailStrip.id != .naturalNoteStrip
            || verticalRailStrip.kind != .naturalNoteStrip
            || verticalRailStrip.roles != Set([.answer])
            || verticalRailStrip.presentationStyle != .verticalRail {
            issues.append(
                issue(
                    fixtureName,
                    "withPresentationStyle(.verticalRail) 应只修改 strip 的 presentation style，不改变 logical surface 身份。"
                )
            )
        }
        if ExerciseSurfaceNode.naturalNoteStripAnswer.presentationStyle
            != .horizontalStrip {
            issues.append(
                issue(
                    fixtureName,
                    "withPresentationStyle(...) 应返回副本，不应回写静态 natural note strip surface。"
                )
            )
        }

        let stackedMixedScene = ExerciseScene.stacked(
            top: .fretboardPrompt,
            bottom: .naturalNoteStripAnswer
        )
        if !stackedMixedScene.hasMixedMainAxisSizing(along: .vertical) {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 1 应能被 shared helper 识别为 vertical mixed main-axis sizing。"
                )
            )
        }
        if !stackedMixedScene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "包含 vertical mixed main-axis sizing 的 scene 在阶段 1 应继续要求 viewport pin 高度。"
                )
            )
        }

        let railScene = ExerciseScene(
            root: .makeSplit(
                axis: .horizontal,
                children: [
                    ExerciseSceneSplitChild(
                        node: .surface(.fretboardPrompt),
                        mainAxisSizing: .weighted(1)
                    ),
                    ExerciseSceneSplitChild(
                        node: .surface(verticalRailStrip),
                        mainAxisSizing: .fitContent
                    )
                ]
            )
        )
        if !railScene.hasMixedMainAxisSizing(along: .horizontal) {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 horizontal split 在阶段 1 应能被 shared contract 表达为 mixed main-axis sizing。"
                )
            )
        }
        if railScene.hasMixedMainAxisSizing(along: .vertical) {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 horizontal split 在阶段 1 不应误报为 vertical mixed main-axis sizing。"
                )
            )
        }
        if !railScene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "包含 verticalRail surface 的 scene 在阶段 1 应能通过 shared helper 要求 viewport pin 高度。"
                )
            )
        }

        return issues
    }

    static func validateSchemeOneHorizontalStripSemanticBoundaryStaysDistinctFromVerticalRail()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "scheme_one_horizontal_strip_semantic_boundary_stays_distinct_from_vertical_rail"
        var issues: [ExerciseCompositionValidationIssue] = []

        let expectedAccidentals: [PitchClass] = [
            .cSharp,
            .dSharp,
            .fSharp,
            .gSharp,
            .aSharp
        ]
        if PitchClass.accidentalCasesInOrder != expectedAccidentals {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 应把 horizontalStrip 的顶行来源冻结为 C#-D#-F#-G#-A#，对应上方半音按钮。"
                )
            )
        }
        if !PitchClass.accidentalCasesInOrder.allSatisfy(\.isAccidental) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 不应把自然音混进 horizontalStrip 的顶行 accidental source。"
                )
            )
        }

        let expectedNaturals: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
        if PitchClass.naturalCasesInOrder != expectedNaturals {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 应把 horizontalStrip 的底行来源冻结为 C-D-E-F-G-A-B，对应下方自然音按钮。"
                )
            )
        }
        if !PitchClass.naturalCasesInOrder.allSatisfy(\.isNatural) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 不应把半音混进 horizontalStrip 的底行 natural source。"
                )
            )
        }

        let horizontalStripPitchSet = Set(
            PitchClass.accidentalCasesInOrder + PitchClass.naturalCasesInOrder
        )
        if horizontalStripPitchSet.count != PitchClass.allCases.count
            || horizontalStripPitchSet != Set(PitchClass.allCases) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 应让 horizontalStrip 的上下两行合起来恰好覆盖 12 个 PitchClass，避免遗漏或重复。"
                )
            )
        }
        if !Set(PitchClass.accidentalCasesInOrder).isDisjoint(
            with: Set(PitchClass.naturalCasesInOrder)
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 应保证 horizontalStrip 的顶行与底行语义彼此正交，不共享 PitchClass。"
                )
            )
        }

        let stackedPositionPromptPresentation = ExerciseCompositionPolicy
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
                        layoutPreset: .stacked
                    )
                )
            )
        switch stackedPositionPromptPresentation.scene.root {
        case let .split(axis, children):
            if axis != .vertical {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 0 的 stacked strip 场景应继续保持 vertical split，明确它属于底部 horizontalStrip 语境。"
                    )
                )
            }
            guard
                children.count == 2,
                case let .surface(promptSurface) = children[0].node,
                case let .surface(answerSurface) = children[1].node
            else {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 0 的 stacked strip 场景应继续稳定投影为上 prompt、下 answer 的双 surface 结构。"
                    )
                )
                break
            }
            if promptSurface.id != .fretboard
                || promptSurface.presentationStyle != .standard
                || answerSurface.id != .naturalNoteStrip
                || answerSurface.presentationStyle != .horizontalStrip {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 0 应把 stacked 的 fretboard -> strip 场景冻结为上方 standard fretboard、下方 horizontalStrip；该 horizontalStrip 的产品语义固定为上半音、下自然音。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 的 stacked strip 场景应继续落成 split scene，而不是退化为单 surface 或 overlay。"
                )
            )
        }

        let sidePositionPromptPresentation = ExerciseCompositionPolicy
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
        switch sidePositionPromptPresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 0 的 side strip 场景应继续保持 horizontal split，明确它属于右侧 verticalRail 语境。"
                    )
                )
            }
            guard
                children.count == 2,
                case let .surface(promptSurface) = children[0].node,
                case let .surface(answerSurface) = children[1].node
            else {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 0 的 side strip 场景应继续稳定投影为左 prompt、右 answer 的双 surface 结构。"
                    )
                )
                break
            }
            if promptSurface.id != .fretboard
                || promptSurface.presentationStyle != .standard
                || answerSurface.id != .naturalNoteStrip
                || answerSurface.presentationStyle != .verticalRail {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 0 应继续把 side 的 fretboard -> strip 场景冻结为左侧 standard fretboard、右侧 verticalRail，防止方案一误伤既有 rail 语义。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "阶段 0 的 side strip 场景应继续落成 split scene，而不是被 horizontalStrip 语义吞并。"
                )
            )
        }

        return issues
    }

    static func validateNaturalNoteStripHorizontalLayoutContextFreezesTwoRowDefaults()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "natural_note_strip_horizontal_layout_context_freezes_two_row_defaults"
        var issues: [ExerciseCompositionValidationIssue] = []

        let expectedGeometry =
            ExerciseNaturalNoteStripHorizontalGeometry
            .defaultTwoRowHorizontalStrip(
                buttonExtent:
                    ExerciseNaturalNoteStripHorizontalGeometry.defaultButtonExtent
            )
        let expectedContext = ExerciseNaturalNoteStripHorizontalLayoutContext(
            appliesToSurface: .naturalNoteStrip,
            titleDisplayPolicy:
                ExerciseNaturalNoteStripHorizontalLayoutContext
                .defaultTitleDisplayPolicy,
            geometry: expectedGeometry,
            accidentalPitchClasses: PitchClass.accidentalCasesInOrder,
            naturalPitchClasses: PitchClass.naturalCasesInOrder
        )

        let stackedPositionPromptPresentation = ExerciseCompositionPolicy
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
                        layoutPreset: .stacked
                    )
                )
            )
        if stackedPositionPromptPresentation.naturalNoteStripHorizontalLayoutContext
            != expectedContext {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 stacked horizontalStrip scene 应暴露默认双行 layoutContext：allPitchClasses 标题、共享 geometry token，以及上半音/下自然音顺序。"
                )
            )
        }
        if stackedPositionPromptPresentation.scene
            .naturalNoteStripHorizontalLayoutContext
            != stackedPositionPromptPresentation
                .naturalNoteStripHorizontalLayoutContext {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 ExerciseScene 应把 horizontalStrip layoutContext 原样透传给 presentation 层。"
                )
            )
        }

        let accessoryStripPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .single),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToFretboard,
                    layoutPreset: .stacked,
                    accessoryPresentation: .docked,
                    isNaturalNoteStripVisible: true,
                    isPianoAccessoryVisible: false,
                    isAccessoryExpanded: true
                )
            )
        )
        if accessoryStripPresentation.naturalNoteStripHorizontalLayoutContext
            != expectedContext {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 accessory horizontalStrip scene 也应复用同一份双行 layoutContext，而不是只给主 answer strip 暴露 contract。"
                )
            )
        }

        let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
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
        if sideRailPresentation.naturalNoteStripHorizontalLayoutContext != nil
            || sideRailPresentation.scene.naturalNoteStripHorizontalLayoutContext
            != nil {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 verticalRail scene 不应误暴露 horizontalStrip layoutContext。"
                )
            )
        }

        let targetPromptSideBySidePresentation = ExerciseCompositionPolicy
            .makePresentation(
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
        if targetPromptSideBySidePresentation.naturalNoteStripHorizontalLayoutContext
            != nil
            || targetPromptSideBySidePresentation.scene
                .naturalNoteStripHorizontalLayoutContext != nil {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的非 strip scene 不应误暴露 horizontalStrip layoutContext。"
                )
            )
        }

        return issues
    }

    static func validateNaturalNoteStripHorizontalLayoutBuilderExposesSharedLayoutOutput()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "natural_note_strip_horizontal_layout_builder_exposes_shared_layout_output"
        var issues: [ExerciseCompositionValidationIssue] = []

        let stackedPositionPromptPresentation = ExerciseCompositionPolicy
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
                        layoutPreset: .stacked
                    )
                )
            )

        switch stackedPositionPromptPresentation.naturalNoteStripHorizontalLayout {
        case let .some(layout):
            if layout.context
                != stackedPositionPromptPresentation
                    .naturalNoteStripHorizontalLayoutContext {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的 shared horizontal layout 应直接引用当前 presentation 暴露的 layoutContext。"
                    )
                )
            }
            if layout.accidentalPlacements.map(\.pitchClass)
                != PitchClass.accidentalCasesInOrder {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的 shared horizontal layout 应按固定顺序输出顶部半音 placements。"
                    )
                )
            }
            if layout.naturalPlacements.map(\.pitchClass)
                != PitchClass.naturalCasesInOrder {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的 shared horizontal layout 应按固定顺序输出底部自然音 placements。"
                    )
                )
            }
            if layout.contentSize.width <= 0 || layout.contentSize.height <= 0 {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的 shared horizontal layout 应产出正值 contentSize，而不是零尺寸布局。"
                    )
                )
            }
            if layout.placementsInDisplayOrder.contains(where: { !$0.showsTitle }) {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的默认双行 horizontalStrip layout 在 allPitchClasses 策略下，不应遗漏任何按钮标题可见性。"
                    )
                )
            }
        case .none:
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 stacked horizontalStrip scene 应暴露 active shared horizontal layout，而不是 nil。"
                )
            )
        }

        if stackedPositionPromptPresentation.scene.naturalNoteStripHorizontalLayout
            != stackedPositionPromptPresentation
                .naturalNoteStripHorizontalLayout {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 ExerciseScene 应把 shared horizontal layout 原样透传给 presentation 层。"
                )
            )
        }

        let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
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
        if sideRailPresentation.naturalNoteStripHorizontalLayout != nil
            || sideRailPresentation.scene.naturalNoteStripHorizontalLayout != nil {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的 verticalRail scene 不应误暴露 shared horizontal layout。"
                )
            )
        }

        return issues
    }

    static func validateNaturalNoteStripHorizontalLayoutPreservesRowTopologyAndContentSize()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "natural_note_strip_horizontal_layout_preserves_row_topology_and_content_size"
        var issues: [ExerciseCompositionValidationIssue] = []

        let stackedPositionPromptPresentation = ExerciseCompositionPolicy
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
                        layoutPreset: .stacked
                    )
                )
            )

        guard let layout = stackedPositionPromptPresentation
            .naturalNoteStripHorizontalLayout else {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 应能从 stacked horizontalStrip presentation 读到 active shared horizontal layout。"
                )
            )
            return issues
        }

        if layout.accidentalPlacements.contains(where: {
            $0.row != .accidentalsTop
        }) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的顶部 placements 应全部固定在 accidentalsTop 行。"
                )
            )
        }
        if layout.naturalPlacements.contains(where: {
            $0.row != .naturalsBottom
        }) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的底部 placements 应全部固定在 naturalsBottom 行。"
                )
            )
        }

        if layout.accidentalPlacements.map(\.columnIndex)
            != Array(layout.accidentalPlacements.indices) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的顶部半音 placements 应继续以 0..<count 的列索引顺序输出。"
                )
            )
        }
        if layout.naturalPlacements.map(\.columnIndex)
            != Array(layout.naturalPlacements.indices) {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的底部自然音 placements 应继续以 0..<count 的列索引顺序输出。"
                )
            )
        }

        let geometry = layout.context.geometry
        let expectedAccidentalWidth = geometry.rowContentWidth(
            columnCount: PitchClass.accidentalCasesInOrder.count
        )
        let expectedNaturalWidth = geometry.rowContentWidth(
            columnCount: PitchClass.naturalCasesInOrder.count
        )
        let expectedContentSize = geometry.twoRowContentSize(
            topColumnCount: PitchClass.accidentalCasesInOrder.count,
            bottomColumnCount: PitchClass.naturalCasesInOrder.count
        )
        if layout.contentSize != expectedContentSize {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的双行 horizontalStrip contentSize 应继续由共享 geometry token 和上下两行按钮数共同决定。"
                )
            )
        }
        if expectedNaturalWidth <= expectedAccidentalWidth {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的共享几何语义应继续保证 7 个自然音行宽大于 5 个半音行宽。"
                )
            )
        }
        if layout.contentSize.width != expectedNaturalWidth {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 的双行 horizontalStrip 总宽度应继续由较宽的自然音行驱动，而不是错误取半音行宽。"
                )
            )
        }

        return issues
    }

    static func validateNaturalNoteStripRailContractFreezesScopeAndGeometryDefaults()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "natural_note_strip_rail_contract_freezes_scope_and_geometry_defaults"
        var issues: [ExerciseCompositionValidationIssue] = []

        let positionPromptTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .positionPrompt
        )
        let railPresentation = ExerciseCompositionPolicy.makePresentation(
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

        if !railPresentation.scene
            .containsNaturalNoteStripAnswerRailInSideBySideLayout {
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide 的 fretboard -> natural note strip scene 在阶段 1 应继续被 shared helper 标记为右侧 answer rail 作用域。"
                )
            )
        }

        switch railPresentation.naturalNoteStripRailContract {
        case let .some(railContract):
            if railContract.appliesToSurface != .naturalNoteStrip {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的 rail contract 应继续显式指向 natural note strip surface。"
                    )
                )
            }

            if railContract.slotModel != .chromatic12Preserved
                || railContract.slotModel.slotCount != PitchClass.allCases.count {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的 rail contract 应继续冻结为保留 12 个 PitchClass 槽位的语义。"
                    )
                )
            }

            if railContract.buttonShape != .square
                || railContract.buttonExtent
                != ExerciseNaturalNoteStripRailContract.defaultButtonExtent {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的 rail contract 应继续给出 square + 50 的默认按钮几何语义。"
                    )
                )
            }

            if railContract.mainAxisPolicy != .contentSized
                || railContract.crossAxisPolicy != .fitContent
                || railContract.crossAxisWidthScale
                != ExerciseNaturalNoteStripRailContract.defaultCrossAxisWidthScale
                || railContract.verticalAlignment != .centered {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 1 的 rail contract 应继续给出 contentSized / fitContent(x2) / centered 的 shared 布局语义。"
                    )
                )
            }
        case .none:
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide 的 fretboard -> natural note strip scene 在阶段 1 应暴露 active rail contract，而不是 nil。"
                )
            )
        }

        switch railPresentation.naturalNoteStripRailLayout {
        case let .some(layout):
            if layout.context.appliesToSurface != .naturalNoteStrip
                || layout.context.slotModel != .chromatic12Preserved
                || layout.placements.count != PitchClass.allCases.count
                || layout.placements.map(\.pitchClass) != PitchClass.allCases {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 3 的 rail contract 应继续稳定投影为 shared rail layout 摘要：12 个 chromatic placements 与 natural note strip surface 作用域都不能丢。"
                    )
                )
            }

            if layout.contentSize.width <= 0 || layout.contentSize.height <= 0 {
                issues.append(
                    issue(
                        fixtureName,
                        "阶段 3 的 rail contract 应继续投影出正值 contentSize 的 shared rail layout 摘要，而不是零尺寸布局。"
                    )
                )
            }
        case .none:
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide 的 fretboard -> natural note strip scene 在阶段 3 应同时暴露 active shared rail layout 摘要，而不是 nil。"
                )
            )
        }

        if railPresentation.scene.naturalNoteStripRailLayout
            != railPresentation.naturalNoteStripRailLayout {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 3 的 ExerciseScene 应继续把 shared rail layout 摘要原样透传给 presentation 层。"
                )
            )
        }

        if railPresentation.fretboardLayoutContract.heightPolicy
            != .fillAvailableHeight {
            issues.append(
                issue(
                    fixtureName,
                    "阶段 1 引入 rail contract 时，不应反向破坏 side fretboard 的 fillAvailableHeight 语义。"
                )
            )
        }

        let stackedRailPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: positionPromptTrainerDisplayState,
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .fretboardToNaturalNoteStrip,
                    layoutPreset: .stacked
                )
            )
        )

        if stackedRailPresentation.scene
            .containsNaturalNoteStripAnswerRailInSideBySideLayout
            || stackedRailPresentation.naturalNoteStripRailContract != nil
            || stackedRailPresentation.naturalNoteStripRailLayout != nil
            || stackedRailPresentation.scene.naturalNoteStripRailLayout != nil {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 3 不应被误纳入 right rail contract / shared rail layout 摘要。"
                )
            )
        }

        let singleTrainerDisplayState = TrainerDisplayState(exerciseMode: .single)
        let targetPromptSideBySidePresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: singleTrainerDisplayState,
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

        if targetPromptSideBySidePresentation.scene
            .containsNaturalNoteStripAnswerRailInSideBySideLayout
            || targetPromptSideBySidePresentation.naturalNoteStripRailContract
            != nil
            || targetPromptSideBySidePresentation.naturalNoteStripRailLayout != nil
            || targetPromptSideBySidePresentation.scene
                .naturalNoteStripRailLayout != nil {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide scene 在阶段 3 不应被误纳入 natural note strip rail contract / shared rail layout 摘要。"
                )
            )
        }

        let sequenceTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .sequence
        )
        let staffSideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: sequenceTrainerDisplayState,
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToFretboard,
                    layoutPreset: .sideBySide
                )
            )
        )

        if staffSideBySidePresentation.scene
            .containsNaturalNoteStripAnswerRailInSideBySideLayout
            || staffSideBySidePresentation.naturalNoteStripRailContract != nil
            || staffSideBySidePresentation.naturalNoteStripRailLayout != nil
            || staffSideBySidePresentation.scene.naturalNoteStripRailLayout
            != nil {
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard 的 sideBySide scene 在阶段 3 不应被误纳入 natural note strip rail contract / shared rail layout 摘要。"
                )
            )
        }

        return issues
    }

    static func validateSideRailContractRemainsOrthogonalToFretboardHeightContract()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "side_rail_contract_remains_orthogonal_to_fretboard_height_contract"
        var issues: [ExerciseCompositionValidationIssue] = []

        let positionPromptTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .positionPrompt
        )
        let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
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

        if sideRailPresentation.naturalNoteStripRailContract
            != .defaultSideBySideAnswerRail {
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide 的 fretboard -> natural note strip presentation 应继续精确暴露默认 rail contract。"
                )
            )
        }
        if sideRailPresentation.scene.naturalNoteStripRailContract
            != .defaultSideBySideAnswerRail {
            issues.append(
                issue(
                    fixtureName,
                    "ExerciseScene 应继续把 side rail 的 shared 默认 contract 原样透传给 presentation 层。"
                )
            )
        }
        let expectedPureSharedLayout =
            ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
                .defaultLayoutContext.resolvedLayout
        if sideRailPresentation.naturalNoteStripRailLayout
            != expectedPureSharedLayout {
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide 的 shared rail layout 应继续只由 rail contract / layoutContext 决定，而不依赖 fretboardLayoutContract。"
                )
            )
        }
        if sideRailPresentation.scene.naturalNoteStripRailLayout
            != expectedPureSharedLayout {
            issues.append(
                issue(
                    fixtureName,
                    "ExerciseScene 应继续把由默认 rail contract 纯计算出来的 shared rail layout 原样透传给 presentation 层。"
                )
            )
        }
        if sideRailPresentation.fretboardLayoutContract
            != ExerciseFretboardLayoutContract(
                pinsSceneToViewportHeight: true,
                heightPolicy: .fillAvailableHeight
            ) {
            issues.append(
                issue(
                    fixtureName,
                    "side rail 场景下的 fretboardLayoutContract 应继续保持 viewport pin + fillAvailableHeight。"
                )
            )
        }
        if sideRailPresentation.fretboardLayoutContract
            .usesVerticalViewportHeightControl {
            issues.append(
                issue(
                    fixtureName,
                    "side rail 场景下的 fretboard 高度应由容器填满，不应重新打开 Vertical Viewport Height 控制语义。"
                )
            )
        }

        let stackedRailPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: positionPromptTrainerDisplayState,
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .fretboardToNaturalNoteStrip,
                    layoutPreset: .stacked
                )
            )
        )

        if stackedRailPresentation.naturalNoteStripRailContract != nil
            || stackedRailPresentation.scene.naturalNoteStripRailContract != nil
            || stackedRailPresentation.naturalNoteStripRailLayout != nil
            || stackedRailPresentation.scene.naturalNoteStripRailLayout != nil {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip 场景不应误暴露 right rail contract / shared rail layout。"
                )
            )
        }
        if stackedRailPresentation.fretboardLayoutContract
            != ExerciseFretboardLayoutContract(
                pinsSceneToViewportHeight: true,
                heightPolicy: .followViewportRatio
            ) {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 场景下的 fretboardLayoutContract 应继续保持 viewport pin + followViewportRatio。"
                )
            )
        }
        if !stackedRailPresentation.fretboardLayoutContract
            .usesVerticalViewportHeightControl {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 场景下应继续保留 Vertical Viewport Height 控制语义。"
                )
            )
        }

        let sideTargetPromptPresentation = ExerciseCompositionPolicy.makePresentation(
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

        if sideTargetPromptPresentation.naturalNoteStripRailContract != nil
            || sideTargetPromptPresentation.scene.naturalNoteStripRailContract != nil
            || sideTargetPromptPresentation.naturalNoteStripRailLayout != nil
            || sideTargetPromptPresentation.scene.naturalNoteStripRailLayout
            != nil {
            issues.append(
                issue(
                    fixtureName,
                    "不包含 natural note strip answer rail 的 sideBySide 场景不应误携带 rail contract / shared rail layout。"
                )
            )
        }
        if sideTargetPromptPresentation.fretboardLayoutContract.heightPolicy
            != .fillAvailableHeight
            || sideTargetPromptPresentation.fretboardLayoutContract
            .usesVerticalViewportHeightControl {
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide 的非 rail fretboard 场景仍应保持 fillAvailableHeight，证明 rail contract 不会篡改 side 布局的 fretboard 高度语义。"
                )
            )
        }

        return issues
    }

    static func validateNaturalNoteStripStageCTopologyFreezesChromatic12Semantics()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "natural_note_strip_stage_c_topology_freezes_chromatic12_semantics"
        var issues: [ExerciseCompositionValidationIssue] = []

        let expectedNaturals: [PitchClass] = [.c, .d, .e, .f, .g, .a, .b]
        if PitchClass.naturalCasesInOrder != expectedNaturals {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 0 应继续把 naturalCasesInOrder 冻结为 C-D-E-F-G-A-B，作为右列自然音主行顺序。"
                )
            )
        }

        let expectedAccidentals: [PitchClass] = [
            .cSharp,
            .dSharp,
            .fSharp,
            .gSharp,
            .aSharp
        ]
        if PitchClass.accidentalCasesInOrder != expectedAccidentals {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 0 应继续把 accidentalCasesInOrder 冻结为 C#-D#-F#-G#-A#，不在 E-F / B-C 之间伪造 accidental 槽位。"
                )
            )
        }

        let naturalColumns = PitchClass.naturalCasesInOrder.map {
            $0.naturalNoteStripStaggeredRailPitchTopology.column
        }
        if naturalColumns != Array(
            repeating: .naturalRight,
            count: PitchClass.naturalCasesInOrder.count
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 0 应继续把全部自然音拓扑冻结在右列，而不是让平台层重新决定列归属。"
                )
            )
        }

        let accidentalColumns = PitchClass.accidentalCasesInOrder.map {
            $0.naturalNoteStripStaggeredRailPitchTopology.column
        }
        if accidentalColumns != Array(
            repeating: .accidentalLeft,
            count: PitchClass.accidentalCasesInOrder.count
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 0 应继续把全部 accidental 拓扑冻结在左列，而不是让平台层自行推导左右列。"
                )
            )
        }

        let naturalRowIndices = PitchClass.naturalCasesInOrder.compactMap {
            pitchClass -> Int? in
            guard case let .naturalRow(index) =
                pitchClass.naturalNoteStripStaggeredRailPitchTopology.anchor else {
                return nil
            }

            return index
        }
        if naturalRowIndices != Array(0...6) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 0 应继续把自然音主行索引冻结为 0...6，保证 C-D-E-F-G-A-B 上下连续相邻。"
                )
            )
        }

        let accidentalMidpointPairs = PitchClass.accidentalCasesInOrder.compactMap {
            pitchClass -> [Int]? in
            guard case let .midpointBetweenNaturalRows(top, bottom) =
                pitchClass.naturalNoteStripStaggeredRailPitchTopology.anchor else {
                return nil
            }

            return [top, bottom]
        }
        let expectedAccidentalMidpointPairs = [
            [0, 1],
            [1, 2],
            [3, 4],
            [4, 5],
            [5, 6]
        ]
        if accidentalMidpointPairs != expectedAccidentalMidpointPairs {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 0 应继续冻结 C#/D#/F#/G#/A# 位于相邻自然音中点，且 E-F / B-C 之间没有 accidental midpoint。"
                )
            )
        }

        let expectedTopologies: [ExerciseNaturalNoteStripRailPitchTopology] = [
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .c,
                column: .naturalRight,
                anchor: .naturalRow(index: 0)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .cSharp,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 0, bottom: 1)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .d,
                column: .naturalRight,
                anchor: .naturalRow(index: 1)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .dSharp,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 1, bottom: 2)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .e,
                column: .naturalRight,
                anchor: .naturalRow(index: 2)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .f,
                column: .naturalRight,
                anchor: .naturalRow(index: 3)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .fSharp,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 3, bottom: 4)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .g,
                column: .naturalRight,
                anchor: .naturalRow(index: 4)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .gSharp,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 4, bottom: 5)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .a,
                column: .naturalRight,
                anchor: .naturalRow(index: 5)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .aSharp,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 5, bottom: 6)
            ),
            ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: .b,
                column: .naturalRight,
                anchor: .naturalRow(index: 6)
            )
        ]
        if PitchClass.naturalNoteStripStaggeredRailTopologiesInChromaticOrder
            != expectedTopologies {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 0 应继续把 12 个 PitchClass 的双列错位拓扑冻结在 shared 层，而不是依赖平台 stack 顺序临时拼装。"
                )
            )
        }

        let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt),
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
        if sideRailPresentation.naturalNoteStripRailContract?.slotModel.slotCount
            != expectedTopologies.count {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 0 应继续保持 side rail 的 12 个语义槽位，与未来双列错位视觉拓扑一一对应。"
                )
            )
        }

        return issues
    }

    static func validateNaturalNoteStripStageCLayoutContextFreezesDefaultGeometryTokens()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "natural_note_strip_stage_c_layout_context_freezes_default_geometry_tokens"
        var issues: [ExerciseCompositionValidationIssue] = []

        let positionPromptTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .positionPrompt
        )
        let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
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
        let expectedInsets =
            ExerciseNaturalNoteStripRailInsets.defaultSideBySideAnswerRail
        let expectedGeometry =
            ExerciseNaturalNoteStripRailGeometry.defaultStageCSideBySideAnswerRail(
                buttonExtent:
                    ExerciseNaturalNoteStripRailContract.defaultButtonExtent
            )
        let expectedLegacyCompatibleContentWidth =
            (expectedInsets.leading
                + ExerciseNaturalNoteStripRailContract.defaultButtonExtent
                + expectedInsets.trailing)
            * ExerciseNaturalNoteStripRailContract.defaultCrossAxisWidthScale
        let expectedNaturalColumnContentHeight =
            expectedInsets.top
            + (ExerciseNaturalNoteStripRailContract.defaultButtonExtent
                * Double(PitchClass.naturalCasesInOrder.count))
            + expectedInsets.bottom

        switch sideRailPresentation.naturalNoteStripRailLayoutContext {
        case let .some(layoutContext):
            if layoutContext.appliesToSurface != .naturalNoteStrip {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的 layoutContext 应继续显式绑定 natural note strip surface。"
                    )
                )
            }

            if layoutContext.slotModel != .chromatic12Preserved {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的 layoutContext 应继续保留 chromatic12Preserved 的 12 个语义槽位。"
                    )
                )
            }

            if layoutContext.buttonShape != .square {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的 layoutContext 应继续冻结 square 按钮形状。"
                    )
                )
            }

            if layoutContext.placementModel
                != .staggeredNaturalAccidentalTwoColumn {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的 layoutContext 应继续明确声明 staggeredNaturalAccidentalTwoColumn placement model。"
                    )
                )
            }

            if layoutContext.titleDisplayPolicy != .allPitchClasses {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的 layoutContext 应继续冻结 allPitchClasses 标题策略，避免平台层各自决定 accidental 是否显示标题。"
                    )
                )
            }

            if layoutContext.hostVerticalAlignment != .centered {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的 layoutContext 应继续把 host 对齐语义冻结为 centered。"
                    )
                )
            }

            if layoutContext.geometry != expectedGeometry {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的 layoutContext 应继续冻结 shared rail geometry token：10/12 inset、24 columnGap、0 naturalRowSpacing、buttonExtent 跟随 contract。"
                    )
                )
            }

            if layoutContext.geometry.twoColumnContentWidth
                != expectedLegacyCompatibleContentWidth {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的两列 rail contentWidth 应继续与现有 fitContent(x2) 过渡宽度兼容。"
                    )
                )
            }

            if layoutContext.geometry.naturalColumnContentHeight(
                rowCount: PitchClass.naturalCasesInOrder.count
            ) != expectedNaturalColumnContentHeight {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的自然音主列高度应继续由 7 个自然音按钮与 contentInsets 直接决定，保持 0 行距语义。"
                    )
                )
            }

            if layoutContext.pitchTopologies
                != PitchClass.naturalNoteStripStaggeredRailTopologiesInChromaticOrder
            {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 1 的 layoutContext 应继续直接透传阶段 0 冻结的双列错位 pitch topology。"
                    )
                )
            }
        case .none:
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 side rail presentation 应暴露 active layoutContext，而不是 nil。"
                )
            )
        }

        if sideRailPresentation.scene.naturalNoteStripRailLayoutContext
            != sideRailPresentation.naturalNoteStripRailLayoutContext {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 ExerciseScene 应继续把 shared rail layoutContext 原样透传给 presentation 层。"
                )
            )
        }

        let stackedRailPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: positionPromptTrainerDisplayState,
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .fretboardToNaturalNoteStrip,
                    layoutPreset: .stacked
                )
            )
        )
        if stackedRailPresentation.naturalNoteStripRailLayoutContext != nil
            || stackedRailPresentation.scene.naturalNoteStripRailLayoutContext
            != nil {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的 stacked scene 不应误暴露 natural note strip rail layoutContext。"
                )
            )
        }

        let targetPromptSideBySidePresentation = ExerciseCompositionPolicy
            .makePresentation(
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
        if targetPromptSideBySidePresentation.naturalNoteStripRailLayoutContext
            != nil
            || targetPromptSideBySidePresentation.scene
                .naturalNoteStripRailLayoutContext != nil {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 1 的非 rail sideBySide scene 不应误暴露 natural note strip rail layoutContext。"
                )
            )
        }

        return issues
    }

    static func validateNaturalNoteStripStageCLayoutBuilderExposesSharedLayoutOutput()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "natural_note_strip_stage_c_layout_builder_exposes_shared_layout_output"
        var issues: [ExerciseCompositionValidationIssue] = []

        let positionPromptTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .positionPrompt
        )
        let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
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

        let expectedPitchClasses = PitchClass.allCases
        switch sideRailPresentation.naturalNoteStripRailLayout {
        case let .some(layout):
            if layout.context != sideRailPresentation.naturalNoteStripRailLayoutContext {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 2 的 shared rail layout 应继续直接引用当前 presentation 暴露的 layoutContext。"
                    )
                )
            }

            if layout.placements.map(\.pitchClass) != expectedPitchClasses {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 2 的 shared rail layout 应继续按 chromatic12 顺序输出 C/C#/D/.../B 的 placements。"
                    )
                )
            }

            if layout.placements.count != layout.context.slotModel.slotCount {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 2 的 shared rail layout 应继续为每个语义槽位产出一个 placement。"
                    )
                )
            }

            if layout.contentSize.width <= 0 || layout.contentSize.height <= 0 {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 2 的 shared rail layout 应继续产出正值 contentSize，而不是零尺寸布局。"
                    )
                )
            }

            let resolvedButtonExtent = layout.context.geometry.resolvedButtonExtent
            let hasMismatchedButtonFrames = layout.placements.contains { placement in
                placement.frame.width != resolvedButtonExtent
                    || placement.frame.height != resolvedButtonExtent
            }
            if hasMismatchedButtonFrames {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 2 的 shared rail layout 应继续让全部 placement frame 与 rail buttonExtent 对齐。"
                    )
                )
            }

            if layout.context.titleDisplayPolicy == .allPitchClasses
                && layout.placements.contains(where: { !$0.showsTitle }) {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 2 的 shared rail layout 在 allPitchClasses 策略下，不应漏掉任何按钮标题可见性。"
                    )
                )
            }
        case .none:
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 side rail presentation 应暴露 active shared rail layout，而不是 nil。"
                )
            )
        }

        if sideRailPresentation.scene.naturalNoteStripRailLayout
            != sideRailPresentation.naturalNoteStripRailLayout {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 ExerciseScene 应继续把 shared rail layout 原样透传给 presentation 层。"
                )
            )
        }

        let stackedRailPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: positionPromptTrainerDisplayState,
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .fretboardToNaturalNoteStrip,
                    layoutPreset: .stacked
                )
            )
        )
        if stackedRailPresentation.naturalNoteStripRailLayout != nil
            || stackedRailPresentation.scene.naturalNoteStripRailLayout != nil {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的 stacked scene 不应误暴露 natural note strip shared rail layout。"
                )
            )
        }

        let targetPromptSideBySidePresentation = ExerciseCompositionPolicy
            .makePresentation(
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
        if targetPromptSideBySidePresentation.naturalNoteStripRailLayout != nil
            || targetPromptSideBySidePresentation.scene.naturalNoteStripRailLayout
            != nil {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 2 的非 rail sideBySide scene 不应误暴露 natural note strip shared rail layout。"
                )
            )
        }

        return issues
    }

    static func validateNaturalNoteStripStaggeredTwoColumnLayoutMatchesPitchclassTopology()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "natural_note_strip_staggered_two_column_layout_matches_pitchclass_topology"
        var issues: [ExerciseCompositionValidationIssue] = []
        let tolerance = 0.0001

        func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
            abs(lhs - rhs) <= tolerance
        }

        let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt),
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

        guard let layout = sideRailPresentation.naturalNoteStripRailLayout else {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 应能从 side rail presentation 读到 active shared rail layout。"
                )
            )
            return issues
        }

        let geometry = layout.context.geometry
        let expectedAccidentalX = geometry.contentInsets.leading
        let expectedNaturalX = geometry.contentInsets.leading
            + geometry.resolvedButtonExtent
            + geometry.resolvedColumnGap
        let expectedTopologies =
            PitchClass.naturalNoteStripStaggeredRailTopologiesInChromaticOrder

        func expectedCenterY(
            for anchor: ExerciseNaturalNoteStripRailPitchTopologyAnchor
        ) -> Double {
            switch anchor {
            case let .naturalRow(index):
                return geometry.contentInsets.top
                    + (geometry.resolvedButtonExtent / 2)
                    + (Double(index) * geometry.naturalRowStride)
            case let .midpointBetweenNaturalRows(top, bottom):
                let topCenter = geometry.contentInsets.top
                    + (geometry.resolvedButtonExtent / 2)
                    + (Double(top) * geometry.naturalRowStride)
                let bottomCenter = geometry.contentInsets.top
                    + (geometry.resolvedButtonExtent / 2)
                    + (Double(bottom) * geometry.naturalRowStride)
                return (topCenter + bottomCenter) / 2
            }
        }

        func placement(
            for pitchClass: PitchClass
        ) -> ExerciseNaturalNoteStripRailPlacement? {
            layout.placements.first { $0.pitchClass == pitchClass }
        }

        if layout.context.placementModel != .staggeredNaturalAccidentalTwoColumn {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 的 rail layout 应继续使用 staggeredNaturalAccidentalTwoColumn placement model。"
                )
            )
        }

        if layout.placements.map(\.topology) != expectedTopologies {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 的 rail placements 应继续按 chromatic12 顺序携带 stage0 冻结的双列错位 topology。"
                )
            )
        }

        let naturalCenters = PitchClass.naturalCasesInOrder.compactMap {
            pitchClass -> Double? in
            guard let currentPlacement = placement(for: pitchClass) else {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 3 的 rail layout 缺少自然音 \(pitchClass.displayText()) 的 placement。"
                    )
                )
                return nil
            }

            if !approximatelyEqual(
                Double(currentPlacement.frame.minX),
                expectedNaturalX
            ) {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 3 应继续把自然音 \(pitchClass.displayText()) 放在右列固定 x 位置。"
                    )
                )
            }

            let expectedMidY = expectedCenterY(for: currentPlacement.topology.anchor)
            if !approximatelyEqual(
                Double(currentPlacement.frame.midY),
                expectedMidY
            ) {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 3 应继续让自然音 \(pitchClass.displayText()) 的中心点与 natural row 锚点对齐。"
                    )
                )
            }

            return Double(currentPlacement.frame.midY)
        }

        let hasBrokenNaturalStride = zip(
            naturalCenters,
            naturalCenters.dropFirst()
        ).contains(where: { pair in
            !approximatelyEqual(pair.1 - pair.0, geometry.naturalRowStride)
        })
        if hasBrokenNaturalStride {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 应继续让 C-D-E-F-G-A-B 的主行中心按 naturalRowStride 连续递增。"
                )
            )
        }

        for pitchClass in PitchClass.accidentalCasesInOrder {
            guard let currentPlacement = placement(for: pitchClass) else {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 3 的 rail layout 缺少 accidental \(pitchClass.displayText()) 的 placement。"
                    )
                )
                continue
            }

            if !approximatelyEqual(
                Double(currentPlacement.frame.minX),
                expectedAccidentalX
            ) {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 3 应继续把 accidental \(pitchClass.displayText()) 放在左列固定 x 位置。"
                    )
                )
            }

            let expectedMidY = expectedCenterY(for: currentPlacement.topology.anchor)
            if !approximatelyEqual(
                Double(currentPlacement.frame.midY),
                expectedMidY
            ) {
                issues.append(
                    issue(
                        fixtureName,
                        "方案 C 阶段 3 应继续让 accidental \(pitchClass.displayText()) 的中心点落在相邻自然音主行中点。"
                    )
                )
            }
        }

        return issues
    }

    static func validateNaturalNoteStripSharedLayoutContentSizeMatchesIntrinsicSemantics()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "natural_note_strip_shared_layout_content_size_matches_intrinsic_semantics"
        var issues: [ExerciseCompositionValidationIssue] = []
        let tolerance = 0.0001

        func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
            abs(lhs - rhs) <= tolerance
        }

        let sideRailPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .positionPrompt),
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

        guard let layout = sideRailPresentation.naturalNoteStripRailLayout else {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 应能从 side rail presentation 读到 active shared rail layout。"
                )
            )
            return issues
        }

        let geometry = layout.context.geometry
        let expectedContentWidth = geometry.twoColumnContentWidth
        let expectedContentHeight = geometry.naturalColumnContentHeight(
            rowCount: PitchClass.naturalCasesInOrder.count
        )
        let legacySingleColumnHeight = geometry.columnContentHeight(
            rowCount: layout.context.slotModel.slotCount
        )

        if !approximatelyEqual(
            Double(layout.contentSize.width),
            expectedContentWidth
        ) || !approximatelyEqual(
            Double(layout.contentSize.height),
            expectedContentHeight
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 的 shared rail contentSize 应继续由两列按钮宽度、列间距、7 个自然音主行与内容内边距共同决定。"
                )
            )
        }

        if approximatelyEqual(
            Double(layout.contentSize.height),
            legacySingleColumnHeight
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 的 shared rail contentHeight 不应退回 12 槽位单列公式；它必须继续来自 7 个自然音主行。"
                )
            )
        }

        let minX = layout.placements.map { Double($0.frame.minX) }.min()
        let maxX = layout.placements.map { Double($0.frame.maxX) }.max()
        let minY = layout.placements.map { Double($0.frame.minY) }.min()
        let maxY = layout.placements.map { Double($0.frame.maxY) }.max()

        if !approximatelyEqual(minX ?? -1, geometry.contentInsets.leading)
            || !approximatelyEqual(
                expectedContentWidth - (maxX ?? -1),
                geometry.contentInsets.trailing
            ) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 的 shared rail contentWidth 应继续精确包裹左右两列按钮，并保留 leading / trailing contentInsets。"
                )
            )
        }

        if !approximatelyEqual(minY ?? -1, geometry.contentInsets.top)
            || !approximatelyEqual(
                expectedContentHeight - (maxY ?? -1),
                geometry.contentInsets.bottom
            ) {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 的 shared rail contentHeight 应继续精确包裹最上/最下 natural row，并保留 top / bottom contentInsets。"
                )
            )
        }

        var widenedScaleContract =
            ExerciseNaturalNoteStripRailContract.defaultSideBySideAnswerRail
        widenedScaleContract.crossAxisWidthScale = 99
        let widenedScaleLayout = widenedScaleContract.defaultLayoutContext
            .resolvedLayout
        if widenedScaleLayout != layout {
            issues.append(
                issue(
                    fixtureName,
                    "方案 C 阶段 3 的 shared rail layout 不应再依赖过渡字段 crossAxisWidthScale；width 必须继续由 shared geometry 自身决定。"
                )
            )
        }

        return issues
    }

    static func validateVerticalFitContentSplitSizingTracksSurfaceKinds()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "vertical_fit_content_split_sizing_tracks_surface_kinds"
        var issues: [ExerciseCompositionValidationIssue] = []

        let staffStackedScene = ExerciseScene.stacked(
            top: .staffPrompt,
            bottom: .fretboardAnswer
        )
        switch staffStackedScene.root {
        case let .split(axis, children):
            if axis != .vertical
                || children.count != 2
                || children[0].mainAxisSizing != .fitContent
                || children[1].mainAxisSizing != .weighted(1) {
                issues.append(
                    issue(
                        fixtureName,
                        "staff -> fretboard 的 vertical split 应保持上方 prompt fitContent、下方 fretboard weighted(1)。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard stacked scene 应继续落成 vertical split。"
                )
            )
        }

        let positionPromptScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .fretboardToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
        switch positionPromptScene.root {
        case let .split(axis, children):
            if axis != .vertical
                || children.count != 2
                || children[0].mainAxisSizing != .weighted(1)
                || children[1].mainAxisSizing != .fitContent {
                issues.append(
                    issue(
                        fixtureName,
                        "fretboard -> natural note strip 的 vertical split 应保持上方 fretboard weighted(1)、下方 strip fitContent。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的主视觉 scene 应继续落成 vertical split。"
                )
            )
        }
        if !positionPromptScene.hasMixedMainAxisSizing(along: .vertical) {
            issues.append(
                issue(
                    fixtureName,
                    "包含 natural note strip answer 的 vertical split 应触发 vertical mixed main-axis sizing 语义。"
                )
            )
        }

        let threePaneScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .staffToFretboard,
                layoutPreset: .threePane,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: true,
                isAccessoryExpanded: true
            )
        )
        switch threePaneScene.root {
        case let .split(_, children):
            guard
                children.count == 2,
                case let .split(_, accessoryChildren) = children[1].node
            else {
                issues.append(
                    issue(
                        fixtureName,
                        "threePane accessory subtree 应继续落成承载 strip/piano 的 split。"
                    )
                )
                return issues
            }
            if accessoryChildren.count != 2
                || accessoryChildren[0].mainAxisSizing != .fitContent
                || accessoryChildren[1].mainAxisSizing != .weighted(1.3) {
                issues.append(
                    issue(
                        fixtureName,
                        "threePane accessory split 应保持 strip fitContent、piano weighted(1.3)。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "threePane scene 应继续以 split 承载主视觉与 accessory subtree。"
                )
            )
        }

        let sideBySideScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .targetPromptToFretboard,
                layoutPreset: .sideBySide,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: false,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
        if sideBySideScene.hasMixedMainAxisSizing(along: .vertical) {
            issues.append(
                issue(
                    fixtureName,
                    "sideBySide scene 不应误触发 vertical mixed main-axis sizing 语义。"
                )
            )
        }

        return issues
    }

    static func validatePhaseZeroSideBySideInvariantsPreserveCompositionSpecificSurfacePairs()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "phase_zero_side_by_side_invariants_preserve_composition_specific_surface_pairs"
        var issues: [ExerciseCompositionValidationIssue] = []

        func validateHorizontalPair(
            _ presentation: ExercisePresentationState,
            expectedSurfaceIDs: [ExerciseSurfaceID],
            sceneDescription: String,
            expectedOrderDescription: String
        ) {
            if !ExerciseSceneValidator.validate(presentation.scene).isEmpty {
                issues.append(
                    issue(
                        fixtureName,
                        "\(sceneDescription) 在阶段 0 应继续生成合法 scene。"
                    )
                )
            }

            switch presentation.scene.root {
            case let .split(axis, children):
                if axis != .horizontal {
                    issues.append(
                        issue(
                            fixtureName,
                            "\(sceneDescription) 在阶段 0 应继续投影到 horizontal split。"
                        )
                    )
                }

                let childSurfaceIDs = children.compactMap {
                    $0.node.surfaceNodes.first?.id
                }
                if childSurfaceIDs != expectedSurfaceIDs {
                    issues.append(
                        issue(
                            fixtureName,
                            "\(sceneDescription) 在阶段 0 应继续保持 \(expectedOrderDescription)。"
                        )
                    )
                }
            default:
                issues.append(
                    issue(
                        fixtureName,
                        "\(sceneDescription) 在阶段 0 应继续生成 split scene。"
                    )
                )
            }

            if presentation.scene.hasMixedMainAxisSizing(along: .vertical) {
                issues.append(
                    issue(
                        fixtureName,
                        "\(sceneDescription) 在阶段 0 不应误触发 vertical mixed main-axis sizing 语义。"
                    )
                )
            }
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
        validateHorizontalPair(
            sideBySidePositionPromptPresentation,
            expectedSurfaceIDs: [.fretboard, .naturalNoteStrip],
            sceneDescription: "positionPrompt 的 fretboard -> natural note strip sideBySide 组合",
            expectedOrderDescription: "左 fretboard、右 natural note strip"
        )
        if sideBySidePositionPromptPresentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的 sideBySide 组合在阶段 0 仍不应被误投影成 legacy page 双槽位。"
                )
            )
        }
        guard
            let promptFretboardState = sideBySidePositionPromptPresentation
                .projectedSurfaceState(
                for: .fretboard
            ),
            let stripAnswerState = sideBySidePositionPromptPresentation
                .projectedSurfaceState(
                for: .naturalNoteStrip
            )
        else {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的 sideBySide 组合应继续生成 fretboard 与 natural note strip 的 surface state。"
                )
            )
            return issues
        }
        if !promptFretboardState.isVisible
            || !promptFretboardState.isPromptActive
            || promptFretboardState.isAnswerEnabled
            || promptFretboardState.isInteractionEnabled {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的 sideBySide 组合里，fretboard 应继续保持 prompt-only surface state。"
                )
            )
        }
        if !stripAnswerState.isVisible
            || stripAnswerState.isPromptActive
            || !stripAnswerState.isAnswerEnabled
            || !stripAnswerState.isInteractionEnabled {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的 sideBySide 组合里，natural note strip 应继续保持 answer-only surface state。"
                )
            )
        }
        switch sideBySidePositionPromptPresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal
                || children.count != 2
                || children[0].mainAxisSizing != .weighted(1)
                || children[1].mainAxisSizing != .fitContent {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 sideBySide 组合在阶段 2 应升级为左 fretboard weighted(1)、右 strip fitContent 的主轴尺寸语义。"
                    )
                )
            }
            guard
                case let .surface(promptSurface) = children[0].node,
                case let .surface(stripSurface) = children[1].node
            else {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 sideBySide 组合在阶段 2 应继续由两个 surface child 组成。"
                    )
                )
                break
            }
            if promptSurface.presentationStyle != .standard
                || stripSurface.presentationStyle != .verticalRail {
                issues.append(
                    issue(
                        fixtureName,
                        "positionPrompt 的 sideBySide 组合在阶段 2 应保持左侧 standard fretboard、右侧 verticalRail strip。"
                    )
                )
            }
        default:
            break
        }
        if !sideBySidePositionPromptPresentation.scene
            .hasMixedMainAxisSizing(along: .horizontal) {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的 sideBySide 组合在阶段 2 应触发 horizontal mixed main-axis sizing 语义。"
                )
            )
        }
        if !sideBySidePositionPromptPresentation.scene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的 sideBySide 组合在阶段 2 应通过 shared helper 请求 viewport pin 高度。"
                )
            )
        }
        if sideBySidePositionPromptPresentation.fretboardLayoutContract.heightPolicy
            != .fillAvailableHeight {
            issues.append(
                issue(
                    fixtureName,
                    "positionPrompt 的 sideBySide 组合在阶段 2 应让主 fretboard 跟随 side 容器填满高度。"
                )
            )
        }

        let singleTrainerDisplayState = TrainerDisplayState(exerciseMode: .single)
        let sideBySideTargetPromptPresentation = ExerciseCompositionPolicy
            .makePresentation(
                from: ExerciseCompositionPolicyInput(
                    trainerDisplayState: singleTrainerDisplayState,
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
        validateHorizontalPair(
            sideBySideTargetPromptPresentation,
            expectedSurfaceIDs: [.targetPrompt, .fretboard],
            sceneDescription: "single 的 targetPrompt -> fretboard sideBySide 组合",
            expectedOrderDescription: "左 targetPrompt、右 fretboard"
        )
        if sideBySideTargetPromptPresentation.scene.containsSurface(
            .naturalNoteStrip
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide 组合在阶段 0 不应混入 natural note strip surface。"
                )
            )
        }
        switch sideBySideTargetPromptPresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal
                || children.count != 2
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
                        "targetPrompt -> fretboard 的 sideBySide 组合在阶段 2 不应被 verticalRail 语义污染。"
                    )
                )
            }
        default:
            break
        }
        if !sideBySideTargetPromptPresentation.scene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide 组合在阶段 2 应通过 shared helper 请求 viewport pin 高度。"
                )
            )
        }
        if sideBySideTargetPromptPresentation.fretboardLayoutContract.heightPolicy
            != .fillAvailableHeight {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide 组合在阶段 2 应让主 fretboard 跟随 side 容器填满高度。"
                )
            )
        }

        let sequenceTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .sequence
        )
        let sideBySideStaffPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: sequenceTrainerDisplayState,
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToFretboard,
                    layoutPreset: .sideBySide
                )
            )
        )
        validateHorizontalPair(
            sideBySideStaffPresentation,
            expectedSurfaceIDs: [.staff, .fretboard],
            sceneDescription: "sequence 的 staff -> fretboard sideBySide 组合",
            expectedOrderDescription: "左 staff、右 fretboard"
        )
        if sideBySideStaffPresentation.scene.containsSurface(.naturalNoteStrip) {
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard 的 sideBySide 组合在阶段 0 不应混入 natural note strip surface。"
                )
            )
        }
        switch sideBySideStaffPresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal
                || children.count != 2
                || !children[0].mainAxisSizing.isWeighted
                || !children[1].mainAxisSizing.isWeighted {
                issues.append(
                    issue(
                        fixtureName,
                        "staff -> fretboard 的 sideBySide 组合在阶段 2 仍应保持双 weighted 主轴尺寸语义。"
                    )
                )
            }
            guard
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
                        "staff -> fretboard 的 sideBySide 组合在阶段 2 不应被 verticalRail 语义污染。"
                    )
                )
            }
        default:
            break
        }
        if !sideBySideStaffPresentation.scene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard 的 sideBySide 组合在阶段 2 应通过 shared helper 请求 viewport pin 高度。"
                )
            )
        }
        if sideBySideStaffPresentation.fretboardLayoutContract.heightPolicy
            != .fillAvailableHeight {
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard 的 sideBySide 组合在阶段 2 应让主 fretboard 跟随 side 容器填满高度。"
                )
            )
        }

        return issues
    }

    static func validateStaffToPianoScenePromotesMainPianoAnswerSurface()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "staff_to_piano_scene_promotes_main_piano_answer_surface"
        var issues: [ExerciseCompositionValidationIssue] = []

        let rawScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .staffToPiano,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: false,
                isPianoAccessoryVisible: true,
                isAccessoryExpanded: true
            )
        )
        let rawSurfaceIDs = rawScene.surfaceNodes.map(\.id)
        let rawPianoSurfaceCount = rawScene.surfaceNodes.filter {
            $0.id == .piano
        }.count
        if rawSurfaceIDs.count != 2
            || Set(rawSurfaceIDs) != Set([.staff, .piano]) {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` scene 应只保留主 `staff` 与主 `piano`，不应再把 accessory piano 混进来。"
                )
            )
        }
        if !ExerciseSceneValidator.validate(rawScene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` scene 在请求显示 piano accessory 时仍应生成合法 scene。"
                )
            )
        }
        if rawPianoSurfaceCount != 1 {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 的 raw scene 里只允许存在一个逻辑 `.piano` surface，避免 main piano 与 accessory piano 同场共存。"
                )
            )
        }
        if ExerciseSceneValidator.legacyPageDisplayState(for: rawScene) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 的 raw scene 应被视为合法但不可投影到 legacy page 的新场景，而不是伪装成旧 page 结构。"
                )
            )
        }
        switch rawScene.root {
        case let .split(axis, children):
            if axis != .vertical
                || children.count != 2
                || children[0].mainAxisSizing != .fitContent
                || children[1].mainAxisSizing != .weighted(1) {
                issues.append(
                    issue(
                        fixtureName,
                        "`staffToPiano` 的 stacked scene 应保持上方 staff fitContent、下方 piano weighted(1)。"
                    )
                )
            }
            guard
                children.count == 2,
                case let .surface(topSurface) = children[0].node,
                case let .surface(bottomSurface) = children[1].node
            else {
                break
            }
            if topSurface.id != .staff
                || !topSurface.isPromptSurface
                || topSurface.isAnswerSurface {
                issues.append(
                    issue(
                        fixtureName,
                        "`staffToPiano` 的上方 surface 应保持 prompt-only 的 `staff`。"
                    )
                )
            }
            if bottomSurface.id != .piano
                || bottomSurface.isPromptSurface
                || !bottomSurface.isAnswerSurface
                || bottomSurface.isAuxiliarySurface {
                issues.append(
                    issue(
                        fixtureName,
                        "`staffToPiano` 的下方 surface 应提升为 answer-only 的主 `piano`。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 的主 scene 应投影成 vertical split。"
                )
            )
        }

        let presentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .sr1),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: PianoPanelState(isVisible: true),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToPiano,
                    layoutPreset: .stacked,
                    accessoryPresentation: .docked,
                    isNaturalNoteStripVisible: false,
                    isPianoAccessoryVisible: true,
                    isAccessoryExpanded: true
                )
            )
        )
        let presentationPianoSurfaceCount = presentation.scene.surfaceNodes.filter {
            $0.id == .piano
        }.count
        if presentation.resolvedLayoutPreferences.compositionPreset != .staffToPiano {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 在 shared composition policy 中不应被错误降级回旧 preset。"
                )
            )
        }
        if presentation.resolvedLayoutPreferences.isPianoAccessoryVisible {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 在 makePresentation 中应强制关闭 piano accessory，避免 duplicate `.piano` surface。"
                )
            )
        }
        if presentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 的主 scene 不应被误标记为 legacy page 可直接投影。"
                )
            )
        }
        if ExerciseSceneValidator.legacyPageDisplayState(for: presentation.scene) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 的 presentation.scene 应继续被 scene validator 视为 non-legacy；`legacyPageDisplayState == nil` 在 SR-1 下是预期结果。"
                )
            )
        }
        if presentationPianoSurfaceCount != 1 {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 的最终 presentation.scene 只允许保留一个主 `.piano` surface。"
                )
            )
        }
        if presentation.projectedSurfaceState(for: .staff) != .promptOnly {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 中的 `staff` 应继续暴露 prompt-only surface state。"
                )
            )
        }
        if presentation.projectedSurfaceState(for: .piano) != .answerOnly {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` 中的主 `piano` 应暴露 answer-only surface state。"
                )
            )
        }
        if presentation.containsSurface(.fretboard)
            || presentation.containsSurface(.naturalNoteStrip) {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToPiano` scene 不应混入 `fretboard` 或 `natural note strip`。"
                )
            )
        }

        return issues
    }

    static func validateStaffToNaturalNoteStripScenePromotesMainNaturalNoteStripAnswerSurface()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName =
            "staff_to_natural_note_strip_scene_promotes_main_natural_note_strip_answer_surface"
        var issues: [ExerciseCompositionValidationIssue] = []

        let rawScene = ExerciseCompositionPolicy.makeScene(
            preferences: ExerciseLayoutPreferences(
                compositionPreset: .staffToNaturalNoteStrip,
                layoutPreset: .stacked,
                accessoryPresentation: .docked,
                isNaturalNoteStripVisible: true,
                isPianoAccessoryVisible: false,
                isAccessoryExpanded: true
            )
        )
        let rawSurfaceIDs = rawScene.surfaceNodes.map(\.id)
        let rawStripSurfaceCount = rawScene.surfaceNodes.filter {
            $0.id == .naturalNoteStrip
        }.count
        if rawSurfaceIDs.count != 2
            || Set(rawSurfaceIDs) != Set([.staff, .naturalNoteStrip]) {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` scene 应只保留主 `staff` 与主 `natural note strip`，不应混入 fretboard / piano 或 duplicate strip。"
                )
            )
        }
        if !ExerciseSceneValidator.validate(rawScene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` scene 应生成合法 scene。"
                )
            )
        }
        if rawStripSurfaceCount != 1 {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 的 raw scene 里只允许存在一个逻辑 `.naturalNoteStrip` surface。"
                )
            )
        }
        if ExerciseSceneValidator.legacyPageDisplayState(for: rawScene) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 的 raw scene 应被视为 non-legacy 新场景，而不是回投影成旧 page 结构。"
                )
            )
        }
        switch rawScene.root {
        case let .split(axis, children):
            if axis != .vertical
                || children.count != 2
                || children[0].mainAxisSizing != .fitContent
                || children[1].mainAxisSizing != .fitContent {
                issues.append(
                    issue(
                        fixtureName,
                        "`staffToNaturalNoteStrip` 的 stacked scene 应保持上方 staff fitContent、下方 natural note strip fitContent。"
                    )
                )
            }
            guard
                children.count == 2,
                case let .surface(topSurface) = children[0].node,
                case let .surface(bottomSurface) = children[1].node
            else {
                break
            }
            if topSurface.id != .staff
                || !topSurface.isPromptSurface
                || topSurface.isAnswerSurface {
                issues.append(
                    issue(
                        fixtureName,
                        "`staffToNaturalNoteStrip` 的上方 surface 应保持 prompt-only 的 `staff`。"
                    )
                )
            }
            if bottomSurface.id != .naturalNoteStrip
                || bottomSurface.isPromptSurface
                || !bottomSurface.isAnswerSurface
                || bottomSurface.isAuxiliarySurface
                || bottomSurface.presentationStyle != .horizontalStrip {
                issues.append(
                    issue(
                        fixtureName,
                        "`staffToNaturalNoteStrip` 的下方 surface 应提升为 answer-only 的主 `natural note strip`，并保持 `horizontalStrip` presentation style。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 的主 scene 应投影成 vertical split。"
                )
            )
        }

        let presentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .sr0),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: PianoPanelState(isVisible: true),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .targetPromptToFretboard,
                    layoutPreset: .sideBySide,
                    accessoryPresentation: .floating,
                    isNaturalNoteStripVisible: false,
                    isPianoAccessoryVisible: true,
                    isAccessoryExpanded: false
                )
            )
        )
        let presentationStripSurfaceCount = presentation.scene.surfaceNodes.filter {
            $0.id == .naturalNoteStrip
        }.count
        if presentation.resolvedLayoutPreferences != .srNoteStripAnswer {
            issues.append(
                issue(
                    fixtureName,
                    "SR-0 的 makePresentation 应固定收敛到 `srNoteStripAnswer`，而不是沿用请求的自由组合。"
                )
            )
        }
        if presentation.legacyPageDisplayState != nil {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 的 presentation.scene 不应被误标记为 legacy page 可直接投影。"
                )
            )
        }
        if ExerciseSceneValidator.legacyPageDisplayState(for: presentation.scene)
            != nil {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 的 presentation.scene 应继续被 scene validator 视为 non-legacy；`legacyPageDisplayState == nil` 在 SR-0 下是预期结果。"
                )
            )
        }
        if presentationStripSurfaceCount != 1 {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 的最终 presentation.scene 只允许保留一个主 `.naturalNoteStrip` surface。"
                )
            )
        }
        if presentation.projectedSurfaceState(for: .staff) != .promptOnly {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 中的 `staff` 应继续暴露 prompt-only surface state。"
                )
            )
        }
        if presentation.projectedSurfaceState(for: .naturalNoteStrip)
            != .answerOnly {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` 中的主 `natural note strip` 应暴露 answer-only surface state。"
                )
            )
        }
        if presentation.containsSurface(.fretboard)
            || presentation.containsSurface(.piano) {
            issues.append(
                issue(
                    fixtureName,
                    "`staffToNaturalNoteStrip` scene 不应混入 `fretboard` 或 `piano`。"
                )
            )
        }

        return issues
    }

    static func validateSharedSurfaceStateDefaultsFollowSurfaceRoles()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "shared_surface_state_defaults_follow_surface_roles"
        var issues: [ExerciseCompositionValidationIssue] = []
        var presentationState = ExercisePresentationState(
            scene: .singleSurface(.fretboardPromptAndAnswer)
        )

        guard let defaultFretboardState = presentationState.projectedSurfaceState(
            for: .fretboard
        ) else {
            issues.append(
                issue(
                    fixtureName,
                    "presentation state 应能为 scene 中的 fretboard 推导默认 surface state。"
                )
            )
            return issues
        }

        if !defaultFretboardState.isVisible
            || !defaultFretboardState.isPromptActive
            || !defaultFretboardState.isAnswerEnabled
            || !defaultFretboardState.isInteractionEnabled {
            issues.append(
                issue(
                    fixtureName,
                    "双角色 fretboard 的默认 surface state 应同时开启可见、prompt active、answer enabled 与 interaction enabled。"
                )
            )
        }
        if presentationState.containsSurface(.staff) {
            issues.append(
                issue(
                    fixtureName,
                    "presentation state 不应把不在 scene 中的 surface 误报为结构成员。"
                )
            )
        }
        if presentationState.projectedSurfaceState(for: .staff) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "presentation state 不应为不在 scene 中的 surface 凭空生成状态。"
                )
            )
        }
        if presentationState.effectiveSurfaceState(for: .staff) != .hidden {
            issues.append(
                issue(
                    fixtureName,
                    "presentation state 应把不在 scene 中的 surface 统一收口为 hidden 的 effective state。"
                )
            )
        }

        presentationState.setSurfaceState(
            ExerciseSurfaceState(
                isVisible: false,
                isPromptActive: true,
                isAnswerEnabled: false,
                isInteractionEnabled: false
            ),
            for: .fretboard
        )
        let overriddenState = presentationState.projectedSurfaceState(
            for: .fretboard
        )
        if overriddenState?.isVisible ?? true
            || !(overriddenState?.isPromptActive ?? false)
            || overriddenState?.isAnswerEnabled ?? true
            || overriddenState?.isInteractionEnabled ?? true {
            issues.append(
                issue(
                    fixtureName,
                    "显式写入的 surface state 应覆盖默认角色投影。"
                )
            )
        }

        return issues
    }

    static func validateSurfaceMembershipDistinguishesAbsentAndHiddenStates()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "surface_membership_distinguishes_absent_and_hidden_states"
        var issues: [ExerciseCompositionValidationIssue] = []

        let targetPromptSideBySidePresentation = ExerciseCompositionPolicy
            .makePresentation(
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
        if targetPromptSideBySidePresentation.containsSurface(.naturalNoteStrip) {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide 组合不应把 natural note strip 记为 scene 成员。"
                )
            )
        }
        if targetPromptSideBySidePresentation.projectedSurfaceState(
            for: .naturalNoteStrip
        ) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide 组合不应为缺席的 natural note strip 暴露 projected state。"
                )
            )
        }
        if targetPromptSideBySidePresentation.effectiveSurfaceState(
            for: .naturalNoteStrip
        ) != .hidden {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide 组合应把缺席的 natural note strip 收口为 hidden effective state。"
                )
            )
        }

        let staffSideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: TrainerDisplayState(exerciseMode: .sequence),
                fretboardTrainerState: .init(),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .staffToFretboard,
                    layoutPreset: .sideBySide
                )
            )
        )
        if staffSideBySidePresentation.containsSurface(.naturalNoteStrip) {
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard 的 sideBySide 组合不应把 natural note strip 记为 scene 成员。"
                )
            )
        }
        if staffSideBySidePresentation.projectedSurfaceState(
            for: .naturalNoteStrip
        ) != nil {
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard 的 sideBySide 组合不应为缺席的 natural note strip 暴露 projected state。"
                )
            )
        }
        if staffSideBySidePresentation.effectiveSurfaceState(
            for: .naturalNoteStrip
        ) != .hidden {
            issues.append(
                issue(
                    fixtureName,
                    "staff -> fretboard 的 sideBySide 组合应把缺席的 natural note strip 收口为 hidden effective state。"
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
        if !sideBySidePositionPromptPresentation.containsSurface(
            .naturalNoteStrip
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 sideBySide 组合应继续投影 natural note strip。"
                )
            )
        }
        if sideBySidePositionPromptPresentation.projectedSurfaceState(
            for: .naturalNoteStrip
        ) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 sideBySide 组合应暴露 natural note strip 的 projected state。"
                )
            )
        }
        if sideBySidePositionPromptPresentation.scene.surfaceNode(
            for: .naturalNoteStrip
        )?.presentationStyle != .verticalRail {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 sideBySide 组合应把 natural note strip 标记为 verticalRail。"
                )
            )
        }

        let stackedPositionPromptPresentation = ExerciseCompositionPolicy
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
                        layoutPreset: .stacked,
                        accessoryPresentation: .docked,
                        isNaturalNoteStripVisible: true,
                        isPianoAccessoryVisible: false,
                        isAccessoryExpanded: true
                    )
                )
            )
        if !stackedPositionPromptPresentation.containsSurface(.naturalNoteStrip) {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 stacked 组合应继续投影 natural note strip。"
                )
            )
        }
        if stackedPositionPromptPresentation.projectedSurfaceState(
            for: .naturalNoteStrip
        ) == nil {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 stacked 组合应暴露 natural note strip 的 projected state。"
                )
            )
        }
        if stackedPositionPromptPresentation.scene.surfaceNode(
            for: .naturalNoteStrip
        )?.presentationStyle != .horizontalStrip {
            issues.append(
                issue(
                    fixtureName,
                    "fretboard -> natural note strip 的 stacked 组合应把 natural note strip 保持为 horizontalStrip。"
                )
            )
        }

        return issues
    }
    static func validateSceneValidatorRejectsDuplicateLogicalSurfaceIDs()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "scene_validator_rejects_duplicate_logical_surface_ids"
        var issues: [ExerciseCompositionValidationIssue] = []

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
        if !duplicateIssues.contains(.duplicateSurfaceID(.fretboard)) {
            issues.append(
                issue(
                    fixtureName,
                    "validator 应拒绝同一个 logical fretboard 被拆成两个 scene 节点的情况。"
                )
            )
        }

        let validSelfAnswerScene = ExerciseScene.singleSurface(
            .fretboardPromptAndAnswer
        )
        if !ExerciseSceneValidator.validate(validSelfAnswerScene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "同时承担 prompt/answer 的单 fretboard scene 不应被 validator 误判为重复 surface。"
                )
            )
        }

        return issues
    }

    static func validateSceneValidatorRestrictsVerticalRailToHorizontalSplit()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "scene_validator_restricts_vertical_rail_to_horizontal_split"
        var issues: [ExerciseCompositionValidationIssue] = []

        let invalidVerticalRailStackedScene = ExerciseScene(
            root: .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(
                        node: .surface(.fretboardPrompt),
                        mainAxisSizing: .weighted(1)
                    ),
                    ExerciseSceneSplitChild(
                        node: .surface(
                            .naturalNoteStripAnswer.withPresentationStyle(
                                .verticalRail
                            )
                        ),
                        mainAxisSizing: .fitContent
                    )
                ]
            )
        )
        let invalidIssues = ExerciseSceneValidator.validate(
            invalidVerticalRailStackedScene
        )
        if !invalidIssues.contains(
            .verticalRailRequiresHorizontalSplit(.naturalNoteStrip)
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "validator 应拒绝把 verticalRail strip 放进非 horizontal split 语境。"
                )
            )
        }

        let validVerticalRailSideBySideScene = ExerciseScene(
            root: .makeSplit(
                axis: .horizontal,
                children: [
                    ExerciseSceneSplitChild(
                        node: .surface(.fretboardPrompt),
                        mainAxisSizing: .weighted(1)
                    ),
                    ExerciseSceneSplitChild(
                        node: .surface(
                            .naturalNoteStripAnswer.withPresentationStyle(
                                .verticalRail
                            )
                        ),
                        mainAxisSizing: .fitContent
                    )
                ]
            )
        )
        let validIssues = ExerciseSceneValidator.validate(
            validVerticalRailSideBySideScene
        )
        if validIssues.contains(
            .verticalRailRequiresHorizontalSplit(.naturalNoteStrip)
        ) {
            issues.append(
                issue(
                    fixtureName,
                    "validator 不应误判位于 horizontal split 中的 verticalRail strip。"
                )
            )
        }

        return issues
    }

    static func validateViewportPinningContractsPreserveRailAndStackedLayouts()
        -> [ExerciseCompositionValidationIssue] {
        let fixtureName = "viewport_pinning_contracts_preserve_rail_and_stacked_layouts"
        var issues: [ExerciseCompositionValidationIssue] = []

        let positionPromptTrainerDisplayState = TrainerDisplayState(
            exerciseMode: .positionPrompt
        )
        let railPresentation = ExerciseCompositionPolicy.makePresentation(
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
        if !ExerciseSceneValidator.validate(railPresentation.scene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 positionPrompt scene 在阶段 5 应继续通过 scene validator。"
                )
            )
        }
        switch railPresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "右侧 rail 的 positionPrompt scene 在阶段 5 应保持 horizontal split。"
                    )
                )
            }
            if children.count != 2
                || children[0].mainAxisSizing != .weighted(1)
                || children[1].mainAxisSizing != .fitContent {
                issues.append(
                    issue(
                        fixtureName,
                        "右侧 rail 的 positionPrompt scene 在阶段 5 应保持左 weighted(1)、右 fitContent 的主轴尺寸语义。"
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
            if promptSurface.id != .fretboard
                || promptSurface.presentationStyle != .standard
                || answerSurface.id != .naturalNoteStrip
                || answerSurface.presentationStyle != .verticalRail {
                issues.append(
                    issue(
                        fixtureName,
                        "右侧 rail 的 positionPrompt scene 在阶段 5 应继续保持左 fretboard standard、右 natural note strip verticalRail。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 positionPrompt scene 在阶段 5 应继续落成 split scene。"
                )
            )
        }
        if !railPresentation.scene.hasMixedMainAxisSizing(along: .horizontal) {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 positionPrompt scene 在阶段 5 应继续触发 horizontal mixed main-axis sizing。"
                )
            )
        }
        if railPresentation.scene.hasMixedMainAxisSizing(along: .vertical) {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 positionPrompt scene 在阶段 5 不应误报为 vertical mixed main-axis sizing。"
                )
            )
        }
        if !railPresentation.scene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "右侧 rail 的 positionPrompt scene 在阶段 5 应继续要求 viewport pin 高度。"
                )
            )
        }

        let stackedPresentation = ExerciseCompositionPolicy.makePresentation(
            from: ExerciseCompositionPolicyInput(
                trainerDisplayState: positionPromptTrainerDisplayState,
                fretboardTrainerState: .init(positionPromptMode: ()),
                fretboardDisplayState: .default,
                staffDisplayState: .default,
                pianoPanelState: .init(),
                layoutPreferences: ExerciseLayoutPreferences(
                    compositionPreset: .fretboardToNaturalNoteStrip,
                    layoutPreset: .stacked
                )
            )
        )
        if !ExerciseSceneValidator.validate(stackedPresentation.scene).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续通过 scene validator。"
                )
            )
        }
        switch stackedPresentation.scene.root {
        case let .split(axis, children):
            if axis != .vertical {
                issues.append(
                    issue(
                        fixtureName,
                        "stacked 的 fretboard -> natural note strip scene 在阶段 5 应保持 vertical split。"
                    )
                )
            }
            if children.count != 2
                || children[0].mainAxisSizing != .weighted(1)
                || children[1].mainAxisSizing != .fitContent {
                issues.append(
                    issue(
                        fixtureName,
                        "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续保持上 weighted(1)、下 fitContent 的主轴尺寸语义。"
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
            if promptSurface.id != .fretboard
                || promptSurface.presentationStyle != .standard
                || answerSurface.id != .naturalNoteStrip
                || answerSurface.presentationStyle != .horizontalStrip {
                issues.append(
                    issue(
                        fixtureName,
                        "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续保持上方 standard fretboard、下方 horizontalStrip strip。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续落成 split scene。"
                )
            )
        }
        if !stackedPresentation.scene.hasMixedMainAxisSizing(along: .vertical) {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续触发 vertical mixed main-axis sizing。"
                )
            )
        }
        if stackedPresentation.scene.hasMixedMainAxisSizing(along: .horizontal) {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 不应误报为 horizontal mixed main-axis sizing。"
                )
            )
        }
        if !stackedPresentation.scene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续要求 viewport pin 高度。"
                )
            )
        }
        if stackedPresentation.fretboardLayoutContract.heightPolicy
            != .followViewportRatio {
            issues.append(
                issue(
                    fixtureName,
                    "stacked 的 fretboard -> natural note strip scene 在阶段 5 应继续沿用 viewport ratio 高度语义。"
                )
            )
        }

        let targetPromptSideBySidePresentation = ExerciseCompositionPolicy.makePresentation(
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
        if !ExerciseSceneValidator.validate(
            targetPromptSideBySidePresentation.scene
        ).isEmpty {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 应继续通过 scene validator。"
                )
            )
        }
        switch targetPromptSideBySidePresentation.scene.root {
        case let .split(axis, children):
            if axis != .horizontal {
                issues.append(
                    issue(
                        fixtureName,
                        "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 应保持 horizontal split。"
                    )
                )
            }
            if children.count != 2
                || children[0].mainAxisSizing != .weighted(1)
                || children[1].mainAxisSizing != .weighted(1) {
                issues.append(
                    issue(
                        fixtureName,
                        "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 仍应保持双 weighted 主轴尺寸语义。"
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
                        "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 不应被 verticalRail 或 horizontalStrip answer 语义污染。"
                    )
                )
            }
        default:
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 应继续落成 split scene。"
                )
            )
        }
        if !targetPromptSideBySidePresentation.scene.requiresViewportPinnedHeight {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 应继续要求 viewport pin 高度。"
                )
            )
        }
        if targetPromptSideBySidePresentation.fretboardLayoutContract.heightPolicy
            != .fillAvailableHeight {
            issues.append(
                issue(
                    fixtureName,
                    "targetPrompt -> fretboard 的 sideBySide scene 在阶段 5 应让主 fretboard 跟随 side 容器填满高度。"
                )
            )
        }

        return issues
    }
}

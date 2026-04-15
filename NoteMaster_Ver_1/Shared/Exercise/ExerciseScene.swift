//
//  ExerciseScene.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

enum ExerciseRole: String, CaseIterable, Equatable, Hashable, Sendable {
    case prompt
    case answer
    case auxiliary
}

typealias ExerciseSurfaceID = AppSurfaceID
typealias ExerciseSurfaceKind = AppSurfaceKind
typealias ExerciseSurfacePresentationStyle = AppSurfacePresentationStyle
typealias ExerciseSceneAxis = SceneAxis
typealias ExerciseSceneSplitChildMainAxisSizing = SceneSplitChildMainAxisSizing
typealias ExerciseSceneSplitChild = SceneSplitChild<ExerciseSurfaceNode>
typealias ExerciseSceneNode = SceneNode<ExerciseSurfaceNode>
typealias ExerciseScene = Scene<ExerciseSurfaceNode>

nonisolated struct ExerciseSurfaceNode: SceneSurfaceProtocol, Equatable, Sendable {
    private var baseSurface: AppSurfaceNode
    private(set) var roles: Set<ExerciseRole>

    var id: ExerciseSurfaceID {
        get { baseSurface.id }
        set { baseSurface.id = newValue }
    }

    var kind: ExerciseSurfaceKind {
        get { baseSurface.kind }
        set { baseSurface.kind = newValue }
    }

    var presentationStyle: ExerciseSurfacePresentationStyle {
        get { baseSurface.presentationStyle }
        set { baseSurface.presentationStyle = newValue }
    }

    init(
        id: ExerciseSurfaceID,
        kind: ExerciseSurfaceKind,
        roles: Set<ExerciseRole>,
        presentationStyle: ExerciseSurfacePresentationStyle = .standard
    ) {
        precondition(
            !roles.isEmpty,
            "Exercise surface must expose at least one role."
        )
        self.baseSurface = AppSurfaceNode(
            id: id,
            kind: kind,
            presentationStyle: presentationStyle
        )
        self.roles = roles
    }

    var isPromptSurface: Bool {
        roles.contains(.prompt)
    }

    var isAnswerSurface: Bool {
        roles.contains(.answer)
    }

    var isAuxiliarySurface: Bool {
        roles.contains(.auxiliary)
    }

    var isNaturalNoteStripAnswerRail: Bool {
        id == .naturalNoteStrip
            && kind == .naturalNoteStrip
            && isAnswerSurface
            && presentationStyle == .verticalRail
    }

    func withPresentationStyle(
        _ presentationStyle: ExerciseSurfacePresentationStyle
    ) -> ExerciseSurfaceNode {
        var copy = self
        copy.presentationStyle = presentationStyle
        return copy
    }
}

extension Scene where Surface == ExerciseSurfaceNode {
    static func stacked(
        top: ExerciseSurfaceNode,
        bottom: ExerciseSurfaceNode
    ) -> ExerciseScene {
        ExerciseScene(
            root: .makeSplit(
                axis: .vertical,
                children: [
                    ExerciseSceneSplitChild(
                        node: .surface(top),
                        mainAxisSizing: top.preferredVerticalMainAxisSizing()
                    ),
                    ExerciseSceneSplitChild(
                        node: .surface(bottom),
                        mainAxisSizing: bottom.preferredVerticalMainAxisSizing()
                    )
                ]
            )
        )
    }

    static func sideBySide(
        leading: ExerciseSurfaceNode,
        trailing: ExerciseSurfaceNode
    ) -> ExerciseScene {
        ExerciseScene(
            root: .makeSplit(
                axis: .horizontal,
                children: [
                    ExerciseSceneSplitChild(node: .surface(leading)),
                    ExerciseSceneSplitChild(node: .surface(trailing))
                ]
            )
        )
    }
}

extension ExerciseSurfaceNode {
    func preferredVerticalMainAxisSizing(
        weight: Double = 1
    ) -> ExerciseSceneSplitChildMainAxisSizing {
        switch kind {
        case .staff, .targetPrompt, .naturalNoteStrip:
            return .fitContent
        case .fretboard, .piano:
            return .weighted(weight)
        }
    }

    static let staffPrompt = ExerciseSurfaceNode(
        id: .staff,
        kind: .staff,
        roles: [.prompt]
    )
    static let targetPrompt = ExerciseSurfaceNode(
        id: .targetPrompt,
        kind: .targetPrompt,
        roles: [.prompt]
    )
    static let fretboardPrompt = ExerciseSurfaceNode(
        id: .fretboard,
        kind: .fretboard,
        roles: [.prompt]
    )
    static let fretboardAnswer = ExerciseSurfaceNode(
        id: .fretboard,
        kind: .fretboard,
        roles: [.answer]
    )
    static let fretboardPromptAndAnswer = ExerciseSurfaceNode(
        id: .fretboard,
        kind: .fretboard,
        roles: [.prompt, .answer]
    )
    static let naturalNoteStripAnswer = ExerciseSurfaceNode(
        id: .naturalNoteStrip,
        kind: .naturalNoteStrip,
        roles: [.answer],
        presentationStyle: .horizontalStrip
    )
    static let naturalNoteStripAccessory = ExerciseSurfaceNode(
        id: .naturalNoteStrip,
        kind: .naturalNoteStrip,
        roles: [.auxiliary],
        presentationStyle: .horizontalStrip
    )
    static let pianoAnswer = ExerciseSurfaceNode(
        id: .piano,
        kind: .piano,
        roles: [.answer]
    )
    static let pianoAccessory = ExerciseSurfaceNode(
        id: .piano,
        kind: .piano,
        roles: [.auxiliary]
    )
}

extension SceneNode where Surface == ExerciseSurfaceNode {
    var containsNaturalNoteStripAnswerRailInSideBySideLayout: Bool {
        switch self {
        case .surface:
            return false
        case let .split(axis, children):
            let isCurrentNaturalNoteStripAnswerRailLayout = axis == .horizontal
                && children.count >= 2
                && children.contains { $0.node.containsSurface(.fretboard) }
                && children.contains {
                    $0.node.surfaceNodes.contains(where: {
                        $0.isNaturalNoteStripAnswerRail
                    })
                }
            return isCurrentNaturalNoteStripAnswerRailLayout
                || children.contains {
                    $0.node.containsNaturalNoteStripAnswerRailInSideBySideLayout
                }
        case let .overlay(base, _):
            return base.containsNaturalNoteStripAnswerRailInSideBySideLayout
        case let .collapsible(main, _, _):
            return main.containsNaturalNoteStripAnswerRailInSideBySideLayout
        }
    }

    var containsMainFretboardInSideBySideLayout: Bool {
        switch self {
        case .surface:
            return false
        case let .split(axis, children):
            let isCurrentSideBySideFretboard = axis == .horizontal
                && children.count >= 2
                && children.contains { $0.node.containsSurface(.fretboard) }
            return isCurrentSideBySideFretboard
                || children.contains {
                    $0.node.containsMainFretboardInSideBySideLayout
                }
        case let .overlay(base, _):
            return base.containsMainFretboardInSideBySideLayout
        case let .collapsible(main, _, _):
            return main.containsMainFretboardInSideBySideLayout
        }
    }

    func hasMixedMainAxisSizing(
        along axis: ExerciseSceneAxis
    ) -> Bool {
        switch self {
        case .surface:
            return false
        case let .split(splitAxis, children):
            let hasCurrentMixedMainAxisSizing = splitAxis == axis
                && children.contains(where: { $0.mainAxisSizing.isWeighted })
                && children.contains(where: { !$0.mainAxisSizing.isWeighted })
            return hasCurrentMixedMainAxisSizing
                || children.contains { $0.node.hasMixedMainAxisSizing(along: axis) }
        case let .overlay(base, floating):
            return base.hasMixedMainAxisSizing(along: axis)
                || floating.contains { $0.hasMixedMainAxisSizing(along: axis) }
        case let .collapsible(main, accessory, _):
            return main.hasMixedMainAxisSizing(along: axis)
                || accessory.hasMixedMainAxisSizing(along: axis)
        }
    }

    func hasMixedMainAxisSizing(
        along axis: ExerciseSceneAxis,
        containing surfaceID: ExerciseSurfaceID
    ) -> Bool {
        switch self {
        case .surface:
            return false
        case let .split(splitAxis, children):
            let hasCurrentMixedMainAxisSizing = splitAxis == axis
                && children.contains(where: { $0.mainAxisSizing.isWeighted })
                && children.contains(where: { !$0.mainAxisSizing.isWeighted })
                && children.contains { $0.node.containsSurface(surfaceID) }
            return hasCurrentMixedMainAxisSizing
                || children.contains {
                    $0.node.hasMixedMainAxisSizing(
                        along: axis,
                        containing: surfaceID
                    )
                }
        case let .overlay(base, floating):
            return base.hasMixedMainAxisSizing(
                along: axis,
                containing: surfaceID
            )
                || floating.contains {
                    $0.hasMixedMainAxisSizing(
                        along: axis,
                        containing: surfaceID
                    )
                }
        case let .collapsible(main, accessory, _):
            return main.hasMixedMainAxisSizing(
                along: axis,
                containing: surfaceID
            )
                || accessory.hasMixedMainAxisSizing(
                    along: axis,
                    containing: surfaceID
                )
        }
    }

    var requiresViewportPinnedHeight: Bool {
        hasMixedMainAxisSizing(along: .vertical)
            || surfaceNodes.contains(where: {
                $0.presentationStyle == .verticalRail
            })
            || containsMainFretboardInSideBySideLayout
    }
}

extension Scene where Surface == ExerciseSurfaceNode {
    var containsNaturalNoteStripAnswerRailInSideBySideLayout: Bool {
        root.containsNaturalNoteStripAnswerRailInSideBySideLayout
    }

    var containsMainFretboardInSideBySideLayout: Bool {
        root.containsMainFretboardInSideBySideLayout
    }

    func hasMixedMainAxisSizing(
        along axis: ExerciseSceneAxis
    ) -> Bool {
        root.hasMixedMainAxisSizing(along: axis)
    }

    func hasMixedMainAxisSizing(
        along axis: ExerciseSceneAxis,
        containing surfaceID: ExerciseSurfaceID
    ) -> Bool {
        root.hasMixedMainAxisSizing(along: axis, containing: surfaceID)
    }

    var requiresViewportPinnedHeight: Bool {
        root.requiresViewportPinnedHeight
    }
}

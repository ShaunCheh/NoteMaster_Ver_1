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

enum ExerciseSurfaceID: String, CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case targetPrompt
    case naturalNoteStrip
    case piano
}

enum ExerciseSurfaceKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case targetPrompt
    case naturalNoteStrip
    case piano
}

enum ExerciseSurfacePresentationStyle: String, CaseIterable, Equatable, Hashable, Sendable {
    case standard
    case horizontalStrip
    case verticalRail
}

enum ExerciseSceneAxis: String, Equatable, Hashable, Sendable {
    case vertical
    case horizontal
}

enum ExerciseSceneSplitChildMainAxisSizing: Equatable, Hashable, Sendable {
    case weighted(Double)
    case fitContent
    case fixed(Double)

    var weightedValue: Double? {
        guard case let .weighted(weight) = self else {
            return nil
        }

        return weight
    }

    var isWeighted: Bool {
        weightedValue != nil
    }
}

struct ExerciseSurfaceNode: Equatable, Sendable {
    var id: ExerciseSurfaceID
    var kind: ExerciseSurfaceKind
    private(set) var roles: Set<ExerciseRole>
    var presentationStyle: ExerciseSurfacePresentationStyle

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
        self.id = id
        self.kind = kind
        self.roles = roles
        self.presentationStyle = presentationStyle
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

    func withPresentationStyle(
        _ presentationStyle: ExerciseSurfacePresentationStyle
    ) -> ExerciseSurfaceNode {
        var copy = self
        copy.presentationStyle = presentationStyle
        return copy
    }
}

struct ExerciseSceneSplitChild: Equatable, Sendable {
    var node: ExerciseSceneNode
    var mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing

    init(
        node: ExerciseSceneNode,
        mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing = .weighted(1)
    ) {
        switch mainAxisSizing {
        case let .weighted(weight):
            precondition(
                weight > 0,
                "Exercise scene split child weight must be greater than zero."
            )
        case let .fixed(size):
            precondition(
                size > 0,
                "Exercise scene split child fixed size must be greater than zero."
            )
        case .fitContent:
            break
        }
        self.node = node
        self.mainAxisSizing = mainAxisSizing
    }
}

indirect enum ExerciseSceneNode: Equatable, Sendable {
    case surface(ExerciseSurfaceNode)
    case split(axis: ExerciseSceneAxis, children: [ExerciseSceneSplitChild])
    case overlay(base: ExerciseSceneNode, floating: [ExerciseSceneNode])
    case collapsible(
        main: ExerciseSceneNode,
        accessory: ExerciseSceneNode,
        isExpanded: Bool
    )

    static func makeSplit(
        axis: ExerciseSceneAxis,
        children: [ExerciseSceneSplitChild]
    ) -> ExerciseSceneNode {
        precondition(
            children.count >= 2,
            "Exercise split scene must contain at least two children."
        )
        return .split(axis: axis, children: children)
    }

    static func makeOverlay(
        base: ExerciseSceneNode,
        floating: [ExerciseSceneNode]
    ) -> ExerciseSceneNode {
        precondition(
            !floating.isEmpty,
            "Exercise overlay scene must contain at least one floating node."
        )
        return .overlay(base: base, floating: floating)
    }

    static func makeCollapsible(
        main: ExerciseSceneNode,
        accessory: ExerciseSceneNode,
        isExpanded: Bool
    ) -> ExerciseSceneNode {
        .collapsible(
            main: main,
            accessory: accessory,
            isExpanded: isExpanded
        )
    }

    var surfaceNodes: [ExerciseSurfaceNode] {
        switch self {
        case let .surface(surface):
            return [surface]
        case let .split(_, children):
            return children.flatMap { $0.node.surfaceNodes }
        case let .overlay(base, floating):
            return base.surfaceNodes + floating.flatMap { $0.surfaceNodes }
        case let .collapsible(main, accessory, _):
            return main.surfaceNodes + accessory.surfaceNodes
        }
    }

    func surfaceNode(for surfaceID: ExerciseSurfaceID) -> ExerciseSurfaceNode? {
        switch self {
        case let .surface(surface):
            return surface.id == surfaceID ? surface : nil
        case let .split(_, children):
            return children.compactMap {
                $0.node.surfaceNode(for: surfaceID)
            }.first
        case let .overlay(base, floating):
            if let match = base.surfaceNode(for: surfaceID) {
                return match
            }
            return floating.compactMap {
                $0.surfaceNode(for: surfaceID)
            }.first
        case let .collapsible(main, accessory, _):
            if let match = main.surfaceNode(for: surfaceID) {
                return match
            }
            return accessory.surfaceNode(for: surfaceID)
        }
    }

    func containsSurface(_ surfaceID: ExerciseSurfaceID) -> Bool {
        surfaceNode(for: surfaceID) != nil
    }
}

struct ExerciseScene: Equatable, Sendable {
    var root: ExerciseSceneNode

    init(root: ExerciseSceneNode) {
        self.root = root
    }

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

    static func singleSurface(_ surface: ExerciseSurfaceNode) -> ExerciseScene {
        ExerciseScene(root: .surface(surface))
    }

    var surfaceNodes: [ExerciseSurfaceNode] {
        root.surfaceNodes
    }

    func surfaceNode(for surfaceID: ExerciseSurfaceID) -> ExerciseSurfaceNode? {
        root.surfaceNode(for: surfaceID)
    }

    func containsSurface(_ surfaceID: ExerciseSurfaceID) -> Bool {
        root.containsSurface(surfaceID)
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
    static let pianoAccessory = ExerciseSurfaceNode(
        id: .piano,
        kind: .piano,
        roles: [.auxiliary]
    )
}

extension ExerciseSceneNode {
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

extension ExerciseScene {
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

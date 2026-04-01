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

enum ExerciseSceneAxis: String, Equatable, Hashable, Sendable {
    case vertical
    case horizontal
}

enum ExerciseSceneSplitChildSizing: String, Equatable, Hashable, Sendable {
    case fill
    case fitContent
}

struct ExerciseSurfaceNode: Equatable, Sendable {
    var id: ExerciseSurfaceID
    var kind: ExerciseSurfaceKind
    private(set) var roles: Set<ExerciseRole>

    init(
        id: ExerciseSurfaceID,
        kind: ExerciseSurfaceKind,
        roles: Set<ExerciseRole>
    ) {
        precondition(
            !roles.isEmpty,
            "Exercise surface must expose at least one role."
        )
        self.id = id
        self.kind = kind
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
}

struct ExerciseSceneSplitChild: Equatable, Sendable {
    var node: ExerciseSceneNode
    var weight: Double
    var sizing: ExerciseSceneSplitChildSizing

    init(
        node: ExerciseSceneNode,
        weight: Double = 1,
        sizing: ExerciseSceneSplitChildSizing = .fill
    ) {
        precondition(
            weight > 0,
            "Exercise scene split child weight must be greater than zero."
        )
        self.node = node
        self.weight = weight
        self.sizing = sizing
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
                        sizing: top.preferredVerticalSplitSizing
                    ),
                    ExerciseSceneSplitChild(
                        node: .surface(bottom),
                        sizing: bottom.preferredVerticalSplitSizing
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
}

extension ExerciseSurfaceNode {
    var preferredVerticalSplitSizing: ExerciseSceneSplitChildSizing {
        switch kind {
        case .staff, .targetPrompt, .naturalNoteStrip:
            return .fitContent
        case .fretboard, .piano:
            return .fill
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
        roles: [.answer]
    )
    static let naturalNoteStripAccessory = ExerciseSurfaceNode(
        id: .naturalNoteStrip,
        kind: .naturalNoteStrip,
        roles: [.auxiliary]
    )
    static let pianoAccessory = ExerciseSurfaceNode(
        id: .piano,
        kind: .piano,
        roles: [.auxiliary]
    )
}

extension ExerciseSceneNode {
    var hasVerticalFitContentSplit: Bool {
        switch self {
        case .surface:
            return false
        case let .split(axis, children):
            let hasCurrentFitContentSplit = axis == .vertical
                && children.contains(where: { $0.sizing == .fitContent })
                && children.contains(where: { $0.sizing == .fill })
            return hasCurrentFitContentSplit
                || children.contains { $0.node.hasVerticalFitContentSplit }
        case let .overlay(base, floating):
            return base.hasVerticalFitContentSplit
                || floating.contains { $0.hasVerticalFitContentSplit }
        case let .collapsible(main, accessory, _):
            return main.hasVerticalFitContentSplit
                || accessory.hasVerticalFitContentSplit
        }
    }

    func hasVerticalFitContentSplit(
        containing surfaceID: ExerciseSurfaceID
    ) -> Bool {
        switch self {
        case .surface:
            return false
        case let .split(axis, children):
            let hasCurrentFitContentSplit = axis == .vertical
                && children.contains(where: { $0.sizing == .fitContent })
                && children.contains(where: { $0.sizing == .fill })
                && children.contains {
                    $0.node.surfaceNode(for: surfaceID) != nil
                }
            return hasCurrentFitContentSplit
                || children.contains {
                    $0.node.hasVerticalFitContentSplit(containing: surfaceID)
                }
        case let .overlay(base, floating):
            return base.hasVerticalFitContentSplit(containing: surfaceID)
                || floating.contains {
                    $0.hasVerticalFitContentSplit(containing: surfaceID)
                }
        case let .collapsible(main, accessory, _):
            return main.hasVerticalFitContentSplit(containing: surfaceID)
                || accessory.hasVerticalFitContentSplit(containing: surfaceID)
        }
    }
}

extension ExerciseScene {
    var hasVerticalFitContentSplit: Bool {
        root.hasVerticalFitContentSplit
    }

    func hasVerticalFitContentSplit(
        containing surfaceID: ExerciseSurfaceID
    ) -> Bool {
        root.hasVerticalFitContentSplit(containing: surfaceID)
    }
}

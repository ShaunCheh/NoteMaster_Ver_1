//
//  ExercisePresentationState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/1.
//

struct ExerciseSurfaceState: Equatable, Sendable {
    var isVisible: Bool
    var isPromptActive: Bool
    var isAnswerEnabled: Bool
    var isInteractionEnabled: Bool

    static let hidden = ExerciseSurfaceState(
        isVisible: false,
        isPromptActive: false,
        isAnswerEnabled: false,
        isInteractionEnabled: false
    )

    static let promptOnly = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: true,
        isAnswerEnabled: false,
        isInteractionEnabled: false
    )
    static let answerOnly = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: false,
        isAnswerEnabled: true,
        isInteractionEnabled: true
    )
    static let promptAndAnswer = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: true,
        isAnswerEnabled: true,
        isInteractionEnabled: true
    )
    static let auxiliaryOnly = ExerciseSurfaceState(
        isVisible: true,
        isPromptActive: false,
        isAnswerEnabled: false,
        isInteractionEnabled: true
    )

    init(
        isVisible: Bool = true,
        isPromptActive: Bool = false,
        isAnswerEnabled: Bool = false,
        isInteractionEnabled: Bool = false
    ) {
        self.isVisible = isVisible
        self.isPromptActive = isPromptActive
        self.isAnswerEnabled = isAnswerEnabled
        self.isInteractionEnabled = isInteractionEnabled
    }

    init(
        surface: ExerciseSurfaceNode,
        isVisible: Bool = true
    ) {
        self.init(
            isVisible: isVisible,
            isPromptActive: isVisible && surface.isPromptSurface,
            isAnswerEnabled: isVisible && surface.isAnswerSurface,
            isInteractionEnabled: isVisible
                && Self.defaultInteractionEnabled(for: surface)
        )
    }

    private static func defaultInteractionEnabled(
        for surface: ExerciseSurfaceNode
    ) -> Bool {
        if surface.isAnswerSurface {
            return true
        }

        if surface.isAuxiliarySurface {
            return surface.id == .piano
        }

        return false
    }
}

struct ExercisePresentationState: Equatable, Sendable {
    var scene: ExerciseScene
    var resolvedLayoutPreferences: ExerciseLayoutPreferences
    var legacyPageDisplayState: PageDisplayState?
    private(set) var surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState]

    init(
        scene: ExerciseScene,
        surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState] = [:],
        resolvedLayoutPreferences: ExerciseLayoutPreferences = .default,
        legacyPageDisplayState: PageDisplayState? = nil
    ) {
        self.scene = scene
        self.resolvedLayoutPreferences = resolvedLayoutPreferences
        self.legacyPageDisplayState = legacyPageDisplayState
        self.surfaceStates = surfaceStates
    }

    func surfaceState(
        for surfaceID: ExerciseSurfaceID
    ) -> ExerciseSurfaceState? {
        if let state = surfaceStates[surfaceID] {
            return state
        }

        return defaultSurfaceState(
            for: surfaceID,
            in: scene.root,
            inheritedVisibility: true
        )
    }

    mutating func setSurfaceState(
        _ state: ExerciseSurfaceState,
        for surfaceID: ExerciseSurfaceID
    ) {
        surfaceStates[surfaceID] = state
    }

    private func defaultSurfaceState(
        for surfaceID: ExerciseSurfaceID,
        in node: ExerciseSceneNode,
        inheritedVisibility: Bool
    ) -> ExerciseSurfaceState? {
        switch node {
        case let .surface(surface):
            guard surface.id == surfaceID else {
                return nil
            }
            return ExerciseSurfaceState(
                surface: surface,
                isVisible: inheritedVisibility
            )
        case let .split(_, children):
            return children.compactMap {
                defaultSurfaceState(
                    for: surfaceID,
                    in: $0.node,
                    inheritedVisibility: inheritedVisibility
                )
            }.first
        case let .overlay(base, floating):
            if let match = defaultSurfaceState(
                for: surfaceID,
                in: base,
                inheritedVisibility: inheritedVisibility
            ) {
                return match
            }

            return floating.compactMap {
                defaultSurfaceState(
                    for: surfaceID,
                    in: $0,
                    inheritedVisibility: inheritedVisibility
                )
            }.first
        case let .collapsible(main, accessory, isExpanded):
            if let match = defaultSurfaceState(
                for: surfaceID,
                in: main,
                inheritedVisibility: inheritedVisibility
            ) {
                return match
            }

            return defaultSurfaceState(
                for: surfaceID,
                in: accessory,
                inheritedVisibility: inheritedVisibility && isExpanded
            )
        }
    }
}

enum ExerciseRenderedSceneArrangement: Equatable, Sendable {
    case singleSurface
    case stacked
    case sideBySide
}

struct ExerciseRenderedSceneLayout: Equatable, Sendable {
    var arrangement: ExerciseRenderedSceneArrangement
    var primarySurface: ExerciseSurfaceNode
    var primaryWeight: Double
    var secondarySurface: ExerciseSurfaceNode?
    var secondaryWeight: Double?
}

extension ExercisePresentationState {
    func isSurfaceVisible(_ surfaceID: ExerciseSurfaceID) -> Bool {
        surfaceState(for: surfaceID)?.isVisible ?? false
    }

    var renderedSceneLayout: ExerciseRenderedSceneLayout? {
        renderedSceneLayout(for: scene.root)
    }

    private func renderedSceneLayout(
        for node: ExerciseSceneNode
    ) -> ExerciseRenderedSceneLayout? {
        switch node {
        case let .surface(surface):
            return ExerciseRenderedSceneLayout(
                arrangement: .singleSurface,
                primarySurface: surface,
                primaryWeight: 1,
                secondarySurface: nil,
                secondaryWeight: nil
            )
        case let .split(axis, children):
            guard children.count == 2,
                  case let .surface(primarySurface) = children[0].node,
                  case let .surface(secondarySurface) = children[1].node else {
                return nil
            }

            return ExerciseRenderedSceneLayout(
                arrangement: axis == .vertical ? .stacked : .sideBySide,
                primarySurface: primarySurface,
                primaryWeight: children[0].weight,
                secondarySurface: secondarySurface,
                secondaryWeight: children[1].weight
            )
        case let .overlay(base, _):
            return renderedSceneLayout(for: base)
        case let .collapsible(main, _, _):
            return renderedSceneLayout(for: main)
        }
    }
}

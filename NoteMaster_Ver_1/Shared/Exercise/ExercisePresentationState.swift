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
                || surface.id == .questionModeSelector
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
        self.surfaceStates = Self.normalizedSurfaceStates(
            surfaceStates,
            in: scene
        )
    }

    func containsSurface(_ surfaceID: ExerciseSurfaceID) -> Bool {
        scene.containsSurface(surfaceID)
    }

    func projectedSurfaceState(
        for surfaceID: ExerciseSurfaceID
    ) -> ExerciseSurfaceState? {
        guard containsSurface(surfaceID) else {
            return nil
        }

        if let state = surfaceStates[surfaceID] {
            return state
        }

        return defaultProjectedSurfaceState(
            for: surfaceID,
            in: scene.root,
            inheritedVisibility: true
        )
    }

    func effectiveSurfaceState(
        for surfaceID: ExerciseSurfaceID
    ) -> ExerciseSurfaceState {
        projectedSurfaceState(for: surfaceID) ?? .hidden
    }

    mutating func setSurfaceState(
        _ state: ExerciseSurfaceState,
        for surfaceID: ExerciseSurfaceID
    ) {
        guard containsSurface(surfaceID) else {
            surfaceStates.removeValue(forKey: surfaceID)
            return
        }

        surfaceStates[surfaceID] = state
    }

    private static func normalizedSurfaceStates(
        _ surfaceStates: [ExerciseSurfaceID: ExerciseSurfaceState],
        in scene: ExerciseScene
    ) -> [ExerciseSurfaceID: ExerciseSurfaceState] {
        surfaceStates.reduce(into: [:]) { partialResult, entry in
            guard scene.containsSurface(entry.key) else {
                return
            }

            partialResult[entry.key] = entry.value
        }
    }

    private func defaultProjectedSurfaceState(
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
                defaultProjectedSurfaceState(
                    for: surfaceID,
                    in: $0.node,
                    inheritedVisibility: inheritedVisibility
                )
            }.first
        case let .overlay(base, floating):
            if let match = defaultProjectedSurfaceState(
                for: surfaceID,
                in: base,
                inheritedVisibility: inheritedVisibility
            ) {
                return match
            }

            return floating.compactMap {
                defaultProjectedSurfaceState(
                    for: surfaceID,
                    in: $0,
                    inheritedVisibility: inheritedVisibility
                )
            }.first
        case let .collapsible(main, accessory, isExpanded):
            if let match = defaultProjectedSurfaceState(
                for: surfaceID,
                in: main,
                inheritedVisibility: inheritedVisibility
            ) {
                return match
            }

            return defaultProjectedSurfaceState(
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

struct ExerciseRenderedSceneChild: Equatable, Sendable {
    var surface: ExerciseSurfaceNode
    var mainAxisSizing: ExerciseSceneSplitChildMainAxisSizing
}

struct ExerciseRenderedSceneLayout: Equatable, Sendable {
    var arrangement: ExerciseRenderedSceneArrangement
    var children: [ExerciseRenderedSceneChild]

    var primarySurface: ExerciseSurfaceNode {
        guard let primaryChild = children.first else {
            preconditionFailure(
                "Rendered scene layout must contain a primary child."
            )
        }
        return primaryChild.surface
    }

    var primaryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing {
        guard let primaryChild = children.first else {
            preconditionFailure(
                "Rendered scene layout must contain a primary child."
            )
        }
        return primaryChild.mainAxisSizing
    }

    var secondarySurface: ExerciseSurfaceNode? {
        children.indices.contains(1)
            ? children[1].surface
            : nil
    }

    var secondaryMainAxisSizing: ExerciseSceneSplitChildMainAxisSizing? {
        children.indices.contains(1)
            ? children[1].mainAxisSizing
            : nil
    }
}

enum ExerciseFretboardHeightPolicy: Equatable, Sendable {
    case followViewportRatio
    case fillAvailableHeight
}

struct ExerciseFretboardLayoutContract: Equatable, Sendable {
    var pinsSceneToViewportHeight: Bool
    var heightPolicy: ExerciseFretboardHeightPolicy
    var verticalFretboardWidthScale: Double
    var verticalFretboardOverflowScrollAxis: ExerciseFretboardOverflowScrollAxis

    init(
        pinsSceneToViewportHeight: Bool,
        heightPolicy: ExerciseFretboardHeightPolicy,
        verticalFretboardWidthScale: Double = 1,
        verticalFretboardOverflowScrollAxis:
            ExerciseFretboardOverflowScrollAxis = .horizontal
    ) {
        self.pinsSceneToViewportHeight = pinsSceneToViewportHeight
        self.heightPolicy = heightPolicy
        self.verticalFretboardWidthScale = verticalFretboardWidthScale
        self.verticalFretboardOverflowScrollAxis =
            verticalFretboardOverflowScrollAxis
    }

    var usesVerticalViewportHeightControl: Bool {
        heightPolicy == .followViewportRatio
    }

    var resolvedVerticalFretboardWidthScale: Double {
        max(verticalFretboardWidthScale, 1)
    }

    var usesWidthDrivenVerticalOverflow: Bool {
        verticalFretboardOverflowScrollAxis == .vertical
            && resolvedVerticalFretboardWidthScale > 1
    }
}

enum ExerciseNaturalNoteStripRailSlotModel: Equatable, Sendable {
    case chromatic12Preserved

    var slotCount: Int {
        PitchClass.allCases.count
    }
}

enum ExerciseNaturalNoteStripRailButtonShape: Equatable, Sendable {
    case square
}

enum ExerciseNaturalNoteStripRailMainAxisPolicy: Equatable, Sendable {
    case contentSized
}

enum ExerciseNaturalNoteStripRailCrossAxisPolicy: Equatable, Sendable {
    case fitContent
}

enum ExerciseNaturalNoteStripRailVerticalAlignment: Equatable, Sendable {
    case centered
}

enum ExerciseNaturalNoteStripRailPitchTopologyColumn: Equatable, Sendable {
    case accidentalLeft
    case naturalRight
}

enum ExerciseNaturalNoteStripRailPitchTopologyAnchor: Equatable, Sendable {
    case naturalRow(index: Int)
    case midpointBetweenNaturalRows(top: Int, bottom: Int)
}

struct ExerciseNaturalNoteStripRailPitchTopology: Equatable, Sendable {
    var pitchClass: PitchClass
    var column: ExerciseNaturalNoteStripRailPitchTopologyColumn
    var anchor: ExerciseNaturalNoteStripRailPitchTopologyAnchor
}

struct ExerciseNaturalNoteStripRailContract: Equatable, Sendable {
    static let defaultButtonExtent: Double = 50
    static let defaultCrossAxisWidthScale: Double = 2
    static let defaultSideBySideAnswerRail = ExerciseNaturalNoteStripRailContract(
        appliesToSurface: .naturalNoteStrip,
        slotModel: .chromatic12Preserved,
        buttonShape: .square,
        buttonExtent: defaultButtonExtent,
        mainAxisPolicy: .contentSized,
        crossAxisPolicy: .fitContent,
        crossAxisWidthScale: defaultCrossAxisWidthScale,
        verticalAlignment: .centered
    )

    var appliesToSurface: ExerciseSurfaceID
    var slotModel: ExerciseNaturalNoteStripRailSlotModel
    var buttonShape: ExerciseNaturalNoteStripRailButtonShape
    var buttonExtent: Double
    var mainAxisPolicy: ExerciseNaturalNoteStripRailMainAxisPolicy
    var crossAxisPolicy: ExerciseNaturalNoteStripRailCrossAxisPolicy
    var crossAxisWidthScale: Double
    var verticalAlignment: ExerciseNaturalNoteStripRailVerticalAlignment

    var resolvedCrossAxisWidthScale: Double {
        max(crossAxisWidthScale, 1)
    }
}

extension PitchClass {
    static var naturalNoteStripStaggeredRailTopologiesInChromaticOrder:
        [ExerciseNaturalNoteStripRailPitchTopology] {
        allCases.map(\.naturalNoteStripStaggeredRailPitchTopology)
    }

    var naturalNoteStripStaggeredRailPitchTopology:
        ExerciseNaturalNoteStripRailPitchTopology {
        switch self {
        case .c:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 0)
            )
        case .cSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 0, bottom: 1)
            )
        case .d:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 1)
            )
        case .dSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 1, bottom: 2)
            )
        case .e:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 2)
            )
        case .f:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 3)
            )
        case .fSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 3, bottom: 4)
            )
        case .g:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 4)
            )
        case .gSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 4, bottom: 5)
            )
        case .a:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 5)
            )
        case .aSharp:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .accidentalLeft,
                anchor: .midpointBetweenNaturalRows(top: 5, bottom: 6)
            )
        case .b:
            return ExerciseNaturalNoteStripRailPitchTopology(
                pitchClass: self,
                column: .naturalRight,
                anchor: .naturalRow(index: 6)
            )
        }
    }
}

extension ExercisePresentationState {
    func isSurfaceVisible(_ surfaceID: ExerciseSurfaceID) -> Bool {
        effectiveSurfaceState(for: surfaceID).isVisible
    }

    var renderedSceneLayout: ExerciseRenderedSceneLayout? {
        scene.renderedSceneLayout
    }

    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        scene.fretboardLayoutContract(
            layoutPreferences: resolvedLayoutPreferences
        )
    }

    var naturalNoteStripRailContract: ExerciseNaturalNoteStripRailContract? {
        scene.naturalNoteStripRailContract
    }
}

extension ExerciseScene {
    var renderedSceneLayout: ExerciseRenderedSceneLayout? {
        root.renderedSceneLayout
    }

    var fretboardLayoutContract: ExerciseFretboardLayoutContract {
        fretboardLayoutContract(layoutPreferences: .default)
    }

    func fretboardLayoutContract(
        layoutPreferences: ExerciseLayoutPreferences
    ) -> ExerciseFretboardLayoutContract {
        ExerciseFretboardLayoutContract(
            pinsSceneToViewportHeight: requiresViewportPinnedHeight,
            heightPolicy: containsMainFretboardInSideBySideLayout
                ? .fillAvailableHeight
                : .followViewportRatio,
            verticalFretboardWidthScale: layoutPreferences
                .verticalFretboardWidthScale,
            verticalFretboardOverflowScrollAxis: layoutPreferences
                .verticalFretboardOverflowScrollAxis
        )
    }

    var naturalNoteStripRailContract: ExerciseNaturalNoteStripRailContract? {
        guard
            containsNaturalNoteStripAnswerRailInSideBySideLayout,
            let renderedSceneLayout,
            renderedSceneLayout.arrangement == .sideBySide,
            renderedSceneLayout.children.count == 2,
            renderedSceneLayout.primarySurface.id == .fretboard,
            renderedSceneLayout.secondarySurface?.isNaturalNoteStripAnswerRail == true,
            renderedSceneLayout.secondaryMainAxisSizing == .fitContent
        else {
            return nil
        }

        return .defaultSideBySideAnswerRail
    }
}

private extension ExerciseSceneNode {
    var renderedSceneLayout: ExerciseRenderedSceneLayout? {
        switch self {
        case let .surface(surface):
            return ExerciseRenderedSceneLayout(
                arrangement: .singleSurface,
                children: [
                    ExerciseRenderedSceneChild(
                        surface: surface,
                        mainAxisSizing: .weighted(1)
                    )
                ]
            )
        case let .split(axis, children):
            let renderedChildren: [ExerciseRenderedSceneChild] =
                children.compactMap { child in
                    guard case let .surface(surface) = child.node else {
                        return nil
                    }

                    return ExerciseRenderedSceneChild(
                        surface: surface,
                        mainAxisSizing: child.mainAxisSizing
                    )
                }
            guard renderedChildren.count == children.count else {
                return nil
            }

            return ExerciseRenderedSceneLayout(
                arrangement: axis == .vertical ? .stacked : .sideBySide,
                children: renderedChildren
            )
        case let .overlay(base, _):
            return base.renderedSceneLayout
        case let .collapsible(main, _, _):
            return main.renderedSceneLayout
        }
    }
}

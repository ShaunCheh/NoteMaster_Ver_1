//
//  SceneCore.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

enum AppSurfaceID: String, CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case targetPrompt
    case naturalNoteStrip
    case piano
    case questionModeSelector
}

enum AppSurfaceKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case fretboard
    case staff
    case targetPrompt
    case naturalNoteStrip
    case piano
    case questionModeSelector
}

enum AppSurfacePresentationStyle: String, CaseIterable, Equatable, Hashable,
    Sendable {
    case standard
    // Reserved for bottom strip scenes. Scheme 1 freezes this style as a
    // horizontal two-row strip: accidentals on top, naturals on bottom.
    case horizontalStrip
    // Reserved for side rail scenes and keeps the existing staggered
    // two-column semantics: accidentals on the left, naturals on the right.
    case verticalRail
}

protocol SceneSurfaceProtocol {
    var id: AppSurfaceID { get }
    var presentationStyle: AppSurfacePresentationStyle { get }
}

enum SceneAxis: String, Equatable, Hashable, Sendable {
    case vertical
    case horizontal
}

enum SceneSplitChildMainAxisSizing: Equatable, Hashable, Sendable {
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

nonisolated struct AppSurfaceNode: SceneSurfaceProtocol, Equatable, Sendable {
    var id: AppSurfaceID
    var kind: AppSurfaceKind
    var presentationStyle: AppSurfacePresentationStyle

    init(
        id: AppSurfaceID,
        kind: AppSurfaceKind,
        presentationStyle: AppSurfacePresentationStyle = .standard
    ) {
        self.id = id
        self.kind = kind
        self.presentationStyle = presentationStyle
    }

    func withPresentationStyle(
        _ presentationStyle: AppSurfacePresentationStyle
    ) -> AppSurfaceNode {
        var copy = self
        copy.presentationStyle = presentationStyle
        return copy
    }
}

struct SceneSplitChild<Surface: SceneSurfaceProtocol & Equatable & Sendable>:
    Equatable, Sendable {
    var node: SceneNode<Surface>
    var mainAxisSizing: SceneSplitChildMainAxisSizing

    init(
        node: SceneNode<Surface>,
        mainAxisSizing: SceneSplitChildMainAxisSizing = .weighted(1)
    ) {
        switch mainAxisSizing {
        case let .weighted(weight):
            precondition(
                weight > 0,
                "Scene split child weight must be greater than zero."
            )
        case let .fixed(size):
            precondition(
                size > 0,
                "Scene split child fixed size must be greater than zero."
            )
        case .fitContent:
            break
        }

        self.node = node
        self.mainAxisSizing = mainAxisSizing
    }
}

indirect enum SceneNode<Surface: SceneSurfaceProtocol & Equatable & Sendable>:
    Equatable, Sendable {
    case surface(Surface)
    case split(axis: SceneAxis, children: [SceneSplitChild<Surface>])
    case overlay(base: SceneNode<Surface>, floating: [SceneNode<Surface>])
    case collapsible(
        main: SceneNode<Surface>,
        accessory: SceneNode<Surface>,
        isExpanded: Bool
    )

    static func makeSplit(
        axis: SceneAxis,
        children: [SceneSplitChild<Surface>]
    ) -> SceneNode<Surface> {
        precondition(
            children.count >= 2,
            "Scene split must contain at least two children."
        )
        return .split(axis: axis, children: children)
    }

    static func makeOverlay(
        base: SceneNode<Surface>,
        floating: [SceneNode<Surface>]
    ) -> SceneNode<Surface> {
        precondition(
            !floating.isEmpty,
            "Scene overlay must contain at least one floating node."
        )
        return .overlay(base: base, floating: floating)
    }

    static func makeCollapsible(
        main: SceneNode<Surface>,
        accessory: SceneNode<Surface>,
        isExpanded: Bool
    ) -> SceneNode<Surface> {
        .collapsible(
            main: main,
            accessory: accessory,
            isExpanded: isExpanded
        )
    }

    var surfaceNodes: [Surface] {
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

    func surfaceNode(for surfaceID: AppSurfaceID) -> Surface? {
        switch self {
        case let .surface(surface):
            return surface.id == surfaceID ? surface : nil
        case let .split(_, children):
            return children.compactMap { $0.node.surfaceNode(for: surfaceID) }.first
        case let .overlay(base, floating):
            if let match = base.surfaceNode(for: surfaceID) {
                return match
            }
            return floating.compactMap { $0.surfaceNode(for: surfaceID) }.first
        case let .collapsible(main, accessory, _):
            if let match = main.surfaceNode(for: surfaceID) {
                return match
            }
            return accessory.surfaceNode(for: surfaceID)
        }
    }

    func containsSurface(_ surfaceID: AppSurfaceID) -> Bool {
        surfaceNode(for: surfaceID) != nil
    }
}

struct Scene<Surface: SceneSurfaceProtocol & Equatable & Sendable>: Equatable,
    Sendable {
    var root: SceneNode<Surface>

    init(root: SceneNode<Surface>) {
        self.root = root
    }

    static func singleSurface(_ surface: Surface) -> Scene<Surface> {
        Scene(root: .surface(surface))
    }

    var surfaceNodes: [Surface] {
        root.surfaceNodes
    }

    func surfaceNode(for surfaceID: AppSurfaceID) -> Surface? {
        root.surfaceNode(for: surfaceID)
    }

    func containsSurface(_ surfaceID: AppSurfaceID) -> Bool {
        root.containsSurface(surfaceID)
    }
}

extension AppSurfaceNode {
    static let piano = AppSurfaceNode(
        id: .piano,
        kind: .piano
    )
}

//
//  ScenePresentationState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

struct SceneSurfaceState: Equatable, Sendable {
    var isVisible: Bool
    var isInteractionEnabled: Bool

    static let hidden = SceneSurfaceState(
        isVisible: false,
        isInteractionEnabled: false
    )

    static let passive = SceneSurfaceState(
        isVisible: true,
        isInteractionEnabled: false
    )

    static let interactive = SceneSurfaceState(
        isVisible: true,
        isInteractionEnabled: true
    )

    init(
        isVisible: Bool = true,
        isInteractionEnabled: Bool = false
    ) {
        self.isVisible = isVisible
        self.isInteractionEnabled = isInteractionEnabled
    }
}

struct ScenePresentationState<Surface: SceneSurfaceProtocol & Equatable & Sendable>:
    Equatable, Sendable {
    var scene: Scene<Surface>
    private(set) var surfaceStates: [AppSurfaceID: SceneSurfaceState]

    init(
        scene: Scene<Surface>,
        surfaceStates: [AppSurfaceID: SceneSurfaceState] = [:]
    ) {
        self.scene = scene
        self.surfaceStates = Self.normalizedSurfaceStates(
            surfaceStates,
            in: scene
        )
    }

    func containsSurface(_ surfaceID: AppSurfaceID) -> Bool {
        scene.containsSurface(surfaceID)
    }

    func projectedSurfaceState(
        for surfaceID: AppSurfaceID
    ) -> SceneSurfaceState? {
        guard containsSurface(surfaceID) else {
            return nil
        }

        return surfaceStates[surfaceID] ?? .passive
    }

    func effectiveSurfaceState(
        for surfaceID: AppSurfaceID
    ) -> SceneSurfaceState {
        projectedSurfaceState(for: surfaceID) ?? .hidden
    }

    mutating func setSurfaceState(
        _ state: SceneSurfaceState,
        for surfaceID: AppSurfaceID
    ) {
        guard containsSurface(surfaceID) else {
            surfaceStates.removeValue(forKey: surfaceID)
            return
        }

        surfaceStates[surfaceID] = state
    }

    private static func normalizedSurfaceStates(
        _ surfaceStates: [AppSurfaceID: SceneSurfaceState],
        in scene: Scene<Surface>
    ) -> [AppSurfaceID: SceneSurfaceState] {
        surfaceStates.reduce(into: [:]) { partialResult, entry in
            guard scene.containsSurface(entry.key) else {
                return
            }

            partialResult[entry.key] = entry.value
        }
    }
}

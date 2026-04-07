//
//  PlayCompositionPolicy.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

typealias PlayScene = AppScene
typealias PlaySceneNode = AppSceneNode
typealias PlayPresentationState = AppPresentationState

struct PlayCompositionPolicyInput: Equatable, Sendable {
    var isPianoInteractive: Bool = true
}

enum PlayCompositionPolicy {
    static func makePresentation(
        from input: PlayCompositionPolicyInput = PlayCompositionPolicyInput()
    ) -> PlayPresentationState {
        PlayPresentationState(
            scene: makeScene(),
            surfaceStates: [
                .piano: input.isPianoInteractive ? .interactive : .passive
            ]
        )
    }

    static func makeScene() -> PlayScene {
        PlayScene.singleSurface(.piano)
    }
}

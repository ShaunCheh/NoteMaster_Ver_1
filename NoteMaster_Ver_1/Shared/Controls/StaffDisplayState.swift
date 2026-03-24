//
//  StaffDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration

    static let `default` = StaffDisplayState(
        configuration: StaffConfiguration()
    )

    init(configuration: StaffConfiguration) {
        self.configuration = configuration
    }

    // 控制器只维护共享状态，scene provider 统一从状态派生。
    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            renderHint: .staffClef(
                boundsOverlayStyle: configuration.debugOptions.showsClefBounds
                ? .clefDebug(lineWidth: configuration.debugOptions.clefBoundsLineWidth)
                : nil,
                anchorOverlayStyle: configuration.debugOptions.showsClefAnchor
                ? .clefDebug(
                    lineWidth: configuration.debugOptions.clefAnchorLineWidth,
                    crossHalfLength: configuration.debugOptions.clefAnchorCrossHalfLength
                )
                : nil
            )
        )
    }
}

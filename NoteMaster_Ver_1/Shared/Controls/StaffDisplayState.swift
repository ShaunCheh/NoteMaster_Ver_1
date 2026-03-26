//
//  StaffDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

struct StaffDisplayState: Equatable, Sendable {
    var configuration: StaffConfiguration
    var score: StaffScore?
    // 组件边界描线属于平台展示状态，不进入五线谱 scene/config 语义。
    var showsComponentBoundsOverlay: Bool

    static let `default` = StaffDisplayState(
        configuration: StaffConfiguration()
    )

    init(
        configuration: StaffConfiguration,
        score: StaffScore? = nil,
        showsComponentBoundsOverlay: Bool = false
    ) {
        self.configuration = configuration
        self.score = score
        self.showsComponentBoundsOverlay = showsComponentBoundsOverlay
    }

    // 控制器只维护共享状态，scene provider 统一从状态派生。
    var sceneProvider: StaffSceneProvider {
        StaffSceneProvider(
            clef: configuration.clef,
            score: resolvedScore,
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

    // 显示状态中的 clef 仍然是当前五线谱的视觉真相来源；
    // score 作为内容输入保留原始 note 序列，但在投影到 scene 时会对齐当前配置的 clef。
    private var resolvedScore: StaffScore? {
        guard var score else {
            return nil
        }

        score.clef = configuration.clef
        return score
    }
}

extension StaffDisplayState {
    mutating func apply(_ event: StaffControlEvent) {
        event.apply(to: &self)
    }
}

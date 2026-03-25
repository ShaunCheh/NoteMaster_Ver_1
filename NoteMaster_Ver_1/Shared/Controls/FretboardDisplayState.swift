//
//  FretboardDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

import CoreGraphics

struct FretboardDisplayState: Equatable, Sendable {
    static let verticalHostHeightRatioRange: ClosedRange<CGFloat> = 0.35...0.9
    static let defaultVerticalHostHeightRatio: CGFloat = 0.72

    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool
    private(set) var verticalHostHeightRatio: CGFloat

    static let `default` = FretboardDisplayState(
        configuration: FretboardConfiguration(
            displayMode: .horizontal,
            tuning: .standard(for: .guitar6),
            maxFret: 12
        ),
        verticalHostHeightRatio: defaultVerticalHostHeightRatio
    )

    init(
        configuration: FretboardConfiguration,
        visibility: NoteLabelVisibility = .all,
        spelling: PitchSpelling = .sharp,
        showsOctave: Bool = true,
        verticalHostHeightRatio: CGFloat = defaultVerticalHostHeightRatio
    ) {
        self.configuration = configuration
        self.visibility = visibility
        self.spelling = spelling
        self.showsOctave = showsOctave
        self.verticalHostHeightRatio = Self.clampedVerticalHostHeightRatio(
            verticalHostHeightRatio
        )
    }

    // displayMode 仍以 configuration 为真相来源；这里提供共享状态级别的语义代理。
    var displayMode: FretboardDisplayMode {
        get { configuration.displayMode }
        set { configuration.displayMode = newValue }
    }

    // 模式切换入口收口到共享状态，避免平台层自行解释 horizontal / vertical 业务语义。
    mutating func setDisplayMode(_ displayMode: FretboardDisplayMode) {
        self.displayMode = displayMode
    }

    // vertical 模式下的 host 高度比例属于页面布局状态，不进入指板内部几何配置。
    mutating func setVerticalHostHeightRatio(_ ratio: CGFloat) {
        verticalHostHeightRatio = Self.clampedVerticalHostHeightRatio(ratio)
    }

    // 控制器只维护共享状态，provider 统一从状态派生。
    var contentProvider: NoteNameContentProvider {
        NoteNameContentProvider(
            visibility: visibility,
            spelling: spelling,
            showsOctave: showsOctave
        )
    }

    private static func clampedVerticalHostHeightRatio(
        _ ratio: CGFloat
    ) -> CGFloat {
        min(
            max(ratio, verticalHostHeightRatioRange.lowerBound),
            verticalHostHeightRatioRange.upperBound
        )
    }
}

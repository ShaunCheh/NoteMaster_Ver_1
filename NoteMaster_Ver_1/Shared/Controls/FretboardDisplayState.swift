//
//  FretboardDisplayState.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

import CoreGraphics

struct FretboardDisplayState: Equatable, Sendable {
    var configuration: FretboardConfiguration
    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool

    static let `default` = FretboardDisplayState(
        configuration: FretboardConfiguration(
            displayMode: .horizontal,
            tuning: .standard(for: .guitar6),
            maxFret: 12
        )
    )

    init(
        configuration: FretboardConfiguration,
        visibility: NoteLabelVisibility = .all,
        spelling: PitchSpelling = .sharp,
        showsOctave: Bool = true
    ) {
        self.configuration = configuration
        self.visibility = visibility
        self.spelling = spelling
        self.showsOctave = showsOctave
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

    // 控制器只维护共享状态，provider 统一从状态派生。
    var contentProvider: NoteNameContentProvider {
        NoteNameContentProvider(
            visibility: visibility,
            spelling: spelling,
            showsOctave: showsOctave
        )
    }
}

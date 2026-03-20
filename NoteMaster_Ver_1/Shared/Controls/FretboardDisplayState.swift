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

    // 控制器只维护共享状态，provider 统一从状态派生。
    var contentProvider: NoteNameContentProvider {
        NoteNameContentProvider(
            visibility: visibility,
            spelling: spelling,
            showsOctave: showsOctave
        )
    }
}

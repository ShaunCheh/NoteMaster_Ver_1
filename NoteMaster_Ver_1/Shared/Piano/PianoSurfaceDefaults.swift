//
//  PianoSurfaceDefaults.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

import CoreGraphics

enum PianoSurfaceDefaults {
    static let configuration = PianoConfiguration(
        whiteKeyWidth: 30,
        rowHeight: 216,
        rowSpacing: 10,
        scaleAreaHeight: 28,
        buttonAreaWidth: 30,
        blackKeyWidthRatio: 0.62,
        blackKeyHeightRatio: 0.6,
        whiteKeyStyle: .borderlessSeparatedByGaps,
        snapEnabled: true
    )

    static let rows: [PianoRowState] = [
        PianoRowState(
            startNote: NotePitch(pitchClass: .c, octave: 5),
            movementScope: .cascade
        ),
        PianoRowState(
            startNote: NotePitch(pitchClass: .c, octave: 4),
            movementScope: .cascade
        ),
        PianoRowState(
            startNote: NotePitch(pitchClass: .fSharp, octave: 3),
            movementScope: .rowOnly
        )
    ]

    static let panelState = PianoPanelState.inferred(
        configuration: configuration,
        rows: rows
    )

    static let sharedSettings = PianoPanelSettingsSlice(
        panelState: panelState
    )
}

enum PianoSurfaceChromeStyle: Equatable, Sendable {
    case plain
    case card
}

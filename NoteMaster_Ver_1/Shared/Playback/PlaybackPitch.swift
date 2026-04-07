//
//  PlaybackPitch.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/4/7.
//

import Foundation

extension NotePitch {
    var midiNoteNumber: Int {
        absoluteSemitone + 12
    }

    var playbackFrequencyHz: Double {
        440 * pow(
            2,
            Double(midiNoteNumber - 69) / 12
        )
    }
}

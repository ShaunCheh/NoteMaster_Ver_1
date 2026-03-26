//
//  StaffScoreFixtures.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

import Foundation

enum StaffScoreFixtures {
    static func defaultDemo(clef: StaffClef = .treble) -> StaffScore {
        resolveScore(
            named: "default-demo",
            clef: clef,
            notesJSON: """
            [
              { "pitch": "e4",  "duration": "quarter" },
              { "pitch": "f#4", "duration": "quarter" },
              { "pitch": "g4",  "duration": "quarter" },
              { "pitch": "bb4", "duration": "half" },
              { "pitch": "c5",  "duration": "quarter" },
              { "pitch": "d5",  "duration": "quarter" },
              { "pitch": "e5",  "duration": "half" },
              { "pitch": "f5",  "duration": "whole" }
            ]
            """
        )
    }

    private static func resolveScore(
        named fixtureName: String,
        clef: StaffClef,
        notesJSON: String
    ) -> StaffScore {
        let json = """
        {
          "clef": "\(clef.token)",
          "notes": \(notesJSON)
        }
        """

        do {
            return try StaffScore.decode(from: json)
        } catch {
            assertionFailure(
                "Failed to decode staff score fixture '\(fixtureName)': \(error)"
            )
            return StaffScore(
                clef: clef,
                notes: []
            )
        }
    }
}

private extension StaffClef {
    var token: String {
        switch self {
        case .treble:
            return "treble"
        case .bass:
            return "bass"
        }
    }
}

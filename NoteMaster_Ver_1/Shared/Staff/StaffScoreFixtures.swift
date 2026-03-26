//
//  StaffScoreFixtures.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

import Foundation

enum StaffScoreFixtures {
    private typealias MeasureDefinition = [(pitch: String, duration: StaffNoteDuration)]

    static func defaultDemo(clef: StaffClef = .treble) -> StaffScore {
        resolveScore(
            named: "default-demo",
            clef: clef,
            keySignature: .natural,
            measures: [[
                ("e4", .quarter),
                ("f#4", .quarter),
                ("g4", .quarter),
                ("bb4", .half),
                ("c5", .quarter),
                ("d5", .quarter),
                ("e5", .half),
                ("f5", .whole)
            ]]
        )
    }

    static func keySignatureReference(
        clef: StaffClef,
        keySignature: StaffKeySignature
    ) -> StaffScore {
        resolveScore(
            named: "key-signature-reference-\(clef.token)-\(keySignature.fifths)",
            clef: clef,
            keySignature: keySignature,
            measures: [referenceMeasure(for: clef)]
        )
    }

    static func gMajorAccidentalContextReference() -> StaffScore {
        resolveScore(
            named: "g-major-accidental-context",
            clef: .treble,
            keySignature: StaffKeySignature(fifths: 1),
            measures: [
                [
                    ("f#4", .quarter),
                    ("f#4", .quarter),
                    ("f4", .quarter),
                    ("f4", .quarter),
                    ("f#4", .half)
                ],
                [
                    ("f#4", .quarter),
                    ("f4", .half)
                ]
            ]
        )
    }

    static func bbMajorBassAccidentalContextReference() -> StaffScore {
        resolveScore(
            named: "bb-major-bass-accidental-context",
            clef: .bass,
            keySignature: StaffKeySignature(fifths: -2),
            measures: [
                [
                    ("bb3", .quarter),
                    ("bb3", .quarter),
                    ("b3", .quarter),
                    ("b3", .half)
                ],
                [
                    ("bb3", .quarter),
                    ("b3", .half)
                ]
            ]
        )
    }

    private static func resolveScore(
        named fixtureName: String,
        clef: StaffClef,
        keySignature: StaffKeySignature,
        measures: [MeasureDefinition]
    ) -> StaffScore {
        let measuresJSON = measures
            .map(measureJSON(for:))
            .joined(separator: ",\n")
        let json = """
        {
          "clef": "\(clef.token)",
          "keySignature": {
            "fifths": \(keySignature.fifths)
          },
          "measures": [
        \(measuresJSON)
          ]
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

    private static func referenceMeasure(
        for clef: StaffClef
    ) -> MeasureDefinition {
        switch clef {
        case .treble:
            return [
                ("g4", .quarter),
                ("a4", .half)
            ]
        case .bass:
            return [
                ("g2", .quarter),
                ("a2", .half)
            ]
        }
    }

    private static func measureJSON(
        for measure: MeasureDefinition
    ) -> String {
        let notesJSON = measure
            .map(noteJSON(pitch:duration:))
            .joined(separator: ",\n")
        return """
            {
              "notes": [
        \(notesJSON)
              ]
            }
        """
    }

    private static func noteJSON(
        pitch: String,
        duration: StaffNoteDuration
    ) -> String {
        """
                { "pitch": "\(pitch)", "duration": "\(duration.rawValue)" }
        """
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

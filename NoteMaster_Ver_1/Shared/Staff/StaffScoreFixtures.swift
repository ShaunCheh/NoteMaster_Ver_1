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
            measures: [referenceMeasure(for: clef, keySignature: keySignature)]
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

    static func aMajorAccidentalContextReference() -> StaffScore {
        resolveScore(
            named: "a-major-accidental-context",
            clef: .treble,
            keySignature: StaffKeySignature(fifths: 3),
            measures: [
                [
                    ("f#4", .quarter),
                    ("c#5", .quarter),
                    ("g#4", .quarter),
                    ("f4", .quarter),
                    ("f#4", .quarter),
                    ("c5", .quarter),
                    ("c5", .quarter),
                    ("g4", .quarter),
                    ("g4", .quarter)
                ],
                [
                    ("f4", .quarter),
                    ("c5", .quarter),
                    ("g4", .half)
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
                keySignature: keySignature,
                measures: []
            )
        }
    }

    private static func referenceMeasure(
        for clef: StaffClef,
        keySignature: StaffKeySignature
    ) -> MeasureDefinition {
        guard
            let signatureAccidental = keySignature.signatureAccidental,
            !keySignature.alteredLetters.isEmpty
        else {
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

        let alteredLetters = keySignature.alteredLetters
        let primaryPitch = referencePitchToken(
            letter: alteredLetters[0],
            accidental: signatureAccidental,
            clef: clef
        )
        let secondaryPitch: String
        if alteredLetters.count > 1 {
            secondaryPitch = referencePitchToken(
                letter: alteredLetters[1],
                accidental: signatureAccidental,
                clef: clef
            )
        } else if let naturalLetter = referenceNaturalLetter(
            excluding: alteredLetters
        ) {
            secondaryPitch = referencePitchToken(
                letter: naturalLetter,
                accidental: .natural,
                clef: clef
            )
        } else {
            secondaryPitch = primaryPitch
        }

        return [
            (primaryPitch, .quarter),
            (secondaryPitch, .half)
        ]
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

    private static func referenceNaturalLetter(
        excluding alteredLetters: [StaffPitchLetter]
    ) -> StaffPitchLetter? {
        let alteredLetterSet = Set(alteredLetters)
        let candidateLetters: [StaffPitchLetter] = [.g, .a, .d, .e, .c, .f, .b]
        return candidateLetters.first { !alteredLetterSet.contains($0) }
    }

    private static func referencePitchToken(
        letter: StaffPitchLetter,
        accidental: StaffAccidental,
        clef: StaffClef
    ) -> String {
        let octave = referenceOctave(
            for: letter,
            clef: clef
        )
        return "\(letter.scientificToken.lowercased())\(accidental.scientificToken)\(octave)"
    }

    private static func referenceOctave(
        for letter: StaffPitchLetter,
        clef: StaffClef
    ) -> Int {
        switch (clef, letter) {
        case (.treble, .c), (.treble, .d), (.treble, .e), (.treble, .f):
            return 5
        case (.treble, .g), (.treble, .a), (.treble, .b):
            return 4
        case (.bass, .c), (.bass, .d), (.bass, .e), (.bass, .f):
            return 3
        case (.bass, .g), (.bass, .a), (.bass, .b):
            return 2
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

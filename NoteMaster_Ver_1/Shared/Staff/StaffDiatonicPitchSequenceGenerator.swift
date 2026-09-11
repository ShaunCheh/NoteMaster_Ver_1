//
//  StaffDiatonicPitchSequenceGenerator.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/9/11.
//

struct StaffDiatonicPitchProgressionSpec: Equatable, Sendable {
    var startPitch: StaffPitch
    var intervalNumber: Int
    var candidateCount: Int

    init(
        startPitch: StaffPitch,
        intervalNumber: Int,
        candidateCount: Int
    ) {
        precondition(
            startPitch.accidental == .natural,
            "Diatonic pitch progression must start from a natural pitch."
        )
        precondition(
            intervalNumber >= 2,
            "Diatonic pitch progression interval must be at least a second."
        )
        precondition(
            candidateCount > 0,
            "Diatonic pitch progression must contain at least one candidate."
        )
        self.startPitch = startPitch
        self.intervalNumber = intervalNumber
        self.candidateCount = candidateCount
    }

    var diatonicStepCount: Int {
        intervalNumber - 1
    }
}

struct StaffDiatonicPitchSequenceGenerator: Equatable, Sendable {
    func makeCandidates(
        for spec: StaffDiatonicPitchProgressionSpec
    ) -> [StaffPitch] {
        (0..<spec.candidateCount).map { offset in
            StaffPitch(
                naturalDiatonicIndex: spec.startPitch.diatonicIndex
                    + (offset * spec.diatonicStepCount)
            )
        }
    }
}

private extension StaffPitch {
    init(naturalDiatonicIndex: Int) {
        let normalizedLetterIndex =
            ((naturalDiatonicIndex % StaffPitchLetter.allCases.count)
                + StaffPitchLetter.allCases.count)
            % StaffPitchLetter.allCases.count
        let octave = (
            naturalDiatonicIndex - normalizedLetterIndex
        ) / StaffPitchLetter.allCases.count

        guard let letter = StaffPitchLetter(rawValue: normalizedLetterIndex) else {
            preconditionFailure(
                "Normalized diatonic pitch letter index must be valid."
            )
        }

        self.init(
            letter: letter,
            accidental: .natural,
            octave: octave
        )
    }
}

//
//  StaffQuarterNoteSequenceGenerator.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

struct StaffQuarterNoteSequenceGenerator: Equatable, Sendable {
    struct Spec: Equatable, Sendable {
        var clef: StaffClef
        var noteCount: Int
        var includesAccidentals: Bool

        init(
            clef: StaffClef,
            noteCount: Int,
            includesAccidentals: Bool
        ) {
            precondition(
                noteCount > 0,
                "Quarter-note sequence note count must be greater than zero."
            )
            self.clef = clef
            self.noteCount = noteCount
            self.includesAccidentals = includesAccidentals
        }
    }

    struct Sequence: Equatable, Sendable {
        var score: StaffScore
        var expectedPitchClasses: [PitchClass]

        init(
            score: StaffScore,
            expectedPitchClasses: [PitchClass]
        ) {
            precondition(
                score.keySignature == .natural,
                "Quarter-note sequence score should use a natural key signature."
            )
            precondition(
                score.notes.allSatisfy { $0.duration == .quarter },
                "Quarter-note sequence score should only contain quarter notes."
            )
            precondition(
                expectedPitchClasses.count == score.notes.count,
                "Quarter-note sequence answers must align with the generated score."
            )
            self.score = score
            self.expectedPitchClasses = expectedPitchClasses
        }
    }

    func makeSequence<R: RandomNumberGenerator>(
        spec: Spec,
        using generator: inout R
    ) -> Sequence {
        let candidates = resolvedCandidates(for: spec)
        guard !candidates.isEmpty else {
            preconditionFailure(
                "Quarter-note sequence pitch candidates should never be empty."
            )
        }

        let selectedPitches = (0..<spec.noteCount).map { _ in
            guard let pitch = candidates.randomElement(using: &generator) else {
                preconditionFailure(
                    "Quarter-note sequence pitch selection should always succeed."
                )
            }
            return pitch
        }
        let notes = selectedPitches.map {
            StaffScoreNote(
                pitch: $0,
                duration: .quarter
            )
        }
        let score = StaffScore(
            clef: spec.clef,
            keySignature: .natural,
            measures: makeMeasures(from: notes)
        )
        let expectedPitchClasses = selectedPitches.map {
            $0.notePitch.pitchClass
        }

        return Sequence(
            score: score,
            expectedPitchClasses: expectedPitchClasses
        )
    }

    private func resolvedCandidates(
        for spec: Spec
    ) -> [StaffPitch] {
        let naturalCandidates = naturalCandidates(for: spec.clef)
        guard spec.includesAccidentals else {
            return naturalCandidates
        }

        // 第一版先固定为升号拼写，不在 Bool 开关里引入降号等音语义。
        return naturalCandidates + sharpCandidates(for: spec.clef)
    }

    private func naturalCandidates(for clef: StaffClef) -> [StaffPitch] {
        switch clef {
        case .treble:
            return [
                StaffPitch(letter: .e, octave: 4),
                StaffPitch(letter: .f, octave: 4),
                StaffPitch(letter: .g, octave: 4),
                StaffPitch(letter: .a, octave: 4),
                StaffPitch(letter: .b, octave: 4),
                StaffPitch(letter: .c, octave: 5),
                StaffPitch(letter: .d, octave: 5),
                StaffPitch(letter: .e, octave: 5),
                StaffPitch(letter: .f, octave: 5)
            ]
        case .bass:
            return [
                StaffPitch(letter: .g, octave: 2),
                StaffPitch(letter: .a, octave: 2),
                StaffPitch(letter: .b, octave: 2),
                StaffPitch(letter: .c, octave: 3),
                StaffPitch(letter: .d, octave: 3),
                StaffPitch(letter: .e, octave: 3),
                StaffPitch(letter: .f, octave: 3),
                StaffPitch(letter: .g, octave: 3),
                StaffPitch(letter: .a, octave: 3)
            ]
        }
    }

    private func sharpCandidates(for clef: StaffClef) -> [StaffPitch] {
        switch clef {
        case .treble:
            return [
                StaffPitch(letter: .f, accidental: .sharp, octave: 4),
                StaffPitch(letter: .g, accidental: .sharp, octave: 4),
                StaffPitch(letter: .a, accidental: .sharp, octave: 4),
                StaffPitch(letter: .c, accidental: .sharp, octave: 5),
                StaffPitch(letter: .d, accidental: .sharp, octave: 5),
                StaffPitch(letter: .f, accidental: .sharp, octave: 5)
            ]
        case .bass:
            return [
                StaffPitch(letter: .g, accidental: .sharp, octave: 2),
                StaffPitch(letter: .a, accidental: .sharp, octave: 2),
                StaffPitch(letter: .c, accidental: .sharp, octave: 3),
                StaffPitch(letter: .d, accidental: .sharp, octave: 3),
                StaffPitch(letter: .f, accidental: .sharp, octave: 3),
                StaffPitch(letter: .g, accidental: .sharp, octave: 3),
                StaffPitch(letter: .a, accidental: .sharp, octave: 3)
            ]
        }
    }

    private func makeMeasures(
        from notes: [StaffScoreNote]
    ) -> [StaffMeasure] {
        stride(from: 0, to: notes.count, by: 4).map { startIndex in
            let endIndex = min(startIndex + 4, notes.count)
            return StaffMeasure(
                notes: Array(notes[startIndex..<endIndex])
            )
        }
    }
}

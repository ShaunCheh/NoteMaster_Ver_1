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

    func makeSequence<R: RandomNumberGenerator>(
        spec: Spec,
        using generator: inout R
    ) -> GeneratedNoteSequence {
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
        let items = selectedPitches.map {
            GeneratedNoteSequenceItem(
                writtenPitch: $0
            )
        }

        return GeneratedNoteSequence(
            clef: spec.clef,
            items: items
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
}

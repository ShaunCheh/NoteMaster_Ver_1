//
//  StaffQuarterNoteSequenceGenerator.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

struct StaffWithoutReplacementSelectionSpec: Equatable, Sendable {
    var outputCount: Int
    var minimumLineCount: Int
    var minimumSpaceCount: Int

    init(
        outputCount: Int,
        minimumLineCount: Int = 0,
        minimumSpaceCount: Int = 0
    ) {
        precondition(
            outputCount > 0,
            "Without-replacement selection must produce at least one pitch."
        )
        precondition(
            minimumLineCount >= 0 && minimumSpaceCount >= 0,
            "Minimum staff-position counts cannot be negative."
        )
        precondition(
            minimumLineCount + minimumSpaceCount <= outputCount,
            "Minimum staff-position counts cannot exceed output count."
        )
        self.outputCount = outputCount
        self.minimumLineCount = minimumLineCount
        self.minimumSpaceCount = minimumSpaceCount
    }
}

enum StaffQuarterNoteGenerationStrategy: Equatable, Sendable {
    case clefRangeRandomWithReplacement
    case diatonicProgression(
        progression: StaffDiatonicPitchProgressionSpec,
        selection: StaffWithoutReplacementSelectionSpec
    )
}

struct StaffQuarterNoteSequenceGenerator: Equatable, Sendable {
    struct Spec: Equatable, Sendable {
        var clef: StaffClef
        var noteCount: Int
        var includesAccidentals: Bool
        var generationStrategy: StaffQuarterNoteGenerationStrategy

        init(
            clef: StaffClef,
            noteCount: Int,
            includesAccidentals: Bool,
            generationStrategy: StaffQuarterNoteGenerationStrategy =
                .clefRangeRandomWithReplacement
        ) {
            precondition(
                noteCount > 0,
                "Quarter-note sequence note count must be greater than zero."
            )
            self.clef = clef
            self.noteCount = noteCount
            self.includesAccidentals = includesAccidentals
            self.generationStrategy = generationStrategy
        }
    }

    func makeSequence<R: RandomNumberGenerator>(
        spec: Spec,
        using generator: inout R
    ) -> GeneratedNoteSequence {
        let selectedPitches: [StaffPitch]
        switch spec.generationStrategy {
        case .clefRangeRandomWithReplacement:
            selectedPitches = selectWithReplacement(
                candidates: resolvedCandidates(for: spec),
                count: spec.noteCount,
                using: &generator
            )
        case let .diatonicProgression(progression, selection):
            precondition(
                selection.outputCount == spec.noteCount,
                "Progression output count must match sequence note count."
            )
            precondition(
                !spec.includesAccidentals,
                "Diatonic progression strategy currently supports natural pitches only."
            )
            let candidates = StaffDiatonicPitchSequenceGenerator()
                .makeCandidates(for: progression)
            precondition(
                Set(candidates).count == candidates.count,
                "Without-replacement progression candidates must be unique."
            )
            selectedPitches = selectWithoutReplacement(
                candidates: candidates,
                clef: spec.clef,
                spec: selection,
                using: &generator
            )
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

    private func selectWithReplacement<R: RandomNumberGenerator>(
        candidates: [StaffPitch],
        count: Int,
        using generator: inout R
    ) -> [StaffPitch] {
        guard !candidates.isEmpty else {
            preconditionFailure(
                "Quarter-note sequence pitch candidates should never be empty."
            )
        }

        return (0..<count).map { _ in
            guard let pitch = candidates.randomElement(using: &generator) else {
                preconditionFailure(
                    "Quarter-note sequence pitch selection should always succeed."
                )
            }
            return pitch
        }
    }

    private func selectWithoutReplacement<R: RandomNumberGenerator>(
        candidates: [StaffPitch],
        clef: StaffClef,
        spec: StaffWithoutReplacementSelectionSpec,
        using generator: inout R
    ) -> [StaffPitch] {
        precondition(
            spec.outputCount <= candidates.count,
            "Without-replacement output count cannot exceed candidate count."
        )

        var remaining = candidates
        var selected: [StaffPitch] = []
        let layout = StaffPitchLayout(clef: clef)

        removeRandomCandidates(
            count: spec.minimumLineCount,
            kind: .line,
            from: &remaining,
            into: &selected,
            layout: layout,
            using: &generator
        )
        removeRandomCandidates(
            count: spec.minimumSpaceCount,
            kind: .space,
            from: &remaining,
            into: &selected,
            layout: layout,
            using: &generator
        )

        while selected.count < spec.outputCount {
            selected.append(
                removeRandomCandidate(
                    from: &remaining,
                    using: &generator
                )
            )
        }

        selected.shuffle(using: &generator)
        return selected
    }

    private func removeRandomCandidates<R: RandomNumberGenerator>(
        count: Int,
        kind: StaffPositionKind,
        from remaining: inout [StaffPitch],
        into selected: inout [StaffPitch],
        layout: StaffPitchLayout,
        using generator: inout R
    ) {
        for _ in 0..<count {
            let matchingIndices = remaining.indices.filter {
                layout.positionKind(for: remaining[$0]) == kind
            }
            precondition(
                !matchingIndices.isEmpty,
                "Candidate pool cannot satisfy staff-position minimum."
            )
            let matchingOffset = Int.random(
                in: 0..<matchingIndices.count,
                using: &generator
            )
            selected.append(
                remaining.remove(at: matchingIndices[matchingOffset])
            )
        }
    }

    private func removeRandomCandidate<R: RandomNumberGenerator>(
        from remaining: inout [StaffPitch],
        using generator: inout R
    ) -> StaffPitch {
        precondition(
            !remaining.isEmpty,
            "Candidate pool must contain enough unique pitches."
        )
        return remaining.remove(
            at: Int.random(in: 0..<remaining.count, using: &generator)
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

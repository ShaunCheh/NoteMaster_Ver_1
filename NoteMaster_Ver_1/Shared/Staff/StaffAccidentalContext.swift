//
//  StaffAccidentalContext.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

struct StaffAccidentalContext: Equatable, Sendable {
    struct PitchScope: Hashable, Sendable {
        var letter: StaffPitchLetter
        var octave: Int

        init(letter: StaffPitchLetter, octave: Int) {
            self.letter = letter
            self.octave = octave
        }

        init(pitch: StaffPitch) {
            self.init(
                letter: pitch.letter,
                octave: pitch.octave
            )
        }
    }

    struct Decision: Equatable, Sendable {
        var effectiveAccidentalBeforeNote: StaffAccidental
        var writtenAccidental: StaffAccidental
        var displayedAccidental: StaffAccidental?

        var shouldDisplayAccidental: Bool {
            displayedAccidental != nil
        }
    }

    var keySignature: StaffKeySignature
    private var measureOverrides: [PitchScope: StaffAccidental]

    init(
        keySignature: StaffKeySignature,
        measureOverrides: [PitchScope: StaffAccidental] = [:]
    ) {
        self.keySignature = keySignature
        self.measureOverrides = measureOverrides
    }

    mutating func resetForMeasure() {
        measureOverrides.removeAll()
    }

    func effectiveAccidental(for pitch: StaffPitch) -> StaffAccidental {
        let scope = PitchScope(pitch: pitch)
        return measureOverrides[scope] ?? keySignature.accidental(for: pitch.letter)
    }

    mutating func resolveDisplayDecision(
        for pitch: StaffPitch
    ) -> Decision {
        let effectiveAccidentalBeforeNote = effectiveAccidental(for: pitch)
        let displayedAccidental: StaffAccidental? = effectiveAccidentalBeforeNote == pitch.accidental
            ? nil
            : pitch.accidental

        measureOverrides[PitchScope(pitch: pitch)] = pitch.accidental

        return Decision(
            effectiveAccidentalBeforeNote: effectiveAccidentalBeforeNote,
            writtenAccidental: pitch.accidental,
            displayedAccidental: displayedAccidental
        )
    }
}

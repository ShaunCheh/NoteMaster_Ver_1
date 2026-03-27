//
//  GeneratedNoteSequence.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/27.
//

struct GeneratedNoteSequenceItem: Equatable, Hashable, Sendable {
    var writtenPitch: StaffPitch
    var answerPitchClass: PitchClass

    init(
        writtenPitch: StaffPitch,
        answerPitchClass: PitchClass? = nil
    ) {
        let resolvedAnswerPitchClass = answerPitchClass
            ?? writtenPitch.notePitch.pitchClass
        precondition(
            resolvedAnswerPitchClass == writtenPitch.notePitch.pitchClass,
            "Generated note sequence item answer pitch class must match its written pitch."
        )
        self.writtenPitch = writtenPitch
        self.answerPitchClass = resolvedAnswerPitchClass
    }

    var note: StaffScoreNote {
        StaffScoreNote(
            pitch: writtenPitch,
            duration: .quarter
        )
    }
}

struct GeneratedNoteSequence: Equatable, Sendable {
    var clef: StaffClef
    var items: [GeneratedNoteSequenceItem]

    init(
        clef: StaffClef,
        items: [GeneratedNoteSequenceItem]
    ) {
        precondition(
            !items.isEmpty,
            "Generated note sequence must contain at least one item."
        )
        self.clef = clef
        self.items = items
    }

    var noteCount: Int {
        items.count
    }

    var writtenPitches: [StaffPitch] {
        items.map(\.writtenPitch)
    }

    var answerPitchClasses: [PitchClass] {
        items.map(\.answerPitchClass)
    }

    // 第一阶段先把 prompt 展示真相收敛为 pitchClass；
    // 后续若需要保留更细的书写语义，再在此基础上扩展 display token。
    var displayPitchClasses: [PitchClass] {
        answerPitchClasses
    }

    var notes: [StaffScoreNote] {
        items.map(\.note)
    }

    var score: StaffScore {
        StaffScore(
            clef: clef,
            keySignature: .natural,
            measures: makeMeasures(from: notes)
        )
    }

    func displayTexts(
        using spelling: PitchSpelling = .sharp
    ) -> [String] {
        displayPitchClasses.map {
            $0.displayText(using: spelling)
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

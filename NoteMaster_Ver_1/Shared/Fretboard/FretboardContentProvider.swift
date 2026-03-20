//
//  FretboardContentProvider.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

import CoreGraphics

// 仅控制音名文本的可见性，不影响指板 marker 的绘制。
struct NoteLabelVisibility: Equatable, Hashable, Sendable {
    var showsNaturalNotes: Bool
    var showsAccidentals: Bool

    static let all = NoteLabelVisibility(
        showsNaturalNotes: true,
        showsAccidentals: true
    )

    static let naturalOnly = NoteLabelVisibility(
        showsNaturalNotes: true,
        showsAccidentals: false
    )

    static let accidentalOnly = NoteLabelVisibility(
        showsNaturalNotes: false,
        showsAccidentals: true
    )

    static let none = NoteLabelVisibility(
        showsNaturalNotes: false,
        showsAccidentals: false
    )

    func allows(_ pitchClass: PitchClass) -> Bool {
        pitchClass.isAccidental ? showsAccidentals : showsNaturalNotes
    }
}

struct FretboardLabelContent: Equatable, Sendable {
    var stringIndex: Int
    var fret: Int
    var text: String
    var center: CGPoint
    var badgeDiameter: CGFloat
    var maxSize: CGSize
    var fontSize: CGFloat
}

protocol FretboardContentProviding: Sendable {
    func makeLabels(
        configuration: FretboardConfiguration,
        geometry: FretboardGeometry
    ) -> [FretboardLabelContent]
}

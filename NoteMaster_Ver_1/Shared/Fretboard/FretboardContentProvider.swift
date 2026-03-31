//
//  FretboardContentProvider.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

import CoreGraphics

// 仅控制音名文本的可见性，不影响指板 marker 的绘制。
// 用精确的 pitch class 集合表达可见范围，避免被“自然音/变化音”两位开关限制住。
struct NoteLabelVisibility: Equatable, Hashable, Sendable {
    private static let allPitchClasses = Set(PitchClass.allCases)
    private static let naturalPitchClasses = Set(PitchClass.naturalCasesInOrder)
    private static let accidentalPitchClasses = Set(
        PitchClass.allCases.filter(\.isAccidental)
    )

    var visiblePitchClasses: Set<PitchClass>

    static let all = NoteLabelVisibility(
        visiblePitchClasses: allPitchClasses
    )

    static let naturalOnly = NoteLabelVisibility(
        visiblePitchClasses: naturalPitchClasses
    )

    static let bcefOnly = NoteLabelVisibility(
        visiblePitchClasses: [
            .b,
            .c,
            .e,
            .f
        ]
    )

    static let accidentalOnly = NoteLabelVisibility(
        visiblePitchClasses: accidentalPitchClasses
    )

    static let none = NoteLabelVisibility(
        visiblePitchClasses: []
    )

    func allows(_ pitchClass: PitchClass) -> Bool {
        visiblePitchClasses.contains(pitchClass)
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
        scene: FretboardScene
    ) -> [FretboardLabelContent]
}

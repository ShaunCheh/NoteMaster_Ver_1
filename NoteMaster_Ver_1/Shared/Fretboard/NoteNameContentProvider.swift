//
//  NoteNameContentProvider.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

import CoreGraphics

struct NoteNameContentProvider: FretboardContentProviding, Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var badgeDiameterRatio: CGFloat
        var maxBadgeWidthRatio: CGFloat
        var textInsetRatio: CGFloat
        var fontScale: CGFloat

        static let `default` = LayoutMetrics(
            badgeDiameterRatio: 0.78,
            maxBadgeWidthRatio: 0.74,
            textInsetRatio: 0.18,
            fontScale: 0.88
        )
    }

    var visibility: NoteLabelVisibility
    var spelling: PitchSpelling
    var showsOctave: Bool
    var layoutMetrics: LayoutMetrics

    init(
        visibility: NoteLabelVisibility = .all,
        spelling: PitchSpelling = .sharp,
        showsOctave: Bool = true,
        layoutMetrics: LayoutMetrics = .default
    ) {
        self.visibility = visibility
        self.spelling = spelling
        self.showsOctave = showsOctave
        self.layoutMetrics = layoutMetrics
    }

    func makeLabels(
        configuration: FretboardConfiguration,
        scene: FretboardScene
    ) -> [FretboardLabelContent] {
        var labels: [FretboardLabelContent] = []

        for stringIndex in 0..<configuration.stringCount {
            for fret in configuration.fretRange {
                guard
                    let pitch = configuration.notePitch(
                        stringIndex: stringIndex,
                        fret: fret
                    ),
                    visibility.allows(pitch.pitchClass)
                else {
                    continue
                }

                guard
                    let anchor = scene.labelAnchor(
                        stringIndex: stringIndex,
                        fret: fret
                    )
                else {
                    continue
                }

                labels.append(
                    makeLabelContent(
                        pitch: pitch,
                        stringIndex: stringIndex,
                        fret: fret,
                        anchor: anchor
                    )
                )
            }
        }

        return labels
    }

    private func makeLabelContent(
        pitch: NotePitch,
        stringIndex: Int,
        fret: Int,
        anchor: FretboardScene.LabelAnchor
    ) -> FretboardLabelContent {
        let badgeDiameter = resolvedBadgeDiameter(cellFrame: anchor.cellFrame)
        let textInset = badgeDiameter * layoutMetrics.textInsetRatio
        let maxTextDiameter = max(badgeDiameter - (textInset * 2), 0)
        let fontSize = min(
            maxTextDiameter * layoutMetrics.fontScale,
            maxTextDiameter
        )

        return FretboardLabelContent(
            stringIndex: stringIndex,
            fret: fret,
            text: pitch.displayText(using: spelling, showsOctave: showsOctave),
            center: anchor.center,
            badgeDiameter: badgeDiameter,
            maxSize: CGSize(width: maxTextDiameter, height: maxTextDiameter),
            fontSize: fontSize
        )
    }

    private func resolvedBadgeDiameter(
        cellFrame: CGRect
    ) -> CGFloat {
        let heightDrivenDiameter = cellFrame.height * layoutMetrics.badgeDiameterRatio
        let widthDrivenDiameter = cellFrame.width * layoutMetrics.maxBadgeWidthRatio

        return max(min(heightDrivenDiameter, widthDrivenDiameter), 0)
    }
}

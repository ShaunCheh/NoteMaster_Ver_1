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
        geometry: FretboardGeometry
    ) -> [FretboardLabelContent] {
        var labels: [FretboardLabelContent] = []

        for stringIndex in 0..<configuration.stringCount {
            guard
                let openPitch = configuration.tuning.openStringPitch(for: stringIndex),
                let stringY = geometry.yPositionForString(stringIndex)
            else {
                continue
            }

            for fret in configuration.fretRange {
                let pitch = openPitch.advanced(by: fret)
                guard visibility.allows(pitch.pitchClass) else {
                    continue
                }

                let slotRect = geometry.displaySlotRect(at: fret)
                guard !slotRect.isNull else {
                    continue
                }

                labels.append(
                    makeLabelContent(
                        pitch: pitch,
                        stringIndex: stringIndex,
                        fret: fret,
                        stringY: stringY,
                        slotRect: slotRect,
                        geometry: geometry
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
        stringY: CGFloat,
        slotRect: CGRect,
        geometry: FretboardGeometry
    ) -> FretboardLabelContent {
        let badgeDiameter = resolvedBadgeDiameter(slotRect: slotRect, geometry: geometry)
        let minCenterY = slotRect.minY + (badgeDiameter / 2)
        let maxCenterY = slotRect.maxY - (badgeDiameter / 2)
        let clampedCenterY = min(max(stringY, minCenterY), maxCenterY)
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
            center: CGPoint(x: slotRect.midX, y: clampedCenterY),
            badgeDiameter: badgeDiameter,
            maxSize: CGSize(width: maxTextDiameter, height: maxTextDiameter),
            fontSize: fontSize
        )
    }

    private func resolvedBadgeDiameter(
        slotRect: CGRect,
        geometry: FretboardGeometry
    ) -> CGFloat {
        let referenceHeight = geometry.stringSpacing > 0
            ? geometry.stringSpacing
            : slotRect.height * 0.24
        let heightDrivenDiameter = referenceHeight * layoutMetrics.badgeDiameterRatio
        let widthDrivenDiameter = slotRect.width * layoutMetrics.maxBadgeWidthRatio

        return max(min(heightDrivenDiameter, widthDrivenDiameter), 0)
    }
}

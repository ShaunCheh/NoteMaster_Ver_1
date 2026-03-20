//
//  NoteNameContentProvider.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/20.
//

import CoreGraphics

struct NoteNameContentProvider: FretboardContentProviding, Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var verticalOffsetRatio: CGFloat
        var maxLabelWidthRatio: CGFloat
        var maxLabelHeightRatio: CGFloat
        var fontScale: CGFloat

        static let `default` = LayoutMetrics(
            verticalOffsetRatio: 0.28,
            maxLabelWidthRatio: 0.88,
            maxLabelHeightRatio: 0.9,
            fontScale: 0.46
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
        let maxLabelHeight = resolvedMaxLabelHeight(slotRect: slotRect, geometry: geometry)
        let proposedCenterY = stringY - (verticalOffsetReference(slotRect: slotRect, geometry: geometry) * layoutMetrics.verticalOffsetRatio)
        let minCenterY = slotRect.minY + (maxLabelHeight / 2)
        let maxCenterY = slotRect.maxY - (maxLabelHeight / 2)
        let clampedCenterY = min(max(proposedCenterY, minCenterY), maxCenterY)
        let maxLabelWidth = max(slotRect.width * layoutMetrics.maxLabelWidthRatio, 0)
        let fontSize = min(
            slotRect.width * layoutMetrics.fontScale,
            maxLabelHeight * 0.9
        )

        return FretboardLabelContent(
            stringIndex: stringIndex,
            fret: fret,
            text: pitch.displayText(using: spelling, showsOctave: showsOctave),
            center: CGPoint(x: slotRect.midX, y: clampedCenterY),
            maxSize: CGSize(width: maxLabelWidth, height: maxLabelHeight),
            fontSize: fontSize
        )
    }

    private func resolvedMaxLabelHeight(
        slotRect: CGRect,
        geometry: FretboardGeometry
    ) -> CGFloat {
        let referenceHeight = geometry.stringSpacing > 0
            ? geometry.stringSpacing
            : slotRect.height * 0.28

        return max(referenceHeight * layoutMetrics.maxLabelHeightRatio, 0)
    }

    private func verticalOffsetReference(
        slotRect: CGRect,
        geometry: FretboardGeometry
    ) -> CGFloat {
        geometry.stringSpacing > 0 ? geometry.stringSpacing : slotRect.height
    }
}

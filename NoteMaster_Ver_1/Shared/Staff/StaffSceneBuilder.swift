//
//  StaffSceneBuilder.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

import CoreGraphics

struct StaffSceneBuilder: Equatable, Sendable {
    struct LayoutMetrics: Equatable, Sendable {
        var clefToNoteGapInSpaces: CGFloat
        var noteheadHeightToSpaceRatio: CGFloat
        var noteheadWidthToHeightRatio: CGFloat
        var noteLeadingInsetInNoteheadWidths: CGFloat
        var noteTrailingInsetInNoteheadWidths: CGFloat
        var accidentalWidthToNoteheadWidth: CGFloat
        var accidentalHeightToNoteheadHeight: CGFloat
        var accidentalGapToNoteheadWidth: CGFloat
        var stemLengthInSpaces: CGFloat
        var stemAnchorInsetToNoteheadWidth: CGFloat
        var stemVerticalInsetToNoteheadHeight: CGFloat
        var ledgerLineWidthToNoteheadWidth: CGFloat

        static let `default` = LayoutMetrics(
            clefToNoteGapInSpaces: 1.3,
            noteheadHeightToSpaceRatio: 1.1,
            noteheadWidthToHeightRatio: 1.45,
            noteLeadingInsetInNoteheadWidths: 2.4,
            noteTrailingInsetInNoteheadWidths: 1.2,
            accidentalWidthToNoteheadWidth: 0.72,
            accidentalHeightToNoteheadHeight: 2.05,
            accidentalGapToNoteheadWidth: 0.26,
            stemLengthInSpaces: 3.5,
            stemAnchorInsetToNoteheadWidth: 0.16,
            stemVerticalInsetToNoteheadHeight: 0.08,
            ledgerLineWidthToNoteheadWidth: 1.5
        )
    }

    var clef: StaffClef
    var score: StaffScore
    var notationDisplayOptions: StaffNotationDisplayOptions
    var glyphTintColor: StaffSceneColor
    var clefRenderHint: StaffGlyphRenderHint
    var layoutMetrics: LayoutMetrics

    init(
        clef: StaffClef,
        score: StaffScore,
        notationDisplayOptions: StaffNotationDisplayOptions = .noteheadsOnly,
        glyphTintColor: StaffSceneColor = .primaryInk,
        clefRenderHint: StaffGlyphRenderHint = .staffClef(),
        layoutMetrics: LayoutMetrics = .default
    ) {
        self.clef = clef
        self.score = score
        self.notationDisplayOptions = notationDisplayOptions
        self.glyphTintColor = glyphTintColor
        self.clefRenderHint = clefRenderHint
        self.layoutMetrics = layoutMetrics
    }

    func makeScene(geometry: StaffGeometry) -> StaffScene {
        guard !geometry.drawingRect.isNull else {
            return .empty
        }

        var glyphs: [StaffGlyphItem] = [
            StaffGlyphItem(
                symbolID: clefSymbolID,
                placement: .anchor(geometry.clefAnchor(for: clef)),
                tintColor: glyphTintColor,
                renderHint: clefRenderHint
            )
        ]
        var strokeItems: [StaffStrokeItem] = []

        guard !score.notes.isEmpty else {
            return StaffScene(
                lineSegments: geometry.staffLineSegments,
                strokeItems: strokeItems,
                glyphs: glyphs
            )
        }

        let pitchLayout = StaffPitchLayout(clef: clef)
        let noteFrames = makeNoteheadFrames(
            noteCount: score.notes.count,
            geometry: geometry
        )

        for (note, noteheadFrame) in zip(score.notes, noteFrames) {
            guard
                let positionedPitch = pitchLayout.positionedPitch(
                    note.pitch,
                    in: geometry
                )
            else {
                continue
            }

            if notationDisplayOptions.showsAccidentals,
               let accidentalSymbolID = positionedPitch.accidentalSymbolID {
                glyphs.append(
                    StaffGlyphItem(
                        symbolID: accidentalSymbolID,
                        placement: .frame(
                            accidentalFrame(
                                for: noteheadFrame,
                                centerY: positionedPitch.centerY
                            )
                        ),
                        tintColor: glyphTintColor,
                        renderHint: .accidental()
                    )
                )
            }

            glyphs.append(
                StaffGlyphItem(
                    symbolID: noteheadSymbolID(for: note.duration),
                    placement: .frame(
                        centeredFrame(
                            center: CGPoint(
                                x: noteheadFrame.midX,
                                y: positionedPitch.centerY
                            ),
                            size: noteheadFrame.size
                        )
                    ),
                    tintColor: glyphTintColor,
                    renderHint: .notehead()
                )
            )

            if notationDisplayOptions.showsStems,
               note.duration.showsStem {
                strokeItems.append(
                    stemStroke(
                        for: noteheadFrame,
                        positionedPitch: positionedPitch,
                        geometry: geometry
                    )
                )
            }

            if notationDisplayOptions.showsLedgerLines {
                strokeItems.append(
                    contentsOf: ledgerLineStrokes(
                        for: noteheadFrame,
                        ledgerLineYs: positionedPitch.ledgerLineYs
                    )
                )
            }
        }

        return StaffScene(
            lineSegments: geometry.staffLineSegments,
            strokeItems: strokeItems,
            glyphs: glyphs
        )
    }

    private var clefSymbolID: StaffGlyphSymbolID {
        switch clef {
        case .treble:
            return .trebleClef
        case .bass:
            return .bassClef
        }
    }

    private func noteheadSymbolID(
        for duration: StaffNoteDuration
    ) -> StaffGlyphSymbolID {
        switch duration {
        case .whole:
            return .noteheadWhole
        case .half:
            return .noteheadHalf
        case .quarter:
            return .noteheadBlack
        }
    }

    private func makeNoteheadFrames(
        noteCount: Int,
        geometry: StaffGeometry
    ) -> [CGRect] {
        guard
            noteCount > 0,
            !geometry.drawingRect.isNull,
            geometry.staffSpaceHeight > 0
        else {
            return []
        }

        let noteheadSize = resolvedNoteheadSize(geometry: geometry)
        let noteAreaRect = resolvedNoteAreaRect(geometry: geometry)
        guard !noteAreaRect.isNull, !noteAreaRect.isEmpty else {
            return []
        }

        let accidentalWidth = noteheadSize.width * layoutMetrics.accidentalWidthToNoteheadWidth
        let accidentalGap = noteheadSize.width * layoutMetrics.accidentalGapToNoteheadWidth
        let minimumLeadingInset = noteheadSize.width * layoutMetrics.noteLeadingInsetInNoteheadWidths
        let leftInset = notationDisplayOptions.showsAccidentals
            ? max(
                minimumLeadingInset,
                accidentalWidth + accidentalGap + (noteheadSize.width / 2)
            )
            : minimumLeadingInset
        let rightInset = noteheadSize.width * layoutMetrics.noteTrailingInsetInNoteheadWidths

        let centerXs = resolvedNoteCenterXs(
            noteCount: noteCount,
            noteAreaRect: noteAreaRect,
            noteheadWidth: noteheadSize.width,
            leftInset: leftInset,
            rightInset: rightInset
        )

        return centerXs.map {
            centeredFrame(
                center: CGPoint(
                    x: $0,
                    y: geometry.staffRect.midY
                ),
                size: noteheadSize
            )
        }
    }

    private func resolvedNoteAreaRect(
        geometry: StaffGeometry
    ) -> CGRect {
        let minX = min(
            geometry.clefAreaRect.maxX
                + (geometry.staffSpaceHeight * layoutMetrics.clefToNoteGapInSpaces),
            geometry.drawingRect.maxX
        )

        return CGRect(
            x: minX,
            y: geometry.drawingRect.minY,
            width: max(geometry.drawingRect.maxX - minX, 0),
            height: geometry.drawingRect.height
        )
    }

    private func resolvedNoteCenterXs(
        noteCount: Int,
        noteAreaRect: CGRect,
        noteheadWidth: CGFloat,
        leftInset: CGFloat,
        rightInset: CGFloat
    ) -> [CGFloat] {
        guard noteCount > 0 else {
            return []
        }

        let minimumCenterX = min(
            max(noteAreaRect.minX + leftInset, noteAreaRect.minX + (noteheadWidth / 2)),
            noteAreaRect.maxX
        )
        let maximumCenterX = max(
            min(noteAreaRect.maxX - rightInset, noteAreaRect.maxX - (noteheadWidth / 2)),
            minimumCenterX
        )

        if noteCount == 1 {
            return [(minimumCenterX + maximumCenterX) / 2]
        }

        let usableWidth = maximumCenterX - minimumCenterX
        guard usableWidth > 0.5 else {
            return (0..<noteCount).map { index in
                let fraction = (CGFloat(index) + 0.5) / CGFloat(noteCount)
                return noteAreaRect.minX + (noteAreaRect.width * fraction)
            }
        }

        let step = usableWidth / CGFloat(noteCount - 1)
        return (0..<noteCount).map { index in
            minimumCenterX + (CGFloat(index) * step)
        }
    }

    private func resolvedNoteheadSize(
        geometry: StaffGeometry
    ) -> CGSize {
        let height = max(
            geometry.staffSpaceHeight * layoutMetrics.noteheadHeightToSpaceRatio,
            1
        )
        return CGSize(
            width: max(height * layoutMetrics.noteheadWidthToHeightRatio, 1),
            height: height
        )
    }

    private func accidentalFrame(
        for noteheadFrame: CGRect,
        centerY: CGFloat
    ) -> CGRect {
        let width = max(
            noteheadFrame.width * layoutMetrics.accidentalWidthToNoteheadWidth,
            1
        )
        let height = max(
            noteheadFrame.height * layoutMetrics.accidentalHeightToNoteheadHeight,
            1
        )
        let gap = noteheadFrame.width * layoutMetrics.accidentalGapToNoteheadWidth
        let centerX = noteheadFrame.minX - gap - (width / 2)

        return centeredFrame(
            center: CGPoint(x: centerX, y: centerY),
            size: CGSize(width: width, height: height)
        )
    }

    private func stemStroke(
        for noteheadFrame: CGRect,
        positionedPitch: StaffPitchLayout.PositionedPitch,
        geometry: StaffGeometry
    ) -> StaffStrokeItem {
        let length = geometry.staffSpaceHeight * layoutMetrics.stemLengthInSpaces
        let xInset = noteheadFrame.width * layoutMetrics.stemAnchorInsetToNoteheadWidth
        let yInset = noteheadFrame.height * layoutMetrics.stemVerticalInsetToNoteheadHeight
        let stemX: CGFloat
        let startY: CGFloat
        let endY: CGFloat

        switch positionedPitch.stemDirection {
        case .up:
            stemX = noteheadFrame.maxX - xInset
            startY = noteheadFrame.midY + yInset
            endY = startY - length
        case .down:
            stemX = noteheadFrame.minX + xInset
            startY = noteheadFrame.midY - yInset
            endY = startY + length
        }

        return StaffStrokeItem(
            semantic: .stem,
            start: CGPoint(x: stemX, y: startY),
            end: CGPoint(x: stemX, y: endY),
            style: .stem(
                strokeColor: glyphTintColor
            )
        )
    }

    private func ledgerLineStrokes(
        for noteheadFrame: CGRect,
        ledgerLineYs: [CGFloat]
    ) -> [StaffStrokeItem] {
        let ledgerWidth = noteheadFrame.width * layoutMetrics.ledgerLineWidthToNoteheadWidth
        let startX = noteheadFrame.midX - (ledgerWidth / 2)
        let endX = noteheadFrame.midX + (ledgerWidth / 2)

        return ledgerLineYs.map {
            StaffStrokeItem(
                semantic: .ledgerLine,
                start: CGPoint(x: startX, y: $0),
                end: CGPoint(x: endX, y: $0),
                style: .ledgerLine(
                    strokeColor: glyphTintColor
                )
            )
        }
    }

    private func centeredFrame(
        center: CGPoint,
        size: CGSize
    ) -> CGRect {
        CGRect(
            x: center.x - (size.width / 2),
            y: center.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }
}

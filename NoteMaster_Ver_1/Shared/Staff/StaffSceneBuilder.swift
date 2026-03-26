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
        var keySignatureToNoteGapInSpaces: CGFloat
        var keySignatureAccidentalSpacingToAccidentalWidth: CGFloat
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
            keySignatureToNoteGapInSpaces: 1.15,
            keySignatureAccidentalSpacingToAccidentalWidth: 0.24,
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

    struct KeySignatureGlyphLayout: Equatable, Sendable {
        var symbolID: StaffGlyphSymbolID
        var frame: CGRect
    }

    struct NoteSemanticLayout: Equatable, Sendable {
        var note: StaffScoreNote
        var positionedPitch: StaffPitchLayout.PositionedPitch
        var displayedAccidental: StaffAccidental?
    }

    struct PositionedNoteLayout: Equatable, Sendable {
        var note: StaffScoreNote
        var positionedPitch: StaffPitchLayout.PositionedPitch
        var displayedAccidental: StaffAccidental?
        var noteheadFrame: CGRect
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
        notationDisplayOptions: StaffNotationDisplayOptions = .fullNotation,
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

        let noteheadSize = resolvedNoteheadSize(geometry: geometry)
        var glyphs: [StaffGlyphItem] = [
            StaffGlyphItem(
                symbolID: clefSymbolID,
                placement: .anchor(geometry.clefAnchor(for: clef)),
                tintColor: glyphTintColor,
                renderHint: clefRenderHint
            )
        ]
        var strokeItems: [StaffStrokeItem] = []

        let keySignatureGlyphLayouts = resolvedKeySignatureGlyphLayouts(
            geometry: geometry,
            noteheadSize: noteheadSize
        )
        glyphs.append(
            contentsOf: keySignatureGlyphLayouts.map {
                StaffGlyphItem(
                    symbolID: $0.symbolID,
                    placement: .frame($0.frame),
                    tintColor: glyphTintColor,
                    renderHint: .accidental()
                )
            }
        )

        let noteSemanticLayouts = resolvedNoteSemanticLayouts(geometry: geometry)
        let noteLayouts = resolvedNoteLayouts(
            noteSemanticLayouts: noteSemanticLayouts,
            geometry: geometry,
            noteheadSize: noteheadSize,
            keySignatureClusterWidth: resolvedKeySignatureClusterWidth(
                from: keySignatureGlyphLayouts
            )
        )

        for noteLayout in noteLayouts {
            if notationDisplayOptions.showsNoteAccidentals,
               let displayedAccidental = noteLayout.displayedAccidental,
               let accidentalSymbolID = accidentalSymbolID(
                for: displayedAccidental
               ) {
                glyphs.append(
                    StaffGlyphItem(
                        symbolID: accidentalSymbolID,
                        placement: .frame(
                            accidentalFrame(
                                for: noteLayout.noteheadFrame,
                                centerY: noteLayout.positionedPitch.centerY
                            )
                        ),
                        tintColor: glyphTintColor,
                        renderHint: .accidental()
                    )
                )
            }

            glyphs.append(
                StaffGlyphItem(
                    symbolID: noteheadSymbolID(for: noteLayout.note.duration),
                    placement: .frame(noteLayout.noteheadFrame),
                    tintColor: glyphTintColor,
                    renderHint: .notehead()
                )
            )

            if notationDisplayOptions.showsStems,
               noteLayout.note.duration.showsStem {
                strokeItems.append(
                    stemStroke(
                        for: noteLayout.noteheadFrame,
                        positionedPitch: noteLayout.positionedPitch,
                        geometry: geometry
                    )
                )
            }

            if notationDisplayOptions.showsLedgerLines {
                strokeItems.append(
                    contentsOf: ledgerLineStrokes(
                        for: noteLayout.noteheadFrame,
                        ledgerLineYs: noteLayout.positionedPitch.ledgerLineYs
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

    private func accidentalSymbolID(
        for accidental: StaffAccidental
    ) -> StaffGlyphSymbolID? {
        switch accidental {
        case .flat:
            return .accidentalFlat
        case .natural:
            return .accidentalNatural
        case .sharp:
            return .accidentalSharp
        }
    }

    private func resolvedKeySignatureGlyphLayouts(
        geometry: StaffGeometry,
        noteheadSize: CGSize
    ) -> [KeySignatureGlyphLayout] {
        guard notationDisplayOptions.showsKeySignatureAccidentals else {
            return []
        }

        let keySignatureAccidentals = StaffKeySignatureLayout(clef: clef)
            .positionedAccidentals(
                for: score.keySignature,
                in: geometry
            )
        guard !keySignatureAccidentals.isEmpty else {
            return []
        }

        let accidentalSize = resolvedAccidentalSize(noteheadSize: noteheadSize)
        let startX = resolvedContentStartX(geometry: geometry)
        let spacing = accidentalSize.width
            * layoutMetrics.keySignatureAccidentalSpacingToAccidentalWidth

        return keySignatureAccidentals.enumerated().map { index, accidental in
            let centerX = startX
                + (accidentalSize.width / 2)
                + (CGFloat(index) * (accidentalSize.width + spacing))
            return KeySignatureGlyphLayout(
                symbolID: accidental.symbolID,
                frame: centeredFrame(
                    center: CGPoint(x: centerX, y: accidental.centerY),
                    size: accidentalSize
                )
            )
        }
    }

    private func resolvedKeySignatureClusterWidth(
        from keySignatureGlyphLayouts: [KeySignatureGlyphLayout]
    ) -> CGFloat {
        guard
            let firstFrame = keySignatureGlyphLayouts.first?.frame,
            let lastFrame = keySignatureGlyphLayouts.last?.frame
        else {
            return 0
        }

        return max(lastFrame.maxX - firstFrame.minX, 0)
    }

    private func resolvedNoteSemanticLayouts(
        geometry: StaffGeometry
    ) -> [NoteSemanticLayout] {
        let pitchLayout = StaffPitchLayout(clef: clef)
        var accidentalContext = StaffAccidentalContext(
            keySignature: score.keySignature
        )
        var noteLayouts: [NoteSemanticLayout] = []

        for measure in score.measures {
            accidentalContext.resetForMeasure()

            for note in measure.notes {
                guard
                    let positionedPitch = pitchLayout.positionedPitch(
                        note.pitch,
                        in: geometry
                    )
                else {
                    continue
                }

                let accidentalDecision = accidentalContext.resolveDisplayDecision(
                    for: note.pitch
                )
                noteLayouts.append(
                    NoteSemanticLayout(
                        note: note,
                        positionedPitch: positionedPitch,
                        displayedAccidental: accidentalDecision.displayedAccidental
                    )
                )
            }
        }

        return noteLayouts
    }

    private func resolvedNoteLayouts(
        noteSemanticLayouts: [NoteSemanticLayout],
        geometry: StaffGeometry,
        noteheadSize: CGSize,
        keySignatureClusterWidth: CGFloat
    ) -> [PositionedNoteLayout] {
        guard
            !noteSemanticLayouts.isEmpty,
            !geometry.drawingRect.isNull,
            geometry.staffSpaceHeight > 0
        else {
            return []
        }

        let noteAreaRect = resolvedNoteAreaRect(
            geometry: geometry,
            keySignatureClusterWidth: keySignatureClusterWidth
        )
        guard !noteAreaRect.isNull, !noteAreaRect.isEmpty else {
            return []
        }

        let centerXs = resolvedNoteCenterXs(
            noteAreaRect: noteAreaRect,
            noteheadWidth: noteheadSize.width,
            leadingAccessoryWidths: noteSemanticLayouts.map {
                resolvedLeadingAccessoryWidth(
                    displayedAccidental: $0.displayedAccidental,
                    noteheadSize: noteheadSize
                )
            }
        )

        return zip(noteSemanticLayouts, centerXs).map { noteLayout, centerX in
            PositionedNoteLayout(
                note: noteLayout.note,
                positionedPitch: noteLayout.positionedPitch,
                displayedAccidental: noteLayout.displayedAccidental,
                noteheadFrame: centeredFrame(
                    center: CGPoint(
                        x: centerX,
                        y: noteLayout.positionedPitch.centerY
                    ),
                    size: noteheadSize
                )
            )
        }
    }

    private func resolvedNoteAreaRect(
        geometry: StaffGeometry,
        keySignatureClusterWidth: CGFloat
    ) -> CGRect {
        let contentStartX = resolvedContentStartX(geometry: geometry)
        let minX = min(
            contentStartX
                + keySignatureClusterWidth
                + (
                    keySignatureClusterWidth > 0
                    ? geometry.staffSpaceHeight * layoutMetrics.keySignatureToNoteGapInSpaces
                    : 0
                ),
            geometry.drawingRect.maxX
        )

        return CGRect(
            x: minX,
            y: geometry.drawingRect.minY,
            width: max(geometry.drawingRect.maxX - minX, 0),
            height: geometry.drawingRect.height
        )
    }

    private func resolvedContentStartX(
        geometry: StaffGeometry
    ) -> CGFloat {
        geometry.clefContentStartX(
            for: clef,
            gapInSpaces: layoutMetrics.clefToNoteGapInSpaces
        )
    }

    private func resolvedNoteCenterXs(
        noteAreaRect: CGRect,
        noteheadWidth: CGFloat,
        leadingAccessoryWidths: [CGFloat]
    ) -> [CGFloat] {
        let noteCount = leadingAccessoryWidths.count
        guard noteCount > 0 else {
            return []
        }

        let clusterWidths = leadingAccessoryWidths.map { $0 + noteheadWidth }
        let totalClusterWidth = clusterWidths.reduce(0, +)
        let remainingWidth = max(noteAreaRect.width - totalClusterWidth, 0)

        if noteCount == 1,
           let leadingAccessoryWidth = leadingAccessoryWidths.first {
            let clusterMinX = noteAreaRect.minX + (remainingWidth / 2)
            return [clusterMinX + leadingAccessoryWidth + (noteheadWidth / 2)]
        }

        let targetLeadingInset = noteheadWidth * layoutMetrics.noteLeadingInsetInNoteheadWidths
        let targetTrailingInset = noteheadWidth * layoutMetrics.noteTrailingInsetInNoteheadWidths
        let appliedLeadingInset = min(targetLeadingInset, remainingWidth / 2)
        let widthAfterLeadingInset = max(remainingWidth - appliedLeadingInset, 0)
        let appliedTrailingInset = min(targetTrailingInset, widthAfterLeadingInset)
        let interClusterGap = max(
            remainingWidth - appliedLeadingInset - appliedTrailingInset,
            0
        ) / CGFloat(noteCount - 1)

        var currentX = noteAreaRect.minX + appliedLeadingInset
        var centerXs: [CGFloat] = []
        centerXs.reserveCapacity(noteCount)

        for index in leadingAccessoryWidths.indices {
            centerXs.append(
                currentX + leadingAccessoryWidths[index] + (noteheadWidth / 2)
            )
            currentX += clusterWidths[index] + interClusterGap
        }

        return centerXs
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

    private func resolvedAccidentalSize(
        noteheadSize: CGSize
    ) -> CGSize {
        CGSize(
            width: max(
                noteheadSize.width * layoutMetrics.accidentalWidthToNoteheadWidth,
                1
            ),
            height: max(
                noteheadSize.height * layoutMetrics.accidentalHeightToNoteheadHeight,
                1
            )
        )
    }

    private func resolvedLeadingAccessoryWidth(
        displayedAccidental: StaffAccidental?,
        noteheadSize: CGSize
    ) -> CGFloat {
        guard
            notationDisplayOptions.showsNoteAccidentals,
            displayedAccidental != nil
        else {
            return 0
        }

        let accidentalSize = resolvedAccidentalSize(noteheadSize: noteheadSize)
        return accidentalSize.width
            + (noteheadSize.width * layoutMetrics.accidentalGapToNoteheadWidth)
    }

    private func accidentalFrame(
        for noteheadFrame: CGRect,
        centerY: CGFloat
    ) -> CGRect {
        let accidentalSize = resolvedAccidentalSize(noteheadSize: noteheadFrame.size)
        let gap = noteheadFrame.width * layoutMetrics.accidentalGapToNoteheadWidth
        let centerX = noteheadFrame.minX - gap - (accidentalSize.width / 2)

        return centeredFrame(
            center: CGPoint(x: centerX, y: centerY),
            size: accidentalSize
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

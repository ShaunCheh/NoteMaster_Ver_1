//
//  PianoGeometry.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/30.
//

import CoreGraphics

struct PianoSnapTarget: Equatable, Sendable {
    var note: NotePitch
    var offsetX: CGFloat
}

struct PianoGeometry: Equatable, Sendable {
    let configuration: PianoConfiguration
    let state: PianoComponentState
    let bounds: CGRect
    let scene: PianoScene

    init(
        configuration: PianoConfiguration,
        state: PianoComponentState,
        bounds: CGRect
    ) {
        let normalizedBounds = bounds.standardized
        self.configuration = configuration
        self.state = state
        self.bounds = normalizedBounds
        self.scene = PianoSceneBuilder(
            configuration: configuration,
            state: state
        ).makeScene(bounds: normalizedBounds)
    }

    var contentHeight: CGFloat {
        PianoLayoutMath.totalContentHeight(
            configuration: configuration,
            rowCount: state.rowCount
        )
    }

    func rowScene(at rowIndex: Int) -> PianoScene.RowScene? {
        scene.rowScene(at: rowIndex)
    }

    func rowFrame(at rowIndex: Int) -> CGRect? {
        rowScene(at: rowIndex)?.frame
    }

    func noteRect(
        for note: NotePitch,
        rowIndex: Int
    ) -> CGRect? {
        rowScene(at: rowIndex)?.noteRect(for: note)
    }

    func nearestSnapTarget(
        for rowState: PianoRowState
    ) -> PianoSnapTarget {
        PianoLayoutMath.nearestSnapTarget(
            for: rowState,
            configuration: configuration
        )
    }

    func snappedOffsetX(
        for rowState: PianoRowState
    ) -> CGFloat {
        nearestSnapTarget(for: rowState).offsetX
    }

    func normalizedSnappedRowState(
        _ rowState: PianoRowState
    ) -> PianoRowState {
        let snapTarget = nearestSnapTarget(for: rowState)
        return PianoRowState(
            startNote: snapTarget.note,
            offsetX: 0,
            movementScope: rowState.movementScope
        )
    }

    func hitTest(
        _ point: CGPoint,
        phase: PianoEventPhase
    ) -> PianoHitResult {
        let normalizedPoint = CGPoint(x: point.x, y: point.y)

        for rowScene in scene.rows {
            if PianoLayoutMath.contains(
                normalizedPoint,
                inInclusiveBoundsOf: rowScene.buttonLeftRect
            ) {
                return makeHitResult(
                    phase: phase,
                    location: normalizedPoint,
                    rowIndex: rowScene.rowIndex,
                    zone: .buttonLeft,
                    note: nil
                )
            }

            if PianoLayoutMath.contains(
                normalizedPoint,
                inInclusiveBoundsOf: rowScene.buttonRightRect
            ) {
                return makeHitResult(
                    phase: phase,
                    location: normalizedPoint,
                    rowIndex: rowScene.rowIndex,
                    zone: .buttonRight,
                    note: nil
                )
            }

            if PianoLayoutMath.contains(
                normalizedPoint,
                inInclusiveBoundsOf: rowScene.scaleRect
            ) {
                return makeHitResult(
                    phase: phase,
                    location: normalizedPoint,
                    rowIndex: rowScene.rowIndex,
                    zone: .scale,
                    note: nearestScaleMarkerNote(
                        toX: normalizedPoint.x,
                        in: rowScene
                    )
                )
            }

            if PianoLayoutMath.contains(
                normalizedPoint,
                inInclusiveBoundsOf: rowScene.keysRect
            ) {
                return makeHitResult(
                    phase: phase,
                    location: normalizedPoint,
                    rowIndex: rowScene.rowIndex,
                    zone: .keys,
                    note: noteHit(
                        at: normalizedPoint,
                        in: rowScene
                    )
                )
            }
        }

        return PianoHitResult(
            phase: phase,
            locationInView: normalizedPoint,
            rowIndex: nil,
            zone: .outside,
            note: nil,
            isInsideActiveZone: false
        )
    }

    private func makeHitResult(
        phase: PianoEventPhase,
        location: CGPoint,
        rowIndex: Int,
        zone: PianoZone,
        note: NotePitch?
    ) -> PianoHitResult {
        let provisionalHit = PianoHitResult(
            phase: phase,
            locationInView: location,
            rowIndex: rowIndex,
            zone: zone,
            note: note,
            isInsideActiveZone: false
        )

        return PianoHitResult(
            phase: provisionalHit.phase,
            locationInView: provisionalHit.locationInView,
            rowIndex: provisionalHit.rowIndex,
            zone: provisionalHit.zone,
            note: provisionalHit.note,
            isInsideActiveZone: isInsideActiveZone(for: provisionalHit)
        )
    }

    private func noteHit(
        at point: CGPoint,
        in rowScene: PianoScene.RowScene
    ) -> NotePitch? {
        if let blackNote = rowScene.blackKeys.first(where: {
            PianoLayoutMath.contains(point, inInclusiveBoundsOf: $0.rect)
        })?.note {
            return blackNote
        }

        return rowScene.whiteKeys.first(where: {
            PianoLayoutMath.contains(point, inInclusiveBoundsOf: $0.rect)
        })?.note
    }

    private func nearestScaleMarkerNote(
        toX x: CGFloat,
        in rowScene: PianoScene.RowScene
    ) -> NotePitch? {
        rowScene.scaleMarkers.min { lhs, rhs in
            let lhsDistance = abs(lhs.x - x)
            let rhsDistance = abs(rhs.x - x)
            if lhsDistance == rhsDistance {
                return lhs.note.absoluteSemitone < rhs.note.absoluteSemitone
            }
            return lhsDistance < rhsDistance
        }?.note
    }

    private func isInsideActiveZone(
        for hit: PianoHitResult
    ) -> Bool {
        guard let activeInteraction = state.activeInteraction else {
            return hit.zone != .outside
        }

        switch activeInteraction {
        case let .buttonPressed(interaction):
            return hit.rowIndex == interaction.rowIndex
                && hit.buttonDirection == interaction.direction
        case let .scaleDrag(interaction):
            return hit.rowIndex == interaction.rowIndex
                && hit.zone == .scale
        case let .keyGlissando(interaction):
            return hit.rowIndex == interaction.rowIndex
                && hit.zone == .keys
                && hit.note != nil
        }
    }
}

enum PianoLayoutMath {
    static func totalContentHeight(
        configuration: PianoConfiguration,
        rowCount: Int
    ) -> CGFloat {
        guard rowCount > 0 else {
            return 0
        }

        return (CGFloat(rowCount) * configuration.resolvedRowHeight)
            + (CGFloat(max(rowCount - 1, 0)) * configuration.resolvedRowSpacing)
    }

    static func rowFrame(
        rowIndex: Int,
        bounds: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        let originY = bounds.minY
            + (CGFloat(rowIndex)
                * (configuration.resolvedRowHeight + configuration.resolvedRowSpacing))
        return CGRect(
            x: bounds.minX,
            y: originY,
            width: bounds.width,
            height: configuration.resolvedRowHeight
        )
    }

    static func controlStripRect(
        for rowFrame: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        CGRect(
            x: rowFrame.minX,
            y: rowFrame.minY,
            width: rowFrame.width,
            height: configuration.resolvedControlAreaHeight
        )
    }

    static func buttonStripRect(
        for rowFrame: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        CGRect(
            x: rowFrame.minX,
            y: rowFrame.minY,
            width: rowFrame.width,
            height: configuration.resolvedButtonStripHeight
        )
    }

    static func keysRect(
        for rowFrame: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        let controlHeight = configuration.resolvedControlAreaHeight
        return CGRect(
            x: rowFrame.minX,
            y: rowFrame.minY + controlHeight,
            width: rowFrame.width,
            height: max(rowFrame.height - controlHeight, 0)
        )
    }

    static func buttonLeftRect(
        in buttonStripRect: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        let buttonWidth = resolvedButtonWidth(
            in: buttonStripRect,
            configuration: configuration
        )
        return CGRect(
            x: buttonStripRect.minX,
            y: buttonStripRect.minY,
            width: buttonWidth,
            height: buttonStripRect.height
        )
    }

    static func buttonRightRect(
        in buttonStripRect: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        let buttonWidth = resolvedButtonWidth(
            in: buttonStripRect,
            configuration: configuration
        )
        return CGRect(
            x: buttonStripRect.maxX - buttonWidth,
            y: buttonStripRect.minY,
            width: buttonWidth,
            height: buttonStripRect.height
        )
    }

    static func scaleRect(
        for rowFrame: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        return CGRect(
            x: rowFrame.minX,
            y: rowFrame.minY + configuration.resolvedButtonStripHeight,
            width: rowFrame.width,
            height: configuration.resolvedScaleAreaHeight
        )
    }

    static func resolvedButtonWidth(
        in buttonStripRect: CGRect,
        configuration: PianoConfiguration
    ) -> CGFloat {
        min(configuration.resolvedButtonAreaWidth, buttonStripRect.width / 2)
    }

    static func blackKeyWidth(
        configuration: PianoConfiguration
    ) -> CGFloat {
        configuration.resolvedWhiteKeyWidth * configuration.resolvedBlackKeyWidthRatio
    }

    static func blackKeyHeight(
        configuration: PianoConfiguration
    ) -> CGFloat {
        configuration.keyAreaHeight * configuration.resolvedBlackKeyHeightRatio
    }

    static func noteLeadingX(
        _ note: NotePitch,
        configuration: PianoConfiguration
    ) -> CGFloat {
        let whiteKeyWidth = configuration.resolvedWhiteKeyWidth
        let blackKeyWidth = blackKeyWidth(configuration: configuration)

        if let naturalWhiteIndex = naturalWhiteIndex(for: note.pitchClass) {
            let totalWhiteIndex = (note.octave * 7) + naturalWhiteIndex
            return CGFloat(totalWhiteIndex) * whiteKeyWidth
        }

        let leftWhiteIndex = (note.octave * 7)
            + leftNaturalWhiteIndex(for: note.pitchClass)
        return (CGFloat(leftWhiteIndex + 1) * whiteKeyWidth) - (blackKeyWidth / 2)
    }

    static func keyRect(
        for note: NotePitch,
        rowState: PianoRowState,
        keysRect: CGRect,
        configuration: PianoConfiguration
    ) -> CGRect {
        let originX = keysRect.minX
            + noteLeadingX(note, configuration: configuration)
            - noteLeadingX(rowState.startNote, configuration: configuration)
            - rowState.offsetX

        if note.pitchClass.isNatural {
            return CGRect(
                x: originX,
                y: keysRect.minY,
                width: configuration.resolvedWhiteKeyWidth,
                height: keysRect.height
            )
        }

        return CGRect(
            x: originX,
            y: keysRect.minY,
            width: blackKeyWidth(configuration: configuration),
            height: blackKeyHeight(configuration: configuration)
        )
    }

    static func visibleKeys(
        rowState: PianoRowState,
        keysRect: CGRect,
        configuration: PianoConfiguration
    ) -> (
        whites: [PianoScene.RowScene.WhiteKey],
        blacks: [PianoScene.RowScene.BlackKey]
    ) {
        let searchRadius = noteSearchRadius(
            rowState: rowState,
            keysRect: keysRect,
            configuration: configuration
        )
        let bufferRect = keysRect.insetBy(
            dx: -max(
                configuration.resolvedWhiteKeyWidth,
                blackKeyWidth(configuration: configuration)
            ),
            dy: 0
        )

        var whiteKeys: [PianoScene.RowScene.WhiteKey] = []
        var blackKeys: [PianoScene.RowScene.BlackKey] = []

        for semitoneOffset in (-searchRadius)...searchRadius {
            let note = rowState.startNote.advanced(by: semitoneOffset)
            let rect = keyRect(
                for: note,
                rowState: rowState,
                keysRect: keysRect,
                configuration: configuration
            )

            guard rect.intersects(bufferRect) else {
                continue
            }

            if note.pitchClass.isNatural {
                whiteKeys.append(
                    PianoScene.RowScene.WhiteKey(
                        note: note,
                        rect: rect
                    )
                )
            } else {
                blackKeys.append(
                    PianoScene.RowScene.BlackKey(
                        note: note,
                        rect: rect
                    )
                )
            }
        }

        return (whites: whiteKeys, blacks: blackKeys)
    }

    static func scaleMarkers(
        from whiteKeys: [PianoScene.RowScene.WhiteKey],
        scaleRect: CGRect
    ) -> [PianoScene.RowScene.ScaleMarker] {
        whiteKeys.compactMap { whiteKey in
            let markerX = whiteKey.rect.midX
            guard isValue(
                markerX,
                withinInclusiveRangeOf: scaleRect.minX,
                and: scaleRect.maxX
            ) else {
                return nil
            }

            return PianoScene.RowScene.ScaleMarker(
                note: whiteKey.note,
                x: markerX,
                labelText: whiteKey.note.displayText()
            )
        }
    }

    static func nearestSnapTarget(
        for rowState: PianoRowState,
        configuration: PianoConfiguration
    ) -> PianoSnapTarget {
        let searchRadius = snapSearchRadius(
            rowState: rowState,
            configuration: configuration
        )
        let startLeadingX = noteLeadingX(
            rowState.startNote,
            configuration: configuration
        )

        var bestTarget = PianoSnapTarget(
            note: rowState.startNote,
            offsetX: 0
        )
        var bestDistance = abs(rowState.offsetX)

        for semitoneOffset in (-searchRadius)...searchRadius {
            let note = rowState.startNote.advanced(by: semitoneOffset)
            let candidateOffset = noteLeadingX(
                note,
                configuration: configuration
            ) - startLeadingX
            let distance = abs(candidateOffset - rowState.offsetX)

            if distance < bestDistance {
                bestDistance = distance
                bestTarget = PianoSnapTarget(
                    note: note,
                    offsetX: candidateOffset
                )
                continue
            }

            if distance == bestDistance
                && abs(semitoneOffset)
                    < abs(
                        bestTarget.note.absoluteSemitone
                            - rowState.startNote.absoluteSemitone
                    ) {
                bestTarget = PianoSnapTarget(
                    note: note,
                    offsetX: candidateOffset
                )
            }
        }

        return bestTarget
    }

    static func noteSearchRadius(
        rowState: PianoRowState,
        keysRect: CGRect,
        configuration: PianoConfiguration
    ) -> Int {
        let searchDistance = abs(rowState.offsetX)
            + keysRect.width
            + (configuration.resolvedWhiteKeyWidth * 4)
        let minimumAdvance = max(
            blackKeyWidth(configuration: configuration) / 2,
            1
        )
        return max(
            Int(ceil(searchDistance / minimumAdvance)) + 12,
            24
        )
    }

    static func snapSearchRadius(
        rowState: PianoRowState,
        configuration: PianoConfiguration
    ) -> Int {
        let searchDistance = abs(rowState.offsetX)
            + (configuration.resolvedWhiteKeyWidth * 2)
        let minimumAdvance = max(
            blackKeyWidth(configuration: configuration) / 2,
            1
        )
        return max(
            Int(ceil(searchDistance / minimumAdvance)) + 4,
            12
        )
    }

    static func naturalWhiteIndex(
        for pitchClass: PitchClass
    ) -> Int? {
        switch pitchClass {
        case .c:
            return 0
        case .d:
            return 1
        case .e:
            return 2
        case .f:
            return 3
        case .g:
            return 4
        case .a:
            return 5
        case .b:
            return 6
        case .cSharp, .dSharp, .fSharp, .gSharp, .aSharp:
            return nil
        }
    }

    static func leftNaturalWhiteIndex(
        for pitchClass: PitchClass
    ) -> Int {
        switch pitchClass {
        case .cSharp:
            return 0
        case .dSharp:
            return 1
        case .fSharp:
            return 3
        case .gSharp:
            return 4
        case .aSharp:
            return 5
        case .c, .d, .e, .f, .g, .a, .b:
            return naturalWhiteIndex(for: pitchClass) ?? 0
        }
    }

    static func contains(
        _ point: CGPoint,
        inInclusiveBoundsOf rect: CGRect
    ) -> Bool {
        guard !rect.isNull else {
            return false
        }

        return isValue(point.x, withinInclusiveRangeOf: rect.minX, and: rect.maxX)
            && isValue(point.y, withinInclusiveRangeOf: rect.minY, and: rect.maxY)
    }

    static func isValue(
        _ value: CGFloat,
        withinInclusiveRangeOf minValue: CGFloat,
        and maxValue: CGFloat
    ) -> Bool {
        value >= minValue && value <= maxValue
    }
}

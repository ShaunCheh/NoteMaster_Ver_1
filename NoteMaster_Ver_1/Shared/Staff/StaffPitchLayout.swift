//
//  StaffPitchLayout.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/26.
//

import CoreGraphics

struct StaffPitchLayout: Equatable, Sendable {
    enum StemDirection: Equatable, Sendable {
        case up
        case down
    }

    struct PositionedPitch: Equatable, Sendable {
        var staffPosition: Int
        var centerY: CGFloat
        var stemDirection: StemDirection
        var ledgerLineYs: [CGFloat]
    }

    var clef: StaffClef

    init(clef: StaffClef) {
        self.clef = clef
    }

    func positionedPitch(
        _ pitch: StaffPitch,
        in geometry: StaffGeometry
    ) -> PositionedPitch? {
        guard
            let bottomLineY = geometry.bottomLineY,
            geometry.staffStepHeight > 0
        else {
            return nil
        }

        let staffPosition = pitch.diatonicIndex - bottomLineReferencePitch.diatonicIndex
        let centerY = bottomLineY - (CGFloat(staffPosition) * geometry.staffStepHeight)

        return PositionedPitch(
            staffPosition: staffPosition,
            centerY: centerY,
            stemDirection: stemDirection(
                for: staffPosition,
                geometry: geometry
            ),
            ledgerLineYs: ledgerLineYs(
                for: staffPosition,
                geometry: geometry
            )
        )
    }

    private var bottomLineReferencePitch: StaffPitch {
        switch clef {
        case .treble:
            return StaffPitch(letter: .e, octave: 4)
        case .bass:
            return StaffPitch(letter: .g, octave: 2)
        }
    }

    private func stemDirection(
        for staffPosition: Int,
        geometry: StaffGeometry
    ) -> StemDirection {
        let middleLinePosition = geometry.staffLineCount - 1
        return staffPosition >= middleLinePosition ? .down : .up
    }

    private func ledgerLineYs(
        for staffPosition: Int,
        geometry: StaffGeometry
    ) -> [CGFloat] {
        guard
            let bottomLineY = geometry.bottomLineY,
            geometry.staffStepHeight > 0
        else {
            return []
        }

        let topLinePosition = (geometry.staffLineCount - 1) * 2

        if staffPosition > topLinePosition {
            var lineYs: [CGFloat] = []
            var currentPosition = topLinePosition + 2
            while currentPosition <= staffPosition {
                lineYs.append(
                    bottomLineY - (CGFloat(currentPosition) * geometry.staffStepHeight)
                )
                currentPosition += 2
            }
            return lineYs
        }

        if staffPosition < 0 {
            var lineYs: [CGFloat] = []
            var currentPosition = -2
            while currentPosition >= staffPosition {
                lineYs.append(
                    bottomLineY - (CGFloat(currentPosition) * geometry.staffStepHeight)
                )
                currentPosition -= 2
            }
            return lineYs
        }

        return []
    }
}
